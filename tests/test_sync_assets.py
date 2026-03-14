from pathlib import Path

import pytest

import sync_assets


@pytest.fixture(autouse=True)
def _default_assets_policy_mode(monkeypatch):
    monkeypatch.setenv("FRONTEND_ASSETS_POLICY_MODE", "warning")


def test_sincronizar_copies_only_csv_files(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)

    (datos_dir / "trend_score.csv").write_text("col\n1\n", encoding="utf-8")
    (datos_dir / "github_lenguajes.csv").write_text("col\n2\n", encoding="utf-8")
    (datos_dir / "notes.txt").write_text("ignore", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    sync_assets.sincronizar()

    assert (destino_dir / "trend_score.csv").exists()
    assert (destino_dir / "github_lenguajes.csv").exists()
    assert not (destino_dir / "notes.txt").exists()


def test_sincronizar_creates_destination_if_missing(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)

    (datos_dir / "trend_score.csv").write_text("x\n1\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    assert not destino_dir.exists()
    sync_assets.sincronizar()
    assert destino_dir.exists()
    assert (destino_dir / "trend_score.csv").exists()


def test_sincronizar_overwrites_existing_csv(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    destino_dir.mkdir(parents=True)

    (datos_dir / "trend_score.csv").write_text("v\n2\n", encoding="utf-8")
    (destino_dir / "trend_score.csv").write_text("v\n1\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    sync_assets.sincronizar()

    assert (destino_dir / "trend_score.csv").read_text(encoding="utf-8") == "v\n2\n"


def test_sincronizar_returns_summary(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    (datos_dir / "trend_score.csv").write_text("a\n1\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    summary = sync_assets.sincronizar()

    assert summary["files_copied"] == 1
    assert summary["errors"] == 0


def test_sincronizar_prefers_latest_directory_when_available(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    latest_dir = datos_dir / "latest"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    latest_dir.mkdir(parents=True)

    (datos_dir / "trend_score.csv").write_text("v\nlegacy\n", encoding="utf-8")
    (latest_dir / "trend_score.csv").write_text("v\nlatest\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    summary = sync_assets.sincronizar()

    assert summary["files_copied"] == 1
    assert (destino_dir / "trend_score.csv").read_text(encoding="utf-8") == "v\nlatest\n"
    assert summary["source_mode"] == "latest"
    assert summary["source"].endswith(str(Path("datos") / "latest"))


def test_sincronizar_prefers_richer_schema_over_latest_stale_file(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    latest_dir = datos_dir / "latest"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    latest_dir.mkdir(parents=True)

    legacy_csv = (
        "framework,repo,commits_2025,active_contributors,merged_prs,closed_issues,releases_count,ranking\n"
        "Angular,angular/angular,100,10,50,20,3,1\n"
    )
    latest_csv = (
        "framework,repo,commits_2025,ranking\n"
        "Angular,angular/angular,90,1\n"
    )
    (datos_dir / "github_commits_frameworks.csv").write_text(
        legacy_csv,
        encoding="utf-8",
    )
    (latest_dir / "github_commits_frameworks.csv").write_text(
        latest_csv,
        encoding="utf-8",
    )

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "0")

    summary = sync_assets.sincronizar()

    assert summary["files_copied"] == 1
    assert (destino_dir / "github_commits_frameworks.csv").read_text(
        encoding="utf-8"
    ) == legacy_csv


def test_sincronizar_uses_latest_per_file_with_legacy_fallback(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    latest_dir = datos_dir / "latest"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    latest_dir.mkdir(parents=True)

    (datos_dir / "github_lenguajes.csv").write_text("lang\nlegacy\n", encoding="utf-8")
    (datos_dir / "trend_score.csv").write_text("score\nlegacy\n", encoding="utf-8")
    (latest_dir / "trend_score.csv").write_text("score\nlatest\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "0")

    summary = sync_assets.sincronizar()

    assert summary["files_copied"] == 2
    assert summary["source_mode"] == "mixed"
    assert summary["source"] == "mixed(latest+legacy)"
    assert (destino_dir / "trend_score.csv").read_text(encoding="utf-8") == "score\nlatest\n"
    assert (destino_dir / "github_lenguajes.csv").read_text(encoding="utf-8") == "lang\nlegacy\n"


def test_sincronizar_generates_bridge_json_when_enabled(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    latest_dir = datos_dir / "latest"
    history_dir = datos_dir / "history" / "trend_score" / "year=2026" / "month=02" / "day=22"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    latest_dir.mkdir(parents=True)
    history_dir.mkdir(parents=True)

    trend_csv = (
        "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
        "1,Python,100,100,5.8,76.45,3\n"
    )
    (latest_dir / "trend_score.csv").write_text(trend_csv, encoding="utf-8")
    (history_dir / "trend_score.csv").write_text(trend_csv, encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "1")

    summary = sync_assets.sincronizar()

    assert summary["bridge_export_enabled"] is True
    assert summary["bridge_files_written"] == 13
    assert summary["public_manifest_enabled"] is True
    assert summary["public_manifest_written"] is True
    assert (destino_dir / "history_index.json").exists()
    assert (destino_dir / "trend_score_history.json").exists()
    assert (destino_dir / "reddit_sentimiento_public.json").exists()
    assert (destino_dir / "reddit_temas_history.json").exists()
    assert (destino_dir / "reddit_interseccion_history.json").exists()
    assert (destino_dir / "github_lenguajes_public.json").exists()
    assert (destino_dir / "github_frameworks_history.json").exists()
    assert (destino_dir / "github_correlacion_history.json").exists()
    assert (destino_dir / "home_highlights.json").exists()
    assert (destino_dir / "so_volumen_history.json").exists()
    assert (destino_dir / "so_aceptacion_history.json").exists()
    assert (destino_dir / "so_tendencias_history.json").exists()
    assert (destino_dir / "technology_profiles.json").exists()
    assert (destino_dir / "run_manifest.json").exists()


def test_sincronizar_skips_bridge_json_when_disabled(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    latest_dir = datos_dir / "latest"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    latest_dir.mkdir(parents=True)
    (latest_dir / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,100,100,5.8,76.45,3\n"
        ),
        encoding="utf-8",
    )

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "0")

    summary = sync_assets.sincronizar()

    assert summary["bridge_export_enabled"] is False
    assert summary["bridge_files_written"] == 0
    assert summary["public_manifest_enabled"] is True
    assert summary["public_manifest_written"] is True
    assert not (destino_dir / "history_index.json").exists()
    assert not (destino_dir / "trend_score_history.json").exists()
    assert (destino_dir / "run_manifest.json").exists()


def test_sincronizar_public_manifest_soft_mode_when_missing_metadata(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    destino_dir.mkdir(parents=True)

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("USE_PUBLIC_RUN_MANIFEST", "1")
    monkeypatch.setenv("REQUIRE_FRONTEND_METADATA", "0")
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "0")

    summary = sync_assets.sincronizar()

    assert summary["errors"] == 0
    assert summary["public_manifest_enabled"] is True
    assert summary["public_manifest_required"] is False
    assert summary["public_manifest_written"] is False
    assert summary["public_manifest_status"] == "warning"
    assert not (destino_dir / "run_manifest.json").exists()


def test_sincronizar_public_manifest_strict_mode_counts_error(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    destino_dir.mkdir(parents=True)

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("USE_PUBLIC_RUN_MANIFEST", "1")
    monkeypatch.setenv("REQUIRE_FRONTEND_METADATA", "1")
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "0")

    summary = sync_assets.sincronizar()

    assert summary["errors"] == 1
    assert summary["public_manifest_enabled"] is True
    assert summary["public_manifest_required"] is True
    assert summary["public_manifest_written"] is False
    assert summary["public_manifest_status"] == "failed"
    assert not (destino_dir / "run_manifest.json").exists()


def test_sincronizar_skips_csv_not_allowlisted(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    destino_dir.mkdir(parents=True)

    (datos_dir / "trend_score.csv").write_text("score\n1\n", encoding="utf-8")
    (datos_dir / "github_repos_2025.csv").write_text("repo\nx\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "0")
    monkeypatch.setenv("USE_PUBLIC_RUN_MANIFEST", "0")

    summary = sync_assets.sincronizar()

    assert (destino_dir / "trend_score.csv").exists()
    assert not (destino_dir / "github_repos_2025.csv").exists()
    assert "github_repos_2025.csv" in summary["skipped_not_allowlisted"]


def test_sincronizar_strict_assets_policy_adds_errors_for_missing_required(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    (datos_dir / "trend_score.csv").write_text("score\n1\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))
    monkeypatch.setenv("EXPORT_HISTORY_BRIDGE_JSON", "0")
    monkeypatch.setenv("USE_PUBLIC_RUN_MANIFEST", "0")
    monkeypatch.setenv("FRONTEND_ASSETS_POLICY_MODE", "strict")

    summary = sync_assets.sincronizar()

    assert summary["assets_policy_mode"] == "strict"
    assert summary["files_copied"] == 1
    assert summary["errors"] > 0
