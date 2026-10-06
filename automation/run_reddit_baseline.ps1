param([string]$PreparedMainSha = "")
$ErrorActionPreference = "Stop"
$repo = Split-Path -Parent $PSScriptRoot
$py = Join-Path $repo ".venv311\Scripts\python.exe"
Import-Module (Join-Path $PSScriptRoot "reddit_output_transaction.psm1") -Force

$utcDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$branch = "reddit-source-$((Get-Date).ToUniversalTime().ToString('yyyyMMdd-HHmm'))"
$filesToStage = @(
  "datos/reddit_sentimiento_frameworks.csv",
  "datos/reddit_temas_emergentes.csv",
  "datos/source_packages/reddit/receipt.json"
)
$parts = $utcDate.Split("-")
$ignoredOutputs = @(
  "datos\latest\reddit_sentimiento_frameworks.csv",
  "datos\latest\reddit_temas_emergentes.csv",
  "datos\history\reddit_sentimiento\year=$($parts[0])\month=$($parts[1])\day=$($parts[2])\reddit_sentimiento_frameworks.csv",
  "datos\history\reddit_temas\year=$($parts[0])\month=$($parts[1])\day=$($parts[2])\reddit_temas_emergentes.csv"
)

function Run-Step {
  param([string]$Label, [string[]]$Command)
  Write-Host "==> $Label"
  & $Command[0] $Command[1..($Command.Length - 1)]
  if ($LASTEXITCODE -ne 0) { throw "$Label failed with exit code $LASTEXITCODE" }
}

function Assert-CleanWorktree {
  $status = @(git status --porcelain)
  if ($LASTEXITCODE -ne 0) { throw "git status failed" }
  $ignored = @(git status --porcelain --ignored --untracked-files=all -- datos/latest datos/history datos/metadata)
  if ($LASTEXITCODE -ne 0) { throw "git ignored-output status failed" }
  $ignored = @($ignored | Where-Object { $_.StartsWith("!! ") })
  if ($status.Count -gt 0 -or $ignored.Count -gt 0) { throw "Pre-existing changes or ignored outputs; refusing to touch them." }
  $currentBranch = (git branch --show-current).Trim()
  if ($LASTEXITCODE -ne 0 -or $currentBranch -ne "main") { throw "The automation requires clean main: $currentBranch" }
}

function Assert-PreparedMainSha {
  if ($PreparedMainSha -notmatch '^[0-9a-f]{40}$') { throw "Missing or invalid prepared main SHA" }
  $head = (git rev-parse HEAD).Trim()
  if ($LASTEXITCODE -ne 0 -or $head -ne $PreparedMainSha) { throw "HEAD differs from prepared main SHA" }
  $currentBranch = (git branch --show-current).Trim()
  if ($LASTEXITCODE -ne 0 -or $currentBranch -ne "main") { throw "Prepared producer requires main" }
}

function Get-TopicMentions {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Missing Reddit topics CSV: $Path" }
  $rows = @(Import-Csv -LiteralPath $Path)
  if ($rows.Count -eq 0) { throw "Empty Reddit topics CSV: $Path" }
  $total = 0
  foreach ($row in $rows) {
    $count = 0
    if (-not [int]::TryParse([string]$row.menciones, [ref]$count) -or $count -le 0) { throw "Invalid Reddit topic count" }
    $total += $count
  }
  return $total
}

function Assert-RedditSourcePackage {
  param([int]$BaselineMentions)
  $receiptPath = Join-Path $repo $filesToStage[2]
  if (-not (Test-Path -LiteralPath $receiptPath -PathType Leaf)) { throw "Missing Reddit receipt" }
  $receipt = Get-Content -LiteralPath $receiptPath -Raw | ConvertFrom-Json
  if ($receipt.source -ne "reddit" -or $receipt.source_date_utc -ne $utcDate -or
      $receipt.reference_date_utc -ne $utcDate -or
      $receipt.posts_count -le 0 -or $receipt.scope.Count -ne 10) { throw "Invalid Reddit receipt source, scope or UTC date" }
  $started = [datetimeoffset]::Parse([string]$receipt.extraction_started_at_utc)
  $finished = [datetimeoffset]::Parse([string]$receipt.extraction_finished_at_utc)
  if ($started.Offset -ne [timespan]::Zero -or $finished.Offset -ne [timespan]::Zero -or
      $started.UtcDateTime.Date -ne $finished.UtcDateTime.Date -or
      $started.UtcDateTime.ToString("yyyy-MM-dd") -ne $utcDate -or $finished -lt $started) {
    throw "Reddit extraction disagreed with the UTC reference date"
  }
  foreach ($name in @("reddit_sentimiento_frameworks.csv", "reddit_temas_emergentes.csv")) {
    $rootPath = Join-Path $repo "datos\$name"
    $latestPath = Join-Path $repo "datos\latest\$name"
    $dataset = if ($name.StartsWith("reddit_sentimiento")) { "reddit_sentimiento" } else { "reddit_temas" }
    $historyPath = Join-Path $repo "datos\history\$dataset\year=$($parts[0])\month=$($parts[1])\day=$($parts[2])\$name"
    $expectedHash = [string]$receipt.outputs.$name.sha256
    if ($expectedHash -notmatch '^[0-9a-f]{64}$') { throw "Missing Reddit output hash: $name" }
    foreach ($path in @($rootPath, $latestPath, $historyPath)) {
      if (-not (Test-Path -LiteralPath $path -PathType Leaf) -or
          (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expectedHash) {
        throw "Reddit output copy mismatch: $name"
      }
    }
  }
  $mentions = Get-TopicMentions -Path (Join-Path $repo $filesToStage[1])
  if ($mentions -ne $receipt.outputs.'reddit_temas_emergentes.csv'.mentions_total -or
      $mentions -lt 400 -or $mentions -lt [math]::Ceiling($BaselineMentions * 0.85)) {
    throw "Reddit coverage below 400 mentions or 85 percent of baseline"
  }
}

function Invoke-SourcePublication {
  param([Parameter(Mandatory = $true)]$Snapshot)
  try {
    Assert-PreparedMainSha
    Run-Step "git checkout branch" @("git", "checkout", "-b", $branch)
    Run-Step "git add target files" (@("git", "add", "--") + $filesToStage)
    Run-Step "git commit" @("git", "commit", "-m", "chore(data): refresh reddit source package $utcDate")
    Run-Step "git push" @("git", "push", "-u", "origin", $branch)
    $body = @"
## Summary
- Refresh aggregated Reddit sentiment and topics for $utcDate.
- Include the source extraction window, scope, counts and exact CSV hashes.
- No cross-source or public frontend assets are changed.

## Validation
- Reddit source extraction completed for all ten configured subreddits.
- UTC date, output-copy integrity and minimum 85% baseline mention coverage passed.
"@
    $prUrl = gh pr create --base main --head $branch --title "chore(data): refresh reddit source package $utcDate" --body $body
    if ($LASTEXITCODE -ne 0) { throw "gh pr create failed with exit code $LASTEXITCODE" }
    Run-Step "git checkout main after PR" @("git", "checkout", "main")
    Remove-RedditOutputSnapshot -Snapshot $Snapshot
    return $prUrl
  }
  catch {
    $failure = $_
    Write-Output "REDDIT_SOURCE_PUBLICATION_FAILED=1"
    Write-Output "Git state was not rolled back; inspect branch, index, local commits and remote branch before retrying."
    try {
      if (-not (Test-Path -LiteralPath $Snapshot.BackupRoot -PathType Container)) { throw "Reddit output snapshot is missing" }
      Restore-RedditOutputSnapshot -Snapshot $Snapshot
      Write-Output "REDDIT_SOURCE_LOCAL_FILES_RESTORED=1"
    }
    catch {
      Write-Output "REDDIT_SOURCE_LOCAL_FILE_RESTORE_FAILED=1"
      throw "Publication failed: $($failure.Exception.Message); local file restore failed: $($_.Exception.Message)"
    }
    throw $failure
  }
}

Set-Location $repo
Assert-CleanWorktree
Assert-PreparedMainSha
$baselineMentions = Get-TopicMentions -Path (Join-Path $repo $filesToStage[1])
$outputSnapshot = New-RedditOutputSnapshot -ProjectRoot $repo -RelativePaths ($filesToStage + $ignoredOutputs)
$env:ETL_REFERENCE_DATE_UTC = $utcDate
$env:PYTHONDONTWRITEBYTECODE = "1"
$env:DATA_WRITE_LEGACY_CSV = "1"
$env:DATA_WRITE_LATEST_CSV = "1"
$env:DATA_WRITE_HISTORY_CSV = "1"
$env:DATA_HISTORY_PARTITION_MODE = "day"
$env:REDDIT_SUBREDDIT_LIST = "webdev,programming,learnprogramming,Python,javascript,typescript,reactjs,node,devops,MachineLearning"
$env:REDDIT_SUBREDDIT = $env:REDDIT_SUBREDDIT_LIST
$env:REDDIT_LIMIT = "3000"
$env:REDDIT_PER_SUBREDDIT_LIMIT = "300"
$env:REDDIT_RSS_FEED_DELAY_SECONDS = "2"
$env:REDDIT_SUBREDDIT_DELAY_SECONDS = "2"
$env:REDDIT_RSS_429_BACKOFF_SECONDS = "60"
$env:REDDIT_RSS_MAX_ATTEMPTS = "2"

try {
  Run-Step "reddit source extraction" @($py, "backend\reddit_etl.py", "--source-package")
  Assert-RedditSourcePackage -BaselineMentions $baselineMentions
  Restore-RedditOutputSnapshotPaths -Snapshot $outputSnapshot -RelativePaths $ignoredOutputs
}
catch {
  $failure = $_
  Write-Output "REDDIT_SOURCE_PACKAGE_FAILED_ROLLBACK=1"
  if (Test-Path -LiteralPath $outputSnapshot.BackupRoot -PathType Container) { Restore-RedditOutputSnapshot -Snapshot $outputSnapshot }
  Assert-CleanWorktree
  throw $failure
}

$prUrl = Invoke-SourcePublication -Snapshot $outputSnapshot
Write-Output "PR_URL=$prUrl"
