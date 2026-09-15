import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

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
    restore = runner.index("Restore-RedditOutputSnapshotPaths")
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
    assert "git reset --" not in runner
    assert 'git checkout --' not in runner
    preflight = runner.index("Assert-CleanWorktree", runner.index("Set-Location $repo"))
    seed = runner.index("Seed-HistoryFromRepoBaseline", snapshot)
    assert preflight < snapshot < seed


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
def test_integrity_failure_executes_prepublication_rollback_without_publication(tmp_path):
    automation = tmp_path / "automation"
    automation.mkdir()
    shutil.copy2(TRANSACTION_MODULE, automation / TRANSACTION_MODULE.name)
    existing = tmp_path / "existing.txt"
    created = tmp_path / "created.txt"
    existing.write_text("before", encoding="utf-8")

    runner = RUNNER_PATH.read_text(encoding="utf-8")
    preamble = runner[: runner.index("Set-Location $repo")]
    prepublication_start = runner.index("try {", runner.index("$outputSnapshot ="))
    prepublication_end = runner.index("\nRemove-RedditOutputSnapshot -Snapshot $outputSnapshot")
    harness = automation / "prepublication_fixture.ps1"
    harness.write_text(
        preamble
        + r'''
Set-Location $repo
$outputSnapshot = New-RedditOutputSnapshot -ProjectRoot $repo -RelativePaths @(
  "existing.txt",
  "created.txt",
  "frontend/assets/data/github_lenguajes_public.json",
  "frontend/assets/data/github_frameworks_history.json",
  "frontend/assets/data/github_correlacion_history.json",
  "frontend/assets/data/so_volumen_history.json",
  "frontend/assets/data/so_aceptacion_history.json",
  "frontend/assets/data/so_tendencias_history.json"
)
function Seed-HistoryFromRepoBaseline {
  Set-Content -LiteralPath (Join-Path $repo "existing.txt") -Value "mixed" -NoNewline
  Set-Content -LiteralPath (Join-Path $repo "created.txt") -Value "created" -NoNewline
}
function Get-BridgeSnapshotJson { return "{}" }
function Test-FreshRedditHistoryForDate { return $true }
function Assert-RedditMentionCoverage { return $true }
function Assert-BridgeDates {}
function Assert-BridgeSnapshotPreserved {}
function Run-Step {
  param([string]$Label, [string[]]$Command)
  if ($Label -eq "check_bridge_integrity") { throw "fixture integrity failure" }
  if ($Label -in @("git checkout branch", "git commit", "git push")) {
    Set-Content -LiteralPath (Join-Path $repo "publication-reached.txt") -Value $Label
  }
}
'''
        + runner[prepublication_start:prepublication_end],
        encoding="utf-8",
    )

    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "config", "user.email", "test@example.invalid"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "config", "user.name", "Test"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "add", "existing.txt", "automation"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "commit", "-qm", "fixture"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "branch", "-M", "main"], check=True)

    result = subprocess.run(
        [POWERSHELL, "-NoProfile", "-NonInteractive", "-File", str(harness)],
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode != 0
    assert "fixture integrity failure" in result.stderr
    assert existing.read_text(encoding="utf-8") == "before"
    assert not created.exists()
    assert not (tmp_path / "publication-reached.txt").exists()
    subprocess.run(["git", "-C", str(tmp_path), "diff", "--quiet"], check=True)

GUARDED_RUNNER_PATH = PROJECT_ROOT / "automation" / "run_reddit_baseline_guarded.ps1"


def _run_powershell(script, env):
    return subprocess.run(
        [POWERSHELL, "-NoProfile", "-NonInteractive", "-Command", script],
        env=env,
        capture_output=True,
        text=True,
        check=False,
    )


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
def test_guarded_runner_skips_before_state_or_main_when_named_lock_is_held(tmp_path):
    guarded = tmp_path / "automation" / "run_reddit_baseline_guarded.ps1"
    guarded.parent.mkdir()
    runner = GUARDED_RUNNER_PATH.read_text(encoding="utf-8")
    mutex_name = f"Global\\TechnologyTrend-RedditBaselineWeekly-{uuid.uuid4().hex}"
    runner = runner.replace(
        '"Global\\TechnologyTrend-RedditBaselineWeekly"',
        f'"{mutex_name}"',
    ).replace(
        "$utcNow = (Get-Date).ToUniversalTime()",
        "$utcNow = [datetime]::Parse('2026-09-14T03:00:00Z').ToUniversalTime()",
    )
    guarded.write_text(runner, encoding="utf-8")

    main = tmp_path / "automation" / "run_reddit_baseline.ps1"
    main.parent.mkdir(exist_ok=True)
    main.write_text(
        'Set-Content -LiteralPath (Join-Path (Split-Path -Parent $PSScriptRoot) "main-invoked.txt") -Value "invoked"\n',
        encoding="utf-8",
    )

    holder_script = """
$mutex = [System.Threading.Mutex]::new($false, '__MUTEX_NAME__')
if (-not $mutex.WaitOne(0)) { exit 2 }
[Console]::Out.WriteLine('LOCK_HELD')
Start-Sleep -Seconds 15
""".replace("__MUTEX_NAME__", mutex_name)
    holder = subprocess.Popen(
        [
            POWERSHELL,
            "-NoProfile",
            "-NonInteractive",
            "-Command",
            holder_script,
        ],
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
    )
    try:
        assert holder.stdout is not None
        assert holder.stdout.readline().strip() == "LOCK_HELD"
        result = subprocess.run(
            [POWERSHELL, "-NoProfile", "-NonInteractive", "-File", str(guarded), "-Reason", "manual"],
            capture_output=True,
            text=True,
            check=False,
            timeout=10,
        )
    finally:
        holder.terminate()
        holder.wait(timeout=10)

    assert result.returncode == 0, result.stderr
    assert "SKIP_RUNNER_LOCKED=1" in result.stdout
    assert "SKIP_RUNNER_LOCKED=1" in (tmp_path / "logs" / "reddit_baseline_weekly.log").read_text(encoding="utf-8")
    assert not (tmp_path / "automation" / "state").exists()
    assert not (tmp_path / "main-invoked.txt").exists()


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
@pytest.mark.parametrize("kind", ["tracked", "ignored", "empty_ignored_root"])
def test_runner_dirty_preflight_preserves_existing_bytes_and_stops_before_mutation(tmp_path, kind):
    subprocess.run(["git", "init", "-q", str(tmp_path)], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "config", "user.email", "test@example.invalid"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "config", "user.name", "Test"], check=True)
    (tmp_path / ".gitignore").write_text("datos/latest/\n", encoding="utf-8")
    tracked = tmp_path / "tracked.txt"
    tracked.write_bytes(b"before")
    subprocess.run(["git", "-C", str(tmp_path), "add", ".gitignore", "tracked.txt"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "commit", "-qm", "fixture"], check=True)
    subprocess.run(["git", "-C", str(tmp_path), "branch", "-M", "main"], check=True)

    if kind == "tracked":
        target = tracked
        target.write_bytes(b"preexisting-bytes")
    elif kind == "ignored":
        target = tmp_path / "datos" / "latest" / "preexisting.csv"
        target.parent.mkdir(parents=True)
        target.write_bytes(b"preexisting-bytes")
    else:
        target = tmp_path / "datos" / "latest"
        target.mkdir(parents=True)

    script = r'''
$runner = Get-Content -LiteralPath $env:RUNNER_PATH -Raw
$preamble = $runner.Substring(0, $runner.IndexOf('Set-Location $repo'))
$preamble = $preamble -replace 'Import-Module.*\r?\n', ''
$preamble = $preamble.Replace('$repo = Split-Path -Parent $PSScriptRoot', '$repo = $env:TEST_ROOT')
Invoke-Expression $preamble
$repo = $env:TEST_ROOT
Set-Location $repo
Assert-CleanWorktree
'''
    env = os.environ.copy()
    env["RUNNER_PATH"] = str(RUNNER_PATH)
    env["TEST_ROOT"] = str(tmp_path)
    result = _run_powershell(script, env)

    if kind == "empty_ignored_root":
        assert result.returncode == 0, result.stderr
    else:
        assert result.returncode != 0
        assert target.read_bytes() == b"preexisting-bytes"
