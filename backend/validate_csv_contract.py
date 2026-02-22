"""Validates CSV headers against the shared backend/frontend contract.

Used in CI/ETL to detect incompatible schema changes
before publishing data to the frontend.
"""

import sys
import logging
from pathlib import Path

import pandas as pd

from config.csv_contract import CSV_SCHEMA_CONTRACT, get_contract_version
from config.settings import ARCHIVOS_SALIDA
from exceptions import ETLValidationError
from validador import validar_dataframe


logger = logging.getLogger("validate_csv_contract")


def validate_contract(strict=True):
    """Validates existing CSV files against required contract columns.

    Returns:
        tuple(bool, list[str]): (overall_ok, messages)
    """
    mode = "strict" if strict else "warn-only"
    messages = [f"Validando contrato CSV v{get_contract_version()} (modo={mode})..."]
    ok = True

    for logical_name, schema in CSV_SCHEMA_CONTRACT.items():
        csv_path = Path(ARCHIVOS_SALIDA[logical_name])

        if not csv_path.exists():
            messages.append(f"[WARN] {logical_name}: archivo no existe ({csv_path.name})")
            if strict:
                ok = False
            continue

        try:
            df = pd.read_csv(csv_path)
            validar_dataframe(
                df,
                logical_name,
                strict=strict,
                validate_types=True,
            )
            messages.append(f"[OK] {logical_name}: contrato válido")
        except ETLValidationError as exc:
            messages.append(f"[ERROR] {logical_name}: {exc}")
            ok = False
        except Exception as exc:  # pylint: disable=broad-exception-caught
            messages.append(f"[ERROR] {logical_name}: no se pudo validar ({exc})")
            ok = False

    return ok, messages


def main():
    logging.basicConfig(level=logging.INFO, format="[%(asctime)s] [%(levelname)s] %(name)s - %(message)s")
    strict = "--no-strict" not in sys.argv
    ok, messages = validate_contract(strict=strict)
    for msg in messages:
        if msg.startswith("[ERROR]"):
            logger.error(msg)
        elif msg.startswith("[WARN]"):
            logger.warning(msg)
        else:
            logger.info(msg)

    if not ok:
        logger.error("[RUN][SUMMARY] estado=failed")
        sys.exit(1)

    logger.info("[RUN][SUMMARY] estado=success")


if __name__ == "__main__":
    main()
