"""
Configuración para el scraper de GitHub
"""
import os
from pathlib import Path
from dotenv import load_dotenv

# Cargar variables de entorno desde .env (en la raíz del proyecto)
env_path = Path(__file__).parent.parent / ".env"
load_dotenv(env_path)

# Token de GitHub (desde .env)
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN")

# Validar que el token exista
if not GITHUB_TOKEN:
    print("⚠️ ADVERTENCIA: No se encontró GITHUB_TOKEN en el archivo .env")
    print(f"   Buscando en: {env_path}")

# Configuración de la API
GITHUB_API_BASE = "https://api.github.com"

# Headers para autenticación
HEADERS = {
    "Authorization": f"token {GITHUB_TOKEN}",
    "Accept": "application/vnd.github.v3+json"
}

# Límites de búsqueda
MAX_REPOS = 1000  # Máximo permitido por GitHub Search API
PER_PAGE = 100    # Repos por página (máximo 100)

# Repos oficiales de frameworks frontend (actualizado con Vue 3)
FRAMEWORK_REPOS = {
    "React": "facebook/react",
    "Vue 3": "vuejs/core",      # Vue 3 (activo)
    "Angular": "angular/angular"
}
