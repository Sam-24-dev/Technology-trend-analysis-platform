"""
Data validation utilities for the ETL pipeline.

Provides reusable functions to validate DataFrames before
saving them to CSV: empty checks, column verification,
and null detection.
"""
import logging
import pandas as pd

from exceptions import ETLValidationError
from config.csv_contract import get_required_columns, get_critical_columns, get_column_types

logger = logging.getLogger("validador")


def _is_series_type_valid(series, expected_type):
    """Validates pandas Series against a minimal type contract."""
    non_null = series.dropna()
    if non_null.empty:
        return True

    if expected_type == "string":
        return non_null.map(lambda value: isinstance(value, str)).all()

    if expected_type == "integer":
        numeric = pd.to_numeric(non_null, errors="coerce")
        return numeric.notna().all() and (numeric % 1 == 0).all()

    if expected_type == "number":
        numeric = pd.to_numeric(non_null, errors="coerce")
        return numeric.notna().all()

    if expected_type == "datetime":
        parsed = pd.to_datetime(non_null, errors="coerce")
        return parsed.notna().all()

    if expected_type == "string_or_integer":
        def _ok(value):
            if isinstance(value, str):
                return True
            numeric_value = pd.to_numeric(value, errors="coerce")
            return pd.notna(numeric_value) and float(numeric_value).is_integer()

        return non_null.map(_ok).all()

    return True


def validar_dataframe(df, nombre_archivo, strict=False, validate_types=False):
    """Validates a DataFrame before saving.

    Checks:
    1. DataFrame is not empty
    2. Expected columns exist
    3. Critical columns have no nulls

    Args:
        df: The DataFrame to validate.
        nombre_archivo: Key from ARCHIVOS_SALIDA (e.g. 'github_repos').
        strict: If True, raises ETLValidationError on schema violations.
        validate_types: If True, applies minimal type checks defined in the contract.

    Raises:
        ETLValidationError: If the DataFrame is empty.
    """
    # 1. Verificar que no esta vacio
    if df.empty:
        raise ETLValidationError(f"DataFrame '{nombre_archivo}' esta vacio, no se puede guardar")

    logger.info("Validando '%s': %d filas, %d columnas", nombre_archivo, len(df), len(df.columns))

    # 2. Verificar columnas esperadas
    esperadas = get_required_columns(nombre_archivo)
    if esperadas:
        faltantes = [col for col in esperadas if col not in df.columns]
        if faltantes:
            logger.warning("Columnas faltantes en '%s': %s", nombre_archivo, faltantes)
            if strict:
                raise ETLValidationError(
                    f"'{nombre_archivo}' no cumple schema requerido, faltan columnas: {faltantes}"
                )

    # 3. Verificar nulos en columnas criticas
    criticas = get_critical_columns(nombre_archivo)
    for col in criticas:
        if col not in df.columns:
            logger.warning("'%s': columna critica '%s' no existe", nombre_archivo, col)
            if strict:
                raise ETLValidationError(
                    f"'{nombre_archivo}' no cumple schema critico, falta columna '{col}'"
                )
            continue

        nulos = df[col].isnull().sum()
        if nulos > 0:
            logger.warning(
                "'%s': columna '%s' tiene %d nulos (%.1f%%)",
                nombre_archivo, col, nulos, nulos / len(df) * 100
            )
            if strict:
                raise ETLValidationError(
                    f"'{nombre_archivo}' no cumple schema critico: columna '{col}' con nulos"
                )

    # 4. Verificar tipos mínimos (opcional)
    if validate_types:
        type_map = get_column_types(nombre_archivo)
        for col, expected_type in type_map.items():
            if col not in df.columns:
                continue

            if not _is_series_type_valid(df[col], expected_type):
                logger.warning(
                    "'%s': columna '%s' no cumple tipo esperado '%s'",
                    nombre_archivo,
                    col,
                    expected_type,
                )
                if strict:
                    raise ETLValidationError(
                        f"'{nombre_archivo}' no cumple tipo esperado en '{col}': {expected_type}"
                    )

    return True
