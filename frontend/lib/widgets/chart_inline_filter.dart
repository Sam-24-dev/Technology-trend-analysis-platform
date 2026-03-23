import 'package:flutter/material.dart';

class ChartInlineFilter<T> extends StatelessWidget {
  const ChartInlineFilter({
    super.key,
    required this.label,
    required this.value,
    required this.selectedLabel,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final String selectedLabel;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 320;
          final Widget dropdown = DropdownButtonHideUnderline(
            child: DropdownButton<T>(
              isDense: true,
              isExpanded: compact,
              value: value,
              items: items,
              selectedItemBuilder: (_) => items
                  .map(
                    (_) => Text(
                      selectedLabel,
                      maxLines: 1,
                      overflow: TextOverflow.fade,
                      softWrap: false,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              icon: const Icon(
                Icons.arrow_drop_down_rounded,
                size: 18,
                color: Color(0xFF64748B),
              ),
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
              ),
            ),
          );

          final Text labelText = Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          );

          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                labelText,
                const SizedBox(height: 2),
                SizedBox(width: constraints.maxWidth, child: dropdown),
              ],
            );
          }

          return Wrap(
            spacing: 4,
            runSpacing: 2,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              labelText,
              dropdown,
            ],
          );
        },
      ),
    );
  }
}
