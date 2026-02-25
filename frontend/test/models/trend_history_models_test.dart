import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/trend_history_models.dart';

void main() {
  test('TrendScoreHistoryModel.fromMap parses snapshots and top10', () {
    final model = TrendScoreHistoryModel.fromMap({
      'generated_at_utc': '2026-02-23T10:00:00Z',
      'snapshot_count': 1,
      'snapshots': [
        {
          'date': '2026-02-23',
          'path':
              'datos/history/trend_score/year=2026/month=02/day=23/trend_score.csv',
          'source_type': 'history',
          'row_count': 23,
          'top_10': [
            {
              'ranking': 1,
              'tecnologia': 'Python',
              'trend_score': 76.45,
              'fuentes': 3,
            },
          ],
        },
      ],
    });

    expect(model.snapshotCount, 1);
    expect(model.snapshots.first.sourceType, 'history');
    expect(model.snapshots.first.top10.first.tecnologia, 'Python');
    expect(model.snapshots.first.top10.first.trendScore, 76.45);
  });
}
