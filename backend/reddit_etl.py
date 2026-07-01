"""
Reddit ETL - Technology Trend Analysis Platform

Extrae datos de subreddit r/webdev para analizar tendencias tecnologicas:
sentimiento de frameworks backend, temas emergentes y comparacion
cross-platform con datos de GitHub.

Autor: Mateo Mayorga
"""
import pandas as pd
from datetime import datetime
import os
import requests
import warnings
import time
import re
import html
from defusedxml import ElementTree as ET
from vaderSentiment.vaderSentiment import SentimentIntensityAnalyzer

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


def _env_float(name, default):
    """Read a positive float from the environment with a safe fallback."""
    try:
        value = float(os.getenv(name, str(default)))
    except (TypeError, ValueError):
        return default
    return value if value >= 0 else default


def _env_int(name, default):
    """Read a positive int from the environment with a safe fallback."""
    try:
        value = int(os.getenv(name, str(default)))
    except (TypeError, ValueError):
        return default
    return value if value > 0 else default


def _split_subreddit_targets(subreddit_name):
    """Return one or more subreddit targets from env/config."""
    configured = os.getenv("REDDIT_SUBREDDIT_LIST") or subreddit_name
    targets = re.split(r"[,+\s]+", configured)
    seen = set()
    unique_targets = []
    for target in targets:
        clean_target = target.strip().strip("/")
        if clean_target.lower().startswith("r/"):
            clean_target = clean_target[2:]
        if not clean_target:
            continue
        key = clean_target.lower()
        if key in seen:
            continue
        seen.add(key)
        unique_targets.append(clean_target)
    return unique_targets or [subreddit_name]


class RedditETL(BaseETL):
    """Extractor ETL para datos de posts de Reddit."""

    def __init__(self):
        super().__init__("reddit")
        self.df_posts = None
        self.df_temas = None
        self.access_token = None
        self.api_base = "https://www.reddit.com"  # fallback: API publica
        self.headers = dict(REDDIT_HEADERS)

    @staticmethod
    def _coincide_keyword(texto, keyword):
        """Verifica presencia de keyword usando regex segura por limites."""
        kw = keyword.strip().lower()
        if not kw:
            return False

        if re.fullmatch(r"[a-z0-9_]+", kw):
            patron = rf"(?<![a-z0-9_]){re.escape(kw)}(?![a-z0-9_])"
        else:
            patron = rf"(?<!\w){re.escape(kw)}(?!\w)"
        return re.search(patron, texto, flags=re.IGNORECASE) is not None

    @staticmethod
    def _html_to_text(value):
        """Convierte contenido HTML básico de RSS a texto plano."""
        if not value:
            return ""
        without_tags = re.sub(r"<[^>]+>", " ", value)
        without_comments = re.sub(r"<!--.*?-->", " ", without_tags, flags=re.DOTALL)
        normalized = html.unescape(without_comments)
        return re.sub(r"\s+", " ", normalized).strip()

    @staticmethod
    def _parse_atom_datetime(value):
        """Parsea fechas Atom/RSS en formato ISO; retorna epoch si falla."""
        if not value:
            return datetime.fromtimestamp(0)
        try:
            return datetime.fromisoformat(value.replace("Z", "+00:00")).replace(tzinfo=None)
        except ValueError:
            return datetime.fromtimestamp(0)

    def _obtener_token_oauth(self):
        """Obtiene token bearer OAuth2 de Reddit usando client credentials.

        Si REDDIT_CLIENT_ID y REDDIT_CLIENT_SECRET existen, cambia
        al endpoint autenticado oauth.reddit.com que funciona desde
        IPs de datacenter (GitHub Actions).
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
                        "Token vacio en respuesta OAuth; usando API publica"
                    )
            else:
                self.logger.warning(
                    "OAuth fallo (%d) — usando API publica", resp.status_code
                )
        except requests.exceptions.RequestException as e:
            self.logger.warning("Error en OAuth: %s — usando API publica", e)

    def definir_pasos(self):
        """Define los pasos ETL de Reddit."""
        return [
            ("Autenticacion OAuth", self._obtener_token_oauth),
            ("Extraccion de posts", self.extraer_posts),
            ("Sentimiento de frameworks", self.analizar_sentimiento_frameworks),
            ("Temas emergentes", self.detectar_temas_emergentes),
            ("Interseccion GitHub-Reddit", self.interseccion_tecnologias),
        ]

    def validar_configuracion(self):
        """Valida consistencia de credenciales de Reddit antes de ejecutar.

        - Si faltan ambas: permitido (modo degradado API publica).
        - Si solo hay una: configuracion invalida (critical).
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

    def _extraer_posts_json(self, subreddit_name, limit):
        """Extrae posts usando JSON API/OAuth de Reddit."""
        posts_data = []
        url = f"{self.api_base}/r/{subreddit_name}/hot.json"

        after = None
        posts_obtenidos = 0

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

        return posts_data

    def _extraer_posts_rss(self, subreddit_name, limit):
        """Extrae posts publicos desde feeds Atom/RSS de Reddit como fallback."""
        feed_urls = [
            f"https://www.reddit.com/r/{subreddit_name}/.rss?limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/new/.rss?limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/hot/.rss?limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/rising/.rss?limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/top/.rss?t=day&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/top/.rss?t=week&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/top/.rss?t=month&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/top/.rss?t=year&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/top/.rss?t=all&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/controversial/.rss?t=day&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/controversial/.rss?t=week&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/controversial/.rss?t=month&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/controversial/.rss?t=year&limit=100",
            f"https://www.reddit.com/r/{subreddit_name}/controversial/.rss?t=all&limit=100",
        ]
        namespace = {"atom": "http://www.w3.org/2005/Atom"}
        posts_by_id = {}
        max_attempts = _env_int("REDDIT_RSS_MAX_ATTEMPTS", 3)
        feed_delay_seconds = _env_float(
            "REDDIT_RSS_FEED_DELAY_SECONDS",
            REQUEST_PAGE_DELAY_SECONDS,
        )
        rate_limit_backoff_seconds = _env_float(
            "REDDIT_RSS_429_BACKOFF_SECONDS",
            90.0,
        )
        rss_headers = {
            "User-Agent": REDDIT_USER_AGENT,
            "Accept": "application/atom+xml,application/xml;q=0.9,*/*;q=0.8",
        }

        self.logger.info("Intentando fallback RSS publico de Reddit...")

        for feed_index, feed_url in enumerate(feed_urls, start=1):
            if len(posts_by_id) >= limit:
                break

            if feed_index > 1 and feed_delay_seconds > 0:
                self.logger.info(
                    "  Esperando %.1fs antes del siguiente feed RSS...",
                    feed_delay_seconds,
                )
                time.sleep(feed_delay_seconds)

            response = None
            for attempt in range(1, max_attempts + 1):
                self.logger.info(
                    "  Descargando RSS (%d/%d intento %d/%d): %s",
                    feed_index,
                    len(feed_urls),
                    attempt,
                    max_attempts,
                    feed_url,
                )
                try:
                    response = requests.get(
                        feed_url,
                        headers=rss_headers,
                        timeout=REQUEST_TIMEOUT_SECONDS,
                    )
                except requests.exceptions.RequestException as e:
                    self.logger.error("  Error RSS: %s", e)
                    time.sleep(HTTP_RETRY_BACKOFF_SECONDS * attempt)
                    continue

                if response.status_code == 200:
                    break

                if response.status_code == 429 and attempt < max_attempts:
                    retry_after = response.headers.get("Retry-After")
                    try:
                        wait_seconds = float(retry_after) if retry_after else rate_limit_backoff_seconds
                    except ValueError:
                        wait_seconds = rate_limit_backoff_seconds
                    self.logger.warning(
                        "  Reddit RSS rate limit (429). Esperando %.1fs antes de reintentar...",
                        wait_seconds,
                    )
                    time.sleep(wait_seconds)
                    continue

                self.logger.error("  Error RSS: %s", response.status_code)
                break

            if response is None or response.status_code != 200:
                continue

            try:
                root = ET.fromstring(response.text)
            except ET.ParseError as e:
                self.logger.error("  RSS invalido: %s", e)
                continue

            for entry in root.findall("atom:entry", namespace):
                if len(posts_by_id) >= limit:
                    break

                post_id = (entry.findtext("atom:id", default="", namespaces=namespace) or "").strip()
                title = (entry.findtext("atom:title", default="", namespaces=namespace) or "").strip()
                content_html = entry.findtext("atom:content", default="", namespaces=namespace) or ""
                content = self._html_to_text(content_html)
                published = (
                    entry.findtext("atom:published", default="", namespaces=namespace)
                    or entry.findtext("atom:updated", default="", namespaces=namespace)
                    or ""
                )
                author_name = "RSS"
                author = entry.find("atom:author", namespace)
                if author is not None:
                    author_name = (
                        author.findtext("atom:name", default="", namespaces=namespace)
                        or "RSS"
                    ).strip()

                if not post_id:
                    link = entry.find("atom:link", namespace)
                    post_id = link.attrib.get("href", title) if link is not None else title

                if not title and not content:
                    continue

                posts_by_id[post_id] = {
                    "post_id": post_id.replace("t3_", ""),
                    "titulo": title,
                    "contenido": content,
                    "upvotes": 0,
                    "comentarios": 0,
                    "created_at": self._parse_atom_datetime(published),
                    "autor": author_name or "RSS",
                }

            time.sleep(REQUEST_PAGE_DELAY_SECONDS)

        posts_data = list(posts_by_id.values())[:limit]
        self.logger.info("Fallback RSS obtuvo %d posts", len(posts_data))
        return posts_data

    def extraer_posts(self, subreddit_name=REDDIT_SUBREDDIT, limit=REDDIT_LIMIT):
        """Extrae posts de un subreddit usando JSON API y RSS fallback.

        Raises:
            ETLExtractionError: Si no se pudieron extraer posts.
        """
        targets = _split_subreddit_targets(subreddit_name)
        posts_by_id = {}

        if len(targets) > 1:
            per_target_limit = _env_int(
                "REDDIT_PER_SUBREDDIT_LIMIT",
                max(100, min(500, limit)),
            )
            subreddit_delay_seconds = _env_float(
                "REDDIT_SUBREDDIT_DELAY_SECONDS",
                REQUEST_PAGE_DELAY_SECONDS,
            )
            self.logger.info(
                "Obteniendo hasta %d posts desde %d subreddits individuales...",
                limit,
                len(targets),
            )

            for target_index, target in enumerate(targets, start=1):
                if len(posts_by_id) >= limit:
                    break
                if target_index > 1 and subreddit_delay_seconds > 0:
                    self.logger.info(
                        "Esperando %.1fs antes del siguiente subreddit...",
                        subreddit_delay_seconds,
                    )
                    time.sleep(subreddit_delay_seconds)

                remaining = limit - len(posts_by_id)
                target_limit = min(per_target_limit, remaining)
                self.logger.info(
                    "Obteniendo posts de r/%s (%d/%d, limite %d)...",
                    target,
                    target_index,
                    len(targets),
                    target_limit,
                )

                target_posts = self._extraer_posts_json(target, target_limit)
                if not target_posts:
                    target_posts = self._extraer_posts_rss(target, target_limit)

                for post in target_posts:
                    post_id = str(post.get("post_id") or "").strip()
                    if not post_id:
                        post_id = f"{target}:{post.get('titulo', '')}"
                    posts_by_id.setdefault(post_id, post)

                self.logger.info(
                    "Acumulado Reddit: %d posts unicos",
                    len(posts_by_id),
                )

            posts_data = list(posts_by_id.values())[:limit]
        else:
            subreddit_name = targets[0]
            self.logger.info(f"Obteniendo posts de r/{subreddit_name}...")

            posts_data = self._extraer_posts_json(subreddit_name, limit)

            if not posts_data:
                posts_data = self._extraer_posts_rss(subreddit_name, limit)

        self.logger.info(f"Obtenidos {len(posts_data)} posts")

        if not posts_data:
            # Intentar cargar datos previos si existen
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
        """Analiza sentimiento para frameworks backend mencionados en posts."""
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
        """Detecta temas emergentes mencionados en posts de r/webdev."""
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
        """Compara ranking de tecnologias entre GitHub y Reddit."""
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

        frameworks_frontend = None
        try:
            df_frameworks = pd.read_csv(ARCHIVOS_SALIDA["github_commits"])
            required = {"framework", "ranking"}
            if required.issubset(df_frameworks.columns) and not df_frameworks.empty:
                frameworks_frontend = (
                    df_frameworks[["framework", "ranking"]]
                    .rename(
                        columns={
                            "framework": "tecnologia",
                            "ranking": "ranking_github",
                        }
                    )
                    .sort_values("ranking_github", ascending=True)
                    .head(5)
                )
                frameworks_frontend["tipo"] = "Framework Frontend"
        except FileNotFoundError:
            self.logger.warning(
                "No se encontro %s para construir framework intersection, usando fallback.",
                ARCHIVOS_SALIDA["github_commits"],
            )

        if frameworks_frontend is None or frameworks_frontend.empty:
            frameworks_frontend = pd.DataFrame({
                "tecnologia": ["React", "Angular", "Vue 3", "Svelte", "Next.js"],
                "ranking_github": [1, 2, 3, 4, 5],
                "tipo": "Framework Frontend",
            })

        github_data = pd.concat([github_langs[["tecnologia", "ranking_github", "tipo"]],
                                 frameworks_frontend],
                                ignore_index=True)

        reddit_temas = (
            self.df_temas.copy()
            .sort_values(["menciones", "tema"], ascending=[False, True])
            .head(10)
            .reset_index(drop=True)
        )
        reddit_temas["ranking_reddit"] = range(1, len(reddit_temas) + 1)
        reddit_temas = reddit_temas.rename(columns={"tema": "tecnologia"})

        coincidencias = []
        used_reddit_indexes = set()

        for _, row_gh in github_data.iterrows():
            gh_norm = normalize_for_match(row_gh["tecnologia"])
            encontrado = None
            found_score = 999

            for rd_idx, row_rd in reddit_temas.iterrows():
                if rd_idx in used_reddit_indexes:
                    continue
                rd_norm = normalize_for_match(row_rd["tecnologia"])
                is_exact = gh_norm == rd_norm
                is_contains = (
                    gh_norm and rd_norm and (gh_norm in rd_norm or rd_norm in gh_norm)
                )
                if not is_exact and not is_contains:
                    continue
                match_score = 0 if is_exact else 1
                if encontrado is None or match_score < found_score:
                    encontrado = (rd_idx, row_rd)
                    found_score = match_score
                    if match_score == 0:
                        break

            if encontrado is None:
                coincidencias.append({
                    "tecnologia": row_gh["tecnologia"],
                    "tipo": row_gh["tipo"],
                    "ranking_github": row_gh["ranking_github"],
                    "ranking_reddit": "No encontrado",
                    "diferencia": "-"
                })
            else:
                rd_idx, row_rd = encontrado
                used_reddit_indexes.add(rd_idx)
                coincidencias.append({
                    "tecnologia": row_gh["tecnologia"],
                    "tipo": row_gh["tipo"],
                    "ranking_github": row_gh["ranking_github"],
                    "ranking_reddit": row_rd["ranking_reddit"],
                    "diferencia": abs(row_gh["ranking_github"] - row_rd["ranking_reddit"])
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
    """Punto de entrada para el pipeline ETL de Reddit."""
    etl = RedditETL()
    etl.ejecutar()


if __name__ == "__main__":
    main()
