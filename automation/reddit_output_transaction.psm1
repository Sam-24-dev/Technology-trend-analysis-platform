Set-StrictMode -Version Latest

function Resolve-RedditOutputPath {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  if ([IO.Path]::IsPathRooted($RelativePath)) {
    throw "Output path must be relative: $RelativePath"
  }

  $root = [IO.Path]::GetFullPath($ProjectRoot).TrimEnd([IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
  $target = [IO.Path]::GetFullPath((Join-Path $root $RelativePath))
  $prefix = $root + [IO.Path]::DirectorySeparatorChar
  if (-not $target.StartsWith($prefix, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Output path escapes the project root: $RelativePath"
  }

  return $target
}

function Assert-RedditSnapshotRoot {
  param([Parameter(Mandatory = $true)]$Snapshot)

  $snapshotRoot = [IO.Path]::GetFullPath([string]$Snapshot.BackupRoot)
  $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
  if (-not $snapshotRoot.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Snapshot root is outside the system temp directory."
  }
  if (-not (Split-Path -Leaf $snapshotRoot).StartsWith("ttap-reddit-output-", [StringComparison]::OrdinalIgnoreCase)) {
    throw "Snapshot root has an unexpected name."
  }

  return $snapshotRoot
}

function New-RedditOutputSnapshot {
  param(
    [Parameter(Mandatory = $true)][string]$ProjectRoot,
    [Parameter(Mandatory = $true)][string[]]$RelativePaths
  )

  $backupRoot = Join-Path ([IO.Path]::GetTempPath()) ("ttap-reddit-output-" + [Guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $backupRoot | Out-Null

  try {
    $entries = @()
    $seen = @{}
    foreach ($relativePath in $RelativePaths) {
      $target = Resolve-RedditOutputPath -ProjectRoot $ProjectRoot -RelativePath $relativePath
      if ($seen.ContainsKey($target)) {
        continue
      }
      $seen[$target] = $true

      if ((Test-Path -LiteralPath $target) -and -not (Test-Path -LiteralPath $target -PathType Leaf)) {
        throw "Expected a file output but found another item type: $relativePath"
      }

      $existed = Test-Path -LiteralPath $target -PathType Leaf
      $backup = Join-Path $backupRoot ("{0:D4}.bin" -f $entries.Count)
      if ($existed) {
        Copy-Item -LiteralPath $target -Destination $backup
      }

      $entries += [PSCustomObject]@{
        Target = $target
        Existed = $existed
        Backup = $backup
      }
    }
  }
  catch {
    Remove-Item -LiteralPath $backupRoot -Recurse -Force
    throw
  }

  return [PSCustomObject]@{
    BackupRoot = $backupRoot
    Entries = $entries
  }
}

function Remove-RedditOutputSnapshot {
  param([Parameter(Mandatory = $true)]$Snapshot)

  $snapshotRoot = Assert-RedditSnapshotRoot -Snapshot $Snapshot
  if (Test-Path -LiteralPath $snapshotRoot -PathType Container) {
    Remove-Item -LiteralPath $snapshotRoot -Recurse -Force
  }
}

function Restore-RedditOutputSnapshot {
  param([Parameter(Mandatory = $true)]$Snapshot)

  Assert-RedditSnapshotRoot -Snapshot $Snapshot | Out-Null
  foreach ($entry in $Snapshot.Entries) {
    if ($entry.Existed) {
      $parent = Split-Path -Parent $entry.Target
      New-Item -ItemType Directory -Force -Path $parent | Out-Null
      Copy-Item -LiteralPath $entry.Backup -Destination $entry.Target -Force
    }
    elseif (Test-Path -LiteralPath $entry.Target -PathType Leaf) {
      Remove-Item -LiteralPath $entry.Target -Force
    }
    elseif (Test-Path -LiteralPath $entry.Target) {
      throw "Cannot restore file output because another item type exists: $($entry.Target)"
    }
  }

  Remove-RedditOutputSnapshot -Snapshot $Snapshot
}

Export-ModuleMember -Function New-RedditOutputSnapshot, Restore-RedditOutputSnapshot, Remove-RedditOutputSnapshot
