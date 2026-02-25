import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/trend_history_models.dart';
import 'package:frontend/services/data_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const service = DataService();

  test('DataService.loadCsvRows loads trend_score csv', () async {
    final rows = await service.loadCsvRows('assets/data/trend_score.csv');
    expect(rows, isNotEmpty);
    expect(rows.first.containsKey('tecnologia'), true);
  });

  test('DataService.loadPublicRunManifest loads public manifest', () async {
    final manifest = await service.loadPublicRunManifest();
    expect(manifest.manifestVersion, isNotEmpty);
    expect(manifest.datasetSummaries, isNotEmpty);
  });

  test('DataService.loadHistoryIndex loads bridge history index', () async {
    final history = await service.loadHistoryIndex();
    expect(history.datasetCount, greaterThanOrEqualTo(0));
  });

  test(
    'DataService.loadTrendScoreHistory loads bridge trend history',
    () async {
      final trend = await service.loadTrendScoreHistory();
      expect(trend, isA<TrendScoreHistoryModel>());
    },
  );

  test('DataService.loadTrendTemporalView resolves view payload', () async {
    final view = await service.loadTrendTemporalView(topN: 5);
    expect(view.source, isNotEmpty);
    expect(view.snapshotCount, greaterThanOrEqualTo(0));
    expect(view.items.length, lessThanOrEqualTo(5));
  });
}
