import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/github_models.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/github_dashboard.dart';
import 'package:frontend/services/download/download_service.dart';

class _FakeDownloadService implements DownloadService {
  String? fileName;
  List<int>? zipBytes;

  @override
  Future<void> saveZipBytes({
    required String fileName,
    required List<int> bytes,
  }) async {
    this.fileName = fileName;
    zipBytes = bytes;
  }
}

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

  List<FrameworkCommitModel> _frameworks({
    int nextDelta = 0,
    int angularDelta = -20,
    int reactDelta = 2,
    int svelteDelta = 0,
    int vueDelta = 0,
  }) {
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
        commitsPrev: 5000 - nextDelta,
        deltaCommits: nextDelta,
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
        commitsPrev: 4333 - angularDelta,
        deltaCommits: angularDelta,
        growthPct: -0.46,
        trendDirection: 'cayendo',
      ),
      FrameworkCommitModel(
        framework: 'React',
        repo: 'facebook/react',
        commits2025: 1380,
        ranking: 3,
        activeContributors: 90,
        mergedPrs: 1381,
        closedIssues: 797,
        releasesCount: 15,
        commitsPrev: 1380 - reactDelta,
        deltaCommits: reactDelta,
        growthPct: -0.14,
        trendDirection: 'estable',
      ),
      FrameworkCommitModel(
        framework: 'Svelte',
        repo: 'sveltejs/svelte',
        commits2025: 999,
        ranking: 4,
        activeContributors: 113,
        mergedPrs: 1015,
        closedIssues: 778,
        releasesCount: 207,
        commitsPrev: 999 - svelteDelta,
        deltaCommits: svelteDelta,
        growthPct: 0.0,
        trendDirection: 'estable',
      ),
      FrameworkCommitModel(
        framework: 'Vue 3',
        repo: 'vuejs/core',
        commits2025: 390,
        ranking: 5,
        activeContributors: 81,
        mergedPrs: 652,
        closedIssues: 407,
        releasesCount: 30,
        commitsPrev: 390 - vueDelta,
        deltaCommits: vueDelta,
        growthPct: -0.51,
        trendDirection: 'cayendo',
      ),
    ];
  }

  GithubFrameworkHistoryModel _historyFromFrameworks(
    List<FrameworkCommitModel> rows,
  ) {
    return GithubFrameworkHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-06',
      'previous_snapshot_date': '2026-03-05',
      'item_count': rows.length,
      'has_historical_comparison': true,
      'latest_frameworks': rows
          .map(
            (item) => <String, dynamic>{
              'framework': item.framework,
              'repo': item.repo,
              'ranking': item.ranking,
              'commits_2025': item.commits2025,
              'active_contributors': item.activeContributors,
              'merged_prs': item.mergedPrs,
              'closed_issues': item.closedIssues,
              'releases_count': item.releasesCount,
              'commits_prev': item.commitsPrev,
              'delta_commits': item.deltaCommits,
              'growth_pct': item.growthPct,
              'trend_direction': item.trendDirection,
              'active_contributors_prev': null,
              'delta_active_contributors': null,
              'growth_active_contributors_pct': null,
              'merged_prs_prev': null,
              'delta_merged_prs': null,
              'growth_merged_prs_pct': null,
              'closed_issues_prev': null,
              'delta_closed_issues': null,
              'growth_closed_issues_pct': null,
              'releases_count_prev': null,
              'delta_releases_count': null,
              'growth_releases_count_pct': null,
            },
          )
          .toList(),
      'summary': <String, dynamic>{
        'leader_framework': 'Next.js',
        'leader_commits': 5000,
        'max_growth_framework': 'React',
        'max_growth_delta': 2,
        'max_drop_framework': 'Angular',
        'max_drop_delta': -20,
        'missing_metrics_frameworks': 0,
      },
      'series': <dynamic>[],
    });
  }

  List<LenguajeModel> _lenguajes() {
    return <LenguajeModel>[
      LenguajeModel(lenguaje: 'Python', reposCount: 322, porcentaje: 34.8),
      LenguajeModel(lenguaje: 'TypeScript', reposCount: 240, porcentaje: 25.9),
      LenguajeModel(lenguaje: 'JavaScript', reposCount: 64, porcentaje: 6.9),
      LenguajeModel(lenguaje: 'Go', reposCount: 57, porcentaje: 6.1),
      LenguajeModel(lenguaje: 'Rust', reposCount: 44, porcentaje: 4.8),
    ];
  }

  GithubLanguagePublicModel _lenguajesPublic() {
    return GithubLanguagePublicModel.fromMap(<String, dynamic>{
      'generated_at_utc': '2026-03-09T05:56:37Z',
      'dataset': 'github_lenguajes',
      'source_mode': 'latest',
      'source_path': 'datos/latest/github_lenguajes.csv',
      'source_updated_at_utc': '2026-03-09T05:16:58Z',
      'language_count': 10,
      'languages': <Map<String, dynamic>>[
        <String, dynamic>{
          'lenguaje': 'Python',
          'repos_count': 321,
          'share_pct': 34.55,
        },
        <String, dynamic>{
          'lenguaje': 'TypeScript',
          'repos_count': 245,
          'share_pct': 26.37,
        },
      ],
      'summary': <String, dynamic>{
        'leader': <String, dynamic>{
          'lenguaje': 'Python',
          'repos_count': 321,
          'share_pct': 34.55,
        },
        'runner_up': <String, dynamic>{
          'lenguaje': 'TypeScript',
          'repos_count': 245,
          'share_pct': 26.37,
        },
        'language_count': 10,
        'total_classifiable_repos': 835,
        'leader_gap_repos': 76,
        'leader_gap_share_pct': 8.18,
      },
    });
  }

  List<CorrelacionModel> _correlacion() {
    return <CorrelacionModel>[
      CorrelacionModel(
        repoName: 'vercel/next.js',
        stars: 128000,
        contributors: 304,
        language: 'TypeScript',
      ),
      CorrelacionModel(
        repoName: 'angular/angular',
        stars: 95000,
        contributors: 274,
        language: 'TypeScript',
      ),
    ];
  }

  GithubCorrelationHistoryModel _correlationHistory() {
    return GithubCorrelationHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-09',
      'previous_snapshot_date': '2026-03-08',
      'item_count': 2,
      'has_historical_comparison': true,
      'summary': <String, dynamic>{
        'correlation_value': 0.67,
        'positive_outlier_repo': <String, dynamic>{
          'repo_name': 'Kilo-Org/kilocode',
          'stars': 16395,
          'contributors': 869,
          'language': 'TypeScript',
          'contributors_per_1k_stars': 53.004,
          'engagement_ratio': 0.053004,
        },
      },
      'latest_items': _correlacion()
          .map(
            (CorrelacionModel item) => <String, dynamic>{
              'repo_name': item.repoName,
              'stars': item.stars,
              'contributors': item.contributors,
              'language': item.language,
            },
          )
          .toList(),
      'snapshots': const <dynamic>[],
    });
  }

  Future<void> _pumpGithubDashboard(
    WidgetTester tester, {
    required List<FrameworkCommitModel> frameworks,
    required GithubFrameworkHistoryModel history,
    GithubLanguagePublicModel? lenguajesPublic,
    GithubCorrelationHistoryModel? correlationHistory,
    Size size = const Size(1280, 900),
    DownloadService? downloadService,
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
                frameworks: frameworks,
                correlacion: _correlacion(),
                lenguajesPublic: lenguajesPublic ?? _lenguajesPublic(),
                frameworksHistory: history,
                correlationHistory: correlationHistory ?? _correlationHistory(),
              ),
            );
          }),
          runManifestProvider.overrideWith((ref) async {
            return DataLoadState<RunManifestPublic>.data(_manifest());
          }),
        ],
        child: MaterialApp(
          home: GithubDashboard(downloadService: downloadService),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
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

  testWidgets(
    'github chart 2 keeps filters interactive after Top 3 and metric switching',
    (WidgetTester tester) async {
      final List<FrameworkCommitModel> rows = _frameworks();
      await _pumpGithubDashboard(
        tester,
        frameworks: rows,
        history: _historyFromFrameworks(rows),
      );

      final Key topKey = const ValueKey<String>('gh-framework-top-filter');
      final Key metricKey = const ValueKey<String>(
        'gh-framework-metric-filter',
      );
      final Key orderKey = const ValueKey<String>('gh-framework-order-filter');
      final Key viewKey = const ValueKey<String>('gh-framework-view-filter');

      expect(find.byKey(topKey), findsOneWidget);
      expect(find.byKey(metricKey), findsOneWidget);
      expect(find.byKey(orderKey), findsOneWidget);
      expect(find.byKey(viewKey), findsOneWidget);

      await _openFilter(tester, topKey);
      await tester.tap(find.text('Top 3').last, warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await _openFilter(tester, metricKey);
      await tester.tap(find.text('Contributors').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(orderKey), findsNothing);
      expect(find.byKey(viewKey), findsNothing);
      expect(tester.takeException(), isNull);

      await _openFilter(tester, metricKey);
      await tester.tap(find.text('Commits').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(find.byKey(orderKey), findsOneWidget);
      expect(find.byKey(viewKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'github chart 2 hides growth order when no positive deltas exist',
    (WidgetTester tester) async {
      final List<FrameworkCommitModel> rows = _frameworks(
        nextDelta: 0,
        angularDelta: -20,
        reactDelta: -2,
        svelteDelta: 0,
        vueDelta: -1,
      );
      await _pumpGithubDashboard(
        tester,
        frameworks: rows,
        history: _historyFromFrameworks(rows),
      );

      final Key orderKey = const ValueKey<String>('gh-framework-order-filter');
      expect(find.byKey(orderKey), findsOneWidget);

      await _openFilter(tester, orderKey);

      expect(find.text('Mayor valor'), findsWidgets);
      expect(find.textContaining('Mayor ca'), findsWidgets);
      expect(find.text('Mayor crecimiento'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('github insights align one insight per graph', (
    WidgetTester tester,
  ) async {
    final List<FrameworkCommitModel> rows = _frameworks();
    await _pumpGithubDashboard(
      tester,
      frameworks: rows,
      history: _historyFromFrameworks(rows),
    );

    expect(
      find.text('Python lidera los repositorios nuevos en GitHub'),
      findsOneWidget,
    );
    expect(
      find.textContaining('322 repos nuevos, 34.8% del total del periodo'),
      findsOneWidget,
    );
    expect(
      find.textContaining('+82 vs TypeScript.'),
      findsOneWidget,
    );
    expect(
      find.text('Next.js lidera los commits frontend en GitHub'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        '5,000 commits en el periodo actual. +667 vs Angular.',
      ),
      findsOneWidget,
    );
    expect(
      find.text('next.js destaca por contributors por cada 1k stars'),
      findsOneWidget,
    );
    expect(
      find.text(
        '304 contributors, 128,000 stars, 0.0 contributors por cada 1k stars.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'github export zip ignores UI filters and keeps stable CSV names',
    (WidgetTester tester) async {
      final _FakeDownloadService downloadService = _FakeDownloadService();
      final List<FrameworkCommitModel> rows = _frameworks();
      await _pumpGithubDashboard(
        tester,
        frameworks: rows,
        history: _historyFromFrameworks(rows),
        downloadService: downloadService,
      );

      const Key topKey = ValueKey<String>('gh-framework-top-filter');
      await _openFilter(tester, topKey);
      await tester.tap(find.text('Top 3').last, warnIfMissed: false);
      await tester.pumpAndSettle();

      final Finder exportIcon = find.byIcon(Icons.folder_zip);
      expect(exportIcon, findsOneWidget);
      await tester.ensureVisible(exportIcon);
      await tester.tap(exportIcon, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(downloadService.fileName, 'github_datos_completos');
      expect(downloadService.zipBytes, isNotNull);

      final Archive archive = ZipDecoder().decodeBytes(
        downloadService.zipBytes!,
      );
      final List<String> fileNames = archive.files
          .map((ArchiveFile file) => file.name)
          .toList();

      expect(fileNames, contains('1_lenguajes_nuevos.csv'));
      expect(fileNames, contains('2_frameworks_frontend.csv'));
      expect(fileNames, contains('3_correlacion_stars_contributors.csv'));
      expect(fileNames.any((String name) => name.contains('top')), isFalse);

      final ArchiveFile lenguajesFile = archive.files.firstWhere(
        (ArchiveFile file) => file.name == '1_lenguajes_nuevos.csv',
      );
      final String csv = utf8.decode(lenguajesFile.content as List<int>);
      final List<String> lines = const LineSplitter().convert(csv);

      expect(lines.first, 'lenguaje,repositorios_nuevos,participacion_pct');
      expect(lines.length, 6);
      expect(lines, contains('Python,322,34.8'));
      expect(lines, contains('Rust,44,4.8'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('github dashboard stays stable on mobile, tablet and desktop', (
    WidgetTester tester,
  ) async {
    final List<Size> sizes = <Size>[
      const Size(390, 844),
      const Size(844, 390),
      const Size(768, 1024),
      const Size(1280, 900),
    ];

    for (final Size size in sizes) {
      await _pumpGithubDashboard(
        tester,
        frameworks: _frameworks(),
        history: _historyFromFrameworks(_frameworks()),
        size: size,
      );
      expect(find.text('Dashboard GitHub'), findsOneWidget);
      expect(find.textContaining('frameworks frontend'), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
}

