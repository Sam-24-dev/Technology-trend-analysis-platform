from __future__ import annotations

import json

import pytest

from generate_run_manifest import generate_manifest_from_final_bridges, generate_manifest_public


def test_generate_manifest_public_writes_output_with_filesystem_fallback(tmp_path):
    latest_dir = tmp_path / "datos" / "latest"
    latest_dir.mkdir(parents=True)
    (latest_dir / "trend_score.csv").write_text(
        "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n1,Python,100,100,0,75,2\n",
        encoding="utf-8",
    )
    (latest_dir / "github_lenguajes.csv").write_text("lenguaje,total_repos\nPython,10\n", encoding="utf-8")
    (latest_dir / "so_volumen_preguntas.csv").write_text(
        "lenguaje,preguntas_nuevas_2025\nPython,20\n",
        encoding="utf-8",
    )

    summary = generate_manifest_public(tmp_path, require_metadata=False)

    assert summary["status"] == "success"
    assert summary["valid"] is True
    assert summary["source_mode"] == "filesystem_fallback"
    assert summary["output_path"] is not None
    assert (tmp_path / "frontend" / "assets" / "data" / "run_manifest.json").exists()


def test_generate_manifest_public_soft_mode_returns_warning_when_invalid(tmp_path):
    summary = generate_manifest_public(tmp_path, require_metadata=False)

    assert summary["status"] == "warning"
    assert summary["valid"] is False
    assert summary["output_path"] is None
    assert not (tmp_path / "frontend" / "assets" / "data" / "run_manifest.json").exists()


def test_generate_manifest_public_required_mode_raises_when_invalid(tmp_path):
    with pytest.raises(RuntimeError):
        generate_manifest_public(tmp_path, require_metadata=True)


def test_generate_manifest_from_final_bridges_writes_both_final_asset_roots(tmp_path):
    latest_dir = tmp_path / "datos" / "latest"
    assets_dir = tmp_path / "frontend" / "assets" / "data"
    remote_dir = tmp_path / "datos" / "metadata" / "remote_assets"
    latest_dir.mkdir(parents=True)
    assets_dir.mkdir(parents=True)
    (latest_dir / "github_lenguajes.csv").write_text("lenguaje,total_repos\nPython,1\n", encoding="utf-8")
    (latest_dir / "so_volumen_preguntas.csv").write_text(
        "lenguaje,preguntas_nuevas_2025\nPython,1\n", encoding="utf-8"
    )
    (latest_dir / "reddit_sentimiento_frameworks.csv").write_text(
        "framework,total_menciones\nPython,1\n", encoding="utf-8"
    )
    (latest_dir / "reddit_temas_emergentes.csv").write_text("tema,menciones\nPython,1\n", encoding="utf-8")
    (latest_dir / "interseccion_github_reddit.csv").write_text("tecnologia,rank\nPython,1\n", encoding="utf-8")
    for filename, dataset, timestamp_field in (
        ("reddit_sentimiento_public.json", "reddit_sentimiento_frameworks", "source_updated_at_utc"),
        ("reddit_temas_history.json", "reddit_temas_emergentes", "generated_at_utc"),
        ("reddit_interseccion_history.json", "interseccion_github_reddit", "generated_at_utc"),
    ):
        (assets_dir / filename).write_text(
            json.dumps(
                {
                    "dataset": dataset,
                    timestamp_field: "2026-08-24T08:17:00Z",
                    "fallback_provenance": {"source": "reddit", "mode": "baseline"},
                }
            ),
            encoding="utf-8",
        )
    (tmp_path / "datos" / "metadata").mkdir(parents=True)
    (tmp_path / "datos" / "metadata" / "run_manifest.json").write_text(
        json.dumps({"generated_at_utc": "2026-08-31T08:17:00Z", "datasets": []}),
        encoding="utf-8",
    )

    summary = generate_manifest_from_final_bridges(
        tmp_path,
        output_dirs=[assets_dir, remote_dir],
        require_metadata=True,
    )

    assert summary["valid"] is True
    frontend_manifest = json.loads((assets_dir / "run_manifest.json").read_text(encoding="utf-8"))
    remote_manifest = json.loads((remote_dir / "run_manifest.json").read_text(encoding="utf-8"))
    assert frontend_manifest == remote_manifest
    assert frontend_manifest["degraded_mode"] is True
    assert frontend_manifest["quality_gate_status"] == "pass_with_warnings"
    assert frontend_manifest["notes"] == "Sources restored from baseline: reddit"
    summaries = {summary["dataset"]: summary["updated_at_utc"] for summary in frontend_manifest["dataset_summaries"]}
    assert summaries["reddit_sentimiento_frameworks"] == "2026-08-24T08:17:00Z"
    assert summaries["reddit_temas_emergentes"] == "2026-08-24T08:17:00Z"
    assert summaries["interseccion_github_reddit"] == "2026-08-24T08:17:00Z"
