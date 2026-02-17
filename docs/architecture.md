# Architecture -- Technology Trend Analysis Platform

## System Overview

Plataforma multi-fuente que extrae, transforma y visualiza datos de tendencias tecnologicas
desde tres comunidades de desarrolladores: GitHub, StackOverflow y Reddit.

## Data Flow

```
                    .env (API Keys)
                         |
          +--------------+--------------+
          v              v              v
   GitHub API    StackOverflow API   Reddit API
     (REST)         (REST)          (OAuth/JSON)
          |              |              |
          v              v              v
   github_etl.py  so_etl.py      reddit_etl.py
          |              |              |
          +--------------+--------------+
                         v
                   datos/ (CSV)
                 Fuente de Verdad
                         |
                  sync_assets.py
                         |
                         v
              frontend/assets/data/
                         |
                         v
               Flutter Web Dashboard
                    (fl_chart)
```

## Data Schema

### GitHub

| Archivo | Columnas | Descripcion |
|---------|----------|-------------|
| github_repos_2025.csv | repo_name, language, stars, forks, created_at, description | Top 1000 repos creados en 2025 |
| github_lenguajes.csv | lenguaje, repos_count, porcentaje | Top 10 lenguajes por cantidad de repos |
| github_commits_frameworks.csv | framework, repo, commits_2025, ranking | Actividad de commits en frameworks frontend |
| github_correlacion.csv | repo_name, stars, contributors, language | Correlacion Stars vs Contributors |

### StackOverflow

| Archivo | Columnas | Descripcion |
|---------|----------|-------------|
| so_volumen_preguntas.csv | lenguaje, preguntas_nuevas_2025 | Volumen de preguntas por lenguaje |
| so_tasa_aceptacion.csv | tecnologia, total_preguntas, respuestas_aceptadas, tasa_aceptacion_pct | Tasa de respuestas aceptadas por framework |
| so_tendencias_mensuales.csv | mes, python, javascript, typescript | Tendencias mensuales de preguntas |

### Reddit

| Archivo | Columnas | Descripcion |
|---------|----------|-------------|
| reddit_sentimiento_frameworks.csv | framework, total_menciones, positivos, neutros, negativos, % positivo, % neutro, % negativo | Analisis de sentimiento para frameworks backend |
| reddit_temas_emergentes.csv | tema, menciones | Temas emergentes en r/webdev |
| interseccion_github_reddit.csv | tecnologia, tipo, ranking_github, ranking_reddit, diferencia | Comparacion de rankings entre plataformas |

### Trend Score

| Archivo | Columnas | Descripcion |
|---------|----------|-------------|
| trend_score.csv | ranking, tecnologia, github_score, so_score, reddit_score, trend_score, fuentes | Indice compuesto ponderado (GitHub 40% + SO 35% + Reddit 25%) |

## Frontend Architecture

```
Flutter Web Dashboard
  HomeScreen          - KPIs globales, insights
  GithubDashboard     - 3 graficos (barras, donut, scatter)
  SODashboard         - 3 graficos (barras, stacked, lineas)
  RedditDashboard     - 3 graficos (divergentes, barras, rankings)

Cada dashboard incluye:
  - Carga de CSV via CsvService
  - Graficos interactivos (fl_chart)
  - Key Insights
  - Exportar ZIP
```

## Deployment

### Local
```bash
# Backend
make install
make etl

# Frontend
cd frontend
flutter pub get
flutter run -d chrome
```

### GitHub Pages
```bash
cd frontend
flutter build web --base-href "/Technology-trend-analysis-platform/"
```

### Automatizacion (GitHub Actions)
- Cron: cada lunes a las 08:00 UTC (03:00 Ecuador)
- Ejecuta el pipeline ETL completo
- Sincroniza CSVs al frontend
- Rebuild y deploy de Flutter Web
