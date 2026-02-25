import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/screens/github_dashboard.dart';
import 'package:frontend/screens/reddit_dashboard.dart';
import 'package:frontend/screens/stackoverflow_dashboard.dart';

void main() {
  Future<void> _pumpDashboard(
    WidgetTester tester, {
    required Widget child,
    Size size = const Size(2560, 3000),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(ProviderScope(child: MaterialApp(home: child)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(seconds: 2));
  }

  testWidgets('github dashboard smoke renders scaffold title', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, child: const GithubDashboard());

    expect(find.text('Dashboard GitHub'), findsOneWidget);
  });

  testWidgets('stackoverflow dashboard smoke renders scaffold title', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, child: const StackOverflowDashboard());

    expect(find.text('Dashboard StackOverflow'), findsOneWidget);
  });

  testWidgets('reddit dashboard smoke renders scaffold title', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(tester, child: const RedditDashboard());

    expect(find.text('Dashboard Reddit'), findsOneWidget);
  });

  testWidgets('dashboards no rompen layout en mobile portrait 390x844', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(
      tester,
      child: const GithubDashboard(),
      size: const Size(390, 844),
    );
    expect(find.byType(GithubDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpDashboard(
      tester,
      child: const StackOverflowDashboard(),
      size: const Size(390, 844),
    );
    expect(find.byType(StackOverflowDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpDashboard(
      tester,
      child: const RedditDashboard(),
      size: const Size(390, 844),
    );
    expect(find.byType(RedditDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboards no rompen layout en mobile landscape 844x390', (
    WidgetTester tester,
  ) async {
    await _pumpDashboard(
      tester,
      child: const GithubDashboard(),
      size: const Size(844, 390),
    );
    expect(find.byType(GithubDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpDashboard(
      tester,
      child: const StackOverflowDashboard(),
      size: const Size(844, 390),
    );
    expect(find.byType(StackOverflowDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);

    await _pumpDashboard(
      tester,
      child: const RedditDashboard(),
      size: const Size(844, 390),
    );
    expect(find.byType(RedditDashboard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
