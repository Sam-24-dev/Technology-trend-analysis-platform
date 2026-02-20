import pandas as pd
import pytest

from exceptions import ETLValidationError
from validador import validar_dataframe


def test_validar_dataframe_raises_on_empty():
    df = pd.DataFrame()
    with pytest.raises(ETLValidationError):
        validar_dataframe(df, "github_lenguajes")


def test_validar_dataframe_ok_returns_true():
    df = pd.DataFrame(
        {
            "lenguaje": ["Python", "TypeScript"],
            "repos_count": [10, 8],
            "porcentaje": [55.0, 45.0],
        }
    )

    assert validar_dataframe(df, "github_lenguajes") is True


def test_validar_dataframe_warns_missing_columns(caplog):
    df = pd.DataFrame(
        {
            "framework": ["Django"],
            "positivos": [10],
        }
    )

    with caplog.at_level("WARNING"):
        result = validar_dataframe(df, "reddit_sentimiento")

    assert result is True
    assert "Columnas faltantes" in caplog.text


def test_validar_dataframe_warns_nulls_in_critical(caplog):
    df = pd.DataFrame(
        {
            "repo_name": ["org/repo1", None],
            "stars": [100, None],
            "contributors": [10, 20],
            "language": ["Python", "Go"],
        }
    )

    with caplog.at_level("WARNING"):
        result = validar_dataframe(df, "github_correlacion")

    assert result is True
    assert "tiene" in caplog.text and "nulos" in caplog.text


def test_validar_dataframe_strict_raises_on_missing_required_columns():
    df = pd.DataFrame(
        {
            "framework": ["Django"],
            "positivos": [10],
        }
    )

    with pytest.raises(ETLValidationError):
        validar_dataframe(df, "reddit_sentimiento", strict=True)


def test_validar_dataframe_strict_raises_on_invalid_type():
    df = pd.DataFrame(
        {
            "lenguaje": ["Python", "TypeScript"],
            "repos_count": ["x", "y"],
            "porcentaje": [55.0, 45.0],
        }
    )

    with pytest.raises(ETLValidationError):
        validar_dataframe(df, "github_lenguajes", strict=True, validate_types=True)
