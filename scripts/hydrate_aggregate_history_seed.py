"""Reconstruye latest/history desde un aggregate previo cuando faltan archivos crudos."""

from __future__ import annotations

import argparse
import json
import shutil
from pathlib import Path


REQUIRED_HISTORY_SEED_DATASETS = (
    "trend_score",
    "github_commits",
    "github_correlacion",
    "so_volumen",
    "so_aceptacion",
    "so_tendencias",
    "reddit_temas",
    "interseccion",
)


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _copy_if_missing(source: Path, target: Path) -> bool:
    if target.exists():
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)
    return True


def _artifact_destination(project_root: Path, path_label: str) -> Path:
    candidate = Path(path_label)
    if candidate.is_absolute():
        raise ValueError(f"unsafe artifact destination: {path_label}")

    target = (project_root / candidate).resolve()
    try:
        relative_target = target.relative_to(project_root)
    except ValueError as exc:
        raise ValueError(f"unsafe artifact destination: {path_label}") from exc

    if relative_target.parts[:2] not in (("datos", "latest"), ("datos", "history")):
        raise ValueError(f"unsafe artifact destination: {path_label}")
    return target


def hydrate_aggregate_history_seed(project_root: Path | str) -> dict[str, int]:
    project_root = Path(project_root).resolve()
    history_index_path = project_root / "frontend" / "assets" / "data" / "history_index.json"
    if not history_index_path.exists():
        return {
            "dataset_count": 0,
            "seeded_latest_files": 0,
            "seeded_history_files": 0,
        }

    history_index = _load_json(history_index_path)
    seeded_latest_files = 0
    seeded_history_files = 0

    for dataset_entry in history_index.get("datasets", []):
        snapshots = dataset_entry.get("snapshots") or []
        latest_path_label = dataset_entry.get("latest_path")
        snapshot_path_label = snapshots[-1].get("path") if snapshots else None
        latest_target = (
            _artifact_destination(project_root, latest_path_label)
            if latest_path_label
            else None
        )
        snapshot_target = (
            _artifact_destination(project_root, snapshot_path_label)
            if snapshot_path_label
            else None
        )

        source_candidates = []
        if latest_path_label:
            source_candidates.append(project_root / "datos" / Path(latest_path_label).name)
        if snapshot_path_label:
            source_candidates.append(project_root / "datos" / Path(snapshot_path_label).name)

        source_path = next((path for path in source_candidates if path.exists()), None)
        if source_path is None:
            continue

        if latest_path_label:
            seeded_latest_files += int(
                _copy_if_missing(source_path, latest_target)
            )
        if snapshot_path_label:
            seeded_history_files += int(
                _copy_if_missing(source_path, snapshot_target)
            )

    return {
        "dataset_count": len(history_index.get("datasets", [])),
        "seeded_latest_files": seeded_latest_files,
        "seeded_history_files": seeded_history_files,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", default=".")
    args = parser.parse_args()

    summary = hydrate_aggregate_history_seed(args.project_root)
    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
