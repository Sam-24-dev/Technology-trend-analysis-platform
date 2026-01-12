import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titulo principal
          const Text(
            'Tech Trends 2025',
            style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Análisis Integral de Tendencias Tecnológicas 2025',
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 40),
          
          // KPIs principales con iconos oficiales
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildKpiCardFA(
                icon: FontAwesomeIcons.github,
                value: '1,000',
                label: 'Total Repos Analizados',
                color: Colors.blue,
              ),
              _buildKpiCardFA(
                icon: FontAwesomeIcons.stackOverflow,
                value: '33,085',
                label: 'Preguntas Procesadas',
                color: const Color(0xFFF48024), // StackOverflow orange
              ),
              _buildKpiCardFA(
                icon: FontAwesomeIcons.reddit,
                value: '500',
                label: 'Posts de Reddit',
                color: const Color(0xFFFF4500), // Reddit orange
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          
          // Seccion Sobre el Dashboard
          const Text(
            'Sobre el Dashboard',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          
          Wrap(
            spacing: 24,
            runSpacing: 24,
            children: [
              _buildInfoCardFA(
                icon: FontAwesomeIcons.github,
                title: 'GitHub Data',
                description: 'Análisis de repositorios, lenguajes más populares y correlación entre stars y contribuidores',
                color: Colors.blue,
              ),
              _buildInfoCardFA(
                icon: FontAwesomeIcons.stackOverflow,
                title: 'StackOverflow Data',
                description: 'Madurez de tecnologías y evolución del interés en frameworks a lo largo del año',
                color: const Color(0xFFF48024),
              ),
              _buildInfoCardFA(
                icon: FontAwesomeIcons.reddit,
                title: 'Reddit Data',
                description: 'Sentimiento de la comunidad sobre frameworks backend y temas de discusión frecuentes',
                color: const Color(0xFFFF4500),
              ),
            ],
          ),
          
          const SizedBox(height: 48),
          
          // Integrantes
          const Text(
            'Integrantes del Equipo',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildTeamMemberFA('Samir Caizapasto', 'GitHub ETL & Dashboard', FontAwesomeIcons.github, Colors.blue),
          _buildTeamMemberFA('Andrés Salinas', 'StackOverflow ETL & Dashboard', FontAwesomeIcons.stackOverflow, const Color(0xFFF48024)),
          _buildTeamMemberFA('Mateo Mayorga', 'Reddit ETL & Dashboard', FontAwesomeIcons.reddit, const Color(0xFFFF4500)),
          
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildKpiCardFA({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 32, color: Colors.white.withOpacity(0.9)),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCardFA({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(
          top: BorderSide(color: color, width: 4),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FaIcon(icon, size: 20, color: color),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberFA(String name, String role, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.15),
            child: FaIcon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(role, style: const TextStyle(color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}
