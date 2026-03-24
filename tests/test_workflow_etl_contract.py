import re
from pathlib import Path


WORKFLOW_PATH = Path(__file__).resolve().parent.parent / ".github" / "workflows" / "etl_semanal.yml"


def _load_workflow_text():
    return WORKFLOW_PATH.read_text(encoding="utf-8")


def test_workflow_has_parallel_source_jobs_and_aggregate_dependency_graph():
    content = _load_workflow_text()

    for job_name in ("job_github", "job_stackoverflow", "job_reddit", "job_aggregate", "job_publish"):
        assert f"{job_name}:" in content

    aggregate_needs_pattern = (
        r"job_aggregate:\s*(?:.|\n)*?needs:\s*"
        r"\n\s*-\s*job_github"
        r"\n\s*-\s*job_stackoverflow"
        r"\n\s*-\s*job_reddit"
    )
    assert re.search(aggregate_needs_pattern, content, flags=re.MULTILINE)


def test_workflow_artifact_handoff_contract_is_defined():
    content = _load_workflow_text()

    assert "name: github-data" in content
    assert "name: stackoverflow-data" in content
    assert "name: reddit-data" in content
    assert "name: aggregate-data" in content

    assert "Download GitHub artifacts" in content
    assert "Download StackOverflow artifacts" in content
    assert "Download Reddit artifacts" in content
    assert "Download aggregate artifacts" in content
    assert "if-no-files-found: error" in content
    assert "python scripts/materialize_etl_artifacts.py" in content
    assert "python scripts/check_bridge_integrity.py" in content
    assert "python scripts/download_valid_aggregate_artifact.py" in content
    assert "python scripts/hydrate_aggregate_history_seed.py --project-root ." in content
    assert "dawidd6/action-download-artifact" not in content
    assert "Stage Reddit artifact payload" in content
    assert "artifact_payload/reddit" in content


def test_workflow_publish_gate_and_bridge_asset_paths():
    content = _load_workflow_text()

    assert "if: ${{ needs.job_aggregate.result == 'success' }}" in content
    assert "Enforce frontend assets policy (strict)" in content
    assert "python scripts/check_frontend_assets.py --mode strict --root ." in content
    assert "frontend/assets/data/*.json" in content
    assert "python scripts/materialize_etl_artifacts.py --project-root . artifact_payload" in content
    assert "frontend/assets/data/github_lenguajes.csv" in content
    assert "frontend/assets/data/so_volumen_preguntas.csv" in content
    assert "frontend/assets/data/reddit_temas_emergentes.csv" in content
    assert "frontend/assets/data/run_manifest.json" in content


def test_workflow_enables_dual_write_and_bridge_flags():
    content = _load_workflow_text()

    assert 'DATA_WRITE_LEGACY_CSV: "1"' in content
    assert 'DATA_WRITE_LATEST_CSV: "1"' in content
    assert 'DATA_WRITE_HISTORY_CSV: "1"' in content
    assert 'EXPORT_HISTORY_BRIDGE_JSON: "1"' in content
    assert 'USE_PUBLIC_RUN_MANIFEST: "1"' in content
    assert "REQUIRE_FRONTEND_METADATA:" in content
    assert 'FRONTEND_ASSETS_POLICY_MODE: "strict"' in content
    assert 'TREND_SCORE_ENGINE: "duckdb"' in content


def test_workflow_generates_public_run_manifest_via_sync_assets():
    content = _load_workflow_text()

    assert "Sync CSVs to frontend assets" in content
    assert "python backend/sync_assets.py" in content
    assert "Generate/validate public run manifest" not in content


def test_workflow_no_longer_downloads_nltk_data():
    content = _load_workflow_text()

    assert "Download NLTK data" not in content


def test_workflow_reddit_job_resets_stale_outputs_and_requires_fresh_latest_files():
    content = _load_workflow_text()

    assert "Reset Reddit workspace outputs" in content
    assert "Stage Reddit artifact payload" in content
    assert "if: always()" in content
    assert "Reddit ETL produced no fresh latest/history outputs" in content
    assert "reddit_status.json" in content
    assert "datos/latest/reddit_sentimiento_frameworks.csv" in content
    assert "datos/latest/reddit_temas_emergentes.csv" in content
    assert "datos/latest/interseccion_github_reddit.csv" in content
    assert "Restore previous Reddit bridges on source fallback" in content
    assert "reddit_temas_history.json" in content
    assert "reddit_interseccion_history.json" in content
