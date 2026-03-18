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
from generate_run_manifest import generate_manifest_public


FRONTEND_CSV_ALLOWLIST = {
    "trend_score.csv",
    "github_lenguajes.csv",
    "github_commits_frameworks.csv",
    "github_correlacion.csv",
    "so_volumen_preguntas.csv",
    "so_tasa_aceptacion.csv",
    "so_tendencias_mensuales.csv",
    "reddit_sentimiento_frameworks.csv",
    "reddit_temas_emergentes.csv",
    "interseccion_github_reddit.csv",
}


def _is_bridge_export_enabled():
    return os.getenv("EXPORT_HISTORY_BRIDGE_JSON", "1") == "1"


def _is_public_manifest_enabled():
    return os.getenv("USE_PUBLIC_RUN_MANIFEST", "1") == "1"


def _is_public_manifest_required():
    return os.getenv("REQUIRE_FRONTEND_METADATA", "0") == "1"


def _assets_policy_mode():
    mode = os.getenv("FRONTEND_ASSETS_POLICY_MODE", "warning").strip().lower()
    return mode if mode in {"warning", "strict"} else "warning"


def _resolve_bridge_remote_dir(project_root):
    raw = os.getenv("FRONTEND_BRIDGE_REMOTE_DIR", "").strip()
    if not raw:
        return None
    path = Path(raw)
    if not path.is_absolute():
        path = project_root / raw
    return path


def _csv_column_count(csv_path):
    try:
        first_line = csv_path.read_text(encoding="utf-8", errors="ignore").splitlines()[0]
    except Exception:  # pylint: disable=broad-exception-caught
        return 0
    return len([col for col in first_line.split(",") if col.strip() != ""])


def _should_replace_csv(existing_path, candidate_path):
    existing_cols = _csv_column_count(existing_path)
    candidate_cols = _csv_column_count(candidate_path)
    if candidate_cols != existing_cols:
        return candidate_cols > existing_cols

    try:
        existing_mtime = existing_path.stat().st_mtime_ns
        candidate_mtime = candidate_path.stat().st_mtime_ns
        return candidate_mtime >= existing_mtime
    except Exception:  # pylint: disable=broad-exception-caught
        return True


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
            existing = csv_by_name.get(csv_file.name)
            if existing is None or _should_replace_csv(existing, csv_file):
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
    bridge_output_dir = None
    public_manifest_written = False
    public_manifest_status = "disabled"
    bridge_enabled = _is_bridge_export_enabled()
    public_manifest_enabled = _is_public_manifest_enabled()
    public_manifest_required = _is_public_manifest_required()
    policy_mode = _assets_policy_mode()
    skipped_not_allowlisted = []

    for csv_name in sorted(csv_by_name):
        csv_file = csv_by_name[csv_name]
        if csv_name not in FRONTEND_CSV_ALLOWLIST:
            skipped_not_allowlisted.append(csv_name)
            logger.info(
                "[STEP][SKIP] accion=copy archivo=%s razon=not_allowlisted policy_mode=%s",
                csv_name,
                policy_mode,
            )
            continue
        try:
            shutil.copy2(csv_file, destino / csv_file.name)
            archivos_copiados += 1
            logger.info("[STEP][END] accion=copy archivo=%s origen=%s estado=success", csv_file.name, csv_file.parent)
        except Exception as exc:  # pylint: disable=broad-exception-caught
            errores += 1
            logger.error("[STEP][END] accion=copy archivo=%s estado=failed error=%s", csv_file.name, exc)

    missing_required = [
        csv_name for csv_name in sorted(FRONTEND_CSV_ALLOWLIST) if not (destino / csv_name).exists()
    ]
    if missing_required:
        for csv_name in missing_required:
            message = (
                "[STEP][END] accion=allowlist_required archivo=%s "
                "estado=%s policy_mode=%s"
            )
            if policy_mode == "strict":
                errores += 1
                logger.error(message, csv_name, "missing", policy_mode)
            else:
                logger.warning(message, csv_name, "missing", policy_mode)

    if bridge_enabled:
        try:
            bridge_output_dir = _resolve_bridge_remote_dir(proyecto_root)
            bridge_summary = export_bridge_assets(
                proyecto_root,
                output_dir=destino,
                compact=True,
            )
            bridge_files_written = int(bridge_summary["files_written"])
            output_location = bridge_summary["history_index_path"]
            if bridge_output_dir is not None and bridge_output_dir.resolve() != destino.resolve():
                remote_summary = export_bridge_assets(
                    proyecto_root,
                    output_dir=bridge_output_dir,
                    compact=False,
                )
                bridge_files_written += int(remote_summary["files_written"])
                output_location = bridge_output_dir
            logger.info(
                "[STEP][END] action=bridge_export status=success files_written=%d trend_snapshots=%d output_dir=%s",
                bridge_files_written,
                bridge_summary["trend_snapshot_count"],
                output_location,
            )
        except Exception as exc:  # pylint: disable=broad-exception-caught
            errores += 1
            logger.error("[STEP][END] action=bridge_export status=failed error=%s", exc)

    if public_manifest_enabled:
        try:
            manifest_summary = generate_manifest_public(
                proyecto_root,
                require_metadata=public_manifest_required,
            )
            public_manifest_written = bool(manifest_summary["valid"])
            public_manifest_status = str(manifest_summary["status"])
            logger.info(
                "[STEP][END] action=run_manifest_public status=%s valid=%s source_mode=%s output=%s",
                manifest_summary["status"],
                manifest_summary["valid"],
                manifest_summary["source_mode"],
                manifest_summary["output_path"],
            )
        except Exception as exc:  # pylint: disable=broad-exception-caught
            public_manifest_status = "failed"
            if public_manifest_required:
                errores += 1
            logger.error(
                "[STEP][END] action=run_manifest_public status=failed required=%s error=%s",
                public_manifest_required,
                exc,
            )

    logger.info(
        "[RUN][SUMMARY] estado=%s archivos_copiados=%d bridge_files=%d bridge_enabled=%s "
        "public_manifest_enabled=%s public_manifest_status=%s public_manifest_written=%s "
        "assets_policy_mode=%s skipped_not_allowlisted=%d errores=%d source_mode=%s origen=%s destino=%s",
        "success" if errores == 0 else "partial",
        archivos_copiados,
        bridge_files_written,
        bridge_enabled,
        public_manifest_enabled,
        public_manifest_status,
        public_manifest_written,
        policy_mode,
        len(skipped_not_allowlisted),
        errores,
        source_mode,
        origen,
        destino,
    )
    return {
        "files_copied": archivos_copiados,
        "bridge_files_written": bridge_files_written,
        "bridge_export_enabled": bridge_enabled,
        "public_manifest_enabled": public_manifest_enabled,
        "public_manifest_required": public_manifest_required,
        "public_manifest_status": public_manifest_status,
        "public_manifest_written": public_manifest_written,
        "assets_policy_mode": policy_mode,
        "skipped_not_allowlisted": skipped_not_allowlisted,
        "errors": errores,
        "source_mode": source_mode,
        "source": str(origen),
        "destination": str(destino),
        "bridge_output_dir": str(bridge_output_dir) if bridge_output_dir else None,
    }


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")
    sincronizar()
