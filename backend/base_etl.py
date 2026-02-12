"""
Base ETL class for the Technology Trend Analysis Platform.

Provides a standardized Extract-Transform-Load pattern that all
ETL scripts inherit from. Handles logging setup, data validation,
and CSV output in a consistent way.

Usage:
    class GitHubETL(BaseETL):
        def extraer(self):
            # fetch data from GitHub API
            return raw_data

        def transformar(self, datos_crudos):
            # process raw data
            return processed_df
"""
import logging
from datetime import datetime
from abc import ABC, abstractmethod

from config.settings import LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR, DATOS_DIR
from exceptions import ETLExtractionError, ETLValidationError
from validador import validar_dataframe


class BaseETL(ABC):
    """Base class for all ETL extractors.

    Provides common functionality: logging, validation, and CSV output.
    Subclasses must implement extraer() and transformar().
    """

    def __init__(self, nombre_fuente):
        """Initializes the ETL with source name and logger.

        Args:
            nombre_fuente: Name of the data source (e.g. 'github', 'reddit').
        """
        self.nombre = nombre_fuente
        self.logger = logging.getLogger(nombre_fuente)
        self.resultados = {}

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

    @abstractmethod
    def extraer(self):
        """Extracts raw data from the source.

        Must be implemented by subclasses.

        Returns:
            Raw data (dict, list, or DataFrame).

        Raises:
            ETLExtractionError: If extraction fails.
        """
        raise NotImplementedError

    @abstractmethod
    def transformar(self, datos_crudos):
        """Transforms raw data into processed DataFrames.

        Must be implemented by subclasses.

        Args:
            datos_crudos: Raw data from extraer().

        Returns:
            dict: Mapping of output names to DataFrames.
                  e.g. {"github_repos": df_repos, "github_lenguajes": df_langs}
        """
        raise NotImplementedError

    def cargar(self, datos_procesados, archivos_salida):
        """Saves processed DataFrames to CSV files.

        Validates each DataFrame before saving. Logs warnings
        for any validation issues but does not stop execution.

        Args:
            datos_procesados: dict mapping names to DataFrames.
            archivos_salida: dict mapping names to file paths.
        """
        for nombre, df in datos_procesados.items():
            ruta = archivos_salida.get(nombre)
            if ruta is None:
                self.logger.warning(f"No hay ruta de salida para '{nombre}', saltando...")
                continue

            try:
                validar_dataframe(df, nombre)
                df.to_csv(ruta, index=False, encoding="utf-8")
                self.logger.info(f"Guardado en: {ruta}")
            except ETLValidationError as e:
                self.logger.error(f"Validacion fallida para '{nombre}': {e}")
            except Exception as e:
                self.logger.error(f"Error guardando '{nombre}': {e}")

    def ejecutar(self):
        """Runs the complete ETL pipeline: Extract -> Transform -> Load.

        Each phase is wrapped in try/except so failures are logged
        but don't crash the entire pipeline.

        Returns:
            dict: The processed data, or empty dict on failure.
        """
        self.configurar_logging()
        self.logger.info(f"{self.nombre.upper()} ETL - Technology Trend Analysis Platform")

        # Extraer
        try:
            datos_crudos = self.extraer()
        except ETLExtractionError as e:
            self.logger.error(f"Extraccion fallida: {e}")
            return {}
        except Exception as e:
            self.logger.error(f"Error inesperado en extraccion: {e}")
            return {}

        # Transformar
        try:
            self.resultados = self.transformar(datos_crudos)
        except (ETLValidationError, ETLExtractionError) as e:
            self.logger.error(f"Transformacion fallida: {e}")
            return {}
        except Exception as e:
            self.logger.error(f"Error inesperado en transformacion: {e}")
            return {}

        self.logger.info(f"ETL {self.nombre} completado")
        return self.resultados
