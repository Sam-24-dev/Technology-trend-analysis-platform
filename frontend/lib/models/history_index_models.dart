class HistorySnapshotEntry {
  final String date;
  final String path;
  final int? rowCount;

  const HistorySnapshotEntry({
    required this.date,
    required this.path,
    required this.rowCount,
  });

  factory HistorySnapshotEntry.fromMap(Map<String, dynamic> map) {
    final rawRowCount = map['row_count'];
    return HistorySnapshotEntry(
      date: map['date']?.toString() ?? '',
      path: map['path']?.toString() ?? '',
      rowCount: rawRowCount == null
          ? null
          : int.tryParse(rawRowCount.toString()),
    );
  }
}

class HistoryDatasetEntry {
  final String dataset;
  final String? latestPath;
  final int? latestRowCount;
  final int historySnapshotCount;
  final List<HistorySnapshotEntry> snapshots;

  const HistoryDatasetEntry({
    required this.dataset,
    required this.latestPath,
    required this.latestRowCount,
    required this.historySnapshotCount,
    required this.snapshots,
  });

  factory HistoryDatasetEntry.fromMap(Map<String, dynamic> map) {
    final rawSnapshots = (map['snapshots'] as List?) ?? const [];
    final rawLatestRowCount = map['latest_row_count'];
    return HistoryDatasetEntry(
      dataset: map['dataset']?.toString() ?? '',
      latestPath: map['latest_path']?.toString(),
      latestRowCount: rawLatestRowCount == null
          ? null
          : int.tryParse(rawLatestRowCount.toString()),
      historySnapshotCount:
          int.tryParse(map['history_snapshot_count']?.toString() ?? '0') ?? 0,
      snapshots: rawSnapshots
          .whereType<Map>()
          .map(
            (item) =>
                HistorySnapshotEntry.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}

class HistoryIndexModel {
  final String generatedAtUtc;
  final int datasetCount;
  final List<HistoryDatasetEntry> datasets;

  const HistoryIndexModel({
    required this.generatedAtUtc,
    required this.datasetCount,
    required this.datasets,
  });

  factory HistoryIndexModel.fromMap(Map<String, dynamic> map) {
    final rawDatasets = (map['datasets'] as List?) ?? const [];
    return HistoryIndexModel(
      generatedAtUtc: map['generated_at_utc']?.toString() ?? '',
      datasetCount: int.tryParse(map['dataset_count']?.toString() ?? '0') ?? 0,
      datasets: rawDatasets
          .whereType<Map>()
          .map(
            (item) => HistoryDatasetEntry.fromMap(item.cast<String, dynamic>()),
          )
          .toList(),
    );
  }
}
