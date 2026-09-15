param(
  [ValidateSet("scheduled", "logon", "manual")]
  [string]$Reason = "manual"
)

$ErrorActionPreference = "Stop"
if (Get-Variable PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
  $PSNativeCommandUseErrorActionPreference = $false
}

$repo = Split-Path -Parent $PSScriptRoot
$logsDir = Join-Path $repo "logs"
$logFile = Join-Path $logsDir "reddit_baseline_weekly.log"
$stateDir = Join-Path $repo "automation\state"
$stateFile = Join-Path $stateDir "reddit_baseline_last_window.txt"
$statusFile = Join-Path $stateDir "reddit_baseline_last_status.txt"
$mainScript = Join-Path $repo "automation\run_reddit_baseline.ps1"
$topicsBridgePath = Join-Path $repo "frontend\assets\data\reddit_temas_history.json"
$intersectionBridgePath = Join-Path $repo "frontend\assets\data\reddit_interseccion_history.json"

function Write-LockSkipLog {
  try {
    New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
    Add-Content -LiteralPath $logFile -Value "[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] SKIP_RUNNER_LOCKED=1" -Encoding UTF8
  }
  catch {
    # A collision must still skip safely when the canonical log is unavailable.
  }
}

$runnerLock = [System.Threading.Mutex]::new($false, "Global\TechnologyTrend-RedditBaselineWeekly")
$runnerLockAcquired = $false
try {
  try {
    $runnerLockAcquired = $runnerLock.WaitOne(0)
  }
  catch [System.Threading.AbandonedMutexException] {
    $runnerLockAcquired = $true
  }

  if (-not $runnerLockAcquired) {
    Write-Output "SKIP_RUNNER_LOCKED=1"
    Write-LockSkipLog
    exit 0
  }

New-Item -ItemType Directory -Force -Path $logsDir | Out-Null
New-Item -ItemType Directory -Force -Path $stateDir | Out-Null

function Write-Log {
  param([string]$Message)

  $timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
  Add-Content -Path $logFile -Value "[$timestamp] $Message" -Encoding UTF8
}

function Write-Status {
  param(
    [string]$Outcome,
    [string]$Message,
    [string]$WindowKey = "",
    [string]$PrUrl = ""
  )

  $lines = @(
    "timestamp_local=$((Get-Date).ToString("yyyy-MM-dd HH:mm:ss"))",
    "reason=$Reason",
    "outcome=$Outcome",
    "window_key=$WindowKey",
    "pr_url=$PrUrl",
    "message=$Message"
  )

  Set-Content -Path $statusFile -Value $lines -Encoding UTF8
}

function Get-EcuadorNow {
  $utcNow = (Get-Date).ToUniversalTime()
  foreach ($timezoneId in @("SA Pacific Standard Time", "America/Guayaquil")) {
    try {
      $tz = [System.TimeZoneInfo]::FindSystemTimeZoneById($timezoneId)
      return [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, $tz)
    }
    catch {
      continue
    }
  }

  return Get-Date
}

function Get-EligibleWindowKey {
  param([datetime]$NowEc)

  $sundayStart = [TimeSpan]::Parse("21:00:00")
  $mondayCutoff = [TimeSpan]::Parse("01:30:00")

  if ($NowEc.DayOfWeek -eq [DayOfWeek]::Sunday -and $NowEc.TimeOfDay -ge $sundayStart) {
    return $NowEc.Date.ToString("yyyy-MM-dd")
  }

  if ($NowEc.DayOfWeek -eq [DayOfWeek]::Monday -and $NowEc.TimeOfDay -lt $mondayCutoff) {
    return $NowEc.Date.AddDays(-1).ToString("yyyy-MM-dd")
  }

  return $null
}

function Send-BestEffortMessage {
  param(
    [string]$Title,
    [string]$Message,
    [ValidateSet("Info", "Warning", "Error")]
    [string]$Level = "Info"
  )

  $popupFlags = @{
    Info = 64
    Warning = 48
    Error = 16
  }

  try {
    $wshell = New-Object -ComObject WScript.Shell
    [void]$wshell.Popup($Message, 12, $Title, $popupFlags[$Level])
    Write-Log "popup shown title=$Title"
    return
  }
  catch {
    Write-Log "local popup unavailable: $($_.Exception.Message)"
  }

  try {
    & msg.exe $env:USERNAME "$Title`n$Message" | Out-Null
    Write-Log "msg.exe sent title=$Title"
  }
  catch {
    Write-Log "msg.exe unavailable or no active session"
  }
}

function Get-BridgeLatestDate {
  param([string]$Path)

  if (-not (Test-Path $Path)) {
    return $null
  }

  try {
    $payload = Get-Content $Path -Raw | ConvertFrom-Json
    return [string]$payload.latest_snapshot_date
  }
  catch {
    Write-Log "could not read latest_snapshot_date from $Path"
    return $null
  }
}

$ecuadorNow = Get-EcuadorNow
$windowKey = Get-EligibleWindowKey -NowEc $ecuadorNow
$formattedNow = $ecuadorNow.ToString("yyyy-MM-dd HH:mm:ss")

Write-Log "guard start reason=$Reason ecuador_now=$formattedNow window_key=$windowKey"

if (-not $windowKey) {
  Write-Output "SKIP_OUTSIDE_WINDOW=1"
  Write-Status -Outcome "skipped_outside_window" -Message "Outside the eligible window. The automation did not run."
  Write-Log "guard skip outside window"
  exit 0
}

if (Test-Path $stateFile) {
  $lastWindow = (Get-Content $stateFile -Raw).Trim()
  if ($lastWindow -eq $windowKey) {
    Write-Output "SKIP_ALREADY_RAN=$windowKey"
    Write-Status -Outcome "skipped_already_ran" -Message "The automation already ran in this weekly window." -WindowKey $windowKey
    Write-Log "guard skip already ran for $windowKey"
    exit 0
  }
}

$currentUtcDate = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$topicsLatest = Get-BridgeLatestDate -Path $topicsBridgePath
$intersectionLatest = Get-BridgeLatestDate -Path $intersectionBridgePath

if ($topicsLatest -eq $currentUtcDate -and $intersectionLatest -eq $currentUtcDate) {
  Set-Content -Path $stateFile -Value $windowKey -Encoding ASCII
  Write-Output "SKIP_ALREADY_UP_TO_DATE=$currentUtcDate"
  Write-Status -Outcome "skipped_up_to_date" -Message "The Reddit baseline was already up to date for $currentUtcDate. No PR was created." -WindowKey $windowKey
  Write-Log "guard skip main already up to date for utc_date=$currentUtcDate"
  Send-BestEffortMessage -Title "Reddit baseline unchanged" -Message "The Reddit baseline was already up to date for $currentUtcDate. No PR was created." -Level Info
  exit 0
}

Write-Host "==> guarded run reason=$Reason window=$windowKey"
Write-Log "guard executing main script for $windowKey"

$commandLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$mainScript`" 2>&1"
$runOutput = New-Object System.Collections.Generic.List[string]
& cmd.exe /d /c $commandLine | ForEach-Object {
  $line = [string]$_
  Add-Content -Path $logFile -Value $line -Encoding UTF8
  Write-Output $line
  $runOutput.Add($line)
}
$exitCode = $LASTEXITCODE

if ($exitCode -ne 0) {
  Write-Status -Outcome "failed" -Message "The automation failed. Check the local log." -WindowKey $windowKey
  Write-Log "guard failed exit_code=$exitCode"
  Send-BestEffortMessage -Title "Reddit baseline failed" -Message "The automation failed. Check the local log." -Level Error
  exit $exitCode
}

$prUrl = ""
foreach ($line in $runOutput) {
  if ($line -match "^PR_URL=(.+)$") {
    $prUrl = $Matches[1].Trim()
    break
  }
}

if ($runOutput -contains "NO_FRESH_REDDIT_DATA=1") {
  Write-Status -Outcome "no_fresh_reddit_data" -Message "Reddit produced no fresh data. No PR was created and the repository was restored." -WindowKey $windowKey
  Write-Log "guard no fresh reddit data window=$windowKey"
  Send-BestEffortMessage -Title "Reddit baseline has no fresh data" -Message "Reddit produced no fresh data. No PR was created. Check Reddit OAuth credentials." -Level Warning
  exit 0
}

if ($runOutput -contains "LOW_REDDIT_MENTIONS_ROLLBACK=1") {
  Set-Content -Path $stateFile -Value $windowKey -Encoding ASCII
  Write-Status -Outcome "low_reddit_mentions" -Message "Reddit produced fewer mentions than the minimum. No PR was created and the repository was restored." -WindowKey $windowKey
  Write-Log "guard low reddit mentions window=$windowKey"
  Send-BestEffortMessage -Title "Reddit baseline has low coverage" -Message "Reddit produced fewer mentions than the minimum. No PR was created." -Level Warning
  exit 0
}

Set-Content -Path $stateFile -Value $windowKey -Encoding ASCII
Write-Log "guard success window=$windowKey"

if ($prUrl) {
  Write-Status -Outcome "pr_created" -Message "The automation completed successfully and created a PR." -WindowKey $windowKey -PrUrl $prUrl
  Send-BestEffortMessage -Title "Reddit baseline complete" -Message "PR created: $prUrl" -Level Info
  exit 0
}

if ($runOutput -contains "NO_REDDIT_BASELINE_CHANGES=1") {
  Write-Status -Outcome "no_changes" -Message "The automation completed successfully, but there were no changes for a PR." -WindowKey $windowKey
  Send-BestEffortMessage -Title "Reddit baseline unchanged" -Message "The automation completed successfully, but there were no changes for a PR." -Level Info
  exit 0
}

Write-Status -Outcome "success_no_pr_marker" -Message "The automation completed successfully, but returned neither PR_URL nor a no-changes marker." -WindowKey $windowKey
Send-BestEffortMessage -Title "Reddit baseline complete" -Message "The automation completed successfully. Check the local log." -Level Warning
}
finally {
  if ($runnerLockAcquired) {
    $runnerLock.ReleaseMutex()
  }
  $runnerLock.Dispose()
}
