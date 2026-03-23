from scripts.materialize_etl_artifacts import materialize_artifacts


def test_materialize_artifacts_restores_nested_datos_layout(tmp_path):
    artifact_root = tmp_path / "artifact"
    workspace_root = tmp_path / "workspace"

    (artifact_root / "datos" / "latest").mkdir(parents=True, exist_ok=True)
    (
        artifact_root
        / "datos"
        / "history"
        / "github_lenguajes"
        / "year=2026"
        / "month=03"
        / "day=22"
    ).mkdir(parents=True, exist_ok=True)

    (artifact_root / "datos" / "github_lenguajes.csv").write_text(
        "lenguaje,count\npython,10\n",
        encoding="utf-8",
    )
    (artifact_root / "datos" / "latest" / "github_lenguajes.csv").write_text(
        "lenguaje,count\npython,12\n",
        encoding="utf-8",
    )
    (
        artifact_root
        / "datos"
        / "history"
        / "github_lenguajes"
        / "year=2026"
        / "month=03"
        / "day=22"
        / "github_lenguajes.csv"
    ).write_text("lenguaje,count\npython,12\n", encoding="utf-8")

    summary = materialize_artifacts(
        project_root=workspace_root,
        artifact_roots=[artifact_root],
    )

    assert summary["legacy_files"] == 1
    assert summary["latest_files"] == 1
    assert summary["history_files"] == 1
    assert (workspace_root / "datos" / "github_lenguajes.csv").exists()
    assert (workspace_root / "datos" / "latest" / "github_lenguajes.csv").exists()
    assert (
        workspace_root
        / "datos"
        / "history"
        / "github_lenguajes"
        / "year=2026"
        / "month=03"
        / "day=22"
        / "github_lenguajes.csv"
    ).exists()


def test_materialize_artifacts_restores_flattened_layout_and_overlays_in_order(tmp_path):
    previous_root = tmp_path / "previous"
    current_root = tmp_path / "current"
    workspace_root = tmp_path / "workspace"

    (previous_root / "latest").mkdir(parents=True, exist_ok=True)
    (
        previous_root
        / "history"
        / "reddit_temas"
        / "year=2026"
        / "month=03"
        / "day=19"
    ).mkdir(parents=True, exist_ok=True)
    current_root.mkdir(parents=True, exist_ok=True)

    (previous_root / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nAI,10\n",
        encoding="utf-8",
    )
    (previous_root / "latest" / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nAI,10\n",
        encoding="utf-8",
    )
    (
        previous_root
        / "history"
        / "reddit_temas"
        / "year=2026"
        / "month=03"
        / "day=19"
        / "reddit_temas_emergentes.csv"
    ).write_text("tema,menciones\nAI,10\n", encoding="utf-8")

    (current_root / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nAI,12\n",
        encoding="utf-8",
    )
    (current_root / "latest").mkdir(parents=True, exist_ok=True)
    (current_root / "latest" / "reddit_temas_emergentes.csv").write_text(
        "tema,menciones\nAI,12\n",
        encoding="utf-8",
    )

    summary = materialize_artifacts(
        project_root=workspace_root,
        artifact_roots=[previous_root, current_root],
    )

    assert summary["legacy_files"] == 2
    assert summary["latest_files"] == 2
    assert summary["history_files"] == 1
    assert (workspace_root / "datos" / "reddit_temas_emergentes.csv").read_text(
        encoding="utf-8"
    ) == "tema,menciones\nAI,12\n"
    assert (workspace_root / "datos" / "latest" / "reddit_temas_emergentes.csv").read_text(
        encoding="utf-8"
    ) == "tema,menciones\nAI,12\n"
    assert (
        workspace_root
        / "datos"
        / "history"
        / "reddit_temas"
        / "year=2026"
        / "month=03"
        / "day=19"
        / "reddit_temas_emergentes.csv"
    ).exists()
