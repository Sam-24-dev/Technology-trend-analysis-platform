"""
Configuración centralizada para la Technology Trend Analysis Platform.

Gestiona rutas, credenciales de API y constantes usando pathlib 
para compatibilidad cross-platform (Windows/Linux/Mac).
"""
import os
from pathlib import Path
from datetime import datetime, timedelta, timezone
from dotenv import load_dotenv

# Rutas del proyecto (cross-platform con pathlib)
PROYECTO_ROOT = Path(__file__).resolve().parent.parent.parent
BACKEND_DIR = PROYECTO_ROOT / "backend"
DATOS_DIR = PROYECTO_ROOT / "datos"
DATOS_LATEST_DIR = DATOS_DIR / "latest"
DATOS_HISTORY_DIR = DATOS_DIR / "history"
DATOS_METADATA_DIR = DATOS_DIR / "metadata"
FRONTEND_ASSETS_DIR = PROYECTO_ROOT / "frontend" / "assets" / "data"
SO_TRENDS_METADATA_PATH = DATOS_METADATA_DIR / "so_tendencias_series.json"
LOGS_DIR = PROYECTO_ROOT / "logs"

DATOS_DIR.mkdir(exist_ok=True)
DATOS_LATEST_DIR.mkdir(parents=True, exist_ok=True)
DATOS_HISTORY_DIR.mkdir(parents=True, exist_ok=True)
DATOS_METADATA_DIR.mkdir(parents=True, exist_ok=True)
LOGS_DIR.mkdir(exist_ok=True)

# Variables de entorno
env_path = PROYECTO_ROOT / ".env"
load_dotenv(env_path)

# API de GitHub
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
    "Angular": "angular/angular",
    "Svelte": "sveltejs/svelte",
    "Next.js": "vercel/next.js",
}

# API de StackOverflow
SO_API_KEY = os.getenv("STACKOVERFLOW_KEY")
SO_API_URL = "https://api.stackexchange.com/2.3/search/advanced"


def _parse_csv_list(value: str) -> list[str]:
    return [item.strip().lower() for item in value.split(",") if item.strip()]


SO_TOP_LANGUAGES = _parse_csv_list(
    os.getenv(
        "STACKOVERFLOW_TOP_LANGUAGES",
        "python,javascript,typescript,java,go,c#,php,c++,ruby,kotlin",
    )
)

# API de Reddit (OAuth para evitar bloqueos de IP de datacenter en CI)
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
    "github_commits_monthly": DATOS_DIR / "github_commits_frameworks_monthly.csv",
    "github_correlacion": DATOS_DIR / "github_correlacion.csv",
    "so_volumen": DATOS_DIR / "so_volumen_preguntas.csv",
    "so_aceptacion": DATOS_DIR / "so_tasa_aceptacion.csv",
    "so_tendencias": DATOS_DIR / "so_tendencias_mensuales.csv",
    "reddit_sentimiento": DATOS_DIR / "reddit_sentimiento_frameworks.csv",
    "reddit_temas": DATOS_DIR / "reddit_temas_emergentes.csv",
    "interseccion": DATOS_DIR / "interseccion_github_reddit.csv",
    "trend_score": DATOS_DIR / "trend_score.csv",
}

# Estrategia de escritura de datos (refactor incremental)
# - LEGACY: mantiene el comportamiento histórico actual
# - LATEST: publica CSVs en datos/latest para consumo de sync
# - HISTORY: guarda snapshots particionados por fecha (CSV por ahora)
WRITE_LEGACY_CSV = os.getenv("DATA_WRITE_LEGACY_CSV", "1") == "1"
WRITE_LATEST_CSV = os.getenv("DATA_WRITE_LATEST_CSV", "0") == "1"
WRITE_HISTORY_CSV = os.getenv("DATA_WRITE_HISTORY_CSV", "0") == "1"
HISTORY_PARTITION_MODE = os.getenv("DATA_HISTORY_PARTITION_MODE", "day").strip().lower()


def get_latest_output_path(nombre_archivo):
    """Retorna la ruta en datos/latest para un archivo lógico de salida."""
    ruta_legacy = ARCHIVOS_SALIDA.get(nombre_archivo)
    if ruta_legacy is None:
        return None
    return DATOS_LATEST_DIR / ruta_legacy.name


def get_history_output_path(nombre_archivo, fecha=None):
    """Retorna una ruta particionada por fecha para el histórico CSV."""
    ruta_legacy = ARCHIVOS_SALIDA.get(nombre_archivo)
    if ruta_legacy is None:
        return None

    fecha_ref = fecha or datetime.now(timezone.utc)
    particion = (
        DATOS_HISTORY_DIR
        / nombre_archivo
        / f"year={fecha_ref.strftime('%Y')}"
        / f"month={fecha_ref.strftime('%m')}"
        / f"day={fecha_ref.strftime('%d')}"
    )
    if HISTORY_PARTITION_MODE == "run":
        particion = particion / f"run={fecha_ref.strftime('%H%M%S')}"
    return particion / ruta_legacy.name

# Logging
LOG_FORMAT = "[%(asctime)s] [%(levelname)s] %(name)s - %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

# Resiliencia de red (compartida entre ETLs)
REQUEST_TIMEOUT_SECONDS = 10
HTTP_MAX_RETRIES = 3
HTTP_RETRY_BACKOFF_SECONDS = 2
REQUEST_PAGE_DELAY_SECONDS = 2.0
REQUEST_MEDIUM_DELAY_SECONDS = 0.5
REQUEST_SHORT_DELAY_SECONDS = 0.3

# Rango dinámico de fechas (últimos 12 meses)
# Permite fijar fecha de referencia en UTC vía env:
#   ETL_REFERENCE_DATE_UTC=YYYY-MM-DD (o ISO-8601 completo)
_reference_date = os.getenv("ETL_REFERENCE_DATE_UTC") or os.getenv(
    "ETL_REFERENCE_DATE"
)
if _reference_date:
    try:
        FECHA_FIN = datetime.fromisoformat(_reference_date)
        if FECHA_FIN.tzinfo is None:
            FECHA_FIN = FECHA_FIN.replace(tzinfo=timezone.utc)
    except ValueError:
        FECHA_FIN = datetime.now(timezone.utc)
else:
    FECHA_FIN = datetime.now(timezone.utc)

FECHA_INICIO = FECHA_FIN - timedelta(days=365)

FECHA_INICIO_STR = FECHA_INICIO.strftime("%Y-%m-%d")
FECHA_FIN_STR = FECHA_FIN.strftime("%Y-%m-%d")
FECHA_INICIO_ISO = FECHA_INICIO.strftime("%Y-%m-%dT00:00:00Z")
FECHA_INICIO_TIMESTAMP = int(FECHA_INICIO.timestamp())

