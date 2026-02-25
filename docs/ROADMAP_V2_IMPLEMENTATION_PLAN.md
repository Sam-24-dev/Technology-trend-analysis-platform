# ROADMAP FRONTEND V2 FINAL - Technology Trend Analysis Platform

## 1) Resumen

Este documento define el plan final de implementacion frontend V2 en la rama `feat/frontend`.

Objetivo:
- migrar de consumo CSV-first a JSON-first con fallback controlado,
- mejorar UX/UI (responsive + accesibilidad),
- mantener compatibilidad con el backend V2 ya implementado,
- ejecutar por fases (PR-FE-01 a PR-FE-04) sin romper dashboards actuales.

Nota de gobernanza:
- En esta rama se usa este roadmap frontend como documento principal en `docs/ROADMAP_V2_IMPLEMENTATION_PLAN.md`, reemplazando el contenido previo del roadmap backend V2 en este archivo.
- El roadmap backend V2 original permanece accesible en el historial de `main` y en la rama `feat/backend`.

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

Estado:
- DONE

Evidencia de cierre:
- contrato publico de manifest implementado y versionado:
  - `backend/config/run_manifest_public_schema.json`
  - `backend/config/run_manifest_public_contract.py`
  - `backend/generate_run_manifest.py`
- publicacion/sync de metadata publica integrada:
  - `backend/sync_assets.py`
  - `frontend/assets/data/run_manifest.json`
- CI/workflows actualizados para FE baseline:
  - `.github/workflows/ci.yml`
  - `.github/workflows/etl_semanal.yml`
  - `scripts/check_frontend_assets.py`
- pruebas FE-01 activas:
  - `frontend/test/smoke/main_app_smoke_test.dart`
  - `frontend/test/contracts/run_manifest_contract_test.dart`
  - `tests/test_run_manifest_public_contract.py`
  - `tests/test_generate_run_manifest.py`
- baseline registrado:
  - cobertura inicial FE (pre-smokes de dashboards): `31.85%` (`LH=544`, `LF=1708`)
  - peso total de `frontend/assets/data`: `156279` bytes
  - `flutter build web --debug`: `144.94s`

Hallazgos importantes:
- tras introducir Riverpod en UI, el smoke test de app requiere `ProviderScope` explicito para evitar `No ProviderScope found`.
- build web debug reporta warning de wasm por `universal_html`; su remocion queda en alcance de FE-04.
- el asset dominante sigue siendo `github_repos_2025.csv` (~140 KB), punto de optimizacion para fase de limpieza.

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

Estado:
- DONE

Evidencia de cierre:
- Data layer JSON-first implementado:
  - `frontend/lib/services/data_service.dart`
  - `frontend/lib/services/retry_policy.dart`
  - `frontend/lib/repositories/*.dart`
  - `frontend/lib/providers/app_providers.dart`
  - `frontend/lib/models/*_models.dart` (manifest/history/trend/domain state)
- `csv_service.dart` queda como wrapper temporal para fallback compatible.
- pantallas principales conectadas a providers de dominio:
  - `frontend/lib/screens/home_screen.dart`
  - `frontend/lib/screens/github_dashboard.dart`
  - `frontend/lib/screens/stackoverflow_dashboard.dart`
  - `frontend/lib/screens/reddit_dashboard.dart`
- validacion tecnica:
  - `flutter analyze --no-fatal-infos` -> `exit 0` (solo `info`, no errors/warnings bloqueantes)
  - `flutter test --coverage` -> `28 passed`
  - cobertura FE actual: `75.41%` (`LH=1288`, `LF=1708`)
  - regresion backend: `pytest -q` -> `146 passed`

Hallazgos importantes:
- los smokes de dashboards detectaron overflows en viewport pequeno de test (`1280x720`), por lo que se estabilizo el smoke de FE-02 con viewport desktop amplio; hardening responsive queda como entregable obligatorio de FE-03.
- estado de degradacion queda estandarizado via `DataLoadState` (`loading/data/degraded/error`) y centralizado en providers/repositorios.
- politica de retry queda aplicada (3 intentos con backoff) y 404 mantiene fallback inmediato sin retry.

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

Estado:
- DONE

Evidencia de cierre:
- routing con `go_router` integrado:
  - `frontend/pubspec.yaml`
  - `frontend/lib/router/app_router.dart`
  - `frontend/lib/main.dart` (`MaterialApp.router`)
- shell responsive implementado por breakpoint:
  - `frontend/lib/screens/main_screen.dart` (desktop sidebar, tablet rail, mobile drawer/appbar)
- observabilidad UI y estado degradado:
  - `frontend/lib/widgets/data_health_badge.dart`
  - `frontend/lib/widgets/degraded_state_card.dart`
  - refactor de uso en `frontend/lib/screens/home_screen.dart`, `frontend/lib/screens/github_dashboard.dart`, `frontend/lib/screens/stackoverflow_dashboard.dart`, `frontend/lib/screens/reddit_dashboard.dart`
- pruebas FE-03 agregadas:
  - `frontend/test/router/app_router_test.dart`
  - `frontend/test/widgets/main_screen_responsive_test.dart`
  - `frontend/test/widgets/data_health_badge_test.dart`
- validacion tecnica:
  - `flutter test --coverage` -> `37 passed`
  - cobertura FE: `80.78%` (`LH=1513`, `LF=1873`)
  - `flutter analyze --no-fatal-infos` -> `exit 0` (sin errores bloqueantes)
  - `flutter build web --debug` -> `success`
  - regresion backend: `pytest -q` -> `146 passed`

Hallazgos importantes:
- para evitar conflictos de scroll en tests/routing se desactivo el uso de `PrimaryScrollController` compartido dentro del shell y se estabilizo el contenedor scrollable por ruta.
- se detectaron overflows reales en home en viewport movil; se corrigieron con `Wrap`/`Expanded` en secciones clave.
- `DataHealthBadge` queda operativo con fallback `unknown` y tooltip de metadata.
- wasm dry-run sigue reportando incompatibilidad por `universal_html`; su retiro permanece en alcance de FE-04 (cutover tecnico).

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

Estado:
- DONE

Evidencia de cierre:
- adapter de descarga implementado y desacoplado por plataforma:
  - `frontend/lib/services/download/download_service.dart`
  - `frontend/lib/services/download/download_service_web.dart`
  - `frontend/lib/services/download/download_service_stub.dart`
- export ZIP migrado sin `universal_html`:
  - `frontend/lib/screens/github_dashboard.dart`
  - `frontend/lib/screens/stackoverflow_dashboard.dart`
  - `frontend/lib/screens/reddit_dashboard.dart`
- dependencias frontend actualizadas para cutover tecnico:
  - `frontend/pubspec.yaml` (`universal_html` removido, `file_saver` agregado)
- allowlist strict aplicado en sincronizacion backend:
  - `backend/sync_assets.py` (skip de CSV no allowlisted + modo `warning|strict`)
- workflows endurecidos para FE-04:
  - `.github/workflows/etl_semanal.yml`
  - `.github/workflows/ci.yml` (coverage min 55, no-drop en PR, assets strict)
- pruebas/validaciones ejecutadas:
  - `flutter analyze --no-fatal-infos` -> `exit 0` (solo infos)
  - `flutter test --coverage` -> `38 passed`
  - cobertura FE: `81.08%` (`LH=1517`, `LF=1871`)
  - `flutter build web --debug` -> `success` (`Wasm dry run succeeded`)
  - `python scripts/check_frontend_assets.py --mode strict --root .` -> `success`
    - `assets=13`, `total=15.3 KB`, `critical=9.6 KB`
  - `pytest -q` -> `151 passed`

Hallazgos importantes:
- para activar assets strict fue necesario retirar archivos no allowlisted en `frontend/assets/data/` (`github_repos_2025.csv` y `github_ai_repos_insights.csv`), ya que bloqueaban el gate.
- el gate no-drop de cobertura se implemento comparando contra la rama base en PR (`git worktree` + `flutter test --coverage`), lo que aumenta tiempo de CI pero evita regresion silenciosa.
- se detecto bug de `flutter pub remove` (`yaml_edit`) en este entorno; la remocion de `universal_html` se resolvio con edicion manual de `pubspec.yaml`.

## 8) Cobertura por rampa y gate
Estado actual:
- IMPLEMENTADO en `.github/workflows/ci.yml` (`FRONTEND_PHASE`, gate de cobertura minima por fase y regla no-drop).

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
Estado actual:
- IMPLEMENTADO en `scripts/check_frontend_assets.py`, `.github/workflows/ci.yml` y `.github/workflows/etl_semanal.yml`.

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
Estado actual (avance por bloques):
- [x] 1. Contrato `run_manifest.json` valido/invalido.
- [x] 2. Contratos `history_index.json` y `trend_score_history.json`.
- [x] 3. Fallback metadata missing -> badge gris + UI operativa.
- [x] 4. Fallback bridge missing -> CSV snapshot.
- [x] 5. Estados `loading/data/degraded/error` por dominio.
- [x] 6. Retry transitorio y no retry en 404.
- [x] 7. Routing hash con refresh web.
- [x] 8. Responsive en portrait y landscape movil.
- [x] 9. A11y smoke (focus, teclado, semantics, contraste).
- [x] 10. Export ZIP web sin `universal_html`.
- [x] 11. Allowlist y budgets en CI.
- [x] 12. No regresion de dashboards actuales.

Evidencia bloque 1:
- escenario 1: `frontend/test/contracts/run_manifest_contract_test.dart`
- escenario 2: `frontend/test/contracts/history_bridge_contract_test.dart`
- ejecucion: `flutter test test/contracts/run_manifest_contract_test.dart test/contracts/history_bridge_contract_test.dart` -> `6 passed`

Evidencia bloque 2:
- escenario 3:
  - `frontend/test/widgets/main_screen_responsive_test.dart` (`metadata missing mantiene badge unknown y UI operativa`)
- escenario 4:
  - `frontend/test/repositories/repositories_test.dart` (`TrendRepository keeps CSV snapshot data when bridge is unavailable`)
- ejecucion: `flutter test test/widgets/main_screen_responsive_test.dart test/repositories/repositories_test.dart` -> `14 passed`

Evidencia bloque 3:
- escenario 5:
  - `frontend/test/providers/app_providers_test.dart` (`domain providers expose loading before resolving`)
  - `frontend/test/repositories/repositories_test.dart` (matriz `data/degraded/error` para `github`, `stackoverflow`, `reddit`)
- escenario 6:
  - `frontend/test/services/retry_policy_test.dart` (`HTTP 503` retry + `404/not found` sin retry)
- ejecucion: `flutter test test/providers/app_providers_test.dart test/repositories/repositories_test.dart test/services/retry_policy_test.dart` -> `18 passed`

Evidencia bloque 4:
- escenario 7:
  - `frontend/test/router/app_router_test.dart` (`go_router hash deep-link /#/github` + `refresh simulado`)
- escenario 8:
  - `frontend/test/widgets/main_screen_responsive_test.dart` (`390x844` y `844x390`)
  - `frontend/test/widgets/dashboard_smoke_test.dart` (smoke de dashboards en `390x844` y `844x390` sin exceptions)
- escenario 9:
  - `frontend/test/widgets/a11y_smoke_test.dart` (focus/teclado, semantics labels, contraste WCAG AA)
- ejecucion: `flutter test test/router/app_router_test.dart test/widgets/main_screen_responsive_test.dart test/widgets/dashboard_smoke_test.dart test/widgets/a11y_smoke_test.dart` -> `19 passed`

Evidencia bloque 5:
- escenario 10:
  - implementacion: `frontend/lib/services/download/download_service.dart`, `frontend/lib/services/download/download_service_web.dart`, `frontend/lib/services/download/download_service_stub.dart`
  - test: `frontend/test/services/download_service_test.dart`
  - verificacion sin dependencia legacy: `rg -n "universal_html" frontend` -> sin coincidencias
- escenario 11:
  - politica strict: `scripts/check_frontend_assets.py`
  - tests de politica: `tests/test_check_frontend_assets.py`
  - ejecucion strict real: `python scripts/check_frontend_assets.py --mode strict --root .` -> `assets=13, references=13, total=15.3 KB, critical=9.6 KB`
  - ejecucion tests: `python -m pytest -q tests/test_check_frontend_assets.py` -> `3 passed`
- escenario 12:
  - no-regresion dashboards/routing: `frontend/test/widgets/dashboard_smoke_test.dart`, `frontend/test/router/app_router_test.dart`
  - verificacion integral frontend: `flutter test` -> `59 passed`

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

Estado:
- ACTIVO (control operativo continuo hasta cutover final).

Riesgo 1:
- `overlap` de labels/charts en movil (`390x844`, `844x390`).
- Trigger: overflow visual, labels truncados sin contexto, o `layout exception`.
- Mitigacion:
  - truncado controlado + tooltip,
  - scroll horizontal donde aplique,
  - smoke tests responsive obligatorios por dashboard.
- Verificacion:
  - `frontend/test/widgets/main_screen_responsive_test.dart`
  - `frontend/test/widgets/dashboard_smoke_test.dart`

Riesgo 2:
- cambio de schema de `run_manifest.json` sin coordinacion frontend/backend.
- Trigger: error de parseo en repositorios/providers o falla de contrato en CI.
- Mitigacion:
  - schema versionado (`manifest_version`),
  - contract tests obligatorios (`valido/invalido`),
  - publicacion controlada del manifest publico desde backend.
- Verificacion:
  - `frontend/test/contracts/run_manifest_contract_test.dart`
  - `tests/test_run_manifest_public_contract.py`
  - `tests/test_generate_run_manifest.py`

Riesgo 3:
- fallback CSV permanente (nunca se completa el cutover real).
- Trigger: `ENABLE_CSV_FALLBACK=true` se mantiene en release final sin excepcion aprobada.
- Mitigacion:
  - owner unico por fase,
  - criterio de salida formal (seccion 12),
  - desactivacion explicita de fallback en release de cutover.
- Verificacion:
  - checklist Go/No-Go de seccion 12,
  - evidencia de 4 corridas semanales sin `critical`.

## 12) Criterio de salida y cutover final

Para declarar frontend V2 cutover-ready:
1. FE-01..FE-04 completados con DoD en verde.
2. 4 corridas semanales consecutivas sin `critical`.
3. `run_manifest` publico estable en assets.
4. SLO frontend en rango (errores de carga controlados).
5. Luego desactivar fallback por defecto (`ENABLE_CSV_FALLBACK=false`) en release de cutover.

Estado actual de criterio de salida:
1. FE-01..FE-04 completados:
   - estado: CUMPLIDO (implementacion + evidencia tecnica en este roadmap).
2. 4 corridas semanales consecutivas sin `critical`:
   - estado: PENDIENTE OPERATIVO (requiere ventana real de 4 semanas en `main`).
3. `run_manifest` publico estable en assets:
   - estado: CUMPLIDO TECNICO / PENDIENTE CONFIRMACION OPERATIVA semanal.
4. SLO frontend en rango:
   - estado: PENDIENTE OPERATIVO (medicion en ejecucion real continua).
5. Desactivar fallback por defecto:
   - estado: PENDIENTE (accion final de release tras cumplir 1-4).

Checklist Go/No-Go (ejecucion):
1. Verificar `flutter analyze` y `flutter test` en verde en `main`.
2. Confirmar assets policy strict (`scripts/check_frontend_assets.py --mode strict --root .`) en verde.
3. Confirmar 4 runs semanales ETL consecutivos sin `critical`.
4. Confirmar que `frontend/assets/data/run_manifest.json` se publica y valida en cada run.
5. Cambiar `ENABLE_CSV_FALLBACK=false` en release de cutover.
6. Ejecutar smoke web final (`flutter build web --debug`) y validacion de navegacion hash.

Rollback de cutover (si hay incidente):
1. Restaurar `ENABLE_CSV_FALLBACK=true`.
2. Mantener `USE_HISTORY_BRIDGE_JSON=true` y `USE_PUBLIC_RUN_MANIFEST=true`.
3. Re-ejecutar CI + smoke frontend antes de nuevo intento de cutover.

---

Estado del documento:
- aprobado para ejecucion por fases.
- FE-01..FE-04: DONE.
- escenarios obligatorios 1..12: DONE (tecnico).
- pendiente para cierre de release V2: validacion operativa semanal + cutover final.
