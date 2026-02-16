import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Central CSV loading service.
///
/// Loading strategy (in order):
/// 1. Web HTTP GET using relative paths:
///    - assets/assets/data/<file>
///    - assets/data/<file>
/// 2. Local fallback via rootBundle.
class CsvService {
  /// Robust CSV line parser (supports escaped quotes).
  static List<String> _splitCsvLine(String line) {
    final fields = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
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

  /// Manual CSV parser to Map rows.
  static List<Map<String, dynamic>> _parseCsvManual(String raw) {
    final normalized = raw
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
    if (normalized.isEmpty) return [];

    final lines = normalized
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final headers = _splitCsvLine(
      lines.first,
    ).map((h) => h.replaceFirst('\ufeff', '').trim()).toList();

    return [
      for (final line in lines.skip(1))
        () {
          final vals = _splitCsvLine(line);
          return {
            for (var i = 0; i < headers.length; i++)
              headers[i]: i < vals.length ? vals[i] : '',
          };
        }(),
    ];
  }

  /// CSV parser with converter first, manual fallback.
  static List<Map<String, dynamic>> _parseCsvToMap(String rawData) {
    if (rawData.trim().isEmpty) return [];

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
            for (var i = 0; i < headers.length && i < row.length; i++)
              headers[i]: row[i],
          },
      ];
    } catch (_) {
      return _parseCsvManual(rawData);
    }
  }

  /// Adds a query param to avoid stale/304 cached responses.
  static Uri _withCacheBuster(Uri uri) {
    final query = Map<String, String>.from(uri.queryParameters);
    query['_cb'] = DateTime.now().millisecondsSinceEpoch.toString();
    return uri.replace(queryParameters: query);
  }

  /// Fetches a CSV URL and parses it.
  static Future<List<Map<String, dynamic>>?> _tryHttp(String url) async {
    try {
      final baseUri = Uri.parse(url);
      var response = await http
          .get(baseUri)
          .timeout(const Duration(seconds: 10));
      var effectiveUri = baseUri;

      // Some environments return 304 with empty body for cached assets.
      if (response.statusCode == 304 || response.body.isEmpty) {
        effectiveUri = _withCacheBuster(baseUri);
        response = await http
            .get(effectiveUri)
            .timeout(const Duration(seconds: 10));
      }

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} en $effectiveUri');
      }

      if (response.body.isEmpty) {
        throw Exception('HTTP 200 sin contenido en $effectiveUri');
      }

      final parsed = _parseCsvToMap(response.body);
      if (parsed.isEmpty) {
        throw Exception(
          'Respuesta no valida (HTML/CSV vacio) en $effectiveUri',
        );
      }

      print(
        '[CsvService] OK via HTTP -> $effectiveUri (${parsed.length} filas)',
      );
      return parsed;
    } catch (e) {
      print('[CsvService] HTTP fallo en $url -> $e');
      rethrow;
    }
  }

  /// Loads CSV rows as List<List<dynamic>>.
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

  /// Loads CSV rows as List<Map<String, dynamic>>.
  static Future<List<Map<String, dynamic>>> loadCsvAsMap(
    String assetPath,
  ) async {
    final fileName = assetPath.replaceAll('\\', '/').split('/').last;
    final errors = <String>[];

    // 1) Web HTTP relative paths.
    if (kIsWeb) {
      final urls = ['assets/assets/data/$fileName', 'assets/data/$fileName'];

      for (final url in urls) {
        try {
          final result = await _tryHttp(url);
          if (result != null) return result;
        } catch (e) {
          errors.add('HTTP $url: $e');
        }
      }
    }

    // 2) Local rootBundle fallback.
    final bundlePaths = <String>['assets/data/$fileName', assetPath];
    final seen = <String>{};
    final uniquePaths = bundlePaths.where((p) => seen.add(p)).toList();

    for (final path in uniquePaths) {
      try {
        final raw = await rootBundle.loadString(path);
        final parsed = _parseCsvToMap(raw);
        if (parsed.isNotEmpty) {
          print(
            '[CsvService] OK via AssetBundle -> $path (${parsed.length} filas)',
          );
          return parsed;
        }
      } catch (e) {
        errors.add('AssetBundle $path: $e');
        print('[CsvService] AssetBundle fallo en $path -> $e');
      }
    }

    final errorMsg =
        'No se pudo cargar $fileName.\nErrores:\n${errors.join('\n')}';
    print('[CsvService] FALLO total para: $assetPath ($fileName)');
    throw Exception(errorMsg);
  }
}
