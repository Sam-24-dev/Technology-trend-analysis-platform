import 'dart:convert';
import 'dart:math' as math;

import 'package:archive/archive.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/run_manifest_models.dart';
import '../models/stackoverflow_models.dart';
import '../providers/app_providers.dart';
import '../services/download/download_service.dart';
import '../widgets/chart_card.dart';
import '../widgets/chart_legend.dart';
import '../widgets/chart_inline_filter.dart';
import '../widgets/degraded_state_card.dart';
import '../widgets/loading_skeleton.dart';

const Color kTitleColor = Color(0xFF0F172A);
const Color kBodyColor = Color(0xFF1E293B);
const Color kMutedColor = Color(0xFF475569);

class StackOverflowDashboard extends ConsumerStatefulWidget {
  final DownloadService? downloadService;

  const StackOverflowDashboard({super.key, this.downloadService});

  @override
  ConsumerState<StackOverflowDashboard> createState() =>
      _StackOverflowDashboardState();
}

class _StackOverflowDashboardState
    extends ConsumerState<StackOverflowDashboard> {
  late final DownloadService _downloadService =
      widget.downloadService ?? createDownloadService();

  List<VolumenPreguntasModel> volumenData = <VolumenPreguntasModel>[];
  List<TasaAceptacionModel> aceptacionData = <TasaAceptacionModel>[];
  List<TendenciaMensualModel> tendenciasData = <TendenciaMensualModel>[];
  StackOverflowVolumeHistoryModel? volumenHistory;
  StackOverflowAcceptanceHistoryModel? aceptacionHistory;
  StackOverflowTrendsHistoryModel? tendenciasHistory;

  bool isLoading = true;
  bool isDegraded = false;
  String? degradedMessage;
  String? errorMessage;
  int _volumenTopN = 0;
  _StackVolumeSort _volumenSort = _StackVolumeSort.preguntas;
  _StackVolumeMetric _volumenMetric = _StackVolumeMetric.preguntas;
  _StackAcceptanceMetric _aceptacionMetric =
      _StackAcceptanceMetric.tasaAceptacion;
  _StackAcceptanceSort _aceptacionSort = _StackAcceptanceSort.tasaDesc;
  _StackTrendView _trendView = _StackTrendView.volumenMensual;
  _StackTrendTop _trendTop = _StackTrendTop.top3;

  static const Color _soOrange = Color(0xFFF48024);

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    try {
      final DataLoadState<StackOverflowDashboardData> state = await ref.read(
        stackoverflowDashboardProvider.future,
      );
      if (!mounted) {
        return;
      }

      final StackOverflowDashboardData? data = state.data;
      if (state.isError || data == null) {
        setState(() {
          isLoading = false;
          errorMessage = state.message ?? 'No se pudieron cargar datos.';
        });
        return;
      }

      setState(() {
        volumenData = List<VolumenPreguntasModel>.from(data.volumen)
          ..sort((a, b) => b.preguntas.compareTo(a.preguntas));
        volumenHistory = data.volumenHistory;
        aceptacionHistory = data.aceptacionHistory;
        aceptacionData = List<TasaAceptacionModel>.from(data.aceptacion)
          ..sort((a, b) => b.tasaPct.compareTo(a.tasaPct));
        tendenciasData = List<TendenciaMensualModel>.from(data.tendencias);
        tendenciasHistory = data.tendenciasHistory;
        if (!(data.volumenHistory?.hasHistoricalComparison ?? false)) {
          _volumenSort = _StackVolumeSort.preguntas;
          _volumenMetric = _StackVolumeMetric.preguntas;
        }
        _volumenMetric = _normalizeVolumeMetric(_volumenMetric);
        _volumenSort = _normalizeVolumeSort(
          _volumenSort,
          metric: _volumenMetric,
        );
        _volumenTopN = _normalizeVolumeTop(
          _volumenTopN,
          metric: _volumenMetric,
        );
        _aceptacionMetric = _normalizeAcceptanceMetric(_aceptacionMetric);
        _aceptacionSort = _normalizeAcceptanceSort(
          _aceptacionSort,
          metric: _aceptacionMetric,
        );
        isDegraded = state.isDegraded;
        degradedMessage = state.isDegraded ? state.message : null;
        errorMessage = null;
        isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        isLoading = false;
        errorMessage = 'Error cargando datos: $error';
      });
    }
  }

  Future<void> _exportDataAsZip() async {
    final StringBuffer csvVolumen = StringBuffer(
      'lenguaje,preguntas_nuevas,preguntas_previas,variacion_preguntas,variacion_pct,tendencia,participacion_pct\n',
    );
    for (final VolumenPreguntasModel item in volumenData) {
      csvVolumen.writeln(
        '${_csvField(item.lenguaje)},${item.preguntas},${item.preguntasPrev},'
        '${item.deltaPreguntas},${_formatCsvDouble(item.growthPct)},'
        '${_csvField(item.trendDirection ?? '')},${_formatCsvDouble(item.sharePct)}',
      );
    }

    final StringBuffer csvAceptacion = StringBuffer(
      'tecnologia,preguntas_totales,respuestas_aceptadas,tasa_aceptacion_pct,'
      'preguntas_totales_previas,respuestas_aceptadas_previas,'
      'tasa_aceptacion_previa_pct,variacion_tasa_pct,variacion_preguntas,'
      'calidad_muestra,confidence_score,raw_rank,confidence_rank\n',
    );
    for (final TasaAceptacionModel item in aceptacionData) {
      csvAceptacion.writeln(
        '${_csvField(item.tecnologia)},${item.totalPreguntas},'
        '${item.respuestasAceptadas},${_formatCsvDouble(item.tasaPct)},'
        '${item.totalPreguntasPrev},${item.respuestasAceptadasPrev},'
        '${_formatCsvDouble(item.tasaAceptacionPrevPct)},'
        '${_formatCsvDouble(item.deltaTasaPct)},${item.deltaPreguntas},'
        '${_csvField(item.sampleBucket ?? '')},'
        '${_formatCsvDouble(item.confidenceScore)},${item.rawRank},'
        '${item.confidenceRank}',
      );
    }

    final StackOverflowTrendsHistoryModel trendHistory =
        _effectiveTrendsHistory();
    final StringBuffer csvTendencias = StringBuffer(
      'tecnologia,mes,valor,indice_base_100,start_value,end_value,'
      'abs_delta,pct_delta,retention_pct,latest_rank\n',
    );
    for (final StackOverflowTrendSeriesModel serie in trendHistory.series) {
      final List<double> base100 = _normalizedTrendPoints(serie);
      for (int index = 0; index < trendHistory.months.length; index++) {
        final int value = index < serie.points.length ? serie.points[index] : 0;
        final double normalized = index < base100.length ? base100[index] : 0.0;
        csvTendencias.writeln(
          '${_csvField(serie.tecnologia)},${_csvField(trendHistory.months[index])},'
          '$value,${_formatCsvDouble(normalized)},${serie.startValue},'
          '${serie.endValue},${serie.absDelta},${_formatCsvDouble(serie.pctDelta)},'
          '${_formatCsvDouble(serie.retentionPct)},${serie.latestRank}',
        );
      }
    }

    final Archive archive = Archive()
      ..addFile(
        ArchiveFile(
          '1_preguntas_nuevas_por_lenguaje.csv',
          csvVolumen.length,
          utf8.encode(csvVolumen.toString()),
        ),
      )
      ..addFile(
        ArchiveFile(
          '2_respuestas_aceptadas.csv',
          csvAceptacion.length,
          utf8.encode(csvAceptacion.toString()),
        ),
      )
      ..addFile(
        ArchiveFile(
          '3_tendencias_mensuales.csv',
          csvTendencias.length,
          utf8.encode(csvTendencias.toString()),
        ),
      );

    final List<int>? zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      return;
    }

    try {
      await _downloadService.saveZipBytes(
        fileName: 'stackoverflow_datos_completos',
        bytes: zipBytes,
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
    if (isLoading) {
      return _buildLoadingSkeleton(context);
    }

    if (errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
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
        final List<TasaAceptacionModel> visibleAceptacion =
            _visibleAceptacionData();
        final double acceptanceHeight = math.max(
          360,
          (visibleAceptacion.length * 84).toDouble() + 120,
        );
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
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Dashboard StackOverflow',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: kTitleColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          buildAnalysisPeriodLabel(manifest),
                          style: const TextStyle(
                            fontSize: 16,
                            color: kMutedColor,
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
                      backgroundColor: _soOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              if (isDegraded) ...<Widget>[
                const SizedBox(height: 16),
                DegradedStateCard(
                  message:
                      degradedMessage ??
                      'Modo degradado: algunos datasets no estuvieron disponibles.',
                  onRetry: _loadAllData,
                ),
              ],
              const SizedBox(height: 24),
              _buildInsightsSection(constraints.maxWidth),
              const SizedBox(height: 24),
              ChartCard(
                title: 'Lenguajes por volumen de preguntas nuevas',
                subtitle: _buildVolumeSubtitle(),
                height: 500,
                chart: _buildVolumeChart(),
                legend: _buildVolumeLegend(context),
                semanticLabel: _buildVolumeChartAltText(),
              ),
              const SizedBox(height: 24),
              ChartCard(
                title: 'Tasa de respuestas aceptadas',
                subtitle: _buildAcceptanceSubtitle(),
                height: acceptanceHeight,
                chart: _buildAcceptanceChart(),
                legend: _buildAcceptanceLegend(),
                semanticLabel: _buildAcceptanceChartAltText(),
              ),
              const SizedBox(height: 24),
              ChartCard(
                title: 'Tendencias evolutivas',
                subtitle: _buildTrendSubtitle(),
                height: 500,
                chart: _buildTrendChart(),
                semanticLabel: _buildTrendChartAltText(),
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
              chartHeight: 500,
              filterPills: 3,
              legendItems: 3,
            ),
            const SizedBox(height: 24),
            const ChartSkeletonCard(
              chartHeight: 420,
              filterPills: 2,
              legendItems: 3,
            ),
            const SizedBox(height: 24),
            const ChartSkeletonCard(
              chartHeight: 500,
              filterPills: 2,
              legendItems: 4,
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

  Widget _buildVolumeLegend(BuildContext context) {
    final _StackVolumeMetric metric = _effectiveVolumeMetric();
    if (metric == _StackVolumeMetric.variacion) {
      return const ChartLegend(
        items: <ChartLegendItemData>[
          ChartLegendItemData(
            label: 'Crecimiento',
            color: Color(0xFF059669),
          ),
          ChartLegendItemData(
            label: 'Caida',
            color: Color(0xFFDC2626),
          ),
          ChartLegendItemData(
            label: 'Sin cambio',
            color: Color(0xFF64748B),
          ),
        ],
      );
    }
    final String label =
        metric == _StackVolumeMetric.participacion
        ? 'Barras: % participacion'
        : 'Barras: preguntas nuevas';
    return ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: label,
          color: _soOrange,
          marker: ChartLegendMarker.square,
        ),
      ],
    );
  }

  Widget _buildAcceptanceLegend() {
    final _StackAcceptanceMetric metric = _effectiveAcceptanceMetric();
    if (metric == _StackAcceptanceMetric.variacion) {
      return const ChartLegend(
        items: <ChartLegendItemData>[
          ChartLegendItemData(
            label: 'Mejora',
            color: Color(0xFF10B981),
          ),
          ChartLegendItemData(
            label: 'Caida',
            color: Color(0xFFEF4444),
          ),
          ChartLegendItemData(
            label: 'Linea base',
            color: Color(0xFF94A3B8),
            marker: ChartLegendMarker.line,
          ),
        ],
      );
    }
    return const ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: '% aceptadas',
          color: Color(0xFF10B981),
          marker: ChartLegendMarker.square,
        ),
        ChartLegendItemData(
          label: 'Base total',
          color: Color(0xFFE2E8F0),
          marker: ChartLegendMarker.square,
        ),
      ],
    );
  }

  String _buildVolumeChartAltText() {
    final _StackVolumeMetric metric = _effectiveVolumeMetric();
    final String metricLabel = _volumeMetricLabel(metric);
    final String orderLabel = _volumeSortLabel(_effectiveVolumeSort());
    final int topN = _effectiveVolumeTopN();
    final String topLabel = topN > 0 ? 'top $topN' : 'todos los lenguajes';
    return 'Grafico de barras. Metrica: $metricLabel por lenguaje. '
        'Vista: $topLabel. Orden: $orderLabel.';
  }

  String _buildAcceptanceChartAltText() {
    final _StackAcceptanceMetric metric = _effectiveAcceptanceMetric();
    final _StackAcceptanceSort sort = _effectiveAcceptanceSort();
    return 'Panel de tasa de aceptacion por tecnologia. '
        'Metrica: ${_acceptanceMetricLabel(metric)}. '
        'Orden: ${_acceptanceSortLabel(sort)}.';
  }

  String _buildTrendChartAltText() {
    final String viewLabel = _trendViewLabel(_trendView);
    final String topLabel = _trendTopLabel(_trendTop);
    return 'Grafico de lineas con tendencia mensual. '
        'Vista: $viewLabel. $topLabel.';
  }

  Widget _buildInsightsSection(double _) {
    final Map<String, Object?> trendInsight = _buildTrendInsight();
    final String? trendTech = trendInsight['tech'] as String?;
    final String? trendLogo =
        trendTech == null ? null : _resolveFrameworkLogo(trendTech);
    final TasaAceptacionModel? bestAcceptance = _canonicalAcceptanceLeader();
    final VolumenPreguntasModel? topVolume = _canonicalVolumeLeader();

    final List<_InsightCardData> cards = <_InsightCardData>[
      if (topVolume != null)
        _InsightCardData(
          iconAsset: _resolveFrameworkLogo(topVolume.lenguaje),
          iconData: _resolveFrameworkFallbackIcon(topVolume.lenguaje),
          iconColor: const Color(0xFF3B82F6),
          title: _buildVolumeInsightTitle(topVolume),
          description: _buildVolumeInsightDescription(topVolume),
        ),
      if (bestAcceptance != null)
        _InsightCardData(
          iconAsset: _resolveFrameworkLogo(bestAcceptance.tecnologia),
          iconData: _resolveFrameworkFallbackIcon(bestAcceptance.tecnologia),
          iconColor: const Color(0xFFEF4444),
          title: _buildAcceptanceInsightTitle(bestAcceptance),
          description: _buildAcceptanceInsightDescription(bestAcceptance),
        ),
      _InsightCardData(
        iconAsset: trendLogo,
        iconData: trendLogo == null
            ? trendInsight['icon'] as IconData
            : null,
        iconColor: trendInsight['color'] as Color,
        title: trendInsight['title'] as String,
        description: trendInsight['description'] as String,
      ),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Insights clave',
            style: TextStyle(
              fontSize: 36 / 2,
              fontWeight: FontWeight.w700,
              color: kTitleColor,
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: cards.asMap().entries.map((entry) {
              final bool isLast = entry.key == cards.length - 1;
              return Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                child: _InsightCard(card: entry.value),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  VolumenPreguntasModel? _canonicalVolumeLeader() {
    if (volumenHistory?.summary.leader != null) {
      return volumenHistory!.summary.leader;
    }
    if (volumenData.isEmpty) {
      return null;
    }
    return volumenData.reduce(
      (VolumenPreguntasModel current, VolumenPreguntasModel next) =>
          current.preguntas >= next.preguntas ? current : next,
    );
  }

  String _buildVolumeInsightTitle(VolumenPreguntasModel leader) {
    return '${_formatTech(leader.lenguaje)} lidera el volumen en StackOverflow';
  }

  String _buildVolumeInsightDescription(VolumenPreguntasModel leader) {
    final String currentQuestions = _formatInt(leader.preguntas);
    final String share = '${leader.sharePct.toStringAsFixed(1)}%';
    if (_hasVolumeHistoricalComparison &&
        volumenHistory?.previousSnapshotDate != null) {
      final String previous = _formatUtcDate(
        volumenHistory?.previousSnapshotDate,
      );
      return '$currentQuestions preguntas nuevas, $share del total, '
          'var ${_formatSignedPercent(leader.growthPct)} vs $previous';
    }
    return '$currentQuestions preguntas nuevas, $share del total.';
  }

  TasaAceptacionModel? _canonicalAcceptanceLeader() {
    if (aceptacionHistory?.summary.confidenceLeader != null) {
      return aceptacionHistory!.summary.confidenceLeader;
    }
    if (aceptacionData.isEmpty) {
      return null;
    }
    return _findBestAcceptance();
  }

  String _buildAcceptanceInsightTitle(TasaAceptacionModel leader) {
    return '${_formatTech(leader.tecnologia)} combina alta aceptaci\u00F3n y muestra s\u00F3lida';
  }

  String _buildAcceptanceInsightDescription(TasaAceptacionModel leader) {
    final String rate = '${leader.tasaPct.toStringAsFixed(1)}%';
    final String total = _formatInt(leader.totalPreguntas);
    if (_hasAcceptanceHistoricalComparison &&
        aceptacionHistory?.previousSnapshotDate != null) {
      final String previous = _formatUtcDate(
        aceptacionHistory?.previousSnapshotDate,
      );
      return '$rate de aceptaci\u00F3n sobre $total preguntas, '
          'var ${_formatSignedPoints(leader.deltaTasaPct)} vs $previous';
    }
    return '$rate de aceptaci\u00F3n sobre $total preguntas.';
  }

  List<T> _applyTopN<T>(List<T> ordered, int topN) {
    if (topN <= 0 || topN >= ordered.length) {
      return ordered;
    }
    return ordered.take(topN).toList();
  }

  bool get _hasVolumeHistoricalComparison =>
      volumenHistory?.hasHistoricalComparison ?? false;

  bool _isActiveVolumeItem(VolumenPreguntasModel item) => item.preguntas > 0;

  bool _hasComparableVolumeVariation(VolumenPreguntasModel item) =>
      item.preguntasPrev > 0 && item.deltaPreguntas != 0;

  List<VolumenPreguntasModel> _volumeMetricBaseData({
    _StackVolumeMetric? metric,
  }) {
    final _StackVolumeMetric effectiveMetric =
        metric ?? _normalizeVolumeMetric(_volumenMetric);
    switch (effectiveMetric) {
      case _StackVolumeMetric.preguntas:
      case _StackVolumeMetric.participacion:
        return volumenData.where(_isActiveVolumeItem).toList(growable: false);
      case _StackVolumeMetric.variacion:
        return volumenData
            .where(_hasComparableVolumeVariation)
            .toList(growable: false);
    }
  }

  List<_StackVolumeMetric> _availableVolumeMetricOptions() {
    final bool hasVariationData =
        _hasVolumeHistoricalComparison &&
        _volumeMetricBaseData(metric: _StackVolumeMetric.variacion).isNotEmpty;
    return hasVariationData
        ? const <_StackVolumeMetric>[
            _StackVolumeMetric.preguntas,
            _StackVolumeMetric.participacion,
            _StackVolumeMetric.variacion,
          ]
        : const <_StackVolumeMetric>[
            _StackVolumeMetric.preguntas,
            _StackVolumeMetric.participacion,
          ];
  }

  _StackVolumeMetric _normalizeVolumeMetric(_StackVolumeMetric metric) {
    final List<_StackVolumeMetric> options = _availableVolumeMetricOptions();
    return options.contains(metric) ? metric : options.first;
  }

  _StackVolumeMetric _effectiveVolumeMetric() {
    return _normalizeVolumeMetric(_volumenMetric);
  }

  List<_StackVolumeSort> _availableVolumeSortOptions({
    _StackVolumeMetric? metric,
  }) {
    final _StackVolumeMetric effectiveMetric =
        metric ?? _normalizeVolumeMetric(_volumenMetric);
    switch (effectiveMetric) {
      case _StackVolumeMetric.preguntas:
        return const <_StackVolumeSort>[_StackVolumeSort.preguntas];
      case _StackVolumeMetric.participacion:
        return const <_StackVolumeSort>[_StackVolumeSort.participacion];
      case _StackVolumeMetric.variacion:
        final List<VolumenPreguntasModel> comparable = _volumeMetricBaseData(
          metric: _StackVolumeMetric.variacion,
        );
        final List<_StackVolumeSort> options = <_StackVolumeSort>[];
        if (comparable.any((item) => item.deltaPreguntas > 0)) {
          options.add(_StackVolumeSort.crecimiento);
        }
        if (comparable.any((item) => item.deltaPreguntas < 0)) {
          options.add(_StackVolumeSort.caida);
        }
        return options.isEmpty
            ? const <_StackVolumeSort>[_StackVolumeSort.caida]
            : options;
    }
  }

  _StackVolumeSort _normalizeVolumeSort(
    _StackVolumeSort sort, {
    _StackVolumeMetric? metric,
  }) {
    final List<_StackVolumeSort> options = _availableVolumeSortOptions(
      metric: metric,
    );
    return options.contains(sort) ? sort : options.first;
  }

  _StackVolumeSort _effectiveVolumeSort() {
    final _StackVolumeMetric normalizedMetric = _effectiveVolumeMetric();
    return _normalizeVolumeSort(_volumenSort, metric: normalizedMetric);
  }

  List<int> _buildVolumeTopOptions({_StackVolumeMetric? metric}) {
    final int visibleCount = _volumeMetricBaseData(metric: metric).length;
    final List<int> options = <int>[0];
    if (visibleCount <= 5) {
      return options;
    }
    for (final int preset in <int>[5, 8, 10]) {
      if (preset < visibleCount) {
        options.add(preset);
      }
    }
    return options;
  }

  int _normalizeVolumeTop(int topN, {_StackVolumeMetric? metric}) {
    final List<int> options = _buildVolumeTopOptions(metric: metric);
    return options.contains(topN) ? topN : 0;
  }

  int _effectiveVolumeTopN() {
    final _StackVolumeMetric normalizedMetric = _effectiveVolumeMetric();
    return _normalizeVolumeTop(_volumenTopN, metric: normalizedMetric);
  }

  List<DropdownMenuItem<int>> _buildVolumeTopMenuItems({
    _StackVolumeMetric? metric,
  }) {
    final List<int> options = _buildVolumeTopOptions(metric: metric);
    return options.map((int value) {
      return DropdownMenuItem<int>(
        value: value,
        child: Text(value == 0 ? 'Ver todos' : 'Top $value'),
      );
    }).toList();
  }

  List<DropdownMenuItem<_StackVolumeSort>> _buildVolumeSortMenuItems() {
    final List<_StackVolumeSort> options = _availableVolumeSortOptions();
    return options.map((option) {
      return DropdownMenuItem<_StackVolumeSort>(
        value: option,
        child: Text(_volumeSortLabel(option)),
      );
    }).toList();
  }

  List<DropdownMenuItem<_StackVolumeMetric>> _buildVolumeMetricMenuItems() {
    final List<_StackVolumeMetric> options = _availableVolumeMetricOptions();
    return options.map((option) {
      return DropdownMenuItem<_StackVolumeMetric>(
        value: option,
        child: Text(_volumeMetricLabel(option)),
      );
    }).toList();
  }

  String _volumeSortLabel(_StackVolumeSort value) {
    switch (value) {
      case _StackVolumeSort.preguntas:
        return 'M\u00E1s preguntas';
      case _StackVolumeSort.participacion:
        return 'Mayor participaci\u00F3n';
      case _StackVolumeSort.crecimiento:
        return 'Mayor crecimiento';
      case _StackVolumeSort.caida:
        return 'Mayor ca\u00EDda';
    }
  }

  String _volumeMetricLabel(_StackVolumeMetric value) {
    switch (value) {
      case _StackVolumeMetric.preguntas:
        return 'Preguntas nuevas';
      case _StackVolumeMetric.participacion:
        return '% participaci\u00F3n';
      case _StackVolumeMetric.variacion:
        return 'Variaci\u00F3n';
    }
  }

  String _volumeTopLabel(int value) {
    return value <= 0 ? 'Ver todos' : 'Top $value';
  }

  String _buildVolumeSubtitle() {
    if (!_hasVolumeHistoricalComparison) {
      final String latest = _formatUtcDate(volumenHistory?.latestSnapshotDate);
      return 'Snapshot actual (UTC): $latest';
    }
    final String? previousRaw = volumenHistory?.previousSnapshotDate;
    final String? latestRaw = volumenHistory?.latestSnapshotDate;
    final String previous = _formatUtcDate(previousRaw);
    final String latest = _formatUtcDate(latestRaw);
    return 'Top: ${_volumeTopLabel(_effectiveVolumeTopN())}   '
        'Orden: ${_volumeSortLabel(_effectiveVolumeSort())}   '
        'M\u00E9trica: ${_volumeMetricLabel(_effectiveVolumeMetric())}\n'
        'Comparado (UTC): $previous -> $latest';
  }

  String _acceptanceMetricLabel(_StackAcceptanceMetric value) {
    switch (value) {
      case _StackAcceptanceMetric.tasaAceptacion:
        return 'Tasa de aceptaci\u00F3n';
      case _StackAcceptanceMetric.variacion:
        return 'Variaci\u00F3n';
    }
  }

  String _acceptanceSortLabel(_StackAcceptanceSort value) {
    switch (value) {
      case _StackAcceptanceSort.tasaDesc:
        return 'Mayor tasa';
      case _StackAcceptanceSort.tasaAsc:
        return 'Menor tasa';
      case _StackAcceptanceSort.mejora:
        return 'Mayor mejora';
      case _StackAcceptanceSort.caida:
        return 'Mayor ca\u00EDda';
    }
  }

  bool get _hasAcceptanceHistoricalComparison =>
      aceptacionHistory?.hasHistoricalComparison ?? false;

  List<_StackAcceptanceMetric> _availableAcceptanceMetricOptions() {
    final options = <_StackAcceptanceMetric>[
      _StackAcceptanceMetric.tasaAceptacion,
    ];
    if (_hasAcceptanceHistoricalComparison) {
      options.add(_StackAcceptanceMetric.variacion);
    }
    return options;
  }

  _StackAcceptanceMetric _normalizeAcceptanceMetric(
    _StackAcceptanceMetric metric,
  ) {
    if (!_hasAcceptanceHistoricalComparison &&
        metric == _StackAcceptanceMetric.variacion) {
      return _StackAcceptanceMetric.tasaAceptacion;
    }
    return metric;
  }

  _StackAcceptanceMetric _effectiveAcceptanceMetric() {
    return _normalizeAcceptanceMetric(_aceptacionMetric);
  }

  List<_StackAcceptanceSort> _availableAcceptanceSortOptions({
    _StackAcceptanceMetric? metric,
  }) {
    switch (metric ?? _effectiveAcceptanceMetric()) {
      case _StackAcceptanceMetric.tasaAceptacion:
        return const <_StackAcceptanceSort>[
          _StackAcceptanceSort.tasaDesc,
          _StackAcceptanceSort.tasaAsc,
        ];
      case _StackAcceptanceMetric.variacion:
        return const <_StackAcceptanceSort>[
          _StackAcceptanceSort.mejora,
          _StackAcceptanceSort.caida,
        ];
    }
  }

  _StackAcceptanceSort _normalizeAcceptanceSort(
    _StackAcceptanceSort sort, {
    required _StackAcceptanceMetric metric,
  }) {
    final List<_StackAcceptanceSort> options = _availableAcceptanceSortOptions(
      metric: metric,
    );
    if (options.contains(sort)) {
      return sort;
    }
    return options.first;
  }

  _StackAcceptanceSort _effectiveAcceptanceSort() {
    return _normalizeAcceptanceSort(
      _aceptacionSort,
      metric: _effectiveAcceptanceMetric(),
    );
  }

  List<DropdownMenuItem<_StackAcceptanceMetric>>
  _buildAcceptanceMetricMenuItems() {
    final options = _availableAcceptanceMetricOptions();
    return options.map((option) {
      return DropdownMenuItem<_StackAcceptanceMetric>(
        value: option,
        child: Text(_acceptanceMetricLabel(option)),
      );
    }).toList();
  }

  List<DropdownMenuItem<_StackAcceptanceSort>> _buildAcceptanceSortMenuItems() {
    final options = _availableAcceptanceSortOptions();
    return options.map((option) {
      return DropdownMenuItem<_StackAcceptanceSort>(
        value: option,
        child: Text(_acceptanceSortLabel(option)),
      );
    }).toList();
  }

  String _buildAcceptanceSubtitle() {
    final _StackAcceptanceMetric metric = _effectiveAcceptanceMetric();
    final _StackAcceptanceSort sort = _effectiveAcceptanceSort();
    if (!_hasAcceptanceHistoricalComparison) {
      final String latest = _formatUtcDate(
        aceptacionHistory?.latestSnapshotDate,
      );
      return 'M\u00E9trica: ${_acceptanceMetricLabel(metric)}   '
          'Orden: ${_acceptanceSortLabel(sort)}\n'
          'Snapshot actual (UTC): $latest';
    }

    final String? previousRaw = aceptacionHistory?.previousSnapshotDate;
    final String? latestRaw = aceptacionHistory?.latestSnapshotDate;
    final String previous = _formatUtcDate(previousRaw);
    final String latest = _formatUtcDate(latestRaw);
    return 'M\u00E9trica: ${_acceptanceMetricLabel(metric)}   '
        'Orden: ${_acceptanceSortLabel(sort)}\n'
        'Comparado (UTC): $previous -> $latest';
  }

  String _trendViewLabel(_StackTrendView value) {
    switch (value) {
      case _StackTrendView.volumenMensual:
        return 'Volumen mensual';
      case _StackTrendView.indiceBase100:
        return '\u00CDndice base 100';
    }
  }

  List<DropdownMenuItem<_StackTrendView>> _buildTrendViewMenuItems() {
    return _StackTrendView.values.map((option) {
      return DropdownMenuItem<_StackTrendView>(
        value: option,
        child: Text(_trendViewLabel(option)),
      );
    }).toList();
  }

  String _trendTopLabel(_StackTrendTop value) {
    switch (value) {
      case _StackTrendTop.top3:
        return 'Top 3';
      case _StackTrendTop.todas:
        return 'Todas';
    }
  }

  List<DropdownMenuItem<_StackTrendTop>> _buildTrendTopMenuItems(
    int seriesCount,
  ) {
    final List<_StackTrendTop> options = seriesCount > 3
        ? const <_StackTrendTop>[_StackTrendTop.top3, _StackTrendTop.todas]
        : const <_StackTrendTop>[_StackTrendTop.todas];
    return options.map((option) {
      return DropdownMenuItem<_StackTrendTop>(
        value: option,
        child: Text(_trendTopLabel(option)),
      );
    }).toList();
  }

  _StackTrendTop _normalizeTrendTop(int seriesCount) {
    if (seriesCount <= 3) {
      return _StackTrendTop.todas;
    }
    return _trendTop;
  }

  String _buildTrendSubtitle() {
    final StackOverflowTrendsHistoryModel trends = _effectiveTrendsHistory();
    final _StackTrendTop effectiveTop = _normalizeTrendTop(
      _trendVisualSeries(trends).length,
    );
    final String start = trends.months.isEmpty
        ? 'n/d'
        : _formatMonthWithYear(trends.months.first);
    final String end = trends.months.isEmpty
        ? 'n/d'
        : _formatMonthWithYear(trends.months.last);
    final String topLabel = effectiveTop == _StackTrendTop.top3
        ? 'Top 3 (según último mes)'
        : 'Todas';
    return 'Vista: ${_trendViewLabel(_trendView)}   Top: $topLabel\n'
        'Per\u00EDodo mensual (12 meses completos): $start -> $end';
  }

  String _formatUtcDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return 'no disponible';
    }
    final List<String> parts = raw.trim().split('-');
    if (parts.length != 3) {
      return raw.trim();
    }
    return '${parts[2]}/${parts[1]}/${parts[0]}';
  }

  List<VolumenPreguntasModel> _visibleVolumenData() {
    final _StackVolumeMetric effectiveMetric = _effectiveVolumeMetric();
    final _StackVolumeSort effectiveSort = _effectiveVolumeSort();
    final List<VolumenPreguntasModel> ordered =
        List<VolumenPreguntasModel>.from(
          _volumeMetricBaseData(metric: effectiveMetric),
        )..sort((VolumenPreguntasModel a, VolumenPreguntasModel b) {
          switch (effectiveSort) {
            case _StackVolumeSort.preguntas:
              return b.preguntas.compareTo(a.preguntas);
            case _StackVolumeSort.participacion:
              final int byShare = b.sharePct.compareTo(a.sharePct);
              if (byShare != 0) {
                return byShare;
              }
              return b.preguntas.compareTo(a.preguntas);
            case _StackVolumeSort.crecimiento:
              final int byGrowth = b.deltaPreguntas.compareTo(a.deltaPreguntas);
              if (byGrowth != 0) {
                return byGrowth;
              }
              return b.preguntas.compareTo(a.preguntas);
            case _StackVolumeSort.caida:
              final int byDrop = a.deltaPreguntas.compareTo(b.deltaPreguntas);
              if (byDrop != 0) {
                return byDrop;
              }
              return b.preguntas.compareTo(a.preguntas);
          }
        });
    return _applyTopN<VolumenPreguntasModel>(ordered, _effectiveVolumeTopN());
  }

  List<TasaAceptacionModel> _visibleAceptacionData() {
    final _StackAcceptanceMetric metric = _effectiveAcceptanceMetric();
    final _StackAcceptanceSort sort = _effectiveAcceptanceSort();
    final Iterable<TasaAceptacionModel> base =
        metric == _StackAcceptanceMetric.variacion
        ? aceptacionData.where(
            (item) =>
                item.deltaPreguntas != 0 || item.deltaTasaPct.abs() > 0.0001,
          )
        : aceptacionData;
    final List<TasaAceptacionModel> ordered =
        List<TasaAceptacionModel>.from(base)
          ..sort((TasaAceptacionModel a, TasaAceptacionModel b) {
            switch (sort) {
              case _StackAcceptanceSort.tasaDesc:
                final int byRate = b.tasaPct.compareTo(a.tasaPct);
                if (byRate != 0) {
                  return byRate;
                }
                return b.totalPreguntas.compareTo(a.totalPreguntas);
              case _StackAcceptanceSort.tasaAsc:
                final int byRate = a.tasaPct.compareTo(b.tasaPct);
                if (byRate != 0) {
                  return byRate;
                }
                return b.totalPreguntas.compareTo(a.totalPreguntas);
              case _StackAcceptanceSort.mejora:
                final int byDelta = b.deltaTasaPct.compareTo(a.deltaTasaPct);
                if (byDelta != 0) {
                  return byDelta;
                }
                return b.totalPreguntas.compareTo(a.totalPreguntas);
              case _StackAcceptanceSort.caida:
                final int byDelta = a.deltaTasaPct.compareTo(b.deltaTasaPct);
                if (byDelta != 0) {
                  return byDelta;
                }
                return b.totalPreguntas.compareTo(a.totalPreguntas);
            }
          });
    return ordered;
  }

  Widget _buildVolumeChart() {
    if (volumenData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final _StackVolumeMetric effectiveMetric = _effectiveVolumeMetric();
    final _StackVolumeSort effectiveSort = _effectiveVolumeSort();
    final List<VolumenPreguntasModel> visible = _visibleVolumenData();
    final bool renderVariation =
        effectiveMetric == _StackVolumeMetric.variacion;
    final bool renderParticipation =
        effectiveMetric == _StackVolumeMetric.participacion;
    final List<double> values = visible.map((VolumenPreguntasModel item) {
      switch (effectiveMetric) {
        case _StackVolumeMetric.preguntas:
          return item.preguntas.toDouble();
        case _StackVolumeMetric.participacion:
          return item.sharePct;
        case _StackVolumeMetric.variacion:
          return item.deltaPreguntas.toDouble();
      }
    }).toList();
    final double maxRaw = values.isEmpty ? 0 : values.reduce(math.max);
    final double minRaw = values.isEmpty ? 0 : values.reduce(math.min);
    final double maxAbs = math.max(maxRaw.abs(), minRaw.abs());
    final double yInterval = renderParticipation
        ? _computePercentYAxisStep(math.max(maxRaw, 1))
        : _computeYAxisStep(
            renderVariation ? math.max(maxAbs, 1) : math.max(maxRaw, 1),
          );
    final double maxY = renderVariation
        ? math.max(
            yInterval,
            (math.max(0, maxRaw) / yInterval).ceil() * yInterval,
          )
        : ((math.max(1, maxRaw) / yInterval).ceil() * yInterval);
    final double minY = renderVariation
        ? (minRaw < 0 ? (minRaw / yInterval).floor() * yInterval : 0)
        : 0;
    final List<_VolumeBadgeData> badges = _buildVolumeBadges(
      visible,
      metric: effectiveMetric,
    );
    final List<int> topOptions = _buildVolumeTopOptions(
      metric: effectiveMetric,
    );
    final List<DropdownMenuItem<_StackVolumeSort>> sortItems =
        _buildVolumeSortMenuItems();
    final List<DropdownMenuItem<_StackVolumeMetric>> metricItems =
        _buildVolumeMetricMenuItems();

    final Widget chart = BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        minY: minY,
        maxY: maxY,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            tooltipRoundedRadius: 8,
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            getTooltipColor: (_) => const Color(0xFF0F172A),
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final VolumenPreguntasModel item = visible[group.x.toInt()];
              return BarTooltipItem(
                _buildVolumeTooltipText(item, metric: effectiveMetric),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double value) => FlLine(
            color: value == 0
                ? const Color(0xFFCBD5E1)
                : const Color(0xFFE2E8F0),
            strokeWidth: value == 0 ? 1.2 : 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 52,
              interval: yInterval,
              getTitlesWidget: (value, meta) {
                return Text(
                  _formatVolumeAxisValue(value, metric: effectiveMetric),
                  style: const TextStyle(fontSize: 11, color: kMutedColor),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 38,
              getTitlesWidget: (value, meta) {
                final int idx = value.toInt();
                if (idx < 0 || idx >= visible.length) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatTech(visible[idx].lenguaje),
                    style: const TextStyle(
                      fontSize: 12,
                      color: kBodyColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        barGroups: visible.asMap().entries.map((entry) {
          final VolumenPreguntasModel item = entry.value;
          final double value = switch (effectiveMetric) {
            _StackVolumeMetric.preguntas => item.preguntas.toDouble(),
            _StackVolumeMetric.participacion => item.sharePct,
            _StackVolumeMetric.variacion => item.deltaPreguntas.toDouble(),
          };
          final bool isNegative = value < 0;
          final Color color = renderVariation
              ? _volumeVariationColor(item.deltaPreguntas)
              : _volumeCurrentColor(entry.key);
          return BarChartGroupData(
            x: entry.key,
            barRods: <BarChartRodData>[
              BarChartRodData(
                fromY: 0,
                toY: value,
                width: 22,
                color: color,
                borderRadius: isNegative
                    ? const BorderRadius.only(
                        bottomLeft: Radius.circular(6),
                        bottomRight: Radius.circular(6),
                      )
                    : const BorderRadius.only(
                        topLeft: Radius.circular(6),
                        topRight: Radius.circular(6),
                      ),
              ),
            ],
          );
        }).toList(),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            if (topOptions.length > 1)
              ChartInlineFilter<int>(
                key: const ValueKey<String>('so-volume-top-filter'),
                label: 'Top',
                value: _effectiveVolumeTopN(),
                selectedLabel: _volumeTopLabel(_effectiveVolumeTopN()),
                items: _buildVolumeTopMenuItems(metric: effectiveMetric),
                onChanged: (int? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _volumenTopN = value;
                  });
                },
              ),
            if (sortItems.length > 1)
              ChartInlineFilter<_StackVolumeSort>(
                key: const ValueKey<String>('so-volume-sort-filter'),
                label: 'Orden',
                value: effectiveSort,
                selectedLabel: _volumeSortLabel(effectiveSort),
                items: sortItems,
                onChanged: (_StackVolumeSort? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _volumenSort = value;
                  });
                },
              ),
            if (metricItems.length > 1)
              ChartInlineFilter<_StackVolumeMetric>(
                key: const ValueKey<String>('so-volume-metric-filter'),
                label: 'M\u00E9trica',
                value: effectiveMetric,
                selectedLabel: _volumeMetricLabel(effectiveMetric),
                items: metricItems,
                onChanged: (_StackVolumeMetric? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _volumenMetric = value;
                    _volumenSort = _normalizeVolumeSort(
                      _volumenSort,
                      metric: _volumenMetric,
                    );
                    _volumenTopN = _normalizeVolumeTop(
                      _volumenTopN,
                      metric: _volumenMetric,
                    );
                  });
                },
              ),
          ],
        ),
        if (badges.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: badges
                .map((_VolumeBadgeData badge) => _buildVolumeBadge(badge))
                .toList(),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(child: chart),
      ],
    );
  }

  List<_VolumeBadgeData> _buildVolumeBadges(
    List<VolumenPreguntasModel> visible, {
    _StackVolumeMetric? metric,
  }) {
    if (visible.isEmpty) {
      return const <_VolumeBadgeData>[];
    }

    final _StackVolumeMetric effectiveMetric =
        metric ?? _normalizeVolumeMetric(_volumenMetric);
    final List<_VolumeBadgeData> badges = <_VolumeBadgeData>[];
    switch (effectiveMetric) {
      case _StackVolumeMetric.preguntas:
        final VolumenPreguntasModel leader = visible.reduce(
          (VolumenPreguntasModel current, VolumenPreguntasModel next) =>
              current.preguntas >= next.preguntas ? current : next,
        );
        badges.add(
          _VolumeBadgeData(
            label:
                'L\u00EDder: ${_formatTech(leader.lenguaje)} (${_formatInt(leader.preguntas)})',
            color: const Color(0xFF1D4ED8),
          ),
        );
        return badges;
      case _StackVolumeMetric.participacion:
        final VolumenPreguntasModel leader = visible.reduce(
          (VolumenPreguntasModel current, VolumenPreguntasModel next) =>
              current.sharePct >= next.sharePct ? current : next,
        );
        badges.add(
          _VolumeBadgeData(
            label:
                'Mayor participaci\u00F3n: ${_formatTech(leader.lenguaje)} '
                '(${leader.sharePct.toStringAsFixed(1)}%)',
            color: const Color(0xFF1D4ED8),
          ),
        );
        return badges;
      case _StackVolumeMetric.variacion:
        break;
    }

    final Iterable<VolumenPreguntasModel> comparable = visible.where(
      _hasComparableVolumeVariation,
    );
    final Iterable<VolumenPreguntasModel> positive = comparable.where(
      (VolumenPreguntasModel item) => item.deltaPreguntas > 0,
    );
    final Iterable<VolumenPreguntasModel> negative = comparable.where(
      (VolumenPreguntasModel item) => item.deltaPreguntas < 0,
    );

    if (positive.isNotEmpty) {
      final VolumenPreguntasModel winner = positive.reduce(
        (VolumenPreguntasModel current, VolumenPreguntasModel next) =>
            current.deltaPreguntas >= next.deltaPreguntas ? current : next,
      );
      badges.add(
        _VolumeBadgeData(
          label:
              'Mayor crecimiento: ${_formatTech(winner.lenguaje)} '
              '(${_formatSignedInt(winner.deltaPreguntas)})',
          color: const Color(0xFF059669),
        ),
      );
    }

    if (negative.isNotEmpty) {
      final VolumenPreguntasModel drop = negative.reduce(
        (VolumenPreguntasModel current, VolumenPreguntasModel next) =>
            current.deltaPreguntas <= next.deltaPreguntas ? current : next,
      );
      badges.add(
        _VolumeBadgeData(
          label:
              'Mayor ca\u00EDda: ${_formatTech(drop.lenguaje)} '
              '(${_formatSignedInt(drop.deltaPreguntas)})',
          color: const Color(0xFFDC2626),
        ),
      );
    }

    return badges;
  }

  Widget _buildVolumeBadge(_VolumeBadgeData badge) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: badge.color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badge.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                badge.label,
                softWrap: true,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: badge.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _volumeCurrentColor(int index) {
    if (index == 0) {
      return _soOrange;
    }
    return _soOrange.withValues(alpha: 0.82);
  }

  Color _volumeVariationColor(int delta) {
    if (delta > 0) {
      return const Color(0xFF059669);
    }
    if (delta < 0) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFF64748B);
  }

  List<_AcceptanceBadgeData> _buildAcceptanceBadges(
    List<TasaAceptacionModel> visible, {
    required _StackAcceptanceMetric metric,
    required _StackAcceptanceSort sort,
  }) {
    if (visible.isEmpty) {
      return const <_AcceptanceBadgeData>[];
    }
    switch (metric) {
      case _StackAcceptanceMetric.tasaAceptacion:
        final TasaAceptacionModel rateFocus = switch (sort) {
          _StackAcceptanceSort.tasaAsc => visible.reduce(
            (current, next) => current.tasaPct <= next.tasaPct ? current : next,
          ),
          _ => visible.reduce(
            (current, next) => current.tasaPct >= next.tasaPct ? current : next,
          ),
        };
        final bool isLowerRate = sort == _StackAcceptanceSort.tasaAsc;
        return <_AcceptanceBadgeData>[
          _AcceptanceBadgeData(
            label:
                '${isLowerRate ? 'Menor tasa' : 'Mayor tasa'}: '
                '${_formatTech(rateFocus.tecnologia)} '
                '(${rateFocus.tasaPct.toStringAsFixed(1)}%)',
            color: isLowerRate
                ? const Color(0xFFF97316)
                : const Color(0xFF0EA5E9),
          ),
        ];
      case _StackAcceptanceMetric.variacion:
        if (sort == _StackAcceptanceSort.mejora) {
          final Iterable<TasaAceptacionModel> positive = visible.where(
            (item) => item.deltaTasaPct > 0,
          );
          if (positive.isEmpty) {
            return const <_AcceptanceBadgeData>[];
          }
          final TasaAceptacionModel bestGain = positive.reduce(
            (current, next) =>
                current.deltaTasaPct >= next.deltaTasaPct ? current : next,
          );
          return <_AcceptanceBadgeData>[
            _AcceptanceBadgeData(
              label:
                  'Mayor mejora: ${_formatTech(bestGain.tecnologia)} '
                  '(${_formatSignedPoints(bestGain.deltaTasaPct)})',
              color: const Color(0xFF059669),
            ),
          ];
        }
        final Iterable<TasaAceptacionModel> negative = visible.where(
          (item) => item.deltaTasaPct < 0,
        );
        if (negative.isEmpty) {
          return const <_AcceptanceBadgeData>[];
        }
        final TasaAceptacionModel biggestDrop = negative.reduce(
          (current, next) =>
              current.deltaTasaPct <= next.deltaTasaPct ? current : next,
        );
        return <_AcceptanceBadgeData>[
          _AcceptanceBadgeData(
            label:
                'Mayor ca\u00EDda: ${_formatTech(biggestDrop.tecnologia)} '
                '(${_formatSignedPoints(biggestDrop.deltaTasaPct)})',
            color: const Color(0xFFDC2626),
          ),
        ];
    }
  }

  Widget _buildAcceptanceBadge(_AcceptanceBadgeData badge) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: badge.color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badge.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                badge.label,
                softWrap: true,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: badge.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAcceptanceChart() {
    if (aceptacionData.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }
    final _StackAcceptanceMetric metric = _effectiveAcceptanceMetric();
    final _StackAcceptanceSort sort = _effectiveAcceptanceSort();
    final List<TasaAceptacionModel> data = _visibleAceptacionData();
    final List<_AcceptanceBadgeData> badges = _buildAcceptanceBadges(
      data,
      metric: metric,
      sort: sort,
    );
    final double maxDeltaRate = data.isEmpty
        ? 1
        : data.map((item) => item.deltaTasaPct.abs()).reduce(math.max);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            ChartInlineFilter<_StackAcceptanceMetric>(
              key: const ValueKey<String>('so-acceptance-metric-filter'),
              label: 'M\u00E9trica',
              value: metric,
              selectedLabel: _acceptanceMetricLabel(metric),
              items: _buildAcceptanceMetricMenuItems(),
              onChanged: (_StackAcceptanceMetric? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _aceptacionMetric = value;
                  _aceptacionSort = _normalizeAcceptanceSort(
                    _aceptacionSort,
                    metric: value,
                  );
                });
              },
            ),
            ChartInlineFilter<_StackAcceptanceSort>(
              key: const ValueKey<String>('so-acceptance-sort-filter'),
              label: 'Orden',
              value: sort,
              selectedLabel: _acceptanceSortLabel(sort),
              items: _buildAcceptanceSortMenuItems(),
              onChanged: (_StackAcceptanceSort? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _aceptacionSort = value;
                });
              },
            ),
          ],
        ),
        if (badges.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: badges.map(_buildAcceptanceBadge).toList(),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: data.isEmpty
              ? Center(
                  child: Text(
                    metric == _StackAcceptanceMetric.variacion
                        ? 'No hay variaciones comparables disponibles'
                        : 'No hay datos disponibles',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kMutedColor,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    children: data.asMap().entries.map((entry) {
                      final TasaAceptacionModel item = entry.value;
                      final bool isLast = entry.key == data.length - 1;
                      final EdgeInsets padding = EdgeInsets.only(
                        bottom: isLast ? 0 : 12,
                      );
                      return Padding(
                        padding: padding,
                        child: switch (metric) {
                          _StackAcceptanceMetric.tasaAceptacion =>
                            _buildAcceptanceRateRow(item),
                          _StackAcceptanceMetric.variacion =>
                            _buildAcceptanceVariationRow(
                              item,
                              maxDeltaRate: maxDeltaRate,
                            ),
                        },
                      );
                    }).toList(),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildAcceptanceRateRow(TasaAceptacionModel item) {
    final double rate = item.tasaPct.clamp(0, 100).toDouble();
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _formatTech(item.tecnologia),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kBodyColor,
                  ),
                ),
              ),
              _buildSamplePill(item),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Stack(
              children: <Widget>[
                Container(height: 14, color: const Color(0xFFE2E8F0)),
                FractionallySizedBox(
                  widthFactor: rate / 100,
                  child: Container(height: 14, color: const Color(0xFF10B981)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tasa de aceptaci\u00F3n: ${rate.toStringAsFixed(1)}% \u00B7 '
            '${_formatInt(item.respuestasAceptadas)} aceptadas',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kMutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAcceptanceVariationRow(
    TasaAceptacionModel item, {
    required double maxDeltaRate,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  _formatTech(item.tecnologia),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kBodyColor,
                  ),
                ),
              ),
              _buildSamplePill(item),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 18,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double half = constraints.maxWidth / 2;
                final double width = maxDeltaRate <= 0
                    ? 0
                    : half * (item.deltaTasaPct.abs() / maxDeltaRate);
                return Stack(
                  children: <Widget>[
                    Container(
                      height: 18,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Align(
                      alignment: Alignment.center,
                      child: Container(
                        width: 1,
                        height: 18,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                    if (item.deltaTasaPct > 0)
                      Positioned(
                        left: half,
                        width: width.clamp(0.0, half),
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    if (item.deltaTasaPct < 0)
                      Positioned(
                        right: half,
                        width: width.clamp(0.0, half),
                        child: Container(
                          height: 18,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Actual: ${item.tasaPct.toStringAsFixed(1)}% \u00B7 '
            'Previa: ${item.tasaAceptacionPrevPct.toStringAsFixed(1)}% \u00B7 '
            'Variaci\u00F3n: ${_formatSignedPoints(item.deltaTasaPct)}',
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: kMutedColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSamplePill(TasaAceptacionModel item) {
    final Color color = _acceptanceSampleBucketColor(item.sampleBucket);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${_sampleBucketLabel(item.sampleBucket)} \u00B7 ${_formatInt(item.totalPreguntas)} preguntas',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Color _acceptanceSampleBucketColor(String? bucket) {
    switch (bucket) {
      case 'alta':
        return const Color(0xFF059669);
      case 'media':
        return const Color(0xFF2563EB);
      case 'baja':
      default:
        return const Color(0xFFD97706);
    }
  }

  String _sampleBucketLabel(String? bucket) {
    switch (bucket) {
      case 'alta':
        return 'Muestra alta';
      case 'media':
        return 'Muestra media';
      case 'baja':
      default:
        return 'Muestra baja';
    }
  }

  Widget _buildTrendChart() {
    final StackOverflowTrendsHistoryModel trends = _effectiveTrendsHistory();
    if (trends.series.isEmpty || trends.months.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }
    final List<_TrendVisualSeries> allSeries = _trendVisualSeries(trends);
    if (allSeries.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }
    final _StackTrendTop effectiveTop = _normalizeTrendTop(allSeries.length);
    final List<DropdownMenuItem<_StackTrendTop>> topItems =
        _buildTrendTopMenuItems(allSeries.length);
    final List<_TrendVisualSeries> visibleSeries =
        effectiveTop == _StackTrendTop.top3 && allSeries.length > 3
        ? allSeries.take(3).toList(growable: false)
        : allSeries;
    final List<_TrendBadgeData> badges = _buildTrendBadges(visibleSeries);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            ChartInlineFilter<_StackTrendView>(
              key: const ValueKey<String>('so-trend-view-filter'),
              label: 'Vista',
              value: _trendView,
              selectedLabel: _trendViewLabel(_trendView),
              items: _buildTrendViewMenuItems(),
              onChanged: (_StackTrendView? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _trendView = value;
                });
              },
            ),
            if (topItems.length > 1)
              ChartInlineFilter<_StackTrendTop>(
                key: const ValueKey<String>('so-trend-top-filter'),
                label: 'Top',
                value: effectiveTop,
                selectedLabel: _trendTopLabel(effectiveTop),
                items: topItems,
                onChanged: (_StackTrendTop? value) {
                  if (value == null) {
                    return;
                  }
                  setState(() {
                    _trendTop = value;
                  });
                },
              ),
          ],
        ),
        if (badges.isNotEmpty) ...<Widget>[
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: badges.map(_buildTrendBadge).toList(),
          ),
        ],
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: visibleSeries.map(_buildTrendLegendChip).toList(),
        ),
        const SizedBox(height: 12),
        _buildTrendCurrentValuesSummary(visibleSeries),
        const SizedBox(height: 16),
        Expanded(
          child: _buildTrendLineChart(
            visibleSeries: visibleSeries,
            months: trends.months,
          ),
        ),
      ],
    );
  }

  Widget _buildTrendLineChart({
    required List<_TrendVisualSeries> visibleSeries,
    required List<String> months,
  }) {
    final double minY = _trendMinY(visibleSeries);
    final double maxY = _trendMaxY(visibleSeries);
    final double interval = _trendYAxisStep(maxY: maxY, minY: minY);
    final double roundedMaxY = ((maxY + interval) / interval).ceil() * interval;

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (months.length - 1).toDouble(),
        minY: minY,
        maxY: roundedMaxY,
        clipData: const FlClipData.all(),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              const FlLine(color: Color(0xFFE2E8F0), strokeWidth: 1),
        ),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            left: BorderSide(color: Color(0xFF94A3B8), width: 1),
            bottom: BorderSide(color: Color(0xFF94A3B8), width: 1),
          ),
        ),
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipColor: (_) => const Color(0xFF0F172A),
            getTooltipItems: (spots) => spots.map((spot) {
              final _TrendVisualSeries series = visibleSeries[spot.barIndex];
              return LineTooltipItem(
                _buildTrendTooltipText(
                  series: series,
                  month: months[spot.x.round()],
                  index: spot.x.round(),
                ),
                const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              );
            }).toList(),
          ),
        ),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              interval: interval,
              getTitlesWidget: (value, meta) => Text(
                _formatTrendAxisValue(value),
                style: const TextStyle(fontSize: 11, color: kMutedColor),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final int idx = value.round();
                if ((value - idx).abs() > 0.05 ||
                    idx < 0 ||
                    idx >= months.length) {
                  return const SizedBox.shrink();
                }
                final bool isNarrow = MediaQuery.sizeOf(context).width < 760;
                if (isNarrow && idx.isOdd) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    _formatMonthLabel(months[idx]),
                    style: const TextStyle(fontSize: 11, color: kMutedColor),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: visibleSeries
            .map(
              (_TrendVisualSeries series) => LineChartBarData(
                spots: List<FlSpot>.generate(
                  series.values.length,
                  (int index) => FlSpot(index.toDouble(), series.values[index]),
                ),
                isCurved: false,
                color: series.color,
                barWidth: 2.8,
                dotData: const FlDotData(show: false),
              ),
            )
            .toList(),
      ),
    );
  }

  StackOverflowTrendsHistoryModel _effectiveTrendsHistory() {
    final StackOverflowTrendsHistoryModel? history = tendenciasHistory;
    if (history != null &&
        history.series.isNotEmpty &&
        history.months.isNotEmpty) {
      return history;
    }
    return StackOverflowTrendsHistoryModel.fromLegacy(tendenciasData);
  }

  List<_TrendVisualSeries> _trendVisualSeries(
    StackOverflowTrendsHistoryModel trends,
  ) {
    final List<StackOverflowTrendSeriesModel> ordered =
        _trendSignalSeries(trends);
    return ordered
        .map(
          (StackOverflowTrendSeriesModel item) => _TrendVisualSeries(
            source: item,
            tecnologia: item.tecnologia,
            normalizedKey: _normalizeTrendKey(item.tecnologia),
            color: _trendColor(item.tecnologia),
            values: _trendView == _StackTrendView.volumenMensual
                ? item.points.map((point) => point.toDouble()).toList()
                : _normalizedTrendPoints(item),
          ),
        )
        .toList();
  }

  List<StackOverflowTrendSeriesModel> _trendSignalSeries(
    StackOverflowTrendsHistoryModel trends,
  ) {
    final List<StackOverflowTrendSeriesModel> ordered =
        List<StackOverflowTrendSeriesModel>.from(trends.series)
          ..sort((a, b) => a.latestRank.compareTo(b.latestRank));
    return ordered
        .where(
          (StackOverflowTrendSeriesModel item) => item.points.any(
            (int value) => value > 0,
          ),
        )
        .toList();
  }

  Widget _buildTrendLegendChip(_TrendVisualSeries series) {
    return Chip(
      key: ValueKey<String>('trend-series-chip-${series.normalizedKey}'),
      side: BorderSide(color: series.color.withValues(alpha: 0.28)),
      backgroundColor: const Color(0xFFF8FAFC),
      avatar: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: series.color, shape: BoxShape.circle),
      ),
      label: Text(
        _formatTech(series.tecnologia),
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: series.color,
        ),
      ),
    );
  }

  List<_TrendBadgeData> _buildTrendBadges(
    List<_TrendVisualSeries> visibleSeries,
  ) {
    final List<_TrendBadgeData> badges = <_TrendBadgeData>[];
    if (visibleSeries.isEmpty) {
      return badges;
    }
    _TrendVisualSeries? maxBy(
      double Function(_TrendVisualSeries series) selector,
    ) {
      _TrendVisualSeries current = visibleSeries.first;
      double currentValue = selector(current);
      for (final _TrendVisualSeries series in visibleSeries.skip(1)) {
        final double candidate = selector(series);
        if (candidate > currentValue) {
          current = series;
          currentValue = candidate;
        }
      }
      return current;
    }

    _TrendVisualSeries? minBy(
      double Function(_TrendVisualSeries series) selector,
    ) {
      _TrendVisualSeries current = visibleSeries.first;
      double currentValue = selector(current);
      for (final _TrendVisualSeries series in visibleSeries.skip(1)) {
        final double candidate = selector(series);
        if (candidate < currentValue) {
          current = series;
          currentValue = candidate;
        }
      }
      return current;
    }

    if (_trendView == _StackTrendView.volumenMensual) {
      final _TrendVisualSeries? currentLeader = maxBy(
        (_TrendVisualSeries series) => series.source.endValue.toDouble(),
      );
      final _TrendVisualSeries? largestAbsoluteDrop = minBy(
        (_TrendVisualSeries series) => series.source.absDelta.toDouble(),
      );
      if (currentLeader != null) {
        badges.add(
          _TrendBadgeData(
            label:
                'L\u00EDder actual: ${_formatTech(currentLeader.tecnologia)} '
                '(${_formatInt(currentLeader.source.endValue)})',
            color: currentLeader.color,
          ),
        );
      }
      if (largestAbsoluteDrop != null) {
        badges.add(
          _TrendBadgeData(
            label:
                'Mayor ca\u00EDda absoluta: '
                '${_formatTech(largestAbsoluteDrop.tecnologia)} '
                '(${_formatSignedInt(largestAbsoluteDrop.source.absDelta)})',
            color: largestAbsoluteDrop.color,
          ),
        );
      }
      return badges;
    }
    final _TrendVisualSeries? bestRetention = maxBy(
      (_TrendVisualSeries series) => series.source.retentionPct,
    );
    final _TrendVisualSeries? largestRelativeDrop = minBy(
      (_TrendVisualSeries series) => series.source.pctDelta,
    );
    if (bestRetention != null) {
      badges.add(
        _TrendBadgeData(
          label:
              'Mejor retenci\u00F3n: ${_formatTech(bestRetention.tecnologia)} '
              '(${bestRetention.source.retentionPct.toStringAsFixed(1)}%)',
          color: bestRetention.color,
        ),
      );
    }
    if (largestRelativeDrop != null) {
      badges.add(
        _TrendBadgeData(
          label:
              'Mayor ca\u00EDda relativa: '
              '${_formatTech(largestRelativeDrop.tecnologia)} '
              '(${_formatSignedPercent(largestRelativeDrop.source.pctDelta)})',
          color: largestRelativeDrop.color,
        ),
      );
    }
    return badges;
  }

  Widget _buildTrendBadge(_TrendBadgeData badge) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: badge.color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: badge.color.withValues(alpha: 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: badge.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                badge.label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: badge.color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _normalizedTrendPoints(StackOverflowTrendSeriesModel series) {
    if (series.startValue <= 0) {
      return List<double>.filled(series.points.length, 0);
    }
    return series.points
        .map((int point) => (point / series.startValue) * 100)
        .toList();
  }

  double _trendMinY(List<_TrendVisualSeries> series) {
    if (_trendView == _StackTrendView.indiceBase100) {
      final double minValue = series
          .expand((item) => item.values)
          .fold<double>(100, math.min);
      return math.max(0, (minValue - 10).floorToDouble());
    }
    return 0;
  }

  double _trendMaxY(List<_TrendVisualSeries> series) {
    final double maxValue = series
        .expand((item) => item.values)
        .fold<double>(0, math.max);
    if (_trendView == _StackTrendView.indiceBase100) {
      return maxValue + 10;
    }
    return maxValue * 1.18;
  }

  double _trendYAxisStep({required double maxY, required double minY}) {
    final double span = math.max(1, maxY - minY);
    return _trendView == _StackTrendView.indiceBase100
        ? _computePercentYAxisStep(span / 5)
        : _computeYAxisStep(span);
  }

  String _formatTrendAxisValue(double value) {
    if (_trendView == _StackTrendView.indiceBase100) {
      return value.toStringAsFixed(0);
    }
    if (value <= 0) {
      return '0';
    }
    return _formatCompactAxisValue(value);
  }

  String _buildTrendTooltipText({
    required _TrendVisualSeries series,
    required String month,
    required int index,
  }) {
    final StringBuffer buffer = StringBuffer(_formatTech(series.tecnologia));
    buffer.write('\n${_formatMonthWithYear(month)}');
    if (_trendView == _StackTrendView.volumenMensual) {
      final int value = index < series.source.points.length
          ? series.source.points[index]
          : 0;
      buffer.write('\nValor: ${_formatInt(value)}');
      return buffer.toString();
    }
    final double normalized = index < series.values.length
        ? series.values[index]
        : 0;
    buffer.write('\n\u00CDndice: ${normalized.toStringAsFixed(1)}');
    return buffer.toString();
  }

  Widget _buildTrendCurrentValuesSummary(
    List<_TrendVisualSeries> visibleSeries,
  ) {
    final List<_TrendVisualSeries> ordered = List<_TrendVisualSeries>.from(
      visibleSeries,
    )..sort((a, b) => b.values.last.compareTo(a.values.last));

    return Align(
      alignment: Alignment.centerRight,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Wrap(
          alignment: WrapAlignment.end,
          spacing: 8,
          runSpacing: 8,
          children: ordered.map(_buildTrendCurrentValueChip).toList(),
        ),
      ),
    );
  }

  Widget _buildTrendCurrentValueChip(_TrendVisualSeries series) {
    final String suffix = _trendView == _StackTrendView.volumenMensual
        ? _formatInt(series.source.endValue)
        : series.values.last.toStringAsFixed(1);
    return Container(
      key: ValueKey<String>('trend-current-value-${series.normalizedKey}'),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: series.color.withValues(alpha: 0.28)),
      ),
      child: Text(
        '${_formatTech(series.tecnologia)} \u00B7 $suffix',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: series.color,
        ),
      ),
    );
  }

  TasaAceptacionModel? _findBestAcceptance() {
    if (aceptacionData.isEmpty) {
      return null;
    }
    return aceptacionData.reduce(
      (current, next) => current.tasaPct >= next.tasaPct ? current : next,
    );
  }

  Map<String, Object?> _buildTrendInsight() {
    final StackOverflowTrendsHistoryModel trends = _effectiveTrendsHistory();
    final List<StackOverflowTrendSeriesModel> signalSeries =
        _trendSignalSeries(trends);

    StackOverflowTrendSeriesModel? maxBy(
      Iterable<StackOverflowTrendSeriesModel> items,
      double Function(StackOverflowTrendSeriesModel item) selector,
    ) {
      StackOverflowTrendSeriesModel? current;
      double currentValue = double.negativeInfinity;
      for (final StackOverflowTrendSeriesModel item in items) {
        final double value = selector(item);
        if (current == null || value > currentValue) {
          current = item;
          currentValue = value;
        }
      }
      return current;
    }

    StackOverflowTrendSeriesModel? minBy(
      Iterable<StackOverflowTrendSeriesModel> items,
      double Function(StackOverflowTrendSeriesModel item) selector,
    ) {
      StackOverflowTrendSeriesModel? current;
      double currentValue = double.infinity;
      for (final StackOverflowTrendSeriesModel item in items) {
        final double value = selector(item);
        if (current == null || value < currentValue) {
          current = item;
          currentValue = value;
        }
      }
      return current;
    }

    if (signalSeries.isNotEmpty) {
      final StackOverflowTrendSeriesModel? largestRelativeDrop = minBy(
        signalSeries.where((item) => item.pctDelta < 0),
        (item) => item.pctDelta,
      );
      if (largestRelativeDrop != null) {
        return <String, Object?>{
          'title':
              '${_formatTech(largestRelativeDrop.tecnologia)} registra la caída relativa más pronunciada',
          'description':
              'De ${_formatInt(largestRelativeDrop.startValue)} a '
              '${_formatInt(largestRelativeDrop.endValue)} preguntas mensuales, '
              'mayor caída relativa.',
          'icon': Icons.trending_down_rounded,
          'color': const Color(0xFFDC2626),
          'tech': largestRelativeDrop.tecnologia,
        };
      }

      final StackOverflowTrendSeriesModel? bestRetention = maxBy(
        signalSeries,
        (item) => item.retentionPct,
      );
      if (bestRetention != null && bestRetention.retentionPct > 0) {
        return <String, Object?>{
          'title':
              '${_formatTech(bestRetention.tecnologia)} conserva mejor su tracción mensual',
          'description':
              'Retiene ${bestRetention.retentionPct.toStringAsFixed(1)}% del volumen, '
              'de ${_formatInt(bestRetention.startValue)} a '
              '${_formatInt(bestRetention.endValue)} preguntas mensuales.',
          'icon': Icons.trending_flat_rounded,
          'color': const Color(0xFF2563EB),
          'tech': bestRetention.tecnologia,
        };
      }

      final StackOverflowTrendSeriesModel? currentLeader = maxBy(
        signalSeries,
        (item) => item.endValue.toDouble(),
      );
      if (currentLeader != null) {
        return <String, Object?>{
          'title':
              '${_formatTech(currentLeader.tecnologia)} mantiene el liderazgo mensual',
          'description':
              'Cierra con ${_formatInt(currentLeader.endValue)} preguntas mensuales, '
              'el mayor volumen del corte.',
          'icon': Icons.show_chart_rounded,
          'color': const Color(0xFF2563EB),
          'tech': currentLeader.tecnologia,
        };
      }
    }

    if (tendenciasData.length < 2) {
      return <String, Object?>{
        'title': 'Seguimiento del volumen mensual',
        'description': 'Se requiere más histórico para identificar tendencia.',
        'icon': Icons.show_chart_rounded,
        'color': const Color(0xFF2563EB),
        'tech': null,
      };
    }
    return <String, Object?>{
      'title': 'Actividad estable en el período',
      'description': 'Sin señal dominante en la trayectoria mensual.',
      'icon': Icons.trending_flat_rounded,
      'color': const Color(0xFF475569),
      'tech': null,
    };
  }

  String? _resolveFrameworkLogo(String tech) {
    final String normalized = tech.toLowerCase().trim();
    if (normalized.contains('react')) {
      return 'assets/images/React-logo.png';
    }
    if (normalized.contains('vue')) {
      return 'assets/images/Vue-logo.png';
    }
    if (normalized.contains('typescript')) {
      return 'assets/images/TypeScript-logo.png';
    }
    if (normalized.contains('javascript')) {
      return 'assets/images/JavaScript-logo.png';
    }
    if (normalized.contains('svelte')) {
      return 'assets/images/svelte-logo.png';
    }
    if (normalized.contains('angular')) {
      return 'assets/images/angular_logo.png';
    }
    if (normalized.contains('next')) {
      return 'assets/images/nextjs-logo.png';
    }
    if (normalized.contains('django')) {
      return 'assets/images/django-logo.png';
    }
    if (normalized.contains('python')) {
      return 'assets/images/python_logo.png';
    }
    if (normalized.contains('java') && !normalized.contains('javascript')) {
      return 'assets/images/Java-logo.png';
    }
    if (normalized.contains('c#') || normalized.contains('csharp')) {
      return 'assets/images/csharp-logo.png';
    }
    if (normalized.contains('c++') || normalized.contains('cpp')) {
      return 'assets/images/cpp-logo.png';
    }
    if (normalized.contains('spring')) {
      return 'assets/images/Spring-logo.png';
    }
    if (normalized.contains('laravel')) {
      return 'assets/images/Laravel-logo.png';
    }
    if (normalized.contains('fastapi')) {
      return 'assets/images/FastAPI-logo.png';
    }
    if (normalized.contains('kotlin')) {
      return 'assets/images/Kotlin-logo.png';
    }
    if (normalized.contains('php')) {
      return 'assets/images/PHP-logo.png';
    }
    if (normalized.contains('rust')) {
      return 'assets/images/Rust-logo.png';
    }
    if (normalized.contains('go')) {
      return 'assets/images/Go-logo.png';
    }
    return null;
  }

  IconData _resolveFrameworkFallbackIcon(String tech) {
    final String normalized = tech.toLowerCase().trim();
    if (normalized.contains('ai') ||
        normalized.contains('ml') ||
        normalized.contains('machine') ||
        normalized.contains('llm')) {
      return Icons.auto_awesome_rounded;
    }
    if (normalized.contains('security')) return Icons.shield_rounded;
    if (normalized.contains('performance')) return Icons.speed_rounded;
    if (normalized.contains('devops')) return Icons.settings_rounded;
    if (normalized.contains('testing')) return Icons.fact_check_rounded;
    if (normalized.contains('cloud')) return Icons.cloud_rounded;
    if (normalized.contains('web3') || normalized.contains('blockchain')) {
      return Icons.link_rounded;
    }
    if (normalized.contains('microservice')) return Icons.device_hub_rounded;
    if (normalized.contains('angular')) {
      return Icons.webhook_rounded;
    }
    if (normalized.contains('react') || normalized.contains('vue')) {
      return Icons.developer_mode_rounded;
    }
    if (normalized.contains('python')) {
      return Icons.code_rounded;
    }
    return Icons.extension_rounded;
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
      'java': 'Java',
      'go': 'Go',
      'c#': 'C#',
      'csharp': 'C#',
      'c++': 'C++',
      'cpp': 'C++',
      'php': 'PHP',
      'ruby': 'Ruby',
      'kotlin': 'Kotlin',
    };
    return names[raw.toLowerCase()] ?? raw;
  }

  String _csvField(Object? value) {
    final String text = value?.toString() ?? '';
    if (text.contains(',') || text.contains('"') || text.contains('\n')) {
      final String escaped = text.replaceAll('"', '""');
      return '"$escaped"';
    }
    return text;
  }

  String _formatCsvDouble(double value) {
    return value.toStringAsFixed(2);
  }

  String _formatInt(int value) {
    final String valueText = value.abs().toString();
    final RegExp pattern = RegExp(r'\B(?=(\d{3})+(?!\d))');
    final String formatted = valueText.replaceAllMapped(
      pattern,
      (match) => ',',
    );
    return value.isNegative ? '-$formatted' : formatted;
  }

  String _formatSignedInt(int value) {
    if (value > 0) {
      return '+${_formatInt(value)}';
    }
    return _formatInt(value);
  }

  String _formatSignedPercent(double value) {
    final String fixed = value.toStringAsFixed(1);
    if (value > 0) {
      return '+$fixed%';
    }
    return '$fixed%';
  }

  String _formatSignedPoints(double value) {
    final String fixed = value.toStringAsFixed(2);
    if (value > 0) {
      return '+$fixed pts';
    }
    return '$fixed pts';
  }

  String _formatMonthLabel(String raw) {
    final String clean = raw.trim();
    try {
      DateTime parsed;
      final RegExp yearMonth = RegExp(r'^\d{4}-\d{2}$');
      if (yearMonth.hasMatch(clean)) {
        parsed = DateTime.parse('$clean-01');
      } else {
        parsed = DateTime.parse(clean);
      }
      const List<String> shortMonths = <String>[
        'Ene',
        'Feb',
        'Mar',
        'Abr',
        'May',
        'Jun',
        'Jul',
        'Ago',
        'Sep',
        'Oct',
        'Nov',
        'Dic',
      ];
      return shortMonths[parsed.month - 1];
    } catch (_) {
      if (clean.length >= 7) {
        return clean.substring(5, 7);
      }
      return clean;
    }
  }

  String _formatMonthWithYear(String raw) {
    final String clean = raw.trim();
    try {
      DateTime parsed;
      final RegExp yearMonth = RegExp(r'^\d{4}-\d{2}$');
      if (yearMonth.hasMatch(clean)) {
        parsed = DateTime.parse('$clean-01');
      } else {
        parsed = DateTime.parse(clean);
      }
      const List<String> shortMonths = <String>[
        'ene',
        'feb',
        'mar',
        'abr',
        'may',
        'jun',
        'jul',
        'ago',
        'sep',
        'oct',
        'nov',
        'dic',
      ];
      return '${shortMonths[parsed.month - 1]} ${parsed.year}';
    } catch (_) {
      return clean;
    }
  }

  String _normalizeTrendKey(String raw) {
    return raw
        .toLowerCase()
        .replaceAll('c++', 'c-plus-plus')
        .replaceAll('c#', 'c-sharp')
        .replaceAll('+', '-plus-')
        .replaceAll('#', '-sharp-')
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
  }

  Color _trendColor(String tecnologia) {
    switch (tecnologia.toLowerCase()) {
      case 'python':
        return const Color(0xFF2563EB);
      case 'javascript':
        return const Color(0xFFEAB308);
      case 'typescript':
        return const Color(0xFF60A5FA);
      default:
        const List<Color> palette = <Color>[
          Color(0xFF10B981),
          Color(0xFFF97316),
          Color(0xFF8B5CF6),
          Color(0xFFEC4899),
          Color(0xFF14B8A6),
        ];
        final int hash = tecnologia.codeUnits.fold<int>(
          0,
          (int total, int unit) => total + unit,
        );
        return palette[hash % palette.length];
    }
  }

  double _computeYAxisStep(double maxY) {
    if (maxY <= 0) {
      return 200;
    }
    final List<double> candidates = <double>[
      100,
      200,
      250,
      500,
      1000,
      2000,
      2500,
      5000,
      10000,
    ];
    for (final double candidate in candidates) {
      if ((maxY / candidate) <= 6) {
        return candidate;
      }
    }
    return 10000;
  }

  double _computePercentYAxisStep(double maxY) {
    if (maxY <= 0) {
      return 5;
    }
    final List<double> candidates = <double>[1, 2, 5, 10, 20, 25];
    for (final double candidate in candidates) {
      if ((maxY / candidate) <= 6) {
        return candidate;
      }
    }
    return 25;
  }

  String _formatCompactAxisValue(double value) {
    if (value >= 1000) {
      final double scaled = value / 1000;
      final String compact = (scaled % 1 == 0)
          ? scaled.toStringAsFixed(0)
          : scaled.toStringAsFixed(1);
      return '${compact}k';
    }
    return value.toStringAsFixed(0);
  }

  String _formatCompactSignedAxisValue(double value) {
    if (value == 0) {
      return '0';
    }
    final String prefix = value < 0 ? '-' : '';
    return '$prefix${_formatCompactAxisValue(value.abs())}';
  }

  String _formatPercentAxisValue(double value) {
    final double safe = value.abs();
    final String number = safe >= 10 || safe == safe.roundToDouble()
        ? safe.toStringAsFixed(0)
        : safe.toStringAsFixed(1);
    final String prefix = value < 0 ? '-' : '';
    return '$prefix$number%';
  }

  String _formatVolumeAxisValue(
    double value, {
    required _StackVolumeMetric metric,
  }) {
    switch (metric) {
      case _StackVolumeMetric.preguntas:
        return _formatCompactAxisValue(value);
      case _StackVolumeMetric.participacion:
        return _formatPercentAxisValue(value);
      case _StackVolumeMetric.variacion:
        return _formatCompactSignedAxisValue(value);
    }
  }

  String _buildVolumeTooltipText(
    VolumenPreguntasModel item, {
    required _StackVolumeMetric metric,
  }) {
    final StringBuffer buffer = StringBuffer(_formatTech(item.lenguaje));
    switch (metric) {
      case _StackVolumeMetric.preguntas:
        buffer.write('\nPreguntas nuevas: ${_formatInt(item.preguntas)}');
      case _StackVolumeMetric.participacion:
        buffer.write(
          '\n% participaci\u00F3n: ${item.sharePct.toStringAsFixed(1)}%',
        );
      case _StackVolumeMetric.variacion:
        buffer.write(
          '\nVariaci\u00F3n: ${_formatSignedInt(item.deltaPreguntas)}',
        );
        buffer.write(
          '\n% de variaci\u00F3n: ${_formatSignedPercent(item.growthPct)}',
        );
    }
    return buffer.toString();
  }
}

class _InsightCardData {
  final String? iconAsset;
  final IconData? iconData;
  final Color iconColor;
  final String title;
  final String description;

  const _InsightCardData({
    required this.iconColor,
    required this.title,
    required this.description,
    this.iconAsset,
    this.iconData,
  });
}

class _InsightCard extends StatelessWidget {
  final _InsightCardData card;

  const _InsightCard({required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: card.iconColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: card.iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: card.iconAsset != null
                ? Padding(
                    padding: const EdgeInsets.all(6),
                    child: Image.asset(card.iconAsset!, fit: BoxFit.contain),
                  )
                : Icon(
                    card.iconData ?? Icons.extension_rounded,
                    color: card.iconColor,
                    size: 28,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  card.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: card.iconColor,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  card.description,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: kBodyColor,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
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
}

class _VolumeBadgeData {
  final String label;
  final Color color;

  const _VolumeBadgeData({required this.label, required this.color});
}

class _AcceptanceBadgeData {
  final String label;
  final Color color;

  const _AcceptanceBadgeData({required this.label, required this.color});
}

class _TrendBadgeData {
  final String label;
  final Color color;

  const _TrendBadgeData({required this.label, required this.color});
}

class _TrendVisualSeries {
  final StackOverflowTrendSeriesModel source;
  final String tecnologia;
  final String normalizedKey;
  final Color color;
  final List<double> values;

  const _TrendVisualSeries({
    required this.source,
    required this.tecnologia,
    required this.normalizedKey,
    required this.color,
    required this.values,
  });
}

enum _StackVolumeSort { preguntas, participacion, crecimiento, caida }

enum _StackVolumeMetric { preguntas, participacion, variacion }

enum _StackAcceptanceMetric { tasaAceptacion, variacion }

enum _StackAcceptanceSort { tasaDesc, tasaAsc, mejora, caida }

enum _StackTrendView { volumenMensual, indiceBase100 }

enum _StackTrendTop { top3, todas }
