import json

from scripts.hydrate_aggregate_history_seed import hydrate_aggregate_history_seed


def _write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def test_hydrate_aggregate_history_seed_rebuilds_latest_and_history_from_legacy_csv(
    tmp_path,
):
    project_root = tmp_path
    (project_root / "datos").mkdir(parents=True, exist_ok=True)
    (project_root / "datos" / "github_commits_frameworks.csv").write_text(
        "framework,commits_2025\nNext.js,5000\n",
        encoding="utf-8",
    )
    _write_json(
        project_root / "frontend" / "assets" / "data" / "history_index.json",
        {
            "datasets": [
                {
                    "dataset": "github_commits",
                    "latest_path": "datos/latest/github_commits_frameworks.csv",
                    "snapshots": [
                        {
                            "date": "2026-03-16",
                            "path": "datos/history/github_commits/year=2026/month=03/day=16/github_commits_frameworks.csv",
                        }
                    ],
                }
            ]
        },
    )

    summary = hydrate_aggregate_history_seed(project_root)

    assert summary["dataset_count"] == 1
    assert summary["seeded_latest_files"] == 1
    assert summary["seeded_history_files"] == 1
    assert (
        project_root / "datos" / "latest" / "github_commits_frameworks.csv"
    ).exists()
    assert (
        project_root
        / "datos"
        / "history"
        / "github_commits"
        / "year=2026"
        / "month=03"
        / "day=16"
        / "github_commits_frameworks.csv"
    ).exists()


def test_hydrate_aggregate_history_seed_does_not_overwrite_existing_targets(tmp_path):
    project_root = tmp_path
    (project_root / "datos").mkdir(parents=True, exist_ok=True)
    (project_root / "datos" / "trend_score.csv").write_text(
        "ranking,tecnologia,trend_score\n1,Python,80\n",
        encoding="utf-8",
    )
    latest_target = project_root / "datos" / "latest" / "trend_score.csv"
    history_target = (
        project_root
        / "datos"
        / "history"
        / "trend_score"
        / "year=2026"
        / "month=03"
        / "day=16"
        / "trend_score.csv"
    )
    latest_target.parent.mkdir(parents=True, exist_ok=True)
    history_target.parent.mkdir(parents=True, exist_ok=True)
    latest_target.write_text("existing latest\n", encoding="utf-8")
    history_target.write_text("existing history\n", encoding="utf-8")
    _write_json(
        project_root / "frontend" / "assets" / "data" / "history_index.json",
        {
            "datasets": [
                {
                    "dataset": "trend_score",
                    "latest_path": "datos/latest/trend_score.csv",
                    "snapshots": [
                        {
                            "date": "2026-03-16",
                            "path": "datos/history/trend_score/year=2026/month=03/day=16/trend_score.csv",
                        }
                    ],
                }
            ]
        },
    )

    summary = hydrate_aggregate_history_seed(project_root)

    assert summary["seeded_latest_files"] == 0
    assert summary["seeded_history_files"] == 0
    assert latest_target.read_text(encoding="utf-8") == "existing latest\n"
    assert history_target.read_text(encoding="utf-8") == "existing history\n"
