# AGENTS.md

## Project Agent Rules

- Use Ponytail mode by default: choose the simplest working solution and avoid over-engineering.
- Before adding code, check whether the change needs to exist, whether the repo already has a helper/pattern, and whether stdlib/native features are enough.
- Prefer the smallest safe diff: reuse existing code, avoid new dependencies, and avoid abstractions made only for future possibilities.
- Do not simplify away safety: keep validation, error handling that prevents data loss, security checks, accessibility basics, and requested tests.
- For non-trivial logic, leave the smallest runnable check that would fail if the logic breaks.
- Never commit secrets, local environment files, logs, generated agent artifacts, or unrelated data outputs.
- Use conventional commits only. Do not add `Co-Authored-By` or AI attribution.
