"""
Data validation utilities for the ETL pipeline.

Provides reusable functions to validate DataFrames before
saving them to CSV: empty checks, column verification,
and null detection.
"""
import logging

from exceptions import ETLValidationError

logger = logging.getLogger("validador")


# Columnas esperadas por cada CSV de salida
COLUMNAS_ESPERADAS = {
    "github_repos": ["repo_name", "language", "stars", "forks", "created_at"],
    "github_lenguajes": ["lenguaje", "repos_count", "porcentaje"],
    "github_ai_insights": [
        "total_repos_analizados",
        "repos_ai_detectados",
        "porcentaje_ai",
        "mes_pico_ai",
        "repos_mes_pico_ai",
        "top_keywords_ai",
        "top_repos_ai",
    ],
    "github_commits": ["framework", "repo", "commits_2025", "ranking"],
    "github_correlacion": ["repo_name", "stars", "contributors", "language"],
    "so_volumen": ["lenguaje", "preguntas_nuevas_2025"],
    "so_aceptacion": ["tecnologia", "total_preguntas", "respuestas_aceptadas", "tasa_aceptacion_pct"],
    "so_tendencias": ["mes", "python", "javascript", "typescript"],
    "reddit_sentimiento": ["framework", "total_menciones", "positivos", "neutros", "negativos"],
    "reddit_temas": ["tema", "menciones"],
    "interseccion": ["tecnologia", "tipo", "ranking_github", "ranking_reddit"],
}

# Columnas que no deben tener nulos
COLUMNAS_CRITICAS = {
    "github_repos": ["repo_name", "language", "stars"],
    "github_lenguajes": ["lenguaje", "repos_count"],
    "github_ai_insights": ["total_repos_analizados", "repos_ai_detectados", "porcentaje_ai"],
    "github_commits": ["framework", "commits_2025"],
    "github_correlacion": ["repo_name", "stars"],
    "so_volumen": ["lenguaje"],
    "so_aceptacion": ["tecnologia"],
    "so_tendencias": ["mes"],
    "reddit_sentimiento": ["framework", "total_menciones"],
    "reddit_temas": ["tema", "menciones"],
    "interseccion": ["tecnologia", "ranking_github"],
}


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
    esperadas = COLUMNAS_ESPERADAS.get(nombre_archivo, [])
    if esperadas:
        faltantes = [col for col in esperadas if col not in df.columns]
        if faltantes:
            logger.warning("Columnas faltantes en '%s': %s", nombre_archivo, faltantes)

    # 3. Verificar nulos en columnas criticas
    criticas = COLUMNAS_CRITICAS.get(nombre_archivo, [])
    for col in criticas:
        if col in df.columns:
            nulos = df[col].isnull().sum()
            if nulos > 0:
                logger.warning(
                    "'%s': columna '%s' tiene %d nulos (%.1f%%)",
                    nombre_archivo, col, nulos, nulos / len(df) * 100
                )

    return True
