class TrendTopEntry {
  final int ranking;
  final String tecnologia;
  final double trendScore;
  final int fuentes;

  const TrendTopEntry({
    required this.ranking,
    required this.tecnologia,
    required this.trendScore,
    required this.fuentes,
  });

  factory TrendTopEntry.fromMap(Map<String, dynamic> map) {
    return TrendTopEntry(
      ranking: int.tryParse(map['ranking']?.toString() ?? '0') ?? 0,
      tecnologia: map['tecnologia']?.toString() ?? '',
      trendScore: double.tryParse(map['trend_score']?.toString() ?? '0') ?? 0.0,
      fuentes: int.tryParse(map['fuentes']?.toString() ?? '0') ?? 0,
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
