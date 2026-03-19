import 'package:flutter/material.dart';

const Color _kSkeletonBase = Color(0xFFE2E8F0);

class SkeletonBox extends StatelessWidget {
  final double height;
  final double? width;
  final BorderRadius borderRadius;
  final Color color;

  const SkeletonBox({
    super.key,
    required this.height,
    this.width,
    this.borderRadius = const BorderRadius.all(Radius.circular(8)),
    this.color = _kSkeletonBase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width ?? double.infinity,
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
    );
  }
}

class SkeletonLine extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonLine({
    super.key,
    this.width = 140,
    this.height = 12,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      height: height,
      width: width,
      borderRadius: BorderRadius.circular(999),
    );
  }
}

class SkeletonPill extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonPill({
    super.key,
    this.width = 86,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    return SkeletonBox(
      height: height,
      width: width,
      borderRadius: BorderRadius.circular(999),
    );
  }
}

class ChartSkeletonCard extends StatelessWidget {
  final double chartHeight;
  final double titleWidth;
  final double subtitleWidth;
  final bool showSubtitle;
  final bool showBadge;
  final int filterPills;
  final int legendItems;

  const ChartSkeletonCard({
    super.key,
    required this.chartHeight,
    this.titleWidth = 220,
    this.subtitleWidth = 160,
    this.showSubtitle = true,
    this.showBadge = false,
    this.filterPills = 0,
    this.legendItems = 0,
  });

  @override
  Widget build(BuildContext context) {
    final List<Widget> filters = List<Widget>.generate(
      filterPills,
      (int index) => const SkeletonPill(),
    );
    final List<Widget> legends = List<Widget>.generate(
      legendItems,
      (int index) => const SkeletonLine(width: 90),
    );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                const SkeletonBox(
                  height: 10,
                  width: 10,
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: titleWidth),
                  child: SkeletonLine(width: titleWidth, height: 16),
                ),
                if (showBadge) const SkeletonPill(width: 70, height: 22),
              ],
            ),
            if (showSubtitle) ...<Widget>[
              const SizedBox(height: 8),
              SkeletonLine(width: subtitleWidth, height: 12),
            ],
            if (filters.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: filters),
            ],
            const SizedBox(height: 12),
            SkeletonBox(
              height: chartHeight,
              borderRadius: BorderRadius.circular(12),
            ),
            if (legends.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              Wrap(spacing: 10, runSpacing: 8, children: legends),
            ],
          ],
        ),
      ),
    );
  }
}
