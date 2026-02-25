class RunManifestDatasetSummary {
  final String dataset;
  final int rowCount;
  final String qualityStatus;
  final String updatedAtUtc;

  const RunManifestDatasetSummary({
    required this.dataset,
    required this.rowCount,
    required this.qualityStatus,
    required this.updatedAtUtc,
  });

  factory RunManifestDatasetSummary.fromMap(Map<String, dynamic> map) {
    return RunManifestDatasetSummary(
      dataset: map['dataset']?.toString() ?? '',
      rowCount: int.tryParse(map['row_count']?.toString() ?? '0') ?? 0,
      qualityStatus: map['quality_status']?.toString() ?? 'warning',
      updatedAtUtc: map['updated_at_utc']?.toString() ?? '',
    );
  }
}

class RunManifestPublic {
  final String manifestVersion;
  final String generatedAtUtc;
  final String sourceWindowStartUtc;
  final String sourceWindowEndUtc;
  final String qualityGateStatus;
  final bool degradedMode;
  final List<String> availableSources;
  final List<RunManifestDatasetSummary> datasetSummaries;
  final String? notes;

  const RunManifestPublic({
    required this.manifestVersion,
    required this.generatedAtUtc,
    required this.sourceWindowStartUtc,
    required this.sourceWindowEndUtc,
    required this.qualityGateStatus,
    required this.degradedMode,
    required this.availableSources,
    required this.datasetSummaries,
    required this.notes,
  });

  factory RunManifestPublic.fromMap(Map<String, dynamic> map) {
    final rawSources = (map['available_sources'] as List?) ?? const [];
    final rawDatasets = (map['dataset_summaries'] as List?) ?? const [];

    return RunManifestPublic(
      manifestVersion: map['manifest_version']?.toString() ?? '',
      generatedAtUtc: map['generated_at_utc']?.toString() ?? '',
      sourceWindowStartUtc: map['source_window_start_utc']?.toString() ?? '',
      sourceWindowEndUtc: map['source_window_end_utc']?.toString() ?? '',
      qualityGateStatus: map['quality_gate_status']?.toString() ?? 'unknown',
      degradedMode: map['degraded_mode'] == true,
      availableSources: rawSources.map((item) => item.toString()).toList(),
      datasetSummaries: rawDatasets
          .whereType<Map>()
          .map(
            (item) =>
                RunManifestDatasetSummary.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
      notes: map['notes']?.toString(),
    );
  }
}
