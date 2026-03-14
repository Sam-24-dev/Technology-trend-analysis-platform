import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/chart_legend.dart';

void main() {
  testWidgets('ChartLegend renders legend labels', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChartLegend(
            items: const <ChartLegendItemData>[
              ChartLegendItemData(label: 'Serie A', color: Colors.red),
              ChartLegendItemData(
                label: 'Serie B',
                color: Colors.blue,
                marker: ChartLegendMarker.line,
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Serie A'), findsOneWidget);
    expect(find.text('Serie B'), findsOneWidget);
  });
}
