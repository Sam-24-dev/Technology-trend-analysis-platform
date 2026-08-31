from __future__ import annotations

import json
import os
from datetime import datetime, timezone

from config.run_manifest_public_contract import (
    build_public_run_manifest_from_filesystem,
    build_public_run_manifest_from_internal,
    generate_public_run_manifest,
    load_public_manifest_schema,
    validate_public_run_manifest,
)


def _valid_public_manifest():
    return {
        "manifest_version": "1.0.0",
        "generated_at_utc": "2026-02-23T10:00:00Z",
        "source_window_start_utc": "2025-02-23T00:00:00Z",
        "source_window_end_utc": "2026-02-23T00:00:00Z",
        "quality_gate_status": "pass_with_warnings",
        "degraded_mode": True,
        "available_sources": ["github", "stackoverflow"],
        "dataset_summaries": [
            {
                "dataset": "trend_score",
                "row_count": 23,
                "quality_status": "pass",
                "updated_at_utc": "2026-02-23T09:59:30Z",
            }
        ],
        "total_repos_extraidos": 1000,
        "total_repos_clasificables": 925,
        "so_languages_count": 10,
        "notes": "Reddit temporalmente no disponible",
    }


def test_load_public_manifest_schema():
    schema = load_public_manifest_schema()
    assert schema["title"] == "RunManifestPublic"
    assert "dataset_summaries" in schema["properties"]


def test_validate_public_run_manifest_valid_case():
    is_valid, errors = validate_public_run_manifest(_valid_public_manifest())
    assert is_valid is True
    assert errors == []


def test_validate_public_run_manifest_invalid_case():
    payload = {
        "manifest_version": "1",
        "generated_at_utc": "23-02-2026",
        "quality_gate_status": "ok",
        "degraded_mode": "true",
        "available_sources": ["github", "github"],
        "dataset_summaries": [],
    }
    is_valid, errors = validate_public_run_manifest(payload)
    assert is_valid is False
    assert any("manifest_version" in error for error in errors)
    assert any("degraded_mode" in error for error in errors)
    assert any("dataset_summaries" in error for error in errors)


def test_build_public_run_manifest_from_internal():
    internal = {
        "generated_at_utc": "2026-02-24T12:00:00Z",
        "source_window_start_utc": "2025-02-24T00:00:00Z",
        "source_window_end_utc": "2026-02-24T00:00:00Z",
        "quality_gate_status": "pass_with_warnings",
        "datasets": [
            {
                "dataset_logical_name": "github_lenguajes",
                "row_count": 10,
                "quality_status": "pass",
                "generated_at_utc": "2026-02-24T11:59:00Z",
            },
            {
                "dataset_logical_name": "so_volumen",
                "row_count": 20,
                "quality_status": "pass",
                "generated_at_utc": "2026-02-24T11:58:00Z",
            },
        ],
    }

    payload = build_public_run_manifest_from_internal(
        internal,
        default_window_start_utc="2025-02-24T00:00:00Z",
        default_window_end_utc="2026-02-24T00:00:00Z",
    )
    is_valid, errors = validate_public_run_manifest(payload)

    assert is_valid is True
    assert errors == []
    assert payload["degraded_mode"] is True
    assert payload["available_sources"] == ["github", "stackoverflow"]
    assert "total_repos_extraidos" in payload
    assert "total_repos_clasificables" in payload
    assert "so_languages_count" in payload


def test_build_public_run_manifest_from_filesystem(tmp_path):
    latest_dir = tmp_path / "datos" / "latest"
    latest_dir.mkdir(parents=True)
    (latest_dir / "github_lenguajes.csv").write_text("lenguaje,total_repos\nPython,10\n", encoding="utf-8")
    (latest_dir / "so_volumen_preguntas.csv").write_text("lenguaje,preguntas_nuevas_2025\nPython,20\n", encoding="utf-8")
    (latest_dir / "trend_score.csv").write_text(
        "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n1,Python,100,100,0,75,2\n",
        encoding="utf-8",
    )

    payload = build_public_run_manifest_from_filesystem(tmp_path)
    is_valid, errors = validate_public_run_manifest(payload)

    assert is_valid is True
    assert errors == []
    assert payload["degraded_mode"] is True
    assert payload["available_sources"] == ["github", "stackoverflow"]
    assert "total_repos_extraidos" in payload
    assert "total_repos_clasificables" in payload
    assert "so_languages_count" in payload
    assert len(payload["dataset_summaries"]) >= 1


def test_generate_public_run_manifest_prefers_internal(tmp_path):
    metadata_dir = tmp_path / "datos" / "metadata"
    metadata_dir.mkdir(parents=True)
    internal = {
        "generated_at_utc": "2026-02-24T12:00:00Z",
        "source_window_start_utc": "2025-02-24T00:00:00Z",
        "source_window_end_utc": "2026-02-24T00:00:00Z",
        "quality_gate_status": "pass",
        "datasets": [
            {
                "dataset_logical_name": "github_lenguajes",
                "row_count": 10,
                "quality_status": "pass",
                "generated_at_utc": "2026-02-24T11:59:00Z",
            }
        ],
    }
    (metadata_dir / "run_manifest.json").write_text(json.dumps(internal), encoding="utf-8")

    generation = generate_public_run_manifest(tmp_path)
    assert generation["valid"] is True
    assert generation["source_mode"] == "internal_manifest"


def test_generate_public_run_manifest_fallbacks_when_internal_is_invalid(tmp_path):
    metadata_dir = tmp_path / "datos" / "metadata"
    latest_dir = tmp_path / "datos" / "latest"
    metadata_dir.mkdir(parents=True)
    latest_dir.mkdir(parents=True)

    invalid_internal = {
        "generated_at_utc": "invalid-date",
        "datasets": [],
    }
    (metadata_dir / "run_manifest.json").write_text(json.dumps(invalid_internal), encoding="utf-8")
    (latest_dir / "trend_score.csv").write_text(
        "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n1,Python,100,100,0,75,2\n",
        encoding="utf-8",
    )
    (latest_dir / "github_lenguajes.csv").write_text("lenguaje,total_repos\nPython,10\n", encoding="utf-8")
    (latest_dir / "so_volumen_preguntas.csv").write_text(
        "lenguaje,preguntas_nuevas_2025\nPython,20\n",
        encoding="utf-8",
    )

    generation = generate_public_run_manifest(tmp_path)
    assert generation["valid"] is True
    assert generation["source_mode"] == "filesystem_fallback_after_internal_invalid"


def test_filesystem_manifest_uses_canonical_bridge_metadata_for_mixed_source_freshness(tmp_path):
    latest_dir = tmp_path / "datos" / "latest"
    assets_dir = tmp_path / "frontend" / "assets" / "data"
    latest_dir.mkdir(parents=True)
    assets_dir.mkdir(parents=True)

    (latest_dir / "github_repos_2025.csv").write_text(
        "language\nPython\nTypeScript\nAI/ML\n",
        encoding="utf-8",
    )
    (latest_dir / "github_lenguajes.csv").write_text(
        "lenguaje,repos_count\nPython,2\nTypeScript,1\n",
        encoding="utf-8",
    )
    (latest_dir / "so_volumen_preguntas.csv").write_text(
        "lenguaje,preguntas_nuevas_2025\npython,20\ntypescript,10\n",
        encoding="utf-8",
    )
    (latest_dir / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nIA/Machine Learning,555\n",
        encoding="utf-8",
    )
    (latest_dir / "trend_score.csv").write_text(
        "ranking,tecnologia,trend_score\n1,Python,91.59\n",
        encoding="utf-8",
    )

    (assets_dir / "github_lenguajes_public.json").write_text(
        json.dumps(
            {
                "generated_at_utc": "2026-08-24T09:07:33Z",
                "source_updated_at_utc": "2026-08-24T09:07:25Z",
                "language_count": 2,
                "summary": {"total_classifiable_repos": 2},
            }
        ),
        encoding="utf-8",
    )
    (assets_dir / "so_volumen_history.json").write_text(
        json.dumps({"generated_at_utc": "2026-08-24T09:07:34Z", "item_count": 2}),
        encoding="utf-8",
    )
    (assets_dir / "reddit_temas_history.json").write_text(
        json.dumps({"generated_at_utc": "2026-08-31T03:47:08Z", "topic_count": 1}),
        encoding="utf-8",
    )
    (assets_dir / "trend_score_history.json").write_text(
        json.dumps({"generated_at_utc": "2026-08-31T03:47:07Z"}),
        encoding="utf-8",
    )

    stale_mtime = datetime(2026, 7, 6, tzinfo=timezone.utc).timestamp()
    for path in latest_dir.glob("*.csv"):
        os.utime(path, (stale_mtime, stale_mtime))

    payload = build_public_run_manifest_from_filesystem(tmp_path)
    summaries = {item["dataset"]: item for item in payload["dataset_summaries"]}

    assert summaries["github_lenguajes"]["updated_at_utc"] == "2026-08-24T09:07:25Z"
    assert summaries["so_volumen_preguntas"]["updated_at_utc"] == "2026-08-24T09:07:34Z"
    assert summaries["reddit_temas_emergentes"]["updated_at_utc"] == "2026-08-31T03:47:08Z"
    assert summaries["trend_score"]["updated_at_utc"] == "2026-08-31T03:47:07Z"
    assert payload["total_repos_extraidos"] == 3
    assert payload["total_repos_clasificables"] == 2
    assert payload["so_languages_count"] == 2
