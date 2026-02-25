import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/router/app_router.dart';
import 'package:frontend/widgets/data_health_badge.dart';

double _channelToLinear(int channel) {
  final value = channel / 255.0;
  if (value <= 0.03928) {
    return value / 12.92;
  }
  return pow((value + 0.055) / 1.055, 2.4).toDouble();
}

double _relativeLuminance(Color color) {
  return (0.2126 * _channelToLinear(color.red)) +
      (0.7152 * _channelToLinear(color.green)) +
      (0.0722 * _channelToLinear(color.blue));
}

double _contrastRatio(Color a, Color b) {
  final l1 = _relativeLuminance(a);
  final l2 = _relativeLuminance(b);
  final lighter = max(l1, l2);
  final darker = min(l1, l2);
  return (lighter + 0.05) / (darker + 0.05);
}

void main() {
  Future<void> _pumpMain(
    WidgetTester tester, {
    Size size = const Size(1280, 768),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createAppRouter(initialLocation: AppRoutes.home);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('main navigation expone semantics labels', (
    WidgetTester tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

    await _pumpMain(tester);

    final homeNode = tester.getSemantics(find.byKey(const Key('nav-home')));
    final githubNode = tester.getSemantics(find.byKey(const Key('nav-github')));
    final stackoverflowNode = tester.getSemantics(
      find.byKey(const Key('nav-stackoverflow')),
    );
    final redditNode = tester.getSemantics(find.byKey(const Key('nav-reddit')));

    expect(homeNode.label, contains('Navegar a inicio'));
    expect(githubNode.label, contains('Navegar a dashboard de GitHub'));
    expect(
      stackoverflowNode.label,
      contains('Navegar a dashboard de StackOverflow'),
    );
    expect(redditNode.label, contains('Navegar a dashboard de Reddit'));

    semanticsHandle.dispose();
  });

  testWidgets('teclado tab/enter no rompe foco ni navegacion base', (
    WidgetTester tester,
  ) async {
    await _pumpMain(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.takeException(), isNull);
  });

  testWidgets('DataHealthBadge expone semantics de estado', (
    WidgetTester tester,
  ) async {
    final semanticsHandle = tester.ensureSemantics();

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
                datasetSummaries: const <RunManifestDatasetSummary>[],
                notes: 'ok',
              ),
            );
          }),
        ],
        child: MaterialApp(
          home: Scaffold(body: Center(child: DataHealthBadge())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.byKey(const Key('data-health-badge')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Estado de datos')), findsOneWidget);

    semanticsHandle.dispose();
  });

  test('tokens de contraste base cumplen WCAG AA (>= 4.5)', () {
    final contrastPrimaryText = _contrastRatio(
      const Color(0xFF1F2937),
      Colors.white,
    );
    final contrastSecondaryText = _contrastRatio(
      const Color(0xFF6B7280),
      Colors.white,
    );
    final contrastSidebarText = _contrastRatio(
      Colors.white,
      const Color(0xFF1A1A2E),
    );

    expect(contrastPrimaryText, greaterThanOrEqualTo(4.5));
    expect(contrastSecondaryText, greaterThanOrEqualTo(4.5));
    expect(contrastSidebarText, greaterThanOrEqualTo(4.5));
  });
}
