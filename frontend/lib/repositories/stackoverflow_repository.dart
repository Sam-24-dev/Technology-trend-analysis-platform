import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/stackoverflow_models.dart';
import '../services/data_service.dart';

class StackOverflowRepository {
  final DataService dataService;

  const StackOverflowRepository(this.dataService);

  Future<DataLoadState<StackOverflowDashboardData>> loadDashboardData() async {
    final errors = <String>[];
    List<VolumenPreguntasModel> volumen = [];
    List<TasaAceptacionModel> aceptacion = [];
    List<TendenciaMensualModel> tendencias = [];

    try {
      final rows = await dataService.loadCsvRows(
        'assets/data/so_volumen_preguntas.csv',
      );
      volumen = rows
          .map((item) => VolumenPreguntasModel.fromMap(item))
          .toList();
      volumen.sort((a, b) => b.preguntas.compareTo(a.preguntas));
    } catch (error) {
      errors.add('so_volumen_preguntas.csv: $error');
    }

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

    if (volumen.isEmpty && aceptacion.isEmpty && tendencias.isEmpty) {
      return DataLoadState.error(
        'stackoverflow domain has no available datasets. ${errors.join(" | ")}',
      );
    }

    final payload = StackOverflowDashboardData(
      volumen: volumen,
      aceptacion: aceptacion,
      tendencias: tendencias,
    );
    if (errors.isNotEmpty) {
      return DataLoadState.degraded(payload, message: errors.join(' | '));
    }
    return DataLoadState.data(payload);
  }
}
