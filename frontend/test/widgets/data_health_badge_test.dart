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
                datasetSummaries: const [],
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
