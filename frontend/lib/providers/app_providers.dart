import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/history_index_models.dart';
import '../models/run_manifest_models.dart';
import '../repositories/github_repository.dart';
import '../repositories/reddit_repository.dart';
import '../repositories/run_manifest_repository.dart';
import '../repositories/stackoverflow_repository.dart';
import '../repositories/trend_repository.dart';
import '../services/data_service.dart';

final dataServiceProvider = Provider<DataService>((ref) {
  return const DataService();
});

final runManifestRepositoryProvider = Provider<RunManifestRepository>((ref) {
  return RunManifestRepository(ref.watch(dataServiceProvider));
});

final trendRepositoryProvider = Provider<TrendRepository>((ref) {
  return TrendRepository(ref.watch(dataServiceProvider));
});

final githubRepositoryProvider = Provider<GithubRepository>((ref) {
  return GithubRepository(ref.watch(dataServiceProvider));
});

final stackoverflowRepositoryProvider = Provider<StackOverflowRepository>((
  ref,
) {
  return StackOverflowRepository(ref.watch(dataServiceProvider));
});

final redditRepositoryProvider = Provider<RedditRepository>((ref) {
  return RedditRepository(ref.watch(dataServiceProvider));
});

final runManifestProvider = FutureProvider<DataLoadState<RunManifestPublic>>((
  ref,
) async {
  return ref.watch(runManifestRepositoryProvider).loadRunManifest();
});

final historyIndexProvider = FutureProvider<DataLoadState<HistoryIndexModel>>((
  ref,
) async {
  return ref.watch(runManifestRepositoryProvider).loadHistoryIndex();
});

final trendTemporalProvider =
    FutureProvider<DataLoadState<TrendTemporalViewData>>((ref) async {
      return ref.watch(trendRepositoryProvider).loadTrendTemporalView();
    });

final githubDashboardProvider =
    FutureProvider<DataLoadState<GithubDashboardData>>((ref) async {
      return ref.watch(githubRepositoryProvider).loadDashboardData();
    });

final stackoverflowDashboardProvider =
    FutureProvider<DataLoadState<StackOverflowDashboardData>>((ref) async {
      return ref.watch(stackoverflowRepositoryProvider).loadDashboardData();
    });

final redditDashboardProvider =
    FutureProvider<DataLoadState<RedditDashboardData>>((ref) async {
      return ref.watch(redditRepositoryProvider).loadDashboardData();
    });

final frontendHealthProvider =
    Provider<AsyncValue<DataLoadState<FrontendHealthData>>>((ref) {
      final manifestAsync = ref.watch(runManifestProvider);

      return manifestAsync.whenData((manifestState) {
        final manifest = manifestState.data;
        if (manifestState.isError || manifest == null) {
          return DataLoadState.degraded(
            const FrontendHealthData(
              status: 'unknown',
              message: 'metadata unavailable',
              degradedMode: true,
              availableSourcesCount: 0,
            ),
            message: manifestState.message ?? 'metadata unavailable',
          );
        }

        return DataLoadState.data(
          FrontendHealthData(
            status: manifest.qualityGateStatus,
            message: manifest.notes ?? 'metadata available',
            degradedMode: manifest.degradedMode,
            availableSourcesCount: manifest.availableSources.length,
          ),
        );
      });
    });
