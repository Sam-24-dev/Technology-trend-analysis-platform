from __future__ import annotations

import pytest

from generate_run_manifest import generate_manifest_public


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
