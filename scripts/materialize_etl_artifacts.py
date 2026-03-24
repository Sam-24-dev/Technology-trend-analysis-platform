"""Materializa artifacts ETL descargados dentro del workspace del proyecto."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


def _copy_file(source: Path, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, destination)


def _copy_matching_files(source_root: Path, destination_root: Path, suffixes: tuple[str, ...]) -> int:
    if not source_root.exists():
        return 0

    copied = 0
    for file_path in sorted(source_root.rglob("*")):
        if not file_path.is_file():
            continue
        if file_path.suffix.lower() not in suffixes:
            continue
        _copy_file(file_path, destination_root / file_path.relative_to(source_root))
        copied += 1
    return copied


def _copy_top_level_csvs(source_root: Path, destination_root: Path) -> int:
    if not source_root.exists():
        return 0

    copied = 0
    for csv_path in sorted(source_root.glob("*.csv")):
        _copy_file(csv_path, destination_root / csv_path.name)
        copied += 1
    return copied


def _resolve_data_root(artifact_root: Path) -> Path:
    nested = artifact_root / "datos"
    return nested if nested.exists() else artifact_root


def materialize_artifacts(project_root: Path | str, artifact_roots: list[Path | str]) -> dict[str, int]:
    project_root = Path(project_root)
    data_root = project_root / "datos"
    frontend_assets_root = project_root / "frontend" / "assets" / "data"

    summary = {
        "artifact_roots": 0,
        "legacy_files": 0,
        "latest_files": 0,
        "history_files": 0,
        "metadata_files": 0,
        "frontend_asset_files": 0,
    }

    for raw_root in artifact_roots:
        artifact_root = Path(raw_root)
        if not artifact_root.exists():
            continue

        summary["artifact_roots"] += 1
        source_data_root = _resolve_data_root(artifact_root)
        summary["legacy_files"] += _copy_top_level_csvs(source_data_root, data_root)
        summary["latest_files"] += _copy_matching_files(
            source_data_root / "latest",
            data_root / "latest",
            suffixes=(".csv",),
        )
        summary["history_files"] += _copy_matching_files(
            source_data_root / "history",
            data_root / "history",
            suffixes=(".csv",),
        )
        summary["metadata_files"] += _copy_matching_files(
            source_data_root / "metadata",
            data_root / "metadata",
            suffixes=(".json",),
        )
        summary["frontend_asset_files"] += _copy_matching_files(
            artifact_root / "frontend" / "assets" / "data",
            frontend_assets_root,
            suffixes=(".csv", ".json"),
        )

    return summary


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--project-root",
        default=".",
        help="Raiz del proyecto donde se restauran datos/ y frontend/assets/data.",
    )
    parser.add_argument(
        "artifact_roots",
        nargs="+",
        help="Directorios raiz descargados por actions/download-artifact.",
    )
    args = parser.parse_args()

    summary = materialize_artifacts(
        project_root=args.project_root,
        artifact_roots=args.artifact_roots,
    )
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
