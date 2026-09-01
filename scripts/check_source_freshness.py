"""Reject canonical source snapshots that are too old to publish."""

from __future__ import annotations

import argparse
import json
from datetime import datetime, timezone
from pathlib import Path


DEFAULT_MAX_SOURCE_AGE_HOURS = 192
REQUIRED_SOURCE_DATASETS = {
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
    ),
}


def _parse_utc_timestamp(value: object) -> datetime | None:
    if not isinstance(value, str) or not value.endswith("Z"):
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00")).astimezone(timezone.utc)
    except ValueError:
        return None


def _oldest_required_timestamp(
    dataset_summaries: object,
    required_datasets: tuple[str, ...],
) -> tuple[str, datetime] | None:
    if not isinstance(dataset_summaries, list):
        return None

    summaries = {
        str(summary.get("dataset")): summary
        for summary in dataset_summaries
        if isinstance(summary, dict)
    }
    timestamps: list[tuple[str, datetime]] = []
    for dataset in required_datasets:
        summary = summaries.get(dataset)
        timestamp = _parse_utc_timestamp(summary.get("updated_at_utc")) if summary else None
        if timestamp is None:
            return None
        timestamps.append((str(summary["updated_at_utc"]), timestamp))

    return min(timestamps, key=lambda item: item[1])


def _source_error(
    dataset_summaries: object,
    source: str,
    required_datasets: tuple[str, ...],
    reference_at: datetime,
) -> str | None:
    if not isinstance(dataset_summaries, list):
        return f"Source freshness unavailable: {source} has no canonical dataset summaries"

    seen_datasets: set[str] = set()
    required_names = set(required_datasets)
    for summary in dataset_summaries:
        if not isinstance(summary, dict):
            continue
        dataset = str(summary.get("dataset"))
        if dataset not in required_names:
            continue
        if dataset in seen_datasets:
            return f"Source freshness invalid: {source} has duplicate required dataset {dataset}"
        seen_datasets.add(dataset)

    summaries = {
        str(summary.get("dataset")): summary
        for summary in dataset_summaries
        if isinstance(summary, dict)
    }
    for dataset in required_datasets:
        summary = summaries.get(dataset)
        if summary is None:
            return f"Source freshness unavailable: {source} is missing required dataset {dataset}"
        timestamp = _parse_utc_timestamp(summary.get("updated_at_utc"))
        if timestamp is None:
            return f"Source freshness unavailable: {source} has invalid updated_at_utc for {dataset}"
        if timestamp > reference_at:
            return f"Source freshness invalid: {source} has future updated_at_utc for {dataset}"
    return None


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
    dataset_summaries = manifest.get("dataset_summaries")
    for source, required_datasets in REQUIRED_SOURCE_DATASETS.items():
        source_error = _source_error(dataset_summaries, source, required_datasets, reference_at)
        if source_error is not None:
            errors.append(source_error)
            continue

        oldest = _oldest_required_timestamp(dataset_summaries, required_datasets)
        if oldest is None:
            errors.append(f"Source freshness unavailable: {source} has no valid canonical updated_at_utc")
            continue
        updated_at_raw, updated_at = oldest
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
