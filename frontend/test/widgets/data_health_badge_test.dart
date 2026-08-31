import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/widgets/data_health_badge.dart';

void main() {
  testWidgets('DataHealthBadge renderiza estado pass y semantics', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frontendHealthProvider.overrideWithValue(
            AsyncData(
              DataLoadState.data(
                const FrontendHealthData(
                  status: 'pass',
                  message: 'ok',
                  degradedMode: false,
                  availableSourcesCount: 3,
                ),
              ),
            ),
          ),
          runManifestProvider.overrideWith((ref) async {
            return DataLoadState.data(
              RunManifestPublic(
                manifestVersion: '1.0.0',
                generatedAtUtc: '2026-02-25T00:00:00Z',
                sourceWindowStartUtc: '2025-02-25T00:00:00Z',
                sourceWindowEndUtc: '2026-02-25T00:00:00Z',
                qualityGateStatus: 'pass',
                degradedMode: false,
                availableSources: const ['github', 'stackoverflow', 'reddit'],
                datasetSummaries: const <RunManifestDatasetSummary>[
                  RunManifestDatasetSummary(
                    dataset: 'github_lenguajes',
                    rowCount: 10,
                    qualityStatus: 'pass',
                    updatedAtUtc: '2026-08-24T09:00:00Z',
                  ),
                  RunManifestDatasetSummary(
                    dataset: 'so_volumen_preguntas',
                    rowCount: 10,
                    qualityStatus: 'pass',
                    updatedAtUtc: '2026-08-24T10:00:00Z',
                  ),
                  RunManifestDatasetSummary(
                    dataset: 'reddit_temas_emergentes',
                    rowCount: 10,
                    qualityStatus: 'pass',
                    updatedAtUtc: '2026-08-31T03:00:00Z',
                  ),
                ],
                totalReposExtraidos: 1000,
                totalReposClasificables: 925,
                soLanguagesCount: 10,
                notes: 'ok',
              ),
            );
          }),
        ],
        child: const MaterialApp(
          home: Scaffold(body: Center(child: DataHealthBadge())),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data-health-badge')), findsOneWidget);
    expect(find.textContaining('pass'), findsOneWidget);
    expect(find.byType(Tooltip), findsOneWidget);
    final Tooltip tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(tooltip.message, contains('GitHub: 24/08/2026 UTC'));
    expect(tooltip.message, contains('Stack Overflow: 24/08/2026 UTC'));
    expect(tooltip.message, contains('Reddit: 31/08/2026 UTC'));
    expect(
      find.bySemanticsLabel(RegExp('GitHub: 24/08/2026 UTC')),
      findsOneWidget,
    );
  });

  testWidgets('DataHealthBadge cae a unknown cuando no hay metadata', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          frontendHealthProvider.overrideWithValue(
            AsyncData(
              DataLoadState.degraded(
                const FrontendHealthData(
                  status: 'unknown',
                  message: 'metadata unavailable',
                  degradedMode: true,
                  availableSourcesCount: 0,
                ),
              ),
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: DataHealthBadge(compact: true)),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('data-health-badge')), findsOneWidget);
    expect(find.textContaining('unknown'), findsOneWidget);
  });
}
