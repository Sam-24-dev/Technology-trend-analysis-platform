import 'dart:convert';

import 'package:archive/archive.dart';
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
      generatedAtUtc: '2026-03-08T20:45:55Z',
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

  StackOverflowTrendsHistoryModel trendsHistory() {
    return StackOverflowTrendsHistoryModel.fromMap(<String, dynamic>{
      'source_mode': 'history',
      'snapshot_count': 5,
      'months': ['2025-03', '2025-04', '2025-05', '2025-06'],
      'series': [
        {
          'tecnologia': 'Python',
          'points': [2113, 1660, 1374, 1022],
          'start_value': 2113,
          'end_value': 1022,
          'abs_delta': -1091,
          'pct_delta': -51.64,
          'retention_pct': 48.36,
          'peak_month': '2025-03',
          'peak_value': 2113,
          'latest_rank': 1,
        },
        {
          'tecnologia': 'JavaScript',
          'points': [1054, 734, 599, 456],
          'start_value': 1054,
          'end_value': 456,
          'abs_delta': -598,
          'pct_delta': -56.74,
          'retention_pct': 43.26,
          'peak_month': '2025-03',
          'peak_value': 1054,
          'latest_rank': 2,
        },
        {
          'tecnologia': 'TypeScript',
          'points': [467, 346, 312, 216],
          'start_value': 467,
          'end_value': 216,
          'abs_delta': -251,
          'pct_delta': -53.75,
          'retention_pct': 46.25,
          'peak_month': '2025-03',
          'peak_value': 467,
          'latest_rank': 3,
        },
        {
          'tecnologia': 'C#',
          'points': [430, 318, 205, 120],
          'start_value': 430,
          'end_value': 120,
          'abs_delta': -310,
          'pct_delta': -72.09,
          'retention_pct': 27.91,
          'peak_month': '2025-03',
          'peak_value': 430,
          'latest_rank': 4,
        },
        {
          'tecnologia': 'Java',
          'points': [402, 298, 244, 158],
          'start_value': 402,
          'end_value': 158,
          'abs_delta': -244,
          'pct_delta': -60.70,
          'retention_pct': 39.30,
          'peak_month': '2025-03',
          'peak_value': 402,
          'latest_rank': 5,
        },
      ],
      'summary': {
        'current_leader': {
          'tecnologia': 'Python',
          'start_value': 2113,
          'end_value': 1022,
          'abs_delta': -1091,
          'pct_delta': -51.64,
          'retention_pct': 48.36,
          'peak_month': '2025-03',
          'peak_value': 2113,
          'latest_rank': 1,
        },
        'best_retention': {
          'tecnologia': 'Python',
          'start_value': 2113,
          'end_value': 1022,
          'abs_delta': -1091,
          'pct_delta': -51.64,
          'retention_pct': 48.36,
          'peak_month': '2025-03',
          'peak_value': 2113,
          'latest_rank': 1,
        },
        'largest_relative_drop': {
          'tecnologia': 'C#',
          'start_value': 430,
          'end_value': 120,
          'abs_delta': -310,
          'pct_delta': -72.09,
          'retention_pct': 27.91,
          'peak_month': '2025-03',
          'peak_value': 430,
          'latest_rank': 4,
        },
        'largest_absolute_drop': {
          'tecnologia': 'Python',
          'start_value': 2113,
          'end_value': 1022,
          'abs_delta': -1091,
          'pct_delta': -51.64,
          'retention_pct': 48.36,
          'peak_month': '2025-03',
          'peak_value': 2113,
          'latest_rank': 1,
        },
      },
    });
  }

  StackOverflowDashboardData dashboardData() {
    final StackOverflowTrendsHistoryModel history = trendsHistory();
    return StackOverflowDashboardData(
      volumen: const <VolumenPreguntasModel>[
        VolumenPreguntasModel(lenguaje: 'python', preguntas: 100),
      ],
      aceptacion: const <TasaAceptacionModel>[
        TasaAceptacionModel(
          tecnologia: 'svelte',
          tasaPct: 36.0,
          totalPreguntas: 150,
          respuestasAceptadas: 54,
        ),
      ],
      tendencias: const <TendenciaMensualModel>[
        TendenciaMensualModel(
          mes: '2025-03',
          python: 2113,
          javascript: 1054,
          typescript: 467,
        ),
        TendenciaMensualModel(
          mes: '2025-04',
          python: 1660,
          javascript: 734,
          typescript: 346,
        ),
        TendenciaMensualModel(
          mes: '2025-05',
          python: 1374,
          javascript: 599,
          typescript: 312,
        ),
        TendenciaMensualModel(
          mes: '2025-06',
          python: 1022,
          javascript: 456,
          typescript: 216,
        ),
      ],
      tendenciasHistory: history,
    );
  }

  Future<void> pumpDashboard(
    WidgetTester tester, {
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
              dashboardData(),
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
    await tester.tap(dropdown, warnIfMissed: false);
    await tester.pumpAndSettle();
  }

  String firstTrendTooltipText(WidgetTester tester) {
    final LineChart chart = tester.widget<LineChart>(find.byType(LineChart));
    final LineChartData data = chart.data;
    final LineChartBarData firstBar = data.lineBarsData.first;
    final tooltipItems = data.lineTouchData.touchTooltipData.getTooltipItems(
      <TouchLineBarSpot>[
        TouchLineBarSpot(firstBar, 0, firstBar.spots.first, 0),
      ],
    );
    expect(tooltipItems, isNotNull);
    expect(tooltipItems.first, isNotNull);
    return tooltipItems.first!.text;
  }

  testWidgets('graph 3 shows bridge-driven summary and shared view filter', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    expect(
      find.textContaining('Vista: Volumen mensual   Top: Top 3'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Período mensual (12 meses completos): mar 2025 -> jun 2025',
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('so-trend-view-filter')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('so-trend-top-filter')),
      findsOneWidget,
    );
    expect(find.textContaining('Líder actual: Python (1,022)'), findsOneWidget);
    expect(
      find.textContaining('Mayor caída absoluta: Python (-1,091)'),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-python')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-javascript')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-typescript')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-c-sharp')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-current-value-python')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-current-value-javascript')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('graph 3 switches to índice base 100 and updates badges', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    await openFilter(tester, const ValueKey<String>('so-trend-view-filter'));
    await tester.tap(find.text('Índice base 100').last);
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Vista: Índice base 100   Top: Top 3'),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Período mensual (12 meses completos): mar 2025 -> jun 2025',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('Líder actual:'), findsNothing);
    expect(find.textContaining('Mayor caída absoluta:'), findsNothing);
    expect(
      find.textContaining('Mejor retención: Python (48.4%)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mayor caída relativa: JavaScript (-56.7%)'),
      findsOneWidget,
    );
    final String tooltip = firstTrendTooltipText(tester);
    expect(tooltip, contains('Python'));
    expect(tooltip, contains('Índice: 100.0'));
    expect(tooltip, isNot(contains('Variación acumulada')));
  });

  testWidgets('graph 3 top filter keeps a stable subset across views', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.byType(Chip), findsNWidgets(3));
    await openFilter(tester, const ValueKey<String>('so-trend-top-filter'));
    await tester.tap(find.text('Todas').last);
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNWidgets(5));
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-c-sharp')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-java')),
      findsOneWidget,
    );
    expect(find.textContaining('Top: Todas'), findsOneWidget);
    expect(
      find.textContaining('Mayor caída absoluta: Python (-1,091)'),
      findsOneWidget,
    );

    await openFilter(tester, const ValueKey<String>('so-trend-view-filter'));
    await tester.tap(find.text('Índice base 100').last);
    await tester.pumpAndSettle();

    expect(find.byType(Chip), findsNWidgets(5));
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-c-sharp')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('trend-series-chip-java')),
      findsOneWidget,
    );
    expect(find.textContaining('Top: Todas'), findsOneWidget);
    expect(
      find.textContaining('Mejor retención: Python (48.4%)'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Mayor caída relativa: C# (-72.1%)'),
      findsOneWidget,
    );
  });

  testWidgets('graph 3 legend chips render as passive legend items', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    final Finder pythonChip = find.byKey(
      const ValueKey<String>('trend-series-chip-python'),
    );
    expect(pythonChip, findsOneWidget);
    expect(find.byType(FilterChip), findsNothing);
    expect(tester.widget<Chip>(pythonChip).label, isA<Text>());
    expect(tester.takeException(), isNull);
  });

  testWidgets('graph 3 insight reads from summary without causal wording', (
    WidgetTester tester,
  ) async {
    await pumpDashboard(tester);

    expect(find.text('Impacto de IA en el volumen'), findsNothing);
    expect(
      find.text('C# registra la caída relativa más pronunciada'),
      findsOneWidget,
    );
    expect(
      find.text(
        'De 430 a 120 preguntas mensuales, mayor caída relativa.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'graph 3 export keeps enriched CSV independent of visible filter state',
    (WidgetTester tester) async {
      final _FakeDownloadService downloadService = _FakeDownloadService();
      await pumpDashboard(tester, downloadService: downloadService);

      expect(find.byType(Chip), findsNWidgets(3));
      await openFilter(tester, const ValueKey<String>('so-trend-view-filter'));
      await tester.tap(find.text('Índice base 100').last);
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
      final ArchiveFile trendFile = archive.files.firstWhere(
        (ArchiveFile file) => file.name == '3_tendencias_mensuales.csv',
      );
      final String csv = utf8.decode(trendFile.content as List<int>);
      final List<String> lines = const LineSplitter().convert(csv);

      expect(
        lines.first,
        'tecnologia,mes,valor,indice_base_100,start_value,end_value,abs_delta,pct_delta,retention_pct,latest_rank',
      );
      expect(lines.length, 21);
      expect(
        lines,
        contains('Python,2025-03,2113,100.00,2113,1022,-1091,-51.64,48.36,1'),
      );
      expect(
        lines,
        contains('JavaScript,2025-06,456,43.26,1054,456,-598,-56.74,43.26,2'),
      );
      expect(
        lines,
        contains('C#,2025-06,120,27.91,430,120,-310,-72.09,27.91,4'),
      );
    },
  );

  testWidgets('graph 3 stays stable across responsive breakpoints', (
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
      await pumpDashboard(tester, size: size);
      expect(find.byType(StackOverflowDashboard), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });
}
