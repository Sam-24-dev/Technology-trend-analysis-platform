"""
StackOverflow ETL - Technology Trend Analysis Platform

Extracts question data from the StackOverflow API to analyze
technology trends: question volume, accepted answer rates,
and monthly trends by language.

Author: Andres
"""
import requests
import pandas as pd
import time
from datetime import datetime
import calendar

from config.settings import (
    SO_API_URL, SO_API_KEY,
    FECHA_INICIO, FECHA_INICIO_TIMESTAMP
)
from exceptions import ETLExtractionError
from base_etl import BaseETL


class StackOverflowETL(BaseETL):
    """ETL extractor for StackOverflow question data."""

    def __init__(self):
        super().__init__("stackoverflow")

    def definir_pasos(self):
        """Defines the StackOverflow ETL steps."""
        return [
            ("Volumen de preguntas", self.extraer_volumen_preguntas),
            ("Tasa de aceptacion", self.calcular_tasa_aceptacion),
            ("Tendencias mensuales", self.generar_tendencias_mensuales),
        ]

    def get_total_count(self, params):
        """Queries the API returning only the total result count.

        Raises:
            ETLExtractionError: If the API call fails.
        """
        params['filter'] = 'total'
        if SO_API_KEY:
            params['key'] = SO_API_KEY

        try:
            response = requests.get(SO_API_URL, params=params, timeout=10)
            if response.status_code == 200:
                return response.json().get('total', 0)
            else:
                self.logger.error(f"Error API {response.status_code}: {response.text}")
                raise ETLExtractionError(f"StackOverflow API retorno {response.status_code}")
        except requests.exceptions.RequestException as e:
            self.logger.error(f"Error de conexion: {e}")
            raise ETLExtractionError(f"Error de red: {e}") from e

    def extraer_volumen_preguntas(self):
        """Extracts yearly question volume per language from StackOverflow."""
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
            time.sleep(0.5)

        if errores == len(languages):
            raise ETLExtractionError("No se pudo consultar ningun lenguaje en StackOverflow")

        df_volumen = pd.DataFrame(data_volumen)
        self.guardar_csv(df_volumen, "so_volumen")

    def calcular_tasa_aceptacion(self):
        """Calculates accepted answer rates per framework as a maturity metric."""
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
                time.sleep(0.3)

                params_accepted = {
                    'site': 'stackoverflow',
                    'tagged': fw,
                    'fromdate': FECHA_INICIO_TIMESTAMP,
                    'accepted': True
                }
                accepted_questions = self.get_total_count(params_accepted)
                time.sleep(0.3)
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
        """Generates monthly question trends for top languages."""
        self.logger.info("[3/3] Generando historico mensual...")
        target_langs = ['python', 'javascript', 'typescript']
        data_trends = []

        inicio_year = FECHA_INICIO.year
        inicio_month = FECHA_INICIO.month

        for i in range(12):
            mes_idx = (inicio_month + i - 1) % 12 + 1
            year = inicio_year + (inicio_month + i - 1) // 12
            nombre_mes = calendar.month_abbr[mes_idx]

            start_date = datetime(year, mes_idx, 1)
            last_day = calendar.monthrange(year, mes_idx)[1]
            end_date = datetime(year, mes_idx, last_day, 23, 59, 59)

            ts_start = int(start_date.timestamp())
            ts_end = int(end_date.timestamp())

            if start_date > datetime.now():
                self.logger.info(f"   Saltando {nombre_mes} {year} (futuro)...")
                row = {'mes': f"{nombre_mes} {year}", 'python': 0, 'javascript': 0, 'typescript': 0}
                data_trends.append(row)
                continue

            self.logger.info(f"   Consultando {nombre_mes} {year}...")
            row = {'mes': f"{nombre_mes} {year}"}

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
                time.sleep(0.3)

            data_trends.append(row)

        df_trends = pd.DataFrame(data_trends)
        self.guardar_csv(df_trends, "so_tendencias")


def main():
    """Entry point for the StackOverflow ETL pipeline."""
    etl = StackOverflowETL()
    etl.ejecutar()


if __name__ == "__main__":
    main()