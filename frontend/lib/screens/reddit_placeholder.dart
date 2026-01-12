import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/reddit_models.dart';
import '../services/csv_service.dart';
import '../widgets/chart_card.dart';

class RedditPlaceholder extends StatefulWidget {
  const RedditPlaceholder({super.key});

  @override
  State<RedditPlaceholder> createState() => _RedditPlaceholderState();
}

class _RedditPlaceholderState extends State<RedditPlaceholder> {
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
      // Cargar Sentimiento
      final sentimientoCsv =
          await CsvService.loadCsvAsMap('assets/data/reddit_sentimiento_frameworks.csv');
      // Cargar Temas Emergentes
      final temasCsv =
          await CsvService.loadCsvAsMap('assets/data/reddit_temas_emergentes.csv');
      // Cargar Intersección
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

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Dashboard Reddit',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Análisis de sentimientos y tendencias en comunidades de tecnología',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 32),
            // Gráfico 1: Sentimiento de Frameworks
            ChartCard(
              title: 'Sentimiento de Frameworks Backend',
              subtitle: 'Análisis de sentimiento positivo y negativo en Reddit',
              height: 400,
              chart: _buildSentimientoChart(),
            ),
            const SizedBox(height: 24),
            // Gráfico 2: Temas Emergentes
            ChartCard(
              title: 'Temas Emergentes',
              subtitle: 'Tendencias más mencionadas en comunidades tecnológicas',
              height: 400,
              chart: _buildTemasChart(),
            ),
            const SizedBox(height: 24),
            // Gráfico 3: Intersección GitHub-Reddit
            ChartCard(
              title: 'Intersección GitHub vs Reddit',
              subtitle: 'Ranking de tecnologías en ambas plataformas',
              height: 400,
              chart: _buildInterseccionChart(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimientoChart() {
    if (sentimientoData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    return BarChart(
      BarChartData(
        barGroups: List.generate(
          sentimientoData.length,
          (index) {
            final item = sentimientoData[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                // Barra negativa (izquierda)
                BarChartRodData(
                  toY: -item.porcentajeNegativo,
                  color: const Color(0xFFEF4444),
                  width: 20,
                ),
                // Barra positiva (derecha)
                BarChartRodData(
                  toY: item.porcentajePositivo,
                  color: const Color(0xFF10B981),
                  width: 20,
                ),
              ],
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    sentimientoData[value.toInt()].framework,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}%', style: const TextStyle(fontSize: 10));
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

    return BarChart(
      BarChartData(
        barGroups: List.generate(
          sortedData.length,
          (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: sortedData[index].menciones.toDouble(),
                  color: const Color(0xFFFF4500),
                  width: 24,
                ),
              ],
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(
                  sortedData[value.toInt()].tema,
                  style: const TextStyle(fontSize: 12),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString());
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
      ),
    );
  }

  Widget _buildInterseccionChart() {
    if (interseccionData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    // Filtrar solo los datos que tienen ambos rankings
    final datosValidos = interseccionData
        .where((item) => item.rankingGitHub != null && item.rankingReddit != null)
        .toList();

    if (datosValidos.isEmpty) {
      return const Center(child: Text('No hay datos con ambos rankings disponibles'));
    }

    return BarChart(
      BarChartData(
        barGroups: List.generate(
          datosValidos.length,
          (index) {
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: datosValidos[index].rankingGitHub!.toDouble(),
                  color: const Color(0xFF3B82F6),
                  width: 18,
                ),
                BarChartRodData(
                  toY: datosValidos[index].rankingReddit!.toDouble(),
                  color: const Color(0xFFFF4500),
                  width: 18,
                ),
              ],
            );
          },
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    datosValidos[value.toInt()].tecnologia,
                    style: const TextStyle(fontSize: 11),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('#${value.toInt()}', style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: true, drawVerticalLine: false),
      ),
    );
  }
}
