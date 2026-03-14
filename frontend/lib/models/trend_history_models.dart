class TrendTopEntry {
  final int ranking;
  final String slug;
  final String tecnologia;
  final double trendScore;
  final int fuentes;
  final double githubScore;
  final double stackOverflowScore;
  final double redditScore;
  final double? scorePrev;
  final double? deltaScore;
  final int? rankingPrev;
  final int? deltaRanking;
  final List<String> availableSources;

  const TrendTopEntry({
    required this.ranking,
    this.slug = '',
    required this.tecnologia,
    required this.trendScore,
    required this.fuentes,
    required this.githubScore,
    required this.stackOverflowScore,
    required this.redditScore,
    required this.scorePrev,
    required this.deltaScore,
    required this.rankingPrev,
    required this.deltaRanking,
    required this.availableSources,
  });

  factory TrendTopEntry.fromMap(Map<String, dynamic> map) {
    return TrendTopEntry(
      ranking: int.tryParse(map['ranking']?.toString() ?? '0') ?? 0,
      slug: map['slug']?.toString() ?? '',
      tecnologia: map['tecnologia']?.toString() ?? '',
      trendScore: double.tryParse(map['trend_score']?.toString() ?? '0') ?? 0.0,
      fuentes: int.tryParse(map['fuentes']?.toString() ?? '0') ?? 0,
      githubScore:
          double.tryParse(map['github_score']?.toString() ?? '0') ?? 0.0,
      stackOverflowScore:
          double.tryParse(map['so_score']?.toString() ?? '0') ?? 0.0,
      redditScore:
          double.tryParse(map['reddit_score']?.toString() ?? '0') ?? 0.0,
      scorePrev: map.containsKey('score_prev')
          ? double.tryParse(map['score_prev']?.toString() ?? '')
          : null,
      deltaScore: map.containsKey('delta_score')
          ? double.tryParse(map['delta_score']?.toString() ?? '')
          : null,
      rankingPrev: map.containsKey('ranking_prev')
          ? int.tryParse(map['ranking_prev']?.toString() ?? '')
          : null,
      deltaRanking: map.containsKey('delta_ranking')
          ? int.tryParse(map['delta_ranking']?.toString() ?? '')
          : null,
      availableSources: (map['available_source_codes'] as List?)
              ?.whereType<String>()
              .map((value) => value.toUpperCase())
              .toList() ??
          const <String>[],
    );
  }
}

class TrendSnapshotModel {
  final String date;
  final String path;
  final String sourceType;
  final int rowCount;
  final List<TrendTopEntry> top10;

  const TrendSnapshotModel({
    required this.date,
    required this.path,
    required this.sourceType,
    required this.rowCount,
    required this.top10,
  });

  factory TrendSnapshotModel.fromMap(Map<String, dynamic> map) {
    final rawTop = (map['top_10'] as List?) ?? const [];
    return TrendSnapshotModel(
      date: map['date']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      sourceType: map['source_type']?.toString() ?? '',
      rowCount: int.tryParse(map['row_count']?.toString() ?? '0') ?? 0,
      top10: rawTop
          .whereType<Map>()
          .map((item) => TrendTopEntry.fromMap(item.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TrendScoreHistoryModel {
  final String generatedAtUtc;
  final int snapshotCount;
  final List<TrendSnapshotModel> snapshots;

  const TrendScoreHistoryModel({
    required this.generatedAtUtc,
    required this.snapshotCount,
    required this.snapshots,
  });

  factory TrendScoreHistoryModel.fromMap(Map<String, dynamic> map) {
    final rawSnapshots = (map['snapshots'] as List?) ?? const [];
    return TrendScoreHistoryModel(
      generatedAtUtc: map['generated_at_utc']?.toString() ?? '',
      snapshotCount:
          int.tryParse(map['snapshot_count']?.toString() ?? '0') ?? 0,
      snapshots: rawSnapshots
          .whereType<Map>()
          .map(
            (item) => TrendSnapshotModel.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}
