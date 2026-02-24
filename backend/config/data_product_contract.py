"""Data product contract for ETL run manifests.

This module defines the minimal structure and validations for:
1. Run manifest (execution level)
2. Dataset manifest (output level)

It stays separate from the CSV contract to enable storage evolution
(latest/history/metadata) without breaking V1.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from typing import Any, Mapping


DATA_PRODUCT_CONTRACT_VERSION = "1.0.0"

QUALITY_GATE_STATUSES = {"pass", "pass_with_warnings", "fail"}
DATASET_QUALITY_STATUSES = {"pass", "warning", "fail"}

RUN_REQUIRED_FIELDS = (
    "run_id",
    "generated_at_utc",
    "git_sha",
    "branch",
    "source_window_start_utc",
    "source_window_end_utc",
    "quality_gate_status",
    "datasets",
)

DATASET_REQUIRED_FIELDS = (
    "dataset_logical_name",
    "version_semver",
    "generated_at_utc",
    "source_run_id",
    "schema_hash",
    "row_count",
    "quality_status",
    "latest_path",
    "history_path",
)

_SEMVER_RE = re.compile(
    r"^(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)\."
    r"(0|[1-9]\d*)"
    r"(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)
_HEX64_RE = re.compile(r"^[a-fA-F0-9]{64}$")


def _is_non_empty_string(value: Any) -> bool:
    return isinstance(value, str) and bool(value.strip())


def get_data_product_contract_version() -> str:
    """Returns the current data product contract version."""
    return DATA_PRODUCT_CONTRACT_VERSION


def utc_now_iso() -> str:
    """Returns UTC datetime in ISO-8601 format with Z suffix."""
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def is_valid_semver(version: Any) -> bool:
    """Validates semantic versioning (SemVer 2.0.0)."""
    return _is_non_empty_string(version) and _SEMVER_RE.fullmatch(version.strip()) is not None


def is_valid_iso_utc(value: Any) -> bool:
    """Validates ISO-8601 datetime with timezone."""
    if not _is_non_empty_string(value):
        return False

    text = value.strip().replace("Z", "+00:00")
    try:
        parsed = datetime.fromisoformat(text)
    except ValueError:
        return False

    return parsed.tzinfo is not None


def validate_dataset_manifest(dataset_manifest: Mapping[str, Any], expected_run_id: str | None = None) -> list[str]:
    """Validates minimal structure and rules for a dataset manifest.

    Args:
        dataset_manifest: Individual dataset manifest.
        expected_run_id: If provided, validates source_run_id == expected_run_id.

    Returns:
        Error list. An empty list means valid manifest.
    """
    errors: list[str] = []

    if not isinstance(dataset_manifest, Mapping):
        return ["dataset manifest debe ser un objeto (dict/mapping)"]

    for field in DATASET_REQUIRED_FIELDS:
        if field not in dataset_manifest:
            errors.append(f"falta campo requerido '{field}'")

    dataset_name = dataset_manifest.get("dataset_logical_name")
    if "dataset_logical_name" in dataset_manifest and not _is_non_empty_string(dataset_name):
        errors.append("'dataset_logical_name' debe ser string no vacio")

    version_semver = dataset_manifest.get("version_semver")
    if "version_semver" in dataset_manifest and not is_valid_semver(version_semver):
        errors.append("'version_semver' no cumple SemVer")

    generated_at_utc = dataset_manifest.get("generated_at_utc")
    if "generated_at_utc" in dataset_manifest and not is_valid_iso_utc(generated_at_utc):
        errors.append("'generated_at_utc' no es ISO-8601 valido con zona horaria")

    source_run_id = dataset_manifest.get("source_run_id")
    if "source_run_id" in dataset_manifest and not _is_non_empty_string(source_run_id):
        errors.append("'source_run_id' debe ser string no vacio")
    if expected_run_id and source_run_id != expected_run_id:
        errors.append("'source_run_id' no coincide con run_id del manifest principal")

    schema_hash = dataset_manifest.get("schema_hash")
    if "schema_hash" in dataset_manifest:
        if not _is_non_empty_string(schema_hash) or _HEX64_RE.fullmatch(schema_hash.strip()) is None:
            errors.append("'schema_hash' debe ser hash sha256 en hexadecimal (64 chars)")

    row_count = dataset_manifest.get("row_count")
    if "row_count" in dataset_manifest:
        if not isinstance(row_count, int):
            errors.append("'row_count' debe ser integer")
        elif row_count < 0:
            errors.append("'row_count' no puede ser negativo")

    quality_status = dataset_manifest.get("quality_status")
    if "quality_status" in dataset_manifest and quality_status not in DATASET_QUALITY_STATUSES:
        errors.append(f"'quality_status' invalido: {quality_status}")

    latest_path = dataset_manifest.get("latest_path")
    if "latest_path" in dataset_manifest and not _is_non_empty_string(latest_path):
        errors.append("'latest_path' debe ser string no vacio")

    history_path = dataset_manifest.get("history_path")
    if "history_path" in dataset_manifest:
        if quality_status == "fail":
            if history_path is not None and not _is_non_empty_string(history_path):
                errors.append("'history_path' debe ser null o string no vacio cuando quality_status=fail")
        elif not _is_non_empty_string(history_path):
            errors.append("'history_path' debe ser string no vacio")

    return errors


def validate_run_manifest(run_manifest: Mapping[str, Any]) -> tuple[bool, list[str]]:
    """Validates minimal structure and rules for a run manifest."""
    errors: list[str] = []

    if not isinstance(run_manifest, Mapping):
        return False, ["run manifest debe ser un objeto (dict/mapping)"]

    for field in RUN_REQUIRED_FIELDS:
        if field not in run_manifest:
            errors.append(f"falta campo requerido '{field}'")

    run_id = run_manifest.get("run_id")
    if "run_id" in run_manifest and not _is_non_empty_string(run_id):
        errors.append("'run_id' debe ser string no vacio")

    generated_at_utc = run_manifest.get("generated_at_utc")
    if "generated_at_utc" in run_manifest and not is_valid_iso_utc(generated_at_utc):
        errors.append("'generated_at_utc' no es ISO-8601 valido con zona horaria")

    for field in ("source_window_start_utc", "source_window_end_utc"):
        value = run_manifest.get(field)
        if field in run_manifest and not is_valid_iso_utc(value):
            errors.append(f"'{field}' no es ISO-8601 valido con zona horaria")

    quality_gate_status = run_manifest.get("quality_gate_status")
    if "quality_gate_status" in run_manifest and quality_gate_status not in QUALITY_GATE_STATUSES:
        errors.append(f"'quality_gate_status' invalido: {quality_gate_status}")

    for field in ("git_sha", "branch"):
        value = run_manifest.get(field)
        if field in run_manifest and not _is_non_empty_string(value):
            errors.append(f"'{field}' debe ser string no vacio")

    datasets = run_manifest.get("datasets")
    if "datasets" in run_manifest:
        if not isinstance(datasets, list):
            errors.append("'datasets' debe ser lista")
        elif not datasets:
            errors.append("'datasets' no puede estar vacio")
        else:
            for index, dataset_manifest in enumerate(datasets):
                dataset_errors = validate_dataset_manifest(
                    dataset_manifest,
                    expected_run_id=run_id if _is_non_empty_string(run_id) else None,
                )
                errors.extend(f"datasets[{index}]: {message}" for message in dataset_errors)

    return len(errors) == 0, errors


def build_dataset_manifest(
    *,
    dataset_logical_name: str,
    version_semver: str,
    source_run_id: str,
    schema_hash: str,
    row_count: int,
    quality_status: str,
    latest_path: str,
    history_path: str | None,
    generated_at_utc: str | None = None,
) -> dict[str, Any]:
    """Builds a dataset manifest with standard fields."""
    return {
        "dataset_logical_name": dataset_logical_name,
        "version_semver": version_semver,
        "generated_at_utc": generated_at_utc or utc_now_iso(),
        "source_run_id": source_run_id,
        "schema_hash": schema_hash,
        "row_count": row_count,
        "quality_status": quality_status,
        "latest_path": latest_path,
        "history_path": history_path,
    }


def build_run_manifest(
    *,
    run_id: str,
    git_sha: str,
    branch: str,
    source_window_start_utc: str,
    source_window_end_utc: str,
    quality_gate_status: str,
    datasets: list[dict[str, Any]],
    generated_at_utc: str | None = None,
) -> dict[str, Any]:
    """Builds a run manifest with standard fields."""
    return {
        "run_id": run_id,
        "generated_at_utc": generated_at_utc or utc_now_iso(),
        "git_sha": git_sha,
        "branch": branch,
        "source_window_start_utc": source_window_start_utc,
        "source_window_end_utc": source_window_end_utc,
        "quality_gate_status": quality_gate_status,
        "datasets": datasets,
    }
