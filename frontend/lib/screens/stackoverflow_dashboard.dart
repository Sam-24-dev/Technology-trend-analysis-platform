import 'dart:convert'; // Para utf8 encode
import 'package:archive/archive.dart'; // Para crear el ZIP
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/dashboard_domain_models.dart';
import '../models/stackoverflow_models.dart';
import '../providers/app_providers.dart';
import '../services/download/download_service.dart';
import '../widgets/chart_card.dart';
import '../widgets/degraded_state_card.dart';

class StackOverflowDashboard extends ConsumerStatefulWidget {
  const StackOverflowDashboard({super.key});

  @override
  ConsumerState<StackOverflowDashboard> createState() =>
      _StackOverflowDashboardState();
}

class _StackOverflowDashboardState
    extends ConsumerState<StackOverflowDashboard> {
  final DownloadService _downloadService = createDownloadService();
  List<VolumenPreguntasModel> volumenData = [];
  List<TasaAceptacionModel> aceptacionData = [];
  List<TendenciaMensualModel> tendenciasData = [];

  bool isLoading = true;
  bool isDegraded = false;
  String? degradedMessage;
  String? errorMessage;

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
      final state = await ref.read(stackoverflowDashboardProvider.future);
      if (!mounted) return;
      final StackOverflowDashboardData? data = state.data;
      if (state.isError || data == null) {
        setState(() {
          isLoading = false;
          errorMessage =
              state.message ?? 'Error cargando datos de StackOverflow';
        });
        return;
      }

      setState(() {
        volumenData = data.volumen;
        aceptacionData = data.aceptacion;
        tendenciasData = data.tendencias;
        isDegraded = state.isDegraded;
        degradedMessage = state.isDegraded ? state.message : null;
        errorMessage = null;
        isLoading = false;
      });
    } catch (e) {
      debugPrint("Error cargando datos: $e");
      setState(() {
        isLoading = false;
        errorMessage = 'Error cargando datos: $e';
      });
    }
  }

  // --- FUNCIÓN DE EXPORTACIÓN (Requerimiento Samir) ---
  Future<void> _exportDataAsZip() async {
    // 1. CSV Volumen de Preguntas
    String csv1 = 'lenguaje,preguntas\n';
    for (var item in volumenData) {
      csv1 += '${item.lenguaje},${item.preguntas}\n';
    }

    // 2. CSV Tasa de Aceptación
    String csv2 = 'tecnologia,tasa_aceptacion_pct\n';
    for (var item in aceptacionData) {
      csv2 += '${item.tecnologia},${item.tasaPct}\n';
    }

    // 3. CSV Tendencias Mensuales
    String csv3 = 'mes,python,javascript,typescript\n';
    for (var item in tendenciasData) {
      // Asumiendo que tus modelos tienen getters para estos valores
      csv3 +=
          '${item.mes},${item.python},${item.javascript},${item.typescript}\n';
    }

    // 4. Crear ZIP
    final archive = Archive();
    archive.addFile(
      ArchiveFile('so_volumen_preguntas.csv', csv1.length, utf8.encode(csv1)),
    );
    archive.addFile(
      ArchiveFile('so_tasa_aceptacion.csv', csv2.length, utf8.encode(csv2)),
    );
    archive.addFile(
      ArchiveFile(
        'so_tendencias_mensuales.csv',
        csv3.length,
        utf8.encode(csv3),
      ),
    );

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      return;
    }

    try {
      await _downloadService.saveZipBytes(
        fileName: 'stackoverflow_dashboard_data',
        bytes: zipData,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo exportar ZIP: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- HEADER CON BOTÓN ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      'Dashboard StackOverflow',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2D2D2D),
                      ),
                    ),
                    Text(
                      'Análisis de preguntas, madurez y tendencias 2025',
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
                  backgroundColor: soOrange, // Color oficial SO
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
          if (isDegraded)
            DegradedStateCard(
              message:
                  degradedMessage ??
                  'Modo degradado: algunos datasets no estuvieron disponibles.',
              onRetry: _loadAllData,
            ),

          const SizedBox(height: 24),

          // --- KEY INSIGHTS SECTION ---
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

                // Insight 1: Volumen (Dinámico) - Python logo
                if (volumenData.isNotEmpty)
                  _buildInsightCardImage(
                    'assets/images/python_logo.png',
                    '${_capitalizeFramework(volumenData.first.lenguaje)} domina las discusiones',
                    'Lidera con ${volumenData.first.preguntas} preguntas nuevas, marcando la pauta del desarrollo actual.',
                    const Color(0xFF3776AB), // Python blue
                  ),
                const SizedBox(height: 12),

                // Insight 2: Aceptación (Dinámico) - Svelte logo
                if (aceptacionData.isNotEmpty)
                  Builder(
                    builder: (context) {
                      // Buscar la tecnología con mayor tasa de aceptación
                      final best = aceptacionData.reduce(
                        (curr, next) =>
                            curr.tasaPct > next.tasaPct ? curr : next,
                      );
                      return _buildInsightCardImage(
                        'assets/images/svelte-logo.png',
                        '${_capitalizeFramework(best.tecnologia)}: Soluciones más efectivas',
                        'Tasa de respuestas aceptadas del ${best.tasaPct.toStringAsFixed(1)}%, indicando una comunidad madura y colaborativa.',
                        const Color(0xFFFF3E00), // Svelte orange
                      );
                    },
                  ),

                const SizedBox(height: 12),

                // Insight 3: Tendencia (Estático/Genérico)
                _buildInsightCard(
                  Icons.trending_down,
                  'Impacto de IA en el volumen',
                  'Descenso general del ~80% en preguntas nuevas. La comunidad migra a asistentes de IA, reduciendo las dudas básicas.',
                  const Color(0xFFDC2626), // Red
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // --- GRÁFICOS ORIGINALES ---
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
                              _capitalizeFramework(
                                volumenData[value.toInt()].lenguaje,
                              ),
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
                  barTouchData: BarTouchData(enabled: false),
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
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 8,
            children: [
              _buildLegend(colorPython, 'Python'),
              _buildLegend(colorJS, 'JavaScript'),
              _buildLegend(colorTS, 'TypeScript'),
            ],
          ),
        ],
      ),
    );
  }

  // --- WIDGET AUXILIAR PARA INSIGHTS ---
  Widget _buildInsightCard(
    IconData icon,
    String title,
    String description,
    Color accentColor,
  ) {
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

  // Widget con imagen de logo
  Widget _buildInsightCardImage(
    String imagePath,
    String title,
    String description,
    Color accentColor,
  ) {
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
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(10)),
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
