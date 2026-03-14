import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/models/trend_history_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/screens/home_screen.dart';
import 'package:frontend/widgets/degraded_state_card.dart';

void main() {
  testWidgets(
    'home muestra banner degradado y mantiene items cuando hay csv_fallback',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            trendTemporalProvider.overrideWith(
              (ref) async => DataLoadState.degraded(
                const TrendTemporalViewData(
                  source: 'csv_fallback',
                  snapshotCount: 1,
                  items: <TrendTopEntry>[
                    TrendTopEntry(
                      ranking: 1,
                      tecnologia: 'Python',
                      trendScore: 76.45,
                      fuentes: 3,
                      githubScore: 45,
                      stackOverflowScore: 25,
                      redditScore: 6.45,
                      scorePrev: 74,
                      deltaScore: 2.45,
                      rankingPrev: 1,
                      deltaRanking: 0,
                      availableSources: <String>['GH', 'SO', 'RD'],
                    ),
                  ],
                ),
                message: 'bridge unavailable, using CSV fallback',
              ),
            ),
            runManifestProvider.overrideWith(
              (ref) async => DataLoadState.data(
                const RunManifestPublic(
                  manifestVersion: '1.0.0',
                  generatedAtUtc: '2026-02-25T00:00:00Z',
                  sourceWindowStartUtc: '2025-02-25T00:00:00Z',
                  sourceWindowEndUtc: '2026-02-25T00:00:00Z',
                  qualityGateStatus: 'pass_with_warnings',
                  degradedMode: true,
                  availableSources: <String>['github', 'stackoverflow'],
                  totalReposExtraidos: 1000,
                  totalReposClasificables: 925,
                  soLanguagesCount: 10,
                  datasetSummaries: <RunManifestDatasetSummary>[
                    RunManifestDatasetSummary(
                      dataset: 'trend_score',
                      rowCount: 23,
                      qualityStatus: 'pass',
                      updatedAtUtc: '2026-02-25T00:00:00Z',
                    ),
                  ],
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

      expect(find.byType(DegradedStateCard), findsOneWidget);
      expect(find.text('Python'), findsOneWidget);
      expect(find.text('76.45'), findsOneWidget);
    },
  );
}
