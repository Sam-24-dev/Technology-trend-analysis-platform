import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:html' as html;
import 'dart:convert';
import 'package:archive/archive.dart';
import '../models/reddit_models.dart';
import '../services/csv_service.dart';
import '../widgets/chart_card.dart';

class RedditDashboard extends StatefulWidget {
  const RedditDashboard({super.key});

  @override
  State<RedditDashboard> createState() => _RedditDashboardState();
}

class _RedditDashboardState extends State<RedditDashboard> {
  List<SentimientoModel> sentimientoData = [];
  List<TemasEmergentesModel> temasData = [];
  List<InterseccionModel> interseccionData = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final sentimientoCsv =
          await CsvService.loadCsvAsMap('assets/data/reddit_sentimiento_frameworks.csv');
      final temasCsv =
          await CsvService.loadCsvAsMap('assets/data/reddit_temas_emergentes.csv');
      final interseccionCsv = await CsvService.loadCsvAsMap(
          'assets/data/interseccion_github_reddit.csv');

      setState(() {
        sentimientoData = sentimientoCsv
            .map((e) => SentimientoModel.fromMap(e))
            .toList();
        temasData =
            temasCsv.map((e) => TemasEmergentesModel.fromMap(e)).toList();
        interseccionData = interseccionCsv
            .map((e) => InterseccionModel.fromMap(e))
            .toList();
        isLoading = false;
      });
    } catch (e) {
      print('Error cargando datos: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con título y botón exportar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dashboard Reddit',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              ElevatedButton.icon(
                onPressed: _exportDataAsZip,
                icon: const Icon(Icons.folder_zip, size: 18),
                label: const Text('Exportar ZIP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF4500), // Reddit orange
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Análisis de sentimientos y tendencias en comunidades de tecnología 2025',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),
          // Key Insights Section
          _buildKeyInsightsSection(),
          const SizedBox(height: 32),
          // Gráfico 1: Sentimiento de Frameworks
          ChartCard(
            title: 'Sentimiento de Frameworks Backend',
            subtitle: 'Porcentaje de opiniones positivas (verde) y negativas (rojo) en Reddit',
            height: 400,
            chart: _buildSentimientoChart(),
          ),
          const SizedBox(height: 24),
          // Gráfico 2: Temas Emergentes
          ChartCard(
            title: 'Temas Emergentes',
            subtitle: 'Tendencias más mencionadas en comunidades tecnológicas',
            height: 450,
            chart: _buildTemasChart(),
          ),
          const SizedBox(height: 24),
          // Gráfico 3: Intersección GitHub-Reddit
          ChartCard(
            title: 'Intersección GitHub vs Reddit',
            subtitle: 'Comparación de ranking de popularidad en ambas plataformas',
            height: 400,
            chart: _buildInterseccionChart(),
          ),
          const SizedBox(height: 16),
          // Leyenda para Gráfico 3
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(const Color(0xFF3B82F6), 'Ranking GitHub'),
              const SizedBox(width: 24),
              _buildLegend(const Color(0xFFFF4500), 'Ranking Reddit'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSentimientoChart() {
    if (sentimientoData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Ordenar por % positivo descendente
    final sortedData = List<SentimientoModel>.from(sentimientoData)
      ..sort((a, b) => b.porcentajePositivo.compareTo(a.porcentajePositivo));

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 100,
        minY: -30,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = sortedData[group.x.toInt()];
              final isPositive = rodIndex == 1;
              return BarTooltipItem(
                '${_capitalizeFramework(item.framework)}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: isPositive 
                        ? '${item.porcentajePositivo.toStringAsFixed(1)}% Positivo'
                        : '${item.porcentajeNegativo.toStringAsFixed(1)}% Negativo',
                    style: TextStyle(
                      color: isPositive ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: List.generate(
          sortedData.length,
          (index) {
            final item = sortedData[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                // Barra negativa
                BarChartRodData(
                  toY: -item.porcentajeNegativo,
                  color: const Color(0xFFEF4444),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(4)),
                ),
                // Barra positiva
                BarChartRodData(
                  toY: item.porcentajePositivo,
                  color: const Color(0xFF10B981),
                  width: 22,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _capitalizeFramework(sortedData[value.toInt()].framework),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: 20,
              getTitlesWidget: (value, meta) {
                return Text(
                  '${value.toInt()}%',
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildTemasChart() {
    if (temasData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final sortedData = List<TemasEmergentesModel>.from(temasData)
      ..sort((a, b) => b.menciones.compareTo(a.menciones));
    
    final maxMenciones = sortedData.first.menciones.toDouble();

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: maxMenciones * 1.1,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = sortedData[group.x.toInt()];
              return BarTooltipItem(
                '${_formatTema(item.tema)}\n${item.menciones} menciones',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              );
            },
          ),
        ),
        barGroups: List.generate(
          sortedData.length,
          (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: sortedData[index].menciones.toDouble(),
                  color: const Color(0xFFFF4500),
                  width: 28,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 80,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < sortedData.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: RotatedBox(
                      quarterTurns: -1,
                      child: Text(
                        _formatTema(sortedData[value.toInt()].tema),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                        textAlign: TextAlign.left,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildInterseccionChart() {
    if (interseccionData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final datosValidos = interseccionData
        .where((item) => item.rankingGitHub != null && item.rankingReddit != null)
        .toList();

    if (datosValidos.isEmpty) {
      return const Center(child: Text('No hay datos con ambos rankings disponibles'));
    }

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: 11,
        minY: 0,
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final item = datosValidos[group.x.toInt()];
              final isGitHub = rodIndex == 0;
              return BarTooltipItem(
                '${_capitalizeFramework(item.tecnologia)}\n',
                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                children: [
                  TextSpan(
                    text: isGitHub 
                        ? 'GitHub: #${item.rankingGitHub}'
                        : 'Reddit: #${item.rankingReddit}',
                    style: TextStyle(
                      color: isGitHub ? const Color(0xFF3B82F6) : const Color(0xFFFF4500),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        barGroups: List.generate(
          datosValidos.length,
          (index) {
            final item = datosValidos[index];
            // Invertir: ranking 1 = barra alta (10), ranking 10 = barra baja (1)
            final githubHeight = (11 - item.rankingGitHub!).toDouble();
            final redditHeight = (11 - item.rankingReddit!).toDouble();
            
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: githubHeight,
                  color: const Color(0xFF3B82F6),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
                BarChartRodData(
                  toY: redditHeight,
                  color: const Color(0xFFFF4500),
                  width: 20,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
            );
          },
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value.toInt() >= 0 && value.toInt() < datosValidos.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _capitalizeFramework(datosValidos[value.toInt()].tecnologia),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 35,
              interval: 1,
              getTitlesWidget: (value, meta) {
                // Mostrar como ranking: 10 arriba = #1, 1 abajo = #10
                final ranking = 11 - value.toInt();
                if (ranking >= 1 && ranking <= 10) {
                  return Text(
                    '#$ranking',
                    style: const TextStyle(fontSize: 10),
                  );
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 16, height: 16, decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(4),
        )),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(fontWeight: FontWeight.w500)),
      ],
    );
  }

  String _capitalizeFramework(String name) {
    final Map<String, String> capitalizations = {
      'django': 'Django',
      'laravel': 'Laravel',
      'express': 'Express',
      'spring': 'Spring',
      'fastapi': 'FastAPI',
      'python': 'Python',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
    };
    return capitalizations[name.toLowerCase()] ?? name;
  }

  String _formatTema(String tema) {
    // Cambiar IA por AI y formatear correctamente
    return tema
        .replaceAll('IA/Machine Learning', 'AI/ML')
        .replaceAll('IA', 'AI');
  }

  // ========== KEY INSIGHTS AND EXPORT FUNCTIONS ==========

  Widget _buildKeyInsightsSection() {
    // Calcular insight 1: Tema más mencionado
    String temaTopico = 'AI/Machine Learning';
    int menciones = 0;
    if (temasData.isNotEmpty) {
      temasData.sort((a, b) => b.menciones.compareTo(a.menciones));
      temaTopico = temasData.first.tema;
      menciones = temasData.first.menciones;
    }

    // Calcular insight 2: Framework con mejor sentimiento
    String frameworkTopico = 'Express';
    double sentimientoMax = 0;
    if (sentimientoData.isNotEmpty) {
      sentimientoData.sort((a, b) => b.porcentajePositivo.compareTo(a.porcentajePositivo));
      frameworkTopico = sentimientoData.first.framework;
      sentimientoMax = sentimientoData.first.porcentajePositivo;
    }

    // Calcular insight 3: Tendencia de intersección
    int tecnologiasEnAmbas = interseccionData.length;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6), // Gris claro
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: const [
              Icon(Icons.insights, color: Color(0xFF374151), size: 28),
              SizedBox(width: 12),
              Text(
                'Key Insights',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Insight 1: Tema más mencionado - ChatGPT logo (AI/ML tema)
          _buildInsightCardImage(
            'assets/images/chatgpt-logo.png',
            'Tema Emergente Dominante',
            '$temaTopico lideran con $menciones menciones',
            const Color(0xFF1A1A1A), // ChatGPT black
          ),
          const SizedBox(height: 12),
          // Insight 2: Framework con mejor sentimiento - Django logo
          _buildInsightCardImage(
            'assets/images/django-logo.png',
            'Framework Mejor Valorado',
            '$frameworkTopico con ${sentimientoMax.toStringAsFixed(1)}% sentimiento positivo',
            const Color(0xFF092E20), // Django green
          ),
          const SizedBox(height: 12),
          // Insight 3: Cobertura multi-plataforma - Mantener icono
          _buildInsightCardIcon(
            Icons.hub,
            'Tendencias Multi-plataforma',
            '$tecnologiasEnAmbas tecnologías populares en GitHub y Reddit',
            const Color(0xFF7C3AED), // Purple
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCardIcon(IconData icon, String title, String description, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Widget con imagen de logo
  Widget _buildInsightCardImage(String imagePath, String title, String description, Color accentColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(imagePath, fit: BoxFit.contain),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _exportDataAsZip() {
    // CSV 1: Sentimiento de Frameworks
    String csv1 = 'Framework,Porcentaje Positivo,Porcentaje Negativo\n';
    for (var item in sentimientoData) {
      csv1 += '${item.framework},${item.porcentajePositivo},${item.porcentajeNegativo}\n';
    }

    // CSV 2: Temas Emergentes
    String csv2 = 'Tema,Menciones\n';
    for (var item in temasData) {
      csv2 += '${item.tema},${item.menciones}\n';
    }

    // CSV 3: Intersección GitHub-Reddit
    String csv3 = 'Tecnologia,Ranking GitHub,Ranking Reddit\n';
    for (var item in interseccionData) {
      csv3 += '${item.tecnologia},${item.rankingGitHub},${item.rankingReddit}\n';
    }

    // Crear ZIP
    final archive = Archive();
    archive.addFile(ArchiveFile('1_sentimiento_frameworks.csv', csv1.length, utf8.encode(csv1)));
    archive.addFile(ArchiveFile('2_temas_emergentes.csv', csv2.length, utf8.encode(csv2)));
    archive.addFile(ArchiveFile('3_interseccion_github_reddit.csv', csv3.length, utf8.encode(csv3)));

    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      final blob = html.Blob([zipData], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'reddit_dashboard_data.zip')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }
}
