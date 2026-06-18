[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$TestExe = Join-Path $RepoRoot 'tests\bin\delphiSemanticsTests.exe'
$TempRoot = Join-Path $RepoRoot 'tests\bin\snapshot-sqlite-concurrency-script'

. (Join-Path $ScriptRoot 'test-support.ps1')

function Invoke-HarnessProcess {
  param(
    [hashtable]$Environment
  )

  $lStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $lStartInfo.FileName = $TestExe
  $lStartInfo.WorkingDirectory = $RepoRoot
  $lStartInfo.UseShellExecute = $false
  $lStartInfo.ArgumentList.Add('--hidebanner') | Out-Null
  $lStartInfo.ArgumentList.Add('--consolemode:quiet') | Out-Null
  $lStartInfo.ArgumentList.Add('-r:Test.SnapshotSqlite.TSnapshotSqliteTests.SnapshotSqliteConcurrencyHarness') | Out-Null

  foreach ($lKey in $Environment.Keys) {
    $lStartInfo.Environment[$lKey] = [string]$Environment[$lKey]
  }

  return [System.Diagnostics.Process]::Start($lStartInfo)
}

function Wait-ForFile {
  param(
    [string]$Path,
    [int]$TimeoutMs
  )

  $lStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
  while (-not (Test-Path -LiteralPath $Path)) {
    if ($lStopwatch.ElapsedMilliseconds -gt $TimeoutMs) {
      throw "Timed out waiting for file: $Path"
    }
    Start-Sleep -Milliseconds 50
  }
}

function Wait-HarnessProcess {
  param(
    [System.Diagnostics.Process]$Process,
    [string]$Name,
    [int]$TimeoutMs
  )

  if (-not $Process.WaitForExit($TimeoutMs)) {
    try {
      $Process.Kill($true)
    } catch {
      $Process.Kill()
    }
    throw "Timed out waiting for $Name."
  }

  if ($Process.ExitCode -ne 0) {
    throw "$Name exited with code $($Process.ExitCode)."
  }
}

function Close-HarnessProcess {
  param(
    [AllowNull()][System.Diagnostics.Process]$Process
  )

  if ($null -eq $Process) {
    return
  }
  if ($Process.HasExited) {
    return
  }

  try {
    $Process.Kill($true)
  } catch {
    $Process.Kill()
  }
}

function Test-SnapshotSqliteConcurrentWritersWaitForSharedCache {
  Assert-True (Test-Path -LiteralPath $TestExe) `
    "Expected DelphiSemantics test executable at $TestExe."

  if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $TempRoot | Out-Null

  $lCacheFile = Join-Path $TempRoot 'shared-snapshot-cache.sqlite3'
  $lReadyFile = Join-Path $TempRoot 'holder.ready'
  $lReleaseFile = Join-Path $TempRoot 'holder.release'
  $lHolder = $null
  $lWriters = @()

  try {
    $lHolder = Invoke-HarnessProcess @{
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_ROLE = 'holder'
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_CACHE = $lCacheFile
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_READY = $lReadyFile
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_RELEASE = $lReleaseFile
    }
    Wait-ForFile -Path $lReadyFile -TimeoutMs 15000

    $lWriters += Invoke-HarnessProcess @{
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_ROLE = 'writer'
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_CACHE = $lCacheFile
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_IDENTITY = 'WriterA'
    }
    $lWriters += Invoke-HarnessProcess @{
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_ROLE = 'writer'
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_CACHE = $lCacheFile
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_IDENTITY = 'WriterB'
    }

    Start-Sleep -Milliseconds 500
    Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8

    Wait-HarnessProcess -Process $lHolder -Name 'lock holder' -TimeoutMs 20000
    foreach ($lWriter in $lWriters) {
      Wait-HarnessProcess -Process $lWriter -Name 'cache writer' -TimeoutMs 20000
    }

    $lVerifier = Invoke-HarnessProcess @{
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_ROLE = 'verify'
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_CACHE = $lCacheFile
      DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_IDENTITIES = 'WriterA;WriterB'
    }
    Wait-HarnessProcess -Process $lVerifier -Name 'cache verifier' -TimeoutMs 20000
  } finally {
    if (-not (Test-Path -LiteralPath $lReleaseFile)) {
      Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    }
    Close-HarnessProcess -Process $lHolder
    foreach ($lWriter in $lWriters) {
      Close-HarnessProcess -Process $lWriter
    }
  }
}

Invoke-ScriptTests
