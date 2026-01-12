<div align="center">

# 🚀 Tech Trends 2025

### Plataforma de Análisis de Tendencias Tecnológicas

[![Flutter](https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter)](https://flutter.dev)
[![Python](https://img.shields.io/badge/Python-3.9+-3776AB?logo=python)](https://python.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

*Análisis de datos de GitHub, StackOverflow y Reddit para identificar tendencias tecnológicas emergentes*

[Ver Demo](#demo) • [Instalación](#instalación) • [Documentación](#estructura-del-proyecto)

</div>

---

## 📋 Descripción

**Tech Trends 2025** es una plataforma de inteligencia de datos que extrae, transforma y visualiza información de las principales comunidades de desarrolladores para identificar:

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
│  │                    ETL Pipeline                          │   │
│  │   • Extracción de datos via APIs                        │   │
│  │   • Transformación y limpieza                           │   │
│  │   • Análisis de sentimiento (NLP)                       │   │
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
│  │   • Visualizaciones interactivas                        │   │
│  │   • Gráficos con fl_chart                               │   │
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
├── 📂 etl/                          # Pipeline de extracción de datos
│   ├── config.py                    # Configuración y tokens de API
│   ├── github_etl.py                # Extracción de repositorios GitHub
│   ├── stackoverflow_etl.py         # Extracción de preguntas SO
│   ├── reddit_etl.py                # Extracción y análisis de Reddit
│   └── requirements.txt             # Dependencias Python
│
├── 📂 datos/                         # Datos procesados (CSV)
│   ├── github_lenguajes.csv         # Top 10 lenguajes
│   ├── github_commits_frameworks.csv # Commits por framework
│   ├── github_correlacion.csv       # Stars vs Contributors
│   ├── so_volumen_preguntas.csv     # Volumen preguntas SO
│   ├── so_tasa_aceptacion.csv       # Tasa aceptación SO
│   ├── so_tendencias_mensuales.csv  # Tendencias mensuales
│   ├── reddit_sentimiento_*.csv     # Análisis de sentimiento
│   └── interseccion_*.csv           # Datos cruzados
│
├── 📂 frontend/                      # Dashboard Flutter Web
│   ├── lib/
│   │   ├── main.dart                # Entry point
│   │   ├── screens/                 # Pantallas del dashboard
│   │   │   ├── home_screen.dart
│   │   │   ├── github_dashboard.dart
│   │   │   ├── stackoverflow_dashboard.dart
│   │   │   └── reddit_dashboard.dart
│   │   ├── models/                  # Modelos de datos
│   │   ├── services/                # Servicios (CSV loader)
│   │   └── widgets/                 # Componentes reutilizables
│   ├── assets/data/                 # CSVs para el dashboard
│   └── pubspec.yaml                 # Dependencias Flutter
│
├── .env                              # Variables de entorno (no commitear)
├── .gitignore                        # Archivos ignorados
├── LICENSE                           # Licencia MIT
└── README.md                         # Este archivo
```

---

## 🚀 Instalación

### Prerrequisitos

- **Python 3.9+** para el ETL
- **Flutter 3.0+** para el dashboard
- **Git** para clonar el repositorio

### 1️⃣ Clonar el Repositorio

```bash
git clone https://github.com/Sam-24-dev/Technology-trend-analysis-platform.git
cd Technology-trend-analysis-platform
```

### 2️⃣ Configurar el ETL (Python)

```bash
cd etl
pip install -r requirements.txt
```

Crear archivo `.env` en la raíz con los tokens:
```env
GITHUB_TOKEN=tu_github_token
```

### 3️⃣ Ejecutar el Dashboard (Flutter)

```bash
cd frontend
flutter pub get
flutter run -d chrome
```

> **⚠️ Nota Windows:** Si Flutter no se reconoce, ejecutar primero:
> ```powershell
> $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
> ```

---

## 📊 Visualizaciones

### GitHub Dashboard
| Gráfico | Descripción |
|---------|-------------|
| Lenguajes Top 10 | Barras horizontales con repositorios nuevos en 2025 |
| Commits por Framework | Donut chart (Angular vs React vs Vue) |
| Stars vs Contributors | Scatter plot con regresión lineal |

### StackOverflow Dashboard
| Gráfico | Descripción |
|---------|-------------|
| Volumen de Preguntas | Barras verticales por lenguaje |
| Tasa de Aceptación | Barras apiladas (verde/rojo) |
| Tendencias 2025 | Líneas (Python vs JS vs TS) |

### Reddit Dashboard
| Gráfico | Descripción |
|---------|-------------|
| Sentimiento | Barras divergentes positivo/negativo |
| Temas Emergentes | Barras verticales con menciones |
| Intersección | Comparativo GitHub vs Reddit rankings |

---

## 🛠️ Tecnologías

| Componente | Tecnología |
|------------|------------|
| **ETL** | Python, Requests, NLTK, Pandas |
| **Frontend** | Flutter Web, fl_chart, font_awesome |
| **Datos** | CSV, JSON (APIs) |
| **Control de versiones** | Git, GitHub |

---

## 👥 Equipo

| Integrante | Rol | Responsabilidad |
|------------|-----|-----------------|
| **Samir Caizapasto** | Lead Developer | GitHub ETL + Dashboard + Arquitectura |
| **Andrés Salinas** | Developer | StackOverflow ETL + Dashboard |
| **Mateo Mayorga** | Developer | Reddit ETL + Dashboard + NLP |

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Ver [LICENSE](LICENSE) para más detalles.

---

<div align="center">

**Universidad Politécnica Salesiana** • Ingeniería en Ciencias de la Computación • 2025

</div>
