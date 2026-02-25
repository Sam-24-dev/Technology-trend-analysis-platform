import 'github_models.dart';
import 'reddit_models.dart';
import 'stackoverflow_models.dart';
import 'trend_history_models.dart';

class GithubDashboardData {
  final List<LenguajeModel> lenguajes;
  final List<FrameworkCommitModel> frameworks;
  final List<CorrelacionModel> correlacion;

  const GithubDashboardData({
    required this.lenguajes,
    required this.frameworks,
    required this.correlacion,
  });
}

class StackOverflowDashboardData {
  final List<VolumenPreguntasModel> volumen;
  final List<TasaAceptacionModel> aceptacion;
  final List<TendenciaMensualModel> tendencias;

  const StackOverflowDashboardData({
    required this.volumen,
    required this.aceptacion,
    required this.tendencias,
  });
}

class RedditDashboardData {
  final List<SentimientoModel> sentimiento;
  final List<TemasEmergentesModel> temas;
  final List<InterseccionModel> interseccion;

  const RedditDashboardData({
    required this.sentimiento,
    required this.temas,
    required this.interseccion,
  });
}

class TrendTemporalViewData {
  final String source;
  final int snapshotCount;
  final List<TrendTopEntry> items;

  const TrendTemporalViewData({
    required this.source,
    required this.snapshotCount,
    required this.items,
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
