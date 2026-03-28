import json
from pathlib import Path

from scripts.restore_reddit_baseline import (
    restore_reddit_bridges,
    restore_reddit_source_baseline,
)


def _write(path: Path, content: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")


def _create_candidate(root: Path, latest_snapshot_date: str) -> None:
    for csv_name in (
        "reddit_sentimiento_frameworks.csv",
        "reddit_temas_emergentes.csv",
        "interseccion_github_reddit.csv",
    ):
        _write(root / "datos" / csv_name, "col\n1\n")

    _write(
        root / "frontend" / "assets" / "data" / "reddit_temas_history.json",
        json.dumps(
            {
                "latest_snapshot_date": latest_snapshot_date,
                "previous_snapshot_date": "2026-03-22",
            }
        ),
    )
    _write(
        root / "frontend" / "assets" / "data" / "reddit_interseccion_history.json",
        json.dumps(
            {
                "latest_snapshot_date": latest_snapshot_date,
                "previous_snapshot_date": "2026-03-22",
            }
        ),
    )


def test_restore_reddit_source_baseline_prefers_fresher_repo_candidate(tmp_path):
    project_root = tmp_path / "project"
    repo_baseline = tmp_path / "repo_baseline"
    prev_artifacts = tmp_path / "prev_artifacts"

    _create_candidate(repo_baseline, "2026-03-24")
    _create_candidate(prev_artifacts, "2026-03-16")

    summary = restore_reddit_source_baseline(
        project_root,
        [repo_baseline, prev_artifacts],
    )

    assert summary["latest_snapshot_date"] == "2026-03-24"
    assert "repo_baseline" in summary["selected_root"]
    assert (
        project_root / "datos" / "latest" / "reddit_temas_emergentes.csv"
    ).exists()
    assert (
        project_root
        / "datos"
        / "history"
        / "reddit_temas"
        / "year=2026"
        / "month=03"
        / "day=24"
        / "reddit_temas_emergentes.csv"
    ).exists()


def test_restore_reddit_source_baseline_preserves_existing_history_when_candidate_lacks_history(
    tmp_path,
):
    project_root = tmp_path / "project"
    repo_baseline = tmp_path / "repo_baseline"

    _create_candidate(repo_baseline, "2026-03-24")
    existing_history_file = (
        project_root
        / "datos"
        / "history"
        / "reddit_temas"
        / "year=2026"
        / "month=03"
        / "day=22"
        / "reddit_temas_emergentes.csv"
    )
    _write(existing_history_file, "col\nlegacy\n")

    summary = restore_reddit_source_baseline(project_root, [repo_baseline])

    assert summary["latest_snapshot_date"] == "2026-03-24"
    assert existing_history_file.exists()
    assert (
        project_root
        / "datos"
        / "history"
        / "reddit_temas"
        / "year=2026"
        / "month=03"
        / "day=24"
        / "reddit_temas_emergentes.csv"
    ).exists()


def test_restore_reddit_bridges_skips_corrupt_fresher_candidate(tmp_path):
    project_root = tmp_path / "project"
    corrupt_repo_baseline = tmp_path / "repo_baseline"
    prev_artifacts = tmp_path / "prev_artifacts"

    _create_candidate(corrupt_repo_baseline, "2026-03-24")
    _create_candidate(prev_artifacts, "2026-03-16")
    _write(
        corrupt_repo_baseline
        / "frontend"
        / "assets"
        / "data"
        / "reddit_temas_history.json",
        "{not-json",
    )

    summary = restore_reddit_bridges(
        project_root,
        [corrupt_repo_baseline, prev_artifacts],
    )

    restored = json.loads(
        (
            project_root
            / "frontend"
            / "assets"
            / "data"
            / "reddit_temas_history.json"
        ).read_text(encoding="utf-8")
    )
    assert summary["latest_snapshot_date"] == "2026-03-16"
    assert "prev_artifacts" in summary["selected_root"]
    assert restored["latest_snapshot_date"] == "2026-03-16"


def test_restore_reddit_bridges_copies_selected_candidate(tmp_path):
    project_root = tmp_path / "project"
    repo_baseline = tmp_path / "repo_baseline"
    prev_artifacts = tmp_path / "prev_artifacts"

    _create_candidate(repo_baseline, "2026-03-24")
    _create_candidate(prev_artifacts, "2026-03-16")

    summary = restore_reddit_bridges(
        project_root,
        [prev_artifacts, repo_baseline],
    )

    restored = json.loads(
        (
            project_root
            / "frontend"
            / "assets"
            / "data"
            / "reddit_temas_history.json"
        ).read_text(encoding="utf-8")
    )
    assert summary["latest_snapshot_date"] == "2026-03-24"
    assert restored["latest_snapshot_date"] == "2026-03-24"
