"""
GitHub ETL - Technology Trend Analysis Platform

Extracts repository data from the GitHub API to analyze
technology trends: top languages, framework activity,
and stars-contributors correlation.

Author: Samir Caizapasto
"""
import requests
import pandas as pd
from datetime import datetime
import time
import re
import logging

from config.settings import (
    GITHUB_TOKEN, GITHUB_API_BASE, GITHUB_HEADERS, MAX_REPOS, PER_PAGE,
    FRAMEWORK_REPOS, DATOS_DIR, ARCHIVOS_SALIDA,
    LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR,
    FECHA_INICIO_STR, FECHA_FIN_STR, FECHA_INICIO_ISO
)
from exceptions import ETLExtractionError, ETLValidationError
from validador import validar_dataframe

# Logger para este modulo
logger = logging.getLogger("github_etl")


def configurar_logging():
    """Sets up logging to console and daily log file."""
    logger.setLevel(logging.INFO)

    if logger.handlers:
        return

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
    logger.addHandler(console)

    fecha = datetime.now().strftime("%Y-%m-%d")
    archivo = LOGS_DIR / f"etl_{fecha}.log"
    file_handler = logging.FileHandler(archivo, encoding="utf-8")
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
    logger.addHandler(file_handler)


def verificar_conexion():
    """Verifies connection to the GitHub API and checks rate limit."""
    logger.info("Verificando conexion con GitHub API...")

    try:
        response = requests.get(f"{GITHUB_API_BASE}/user", headers=GITHUB_HEADERS, timeout=10)
    except requests.exceptions.RequestException as e:
        logger.error(f"Error de red: {e}")
        return False

    if response.status_code == 200:
        user = response.json()
        logger.info(f"Conectado como: {user.get('login', 'Usuario')}")
        remaining = response.headers.get('X-RateLimit-Remaining', 'N/A')
        limit = response.headers.get('X-RateLimit-Limit', 'N/A')
        logger.info(f"Rate Limit: {remaining}/{limit} requests disponibles")
        return True
    else:
        logger.error(f"Error de conexion: {response.status_code}")
        return False


def esperar_rate_limit(response):
    """Handles GitHub API rate limiting by waiting until reset."""
    if response.status_code == 403:
        reset_time = int(response.headers.get('X-RateLimit-Reset', 0))
        if reset_time:
            wait_seconds = reset_time - int(time.time()) + 5
            if wait_seconds > 0 and wait_seconds < 300:
                logger.warning(f"Rate limit alcanzado. Esperando {wait_seconds} segundos...")
                time.sleep(wait_seconds)
                return True
    return False


def extraer_repos_2025(max_repos=MAX_REPOS):
    """Extracts the most popular repositories from the last 12 months.

    Raises:
        ETLExtractionError: If no repositories could be extracted.
    """
    logger.info(f"Extrayendo top {max_repos} repos ({FECHA_INICIO_STR} a {FECHA_FIN_STR})...")

    repos_data = []
    page = 1
    total_pages = max_repos // PER_PAGE
    max_retries = 3

    while len(repos_data) < max_repos:
        logger.info(f"  Pagina {page}/{total_pages}...")

        params = {
            "q": f"created:{FECHA_INICIO_STR}..{FECHA_FIN_STR}",
            "sort": "stars",
            "order": "desc",
            "per_page": PER_PAGE,
            "page": page
        }

        response = None
        for retry in range(max_retries):
            try:
                response = requests.get(
                    f"{GITHUB_API_BASE}/search/repositories",
                    headers=GITHUB_HEADERS,
                    params=params,
                    timeout=10
                )
            except requests.exceptions.RequestException as e:
                logger.error(f"Error de red en pagina {page}: {e}")
                break

            if response.status_code == 200:
                break
            elif response.status_code == 403:
                if esperar_rate_limit(response):
                    continue
                else:
                    logger.warning(f"  Error 403, reintentando ({retry+1}/{max_retries})...")
                    time.sleep(10)
            else:
                logger.error(f"Error en pagina {page}: {response.status_code}")
                break

        if response is None or response.status_code != 200:
            page += 1
            continue

        data = response.json()
        items = data.get("items", [])

        if not items:
            break

        for repo in items:
            language = repo.get("language")
            if language is None or language == "":
                language = "Sin especificar"

            repos_data.append({
                "repo_name": repo["full_name"],
                "language": language,
                "stars": repo["stargazers_count"],
                "forks": repo["forks_count"],
                "created_at": repo["created_at"],
                "description": repo.get("description", "")[:100] if repo.get("description") else ""
            })

        page += 1
        time.sleep(2)

        if page > total_pages:
            break

    if not repos_data:
        raise ETLExtractionError("No se pudo extraer ningun repositorio de GitHub")

    logger.info(f"Extraidos {len(repos_data)} repos")

    df = pd.DataFrame(repos_data)
    validar_dataframe(df, "github_repos")
    df.to_csv(ARCHIVOS_SALIDA["github_repos"], index=False, encoding="utf-8")
    logger.info(f"Guardado en: {ARCHIVOS_SALIDA['github_repos']}")

    return df


def analizar_lenguajes(df_repos):
    """Analyzes the most used programming languages in recent repos.

    Raises:
        ETLValidationError: If the input DataFrame is empty.
    """
    logger.info("PREGUNTA 1: Analizando lenguajes...")

    if df_repos.empty:
        raise ETLValidationError("DataFrame de repos vacio, no se puede analizar lenguajes")

    total_repos = len(df_repos)
    lenguajes = df_repos["language"].value_counts()
    top_10 = lenguajes.head(10)

    df_lenguajes = pd.DataFrame({
        "lenguaje": top_10.index,
        "repos_count": top_10.values
    })
    df_lenguajes["porcentaje"] = (df_lenguajes["repos_count"] / total_repos * 100).round(2)

    logger.info(f"Top 10 Lenguajes (de {total_repos} repos):")
    for i, row in df_lenguajes.iterrows():
        logger.info(f"  {i+1}. {row['lenguaje']}: {row['repos_count']} repos ({row['porcentaje']}%)")

    suma_top10 = df_lenguajes["repos_count"].sum()
    logger.info(f"Suma Top 10: {suma_top10} repos ({suma_top10/total_repos*100:.1f}% del total)")

    validar_dataframe(df_lenguajes, "github_lenguajes")
    df_lenguajes.to_csv(ARCHIVOS_SALIDA["github_lenguajes"], index=False, encoding="utf-8")
    logger.info(f"Guardado en: {ARCHIVOS_SALIDA['github_lenguajes']}")

    return df_lenguajes


def analizar_commits_frameworks():
    """Analyzes commit activity for frontend frameworks.

    Raises:
        ETLExtractionError: If no commit data could be extracted.
    """
    logger.info("PREGUNTA 2: Analizando commits de frameworks...")

    commits_data = []

    for framework, repo_path in FRAMEWORK_REPOS.items():
        logger.info(f"  Analizando {framework} ({repo_path})...")

        params = {
            "since": FECHA_INICIO_ISO,
            "per_page": 100
        }

        total_commits = 0
        page = 1

        while True:
            params["page"] = page
            try:
                response = requests.get(
                    f"{GITHUB_API_BASE}/repos/{repo_path}/commits",
                    headers=GITHUB_HEADERS,
                    params=params,
                    timeout=10
                )
            except requests.exceptions.RequestException as e:
                logger.error(f"  Error de red para {framework}: {e}")
                break

            if response.status_code != 200:
                if response.status_code == 403:
                    esperar_rate_limit(response)
                    continue
                logger.error(f"  Error obteniendo commits: {response.status_code}")
                break

            commits = response.json()
            if not commits:
                break

            total_commits += len(commits)
            page += 1
            time.sleep(0.5)

            if page > 50:
                break

        commits_data.append({
            "framework": framework,
            "repo": repo_path,
            "commits_2025": total_commits
        })
        logger.info(f"  {framework}: {total_commits} commits")

    if not commits_data:
        raise ETLExtractionError("No se pudo extraer datos de commits de ningun framework")

    df_commits = pd.DataFrame(commits_data)
    df_commits = df_commits.sort_values("commits_2025", ascending=False).reset_index(drop=True)
    df_commits["ranking"] = range(1, len(df_commits) + 1)

    logger.info("Ranking de Frameworks Frontend por Commits:")
    for i, row in df_commits.iterrows():
        logger.info(f"  #{row['ranking']} {row['framework']}: {row['commits_2025']} commits")

    validar_dataframe(df_commits, "github_commits")
    df_commits.to_csv(ARCHIVOS_SALIDA["github_commits"], index=False, encoding="utf-8")
    logger.info(f"Guardado en: {ARCHIVOS_SALIDA['github_commits']}")

    return df_commits


def analizar_correlacion(df_repos):
    """Analyzes the correlation between Stars and Contributors.

    Raises:
        ETLValidationError: If the input DataFrame is empty.
    """
    logger.info("PREGUNTA 3: Analizando correlacion Stars vs Contributors...")

    if df_repos.empty:
        raise ETLValidationError("DataFrame de repos vacio, no se puede analizar correlacion")

    correlacion_data = []
    total = min(100, len(df_repos))

    count = 0
    for idx, row in df_repos.head(total).iterrows():
        count += 1
        repo_name = row["repo_name"]
        logger.info(f"  [{count}/{total}] {repo_name}...")

        max_retries = 3
        success = False
        response = None

        for attempt in range(max_retries):
            try:
                response = requests.get(
                    f"{GITHUB_API_BASE}/repos/{repo_name}/contributors",
                    headers=GITHUB_HEADERS,
                    params={"per_page": 1, "anon": "true"},
                    timeout=10
                )

                if response.status_code == 200:
                    success = True
                    break
                elif response.status_code == 403:
                    if esperar_rate_limit(response):
                        continue
                    else:
                        logger.warning(f" Rate limit, esperando 60s...")
                        time.sleep(60)
                else:
                    logger.error(f" Error: {response.status_code}")
                    break
            except requests.exceptions.RequestException as e:
                logger.warning(f" Error de red, reintento {attempt + 1}/{max_retries}: {e}")
                time.sleep(5)

        if success and response:
            contributors = len(response.json())

            link_header = response.headers.get("Link", "")
            if "last" in link_header:
                match = re.search(r'page=(\d+)>; rel="last"', link_header)
                if match:
                    contributors = int(match.group(1))

            correlacion_data.append({
                "repo_name": repo_name,
                "stars": row["stars"],
                "contributors": contributors,
                "language": row["language"]
            })
            logger.info(f"    {contributors} contributors")
        else:
            logger.warning(f"    No se pudo obtener contributors")
            correlacion_data.append({
                "repo_name": repo_name,
                "stars": row["stars"],
                "contributors": 0,
                "language": row["language"]
            })

        time.sleep(0.3)

    df_correlacion = pd.DataFrame(correlacion_data)

    if len(df_correlacion) > 0:
        correlacion = df_correlacion["stars"].corr(df_correlacion["contributors"])
        logger.info(f"Coeficiente de correlacion: {correlacion:.4f}")

        if correlacion > 0.7:
            logger.info("  Correlacion FUERTE positiva")
        elif correlacion > 0.4:
            logger.info("  Correlacion MODERADA positiva")
        elif correlacion > 0:
            logger.info("  Correlacion DEBIL positiva")
        else:
            logger.info("  Correlacion negativa o nula")

    validar_dataframe(df_correlacion, "github_correlacion")
    df_correlacion.to_csv(ARCHIVOS_SALIDA["github_correlacion"], index=False, encoding="utf-8")
    logger.info(f"Guardado en: {ARCHIVOS_SALIDA['github_correlacion']}")

    return df_correlacion


def main():
    """Main function that runs the complete GitHub ETL pipeline.
    Each step is wrapped in try/except so if one fails,
    the others still run.
    """
    configurar_logging()

    logger.info("GitHub ETL - Technology Trend Analysis Platform")
    logger.info(f"Rango: {FECHA_INICIO_STR} a {FECHA_FIN_STR}")

    if not verificar_conexion():
        logger.error("No se pudo conectar a GitHub. Verifica tu token.")
        return

    df_repos = None

    try:
        df_repos = extraer_repos_2025()
    except ETLExtractionError as e:
        logger.error(f"Extraccion fallida: {e}")
        return
    except Exception as e:
        logger.error(f"Error inesperado en extraccion: {e}")
        return

    try:
        analizar_lenguajes(df_repos)
    except (ETLValidationError, ETLExtractionError) as e:
        logger.error(f"Analisis de lenguajes fallido: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en lenguajes: {e}")

    try:
        analizar_commits_frameworks()
    except (ETLValidationError, ETLExtractionError) as e:
        logger.error(f"Analisis de commits fallido: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en commits: {e}")

    try:
        analizar_correlacion(df_repos)
    except (ETLValidationError, ETLExtractionError) as e:
        logger.error(f"Analisis de correlacion fallido: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en correlacion: {e}")

    logger.info("ETL GitHub completado")


if __name__ == "__main__":
    main()
