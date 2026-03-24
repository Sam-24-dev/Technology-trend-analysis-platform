"""Valida que los bridges frontend conserven historial util antes de publicar."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


REQUIRED_HISTORY_DATASETS = {
    "trend_score",
    "github_commits",
    "github_correlacion",
    "github_lenguajes",
    "so_volumen",
    "so_aceptacion",
    "so_tendencias",
    "reddit_temas",
    "interseccion",
}

REQUIRED_HISTORY_BRIDGES = (
    "github_frameworks_history.json",
    "github_correlacion_history.json",
    "so_volumen_history.json",
    "so_aceptacion_history.json",
    "so_tendencias_history.json",
    "reddit_temas_history.json",
    "reddit_interseccion_history.json",
)

BRIDGES_WITH_OPTIONAL_LATEST_DATE = {
    "so_tendencias_history.json",
}


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _bridge_assets_root(project_root: Path) -> Path:
    return project_root / "frontend" / "assets" / "data"


def check_bridge_integrity(
    project_root: Path | str,
    *,
    expect_previous_history: bool = False,
) -> dict[str, int | str]:
    project_root = Path(project_root)
    assets_root = _bridge_assets_root(project_root)
    errors: list[str] = []

    history_index = _load_json(assets_root / "history_index.json")
    dataset_names = {
        str(item.get("dataset", "")).strip()
        for item in history_index.get("datasets", [])
        if str(item.get("dataset", "")).strip()
    }
    missing_datasets = sorted(REQUIRED_HISTORY_DATASETS - dataset_names)
    if missing_datasets:
        errors.append(
            "history_index missing datasets: " + ", ".join(missing_datasets)
        )

    trend_history = _load_json(assets_root / "trend_score_history.json")
    snapshot_count = int(trend_history.get("snapshot_count", 0) or 0)
    minimum_snapshots = 2 if expect_previous_history else 1
    if snapshot_count < minimum_snapshots:
        errors.append(
            f"trend_score_history snapshot_count={snapshot_count} < {minimum_snapshots}"
        )

    technology_profiles = _load_json(assets_root / "technology_profiles.json")
    if not technology_profiles.get("latest_snapshot_date"):
        errors.append("technology_profiles latest_snapshot_date missing")
    if int(technology_profiles.get("profile_count", 0) or 0) <= 0:
        errors.append("technology_profiles profile_count must be positive")
    if expect_previous_history and not technology_profiles.get("previous_snapshot_date"):
        errors.append("technology_profiles previous_snapshot_date missing")

    home_highlights = _load_json(assets_root / "home_highlights.json")
    highlights = home_highlights.get("highlights", [])
    minimum_highlights = 3 if expect_previous_history else 2
    if len(highlights) < minimum_highlights:
        errors.append(
            f"home_highlights highlights={len(highlights)} < {minimum_highlights}"
        )

    for bridge_name in REQUIRED_HISTORY_BRIDGES:
        payload = _load_json(assets_root / bridge_name)
        source_mode = str(payload.get("source_mode", "")).strip().lower()
        if source_mode in {"", "missing", "none"}:
            errors.append(f"{bridge_name} source_mode={source_mode or 'missing'}")
        if (
            bridge_name not in BRIDGES_WITH_OPTIONAL_LATEST_DATE
            and not payload.get("latest_snapshot_date")
        ):
            errors.append(f"{bridge_name} latest_snapshot_date missing")
        if bridge_name in BRIDGES_WITH_OPTIONAL_LATEST_DATE:
            months = payload.get("months")
            series = payload.get("series")
            if not isinstance(months, list) or not months:
                errors.append(f"{bridge_name} months missing")
            if not isinstance(series, list) or not series:
                errors.append(f"{bridge_name} series missing")
            if expect_previous_history and (not isinstance(months, list) or len(months) < 2):
                errors.append(
                    f"{bridge_name} months must contain at least 2 entries when previous history is required"
                )
        elif expect_previous_history and not payload.get("previous_snapshot_date"):
            errors.append(f"{bridge_name} previous_snapshot_date missing")

    if errors:
        raise ValueError("; ".join(errors))

    return {
        "status": "ok",
        "dataset_count": len(dataset_names),
        "trend_snapshot_count": snapshot_count,
        "profile_count": int(technology_profiles.get("profile_count", 0) or 0),
        "home_highlight_count": len(highlights),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", default=".")
    parser.add_argument(
        "--expect-previous-history",
        type=int,
        default=0,
        choices=(0, 1),
        help="Exige snapshot previo cuando el workflow ya recupero un aggregate previo.",
    )
    args = parser.parse_args()

    summary = check_bridge_integrity(
        args.project_root,
        expect_previous_history=bool(args.expect_previous_history),
    )
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
