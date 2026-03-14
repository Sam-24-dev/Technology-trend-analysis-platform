import 'package:flutter/material.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget chart;
  final double height;
  final String? badgeText;
  final Widget? legend;
  final String? semanticLabel;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.chart,
    this.height = 300,
    this.badgeText,
    this.legend,
    this.semanticLabel,
  });

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final bool isNarrow = screenWidth < 760;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;

    Widget chartBody = SizedBox(height: height, child: chart);
    if (isNarrow) {
      chartBody = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(width: 780, height: height, child: chart),
      );
    }
    chartBody = RepaintBoundary(child: chartBody);
    if (semanticLabel != null && semanticLabel!.trim().isNotEmpty) {
      chartBody = Semantics(
        container: true,
        label: semanticLabel,
        child: chartBody,
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: colors.primary,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (badgeText != null && badgeText!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      badgeText!,
                      style: textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF334155),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(
                subtitle!,
                style: textTheme.bodyMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontSize: 13.5,
                ),
              ),
            ],
            const SizedBox(height: 18),
            chartBody,
            if (legend != null) ...[
              const SizedBox(height: 12),
              legend!,
            ],
          ],
        ),
      ),
    );
  }
}
