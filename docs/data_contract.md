# Contrato de datos CSV (Backend ↔ Frontend)

Este documento formaliza el contrato de columnas entre el pipeline ETL (`backend/`) y el dashboard Flutter (`frontend/`).

## Fuente de verdad

El contrato ejecutable vive en:

- `backend/config/csv_contract.py`

Versión actual del contrato:

- `CONTRACT_VERSION = 2026.03`

El validador consume ese contrato para verificar columnas requeridas y columnas críticas.

Además, el pipeline ETL semanal ejecuta validación de headers con:

- `python backend/validate_csv_contract.py`

Si faltan columnas requeridas o no se cumplen tipos mínimos, el workflow falla antes de publicar cambios de datos.

Modo opcional no estricto (solo advertencias):

- `python backend/validate_csv_contract.py --no-strict`

## Reglas del contrato

1. **required_columns**: deben existir para considerar que el CSV cumple contrato.
2. **critical_columns**: no deberían contener nulos; en modo estricto, fallan la validación.
3. **column_types**: define tipos mínimos esperados por columna (`string`, `integer`, `number`, `datetime`, `string_or_integer`).
4. **optional_columns**: columnas permitidas (compatibilidad y métricas adicionales), pero no obligatorias.

## Tipos mínimos por archivo (resumen)

- `github_repos.csv`
  - `repo_name:string`, `language:string`, `stars:integer`, `forks:integer`, `created_at:datetime`
- `github_lenguajes.csv`
  - `lenguaje:string`, `repos_count:integer`, `porcentaje:number`
- `github_ai_repos_insights.csv`
  - `total_repos_analizados:integer`, `repos_ai_detectados:integer`, `porcentaje_ai:number`, `mes_pico_ai:string`, `repos_mes_pico_ai:integer`, `top_keywords_ai:string`, `top_repos_ai:string`
- `github_commits_frameworks.csv`
  - `framework:string`, `repo:string`, `commits_2025:integer`, `ranking:integer`
- `github_correlacion.csv`
  - `repo_name:string`, `stars:integer`, `contributors:integer`, `language:string`
- `so_volumen_preguntas.csv`
  - `lenguaje:string`, `preguntas_nuevas_2025:integer`
- `so_tasa_aceptacion.csv`
  - `tecnologia:string`, `total_preguntas:integer`, `respuestas_aceptadas:integer`, `tasa_aceptacion_pct:number`
- `so_tendencias_mensuales.csv`
  - `mes:string`, `python:integer`, `javascript:integer`, `typescript:integer`
- `reddit_sentimiento_frameworks.csv`
  - `framework:string`, `total_menciones:integer`, `positivos:integer`, `neutros:integer`, `negativos:integer`
  - opcionales: `% positivo:number`, `% neutro:number`, `% negativo:number`
- `reddit_temas_emergentes.csv`
  - `tema:string`, `menciones:integer`
- `interseccion_github_reddit.csv`
  - `tecnologia:string`, `tipo:string`, `ranking_github:integer`, `ranking_reddit:string_or_integer`
- `trend_score.csv`
  - `ranking:integer`, `tecnologia:string`, `github_score:number`, `so_score:number`, `reddit_score:number`, `trend_score:number`, `fuentes:integer`

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
