import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/models/dashboard_domain_models.dart';
import 'package:frontend/models/data_load_state.dart';
import 'package:frontend/models/run_manifest_models.dart';
import 'package:frontend/providers/app_providers.dart';
import 'package:frontend/router/app_router.dart';

void main() {
  Future<void> _pumpAtSize(
    WidgetTester tester, {
    required Size size,
    String initialLocation = AppRoutes.home,
    List<Override> overrides = const <Override>[],
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createAppRouter(initialLocation: initialLocation);
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('desktop usa sidebar', (WidgetTester tester) async {
    await _pumpAtSize(tester, size: const Size(1280, 768));
    expect(find.byKey(const Key('sidebar-desktop')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet usa navigation rail', (WidgetTester tester) async {
    await _pumpAtSize(tester, size: const Size(1024, 768));
    expect(find.byKey(const Key('navigation-rail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet portrait 768x1024 usa navigation rail', (
    WidgetTester tester,
  ) async {
    await _pumpAtSize(tester, size: const Size(768, 1024));
    expect(find.byKey(const Key('navigation-rail')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile portrait usa appbar + drawer', (
    WidgetTester tester,
  ) async {
    await _pumpAtSize(tester, size: const Size(390, 844));
    expect(find.byKey(const Key('mobile-scaffold')), findsOneWidget);
    expect(find.byKey(const Key('appbar-mobile')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile landscape no rompe layout base', (
    WidgetTester tester,
  ) async {
    await _pumpAtSize(tester, size: const Size(844, 390));
    expect(find.byType(Scaffold), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('metadata missing mantiene badge unknown y UI operativa', (
    WidgetTester tester,
  ) async {
    await _pumpAtSize(
      tester,
      size: const Size(1280, 768),
      overrides: <Override>[
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
        runManifestProvider.overrideWith(
          (ref) async =>
              DataLoadState<RunManifestPublic>.error('metadata unavailable'),
        ),
      ],
    );

    expect(find.byKey(const Key('data-health-badge')), findsWidgets);
    expect(find.textContaining('unknown'), findsWidgets);
    expect(find.text('Tech Trends 2025'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
