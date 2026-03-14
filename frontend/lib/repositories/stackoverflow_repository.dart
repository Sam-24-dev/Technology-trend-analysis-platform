import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/stackoverflow_models.dart';
import '../services/data_service.dart';

class StackOverflowRepository {
  final DataService dataService;

  const StackOverflowRepository(this.dataService);

  List<VolumenPreguntasModel> _withComputedShare(
    List<VolumenPreguntasModel> items,
  ) {
    final int totalQuestions = items.fold<int>(
      0,
      (int total, VolumenPreguntasModel item) => total + item.preguntas,
    );
    if (totalQuestions <= 0) {
      return items;
    }
    return items
        .map(
          (VolumenPreguntasModel item) => VolumenPreguntasModel(
            lenguaje: item.lenguaje,
            preguntas: item.preguntas,
            preguntasPrev: item.preguntasPrev,
            deltaPreguntas: item.deltaPreguntas,
            growthPct: item.growthPct,
            trendDirection: item.trendDirection,
            sharePct: (item.preguntas / totalQuestions) * 100,
          ),
        )
        .toList();
  }

  Future<DataLoadState<StackOverflowDashboardData>> loadDashboardData() async {
    final errors = <String>[];
    List<VolumenPreguntasModel> volumen = [];
    List<TasaAceptacionModel> aceptacion = [];
    List<TendenciaMensualModel> tendencias = [];
    StackOverflowVolumeHistoryModel? volumenHistory;
    StackOverflowAcceptanceHistoryModel? aceptacionHistory;
    StackOverflowTrendsHistoryModel? tendenciasHistory;

    try {
      final payload = await dataService.loadStackOverflowVolumeHistoryPublic();
      volumenHistory = StackOverflowVolumeHistoryModel.fromMap(payload);
      if (volumenHistory.latestItems.isNotEmpty) {
        volumen = List<VolumenPreguntasModel>.from(volumenHistory.latestItems)
          ..sort((a, b) => b.preguntas.compareTo(a.preguntas));
      }
    } catch (_) {}

    if (volumen.isEmpty) {
      try {
        final rows = await dataService.loadCsvRows(
          'assets/data/so_volumen_preguntas.csv',
        );
        volumen = rows
            .map((item) => VolumenPreguntasModel.fromMap(item))
            .toList();
        volumen = _withComputedShare(volumen);
        volumen.sort((a, b) => b.preguntas.compareTo(a.preguntas));
      } catch (error) {
        errors.add('so_volumen_preguntas.csv: $error');
      }
    }

    try {
      final payload = await dataService
          .loadStackOverflowAcceptanceHistoryPublic();
      aceptacionHistory = StackOverflowAcceptanceHistoryModel.fromMap(payload);
      if (aceptacionHistory.latestItems.isNotEmpty) {
        aceptacion = List<TasaAceptacionModel>.from(
          aceptacionHistory.latestItems,
        )..sort((a, b) => b.tasaPct.compareTo(a.tasaPct));
      }
    } catch (_) {}

    if (aceptacion.isEmpty) {
      try {
        final rows = await dataService.loadCsvRows(
          'assets/data/so_tasa_aceptacion.csv',
        );
        aceptacion = rows
            .map((item) => TasaAceptacionModel.fromMap(item))
            .toList();
      } catch (error) {
        errors.add('so_tasa_aceptacion.csv: $error');
      }
    }

    try {
      final payload = await dataService.loadStackOverflowTrendsHistoryPublic();
      tendenciasHistory = StackOverflowTrendsHistoryModel.fromMap(payload);
      if (tendenciasHistory.series.isNotEmpty &&
          tendenciasHistory.months.isNotEmpty) {
        tendencias = _legacyTrendRowsFromHistory(tendenciasHistory);
      }
    } catch (_) {}

    if (tendencias.isEmpty) {
      try {
        final rows = await dataService.loadCsvRows(
          'assets/data/so_tendencias_mensuales.csv',
        );
        tendencias = rows
            .map((item) => TendenciaMensualModel.fromMap(item))
            .toList();
      } catch (error) {
        errors.add('so_tendencias_mensuales.csv: $error');
      }
    }

    if (volumen.isEmpty && aceptacion.isEmpty && tendencias.isEmpty) {
      return DataLoadState.error(
        'stackoverflow domain has no available datasets. ${errors.join(" | ")}',
      );
    }

    final payload = StackOverflowDashboardData(
      volumen: volumen,
      aceptacion: aceptacion,
      tendencias: tendencias,
      volumenHistory: volumenHistory,
      aceptacionHistory: aceptacionHistory,
      tendenciasHistory: tendenciasHistory,
    );
    if (errors.isNotEmpty) {
      return DataLoadState.degraded(payload, message: errors.join(' | '));
    }
    return DataLoadState.data(payload);
  }

  List<TendenciaMensualModel> _legacyTrendRowsFromHistory(
    StackOverflowTrendsHistoryModel history,
  ) {
    final StackOverflowTrendSeriesModel? pythonSeries = _findTrendSeries(
      history.series,
      'python',
    );
    final StackOverflowTrendSeriesModel? javascriptSeries = _findTrendSeries(
      history.series,
      'javascript',
    );
    final StackOverflowTrendSeriesModel? typescriptSeries = _findTrendSeries(
      history.series,
      'typescript',
    );

    return List<TendenciaMensualModel>.generate(history.months.length, (
      int index,
    ) {
      return TendenciaMensualModel(
        mes: history.months[index],
        python: _pointAt(pythonSeries, index),
        javascript: _pointAt(javascriptSeries, index),
        typescript: _pointAt(typescriptSeries, index),
      );
    });
  }

  StackOverflowTrendSeriesModel? _findTrendSeries(
    List<StackOverflowTrendSeriesModel> items,
    String tecnologia,
  ) {
    for (final StackOverflowTrendSeriesModel item in items) {
      if (item.tecnologia.toLowerCase() == tecnologia) {
        return item;
      }
    }
    return null;
  }

  int _pointAt(StackOverflowTrendSeriesModel? series, int index) {
    if (series == null || index < 0 || index >= series.points.length) {
      return 0;
    }
    return series.points[index];
  }
}
