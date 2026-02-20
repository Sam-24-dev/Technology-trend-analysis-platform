"""
GitHub ETL - Technology Trend Analysis Platform

Extracts repository data from the GitHub API to analyze
technology trends: top languages, framework activity,
and stars-contributors correlation.

Author: Samir Caizapasto
"""
import requests
import pandas as pd
import time
import re

from config.settings import (
    GITHUB_API_BASE, GITHUB_HEADERS, MAX_REPOS, PER_PAGE,
    FRAMEWORK_REPOS,
    FECHA_INICIO_STR, FECHA_FIN_STR, FECHA_INICIO_ISO,
    REQUEST_TIMEOUT_SECONDS, HTTP_MAX_RETRIES, HTTP_RETRY_BACKOFF_SECONDS,
    REQUEST_PAGE_DELAY_SECONDS, REQUEST_MEDIUM_DELAY_SECONDS, REQUEST_SHORT_DELAY_SECONDS
)
from exceptions import ETLExtractionError, ETLValidationError
from base_etl import BaseETL


class GitHubETL(BaseETL):
    """ETL extractor for GitHub repository data."""

    ETIQUETAS_NO_LENGUAJE = {
        "sin especificar",
        "llms/ai",
        "ai/ml",
        "ai",
        "llm",
        "genai",
        "artificial intelligence",
    }

    KEYWORDS_AI = [
        "llm", "ai", "ai/ml", "machine learning", "deep learning",
        "gpt", "chatgpt", "gemini", "claude", "deepseek", "openai",
        "anthropic", "prompt", "rag", "vector db",
    ]

    def __init__(self):
        super().__init__("github")
        self.df_repos = None

    def definir_pasos(self):
        """Defines the GitHub ETL steps."""
        return [
            ("Verificar conexion", self.verificar_conexion),
            ("Extraccion de repos", self.extraer_repos),
            ("Analisis de lenguajes", self.analizar_lenguajes),
            ("Insights repos IA", self.generar_insights_repos_ai),
            ("Analisis de commits", self.analizar_commits_frameworks),
            ("Correlacion stars-contributors", self.analizar_correlacion),
        ]

    def validar_configuracion(self):
        """Warns when running without GitHub token (degraded quota mode)."""
        if not GITHUB_HEADERS.get("Authorization"):
            self.logger.warning(
                "GITHUB_TOKEN no configurado. Se ejecutara en modo degradado "
                "(limite de 60 requests/h)."
            )

    def _normalizar_lenguaje(self, valor):
        """Normalizes language values from GitHub API."""
        if valor is None:
            return "Sin especificar"
        texto = str(valor).strip()
        return texto if texto else "Sin especificar"

    def _es_lenguaje_clasificable(self, lenguaje):
        """Returns True when the value represents a real programming language."""
        if lenguaje is None:
            return False
        return str(lenguaje).strip().lower() not in self.ETIQUETAS_NO_LENGUAJE

    def _es_repo_ai(self, repo_name, description, language):
        """Detects whether a repository is related to AI/LLMs."""
        nombre = str(repo_name or "").lower()
        desc = str(description or "").lower()
        lenguaje = str(language or "").strip().lower()

        if lenguaje in {"llms/ai", "ai/ml", "ai", "llm", "genai", "artificial intelligence"}:
            return True

        texto = f"{nombre} {desc}"
        return any(kw in texto for kw in self.KEYWORDS_AI)

    def verificar_conexion(self):
        """Verifies connection to the GitHub API and checks rate limit."""
        self.logger.info("Verificando conexion con GitHub API...")

        try:
            response = requests.get(
                f"{GITHUB_API_BASE}/rate_limit",
                headers=GITHUB_HEADERS,
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
        except requests.exceptions.RequestException as e:
            raise ETLExtractionError(f"Error de red: {e}", critical=True) from e

        if response.status_code == 200:
            data = response.json()
            core = data.get('resources', {}).get('core', {})
            remaining = core.get('remaining', 'N/A')
            limit = core.get('limit', 'N/A')
            search = data.get('resources', {}).get('search', {})
            self.logger.info(f"Rate Limit Core: {remaining}/{limit} requests disponibles")
            self.logger.info(f"Rate Limit Search: {search.get('remaining', '?')}/{search.get('limit', '?')}")
            if GITHUB_HEADERS.get('Authorization'):
                self.logger.info("Autenticado con token personal")
            else:
                self.logger.warning("Sin token — rate limit reducido (60 req/h)")
        else:
            raise ETLExtractionError(f"Error de conexion: {response.status_code}", critical=True)

    def esperar_rate_limit(self, response):
        """Handles GitHub API rate limiting by waiting until reset."""
        if response.status_code == 403:
            reset_time = int(response.headers.get('X-RateLimit-Reset', 0))
            if reset_time:
                wait_seconds = reset_time - int(time.time()) + 5
                if wait_seconds > 0 and wait_seconds < 300:
                    self.logger.warning(f"Rate limit alcanzado. Esperando {wait_seconds} segundos...")
                    time.sleep(wait_seconds)
                    return True
        return False

    def extraer_repos(self, max_repos=MAX_REPOS):
        """Extracts the most popular repositories from the last 12 months.

        Raises:
            ETLExtractionError: If no repositories could be extracted.
        """
        self.logger.info(f"Extrayendo top {max_repos} repos ({FECHA_INICIO_STR} a {FECHA_FIN_STR})...")

        repos_data = []
        page = 1
        total_pages = max(1, (max_repos + PER_PAGE - 1) // PER_PAGE)
        max_retries = HTTP_MAX_RETRIES
        max_fallos_consecutivos = 5
        fallos_consecutivos = 0

        while len(repos_data) < max_repos and page <= total_pages:
            self.logger.info(f"  Pagina {page}/{total_pages}...")

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
                        timeout=REQUEST_TIMEOUT_SECONDS
                    )
                except requests.exceptions.RequestException as e:
                    self.logger.error(f"Error de red en pagina {page}: {e}")
                    break

                if response.status_code == 200:
                    break
                elif response.status_code == 403:
                    if self.esperar_rate_limit(response):
                        continue
                    else:
                        self.logger.warning(f"  Error 403, reintentando ({retry+1}/{max_retries})...")
                        time.sleep(HTTP_RETRY_BACKOFF_SECONDS * (retry + 1))
                else:
                    self.logger.error(f"Error en pagina {page}: {response.status_code}")
                    break

            if response is None or response.status_code != 200:
                fallos_consecutivos += 1
                if fallos_consecutivos >= max_fallos_consecutivos:
                    self.logger.error(
                        "Demasiados fallos consecutivos (%s), deteniendo extraccion",
                        fallos_consecutivos,
                    )
                    break
                page += 1
                continue

            fallos_consecutivos = 0

            data = response.json()
            items = data.get("items", [])

            if not items:
                break

            for repo in items:
                language = self._normalizar_lenguaje(repo.get("language"))

                repos_data.append({
                    "repo_name": repo["full_name"],
                    "language": language,
                    "stars": repo["stargazers_count"],
                    "forks": repo["forks_count"],
                    "created_at": repo["created_at"],
                    "description": repo.get("description", "")[:100] if repo.get("description") else ""
                })

            page += 1
            time.sleep(REQUEST_PAGE_DELAY_SECONDS)

        if not repos_data:
            raise ETLExtractionError("No se pudo extraer ningun repositorio de GitHub", critical=True)

        self.logger.info(f"Extraidos {len(repos_data)} repos")

        self.df_repos = pd.DataFrame(repos_data)
        self.guardar_csv(self.df_repos, "github_repos")

    def analizar_lenguajes(self):
        """Analyzes the most used programming languages in recent repos."""
        self.logger.info("PREGUNTA 1: Analizando lenguajes...")

        if self.df_repos is None or self.df_repos.empty:
            raise ETLValidationError("DataFrame de repos vacio, no se puede analizar lenguajes")

        df_clasificables = self.df_repos.copy()
        df_clasificables["language"] = df_clasificables["language"].apply(self._normalizar_lenguaje)
        df_clasificables = df_clasificables[
            df_clasificables["language"].apply(self._es_lenguaje_clasificable)
        ]

        if df_clasificables.empty:
            raise ETLValidationError("No hay lenguajes clasificables para analizar")

        total_repos = len(df_clasificables)
        total_excluidos = len(self.df_repos) - total_repos
        lenguajes = df_clasificables["language"].value_counts()
        top_10 = lenguajes.head(10)

        df_lenguajes = pd.DataFrame({
            "lenguaje": top_10.index,
            "repos_count": top_10.values
        })
        df_lenguajes["porcentaje"] = (df_lenguajes["repos_count"] / total_repos * 100).round(2)

        self.logger.info(f"Top 10 Lenguajes (de {total_repos} repos clasificables):")
        self.logger.info("Repos excluidos por no clasificables: %s", total_excluidos)
        for i, row in df_lenguajes.iterrows():
            self.logger.info(f"  {i+1}. {row['lenguaje']}: {row['repos_count']} repos ({row['porcentaje']}%)")

        suma_top10 = df_lenguajes["repos_count"].sum()
        self.logger.info(f"Suma Top 10: {suma_top10} repos ({suma_top10/total_repos*100:.1f}% del total)")

        self.guardar_csv(df_lenguajes, "github_lenguajes")

    def generar_insights_repos_ai(self):
        """Builds a dedicated insights CSV for AI/LLM repositories."""
        self.logger.info("PREGUNTA 1b: Generando insights de repos IA/LLMs...")

        if self.df_repos is None or self.df_repos.empty:
            raise ETLValidationError("DataFrame de repos vacio, no se pueden generar insights IA")

        df = self.df_repos.copy()
        df["language"] = df["language"].apply(self._normalizar_lenguaje)
        df["description"] = df["description"].fillna("")

        mask_ai = df.apply(
            lambda row: self._es_repo_ai(row["repo_name"], row["description"], row["language"]),
            axis=1,
        )
        ai_df = df[mask_ai].copy()

        total_repos = len(df)
        total_ai = len(ai_df)
        porcentaje_ai = round((total_ai / total_repos) * 100, 2) if total_repos else 0.0

        mes_pico = "N/A"
        repos_mes_pico = 0
        if not ai_df.empty:
            fechas = pd.to_datetime(ai_df["created_at"], errors="coerce")
            meses = fechas.dt.strftime("%Y-%m").dropna()
            if not meses.empty:
                conteo_meses = meses.value_counts()
                mes_pico = str(conteo_meses.index[0])
                repos_mes_pico = int(conteo_meses.iloc[0])

        texto_ai = " ".join((ai_df["repo_name"].fillna("") + " " + ai_df["description"].fillna("")) if not ai_df.empty else [])
        texto_ai = texto_ai.lower()
        conteo_keywords = {
            kw: texto_ai.count(kw) for kw in self.KEYWORDS_AI if texto_ai.count(kw) > 0
        }
        top_keywords = sorted(conteo_keywords.items(), key=lambda item: item[1], reverse=True)[:5]
        top_keywords_str = " | ".join([f"{kw}:{cnt}" for kw, cnt in top_keywords]) if top_keywords else "N/A"

        top_repos = []
        if not ai_df.empty:
            top_repos = ai_df.sort_values("stars", ascending=False).head(5)["repo_name"].tolist()
        top_repos_str = " | ".join(top_repos) if top_repos else "N/A"

        df_insights = pd.DataFrame([
            {
                "total_repos_analizados": total_repos,
                "repos_ai_detectados": total_ai,
                "porcentaje_ai": porcentaje_ai,
                "mes_pico_ai": mes_pico,
                "repos_mes_pico_ai": repos_mes_pico,
                "top_keywords_ai": top_keywords_str,
                "top_repos_ai": top_repos_str,
            }
        ])

        self.logger.info(
            "Repos IA detectados: %s/%s (%.2f%%)", total_ai, total_repos, porcentaje_ai
        )
        self.guardar_csv(df_insights, "github_ai_insights")

    def analizar_commits_frameworks(self):
        """Analyzes commit activity for frontend frameworks."""
        self.logger.info("PREGUNTA 2: Analizando commits de frameworks...")

        commits_data = []

        for framework, repo_path in FRAMEWORK_REPOS.items():
            self.logger.info(f"  Analizando {framework} ({repo_path})...")

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
                        timeout=REQUEST_TIMEOUT_SECONDS
                    )
                except requests.exceptions.RequestException as e:
                    self.logger.error(f"  Error de red para {framework}: {e}")
                    break

                if response.status_code != 200:
                    if response.status_code == 403:
                        if self.esperar_rate_limit(response):
                            continue
                        else:
                            self.logger.error(f"  Rate limit sin header de reset para {framework}, saltando")
                            break
                    self.logger.error(f"  Error obteniendo commits: {response.status_code}")
                    break

                commits = response.json()
                if not commits:
                    break

                total_commits += len(commits)
                page += 1
                time.sleep(REQUEST_MEDIUM_DELAY_SECONDS)

                if page > 50:
                    break

            commits_data.append({
                "framework": framework,
                "repo": repo_path,
                "commits_2025": total_commits
            })
            self.logger.info(f"  {framework}: {total_commits} commits")

        if not commits_data:
            raise ETLExtractionError("No se pudo extraer datos de commits de ningun framework")

        df_commits = pd.DataFrame(commits_data)
        df_commits = df_commits.sort_values("commits_2025", ascending=False).reset_index(drop=True)
        df_commits["ranking"] = range(1, len(df_commits) + 1)

        self.logger.info("Ranking de Frameworks Frontend por Commits:")
        for _, row in df_commits.iterrows():
            self.logger.info(f"  #{row['ranking']} {row['framework']}: {row['commits_2025']} commits")

        self.guardar_csv(df_commits, "github_commits")

    def analizar_correlacion(self):
        """Analyzes the correlation between Stars and Contributors."""
        self.logger.info("PREGUNTA 3: Analizando correlacion Stars vs Contributors...")

        if self.df_repos is None or self.df_repos.empty:
            raise ETLValidationError("DataFrame de repos vacio, no se puede analizar correlacion")

        correlacion_data = []
        total = min(100, len(self.df_repos))

        count = 0
        for _, row in self.df_repos.head(total).iterrows():
            count += 1
            repo_name = row["repo_name"]
            self.logger.info(f"  [{count}/{total}] {repo_name}...")

            max_retries = HTTP_MAX_RETRIES
            success = False
            response = None

            for attempt in range(max_retries):
                try:
                    response = requests.get(
                        f"{GITHUB_API_BASE}/repos/{repo_name}/contributors",
                        headers=GITHUB_HEADERS,
                        params={"per_page": 1, "anon": "true"},
                        timeout=REQUEST_TIMEOUT_SECONDS
                    )

                    if response.status_code == 200:
                        success = True
                        break
                    elif response.status_code == 403:
                        if self.esperar_rate_limit(response):
                            continue
                        else:
                            self.logger.warning(" Rate limit, esperando backoff...")
                            time.sleep(HTTP_RETRY_BACKOFF_SECONDS * (attempt + 1))
                    else:
                        self.logger.error(f" Error: {response.status_code}")
                        break
                except requests.exceptions.RequestException as e:
                    self.logger.warning(f" Error de red, reintento {attempt + 1}/{max_retries}: {e}")
                    time.sleep(HTTP_RETRY_BACKOFF_SECONDS * (attempt + 1))

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
                self.logger.info(f"    {contributors} contributors")
            else:
                self.logger.warning("    No se pudo obtener contributors")
                correlacion_data.append({
                    "repo_name": repo_name,
                    "stars": row["stars"],
                    "contributors": 0,
                    "language": row["language"]
                })

            time.sleep(REQUEST_SHORT_DELAY_SECONDS)

        df_correlacion = pd.DataFrame(correlacion_data)

        if len(df_correlacion) > 0:
            correlacion = df_correlacion["stars"].corr(df_correlacion["contributors"])
            self.logger.info(f"Coeficiente de correlacion: {correlacion:.4f}")

            if correlacion > 0.7:
                self.logger.info("  Correlacion FUERTE positiva")
            elif correlacion > 0.4:
                self.logger.info("  Correlacion MODERADA positiva")
            elif correlacion > 0:
                self.logger.info("  Correlacion DEBIL positiva")
            else:
                self.logger.info("  Correlacion negativa o nula")

        self.guardar_csv(df_correlacion, "github_correlacion")


def main():
    """Entry point for the GitHub ETL pipeline."""
    etl = GitHubETL()
    etl.ejecutar()


if __name__ == "__main__":
    main()
