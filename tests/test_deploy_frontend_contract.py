from pathlib import Path


WORKFLOW = Path(__file__).resolve().parent.parent / ".github/workflows/deploy_frontend.yml"


def _step(content, name):
    return content.split(f"- name: {name}", 1)[1].split("\n      - name:", 1)[0]


def test_deploy_only_follows_successful_main_etl():
    content = WORKFLOW.read_text(encoding="utf-8")
    triggers = content.split("on:", 1)[1].split("permissions:", 1)[0]

    assert 'workflows: ["ETL Weekly Data Refresh"]' in triggers
    assert "types: [completed]" in triggers
    assert "branches: [main]" in triggers
    assert "push:" not in triggers
    assert "workflow_dispatch:" not in triggers
    assert (
        "if: ${{ github.event.workflow_run.conclusion == 'success' && "
        "github.event.workflow_run.head_branch == 'main' }}"
    ) in content


def test_deploy_requires_exact_triggering_run_artifact():
    content = WORKFLOW.read_text(encoding="utf-8")
    download = _step(content, "Download ETL artifact (workflow_run)")

    assert "run_id: ${{ github.event.workflow_run.id }}" in download
    assert "name: aggregate-data" in download
    assert "if_no_artifact_found: fail" in download
    assert "continue-on-error:" not in download
    assert "Download ETL artifact (latest main)" not in content


def test_deploy_fails_instead_of_using_stubs_when_remote_assets_are_missing():
    content = WORKFLOW.read_text(encoding="utf-8")
    resolve = _step(content, "Resolve remote assets base")
    inject = _step(content, "Inject remote JSON assets")

    for filename in (
        "history_index.json",
        "trend_score_history.json",
        "technology_profiles.json",
        "home_highlights.json",
        "github_lenguajes_public.json",
        "github_frameworks_history.json",
        "github_correlacion_history.json",
        "so_volumen_history.json",
        "so_aceptacion_history.json",
        "so_tendencias_history.json",
        "reddit_sentimiento_public.json",
        "reddit_temas_history.json",
        "reddit_interseccion_history.json",
        "run_manifest.json",
    ):
        assert f'"{filename}"' in resolve

    assert 'if [ ! -d "$REMOTE_DIR" ]; then' in resolve
    assert 'if [ ! -f "$REMOTE_DIR/$file" ]; then' in resolve
    assert "exit 1" in resolve
    assert 'echo "REMOTE_ASSETS_BASE_URL="' not in resolve
    assert "|| true" not in inject
    assert "keeping local stubs" not in inject
