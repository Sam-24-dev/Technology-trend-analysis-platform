# 🚀 Tech Trends 2025 - Plataforma de Análisis de Tendencias Tecnológicas

Dashboard interactivo para análisis de tendencias tecnológicas 2025, integrando datos de **GitHub**, **StackOverflow** y **Reddit**.

## 📊 Vista Previa

El dashboard incluye:
- **Inicio**: KPIs generales y resumen del proyecto
- **GitHub Data**: Lenguajes populares, commits por framework, correlación stars/contributors
- **StackOverflow Data**: Volumen de preguntas, tasas de respuesta, tendencias
- **Reddit Data**: Sentimiento de frameworks, temas emergentes, comparativas

## 🛠️ Tecnologías

| Componente | Tecnología |
|------------|------------|
| ETL | Python (requests, pandas, nltk) |
| Frontend | Flutter Web (fl_chart, google_fonts) |
| Datos | CSV |

## 📁 Estructura del Proyecto

```
├── datos/                    # CSVs generados por ETL
├── etl/                      # Scripts de extracción
│   ├── config.py
│   ├── github_etl.py
│   ├── stackoverflow_etl.py
│   └── reddit_etl.py
├── frontend/                 # Dashboard Flutter Web
│   ├── lib/
│   │   ├── models/
│   │   ├── screens/
│   │   ├── services/
│   │   └── widgets/
│   └── assets/data/
├── GUIA_COMPAÑEROS.md       # Guía para el equipo
└── README.md
```

## 🚀 Instalación y Ejecución

### Requisitos
- Python 3.8+
- Flutter 3.x

### ETL (Extracción de datos)
```bash
cd etl
pip install -r requirements.txt
python github_etl.py
python stackoverflow_etl.py
python reddit_etl.py
```

### Frontend (Dashboard)

**Windows - Ejecutar en cada terminal nueva:**
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

**Luego:**
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

## 👥 Equipo

| Integrante | Rol |
|------------|-----|
| Samir Caizapasto | GitHub ETL & Dashboard |
| Andrés Salinas | StackOverflow ETL & Dashboard |
| Mateo Mayorga | Reddit ETL & Dashboard |

## 📋 Para compañeros del equipo

Ver **[GUIA_COMPAÑEROS.md](GUIA_COMPAÑEROS.md)** para instrucciones detalladas sobre cómo implementar sus dashboards.

## 📄 Licencia

MIT License - Proyecto Académico 2025
