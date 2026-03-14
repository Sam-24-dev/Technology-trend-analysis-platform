import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:convert';
import 'dart:math';
import 'package:archive/archive.dart';
import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/github_models.dart';
import '../models/run_manifest_models.dart';
import '../providers/app_providers.dart';
import '../services/download/download_service.dart';
import '../widgets/chart_card.dart';
import '../widgets/chart_legend.dart';
import '../widgets/chart_inline_filter.dart';
import '../widgets/degraded_state_card.dart';
import '../widgets/loading_skeleton.dart';

class GithubDashboard extends ConsumerStatefulWidget {
  const GithubDashboard({super.key, this.downloadService});

  final DownloadService? downloadService;

  @override
  ConsumerState<GithubDashboard> createState() => _GithubDashboardState();
}

class _GithubDashboardState extends ConsumerState<GithubDashboard> {
  late final DownloadService _downloadService;
  List<LenguajeModel> lenguajes = [];
  GithubLanguagePublicModel? lenguajesPublic;
  List<FrameworkCommitModel> frameworks = [];
  GithubFrameworkHistoryModel? frameworksHistory;
  GithubCorrelationHistoryModel? correlationHistory;
  List<CorrelacionModel> correlacion = [];
  bool isLoading = true;
  bool isDegraded = false;
  String? degradedMessage;
  int _lenguajesTopN = 10;
  _GithubLenguajesSort _lenguajesSort = _GithubLenguajesSort.repos;
  int _frameworkTopN = 0;
  _GithubFrameworkMetric _frameworkMetric = _GithubFrameworkMetric.commits;
  _GithubFrameworkView _frameworkView = _GithubFrameworkView.current;
  _GithubFrameworkOrder _frameworkOrder = _GithubFrameworkOrder.highest;
  _GithubScatterFocus _scatterFocus = _GithubScatterFocus.all;
  _GithubScatterDetailMode _scatterDetailMode = _GithubScatterDetailMode.basic;
  String? _scatterSelectedRepoName;
  List<String> _scatterCollisionRepoNames = const <String>[];

  // Colores distintivos para cada lenguaje (todos diferentes)
  final List<Color> distinctColors = [
    const Color(0xFF3776AB), // Python - azul oficial
    const Color(0xFF2D79C7), // TypeScript - azul diferente
    const Color(0xFF10B981), // LLMs/AI - verde esmeralda
    const Color(0xFFF7DF1E), // JavaScript - amarillo
    const Color(0xFF00ADD8), // Go - cyan
    const Color(0xFFDEA584), // Rust - naranja/cobre
    const Color(0xFFF37626), // Jupyter - naranja brillante
    const Color(0xFF7F52FF), // Kotlin - purpura
    const Color(0xFF00599C), // C++ - azul oscuro
    const Color(0xFF4EAA25), // Shell - verde
  ];

  @override
  void initState() {
    super.initState();
    _downloadService = widget.downloadService ?? createDownloadService();
    _loadData();
  }

  String? errorMessage;

  List<LenguajeModel> get _topLenguajes {
    final List<LenguajeModel> ordered = List<LenguajeModel>.from(lenguajes)
      ..sort((LenguajeModel a, LenguajeModel b) {
        switch (_lenguajesSort) {
          case _GithubLenguajesSort.repos:
            return b.reposCount.compareTo(a.reposCount);
          case _GithubLenguajesSort.porcentaje:
            return b.porcentaje.compareTo(a.porcentaje);
        }
      });
    return _applyTopN<LenguajeModel>(ordered, _lenguajesTopN);
  }

  Future<void> _loadData() async {
    try {
      final state = await ref.read(githubDashboardProvider.future);
      if (!mounted) return;
      final GithubDashboardData? data = state.data;
      if (state.isError || data == null) {
        setState(() {
          isLoading = false;
          errorMessage =
              state.message ?? 'No se cargaron datos. Verifique logs.';
        });
        return;
      }

      setState(() {
        lenguajes = List<LenguajeModel>.from(data.lenguajes)
          ..sort((a, b) => b.reposCount.compareTo(a.reposCount));
        lenguajesPublic = data.lenguajesPublic;
        frameworks = data.frameworks;
        frameworksHistory = data.frameworksHistory;
        correlationHistory = data.correlationHistory;
        correlacion = data.correlacion;
        _scatterSelectedRepoName = data.correlacion.isNotEmpty
            ? data.correlacion.first.repoName
            : null;
        _scatterCollisionRepoNames = const <String>[];
        isDegraded = state.isDegraded;
        degradedMessage = state.isDegraded ? state.message : null;
        errorMessage = null;
        isLoading = false;
      });
    } catch (e, stackTrace) {
      debugPrint('Error cargando datos: $e');
      setState(() {
        isLoading = false;
        errorMessage = 'Error: $e\n$stackTrace';
      });
    }
  }

  Future<void> _exportDataAsZip() async {
    final List<LenguajeModel> exportLenguajes =
        List<LenguajeModel>.from(lenguajes)
          ..sort((LenguajeModel a, LenguajeModel b) {
            final int byRepos = b.reposCount.compareTo(a.reposCount);
            if (byRepos != 0) {
              return byRepos;
            }
            return a.lenguaje.toLowerCase().compareTo(b.lenguaje.toLowerCase());
          });

    // CSV 1: Lenguajes
    String csv1 = 'lenguaje,repositorios_nuevos,participacion_pct\n';
    for (var lang in exportLenguajes) {
      csv1 += '${lang.lenguaje},${lang.reposCount},${lang.porcentaje}\n';
    }

    // CSV 2: Frameworks
    String csv2 = [
      'framework',
      'repo',
      'commits',
      'active_contributors',
      'merged_prs',
      'closed_issues',
      'releases',
      'commits_previos',
      'delta_commits',
      'growth_pct',
      'trend_direction',
      'ranking',
    ].join(',');
    csv2 += '\n';
    for (var fw in frameworks) {
      csv2 += [
        fw.framework,
        fw.repo,
        fw.commits2025.toString(),
        fw.activeContributors?.toString() ?? '',
        fw.mergedPrs?.toString() ?? '',
        fw.closedIssues?.toString() ?? '',
        fw.releasesCount?.toString() ?? '',
        fw.commitsPrev?.toString() ?? '',
        fw.deltaCommits?.toString() ?? '',
        fw.growthPct?.toStringAsFixed(2) ?? '',
        fw.trendDirection ?? '',
        fw.ranking.toString(),
      ].join(',');
      csv2 += '\n';
    }

    // CSV 3: Correlacion
    String csv3 = [
      'repo',
      'stars',
      'contributors',
      'language',
      'engagement_ratio',
      'contributors_per_1k_stars',
      'expected_contributors',
      'contributors_delta_vs_trend',
      'outlier_score',
      'trend_bucket',
      'snapshot_date_utc',
    ].join(',');
    csv3 += '\n';
    for (var item in correlacion) {
      csv3 += [
        item.repoName,
        item.stars.toString(),
        item.contributors.toString(),
        item.language,
        item.engagementRatio.toStringAsFixed(6),
        item.contributorsPer1kStars.toStringAsFixed(3),
        item.expectedContributors?.toStringAsFixed(3) ?? '',
        item.contributorsDeltaVsTrend?.toStringAsFixed(3) ?? '',
        item.outlierScore?.toStringAsFixed(6) ?? '',
        item.trendBucket ?? '',
        item.snapshotDateUtc ?? '',
      ].join(',');
      csv3 += '\n';
    }

    // Crear ZIP
    final archive = Archive();
    archive.addFile(
      ArchiveFile('1_lenguajes_nuevos.csv', csv1.length, utf8.encode(csv1)),
    );
    archive.addFile(
      ArchiveFile('2_frameworks_frontend.csv', csv2.length, utf8.encode(csv2)),
    );
    archive.addFile(
      ArchiveFile(
        '3_correlacion_stars_contributors.csv',
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
        fileName: 'github_datos_completos',
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
        final DataLoadState<RunManifestPublic>? manifestState = ref
            .watch(runManifestProvider)
            .asData
            ?.value;
        final RunManifestPublic? manifest = manifestState?.data;
        final String topLanguageName = _languageInsightAccentName;
        final String topFrameworkName = _frameworkInsightAccentName;
        final String topCorrelationName = _correlationInsightAccentName;
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
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Dashboard GitHub',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                          ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _exportDataAsZip,
                    icon: const Icon(Icons.folder_zip, size: 18),
                    label: const Text('Exportar ZIP'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                buildAnalysisPeriodLabel(manifest),
                style: TextStyle(fontSize: 16, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 4),
              Text(
                buildLastUpdatedLabel(manifest),
                style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
              ),
              if (isDegraded)
                DegradedStateCard(
                  message:
                      degradedMessage ??
                      'Modo degradado: algunos datasets no estuvieron disponibles.',
                  onRetry: _loadData,
                ),
              const SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 14,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Insights clave',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Insight 1: tecnologia lider
                    _buildGithubInsightCard(
                      _getLanguageInsightTitle(manifest),
                      _getLanguageInsightDescription(manifest),
                      _resolveInsightColor(topLanguageName),
                      imagePath: _resolveInsightLogo(topLanguageName),
                      fallbackIcon: _resolveInsightFallbackIcon(
                        topLanguageName,
                        defaultIcon: Icons.code_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Insight 2: framework lider
                    _buildGithubInsightCard(
                      _getFrameworkInsightTitle(),
                      _getFrameworkInsightDescription(),
                      _resolveInsightColor(topFrameworkName),
                      imagePath: _resolveInsightLogo(topFrameworkName),
                      fallbackIcon: _resolveInsightFallbackIcon(
                        topFrameworkName,
                        defaultIcon: Icons.webhook_rounded,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Insight 3: Correlacion
                    _buildGithubInsightCard(
                      _getCorrelationInsightTitle(),
                      _getCorrelationInsightDescription(),
                      _resolveInsightColor(topCorrelationName),
                      imagePath: null,
                      fallbackIcon: _resolveInsightFallbackIcon(
                        topCorrelationName,
                        defaultIcon: Icons.group_work_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Grafico 1
              ChartCard(
                title:
                    'Top ${_topLenguajes.length} lenguajes con m\u00e1s repositorios nuevos',
                subtitle: _lenguajesSubtitle,
                height: 520,
                chart: _buildHorizontalBarChart(),
                legend: _buildLanguageLegend(context),
                semanticLabel: _buildLanguageChartAltText(),
              ),
              const SizedBox(height: 24),

              // Grafico 2
              ChartCard(
                title: _frameworkChartTitle,
                subtitle: _frameworkChartSubtitle,
                height: 460,
                chart: _buildFrameworkPieChart(),
                legend: _buildFrameworkLegend(context),
                semanticLabel: _buildFrameworkChartAltText(),
              ),
              const SizedBox(height: 24),

              // Grafico 3
              ChartCard(
                title: 'Correlaci\u00f3n entre stars y contribuidores',
                subtitle: _scatterChartSubtitle,
                height: compact ? 1040 : 860,
                chart: _buildCorrelationExperience(),
                legend: _buildCorrelationLegend(),
                semanticLabel: _buildCorrelationChartAltText(),
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLoadingSkeleton(BuildContext context) {
    final bool compact = MediaQuery.sizeOf(context).width < 760;
    final double horizontalPadding = compact ? 16 : 24;
    final double correlationHeight = compact ? 1040 : 860;
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
              chartHeight: 520,
              filterPills: 2,
              legendItems: 1,
            ),
            const SizedBox(height: 24),
            const ChartSkeletonCard(
              chartHeight: 460,
              filterPills: 3,
              legendItems: 3,
            ),
            const SizedBox(height: 24),
            ChartSkeletonCard(
              chartHeight: correlationHeight,
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

  Widget _buildLanguageLegend(BuildContext context) {
    final String label = _lenguajesSort == _GithubLenguajesSort.porcentaje
        ? 'Barras: % de repos nuevos'
        : 'Barras: repos nuevos';
    return ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: label,
          color: Theme.of(context).colorScheme.primary,
          marker: ChartLegendMarker.square,
        ),
      ],
    );
  }

  Widget _buildFrameworkLegend(BuildContext context) {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final bool variationMode =
        _effectiveFrameworkView == _GithubFrameworkView.variation &&
        _hasHistoricalDeltaForMetric(metric);
    if (variationMode) {
      return const ChartLegend(
        items: <ChartLegendItemData>[
          ChartLegendItemData(
            label: 'Crecimiento',
            color: Color(0xFF10B981),
          ),
          ChartLegendItemData(
            label: 'Caida',
            color: Color(0xFFEF4444),
          ),
          ChartLegendItemData(
            label: 'Sin cambio',
            color: Color(0xFF94A3B8),
          ),
        ],
      );
    }
    return ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: 'Barras: valor actual',
          color: Theme.of(context).colorScheme.primary,
          marker: ChartLegendMarker.square,
        ),
      ],
    );
  }

  Widget _buildCorrelationLegend() {
    return const ChartLegend(
      items: <ChartLegendItemData>[
        ChartLegendItemData(
          label: 'Sobre tendencia',
          color: Color(0xFF059669),
        ),
        ChartLegendItemData(
          label: 'Cerca de tendencia',
          color: Color(0xFF4F46E5),
        ),
        ChartLegendItemData(
          label: 'Bajo tendencia',
          color: Color(0xFFDC2626),
        ),
        ChartLegendItemData(
          label: 'Linea de tendencia',
          color: Color(0xFFEF4444),
          marker: ChartLegendMarker.line,
        ),
      ],
    );
  }

  String _buildLanguageChartAltText() {
    final String metric =
        _lenguajesSort == _GithubLenguajesSort.porcentaje
        ? 'porcentaje de repos nuevos'
        : 'repos nuevos';
    final String order =
        _lenguajesSort == _GithubLenguajesSort.porcentaje
        ? 'ordenado por porcentaje'
        : 'ordenado por repos';
    final String topLabel =
        _lenguajesTopN > 0 ? 'top $_lenguajesTopN' : 'todos los lenguajes';
    return 'Grafico de barras horizontales. Cada barra es un lenguaje. '
        'Metrica: $metric. Vista: $topLabel, $order.';
  }

  String _buildFrameworkChartAltText() {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final _GithubFrameworkView view = _effectiveFrameworkView;
    final _GithubFrameworkOrder order = _effectiveFrameworkOrder;
    final String viewLabel =
        view == _GithubFrameworkView.variation
        ? 'variacion vs periodo anterior'
        : 'valor actual';
    final String orderLabel = switch (order) {
      _GithubFrameworkOrder.highest => 'mayor valor',
      _GithubFrameworkOrder.growth => 'mayor crecimiento',
      _GithubFrameworkOrder.drop => 'mayor caida',
    };
    final String topLabel =
        _frameworkTopN > 0 ? 'top $_frameworkTopN' : 'todos los frameworks';
    return 'Grafico de barras por framework. Metrica: '
        '${_frameworkMetricLabel(metric)}. Vista: $viewLabel. '
        'Orden: $orderLabel. $topLabel.';
  }

  String _buildCorrelationChartAltText() {
    final String detail =
        _scatterDetailMode == _GithubScatterDetailMode.basic
        ? 'basico'
        : 'avanzado';
    return 'Diagrama de dispersion. Eje X: stars (escala log). '
        'Eje Y: contribuidores (escala log). Cada punto es un repo; '
        'el color indica posicion vs tendencia. Linea punteada: tendencia. '
        'Vista: $_scatterFocusLabel, detalle $detail.';
  }

  int _resolveGithubDenominator(
    RunManifestPublic? manifest,
    List<LenguajeModel> rows,
  ) {
    final int manifestBase = manifest?.totalReposClasificables ?? 0;
    if (manifestBase > 0) {
      return manifestBase;
    }
    return rows.fold<int>(
      0,
      (int sum, LenguajeModel item) => sum + item.reposCount,
    );
  }

  String get _languageInsightAccentName {
    final LenguajeModel? leader = _languageInsightLeader;
    if (leader != null && leader.lenguaje.trim().isNotEmpty) {
      return leader.lenguaje;
    }
    return lenguajesPublic?.summary.leader?.lenguaje ??
        (lenguajes.isNotEmpty ? lenguajes.first.lenguaje : 'Tecnolog\u00eda');
  }

  String get _frameworkInsightAccentName {
    return _frameworkInsightLeader?.framework ??
        frameworksHistory?.summary.leaderFramework ??
        _leadingFramework()?.framework ??
        'Framework';
  }

  String get _correlationInsightAccentName {
    final CorrelacionModel? outlier = _correlationInsightRepo;
    if (outlier != null && outlier.language.trim().isNotEmpty) {
      return outlier.language;
    }
    return 'Correlaci\u00f3n';
  }

  List<LenguajeModel> _orderedLenguajesByRepos() {
    if (lenguajes.isEmpty) {
      return const <LenguajeModel>[];
    }
    final List<LenguajeModel> ordered = List<LenguajeModel>.from(lenguajes)
      ..sort((LenguajeModel a, LenguajeModel b) {
        final int byRepos = b.reposCount.compareTo(a.reposCount);
        if (byRepos != 0) {
          return byRepos;
        }
        return a.lenguaje.toLowerCase().compareTo(b.lenguaje.toLowerCase());
      });
    return ordered;
  }

  LenguajeModel? get _languageInsightLeader {
    final List<LenguajeModel> ordered = _orderedLenguajesByRepos();
    if (ordered.isEmpty) {
      return null;
    }
    return ordered.first;
  }

  LenguajeModel? get _languageInsightRunnerUp {
    final List<LenguajeModel> ordered = _orderedLenguajesByRepos();
    if (ordered.length < 2) {
      return null;
    }
    return ordered[1];
  }

  String _getLanguageInsightTitle(RunManifestPublic? manifest) {
    final LenguajeModel? leader = _languageInsightLeader;
    if (leader != null && leader.lenguaje.trim().isNotEmpty) {
      return '${_formatTech(leader.lenguaje)} lidera los repositorios nuevos en GitHub';
    }
    final GithubLanguagePublicLeaderModel? publicLeader =
        lenguajesPublic?.summary.leader;
    if (publicLeader != null && publicLeader.lenguaje.trim().isNotEmpty) {
      return '${_formatTech(publicLeader.lenguaje)} lidera los repositorios nuevos en GitHub';
    }

    final String fallbackName = lenguajes.isNotEmpty
        ? _formatTech(lenguajes.first.lenguaje)
        : 'Tecnolog\u00eda';
    return '$fallbackName lidera los repositorios nuevos en GitHub';
  }

  String _getLanguageInsightDescription(RunManifestPublic? manifest) {
    final LenguajeModel? leader = _languageInsightLeader;
    if (leader != null) {
      final double share = _resolveLanguageSharePct(leader, manifest);
      final String shareText = share > 0
          ? '${share.toStringAsFixed(1)}% del total del periodo'
          : '';
      final LenguajeModel? runnerUp = _languageInsightRunnerUp;
      if (runnerUp != null) {
        final int gap = leader.reposCount - runnerUp.reposCount;
        if (gap > 0) {
          final String gapText =
              '+${_formatCompactInt(gap)} vs ${_formatTech(runnerUp.lenguaje)}';
          if (shareText.isNotEmpty) {
            return '${_formatCompactInt(leader.reposCount)} repos nuevos, '
                '$shareText, $gapText.';
          }
          return '${_formatCompactInt(leader.reposCount)} repos nuevos, '
              '$gapText.';
        }
      }
      if (shareText.isNotEmpty) {
        return '${_formatCompactInt(leader.reposCount)} repos nuevos, $shareText.';
      }
      return '${_formatCompactInt(leader.reposCount)} repos nuevos.';
    }

    final GithubLanguagePublicSummaryModel? summary = lenguajesPublic?.summary;
    final GithubLanguagePublicLeaderModel? publicLeader = summary?.leader;
    if (publicLeader != null) {
      final GithubLanguagePublicLeaderModel? runnerUp = summary?.runnerUp;
      final String shareText =
          '${publicLeader.sharePct.toStringAsFixed(1)}% del total del periodo';
      if (runnerUp != null && (summary?.leaderGapRepos ?? 0) > 0) {
        final int gap = summary!.leaderGapRepos;
        return '${_formatCompactInt(publicLeader.reposCount)} repos nuevos, '
            '$shareText, +${_formatCompactInt(gap)} vs '
            '${_formatTech(runnerUp.lenguaje)}.';
      }
      return '${_formatCompactInt(publicLeader.reposCount)} repos nuevos, $shareText.';
    }

    final int githubDenominator = _resolveGithubDenominator(
      manifest,
      lenguajes,
    );
    if (lenguajes.isEmpty || githubDenominator <= 0) {
      return 'Sin base para resumir el liderazgo de lenguajes.';
    }
    final LenguajeModel fallbackLeader = lenguajes.first;
    final double share = (fallbackLeader.reposCount / githubDenominator) * 100;
    return '${_formatCompactInt(fallbackLeader.reposCount)} repos nuevos, '
        '${share.toStringAsFixed(1)}% del total del periodo.';
  }

  double _resolveLanguageSharePct(
    LenguajeModel leader,
    RunManifestPublic? manifest,
  ) {
    if (leader.porcentaje > 0) {
      return leader.porcentaje;
    }
    final int githubDenominator = _resolveGithubDenominator(
      manifest,
      lenguajes,
    );
    if (githubDenominator <= 0) {
      return 0;
    }
    return (leader.reposCount / githubDenominator) * 100;
  }

  String get _lenguajesSubtitle {
    switch (_lenguajesSort) {
      case _GithubLenguajesSort.repos:
        return 'Lenguajes ordenados por repositorios nuevos en el per\u00edodo de an\u00e1lisis establecido.';
      case _GithubLenguajesSort.porcentaje:
        return 'Lenguajes ordenados por porcentaje de repositorios nuevos en el per\u00edodo de an\u00e1lisis establecido.';
    }
  }

  List<T> _applyTopN<T>(List<T> ordered, int topN) {
    if (topN <= 0 || topN >= ordered.length) {
      return ordered;
    }
    return ordered.take(topN).toList();
  }

  List<int> _buildTopNOptions(
    int rowCount, {
    List<int> presets = const <int>[3, 5, 8, 10, 15],
  }) {
    if (rowCount <= 1) {
      return const <int>[0];
    }
    final Set<int> options = <int>{0, ...presets};
    options.removeWhere((int value) => value != 0 && value >= rowCount);
    if (options.length == 1) {
      options.add(rowCount - 1);
    }
    final List<int> values = options.toList()..sort();
    if (values.contains(0)) {
      values.remove(0);
      values.insert(0, 0);
    }
    return values;
  }

  Map<String, GithubFrameworkHistoryItemModel> get _frameworkHistoryByName {
    final GithubFrameworkHistoryModel? history = frameworksHistory;
    if (history == null) {
      return const <String, GithubFrameworkHistoryItemModel>{};
    }
    final Map<String, GithubFrameworkHistoryItemModel> map =
        <String, GithubFrameworkHistoryItemModel>{};
    for (final item in history.latestFrameworks) {
      final String key = item.framework.trim().toLowerCase();
      if (key.isEmpty) {
        continue;
      }
      map[key] = item;
    }
    return map;
  }

  GithubFrameworkHistoryItemModel? _frameworkHistoryItem(
    FrameworkCommitModel item,
  ) {
    final String key = item.framework.trim().toLowerCase();
    return _frameworkHistoryByName[key];
  }

  String _frameworkMetricLabel(_GithubFrameworkMetric metric) {
    switch (metric) {
      case _GithubFrameworkMetric.commits:
        return 'Commits';
      case _GithubFrameworkMetric.contributors:
        return 'Contributors';
      case _GithubFrameworkMetric.prs:
        return 'PRs mergeados';
      case _GithubFrameworkMetric.issues:
        return 'Issues cerrados';
      case _GithubFrameworkMetric.releases:
        return 'Releases';
    }
  }

  String _frameworkMetricColumnLabel(_GithubFrameworkMetric metric) {
    switch (metric) {
      case _GithubFrameworkMetric.commits:
        return 'commits';
      case _GithubFrameworkMetric.contributors:
        return 'contributors';
      case _GithubFrameworkMetric.prs:
        return 'PRs';
      case _GithubFrameworkMetric.issues:
        return 'issues';
      case _GithubFrameworkMetric.releases:
        return 'releases';
    }
  }

  String _frameworkOrderLabel(_GithubFrameworkOrder order) {
    switch (order) {
      case _GithubFrameworkOrder.highest:
        return 'mayor valor actual';
      case _GithubFrameworkOrder.growth:
        return 'mayor crecimiento';
      case _GithubFrameworkOrder.drop:
        return 'mayor caída';
    }
  }

  double? _frameworkMetricCurrentOrNull(
    FrameworkCommitModel item,
    _GithubFrameworkMetric metric,
  ) {
    final GithubFrameworkHistoryItemModel? historyItem = _frameworkHistoryItem(
      item,
    );
    switch (metric) {
      case _GithubFrameworkMetric.commits:
        return item.commits2025.toDouble();
      case _GithubFrameworkMetric.contributors:
        return (historyItem?.activeContributors ?? item.activeContributors)
            ?.toDouble();
      case _GithubFrameworkMetric.prs:
        return (historyItem?.mergedPrs ?? item.mergedPrs)?.toDouble();
      case _GithubFrameworkMetric.issues:
        return (historyItem?.closedIssues ?? item.closedIssues)?.toDouble();
      case _GithubFrameworkMetric.releases:
        return (historyItem?.releasesCount ?? item.releasesCount)?.toDouble();
    }
  }

  double _frameworkMetricCurrent(
    FrameworkCommitModel item,
    _GithubFrameworkMetric metric,
  ) {
    return _frameworkMetricCurrentOrNull(item, metric) ?? 0;
  }

  double? _frameworkMetricPrevious(
    FrameworkCommitModel item,
    _GithubFrameworkMetric metric,
  ) {
    final GithubFrameworkHistoryItemModel? historyItem = _frameworkHistoryItem(
      item,
    );
    switch (metric) {
      case _GithubFrameworkMetric.commits:
        return (historyItem?.commitsPrev ?? item.commitsPrev)?.toDouble();
      case _GithubFrameworkMetric.contributors:
        return historyItem?.activeContributorsPrev?.toDouble();
      case _GithubFrameworkMetric.prs:
        return historyItem?.mergedPrsPrev?.toDouble();
      case _GithubFrameworkMetric.issues:
        return historyItem?.closedIssuesPrev?.toDouble();
      case _GithubFrameworkMetric.releases:
        return historyItem?.releasesCountPrev?.toDouble();
    }
  }

  double? _frameworkMetricDelta(
    FrameworkCommitModel item,
    _GithubFrameworkMetric metric,
  ) {
    final GithubFrameworkHistoryItemModel? historyItem = _frameworkHistoryItem(
      item,
    );
    switch (metric) {
      case _GithubFrameworkMetric.commits:
        return (historyItem?.deltaCommits ?? item.deltaCommits)?.toDouble();
      case _GithubFrameworkMetric.contributors:
        return historyItem?.deltaActiveContributors?.toDouble();
      case _GithubFrameworkMetric.prs:
        return historyItem?.deltaMergedPrs?.toDouble();
      case _GithubFrameworkMetric.issues:
        return historyItem?.deltaClosedIssues?.toDouble();
      case _GithubFrameworkMetric.releases:
        return historyItem?.deltaReleasesCount?.toDouble();
    }
  }

  double? _frameworkMetricGrowthPct(
    FrameworkCommitModel item,
    _GithubFrameworkMetric metric,
  ) {
    final GithubFrameworkHistoryItemModel? historyItem = _frameworkHistoryItem(
      item,
    );
    switch (metric) {
      case _GithubFrameworkMetric.commits:
        return historyItem?.growthPct ?? item.growthPct;
      case _GithubFrameworkMetric.contributors:
        return historyItem?.growthActiveContributorsPct;
      case _GithubFrameworkMetric.prs:
        return historyItem?.growthMergedPrsPct;
      case _GithubFrameworkMetric.issues:
        return historyItem?.growthClosedIssuesPct;
      case _GithubFrameworkMetric.releases:
        return historyItem?.growthReleasesCountPct;
    }
  }

  bool _hasHistoricalDeltaForMetric(_GithubFrameworkMetric metric) {
    return frameworks.any(
      (FrameworkCommitModel item) =>
          _frameworkMetricDelta(item, metric) != null,
    );
  }

  bool _hasPositiveDeltaForMetric(_GithubFrameworkMetric metric) {
    return frameworks.any((FrameworkCommitModel item) {
      final double? delta = _frameworkMetricDelta(item, metric);
      return delta != null && delta > 0;
    });
  }

  bool _hasNegativeDeltaForMetric(_GithubFrameworkMetric metric) {
    return frameworks.any((FrameworkCommitModel item) {
      final double? delta = _frameworkMetricDelta(item, metric);
      return delta != null && delta < 0;
    });
  }

  bool _hasCurrentDataForMetric(_GithubFrameworkMetric metric) {
    return frameworks.any(
      (FrameworkCommitModel item) =>
          _frameworkMetricCurrentOrNull(item, metric) != null,
    );
  }

  List<_GithubFrameworkMetric> get _frameworkAvailableMetrics {
    final List<_GithubFrameworkMetric> metrics = _GithubFrameworkMetric.values
        .where(_hasCurrentDataForMetric)
        .toList();
    if (metrics.isEmpty) {
      return const <_GithubFrameworkMetric>[_GithubFrameworkMetric.commits];
    }
    return metrics;
  }

  _GithubFrameworkMetric get _effectiveFrameworkMetric {
    final List<_GithubFrameworkMetric> options = _frameworkAvailableMetrics;
    if (options.contains(_frameworkMetric)) {
      return _frameworkMetric;
    }
    return options.first;
  }

  List<_GithubFrameworkView> get _frameworkViewOptions {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final List<_GithubFrameworkView> options = <_GithubFrameworkView>[
      _GithubFrameworkView.current,
    ];
    if (_hasHistoricalDeltaForMetric(metric)) {
      options.add(_GithubFrameworkView.variation);
    }
    return options;
  }

  List<_GithubFrameworkOrder> get _frameworkOrderOptions {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final List<_GithubFrameworkOrder> options = <_GithubFrameworkOrder>[
      _GithubFrameworkOrder.highest,
    ];
    if (_hasHistoricalDeltaForMetric(metric)) {
      if (_hasPositiveDeltaForMetric(metric)) {
        options.add(_GithubFrameworkOrder.growth);
      }
      if (_hasNegativeDeltaForMetric(metric)) {
        options.add(_GithubFrameworkOrder.drop);
      }
    }
    return options;
  }

  _GithubFrameworkView get _effectiveFrameworkView {
    final List<_GithubFrameworkView> options = _frameworkViewOptions;
    if (options.contains(_frameworkView)) {
      return _frameworkView;
    }
    return _GithubFrameworkView.current;
  }

  _GithubFrameworkOrder get _effectiveFrameworkOrder {
    final List<_GithubFrameworkOrder> options = _frameworkOrderOptions;
    if (options.contains(_frameworkOrder)) {
      return _frameworkOrder;
    }
    return _GithubFrameworkOrder.highest;
  }

  int _frameworkMissingCoverageCount(_GithubFrameworkMetric metric) {
    return frameworks
        .where(
          (FrameworkCommitModel item) =>
              _frameworkMetricCurrentOrNull(item, metric) == null,
        )
        .length;
  }

  String? _formatSnapshotDateLabel(String? dateLabel) {
    if (dateLabel == null || dateLabel.trim().isEmpty) {
      return null;
    }
    final DateTime? parsed = DateTime.tryParse(dateLabel.trim());
    if (parsed == null) {
      return dateLabel;
    }
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  String get _frameworkChartTitle {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final int totalCount = frameworks.length;
    final int visibleCount = _visibleFrameworkChartData().length;
    final String metricLabel = _frameworkMetricLabel(metric);
    if (_effectiveFrameworkView == _GithubFrameworkView.variation) {
      return 'Variación de $metricLabel en repos oficiales frontend';
    }
    final int topLabel = (_frameworkTopN > 0 && _frameworkTopN < totalCount)
        ? _frameworkTopN
        : visibleCount;
    return 'Top $topLabel frameworks frontend por $metricLabel';
  }

  String get _frameworkChartSubtitle {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final String metricLabel = _frameworkMetricLabel(metric);
    final String orderLabel = _frameworkOrderLabel(_effectiveFrameworkOrder);
    final StringBuffer buffer = StringBuffer(
      'Métrica: $metricLabel   Orden: $orderLabel',
    );
    final String? latestDate = _formatSnapshotDateLabel(
      frameworksHistory?.latestSnapshotDate ?? frameworksHistory?.snapshotDate,
    );
    final String? previousDate = _formatSnapshotDateLabel(
      frameworksHistory?.previousSnapshotDate,
    );
    if (latestDate != null && previousDate != null) {
      buffer.write('\nComparado (UTC): $previousDate -> $latestDate');
    } else if (latestDate != null) {
      buffer.write('\nActual (UTC): $latestDate');
    }
    return buffer.toString();
  }

  String _formatFrameworkMetricValue(
    double value,
    _GithubFrameworkMetric metric, {
    bool signed = false,
  }) {
    final String prefix = signed && value > 0 ? '+' : '';
    final int rounded = value.round();
    return '$prefix$rounded';
  }

  List<FrameworkCommitModel> _visibleFrameworkChartData() {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final _GithubFrameworkOrder order = _effectiveFrameworkOrder;
    final List<FrameworkCommitModel> ordered =
        List<FrameworkCommitModel>.from(frameworks)..sort((
          FrameworkCommitModel a,
          FrameworkCommitModel b,
        ) {
          if (order == _GithubFrameworkOrder.highest) {
            final double bValue = _frameworkMetricCurrent(b, metric);
            final double aValue = _frameworkMetricCurrent(a, metric);
            final int byValue = bValue.compareTo(aValue);
            if (byValue != 0) {
              return byValue;
            }
          } else if (order == _GithubFrameworkOrder.growth) {
            final double? bDelta = _frameworkMetricDelta(b, metric);
            final double? aDelta = _frameworkMetricDelta(a, metric);
            final double bScore = bDelta ?? -999999;
            final double aScore = aDelta ?? -999999;
            final int byDelta = bScore.compareTo(aScore);
            if (byDelta != 0) {
              return byDelta;
            }
          } else {
            final double? bDelta = _frameworkMetricDelta(b, metric);
            final double? aDelta = _frameworkMetricDelta(a, metric);
            final double bScore = bDelta ?? 999999;
            final double aScore = aDelta ?? 999999;
            final int byDelta = aScore.compareTo(bScore);
            if (byDelta != 0) {
              return byDelta;
            }
          }
          return a.framework.toLowerCase().compareTo(b.framework.toLowerCase());
        });
    return _applyTopN<FrameworkCommitModel>(ordered, _frameworkTopN);
  }

  static const int _scatterFocusLimit = 30;

  List<CorrelacionModel> _visibleCorrelacionDataForFocus(
    _GithubScatterFocus focus,
  ) {
    final List<CorrelacionModel> ordered = List<CorrelacionModel>.from(
      correlacion,
    );
    switch (focus) {
      case _GithubScatterFocus.all:
        return ordered;
      case _GithubScatterFocus.topStars:
        ordered.sort((a, b) => b.stars.compareTo(a.stars));
        break;
      case _GithubScatterFocus.topContributors:
        ordered.sort((a, b) => b.contributors.compareTo(a.contributors));
        break;
      case _GithubScatterFocus.topEngagement:
        ordered.sort(
          (a, b) =>
              b.contributorsPer1kStars.compareTo(a.contributorsPer1kStars),
        );
        break;
      case _GithubScatterFocus.outliers:
        ordered.sort((a, b) {
          final double aScore = a.outlierScore?.abs() ?? -1;
          final double bScore = b.outlierScore?.abs() ?? -1;
          return bScore.compareTo(aScore);
        });
        break;
    }
    return ordered.take(min(_scatterFocusLimit, ordered.length)).toList();
  }

  List<CorrelacionModel> _visibleCorrelacionData() =>
      _visibleCorrelacionDataForFocus(_scatterFocus);

  GithubCorrelationHistorySummaryModel get _effectiveCorrelationSummary {
    if (correlationHistory != null) {
      return correlationHistory!.summary;
    }
    final List<CorrelacionModel> rows = correlacion;
    CorrelacionModel? firstBy(
      int Function(CorrelacionModel a, CorrelacionModel b) comparator,
    ) {
      if (rows.isEmpty) {
        return null;
      }
      final List<CorrelacionModel> ordered = List<CorrelacionModel>.from(rows)
        ..sort(comparator);
      return ordered.first;
    }

    CorrelacionModel? outlierBy(bool positive) {
      final List<CorrelacionModel> withScore = rows
          .where((item) => item.outlierScore != null)
          .toList();
      if (withScore.isEmpty) {
        return null;
      }
      withScore.sort((a, b) {
        final double aScore = a.outlierScore ?? 0;
        final double bScore = b.outlierScore ?? 0;
        return positive ? bScore.compareTo(aScore) : aScore.compareTo(bScore);
      });
      return withScore.first;
    }

    final String? latestDate = correlacion.isNotEmpty
        ? correlacion.first.snapshotDateUtc
        : null;
    return GithubCorrelationHistorySummaryModel(
      correlationValue: _calculateCorrelation(),
      topStarsRepo: firstBy((a, b) => b.stars.compareTo(a.stars)),
      topContributorsRepo: firstBy(
        (a, b) => b.contributors.compareTo(a.contributors),
      ),
      topEngagementRepo: firstBy(
        (a, b) => b.contributorsPer1kStars.compareTo(a.contributorsPer1kStars),
      ),
      positiveOutlierRepo: outlierBy(true),
      negativeOutlierRepo: outlierBy(false),
      itemCount: rows.length,
      latestSnapshotDate: latestDate,
      previousSnapshotDate: null,
    );
  }

  double _calculateCorrelationForRows(List<CorrelacionModel> rows) {
    if (rows.length < 2) {
      return 0.0;
    }
    final int n = rows.length;
    double sumX = 0;
    double sumY = 0;
    double sumX2 = 0;
    double sumY2 = 0;
    double sumXY = 0;

    for (final CorrelacionModel item in rows) {
      final double x = item.stars.toDouble();
      final double y = item.contributors.toDouble();
      sumX += x;
      sumY += y;
      sumX2 += x * x;
      sumY2 += y * y;
      sumXY += x * y;
    }

    final double numerator = (n * sumXY) - (sumX * sumY);
    final double denominator = sqrt(
      ((n * sumX2) - (sumX * sumX)) * ((n * sumY2) - (sumY * sumY)),
    );
    if (denominator == 0) {
      return 0.0;
    }
    return numerator / denominator;
  }

  GithubCorrelationHistorySummaryModel _deriveCorrelationSummary(
    List<CorrelacionModel> rows,
  ) {
    if (rows.isEmpty) {
      return _effectiveCorrelationSummary;
    }

    CorrelacionModel? firstBy(
      int Function(CorrelacionModel a, CorrelacionModel b) comparator,
    ) {
      final List<CorrelacionModel> ordered = List<CorrelacionModel>.from(rows)
        ..sort(comparator);
      return ordered.first;
    }

    CorrelacionModel? outlierBy(bool positive) {
      final List<CorrelacionModel> withScore = rows
          .where((item) => item.outlierScore != null)
          .toList();
      if (withScore.isEmpty) {
        return null;
      }
      withScore.sort((a, b) {
        final double aScore = a.outlierScore ?? 0;
        final double bScore = b.outlierScore ?? 0;
        return positive ? bScore.compareTo(aScore) : aScore.compareTo(bScore);
      });
      return withScore.first;
    }

    final String? latestDate =
        correlationHistory?.latestSnapshotDate ??
        (rows.isNotEmpty ? rows.first.snapshotDateUtc : null);
    final String? previousDate = correlationHistory?.previousSnapshotDate;

    return GithubCorrelationHistorySummaryModel(
      correlationValue: _calculateCorrelationForRows(rows),
      topStarsRepo: firstBy((a, b) => b.stars.compareTo(a.stars)),
      topContributorsRepo: firstBy(
        (a, b) => b.contributors.compareTo(a.contributors),
      ),
      topEngagementRepo: firstBy(
        (a, b) => b.contributorsPer1kStars.compareTo(a.contributorsPer1kStars),
      ),
      positiveOutlierRepo: outlierBy(true),
      negativeOutlierRepo: outlierBy(false),
      itemCount: rows.length,
      latestSnapshotDate: latestDate,
      previousSnapshotDate: previousDate,
    );
  }

  GithubCorrelationHistorySummaryModel get _visibleCorrelationSummary {
    return _visibleCorrelationSummaryForFocus(_scatterFocus);
  }

  GithubCorrelationHistorySummaryModel _visibleCorrelationSummaryForFocus(
    _GithubScatterFocus focus,
  ) {
    final List<CorrelacionModel> rows = _visibleCorrelacionDataForFocus(focus);
    if (rows.isEmpty) {
      return _effectiveCorrelationSummary;
    }
    if (focus == _GithubScatterFocus.all) {
      return _effectiveCorrelationSummary;
    }
    return _deriveCorrelationSummary(rows);
  }

  String get _scatterScaleLabel => 'Log';

  String get _scatterFocusLabel {
    switch (_scatterFocus) {
      case _GithubScatterFocus.all:
        return 'Ver todos';
      case _GithubScatterFocus.topStars:
        return 'Top stars';
      case _GithubScatterFocus.topContributors:
        return 'Top contributors';
      case _GithubScatterFocus.topEngagement:
        return 'Top engagement';
      case _GithubScatterFocus.outliers:
        return 'Outliers';
    }
  }

  String get _scatterChartSubtitle {
    final List<CorrelacionModel> data = _visibleCorrelacionData();
    final StringBuffer buffer = StringBuffer(
      'Escala: $_scatterScaleLabel   Vista: $_scatterFocusLabel   Repos: ${data.length}',
    );
    final String? latestDate = _formatSnapshotDateLabel(
      correlationHistory?.latestSnapshotDate ??
          (correlacion.isNotEmpty ? correlacion.first.snapshotDateUtc : null),
    );
    final String? previousDate = _formatSnapshotDateLabel(
      correlationHistory?.previousSnapshotDate,
    );
    if (latestDate != null && previousDate != null) {
      buffer.write('\nComparado (UTC): $previousDate -> $latestDate');
    } else if (latestDate != null) {
      buffer.write('\nSnapshot actual (UTC): $latestDate');
    } else {
      buffer.write('\nSnapshot actual (UTC): no disponible');
    }
    return buffer.toString();
  }

  CorrelacionModel? _currentSelectedCorrelation(List<CorrelacionModel> data) {
    if (data.isEmpty) {
      return null;
    }
    if (_scatterSelectedRepoName == null || _scatterSelectedRepoName!.isEmpty) {
      return data.first;
    }
    for (final CorrelacionModel item in data) {
      if (item.repoName == _scatterSelectedRepoName) {
        return item;
      }
    }
    return data.first;
  }

  CorrelacionModel? _preferredCorrelationSelectionForFocus(
    _GithubScatterFocus focus,
  ) {
    if (focus == _GithubScatterFocus.all) {
      return null;
    }

    final GithubCorrelationHistorySummaryModel summary =
        _visibleCorrelationSummaryForFocus(focus);
    final CorrelacionModel? preferred = switch (focus) {
      _GithubScatterFocus.all => null,
      _GithubScatterFocus.topStars => summary.topStarsRepo,
      _GithubScatterFocus.topContributors => summary.topContributorsRepo,
      _GithubScatterFocus.topEngagement => summary.topEngagementRepo,
      _GithubScatterFocus.outliers => summary.positiveOutlierRepo,
    };
    if (preferred == null) {
      return null;
    }

    for (final CorrelacionModel item in _visibleCorrelacionDataForFocus(
      focus,
    )) {
      if (item.repoName == preferred.repoName) {
        return item;
      }
    }
    return null;
  }

  void _handleScatterFocusChanged(_GithubScatterFocus value) {
    final List<CorrelacionModel> visibleRows = _visibleCorrelacionDataForFocus(
      value,
    );
    final CorrelacionModel? preferred = _preferredCorrelationSelectionForFocus(
      value,
    );

    setState(() {
      _scatterFocus = value;
      _scatterCollisionRepoNames = const <String>[];
      if (value == _GithubScatterFocus.all) {
        final bool keepCurrent =
            _scatterSelectedRepoName != null &&
            visibleRows.any(
              (CorrelacionModel item) =>
                  item.repoName == _scatterSelectedRepoName,
            );
        if (!keepCurrent) {
          _scatterSelectedRepoName = visibleRows.isEmpty
              ? null
              : visibleRows.first.repoName;
        }
        return;
      }

      if (preferred != null) {
        _scatterSelectedRepoName = preferred.repoName;
      } else {
        _scatterSelectedRepoName = visibleRows.isEmpty
            ? null
            : visibleRows.first.repoName;
      }
    });
  }

  Widget _buildScatterSummaryBadges() {
    final GithubCorrelationHistorySummaryModel summary =
        _visibleCorrelationSummary;
    final List<Widget> badges = <Widget>[
      _buildScatterSummaryBadge(
        label: 'Correlación',
        value: summary.correlationValue.toStringAsFixed(2),
        color: const Color(0xFF2563EB),
      ),
    ];

    void addRepoBadge({
      required String label,
      required CorrelacionModel? repo,
    }) {
      if (repo == null) {
        return;
      }
      badges.add(
        _buildScatterSummaryBadge(
          label: label,
          value: _shortRepoLabel(repo.repoName),
          color: _resolveCorrelationDotColor(repo),
        ),
      );
    }

    switch (_scatterFocus) {
      case _GithubScatterFocus.all:
        {
          addRepoBadge(label: 'Mayor stars', repo: summary.topStarsRepo);
          addRepoBadge(
            label: 'Mayor contributors',
            repo: summary.topContributorsRepo,
          );
          addRepoBadge(
            label: 'Comunidad más activa',
            repo: summary.topEngagementRepo,
          );
          addRepoBadge(
            label: 'Por encima de la tendencia',
            repo: summary.positiveOutlierRepo,
          );
          addRepoBadge(
            label: 'Por debajo de la tendencia',
            repo: summary.negativeOutlierRepo,
          );
          break;
        }
      case _GithubScatterFocus.topStars:
        {
          addRepoBadge(label: 'Mayor stars', repo: summary.topStarsRepo);
          addRepoBadge(
            label: 'Por encima de la tendencia',
            repo: summary.positiveOutlierRepo,
          );
          addRepoBadge(
            label: 'Por debajo de la tendencia',
            repo: summary.negativeOutlierRepo,
          );
          break;
        }
      case _GithubScatterFocus.topContributors:
        {
          addRepoBadge(
            label: 'Mayor contributors',
            repo: summary.topContributorsRepo,
          );
          addRepoBadge(
            label: 'Comunidad más activa',
            repo: summary.topEngagementRepo,
          );
          addRepoBadge(
            label: 'Por encima de la tendencia',
            repo: summary.positiveOutlierRepo,
          );
          addRepoBadge(
            label: 'Por debajo de la tendencia',
            repo: summary.negativeOutlierRepo,
          );
          break;
        }
      case _GithubScatterFocus.topEngagement:
        {
          addRepoBadge(
            label: 'Comunidad más activa',
            repo: summary.topEngagementRepo,
          );
          addRepoBadge(
            label: 'Por encima de la tendencia',
            repo: summary.positiveOutlierRepo,
          );
          addRepoBadge(
            label: 'Por debajo de la tendencia',
            repo: summary.negativeOutlierRepo,
          );
          break;
        }
      case _GithubScatterFocus.outliers:
        {
          addRepoBadge(
            label: 'Por encima de la tendencia',
            repo: summary.positiveOutlierRepo,
          );
          addRepoBadge(
            label: 'Por debajo de la tendencia',
            repo: summary.negativeOutlierRepo,
          );
          break;
        }
    }

    return Wrap(spacing: 8, runSpacing: 8, children: badges);
  }

  Widget _buildScatterSummaryBadge({
    required String label,
    required String value,
    required Color color,
  }) {
    final Color foreground = _resolveFrameworkBadgeTextColor(color);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationDetailPanel(CorrelacionModel? selected) {
    if (selected == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Text(
          'Selecciona un repositorio para ver el detalle.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF475569),
          ),
        ),
      );
    }

    final Color accent = _resolveCorrelationDotColor(selected);
    final List<_DetailMetric> metrics = <_DetailMetric>[
      _DetailMetric(label: 'Stars', value: _formatCompactInt(selected.stars)),
      _DetailMetric(
        label: 'Contributors',
        value: _formatCompactInt(selected.contributors),
      ),
      _DetailMetric(
        label: 'Language',
        value: selected.language.trim().isEmpty
            ? 'No clasificado'
            : selected.language,
      ),
      _DetailMetric(
        label: 'Actividad por stars',
        value: _formatMetricDecimal(
          selected.engagementRatio,
          decimals: 3,
          tinyThreshold: 0.001,
        ),
      ),
      _DetailMetric(
        label: 'Contributors / 1k stars',
        value: _formatMetricDecimal(
          selected.contributorsPer1kStars,
          decimals: 1,
          tinyThreshold: 0.1,
        ),
      ),
      _DetailMetric(
        label: 'Posicion frente a la tendencia',
        value: _positionVersusTrendLabel(selected),
      ),
      _DetailMetric(
        label: 'Estado frente a la tendencia',
        value: _outlierStateLabel(selected),
      ),
    ];

    if (_scatterDetailMode == _GithubScatterDetailMode.advanced) {
      metrics.addAll(<_DetailMetric>[
        _DetailMetric(
          label: 'Contributors esperados',
          value: selected.expectedContributors == null
              ? 'N/D'
              : _formatMetricDecimal(
                  selected.expectedContributors!,
                  decimals: 1,
                ),
        ),
        _DetailMetric(
          label: 'Variación vs tendencia',
          value: selected.contributorsDeltaVsTrend == null
              ? 'N/D'
              : _formatMetricDecimal(
                  selected.contributorsDeltaVsTrend!,
                  decimals: 1,
                  signed: true,
                ),
        ),
        _DetailMetric(
          label: 'Distancia a la tendencia',
          value: selected.outlierScore == null
              ? 'N/D'
              : _formatMetricDecimal(
                  selected.outlierScore!,
                  decimals: 1,
                  signed: true,
                ),
        ),
      ]);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: accent.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _shortRepoLabel(selected.repoName),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),
              Text(
                _scatterDetailMode == _GithubScatterDetailMode.basic
                    ? 'Detalle basico'
                    : 'Detalle avanzado',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: metrics
                .map((item) => _buildCorrelationMetricTile(item, accent))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrelationMetricTile(_DetailMetric metric, Color accent) {
    return Container(
      constraints: const BoxConstraints(minWidth: 160, maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            metric.label,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            metric.value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
        ],
      ),
    );
  }

  String _positionVersusTrendLabel(CorrelacionModel item) {
    final double? delta = item.contributorsDeltaVsTrend;
    if (delta == null) {
      return 'Sin referencia';
    }
    if (delta.abs() < 1) {
      return 'En linea con la tendencia';
    }
    return delta > 0
        ? 'Por encima de la tendencia'
        : 'Por debajo de la tendencia';
  }

  String _outlierStateLabel(CorrelacionModel item) {
    switch (item.trendBucket) {
      case 'above_trend':
        return 'Por encima de la tendencia';
      case 'below_trend':
        return 'Por debajo de la tendencia';
      case 'near_trend':
        return 'Cercano a la tendencia';
      default:
        return 'Sin clasificar';
    }
  }

  Color _resolveCorrelationDotColor(CorrelacionModel item) {
    switch (item.trendBucket) {
      case 'above_trend':
        return const Color(0xFF059669);
      case 'below_trend':
        return const Color(0xFFDC2626);
      case 'near_trend':
      default:
        return const Color(0xFF4F46E5);
    }
  }

  double _scatterTransform(double value) {
    return log(max(value, 1)) / ln10;
  }

  double _scatterMinBound(Iterable<double> rawValues, {double padding = 0.18}) {
    final double minValue = rawValues
        .map((double value) => max(value, 1.0))
        .reduce(min);
    return max(0.0, _scatterTransform(minValue) - padding);
  }

  String _formatLogAxisValueWithOffset(double value, double offset) {
    final double normalized = value - offset;
    final int power = normalized.round();
    if ((normalized - power).abs() > 0.04 || power < 0) {
      return '';
    }
    final double actual = pow(10, power).toDouble();
    return _formatCompactAxisValue(actual);
  }

  String _formatMetricDecimal(
    double value, {
    required int decimals,
    double? tinyThreshold,
    bool signed = false,
  }) {
    final double threshold = tinyThreshold ?? (1 / pow(10, decimals));
    final double absValue = value.abs();
    if (absValue > 0 && absValue < threshold) {
      final String thresholdLabel = threshold.toStringAsFixed(decimals);
      return value.isNegative ? '-<$thresholdLabel' : '<$thresholdLabel';
    }

    final String signPrefix = signed && value > 0 ? '+' : '';
    final String fixed = value.toStringAsFixed(decimals);
    final bool negative = fixed.startsWith('-');
    final String unsigned = negative ? fixed.substring(1) : fixed;
    final List<String> parts = unsigned.split('.');
    final String wholePart = _formatCompactInt(int.parse(parts.first));
    if (parts.length == 1 || int.parse(parts.last) == 0 && decimals == 0) {
      return '${negative ? '-' : signPrefix}$wholePart';
    }
    return '${negative ? '-' : signPrefix}$wholePart.${parts.last}';
  }

  List<CorrelacionModel> _correlationCandidatesFromResponse(
    LineTouchResponse? response,
    List<CorrelacionModel> data,
  ) {
    final List<LineBarSpot> touched =
        response?.lineBarSpots
            ?.where((LineBarSpot spot) => spot.barIndex == 0)
            .toList() ??
        const <LineBarSpot>[];
    if (touched.isEmpty) {
      return const <CorrelacionModel>[];
    }
    final Set<String> seen = <String>{};
    final List<CorrelacionModel> matches = <CorrelacionModel>[];
    for (final LineBarSpot touchedSpot in touched) {
      final int index = touchedSpot.spotIndex;
      if (index < 0 || index >= data.length) {
        continue;
      }
      final CorrelacionModel item = data[index];
      if (seen.add(item.repoName)) {
        matches.add(item);
      }
    }
    return matches;
  }

  // Grafico 1: Barras HORIZONTALES
  Widget _buildHorizontalBarChart() {
    final List<LenguajeModel> data = _topLenguajes;
    if (data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final List<int> topNOptions = _buildTopNOptions(
      lenguajes.length,
      presets: const <int>[3, 5, 8, 10, 15, 20],
    );
    final int selectedTopN = topNOptions.contains(_lenguajesTopN)
        ? _lenguajesTopN
        : 0;
    final bool sortByPercentage =
        _lenguajesSort == _GithubLenguajesSort.porcentaje;

    double metricValue(LenguajeModel item) {
      return sortByPercentage ? item.porcentaje : item.reposCount.toDouble();
    }

    final double maxMetric = data
        .map((LenguajeModel item) => metricValue(item))
        .reduce(max);
    final double axisMax;
    if (sortByPercentage) {
      final double padded = (maxMetric * 1.1).clamp(5, 100).toDouble();
      axisMax = ((padded / 5).ceil() * 5).toDouble();
    } else {
      final int maxRepos = data
          .map((LenguajeModel item) => item.reposCount)
          .reduce(max);
      axisMax = ((maxRepos + 49) ~/ 50 * 50).toDouble();
    }
    final List<double> ticks = <double>[
      0,
      axisMax * 0.25,
      axisMax * 0.5,
      axisMax * 0.75,
      axisMax,
    ].toSet().toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: <Widget>[
            ChartInlineFilter<int>(
              key: const ValueKey<String>('gh-framework-top-filter'),
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
                  _lenguajesTopN = value;
                });
              },
            ),
            ChartInlineFilter<_GithubLenguajesSort>(
              label: 'Orden',
              value: _lenguajesSort,
              selectedLabel: _lenguajesSort == _GithubLenguajesSort.repos
                  ? 'Más repos'
                  : 'Mayor %',
              items: const <DropdownMenuItem<_GithubLenguajesSort>>[
                DropdownMenuItem<_GithubLenguajesSort>(
                  value: _GithubLenguajesSort.repos,
                  child: Text('M\u00e1s repos'),
                ),
                DropdownMenuItem<_GithubLenguajesSort>(
                  value: _GithubLenguajesSort.porcentaje,
                  child: Text('Mayor %'),
                ),
              ],
              onChanged: (_GithubLenguajesSort? value) {
                if (value == null) {
                  return;
                }
                setState(() {
                  _lenguajesSort = value;
                });
              },
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    width: 116,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: data
                          .map(
                            (LenguajeModel lang) => Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(
                                _formatTech(lang.lenguaje),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: data.asMap().entries.map((entry) {
                              final int index = entry.key;
                              final LenguajeModel item = entry.value;
                              final double currentMetric = metricValue(item);
                              final double widthPercent = axisMax == 0
                                  ? 0
                                  : currentMetric / axisMax;
                              return Tooltip(
                                message: sortByPercentage
                                    ? '${_formatTech(item.lenguaje)}: ${item.porcentaje.toStringAsFixed(1)}%'
                                    : '${_formatTech(item.lenguaje)}: ${item.reposCount} repos',
                                waitDuration: const Duration(milliseconds: 120),
                                showDuration: const Duration(
                                  milliseconds: 1400,
                                ),
                                textStyle: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Container(
                                  height: 28,
                                  width: max(
                                    40,
                                    (constraints.maxWidth - 130) * widthPercent,
                                  ).toDouble(),
                                  decoration: BoxDecoration(
                                    color:
                                        distinctColors[index %
                                            distinctColors.length],
                                    borderRadius: const BorderRadius.horizontal(
                                      right: Radius.circular(4),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: ticks
                              .map(
                                (double val) => Text(
                                  sortByPercentage
                                      ? '${val.toStringAsFixed(0)}%'
                                      : val.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  // Grafico 2: Framework metrics with dynamic metric/view selectors
  Widget _buildFrameworkPieChart() {
    final List<_GithubFrameworkMetric> metricOptions =
        _frameworkAvailableMetrics;
    final _GithubFrameworkMetric selectedMetric = _effectiveFrameworkMetric;
    if (selectedMetric != _frameworkMetric) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _frameworkMetric = selectedMetric;
        });
      });
    }

    final List<FrameworkCommitModel> data = _visibleFrameworkChartData();
    if (data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final List<int> topNOptions = _buildTopNOptions(
      frameworks.length,
      presets: const <int>[3, 5, 8, 10, 15],
    );
    final int selectedTopN = topNOptions.contains(_frameworkTopN)
        ? _frameworkTopN
        : 0;
    final List<_GithubFrameworkOrder> orderOptions = _frameworkOrderOptions;
    final _GithubFrameworkOrder selectedOrder = _effectiveFrameworkOrder;
    final List<_GithubFrameworkView> viewOptions = _frameworkViewOptions;
    final _GithubFrameworkView selectedView = _effectiveFrameworkView;
    final int missingCoverage = _frameworkMissingCoverageCount(selectedMetric);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            ChartInlineFilter<int>(
              label: 'Top',
              value: selectedTopN,
              selectedLabel: selectedTopN == 0
                  ? 'Ver todos'
                  : 'Top $selectedTopN',
              items: topNOptions
                  .map(
                    (int value) => DropdownMenuItem<int>(
                      value: value,
                      child: Text(value == 0 ? 'Ver todos' : 'Top $value'),
                    ),
                  )
                  .toList(),
              onChanged: (int? value) {
                if (value == null) return;
                setState(() {
                  _frameworkTopN = value;
                });
              },
            ),
            ChartInlineFilter<_GithubFrameworkMetric>(
              key: const ValueKey<String>('gh-framework-metric-filter'),
              label: 'Métrica',
              value: selectedMetric,
              selectedLabel: _frameworkMetricLabel(selectedMetric),
              items: metricOptions
                  .map(
                    (_GithubFrameworkMetric metric) =>
                        DropdownMenuItem<_GithubFrameworkMetric>(
                          value: metric,
                          child: Text(_frameworkMetricLabel(metric)),
                        ),
                  )
                  .toList(),
              onChanged: (_GithubFrameworkMetric? value) {
                if (value == null) return;
                setState(() {
                  _frameworkMetric = value;
                });
              },
            ),
            if (orderOptions.length > 1)
              ChartInlineFilter<_GithubFrameworkOrder>(
                key: const ValueKey<String>('gh-framework-order-filter'),
                label: 'Orden',
                value: selectedOrder,
                selectedLabel: switch (selectedOrder) {
                  _GithubFrameworkOrder.highest => 'Mayor valor',
                  _GithubFrameworkOrder.growth => 'Mayor crecimiento',
                  _GithubFrameworkOrder.drop => 'Mayor caída',
                },
                items: orderOptions
                    .map(
                      (_GithubFrameworkOrder order) =>
                          DropdownMenuItem<_GithubFrameworkOrder>(
                            value: order,
                            child: Text(switch (order) {
                              _GithubFrameworkOrder.highest => 'Mayor valor',
                              _GithubFrameworkOrder.growth =>
                                'Mayor crecimiento',
                              _GithubFrameworkOrder.drop => 'Mayor caída',
                            }),
                          ),
                    )
                    .toList(),
                onChanged: (_GithubFrameworkOrder? value) {
                  if (value == null) return;
                  setState(() {
                    _frameworkOrder = value;
                  });
                },
              ),
            if (viewOptions.length > 1)
              ChartInlineFilter<_GithubFrameworkView>(
                key: const ValueKey<String>('gh-framework-view-filter'),
                label: 'Ver',
                value: selectedView,
                selectedLabel: selectedView == _GithubFrameworkView.current
                    ? 'Valor actual'
                    : 'Variación',
                items: viewOptions
                    .map(
                      (_GithubFrameworkView view) =>
                          DropdownMenuItem<_GithubFrameworkView>(
                            value: view,
                            child: Text(
                              view == _GithubFrameworkView.current
                                  ? 'Valor actual'
                                  : 'Variación',
                            ),
                          ),
                    )
                    .toList(),
                onChanged: (_GithubFrameworkView? value) {
                  if (value == null) return;
                  setState(() {
                    _frameworkView = value;
                  });
                },
              ),
          ],
        ),
        const SizedBox(height: 12),
        _buildFrameworkSummaryBadges(data),
        if (missingCoverage > 0) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            'Cobertura parcial: $missingCoverage framework(s) sin datos completos para ${_frameworkMetricColumnLabel(selectedMetric)}.',
            style: const TextStyle(
              color: Color(0xFFB45309),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
        if (selectedView == _GithubFrameworkView.variation &&
            !_hasHistoricalDeltaForMetric(selectedMetric)) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'Histórico insuficiente: se muestra solo valor actual.',
            style: TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(child: _buildFrameworkMetricBarChart(data, selectedView)),
      ],
    );
  }

  Widget _buildFrameworkSummaryBadges(List<FrameworkCommitModel> data) {
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    if (!_hasCurrentDataForMetric(metric)) {
      return const SizedBox.shrink();
    }

    final FrameworkCommitModel leader = data.reduce(
      (FrameworkCommitModel a, FrameworkCommitModel b) =>
          _frameworkMetricCurrent(a, metric) >=
              _frameworkMetricCurrent(b, metric)
          ? a
          : b,
    );
    final List<FrameworkCommitModel> deltas = data
        .where(
          (FrameworkCommitModel item) =>
              _frameworkMetricDelta(item, metric) != null,
        )
        .toList();
    FrameworkCommitModel? growth;
    FrameworkCommitModel? drop;
    if (deltas.isNotEmpty) {
      final List<FrameworkCommitModel> positiveDeltas = deltas
          .where(
            (FrameworkCommitModel item) =>
                (_frameworkMetricDelta(item, metric) ?? 0) > 0,
          )
          .toList();
      final List<FrameworkCommitModel> negativeDeltas = deltas
          .where(
            (FrameworkCommitModel item) =>
                (_frameworkMetricDelta(item, metric) ?? 0) < 0,
          )
          .toList();

      if (positiveDeltas.isNotEmpty) {
        growth = positiveDeltas.reduce(
          (FrameworkCommitModel a, FrameworkCommitModel b) =>
              (_frameworkMetricDelta(a, metric) ?? -999999) >=
                  (_frameworkMetricDelta(b, metric) ?? -999999)
              ? a
              : b,
        );
      }

      if (negativeDeltas.isNotEmpty) {
        drop = negativeDeltas.reduce(
          (FrameworkCommitModel a, FrameworkCommitModel b) =>
              (_frameworkMetricDelta(a, metric) ?? 999999) <=
                  (_frameworkMetricDelta(b, metric) ?? 999999)
              ? a
              : b,
        );
      }
    }

    Widget badge({
      required String label,
      required String value,
      required Color accent,
    }) {
      final Color background = accent.withValues(alpha: 0.12);
      final Color foreground = _resolveFrameworkBadgeTextColor(accent);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: accent.withValues(alpha: 0.45)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: accent.withValues(alpha: 0.12),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '$label: $value',
              style: TextStyle(
                color: foreground,
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ],
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        badge(
          label: 'Líder',
          value: leader.framework,
          accent: _resolveFrameworkBarColor(leader.framework),
        ),
        if (growth != null)
          badge(
            label: 'Mayor crecimiento',
            value:
                '${growth.framework} (${_formatFrameworkMetricValue(_frameworkMetricDelta(growth, metric) ?? 0, metric, signed: true)})',
            accent: _resolveFrameworkBarColor(growth.framework),
          ),
        if (drop != null)
          badge(
            label: 'Mayor caída',
            value:
                '${drop.framework} (${_formatFrameworkMetricValue(_frameworkMetricDelta(drop, metric) ?? 0, metric, signed: true)})',
            accent: _resolveFrameworkBarColor(drop.framework),
          ),
      ],
    );
  }

  Widget _buildFrameworkMetricBarChart(
    List<FrameworkCommitModel> data,
    _GithubFrameworkView selectedView,
  ) {
    final _GithubFrameworkMetric metric = _effectiveFrameworkMetric;
    final bool variationMode =
        selectedView == _GithubFrameworkView.variation &&
        _hasHistoricalDeltaForMetric(metric);
    final List<double> values = data
        .map(
          (FrameworkCommitModel item) => variationMode
              ? (_frameworkMetricDelta(item, metric) ?? 0)
              : _frameworkMetricCurrent(item, metric),
        )
        .toList();
    final double maxAbs = values.fold<double>(
      0,
      (double maxValue, double value) =>
          value.abs() > maxValue ? value.abs() : maxValue,
    );
    final double axisMax = maxAbs <= 0 ? 1 : (maxAbs * 1.25);
    final double minY = variationMode ? -axisMax : 0;
    final double maxY = axisMax;
    final double zeroMarkerHeight = max(axisMax * 0.03, 0.12);

    return BarChart(
      key: ValueKey<String>(
        'gh-framework-bars-${metric.name}-${selectedView.name}-${_effectiveFrameworkOrder.name}-$_frameworkTopN-${data.length}',
      ),
      BarChartData(
        minY: minY,
        maxY: maxY,
        barGroups: data.asMap().entries.map((entry) {
          final int index = entry.key;
          final FrameworkCommitModel item = entry.value;
          final double y = variationMode
              ? (_frameworkMetricDelta(item, metric) ?? 0)
              : _frameworkMetricCurrent(item, metric);
          final bool isZeroVariationMarker = variationMode && y == 0;
          final double plottedY = isZeroVariationMarker ? zeroMarkerHeight : y;
          final Color barColor = variationMode
              ? (isZeroVariationMarker
                    ? const Color(0xFF94A3B8)
                    : y > 0
                    ? const Color(0xFF10B981)
                    : y < 0
                    ? const Color(0xFFEF4444)
                    : const Color(0xFF94A3B8))
              : _resolveFrameworkBarColor(item.framework);
          return BarChartGroupData(
            x: index,
            barRods: <BarChartRodData>[
              BarChartRodData(
                toY: plottedY,
                width: 24,
                borderRadius: BorderRadius.circular(4),
                color: barColor,
              ),
            ],
          );
        }).toList(),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final int index = group.x.toInt();
              if (index < 0 || index >= data.length) {
                return null;
              }
              final FrameworkCommitModel item = data[index];
              final double currentValue = _frameworkMetricCurrent(item, metric);
              final double? previousValue = _frameworkMetricPrevious(
                item,
                metric,
              );
              final double? deltaValue = _frameworkMetricDelta(item, metric);
              final double? growthPct = _frameworkMetricGrowthPct(item, metric);
              final String metricLabel = _frameworkMetricLabel(metric);
              final StringBuffer text = StringBuffer();
              text.writeln(item.framework);
              if (variationMode) {
                final double delta = deltaValue ?? 0;
                if (delta == 0) {
                  text.writeln('Cambio vs periodo anterior: sin variación');
                } else {
                  text.writeln(
                    'Cambio vs periodo anterior: ${_formatFrameworkMetricValue(delta, metric, signed: true)} ${_frameworkMetricColumnLabel(metric)}',
                  );
                }
              }
              text.writeln(
                '$metricLabel actual: ${_formatFrameworkMetricValue(currentValue, metric)}',
              );
              if (previousValue != null) {
                text.writeln(
                  '$metricLabel previo: ${_formatFrameworkMetricValue(previousValue, metric)}',
                );
              }
              if (growthPct != null) {
                final String pctPrefix = growthPct > 0 ? '+' : '';
                text.write(
                  'Variación %: $pctPrefix${growthPct.toStringAsFixed(1)}%',
                );
              }
              return BarTooltipItem(
                text.toString(),
                const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              );
            },
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: axisMax / 5,
          getDrawingHorizontalLine: (double _) => FlLine(
            color: const Color(0xFFCBD5E1),
            strokeWidth: 1,
            dashArray: <int>[6, 4],
          ),
        ),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              getTitlesWidget: (double value, TitleMeta meta) => Text(
                _formatFrameworkMetricValue(
                  value,
                  metric,
                  signed: variationMode,
                ),
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF475569),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 58,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index < 0 || index >= data.length) {
                  return const SizedBox.shrink();
                }
                final String label = data[index].framework;
                return SideTitleWidget(
                  axisSide: meta.axisSide,
                  space: 8,
                  child: Text(
                    label.length > 14 ? '${label.substring(0, 14)}...' : label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF475569),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }

  Widget _buildCorrelationExperience() {
    final List<CorrelacionModel> data = _visibleCorrelacionData();
    if (data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }

    final CorrelacionModel? selected = _currentSelectedCorrelation(data);
    final List<String> visibleCandidates = _scatterCollisionRepoNames
        .where(
          (String repoName) => data.any((item) => item.repoName == repoName),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: <Widget>[
            ChartInlineFilter<_GithubScatterFocus>(
              key: const ValueKey<String>('gh-correlation-focus-filter'),
              label: 'Vista',
              value: _scatterFocus,
              selectedLabel: _scatterFocusLabel,
              items: const <DropdownMenuItem<_GithubScatterFocus>>[
                DropdownMenuItem<_GithubScatterFocus>(
                  value: _GithubScatterFocus.all,
                  child: Text('Ver todos'),
                ),
                DropdownMenuItem<_GithubScatterFocus>(
                  value: _GithubScatterFocus.topStars,
                  child: Text('Top stars'),
                ),
                DropdownMenuItem<_GithubScatterFocus>(
                  value: _GithubScatterFocus.topContributors,
                  child: Text('Top contributors'),
                ),
                DropdownMenuItem<_GithubScatterFocus>(
                  value: _GithubScatterFocus.topEngagement,
                  child: Text('Top engagement'),
                ),
                DropdownMenuItem<_GithubScatterFocus>(
                  value: _GithubScatterFocus.outliers,
                  child: Text('Outliers'),
                ),
              ],
              onChanged: (_GithubScatterFocus? value) {
                if (value == null) return;
                _handleScatterFocusChanged(value);
              },
            ),
            ChartInlineFilter<_GithubScatterDetailMode>(
              key: const ValueKey<String>('gh-correlation-detail-filter'),
              label: 'Detalle',
              value: _scatterDetailMode,
              selectedLabel:
                  _scatterDetailMode == _GithubScatterDetailMode.basic
                  ? 'B\u00e1sico'
                  : 'Avanzado',
              items: const <DropdownMenuItem<_GithubScatterDetailMode>>[
                DropdownMenuItem<_GithubScatterDetailMode>(
                  value: _GithubScatterDetailMode.basic,
                  child: Text('Básico'),
                ),
                DropdownMenuItem<_GithubScatterDetailMode>(
                  value: _GithubScatterDetailMode.advanced,
                  child: Text('Avanzado'),
                ),
              ],
              onChanged: (_GithubScatterDetailMode? value) {
                if (value == null) return;
                setState(() => _scatterDetailMode = value);
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildScatterSummaryBadges(),
        const SizedBox(height: 10),
        const Text(
          'Selecciona un punto para ver sus detalles',
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: Color(0xFF334155),
          ),
        ),
        if (correlationHistory == null) ...<Widget>[
          const SizedBox(height: 8),
          const Text(
            'Modo fallback CSV: el bridge histórico no estuvo disponible.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ],
        if (visibleCandidates.length > 1) ...<Widget>[
          const SizedBox(height: 10),
          const Text(
            'Repos cercanos: elige uno para fijar el detalle.',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: Color(0xFF334155),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: visibleCandidates
                .map(
                  (String repoName) => ChoiceChip(
                    label: Text(_shortRepoLabel(repoName)),
                    selected: repoName == selected?.repoName,
                    onSelected: (_) {
                      setState(() {
                        _scatterSelectedRepoName = repoName;
                      });
                    },
                  ),
                )
                .toList(),
          ),
        ],
        const SizedBox(height: 12),
        Expanded(child: _buildScatterChart(data, selected)),
        const SizedBox(height: 14),
        _buildCorrelationDetailPanel(selected),
      ],
    );
  }

  // Grafico 3: Scatter Plot
  Widget _buildScatterChart(
    List<CorrelacionModel> data,
    CorrelacionModel? selected,
  ) {
    if (data.isEmpty) {
      return const Center(child: Text('No hay datos disponibles'));
    }
    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;
    final int n = data.length;

    for (final CorrelacionModel item in data) {
      final double x = item.stars.toDouble();
      final double y = item.contributors.toDouble();
      sumX += x;
      sumY += y;
      sumXY += x * y;
      sumX2 += x * x;
    }

    final double slope = n > 0 && (n * sumX2 - sumX * sumX) != 0
        ? (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX)
        : 0;
    final double intercept = n > 0 ? (sumY - slope * sumX) / n : 0;

    double expectedAt(double x) {
      return max(0, slope * x + intercept);
    }

    final double maxStarsValue = data
        .map((CorrelacionModel item) => item.stars.toDouble())
        .reduce(max);
    final double minStarsValue = data
        .map((CorrelacionModel item) => max(item.stars.toDouble(), 1.0))
        .reduce(min);
    final double maxContributorsValue = data
        .map((CorrelacionModel item) {
          final double expected = item.expectedContributors ?? 0;
          return max(item.contributors.toDouble(), expected);
        })
        .reduce(max);
    final double minContributorsValue = data
        .expand((CorrelacionModel item) sync* {
          yield max(item.contributors.toDouble(), 1.0);
          final double expected = item.expectedContributors ?? 0;
          if (expected > 0) {
            yield expected;
          }
        })
        .reduce(min);

    final double chartMinStars = _scatterMinBound(<double>[
      minStarsValue,
    ], padding: 0.22);
    final double chartMinContributors = _scatterMinBound(<double>[
      minContributorsValue,
      expectedAt(minStarsValue),
      expectedAt(maxStarsValue),
    ], padding: 0.16);

    final double chartMaxStars = max(
      chartMinStars + 1.4,
      _scatterTransform(maxStarsValue) + 0.2,
    );
    final double chartMaxContributors = max(
      chartMinContributors + 1.15,
      _scatterTransform(maxContributorsValue) + 0.2,
    );

    const double xInterval = 1;
    const double yInterval = 1;

    FlSpot buildSpot(CorrelacionModel item) => FlSpot(
      _scatterTransform(item.stars.toDouble()),
      _scatterTransform(item.contributors.toDouble()),
    );

    final List<FlSpot> scatterSpots = data.map(buildSpot).toList();
    final int? selectedIndex = selected == null
        ? null
        : data.indexWhere(
            (CorrelacionModel item) => item.repoName == selected.repoName,
          );

    final LineChartBarData scatterBar = LineChartBarData(
      spots: scatterSpots,
      showingIndicators: selectedIndex == null
          ? const <int>[]
          : <int>[selectedIndex],
      isCurved: false,
      color: Colors.transparent,
      dotData: FlDotData(
        show: true,
        getDotPainter:
            (FlSpot spot, double percent, LineChartBarData barData, int index) {
              final CorrelacionModel item = data[index];
              final bool isSelected = selectedIndex == index;
              final Color color = _resolveCorrelationDotColor(item);
              return FlDotCirclePainter(
                radius: isSelected ? 7 : 4.5,
                color: color.withValues(alpha: isSelected ? 0.95 : 0.72),
                strokeWidth: isSelected ? 2.4 : 1.2,
                strokeColor: isSelected ? Colors.white : color,
              );
            },
      ),
    );

    final double trendMinXRaw = minStarsValue;
    final double trendMaxXRaw = maxStarsValue;
    final double xLabelOffset = chartMinStars.remainder(1);
    final double yLabelOffset = chartMinContributors.remainder(1);
    final List<FlSpot> trendSpots = <FlSpot>[
      FlSpot(
        _scatterTransform(trendMinXRaw),
        _scatterTransform(expectedAt(trendMinXRaw)),
      ),
      FlSpot(
        _scatterTransform(trendMaxXRaw),
        _scatterTransform(expectedAt(trendMaxXRaw)),
      ),
    ];

    final LineChartBarData trendBar = LineChartBarData(
      spots: trendSpots,
      isCurved: false,
      color: const Color(0xFFEF4444),
      barWidth: 2,
      dotData: const FlDotData(show: false),
      dashArray: const <int>[8, 4],
    );

    return Padding(
      padding: const EdgeInsets.only(top: 20, right: 12),
      child: LineChart(
        LineChartData(
          minX: chartMinStars,
          maxX: chartMaxStars,
          minY: chartMinContributors,
          maxY: chartMaxContributors,
          clipData: const FlClipData.all(),
          lineTouchData: LineTouchData(
            enabled: true,
            handleBuiltInTouches: false,
            touchSpotThreshold: 18,
            touchCallback: (FlTouchEvent event, LineTouchResponse? response) {
              if (event is! FlTapUpEvent) {
                return;
              }
              final List<CorrelacionModel> candidates =
                  _correlationCandidatesFromResponse(response, data);
              setState(() {
                if (candidates.isEmpty) {
                  _scatterCollisionRepoNames = const <String>[];
                  return;
                }
                _scatterCollisionRepoNames = candidates
                    .map((CorrelacionModel item) => item.repoName)
                    .toList();
                if (!candidates.any(
                  (CorrelacionModel item) =>
                      item.repoName == _scatterSelectedRepoName,
                )) {
                  _scatterSelectedRepoName = candidates.first.repoName;
                }
              });
            },
            mouseCursorResolver:
                (FlTouchEvent event, LineTouchResponse? response) {
                  final bool onScatterPoint =
                      response?.lineBarSpots?.any(
                        (LineBarSpot spot) => spot.barIndex == 0,
                      ) ??
                      false;
                  return onScatterPoint
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.basic;
                },
            getTouchedSpotIndicator:
                (LineChartBarData barData, List<int> spotIndexes) {
                  if (!identical(barData, scatterBar)) {
                    return spotIndexes
                        .map(
                          (_) => TouchedSpotIndicatorData(
                            const FlLine(
                              color: Colors.transparent,
                              strokeWidth: 0,
                            ),
                            const FlDotData(show: false),
                          ),
                        )
                        .toList();
                  }
                  return spotIndexes
                      .map(
                        (int index) => TouchedSpotIndicatorData(
                          const FlLine(
                            color: Colors.transparent,
                            strokeWidth: 0,
                          ),
                          FlDotData(
                            show: true,
                            getDotPainter:
                                (
                                  FlSpot spot,
                                  double percent,
                                  LineChartBarData bar,
                                  int dotIndex,
                                ) {
                                  final Color color =
                                      _resolveCorrelationDotColor(data[index]);
                                  return FlDotCirclePainter(
                                    radius: 7,
                                    color: color,
                                    strokeWidth: 2.5,
                                    strokeColor: Colors.white,
                                  );
                                },
                          ),
                        ),
                      )
                      .toList();
                },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              axisNameWidget: const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Stars',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              axisNameSize: 35,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 42,
                interval: xInterval,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final String label = _formatLogAxisValueWithOffset(
                    value,
                    xLabelOffset,
                  );
                  if (label.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              axisNameWidget: const Text(
                'Contributors',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              axisNameSize: 35,
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 54,
                interval: yInterval,
                getTitlesWidget: (double value, TitleMeta meta) {
                  final String label = _formatLogAxisValueWithOffset(
                    value,
                    yLabelOffset,
                  );
                  if (label.isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Text(label, style: const TextStyle(fontSize: 10)),
                  );
                },
              ),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
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
            horizontalInterval: yInterval,
            verticalInterval: xInterval,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
            getDrawingVerticalLine: (_) =>
                FlLine(color: Colors.grey.shade200, strokeWidth: 1),
          ),
          lineBarsData: <LineChartBarData>[scatterBar, trendBar],
        ),
      ),
    );
  }

  String _shortRepoLabel(String fullRepoName) {
    final String compact = fullRepoName.split('/').last.trim();
    if (compact.length <= 22) {
      return compact;
    }
    return '${compact.substring(0, 19)}...';
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
      'rust': 'Rust',
      'ai/ml': 'AI/ML',
      'ai': 'AI',
      'llm': 'LLM',
    };
    return names[raw.toLowerCase().trim()] ?? raw;
  }

  // Calcular insight de frameworks
  String _getFrameworkInsightTitle() {
    final FrameworkCommitModel? leader = _frameworkInsightLeader;
    if (leader == null) {
      return 'Sin datos de frameworks';
    }
    return '${leader.framework} lidera los commits frontend en GitHub';
  }

  String _getFrameworkInsightDescription() {
    final FrameworkCommitModel? leader = _frameworkInsightLeader;
    if (leader == null) {
      return 'Sin base suficiente para resumir el liderazgo de frameworks.';
    }

    final FrameworkCommitModel? runnerUp = _frameworkInsightRunnerUp;
    if (runnerUp == null) {
      return '${_formatCompactInt(leader.commits2025)} commits en el periodo actual.';
    }

    final int gap = leader.commits2025 - runnerUp.commits2025;
    if (gap <= 0) {
      return '${_formatCompactInt(leader.commits2025)} commits en el periodo actual. Empate con ${runnerUp.framework}.';
    }
    return '${_formatCompactInt(leader.commits2025)} commits en el periodo actual. +${_formatCompactInt(gap)} vs ${runnerUp.framework}.';
  }

  FrameworkCommitModel? get _frameworkInsightLeader {
    if (frameworks.isEmpty) {
      return null;
    }
    final List<FrameworkCommitModel> ordered =
        List<FrameworkCommitModel>.from(frameworks)..sort((
          FrameworkCommitModel a,
          FrameworkCommitModel b,
        ) {
          final int byCommits = b.commits2025.compareTo(a.commits2025);
          if (byCommits != 0) {
            return byCommits;
          }
          return a.framework.toLowerCase().compareTo(b.framework.toLowerCase());
        });
    return ordered.first;
  }

  FrameworkCommitModel? get _frameworkInsightRunnerUp {
    if (frameworks.length < 2) {
      return null;
    }
    final List<FrameworkCommitModel> ordered =
        List<FrameworkCommitModel>.from(frameworks)..sort((
          FrameworkCommitModel a,
          FrameworkCommitModel b,
        ) {
          final int byCommits = b.commits2025.compareTo(a.commits2025);
          if (byCommits != 0) {
            return byCommits;
          }
          return a.framework.toLowerCase().compareTo(b.framework.toLowerCase());
        });
    return ordered[1];
  }

  String _getCorrelationInsightTitle() {
    final CorrelacionModel? outlier = _correlationInsightRepo;
    if (outlier != null) {
      return '${_formatRepoInsightName(outlier.repoName)} destaca por contributors por cada 1k stars';
    }
    return 'La correlaci\u00f3n stars-contributors se mantiene consistente';
  }

  String _getCorrelationInsightDescription() {
    final CorrelacionModel? outlier = _correlationInsightRepo;
    if (outlier != null) {
      return '${_formatCompactInt(outlier.contributors)} contributors, '
          '${_formatCompactInt(outlier.stars)} stars, '
          '${outlier.contributorsPer1kStars.toStringAsFixed(1)} contributors por cada 1k stars.';
    }
    return 'Correlaci\u00f3n Stars-Contributors: ${_calculateCorrelation().toStringAsFixed(2)}.';
  }

  CorrelacionModel? get _correlationInsightRepo {
    final CorrelacionModel? listOutlier = _resolveCorrelationOutlierFromList();
    if (listOutlier != null) {
      return listOutlier;
    }
    final GithubCorrelationHistorySummaryModel? summary =
        correlationHistory?.summary;
    return summary?.positiveOutlierRepo ?? summary?.topEngagementRepo;
  }

  CorrelacionModel? _resolveCorrelationOutlierFromList() {
    if (correlacion.isEmpty) {
      return null;
    }
    final List<CorrelacionModel> ordered = List<CorrelacionModel>.from(
      correlacion,
    )..sort((CorrelacionModel a, CorrelacionModel b) {
        final double scoreA = (a.outlierScore ?? a.contributorsPer1kStars);
        final double scoreB = (b.outlierScore ?? b.contributorsPer1kStars);
        final int byScore = scoreB.compareTo(scoreA);
        if (byScore != 0) {
          return byScore;
        }
        final int byContributors = b.contributors.compareTo(a.contributors);
        if (byContributors != 0) {
          return byContributors;
        }
        return b.stars.compareTo(a.stars);
      });
    return ordered.firstWhere(
      (CorrelacionModel item) => item.repoName.trim().isNotEmpty,
      orElse: () => ordered.first,
    );
  }

  String _formatRepoInsightName(String raw) {
    final List<String> segments = raw
        .split('/')
        .where((String segment) => segment.trim().isNotEmpty)
        .toList();
    if (segments.isEmpty) {
      return raw;
    }
    return segments.last.trim();
  }

  // Calcular coeficiente de correlacion de Pearson
  double _calculateCorrelation() {
    if (correlationHistory != null) {
      return correlationHistory!.summary.correlationValue;
    }
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

  FrameworkCommitModel? _leadingFramework() {
    if (frameworks.isEmpty) {
      return null;
    }
    final List<FrameworkCommitModel> ordered = List<FrameworkCommitModel>.from(
      frameworks,
    )..sort((a, b) => b.commits2025.compareTo(a.commits2025));
    return ordered.first;
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
    if (key.contains('next.js') || key.contains('nextjs')) {
      return 'assets/images/nextjs-logo.png';
    }
    if (key.contains('angular')) {
      return 'assets/images/angular_logo.png';
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
    if (key.contains('django')) {
      return 'assets/images/django-logo.png';
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
    if (key.contains('svelte')) {
      return 'assets/images/svelte-logo.png';
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
    if (key.contains('ai') ||
        key.contains('ml') ||
        key.contains('machine') ||
        key.contains('llm')) {
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
    if (key.contains('go') || key.contains('rust')) {
      return Icons.memory_rounded;
    }
    if (key.contains('angular') ||
        key.contains('react') ||
        key.contains('vue')) {
      return Icons.web_rounded;
    }
    return defaultIcon;
  }

  Color _resolveInsightColor(String raw) {
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
    if (key.contains('next.js') || key.contains('nextjs')) {
      return const Color(0xFF111827);
    }
    if (key.contains('angular')) {
      return const Color(0xFFDD0031);
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
    if (key.contains('django')) {
      return const Color(0xFF0B5B3C);
    }
    if (key.contains('spring')) {
      return const Color(0xFF6DB33F);
    }
    if (key.contains('laravel')) {
      return const Color(0xFFFF2D20);
    }
    if (key.contains('fastapi')) {
      return const Color(0xFF009688);
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
    if (key.contains('ai') || key.contains('ml') || key.contains('machine')) {
      return const Color(0xFF0EA5E9);
    }
    if (key.contains('svelte')) {
      return const Color(0xFFFF3E00);
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
    return const Color(0xFF2563EB);
  }

  Color _resolveFrameworkBarColor(String framework) {
    final String key = framework.trim().toLowerCase();
    if (key.contains('angular')) {
      return const Color(0xFFDD0031);
    }
    if (key.contains('react')) {
      return const Color(0xFF61DAFB);
    }
    if (key.contains('vue')) {
      return const Color(0xFF42B883);
    }
    if (key.contains('svelte')) {
      return const Color(0xFFFF3E00);
    }
    if (key.contains('next')) {
      return const Color(0xFF111827);
    }
    return const Color(0xFF2563EB);
  }

  Color _resolveFrameworkBadgeTextColor(Color accent) {
    if (accent.computeLuminance() >= 0.45) {
      final HSLColor hsl = HSLColor.fromColor(accent);
      return hsl
          .withLightness((hsl.lightness * 0.38).clamp(0.18, 0.32))
          .toColor();
    }
    return accent.withValues(alpha: 0.96);
  }

  String _formatCompactInt(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match match) => '${match[1]},',
    );
  }

  // Widget con imagen de logo o fallback de icono
  Widget _buildGithubInsightCard(
    String title,
    String description,
    Color accentColor, {
    String? imagePath,
    IconData fallbackIcon = Icons.code_rounded,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
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
              color: accentColor.withValues(alpha: 0.1),
            ),
            child: imagePath == null
                ? Icon(fallbackIcon, color: accentColor, size: 26)
                : ClipRRect(
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
                    color: Color(0xFF475569),
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

enum _GithubLenguajesSort { repos, porcentaje }

enum _GithubFrameworkMetric { commits, contributors, prs, issues, releases }

enum _GithubFrameworkView { current, variation }

enum _GithubFrameworkOrder { highest, growth, drop }

enum _GithubScatterFocus {
  all,
  topStars,
  topContributors,
  topEngagement,
  outliers,
}

enum _GithubScatterDetailMode { basic, advanced }

class _DetailMetric {
  final String label;
  final String value;

  const _DetailMetric({required this.label, required this.value});
}
