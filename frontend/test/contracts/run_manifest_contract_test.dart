import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

const String _validManifestJson = '''
{
  "manifest_version": "1.0.0",
  "generated_at_utc": "2026-02-23T10:00:00Z",
  "source_window_start_utc": "2025-02-23T00:00:00Z",
  "source_window_end_utc": "2026-02-23T00:00:00Z",
  "quality_gate_status": "pass_with_warnings",
  "degraded_mode": true,
  "available_sources": ["github", "stackoverflow"],
  "dataset_summaries": [
    {
      "dataset": "trend_score",
      "row_count": 23,
      "quality_status": "pass",
      "updated_at_utc": "2026-02-23T09:59:30Z"
    }
  ],
  "total_repos_extraidos": 1000,
  "total_repos_clasificables": 925,
  "so_languages_count": 10,
  "notes": "Reddit temporalmente no disponible"
}
''';

const String _invalidManifestJson = '''
{
  "manifest_version": "1",
  "generated_at_utc": "23-02-2026",
  "quality_gate_status": "ok",
  "degraded_mode": "true",
  "available_sources": ["github", "github"],
  "dataset_summaries": []
}
''';

final RegExp _semverRegex = RegExp(
  r'^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$',
);

bool _isIsoUtc(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '') != null;

List<String> _validatePublicRunManifest(Map<String, dynamic> payload) {
  final errors = <String>[];

  const required = <String>[
    'manifest_version',
    'generated_at_utc',
    'source_window_start_utc',
    'source_window_end_utc',
    'quality_gate_status',
    'degraded_mode',
    'available_sources',
    'dataset_summaries',
    'total_repos_extraidos',
    'total_repos_clasificables',
    'so_languages_count',
  ];

  for (final field in required) {
    if (!payload.containsKey(field)) {
      errors.add('missing:$field');
    }
  }

  final version = payload['manifest_version']?.toString() ?? '';
  if (!_semverRegex.hasMatch(version)) {
    errors.add('invalid:manifest_version');
  }

  for (final field in const <String>[
    'generated_at_utc',
    'source_window_start_utc',
    'source_window_end_utc',
  ]) {
    if (!_isIsoUtc(payload[field])) {
      errors.add('invalid:$field');
    }
  }

  if (payload['quality_gate_status'] is! String ||
      !const <String>{
        'pass',
        'pass_with_warnings',
        'fail',
      }.contains(payload['quality_gate_status'])) {
    errors.add('invalid:quality_gate_status');
  }

  if (payload['degraded_mode'] is! bool) {
    errors.add('invalid:degraded_mode');
  }

  for (final field in const <String>[
    'total_repos_extraidos',
    'total_repos_clasificables',
    'so_languages_count',
  ]) {
    final value = payload[field];
    if (value is! int || value < 0) {
      errors.add('invalid:$field');
    }
  }

  final sources = payload['available_sources'];
  if (sources is! List) {
    errors.add('invalid:available_sources');
  } else {
    final unique = sources.map((item) => item.toString()).toSet();
    if (unique.length != sources.length) {
      errors.add('invalid:available_sources_duplicates');
    }
  }

  final datasets = payload['dataset_summaries'];
  if (datasets is! List || datasets.isEmpty) {
    errors.add('invalid:dataset_summaries');
  }

  return errors;
}

void main() {
  test('run_manifest public contract accepts valid payload', () {
    final payload = jsonDecode(_validManifestJson) as Map<String, dynamic>;
    final errors = _validatePublicRunManifest(payload);
    expect(errors, isEmpty);
  });

  test('run_manifest public contract rejects invalid payload', () {
    final payload = jsonDecode(_invalidManifestJson) as Map<String, dynamic>;
    final errors = _validatePublicRunManifest(payload);
    expect(errors, isNotEmpty);
    expect(errors, contains('invalid:manifest_version'));
    expect(errors, contains('invalid:degraded_mode'));
    expect(errors, contains('invalid:dataset_summaries'));
  });
}
