"""The optional Reddit handoff must be selected before any public output."""

import json
import shutil
from datetime import datetime, timedelta, timezone
from pathlib import Path

import pytest

import base_etl
import reddit_etl
from reddit_etl import write_source_package_receipt
from reddit_source_package import REDDIT_SCOPE
from scripts.materialize_etl_artifacts import materialize_artifacts
from scripts.reddit_source_package_consumer import finalize_package, select_package


NOW = datetime.now(timezone.utc).replace(microsecond=0)
DATE = NOW.date().isoformat()
PARTITION = f"year={DATE[:4]}/month={DATE[5:7]}/day={DATE[8:10]}"
NAMES = ("reddit_sentimiento_frameworks.csv", "reddit_temas_emergentes.csv")


@pytest.fixture
def handoff(tmp_path):
    candidate = tmp_path / "candidate"
    data = candidate / "datos"
    data.mkdir(parents=True)
    (data / NAMES[0]).write_bytes(
        b"framework,total_menciones,positivos,neutros,negativos,% positivo,% neutro,% negativo\r\n"
        b"Python,3,2,1,0,66.67,33.33,0\r\n"
    )
    (data / NAMES[1]).write_bytes(b"tema,menciones\r\nPython,3\r\n")
    start = NOW.replace(hour=0, minute=0, second=0)
    write_source_package_receipt(candidate, start, start, start, list(REDDIT_SCOPE), 5)
    workspace = tmp_path / "workspace"
    root = workspace / "datos"
    receipt = root / "source_packages/reddit/receipt.json"
    receipt.parent.mkdir(parents=True)
    shutil.copyfile(data / "source_packages/reddit/receipt.json", receipt)
    for name in NAMES:
        (root / name).write_bytes(b"old remote output")
    return workspace, candidate


def test_same_run_remote_priority_leaves_package_inert(handoff):
    workspace, candidate = handoff
    (candidate / "datos/source_packages/reddit/receipt.json").unlink()
    before = [(workspace / "datos" / name).read_bytes() for name in NAMES]
    assert not select_package(workspace, candidate, DATE, remote_accepted=True, minimum_mentions=2, now=NOW)
    assert before == [(workspace / "datos" / name).read_bytes() for name in NAMES]
    assert not (workspace / "artifacts/reddit-package").exists()


def test_same_date_package_installs_exact_source_bytes_and_current_history(handoff):
    workspace, candidate = handoff
    assert select_package(workspace, candidate, DATE, remote_accepted=False, minimum_mentions=2, now=NOW)
    for dataset, name in (("reddit_sentimiento", NAMES[0]), ("reddit_temas", NAMES[1])):
        source = (candidate / "datos" / name).read_bytes()
        for relative in (
            f"datos/{name}", f"datos/latest/{name}",
            f"datos/history/{dataset}/{PARTITION}/{name}",
            f"artifacts/reddit-package/datos/{name}",
            f"artifacts/reddit-package/datos/latest/{name}",
            f"artifacts/reddit-package/datos/history/{dataset}/{PARTITION}/{name}",
        ):
            assert (workspace / relative).read_bytes() == source
    assert not (workspace / "datos/history/interseccion" / PARTITION).exists()


@pytest.mark.parametrize("missing_github", [False, True])
def test_package_intersection_uses_same_run_github_artifact(handoff, monkeypatch, missing_github):
    workspace, candidate = handoff
    assert select_package(workspace, candidate, DATE, remote_accepted=False, minimum_mentions=2, now=NOW)
    github = workspace / "artifacts/github"
    for dataset, name, content in (
        ("github_repos", "github_repos_2025.csv", b"language\nPython\n"),
        ("github_commits", "github_commits_frameworks.csv", b"framework,ranking\nReact,1\n"),
    ):
        for relative in (f"datos/{name}", f"datos/latest/{name}",
                         f"datos/history/{dataset}/{PARTITION}/{name}"):
            path = github / relative
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(content)
    materialize_artifacts(workspace, [github])
    if missing_github:
        (github / "datos/github_commits_frameworks.csv").unlink()
    outputs = {key: workspace / "datos" / name for key, name in (
        ("github_repos", "github_repos_2025.csv"),
        ("github_commits", "github_commits_frameworks.csv"),
        ("reddit_temas", NAMES[1]),
        ("interseccion", "interseccion_github_reddit.csv"),
    )}
    monkeypatch.setattr(reddit_etl, "ARCHIVOS_SALIDA", outputs)
    monkeypatch.setattr(base_etl, "ARCHIVOS_SALIDA", outputs)
    monkeypatch.setattr(base_etl, "FECHA_FIN", NOW)
    monkeypatch.setattr(base_etl, "WRITE_LEGACY_CSV", True)
    monkeypatch.setattr(base_etl, "WRITE_LATEST_CSV", True)
    monkeypatch.setattr(base_etl, "WRITE_HISTORY_CSV", True)
    monkeypatch.setattr(base_etl, "get_latest_output_path", lambda key: workspace / "datos/latest" / outputs[key].name)
    monkeypatch.setattr(
        base_etl, "get_history_output_path",
        lambda key, fecha=None: workspace / "datos/history" / key / PARTITION / outputs[key].name,
    )
    if missing_github:
        with pytest.raises(ValueError, match="GitHub source missing"):
            reddit_etl.run_intersection_only(workspace, github, workspace / "artifacts/reddit-package")
        assert not outputs["interseccion"].exists()
    else:
        reddit_etl.run_intersection_only(workspace, github, workspace / "artifacts/reddit-package")
        assert b"Python" in outputs["interseccion"].read_bytes()
        assert (workspace / "datos/latest/interseccion_github_reddit.csv").read_bytes() == outputs["interseccion"].read_bytes()


@pytest.mark.parametrize("damage", [
    "missing_receipt", "missing_csv", "tampered", "duplicate_key", "low_coverage", "no_baseline",
    "cross_date", "stale", "future", "receipt_mismatch", "ambiguous_history",
])
def test_ineligible_package_never_replaces_materialized_remote_outputs(handoff, damage):
    workspace, candidate = handoff
    data = candidate / "datos"
    receipt = data / "source_packages/reddit/receipt.json"
    minimum = 2
    aggregate_date = DATE
    now = NOW
    if damage == "missing_receipt":
        receipt.unlink()
    elif damage == "missing_csv":
        (data / NAMES[0]).unlink()
    elif damage == "tampered":
        (data / NAMES[1]).write_bytes(b"tema,menciones\r\nOther,3\r\n")
    elif damage == "duplicate_key":
        text = receipt.read_text(encoding="utf-8")
        receipt.write_text(text.replace('"source": "reddit",', '"source": "other", "source": "reddit",', 1), encoding="utf-8")
    elif damage == "low_coverage":
        minimum = 4
    elif damage == "no_baseline":
        minimum = None
    elif damage == "cross_date":
        aggregate_date = (NOW + timedelta(days=1)).date().isoformat()
        now += timedelta(days=1)
    elif damage == "stale":
        now += timedelta(days=9)
    elif damage == "future":
        now = NOW - timedelta(days=1)
    elif damage == "receipt_mismatch":
        (workspace / "datos/source_packages/reddit/receipt.json").write_text("{}", encoding="utf-8")
    elif damage == "ambiguous_history":
        alias = workspace / "datos/history/reddit_temas" / PARTITION / "run=123456" / NAMES[1]
        alias.parent.mkdir(parents=True)
        alias.write_bytes(b"unverified older bytes")
    before = [(workspace / "datos" / name).read_bytes() for name in NAMES]
    assert not select_package(workspace, candidate, aggregate_date, remote_accepted=False, minimum_mentions=minimum, now=now)
    assert before == [(workspace / "datos" / name).read_bytes() for name in NAMES]
    assert not (workspace / "artifacts/reddit-package").exists()


def test_tampered_selected_package_cannot_finalize_public_assets(handoff):
    workspace, candidate = handoff
    assert select_package(workspace, candidate, DATE, remote_accepted=False, minimum_mentions=2, now=NOW)
    (workspace / "datos" / NAMES[1]).write_bytes(b"tema,menciones\nOther,3\n")
    with pytest.raises(ValueError, match="Invalid Reddit source package"):
        finalize_package(workspace, DATE)
    assert not (workspace / "frontend/assets/data/run_manifest.json").exists()


def test_stale_frontend_reddit_csv_cannot_finalize_public_assets(handoff):
    workspace, candidate = handoff
    assert select_package(workspace, candidate, DATE, remote_accepted=False, minimum_mentions=2, now=NOW)
    assets = workspace / "frontend/assets/data"
    assets.mkdir(parents=True)
    for name in NAMES:
        (assets / name).write_bytes((workspace / "datos" / name).read_bytes())
    (assets / NAMES[1]).write_bytes(b"tema,menciones\nOther,3\n")
    with pytest.raises(ValueError, match="frontend mismatch"):
        finalize_package(workspace, DATE)
    assert not (assets / "run_manifest.json").exists()


def test_final_package_metadata_uses_collection_time_and_both_roots(handoff):
    workspace, candidate = handoff
    assert select_package(workspace, candidate, DATE, remote_accepted=False, minimum_mentions=2, now=NOW)
    data = workspace / "datos"
    assets = workspace / "frontend/assets/data"
    assets.mkdir(parents=True)
    for name in NAMES:
        (assets / name).write_bytes((data / name).read_bytes())
    intersection = b"tecnologia,ranking_github,ranking_reddit\nPython,1,1\n"
    for relative in (
        "interseccion_github_reddit.csv", "latest/interseccion_github_reddit.csv",
        f"history/interseccion/{PARTITION}/interseccion_github_reddit.csv",
    ):
        path = data / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(intersection)
    for name, content in (
        ("github_lenguajes.csv", b"lenguaje,total_repos\nPython,1\n"),
        ("so_volumen_preguntas.csv", b"lenguaje,preguntas_nuevas_2025\nPython,1\n"),
    ):
        path = data / "latest" / name
        path.write_bytes(content)
    finalize_package(workspace, DATE)
    finished = json.loads((candidate / "datos/source_packages/reddit/receipt.json").read_text())["extraction_finished_at_utc"]
    for root in (workspace / "frontend/assets/data", workspace / "datos/metadata/remote_assets"):
        for name in ("reddit_sentimiento_public.json", "reddit_temas_history.json", "reddit_interseccion_history.json"):
            bridge = json.loads((root / name).read_text())
            assert bridge["source_updated_at_utc"] == finished
            assert bridge["source_provenance"]["mode"] == "source_package"
        manifest = json.loads((root / "run_manifest.json").read_text())
        assert manifest["degraded_mode"] is True
        assert manifest["quality_gate_status"] == "pass_with_warnings"
        summaries = {row["dataset"]: row for row in manifest["dataset_summaries"]}
        assert {summaries[name]["updated_at_utc"] for name in (
            "reddit_sentimiento_frameworks", "reddit_temas_emergentes", "interseccion_github_reddit",
        )} == {finished}


def test_workflow_never_uploads_before_final_package_gates():
    workflow = (Path(__file__).resolve().parents[1] / ".github/workflows/etl_semanal.yml").read_text(encoding="utf-8")
    aggregate = workflow.split("  job_aggregate:", 1)[1].split("  job_publish:", 1)[0]
    steps = (
        "Snapshot repo Reddit baseline", "Materialize source outputs", "Select reviewed Reddit package",
        "Derive package Reddit intersection", "Sync CSVs to frontend assets", "Finalize package provenance",
        "Enforce bridge integrity gate", "Enforce canonical source freshness guard", "Upload aggregate artifacts",
    )
    assert [aggregate.index(step) for step in steps] == sorted(aggregate.index(step) for step in steps)
    assert "steps.package_selection.outputs.selected != 'true'" in aggregate
    assert "steps.package_selection.outputs.selected == 'true'" in aggregate
    assert workflow.index("if: ${{ needs.job_aggregate.result == 'success' }}") > workflow.index("Upload aggregate artifacts")
