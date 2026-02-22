# ROADMAP V2 FINAL - Technology Trend Analysis Platform

## 1) Summary

This is the final, decision-complete plan for V2.
Goal: migrate from V1 CSV-only pipeline to a serverless data stack V2 without breaking current frontend behavior.

Primary outcomes:
1. Data Product Contract V2 with run and dataset metadata.
2. Dual write (latest + history) with controlled transition.
3. Quality gate with severity levels.
4. Trend Score V1 vs V2 numeric equivalence tests.
5. Parallel CI pipeline with artifacts and conditional publish.
6. Frontend bridge with JSON history while keeping CSV compatibility.

## 2) Scope

In scope now (V2 core): F2-F7
- Contract V2
- Dual write
- Pandera quality gate
- DuckDB trend score engine
- GitHub Actions parallel jobs with artifacts
- Frontend bridge
- Cutover governance

Out of scope now:
- Advanced forecasting productionization
- Advanced topic modeling productionization
- External BI platform integration

These move to V2.1 or post-V2.

## 3) Current baseline (verified)

Backend:
- ETLs: GitHub, StackOverflow, Reddit
- Trend score engine: `backend/trend_score.py`
- CSV contract: `backend/config/csv_contract.py`
- CSV contract validator: `backend/validate_csv_contract.py`

Frontend:
- Flutter dashboards read CSV from `frontend/assets/data/`
- Loader: `frontend/lib/services/csv_service.dart`

CI/CD:
- Weekly ETL workflow exists and works
- Current flow is mostly sequential for ETL processing

## 4) Branch strategy and governance

Branches:
- Backend work branch: `feat/backend`
- Frontend work branch: `feat/frontend`

Default merge policy:
- `squash merge` unless explicit reason to preserve detailed commit graph.

Sync policy before each backend PR:
1. `git fetch --all --prune`
2. `git switch main && git pull --ff-only origin main`
3. `git switch feat/backend && git merge --ff-only main`

If exact-commit alignment is required and FF does not apply:
- `git reset --hard main`
- `git push --force-with-lease`

## 5) Data Product Contract V2

### 5.1 Run-level metadata (required)

- `run_id` (uuid)
- `generated_at_utc` (ISO datetime)
- `git_sha`
- `branch`
- `source_window_start_utc`
- `source_window_end_utc`
- `quality_gate_status` (`pass`, `pass_with_warnings`, `fail`)
- `datasets` (array of dataset manifests)

### 5.2 Dataset-level metadata (required)

- `dataset_logical_name`
- `version_semver`
- `generated_at_utc`
- `source_run_id`
- `schema_hash`
- `row_count`
- `quality_status` (`pass`, `warning`, `fail`)
- `latest_path`
- `history_path`

### 5.3 SemVer rules for datasets

- MAJOR: breaking schema change (remove/rename required column, incompatible type change)
- MINOR: backward-compatible additions (optional columns, non-breaking checks)
- PATCH: internal fixes with no schema contract break

## 6) Storage layout (fixed now)

Latest outputs:
- `datos/latest/*.csv`
- `datos/latest/history_index.json`
- `datos/latest/trend_score_history.json`

History outputs:
- `datos/history/<dataset_logical_name>/year=YYYY/month=MM/day=DD/part-0000.parquet`

Metadata outputs:
- `datos/metadata/run_manifest.json`
- `datos/metadata/runs/<run_id>.json`

Examples:
- `datos/history/trend_score/year=2026/month=02/day=22/part-0000.parquet`
- `datos/history/so_volumen/year=2026/month=02/day=22/part-0000.parquet`

## 7) V1 -> V2 compatibility matrix (core)

- `datos/trend_score.csv` -> `datos/latest/trend_score.csv` + `datos/history/trend_score/...`
- `datos/so_volumen_preguntas.csv` -> `datos/latest/so_volumen_preguntas.csv` + `datos/history/so_volumen/...`
- `datos/so_tendencias_mensuales.csv` -> `datos/latest/so_tendencias_mensuales.csv` + `datos/history/so_tendencias/...`
- `datos/reddit_temas_emergentes.csv` -> `datos/latest/reddit_temas_emergentes.csv` + `datos/history/reddit_temas/...`
- `datos/github_lenguajes.csv` -> `datos/latest/github_lenguajes.csv` + `datos/history/github_lenguajes/...`

Frontend cutover rule:
- CSV stays until bridge JSON passes 4 consecutive weekly runs without critical failures.

## 8) Quality model (Pandera + severity)

Severity and actions:
- `critical`: fail pipeline, no publish
- `warning`: publish with warning flag
- `info`: publish, observability only

Minimum required rules:
1. Required columns present (critical)
2. Critical types valid (critical)
3. Critical columns no nulls (critical)
4. `trend_score >= 0` (critical)
5. Ranking uniqueness (critical)
6. Core dataset row_count > 0 (warning)
7. Freshness threshold exceeded (warning)
8. Distribution drift soft breach (warning)
9. Optional fields missing (info)
10. Minor cardinality variation (info)

## 9) Trend score equivalence V1 vs V2

Acceptance thresholds:
- Absolute score difference per shared technology: `<= 0.01`
- Top-10 overlap: `>= 90%`
- Ranking delta: `<= 1` for at least 90% of shared technologies
- Tie handling allowed when score delta is `<= 0.01`

## 10) Source failure degradation policy

- 3/3 sources available: publish, normal weights
- 2/3 sources available: renormalize available weights, publish with warning
- 1/3 source available: do not publish new latest, mark fail
- 0/3 available: fail run

## 11) CI/CD V2 architecture (artifacts)

Main workflow: `.github/workflows/etl_semanal.yml`

Jobs:
1. `job_github`
2. `job_stackoverflow`
3. `job_reddit`
4. `job_aggregate` (downloads artifacts, computes trend, runs quality gate, writes manifest)
5. `job_publish` (conditional on quality gate)

Publish condition:
- only if quality status is `pass` or `pass_with_warnings`

## 12) Runtime and cost budgets (GitHub Actions)

Per-run limits:
- Source job timeout: 20 min each
- Aggregate timeout: 15 min
- Publish timeout: 10 min
- Total run budget: 60 min

Artifact budget:
- Warning at 75 MB total
- Critical at 100 MB total

Alerting thresholds:
- Warning: runtime > 45 min
- Critical: runtime > 60 min

## 13) Reproducibility

- Python lock file for deterministic installs
- Flutter lock file committed
- Deterministic seed for transforms where applicable
- Baseline fixtures for V1 equivalence tests
- Historical replay by `run_id` supported through manifest metadata

## 14) Retention and lifecycle

Core aggregated datasets:
- Daily: 180 days
- Monthly compacted: 5 years

Heavy raw-like datasets:
- Daily: 90 days
- Monthly compacted: 24 months

Compaction:
- Monthly parquet compaction
- Integrity validation after compaction (row_count, schema_hash, checksums)

## 15) Security and compliance in CI

- Least-privilege workflow permissions
- `contents: write` only where publish is needed
- Secrets required:
  - `GH_PAT`
  - `STACKOVERFLOW_KEY`
  - `REDDIT_CLIENT_ID`
  - `REDDIT_CLIENT_SECRET`
- Secret masking required
- No sensitive payloads in logs/artifacts
- Preflight secret checks before extraction

## 16) PR plan (F2-F7, PR-ready)

### PR-01 (F2) - Contract V2 foundation
Goal:
- Introduce V2 contract and manifest model.

Files:
- `backend/config/data_product_contract_v2.py` (new)
- `backend/config/csv_contract.py`
- `docs/data_contract.md`

Checks:
- contract tests pass
- schema validation tests pass

Merge criteria:
- no regressions in current tests

Rollback:
- revert PR

### PR-02 (F3) - Dual write infrastructure
Goal:
- Add latest/history writing path while preserving existing CSV behavior.

Files:
- `backend/base_etl.py`
- `backend/config/settings.py`
- `backend/sync_assets.py`
- tests for write behavior

Checks:
- write tests pass
- current ETL tests pass

Rollback:
- disable history writes via config flag

### PR-03 (F5) - Quality gate warn-only
Goal:
- Add Pandera validation with severity routing.

Files:
- `backend/validador.py`
- `backend/validate_csv_contract.py`
- `backend/quality/pandera_schemas.py` (new)
- tests for severity handling

Checks:
- quality tests pass
- warning path does not block publish

Rollback:
- bypass Pandera stage

### PR-04 (F4) - DuckDB trend engine + equivalence tests
Goal:
- Move trend calculation to DuckDB while proving equivalence.

Files:
- `backend/trend_score.py`
- `backend/trend_score_v2_duckdb.py` (new)
- `tests/test_trend_equivalence_v1_v2.py` (new)

Checks:
- equivalence thresholds satisfied

Rollback:
- switch to previous trend engine path

### PR-05 (F6) - Parallel workflow with artifacts
Goal:
- Split source jobs and aggregate with artifacts.

Files:
- `.github/workflows/etl_semanal.yml`

Checks:
- manual workflow run succeeds
- artifact handoff valid

Rollback:
- restore sequential workflow version

### PR-06 (F7) - Frontend bridge assets
Goal:
- Produce JSON history bridge assets while keeping CSV.

Files:
- `backend/export_history_json.py` (new)
- `backend/sync_assets.py`
- generated files under `frontend/assets/data/`

Checks:
- bridge files generated
- frontend can load existing CSV unchanged

Rollback:
- disable bridge export

### PR-07 (F7) - Frontend partial cutover
Goal:
- Consume bridge JSON via feature flag.

Files:
- `frontend/lib/services/csv_service.dart`
- `frontend/lib/config/feature_flags.dart` (new)
- minimal temporal view wiring

Checks:
- smoke load for CSV and JSON paths
- no regressions in existing dashboards

Rollback:
- feature flag off

## 17) DoD by phase (F2-F7)

F2:
- Deliverables: V2 contract + manifest schema
- Tests: contract schema tests
- Acceptance: manifest valid in sample run
- Rollback: PR revert

F3:
- Deliverables: dual write latest/history
- Tests: write path + idempotency tests
- Acceptance: expected files created in fixed layout
- Rollback: disable history flag

F4:
- Deliverables: DuckDB trend engine
- Tests: equivalence suite
- Acceptance: all thresholds pass
- Rollback: switch back to V1 engine

F5:
- Deliverables: severity quality gate
- Tests: critical/warning/info routing
- Acceptance: critical blocks publish, warning allows publish-with-flag
- Rollback: bypass new gate

F6:
- Deliverables: parallel CI with artifacts
- Tests: workflow dry run + artifact contract
- Acceptance: successful end-to-end run
- Rollback: sequential workflow restore

F7:
- Deliverables: bridge JSON + frontend flag cutover
- Tests: frontend smoke path
- Acceptance: 4 weekly runs stable before CSV retirement decision
- Rollback: flag off and CSV-only fallback

## 18) Test scenarios (mandatory)

1. Manifest schema: valid and invalid samples
2. SemVer bump correctness on representative changes
3. Deterministic schema_hash stability
4. Dual write idempotent behavior by run_id
5. Quality gate severity actions
6. V1 vs V2 trend equivalence thresholds
7. Degradation matrix (3/3, 2/3, 1/3, 0/3 sources)
8. Artifact corruption or missing artifact handling
9. Frontend bridge fallback behavior
10. Rollback verification per PR

## 19) Release and tags

Recommended release checkpoints:
- `v2.0.0-rc1`: F2 + F3
- `v2.0.0-rc2`: F5 + F4
- `v2.0.0-rc3`: F6
- `v2.0.0`: F7 stable and cutover-ready
- `v2.1.0`: advanced analytics

Cutover complete criteria:
- 4 consecutive weekly runs without critical quality failures
- SLO targets met
- trend equivalence stable
- frontend bridge stable under flag-on

## 20) Decision timeline tags

- Adopt now:
  - Contract V2
  - Dual write
  - Pandera severity
  - DuckDB equivalence
  - CI artifacts
  - Frontend bridge

- Adopt in V2.1:
  - forecasting and advanced NLP

- Post-V2:
  - external BI and non-GitHub long-term storage

## 21) Final assumptions

1. Serverless architecture remains mandatory.
2. This document is the execution source of truth for backend V2 in `feat/backend`.
3. No open decision should be left to implementers outside this plan.
