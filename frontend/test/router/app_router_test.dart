import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/router/app_router.dart';

void main() {
  Future<void> _pumpRouter(
    WidgetTester tester, {
    required String initialLocation,
    Size size = const Size(1280, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createAppRouter(initialLocation: initialLocation);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    for (int i = 0; i < 32; i++) {
      await tester.pump(const Duration(milliseconds: 250));
    }
  }

  testWidgets('go_router deep-link /github carga shell y vista GitHub', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(tester, initialLocation: AppRoutes.github);

    expect(find.text('GitHub Data'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('go_router deep-link /trends/:tech renderiza detalle', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/trends/python');

    expect(find.text('Python'), findsOneWidget);
    expect(find.textContaining('Análisis por tecnología'), findsWidgets);
  });

  testWidgets('go_router hash deep-link /#/github carga vista GitHub', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(tester, initialLocation: '/#/github');

    expect(find.text('Tech Trends 2025'), findsNothing);
    expect(find.text('GitHub Data'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'go_router mantiene ruta hash al recrear router (refresh simulado)',
    (WidgetTester tester) async {
      await _pumpRouter(tester, initialLocation: '/#/stackoverflow');
      expect(find.text('Tech Trends 2025'), findsNothing);
      expect(find.text('StackOverflow Data'), findsWidgets);

      await _pumpRouter(tester, initialLocation: '/#/stackoverflow');
      expect(find.text('Tech Trends 2025'), findsNothing);
      expect(find.text('StackOverflow Data'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}

