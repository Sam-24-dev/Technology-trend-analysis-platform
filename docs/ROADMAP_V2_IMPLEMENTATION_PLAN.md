# ROADMAP V2 FINAL - Technology Trend Analysis Platform

## 1) Resumen

Este es el plan final, **decision-complete**, para la V2.
Objetivo: migrar desde el pipeline V1 (CSV-only) a un serverless data stack V2 sin romper el comportamiento actual del frontend.

Resultados principales:
1. Data Product Contract V2 con metadata de run y de dataset.
2. Dual write (latest + history) con transicion controlada.
3. Quality gate con niveles de severidad.
4. Pruebas de equivalencia numerica V1 vs V2 para Trend Score.
5. Pipeline CI paralelo con artifacts y publicacion condicional.
6. Frontend bridge con JSON historico manteniendo compatibilidad CSV.

## 2) Alcance

En alcance ahora (core V2): F2-F7
- Contract V2
- Dual write
- Pandera quality gate
- DuckDB trend score engine
- GitHub Actions con jobs paralelos y artifacts
- Frontend bridge
- Gobernanza de cutover

Fuera de alcance ahora:
- Productivizacion avanzada de forecasting
- Productivizacion avanzada de topic modeling
- Integracion con plataformas BI externas

Eso pasa a V2.1 o post-V2.

## 3) Baseline actual (verificado)

Backend:
- ETLs: GitHub, StackOverflow, Reddit
- Trend score engine: `backend/trend_score.py`
- CSV contract: `backend/config/csv_contract.py`
- CSV contract validator: `backend/validate_csv_contract.py`

Frontend:
- Dashboards Flutter leen CSV desde `frontend/assets/data/`
- Loader: `frontend/lib/services/csv_service.dart`

CI/CD:
- Workflow ETL semanal existe y funciona
- Flujo actual mayormente secuencial para procesamiento ETL

## 4) Estrategia de ramas y gobernanza

Ramas:
- Rama de trabajo backend: `feat/backend`
- Rama de trabajo frontend: `feat/frontend`

Politica de merge por defecto:
- `squash merge`, salvo razon explicita para preservar el grafo detallado de commits.

Politica de sincronizacion antes de cada PR de backend:
1. `git fetch --all --prune`
2. `git switch main && git pull --ff-only origin main`
3. `git switch feat/backend && git merge --ff-only main`

Si se requiere alineacion exacta de commit y no aplica fast-forward:
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
- `datasets` (array de dataset manifests)

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

### 5.3 Reglas SemVer para datasets

- MAJOR: cambio breaking de schema (eliminar/renombrar columna requerida, cambio de tipo incompatible)
- MINOR: adiciones backward-compatible (columnas opcionales, checks no-breaking)
- PATCH: correcciones internas sin romper el contrato de schema

## 6) Layout de almacenamiento (fijado desde ahora)

Latest outputs:
- `datos/latest/*.csv`
- `datos/latest/history_index.json`
- `datos/latest/trend_score_history.json`

History outputs:
- `datos/history/<dataset_logical_name>/year=YYYY/month=MM/day=DD/part-0000.parquet`

Metadata outputs:
- `datos/metadata/run_manifest.json`
- `datos/metadata/runs/<run_id>.json`

Ejemplos:
- `datos/history/trend_score/year=2026/month=02/day=22/part-0000.parquet`
- `datos/history/so_volumen/year=2026/month=02/day=22/part-0000.parquet`

## 7) Matriz de compatibilidad V1 -> V2 (core)

- `datos/trend_score.csv` -> `datos/latest/trend_score.csv` + `datos/history/trend_score/...`
- `datos/so_volumen_preguntas.csv` -> `datos/latest/so_volumen_preguntas.csv` + `datos/history/so_volumen/...`
- `datos/so_tendencias_mensuales.csv` -> `datos/latest/so_tendencias_mensuales.csv` + `datos/history/so_tendencias/...`
- `datos/reddit_temas_emergentes.csv` -> `datos/latest/reddit_temas_emergentes.csv` + `datos/history/reddit_temas/...`
- `datos/github_lenguajes.csv` -> `datos/latest/github_lenguajes.csv` + `datos/history/github_lenguajes/...`

Regla de cutover frontend:
- CSV se mantiene hasta que el bridge JSON pase 4 corridas semanales consecutivas sin fallos `critical`.

## 8) Modelo de calidad (Pandera + severity)

Severidad y acciones:
- `critical`: falla pipeline, no publica
- `warning`: publica con warning flag
- `info`: publica, solo observabilidad

Reglas minimas obligatorias:
1. Required columns presentes (`critical`)
2. Critical types validos (`critical`)
3. No nulos en critical columns (`critical`)
4. `trend_score >= 0` (`critical`)
5. Unicidad de ranking (`critical`)
6. `row_count > 0` en datasets core (`warning`)
7. Freshness fuera de umbral (`warning`)
8. Distribution drift suave (`warning`)
9. Optional fields faltantes (`info`)
10. Variacion menor de cardinalidad (`info`)

## 9) Equivalencia de Trend Score V1 vs V2

Umbrales de aceptacion:
- Diferencia absoluta por tecnologia compartida: `<= 0.01`
- Top-10 overlap: `>= 90%`
- Delta de ranking: `<= 1` para al menos 90% de tecnologias compartidas
- Empates permitidos cuando delta de score `<= 0.01`

## 10) Politica de degradacion ante fallo de fuentes

- 3/3 fuentes disponibles: publica, weights normales
- 2/3 fuentes disponibles: renormaliza weights disponibles, publica con warning
- 1/3 fuente disponible: no publica nuevo latest, marca fail
- 0/3 fuentes disponibles: fail run

## 11) Arquitectura CI/CD V2 (artifacts)

Workflow principal: `.github/workflows/etl_semanal.yml`

Jobs:
1. `job_github`
2. `job_stackoverflow`
3. `job_reddit`
4. `job_aggregate` (descarga artifacts, calcula trend, corre quality gate, escribe manifest)
5. `job_publish` (condicional por quality gate)

Condicion de publicacion:
- solo si quality status es `pass` o `pass_with_warnings`

## 12) Presupuesto runtime y costo (GitHub Actions)

Limites por run:
- Timeout por source job: 20 min cada uno
- Timeout aggregate: 15 min
- Timeout publish: 10 min
- Presupuesto total por run: 60 min

Presupuesto de artifacts:
- Warning en 75 MB total
- Critical en 100 MB total

Umbrales de alerta:
- Warning: runtime > 45 min
- Critical: runtime > 60 min

## 13) Reproducibilidad

- Python lock file para instalaciones deterministicas
- Flutter lock file commiteado
- Seed deterministica para transformaciones donde aplique
- Baseline fixtures V1 para pruebas de equivalencia
- Replay historico por `run_id` soportado via manifest metadata

## 14) Retencion y ciclo de vida

Datasets core agregados:
- Diario: 180 dias
- Mensual compactado: 5 anios

Datasets pesados tipo raw:
- Diario: 90 dias
- Mensual compactado: 24 meses

Compactacion:
- Compactacion parquet mensual
- Validacion de integridad post-compactacion (`row_count`, `schema_hash`, checksums)

## 15) Security and compliance en CI

- Workflow permissions con minimo privilegio
- `contents: write` solo donde la publicacion lo requiera
- Secrets requeridos:
  - `GH_PAT`
  - `STACKOVERFLOW_KEY`
  - `REDDIT_CLIENT_ID`
  - `REDDIT_CLIENT_SECRET`
- Secret masking obligatorio
- No exponer payloads sensibles en logs/artifacts
- Preflight checks de secretos antes de extraer datos

## 16) Plan de PRs (F2-F7, PR-ready)

### PR-01 (F2) - Contract V2 foundation
Objetivo:
- Introducir contrato V2 y modelo de manifest.

Archivos:
- `backend/config/data_product_contract.py` (new)
- `backend/config/csv_contract.py`
- `docs/data_contract.md`

Checks:
- contract tests en verde
- schema validation tests en verde

Merge criteria:
- sin regresiones en la suite actual

Rollback:
- revert PR

### PR-02 (F3) - Dual write infrastructure
Objetivo:
- Agregar latest/history write path preservando el comportamiento CSV existente.

Archivos:
- `backend/base_etl.py`
- `backend/config/settings.py`
- `backend/sync_assets.py`
- tests de write behavior

Checks:
- write tests en verde
- ETL tests actuales en verde

Rollback:
- desactivar history writes con config flag

### PR-03 (F5) - Quality gate warn-only
Objetivo:
- Agregar validacion Pandera con enrutamiento por severidad.

Archivos:
- `backend/validador.py`
- `backend/validate_csv_contract.py`
- `backend/quality/pandera_schemas.py` (new)
- tests de manejo de severidad

Checks:
- quality tests en verde
- warning path no bloquea publish

Rollback:
- bypass de etapa Pandera

### PR-04 (F4) - DuckDB trend engine + equivalence tests
Objetivo:
- Mover calculo de trend a DuckDB demostrando equivalencia.

Archivos:
- `backend/trend_score.py`
- `backend/trend_score_v2_duckdb.py` (new)
- `tests/test_trend_equivalence_v1_v2.py` (new)

Checks:
- equivalence thresholds cumplidos

Rollback:
- volver a ruta de trend engine anterior

### PR-05 (F6) - Parallel workflow with artifacts
Objetivo:
- Separar source jobs y agregar aggregate por artifacts.

Archivos:
- `.github/workflows/etl_semanal.yml`

Checks:
- manual workflow run exitoso
- artifact handoff valido

Rollback:
- restaurar version secuencial del workflow

### PR-06 (F7) - Frontend bridge assets
Objetivo:
- Producir bridge JSON historico manteniendo CSV.

Archivos:
- `backend/export_history_json.py` (new)
- `backend/sync_assets.py`
- archivos generados en `frontend/assets/data/`

Checks:
- bridge files generados
- frontend sigue cargando CSV sin cambios

Rollback:
- desactivar bridge export

### PR-07 (F7) - Frontend partial cutover
Objetivo:
- Consumir bridge JSON por feature flag.

Archivos:
- `frontend/lib/services/csv_service.dart`
- `frontend/lib/config/feature_flags.dart` (new)
- wiring minimo de vista temporal

Checks:
- smoke load para path CSV y JSON
- sin regresiones en dashboards actuales

Rollback:
- feature flag off

## 17) DoD por fase (F2-F7)

F2:
- Deliverables: contrato V2 + manifest schema
- Tests: contract schema tests
- Acceptance: manifest valido en sample run
- Rollback: revert PR

F3:
- Deliverables: dual write latest/history
- Tests: write path + idempotency tests
- Acceptance: archivos esperados creados en el layout fijo
- Rollback: desactivar history flag

F4:
- Deliverables: DuckDB trend engine
- Tests: equivalence suite
- Acceptance: todos los umbrales en verde
- Rollback: volver a V1 engine

F5:
- Deliverables: severity quality gate
- Tests: enrutamiento `critical`/`warning`/`info`
- Acceptance: critical bloquea publish, warning permite publish-with-flag
- Rollback: bypass de gate nuevo

F6:
- Deliverables: CI paralelo con artifacts
- Tests: workflow dry run + artifact contract
- Acceptance: corrida end-to-end exitosa
- Rollback: restaurar workflow secuencial

F7:
- Deliverables: bridge JSON + cutover parcial frontend
- Tests: frontend smoke path
- Acceptance: 4 corridas semanales estables antes de retiro de CSV
- Rollback: flag off y fallback CSV-only

## 18) Escenarios de prueba (obligatorios)

1. Manifest schema: muestras validas e invalidas
2. Correctitud de SemVer bump en cambios representativos
3. Estabilidad deterministica de `schema_hash`
4. Idempotencia de dual write por `run_id`
5. Acciones del quality gate por severidad
6. Umbrales de equivalencia trend V1 vs V2
7. Matriz de degradacion (3/3, 2/3, 1/3, 0/3 fuentes)
8. Manejo de artifact corrupto o faltante
9. Comportamiento de fallback del frontend bridge
10. Verificacion de rollback por PR

## 19) Releases y tags

Checkpoints recomendados:
- `v2.0.0-rc1`: F2 + F3
- `v2.0.0-rc2`: F5 + F4
- `v2.0.0-rc3`: F6
- `v2.0.0`: F7 estable y cutover-ready
- `v2.1.0`: advanced analytics

Criterios de cutover completo:
- 4 corridas semanales consecutivas sin fallos `critical`
- SLOs cumplidos
- equivalencia trend estable
- frontend bridge estable con flag on

## 20) Decision timeline tags

- Adoptar ahora:
  - Contract V2
  - Dual write
  - Pandera severity
  - DuckDB equivalence
  - CI artifacts
  - Frontend bridge

- Adoptar en V2.1:
  - forecasting y NLP avanzado

- Post-V2:
  - BI externo y almacenamiento long-term fuera de GitHub

## 21) Supuestos finales

1. La arquitectura serverless se mantiene como restriccion principal.
2. Este documento es la fuente de verdad de ejecucion para backend V2 en `feat/backend`.
3. No se dejan decisiones abiertas fuera de este plan.
