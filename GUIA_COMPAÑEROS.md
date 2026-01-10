# 📋 Guía para Compañeros - Tech Trends 2025 Dashboard

## 🎯 Objetivo
Esta guía explica cómo implementar los dashboards de **StackOverflow** y **Reddit** siguiendo la misma estructura y estilo que el dashboard de GitHub.

---

## 📁 Estructura del Proyecto

```
Technology-trend-analysis-platform/
├── datos/                          # CSVs generados por los ETL
│   ├── github_*.csv                # Datos de GitHub (Samir)
│   ├── so_*.csv                    # Datos de StackOverflow (Andrés)
│   └── reddit_*.csv                # Datos de Reddit (Mateo)
├── etl/                            # Scripts de extracción
│   ├── github_etl.py
│   ├── stackoverflow_etl.py
│   └── reddit_etl.py
└── frontend/
    ├── assets/data/                # CSVs copiados para el dashboard
    ├── lib/
    │   ├── models/                 # Modelos de datos
    │   │   └── github_models.dart  # EJEMPLO: Modelos para GitHub
    │   ├── screens/                # Pantallas del dashboard
    │   │   ├── home_screen.dart
    │   │   ├── github_dashboard.dart
    │   │   ├── stackoverflow_placeholder.dart  # 👈 EDITAR ANDRÉS
    │   │   └── reddit_placeholder.dart         # 👈 EDITAR MATEO
    │   ├── services/
    │   │   └── csv_service.dart    # Servicio para cargar CSVs
    │   └── widgets/
    │       └── chart_card.dart     # Widget reutilizable para gráficos
    └── pubspec.yaml                # Dependencias
```

---

## 🚀 Configuración Inicial

### 1. Clonar y preparar
```bash
git clone <repo-url>
cd Technology-trend-analysis-platform
```

### 2. Copiar tus CSVs a assets
```bash
# Andrés (StackOverflow):
cp datos/so_*.csv frontend/assets/data/

# Mateo (Reddit):
cp datos/reddit_*.csv frontend/assets/data/
```

### 3. Ejecutar Flutter

**⚠️ IMPORTANTE (Windows):** Cada vez que abras una nueva terminal, primero ejecuta:
```powershell
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
```

Luego:
```bash
cd frontend
flutter pub get
flutter run -d chrome
```

Esto abrirá Chrome con el dashboard. Para cerrar, presiona `q` en la terminal.

---

## 🎨 Guía de Estilo

### Colores por Herramienta
| Herramienta   | Color Principal | Código Hex |
|---------------|-----------------|------------|
| GitHub        | Azul            | `#3B82F6`  |
| StackOverflow | Naranja         | `#F48024`  |
| Reddit        | Naranja-Rojo    | `#FF4500`  |

### Colores para Gráficos
```dart
// Sentimiento
Verde positivo:  Color(0xFF10B981)
Gris neutral:    Color(0xFF9CA3AF)
Rojo negativo:   Color(0xFFEF4444)

// Lenguajes
Python:          Color(0xFF3776AB)
JavaScript:      Color(0xFFF7DF1E)
TypeScript:      Color(0xFF2D79C7)
```

### Estructura de Pantalla
```dart
return Padding(
  padding: const EdgeInsets.all(24),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Título principal
      const Text(
        'Dashboard [Herramienta]',
        style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      ),
      // Subtítulo
      const Text(
        'Descripción breve',
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
      const SizedBox(height: 32),
      
      // Gráfico 1
      ChartCard(
        title: 'Título del Gráfico',
        subtitle: 'Descripción del gráfico',
        height: 400,
        chart: _buildChart1(),
      ),
      const SizedBox(height: 24),
      
      // Gráfico 2, 3...
    ],
  ),
);
```

---

## 📊 ANDRÉS SALINAS - StackOverflow Dashboard

### Archivo a editar:
`frontend/lib/screens/stackoverflow_placeholder.dart`

### Renombrar a:
`frontend/lib/screens/stackoverflow_dashboard.dart`

### CSVs a usar:
- `so_volumen_preguntas.csv` - Volumen de preguntas por lenguaje
- `so_tasa_respuestas.csv` - Tasa de respuestas aceptadas
- `so_tendencias.csv` - Tendencias mensuales

### Gráficos a implementar:

#### Gráfico 1: Volumen de Preguntas por Lenguaje
- **Tipo**: Barras verticales
- **Eje X**: Lenguajes (Python, JavaScript, TypeScript, Java, Go)
- **Eje Y**: Número de preguntas
- **Color**: Naranja StackOverflow (#F48024)
- **Referencia**: Similar al gráfico horizontal de GitHub pero vertical

#### Gráfico 2: Tasa de Respuestas Aceptadas
- **Tipo**: Barras horizontales apiladas al 100%
- **Eje X**: Porcentaje (0% - 100%)
- **Eje Y**: Frameworks/Tecnologías
- **Colores**: Verde = Aceptada, Rojo = Sin aceptar
- **Referencia**: Ver imagen Figma proporcionada

#### Gráfico 3: Tendencias Python vs JS vs TS
- **Tipo**: Gráfico de líneas múltiples
- **Eje X**: Meses (Ene, Feb, Mar...)
- **Eje Y**: Número de preguntas
- **Colores**: Python (azul), JavaScript (amarillo), TypeScript (azul oscuro)

### Ejemplo de modelo de datos:
```dart
// frontend/lib/models/stackoverflow_models.dart
class VolumenPreguntasModel {
  final String lenguaje;
  final int preguntasNuevas;
  
  VolumenPreguntasModel({required this.lenguaje, required this.preguntasNuevas});
  
  factory VolumenPreguntasModel.fromMap(Map<String, dynamic> map) {
    return VolumenPreguntasModel(
      lenguaje: map['lenguaje'] ?? '',
      preguntasNuevas: int.tryParse(map['preguntas_nuevas_2025']?.toString() ?? '0') ?? 0,
    );
  }
}
```

---

## 📊 MATEO MAYORGA - Reddit Dashboard

### Archivo a editar:
`frontend/lib/screens/reddit_placeholder.dart`

### Renombrar a:
`frontend/lib/screens/reddit_dashboard.dart`

### CSVs a usar:
- `reddit_sentimiento.csv` - Sentimiento por framework
- `reddit_temas_emergentes.csv` - Temas más mencionados
- `reddit_interseccion.csv` - Comparación GitHub vs Reddit

### Gráficos a implementar:

#### Gráfico 1: Sentimiento de Frameworks Backend
- **Tipo**: Barras horizontales apiladas divergentes (desde el centro)
- **Eje X**: Porcentaje (-100 a +100)
- **Eje Y**: Frameworks (FastAPI, Django, Laravel, Express, Spring, Flask)
- **Colores**: Verde = Positivo, Rojo = Negativo
- **Referencia**: Ver imagen Figma proporcionada

#### Gráfico 2: Temas Emergentes
- **Tipo**: Barras horizontales
- **Eje X**: Número de menciones
- **Eje Y**: Temas (IA/ML, Cloud, Microservicios, etc.)
- **Color**: Degradado o color único (#FF4500)

#### Gráfico 3: Intersección GitHub-Reddit
- **Tipo**: Barras comparativas lado a lado
- **Eje X**: Tecnologías
- **Eje Y**: Ranking
- **Colores**: Azul (GitHub), Naranja (Reddit)

### Ejemplo de modelo de datos:
```dart
// frontend/lib/models/reddit_models.dart
class SentimientoModel {
  final String framework;
  final double positivo;
  final double negativo;
  
  SentimientoModel({required this.framework, required this.positivo, required this.negativo});
  
  factory SentimientoModel.fromMap(Map<String, dynamic> map) {
    return SentimientoModel(
      framework: map['framework'] ?? '',
      positivo: double.tryParse(map['positivo']?.toString() ?? '0') ?? 0,
      negativo: double.tryParse(map['negativo']?.toString() ?? '0') ?? 0,
    );
  }
}
```

---

## 🔧 Cómo usar ChartCard

```dart
import '../widgets/chart_card.dart';

ChartCard(
  title: 'Título Principal del Gráfico',
  subtitle: 'Descripción opcional',
  height: 400,  // Altura del gráfico
  chart: _tuMetodoDeConstruccion(),
)
```

---

## 📦 Cómo cargar datos CSV

```dart
import '../services/csv_service.dart';

// En tu clase State:
List<TuModelo> datos = [];

Future<void> _loadData() async {
  final csvData = await CsvService.loadCsvAsMap('assets/data/tu_archivo.csv');
  datos = csvData.map((e) => TuModelo.fromMap(e)).toList();
  setState(() {});
}

@override
void initState() {
  super.initState();
  _loadData();
}
```

---

## ✅ Checklist antes de commit

- [ ] CSVs copiados a `frontend/assets/data/`
- [ ] Modelos creados en `frontend/lib/models/`
- [ ] Dashboard implementado con 3 gráficos
- [ ] Títulos y subtítulos descriptivos
- [ ] Colores consistentes con la guía
- [ ] Sin errores de compilación (`flutter analyze`)
- [ ] Probado en Chrome

---

## 🆘 Problemas comunes

### CSV no se carga
Verifica que esté en `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/data/
```

### Gráfico no se muestra
- Verifica que los datos no estén vacíos
- Revisa la consola de Chrome (F12) para errores

### Error de dependencias
```bash
flutter clean
flutter pub get
```

---

## 📞 Contacto
Si tienen dudas, revisen el código de `github_dashboard.dart` como referencia o contacten al equipo.

---

**¡Éxito con sus dashboards! 🚀**
