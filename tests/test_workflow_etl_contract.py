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
    assert "Missing required artifact file" in content
    assert "Optional artifact missing (degraded mode may continue)" in content


def test_workflow_publish_gate_and_bridge_asset_paths():
    content = _load_workflow_text()

    assert "if: ${{ needs.job_aggregate.result == 'success' }}" in content
    assert "Enforce frontend assets policy (strict)" in content
    assert "python scripts/check_frontend_assets.py --mode strict --root ." in content
    assert "frontend/assets/data/*.json" in content
    assert "artifact_payload/frontend/assets/data/*.json" in content
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


def test_workflow_generates_public_run_manifest():
    content = _load_workflow_text()

    assert "Generate/validate public run manifest" in content
    assert "python backend/generate_run_manifest.py" in content
