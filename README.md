# Technology Trend Analysis Platform 

A comprehensive Data Intelligence Dashboard designed to analyze and visualize software development trends for 2025 using real-time data from **GitHub**, **StackOverflow**, and **Reddit**.

##  Project Overview

This platform solves the complexity of selecting technologies by providing data-driven insights on popularity, community support, and sentiment analysis.

##  Architecture

The system follows a decoupled Client-Server architecture with REST APIs:

* **ETL Layer:** Python scripts for automated data extraction (API & Scraping).
* **Data Layer:** MySQL database for structured storage.
* **Backend:** FastAPI (Python) serving REST endpoints.
* **Frontend:** Flutter Web for interactive data visualization.

##  Tech Stack

| Category | Technologies |
|----------|-------------|
| **Languages** | Python (Backend/ETL), Dart (Frontend), SQL |
| **Frameworks** | FastAPI, Flutter Web |
| **Data & Analytics** | Pandas, NumPy, MySQL |
| **Tools** | Git, GitHub |

##  Key Features

1. **GitHub Analytics:** Top languages by repo creation & commit activity.
2. **StackOverflow Insights:** Technology maturity via accepted answer rates.
3. **Community Sentiment:** Reddit analysis on backend frameworks.

##  Installation & Setup

### 1. Clone the repository

```bash
git clone https://github.com/Sam-24-dev/Technology-trend-analysis-platform.git
cd Technology-trend-analysis-platform
```

### 2. Setup Backend (Python)

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

### 3. Setup Frontend (Flutter)

```bash
cd frontend
flutter run -d chrome
```

##  Project Structure

```
Technology-trend-analysis-platform/
├── backend/          # FastAPI REST API
├── frontend/         # Flutter Web Application
├── etl/              # ETL scripts for data extraction
├── database/         # SQL schemas and migrations
└── README.md
```

##  Authors

- **Samir Caizapasto** 
- **Andrés Salinas** 
- **Mateo Mayorga** 

---


