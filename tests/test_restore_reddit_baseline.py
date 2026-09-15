import json
import shutil
from pathlib import Path

from export_history_json import rebuild_home_highlights_from_bridges
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
                "generated_at_utc": "2026-03-24T08:17:00Z",
                "source_mode": "history",
                "latest_snapshot_date": latest_snapshot_date,
                "previous_snapshot_date": "2026-03-22",
                "summary": {
                    "leader_topic": {
                        "tema": f"topic-{latest_snapshot_date}",
                        "menciones": 2228,
                        "delta_menciones": 0,
                    }
                },
            }
        ),
    )
    _write(
        root / "frontend" / "assets" / "data" / "reddit_sentimiento_public.json",
        json.dumps(
            {
                "generated_at_utc": "2026-03-24T08:17:00Z",
                "source_updated_at_utc": "2026-03-24T08:00:00Z",
                "dataset": "reddit_sentimiento_frameworks",
                "source_mode": "latest",
                "framework_count": 1,
            }
        ),
    )
    _write(
        root / "frontend" / "assets" / "data" / "reddit_interseccion_history.json",
        json.dumps(
            {
                "generated_at_utc": "2026-03-24T08:17:00Z",
                "source_mode": "history",
                "latest_snapshot_date": latest_snapshot_date,
                "previous_snapshot_date": "2026-03-22",
                "summary": {
                    "closest_alignment": {
                        "tecnologia": "Python",
                        "brecha_abs": 1,
                        "promedio_rank": 1.0,
                    }
                },
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


def test_restore_reddit_bridges_preserves_canonical_provenance_in_every_asset_root(tmp_path, monkeypatch):
    project_root = tmp_path / "project"
    repo_baseline = tmp_path / "repo_baseline"
    _create_candidate(repo_baseline, "2026-03-24")
    monkeypatch.setenv("FRONTEND_BRIDGE_REMOTE_DIR", "datos/metadata/remote_assets")

    restore_reddit_bridges(project_root, [repo_baseline])

    for assets_root in (
        project_root / "frontend" / "assets" / "data",
        project_root / "datos" / "metadata" / "remote_assets",
    ):
        for filename, timestamp_field, timestamp in (
            ("reddit_sentimiento_public.json", "source_updated_at_utc", "2026-03-24T08:00:00Z"),
            ("reddit_temas_history.json", "generated_at_utc", "2026-03-24T08:17:00Z"),
            ("reddit_interseccion_history.json", "generated_at_utc", "2026-03-24T08:17:00Z"),
        ):
            bridge = json.loads((assets_root / filename).read_text(encoding="utf-8"))
            assert bridge[timestamp_field] == timestamp
            assert bridge["fallback_provenance"] == {
                "source": "reddit",
                "mode": "baseline",
                "latest_snapshot_date": "2026-03-24",
            }


def test_restore_reddit_bridges_rebuilds_home_in_frontend_and_remote_assets(
    tmp_path,
    monkeypatch,
):
    project_root = tmp_path / "project"
    repo_baseline = tmp_path / "repo_baseline"
    _create_candidate(repo_baseline, "2026-03-24")

    fixture_root = Path(__file__).resolve().parent.parent / "frontend" / "assets" / "data"
    frontend_root = project_root / "frontend" / "assets" / "data"
    remote_root = project_root / "datos" / "metadata" / "remote_assets"
    bridge_names = (
        "github_lenguajes_public.json",
        "github_frameworks_history.json",
        "github_correlacion_history.json",
        "reddit_sentimiento_public.json",
        "reddit_temas_history.json",
        "reddit_interseccion_history.json",
        "so_volumen_history.json",
        "so_aceptacion_history.json",
        "so_tendencias_history.json",
        "home_highlights.json",
    )
    for assets_root in (frontend_root, remote_root):
        assets_root.mkdir(parents=True)
        for name in bridge_names:
            shutil.copy2(fixture_root / name, assets_root / name)

    monkeypatch.setenv("FRONTEND_BRIDGE_REMOTE_DIR", "datos/metadata/remote_assets")

    summary = restore_reddit_bridges(project_root, [repo_baseline])
    for assets_root in (frontend_root, remote_root):
        rebuild_home_highlights_from_bridges(assets_root)

    assert summary["asset_roots_updated"] == 2
    for assets_root in (frontend_root, remote_root):
        topics = json.loads((assets_root / "reddit_temas_history.json").read_text(encoding="utf-8"))
        home = json.loads((assets_root / "home_highlights.json").read_text(encoding="utf-8"))
        assert topics["latest_snapshot_date"] == "2026-03-24"
        assert home["dashboard_signals"]["reddit"]["graph_2"]["payload"] == topics["summary"]["leader_topic"]
