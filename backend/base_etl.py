"""
Clase base ETL para la Technology Trend Analysis Platform.

Proporciona un patrón estandarizado de Extract-Transform-Load del
 cual heredan todos los scripts ETL. Maneja la configuración de 
 logging, validación de datos y salida a CSV de manera consistente.
Uso:
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
from time import perf_counter

from config.settings import LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR, ARCHIVOS_SALIDA
from exceptions import ETLExtractionError, ETLValidationError
from validador import validar_dataframe


class BaseETL(ABC):
    """Clase base para todos los extractores ETL.

Las subclases deben implementar definir_pasos(),
 retornando una lista de tuplas (nombre, función).
Cada paso se ejecuta de forma independiente, de modo 
que un fallo no detenga la ejecución de los demás..
    """

    def __init__(self, nombre_fuente):
        """Inicializa el ETL con el nombre de la fuente y el logger.

Args:
    nombre_fuente: Nombre de la fuente de datos (ej. 'github', 'reddit').
        """
        self.nombre = nombre_fuente
        self.logger = logging.getLogger(nombre_fuente)
        self._run_summary = {
            "steps": [],
            "files_written": [],
            "rows_written": 0,
            "non_critical_failures": 0,
            "critical_failures": 0,
        }

    def configurar_logging(self):
        """Configura el **logging** hacia la consola y
          hacia un archivo de log diario.
         """
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
        """Valida y guarda un DataFrame en formato CSV.

Args:
    df: DataFrame a guardar.
    nombre_archivo: Clave tomada de ARCHIVOS_SALIDA (ej. 'github_repos').

Raises:
    ETLValidationError: Si el DataFrame está vacío.
        """
        ruta = ARCHIVOS_SALIDA.get(nombre_archivo)
        if ruta is None:
            self.logger.warning("No hay ruta de salida para '%s'", nombre_archivo)
            return

        validar_dataframe(df, nombre_archivo)
        df.to_csv(ruta, index=False, encoding="utf-8")
        filas = len(df)
        self._run_summary["files_written"].append(str(ruta))
        self._run_summary["rows_written"] += filas
        self.logger.info("[WRITE] archivo=%s filas=%d", ruta, filas)

    @abstractmethod
    def definir_pasos(self):
        """Define los pasos ETL a ejecutar.

Debe ser implementado por las subclases.

Returns:
    list: Lista de tuplas (nombre_paso, funcion_paso).
        Cada función se ejecuta sin argumentos.
        Usa self para compartir datos entre los pasos.
        Ejemplo:
            return [
                ("Extraccion", self.extraer_repos),
                ("Lenguajes", self.analizar_lenguajes),
            ]
        """
        raise NotImplementedError

    def validar_configuracion(self):
        """Valida la configuración del ETL antes de ejecutar los pasos.

        Las subclases pueden sobrescribir este método para 
        exigir variables de entorno requeridas o realizar 
        verificaciones de consistencia.
        Lanza ETLExtractionError(critical=True) para detener 
        la ejecución anticipadamente.
        """
        return

    def ejecutar(self):
        """Ejecuta el pipeline completo de ETL.

        Llama a configurar_logging() y luego ejecuta cada paso
        definido en definir_pasos() de manera independiente usando 
        try/except.
        Si un paso lanza ETLExtractionError con critical=True, 
        el pipeline se detiene y finaliza con código de salida 1.
        """
        self.configurar_logging()
        run_start = perf_counter()
        self.logger.info("[RUN][START] fuente=%s", self.nombre)
        self.logger.info("%s ETL - Technology Trend Analysis Platform", self.nombre.upper())

        try:
            self.validar_configuracion()
        except ETLExtractionError as e:
            self.logger.error("Configuracion invalida: %s", e)
            if getattr(e, 'critical', False):
                self.logger.error("Error critico de configuracion, deteniendo pipeline")
                sys.exit(1)

        pasos = self.definir_pasos()
        errores_criticos = 0

        for nombre_paso, funcion in pasos:
            step_start = perf_counter()
            resultado = "success"
            mensaje = ""
            self.logger.info("[STEP][START] fuente=%s paso=%s", self.nombre, nombre_paso)
            try:
                funcion()
            except ETLExtractionError as e:
                self.logger.error("%s fallido: %s", nombre_paso, e)
                resultado = "failed_extraction"
                mensaje = str(e)
                if getattr(e, 'critical', False):
                    self.logger.error("Error critico, deteniendo pipeline")
                    errores_criticos += 1
                    self._run_summary["critical_failures"] += 1
                    break
                self._run_summary["non_critical_failures"] += 1
            except ETLValidationError as e:
                self.logger.error("%s - validacion fallida: %s", nombre_paso, e)
                resultado = "failed_validation"
                mensaje = str(e)
                self._run_summary["non_critical_failures"] += 1
            except Exception as e:  # pylint: disable=broad-exception-caught
                self.logger.error("%s - error inesperado: %s", nombre_paso, e)
                resultado = "failed_unexpected"
                mensaje = str(e)
                self._run_summary["non_critical_failures"] += 1
            finally:
                duracion = perf_counter() - step_start
                self._run_summary["steps"].append(
                    {
                        "name": nombre_paso,
                        "status": resultado,
                        "duration_s": round(duracion, 3),
                        "message": mensaje,
                    }
                )
                self.logger.info(
                    "[STEP][END] fuente=%s paso=%s estado=%s duracion_s=%.3f",
                    self.nombre,
                    nombre_paso,
                    resultado,
                    duracion,
                )

        if errores_criticos > 0:
            self.logger.error("ETL %s finalizado con errores criticos", self.nombre)
            self._log_summary(run_start, final_status="failed")
            sys.exit(1)

        self._log_summary(run_start, final_status="success")
        self.logger.info("ETL %s completado", self.nombre)

    def _log_summary(self, run_start, final_status):
        """Registra un resumen compacto de la ejecución para observabilidad."""
        total_duration = perf_counter() - run_start
        total_steps = len(self._run_summary["steps"])
        successful_steps = sum(1 for s in self._run_summary["steps"] if s["status"] == "success")

        self.logger.info(
            "[RUN][SUMMARY] fuente=%s estado=%s pasos_total=%d pasos_ok=%d "
            "fallos_no_criticos=%d fallos_criticos=%d archivos_escritos=%d filas_escritas=%d duracion_s=%.3f",
            self.nombre,
            final_status,
            total_steps,
            successful_steps,
            self._run_summary["non_critical_failures"],
            self._run_summary["critical_failures"],
            len(self._run_summary["files_written"]),
            self._run_summary["rows_written"],
            total_duration,
        )
