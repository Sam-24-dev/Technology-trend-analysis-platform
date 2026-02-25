# Frontend Coding Style (Flutter/Dart)

## Objetivo
Definir reglas minimas de codigo para FE V2 con foco en mantenibilidad, testabilidad y consistencia.

## Reglas base
- Usar `flutter_lints` y mantener `flutter analyze` sin errores ni warnings.
- Mantener archivos en ASCII cuando sea posible.
- Evitar logica de negocio en widgets; usar servicios/repositorios/providers.
- Evitar comentarios redundantes. Comentar solo decisiones no obvias.

## Arquitectura por capas
- Flujo obligatorio: `DataService -> Repository -> Provider -> UI`.
- En FE-01 se permite compatibilidad temporal con `CsvService`.
- No mezclar acceso directo a `rootBundle/http` desde pantallas.

## Naming
- Clases: `PascalCase`.
- Metodos/variables: `camelCase`.
- Archivos Dart: `snake_case.dart`.
- Constantes de feature flag/env: `SCREAMING_SNAKE_CASE`.

## Manejo de errores
- Propagar errores con contexto tecnico claro.
- Para errores esperados (asset faltante, 404), usar fallback controlado.
- No bloquear render completo por fallo parcial de datos.

## Tests
- Cada cambio funcional debe incluir test.
- Minimo FE-01:
  - smoke test de app
  - test de contrato `run_manifest.json`
- Mantener pruebas rapidas y deterministas.

## PR hygiene
- Un PR = una fase/objetivo.
- Incluir plan de rollback claro.
- No mezclar refactor grande + feature + cleanup en el mismo PR.
