import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/run_manifest_models.dart';

void main() {
  test('RunManifestPublic.fromMap parses expected fields', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-02-23T10:00:00Z',
      'source_window_start_utc': '2025-02-23T00:00:00Z',
      'source_window_end_utc': '2026-02-23T00:00:00Z',
      'quality_gate_status': 'pass_with_warnings',
      'degraded_mode': true,
      'available_sources': ['github', 'stackoverflow'],
      'dataset_summaries': [
        {
          'dataset': 'trend_score',
          'row_count': 23,
          'quality_status': 'pass',
          'updated_at_utc': '2026-02-23T09:59:30Z',
        },
      ],
      'notes': 'Reddit temporalmente no disponible',
    });

    expect(manifest.manifestVersion, '1.0.0');
    expect(manifest.qualityGateStatus, 'pass_with_warnings');
    expect(manifest.degradedMode, true);
    expect(manifest.availableSources, ['github', 'stackoverflow']);
    expect(manifest.datasetSummaries.length, 1);
    expect(manifest.datasetSummaries.first.dataset, 'trend_score');
    expect(manifest.notes, isNotNull);
  });

  test('RunManifestDatasetSummary.fromMap handles invalid row_count', () {
    final summary = RunManifestDatasetSummary.fromMap({
      'dataset': 'trend_score',
      'row_count': 'invalid',
      'quality_status': 'warning',
      'updated_at_utc': '2026-02-23T09:59:30Z',
    });

    expect(summary.dataset, 'trend_score');
    expect(summary.rowCount, 0);
    expect(summary.qualityStatus, 'warning');
  });
}
