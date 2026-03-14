import 'package:flutter/material.dart';

enum ChartLegendMarker {
  dot,
  square,
  line,
}

class ChartLegendItemData {
  final String label;
  final Color color;
  final ChartLegendMarker marker;
  final double? markerWidth;
  final double? markerHeight;

  const ChartLegendItemData({
    required this.label,
    required this.color,
    this.marker = ChartLegendMarker.dot,
    this.markerWidth,
    this.markerHeight,
  });
}

class ChartLegend extends StatelessWidget {
  final List<ChartLegendItemData> items;
  final double spacing;
  final double runSpacing;
  final TextStyle? textStyle;

  const ChartLegend({
    super.key,
    required this.items,
    this.spacing = 10,
    this.runSpacing = 8,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    final TextStyle resolvedStyle =
        textStyle ??
        Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFF475569),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ) ??
        const TextStyle(
          color: Color(0xFF475569),
          fontWeight: FontWeight.w600,
          fontSize: 12,
        );

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: items
          .map(
            (ChartLegendItemData item) => _LegendItem(
              item: item,
              textStyle: resolvedStyle,
            ),
          )
          .toList(),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final ChartLegendItemData item;
  final TextStyle textStyle;

  const _LegendItem({required this.item, required this.textStyle});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          _LegendMarker(item: item),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              item.label,
              style: textStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendMarker extends StatelessWidget {
  final ChartLegendItemData item;

  const _LegendMarker({required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.marker) {
      case ChartLegendMarker.line:
        return Container(
          width: item.markerWidth ?? 18,
          height: item.markerHeight ?? 2,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(999),
          ),
        );
      case ChartLegendMarker.square:
        return Container(
          width: item.markerWidth ?? 10,
          height: item.markerHeight ?? 10,
          decoration: BoxDecoration(
            color: item.color,
            borderRadius: BorderRadius.circular(3),
          ),
        );
      case ChartLegendMarker.dot:
        return Container(
          width: item.markerWidth ?? 10,
          height: item.markerHeight ?? 10,
          decoration: BoxDecoration(
            color: item.color,
            shape: BoxShape.circle,
          ),
        );
    }
  }
}
