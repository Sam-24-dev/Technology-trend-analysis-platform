import 'package:flutter/material.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget chart;
  final double height;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.chart,
    this.height = 300,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isNarrow = screenWidth < 760;

    Widget chartBody = SizedBox(height: height, child: chart);
    if (isNarrow) {
      chartBody = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: 760, height: height, child: chart),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
            const SizedBox(height: 20),
            chartBody,
          ],
        ),
      ),
    );
  }
}
