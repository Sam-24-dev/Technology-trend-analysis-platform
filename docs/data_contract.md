# Contrato de datos CSV (Backend ↔ Frontend)

Este documento formaliza el contrato de columnas entre el pipeline ETL (`backend/`) y el dashboard Flutter (`frontend/`).

## Fuente de verdad

El contrato ejecutable vive en:

- `backend/config/csv_contract.py`

Versión actual del contrato:

- `CONTRACT_VERSION = 2026.02`

El validador consume ese contrato para verificar columnas requeridas y columnas críticas.

Además, el pipeline ETL semanal ejecuta validación de headers con:

- `python backend/validate_csv_contract.py`

Si faltan columnas requeridas, el workflow falla antes de publicar cambios de datos.

## Reglas del contrato

1. **required_columns**: deben existir para considerar que el CSV cumple contrato.
2. **critical_columns**: no deberían contener nulos; si aparecen, se reportan advertencias.
3. **optional_columns**: columnas permitidas (compatibilidad y métricas adicionales), pero no obligatorias.

## Archivos clave consumidos por frontend

- `github_lenguajes.csv`
  - requeridas: `lenguaje`, `repos_count`, `porcentaje`
- `so_volumen_preguntas.csv`
  - requeridas: `lenguaje`, `preguntas_nuevas_2025`
- `so_tasa_aceptacion.csv`
  - requeridas: `tecnologia`, `total_preguntas`, `respuestas_aceptadas`, `tasa_aceptacion_pct`
- `reddit_temas_emergentes.csv`
  - requeridas: `tema`, `menciones`
- `trend_score.csv`
  - requeridas: `ranking`, `tecnologia`, `github_score`, `so_score`, `reddit_score`, `trend_score`, `fuentes`

## Compatibilidad de `reddit_sentimiento_frameworks.csv`

El backend mantiene como requeridas:

- `framework`, `total_menciones`, `positivos`, `neutros`, `negativos`

Y como opcionales para visualización:

- `% positivo`, `% neutro`, `% negativo`

Esto evita acoplamiento implícito y deja explícita la coexistencia de métricas absolutas y porcentuales.
