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
import logging

from config.settings import (
    DATOS_DIR, ARCHIVOS_SALIDA, REDDIT_SUBREDDIT, REDDIT_LIMIT,
    REDDIT_HEADERS, LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR
)
from exceptions import ETLExtractionError, ETLValidationError
from validador import validar_dataframe

warnings.filterwarnings("ignore")

# Logger para este modulo
logger = logging.getLogger("reddit_etl")

# Descargar recursos NLTK si no estan
try:
    nltk.data.find('sentiment/vader_lexicon')
except LookupError:
    nltk.download('vader_lexicon')

try:
    nltk.data.find('corpora/stopwords')
except LookupError:
    nltk.download('stopwords')


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


def obtener_posts_reddit(subreddit_name=REDDIT_SUBREDDIT, limit=REDDIT_LIMIT):
    """Fetches posts from a subreddit using Reddit's public JSON API.

    Raises:
        ETLExtractionError: If no posts could be fetched.
    """
    logger.info(f"Obteniendo posts de r/{subreddit_name}...")

    posts_data = []
    url = f"https://www.reddit.com/r/{subreddit_name}/hot.json"

    after = None
    posts_obtenidos = 0

    try:
        while posts_obtenidos < limit:
            params = {
                "limit": 100,
                "after": after
            }

            logger.info(f"  Descargando posts {posts_obtenidos + 1}-{min(posts_obtenidos + 100, limit)}...")

            try:
                response = requests.get(url, headers=REDDIT_HEADERS, params=params, timeout=10)
            except requests.exceptions.RequestException as e:
                logger.error(f"  Error de red: {e}")
                break

            if response.status_code != 200:
                logger.error(f"  Error: {response.status_code}")
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

            time.sleep(2)

        logger.info(f"Obtenidos {len(posts_data)} posts")

    except Exception as e:
        logger.error(f"Error obteniendo posts: {e}")

    if not posts_data:
        raise ETLExtractionError(f"No se pudo extraer posts de r/{subreddit_name}")

    return pd.DataFrame(posts_data)


def extraer_posts_reddit(subreddit_name=REDDIT_SUBREDDIT, limit=REDDIT_LIMIT):
    """Wrapper for obtener_posts_reddit for backward compatibility."""
    return obtener_posts_reddit(subreddit_name, limit)


def analizar_sentimiento_frameworks(df_posts):
    """Analyzes sentiment for backend frameworks mentioned in posts.

    Raises:
        ETLValidationError: If the input DataFrame is empty.
    """
    logger.info("PREGUNTA 1: Analizando sentimiento de frameworks backend...")

    if df_posts.empty:
        raise ETLValidationError("DataFrame de posts vacio, no se puede analizar sentimiento")

    sia = SentimentIntensityAnalyzer()

    frameworks_backend = {
        "Django": ["django", "python web"],
        "FastAPI": ["fastapi"],
        "Express": ["express", "node.js", "nodejs"],
        "Spring": ["spring", "springboot", "java"],
        "Laravel": ["laravel", "php"]
    }

    sentimientos_framework = {}

    todos_textos = []
    for idx, post in df_posts.iterrows():
        todos_textos.append({
            "texto": f"{post['titulo']} {post['contenido']}",
            "tipo": "post"
        })

    logger.info("Analizando sentimientos...")

    for framework, keywords in frameworks_backend.items():
        sentimientos = {"positivo": 0, "neutro": 0, "negativo": 0}
        total_menciones = 0

        for item in todos_textos:
            texto = item["texto"].lower()

            if any(keyword in texto for keyword in keywords):
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

    logger.info("Top Frameworks Backend por Sentimiento Positivo:")
    for i, row in df_sentimientos.iterrows():
        logger.info(f"  {i+1}. {row['framework']}: {row['% positivo']}% positivos ({row['total_menciones']} menciones)")

    validar_dataframe(df_sentimientos, "reddit_sentimiento")
    df_sentimientos.to_csv(ARCHIVOS_SALIDA["reddit_sentimiento"], index=False, encoding="utf-8")
    logger.info(f"Guardado en: {ARCHIVOS_SALIDA['reddit_sentimiento']}")

    return df_sentimientos


def detectar_temas_emergentes(df_posts):
    """Detects emerging topics mentioned in r/webdev posts.

    Raises:
        ETLValidationError: If the input DataFrame is empty.
    """
    logger.info("PREGUNTA 2: Detectando temas emergentes...")

    if df_posts.empty:
        raise ETLValidationError("DataFrame de posts vacio, no se puede detectar temas")

    temas_clave = {
        "IA/Machine Learning": ["ai", "artificial intelligence", "machine learning", "ml", "chatgpt", "llm", "neural", "gpt", "openai"],
        "Cloud": ["cloud", "aws", "azure", "gcp", "google cloud", "kubernetes", "docker", "containerization"],
        "Web3/Blockchain": ["web3", "blockchain", "cryptocurrency", "crypto", "ethereum", "bitcoin", "nft", "smart contract"],
        "DevOps": ["devops", "ci/cd", "github actions", "gitlab", "jenkins", "deployment", "infrastructure"],
        "Microservicios": ["microservices", "microservice", "api", "rest api", "graphql"],
        "Testing": ["testing", "unit test", "integration test", "e2e", "jest", "pytest"],
        "Performance": ["performance", "optimization", "caching", "cdn", "latency", "speed"],
        "Seguridad": ["security", "security", "encryption", "authentication", "oauth", "jwt"],
        "TypeScript": ["typescript", "typescript"],
        "Python": ["python", "django", "fastapi", "flask"]
    }

    menciones_temas = {tema: 0 for tema in temas_clave.keys()}

    for idx, post in df_posts.iterrows():
        texto = f"{post['titulo']} {post['contenido']}".lower()

        for tema, keywords in temas_clave.items():
            for keyword in keywords:
                if keyword in texto:
                    menciones_temas[tema] += 1
                    break

    df_temas = pd.DataFrame([
        {"tema": tema, "menciones": menciones_temas[tema]}
        for tema in menciones_temas.keys()
        if menciones_temas[tema] > 0
    ]).sort_values("menciones", ascending=False).reset_index(drop=True)

    logger.info("Temas Emergentes en r/webdev:")
    for i, row in df_temas.iterrows():
        logger.info(f"  {i+1}. {row['tema']}: {row['menciones']} menciones")

    validar_dataframe(df_temas, "reddit_temas")
    df_temas.to_csv(ARCHIVOS_SALIDA["reddit_temas"], index=False, encoding="utf-8")
    logger.info(f"Guardado en: {ARCHIVOS_SALIDA['reddit_temas']}")

    return df_temas


def interseccion_tecnologias(df_repos, df_temas):
    """Compares technology rankings between GitHub and Reddit.

    Raises:
        ETLValidationError: If either input DataFrame is empty.
    """
    logger.info("PREGUNTA 3: Analizando interseccion GitHub vs Reddit...")

    if df_repos.empty or df_temas.empty:
        raise ETLValidationError("DataFrames vacios, no se puede analizar interseccion")

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

    reddit_temas = df_temas.head(10).copy()
    reddit_temas["ranking_reddit"] = range(1, len(reddit_temas) + 1)
    reddit_temas = reddit_temas.rename(columns={"tema": "tecnologia"})

    mapeo_normalizacion = {
        "python": ["python"],
        "javascript": ["javascript", "js", "web"],
        "typescript": ["typescript", "ts"],
        "go": ["golang", "go"],
        "rust": ["rust"],
        "react": ["react"],
        "angular": ["angular"],
        "vue 3": ["vue"],
        "java": ["java", "spring"],
        "c#": ["c#", "csharp", "dotnet", "asp.net"]
    }

    def normalizar_nombre(nombre):
        """Normalizes technology names for comparison."""
        nombre_lower = nombre.lower()
        for clave, valores in mapeo_normalizacion.items():
            if nombre_lower == clave or any(v in nombre_lower for v in valores):
                return clave
        return nombre_lower

    coincidencias = []

    for idx_gh, row_gh in github_data.iterrows():
        gh_norm = normalizar_nombre(row_gh["tecnologia"])
        encontrado = False

        for idx_rd, row_rd in reddit_temas.iterrows():
            rd_norm = normalizar_nombre(row_rd["tecnologia"])

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

    logger.info("Tecnologias comparadas entre GitHub y Reddit:")
    for i, row in df_coincidencias.iterrows():
        if row["ranking_reddit"] != "No encontrado":
            logger.info(f"  {row['tecnologia']:20} ({row['tipo']:20}): GitHub #{row['ranking_github']} - Reddit #{row['ranking_reddit']} (dif: {row['diferencia']})")
        else:
            logger.info(f"  {row['tecnologia']:20} ({row['tipo']:20}): GitHub #{row['ranking_github']} - No menciona en Reddit")

    validar_dataframe(df_coincidencias, "interseccion")
    df_coincidencias.to_csv(ARCHIVOS_SALIDA["interseccion"], index=False, encoding="utf-8")
    logger.info(f"Guardado en: {ARCHIVOS_SALIDA['interseccion']}")

    return df_coincidencias


def main():
    """Main function that runs the complete Reddit ETL pipeline.
    Each step is independent so one failure does not stop the others.
    """
    configurar_logging()

    logger.info("Reddit ETL - Technology Trend Analysis Platform")
    logger.info(f"Directorio de datos: {DATOS_DIR}")

    # Extraccion de posts
    try:
        df_posts = extraer_posts_reddit()
    except ETLExtractionError as e:
        logger.error(f"Extraccion de posts fallida: {e}")
        return
    except Exception as e:
        logger.error(f"Error inesperado en extraccion: {e}")
        return

    # Analisis de sentimiento
    df_temas = None
    try:
        analizar_sentimiento_frameworks(df_posts)
    except (ETLValidationError, ETLExtractionError) as e:
        logger.error(f"Analisis de sentimiento fallido: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en sentimiento: {e}")

    # Deteccion de temas
    try:
        df_temas = detectar_temas_emergentes(df_posts)
    except (ETLValidationError, ETLExtractionError) as e:
        logger.error(f"Deteccion de temas fallida: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en temas: {e}")

    # Interseccion GitHub vs Reddit
    if df_temas is not None:
        try:
            df_repos = pd.read_csv(ARCHIVOS_SALIDA["github_repos"])
            interseccion_tecnologias(df_repos, df_temas)
        except FileNotFoundError:
            logger.warning(f"No se encontro {ARCHIVOS_SALIDA['github_repos']}")
            logger.warning("Ejecuta primero github_etl.py")
        except (ETLValidationError, ETLExtractionError) as e:
            logger.error(f"Analisis de interseccion fallido: {e}")
        except Exception as e:
            logger.error(f"Error inesperado en interseccion: {e}")

    logger.info("ETL Reddit completado")


if __name__ == "__main__":
    main()