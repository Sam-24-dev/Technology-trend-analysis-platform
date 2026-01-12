import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/stackoverflow_models.dart';
import '../services/csv_service.dart';
import '../widgets/chart_card.dart';

class StackOverflowDashboard extends StatefulWidget {
  const StackOverflowDashboard({super.key});

  @override
  State<StackOverflowDashboard> createState() => _StackOverflowDashboardState();
}

class _StackOverflowDashboardState extends State<StackOverflowDashboard> {
  List<VolumenPreguntasModel> volumenData = [];
  List<TasaAceptacionModel> aceptacionData = [];
  List<TendenciaMensualModel> tendenciasData = [];

  bool isLoading = true;

  final Color soOrange = const Color(0xFFF48024);
  final Color colorPython = const Color(0xFF3776AB);
  final Color colorJS = const Color(0xFFF7DF1E);
  final Color colorTS = const Color(0xFF2D79C7);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final volRaw = await CsvService.loadCsvAsMap(
        'assets/data/so_volumen_preguntas.csv',
      );
      volumenData = volRaw
          .map((e) => VolumenPreguntasModel.fromMap(e))
          .toList();

      volumenData.sort((a, b) => b.preguntas.compareTo(a.preguntas));

      final acepRaw = await CsvService.loadCsvAsMap(
        'assets/data/so_tasa_aceptacion.csv',
      );
      aceptacionData = acepRaw
          .map((e) => TasaAceptacionModel.fromMap(e))
          .toList();

      final trendRaw = await CsvService.loadCsvAsMap(
        'assets/data/so_tendencias_mensuales.csv',
      );
      tendenciasData = trendRaw
          .map((e) => TendenciaMensualModel.fromMap(e))
          .toList();

      setState(() => isLoading = false);
    } catch (e) {
      debugPrint("Error cargando datos: $e");
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard StackOverflow',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF2D2D2D),
            ),
          ),
          const Text(
            'Análisis de preguntas, madurez y tendencias 2025',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          const SizedBox(height: 32),

          ChartCard(
            title: 'Volumen de Preguntas Nuevas 2025',
            subtitle: 'Lenguajes con mayor actividad reciente en la plataforma',
            height: 400,
            chart: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (volumenData.firstOrNull?.preguntas.toDouble() ?? 1000) *
                    1.4,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => Colors.blueGrey,
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < volumenData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              _capitalizeFramework(volumenData[value.toInt()].lenguaje),
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 60),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                borderData: FlBorderData(show: false),
                barGroups: volumenData.asMap().entries.map((entry) {
                  return BarChartGroupData(
                    x: entry.key,
                    barRods: [
                      BarChartRodData(
                        toY: entry.value.preguntas.toDouble(),
                        color: soOrange,
                        width: 22,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(6),
                          topRight: Radius.circular(6),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),

          const SizedBox(height: 24),

          ChartCard(
            title: 'Tasa de Respuestas Aceptadas',
            subtitle:
                '% de preguntas con solución verificada (Verde = Aceptada)',
            height: 450,
            chart: RotatedBox(
              quarterTurns: 1,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 100,
                  barTouchData: BarTouchData(
                    enabled: false, // Desactivado - el % ya se muestra a la izquierda
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 90,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 &&
                              value.toInt() < aceptacionData.length) {
                            final item = aceptacionData[value.toInt()];
                            return RotatedBox(
                              quarterTurns: -1,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _capitalizeFramework(item.tecnologia),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    "${item.tasaPct.toStringAsFixed(1)}%",
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: aceptacionData.asMap().entries.map((entry) {
                    final pct = entry.value.tasaPct;
                    return BarChartGroupData(
                      x: entry.key,
                      barRods: [
                        BarChartRodData(
                          toY: 100,
                          rodStackItems: [
                            BarChartRodStackItem(
                              0,
                              pct,
                              const Color(0xFF10B981),
                            ),
                            BarChartRodStackItem(
                              pct,
                              100,
                              const Color(0xFFEF4444),
                            ),
                          ],
                          color: Colors.transparent,
                          width: 24,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          ChartCard(
            title: 'Tendencias Evolutivas 2025',
            subtitle:
                'Comparativa mensual de volumen de preguntas: Python vs JS vs TS',
            height: 400,
            chart: LineChart(
              LineChartData(
                gridData: const FlGridData(show: true, drawVerticalLine: false),
                titlesData: FlTitlesData(
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      interval: 1,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() >= 0 &&
                            value.toInt() < tendenciasData.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              tendenciasData[value.toInt()].mes,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: true, reservedSize: 40),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: tendenciasData
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(
                            e.key.toDouble(),
                            e.value.python.toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    color: colorPython,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: tendenciasData
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(
                            e.key.toDouble(),
                            e.value.javascript.toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    color: colorJS,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                  LineChartBarData(
                    spots: tendenciasData
                        .asMap()
                        .entries
                        .map(
                          (e) => FlSpot(
                            e.key.toDouble(),
                            e.value.typescript.toDouble(),
                          ),
                        )
                        .toList(),
                    isCurved: true,
                    color: colorTS,
                    barWidth: 3,
                    dotData: const FlDotData(show: false),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegend(colorPython, 'Python'),
              const SizedBox(width: 16),
              _buildLegend(colorJS, 'JavaScript'),
              const SizedBox(width: 16),
              _buildLegend(colorTS, 'TypeScript'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  // Capitalizar nombres de frameworks correctamente
  String _capitalizeFramework(String name) {
    final Map<String, String> capitalizations = {
      'reactjs': 'ReactJS',
      'vue.js': 'Vue.js',
      'angular': 'Angular',
      'next.js': 'Next.js',
      'svelte': 'Svelte',
      'python': 'Python',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'java': 'Java',
      'go': 'Go',
    };
    return capitalizations[name.toLowerCase()] ?? name;
  }
}
