# Arquitectura del Proyecto

## Resumen

La plataforma procesa tendencias de tecnologia desde tres fuentes (GitHub, StackOverflow, Reddit),
calcula un Trend Score compuesto, valida calidad de datos y publica activos para frontend.

## Flujo de Datos

```text
GitHub ETL -------\
StackOverflow ETL --> datos/*.csv --> Trend Score --> sync_assets --> frontend/assets/data/*
Reddit ETL -------/

Adicional:
- dual write opcional a datos/latest y datos/history
- export de bridge JSON para historico de trend
```

## Componentes Backend

- `backend/base_etl.py`
  - clase base para ejecucion, logging y escritura.
- `backend/config/settings.py`
  - rutas, flags de escritura y configuracion global.
- `backend/trend_score.py`
  - motor principal de Trend Score con selector de engine.
- `backend/trend_score_duckdb.py`
  - engine DuckDB para calculo SQL.
- `backend/validador.py`
  - validacion de schema y quality report por severidad.
- `backend/quality/pandera_schemas.py`
  - reglas `critical/warning/info` con Pandera.
- `backend/quality/degradation_policy.py`
  - politica de degradacion por disponibilidad de fuentes.
- `backend/validate_csv_contract.py`
  - contrato CSV para compatibilidad backend/frontend.
- `backend/config/data_product_contract.py`
  - contrato de run manifest y dataset manifest.
- `backend/config/schema_contract_utils.py`
  - `schema_hash` deterministico y reglas SemVer bump.
- `backend/sync_assets.py`
  - sincroniza CSV a frontend con prioridad por archivo (`latest` -> fallback `legacy`).
- `backend/export_history_json.py`
  - genera `history_index.json` y `trend_score_history.json`.

## Estrategia de Escritura

Control por variables de entorno:

- `DATA_WRITE_LEGACY_CSV`
- `DATA_WRITE_LATEST_CSV`
- `DATA_WRITE_HISTORY_CSV`

Rutas:

- Legacy: `datos/*.csv`
- Latest: `datos/latest/*.csv`
- History: `datos/history/<dataset>/year=YYYY/month=MM/day=DD/*.csv`
- Metadata: `datos/metadata/`

## Conexion con Frontend

El frontend consume:

- CSV tradicionales en `frontend/assets/data/*.csv`
- Bridge JSON opcional:
  - `frontend/assets/data/history_index.json`
  - `frontend/assets/data/trend_score_history.json`

Feature flag:

- `frontend/lib/config/feature_flags.dart`
- `USE_HISTORY_BRIDGE_JSON=false` por defecto.

Esto permite cutover parcial sin romper dashboards existentes.

## GitHub Actions

Workflows activos:

1. `etl_semanal.yml`
   - lunes `08:00 UTC` + manual.
   - jobs paralelos por fuente + aggregate + publish.
2. `ci.yml`
   - tests en `main`, `feat/backend`, `feat/frontend`.
3. `dependency_security.yml`
   - auditoria de dependencias (push/PR/schedule/manual).
4. `deploy_frontend.yml`
   - deploy de Flutter Web en `main` o tras ETL exitoso.

## Estado de Backend V2

- Implementacion tecnica: completada.
- Gate operativo pendiente para cutover final:
  - 4 corridas semanales consecutivas sin fallos `critical`.
