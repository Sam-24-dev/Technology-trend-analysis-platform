"""Política de degradación de trend score basada en disponibilidad de fuentes."""

from __future__ import annotations

from typing import Mapping


DEFAULT_SOURCE_WEIGHTS = {
    "github": 0.40,
    "stackoverflow": 0.35,
    "reddit": 0.25,
}

_REQUIRED_SOURCES = ("github", "stackoverflow", "reddit")


def _normalize_status(source_status: Mapping[str, bool]) -> dict[str, bool]:
    return {source: bool(source_status.get(source, False)) for source in _REQUIRED_SOURCES}


def _renormalize_weights(default_weights: Mapping[str, float], status: Mapping[str, bool]) -> dict[str, float]:
    active_sources = [source for source, available in status.items() if available]
    if not active_sources:
        return {}

    total = sum(float(default_weights[source]) for source in active_sources)
    if total <= 0:
        return {}

    return {
        source: round(float(default_weights[source]) / total, 6)
        for source in active_sources
    }


def evaluate_degradation_policy(
    source_status: Mapping[str, bool],
    default_weights: Mapping[str, float] | None = None,
) -> dict[str, object]:
    """Evalúa decisión de publicación y pesos según disponibilidad de fuentes."""
    weights = default_weights or DEFAULT_SOURCE_WEIGHTS
    status = _normalize_status(source_status)

    available_sources = [source for source, available in status.items() if available]
    missing_sources = [source for source, available in status.items() if not available]
    available_count = len(available_sources)

    if available_count == 3:
        return {
            "available_count": 3,
            "available_sources": available_sources,
            "missing_sources": missing_sources,
            "publish_allowed": True,
            "quality_gate_status": "pass",
            "weights_mode": "default",
            "effective_weights": dict(weights),
            "reason": "all_sources_available",
        }

    if available_count == 2:
        return {
            "available_count": 2,
            "available_sources": available_sources,
            "missing_sources": missing_sources,
            "publish_allowed": True,
            "quality_gate_status": "pass_with_warnings",
            "weights_mode": "renormalized",
            "effective_weights": _renormalize_weights(weights, status),
            "reason": "single_source_missing",
        }

    return {
        "available_count": available_count,
        "available_sources": available_sources,
        "missing_sources": missing_sources,
        "publish_allowed": False,
        "quality_gate_status": "fail",
        "weights_mode": "unavailable",
        "effective_weights": {},
        "reason": "insufficient_sources",
    }
