"""
Syncs CSV files from datos/ to frontend/assets/data/.

Ensures the Flutter Web dashboard always uses the latest
processed data from the ETL pipeline.
"""
import logging
import shutil
from pathlib import Path


def sincronizar():
    """Copies all CSV files from datos/ to frontend/assets/data/."""
    logger = logging.getLogger("sync_assets")
    if not logger.handlers:
        logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")

    proyecto_root = Path(__file__).resolve().parent.parent
    origen = proyecto_root / "datos"
    destino = proyecto_root / "frontend" / "assets" / "data"

    destino.mkdir(parents=True, exist_ok=True)
    logger.info("[RUN][START] origen=%s destino=%s", origen, destino)

    archivos_copiados = 0
    errores = 0
    for csv_file in origen.glob("*.csv"):
        try:
            shutil.copy2(csv_file, destino / csv_file.name)
            archivos_copiados += 1
            logger.info("[STEP][END] accion=copy archivo=%s estado=success", csv_file.name)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            errores += 1
            logger.error("[STEP][END] accion=copy archivo=%s estado=failed error=%s", csv_file.name, exc)

    logger.info(
        "[RUN][SUMMARY] estado=%s archivos_copiados=%d errores=%d origen=%s destino=%s",
        "success" if errores == 0 else "partial",
        archivos_copiados,
        errores,
        origen,
        destino,
    )
    return {
        "files_copied": archivos_copiados,
        "errors": errores,
        "source": str(origen),
        "destination": str(destino),
    }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")
    sincronizar()
