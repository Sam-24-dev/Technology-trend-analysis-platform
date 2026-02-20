"""
Data validation utilities for the ETL pipeline.

Provides reusable functions to validate DataFrames before
saving them to CSV: empty checks, column verification,
and null detection.
"""
import logging

from exceptions import ETLValidationError
from config.csv_contract import get_required_columns, get_critical_columns

logger = logging.getLogger("validador")


def validar_dataframe(df, nombre_archivo):
    """Validates a DataFrame before saving.

    Checks:
    1. DataFrame is not empty
    2. Expected columns exist
    3. Critical columns have no nulls

    Args:
        df: The DataFrame to validate.
        nombre_archivo: Key from ARCHIVOS_SALIDA (e.g. 'github_repos').

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

    # 3. Verificar nulos en columnas criticas
    criticas = get_critical_columns(nombre_archivo)
    for col in criticas:
        if col in df.columns:
            nulos = df[col].isnull().sum()
            if nulos > 0:
                logger.warning(
                    "'%s': columna '%s' tiene %d nulos (%.1f%%)",
                    nombre_archivo, col, nulos, nulos / len(df) * 100
                )

    return True
