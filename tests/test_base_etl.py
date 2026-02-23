import pandas as pd
import pytest

import base_etl
from base_etl import BaseETL
from exceptions import ETLExtractionError, ETLValidationError


class DummyETL(BaseETL):
    def __init__(self, steps):
        super().__init__("dummy")
        self._steps = steps

    def definir_pasos(self):
        return self._steps


def _configure_write_flags(monkeypatch, *, legacy=True, latest=False, history=False):
    monkeypatch.setattr(base_etl, "WRITE_LEGACY_CSV", legacy)
    monkeypatch.setattr(base_etl, "WRITE_LATEST_CSV", latest)
    monkeypatch.setattr(base_etl, "WRITE_HISTORY_CSV", history)


def test_ejecutar_continues_after_non_critical_extraction_error(monkeypatch):
    called = {"step2": False}

    def step1():
        raise ETLExtractionError("fallo no critico", critical=False)

    def step2():
        called["step2"] = True

    etl = DummyETL([("Paso 1", step1), ("Paso 2", step2)])
    monkeypatch.setattr(etl, "configurar_logging", lambda: None)

    etl.ejecutar()

    assert called["step2"] is True


def test_ejecutar_stops_on_critical_extraction_error(monkeypatch):
    def step1():
        raise ETLExtractionError("fallo critico", critical=True)

    etl = DummyETL([("Paso 1", step1)])
    monkeypatch.setattr(etl, "configurar_logging", lambda: None)

    with pytest.raises(SystemExit) as exc:
        etl.ejecutar()

    assert exc.value.code == 1


def test_ejecutar_continues_after_validation_error(monkeypatch):
    called = {"step2": False}

    def step1():
        raise ETLValidationError("validacion")

    def step2():
        called["step2"] = True

    etl = DummyETL([("Paso 1", step1), ("Paso 2", step2)])
    monkeypatch.setattr(etl, "configurar_logging", lambda: None)

    etl.ejecutar()

    assert called["step2"] is True


def test_guardar_csv_writes_file_when_route_exists(tmp_path, monkeypatch):
    destino = tmp_path / "out.csv"
    monkeypatch.setattr(base_etl, "ARCHIVOS_SALIDA", {"github_lenguajes": destino})
    _configure_write_flags(monkeypatch, legacy=True, latest=False, history=False)

    etl = DummyETL([])
    df = pd.DataFrame(
        {
            "lenguaje": ["Python"],
            "repos_count": [1],
            "porcentaje": [100.0],
        }
    )

    etl.guardar_csv(df, "github_lenguajes")

    assert destino.exists()


def test_guardar_csv_no_route_does_not_raise(monkeypatch):
    monkeypatch.setattr(base_etl, "ARCHIVOS_SALIDA", {})

    etl = DummyETL([])
    df = pd.DataFrame({"a": [1]})

    etl.guardar_csv(df, "inexistente")


def test_ejecutar_invoca_validar_configuracion(monkeypatch):
    called = {"config": False}

    class DummyWithConfig(DummyETL):
        def validar_configuracion(self):
            called["config"] = True

    etl = DummyWithConfig([])
    monkeypatch.setattr(etl, "configurar_logging", lambda: None)

    etl.ejecutar()

    assert called["config"] is True


def test_guardar_csv_actualiza_resumen_de_ejecucion(tmp_path, monkeypatch):
    destino = tmp_path / "out.csv"
    monkeypatch.setattr(base_etl, "ARCHIVOS_SALIDA", {"github_lenguajes": destino})
    _configure_write_flags(monkeypatch, legacy=True, latest=False, history=False)

    etl = DummyETL([])
    df = pd.DataFrame(
        {
            "lenguaje": ["Python", "Go"],
            "repos_count": [10, 5],
            "porcentaje": [66.6, 33.4],
        }
    )

    etl.guardar_csv(df, "github_lenguajes")

    assert etl._run_summary["rows_written"] == 2
    assert len(etl._run_summary["files_written"]) == 1


def test_guardar_csv_writes_legacy_and_latest_when_enabled(tmp_path, monkeypatch):
    legacy_destino = tmp_path / "legacy" / "out.csv"
    latest_destino = tmp_path / "latest" / "out.csv"

    monkeypatch.setattr(base_etl, "ARCHIVOS_SALIDA", {"github_lenguajes": legacy_destino})
    _configure_write_flags(monkeypatch, legacy=True, latest=True, history=False)
    monkeypatch.setattr(base_etl, "get_latest_output_path", lambda _nombre: latest_destino)

    etl = DummyETL([])
    df = pd.DataFrame(
        {
            "lenguaje": ["Python", "Go"],
            "repos_count": [10, 5],
            "porcentaje": [66.6, 33.4],
        }
    )

    etl.guardar_csv(df, "github_lenguajes")

    assert legacy_destino.exists()
    assert latest_destino.exists()
    assert etl._run_summary["rows_written"] == 2
    assert len(etl._run_summary["files_written"]) == 2


def test_guardar_csv_writes_history_only_when_enabled(tmp_path, monkeypatch):
    legacy_destino = tmp_path / "legacy" / "out.csv"
    history_destino = (
        tmp_path
        / "history"
        / "github_lenguajes"
        / "year=2026"
        / "month=03"
        / "day=01"
        / "out.csv"
    )

    monkeypatch.setattr(base_etl, "ARCHIVOS_SALIDA", {"github_lenguajes": legacy_destino})
    _configure_write_flags(monkeypatch, legacy=False, latest=False, history=True)
    monkeypatch.setattr(
        base_etl,
        "get_history_output_path",
        lambda _nombre, fecha=None: history_destino,
    )

    etl = DummyETL([])
    df = pd.DataFrame(
        {
            "lenguaje": ["Python"],
            "repos_count": [1],
            "porcentaje": [100.0],
        }
    )

    etl.guardar_csv(df, "github_lenguajes")

    assert not legacy_destino.exists()
    assert history_destino.exists()
    assert etl._run_summary["rows_written"] == 1
    assert len(etl._run_summary["files_written"]) == 1
