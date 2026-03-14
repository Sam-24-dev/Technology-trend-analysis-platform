import 'package:flutter/material.dart';

enum DegradedSeverity { warning, unavailable, cached }

class DegradedStateCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  final DegradedSeverity severity;
  final String? cachedAge;

  const DegradedStateCard({
    super.key,
    required this.message,
    this.onRetry,
    this.severity = DegradedSeverity.warning,
    this.cachedAge,
  });

  ({Color background, Color border, Color text, IconData icon, String label})
  _resolveStyle() {
    switch (severity) {
      case DegradedSeverity.unavailable:
        return (
          background: const Color(0xFFFFF1F2),
          border: const Color(0xFFDC2626),
          text: const Color(0xFF991B1B),
          icon: Icons.wifi_off_rounded,
          label: 'Fuente no disponible',
        );
      case DegradedSeverity.cached:
        return (
          background: const Color(0xFFFEF7E7),
          border: const Color(0xFFF59E0B),
          text: const Color(0xFF92400E),
          icon: Icons.history_toggle_off_rounded,
          label: 'Datos cacheados',
        );
      case DegradedSeverity.warning:
        return (
          background: const Color(0xFFFFF7E6),
          border: const Color(0xFFF59E0B),
          text: const Color(0xFF92400E),
          icon: Icons.warning_amber_rounded,
          label: 'Modo degradado',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final style = _resolveStyle();
    return Semantics(
      label: 'Estado degradado de datos',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: style.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: style.border.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: style.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(style.icon, size: 18, color: style.text),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    style.label,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: style.text,
                    ),
                  ),
                ),
                if (cachedAge != null && cachedAge!.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: style.border.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'cache: $cachedAge',
                      style: textTheme.labelSmall?.copyWith(
                        color: style.text,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: textTheme.bodyMedium?.copyWith(
                color: style.text,
                height: 1.35,
              ),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reintentar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: style.text,
                  side: BorderSide(color: style.border),
                  backgroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
