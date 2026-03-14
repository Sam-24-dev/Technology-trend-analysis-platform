import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../services/data_service.dart';

class TrendRepository {
  final DataService dataService;

  const TrendRepository(this.dataService);

  Future<DataLoadState<TrendTemporalViewData>> loadTrendTemporalView() async {
    try {
      final trendData = await dataService.loadTrendTemporalView(topN: 15);

      if (trendData.source == 'bridge_json' || trendData.source == 'csv') {
        return DataLoadState.data(trendData);
      }
      if (trendData.source == 'csv_fallback') {
        final bridgeData = await _tryLoadBridgeTrendView(topN: 15);
        if (bridgeData != null) {
          return DataLoadState.data(bridgeData);
        }
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

  Future<TrendTemporalViewData?> _tryLoadBridgeTrendView({
    required int topN,
  }) async {
    try {
      final trendHistory = await dataService.loadTrendScoreHistory();
      if (trendHistory.snapshots.isEmpty) {
        return null;
      }
      final latestSnapshot = trendHistory.snapshots.last;
      final previousSnapshot = trendHistory.snapshots.length >= 2
          ? trendHistory.snapshots[trendHistory.snapshots.length - 2]
          : null;
      final items = latestSnapshot.top10;
      final resolvedTopN = topN < items.length ? topN : items.length;
      return TrendTemporalViewData(
        source: 'bridge_json',
        snapshotCount: trendHistory.snapshotCount,
        items: items.take(resolvedTopN).toList(),
        latestSnapshotDate: latestSnapshot.date,
        previousSnapshotDate: previousSnapshot?.date,
      );
    } catch (_) {
      return null;
    }
  }
}
