# Estandar de Estilo del Repositorio

Este documento define reglas para mantener consistencia tecnica y colaboracion.

## 1) Idioma por Area

- `README.md`: ingles.
- `docs/`: espanol (terminos tecnicos pueden quedar en ingles).
- `backend/`:
  - comentarios y docstrings en ingles.
  - nombres ETL de negocio existentes pueden mantenerse en espanol.
  - modulos tecnicos y utilidades compartidas en ingles.

## 2) Naming y Estructura

- usar nombres profesionales y estables.
- evitar nombres temporales en codigo (`fase`, `pr-xx`, `tmp`, etc).
- mantener coherencia con el estilo del modulo antes de renombrar APIs.
- evitar sobre-comentarios; comentar solo cuando agrega contexto real.
- no usar emojis en codigo backend.

## 3) Reglas de Implementacion

- cambios incrementales y compatibles con comportamiento actual.
- no romper contratos publicos sin requerimiento funcional explicito.
- separar logica de negocio y utilidades tecnicas.
- toda capa nueva debe incluir tests.

## 4) Flujo de Ramas

- `main`: rama estable.
- `feat/backend`: cambios backend.
- `feat/frontend`: cambios frontend.

Antes de PR:
1. actualizar rama con `main`.
2. correr tests relevantes.
3. verificar build/smoke cuando aplique.

## 5) Commits

- mensajes en ingles, claros y breves.
- evitar titulos con terminologia interna del plan (`f2`, `pr03`, etc).
- un commit debe agrupar cambios coherentes.

## 6) Validacion Minima antes de Push

- `pytest -q`
- smoke ETL si se toca pipeline.
- smoke frontend si se toca integracion de assets.
- confirmar que cambios no relacionados no se incluyan por error.

## 7) Politica de Artefactos Generados

- no commitear salidas runtime (`datos/latest`, `datos/history`, `datos/metadata`) salvo decision explicita.
- commitear codigo, tests y documentacion.

## 8) Definicion de Listo

- tests en verde.
- sin regresiones de contrato de datos.
- comportamiento de rollback definido para cambios de riesgo.
