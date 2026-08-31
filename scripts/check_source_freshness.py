"""Reject canonical source snapshots that are too old to publish."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_MAX_SOURCE_AGE_HOURS = 192
SOURCE_DATASET_PREFIXES = {
    "github": "github_",
    "stackoverflow": "so_",
    "reddit": "reddit_",
}


def _parse_utc_timestamp(value: object) -> datetime | None:
    if not isinstance(value, str) or not value.endswith("Z"):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def _latest_source_timestamp(dataset_summaries: object, prefix: str) -> tuple[str, datetime] | None:
    if not isinstance(dataset_summaries, list):
        return None

    latest: tuple[str, datetime] | None = None
    for summary in dataset_summaries:
        if not isinstance(summary, dict) or not str(summary.get("dataset", "")).startswith(prefix):
            continue
        timestamp = _parse_utc_timestamp(summary.get("updated_at_utc"))
        if timestamp is None:
            continue
        raw_timestamp = str(summary["updated_at_utc"])
        if latest is None or timestamp > latest[1]:
            latest = (raw_timestamp, timestamp)
    return latest


def check_source_freshness(
    project_root: Path | str,
    *,
    max_source_age_hours: int = DEFAULT_MAX_SOURCE_AGE_HOURS,
) -> dict[str, object]:
    """Validate source timestamps against the manifest generation time."""
    manifest_path = Path(project_root) / "frontend" / "assets" / "data" / "run_manifest.json"
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if not isinstance(manifest, dict):
        raise ValueError("Source freshness unavailable: run manifest must be a JSON object")

    reference_at = _parse_utc_timestamp(manifest.get("generated_at_utc"))
    if reference_at is None:
        raise ValueError("Source freshness unavailable: manifest generated_at_utc is invalid")

    source_updated_at_utc: dict[str, str] = {}
    errors: list[str] = []
    for source, prefix in SOURCE_DATASET_PREFIXES.items():
        latest = _latest_source_timestamp(manifest.get("dataset_summaries"), prefix)
        if latest is None:
            errors.append(f"Source freshness unavailable: {source} has no valid canonical updated_at_utc")
            continue

        updated_at_raw, updated_at = latest
        source_updated_at_utc[source] = updated_at_raw
        age_hours = (reference_at - updated_at).total_seconds() / 3600
        if age_hours > max_source_age_hours:
            errors.append(
                f"Source freshness stale: {source} is {age_hours:.1f}h old "
                f"(maximum {max_source_age_hours}h)"
            )

    if errors:
        raise ValueError("; ".join(errors))

    return {
        "max_source_age_hours": max_source_age_hours,
        "source_updated_at_utc": source_updated_at_utc,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", type=Path, default=Path("."))
    parser.add_argument("--max-source-age-hours", type=int, default=DEFAULT_MAX_SOURCE_AGE_HOURS)
    args = parser.parse_args()

    try:
        check_source_freshness(args.project_root, max_source_age_hours=args.max_source_age_hours)
    except ValueError as error:
        print(f"Source freshness guard failed: {error}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
