"""Exporta assets JSON puente del frontend desde snapshots históricos ETL."""

from __future__ import annotations

import json
import logging
import re
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

from tech_normalization import normalize_technology_name


logger = logging.getLogger("export_history_json")

HISTORY_INDEX_FILENAME = "history_index.json"
TREND_SCORE_HISTORY_FILENAME = "trend_score_history.json"
REDDIT_SENTIMENT_PUBLIC_FILENAME = "reddit_sentimiento_public.json"
REDDIT_TOPICS_HISTORY_FILENAME = "reddit_temas_history.json"
REDDIT_INTERSECTION_HISTORY_FILENAME = "reddit_interseccion_history.json"
GITHUB_LANGUAGES_PUBLIC_FILENAME = "github_lenguajes_public.json"
GITHUB_FRAMEWORKS_HISTORY_FILENAME = "github_frameworks_history.json"
GITHUB_CORRELATION_HISTORY_FILENAME = "github_correlacion_history.json"
HOME_HIGHLIGHTS_FILENAME = "home_highlights.json"
SO_VOLUME_HISTORY_FILENAME = "so_volumen_history.json"
SO_ACCEPTANCE_HISTORY_FILENAME = "so_aceptacion_history.json"
SO_TRENDS_HISTORY_FILENAME = "so_tendencias_history.json"
TECHNOLOGY_PROFILES_FILENAME = "technology_profiles.json"

GITHUB_FRAMEWORK_METRICS = (
    "commits_2025",
    "active_contributors",
    "merged_prs",
    "closed_issues",
    "releases_count",
)

TREND_SOURCE_COLUMNS = (
    ("github_score", "GH", "github", "GitHub"),
    ("so_score", "SO", "stackoverflow", "StackOverflow"),
    ("reddit_score", "RD", "reddit", "Reddit"),
)

SPECIAL_TECH_SLUGS = {
    "ai/ml": "ai-ml",
    "c#": "c-sharp",
    "c++": "c-plus-plus",
}


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


def _safe_nullable_int(value):
    if value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        if pd.isna(value):
            return None
        return int(value)
    text = str(value).strip()
    if not text:
        return None
    lowered = text.lower()
    if lowered in {"none", "null", "nan", "n/a"}:
        return None
    try:
        return int(float(text))
    except (TypeError, ValueError):
        return None


def _safe_nullable_float(value):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        if isinstance(value, float) and pd.isna(value):
            return None
        return float(value)
    text = str(value).strip()
    if not text:
        return None
    lowered = text.lower()
    if lowered in {"none", "null", "nan", "n/a"}:
        return None
    try:
        return float(text)
    except (TypeError, ValueError):
        return None


def _safe_percent(value):
    number = _safe_float(value, default=0.0)
    if number < 0:
        return 0.0
    if number > 100:
        return 100.0
    return round(number, 2)


def _normalize_trend_technology_name(name):
    text = str(name or "").strip()
    lowered = text.lower()
    if lowered in {"ai/ml", "ia/machine learning"}:
        return "AI/ML"
    return normalize_technology_name(text)


def _technology_slug(name):
    display_name = _normalize_trend_technology_name(name)
    lowered = display_name.strip().lower()
    if not lowered:
        return ""
    if lowered in SPECIAL_TECH_SLUGS:
        return SPECIAL_TECH_SLUGS[lowered]
    slug = re.sub(r"[^a-z0-9]+", "-", lowered).strip("-")
    return slug


def _trend_available_source_codes(row):
    codes = []
    for column, code, _, _ in TREND_SOURCE_COLUMNS:
        if _safe_float(row.get(column), default=0.0) > 0:
            codes.append(code)
    return codes


def _trend_sources_present(row):
    return [
        source_key
        for column, _, source_key, _ in TREND_SOURCE_COLUMNS
        if _safe_float(row.get(column), default=0.0) > 0
    ]


def _prepare_trend_snapshot_df(df):
    working = df.copy()

    for column, _, _, _ in TREND_SOURCE_COLUMNS:
        if column not in working.columns:
            working[column] = 0.0
        else:
            working[column] = pd.to_numeric(working[column], errors="coerce").fillna(0.0)

    if "trend_score" not in working.columns:
        working["trend_score"] = 0.0
    else:
        working["trend_score"] = pd.to_numeric(working["trend_score"], errors="coerce").fillna(0.0)

    if "fuentes" not in working.columns:
        working["fuentes"] = 0
    else:
        working["fuentes"] = pd.to_numeric(working["fuentes"], errors="coerce").fillna(0).astype(int)

    working["tecnologia"] = working["tecnologia"].apply(_normalize_trend_technology_name)
    working["slug"] = working["tecnologia"].apply(_technology_slug)

    if "ranking" not in working.columns:
        working = working.sort_values("trend_score", ascending=False).reset_index(drop=True)
        working["ranking"] = range(1, len(working) + 1)
    else:
        working["ranking"] = pd.to_numeric(working["ranking"], errors="coerce").fillna(0).astype(int)
        zero_rank_mask = working["ranking"] <= 0
        if zero_rank_mask.any():
            ranked = working.loc[zero_rank_mask].sort_values("trend_score", ascending=False).index.tolist()
            next_rank = int(working.loc[~zero_rank_mask, "ranking"].max()) + 1 if (~zero_rank_mask).any() else 1
            for idx in ranked:
                working.at[idx, "ranking"] = next_rank
                next_rank += 1

    return working.sort_values(["ranking", "tecnologia"], ascending=[True, True]).reset_index(drop=True)


def _trend_previous_lookup(previous_df):
    if previous_df is None or previous_df.empty:
        return {}
    return {str(row.get("slug", "")): row for _, row in previous_df.iterrows()}


def _build_trend_top_item(row, previous_lookup):
    slug = str(row.get("slug", ""))
    previous_row = previous_lookup.get(slug)
    current_ranking = _safe_int(row.get("ranking"), default=0)
    current_score = round(_safe_float(row.get("trend_score"), default=0.0), 2)
    ranking_prev = None
    score_prev = None
    delta_score = None
    delta_ranking = None

    if previous_row is not None:
        ranking_prev = _safe_nullable_int(previous_row.get("ranking"))
        score_prev = round(_safe_float(previous_row.get("trend_score"), default=0.0), 2)
        delta_score = round(current_score - score_prev, 2)
        if ranking_prev is not None and current_ranking > 0:
            delta_ranking = ranking_prev - current_ranking

    return {
        "ranking": current_ranking,
        "tecnologia": str(row.get("tecnologia", "")),
        "slug": slug,
        "github_score": round(_safe_float(row.get("github_score"), default=0.0), 2),
        "so_score": round(_safe_float(row.get("so_score"), default=0.0), 2),
        "reddit_score": round(_safe_float(row.get("reddit_score"), default=0.0), 2),
        "trend_score": current_score,
        "fuentes": _safe_int(row.get("fuentes"), default=0),
        "available_source_codes": _trend_available_source_codes(row),
        "score_prev": score_prev,
        "delta_score": delta_score,
        "ranking_prev": ranking_prev,
        "delta_ranking": delta_ranking,
    }


def _build_source_summary(row, previous_row, *, column, source_key, source_label):
    score_actual = round(_safe_float(row.get(column), default=0.0), 2)
    score_prev = None
    delta_score = None
    if previous_row is not None:
        score_prev = round(_safe_float(previous_row.get(column), default=0.0), 2)
        delta_score = round(score_actual - score_prev, 2)
    return {
        "source": source_key,
        "display_name": source_label,
        "available": score_actual > 0,
        "score_actual": score_actual,
        "score_prev": score_prev,
        "delta_score": delta_score,
    }


def _build_technology_profile_insights(
    *,
    display_name,
    row,
    previous_row,
    ranking_actual,
    ranking_prev,
    delta_ranking,
):
    source_scores = [
        (source_key, source_label, round(_safe_float(row.get(column), default=0.0), 2))
        for column, _, source_key, source_label in TREND_SOURCE_COLUMNS
    ]
    dominant_source = max(source_scores, key=lambda item: item[2]) if source_scores else None
    dominant_payload = None
    if dominant_source and dominant_source[2] > 0:
        dominant_payload = {
            "source": dominant_source[0],
            "display_name": dominant_source[1],
            "score": dominant_source[2],
            "label": f"{dominant_source[1]} aporta la mayor parte del score actual.",
        }

    sources_present = _trend_sources_present(row)
    coverage_names = [source_label for column, _, source_key, source_label in TREND_SOURCE_COLUMNS if source_key in sources_present]
    if coverage_names:
        if len(coverage_names) == 1:
            coverage_label = f"Señal disponible en {coverage_names[0]}."
        else:
            coverage_label = f"Señal combinada en {', '.join(coverage_names[:-1])} y {coverage_names[-1]}."
    else:
        coverage_label = "Sin señal activa en las fuentes principales."

    current_score = round(_safe_float(row.get("trend_score"), default=0.0), 2)
    score_prev = round(_safe_float(previous_row.get("trend_score"), default=0.0), 2) if previous_row is not None else None
    if ranking_prev is None:
        momentum_label = "Sin corrida previa comparable para medir movimiento."
    elif delta_ranking > 0:
        momentum_label = f"{display_name} sube {delta_ranking} posición(es) frente a la corrida previa."
    elif delta_ranking < 0:
        momentum_label = f"{display_name} cae {abs(delta_ranking)} posición(es) frente a la corrida previa."
    else:
        delta_score_value = round(current_score - (score_prev or 0.0), 2) if score_prev is not None else 0.0
        if score_prev is None or abs(delta_score_value) < 0.01:
            momentum_label = f"{display_name} se mantiene estable frente a la corrida previa."
        elif delta_score_value > 0:
            momentum_label = f"{display_name} mantiene posición frente a la corrida previa y gana {delta_score_value:.2f} puntos."
        else:
            momentum_label = f"{display_name} mantiene posición frente a la corrida previa y pierde {abs(delta_score_value):.2f} puntos."

    return {
        "dominant_source": dominant_payload,
        "coverage": {
            "source_count": len(sources_present),
            "sources_present": sources_present,
            "label": coverage_label,
        },
        "momentum": {
            "ranking_actual": ranking_actual,
            "ranking_prev": ranking_prev,
            "delta_ranking": delta_ranking,
            "score_actual": current_score,
            "score_prev": score_prev,
            "label": momentum_label,
        },
    }


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


def _resolve_reddit_sentiment_source(project_root):
    latest_path = project_root / "datos" / "latest" / "reddit_sentimiento_frameworks.csv"
    if latest_path.exists():
        return latest_path, "latest"

    legacy_path = project_root / "datos" / "reddit_sentimiento_frameworks.csv"
    if legacy_path.exists():
        return legacy_path, "legacy"

    return None, "missing"


def _resolve_github_languages_source(project_root):
    latest_path = project_root / "datos" / "latest" / "github_lenguajes.csv"
    if latest_path.exists():
        return latest_path, "latest"

    legacy_path = project_root / "datos" / "github_lenguajes.csv"
    if legacy_path.exists():
        return legacy_path, "legacy"

    return None, "missing"


def build_history_index(project_root):
    """Construye metadata del índice histórico para uso del bridge frontend."""
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


def _build_trend_snapshot_record(df, date_label, relative_path, source_type, previous_dataframe=None):
    working = _prepare_trend_snapshot_df(df)
    previous_lookup = _trend_previous_lookup(_prepare_trend_snapshot_df(previous_dataframe) if previous_dataframe is not None else None)
    top_10 = []
    for _, row in working.sort_values("ranking", ascending=True).head(10).iterrows():
        top_10.append(_build_trend_top_item(row, previous_lookup))

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
    previous_dataframe=None,
):
    snapshots.append(
        _build_trend_snapshot_record(
            df=dataframe,
            date_label=date_label,
            relative_path=relative_path,
            source_type=source_type,
            previous_dataframe=previous_dataframe,
        )
    )
    snapshots_with_df.append(
        {
            "date": date_label,
            "dataframe": _prepare_trend_snapshot_df(dataframe),
        }
    )


def _build_trend_series(snapshots_with_df):
    series_map = {}
    for snapshot in snapshots_with_df:
        date_label = snapshot["date"]
        df = snapshot["dataframe"]
        for _, row in df.iterrows():
            slug = str(row.get("slug", "")).strip()
            tech = str(row.get("tecnologia", "")).strip()
            if not tech or not slug:
                continue
            series_map.setdefault(slug, {"tecnologia": tech, "slug": slug, "points": []})
            series_map[slug]["points"].append(
                {
                    "date": date_label,
                    "ranking": _safe_int(row.get("ranking"), default=0),
                    "github_score": round(_safe_float(row.get("github_score"), default=0.0), 2),
                    "so_score": round(_safe_float(row.get("so_score"), default=0.0), 2),
                    "reddit_score": round(_safe_float(row.get("reddit_score"), default=0.0), 2),
                    "trend_score": round(_safe_float(row.get("trend_score"), default=0.0), 2),
                    "fuentes": _safe_int(row.get("fuentes"), default=0),
                    "available_source_codes": _trend_available_source_codes(row),
                }
            )

    series = []
    for item in series_map.values():
        sorted_points = sorted(item["points"], key=lambda point: point["date"])
        latest_ranking = sorted_points[-1]["ranking"] if sorted_points else 999999
        series.append(
            {
                "tecnologia": item["tecnologia"],
                "slug": item["slug"],
                "points": sorted_points,
                "_latest_ranking": latest_ranking,
            }
        )

    series = sorted(series, key=lambda item: (item["_latest_ranking"], item["tecnologia"]))
    for item in series:
        item.pop("_latest_ranking", None)
    return series


def _collect_trend_snapshot_data(project_root, history_index):
    sources = _resolve_trend_snapshot_sources(project_root, history_index)
    snapshots = []
    snapshots_with_df = []
    previous_df = None

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

        prepared_df = _prepare_trend_snapshot_df(df)
        _append_trend_snapshot(
            snapshots=snapshots,
            snapshots_with_df=snapshots_with_df,
            dataframe=prepared_df,
            date_label=source["date"],
            relative_path=source["path"],
            source_type=source["source_type"],
            previous_dataframe=previous_df,
        )
        previous_df = prepared_df

    if not snapshots:
        trend_entry = next((item for item in history_index["datasets"] if item["dataset"] == "trend_score"), None)
        latest_path = trend_entry.get("latest_path") if trend_entry else None
        if latest_path:
            latest_csv_path = project_root / latest_path
            if latest_csv_path.exists():
                try:
                    latest_df = pd.read_csv(latest_csv_path)
                    if _is_valid_trend_snapshot_df(latest_df):
                        prepared_df = _prepare_trend_snapshot_df(latest_df)
                        mtime = datetime.fromtimestamp(latest_csv_path.stat().st_mtime, tz=timezone.utc)
                        _append_trend_snapshot(
                            snapshots=snapshots,
                            snapshots_with_df=snapshots_with_df,
                            dataframe=prepared_df,
                            date_label=mtime.strftime("%Y-%m-%d"),
                            relative_path=latest_path,
                            source_type="latest",
                            previous_dataframe=None,
                        )
                except Exception as exc:  # pylint: disable=broad-exception-caught
                    logger.warning("Skipping latest trend snapshot fallback due to read error: %s", exc)

    return snapshots, snapshots_with_df


def _build_technology_profiles_payload(snapshots_with_df):
    latest_snapshot = snapshots_with_df[-1] if snapshots_with_df else None
    previous_snapshot = snapshots_with_df[-2] if len(snapshots_with_df) >= 2 else None
    latest_df = latest_snapshot["dataframe"] if latest_snapshot else pd.DataFrame()
    previous_lookup = _trend_previous_lookup(previous_snapshot["dataframe"] if previous_snapshot else None)
    profiles = []

    if latest_df.empty or not {"ranking", "tecnologia"}.issubset(latest_df.columns):
        return {
            "generated_at_utc": _utc_now_iso(),
            "dataset": "technology_profiles",
            "source_mode": "missing",
            "latest_snapshot_date": latest_snapshot["date"] if latest_snapshot else None,
            "previous_snapshot_date": previous_snapshot["date"] if previous_snapshot else None,
            "profile_count": 0,
            "profiles": [],
        }

    for _, row in latest_df.sort_values(["ranking", "tecnologia"], ascending=[True, True]).iterrows():
        slug = str(row.get("slug", "")).strip()
        if not slug:
            continue
        display_name = str(row.get("tecnologia", "")).strip()
        previous_row = previous_lookup.get(slug)
        ranking_actual = _safe_int(row.get("ranking"), default=0)
        ranking_prev = _safe_nullable_int(previous_row.get("ranking")) if previous_row is not None else None
        delta_ranking = (ranking_prev - ranking_actual) if ranking_prev is not None and ranking_actual > 0 else None

        history_points = []
        for snapshot in snapshots_with_df:
            snapshot_df = snapshot["dataframe"]
            matched_rows = snapshot_df[snapshot_df["slug"] == slug]
            if matched_rows.empty:
                history_points.append(
                    {
                        "date": snapshot["date"],
                        "trend_score": 0.0,
                        "github_score": 0.0,
                        "so_score": 0.0,
                        "reddit_score": 0.0,
                        "ranking": None,
                        "fuentes": 0,
                        "available_source_codes": [],
                    }
                )
                continue
            matched = matched_rows.iloc[0]
            history_points.append(
                {
                    "date": snapshot["date"],
                    "trend_score": round(_safe_float(matched.get("trend_score"), default=0.0), 2),
                    "github_score": round(_safe_float(matched.get("github_score"), default=0.0), 2),
                    "so_score": round(_safe_float(matched.get("so_score"), default=0.0), 2),
                    "reddit_score": round(_safe_float(matched.get("reddit_score"), default=0.0), 2),
                    "ranking": _safe_nullable_int(matched.get("ranking")),
                    "fuentes": _safe_int(matched.get("fuentes"), default=0),
                    "available_source_codes": _trend_available_source_codes(matched),
                }
            )

        profile = {
            "slug": slug,
            "display_name": display_name,
            "trend_score_actual": round(_safe_float(row.get("trend_score"), default=0.0), 2),
            "trend_score_prev": round(_safe_float(previous_row.get("trend_score"), default=0.0), 2)
            if previous_row is not None
            else None,
            "delta_score": round(
                _safe_float(row.get("trend_score"), default=0.0)
                - _safe_float(previous_row.get("trend_score"), default=0.0),
                2,
            )
            if previous_row is not None
            else None,
            "ranking_actual": ranking_actual,
            "ranking_prev": ranking_prev,
            "delta_ranking": delta_ranking,
            "sources_present": _trend_sources_present(row),
            "github_summary": _build_source_summary(
                row,
                previous_row,
                column="github_score",
                source_key="github",
                source_label="GitHub",
            ),
            "stackoverflow_summary": _build_source_summary(
                row,
                previous_row,
                column="so_score",
                source_key="stackoverflow",
                source_label="StackOverflow",
            ),
            "reddit_summary": _build_source_summary(
                row,
                previous_row,
                column="reddit_score",
                source_key="reddit",
                source_label="Reddit",
            ),
            "source_history": history_points,
            "summary_insights": _build_technology_profile_insights(
                display_name=display_name,
                row=row,
                previous_row=previous_row,
                ranking_actual=ranking_actual,
                ranking_prev=ranking_prev,
                delta_ranking=delta_ranking,
            ),
        }
        profiles.append(profile)

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "technology_profiles",
        "source_mode": "trend_score_history" if snapshots_with_df else "missing",
        "latest_snapshot_date": latest_snapshot["date"] if latest_snapshot else None,
        "previous_snapshot_date": previous_snapshot["date"] if previous_snapshot else None,
        "profile_count": len(profiles),
        "profiles": profiles,
    }


def build_reddit_sentiment_public(project_root):
    """Construye payload público para sentimiento de frameworks en Reddit."""
    csv_path, source_mode = _resolve_reddit_sentiment_source(project_root)
    payload = {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "reddit_sentimiento_frameworks",
        "source_mode": source_mode,
        "source_path": None,
        "source_updated_at_utc": None,
        "framework_count": 0,
        "frameworks": [],
        "summary": _build_reddit_sentiment_summary([]),
    }

    if csv_path is None:
        return payload

    try:
        dataframe = pd.read_csv(csv_path)
    except Exception as exc:  # pylint: disable=broad-exception-caught
        logger.warning("Skipping reddit sentiment public payload due to read error: %s", exc)
        return payload

    payload["source_path"] = _to_relative_path(csv_path, project_root)
    payload["source_updated_at_utc"] = (
        datetime.fromtimestamp(csv_path.stat().st_mtime, tz=timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )

    frameworks = []
    for _, row in dataframe.iterrows():
        framework = str(row.get("framework", "")).strip()
        if not framework:
            continue

        frameworks.append(
            {
                "framework": framework,
                "total_menciones": _safe_int(row.get("total_menciones"), default=0),
                "positivos": _safe_int(row.get("positivos"), default=0),
                "neutros": _safe_int(row.get("neutros"), default=0),
                "negativos": _safe_int(row.get("negativos"), default=0),
                "porcentaje_positivo": _safe_percent(row.get("% positivo")),
                "porcentaje_neutro": _safe_percent(row.get("% neutro")),
                "porcentaje_negativo": _safe_percent(row.get("% negativo")),
            }
        )

    frameworks.sort(
        key=lambda item: (
            -_safe_float(item.get("porcentaje_positivo"), default=0.0),
            -_safe_int(item.get("total_menciones"), default=0),
            item.get("framework", "").lower(),
        )
    )
    payload["framework_count"] = len(frameworks)
    payload["frameworks"] = frameworks
    payload["summary"] = _build_reddit_sentiment_summary(frameworks)
    return payload


def _summarize_reddit_sentiment_framework(item):
    if not item:
        return None
    return {
        "framework": item.get("framework"),
        "total_menciones": _safe_int(item.get("total_menciones"), default=0),
        "positivos": _safe_int(item.get("positivos"), default=0),
        "neutros": _safe_int(item.get("neutros"), default=0),
        "negativos": _safe_int(item.get("negativos"), default=0),
        "porcentaje_positivo": round(_safe_float(item.get("porcentaje_positivo"), default=0.0), 2),
        "porcentaje_neutro": round(_safe_float(item.get("porcentaje_neutro"), default=0.0), 2),
        "porcentaje_negativo": round(_safe_float(item.get("porcentaje_negativo"), default=0.0), 2),
    }


def _build_reddit_sentiment_summary(frameworks):
    summary = {
        "positive_leader": None,
        "largest_sample": None,
        "negative_leader": None,
        "framework_count": len(frameworks),
        "total_menciones": sum(_safe_int(item.get("total_menciones"), default=0) for item in frameworks),
    }
    if not frameworks:
        return summary

    positive_leader = max(
        frameworks,
        key=lambda item: (
            _safe_float(item.get("porcentaje_positivo"), default=0.0),
            _safe_int(item.get("total_menciones"), default=0),
            item.get("framework", ""),
        ),
    )
    largest_sample = max(
        frameworks,
        key=lambda item: (
            _safe_int(item.get("total_menciones"), default=0),
            _safe_float(item.get("porcentaje_positivo"), default=0.0),
            item.get("framework", ""),
        ),
    )
    negative_leader = max(
        frameworks,
        key=lambda item: (
            _safe_float(item.get("porcentaje_negativo"), default=0.0),
            _safe_int(item.get("total_menciones"), default=0),
            item.get("framework", ""),
        ),
    )

    summary["positive_leader"] = _summarize_reddit_sentiment_framework(positive_leader)
    summary["largest_sample"] = _summarize_reddit_sentiment_framework(largest_sample)
    summary["negative_leader"] = _summarize_reddit_sentiment_framework(negative_leader)
    return summary


def _summarize_github_language(item):
    if not item:
        return None
    return {
        "lenguaje": item.get("lenguaje"),
        "repos_count": _safe_int(item.get("repos_count"), default=0),
        "share_pct": round(_safe_float(item.get("share_pct"), default=0.0), 2),
    }


def _build_github_languages_summary(languages):
    summary = {
        "leader": None,
        "runner_up": None,
        "language_count": len(languages),
        "total_classifiable_repos": sum(_safe_int(item.get("repos_count"), default=0) for item in languages),
        "leader_gap_repos": None,
        "leader_gap_share_pct": None,
    }
    if not languages:
        return summary

    leader = languages[0]
    runner_up = languages[1] if len(languages) >= 2 else None
    summary["leader"] = _summarize_github_language(leader)
    summary["runner_up"] = _summarize_github_language(runner_up)
    if runner_up is not None:
        summary["leader_gap_repos"] = (
            _safe_int(leader.get("repos_count"), default=0)
            - _safe_int(runner_up.get("repos_count"), default=0)
        )
        summary["leader_gap_share_pct"] = round(
            _safe_float(leader.get("share_pct"), default=0.0)
            - _safe_float(runner_up.get("share_pct"), default=0.0),
            2,
        )
    return summary


def build_github_languages_public(project_root):
    """Construye payload pÃºblico para lenguajes de GitHub."""
    csv_path, source_mode = _resolve_github_languages_source(project_root)
    payload = {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "github_lenguajes",
        "source_mode": source_mode,
        "source_path": None,
        "source_updated_at_utc": None,
        "language_count": 0,
        "languages": [],
        "summary": _build_github_languages_summary([]),
    }

    if csv_path is None:
        return payload

    try:
        dataframe = pd.read_csv(csv_path)
    except Exception as exc:  # pylint: disable=broad-exception-caught
        logger.warning("Skipping github languages public payload due to read error: %s", exc)
        return payload

    payload["source_path"] = _to_relative_path(csv_path, project_root)
    payload["source_updated_at_utc"] = (
        datetime.fromtimestamp(csv_path.stat().st_mtime, tz=timezone.utc)
        .replace(microsecond=0)
        .isoformat()
        .replace("+00:00", "Z")
    )

    languages = []
    for _, row in dataframe.iterrows():
        language = str(row.get("lenguaje", "")).strip()
        if not language:
            continue
        languages.append(
            {
                "lenguaje": language,
                "repos_count": _safe_int(row.get("repos_count"), default=0),
                "share_pct": _safe_percent(row.get("porcentaje")),
            }
        )

    languages.sort(
        key=lambda item: (
            -_safe_int(item.get("repos_count"), default=0),
            -_safe_float(item.get("share_pct"), default=0.0),
            item.get("lenguaje", "").lower(),
        )
    )
    payload["language_count"] = len(languages)
    payload["languages"] = languages
    payload["summary"] = _build_github_languages_summary(languages)
    return payload



def _resolve_dataset_snapshot_sources(project_root, history_index, dataset_names):
    if isinstance(dataset_names, str):
        dataset_names = [dataset_names]
    dataset_entries = [
        item
        for item in history_index["datasets"]
        if item["dataset"] in set(dataset_names)
    ]
    if not dataset_entries:
        return []

    sources_by_path = {}
    for dataset_entry in dataset_entries:
        for snapshot in dataset_entry["snapshots"]:
            csv_path = project_root / snapshot["path"]
            if csv_path.exists():
                sources_by_path[snapshot["path"]] = {
                    "date": snapshot["date"],
                    "path": snapshot["path"],
                    "source_type": "history",
                }

    if not sources_by_path:
        for dataset_entry in dataset_entries:
            latest_path_label = dataset_entry.get("latest_path")
            if not latest_path_label:
                continue
            latest_path = project_root / latest_path_label
            if latest_path.exists():
                mtime = datetime.fromtimestamp(
                    latest_path.stat().st_mtime,
                    tz=timezone.utc,
                )
                sources_by_path[latest_path_label] = {
                    "date": mtime.strftime("%Y-%m-%d"),
                    "path": latest_path_label,
                    "source_type": "latest",
                }

    sources = list(sources_by_path.values())
    return sorted(sources, key=lambda item: (item["date"], item["path"]))


def _is_valid_github_frameworks_df(df):
    required_columns = {"framework", "commits_2025"}
    return required_columns.issubset(df.columns)


def _is_valid_github_correlation_df(df):
    required_columns = {"repo_name", "stars", "contributors"}
    return required_columns.issubset(df.columns)


def _is_valid_so_volume_df(df):
    required_columns = {"lenguaje", "preguntas_nuevas_2025"}
    return required_columns.issubset(df.columns)


def _is_valid_so_acceptance_df(df):
    required_columns = {
        "tecnologia",
        "total_preguntas",
        "respuestas_aceptadas",
        "tasa_aceptacion_pct",
    }
    return required_columns.issubset(df.columns)


def _is_valid_so_trends_df(df):
    columns = [str(col).strip() for col in df.columns]
    if "mes" not in columns:
        return False
    technology_columns = [column for column in columns if column and column != "mes"]
    return len(technology_columns) > 0


def _normalize_so_volume_language_label(value):
    raw = str(value or "").strip()
    if not raw:
        return ""
    normalized = raw.lower()
    alias_map = {
        "csharp": "c#",
        "cpp": "c++",
    }
    return alias_map.get(normalized, normalized)


def _normalize_so_trend_technology_label(value):
    raw = str(value or "").strip()
    if not raw:
        return ""
    normalized = raw.lower()
    alias_map = {
        "python": "Python",
        "javascript": "JavaScript",
        "typescript": "TypeScript",
        "reactjs": "ReactJS",
        "react.js": "ReactJS",
        "nextjs": "Next.js",
        "next.js": "Next.js",
        "vuejs": "Vue.js",
        "vue.js": "Vue.js",
        "nodejs": "Node.js",
        "node.js": "Node.js",
        "csharp": "C#",
        "c#": "C#",
        "cpp": "C++",
        "c++": "C++",
        "php": "PHP",
        "go": "Go",
        "ruby": "Ruby",
        "java": "Java",
    }
    if normalized in alias_map:
        return alias_map[normalized]
    if raw != normalized:
        return raw
    return raw.title()


def _normalize_so_volume_df(df):
    working = df.copy()
    if "lenguaje" not in working.columns:
        working["lenguaje"] = ""
    if "preguntas_nuevas_2025" not in working.columns:
        working["preguntas_nuevas_2025"] = 0

    working["lenguaje"] = working["lenguaje"].map(_normalize_so_volume_language_label)
    working["preguntas_nuevas_2025"] = (
        pd.to_numeric(working["preguntas_nuevas_2025"], errors="coerce")
        .fillna(0)
        .astype(int)
    )
    working = working[working["lenguaje"] != ""].copy()
    working = working.sort_values(
        ["preguntas_nuevas_2025", "lenguaje"],
        ascending=[False, True],
    ).reset_index(drop=True)
    return working


def _build_so_volume_snapshot_record(df, date_label, relative_path, source_type):
    working = _normalize_so_volume_df(df)
    total_questions = int(working["preguntas_nuevas_2025"].sum()) if not working.empty else 0

    items = []
    for _, row in working.iterrows():
        preguntas = _safe_int(row.get("preguntas_nuevas_2025"), default=0)
        share_pct = (preguntas / total_questions * 100) if total_questions > 0 else 0.0
        items.append(
            {
                "lenguaje": str(row.get("lenguaje", "")).strip(),
                "preguntas": preguntas,
                "share_pct": round(share_pct, 2),
            }
        )

    return {
        "date": date_label,
        "path": relative_path,
        "source_type": source_type,
        "row_count": len(items),
        "item_count": len(items),
        "total_questions": total_questions,
        "items": items,
    }


def _build_latest_so_volume_items(*, latest_snapshot, previous_snapshot):
    if latest_snapshot is None:
        return []

    previous_map = {}
    if previous_snapshot is not None:
        previous_map = {
            str(item.get("lenguaje", "")).strip().lower(): item
            for item in previous_snapshot.get("items", [])
            if str(item.get("lenguaje", "")).strip()
        }

    latest_items = []
    for item in latest_snapshot.get("items", []):
        language_key = str(item.get("lenguaje", "")).strip().lower()
        prev_item = previous_map.get(language_key)
        preguntas = _safe_int(item.get("preguntas"), default=0)
        preguntas_prev = _safe_int(prev_item.get("preguntas"), default=0) if prev_item else 0
        delta_preguntas = preguntas - preguntas_prev
        growth_pct = 0.0
        if preguntas_prev > 0:
            growth_pct = round((delta_preguntas / preguntas_prev) * 100, 2)

        if delta_preguntas > 0:
            trend_direction = "creciendo"
        elif delta_preguntas < 0:
            trend_direction = "cayendo"
        else:
            trend_direction = "estable"

        latest_items.append(
            {
                "lenguaje": item.get("lenguaje"),
                "preguntas": preguntas,
                "preguntas_prev": preguntas_prev,
                "delta_preguntas": delta_preguntas,
                "growth_pct": growth_pct,
                "trend_direction": trend_direction,
                "share_pct": round(_safe_float(item.get("share_pct"), default=0.0), 2),
            }
        )

    latest_items.sort(
        key=lambda item: (
            -_safe_int(item.get("preguntas"), default=0),
            item.get("lenguaje", "").lower(),
        )
    )
    return latest_items


def _summarize_so_volume_language(item):
    if not item:
        return None
    return {
        "lenguaje": item.get("lenguaje"),
        "preguntas": _safe_int(item.get("preguntas"), default=0),
        "preguntas_prev": _safe_int(item.get("preguntas_prev"), default=0),
        "delta_preguntas": _safe_int(item.get("delta_preguntas"), default=0),
        "growth_pct": round(_safe_float(item.get("growth_pct"), default=0.0), 2),
        "trend_direction": item.get("trend_direction"),
        "share_pct": round(_safe_float(item.get("share_pct"), default=0.0), 2),
    }


def _build_so_volume_summary(latest_items, latest_snapshot, previous_snapshot):
    summary = {
        "leader": None,
        "highest_growth": None,
        "largest_drop": None,
        "total_questions": latest_snapshot.get("total_questions", 0) if latest_snapshot else 0,
    }
    if not latest_items:
        return summary

    leader = max(
        latest_items,
        key=lambda item: (_safe_int(item.get("preguntas"), default=0), item.get("lenguaje", "")),
    )
    summary["leader"] = _summarize_so_volume_language(leader)

    if previous_snapshot is None:
        return summary

    growth_candidates = [
        item
        for item in latest_items
        if _safe_int(item.get("preguntas_prev"), default=0) > 0
        and _safe_int(item.get("delta_preguntas"), default=0) > 0
    ]
    drop_candidates = [
        item
        for item in latest_items
        if _safe_int(item.get("preguntas_prev"), default=0) > 0
        and _safe_int(item.get("delta_preguntas"), default=0) < 0
    ]
    highest_growth = max(
        growth_candidates,
        key=lambda item: (item.get("delta_preguntas", 0), item.get("lenguaje", "")),
        default=None,
    )
    largest_drop = min(
        drop_candidates,
        key=lambda item: (item.get("delta_preguntas", 0), item.get("lenguaje", "")),
        default=None,
    )
    summary["highest_growth"] = _summarize_so_volume_language(highest_growth)
    summary["largest_drop"] = _summarize_so_volume_language(largest_drop)
    return summary


def build_so_volume_history(project_root, history_index):
    """Construye payload historico para volumen de preguntas StackOverflow."""
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        ["so_volumen", "so_volumen_preguntas"],
    )
    snapshots = []

    for source in sources:
        csv_path = project_root / source["path"]
        try:
            df = pd.read_csv(csv_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning("Skipping StackOverflow volume snapshot %s due to read error: %s", csv_path, exc)
            continue

        if not _is_valid_so_volume_df(df):
            logger.warning("Skipping StackOverflow volume snapshot %s due to missing required columns", csv_path)
            continue

        snapshots.append(
            _build_so_volume_snapshot_record(
                df,
                date_label=source["date"],
                relative_path=source["path"],
                source_type=source["source_type"],
            )
        )

    source_mode = "missing"
    if snapshots:
        history_count = sum(1 for item in snapshots if item["source_type"] == "history")
        source_mode = "history" if history_count > 0 else "latest"

    latest_snapshot = snapshots[-1] if snapshots else None
    previous_snapshot = snapshots[-2] if len(snapshots) >= 2 else None
    latest_items = _build_latest_so_volume_items(
        latest_snapshot=latest_snapshot,
        previous_snapshot=previous_snapshot,
    )

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "so_volumen_preguntas",
        "source_mode": source_mode,
        "snapshot_count": len(snapshots),
        "latest_snapshot_date": latest_snapshot.get("date") if latest_snapshot else None,
        "previous_snapshot_date": previous_snapshot.get("date") if previous_snapshot else None,
        "has_historical_comparison": previous_snapshot is not None,
        "item_count": latest_snapshot.get("item_count", 0) if latest_snapshot else 0,
        "summary": _build_so_volume_summary(latest_items, latest_snapshot, previous_snapshot),
        "latest_items": latest_items,
        "snapshots": snapshots,
    }


def _wilson_lower_bound_95(successes, total):
    successes = max(_safe_int(successes, default=0), 0)
    total = max(_safe_int(total, default=0), 0)
    if total <= 0:
        return 0.0

    z = 1.96
    phat = successes / total
    z2 = z * z
    denominator = 1 + (z2 / total)
    center = phat + (z2 / (2 * total))
    margin = z * ((phat * (1 - phat) + (z2 / (4 * total))) / total) ** 0.5
    return round((center - margin) / denominator, 6)


def _resolve_so_acceptance_sample_bucket(total_questions):
    total_questions = max(_safe_int(total_questions, default=0), 0)
    if total_questions < 300:
        return "baja"
    if total_questions < 1000:
        return "media"
    return "alta"


def _normalize_so_acceptance_df(df):
    working = df.copy()
    if "tecnologia" not in working.columns:
        working["tecnologia"] = ""
    if "total_preguntas" not in working.columns:
        working["total_preguntas"] = 0
    if "respuestas_aceptadas" not in working.columns:
        working["respuestas_aceptadas"] = 0
    if "tasa_aceptacion_pct" not in working.columns:
        working["tasa_aceptacion_pct"] = 0.0

    working["tecnologia"] = working["tecnologia"].astype(str).str.strip()
    working["total_preguntas"] = (
        pd.to_numeric(working["total_preguntas"], errors="coerce")
        .fillna(0)
        .astype(int)
    )
    working["respuestas_aceptadas"] = (
        pd.to_numeric(working["respuestas_aceptadas"], errors="coerce")
        .fillna(0)
        .astype(int)
    )
    working = working[working["tecnologia"] != ""].copy()
    working["respuestas_aceptadas"] = working.apply(
        lambda row: max(min(int(row["respuestas_aceptadas"]), int(row["total_preguntas"])), 0),
        axis=1,
    )
    working["tasa_aceptacion_pct"] = working.apply(
        lambda row: round(
            (row["respuestas_aceptadas"] / row["total_preguntas"]) * 100,
            2,
        )
        if row["total_preguntas"] > 0
        else 0.0,
        axis=1,
    )
    working["sample_bucket"] = working["total_preguntas"].apply(
        _resolve_so_acceptance_sample_bucket
    )
    working["confidence_score"] = working.apply(
        lambda row: _wilson_lower_bound_95(
            row["respuestas_aceptadas"],
            row["total_preguntas"],
        ),
        axis=1,
    )

    working["raw_rank"] = 0
    raw_ranking = (
        working.sort_values(
            ["tasa_aceptacion_pct", "total_preguntas", "tecnologia"],
            ascending=[False, False, True],
        )
        .index
        .tolist()
    )
    for rank, index in enumerate(raw_ranking, start=1):
        working.at[index, "raw_rank"] = rank

    working["confidence_rank"] = 0
    confidence_ranking = (
        working.sort_values(
            ["confidence_score", "total_preguntas", "tasa_aceptacion_pct", "tecnologia"],
            ascending=[False, False, False, True],
        )
        .index
        .tolist()
    )
    for rank, index in enumerate(confidence_ranking, start=1):
        working.at[index, "confidence_rank"] = rank

    working = working.sort_values(
        ["raw_rank", "tecnologia"],
        ascending=[True, True],
    ).reset_index(drop=True)
    return working


def _build_so_acceptance_snapshot_record(df, date_label, relative_path, source_type):
    working = _normalize_so_acceptance_df(df)
    items = []

    for _, row in working.iterrows():
        items.append(
            {
                "tecnologia": str(row.get("tecnologia", "")).strip(),
                "total_preguntas": _safe_int(row.get("total_preguntas"), default=0),
                "respuestas_aceptadas": _safe_int(
                    row.get("respuestas_aceptadas"),
                    default=0,
                ),
                "tasa_aceptacion_pct": round(
                    _safe_float(row.get("tasa_aceptacion_pct"), default=0.0),
                    2,
                ),
                "sample_bucket": row.get("sample_bucket"),
                "confidence_score": round(
                    _safe_float(row.get("confidence_score"), default=0.0),
                    6,
                ),
                "raw_rank": _safe_int(row.get("raw_rank"), default=0),
                "confidence_rank": _safe_int(
                    row.get("confidence_rank"),
                    default=0,
                ),
            }
        )

    return {
        "date": date_label,
        "path": relative_path,
        "source_type": source_type,
        "row_count": len(items),
        "item_count": len(items),
        "items": items,
    }


def _build_latest_so_acceptance_items(*, latest_snapshot, previous_snapshot):
    if latest_snapshot is None:
        return []

    previous_map = {}
    if previous_snapshot is not None:
        previous_map = {
            str(item.get("tecnologia", "")).strip().lower(): item
            for item in previous_snapshot.get("items", [])
            if str(item.get("tecnologia", "")).strip()
        }

    latest_items = []
    for item in latest_snapshot.get("items", []):
        tech_key = str(item.get("tecnologia", "")).strip().lower()
        prev_item = previous_map.get(tech_key)

        total_questions = _safe_int(item.get("total_preguntas"), default=0)
        accepted_answers = _safe_int(item.get("respuestas_aceptadas"), default=0)
        rate_pct = round(_safe_float(item.get("tasa_aceptacion_pct"), default=0.0), 2)
        total_questions_prev = (
            _safe_int(prev_item.get("total_preguntas"), default=0) if prev_item else 0
        )
        accepted_answers_prev = (
            _safe_int(prev_item.get("respuestas_aceptadas"), default=0) if prev_item else 0
        )
        rate_prev_pct = (
            round(_safe_float(prev_item.get("tasa_aceptacion_pct"), default=0.0), 2)
            if prev_item
            else 0.0
        )

        latest_items.append(
            {
                "tecnologia": item.get("tecnologia"),
                "total_preguntas": total_questions,
                "respuestas_aceptadas": accepted_answers,
                "tasa_aceptacion_pct": rate_pct,
                "total_preguntas_prev": total_questions_prev,
                "respuestas_aceptadas_prev": accepted_answers_prev,
                "tasa_aceptacion_prev_pct": rate_prev_pct,
                "delta_tasa_pct": round(rate_pct - rate_prev_pct, 2),
                "delta_preguntas": total_questions - total_questions_prev,
                "sample_bucket": item.get("sample_bucket"),
                "confidence_score": round(
                    _safe_float(item.get("confidence_score"), default=0.0),
                    6,
                ),
                "raw_rank": _safe_int(item.get("raw_rank"), default=0),
                "confidence_rank": _safe_int(item.get("confidence_rank"), default=0),
            }
        )

    latest_items.sort(
        key=lambda current: (
            _safe_int(current.get("raw_rank"), default=9999),
            current.get("tecnologia", "").lower(),
        )
    )
    return latest_items


def _summarize_so_acceptance_item(item):
    if not item:
        return None
    return {
        "tecnologia": item.get("tecnologia"),
        "total_preguntas": _safe_int(item.get("total_preguntas"), default=0),
        "respuestas_aceptadas": _safe_int(item.get("respuestas_aceptadas"), default=0),
        "tasa_aceptacion_pct": round(
            _safe_float(item.get("tasa_aceptacion_pct"), default=0.0),
            2,
        ),
        "total_preguntas_prev": _safe_int(item.get("total_preguntas_prev"), default=0),
        "respuestas_aceptadas_prev": _safe_int(
            item.get("respuestas_aceptadas_prev"),
            default=0,
        ),
        "tasa_aceptacion_prev_pct": round(
            _safe_float(item.get("tasa_aceptacion_prev_pct"), default=0.0),
            2,
        ),
        "delta_tasa_pct": round(
            _safe_float(item.get("delta_tasa_pct"), default=0.0),
            2,
        ),
        "delta_preguntas": _safe_int(item.get("delta_preguntas"), default=0),
        "sample_bucket": item.get("sample_bucket"),
        "confidence_score": round(
            _safe_float(item.get("confidence_score"), default=0.0),
            6,
        ),
        "raw_rank": _safe_int(item.get("raw_rank"), default=0),
        "confidence_rank": _safe_int(item.get("confidence_rank"), default=0),
    }


def _build_so_acceptance_summary(latest_items, previous_snapshot):
    summary = {
        "raw_leader": None,
        "confidence_leader": None,
        "highest_improvement": None,
        "largest_drop": None,
        "largest_sample": None,
    }
    if not latest_items:
        return summary

    raw_leader = min(
        latest_items,
        key=lambda item: (
            _safe_int(item.get("raw_rank"), default=9999),
            item.get("tecnologia", ""),
        ),
    )
    confidence_leader = min(
        latest_items,
        key=lambda item: (
            _safe_int(item.get("confidence_rank"), default=9999),
            item.get("tecnologia", ""),
        ),
    )
    largest_sample = max(
        latest_items,
        key=lambda item: (
            _safe_int(item.get("total_preguntas"), default=0),
            -_safe_int(item.get("raw_rank"), default=9999),
            item.get("tecnologia", ""),
        ),
    )

    summary["raw_leader"] = _summarize_so_acceptance_item(raw_leader)
    summary["confidence_leader"] = _summarize_so_acceptance_item(confidence_leader)
    summary["largest_sample"] = _summarize_so_acceptance_item(largest_sample)

    if previous_snapshot is None:
        return summary

    improvement_candidates = [
        item
        for item in latest_items
        if _safe_int(item.get("total_preguntas_prev"), default=0) > 0
        and _safe_float(item.get("delta_tasa_pct"), default=0.0) > 0
    ]
    drop_candidates = [
        item
        for item in latest_items
        if _safe_int(item.get("total_preguntas_prev"), default=0) > 0
        and _safe_float(item.get("delta_tasa_pct"), default=0.0) < 0
    ]

    highest_improvement = max(
        improvement_candidates,
        key=lambda item: (
            _safe_float(item.get("delta_tasa_pct"), default=0.0),
            _safe_int(item.get("total_preguntas"), default=0),
            item.get("tecnologia", ""),
        ),
        default=None,
    )
    largest_drop = min(
        drop_candidates,
        key=lambda item: (
            _safe_float(item.get("delta_tasa_pct"), default=0.0),
            -_safe_int(item.get("total_preguntas"), default=0),
            item.get("tecnologia", ""),
        ),
        default=None,
    )

    summary["highest_improvement"] = _summarize_so_acceptance_item(highest_improvement)
    summary["largest_drop"] = _summarize_so_acceptance_item(largest_drop)
    return summary


def _normalize_so_trends_df(df):
    working = df.copy()
    columns = [str(column).strip() for column in working.columns]
    if "mes" not in columns:
        working["mes"] = ""
        columns = [str(column).strip() for column in working.columns]

    rename_map = {column: str(column).strip() for column in working.columns}
    working = working.rename(columns=rename_map)
    working["mes"] = working["mes"].astype(str).str.strip()
    working = working[working["mes"] != ""].copy()
    working = working.sort_values("mes", ascending=True).reset_index(drop=True)

    technology_columns = [
        column
        for column in working.columns
        if column != "mes" and str(column).strip() != ""
    ]
    for column in technology_columns:
        working[column] = pd.to_numeric(working[column], errors="coerce").fillna(0).astype(int)

    return working, technology_columns


def _compute_so_trends_series(months, technology_label, points):
    start_value = _safe_int(points[0], default=0) if points else 0
    end_value = _safe_int(points[-1], default=0) if points else 0
    abs_delta = end_value - start_value
    pct_delta = 0.0
    retention_pct = 0.0
    if start_value > 0:
        pct_delta = round((abs_delta / start_value) * 100, 2)
        retention_pct = round((end_value / start_value) * 100, 2)

    peak_value = max(points) if points else 0
    peak_index = points.index(peak_value) if points else 0
    peak_month = months[peak_index] if points and peak_index < len(months) else None

    return {
        "tecnologia": technology_label,
        "points": [_safe_int(value, default=0) for value in points],
        "start_value": start_value,
        "end_value": end_value,
        "abs_delta": abs_delta,
        "pct_delta": pct_delta,
        "retention_pct": retention_pct,
        "peak_month": peak_month,
        "peak_value": _safe_int(peak_value, default=0),
        "latest_rank": 0,
    }


def _load_so_trends_metadata(project_root):
    metadata_path = project_root / "datos" / "metadata" / "so_tendencias_series.json"
    if not metadata_path.exists():
        return None

    try:
        payload = json.loads(metadata_path.read_text(encoding="utf-8"))
    except Exception as exc:  # pylint: disable=broad-exception-caught
        logger.warning(
            "Skipping StackOverflow trends metadata due to read error in %s: %s",
            metadata_path,
            exc,
        )
        return None

    raw_months = payload.get("months")
    raw_series = payload.get("series")
    if not isinstance(raw_months, list) or not isinstance(raw_series, list):
        return None

    months = [str(month).strip() for month in raw_months if str(month).strip()]
    if not months:
        return None

    series = []
    for item in raw_series:
        if not isinstance(item, dict):
            continue
        tecnologia = _normalize_so_trend_technology_label(item.get("tecnologia"))
        points = item.get("points")
        if not tecnologia or not isinstance(points, list) or len(points) != len(months):
            continue
        series.append(
            _compute_so_trends_series(
                months,
                tecnologia,
                [_safe_int(value, default=0) for value in points],
            )
        )

    if not series:
        return None
    return {"months": months, "series": series}


def _summarize_so_trends_series(item):
    if not item:
        return None
    return {
        "tecnologia": item.get("tecnologia"),
        "start_value": _safe_int(item.get("start_value"), default=0),
        "end_value": _safe_int(item.get("end_value"), default=0),
        "abs_delta": _safe_int(item.get("abs_delta"), default=0),
        "pct_delta": round(_safe_float(item.get("pct_delta"), default=0.0), 2),
        "retention_pct": round(_safe_float(item.get("retention_pct"), default=0.0), 2),
        "peak_month": item.get("peak_month"),
        "peak_value": _safe_int(item.get("peak_value"), default=0),
        "latest_rank": _safe_int(item.get("latest_rank"), default=0),
    }


def _build_so_trends_history_payload_from_series(months, series):
    ranking = sorted(
        series,
        key=lambda item: (
            -_safe_int(item.get("end_value"), default=0),
            item.get("tecnologia", "").lower(),
        ),
    )
    for rank, item in enumerate(ranking, start=1):
        item["latest_rank"] = rank

    series = sorted(
        ranking,
        key=lambda item: (
            _safe_int(item.get("latest_rank"), default=9999),
            item.get("tecnologia", "").lower(),
        ),
    )

    current_leader = series[0] if series else None
    best_retention = max(
        series,
        key=lambda item: (
            _safe_float(item.get("retention_pct"), default=0.0),
            _safe_int(item.get("end_value"), default=0),
            item.get("tecnologia", ""),
        ),
        default=None,
    )
    relative_drop_candidates = [
        item for item in series if _safe_float(item.get("pct_delta"), default=0.0) < 0
    ]
    absolute_drop_candidates = [
        item for item in series if _safe_int(item.get("abs_delta"), default=0) < 0
    ]
    largest_relative_drop = min(
        relative_drop_candidates,
        key=lambda item: (
            _safe_float(item.get("pct_delta"), default=0.0),
            item.get("tecnologia", ""),
        ),
        default=None,
    )
    largest_absolute_drop = min(
        absolute_drop_candidates,
        key=lambda item: (
            _safe_int(item.get("abs_delta"), default=0),
            item.get("tecnologia", ""),
        ),
        default=None,
    )

    return {
        "months": months,
        "series": series,
        "summary": {
            "current_leader": _summarize_so_trends_series(current_leader),
            "best_retention": _summarize_so_trends_series(best_retention),
            "largest_relative_drop": _summarize_so_trends_series(largest_relative_drop),
            "largest_absolute_drop": _summarize_so_trends_series(largest_absolute_drop),
        },
    }


def _build_so_trends_history_payload(df):
    working, technology_columns = _normalize_so_trends_df(df)
    months = working["mes"].astype(str).tolist()

    series = []
    for column in technology_columns:
        points = working[column].tolist()
        series.append(
            _compute_so_trends_series(
                months,
                _normalize_so_trend_technology_label(column),
                points,
            )
        )

    return _build_so_trends_history_payload_from_series(months, series)


def build_so_trends_history(project_root, history_index):
    """Build structured payload for StackOverflow monthly trends."""
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        ["so_tendencias", "so_tendencias_mensuales"],
    )

    source_mode = "missing"
    latest_df = None
    if sources:
        latest_source = sources[-1]
        csv_path = project_root / latest_source["path"]
        try:
            df = pd.read_csv(csv_path)
            if _is_valid_so_trends_df(df):
                latest_df = df
                history_count = sum(1 for item in sources if item["source_type"] == "history")
                source_mode = "history" if history_count > 0 else "latest"
            else:
                logger.warning(
                    "Skipping StackOverflow trends bridge due to missing required columns in %s",
                    csv_path,
                )
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning("Skipping StackOverflow trends bridge due to read error in %s: %s", csv_path, exc)

    payload = {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "so_tendencias_mensuales",
        "source_mode": source_mode,
        "snapshot_count": len(sources),
        "months": [],
        "series": [],
        "summary": {
            "current_leader": None,
            "best_retention": None,
            "largest_relative_drop": None,
            "largest_absolute_drop": None,
        },
    }
    metadata_payload = _load_so_trends_metadata(project_root)
    if metadata_payload is not None:
        if source_mode == "missing":
            payload["source_mode"] = "metadata"
        payload.update(
            _build_so_trends_history_payload_from_series(
                metadata_payload["months"],
                metadata_payload["series"],
            )
        )
        return payload

    if latest_df is None:
        return payload

    payload.update(_build_so_trends_history_payload(latest_df))
    return payload


def _normalize_highlight_entity(value):
    text = str(value or "").strip().lower()
    if not text:
        return ""
    normalized = []
    for char in text:
        if char.isalnum():
            normalized.append(char)
    return "".join(normalized)


def _highlight_candidate(*, dashboard, graph, signal, source, entity, score, payload):
    return {
        "dashboard": dashboard,
        "graph": graph,
        "signal": signal,
        "source": source,
        "entity": entity,
        "entity_key": _normalize_highlight_entity(entity),
        "score": round(_safe_float(score, default=0.0), 2),
        "payload": payload,
    }


def _score_github_language_highlight(item, summary):
    return (
        _safe_float(item.get("share_pct"), default=0.0) * 4
        + min(_safe_int(item.get("repos_count"), default=0) / 5, 80)
        + max(_safe_int(summary.get("leader_gap_repos"), default=0), 0) / 10
    )


def _score_github_framework_highlight(item, summary):
    return (
        _safe_float(summary.get("leader_share_pct"), default=0.0) * 4
        + min(_safe_int(item.get("commits_2025"), default=0) / 100, 80)
        + max(_safe_int(summary.get("leader_gap_commits"), default=0), 0) / 20
    )


def _score_github_correlation_highlight(item):
    return (
        max(_safe_float(item.get("outlier_score"), default=0.0), 0.0) * 8
        + (_safe_float(item.get("contributors_per_1k_stars"), default=0.0) / 2)
    )


def _score_reddit_sentiment_highlight(item):
    return (
        _safe_float(item.get("porcentaje_positivo"), default=0.0)
        * min(_safe_int(item.get("total_menciones"), default=0), 25)
        / 25
    )


def _score_reddit_topics_highlight(item):
    return (
        _safe_int(item.get("menciones"), default=0)
        + max(_safe_int(item.get("delta_menciones"), default=0), 0) * 3
    )


def _score_reddit_intersection_highlight(item):
    return (
        max(0.0, 100 - (_safe_int(item.get("brecha_abs"), default=999) * 15))
        + max(0.0, 30 - (_safe_float(item.get("promedio_rank"), default=999.0) * 3))
    )


def _score_so_volume_highlight(item):
    return (
        _safe_float(item.get("share_pct"), default=0.0) * 4
        + min(_safe_int(item.get("preguntas"), default=0) / 100, 120)
    )


def _score_so_acceptance_highlight(item):
    return (
        _safe_float(item.get("confidence_score"), default=0.0) * 300
        + min(_safe_int(item.get("total_preguntas"), default=0) / 50, 60)
    )


def _score_so_trends_highlight(item):
    return abs(min(_safe_float(item.get("pct_delta"), default=0.0), 0.0))


def _build_home_highlight_candidates(dashboard_signals):
    candidates = []

    github_signals = dashboard_signals.get("github", {})
    leader_language = github_signals.get("graph_1", {}).get("payload")
    if leader_language:
        candidates.append(
            _highlight_candidate(
                dashboard="github",
                graph=1,
                signal="leader",
                source="github_lenguajes_public.summary.leader",
                entity=leader_language.get("lenguaje"),
                score=_score_github_language_highlight(
                    leader_language,
                    github_signals.get("graph_1", {}).get("summary", {}),
                ),
                payload=leader_language,
            )
        )

    leader_framework = github_signals.get("graph_2", {}).get("payload")
    if leader_framework:
        candidates.append(
            _highlight_candidate(
                dashboard="github",
                graph=2,
                signal="leader",
                source="github_frameworks_history.summary.leader",
                entity=leader_framework.get("framework"),
                score=_score_github_framework_highlight(
                    leader_framework,
                    github_signals.get("graph_2", {}).get("summary", {}),
                ),
                payload=leader_framework,
            )
        )

    positive_outlier_repo = github_signals.get("graph_3", {}).get("payload")
    if positive_outlier_repo:
        candidates.append(
            _highlight_candidate(
                dashboard="github",
                graph=3,
                signal="positive_outlier_repo",
                source="github_correlacion_history.summary.positive_outlier_repo",
                entity=positive_outlier_repo.get("repo_name"),
                score=_score_github_correlation_highlight(positive_outlier_repo),
                payload=positive_outlier_repo,
            )
        )

    reddit_signals = dashboard_signals.get("reddit", {})
    positive_leader = reddit_signals.get("graph_1", {}).get("payload")
    if positive_leader:
        candidates.append(
            _highlight_candidate(
                dashboard="reddit",
                graph=1,
                signal="positive_leader",
                source="reddit_sentimiento_public.summary.positive_leader",
                entity=positive_leader.get("framework"),
                score=_score_reddit_sentiment_highlight(positive_leader),
                payload=positive_leader,
            )
        )

    leader_topic = reddit_signals.get("graph_2", {}).get("payload")
    if leader_topic:
        candidates.append(
            _highlight_candidate(
                dashboard="reddit",
                graph=2,
                signal="leader_topic",
                source="reddit_temas_history.summary.leader_topic",
                entity=leader_topic.get("tema"),
                score=_score_reddit_topics_highlight(leader_topic),
                payload=leader_topic,
            )
        )

    closest_alignment = reddit_signals.get("graph_3", {}).get("payload")
    if closest_alignment:
        candidates.append(
            _highlight_candidate(
                dashboard="reddit",
                graph=3,
                signal="closest_alignment",
                source="reddit_interseccion_history.summary.closest_alignment",
                entity=closest_alignment.get("tecnologia"),
                score=_score_reddit_intersection_highlight(closest_alignment),
                payload=closest_alignment,
            )
        )

    stack_signals = dashboard_signals.get("stackoverflow", {})
    leader_language = stack_signals.get("graph_1", {}).get("payload")
    if leader_language:
        candidates.append(
            _highlight_candidate(
                dashboard="stackoverflow",
                graph=1,
                signal="leader",
                source="so_volumen_history.summary.leader",
                entity=leader_language.get("lenguaje"),
                score=_score_so_volume_highlight(leader_language),
                payload=leader_language,
            )
        )

    confidence_leader = stack_signals.get("graph_2", {}).get("payload")
    if confidence_leader:
        candidates.append(
            _highlight_candidate(
                dashboard="stackoverflow",
                graph=2,
                signal="confidence_leader",
                source="so_aceptacion_history.summary.confidence_leader",
                entity=confidence_leader.get("tecnologia"),
                score=_score_so_acceptance_highlight(confidence_leader),
                payload=confidence_leader,
            )
        )

    largest_relative_drop = stack_signals.get("graph_3", {}).get("payload")
    if largest_relative_drop:
        candidates.append(
            _highlight_candidate(
                dashboard="stackoverflow",
                graph=3,
                signal="largest_relative_drop",
                source="so_tendencias_history.summary.largest_relative_drop",
                entity=largest_relative_drop.get("tecnologia"),
                score=_score_so_trends_highlight(largest_relative_drop),
                payload=largest_relative_drop,
            )
        )

    candidates.sort(
        key=lambda item: (
            -_safe_float(item.get("score"), default=0.0),
            item.get("dashboard", ""),
            _safe_int(item.get("graph"), default=9999),
            item.get("entity", ""),
        )
    )
    return candidates


def _select_home_highlights(candidates, limit=3):
    selected = []
    seen_entities = set()
    for candidate in candidates:
        entity_key = candidate.get("entity_key")
        if entity_key and entity_key in seen_entities:
            continue
        selected.append(candidate)
        if entity_key:
            seen_entities.add(entity_key)
        if len(selected) >= limit:
            return selected

    if len(selected) < limit:
        for candidate in candidates:
            if candidate in selected:
                continue
            selected.append(candidate)
            if len(selected) >= limit:
                break
    return selected


def build_home_highlights_payload(
    *,
    github_languages_payload,
    github_frameworks_payload,
    github_correlation_payload,
    reddit_sentiment_payload,
    reddit_topics_payload,
    reddit_intersection_payload,
    so_volume_payload,
    so_acceptance_payload,
    so_trends_payload,
):
    dashboard_signals = {
        "github": {
            "graph_1": {
                "signal": "leader",
                "source": "github_lenguajes_public.summary.leader",
                "payload": github_languages_payload.get("summary", {}).get("leader"),
                "summary": github_languages_payload.get("summary", {}),
            },
            "graph_2": {
                "signal": "leader",
                "source": "github_frameworks_history.summary.leader",
                "payload": github_frameworks_payload.get("summary", {}).get("leader"),
                "summary": github_frameworks_payload.get("summary", {}),
            },
            "graph_3": {
                "signal": "positive_outlier_repo",
                "source": "github_correlacion_history.summary.positive_outlier_repo",
                "payload": github_correlation_payload.get("summary", {}).get("positive_outlier_repo"),
                "summary": github_correlation_payload.get("summary", {}),
            },
        },
        "reddit": {
            "graph_1": {
                "signal": "positive_leader",
                "source": "reddit_sentimiento_public.summary.positive_leader",
                "payload": reddit_sentiment_payload.get("summary", {}).get("positive_leader"),
                "summary": reddit_sentiment_payload.get("summary", {}),
            },
            "graph_2": {
                "signal": "leader_topic",
                "source": "reddit_temas_history.summary.leader_topic",
                "payload": reddit_topics_payload.get("summary", {}).get("leader_topic"),
                "summary": reddit_topics_payload.get("summary", {}),
            },
            "graph_3": {
                "signal": "closest_alignment",
                "source": "reddit_interseccion_history.summary.closest_alignment",
                "payload": reddit_intersection_payload.get("summary", {}).get("closest_alignment"),
                "summary": reddit_intersection_payload.get("summary", {}),
            },
        },
        "stackoverflow": {
            "graph_1": {
                "signal": "leader",
                "source": "so_volumen_history.summary.leader",
                "payload": so_volume_payload.get("summary", {}).get("leader"),
                "summary": so_volume_payload.get("summary", {}),
            },
            "graph_2": {
                "signal": "confidence_leader",
                "source": "so_aceptacion_history.summary.confidence_leader",
                "payload": so_acceptance_payload.get("summary", {}).get("confidence_leader"),
                "summary": so_acceptance_payload.get("summary", {}),
            },
            "graph_3": {
                "signal": "largest_relative_drop",
                "source": "so_tendencias_history.summary.largest_relative_drop",
                "payload": so_trends_payload.get("summary", {}).get("largest_relative_drop"),
                "summary": so_trends_payload.get("summary", {}),
            },
        },
    }
    candidates = _build_home_highlight_candidates(dashboard_signals)
    highlights = _select_home_highlights(candidates, limit=3)
    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "home_highlights",
        "source_mode": "bridges",
        "candidate_count": len(candidates),
        "dashboard_signals": dashboard_signals,
        "highlights": highlights,
    }


def build_so_acceptance_history(project_root, history_index):
    """Build historical payload for StackOverflow acceptance metrics."""
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        ["so_aceptacion", "so_tasa_aceptacion"],
    )
    snapshots = []

    for source in sources:
        csv_path = project_root / source["path"]
        try:
            df = pd.read_csv(csv_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning(
                "Skipping StackOverflow acceptance snapshot %s due to read error: %s",
                csv_path,
                exc,
            )
            continue

        if not _is_valid_so_acceptance_df(df):
            logger.warning(
                "Skipping StackOverflow acceptance snapshot %s due to missing required columns",
                csv_path,
            )
            continue

        snapshots.append(
            _build_so_acceptance_snapshot_record(
                df,
                date_label=source["date"],
                relative_path=source["path"],
                source_type=source["source_type"],
            )
        )

    source_mode = "missing"
    if snapshots:
        history_count = sum(1 for item in snapshots if item["source_type"] == "history")
        source_mode = "history" if history_count > 0 else "latest"

    latest_snapshot = snapshots[-1] if snapshots else None
    previous_snapshot = snapshots[-2] if len(snapshots) >= 2 else None
    latest_items = _build_latest_so_acceptance_items(
        latest_snapshot=latest_snapshot,
        previous_snapshot=previous_snapshot,
    )

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "so_tasa_aceptacion",
        "source_mode": source_mode,
        "snapshot_count": len(snapshots),
        "latest_snapshot_date": latest_snapshot.get("date") if latest_snapshot else None,
        "previous_snapshot_date": previous_snapshot.get("date") if previous_snapshot else None,
        "has_historical_comparison": previous_snapshot is not None,
        "item_count": latest_snapshot.get("item_count", 0) if latest_snapshot else 0,
        "summary": _build_so_acceptance_summary(latest_items, previous_snapshot),
        "latest_items": latest_items,
        "snapshots": snapshots,
    }


def _compute_correlation_regression_metrics(df, snapshot_date):
    working = df.copy()
    if "repo_name" not in working.columns:
        working["repo_name"] = ""
    if "language" not in working.columns:
        working["language"] = "Sin especificar"

    working["repo_name"] = working["repo_name"].astype(str).str.strip()
    working["language"] = working["language"].astype(str).str.strip()
    working["stars"] = pd.to_numeric(working["stars"], errors="coerce").fillna(0).astype(int)
    working["contributors"] = pd.to_numeric(working["contributors"], errors="coerce").fillna(0).astype(int)
    working = working[working["repo_name"] != ""].copy()

    if working.empty:
        return working, 0.0

    x = working["stars"].astype(float)
    y = working["contributors"].astype(float)
    correlation = float(x.corr(y)) if len(working) > 1 else 0.0
    if pd.isna(correlation):
        correlation = 0.0

    mean_x = float(x.mean()) if len(working) > 0 else 0.0
    mean_y = float(y.mean()) if len(working) > 0 else 0.0
    variance_x = float(((x - mean_x) ** 2).mean()) if len(working) > 0 else 0.0
    if variance_x > 0:
        covariance_xy = float(((x - mean_x) * (y - mean_y)).mean())
        slope = covariance_xy / variance_x
        intercept = mean_y - (slope * mean_x)
        expected = (slope * x) + intercept
    else:
        expected = pd.Series([mean_y] * len(working), index=working.index, dtype="float64")

    expected = expected.clip(lower=0.0)
    residuals = y - expected
    residual_std = float(residuals.std(ddof=0))
    if pd.isna(residual_std):
        residual_std = 0.0
    if residual_std > 0:
        outlier_scores = residuals / residual_std
    else:
        outlier_scores = pd.Series([0.0] * len(working), index=working.index, dtype="float64")

    working["engagement_ratio"] = working.apply(
        lambda row: round((row["contributors"] / row["stars"]) if row["stars"] > 0 else 0.0, 6),
        axis=1,
    )
    working["contributors_per_1k_stars"] = working["engagement_ratio"].mul(1000).round(3)
    working["expected_contributors"] = expected.round(3)
    working["contributors_delta_vs_trend"] = residuals.round(3)
    working["outlier_score"] = outlier_scores.round(6)
    working["trend_bucket"] = working["outlier_score"].apply(
        lambda score: "above_trend" if score >= 1.0 else "below_trend" if score <= -1.0 else "near_trend"
    )
    working["snapshot_date_utc"] = snapshot_date
    return working, correlation


def _summarize_github_correlation_repo(item):
    if not item:
        return None
    return {
        "repo_name": item.get("repo_name"),
        "stars": item.get("stars"),
        "contributors": item.get("contributors"),
        "language": item.get("language"),
        "engagement_ratio": item.get("engagement_ratio"),
        "contributors_per_1k_stars": item.get("contributors_per_1k_stars"),
        "outlier_score": item.get("outlier_score"),
        "trend_bucket": item.get("trend_bucket"),
    }


def _build_github_correlation_snapshot_record(df, date_label, relative_path, source_type):
    working, correlation_value = _compute_correlation_regression_metrics(df, snapshot_date=date_label)
    items = []
    for _, row in working.iterrows():
        items.append(
            {
                "repo_name": str(row.get("repo_name", "")).strip(),
                "stars": _safe_int(row.get("stars"), default=0),
                "contributors": _safe_int(row.get("contributors"), default=0),
                "language": str(row.get("language", "")).strip() or "Sin especificar",
                "engagement_ratio": round(_safe_float(row.get("engagement_ratio"), default=0.0), 6),
                "contributors_per_1k_stars": round(
                    _safe_float(row.get("contributors_per_1k_stars"), default=0.0),
                    3,
                ),
                "expected_contributors": round(_safe_float(row.get("expected_contributors"), default=0.0), 3),
                "contributors_delta_vs_trend": round(
                    _safe_float(row.get("contributors_delta_vs_trend"), default=0.0),
                    3,
                ),
                "outlier_score": round(_safe_float(row.get("outlier_score"), default=0.0), 6),
                "trend_bucket": str(row.get("trend_bucket", "near_trend")).strip() or "near_trend",
                "snapshot_date_utc": str(row.get("snapshot_date_utc", date_label)).strip() or date_label,
            }
        )

    items.sort(
        key=lambda item: (
            -_safe_int(item.get("stars"), default=0),
            -_safe_int(item.get("contributors"), default=0),
            item.get("repo_name", "").lower(),
        )
    )

    return {
        "date": date_label,
        "path": relative_path,
        "source_type": source_type,
        "row_count": len(items),
        "item_count": len(items),
        "correlation_value": round(correlation_value, 4),
        "items": items,
    }


def _build_github_correlation_summary(latest_snapshot, previous_snapshot):
    latest_items = latest_snapshot.get("items", []) if latest_snapshot else []
    if not latest_items:
        return {
            "correlation_value": None,
            "top_stars_repo": None,
            "top_contributors_repo": None,
            "top_engagement_repo": None,
            "positive_outlier_repo": None,
            "negative_outlier_repo": None,
            "item_count": 0,
            "latest_snapshot_date": latest_snapshot.get("date") if latest_snapshot else None,
            "previous_snapshot_date": previous_snapshot.get("date") if previous_snapshot else None,
        }

    top_stars_repo = max(
        latest_items,
        key=lambda item: (_safe_int(item.get("stars"), default=0), item.get("repo_name", "")),
    )
    top_contributors_repo = max(
        latest_items,
        key=lambda item: (_safe_int(item.get("contributors"), default=0), item.get("repo_name", "")),
    )
    top_engagement_repo = max(
        latest_items,
        key=lambda item: (_safe_float(item.get("engagement_ratio"), default=0.0), item.get("repo_name", "")),
    )
    positive_outlier_repo = max(
        latest_items,
        key=lambda item: (_safe_float(item.get("outlier_score"), default=0.0), item.get("repo_name", "")),
    )
    negative_outlier_repo = min(
        latest_items,
        key=lambda item: (_safe_float(item.get("outlier_score"), default=0.0), item.get("repo_name", "")),
    )

    return {
        "correlation_value": latest_snapshot.get("correlation_value"),
        "top_stars_repo": _summarize_github_correlation_repo(top_stars_repo),
        "top_contributors_repo": _summarize_github_correlation_repo(top_contributors_repo),
        "top_engagement_repo": _summarize_github_correlation_repo(top_engagement_repo),
        "positive_outlier_repo": _summarize_github_correlation_repo(positive_outlier_repo),
        "negative_outlier_repo": _summarize_github_correlation_repo(negative_outlier_repo),
        "item_count": len(latest_items),
        "latest_snapshot_date": latest_snapshot.get("date") if latest_snapshot else None,
        "previous_snapshot_date": previous_snapshot.get("date") if previous_snapshot else None,
    }


def _build_github_frameworks_snapshot_record(df, date_label, relative_path, source_type):
    working = df.copy()
    if "framework" not in working.columns:
        working["framework"] = ""
    if "repo" not in working.columns:
        working["repo"] = ""
    if "ranking" not in working.columns:
        working["ranking"] = None
    for metric in GITHUB_FRAMEWORK_METRICS:
        if metric not in working.columns:
            working[metric] = None
    if "commits_prev" not in working.columns:
        working["commits_prev"] = None
    if "delta_commits" not in working.columns:
        working["delta_commits"] = None
    if "growth_pct" not in working.columns:
        working["growth_pct"] = None
    if "trend_direction" not in working.columns:
        working["trend_direction"] = None

    working["framework"] = working["framework"].astype(str).str.strip()
    working = working[working["framework"] != ""]

    items = []
    for _, row in working.iterrows():
        trend_direction_raw = str(row.get("trend_direction", "")).strip()
        trend_direction = (
            None
            if trend_direction_raw.lower() in {"", "none", "nan", "null"}
            else trend_direction_raw
        )
        items.append(
            {
                "framework": str(row.get("framework", "")).strip(),
                "repo": str(row.get("repo", "")).strip(),
                "ranking": _safe_nullable_int(row.get("ranking")),
                "commits_2025": _safe_int(row.get("commits_2025"), default=0),
                "active_contributors": _safe_nullable_int(row.get("active_contributors")),
                "merged_prs": _safe_nullable_int(row.get("merged_prs")),
                "closed_issues": _safe_nullable_int(row.get("closed_issues")),
                "releases_count": _safe_nullable_int(row.get("releases_count")),
                "commits_prev": _safe_nullable_int(row.get("commits_prev")),
                "delta_commits": _safe_nullable_int(row.get("delta_commits")),
                "growth_pct": _safe_nullable_float(row.get("growth_pct")),
                "trend_direction": trend_direction,
            }
        )

    items.sort(
        key=lambda item: (
            item["ranking"] if item["ranking"] is not None else 9999,
            -_safe_int(item.get("commits_2025"), default=0),
            item["framework"].lower(),
        )
    )

    return {
        "date": date_label,
        "path": relative_path,
        "source_type": source_type,
        "row_count": len(items),
        "framework_count": len(items),
        "items": items,
    }


def _compute_metric_delta(current_value, previous_value):
    if current_value is None or previous_value is None:
        return None, None
    delta_value = current_value - previous_value
    growth_pct = None
    if previous_value > 0:
        growth_pct = round((delta_value / previous_value) * 100, 2)
    return delta_value, growth_pct


def _build_latest_github_frameworks_with_growth(*, latest_snapshot, previous_snapshot):
    previous_map = {}
    if previous_snapshot is not None:
        previous_map = {
            str(item.get("framework", "")).strip().lower(): item
            for item in previous_snapshot.get("items", [])
            if str(item.get("framework", "")).strip()
        }

    latest_items = []
    for item in latest_snapshot.get("items", []):
        framework_key = str(item.get("framework", "")).strip().lower()
        prev_item = previous_map.get(framework_key)
        merged = dict(item)

        prev_commits = merged.get("commits_prev")
        if prev_commits is None and prev_item is not None:
            prev_commits = prev_item.get("commits_2025")
        merged["commits_prev"] = prev_commits

        delta_commits = merged.get("delta_commits")
        growth_pct = merged.get("growth_pct")
        if delta_commits is None and prev_commits is not None:
            delta_commits, growth_pct = _compute_metric_delta(
                merged.get("commits_2025"),
                prev_commits,
            )
        if growth_pct is None and prev_commits is not None:
            _, growth_pct = _compute_metric_delta(merged.get("commits_2025"), prev_commits)
        merged["delta_commits"] = delta_commits
        merged["growth_pct"] = growth_pct
        if not merged.get("trend_direction"):
            if delta_commits is None:
                merged["trend_direction"] = None
            elif delta_commits > 0:
                merged["trend_direction"] = "creciendo"
            elif delta_commits < 0:
                merged["trend_direction"] = "cayendo"
            else:
                merged["trend_direction"] = "estable"

        for metric in ("active_contributors", "merged_prs", "closed_issues", "releases_count"):
            prev_field = f"{metric}_prev"
            delta_field = f"delta_{metric}"
            growth_field = f"growth_{metric}_pct"
            prev_value = prev_item.get(metric) if prev_item else None
            merged[prev_field] = prev_value
            delta_value, growth_value = _compute_metric_delta(
                merged.get(metric),
                prev_value,
            )
            merged[delta_field] = delta_value
            merged[growth_field] = growth_value

        latest_items.append(merged)

    latest_items.sort(
        key=lambda item: (
            item["ranking"] if item.get("ranking") is not None else 9999,
            -_safe_int(item.get("commits_2025"), default=0),
            str(item.get("framework", "")).lower(),
        )
    )
    return latest_items


def _summarize_github_framework(item):
    if not item:
        return None
    return {
        "framework": item.get("framework"),
        "repo": item.get("repo"),
        "ranking": _safe_nullable_int(item.get("ranking")),
        "commits_2025": _safe_int(item.get("commits_2025"), default=0),
        "delta_commits": _safe_nullable_int(item.get("delta_commits")),
        "growth_pct": _safe_nullable_float(item.get("growth_pct")),
        "trend_direction": item.get("trend_direction"),
    }


def _build_github_frameworks_summary(latest_items):
    if not latest_items:
        return {
            "leader": None,
            "runner_up": None,
            "leader_share_pct": None,
            "leader_gap_commits": None,
            "highest_growth": None,
            "largest_drop": None,
            "total_commits": 0,
            "leader_framework": None,
            "leader_commits": None,
            "max_growth_framework": None,
            "max_growth_delta": None,
            "max_drop_framework": None,
            "max_drop_delta": None,
            "missing_metrics_frameworks": 0,
        }

    leader = max(
        latest_items,
        key=lambda item: (_safe_int(item.get("commits_2025"), default=0), item.get("framework", "")),
    )
    ranked_by_commits = sorted(
        latest_items,
        key=lambda item: (
            -_safe_int(item.get("commits_2025"), default=0),
            item.get("framework", ""),
        ),
    )
    runner_up = ranked_by_commits[1] if len(ranked_by_commits) >= 2 else None
    growth_items = [
        item for item in latest_items if isinstance(item.get("delta_commits"), int)
    ]
    max_growth = max(
        growth_items,
        key=lambda item: (item.get("delta_commits", -999999), item.get("framework", "")),
        default=None,
    )
    max_drop = min(
        growth_items,
        key=lambda item: (item.get("delta_commits", 999999), item.get("framework", "")),
        default=None,
    )
    missing_metrics_frameworks = sum(
        1
        for item in latest_items
        if any(item.get(metric) is None for metric in GITHUB_FRAMEWORK_METRICS)
    )
    total_commits = sum(_safe_int(item.get("commits_2025"), default=0) for item in latest_items)
    leader_share_pct = (
        round((_safe_int(leader.get("commits_2025"), default=0) / total_commits) * 100, 2)
        if total_commits > 0
        else 0.0
    )
    leader_gap_commits = (
        _safe_int(leader.get("commits_2025"), default=0)
        - _safe_int(runner_up.get("commits_2025"), default=0)
        if runner_up is not None
        else None
    )
    highest_growth = max(
        [
            item
            for item in latest_items
            if _safe_nullable_int(item.get("delta_commits")) is not None
            and _safe_int(item.get("delta_commits"), default=0) > 0
        ],
        key=lambda item: (
            _safe_int(item.get("delta_commits"), default=0),
            _safe_int(item.get("commits_2025"), default=0),
            item.get("framework", ""),
        ),
        default=None,
    )
    largest_drop = min(
        [
            item
            for item in latest_items
            if _safe_nullable_int(item.get("delta_commits")) is not None
            and _safe_int(item.get("delta_commits"), default=0) < 0
        ],
        key=lambda item: (
            _safe_int(item.get("delta_commits"), default=0),
            -_safe_int(item.get("commits_2025"), default=0),
            item.get("framework", ""),
        ),
        default=None,
    )

    return {
        "leader": _summarize_github_framework(leader),
        "runner_up": _summarize_github_framework(runner_up),
        "leader_share_pct": leader_share_pct,
        "leader_gap_commits": leader_gap_commits,
        "highest_growth": _summarize_github_framework(highest_growth),
        "largest_drop": _summarize_github_framework(largest_drop),
        "total_commits": total_commits,
        "leader_framework": leader.get("framework"),
        "leader_commits": leader.get("commits_2025"),
        "max_growth_framework": max_growth.get("framework") if max_growth else None,
        "max_growth_delta": max_growth.get("delta_commits") if max_growth else None,
        "max_drop_framework": max_drop.get("framework") if max_drop else None,
        "max_drop_delta": max_drop.get("delta_commits") if max_drop else None,
        "missing_metrics_frameworks": missing_metrics_frameworks,
    }


def _build_github_frameworks_monthly_series(project_root, history_index):
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        ["github_commits_monthly", "github_commits_frameworks_monthly"],
    )
    if not sources:
        return []

    latest_source = sources[-1]
    csv_path = project_root / latest_source["path"]
    try:
        df = pd.read_csv(csv_path)
    except Exception as exc:  # pylint: disable=broad-exception-caught
        logger.warning("Skipping github monthly snapshot %s due to read error: %s", csv_path, exc)
        return []

    required = {"framework", "month", "commits"}
    if not required.issubset(df.columns):
        return []

    working = df.copy()
    working["framework"] = working["framework"].astype(str).str.strip()
    working["month"] = working["month"].astype(str).str.strip()
    working["commits"] = pd.to_numeric(working["commits"], errors="coerce").fillna(0).astype(int)
    working = working[(working["framework"] != "") & (working["month"] != "")]

    series = []
    for framework, group in working.groupby("framework"):
        points = (
            group.sort_values("month", ascending=True)[["month", "commits"]]
            .to_dict(orient="records")
        )
        series.append(
            {
                "framework": framework,
                "points": points,
            }
        )
    series.sort(key=lambda item: item["framework"].lower())
    return series


def build_github_frameworks_history(project_root, history_index):
    """Construye payload histórico para commits de frameworks GitHub."""
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        ["github_commits", "github_commits_frameworks"],
    )
    snapshots = []

    for source in sources:
        csv_path = project_root / source["path"]
        try:
            df = pd.read_csv(csv_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning("Skipping github frameworks snapshot %s due to read error: %s", csv_path, exc)
            continue

        if not _is_valid_github_frameworks_df(df):
            logger.warning("Skipping github frameworks snapshot %s due to missing required columns", csv_path)
            continue

        snapshots.append(
            _build_github_frameworks_snapshot_record(
                df,
                date_label=source["date"],
                relative_path=source["path"],
                source_type=source["source_type"],
            )
        )

    source_mode = "missing"
    if snapshots:
        history_count = sum(1 for item in snapshots if item["source_type"] == "history")
        source_mode = "history" if history_count > 0 else "latest"

    latest_snapshot = snapshots[-1] if snapshots else None
    previous_snapshot = snapshots[-2] if len(snapshots) >= 2 else None
    latest_items = (
        _build_latest_github_frameworks_with_growth(
            latest_snapshot=latest_snapshot,
            previous_snapshot=previous_snapshot,
        )
        if latest_snapshot is not None
        else []
    )
    monthly_series = _build_github_frameworks_monthly_series(project_root, history_index)

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "github_commits_frameworks",
        "scope_label": "repos oficiales frontend",
        "source_mode": source_mode,
        "snapshot_count": len(snapshots),
        "snapshot_date": latest_snapshot["date"] if latest_snapshot else None,
        "latest_snapshot_date": latest_snapshot["date"] if latest_snapshot else None,
        "previous_snapshot_date": previous_snapshot["date"] if previous_snapshot else None,
        "item_count": latest_snapshot["row_count"] if latest_snapshot else 0,
        "has_historical_comparison": previous_snapshot is not None,
        "latest_frameworks": latest_items,
        "summary": _build_github_frameworks_summary(latest_items),
        "snapshots": snapshots,
        "series": monthly_series,
    }


def build_github_correlation_history(project_root, history_index):
    """Construye payload histórico para correlación GitHub stars vs contributors."""
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        "github_correlacion",
    )
    snapshots = []

    for source in sources:
        csv_path = project_root / source["path"]
        try:
            df = pd.read_csv(csv_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning("Skipping github correlation snapshot %s due to read error: %s", csv_path, exc)
            continue

        if not _is_valid_github_correlation_df(df):
            logger.warning("Skipping github correlation snapshot %s due to missing required columns", csv_path)
            continue

        snapshots.append(
            _build_github_correlation_snapshot_record(
                df,
                date_label=source["date"],
                relative_path=source["path"],
                source_type=source["source_type"],
            )
        )

    source_mode = "missing"
    if snapshots:
        history_count = sum(1 for item in snapshots if item["source_type"] == "history")
        source_mode = "history" if history_count > 0 else "latest"

    latest_snapshot = snapshots[-1] if snapshots else None
    previous_snapshot = snapshots[-2] if len(snapshots) >= 2 else None
    latest_items = latest_snapshot.get("items", []) if latest_snapshot else []

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "github_correlacion",
        "source_mode": source_mode,
        "snapshot_count": len(snapshots),
        "latest_snapshot_date": latest_snapshot.get("date") if latest_snapshot else None,
        "previous_snapshot_date": previous_snapshot.get("date") if previous_snapshot else None,
        "item_count": latest_snapshot.get("row_count", 0) if latest_snapshot else 0,
        "has_historical_comparison": previous_snapshot is not None,
        "summary": _build_github_correlation_summary(latest_snapshot, previous_snapshot),
        "latest_items": latest_items,
        "snapshots": snapshots,
    }


def _is_valid_reddit_topics_df(df):
    required_columns = {"tema", "menciones"}
    return required_columns.issubset(df.columns)


def _build_reddit_topics_snapshot_record(df, date_label, relative_path, source_type):
    working = df.copy()
    if "tema" not in working.columns:
        working["tema"] = ""
    if "menciones" not in working.columns:
        working["menciones"] = 0

    working["tema"] = working["tema"].astype(str).str.strip()
    working["menciones"] = pd.to_numeric(working["menciones"], errors="coerce").fillna(0).astype(int)
    working = working[working["tema"] != ""]
    working = working.sort_values(["menciones", "tema"], ascending=[False, True]).reset_index(drop=True)

    total_mentions = int(working["menciones"].sum()) if not working.empty else 0
    top_topics = []
    for _, row in working.head(10).iterrows():
        mentions = _safe_int(row.get("menciones"), default=0)
        share_pct = (mentions / total_mentions * 100) if total_mentions > 0 else 0.0
        top_topics.append(
            {
                "tema": str(row.get("tema", "")),
                "menciones": mentions,
                "participacion_pct": round(share_pct, 2),
            }
        )

    return {
        "date": date_label,
        "path": relative_path,
        "source_type": source_type,
        "row_count": len(working),
        "total_menciones": total_mentions,
        "top_topics": top_topics,
    }


def _build_reddit_topics_series(snapshots_with_df):
    series_map = {}
    for snapshot in snapshots_with_df:
        date_label = snapshot["date"]
        df = snapshot["dataframe"]
        if df.empty:
            continue
        total_mentions = int(df["menciones"].sum())
        for _, row in df.iterrows():
            tema = str(row.get("tema", "")).strip()
            if not tema:
                continue
            mentions = _safe_int(row.get("menciones"), default=0)
            share_pct = (mentions / total_mentions * 100) if total_mentions > 0 else 0.0
            series_map.setdefault(tema, [])
            series_map[tema].append(
                {
                    "date": date_label,
                    "menciones": mentions,
                    "participacion_pct": round(share_pct, 2),
                }
            )

    series = []
    for tema, points in series_map.items():
        sorted_points = sorted(points, key=lambda item: item["date"])
        latest_mentions = sorted_points[-1]["menciones"] if sorted_points else 0
        series.append(
            {
                "tema": tema,
                "points": sorted_points,
                "_latest_mentions": latest_mentions,
            }
        )

    series = sorted(series, key=lambda item: (-item["_latest_mentions"], item["tema"].lower()))
    for item in series:
        item.pop("_latest_mentions", None)
    return series


def _build_latest_reddit_topics_with_growth(*, latest_df, previous_df):
    latest_sorted = latest_df.sort_values(["menciones", "tema"], ascending=[False, True]).reset_index(drop=True)
    previous_by_topic = {}
    if previous_df is not None and not previous_df.empty:
        previous_by_topic = {
            str(row.get("tema", "")).strip(): _safe_int(row.get("menciones"), default=0)
            for _, row in previous_df.iterrows()
        }

    latest_topics = []
    for _, row in latest_sorted.iterrows():
        tema = str(row.get("tema", "")).strip()
        if not tema:
            continue
        mentions = _safe_int(row.get("menciones"), default=0)
        prev_mentions = previous_by_topic.get(tema)
        delta_mentions = None if prev_mentions is None else mentions - prev_mentions
        growth_pct = None
        if prev_mentions is not None and prev_mentions > 0:
            growth_pct = round(((mentions - prev_mentions) / prev_mentions) * 100, 2)
        trend_direction = None
        if delta_mentions is not None:
            if delta_mentions > 0:
                trend_direction = "creciendo"
            elif delta_mentions < 0:
                trend_direction = "cayendo"
            else:
                trend_direction = "estable"

        latest_topics.append(
            {
                "tema": tema,
                "menciones": mentions,
                "menciones_previas": prev_mentions,
                "delta_menciones": delta_mentions,
                "growth_pct": growth_pct,
                "trend_direction": trend_direction,
            }
        )

    return latest_topics


def _summarize_reddit_topic(item):
    if not item:
        return None
    return {
        "tema": item.get("tema"),
        "menciones": _safe_int(item.get("menciones"), default=0),
        "menciones_previas": _safe_nullable_int(item.get("menciones_previas")),
        "delta_menciones": _safe_nullable_int(item.get("delta_menciones")),
        "growth_pct": _safe_nullable_float(item.get("growth_pct")),
        "trend_direction": item.get("trend_direction"),
    }


def _build_reddit_topics_summary(latest_topics, latest_snapshot, previous_snapshot):
    summary = {
        "leader_topic": None,
        "highest_growth_topic": None,
        "largest_drop_topic": None,
        "total_menciones": latest_snapshot.get("total_menciones", 0) if latest_snapshot else 0,
        "topic_count": len(latest_topics),
    }
    if not latest_topics:
        return summary

    leader_topic = max(
        latest_topics,
        key=lambda item: (
            _safe_int(item.get("menciones"), default=0),
            item.get("tema", ""),
        ),
    )
    summary["leader_topic"] = _summarize_reddit_topic(leader_topic)

    if previous_snapshot is None:
        return summary

    growth_candidates = [
        item
        for item in latest_topics
        if _safe_int(item.get("menciones_previas"), default=0) > 0
        and _safe_int(item.get("delta_menciones"), default=0) > 0
    ]
    drop_candidates = [
        item
        for item in latest_topics
        if _safe_int(item.get("menciones_previas"), default=0) > 0
        and _safe_int(item.get("delta_menciones"), default=0) < 0
    ]
    highest_growth_topic = max(
        growth_candidates,
        key=lambda item: (
            _safe_int(item.get("delta_menciones"), default=0),
            _safe_int(item.get("menciones"), default=0),
            item.get("tema", ""),
        ),
        default=None,
    )
    largest_drop_topic = min(
        drop_candidates,
        key=lambda item: (
            _safe_int(item.get("delta_menciones"), default=0),
            -_safe_int(item.get("menciones"), default=0),
            item.get("tema", ""),
        ),
        default=None,
    )
    summary["highest_growth_topic"] = _summarize_reddit_topic(highest_growth_topic)
    summary["largest_drop_topic"] = _summarize_reddit_topic(largest_drop_topic)
    return summary


def build_reddit_topics_history(project_root, history_index):
    """Construye payload histórico para reddit_temas_emergentes con crecimiento opcional."""
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        ["reddit_temas_emergentes", "reddit_temas"],
    )
    snapshots = []
    snapshots_with_df = []

    for source in sources:
        csv_path = project_root / source["path"]
        try:
            df = pd.read_csv(csv_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning("Skipping reddit topics snapshot %s due to read error: %s", csv_path, exc)
            continue

        if not _is_valid_reddit_topics_df(df):
            logger.warning("Skipping reddit topics snapshot %s due to missing required columns", csv_path)
            continue

        working = df.copy()
        working["tema"] = working["tema"].astype(str).str.strip()
        working["menciones"] = pd.to_numeric(working["menciones"], errors="coerce").fillna(0).astype(int)
        working = working[working["tema"] != ""]
        working = working.sort_values(["menciones", "tema"], ascending=[False, True]).reset_index(drop=True)

        snapshots.append(
            _build_reddit_topics_snapshot_record(
                working,
                date_label=source["date"],
                relative_path=source["path"],
                source_type=source["source_type"],
            )
        )
        snapshots_with_df.append({"date": source["date"], "dataframe": working})

    source_mode = "missing"
    if snapshots:
        history_count = sum(1 for item in snapshots if item["source_type"] == "history")
        source_mode = "history" if history_count > 0 else "latest"

    latest_snapshot_date = snapshots[-1]["date"] if snapshots else None
    previous_snapshot_date = snapshots[-2]["date"] if len(snapshots) >= 2 else None
    latest_df = snapshots_with_df[-1]["dataframe"] if snapshots_with_df else pd.DataFrame(columns=["tema", "menciones"])
    previous_df = snapshots_with_df[-2]["dataframe"] if len(snapshots_with_df) >= 2 else None

    latest_topics = _build_latest_reddit_topics_with_growth(
        latest_df=latest_df,
        previous_df=previous_df,
    )

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "reddit_temas_emergentes",
        "source_mode": source_mode,
        "snapshot_count": len(snapshots),
        "latest_snapshot_date": latest_snapshot_date,
        "previous_snapshot_date": previous_snapshot_date,
        "topic_count": len(latest_topics),
        "summary": _build_reddit_topics_summary(
            latest_topics,
            snapshots[-1] if snapshots else None,
            snapshots[-2] if len(snapshots) >= 2 else None,
        ),
        "latest_topics": latest_topics,
        "snapshots": snapshots,
        "series": _build_reddit_topics_series(snapshots_with_df),
    }


def _parse_optional_rank(value):
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return int(value)

    text = str(value).strip()
    if not text:
        return None
    if text.lower() in {"no encontrado", "n/a", "none", "nan"}:
        return None

    try:
        return int(float(text))
    except (TypeError, ValueError):
        return None


def _intersection_direction(github_rank, reddit_rank):
    if github_rank is None or reddit_rank is None:
        return "incompleto"
    if github_rank == reddit_rank:
        return "consenso"
    return "github_favorece" if github_rank < reddit_rank else "reddit_favorece"


def _intersection_gap(github_rank, reddit_rank):
    if github_rank is None or reddit_rank is None:
        return None
    return abs(github_rank - reddit_rank)


def _enforce_unique_rankings(items, rank_key):
    ranked_indices = [
        idx for idx, item in enumerate(items) if item.get(rank_key) is not None
    ]
    ranked_indices.sort(
        key=lambda idx: (
            items[idx].get(rank_key),
            str(items[idx].get("tecnologia", "")).lower(),
        )
    )

    next_rank = 1
    for idx in ranked_indices:
        rank_value = _safe_nullable_int(items[idx].get(rank_key))
        if rank_value is None:
            continue
        if rank_value < next_rank:
            rank_value = next_rank
        items[idx][rank_key] = rank_value
        next_rank = rank_value + 1


def _build_reddit_intersection_snapshot_record(df, date_label, relative_path, source_type):
    working = df.copy()
    if "tecnologia" not in working.columns:
        working["tecnologia"] = ""
    if "tipo" not in working.columns:
        working["tipo"] = ""
    if "ranking_github" not in working.columns:
        working["ranking_github"] = None
    if "ranking_reddit" not in working.columns:
        working["ranking_reddit"] = None

    items = []
    for _, row in working.iterrows():
        tecnologia = str(row.get("tecnologia", "")).strip()
        if not tecnologia:
            continue
        ranking_github = _parse_optional_rank(row.get("ranking_github"))
        ranking_reddit = _parse_optional_rank(row.get("ranking_reddit"))
        gap = _intersection_gap(ranking_github, ranking_reddit)
        avg_rank = (
            round((ranking_github + ranking_reddit) / 2, 2)
            if ranking_github is not None and ranking_reddit is not None
            else None
        )
        items.append(
            {
                "tecnologia": tecnologia,
                "tipo": str(row.get("tipo", "")).strip(),
                "ranking_github": ranking_github,
                "ranking_reddit": ranking_reddit,
                "brecha_abs": gap,
                "promedio_rank": avg_rank,
                "direccion": _intersection_direction(ranking_github, ranking_reddit),
            }
        )

    # Enforce deterministic unique ranks only on comparable items.
    comparable_items = [
        item
        for item in items
        if item.get("ranking_github") is not None
        and item.get("ranking_reddit") is not None
    ]
    _enforce_unique_rankings(comparable_items, "ranking_github")
    _enforce_unique_rankings(comparable_items, "ranking_reddit")
    for item in items:
        ranking_github = item.get("ranking_github")
        ranking_reddit = item.get("ranking_reddit")
        item["brecha_abs"] = _intersection_gap(ranking_github, ranking_reddit)
        item["promedio_rank"] = (
            round((ranking_github + ranking_reddit) / 2, 2)
            if ranking_github is not None and ranking_reddit is not None
            else None
        )
        item["direccion"] = _intersection_direction(ranking_github, ranking_reddit)

    comparable_count = sum(
        1
        for item in items
        if item["ranking_github"] is not None and item["ranking_reddit"] is not None
    )
    coverage_pct = round((comparable_count / len(items) * 100), 2) if items else 0.0

    items.sort(
        key=lambda item: (
            item["promedio_rank"] if item["promedio_rank"] is not None else 9999,
            item["tecnologia"].lower(),
        )
    )

    return {
        "date": date_label,
        "path": relative_path,
        "source_type": source_type,
        "row_count": len(items),
        "comparable_count": comparable_count,
        "coverage_pct": coverage_pct,
        "items": items,
    }


def _build_latest_intersection_items_with_delta(*, latest_snapshot, previous_snapshot):
    previous_map = {}
    if previous_snapshot is not None:
        previous_map = {
            str(item.get("tecnologia", "")).strip().lower(): item
            for item in previous_snapshot.get("items", [])
            if str(item.get("tecnologia", "")).strip()
        }

    latest_items = []
    for item in latest_snapshot.get("items", []):
        tech_key = str(item.get("tecnologia", "")).strip().lower()
        prev_item = previous_map.get(tech_key)

        rank_github_prev = prev_item.get("ranking_github") if prev_item else None
        rank_reddit_prev = prev_item.get("ranking_reddit") if prev_item else None
        current_gap = item.get("brecha_abs")
        prev_gap = prev_item.get("brecha_abs") if prev_item else None
        delta_gap = (
            current_gap - prev_gap
            if isinstance(current_gap, int) and isinstance(prev_gap, int)
            else None
        )
        trend_direction = None
        if delta_gap is not None:
            if delta_gap < 0:
                trend_direction = "disminuyendo"
            elif delta_gap > 0:
                trend_direction = "aumentando"
            else:
                trend_direction = "estable"

        latest_items.append(
            {
                **item,
                "rank_github_prev": rank_github_prev,
                "rank_reddit_prev": rank_reddit_prev,
                "delta_gap": delta_gap,
                "trend_direction": trend_direction,
            }
        )

    return latest_items


def _summarize_intersection_item(item):
    if not item:
        return None
    return {
        "tecnologia": item.get("tecnologia"),
        "tipo": item.get("tipo"),
        "ranking_github": _safe_nullable_int(item.get("ranking_github")),
        "ranking_reddit": _safe_nullable_int(item.get("ranking_reddit")),
        "brecha_abs": _safe_nullable_int(item.get("brecha_abs")),
        "promedio_rank": _safe_nullable_float(item.get("promedio_rank")),
        "direccion": item.get("direccion"),
        "delta_gap": _safe_nullable_int(item.get("delta_gap")),
        "trend_direction": item.get("trend_direction"),
    }


def _build_intersection_summary(latest_items, latest_snapshot):
    if not latest_items:
        return {
            "consenso_count": 0,
            "divergente_count": 0,
            "comparable_count": 0,
            "coverage_pct": 0.0,
            "closest_alignment": None,
            "largest_gap_item": None,
            "max_brecha_tecnologia": None,
            "max_brecha_abs": None,
        }

    consenso_count = sum(1 for item in latest_items if item.get("brecha_abs") == 0)
    divergente_count = sum(
        1 for item in latest_items if isinstance(item.get("brecha_abs"), int) and item.get("brecha_abs", 0) > 0
    )
    comparable = [item for item in latest_items if isinstance(item.get("brecha_abs"), int)]
    max_gap_item = max(
        comparable,
        key=lambda item: (item.get("brecha_abs", -1), item.get("tecnologia", "")),
        default=None,
    )
    closest_alignment = min(
        comparable,
        key=lambda item: (
            _safe_int(item.get("brecha_abs"), default=9999),
            _safe_float(item.get("promedio_rank"), default=9999.0),
            item.get("tecnologia", ""),
        ),
        default=None,
    )

    return {
        "consenso_count": consenso_count,
        "divergente_count": divergente_count,
        "comparable_count": latest_snapshot.get("comparable_count", len(comparable)) if latest_snapshot else len(comparable),
        "coverage_pct": latest_snapshot.get("coverage_pct", 0.0) if latest_snapshot else 0.0,
        "closest_alignment": _summarize_intersection_item(closest_alignment),
        "largest_gap_item": _summarize_intersection_item(max_gap_item),
        "max_brecha_tecnologia": max_gap_item.get("tecnologia") if max_gap_item else None,
        "max_brecha_abs": max_gap_item.get("brecha_abs") if max_gap_item else None,
    }


def build_reddit_intersection_history(project_root, history_index):
    """Construye payload histórico para intersección GitHub vs Reddit."""
    sources = _resolve_dataset_snapshot_sources(
        project_root,
        history_index,
        ["interseccion", "interseccion_github_reddit"],
    )
    snapshots = []

    for source in sources:
        csv_path = project_root / source["path"]
        try:
            df = pd.read_csv(csv_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            logger.warning("Skipping reddit intersection snapshot %s due to read error: %s", csv_path, exc)
            continue

        snapshots.append(
            _build_reddit_intersection_snapshot_record(
                df,
                date_label=source["date"],
                relative_path=source["path"],
                source_type=source["source_type"],
            )
        )

    source_mode = "missing"
    if snapshots:
        history_count = sum(1 for item in snapshots if item["source_type"] == "history")
        source_mode = "history" if history_count > 0 else "latest"

    latest_snapshot = snapshots[-1] if snapshots else None
    previous_snapshot = snapshots[-2] if len(snapshots) >= 2 else None
    latest_items = (
        _build_latest_intersection_items_with_delta(
            latest_snapshot=latest_snapshot,
            previous_snapshot=previous_snapshot,
        )
        if latest_snapshot is not None
        else []
    )

    return {
        "generated_at_utc": _utc_now_iso(),
        "dataset": "interseccion_github_reddit",
        "source_mode": source_mode,
        "snapshot_count": len(snapshots),
        "latest_snapshot_date": latest_snapshot["date"] if latest_snapshot else None,
        "previous_snapshot_date": previous_snapshot["date"] if previous_snapshot else None,
        "coverage_pct": latest_snapshot["coverage_pct"] if latest_snapshot else 0.0,
        "comparable_count": latest_snapshot["comparable_count"] if latest_snapshot else 0,
        "item_count": latest_snapshot["row_count"] if latest_snapshot else 0,
        "latest_items": latest_items,
        "summary": _build_intersection_summary(latest_items, latest_snapshot),
        "snapshots": snapshots,
    }

def build_trend_score_history(project_root, history_index):
    """Construye payload de trend_score_history para uso del bridge frontend."""
    snapshots, snapshots_with_df = _collect_trend_snapshot_data(project_root, history_index)

    return {
        "generated_at_utc": _utc_now_iso(),
        "snapshot_count": len(snapshots),
        "snapshots": snapshots,
        "series": _build_trend_series(snapshots_with_df),
    }


def build_technology_profiles(project_root, history_index):
    """Construye bridge canónico para Inicio y Análisis por tecnología."""
    _, snapshots_with_df = _collect_trend_snapshot_data(project_root, history_index)
    return _build_technology_profiles_payload(snapshots_with_df)


def _limit_tail(items, limit):
    if not isinstance(items, list):
        return items
    if limit <= 0 or len(items) <= limit:
        return items
    return items[-limit:]


def _build_compact_frontend_payload(
    payload,
    *,
    snapshot_limit=2,
    point_limit=2,
    preserve_points=False,
):
    """Reduce committed frontend bridge payloads while keeping the schema valid."""
    if isinstance(payload, dict):
        preserve_points = preserve_points or (
            payload.get("dataset") == "so_tendencias_mensuales"
        )
        compact = {}
        for key, value in payload.items():
            if key == "snapshots" and isinstance(value, list):
                compact[key] = [
                    _build_compact_frontend_payload(
                        item,
                        snapshot_limit=snapshot_limit,
                        point_limit=point_limit,
                        preserve_points=preserve_points,
                    )
                    for item in _limit_tail(value, snapshot_limit)
                ]
                continue

            if key in {"points", "source_history"} and isinstance(value, list):
                values = value
                if key != "points" or not preserve_points:
                    values = _limit_tail(value, point_limit)
                compact[key] = [
                    _build_compact_frontend_payload(
                        item,
                        snapshot_limit=snapshot_limit,
                        point_limit=point_limit,
                        preserve_points=preserve_points,
                    )
                    for item in values
                ]
                continue

            if isinstance(value, list):
                compact[key] = [
                    _build_compact_frontend_payload(
                        item,
                        snapshot_limit=snapshot_limit,
                        point_limit=point_limit,
                        preserve_points=preserve_points,
                    )
                    for item in value
                ]
                continue

            compact[key] = _build_compact_frontend_payload(
                value,
                snapshot_limit=snapshot_limit,
                point_limit=point_limit,
                preserve_points=preserve_points,
            )

        if "snapshots" in compact and "snapshot_count" in compact:
            compact["snapshot_count"] = len(compact["snapshots"])
        if "snapshots" in compact and "history_snapshot_count" in compact:
            compact["history_snapshot_count"] = len(compact["snapshots"])
        if "datasets" in compact and "dataset_count" in compact:
            compact["dataset_count"] = len(compact["datasets"])
        if "profiles" in compact and "profile_count" in compact:
            compact["profile_count"] = len(compact["profiles"])
        if "latest_items" in compact and "item_count" in compact:
            compact["item_count"] = len(compact["latest_items"])
        if "latest_topics" in compact and "topic_count" in compact:
            compact["topic_count"] = len(compact["latest_topics"])
        if "highlights" in compact and "highlight_count" in compact:
            compact["highlight_count"] = len(compact["highlights"])
        if (
            compact.get("dataset") == "so_tendencias_mensuales"
            and "snapshot_count" in compact
        ):
            compact["snapshot_count"] = min(
                _safe_int(compact.get("snapshot_count"), default=0),
                snapshot_limit,
            )

        snapshots = compact.get("snapshots")
        if isinstance(snapshots, list):
            latest_snapshot = snapshots[-1] if snapshots else None
            previous_snapshot = snapshots[-2] if len(snapshots) >= 2 else None
            if (
                latest_snapshot is not None
                and isinstance(latest_snapshot, dict)
                and latest_snapshot.get("date")
            ):
                compact["latest_snapshot_date"] = latest_snapshot.get("date")
            if "previous_snapshot_date" in compact:
                compact["previous_snapshot_date"] = (
                    previous_snapshot.get("date")
                    if isinstance(previous_snapshot, dict)
                    else None
                )
            if "has_historical_comparison" in compact:
                compact["has_historical_comparison"] = previous_snapshot is not None

        return compact

    if isinstance(payload, list):
        return [
            _build_compact_frontend_payload(
                item,
                snapshot_limit=snapshot_limit,
                point_limit=point_limit,
                preserve_points=preserve_points,
            )
            for item in payload
        ]

    return payload


def _write_json(path, payload):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")


def export_bridge_assets(project_root, output_dir=None, compact=False):
    """Exporta archivos JSON puente para acceso histórico del frontend."""
    project_root = Path(project_root)
    output_dir = Path(output_dir) if output_dir else project_root / "frontend" / "assets" / "data"
    output_dir.mkdir(parents=True, exist_ok=True)

    history_index_payload = build_history_index(project_root)
    trend_history_payload = build_trend_score_history(project_root, history_index_payload)
    reddit_sentiment_payload = build_reddit_sentiment_public(project_root)
    reddit_topics_history_payload = build_reddit_topics_history(project_root, history_index_payload)
    reddit_intersection_history_payload = build_reddit_intersection_history(project_root, history_index_payload)
    github_languages_public_payload = build_github_languages_public(project_root)
    github_frameworks_history_payload = build_github_frameworks_history(
        project_root,
        history_index_payload,
    )
    github_correlation_history_payload = build_github_correlation_history(
        project_root,
        history_index_payload,
    )
    so_volume_history_payload = build_so_volume_history(
        project_root,
        history_index_payload,
    )
    so_acceptance_history_payload = build_so_acceptance_history(
        project_root,
        history_index_payload,
    )
    so_trends_history_payload = build_so_trends_history(
        project_root,
        history_index_payload,
    )
    technology_profiles_payload = build_technology_profiles(
        project_root,
        history_index_payload,
    )
    home_highlights_payload = build_home_highlights_payload(
        github_languages_payload=github_languages_public_payload,
        github_frameworks_payload=github_frameworks_history_payload,
        github_correlation_payload=github_correlation_history_payload,
        reddit_sentiment_payload=reddit_sentiment_payload,
        reddit_topics_payload=reddit_topics_history_payload,
        reddit_intersection_payload=reddit_intersection_history_payload,
        so_volume_payload=so_volume_history_payload,
        so_acceptance_payload=so_acceptance_history_payload,
        so_trends_payload=so_trends_history_payload,
    )

    if compact:
        history_index_payload = _build_compact_frontend_payload(history_index_payload)
        trend_history_payload = _build_compact_frontend_payload(trend_history_payload)
        reddit_sentiment_payload = _build_compact_frontend_payload(reddit_sentiment_payload)
        reddit_topics_history_payload = _build_compact_frontend_payload(reddit_topics_history_payload)
        reddit_intersection_history_payload = _build_compact_frontend_payload(reddit_intersection_history_payload)
        github_languages_public_payload = _build_compact_frontend_payload(github_languages_public_payload)
        github_frameworks_history_payload = _build_compact_frontend_payload(github_frameworks_history_payload)
        github_correlation_history_payload = _build_compact_frontend_payload(github_correlation_history_payload)
        home_highlights_payload = _build_compact_frontend_payload(home_highlights_payload)
        so_volume_history_payload = _build_compact_frontend_payload(so_volume_history_payload)
        so_acceptance_history_payload = _build_compact_frontend_payload(so_acceptance_history_payload)
        so_trends_history_payload = _build_compact_frontend_payload(so_trends_history_payload)
        technology_profiles_payload = _build_compact_frontend_payload(technology_profiles_payload)

    history_index_path = output_dir / HISTORY_INDEX_FILENAME
    trend_history_path = output_dir / TREND_SCORE_HISTORY_FILENAME
    reddit_sentiment_path = output_dir / REDDIT_SENTIMENT_PUBLIC_FILENAME
    reddit_topics_history_path = output_dir / REDDIT_TOPICS_HISTORY_FILENAME
    reddit_intersection_history_path = output_dir / REDDIT_INTERSECTION_HISTORY_FILENAME
    github_languages_public_path = output_dir / GITHUB_LANGUAGES_PUBLIC_FILENAME
    github_frameworks_history_path = output_dir / GITHUB_FRAMEWORKS_HISTORY_FILENAME
    github_correlation_history_path = output_dir / GITHUB_CORRELATION_HISTORY_FILENAME
    home_highlights_path = output_dir / HOME_HIGHLIGHTS_FILENAME
    so_volume_history_path = output_dir / SO_VOLUME_HISTORY_FILENAME
    so_acceptance_history_path = output_dir / SO_ACCEPTANCE_HISTORY_FILENAME
    so_trends_history_path = output_dir / SO_TRENDS_HISTORY_FILENAME
    technology_profiles_path = output_dir / TECHNOLOGY_PROFILES_FILENAME
    _write_json(history_index_path, history_index_payload)
    _write_json(trend_history_path, trend_history_payload)
    _write_json(reddit_sentiment_path, reddit_sentiment_payload)
    _write_json(reddit_topics_history_path, reddit_topics_history_payload)
    _write_json(reddit_intersection_history_path, reddit_intersection_history_payload)
    _write_json(github_languages_public_path, github_languages_public_payload)
    _write_json(github_frameworks_history_path, github_frameworks_history_payload)
    _write_json(github_correlation_history_path, github_correlation_history_payload)
    _write_json(home_highlights_path, home_highlights_payload)
    _write_json(so_volume_history_path, so_volume_history_payload)
    _write_json(so_acceptance_history_path, so_acceptance_history_payload)
    _write_json(so_trends_history_path, so_trends_history_payload)
    _write_json(technology_profiles_path, technology_profiles_payload)

    summary = {
        "files_written": 13,
        "history_index_path": str(history_index_path),
        "trend_score_history_path": str(trend_history_path),
        "reddit_sentiment_public_path": str(reddit_sentiment_path),
        "reddit_topics_history_path": str(reddit_topics_history_path),
        "reddit_intersection_history_path": str(reddit_intersection_history_path),
        "github_languages_public_path": str(github_languages_public_path),
        "github_frameworks_history_path": str(github_frameworks_history_path),
        "github_correlation_history_path": str(github_correlation_history_path),
        "home_highlights_path": str(home_highlights_path),
        "so_volume_history_path": str(so_volume_history_path),
        "so_acceptance_history_path": str(so_acceptance_history_path),
        "so_trends_history_path": str(so_trends_history_path),
        "technology_profiles_path": str(technology_profiles_path),
        "compact": compact,
        "dataset_count": int(history_index_payload["dataset_count"]),
        "trend_snapshot_count": int(trend_history_payload["snapshot_count"]),
        "reddit_framework_count": int(reddit_sentiment_payload["framework_count"]),
        "reddit_topics_snapshot_count": int(reddit_topics_history_payload["snapshot_count"]),
        "reddit_intersection_snapshot_count": int(reddit_intersection_history_payload["snapshot_count"]),
        "github_language_count": int(github_languages_public_payload["language_count"]),
        "github_frameworks_snapshot_count": int(github_frameworks_history_payload["snapshot_count"]),
        "github_correlation_snapshot_count": int(github_correlation_history_payload["snapshot_count"]),
        "home_highlight_count": int(len(home_highlights_payload["highlights"])),
        "so_volume_snapshot_count": int(so_volume_history_payload["snapshot_count"]),
        "so_acceptance_snapshot_count": int(so_acceptance_history_payload["snapshot_count"]),
        "so_trends_snapshot_count": int(so_trends_history_payload["snapshot_count"]),
        "technology_profile_count": int(technology_profiles_payload["profile_count"]),
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

