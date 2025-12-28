import requests
import pandas as pd
import time
import os
import sys
from datetime import datetime, timedelta
import calendar

# CONFIGURACIÓN DE RUTAS 
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

try:
    import config
except ImportError:
    print("Usando configuración por defecto (sin config.py)")
    class config:
        SO_API_URL = "https://api.stackexchange.com/2.3/search/advanced"
        SO_API_KEY = None

# Configuración API
API_URL = config.SO_API_URL
DATE_START_2025 = 1735689600 # 1 Enero 2025

# Carpetas
OUTPUT_DIR = "datos"
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

def get_total_count(params):
    """ Función auxiliar para obtener solo el conteo total usando filter='total' """
    # El filtro 'total' es nativo de la API y devuelve solo el número total de items
    params['filter'] = 'total' 
    if config.SO_API_KEY:
        params['key'] = config.SO_API_KEY
    
    try:
        response = requests.get(API_URL, params=params)
        if response.status_code == 200:
            return response.json().get('total', 0)
        else:
            print(f"Error API {response.status_code}: {response.text}")
            return 0
    except Exception as e:
        print(f"Error de conexión: {e}")
        return 0

print(" INICIANDO ETL STACKOVERFLOW (DATOS 100% REALES) ")
print(f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
print("NOTA: Este proceso puede tardar 1-2 minutos debido a las múltiples consultas mensuales.\n")


# 1. Volumen de preguntas 2025

print("[1/3] Obteniendo volumen TOTAL de preguntas (2025)...")
languages = ['python', 'javascript', 'typescript', 'java', 'go']
data_volumen = []

for lang in languages:
    print(f"   > Consultando StackOverflow para: [{lang}]...")
    params = {
        'site': 'stackoverflow',
        'tagged': lang,
        'fromdate': DATE_START_2025
    }
    total = get_total_count(params)
    
    data_volumen.append({
        'lenguaje': lang, 
        'preguntas_nuevas_2025': total
    })
    time.sleep(0.5) # Respetar límites

df_volumen = pd.DataFrame(data_volumen)
df_volumen.to_csv(f"{OUTPUT_DIR}/so_volumen_preguntas.csv", index=False)
print(f"   ✓ Datos guardados en {OUTPUT_DIR}/so_volumen_preguntas.csv")


# 2.  Tasa de Respuestas Aceptadas

print("\n[2/3] Calculando métricas de madurez (Tasa de Aceptación Real)...")
frameworks = ['reactjs', 'vue.js', 'angular', 'next.js', 'svelte']
data_madurez = []

for fw in frameworks:
    print(f"   > Analizando [{fw}] (Total vs Aceptadas)...")
    
    # 1. Total de preguntas del framework en 2025
    params_total = {
        'site': 'stackoverflow',
        'tagged': fw,
        'fromdate': DATE_START_2025
    }
    total_questions = get_total_count(params_total)
    time.sleep(0.3)

    # 2. Total de preguntas CON respuesta aceptada
    params_accepted = {
        'site': 'stackoverflow',
        'tagged': fw,
        'fromdate': DATE_START_2025,
        'accepted': True # Filtro mágico de la API
    }
    accepted_questions = get_total_count(params_accepted)
    time.sleep(0.3)

    # Cálculo
    rate = 0
    if total_questions > 0:
        rate = round((accepted_questions / total_questions) * 100, 2)

    data_madurez.append({
        'tecnologia': fw,
        'total_preguntas': total_questions,
        'respuestas_aceptadas': accepted_questions,
        'tasa_aceptacion_pct': rate
    })

df_madurez = pd.DataFrame(data_madurez)
df_madurez.to_csv(f"{OUTPUT_DIR}/so_tasa_aceptacion.csv", index=False)
print(f"   ✓ Datos guardados.")


# 3. Tendencias Mensuales 

print("\n[3/3] Generando histórico mensual REAL (consultando mes a mes)...")
target_langs = ['python', 'javascript', 'typescript']
data_trends = []

# Generar rangos de fechas para los meses de 2025 que ya han pasado
current_year = 2025
current_month = datetime.now().month

# Loop por cada mes hasta el actual
for mes_idx in range(1, 13): # 1 a 12
    # Si estamos en mayo, no consultamos junio/dic
    if mes_idx > current_month: 
        break
        
    nombre_mes = calendar.month_abbr[mes_idx]
    
    # Calcular timestamps inicio y fin del mes
    start_date = datetime(current_year, mes_idx, 1)
    # Truco para obtener el último día del mes
    last_day = calendar.monthrange(current_year, mes_idx)[1]
    end_date = datetime(current_year, mes_idx, last_day, 23, 59, 59)
    
    ts_start = int(start_date.timestamp())
    ts_end = int(end_date.timestamp())
    
    print(f"   > Consultando {nombre_mes} 2025...")
    
    row = {'mes': nombre_mes}
    
    for lang in target_langs:
        params = {
            'site': 'stackoverflow',
            'tagged': lang,
            'fromdate': ts_start,
            'todate': ts_end
        }
        count = get_total_count(params)
        row[lang] = count
        time.sleep(0.3) # Pausa pequeña entre lenguajes
        
    data_trends.append(row)

df_trends = pd.DataFrame(data_trends)
df_trends.to_csv(f"{OUTPUT_DIR}/so_tendencias_mensuales.csv", index=False)

print("\nPROCESO COMPLETADO EXITOSAMENTE ")