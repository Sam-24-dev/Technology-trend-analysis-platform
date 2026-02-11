"""
Centralized configuration for the Technology Trend Analysis Platform.

Manages paths, API credentials, and constants using pathlib
for cross-platform compatibility (Windows/Linux/Mac).
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# ============================================
# Rutas del proyecto (cross-platform)
# ============================================
# Raiz del proyecto: Technology-trend-analysis-platform/
PROYECTO_ROOT = Path(__file__).resolve().parent.parent.parent
BACKEND_DIR = PROYECTO_ROOT / "backend"
DATOS_DIR = PROYECTO_ROOT / "datos"
FRONTEND_ASSETS_DIR = PROYECTO_ROOT / "frontend" / "assets" / "data"
LOGS_DIR = PROYECTO_ROOT / "logs"

# Crear directorios si no existen
DATOS_DIR.mkdir(exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)

# ============================================
# Variables de entorno
# ============================================
env_path = PROYECTO_ROOT / ".env"
load_dotenv(env_path)

# ============================================
# GitHub API
# ============================================
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_API_BASE = "https://api.github.com"

GITHUB_HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}" if GITHUB_TOKEN else "",
    "Accept": "application/vnd.github.v3+json"
}

# Limites de extraccion
MAX_REPOS = 1000
PER_PAGE = 100

# Frameworks frontend a analizar
FRAMEWORK_REPOS = {
    "React": "facebook/react",
    "Vue 3": "vuejs/core",
    "Angular": "angular/angular"
}

# ============================================
# StackOverflow API
# ============================================
SO_API_KEY = os.getenv("STACKOVERFLOW_KEY")
SO_API_URL = "https://api.stackexchange.com/2.3/search/advanced"

# ============================================
# Reddit API (publica, sin autenticacion)
# ============================================
REDDIT_SUBREDDIT = "webdev"
REDDIT_LIMIT = 500
REDDIT_HEADERS = {
    "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
}

# ============================================
# Archivos de salida
# ============================================
ARCHIVOS_SALIDA = {
    "github_repos": DATOS_DIR / "github_repos_2025.csv",
    "github_lenguajes": DATOS_DIR / "github_lenguajes.csv",
    "github_commits": DATOS_DIR / "github_commits_frameworks.csv",
    "github_correlacion": DATOS_DIR / "github_correlacion.csv",
    "so_volumen": DATOS_DIR / "so_volumen_preguntas.csv",
    "so_aceptacion": DATOS_DIR / "so_tasa_aceptacion.csv",
    "so_tendencias": DATOS_DIR / "so_tendencias_mensuales.csv",
    "reddit_sentimiento": DATOS_DIR / "reddit_sentimiento_frameworks.csv",
    "reddit_temas": DATOS_DIR / "reddit_temas_emergentes.csv",
    "interseccion": DATOS_DIR / "interseccion_github_reddit.csv",
    "trend_score": DATOS_DIR / "trend_score.csv",
}

# ============================================
# Logging
# ============================================
LOG_FORMAT = "[%(asctime)s] [%(levelname)s] %(name)s - %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"
