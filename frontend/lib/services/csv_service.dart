import 'dart:convert' show jsonDecode, utf8;

import 'package:csv/csv.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;

import '../config/feature_flags.dart';
import '../utils/tech_slug.dart';

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
  static Map<String, dynamic> _coerceJsonMap(dynamic parsed, String source) {
    if (parsed is Map<String, dynamic>) {
      return parsed;
    }
    if (parsed is Map) {
      return parsed.map((key, value) => MapEntry(key.toString(), value));
    }
    throw Exception('Invalid JSON payload shape for $source');
  }

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
    print(
      '[CsvService] _parseCsvToMap: ${rawData.length} chars, '
      'first 20 code units: ${rawData.codeUnits.take(20).toList()}',
    );
    print('[CsvService] _parseCsvToMap preview: $preview');

    // ── PRIMARY: Parser manual (funciona en todas las plataformas) ──
    final manual = _parseCsvManual(rawData);
    if (manual.isNotEmpty) {
      print(
        '[CsvService] _parseCsvToMap: manual parser OK '
        '(${manual.length} filas, headers: ${manual.first.keys.toList()})',
      );
      return manual;
    }
    print('[CsvService] _parseCsvToMap: manual parser devolvió vacío');

    // ── FALLBACK: CsvToListConverter ──
    try {
      final csvData = const CsvToListConverter().convert(rawData);
      print(
        '[CsvService] _parseCsvToMap: CsvToListConverter '
        'rows=${csvData.length}',
      );
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
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      print(
        '[CsvService] HTTP ${response.statusCode} ← $url '
        '(${response.bodyBytes.length} bytes)',
      );

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

    // ── 2) rootBundle (local / flutter run) ──
    final bundlePaths = <String>['assets/data/$fileName', assetPath];
    final seen = <String>{};
    final unique = bundlePaths.where((p) => seen.add(p)).toList();

    for (final path in unique) {
      try {
        final raw = await rootBundle.loadString(path);
        final parsed = _parseCsvToMap(raw);
        if (parsed.isNotEmpty) {
          print(
            '[CsvService] OK via AssetBundle → $path '
            '(${parsed.length} filas)',
          );
          return parsed;
        }
        // Si parsed está vacío, registrar como error (antes se perdía)
        errors.add(
          'AssetBundle $path: parseo devolvió vacío '
          '(${raw.length} chars cargados)',
        );
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

  /// Carga un JSON asset y lo retorna como mapa.
  static Future<Map<String, dynamic>> loadJsonAsMap(String assetPath) async {
    final fileName = assetPath.replaceAll('\\', '/').split('/').last;
    final errors = <String>[];
    print('[CsvService] === Loading JSON: $fileName ===');

    if (kIsWeb) {
      final urls = ['assets/assets/data/$fileName', 'assets/data/$fileName'];
      for (final url in urls) {
        try {
          final response = await http
              .get(Uri.parse(url))
              .timeout(const Duration(seconds: 15));
          if (response.statusCode != 200) {
            throw Exception('HTTP ${response.statusCode}');
          }
          final body = utf8.decode(response.bodyBytes, allowMalformed: true);
          return _coerceJsonMap(jsonDecode(body), url);
        } catch (e) {
          errors.add('HTTP $url: $e');
        }
      }
    }

    final bundlePaths = <String>['assets/data/$fileName', assetPath];
    final seen = <String>{};
    final unique = bundlePaths.where((p) => seen.add(p)).toList();

    for (final path in unique) {
      try {
        final raw = await rootBundle.loadString(path);
        return _coerceJsonMap(jsonDecode(raw), path);
      } catch (e) {
        errors.add('AssetBundle $path: $e');
      }
    }

    throw Exception(
      'No se pudo cargar JSON $fileName.\nErrores:\n${errors.join('\n')}',
    );
  }

  /// Carga un JSON por URL absoluta (http/https).
  static Future<Map<String, dynamic>> loadJsonFromUrl(String url) async {
    final uri = Uri.parse(url);
    if (!(uri.scheme == 'http' || uri.scheme == 'https')) {
      throw Exception('URL no soportada para JSON remoto: $url');
    }

    final response = await http.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode} en $url');
    }
    final body = utf8.decode(response.bodyBytes, allowMalformed: true);
    return _coerceJsonMap(jsonDecode(body), url);
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((item) => item.toString()).toList();
    }
    return const [];
  }

  static List<Map<String, dynamic>> _normalizeTrendRowsFromCsv(
    List<Map<String, dynamic>> csvRows,
    int topN,
  ) {
    final normalized = csvRows
        .map(
          (row) => {
            'ranking': _asInt(row['ranking'], fallback: 999999),
            'slug': normalizeSlug(row['tecnologia']?.toString() ?? ''),
            'tecnologia': row['tecnologia']?.toString() ?? '',
            'trend_score': _asDouble(row['trend_score'], fallback: 0.0),
            'fuentes': _asInt(row['fuentes'], fallback: 0),
            'github_score': _asDouble(row['github_score'], fallback: 0.0),
            'so_score': _asDouble(row['so_score'], fallback: 0.0),
            'reddit_score': _asDouble(row['reddit_score'], fallback: 0.0),
            'score_prev': _tryDouble(row['score_prev']),
            'delta_score': _tryDouble(row['delta_score']),
            'ranking_prev': _tryInt(row['ranking_prev']),
            'delta_ranking': _tryInt(row['delta_ranking']),
            'available_source_codes':
                _resolveCsvSourceCodes(row, _asInt(row['fuentes'])),
          },
        )
        .where((row) => (row['tecnologia']?.toString().isNotEmpty ?? false))
        .toList();

      normalized.sort(
        (a, b) => _asInt(a['ranking']).compareTo(_asInt(b['ranking'])),
      );
      return normalized.take(topN).toList();
    }

    static double? _tryDouble(dynamic value) {
      return double.tryParse(value?.toString() ?? '');
    }

    static int? _tryInt(dynamic value) {
      return int.tryParse(value?.toString() ?? '');
    }

    static List<String> _resolveCsvSourceCodes(
      Map<String, dynamic> row,
      int fuentes,
    ) {
      final List<String> codes = <String>[];
      final double gh = _asDouble(row['github_score'], fallback: 0.0);
      final double so = _asDouble(row['so_score'], fallback: 0.0);
      final double rd = _asDouble(row['reddit_score'], fallback: 0.0);
      if (gh > 0) codes.add('GH');
      if (so > 0) codes.add('SO');
      if (rd > 0) codes.add('RD');
      const List<String> ordered = <String>['GH', 'SO', 'RD'];
      for (final label in ordered) {
        if (codes.length >= fuentes && fuentes > 0) {
          break;
        }
        if (!codes.contains(label)) {
          codes.add(label);
        }
      }
      return codes;
    }

  /// Carga metadata publica de run manifest para UI.
  ///
  /// `status`:
  /// - available
  /// - metadata_unavailable
  /// - disabled
  static Future<Map<String, dynamic>> loadPublicRunManifestView() async {
    if (!FeatureFlags.usePublicRunManifest) {
      return const {
        'status': 'disabled',
        'message': 'Public run manifest disabled by feature flag',
      };
    }

    try {
      final payload = await loadJsonAsMap('assets/data/run_manifest.json');
      final datasetSummaries =
          (payload['dataset_summaries'] as List?) ?? const [];
      return {
        'status': 'available',
        'quality_gate_status':
            payload['quality_gate_status']?.toString() ?? 'unknown',
        'generated_at_utc': payload['generated_at_utc']?.toString() ?? '',
        'degraded_mode': payload['degraded_mode'] == true,
        'available_sources': _toStringList(payload['available_sources']),
        'dataset_count': datasetSummaries.length,
      };
    } catch (e) {
      return {
        'status': 'metadata_unavailable',
        'message': 'metadata unavailable',
        'error': e.toString(),
      };
    }
  }

  /// Carga vista temporal de Trend Score.
  ///
  /// Si `useHistoryBridgeJson` está activo, intenta usar bridge JSON y
  /// mantiene fallback automático a CSV.
  static Future<Map<String, dynamic>> loadTrendTemporalView({
    int topN = 5,
  }) async {
    final csvRows = await loadCsvAsMap('assets/data/trend_score.csv');
    final csvTop = _normalizeTrendRowsFromCsv(csvRows, topN);

    if (!FeatureFlags.useHistoryBridgeJson) {
      return {
        'source': 'csv',
        'snapshotCount': csvTop.isEmpty ? 0 : 1,
        'items': csvTop,
      };
    }

    try {
      final bridgePayload = await loadJsonAsMap(
        'assets/data/trend_score_history.json',
      );
      final rawSnapshots = (bridgePayload['snapshots'] as List?) ?? const [];
      if (rawSnapshots.isEmpty) {
        return {
          'source': 'csv_fallback',
          'snapshotCount': csvTop.isEmpty ? 0 : 1,
          'items': csvTop,
        };
      }

      final latestSnapshot = rawSnapshots.last;
      if (latestSnapshot is! Map) {
        return {
          'source': 'csv_fallback',
          'snapshotCount': csvTop.isEmpty ? 0 : 1,
          'items': csvTop,
        };
      }

      final Map latestSnapshotMap = latestSnapshot;
      final Map? previousSnapshot =
          rawSnapshots.length >= 2 ? rawSnapshots[rawSnapshots.length - 2] as Map? : null;
      final String? latestDate = latestSnapshotMap['date']?.toString();
      final String? previousDate = previousSnapshot?['date']?.toString();
              final topRows = (latestSnapshotMap['top_10'] as List?) ?? const [];
              final bridgeItems = topRows
                  .whereType<Map>()
                  .map(
                    (row) => {
                        'ranking': _asInt(row['ranking'], fallback: 999999),
                        'slug': row['slug']?.toString() ??
                    normalizeSlug(row['tecnologia']?.toString() ?? ''),
                        'tecnologia': row['tecnologia']?.toString() ?? '',
                        'trend_score': _asDouble(row['trend_score'], fallback: 0.0),
                        'fuentes': _asInt(row['fuentes'], fallback: 0),
                'github_score': _asDouble(row['github_score'], fallback: 0.0),
                'so_score': _asDouble(row['so_score'], fallback: 0.0),
                'reddit_score': _asDouble(row['reddit_score'], fallback: 0.0),
                'score_prev': _tryDouble(row['score_prev']),
                'delta_score': _tryDouble(row['delta_score']),
                'ranking_prev': _tryInt(row['ranking_prev']),
                'delta_ranking': _tryInt(row['delta_ranking']),
                'available_source_codes':
                    _toStringList(row['available_source_codes'])
                        .map((code) => code.toUpperCase())
                        .toList(),
              },
            )
            .where((row) => (row['tecnologia']?.toString().isNotEmpty ?? false))
            .take(topN)
            .toList();

        if (bridgeItems.isNotEmpty) {
          return {
            'source': 'bridge_json',
            'snapshotCount': rawSnapshots.length,
            'items': bridgeItems,
            'latestSnapshotDate': latestDate,
            'previousSnapshotDate': previousDate,
          };
        }
      } catch (e) {
        print('[CsvService] Bridge JSON fallback to CSV: $e');
      }

      return {
        'source': 'csv_fallback',
        'snapshotCount': csvTop.isEmpty ? 0 : 1,
        'items': csvTop,
      };
    }
  }
