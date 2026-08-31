import json

import pytest

from scripts.check_source_freshness import check_source_freshness


def _write_manifest(tmp_path, *, github, stackoverflow, reddit):
    assets_root = tmp_path / "frontend" / "assets" / "data"
    assets_root.mkdir(parents=True)
    payload = {
        "generated_at_utc": "2026-08-31T08:17:00Z",
        "dataset_summaries": [
            {"dataset": "github_lenguajes", "updated_at_utc": github},
            {"dataset": "so_volumen_preguntas", "updated_at_utc": stackoverflow},
            {"dataset": "reddit_temas_emergentes", "updated_at_utc": reddit},
            {"dataset": "trend_score", "updated_at_utc": "2026-08-31T08:17:00Z"},
        ],
    }
    (assets_root / "run_manifest.json").write_text(json.dumps(payload), encoding="utf-8")


def test_allows_mixed_source_freshness_within_weekly_grace(tmp_path):
    _write_manifest(
        tmp_path,
        github="2026-08-24T08:17:00Z",
        stackoverflow="2026-08-24T08:17:00Z",
        reddit="2026-08-31T08:16:00Z",
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
        github="2026-08-23T08:16:59Z",
        stackoverflow="2026-08-31T08:17:00Z",
        reddit="2026-08-31T08:17:00Z",
    )

    with pytest.raises(ValueError, match="Source freshness stale: github"):
        check_source_freshness(tmp_path)


def test_rejects_missing_source_timestamp_without_manifest_fallback(tmp_path):
    _write_manifest(
        tmp_path,
        github="not-a-timestamp",
        stackoverflow="2026-08-31T08:17:00Z",
        reddit="2026-08-31T08:17:00Z",
    )

    with pytest.raises(ValueError, match="Source freshness unavailable: github"):
        check_source_freshness(tmp_path)
