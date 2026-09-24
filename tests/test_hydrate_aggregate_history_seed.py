import json

import pytest

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


@pytest.mark.parametrize(
    ("dataset", "filename"),
    [
        ("reddit_temas", "reddit_temas_emergentes.csv"),
        ("interseccion", "interseccion_github_reddit.csv"),
        ("reddit_sentimiento", "reddit_sentimiento_frameworks.csv"),
    ],
)
@pytest.mark.parametrize(
    ("indexed_date", "path_date", "topics_date", "intersection_date", "expected_seed"),
    [
        pytest.param("2026-09-14", "year=2026/month=09/day=14", "2026-08-31", "2026-08-31", False, id="stale-index"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-08-31", "2026-08-31", True, id="matching-dates"),
        pytest.param("2026-08-31", "year=2026/month=09/day=14", "2026-08-31", "2026-08-31", False, id="stale-path"),
        pytest.param(None, "year=2026/month=08/day=31", "2026-08-31", "2026-08-31", False, id="missing-index-date"),
        pytest.param("2026-8-31", "year=2026/month=08/day=31", "2026-08-31", "2026-08-31", False, id="malformed-index-date"),
        pytest.param("2026-02-30", "year=2026/month=08/day=31", "2026-08-31", "2026-08-31", False, id="invalid-index-date"),
        pytest.param("2026-08-31", "month=08/day=31", "2026-08-31", "2026-08-31", False, id="missing-path-year"),
        pytest.param("2026-08-31", "year=2026/day=31", "2026-08-31", "2026-08-31", False, id="missing-path-month"),
        pytest.param("2026-08-31", "year=2026/month=08", "2026-08-31", "2026-08-31", False, id="missing-path-day"),
        pytest.param("2026-08-31", "year=26/month=08/day=31", "2026-08-31", "2026-08-31", False, id="malformed-path-year"),
        pytest.param("2026-08-31", "year=2026/month=8/day=31", "2026-08-31", "2026-08-31", False, id="malformed-path-month"),
        pytest.param("2026-08-31", "year=2026/month=08/day=1", "2026-08-31", "2026-08-31", False, id="malformed-path-day"),
        pytest.param("2026-08-31", "year=2026/month=02/day=30", "2026-08-31", "2026-08-31", False, id="invalid-path-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", None, "2026-08-31", False, id="missing-topics-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "", "2026-08-31", False, id="empty-topics-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-8-31", "2026-08-31", False, id="malformed-topics-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-02-30", "2026-08-31", False, id="invalid-topics-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-08-31", None, False, id="missing-intersection-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-08-31", "", False, id="empty-intersection-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-08-31", "2026-8-31", False, id="malformed-intersection-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-08-31", "2026-02-30", False, id="invalid-intersection-date"),
        pytest.param("2026-08-31", "year=2026/month=08/day=31", "2026-08-31", "2026-09-14", False, id="bridge-date-disagreement"),
    ],
)
def test_reddit_history_seed_requires_matching_canonical_date(
    tmp_path, dataset, filename, indexed_date, path_date, topics_date, intersection_date, expected_seed
):
    project_root = tmp_path
    source = project_root / "datos" / filename
    source.parent.mkdir(parents=True)
    source.write_text("legacy reddit data\n", encoding="utf-8")
    assets = project_root / "frontend" / "assets" / "data"
    for bridge, bridge_date in (
        ("reddit_temas_history.json", topics_date),
        ("reddit_interseccion_history.json", intersection_date),
    ):
        _write_json(
            assets / bridge,
            {} if bridge_date is None else {"latest_snapshot_date": bridge_date},
        )

    canonical_seed = (
        project_root
        / "datos"
        / "history"
        / dataset
        / "year=2026"
        / "month=08"
        / "day=31"
        / filename
    )
    if indexed_date == "2026-09-14":
        canonical_seed.parent.mkdir(parents=True)
        canonical_seed.write_text("canonical baseline\n", encoding="utf-8")
    target = (
        project_root
        / "datos"
        / "history"
        / dataset
        / path_date
        / filename
    )
    _write_json(
        assets / "history_index.json",
        {
            "datasets": [
                {
                    "dataset": dataset,
                    "latest_path": f"datos/latest/{filename}",
                    "snapshots": [
                        {
                            "date": indexed_date,
                            "path": target.relative_to(project_root).as_posix(),
                        }
                    ],
                }
            ]
        },
    )

    summary = hydrate_aggregate_history_seed(project_root)

    assert target.exists() is expected_seed
    assert summary["seeded_history_files"] == int(expected_seed)
    assert summary["seeded_latest_files"] == 1
    assert (project_root / "datos" / "latest" / filename).exists()
    if indexed_date == "2026-09-14":
        assert canonical_seed.read_text(encoding="utf-8") == "canonical baseline\n"


@pytest.mark.parametrize(
    "destination", [
        lambda project_root: str(project_root.parent / "escaped.csv"),
        lambda project_root: "../../escaped.csv",
    ],
    ids=["absolute", "traversal"],
)
@pytest.mark.parametrize("path_kind", ["latest", "snapshot"])
def test_hydrate_aggregate_history_seed_rejects_unsafe_artifact_destinations(
    tmp_path, destination, path_kind
):
    project_root = tmp_path / "project"
    (project_root / "datos").mkdir(parents=True)
    (project_root / "datos" / "trend_score.csv").write_text(
        "ranking,tecnologia,trend_score\n1,Python,80\n", encoding="utf-8"
    )
    destination_path = destination(project_root)
    dataset_entry = {
        "dataset": "trend_score",
        "latest_path": destination_path if path_kind == "latest" else None,
        "snapshots": ([{"path": destination_path}] if path_kind == "snapshot" else []),
    }
    _write_json(
        project_root / "frontend" / "assets" / "data" / "history_index.json",
        {
            "datasets": [dataset_entry]
        },
    )

    with pytest.raises(ValueError, match="unsafe artifact destination"):
        hydrate_aggregate_history_seed(project_root)

    assert not (project_root.parent / "escaped.csv").exists()
