"""
Base ETL class for the Technology Trend Analysis Platform.

Provides a standardized Extract-Transform-Load pattern that all
ETL scripts inherit from. Handles logging setup, data validation,
and CSV output in a consistent way.

Usage:
    class GitHubETL(BaseETL):
        def definir_pasos(self):
            return [
                ("Extraccion de repos", self.extraer_repos),
                ("Analisis de lenguajes", self.analizar_lenguajes),
            ]
"""
import logging
import sys
from datetime import datetime
from abc import ABC, abstractmethod

from config.settings import LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR, ARCHIVOS_SALIDA
from exceptions import ETLExtractionError, ETLValidationError
from validador import validar_dataframe


class BaseETL(ABC):
    """Base class for all ETL extractors.

    Subclasses must implement definir_pasos() returning a list
    of (name, function) tuples. Each step runs independently
    so one failure doesn't stop the others.
    """

    def __init__(self, nombre_fuente):
        """Initializes the ETL with source name and logger.

        Args:
            nombre_fuente: Name of the data source (e.g. 'github', 'reddit').
        """
        self.nombre = nombre_fuente
        self.logger = logging.getLogger(nombre_fuente)

    def configurar_logging(self):
        """Sets up logging to console and daily log file."""
        self.logger.setLevel(logging.INFO)

        if self.logger.handlers:
            return

        console = logging.StreamHandler()
        console.setLevel(logging.INFO)
        console.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
        self.logger.addHandler(console)

        fecha = datetime.now().strftime("%Y-%m-%d")
        archivo = LOGS_DIR / f"etl_{fecha}.log"
        file_handler = logging.FileHandler(archivo, encoding="utf-8")
        file_handler.setLevel(logging.INFO)
        file_handler.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
        self.logger.addHandler(file_handler)

    def guardar_csv(self, df, nombre_archivo):
        """Validates and saves a DataFrame to CSV.

        Args:
            df: DataFrame to save.
            nombre_archivo: Key from ARCHIVOS_SALIDA (e.g. 'github_repos').

        Raises:
            ETLValidationError: If the DataFrame is empty.
        """
        ruta = ARCHIVOS_SALIDA.get(nombre_archivo)
        if ruta is None:
            self.logger.warning(f"No hay ruta de salida para '{nombre_archivo}'")
            return

        validar_dataframe(df, nombre_archivo)
        df.to_csv(ruta, index=False, encoding="utf-8")
        self.logger.info(f"Guardado en: {ruta}")

    @abstractmethod
    def definir_pasos(self):
        """Defines the ETL steps to execute.

        Must be implemented by subclasses.

        Returns:
            list: List of tuples (step_name, step_function).
                  Each function is called with no arguments.
                  Use self to share data between steps.

        Example:
            return [
                ("Extraccion", self.extraer_repos),
                ("Lenguajes", self.analizar_lenguajes),
            ]
        """
        raise NotImplementedError

    def ejecutar(self):
        """Runs the complete ETL pipeline.

        Calls configurar_logging(), then runs each step from
        definir_pasos() independently with try/except.
        If a step raises ETLExtractionError with critical=True,
        the pipeline stops and exits with code 1.
        """
        self.configurar_logging()
        self.logger.info(f"{self.nombre.upper()} ETL - Technology Trend Analysis Platform")

        pasos = self.definir_pasos()
        errores_criticos = 0

        for nombre_paso, funcion in pasos:
            try:
                funcion()
            except ETLExtractionError as e:
                self.logger.error(f"{nombre_paso} fallido: {e}")
                if getattr(e, 'critical', False):
                    self.logger.error("Error critico, deteniendo pipeline")
                    errores_criticos += 1
                    break
            except ETLValidationError as e:
                self.logger.error(f"{nombre_paso} - validacion fallida: {e}")
            except Exception as e:
                self.logger.error(f"{nombre_paso} - error inesperado: {e}")

        if errores_criticos > 0:
            self.logger.error(f"ETL {self.nombre} finalizado con errores criticos")
            sys.exit(1)

        self.logger.info(f"ETL {self.nombre} completado")
