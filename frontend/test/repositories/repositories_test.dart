import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/repositories/home_repository.dart';
import 'package:frontend/repositories/github_repository.dart';
import 'package:frontend/repositories/reddit_repository.dart';
import 'package:frontend/repositories/run_manifest_repository.dart';
import 'package:frontend/repositories/stackoverflow_repository.dart';
import 'package:frontend/repositories/technology_profiles_repository.dart';
import 'package:frontend/repositories/trend_repository.dart';
import 'package:frontend/models/trend_history_models.dart';
import '../support/fake_data_service.dart';

void main() {
  test('HomeRepository loads canonical home highlights bridge', () async {
    final service = FakeDataService(
      jsonByAsset: {
        'assets/data/home_highlights.json': {
          'generated_at_utc': '2026-03-09T05:56:39Z',
          'dataset': 'home_highlights',
          'source_mode': 'bridges',
          'candidate_count': 3,
          'highlights': [
            {
              'dashboard': 'github',
              'graph': 2,
              'signal': 'leader',
              'source': 'github_frameworks_history.summary.leader',
              'entity': 'Next.js',
              'entity_key': 'nextjs',
              'score': 251.61,
              'payload': {'framework': 'Next.js', 'commits_2025': 5000},
            },
          ],
        },
      },
    );

    final repo = HomeRepository(service);
    final state = await repo.loadHomeHighlights();

    expect(state.isData, true);
    expect(state.data, isNotNull);
    expect(state.data!.highlights.single.entity, 'Next.js');
  });

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

  test('GithubRepository uses public language bridge when available', () async {
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
      fakeGithubLanguagePublic: {
        'generated_at_utc': '2026-03-09T05:56:37Z',
        'dataset': 'github_lenguajes',
        'source_mode': 'latest',
        'source_path': 'datos/latest/github_lenguajes.csv',
        'source_updated_at_utc': '2026-03-09T05:16:58Z',
        'language_count': 2,
        'languages': [
          {'lenguaje': 'Python', 'repos_count': 321, 'share_pct': 34.55},
          {'lenguaje': 'TypeScript', 'repos_count': 245, 'share_pct': 26.37},
        ],
        'summary': {
          'leader': {
            'lenguaje': 'Python',
            'repos_count': 321,
            'share_pct': 34.55,
          },
          'runner_up': {
            'lenguaje': 'TypeScript',
            'repos_count': 245,
            'share_pct': 26.37,
          },
          'language_count': 2,
          'total_classifiable_repos': 835,
          'leader_gap_repos': 76,
          'leader_gap_share_pct': 8.18,
        },
      },
    );
    final repo = GithubRepository(service);

    final state = await repo.loadDashboardData();
    expect(state.isData, true);
    expect(state.data!.lenguajesPublic, isNotNull);
    expect(state.data!.lenguajesPublic!.summary.leader?.lenguaje, 'Python');
    expect(state.data!.lenguajesPublic!.summary.leaderGapRepos, 76);
  });

  test(
    'GithubRepository uses public frameworks history bridge when available',
    () async {
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
        fakeGithubFrameworksHistoryPublic: {
          'dataset': 'github_commits_frameworks',
          'snapshot_count': 2,
          'snapshot_date': '2026-03-04',
          'latest_snapshot_date': '2026-03-04',
          'previous_snapshot_date': '2026-03-03',
          'item_count': 1,
          'has_historical_comparison': true,
          'latest_frameworks': [
            {
              'framework': 'Angular',
              'repo': 'angular/angular',
              'ranking': 1,
              'commits_2025': 150,
              'active_contributors': 42,
              'merged_prs': 28,
              'closed_issues': 31,
              'releases_count': 2,
              'commits_prev': 120,
              'delta_commits': 30,
              'growth_pct': 25.0,
              'trend_direction': 'creciendo',
            },
          ],
          'summary': {
            'leader_framework': 'Angular',
            'leader_commits': 150,
            'max_growth_framework': 'Angular',
            'max_growth_delta': 30,
            'max_drop_framework': null,
            'max_drop_delta': null,
            'missing_metrics_frameworks': 0,
          },
          'series': [],
        },
      );
      final repo = GithubRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.frameworksHistory, isNotNull);
      expect(state.data!.frameworks.first.commits2025, 150);
      expect(state.data!.frameworks.first.deltaCommits, 30);
    },
  );

  test(
    'GithubRepository uses correlation history bridge before CSV fallback',
    () async {
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
              'repo_name': 'csv-repo',
              'stars': 1,
              'contributors': 1,
              'language': 'Python',
            },
          ],
        },
        fakeGithubCorrelationHistoryPublic: {
          'dataset': 'github_correlacion',
          'source_mode': 'history',
          'snapshot_count': 2,
          'latest_snapshot_date': '2026-03-06',
          'previous_snapshot_date': '2026-03-05',
          'item_count': 1,
          'has_historical_comparison': true,
          'summary': {
            'correlation_value': 0.61,
            'top_stars_repo': {
              'repo_name': 'vercel/next.js',
              'stars': 100,
              'contributors': 10,
              'language': 'TypeScript',
            },
          },
          'latest_items': [
            {
              'repo_name': 'vercel/next.js',
              'stars': 100,
              'contributors': 10,
              'language': 'TypeScript',
              'engagement_ratio': 0.1,
              'contributors_per_1k_stars': 100.0,
              'expected_contributors': 8.5,
              'contributors_delta_vs_trend': 1.5,
              'outlier_score': 0.42,
              'trend_bucket': 'above_trend',
              'snapshot_date_utc': '2026-03-06',
            },
          ],
          'snapshots': [],
        },
      );
      final repo = GithubRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.correlationHistory, isNotNull);
      expect(state.data!.correlacion.single.repoName, 'vercel/next.js');
      expect(state.data!.correlacion.single.outlierScore, 0.42);
    },
  );

  test(
    'GithubRepository falls back to correlation CSV when bridge fails',
    () async {
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
              'repo_name': 'csv-repo',
              'stars': 12,
              'contributors': 4,
              'language': 'TypeScript',
            },
          ],
        },
        throwAssets: const {'assets/data/github_correlacion_history.json'},
      );
      final repo = GithubRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.correlationHistory, isNull);
      expect(state.data!.correlacion.single.repoName, 'csv-repo');
    },
  );

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
    'StackOverflowRepository uses volume history bridge before CSV fallback',
    () async {
      final service = FakeDataService(
        csvByAsset: {
          'assets/data/so_tasa_aceptacion.csv': [
            {
              'tecnologia': 'reactjs',
              'tasa_aceptacion_pct': 30,
              'total_preguntas': 150,
            },
          ],
          'assets/data/so_tendencias_mensuales.csv': [
            {'mes': '2026-03', 'python': 10, 'javascript': 9, 'typescript': 8},
          ],
        },
        fakeStackOverflowVolumeHistoryPublic: {
          'source_mode': 'history',
          'snapshot_count': 2,
          'latest_snapshot_date': '2026-03-07',
          'previous_snapshot_date': '2026-03-06',
          'has_historical_comparison': true,
          'item_count': 2,
          'summary': {
            'leader': {
              'lenguaje': 'javascript',
              'preguntas': 120,
              'preguntas_prev': 110,
              'delta_preguntas': 10,
              'growth_pct': 9.1,
              'trend_direction': 'creciendo',
              'share_pct': 57.1,
            },
            'highest_growth': {
              'lenguaje': 'javascript',
              'preguntas': 120,
              'preguntas_prev': 110,
              'delta_preguntas': 10,
              'growth_pct': 9.1,
              'trend_direction': 'creciendo',
              'share_pct': 57.1,
            },
            'largest_drop': {
              'lenguaje': 'java',
              'preguntas': 90,
              'preguntas_prev': 95,
              'delta_preguntas': -5,
              'growth_pct': -5.3,
              'trend_direction': 'cayendo',
              'share_pct': 42.9,
            },
            'total_questions': 210,
          },
          'latest_items': [
            {
              'lenguaje': 'javascript',
              'preguntas': 120,
              'preguntas_prev': 110,
              'delta_preguntas': 10,
              'growth_pct': 9.1,
              'trend_direction': 'creciendo',
              'share_pct': 57.1,
            },
            {
              'lenguaje': 'java',
              'preguntas': 90,
              'preguntas_prev': 95,
              'delta_preguntas': -5,
              'growth_pct': -5.3,
              'trend_direction': 'cayendo',
              'share_pct': 42.9,
            },
          ],
          'snapshots': [],
        },
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.volumenHistory, isNotNull);
      expect(state.data!.volumen.first.lenguaje, 'javascript');
      expect(state.data!.volumen.first.deltaPreguntas, 10);
      expect(state.data!.volumen.first.sharePct, closeTo(57.1, 0.01));
    },
  );

  test(
    'StackOverflowRepository uses acceptance history bridge before CSV fallback',
    () async {
      final service = FakeDataService(
        csvByAsset: {
          'assets/data/so_volumen_preguntas.csv': [
            {'lenguaje': 'python', 'preguntas_nuevas_2025': 100},
          ],
          'assets/data/so_tendencias_mensuales.csv': [
            {'mes': '2026-03', 'python': 10, 'javascript': 9, 'typescript': 8},
          ],
        },
        fakeStackOverflowAcceptanceHistoryPublic: {
          'source_mode': 'history',
          'snapshot_count': 2,
          'latest_snapshot_date': '2026-03-08',
          'previous_snapshot_date': '2026-03-07',
          'has_historical_comparison': true,
          'item_count': 2,
          'summary': {
            'raw_leader': {
              'tecnologia': 'svelte',
              'total_preguntas': 150,
              'respuestas_aceptadas': 54,
              'tasa_aceptacion_pct': 36.0,
              'total_preguntas_prev': 151,
              'respuestas_aceptadas_prev': 55,
              'tasa_aceptacion_prev_pct': 36.4,
              'delta_tasa_pct': -0.4,
              'delta_preguntas': -1,
              'sample_bucket': 'baja',
              'confidence_score': 0.28,
              'raw_rank': 1,
              'confidence_rank': 1,
            },
            'confidence_leader': {
              'tecnologia': 'svelte',
              'total_preguntas': 150,
              'respuestas_aceptadas': 54,
              'tasa_aceptacion_pct': 36.0,
              'total_preguntas_prev': 151,
              'respuestas_aceptadas_prev': 55,
              'tasa_aceptacion_prev_pct': 36.4,
              'delta_tasa_pct': -0.4,
              'delta_preguntas': -1,
              'sample_bucket': 'baja',
              'confidence_score': 0.28,
              'raw_rank': 1,
              'confidence_rank': 1,
            },
            'highest_improvement': {
              'tecnologia': 'reactjs',
              'total_preguntas': 2300,
              'respuestas_aceptadas': 560,
              'tasa_aceptacion_pct': 24.3,
              'total_preguntas_prev': 2400,
              'respuestas_aceptadas_prev': 570,
              'tasa_aceptacion_prev_pct': 24.0,
              'delta_tasa_pct': 0.3,
              'delta_preguntas': -100,
              'sample_bucket': 'alta',
              'confidence_score': 0.22,
              'raw_rank': 4,
              'confidence_rank': 3,
            },
            'largest_drop': null,
            'largest_sample': {
              'tecnologia': 'reactjs',
              'total_preguntas': 2300,
              'respuestas_aceptadas': 560,
              'tasa_aceptacion_pct': 24.3,
              'total_preguntas_prev': 2400,
              'respuestas_aceptadas_prev': 570,
              'tasa_aceptacion_prev_pct': 24.0,
              'delta_tasa_pct': 0.3,
              'delta_preguntas': -100,
              'sample_bucket': 'alta',
              'confidence_score': 0.22,
              'raw_rank': 4,
              'confidence_rank': 3,
            },
          },
          'latest_items': [
            {
              'tecnologia': 'svelte',
              'total_preguntas': 150,
              'respuestas_aceptadas': 54,
              'tasa_aceptacion_pct': 36.0,
              'total_preguntas_prev': 151,
              'respuestas_aceptadas_prev': 55,
              'tasa_aceptacion_prev_pct': 36.4,
              'delta_tasa_pct': -0.4,
              'delta_preguntas': -1,
              'sample_bucket': 'baja',
              'confidence_score': 0.28,
              'raw_rank': 1,
              'confidence_rank': 1,
            },
            {
              'tecnologia': 'reactjs',
              'total_preguntas': 2300,
              'respuestas_aceptadas': 560,
              'tasa_aceptacion_pct': 24.3,
              'total_preguntas_prev': 2400,
              'respuestas_aceptadas_prev': 570,
              'tasa_aceptacion_prev_pct': 24.0,
              'delta_tasa_pct': 0.3,
              'delta_preguntas': -100,
              'sample_bucket': 'alta',
              'confidence_score': 0.22,
              'raw_rank': 4,
              'confidence_rank': 3,
            },
          ],
          'snapshots': [],
        },
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.aceptacionHistory, isNotNull);
      expect(state.data!.aceptacion.first.tecnologia, 'svelte');
      expect(state.data!.aceptacion.first.sampleBucket, 'baja');
      expect(state.data!.aceptacion.first.confidenceRank, 1);
    },
  );

  test(
    'StackOverflowRepository falls back to acceptance CSV when bridge fails',
    () async {
      final service = FakeDataService(
        csvByAsset: {
          'assets/data/so_volumen_preguntas.csv': [
            {'lenguaje': 'python', 'preguntas_nuevas_2025': 100},
          ],
          'assets/data/so_tasa_aceptacion.csv': [
            {
              'tecnologia': 'reactjs',
              'tasa_aceptacion_pct': 30,
              'total_preguntas': 150,
            },
          ],
          'assets/data/so_tendencias_mensuales.csv': [
            {'mes': '2026-03', 'python': 10, 'javascript': 9, 'typescript': 8},
          ],
        },
        throwAssets: const {'assets/data/so_aceptacion_history.json'},
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.aceptacionHistory, isNull);
      expect(state.data!.aceptacion.single.tecnologia, 'reactjs');
      expect(state.data!.aceptacion.single.totalPreguntasPrev, 0);
    },
  );

  test(
    'StackOverflowRepository uses trends history bridge before CSV fallback',
    () async {
      final service = FakeDataService(
        csvByAsset: {
          'assets/data/so_volumen_preguntas.csv': [
            {'lenguaje': 'python', 'preguntas_nuevas_2025': 100},
          ],
          'assets/data/so_tasa_aceptacion.csv': [
            {
              'tecnologia': 'reactjs',
              'tasa_aceptacion_pct': 30,
              'total_preguntas': 150,
            },
          ],
        },
        fakeStackOverflowTrendsHistoryPublic: {
          'source_mode': 'history',
          'snapshot_count': 5,
          'months': ['2025-03', '2025-04', '2025-05'],
          'series': [
            {
              'tecnologia': 'Python',
              'points': [120, 95, 80],
              'start_value': 120,
              'end_value': 80,
              'abs_delta': -40,
              'pct_delta': -33.3,
              'retention_pct': 66.7,
              'peak_month': '2025-03',
              'peak_value': 120,
              'latest_rank': 1,
            },
            {
              'tecnologia': 'JavaScript',
              'points': [90, 74, 60],
              'start_value': 90,
              'end_value': 60,
              'abs_delta': -30,
              'pct_delta': -33.3,
              'retention_pct': 66.7,
              'peak_month': '2025-03',
              'peak_value': 90,
              'latest_rank': 2,
            },
            {
              'tecnologia': 'TypeScript',
              'points': [50, 41, 32],
              'start_value': 50,
              'end_value': 32,
              'abs_delta': -18,
              'pct_delta': -36.0,
              'retention_pct': 64.0,
              'peak_month': '2025-03',
              'peak_value': 50,
              'latest_rank': 3,
            },
          ],
          'summary': {
            'current_leader': {
              'tecnologia': 'Python',
              'start_value': 120,
              'end_value': 80,
              'abs_delta': -40,
              'pct_delta': -33.3,
              'retention_pct': 66.7,
              'peak_month': '2025-03',
              'peak_value': 120,
              'latest_rank': 1,
            },
            'best_retention': {
              'tecnologia': 'Python',
              'start_value': 120,
              'end_value': 80,
              'abs_delta': -40,
              'pct_delta': -33.3,
              'retention_pct': 66.7,
              'peak_month': '2025-03',
              'peak_value': 120,
              'latest_rank': 1,
            },
            'largest_relative_drop': {
              'tecnologia': 'TypeScript',
              'start_value': 50,
              'end_value': 32,
              'abs_delta': -18,
              'pct_delta': -36.0,
              'retention_pct': 64.0,
              'peak_month': '2025-03',
              'peak_value': 50,
              'latest_rank': 3,
            },
            'largest_absolute_drop': {
              'tecnologia': 'Python',
              'start_value': 120,
              'end_value': 80,
              'abs_delta': -40,
              'pct_delta': -33.3,
              'retention_pct': 66.7,
              'peak_month': '2025-03',
              'peak_value': 120,
              'latest_rank': 1,
            },
          },
        },
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.tendenciasHistory, isNotNull);
      expect(state.data!.tendencias.length, 3);
      expect(state.data!.tendencias.first.python, 120);
      expect(state.data!.tendencias.last.typescript, 32);
    },
  );

  test(
    'StackOverflowRepository falls back to trends CSV when bridge fails',
    () async {
      final service = FakeDataService(
        csvByAsset: {
          'assets/data/so_volumen_preguntas.csv': [
            {'lenguaje': 'python', 'preguntas_nuevas_2025': 100},
          ],
          'assets/data/so_tasa_aceptacion.csv': [
            {
              'tecnologia': 'reactjs',
              'tasa_aceptacion_pct': 30,
              'total_preguntas': 150,
            },
          ],
          'assets/data/so_tendencias_mensuales.csv': [
            {'mes': '2025-03', 'python': 20, 'javascript': 12, 'typescript': 8},
            {'mes': '2025-04', 'python': 18, 'javascript': 10, 'typescript': 6},
          ],
        },
        throwAssets: const {'assets/data/so_tendencias_history.json'},
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.tendenciasHistory, isNull);
      expect(state.data!.tendencias.length, 2);
      expect(state.data!.tendencias.first.python, 20);
    },
  );

  test(
    'StackOverflowRepository falls back to CSV and computes share when bridge fails',
    () async {
      final service = FakeDataService(
        csvByAsset: {
          'assets/data/so_volumen_preguntas.csv': [
            {'lenguaje': 'python', 'preguntas_nuevas_2025': 100},
            {'lenguaje': 'java', 'preguntas_nuevas_2025': 50},
          ],
          'assets/data/so_tasa_aceptacion.csv': [
            {
              'tecnologia': 'reactjs',
              'tasa_aceptacion_pct': 30,
              'total_preguntas': 150,
            },
          ],
          'assets/data/so_tendencias_mensuales.csv': [
            {'mes': '2026-03', 'python': 10, 'javascript': 9, 'typescript': 8},
          ],
        },
        throwAssets: const {'assets/data/so_volumen_history.json'},
      );
      final repo = StackOverflowRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.volumenHistory, isNull);
      expect(state.data!.volumen.first.lenguaje, 'python');
      expect(state.data!.volumen.first.sharePct, closeTo(66.67, 0.01));
      expect(state.data!.volumen.last.sharePct, closeTo(33.33, 0.01));
    },
  );

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

  test(
    'RedditRepository uses public sentiment bridge when available',
    () async {
      final service = FakeDataService(
        fakeRedditSentimentPublic: {
          'summary': {
            'positive_leader': {
              'framework': 'Django',
              'total_menciones': 9,
              'porcentaje_positivo': 88.89,
              'porcentaje_neutro': 0.0,
              'porcentaje_negativo': 11.11,
            },
          },
          'frameworks': [
            {
              'framework': 'Django',
              'total_menciones': 9,
              'porcentaje_positivo': 88.89,
              'porcentaje_neutro': 0.0,
              'porcentaje_negativo': 11.11,
            },
          ],
        },
        csvByAsset: {
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
      expect(state.data!.sentimiento, isNotEmpty);
      expect(state.data!.sentimiento.first.framework, 'Django');
      expect(state.data!.sentimiento.first.totalMenciones, 9);
      expect(state.data!.sentimientoSummary, isNotNull);
      expect(
        state.data!.sentimientoSummary!.positiveLeader?.framework,
        'Django',
      );
    },
  );

  test(
    'RedditRepository uses public topics history bridge when available',
    () async {
      final service = FakeDataService(
        fakeRedditTopicsHistoryPublic: {
          'dataset': 'reddit_temas_emergentes',
          'snapshot_count': 2,
          'latest_snapshot_date': '2026-03-03',
          'previous_snapshot_date': '2026-02-27',
          'latest_topics': [
            {
              'tema': 'AI/ML',
              'menciones': 120,
              'menciones_previas': 100,
              'delta_menciones': 20,
              'growth_pct': 20.0,
            },
          ],
        },
        csvByAsset: {
          'assets/data/reddit_sentimiento_frameworks.csv': [
            {'framework': 'django', '% positivo': 50, '% negativo': 50},
          ],
          'assets/data/interseccion_github_reddit.csv': [
            {'tecnologia': 'Python', 'ranking_github': 1, 'ranking_reddit': 1},
          ],
        },
      );
      final repo = RedditRepository(service);

      final state = await repo.loadDashboardData();
      expect(state.isData, true);
      expect(state.data!.temas, isNotEmpty);
      expect(state.data!.temas.first.tema, 'AI/ML');
      expect(state.data!.temas.first.growthPct, 20.0);
      expect(state.data!.temasHistory, isNotNull);
      expect(state.data!.temasHistory!.hasGrowthSignals, true);
    },
  );

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

  test('TechnologyProfilesRepository loads profiles when available', () async {
    final repo = TechnologyProfilesRepository(
      const FakeDataService(
        fakeTechnologyProfiles: {
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
              'sources_present': ['github'],
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
                'available': false,
                'score_actual': 0.0,
                'score_prev': 0.0,
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
                  'so_score': 0.0,
                  'reddit_score': 0.0,
                  'ranking': 2,
                  'fuentes': 1,
                  'available_source_codes': ['GH'],
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
                  'source_count': 1,
                  'sources_present': ['github'],
                  'label': 'Señal disponible en GitHub.',
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
        },
      ),
    );

    final result = await repo.loadTechnologyProfiles();
    expect(result.isData, true);
    expect(result.data?.profiles.first.slug, 'python');
  });

  test('TechnologyProfilesRepository returns error when bridge fails', () async {
    final repo = TechnologyProfilesRepository(
      const FakeDataService(
        throwAssets: {'assets/data/technology_profiles.json'},
      ),
    );

    final result = await repo.loadTechnologyProfiles();
    expect(result.isError, true);
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

  test('TrendRepository maps csv source to data state', () async {
    final repo = TrendRepository(
      const FakeDataService(
        fakeTrendView: TrendTemporalViewData(
          source: 'csv',
          snapshotCount: 1,
          items: [],
        ),
      ),
    );
    final state = await repo.loadTrendTemporalView();
    expect(state.isData, true);
    expect(state.isDegraded, false);
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
                githubScore: 40,
                stackOverflowScore: 30,
                redditScore: 6.45,
                scorePrev: 74.00,
                deltaScore: 2.45,
                rankingPrev: 2,
                deltaRanking: 1,
                availableSources: <String>['GH', 'SO', 'RD'],
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

  test(
    'TrendRepository prefers bridge history when csv_fallback but bridge exists',
    () async {
      final service = FakeDataService(
        fakeTrendView: const TrendTemporalViewData(
          source: 'csv_fallback',
          snapshotCount: 1,
          items: <TrendTopEntry>[],
        ),
        jsonByAsset: {
          'assets/data/trend_score_history.json': {
            'generated_at_utc': '2026-03-11T00:00:00Z',
            'snapshot_count': 2,
            'snapshots': [
              {
                'date': '2026-03-10',
                'path': 'datos/history/trend_score/day=10/trend_score.csv',
                'source_type': 'history',
                'row_count': 1,
                'top_10': [
                  {
                    'ranking': 1,
                    'tecnologia': 'Python',
                    'slug': 'python',
                    'github_score': 100.0,
                    'so_score': 90.0,
                    'reddit_score': 10.0,
                    'trend_score': 80.0,
                    'fuentes': 3,
                    'available_source_codes': ['GH', 'SO', 'RD'],
                  },
                ],
              },
              {
                'date': '2026-03-11',
                'path': 'datos/history/trend_score/day=11/trend_score.csv',
                'source_type': 'history',
                'row_count': 1,
                'top_10': [
                  {
                    'ranking': 1,
                    'tecnologia': 'Python',
                    'slug': 'python',
                    'github_score': 100.0,
                    'so_score': 91.0,
                    'reddit_score': 12.0,
                    'trend_score': 81.0,
                    'fuentes': 3,
                    'available_source_codes': ['GH', 'SO', 'RD'],
                  },
                ],
              },
            ],
          },
        },
      );
      final repo = TrendRepository(service);

      final state = await repo.loadTrendTemporalView();
      expect(state.isData, true);
      expect(state.data, isNotNull);
      expect(state.data!.source, 'bridge_json');
      expect(state.data!.latestSnapshotDate, '2026-03-11');
      expect(state.data!.items.first.tecnologia, 'Python');
    },
  );
}
