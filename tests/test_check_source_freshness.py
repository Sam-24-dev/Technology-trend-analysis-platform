import json

import pytest

from scripts.check_source_freshness import check_source_freshness


CANONICAL_DATASETS = {
    "github": (
        "github_ai_repos_insights",
        "github_commits_frameworks",
        "github_commits_frameworks_monthly",
        "github_correlacion",
        "github_lenguajes",
        "github_repos_2025",
    ),
    "stackoverflow": (
        "so_volumen_preguntas",
        "so_tasa_aceptacion",
        "so_tendencias_mensuales",
    ),
    "reddit": (
        "reddit_sentimiento_frameworks",
        "reddit_temas_emergentes",
        "interseccion_github_reddit",
    ),
}


def _write_manifest(
    tmp_path,
    *,
    updated_at_by_dataset=None,
    missing_datasets=(),
    prepended_summaries=(),
):
    assets_root = tmp_path / "frontend" / "assets" / "data"
    assets_root.mkdir(parents=True)
    timestamps = {
        dataset: "2026-08-31T08:17:00Z"
        for datasets in CANONICAL_DATASETS.values()
        for dataset in datasets
    }
    timestamps.update(updated_at_by_dataset or {})
    payload = {
        "generated_at_utc": "2026-08-31T08:17:00Z",
        "dataset_summaries": list(prepended_summaries)
        + [
            {"dataset": dataset, "updated_at_utc": updated_at}
            for dataset, updated_at in timestamps.items()
            if dataset not in missing_datasets
        ]
        + [
            {"dataset": "trend_score", "updated_at_utc": "2026-08-31T08:17:00Z"},
        ],
    }
    (assets_root / "run_manifest.json").write_text(json.dumps(payload), encoding="utf-8")


def test_allows_mixed_source_freshness_within_weekly_grace(tmp_path):
    _write_manifest(
        tmp_path,
        updated_at_by_dataset={
            **{
                dataset: "2026-08-24T08:17:00Z"
                for dataset in CANONICAL_DATASETS["github"]
                + CANONICAL_DATASETS["stackoverflow"]
            },
            "reddit_sentimiento_frameworks": "2026-08-31T08:16:00Z",
            "reddit_temas_emergentes": "2026-08-31T08:17:00Z",
        },
    )

    result = check_source_freshness(tmp_path)

    assert result["source_updated_at_utc"] == {
        "github": "2026-08-24T08:17:00Z",
        "stackoverflow": "2026-08-24T08:17:00Z",
        "reddit": "2026-08-31T08:16:00Z",
    }


def test_rejects_source_older_than_weekly_grace(tmp_path):
    _write_manifest(
        tmp_path,
        updated_at_by_dataset={"github_lenguajes": "2026-08-23T08:16:59Z"},
    )

    with pytest.raises(ValueError, match="Source freshness stale: github"):
        check_source_freshness(tmp_path)


def test_rejects_missing_source_timestamp_without_manifest_fallback(tmp_path):
    _write_manifest(
        tmp_path,
        updated_at_by_dataset={"github_lenguajes": "not-a-timestamp"},
    )

    with pytest.raises(ValueError, match="Source freshness unavailable: github"):
        check_source_freshness(tmp_path)


def test_rejects_required_timestamp_later_than_manifest_generation(tmp_path):
    _write_manifest(
        tmp_path,
        updated_at_by_dataset={"github_lenguajes": "2026-08-31T09:17:00Z"},
    )

    with pytest.raises(ValueError, match="Source freshness invalid: github"):
        check_source_freshness(tmp_path)


def test_rejects_duplicate_required_dataset_even_when_later_entry_is_fresh(tmp_path):
    _write_manifest(
        tmp_path,
        prepended_summaries=(
            {"dataset": "github_lenguajes", "updated_at_utc": "2026-08-20T08:17:00Z"},
        ),
    )

    with pytest.raises(ValueError, match="Source freshness invalid: github"):
        check_source_freshness(tmp_path)


def test_rejects_stale_required_sibling_even_when_another_github_dataset_is_fresh(tmp_path):
    _write_manifest(
        tmp_path,
        updated_at_by_dataset={
            "github_lenguajes": "2026-08-20T08:17:00Z",
            "github_repos_2025": "2026-08-31T08:17:00Z",
        },
    )

    with pytest.raises(ValueError, match="Source freshness stale: github"):
        check_source_freshness(tmp_path)


def test_rejects_missing_required_canonical_dataset(tmp_path):
    _write_manifest(tmp_path, missing_datasets=("github_lenguajes",))

    with pytest.raises(ValueError, match="Source freshness unavailable: github"):
        check_source_freshness(tmp_path)


def test_rejects_manifest_that_disagrees_with_final_reddit_bridges(tmp_path):
    _write_manifest(tmp_path)
    assets_root = tmp_path / "frontend" / "assets" / "data"
    for filename, dataset, timestamp_field in (
        ("reddit_sentimiento_public.json", "reddit_sentimiento_frameworks", "source_updated_at_utc"),
        ("reddit_temas_history.json", "reddit_temas_emergentes", "generated_at_utc"),
        ("reddit_interseccion_history.json", "interseccion_github_reddit", "generated_at_utc"),
    ):
        (assets_root / filename).write_text(
            json.dumps({"dataset": dataset, timestamp_field: "2026-08-20T08:17:00Z"}),
            encoding="utf-8",
        )

    with pytest.raises(ValueError, match="final canonical timestamp mismatch: reddit"):
        check_source_freshness(tmp_path)


def _write_final_reddit_bridges(assets_root, timestamp):
    for filename, dataset, timestamp_field in (
        ("reddit_sentimiento_public.json", "reddit_sentimiento_frameworks", "source_updated_at_utc"),
        ("reddit_temas_history.json", "reddit_temas_emergentes", "generated_at_utc"),
        ("reddit_interseccion_history.json", "interseccion_github_reddit", "generated_at_utc"),
    ):
        (assets_root / filename).write_text(
            json.dumps({"dataset": dataset, timestamp_field: timestamp}),
            encoding="utf-8",
        )


def test_allows_final_reddit_fallback_within_192_hours(tmp_path):
    timestamp = "2026-08-24T08:17:00Z"
    _write_manifest(
        tmp_path,
        updated_at_by_dataset={dataset: timestamp for dataset in CANONICAL_DATASETS["reddit"]},
    )
    _write_final_reddit_bridges(tmp_path / "frontend" / "assets" / "data", timestamp)

    result = check_source_freshness(tmp_path)

    assert result["source_updated_at_utc"]["reddit"] == timestamp


def test_rejects_final_reddit_fallback_older_than_192_hours(tmp_path):
    timestamp = "2026-08-23T08:16:59Z"
    _write_manifest(
        tmp_path,
        updated_at_by_dataset={dataset: timestamp for dataset in CANONICAL_DATASETS["reddit"]},
    )
    _write_final_reddit_bridges(tmp_path / "frontend" / "assets" / "data", timestamp)

    with pytest.raises(ValueError, match="Source freshness stale: reddit"):
        check_source_freshness(tmp_path)
