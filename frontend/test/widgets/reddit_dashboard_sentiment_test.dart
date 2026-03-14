import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/reddit_models.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/reddit_dashboard.dart';

void main() {
  RunManifestPublic _manifest() {
    return const RunManifestPublic(
      manifestVersion: '1.0.0',
      generatedAtUtc: '2026-02-27T05:11:00Z',
      sourceWindowStartUtc: '2025-02-27T00:00:00Z',
      sourceWindowEndUtc: '2026-02-27T00:00:00Z',
      qualityGateStatus: 'pass',
      degradedMode: false,
      availableSources: <String>['github', 'stackoverflow', 'reddit'],
      datasetSummaries: <RunManifestDatasetSummary>[],
      totalReposExtraidos: 0,
      totalReposClasificables: 0,
      soLanguagesCount: 0,
      notes: null,
    );
  }

  RedditDashboardData _dashboardData(
    List<SentimientoModel> sentimiento, {
    RedditSentimentSummaryModel? sentimientoSummary,
    List<TemasEmergentesModel>? temas,
    RedditTemasHistoryModel? temasHistory,
    RedditInterseccionHistoryModel? interseccionHistory,
  }) {
    return RedditDashboardData(
      sentimiento: sentimiento,
      sentimientoSummary: sentimientoSummary,
      temas:
          temas ??
          <TemasEmergentesModel>[
            TemasEmergentesModel(tema: 'ai_ml', menciones: 120),
          ],
      interseccion: <InterseccionModel>[
        InterseccionModel(
          tecnologia: 'python',
          rankingGitHub: 1,
          rankingReddit: 2,
        ),
      ],
      temasHistory: temasHistory,
      interseccionHistory: interseccionHistory,
    );
  }

  Future<void> _pumpRedditDashboard(
    WidgetTester tester, {
    required List<SentimientoModel> sentimiento,
    RedditSentimentSummaryModel? sentimientoSummary,
    List<TemasEmergentesModel>? temas,
    RedditTemasHistoryModel? temasHistory,
    RedditInterseccionHistoryModel? interseccionHistory,
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
          redditDashboardProvider.overrideWith((ref) async {
            return DataLoadState<RedditDashboardData>.data(
              _dashboardData(
                sentimiento,
                sentimientoSummary: sentimientoSummary,
                temas: temas,
                temasHistory: temasHistory,
                interseccionHistory: interseccionHistory,
              ),
            );
          }),
          runManifestProvider.overrideWith((ref) async {
            return DataLoadState<RunManifestPublic>.data(_manifest());
          }),
        ],
        child: const MaterialApp(home: RedditDashboard()),
      ),
    );

    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('warning copy removes Nota prefix for low sample frameworks', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 8,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
        SentimientoModel(
          framework: 'laravel',
          totalMenciones: 7,
          porcentajePositivo: 84.2,
          porcentajeNeutro: 0,
          porcentajeNegativo: 15.8,
        ),
        SentimientoModel(
          framework: 'spring',
          totalMenciones: 32,
          porcentajePositivo: 80.0,
          porcentajeNeutro: 5.0,
          porcentajeNegativo: 15.0,
        ),
      ],
    );

    expect(
      find.text('2 framework(s) tienen menos de 10 menciones.'),
      findsOneWidget,
    );
    expect(find.textContaining('Nota:'), findsNothing);
  });

  testWidgets('insights align 1:1 with reddit graph summaries', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 3,
          positivos: 3,
          porcentajePositivo: 100.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 0,
        ),
      ],
      sentimientoSummary: RedditSentimentSummaryModel(
        positiveLeader: SentimientoModel(
          framework: 'django',
          totalMenciones: 3,
          positivos: 3,
          porcentajePositivo: 100.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 0,
        ),
        largestSample: SentimientoModel(
          framework: 'laravel',
          totalMenciones: 21,
          positivos: 19,
          porcentajePositivo: 90.48,
          porcentajeNeutro: 0,
          porcentajeNegativo: 9.52,
        ),
      ),
      temas: const <TemasEmergentesModel>[
        TemasEmergentesModel(tema: 'ai_ml', menciones: 142),
      ],
      temasHistory: const RedditTemasHistoryModel(
        sourceMode: 'history',
        snapshotCount: 2,
        latestSnapshotDate: '2026-03-09',
        previousSnapshotDate: '2026-03-08',
        topicCount: 10,
        summary: RedditTemasSummaryModel(
          leaderTopic: TemasEmergentesModel(
            tema: 'IA/Machine Learning',
            menciones: 142,
            mencionesPrevias: 141,
            deltaMenciones: 1,
            growthPct: 0.71,
            trendDirection: 'creciendo',
          ),
        ),
        latestTopics: <TemasEmergentesModel>[
          TemasEmergentesModel(tema: 'ai_ml', menciones: 142),
        ],
      ),
      interseccionHistory: const RedditInterseccionHistoryModel(
        sourceMode: 'history',
        snapshotCount: 2,
        latestSnapshotDate: '2026-03-09',
        previousSnapshotDate: '2026-03-08',
        coveragePct: 30.0,
        comparableCount: 3,
        itemCount: 10,
        summary: RedditInterseccionSummaryModel(
          consensoCount: 0,
          divergenteCount: 3,
          comparableCount: 3,
          coveragePct: 30.0,
          maxBrechaTecnologia: 'TypeScript',
          maxBrechaAbs: 6,
          closestAlignment: RedditInterseccionHistoryItemModel(
            tecnologia: 'Python',
            tipo: 'Lenguaje',
            rankingGitHub: 1,
            rankingReddit: 5,
            brechaAbs: 4,
            promedioRank: 3.0,
            direccion: 'github_favorece',
            rankGithubPrev: 1,
            rankRedditPrev: 5,
            deltaGap: 0,
            trendDirection: 'estable',
          ),
        ),
        latestItems: <RedditInterseccionHistoryItemModel>[],
        snapshots: <RedditInterseccionSnapshotModel>[],
      ),
    );

    expect(
      find.text('AI/ML concentra el mayor volumen de menciones en Reddit'),
      findsOneWidget,
    );
    expect(
      find.text('142 menciones, var +1 vs 08/03/2026.'),
      findsOneWidget,
    );
    expect(
      find.text('Django registra el sentimiento más positivo en Reddit'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mayor muestra: Laravel (21).'),
      findsOneWidget,
    );
    expect(
      find.text('Python muestra la alineación más cercana entre plataformas'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Cobertura: 30.0% (3 tecnologías).'),
      findsOneWidget,
    );
  });

  testWidgets('filters handle larger dynamic framework datasets', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'alpha',
          totalMenciones: 12,
          porcentajePositivo: 95.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 5.0,
        ),
        SentimientoModel(
          framework: 'bravo',
          totalMenciones: 11,
          porcentajePositivo: 90.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 10.0,
        ),
        SentimientoModel(
          framework: 'charlie',
          totalMenciones: 10,
          porcentajePositivo: 88.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 12.0,
        ),
        SentimientoModel(
          framework: 'delta',
          totalMenciones: 30,
          porcentajePositivo: 70.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 30.0,
        ),
        SentimientoModel(
          framework: 'echo',
          totalMenciones: 40,
          porcentajePositivo: 65.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 35.0,
        ),
        SentimientoModel(
          framework: 'foxtrot',
          totalMenciones: 50,
          porcentajePositivo: 60.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 40.0,
        ),
        SentimientoModel(
          framework: 'golang',
          totalMenciones: 60,
          porcentajePositivo: 55.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 45.0,
        ),
      ],
    );

    expect(find.text('Ver todos'), findsAtLeastNWidgets(1));
    expect(find.text('Más positivo'), findsAtLeastNWidgets(1));

    await tester.tap(find.text('Ver todos').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top 3').last);
    await tester.pumpAndSettle();
    expect(find.text('Top 3'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Más positivo').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Más menciones').last);
    await tester.pumpAndSettle();

    expect(find.text('Más menciones'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('top filter hides redundant option when row count is 5', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'alpha',
          totalMenciones: 12,
          porcentajePositivo: 95.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 5.0,
        ),
        SentimientoModel(
          framework: 'bravo',
          totalMenciones: 11,
          porcentajePositivo: 90.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 10.0,
        ),
        SentimientoModel(
          framework: 'charlie',
          totalMenciones: 10,
          porcentajePositivo: 88.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 12.0,
        ),
        SentimientoModel(
          framework: 'delta',
          totalMenciones: 30,
          porcentajePositivo: 70.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 30.0,
        ),
        SentimientoModel(
          framework: 'echo',
          totalMenciones: 40,
          porcentajePositivo: 65.0,
          porcentajeNeutro: 0,
          porcentajeNegativo: 35.0,
        ),
      ],
    );

    await tester.tap(find.text('Ver todos').first);
    await tester.pumpAndSettle();

    expect(find.text('Top 3'), findsOneWidget);
    expect(find.text('Top 5'), findsNothing);
  });

  testWidgets('temas chart title reflects dynamic top count', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
      ],
      temas: <TemasEmergentesModel>[
        TemasEmergentesModel(tema: 'ai_ml', menciones: 120),
        TemasEmergentesModel(tema: 'performance', menciones: 66),
        TemasEmergentesModel(tema: 'cloud', menciones: 55),
        TemasEmergentesModel(tema: 'seguridad', menciones: 39),
        TemasEmergentesModel(tema: 'testing', menciones: 29),
        TemasEmergentesModel(tema: 'devops', menciones: 20),
      ],
    );

    expect(find.text('Top 6 temas emergentes'), findsOneWidget);

    Finder allDropdowns() =>
        find.byWidgetPredicate((widget) => widget is DropdownButton);
    final Finder temasTopDropdown = allDropdowns().at(2);
    await tester.ensureVisible(temasTopDropdown);
    await tester.pumpAndSettle();
    await tester.tap(temasTopDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Top 3').last);
    await tester.pumpAndSettle();

    expect(find.text('Top 3 temas emergentes'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('temas chart enables order filter when growth history exists', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
      ],
      temas: <TemasEmergentesModel>[
        TemasEmergentesModel(
          tema: 'ai_ml',
          menciones: 130,
          mencionesPrevias: 120,
          deltaMenciones: 10,
          growthPct: 8.33,
          trendDirection: 'creciendo',
        ),
        TemasEmergentesModel(
          tema: 'cloud',
          menciones: 35,
          mencionesPrevias: 40,
          deltaMenciones: -5,
          growthPct: -12.5,
          trendDirection: 'cayendo',
        ),
        TemasEmergentesModel(
          tema: 'testing',
          menciones: 20,
          mencionesPrevias: 20,
          deltaMenciones: 0,
          growthPct: 0.0,
          trendDirection: 'estable',
        ),
      ],
      temasHistory: const RedditTemasHistoryModel(
        sourceMode: 'history',
        snapshotCount: 2,
        latestSnapshotDate: '2026-03-03',
        previousSnapshotDate: '2026-02-27',
        topicCount: 3,
        latestTopics: <TemasEmergentesModel>[
          TemasEmergentesModel(
            tema: 'ai_ml',
            menciones: 130,
            mencionesPrevias: 120,
            deltaMenciones: 10,
            growthPct: 8.33,
            trendDirection: 'creciendo',
          ),
        ],
      ),
    );

    final Finder temasOrderDropdown = find.byKey(
      const ValueKey<String>('temas-orden-filter'),
    );
    await tester.ensureVisible(temasOrderDropdown);
    await tester.pumpAndSettle();
    await tester.tap(temasOrderDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mayor crecimiento').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Orden: mayor crecimiento'),
      findsAtLeastNWidgets(1),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('temas chart filters stay interactive after Top 3', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
        SentimientoModel(
          framework: 'laravel',
          totalMenciones: 18,
          porcentajePositivo: 84.2,
          porcentajeNeutro: 0,
          porcentajeNegativo: 15.8,
        ),
      ],
      temas: <TemasEmergentesModel>[
        TemasEmergentesModel(tema: 'ai_ml', menciones: 316),
        TemasEmergentesModel(tema: 'microservicios', menciones: 66),
        TemasEmergentesModel(tema: 'performance', menciones: 55),
        TemasEmergentesModel(tema: 'cloud', menciones: 39),
        TemasEmergentesModel(tema: 'seguridad', menciones: 29),
        TemasEmergentesModel(tema: 'testing', menciones: 26),
        TemasEmergentesModel(tema: 'python', menciones: 23),
        TemasEmergentesModel(tema: 'devops', menciones: 20),
      ],
    );

    Future<void> openDropdown(Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final Finder toggle = find.descendant(
        of: target,
        matching: find.byIcon(Icons.arrow_drop_down_rounded),
      );
      await tester.tap(toggle.first);
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(
      find.byKey(const ValueKey<String>('temas-top-filter')),
    );
    await tester.pumpAndSettle();

    await openDropdown(find.byKey(const ValueKey<String>('temas-top-filter')));
    await tester.tap(find.text('Top 3').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await openDropdown(
      find.byKey(const ValueKey<String>('temas-metrica-filter')),
    );
    await tester.tap(find.text('% participación').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await openDropdown(
      find.byKey(const ValueKey<String>('temas-metrica-filter')),
    );
    await tester.tap(find.text('Menciones').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('temas chart can switch between valor actual y variación', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
      ],
      temas: <TemasEmergentesModel>[
        TemasEmergentesModel(
          tema: 'ai_ml',
          menciones: 316,
          mencionesPrevias: 300,
          deltaMenciones: 16,
          growthPct: 5.33,
          trendDirection: 'creciendo',
        ),
        TemasEmergentesModel(
          tema: 'cloud',
          menciones: 39,
          mencionesPrevias: 43,
          deltaMenciones: -4,
          growthPct: -9.30,
          trendDirection: 'cayendo',
        ),
      ],
      temasHistory: const RedditTemasHistoryModel(
        sourceMode: 'history',
        snapshotCount: 2,
        latestSnapshotDate: '2026-03-04',
        previousSnapshotDate: '2026-03-03',
        topicCount: 2,
        latestTopics: <TemasEmergentesModel>[
          TemasEmergentesModel(
            tema: 'ai_ml',
            menciones: 316,
            mencionesPrevias: 300,
            deltaMenciones: 16,
            growthPct: 5.33,
            trendDirection: 'creciendo',
          ),
        ],
      ),
    );

    Future<void> openDropdown(Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      final Finder toggle = find.descendant(
        of: target,
        matching: find.byIcon(Icons.arrow_drop_down_rounded),
      );
      await tester.tap(toggle.first);
      await tester.pumpAndSettle();
    }

    await openDropdown(
      find.byKey(const ValueKey<String>('temas-vista-filter')),
    );
    await tester.tap(find.text('Variación').last);
    await tester.pumpAndSettle();

    await openDropdown(
      find.byKey(const ValueKey<String>('temas-orden-filter')),
    );
    await tester.tap(find.text('Mayor crecimiento').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('barras muestran variación'), findsOneWidget);

    await openDropdown(
      find.byKey(const ValueKey<String>('temas-vista-filter')),
    );
    await tester.tap(find.text('Valor actual').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('barras muestran valor actual'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reddit dashboard keeps stable layout on mobile portrait', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
      ],
      size: const Size(390, 844),
    );

    expect(find.byType(RedditDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reddit dashboard keeps stable layout on mobile landscape', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
      ],
      size: const Size(844, 390),
    );

    expect(find.byType(RedditDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reddit dashboard keeps stable layout on tablet portrait', (
    WidgetTester tester,
  ) async {
    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
      ],
      size: const Size(768, 1024),
    );

    expect(find.byType(RedditDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('interseccion pro filters stay interactive with history data', (
    WidgetTester tester,
  ) async {
    const RedditInterseccionHistoryModel history =
        RedditInterseccionHistoryModel(
          sourceMode: 'history',
          snapshotCount: 2,
          latestSnapshotDate: '2026-03-03',
          previousSnapshotDate: '2026-03-03',
          coveragePct: 62.5,
          comparableCount: 4,
          itemCount: 8,
          summary: RedditInterseccionSummaryModel(
            consensoCount: 0,
            divergenteCount: 4,
            maxBrechaTecnologia: 'TypeScript',
            maxBrechaAbs: 6,
          ),
          latestItems: <RedditInterseccionHistoryItemModel>[
            RedditInterseccionHistoryItemModel(
              tecnologia: 'Python',
              tipo: 'Lenguaje',
              rankingGitHub: 1,
              rankingReddit: 5,
              brechaAbs: 4,
              promedioRank: 3,
              direccion: 'github_favorece',
              rankGithubPrev: 1,
              rankRedditPrev: 6,
              deltaGap: -1,
              trendDirection: 'convergiendo',
            ),
            RedditInterseccionHistoryItemModel(
              tecnologia: 'TypeScript',
              tipo: 'Lenguaje',
              rankingGitHub: 2,
              rankingReddit: 8,
              brechaAbs: 6,
              promedioRank: 5,
              direccion: 'github_favorece',
              rankGithubPrev: 2,
              rankRedditPrev: 9,
              deltaGap: -1,
              trendDirection: 'convergiendo',
            ),
            RedditInterseccionHistoryItemModel(
              tecnologia: 'JavaScript',
              tipo: 'Lenguaje',
              rankingGitHub: 4,
              rankingReddit: 9,
              brechaAbs: 5,
              promedioRank: 6.5,
              direccion: 'github_favorece',
              rankGithubPrev: 4,
              rankRedditPrev: 9,
              deltaGap: 0,
              trendDirection: 'estable',
            ),
            RedditInterseccionHistoryItemModel(
              tecnologia: 'Go',
              tipo: 'Lenguaje',
              rankingGitHub: 5,
              rankingReddit: 7,
              brechaAbs: 2,
              promedioRank: 6,
              direccion: 'github_favorece',
              rankGithubPrev: 5,
              rankRedditPrev: 6,
              deltaGap: 1,
              trendDirection: 'divergiendo',
            ),
          ],
          snapshots: <RedditInterseccionSnapshotModel>[],
        );

    await _pumpRedditDashboard(
      tester,
      sentimiento: <SentimientoModel>[
        SentimientoModel(
          framework: 'django',
          totalMenciones: 22,
          porcentajePositivo: 88.9,
          porcentajeNeutro: 0,
          porcentajeNegativo: 11.1,
        ),
      ],
      interseccionHistory: history,
    );

    Future<void> openDropdown(Finder target) async {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      await tester.tap(target);
      await tester.pumpAndSettle();
    }

    await tester.ensureVisible(find.byType(RedditDashboard));
    await tester.pumpAndSettle();

    await openDropdown(
      find.byKey(const ValueKey<String>('interseccion-top-filter')),
    );
    await tester.tap(find.text('Top 3').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await openDropdown(
      find.byKey(const ValueKey<String>('interseccion-vista-filter')),
    );
    await tester.tap(find.text('Mayor consenso').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await openDropdown(
      find.byKey(const ValueKey<String>('interseccion-vista-filter')),
    );
    await tester.tap(find.text('Promedio rank').last);
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('interseccion-detalle-filter')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });
}
