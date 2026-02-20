# Política mínima de dependencias y seguridad

Esta política reduce riesgo técnico y mejora reproducibilidad para el backend.

## Objetivos

- Mantener rangos de versiones controlados en `backend/requirements.txt`.
- Detectar vulnerabilidades conocidas de forma continua.
- Definir una cadencia mínima de actualización.

## Reglas de versionado

1. Evitar rangos abiertos en major (`<3.0` para todo) cuando no sea necesario.
2. Usar límites superiores por compatibilidad real del proyecto.
3. Mantener `pytest` en major estable (`>=8,<9`).

## Auditoría de seguridad

- Local:
  - `make security`
- CI:
  - Workflow: `Dependency Security Audit`
  - Se ejecuta en:
    - cambios de `backend/requirements.txt`
    - `pull_request` hacia `main`
    - semanalmente (lunes)
    - manualmente (`workflow_dispatch`)

Si se detectan CVEs, el job falla y se debe corregir antes de mergear a `main`.

## Política mínima de actualización

- **Mensual**: revisar updates menores/patch de librerías.
- **Trimestral**: revisar nuevos majors y plan de adopción.
- **Inmediato**: parchear CVEs con severidad alta/crítica.

## Flujo recomendado

1. Crear rama de actualización.
2. Ajustar `backend/requirements.txt` con cambios mínimos.
3. Ejecutar:
   - `python -m pytest tests/ -q`
   - `make security`
4. Abrir PR con resumen:
   - librerías cambiadas
   - motivo (bugfix/CVE/compatibilidad)
   - evidencia de tests y auditoría.
