# Frontend UI/UX Rules (V2)

## Objetivo
Asegurar experiencia consistente, responsive y accesible en FE V2.

## Responsive obligatorio
- Breakpoints de validacion:
  - `390x844` (portrait)
  - `844x390` (landscape movil)
  - `768x1024`
  - `1024x768`
  - `1280+`
- Criterio: cero overflow/layout exceptions.

## Accesibilidad (WCAG AA practico)
- Contraste suficiente en texto y componentes interactivos.
- Focus visible en navegacion por teclado.
- Semantics labels en elementos relevantes.
- No depender solo de color para estados (`pass/warning/fail/unknown`).

## Estados UX de datos
- Estados estandar por pantalla/componente:
  - `loading`
  - `data`
  - `degraded`
  - `error`
- Si metadata falta, mostrar estado `unknown/metadata unavailable` sin bloquear navegacion.

## Consistencia de fechas y comparaciones
- Formato visible: `dd/MM/yyyy` en labels tipo "Comparado (UTC)".
- Badges de tendencia sin fecha cuando el header ya muestra el rango.

## Fallback UX
- Si falla `run_manifest.json`: badge/estado gris y continuar con datos disponibles.
- Si falla bridge JSON historico: fallback CSV con etiqueta de modo fallback.
- Errores parciales no deben tumbar todo el `Scaffold`.

## Consistencia visual
- Mantener misma jerarquia tipografica y espaciado entre dashboards.
- Reusar componentes para estados repetidos (loading/error/empty/degraded).
- Evitar introducir estilos aislados sin token/criterio compartido.

## Navegacion y explicabilidad
- Tarjetas del ranking deben ser clickeables y la UI debe indicarlo con micro-copy.
- Tooltips de ayuda para explicar el puntaje compuesto y sus pesos.
- Numeracion de ranking debe renumerar dentro de cada filtro (sin saltos).

## Logos y fallback visual
- Usar logo oficial cuando exista en assets.
- Si no hay logo oficial, usar icono tematico generico (AI/ML, Security, etc.).
