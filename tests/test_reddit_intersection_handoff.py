"""Accepted intersection inputs and outputs must have a single provenance."""

from datetime import datetime, timezone
from pathlib import Path
import shutil

import pandas as pd
import pytest

import base_etl
import reddit_etl
from scripts.materialize_etl_artifacts import materialize_artifacts
from scripts.restore_reddit_baseline import restore_reddit_source_baseline


def _write(root: Path, relative: str, content: str) -> Path:
    path = root / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(content, encoding="utf-8")
    return path


@pytest.fixture
def workspace(tmp_path, monkeypatch):
    root = tmp_path / "workspace"
    data = root / "datos"
    outputs = {
        "github_repos": data / "github_repos_2025.csv",
        "github_commits": data / "github_commits_frameworks.csv",
        "reddit_temas": data / "reddit_temas_emergentes.csv",
        "interseccion": data / "interseccion_github_reddit.csv",
    }
    monkeypatch.setattr(reddit_etl, "ARCHIVOS_SALIDA", outputs)
    monkeypatch.setattr(base_etl, "ARCHIVOS_SALIDA", outputs)
    monkeypatch.setattr(base_etl, "WRITE_LEGACY_CSV", True)
    monkeypatch.setattr(base_etl, "WRITE_LATEST_CSV", True)
    monkeypatch.setattr(base_etl, "WRITE_HISTORY_CSV", True)
    monkeypatch.setattr(base_etl, "get_latest_output_path", lambda name: data / "latest" / outputs[name].name)
    monkeypatch.setattr(
        base_etl, "get_history_output_path",
        lambda name, fecha=None: data / "history" / name / "year=2026/month=09/day=25" / outputs[name].name,
    )
    monkeypatch.setattr(base_etl, "FECHA_FIN", datetime(2026, 9, 25, tzinfo=timezone.utc))
    return root


def _fresh_artifacts(root: Path) -> tuple[Path, Path]:
    github = root / "artifacts" / "github"
    reddit = root / "artifacts" / "reddit"
    for artifact, dataset, filename, content in (
        (github, "github_repos", "github_repos_2025.csv", "language\nPython\nPython\n"),
        (github, "github_commits", "github_commits_frameworks.csv", "framework,ranking\nReact,1\n"),
        (reddit, "reddit_temas", "reddit_temas_emergentes.csv", "tema,menciones\nPython,8\n"),
    ):
        for relative in (filename, f"latest/{filename}", f"history/{dataset}/year=2026/month=09/day=25/{filename}"):
            _write(artifact, f"datos/{relative}", content)
    return github, reddit


def _assert_rejected(workspace, github, reddit, message):
    materialize_artifacts(workspace, [github, reddit])
    with pytest.raises(ValueError, match=message):
        reddit_etl.run_intersection_only(workspace, github, reddit)
    assert not (workspace / "datos/interseccion_github_reddit.csv").exists()


def test_fresh_intersection_uses_downloaded_github_not_checkout(workspace):
    github, reddit = _fresh_artifacts(workspace)
    _write(workspace, "datos/github_repos_2025.csv", "language\nJavaScript\n")
    _write(workspace, "datos/github_commits_frameworks.csv", "framework,ranking\nVue 3,1\n")
    _write(
        workspace,
        "datos/history/github_repos/year=2026/month=09/day=14/github_repos_2025.csv",
        "language\nOld\n",
    )
    materialize_artifacts(workspace, [github, reddit])

    reddit_etl.run_intersection_only(workspace, github, reddit)

    names = set(pd.read_csv(workspace / "datos/interseccion_github_reddit.csv")["tecnologia"])
    assert {"Python", "React"} <= names
    assert names.isdisjoint({"JavaScript", "Vue 3"})
    assert (workspace / "datos/latest/interseccion_github_reddit.csv").read_bytes() == (
        workspace / "datos/interseccion_github_reddit.csv"
    ).read_bytes()


def test_flat_downloaded_artifact_layout_keeps_history_partition(workspace):
    nested_github, nested_reddit = _fresh_artifacts(workspace)
    flat_github = workspace / "flat" / "github"
    flat_reddit = workspace / "flat" / "reddit"
    shutil.copytree(nested_github / "datos", flat_github)
    shutil.copytree(nested_reddit / "datos", flat_reddit)
    materialize_artifacts(workspace, [flat_github, flat_reddit])

    reddit_etl.run_intersection_only(workspace, flat_github, flat_reddit)

    source = flat_github / "history/github_repos/year=2026/month=09/day=25/github_repos_2025.csv"
    target = workspace / "datos/history/github_repos/year=2026/month=09/day=25/github_repos_2025.csv"
    assert target.read_bytes() == source.read_bytes()
    assert target.stat().st_mtime_ns == source.stat().st_mtime_ns


@pytest.mark.parametrize("missing", ["github_repos_2025.csv", "github_commits_frameworks.csv"])
def test_missing_downloaded_github_file_cannot_use_checkout(workspace, missing):
    github, reddit = _fresh_artifacts(workspace)
    (github / "datos" / missing).unlink()
    _write(workspace, "datos/github_repos_2025.csv", "language\nJavaScript\n")
    _write(workspace, "datos/github_commits_frameworks.csv", "framework,ranking\nVue 3,1\n")
    _assert_rejected(workspace, github, reddit, "GitHub")


def test_malformed_downloaded_commits_cannot_activate_static_fallback(workspace):
    github, reddit = _fresh_artifacts(workspace)
    bad = "framework,commits\nReact,10\n"
    _write(github, "datos/github_commits_frameworks.csv", bad)
    _write(github, "datos/latest/github_commits_frameworks.csv", bad)
    _write(github, "datos/history/github_commits/year=2026/month=09/day=25/github_commits_frameworks.csv", bad)
    _assert_rejected(workspace, github, reddit, "GitHub")


@pytest.mark.parametrize("dataset,filename", [
    ("github_repos", "github_repos_2025.csv"),
    ("github_commits", "github_commits_frameworks.csv"),
    ("reddit_temas", "reddit_temas_emergentes.csv"),
])
def test_missing_downloaded_source_history_fails_before_intersection_write(workspace, dataset, filename):
    github, reddit = _fresh_artifacts(workspace)
    artifact = reddit if dataset == "reddit_temas" else github
    history = artifact / "datos" / "history" / dataset / "year=2026" / "month=09" / "day=25" / filename
    history.unlink()
    _assert_rejected(workspace, github, reddit, "history")


def test_downloaded_history_must_match_materialized_source(workspace):
    github, reddit = _fresh_artifacts(workspace)
    materialize_artifacts(workspace, [github, reddit])
    history = workspace / "datos/history/github_commits/year=2026/month=09/day=25/github_commits_frameworks.csv"
    history.write_text("framework,ranking\nVue 3,1\n", encoding="utf-8")

    with pytest.raises(ValueError, match="history"):
        reddit_etl.run_intersection_only(workspace, github, reddit)
    assert not (workspace / "datos/interseccion_github_reddit.csv").exists()


def test_multiple_downloaded_history_snapshots_fail_closed(workspace):
    github, reddit = _fresh_artifacts(workspace)
    _write(
        github,
        "datos/history/github_repos/year=2026/month=09/day=24/github_repos_2025.csv",
        "language\nOld\n",
    )
    _assert_rejected(workspace, github, reddit, "history")


def test_final_intersection_identity_rejects_stale_frontend_and_history(workspace):
    root = _write(workspace, "datos/interseccion_github_reddit.csv", "tecnologia\nPython\n")
    _write(workspace, "datos/latest/interseccion_github_reddit.csv", root.read_text())
    asset = _write(workspace, "frontend/assets/data/interseccion_github_reddit.csv", "tecnologia\nOld\n")
    history = _write(
        workspace,
        "datos/history/interseccion/year=2026/month=09/day=25/interseccion_github_reddit.csv",
        root.read_text(),
    )

    with pytest.raises(ValueError, match="intersection output mismatch"):
        reddit_etl.verify_intersection_outputs(workspace, fresh=True)
    asset.write_bytes(root.read_bytes())
    reddit_etl.verify_intersection_outputs(workspace, fresh=True)
    history.write_text("tecnologia\nOld\n")
    with pytest.raises(ValueError, match="intersection output mismatch"):
        reddit_etl.verify_intersection_outputs(workspace, fresh=True)


def test_fallback_identity_does_not_require_current_history(workspace):
    baseline = workspace / "baseline"
    for name in ("reddit_sentimiento_frameworks.csv", "reddit_temas_emergentes.csv", "interseccion_github_reddit.csv"):
        _write(baseline, f"datos/{name}", "col\nprior\n")
    for name in ("reddit_sentimiento_public.json", "reddit_temas_history.json", "reddit_interseccion_history.json"):
        _write(baseline, f"frontend/assets/data/{name}", '{"latest_snapshot_date":"2026-09-14"}')
    restore_reddit_source_baseline(workspace, [baseline])
    _write(workspace, "frontend/assets/data/interseccion_github_reddit.csv", "col\nprior\n")

    reddit_etl.verify_intersection_outputs(workspace, fresh=False)
    assert not (workspace / "datos/history/interseccion/year=2026/month=09/day=25/interseccion_github_reddit.csv").exists()
