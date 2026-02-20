"""
Contrato de esquemas CSV compartido entre backend y frontend.

Este módulo define las columnas requeridas/criticas para cada salida
del pipeline ETL. Centralizar este contrato reduce acoplamiento implícito
y hace explícitas las dependencias de datos entre módulos.
"""

CONTRACT_VERSION = "2026.03"

CSV_SCHEMA_CONTRACT = {
    "github_repos": {
        "required_columns": ["repo_name", "language", "stars", "forks", "created_at"],
        "critical_columns": ["repo_name", "language", "stars"],
        "column_types": {
            "repo_name": "string",
            "language": "string",
            "stars": "integer",
            "forks": "integer",
            "created_at": "datetime",
        },
    },
    "github_lenguajes": {
        "required_columns": ["lenguaje", "repos_count", "porcentaje"],
        "critical_columns": ["lenguaje", "repos_count"],
        "column_types": {
            "lenguaje": "string",
            "repos_count": "integer",
            "porcentaje": "number",
        },
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
        "column_types": {
            "total_repos_analizados": "integer",
            "repos_ai_detectados": "integer",
            "porcentaje_ai": "number",
            "mes_pico_ai": "string",
            "repos_mes_pico_ai": "integer",
            "top_keywords_ai": "string",
            "top_repos_ai": "string",
        },
    },
    "github_commits": {
        "required_columns": ["framework", "repo", "commits_2025", "ranking"],
        "critical_columns": ["framework", "commits_2025"],
        "column_types": {
            "framework": "string",
            "repo": "string",
            "commits_2025": "integer",
            "ranking": "integer",
        },
    },
    "github_correlacion": {
        "required_columns": ["repo_name", "stars", "contributors", "language"],
        "critical_columns": ["repo_name", "stars"],
        "column_types": {
            "repo_name": "string",
            "stars": "integer",
            "contributors": "integer",
            "language": "string",
        },
    },
    "so_volumen": {
        "required_columns": ["lenguaje", "preguntas_nuevas_2025"],
        "critical_columns": ["lenguaje"],
        "column_types": {
            "lenguaje": "string",
            "preguntas_nuevas_2025": "integer",
        },
    },
    "so_aceptacion": {
        "required_columns": ["tecnologia", "total_preguntas", "respuestas_aceptadas", "tasa_aceptacion_pct"],
        "critical_columns": ["tecnologia"],
        "column_types": {
            "tecnologia": "string",
            "total_preguntas": "integer",
            "respuestas_aceptadas": "integer",
            "tasa_aceptacion_pct": "number",
        },
    },
    "so_tendencias": {
        "required_columns": ["mes", "python", "javascript", "typescript"],
        "critical_columns": ["mes"],
        "column_types": {
            "mes": "string",
            "python": "integer",
            "javascript": "integer",
            "typescript": "integer",
        },
    },
    "reddit_sentimiento": {
        "required_columns": ["framework", "total_menciones", "positivos", "neutros", "negativos"],
        "critical_columns": ["framework", "total_menciones"],
        "optional_columns": ["% positivo", "% neutro", "% negativo"],
        "column_types": {
            "framework": "string",
            "total_menciones": "integer",
            "positivos": "integer",
            "neutros": "integer",
            "negativos": "integer",
            "% positivo": "number",
            "% neutro": "number",
            "% negativo": "number",
        },
    },
    "reddit_temas": {
        "required_columns": ["tema", "menciones"],
        "critical_columns": ["tema", "menciones"],
        "column_types": {
            "tema": "string",
            "menciones": "integer",
        },
    },
    "interseccion": {
        "required_columns": ["tecnologia", "tipo", "ranking_github", "ranking_reddit"],
        "critical_columns": ["tecnologia", "ranking_github"],
        "column_types": {
            "tecnologia": "string",
            "tipo": "string",
            "ranking_github": "integer",
            "ranking_reddit": "string_or_integer",
        },
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
        "column_types": {
            "ranking": "integer",
            "tecnologia": "string",
            "github_score": "number",
            "so_score": "number",
            "reddit_score": "number",
            "trend_score": "number",
            "fuentes": "integer",
        },
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


def get_column_types(nombre_archivo):
    """Retorna contrato mínimo de tipos por columna para un CSV lógico."""
    return CSV_SCHEMA_CONTRACT.get(nombre_archivo, {}).get("column_types", {})


def get_contract_version():
    """Retorna la versión vigente del contrato de datos CSV."""
    return CONTRACT_VERSION
