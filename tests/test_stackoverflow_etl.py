"""
Tests para stackoverflow_etl.py - módulo ETL de StackOverflow.

Los tests cubren:
- Cálculo de tasa de aceptación
- Formato y columnas del CSV de salida
- Mocking de API
"""
import pytest
import pandas as pd
from unittest.mock import patch, MagicMock
from stackoverflow_etl import StackOverflowETL


@pytest.fixture
def etl():
    """Crea una instancia de StackOverflowETL con logging configurado."""
    instance = StackOverflowETL()
    instance.configurar_logging()
    return instance


class TestDefinirPasos:
    """Tests para definir_pasos."""

    def test_returns_three_steps(self, etl):
        pasos = etl.definir_pasos()
        assert len(pasos) == 3

    def test_step_names(self, etl):
        pasos = etl.definir_pasos()
        nombres = [n for n, _ in pasos]
        assert "Volumen de preguntas" in nombres
        assert "Tasa de aceptacion" in nombres
        assert "Tendencias mensuales" in nombres


class TestGetTotalCount:
    """Tests para el helper get_total_count."""

    def test_returns_total_on_success(self, etl):
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"total": 4200}

        with patch("stackoverflow_etl.requests.get", return_value=mock_response):
            result = etl.get_total_count({"site": "stackoverflow", "tagged": "python"})

        assert result == 4200

    def test_raises_on_error(self, etl):
        mock_response = MagicMock()
        mock_response.status_code = 500
        mock_response.text = "Internal Server Error"

        with patch("stackoverflow_etl.requests.get", return_value=mock_response):
            with pytest.raises(Exception):
                etl.get_total_count({"site": "stackoverflow", "tagged": "python"})

    def test_does_not_mutate_input_params(self, etl):
        """Verifica que get_total_count no muta los params del caller."""
        mock_response = MagicMock()
        mock_response.status_code = 200
        mock_response.json.return_value = {"total": 10}

        params = {"site": "stackoverflow", "tagged": "python"}
        original = dict(params)

        with patch("stackoverflow_etl.requests.get", return_value=mock_response):
            etl.get_total_count(params)

        assert params == original


class TestTasaAceptacion:
    """Tests para calcular_tasa_aceptacion."""

    def test_correct_rate_calculation(self, etl, tmp_path):
        """Verifica que la tasa de aceptación se calcule correctamente."""
        call_count = [0]
        totals = [100, 75, 200, 150, 300, 200, 50, 30, 80, 40]

        def mock_get_total(*_args, **_kwargs):
            idx = call_count[0]
            call_count[0] += 1
            return totals[idx] if idx < len(totals) else 0

        with patch.object(etl, "get_total_count", side_effect=mock_get_total):
            with patch("base_etl.ARCHIVOS_SALIDA", {"so_aceptacion": tmp_path / "test.csv"}):
                etl.calcular_tasa_aceptacion()

        df = pd.read_csv(tmp_path / "test.csv")
        assert "tasa_aceptacion_pct" in df.columns
        assert "tecnologia" in df.columns
        assert len(df) == 5

        # Primer framework: 100 total, 75 aceptadas = 75%
        assert df.iloc[0]["tasa_aceptacion_pct"] == 75.0

    def test_output_format(self, etl, tmp_path):
        """Verifica que el CSV tenga todas las columnas requeridas."""
        with patch.object(etl, "get_total_count", return_value=100):
            with patch("base_etl.ARCHIVOS_SALIDA", {"so_aceptacion": tmp_path / "test.csv"}):
                etl.calcular_tasa_aceptacion()

        df = pd.read_csv(tmp_path / "test.csv")
        expected_cols = ["tecnologia", "total_preguntas", "respuestas_aceptadas", "tasa_aceptacion_pct"]
        for col in expected_cols:
            assert col in df.columns


class TestVolumenPreguntas:
    """Tests para extraer_volumen_preguntas."""

    def test_correct_output_columns(self, etl, tmp_path):
        """Verifica que la salida tenga columnas correctas."""
        with patch.object(etl, "get_total_count", return_value=500):
            with patch("base_etl.ARCHIVOS_SALIDA", {"so_volumen": tmp_path / "test.csv"}):
                etl.extraer_volumen_preguntas()

        df = pd.read_csv(tmp_path / "test.csv")
        assert "lenguaje" in df.columns
        assert "preguntas_nuevas_2025" in df.columns
        assert len(df) == 5

    def test_raises_when_all_fail(self, etl):
        """Verifica que lance excepción cuando todas las llamadas a API fallan."""
        from exceptions import ETLExtractionError

        with patch.object(etl, "get_total_count", side_effect=ETLExtractionError("fail")):
            with pytest.raises(ETLExtractionError):
                etl.extraer_volumen_preguntas()
