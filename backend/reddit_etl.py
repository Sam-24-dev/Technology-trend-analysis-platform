"""
Reddit ETL - Technology Trend Analysis Platform

Extracts data from subreddit r/webdev to analyze technology trends:
backend framework sentiment, emerging topics, and cross-platform
comparison with GitHub data.

Author: Mateo Mayorga
"""
import pandas as pd
from datetime import datetime
import requests
import nltk
from nltk.sentiment import SentimentIntensityAnalyzer
import warnings
import time
import re

from config.settings import (
    ARCHIVOS_SALIDA, REDDIT_SUBREDDIT, REDDIT_LIMIT,
    REDDIT_HEADERS, REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET,
    REDDIT_USER_AGENT,
    REQUEST_TIMEOUT_SECONDS, HTTP_RETRY_BACKOFF_SECONDS,
    REQUEST_PAGE_DELAY_SECONDS
)
from exceptions import ETLExtractionError, ETLValidationError
from base_etl import BaseETL
from tech_normalization import normalize_for_match

warnings.filterwarnings("ignore")


class RedditETL(BaseETL):
    """ETL extractor for Reddit post data."""

    def __init__(self):
        super().__init__("reddit")
        self.df_posts = None
        self.df_temas = None
        self.access_token = None
        self.api_base = "https://www.reddit.com"  # fallback: public API
        self.headers = dict(REDDIT_HEADERS)

    @staticmethod
    def _coincide_keyword(texto, keyword):
        """Checks keyword presence using boundary-safe regex matching."""
        kw = keyword.strip().lower()
        if not kw:
            return False

        if re.fullmatch(r"[a-z0-9_]+", kw):
            patron = rf"(?<![a-z0-9_]){re.escape(kw)}(?![a-z0-9_])"
        else:
            patron = rf"(?<!\w){re.escape(kw)}(?!\w)"
        return re.search(patron, texto, flags=re.IGNORECASE) is not None

    def _obtener_token_oauth(self):
        """Obtains an OAuth2 bearer token from Reddit using client credentials.

        If REDDIT_CLIENT_ID and REDDIT_CLIENT_SECRET are set, switches
        to the authenticated oauth.reddit.com endpoint which works from
        datacenter IPs (GitHub Actions).
        """
        if not REDDIT_CLIENT_ID or not REDDIT_CLIENT_SECRET:
            self.logger.warning(
                "Sin credenciales OAuth de Reddit — usando API publica "
                "(puede fallar desde IPs de datacenter)"
            )
            return

        self.logger.info("Obteniendo token OAuth de Reddit...")
        try:
            auth = requests.auth.HTTPBasicAuth(
                REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET
            )
            data = {
                "grant_type": "client_credentials",
            }
            resp = requests.post(
                "https://www.reddit.com/api/v1/access_token",
                auth=auth,
                data=data,
                headers={"User-Agent": REDDIT_USER_AGENT},
                timeout=REQUEST_TIMEOUT_SECONDS,
            )
            if resp.status_code == 200:
                token_data = resp.json()
                self.access_token = token_data.get("access_token")
                if self.access_token:
                    self.api_base = "https://oauth.reddit.com"
                    self.headers = {
                        "Authorization": f"Bearer {self.access_token}",
                        "User-Agent": REDDIT_USER_AGENT,
                    }
                    self.logger.info(
                        "OAuth autenticado — usando oauth.reddit.com"
                    )
                else:
                    self.logger.warning(
                        "Token vacio en respuesta OAuth: %s", token_data
                    )
            else:
                self.logger.warning(
                    "OAuth fallo (%d) — usando API publica", resp.status_code
                )
        except requests.exceptions.RequestException as e:
            self.logger.warning("Error en OAuth: %s — usando API publica", e)

    def definir_pasos(self):
        """Defines the Reddit ETL steps."""
        return [
            ("Preparar recursos NLTK", self._ensure_nltk_resources),
            ("Autenticacion OAuth", self._obtener_token_oauth),
            ("Extraccion de posts", self.extraer_posts),
            ("Sentimiento de frameworks", self.analizar_sentimiento_frameworks),
            ("Temas emergentes", self.detectar_temas_emergentes),
            ("Interseccion GitHub-Reddit", self.interseccion_tecnologias),
        ]

    def validar_configuracion(self):
        """Validates Reddit credentials consistency before running.

        - If both are missing: allowed (degraded public API mode).
        - If only one is present: invalid configuration (critical).
        """
        if bool(REDDIT_CLIENT_ID) ^ bool(REDDIT_CLIENT_SECRET):
            raise ETLExtractionError(
                "Configuracion incompleta: REDDIT_CLIENT_ID y REDDIT_CLIENT_SECRET "
                "deben estar ambos definidos o ambos vacios.",
                critical=True,
            )

        if not REDDIT_CLIENT_ID and not REDDIT_CLIENT_SECRET:
            self.logger.warning(
                "Credenciales OAuth de Reddit no configuradas. "
                "Se ejecutara en modo degradado (API publica)."
            )

    def _ensure_nltk_resources(self):
        """Ensures required NLTK resources are available at runtime.

        Avoids side effects during module import.
        """
        try:
            nltk.data.find('sentiment/vader_lexicon')
        except LookupError:
            self.logger.info("Descargando recurso NLTK: vader_lexicon")
            nltk.download('vader_lexicon', quiet=True)

        try:
            nltk.data.find('corpora/stopwords')
        except LookupError:
            self.logger.info("Descargando recurso NLTK: stopwords")
            nltk.download('stopwords', quiet=True)

    def extraer_posts(self, subreddit_name=REDDIT_SUBREDDIT, limit=REDDIT_LIMIT):
        """Fetches posts from a subreddit using Reddit's public JSON API.

        Raises:
            ETLExtractionError: If no posts could be fetched.
        """
        self.logger.info(f"Obteniendo posts de r/{subreddit_name}...")

        posts_data = []
        url = f"{self.api_base}/r/{subreddit_name}/hot.json"

        after = None
        posts_obtenidos = 0

        try:
            while posts_obtenidos < limit:
                params = {
                    "limit": 100,
                    "after": after
                }

                self.logger.info(f"  Descargando posts {posts_obtenidos + 1}-{min(posts_obtenidos + 100, limit)}...")

                try:
                    response = requests.get(
                        url,
                        headers=self.headers,
                        params=params,
                        timeout=REQUEST_TIMEOUT_SECONDS,
                    )
                except requests.exceptions.RequestException as e:
                    self.logger.error(f"  Error de red: {e}")
                    time.sleep(HTTP_RETRY_BACKOFF_SECONDS)
                    break

                if response.status_code != 200:
                    self.logger.error(f"  Error: {response.status_code}")
                    break

                data = response.json()
                children = data.get("data", {}).get("children", [])

                if not children:
                    break

                for post in children:
                    if posts_obtenidos >= limit:
                        break

                    post_data = post.get("data", {})

                    if post_data.get("is_self"):
                        posts_data.append({
                            "post_id": post_data.get("id"),
                            "titulo": post_data.get("title", ""),
                            "contenido": post_data.get("selftext", ""),
                            "upvotes": post_data.get("score", 0),
                            "comentarios": post_data.get("num_comments", 0),
                            "created_at": datetime.fromtimestamp(post_data.get("created_utc", 0)),
                            "autor": post_data.get("author", "Eliminado")
                        })
                        posts_obtenidos += 1

                after = data.get("data", {}).get("after")

                if not after:
                    break

                time.sleep(REQUEST_PAGE_DELAY_SECONDS)

            self.logger.info(f"Obtenidos {len(posts_data)} posts")

        except requests.exceptions.RequestException as e:
            self.logger.error(f"Error obteniendo posts: {e}")

        if not posts_data:
            # Try loading previous data if available
            ruta_anterior = ARCHIVOS_SALIDA.get("reddit_sentimiento")
            if ruta_anterior and ruta_anterior.exists():
                self.logger.warning(f"No se pudo extraer posts de r/{subreddit_name} — usando datos anteriores")
                raise ETLExtractionError(
                    "Reddit API no disponible (posible bloqueo de IP). "
                    "Los CSVs anteriores se mantienen.",
                    critical=False
                )
            else:
                raise ETLExtractionError(
                    f"No se pudo extraer posts de r/{subreddit_name} y no hay datos previos",
                    critical=True
                )

        self.df_posts = pd.DataFrame(posts_data)

    def analizar_sentimiento_frameworks(self):
        """Analyzes sentiment for backend frameworks mentioned in posts."""
        self.logger.info("PREGUNTA 1: Analizando sentimiento de frameworks backend...")

        if self.df_posts is None or self.df_posts.empty:
            raise ETLValidationError("DataFrame de posts vacio, no se puede analizar sentimiento")

        sia = SentimentIntensityAnalyzer()

        frameworks_backend = {
            "Django": ["django", "python web"],
            "FastAPI": ["fastapi"],
            "Express": ["express", "node.js", "nodejs"],
            "Spring": ["spring", "springboot", "spring boot", "java spring"],
            "Laravel": ["laravel", "php"]
        }

        sentimientos_framework = {}

        todos_textos = []
        for _, post in self.df_posts.iterrows():
            todos_textos.append({
                "texto": f"{post['titulo']} {post['contenido']}",
                "tipo": "post"
            })

        self.logger.info("Analizando sentimientos...")

        for framework, keywords in frameworks_backend.items():
            sentimientos = {"positivo": 0, "neutro": 0, "negativo": 0}
            total_menciones = 0

            for item in todos_textos:
                texto = item["texto"].lower()

                if any(self._coincide_keyword(texto, keyword) for keyword in keywords):
                    total_menciones += 1

                    scores = sia.polarity_scores(item["texto"])
                    compound = scores['compound']

                    if compound >= 0.05:
                        sentimientos["positivo"] += 1
                    elif compound <= -0.05:
                        sentimientos["negativo"] += 1
                    else:
                        sentimientos["neutro"] += 1

            if total_menciones > 0:
                sentimientos_framework[framework] = {
                    "total_menciones": total_menciones,
                    "positivo": sentimientos["positivo"],
                    "neutro": sentimientos["neutro"],
                    "negativo": sentimientos["negativo"],
                    "porcentaje_positivo": round((sentimientos["positivo"] / total_menciones) * 100, 2),
                    "porcentaje_neutro": round((sentimientos["neutro"] / total_menciones) * 100, 2),
                    "porcentaje_negativo": round((sentimientos["negativo"] / total_menciones) * 100, 2)
                }

        df_sentimientos = pd.DataFrame([
            {
                "framework": framework,
                "total_menciones": data["total_menciones"],
                "positivos": data["positivo"],
                "neutros": data["neutro"],
                "negativos": data["negativo"],
                "% positivo": data["porcentaje_positivo"],
                "% neutro": data["porcentaje_neutro"],
                "% negativo": data["porcentaje_negativo"]
            }
            for framework, data in sentimientos_framework.items()
        ]).sort_values("% positivo", ascending=False).reset_index(drop=True)

        self.logger.info("Top Frameworks Backend por Sentimiento Positivo:")
        for i, row in df_sentimientos.iterrows():
            self.logger.info(f"  {i+1}. {row['framework']}: {row['% positivo']}% positivos ({row['total_menciones']} menciones)")

        self.guardar_csv(df_sentimientos, "reddit_sentimiento")

    def detectar_temas_emergentes(self):
        """Detects emerging topics mentioned in r/webdev posts."""
        self.logger.info("PREGUNTA 2: Detectando temas emergentes...")

        if self.df_posts is None or self.df_posts.empty:
            raise ETLValidationError("DataFrame de posts vacio, no se puede detectar temas")

        temas_clave = {
            "IA/Machine Learning": ["ai", "artificial intelligence", "machine learning", "ml", "chatgpt", "llm", "neural", "gpt", "openai"],
            "Cloud": ["cloud", "aws", "azure", "gcp", "google cloud", "kubernetes", "docker", "containerization"],
            "Web3/Blockchain": ["web3", "blockchain", "cryptocurrency", "crypto", "ethereum", "bitcoin", "nft", "smart contract"],
            "DevOps": ["devops", "ci/cd", "github actions", "gitlab", "jenkins", "deployment", "infrastructure"],
            "Microservicios": ["microservices", "microservice", "rest api", "graphql"],
            "Testing": ["testing", "unit test", "integration test", "e2e", "jest", "pytest"],
            "Performance": ["performance", "optimization", "caching", "cdn", "latency", "speed"],
            "Seguridad": ["security", "encryption", "authentication", "oauth", "jwt"],
            "TypeScript": ["typescript"],
            "Python": ["python", "django", "fastapi", "flask"]
        }

        menciones_temas = {tema: 0 for tema in temas_clave.keys()}

        for _, post in self.df_posts.iterrows():
            texto = f"{post['titulo']} {post['contenido']}".lower()

            for tema, keywords in temas_clave.items():
                for keyword in keywords:
                    if self._coincide_keyword(texto, keyword):
                        menciones_temas[tema] += 1
                        break

        self.df_temas = pd.DataFrame([
            {"tema": tema, "menciones": menciones_temas[tema]}
            for tema in menciones_temas.keys()
            if menciones_temas[tema] > 0
        ]).sort_values("menciones", ascending=False).reset_index(drop=True)

        self.logger.info("Temas Emergentes en r/webdev:")
        for i, row in self.df_temas.iterrows():
            self.logger.info(f"  {i+1}. {row['tema']}: {row['menciones']} menciones")

        self.guardar_csv(self.df_temas, "reddit_temas")

    def interseccion_tecnologias(self):
        """Compares technology rankings between GitHub and Reddit."""
        self.logger.info("PREGUNTA 3: Analizando interseccion GitHub vs Reddit...")

        if self.df_temas is None or self.df_temas.empty:
            raise ETLValidationError("DataFrame de temas vacio, no se puede analizar interseccion")

        try:
            df_repos = pd.read_csv(ARCHIVOS_SALIDA["github_repos"])
        except FileNotFoundError:
            self.logger.warning(f"No se encontro {ARCHIVOS_SALIDA['github_repos']}")
            self.logger.warning("Ejecuta primero github_etl.py")
            return

        github_langs = df_repos["language"].value_counts().head(5).reset_index()
        github_langs.columns = ["tecnologia", "frecuencia"]
        github_langs["ranking_github"] = range(1, len(github_langs) + 1)
        github_langs["tipo"] = "Lenguaje"

        frameworks_frontend = pd.DataFrame({
            "tecnologia": ["Angular", "React", "Vue 3"],
            "ranking_github": [1, 2, 3],
            "tipo": "Framework Frontend"
        })

        github_data = pd.concat([github_langs[["tecnologia", "ranking_github", "tipo"]],
                                 frameworks_frontend],
                                ignore_index=True)

        reddit_temas = self.df_temas.head(10).copy()
        reddit_temas["ranking_reddit"] = range(1, len(reddit_temas) + 1)
        reddit_temas = reddit_temas.rename(columns={"tema": "tecnologia"})

        coincidencias = []

        for _, row_gh in github_data.iterrows():
            gh_norm = normalize_for_match(row_gh["tecnologia"])
            encontrado = False

            for _, row_rd in reddit_temas.iterrows():
                rd_norm = normalize_for_match(row_rd["tecnologia"])

                if gh_norm == rd_norm or gh_norm in rd_norm or rd_norm in gh_norm:
                    coincidencias.append({
                        "tecnologia": row_gh["tecnologia"],
                        "tipo": row_gh["tipo"],
                        "ranking_github": row_gh["ranking_github"],
                        "ranking_reddit": row_rd["ranking_reddit"],
                        "diferencia": abs(row_gh["ranking_github"] - row_rd["ranking_reddit"])
                    })
                    encontrado = True
                    break

            if not encontrado:
                coincidencias.append({
                    "tecnologia": row_gh["tecnologia"],
                    "tipo": row_gh["tipo"],
                    "ranking_github": row_gh["ranking_github"],
                    "ranking_reddit": "No encontrado",
                    "diferencia": "-"
                })

        df_coincidencias = pd.DataFrame(coincidencias).reset_index(drop=True)

        self.logger.info("Tecnologias comparadas entre GitHub y Reddit:")
        for _, row in df_coincidencias.iterrows():
            if row["ranking_reddit"] != "No encontrado":
                self.logger.info(f"  {row['tecnologia']:20} ({row['tipo']:20}): GitHub #{row['ranking_github']} - Reddit #{row['ranking_reddit']} (dif: {row['diferencia']})")
            else:
                self.logger.info(f"  {row['tecnologia']:20} ({row['tipo']:20}): GitHub #{row['ranking_github']} - No menciona en Reddit")

        self.guardar_csv(df_coincidencias, "interseccion")


def main():
    """Entry point for the Reddit ETL pipeline."""
    etl = RedditETL()
    etl.ejecutar()


if __name__ == "__main__":
    main()
