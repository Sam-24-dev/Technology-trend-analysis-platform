from pathlib import Path

import sync_assets


def test_sincronizar_copies_only_csv_files(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)

    (datos_dir / "a.csv").write_text("col\n1\n", encoding="utf-8")
    (datos_dir / "b.csv").write_text("col\n2\n", encoding="utf-8")
    (datos_dir / "notes.txt").write_text("ignore", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    sync_assets.sincronizar()

    assert (destino_dir / "a.csv").exists()
    assert (destino_dir / "b.csv").exists()
    assert not (destino_dir / "notes.txt").exists()


def test_sincronizar_creates_destination_if_missing(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)

    (datos_dir / "only.csv").write_text("x\n1\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    assert not destino_dir.exists()
    sync_assets.sincronizar()
    assert destino_dir.exists()
    assert (destino_dir / "only.csv").exists()


def test_sincronizar_overwrites_existing_csv(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"
    destino_dir = project_root / "frontend" / "assets" / "data"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    destino_dir.mkdir(parents=True)

    (datos_dir / "dup.csv").write_text("v\n2\n", encoding="utf-8")
    (destino_dir / "dup.csv").write_text("v\n1\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    sync_assets.sincronizar()

    assert (destino_dir / "dup.csv").read_text(encoding="utf-8") == "v\n2\n"


def test_sincronizar_returns_summary(tmp_path, monkeypatch):
    project_root = tmp_path
    backend_dir = project_root / "backend"
    datos_dir = project_root / "datos"

    backend_dir.mkdir(parents=True)
    datos_dir.mkdir(parents=True)
    (datos_dir / "one.csv").write_text("a\n1\n", encoding="utf-8")

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

    (datos_dir / "same.csv").write_text("v\nlegacy\n", encoding="utf-8")
    (latest_dir / "same.csv").write_text("v\nlatest\n", encoding="utf-8")

    monkeypatch.setattr(sync_assets, "__file__", str(backend_dir / "sync_assets.py"))

    summary = sync_assets.sincronizar()

    assert summary["files_copied"] == 1
    assert (destino_dir / "same.csv").read_text(encoding="utf-8") == "v\nlatest\n"
    assert summary["source_mode"] == "latest"
    assert summary["source"].endswith(str(Path("datos") / "latest"))


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
    assert summary["bridge_files_written"] == 2
    assert (destino_dir / "history_index.json").exists()
    assert (destino_dir / "trend_score_history.json").exists()


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
    assert not (destino_dir / "history_index.json").exists()
    assert not (destino_dir / "trend_score_history.json").exists()
