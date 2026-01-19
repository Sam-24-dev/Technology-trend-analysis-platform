"""
Configuracion para el scraper de GitHub
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Cargar variables de entorno
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(env_path)

# Token de GitHub
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")

if not GITHUB_TOKEN:
    print("ADVERTENCIA: No se encontro GITHUB_TOKEN en .env")

# API
GITHUB_API_BASE = "https://api.github.com"

# Headers
HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json"
}

# Limites
MAX_REPOS = 1000
PER_PAGE = 100

# Frameworks frontend
FRAMEWORK_REPOS = {
    "React": "facebook/react",
    "Vue 3": "vuejs/core",
    "Angular": "angular/angular"
}

# --- CONFIGURACIÓN STACKOVERFLOW (Andrés) ---
SO_API_KEY = os.getenv("STACKOVERFLOW_KEY")
SO_API_URL = "https://api.stackexchange.com/2.3/search/advanced"