import 'package:flutter/material.dart';

class TrendsTechScreen extends StatelessWidget {
  final String technology;

  const TrendsTechScreen({super.key, required this.technology});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                'Trend Detail',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Tecnologia: $technology',
                style: const TextStyle(fontSize: 16, color: Color(0xFF374151)),
              ),
              const SizedBox(height: 16),
              const Text(
                'Este detalle se expandira en siguientes fases con comparativas historicas y metadatos por tecnologia.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
