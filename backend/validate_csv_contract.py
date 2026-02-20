"""Valida headers CSV contra el contrato backend/frontend.

Se utiliza en CI/ETL para detectar cambios incompatibles de esquema
antes de publicar datos al frontend.
"""

import sys
from pathlib import Path

import pandas as pd

from config.csv_contract import CSV_SCHEMA_CONTRACT, get_contract_version
from config.settings import ARCHIVOS_SALIDA


def _read_headers(csv_path):
    """Lee únicamente headers de un CSV y retorna lista de columnas."""
    df = pd.read_csv(csv_path, nrows=0)
    return list(df.columns)


def validate_contract():
    """Valida archivos CSV existentes contra columnas requeridas del contrato.

    Retorna:
        tuple(bool, list[str]): (ok_global, mensajes)
    """
    messages = [f"Validando contrato CSV v{get_contract_version()}..."]
    ok = True

    for logical_name, schema in CSV_SCHEMA_CONTRACT.items():
        csv_path = Path(ARCHIVOS_SALIDA[logical_name])
        required = schema.get("required_columns", [])

        if not csv_path.exists():
            messages.append(f"[WARN] {logical_name}: archivo no existe ({csv_path.name})")
            ok = False
            continue

        headers = _read_headers(csv_path)
        missing = [col for col in required if col not in headers]
        if missing:
            messages.append(
                f"[ERROR] {logical_name}: faltan columnas requeridas {missing} en {csv_path.name}"
            )
            ok = False
        else:
            messages.append(f"[OK] {logical_name}: contrato válido")

    return ok, messages


def main():
    ok, messages = validate_contract()
    for msg in messages:
        print(msg)

    if not ok:
        print("Validación de contrato CSV fallida")
        sys.exit(1)

    print("Validación de contrato CSV exitosa")


if __name__ == "__main__":
    main()
