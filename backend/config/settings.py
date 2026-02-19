"""
Centralized configuration for the Technology Trend Analysis Platform.

Manages paths, API credentials, and constants using pathlib
for cross-platform compatibility (Windows/Linux/Mac).
"""
import os
from pathlib import Path
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Rutas del proyecto (cross-platform con pathlib)
PROYECTO_ROOT = Path(__file__).resolve().parent.parent.parent
BACKEND_DIR = PROYECTO_ROOT / "backend"
DATOS_DIR = PROYECTO_ROOT / "datos"
FRONTEND_ASSETS_DIR = PROYECTO_ROOT / "frontend" / "assets" / "data"
LOGS_DIR = PROYECTO_ROOT / "logs"

DATOS_DIR.mkdir(exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)

# Variables de entorno
env_path = PROYECTO_ROOT / ".env"
load_dotenv(env_path)

# GitHub API
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")
GITHUB_API_BASE = "https://api.github.com"

GITHUB_HEADERS = {"Accept": "application/vnd.github.v3+json"}
if GITHUB_TOKEN:
    GITHUB_HEADERS["Authorization"] = f"token {GITHUB_TOKEN}"

MAX_REPOS = 1000
PER_PAGE = 100

FRAMEWORK_REPOS = {
    "React": "facebook/react",
    "Vue 3": "vuejs/core",
    "Angular": "angular/angular"
}

# StackOverflow API
SO_API_KEY = os.getenv("STACKOVERFLOW_KEY")
SO_API_URL = "https://api.stackexchange.com/2.3/search/advanced"

# Reddit API (OAuth para evitar bloqueo de IP en CI)
REDDIT_CLIENT_ID = os.getenv("REDDIT_CLIENT_ID")
REDDIT_CLIENT_SECRET = os.getenv("REDDIT_CLIENT_SECRET")
REDDIT_SUBREDDIT = "webdev"
REDDIT_LIMIT = 500
REDDIT_USER_AGENT = (
    "TechTrendsETL/1.0 "
    "(github.com/Sam-24-dev/Technology-trend-analysis-platform)"
)
REDDIT_HEADERS = {
    "User-Agent": REDDIT_USER_AGENT
}

# Archivos de salida
ARCHIVOS_SALIDA = {
    "github_repos": DATOS_DIR / "github_repos_2025.csv",
    "github_lenguajes": DATOS_DIR / "github_lenguajes.csv",
    "github_ai_insights": DATOS_DIR / "github_ai_repos_insights.csv",
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

# Logging
LOG_FORMAT = "[%(asctime)s] [%(levelname)s] %(name)s - %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# Rango de fechas dinamico (ultimos 12 meses)
FECHA_FIN = datetime.now()
FECHA_INICIO = FECHA_FIN - timedelta(days=365)

FECHA_INICIO_STR = FECHA_INICIO.strftime("%Y-%m-%d")
FECHA_FIN_STR = FECHA_FIN.strftime("%Y-%m-%d")
FECHA_INICIO_ISO = FECHA_INICIO.strftime("%Y-%m-%dT00:00:00Z")
FECHA_INICIO_TIMESTAMP = int(FECHA_INICIO.timestamp())

