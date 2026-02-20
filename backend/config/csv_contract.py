"""
Contrato de esquemas CSV compartido entre backend y frontend.

Este módulo define las columnas requeridas/criticas para cada salida
del pipeline ETL. Centralizar este contrato reduce acoplamiento implícito
y hace explícitas las dependencias de datos entre módulos.
"""

CONTRACT_VERSION = "2026.02"

CSV_SCHEMA_CONTRACT = {
    "github_repos": {
        "required_columns": ["repo_name", "language", "stars", "forks", "created_at"],
        "critical_columns": ["repo_name", "language", "stars"],
    },
    "github_lenguajes": {
        "required_columns": ["lenguaje", "repos_count", "porcentaje"],
        "critical_columns": ["lenguaje", "repos_count"],
    },
    "github_ai_insights": {
        "required_columns": [
            "total_repos_analizados",
            "repos_ai_detectados",
            "porcentaje_ai",
            "mes_pico_ai",
            "repos_mes_pico_ai",
            "top_keywords_ai",
            "top_repos_ai",
        ],
        "critical_columns": ["total_repos_analizados", "repos_ai_detectados", "porcentaje_ai"],
    },
    "github_commits": {
        "required_columns": ["framework", "repo", "commits_2025", "ranking"],
        "critical_columns": ["framework", "commits_2025"],
    },
    "github_correlacion": {
        "required_columns": ["repo_name", "stars", "contributors", "language"],
        "critical_columns": ["repo_name", "stars"],
    },
    "so_volumen": {
        "required_columns": ["lenguaje", "preguntas_nuevas_2025"],
        "critical_columns": ["lenguaje"],
    },
    "so_aceptacion": {
        "required_columns": ["tecnologia", "total_preguntas", "respuestas_aceptadas", "tasa_aceptacion_pct"],
        "critical_columns": ["tecnologia"],
    },
    "so_tendencias": {
        "required_columns": ["mes", "python", "javascript", "typescript"],
        "critical_columns": ["mes"],
    },
    "reddit_sentimiento": {
        "required_columns": ["framework", "total_menciones", "positivos", "neutros", "negativos"],
        "critical_columns": ["framework", "total_menciones"],
        "optional_columns": ["% positivo", "% neutro", "% negativo"],
    },
    "reddit_temas": {
        "required_columns": ["tema", "menciones"],
        "critical_columns": ["tema", "menciones"],
    },
    "interseccion": {
        "required_columns": ["tecnologia", "tipo", "ranking_github", "ranking_reddit"],
        "critical_columns": ["tecnologia", "ranking_github"],
    },
    "trend_score": {
        "required_columns": [
            "ranking",
            "tecnologia",
            "github_score",
            "so_score",
            "reddit_score",
            "trend_score",
            "fuentes",
        ],
        "critical_columns": ["ranking", "tecnologia", "trend_score"],
    },
}


def get_required_columns(nombre_archivo):
    """Retorna las columnas requeridas para un archivo lógico de salida."""
    return CSV_SCHEMA_CONTRACT.get(nombre_archivo, {}).get("required_columns", [])


def get_critical_columns(nombre_archivo):
    """Retorna las columnas críticas para un archivo lógico de salida."""
    return CSV_SCHEMA_CONTRACT.get(nombre_archivo, {}).get("critical_columns", [])


def get_optional_columns(nombre_archivo):
    """Retorna columnas opcionales para un archivo lógico de salida."""
    return CSV_SCHEMA_CONTRACT.get(nombre_archivo, {}).get("optional_columns", [])


def get_contract_version():
    """Retorna la versión vigente del contrato de datos CSV."""
    return CONTRACT_VERSION
