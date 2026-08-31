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

const List<String> kFreshnessSources = <String>[
  'github',
  'stackoverflow',
  'reddit',
];

const Map<String, String> _sourceLabels = <String, String>{
  'github': 'GitHub',
  'stackoverflow': 'Stack Overflow',
  'reddit': 'Reddit',
};

const Map<String, String> _sourceDatasetPrefixes = <String, String>{
  'github': 'github_',
  'stackoverflow': 'so_',
  'reddit': 'reddit_',
};

String buildSourceFreshnessLabel(RunManifestPublic? manifest, String source) {
  final String label = _sourceLabels[source] ?? source;
  final DateTime? updatedAt = _resolveSourceFreshness(manifest, source);
  if (updatedAt == null) {
    return '$label: no disponible';
  }
  final DateTime utc = updatedAt.toUtc();
  final String day = utc.day.toString().padLeft(2, '0');
  final String month = utc.month.toString().padLeft(2, '0');
  return '$label: $day/$month/${utc.year} UTC';
}

List<String> buildSourceFreshnessLabels(RunManifestPublic? manifest) {
  return kFreshnessSources
      .map((String source) => buildSourceFreshnessLabel(manifest, source))
      .toList(growable: false);
}

DateTime? _resolveSourceFreshness(RunManifestPublic? manifest, String source) {
  final String? prefix = _sourceDatasetPrefixes[source];
  if (manifest == null || prefix == null) {
    return null;
  }

  DateTime? latestUpdate;
  for (final RunManifestDatasetSummary dataset in manifest.datasetSummaries) {
    if (!dataset.dataset.startsWith(prefix)) {
      continue;
    }
    final DateTime? parsed = _parseUtcTimestamp(dataset.updatedAtUtc);
    if (parsed != null &&
        (latestUpdate == null || parsed.isAfter(latestUpdate))) {
      latestUpdate = parsed;
    }
  }
  return latestUpdate;
}

DateTime? _parseUtcTimestamp(String value) {
  if (!value.endsWith('Z')) {
    return null;
  }
  return DateTime.tryParse(value)?.toUtc();
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
