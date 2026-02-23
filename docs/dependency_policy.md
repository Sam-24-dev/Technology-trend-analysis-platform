# Politica de Dependencias y Seguridad

Esta politica define criterios minimos para mantener estabilidad y seguridad en backend.

## Objetivos

- controlar versiones en `backend/requirements.txt`.
- detectar vulnerabilidades conocidas de forma continua.
- mantener reproducibilidad en CI y local.

## Reglas de Versionado

1. usar rangos compatibles con limite superior.
2. evitar upgrades de major sin validacion de regresion.
3. mantener dependencias de test en major estable (`pytest >=8,<9`).

## Dependencias Core Actuales

- `pandas`
- `requests`
- `nltk`
- `pandera`
- `duckdb`
- `python-dotenv`

## Auditoria de Seguridad

Workflow: `.github/workflows/dependency_security.yml`

Se ejecuta en:
- push a `main` y `feat/backend` con cambios en `backend/requirements.txt`.
- pull request a `main` con cambios en dependencias.
- schedule semanal: lunes `09:00 UTC`.
- manual (`workflow_dispatch`).

Herramienta:
- `pip-audit`

Si hay vulnerabilidades, el job falla y no se recomienda merge a `main`.

Excepcion temporal vigente:
- `CVE-2025-14009` (`nltk 3.9.2`) esta ignorado en CI porque no existe version parche publicada.
- La excepcion debe revisarse semanalmente y removerse apenas exista fix oficial de `nltk`.

## Flujo Recomendado de Actualizacion

1. crear rama de trabajo.
2. cambiar dependencias minimas necesarias.
3. ejecutar:
   - `python -m pytest -q`
   - pipeline de seguridad.
4. documentar en PR:
   - librerias cambiadas
   - motivo
   - evidencia de tests

## Cadencia Recomendada

- mensual: patch/minor review.
- trimestral: analisis de majors.
- inmediato: CVEs de severidad alta/critica.
