class TechnologyProfilesPayload {
  final String dataset;
  final String generatedAtUtc;
  final String sourceMode;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;
  final int profileCount;
  final List<TechnologyProfile> profiles;

  const TechnologyProfilesPayload({
    required this.dataset,
    required this.generatedAtUtc,
    required this.sourceMode,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
    required this.profileCount,
    required this.profiles,
  });

  factory TechnologyProfilesPayload.fromMap(Map<String, dynamic> map) {
    final rawProfiles = (map['profiles'] as List?) ?? const [];
    final profiles = rawProfiles
        .whereType<Map>()
        .map((item) => TechnologyProfile.fromMap(item.cast<String, dynamic>()))
        .toList();
    return TechnologyProfilesPayload(
      dataset: map['dataset']?.toString() ?? 'technology_profiles',
      generatedAtUtc: map['generated_at_utc']?.toString() ?? '',
      sourceMode: map['source_mode']?.toString() ?? '',
      latestSnapshotDate: map['latest_snapshot_date']?.toString(),
      previousSnapshotDate: map['previous_snapshot_date']?.toString(),
      profileCount: _asInt(map['profile_count'], fallback: profiles.length),
      profiles: profiles,
    );
  }
}

class TechnologyProfile {
  final String slug;
  final String displayName;
  final double trendScoreActual;
  final double? trendScorePrev;
  final double? deltaScore;
  final int rankingActual;
  final int? rankingPrev;
  final int? deltaRanking;
  final List<String> sourcesPresent;
  final TechnologySourceSummary githubSummary;
  final TechnologySourceSummary stackoverflowSummary;
  final TechnologySourceSummary redditSummary;
  final List<TechnologySourceHistoryPoint> sourceHistory;
  final TechnologySummaryInsights summaryInsights;

  const TechnologyProfile({
    required this.slug,
    required this.displayName,
    required this.trendScoreActual,
    required this.trendScorePrev,
    required this.deltaScore,
    required this.rankingActual,
    required this.rankingPrev,
    required this.deltaRanking,
    required this.sourcesPresent,
    required this.githubSummary,
    required this.stackoverflowSummary,
    required this.redditSummary,
    required this.sourceHistory,
    required this.summaryInsights,
  });

  factory TechnologyProfile.fromMap(Map<String, dynamic> map) {
    final historyRaw = (map['source_history'] as List?) ?? const [];
    return TechnologyProfile(
      slug: map['slug']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      trendScoreActual: _asDouble(map['trend_score_actual']),
      trendScorePrev: _tryDouble(map['trend_score_prev']),
      deltaScore: _tryDouble(map['delta_score']),
      rankingActual: _asInt(map['ranking_actual']),
      rankingPrev: _tryInt(map['ranking_prev']),
      deltaRanking: _tryInt(map['delta_ranking']),
      sourcesPresent: _toStringList(map['sources_present']),
      githubSummary: TechnologySourceSummary.fromMap(
        map['github_summary'] as Map?,
        fallbackSource: 'github',
        fallbackDisplayName: 'GitHub',
      ),
      stackoverflowSummary: TechnologySourceSummary.fromMap(
        map['stackoverflow_summary'] as Map?,
        fallbackSource: 'stackoverflow',
        fallbackDisplayName: 'StackOverflow',
      ),
      redditSummary: TechnologySourceSummary.fromMap(
        map['reddit_summary'] as Map?,
        fallbackSource: 'reddit',
        fallbackDisplayName: 'Reddit',
      ),
      sourceHistory: historyRaw
          .whereType<Map>()
          .map(
            (item) =>
                TechnologySourceHistoryPoint.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
      summaryInsights: TechnologySummaryInsights.fromMap(
        (map['summary_insights'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

class TechnologySourceSummary {
  final String source;
  final String displayName;
  final bool available;
  final double scoreActual;
  final double? scorePrev;
  final double? deltaScore;

  const TechnologySourceSummary({
    required this.source,
    required this.displayName,
    required this.available,
    required this.scoreActual,
    required this.scorePrev,
    required this.deltaScore,
  });

  factory TechnologySourceSummary.fromMap(
    Map? map, {
    required String fallbackSource,
    required String fallbackDisplayName,
  }) {
    if (map == null) {
      return TechnologySourceSummary(
        source: fallbackSource,
        displayName: fallbackDisplayName,
        available: false,
        scoreActual: 0.0,
        scorePrev: null,
        deltaScore: null,
      );
    }
    return TechnologySourceSummary(
      source: map['source']?.toString() ?? fallbackSource,
      displayName: map['display_name']?.toString() ?? fallbackDisplayName,
      available: map['available'] == true,
      scoreActual: _asDouble(map['score_actual']),
      scorePrev: _tryDouble(map['score_prev']),
      deltaScore: _tryDouble(map['delta_score']),
    );
  }
}

class TechnologySourceHistoryPoint {
  final String date;
  final double trendScore;
  final double githubScore;
  final double stackOverflowScore;
  final double redditScore;
  final int? ranking;
  final int fuentes;
  final List<String> availableSourceCodes;

  const TechnologySourceHistoryPoint({
    required this.date,
    required this.trendScore,
    required this.githubScore,
    required this.stackOverflowScore,
    required this.redditScore,
    required this.ranking,
    required this.fuentes,
    required this.availableSourceCodes,
  });

  factory TechnologySourceHistoryPoint.fromMap(Map<String, dynamic> map) {
    return TechnologySourceHistoryPoint(
      date: map['date']?.toString() ?? '',
      trendScore: _asDouble(map['trend_score']),
      githubScore: _asDouble(map['github_score']),
      stackOverflowScore: _asDouble(map['so_score']),
      redditScore: _asDouble(map['reddit_score']),
      ranking: _tryInt(map['ranking']),
      fuentes: _asInt(map['fuentes']),
      availableSourceCodes: _toStringList(map['available_source_codes']),
    );
  }
}

class TechnologySummaryInsights {
  final TechnologyDominantSourceInsight? dominantSource;
  final TechnologyCoverageInsight coverage;
  final TechnologyMomentumInsight momentum;

  const TechnologySummaryInsights({
    required this.dominantSource,
    required this.coverage,
    required this.momentum,
  });

  factory TechnologySummaryInsights.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return TechnologySummaryInsights(
        dominantSource: null,
        coverage: const TechnologyCoverageInsight(
          sourceCount: 0,
          sourcesPresent: <String>[],
          label: 'Cobertura no disponible.',
        ),
        momentum: const TechnologyMomentumInsight(
          rankingActual: 0,
          rankingPrev: null,
          deltaRanking: null,
          scoreActual: 0.0,
          scorePrev: null,
          label: 'Movimiento no disponible.',
        ),
      );
    }

    final Map<String, dynamic>? dominantRaw =
        (map['dominant_source'] as Map?)?.cast<String, dynamic>();
    return TechnologySummaryInsights(
      dominantSource: dominantRaw == null
          ? null
          : TechnologyDominantSourceInsight.fromMap(dominantRaw),
      coverage: TechnologyCoverageInsight.fromMap(
        (map['coverage'] as Map?)?.cast<String, dynamic>(),
      ),
      momentum: TechnologyMomentumInsight.fromMap(
        (map['momentum'] as Map?)?.cast<String, dynamic>(),
      ),
    );
  }
}

class TechnologyDominantSourceInsight {
  final String source;
  final String displayName;
  final double score;
  final String label;

  const TechnologyDominantSourceInsight({
    required this.source,
    required this.displayName,
    required this.score,
    required this.label,
  });

  factory TechnologyDominantSourceInsight.fromMap(Map<String, dynamic> map) {
    return TechnologyDominantSourceInsight(
      source: map['source']?.toString() ?? '',
      displayName: map['display_name']?.toString() ?? '',
      score: _asDouble(map['score']),
      label: map['label']?.toString() ?? '',
    );
  }
}

class TechnologyCoverageInsight {
  final int sourceCount;
  final List<String> sourcesPresent;
  final String label;

  const TechnologyCoverageInsight({
    required this.sourceCount,
    required this.sourcesPresent,
    required this.label,
  });

  factory TechnologyCoverageInsight.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const TechnologyCoverageInsight(
        sourceCount: 0,
        sourcesPresent: <String>[],
        label: 'Cobertura no disponible.',
      );
    }
    return TechnologyCoverageInsight(
      sourceCount: _asInt(map['source_count']),
      sourcesPresent: _toStringList(map['sources_present']),
      label: map['label']?.toString() ?? '',
    );
  }
}

class TechnologyMomentumInsight {
  final int rankingActual;
  final int? rankingPrev;
  final int? deltaRanking;
  final double scoreActual;
  final double? scorePrev;
  final String label;

  const TechnologyMomentumInsight({
    required this.rankingActual,
    required this.rankingPrev,
    required this.deltaRanking,
    required this.scoreActual,
    required this.scorePrev,
    required this.label,
  });

  factory TechnologyMomentumInsight.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const TechnologyMomentumInsight(
        rankingActual: 0,
        rankingPrev: null,
        deltaRanking: null,
        scoreActual: 0.0,
        scorePrev: null,
        label: 'Movimiento no disponible.',
      );
    }
    return TechnologyMomentumInsight(
      rankingActual: _asInt(map['ranking_actual']),
      rankingPrev: _tryInt(map['ranking_prev']),
      deltaRanking: _tryInt(map['delta_ranking']),
      scoreActual: _asDouble(map['score_actual']),
      scorePrev: _tryDouble(map['score_prev']),
      label: map['label']?.toString() ?? '',
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

double _asDouble(dynamic value, {double fallback = 0.0}) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _tryDouble(dynamic value) {
  return double.tryParse(value?.toString() ?? '');
}

int? _tryInt(dynamic value) {
  return int.tryParse(value?.toString() ?? '');
}

List<String> _toStringList(dynamic value) {
  if (value is List) {
    return value.map((item) => item.toString()).toList();
  }
  return const [];
}
