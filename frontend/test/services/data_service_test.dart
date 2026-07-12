import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:frontend/models/trend_history_models.dart';
import 'package:frontend/services/csv_service.dart';
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

  test(
    'DataService.loadRedditSentimentPublic loads public reddit sentiment bridge',
    () async {
      final payload = await service.loadRedditSentimentPublic();
      expect(payload['dataset'], 'reddit_sentimiento_frameworks');
      expect(payload['frameworks'], isA<List<dynamic>>());
    },
  );

  test(
    'DataService.loadRedditTopicsHistoryPublic loads reddit topics history bridge',
    () async {
      final payload = await service.loadRedditTopicsHistoryPublic();
      expect(payload['dataset'], 'reddit_temas_emergentes');
      expect(payload['latest_topics'], isA<List<dynamic>>());
    },
  );

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

  test(
    'DataService.loadGithubCorrelationHistoryPublic loads correlation bridge',
    () async {
      final payload = await service.loadGithubCorrelationHistoryPublic();
      expect(payload['dataset'], 'github_correlacion');
      expect(payload['latest_items'], isA<List<dynamic>>());
      expect(payload['summary'], isA<Map<dynamic, dynamic>>());
    },
  );

  test('DataService.loadTrendTemporalView resolves view payload', () async {
    final view = await service.loadTrendTemporalView(topN: 5);
    expect(view.source, isNotEmpty);
    expect(view.snapshotCount, greaterThanOrEqualTo(0));
    expect(view.items.length, lessThanOrEqualTo(5));
  });

  test('DataService rejects insecure remote JSON URLs', () async {
    await expectLater(
      service.loadJsonFromUrl('http://example.test/data.json'),
      throwsA(
        isA<Exception>().having(
          (error) => error.toString(),
          'message',
          contains('HTTPS'),
        ),
      ),
    );
  });

  test('CsvService rejects oversized remote JSON responses', () async {
    final client = MockClient(
      (_) async => http.Response.bytes(
        List<int>.filled(2 * 1024 * 1024 + 1, 0),
        200,
        headers: const {'content-type': 'application/json'},
      ),
    );

    await expectLater(
      CsvService.loadJsonFromUrl('https://example.test/data.json', client: client),
      throwsA(isA<Exception>().having((error) => error.toString(), 'message', contains('too large'))),
    );
  });
}
