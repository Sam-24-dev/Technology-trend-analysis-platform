import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/github_models.dart';
import '../services/data_service.dart';

class GithubRepository {
  final DataService dataService;

  const GithubRepository(this.dataService);

  Future<DataLoadState<GithubDashboardData>> loadDashboardData() async {
    final errors = <String>[];
    List<LenguajeModel> lenguajes = [];
    GithubLanguagePublicModel? lenguajesPublic;
    List<FrameworkCommitModel> frameworks = [];
    final Map<String, FrameworkCommitModel> csvFrameworkByName =
        <String, FrameworkCommitModel>{};
    List<CorrelacionModel> correlacion = [];
    GithubFrameworkHistoryModel? frameworksHistory;
    GithubCorrelationHistoryModel? correlationHistory;

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/github_lenguajes.csv',
      );
      final parsed = rows.map((item) => LenguajeModel.fromMap(item)).toList()
        ..sort((a, b) => b.reposCount.compareTo(a.reposCount));
      lenguajes = parsed.take(10).toList();
    } catch (error) {
      errors.add('github_lenguajes.csv: $error');
    }

    try {
      final payload = await dataService.loadGithubLanguagePublic();
      lenguajesPublic = GithubLanguagePublicModel.fromMap(payload);
    } catch (error) {
      if (lenguajes.isEmpty) {
        errors.add('github_lenguajes_public.json: $error');
      }
    }

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/github_commits_frameworks.csv',
      );
      frameworks = rows
          .map((item) => FrameworkCommitModel.fromMap(item))
          .toList();
      for (final FrameworkCommitModel item in frameworks) {
        csvFrameworkByName[item.framework.trim().toLowerCase()] = item;
      }
    } catch (error) {
      errors.add('github_commits_frameworks.csv: $error');
    }

    try {
      final payload = await dataService.loadGithubFrameworksHistoryPublic();
      frameworksHistory = GithubFrameworkHistoryModel.fromMap(payload);
      if (frameworksHistory.latestFrameworks.isNotEmpty) {
        final Set<String> historyKeys = <String>{};
        final List<FrameworkCommitModel> mergedFromHistory = frameworksHistory
            .latestFrameworks
            .map((item) {
              final String key = item.framework.trim().toLowerCase();
              historyKeys.add(key);
              final FrameworkCommitModel? csvItem = csvFrameworkByName[key];
              return FrameworkCommitModel(
                framework: item.framework,
                repo: item.repo.isNotEmpty ? item.repo : (csvItem?.repo ?? ''),
                commits2025: item.commits2025,
                ranking: item.ranking,
                activeContributors:
                    item.activeContributors ?? csvItem?.activeContributors,
                mergedPrs: item.mergedPrs ?? csvItem?.mergedPrs,
                closedIssues: item.closedIssues ?? csvItem?.closedIssues,
                releasesCount: item.releasesCount ?? csvItem?.releasesCount,
                commitsPrev: item.commitsPrev ?? csvItem?.commitsPrev,
                deltaCommits: item.deltaCommits ?? csvItem?.deltaCommits,
                growthPct: item.growthPct ?? csvItem?.growthPct,
                trendDirection: item.trendDirection ?? csvItem?.trendDirection,
              );
            })
            .toList();

        final List<FrameworkCommitModel> csvOnly = frameworks
            .where(
              (FrameworkCommitModel item) =>
                  !historyKeys.contains(item.framework.trim().toLowerCase()),
            )
            .toList();
        frameworks = <FrameworkCommitModel>[...mergedFromHistory, ...csvOnly];
      }
    } catch (error) {
      if (frameworks.isEmpty) {
        errors.add('github_frameworks_history.json: $error');
      }
    }

    try {
      final payload = await dataService.loadGithubCorrelationHistoryPublic();
      correlationHistory = GithubCorrelationHistoryModel.fromMap(payload);
      if (correlationHistory.latestItems.isNotEmpty) {
        correlacion = correlationHistory.latestItems;
      }
    } catch (_) {}

    if (correlacion.isEmpty) {
      try {
        final rows = await dataService.loadCsvRows(
          'assets/data/github_correlacion.csv',
        );
        correlacion = rows
            .map((item) => CorrelacionModel.fromMap(item))
            .toList();
      } catch (error) {
        errors.add('github_correlacion.csv: $error');
      }
    }

    if (lenguajes.isEmpty && frameworks.isEmpty && correlacion.isEmpty) {
      return DataLoadState.error(
        'github domain has no available datasets. ${errors.join(" | ")}',
      );
    }

    final payload = GithubDashboardData(
      lenguajes: lenguajes,
      frameworks: frameworks,
      correlacion: correlacion,
      lenguajesPublic: lenguajesPublic,
      frameworksHistory: frameworksHistory,
      correlationHistory: correlationHistory,
    );

    if (errors.isNotEmpty) {
      return DataLoadState.degraded(payload, message: errors.join(' | '));
    }
    return DataLoadState.data(payload);
  }
}
