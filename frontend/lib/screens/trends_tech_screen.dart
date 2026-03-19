import 'dart:convert';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/github_models.dart';
import '../models/reddit_models.dart';
import '../models/run_manifest_models.dart';
import '../models/stackoverflow_models.dart';
import '../models/technology_profile_models.dart';
import '../models/trend_history_models.dart';
import '../providers/app_providers.dart';
import '../router/app_router.dart';
import '../utils/tech_slug.dart';
import '../widgets/chart_card.dart';
import '../widgets/chart_legend.dart';
import '../widgets/degraded_state_card.dart';
import '../widgets/loading_skeleton.dart';

class TrendsTechScreen extends ConsumerWidget {
  final String technology;

  const TrendsTechScreen({super.key, required this.technology});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<DataLoadState<GithubDashboardData>> githubAsync = ref
        .watch(githubDashboardProvider);
    final AsyncValue<DataLoadState<StackOverflowDashboardData>> soAsync = ref
        .watch(stackoverflowDashboardProvider);
    final AsyncValue<DataLoadState<RedditDashboardData>> redditAsync = ref
        .watch(redditDashboardProvider);
    final AsyncValue<DataLoadState<TrendTemporalViewData>> trendAsync = ref
        .watch(trendTemporalProvider);
    final AsyncValue<DataLoadState<RunManifestPublic>> manifestAsync = ref
        .watch(runManifestProvider);
    final AsyncValue<DataLoadState<TechnologyProfilesPayload>> profilesAsync =
        ref.watch(technologyProfilesProvider);

    final DataLoadState<GithubDashboardData>? githubState =
        githubAsync.asData?.value;
    final DataLoadState<StackOverflowDashboardData>? soState =
        soAsync.asData?.value;
    final DataLoadState<RedditDashboardData>? redditState =
        redditAsync.asData?.value;
    final DataLoadState<TrendTemporalViewData>? trendState =
        trendAsync.asData?.value;
    final DataLoadState<RunManifestPublic>? manifestState =
        manifestAsync.asData?.value;
    final DataLoadState<TechnologyProfilesPayload>? profilesState =
        profilesAsync.asData?.value;
    final RunManifestPublic? manifest = manifestState?.data;

    final String rawSlug = Uri.decodeComponent(technology);
    final String normalizedSlug = normalizeSlug(rawSlug);
    final TechnologyProfilesPayload? profilesPayload = profilesState?.data;
    final TechnologyProfile? profile =
        _resolveProfile(profilesPayload, normalizedSlug);
    final bool usingBridge = profile != null && profilesPayload != null;
    final String techName =
        (profile != null && profile.displayName.trim().isNotEmpty)
            ? profile.displayName
            : _displayName(rawSlug);
    final _TechSummary summary = _buildSummary(
      tech: rawSlug,
      githubState: githubState,
      soState: soState,
      redditState: redditState,
      trendState: trendState,
    );

    final bool awaitingBridge = profilesAsync.isLoading && !usingBridge;
    final bool legacyLoading =
        !usingBridge &&
        (githubAsync.isLoading || soAsync.isLoading || trendAsync.isLoading) &&
        summary.githubMainValue == 0 &&
        summary.stackMainValue == 0;

    if (awaitingBridge || legacyLoading) {
      return _buildLoadingSkeleton(context, techName: techName);
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 980;
        final double horizontalPadding = compact ? 16 : 24;
        final List<Widget> contentChildren;
        if (profile != null && profilesPayload != null) {
          contentChildren = _buildBridgeWidgets(
            context: context,
            compact: compact,
            profile: profile,
            profilesPayload: profilesPayload,
            manifest: manifest,
            techName: techName,
          );
        } else {
          contentChildren = _buildLegacyWidgets(
            context: context,
            compact: compact,
            techName: techName,
            summary: summary,
            manifest: manifest,
            bridgeMessage: profilesState?.message,
          );
        }
        final Widget content = Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            20,
            horizontalPadding,
            28,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: contentChildren,
          ),
        );

        final bool hasScrollable = Scrollable.maybeOf(context) != null;
        if (hasScrollable) {
          return content;
        }
        return SingleChildScrollView(child: content);
      },
    );
  }

  Widget _buildBreadcrumb(BuildContext context, TextTheme textTheme) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        TextButton.icon(
          onPressed: () => context.go(AppRoutes.home),
          icon: const Icon(Icons.arrow_back_rounded, size: 18),
          label: const Text('Inicio'),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            minimumSize: const Size(0, 0),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            foregroundColor: const Color(0xFF1D4ED8),
            backgroundColor: const Color(0xFFEFF6FF),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Color(0xFFBFDBFE)),
            ),
            textStyle: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          '> Análisis por tecnología',
          style: textTheme.labelLarge?.copyWith(
            color: const Color(0xFF64748B),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildResponsiveHeroHeader({
    required Widget primary,
    required Widget secondary,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final Widget scaledSecondary = FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.topRight,
          child: secondary,
        );

        if (constraints.maxWidth < 980) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              primary,
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: scaledSecondary,
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(child: primary),
            const SizedBox(width: 16),
            Flexible(
              child: Align(
                alignment: Alignment.topRight,
                child: scaledSecondary,
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildBridgeWidgets({
    required BuildContext context,
    required bool compact,
    required TechnologyProfile profile,
    required TechnologyProfilesPayload profilesPayload,
    required RunManifestPublic? manifest,
    required String techName,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final String latestLabel = _formatDate(profilesPayload.latestSnapshotDate);
    final String prevLabel = _formatDate(profilesPayload.previousSnapshotDate);
    final String comparisonLabel = _buildComparisonLabel(
      prevLabel,
      latestLabel,
    );
    final String trendDeltaLabel =
        _buildDeltaLabel(profile.deltaScore, unit: 'pts');
    const String weightsTooltip =
        'Puntaje total = GH 40% · SO 35% · RD 25%.';
    final String rankingDeltaLabel = _formatRankingDelta(profile.deltaRanking);
    final List<_InsightLine> insights =
        _buildInsights(profile.summaryInsights);
    final bool isDegraded = manifest?.degradedMode == true;

    final Widget headerBlock = _buildResponsiveHeroHeader(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            techName,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: compact ? 28 : 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            buildAnalysisPeriodLabel(manifest),
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            buildLastUpdatedLabel(manifest),
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
          if (comparisonLabel.isNotEmpty)
            Text(
              comparisonLabel,
              style: textTheme.bodySmall?.copyWith(
                color: const Color(0xFF64748B),
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              _buildMetaChip(
                label: 'Ranking global #${profile.rankingActual}',
                color: const Color(0xFF1D4ED8),
              ),
              _buildMetaChip(
                label: rankingDeltaLabel,
                color: _rankingDeltaColor(profile.deltaRanking),
              ),
              _buildMetaChipWithInfo(
                label: trendDeltaLabel,
                color: _deltaColor(profile.deltaScore),
                tooltip: weightsTooltip,
              ),
            ],
          ),
        ],
      ),
      secondary: _TrendScoreChip(score: profile.trendScoreActual),
    );

    return <Widget>[
        _buildBreadcrumb(context, textTheme),
      const SizedBox(height: 8),
      headerBlock,
      if (isDegraded)
        const DegradedStateCard(
          message:
              'Modo degradado: algunos datasets no estuvieron disponibles.',
        ),
      const SizedBox(height: 20),
      ChartCard(
        title: 'Evolución del aporte por fuente',
        subtitle:
            'Cómo cambia el aporte de GitHub, StackOverflow y Reddit en cada corte.',
        height: compact ? 300 : 340,
        chart: _buildHistoryChart(profile, compact: compact),
        semanticLabel: _buildHistoryChartAltText(profile),
      ),
      const SizedBox(height: 20),
      Text(
        'Contribución por fuente',
        style: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: <Widget>[
          _SourceCard(
            color: const Color(0xFF2563EB),
            code: 'GH',
            title: profile.githubSummary.displayName,
            mainValue: _formatScore(profile.githubSummary.scoreActual),
            deltaLabel: _buildDeltaLabel(profile.githubSummary.deltaScore),
            contextText: _sourceContext(profile.githubSummary, prevLabel),
            metricA: 'Prev',
            valueA: _formatScore(profile.githubSummary.scorePrev),
            metricB: 'Delta',
            valueB: _formatDelta(profile.githubSummary.deltaScore),
            available: profile.githubSummary.available,
          ),
          _SourceCard(
            color: const Color(0xFFF97316),
            code: 'SO',
            title: profile.stackoverflowSummary.displayName,
            mainValue: _formatScore(profile.stackoverflowSummary.scoreActual),
            deltaLabel: _buildDeltaLabel(profile.stackoverflowSummary.deltaScore),
            contextText: _sourceContext(profile.stackoverflowSummary, prevLabel),
            metricA: 'Prev',
            valueA: _formatScore(profile.stackoverflowSummary.scorePrev),
            metricB: 'Delta',
            valueB: _formatDelta(profile.stackoverflowSummary.deltaScore),
            available: profile.stackoverflowSummary.available,
          ),
          _SourceCard(
            color: const Color(0xFFEF4444),
            code: 'RD',
            title: profile.redditSummary.displayName,
            mainValue: _formatScore(profile.redditSummary.scoreActual),
            deltaLabel: _buildDeltaLabel(profile.redditSummary.deltaScore),
            contextText: _sourceContext(profile.redditSummary, prevLabel),
            metricA: 'Prev',
            valueA: _formatScore(profile.redditSummary.scorePrev),
            metricB: 'Delta',
            valueB: _formatDelta(profile.redditSummary.deltaScore),
            available: profile.redditSummary.available,
          ),
        ],
      ),
      const SizedBox(height: 22),
      Text(
        'Hallazgos principales',
        style: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      _InsightPanel(insights: insights),
    ];
  }

  List<Widget> _buildLegacyWidgets({
    required BuildContext context,
    required bool compact,
    required String techName,
    required _TechSummary summary,
    required RunManifestPublic? manifest,
    required String? bridgeMessage,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool showBridgeWarning =
        bridgeMessage != null && bridgeMessage.trim().isNotEmpty;
    final bool isDegraded = manifest?.degradedMode == true;
    final Widget headerBlock = _buildResponsiveHeroHeader(
      primary: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            techName,
            style: textTheme.headlineMedium?.copyWith(
              fontSize: compact ? 28 : 32,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            buildAnalysisPeriodLabel(manifest),
            style: textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            buildLastUpdatedLabel(manifest),
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
      secondary: _TrendScoreChip(score: summary.trendScore),
    );

    return <Widget>[
      _buildBreadcrumb(context, textTheme),
      const SizedBox(height: 8),
      headerBlock,
      if (showBridgeWarning)
        const DegradedStateCard(
          message:
              'Bridge no disponible. Usando datos legacy (CSV) para mantener el análisis.',
          severity: DegradedSeverity.cached,
        ),
      if (isDegraded)
        const DegradedStateCard(
          message:
              'Modo degradado: algunos datasets no estuvieron disponibles.',
        ),
      const SizedBox(height: 20),
      ChartCard(
        title: 'Evolución del aporte por fuente (fallback)',
        subtitle: 'Serie sintetizada para continuidad visual.',
        badgeText: 'Fallback',
        height: compact ? 280 : 320,
        chart: _buildLineChart(summary),
      ),
      const SizedBox(height: 20),
      Text(
        'Contribución por fuente',
        style: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 16,
        runSpacing: 16,
        children: <Widget>[
          _SourceCard(
            color: const Color(0xFF2563EB),
            code: 'GH',
            title: 'GitHub',
            mainValue: summary.githubMainValueLabel,
            deltaLabel: '',
            contextText: 'Repositorios en tendencia. Señal técnica más estable.',
            metricA: 'Top',
            valueA: summary.githubTopLabel,
            metricB: 'Stars',
            valueB: summary.githubStarsLabel,
          ),
          _SourceCard(
            color: const Color(0xFFF97316),
            code: 'SO',
            title: 'StackOverflow',
            mainValue: summary.stackMainValueLabel,
            deltaLabel: '',
            contextText: 'Preguntas recientes. Calidad de discusión en la fuente.',
            metricA: 'Aceptación',
            valueA: summary.stackAcceptanceLabel,
            metricB: 'Top',
            valueB: summary.stackTopLabel,
          ),
          _SourceCard(
            color: const Color(0xFFEF4444),
            code: 'RD',
            title: 'Reddit',
            mainValue: summary.redditMainValueLabel,
            deltaLabel: '',
            contextText: summary.redditUnavailable
                ? 'Fuente no disponible. Continuidad visual con datos cacheados.'
                : 'Pulso de la comunidad. Tema dominante: ${summary.redditTopicLabel}.',
            metricA: 'Sentimiento',
            valueA: summary.redditSentimentLabel,
            metricB: 'Tema',
            valueB: summary.redditTopicLabel,
            available: !summary.redditUnavailable,
          ),
        ],
      ),
      const SizedBox(height: 22),
      Text(
        'Hallazgos principales',
        style: textTheme.titleLarge?.copyWith(
          color: const Color(0xFF0F172A),
          fontWeight: FontWeight.w700,
        ),
      ),
      const SizedBox(height: 12),
      _InsightPanel(insights: summary.insights),
    ];
  }

  Widget _buildHistoryChart(
    TechnologyProfile profile, {
    required bool compact,
  }) {
    final List<TechnologySourceHistoryPoint> history = profile.sourceHistory;
    if (history.length < 2) {
      return Center(
        child: Text(
          'Histórico insuficiente para graficar.',
          style: TextStyle(
            fontSize: 13,
            color: const Color(0xFF64748B),
          ),
        ),
      );
    }

    final bool showGithub = profile.githubSummary.available;
    final bool showStack = profile.stackoverflowSummary.available;
    final bool showReddit = profile.redditSummary.available;
    if (!showGithub && !showStack && !showReddit) {
      return Center(
        child: Text(
          'No hay fuentes disponibles para graficar.',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF64748B),
          ),
        ),
      );
    }
    final double maxValue = history.fold<double>(
      0,
      (double max, TechnologySourceHistoryPoint point) {
        final double localMax = <double>[
          showGithub ? point.githubScore : 0,
          showStack ? point.stackOverflowScore : 0,
          showReddit ? point.redditScore : 0,
        ].reduce((double a, double b) => a > b ? a : b);
        return localMax > max ? localMax : max;
      },
    );
    final double maxY =
        maxValue <= 0 ? 100 : ((maxValue * 1.1) / 10).ceilToDouble() * 10;
    final double maxX = (history.length - 1).toDouble();
    final int labelInterval =
        history.length <= 6 ? 1 : (history.length / 5).ceil();

    final List<LineChartBarData> series = <LineChartBarData>[
      if (showGithub)
        LineChartBarData(
          spots: _buildHistorySeries(history, (point) => point.githubScore),
          isCurved: true,
          color: const Color(0xFF2563EB),
          barWidth: 3,
          dotData: const FlDotData(show: false),
        ),
      if (showStack)
        LineChartBarData(
          spots: _buildHistorySeries(
            history,
            (point) => point.stackOverflowScore,
          ),
          isCurved: true,
          color: const Color(0xFFF97316),
          barWidth: 3,
          dotData: const FlDotData(show: false),
          dashArray: const <int>[6, 4],
        ),
      if (showReddit)
        LineChartBarData(
          spots: _buildHistorySeries(history, (point) => point.redditScore),
          isCurved: true,
          color: const Color(0xFFEF4444),
          barWidth: 3,
          dotData: const FlDotData(show: false),
        ),
    ];

    return Column(
      children: <Widget>[
        Expanded(
          child: LineChart(
            LineChartData(
              minY: 0,
              maxY: maxY,
              minX: 0,
              maxX: maxX,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (double _) =>
                    FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
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
                    reservedSize: 36,
                    interval: maxY / 4,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      return Text(
                        value.toInt().toString(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF64748B),
                        ),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    interval: 1,
                    getTitlesWidget: (double value, TitleMeta meta) {
                      if (value < 0 || value > maxX) {
                        return const SizedBox.shrink();
                      }
                      final int index = value.round();
                      if (index % labelInterval != 0 &&
                          index != history.length - 1) {
                        return const SizedBox.shrink();
                      }
                      final String label =
                          _formatShortDate(history[index].date);
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: series,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ChartLegend(
          items: <ChartLegendItemData>[
            if (showGithub)
              const ChartLegendItemData(
                label: 'GitHub',
                color: Color(0xFF2563EB),
              ),
            if (showStack)
              const ChartLegendItemData(
                label: 'StackOverflow',
                color: Color(0xFFF97316),
              ),
            if (showReddit)
              const ChartLegendItemData(
                label: 'Reddit',
                color: Color(0xFFEF4444),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildLoadingSkeleton(
    BuildContext context, {
    required String techName,
  }) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 980;
        final double horizontalPadding = compact ? 16 : 24;
        final double chartHeight = compact ? 300 : 340;
        final TextTheme textTheme = Theme.of(context).textTheme;
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
                const SkeletonLine(width: 180, height: 12),
                const SizedBox(height: 8),
                _buildResponsiveHeroHeader(
                  primary: Text(
                    techName,
                    style: textTheme.titleLarge?.copyWith(
                      color: const Color(0xFF0F172A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  secondary: const SkeletonPill(width: 72, height: 32),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: const <Widget>[
                    SkeletonPill(width: 90, height: 24),
                    SkeletonPill(width: 110, height: 24),
                    SkeletonPill(width: 120, height: 24),
                  ],
                ),
                const SizedBox(height: 20),
                ChartSkeletonCard(
                  chartHeight: chartHeight,
                  legendItems: 3,
                  showBadge: true,
                ),
                const SizedBox(height: 20),
                const SkeletonLine(width: 200, height: 16),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: <Widget>[
                    _buildSourceSkeletonCard(),
                    _buildSourceSkeletonCard(),
                    _buildSourceSkeletonCard(),
                  ],
                ),
                const SizedBox(height: 22),
                const SkeletonLine(width: 200, height: 16),
                const SizedBox(height: 12),
                _buildInsightsSkeletonCard(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceSkeletonCard() {
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const <Widget>[
              SkeletonLine(width: 120, height: 14),
              SizedBox(height: 10),
              SkeletonBox(
                height: 20,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
              SizedBox(height: 12),
              SkeletonLine(width: 160, height: 12),
              SizedBox(height: 10),
              SkeletonLine(width: 120, height: 12),
            ],
          ),
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
            SkeletonLine(width: 220, height: 12),
            SizedBox(height: 10),
            SkeletonLine(width: 180, height: 12),
            SizedBox(height: 10),
            SkeletonLine(width: 200, height: 12),
          ],
        ),
      ),
    );
  }

  String _buildHistoryChartAltText(TechnologyProfile profile) {
    final List<String> sources = <String>[
      if (profile.githubSummary.available) 'GitHub',
      if (profile.stackoverflowSummary.available) 'StackOverflow',
      if (profile.redditSummary.available) 'Reddit',
    ];
    final String sourcesLabel =
        sources.isEmpty ? 'sin fuentes disponibles' : sources.join(', ');
    return 'Grafico de lineas por fuente. Fuentes: $sourcesLabel. '
        'Eje X: snapshots. Eje Y: score por fuente.';
  }

  static List<FlSpot> _buildHistorySeries(
    List<TechnologySourceHistoryPoint> history,
    double Function(TechnologySourceHistoryPoint point) selector,
  ) {
    return history
        .asMap()
        .entries
        .map(
          (MapEntry<int, TechnologySourceHistoryPoint> entry) =>
              FlSpot(entry.key.toDouble(), selector(entry.value)),
        )
        .toList();
  }

  static TechnologyProfile? _resolveProfile(
    TechnologyProfilesPayload? payload,
    String slug,
  ) {
    if (payload == null || slug.isEmpty) {
      return null;
    }
    for (final TechnologyProfile profile in payload.profiles) {
      if (normalizeSlug(profile.slug) == slug) {
        return profile;
      }
    }
    for (final TechnologyProfile profile in payload.profiles) {
      if (normalizeSlug(profile.displayName) == slug) {
        return profile;
      }
    }
    return null;
  }

  static String _formatDate(String? value) {
    final DateTime? parsed = DateTime.tryParse(value ?? '');
    if (parsed == null) {
      return '';
    }
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static String _buildComparisonLabel(
    String prevLabel,
    String latestLabel,
  ) {
    if (prevLabel.isEmpty || latestLabel.isEmpty) {
      return '';
    }
    return 'Comparado (UTC): $prevLabel -> $latestLabel';
  }

  static String _formatShortDate(String value) {
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month';
  }

  static String _formatScore(double? value) {
    if (value == null) {
      return '-';
    }
    return value.toStringAsFixed(2);
  }

  static String _formatDelta(double? value) {
    if (value == null) {
      return '-';
    }
    final String sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
  }

  static String _buildDeltaLabel(
    double? delta, {
    String unit = '',
  }) {
    if (delta == null) {
      return 'Sin histórico previo';
    }
    final String suffix = unit.isNotEmpty ? ' $unit' : '';
    return '${_formatDelta(delta)}$suffix vs corrida previa';
  }

  static String _formatRankingDelta(int? delta) {
    if (delta == null) {
      return 'Sin histórico previo';
    }
    if (delta == 0) {
      return 'Tendencia estable';
    }
    if (delta > 0) {
      return 'Sube ${delta.abs()} posiciones';
    }
    return 'Baja ${delta.abs()} posiciones';
  }

  static Color _deltaColor(double? delta) {
    if (delta == null) {
      return const Color(0xFF64748B);
    }
    if (delta > 0) {
      return const Color(0xFF16A34A);
    }
    if (delta < 0) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFFF59E0B);
  }

  static Color _rankingDeltaColor(int? delta) {
    if (delta == null) {
      return const Color(0xFF64748B);
    }
    if (delta > 0) {
      return const Color(0xFF16A34A);
    }
    if (delta < 0) {
      return const Color(0xFFDC2626);
    }
    return const Color(0xFFF59E0B);
  }

  static String _sanitizeLabel(String value) {
    if (!value.contains('Ã') && !value.contains('Â')) {
      return value;
    }
    try {
      return utf8.decode(latin1.encode(value));
    } catch (_) {
      return value;
    }
  }

  static String _compactInsightBody(String value) {
    final String clean = _sanitizeLabel(value).trim();
    if (clean.isEmpty) {
      return clean;
    }
    String compact = clean;
    final int sentenceBreak = clean.indexOf(RegExp(r'[.!?]'));
    if (sentenceBreak > 0 && sentenceBreak < 120) {
      compact = clean.substring(0, sentenceBreak + 1);
    }
    const int maxLength = 120;
    if (compact.length > maxLength) {
      compact = '${compact.substring(0, maxLength - 3).trimRight()}...';
    }
    return compact;
  }

  static String _normalizeMomentumLabel(String value) {
    final String clean = _sanitizeLabel(value).trim();
    if (clean.isEmpty) {
      return clean;
    }
    final String lower = clean.toLowerCase();
    if (lower.contains('gana 0') ||
        lower.contains('gana 0.0') ||
        lower.contains('mantiene')) {
      return 'Mantiene su posición frente a la corrida previa.';
    }
    return clean;
  }

  static List<_InsightLine> _buildInsights(
    TechnologySummaryInsights summary,
  ) {
    final List<_InsightLine> insights = <_InsightLine>[];
    final TechnologyDominantSourceInsight? dominant = summary.dominantSource;
    if (dominant != null) {
      insights.add(
        _InsightLine(
          title: 'Fuente dominante',
          body: _compactInsightBody(dominant.label),
        ),
      );
    }
    insights.add(
      _InsightLine(
        title: 'Cobertura',
        body: _compactInsightBody(summary.coverage.label),
      ),
    );
    insights.add(
      _InsightLine(
        title: 'Momentum',
        body: _compactInsightBody(
          _normalizeMomentumLabel(summary.momentum.label),
        ),
      ),
    );
    return insights;
  }

  static String _sourceContext(
    TechnologySourceSummary summary,
    String prevLabel,
  ) {
    if (!summary.available) {
      return 'Fuente no disponible en esta corrida.';
    }
    if (summary.deltaScore == null || prevLabel.isEmpty) {
      return 'Sin histórico previo para comparar.';
    }
    if (summary.deltaScore == 0) {
      return 'Se mantiene estable vs la corrida anterior.';
    }
    if (summary.deltaScore! > 0) {
      return 'Aporta crecimiento frente a la corrida anterior.';
    }
    return 'Pierde tracción frente a la corrida anterior.';
  }

  Widget _buildMetaChip({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildMetaChipWithInfo({
    required String label,
    required Color color,
    required String tooltip,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 6),
            _buildTapTooltip(
              message: tooltip,
              child: Icon(
                Icons.info_outline_rounded,
                size: 14,
                color: color,
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildTapTooltip({required String message, required Widget child}) {
      final GlobalKey<TooltipState> tooltipKey = GlobalKey<TooltipState>();
      return Tooltip(
        key: tooltipKey,
        message: message,
        waitDuration: const Duration(milliseconds: 200),
        showDuration: const Duration(seconds: 2),
        child: GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => tooltipKey.currentState?.ensureTooltipVisible(),
          child: child,
        ),
      );
    }
  
    Widget _buildLineChart(_TechSummary summary) {
    final List<FlSpot> githubSpots = _buildSeries(summary.githubSeries);
    final List<FlSpot> stackSpots = _buildSeries(summary.stackSeries);
    final List<FlSpot> redditSpots = _buildSeries(summary.redditSeries);

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: 5,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (double _) =>
              FlLine(color: const Color(0xFFE2E8F0), strokeWidth: 1),
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
              reservedSize: 34,
              interval: 20,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  value.toInt().toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                );
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              getTitlesWidget: (double value, TitleMeta meta) {
                const List<String> labels = <String>[
                  'Mar',
                  'May',
                  'Jul',
                  'Sep',
                  'Nov',
                  'Feb',
                ];
                if (value < 0 || value > labels.length - 1) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    labels[value.toInt()],
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF64748B),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: <LineChartBarData>[
          LineChartBarData(
            spots: githubSpots,
            isCurved: true,
            color: const Color(0xFF2563EB),
            barWidth: 3,
            dotData: const FlDotData(show: false),
          ),
          LineChartBarData(
            spots: stackSpots,
            isCurved: true,
            color: const Color(0xFFF97316),
            barWidth: 3,
            dotData: const FlDotData(show: false),
            dashArray: const <int>[6, 4],
          ),
          if (!summary.redditUnavailable)
            LineChartBarData(
              spots: redditSpots,
              isCurved: true,
              color: const Color(0xFFEF4444),
              barWidth: 3,
              dotData: const FlDotData(show: false),
            ),
        ],
      ),
    );
  }

  static List<FlSpot> _buildSeries(List<double> values) {
    return values
        .asMap()
        .entries
        .map(
          (MapEntry<int, double> item) =>
              FlSpot(item.key.toDouble(), item.value),
        )
        .toList();
  }

  static String _displayName(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return 'Tecnología';
    }
    final String normalized = normalizeSlug(trimmed);
    if (normalized == 'ai-ml') {
      return 'AI/ML';
    }
    if (normalized == 'c-sharp') {
      return 'C#';
    }
    if (normalized == 'c-plus-plus') {
      return 'C++';
    }
    final String lower = trimmed.toLowerCase();
    if (lower == 'javascript') {
      return 'JavaScript';
    }
    if (lower == 'typescript') {
      return 'TypeScript';
    }
    if (trimmed.contains('-')) {
      final List<String> parts = trimmed.split('-');
      return parts
          .where((String part) => part.isNotEmpty)
          .map(
            (String part) =>
                '${part[0].toUpperCase()}${part.substring(1)}',
          )
          .join(' ');
    }
    if (trimmed.length == 1) {
      return trimmed.toUpperCase();
    }
    return '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  static _TechSummary _buildSummary({
    required String tech,
    required DataLoadState<GithubDashboardData>? githubState,
    required DataLoadState<StackOverflowDashboardData>? soState,
    required DataLoadState<RedditDashboardData>? redditState,
    required DataLoadState<TrendTemporalViewData>? trendState,
  }) {
    final String normalizedTech = normalizeKey(tech);

    final GithubDashboardData? github = githubState?.data;
    final StackOverflowDashboardData? stack = soState?.data;
    final RedditDashboardData? reddit = redditState?.data;
    final TrendTemporalViewData? trend = trendState?.data;

    final int githubRepos =
        github?.lenguajes
            .where(
              (LenguajeModel item) =>
                  normalizeKey(item.lenguaje) == normalizedTech,
            )
            .fold<int>(
              0,
              (int acc, LenguajeModel item) => acc + item.reposCount,
            ) ??
        0;
    final int githubFallbackRepos =
        github?.lenguajes.fold<int>(
          0,
          (int acc, LenguajeModel item) => acc + item.reposCount,
        ) ??
        0;
    final int githubMain = githubRepos > 0 ? githubRepos : githubFallbackRepos;
    final String githubTopLabel = github?.lenguajes.isNotEmpty == true
        ? github!.lenguajes.first.lenguaje
        : '-';
    final int githubStars =
        github?.correlacion.fold<int>(
          0,
          (int acc, CorrelacionModel item) => acc + item.stars,
        ) ??
        0;

    final int stackMain =
        stack?.volumen
            .where(
              (VolumenPreguntasModel item) =>
                  normalizeKey(item.lenguaje) == normalizedTech,
            )
            .fold<int>(
              0,
              (int acc, VolumenPreguntasModel item) => acc + item.preguntas,
            ) ??
        0;
    final int stackFallbackMain =
        stack?.volumen.fold<int>(
          0,
          (int acc, VolumenPreguntasModel item) => acc + item.preguntas,
        ) ??
        0;
    final int soQuestions = stackMain > 0 ? stackMain : stackFallbackMain;
    double soAcceptance = 0;
    if (stack != null && stack.aceptacion.isNotEmpty) {
      final double sumAcceptance = stack.aceptacion
          .map((TasaAceptacionModel item) => item.tasaPct)
          .reduce((double a, double b) => a + b);
      soAcceptance = sumAcceptance / stack.aceptacion.length;
    }
    final String soTop = stack?.volumen.isNotEmpty == true
        ? stack!.volumen.first.lenguaje
        : '-';

    final bool redditUnavailable =
        reddit == null ||
        redditState?.isError == true ||
        redditState?.isDegraded == true;
    InterseccionModel? redditMatch;
    if (reddit != null) {
      for (final InterseccionModel item in reddit.interseccion) {
        if (normalizeKey(item.tecnologia) == normalizedTech) {
          redditMatch = item;
          break;
        }
      }
    }

    final int redditMentions = reddit?.temas.isNotEmpty == true
        ? reddit!.temas.first.menciones
        : 0;
    double redditSentiment = 0;
    if (reddit != null && reddit.sentimiento.isNotEmpty) {
      final double sentimentSum = reddit.sentimiento
          .map((SentimientoModel item) => item.porcentajePositivo)
          .reduce((double a, double b) => a + b);
      redditSentiment = sentimentSum / reddit.sentimiento.length;
    }
    final String redditTopic = reddit?.temas.isNotEmpty == true
        ? reddit!.temas.first.tema
        : '-';

    final double trendScore =
        trend?.items
            .where(
              (TrendTopEntry entry) {
                final String entryKey =
                    entry.slug.isNotEmpty ? entry.slug : entry.tecnologia;
                return normalizeKey(entryKey) == normalizedTech;
              },
            )
            .map((TrendTopEntry entry) => entry.trendScore)
            .cast<double?>()
            .firstWhere((double? item) => item != null, orElse: () => null) ??
        (trend?.items.isNotEmpty == true ? trend!.items.first.trendScore : 0);

    final List<double> normalized = _normalizeSeries(
      githubMain.toDouble(),
      soQuestions.toDouble(),
      redditUnavailable ? 0 : redditMentions.toDouble(),
    );

    final List<_InsightLine> insights = <_InsightLine>[
      _InsightLine(
        title: 'Dominio en actividad técnica',
        body:
            'GitHub ${_compactInt(githubMain)}, StackOverflow ${_compactInt(soQuestions)}.',
      ),
      _InsightLine(
        title: 'Calidad de discusión',
        body: 'Aceptación media en StackOverflow: ${soAcceptance.toStringAsFixed(1)}%.',
      ),
      _InsightLine(
        title: redditUnavailable
            ? 'Reddit temporalmente no disponible'
            : 'Pulso de comunidad',
        body: redditUnavailable
            ? 'Reddit no disponible. Fallback con caché.'
            : 'Tema: $redditTopic (${_compactInt(redditMentions)} menciones).',
      ),
    ];

    return _TechSummary(
      githubMainValue: githubMain,
      githubMainValueLabel: _compactInt(githubMain),
      githubTopLabel: githubTopLabel,
      githubStarsLabel: _compactInt(githubStars),
      stackMainValue: soQuestions,
      stackMainValueLabel: _compactInt(soQuestions),
      stackAcceptanceLabel: '${soAcceptance.toStringAsFixed(0)}%',
      stackTopLabel: _displayName(soTop),
      redditMainValueLabel: redditMatch?.rankingReddit != null
          ? '#${redditMatch!.rankingReddit}'
          : _compactInt(redditMentions),
      redditSentimentLabel: '${redditSentiment.toStringAsFixed(0)}%',
      redditTopicLabel: redditTopic,
      trendScore: trendScore,
      redditUnavailable: redditUnavailable,
      githubSeries: _buildProgressiveSeries(normalized[0]),
      stackSeries: _buildProgressiveSeries(normalized[1]),
      redditSeries: _buildProgressiveSeries(normalized[2]),
      insights: insights,
    );
  }

  static List<double> _normalizeSeries(double a, double b, double c) {
    final double maxValue = <double>[
      a,
      b,
      c,
      1,
    ].reduce((double prev, double next) => prev > next ? prev : next);
    return <double>[
      (a / maxValue) * 100,
      (b / maxValue) * 100,
      (c / maxValue) * 100,
    ];
  }

  static List<double> _buildProgressiveSeries(double finalValue) {
    final List<double> multipliers = <double>[
      0.36,
      0.48,
      0.61,
      0.74,
      0.86,
      1.0,
    ];
    return multipliers
        .map((double ratio) => (finalValue * ratio).clamp(0, 100).toDouble())
        .toList();
  }

  static String _compactInt(int value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toString();
  }
}

class _TrendScoreChip extends StatelessWidget {
  final double score;

  const _TrendScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    final bool strong = score >= 70;
    final bool medium = score >= 45 && score < 70;
    final Color chipColor = strong
        ? const Color(0xFF16A34A)
        : (medium ? const Color(0xFFF59E0B) : const Color(0xFFDC2626));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          const Text(
            'PUNTAJE DE TENDENCIA',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
              letterSpacing: 0.6,
            ),
          ),
          Text(
            score.toStringAsFixed(2),
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: chipColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceCard extends StatelessWidget {
  final Color color;
  final String code;
  final String title;
  final String mainValue;
  final String deltaLabel;
  final String contextText;
  final String metricA;
  final String valueA;
  final String metricB;
  final String valueB;
  final bool available;

  const _SourceCard({
    required this.color,
    required this.code,
    required this.title,
    required this.mainValue,
    required this.deltaLabel,
    required this.contextText,
    required this.metricA,
    required this.valueA,
    required this.metricB,
    required this.valueB,
    this.available = true,
  });

  @override
  Widget build(BuildContext context) {
    final Color accent = available ? color : const Color(0xFFCBD5F5);
    final Color titleColor =
        available ? const Color(0xFF0F172A) : const Color(0xFF64748B);
    final Color subtitleColor =
        available ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    const double contextHeight = 36;
    final String contextCopy = contextText.trim();

    return Container(
      width: 330,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border(left: BorderSide(color: accent, width: 4)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 5),
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
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$code · $title',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: titleColor,
                  ),
                ),
              ),
              if (!available)
                _buildStatusChip('No disponible', const Color(0xFFDC2626))
              else if (deltaLabel.isNotEmpty)
                _buildStatusChip(deltaLabel, accent),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            available ? mainValue : '—',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: titleColor,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: contextHeight,
            child: Text(
              contextCopy.isEmpty ? ' ' : contextCopy,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: subtitleColor),
            ),
          ),
          const SizedBox(height: 10),
          const Divider(height: 1),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '$metricA: $valueA',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$metricB: $valueB',
                  style: TextStyle(
                    fontSize: 13,
                    color: subtitleColor,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _InsightPanel extends StatelessWidget {
  final List<_InsightLine> insights;

  const _InsightPanel({required this.insights});

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: insights.isEmpty
            ? <Widget>[
                Text(
                  'Sin insights disponibles.',
                  style: textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF64748B),
                  ),
                ),
              ]
            : insights
                .map(
                  (_InsightLine line) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(top: 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                line.title,
                                style: textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                line.body,
                                style: textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF475569),
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }
}

class _InsightLine {
  final String title;
  final String body;

  const _InsightLine({required this.title, required this.body});
}

class _TechSummary {
  final int githubMainValue;
  final String githubMainValueLabel;
  final String githubTopLabel;
  final String githubStarsLabel;
  final int stackMainValue;
  final String stackMainValueLabel;
  final String stackAcceptanceLabel;
  final String stackTopLabel;
  final String redditMainValueLabel;
  final String redditSentimentLabel;
  final String redditTopicLabel;
  final double trendScore;
  final bool redditUnavailable;
  final List<double> githubSeries;
  final List<double> stackSeries;
  final List<double> redditSeries;
  final List<_InsightLine> insights;

  const _TechSummary({
    required this.githubMainValue,
    required this.githubMainValueLabel,
    required this.githubTopLabel,
    required this.githubStarsLabel,
    required this.stackMainValue,
    required this.stackMainValueLabel,
    required this.stackAcceptanceLabel,
    required this.stackTopLabel,
    required this.redditMainValueLabel,
    required this.redditSentimentLabel,
    required this.redditTopicLabel,
    required this.trendScore,
    required this.redditUnavailable,
    required this.githubSeries,
    required this.stackSeries,
    required this.redditSeries,
    required this.insights,
  });
}





