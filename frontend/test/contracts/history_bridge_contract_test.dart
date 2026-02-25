import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

const String _validHistoryIndexJson = '''
{
  "generated_at_utc": "2026-02-23T08:58:55Z",
  "dataset_count": 1,
  "datasets": [
    {
      "dataset": "trend_score",
      "latest_path": "datos/latest/trend_score.csv",
      "latest_row_count": 23,
      "history_snapshot_count": 1,
      "snapshots": [
        {
          "date": "2026-02-23",
          "path": "datos/history/trend_score/year=2026/month=02/day=23/trend_score.csv",
          "row_count": 23
        }
      ]
    }
  ]
}
''';

const String _invalidHistoryIndexJson = '''
{
  "generated_at_utc": "invalid-date",
  "dataset_count": "x",
  "datasets": []
}
''';

const String _validTrendHistoryJson = '''
{
  "generated_at_utc": "2026-02-23T08:58:55Z",
  "snapshot_count": 1,
  "snapshots": [
    {
      "date": "2026-02-23",
      "path": "datos/history/trend_score/year=2026/month=02/day=23/trend_score.csv",
      "source_type": "history",
      "row_count": 23,
      "top_10": [
        {
          "ranking": 1,
          "tecnologia": "Python",
          "trend_score": 76.45,
          "fuentes": 3
        }
      ]
    }
  ],
  "series": [
    {
      "tecnologia": "Python",
      "points": [
        {
          "date": "2026-02-23",
          "ranking": 1,
          "trend_score": 76.45,
          "fuentes": 3
        }
      ]
    }
  ]
}
''';

const String _invalidTrendHistoryJson = '''
{
  "generated_at_utc": "invalid-date",
  "snapshot_count": "x",
  "snapshots": [
    {
      "date": "",
      "path": "",
      "source_type": "",
      "row_count": -1,
      "top_10": []
    }
  ]
}
''';

bool _isIsoDateTime(dynamic value) =>
    DateTime.tryParse(value?.toString() ?? '') != null;

bool _isIsoDate(dynamic value) =>
    RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value?.toString() ?? '');

List<String> _validateHistoryIndex(Map<String, dynamic> payload) {
  final errors = <String>[];

  for (final field in const <String>[
    'generated_at_utc',
    'dataset_count',
    'datasets',
  ]) {
    if (!payload.containsKey(field)) {
      errors.add('missing:$field');
    }
  }

  if (!_isIsoDateTime(payload['generated_at_utc'])) {
    errors.add('invalid:generated_at_utc');
  }

  final datasetCount = int.tryParse(payload['dataset_count']?.toString() ?? '');
  if (datasetCount == null || datasetCount < 0) {
    errors.add('invalid:dataset_count');
  }

  final datasets = payload['datasets'];
  if (datasets is! List || datasets.isEmpty) {
    errors.add('invalid:datasets');
    return errors;
  }

  for (final dataset in datasets.whereType<Map>()) {
    final map = dataset.cast<String, dynamic>();
    if ((map['dataset']?.toString() ?? '').isEmpty) {
      errors.add('invalid:dataset_name');
    }
    final historySnapshotCount = int.tryParse(
      map['history_snapshot_count']?.toString() ?? '',
    );
    if (historySnapshotCount == null || historySnapshotCount < 0) {
      errors.add('invalid:history_snapshot_count');
    }

    final snapshots = map['snapshots'];
    if (snapshots is! List || snapshots.isEmpty) {
      errors.add('invalid:snapshots');
      continue;
    }

    for (final snapshot in snapshots.whereType<Map>()) {
      final snapshotMap = snapshot.cast<String, dynamic>();
      if (!_isIsoDate(snapshotMap['date'])) {
        errors.add('invalid:snapshot_date');
      }
      if ((snapshotMap['path']?.toString() ?? '').isEmpty) {
        errors.add('invalid:snapshot_path');
      }
      final rowCount = int.tryParse(snapshotMap['row_count']?.toString() ?? '');
      if (rowCount == null || rowCount < 0) {
        errors.add('invalid:snapshot_row_count');
      }
    }
  }

  return errors;
}

List<String> _validateTrendHistory(Map<String, dynamic> payload) {
  final errors = <String>[];

  for (final field in const <String>[
    'generated_at_utc',
    'snapshot_count',
    'snapshots',
    'series',
  ]) {
    if (!payload.containsKey(field)) {
      errors.add('missing:$field');
    }
  }

  if (!_isIsoDateTime(payload['generated_at_utc'])) {
    errors.add('invalid:generated_at_utc');
  }

  final snapshotCount = int.tryParse(
    payload['snapshot_count']?.toString() ?? '',
  );
  if (snapshotCount == null || snapshotCount < 0) {
    errors.add('invalid:snapshot_count');
  }

  final snapshots = payload['snapshots'];
  if (snapshots is! List || snapshots.isEmpty) {
    errors.add('invalid:snapshots');
    return errors;
  }

  for (final snapshot in snapshots.whereType<Map>()) {
    final map = snapshot.cast<String, dynamic>();
    if (!_isIsoDate(map['date'])) {
      errors.add('invalid:snapshot_date');
    }
    if ((map['path']?.toString() ?? '').isEmpty) {
      errors.add('invalid:snapshot_path');
    }
    if ((map['source_type']?.toString() ?? '').isEmpty) {
      errors.add('invalid:source_type');
    }
    final rowCount = int.tryParse(map['row_count']?.toString() ?? '');
    if (rowCount == null || rowCount < 0) {
      errors.add('invalid:row_count');
    }

    final top10 = map['top_10'];
    if (top10 is! List || top10.isEmpty) {
      errors.add('invalid:top_10');
      continue;
    }

    for (final entry in top10.whereType<Map>()) {
      final item = entry.cast<String, dynamic>();
      final ranking = int.tryParse(item['ranking']?.toString() ?? '');
      final trendScore = double.tryParse(item['trend_score']?.toString() ?? '');
      final fuentes = int.tryParse(item['fuentes']?.toString() ?? '');
      if (ranking == null || ranking <= 0) {
        errors.add('invalid:ranking');
      }
      if ((item['tecnologia']?.toString() ?? '').isEmpty) {
        errors.add('invalid:tecnologia');
      }
      if (trendScore == null || trendScore < 0) {
        errors.add('invalid:trend_score');
      }
      if (fuentes == null || fuentes < 0) {
        errors.add('invalid:fuentes');
      }
    }
  }

  final series = payload['series'];
  if (series is! List) {
    errors.add('invalid:series');
  }

  return errors;
}

void main() {
  test('history_index contract accepts valid payload', () {
    final payload = jsonDecode(_validHistoryIndexJson) as Map<String, dynamic>;
    final errors = _validateHistoryIndex(payload);
    expect(errors, isEmpty);
  });

  test('history_index contract rejects invalid payload', () {
    final payload =
        jsonDecode(_invalidHistoryIndexJson) as Map<String, dynamic>;
    final errors = _validateHistoryIndex(payload);
    expect(errors, isNotEmpty);
    expect(errors, contains('invalid:generated_at_utc'));
    expect(errors, contains('invalid:dataset_count'));
    expect(errors, contains('invalid:datasets'));
  });

  test('trend_score_history contract accepts valid payload', () {
    final payload = jsonDecode(_validTrendHistoryJson) as Map<String, dynamic>;
    final errors = _validateTrendHistory(payload);
    expect(errors, isEmpty);
  });

  test('trend_score_history contract rejects invalid payload', () {
    final payload =
        jsonDecode(_invalidTrendHistoryJson) as Map<String, dynamic>;
    final errors = _validateTrendHistory(payload);
    expect(errors, isNotEmpty);
    expect(errors, contains('invalid:generated_at_utc'));
    expect(errors, contains('invalid:snapshot_count'));
    expect(errors, contains('invalid:top_10'));
  });
}
