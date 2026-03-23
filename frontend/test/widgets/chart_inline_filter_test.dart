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

  testWidgets('ChartInlineFilter wraps cleanly on narrow widths', (
    WidgetTester tester,
  ) async {
    const List<Size> viewports = <Size>[
      Size(220, 120),
      Size(280, 120),
      Size(390, 120),
      Size(768, 120),
      Size(1280, 120),
    ];

    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final Size size in viewports) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: size.width < 300 ? size.width - 16 : 280,
                child: ChartInlineFilter<String>(
                  key: const ValueKey<String>('shared-inline-filter'),
                  label: 'Vista',
                  value: 'Solo multi-fuente',
                  selectedLabel: 'Solo multi-fuente',
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'Top recomendado',
                      child: Text('Top recomendado'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'Solo multi-fuente',
                      child: Text('Solo multi-fuente'),
                    ),
                  ],
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(
        tester.takeException(),
        isNull,
        reason: 'ChartInlineFilter overflowed at viewport $size',
      );
    }
  });
}