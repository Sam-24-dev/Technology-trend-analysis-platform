int _parseInt(dynamic value, {int defaultValue = 0}) {
  return int.tryParse(value?.toString() ?? '') ?? defaultValue;
}

double _parseDouble(dynamic value, {double defaultValue = 0.0}) {
  return double.tryParse(value?.toString() ?? '') ?? defaultValue;
}

String? _parseOptionalString(dynamic value) {
  final String text = value?.toString().trim() ?? '';
  return text.isEmpty ? null : text;
}

class VolumenPreguntasModel {
  final String lenguaje;
  final int preguntas;
  final int preguntasPrev;
  final int deltaPreguntas;
  final double growthPct;
  final String? trendDirection;
  final double sharePct;

  const VolumenPreguntasModel({
    required this.lenguaje,
    required this.preguntas,
    this.preguntasPrev = 0,
    this.deltaPreguntas = 0,
    this.growthPct = 0.0,
    this.trendDirection,
    this.sharePct = 0.0,
  });

  factory VolumenPreguntasModel.fromMap(Map<String, dynamic> map) {
    return VolumenPreguntasModel(
      lenguaje: map['lenguaje']?.toString() ?? 'Desconocido',
      preguntas: _parseInt(map['preguntas_nuevas_2025']),
    );
  }

  factory VolumenPreguntasModel.fromHistoryMap(Map<String, dynamic> map) {
    return VolumenPreguntasModel(
      lenguaje: map['lenguaje']?.toString() ?? 'Desconocido',
      preguntas: _parseInt(map['preguntas']),
      preguntasPrev: _parseInt(map['preguntas_prev']),
      deltaPreguntas: _parseInt(map['delta_preguntas']),
      growthPct: _parseDouble(map['growth_pct']),
      trendDirection: _parseOptionalString(map['trend_direction']),
      sharePct: _parseDouble(map['share_pct']),
    );
  }
}

class StackOverflowVolumeHistorySummaryModel {
  final VolumenPreguntasModel? leader;
  final VolumenPreguntasModel? highestGrowth;
  final VolumenPreguntasModel? largestDrop;
  final int totalQuestions;

  const StackOverflowVolumeHistorySummaryModel({
    required this.leader,
    required this.highestGrowth,
    required this.largestDrop,
    required this.totalQuestions,
  });

  factory StackOverflowVolumeHistorySummaryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    VolumenPreguntasModel? parseItem(String key) {
      final dynamic raw = map[key];
      if (raw is! Map) {
        return null;
      }
      return VolumenPreguntasModel.fromHistoryMap(raw.cast<String, dynamic>());
    }

    return StackOverflowVolumeHistorySummaryModel(
      leader: parseItem('leader'),
      highestGrowth: parseItem('highest_growth'),
      largestDrop: parseItem('largest_drop'),
      totalQuestions: _parseInt(map['total_questions']),
    );
  }
}

class StackOverflowVolumeHistorySnapshotModel {
  final String date;
  final String? path;
  final String? sourceType;
  final int itemCount;
  final int totalQuestions;
  final List<VolumenPreguntasModel> items;

  const StackOverflowVolumeHistorySnapshotModel({
    required this.date,
    required this.path,
    required this.sourceType,
    required this.itemCount,
    required this.totalQuestions,
    required this.items,
  });

  factory StackOverflowVolumeHistorySnapshotModel.fromMap(
    Map<String, dynamic> map,
  ) {
    final List<dynamic> rawItems = (map['items'] as List?) ?? const [];
    return StackOverflowVolumeHistorySnapshotModel(
      date: map['date']?.toString() ?? '',
      path: _parseOptionalString(map['path']),
      sourceType: _parseOptionalString(map['source_type']),
      itemCount: _parseInt(map['item_count']),
      totalQuestions: _parseInt(map['total_questions']),
      items: rawItems
          .whereType<Map>()
          .map(
            (dynamic item) => VolumenPreguntasModel.fromHistoryMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class StackOverflowVolumeHistoryModel {
  final String sourceMode;
  final int snapshotCount;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;
  final bool hasHistoricalComparison;
  final int itemCount;
  final StackOverflowVolumeHistorySummaryModel summary;
  final List<VolumenPreguntasModel> latestItems;
  final List<StackOverflowVolumeHistorySnapshotModel> snapshots;

  const StackOverflowVolumeHistoryModel({
    required this.sourceMode,
    required this.snapshotCount,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
    required this.hasHistoricalComparison,
    required this.itemCount,
    required this.summary,
    required this.latestItems,
    required this.snapshots,
  });

  factory StackOverflowVolumeHistoryModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawLatest = (map['latest_items'] as List?) ?? const [];
    final List<dynamic> rawSnapshots = (map['snapshots'] as List?) ?? const [];
    return StackOverflowVolumeHistoryModel(
      sourceMode: map['source_mode']?.toString() ?? '',
      snapshotCount: _parseInt(map['snapshot_count']),
      latestSnapshotDate: _parseOptionalString(map['latest_snapshot_date']),
      previousSnapshotDate: _parseOptionalString(map['previous_snapshot_date']),
      hasHistoricalComparison:
          map['has_historical_comparison']?.toString().toLowerCase() == 'true',
      itemCount: _parseInt(map['item_count']),
      summary: StackOverflowVolumeHistorySummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      latestItems: rawLatest
          .whereType<Map>()
          .map(
            (dynamic item) => VolumenPreguntasModel.fromHistoryMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      snapshots: rawSnapshots
          .whereType<Map>()
          .map(
            (dynamic item) => StackOverflowVolumeHistorySnapshotModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class TasaAceptacionModel {
  final String tecnologia;
  final double tasaPct;
  final int totalPreguntas;
  final int respuestasAceptadas;
  final int totalPreguntasPrev;
  final int respuestasAceptadasPrev;
  final double tasaAceptacionPrevPct;
  final double deltaTasaPct;
  final int deltaPreguntas;
  final String? sampleBucket;
  final double confidenceScore;
  final int rawRank;
  final int confidenceRank;

  const TasaAceptacionModel({
    required this.tecnologia,
    required this.tasaPct,
    required this.totalPreguntas,
    this.respuestasAceptadas = 0,
    this.totalPreguntasPrev = 0,
    this.respuestasAceptadasPrev = 0,
    this.tasaAceptacionPrevPct = 0.0,
    this.deltaTasaPct = 0.0,
    this.deltaPreguntas = 0,
    this.sampleBucket,
    this.confidenceScore = 0.0,
    this.rawRank = 0,
    this.confidenceRank = 0,
  });

  factory TasaAceptacionModel.fromMap(Map<String, dynamic> map) {
    return TasaAceptacionModel(
      tecnologia: map['tecnologia']?.toString() ?? '',
      tasaPct: _parseDouble(map['tasa_aceptacion_pct']),
      totalPreguntas: _parseInt(map['total_preguntas']),
      respuestasAceptadas: _parseInt(map['respuestas_aceptadas']),
    );
  }

  factory TasaAceptacionModel.fromHistoryMap(Map<String, dynamic> map) {
    return TasaAceptacionModel(
      tecnologia: map['tecnologia']?.toString() ?? '',
      tasaPct: _parseDouble(map['tasa_aceptacion_pct']),
      totalPreguntas: _parseInt(map['total_preguntas']),
      respuestasAceptadas: _parseInt(map['respuestas_aceptadas']),
      totalPreguntasPrev: _parseInt(map['total_preguntas_prev']),
      respuestasAceptadasPrev: _parseInt(map['respuestas_aceptadas_prev']),
      tasaAceptacionPrevPct: _parseDouble(map['tasa_aceptacion_prev_pct']),
      deltaTasaPct: _parseDouble(map['delta_tasa_pct']),
      deltaPreguntas: _parseInt(map['delta_preguntas']),
      sampleBucket: _parseOptionalString(map['sample_bucket']),
      confidenceScore: _parseDouble(map['confidence_score']),
      rawRank: _parseInt(map['raw_rank']),
      confidenceRank: _parseInt(map['confidence_rank']),
    );
  }
}

class StackOverflowAcceptanceHistorySummaryModel {
  final TasaAceptacionModel? rawLeader;
  final TasaAceptacionModel? confidenceLeader;
  final TasaAceptacionModel? highestImprovement;
  final TasaAceptacionModel? largestDrop;
  final TasaAceptacionModel? largestSample;

  const StackOverflowAcceptanceHistorySummaryModel({
    required this.rawLeader,
    required this.confidenceLeader,
    required this.highestImprovement,
    required this.largestDrop,
    required this.largestSample,
  });

  factory StackOverflowAcceptanceHistorySummaryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    TasaAceptacionModel? parseItem(String key) {
      final dynamic raw = map[key];
      if (raw is! Map) {
        return null;
      }
      return TasaAceptacionModel.fromHistoryMap(raw.cast<String, dynamic>());
    }

    return StackOverflowAcceptanceHistorySummaryModel(
      rawLeader: parseItem('raw_leader'),
      confidenceLeader: parseItem('confidence_leader'),
      highestImprovement: parseItem('highest_improvement'),
      largestDrop: parseItem('largest_drop'),
      largestSample: parseItem('largest_sample'),
    );
  }
}

class StackOverflowAcceptanceHistorySnapshotModel {
  final String date;
  final String? path;
  final String? sourceType;
  final int itemCount;
  final List<TasaAceptacionModel> items;

  const StackOverflowAcceptanceHistorySnapshotModel({
    required this.date,
    required this.path,
    required this.sourceType,
    required this.itemCount,
    required this.items,
  });

  factory StackOverflowAcceptanceHistorySnapshotModel.fromMap(
    Map<String, dynamic> map,
  ) {
    final List<dynamic> rawItems = (map['items'] as List?) ?? const [];
    return StackOverflowAcceptanceHistorySnapshotModel(
      date: map['date']?.toString() ?? '',
      path: _parseOptionalString(map['path']),
      sourceType: _parseOptionalString(map['source_type']),
      itemCount: _parseInt(map['item_count']),
      items: rawItems
          .whereType<Map>()
          .map(
            (dynamic item) => TasaAceptacionModel.fromHistoryMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
    );
  }
}

class StackOverflowAcceptanceHistoryModel {
  final String sourceMode;
  final int snapshotCount;
  final String? latestSnapshotDate;
  final String? previousSnapshotDate;
  final bool hasHistoricalComparison;
  final int itemCount;
  final StackOverflowAcceptanceHistorySummaryModel summary;
  final List<TasaAceptacionModel> latestItems;
  final List<StackOverflowAcceptanceHistorySnapshotModel> snapshots;

  const StackOverflowAcceptanceHistoryModel({
    required this.sourceMode,
    required this.snapshotCount,
    required this.latestSnapshotDate,
    required this.previousSnapshotDate,
    required this.hasHistoricalComparison,
    required this.itemCount,
    required this.summary,
    required this.latestItems,
    required this.snapshots,
  });

  factory StackOverflowAcceptanceHistoryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    final List<dynamic> rawLatest = (map['latest_items'] as List?) ?? const [];
    final List<dynamic> rawSnapshots = (map['snapshots'] as List?) ?? const [];
    return StackOverflowAcceptanceHistoryModel(
      sourceMode: map['source_mode']?.toString() ?? '',
      snapshotCount: _parseInt(map['snapshot_count']),
      latestSnapshotDate: _parseOptionalString(map['latest_snapshot_date']),
      previousSnapshotDate: _parseOptionalString(map['previous_snapshot_date']),
      hasHistoricalComparison:
          map['has_historical_comparison']?.toString().toLowerCase() == 'true',
      itemCount: _parseInt(map['item_count']),
      summary: StackOverflowAcceptanceHistorySummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
      latestItems: rawLatest
          .whereType<Map>()
          .map(
            (dynamic item) => TasaAceptacionModel.fromHistoryMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      snapshots: rawSnapshots
          .whereType<Map>()
          .map(
            (dynamic item) =>
                StackOverflowAcceptanceHistorySnapshotModel.fromMap(
                  item.cast<String, dynamic>(),
                ),
          )
          .toList(),
    );
  }
}

class TendenciaMensualModel {
  final String mes;
  final int python;
  final int javascript;
  final int typescript;

  const TendenciaMensualModel({
    required this.mes,
    required this.python,
    required this.javascript,
    required this.typescript,
  });

  factory TendenciaMensualModel.fromMap(Map<String, dynamic> map) {
    return TendenciaMensualModel(
      mes: map['mes']?.toString() ?? '',
      python: _parseInt(map['python']),
      javascript: _parseInt(map['javascript']),
      typescript: _parseInt(map['typescript']),
    );
  }
}

class StackOverflowTrendSeriesModel {
  final String tecnologia;
  final List<int> points;
  final int startValue;
  final int endValue;
  final int absDelta;
  final double pctDelta;
  final double retentionPct;
  final String peakMonth;
  final int peakValue;
  final int latestRank;

  const StackOverflowTrendSeriesModel({
    required this.tecnologia,
    required this.points,
    required this.startValue,
    required this.endValue,
    required this.absDelta,
    required this.pctDelta,
    required this.retentionPct,
    required this.peakMonth,
    required this.peakValue,
    required this.latestRank,
  });

  factory StackOverflowTrendSeriesModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawPoints = (map['points'] as List?) ?? const [];
    return StackOverflowTrendSeriesModel(
      tecnologia: map['tecnologia']?.toString() ?? '',
      points: rawPoints.map((dynamic point) => _parseInt(point)).toList(),
      startValue: _parseInt(map['start_value']),
      endValue: _parseInt(map['end_value']),
      absDelta: _parseInt(map['abs_delta']),
      pctDelta: _parseDouble(map['pct_delta']),
      retentionPct: _parseDouble(map['retention_pct']),
      peakMonth: map['peak_month']?.toString() ?? '',
      peakValue: _parseInt(map['peak_value']),
      latestRank: _parseInt(map['latest_rank']),
    );
  }
}

class StackOverflowTrendSummaryEntryModel {
  final String tecnologia;
  final int startValue;
  final int endValue;
  final int absDelta;
  final double pctDelta;
  final double retentionPct;
  final String peakMonth;
  final int peakValue;
  final int latestRank;

  const StackOverflowTrendSummaryEntryModel({
    required this.tecnologia,
    required this.startValue,
    required this.endValue,
    required this.absDelta,
    required this.pctDelta,
    required this.retentionPct,
    required this.peakMonth,
    required this.peakValue,
    required this.latestRank,
  });

  factory StackOverflowTrendSummaryEntryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return StackOverflowTrendSummaryEntryModel(
      tecnologia: map['tecnologia']?.toString() ?? '',
      startValue: _parseInt(map['start_value']),
      endValue: _parseInt(map['end_value']),
      absDelta: _parseInt(map['abs_delta']),
      pctDelta: _parseDouble(map['pct_delta']),
      retentionPct: _parseDouble(map['retention_pct']),
      peakMonth: map['peak_month']?.toString() ?? '',
      peakValue: _parseInt(map['peak_value']),
      latestRank: _parseInt(map['latest_rank']),
    );
  }
}

class StackOverflowTrendsHistorySummaryModel {
  final StackOverflowTrendSummaryEntryModel? currentLeader;
  final StackOverflowTrendSummaryEntryModel? bestRetention;
  final StackOverflowTrendSummaryEntryModel? largestRelativeDrop;
  final StackOverflowTrendSummaryEntryModel? largestAbsoluteDrop;

  const StackOverflowTrendsHistorySummaryModel({
    required this.currentLeader,
    required this.bestRetention,
    required this.largestRelativeDrop,
    required this.largestAbsoluteDrop,
  });

  factory StackOverflowTrendsHistorySummaryModel.fromMap(
    Map<String, dynamic> map,
  ) {
    StackOverflowTrendSummaryEntryModel? parseItem(String key) {
      final dynamic raw = map[key];
      if (raw is! Map) {
        return null;
      }
      return StackOverflowTrendSummaryEntryModel.fromMap(
        raw.cast<String, dynamic>(),
      );
    }

    return StackOverflowTrendsHistorySummaryModel(
      currentLeader: parseItem('current_leader'),
      bestRetention: parseItem('best_retention'),
      largestRelativeDrop: parseItem('largest_relative_drop'),
      largestAbsoluteDrop: parseItem('largest_absolute_drop'),
    );
  }
}

class StackOverflowTrendsHistoryModel {
  final String sourceMode;
  final int snapshotCount;
  final List<String> months;
  final List<StackOverflowTrendSeriesModel> series;
  final StackOverflowTrendsHistorySummaryModel summary;

  const StackOverflowTrendsHistoryModel({
    required this.sourceMode,
    required this.snapshotCount,
    required this.months,
    required this.series,
    required this.summary,
  });

  factory StackOverflowTrendsHistoryModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawSeries = (map['series'] as List?) ?? const [];
    final List<dynamic> rawMonths = (map['months'] as List?) ?? const [];
    return StackOverflowTrendsHistoryModel(
      sourceMode: map['source_mode']?.toString() ?? '',
      snapshotCount: _parseInt(map['snapshot_count']),
      months: rawMonths.map((dynamic month) => month.toString()).toList(),
      series: rawSeries
          .whereType<Map>()
          .map(
            (dynamic item) => StackOverflowTrendSeriesModel.fromMap(
              item.cast<String, dynamic>(),
            ),
          )
          .toList(),
      summary: StackOverflowTrendsHistorySummaryModel.fromMap(
        (map['summary'] as Map?)?.cast<String, dynamic>() ??
            const <String, dynamic>{},
      ),
    );
  }

  factory StackOverflowTrendsHistoryModel.fromLegacy(
    List<TendenciaMensualModel> source,
  ) {
    final List<String> months = source.map((item) => item.mes).toList();
    final List<StackOverflowTrendSeriesModel> series =
        <StackOverflowTrendSeriesModel>[
          _buildLegacySeries(
            tecnologia: 'Python',
            points: source.map((item) => item.python).toList(),
            months: months,
          ),
          _buildLegacySeries(
            tecnologia: 'JavaScript',
            points: source.map((item) => item.javascript).toList(),
            months: months,
          ),
          _buildLegacySeries(
            tecnologia: 'TypeScript',
            points: source.map((item) => item.typescript).toList(),
            months: months,
          ),
        ];
    final List<StackOverflowTrendSeriesModel> ranked =
        List<StackOverflowTrendSeriesModel>.from(series)
          ..sort((a, b) => b.endValue.compareTo(a.endValue));
    final Map<String, int> ranks = <String, int>{
      for (int index = 0; index < ranked.length; index++)
        ranked[index].tecnologia: index + 1,
    };
    final List<StackOverflowTrendSeriesModel> normalizedSeries = series
        .map(
          (item) => StackOverflowTrendSeriesModel(
            tecnologia: item.tecnologia,
            points: item.points,
            startValue: item.startValue,
            endValue: item.endValue,
            absDelta: item.absDelta,
            pctDelta: item.pctDelta,
            retentionPct: item.retentionPct,
            peakMonth: item.peakMonth,
            peakValue: item.peakValue,
            latestRank: ranks[item.tecnologia] ?? item.latestRank,
          ),
        )
        .toList();

    final StackOverflowTrendSeriesModel? currentLeader =
        normalizedSeries.isEmpty
        ? null
        : normalizedSeries.reduce((a, b) => a.endValue >= b.endValue ? a : b);
    final StackOverflowTrendSeriesModel? bestRetention =
        normalizedSeries.isEmpty
        ? null
        : normalizedSeries.reduce(
            (a, b) => a.retentionPct >= b.retentionPct ? a : b,
          );
    final StackOverflowTrendSeriesModel? largestRelativeDrop =
        normalizedSeries.isEmpty
        ? null
        : normalizedSeries.reduce((a, b) => a.pctDelta <= b.pctDelta ? a : b);
    final StackOverflowTrendSeriesModel? largestAbsoluteDrop =
        normalizedSeries.isEmpty
        ? null
        : normalizedSeries.reduce((a, b) => a.absDelta <= b.absDelta ? a : b);

    StackOverflowTrendSummaryEntryModel? toSummary(
      StackOverflowTrendSeriesModel? item,
    ) {
      if (item == null) {
        return null;
      }
      return StackOverflowTrendSummaryEntryModel(
        tecnologia: item.tecnologia,
        startValue: item.startValue,
        endValue: item.endValue,
        absDelta: item.absDelta,
        pctDelta: item.pctDelta,
        retentionPct: item.retentionPct,
        peakMonth: item.peakMonth,
        peakValue: item.peakValue,
        latestRank: item.latestRank,
      );
    }

    return StackOverflowTrendsHistoryModel(
      sourceMode: 'csv_fallback',
      snapshotCount: 1,
      months: months,
      series: normalizedSeries,
      summary: StackOverflowTrendsHistorySummaryModel(
        currentLeader: toSummary(currentLeader),
        bestRetention: toSummary(bestRetention),
        largestRelativeDrop: toSummary(largestRelativeDrop),
        largestAbsoluteDrop: toSummary(largestAbsoluteDrop),
      ),
    );
  }

  static StackOverflowTrendSeriesModel _buildLegacySeries({
    required String tecnologia,
    required List<int> points,
    required List<String> months,
  }) {
    final int startValue = points.isEmpty ? 0 : points.first;
    final int endValue = points.isEmpty ? 0 : points.last;
    final int absDelta = endValue - startValue;
    final double pctDelta = startValue == 0
        ? 0.0
        : ((endValue - startValue) / startValue) * 100;
    final double retentionPct = startValue == 0
        ? 0.0
        : (endValue / startValue) * 100;
    int peakValue = 0;
    String peakMonth = months.isEmpty ? '' : months.first;
    for (int index = 0; index < points.length; index++) {
      if (index == 0 || points[index] > peakValue) {
        peakValue = points[index];
        peakMonth = months[index];
      }
    }
    return StackOverflowTrendSeriesModel(
      tecnologia: tecnologia,
      points: points,
      startValue: startValue,
      endValue: endValue,
      absDelta: absDelta,
      pctDelta: pctDelta,
      retentionPct: retentionPct,
      peakMonth: peakMonth,
      peakValue: peakValue,
      latestRank: 0,
    );
  }
}
