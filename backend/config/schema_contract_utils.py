"""Utilidades del contrato de schema para hashing determinístico y política de versionado."""

from __future__ import annotations

import hashlib
import json
from typing import Any, Iterable, Mapping


SEMVER_MAJOR = "major"
SEMVER_MINOR = "minor"
SEMVER_PATCH = "patch"
VALID_BUMP_LEVELS = (SEMVER_MAJOR, SEMVER_MINOR, SEMVER_PATCH)

_CHANGE_TO_BUMP = {
    "remove_required_column": SEMVER_MAJOR,
    "rename_required_column": SEMVER_MAJOR,
    "change_type_incompatible": SEMVER_MAJOR,
    "tighten_nullability": SEMVER_MAJOR,
    "drop_dataset": SEMVER_MAJOR,
    "change_partition_key_breaking": SEMVER_MAJOR,
    "add_optional_column": SEMVER_MINOR,
    "add_required_column_with_default": SEMVER_MINOR,
    "add_non_breaking_quality_rule": SEMVER_MINOR,
    "add_partition_field_backward_compatible": SEMVER_MINOR,
    "add_optional_dataset_metadata": SEMVER_MINOR,
    "fix_quality_rule_bug": SEMVER_PATCH,
    "relax_warning_threshold": SEMVER_PATCH,
    "metadata_only_change": SEMVER_PATCH,
    "reorder_columns_only": SEMVER_PATCH,
    "backfill_without_schema_change": SEMVER_PATCH,
}

_BUMP_PRIORITY = {
    SEMVER_MAJOR: 3,
    SEMVER_MINOR: 2,
    SEMVER_PATCH: 1,
}


def _canonical_type_name(raw_type: Any) -> str:
    text = str(raw_type or "").strip().lower()
    aliases = {
        "int": "integer",
        "int32": "integer",
        "int64": "integer",
        "long": "integer",
        "float": "number",
        "float32": "number",
        "float64": "number",
        "double": "number",
        "str": "string",
        "string": "string",
        "bool": "boolean",
        "boolean": "boolean",
        "datetime64[ns]": "datetime",
        "timestamp": "datetime",
    }
    return aliases.get(text, text)


def canonicalize_schema_columns(columns: Iterable[Mapping[str, Any]]) -> list[dict[str, Any]]:
    """Retorna una representación canónica determinística del schema."""
    normalized: list[dict[str, Any]] = []

    for column in columns:
        name = str(column.get("name", "")).strip()
        if not name:
            continue

        nullable_value = column.get("nullable", True)
        nullable = bool(nullable_value)
        normalized.append(
            {
                "name": name.lower(),
                "type": _canonical_type_name(column.get("type")),
                "nullable": nullable,
            }
        )

    normalized.sort(key=lambda item: item["name"])
    return normalized


def compute_schema_hash(columns: Iterable[Mapping[str, Any]]) -> str:
    """Calcula hash SHA-256 determinístico para un schema canonizado."""
    canonical = canonicalize_schema_columns(columns)
    payload = json.dumps(canonical, sort_keys=True, separators=(",", ":"), ensure_ascii=True)
    return hashlib.sha256(payload.encode("utf-8")).hexdigest()


def recommend_semver_bump(change_kind: str) -> str:
    """Mapea un tipo de cambio de schema/data-contract al nivel de bump SemVer."""
    normalized = str(change_kind or "").strip().lower()
    if normalized not in _CHANGE_TO_BUMP:
        raise ValueError(f"Unknown change kind: {change_kind}")
    return _CHANGE_TO_BUMP[normalized]


def aggregate_semver_bump(change_kinds: Iterable[str]) -> str:
    """Retorna el bump de mayor prioridad requerido por una lista de cambios."""
    selected_level = SEMVER_PATCH
    selected_priority = _BUMP_PRIORITY[selected_level]

    for change_kind in change_kinds:
        level = recommend_semver_bump(change_kind)
        priority = _BUMP_PRIORITY[level]
        if priority > selected_priority:
            selected_level = level
            selected_priority = priority

    return selected_level
