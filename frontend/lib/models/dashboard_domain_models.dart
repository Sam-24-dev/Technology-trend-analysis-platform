import 'github_models.dart';
import 'reddit_models.dart';
import 'stackoverflow_models.dart';
import 'trend_history_models.dart';

class GithubDashboardData {
  final List<LenguajeModel> lenguajes;
  final List<FrameworkCommitModel> frameworks;
  final List<CorrelacionModel> correlacion;
  final GithubLanguagePublicModel? lenguajesPublic;
  final GithubFrameworkHistoryModel? frameworksHistory;
  final GithubCorrelationHistoryModel? correlationHistory;

  const GithubDashboardData({
    required this.lenguajes,
    required this.frameworks,
    required this.correlacion,
    this.lenguajesPublic,
    this.frameworksHistory,
    this.correlationHistory,
  });
}

class StackOverflowDashboardData {
  final List<VolumenPreguntasModel> volumen;
  final List<TasaAceptacionModel> aceptacion;
  final List<TendenciaMensualModel> tendencias;
  final StackOverflowVolumeHistoryModel? volumenHistory;
  final StackOverflowAcceptanceHistoryModel? aceptacionHistory;
  final StackOverflowTrendsHistoryModel? tendenciasHistory;

  const StackOverflowDashboardData({
    required this.volumen,
    required this.aceptacion,
    required this.tendencias,
    this.volumenHistory,
    this.aceptacionHistory,
    this.tendenciasHistory,
  });
}

class RedditDashboardData {
  final List<SentimientoModel> sentimiento;
  final List<TemasEmergentesModel> temas;
  final List<InterseccionModel> interseccion;
  final RedditSentimentSummaryModel? sentimientoSummary;
  final RedditTemasHistoryModel? temasHistory;
  final RedditInterseccionHistoryModel? interseccionHistory;

  const RedditDashboardData({
    required this.sentimiento,
    required this.temas,
    required this.interseccion,
    this.sentimientoSummary,
    this.temasHistory,
    this.interseccionHistory,
  });
}

class TrendTemporalViewData {
  final String source;
  final int snapshotCount;
  final List<TrendTopEntry> items;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;

  const TrendTemporalViewData({
    required this.source,
    required this.snapshotCount,
    required this.items,
    this.latestSnapshotDate,
    this.previousSnapshotDate,
  });
}

class FrontendHealthData {
  final String status;
  final String message;
  final bool degradedMode;
  final int availableSourcesCount;

  const FrontendHealthData({
    required this.status,
    required this.message,
    required this.degradedMode,
    required this.availableSourcesCount,
  });
}
