import 'package:flutter/material.dart';

class DegradedStateCard extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const DegradedStateCard({super.key, required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Estado degradado de datos',
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(top: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF3C7),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFF59E0B), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Row(
              children: <Widget>[
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Color(0xFF92400E),
                ),
                SizedBox(width: 8),
                Text(
                  'Modo degradado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF92400E),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              message,
              style: const TextStyle(fontSize: 12, color: Color(0xFF92400E)),
            ),
            if (onRetry != null) ...<Widget>[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 14),
                label: const Text('Reintentar'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF92400E),
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
