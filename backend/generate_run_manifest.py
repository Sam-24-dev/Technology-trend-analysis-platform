"""Genera el run manifest público de frontend desde salidas ETL."""

from __future__ import annotations

import argparse
import logging
import os
from pathlib import Path

from config.run_manifest_public_contract import generate_public_run_manifest, write_public_run_manifest


logger = logging.getLogger("generate_run_manifest")


def _is_enabled() -> bool:
    return os.getenv("USE_PUBLIC_RUN_MANIFEST", "1") == "1"


def _is_required() -> bool:
    return os.getenv("REQUIRE_FRONTEND_METADATA", "0") == "1"


def generate_manifest_public(
    project_root: Path,
    *,
    require_metadata: bool,
) -> dict[str, object]:
    """Genera y valida el run manifest público para frontend."""
    generation = generate_public_run_manifest(project_root)
    is_valid = bool(generation["valid"])
    errors = generation["errors"]
    payload = generation["payload"]
    source_mode = str(generation["source_mode"])

    if not is_valid:
        error_message = "; ".join(str(item) for item in errors) if errors else "unknown validation errors"
        if require_metadata:
            raise RuntimeError(f"public run manifest is invalid (required mode): {error_message}")
        logger.warning("public run manifest invalid (soft mode): %s", error_message)
        return {
            "status": "warning",
            "valid": False,
            "errors": list(errors),
            "source_mode": source_mode,
            "output_path": None,
        }

    output_path = write_public_run_manifest(project_root, payload)
    return {
        "status": "success",
        "valid": True,
        "errors": [],
        "source_mode": source_mode,
        "output_path": str(output_path),
    }


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Generate frontend public run_manifest.json")
    parser.add_argument(
        "--project-root",
        default=None,
        help="Ruta root del proyecto. Por defecto usa el root del repositorio.",
    )
    parser.add_argument(
        "--require-metadata",
        action="store_true",
        help="Falla si la metadata pública no se puede generar como payload válido.",
    )
    parser.add_argument(
        "--force-disable",
        action="store_true",
        help="Omite generación sin importar el env flag USE_PUBLIC_RUN_MANIFEST.",
    )
    return parser


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")

    parser = _build_parser()
    args = parser.parse_args()

    if args.force_disable or not _is_enabled():
        logger.info("[RUN][SUMMARY] status=skipped reason=USE_PUBLIC_RUN_MANIFEST_disabled")
        return 0

    project_root = Path(args.project_root) if args.project_root else Path(__file__).resolve().parent.parent
    require_metadata = bool(args.require_metadata or _is_required())

    try:
        summary = generate_manifest_public(project_root, require_metadata=require_metadata)
    except Exception as exc:  # pylint: disable=broad-exception-caught
        logger.error("[RUN][SUMMARY] status=failed require_metadata=%s error=%s", require_metadata, exc)
        return 1

    logger.info(
        "[RUN][SUMMARY] status=%s valid=%s source_mode=%s output=%s errors=%d",
        summary["status"],
        summary["valid"],
        summary["source_mode"],
        summary["output_path"],
        len(summary["errors"]),
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
