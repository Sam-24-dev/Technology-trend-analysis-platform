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
    List<FrameworkCommitModel> frameworks = [];
    List<CorrelacionModel> correlacion = [];

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/github_lenguajes.csv',
      );
      lenguajes = rows
          .map((item) => LenguajeModel.fromMap(item))
          .take(5)
          .toList();
    } catch (error) {
      errors.add('github_lenguajes.csv: $error');
    }

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/github_commits_frameworks.csv',
      );
      frameworks = rows
          .map((item) => FrameworkCommitModel.fromMap(item))
          .toList();
    } catch (error) {
      errors.add('github_commits_frameworks.csv: $error');
    }

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/github_correlacion.csv',
      );
      correlacion = rows.map((item) => CorrelacionModel.fromMap(item)).toList();
    } catch (error) {
      errors.add('github_correlacion.csv: $error');
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
    );

    if (errors.isNotEmpty) {
      return DataLoadState.degraded(payload, message: errors.join(' | '));
    }
    return DataLoadState.data(payload);
  }
}
