from pathlib import Path

import pandas as pd

import validate_csv_contract


def test_validate_contract_strict_ok(tmp_path, monkeypatch):
    csv_path = tmp_path / "a.csv"
    pd.DataFrame({"col1": [1], "col2": ["x"]}).to_csv(csv_path, index=False)

    monkeypatch.setattr(
        validate_csv_contract,
        "CSV_SCHEMA_CONTRACT",
        {
            "test_csv": {
                "required_columns": ["col1", "col2"],
                "critical_columns": ["col1"],
                "column_types": {"col1": "integer", "col2": "string"},
            }
        },
    )
    monkeypatch.setattr(validate_csv_contract, "ARCHIVOS_SALIDA", {"test_csv": Path(csv_path)})

    ok, messages = validate_csv_contract.validate_contract(strict=True)
    assert ok is True
    assert any("[OK] test_csv" in m for m in messages)


def test_validate_contract_warn_only_missing_file(tmp_path, monkeypatch):
    csv_path = tmp_path / "missing.csv"

    monkeypatch.setattr(
        validate_csv_contract,
        "CSV_SCHEMA_CONTRACT",
        {
            "test_csv": {
                "required_columns": ["col1"],
                "critical_columns": ["col1"],
                "column_types": {"col1": "integer"},
            }
        },
    )
    monkeypatch.setattr(validate_csv_contract, "ARCHIVOS_SALIDA", {"test_csv": Path(csv_path)})

    ok, messages = validate_csv_contract.validate_contract(strict=False)
    assert ok is True
    assert any("[WARN] test_csv" in m for m in messages)
