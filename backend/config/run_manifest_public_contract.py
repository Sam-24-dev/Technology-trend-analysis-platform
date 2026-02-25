"""Contract and generation utilities for frontend public run manifest."""

from __future__ import annotations

import csv
import json
import re
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Mapping

from config.data_product_contract import is_valid_iso_utc
from quality.degradation_policy import evaluate_degradation_policy


RUN_MANIFEST_PUBLIC_VERSION = "1.0.0"
RUN_MANIFEST_PUBLIC_FILE_NAME = "run_manifest.json"

QUALITY_GATE_STATUSES = {"pass", "pass_with_warnings", "fail"}
DATASET_QUALITY_STATUSES = {"pass", "warning", "fail"}
AVAILABLE_SOURCES = ("github", "stackoverflow", "reddit")

RUN_MANIFEST_PUBLIC_REQUIRED_FIELDS = (
    "manifest_version",
    "generated_at_utc",
    "source_window_start_utc",
    "source_window_end_utc",
    "quality_gate_status",
    "degraded_mode",
    "available_sources",
    "dataset_summaries",
)

RUN_MANIFEST_PUBLIC_ALLOWED_FIELDS = RUN_MANIFEST_PUBLIC_REQUIRED_FIELDS + ("notes",)
RUN_MANIFEST_PUBLIC_DATASET_REQUIRED_FIELDS = (
    "dataset",
    "row_count",
    "quality_status",
    "updated_at_utc",
)
RUN_MANIFEST_PUBLIC_DATASET_ALLOWED_FIELDS = RUN_MANIFEST_PUBLIC_DATASET_REQUIRED_FIELDS

_SEMVER_RE = re.compile(r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$")


def _is_non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def _to_iso_utc_from_mtime(path: Path) -> str:
    return datetime.fromtimestamp(path.stat().st_mtime, tz=timezone.utc).replace(microsecond=0).isoformat().replace(
        "+00:00", "Z"
    )


def _coerce_int(value: Any, default: int = 0) -> int:
    if isinstance(value, bool):
        return default
    if isinstance(value, int):
        return value
    try:
        return int(value)
    except (TypeError, ValueError):
        return default


def _count_csv_rows(path: Path) -> int:
    try:
        with path.open("r", encoding="utf-8", newline="") as handle:
            reader = csv.reader(handle)
            next(reader, None)  # header
            return sum(1 for _ in reader)
    except Exception:  # pylint: disable=broad-exception-caught
        return 0


def _dataset_to_source(dataset_name: str) -> str | None:
    normalized = dataset_name.strip().lower()

    if normalized.startswith("github_"):
        return "github"
    if normalized.startswith("so_") or normalized.startswith("stackoverflow_"):
        return "stackoverflow"
    if normalized.startswith("reddit_"):
        return "reddit"
    if normalized.startswith("interseccion_github_reddit"):
        return None
    if normalized == "trend_score":
        return None
    return None


def _available_sources_from_dataset_names(dataset_names: list[str]) -> list[str]:
    detected = {_dataset_to_source(name) for name in dataset_names}
    return [source for source in AVAILABLE_SOURCES if source in detected]


def _read_json(path: Path) -> Mapping[str, Any] | None:
    if not path.exists():
        return None
    try:
        payload = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return None
    if isinstance(payload, Mapping):
        return payload
    return None


def load_public_manifest_schema(project_root: Path | None = None) -> dict[str, Any]:
    """Loads run_manifest public JSON schema."""
    root = Path(project_root) if project_root else Path(__file__).resolve().parents[2]
    schema_path = root / "backend" / "config" / "run_manifest_public_schema.json"
    return json.loads(schema_path.read_text(encoding="utf-8"))


def validate_public_run_manifest(run_manifest_public: Mapping[str, Any]) -> tuple[bool, list[str]]:
    """Validates public run manifest payload used by frontend."""
    errors: list[str] = []

    if not isinstance(run_manifest_public, Mapping):
        return False, ["run manifest publico debe ser un objeto (dict/mapping)"]

    for field in RUN_MANIFEST_PUBLIC_REQUIRED_FIELDS:
        if field not in run_manifest_public:
            errors.append(f"falta campo requerido '{field}'")

    for field in run_manifest_public.keys():
        if field not in RUN_MANIFEST_PUBLIC_ALLOWED_FIELDS:
            errors.append(f"campo no permitido '{field}'")

    manifest_version = run_manifest_public.get("manifest_version")
    if "manifest_version" in run_manifest_public:
        if not _is_non_empty_string(manifest_version) or _SEMVER_RE.fullmatch(manifest_version.strip()) is None:
            errors.append("'manifest_version' no cumple SemVer x.y.z")

    for field in ("generated_at_utc", "source_window_start_utc", "source_window_end_utc"):
        value = run_manifest_public.get(field)
        if field in run_manifest_public and not is_valid_iso_utc(value):
            errors.append(f"'{field}' no es ISO-8601 valido con zona horaria")

    quality_gate_status = run_manifest_public.get("quality_gate_status")
    if "quality_gate_status" in run_manifest_public and quality_gate_status not in QUALITY_GATE_STATUSES:
        errors.append(f"'quality_gate_status' invalido: {quality_gate_status}")

    degraded_mode = run_manifest_public.get("degraded_mode")
    if "degraded_mode" in run_manifest_public and not isinstance(degraded_mode, bool):
        errors.append("'degraded_mode' debe ser boolean")

    available_sources = run_manifest_public.get("available_sources")
    if "available_sources" in run_manifest_public:
        if not isinstance(available_sources, list):
            errors.append("'available_sources' debe ser lista")
        else:
            if len(available_sources) > len(AVAILABLE_SOURCES):
                errors.append("'available_sources' excede maximo permitido")
            if len(set(available_sources)) != len(available_sources):
                errors.append("'available_sources' no permite duplicados")
            for source in available_sources:
                if source not in AVAILABLE_SOURCES:
                    errors.append(f"'available_sources' contiene valor invalido: {source}")

    dataset_summaries = run_manifest_public.get("dataset_summaries")
    if "dataset_summaries" in run_manifest_public:
        if not isinstance(dataset_summaries, list):
            errors.append("'dataset_summaries' debe ser lista")
        elif not dataset_summaries:
            errors.append("'dataset_summaries' no puede estar vacio")
        else:
            for index, dataset_summary in enumerate(dataset_summaries):
                if not isinstance(dataset_summary, Mapping):
                    errors.append(f"dataset_summaries[{index}] debe ser objeto")
                    continue

                for field in RUN_MANIFEST_PUBLIC_DATASET_REQUIRED_FIELDS:
                    if field not in dataset_summary:
                        errors.append(f"dataset_summaries[{index}] falta campo requerido '{field}'")
                for field in dataset_summary.keys():
                    if field not in RUN_MANIFEST_PUBLIC_DATASET_ALLOWED_FIELDS:
                        errors.append(f"dataset_summaries[{index}] campo no permitido '{field}'")

                dataset_name = dataset_summary.get("dataset")
                if "dataset" in dataset_summary and not _is_non_empty_string(dataset_name):
                    errors.append(f"dataset_summaries[{index}] 'dataset' debe ser string no vacio")

                row_count = dataset_summary.get("row_count")
                if "row_count" in dataset_summary:
                    if not isinstance(row_count, int) or isinstance(row_count, bool):
                        errors.append(f"dataset_summaries[{index}] 'row_count' debe ser integer")
                    elif row_count < 0:
                        errors.append(f"dataset_summaries[{index}] 'row_count' no puede ser negativo")

                quality_status = dataset_summary.get("quality_status")
                if "quality_status" in dataset_summary and quality_status not in DATASET_QUALITY_STATUSES:
                    errors.append(f"dataset_summaries[{index}] 'quality_status' invalido: {quality_status}")

                updated_at_utc = dataset_summary.get("updated_at_utc")
                if "updated_at_utc" in dataset_summary and not is_valid_iso_utc(updated_at_utc):
                    errors.append(
                        f"dataset_summaries[{index}] 'updated_at_utc' no es ISO-8601 valido con zona horaria"
                    )

    notes = run_manifest_public.get("notes")
    if "notes" in run_manifest_public and notes is not None and not isinstance(notes, str):
        errors.append("'notes' debe ser string o null")

    return len(errors) == 0, errors


def _normalize_dataset_quality_status(value: Any, row_count: int) -> str:
    if value in DATASET_QUALITY_STATUSES:
        return str(value)
    if row_count <= 0:
        return "warning"
    return "pass"


def _build_dataset_summaries_from_internal(
    datasets: list[Mapping[str, Any]],
    default_updated_at_utc: str,
) -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    for dataset in datasets:
        dataset_name = str(dataset.get("dataset_logical_name") or "").strip()
        if not dataset_name:
            latest_path = str(dataset.get("latest_path") or "").strip()
            dataset_name = Path(latest_path).stem if latest_path else "unknown_dataset"

        row_count = _coerce_int(dataset.get("row_count"), default=0)
        quality_status = _normalize_dataset_quality_status(dataset.get("quality_status"), row_count)
        updated_at_utc = dataset.get("generated_at_utc")
        if not is_valid_iso_utc(updated_at_utc):
            updated_at_utc = default_updated_at_utc

        summaries.append(
            {
                "dataset": dataset_name,
                "row_count": row_count,
                "quality_status": quality_status,
                "updated_at_utc": str(updated_at_utc),
            }
        )

    return sorted(summaries, key=lambda item: item["dataset"])


def _build_dataset_summaries_from_filesystem(dataset_paths: list[Path]) -> list[dict[str, Any]]:
    summaries: list[dict[str, Any]] = []
    for csv_path in sorted(dataset_paths, key=lambda path: path.name):
        row_count = _count_csv_rows(csv_path)
        summaries.append(
            {
                "dataset": csv_path.stem,
                "row_count": row_count,
                "quality_status": "pass" if row_count > 0 else "warning",
                "updated_at_utc": _to_iso_utc_from_mtime(csv_path),
            }
        )
    return summaries


def _resolve_latest_dataset_paths(project_root: Path) -> list[Path]:
    latest_dir = project_root / "datos" / "latest"
    legacy_dir = project_root / "datos"

    paths_by_name: dict[str, Path] = {}
    if legacy_dir.exists():
        for csv_path in legacy_dir.glob("*.csv"):
            paths_by_name[csv_path.name] = csv_path
    if latest_dir.exists():
        for csv_path in latest_dir.glob("*.csv"):
            paths_by_name[csv_path.name] = csv_path

    return sorted(paths_by_name.values(), key=lambda path: path.name)


def build_public_run_manifest_from_internal(
    internal_manifest: Mapping[str, Any],
    *,
    default_window_start_utc: str,
    default_window_end_utc: str,
) -> dict[str, Any]:
    """Builds frontend public run manifest from internal run manifest."""
    generated_at_utc = internal_manifest.get("generated_at_utc")
    if not is_valid_iso_utc(generated_at_utc):
        generated_at_utc = _utc_now_iso()

    datasets_raw = internal_manifest.get("datasets")
    datasets: list[Mapping[str, Any]] = [item for item in datasets_raw if isinstance(item, Mapping)] if isinstance(
        datasets_raw, list
    ) else []

    dataset_summaries = _build_dataset_summaries_from_internal(datasets, generated_at_utc)
    dataset_names = [item["dataset"] for item in dataset_summaries]
    available_sources = _available_sources_from_dataset_names(dataset_names)
    source_status = {source: source in available_sources for source in AVAILABLE_SOURCES}
    degradation = evaluate_degradation_policy(source_status)

    quality_gate_status = internal_manifest.get("quality_gate_status")
    if quality_gate_status not in QUALITY_GATE_STATUSES:
        quality_gate_status = degradation["quality_gate_status"]

    source_window_start_utc = internal_manifest.get("source_window_start_utc")
    source_window_end_utc = internal_manifest.get("source_window_end_utc")
    if not is_valid_iso_utc(source_window_start_utc):
        source_window_start_utc = default_window_start_utc
    if not is_valid_iso_utc(source_window_end_utc):
        source_window_end_utc = default_window_end_utc

    notes = None
    if degradation["available_count"] < len(AVAILABLE_SOURCES):
        missing_sources = degradation.get("missing_sources", [])
        missing_label = ", ".join(str(source) for source in missing_sources) if missing_sources else "unknown"
        notes = f"Sources unavailable in this run: {missing_label}"

    return {
        "manifest_version": RUN_MANIFEST_PUBLIC_VERSION,
        "generated_at_utc": str(generated_at_utc),
        "source_window_start_utc": str(source_window_start_utc),
        "source_window_end_utc": str(source_window_end_utc),
        "quality_gate_status": str(quality_gate_status),
        "degraded_mode": bool(degradation["available_count"] < len(AVAILABLE_SOURCES)),
        "available_sources": available_sources,
        "dataset_summaries": dataset_summaries,
        "notes": notes,
    }


def build_public_run_manifest_from_filesystem(project_root: Path) -> dict[str, Any]:
    """Builds frontend public run manifest from generated CSV outputs."""
    dataset_paths = _resolve_latest_dataset_paths(project_root)
    dataset_summaries = _build_dataset_summaries_from_filesystem(dataset_paths)
    dataset_names = [item["dataset"] for item in dataset_summaries]
    available_sources = _available_sources_from_dataset_names(dataset_names)
    source_status = {source: source in available_sources for source in AVAILABLE_SOURCES}
    degradation = evaluate_degradation_policy(source_status)

    generated_at_utc = _utc_now_iso()
    source_window_end_utc = generated_at_utc
    source_window_start_utc = (
        datetime.now(timezone.utc).replace(microsecond=0) - timedelta(days=365)
    ).isoformat().replace("+00:00", "Z")

    notes = "Public manifest generated from filesystem fallback."
    if degradation["available_count"] < len(AVAILABLE_SOURCES):
        missing_sources = degradation.get("missing_sources", [])
        missing_label = ", ".join(str(source) for source in missing_sources) if missing_sources else "unknown"
        notes = f"Sources unavailable in this run: {missing_label}"

    return {
        "manifest_version": RUN_MANIFEST_PUBLIC_VERSION,
        "generated_at_utc": generated_at_utc,
        "source_window_start_utc": source_window_start_utc,
        "source_window_end_utc": source_window_end_utc,
        "quality_gate_status": str(degradation["quality_gate_status"]),
        "degraded_mode": bool(degradation["available_count"] < len(AVAILABLE_SOURCES)),
        "available_sources": available_sources,
        "dataset_summaries": dataset_summaries,
        "notes": notes,
    }


def generate_public_run_manifest(project_root: Path | str) -> dict[str, Any]:
    """Generates public run manifest payload and metadata."""
    root = Path(project_root)
    internal_manifest_path = root / "datos" / "metadata" / "run_manifest.json"
    internal_manifest = _read_json(internal_manifest_path)

    now_iso = _utc_now_iso()
    one_year_before = (
        datetime.now(timezone.utc).replace(microsecond=0) - timedelta(days=365)
    ).isoformat().replace("+00:00", "Z")

    if internal_manifest is not None:
        internal_payload = build_public_run_manifest_from_internal(
            internal_manifest,
            default_window_start_utc=one_year_before,
            default_window_end_utc=now_iso,
        )
        internal_valid, internal_errors = validate_public_run_manifest(internal_payload)
        if internal_valid:
            return {
                "valid": True,
                "errors": [],
                "payload": internal_payload,
                "source_mode": "internal_manifest",
            }

        fallback_payload = build_public_run_manifest_from_filesystem(root)
        fallback_valid, fallback_errors = validate_public_run_manifest(fallback_payload)
        if fallback_valid:
            return {
                "valid": True,
                "errors": [],
                "payload": fallback_payload,
                "source_mode": "filesystem_fallback_after_internal_invalid",
            }

        return {
            "valid": False,
            "errors": [
                "internal_manifest_invalid: " + "; ".join(internal_errors),
                "filesystem_fallback_invalid: " + "; ".join(fallback_errors),
            ],
            "payload": fallback_payload,
            "source_mode": "filesystem_fallback_after_internal_invalid",
        }

    payload = build_public_run_manifest_from_filesystem(root)
    is_valid, errors = validate_public_run_manifest(payload)
    return {
        "valid": is_valid,
        "errors": errors,
        "payload": payload,
        "source_mode": "filesystem_fallback",
    }


def write_public_run_manifest(project_root: Path | str, payload: Mapping[str, Any]) -> Path:
    """Writes public run manifest to frontend assets path."""
    root = Path(project_root)
    output_path = root / "frontend" / "assets" / "data" / RUN_MANIFEST_PUBLIC_FILE_NAME
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(payload, indent=2, ensure_ascii=False), encoding="utf-8")
    return output_path
