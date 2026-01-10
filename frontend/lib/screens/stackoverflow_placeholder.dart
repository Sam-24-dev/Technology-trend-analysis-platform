import 'package:flutter/material.dart';

class StackoverflowPlaceholder extends StatelessWidget {
  const StackoverflowPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.question_answer, size: 100, color: Colors.orange.shade300),
          const SizedBox(height: 24),
          const Text(
            'Dashboard StackOverflow',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Responsable: Andres Salinas',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text(
              'PENDIENTE',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Preguntas a visualizar:',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          const Text('1. Volumen de preguntas por lenguaje'),
          const Text('2. Tasa de respuestas aceptadas'),
          const Text('3. Tendencias Python vs JS vs TS'),
        ],
      ),
    );
  }
}
