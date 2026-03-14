import '../models/data_load_state.dart';
import '../models/technology_profile_models.dart';
import '../services/data_service.dart';

class TechnologyProfilesRepository {
  final DataService dataService;

  const TechnologyProfilesRepository(this.dataService);

  Future<DataLoadState<TechnologyProfilesPayload>> loadTechnologyProfiles() async {
    try {
      final Map<String, dynamic> payload =
          await dataService.loadTechnologyProfiles();
      final TechnologyProfilesPayload data =
          TechnologyProfilesPayload.fromMap(payload);
      if (data.profiles.isEmpty) {
        return DataLoadState.error(
          'technology_profiles.json has no profiles',
        );
      }
      return DataLoadState.data(data);
    } catch (error) {
      return DataLoadState.error('technology profiles load failed: $error');
    }
  }
}
