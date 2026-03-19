import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/router/app_router.dart';
import 'package:frontend/screens/trends_tech_screen.dart';

void main() {
  Future<void> _pumpRouter(
    WidgetTester tester, {
    required String initialLocation,
    Size size = const Size(1280, 900),
    Finder? readyFinder,
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
    for (int i = 0; i < 80; i++) {
      await tester.pump(const Duration(milliseconds: 250));
      if (readyFinder != null && readyFinder.evaluate().isNotEmpty) {
        await tester.pump();
        return;
      }
    }
    if (readyFinder != null) {
      expect(readyFinder, findsWidgets);
      await tester.pump();
    }
  }

  testWidgets('go_router deep-link /github carga shell y vista GitHub', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(
      tester,
      initialLocation: AppRoutes.github,
      readyFinder: find.text('GitHub Data'),
    );

    expect(find.text('GitHub Data'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('go_router deep-link /trends/:tech renderiza detalle', (
    WidgetTester tester,
  ) async {
    final Finder trendsScreenFinder = find.byWidgetPredicate(
      (Widget widget) =>
          widget is TrendsTechScreen && widget.technology == 'python',
    );

    await _pumpRouter(
      tester,
      initialLocation: '/trends/python',
      readyFinder: trendsScreenFinder,
    );

    expect(trendsScreenFinder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('go_router hash deep-link /#/github carga vista GitHub', (
    WidgetTester tester,
  ) async {
    await _pumpRouter(
      tester,
      initialLocation: '/#/github',
      readyFinder: find.text('GitHub Data'),
    );

    expect(find.text('Tech Trends 2025'), findsNothing);
    expect(find.text('GitHub Data'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'go_router mantiene ruta hash al recrear router (refresh simulado)',
    (WidgetTester tester) async {
      await _pumpRouter(
        tester,
        initialLocation: '/#/stackoverflow',
        readyFinder: find.text('StackOverflow Data'),
      );
      expect(find.text('Tech Trends 2025'), findsNothing);
      expect(find.text('StackOverflow Data'), findsWidgets);

      await _pumpRouter(
        tester,
        initialLocation: '/#/stackoverflow',
        readyFinder: find.text('StackOverflow Data'),
      );
      expect(find.text('Tech Trends 2025'), findsNothing);
      expect(find.text('StackOverflow Data'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
}
