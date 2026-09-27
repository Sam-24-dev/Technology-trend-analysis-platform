"""The remote Reddit aggregate receipt is inert until explicitly selected."""

import json
import hashlib
from datetime import datetime, timedelta, timezone

import pytest

import export_history_json
from config.run_manifest_public_contract import build_public_run_manifest_from_filesystem
from generate_run_manifest import generate_manifest_from_final_bridges
from reddit_etl import write_source_package_receipt
from reddit_source_package import validate_reddit_source_package
from scripts.check_source_freshness import REQUIRED_SOURCE_DATASETS, check_source_freshness


SCOPE = ["webdev", "programming", "learnprogramming", "Python", "javascript",
         "typescript", "reactjs", "node", "devops", "MachineLearning"]


@pytest.fixture
def package(tmp_path):
    data = tmp_path / "datos"
    data.mkdir()
    (data / "reddit_sentimiento_frameworks.csv").write_text(
        "framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\n"
        "Python,3,2,1,0,66.67,33.33,0\n", encoding="utf-8",
    )
    (data / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nPython,3\n", encoding="utf-8",
    )
    now = datetime.now(timezone.utc).replace(microsecond=0)
    start = now.replace(hour=0, minute=0, second=0)
    receipt = write_source_package_receipt(tmp_path, start, start, start, SCOPE, 5)
    return tmp_path, receipt, start.date().isoformat(), now


def test_valid_receipt_binds_exact_bytes_and_claims_only_posts_count(package):
    root, _, date, now = package
    context = validate_reddit_source_package(root, date, now=now)
    assert context["source_date_utc"] == date
    assert context["extraction_finished_at_utc"].endswith("Z")
    assert context["posts_count"] == 5  # A positive producer claim, not independently proven by aggregates.
    finish = datetime.fromisoformat(context["extraction_finished_at_utc"].replace("Z", "+00:00"))
    assert validate_reddit_source_package(root, date, now=finish + timedelta(hours=192))
    with pytest.raises(ValueError):
        validate_reddit_source_package(root, date, now=finish + timedelta(hours=192, seconds=1))


@pytest.mark.parametrize("damage", [
    "missing", "missing_csv", "tampered", "wrong_hash", "wrong_rows", "wrong_total",
    "bad_schema", "bad_sentiment", "bad_percentages", "bad_scope", "bad_posts", "extra_receipt", "extra_meta",
    "stale", "future", "cross_date",
])
def test_invalid_package_fails_closed(package, damage):
    root, receipt, date, now = package
    data = root / "datos"
    payload = json.loads(receipt.read_text(encoding="utf-8"))
    if damage == "missing":
        receipt.unlink()
    elif damage == "missing_csv":
        (data / "reddit_temas_emergentes.csv").unlink()
    elif damage == "tampered":
        with (data / "reddit_temas_emergentes.csv").open("ab") as handle:
            handle.write(b"Extra,1\n")
    elif damage == "wrong_hash":
        payload["outputs"]["reddit_temas_emergentes.csv"]["sha256"] = "0" * 64
    elif damage == "wrong_rows":
        payload["outputs"]["reddit_temas_emergentes.csv"]["rows"] = 2
    elif damage == "wrong_total":
        payload["outputs"]["reddit_temas_emergentes.csv"]["mentions_total"] = 4
    elif damage == "bad_schema":
        (data / "reddit_temas_emergentes.csv").write_text("tema,bad\nPython,3\n", encoding="utf-8")
    elif damage in {"bad_sentiment", "bad_percentages"}:
        counts = "1,1,0" if damage == "bad_sentiment" else "2,1,0"
        (data / "reddit_sentimiento_frameworks.csv").write_text(
            "framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\n"
            f"Python,3,{counts},50,50,0\n", encoding="utf-8",
        )
    elif damage == "bad_scope":
        payload["scope"] = SCOPE[:-1] + ["other"]
    elif damage == "bad_posts":
        payload["posts_count"] = 0
    elif damage == "extra_receipt":
        payload["unverified"] = True
    elif damage == "extra_meta":
        payload["outputs"]["reddit_temas_emergentes.csv"]["unverified"] = 1
    elif damage in {"stale", "future"}:
        shift = timedelta(days=-9) if damage == "stale" else timedelta(minutes=1)
        for field in ("extraction_started_at_utc", "extraction_finished_at_utc"):
            payload[field] = (now + shift).isoformat().replace("+00:00", "Z")
        shifted_date = (now + shift).date().isoformat()
        payload["source_date_utc"] = shifted_date
        payload["reference_date_utc"] = shifted_date
    elif damage == "cross_date":
        payload["source_date_utc"] = "1999-01-01"
    if damage in {"bad_schema", "bad_sentiment", "bad_percentages"}:
        name = "reddit_temas_emergentes.csv" if damage == "bad_schema" else "reddit_sentimiento_frameworks.csv"
        payload["outputs"][name]["sha256"] = hashlib.sha256((data / name).read_bytes()).hexdigest()
    if damage not in {"missing", "tampered", "missing_csv"}:
        receipt.write_text(json.dumps(payload), encoding="utf-8")
    with pytest.raises(ValueError):
        validate_reddit_source_package(root, payload["source_date_utc"] if damage == "stale" else date, now=now)


def test_receipt_presence_is_inert_without_opt_in(package, monkeypatch):
    root, receipt, _, _ = package
    monkeypatch.setattr(export_history_json, "_utc_now_iso", lambda: "2026-09-28T12:00:00Z")
    first = root / "off_absent"
    second = root / "off_present"
    receipt_bytes = receipt.read_bytes()
    receipt.unlink()
    export_history_json.export_bridge_assets(root, output_dir=first)
    absent_manifest = build_public_run_manifest_from_filesystem(root)
    receipt.parent.mkdir(parents=True, exist_ok=True)
    receipt.write_bytes(receipt_bytes)
    export_history_json.export_bridge_assets(root, output_dir=second)
    present_manifest = build_public_run_manifest_from_filesystem(root)
    for field in ("dataset_summaries", "quality_gate_status", "degraded_mode", "notes"):
        assert absent_manifest[field] == present_manifest[field]
    for name in ("reddit_sentimiento_public.json", "reddit_temas_history.json", "reddit_interseccion_history.json"):
        assert (first / name).read_bytes() == (second / name).read_bytes()


def test_explicit_opt_in_stamps_all_three_bridges_and_revalidates(package):
    root, receipt, date, _ = package
    data = root / "datos"
    latest = data / "latest"
    latest.mkdir()
    (latest / "reddit_sentimiento_frameworks.csv").write_bytes((data / "reddit_sentimiento_frameworks.csv").read_bytes())
    year, month, day = date.split("-")
    for dataset, name, content in (
        ("reddit_temas", "reddit_temas_emergentes.csv", (data / "reddit_temas_emergentes.csv").read_bytes()),
        ("interseccion", "interseccion_github_reddit.csv", b"tecnologia,ranking_github,ranking_reddit\nPython,1,1\n"),
    ):
        history = data / "history" / dataset / f"year={year}" / f"month={month}" / f"day={day}"
        history.mkdir(parents=True)
        (history / name).write_bytes(content)
    output = root / "opted_in"
    export_history_json.export_bridge_assets(
        root, output_dir=output, reddit_source_package_date_utc=date,
    )
    for name in ("reddit_sentimiento_public.json", "reddit_temas_history.json", "reddit_interseccion_history.json"):
        bridge = json.loads((output / name).read_text(encoding="utf-8"))
        assert bridge["source_updated_at_utc"] == json.loads(receipt.read_text())["extraction_finished_at_utc"]
        assert bridge["source_provenance"]["mode"] == "source_package"
        assert bridge["generated_at_utc"] != bridge["source_updated_at_utc"]
    (latest / "reddit_sentimiento_frameworks.csv").write_text("framework,total_menciones\nOther,99\n", encoding="utf-8")
    with pytest.raises(ValueError, match="not match selected Reddit source package"):
        export_history_json.export_bridge_assets(root, output_dir=root / "invalid", reddit_source_package_date_utc=date)
    receipt.unlink()
    with pytest.raises(ValueError):
        export_history_json.export_bridge_assets(
            root, output_dir=root / "invalid", reddit_source_package_date_utc=date,
        )


def test_final_manifest_uses_package_time_and_degraded_status(package):
    root, receipt, date, _ = package
    assets = root / "frontend" / "assets" / "data"
    assets.mkdir(parents=True)
    latest = root / "datos" / "latest"
    latest.mkdir()
    for name, content in (
        ("github_lenguajes.csv", "lenguaje,total_repos\nPython,1\n"),
        ("so_volumen_preguntas.csv", "lenguaje,preguntas_nuevas_2025\nPython,1\n"),
        ("reddit_sentimiento_frameworks.csv", "framework,total_menciones\nPython,1\n"),
        ("reddit_temas_emergentes.csv", "tema,menciones\nPython,1\n"),
        ("interseccion_github_reddit.csv", "tecnologia,rank\nPython,1\n"),
    ):
        (latest / name).write_text(content, encoding="utf-8")
    finished = json.loads(receipt.read_text())["extraction_finished_at_utc"]
    for name in ("reddit_sentimiento_public.json", "reddit_temas_history.json", "reddit_interseccion_history.json"):
        (assets / name).write_text(json.dumps({
            "generated_at_utc": "2026-09-28T12:00:00Z",
            "source_updated_at_utc": finished,
            "source_provenance": {"source": "reddit", "mode": "source_package", "source_date_utc": date},
        }), encoding="utf-8")
    with pytest.raises(ValueError, match="explicit validated package context"):
        build_public_run_manifest_from_filesystem(root)
    generate_manifest_from_final_bridges(
        root, output_dirs=[assets], require_metadata=True, reddit_source_package_date_utc=date,
    )
    payload = json.loads((assets / "run_manifest.json").read_text())
    summaries = {item["dataset"]: item for item in payload["dataset_summaries"]}
    assert {summaries[name]["updated_at_utc"] for name in (
        "reddit_sentimiento_frameworks", "reddit_temas_emergentes", "interseccion_github_reddit",
    )} == {finished}
    assert payload["degraded_mode"] is True
    assert payload["quality_gate_status"] == "pass_with_warnings"
    receipt.unlink()
    with pytest.raises(ValueError):
        build_public_run_manifest_from_filesystem(root, reddit_source_package_date_utc=date)


def test_freshness_lineage_uses_package_source_time_only_when_marked(package):
    root, receipt, date, now = package
    assets = root / "frontend" / "assets" / "data"
    assets.mkdir(parents=True)
    source_time = json.loads(receipt.read_text())["extraction_finished_at_utc"]
    generated = now.isoformat().replace("+00:00", "Z")
    manifest = {"generated_at_utc": generated, "dataset_summaries": [
        {"dataset": dataset, "updated_at_utc": source_time if source == "reddit" else generated}
        for source, datasets in REQUIRED_SOURCE_DATASETS.items() for dataset in datasets
    ]}
    (assets / "run_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    for name in ("reddit_sentimiento_public.json", "reddit_temas_history.json", "reddit_interseccion_history.json"):
        (assets / name).write_text(json.dumps({
            "generated_at_utc": generated, "source_updated_at_utc": source_time,
            "source_provenance": {"source": "reddit", "mode": "source_package", "source_date_utc": date},
        }), encoding="utf-8")
    with pytest.raises(ValueError, match="explicit validated package context"):
        check_source_freshness(root)
    assert check_source_freshness(root, reddit_source_package_date_utc=date)["source_updated_at_utc"]["reddit"] == source_time
    manifest["dataset_summaries"][-1]["updated_at_utc"] = generated
    (assets / "run_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    with pytest.raises(ValueError, match="final canonical timestamp mismatch"):
        check_source_freshness(root, reddit_source_package_date_utc=date)
    manifest["dataset_summaries"][-1]["updated_at_utc"] = source_time
    (assets / "run_manifest.json").write_text(json.dumps(manifest), encoding="utf-8")
    for name in ("reddit_sentimiento_public.json", "reddit_temas_history.json", "reddit_interseccion_history.json"):
        (assets / name).unlink()
    with pytest.raises(ValueError, match="final canonical Reddit bridge missing"):
        check_source_freshness(root, reddit_source_package_date_utc=date)
