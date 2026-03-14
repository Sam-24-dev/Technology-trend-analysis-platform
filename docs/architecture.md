# Arquitectura del Proyecto

## Resumen

La plataforma ingiere datos de GitHub, StackOverflow y Reddit, calcula un Trend Score compuesto,
valida calidad y publica assets (CSV + JSON) consumidos por Flutter Web.

## Flujo de Datos

```text
GitHub ETL -------\
StackOverflow ETL --> datos/*.csv --> Trend Score --> export_history_json --> sync_assets --> frontend/assets/data/*
Reddit ETL -------/

Opcional (CI):
- publish de assets a GH Pages (remote_assets)
- commit automatico de datos en branch

Opcional:
- dual write a datos/latest y datos/history
- export de bridges JSON para UI
```

## Componentes Backend

- `backend/base_etl.py`
  - ejecución, logging y escritura CSV.
- `backend/config/settings.py`
  - rutas, flags de escritura y configuración global.
- `backend/trend_score.py`
  - motor principal de Trend Score.
- `backend/trend_score_duckdb.py`
  - engine SQL (DuckDB) con equivalencia.
- `backend/validador.py`
  - validación de schema y quality report.
- `backend/quality/pandera_schemas.py`
  - reglas `critical/warning/info`.
- `backend/quality/degradation_policy.py`
  - política de degradación por fuentes.
- `backend/validate_csv_contract.py`
  - contrato CSV para compatibilidad backend/frontend.
- `backend/export_history_json.py`
  - genera bridges JSON para UI.
- `backend/sync_assets.py`
  - sincroniza CSV + JSON a frontend.

## Bridges y Assets Públicos (Frontend)

Bridges principales:
- `history_index.json`
- `trend_score_history.json` (enriquecido)
- `home_highlights.json`
- `technology_profiles.json`

Series por fuente (historia real):
- `github_frameworks_history.json`
- `github_correlacion_history.json`
- `reddit_temas_history.json`
- `reddit_interseccion_history.json`
- `so_volumen_history.json`
- `so_aceptacion_history.json`
- `so_tendencias_history.json`

Snapshots publicos (resumen actual):
- `github_lenguajes_public.json`
- `reddit_sentimiento_public.json`

Metadata publica:
- `run_manifest.json`

## Conexión con Frontend

- `DataService` intenta `REMOTE_ASSETS_BASE_URL` y hace fallback a assets locales.
- UI consume bridges primero y usa CSV si falta el bridge.
- Rutas usan slugs canónicos (`AI/ML`, `C#`, `C++`).
- `run_manifest.json` publico controla metadata y degradacion.

## Configuracion Clave

- `DATA_WRITE_LEGACY_CSV`
- `DATA_WRITE_LATEST_CSV`
- `DATA_WRITE_HISTORY_CSV`
- `EXPORT_HISTORY_BRIDGE_JSON`
- `USE_PUBLIC_RUN_MANIFEST`
- `REQUIRE_FRONTEND_METADATA`
- `FRONTEND_ASSETS_POLICY_MODE`
- `TREND_SCORE_ENGINE`
- `REMOTE_ASSETS_BASE_URL`
- `FRONTEND_BRIDGE_REMOTE_DIR`

## GitHub Actions

1. `etl_semanal.yml` (lunes 08:00 UTC)
2. `ci.yml` (tests backend + frontend)
3. `dependency_security.yml` (pip-audit)
4. `deploy_frontend.yml` (GH Pages)

## Estado

- Backend V2: implementado.
- UI V2: bridge-first con fallback.
- Operación: requiere corridas semanales sin fallos críticos.
