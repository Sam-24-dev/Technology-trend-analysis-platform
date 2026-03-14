class HomeHighlightModel {
  final String dashboard;
  final int graph;
  final String signal;
  final String source;
  final String entity;
  final String entityKey;
  final double score;
  final Map<String, dynamic> payload;

  const HomeHighlightModel({
    required this.dashboard,
    required this.graph,
    required this.signal,
    required this.source,
    required this.entity,
    required this.entityKey,
    required this.score,
    required this.payload,
  });

  factory HomeHighlightModel.fromMap(Map<String, dynamic> map) {
    return HomeHighlightModel(
      dashboard: map['dashboard']?.toString() ?? '',
      graph: int.tryParse(map['graph']?.toString() ?? '0') ?? 0,
      signal: map['signal']?.toString() ?? '',
      source: map['source']?.toString() ?? '',
      entity: map['entity']?.toString() ?? '',
      entityKey: map['entity_key']?.toString() ?? '',
      score: double.tryParse(map['score']?.toString() ?? '0') ?? 0.0,
      payload:
          (map['payload'] as Map?)?.cast<String, dynamic>() ??
          const <String, dynamic>{},
    );
  }
}

class HomeHighlightsPayloadModel {
  final String generatedAtUtc;
  final String dataset;
  final String sourceMode;
  final int candidateCount;
  final List<HomeHighlightModel> highlights;

  const HomeHighlightsPayloadModel({
    required this.generatedAtUtc,
    required this.dataset,
    required this.sourceMode,
    required this.candidateCount,
    required this.highlights,
  });

  factory HomeHighlightsPayloadModel.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawHighlights =
        (map['highlights'] as List?) ?? const <dynamic>[];
    return HomeHighlightsPayloadModel(
      generatedAtUtc: map['generated_at_utc']?.toString() ?? '',
      dataset: map['dataset']?.toString() ?? '',
      sourceMode: map['source_mode']?.toString() ?? '',
      candidateCount:
          int.tryParse(map['candidate_count']?.toString() ?? '0') ?? 0,
      highlights: rawHighlights
          .whereType<Map>()
          .map(
            (dynamic item) =>
                HomeHighlightModel.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}
