import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/history_index_models.dart';

void main() {
  test('HistoryIndexModel.fromMap parses nested structure', () {
    final model = HistoryIndexModel.fromMap({
      'generated_at_utc': '2026-02-23T10:00:00Z',
      'dataset_count': 1,
      'datasets': [
        {
          'dataset': 'trend_score',
          'latest_path': 'datos/latest/trend_score.csv',
          'latest_row_count': 23,
          'history_snapshot_count': 1,
          'snapshots': [
            {
              'date': '2026-02-23',
              'path':
                  'datos/history/trend_score/year=2026/month=02/day=23/trend_score.csv',
              'row_count': 23,
            },
          ],
        },
      ],
    });

    expect(model.generatedAtUtc, '2026-02-23T10:00:00Z');
    expect(model.datasetCount, 1);
    expect(model.datasets.first.dataset, 'trend_score');
    expect(model.datasets.first.snapshots.first.date, '2026-02-23');
  });
}
