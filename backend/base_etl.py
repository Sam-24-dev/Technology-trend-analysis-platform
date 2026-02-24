"""
Clase base ETL para Technology Trend Analysis Platform.

Proporciona un patron estandar de Extract-Transform-Load del
que heredan todos los scripts ETL. Maneja configuracion de logging,
validacion de datos y salida CSV de forma consistente.

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
from datetime import datetime, timezone
from abc import ABC, abstractmethod
from time import perf_counter

from config.settings import LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR, ARCHIVOS_SALIDA
from config.settings import (
    WRITE_LEGACY_CSV,
    WRITE_LATEST_CSV,
    WRITE_HISTORY_CSV,
    get_latest_output_path,
    get_history_output_path,
)
from exceptions import ETLExtractionError, ETLValidationError
from validador import validar_dataframe


class BaseETL(ABC):
    """Clase base para todos los extractores ETL.

    Las subclases deben implementar definir_pasos() retornando
    una lista de tuplas (nombre, funcion). Cada paso se ejecuta
    de forma independiente para que un fallo no detenga los demas.
    """

    def __init__(self, nombre_fuente):
        """Inicializa ETL con nombre de fuente y logger.

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
        """Configura logging en consola y archivo diario."""
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
        """Valida y guarda un DataFrame en uno o mas destinos CSV.

        Args:
            df: DataFrame a guardar.
            nombre_archivo: Clave de ARCHIVOS_SALIDA (ej. 'github_repos').

        Raises:
            ETLValidationError: Si el DataFrame esta vacio.
        """
        ruta_legacy = ARCHIVOS_SALIDA.get(nombre_archivo)
        if ruta_legacy is None:
            self.logger.warning("No hay ruta de salida para '%s'", nombre_archivo)
            return

        validar_dataframe(df, nombre_archivo)

        destinos = []
        if WRITE_LEGACY_CSV:
            destinos.append(("legacy", ruta_legacy))
        if WRITE_LATEST_CSV:
            ruta_latest = get_latest_output_path(nombre_archivo)
            if ruta_latest is not None:
                destinos.append(("latest", ruta_latest))
        if WRITE_HISTORY_CSV:
            ruta_history = get_history_output_path(nombre_archivo, fecha=datetime.now(timezone.utc))
            if ruta_history is not None:
                destinos.append(("history", ruta_history))

        if not destinos:
            self.logger.warning(
                "Escritura deshabilitada para '%s' (sin destinos activos por config)",
                nombre_archivo,
            )
            return

        rutas_escritas = set()
        for salida, ruta in destinos:
            ruta = ruta.resolve()
            if ruta in rutas_escritas:
                continue
            ruta.parent.mkdir(parents=True, exist_ok=True)
            df.to_csv(ruta, index=False, encoding="utf-8")
            rutas_escritas.add(ruta)
            self._run_summary["files_written"].append(str(ruta))
            self.logger.info("[WRITE] archivo=%s destino=%s filas=%d", ruta, salida, len(df))

        filas = len(df)
        self._run_summary["rows_written"] += filas

    @abstractmethod
    def definir_pasos(self):
        """Define pasos ETL a ejecutar.

        Debe implementarse en subclases.

        Returns:
            list: Lista de tuplas (nombre_paso, funcion_paso).
                  Cada funcion se llama sin argumentos.
                  Usa self para compartir datos entre pasos.

        Ejemplo:
            return [
                ("Extraccion", self.extraer_repos),
                ("Lenguajes", self.analizar_lenguajes),
            ]
        """
        raise NotImplementedError

    def validar_configuracion(self):
        """Valida configuracion ETL antes de ejecutar pasos.

        Las subclases pueden sobrescribir este metodo para exigir
        variables de entorno o checks de consistencia. Lanza
        ETLExtractionError(critical=True) para detener temprano.
        """
        return

    def ejecutar(self):
        """Ejecuta el pipeline ETL completo.

        Llama configurar_logging() y luego ejecuta cada paso de
        definir_pasos() en forma independiente con try/except.
        Si un paso lanza ETLExtractionError con critical=True,
        el pipeline se detiene y sale con codigo 1.
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
        """Registra resumen compacto de ejecucion para observabilidad."""
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
