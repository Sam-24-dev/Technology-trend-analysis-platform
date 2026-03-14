import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/history_index_models.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/services/data_service.dart';

class FakeDataService extends DataService {
  const FakeDataService({
    this.csvByAsset = const {},
    this.jsonByAsset = const {},
    this.throwAssets = const {},
    this.fakeTrendView,
    this.fakeManifest,
    this.fakeHistory,
    this.fakeRedditSentimentPublic,
    this.fakeRedditTopicsHistoryPublic,
    this.fakeGithubLanguagePublic,
    this.fakeGithubFrameworksHistoryPublic,
    this.fakeGithubCorrelationHistoryPublic,
    this.fakeStackOverflowVolumeHistoryPublic,
    this.fakeStackOverflowAcceptanceHistoryPublic,
    this.fakeStackOverflowTrendsHistoryPublic,
    this.fakeTechnologyProfiles,
    this.csvDelay = Duration.zero,
    this.jsonDelay = Duration.zero,
    this.trendDelay = Duration.zero,
    this.manifestDelay = Duration.zero,
    this.historyDelay = Duration.zero,
    this.redditSentimentDelay = Duration.zero,
    this.redditTopicsDelay = Duration.zero,
    this.githubFrameworksDelay = Duration.zero,
    this.githubCorrelationDelay = Duration.zero,
    this.stackOverflowAcceptanceDelay = Duration.zero,
    this.stackOverflowTrendsDelay = Duration.zero,
  });

  final Map<String, List<Map<String, dynamic>>> csvByAsset;
  final Map<String, Map<String, dynamic>> jsonByAsset;
  final Set<String> throwAssets;
  final TrendTemporalViewData? fakeTrendView;
  final RunManifestPublic? fakeManifest;
  final HistoryIndexModel? fakeHistory;
  final Map<String, dynamic>? fakeRedditSentimentPublic;
  final Map<String, dynamic>? fakeRedditTopicsHistoryPublic;
  final Map<String, dynamic>? fakeGithubLanguagePublic;
  final Map<String, dynamic>? fakeGithubFrameworksHistoryPublic;
  final Map<String, dynamic>? fakeGithubCorrelationHistoryPublic;
  final Map<String, dynamic>? fakeStackOverflowVolumeHistoryPublic;
  final Map<String, dynamic>? fakeStackOverflowAcceptanceHistoryPublic;
  final Map<String, dynamic>? fakeStackOverflowTrendsHistoryPublic;
  final Map<String, dynamic>? fakeTechnologyProfiles;
  final Duration csvDelay;
  final Duration jsonDelay;
  final Duration trendDelay;
  final Duration manifestDelay;
  final Duration historyDelay;
  final Duration redditSentimentDelay;
  final Duration redditTopicsDelay;
  final Duration githubFrameworksDelay;
  final Duration githubCorrelationDelay;
  final Duration stackOverflowAcceptanceDelay;
  final Duration stackOverflowTrendsDelay;

  @override
  Future<List<Map<String, dynamic>>> loadCsvRows(String assetPath) async {
    if (csvDelay > Duration.zero) {
      await Future<void>.delayed(csvDelay);
    }
    if (throwAssets.contains(assetPath)) {
      throw Exception('forced error on $assetPath');
    }
    return csvByAsset[assetPath] ?? <Map<String, dynamic>>[];
  }

  @override
  Future<Map<String, dynamic>> loadJsonMap(String assetPath) async {
    if (jsonDelay > Duration.zero) {
      await Future<void>.delayed(jsonDelay);
    }
    if (throwAssets.contains(assetPath)) {
      throw Exception('forced error on $assetPath');
    }
    return jsonByAsset[assetPath] ?? <String, dynamic>{};
  }

  @override
  Future<RunManifestPublic> loadPublicRunManifest() async {
    if (manifestDelay > Duration.zero) {
      await Future<void>.delayed(manifestDelay);
    }
    if (throwAssets.contains('assets/data/run_manifest.json')) {
      throw Exception('manifest unavailable');
    }
    return fakeManifest ??
        RunManifestPublic.fromMap({
          'manifest_version': '1.0.0',
          'generated_at_utc': '2026-02-23T10:00:00Z',
          'source_window_start_utc': '2025-02-23T00:00:00Z',
          'source_window_end_utc': '2026-02-23T00:00:00Z',
          'quality_gate_status': 'pass',
          'degraded_mode': false,
          'available_sources': ['github', 'stackoverflow', 'reddit'],
          'dataset_summaries': [
            {
              'dataset': 'trend_score',
              'row_count': 23,
              'quality_status': 'pass',
              'updated_at_utc': '2026-02-23T09:59:30Z',
            },
          ],
        });
  }

  @override
  Future<HistoryIndexModel> loadHistoryIndex() async {
    if (historyDelay > Duration.zero) {
      await Future<void>.delayed(historyDelay);
    }
    if (throwAssets.contains('assets/data/history_index.json')) {
      throw Exception('history index unavailable');
    }
    return fakeHistory ??
        HistoryIndexModel.fromMap({
          'generated_at_utc': '2026-02-23T10:00:00Z',
          'dataset_count': 1,
          'datasets': [
            {
              'dataset': 'trend_score',
              'latest_path': 'datos/latest/trend_score.csv',
              'latest_row_count': 23,
              'history_snapshot_count': 1,
              'snapshots': [],
            },
          ],
        });
  }

  @override
  Future<TrendTemporalViewData> loadTrendTemporalView({int topN = 5}) async {
    if (trendDelay > Duration.zero) {
      await Future<void>.delayed(trendDelay);
    }
    if (throwAssets.contains('trend_temporal')) {
      throw Exception('trend temporal unavailable');
    }
    return fakeTrendView ??
        const TrendTemporalViewData(
          source: 'csv_fallback',
          snapshotCount: 1,
          items: [],
        );
  }

  @override
  Future<Map<String, dynamic>> loadRedditSentimentPublic() async {
    if (redditSentimentDelay > Duration.zero) {
      await Future<void>.delayed(redditSentimentDelay);
    }
    if (throwAssets.contains('assets/data/reddit_sentimiento_public.json')) {
      throw Exception('reddit sentiment public unavailable');
    }
    return fakeRedditSentimentPublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> loadRedditTopicsHistoryPublic() async {
    if (redditTopicsDelay > Duration.zero) {
      await Future<void>.delayed(redditTopicsDelay);
    }
    if (throwAssets.contains('assets/data/reddit_temas_history.json')) {
      throw Exception('reddit topics history public unavailable');
    }
    return fakeRedditTopicsHistoryPublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> loadGithubFrameworksHistoryPublic() async {
    if (githubFrameworksDelay > Duration.zero) {
      await Future<void>.delayed(githubFrameworksDelay);
    }
    if (throwAssets.contains('assets/data/github_frameworks_history.json')) {
      throw Exception('github frameworks history public unavailable');
    }
    return fakeGithubFrameworksHistoryPublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> loadGithubLanguagePublic() async {
    if (throwAssets.contains('assets/data/github_lenguajes_public.json')) {
      throw Exception('github language public unavailable');
    }
    return fakeGithubLanguagePublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> loadGithubCorrelationHistoryPublic() async {
    if (githubCorrelationDelay > Duration.zero) {
      await Future<void>.delayed(githubCorrelationDelay);
    }
    if (throwAssets.contains('assets/data/github_correlacion_history.json')) {
      throw Exception('github correlation history public unavailable');
    }
    return fakeGithubCorrelationHistoryPublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> loadStackOverflowVolumeHistoryPublic() async {
    if (throwAssets.contains('assets/data/so_volumen_history.json')) {
      throw Exception('stack overflow volume history public unavailable');
    }
    return fakeStackOverflowVolumeHistoryPublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>>
  loadStackOverflowAcceptanceHistoryPublic() async {
    if (stackOverflowAcceptanceDelay > Duration.zero) {
      await Future<void>.delayed(stackOverflowAcceptanceDelay);
    }
    if (throwAssets.contains('assets/data/so_aceptacion_history.json')) {
      throw Exception('stack overflow acceptance history public unavailable');
    }
    return fakeStackOverflowAcceptanceHistoryPublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> loadStackOverflowTrendsHistoryPublic() async {
    if (stackOverflowTrendsDelay > Duration.zero) {
      await Future<void>.delayed(stackOverflowTrendsDelay);
    }
    if (throwAssets.contains('assets/data/so_tendencias_history.json')) {
      throw Exception('stack overflow trends history public unavailable');
    }
    return fakeStackOverflowTrendsHistoryPublic ?? <String, dynamic>{};
  }

  @override
  Future<Map<String, dynamic>> loadTechnologyProfiles() async {
    if (throwAssets.contains('assets/data/technology_profiles.json')) {
      throw Exception('technology profiles unavailable');
    }
    return fakeTechnologyProfiles ?? <String, dynamic>{};
  }
}
