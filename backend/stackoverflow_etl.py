import requests
import pandas as pd
import time
import os
import sys
from datetime import datetime, timedelta
import calendar

# Añadir directorio actual al path para importar módulos locales
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

# Configuración: Intenta cargar credenciales, usa valores por defecto si falla
try:
    import config
except ImportError:
    print("Usando configuración por defecto (sin config.py)")
    class config:
        SO_API_URL = "https://api.stackexchange.com/2.3/search/advanced"
        SO_API_KEY = None

API_URL = config.SO_API_URL
DATE_START_2025 = 1735689600  # Timestamp para 1 de Enero 2025

# Garantizar que el directorio de salida existe
OUTPUT_DIR = "datos"
if not os.path.exists(OUTPUT_DIR):
    os.makedirs(OUTPUT_DIR)

def get_total_count(params):
    """
    Consulta la API devolviendo solo el número total de resultados.
    Usa el filtro 'total' para ahorrar ancho de banda y cuota de API.
    """
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

print(" INICIANDO ETL STACKOVERFLOW ")
print(f"Fecha: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

# --- 1. Volumen de Preguntas (Total Anual) ---
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
    time.sleep(0.5) # Pausa para respetar el Rate Limit de la API

df_volumen = pd.DataFrame(data_volumen)
df_volumen.to_csv(f"{OUTPUT_DIR}/so_volumen_preguntas.csv", index=False)
print(f"   ✓ Datos guardados en {OUTPUT_DIR}/so_volumen_preguntas.csv")


# --- 2. Tasa de Respuestas Aceptadas (Métrica de Calidad) ---
print("\n[2/3] Calculando métricas de madurez...")
frameworks = ['reactjs', 'vue.js', 'angular', 'next.js', 'svelte']
data_madurez = []

for fw in frameworks:
    print(f"   > Analizando [{fw}]...")
    
    # Consulta 1: Total de preguntas
    params_total = {
        'site': 'stackoverflow',
        'tagged': fw,
        'fromdate': DATE_START_2025
    }
    total_questions = get_total_count(params_total)
    time.sleep(0.3)

    # Consulta 2: Preguntas con respuesta aceptada (accepted=True)
    params_accepted = {
        'site': 'stackoverflow',
        'tagged': fw,
        'fromdate': DATE_START_2025,
        'accepted': True 
    }
    accepted_questions = get_total_count(params_accepted)
    time.sleep(0.3)

    # Cálculo del porcentaje
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


# --- 3. Tendencias Mensuales (Histórico) ---
print("\n[3/3] Generando histórico mensual...")
target_langs = ['python', 'javascript', 'typescript']
data_trends = []
current_year = 2025

# Iterar mes a mes (1 al 12)
for mes_idx in range(1, 13): 
    nombre_mes = calendar.month_abbr[mes_idx]
    
    # Calcular rango de fechas (timestamps) para el mes específico
    start_date = datetime(current_year, mes_idx, 1)
    last_day = calendar.monthrange(current_year, mes_idx)[1]
    end_date = datetime(current_year, mes_idx, last_day, 23, 59, 59)
    
    ts_start = int(start_date.timestamp())
    ts_end = int(end_date.timestamp())
    
    # Evitar consultas a meses futuros
    if start_date > datetime.now():
        print(f"   > Saltando {nombre_mes} (Futuro)...")
        row = {'mes': nombre_mes, 'python': 0, 'javascript': 0, 'typescript': 0}
        data_trends.append(row)
        continue

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
        time.sleep(0.3) 
        
    data_trends.append(row)

df_trends = pd.DataFrame(data_trends)
df_trends.to_csv(f"{OUTPUT_DIR}/so_tendencias_mensuales.csv", index=False)

print("\nPROCESO COMPLETADO EXITOSAMENTE")