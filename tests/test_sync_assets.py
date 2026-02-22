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
    assert summary["source"].endswith(str(Path("datos") / "latest"))
