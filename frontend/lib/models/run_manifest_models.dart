const String kAnalysisPeriodFallbackLabel =
    'Per\u00EDodo de an\u00E1lisis: \u00FAltimos 12 meses';

String buildAnalysisPeriodLabel(RunManifestPublic? manifest) {
  if (manifest == null) {
    return kAnalysisPeriodFallbackLabel;
  }
  final DateTime? start = DateTime.tryParse(manifest.sourceWindowStartUtc);
  final DateTime? end = DateTime.tryParse(manifest.sourceWindowEndUtc);
  if (start == null || end == null) {
    return kAnalysisPeriodFallbackLabel;
  }
  return 'Per\u00EDodo de an\u00E1lisis: ${start.year}-${end.year}';
}

String buildLastUpdatedLabel(RunManifestPublic? manifest) {
  final DateTime? reference = _resolveLastUpdatedReference(manifest);
  if (reference == null) {
    return '\u00DAltima actualizaci\u00F3n (UTC): no disponible';
  }
  final DateTime utc = reference.toUtc();
  final String day = utc.day.toString().padLeft(2, '0');
  final String month = utc.month.toString().padLeft(2, '0');
  return '\u00DAltima actualizaci\u00F3n (UTC): $day/$month/${utc.year}';
}

DateTime? _resolveLastUpdatedReference(RunManifestPublic? manifest) {
  if (manifest == null) {
    return null;
  }

  DateTime? latestDatasetUpdate;
  for (final RunManifestDatasetSummary dataset in manifest.datasetSummaries) {
    final DateTime? parsed = DateTime.tryParse(dataset.updatedAtUtc);
    if (parsed == null) {
      continue;
    }
    if (latestDatasetUpdate == null || parsed.isAfter(latestDatasetUpdate)) {
      latestDatasetUpdate = parsed;
    }
  }
  if (latestDatasetUpdate != null) {
    return latestDatasetUpdate;
  }

  final DateTime? sourceEnd = DateTime.tryParse(manifest.sourceWindowEndUtc);
  if (sourceEnd != null) {
    return sourceEnd;
  }

  return DateTime.tryParse(manifest.generatedAtUtc);
}

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
  final int totalReposExtraidos;
  final int totalReposClasificables;
  final int soLanguagesCount;
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
    required this.totalReposExtraidos,
    required this.totalReposClasificables,
    required this.soLanguagesCount,
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
      totalReposExtraidos:
          int.tryParse(map['total_repos_extraidos']?.toString() ?? '0') ?? 0,
      totalReposClasificables:
          int.tryParse(map['total_repos_clasificables']?.toString() ?? '0') ??
          0,
      soLanguagesCount:
          int.tryParse(map['so_languages_count']?.toString() ?? '0') ?? 0,
      notes: map['notes']?.toString(),
    );
  }
}
