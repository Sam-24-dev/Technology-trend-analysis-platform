import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/home_highlights_models.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/models/trend_history_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/home_screen.dart';

void main() {
  testWidgets('home usa highlights globales canónicos del bridge', (
    WidgetTester tester,
  ) async {
    const List<Size> viewports = <Size>[
      Size(390, 844),
      Size(844, 390),
      Size(768, 1024),
      Size(1024, 768),
      Size(1400, 1800),
    ];

    bool loadedGithubDashboard = false;
    bool loadedStackOverflowDashboard = false;
    bool loadedRedditDashboard = false;

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final Size size in viewports) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeHighlightsProvider.overrideWith(
              (ref) async => DataLoadState.data(
                HomeHighlightsPayloadModel.fromMap({
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
                      'payload': {
                        'framework': 'Next.js',
                        'commits_2025': 5000,
                        'total_classifiable_repos': 2179,
                      },
                    },
                    {
                      'dashboard': 'stackoverflow',
                      'graph': 1,
                      'signal': 'leader',
                      'source': 'so_volumen_history.summary.leader',
                      'entity': 'python',
                      'entity_key': 'python',
                      'score': 234.22,
                      'payload': {
                        'lenguaje': 'python',
                        'preguntas': 10810,
                        'total_questions': 19848,
                        'share_pct': 31.53,
                      },
                    },
                    {
                      'dashboard': 'reddit',
                      'graph': 2,
                      'signal': 'leader_topic',
                      'source': 'reddit_temas_history.summary.leader_topic',
                      'entity': 'IA/Machine Learning',
                      'entity_key': 'iamachinelearning',
                      'score': 145.0,
                      'payload': {
                        'tema': 'IA/Machine Learning',
                        'menciones': 142,
                        'total_menciones': 2280,
                        'growth_pct': 0.71,
                        'trend_direction': 'creciendo',
                      },
                    },
                  ],
                }),
              ),
            ),
            trendTemporalProvider.overrideWith(
              (ref) async => DataLoadState.data(
                const TrendTemporalViewData(
                  source: 'bridge_json',
                  snapshotCount: 1,
                  items: <TrendTopEntry>[],
                ),
              ),
            ),
            githubDashboardProvider.overrideWith((ref) async {
              loadedGithubDashboard = true;
              return DataLoadState.error('github dashboard should be deferred');
            }),
            stackoverflowDashboardProvider.overrideWith((ref) async {
              loadedStackOverflowDashboard = true;
              return DataLoadState.error(
                'stackoverflow dashboard should be deferred',
              );
            }),
            redditDashboardProvider.overrideWith((ref) async {
              loadedRedditDashboard = true;
              return DataLoadState.error('reddit dashboard should be deferred');
            }),
            runManifestProvider.overrideWith(
              (ref) async => DataLoadState.data(
                const RunManifestPublic(
                  manifestVersion: '1.0.0',
                  generatedAtUtc: '2026-03-09T05:56:39Z',
                  sourceWindowStartUtc: '2025-03-01T00:00:00Z',
                  sourceWindowEndUtc: '2026-03-09T00:00:00Z',
                  qualityGateStatus: 'pass',
                  degradedMode: false,
                  availableSources: <String>[
                    'github',
                    'stackoverflow',
                    'reddit',
                  ],
                  datasetSummaries: <RunManifestDatasetSummary>[],
                  totalReposExtraidos: 0,
                  totalReposClasificables: 2179,
                  soLanguagesCount: 0,
                  notes: 'ok',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: HomeScreen())),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.text('Next.js lidera los commits frontend en GitHub'),
        findsOneWidget,
      );
      expect(
        find.text('Python lidera el volumen en StackOverflow'),
        findsOneWidget,
      );
      expect(
        find.text('AI/ML lidera la conversación en Reddit'),
        findsOneWidget,
      );
      expect(find.text('Python domina GitHub y StackOverflow'), findsNothing);
      final Finder descriptionFinder = find.textContaining(
        '10,810 preguntas nuevas',
      );
      expect(descriptionFinder, findsOneWidget);
      final Text descriptionText = tester.widget<Text>(descriptionFinder);
      expect(descriptionText.maxLines, isNull);
      expect(descriptionText.overflow, isNull);
      expect(find.text('2,179'), findsOneWidget);
      expect(find.text('19,848'), findsOneWidget);
      expect(find.text('2,280'), findsOneWidget);
      expect(loadedGithubDashboard, isFalse);
      expect(loadedStackOverflowDashboard, isFalse);
      expect(loadedRedditDashboard, isFalse);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected layout exception at viewport $size',
      );
    }
  });

  testWidgets('home does not load dashboard fallbacks while highlights load', (
    WidgetTester tester,
  ) async {
    final highlightsCompleter =
        Completer<DataLoadState<HomeHighlightsPayloadModel>>();
    bool loadedGithubDashboard = false;
    bool loadedStackOverflowDashboard = false;
    bool loadedRedditDashboard = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          homeHighlightsProvider.overrideWith(
            (ref) => highlightsCompleter.future,
          ),
          trendTemporalProvider.overrideWith(
            (ref) async => DataLoadState.data(
              const TrendTemporalViewData(
                source: 'bridge_json',
                snapshotCount: 1,
                items: <TrendTopEntry>[],
              ),
            ),
          ),
          githubDashboardProvider.overrideWith((ref) async {
            loadedGithubDashboard = true;
            return DataLoadState.error('github dashboard should wait');
          }),
          stackoverflowDashboardProvider.overrideWith((ref) async {
            loadedStackOverflowDashboard = true;
            return DataLoadState.error('stackoverflow dashboard should wait');
          }),
          redditDashboardProvider.overrideWith((ref) async {
            loadedRedditDashboard = true;
            return DataLoadState.error('reddit dashboard should wait');
          }),
          runManifestProvider.overrideWith(
            (ref) async => DataLoadState.data(
              const RunManifestPublic(
                manifestVersion: '1.0.0',
                generatedAtUtc: '2026-03-09T05:56:39Z',
                sourceWindowStartUtc: '2025-03-01T00:00:00Z',
                sourceWindowEndUtc: '2026-03-09T00:00:00Z',
                qualityGateStatus: 'pass',
                degradedMode: false,
                availableSources: <String>['github', 'stackoverflow', 'reddit'],
                datasetSummaries: <RunManifestDatasetSummary>[],
                totalReposExtraidos: 0,
                totalReposClasificables: 0,
                soLanguagesCount: 0,
                notes: 'ok',
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: SingleChildScrollView(child: HomeScreen())),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Insights no disponibles por ahora.'), findsOneWidget);
    expect(loadedGithubDashboard, isFalse);
    expect(loadedStackOverflowDashboard, isFalse);
    expect(loadedRedditDashboard, isFalse);
    expect(tester.takeException(), isNull);

    highlightsCompleter.complete(DataLoadState.error('no highlights'));
    await tester.pump();
  });

  testWidgets(
    'home keeps dashboard fallbacks deferred when totals are missing',
    (WidgetTester tester) async {
      bool loadedGithubDashboard = false;
      bool loadedStackOverflowDashboard = false;
      bool loadedRedditDashboard = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            homeHighlightsProvider.overrideWith(
              (ref) async => DataLoadState.data(
                HomeHighlightsPayloadModel.fromMap({
                  'generated_at_utc': '2026-03-09T05:56:39Z',
                  'dataset': 'home_highlights',
                  'source_mode': 'bridges',
                  'candidate_count': 3,
                  'highlights': [
                    {
                      'dashboard': 'github',
                      'graph': 2,
                      'signal': 'leader',
                      'entity': 'Next.js',
                      'entity_key': 'nextjs',
                      'score': 251.61,
                      'payload': {'framework': 'Next.js', 'commits_2025': 5000},
                    },
                    {
                      'dashboard': 'stackoverflow',
                      'graph': 1,
                      'signal': 'leader',
                      'entity': 'python',
                      'entity_key': 'python',
                      'score': 234.22,
                      'payload': {'lenguaje': 'python', 'preguntas': 10810},
                    },
                    {
                      'dashboard': 'reddit',
                      'graph': 2,
                      'signal': 'leader_topic',
                      'entity': 'IA/Machine Learning',
                      'entity_key': 'iamachinelearning',
                      'score': 145.0,
                      'payload': {
                        'tema': 'IA/Machine Learning',
                        'menciones': 142,
                      },
                    },
                  ],
                }),
              ),
            ),
            trendTemporalProvider.overrideWith(
              (ref) async => DataLoadState.data(
                const TrendTemporalViewData(
                  source: 'bridge_json',
                  snapshotCount: 1,
                  items: <TrendTopEntry>[],
                ),
              ),
            ),
            githubDashboardProvider.overrideWith((ref) async {
              loadedGithubDashboard = true;
              return DataLoadState.error('github dashboard should be deferred');
            }),
            stackoverflowDashboardProvider.overrideWith((ref) async {
              loadedStackOverflowDashboard = true;
              return DataLoadState.error(
                'stackoverflow dashboard should be deferred',
              );
            }),
            redditDashboardProvider.overrideWith((ref) async {
              loadedRedditDashboard = true;
              return DataLoadState.error('reddit dashboard should be deferred');
            }),
            runManifestProvider.overrideWith(
              (ref) async => DataLoadState.data(
                const RunManifestPublic(
                  manifestVersion: '1.0.0',
                  generatedAtUtc: '2026-03-09T05:56:39Z',
                  sourceWindowStartUtc: '2025-03-01T00:00:00Z',
                  sourceWindowEndUtc: '2026-03-09T00:00:00Z',
                  qualityGateStatus: 'pass',
                  degradedMode: false,
                  availableSources: <String>[
                    'github',
                    'stackoverflow',
                    'reddit',
                  ],
                  datasetSummaries: <RunManifestDatasetSummary>[],
                  totalReposExtraidos: 0,
                  totalReposClasificables: 0,
                  soLanguagesCount: 0,
                  notes: 'ok',
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SingleChildScrollView(child: HomeScreen())),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('--'), findsNWidgets(3));
      expect(loadedGithubDashboard, isFalse);
      expect(loadedStackOverflowDashboard, isFalse);
      expect(loadedRedditDashboard, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
