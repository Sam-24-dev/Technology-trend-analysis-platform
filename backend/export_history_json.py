"""Exports frontend bridge JSON assets from ETL history snapshots."""

from __future__ import annotations

import json
import logging
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd


logger = logging.getLogger("export_history_json")

HISTORY_INDEX_FILENAME = "history_index.json"
TREND_SCORE_HISTORY_FILENAME = "trend_score_history.json"


def _utc_now_iso():
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _to_relative_path(path, project_root):
    try:
        return path.relative_to(project_root).as_posix()
    except ValueError:
        return path.as_posix()


def _safe_int(value, default=0):
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _safe_float(value, default=0.0):
    try:
        return float(value)
    except (TypeError, ValueError):
        return default


def _extract_partition_date(parts):
    if len(parts) < 4:
        return None
    year_part, month_part, day_part = parts[1], parts[2], parts[3]
    if not (year_part.startswith("year=") and month_part.startswith("month=") and day_part.startswith("day=")):
        return None
    year = year_part.split("=", maxsplit=1)[1]
    month = month_part.split("=", maxsplit=1)[1]
    day = day_part.split("=", maxsplit=1)[1]
    return f"{year}-{month}-{day}"


def _count_rows(csv_path):
    try:
        return len(pd.read_csv(csv_path))
    except Exception:  # pylint: disable=broad-exception-caught
        return None


def _collect_history_files(project_root):
    history_root = project_root / "datos" / "history"
    if not history_root.exists():
        return {}

    datasets = {}
    for csv_path in history_root.rglob("*.csv"):
        rel_parts = csv_path.relative_to(history_root).parts
        if len(rel_parts) < 5:
            continue

        dataset = rel_parts[0]
        snapshot_date = _extract_partition_date(rel_parts)
        if snapshot_date is None:
            continue

        datasets.setdefault(dataset, [])
        datasets[dataset].append(
            {
                "date": snapshot_date,
                "path": _to_relative_path(csv_path, project_root),
                "row_count": _count_rows(csv_path),
            }
        )

    for dataset in datasets:
        datasets[dataset] = sorted(
            datasets[dataset],
            key=lambda item: (item["date"], item["path"]),
        )
    return datasets


def _collect_latest_files(project_root):
    latest_root = project_root / "datos" / "latest"
    if not latest_root.exists():
        return {}

    latest_files = {}
    for csv_path in latest_root.glob("*.csv"):
        dataset = csv_path.stem
        latest_files[dataset] = {
            "path": _to_relative_path(csv_path, project_root),
            "row_count": _count_rows(csv_path),
        }
    return latest_files


def build_history_index(project_root):
    """Builds history index metadata for frontend bridge use."""
    history_files = _collect_history_files(project_root)
    latest_files = _collect_latest_files(project_root)
    datasets = []

    for dataset_name in sorted(set(history_files.keys()) | set(latest_files.keys())):
        latest_info = latest_files.get(dataset_name)
        snapshots = history_files.get(dataset_name, [])
        datasets.append(
            {
                "dataset": dataset_name,
                "latest_path": latest_info["path"] if latest_info else None,
                "latest_row_count": latest_info["row_count"] if latest_info else None,
                "history_snapshot_count": len(snapshots),
                "snapshots": snapshots,
            }
        )

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset_count": len(datasets),
        "datasets": datasets,
    }


def _resolve_trend_snapshot_sources(project_root, history_index):
    trend_entry = next((item for item in history_index["datasets"] if item["dataset"] == "trend_score"), None)
    if trend_entry is None:
        return []

    sources = []
    for snapshot in trend_entry["snapshots"]:
        csv_path = project_root / snapshot["path"]
        if csv_path.exists():
            sources.append(
                {
                    "date": snapshot["date"],
                    "path": snapshot["path"],
                    "source_type": "history",
                }
            )

    if not sources and trend_entry.get("latest_path"):
        latest_path = project_root / trend_entry["latest_path"]
        if latest_path.exists():
            mtime = datetime.fromtimestamp(latest_path.stat().st_mtime, tz=timezone.utc)
            sources.append(
                {
                    "date": mtime.strftime("%Y-%m-%d"),
                    "path": trend_entry["latest_path"],
                    "source_type": "latest",
                }
            )

    return sorted(sources, key=lambda item: (item["date"], item["path"]))


def _build_trend_snapshot_record(df, date_label, relative_path, source_type):
    working = df.copy()
    if "ranking" not in working.columns:
        working = working.sort_values("trend_score", ascending=False).reset_index(drop=True)
        working["ranking"] = range(1, len(working) + 1)

    top_10 = []
    for _, row in working.sort_values("ranking", ascending=True).head(10).iterrows():
        top_10.append(
            {
                "ranking": _safe_int(row.get("ranking"), default=0),
                "tecnologia": str(row.get("tecnologia", "")),
                "trend_score": round(_safe_float(row.get("trend_score"), default=0.0), 2),
                "fuentes": _safe_int(row.get("fuentes"), default=0),
            }
        )

    return {
        "date": date_label,
        "path": relative_path,
        "source_type": source_type,
        "row_count": len(working),
        "top_10": top_10,
    }


def _is_valid_trend_snapshot_df(df):
    required_columns = {"tecnologia", "trend_score"}
    return required_columns.issubset(df.columns)


def _append_trend_snapshot(
    *,
    snapshots,
    snapshots_with_df,
    dataframe,
    date_label,
    relative_path,
    source_type,
):
    snapshots.append(
        _build_trend_snapshot_record(
            df=dataframe,
            date_label=date_label,
            relative_path=relative_path,
            source_type=source_type,
        )
    )
    snapshots_with_df.append(
        {
            "date": date_label,
            "dataframe": dataframe,
        }
    )


def _build_trend_series(snapshots_with_df):
    series_map = {}
    for snapshot in snapshots_with_df:
        date_label = snapshot["date"]
        df = snapshot["dataframe"]
        working = df.copy()
        if "ranking" not in working.columns:
            working = working.sort_values("trend_score", ascending=False).reset_index(drop=True)
            working["ranking"] = range(1, len(working) + 1)

        for _, row in working.iterrows():
            tech = str(row.get("tecnologia", "")).strip()
            if not tech:
                continue
            series_map.setdefault(tech, [])
            series_map[tech].append(
                {
                    "date": date_label,
                    "ranking": _safe_int(row.get("ranking"), default=0),
                    "trend_score": round(_safe_float(row.get("trend_score"), default=0.0), 2),
                    "fuentes": _safe_int(row.get("fuentes"), default=0),
                }
            )

    series = []
    for tech, points in series_map.items():
        sorted_points = sorted(points, key=lambda item: item["date"])
        latest_ranking = sorted_points[-1]["ranking"] if sorted_points else 999999
        series.append(
            {
                "tecnologia": tech,
                "points": sorted_points,
                "_latest_ranking": latest_ranking,
            }
        )

    series = sorted(series, key=lambda item: (item["_latest_ranking"], item["tecnologia"]))
    for item in series:
        item.pop("_latest_ranking", None)
    return series


def build_trend_score_history(project_root, history_index):
    """Builds trend_score_history payload for frontend bridge use."""
    sources = _resolve_trend_snapshot_sources(project_root, history_index)
    snapshots = []
    snapshots_with_df = []

    for source in sources:
        csv_path = project_root / source["path"]
        try:
            df = pd.read_csv(csv_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning("Skipping trend snapshot %s due to read error: %s", csv_path, exc)
            continue

        if not _is_valid_trend_snapshot_df(df):
            logger.warning("Skipping trend snapshot %s due to missing required columns", csv_path)
            continue

        _append_trend_snapshot(
            snapshots=snapshots,
            snapshots_with_df=snapshots_with_df,
            dataframe=df,
            date_label=source["date"],
            relative_path=source["path"],
            source_type=source["source_type"],
        )

    # If history entries exist but all are corrupted/invalid, fallback to latest snapshot.
    if not snapshots:
        trend_entry = next((item for item in history_index["datasets"] if item["dataset"] == "trend_score"), None)
        latest_path = trend_entry.get("latest_path") if trend_entry else None
        if latest_path:
            latest_csv_path = project_root / latest_path
            if latest_csv_path.exists():
                try:
                    latest_df = pd.read_csv(latest_csv_path)
                    if _is_valid_trend_snapshot_df(latest_df):
                        mtime = datetime.fromtimestamp(latest_csv_path.stat().st_mtime, tz=timezone.utc)
                        _append_trend_snapshot(
                            snapshots=snapshots,
                            snapshots_with_df=snapshots_with_df,
                            dataframe=latest_df,
                            date_label=mtime.strftime("%Y-%m-%d"),
                            relative_path=latest_path,
                            source_type="latest",
                        )
                except Exception as exc:  # pylint: disable=broad-exception-caught
                    logger.warning("Skipping latest trend snapshot fallback due to read error: %s", exc)

    return {
        "generated_at_utc": _utc_now_iso(),
        "snapshot_count": len(snapshots),
        "snapshots": snapshots,
        "series": _build_trend_series(snapshots_with_df),
    }


def _write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def export_bridge_assets(project_root):
    """Exports bridge JSON files for frontend historical access."""
    project_root = Path(project_root)
    output_dir = project_root / "frontend" / "assets" / "data"
    output_dir.mkdir(parents=True, exist_ok=True)

    history_index_payload = build_history_index(project_root)
    trend_history_payload = build_trend_score_history(project_root, history_index_payload)

    history_index_path = output_dir / HISTORY_INDEX_FILENAME
    trend_history_path = output_dir / TREND_SCORE_HISTORY_FILENAME
    _write_json(history_index_path, history_index_payload)
    _write_json(trend_history_path, trend_history_payload)

    summary = {
        "files_written": 2,
        "history_index_path": str(history_index_path),
        "trend_score_history_path": str(trend_history_path),
        "dataset_count": int(history_index_payload["dataset_count"]),
        "trend_snapshot_count": int(trend_history_payload["snapshot_count"]),
    }
    return summary


def main():
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")
    project_root = Path(__file__).resolve().parent.parent
    summary = export_bridge_assets(project_root)
    logger.info(
        "[RUN][SUMMARY] status=success files_written=%d datasets=%d trend_snapshots=%d",
        summary["files_written"],
        summary["dataset_count"],
        summary["trend_snapshot_count"],
    )


if __name__ == "__main__":
    main()
