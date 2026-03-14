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

  String _resolveRemoteUrl(String assetPath, String? explicitUrl) {
    final String cleaned = explicitUrl?.trim() ?? '';
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    final String fileName =
        assetPath.replaceAll('\\', '/').split('/').last.trim();
    return FeatureFlags.buildRemoteAssetUrl(fileName);
  }

  Future<Map<String, dynamic>> _loadJsonBridge({
    required String assetPath,
    String? explicitUrl,
  }) async {
    final String remoteUrl = _resolveRemoteUrl(assetPath, explicitUrl);
    if (remoteUrl.isNotEmpty) {
      try {
        return await loadJsonFromUrl(remoteUrl);
      } catch (_) {
        if (!FeatureFlags.enableCsvFallback) {
          rethrow;
        }
      }
    }
    return loadJsonMap(assetPath);
  }

  Future<List<Map<String, dynamic>>> loadCsvRows(String assetPath) {
    return retryPolicy.run(() => CsvService.loadCsvAsMap(assetPath));
  }

  Future<Map<String, dynamic>> loadJsonMap(String assetPath) {
    return retryPolicy.run(() => CsvService.loadJsonAsMap(assetPath));
  }

  Future<Map<String, dynamic>> loadJsonFromUrl(String url) {
    return retryPolicy.run(() => CsvService.loadJsonFromUrl(url));
  }

  Future<RunManifestPublic> loadPublicRunManifest() async {
    final payload = await loadJsonMap('assets/data/run_manifest.json');
    return RunManifestPublic.fromMap(payload);
  }

  Future<Map<String, dynamic>> loadRedditSentimentPublic() async {
    if (!FeatureFlags.useRedditSentimentPublicJson) {
      throw Exception(
        'reddit sentiment public bridge disabled by feature flag',
      );
    }

    return _loadJsonBridge(
      assetPath: 'assets/data/reddit_sentimiento_public.json',
      explicitUrl: FeatureFlags.redditSentimentPublicUrl,
    );
  }

  Future<Map<String, dynamic>> loadRedditTopicsHistoryPublic() async {
    if (!FeatureFlags.useRedditTopicsHistoryJson) {
      throw Exception(
        'reddit topics history public bridge disabled by feature flag',
      );
    }

    return _loadJsonBridge(
      assetPath: 'assets/data/reddit_temas_history.json',
      explicitUrl: FeatureFlags.redditTopicsHistoryUrl,
    );
  }

  Future<Map<String, dynamic>> loadRedditIntersectionHistoryPublic() async {
    if (!FeatureFlags.useRedditIntersectionHistoryJson) {
      throw Exception(
        'reddit intersection history public bridge disabled by feature flag',
      );
    }

    return _loadJsonBridge(
      assetPath: 'assets/data/reddit_interseccion_history.json',
      explicitUrl: FeatureFlags.redditIntersectionHistoryUrl,
    );
  }

  Future<Map<String, dynamic>> loadGithubFrameworksHistoryPublic() async {
    if (!FeatureFlags.useGithubFrameworksHistoryJson) {
      throw Exception(
        'github frameworks history public bridge disabled by feature flag',
      );
    }

    return _loadJsonBridge(
      assetPath: 'assets/data/github_frameworks_history.json',
      explicitUrl: FeatureFlags.githubFrameworksHistoryUrl,
    );
  }

  Future<Map<String, dynamic>> loadGithubLanguagePublic() async {
    return _loadJsonBridge(
      assetPath: 'assets/data/github_lenguajes_public.json',
    );
  }

  Future<Map<String, dynamic>> loadGithubCorrelationHistoryPublic() async {
    if (!FeatureFlags.useGithubCorrelationHistoryJson) {
      throw Exception(
        'github correlation history public bridge disabled by feature flag',
      );
    }

    return _loadJsonBridge(
      assetPath: 'assets/data/github_correlacion_history.json',
      explicitUrl: FeatureFlags.githubCorrelationHistoryUrl,
    );
  }

  Future<Map<String, dynamic>> loadStackOverflowVolumeHistoryPublic() async {
    return _loadJsonBridge(
      assetPath: 'assets/data/so_volumen_history.json',
    );
  }

  Future<Map<String, dynamic>>
  loadStackOverflowAcceptanceHistoryPublic() async {
    return _loadJsonBridge(
      assetPath: 'assets/data/so_aceptacion_history.json',
    );
  }

  Future<Map<String, dynamic>> loadStackOverflowTrendsHistoryPublic() async {
    return _loadJsonBridge(
      assetPath: 'assets/data/so_tendencias_history.json',
    );
  }

  Future<Map<String, dynamic>> loadHomeHighlights() async {
    return _loadJsonBridge(
      assetPath: 'assets/data/home_highlights.json',
    );
  }

  Future<Map<String, dynamic>> loadTechnologyProfiles() async {
    if (!FeatureFlags.useHistoryBridgeJson) {
      throw Exception('technology profiles bridge disabled by feature flag');
    }
    return _loadJsonBridge(
      assetPath: 'assets/data/technology_profiles.json',
    );
  }

  Future<HistoryIndexModel> loadHistoryIndex() async {
    final payload = await _loadJsonBridge(
      assetPath: 'assets/data/history_index.json',
    );
    return HistoryIndexModel.fromMap(payload);
  }

  Future<TrendScoreHistoryModel> loadTrendScoreHistory() async {
    final payload = await _loadJsonBridge(
      assetPath: 'assets/data/trend_score_history.json',
    );
    return TrendScoreHistoryModel.fromMap(payload);
  }

  Future<TrendTemporalViewData> loadTrendTemporalView({int topN = 5}) async {
    if (FeatureFlags.useHistoryBridgeJson) {
      try {
        final trendHistory = await loadTrendScoreHistory();
        if (trendHistory.snapshots.isNotEmpty) {
          final latestSnapshot = trendHistory.snapshots.last;
          final TrendSnapshotModel? previousSnapshot =
              trendHistory.snapshots.length >= 2
                  ? trendHistory.snapshots[trendHistory.snapshots.length - 2]
                  : null;
          return TrendTemporalViewData(
            source: 'bridge_json',
            snapshotCount: trendHistory.snapshotCount,
            items: latestSnapshot.top10.take(topN).toList(),
            latestSnapshotDate: latestSnapshot.date,
            previousSnapshotDate: previousSnapshot?.date,
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

    final csvPayload = await retryPolicy.run(
      () => CsvService.loadTrendTemporalView(topN: topN),
    );
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
      latestSnapshotDate: csvPayload['latestSnapshotDate']?.toString(),
      previousSnapshotDate: csvPayload['previousSnapshotDate']?.toString(),
    );
  }
}
