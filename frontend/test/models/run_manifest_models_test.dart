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

    expect(
      buildAnalysisPeriodLabel(manifest),
      'Per\u00edodo de an\u00e1lisis: 2025-2026',
    );
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

  test('buildSourceFreshnessLabels uses only mapped dataset timestamps', () {
    final manifest = RunManifestPublic.fromMap({
      'generated_at_utc': '2026-09-01T12:00:00Z',
      'dataset_summaries': [
        {
          'dataset': 'github_lenguajes',
          'updated_at_utc': '2026-08-24T09:00:00Z',
        },
        {
          'dataset': 'github_repos_2025',
          'updated_at_utc': '2026-08-23T09:00:00Z',
        },
        {
          'dataset': 'so_volumen_preguntas',
          'updated_at_utc': '2026-08-24T10:00:00Z',
        },
        {
          'dataset': 'reddit_temas_emergentes',
          'updated_at_utc': '2026-08-31T03:00:00Z',
        },
        {'dataset': 'trend_score', 'updated_at_utc': '2026-09-01T12:00:00Z'},
        {
          'dataset': 'interseccion_github_reddit',
          'updated_at_utc': '2026-09-01T12:00:00Z',
        },
      ],
    });

    expect(buildSourceFreshnessLabels(manifest), [
      'GitHub: 24/08/2026 UTC',
      'Stack Overflow: 24/08/2026 UTC',
      'Reddit: 31/08/2026 UTC',
    ]);
  });

  test(
    'buildSourceFreshnessLabel never falls back to manifest generation time',
    () {
      final manifest = RunManifestPublic.fromMap({
        'generated_at_utc': '2026-09-01T12:00:00Z',
        'dataset_summaries': [
          {'dataset': 'github_lenguajes', 'updated_at_utc': 'not-a-timestamp'},
        ],
      });

      expect(
        buildSourceFreshnessLabel(manifest, 'github'),
        'GitHub: no disponible',
      );
    },
  );
}
