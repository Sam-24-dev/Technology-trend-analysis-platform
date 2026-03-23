import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/models/stackoverflow_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/stackoverflow_dashboard.dart';

void main() {
  RunManifestPublic manifest() {
    return const RunManifestPublic(
      manifestVersion: '1.0.0',
      generatedAtUtc: '2026-03-07T06:30:00Z',
      sourceWindowStartUtc: '2025-03-01T00:00:00Z',
      sourceWindowEndUtc: '2026-03-07T00:00:00Z',
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

  StackOverflowVolumeHistoryModel historyWithComparison() {
    return StackOverflowVolumeHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-07',
      'previous_snapshot_date': '2026-03-06',
      'has_historical_comparison': true,
      'item_count': 10,
      'summary': {
        'leader': {
          'lenguaje': 'python',
          'preguntas': 10879,
          'preguntas_prev': 10975,
          'delta_preguntas': -96,
          'growth_pct': -0.87,
          'trend_direction': 'cayendo',
          'share_pct': 30.0,
        },
        'highest_growth': {
          'lenguaje': 'ruby',
          'preguntas': 211,
          'preguntas_prev': 208,
          'delta_preguntas': 3,
          'growth_pct': 1.44,
          'trend_direction': 'creciendo',
          'share_pct': 0.6,
        },
        'largest_drop': {
          'lenguaje': 'python',
          'preguntas': 10879,
          'preguntas_prev': 10975,
          'delta_preguntas': -96,
          'growth_pct': -0.87,
          'trend_direction': 'cayendo',
          'share_pct': 30.0,
        },
        'total_questions': 34588,
      },
      'latest_items': [
        {
          'lenguaje': 'python',
          'preguntas': 10879,
          'preguntas_prev': 10975,
          'delta_preguntas': -96,
          'growth_pct': -0.87,
          'trend_direction': 'cayendo',
          'share_pct': 30.0,
        },
        {
          'lenguaje': 'javascript',
          'preguntas': 4755,
          'preguntas_prev': 4811,
          'delta_preguntas': -56,
          'growth_pct': -1.16,
          'trend_direction': 'cayendo',
          'share_pct': 13.1,
        },
        {
          'lenguaje': 'java',
          'preguntas': 4601,
          'preguntas_prev': 4648,
          'delta_preguntas': -47,
          'growth_pct': -1.01,
          'trend_direction': 'cayendo',
          'share_pct': 12.8,
        },
        {
          'lenguaje': 'c#',
          'preguntas': 4545,
          'preguntas_prev': 0,
          'delta_preguntas': 4545,
          'growth_pct': 0.0,
          'trend_direction': 'creciendo',
          'share_pct': 12.6,
        },
        {
          'lenguaje': 'c++',
          'preguntas': 3865,
          'preguntas_prev': 0,
          'delta_preguntas': 3865,
          'growth_pct': 0.0,
          'trend_direction': 'creciendo',
          'share_pct': 10.7,
        },
        {
          'lenguaje': 'typescript',
          'preguntas': 2272,
          'preguntas_prev': 2293,
          'delta_preguntas': -21,
          'growth_pct': -0.92,
          'trend_direction': 'cayendo',
          'share_pct': 6.3,
        },
        {
          'lenguaje': 'php',
          'preguntas': 1556,
          'preguntas_prev': 1568,
          'delta_preguntas': -12,
          'growth_pct': -0.77,
          'trend_direction': 'cayendo',
          'share_pct': 4.3,
        },
        {
          'lenguaje': 'kotlin',
          'preguntas': 1422,
          'preguntas_prev': 1421,
          'delta_preguntas': 1,
          'growth_pct': 0.07,
          'trend_direction': 'creciendo',
          'share_pct': 3.9,
        },
        {
          'lenguaje': 'go',
          'preguntas': 482,
          'preguntas_prev': 482,
          'delta_preguntas': 0,
          'growth_pct': 0.0,
          'trend_direction': 'estable',
          'share_pct': 1.3,
        },
        {
          'lenguaje': 'ruby',
          'preguntas': 211,
          'preguntas_prev': 208,
          'delta_preguntas': 3,
          'growth_pct': 1.44,
          'trend_direction': 'creciendo',
          'share_pct': 0.6,
        },
      ],
      'snapshots': [],
    });
  }

  StackOverflowVolumeHistoryModel historyCurrentOnly() {
    return StackOverflowVolumeHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 1,
      'latest_snapshot_date': '2026-03-07',
      'previous_snapshot_date': null,
      'has_historical_comparison': false,
      'item_count': 3,
      'summary': {
        'leader': {
          'lenguaje': 'javascript',
          'preguntas': 120,
          'preguntas_prev': 0,
          'delta_preguntas': 0,
          'growth_pct': 0.0,
          'trend_direction': 'estable',
          'share_pct': 42.9,
        },
        'highest_growth': null,
        'largest_drop': null,
        'total_questions': 280,
      },
      'latest_items': [
        {
          'lenguaje': 'javascript',
          'preguntas': 120,
          'preguntas_prev': 0,
          'delta_preguntas': 0,
          'growth_pct': 0.0,
          'trend_direction': 'estable',
          'share_pct': 42.9,
        },
        {
          'lenguaje': 'java',
          'preguntas': 90,
          'preguntas_prev': 0,
          'delta_preguntas': 0,
          'growth_pct': 0.0,
          'trend_direction': 'estable',
          'share_pct': 32.1,
        },
        {
          'lenguaje': 'go',
          'preguntas': 70,
          'preguntas_prev': 0,
          'delta_preguntas': 0,
          'growth_pct': 0.0,
          'trend_direction': 'estable',
          'share_pct': 25.0,
        },
      ],
      'snapshots': [],
    });
  }

  StackOverflowVolumeHistoryModel historyWithNonContiguousDates() {
    return StackOverflowVolumeHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-22',
      'previous_snapshot_date': '2026-03-19',
      'has_historical_comparison': true,
      'item_count': 2,
      'summary': {
        'leader': {
          'lenguaje': 'python',
          'preguntas': 120,
          'preguntas_prev': 100,
          'delta_preguntas': 20,
          'growth_pct': 20.0,
          'trend_direction': 'creciendo',
          'share_pct': 54.5,
        },
        'highest_growth': {
          'lenguaje': 'python',
          'preguntas': 120,
          'preguntas_prev': 100,
          'delta_preguntas': 20,
          'growth_pct': 20.0,
          'trend_direction': 'creciendo',
          'share_pct': 54.5,
        },
        'largest_drop': {
          'lenguaje': 'java',
          'preguntas': 100,
          'preguntas_prev': 110,
          'delta_preguntas': -10,
          'growth_pct': -9.09,
          'trend_direction': 'cayendo',
          'share_pct': 45.5,
        },
        'total_questions': 220,
      },
      'latest_items': [
        {
          'lenguaje': 'python',
          'preguntas': 120,
          'preguntas_prev': 100,
          'delta_preguntas': 20,
          'growth_pct': 20.0,
          'trend_direction': 'creciendo',
          'share_pct': 54.5,
        },
        {
          'lenguaje': 'java',
          'preguntas': 100,
          'preguntas_prev': 110,
          'delta_preguntas': -10,
          'growth_pct': -9.09,
          'trend_direction': 'cayendo',
          'share_pct': 45.5,
        },
      ],
      'snapshots': [],
    });
  }

  StackOverflowDashboardData dashboardData(
    StackOverflowVolumeHistoryModel history,
  ) {
    return StackOverflowDashboardData(
      volumen: history.latestItems,
      aceptacion: const <TasaAceptacionModel>[
        TasaAceptacionModel(
          tecnologia: 'reactjs',
          tasaPct: 36.4,
          totalPreguntas: 200,
        ),
      ],
      tendencias: const <TendenciaMensualModel>[
        TendenciaMensualModel(
          mes: '2026-02',
          python: 50,
          javascript: 60,
          typescript: 30,
        ),
        TendenciaMensualModel(
          mes: '2026-03',
          python: 40,
          javascript: 48,
          typescript: 22,
        ),
      ],
      volumenHistory: history,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required StackOverflowVolumeHistoryModel history,
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
          stackoverflowDashboardProvider.overrideWith((ref) async {
            return DataLoadState<StackOverflowDashboardData>.data(
              dashboardData(history),
            );
          }),
          runManifestProvider.overrideWith((ref) async {
            return DataLoadState<RunManifestPublic>.data(manifest());
          }),
        ],
        child: const MaterialApp(home: StackOverflowDashboard()),
      ),
    );

    await tester.pumpAndSettle();
  }

  String firstVolumeTooltipText(WidgetTester tester) {
    final BarChart chart = tester.widget<BarChart>(find.byType(BarChart).first);
    final BarChartData data = chart.data;
    final BarTouchTooltipData tooltipData = data.barTouchData.touchTooltipData;
    final BarTooltipItem? item = tooltipData.getTooltipItem(
      data.barGroups.first,
      0,
      data.barGroups.first.barRods.first,
      0,
    );
    expect(item, isNotNull);
    return item!.text;
  }

  testWidgets(
    'graph 1 historical mode uses dynamic top metric and comparable variation only',
    (WidgetTester tester) async {
      await pumpDashboard(tester, history: historyWithComparison());
      expect(tester.takeException(), isNull);
      expect(find.text('Ver todos'), findsOneWidget);
      await tester.ensureVisible(find.text('Ver todos').first);
      await tester.tap(find.text('Ver todos').first);
      await tester.pumpAndSettle();
      expect(find.text('Top 5'), findsOneWidget);
      expect(find.text('Top 8'), findsOneWidget);
      expect(find.text('Top 10'), findsNothing);
      await tester.tap(find.text('Top 8').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Top: Top 8'), findsOneWidget);
      const Key topKey = ValueKey<String>('so-volume-top-filter');
      const Key sortKey = ValueKey<String>('so-volume-sort-filter');
      const Key metricKey = ValueKey<String>('so-volume-metric-filter');
      final RenderBox topFilter = tester.renderObject<RenderBox>(
        find.byKey(topKey),
      );
      final RenderBox metricFilter = tester.renderObject<RenderBox>(
        find.byKey(metricKey),
      );
      expect(topFilter.size.height, lessThan(44));
      expect(metricFilter.size.height, lessThan(44));
      expect(find.byKey(sortKey), findsNothing);

      await tester.tap(find.text('Preguntas nuevas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('% participación').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Métrica: % participación'), findsOneWidget);
      expect(find.byKey(sortKey), findsNothing);

      await tester.tap(find.text('% participación').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Variación').last);
      await tester.pumpAndSettle();

      expect(find.textContaining('Métrica: Variación'), findsOneWidget);
      expect(find.byKey(sortKey), findsOneWidget);
      final RenderBox sortFilter = tester.renderObject<RenderBox>(
        find.byKey(sortKey),
      );
      expect(sortFilter.size.height, lessThan(44));
      expect(find.text('C#'), findsNothing);
      expect(find.text('C++'), findsNothing);

      await tester.tap(find.text('Ver todos').first);
      await tester.pumpAndSettle();
      expect(find.text('Top 5'), findsOneWidget);
      expect(find.text('Top 8'), findsNothing);
      expect(find.text('Top 10'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'graph 1 current-only mode hides top and variation options cleanly',
    (WidgetTester tester) async {
      await pumpDashboard(
        tester,
        history: historyCurrentOnly(),
        size: const Size(390, 844),
      );

      expect(
        find.text('JavaScript lidera el volumen en StackOverflow'),
        findsOneWidget,
      );
      expect(
        find.textContaining(
          '120 preguntas nuevas, 42.9% del total.',
        ),
        findsOneWidget,
      );
      expect(find.text('Snapshot actual (UTC): 07/03/2026'), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('so-volume-top-filter')),
        findsNothing,
      );
      expect(find.text('Variación'), findsNothing);
      expect(find.textContaining('Líder: JavaScript (120)'), findsOneWidget);

      await tester.ensureVisible(find.text('Preguntas nuevas').first);
      await tester.tap(find.text('Preguntas nuevas').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('% participación').last);
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Mayor participación: JavaScript (42.9%)'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('graph 1 tooltip follows only the active metric', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, history: historyWithComparison());

    final String questionsTooltip = firstVolumeTooltipText(tester);
    expect(questionsTooltip, contains('Preguntas nuevas:'));
    expect(questionsTooltip, isNot(contains('Actual:')));
    expect(questionsTooltip, isNot(contains('Anterior:')));
    expect(questionsTooltip, isNot(contains('Participacion:')));
    expect(questionsTooltip, isNot(contains('% participación:')));
    expect(questionsTooltip, isNot(contains('Variación:')));
    expect(questionsTooltip, isNot(contains('% de variacion:')));

    await tester.tap(find.text('Preguntas nuevas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('% participación').last);
    await tester.pumpAndSettle();

    final String shareTooltip = firstVolumeTooltipText(tester);
    expect(shareTooltip, contains('% participación:'));
    expect(shareTooltip, isNot(contains('Preguntas nuevas:')));
    expect(shareTooltip, isNot(contains('Actual:')));
    expect(shareTooltip, isNot(contains('Anterior:')));
    expect(shareTooltip, isNot(contains('Variación:')));
    expect(shareTooltip, isNot(contains('% de variación:')));

    await tester.tap(find.text('% participación').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Variación').last);
    await tester.pumpAndSettle();

    final String variationTooltip = firstVolumeTooltipText(tester);
    expect(variationTooltip, contains('Variación:'));
    expect(variationTooltip, contains('% de variación:'));
    expect(variationTooltip, isNot(contains('Preguntas nuevas:')));
    expect(variationTooltip, isNot(contains('% participación:')));
    expect(variationTooltip, isNot(contains('Actual:')));
    expect(variationTooltip, isNot(contains('Anterior:')));
  });

  testWidgets('graph 1 badges follow only the active metric', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester, history: historyWithComparison());

    expect(find.textContaining('Líder: Python (10,879)'), findsOneWidget);
    expect(find.textContaining('Mayor particip'), findsNothing);
    expect(find.textContaining('Mayor crec'), findsNothing);
    expect(find.textContaining('Mayor caída:'), findsNothing);

    await tester.tap(find.text('Preguntas nuevas').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('% participación').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Mayor participación: Python (30.0%)'),
      findsOneWidget,
    );
    expect(find.textContaining('Líder:'), findsNothing);
    expect(find.textContaining('Mayor crec'), findsNothing);
    expect(find.textContaining('Mayor caída:'), findsNothing);

    await tester.tap(find.text('% participación').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Variación').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Líder:'), findsNothing);
    expect(find.textContaining('Mayor particip'), findsNothing);
    expect(find.textContaining('Mayor crecimiento: Ruby (+3)'), findsOneWidget);
    expect(find.textContaining('Mayor caída: Python (-96)'), findsOneWidget);
  });

  testWidgets('graph 1 subtitle hides missing snapshot note', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      history: historyWithNonContiguousDates(),
      size: const Size(390, 844),
    );

    expect(
      find.textContaining('Comparado (UTC): 19/03/2026 -> 22/03/2026'),
      findsOneWidget,
    );
    expect(find.textContaining('faltan'), findsNothing);
    expect(find.textContaining('falta snapshot'), findsNothing);
  });

  testWidgets('graph 1 stays stable across responsive breakpoints', (
    WidgetTester tester,
  ) async {
    final List<Size> sizes = <Size>[
      const Size(390, 844),
      const Size(844, 390),
      const Size(768, 1024),
      const Size(1024, 768),
      const Size(1280, 900),
    ];

    for (final Size size in sizes) {
      await pumpDashboard(tester, history: historyWithComparison(), size: size);
      expect(find.byType(StackOverflowDashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
