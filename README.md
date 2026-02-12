# Tech Trends 2025

<div align="center">

![Data Engineer](https://img.shields.io/badge/Role-Data_Engineer-orange?style=for-the-badge&logo=apache-spark&logoColor=white)
![Python](https://img.shields.io/badge/Python-3.9+-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-3.38-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Status](https://img.shields.io/badge/Status-Completed-success?style=for-the-badge)
![Tests](https://img.shields.io/badge/Tests-40_Passed-brightgreen?style=for-the-badge&logo=pytest&logoColor=white)
![CI](https://github.com/Sam-24-dev/Technology-trend-analysis-platform/actions/workflows/ci.yml/badge.svg)

<br>

<a href="https://sam-24-dev.github.io/Technology-trend-analysis-platform/">
  <img src="https://img.shields.io/badge/View_Live_Demo-Dashboard-2EA44F?style=for-the-badge&logo=google-chrome&logoColor=white" />
</a>

</div>

---

## Project Overview

End-to-end data engineering platform that extracts, transforms, and visualizes technology trends from the three largest developer communities: GitHub, StackOverflow, and Reddit.

| Challenge | Solution | Impact |
|-----------|----------|--------|
| Fragmented trend data | Multi-source ETL pipeline | Unified technology ranking |
| No cross-platform comparison | Composite Trend Score index | Weighted ranking across 3 sources |
| Manual analysis | Automated pipeline with OOP | Repeatable, testable, maintainable |
| Raw data, no insights | Interactive Flutter dashboard | Real-time trend visualization |

> **Core Value:** This platform demonstrates a production-grade data pipeline that ingests from 3 APIs, applies NLP sentiment analysis, and produces a composite ranking — the kind of system that powers real technology intelligence products.

---

## Pipeline Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   GitHub    │     │StackOverflow│     │   Reddit    │
│     API     │     │     API     │     │   JSON API  │
└──────┬──────┘     └──────┬──────┘     └──────┬──────┘
       │                   │                   │
       ▼                   ▼                   ▼
┌─────────────────────────────────────────────────────┐
│              BaseETL (Abstract Class)                │
│   configurar_logging() · guardar_csv() · ejecutar() │
├─────────────┬─────────────────┬─────────────────────┤
│ GitHubETL   │ StackOverflowETL│     RedditETL       │
│ 4 analyses  │   3 analyses    │   3 analyses + NLP  │
└──────┬──────┘────────┬────────┘──────────┬──────────┘
       │               │                   │
       ▼               ▼                   ▼
┌─────────────────────────────────────────────────────┐
│                 datos/ (10 CSVs)                     │
│    Validated by validador.py before each save        │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│              Trend Score Engine                      │
│  GitHub 40% + StackOverflow 35% + Reddit 25%        │
│  Min-max normalization · Outer join · Ranking        │
└──────────────────────┬──────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────┐
│            Flutter Web Dashboard                     │
│  4 views · fl_chart · Export ZIP · Responsive        │
└─────────────────────────────────────────────────────┘
```

| Layer | Component | Output |
|-------|-----------|--------|
| **Extraction** | 3 API connectors | Raw data from GitHub, SO, Reddit |
| **Transformation** | BaseETL + 3 children | 10 processed CSVs |
| **Scoring** | trend_score.py | Unified technology ranking |
| **Validation** | validador.py | Column checks + null detection |
| **Presentation** | Flutter Web | 4 interactive dashboards |

---

## Key Metrics & Results

| Metric | Value |
|--------|-------|
| **Repositories analyzed** | 1,000 |
| **StackOverflow questions** | 5 languages + 5 frameworks |
| **Reddit posts** | 500+ from r/webdev |
| **Output CSVs** | 10 validated datasets |
| **Trend Score** | Top technology ranking |
| **Tests** | 40 passing (pytest) |
| **Code coverage** | All ETL modules tested |

---

## Dashboard Features

| Page | Visualizations |
|------|----------------|
| **Home** | Executive KPIs, global insights, navigation |
| **GitHub** | Top 10 languages · Framework commits · Stars vs Contributors correlation |
| **StackOverflow** | Question volume · Acceptance rates · Monthly trends (Python/JS/TS) |
| **Reddit** | Framework sentiment · Emerging topics · GitHub-Reddit intersection |

Each dashboard includes **Key Insights** cards and an **Export ZIP** button.

---

## Tech Stack

| Layer | Technologies |
|-------|--------------|
| **ETL Pipeline** | Python 3.9+, pandas, requests, NLTK |
| **Architecture** | BaseETL (OOP), custom exceptions, data validation |
| **Testing** | pytest, unittest.mock (40 tests, API mocking) |
| **Frontend** | Flutter Web, Dart, fl_chart, google_fonts |
| **Data Storage** | CSV (10 files, pathlib paths) |
| **Automation** | Makefile, sync_assets.py |
| **Deployment** | GitHub Pages |

---

## Quick Start

```bash
# Clone repository
git clone https://github.com/Sam-24-dev/Technology-trend-analysis-platform.git
cd Technology-trend-analysis-platform

# Install dependencies
make install

# Run full pipeline (ETL + Trend Score)
make etl

# Run tests
make test

# Sync CSVs to frontend
make sync

# Or run everything at once
make all
```

### Environment Setup

Create a `.env` file in the project root:
```env
GITHUB_TOKEN=your_github_personal_access_token
STACKOVERFLOW_KEY=your_so_api_key  # optional
```

### Run Frontend

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

> **Note:** Pre-processed data is included in `datos/`. Only run ETL if you need fresh data.

---

## Project Structure

```
Technology-trend-analysis-platform/
├── backend/                          # ETL Pipeline (Python)
│   ├── config/
│   │   ├── __init__.py
│   │   └── settings.py              # Centralized config (pathlib, dates)
│   ├── base_etl.py                  # Abstract ETL base class (OOP)
│   ├── github_etl.py                # GitHubETL: 4 analysis steps
│   ├── stackoverflow_etl.py         # StackOverflowETL: 3 analysis steps
│   ├── reddit_etl.py                # RedditETL: 3 analysis steps + NLP
│   ├── trend_score.py               # Composite index (3 sources)
│   ├── validador.py                 # DataFrame validation before save
│   ├── exceptions.py                # ETLExtractionError, ETLValidationError
│   ├── sync_assets.py               # Copy CSVs to frontend
│   └── requirements.txt
├── datos/                            # Processed CSVs (10 files)
├── docs/
│   └── architecture.md
├── frontend/                         # Flutter Web Dashboard
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/                  # 5 screens (home, github, so, reddit)
│   │   ├── models/                   # Data models per source
│   │   ├── services/                 # CSV parsing service
│   │   └── widgets/                  # Reusable chart card
│   ├── assets/
│   │   ├── data/                     # CSVs for visualization
│   │   └── images/                   # Technology logos
│   └── pubspec.yaml
├── logs/                             # Daily ETL logs
├── tests/                            # pytest suite (40 tests)
│   ├── conftest.py
│   ├── test_github_etl.py
│   ├── test_stackoverflow_etl.py
│   ├── test_reddit_etl.py
│   └── test_trend_score.py
├── .env.example
├── .gitignore
├── LICENSE
├── Makefile                          # make install/etl/test/sync/all
└── README.md
```

---

## Scalability & Roadmap

- **Orchestration:** Pipeline structure is compatible with Apache Airflow for scheduled runs
- **Database:** Migration path to PostgreSQL/BigQuery for data warehousing
- **Containerization:** Ready for Docker deployment
- **CI/CD:** GitHub Actions for automated testing and deployment
- **API Layer:** FastAPI integration for programmatic data access

---

## Team

| Member | Role | Responsibility |
|--------|------|----------------|
| **Samir Caizapasto** | Lead Developer | GitHub ETL + Dashboard + Architecture |
| **Andrés Salinas** | Developer | StackOverflow ETL + Dashboard |
| **Mateo Mayorga** | Developer | Reddit ETL + Dashboard + NLP |

---

<div align="center">

### Author

**Samir Caizapasto**
*Junior Data Engineer & Analyst*

[![](https://img.shields.io/badge/LinkedIn-Connect-0077B5?style=for-the-badge&logo=linkedin)](https://www.linkedin.com/in/samir-caizapasto/)
[![](https://img.shields.io/badge/Portfolio-Visit-00d4ff?style=for-the-badge&logo=vercel)](https://portafolio-samir-tau.vercel.app/)
[![](https://img.shields.io/badge/GitHub-Follow-181717?style=for-the-badge&logo=github)](https://github.com/Sam-24-dev)

</div>

---

<div align="center">

⭐ If this project demonstrates useful data engineering practices, please give it a star.

</div>
