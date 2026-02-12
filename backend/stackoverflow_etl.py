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
import logging
from datetime import datetime
import calendar

from config.settings import (
    SO_API_URL, SO_API_KEY, ARCHIVOS_SALIDA, DATOS_DIR,
    LOG_FORMAT, LOG_DATE_FORMAT, LOGS_DIR,
    FECHA_INICIO, FECHA_INICIO_TIMESTAMP
)
from exceptions import ETLExtractionError, ETLValidationError
from validador import validar_dataframe

# Logger para este modulo
logger = logging.getLogger("stackoverflow_etl")


def configurar_logging():
    """Sets up logging to console and daily log file."""
    logger.setLevel(logging.INFO)

    if logger.handlers:
        return

    console = logging.StreamHandler()
    console.setLevel(logging.INFO)
    console.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
    logger.addHandler(console)

    fecha = datetime.now().strftime("%Y-%m-%d")
    archivo = LOGS_DIR / f"etl_{fecha}.log"
    file_handler = logging.FileHandler(archivo, encoding="utf-8")
    file_handler.setLevel(logging.INFO)
    file_handler.setFormatter(logging.Formatter(LOG_FORMAT, LOG_DATE_FORMAT))
    logger.addHandler(file_handler)


def get_total_count(params):
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
            logger.error(f"Error API {response.status_code}: {response.text}")
            raise ETLExtractionError(f"StackOverflow API retorno {response.status_code}")
    except requests.exceptions.RequestException as e:
        logger.error(f"Error de conexion: {e}")
        raise ETLExtractionError(f"Error de red: {e}")


def extraer_volumen_preguntas():
    """Extracts yearly question volume per language from StackOverflow."""
    logger.info("[1/3] Obteniendo volumen TOTAL de preguntas...")
    languages = ['python', 'javascript', 'typescript', 'java', 'go']
    data_volumen = []
    errores = 0

    for lang in languages:
        logger.info(f"   Consultando StackOverflow para: [{lang}]...")
        params = {
            'site': 'stackoverflow',
            'tagged': lang,
            'fromdate': FECHA_INICIO_TIMESTAMP
        }

        try:
            total = get_total_count(params)
        except ETLExtractionError as e:
            logger.warning(f"   No se pudo obtener datos para {lang}: {e}")
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
    validar_dataframe(df_volumen, "so_volumen")
    df_volumen.to_csv(ARCHIVOS_SALIDA["so_volumen"], index=False)
    logger.info(f"Datos guardados en {ARCHIVOS_SALIDA['so_volumen']}")

    return df_volumen


def calcular_tasa_aceptacion():
    """Calculates accepted answer rates per framework as a maturity metric."""
    logger.info("[2/3] Calculando metricas de madurez...")
    frameworks = ['reactjs', 'vue.js', 'angular', 'next.js', 'svelte']
    data_madurez = []
    errores = 0

    for fw in frameworks:
        logger.info(f"   Analizando [{fw}]...")

        try:
            params_total = {
                'site': 'stackoverflow',
                'tagged': fw,
                'fromdate': FECHA_INICIO_TIMESTAMP
            }
            total_questions = get_total_count(params_total)
            time.sleep(0.3)

            params_accepted = {
                'site': 'stackoverflow',
                'tagged': fw,
                'fromdate': FECHA_INICIO_TIMESTAMP,
                'accepted': True
            }
            accepted_questions = get_total_count(params_accepted)
            time.sleep(0.3)
        except ETLExtractionError as e:
            logger.warning(f"   No se pudo obtener datos para {fw}: {e}")
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
    validar_dataframe(df_madurez, "so_aceptacion")
    df_madurez.to_csv(ARCHIVOS_SALIDA["so_aceptacion"], index=False)
    logger.info(f"Datos guardados en {ARCHIVOS_SALIDA['so_aceptacion']}")

    return df_madurez


def generar_tendencias_mensuales():
    """Generates monthly question trends for top languages."""
    logger.info("[3/3] Generando historico mensual...")
    target_langs = ['python', 'javascript', 'typescript']
    data_trends = []

    # Calcular los ultimos 12 meses desde FECHA_INICIO
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
            logger.info(f"   Saltando {nombre_mes} {year} (futuro)...")
            row = {'mes': f"{nombre_mes} {year}", 'python': 0, 'javascript': 0, 'typescript': 0}
            data_trends.append(row)
            continue

        logger.info(f"   Consultando {nombre_mes} {year}...")
        row = {'mes': f"{nombre_mes} {year}"}

        for lang in target_langs:
            params = {
                'site': 'stackoverflow',
                'tagged': lang,
                'fromdate': ts_start,
                'todate': ts_end
            }
            try:
                count = get_total_count(params)
            except ETLExtractionError as e:
                logger.warning(f"   Error en {nombre_mes}/{lang}: {e}")
                count = 0
            row[lang] = count
            time.sleep(0.3)

        data_trends.append(row)

    df_trends = pd.DataFrame(data_trends)
    validar_dataframe(df_trends, "so_tendencias")
    df_trends.to_csv(ARCHIVOS_SALIDA["so_tendencias"], index=False)
    logger.info(f"Datos guardados en {ARCHIVOS_SALIDA['so_tendencias']}")

    return df_trends


def main():
    """Main function that runs the complete StackOverflow ETL pipeline.
    Each step is independent so one failure does not stop the others.
    """
    configurar_logging()

    logger.info("StackOverflow ETL - Technology Trend Analysis Platform")
    logger.info(f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    try:
        extraer_volumen_preguntas()
    except ETLExtractionError as e:
        logger.error(f"Extraccion de volumen fallida: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en volumen: {e}")

    try:
        calcular_tasa_aceptacion()
    except ETLExtractionError as e:
        logger.error(f"Calculo de tasa fallido: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en tasa: {e}")

    try:
        generar_tendencias_mensuales()
    except ETLExtractionError as e:
        logger.error(f"Tendencias mensuales fallidas: {e}")
    except Exception as e:
        logger.error(f"Error inesperado en tendencias: {e}")

    logger.info("ETL StackOverflow completado")


if __name__ == "__main__":
    main()