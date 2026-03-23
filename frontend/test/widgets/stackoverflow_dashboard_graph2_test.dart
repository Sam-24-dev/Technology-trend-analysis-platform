import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/models/stackoverflow_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/stackoverflow_dashboard.dart';
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
  RunManifestPublic manifest() {
    return const RunManifestPublic(
      manifestVersion: '1.0.0',
      generatedAtUtc: '2026-03-08T05:10:00Z',
      sourceWindowStartUtc: '2025-03-01T00:00:00Z',
      sourceWindowEndUtc: '2026-03-08T00:00:00Z',
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

  StackOverflowVolumeHistoryModel volumeHistory() {
    return StackOverflowVolumeHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-08',
      'previous_snapshot_date': '2026-03-07',
      'has_historical_comparison': true,
      'item_count': 3,
      'summary': {
        'leader': {
          'lenguaje': 'python',
          'preguntas': 10840,
          'preguntas_prev': 10879,
          'delta_preguntas': -39,
          'growth_pct': -0.36,
          'trend_direction': 'cayendo',
          'share_pct': 31.5,
        },
        'highest_growth': null,
        'largest_drop': {
          'lenguaje': 'python',
          'preguntas': 10840,
          'preguntas_prev': 10879,
          'delta_preguntas': -39,
          'growth_pct': -0.36,
          'trend_direction': 'cayendo',
          'share_pct': 31.5,
        },
        'total_questions': 34400,
      },
      'latest_items': [
        {
          'lenguaje': 'python',
          'preguntas': 10840,
          'preguntas_prev': 10879,
          'delta_preguntas': -39,
          'growth_pct': -0.36,
          'trend_direction': 'cayendo',
          'share_pct': 31.5,
        },
        {
          'lenguaje': 'javascript',
          'preguntas': 4700,
          'preguntas_prev': 4755,
          'delta_preguntas': -55,
          'growth_pct': -1.16,
          'trend_direction': 'cayendo',
          'share_pct': 13.7,
        },
        {
          'lenguaje': 'java',
          'preguntas': 4580,
          'preguntas_prev': 4601,
          'delta_preguntas': -21,
          'growth_pct': -0.46,
          'trend_direction': 'cayendo',
          'share_pct': 13.3,
        },
      ],
      'snapshots': [],
    });
  }

  StackOverflowAcceptanceHistoryModel acceptanceHistoryWithComparison() {
    return StackOverflowAcceptanceHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-08',
      'previous_snapshot_date': '2026-03-07',
      'has_historical_comparison': true,
      'item_count': 5,
      'summary': {
        'raw_leader': {
          'tecnologia': 'svelte',
          'total_preguntas': 150,
          'respuestas_aceptadas': 54,
          'tasa_aceptacion_pct': 36.0,
          'total_preguntas_prev': 151,
          'respuestas_aceptadas_prev': 55,
          'tasa_aceptacion_prev_pct': 36.42,
          'delta_tasa_pct': -0.42,
          'delta_preguntas': -1,
          'sample_bucket': 'baja',
          'confidence_score': 0.287565,
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
          'tasa_aceptacion_prev_pct': 36.42,
          'delta_tasa_pct': -0.42,
          'delta_preguntas': -1,
          'sample_bucket': 'baja',
          'confidence_score': 0.287565,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        'highest_improvement': {
          'tecnologia': 'reactjs',
          'total_preguntas': 2387,
          'respuestas_aceptadas': 576,
          'tasa_aceptacion_pct': 24.13,
          'total_preguntas_prev': 2402,
          'respuestas_aceptadas_prev': 579,
          'tasa_aceptacion_prev_pct': 24.10,
          'delta_tasa_pct': 0.03,
          'delta_preguntas': -15,
          'sample_bucket': 'alta',
          'confidence_score': 0.224566,
          'raw_rank': 4,
          'confidence_rank': 3,
        },
        'largest_drop': {
          'tecnologia': 'svelte',
          'total_preguntas': 150,
          'respuestas_aceptadas': 54,
          'tasa_aceptacion_pct': 36.0,
          'total_preguntas_prev': 151,
          'respuestas_aceptadas_prev': 55,
          'tasa_aceptacion_prev_pct': 36.42,
          'delta_tasa_pct': -0.42,
          'delta_preguntas': -1,
          'sample_bucket': 'baja',
          'confidence_score': 0.287565,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        'largest_sample': {
          'tecnologia': 'reactjs',
          'total_preguntas': 2387,
          'respuestas_aceptadas': 576,
          'tasa_aceptacion_pct': 24.13,
          'total_preguntas_prev': 2402,
          'respuestas_aceptadas_prev': 579,
          'tasa_aceptacion_prev_pct': 24.10,
          'delta_tasa_pct': 0.03,
          'delta_preguntas': -15,
          'sample_bucket': 'alta',
          'confidence_score': 0.224566,
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
          'tasa_aceptacion_prev_pct': 36.42,
          'delta_tasa_pct': -0.42,
          'delta_preguntas': -1,
          'sample_bucket': 'baja',
          'confidence_score': 0.287565,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        {
          'tecnologia': 'angular',
          'total_preguntas': 1624,
          'respuestas_aceptadas': 472,
          'tasa_aceptacion_pct': 29.06,
          'total_preguntas_prev': 1635,
          'respuestas_aceptadas_prev': 475,
          'tasa_aceptacion_prev_pct': 29.05,
          'delta_tasa_pct': 0.01,
          'delta_preguntas': -11,
          'sample_bucket': 'alta',
          'confidence_score': 0.269071,
          'raw_rank': 2,
          'confidence_rank': 2,
        },
        {
          'tecnologia': 'vue.js',
          'total_preguntas': 451,
          'respuestas_aceptadas': 111,
          'tasa_aceptacion_pct': 24.61,
          'total_preguntas_prev': 455,
          'respuestas_aceptadas_prev': 113,
          'tasa_aceptacion_prev_pct': 24.84,
          'delta_tasa_pct': -0.23,
          'delta_preguntas': -4,
          'sample_bucket': 'media',
          'confidence_score': 0.208619,
          'raw_rank': 3,
          'confidence_rank': 4,
        },
        {
          'tecnologia': 'reactjs',
          'total_preguntas': 2387,
          'respuestas_aceptadas': 576,
          'tasa_aceptacion_pct': 24.13,
          'total_preguntas_prev': 2402,
          'respuestas_aceptadas_prev': 579,
          'tasa_aceptacion_prev_pct': 24.10,
          'delta_tasa_pct': 0.03,
          'delta_preguntas': -15,
          'sample_bucket': 'alta',
          'confidence_score': 0.224566,
          'raw_rank': 4,
          'confidence_rank': 3,
        },
        {
          'tecnologia': 'next.js',
          'total_preguntas': 1265,
          'respuestas_aceptadas': 221,
          'tasa_aceptacion_pct': 17.47,
          'total_preguntas_prev': 1273,
          'respuestas_aceptadas_prev': 223,
          'tasa_aceptacion_prev_pct': 17.52,
          'delta_tasa_pct': -0.05,
          'delta_preguntas': -8,
          'sample_bucket': 'alta',
          'confidence_score': 0.154772,
          'raw_rank': 5,
          'confidence_rank': 5,
        },
      ],
      'snapshots': [],
    });
  }

  StackOverflowAcceptanceHistoryModel acceptanceHistoryCurrentOnly() {
    return StackOverflowAcceptanceHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 1,
      'latest_snapshot_date': '2026-03-08',
      'previous_snapshot_date': null,
      'has_historical_comparison': false,
      'item_count': 2,
      'summary': {
        'raw_leader': {
          'tecnologia': 'svelte',
          'total_preguntas': 150,
          'respuestas_aceptadas': 54,
          'tasa_aceptacion_pct': 36.0,
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
          'sample_bucket': 'baja',
          'confidence_score': 0.28,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        'highest_improvement': null,
        'largest_drop': null,
        'largest_sample': {
          'tecnologia': 'angular',
          'total_preguntas': 1600,
          'respuestas_aceptadas': 470,
          'tasa_aceptacion_pct': 29.4,
          'sample_bucket': 'alta',
          'confidence_score': 0.27,
          'raw_rank': 2,
          'confidence_rank': 2,
        },
      },
      'latest_items': [
        {
          'tecnologia': 'svelte',
          'total_preguntas': 150,
          'respuestas_aceptadas': 54,
          'tasa_aceptacion_pct': 36.0,
          'sample_bucket': 'baja',
          'confidence_score': 0.28,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        {
          'tecnologia': 'angular',
          'total_preguntas': 1600,
          'respuestas_aceptadas': 470,
          'tasa_aceptacion_pct': 29.4,
          'sample_bucket': 'alta',
          'confidence_score': 0.27,
          'raw_rank': 2,
          'confidence_rank': 2,
        },
      ],
      'snapshots': [],
    });
  }

  StackOverflowAcceptanceHistoryModel acceptanceHistoryWithNonContiguousDates() {
    return StackOverflowAcceptanceHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 2,
      'latest_snapshot_date': '2026-03-22',
      'previous_snapshot_date': '2026-03-19',
      'has_historical_comparison': true,
      'item_count': 2,
      'summary': {
        'raw_leader': {
          'tecnologia': 'svelte',
          'total_preguntas': 150,
          'respuestas_aceptadas': 54,
          'tasa_aceptacion_pct': 36.0,
          'total_preguntas_prev': 145,
          'respuestas_aceptadas_prev': 51,
          'tasa_aceptacion_prev_pct': 35.17,
          'delta_tasa_pct': 0.83,
          'delta_preguntas': 5,
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
          'total_preguntas_prev': 145,
          'respuestas_aceptadas_prev': 51,
          'tasa_aceptacion_prev_pct': 35.17,
          'delta_tasa_pct': 0.83,
          'delta_preguntas': 5,
          'sample_bucket': 'baja',
          'confidence_score': 0.28,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        'highest_improvement': {
          'tecnologia': 'svelte',
          'total_preguntas': 150,
          'respuestas_aceptadas': 54,
          'tasa_aceptacion_pct': 36.0,
          'total_preguntas_prev': 145,
          'respuestas_aceptadas_prev': 51,
          'tasa_aceptacion_prev_pct': 35.17,
          'delta_tasa_pct': 0.83,
          'delta_preguntas': 5,
          'sample_bucket': 'baja',
          'confidence_score': 0.28,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        'largest_drop': {
          'tecnologia': 'angular',
          'total_preguntas': 1600,
          'respuestas_aceptadas': 470,
          'tasa_aceptacion_pct': 29.4,
          'total_preguntas_prev': 1620,
          'respuestas_aceptadas_prev': 480,
          'tasa_aceptacion_prev_pct': 29.63,
          'delta_tasa_pct': -0.23,
          'delta_preguntas': -20,
          'sample_bucket': 'alta',
          'confidence_score': 0.27,
          'raw_rank': 2,
          'confidence_rank': 2,
        },
        'largest_sample': {
          'tecnologia': 'angular',
          'total_preguntas': 1600,
          'respuestas_aceptadas': 470,
          'tasa_aceptacion_pct': 29.4,
          'total_preguntas_prev': 1620,
          'respuestas_aceptadas_prev': 480,
          'tasa_aceptacion_prev_pct': 29.63,
          'delta_tasa_pct': -0.23,
          'delta_preguntas': -20,
          'sample_bucket': 'alta',
          'confidence_score': 0.27,
          'raw_rank': 2,
          'confidence_rank': 2,
        },
      },
      'latest_items': [
        {
          'tecnologia': 'svelte',
          'total_preguntas': 150,
          'respuestas_aceptadas': 54,
          'tasa_aceptacion_pct': 36.0,
          'total_preguntas_prev': 145,
          'respuestas_aceptadas_prev': 51,
          'tasa_aceptacion_prev_pct': 35.17,
          'delta_tasa_pct': 0.83,
          'delta_preguntas': 5,
          'sample_bucket': 'baja',
          'confidence_score': 0.28,
          'raw_rank': 1,
          'confidence_rank': 1,
        },
        {
          'tecnologia': 'angular',
          'total_preguntas': 1600,
          'respuestas_aceptadas': 470,
          'tasa_aceptacion_pct': 29.4,
          'total_preguntas_prev': 1620,
          'respuestas_aceptadas_prev': 480,
          'tasa_aceptacion_prev_pct': 29.63,
          'delta_tasa_pct': -0.23,
          'delta_preguntas': -20,
          'sample_bucket': 'alta',
          'confidence_score': 0.27,
          'raw_rank': 2,
          'confidence_rank': 2,
        },
      ],
      'snapshots': [],
    });
  }

  StackOverflowDashboardData dashboardData({
    required StackOverflowAcceptanceHistoryModel acceptanceHistory,
  }) {
    return StackOverflowDashboardData(
      volumen: volumeHistory().latestItems,
      aceptacion: acceptanceHistory.latestItems,
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
      volumenHistory: volumeHistory(),
      aceptacionHistory: acceptanceHistory,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
    required StackOverflowAcceptanceHistoryModel acceptanceHistory,
    _FakeDownloadService? downloadService,
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
              dashboardData(acceptanceHistory: acceptanceHistory),
            );
          }),
          runManifestProvider.overrideWith((ref) async {
            return DataLoadState<RunManifestPublic>.data(manifest());
          }),
        ],
        child: MaterialApp(
          home: StackOverflowDashboard(downloadService: downloadService),
        ),
      ),
    );

    await tester.pumpAndSettle();
  }

  Future<void> openFilter(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    final Finder dropdown = find.descendant(
      of: find.byKey(key),
      matching: find.byWidgetPredicate((widget) => widget is DropdownButton),
    );
    await tester.ensureVisible(dropdown);
    await tester.tap(dropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  testWidgets('graph 2 historical mode shows acceptance metric filters', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      acceptanceHistory: acceptanceHistoryWithComparison(),
    );

    expect(
      find.text(
        'M\u00E9trica: Tasa de aceptaci\u00F3n   Orden: Mayor tasa\n'
        'Comparado (UTC): 07/03/2026 -> 08/03/2026',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Mayor tasa: Svelte (36.0%)'), findsOneWidget);
    expect(find.textContaining('Mayor muestra:'), findsNothing);
    expect(find.textContaining('Muestra baja'), findsOneWidget);
    expect(find.textContaining('Muestra alta'), findsWidgets);
    final RenderBox metricFilter = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('so-acceptance-metric-filter')),
    );
    final RenderBox sortFilter = tester.renderObject<RenderBox>(
      find.byKey(const ValueKey<String>('so-acceptance-sort-filter')),
    );
    expect(metricFilter.size.height, lessThan(44));
    expect(sortFilter.size.height, lessThan(44));
    expect(tester.takeException(), isNull);
  });

  testWidgets('graph 2 current-only mode hides variaci\u00F3n cleanly', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      acceptanceHistory: acceptanceHistoryCurrentOnly(),
      size: const Size(390, 844),
    );

    expect(
      find.textContaining('Snapshot actual (UTC): 08/03/2026'),
      findsOneWidget,
    );
    await openFilter(
      tester,
      const ValueKey<String>('so-acceptance-metric-filter'),
    );
    expect(find.text('Tasa de aceptaci\u00F3n'), findsWidgets);
    expect(find.text('Preguntas totales'), findsNothing);
    expect(find.text('Variaci\u00F3n'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('graph 2 subtitle hides missing snapshot note', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      acceptanceHistory: acceptanceHistoryWithNonContiguousDates(),
      size: const Size(390, 844),
    );

    expect(
      find.text(
        'M\u00E9trica: Tasa de aceptaci\u00F3n   Orden: Mayor tasa\n'
        'Comparado (UTC): 19/03/2026 -> 22/03/2026',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('faltan'), findsNothing);
    expect(find.textContaining('falta snapshot'), findsNothing);
  });

  testWidgets('graph 2 badges follow only the active metric', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      acceptanceHistory: acceptanceHistoryWithComparison(),
    );

    expect(find.textContaining('Mayor tasa:'), findsOneWidget);
    expect(find.textContaining('Menor tasa:'), findsNothing);
    expect(find.textContaining('Mayor mejora:'), findsNothing);
    expect(find.textContaining('Mayor ca\u00EDda:'), findsNothing);
    expect(find.textContaining('Mayor muestra:'), findsNothing);

    await openFilter(
      tester,
      const ValueKey<String>('so-acceptance-sort-filter'),
    );
    await tester.tap(find.text('Menor tasa').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Mayor tasa:'), findsNothing);
    expect(find.textContaining('Menor tasa: Next.js (17.5%)'), findsOneWidget);
    expect(find.textContaining('Mayor mejora:'), findsNothing);
    expect(find.textContaining('Mayor ca\u00EDda:'), findsNothing);
    expect(find.textContaining('Mayor muestra:'), findsNothing);

    await openFilter(
      tester,
      const ValueKey<String>('so-acceptance-metric-filter'),
    );
    await tester.tap(find.text('Variaci\u00F3n').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Mayor mejora: ReactJS (+0.03 pts)'),
      findsOneWidget,
    );
    expect(find.textContaining('Mayor tasa:'), findsNothing);
    expect(find.textContaining('Menor tasa:'), findsNothing);
    expect(find.textContaining('Mayor muestra:'), findsNothing);
    expect(find.textContaining('Mayor ca\u00EDda:'), findsNothing);

    await openFilter(
      tester,
      const ValueKey<String>('so-acceptance-sort-filter'),
    );
    await tester.tap(find.text('Mayor ca\u00EDda').last);
    await tester.pumpAndSettle();

    expect(find.textContaining('Mayor mejora:'), findsNothing);
    expect(
      find.textContaining('Mayor ca\u00EDda: Svelte (-0.42 pts)'),
      findsOneWidget,
    );
  });

  testWidgets('graph 2 does not render duplicate tooltips', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      acceptanceHistory: acceptanceHistoryWithComparison(),
    );

    expect(
      find.byKey(const ValueKey<String>('acceptance-tooltip-svelte')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('acceptance-tooltip-reactjs')),
      findsNothing,
    );
  });

  testWidgets(
    'graph 2 export zip keeps enriched acceptance CSV independent of filters',
    (WidgetTester tester) async {
      final _FakeDownloadService downloadService = _FakeDownloadService();
      await pumpDashboard(
        tester,
        acceptanceHistory: acceptanceHistoryWithComparison(),
        downloadService: downloadService,
      );

      await openFilter(
        tester,
        const ValueKey<String>('so-acceptance-metric-filter'),
      );
      await tester.tap(find.text('Variaci\u00F3n').last);
      await tester.pumpAndSettle();

      final Finder exportIcon = find.byIcon(Icons.folder_zip);
      await tester.ensureVisible(exportIcon);
      await tester.tap(exportIcon, warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(downloadService.fileName, 'stackoverflow_datos_completos');
      expect(downloadService.zipBytes, isNotNull);

      final Archive archive = ZipDecoder().decodeBytes(
        downloadService.zipBytes!,
      );
      final ArchiveFile acceptanceFile = archive.files.firstWhere(
        (ArchiveFile file) => file.name == '2_respuestas_aceptadas.csv',
      );
      final String csv = utf8.decode(acceptanceFile.content as List<int>);
      final List<String> lines = const LineSplitter().convert(csv);

      expect(
        lines.first,
        'tecnologia,preguntas_totales,respuestas_aceptadas,tasa_aceptacion_pct,'
        'preguntas_totales_previas,respuestas_aceptadas_previas,'
        'tasa_aceptacion_previa_pct,variacion_tasa_pct,variacion_preguntas,'
        'calidad_muestra,confidence_score,raw_rank,confidence_rank',
      );
      expect(lines.length, 6);
      expect(
        lines,
        contains('svelte,150,54,36.00,151,55,36.42,-0.42,-1,baja,0.29,1,1'),
      );
      expect(
        lines,
        contains(
          'reactjs,2387,576,24.13,2402,579,24.10,0.03,-15,alta,0.22,4,3',
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('graph 2 stays stable across responsive breakpoints', (
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
      await pumpDashboard(
        tester,
        acceptanceHistory: acceptanceHistoryWithComparison(),
        size: size,
      );
      expect(find.byType(StackOverflowDashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'insight 2 uses confidence leader source with historical comparison',
    (WidgetTester tester) async {
      await pumpDashboard(
        tester,
        acceptanceHistory: acceptanceHistoryWithComparison(),
      );

      expect(
        find.text('Svelte combina alta aceptaci\u00F3n y muestra s\u00F3lida'),
        findsOneWidget,
      );
      expect(
        find.text(
          '36.0% de aceptaci\u00F3n sobre 150 preguntas, var -0.42 pts vs 07/03/2026',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('soluciones'), findsNothing);
    },
  );

  testWidgets('insight 2 current-only mode uses snapshot copy', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(
      tester,
      acceptanceHistory: acceptanceHistoryCurrentOnly(),
    );

    expect(
      find.text('Svelte combina alta aceptaci\u00F3n y muestra s\u00F3lida'),
      findsOneWidget,
    );
    expect(
      find.text(
        '36.0% de aceptaci\u00F3n sobre 150 preguntas.',
      ),
      findsOneWidget,
    );
  });
}
