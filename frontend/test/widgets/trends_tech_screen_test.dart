import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/github_models.dart';
import 'package:frontend/models/reddit_models.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/models/stackoverflow_models.dart';
import 'package:frontend/models/technology_profile_models.dart';
import 'package:frontend/models/trend_history_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/trends_tech_screen.dart';
import 'package:frontend/widgets/degraded_state_card.dart';

void main() {
  RunManifestPublic _manifest({bool degraded = false}) {
    return RunManifestPublic(
      manifestVersion: '1.0.0',
      generatedAtUtc: '2026-03-10T00:00:00Z',
      sourceWindowStartUtc: '2025-03-10T00:00:00Z',
      sourceWindowEndUtc: '2026-03-10T00:00:00Z',
      qualityGateStatus: 'pass',
      degradedMode: degraded,
      availableSources: const <String>['github', 'stackoverflow', 'reddit'],
      datasetSummaries: const <RunManifestDatasetSummary>[],
      totalReposExtraidos: 0,
      totalReposClasificables: 0,
      soLanguagesCount: 0,
      notes: null,
    );
  }

  TechnologyProfile _profile({
    required String slug,
    required String displayName,
    bool redditAvailable = true,
  }) {
    return TechnologyProfile(
      slug: slug,
      displayName: displayName,
      trendScoreActual: 80.0,
      trendScorePrev: 78.0,
      deltaScore: 2.0,
      rankingActual: 1,
      rankingPrev: 2,
      deltaRanking: 1,
      sourcesPresent:
          redditAvailable
              ? const <String>['github', 'stackoverflow', 'reddit']
              : const <String>['github', 'stackoverflow'],
      githubSummary: const TechnologySourceSummary(
        source: 'github',
        displayName: 'GitHub',
        available: true,
        scoreActual: 50.0,
        scorePrev: 48.0,
        deltaScore: 2.0,
      ),
      stackoverflowSummary: const TechnologySourceSummary(
        source: 'stackoverflow',
        displayName: 'StackOverflow',
        available: true,
        scoreActual: 20.0,
        scorePrev: 19.0,
        deltaScore: 1.0,
      ),
      redditSummary: TechnologySourceSummary(
        source: 'reddit',
        displayName: 'Reddit',
        available: redditAvailable,
        scoreActual: redditAvailable ? 10.0 : 0.0,
        scorePrev: redditAvailable ? 9.0 : 0.0,
        deltaScore: redditAvailable ? 1.0 : 0.0,
      ),
      sourceHistory: <TechnologySourceHistoryPoint>[
        TechnologySourceHistoryPoint(
          date: '2026-03-09',
          trendScore: 78.0,
          githubScore: 48.0,
          stackOverflowScore: 19.0,
          redditScore: redditAvailable ? 9.0 : 0.0,
          ranking: 2,
          fuentes: redditAvailable ? 3 : 2,
          availableSourceCodes:
              redditAvailable
                  ? const <String>['GH', 'SO', 'RD']
                  : const <String>['GH', 'SO'],
        ),
        TechnologySourceHistoryPoint(
          date: '2026-03-10',
          trendScore: 80.0,
          githubScore: 50.0,
          stackOverflowScore: 20.0,
          redditScore: redditAvailable ? 10.0 : 0.0,
          ranking: 1,
          fuentes: redditAvailable ? 3 : 2,
          availableSourceCodes:
              redditAvailable
                  ? const <String>['GH', 'SO', 'RD']
                  : const <String>['GH', 'SO'],
        ),
      ],
      summaryInsights: TechnologySummaryInsights(
        dominantSource: const TechnologyDominantSourceInsight(
          source: 'github',
          displayName: 'GitHub',
          score: 50.0,
          label: 'GitHub aporta la mayor parte del score actual.',
        ),
        coverage: TechnologyCoverageInsight(
          sourceCount: redditAvailable ? 3 : 2,
          sourcesPresent:
              redditAvailable
                  ? const <String>['github', 'stackoverflow', 'reddit']
                  : const <String>['github', 'stackoverflow'],
          label:
              redditAvailable
                  ? 'SeÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±al combinada en GitHub, StackOverflow y Reddit.'
                  : 'SeÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â±al disponible en GitHub y StackOverflow.',
        ),
        momentum: const TechnologyMomentumInsight(
          rankingActual: 1,
          rankingPrev: 2,
          deltaRanking: 1,
          scoreActual: 80.0,
          scorePrev: 78.0,
          label: 'Python sube 1 posiciÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â³n frente a la corrida previa.',
        ),
      ),
    );
  }

  TechnologyProfilesPayload _profilesPayload(TechnologyProfile profile) {
    return TechnologyProfilesPayload(
      dataset: 'technology_profiles',
      generatedAtUtc: '2026-03-10T00:00:00Z',
      sourceMode: 'trend_score_history',
      latestSnapshotDate: '2026-03-10',
      previousSnapshotDate: '2026-03-09',
      profileCount: 1,
      profiles: <TechnologyProfile>[profile],
    );
  }

  GithubDashboardData _githubData() {
    return GithubDashboardData(
      lenguajes: <LenguajeModel>[
        LenguajeModel(lenguaje: 'Python', reposCount: 200, porcentaje: 30.0),
      ],
      frameworks: <FrameworkCommitModel>[],
      correlacion: <CorrelacionModel>[],
    );
  }

  StackOverflowDashboardData _stackData() {
    return const StackOverflowDashboardData(
      volumen: <VolumenPreguntasModel>[
        VolumenPreguntasModel(lenguaje: 'python', preguntas: 120),
      ],
      aceptacion: <TasaAceptacionModel>[],
      tendencias: <TendenciaMensualModel>[],
    );
  }

  RedditDashboardData _redditData() {
    return RedditDashboardData(
      sentimiento: <SentimientoModel>[],
      temas: const <TemasEmergentesModel>[
        TemasEmergentesModel(tema: 'AI/ML', menciones: 120),
      ],
      interseccion: <InterseccionModel>[
        InterseccionModel(
          tecnologia: 'Python',
          rankingGitHub: 1,
          rankingReddit: 2,
        ),
      ],
    );
  }

  TrendTemporalViewData _trendView() {
    return const TrendTemporalViewData(
      source: 'bridge_json',
      snapshotCount: 1,
      items: <TrendTopEntry>[
        TrendTopEntry(
          ranking: 1,
          slug: 'python',
          tecnologia: 'Python',
          trendScore: 80.0,
          fuentes: 3,
          githubScore: 50.0,
          stackOverflowScore: 20.0,
          redditScore: 10.0,
          scorePrev: 78.0,
          deltaScore: 2.0,
          rankingPrev: 2,
          deltaRanking: 1,
          availableSources: <String>['GH', 'SO', 'RD'],
        ),
      ],
      latestSnapshotDate: '2026-03-10',
      previousSnapshotDate: '2026-03-09',
    );
  }

  Future<void> _pumpTrendsTech(
    WidgetTester tester, {
    required DataLoadState<TechnologyProfilesPayload> profilesState,
    String technology = 'python',
    Size size = const Size(1280, 900),
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
          technologyProfilesProvider.overrideWith((ref) async => profilesState),
          githubDashboardProvider.overrideWith(
            (ref) async => DataLoadState<GithubDashboardData>.data(_githubData()),
          ),
          stackoverflowDashboardProvider.overrideWith(
            (ref) async =>
                DataLoadState<StackOverflowDashboardData>.data(_stackData()),
          ),
          redditDashboardProvider.overrideWith(
            (ref) async => DataLoadState<RedditDashboardData>.data(_redditData()),
          ),
          trendTemporalProvider.overrideWith(
            (ref) async =>
                DataLoadState<TrendTemporalViewData>.data(_trendView()),
          ),
          runManifestProvider.overrideWith(
            (ref) async => DataLoadState<RunManifestPublic>.data(_manifest()),
          ),
        ],
        child: MaterialApp(
          home: TrendsTechScreen(technology: technology),
        ),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('trends tech renders bridge view with history chart', (
    WidgetTester tester,
  ) async {
    final profile = _profile(slug: 'python', displayName: 'Python');
    const List<Size> viewports = <Size>[
      Size(390, 844),
      Size(844, 390),
      Size(768, 1024),
      Size(1024, 768),
      Size(1280, 900),
    ];

    for (final Size size in viewports) {
      await _pumpTrendsTech(
        tester,
        profilesState: DataLoadState.data(_profilesPayload(profile)),
        size: size,
      );

      expect(find.textContaining('aporte por fuente'), findsOneWidget);
      expect(find.text('Hallazgos principales'), findsOneWidget);
      expect(find.text('PUNTAJE DE TENDENCIA'), findsOneWidget);
      final Finder insightFinder = find.text(
        'GitHub aporta la mayor parte del score actual.',
      );
      expect(insightFinder, findsOneWidget);
      final Text insightText = tester.widget<Text>(insightFinder);
      expect(insightText.maxLines, isNull);
      expect(insightText.overflow, isNull);
      expect(find.byType(DegradedStateCard), findsNothing);
      expect(find.textContaining('Bridge no disponible'), findsNothing);
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected layout exception at viewport $size',
      );
    }
  });
  testWidgets('trends tech shows legacy warning when bridge fails', (
    WidgetTester tester,
  ) async {
    await _pumpTrendsTech(
      tester,
      profilesState: DataLoadState.error('technology profiles load failed'),
    );

    expect(find.byType(DegradedStateCard), findsOneWidget);
    expect(find.textContaining('Bridge no disponible'), findsOneWidget);
    expect(
      find.textContaining('aporte por fuente'),
      findsOneWidget,
    );
  });

  testWidgets('trends tech marks missing source as unavailable', (
    WidgetTester tester,
  ) async {
    final profile = _profile(
      slug: 'python',
      displayName: 'Python',
      redditAvailable: false,
    );
    await _pumpTrendsTech(
      tester,
      profilesState: DataLoadState.data(_profilesPayload(profile)),
    );

    expect(find.text('No disponible'), findsOneWidget);
    expect(find.text('Fuente no disponible en esta corrida.'), findsOneWidget);
  });

  testWidgets('trends tech resolves special slug casing', (
    WidgetTester tester,
  ) async {
    final profile = _profile(slug: 'c-plus-plus', displayName: 'C++');
    await _pumpTrendsTech(
      tester,
      profilesState: DataLoadState.data(_profilesPayload(profile)),
      technology: 'c++',
    );

    expect(find.text('C++'), findsWidgets);
  });
}
