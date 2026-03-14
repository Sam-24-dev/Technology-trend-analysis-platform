import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:math' as math;
import 'package:archive/archive.dart';
import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/reddit_models.dart';
import '../models/run_manifest_models.dart';
import '../providers/app_providers.dart';
import '../services/download/download_service.dart';
import '../widgets/chart_card.dart';
import '../widgets/chart_legend.dart';
import '../widgets/chart_inline_filter.dart';
import '../widgets/degraded_state_card.dart';
import '../widgets/loading_skeleton.dart';

class RedditDashboard extends ConsumerStatefulWidget {
  const RedditDashboard({super.key});

  @override
  ConsumerState<RedditDashboard> createState() => _RedditDashboardState();
}

class _RedditDashboardState extends ConsumerState<RedditDashboard> {
  final DownloadService _downloadService = createDownloadService();
  List<SentimientoModel> sentimientoData = [];
  List<TemasEmergentesModel> temasData = [];
  List<InterseccionModel> interseccionData = [];
  RedditSentimentSummaryModel? sentimientoSummary;
  RedditTemasHistoryModel? temasHistory;
  RedditInterseccionHistoryModel? interseccionHistory;
  bool isLoading = true;
  bool isDegraded = false;
  String? degradedMessage;
  String? errorMessage;
  Timer? _autoRefreshTimer;
  int _sentimientoTopN = 0;
  _SentimientoSort _sentimientoSort = _SentimientoSort.porcentajePositivo;
  int _temasTopN = 0;
  _RedditTemasMetric _temasMetric = _RedditTemasMetric.menciones;
  _RedditTemasSort _temasSort = _RedditTemasSort.menciones;
  _RedditTemasDisplayMode _temasDisplayMode = _RedditTemasDisplayMode.actual;
  int _interseccionTopN = 0;
  _RedditInterseccionView _interseccionView = _RedditInterseccionView.brecha;
  _RedditInterseccionDetail _interseccionDetail =
      _RedditInterseccionDetail.basico;

  static const int _lowSampleThreshold = 10;
  static const Duration _pollingInterval = Duration(minutes: 5);

  @override
  void initState() {
    super.initState();
    _loadData();
    _startAutoRefresh();
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(_pollingInterval, (_) {
      if (!mounted) {
        return;
      }
      _loadData();
    });
  }

  Future<void> _loadData() async {
    try {
      final state = await ref.refresh(redditDashboardProvider.future);
      if (!mounted) return;
      final RedditDashboardData? data = state.data;

      if (state.isError || data == null) {
        setState(() {
          isLoading = false;
          errorMessage = state.message ?? 'Error cargando datos de Reddit';
        });
        return;
      }

      setState(() {
        sentimientoData = data.sentimiento;
        temasData = data.temas;
        interseccionData = data.interseccion;
        sentimientoSummary = data.sentimientoSummary;
        temasHistory = data.temasHistory;
        interseccionHistory = data.interseccionHistory;
        if (!_temasSortEnabled) {
          _temasSort = _RedditTemasSort.menciones;
        }
        isDegraded = state.isDegraded;
        degradedMessage = state.isDegraded ? state.message : null;
        errorMessage = null;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error cargando datos: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error cargando datos: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return _buildLoadingSkeleton(context);
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

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        final double horizontalPadding = compact ? 16 : 24;
        const Color kRedditPrimary = Color(0xFFFF4500);
        final DataLoadState<RunManifestPublic>? manifestState = ref
            .watch(runManifestProvider)
            .asData
            ?.value;
        final RunManifestPublic? manifest = manifestState?.data;
        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Dashboard Reddit',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF0F172A),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          buildAnalysisPeriodLabel(manifest),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF475569),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          buildLastUpdatedLabel(manifest),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
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
                      backgroundColor: kRedditPrimary,
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
                  severity: DegradedSeverity.unavailable,
                  cachedAge: '2 días',
                  message:
                      degradedMessage ??
                      'Fuente temporalmente no disponible. Se muestran datos en caché cuando existen.',
                  onRetry: _loadData,
                ),
              const SizedBox(height: 32),
              _buildKeyInsightsSection(),
              const SizedBox(height: 32),
              ChartCard(
                title: _sentimientoChartTitle,
                subtitle: _sentimientoChartSubtitle,
                badgeText: isDegraded ? 'en caché' : null,
                height: 400,
                chart: _buildSentimientoChart(),
                legend: _buildSentimientoLegend(),
                semanticLabel: _buildSentimientoChartAltText(),
              ),
              const SizedBox(height: 24),
              ChartCard(
                title: _temasChartTitle,
                subtitle: _temasChartSubtitle,
                badgeText: isDegraded ? 'en caché' : null,
                height: 450,
                chart: _buildTemasChart(),
                legend: _buildTemasLegend(),
                semanticLabel: _buildTemasChartAltText(),
              ),
              const SizedBox(height: 24),
              ChartCard(
                title: _interseccionChartTitle,
                subtitle: _interseccionChartSubtitle,
                badgeText: isDegraded ? 'parcial' : null,
                height: 470,
                chart: _buildInterseccionChart(),
                legend: _buildInterseccionLegend(),
                semanticLabel: _buildInterseccionChartAltText(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final double horizontalPadding = compact ? 16 : 24;
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          20,
          horizontalPadding,
          28,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: const <Widget>[
                SkeletonLine(width: 220, height: 18),
                SkeletonPill(width: 90, height: 24),
                SkeletonPill(width: 120, height: 36),
              ],
            ),
            const SizedBox(height: 20),
            _buildInsightsSkeletonCard(),
            const SizedBox(height: 24),
            const ChartSkeletonCard(
              chartHeight: 400,
              filterPills: 2,
              legendItems: 3,
            ),
            const SizedBox(height: 24),
            const ChartSkeletonCard(
              chartHeight: 450,
              filterPills: 3,
              legendItems: 3,
            ),
            const SizedBox(height: 24),
            const ChartSkeletonCard(
              chartHeight: 470,
              filterPills: 3,
              legendItems: 3,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsSkeletonCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const <Widget>[
            SkeletonLine(width: 160, height: 16),
            SizedBox(height: 16),
            SkeletonBox(height: 64, borderRadius: BorderRadius.all(Radius.circular(12))),
            SizedBox(height: 12),
            SkeletonBox(height: 64, borderRadius: BorderRadius.all(Radius.circular(12))),
            SizedBox(height: 12),
            SkeletonBox(height: 64, borderRadius: BorderRadius.all(Radius.circular(12))),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimientoLegend() {
    return const ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: 'Negativo',
          color: Color(0xFFEF4444),
        ),
        ChartLegendItemData(
          label: 'Neutro',
          color: Color(0xFF94A3B8),
        ),
        ChartLegendItemData(
          label: 'Positivo',
          color: Color(0xFF10B981),
        ),
      ],
    );
  }

  Widget _buildTemasLegend() {
    final bool renderDelta =
        _temasDisplayMode == _RedditTemasDisplayMode.delta;
    if (renderDelta) {
      return const ChartLegend(
        items: <ChartLegendItemData>[
          ChartLegendItemData(
            label: 'Crecimiento',
            color: Color(0xFF10B981),
          ),
          ChartLegendItemData(
            label: 'Caida',
            color: Color(0xFFDC2626),
          ),
          ChartLegendItemData(
            label: 'Sin cambio',
            color: Color(0xFF94A3B8),
          ),
        ],
      );
    }
    return const ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: 'Valor actual',
          color: Color(0xFFFF4500),
          marker: ChartLegendMarker.square,
        ),
      ],
    );
  }

  Widget _buildInterseccionLegend() {
    return const ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: 'GitHub',
          color: Color(0xFF2563EB),
        ),
        ChartLegendItemData(
          label: 'Reddit',
          color: Color(0xFFFF4500),
        ),
        ChartLegendItemData(
          label: 'Brecha',
          color: Color(0xFF93C5FD),
          marker: ChartLegendMarker.line,
        ),
      ],
    );
  }

  String _buildSentimientoChartAltText() {
    final int visible = _sentimientoVisibleCount;
    final String topLabel =
        visible > 0 ? 'top $visible' : 'sin datos disponibles';
    return 'Grafico de barras apiladas. Muestra sentimiento por framework. '
        'Vista: $topLabel. Orden: $_sentimientoOrderLabel.';
  }

  String _buildTemasChartAltText() {
    final int visible = _temasVisibleCount;
    final String topLabel = visible > 0 ? 'top $visible' : 'sin datos';
    final String metricLabel =
        _temasMetric == _RedditTemasMetric.share
        ? '% participacion'
        : 'menciones';
    final String viewLabel =
        _temasDisplayMode == _RedditTemasDisplayMode.delta
        ? 'variacion vs corrida anterior'
        : 'valor actual';
    final String sortLabel = switch (_temasSortEnabled ? _temasSort : _RedditTemasSort.menciones) {
      _RedditTemasSort.menciones => 'mas menciones',
      _RedditTemasSort.growth => 'mayor crecimiento',
      _RedditTemasSort.drop => 'mayor caida',
    };
    return 'Grafico de barras. Metrica: $metricLabel. '
        'Vista: $viewLabel. Orden: $sortLabel. $topLabel.';
  }

  String _buildInterseccionChartAltText() {
    final String viewLabel = switch (_interseccionView) {
      _RedditInterseccionView.brecha => 'mayor brecha',
      _RedditInterseccionView.consenso => 'mayor consenso',
      _RedditInterseccionView.promedio => 'promedio rank',
    };
    final String detailLabel =
        _interseccionDetail == _RedditInterseccionDetail.basico
        ? 'basico'
        : 'avanzado';
    return 'Comparativo de ranking GitHub vs Reddit. '
        'Vista: $viewLabel. Detalle: $detailLabel.';
  }

  Widget _buildSentimientoChart() {
    if (sentimientoData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final List<SentimientoModel> visibleData = _visibleSentimientoData();
    final List<int> topNOptions = _sentimientoTopNOptions(
      sentimientoData.length,
    );
    final int selectedTopN = topNOptions.contains(_sentimientoTopN)
        ? _sentimientoTopN
        : 0;

    final double maxNegativo = visibleData.fold<double>(
      0,
      (double maxValue, SentimientoModel item) =>
          item.porcentajeNegativo > maxValue
          ? item.porcentajeNegativo
          : maxValue,
    );
    final double maxPositivoNeutro = visibleData.fold<double>(0, (
      double maxValue,
      SentimientoModel item,
    ) {
      final double stack = item.porcentajePositivo + item.porcentajeNeutro;
      return stack > maxValue ? stack : maxValue;
    });
    final double minY = -((maxNegativo + 5).clamp(20, 35).toDouble());
    final double maxY = (maxPositivoNeutro + 5).clamp(60, 100);
    final int lowSampleCount = visibleData
        .where(
          (item) =>
              item.totalMenciones > 0 &&
              item.totalMenciones < _lowSampleThreshold,
        )
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: <Widget>[
            ChartInlineFilter<int>(
              key: const ValueKey<String>('sentimiento-top-filter'),
              label: 'Top',
              value: selectedTopN,
              selectedLabel: selectedTopN == 0
                  ? 'Ver todos'
                  : 'Top $selectedTopN',
              items: topNOptions
                  .map(
                    (int option) => DropdownMenuItem<int>(
                      value: option,
                      child: Text(option == 0 ? 'Ver todos' : 'Top $option'),
                    ),
                  )
                  .toList(),
              onChanged: (int? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _sentimientoTopN = value;
                });
              },
            ),
            ChartInlineFilter<_SentimientoSort>(
              key: const ValueKey<String>('sentimiento-order-filter'),
              label: 'Orden',
              value: _sentimientoSort,
              selectedLabel: switch (_sentimientoSort) {
                _SentimientoSort.porcentajePositivo => 'M\u00e1s positivo',
                _SentimientoSort.porcentajeNegativo => 'M\u00e1s negativo',
                _SentimientoSort.menciones => 'M\u00e1s menciones',
              },
              items: const <DropdownMenuItem<_SentimientoSort>>[
                DropdownMenuItem<_SentimientoSort>(
                  value: _SentimientoSort.porcentajePositivo,
                  child: Text('Más positivo'),
                ),
                DropdownMenuItem<_SentimientoSort>(
                  value: _SentimientoSort.porcentajeNegativo,
                  child: Text('Más negativo'),
                ),
                DropdownMenuItem<_SentimientoSort>(
                  value: _SentimientoSort.menciones,
                  child: Text('Más menciones'),
                ),
              ],
              onChanged: (_SentimientoSort? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _sentimientoSort = value;
                });
              },
            ),
          ],
        ),
        if (lowSampleCount > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '$lowSampleCount framework(s) tienen menos de $_lowSampleThreshold menciones.',
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF9A3412),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: BarChart(
            key: ValueKey<String>(
              'sentimiento-$_sentimientoTopN-${_sentimientoSort.name}-${visibleData.length}',
            ),
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY,
              minY: minY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => const Color(0xFF0F172A),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final int index = group.x.toInt();
                    if (index < 0 || index >= visibleData.length) {
                      return null;
                    }
                    final SentimientoModel item = visibleData[index];
                    final String segmentLabel = switch (rodIndex) {
                      0 => 'Negativo',
                      1 => 'Neutro',
                      _ => 'Positivo',
                    };
                    final double segmentValue = switch (rodIndex) {
                      0 => item.porcentajeNegativo,
                      1 => item.porcentajeNeutro,
                      _ => item.porcentajePositivo,
                    };
                    final Color segmentColor = switch (rodIndex) {
                      0 => const Color(0xFFEF4444),
                      1 => const Color(0xFF94A3B8),
                      _ => const Color(0xFF10B981),
                    };
                    return BarTooltipItem(
                      '${_capitalizeFramework(item.framework)}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text:
                              '$segmentLabel: ${segmentValue.toStringAsFixed(1)}%\n',
                          style: TextStyle(color: segmentColor),
                        ),
                        TextSpan(
                          text: 'Menciones: ${item.totalMenciones}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: List<BarChartGroupData>.generate(visibleData.length, (
                int index,
              ) {
                final SentimientoModel item = visibleData[index];
                return BarChartGroupData(
                  x: index,
                  barsSpace: 3,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: -item.porcentajeNegativo,
                      color: const Color(0xFFEF4444),
                      width: 12,
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: item.porcentajeNeutro,
                      color: const Color(0xFF94A3B8),
                      width: 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                    BarChartRodData(
                      toY: item.porcentajePositivo,
                      color: const Color(0xFF10B981),
                      width: 12,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(4),
                      ),
                    ),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) {
                      final int idx = value.toInt();
                      if (idx < 0 || idx >= visibleData.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _shortFrameworkLabel(
                            _capitalizeFramework(visibleData[idx].framework),
                          ),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
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
          ),
        ),
      ],
    );
  }

  List<SentimientoModel> _visibleSentimientoData() {
    final List<SentimientoModel> ordered =
        List<SentimientoModel>.from(sentimientoData)..sort((a, b) {
          switch (_sentimientoSort) {
            case _SentimientoSort.porcentajePositivo:
              final int byPositive = b.porcentajePositivo.compareTo(
                a.porcentajePositivo,
              );
              if (byPositive != 0) {
                return byPositive;
              }
              return b.totalMenciones.compareTo(a.totalMenciones);
            case _SentimientoSort.porcentajeNegativo:
              final int byNegative = b.porcentajeNegativo.compareTo(
                a.porcentajeNegativo,
              );
              if (byNegative != 0) {
                return byNegative;
              }
              return b.totalMenciones.compareTo(a.totalMenciones);
            case _SentimientoSort.menciones:
              final int byMentions = b.totalMenciones.compareTo(
                a.totalMenciones,
              );
              if (byMentions != 0) {
                return byMentions;
              }
              return b.porcentajePositivo.compareTo(a.porcentajePositivo);
          }
        });

    if (_sentimientoTopN <= 0 || _sentimientoTopN >= ordered.length) {
      return ordered;
    }
    return ordered.take(_sentimientoTopN).toList();
  }

  List<T> _applyTopN<T>(List<T> ordered, int topN) {
    if (topN <= 0 || topN >= ordered.length) {
      return ordered;
    }
    return ordered.take(topN).toList();
  }

  List<int> _buildTopNOptions(
    int rowCount, {
    List<int> presets = const <int>[3, 5, 8, 10],
  }) {
    if (rowCount <= 1) {
      return const <int>[0];
    }
    if (rowCount <= 3) {
      return const <int>[0];
    }

    final Set<int> options = <int>{
      0,
      ...presets.where((int value) => value > 0 && value < rowCount),
    };
    if (options.length == 1) {
      options.add(math.min(3, rowCount - 1));
    }

    final List<int> values = options.toList()..sort();
    if (values.contains(0)) {
      values.remove(0);
      values.insert(0, 0);
    }
    return values;
  }

  List<int> _sentimientoTopNOptions(int rowCount) {
    return _buildTopNOptions(rowCount, presets: const <int>[3, 5, 8, 10]);
  }

  int get _sentimientoVisibleCount {
    final int total = sentimientoData.length;
    if (total == 0) {
      return 0;
    }
    if (_sentimientoTopN > 0 && _sentimientoTopN < total) {
      return _sentimientoTopN;
    }
    return total;
  }

  String get _sentimientoOrderLabel {
    return switch (_sentimientoSort) {
      _SentimientoSort.porcentajePositivo => 'más positivo',
      _SentimientoSort.porcentajeNegativo => 'más negativo',
      _SentimientoSort.menciones => 'más menciones',
    };
  }

  String get _sentimientoChartTitle {
    if (sentimientoData.isEmpty) {
      return 'Sentimiento de Frameworks Backend';
    }
    return 'Top $_sentimientoVisibleCount frameworks backend por sentimiento';
  }

  String get _sentimientoChartSubtitle {
    if (sentimientoData.isEmpty) {
      return 'No hay datos disponibles para sentimiento de frameworks.';
    }
    final String line1 =
        'Métrica: Sentimiento   Orden: $_sentimientoOrderLabel';
    final String line2 =
        'Cobertura: $_sentimientoVisibleCount de ${sentimientoData.length} frameworks analizados.';
    return '$line1\n$line2';
  }

  String get _temasChartTitle {
    if (temasData.isEmpty) {
      return 'Temas emergentes';
    }
    return 'Top $_temasVisibleCount temas emergentes';
  }

  int get _temasVisibleCount {
    final int total = temasData.length;
    if (total == 0) {
      return 0;
    }
    if (_temasTopN > 0 && _temasTopN < total) {
      return _temasTopN;
    }
    return total;
  }

  bool get _temasSortEnabled {
    final bool hasHistorySignals = temasHistory?.hasGrowthSignals ?? false;
    if (hasHistorySignals) {
      return true;
    }
    return temasData.any(
      (item) =>
          item.deltaMenciones != null ||
          item.growthPct != null ||
          item.trendDirection != null,
    );
  }

  bool get _temasHasDropSignals {
    return temasData.any((TemasEmergentesModel item) {
      return (item.deltaMenciones ?? 0) < 0 || (item.growthPct ?? 0) < 0;
    });
  }

  String get _temasComparisonLabel {
    final String? previous = _formatDateLabel(
      temasHistory?.previousSnapshotDate,
    );
    final String? latest = _formatDateLabel(temasHistory?.latestSnapshotDate);
    if (previous != null && latest != null) {
      if (latest == previous) {
        return 'Comparado (UTC): $previous (misma fecha, corrida previa)';
      }
      return 'Comparado (UTC): $previous -> $latest';
    }
    if (latest != null) {
      return 'Comparado (UTC): $latest';
    }
    return 'Comparado (UTC): no disponible';
  }

  String get _temasChartSubtitle {
    if (temasData.isEmpty) {
      return 'No hay datos disponibles para temas emergentes.';
    }
    final String metricLabel = _temasMetric == _RedditTemasMetric.share
        ? '% participación'
        : 'menciones';
    final _RedditTemasSort activeSort = _temasSortEnabled
        ? _temasSort
        : _RedditTemasSort.menciones;
    final String orderLabel = switch (activeSort) {
      _RedditTemasSort.menciones => 'más menciones',
      _RedditTemasSort.growth => 'mayor crecimiento',
      _RedditTemasSort.drop => 'mayor caída',
    };
    final String line1 = 'Métrica: $metricLabel   Orden: $orderLabel';
    return '$line1\n$_temasComparisonLabel';
  }

  String _shortFrameworkLabel(String label) {
    if (label.length <= 11) {
      return label;
    }
    return '${label.substring(0, 9)}...';
  }

  String _shortTemaLabel(String label) {
    if (label.length <= 14) {
      return label;
    }
    return '${label.substring(0, 12)}...';
  }

  String? _formatDateLabel(String? input) {
    if (input == null || input.trim().isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(input.trim());
    if (parsed == null) {
      return null;
    }
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  int _compareNullableDoubleDesc(double? a, double? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return b.compareTo(a);
  }

  int _compareNullableDoubleAsc(double? a, double? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return a.compareTo(b);
  }

  int _compareNullableIntDesc(int? a, int? b) {
    if (a == null && b == null) {
      return 0;
    }
    if (a == null) {
      return 1;
    }
    if (b == null) {
      return -1;
    }
    return b.compareTo(a);
  }

  List<TemasEmergentesModel> _orderedTemasData() {
    final List<TemasEmergentesModel> ordered = List<TemasEmergentesModel>.from(
      temasData,
    );

    ordered.sort((TemasEmergentesModel a, TemasEmergentesModel b) {
      switch (_temasSortEnabled ? _temasSort : _RedditTemasSort.menciones) {
        case _RedditTemasSort.menciones:
          final int byMentions = b.menciones.compareTo(a.menciones);
          if (byMentions != 0) {
            return byMentions;
          }
          return a.tema.toLowerCase().compareTo(b.tema.toLowerCase());
        case _RedditTemasSort.growth:
          final int byGrowth = _compareNullableDoubleDesc(
            a.growthPct,
            b.growthPct,
          );
          if (byGrowth != 0) {
            return byGrowth;
          }
          final int byDelta = _compareNullableIntDesc(
            a.deltaMenciones,
            b.deltaMenciones,
          );
          if (byDelta != 0) {
            return byDelta;
          }
          final int byMentions = b.menciones.compareTo(a.menciones);
          if (byMentions != 0) {
            return byMentions;
          }
          return a.tema.toLowerCase().compareTo(b.tema.toLowerCase());
        case _RedditTemasSort.drop:
          final bool negativeA =
              (a.deltaMenciones ?? 0) < 0 || (a.growthPct ?? 0) < 0;
          final bool negativeB =
              (b.deltaMenciones ?? 0) < 0 || (b.growthPct ?? 0) < 0;
          if (negativeA != negativeB) {
            return negativeA ? -1 : 1;
          }
          final int deltaA = a.deltaMenciones ?? 999999;
          final int deltaB = b.deltaMenciones ?? 999999;
          if (deltaA != deltaB) {
            return deltaA.compareTo(deltaB);
          }
          final int byGrowth = _compareNullableDoubleAsc(
            a.growthPct,
            b.growthPct,
          );
          if (byGrowth != 0) {
            return byGrowth;
          }
          final int byMentions = b.menciones.compareTo(a.menciones);
          if (byMentions != 0) {
            return byMentions;
          }
          return a.tema.toLowerCase().compareTo(b.tema.toLowerCase());
      }
    });
    return ordered;
  }

  Widget _buildTemasChart() {
    if (temasData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final List<TemasEmergentesModel> ordered = _orderedTemasData();
    final int totalMenciones = ordered.fold<int>(
      0,
      (int sum, TemasEmergentesModel item) => sum + item.menciones,
    );
    final List<int> topNOptions = _buildTopNOptions(
      ordered.length,
      presets: const <int>[3, 5, 8, 10],
    );
    final int selectedTopN = topNOptions.contains(_temasTopN) ? _temasTopN : 0;
    final List<TemasEmergentesModel> visible = _applyTopN<TemasEmergentesModel>(
      ordered,
      selectedTopN,
    );
    final bool renderDelta = _temasDisplayMode == _RedditTemasDisplayMode.delta;

    double metricValue(TemasEmergentesModel item) {
      if (renderDelta) {
        if (_temasMetric == _RedditTemasMetric.menciones) {
          return (item.deltaMenciones ?? 0).toDouble();
        }
        return item.growthPct ?? 0;
      }
      if (_temasMetric == _RedditTemasMetric.menciones) {
        return item.menciones.toDouble();
      }
      if (totalMenciones <= 0) {
        return 0;
      }
      return (item.menciones / totalMenciones) * 100;
    }

    final List<double> metricValues = visible
        .map((TemasEmergentesModel item) => metricValue(item))
        .toList();
    final double maxRaw = metricValues.isEmpty
        ? 0
        : metricValues.reduce(math.max);
    final double minRaw = metricValues.isEmpty
        ? 0
        : metricValues.reduce(math.min);
    final double maxY = renderDelta
        ? (maxRaw <= 0 ? 1 : maxRaw * 1.15)
        : (maxRaw <= 0 ? 1 : maxRaw * 1.12);
    final double minY = renderDelta ? (minRaw >= 0 ? 0 : minRaw * 1.15) : 0;
    final double yInterval = _temasMetric == _RedditTemasMetric.share
        ? (maxY.abs() / 5).clamp(1, 20).toDouble()
        : (maxY.abs() / 5).clamp(1, 200).toDouble();
    final String yAxisLabel = switch ((_temasDisplayMode, _temasMetric)) {
      (_RedditTemasDisplayMode.actual, _RedditTemasMetric.menciones) =>
        'Menciones',
      (_RedditTemasDisplayMode.actual, _RedditTemasMetric.share) =>
        '% participación',
      (_RedditTemasDisplayMode.delta, _RedditTemasMetric.menciones) =>
        'Î” menciones',
      (_RedditTemasDisplayMode.delta, _RedditTemasMetric.share) =>
        'Î” % crecimiento',
    };
    final bool showVariationLegend =
        _temasSortEnabled &&
        (_temasSort == _RedditTemasSort.growth ||
            _temasSort == _RedditTemasSort.drop);
    final bool showNoDropMessage =
        _temasSortEnabled &&
        _temasSort == _RedditTemasSort.drop &&
        !_temasHasDropSignals;
    final String variationLegendText = renderDelta
        ? 'Ordenado por variación vs corrida anterior; barras muestran variación.'
        : 'Ordenado por variación vs corrida anterior; barras muestran valor actual.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: <Widget>[
            ChartInlineFilter<int>(
              key: const ValueKey<String>('temas-top-filter'),
              label: 'Top',
              value: selectedTopN,
              selectedLabel: selectedTopN == 0
                  ? 'Ver todos'
                  : 'Top $selectedTopN',
              items: topNOptions
                  .map(
                    (int option) => DropdownMenuItem<int>(
                      value: option,
                      child: Text(option == 0 ? 'Ver todos' : 'Top $option'),
                    ),
                  )
                  .toList(),
              onChanged: (int? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _temasTopN = value;
                });
              },
            ),
            ChartInlineFilter<_RedditTemasMetric>(
              key: const ValueKey<String>('temas-metrica-filter'),
              label: 'Métrica',
              value: _temasMetric,
              selectedLabel: _temasMetric == _RedditTemasMetric.share
                  ? '% participaci\u00f3n'
                  : 'Menciones',
              items: const <DropdownMenuItem<_RedditTemasMetric>>[
                DropdownMenuItem<_RedditTemasMetric>(
                  value: _RedditTemasMetric.menciones,
                  child: Text('Menciones'),
                ),
                DropdownMenuItem<_RedditTemasMetric>(
                  value: _RedditTemasMetric.share,
                  child: Text('% participación'),
                ),
              ],
              onChanged: (_RedditTemasMetric? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _temasMetric = value;
                });
              },
            ),
            if (_temasSortEnabled)
              ChartInlineFilter<_RedditTemasSort>(
                key: const ValueKey<String>('temas-orden-filter'),
                label: 'Orden',
                value: _temasSort,
                selectedLabel: switch (_temasSort) {
                  _RedditTemasSort.menciones => 'M\u00e1s menciones',
                  _RedditTemasSort.growth => 'Mayor crecimiento',
                  _RedditTemasSort.drop => 'Mayor ca\u00edda',
                },
                items: const <DropdownMenuItem<_RedditTemasSort>>[
                  DropdownMenuItem<_RedditTemasSort>(
                    value: _RedditTemasSort.menciones,
                    child: Text('Más menciones'),
                  ),
                  DropdownMenuItem<_RedditTemasSort>(
                    value: _RedditTemasSort.growth,
                    child: Text('Mayor crecimiento'),
                  ),
                  DropdownMenuItem<_RedditTemasSort>(
                    value: _RedditTemasSort.drop,
                    child: Text('Mayor caída'),
                  ),
                ],
                onChanged: (_RedditTemasSort? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _temasSort = value;
                  });
                },
              ),
            if (_temasSortEnabled)
              ChartInlineFilter<_RedditTemasDisplayMode>(
                key: const ValueKey<String>('temas-vista-filter'),
                label: 'Ver',
                value: _temasDisplayMode,
                selectedLabel:
                    _temasDisplayMode == _RedditTemasDisplayMode.actual
                    ? 'Valor actual'
                    : 'Variaci\u00f3n',
                items: const <DropdownMenuItem<_RedditTemasDisplayMode>>[
                  DropdownMenuItem<_RedditTemasDisplayMode>(
                    value: _RedditTemasDisplayMode.actual,
                    child: Text('Valor actual'),
                  ),
                  DropdownMenuItem<_RedditTemasDisplayMode>(
                    value: _RedditTemasDisplayMode.delta,
                    child: Text('Variación'),
                  ),
                ],
                onChanged: (_RedditTemasDisplayMode? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _temasDisplayMode = value;
                  });
                },
              ),
          ],
        ),
        if (showVariationLegend) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            variationLegendText,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        if (showNoDropMessage) ...<Widget>[
          const SizedBox(height: 6),
          const Text(
            'No hay temas en caída en esta corrida. Se muestran temas estables o en crecimiento.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF9A3412),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: BarChart(
            key: ValueKey<String>(
              'temas-$_temasTopN-${_temasMetric.name}-${_temasSort.name}-${_temasDisplayMode.name}-${visible.length}-$totalMenciones',
            ),
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              minY: minY,
              maxY: maxY,
              barTouchData: BarTouchData(
                enabled: true,
                touchTooltipData: BarTouchTooltipData(
                  fitInsideHorizontally: true,
                  fitInsideVertically: true,
                  getTooltipColor: (_) => const Color(0xFF0F172A),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final int index = group.x.toInt();
                    if (index < 0 || index >= visible.length) {
                      return null;
                    }
                    final TemasEmergentesModel item = visible[index];
                    final double share = totalMenciones > 0
                        ? (item.menciones / totalMenciones) * 100
                        : 0;
                    final String variationLine = _buildTemaVariationLine(item);
                    final String valueLine = switch ((
                      _temasDisplayMode,
                      _temasMetric,
                    )) {
                      (
                        _RedditTemasDisplayMode.actual,
                        _RedditTemasMetric.menciones,
                      ) =>
                        'Valor actual: ${item.menciones} menciones',
                      (
                        _RedditTemasDisplayMode.actual,
                        _RedditTemasMetric.share,
                      ) =>
                        'Valor actual: ${share.toStringAsFixed(1)}% participación',
                      (
                        _RedditTemasDisplayMode.delta,
                        _RedditTemasMetric.menciones,
                      ) =>
                        'Variación mostrada: ${(item.deltaMenciones ?? 0) > 0 ? '+' : ''}${item.deltaMenciones ?? 0} menciones',
                      (
                        _RedditTemasDisplayMode.delta,
                        _RedditTemasMetric.share,
                      ) =>
                        'Variación mostrada: ${(item.growthPct ?? 0) > 0 ? '+' : ''}${(item.growthPct ?? 0).toStringAsFixed(2)}%',
                    };
                    final String trendLine = _buildTemaTrendLine(item);
                    return BarTooltipItem(
                      '${_formatTema(item.tema)}\n',
                      const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                      children: <TextSpan>[
                        TextSpan(
                          text: '$variationLine\n',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        TextSpan(
                          text: '$trendLine\n',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        TextSpan(
                          text: valueLine,
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    );
                  },
                ),
              ),
              barGroups: List<BarChartGroupData>.generate(visible.length, (
                int index,
              ) {
                final double rawBarValue = metricValue(visible[index]);
                final bool isZeroDeltaMarker = renderDelta && rawBarValue == 0;
                final double barValue = isZeroDeltaMarker
                    ? (_temasMetric == _RedditTemasMetric.share ? 0.25 : 0.18)
                    : rawBarValue;
                final bool isNegativeDelta = renderDelta && rawBarValue < 0;
                return BarChartGroupData(
                  x: index,
                  barRods: <BarChartRodData>[
                    BarChartRodData(
                      toY: barValue,
                      color: isZeroDeltaMarker
                          ? const Color(0xFF94A3B8)
                          : renderDelta
                          ? (isNegativeDelta
                              ? const Color(0xFFDC2626)
                              : const Color(0xFF10B981))
                          : const Color(0xFFFF4500),
                      width: 26,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(barValue >= 0 ? 4 : 0),
                        bottom: Radius.circular(barValue < 0 ? 4 : 0),
                      ),
                    ),
                  ],
                );
              }),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                rightTitles: const AxisTitles(
                  sideTitles: SideTitles(showTitles: false),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 80,
                    getTitlesWidget: (value, meta) {
                      final int idx = value.toInt();
                      if (idx < 0 || idx >= visible.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: RotatedBox(
                          quarterTurns: -1,
                          child: Text(
                            _shortTemaLabel(_formatTema(visible[idx].tema)),
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.left,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  axisNameWidget: Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(
                      yAxisLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  axisNameSize: 30,
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 50,
                    interval: yInterval,
                    getTitlesWidget: (value, meta) {
                      if (_temasMetric == _RedditTemasMetric.share) {
                        return Text(
                          '${value.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 10),
                        );
                      }
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
          ),
        ),
      ],
    );
  }

  String _buildTemaVariationLine(TemasEmergentesModel item) {
    if (item.deltaMenciones == null && item.growthPct == null) {
      return 'Variación vs corrida anterior: no disponible';
    }
    final int delta = item.deltaMenciones ?? 0;
    final double growth = item.growthPct ?? 0;
    final String deltaPrefix = delta > 0 ? '+' : '';
    final String growthPrefix = growth > 0 ? '+' : '';
    return 'Variación vs corrida anterior: $deltaPrefix$delta ($growthPrefix${growth.toStringAsFixed(2)}%)';
  }

  String _buildTemaTrendLine(TemasEmergentesModel item) {
    final String rawTrend = (item.trendDirection ?? '').trim().toLowerCase();
    if (rawTrend == 'creciendo' ||
        rawTrend == 'estable' ||
        rawTrend == 'cayendo') {
      return 'Tendencia: $rawTrend';
    }
    if (item.deltaMenciones != null) {
      if (item.deltaMenciones! > 0) {
        return 'Tendencia: creciendo';
      }
      if (item.deltaMenciones! < 0) {
        return 'Tendencia: cayendo';
      }
      return 'Tendencia: estable';
    }
    return 'Tendencia: no disponible';
  }

  Widget _buildInterseccionChart() {
    final RedditInterseccionHistoryModel? history = interseccionHistory;
    if (history == null || history.latestItems.isEmpty) {
      return _buildInterseccionHistoryUnavailableState();
    }

    final List<RedditInterseccionHistoryItemModel> orderedItems =
        _orderedInterseccionItems(
          history.latestItems.where((item) => item.hasComparableRanks).toList(),
        );
    if (orderedItems.isEmpty) {
      return _buildInterseccionHistoryUnavailableState(
        message:
            'No hay tecnologías comparables en la selección actual. Ajusta Top para incluir más elementos.',
      );
    }

    final List<int> topNOptions = _buildTopNOptions(
      orderedItems.length,
      presets: const <int>[3, 5, 8, 10],
    );
    final int selectedTopN = topNOptions.contains(_interseccionTopN)
        ? _interseccionTopN
        : 0;
    final List<RedditInterseccionHistoryItemModel> comparableItems = _applyTopN(
      orderedItems,
      selectedTopN,
    );

    final int maxRank = comparableItems.fold<int>(10, (int maxValue, item) {
      final int github = item.rankingGitHub ?? 0;
      final int reddit = item.rankingReddit ?? 0;
      final int candidate = math.max(github, reddit);
      return candidate > maxValue ? candidate : maxValue;
    });
    final int boundedMaxRank = math.max(10, maxRank);
    final bool showAdvancedDetail =
        _interseccionDetail == _RedditInterseccionDetail.avanzado;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: <Widget>[
            if (topNOptions.length > 1)
              ChartInlineFilter<int>(
                key: const ValueKey<String>('interseccion-top-filter'),
                label: 'Top',
                value: selectedTopN,
                selectedLabel: selectedTopN == 0
                    ? 'Ver todos'
                    : 'Top $selectedTopN',
                items: topNOptions
                    .map(
                      (int option) => DropdownMenuItem<int>(
                        value: option,
                        child: Text(option == 0 ? 'Ver todos' : 'Top $option'),
                      ),
                    )
                    .toList(),
                onChanged: (int? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _interseccionTopN = value;
                  });
                },
              ),
            ChartInlineFilter<_RedditInterseccionView>(
              key: const ValueKey<String>('interseccion-vista-filter'),
              label: 'Vista',
              value: _interseccionView,
              selectedLabel: switch (_interseccionView) {
                _RedditInterseccionView.brecha => 'Mayor brecha',
                _RedditInterseccionView.consenso => 'Mayor consenso',
                _RedditInterseccionView.promedio => 'Promedio rank',
              },
              items: const <DropdownMenuItem<_RedditInterseccionView>>[
                DropdownMenuItem<_RedditInterseccionView>(
                  value: _RedditInterseccionView.brecha,
                  child: Text('Mayor brecha'),
                ),
                DropdownMenuItem<_RedditInterseccionView>(
                  value: _RedditInterseccionView.consenso,
                  child: Text('Mayor consenso'),
                ),
                DropdownMenuItem<_RedditInterseccionView>(
                  value: _RedditInterseccionView.promedio,
                  child: Text('Promedio rank'),
                ),
              ],
              onChanged: (_RedditInterseccionView? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _interseccionView = value;
                });
              },
            ),
            ChartInlineFilter<_RedditInterseccionDetail>(
              key: const ValueKey<String>('interseccion-detalle-filter'),
              label: 'Detalle',
              value: _interseccionDetail,
              selectedLabel:
                  _interseccionDetail == _RedditInterseccionDetail.basico
                  ? 'B\u00e1sico'
                  : 'Avanzado',
              items: const <DropdownMenuItem<_RedditInterseccionDetail>>[
                DropdownMenuItem<_RedditInterseccionDetail>(
                  value: _RedditInterseccionDetail.basico,
                  child: Text('Básico'),
                ),
                DropdownMenuItem<_RedditInterseccionDetail>(
                  value: _RedditInterseccionDetail.avanzado,
                  child: Text('Avanzado'),
                ),
              ],
              onChanged: (_RedditInterseccionDetail? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _interseccionDetail = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: <Widget>[
            _buildIntersectionSummaryPill(
              label: 'Consenso',
              value: history.summary.consensoCount.toString(),
              color: const Color(0xFF059669),
            ),
            _buildIntersectionSummaryPill(
              label: 'Divergentes',
              value: history.summary.divergenteCount.toString(),
              color: const Color(0xFFEA580C),
            ),
            _buildIntersectionSummaryPill(
              label: 'Comparables',
              value: '${history.comparableCount}/${history.itemCount}',
              color: const Color(0xFF0F766E),
            ),
            _buildIntersectionSummaryPill(
              label: 'Cobertura',
              value: '${history.coveragePct.toStringAsFixed(1)}%',
              color: const Color(0xFF2563EB),
            ),
          ],
        ),
        if (history.snapshotCount < 2) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'Histórico insuficiente para tendencia: ejecuta una segunda corrida ETL para habilitar delta.',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF9A3412),
            ),
          ),
        ],
        const SizedBox(height: 10),
        Expanded(
          child: ListView(
            padding: EdgeInsets.zero,
            children: <Widget>[
              Text(
                'Comparables (${comparableItems.length})',
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0F172A),
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              ...comparableItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildInterseccionDumbbellRow(
                    item: item,
                    maxRank: boundedMaxRank,
                    showAdvancedDetail: showAdvancedDetail,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInterseccionDumbbellRow({
    required RedditInterseccionHistoryItemModel item,
    required int maxRank,
    required bool showAdvancedDetail,
  }) {
    final int githubRank = item.rankingGitHub ?? 0;
    final int redditRank = item.rankingReddit ?? 0;
    final double denominator = (maxRank - 1).toDouble();
    final double githubNorm = denominator <= 0
        ? 0
        : ((githubRank - 1) / denominator).clamp(0, 1).toDouble();
    final double redditNorm = denominator <= 0
        ? 0
        : ((redditRank - 1) / denominator).clamp(0, 1).toDouble();
    final double startNorm = math.min(githubNorm, redditNorm);
    final double endNorm = math.max(githubNorm, redditNorm);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _formatTech(item.tecnologia),
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 28,
            child: LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                final double width = constraints.maxWidth;
                final double startPx = startNorm * width;
                final double endPx = endNorm * width;
                final double githubPx = githubNorm * width;
                final double redditPx = redditNorm * width;

                return Stack(
                  clipBehavior: Clip.none,
                  children: <Widget>[
                    Positioned(
                      left: 0,
                      right: 0,
                      top: 13,
                      child: Container(
                        height: 2,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    Positioned(
                      left: startPx,
                      width: endPx - startPx,
                      top: 12,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          color: const Color(0xFF93C5FD),
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    Positioned(
                      left: githubPx - 6,
                      top: 8,
                      child: _buildInterseccionRankDot(
                        color: const Color(0xFF2563EB),
                      ),
                    ),
                    Positioned(
                      left: redditPx - 6,
                      top: 8,
                      child: _buildInterseccionRankDot(
                        color: const Color(0xFFFF4500),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            children: <Widget>[
              Text(
                'GitHub #$githubRank',
                style: const TextStyle(fontSize: 12, color: Color(0xFF2563EB)),
              ),
              Text(
                'Reddit #$redditRank',
                style: const TextStyle(fontSize: 12, color: Color(0xFFFF4500)),
              ),
              Text(
                'Brecha ${item.brechaAbs ?? '-'}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF334155)),
              ),
              if (showAdvancedDetail)
                Text(
                  'Variación ${item.deltaGap ?? 'N/D'}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                  ),
                ),
              if (showAdvancedDetail)
                Text(
                  'Tendencia ${_formatInterseccionTrendLabel(item.trendDirection)}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF334155),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInterseccionRankDot({required Color color}) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }

  String _formatInterseccionTrendLabel(String? value) {
    final String normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'divergiendo':
      case 'aumentando':
        return 'aumentando';
      case 'convergiendo':
      case 'disminuyendo':
        return 'disminuyendo';
      case 'estable':
        return 'estable';
      default:
        return 'N/D';
    }
  }

  Widget _buildInterseccionHistoryUnavailableState({String? message}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          message ??
              'Histórico insuficiente para intersección. Ejecuta github_etl.py -> reddit_etl.py -> sync_assets.py.',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF475569),
            height: 1.4,
          ),
        ),
      ),
    );
  }

  Widget _buildIntersectionSummaryPill({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  String get _interseccionChartTitle {
    final int comparableTotal = _interseccionComparableTotal;
    if (comparableTotal <= 0) {
      return 'Intersección GitHub vs Reddit';
    }
    final int visibleCount = _interseccionVisibleCount;
    return 'Top $visibleCount tecnologías en intersección GitHub vs Reddit';
  }

  String get _interseccionChartSubtitle {
    final String viewLabel = switch (_interseccionView) {
      _RedditInterseccionView.brecha => 'mayor brecha',
      _RedditInterseccionView.consenso => 'mayor consenso',
      _RedditInterseccionView.promedio => 'promedio de ranking',
    };
    final String line1 = 'Métrica: Brecha de ranking   Orden: $viewLabel';
    return '$line1\n${_interseccionComparisonLabel()}';
  }

  String _interseccionComparisonLabel() {
    final String? previous = _formatDateLabel(
      interseccionHistory?.previousSnapshotDate,
    );
    final String? latest = _formatDateLabel(
      interseccionHistory?.latestSnapshotDate,
    );
    if (previous != null && latest != null) {
      if (previous == latest) {
        return 'Comparado (UTC): $previous (misma fecha, corrida previa)';
      }
      return 'Comparado (UTC): $previous -> $latest';
    }
    if (latest != null) {
      return 'Comparado (UTC): $latest';
    }
    return 'Comparado (UTC): no disponible';
  }

  int get _interseccionComparableTotal {
    final RedditInterseccionHistoryModel? history = interseccionHistory;
    if (history == null) {
      return 0;
    }
    return history.latestItems.where((item) => item.hasComparableRanks).length;
  }

  int get _interseccionVisibleCount {
    final int comparableTotal = _interseccionComparableTotal;
    if (comparableTotal <= 0) {
      return 0;
    }
    if (_interseccionTopN > 0 && _interseccionTopN < comparableTotal) {
      return _interseccionTopN;
    }
    return comparableTotal;
  }

  List<RedditInterseccionHistoryItemModel> _orderedInterseccionItems(
    List<RedditInterseccionHistoryItemModel> source,
  ) {
    final List<RedditInterseccionHistoryItemModel> ordered =
        List<RedditInterseccionHistoryItemModel>.from(source);
    ordered.sort((a, b) {
      final int gapA = a.brechaAbs ?? 9999;
      final int gapB = b.brechaAbs ?? 9999;
      final double avgA = a.promedioRank ?? 9999;
      final double avgB = b.promedioRank ?? 9999;
      switch (_interseccionView) {
        case _RedditInterseccionView.brecha:
          if (gapA != gapB) {
            return gapB.compareTo(gapA);
          }
          return avgA.compareTo(avgB);
        case _RedditInterseccionView.consenso:
          if (gapA != gapB) {
            return gapA.compareTo(gapB);
          }
          return avgA.compareTo(avgB);
        case _RedditInterseccionView.promedio:
          if (avgA != avgB) {
            return avgA.compareTo(avgB);
          }
          return gapA.compareTo(gapB);
      }
    });
    return ordered;
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
    return tema
        .replaceAll('IA/Machine Learning', 'AI/ML')
        .replaceAll('IA', 'AI');
  }

  String _formatTech(String raw) {
    final Map<String, String> names = <String, String>{
      'reactjs': 'ReactJS',
      'react.js': 'ReactJS',
      'vue.js': 'Vue.js',
      'angular': 'Angular',
      'next.js': 'Next.js',
      'svelte': 'Svelte',
      'python': 'Python',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'ai/ml': 'AI/ML',
      'ai': 'AI',
      'llm': 'LLM',
    };
    return names[raw.toLowerCase().trim()] ?? _capitalizeFramework(raw);
  }

  Widget _buildKeyInsightsSection() {
    final List<_InsightCardData> cards = <_InsightCardData>[
      _buildSentimentInsight(),
      _buildTopicInsight(),
      _buildIntersectionInsight(),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Insights clave',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 20),
          Column(
            children: cards.asMap().entries.map((entry) {
              final bool isLast = entry.key == cards.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: _buildInsightCard(entry.value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  _InsightCardData _buildTopicInsight() {
    final TemasEmergentesModel? leaderFromSummary =
        temasHistory?.summary.leaderTopic;
    final String? previousDate = _formatDateLabel(
      temasHistory?.previousSnapshotDate,
    );

    if (leaderFromSummary != null) {
      final String topicName = _formatTech(_formatTema(leaderFromSummary.tema));
      final int? delta = leaderFromSummary.deltaMenciones;
      final String description;
      if (delta != null && previousDate != null) {
        final String deltaText = delta > 0 ? '+$delta' : '$delta';
        description =
            '${leaderFromSummary.menciones} menciones, var $deltaText vs $previousDate.';
      } else {
        description = '${leaderFromSummary.menciones} menciones en el corte.';
      }

      return _InsightCardData(
        title: '$topicName concentra el mayor volumen de menciones en Reddit',
        description: description,
        iconColor: _resolveInsightColor(
          topicName,
          fallbackColor: const Color(0xFFFF4500),
        ),
        iconAsset: _resolveInsightLogo(topicName),
        iconData: _resolveInsightFallbackIcon(
          topicName,
          defaultIcon: Icons.topic_rounded,
        ),
      );
    }

    if (temasData.isEmpty) {
      return const _InsightCardData(
        title: 'Temas de Reddit',
        description:
            'Aún no hay suficientes menciones para resumir tendencias.',
        iconColor: Color(0xFFFF4500),
        iconData: Icons.topic_rounded,
      );
    }
    final List<TemasEmergentesModel> ordered = List<TemasEmergentesModel>.from(
      temasData,
    )..sort((a, b) => b.menciones.compareTo(a.menciones));
    final TemasEmergentesModel leader = ordered.first;
    final String topicName = _formatTech(_formatTema(leader.tema));

    return _InsightCardData(
      title: '$topicName concentra el mayor volumen de menciones en Reddit',
      description:
          '${leader.menciones} menciones en el corte.',
      iconColor: _resolveInsightColor(
        topicName,
        fallbackColor: const Color(0xFFFF4500),
      ),
      iconAsset: _resolveInsightLogo(topicName),
      iconData: _resolveInsightFallbackIcon(
        topicName,
        defaultIcon: Icons.topic_rounded,
      ),
    );
  }

  _InsightCardData _buildSentimentInsight() {
    final SentimientoModel? leaderFromSummary =
        sentimientoSummary?.positiveLeader;
    final SentimientoModel? largestSample = sentimientoSummary?.largestSample;

    if (leaderFromSummary != null) {
      final String frameworkName = _formatTech(leaderFromSummary.framework);
      final bool lowSample =
          leaderFromSummary.totalMenciones > 0 &&
          leaderFromSummary.totalMenciones < _lowSampleThreshold;
      String description =
          '${leaderFromSummary.porcentajePositivo.toStringAsFixed(1)}% positivo sobre ${leaderFromSummary.totalMenciones} menciones.';
      if (lowSample && largestSample != null) {
        final String sampleName = _formatTech(largestSample.framework);
        description =
            '${leaderFromSummary.porcentajePositivo.toStringAsFixed(1)}% positivo sobre ${leaderFromSummary.totalMenciones} menciones. Mayor muestra: $sampleName (${largestSample.totalMenciones}).';
      }

      return _InsightCardData(
        title: '$frameworkName registra el sentimiento más positivo en Reddit',
        description: description,
        iconColor: _resolveInsightColor(
          frameworkName,
          fallbackColor: const Color(0xFF059669),
        ),
        iconAsset: _resolveInsightLogo(frameworkName),
        iconData: _resolveInsightFallbackIcon(
          frameworkName,
          defaultIcon: Icons.sentiment_satisfied_alt_rounded,
        ),
      );
    }

    if (sentimientoData.isEmpty) {
      return const _InsightCardData(
        title: 'Sentimiento en Reddit',
        description:
            'No hay suficientes registros para estimar polaridad en Reddit.',
        iconColor: Color(0xFF059669),
        iconData: Icons.sentiment_satisfied_alt_rounded,
      );
    }
    final List<SentimientoModel> ordered = List<SentimientoModel>.from(
      sentimientoData,
    )..sort((a, b) => b.porcentajePositivo.compareTo(a.porcentajePositivo));
    final SentimientoModel leader = ordered.first;
    final String frameworkName = _formatTech(leader.framework);

    return _InsightCardData(
      title: '$frameworkName registra el sentimiento más positivo en Reddit',
      description:
          '${leader.porcentajePositivo.toStringAsFixed(1)}% positivo sobre ${leader.totalMenciones} menciones.',
      iconColor: _resolveInsightColor(
        frameworkName,
        fallbackColor: const Color(0xFF059669),
      ),
      iconAsset: _resolveInsightLogo(frameworkName),
      iconData: _resolveInsightFallbackIcon(
        frameworkName,
        defaultIcon: Icons.sentiment_satisfied_alt_rounded,
      ),
    );
  }

  _InsightCardData _buildIntersectionInsight() {
    final RedditInterseccionSummaryModel? summary =
        interseccionHistory?.summary;
    final RedditInterseccionHistoryItemModel? closestAlignment =
        summary?.closestAlignment;
    if (closestAlignment != null &&
        closestAlignment.rankingGitHub != null &&
        closestAlignment.rankingReddit != null) {
      final String techName = _formatTech(closestAlignment.tecnologia);
      final int githubRank = closestAlignment.rankingGitHub!;
      final int redditRank = closestAlignment.rankingReddit!;
      final int gap =
          closestAlignment.brechaAbs ?? (githubRank - redditRank).abs();
      final String coverageText =
          'Cobertura: ${summary!.coveragePct.toStringAsFixed(1)}% (${summary.comparableCount} tecnologías).';

      return _InsightCardData(
        title: '$techName muestra la alineación más cercana entre plataformas',
        description:
            'GitHub #$githubRank, Reddit #$redditRank; brecha $gap. $coverageText',
        iconColor: _resolveInsightColor(
          techName,
          fallbackColor: const Color(0xFF2563EB),
        ),
        iconAsset: _resolveInsightLogo(techName),
        iconData: _resolveInsightFallbackIcon(
          techName,
          defaultIcon: Icons.hub_rounded,
        ),
      );
    }

    final List<RedditInterseccionHistoryItemModel> historyComparable =
        interseccionHistory?.latestItems
            .where((item) => item.hasComparableRanks)
            .toList() ??
        <RedditInterseccionHistoryItemModel>[];

    if (historyComparable.isNotEmpty) {
      historyComparable.sort((a, b) {
        final int gapA =
            a.brechaAbs ?? ((a.rankingGitHub! - a.rankingReddit!).abs());
        final int gapB =
            b.brechaAbs ?? ((b.rankingGitHub! - b.rankingReddit!).abs());
        if (gapA != gapB) {
          return gapA.compareTo(gapB);
        }
        final double avgA = a.promedioRank ?? 9999;
        final double avgB = b.promedioRank ?? 9999;
        return avgA.compareTo(avgB);
      });

      final RedditInterseccionHistoryItemModel leader = historyComparable.first;
      final String techName = _formatTech(leader.tecnologia);
      final int githubRank = leader.rankingGitHub!;
      final int redditRank = leader.rankingReddit!;
      final int gap = leader.brechaAbs ?? (githubRank - redditRank).abs();
      final String gapText = gap == 0
          ? 'sin brecha entre plataformas.'
          : 'con una brecha de $gap posiciones.';

      return _InsightCardData(
        title: '$techName muestra la alineación más cercana entre plataformas',
        description:
            'Ranking GitHub #$githubRank y Reddit #$redditRank, $gapText',
        iconColor: _resolveInsightColor(
          techName,
          fallbackColor: const Color(0xFF2563EB),
        ),
        iconAsset: _resolveInsightLogo(techName),
        iconData: _resolveInsightFallbackIcon(
          techName,
          defaultIcon: Icons.hub_rounded,
        ),
      );
    }

    final List<InterseccionModel> csvComparable = interseccionData
        .where(
          (InterseccionModel item) =>
              item.rankingGitHub != null && item.rankingReddit != null,
        )
        .toList();
    if (csvComparable.isEmpty) {
      return const _InsightCardData(
        title: 'Cruce GitHub vs Reddit',
        description:
            'No hay tecnologías con ranking completo en GitHub y Reddit.',
        iconColor: Color(0xFF2563EB),
        iconData: Icons.hub_rounded,
      );
    }

    csvComparable.sort((a, b) {
      final int gapA = (a.rankingGitHub! - a.rankingReddit!).abs();
      final int gapB = (b.rankingGitHub! - b.rankingReddit!).abs();
      if (gapA != gapB) {
        return gapA.compareTo(gapB);
      }
      final int rankA = a.rankingGitHub! + a.rankingReddit!;
      final int rankB = b.rankingGitHub! + b.rankingReddit!;
      return rankA.compareTo(rankB);
    });

    final InterseccionModel leader = csvComparable.first;
    final String techName = _formatTech(leader.tecnologia);
    final int gap = (leader.rankingGitHub! - leader.rankingReddit!).abs();
    final String gapText = gap == 0
        ? 'sin brecha entre plataformas.'
        : 'con una brecha de $gap posiciones.';

    return _InsightCardData(
      title: '$techName muestra la alineación más cercana entre plataformas',
      description:
          'Ranking GitHub #${leader.rankingGitHub} y Reddit #${leader.rankingReddit}, $gapText',
      iconColor: _resolveInsightColor(
        techName,
        fallbackColor: const Color(0xFF2563EB),
      ),
      iconAsset: _resolveInsightLogo(techName),
      iconData: _resolveInsightFallbackIcon(
        techName,
        defaultIcon: Icons.hub_rounded,
      ),
    );
  }

  String? _resolveInsightLogo(String raw) {
    final String key = raw.trim().toLowerCase();
    if (key.contains('python')) {
      return 'assets/images/python_logo.png';
    }
    if (key.contains('react')) {
      return 'assets/images/React-logo.png';
    }
    if (key.contains('vue')) {
      return 'assets/images/Vue-logo.png';
    }
    if (key.contains('typescript')) {
      return 'assets/images/TypeScript-logo.png';
    }
    if (key.contains('javascript')) {
      return 'assets/images/JavaScript-logo.png';
    }
    if (key.contains('angular')) {
      return 'assets/images/angular_logo.png';
    }
    if (key.contains('svelte')) {
      return 'assets/images/svelte-logo.png';
    }
    if (key.contains('django')) {
      return 'assets/images/django-logo.png';
    }
    if (key.contains('java') && !key.contains('javascript')) {
      return 'assets/images/Java-logo.png';
    }
    if (key.contains('c#') || key.contains('csharp')) {
      return 'assets/images/csharp-logo.png';
    }
    if (key.contains('c++') || key.contains('cpp')) {
      return 'assets/images/cpp-logo.png';
    }
    if (key.contains('spring')) {
      return 'assets/images/Spring-logo.png';
    }
    if (key.contains('laravel')) {
      return 'assets/images/Laravel-logo.png';
    }
    if (key.contains('fastapi')) {
      return 'assets/images/FastAPI-logo.png';
    }
    if (key.contains('kotlin')) {
      return 'assets/images/Kotlin-logo.png';
    }
    if (key.contains('php')) {
      return 'assets/images/PHP-logo.png';
    }
    if (key.contains('rust')) {
      return 'assets/images/Rust-logo.png';
    }
    if (key.contains('go')) {
      return 'assets/images/Go-logo.png';
    }
    if (key.contains('chatgpt') || key.contains('gpt')) {
      return 'assets/images/chatgpt-logo.png';
    }
    if (key.contains('deepseek')) {
      return 'assets/images/deepseek_logo.png';
    }
    return null;
  }

  IconData _resolveInsightFallbackIcon(
    String raw, {
    required IconData defaultIcon,
  }) {
    final String key = raw.trim().toLowerCase();
    if (key.contains('ai') || key.contains('ml') || key.contains('llm')) {
      return Icons.auto_awesome_rounded;
    }
    if (key.contains('security')) return Icons.shield_rounded;
    if (key.contains('performance')) return Icons.speed_rounded;
    if (key.contains('devops')) return Icons.settings_rounded;
    if (key.contains('testing')) return Icons.fact_check_rounded;
    if (key.contains('cloud')) return Icons.cloud_rounded;
    if (key.contains('web3') || key.contains('blockchain')) {
      return Icons.link_rounded;
    }
    if (key.contains('microservice')) return Icons.device_hub_rounded;
    if (key.contains('python')) {
      return Icons.code_rounded;
    }
    if (key.contains('typescript') || key.contains('javascript')) {
      return Icons.data_object_rounded;
    }
    if (key.contains('angular') ||
        key.contains('react') ||
        key.contains('vue') ||
        key.contains('svelte')) {
      return Icons.web_rounded;
    }
    if (key.contains('django') ||
        key.contains('laravel') ||
        key.contains('express') ||
        key.contains('spring') ||
        key.contains('fastapi')) {
      return Icons.webhook_rounded;
    }
    if (key.contains('github') || key.contains('reddit')) {
      return Icons.hub_rounded;
    }
    return defaultIcon;
  }

  Color _resolveInsightColor(String raw, {required Color fallbackColor}) {
    final String key = raw.trim().toLowerCase();
    if (key.contains('python')) {
      return const Color(0xFF3776AB);
    }
    if (key.contains('typescript')) {
      return const Color(0xFF3178C6);
    }
    if (key.contains('javascript')) {
      return const Color(0xFFEAB308);
    }
    if (key.contains('react')) {
      return const Color(0xFF61DAFB);
    }
    if (key.contains('vue')) {
      return const Color(0xFF42B883);
    }
    if (key.contains('django')) {
      return const Color(0xFF0F766E);
    }
    if (key.contains('laravel')) {
      return const Color(0xFFF97316);
    }
    if (key.contains('express')) {
      return const Color(0xFF334155);
    }
    if (key.contains('spring')) {
      return const Color(0xFF65A30D);
    }
    if (key.contains('fastapi')) {
      return const Color(0xFF0891B2);
    }
    if (key.contains('angular')) {
      return const Color(0xFFDC2626);
    }
    if (key.contains('svelte')) {
      return const Color(0xFFEA580C);
    }
    if (key.contains('java') && !key.contains('javascript')) {
      return const Color(0xFFEA580C);
    }
    if (key.contains('c#') || key.contains('csharp')) {
      return const Color(0xFF8B5CF6);
    }
    if (key.contains('c++') || key.contains('cpp')) {
      return const Color(0xFF0EA5E9);
    }
    if (key.contains('kotlin')) {
      return const Color(0xFF7C3AED);
    }
    if (key.contains('php')) {
      return const Color(0xFF777BB4);
    }
    if (key.contains('rust')) {
      return const Color(0xFFCE422B);
    }
    if (key.contains('go')) {
      return const Color(0xFF00ADD8);
    }
    if (key.contains('ai') || key.contains('ml') || key.contains('llm')) {
      return const Color(0xFF111827);
    }
    if (key.contains('security')) return const Color(0xFF1E3A8A);
    if (key.contains('performance')) return const Color(0xFFF59E0B);
    if (key.contains('devops')) return const Color(0xFF64748B);
    if (key.contains('testing')) return const Color(0xFF10B981);
    if (key.contains('cloud')) return const Color(0xFF38BDF8);
    if (key.contains('web3') || key.contains('blockchain')) {
      return const Color(0xFF7C3AED);
    }
    if (key.contains('microservice')) return const Color(0xFF06B6D4);
    return fallbackColor;
  }

  Widget _buildInsightCard(_InsightCardData card) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: card.iconColor.withValues(alpha: 0.32),
          width: 1.8,
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: card.iconColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: card.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: card.iconAsset != null
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(card.iconAsset!, fit: BoxFit.contain),
                  )
                : Icon(
                    card.iconData ?? Icons.extension_rounded,
                    color: card.iconColor,
                    size: 26,
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  card.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: card.iconColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  card.description,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF475569),
                    height: 1.35,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportDataAsZip() async {
    final StringBuffer csv1 = StringBuffer(
      'framework,total_menciones,positivos,neutros,negativos,porcentaje_positivo,porcentaje_neutro,porcentaje_negativo\n',
    );
    for (final SentimientoModel item in sentimientoData) {
      csv1.writeln(
        '${_csvField(item.framework)},${item.totalMenciones},${item.positivos},${item.neutros},${item.negativos},'
        '${item.porcentajePositivo},${item.porcentajeNeutro},${item.porcentajeNegativo}',
      );
    }

    final StringBuffer csv2 = StringBuffer(
      'tema,menciones,menciones_previas,variacion_menciones,variacion_pct,tendencia\n',
    );
    for (final TemasEmergentesModel item in temasData) {
      csv2.writeln(
        '${_csvField(item.tema)},${item.menciones},${item.mencionesPrevias ?? ''},'
        '${item.deltaMenciones ?? ''},${item.growthPct ?? ''},${_csvField(item.trendDirection ?? '')}',
      );
    }

    final StringBuffer csv3 = StringBuffer(
      'tecnologia,ranking_github,ranking_reddit,brecha_absoluta\n',
    );
    for (final InterseccionModel item in interseccionData) {
      final int? github = item.rankingGitHub;
      final int? reddit = item.rankingReddit;
      final int? brecha = (github != null && reddit != null)
          ? (github - reddit).abs()
          : null;
      csv3.writeln(
        '${_csvField(item.tecnologia)},${github ?? ''},${reddit ?? ''},${brecha ?? ''}',
      );
    }

    final Archive archive = Archive();
    _addCsvToArchive(archive, '1_sentimiento_frameworks.csv', csv1.toString());
    _addCsvToArchive(archive, '2_temas_emergentes.csv', csv2.toString());
    _addCsvToArchive(
      archive,
      '3_interseccion_github_reddit.csv',
      csv3.toString(),
    );

    final zipData = ZipEncoder().encode(archive);
    if (zipData == null) {
      return;
    }

    try {
      await _downloadService.saveZipBytes(
        fileName: 'reddit_datos_completos',
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

  void _addCsvToArchive(Archive archive, String fileName, String content) {
    final List<int> bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(fileName, bytes.length, bytes));
  }

  String _csvField(Object? value) {
    final String text = (value ?? '').toString();
    final String normalized = text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n');
    final String escaped = normalized.replaceAll('"', '""');
    final bool needsQuotes =
        escaped.contains(',') ||
        escaped.contains('"') ||
        escaped.contains('\n');
    if (!needsQuotes) {
      return escaped;
    }
    return '"$escaped"';
  }
}

class _InsightCardData {
  final String title;
  final String description;
  final Color iconColor;
  final String? iconAsset;
  final IconData? iconData;

  const _InsightCardData({
    required this.title,
    required this.description,
    required this.iconColor,
    this.iconAsset,
    this.iconData,
  });
}

enum _SentimientoSort { porcentajePositivo, porcentajeNegativo, menciones }

enum _RedditTemasSort { menciones, growth, drop }

enum _RedditTemasMetric { menciones, share }

enum _RedditTemasDisplayMode { actual, delta }

enum _RedditInterseccionView { brecha, consenso, promedio }

enum _RedditInterseccionDetail { basico, avanzado }
