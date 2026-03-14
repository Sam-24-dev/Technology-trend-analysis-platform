class SentimientoModel {
  final String framework;
  final int totalMenciones;
  final int positivos;
  final int neutros;
  final int negativos;
  final double porcentajePositivo;
  final double porcentajeNeutro;
  final double porcentajeNegativo;

  SentimientoModel({
    required this.framework,
    this.totalMenciones = 0,
    this.positivos = 0,
    this.neutros = 0,
    this.negativos = 0,
    required this.porcentajePositivo,
    this.porcentajeNeutro = 0,
    required this.porcentajeNegativo,
  });

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _firstDouble(List<dynamic> values, {double fallback = 0}) {
    for (final dynamic value in values) {
      final double? parsed = double.tryParse(value?.toString() ?? '');
      if (parsed != null) {
        return parsed;
      }
      if (value is num) {
        return value.toDouble();
      }
    }
    return fallback;
  }

  factory SentimientoModel.fromMap(Map<String, dynamic> map) {
    return SentimientoModel(
      framework: map['framework'] ?? '',
      totalMenciones: _asInt(map['total_menciones']),
      positivos: _asInt(map['positivos']),
      neutros: _asInt(map['neutros']),
      negativos: _asInt(map['negativos']),
      porcentajePositivo: _firstDouble(<dynamic>[
        map['% positivo'],
        map['porcentaje_positivo'],
      ]),
      porcentajeNeutro: _firstDouble(<dynamic>[
        map['% neutro'],
        map['porcentaje_neutro'],
      ]),
      porcentajeNegativo: _firstDouble(<dynamic>[
        map['% negativo'],
        map['porcentaje_negativo'],
      ]),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'framework': framework,
      'total_menciones': totalMenciones,
      'positivos': positivos,
      'neutros': neutros,
      'negativos': negativos,
      'porcentaje_positivo': _asDouble(porcentajePositivo),
      'porcentaje_neutro': _asDouble(porcentajeNeutro),
      'porcentaje_negativo': _asDouble(porcentajeNegativo),
    };
  }
}

class RedditSentimentSummaryModel {
  final SentimientoModel? positiveLeader;
  final SentimientoModel? largestSample;
  final SentimientoModel? negativeLeader;
  final int frameworkCount;
  final int totalMenciones;

  const RedditSentimentSummaryModel({
    this.positiveLeader,
    this.largestSample,
    this.negativeLeader,
    this.frameworkCount = 0,
    this.totalMenciones = 0,
  });

  const RedditSentimentSummaryModel.empty()
    : positiveLeader = null,
      largestSample = null,
      negativeLeader = null,
      frameworkCount = 0,
      totalMenciones = 0;

  factory RedditSentimentSummaryModel.fromMap(Map<String, dynamic> map) {
    SentimientoModel? parseLeader(dynamic value) {
      if (value is Map) {
        return SentimientoModel.fromMap(value.cast<String, dynamic>());
      }
      return null;
    }

    return RedditSentimentSummaryModel(
      positiveLeader: parseLeader(map['positive_leader']),
      largestSample: parseLeader(map['largest_sample']),
      negativeLeader: parseLeader(map['negative_leader']),
      frameworkCount: _parseInt(map['framework_count']),
      totalMenciones: _parseInt(map['total_menciones']),
    );
  }
}

class TemasEmergentesModel {
  final String tema;
  final int menciones;
  final int? mencionesPrevias;
  final int? deltaMenciones;
  final double? growthPct;
  final String? trendDirection;

  const TemasEmergentesModel({
    required this.tema,
    required this.menciones,
    this.mencionesPrevias,
    this.deltaMenciones,
    this.growthPct,
    this.trendDirection,
  });

  factory TemasEmergentesModel.fromMap(Map<String, dynamic> map) {
    int? parseNullableInt(dynamic value) {
      if (value == null) {
        return null;
      }
      return int.tryParse(value.toString());
    }

    double? parseNullableDouble(dynamic value) {
      if (value == null) {
        return null;
      }
      return double.tryParse(value.toString());
    }

    return TemasEmergentesModel(
      tema: map['tema'] ?? '',
      menciones: int.tryParse(map['menciones']?.toString() ?? '0') ?? 0,
      mencionesPrevias: parseNullableInt(map['menciones_previas']),
      deltaMenciones: parseNullableInt(map['delta_menciones']),
      growthPct: parseNullableDouble(map['growth_pct']),
      trendDirection:
          (map['trend_direction']?.toString().trim().isEmpty ?? true)
          ? null
          : map['trend_direction']?.toString().trim(),
    );
  }
}

class RedditTemasHistoryModel {
  final String sourceMode;
  final int snapshotCount;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;
  final int topicCount;
  final RedditTemasSummaryModel summary;
  final List<TemasEmergentesModel> latestTopics;

  const RedditTemasHistoryModel({
    required this.sourceMode,
    required this.snapshotCount,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
    required this.topicCount,
    this.summary = const RedditTemasSummaryModel.empty(),
    required this.latestTopics,
  });

  factory RedditTemasHistoryModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawLatest =
        (map['latest_topics'] as List?) ?? const <dynamic>[];
    return RedditTemasHistoryModel(
      sourceMode: _parseString(map['source_mode']),
      snapshotCount: _parseInt(map['snapshot_count']),
      latestSnapshotDate: _parseString(map['latest_snapshot_date']).isEmpty
          ? null
          : _parseString(map['latest_snapshot_date']),
      previousSnapshotDate: _parseString(map['previous_snapshot_date']).isEmpty
          ? null
          : _parseString(map['previous_snapshot_date']),
      topicCount: _parseInt(map['topic_count']),
      summary: RedditTemasSummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      latestTopics: rawLatest
          .whereType<Map>()
          .map(
            (item) =>
                TemasEmergentesModel.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }

  bool get hasGrowthSignals {
    return snapshotCount >= 2 &&
        latestTopics.any(
          (item) =>
              item.deltaMenciones != null ||
              item.growthPct != null ||
              item.trendDirection != null,
        );
  }
}

class RedditTemasSummaryModel {
  final TemasEmergentesModel? leaderTopic;
  final TemasEmergentesModel? highestGrowthTopic;
  final TemasEmergentesModel? largestDropTopic;
  final int totalMenciones;
  final int topicCount;

  const RedditTemasSummaryModel({
    this.leaderTopic,
    this.highestGrowthTopic,
    this.largestDropTopic,
    this.totalMenciones = 0,
    this.topicCount = 0,
  });

  const RedditTemasSummaryModel.empty()
    : leaderTopic = null,
      highestGrowthTopic = null,
      largestDropTopic = null,
      totalMenciones = 0,
      topicCount = 0;

  factory RedditTemasSummaryModel.fromMap(Map<String, dynamic> map) {
    TemasEmergentesModel? parseTopic(dynamic value) {
      if (value is Map) {
        return TemasEmergentesModel.fromMap(value.cast<String, dynamic>());
      }
      return null;
    }

    return RedditTemasSummaryModel(
      leaderTopic: parseTopic(map['leader_topic']),
      highestGrowthTopic: parseTopic(map['highest_growth_topic']),
      largestDropTopic: parseTopic(map['largest_drop_topic']),
      totalMenciones: _parseInt(map['total_menciones']),
      topicCount: _parseInt(map['topic_count']),
    );
  }
}

class InterseccionModel {
  final String tecnologia;
  final int? rankingGitHub;
  final int? rankingReddit;

  InterseccionModel({
    required this.tecnologia,
    required this.rankingGitHub,
    required this.rankingReddit,
  });

  factory InterseccionModel.fromMap(Map<String, dynamic> map) {
    final githubStr = map['ranking_github']?.toString() ?? '';
    final redditStr = map['ranking_reddit']?.toString() ?? '';

    return InterseccionModel(
      tecnologia: map['tecnologia'] ?? '',
      rankingGitHub: (githubStr.isEmpty || githubStr == 'No encontrado')
          ? null
          : int.tryParse(githubStr),
      rankingReddit: (redditStr.isEmpty || redditStr == 'No encontrado')
          ? null
          : int.tryParse(redditStr),
    );
  }
}

int _parseInt(dynamic value, {int fallback = 0}) {
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int? _parseNullableInt(dynamic value) {
  if (value == null) {
    return null;
  }
  if (value is int) {
    return value;
  }
  if (value is double) {
    return value.toInt();
  }
  return int.tryParse(value.toString());
}

double _parseDouble(dynamic value, {double fallback = 0}) {
  if (value is double) {
    return value;
  }
  if (value is int) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

String _parseString(dynamic value) {
  return value?.toString() ?? '';
}

class RedditInterseccionSummaryModel {
  final int consensoCount;
  final int divergenteCount;
  final int comparableCount;
  final double coveragePct;
  final String? maxBrechaTecnologia;
  final int? maxBrechaAbs;
  final RedditInterseccionHistoryItemModel? closestAlignment;
  final RedditInterseccionHistoryItemModel? largestGapItem;

  const RedditInterseccionSummaryModel({
    required this.consensoCount,
    required this.divergenteCount,
    this.comparableCount = 0,
    this.coveragePct = 0,
    required this.maxBrechaTecnologia,
    required this.maxBrechaAbs,
    this.closestAlignment,
    this.largestGapItem,
  });

  factory RedditInterseccionSummaryModel.fromMap(Map<String, dynamic> map) {
    RedditInterseccionHistoryItemModel? parseItem(dynamic value) {
      if (value is Map) {
        return RedditInterseccionHistoryItemModel.fromMap(
          value.cast<String, dynamic>(),
        );
      }
      return null;
    }

    return RedditInterseccionSummaryModel(
      consensoCount: _parseInt(map['consenso_count']),
      divergenteCount: _parseInt(map['divergente_count']),
      comparableCount: _parseInt(map['comparable_count']),
      coveragePct: _parseDouble(map['coverage_pct']),
      maxBrechaTecnologia: _parseString(map['max_brecha_tecnologia']).isEmpty
          ? null
          : _parseString(map['max_brecha_tecnologia']),
      maxBrechaAbs: _parseNullableInt(map['max_brecha_abs']),
      closestAlignment: parseItem(map['closest_alignment']),
      largestGapItem: parseItem(map['largest_gap_item']),
    );
  }
}

class RedditInterseccionHistoryItemModel {
  final String tecnologia;
  final String tipo;
  final int? rankingGitHub;
  final int? rankingReddit;
  final int? brechaAbs;
  final double? promedioRank;
  final String direccion;
  final int? rankGithubPrev;
  final int? rankRedditPrev;
  final int? deltaGap;
  final String? trendDirection;

  const RedditInterseccionHistoryItemModel({
    required this.tecnologia,
    required this.tipo,
    required this.rankingGitHub,
    required this.rankingReddit,
    required this.brechaAbs,
    required this.promedioRank,
    required this.direccion,
    required this.rankGithubPrev,
    required this.rankRedditPrev,
    required this.deltaGap,
    required this.trendDirection,
  });

  factory RedditInterseccionHistoryItemModel.fromMap(Map<String, dynamic> map) {
    final String direction = _parseString(map['direccion']).trim();
    return RedditInterseccionHistoryItemModel(
      tecnologia: _parseString(map['tecnologia']),
      tipo: _parseString(map['tipo']),
      rankingGitHub: _parseNullableInt(map['ranking_github']),
      rankingReddit: _parseNullableInt(map['ranking_reddit']),
      brechaAbs: _parseNullableInt(map['brecha_abs']),
      promedioRank: map['promedio_rank'] == null
          ? null
          : _parseDouble(map['promedio_rank']),
      direccion: direction.isEmpty ? 'incompleto' : direction,
      rankGithubPrev: _parseNullableInt(map['rank_github_prev']),
      rankRedditPrev: _parseNullableInt(map['rank_reddit_prev']),
      deltaGap: _parseNullableInt(map['delta_gap']),
      trendDirection: _parseString(map['trend_direction']).trim().isEmpty
          ? null
          : _parseString(map['trend_direction']).trim(),
    );
  }

  bool get hasComparableRanks => rankingGitHub != null && rankingReddit != null;
}

class RedditInterseccionSnapshotModel {
  final String date;
  final String sourceType;
  final int rowCount;
  final int comparableCount;
  final double coveragePct;
  final List<RedditInterseccionHistoryItemModel> items;

  const RedditInterseccionSnapshotModel({
    required this.date,
    required this.sourceType,
    required this.rowCount,
    required this.comparableCount,
    required this.coveragePct,
    required this.items,
  });

  factory RedditInterseccionSnapshotModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawItems = (map['items'] as List?) ?? const <dynamic>[];
    return RedditInterseccionSnapshotModel(
      date: _parseString(map['date']),
      sourceType: _parseString(map['source_type']),
      rowCount: _parseInt(map['row_count']),
      comparableCount: _parseInt(map['comparable_count']),
      coveragePct: _parseDouble(map['coverage_pct']),
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => RedditInterseccionHistoryItemModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class RedditInterseccionHistoryModel {
  final String sourceMode;
  final int snapshotCount;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;
  final double coveragePct;
  final int comparableCount;
  final int itemCount;
  final RedditInterseccionSummaryModel summary;
  final List<RedditInterseccionHistoryItemModel> latestItems;
  final List<RedditInterseccionSnapshotModel> snapshots;

  const RedditInterseccionHistoryModel({
    required this.sourceMode,
    required this.snapshotCount,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
    required this.coveragePct,
    required this.comparableCount,
    required this.itemCount,
    required this.summary,
    required this.latestItems,
    required this.snapshots,
  });

  factory RedditInterseccionHistoryModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawLatestItems =
        (map['latest_items'] as List?) ?? const <dynamic>[];
    final List<dynamic> rawSnapshots =
        (map['snapshots'] as List?) ?? const <dynamic>[];

    return RedditInterseccionHistoryModel(
      sourceMode: _parseString(map['source_mode']),
      snapshotCount: _parseInt(map['snapshot_count']),
      latestSnapshotDate: _parseString(map['latest_snapshot_date']).isEmpty
          ? null
          : _parseString(map['latest_snapshot_date']),
      previousSnapshotDate: _parseString(map['previous_snapshot_date']).isEmpty
          ? null
          : _parseString(map['previous_snapshot_date']),
      coveragePct: _parseDouble(map['coverage_pct']),
      comparableCount: _parseInt(map['comparable_count']),
      itemCount: _parseInt(map['item_count']),
      summary: RedditInterseccionSummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      latestItems: rawLatestItems
          .whereType<Map>()
          .map(
            (item) => RedditInterseccionHistoryItemModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      snapshots: rawSnapshots
          .whereType<Map>()
          .map(
            (item) => RedditInterseccionSnapshotModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}
