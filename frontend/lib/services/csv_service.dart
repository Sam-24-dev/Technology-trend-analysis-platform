import 'dart:convert' show utf8;

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

/// Servicio central de carga de CSVs.
///
/// Estrategia de carga (en orden):
///   1. HTTP GET con rutas relativas (web):
///      - assets/assets/data/<file>  (estructura de build Flutter)
///      - assets/data/<file>         (fallback)
///   2. rootBundle (local / flutter run).
///
/// Parser primario: manual (_parseCsvManual) — fiable en todas las
/// plataformas.  CsvToListConverter se usa solo como fallback porque
/// tiene problemas de detección de eol en Dart2JS compilado.
class CsvService {
  // ── Parser manual ──────────────────────────────────────────────

  /// Parser robusto para una línea CSV (maneja comillas escapadas).
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

  /// Parser manual de CSV a lista de mapas.
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
            for (var i = 0; i < headers.length; i++)
              headers[i]: i < vals.length ? vals[i] : '',
          };
        }(),
    ];
  }

  // ── Parser combinado ──────────────────────────────────────────

  /// Parsea CSV: intenta primero el parser manual (fiable en web),
  /// luego CsvToListConverter como fallback.
  static List<Map<String, dynamic>> _parseCsvToMap(String rawData) {
    if (rawData.trim().isEmpty) {
      print('[CsvService] _parseCsvToMap: input vacío');
      return [];
    }

    final probe = rawData.trimLeft();
    if (probe.startsWith('<!') || probe.startsWith('<html')) {
      print('[CsvService] _parseCsvToMap: detectó HTML, no CSV');
      return [];
    }

    // Log de diagnóstico: primeros 150 chars y longitud
    final preview = rawData.length > 150 ? rawData.substring(0, 150) : rawData;
    print('[CsvService] _parseCsvToMap: ${rawData.length} chars, '
        'first 20 code units: ${rawData.codeUnits.take(20).toList()}');
    print('[CsvService] _parseCsvToMap preview: $preview');

    // ── PRIMARY: Parser manual (funciona en todas las plataformas) ──
    final manual = _parseCsvManual(rawData);
    if (manual.isNotEmpty) {
      print('[CsvService] _parseCsvToMap: manual parser OK '
          '(${manual.length} filas, headers: ${manual.first.keys.toList()})');
      return manual;
    }
    print('[CsvService] _parseCsvToMap: manual parser devolvió vacío');

    // ── FALLBACK: CsvToListConverter ──
    try {
      final csvData = const CsvToListConverter().convert(rawData);
      print('[CsvService] _parseCsvToMap: CsvToListConverter '
          'rows=${csvData.length}');
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
    } catch (e) {
      print('[CsvService] _parseCsvToMap: CsvToListConverter falló: $e');
      return [];
    }
  }

  // ── Carga HTTP ────────────────────────────────────────────────

  /// Descarga un CSV por HTTP, decodifica como UTF-8, y parsea.
  static Future<List<Map<String, dynamic>>?> _tryHttp(String url) async {
    try {
      final uri = Uri.parse(url);
      final response =
          await http.get(uri).timeout(const Duration(seconds: 15));

      print('[CsvService] HTTP ${response.statusCode} ← $url '
          '(${response.bodyBytes.length} bytes)');

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode} en $url');
      }

      if (response.bodyBytes.isEmpty) {
        throw Exception('HTTP 200 body vacío en $url');
      }

      // Decodificar SIEMPRE como UTF-8 desde bytes crudos
      // (evita que package:http use latin1 por defecto)
      final body = utf8.decode(response.bodyBytes, allowMalformed: true);

      if (body.trim().isEmpty) {
        throw Exception('HTTP 200 body decodificado vacío en $url');
      }

      final parsed = _parseCsvToMap(body);
      if (parsed.isEmpty) {
        throw Exception('CSV parsing vacío para $url');
      }

      print('[CsvService] OK via HTTP → $url (${parsed.length} filas)');
      return parsed;
    } catch (e) {
      print('[CsvService] HTTP fallo en $url → $e');
      rethrow;
    }
  }

  // ── API pública ───────────────────────────────────────────────

  /// Carga CSV como List<List<dynamic>>.
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

  /// Carga CSV como List<Map<String, dynamic>>.
  static Future<List<Map<String, dynamic>>> loadCsvAsMap(
    String assetPath,
  ) async {
    final fileName = assetPath.replaceAll('\\', '/').split('/').last;
    final errors = <String>[];
    print('[CsvService] ═══ Cargando: $fileName ═══');

    // ── 1) HTTP con rutas relativas (web) ──
    if (kIsWeb) {
      final urls = [
        'assets/assets/data/$fileName',
        'assets/data/$fileName',
      ];
      for (final url in urls) {
        try {
          final result = await _tryHttp(url);
          if (result != null) return result;
        } catch (e) {
          errors.add('HTTP $url: $e');
        }
      }
    }

    // ── 2) rootBundle (local / flutter run) ──
    final bundlePaths = <String>['assets/data/$fileName', assetPath];
    final seen = <String>{};
    final unique = bundlePaths.where((p) => seen.add(p)).toList();

    for (final path in unique) {
      try {
        final raw = await rootBundle.loadString(path);
        final parsed = _parseCsvToMap(raw);
        if (parsed.isNotEmpty) {
          print('[CsvService] OK via AssetBundle → $path '
              '(${parsed.length} filas)');
          return parsed;
        }
        // Si parsed está vacío, registrar como error (antes se perdía)
        errors.add('AssetBundle $path: parseo devolvió vacío '
            '(${raw.length} chars cargados)');
      } catch (e) {
        errors.add('AssetBundle $path: $e');
        print('[CsvService] AssetBundle fallo en $path → $e');
      }
    }

    // ── 3) No se pudo cargar ──
    final errorMsg =
        'No se pudo cargar $fileName.\nErrores:\n${errors.join('\n')}';
    print('[CsvService] FALLO total para $fileName');
    throw Exception(errorMsg);
  }
}
