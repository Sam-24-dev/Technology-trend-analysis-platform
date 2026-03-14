import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/github_models.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/github_dashboard.dart';

void main() {
  RunManifestPublic _manifest() {
    return const RunManifestPublic(
      manifestVersion: '1.0.0',
      generatedAtUtc: '2026-03-06T01:10:00Z',
      sourceWindowStartUtc: '2025-03-01T00:00:00Z',
      sourceWindowEndUtc: '2026-03-06T00:00:00Z',
      qualityGateStatus: 'pass',
      degradedMode: false,
      availableSources: <String>['github', 'stackoverflow', 'reddit'],
      datasetSummaries: <RunManifestDatasetSummary>[],
      totalReposExtraidos: 1000,
      totalReposClasificables: 900,
      soLanguagesCount: 10,
      notes: null,
    );
  }

  List<LenguajeModel> _lenguajes() {
    return <LenguajeModel>[
      LenguajeModel(lenguaje: 'Python', reposCount: 322, porcentaje: 34.8),
      LenguajeModel(lenguaje: 'TypeScript', reposCount: 240, porcentaje: 25.9),
    ];
  }

  List<FrameworkCommitModel> _frameworks() {
    return <FrameworkCommitModel>[
      FrameworkCommitModel(
        framework: 'Next.js',
        repo: 'vercel/next.js',
        commits2025: 5000,
        ranking: 1,
        activeContributors: 304,
        mergedPrs: 5007,
        closedIssues: 2316,
        releasesCount: 633,
        commitsPrev: 5000,
        deltaCommits: 0,
        growthPct: 0.0,
        trendDirection: 'estable',
      ),
      FrameworkCommitModel(
        framework: 'Angular',
        repo: 'angular/angular',
        commits2025: 4333,
        ranking: 2,
        activeContributors: 274,
        mergedPrs: 1978,
        closedIssues: 2101,
        releasesCount: 142,
        commitsPrev: 4353,
        deltaCommits: -20,
        growthPct: -0.46,
        trendDirection: 'cayendo',
      ),
    ];
  }

  GithubFrameworkHistoryModel _frameworkHistory() {
    return GithubFrameworkHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-06',
      'previous_snapshot_date': '2026-03-05',
      'item_count': 2,
      'has_historical_comparison': true,
      'latest_frameworks': [
        {
          'framework': 'Next.js',
          'repo': 'vercel/next.js',
          'ranking': 1,
          'commits_2025': 5000,
          'active_contributors': 304,
          'merged_prs': 5007,
          'closed_issues': 2316,
          'releases_count': 633,
          'commits_prev': 5000,
          'delta_commits': 0,
          'growth_pct': 0.0,
          'trend_direction': 'estable',
        },
        {
          'framework': 'Angular',
          'repo': 'angular/angular',
          'ranking': 2,
          'commits_2025': 4333,
          'active_contributors': 274,
          'merged_prs': 1978,
          'closed_issues': 2101,
          'releases_count': 142,
          'commits_prev': 4353,
          'delta_commits': -20,
          'growth_pct': -0.46,
          'trend_direction': 'cayendo',
        },
      ],
      'summary': <String, dynamic>{
        'leader_framework': 'Next.js',
        'leader_commits': 5000,
        'max_drop_framework': 'Angular',
        'max_drop_delta': -20,
        'missing_metrics_frameworks': 0,
      },
      'series': <dynamic>[],
    });
  }

  GithubCorrelationHistoryModel _correlationHistory() {
    return GithubCorrelationHistoryModel.fromMap(<String, dynamic>{
      'dataset': 'github_correlacion',
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-06',
      'previous_snapshot_date': '2026-03-05',
      'item_count': 4,
      'has_historical_comparison': true,
      'summary': {
        'correlation_value': 0.6552,
        'top_stars_repo': {
          'repo_name': 'vercel/next.js',
          'stars': 128000,
          'contributors': 304,
          'language': 'TypeScript',
          'engagement_ratio': 0.0024,
          'contributors_per_1k_stars': 2.375,
          'expected_contributors': 280.0,
          'contributors_delta_vs_trend': 24.0,
          'outlier_score': 1.3,
          'trend_bucket': 'above_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        'top_contributors_repo': {
          'repo_name': 'angular/angular',
          'stars': 95000,
          'contributors': 320,
          'language': 'TypeScript',
          'engagement_ratio': 0.0033,
          'contributors_per_1k_stars': 3.368,
          'expected_contributors': 260.0,
          'contributors_delta_vs_trend': 60.0,
          'outlier_score': 1.8,
          'trend_bucket': 'above_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        'top_engagement_repo': {
          'repo_name': 'sveltejs/svelte',
          'stars': 70000,
          'contributors': 260,
          'language': 'TypeScript',
          'engagement_ratio': 0.0037,
          'contributors_per_1k_stars': 3.714,
          'expected_contributors': 210.0,
          'contributors_delta_vs_trend': 50.0,
          'outlier_score': 1.4,
          'trend_bucket': 'above_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        'positive_outlier_repo': {
          'repo_name': 'angular/angular',
          'stars': 95000,
          'contributors': 320,
          'language': 'TypeScript',
          'engagement_ratio': 0.0033,
          'contributors_per_1k_stars': 3.368,
          'expected_contributors': 260.0,
          'contributors_delta_vs_trend': 60.0,
          'outlier_score': 1.8,
          'trend_bucket': 'above_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        'negative_outlier_repo': {
          'repo_name': 'facebook/react',
          'stars': 110000,
          'contributors': 90,
          'language': 'JavaScript',
          'engagement_ratio': 0.0008,
          'contributors_per_1k_stars': 0.818,
          'expected_contributors': 180.0,
          'contributors_delta_vs_trend': -90.0,
          'outlier_score': -1.5,
          'trend_bucket': 'below_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        'item_count': 4,
        'latest_snapshot_date': '2026-03-06',
        'previous_snapshot_date': '2026-03-05',
      },
      'latest_items': [
        {
          'repo_name': 'vercel/next.js',
          'stars': 128000,
          'contributors': 304,
          'language': 'TypeScript',
          'engagement_ratio': 0.0024,
          'contributors_per_1k_stars': 2.375,
          'expected_contributors': 280.0,
          'contributors_delta_vs_trend': 24.0,
          'outlier_score': 1.3,
          'trend_bucket': 'above_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        {
          'repo_name': 'angular/angular',
          'stars': 95000,
          'contributors': 320,
          'language': 'TypeScript',
          'engagement_ratio': 0.0033,
          'contributors_per_1k_stars': 3.368,
          'expected_contributors': 260.0,
          'contributors_delta_vs_trend': 60.0,
          'outlier_score': 1.8,
          'trend_bucket': 'above_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        {
          'repo_name': 'facebook/react',
          'stars': 110000,
          'contributors': 90,
          'language': 'JavaScript',
          'engagement_ratio': 0.0008,
          'contributors_per_1k_stars': 0.818,
          'expected_contributors': 180.0,
          'contributors_delta_vs_trend': -90.0,
          'outlier_score': -1.5,
          'trend_bucket': 'below_trend',
          'snapshot_date_utc': '2026-03-06',
        },
        {
          'repo_name': 'sveltejs/svelte',
          'stars': 70000,
          'contributors': 260,
          'language': 'TypeScript',
          'engagement_ratio': 0.0037,
          'contributors_per_1k_stars': 3.714,
          'expected_contributors': 210.0,
          'contributors_delta_vs_trend': 50.0,
          'outlier_score': 1.4,
          'trend_bucket': 'above_trend',
          'snapshot_date_utc': '2026-03-06',
        },
      ],
      'snapshots': [],
    });
  }

  GithubCorrelationHistoryModel _largeCorrelationHistory() {
    final List<Map<String, dynamic>> latestItems = <Map<String, dynamic>>[];

    for (int index = 1; index <= 30; index++) {
      final int stars = 10000 + (index * 1000);
      final int contributors = 20 + index;
      latestItems.add(<String, dynamic>{
        'repo_name': 'org/repo-$index',
        'stars': stars,
        'contributors': contributors,
        'language': 'TypeScript',
        'engagement_ratio': contributors / stars,
        'contributors_per_1k_stars': (contributors / stars) * 1000,
        'expected_contributors': contributors.toDouble(),
        'contributors_delta_vs_trend': 0.0,
        'outlier_score': 0.0,
        'trend_bucket': 'near_trend',
        'snapshot_date_utc': '2026-03-06',
      });
    }

    latestItems.addAll(<Map<String, dynamic>>[
      <String, dynamic>{
        'repo_name': 'special/contributors-king',
        'stars': 50,
        'contributors': 1000,
        'language': '',
        'engagement_ratio': 20.0,
        'contributors_per_1k_stars': 20000.0,
        'expected_contributors': 150.0,
        'contributors_delta_vs_trend': 850.0,
        'outlier_score': 1.5,
        'trend_bucket': 'above_trend',
        'snapshot_date_utc': '2026-03-06',
      },
      <String, dynamic>{
        'repo_name': 'special/engagement-king',
        'stars': 10,
        'contributors': 500,
        'language': '',
        'engagement_ratio': 50.0,
        'contributors_per_1k_stars': 50000.0,
        'expected_contributors': 80.0,
        'contributors_delta_vs_trend': 420.0,
        'outlier_score': 1.2,
        'trend_bucket': 'above_trend',
        'snapshot_date_utc': '2026-03-06',
      },
      <String, dynamic>{
        'repo_name': 'special/outlier-up',
        'stars': 100,
        'contributors': 600,
        'language': '',
        'engagement_ratio': 6.0,
        'contributors_per_1k_stars': 6000.0,
        'expected_contributors': 100.0,
        'contributors_delta_vs_trend': 500.0,
        'outlier_score': 5.0,
        'trend_bucket': 'above_trend',
        'snapshot_date_utc': '2026-03-06',
      },
      <String, dynamic>{
        'repo_name': 'special/outlier-down',
        'stars': 200,
        'contributors': 2,
        'language': '',
        'engagement_ratio': 0.01,
        'contributors_per_1k_stars': 10.0,
        'expected_contributors': 120.0,
        'contributors_delta_vs_trend': -118.0,
        'outlier_score': -4.0,
        'trend_bucket': 'below_trend',
        'snapshot_date_utc': '2026-03-06',
      },
      <String, dynamic>{
        'repo_name': 'special/filler-low',
        'stars': 5,
        'contributors': 40,
        'language': '',
        'engagement_ratio': 8.0,
        'contributors_per_1k_stars': 8000.0,
        'expected_contributors': 25.0,
        'contributors_delta_vs_trend': 15.0,
        'outlier_score': 0.2,
        'trend_bucket': 'near_trend',
        'snapshot_date_utc': '2026-03-06',
      },
    ]);

    return GithubCorrelationHistoryModel.fromMap(<String, dynamic>{
      'dataset': 'github_correlacion',
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-06',
      'previous_snapshot_date': '2026-03-05',
      'item_count': latestItems.length,
      'has_historical_comparison': true,
      'summary': <String, dynamic>{
        'correlation_value': 0.55,
        'top_stars_repo': latestItems[29],
        'top_contributors_repo': latestItems[30],
        'top_engagement_repo': latestItems[31],
        'positive_outlier_repo': latestItems[32],
        'negative_outlier_repo': latestItems[33],
        'item_count': latestItems.length,
        'latest_snapshot_date': '2026-03-06',
        'previous_snapshot_date': '2026-03-05',
      },
      'latest_items': latestItems,
      'snapshots': <dynamic>[],
    });
  }

  Future<void> _pumpDashboard(
    WidgetTester tester, {
    Size size = const Size(1280, 900),
    GithubCorrelationHistoryModel? correlationHistory,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          githubDashboardProvider.overrideWith((ref) async {
            return DataLoadState<GithubDashboardData>.data(
              GithubDashboardData(
                lenguajes: _lenguajes(),
                frameworks: _frameworks(),
                correlacion:
                    (correlationHistory ?? _correlationHistory()).latestItems,
                frameworksHistory: _frameworkHistory(),
                correlationHistory: correlationHistory ?? _correlationHistory(),
              ),
            );
          }),
          runManifestProvider.overrideWith((ref) async {
            return DataLoadState<RunManifestPublic>.data(_manifest());
          }),
        ],
        child: const MaterialApp(home: GithubDashboard()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
  }

  Finder _insideFilter(Key key) {
    return find.descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate((Widget w) => w is DropdownButton),
    );
  }

  Future<void> _openFilter(WidgetTester tester, Key key) async {
    final Finder container = find.byKey(key);
    await tester.ensureVisible(container);
    await tester.pumpAndSettle();
    await tester.tap(_insideFilter(key), warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('github graph 3 shows summary badges and fixed detail panel', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester);

    expect(find.text('Correlación: 0.66'), findsOneWidget);
    expect(find.text('Mayor stars: next.js'), findsOneWidget);
    expect(find.text('Mayor contributors: angular'), findsOneWidget);
    expect(find.text('Comunidad más activa: svelte'), findsOneWidget);
    expect(find.text('next.js'), findsWidgets);
    expect(find.text('Detalle basico'), findsOneWidget);
    expect(find.text('Contributors / 1k stars'), findsOneWidget);
    expect(find.text('Posicion frente a la tendencia'), findsOneWidget);
    expect(find.text('Snapshot actual (UTC): 06/03/2026'), findsNothing);
    expect(
      find.textContaining('Comparado (UTC): 05/03/2026 -> 06/03/2026'),
      findsWidgets,
    );
  });

  testWidgets('github graph 3 toggles view and detail mode', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester);

    const Key focusKey = ValueKey<String>('gh-correlation-focus-filter');
    const Key detailKey = ValueKey<String>('gh-correlation-detail-filter');

    expect(
      find.byKey(const ValueKey<String>('gh-correlation-scale-filter')),
      findsNothing,
    );
    expect(find.text('Lineal'), findsNothing);
    expect(find.textContaining('Escala: Log'), findsOneWidget);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Top contributors').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.textContaining('Vista: Top contributors'), findsOneWidget);

    await _openFilter(tester, detailKey);
    await tester.tap(find.text('Avanzado').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Detalle avanzado'), findsOneWidget);
    expect(find.text('Distancia a la tendencia'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('github graph 3 remains stable across supported breakpoints', (
    WidgetTester tester,
  ) async {
    final List<Size> sizes = <Size>[
      const Size(390, 844),
      const Size(844, 390),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1440, 900),
    ];

    for (final Size size in sizes) {
      await _pumpDashboard(tester, size: size);
      expect(find.byType(LineChart), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('github graph 3 badges become contextual per active view', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(
      tester,
      correlationHistory: _largeCorrelationHistory(),
    );

    expect(find.text('Mayor contributors: contributors-king'), findsOneWidget);
    expect(find.text('Comunidad más activa: engagement-king'), findsOneWidget);
    expect(find.text('Por encima de la tendencia: outlier-up'), findsOneWidget);
    expect(
      find.text('Por debajo de la tendencia: outlier-down'),
      findsOneWidget,
    );

    const Key focusKey = ValueKey<String>('gh-correlation-focus-filter');

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Top stars').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Vista: Top stars'), findsOneWidget);
    expect(find.text('Mayor stars: repo-30'), findsOneWidget);
    expect(find.text('Mayor contributors: repo-30'), findsNothing);
    expect(find.text('Comunidad más activa: repo-1'), findsNothing);
    expect(find.text('Por encima de la tendencia: outlier-up'), findsNothing);
    expect(find.text('Por debajo de la tendencia: outlier-down'), findsNothing);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Top contributors').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Vista: Top contributors'), findsOneWidget);
    expect(find.text('Mayor contributors: contributors-king'), findsOneWidget);
    expect(find.text('Mayor stars: repo-30'), findsNothing);
    expect(find.text('Comunidad más activa: engagement-king'), findsOneWidget);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Top engagement').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Vista: Top engagement'), findsOneWidget);
    expect(find.text('Comunidad más activa: engagement-king'), findsOneWidget);
    expect(find.text('Mayor stars: repo-30'), findsNothing);
    expect(find.text('Mayor contributors: contributors-king'), findsNothing);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Outliers').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.textContaining('Vista: Outliers'), findsOneWidget);
    expect(find.text('Mayor stars: repo-30'), findsNothing);
    expect(find.text('Mayor contributors: contributors-king'), findsNothing);
    expect(find.text('Comunidad más activa: engagement-king'), findsNothing);
    expect(find.text('Por encima de la tendencia: outlier-up'), findsOneWidget);
    expect(
      find.text('Por debajo de la tendencia: outlier-down'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('github graph 3 auto-selects the key repo for each view', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(
      tester,
      correlationHistory: _largeCorrelationHistory(),
    );

    const Key focusKey = ValueKey<String>('gh-correlation-focus-filter');

    Future<void> expectSelectedIndex(int expectedIndex) async {
      final LineChart chart = tester.widget<LineChart>(
        find.byType(LineChart).last,
      );
      expect(chart.data.lineBarsData.first.showingIndicators, <int>[
        expectedIndex,
      ]);
    }

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Top stars').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await expectSelectedIndex(0);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Ver todos').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await expectSelectedIndex(29);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Top contributors').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await expectSelectedIndex(0);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Top engagement').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await expectSelectedIndex(0);

    await _openFilter(tester, focusKey);
    await tester.tap(find.text('Outliers').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    await expectSelectedIndex(0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'github graph 3 uses dynamic log bounds and keeps collision selector working',
    (WidgetTester tester) async {
      await _pumpDashboard(
        tester,
        correlationHistory: _largeCorrelationHistory(),
      );

      expect(
        find.text('Selecciona un punto para ver sus detalles'),
        findsOneWidget,
      );

      final LineChart initialChart = tester.widget<LineChart>(
        find.byType(LineChart).last,
      );
      final double initialMinX = initialChart.data.minX;
      expect(initialMinX, greaterThan(0));
      expect(initialChart.data.minY, greaterThanOrEqualTo(0));

      const Key focusKey = ValueKey<String>('gh-correlation-focus-filter');
      await _openFilter(tester, focusKey);
      await tester.tap(find.text('Top stars').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      final LineChart focusedChart = tester.widget<LineChart>(
        find.byType(LineChart).last,
      );
      expect(focusedChart.data.minX, greaterThan(initialMinX));

      final LineChartBarData scatterBar = focusedChart.data.lineBarsData.first;
      final void Function(FlTouchEvent, LineTouchResponse?)? touchCallback =
          focusedChart.data.lineTouchData.touchCallback;

      expect(touchCallback, isNotNull);
      touchCallback!(
        FlTapUpEvent(
          TapUpDetails(
            kind: PointerDeviceKind.touch,
            localPosition: Offset.zero,
          ),
        ),
        LineTouchResponse(<TouchLineBarSpot>[
          TouchLineBarSpot(scatterBar, 0, scatterBar.spots[0], 0),
          TouchLineBarSpot(scatterBar, 0, scatterBar.spots[1], 0),
        ]),
      );
      await tester.pump();

      expect(
        find.text('Repos cercanos: elige uno para fijar el detalle.'),
        findsOneWidget,
      );
      expect(find.byType(ChoiceChip), findsAtLeastNWidgets(2));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('github graph 3 formats advanced detail values readably', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester);

    const Key detailKey = ValueKey<String>('gh-correlation-detail-filter');

    await _openFilter(tester, detailKey);
    await tester.tap(find.text('Avanzado').last, warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Detalle avanzado'), findsOneWidget);
    expect(find.text('Distancia a la tendencia'), findsOneWidget);
    expect(find.text('0.002'), findsOneWidget);
    expect(find.text('2.4'), findsOneWidget);
    expect(find.text('280.0'), findsOneWidget);
    expect(find.text('+24.0'), findsOneWidget);
    expect(find.text('+1.3'), findsOneWidget);
  });
}
