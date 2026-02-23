"""Pandera quality checks with severity routing.

This module defines dataset-level Pandera schemas and complementary
quality rules with explicit severities:
- critical: candidate to block publication in strict mode
- warning: publish allowed with quality flag
- info: observability only
"""

from __future__ import annotations

from typing import Any

import pandas as pd

SEVERITY_CRITICAL = "critical"
SEVERITY_WARNING = "warning"
SEVERITY_INFO = "info"
VALID_SEVERITIES = {SEVERITY_CRITICAL, SEVERITY_WARNING, SEVERITY_INFO}

try:
    import pandera as pa
    from pandera import Check
    from pandera.errors import SchemaError, SchemaErrors

    PANDERA_AVAILABLE = True
except Exception:  # pylint: disable=broad-exception-caught
    pa = None
    Check = None
    SchemaError = Exception
    SchemaErrors = Exception
    PANDERA_AVAILABLE = False


def _make_issue(dataset: str, severity: str, rule: str, message: str) -> dict[str, str]:
    safe_severity = severity if severity in VALID_SEVERITIES else SEVERITY_INFO
    return {
        "dataset": dataset,
        "severity": safe_severity,
        "rule": rule,
        "message": message,
    }


def _build_schema_registry() -> dict[str, Any]:
    if not PANDERA_AVAILABLE:
        return {}

    return {
        "trend_score": pa.DataFrameSchema(
            {
                "ranking": pa.Column(
                    pa.Int64,
                    nullable=False,
                    checks=[
                        Check(lambda series: (series >= 1).all(), error="ranking_must_be_positive"),
                        Check(lambda series: series.is_unique, error="ranking_must_be_unique"),
                    ],
                ),
                "tecnologia": pa.Column(pa.String, nullable=False),
                "trend_score": pa.Column(
                    pa.Float64,
                    nullable=False,
                    checks=[Check(lambda series: (series >= 0).all(), error="trend_score_non_negative")],
                ),
                "fuentes": pa.Column(
                    pa.Int64,
                    nullable=False,
                    checks=[
                        Check(
                            lambda series: ((series >= 0) & (series <= 3)).all(),
                            error="fuentes_must_be_in_range_0_3",
                        )
                    ],
                ),
            },
            strict=False,
            coerce=False,
        ),
        "so_volumen": pa.DataFrameSchema(
            {
                "lenguaje": pa.Column(pa.String, nullable=False),
                "preguntas_nuevas_2025": pa.Column(
                    pa.Int64,
                    nullable=False,
                    checks=[Check(lambda series: (series >= 0).all(), error="yearly_volume_non_negative")],
                ),
            },
            strict=False,
            coerce=False,
        ),
    }


PANDERA_SCHEMAS = _build_schema_registry()


def _parse_schema_errors(dataset: str, exc: Exception) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []
    failure_cases = getattr(exc, "failure_cases", None)

    if isinstance(failure_cases, pd.DataFrame) and not failure_cases.empty:
        for _, row in failure_cases.iterrows():
            column = row.get("column", "<unknown_column>")
            check = row.get("check", "schema_validation")
            failure_case = row.get("failure_case", "<unknown_failure_case>")
            message = f"column={column} check={check} failure={failure_case}"
            issues.append(
                _make_issue(
                    dataset=dataset,
                    severity=SEVERITY_CRITICAL,
                    rule="pandera_schema",
                    message=message,
                )
            )
        return issues

    issues.append(
        _make_issue(
            dataset=dataset,
            severity=SEVERITY_CRITICAL,
            rule="pandera_schema",
            message=str(exc),
        )
    )
    return issues


def _run_warning_checks(df: pd.DataFrame, logical_name: str) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []

    if logical_name == "trend_score" and "tecnologia" in df.columns:
        if df["tecnologia"].nunique(dropna=True) < 10:
            issues.append(
                _make_issue(
                    dataset=logical_name,
                    severity=SEVERITY_WARNING,
                    rule="low_technology_coverage",
                    message="fewer than 10 unique technologies in trend score output",
                )
            )

    if logical_name == "trend_score" and "fuentes" in df.columns:
        numeric_fuentes = pd.to_numeric(df["fuentes"], errors="coerce").fillna(0)
        zero_source_count = int((numeric_fuentes == 0).sum())
        if zero_source_count > 0:
            issues.append(
                _make_issue(
                    dataset=logical_name,
                    severity=SEVERITY_WARNING,
                    rule="zero_source_rows",
                    message=f"{zero_source_count} rows have fuentes=0",
                )
            )

    if logical_name == "so_volumen" and "preguntas_nuevas_2025" in df.columns:
        numeric = pd.to_numeric(df["preguntas_nuevas_2025"], errors="coerce").fillna(0)
        if not numeric.empty and (numeric == 0).all():
            issues.append(
                _make_issue(
                    dataset=logical_name,
                    severity=SEVERITY_WARNING,
                    rule="all_zero_volume",
                    message="all StackOverflow yearly volumes are zero",
                )
            )

    return issues


def _run_info_checks(df: pd.DataFrame, logical_name: str) -> list[dict[str, str]]:
    issues: list[dict[str, str]] = []

    duplicate_rows = int(df.duplicated().sum())
    if duplicate_rows > 0:
        issues.append(
            _make_issue(
                dataset=logical_name,
                severity=SEVERITY_INFO,
                rule="duplicate_rows_detected",
                message=f"{duplicate_rows} duplicated rows detected",
            )
        )

    return issues


def run_pandera_quality_checks(df: pd.DataFrame, logical_name: str) -> list[dict[str, str]]:
    """Runs Pandera schema validation and severity checks for one dataset."""
    issues: list[dict[str, str]] = []

    if not PANDERA_AVAILABLE:
        issues.append(
            _make_issue(
                dataset=logical_name,
                severity=SEVERITY_INFO,
                rule="pandera_unavailable",
                message="Pandera is not installed; schema checks were skipped",
            )
        )
        issues.extend(_run_info_checks(df, logical_name))
        return issues

    schema = PANDERA_SCHEMAS.get(logical_name)
    if schema is not None:
        try:
            schema.validate(df, lazy=True)
        except SchemaErrors as exc:
            issues.extend(_parse_schema_errors(logical_name, exc))
        except SchemaError as exc:
            issues.extend(_parse_schema_errors(logical_name, exc))

    issues.extend(_run_warning_checks(df, logical_name))
    issues.extend(_run_info_checks(df, logical_name))
    return issues
