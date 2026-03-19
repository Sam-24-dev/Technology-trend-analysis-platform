import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/models/run_manifest_models.dart';

void main() {
  test('RunManifestPublic.fromMap parses public payload', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-02-27T05:11:00Z',
      'source_window_start_utc': '2025-02-27T00:00:00Z',
      'source_window_end_utc': '2026-02-27T00:00:00Z',
      'quality_gate_status': 'pass',
      'degraded_mode': false,
      'available_sources': ['github', 'stackoverflow'],
      'dataset_summaries': [
        {
          'dataset': 'trend_score',
          'row_count': 23,
          'quality_status': 'pass',
          'updated_at_utc': '2026-02-27T05:00:00Z',
        },
      ],
      'total_repos_extraidos': 1200,
      'total_repos_clasificables': 928,
      'so_languages_count': 10,
      'notes': 'ok',
    });

    expect(manifest.manifestVersion, '1.0.0');
    expect(manifest.generatedAtUtc, '2026-02-27T05:11:00Z');
    expect(manifest.availableSources, ['github', 'stackoverflow']);
    expect(manifest.datasetSummaries, hasLength(1));
    expect(manifest.datasetSummaries.first.dataset, 'trend_score');
    expect(manifest.datasetSummaries.first.rowCount, 23);
    expect(manifest.totalReposExtraidos, 1200);
    expect(manifest.totalReposClasificables, 928);
    expect(manifest.soLanguagesCount, 10);
    expect(manifest.notes, 'ok');
  });

  test('RunManifestPublic.fromMap tolerates missing fields', () {
    final manifest = RunManifestPublic.fromMap(<String, dynamic>{});

    expect(manifest.manifestVersion, '');
    expect(manifest.generatedAtUtc, '');
    expect(manifest.availableSources, isEmpty);
    expect(manifest.datasetSummaries, isEmpty);
    expect(manifest.totalReposExtraidos, 0);
    expect(manifest.totalReposClasificables, 0);
    expect(manifest.soLanguagesCount, 0);
    expect(manifest.notes, isNull);
  });

  test('buildAnalysisPeriodLabel uses UTC window years', () {
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

    expect(buildAnalysisPeriodLabel(manifest), 'Per\u00edodo de an\u00e1lisis: 2025-2026');
  });

  test('buildAnalysisPeriodLabel falls back when window invalid', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-02-27T05:11:00Z',
      'source_window_start_utc': '',
      'source_window_end_utc': '',
      'quality_gate_status': 'pass',
      'degraded_mode': false,
      'available_sources': [],
      'dataset_summaries': [],
      'total_repos_extraidos': 0,
      'total_repos_clasificables': 0,
      'so_languages_count': 0,
    });

    expect(buildAnalysisPeriodLabel(manifest), kAnalysisPeriodFallbackLabel);
  });

  test('buildLastUpdatedLabel returns latest dataset update date', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-02-28T05:11:00Z',
      'source_window_start_utc': '2025-02-27T00:00:00Z',
      'source_window_end_utc': '2026-02-28T00:00:00Z',
      'quality_gate_status': 'pass',
      'degraded_mode': false,
      'available_sources': [],
      'dataset_summaries': [
        {
          'dataset': 'trend_score',
          'row_count': 23,
          'quality_status': 'pass',
          'updated_at_utc': '2026-02-27T23:59:59Z',
        },
      ],
      'total_repos_extraidos': 0,
      'total_repos_clasificables': 0,
      'so_languages_count': 0,
    });

    expect(
      buildLastUpdatedLabel(manifest),
      '\u00daltima actualizaci\u00f3n (UTC): 27/02/2026',
    );
  });

  test('buildLastUpdatedLabel falls back when dataset timestamps are missing', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-03-01T05:11:00Z',
      'source_window_start_utc': '2025-03-01T00:00:00Z',
      'source_window_end_utc': '',
      'quality_gate_status': 'pass',
      'degraded_mode': false,
      'available_sources': [],
      'dataset_summaries': [
        {
          'dataset': 'trend_score',
          'row_count': 23,
          'quality_status': 'pass',
          'updated_at_utc': '',
        },
      ],
      'total_repos_extraidos': 0,
      'total_repos_clasificables': 0,
      'so_languages_count': 0,
    });

    expect(
      buildLastUpdatedLabel(manifest),
      '\u00daltima actualizaci\u00f3n (UTC): 01/03/2026',
    );
  });

  test('buildLastUpdatedLabel uses newer fallback timestamp when datasets are missing', () {
    final manifest = RunManifestPublic.fromMap({
      'manifest_version': '1.0.0',
      'generated_at_utc': '2026-03-19T00:24:45Z',
      'source_window_start_utc': '2025-03-19T00:00:00Z',
      'source_window_end_utc': '2026-03-18T23:59:59Z',
      'quality_gate_status': 'pass',
      'degraded_mode': false,
      'available_sources': [],
      'dataset_summaries': [
        {
          'dataset': 'trend_score',
          'row_count': 23,
          'quality_status': 'pass',
          'updated_at_utc': '',
        },
      ],
      'total_repos_extraidos': 0,
      'total_repos_clasificables': 0,
      'so_languages_count': 0,
    });

    expect(
      buildLastUpdatedLabel(manifest),
      '\u00daltima actualizaci\u00f3n (UTC): 19/03/2026',
    );
  });
}
