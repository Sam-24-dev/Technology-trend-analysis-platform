import json

import pytest

from scripts.check_bridge_integrity import check_bridge_integrity


def _write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def _write_healthy_bridge_set(root, *, previous_snapshot_date="2026-03-19"):
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
        "so_tendencias_history.json",
        "reddit_temas_history.json",
        "reddit_interseccion_history.json",
    ):
        _write_json(
            assets_dir / bridge_name,
            {
                "source_mode": "history",
                "latest_snapshot_date": "2026-03-22",
                "previous_snapshot_date": previous_snapshot_date,
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
        "so_tendencias_history.json",
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

    summary = check_bridge_integrity(tmp_path, expect_previous_history=False)

    assert summary["status"] == "ok"
