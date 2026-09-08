import json
import os
from pathlib import Path
import shutil
import subprocess

import pytest

from backend import export_history_json


PROJECT_ROOT = Path(__file__).resolve().parent.parent
RUNNER_PATH = PROJECT_ROOT / "automation" / "run_reddit_baseline.ps1"
TRANSACTION_MODULE = PROJECT_ROOT / "automation" / "reddit_output_transaction.psm1"
POWERSHELL = shutil.which("pwsh") or shutil.which("powershell.exe")
BRIDGE_NAMES = (
    "github_lenguajes_public.json",
    "github_frameworks_history.json",
    "github_correlacion_history.json",
    "reddit_sentimiento_public.json",
    "reddit_temas_history.json",
    "reddit_interseccion_history.json",
    "so_volumen_history.json",
    "so_aceptacion_history.json",
    "so_tendencias_history.json",
)


def test_runner_rebuilds_home_from_final_bridges_not_stale_latest(tmp_path):
    source_root = PROJECT_ROOT / "frontend" / "assets" / "data"
    assets_root = tmp_path / "frontend" / "assets" / "data"
    assets_root.mkdir(parents=True)
    for name in BRIDGE_NAMES:
        shutil.copy2(source_root / name, assets_root / name)

    canonical_path = assets_root / "github_lenguajes_public.json"
    canonical = json.loads(canonical_path.read_text(encoding="utf-8"))
    canonical["summary"]["leader"] = {
        "lenguaje": "Canonical",
        "repos_count": 883,
        "share_pct": 31.85,
    }
    canonical_path.write_text(json.dumps(canonical), encoding="utf-8")

    stale_latest = tmp_path / "datos" / "latest" / "github_lenguajes.csv"
    stale_latest.parent.mkdir(parents=True)
    stale_latest.write_text(
        "lenguaje,repos_count,share_pct\nStale,893,34.94\n",
        encoding="utf-8",
    )

    export_history_json.rebuild_home_highlights_from_bridges(assets_root)

    home = json.loads((assets_root / "home_highlights.json").read_text(encoding="utf-8"))
    assert home["dashboard_signals"]["github"]["graph_1"]["payload"]["lenguaje"] == "Canonical"
    assert "Stale,893,34.94" in stale_latest.read_text(encoding="utf-8")

    runner = RUNNER_PATH.read_text(encoding="utf-8")
    restore = runner.index('Run-Step "restore non-reddit bridge assets"')
    rebuild = runner.index('Run-Step "rebuild home highlights from final bridges"')
    integrity = runner.index('Run-Step "check_bridge_integrity"')
    assert restore < rebuild < integrity
    assert "--rebuild-home-from" in runner
    assert "frontend\\assets\\data" in runner


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
def test_output_transaction_rolls_back_mixed_post_sync_outputs(tmp_path):
    existing = tmp_path / "datos" / "latest" / "reddit_temas_emergentes.csv"
    created = tmp_path / "datos" / "history" / "reddit_temas" / "new.csv"
    highlights = tmp_path / "frontend" / "assets" / "data" / "home_highlights.json"
    existing.parent.mkdir(parents=True)
    existing.write_text("before", encoding="utf-8")
    highlights.parent.mkdir(parents=True)
    highlights.write_text("canonical-home", encoding="utf-8")

    script = r"""
Import-Module $env:TRANSACTION_MODULE -Force
$snapshot = New-RedditOutputSnapshot `
  -ProjectRoot $env:TEST_ROOT `
  -RelativePaths @(
    "datos/latest/reddit_temas_emergentes.csv",
    "datos/history/reddit_temas/new.csv",
    "frontend/assets/data/home_highlights.json"
  )
Set-Content -LiteralPath (Join-Path $env:TEST_ROOT "datos/latest/reddit_temas_emergentes.csv") -Value "mixed" -NoNewline
$newPath = Join-Path $env:TEST_ROOT "datos/history/reddit_temas/new.csv"
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $newPath) | Out-Null
Set-Content -LiteralPath $newPath -Value "new" -NoNewline
Set-Content -LiteralPath (Join-Path $env:TEST_ROOT "frontend/assets/data/home_highlights.json") -Value "mixed-home" -NoNewline
Restore-RedditOutputSnapshot -Snapshot $snapshot
if (Test-Path -LiteralPath $snapshot.BackupRoot) {
  throw "Snapshot backup was not removed after restore"
}
"""
    env = os.environ.copy()
    env["TRANSACTION_MODULE"] = str(TRANSACTION_MODULE)
    env["TEST_ROOT"] = str(tmp_path)
    result = subprocess.run(
        [POWERSHELL, "-NoProfile", "-NonInteractive", "-Command", script],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    assert existing.read_text(encoding="utf-8") == "before"
    assert highlights.read_text(encoding="utf-8") == "canonical-home"
    assert not created.exists()


def test_integrity_failure_rolls_back_before_any_publication_step():
    runner = RUNNER_PATH.read_text(encoding="utf-8")

    snapshot = runner.index("New-RedditOutputSnapshot")
    integrity = runner.index('Run-Step "check_bridge_integrity"')
    rollback = runner.index("Restore-RedditOutputSnapshot", integrity)
    branch = runner.index('Run-Step "git checkout branch"')
    commit = runner.index('Run-Step "git commit"')
    push = runner.index('Run-Step "git push"')
    pull_request = runner.index("gh pr create")

    assert snapshot < integrity < rollback < branch < commit < push < pull_request
    assert "git clean" not in runner
