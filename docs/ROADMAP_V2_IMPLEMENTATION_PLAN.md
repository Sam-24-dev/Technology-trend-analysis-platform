# ROADMAP FRONTEND V2 FINAL - Technology Trend Analysis Platform

## 1) Resumen

Este documento define el plan final de implementacion frontend V2 en la rama `feat/frontend`.

Objetivo:
- migrar de consumo CSV-first a JSON-first con fallback controlado,
- mejorar UX/UI (responsive + accesibilidad),
- mantener compatibilidad con el backend V2 ya implementado,
- ejecutar por fases (PR-FE-01 a PR-FE-04) sin romper dashboards actuales.

Nota de gobernanza:
- En esta rama se usa este roadmap frontend como documento principal en `docs/ROADMAP_V2_IMPLEMENTATION_PLAN.md`.
- El roadmap backend ya vive en la historia de `main` y `feat/backend`.

## 2) Decisiones cerradas (obligatorias)

1. Estrategia: migracion hibrida gradual.
2. Stack frontend: Riverpod + GoRouter.
3. Routing V2.0: hash routing (`/#/...`) oficial.
4. UI idioma: espanol.
5. Diseno: evolutivo premium (sin rediseno total disruptivo).
6. Accesibilidad gate: WCAG AA practico.
7. Metadata UI: `run_manifest.json` publico reducido.
8. Fuente de verdad de degradacion: frontend NO recalcula `degraded_mode`.
9. Export ZIP: reemplazar `universal_html` con `file_saver + DownloadService`.
10. Cobertura: rampa por PR + regla no-drop.
11. Owner por fase: owner unico en FE-01..FE-04.

## 3) Variables operativas CI (desde FE-01)

- `REQUIRE_FRONTEND_METADATA`
  - `0` en `feat/*`
  - `1` en `main`
- `USE_PUBLIC_RUN_MANIFEST=true`
- `USE_HISTORY_BRIDGE_JSON=true`
- `ENABLE_CSV_FALLBACK=true` (hasta cutover final)

## 3.1) Tooling local UI/UX asistido (UIPro)

Estado:
- habilitado como apoyo local de diseno para frontend V2.

Alcance:
- se usa como soporte de UX/UI principalmente en FE-03 (responsive + accesibilidad + polish visual)
  y FE-04 (consistencia final de componentes).

Reglas:
- configuraciones de asistentes generadas por `uipro init --ai all` son solo locales.
- no forman parte del entregable funcional de backend/frontend.
- no se incluyen en commits ni PRs.

Carpetas locales de asistencia (no versionar):
- `.agent/`
- `.claude/`
- `.codebuddy/`
- `.codex/`
- `.continue/`
- `.cursor/`
- `.gemini/`
- `.kiro/`
- `.opencode/`
- `.qoder/`
- `.roo/`
- `.trae/`
- `.windsurf/`
- `.github/prompts/`

Uso recomendado:
- aplicar prompts de diseno de forma controlada por pantalla/componente.
- no aceptar cambios visuales que rompan:
  - breakpoints objetivo,
  - contraste WCAG AA practico,
  - estados de error/degraded,
  - consistencia con el estilo del producto.

## 3.2) Reglas de agente locales con `.cursorrules`

Estado:
- activo como control de arquitectura para asistentes AI durante implementacion frontend.

Objetivo:
- evitar mezcla de patron legado con arquitectura V2 (`DataService -> Repository -> Riverpod -> UI`),
- forzar planificacion antes de cambios grandes,
- estandarizar decisiones de routing, fallback y calidad.

Uso por fase:
- FE-01: validar contratos, CI y manifest publico sin romper reglas de arquitectura.
- FE-02: aplicar regla estricta Riverpod (sin estado de dominio con `setState`).
- FE-03: aplicar reglas de responsive/a11y + routing hash.
- FE-04: aplicar reglas de limpieza tecnica y gates strict.

Como usarlo (operativo):
1. Mantener `.cursorrules` actualizado en la raiz local del repo.
2. Al iniciar sesion con un asistente, pedir explicitamente:
   - \"lee `.cursorrules` y sigue estas reglas para esta tarea\".
3. Revisar que el plan del asistente respete:
   - arquitectura por capas,
   - feature flags,
   - pruebas y rollback.
4. Si el asistente propone codigo fuera del patron, rechazar y reintentar con referencia directa al archivo.

Nota:
- `.cursorrules` es configuracion local de asistencia; no es parte del artefacto funcional de produccion.

## 3.3) Debug web asistido con `chrome-devtools-mcp`

Estado:
- habilitado localmente para soporte de debugging en Flutter Web.

Objetivo:
- diagnosticar errores de runtime web que no aparecen en tests unitarios/widget,
- inspeccionar consola/red/performance durante problemas de routing hash y descarga ZIP.

Uso por fase:
- FE-01:
  - validar que no existan errores JS en arranque web y carga de assets/manifest.
- FE-03:
  - validar deep links hash (`/#/github`, `/#/stackoverflow`, etc.) y refresh sin errores.
- FE-04:
  - validar export ZIP en web tras reemplazo de `universal_html` por `DownloadService` + `file_saver`.

Comandos de validacion local:
- smoke de instalacion/CLI:
  - `npx -y chrome-devtools-mcp@latest --help`
- smoke de arranque MCP (headless):
  - `npx -y chrome-devtools-mcp@latest --headless --isolated --viewport 1280x720`

Cuando usarlo:
- error intermitente solo en navegador,
- fallo de navegacion hash/deep-link en refresh,
- error de descarga/export ZIP en web,
- necesidad de inspeccionar warnings/errores de consola y requests en vivo.

Cuando no usarlo:
- para bugs puros de logica de dominio que ya se reproducen en tests,
- para cambios de backend ETL/CI que no dependen del runtime web del navegador.

Reglas operativas:
- herramienta local de debugging, no parte del artefacto de produccion.
- no versionar configuraciones locales ni logs de sesion de MCP.
- resultado de debugging debe traducirse en tests/regresion cuando aplique.

## 3.4) CI/PR asistido con `github-mcp-server` (GitHub MCP)

Estado:
- habilitado en el entorno local para consultar runs, jobs y logs de GitHub Actions desde el agente.

Objetivo:
- acelerar diagnostico de fallos de CI sin navegar manualmente cada log en la UI de GitHub.
- priorizar fixes de FE segun evidencia real de pipeline (tests, coverage, allowlist, budgets).

Uso por fase:
- FE-01:
  - revisar fallos de `flutter analyze`, `flutter test`, coverage inicial (gate >=20%).
  - validar contrato de artifacts/assets (modo warning).
- FE-02:
  - revisar regresiones de providers/data layer y fallback JSON/CSV en CI.
- FE-03:
  - revisar fallos de routing/responsive/a11y en jobs de frontend.
- FE-04:
  - revisar gates strict (coverage >=55%, allowlist strict, budgets de assets).

Comandos de validacion local:
- verificar que MCP este registrado en Codex:
  - `codex mcp list`
- inspeccionar configuracion de un servidor:
  - `codex mcp get github`

Cuando usarlo:
- cuando un workflow/PR falla y necesitas root cause exacto desde logs.
- cuando el error en CI no se reproduce igual en local.
- para confirmar que el fix realmente resolvio el job fallido.

Cuando no usarlo:
- para bugs puramente de UI local ya diagnosticados con `chrome-devtools-mcp`.
- para tareas que no dependen de resultados de GitHub Actions.

Reglas operativas:
- no hardcodear tokens en repositorio ni en archivos versionados.
- preferir credenciales por entorno/secret manager del IDE.
- si se usa token personal local, mantenerlo fuera del repo y rotarlo ante cualquier exposicion accidental.

## 4) Contrato publico `run_manifest.json` (UI)

Ruta destino:
- `frontend/assets/data/run_manifest.json`

Fuente:
- `datos/metadata/run_manifest.json` (interno completo)
- transformado a version publica reducida para UI

Campos publicos requeridos:
- `manifest_version` (SemVer `x.y.z`)
- `generated_at_utc` (ISO-8601)
- `source_window_start_utc` (ISO-8601)
- `source_window_end_utc` (ISO-8601)
- `quality_gate_status` (`pass|pass_with_warnings|fail`)
- `degraded_mode` (bool)
- `available_sources` (subset unico de `github|stackoverflow|reddit`)
- `dataset_summaries` (array >= 1)
- `notes` (opcional, string/null)

`dataset_summaries[]`:
- `dataset`
- `row_count`
- `quality_status` (`pass|warning|fail`)
- `updated_at_utc`

Reglas:
- Frontend renderiza `degraded_mode` y `available_sources` tal como llegan del manifest.
- Si falta metadata:
  - en `feat/*`: warning + fallback UI (`metadata unavailable`)
  - en `main`: falla pipeline si `REQUIRE_FRONTEND_METADATA=1`.

## 5) Arquitectura frontend objetivo

Flujo:
- `DataService` -> `Repository` por dominio -> `Riverpod Providers` -> UI

Providers minimos:
- `runManifestProvider`
- `historyIndexProvider`
- `trendTemporalProvider`
- `githubDashboardProvider`
- `stackoverflowDashboardProvider`
- `redditDashboardProvider`
- `frontendHealthProvider`

Estados estandar:
- `loading`
- `data`
- `degraded`
- `error`

TTL cache:
- Manifest: 5 min
- History index: 15 min
- Trend history: 15 min
- Dashboards de corrida: 30 min

Retry policy:
- 3 intentos: `300ms`, `900ms`, `1800ms`
- retry solo en timeout/5xx
- 404: no retry, fallback inmediato

## 6) Routing, responsive y accesibilidad

Routing V2.0:
- `/#/`
- `/#/github`
- `/#/stackoverflow`
- `/#/reddit`
- `/#/trends/:tech`

Responsive gate obligatorio:
- `390x844` (portrait)
- `844x390` (landscape)
- `768x1024`
- `1024x768`
- `1280+`

Criterios:
- cero overflow/layout exceptions
- navegacion usable touch + mouse + teclado
- sidebar adaptativo (drawer/rail/sidebar segun breakpoint)

Accesibilidad (WCAG AA practico):
- contraste suficiente
- focus visible
- soporte teclado
- semantics labels en elementos interactivos
- no depender solo de color para estado

## 7) Plan por fases (PR-ready)

## PR-FE-01 - Foundation + Metadata publica + CI frontend

Owner:
- owner unico

Objetivo:
- habilitar metadata publica y baseline de calidad frontend.

Cambios principales:
- `backend/config/run_manifest_public_schema.json` (new)
- `backend/config/run_manifest_public_contract.py` (new)
- `backend/generate_run_manifest.py` (new)
- `backend/sync_assets.py` (update: publicar `run_manifest.json` publico)
- `.github/workflows/etl_semanal.yml` (update: generar/validar manifest publico)
- `.github/workflows/ci.yml` (update: `flutter analyze`, `flutter test`, coverage, checks assets)
- `scripts/check_frontend_assets.py` (new, modo warning)
- `frontend/test/smoke/main_app_smoke_test.dart` (new)
- `frontend/test/contracts/run_manifest_contract_test.dart` (new)
- `docs/frontend_coding_style.md` (new)
- `docs/frontend_ui_ux_rules.md` (new)

DoD:
- manifest publico publicado y valido
- fallback UI funcional si metadata falta
- CI frontend en verde
- baseline inicial registrado:
  - cobertura inicial
  - peso total assets
  - tiempo de build web

Rollback:
- `USE_PUBLIC_RUN_MANIFEST=false`
- `REQUIRE_FRONTEND_METADATA=0`
- revert de pasos workflow/manifest

## PR-FE-02 - Data layer JSON-first + Riverpod

Owner:
- owner unico

Objetivo:
- centralizar carga/estado por dominio con fallback CSV controlado.

Cambios principales:
- `frontend/pubspec.yaml` (add `flutter_riverpod`)
- `frontend/lib/services/data_service.dart` (new)
- `frontend/lib/services/retry_policy.dart` (new)
- `frontend/lib/services/csv_service.dart` (wrapper temporal)
- `frontend/lib/models/*_models.dart` para manifest/history/trend
- `frontend/lib/repositories/*.dart` (new)
- `frontend/lib/providers/*.dart` (new)
- ajuste de pantallas para consumir providers

DoD:
- JSON-first operativo
- estados `loading/data/degraded/error` estandarizados
- fallback CSV funcionando por flag
- sin regresiones en dashboards

Rollback:
- `USE_HISTORY_BRIDGE_JSON=false`
- `ENABLE_CSV_FALLBACK=true`

## PR-FE-03 - GoRouter + responsive + a11y + DataHealthBadge

Owner:
- owner unico

Objetivo:
- cerrar experiencia de navegacion web y UX cross-device.

Cambios principales:
- `frontend/pubspec.yaml` (add `go_router`)
- `frontend/lib/router/app_router.dart` (new)
- `frontend/lib/main.dart` (`MaterialApp.router`)
- `frontend/lib/screens/main_screen.dart` (shell responsive)
- `frontend/lib/widgets/data_health_badge.dart` (new)
- `frontend/lib/widgets/degraded_state_card.dart` (new)
- refactor de dashboards/home para estados degradados
- tests de routing/responsive/a11y

DoD:
- deep links hash + refresh OK
- responsive gate completo (incluye landscape movil)
- badge de salud operativo
- accesibilidad minima obligatoria cumplida

Rollback:
- fallback temporal a shell previo si router rompe flujo
- mantener badge en `unknown` si metadata no disponible

## PR-FE-04 - Cutover tecnico + limpieza + strict CI

Owner:
- owner unico

Objetivo:
- consolidar frontend V2, limpiar deuda y activar gates strict.

Cambios principales:
- `frontend/lib/services/download/download_service.dart` (new)
- `frontend/lib/services/download/download_service_web.dart` (new)
- `frontend/lib/services/download/download_service_stub.dart` (new)
- reemplazo de `universal_html` por `file_saver + adapter`
- `frontend/pubspec.yaml` (remove `universal_html`, add `file_saver`)
- `backend/sync_assets.py` (allowlist strict)
- `.github/workflows/etl_semanal.yml` (validaciones strict outputs)
- `.github/workflows/ci.yml` (coverage ramp + no-drop + assets strict)

DoD:
- export ZIP funcional sin `universal_html`
- assets allowlist strict activo
- budgets de tamano en verde
- cobertura >=55% sin violar regla no-drop

Rollback:
- `ENABLE_CSV_FALLBACK=true`
- downgrade temporal de strict->warning solo en emergencia

## 8) Cobertura por rampa y gate

Umbral por PR:
- FE-01: >=20%
- FE-02: >=35%
- FE-03: >=45%
- FE-04: >=55%

Regla no-drop:
- cobertura global del PR no puede ser menor a `main` (tolerancia tecnica: 0.5 puntos)

Politica `flutter analyze` FE-01:
- errors/warnings bloquean
- infos no bloquean (se reportan)

## 9) Policy de assets frontend (CI)

Allowlist oficial:
- `trend_score.csv`
- `github_lenguajes.csv`
- `github_commits_frameworks.csv`
- `github_correlacion.csv`
- `so_volumen_preguntas.csv`
- `so_tasa_aceptacion.csv`
- `so_tendencias_mensuales.csv`
- `reddit_sentimiento_frameworks.csv`
- `reddit_temas_emergentes.csv`
- `interseccion_github_reddit.csv`
- `history_index.json`
- `trend_score_history.json`
- `run_manifest.json`

Budgets:
- max por archivo: `<=150 KB`
- max total data: `<=600 KB`
- ruta critica: `<=250 KB`

Reglas CI:
- falla si aparece asset no allowlisted
- falla si falta asset required
- falla si codigo referencia asset inexistente
- falla si asset allowlisted no se referencia en `frontend/lib/**`
- FE-01: modo warning
- FE-04: modo strict

## 10) Escenarios de prueba obligatorios

1. Contrato `run_manifest.json` valido/invalido.
2. Contratos `history_index.json` y `trend_score_history.json`.
3. Fallback metadata missing -> badge gris + UI operativa.
4. Fallback bridge missing -> CSV snapshot.
5. Estados `loading/data/degraded/error` por dominio.
6. Retry transitorio y no retry en 404.
7. Routing hash con refresh web.
8. Responsive en portrait y landscape movil.
9. A11y smoke (focus, teclado, semantics, contraste).
10. Export ZIP web sin `universal_html`.
11. Allowlist y budgets en CI.
12. No regresion de dashboards actuales.

## 11) Riesgos y mitigaciones

- Riesgo: overlap labels/charts en movil.
  - Mitigacion: truncado + tooltip + scroll horizontal controlado.
- Riesgo: cambios de schema de manifest sin coordinacion.
  - Mitigacion: contract tests frontend obligatorios + schema versionado.
- Riesgo: fallback CSV permanente.
  - Mitigacion: owner + criterio de salida + fecha objetivo de retiro en FE-04.

## 12) Criterio de salida y cutover final

Para declarar frontend V2 cutover-ready:
1. FE-01..FE-04 completados con DoD en verde.
2. 4 corridas semanales consecutivas sin `critical`.
3. `run_manifest` publico estable en assets.
4. SLO frontend en rango (errores de carga controlados).
5. Luego desactivar fallback por defecto (`ENABLE_CSV_FALLBACK=false`) en release de cutover.

---

Estado del documento:
- aprobado para ejecucion por fases.
- iniciar por FE-01 y no mezclar fases en un mismo PR.
