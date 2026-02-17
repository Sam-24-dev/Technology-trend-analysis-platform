import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:universal_html/html.dart' as html;
import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
import '../services/csv_service.dart';
import '../models/github_models.dart';
import '../widgets/chart_card.dart';

class GithubDashboard extends StatefulWidget {
  const GithubDashboard({super.key});

  @override
  State<GithubDashboard> createState() => _GithubDashboardState();
}

class _GithubDashboardState extends State<GithubDashboard> {
  List<LenguajeModel> lenguajes = [];
  List<FrameworkCommitModel> frameworks = [];
  List<CorrelacionModel> correlacion = [];
  bool isLoading = true;

  // Colores distintivos para cada lenguaje (todos diferentes)
  final List<Color> distinctColors = [
    const Color(0xFF3776AB), // Python - azul oficial
    const Color(0xFF2D79C7), // TypeScript - azul diferente
    const Color(0xFF10B981), // LLMs/AI - verde esmeralda
    const Color(0xFFF7DF1E), // JavaScript - amarillo
    const Color(0xFF00ADD8), // Go - cyan
    const Color(0xFFDEA584), // Rust - naranja/cobre
    const Color(0xFFF37626), // Jupyter - naranja brillante
    const Color(0xFF7F52FF), // Kotlin - púrpura
    const Color(0xFF00599C), // C++ - azul oscuro
    const Color(0xFF4EAA25), // Shell - verde
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String? errorMessage;

  Future<void> _loadData() async {
    try {
      try {
        final lenguajesData = await CsvService.loadCsvAsMap('assets/data/github_lenguajes.csv');
        lenguajes = lenguajesData.map((e) => LenguajeModel.fromMap(e)).take(5).toList();
      } catch (e) {
        print('Error cargando github_lenguajes.csv: $e');
      }

      try {
        final frameworksData = await CsvService.loadCsvAsMap('assets/data/github_commits_frameworks.csv');
        frameworks = frameworksData.map((e) => FrameworkCommitModel.fromMap(e)).toList();
      } catch (e) {
        print('Error cargando github_commits_frameworks.csv: $e');
      }

      try {
        final correlacionData = await CsvService.loadCsvAsMap('assets/data/github_correlacion.csv');
        correlacion = correlacionData.map((e) => CorrelacionModel.fromMap(e)).toList();
      } catch (e) {
        print('Error cargando github_correlacion.csv: $e');
      }

      if (lenguajes.isEmpty && frameworks.isEmpty && correlacion.isEmpty) {
        throw Exception('No se cargaron datos. Verifique logs.');
      }

      setState(() => isLoading = false);
    } catch (e, stackTrace) {
      print('Error cargando datos: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e\n$stackTrace';
      });
    }
  }

  void _exportDataAsZip() {
    // CSV 1: Lenguajes
    String csv1 = 'lenguaje,repos_count,porcentaje\n';
    for (var lang in lenguajes) {
      csv1 += '${lang.lenguaje},${lang.reposCount},${lang.porcentaje}\n';
    }
    
    // CSV 2: Frameworks
    String csv2 = 'framework,commits_2025\n';
    for (var fw in frameworks) {
      csv2 += '${fw.framework},${fw.commits2025}\n';
    }
    
    // CSV 3: Correlación
    String csv3 = 'repo_name,stars,contributors,language\n';
    for (var item in correlacion) {
      csv3 += '${item.repoName},${item.stars},${item.contributors},${item.language}\n';
    }
    
    // Crear ZIP
    final archive = Archive();
    archive.addFile(ArchiveFile('1_lenguajes_top10.csv', csv1.length, utf8.encode(csv1)));
    archive.addFile(ArchiveFile('2_commits_frameworks.csv', csv2.length, utf8.encode(csv2)));
    archive.addFile(ArchiveFile('3_correlacion_stars_contributors.csv', csv3.length, utf8.encode(csv3)));
    
    final zipData = ZipEncoder().encode(archive);
    if (zipData != null) {
      final blob = html.Blob([zipData], 'application/zip');
      final url = html.Url.createObjectUrlFromBlob(blob);
      html.AnchorElement(href: url)
        ..setAttribute('download', 'github_dashboard_data.zip')
        ..click();
      html.Url.revokeObjectUrl(url);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SelectableText(
            errorMessage!,
            style: const TextStyle(color: Colors.red, fontSize: 16),
          ),
        ),
      );
    }


    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Dashboard GitHub',
                      style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Análisis de tendencias tecnológicas 2025',
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              ElevatedButton.icon(
                onPressed: _exportDataAsZip,
                icon: const Icon(Icons.folder_zip, size: 18),
                label: const Text('Exportar ZIP'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, // Blue
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Análisis de tendencias tecnológicas 2025',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 24),

          // KEY INSIGHTS SECTION 
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6), // Gris claro
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                // Insight 1: Python
                _buildGithubInsightCard(
                  'assets/images/python_logo.png',
                  'Python lidera con ${lenguajes.isNotEmpty ? lenguajes.first.reposCount : 0} repos nuevos',
                  '${lenguajes.isNotEmpty ? lenguajes.first.porcentaje.toStringAsFixed(1) : 0}% del total de repositorios analizados',
                  const Color(0xFF3776AB), // Python blue
                ),
                const SizedBox(height: 12),
                // Insight 2: Angular
                _buildGithubInsightCard(
                  'assets/images/angular_logo.png',
                  _getFrameworkInsight(),
                  'Basado en commits de 2025 en repositorios oficiales',
                  const Color(0xFFDD0031), // Angular red
                ),
                const SizedBox(height: 12),
                // Insight 3: Correlación
                _buildGithubInsightCardIcon(
                  Icons.show_chart,
                  'Correlación Stars-Contributors: ${_calculateCorrelation().toStringAsFixed(2)}',
                  'Relación entre popularidad y contribuidores activos',
                  const Color(0xFF059669), // Green
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Gráfico 1
          ChartCard(
            title: '5 Lenguajes con más repositorios nuevos en 2025',
            subtitle: 'Top 5 lenguajes por creación de repositorios',
            height: 420,
            chart: _buildHorizontalBarChart(),
          ),
          const SizedBox(height: 24),

          // Gráfico 2
          ChartCard(
            title: 'Distribución de Commits por Framework Frontend',
            subtitle: 'Proporción de actividad: Angular vs React vs Vue',
            height: 320,
            chart: _buildFrameworkPieChart(),
          ),
          const SizedBox(height: 24),

          // Gráfico 3
          ChartCard(
            title: 'Correlación entre Stars y Contributors',
            subtitle: 'Coeficiente de correlación (r = ${_calculateCorrelation().toStringAsFixed(2)}) - 100 repos top de 2025',
            height: 450,
            chart: _buildScatterChart(),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // Gráfico 1: Barras HORIZONTALES
  // Eje Y = Lenguajes, Eje X = 0-400, Python arriba (mayor valor)
  Widget _buildHorizontalBarChart() {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Eje Y - Nombres de lenguajes
            SizedBox(
              width: 100,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: lenguajes.map((lang) => 
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      lang.lenguaje,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.right,
                    ),
                  )
                ).toList(),
              ),
            ),
            // Gráfico de barras
            Expanded(
              child: Column(
                children: [
                  // Barras
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: lenguajes.asMap().entries.map((entry) {
                        final index = entry.key;
                        final item = entry.value;
                        final widthPercent = item.reposCount / 400;
                        return Tooltip(
                          message: '${item.lenguaje}: ${item.reposCount} repos',
                          child: Container(
                            height: 28,
                            width: constraints.maxWidth * 0.75 * widthPercent,
                            decoration: BoxDecoration(
                              color: distinctColors[index % distinctColors.length],
                              borderRadius: const BorderRadius.horizontal(right: Radius.circular(4)),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  // Eje X - Valores 0 a 400
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [0, 100, 200, 300, 400].map((val) => 
                      Text(
                        val.toString(),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      )
                    ).toList(),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // Gráfico 2: Pie/Donut Chart para frameworks
  Widget _buildFrameworkPieChart() {
    final total = frameworks.fold<int>(0, (sum, f) => sum + f.commits2025);
    
    final colors = [
      const Color(0xFFDD0031), // Angular red
      const Color(0xFF61DAFB), // React blue
      const Color(0xFF42B883), // Vue green
    ];

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 50,
              sections: frameworks.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                final percentage = (item.commits2025 / total * 100);
                return PieChartSectionData(
                  color: colors[index % colors.length],
                  value: item.commits2025.toDouble(),
                  title: '${percentage.toStringAsFixed(1)}%',
                  radius: 80,
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: frameworks.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: colors[index % colors.length],
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.framework,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Text(
                            '${item.commits2025.toString().replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')} commits',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Gráfico 3: Scatter Plot
  Widget _buildScatterChart() {
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0;
    int n = correlacion.length;
    
    for (var item in correlacion) {
      sumX += item.stars;
      sumY += item.contributors;
      sumXY += item.stars * item.contributors;
      sumX2 += item.stars * item.stars;
    }
    
    double slope = n > 0 && (n * sumX2 - sumX * sumX) != 0 
        ? (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX) 
        : 0;
    double intercept = n > 0 ? (sumY - slope * sumX) / n : 0;

    final maxStars = 110000.0;
    final maxContributors = 800.0;

    List<FlSpot> trendSpots = [
      FlSpot(0, intercept.clamp(0, maxContributors)),
      FlSpot(maxStars, (slope * maxStars + intercept).clamp(0, maxContributors)),
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 16),
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: maxStars,
          minY: 0,
          maxY: maxContributors,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (spots) => spots.map((spot) {
                if (spot.barIndex == 0) {
                  final repo = correlacion.firstWhere(
                    (r) => r.stars == spot.x.toInt() && r.contributors == spot.y.toInt(),
                    orElse: () => CorrelacionModel(repoName: '', stars: spot.x.toInt(), contributors: spot.y.toInt(), language: ''),
                  );
                  return LineTooltipItem(
                    '${repo.repoName.isNotEmpty ? repo.repoName.split('/').last : ''}\n⭐ ${spot.x.toInt()} | 👥 ${spot.y.toInt()}',
                    const TextStyle(color: Colors.white, fontSize: 11),
                  );
                }
                return null;
              }).toList(),
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              axisNameWidget: const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text('Stars', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              axisNameSize: 35,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 35,
                interval: 20000,
                getTitlesWidget: (value, meta) {
                  if (value == 0) return const Padding(padding: EdgeInsets.only(top: 8), child: Text('0', style: TextStyle(fontSize: 10)));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text('${(value / 1000).toStringAsFixed(0)}k', style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text('Contributors', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              axisNameSize: 35,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 45,
                interval: 200,
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border(
              left: BorderSide(color: Colors.grey.shade400),
              bottom: BorderSide(color: Colors.grey.shade400),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawHorizontalLine: true,
            drawVerticalLine: true,
            horizontalInterval: 200,
            verticalInterval: 20000,
            getDrawingHorizontalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            getDrawingVerticalLine: (value) => FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: correlacion.map((item) => FlSpot(item.stars.toDouble(), item.contributors.toDouble())).toList(),
              isCurved: false,
              color: Colors.transparent,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 5,
                    color: const Color(0xFF6366F1).withOpacity(0.7),
                    strokeWidth: 1.5,
                    strokeColor: const Color(0xFF6366F1),
                  );
                },
              ),
            ),
            LineChartBarData(
              spots: trendSpots,
              isCurved: false,
              color: const Color(0xFFEF4444),
              barWidth: 2,
              dotData: const FlDotData(show: false),
              dashArray: [8, 4],
            ),
          ],
        ),
      ),
    );
  }

  // Calcular insight de frameworks
  String _getFrameworkInsight() {
    if (frameworks.isEmpty) return 'Sin datos de frameworks';
    
    frameworks.sort((a, b) => b.commits2025.compareTo(a.commits2025));
    final leader = frameworks.first;
    final total = frameworks.fold<int>(0, (sum, f) => sum + f.commits2025);
    final percentage = (leader.commits2025 / total * 100).toStringAsFixed(0);
    
    return '${leader.framework} lidera con $percentage% de los commits totales de frameworks frontend';
  }

  // Calcular coeficiente de correlación de Pearson
  double _calculateCorrelation() {
    if (correlacion.isEmpty) return 0.0;
    
    int n = correlacion.length;
    double sumX = 0, sumY = 0, sumXY = 0, sumX2 = 0, sumY2 = 0;
    
    for (var item in correlacion) {
      double x = item.stars.toDouble();
      double y = item.contributors.toDouble();
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
      sumY2 += y * y;
    }
    
    double numerator = n * sumXY - sumX * sumY;
    double denomX = n * sumX2 - sumX * sumX;
    double denomY = n * sumY2 - sumY * sumY;
    
    if (denomX <= 0 || denomY <= 0) return 0.0;
    
    double denominator = sqrt(denomX * denomY);
    return numerator / denominator;
  }

  // Widget con imagen de logo
  Widget _buildGithubInsightCard(String imagePath, String title, String description, Color accentColor) {
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
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imagePath,
                fit: BoxFit.contain,
              ),
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

  // Widget con icono de Material
  Widget _buildGithubInsightCardIcon(IconData icon, String title, String description, Color accentColor) {
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
        crossAxisAlignment: CrossAxisAlignment.center,
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
}
