"""
GitHub Scraper - Avance 1 (VERSIÓN CORREGIDA)
Extrae datos de GitHub API para análisis de tendencias 2025

Autor: Samir Caizapasto
Proyecto: Technology Trend Analysis Platform - ESPOL 2025

CORRECCIONES:
- Manejo de error 403 (rate limit) con reintentos
- Repos sin lenguaje se cuentan como "Sin especificar"
- Commits sin límite artificial de 1000
- Vue 3 (vuejs/core) agregado
"""
import requests
import pandas as pd
from datetime import datetime
import time
import os
import re

# Importar configuración
from config import GITHUB_TOKEN, GITHUB_API_BASE, HEADERS, MAX_REPOS, PER_PAGE, FRAMEWORK_REPOS


def verificar_conexion():
    """Verifica que el token de GitHub funcione correctamente"""
    print("🔐 Verificando conexión con GitHub API...")
    
    response = requests.get(f"{GITHUB_API_BASE}/user", headers=HEADERS)
    
    if response.status_code == 200:
        user = response.json()
        print(f"✅ Conectado como: {user.get('login', 'Usuario')}")
        
        # Mostrar límite de requests
        remaining = response.headers.get('X-RateLimit-Remaining', 'N/A')
        limit = response.headers.get('X-RateLimit-Limit', 'N/A')
        print(f"📊 Rate Limit: {remaining}/{limit} requests disponibles")
        return True
    else:
        print(f"❌ Error de conexión: {response.status_code}")
        print(f"   Mensaje: {response.json().get('message', 'Sin mensaje')}")
        return False


def esperar_rate_limit(response):
    """Espera si se alcanzó el rate limit"""
    if response.status_code == 403:
        reset_time = int(response.headers.get('X-RateLimit-Reset', 0))
        if reset_time:
            wait_seconds = reset_time - int(time.time()) + 5
            if wait_seconds > 0 and wait_seconds < 300:  # Máximo 5 minutos
                print(f"   ⏳ Rate limit alcanzado. Esperando {wait_seconds} segundos...")
                time.sleep(wait_seconds)
                return True
    return False


def extraer_repos_2025(max_repos=MAX_REPOS):
    """
    PREGUNTA 1 y 3: Extrae los top repos creados en 2025
    CORREGIDO: Manejo de rate limit y repos sin lenguaje
    """
    print(f"\n📥 Extrayendo top {max_repos} repos de 2025...")
    
    repos_data = []
    page = 1
    total_pages = max_repos // PER_PAGE
    max_retries = 3
    
    while len(repos_data) < max_repos:
        print(f"   Página {page}/{total_pages}...")
        
        # Query: repos creados en 2025, ordenados por stars
        params = {
            "q": "created:2025-01-01..2025-12-31",
            "sort": "stars",
            "order": "desc",
            "per_page": PER_PAGE,
            "page": page
        }
        
        # Intentar con reintentos
        for retry in range(max_retries):
            response = requests.get(
                f"{GITHUB_API_BASE}/search/repositories",
                headers=HEADERS,
                params=params
            )
            
            if response.status_code == 200:
                break
            elif response.status_code == 403:
                if esperar_rate_limit(response):
                    continue
                else:
                    print(f"   ⚠️ Error 403 en página {page}, reintentando ({retry+1}/{max_retries})...")
                    time.sleep(10)
            else:
                print(f"❌ Error en página {page}: {response.status_code}")
                break
        
        if response.status_code != 200:
            print(f"   ⚠️ No se pudo obtener página {page}, continuando...")
            page += 1
            continue
        
        data = response.json()
        items = data.get("items", [])
        
        if not items:
            print("   No hay más resultados")
            break
        
        for repo in items:
            # CORREGIDO: Manejar repos sin lenguaje
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
        time.sleep(2)  # Pausa más larga para evitar rate limit
        
        if page > total_pages:
            break
    
    print(f"✅ Extraídos {len(repos_data)} repos")
    
    # Guardar dataset base
    df = pd.DataFrame(repos_data)
    df.to_csv("../datos/repos_2025_raw.csv", index=False, encoding="utf-8")
    print(f"💾 Guardado en: datos/repos_2025_raw.csv")
    
    return df


def analizar_lenguajes(df_repos):
    """
    PREGUNTA 1: ¿Cuáles son los 10 lenguajes con mayor creación de repos en 2025?
    CORREGIDO: Incluye repos sin lenguaje y verifica suma total
    """
    print("\n📊 PREGUNTA 1: Analizando lenguajes...")
    
    total_repos = len(df_repos)
    
    # Contar repos por lenguaje (incluye "Sin especificar")
    lenguajes = df_repos["language"].value_counts()
    
    # Top 10
    top_10 = lenguajes.head(10)
    
    # Crear DataFrame
    df_lenguajes = pd.DataFrame({
        "lenguaje": top_10.index,
        "repos_count": top_10.values
    })
    
    # Calcular porcentaje
    df_lenguajes["porcentaje"] = (df_lenguajes["repos_count"] / total_repos * 100).round(2)
    
    # Mostrar resultados
    print(f"\n🏆 Top 10 Lenguajes de 2025 (de {total_repos} repos):")
    print("-" * 45)
    suma_top10 = 0
    for i, row in df_lenguajes.iterrows():
        print(f"   {i+1}. {row['lenguaje']}: {row['repos_count']} repos ({row['porcentaje']}%)")
        suma_top10 += row['repos_count']
    
    print(f"\n   📊 Suma Top 10: {suma_top10} repos ({suma_top10/total_repos*100:.1f}% del total)")
    otros = total_repos - suma_top10
    print(f"   📊 Otros lenguajes: {otros} repos ({otros/total_repos*100:.1f}%)")
    
    # Guardar CSV
    df_lenguajes.to_csv("../datos/lenguajes_2025.csv", index=False, encoding="utf-8")
    print(f"\n💾 Guardado en: datos/lenguajes_2025.csv")
    
    return df_lenguajes


def analizar_commits_frameworks():
    """
    PREGUNTA 2: ¿Qué frameworks frontend tienen mayor actividad de commits?
    CORREGIDO: 
    - Sin límite artificial de 1000 commits
    - Incluye Vue 3 (vuejs/core)
    - Muestra ranking real
    """
    print("\n📊 PREGUNTA 2: Analizando commits de frameworks...")
    
    # Frameworks actualizados (Vue 2 + Vue 3)
    frameworks = {
        "React": "facebook/react",
        "Vue 3": "vuejs/core",      # Vue 3 (activo)
        "Angular": "angular/angular"
    }
    
    commits_data = []
    
    for framework, repo_path in frameworks.items():
        print(f"   Analizando {framework} ({repo_path})...")
        
        # Obtener commits desde enero 2025
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
                params=params
            )
            
            if response.status_code != 200:
                if response.status_code == 403:
                    esperar_rate_limit(response)
                    continue
                print(f"   ⚠️ Error obteniendo commits: {response.status_code}")
                break
            
            commits = response.json()
            if not commits:
                break
            
            total_commits += len(commits)
            page += 1
            time.sleep(0.5)
            
            # SIN límite artificial - obtener todos los commits
            # Pero limitamos a 50 páginas (5000 commits) por seguridad
            if page > 50:
                print(f"   ℹ️ Limitado a 5000 commits por seguridad")
                break
        
        commits_data.append({
            "framework": framework,
            "repo": repo_path,
            "commits_2025": total_commits
        })
        print(f"   ✅ {framework}: {total_commits} commits en 2025")
    
    # Crear DataFrame y ordenar por commits (ranking)
    df_commits = pd.DataFrame(commits_data)
    df_commits = df_commits.sort_values("commits_2025", ascending=False).reset_index(drop=True)
    df_commits["ranking"] = range(1, len(df_commits) + 1)
    
    # Mostrar resultados como ranking
    print("\n🏆 Ranking de Frameworks Frontend por Commits 2025:")
    print("-" * 50)
    for i, row in df_commits.iterrows():
        medal = "🥇" if row['ranking'] == 1 else "🥈" if row['ranking'] == 2 else "🥉"
        print(f"   {medal} #{row['ranking']} {row['framework']}: {row['commits_2025']} commits")
    
    # Guardar CSV
    df_commits.to_csv("../datos/frameworks_commits.csv", index=False, encoding="utf-8")
    print(f"\n💾 Guardado en: datos/frameworks_commits.csv")
    
    return df_commits


def analizar_correlacion(df_repos):
    """
    PREGUNTA 3: ¿Existe correlación entre Stars y Contributors?
    Extrae contributors de los repos del dataset
    """
    print("\n📊 PREGUNTA 3: Analizando correlación Stars vs Contributors...")
    
    correlacion_data = []
    total = min(100, len(df_repos))  # Top 100 repos
    
    count = 0
    for idx, row in df_repos.head(total).iterrows():
        count += 1
        repo_name = row["repo_name"]
        print(f"   [{count}/{total}] {repo_name}...", end="")
        
        # Obtener contributors del repo
        response = requests.get(
            f"{GITHUB_API_BASE}/repos/{repo_name}/contributors",
            headers=HEADERS,
            params={"per_page": 1, "anon": "true"}
        )
        
        if response.status_code == 200:
            # El número total está en el header Link o contamos
            contributors = len(response.json())
            
            # Si hay paginación, revisar header
            link_header = response.headers.get("Link", "")
            if "last" in link_header:
                # Extraer número de última página
                match = re.search(r'page=(\d+)>; rel="last"', link_header)
                if match:
                    contributors = int(match.group(1))
            
            correlacion_data.append({
                "repo_name": repo_name,
                "stars": row["stars"],
                "contributors": contributors,
                "language": row["language"]
            })
            print(f" ✅ {contributors} contributors")
        elif response.status_code == 403:
            if esperar_rate_limit(response):
                # Reintentar este repo
                i -= 1
                continue
            else:
                print(f" ⚠️ Rate limit")
        else:
            print(f" ⚠️ Error: {response.status_code}")
        
        time.sleep(0.3)
    
    # Crear DataFrame
    df_correlacion = pd.DataFrame(correlacion_data)
    
    # Calcular correlación
    if len(df_correlacion) > 0:
        correlacion = df_correlacion["stars"].corr(df_correlacion["contributors"])
        print(f"\n📈 Coeficiente de correlación: {correlacion:.4f}")
        
        if correlacion > 0.7:
            print("   → Correlación FUERTE positiva")
        elif correlacion > 0.4:
            print("   → Correlación MODERADA positiva")
        elif correlacion > 0:
            print("   → Correlación DÉBIL positiva")
        else:
            print("   → Correlación negativa o nula")
    
    # Guardar CSV
    df_correlacion.to_csv("../datos/stars_vs_contributors.csv", index=False, encoding="utf-8")
    print(f"\n💾 Guardado en: datos/stars_vs_contributors.csv")
    
    return df_correlacion


def main():
    """Función principal que ejecuta todo el scraping"""
    print("=" * 50)
    print("🚀 GITHUB SCRAPER - AVANCE 1 (VERSIÓN CORREGIDA)")
    print("   Technology Trend Analysis Platform")
    print("   ESPOL 2025 - Samir Caizapasto")
    print("=" * 50)
    
    # Verificar conexión
    if not verificar_conexion():
        print("❌ No se pudo conectar a GitHub. Verifica tu token.")
        return
    
    # Crear carpeta datos si no existe
    os.makedirs("../datos", exist_ok=True)
    
    # PASO 1: Extraer dataset base (repos 2025)
    df_repos = extraer_repos_2025()
    
    # PREGUNTA 1: Analizar lenguajes
    analizar_lenguajes(df_repos)
    
    # PREGUNTA 2: Analizar commits de frameworks
    analizar_commits_frameworks()
    
    # PREGUNTA 3: Analizar correlación stars vs contributors
    analizar_correlacion(df_repos)
    
    # Resumen final
    print("\n" + "=" * 50)
    print("✅ SCRAPING COMPLETADO")
    print("=" * 50)
    print("\n📁 Archivos generados en carpeta 'datos/':")
    print("   1. repos_2025_raw.csv (dataset base)")
    print("   2. lenguajes_2025.csv (Pregunta 1)")
    print("   3. frameworks_commits.csv (Pregunta 2)")
    print("   4. stars_vs_contributors.csv (Pregunta 3)")
    print("\n🎉 ¡Listo para el Avance 1!")


if __name__ == "__main__":
    main()
