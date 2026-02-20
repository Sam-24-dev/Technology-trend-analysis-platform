import pandas as pd

from config.csv_contract import CSV_SCHEMA_CONTRACT, get_contract_version
from config.settings import ARCHIVOS_SALIDA


def test_contract_includes_trend_score_schema():
    contract = CSV_SCHEMA_CONTRACT["trend_score"]
    assert "ranking" in contract["required_columns"]
    assert "tecnologia" in contract["required_columns"]
    assert "trend_score" in contract["required_columns"]


def test_reddit_sentimiento_contract_supports_frontend_percentages():
    contract = CSV_SCHEMA_CONTRACT["reddit_sentimiento"]
    optional = contract.get("optional_columns", [])
    assert "% positivo" in optional
    assert "% negativo" in optional


def test_current_csv_headers_match_required_contract_for_core_dashboards():
    targets = ["github_lenguajes", "so_volumen", "so_aceptacion", "reddit_temas", "trend_score"]
    for key in targets:
        df = pd.read_csv(ARCHIVOS_SALIDA[key], nrows=1)
        required = CSV_SCHEMA_CONTRACT[key]["required_columns"]
        missing = [col for col in required if col not in df.columns]
        assert not missing, f"{key} tiene columnas faltantes: {missing}"


def test_contract_version_is_defined():
    version = get_contract_version()
    assert isinstance(version, str)
    assert version.strip()
