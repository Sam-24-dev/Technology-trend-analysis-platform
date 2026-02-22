# Estandar de estilo del repositorio

Este documento define las reglas de estilo activas para mantener consistencia en backend y documentacion.

## Reglas globales

- `README.md` en ingles.
- Archivos dentro de `docs/` en espanol (terminos tecnicos pueden quedar en ingles).
- Sin emojis en codigo backend.
- Evitar comentarios excesivos; comentar solo cuando agrega contexto tecnico real.

## Reglas backend

- Modulos y componentes tecnicos en ingles.
- ETLs y logica de negocio existente pueden mantener nombres de funciones/metodos en espanol.
- Comentarios y docstrings: siempre en ingles en todo `backend/`.
- Mantener nomenclatura profesional y estable (sin nombres temporales tipo `v2`, `fase2`, etc.).

## Criterio para nuevos PR

- No mezclar idioma dentro de comentarios/docstrings de un mismo modulo.
- No cambiar nombres publicos sin necesidad funcional.
- Priorizar cambios incrementales y compatibles con el comportamiento actual.
- Ejecutar tests antes de merge.
