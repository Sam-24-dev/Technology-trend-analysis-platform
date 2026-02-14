import 'package:flutter/services.dart' show rootBundle;
import 'package:csv/csv.dart';
import 'package:http/http.dart' as http;

class CsvService {
  static List<Map<String, dynamic>> _parseCsvToMap(String rawData) {
    if (rawData.trim().isEmpty) {
      return [];
    }

    // Evita parsear HTML de error/fallback como si fuera CSV.
    final probe = rawData.trimLeft();
    if (probe.startsWith('<!DOCTYPE html') || probe.startsWith('<html')) {
      return [];
    }

    final csvData = const CsvToListConverter().convert(rawData);
    if (csvData.isEmpty) {
      return [];
    }

    final headers = csvData[0].map((e) => e.toString()).toList();
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
  }

  static List<String> _buildCandidatePaths(String assetPath) {
    final normalized = assetPath.replaceAll('\\', '/').replaceFirst(RegExp(r'^/+'), '');

    final candidates = <String>[];
    void add(String p) {
      if (p.isNotEmpty && !candidates.contains(p)) {
        candidates.add(p);
      }
    }

    add(normalized);

    if (normalized.startsWith('assets/data/')) {
      final suffix = normalized.substring('assets/data/'.length);
      add('assets/assets/data/$suffix');
      add('data/$suffix');
      add('/Technology-trend-analysis-platform/assets/data/$suffix');
      add('/Technology-trend-analysis-platform/assets/assets/data/$suffix');
    } else if (normalized.startsWith('data/')) {
      final suffix = normalized.substring('data/'.length);
      add('assets/data/$suffix');
      add('assets/assets/data/$suffix');
      add('/Technology-trend-analysis-platform/assets/data/$suffix');
      add('/Technology-trend-analysis-platform/assets/assets/data/$suffix');
    } else {
      add('assets/$normalized');
      add('/Technology-trend-analysis-platform/$normalized');
      add('/Technology-trend-analysis-platform/assets/$normalized');
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

    // 1) Intentar con AssetBundle (Flutter assets)
    for (final path in pathsToTry) {
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

    // 2) Fallback HTTP para GitHub Pages/CDN (con cache-busting)
    for (final path in pathsToTry) {
      try {
        final baseUri = Uri.base.resolve(path);
        final bustUri = baseUri.replace(
          queryParameters: {
            ...baseUri.queryParameters,
            'v': DateTime.now().millisecondsSinceEpoch.toString(),
          },
        );

        final response = await http.get(bustUri);
        if (response.statusCode != 200) {
          print('HTTP ${response.statusCode} en $bustUri');
          continue;
        }

        final parsed = _parseCsvToMap(response.body);
        if (parsed.isNotEmpty) {
          return parsed;
        }
      } catch (e) {
        print('Fallo HTTP en $path: $e');
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
