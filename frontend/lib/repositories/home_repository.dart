import '../models/data_load_state.dart';
import '../models/home_highlights_models.dart';
import '../services/data_service.dart';

class HomeRepository {
  final DataService dataService;

  const HomeRepository(this.dataService);

  Future<DataLoadState<HomeHighlightsPayloadModel>> loadHomeHighlights() async {
    try {
      final Map<String, dynamic> payload =
          await dataService.loadHomeHighlights();
      final HomeHighlightsPayloadModel data =
          HomeHighlightsPayloadModel.fromMap(payload);
      if (data.highlights.isEmpty) {
        return DataLoadState.error('home_highlights.json has no highlights');
      }
      return DataLoadState.data(data);
    } catch (error) {
      return DataLoadState.error('home_highlights.json: $error');
    }
  }
}
