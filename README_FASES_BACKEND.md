# Plan de Fases Backend

Este documento define las fases de trabajo para cerrar el backend sin bugs, con datos limpios y código mantenible.

## Objetivo general

- Dejar el backend estable, predecible y fácil de mantener.
- Reducir errores en extracción, transformación y score.
- Mejorar calidad de datos y cobertura de pruebas.
- Cerrar con una limpieza final de código duplicado y estilo.

## Orden recomendado

1. Fase 3: Bugs críticos backend
2. Fase 6: Calidad de datos backend
3. Fase 7: Testing backend faltante
4. Fase 4: CI y deploy robusto
5. Fase 8: Ajustes de arquitectura backend
6. Fase 10: Configuración y resiliencia operativa
7. Fase 11: Contrato de datos y validación estricta
8. Fase 12: Observabilidad y trazabilidad
9. Fase 13: Dependencias y seguridad
10. Fase 9: Limpieza final y no duplicación

---

## Fase 3: Bugs críticos backend (Alta)

### Objetivo
Corregir fallos funcionales y riesgos de comportamiento.

### Alcance
- `backend/stackoverflow_etl.py`
	- Evitar mutación de `params` en `get_total_count`.
- `backend/github_etl.py`
	- Blindar control de paginación/rate limit para evitar loops largos o no controlados.
- `backend/reddit_etl.py`
	- Refinar matching de keywords (`java` vs `javascript`).
	- Quitar términos demasiado genéricos (`api`) y limpiar duplicados.

### Criterio de cierre
- Sin efectos secundarios por mutación de parámetros.
- Flujo GitHub con condiciones de corte claras.
- Menos falsos positivos en detección por keywords.

---

## Fase 6: Calidad de datos backend (Media)

### Objetivo
Mejorar consistencia y utilidad de los CSV de salida.

### Alcance
- Filtrar `Sin especificar` en análisis de lenguajes.
- Filtrar etiquetas de ruido (por ejemplo `LLMs/AI`) cuando aplique.
- Corregir keywords duplicadas.
- Revisar labels de tendencias mensuales para evitar ambigüedad temporal.

### Criterio de cierre
- CSVs más limpios y estables entre corridas.
- Menos ruido visual y analítico en dashboard y score.

---

## Fase 7: Testing backend faltante (Media)

### Objetivo
Cubrir módulos base sin pruebas dedicadas.

### Alcance
- Crear tests para:
	- `backend/validador.py`
	- `backend/sync_assets.py`
	- `backend/base_etl.py`

### Criterio de cierre
- Suite de tests en verde.
- Casos borde cubiertos (vacíos, columnas faltantes, errores esperados).

---

## Fase 4: CI y deploy robusto (Media)

### Objetivo
Hacer pipeline más confiable y con fallos visibles.

### Alcance
- Revisar compatibilidad real del `Makefile` en Linux/Windows.
- Separar trigger ETL de deploy cuando convenga por flujo.
- Agregar caché para dependencias Python y Flutter.
- Reemplazar `continue-on-error: true` ciego por manejo explícito.

### Criterio de cierre
- Pipelines reproducibles y con señales de error claras.
- Menores tiempos de ejecución por caché.

---

## Fase 8: Ajustes de arquitectura backend (Baja-Media)

### Objetivo
Mejorar mantenibilidad sin romper comportamiento.

### Alcance
- Evaluar integración de `trend_score.py` con patrón base sin sobreingeniería.
- Definir contrato de schema CSV entre backend y frontend.

### Criterio de cierre
- Contratos de datos explícitos.
- Menor acoplamiento implícito entre módulos.

---

## Fase 10: Configuración y resiliencia operativa (Media)

### Objetivo
Reducir fallos por configuración incompleta y hacer el backend más estable ante errores externos.

### Alcance
- Validar variables de entorno críticas al inicio de cada ETL.
- Centralizar timeouts, retries y backoff en constantes compartidas.
- Evitar efectos secundarios al importar módulos (por ejemplo, descargas NLTK en import).
- Definir comportamiento explícito cuando una fuente falla (degradación controlada).

### Criterio de cierre
- Configuración inválida detectada temprano con mensajes claros.
- Parámetros de red consistentes entre ETLs.
- Menos side effects fuera del flujo principal.

---

## Fase 11: Contrato de datos y validación estricta (Media)

### Objetivo
Formalizar reglas del schema para evitar drift silencioso entre backend y frontend.

### Alcance
- Completar `COLUMNAS_ESPERADAS` y `COLUMNAS_CRITICAS` para todos los CSV (incluido `trend_score` y columnas faltantes actuales).
- Agregar validación opcional estricta (fallar si faltan columnas clave).
- Documentar contrato mínimo de tipos y columnas por archivo.

### Criterio de cierre
- Todos los CSV de salida tienen schema validado y consistente.
- Errores de estructura se detectan antes de llegar al frontend.

---

## Fase 12: Observabilidad y trazabilidad (Media)

### Objetivo
Mejorar diagnóstico operativo sin aumentar ruido.

### Alcance
- Sustituir `print` por logging estructurado en scripts de backend.
- Estandarizar logs por paso: inicio, fin, duración y resultado.
- Generar un resumen final por ejecución (filas procesadas, archivos escritos, fallos).

### Criterio de cierre
- Logs homogéneos en todos los módulos.
- Trazabilidad clara de cada corrida ETL.

---

## Fase 13: Dependencias y seguridad (Media)

### Objetivo
Reducir riesgo técnico por dependencias y facilitar reproducibilidad.

### Alcance
- Revisar y ajustar rangos de versiones en `backend/requirements.txt`.
- Ejecutar chequeo de vulnerabilidades de dependencias.
- Definir política mínima de actualización de librerías.

### Criterio de cierre
- Dependencias controladas y auditadas.
- Menos riesgo de rompimientos por cambios externos.

---

## Fase 9: Limpieza final y no duplicación (Final)

### Objetivo
Cerrar backend con estándar de código limpio y mantenible.

### Reglas de esta fase
- Reducir duplicación funcional relevante (extraer helpers donde tenga sentido).
- Aplicar buenas prácticas de estructura y manejo de errores.
- Mantener comentarios en español, pocos y útiles.
- Evitar ruido en logs y prints innecesarios.
- Mantener estilo uniforme entre módulos.

### Criterio de cierre
- Sin bloques duplicados importantes.
- Código legible y consistente.
- Comentarios mínimos, claros y en español.

---

## Checklist de ejecución

- [ ] Fase 3 bugs críticos backend
- [ ] Fase 6 calidad de datos backend
- [ ] Fase 7 pruebas backend faltantes
- [ ] Fase 4 CI y deploy robusto
- [ ] Fase 8 ajustes arquitectura backend
- [ ] Fase 10 configuración y resiliencia operativa
- [ ] Fase 11 contrato de datos y validación estricta
- [ ] Fase 12 observabilidad y trazabilidad
- [ ] Fase 13 dependencias y seguridad
- [ ] Fase 9 limpieza final y no duplicación

