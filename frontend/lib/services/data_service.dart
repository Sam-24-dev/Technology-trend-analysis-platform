import '../config/feature_flags.dart';
import '../models/dashboard_domain_models.dart';
import '../models/history_index_models.dart';
import '../models/run_manifest_models.dart';
import '../models/trend_history_models.dart';
import 'csv_service.dart';
import 'retry_policy.dart';

class DataService {
  final RetryPolicy retryPolicy;

  const DataService({this.retryPolicy = const RetryPolicy()});

  Future<List<Map<String, dynamic>>> loadCsvRows(String assetPath) {
    return retryPolicy.run(() => CsvService.loadCsvAsMap(assetPath));
  }

  Future<Map<String, dynamic>> loadJsonMap(String assetPath) {
    return retryPolicy.run(() => CsvService.loadJsonAsMap(assetPath));
  }

  Future<RunManifestPublic> loadPublicRunManifest() async {
    final payload = await loadJsonMap('assets/data/run_manifest.json');
    return RunManifestPublic.fromMap(payload);
  }

  Future<HistoryIndexModel> loadHistoryIndex() async {
    final payload = await loadJsonMap('assets/data/history_index.json');
    return HistoryIndexModel.fromMap(payload);
  }

  Future<TrendScoreHistoryModel> loadTrendScoreHistory() async {
    final payload = await loadJsonMap('assets/data/trend_score_history.json');
    return TrendScoreHistoryModel.fromMap(payload);
  }

  Future<TrendTemporalViewData> loadTrendTemporalView({int topN = 5}) async {
    if (FeatureFlags.useHistoryBridgeJson) {
      try {
        final trendHistory = await loadTrendScoreHistory();
        if (trendHistory.snapshots.isNotEmpty) {
          final latestSnapshot = trendHistory.snapshots.last;
          return TrendTemporalViewData(
            source: 'bridge_json',
            snapshotCount: trendHistory.snapshotCount,
            items: latestSnapshot.top10.take(topN).toList(),
          );
        }
      } catch (_) {
        if (!FeatureFlags.enableCsvFallback) {
          rethrow;
        }
      }
    }

    if (!FeatureFlags.enableCsvFallback && FeatureFlags.useHistoryBridgeJson) {
      throw Exception('Bridge JSON unavailable and CSV fallback disabled');
    }

    final csvPayload = await CsvService.loadTrendTemporalView(topN: topN);
    final rawItems = (csvPayload['items'] as List?) ?? const [];
    final items = rawItems
        .whereType<Map>()
        .map((item) => TrendTopEntry.fromMap(item.cast<String, dynamic>()))
        .toList();

    return TrendTemporalViewData(
      source: csvPayload['source']?.toString() ?? 'csv',
      snapshotCount:
          int.tryParse(csvPayload['snapshotCount']?.toString() ?? '0') ?? 0,
      items: items,
    );
  }
}
