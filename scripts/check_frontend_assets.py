"""Frontend assets policy check (allowlist, references and size budgets)."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Iterable


ASSET_ALLOWLIST = {
    "trend_score.csv",
    "github_lenguajes.csv",
    "github_commits_frameworks.csv",
    "github_correlacion.csv",
    "so_volumen_preguntas.csv",
    "so_tasa_aceptacion.csv",
    "so_tendencias_mensuales.csv",
    "reddit_sentimiento_frameworks.csv",
    "reddit_temas_emergentes.csv",
    "interseccion_github_reddit.csv",
    "reddit_sentimiento_public.json",
    "reddit_temas_history.json",
    "reddit_interseccion_history.json",
    "github_lenguajes_public.json",
    "github_frameworks_history.json",
    "github_correlacion_history.json",
    "home_highlights.json",
    "so_volumen_history.json",
    "so_aceptacion_history.json",
    "so_tendencias_history.json",
    "history_index.json",
    "trend_score_history.json",
    "technology_profiles.json",
    "run_manifest.json",
}

ASSET_REQUIRED = set(ASSET_ALLOWLIST)
CRITICAL_ROUTE_ASSETS = {
    "trend_score.csv",
    "history_index.json",
    "trend_score_history.json",
    "run_manifest.json",
}

BYTES_PER_KB = 1024


def _build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Checks frontend data assets policy")
    parser.add_argument("--root", default=".", help="Project root path")
    parser.add_argument(
        "--mode",
        choices=("warning", "strict"),
        default="warning",
        help="warning: never fails, strict: fails on policy violations",
    )
    parser.add_argument("--max-file-kb", type=int, default=150, help="Max size per file in KB")
    parser.add_argument("--max-total-kb", type=int, default=600, help="Max total assets/data size in KB")
    parser.add_argument("--max-critical-kb", type=int, default=250, help="Max critical route assets size in KB")
    return parser


def _log_issue(mode: str, message: str) -> None:
    prefix = "::error::" if mode == "strict" else "::warning::"
    print(f"{prefix}{message}")


def _format_kb(num_bytes: int) -> str:
    return f"{num_bytes / BYTES_PER_KB:.1f} KB"


def _collect_assets(asset_dir: Path) -> dict[str, Path]:
    if not asset_dir.exists():
        return {}
    return {path.name: path for path in asset_dir.glob("*") if path.is_file()}


def _collect_data_asset_references(frontend_lib_dir: Path) -> set[str]:
    if not frontend_lib_dir.exists():
        return set()

    references: set[str] = set()
    pattern = re.compile(r"assets/data/([A-Za-z0-9_.-]+)")
    for dart_file in frontend_lib_dir.rglob("*.dart"):
        content = dart_file.read_text(encoding="utf-8")
        references.update(pattern.findall(content))
    return references


def _sum_sizes(paths: Iterable[Path]) -> int:
    return sum(path.stat().st_size for path in paths if path.exists())


def run_policy_check(
    *,
    root: Path,
    mode: str,
    max_file_kb: int,
    max_total_kb: int,
    max_critical_kb: int,
) -> int:
    asset_dir = root / "frontend" / "assets" / "data"
    frontend_lib_dir = root / "frontend" / "lib"

    assets = _collect_assets(asset_dir)
    references = _collect_data_asset_references(frontend_lib_dir)

    issues: list[str] = []

    missing_required = sorted(ASSET_REQUIRED - set(assets.keys()))
    for file_name in missing_required:
        issues.append(f"required asset missing: frontend/assets/data/{file_name}")

    extra_assets = sorted(set(assets.keys()) - ASSET_ALLOWLIST)
    for file_name in extra_assets:
        issues.append(f"asset not allowlisted: frontend/assets/data/{file_name}")

    referenced_missing = sorted(references - set(assets.keys()))
    for file_name in referenced_missing:
        issues.append(f"code references missing asset: assets/data/{file_name}")

    allowlisted_not_referenced = sorted(
        file_name
        for file_name in ASSET_ALLOWLIST
        if file_name in assets and file_name not in references
    )
    for file_name in allowlisted_not_referenced:
        issues.append(f"allowlisted asset not referenced in frontend/lib/**: {file_name}")

    max_file_bytes = max_file_kb * BYTES_PER_KB
    for file_name, path in sorted(assets.items()):
        size = path.stat().st_size
        if size > max_file_bytes:
            issues.append(
                f"asset exceeds max-file budget ({max_file_kb} KB): "
                f"frontend/assets/data/{file_name}={_format_kb(size)}"
            )

    total_bytes = _sum_sizes(assets.values())
    critical_bytes = _sum_sizes([assets[name] for name in CRITICAL_ROUTE_ASSETS if name in assets])

    if total_bytes > max_total_kb * BYTES_PER_KB:
        issues.append(
            f"assets/data exceeds max-total budget ({max_total_kb} KB): {_format_kb(total_bytes)}"
        )
    if critical_bytes > max_critical_kb * BYTES_PER_KB:
        issues.append(
            f"critical route assets exceed budget ({max_critical_kb} KB): {_format_kb(critical_bytes)}"
        )

    print(
        f"[assets-check] mode={mode} assets={len(assets)} references={len(references)} "
        f"total={_format_kb(total_bytes)} critical={_format_kb(critical_bytes)}"
    )

    for issue in issues:
        _log_issue(mode, issue)

    if issues and mode == "strict":
        return 1
    return 0


def main() -> int:
    args = _build_parser().parse_args()
    return run_policy_check(
        root=Path(args.root).resolve(),
        mode=args.mode,
        max_file_kb=args.max_file_kb,
        max_total_kb=args.max_total_kb,
        max_critical_kb=args.max_critical_kb,
    )


if __name__ == "__main__":
    raise SystemExit(main())
