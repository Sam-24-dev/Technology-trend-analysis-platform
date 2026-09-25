import json
import os
from pathlib import Path
import shutil
import subprocess
import uuid

import pytest

from backend import export_history_json
from backend.generate_run_manifest import generate_manifest_from_final_bridges
from scripts.check_source_freshness import REQUIRED_SOURCE_DATASETS, check_source_freshness


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

FINAL_REDDIT_BRIDGES = (
    ("reddit_sentimiento_public.json", "reddit_sentimiento_frameworks", "source_updated_at_utc"),
    ("reddit_temas_history.json", "reddit_temas_emergentes", "generated_at_utc"),
    ("reddit_interseccion_history.json", "interseccion_github_reddit", "generated_at_utc"),
)


def _write_final_reddit_bridges(assets_root, timestamp):
    for filename, dataset, timestamp_field in FINAL_REDDIT_BRIDGES:
        (assets_root / filename).write_text(
            json.dumps(
                {
                    "dataset": dataset,
                    timestamp_field: timestamp,
                    "fallback_provenance": {"source": "reddit", "mode": "baseline"},
                }
            ),
            encoding="utf-8",
        )


def _write_fresh_manifest(project_root, *, generated_at, reddit_timestamp):
    assets_root = project_root / "frontend" / "assets" / "data"
    assets_root.mkdir(parents=True)
    summaries = [
        {"dataset": dataset, "updated_at_utc": reddit_timestamp if source == "reddit" else generated_at}
        for source, datasets in REQUIRED_SOURCE_DATASETS.items()
        for dataset in datasets
    ]
    (assets_root / "run_manifest.json").write_text(
        json.dumps({"generated_at_utc": generated_at, "dataset_summaries": summaries}),
        encoding="utf-8",
    )
    return assets_root


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


def test_final_manifest_uses_restored_canonical_bridge_metadata(tmp_path):
    latest_dir = tmp_path / "datos" / "latest"
    assets_root = tmp_path / "frontend" / "assets" / "data"
    latest_dir.mkdir(parents=True)
    assets_root.mkdir(parents=True)
    for filename, content in {
        "github_lenguajes.csv": "lenguaje,total_repos\nPython,1\n",
        "so_volumen_preguntas.csv": "lenguaje,preguntas_nuevas_2025\nPython,1\n",
        "reddit_sentimiento_frameworks.csv": "framework,total_menciones\nPython,1\n",
        "reddit_temas_emergentes.csv": "tema,menciones\nPython,1\n",
        "interseccion_github_reddit.csv": "tecnologia,rank\nPython,1\n",
    }.items():
        (latest_dir / filename).write_text(content, encoding="utf-8")
    github_timestamp = "2026-08-22T08:15:00Z"
    stackoverflow_timestamp = "2026-08-23T08:16:00Z"
    reddit_timestamp = "2026-08-24T08:17:00Z"
    (assets_root / "github_lenguajes_public.json").write_text(
        json.dumps({"source_updated_at_utc": github_timestamp}),
        encoding="utf-8",
    )
    (assets_root / "so_volumen_history.json").write_text(
        json.dumps({"generated_at_utc": stackoverflow_timestamp}),
        encoding="utf-8",
    )
    _write_final_reddit_bridges(assets_root, reddit_timestamp)
    metadata = tmp_path / "datos" / "metadata"
    metadata.mkdir(parents=True)
    (metadata / "run_manifest.json").write_text(
        json.dumps(
            {
                "generated_at_utc": "2026-01-01T00:00:00Z",
                "datasets": [
                    {
                        "dataset_logical_name": "github_lenguajes",
                        "generated_at_utc": "2026-01-01T00:00:00Z",
                    },
                    {
                        "dataset_logical_name": "so_volumen_preguntas",
                        "generated_at_utc": "2026-01-01T00:00:00Z",
                    },
                ],
            }
        ),
        encoding="utf-8",
    )

    generate_manifest_from_final_bridges(tmp_path, output_dirs=[assets_root], require_metadata=True)

    manifest = json.loads((assets_root / "run_manifest.json").read_text(encoding="utf-8"))
    timestamps = {item["dataset"]: item["updated_at_utc"] for item in manifest["dataset_summaries"]}
    assert timestamps["github_lenguajes"] == github_timestamp
    assert timestamps["so_volumen_preguntas"] == stackoverflow_timestamp
    assert all(timestamps[dataset] == reddit_timestamp for _, dataset, _ in FINAL_REDDIT_BRIDGES)
    assert manifest["notes"] == "Sources restored from baseline: reddit"


def test_runner_regenerates_and_checks_final_manifest_before_publication(tmp_path):
    runner = RUNNER_PATH.read_text(encoding="utf-8")
    restore = runner.index("Restore-RedditOutputSnapshotPaths")
    rebuild = runner.index('Run-Step "rebuild home highlights from final bridges"')
    manifest = runner.index('Run-Step "regenerate final run manifest from final bridges"')
    freshness = runner.index('Run-Step "check final canonical source freshness"')
    integrity = runner.index('Run-Step "check_bridge_integrity"')
    publication = runner.index('Run-Step "git checkout branch"')

    assert restore < rebuild < manifest < freshness < integrity < publication
    assert '"--from-final-bridges"' in runner
    assert '"--output-dir", "frontend\\assets\\data"' in runner
    assert '"--max-source-age-hours", "192"' in runner

    normal_assets_root = _write_fresh_manifest(
        tmp_path / "normal",
        generated_at="2026-09-08T08:17:00Z",
        reddit_timestamp="2026-09-08T08:17:00Z",
    )
    _write_final_reddit_bridges(normal_assets_root, "2026-09-08T08:17:00Z")
    assert check_source_freshness(tmp_path / "normal")["source_updated_at_utc"]["reddit"] == "2026-09-08T08:17:00Z"

    assets_root = _write_fresh_manifest(
        tmp_path,
        generated_at="2026-09-08T08:17:00Z",
        reddit_timestamp="2026-08-30T08:16:59Z",
    )
    _write_final_reddit_bridges(assets_root, "2026-08-30T08:16:59Z")
    with pytest.raises(ValueError, match="Source freshness stale: reddit"):
        check_source_freshness(tmp_path)


@pytest.mark.skipif(POWERSHELL is None, reason="PowerShell is required")
@pytest.mark.parametrize(
    ("failing_step", "failure_message"),
    [
        ("check final canonical source freshness", "fixture final freshness failure"),
        ("check_bridge_integrity", "fixture integrity failure"),
        ("assert bridge dates", "fixture bridge date mismatch"),
    ],
)
def test_prepublication_failure_executes_rollback_without_publication(
    tmp_path, failing_step, failure_message
):
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
function Assert-BridgeDates {
  if ("__FAILING_STEP__" -eq "assert bridge dates") { throw "__FAILURE_MESSAGE__" }
}
function Assert-BridgeSnapshotPreserved {}
function Run-Step {
  param([string]$Label, [string[]]$Command)
  if ($Label -eq "__FAILING_STEP__") { throw "__FAILURE_MESSAGE__" }
  if ($Label -in @("git checkout branch", "git commit", "git push")) {
    Set-Content -LiteralPath (Join-Path $repo "publication-reached.txt") -Value $Label
  }
}
'''.replace("__FAILING_STEP__", failing_step).replace("__FAILURE_MESSAGE__", failure_message)
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
    assert failure_message in result.stderr
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
