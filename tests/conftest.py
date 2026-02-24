"""
Configuración de Pytest para los tests de Technology Trend Analysis Platform.

Agrega el directorio backend a sys.path para que los tests puedan importar
módulos ETL directamente.
"""
import sys
from pathlib import Path

# Agrega el directorio backend al path para que los imports funcionen igual que al ejecutar desde backend/
backend_dir = Path(__file__).parent.parent / "backend"
sys.path.insert(0, str(backend_dir))
