import '../config/feature_flags.dart';
import '../models/data_load_state.dart';
import '../models/history_index_models.dart';
import '../models/run_manifest_models.dart';
import '../services/data_service.dart';

class RunManifestRepository {
  final DataService dataService;

  const RunManifestRepository(this.dataService);

  Future<DataLoadState<RunManifestPublic>> loadRunManifest() async {
    if (!FeatureFlags.usePublicRunManifest) {
      return DataLoadState.degraded(
        null,
        message: 'metadata disabled by feature flag',
      );
    }

    try {
      final manifest = await dataService.loadPublicRunManifest();
      return DataLoadState.data(manifest);
    } catch (error) {
      return DataLoadState.degraded(
        null,
        message: 'metadata unavailable: $error',
      );
    }
  }

  Future<DataLoadState<HistoryIndexModel>> loadHistoryIndex() async {
    try {
      final historyIndex = await dataService.loadHistoryIndex();
      return DataLoadState.data(historyIndex);
    } catch (error) {
      return DataLoadState.degraded(
        null,
        message: 'history index unavailable: $error',
      );
    }
  }
}
