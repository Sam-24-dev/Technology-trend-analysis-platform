# Contrato de Datos (Backend <-> Frontend)

Este documento define los contratos activos para salidas de datos y metadata.

## 1) Contrato CSV

Fuente de verdad:
- `backend/config/csv_contract.py`

Objetivo:
- mantener compatibilidad entre salidas backend y consumo frontend.

Validacion:

```bash
python backend/validate_csv_contract.py
```

Modos relevantes:

```bash
python backend/validate_csv_contract.py --no-strict
python backend/validate_csv_contract.py --pandera-strict
python backend/validate_csv_contract.py --no-strict --skip-pandera
```

## 2) Contrato de Producto de Datos (Manifest)

Fuente de verdad:
- `backend/config/data_product_contract.py`

Incluye:
- run manifest
- dataset manifest

### 2.1 Campos obligatorios de run manifest

- `run_id`
- `generated_at_utc`
- `git_sha`
- `branch`
- `source_window_start_utc`
- `source_window_end_utc`
- `quality_gate_status` (`pass`, `pass_with_warnings`, `fail`)
- `datasets`

### 2.2 Campos obligatorios de dataset manifest

- `dataset_logical_name`
- `version_semver`
- `generated_at_utc`
- `source_run_id`
- `schema_hash`
- `row_count`
- `quality_status` (`pass`, `warning`, `fail`)
- `latest_path`
- `history_path`

## 3) Reglas de Validacion

- fechas en formato ISO-8601 con zona horaria.
- `version_semver` valida SemVer.
- `schema_hash` debe ser SHA-256 hexadecimal de 64 caracteres.
- `row_count` debe ser entero >= 0.
- `source_run_id` debe coincidir con `run_id`.
- `history_path` puede ser `null` cuando `quality_status=fail`.

## 4) Utilidades de Schema y Versionado

Fuente de verdad:
- `backend/config/schema_contract_utils.py`

Funciones:
- `compute_schema_hash(...)`
- `recommend_semver_bump(...)`
- `aggregate_semver_bump(...)`

Politica SemVer implementada:
- `major`: cambio breaking (remove/rename required column, tipo incompatible, etc).
- `minor`: cambios backward-compatible (columna opcional, regla no breaking, etc).
- `patch`: cambios internos sin romper contrato.

## 5) Estrategia de Escritura

Control por flags:
- `DATA_WRITE_LEGACY_CSV`
- `DATA_WRITE_LATEST_CSV`
- `DATA_WRITE_HISTORY_CSV`

Rutas:
- Legacy: `datos/*.csv`
- Latest: `datos/latest/*.csv`
- History: `datos/history/<dataset>/year=YYYY/month=MM/day=DD/*.csv`

## 6) Bridge Frontend

Fuente de verdad:
- `backend/export_history_json.py`

Activos generados:
- `frontend/assets/data/history_index.json`
- `frontend/assets/data/trend_score_history.json`

Comportamiento:
- si el historial esta incompleto o corrupto, se usa fallback a `latest` para trend.

## 7) Recomendacion Operativa

Antes de publicar cambios de contrato:
1. actualizar contrato en backend.
2. agregar o ajustar tests.
3. ejecutar `pytest -q`.
4. validar que frontend sigue consumiendo sin regresiones.
