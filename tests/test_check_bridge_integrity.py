import json
import shutil

import pytest

from scripts.check_bridge_integrity import check_bridge_integrity
from scripts.download_valid_aggregate_artifact import _validate_candidate
from scripts.hydrate_aggregate_history_seed import hydrate_aggregate_history_seed
from scripts.materialize_etl_artifacts import materialize_artifacts
from scripts.restore_reddit_baseline import restore_reddit_source_baseline


def _write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def _write_healthy_bridge_set(root, *, previous_snapshot_date="2026-03-19", latest_snapshot_date="2026-03-22"):
    assets_dir = root / "frontend" / "assets" / "data"
    _write_json(
        assets_dir / "history_index.json",
        {
            "dataset_count": 9,
            "datasets": [
                {"dataset": "trend_score"},
                {"dataset": "github_commits"},
                {"dataset": "github_correlacion"},
                {"dataset": "github_lenguajes"},
                {"dataset": "so_volumen"},
                {"dataset": "so_aceptacion"},
                {"dataset": "so_tendencias"},
                {"dataset": "reddit_temas"},
                {"dataset": "interseccion"},
            ],
        },
    )
    _write_json(
        assets_dir / "technology_profiles.json",
        {
            "latest_snapshot_date": "2026-03-22",
            "previous_snapshot_date": previous_snapshot_date,
            "profile_count": 22,
        },
    )
    _write_json(
        assets_dir / "home_highlights.json",
        {
            "candidate_count": 3,
            "highlights": [{}, {}, {}],
        },
    )
    _write_json(
        assets_dir / "trend_score_history.json",
        {
            "snapshot_count": 2,
            "snapshots": [{"date": "2026-03-19"}, {"date": "2026-03-22"}],
        },
    )

    for bridge_name in (
        "github_frameworks_history.json",
        "github_correlacion_history.json",
        "so_volumen_history.json",
        "so_aceptacion_history.json",
        "reddit_temas_history.json",
        "reddit_interseccion_history.json",
    ):
        _write_json(
            assets_dir / bridge_name,
            {
                "source_mode": "history",
                "latest_snapshot_date": latest_snapshot_date,
                "previous_snapshot_date": previous_snapshot_date,
            },
        )

    _write_json(
        assets_dir / "so_tendencias_history.json",
        {
            "source_mode": "history",
            "months": ["2026-02", "2026-03"],
            "series": [
                {
                    "technology": "Python",
                    "points": [377, 412],
                }
            ],
        },
    )


def test_bridge_integrity_passes_for_healthy_history(tmp_path):
    _write_healthy_bridge_set(tmp_path)

    summary = check_bridge_integrity(tmp_path, expect_previous_history=True)

    assert summary["status"] == "ok"
    assert summary["home_highlight_count"] == 3


def test_bridge_integrity_fails_when_history_collapses_and_previous_is_missing(tmp_path):
    _write_healthy_bridge_set(tmp_path, previous_snapshot_date=None)
    assets_dir = tmp_path / "frontend" / "assets" / "data"
    _write_json(
        assets_dir / "history_index.json",
        {
            "dataset_count": 1,
            "datasets": [{"dataset": "trend_score"}],
        },
    )
    _write_json(
        assets_dir / "home_highlights.json",
        {
            "candidate_count": 2,
            "highlights": [{}, {}],
        },
    )
    _write_json(
        assets_dir / "reddit_interseccion_history.json",
        {
            "source_mode": "missing",
            "latest_snapshot_date": None,
            "previous_snapshot_date": None,
        },
    )

    with pytest.raises(ValueError, match="history_index"):
        check_bridge_integrity(tmp_path, expect_previous_history=True)


def test_bridge_integrity_allows_bootstrap_without_previous_snapshot(tmp_path):
    _write_healthy_bridge_set(tmp_path, previous_snapshot_date=None)
    assets_dir = tmp_path / "frontend" / "assets" / "data"
    _write_json(
        assets_dir / "trend_score_history.json",
        {
            "snapshot_count": 1,
            "snapshots": [{"date": "2026-03-22"}],
        },
    )
    for bridge_name in (
        "github_frameworks_history.json",
        "github_correlacion_history.json",
        "so_volumen_history.json",
        "so_aceptacion_history.json",
        "reddit_temas_history.json",
        "reddit_interseccion_history.json",
    ):
        _write_json(
            assets_dir / bridge_name,
            {
                "source_mode": "history",
                "latest_snapshot_date": "2026-03-22",
                "previous_snapshot_date": None,
            },
        )

    _write_json(
        assets_dir / "so_tendencias_history.json",
        {
            "source_mode": "history",
            "months": ["2026-03"],
            "series": [
                {
                    "technology": "Python",
                    "points": [377],
                }
            ],
        },
    )

    summary = check_bridge_integrity(tmp_path, expect_previous_history=False)

    assert summary["status"] == "ok"


def test_bridge_integrity_requires_multiple_so_trend_months_when_previous_history_expected(
    tmp_path,
):
    _write_healthy_bridge_set(tmp_path)
    assets_dir = tmp_path / "frontend" / "assets" / "data"
    _write_json(
        assets_dir / "so_tendencias_history.json",
        {
            "source_mode": "history",
            "months": ["2026-03"],
            "series": [
                {
                    "technology": "Python",
                    "points": [377],
                }
            ],
        },
    )

    with pytest.raises(ValueError, match="so_tendencias_history.json months must contain at least 2 entries"):
        check_bridge_integrity(tmp_path, expect_previous_history=True)


def test_bridge_integrity_rejects_home_signal_that_differs_from_canonical_summary(tmp_path):
    _write_healthy_bridge_set(tmp_path)
    assets_dir = tmp_path / "frontend" / "assets" / "data"
    _write_json(
        assets_dir / "github_lenguajes_public.json",
        {
            "summary": {
                "leader": {"lenguaje": "Python", "repos_count": 887, "share_pct": 32.03}
            }
        },
    )
    _write_json(
        assets_dir / "home_highlights.json",
        {
            "candidate_count": 3,
            "highlights": [{}, {}, {}],
            "dashboard_signals": {
                "github": {
                    "graph_1": {
                        "source": "github_lenguajes_public.summary.leader",
                        "payload": {"lenguaje": "Python", "repos_count": 893, "share_pct": 34.94},
                        "summary": {
                            "leader": {"lenguaje": "Python", "repos_count": 893, "share_pct": 34.94}
                        },
                    }
                }
            },
        },
    )

    with pytest.raises(ValueError, match="home_highlights canonical payload mismatch"):
        check_bridge_integrity(tmp_path, expect_previous_history=True)


def test_bridge_integrity_checks_remote_assets_and_rejects_home_mismatch(tmp_path, monkeypatch):
    _write_healthy_bridge_set(tmp_path)
    frontend_root = tmp_path / "frontend" / "assets" / "data"
    remote_root = tmp_path / "datos" / "metadata" / "remote_assets"
    shutil.copytree(frontend_root, remote_root)
    monkeypatch.setenv("FRONTEND_BRIDGE_REMOTE_DIR", "datos/metadata/remote_assets")

    summary = check_bridge_integrity(tmp_path, expect_previous_history=True)
    assert summary["asset_roots_checked"] == 2

    _write_json(
        remote_root / "github_lenguajes_public.json",
        {"summary": {"leader": {"lenguaje": "Python", "repos_count": 883}}},
    )
    _write_json(
        remote_root / "home_highlights.json",
        {
            "candidate_count": 3,
            "highlights": [{}, {}, {}],
            "dashboard_signals": {
                "github": {
                    "graph_1": {
                        "source": "github_lenguajes_public.summary.leader",
                        "payload": {"lenguaje": "Python", "repos_count": 893},
                        "summary": {"leader": {"lenguaje": "Python", "repos_count": 893}},
                    }
                }
            },
        },
    )

    with pytest.raises(ValueError, match="remote_assets.*home_highlights canonical payload mismatch"):
        check_bridge_integrity(tmp_path, expect_previous_history=True)

    shutil.copy2(frontend_root / "home_highlights.json", remote_root / "home_highlights.json")
    remote_index = json.loads((remote_root / "history_index.json").read_text(encoding="utf-8"))
    entry = next(item for item in remote_index["datasets"] if item["dataset"] == "reddit_temas")
    entry["snapshots"] = [{
        "date": "2026-09-14",
        "path": "datos/history/reddit_temas/year=2026/month=09/day=14/reddit_temas_emergentes.csv",
    }]
    _write_json(remote_root / "history_index.json", remote_index)
    with pytest.raises(ValueError, match="remote_assets.*reddit history provenance"):
        check_bridge_integrity(tmp_path)


def _reddit_snapshot(root, dataset, indexed_date, path_date, *, write_csv=False):
    filename = {
        "reddit_temas": "reddit_temas_emergentes.csv",
        "interseccion": "interseccion_github_reddit.csv",
    }[dataset]
    path = f"datos/history/{dataset}/year={path_date[:4]}/month={path_date[5:7]}/day={path_date[8:10]}/{filename}"
    index_path = root / "frontend" / "assets" / "data" / "history_index.json"
    index = json.loads(index_path.read_text(encoding="utf-8"))
    entry = next(item for item in index["datasets"] if item["dataset"] == dataset)
    entry["snapshots"] = [{"date": indexed_date, "path": path}]
    entry["latest_snapshot_date"] = indexed_date
    _write_json(index_path, index)
    if write_csv:
        csv_path = root / path
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        csv_path.write_bytes(b"original reddit bytes\n")
    return root / path


@pytest.mark.parametrize("history_date,expected_valid", [("2026-09-14", False), ("2026-08-31", True), ("2026-08-24", True)])
def test_candidate_validates_preexisting_reddit_history_without_rewriting_it(tmp_path, history_date, expected_valid):
    candidate = tmp_path / "candidate"
    workspace = tmp_path / "workspace"
    _write_healthy_bridge_set(candidate, latest_snapshot_date="2026-08-31")
    for dataset in ("reddit_temas", "interseccion"):
        csv_path = _reddit_snapshot(candidate, dataset, history_date, history_date, write_csv=True)
        (candidate / "datos" / csv_path.name).write_bytes(b"legacy reddit bytes\n")
    for dataset in ("trend_score", "github_commits", "github_correlacion", "so_volumen", "so_aceptacion", "so_tendencias"):
        csv_path = candidate / "datos" / "history" / dataset / "seed.csv"
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        csv_path.write_bytes(b"seed\n")

    materialize_artifacts(workspace, [candidate])
    hydrate_aggregate_history_seed(workspace)
    restored = workspace / "datos/history/reddit_temas" / f"year={history_date[:4]}" / f"month={history_date[5:7]}" / f"day={history_date[8:10]}" / "reddit_temas_emergentes.csv"
    assert restored.read_bytes() == b"original reddit bytes\n"
    valid, reason = _validate_candidate(candidate)
    assert valid is expected_valid
    assert reason is None if expected_valid else "reddit history provenance" in reason
    assert restored.read_bytes() == b"original reddit bytes\n"


def test_final_integrity_rejects_future_history_restored_by_source_fallback(tmp_path):
    project = tmp_path / "project"
    source = tmp_path / "source"
    _write_healthy_bridge_set(project, latest_snapshot_date="2026-08-31")
    _write_healthy_bridge_set(source, latest_snapshot_date="2026-08-31")
    _write_json(source / "frontend/assets/data/reddit_sentimiento_public.json", {})
    for filename in ("reddit_sentimiento_frameworks.csv", "reddit_temas_emergentes.csv", "interseccion_github_reddit.csv"):
        csv_path = source / "datos" / filename
        csv_path.parent.mkdir(parents=True, exist_ok=True)
        csv_path.write_bytes(b"legacy\n")
    restored = _reddit_snapshot(source, "reddit_temas", "2026-09-14", "2026-09-14", write_csv=True)
    hydrate_aggregate_history_seed(project)
    assert not (project / restored.relative_to(source)).exists()
    restore_reddit_source_baseline(project, [source])
    assert (project / restored.relative_to(source)).read_bytes() == b"original reddit bytes\n"
    with pytest.raises(ValueError, match="reddit history provenance"):
        check_bridge_integrity(project)


@pytest.mark.parametrize(
    ("indexed_date", "path_date", "valid", "write_csv"),
    [
        ("2026-08-24", "2026-08-24", True, True),
        ("2026-08-31", "2026-08-31", True, True),
        ("2026-08-24", "2026-09-14", False, True),
        ("2026-09-14", "2026-09-14", False, False),
        ("2026-02-30", "2026-02-30", False, True),
        ("2026-8-24", "2026-08-24", False, True),
    ],
)
def test_reddit_index_dates_match_partition_and_do_not_exceed_canonical(tmp_path, indexed_date, path_date, valid, write_csv):
    _write_healthy_bridge_set(tmp_path, latest_snapshot_date="2026-08-31")
    _reddit_snapshot(tmp_path, "reddit_temas", indexed_date, path_date, write_csv=write_csv)
    if valid:
        assert check_bridge_integrity(tmp_path)["status"] == "ok"
    else:
        with pytest.raises(ValueError, match="reddit history provenance"):
            check_bridge_integrity(tmp_path)


def test_unindexed_reddit_history_is_checked_but_non_reddit_history_is_unchanged(tmp_path):
    _write_healthy_bridge_set(tmp_path, latest_snapshot_date="2026-08-31")
    non_reddit = tmp_path / "datos/history/trend_score/year=2026/month=09/day=14/trend_score.csv"
    non_reddit.parent.mkdir(parents=True)
    non_reddit.write_bytes(b"unrelated\n")
    assert check_bridge_integrity(tmp_path)["status"] == "ok"
    unindexed = tmp_path / "datos/history/interseccion/year=2026/month=09/day=14/interseccion_github_reddit.csv"
    unindexed.parent.mkdir(parents=True)
    unindexed.write_bytes(b"unindexed\n")
    with pytest.raises(ValueError, match="reddit history provenance"):
        check_bridge_integrity(tmp_path)
