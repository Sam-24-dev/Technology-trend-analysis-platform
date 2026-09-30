"""Opt in to a reviewed same-day Reddit package in the ephemeral aggregate job."""

import argparse
import sys
from pathlib import Path
from shutil import copyfile


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / "backend"))

from export_history_json import export_bridge_assets  # noqa: E402
from generate_run_manifest import generate_manifest_from_final_bridges  # noqa: E402
from reddit_source_package import validate_reddit_source_package  # noqa: E402
from scripts.check_source_freshness import DEFAULT_MAX_SOURCE_AGE_HOURS, check_source_freshness  # noqa: E402


SOURCES = (
    ("reddit_sentimiento", "reddit_sentimiento_frameworks.csv"),
    ("reddit_temas", "reddit_temas_emergentes.csv"),
)


def _partition(root, dataset, name, source_date):
    year, month, day = source_date.split("-")
    return root / "history" / dataset / f"year={year}" / f"month={month}" / f"day={day}" / name


def select_package(project_root, candidate_root, aggregate_date, *, remote_accepted, minimum_mentions, now=None):
    """Select only verified bytes; otherwise preserve the existing fallback path."""
    if remote_accepted or minimum_mentions is None or minimum_mentions <= 0:
        return False
    project_root, candidate_root = Path(project_root), Path(candidate_root)
    try:
        package = validate_reddit_source_package(candidate_root, aggregate_date, now=now)
        if package["mentions_total"] < minimum_mentions:
            return False
        receipt = Path("datos/source_packages/reddit/receipt.json")
        if (candidate_root / receipt).read_bytes() != (project_root / receipt).read_bytes():
            return False
        for dataset, name in (*SOURCES, ("interseccion", "interseccion_github_reddit.csv")):
            history = project_root / "datos" / "history" / dataset
            expected = _partition(project_root / "datos", dataset, name, aggregate_date)
            for path in history.rglob(name):
                if path != expected and f"day={aggregate_date[-2:]}" in path.parts \
                        and f"month={aggregate_date[5:7]}" in path.parts \
                        and f"year={aggregate_date[:4]}" in path.parts:
                    return False
    except (OSError, ValueError):
        return False

    for dataset, name in SOURCES:
        source = candidate_root / "datos" / name
        for data_root in (project_root / "datos", project_root / "artifacts" / "reddit-package" / "datos"):
            for target in (data_root / name, data_root / "latest" / name,
                           _partition(data_root, dataset, name, aggregate_date)):
                target.parent.mkdir(parents=True, exist_ok=True)
                copyfile(source, target)
    return True


def finalize_package(project_root, aggregate_date):
    """Replace temporary exporter metadata with validated final source time."""
    project_root = Path(project_root)
    package = validate_reddit_source_package(project_root, aggregate_date)
    data = project_root / "datos"
    for dataset, name in SOURCES:
        source = (data / name).read_bytes()
        if (data / "latest" / name).read_bytes() != source or \
                _partition(data, dataset, name, aggregate_date).read_bytes() != source or \
                (project_root / "frontend/assets/data" / name).read_bytes() != source:
            raise ValueError(f"Reddit package root/latest/history/frontend mismatch: {name}")
    for relative, compact in (("frontend/assets/data", True), ("datos/metadata/remote_assets", False)):
        export_bridge_assets(project_root, output_dir=project_root / relative, compact=compact,
                             reddit_source_package_date_utc=aggregate_date)
    generate_manifest_from_final_bridges(
        project_root,
        output_dirs=[project_root / "frontend/assets/data", project_root / "datos/metadata/remote_assets"],
        require_metadata=True,
        reddit_source_package_date_utc=aggregate_date,
    )
    return package


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("action", choices=("select", "finalize", "freshness"))
    parser.add_argument("--project-root", type=Path, default=Path("."))
    parser.add_argument("--candidate-root", type=Path, default=Path("repo_baseline"))
    parser.add_argument("--date", required=True)
    parser.add_argument("--remote-accepted", choices=("true", "false"), default="false")
    parser.add_argument("--minimum-mentions", type=int)
    args = parser.parse_args()
    if args.action == "select":
        selected = select_package(args.project_root, args.candidate_root, args.date,
                                  remote_accepted=args.remote_accepted == "true",
                                  minimum_mentions=args.minimum_mentions)
        print(f"selected={str(selected).lower()}")
    elif args.action == "finalize":
        finalize_package(args.project_root, args.date)
    else:
        check_source_freshness(args.project_root, max_source_age_hours=DEFAULT_MAX_SOURCE_AGE_HOURS,
                               reddit_source_package_date_utc=args.date)


if __name__ == "__main__":
    main()
