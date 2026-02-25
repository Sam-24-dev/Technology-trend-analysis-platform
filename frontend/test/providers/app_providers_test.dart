import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/providers/app_providers.dart';
import '../support/fake_data_service.dart';

void main() {
  test('providers resolve dashboard and health states', () async {
    final fakeService = FakeDataService(
      csvByAsset: {
        'assets/data/github_lenguajes.csv': [
          {'lenguaje': 'Python', 'repos_count': 10, 'porcentaje': 10.0},
        ],
        'assets/data/github_commits_frameworks.csv': [
          {
            'framework': 'Angular',
            'repo': 'angular/angular',
            'commits_2025': 1,
            'ranking': 1,
          },
        ],
        'assets/data/github_correlacion.csv': [
          {
            'repo_name': 'repo',
            'stars': 1,
            'contributors': 1,
            'language': 'Python',
          },
        ],
      },
      fakeTrendView: const TrendTemporalViewData(
        source: 'bridge_json',
        snapshotCount: 1,
        items: [],
      ),
    );

    final container = ProviderContainer(
      overrides: [dataServiceProvider.overrideWithValue(fakeService)],
    );
    addTearDown(container.dispose);

    final githubState = await container.read(githubDashboardProvider.future);
    expect(githubState.data, isNotNull);

    final trendState = await container.read(trendTemporalProvider.future);
    expect(trendState.data, isNotNull);

    final healthAsync = container.read(frontendHealthProvider);
    expect(healthAsync.hasValue || healthAsync.isLoading, true);
  });

  test('domain providers expose loading before resolving', () async {
    final fakeService = FakeDataService(
      csvDelay: const Duration(milliseconds: 40),
      trendDelay: const Duration(milliseconds: 40),
      csvByAsset: {
        'assets/data/github_lenguajes.csv': [
          {'lenguaje': 'Python', 'repos_count': 10, 'porcentaje': 10.0},
        ],
        'assets/data/github_commits_frameworks.csv': [
          {
            'framework': 'Angular',
            'repo': 'angular/angular',
            'commits_2025': 1,
            'ranking': 1,
          },
        ],
        'assets/data/github_correlacion.csv': [
          {
            'repo_name': 'repo',
            'stars': 1,
            'contributors': 1,
            'language': 'Python',
          },
        ],
        'assets/data/so_volumen_preguntas.csv': [
          {'lenguaje': 'python', 'preguntas_nuevas_2025': 100},
        ],
        'assets/data/so_tasa_aceptacion.csv': [
          {'tecnologia': 'reactjs', 'tasa_aceptacion_pct': 30},
        ],
        'assets/data/so_tendencias_mensuales.csv': [
          {'mes': '2025-02', 'python': 10, 'javascript': 8, 'typescript': 5},
        ],
        'assets/data/reddit_sentimiento_frameworks.csv': [
          {'framework': 'django', '% positivo': 50, '% negativo': 50},
        ],
        'assets/data/reddit_temas_emergentes.csv': [
          {'tema': 'AI/ML', 'menciones': 20},
        ],
        'assets/data/interseccion_github_reddit.csv': [
          {'tecnologia': 'Python', 'ranking_github': 1, 'ranking_reddit': 1},
        ],
      },
      fakeTrendView: const TrendTemporalViewData(
        source: 'bridge_json',
        snapshotCount: 1,
        items: [],
      ),
    );

    final container = ProviderContainer(
      overrides: [dataServiceProvider.overrideWithValue(fakeService)],
    );
    addTearDown(container.dispose);

    expect(container.read(githubDashboardProvider).isLoading, true);
    expect(container.read(stackoverflowDashboardProvider).isLoading, true);
    expect(container.read(redditDashboardProvider).isLoading, true);
    expect(container.read(trendTemporalProvider).isLoading, true);

    final githubState = await container.read(githubDashboardProvider.future);
    final stackoverflowState = await container.read(
      stackoverflowDashboardProvider.future,
    );
    final redditState = await container.read(redditDashboardProvider.future);
    final trendState = await container.read(trendTemporalProvider.future);

    expect(githubState.status, DataStatus.data);
    expect(stackoverflowState.status, DataStatus.data);
    expect(redditState.status, DataStatus.data);
    expect(trendState.status, DataStatus.data);
  });
}
