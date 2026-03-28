"""Restore the freshest valid Reddit baseline into the aggregate workspace."""

from __future__ import annotations

import argparse
import json
import shutil
from dataclasses import dataclass
from datetime import date
from pathlib import Path


CSV_SPECS = {
    "reddit_sentimiento_frameworks.csv": (
        "reddit_sentimiento",
        "reddit_sentimiento_frameworks.csv",
    ),
    "reddit_temas_emergentes.csv": (
        "reddit_temas",
        "reddit_temas_emergentes.csv",
    ),
    "interseccion_github_reddit.csv": (
        "interseccion",
        "interseccion_github_reddit.csv",
    ),
}

BRIDGE_FILES = (
    "reddit_temas_history.json",
    "reddit_interseccion_history.json",
)


@dataclass(frozen=True)
class Candidate:
    root: Path
    latest_snapshot_date: date


def _load_json(path: Path) -> dict:
    return json.loads(path.read_text(encoding="utf-8"))


def _parse_snapshot_date(value: object) -> date | None:
    if not isinstance(value, str) or not value:
        return None
    try:
        return date.fromisoformat(value)
    except ValueError:
        return None


def _discover_candidate(root: Path) -> Candidate | None:
    topics_bridge = root / "frontend" / "assets" / "data" / "reddit_temas_history.json"
    intersection_bridge = (
        root / "frontend" / "assets" / "data" / "reddit_interseccion_history.json"
    )

    if not topics_bridge.exists() or not intersection_bridge.exists():
        return None

    for csv_name in CSV_SPECS:
        if not (root / "datos" / csv_name).exists():
            return None

    try:
        topics_payload = _load_json(topics_bridge)
        intersection_payload = _load_json(intersection_bridge)
    except (OSError, ValueError):
        return None

    topics_date = _parse_snapshot_date(topics_payload.get("latest_snapshot_date"))
    intersection_date = _parse_snapshot_date(
        intersection_payload.get("latest_snapshot_date")
    )
    if topics_date is None or intersection_date is None:
        return None
    if topics_date != intersection_date:
        return None

    return Candidate(root=root, latest_snapshot_date=topics_date)


def _select_best_candidate(candidate_roots: list[Path]) -> Candidate:
    candidates: list[Candidate] = []
    for root in candidate_roots:
        candidate = _discover_candidate(root)
        if candidate is not None:
            candidates.append(candidate)

    if not candidates:
        raise ValueError("No valid Reddit baseline candidate was found.")

    return max(candidates, key=lambda candidate: candidate.latest_snapshot_date)


def _copy_file(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, target)


def _replace_dir(source: Path, target: Path) -> None:
    if target.exists():
        shutil.rmtree(target)
    if source.exists():
        shutil.copytree(source, target)


def restore_reddit_source_baseline(
    project_root: Path,
    candidate_roots: list[Path],
) -> dict[str, object]:
    candidate = _select_best_candidate(candidate_roots)

    latest_snapshot = candidate.latest_snapshot_date
    year = latest_snapshot.strftime("%Y")
    month = latest_snapshot.strftime("%m")
    day = latest_snapshot.strftime("%d")

    for csv_name, (history_dataset, history_filename) in CSV_SPECS.items():
        source_csv = candidate.root / "datos" / csv_name
        target_csv = project_root / "datos" / csv_name
        target_latest = project_root / "datos" / "latest" / csv_name

        _copy_file(source_csv, target_csv)
        _copy_file(source_csv, target_latest)

        target_history_root = project_root / "datos" / "history" / history_dataset
        source_history_root = candidate.root / "datos" / "history" / history_dataset
        if source_history_root.exists():
            _replace_dir(source_history_root, target_history_root)
        else:
            target_history_file = (
                target_history_root
                / f"year={year}"
                / f"month={month}"
                / f"day={day}"
                / history_filename
            )
            _copy_file(source_csv, target_history_file)

    return {
        "mode": "source",
        "selected_root": str(candidate.root),
        "latest_snapshot_date": latest_snapshot.isoformat(),
    }


def restore_reddit_bridges(
    project_root: Path,
    candidate_roots: list[Path],
) -> dict[str, object]:
    candidate = _select_best_candidate(candidate_roots)

    for bridge_file in BRIDGE_FILES:
        source_bridge = candidate.root / "frontend" / "assets" / "data" / bridge_file
        target_bridge = project_root / "frontend" / "assets" / "data" / bridge_file
        _copy_file(source_bridge, target_bridge)

    return {
        "mode": "bridges",
        "selected_root": str(candidate.root),
        "latest_snapshot_date": candidate.latest_snapshot_date.isoformat(),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", required=True)
    parser.add_argument(
        "--candidate-root",
        action="append",
        required=True,
        help="Candidate baseline root (can be passed multiple times).",
    )
    parser.add_argument(
        "--mode",
        choices=("source", "bridges"),
        required=True,
    )
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()
    candidate_roots = [Path(value).resolve() for value in args.candidate_root]

    if args.mode == "source":
        summary = restore_reddit_source_baseline(project_root, candidate_roots)
    else:
        summary = restore_reddit_bridges(project_root, candidate_roots)

    print(json.dumps(summary, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
