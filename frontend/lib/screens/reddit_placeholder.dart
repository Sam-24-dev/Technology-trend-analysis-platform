import 'package:flutter/material.dart';

class RedditPlaceholder extends StatelessWidget {
  const RedditPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.forum, size: 100, color: Colors.deepOrange.shade300),
          const SizedBox(height: 24),
          const Text(
            'Dashboard Reddit',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Responsable: Mateo Mayorga',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.deepOrange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.deepOrange.shade200),
            ),
            child: const Text(
              'PENDIENTE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.deepOrange,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Preguntas a visualizar:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          const Text('1. Analisis de sentimiento frameworks'),
          const Text('2. Temas emergentes en r/webdev'),
          const Text('3. Interseccion GitHub vs Reddit'),
        ],
      ),
    );
  }
}
