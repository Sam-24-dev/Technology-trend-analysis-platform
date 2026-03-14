"""
GitHub ETL - Technology Trend Analysis Platform

Extrae datos de repositorios desde la GitHub API 
para analizar tendencias tecnológicas: lenguajes más utilizados, 
actividad de frameworks y correlación entre stars y 
contributors.
Author: Samir Caizapasto
"""
from datetime import datetime, timezone

import requests
import pandas as pd
import time
import re

from config.settings import (
    GITHUB_API_BASE, GITHUB_HEADERS, MAX_REPOS, PER_PAGE,
    FRAMEWORK_REPOS,
    FECHA_INICIO_STR, FECHA_FIN_STR, FECHA_INICIO_ISO,
    DATOS_HISTORY_DIR,
    REQUEST_TIMEOUT_SECONDS, HTTP_MAX_RETRIES, HTTP_RETRY_BACKOFF_SECONDS,
    REQUEST_PAGE_DELAY_SECONDS, REQUEST_MEDIUM_DELAY_SECONDS, REQUEST_SHORT_DELAY_SECONDS
)
from exceptions import ETLExtractionError, ETLValidationError
from base_etl import BaseETL


class GitHubETL(BaseETL):
    """Extractor ETL para datos de repositorios de GitHub."""

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
        """Define los pasos del ETL de GitHub."""
        return [
            ("Verificar conexion", self.verificar_conexion),
            ("Extraccion de repos", self.extraer_repos),
            ("Analisis de lenguajes", self.analizar_lenguajes),
            ("Insights repos IA", self.generar_insights_repos_ai),
            ("Analisis de commits", self.analizar_commits_frameworks),
            ("Correlacion stars-contributors", self.analizar_correlacion),
        ]

    def validar_configuracion(self):
        """Advierte cuando se ejecuta sin GitHub token (modo degradado de cuota)."""
        if not GITHUB_HEADERS.get("Authorization"):
            self.logger.warning(
                "GITHUB_TOKEN no configurado. Se ejecutara en modo degradado "
                "(limite de 60 requests/h)."
            )

    def _normalizar_lenguaje(self, valor):
        """Normaliza valores de lenguaje provenientes de la GitHub API."""
        if valor is None:
            return "Sin especificar"
        texto = str(valor).strip()
        return texto if texto else "Sin especificar"

    def _es_lenguaje_clasificable(self, lenguaje):
        """Retorna True cuando el valor representa un lenguaje de programación real."""
        if lenguaje is None:
            return False
        return str(lenguaje).strip().lower() not in self.ETIQUETAS_NO_LENGUAJE

    def _es_repo_ai(self, repo_name, description, language):
        """Detecta si un repositorio está relacionado con AI/LLMs."""
        nombre = str(repo_name or "").lower()
        desc = str(description or "").lower()
        lenguaje = str(language or "").strip().lower()

        if lenguaje in {"llms/ai", "ai/ml", "ai", "llm", "genai", "artificial intelligence"}:
            return True

        texto = f"{nombre} {desc}"
        return any(kw in texto for kw in self.KEYWORDS_AI)

    @staticmethod
    def _classify_correlation_trend_bucket(outlier_score):
        """Clasifica un repo respecto a la línea de tendencia del snapshot actual."""
        if outlier_score >= 1.0:
            return "above_trend"
        if outlier_score <= -1.0:
            return "below_trend"
        return "near_trend"

    def _build_correlation_dataframe(self, correlacion_data):
        """Enriquece el dataset de correlación con métricas derivadas del snapshot."""
        df_correlacion = pd.DataFrame(correlacion_data)
        if df_correlacion.empty:
            return df_correlacion, 0.0

        working = df_correlacion.copy()
        working["repo_name"] = working["repo_name"].astype(str).str.strip()
        working["language"] = working["language"].astype(str).str.strip()
        working["stars"] = pd.to_numeric(working["stars"], errors="coerce").fillna(0).astype(int)
        working["contributors"] = pd.to_numeric(working["contributors"], errors="coerce").fillna(0).astype(int)

        correlation = float(working["stars"].corr(working["contributors"])) if len(working) > 1 else 0.0
        if pd.isna(correlation):
            correlation = 0.0

        x = working["stars"].astype(float)
        y = working["contributors"].astype(float)
        mean_x = float(x.mean()) if len(working) > 0 else 0.0
        mean_y = float(y.mean()) if len(working) > 0 else 0.0
        variance_x = float(((x - mean_x) ** 2).mean()) if len(working) > 0 else 0.0

        if variance_x > 0:
            covariance_xy = float(((x - mean_x) * (y - mean_y)).mean())
            slope = covariance_xy / variance_x
            intercept = mean_y - (slope * mean_x)
            expected = (slope * x) + intercept
        else:
            expected = pd.Series([mean_y] * len(working), index=working.index, dtype="float64")

        expected = expected.clip(lower=0.0)
        residuals = y - expected
        residual_std = float(residuals.std(ddof=0))
        if pd.isna(residual_std):
            residual_std = 0.0

        if residual_std > 0:
            outlier_scores = residuals / residual_std
        else:
            outlier_scores = pd.Series([0.0] * len(working), index=working.index, dtype="float64")

        snapshot_date_utc = datetime.now(timezone.utc).strftime("%Y-%m-%d")

        working["engagement_ratio"] = working.apply(
            lambda row: round((row["contributors"] / row["stars"]) if row["stars"] > 0 else 0.0, 6),
            axis=1,
        )
        working["contributors_per_1k_stars"] = working["engagement_ratio"].mul(1000).round(3)
        working["expected_contributors"] = expected.round(3)
        working["contributors_delta_vs_trend"] = residuals.round(3)
        working["outlier_score"] = outlier_scores.round(6)
        working["trend_bucket"] = working["outlier_score"].apply(self._classify_correlation_trend_bucket)
        working["snapshot_date_utc"] = snapshot_date_utc

        return working, correlation

    def verificar_conexion(self):
        """Verifica conexión con la GitHub API y revisa el rate limit."""
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
        """Gestiona el rate limiting de GitHub API esperando hasta el reset."""
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
        """Extrae los repositorios más populares de los últimos 12 meses.

        Raises:
            ETLExtractionError: Si no se pudo extraer ningún repositorio.
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
        """Analiza los lenguajes de programación más usados en repos recientes."""
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
        """Construye un CSV de insights dedicado para repositorios AI/LLM."""
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

    @staticmethod
    def _extract_partition_date(parts):
        if len(parts) < 3:
            return None
        year_part, month_part, day_part = parts[0], parts[1], parts[2]
        if not (
            year_part.startswith("year=")
            and month_part.startswith("month=")
            and day_part.startswith("day=")
        ):
            return None
        year = year_part.split("=", maxsplit=1)[1]
        month = month_part.split("=", maxsplit=1)[1]
        day = day_part.split("=", maxsplit=1)[1]
        return f"{year}-{month}-{day}"

    def _resolve_previous_commits_snapshot(self):
        history_root = DATOS_HISTORY_DIR / "github_commits"
        if not history_root.exists():
            return None, None

        snapshots = []
        for csv_path in history_root.rglob("github_commits_frameworks.csv"):
            rel_parts = csv_path.relative_to(history_root).parts
            date_label = self._extract_partition_date(rel_parts)
            if date_label is None:
                continue
            snapshots.append((date_label, csv_path))

        if not snapshots:
            return None, None

        snapshots.sort(key=lambda item: (item[0], str(item[1])))
        return snapshots[-1]

    def _load_previous_commits_map(self):
        snapshot_date, snapshot_path = self._resolve_previous_commits_snapshot()
        if snapshot_path is None:
            return {}, None

        try:
            previous_df = pd.read_csv(snapshot_path)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            self.logger.warning(
                "No se pudo leer snapshot historico previo de commits (%s): %s",
                snapshot_path,
                exc,
            )
            return {}, None

        if "framework" not in previous_df.columns or "commits_2025" not in previous_df.columns:
            return {}, None

        commits_prev = {}
        for _, row in previous_df.iterrows():
            framework = str(row.get("framework", "")).strip()
            if not framework:
                continue
            prev_value = pd.to_numeric(row.get("commits_2025"), errors="coerce")
            if pd.isna(prev_value):
                prev_value = 0
            commits_prev[framework] = int(prev_value)
        return commits_prev, snapshot_date

    @staticmethod
    def _safe_month_label(value):
        parsed = pd.to_datetime(value, errors="coerce", utc=True)
        if pd.isna(parsed):
            return None
        return parsed.strftime("%Y-%m")

    @staticmethod
    def _compute_growth(current_value, previous_value):
        if previous_value is None or previous_value <= 0:
            return None
        return round(((current_value - previous_value) / previous_value) * 100, 2)

    @staticmethod
    def _compute_trend_direction(delta_value):
        if delta_value is None:
            return None
        if delta_value > 0:
            return "creciendo"
        if delta_value < 0:
            return "cayendo"
        return "estable"

    def _count_search_items(self, query):
        for retry in range(HTTP_MAX_RETRIES):
            try:
                response = requests.get(
                    f"{GITHUB_API_BASE}/search/issues",
                    headers=GITHUB_HEADERS,
                    params={"q": query, "per_page": 1},
                    timeout=REQUEST_TIMEOUT_SECONDS,
                )
            except requests.exceptions.RequestException as exc:
                self.logger.warning("Error de red en query search '%s': %s", query, exc)
                time.sleep(HTTP_RETRY_BACKOFF_SECONDS * (retry + 1))
                continue

            if response.status_code == 200:
                return int(response.json().get("total_count", 0))

            if response.status_code == 403 and self.esperar_rate_limit(response):
                continue

            self.logger.warning(
                "Query search fallo (status=%s) para '%s'",
                response.status_code,
                query,
            )
            time.sleep(HTTP_RETRY_BACKOFF_SECONDS * (retry + 1))
        return 0

    def _count_releases_since(self, repo_path):
        since_ref = pd.to_datetime(FECHA_INICIO_ISO, errors="coerce", utc=True)
        if pd.isna(since_ref):
            return 0

        releases_count = 0
        page = 1
        while page <= 10:
            try:
                response = requests.get(
                    f"{GITHUB_API_BASE}/repos/{repo_path}/releases",
                    headers=GITHUB_HEADERS,
                    params={"per_page": 100, "page": page},
                    timeout=REQUEST_TIMEOUT_SECONDS,
                )
            except requests.exceptions.RequestException as exc:
                self.logger.warning(
                    "Error de red obteniendo releases para %s: %s",
                    repo_path,
                    exc,
                )
                break

            if response.status_code != 200:
                if response.status_code == 403 and self.esperar_rate_limit(response):
                    continue
                self.logger.warning(
                    "No se pudieron obtener releases para %s (status=%s)",
                    repo_path,
                    response.status_code,
                )
                break

            releases = response.json()
            if not isinstance(releases, list) or not releases:
                break

            for release in releases:
                published_at = pd.to_datetime(
                    release.get("published_at"),
                    errors="coerce",
                    utc=True,
                )
                if not pd.isna(published_at) and published_at >= since_ref:
                    releases_count += 1

            if len(releases) < 100:
                break
            page += 1
            time.sleep(REQUEST_SHORT_DELAY_SECONDS)

        return releases_count

    def _collect_framework_metrics(self, framework, repo_path):
        params = {
            "since": FECHA_INICIO_ISO,
            "per_page": 100,
        }
        total_commits = 0
        page = 1
        monthly_counts = {}
        unique_contributors = set()

        while True:
            params["page"] = page
            try:
                response = requests.get(
                    f"{GITHUB_API_BASE}/repos/{repo_path}/commits",
                    headers=GITHUB_HEADERS,
                    params=params,
                    timeout=REQUEST_TIMEOUT_SECONDS,
                )
            except requests.exceptions.RequestException as exc:
                self.logger.error("  Error de red para %s: %s", framework, exc)
                break

            if response.status_code != 200:
                if response.status_code == 403 and self.esperar_rate_limit(response):
                    continue
                self.logger.error(
                    "  Error obteniendo commits para %s: %s",
                    framework,
                    response.status_code,
                )
                break

            commits = response.json()
            if not commits:
                break

            total_commits += len(commits)
            for commit in commits:
                commit_author = commit.get("commit", {}).get("author", {}) or {}
                commit_committer = commit.get("commit", {}).get("committer", {}) or {}
                month_label = self._safe_month_label(
                    commit_author.get("date") or commit_committer.get("date")
                )
                if month_label:
                    monthly_counts[month_label] = monthly_counts.get(month_label, 0) + 1

                author = commit.get("author") or {}
                login = str(author.get("login", "")).strip().lower()
                if login:
                    unique_contributors.add(f"login:{login}")
                else:
                    email = str(commit_author.get("email", "")).strip().lower()
                    name = str(commit_author.get("name", "")).strip().lower()
                    if email or name:
                        unique_contributors.add(f"anon:{email}|{name}")

            page += 1
            time.sleep(REQUEST_MEDIUM_DELAY_SECONDS)
            if page > 50:
                break

        merged_prs = self._count_search_items(
            f"repo:{repo_path} is:pr is:merged merged:{FECHA_INICIO_STR}..{FECHA_FIN_STR}"
        )
        closed_issues = self._count_search_items(
            f"repo:{repo_path} is:issue closed:{FECHA_INICIO_STR}..{FECHA_FIN_STR}"
        )
        releases_count = self._count_releases_since(repo_path)

        return {
            "framework": framework,
            "repo": repo_path,
            "commits_2025": total_commits,
            "active_contributors": len(unique_contributors),
            "merged_prs": merged_prs,
            "closed_issues": closed_issues,
            "releases_count": releases_count,
            "monthly_commits": monthly_counts,
        }

    def _build_monthly_framework_rows(self, framework, repo_path, monthly_counts):
        month_range = (
            pd.period_range(
                start=FECHA_INICIO_STR[:7],
                end=FECHA_FIN_STR[:7],
                freq="M",
            )
            .astype(str)
            .tolist()
        )
        return [
            {
                "framework": framework,
                "repo": repo_path,
                "month": month_label,
                "commits": int(monthly_counts.get(month_label, 0)),
            }
            for month_label in month_range
        ]

    def analizar_commits_frameworks(self):
        """Analiza la actividad de commits de frameworks frontend."""
        self.logger.info("PREGUNTA 2: Analizando commits de frameworks...")

        commits_prev_map, previous_snapshot_date = self._load_previous_commits_map()
        if previous_snapshot_date:
            self.logger.info(
                "Comparando contra snapshot historico anterior: %s",
                previous_snapshot_date,
            )

        commits_data = []
        monthly_rows = []

        for framework, repo_path in FRAMEWORK_REPOS.items():
            self.logger.info(f"  Analizando {framework} ({repo_path})...")
            metrics = self._collect_framework_metrics(framework, repo_path)
            previous_commits = commits_prev_map.get(framework)
            delta_commits = (
                metrics["commits_2025"] - previous_commits
                if previous_commits is not None
                else None
            )
            growth_pct = self._compute_growth(
                metrics["commits_2025"],
                previous_commits,
            )
            trend_direction = self._compute_trend_direction(delta_commits)
            commits_data.append({
                "framework": framework,
                "repo": repo_path,
                "commits_2025": metrics["commits_2025"],
                "active_contributors": metrics["active_contributors"],
                "merged_prs": metrics["merged_prs"],
                "closed_issues": metrics["closed_issues"],
                "releases_count": metrics["releases_count"],
                "commits_prev": previous_commits,
                "delta_commits": delta_commits,
                "growth_pct": growth_pct,
                "trend_direction": trend_direction,
            })
            monthly_rows.extend(
                self._build_monthly_framework_rows(
                    framework=framework,
                    repo_path=repo_path,
                    monthly_counts=metrics["monthly_commits"],
                )
            )
            self.logger.info(
                "  %s: commits=%s contributors=%s prs=%s issues=%s releases=%s",
                framework,
                metrics["commits_2025"],
                metrics["active_contributors"],
                metrics["merged_prs"],
                metrics["closed_issues"],
                metrics["releases_count"],
            )

        if not commits_data:
            raise ETLExtractionError("No se pudo extraer datos de commits de ningun framework")

        df_commits = pd.DataFrame(commits_data)
        df_commits = df_commits.sort_values("commits_2025", ascending=False).reset_index(drop=True)
        df_commits["ranking"] = range(1, len(df_commits) + 1)
        df_commits = df_commits[
            [
                "framework",
                "repo",
                "commits_2025",
                "active_contributors",
                "merged_prs",
                "closed_issues",
                "releases_count",
                "commits_prev",
                "delta_commits",
                "growth_pct",
                "trend_direction",
                "ranking",
            ]
        ]

        self.logger.info("Ranking de Frameworks Frontend por Commits:")
        for _, row in df_commits.iterrows():
            self.logger.info(
                "  #%s %s: %s commits (delta=%s)",
                row["ranking"],
                row["framework"],
                row["commits_2025"],
                row["delta_commits"] if not pd.isna(row["delta_commits"]) else "N/A",
            )

        self.guardar_csv(df_commits, "github_commits")

        df_monthly = pd.DataFrame(monthly_rows)
        if not df_monthly.empty:
            df_monthly = df_monthly.sort_values(
                ["framework", "month"],
                ascending=[True, True],
            ).reset_index(drop=True)
            self.guardar_csv(df_monthly, "github_commits_monthly")

    def analizar_correlacion(self):
        """Analiza la correlación entre Stars y Contributors."""
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

        df_correlacion, correlacion = self._build_correlation_dataframe(correlacion_data)

        if len(df_correlacion) > 0:
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
    """Punto de entrada para el pipeline ETL de GitHub."""
    etl = GitHubETL()
    etl.ejecutar()


if __name__ == "__main__":
    main()
