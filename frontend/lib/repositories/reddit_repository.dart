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
    RedditSentimentSummaryModel? sentimientoSummary;
    RedditTemasHistoryModel? temasHistory;
    RedditInterseccionHistoryModel? interseccionHistory;

    bool loadedSentimentFromPublicBridge = false;
    try {
      final Map<String, dynamic> payload = await dataService
          .loadRedditSentimentPublic();
      final List<dynamic> rawFrameworks =
          (payload['frameworks'] as List?) ?? const <dynamic>[];
      sentimiento = rawFrameworks
          .whereType<Map>()
          .map((item) => SentimientoModel.fromMap(item.cast<String, dynamic>()))
          .toList();
      final Map<String, dynamic> rawSummary =
          (payload['summary'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{};
      if (rawSummary.isNotEmpty) {
        sentimientoSummary = RedditSentimentSummaryModel.fromMap(rawSummary);
      }
      if (sentimiento.isNotEmpty) {
        loadedSentimentFromPublicBridge = true;
      }
    } catch (_) {
      loadedSentimentFromPublicBridge = false;
    }

    if (!loadedSentimentFromPublicBridge) {
      try {
        final rows = await dataService.loadCsvRows(
          'assets/data/reddit_sentimiento_frameworks.csv',
        );
        sentimiento = rows
            .map((item) => SentimientoModel.fromMap(item))
            .toList();
      } catch (error) {
        errors.add('reddit_sentimiento_frameworks.csv: $error');
      }
    }

    bool loadedTopicsFromPublicBridge = false;
    try {
      final Map<String, dynamic> payload = await dataService
          .loadRedditTopicsHistoryPublic();
      temasHistory = RedditTemasHistoryModel.fromMap(payload);
      final List<dynamic> rawTopics =
          (payload['latest_topics'] as List?) ?? const <dynamic>[];
      temas = rawTopics
          .whereType<Map>()
          .map(
            (item) =>
                TemasEmergentesModel.fromMap(item.cast<String, dynamic>()),
          )
          .toList();
      if (temas.isNotEmpty) {
        loadedTopicsFromPublicBridge = true;
      }
    } catch (_) {
      loadedTopicsFromPublicBridge = false;
    }

    if (!loadedTopicsFromPublicBridge) {
      try {
        final rows = await dataService.loadCsvRows(
          'assets/data/reddit_temas_emergentes.csv',
        );
        temas = rows.map((item) => TemasEmergentesModel.fromMap(item)).toList();
      } catch (error) {
        errors.add('reddit_temas_emergentes.csv: $error');
      }
    }

    try {
      final Map<String, dynamic> payload = await dataService
          .loadRedditIntersectionHistoryPublic();
      interseccionHistory = RedditInterseccionHistoryModel.fromMap(payload);
    } catch (_) {}

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
      sentimientoSummary: sentimientoSummary,
      temasHistory: temasHistory,
      interseccionHistory: interseccionHistory,
    );
    if (errors.isNotEmpty) {
      return DataLoadState.degraded(payload, message: errors.join(' | '));
    }
    return DataLoadState.data(payload);
  }
}
