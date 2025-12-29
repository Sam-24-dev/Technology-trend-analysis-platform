"""
Reddit Scraper - Avance 1
Extrae datos del subreddit r/webdev para análisis de tendencias tecnológicas 2025

Autor: Mateo Mayorga
Proyecto: Technology Trend Analysis Platform
"""
import os
import pandas as pd
from datetime import datetime
import requests
import nltk
from nltk.sentiment import SentimentIntensityAnalyzer
import warnings
import time

warnings.filterwarnings("ignore")

# Ruta de la carpeta datos
DATOS_DIR = os.path.join(os.path.dirname(__file__), "..", "datos")

# Descargar recursos necesarios de NLTK
try:
    nltk.data.find('sentiment/vader_lexicon')
except LookupError:
    nltk.download('vader_lexicon')

try:
    nltk.data.find('corpora/stopwords')
except LookupError:
    nltk.download('stopwords')


def obtener_posts_reddit(subreddit_name="webdev", limit=500):
    """Obtiene posts del subreddit usando la API pública JSON de Reddit"""
    print(f"Obteniendo posts de r/{subreddit_name} (sin autenticación)...")
    
    posts_data = []
    url = f"https://www.reddit.com/r/{subreddit_name}/hot.json"
    
    # Headers para que Reddit nos reconozca como cliente legítimo
    headers = {
        "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
    }
    
    after = None
    posts_obtenidos = 0
    
    try:
        while posts_obtenidos < limit:
            params = {
                "limit": 100,  # Reddit devuelve máximo 100 por página
                "after": after
            }
            
            print(f"  Descargando posts {posts_obtenidos + 1}-{min(posts_obtenidos + 100, limit)}...")
            
            response = requests.get(url, headers=headers, params=params, timeout=10)
            
            if response.status_code != 200:
                print(f"  Error: {response.status_code}")
                break
            
            data = response.json()
            children = data.get("data", {}).get("children", [])
            
            if not children:
                break
            
            for post in children:
                if posts_obtenidos >= limit:
                    break
                
                post_data = post.get("data", {})
                
                # Solo procesar posts de texto (self posts)
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
            
            # Obtener el 'after' para la siguiente página
            after = data.get("data", {}).get("after")
            
            if not after:
                break
            
            # Esperar un poco para no sobrecargar el servidor
            time.sleep(2)
        
        print(f"Obtenidos {len(posts_data)} posts exitosamente")
        
    except Exception as e:
        print(f"Error obteniendo posts: {e}")
    
    return pd.DataFrame(posts_data)


def extraer_posts_reddit(subreddit_name="webdev", limit=500):
    """Extrae posts del subreddit especificado usando API pública JSON"""
    return obtener_posts_reddit(subreddit_name, limit)


def analizar_sentimiento_frameworks(df_posts):
    """Pregunta 1: Analiza sentimiento sobre frameworks backend"""
    print("\nPREGUNTA 1: Analizando sentimiento de frameworks backend...")
    
    sia = SentimentIntensityAnalyzer()
    
    # Frameworks backend a analizar
    frameworks_backend = {
        "Django": ["django", "python web"],
        "FastAPI": ["fastapi"],
        "Express": ["express", "node.js", "nodejs"],
        "Spring": ["spring", "springboot", "java"],
        "Laravel": ["laravel", "php"]
    }
    
    sentimientos_framework = {}
    
    # Procesar todos los posts y comentarios
    todos_textos = []
    
    for idx, post in df_posts.iterrows():
        todos_textos.append({
            "texto": f"{post['titulo']} {post['contenido']}",
            "tipo": "post"
        })
    
    print("Analizando sentimientos...")
    
    for framework, keywords in frameworks_backend.items():
        sentimientos = {"positivo": 0, "neutro": 0, "negativo": 0}
        total_menciones = 0
        
        for item in todos_textos:
            texto = item["texto"].lower()
            
            # Verificar si alguna palabra clave del framework esta en el texto
            if any(keyword in texto for keyword in keywords):
                total_menciones += 1
                
                # Analizar sentimiento
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
    
    # Crear DataFrame y ordenar por porcentaje positivo
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
    
    print("\nTop Frameworks Backend por Sentimiento Positivo:")
    print("-" * 80)
    for i, row in df_sentimientos.iterrows():
        print(f"  {i+1}. {row['framework']}: {row['% positivo']}% positivos ({row['total_menciones']} menciones)")
    
    csv_path = os.path.join(DATOS_DIR, "reddit_sentimiento_frameworks.csv")
    df_sentimientos.to_csv(csv_path, index=False, encoding="utf-8")
    print(f"Guardado en: {csv_path}")
    
    return df_sentimientos


def detectar_temas_emergentes(df_posts):
    """Pregunta 2: Detecta temas emergentes mencionados en r/webdev"""
    print("\nPREGUNTA 2: Detectando temas emergentes...")
    
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
    
    # Contar menciones en todos los posts
    for idx, post in df_posts.iterrows():
        texto = f"{post['titulo']} {post['contenido']}".lower()
        
        for tema, keywords in temas_clave.items():
            for keyword in keywords:
                if keyword in texto:
                    menciones_temas[tema] += 1
                    break  # Contar solo una vez por tema por post
    
    # Crear DataFrame y ordenar
    df_temas = pd.DataFrame([
        {"tema": tema, "menciones": menciones_temas[tema]}
        for tema in menciones_temas.keys()
        if menciones_temas[tema] > 0
    ]).sort_values("menciones", ascending=False).reset_index(drop=True)
    
    print("\nTemas Emergentes en r/webdev:")
    print("-" * 50)
    for i, row in df_temas.iterrows():
        print(f"  {i+1}. {row['tema']}: {row['menciones']} menciones")
    
    csv_path = os.path.join(DATOS_DIR, "reddit_temas_emergentes.csv")
    df_temas.to_csv(csv_path, index=False, encoding="utf-8")
    print(f"Guardado en: {csv_path}")
    
    return df_temas


def interseccion_tecnologias(df_repos, df_temas):
    """Pregunta 3: Interseccion entre tecnologias populares en GitHub vs Reddit"""
    print("\nPREGUNTA 3: Analizando interseccion GitHub vs Reddit...")
    
    # Obtener top 5 lenguajes de GitHub
    github_langs = df_repos["language"].value_counts().head(5).reset_index()
    github_langs.columns = ["tecnologia", "frecuencia"]
    github_langs["ranking_github"] = range(1, len(github_langs) + 1)
    github_langs["tipo"] = "Lenguaje"
    
    # Frameworks frontend de GitHub (desde frameworks_commits.csv)
    frameworks_frontend = pd.DataFrame({
        "tecnologia": ["Angular", "React", "Vue 3"],
        "ranking_github": [1, 2, 3],  # Basado en commits_2025
        "tipo": "Framework Frontend"
    })
    
    # Combinar lenguajes + frameworks
    github_data = pd.concat([github_langs[["tecnologia", "ranking_github", "tipo"]], 
                             frameworks_frontend], 
                            ignore_index=True)
    
    # Temas de Reddit (top 10)
    reddit_temas = df_temas.head(10).copy()
    reddit_temas["ranking_reddit"] = range(1, len(reddit_temas) + 1)
    reddit_temas = reddit_temas.rename(columns={"tema": "tecnologia"})
    
    # Mapeo de normalización para búsqueda
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
        """Normaliza el nombre para comparación"""
        nombre_lower = nombre.lower()
        for clave, valores in mapeo_normalizacion.items():
            if nombre_lower == clave or any(v in nombre_lower for v in valores):
                return clave
        return nombre_lower
    
    # Buscar coincidencias
    coincidencias = []
    
    for idx_gh, row_gh in github_data.iterrows():
        gh_norm = normalizar_nombre(row_gh["tecnologia"])
        encontrado = False
        
        for idx_rd, row_rd in reddit_temas.iterrows():
            rd_norm = normalizar_nombre(row_rd["tecnologia"])
            
            # Comparar nombres normalizados
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
        
        # Si no se encontró coincidencia en Reddit, registrar como No encontrado
        if not encontrado:
            coincidencias.append({
                "tecnologia": row_gh["tecnologia"],
                "tipo": row_gh["tipo"],
                "ranking_github": row_gh["ranking_github"],
                "ranking_reddit": "No encontrado",
                "diferencia": "-"
            })
    
    df_coincidencias = pd.DataFrame(coincidencias).reset_index(drop=True)
    
    print("\nTecnologias comparadas entre GitHub y Reddit:")
    print("-" * 80)
    for i, row in df_coincidencias.iterrows():
        if row["ranking_reddit"] != "No encontrado":
            print(f"  {row['tecnologia']:20} ({row['tipo']:20}): GitHub #{row['ranking_github']} - Reddit #{row['ranking_reddit']} (dif: {row['diferencia']})")
        else:
            print(f"  {row['tecnologia']:20} ({row['tipo']:20}): GitHub #{row['ranking_github']} - No menciona en Reddit")
    
    csv_path = os.path.join(DATOS_DIR, "interseccion_github_reddit.csv")
    df_coincidencias.to_csv(csv_path, index=False, encoding="utf-8")
    print(f"\nGuardado en: {csv_path}")
    
    return df_coincidencias


def main():
    """Funcion principal para ejecutar el scraper de Reddit"""
    print("=" * 60)
    print("REDDIT SCRAPER - AVANCE 1")
    print("Autor: Mateo Mayorga")
    print("=" * 60)
    
    # Crear carpeta datos si no existe (relativa al directorio raíz del proyecto)
    os.makedirs(DATOS_DIR, exist_ok=True)
    print(f"\nDirectorio de datos: {DATOS_DIR}")
    
    # Obtener posts sin necesidad de credenciales
    df_posts = extraer_posts_reddit("webdev", limit=500)
    
    if not df_posts.empty:
        df_sentimientos = analizar_sentimiento_frameworks(df_posts)
        df_temas = detectar_temas_emergentes(df_posts)
        
        # Para la pregunta 3, necesitamos cargar los datos de GitHub
        try:
            repos_csv_path = os.path.join(DATOS_DIR, "repos_2025_raw.csv")
            df_repos = pd.read_csv(repos_csv_path)
            df_coincidencias = interseccion_tecnologias(df_repos, df_temas)
        except FileNotFoundError:
            print(f"\nADVERTENCIA: No se encontro {repos_csv_path}")
            print("Asegúrate de ejecutar primero el scraper de GitHub (github_scraper.py)")
        
        print("\n" + "=" * 60)
        print("SCRAPING DE REDDIT COMPLETADO")
        print("=" * 60)
        print("\nArchivos generados en carpeta 'datos/':")
        print("  1. reddit_sentimiento_frameworks.csv (Pregunta 1)")
        print("  2. reddit_temas_emergentes.csv (Pregunta 2)")
        print("  3. interseccion_github_reddit.csv (Pregunta 3)")
    else:
        print("No se pudieron extraer posts de Reddit")


if __name__ == "__main__":
    main()