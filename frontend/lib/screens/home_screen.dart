import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:go_router/go_router.dart';
import '../models/dashboard_domain_models.dart';
import '../models/data_load_state.dart';
import '../models/github_models.dart';
import '../models/home_highlights_models.dart';
import '../models/reddit_models.dart';
import '../models/run_manifest_models.dart';
import '../models/stackoverflow_models.dart';
import '../models/trend_history_models.dart';
import '../providers/app_providers.dart';
import '../router/app_router.dart';
import '../utils/tech_slug.dart';
import '../widgets/degraded_state_card.dart';
import '../widgets/chart_inline_filter.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final DataLoadState<GithubDashboardData>? githubState = ref
        .watch(githubDashboardProvider)
        .asData
        ?.value;
    final DataLoadState<StackOverflowDashboardData>? stackState = ref
        .watch(stackoverflowDashboardProvider)
        .asData
        ?.value;
    final DataLoadState<RedditDashboardData>? redditState = ref
        .watch(redditDashboardProvider)
        .asData
        ?.value;
    final DataLoadState<RunManifestPublic>? manifestState = ref
        .watch(runManifestProvider)
        .asData
        ?.value;
    final int githubTop10Repos =
        githubState?.data?.lenguajes.fold<int>(
          0,
          (int total, LenguajeModel row) => total + row.reposCount,
        ) ??
        0;
    final int? githubRepos =
        (manifestState?.data?.totalReposClasificables ?? 0) > 0
        ? manifestState?.data?.totalReposClasificables
        : githubTop10Repos;
    final int? stackQuestions = stackState?.data?.volumen.fold<int>(
      0,
      (int total, VolumenPreguntasModel row) => total + row.preguntas,
    );
    final int? redditMentions = redditState?.data?.temas.fold<int>(
      0,
      (int total, TemasEmergentesModel row) => total + row.menciones,
    );

    return _HomeScrollRestore(
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 760;
        final double horizontalPadding = compact ? 16 : 28;
        final double contentWidth =
            constraints.maxWidth - (horizontalPadding * 2);
        final double kpiCardWidth = contentWidth < 540
            ? contentWidth
            : compact
            ? (contentWidth - 16) / 2
            : 232;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            24,
            horizontalPadding,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tech Trends',
                style: textTheme.headlineLarge?.copyWith(
                  fontSize: compact ? 32 : 40,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Análisis integral de tendencias tecnológicas',
                style: textTheme.titleMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 28),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _buildKpiCardFA(
                    width: kpiCardWidth,
                    icon: FontAwesomeIcons.github,
                    value: _formatMetric(githubRepos),
                    label: 'Repositorios clasificables',
                    color: Colors.blue,
                  ),
                  _buildKpiCardFA(
                    width: kpiCardWidth,
                    icon: FontAwesomeIcons.stackOverflow,
                    value: _formatMetric(stackQuestions),
                    label: 'Preguntas Procesadas',
                    color: const Color(0xFFF48024),
                  ),
                  _buildKpiCardFA(
                    width: kpiCardWidth,
                    icon: FontAwesomeIcons.reddit,
                    value: _formatMetric(redditMentions),
                    label: 'Menciones en Reddit',
                    color: const Color(0xFFFF4500),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Insights clave',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    SizedBox(height: 20),
                    _DynamicHomeInsights(),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              const _TrendTemporalBridgeCard(),

              const SizedBox(height: 28),

              Text(
                'Sobre el Dashboard',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 20),

              Wrap(
                spacing: 24,
                runSpacing: 24,
                children: [
                  _buildInfoCardFA(
                    context: context,
                    icon: FontAwesomeIcons.github,
                    title: 'GitHub Data',
                    description:
                        'Análisis de repos nuevos y commits del corte actual, con ranking de lenguajes y frameworks.',
                    color: Colors.blue,
                    route: AppRoutes.github,
                  ),
                  _buildInfoCardFA(
                    context: context,
                    icon: FontAwesomeIcons.stackOverflow,
                    title: 'StackOverflow Data',
                    description:
                        'Actividad por tecnología a lo largo del tiempo: volumen, variación y tasa de aceptación.',
                    color: const Color(0xFFF48024),
                    route: AppRoutes.stackoverflow,
                  ),
                  _buildInfoCardFA(
                    context: context,
                    icon: FontAwesomeIcons.reddit,
                    title: 'Reddit Data',
                    description:
                        'Sentimiento y crecimiento de temas en la comunidad, con cambios vs corrida previa.',
                    color: const Color(0xFFFF4500),
                    route: AppRoutes.reddit,
                  ),
                ],
              ),

              const SizedBox(height: 36),

              Text(
                'Integrantes del Equipo',
                style: textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              _buildTeamMemberFA(
                'Samir Caizapasto',
                'Líder del proyecto · Arquitectura, ETL GitHub y dashboards',
                FontAwesomeIcons.github,
                Colors.blue,
              ),
              _buildTeamMemberFA(
                'Andrés Salinas',
                'Ingeniería de datos · ETL StackOverflow y dashboards',
                FontAwesomeIcons.stackOverflow,
                const Color(0xFFF48024),
              ),
              _buildTeamMemberFA(
                'Mateo Mayorga',
                'Ingeniería de datos · ETL Reddit y visualización',
                FontAwesomeIcons.reddit,
                const Color(0xFFFF4500),
              ),

              const SizedBox(height: 36),
            ],
          ),
        );
      },
    ),
    );
  }

  Widget _buildKpiCardFA({
    required double width,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 32, color: Colors.white.withValues(alpha: 0.9)),
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
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ],
      ),
    );
  }

  String _formatMetric(int? value) {
    if (value == null) {
      return '--';
    }
    final String digits = value.toString();
    return digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  Widget _buildInfoCardFA({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required String route,
  }) {
    return Container(
      width: 290,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border(top: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
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
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: const Color(0xFF475569),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: () => context.go(route),
            icon: Icon(Icons.arrow_forward_rounded, color: color, size: 18),
            label: Text(
              'Ver dashboard',
              style: TextStyle(color: color, fontWeight: FontWeight.w700),
            ),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              foregroundColor: color,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTeamMemberFA(
    String name,
    String role,
    IconData icon,
    Color color,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 420;
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: FaIcon(icon, color: color, size: 18),
                ),
                const SizedBox(height: 6),
                Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: const TextStyle(color: Color(0xFF475569)),
                  softWrap: true,
                ),
              ],
            );
          }

          return Row(
            children: [
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.15),
                child: FaIcon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      role,
                      style: const TextStyle(color: Color(0xFF475569)),
                      softWrap: true,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _HomeScrollRestore extends ConsumerStatefulWidget {
  final Widget child;

  const _HomeScrollRestore({required this.child});

  @override
  ConsumerState<_HomeScrollRestore> createState() =>
      _HomeScrollRestoreState();
}

class _HomeScrollRestoreState extends ConsumerState<_HomeScrollRestore> {
  static const int _maxRestoreAttempts = 30;
  int _restoreAttempts = 0;
  bool _restoreScheduled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleRestore();
  }

  @override
  Widget build(BuildContext context) {
    _scheduleRestore();
    return widget.child;
  }

  void _scheduleRestore() {
    if (_restoreScheduled) {
      return;
    }
    final double? pendingOffset = ref.read(homeReturnScrollOffsetProvider);
    if (pendingOffset == null) {
      return;
    }
    _restoreScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _restoreScheduled = false;
      _attemptRestore();
    });
  }

  void _attemptRestore() {
    if (!mounted) {
      return;
    }
    final double? pendingOffset = ref.read(homeReturnScrollOffsetProvider);
    if (pendingOffset == null) {
      _restoreAttempts = 0;
      return;
    }
    final ScrollController? controller =
        PrimaryScrollController.maybeOf(context);
    if (controller == null || !controller.hasClients) {
      _retryRestore();
      return;
    }
    final ScrollPosition position = controller.position;
    final double max = position.maxScrollExtent;
    if (max <= 0 && pendingOffset > 0) {
      _retryRestore();
      return;
    }
    if (max < pendingOffset) {
      _retryRestore();
      return;
    }
    final double target =
        pendingOffset.clamp(position.minScrollExtent, max);
    controller.jumpTo(target);
    ref.read(homeReturnScrollOffsetProvider.notifier).state = null;
    _restoreAttempts = 0;
  }

  void _retryRestore() {
    if (_restoreAttempts >= _maxRestoreAttempts) {
      ref.read(homeReturnScrollOffsetProvider.notifier).state = null;
      _restoreAttempts = 0;
      return;
    }
    _restoreAttempts += 1;
    Future.delayed(const Duration(milliseconds: 150), _attemptRestore);
  }
}

class _DynamicHomeInsights extends ConsumerWidget {
  const _DynamicHomeInsights();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DataLoadState<HomeHighlightsPayloadModel>? homeHighlightsState = ref
        .watch(homeHighlightsProvider)
        .asData
        ?.value;
    final DataLoadState<GithubDashboardData>? githubState = ref
        .watch(githubDashboardProvider)
        .asData
        ?.value;
    final DataLoadState<StackOverflowDashboardData>? stackState = ref
        .watch(stackoverflowDashboardProvider)
        .asData
        ?.value;
    final DataLoadState<RedditDashboardData>? redditState = ref
        .watch(redditDashboardProvider)
        .asData
        ?.value;
    final DataLoadState<RunManifestPublic>? manifestState = ref
        .watch(runManifestProvider)
        .asData
        ?.value;
    final DataLoadState<TrendTemporalViewData>? trendState = ref
        .watch(trendTemporalProvider)
        .asData
        ?.value;
    final String? comparisonDate = _formatUtcDateShort(
      trendState?.data?.previousSnapshotDate ??
          trendState?.data?.latestSnapshotDate,
    );

    final HomeHighlightsPayloadModel? highlightsPayload =
        homeHighlightsState?.data;
    final List<_InsightItem> insights =
        (highlightsPayload != null && highlightsPayload.highlights.isNotEmpty)
        ? _buildCanonicalInsights(
            highlightsPayload.highlights,
            comparisonDate: comparisonDate,
          )
        : _buildLegacyInsights(
            github: githubState?.data,
            stack: stackState?.data,
            reddit: redditState?.data,
            manifest: manifestState?.data,
            comparisonDate: comparisonDate,
          );

    if (insights.isEmpty) {
      return const Text(
        'Insights no disponibles por ahora.',
        style: TextStyle(fontSize: 14, color: Color(0xFF475569)),
      );
    }

    return Column(
      children: <Widget>[
        for (int i = 0; i < insights.length; i++) ...<Widget>[
          _HomeInsightTile(item: insights[i]),
          if (i < insights.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  List<_InsightItem> _buildCanonicalInsights(
    List<HomeHighlightModel> highlights, {
    required String? comparisonDate,
  }) {
    return highlights
        .map((highlight) => _buildInsightFromHighlight(
              highlight,
              comparisonDate: comparisonDate,
            ))
        .toList();
  }

  _InsightItem _buildInsightFromHighlight(
    HomeHighlightModel highlight, {
    required String? comparisonDate,
  }) {
    final String kind =
        '${highlight.dashboard}:${highlight.graph}:${highlight.signal}';
    switch (kind) {
      case 'github:1:leader':
        final String language = _displayName(
          _payloadString(highlight, 'lenguaje', fallback: highlight.entity),
        );
        final int reposCount = _payloadInt(highlight, 'repos_count');
        final double sharePct = _payloadDouble(highlight, 'share_pct');
        return _InsightItem(
          title: '$language lidera los repositorios nuevos en GitHub',
          description:
              '${_formatInt(reposCount)} repos nuevos; ${_formatPct(sharePct)} del total.',
          color: _colorForKeyword(language),
          assetPath: _logoForKeyword(language),
          fallbackIcon: _fallbackIconForKeyword(
            language,
            fallback: Icons.account_tree_rounded,
          ),
        );
      case 'github:2:leader':
        final String framework = _displayName(
          _payloadString(highlight, 'framework', fallback: highlight.entity),
        );
        final int commits = _payloadInt(highlight, 'commits_2025');
        final int? deltaCommits =
            _payloadNullableInt(highlight, 'delta_commits');
        final double? growthPct = _payloadNullableDouble(
          highlight,
          'growth_pct',
        );
        final String trendDirection = _payloadString(
          highlight,
          'trend_direction',
        );
        return _InsightItem(
          title: '$framework lidera los commits frontend en GitHub',
          description: _buildFrameworkLeaderDescription(
            commits,
            deltaCommits: deltaCommits,
            growthPct: growthPct,
            trendDirection: trendDirection,
            comparisonDate: comparisonDate,
          ),
          color: _colorForKeyword(framework),
          assetPath: _logoForKeyword(framework),
          fallbackIcon: _fallbackIconForKeyword(
            framework,
            fallback: Icons.code_rounded,
          ),
        );
      case 'github:3:positive_outlier_repo':
        final String repoName = _payloadString(
          highlight,
          'repo_name',
          fallback: highlight.entity,
        );
        final String language = _payloadString(highlight, 'language');
        final double contributorsPer1kStars = _payloadDouble(
          highlight,
          'contributors_per_1k_stars',
        );
        return _InsightItem(
          title:
              '$repoName destaca en contributors frente a repos de su tamaño',
          description:
              '${contributorsPer1kStars.toStringAsFixed(1)} contributors por 1k stars.',
          color: _colorForKeyword(language.isEmpty ? repoName : language),
          assetPath: _logoForKeyword(language.isEmpty ? repoName : language),
          fallbackIcon: _fallbackIconForKeyword(
            language.isEmpty ? repoName : language,
            fallback: Icons.insights_rounded,
          ),
        );
      case 'stackoverflow:1:leader':
        final String language = _displayName(
          _payloadString(highlight, 'lenguaje', fallback: highlight.entity),
        );
        final int preguntas = _payloadInt(highlight, 'preguntas');
        final double sharePct = _payloadDouble(highlight, 'share_pct');
        return _InsightItem(
          title: '$language lidera el volumen en StackOverflow',
          description:
              '${_formatInt(preguntas)} preguntas nuevas; ${_formatPct(sharePct)} del total.',
          color: _colorForKeyword(language),
          assetPath: _logoForKeyword(language),
          fallbackIcon: _fallbackIconForKeyword(
            language,
            fallback: Icons.forum_rounded,
          ),
        );
      case 'stackoverflow:2:confidence_leader':
        final String tech = _displayName(
          _payloadString(highlight, 'tecnologia', fallback: highlight.entity),
        );
        final double tasa = _payloadDouble(highlight, 'tasa_aceptacion_pct');
        final int total = _payloadInt(highlight, 'total_preguntas');
        return _InsightItem(
          title: '$tech combina aceptación y muestra sólida',
          description:
              '${_formatPct(tasa)} aceptación sobre ${_formatInt(total)} preguntas.',
          color: _colorForKeyword(tech),
          assetPath: _logoForKeyword(tech),
          fallbackIcon: _fallbackIconForKeyword(
            tech,
            fallback: Icons.verified_rounded,
          ),
        );
      case 'stackoverflow:3:largest_relative_drop':
        final String tech = _displayName(
          _payloadString(highlight, 'tecnologia', fallback: highlight.entity),
        );
        final int startValue = _payloadInt(highlight, 'start_value');
        final int endValue = _payloadInt(highlight, 'end_value');
        return _InsightItem(
          title: '$tech registra la caída relativa más pronunciada',
          description:
              'De ${_formatInt(startValue)} a ${_formatInt(endValue)} preguntas mensuales.',
          color: _colorForKeyword(tech),
          assetPath: _logoForKeyword(tech),
          fallbackIcon: _fallbackIconForKeyword(
            tech,
            fallback: Icons.trending_down_rounded,
          ),
        );
      case 'reddit:1:positive_leader':
        final String framework = _displayName(
          _payloadString(highlight, 'framework', fallback: highlight.entity),
        );
        final double positivePct = _payloadDouble(
          highlight,
          'porcentaje_positivo',
        );
        final int mentions = _payloadInt(highlight, 'total_menciones');
        final String sampleText = mentions < 10 ? ' Muestra acotada.' : '';
        return _InsightItem(
          title: '$framework registra el sentimiento más positivo en Reddit',
          description:
              '${_formatPct(positivePct)} positivo sobre ${_formatInt(mentions)} menciones.$sampleText',
          color: _colorForKeyword(framework),
          assetPath: _logoForKeyword(framework),
          fallbackIcon: _fallbackIconForKeyword(
            framework,
            fallback: Icons.sentiment_satisfied_alt_rounded,
          ),
        );
      case 'reddit:2:leader_topic':
        final String topic = _normalizeTopic(
          _payloadString(highlight, 'tema', fallback: highlight.entity),
        );
        final int mentions = _payloadInt(highlight, 'menciones');
        final int? deltaMentions =
            _payloadNullableInt(highlight, 'delta_menciones');
        final double? growthPct = _payloadNullableDouble(
          highlight,
          'growth_pct',
        );
        final String trendDirection = _payloadString(
          highlight,
          'trend_direction',
        );
        return _InsightItem(
          title: '$topic lidera la conversación en Reddit',
          description: _buildTopicLeaderDescription(
            mentions,
            deltaMentions: deltaMentions,
            growthPct: growthPct,
            trendDirection: trendDirection,
            comparisonDate: comparisonDate,
          ),
          color: _colorForKeyword(topic),
          assetPath: _logoForKeyword(topic),
          fallbackIcon: _fallbackIconForKeyword(
            topic,
            fallback: Icons.auto_awesome_rounded,
          ),
        );
      case 'reddit:3:closest_alignment':
        final String tech = _displayName(
          _payloadString(highlight, 'tecnologia', fallback: highlight.entity),
        );
        final int gap = _payloadInt(highlight, 'brecha_abs');
        return _InsightItem(
          title: '$tech muestra la menor brecha entre GitHub y Reddit',
          description:
              'Brecha de ${_formatInt(gap)} posiciones entre rankings.',
          color: _colorForKeyword(tech),
          assetPath: _logoForKeyword(tech),
          fallbackIcon: _fallbackIconForKeyword(
            tech,
            fallback: Icons.compare_arrows_rounded,
          ),
        );
      default:
        final String entity = _displayName(highlight.entity);
        return _InsightItem(
          title: '$entity destaca en ${_displayDashboard(highlight.dashboard)}',
          description: 'Hallazgo desde summaries canónicos.',
          color: _colorForKeyword(entity),
          assetPath: _logoForKeyword(entity),
          fallbackIcon: _fallbackIconForKeyword(
            entity,
            fallback: Icons.lightbulb_rounded,
          ),
        );
    }
  }

  List<_InsightItem> _buildLegacyInsights({
    required GithubDashboardData? github,
    required StackOverflowDashboardData? stack,
    required RedditDashboardData? reddit,
    required RunManifestPublic? manifest,
    required String? comparisonDate,
  }) {
    final List<_InsightItem> items = <_InsightItem>[];

    final LenguajeModel? topGithubLang = _topLanguage(github?.lenguajes);
    final VolumenPreguntasModel? topStackLang = _topStackLanguage(
      stack?.volumen,
    );
    final VolumenPreguntasModel? stackForGithub = _findStackByLanguage(
      stack?.volumen,
      topGithubLang?.lenguaje,
    );
    final String headlineTech =
        topGithubLang?.lenguaje ?? topStackLang?.lenguaje ?? 'Tecnología';
    final int reposCount = topGithubLang?.reposCount ?? 0;
    final int questionCount =
        stackForGithub?.preguntas ?? topStackLang?.preguntas ?? 0;

    final bool sameTop =
        topGithubLang != null &&
        topStackLang != null &&
        _normalize(topGithubLang.lenguaje) == _normalize(topStackLang.lenguaje);

    String topTechTitle = '${_displayName(headlineTech)} lidera GitHub';
    if (sameTop) {
      topTechTitle =
          '${_displayName(headlineTech)} lidera GitHub y StackOverflow';
    } else if (topGithubLang != null && topStackLang != null) {
      topTechTitle =
          '${_displayName(topGithubLang.lenguaje)} lidera GitHub y ${_displayName(topStackLang.lenguaje)} lidera StackOverflow';
    }

    final List<String> topTechParts = <String>[];
    if (reposCount > 0) {
      topTechParts.add('#1 en repositorios (${_formatInt(reposCount)})');
    }
    if (questionCount > 0) {
      topTechParts.add('líder en preguntas (${_formatInt(questionCount)})');
    }
    items.add(
      _InsightItem(
        title: topTechTitle,
        description: topTechParts.isEmpty
            ? 'Actividad alta en los datos actuales.'
            : topTechParts.join(' y '),
        color: _colorForKeyword(headlineTech),
        assetPath: _logoForKeyword(headlineTech),
        fallbackIcon: _fallbackIconForKeyword(
          headlineTech,
          fallback: Icons.trending_up_rounded,
        ),
      ),
    );

    final FrameworkCommitModel? topFramework = _topFramework(
      github?.frameworks,
    );
    final FrameworkCommitModel? secondFramework = _secondFramework(
      github?.frameworks,
    );
    final String periodText = _periodLabel(manifest);
    if (topFramework != null) {
      final String frameworkName = _displayName(topFramework.framework);
      final String secondName = secondFramework == null
          ? ''
          : ' - por encima de ${_displayName(secondFramework.framework)}';
      items.add(
        _InsightItem(
          title: '$frameworkName lidera los commits frontend en GitHub',
          description:
              '${_buildFrameworkLeaderDescription(
                topFramework.commits2025,
                deltaCommits: topFramework.deltaCommits,
                growthPct: topFramework.growthPct,
                trendDirection: topFramework.trendDirection,
                periodLabel: periodText,
                comparisonDate: comparisonDate,
              )}$secondName',
          color: _colorForKeyword(frameworkName),
          assetPath: _logoForKeyword(frameworkName),
          fallbackIcon: _fallbackIconForKeyword(
            frameworkName,
            fallback: Icons.code_rounded,
          ),
        ),
      );
    }

    final TemasEmergentesModel? topTopic = _topTopic(reddit?.temas);
    final TemasEmergentesModel? secondTopic = _secondTopic(reddit?.temas);
    if (topTopic != null) {
      final double ratio = (secondTopic != null && secondTopic.menciones > 0)
          ? topTopic.menciones / secondTopic.menciones
          : 0;
      final String ratioText = ratio > 0
          ? ' - ${ratio.toStringAsFixed(1)}x sobre el segundo tema'
          : '';
      final String topicName = _normalizeTopic(topTopic.tema);
      items.add(
        _InsightItem(
          title: '$topicName es el tema más activo en Reddit',
          description: _buildTopicLeaderDescription(
            topTopic.menciones,
            deltaMentions: topTopic.deltaMenciones,
            growthPct: topTopic.growthPct,
            trendDirection: topTopic.trendDirection,
            suffix: ratioText,
            comparisonDate: comparisonDate,
          ),
          color: _colorForKeyword(topicName),
          assetPath: _logoForKeyword(topicName),
          fallbackIcon: _fallbackIconForKeyword(
            topicName,
            fallback: Icons.auto_awesome_rounded,
          ),
        ),
      );
    } else {
      items.add(
        const _InsightItem(
          title: 'Reddit en modo degradado',
          description:
              'Sin datos recientes de temas. Se mantiene respaldo operativo.',
          color: Color(0xFFD97706),
          fallbackIcon: Icons.warning_amber_rounded,
        ),
      );
    }

    return items;
  }

  static String _displayDashboard(String dashboard) {
    switch (dashboard.toLowerCase()) {
      case 'github':
        return 'GitHub';
      case 'reddit':
        return 'Reddit';
      case 'stackoverflow':
        return 'StackOverflow';
      default:
        return 'el dashboard';
    }
  }

  static String _payloadString(
    HomeHighlightModel highlight,
    String key, {
    String fallback = '',
  }) {
    final String value = highlight.payload[key]?.toString().trim() ?? '';
    return value.isEmpty ? fallback : value;
  }

  static String? _formatUtcDateShort(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }

  static int _payloadInt(HomeHighlightModel highlight, String key) {
    return int.tryParse(highlight.payload[key]?.toString() ?? '') ?? 0;
  }

  static int? _payloadNullableInt(HomeHighlightModel highlight, String key) {
    return int.tryParse(highlight.payload[key]?.toString() ?? '');
  }

  static double _payloadDouble(HomeHighlightModel highlight, String key) {
    return double.tryParse(highlight.payload[key]?.toString() ?? '') ?? 0.0;
  }

  static double? _payloadNullableDouble(HomeHighlightModel highlight, String key) {
    return double.tryParse(highlight.payload[key]?.toString() ?? '');
  }

  static LenguajeModel? _topLanguage(List<LenguajeModel>? rows) {
    if (rows == null || rows.isEmpty) return null;
    final List<LenguajeModel> copy = List<LenguajeModel>.from(rows)
      ..sort((a, b) => b.reposCount.compareTo(a.reposCount));
    return copy.first;
  }

  static VolumenPreguntasModel? _topStackLanguage(
    List<VolumenPreguntasModel>? rows,
  ) {
    if (rows == null || rows.isEmpty) return null;
    final List<VolumenPreguntasModel> copy = List<VolumenPreguntasModel>.from(
      rows,
    )..sort((a, b) => b.preguntas.compareTo(a.preguntas));
    return copy.first;
  }

  static VolumenPreguntasModel? _findStackByLanguage(
    List<VolumenPreguntasModel>? rows,
    String? language,
  ) {
    if (rows == null || rows.isEmpty || language == null || language.isEmpty) {
      return null;
    }
    final String target = _normalize(language);
    for (final VolumenPreguntasModel row in rows) {
      if (_normalize(row.lenguaje) == target) {
        return row;
      }
    }
    return null;
  }

  static FrameworkCommitModel? _topFramework(List<FrameworkCommitModel>? rows) {
    if (rows == null || rows.isEmpty) return null;
    final List<FrameworkCommitModel> copy = List<FrameworkCommitModel>.from(
      rows,
    )..sort((a, b) => b.commits2025.compareTo(a.commits2025));
    return copy.first;
  }

  static FrameworkCommitModel? _secondFramework(
    List<FrameworkCommitModel>? rows,
  ) {
    if (rows == null || rows.length < 2) return null;
    final List<FrameworkCommitModel> copy = List<FrameworkCommitModel>.from(
      rows,
    )..sort((a, b) => b.commits2025.compareTo(a.commits2025));
    return copy[1];
  }

  static TemasEmergentesModel? _topTopic(List<TemasEmergentesModel>? rows) {
    if (rows == null || rows.isEmpty) return null;
    final List<TemasEmergentesModel> copy = List<TemasEmergentesModel>.from(
      rows,
    )..sort((a, b) => b.menciones.compareTo(a.menciones));
    return copy.first;
  }

  static TemasEmergentesModel? _secondTopic(List<TemasEmergentesModel>? rows) {
    if (rows == null || rows.length < 2) return null;
    final List<TemasEmergentesModel> copy = List<TemasEmergentesModel>.from(
      rows,
    )..sort((a, b) => b.menciones.compareTo(a.menciones));
    return copy[1];
  }

  static String _periodLabel(RunManifestPublic? manifest) {
    if (manifest == null) return 'los últimos 12 meses';
    final DateTime? start = DateTime.tryParse(manifest.sourceWindowStartUtc);
    final DateTime? end = DateTime.tryParse(manifest.sourceWindowEndUtc);
    if (start == null || end == null) return 'los últimos 12 meses';
    if (start.year == end.year) return 'el periodo ${start.year}';
    return 'el periodo ${start.year}-${end.year}';
  }

  static String _normalize(String value) {
    return value.toLowerCase().replaceAll(' ', '');
  }

  static String _displayName(String value) {
    if (value.isEmpty) return 'Tecnología';
    final String lower = value.toLowerCase();
    const Map<String, String> aliases = <String, String>{
      'ai/ml': 'AI/ML',
      'javascript': 'JavaScript',
      'typescript': 'TypeScript',
      'vue 3': 'Vue 3',
      'reactjs': 'React',
    };
    if (aliases.containsKey(lower)) {
      return aliases[lower]!;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  static String _normalizeTopic(String value) {
    return value
        .replaceAll('IA/Machine Learning', 'AI/ML')
        .replaceAll('IA', 'AI');
  }

  static String _formatInt(int value) {
    return value.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );
  }

  static String _formatPct(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  static String _buildFrameworkLeaderDescription(
    int commits, {
    int? deltaCommits,
    double? growthPct,
    String? trendDirection,
    String? comparisonDate,
    String? periodLabel,
  }) {
    final String base = commits > 0
        ? '${_formatInt(commits)} commits en ${periodLabel ?? 'el periodo actual'}'
        : 'Actividad reciente en commits';
    final String trendText = _buildDeltaTrendLabel(
      deltaValue: deltaCommits,
      growthPct: growthPct,
      trendDirection: trendDirection,
      comparisonDate: comparisonDate,
    );
    return trendText.isEmpty ? '$base.' : '$base; $trendText.';
  }

  static String _buildTopicLeaderDescription(
    int mentions, {
    int? deltaMentions,
    double? growthPct,
    String? trendDirection,
    String? comparisonDate,
    String suffix = '',
  }) {
    final String base = mentions > 0
        ? '${_formatInt(mentions)} menciones en el periodo actual'
        : 'Actividad reciente en menciones';
    final String trendText = _buildDeltaTrendLabel(
      deltaValue: deltaMentions,
      growthPct: growthPct,
      trendDirection: trendDirection,
      comparisonDate: comparisonDate,
    );
    final List<String> extras = <String>[];
    if (trendText.isNotEmpty) {
      extras.add(trendText);
    }
    if (suffix.trim().isNotEmpty) {
      extras.add(suffix.trim().replaceFirst(RegExp(r'^-\\s*'), ''));
    }
    if (extras.isEmpty) {
      return '$base.';
    }
    return '$base; ${extras.join('; ')}.';
  }

  static String _buildDeltaTrendLabel({
    int? deltaValue,
    double? growthPct,
    String? trendDirection,
    String? comparisonDate,
  }) {
    final String dateSuffix = comparisonDate == null || comparisonDate.isEmpty
        ? ''
        : ' (UTC $comparisonDate)';
    if (deltaValue != null) {
      if (deltaValue == 0) {
        return 'Tendencia estable vs corrida previa$dateSuffix';
      }
      if (deltaValue > 0) {
        return 'Tendencia aumentando vs corrida previa$dateSuffix';
      }
      return 'Tendencia disminuyendo vs corrida previa$dateSuffix';
    }
    if (growthPct != null && growthPct.abs() >= 0.01) {
      if (growthPct > 0) {
        return 'Tendencia aumentando vs corrida previa$dateSuffix';
      }
      if (growthPct < 0) {
        return 'Tendencia disminuyendo vs corrida previa$dateSuffix';
      }
      return 'Tendencia estable vs corrida previa$dateSuffix';
    }
    final String trendLabel = _trendLabel(trendDirection);
    return trendLabel.isEmpty
        ? ''
        : 'Tendencia $trendLabel vs corrida previa$dateSuffix';
  }

  static String _trendLabel(String? raw) {
    final String key = raw?.toLowerCase().trim() ?? '';
    switch (key) {
      case 'creciendo':
        return 'aumentando';
      case 'cayendo':
        return 'disminuyendo';
      case 'estable':
        return 'estable';
      default:
        return '';
    }
  }

  static Color _colorForKeyword(String keyword) {
    final String key = keyword.toLowerCase();
    if (key.contains('python')) return const Color(0xFF3776AB);
    if (key.contains('typescript')) return const Color(0xFF3178C6);
    if (key.contains('javascript')) return const Color(0xFFEAB308);
    if (key.contains('react')) return const Color(0xFF61DAFB);
    if (key.contains('vue')) return const Color(0xFF42B883);
    if (key.contains('next.js') || key.contains('nextjs')) {
      return const Color(0xFF111827);
    }
    if (key.contains('angular')) return const Color(0xFFDD0031);
    if (key.contains('java') && !key.contains('javascript')) {
      return const Color(0xFFEA580C);
    }
    if (key.contains('c#') || key.contains('csharp')) {
      return const Color(0xFF8B5CF6);
    }
    if (key.contains('c++') || key.contains('cpp')) {
      return const Color(0xFF0EA5E9);
    }
    if (key.contains('django')) return const Color(0xFF0B5B3C);
    if (key.contains('spring')) return const Color(0xFF6DB33F);
    if (key.contains('laravel')) return const Color(0xFFFF2D20);
    if (key.contains('fastapi')) return const Color(0xFF009688);
    if (key.contains('kotlin')) return const Color(0xFF7C3AED);
    if (key.contains('php')) return const Color(0xFF777BB4);
    if (key.contains('rust')) return const Color(0xFFCE422B);
    if (key.contains('go')) return const Color(0xFF00ADD8);
    if (key.contains('ai') || key.contains('ml') || key.contains('machine')) {
      return const Color(0xFF0EA5E9);
    }
    if (key.contains('svelte')) return const Color(0xFFFF3E00);
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

  static String? _logoForKeyword(String keyword) {
    final String key = keyword.toLowerCase();
    if (key.contains('python')) return 'assets/images/python_logo.png';
    if (key.contains('react')) return 'assets/images/React-logo.png';
    if (key.contains('vue')) return 'assets/images/Vue-logo.png';
    if (key.contains('typescript')) return 'assets/images/TypeScript-logo.png';
    if (key.contains('javascript')) return 'assets/images/JavaScript-logo.png';
    if (key.contains('next.js') || key.contains('nextjs')) {
      return 'assets/images/nextjs-logo.png';
    }
    if (key.contains('angular')) return 'assets/images/angular_logo.png';
    if (key.contains('java') && !key.contains('javascript')) {
      return 'assets/images/Java-logo.png';
    }
    if (key.contains('c#') || key.contains('csharp')) {
      return 'assets/images/csharp-logo.png';
    }
    if (key.contains('c++') || key.contains('cpp')) {
      return 'assets/images/cpp-logo.png';
    }
    if (key.contains('django')) return 'assets/images/django-logo.png';
    if (key.contains('spring')) return 'assets/images/Spring-logo.png';
    if (key.contains('laravel')) return 'assets/images/Laravel-logo.png';
    if (key.contains('fastapi')) return 'assets/images/FastAPI-logo.png';
    if (key.contains('kotlin')) return 'assets/images/Kotlin-logo.png';
    if (key.contains('php')) return 'assets/images/PHP-logo.png';
    if (key.contains('rust')) return 'assets/images/Rust-logo.png';
    if (key.contains('go')) return 'assets/images/Go-logo.png';
    if (key.contains('svelte')) return 'assets/images/svelte-logo.png';
    if (key.contains('chatgpt') || key.contains('gpt')) {
      return 'assets/images/chatgpt-logo.png';
    }
    if (key.contains('deepseek')) return 'assets/images/deepseek_logo.png';
    return null;
  }

  static IconData _fallbackIconForKeyword(
    String keyword, {
    required IconData fallback,
  }) {
    final String key = keyword.toLowerCase();
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
    if (key.contains('github') || key.contains('reddit')) {
      return Icons.hub_rounded;
    }
    if (key.contains('stack')) return Icons.forum_rounded;
    return fallback;
  }
}

class _HomeInsightTile extends StatelessWidget {
  final _InsightItem item;

  const _HomeInsightTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double viewportWidth = MediaQuery.sizeOf(context).width;
        final bool compact =
            viewportWidth < 520 || constraints.maxWidth < 420;
        return Container(
          width: compact ? constraints.maxWidth : null,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.color.withValues(alpha: 0.3), width: 2),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: item.color.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: item.color.withValues(alpha: 0.1),
                      ),
                      child: item.assetPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(
                                item.assetPath!,
                                fit: BoxFit.contain,
                              ),
                            )
                          : Icon(item.fallbackIcon, color: item.color, size: 24),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: item.color,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF475569),
                        height: 1.35,
                      ),
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        color: item.color.withValues(alpha: 0.1),
                      ),
                      child: item.assetPath != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.asset(item.assetPath!, fit: BoxFit.contain),
                            )
                          : Icon(item.fallbackIcon, color: item.color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            item.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: item.color,
                              height: 1.25,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            item.description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF475569),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

class _InsightItem {
  final String title;
  final String description;
  final Color color;
  final String? assetPath;
  final IconData fallbackIcon;

  const _InsightItem({
    required this.title,
    required this.description,
    required this.color,
    this.assetPath,
    required this.fallbackIcon,
  });
}

enum _HomeRankingView { topRecommended, top5, top10, multiSource }

class _RankingFilterResult {
  final List<TrendTopEntry> items;

  const _RankingFilterResult({required this.items});
}

class _TrendTemporalBridgeCard extends ConsumerStatefulWidget {
  const _TrendTemporalBridgeCard();

  @override
  ConsumerState<_TrendTemporalBridgeCard> createState() =>
      _TrendTemporalBridgeCardState();
}

class _TrendTemporalBridgeCardState
    extends ConsumerState<_TrendTemporalBridgeCard> {
  _HomeRankingView _selectedView = _HomeRankingView.topRecommended;

  @override
  void initState() {
    super.initState();
    final int? savedViewIndex = ref.read(homeReturnViewIndexProvider);
    if (savedViewIndex != null &&
        savedViewIndex >= 0 &&
        savedViewIndex < _HomeRankingView.values.length) {
      _selectedView = _HomeRankingView.values[savedViewIndex];
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(homeReturnViewIndexProvider.notifier).state = null;
      });
    }
  }

  void _openTrendDetail(TrendTopEntry item) {
    final ScrollController? scrollController =
        PrimaryScrollController.maybeOf(context);
    if (scrollController != null && scrollController.hasClients) {
      ref.read(homeReturnScrollOffsetProvider.notifier).state =
          scrollController.position.pixels;
    }
    ref.read(homeReturnViewIndexProvider.notifier).state = _selectedView.index;
    String slug = item.slug.trim();
    if (slug.isEmpty) {
      slug = normalizeSlug(item.tecnologia);
    }
    final String encoded = Uri.encodeComponent(
      slug.isNotEmpty ? slug : 'unknown',
    );
    if (!mounted) {
      return;
    }
    context.go('/trends/$encoded');
  }

  @override
  Widget build(BuildContext context) {
    final trendAsync = ref.watch(trendTemporalProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: trendAsync.when(
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (error, stackTrace) => Text(
          'No se pudo cargar la vista temporal: $error',
          style: const TextStyle(color: Colors.red),
        ),
        data: (state) {
          final TrendTemporalViewData? trendData = state.data;
          final List<TrendTopEntry> rawItems =
              trendData?.items ?? const <TrendTopEntry>[];
          final _RankingFilterResult filterResult = _applyFilter(rawItems);
          final List<TrendTopEntry> items = filterResult.items;
          final String? latestSnapshotDate = trendData?.latestSnapshotDate;
          final String? previousSnapshotDate =
              trendData?.previousSnapshotDate;
          final String topChipLabel = items.isEmpty
              ? 'Sin datos disponibles'
              : _selectedView == _HomeRankingView.multiSource
                  ? '>=2 fuentes activas - ${items.length} tecnologias'
                  : '${_viewLabel(_selectedView)} - ${items.length} elementos';

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compactHeader = constraints.maxWidth < 520;
                  final Widget title = const Text(
                    'Ranking actual de tendencias tecnologicas',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  );
                  final Widget topChip = Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      topChipLabel,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1D4ED8),
                      ),
                    ),
                  );
                  final Widget filter = ChartInlineFilter<_HomeRankingView>(
                    label: 'Vista',
                    value: _selectedView,
                    selectedLabel: _viewLabel(_selectedView),
                    items: _filterDropdownItems(),
                    onChanged: (value) {
                      if (value == null || value == _selectedView) {
                        return;
                      }
                      setState(() => _selectedView = value);
                    },
                  );

                  if (compactHeader) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        title,
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: <Widget>[topChip, filter],
                        ),
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: <Widget>[title, topChip, filter],
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'Haz clic en una tarjeta para ver su análisis.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 6),
              LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  final bool compactNote = constraints.maxWidth < 520;
                  final Widget noteText = const Text(
                    'Ranking calculado con datos combinados de GitHub, StackOverflow y Reddit.',
                    style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
                  );
                  final Widget info = _buildTapTooltip(
                    message: 'Puntaje total = GH 40% · SO 35% · RD 25%.',
                    child: const Icon(
                      Icons.info_outline_rounded,
                      size: 14,
                      color: Color(0xFF64748B),
                    ),
                  );

                  if (compactNote) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        noteText,
                        const SizedBox(height: 4),
                        info,
                      ],
                    );
                  }

                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Ranking calculado con datos combinados de GitHub, StackOverflow y Reddit.',
                          style:
                              TextStyle(fontSize: 13, color: Color(0xFF475569)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      info,
                    ],
                  );
                },
              ),
              const SizedBox(height: 4),
              const Text(
                'Cada tarjeta muestra puntaje total, variacion vs corrida previa y contribucion real por fuente.',
                style: TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              if (latestSnapshotDate != null && previousSnapshotDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Comparado (UTC): ${_formatUtcDate(previousSnapshotDate)} -> ${_formatUtcDate(latestSnapshotDate)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                )
              else if (latestSnapshotDate != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Snapshot actual (UTC): ${_formatUtcDate(latestSnapshotDate)}',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
                  ),
                ),
              if (state.isDegraded)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: DegradedStateCard(
                    message:
                        state.message ?? 'Modo degradado activo en la vista temporal.',
                  ),
                ),
              const SizedBox(height: 14),
              if (items.isEmpty)
                Text(
                  _emptyStateMessage(),
                  style: const TextStyle(color: Color(0xFF475569)),
                )
              else
                LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    const double spacing = 10;
                    final double maxWidth = constraints.maxWidth;
                    double cardWidth = 220;

                    if (maxWidth < 620) {
                      cardWidth = maxWidth;
                    } else if (maxWidth < 760) {
                      cardWidth = (maxWidth - spacing) / 2;
                      if (cardWidth < 150) {
                        cardWidth = maxWidth;
                      }
                    } else if (maxWidth < 1120) {
                      cardWidth = (maxWidth - (spacing * 2)) / 3;
                    }

                    final bool useLocalRanking =
                        _selectedView == _HomeRankingView.topRecommended ||
                        _selectedView == _HomeRankingView.multiSource;
                    return Wrap(
                      spacing: spacing,
                      runSpacing: spacing,
                      children: [
                        for (int i = 0; i < items.length; i++)
                          SizedBox(
                            width: cardWidth,
                            child: _TrendTopEntryCard(
                              item: items[i],
                              displayRank: useLocalRanking ? i + 1 : null,
                              isTopRank: useLocalRanking
                                  ? i == 0
                                  : items[i].ranking == 1,
                              onNavigate: () => _openTrendDetail(items[i]),
                              comparisonDate:
                                  previousSnapshotDate == null
                                      ? null
                                      : _formatUtcDate(previousSnapshotDate),
                            ),
                          ),
                      ],
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  _RankingFilterResult _applyFilter(List<TrendTopEntry> items) {
    if (items.isEmpty) {
      return const _RankingFilterResult(items: <TrendTopEntry>[]);
    }
    switch (_selectedView) {
      case _HomeRankingView.topRecommended:
        final recommended = items
            .where((entry) => entry.fuentes >= 2 && entry.trendScore >= 15)
            .toList()
          ..sort((a, b) => b.trendScore.compareTo(a.trendScore));
        return _RankingFilterResult(items: recommended.take(8).toList());
      case _HomeRankingView.top5:
        return _RankingFilterResult(items: items.take(5).toList());
      case _HomeRankingView.top10:
        return _RankingFilterResult(items: items.take(10).toList());
      case _HomeRankingView.multiSource:
        final multi = items.where((entry) => entry.fuentes >= 2).toList();
        return _RankingFilterResult(items: multi);
    }
  }

  List<DropdownMenuItem<_HomeRankingView>> _filterDropdownItems() {
    return _HomeRankingView.values
        .map(
          (view) => DropdownMenuItem<_HomeRankingView>(
            value: view,
            child: Text(_viewLabel(view)),
          ),
        )
        .toList();
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

    static String _viewLabel(_HomeRankingView view) {
    switch (view) {
      case _HomeRankingView.topRecommended:
        return 'Top recomendado';
      case _HomeRankingView.top5:
        return 'Top 5';
      case _HomeRankingView.top10:
        return 'Top 10';
      case _HomeRankingView.multiSource:
        return 'Solo multi-fuente';
    }
  }

  String _emptyStateMessage() {
    switch (_selectedView) {
      case _HomeRankingView.topRecommended:
        return 'No hay tecnologias que cumplan el criterio recomendado en esta corrida.';
      case _HomeRankingView.multiSource:
        return 'No hay tecnologias multi-fuente en esta corrida.';
      default:
        return 'No hay tecnologias disponibles para esta vista.';
    }
  }

  String _formatUtcDate(String value) {
    if (value.isEmpty) {
      return 'fecha no disponible';
    }
    final DateTime? parsed = DateTime.tryParse(value);
    if (parsed == null) {
      return value;
    }
    final String day = parsed.day.toString().padLeft(2, '0');
    final String month = parsed.month.toString().padLeft(2, '0');
    return '$day/$month/${parsed.year}';
  }
}
class _TrendTopEntryCard extends StatefulWidget {
  final TrendTopEntry item;
  final bool isTopRank;
  final String? comparisonDate;
  final int? displayRank;
  final VoidCallback? onNavigate;

  const _TrendTopEntryCard({
    required this.item,
    required this.isTopRank,
    required this.comparisonDate,
    this.displayRank,
    this.onNavigate,
  });

  @override
  State<_TrendTopEntryCard> createState() => _TrendTopEntryCardState();
}

class _SourceContributionMeta {
  final String code;
  final String label;
  final IconData icon;
  final Color color;
  final double value;

  const _SourceContributionMeta({
    required this.code,
    required this.label,
    required this.icon,
    required this.color,
    required this.value,
  });
}

class _TrendTopEntryCardState extends State<_TrendTopEntryCard> {
  bool _hovered = false;
  bool _focused = false;

  void _openTechDetail() {
    final String slug = _resolveSlug();
    final String encoded = Uri.encodeComponent(slug);
    if (!mounted) {
      return;
    }
    context.go('/trends/$encoded');
  }

  String _resolveSlug() {
    final String directSlug = widget.item.slug.trim();
    if (directSlug.isNotEmpty) {
      return directSlug;
    }
    final String slug = normalizeSlug(widget.item.tecnologia);
    return slug.isNotEmpty ? slug : 'unknown';
  }

  @override
  Widget build(BuildContext context) {
    final Color accent = _technologyAccent(widget.item.tecnologia);
    final bool isActive = _hovered || _focused;
    final Color borderColor = isActive
        ? accent.withValues(alpha: 0.55)
        : const Color(0xFFE5E7EB);
    final Color cardColor = widget.isTopRank
        ? const Color(0xFFF8FAFF)
        : Colors.white;
    final Color badgeBackground = widget.isTopRank
        ? const Color(0xFF1E293B)
        : const Color(0xFF334155);
    final Color badgeBorder = widget.isTopRank
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final List<BoxShadow> shadows = <BoxShadow>[
      BoxShadow(
        color: Colors.black.withValues(alpha: widget.isTopRank ? 0.08 : 0.05),
        blurRadius: widget.isTopRank ? 14 : 10,
        offset: const Offset(0, 4),
      ),
      if (isActive)
        BoxShadow(
          color: accent.withValues(alpha: 0.20),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
    ];

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: FocusableActionDetector(
        onShowFocusHighlight: (bool value) {
          if (_focused == value) {
            return;
          }
          setState(() => _focused = value);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: shadows,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: widget.onNavigate ?? _openTechDetail,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(15),
                        topRight: Radius.circular(15),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          widget.item.tecnologia,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: badgeBackground,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: badgeBorder),
                              boxShadow: <BoxShadow>[
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.10),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Text(
                              '#${widget.displayRank ?? widget.item.ranking}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFFF8FAFC),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.item.trendScore.toStringAsFixed(2),
                          style: const TextStyle(
                            fontSize: 44,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 12),
                        _buildDeltaBadges(),
                        const SizedBox(height: 10),
                        _buildContributionChips(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDeltaBadges() {
    final double? deltaScore = widget.item.deltaScore;
    final String? comparisonDate = widget.comparisonDate;
    final String deltaLabel =
        (deltaScore != null && comparisonDate != null)
            ? '${_formatSigned(deltaScore)} pts vs $comparisonDate'
            : 'Variacion no disponible';
    final Color deltaColor =
        deltaScore == null
            ? const Color(0xFF64748B)
            : deltaScore > 0
                ? const Color(0xFF15803D)
                : deltaScore < 0
                    ? const Color(0xFFB91C1C)
                    : const Color(0xFF475569);
    final IconData deltaIcon =
        deltaScore == null
            ? Icons.horizontal_rule_rounded
            : deltaScore > 0
                ? Icons.arrow_upward_rounded
                : deltaScore < 0
                    ? Icons.arrow_downward_rounded
                    : Icons.remove_rounded;

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: [
        _buildDeltaChip(
          icon: deltaIcon,
          label: deltaLabel,
          color: deltaColor,
        ),
        _buildDeltaChip(
          icon: _rankingChangeIcon(),
          label: _rankingChangeLabel(),
          color: _rankingChangeColor(),
        ),
      ],
    );
  }

  Widget _buildDeltaChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 240),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Wrap(
          spacing: 6,
          runSpacing: 2,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Icon(icon, size: 14, color: color),
            Text(
              label,
              softWrap: true,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
      ),
    );
    }

    String _rankingChangeLabel() {
    final int? deltaRanking = widget.item.deltaRanking;
    final int? rankingPrev = widget.item.rankingPrev;
    if (deltaRanking == null || rankingPrev == null) {
      return 'Posicion sin historial';
    }
    if (deltaRanking > 0) {
      return 'Sube ${deltaRanking.abs()} posicion${deltaRanking == 1 ? '' : 'es'}';
    }
    if (deltaRanking < 0) {
      return 'Baja ${deltaRanking.abs()} posicion${deltaRanking == -1 ? '' : 'es'}';
    }
    return 'Tendencia estable';
  }

  Color _rankingChangeColor() {
    final int? deltaRanking = widget.item.deltaRanking;
    final int? rankingPrev = widget.item.rankingPrev;
    if (deltaRanking == null || rankingPrev == null) {
      return const Color(0xFF94A3B8);
    }
    if (deltaRanking > 0) {
      return const Color(0xFF15803D);
    }
    if (deltaRanking < 0) {
      return const Color(0xFFB91C1C);
    }
    return const Color(0xFF475569);
  }

  IconData _rankingChangeIcon() {
    final int? deltaRanking = widget.item.deltaRanking;
    final int? rankingPrev = widget.item.rankingPrev;
    if (deltaRanking == null || rankingPrev == null) {
      return Icons.info_outline_rounded;
    }
    if (deltaRanking > 0) {
      return Icons.trending_up_rounded;
    }
    if (deltaRanking < 0) {
      return Icons.trending_down_rounded;
    }
    return Icons.horizontal_rule_rounded;
  }

  Widget _buildContributionChips() {
    final Set<String> available = widget.item.availableSources
        .map((code) => code.toUpperCase())
        .toSet();
    final List<_SourceContributionMeta> contributions = [
      _SourceContributionMeta(
        code: 'GH',
        label: 'GitHub',
        icon: FontAwesomeIcons.github,
        color: const Color(0xFF111827),
        value: widget.item.githubScore,
      ),
      _SourceContributionMeta(
        code: 'SO',
        label: 'StackOverflow',
        icon: FontAwesomeIcons.stackOverflow,
        color: const Color(0xFFF48024),
        value: widget.item.stackOverflowScore,
      ),
      _SourceContributionMeta(
        code: 'RD',
        label: 'Reddit',
        icon: FontAwesomeIcons.redditAlien,
        color: const Color(0xFFFF4500),
        value: widget.item.redditScore,
      ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: contributions.map((meta) {
        final bool hasData =
            available.contains(meta.code) || meta.value > 0.0;
        final String valueLabel =
            hasData ? meta.value.toStringAsFixed(2) : '--';
        return Tooltip(
          message: hasData
              ? '${meta.label}: ${meta.value.toStringAsFixed(2)} pts'
              : '${meta.label}: esta tecnologia no tuvo puntos en esta fuente',
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: hasData
                  ? meta.color.withValues(alpha: 0.12)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(
                color: hasData
                    ? meta.color.withValues(alpha: 0.35)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FaIcon(
                  meta.icon,
                  size: 12,
                  color: hasData ? meta.color : const Color(0xFF94A3B8),
                ),
                const SizedBox(width: 6),
                Text(
                  '${meta.code} $valueLabel',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasData
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _formatSigned(double value) {
    final String sign = value > 0 ? '+' : '';
    return '$sign${value.toStringAsFixed(2)}';
  }

  static Color _technologyAccent(String value) {
    final String key = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]+'),
      '',
    );

    if (key.contains('python')) return const Color(0xFF3776AB);
    if (key.contains('typescript')) return const Color(0xFF3178C6);
    if (key.contains('javascript')) return const Color(0xFFEAB308);
    if (key.contains('java')) return const Color(0xFFEA580C);
    if (key.contains('rust')) return const Color(0xFFCE422B);
    if (key.contains('go')) return const Color(0xFF00ADD8);
    if (key.contains('aiml') || key.contains('machinelearning')) {
      return const Color(0xFF0EA5E9);
    }
    return const Color(0xFF2563EB);
  }
}
