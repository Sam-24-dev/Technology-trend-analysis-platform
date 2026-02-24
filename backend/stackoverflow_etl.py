"""
StackOverflow ETL - Technology Trend Analysis Platform

Extrae datos de preguntas desde la API de StackOverflow para analizar
tendencias tecnológicas: volumen de preguntas, tasas de respuestas
aceptadas y tendencias mensuales por lenguaje.

Autor: Andres
"""
import requests
import pandas as pd
import time
from datetime import datetime
import calendar

from config.settings import (
    SO_API_URL, SO_API_KEY,
    FECHA_INICIO, FECHA_INICIO_TIMESTAMP,
    REQUEST_TIMEOUT_SECONDS, HTTP_MAX_RETRIES, HTTP_RETRY_BACKOFF_SECONDS,
    REQUEST_MEDIUM_DELAY_SECONDS, REQUEST_SHORT_DELAY_SECONDS
)
from exceptions import ETLExtractionError
from base_etl import BaseETL


class StackOverflowETL(BaseETL):
    """Extractor ETL para datos de preguntas de StackOverflow."""

    def __init__(self):
        super().__init__("stackoverflow")

    def definir_pasos(self):
        """Define los pasos del ETL de StackOverflow."""
        return [
            ("Volumen de preguntas", self.extraer_volumen_preguntas),
            ("Tasa de aceptacion", self.calcular_tasa_aceptacion),
            ("Tendencias mensuales", self.generar_tendencias_mensuales),
        ]

    def validar_configuracion(self):
        """Advierte cuando falta la key de StackOverflow (modo de cuota reducida)."""
        if not SO_API_KEY:
            self.logger.warning(
                "STACKOVERFLOW_KEY no configurado. Se ejecutara en modo degradado "
                "con cuota anonima y posible rate-limit."
            )

    def get_total_count(self, params):
        """Consulta la API devolviendo solo el conteo total de resultados.

        Raises:
            ETLExtractionError: Si falla la llamada a la API.
        """
        request_params = dict(params)
        request_params['filter'] = 'total'
        if SO_API_KEY:
            request_params['key'] = SO_API_KEY

        for intento in range(HTTP_MAX_RETRIES):
            try:
                response = requests.get(
                    SO_API_URL,
                    params=request_params,
                    timeout=REQUEST_TIMEOUT_SECONDS,
                )
                if response.status_code == 200:
                    return response.json().get('total', 0)

                self.logger.error(f"Error API {response.status_code}: {response.text}")
            except requests.exceptions.RequestException as e:
                self.logger.error(f"Error de conexion: {e}")

            if intento < HTTP_MAX_RETRIES - 1:
                time.sleep(HTTP_RETRY_BACKOFF_SECONDS * (intento + 1))

        raise ETLExtractionError("StackOverflow API no disponible tras reintentos")

    def extraer_volumen_preguntas(self):
        """Extrae el volumen anual de preguntas por lenguaje desde StackOverflow."""
        self.logger.info("[1/3] Obteniendo volumen TOTAL de preguntas...")
        languages = ['python', 'javascript', 'typescript', 'java', 'go']
        data_volumen = []
        errores = 0

        for lang in languages:
            self.logger.info(f"   Consultando StackOverflow para: [{lang}]...")
            params = {
                'site': 'stackoverflow',
                'tagged': lang,
                'fromdate': FECHA_INICIO_TIMESTAMP
            }

            try:
                total = self.get_total_count(params)
            except ETLExtractionError as e:
                self.logger.warning(f"   No se pudo obtener datos para {lang}: {e}")
                total = 0
                errores += 1

            data_volumen.append({
                'lenguaje': lang,
                'preguntas_nuevas_2025': total
            })
            time.sleep(REQUEST_MEDIUM_DELAY_SECONDS)

        if errores == len(languages):
            raise ETLExtractionError("No se pudo consultar ningun lenguaje en StackOverflow")

        df_volumen = pd.DataFrame(data_volumen)
        self.guardar_csv(df_volumen, "so_volumen")

    def calcular_tasa_aceptacion(self):
        """Calcula tasas de respuestas aceptadas por framework como métrica de madurez."""
        self.logger.info("[2/3] Calculando metricas de madurez...")
        frameworks = ['reactjs', 'vue.js', 'angular', 'next.js', 'svelte']
        data_madurez = []
        errores = 0

        for fw in frameworks:
            self.logger.info(f"   Analizando [{fw}]...")

            try:
                params_total = {
                    'site': 'stackoverflow',
                    'tagged': fw,
                    'fromdate': FECHA_INICIO_TIMESTAMP
                }
                total_questions = self.get_total_count(params_total)
                time.sleep(REQUEST_SHORT_DELAY_SECONDS)

                params_accepted = {
                    'site': 'stackoverflow',
                    'tagged': fw,
                    'fromdate': FECHA_INICIO_TIMESTAMP,
                    'accepted': True
                }
                accepted_questions = self.get_total_count(params_accepted)
                time.sleep(REQUEST_SHORT_DELAY_SECONDS)
            except ETLExtractionError as e:
                self.logger.warning(f"   No se pudo obtener datos para {fw}: {e}")
                total_questions = 0
                accepted_questions = 0
                errores += 1

            rate = 0
            if total_questions > 0:
                rate = round((accepted_questions / total_questions) * 100, 2)

            data_madurez.append({
                'tecnologia': fw,
                'total_preguntas': total_questions,
                'respuestas_aceptadas': accepted_questions,
                'tasa_aceptacion_pct': rate
            })

        if errores == len(frameworks):
            raise ETLExtractionError("No se pudo consultar ningun framework en StackOverflow")

        df_madurez = pd.DataFrame(data_madurez)
        self.guardar_csv(df_madurez, "so_aceptacion")

    def generar_tendencias_mensuales(self):
        """Genera tendencias mensuales de preguntas para los lenguajes principales."""
        self.logger.info("[3/3] Generando historico mensual...")
        target_langs = ['python', 'javascript', 'typescript']
        data_trends = []

        inicio_year = FECHA_INICIO.year
        inicio_month = FECHA_INICIO.month

        for i in range(12):
            mes_idx = (inicio_month + i - 1) % 12 + 1
            year = inicio_year + (inicio_month + i - 1) // 12
            nombre_mes = calendar.month_abbr[mes_idx]
            mes_label = f"{year}-{mes_idx:02d}"

            start_date = datetime(year, mes_idx, 1)
            last_day = calendar.monthrange(year, mes_idx)[1]
            end_date = datetime(year, mes_idx, last_day, 23, 59, 59)

            ts_start = int(start_date.timestamp())
            ts_end = int(end_date.timestamp())

            if start_date > datetime.now():
                self.logger.info(f"   Saltando {nombre_mes} {year} (futuro)...")
                row = {'mes': mes_label, 'python': 0, 'javascript': 0, 'typescript': 0}
                data_trends.append(row)
                continue

            self.logger.info(f"   Consultando {nombre_mes} {year}...")
            row = {'mes': mes_label}

            for lang in target_langs:
                params = {
                    'site': 'stackoverflow',
                    'tagged': lang,
                    'fromdate': ts_start,
                    'todate': ts_end
                }
                try:
                    count = self.get_total_count(params)
                except ETLExtractionError as e:
                    self.logger.warning(f"   Error en {nombre_mes}/{lang}: {e}")
                    count = 0
                row[lang] = count
                time.sleep(REQUEST_SHORT_DELAY_SECONDS)

            data_trends.append(row)

        df_trends = pd.DataFrame(data_trends)
        self.guardar_csv(df_trends, "so_tendencias")


def main():
    """Punto de entrada para el pipeline ETL de StackOverflow."""
    etl = StackOverflowETL()
    etl.ejecutar()


if __name__ == "__main__":
    main()