import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/repositories/github_repository.dart';
import 'package:frontend/repositories/reddit_repository.dart';
import 'package:frontend/repositories/run_manifest_repository.dart';
import 'package:frontend/repositories/stackoverflow_repository.dart';
import 'package:frontend/repositories/trend_repository.dart';
import 'package:frontend/models/trend_history_models.dart';
import '../support/fake_data_service.dart';

void main() {
  test('GithubRepository returns data when all csv are available', () async {
    final service = FakeDataService(
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
    );
    final repo = GithubRepository(service);

    final state = await repo.loadDashboardData();
    expect(state.isData, true);
    expect(state.data!.lenguajes, isNotEmpty);
  });

  test('GithubRepository returns degraded when one dataset fails', () async {
    final service = FakeDataService(
      csvByAsset: {
        'assets/data/github_lenguajes.csv': [
          {'lenguaje': 'Python', 'repos_count': 10, 'porcentaje': 10.0},
        ],
      },
      throwAssets: const {'assets/data/github_commits_frameworks.csv'},
    );
    final repo = GithubRepository(service);

    final state = await repo.loadDashboardData();
    expect(state.isDegraded, true);
    expect(state.data, isNotNull);
  });

  test('GithubRepository returns error when all datasets fail', () async {
    final service = FakeDataService(
      throwAssets: const {
        'assets/data/github_lenguajes.csv',
        'assets/data/github_commits_frameworks.csv',
        'assets/data/github_correlacion.csv',
      },
    );
    final repo = GithubRepository(service);

    final state = await repo.loadDashboardData();
    expect(state.isError, true);
    expect(state.data, isNull);
  });

  test(
    'StackOverflowRepository returns error when all datasets fail',
    () async {
      final service = FakeDataService(
        throwAssets: const {
          'assets/data/so_volumen_preguntas.csv',
          'assets/data/so_tasa_aceptacion.csv',
          'assets/data/so_tendencias_mensuales.csv',
        },
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isError, true);
    },
  );

  test(
    'StackOverflowRepository returns degraded when one dataset fails',
    () async {
      final service = FakeDataService(
        csvByAsset: {
          'assets/data/so_volumen_preguntas.csv': [
            {'lenguaje': 'python', 'preguntas_nuevas_2025': 100},
          ],
          'assets/data/so_tasa_aceptacion.csv': [
            {'tecnologia': 'reactjs', 'tasa_aceptacion_pct': 30},
          ],
        },
        throwAssets: const {'assets/data/so_tendencias_mensuales.csv'},
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isDegraded, true);
      expect(state.data, isNotNull);
    },
  );

  test('RedditRepository returns data when csv files are available', () async {
    final service = FakeDataService(
      csvByAsset: {
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
    );
    final repo = RedditRepository(service);

    final state = await repo.loadDashboardData();
    expect(state.isData, true);
    expect(state.data!.temas.first.tema, 'AI/ML');
  });

  test('RedditRepository returns degraded when one dataset fails', () async {
    final service = FakeDataService(
      csvByAsset: {
        'assets/data/reddit_sentimiento_frameworks.csv': [
          {'framework': 'django', '% positivo': 50, '% negativo': 50},
        ],
        'assets/data/reddit_temas_emergentes.csv': [
          {'tema': 'AI/ML', 'menciones': 20},
        ],
      },
      throwAssets: const {'assets/data/interseccion_github_reddit.csv'},
    );
    final repo = RedditRepository(service);

    final state = await repo.loadDashboardData();
    expect(state.isDegraded, true);
    expect(state.data, isNotNull);
  });

  test('RedditRepository returns error when all datasets fail', () async {
    final service = FakeDataService(
      throwAssets: const {
        'assets/data/reddit_sentimiento_frameworks.csv',
        'assets/data/reddit_temas_emergentes.csv',
        'assets/data/interseccion_github_reddit.csv',
      },
    );
    final repo = RedditRepository(service);

    final state = await repo.loadDashboardData();
    expect(state.isError, true);
    expect(state.data, isNull);
  });

  test('RunManifestRepository loads manifest in data state', () async {
    final repo = RunManifestRepository(const FakeDataService());
    final state = await repo.loadRunManifest();
    expect(state.isData, true);
    expect(state.data, isNotNull);
  });

  test('RunManifestRepository returns degraded when manifest fails', () async {
    final repo = RunManifestRepository(
      const FakeDataService(throwAssets: {'assets/data/run_manifest.json'}),
    );
    final state = await repo.loadRunManifest();
    expect(state.isDegraded, true);
    expect(state.data, isNull);
  });

  test('TrendRepository maps csv_fallback source to degraded state', () async {
    final repo = TrendRepository(
      const FakeDataService(
        fakeTrendView: TrendTemporalViewData(
          source: 'csv_fallback',
          snapshotCount: 1,
          items: [],
        ),
      ),
    );
    final state = await repo.loadTrendTemporalView();
    expect(state.isDegraded, true);
  });

  test(
    'TrendRepository keeps CSV snapshot data when bridge is unavailable',
    () async {
      final repo = TrendRepository(
        const FakeDataService(
          fakeTrendView: TrendTemporalViewData(
            source: 'csv_fallback',
            snapshotCount: 1,
            items: <TrendTopEntry>[
              TrendTopEntry(
                ranking: 1,
                tecnologia: 'Python',
                trendScore: 76.45,
                fuentes: 3,
              ),
            ],
          ),
        ),
      );

      final state = await repo.loadTrendTemporalView();
      expect(state.isDegraded, true);
      expect(state.data, isNotNull);
      expect(state.data!.source, 'csv_fallback');
      expect(state.data!.snapshotCount, 1);
      expect(state.data!.items, isNotEmpty);
      expect(state.data!.items.first.tecnologia, 'Python');
    },
  );
}
