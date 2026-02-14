import 'dart:html' as html;
import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';

class CsvService {
  static const String _repoBaseUrl =
      'https://sam-24-dev.github.io/Technology-trend-analysis-platform';

  static List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;

    for (int i = 0; i < line.length; i++) {
      final ch = line[i];

      if (ch == '"') {
        // Escaped quote
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == ',' && !inQuotes) {
        fields.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(ch);
      }
    }

    fields.add(buffer.toString());
    return fields;
  }

  static List<Map<String, dynamic>> _parseCsvFallback(String rawData) {
    final normalized = rawData.replaceAll('\r\n', '\n').replaceAll('\r', '\n').trim();
    if (normalized.isEmpty) {
      return [];
    }

    final lines = normalized.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.length < 2) {
      return [];
    }

    final headers = _splitCsvLine(lines.first)
        .map((h) => h.replaceFirst('\ufeff', '').trim())
        .toList();

    final out = <Map<String, dynamic>>[];
    for (final line in lines.skip(1)) {
      final values = _splitCsvLine(line);
      final row = <String, dynamic>{};
      for (int i = 0; i < headers.length; i++) {
        row[headers[i]] = i < values.length ? values[i] : '';
      }
      out.add(row);
    }
    return out;
  }

  static List<Map<String, dynamic>> _parseCsvToMap(String rawData) {
    if (rawData.trim().isEmpty) {
      return [];
    }

    // Evita parsear HTML de error/fallback como si fuera CSV.
    final probe = rawData.trimLeft();
    if (probe.startsWith('<!DOCTYPE html') || probe.startsWith('<html')) {
      return [];
    }

    try {
      final csvData = const CsvToListConverter().convert(rawData);
      if (csvData.isEmpty) {
        return [];
      }

      final headers = csvData[0]
          .map((e) => e.toString().replaceFirst('\ufeff', '').trim())
          .toList();
      if (csvData.length == 1) {
        return [];
      }

      final dataRows = csvData.sublist(1);
      return dataRows.map((row) {
        final map = <String, dynamic>{};
        for (int i = 0; i < headers.length && i < row.length; i++) {
          map[headers[i]] = row[i];
        }
        return map;
      }).toList();
    } catch (_) {
      return _parseCsvFallback(rawData);
    }
  }

  static List<String> _buildCandidatePaths(String assetPath) {
    final normalized = assetPath.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    final candidates = <String>[];

    void add(String p) {
      final clean = p.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
      if (clean.isNotEmpty && !candidates.contains(clean)) {
        candidates.add(clean);
      }
    }

    // Clave de asset para rootBundle (como aparece en AssetManifest)
    add(normalized);

    if (normalized.startsWith('assets/data/')) {
      final suffix = normalized.substring('assets/data/'.length);
      // URL web real en Flutter web: /assets/<asset-key>
      add('assets/assets/data/$suffix');
      // Fallback por si cambian build settings
      add('assets/data/$suffix');
      add('data/$suffix');
    }

    return candidates;
  }

  static Future<List<List<dynamic>>> loadCsv(String assetPath) async {
    try {
      final rowsAsMap = await loadCsvAsMap(assetPath);
      if (rowsAsMap.isEmpty) {
        return [];
      }

      final headers = rowsAsMap.first.keys.toList();
      final csvData = <List<dynamic>>[];
      csvData.add(headers);
      for (final row in rowsAsMap) {
        csvData.add(headers.map((h) => row[h] ?? '').toList());
      }
      
      // Ignorar la primera fila (headers)
      if (csvData.isNotEmpty) {
        return csvData.sublist(1);
      }
      
      return [];
    } catch (e) {
      print('Error cargando CSV: $e');
      return [];
    }
  }
  
  static Future<List<Map<String, dynamic>>> loadCsvAsMap(String assetPath) async {
    final pathsToTry = _buildCandidatePaths(assetPath);

    // Extraer sufijo CSV (github_lenguajes.csv, etc.) cuando aplica.
    final normalized = assetPath.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');
    String? suffix;
    if (normalized.startsWith('assets/data/')) {
      suffix = normalized.substring('assets/data/'.length);
    } else if (normalized.startsWith('data/')) {
      suffix = normalized.substring('data/'.length);
    }

    // 1) Prioridad máxima: URL absoluta real de GitHub Pages.
    if (suffix != null && suffix.isNotEmpty) {
      final absoluteCandidates = <Uri>[
        Uri.parse('$_repoBaseUrl/assets/assets/data/$suffix'),
        Uri.parse('$_repoBaseUrl/assets/data/$suffix'),
      ];

      for (final uri in absoluteCandidates) {
        try {
          final bustUri = uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              'v': DateTime.now().millisecondsSinceEpoch.toString(),
            },
          );

          final rawData = await html.HttpRequest.getString(bustUri.toString());
          final parsed = _parseCsvToMap(rawData);
          if (parsed.isNotEmpty) {
            return parsed;
          }
        } catch (e) {
          print('Fallo URL absoluta en $uri: $e');
        }
      }
    }

    // 2) Último recurso: AssetBundle para ejecución local.
    for (final path in pathsToTry.where((p) => !p.startsWith('assets/assets/'))) {
      try {
        final rawData = await rootBundle.loadString(path);
        final parsed = _parseCsvToMap(rawData);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } catch (e) {
        print('Fallo AssetBundle en $path: $e');
      }
    }

    // 3) Reportar error final
    for (final path in pathsToTry) {
      print('Ruta intentada sin exito: $path');
    }
    
    // Si llegamos aquí, ninguno funcionó
    throw Exception('No se pudo cargar el CSV en ninguna de las rutas probadas: $pathsToTry');
  }
}
