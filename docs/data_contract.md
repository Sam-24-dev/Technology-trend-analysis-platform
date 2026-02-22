# Contrato de Datos (Backend <-> Frontend)

Este documento define los contratos de datos activos del proyecto:

1. **Contrato CSV** para salidas tabulares consumidas hoy por el frontend.
2. **Contrato de producto de datos** para metadata de ejecucion
   (`run manifest` + `dataset manifest`).

## Fuente de verdad

### Contrato CSV
- `backend/config/csv_contract.py`
- Version actual: `CONTRACT_VERSION = 2026.04`

### Contrato de producto de datos
- `backend/config/data_product_contract.py`
- Version actual: `DATA_PRODUCT_CONTRACT_VERSION = 1.0.0`

---

## 1) Contrato CSV (estado actual)

El contrato CSV define por archivo logico:

1. `required_columns`
2. `critical_columns`
3. `column_types`
4. `optional_columns` (cuando aplica)

Validacion de contrato CSV:

```bash
python backend/validate_csv_contract.py
```

Modo no estricto (solo advertencias):

```bash
python backend/validate_csv_contract.py --no-strict
```

---

## 2) Contrato de producto de datos (manifest)

Este contrato modela metadata de ejecucion y metadata de datasets para
estandarizar publicacion, trazabilidad y validacion.

### 2.1 Run manifest (required fields)

- `run_id`
- `generated_at_utc`
- `git_sha`
- `branch`
- `source_window_start_utc`
- `source_window_end_utc`
- `quality_gate_status` (`pass`, `pass_with_warnings`, `fail`)
- `datasets` (lista de dataset manifests)

### 2.2 Dataset manifest (required fields)

- `dataset_logical_name`
- `version_semver`
- `generated_at_utc`
- `source_run_id`
- `schema_hash` (sha256 hexadecimal, 64 chars)
- `row_count`
- `quality_status` (`pass`, `warning`, `fail`)
- `latest_path`
- `history_path`

### 2.3 Reglas minimas del contrato de producto

1. `generated_at_utc` y ventanas de fuente deben ser ISO-8601 con zona.
2. `version_semver` debe cumplir SemVer.
3. `row_count` debe ser integer >= 0.
4. `source_run_id` de cada dataset debe coincidir con `run_id`.
5. `history_path` puede ser `null` cuando `quality_status = fail`.

---

## 3) Validacion programatica del manifest

Ejemplo de uso desde Python:

```python
from config.data_product_contract import validate_run_manifest

ok, errors = validate_run_manifest(run_manifest)
if not ok:
    raise ValueError(errors)
```

Funciones clave disponibles:

- `validate_run_manifest(...)`
- `validate_dataset_manifest(...)`
- `build_run_manifest(...)`
- `build_dataset_manifest(...)`
- `is_valid_semver(...)`
- `is_valid_iso_utc(...)`

---

## 4) Compatibilidad y evolucion

Durante la refactorizacion:

1. El contrato CSV se mantiene para no romper consumo actual.
2. El contrato de producto de datos agrega trazabilidad y control operativo.
3. Ambos contratos conviven; uno no reemplaza al otro en esta etapa.

## 5) Estrategia de escritura (dual write)

La escritura de salidas se controla por configuracion:

- `DATA_WRITE_LEGACY_CSV`
- `DATA_WRITE_LATEST_CSV`
- `DATA_WRITE_HISTORY_CSV`

Comportamiento recomendado por defecto:

1. Legacy activado para no romper consumo existente.
2. Latest desactivado hasta habilitar sincronizacion progresiva.
3. History desactivado hasta activar snapshots por fecha.

Las rutas objetivo son:

- Legacy: `datos/*.csv`
- Latest: `datos/latest/*.csv`
- History: `datos/history/<dataset>/year=YYYY/month=MM/day=DD/*.csv`

Cuando se agreguen nuevas salidas o validaciones:

1. Actualizar contrato correspondiente.
2. Agregar/ajustar tests.
3. Mantener este documento sincronizado.
