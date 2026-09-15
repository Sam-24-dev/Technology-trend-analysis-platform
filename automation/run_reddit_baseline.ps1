$ErrorActionPreference = "Stop"

$repo = Split-Path -Parent $PSScriptRoot
$py = Join-Path $repo ".venv311\Scripts\python.exe"
Import-Module (Join-Path $PSScriptRoot "reddit_output_transaction.psm1") -Force

$utcNow = (Get-Date).ToUniversalTime()
$utcDate = $utcNow.ToString("yyyy-MM-dd")
$stamp = $utcNow.ToString("yyyyMMdd-HHmm")
$branch = "reddit-baseline-$stamp"

$legacyCsvFiles = @(
  "interseccion_github_reddit.csv",
  "reddit_sentimiento_frameworks.csv",
  "reddit_temas_emergentes.csv"
)

$frontendCsvFiles = @(
  "frontend\assets\data\interseccion_github_reddit.csv",
  "frontend\assets\data\reddit_sentimiento_frameworks.csv",
  "frontend\assets\data\reddit_temas_emergentes.csv"
)

$frontendJsonFiles = @(
  "frontend\assets\data\reddit_sentimiento_public.json",
  "frontend\assets\data\reddit_temas_history.json",
  "frontend\assets\data\reddit_interseccion_history.json"
)

$filesToStage = @(
  "datos\interseccion_github_reddit.csv",
  "datos\reddit_sentimiento_frameworks.csv",
  "datos\reddit_temas_emergentes.csv",
  "datos\trend_score.csv",
  "frontend\assets\data\history_index.json",
  "frontend\assets\data\home_highlights.json",
  "frontend\assets\data\interseccion_github_reddit.csv",
  "frontend\assets\data\reddit_sentimiento_frameworks.csv",
  "frontend\assets\data\reddit_temas_emergentes.csv",
  "frontend\assets\data\reddit_sentimiento_public.json",
  "frontend\assets\data\reddit_temas_history.json",
  "frontend\assets\data\reddit_interseccion_history.json",
  "frontend\assets\data\run_manifest.json",
  "frontend\assets\data\technology_profiles.json",
  "frontend\assets\data\trend_score.csv",
  "frontend\assets\data\trend_score_history.json"
)
function Run-Step {
  param(
    [string]$Label,
    [string[]]$Command
  )

  Write-Host "==> $Label"
  & $Command[0] $Command[1..($Command.Length - 1)]
  if ($LASTEXITCODE -ne 0) {
    throw "$Label failed with exit code $LASTEXITCODE"
  }
}

$knownIgnoredOutputRoots = @(
  "datos\latest",
  "datos\history",
  "datos\metadata"
)

function Assert-CleanWorktree {
  $status = @(git status --porcelain)
  if ($LASTEXITCODE -ne 0) {
    throw "git status failed with exit code $LASTEXITCODE"
  }

  $ignoredOutputStatus = @(git status --porcelain --ignored --untracked-files=all -- $knownIgnoredOutputRoots)
  if ($LASTEXITCODE -ne 0) {
    throw "git status for ignored outputs failed with exit code $LASTEXITCODE"
  }
  $ignoredOutputs = @($ignoredOutputStatus | Where-Object { $_.StartsWith("!! ") })
  if ($status.Count -gt 0 -or $ignoredOutputs.Count -gt 0) {
    $details = @($status) + $ignoredOutputs
    throw "The repository has pre-existing changes or ignored outputs. Save or remove them before running the automation.`n$($details -join "`n")"
  }

  $currentBranch = (git branch --show-current).Trim()
  if ($LASTEXITCODE -ne 0 -or $currentBranch -ne "main") {
    throw "The automation requires a clean worktree on the main branch. Current branch: $currentBranch"
  }
}

function Test-FreshRedditHistoryForDate {
  param([string]$SnapshotDate)

  $parts = $SnapshotDate.Split("-")
  if ($parts.Length -ne 3) {
    return $false
  }

  $expected = @(
    "datos\history\reddit_sentimiento\year=$($parts[0])\month=$($parts[1])\day=$($parts[2])\reddit_sentimiento_frameworks.csv",
    "datos\history\reddit_temas\year=$($parts[0])\month=$($parts[1])\day=$($parts[2])\reddit_temas_emergentes.csv",
    "datos\history\interseccion\year=$($parts[0])\month=$($parts[1])\day=$($parts[2])\interseccion_github_reddit.csv"
  )

  foreach ($path in $expected) {
    $fullPath = Join-Path $repo $path
    if (-not (Test-Path $fullPath)) {
      return $false
    }
    if ((Get-Item $fullPath).Length -le 0) {
      return $false
    }
  }

  return $true
}

function Get-RedditTopicMentionsTotal {
  $topicsCsv = Join-Path $repo "datos\reddit_temas_emergentes.csv"
  if (-not (Test-Path $topicsCsv)) {
    throw "No existe el CSV de temas Reddit esperado: $topicsCsv"
  }

  $rows = Import-Csv $topicsCsv
  $total = 0
  foreach ($row in $rows) {
    $value = 0
    $rawValue = $row.menciones
    if ($null -eq $rawValue) {
      $rawValue = $row.total_menciones
    }
    if ([int]::TryParse([string]$rawValue, [ref]$value)) {
      $total += $value
    }
  }
  return $total
}

function Assert-RedditMentionCoverage {
  $minimumMentions = 400
  $targetMentions = 900

  if (-not [string]::IsNullOrWhiteSpace($env:REDDIT_MIN_TOTAL_MENTIONS)) {
    $minimumMentions = [int]$env:REDDIT_MIN_TOTAL_MENTIONS
  }
  if (-not [string]::IsNullOrWhiteSpace($env:REDDIT_TARGET_TOTAL_MENTIONS)) {
    $targetMentions = [int]$env:REDDIT_TARGET_TOTAL_MENTIONS
  }

  $totalMentions = Get-RedditTopicMentionsTotal
  Write-Host "REDDIT_TOTAL_MENTIONS=$totalMentions"

  if ($totalMentions -lt $minimumMentions) {
    Write-Host "LOW_REDDIT_MENTIONS_ROLLBACK=1"
    Write-Host "Reddit genero $totalMentions menciones; minimo requerido: $minimumMentions. Se restaura el repo y no se abre PR."
    return $false
  }

  if ($totalMentions -lt $targetMentions) {
    Write-Host "REDDIT_TARGET_NOT_MET=1"
    Write-Host "Reddit genero $totalMentions menciones; objetivo ideal: $targetMentions. Supera el minimo y continua."
  }
  else {
    Write-Host "REDDIT_TARGET_MET=1"
  }

  return $true
}

function Get-RepoBaselineDate {
  $topicsBridgePath = Join-Path $repo "frontend\assets\data\reddit_temas_history.json"
  $intersectionBridgePath = Join-Path $repo "frontend\assets\data\reddit_interseccion_history.json"

  if (-not (Test-Path $topicsBridgePath)) {
    throw "No existe reddit_temas_history.json en el repo."
  }
  if (-not (Test-Path $intersectionBridgePath)) {
    throw "No existe reddit_interseccion_history.json en el repo."
  }

  $topicsBridge = Get-Content $topicsBridgePath -Raw | ConvertFrom-Json
  $intersectionBridge = Get-Content $intersectionBridgePath -Raw | ConvertFrom-Json

  $seedDate = [string]$topicsBridge.latest_snapshot_date
  $intersectionDate = [string]$intersectionBridge.latest_snapshot_date

  if ([string]::IsNullOrWhiteSpace($seedDate)) {
    throw "El baseline actual del repo no tiene latest_snapshot_date en reddit_temas_history.json."
  }
  if ($seedDate -ne $intersectionDate) {
    throw "Los bridges Reddit del repo no coinciden en latest_snapshot_date."
  }

  $parts = $seedDate.Split("-")
  if ($parts.Length -ne 3) {
    throw "latest_snapshot_date invalido en el baseline actual del repo: $seedDate"
  }

  return $seedDate
}

function Seed-HistoryFromRepoBaseline {
  param([string]$SeedDate)

  $parts = $SeedDate.Split("-")

  $seedSpecs = @(
    @{ Dataset = "reddit_sentimiento"; File = "reddit_sentimiento_frameworks.csv" },
    @{ Dataset = "reddit_temas"; File = "reddit_temas_emergentes.csv" },
    @{ Dataset = "interseccion"; File = "interseccion_github_reddit.csv" }
  )

  foreach ($spec in $seedSpecs) {
    $source = Join-Path $repo ("datos\" + $spec.File)
    if (-not (Test-Path $source)) {
      throw "No existe el CSV base requerido: $source"
    }

    $target = Join-Path $repo (
      "datos\history\" + $spec.Dataset +
      "\year=" + $parts[0] +
      "\month=" + $parts[1] +
      "\day=" + $parts[2] +
      "\" + $spec.File
    )

    $targetDir = Split-Path -Parent $target
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Copy-Item $source $target -Force
  }

  return $SeedDate
}

function Get-RedditRunOutputPaths {
  param(
    [string]$SeedDate,
    [string]$SnapshotDate
  )

  $paths = @($filesToStage)
  $paths += @(
    "datos\latest\reddit_sentimiento_frameworks.csv",
    "datos\latest\reddit_temas_emergentes.csv",
    "datos\latest\interseccion_github_reddit.csv",
    "datos\latest\trend_score.csv",
    "frontend\assets\data\github_lenguajes.csv",
    "frontend\assets\data\github_commits_frameworks.csv",
    "frontend\assets\data\github_correlacion.csv",
    "frontend\assets\data\so_volumen_preguntas.csv",
    "frontend\assets\data\so_tasa_aceptacion.csv",
    "frontend\assets\data\so_tendencias_mensuales.csv",
    "frontend\assets\data\github_lenguajes_public.json",
    "frontend\assets\data\github_frameworks_history.json",
    "frontend\assets\data\github_correlacion_history.json",
    "frontend\assets\data\so_volumen_history.json",
    "frontend\assets\data\so_aceptacion_history.json",
    "frontend\assets\data\so_tendencias_history.json"
  )

  $historySpecs = @(
    @{ Dataset = "reddit_sentimiento"; File = "reddit_sentimiento_frameworks.csv" },
    @{ Dataset = "reddit_temas"; File = "reddit_temas_emergentes.csv" },
    @{ Dataset = "interseccion"; File = "interseccion_github_reddit.csv" }
  )
  foreach ($date in @($SeedDate, $SnapshotDate)) {
    $parts = $date.Split("-")
    foreach ($spec in $historySpecs) {
      $paths += (
        "datos\history\" + $spec.Dataset +
        "\year=" + $parts[0] +
        "\month=" + $parts[1] +
        "\day=" + $parts[2] +
        "\" + $spec.File
      )
    }
  }

  $snapshotParts = $SnapshotDate.Split("-")
  $paths += (
    "datos\history\trend_score" +
    "\year=" + $snapshotParts[0] +
    "\month=" + $snapshotParts[1] +
    "\day=" + $snapshotParts[2] +
    "\trend_score.csv"
  )

  $historyIndexPath = Join-Path $repo "frontend\assets\data\history_index.json"
  if (Test-Path -LiteralPath $historyIndexPath -PathType Leaf) {
    $historyIndex = Get-Content -LiteralPath $historyIndexPath -Raw | ConvertFrom-Json
    foreach ($dataset in $historyIndex.datasets) {
      if (-not [string]::IsNullOrWhiteSpace([string]$dataset.latest_path)) {
        $paths += [string]$dataset.latest_path
      }
      if ($dataset.snapshots.Count -gt 0) {
        $paths += [string]$dataset.snapshots[-1].path
      }
    }
  }

  return @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Get-BridgeSnapshotJson {
  param(
    [string]$BridgePath,
    [string]$SnapshotDate
  )

  if (-not (Test-Path $BridgePath)) {
    throw "No existe el bridge requerido: $BridgePath"
  }

  $payload = Get-Content $BridgePath -Raw | ConvertFrom-Json
  $snapshot = $payload.snapshots | Where-Object { [string]$_.date -eq $SnapshotDate } | Select-Object -First 1
  if ($null -eq $snapshot) {
    throw "No existe snapshot $SnapshotDate en $BridgePath"
  }

  return ($snapshot | ConvertTo-Json -Depth 100 -Compress)
}

function Copy-RedditCsvsToFrontend {
  $frontendDir = Join-Path $repo "frontend\assets\data"
  New-Item -ItemType Directory -Force -Path $frontendDir | Out-Null

  foreach ($csvName in $legacyCsvFiles) {
    $source = Join-Path $repo ("datos\" + $csvName)
    $target = Join-Path $frontendDir $csvName

    if (-not (Test-Path $source)) {
      throw "No existe el CSV Reddit esperado: $source"
    }

    Copy-Item $source $target -Force
  }
}

function Export-RedditFrontendAssets {
  $exportCode = @"
import json
import sys
from pathlib import Path

project_root = Path(r"$repo")
sys.path.insert(0, str(project_root / "backend"))

from export_history_json import (
    build_history_index,
    build_reddit_sentiment_public,
    build_reddit_topics_history,
    build_reddit_intersection_history,
)

output_dir = project_root / "frontend" / "assets" / "data"
output_dir.mkdir(parents=True, exist_ok=True)

history_index = build_history_index(project_root)
sentiment_payload = build_reddit_sentiment_public(project_root)
topics_payload = build_reddit_topics_history(project_root, history_index)
intersection_payload = build_reddit_intersection_history(project_root, history_index)

def validate_bridge(name, payload):
    source_mode = str(payload.get("source_mode", "")).strip().lower()
    latest_snapshot_date = payload.get("latest_snapshot_date")
    previous_snapshot_date = payload.get("previous_snapshot_date")

    if source_mode in {"", "missing", "none"}:
        raise SystemExit(f"{name} generated invalid source_mode={source_mode or 'missing'}")
    if not latest_snapshot_date:
        raise SystemExit(f"{name} missing latest_snapshot_date")
    if not previous_snapshot_date:
        raise SystemExit(f"{name} missing previous_snapshot_date")
    return latest_snapshot_date, previous_snapshot_date

topics_latest, topics_previous = validate_bridge("reddit_temas_history.json", topics_payload)
intersection_latest, intersection_previous = validate_bridge("reddit_interseccion_history.json", intersection_payload)

if topics_latest != intersection_latest:
    raise SystemExit("Reddit bridges latest_snapshot_date mismatch")
if topics_previous != intersection_previous:
    raise SystemExit("Reddit bridges previous_snapshot_date mismatch")

payloads = {
    "reddit_sentimiento_public.json": sentiment_payload,
    "reddit_temas_history.json": topics_payload,
    "reddit_interseccion_history.json": intersection_payload,
}

for filename, payload in payloads.items():
    (output_dir / filename).write_text(
        json.dumps(payload, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
"@

  $tempScript = Join-Path $env:TEMP "reddit_frontend_export.py"
  Set-Content -Path $tempScript -Value $exportCode -Encoding UTF8
  try {
    Run-Step "export reddit frontend assets" @($py, $tempScript)
  }
  finally {
    if (Test-Path $tempScript) {
      Remove-Item -Force $tempScript
    }
  }
}

function Assert-BridgeDates {
  param(
    [string]$ExpectedLatest,
    [string]$ExpectedPrevious
  )

  $bridgePaths = @(
    (Join-Path $repo "frontend\assets\data\reddit_temas_history.json"),
    (Join-Path $repo "frontend\assets\data\reddit_interseccion_history.json")
  )

  foreach ($bridgePath in $bridgePaths) {
    $payload = Get-Content $bridgePath -Raw | ConvertFrom-Json
    $sourceMode = [string]$payload.source_mode
    $latest = [string]$payload.latest_snapshot_date
    $previous = [string]$payload.previous_snapshot_date

    if ([string]::IsNullOrWhiteSpace($sourceMode) -or $sourceMode.ToLower() -in @("missing", "none")) {
      throw "Bridge invalido: $bridgePath tiene source_mode=$sourceMode"
    }
    if ($latest -ne $ExpectedLatest) {
      throw "Bridge invalido: $bridgePath latest_snapshot_date=$latest, esperado=$ExpectedLatest"
    }
    if ($previous -ne $ExpectedPrevious) {
      throw "Bridge invalido: $bridgePath previous_snapshot_date=$previous, esperado=$ExpectedPrevious"
    }
  }
}

function Assert-BridgeSnapshotPreserved {
  param(
    [string]$BridgePath,
    [string]$SnapshotDate,
    [string]$ExpectedSnapshotJson
  )

  $actualSnapshotJson = Get-BridgeSnapshotJson -BridgePath $BridgePath -SnapshotDate $SnapshotDate
  if ($actualSnapshotJson -ne $ExpectedSnapshotJson) {
    throw "Bridge invalido: el snapshot historico $SnapshotDate cambio en $BridgePath"
  }
}

Set-Location $repo
Assert-CleanWorktree

$seedDate = Get-RepoBaselineDate
$outputPaths = Get-RedditRunOutputPaths -SeedDate $seedDate -SnapshotDate $utcDate
$outputSnapshot = New-RedditOutputSnapshot -ProjectRoot $repo -RelativePaths $outputPaths
$topicsBridgePath = Join-Path $repo "frontend\assets\data\reddit_temas_history.json"
$intersectionBridgePath = Join-Path $repo "frontend\assets\data\reddit_interseccion_history.json"

$env:ETL_REFERENCE_DATE_UTC = $utcDate
$env:DATA_WRITE_LEGACY_CSV = "1"
$env:DATA_WRITE_LATEST_CSV = "1"
$env:DATA_WRITE_HISTORY_CSV = "1"
$env:DATA_HISTORY_PARTITION_MODE = "day"
$env:REDDIT_SUBREDDIT_LIST = "webdev,programming,learnprogramming,Python,javascript,typescript,reactjs,node,devops,MachineLearning"
$env:REDDIT_SUBREDDIT = $env:REDDIT_SUBREDDIT_LIST
$env:REDDIT_LIMIT = "3000"
$env:REDDIT_PER_SUBREDDIT_LIMIT = "300"
$env:REDDIT_MIN_TOTAL_MENTIONS = "400"
$env:REDDIT_TARGET_TOTAL_MENTIONS = "900"
$env:REDDIT_RSS_FEED_DELAY_SECONDS = "2"
$env:REDDIT_SUBREDDIT_DELAY_SECONDS = "2"
$env:REDDIT_RSS_429_BACKOFF_SECONDS = "60"
$env:REDDIT_RSS_MAX_ATTEMPTS = "2"

try {
  Seed-HistoryFromRepoBaseline -SeedDate $seedDate | Out-Null
  Run-Step "hydrate aggregate history seed" @($py, "scripts\hydrate_aggregate_history_seed.py", "--project-root", ".")
  $baselineTopicsSnapshotJson = Get-BridgeSnapshotJson -BridgePath $topicsBridgePath -SnapshotDate $seedDate
  $baselineIntersectionSnapshotJson = Get-BridgeSnapshotJson -BridgePath $intersectionBridgePath -SnapshotDate $seedDate

  try {
    Run-Step "reddit_etl" @($py, "backend\reddit_etl.py")
  }
  catch {
    Write-Output "REDDIT_ETL_FAILED_ROLLBACK=1"
    Write-Output $_.Exception.Message
    throw
  }

  if (-not (Test-FreshRedditHistoryForDate -SnapshotDate $utcDate)) {
    Write-Output "NO_FRESH_REDDIT_DATA=1"
    Write-Output "Reddit ETL no genero history para $utcDate. Se restaura el repo y no se abre PR."
    Restore-RedditOutputSnapshot -Snapshot $outputSnapshot
    Assert-CleanWorktree
    exit 0
  }

  if (-not (Assert-RedditMentionCoverage)) {
    Restore-RedditOutputSnapshot -Snapshot $outputSnapshot
    Assert-CleanWorktree
    exit 0
  }

  Run-Step "trend_score" @($py, "backend\trend_score.py")
  Run-Step "sync_assets" @($py, "backend\sync_assets.py")
  Restore-RedditOutputSnapshotPaths -Snapshot $outputSnapshot -RelativePaths @(
    "frontend\assets\data\github_lenguajes_public.json",
    "frontend\assets\data\github_frameworks_history.json",
    "frontend\assets\data\github_correlacion_history.json",
    "frontend\assets\data\so_volumen_history.json",
    "frontend\assets\data\so_aceptacion_history.json",
    "frontend\assets\data\so_tendencias_history.json"
  )
  Run-Step "rebuild home highlights from final bridges" @($py, "backend\export_history_json.py", "--rebuild-home-from", "frontend\assets\data")
  Run-Step "validate_csv_contract" @($py, "backend\validate_csv_contract.py")
  Run-Step "check_frontend_assets" @($py, "scripts\check_frontend_assets.py", "--mode", "strict", "--root", ".")
  Run-Step "check_bridge_integrity" @($py, "scripts\check_bridge_integrity.py", "--project-root", ".", "--expect-previous-history", "1")

  Assert-BridgeDates -ExpectedLatest $utcDate -ExpectedPrevious $seedDate
  Assert-BridgeSnapshotPreserved -BridgePath $topicsBridgePath -SnapshotDate $seedDate -ExpectedSnapshotJson $baselineTopicsSnapshotJson
  Assert-BridgeSnapshotPreserved -BridgePath $intersectionBridgePath -SnapshotDate $seedDate -ExpectedSnapshotJson $baselineIntersectionSnapshotJson
}
catch {
  $failure = $_
  Write-Output "PREPUBLICATION_FAILED_ROLLBACK=1"
  Write-Output $failure.Exception.Message
  if (Test-Path -LiteralPath $outputSnapshot.BackupRoot -PathType Container) {
    Restore-RedditOutputSnapshot -Snapshot $outputSnapshot
  }
  Assert-CleanWorktree
  throw $failure
}

Remove-RedditOutputSnapshot -Snapshot $outputSnapshot

Run-Step "git checkout branch" @("git", "checkout", "-b", $branch)

$gitAddCommand = @("git", "add", "--") + $filesToStage
Run-Step "git add target files" $gitAddCommand

& git diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
  Run-Step "git checkout main after no-op" @("git", "checkout", "main")
  Run-Step "git delete empty branch" @("git", "branch", "-D", $branch)
  Write-Output "NO_REDDIT_BASELINE_CHANGES=1"
  exit 0
}

Run-Step "git commit" @("git", "commit", "-m", "chore(data): refresh reddit baseline $utcDate")
Run-Step "git push" @("git", "push", "-u", "origin", $branch)

$body = @"
## Summary
- refresh reddit baseline data for $utcDate
- preserve previous reddit snapshot from repo baseline ($seedDate)
- prepare reddit fallback data before the weekly ETL

## Validation
- reddit_etl.py
- validate_csv_contract.py
- trend_score.py
- sync_assets.py
- check_frontend_assets.py --mode strict --root .
- check_bridge_integrity.py --project-root . --expect-previous-history 1
"@

$prUrl = gh pr create --base main --head $branch --title "chore(data): refresh reddit baseline $utcDate" --body $body
if ($LASTEXITCODE -ne 0) {
  throw "gh pr create failed with exit code $LASTEXITCODE"
}

Run-Step "git checkout main after publication" @("git", "checkout", "main")
Write-Output "PR_URL=$prUrl"
