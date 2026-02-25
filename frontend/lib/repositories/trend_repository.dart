import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../services/data_service.dart';

class TrendRepository {
  final DataService dataService;

  const TrendRepository(this.dataService);

  Future<DataLoadState<TrendTemporalViewData>> loadTrendTemporalView() async {
    try {
      final trendData = await dataService.loadTrendTemporalView(topN: 5);

      if (trendData.source == 'bridge_json' || trendData.source == 'csv') {
        return DataLoadState.data(trendData);
      }
      if (trendData.source == 'csv_fallback') {
        return DataLoadState.degraded(
          trendData,
          message: 'bridge unavailable, using CSV fallback',
        );
      }
      return DataLoadState.data(trendData);
    } catch (error) {
      return DataLoadState.error('trend temporal load failed: $error');
    }
  }
}
