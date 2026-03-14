import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/chart_inline_filter.dart';

void main() {
  Future<void> pumpFilter(
    WidgetTester tester, {
    required String selectedLabel,
    required ValueChanged<String?> onChanged,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: ChartInlineFilter<String>(
              key: const ValueKey<String>('shared-inline-filter'),
              label: 'Métrica',
              value: selectedLabel,
              selectedLabel: selectedLabel,
              items: const <DropdownMenuItem<String>>[
                DropdownMenuItem<String>(
                  value: 'Tasa de aceptación',
                  child: Text('Tasa de aceptación'),
                ),
                DropdownMenuItem<String>(
                  value: 'Variación',
                  child: Text('Variación'),
                ),
              ],
              onChanged: onChanged,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ChartInlineFilter renders compact inline control', (
    WidgetTester tester,
  ) async {
    await pumpFilter(
      tester,
      selectedLabel: 'Tasa de aceptación',
      onChanged: (_) {},
    );

    final Finder filter = find.byKey(
      const ValueKey<String>('shared-inline-filter'),
    );
    expect(filter, findsOneWidget);
    expect(find.textContaining('Métrica:'), findsOneWidget);
    expect(find.text('Tasa de aceptación'), findsAtLeastNWidgets(1));

    final Size size = tester.getSize(filter);
    expect(size.height, lessThan(44));
  });

  testWidgets('ChartInlineFilter propagates selection changes', (
    WidgetTester tester,
  ) async {
    String selected = 'Tasa de aceptación';

    await pumpFilter(
      tester,
      selectedLabel: selected,
      onChanged: (String? value) {
        if (value != null) {
          selected = value;
        }
      },
    );

    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Variación').last);
    await tester.pumpAndSettle();

    expect(selected, 'Variación');
  });
}
