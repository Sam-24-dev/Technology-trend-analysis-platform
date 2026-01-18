# 📘 Guía para Implementar Key Insights y Exportar ZIP

Esta guía es para **Andrés (StackOverflow)** y **Mateo (Reddit)** para que implementen las secciones de Key Insights y el botón de Exportar ZIP en sus dashboards.

---

## 📁 Archivos de Referencia

Revisa estos archivos como ejemplo:
- `lib/screens/github_dashboard.dart` - Dashboard completo con Key Insights + ZIP
- `lib/screens/home_screen.dart` - Key Insights con logos oficiales

---

## 🎨 Colores Oficiales

| Plataforma | Color HEX | Uso |
|------------|-----------|-----|
| **StackOverflow** | `#F48024` | Botón export, bordes de cards |
| **Reddit** | `#FF4500` | Botón export, bordes de cards |
| **GitHub** | `#238636` | (ya implementado) |
| **Python** | `#3776AB` | Insight de Python |
| **Angular** | `#DD0031` | Insight de Angular |

---

## 🔧 PASO 1: Agregar Imports Necesarios

Al inicio del archivo, agregar:

```dart
import 'dart:html' as html;
import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
```

---

## 🔧 PASO 2: Crear Función de Exportar ZIP

Agregar esta función dentro de la clase del dashboard:

```dart
void _exportDataAsZip() {
  // CSV 1: Tu primer conjunto de datos
  String csv1 = 'columna1,columna2,columna3\n';
  for (var item in tusDatos1) {
    csv1 += '${item.campo1},${item.campo2},${item.campo3}\n';
  }
  
  // CSV 2: Tu segundo conjunto de datos
  String csv2 = 'columna1,columna2\n';
  for (var item in tusDatos2) {
    csv2 += '${item.campo1},${item.campo2}\n';
  }
  
  // CSV 3: Tu tercer conjunto de datos
  String csv3 = 'columna1,columna2\n';
  for (var item in tusDatos3) {
    csv3 += '${item.campo1},${item.campo2}\n';
  }
  
  // Crear ZIP
  final archive = Archive();
  archive.addFile(ArchiveFile('1_nombre_datos.csv', csv1.length, utf8.encode(csv1)));
  archive.addFile(ArchiveFile('2_nombre_datos.csv', csv2.length, utf8.encode(csv2)));
  archive.addFile(ArchiveFile('3_nombre_datos.csv', csv3.length, utf8.encode(csv3)));
  
  final zipData = ZipEncoder().encode(archive);
  if (zipData != null) {
    final blob = html.Blob([zipData], 'application/zip');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'tu_dashboard_data.zip') // Cambiar nombre
      ..click();
    html.Url.revokeObjectUrl(url);
  }
}
```

---

## 🔧 PASO 3: Agregar Botón de Exportar ZIP

En el header del dashboard, agregar el botón:

```dart
// Para StackOverflow (naranja)
ElevatedButton.icon(
  onPressed: _exportDataAsZip,
  icon: const Icon(Icons.folder_zip, size: 18),
  label: const Text('Exportar ZIP'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFF48024), // StackOverflow orange
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
),

// Para Reddit (naranja-rojo)
ElevatedButton.icon(
  onPressed: _exportDataAsZip,
  icon: const Icon(Icons.folder_zip, size: 18),
  label: const Text('Exportar ZIP'),
  style: ElevatedButton.styleFrom(
    backgroundColor: const Color(0xFFFF4500), // Reddit orange
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  ),
),
```

---

## 🔧 PASO 4: Crear Sección Key Insights

### Container Principal (gris claro)

```dart
Container(
  padding: const EdgeInsets.all(24),
  decoration: BoxDecoration(
    color: const Color(0xFFF3F4F6), // Gris claro
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Header
      Row(
        children: const [
          Icon(Icons.insights, color: Color(0xFF374151), size: 28),
          SizedBox(width: 12),
          Text(
            'Key Insights',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
      const SizedBox(height: 20),
      
      // Insight 1
      _buildInsightCard(
        'assets/images/tu_logo.png', // O usa un icono
        'Título del insight',
        'Descripción del insight',
        const Color(0xFFF48024), // Color de acento
      ),
      const SizedBox(height: 12),
      
      // Insight 2
      _buildInsightCard(...),
      const SizedBox(height: 12),
      
      // Insight 3
      _buildInsightCard(...),
    ],
  ),
),
```

---

## 🔧 PASO 5: Widget Helper para Insight Cards

### Opción A: Con Imagen (logo oficial)

```dart
Widget _buildInsightCard(String imagePath, String title, String description, Color accentColor) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
      boxShadow: [
        BoxShadow(
          color: accentColor.withOpacity(0.1),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 48,
          height: 48,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(imagePath, fit: BoxFit.contain),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
```

### Opción B: Con Icono de Material

```dart
Widget _buildInsightCardIcon(IconData icon, String title, String description, Color accentColor) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
    ),
    child: Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: accentColor,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: accentColor)),
              const SizedBox(height: 4),
              Text(description, style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    ),
  );
}
```

---

## 📥 Descargar Logos Oficiales

Para usar logos oficiales (PNG 96x96 o 144x144, fondo transparente):

1. Buscar en Google: `[nombre] logo PNG transparent`
2. O usar sitios como:
   - [simpleicons.org](https://simpleicons.org/)
   - [worldvectorlogo.com](https://worldvectorlogo.com/)

3. Guardar en: `frontend/assets/images/`
4. Agregar a `pubspec.yaml`:
   ```yaml
   assets:
     - assets/images/
   ```

---

## ✅ Checklist Final

- [ ] Imports agregados (`dart:html`, `archive`, `dart:math`)
- [ ] Función `_exportDataAsZip()` creada
- [ ] Botón de exportar con color oficial de tu plataforma
- [ ] Container Key Insights con fondo gris claro
- [ ] 3 Insight cards con bordes de colores
- [ ] Widgets helper agregados
- [ ] Hot restart para probar

---

## 🎯 Ejemplo de Datos para Insights

### StackOverflow (Andrés):
1. **Lenguaje más preguntado**: JavaScript/Python con X preguntas
2. **Tag trending**: Algún tag emergente
3. **Ratio respuestas**: Porcentaje de preguntas respondidas

### Reddit (Mateo):
1. **Tema más mencionado**: AI/ML con 316 menciones
2. **Subreddit más activo**: r/programming o similar
3. **Tendencia**: Crecimiento de algún tema

---

**¿Dudas?** Revisa `github_dashboard.dart` como ejemplo completo. 🚀
