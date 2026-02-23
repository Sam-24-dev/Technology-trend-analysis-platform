"""Validates CSV outputs against the shared backend/frontend contract.

Used in CI/ETL to detect incompatible schema changes
before publishing data to the frontend.
"""

import logging
import sys
from pathlib import Path

import pandas as pd

from config.csv_contract import CSV_SCHEMA_CONTRACT, get_contract_version
from config.settings import ARCHIVOS_SALIDA
from exceptions import ETLValidationError
from validador import validar_dataframe


logger = logging.getLogger("validate_csv_contract")


def validate_contract(strict=True, enable_pandera=True, pandera_warn_only=True):
    """Validates CSV files and routes quality issues by severity.

    Args:
        strict: Enforces required schema and type checks.
        enable_pandera: Enables/disables the Pandera quality stage.
        pandera_warn_only: Routes Pandera critical issues as warnings when True.

    Returns:
        tuple(bool, list[str]): (overall_ok, messages)
    """
    mode = "strict" if strict else "warn-only"
    pandera_mode = "warn-only" if pandera_warn_only else "strict"
    messages = [
        f"Validating CSV contract v{get_contract_version()} "
        f"(mode={mode}, pandera_enabled={enable_pandera}, pandera_mode={pandera_mode})"
    ]
    ok = True

    for logical_name in CSV_SCHEMA_CONTRACT:
        csv_path = Path(ARCHIVOS_SALIDA[logical_name])

        if not csv_path.exists():
            messages.append(f"[WARN] {logical_name}: file not found ({csv_path.name})")
            if strict:
                ok = False
            continue

        try:
            df = pd.read_csv(csv_path)
            quality_report = validar_dataframe(
                df=df,
                nombre_archivo=logical_name,
                strict=strict,
                validate_types=True,
                enable_pandera=enable_pandera,
                pandera_warn_only=pandera_warn_only,
                return_quality_report=True,
            )

            critical = int(quality_report["critical"])
            warning = int(quality_report["warning"])
            info = int(quality_report["info"])

            if critical > 0:
                if pandera_warn_only:
                    messages.append(
                        f"[WARN] {logical_name}: quality critical={critical} routed by warn-only mode"
                    )
                else:
                    messages.append(
                        f"[ERROR] {logical_name}: quality gate failed (critical={critical})"
                    )
                    ok = False
                    continue

            if warning > 0:
                messages.append(f"[WARN] {logical_name}: quality warnings={warning}")
            if info > 0:
                messages.append(f"[INFO] {logical_name}: quality info={info}")

            messages.append(f"[OK] {logical_name}: contract valid")
        except ETLValidationError as exc:
            messages.append(f"[ERROR] {logical_name}: {exc}")
            ok = False
        except Exception as exc:  # pylint: disable=broad-exception-caught
            messages.append(f"[ERROR] {logical_name}: validation execution failed ({exc})")
            ok = False

    return ok, messages


def main():
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")
    strict = "--no-strict" not in sys.argv
    enable_pandera = "--skip-pandera" not in sys.argv
    pandera_warn_only = "--pandera-strict" not in sys.argv

    ok, messages = validate_contract(
        strict=strict,
        enable_pandera=enable_pandera,
        pandera_warn_only=pandera_warn_only,
    )

    for msg in messages:
        if msg.startswith("[ERROR]"):
            logger.error(msg)
        elif msg.startswith("[WARN]"):
            logger.warning(msg)
        else:
            logger.info(msg)

    if not ok:
        logger.error("[RUN][SUMMARY] status=failed")
        sys.exit(1)

    logger.info("[RUN][SUMMARY] status=success")


if __name__ == "__main__":
    main()
