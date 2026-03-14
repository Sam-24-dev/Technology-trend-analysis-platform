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
      'total_repos_extraidos': 1000,
      'total_repos_clasificables': 925,
      'so_languages_count': 10,
      'notes': 'Reddit temporalmente no disponible',
    });

    expect(manifest.manifestVersion, '1.0.0');
    expect(manifest.qualityGateStatus, 'pass_with_warnings');
    expect(manifest.degradedMode, true);
    expect(manifest.availableSources, ['github', 'stackoverflow']);
    expect(manifest.datasetSummaries.length, 1);
    expect(manifest.datasetSummaries.first.dataset, 'trend_score');
    expect(manifest.totalReposExtraidos, 1000);
    expect(manifest.totalReposClasificables, 925);
    expect(manifest.soLanguagesCount, 10);
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

  test('buildAnalysisPeriodLabel returns normalized copy', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-02-23T10:00:00Z',
      'source_window_start_utc': '2025-02-23T00:00:00Z',
      'source_window_end_utc': '2026-02-23T00:00:00Z',
      'quality_gate_status': 'pass',
      'degraded_mode': false,
      'available_sources': [],
      'dataset_summaries': [],
      'total_repos_extraidos': 0,
      'total_repos_clasificables': 0,
      'so_languages_count': 0,
    });

    expect(
      buildAnalysisPeriodLabel(manifest),
      'Período de análisis: 2025-2026',
    );
  });

  test('buildLastUpdatedLabel returns date only', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-02-27T05:11:00Z',
      'source_window_start_utc': '2025-02-27T00:00:00Z',
      'source_window_end_utc': '2026-02-27T00:00:00Z',
      'quality_gate_status': 'pass',
      'degraded_mode': false,
      'available_sources': [],
      'dataset_summaries': [],
      'total_repos_extraidos': 0,
      'total_repos_clasificables': 0,
      'so_languages_count': 0,
    });

    expect(
      buildLastUpdatedLabel(manifest),
      'Última actualización (UTC): 27/02/2026',
    );
  });
}
