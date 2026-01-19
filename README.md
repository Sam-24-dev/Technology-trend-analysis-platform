<div align="center">

#  Tech Trends 2025

### Plataforma de Análisis de Tendencias Tecnológicas

[![Flutter](https://img.shields.io/badge/Flutter-3.38.6-02569B?logo=flutter)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.7-0175C2?logo=dart)](https://dart.dev)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

*Análisis de datos de GitHub, StackOverflow y Reddit para identificar tendencias tecnológicas emergentes*

[Demo](#-demo) • [Instalación](#-instalación) • [Estructura](#-estructura-del-proyecto)

</div>

---

## 📋 Descripción

**Tech Trends 2025** es una plataforma de inteligencia de datos que extrae, transforma y visualiza información de las principales comunidades de desarrolladores:

- 🔥 Lenguajes de programación en crecimiento
- 📊 Frameworks con mayor actividad
- 💬 Sentimiento de la comunidad sobre tecnologías
- 🔗 Correlaciones entre popularidad en diferentes plataformas

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                        TECH TRENDS 2025                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────┐   ┌─────────────┐   ┌─────────────┐          │
│  │   GitHub    │   │StackOverflow│   │   Reddit    │          │
│  │     API     │   │     API     │   │     API     │          │
│  └──────┬──────┘   └──────┬──────┘   └──────┬──────┘          │
│         │                 │                 │                  │
│         ▼                 ▼                 ▼                  │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                    ETL Pipeline (Python)                 │   │
│  │   • Extracción de datos via APIs                        │   │
│  │   • Transformación y limpieza                           │   │
│  │   • Análisis de sentimiento (NLTK)                      │   │
│  └───────────────────────┬─────────────────────────────────┘   │
│                          │                                      │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │                   Data Layer (CSV)                       │   │
│  └───────────────────────┬─────────────────────────────────┘   │
│                          │                                      │
│                          ▼                                      │
│  ┌─────────────────────────────────────────────────────────┐   │
│  │              Flutter Web Dashboard                       │   │
│  │   • Visualizaciones interactivas (fl_chart)             │   │
│  │   • Key Insights + Exportar ZIP                         │   │
│  │   • Diseño responsive                                   │   │
│  └─────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 📁 Estructura del Proyecto

```
Technology-trend-analysis-platform/
│
├── 📂 backend/                       # Backend - Pipeline ETL (Python)
│   ├── config.py                    # Configuración y tokens de API
│   ├── github_etl.py                # Extracción de repositorios GitHub
│   ├── stackoverflow_etl.py         # Extracción de preguntas StackOverflow
│   ├── reddit_etl.py                # Extracción y análisis de Reddit
│   └── requirements.txt             # Dependencias Python
│
├── 📂 datos/                         # Datos procesados (CSV)
│   ├── github_lenguajes.csv
│   ├── github_commits_frameworks.csv
│   ├── github_correlacion.csv
│   ├── so_volumen_preguntas.csv
│   ├── so_tasa_aceptacion.csv
│   ├── so_tendencias_mensuales.csv
│   ├── reddit_sentimiento_frameworks.csv
│   ├── reddit_temas_emergentes.csv
│   └── interseccion_github_reddit.csv
│
├── 📂 frontend/                      # Frontend - Dashboard (Flutter Web)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── screens/
│   │   │   ├── home_screen.dart
│   │   │   ├── github_dashboard.dart
│   │   │   ├── stackoverflow_dashboard.dart
│   │   │   └── reddit_dashboard.dart
│   │   ├── models/
│   │   ├── services/
│   │   └── widgets/
│   ├── assets/
│   │   ├── data/                    # CSVs para visualización
│   │   └── images/                  # Logos oficiales
│   └── pubspec.yaml
│
├── .env                              # Variables de entorno
├── .gitignore
├── LICENSE
└── README.md
```

---

## 🛠️ Versiones de Herramientas

### Backend (ETL - Python)

| Librería | Versión |
|----------|---------|
| Python | 3.9+ |
| requests | 2.31.0 |
| pandas | 2.1.0 |
| python-dotenv | 1.0.0 |
| nltk | 3.8.1 |

### Frontend (Dashboard - Flutter)

| Herramienta/Librería | Versión |
|----------------------|---------|
| Flutter SDK | 3.38.6 |
| Dart SDK | 3.10.7 |
| fl_chart | ^0.69.0 |
| csv | ^6.0.0 |
| google_fonts | ^6.2.1 |
| font_awesome_flutter | ^10.7.0 |
| archive | ^3.4.10 |
| cupertino_icons | ^1.0.8 |
| http | ^1.2.0 |

---

## 🚀 Instalación

### Prerrequisitos

- **Python 3.9+** 
- **Flutter 3.38+** 
- **Git**
- **Google Chrome** (para Flutter Web)

### 1️⃣ Clonar el Repositorio

```bash
git clone https://github.com/Sam-24-dev/Technology-trend-analysis-platform.git
cd Technology-trend-analysis-platform
```

---

## 🔧 Probar el Backend (ETL)

```bash
# 1. Navegar a la carpeta backend
cd backend

# 2. Instalar dependencias
pip install -r requirements.txt

# 3. (Opcional) Ejecutar scripts de extracción
python github_etl.py
python stackoverflow_etl.py
python reddit_etl.py
```

> **Nota:** Los datos ya están pre-procesados en la carpeta `datos/`. Solo ejecutar ETL si se necesitan datos nuevos.

### Configurar Token (solo para ETL)

Crear archivo `.env` en la raíz:
```env
GITHUB_TOKEN=tu_github_token
```

---

## 🖥️ Probar el Frontend (Dashboard)

```bash
# 1. Navegar a la carpeta frontend
cd frontend

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar en Chrome
flutter run -d chrome
```

### ⚠️ Nota para Windows

Si Flutter no se reconoce en PowerShell, ejecutar primero:
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

### Funcionalidades del Dashboard

| Dashboard | Funcionalidades |
|-----------|-----------------|
| **Home** | Key Insights globales, KPIs, navegación |
| **GitHub** | 3 gráficos + Key Insights + Exportar ZIP |
| **StackOverflow** | 3 gráficos + Key Insights + Exportar ZIP |
| **Reddit** | 3 gráficos + Key Insights + Exportar ZIP |

### Exportar Datos

Cada dashboard tiene un botón **"Exportar ZIP"** que descarga los datos en formato CSV comprimido.

---

## 📊 Visualizaciones

### GitHub Dashboard
- **Lenguajes Top 10:** Barras horizontales (repositorios nuevos 2025)
- **Commits por Framework:** Donut chart (Angular vs React vs Vue)
- **Correlación Stars-Contributors:** Scatter plot con coeficiente r

### StackOverflow Dashboard
- **Volumen de Preguntas:** Barras verticales por lenguaje
- **Tasa de Aceptación:** Barras apiladas (verde/rojo)
- **Tendencias 2025:** Líneas (Python vs JS vs TS)

### Reddit Dashboard
- **Sentimiento Frameworks:** Barras divergentes (+/-)
- **Temas Emergentes:** Barras con menciones
- **Intersección GitHub-Reddit:** Rankings comparativos

---

## 👥 Equipo

| Integrante | Rol | Responsabilidad |
|------------|-----|--------------------|
| **Samir Caizapasto** | Lead Developer | GitHub ETL + Dashboard + Arquitectura |
| **Andrés Salinas** | Developer | StackOverflow ETL + Dashboard |
| **Mateo Mayorga** | Developer | Reddit ETL + Dashboard + NLP |

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

---

<div align="center">

**Escuela Superior Politécnica del Litoral** • Ingeniería en Computación • 2026

</div>
