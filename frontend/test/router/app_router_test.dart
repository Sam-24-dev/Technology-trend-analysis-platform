// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:frontend/router/app_router.dart';

void main() {
  Future<void> _pumpRouter(
    WidgetTester tester, {
    required String initialLocation,
    Size size = const Size(1280, 900),
    Finder? readyFinder,
  }) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();

    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 250));
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
    await _pumpRouter(
      tester,
      initialLocation: '/trends/python',
      size: const Size(800, 600),
      readyFinder: find.textContaining(
        'Análisis por tecnología',
        findRichText: true,
        skipOffstage: false,
      ),
    );

    expect(
      find.textContaining(
        'Análisis por tecnología',
        findRichText: true,
        skipOffstage: false,
      ),
      findsWidgets,
    );
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
