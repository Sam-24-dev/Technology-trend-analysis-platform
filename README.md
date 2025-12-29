# Technology Trend Analysis Platform

Plataforma de analisis de tendencias tecnologicas que extrae y visualiza datos de **GitHub**, **StackOverflow** y **Reddit** para facilitar decisiones informadas sobre tecnologias de desarrollo.

## Integrantes

- **Samir Caizapasto** - GitHub ETL
- **Andres Salinas** - StackOverflow ETL
- **Mateo Mayorga** - Reddit ETL

## Estado del Proyecto

| Componente | Estado | Descripcion |
|------------|--------|-------------|
| ETL Scripts | ✅ Completado | Extraccion de datos de las 3 fuentes |
| Datos CSV | ✅ Completado | Datasets generados en `/datos` |
| Base de Datos | ⏳ Pendiente | MySQL para almacenamiento |
| Backend API | ⏳ Pendiente | FastAPI REST endpoints |
| Frontend | ⏳ Pendiente | Flutter Web Dashboard |

## Estructura del Proyecto

```
Technology-trend-analysis-platform/
├── etl/                          # Scripts de extraccion
│   ├── github_etl.py             # Scraper GitHub (Samir)
│   ├── stackoverflow_etl.py      # Scraper StackOverflow (Andres)
│   ├── reddit_etl.py             # Scraper Reddit (Mateo)
│   ├── config.py                 # Configuracion compartida
│   └── requirements.txt          # Dependencias Python
├── datos/                        # CSVs generados
│   ├── github_repos_2025.csv
│   ├── github_lenguajes.csv
│   ├── github_commits_frameworks.csv
│   ├── github_correlacion.csv
│   ├── so_volumen_preguntas.csv
│   ├── so_tasa_aceptacion.csv
│   ├── so_tendencias_mensuales.csv
│   ├── reddit_sentimiento_frameworks.csv
│   ├── reddit_temas_emergentes.csv
│   └── interseccion_github_reddit.csv
├── backend/                      # (Pendiente) FastAPI
├── frontend/                     # (Pendiente) Flutter Web
└── README.md
```

## Instalacion

### 1. Clonar repositorio

```bash
git clone https://github.com/Sam-24-dev/Technology-trend-analysis-platform.git
cd Technology-trend-analysis-platform
```

### 2. Instalar dependencias

```bash
cd etl
pip install -r requirements.txt
```

### 3. Configurar credenciales

Crear archivo `.env` en la raiz del proyecto:

```
GITHUB_TOKEN=tu_token_aqui
```

### 4. Ejecutar ETL

```bash
python github_etl.py
python stackoverflow_etl.py
python reddit_etl.py
```

## Preguntas de Investigacion

### GitHub (Samir)
1. Top 10 lenguajes con mayor creacion de repos en 2025
2. Actividad de commits en frameworks frontend (React, Vue, Angular)
3. Correlacion entre Stars y Contributors

### StackOverflow (Andres)
1. Lenguajes con mayor volumen de preguntas en 2025
2. Tasa de respuestas aceptadas por tecnologia
3. Tendencias mensuales Python vs JavaScript vs TypeScript

### Reddit (Mateo)
1. Analisis de sentimiento en frameworks backend
2. Temas emergentes en r/webdev (IA, Cloud, Web3)
3. Interseccion de popularidad GitHub vs Reddit

## Tech Stack

| Categoria | Tecnologias |
|-----------|-------------|
| ETL | Python, Requests, Pandas, NLTK |
| Backend | FastAPI (pendiente) |
| Frontend | Flutter Web (pendiente) |
| Base de Datos | MySQL (pendiente) |
