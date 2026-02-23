import json
from pathlib import Path

import export_history_json


def test_export_bridge_assets_generates_history_and_trend_json(tmp_path):
    project_root = tmp_path
    history_dir = project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=02" / "day=22"
    latest_dir = project_root / "datos" / "latest"

    history_dir.mkdir(parents=True, exist_ok=True)
    latest_dir.mkdir(parents=True, exist_ok=True)
    (project_root / "frontend" / "assets" / "data").mkdir(parents=True, exist_ok=True)

    trend_csv_content = (
        "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
        "1,Python,100,100,5.8,76.45,3\n"
        "2,TypeScript,70.7,17.7,1.0,34.74,3\n"
    )
    (history_dir / "trend_score.csv").write_text(trend_csv_content, encoding="utf-8")
    (latest_dir / "trend_score.csv").write_text(trend_csv_content, encoding="utf-8")

    summary = export_history_json.export_bridge_assets(project_root)

    assert summary["files_written"] == 2
    history_index = project_root / "frontend" / "assets" / "data" / "history_index.json"
    trend_history = project_root / "frontend" / "assets" / "data" / "trend_score_history.json"

    assert history_index.exists()
    assert trend_history.exists()

    history_payload = json.loads(history_index.read_text(encoding="utf-8"))
    trend_payload = json.loads(trend_history.read_text(encoding="utf-8"))

    assert history_payload["dataset_count"] >= 1
    assert any(dataset["dataset"] == "trend_score" for dataset in history_payload["datasets"])
    assert trend_payload["snapshot_count"] == 1
    assert trend_payload["snapshots"][0]["source_type"] == "history"
    assert trend_payload["snapshots"][0]["top_10"][0]["tecnologia"] == "Python"


def test_build_trend_score_history_falls_back_to_latest_when_history_missing(tmp_path):
    project_root = tmp_path
    latest_dir = project_root / "datos" / "latest"
    latest_dir.mkdir(parents=True, exist_ok=True)
    (project_root / "frontend" / "assets" / "data").mkdir(parents=True, exist_ok=True)

    (latest_dir / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,100,100,5.8,76.45,3\n"
            "2,TypeScript,70.7,17.7,1.0,34.74,3\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    trend_payload = export_history_json.build_trend_score_history(project_root, history_index)

    assert trend_payload["snapshot_count"] == 1
    assert trend_payload["snapshots"][0]["source_type"] == "latest"
    assert len(trend_payload["series"]) == 2


def test_build_trend_score_history_falls_back_to_latest_when_history_is_corrupted(tmp_path):
    project_root = tmp_path
    history_dir = project_root / "datos" / "history" / "trend_score" / "year=2026" / "month=02" / "day=22"
    latest_dir = project_root / "datos" / "latest"

    history_dir.mkdir(parents=True, exist_ok=True)
    latest_dir.mkdir(parents=True, exist_ok=True)
    (project_root / "frontend" / "assets" / "data").mkdir(parents=True, exist_ok=True)

    # Corrupted history schema for trend snapshot (missing required columns).
    (history_dir / "trend_score.csv").write_text(
        "foo,bar\n1,2\n",
        encoding="utf-8",
    )
    (latest_dir / "trend_score.csv").write_text(
        (
            "ranking,tecnologia,github_score,so_score,reddit_score,trend_score,fuentes\n"
            "1,Python,100,100,5.8,76.45,3\n"
            "2,TypeScript,70.7,17.7,1.0,34.74,3\n"
        ),
        encoding="utf-8",
    )

    history_index = export_history_json.build_history_index(project_root)
    trend_payload = export_history_json.build_trend_score_history(project_root, history_index)

    assert trend_payload["snapshot_count"] == 1
    assert trend_payload["snapshots"][0]["source_type"] == "latest"
    assert trend_payload["snapshots"][0]["top_10"][0]["tecnologia"] == "Python"
