"""
GitHub Scraper - Avance 1
Extrae datos de GitHub API para análisis de tendencias tecnológicas 2025

Autor: Samir Caizapasto
Proyecto: Technology Trend Analysis Platform
"""
import requests
import pandas as pd
from datetime import datetime
import time
import os
import re

from config import GITHUB_TOKEN, GITHUB_API_BASE, HEADERS, MAX_REPOS, PER_PAGE, FRAMEWORK_REPOS


def verificar_conexion():
    """Verifica la conexión con GitHub API"""
    print("Verificando conexion con GitHub API...")
    
    response = requests.get(f"{GITHUB_API_BASE}/user", headers=HEADERS, timeout=10)
    
    if response.status_code == 200:
        user = response.json()
        print(f"Conectado como: {user.get('login', 'Usuario')}")
        remaining = response.headers.get('X-RateLimit-Remaining', 'N/A')
        limit = response.headers.get('X-RateLimit-Limit', 'N/A')
        print(f"Rate Limit: {remaining}/{limit} requests disponibles")
        return True
    else:
        print(f"Error de conexion: {response.status_code}")
        return False


def esperar_rate_limit(response):
    """Maneja el rate limit de la API"""
    if response.status_code == 403:
        reset_time = int(response.headers.get('X-RateLimit-Reset', 0))
        if reset_time:
            wait_seconds = reset_time - int(time.time()) + 5
            if wait_seconds > 0 and wait_seconds < 300:
                print(f"Rate limit alcanzado. Esperando {wait_seconds} segundos...")
                time.sleep(wait_seconds)
                return True
    return False


def extraer_repos_2025(max_repos=MAX_REPOS):
    """Extrae los repositorios mas populares creados en 2025"""
    print(f"\nExtrayendo top {max_repos} repos de 2025...")
    
    repos_data = []
    page = 1
    total_pages = max_repos // PER_PAGE
    max_retries = 3
    
    while len(repos_data) < max_repos:
        print(f"  Pagina {page}/{total_pages}...")
        
        params = {
            "q": "created:2025-01-01..2025-12-31",
            "sort": "stars",
            "order": "desc",
            "per_page": PER_PAGE,
            "page": page
        }
        
        for retry in range(max_retries):
            response = requests.get(
                f"{GITHUB_API_BASE}/search/repositories",
                headers=HEADERS,
                params=params,
                timeout=10
            )
            
            if response.status_code == 200:
                break
            elif response.status_code == 403:
                if esperar_rate_limit(response):
                    continue
                else:
                    print(f"  Error 403, reintentando ({retry+1}/{max_retries})...")
                    time.sleep(10)
            else:
                print(f"Error en pagina {page}: {response.status_code}")
                break
        
        if response.status_code != 200:
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
    
    print(f"Extraidos {len(repos_data)} repos")
    
    df = pd.DataFrame(repos_data)
    df.to_csv("../datos/github_repos_2025.csv", index=False, encoding="utf-8")
    print(f"Guardado en: datos/github_repos_2025.csv")
    
    return df


def analizar_lenguajes(df_repos):
    """Analiza los lenguajes mas usados en los repos de 2025"""
    print("\nPREGUNTA 1: Analizando lenguajes...")
    
    total_repos = len(df_repos)
    lenguajes = df_repos["language"].value_counts()
    top_10 = lenguajes.head(10)
    
    df_lenguajes = pd.DataFrame({
        "lenguaje": top_10.index,
        "repos_count": top_10.values
    })
    df_lenguajes["porcentaje"] = (df_lenguajes["repos_count"] / total_repos * 100).round(2)
    
    print(f"\nTop 10 Lenguajes de 2025 (de {total_repos} repos):")
    print("-" * 45)
    suma_top10 = 0
    for i, row in df_lenguajes.iterrows():
        print(f"  {i+1}. {row['lenguaje']}: {row['repos_count']} repos ({row['porcentaje']}%)")
        suma_top10 += row['repos_count']
    
    print(f"\nSuma Top 10: {suma_top10} repos ({suma_top10/total_repos*100:.1f}% del total)")
    otros = total_repos - suma_top10
    print(f"Otros lenguajes: {otros} repos ({otros/total_repos*100:.1f}%)")
    
    df_lenguajes.to_csv("../datos/github_lenguajes.csv", index=False, encoding="utf-8")
    print(f"Guardado en: datos/github_lenguajes.csv")
    
    return df_lenguajes


def analizar_commits_frameworks():
    """Analiza la actividad de commits en frameworks frontend"""
    print("\nPREGUNTA 2: Analizando commits de frameworks...")
    
    frameworks = {
        "React": "facebook/react",
        "Vue 3": "vuejs/core",
        "Angular": "angular/angular"
    }
    
    commits_data = []
    
    for framework, repo_path in frameworks.items():
        print(f"  Analizando {framework} ({repo_path})...")
        
        params = {
            "since": "2025-01-01T00:00:00Z",
            "per_page": 100
        }
        
        total_commits = 0
        page = 1
        
        while True:
            params["page"] = page
            response = requests.get(
                f"{GITHUB_API_BASE}/repos/{repo_path}/commits",
                headers=HEADERS,
                params=params,
                timeout=10
            )
            
            if response.status_code != 200:
                if response.status_code == 403:
                    esperar_rate_limit(response)
                    continue
                print(f"  Error obteniendo commits: {response.status_code}")
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
        print(f"  {framework}: {total_commits} commits en 2025")
    
    df_commits = pd.DataFrame(commits_data)
    df_commits = df_commits.sort_values("commits_2025", ascending=False).reset_index(drop=True)
    df_commits["ranking"] = range(1, len(df_commits) + 1)
    
    print("\nRanking de Frameworks Frontend por Commits 2025:")
    print("-" * 50)
    for i, row in df_commits.iterrows():
        print(f"  #{row['ranking']} {row['framework']}: {row['commits_2025']} commits")
    
    df_commits.to_csv("../datos/github_commits_frameworks.csv", index=False, encoding="utf-8")
    print(f"Guardado en: datos/github_commits_frameworks.csv")
    
    return df_commits


def analizar_correlacion(df_repos):
    """Analiza la correlacion entre Stars y Contributors"""
    print("\nPREGUNTA 3: Analizando correlacion Stars vs Contributors...")
    
    correlacion_data = []
    total = min(100, len(df_repos))
    
    count = 0
    for idx, row in df_repos.head(total).iterrows():
        count += 1
        repo_name = row["repo_name"]
        print(f"  [{count}/{total}] {repo_name}...", end="")
        
        max_retries = 3
        success = False
        response = None
        
        for attempt in range(max_retries):
            try:
                response = requests.get(
                    f"{GITHUB_API_BASE}/repos/{repo_name}/contributors",
                    headers=HEADERS,
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
                        print(f" Rate limit, esperando 60s...")
                        time.sleep(60)
                else:
                    print(f" Error: {response.status_code}")
                    break
            except requests.exceptions.Timeout:
                print(f" Timeout, reintento {attempt + 1}/{max_retries}...")
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
            print(f" OK - {contributors} contributors")
        else:
            print(f" No se pudo obtener")
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
        print(f"\nCoeficiente de correlacion: {correlacion:.4f}")
        
        if correlacion > 0.7:
            print("  Correlacion FUERTE positiva")
        elif correlacion > 0.4:
            print("  Correlacion MODERADA positiva")
        elif correlacion > 0:
            print("  Correlacion DEBIL positiva")
        else:
            print("  Correlacion negativa o nula")
    
    df_correlacion.to_csv("../datos/github_correlacion.csv", index=False, encoding="utf-8")
    print(f"Guardado en: datos/github_correlacion.csv")
    
    return df_correlacion


def main():
    """Funcion principal"""
    print("=" * 50)
    print("GITHUB SCRAPER - AVANCE 1")
    print("Technology Trend Analysis Platform")
    print("Autor: Samir Caizapasto")
    print("=" * 50)
    
    if not verificar_conexion():
        print("No se pudo conectar a GitHub. Verifica tu token.")
        return

    df_repos = extraer_repos_2025()
    analizar_lenguajes(df_repos)
    analizar_commits_frameworks()
    analizar_correlacion(df_repos)
    
    print("\n" + "=" * 50)
    print("SCRAPING COMPLETADO")
    print("=" * 50)
    print("\nArchivos generados en carpeta 'datos/':")
    print("  1. github_repos_2025.csv (dataset base)")
    print("  2. github_lenguajes.csv (Pregunta 1)")
    print("  3. github_commits_frameworks.csv (Pregunta 2)")
    print("  4. github_correlacion.csv (Pregunta 3)")


if __name__ == "__main__":
    main()
