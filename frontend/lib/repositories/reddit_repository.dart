import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/reddit_models.dart';
import '../services/data_service.dart';

class RedditRepository {
  final DataService dataService;

  const RedditRepository(this.dataService);

  Future<DataLoadState<RedditDashboardData>> loadDashboardData() async {
    final errors = <String>[];
    List<SentimientoModel> sentimiento = [];
    List<TemasEmergentesModel> temas = [];
    List<InterseccionModel> interseccion = [];

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/reddit_sentimiento_frameworks.csv',
      );
      sentimiento = rows.map((item) => SentimientoModel.fromMap(item)).toList();
    } catch (error) {
      errors.add('reddit_sentimiento_frameworks.csv: $error');
    }

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/reddit_temas_emergentes.csv',
      );
      temas = rows.map((item) => TemasEmergentesModel.fromMap(item)).toList();
    } catch (error) {
      errors.add('reddit_temas_emergentes.csv: $error');
    }

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/interseccion_github_reddit.csv',
      );
      interseccion = rows
          .map((item) => InterseccionModel.fromMap(item))
          .toList();
    } catch (error) {
      errors.add('interseccion_github_reddit.csv: $error');
    }

    if (sentimiento.isEmpty && temas.isEmpty && interseccion.isEmpty) {
      return DataLoadState.error(
        'reddit domain has no available datasets. ${errors.join(" | ")}',
      );
    }

    final payload = RedditDashboardData(
      sentimiento: sentimiento,
      temas: temas,
      interseccion: interseccion,
    );
    if (errors.isNotEmpty) {
      return DataLoadState.degraded(payload, message: errors.join(' | '));
    }
    return DataLoadState.data(payload);
  }
}
