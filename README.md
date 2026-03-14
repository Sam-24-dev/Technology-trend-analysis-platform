# Tech Trends — Technology Trend Analysis Platform

<div align="center">

![Python](https://img.shields.io/badge/Python-3.11-3776AB?style=for-the-badge&logo=python&logoColor=white)
![Flutter](https://img.shields.io/badge/Flutter-Web-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![ETL](https://img.shields.io/badge/ETL-Weekly-success?style=for-the-badge)
![Data](https://img.shields.io/badge/Data-Contracts-blueviolet?style=for-the-badge)
![License](https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge)

<br>

<a href="https://sam-24-dev.github.io/Technology-trend-analysis-platform/">
  <img src="https://img.shields.io/badge/Live_Demo-View_Dashboard-0078D4?style=for-the-badge&logo=github&logoColor=white" />
</a>

</div>

---

## Project Overview

| Challenge | Solution | Impact |
|---|---|---|
| Multi-source tech trends with consistent scoring | Canonical ETL pipeline + Trend Score bridge | Stable, explainable rankings |
| Fragile frontend assumptions | Bridge-first JSON + CSV fallback | Resilient UI under data changes |
| Weekly refresh without regressions | CI gates + data contracts | Predictable releases |

---

## Key Metrics (Latest Run)

| Metric | Value |
|---|---|
| Repos classified | 931 |
| StackOverflow questions (annual window) | 33,356 |
| Reddit mentions (emerging topics) | 366 |
| Technologies in ranking | 22 |
| Window | 2025-03-13 → 2026-03-13 (UTC) |

---

## Pipeline Architecture

```
┌──────────────┐     ┌────────────────┐     ┌──────────────────┐     ┌──────────────────┐
│   GitHub     │     │ StackOverflow  │     │     Reddit       │     │  Trend Score     │
│   ETL        │────▶│     ETL        │────▶│      ETL          │────▶│ + Bridges JSON   │
└──────────────┘     └────────────────┘     └──────────────────┘     └──────────────────┘
                                                              │
                                                              ▼
                                                   frontend/assets/data
```

---

## Tech Stack

| Layer | Technologies |
|---|---|
| Data | Python, pandas, duckdb, pandera |
| ETL | Custom pipelines + contracts |
| Frontend | Flutter Web |
| Hosting | GitHub Pages |

---

## Quick Start

```bash
# backend
pip install -r backend/requirements.txt
python -m pytest -q

# run ETLs
python backend/github_etl.py
python backend/stackoverflow_etl.py
python backend/reddit_etl.py
python backend/trend_score.py
python backend/sync_assets.py

# frontend
cd frontend
flutter pub get
flutter run -d chrome
```

---

## Automation (GitHub Actions)

1. **ETL Weekly Refresh** (`etl_semanal.yml`)
   - Schedule: Monday `08:00 UTC`
   - Runs all ETLs, Trend Score, syncs assets, validates contracts, and publishes data.
2. **Dependency Security** (`dependency_security.yml`)
   - Schedule: Monday `09:00 UTC`
   - Runs `pip-audit` against `backend/requirements.txt`.
3. **Deploy Frontend** (`deploy_frontend.yml`)
   - Publishes Flutter Web to GitHub Pages.

---

## Project Structure

```
Technology-trend-analysis-platform/
├── backend/                       # ETLs + Trend Score + contracts
├── datos/                         # CSV outputs (legacy + latest + history)
├── frontend/                      # Flutter Web UI
├── docs/                          # Technical docs
├── scripts/                       # CI / assets validation helpers
└── .github/workflows/             # CI + ETL automation
```

---

<div align="center">

### Author

**Samir Caizapasto**  
*Junior Data Engineer & Analyst*

<div style="display: flex; justify-content: center; gap: 10px; margin-bottom: 10px;">
  <a href="https://portafolio-samir-tau.vercel.app/">
    <img src="https://img.shields.io/badge/🌐_Portfolio-Visit_Website-success?style=for-the-badge&logo=vercel&logoColor=white" />
  </a>
  <a href="https://www.linkedin.com/in/samir-caizapasto/">
    <img src="https://img.shields.io/badge/LinkedIn-Connect-0A66C2?style=for-the-badge&logo=linkedin&logoColor=white" />
  </a>
  <a href="mailto:samir.leonardo.caizapasto04@gmail.com">
    <img src="https://img.shields.io/badge/Email-Contact_Me-EA4335?style=for-the-badge&logo=gmail&logoColor=white" />
  </a>
</div>

</div>

---

If you find this project useful, please give the repository a star.
