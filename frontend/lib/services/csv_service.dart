import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

/// Servicio central de carga de CSVs.
///
/// Estrategia de carga (en orden):
///   1. HTTP GET a las URLs absolutas conocidas de GitHub Pages
///      (assets/assets/data/ y assets/data/).
///   2. rootBundle (funciona en ejecución local / flutter run).
///
/// Se usa `package:http` en lugar de `dart:html HttpRequest` porque es el
/// mecanismo estándar de Flutter y funciona correctamente tanto en web como
/// en plataformas nativas.
class CsvService {
  // ── URL base del deploy en GitHub Pages ──
  static const String _ghPagesBase =
      'https://sam-24-dev.github.io/Technology-trend-analysis-platform';

  // ── Parseo de CSV ────────────────────────────────────────────────

  /// Parser manual robusto para una línea CSV (maneja comillas escapadas).
  static List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(buf.toString());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    fields.add(buf.toString());
    return fields;
  }

  /// Parsea CSV crudo a lista de mapas usando parser manual.
  static List<Map<String, dynamic>> _parseCsvManual(String raw) {
    final normalized =
        raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) return [];

    final lines =
        normalized.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) return [];

    final headers = _splitCsvLine(lines.first)
        .map((h) => h.replaceFirst('\ufeff', '').trim())
        .toList();

    return [
      for (final line in lines.skip(1))
        () {
          final vals = _splitCsvLine(line);
          return {
            for (int i = 0; i < headers.length; i++)
              headers[i]: i < vals.length ? vals[i] : '',
          };
        }(),
    ];
  }

  /// Intenta parsear con `CsvToListConverter`; si falla usa parser manual.
  static List<Map<String, dynamic>> _parseCsvToMap(String rawData) {
    if (rawData.trim().isEmpty) return [];

    // Rechazar respuestas HTML (p.ej. páginas 404 de GH Pages).
    final probe = rawData.trimLeft();
    if (probe.startsWith('<!') || probe.startsWith('<html')) return [];

    try {
      final csvData = const CsvToListConverter().convert(rawData);
      if (csvData.length < 2) return [];

      final headers = csvData[0]
          .map((e) => e.toString().replaceFirst('\ufeff', '').trim())
          .toList();

      return [
        for (final row in csvData.sublist(1))
          {
            for (int i = 0; i < headers.length && i < row.length; i++)
              headers[i]: row[i],
          },
      ];
    } catch (_) {
      return _parseCsvManual(rawData);
    }
  }

  // ── Carga HTTP ───────────────────────────────────────────────────

  /// Descarga texto desde [url] y lo parsea como CSV.
  /// Retorna `null` si no se puede obtener datos válidos.
  static Future<List<Map<String, dynamic>>?> _tryHttp(String url) async {
    try {
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200 && response.body.isNotEmpty) {
        final parsed = _parseCsvToMap(response.body);
        if (parsed.isNotEmpty) {
          print('[CsvService] OK via HTTP → $url  (${parsed.length} filas)');
          return parsed;
        }
      }
    } catch (e) {
      print('[CsvService] HTTP fallo en $url → $e');
    }
    return null;
  }

  // ── API pública ─────────────────────────────────────────────────

  /// Carga un CSV y devuelve las filas como `List<List<dynamic>>`.
  static Future<List<List<dynamic>>> loadCsv(String assetPath) async {
    try {
      final maps = await loadCsvAsMap(assetPath);
      if (maps.isEmpty) return [];
      final headers = maps.first.keys.toList();
      return [
        for (final row in maps) [for (final h in headers) row[h] ?? ''],
      ];
    } catch (e) {
      print('[CsvService] loadCsv error: $e');
      return [];
    }
  }

  /// Carga un CSV y devuelve las filas como `List<Map<String, dynamic>>`.
  static Future<List<Map<String, dynamic>>> loadCsvAsMap(
      String assetPath) async {
    // Extraer solo el nombre del archivo (p.ej. "github_lenguajes.csv").
    final fileName = assetPath.replaceAll('\\', '/').split('/').last;

    // ── 1) HTTP a URLs absolutas de GitHub Pages ──
    if (kIsWeb) {
      // Orden: la ruta assets/assets/data/ es la correcta para Flutter Web
      // desplegado en GH Pages (doble "assets" por el build de Flutter).
      final urls = [
        '$_ghPagesBase/assets/assets/data/$fileName',
        '$_ghPagesBase/assets/data/$fileName',
      ];

      for (final url in urls) {
        final result = await _tryHttp(url);
        if (result != null) return result;
      }
    }

    // ── 2) rootBundle (ejecución local / flutter run) ──
    final bundlePaths = [
      'assets/data/$fileName',
      assetPath,
    ];
    // Eliminar duplicados manteniendo orden.
    final seen = <String>{};
    final uniquePaths = bundlePaths.where((p) => seen.add(p)).toList();

    for (final path in uniquePaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final parsed = _parseCsvToMap(raw);
        if (parsed.isNotEmpty) {
          print('[CsvService] OK via AssetBundle → $path  (${parsed.length} filas)');
          return parsed;
        }
      } catch (e) {
        print('[CsvService] AssetBundle fallo en $path → $e');
      }
    }

    // ── 3) No se pudo cargar ──
    print('[CsvService] FALLO total para: $assetPath ($fileName)');
    throw Exception('No se pudo cargar $fileName desde ninguna fuente.');
  }
}
