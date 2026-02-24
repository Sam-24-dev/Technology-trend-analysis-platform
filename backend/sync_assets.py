"""
Sincroniza archivos CSV desde datos/ hacia frontend/assets/data/.

Asegura que el dashboard Flutter Web use siempre los datos
procesados más recientes del pipeline ETL.
"""

import logging
import os
import shutil
from pathlib import Path

from export_history_json import export_bridge_assets


def _is_bridge_export_enabled():
    return os.getenv("EXPORT_HISTORY_BRIDGE_JSON", "1") == "1"


def _resolver_origen_csv(proyecto_root):
    """Resolves CSV source strategy, prioritizing latest per file with legacy fallback."""
    origen_latest = proyecto_root / "datos" / "latest"
    origen_legacy = proyecto_root / "datos"
    csv_by_name = {}

    if origen_legacy.exists():
        for csv_file in origen_legacy.glob("*.csv"):
            csv_by_name[csv_file.name] = csv_file

    if origen_latest.exists():
        for csv_file in origen_latest.glob("*.csv"):
            csv_by_name[csv_file.name] = csv_file

    return csv_by_name, origen_latest, origen_legacy


def _describe_source_mode(csv_by_name, origen_latest, origen_legacy):
    if not csv_by_name:
        return "none"

    latest_used = {
        name
        for name, path in csv_by_name.items()
        if path.parent.resolve() == origen_latest.resolve()
    }
    legacy_used = {
        name
        for name, path in csv_by_name.items()
        if path.parent.resolve() == origen_legacy.resolve()
    }

    if latest_used and legacy_used:
        return "mixed"
    if latest_used:
        return "latest"
    return "legacy"


def _resolve_summary_source(source_mode, origen_latest, origen_legacy):
    if source_mode == "latest":
        return str(origen_latest)
    if source_mode == "legacy":
        return str(origen_legacy)
    if source_mode == "mixed":
        return "mixed(latest+legacy)"
    return "none"


def sincronizar():
    """Copia todos los archivos CSV de datos/ a frontend/assets/data/."""
    logger = logging.getLogger("sync_assets")
    if not logger.handlers:
        logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")

    proyecto_root = Path(__file__).resolve().parent.parent
    csv_by_name, origen_latest, origen_legacy = _resolver_origen_csv(proyecto_root)
    source_mode = _describe_source_mode(csv_by_name, origen_latest, origen_legacy)
    origen = _resolve_summary_source(source_mode, origen_latest, origen_legacy)
    destino = proyecto_root / "frontend" / "assets" / "data"

    destino.mkdir(parents=True, exist_ok=True)
    logger.info("[RUN][START] origen=%s source_mode=%s destino=%s", origen, source_mode, destino)

    archivos_copiados = 0
    errores = 0
    bridge_files_written = 0
    bridge_enabled = _is_bridge_export_enabled()

    for csv_name in sorted(csv_by_name):
        csv_file = csv_by_name[csv_name]
        try:
            shutil.copy2(csv_file, destino / csv_file.name)
            archivos_copiados += 1
            logger.info("[STEP][END] accion=copy archivo=%s origen=%s estado=success", csv_file.name, csv_file.parent)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            errores += 1
            logger.error("[STEP][END] accion=copy archivo=%s estado=failed error=%s", csv_file.name, exc)

    if bridge_enabled:
        try:
            bridge_summary = export_bridge_assets(proyecto_root)
            bridge_files_written = int(bridge_summary["files_written"])
            logger.info(
                "[STEP][END] action=bridge_export status=success files_written=%d trend_snapshots=%d",
                bridge_files_written,
                bridge_summary["trend_snapshot_count"],
            )
        except Exception as exc:  # pylint: disable=broad-exception-caught
            errores += 1
            logger.error("[STEP][END] action=bridge_export status=failed error=%s", exc)

    logger.info(
        "[RUN][SUMMARY] estado=%s archivos_copiados=%d bridge_files=%d bridge_enabled=%s "
        "errores=%d source_mode=%s origen=%s destino=%s",
        "success" if errores == 0 else "partial",
        archivos_copiados,
        bridge_files_written,
        bridge_enabled,
        errores,
        source_mode,
        origen,
        destino,
    )
    return {
        "files_copied": archivos_copiados,
        "bridge_files_written": bridge_files_written,
        "bridge_export_enabled": bridge_enabled,
        "errors": errores,
        "source_mode": source_mode,
        "source": str(origen),
        "destination": str(destino),
    }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")
    sincronizar()
