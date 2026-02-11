"""
Syncs CSV files from datos/ to frontend/assets/data/.

Ensures the Flutter Web dashboard always uses the latest
processed data from the ETL pipeline.
"""
import shutil
from pathlib import Path


def sincronizar():
    """Copies all CSV files from datos/ to frontend/assets/data/."""
    proyecto_root = Path(__file__).resolve().parent.parent
    origen = proyecto_root / "datos"
    destino = proyecto_root / "frontend" / "assets" / "data"

    destino.mkdir(parents=True, exist_ok=True)

    archivos_copiados = 0
    for csv_file in origen.glob("*.csv"):
        shutil.copy2(csv_file, destino / csv_file.name)
        archivos_copiados += 1
        print(f"  Copiado: {csv_file.name}")

    print(f"Sincronizacion completada: {archivos_copiados} archivos copiados")
    print(f"  Origen:  {origen}")
    print(f"  Destino: {destino}")


if __name__ == "__main__":
    print("Sincronizacion de datos: datos/ -> frontend/assets/data/")
    sincronizar()
