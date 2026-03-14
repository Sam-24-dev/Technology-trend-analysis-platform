import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/technology_profile_models.dart';

void main() {
  test('TechnologyProfilesPayload parses profiles and insights', () {
    final payload = TechnologyProfilesPayload.fromMap({
      'dataset': 'technology_profiles',
      'generated_at_utc': '2026-03-10T00:00:00Z',
      'source_mode': 'trend_score_history',
      'latest_snapshot_date': '2026-03-10',
      'previous_snapshot_date': '2026-03-09',
      'profile_count': 1,
      'profiles': [
        {
          'slug': 'python',
          'display_name': 'Python',
          'trend_score_actual': 80.0,
          'trend_score_prev': 78.0,
          'delta_score': 2.0,
          'ranking_actual': 1,
          'ranking_prev': 2,
          'delta_ranking': 1,
          'sources_present': ['github', 'stackoverflow'],
          'github_summary': {
            'source': 'github',
            'display_name': 'GitHub',
            'available': true,
            'score_actual': 60.0,
            'score_prev': 58.0,
            'delta_score': 2.0,
          },
          'stackoverflow_summary': {
            'source': 'stackoverflow',
            'display_name': 'StackOverflow',
            'available': true,
            'score_actual': 20.0,
            'score_prev': 20.0,
            'delta_score': 0.0,
          },
          'reddit_summary': {
            'source': 'reddit',
            'display_name': 'Reddit',
            'available': false,
            'score_actual': 0.0,
            'score_prev': 0.0,
            'delta_score': 0.0,
          },
          'source_history': [
            {
              'date': '2026-03-09',
              'trend_score': 78.0,
              'github_score': 58.0,
              'so_score': 20.0,
              'reddit_score': 0.0,
              'ranking': 2,
              'fuentes': 2,
              'available_source_codes': ['GH', 'SO'],
            },
          ],
          'summary_insights': {
            'dominant_source': {
              'source': 'github',
              'display_name': 'GitHub',
              'score': 60.0,
              'label': 'GitHub aporta la mayor parte del score actual.',
            },
            'coverage': {
              'source_count': 2,
              'sources_present': ['github', 'stackoverflow'],
              'label': 'Señal combinada en GitHub y StackOverflow.',
            },
            'momentum': {
              'ranking_actual': 1,
              'ranking_prev': 2,
              'delta_ranking': 1,
              'score_actual': 80.0,
              'score_prev': 78.0,
              'label': 'Python sube 1 posición frente a la corrida previa.',
            },
          },
        },
      ],
    });

    expect(payload.profileCount, 1);
    expect(payload.profiles, hasLength(1));
    final profile = payload.profiles.first;
    expect(profile.slug, 'python');
    expect(profile.githubSummary.available, true);
    expect(profile.sourceHistory, hasLength(1));
    expect(profile.summaryInsights.coverage.sourceCount, 2);
  });
}
