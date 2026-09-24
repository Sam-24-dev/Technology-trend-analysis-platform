"""Valida que los bridges frontend conserven historial util antes de publicar."""

from __future__ import annotations

import argparse
import json
import os
import re
from datetime import date
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

HOME_HIGHLIGHT_SOURCE_FILES = {
    "github_lenguajes_public": "github_lenguajes_public.json",
    "github_frameworks_history": "github_frameworks_history.json",
    "github_correlacion_history": "github_correlacion_history.json",
    "reddit_sentimiento_public": "reddit_sentimiento_public.json",
    "reddit_temas_history": "reddit_temas_history.json",
    "reddit_interseccion_history": "reddit_interseccion_history.json",
    "so_volumen_history": "so_volumen_history.json",
    "so_aceptacion_history": "so_aceptacion_history.json",
    "so_tendencias_history": "so_tendencias_history.json",
}

REDDIT_HISTORY_DATASETS = ("reddit_sentimiento", "reddit_temas", "interseccion")


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _bridge_assets_roots(project_root: Path) -> list[Path]:
    frontend_root = project_root / "frontend" / "assets" / "data"
    roots = [frontend_root]
    remote_value = os.getenv("FRONTEND_BRIDGE_REMOTE_DIR", "").strip()
    if remote_value:
        remote_root = Path(remote_value)
        if not remote_root.is_absolute():
            remote_root = project_root / remote_root
        if remote_root.exists() and remote_root.resolve() != frontend_root.resolve():
            roots.append(remote_root)
    return roots


def _resolve_json_path(payload: dict, dotted_path: str):
    current = payload
    for segment in dotted_path.split("."):
        if not isinstance(current, dict) or segment not in current:
            return None
        current = current[segment]
    return current


def _check_home_highlights_consistency(assets_root: Path, home_highlights: dict, errors: list[str]) -> None:
    dashboard_signals = home_highlights.get("dashboard_signals")
    if not isinstance(dashboard_signals, dict):
        return

    for dashboard in dashboard_signals.values():
        if not isinstance(dashboard, dict):
            continue
        for graph in dashboard.values():
            if not isinstance(graph, dict):
                continue
            source = graph.get("source")
            if not isinstance(source, str) or ".summary." not in source:
                continue
            source_name, summary_path = source.split(".", 1)
            bridge_name = HOME_HIGHLIGHT_SOURCE_FILES.get(source_name)
            if bridge_name is None:
                continue
            bridge = _load_json(assets_root / bridge_name)
            expected_payload = _resolve_json_path(bridge, summary_path)
            if graph.get("payload") != expected_payload:
                errors.append(f"home_highlights canonical payload mismatch: {source}")
            if graph.get("summary") != bridge.get("summary"):
                errors.append(f"home_highlights canonical summary mismatch: {source_name}")

    for highlight in home_highlights.get("highlights", []):
        if not isinstance(highlight, dict):
            continue
        source = highlight.get("source")
        if not isinstance(source, str) or ".summary." not in source:
            continue
        source_name, summary_path = source.split(".", 1)
        bridge_name = HOME_HIGHLIGHT_SOURCE_FILES.get(source_name)
        if bridge_name is None:
            continue
        expected_payload = _resolve_json_path(_load_json(assets_root / bridge_name), summary_path)
        if highlight.get("payload") != expected_payload:
            errors.append(f"home_highlights canonical payload mismatch: {source}")


def _strict_date(value: object) -> date | None:
    if not isinstance(value, str) or not re.fullmatch(r"\d{4}-\d{2}-\d{2}", value):
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def _reddit_partition_date(path: object, dataset: str) -> date | None:
    if not isinstance(path, str):
        return None
    match = re.fullmatch(
        rf"datos/history/{dataset}/year=(\d{{4}})/month=(\d{{2}})/day=(\d{{2}})/[^/]+\.csv",
        path,
    )
    return _strict_date("-".join(match.groups())) if match else None


def _check_reddit_history_provenance(
    project_root: Path, assets_root: Path, history_index: dict, errors: list[str]
) -> None:
    canonical_dates = [
        _strict_date(_load_json(assets_root / name).get("latest_snapshot_date"))
        for name in ("reddit_temas_history.json", "reddit_interseccion_history.json")
    ]
    if None in canonical_dates or canonical_dates[0] != canonical_dates[1]:
        errors.append("reddit history provenance: canonical bridge dates are invalid or disagree")
        return
    canonical_date = canonical_dates[0]

    for entry in history_index.get("datasets", []):
        dataset = entry.get("dataset")
        if dataset not in REDDIT_HISTORY_DATASETS:
            continue
        latest = entry.get("latest_snapshot_date")
        if latest is not None and (
            (latest_date := _strict_date(latest)) is None or latest_date > canonical_date
        ):
            errors.append(f"reddit history provenance: {dataset} index latest date {latest!r}")
        for snapshot in entry.get("snapshots") or []:
            indexed_date = _strict_date(snapshot.get("date"))
            path = snapshot.get("path")
            partition_date = _reddit_partition_date(path, dataset)
            if indexed_date is None or partition_date != indexed_date or indexed_date > canonical_date:
                errors.append(f"reddit history provenance: {dataset} index date/path {snapshot!r}")

    for dataset in REDDIT_HISTORY_DATASETS:
        history_root = project_root / "datos" / "history" / dataset
        for csv_path in history_root.rglob("*.csv"):
            path = csv_path.relative_to(project_root).as_posix()
            partition_date = _reddit_partition_date(path, dataset)
            if partition_date is None or partition_date > canonical_date:
                errors.append(f"reddit history provenance: {path} exceeds or lacks canonical date")


def _check_bridge_root(
    project_root: Path,
    assets_root: Path,
    *,
    expect_previous_history: bool = False,
) -> dict[str, int | str]:
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
    _check_reddit_history_provenance(project_root, assets_root, history_index, errors)

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
    _check_home_highlights_consistency(assets_root, home_highlights, errors)

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


def check_bridge_integrity(
    project_root: Path | str,
    *,
    expect_previous_history: bool = False,
) -> dict[str, int | str]:
    project_root = Path(project_root)
    summaries = []
    errors = []
    for assets_root in _bridge_assets_roots(project_root):
        try:
            summaries.append(
                _check_bridge_root(
                    project_root,
                    assets_root,
                    expect_previous_history=expect_previous_history,
                )
            )
        except ValueError as exc:
            errors.append(f"{assets_root.name}: {exc}")

    if errors:
        raise ValueError("; ".join(errors))

    summary = summaries[0]
    summary["asset_roots_checked"] = len(summaries)
    return summary


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
