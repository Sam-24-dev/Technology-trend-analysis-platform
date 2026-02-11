# Architecture — Technology Trend Analysis Platform

## System Overview

Multi-source data platform that extracts, transforms, and visualizes technology trend data from three developer communities: GitHub, StackOverflow, and Reddit.

## Data Flow

```
                    ┌──────────────┐
                    │  .env        │
                    │  (API Keys)  │
                    └──────┬───────┘
                           │
          ┌────────────────┼────────────────┐
          ▼                ▼                ▼
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │  GitHub API  │ │StackOverflow│ │ Reddit JSON  │
   │  (REST)     │ │  API (REST) │ │  (Public)    │
   └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
          │                │                │
          ▼                ▼                ▼
   ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
   │ github_etl  │ │ so_etl      │ │ reddit_etl  │
   │  .py        │ │  .py        │ │  .py        │
   └──────┬──────┘ └──────┬──────┘ └──────┬──────┘
          │                │                │
          └────────────────┼────────────────┘
                           ▼
                  ┌─────────────────┐
                  │   datos/ (CSV)  │
                  │ Single Source   │
                  │   of Truth      │
                  └────────┬────────┘
                           │
                    sync_assets.py
                           │
                           ▼
                  ┌─────────────────┐
                  │ frontend/assets │
                  │   /data/ (CSV)  │
                  └────────┬────────┘
                           │
                           ▼
                  ┌─────────────────┐
                  │  Flutter Web    │
                  │  Dashboard      │
                  │  (fl_chart)     │
                  └─────────────────┘
```

## Data Schema

### GitHub Datasets

| File | Columns | Description |
|------|---------|-------------|
| `github_repos_2025.csv` | repo_name, language, stars, forks, created_at, description | Top 1000 repos created in 2025 |
| `github_lenguajes.csv` | lenguaje, repos_count, porcentaje | Top 10 languages by repo count |
| `github_commits_frameworks.csv` | framework, repo, commits_2025, ranking | Frontend framework commit activity |
| `github_correlacion.csv` | repo_name, stars, contributors, language | Stars vs Contributors correlation |

### StackOverflow Datasets

| File | Columns | Description |
|------|---------|-------------|
| `so_volumen_preguntas.csv` | lenguaje, preguntas_nuevas_2025 | Question volume by language |
| `so_tasa_aceptacion.csv` | tecnologia, total_preguntas, respuestas_aceptadas, tasa_aceptacion_pct | Accepted answer rate by framework |
| `so_tendencias_mensuales.csv` | mes, python, javascript, typescript | Monthly question trends |

### Reddit Datasets

| File | Columns | Description |
|------|---------|-------------|
| `reddit_sentimiento_frameworks.csv` | framework, total_menciones, positivos, neutros, negativos, % positivo, % neutro, % negativo | Sentiment analysis for backend frameworks |
| `reddit_temas_emergentes.csv` | tema, menciones | Emerging topics in r/webdev |
| `interseccion_github_reddit.csv` | tecnologia, tipo, ranking_github, ranking_reddit, diferencia | Cross-platform technology ranking comparison |

## Frontend Architecture

```
Flutter Web Dashboard
├── HomeScreen        → KPIs globales, insights
├── GithubDashboard   → 3 graficos (barras, donut, scatter)
├── SODashboard       → 3 graficos (barras, stacked, lineas)
└── RedditDashboard   → 3 graficos (divergentes, barras, rankings)

Cada dashboard incluye:
  - Carga de CSV via CsvService
  - Graficos interactivos (fl_chart)
  - Key Insights section
  - Exportar ZIP
```

## Deployment

### Local Development
```bash
# Backend ETL
make install
make etl

# Frontend
cd frontend
flutter pub get
flutter run -d chrome
```

### Production (GitHub Pages)
```bash
cd frontend
flutter build web --base-href "/Technology-trend-analysis-platform/"
# Deploy build/web/ to gh-pages branch
```

### Automated Updates (GitHub Actions)
- Cron: Every Monday at 06:00 UTC
- Runs full ETL pipeline
- Syncs CSVs to frontend assets
- Rebuilds and deploys Flutter Web
