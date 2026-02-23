# Technology Trend Analysis Platform

End-to-end data pipeline and dashboard for technology trends across GitHub, StackOverflow, and Reddit.

## Current Status

- Backend refactor implementation is complete for F2-F7.
- Test suite is green (`133 passed`).
- Operational cutover is still pending: 4 weekly ETL runs without critical failures.

## What Is Implemented

- Multi-source ETL pipeline (GitHub, StackOverflow, Reddit).
- Dual write strategy:
  - `datos/*.csv` (legacy)
  - `datos/latest/*.csv` (latest)
  - `datos/history/<dataset>/year=YYYY/month=MM/day=DD/*.csv` (history snapshots)
- Trend Score engine selector:
  - `legacy` (pandas)
  - `duckdb` (SQL engine with equivalence tests)
- Severity-based quality gate (`critical`, `warning`, `info`) with Pandera support.
- Data product contract for run and dataset manifests.
- Frontend bridge JSON assets:
  - `history_index.json`
  - `trend_score_history.json`
- Frontend feature flag for partial cutover to bridge JSON.

## Repository Layout

```text
backend/
  base_etl.py
  trend_score.py
  trend_score_duckdb.py
  sync_assets.py
  export_history_json.py
  validate_csv_contract.py
  validador.py
  config/
    settings.py
    csv_contract.py
    data_product_contract.py
    schema_contract_utils.py
  quality/
    pandera_schemas.py
    degradation_policy.py

datos/
  *.csv
  latest/*.csv
  history/<dataset>/year=YYYY/month=MM/day=DD/*.csv
  metadata/

frontend/
  lib/
  assets/data/

docs/
tests/
.github/workflows/
```

## Runtime Workflows

### 1) ETL Weekly Data Refresh (`etl_semanal.yml`)

Trigger:
- Schedule: every Monday at `08:00 UTC`.
- Manual: `workflow_dispatch`.

Flow:
1. Run source jobs in parallel: GitHub, StackOverflow, Reddit.
2. Upload source artifacts.
3. Aggregate job downloads artifacts, runs Trend Score, syncs frontend assets, validates data contract.
4. Publish job commits refreshed data if aggregate is successful.

Important behavior:
- Reddit source is non-blocking in source stage (degraded mode is allowed).
- Aggregate stage enforces required outputs for frontend and trend artifacts.

### 2) CI - Tests (`ci.yml`)

Trigger:
- Push and pull request checks for Python tests.

### 3) Dependency Security Audit (`dependency_security.yml`)

Trigger:
- Dependency file changes and weekly schedule (Monday at `09:00 UTC`).
- Manual execution supported.

### 4) Frontend Deploy (`deploy_frontend.yml`)

Trigger:
- Push to `main` affecting frontend/data paths.
- Successful completion of ETL workflow.
- Manual execution.

## Environment Variables

Create `.env` in repo root:

```env
GITHUB_TOKEN=your_token
STACKOVERFLOW_KEY=your_key
REDDIT_CLIENT_ID=your_client_id
REDDIT_CLIENT_SECRET=your_client_secret

DATA_WRITE_LEGACY_CSV=1
DATA_WRITE_LATEST_CSV=0
DATA_WRITE_HISTORY_CSV=0
EXPORT_HISTORY_BRIDGE_JSON=1
TREND_SCORE_ENGINE=legacy
```

Notes:
- Local defaults keep legacy behavior.
- CI workflow sets dual write and DuckDB explicitly for weekly runs.

## Local Commands

```bash
# backend
pip install -r backend/requirements.txt
python -m pytest -q

# run ETLs
python backend/github_etl.py
python backend/stackoverflow_etl.py
python backend/reddit_etl.py
python backend/trend_score.py

# sync assets + bridge
python backend/sync_assets.py

# frontend
cd frontend
flutter pub get
flutter run -d chrome
```

## Release Readiness

Release and cutover policy is defined in:
- `docs/ROADMAP_V2_IMPLEMENTATION_PLAN.md` (sections 19 and 20)

In short:
- Implementation is done.
- Production cutover requires operational stability gates.

## License

MIT
