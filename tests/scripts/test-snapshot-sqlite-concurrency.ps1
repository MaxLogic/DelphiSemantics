[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$TestExe = Join-Path $RepoRoot 'tests\bin\delphiSemanticsSqliteTests.exe'
$TempRoot = Join-Path $RepoRoot ("tests\bin\snapshot-sqlite-concurrency-script-{0}-{1}" -f `
  $PID, [guid]::NewGuid().ToString('N'))

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

function Invoke-UnitCacheHarnessProcess {
  param(
    [hashtable]$Environment
  )

  $lStartInfo = [System.Diagnostics.ProcessStartInfo]::new()
  $lStartInfo.FileName = $TestExe
  $lStartInfo.WorkingDirectory = $RepoRoot
  $lStartInfo.UseShellExecute = $false
  $lStartInfo.ArgumentList.Add('--hidebanner') | Out-Null
  $lStartInfo.ArgumentList.Add('--consolemode:quiet') | Out-Null
  $lStartInfo.ArgumentList.Add('-r:Test.CacheSqlite.TCacheSqliteTests.UnitCacheSqliteConcurrencyHarness') | Out-Null

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

function Initialize-UnitCacheScenario {
  param([string]$Name)

  $lPath = Join-Path $TempRoot $Name
  if (Test-Path -LiteralPath $lPath) {
    Remove-Item -LiteralPath $lPath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $lPath | Out-Null
  return $lPath
}

function Write-UnitCacheSource {
  param(
    [string]$Path,
    [string]$UnitName,
    [string]$TypeName
  )

  Set-Content -LiteralPath $Path -Encoding UTF8 -Value @"
unit $UnitName;
interface
type
  $TypeName = class end;
implementation
end.
"@
}

function Invoke-UnitCacheHolderProcess {
  param(
    [string]$CacheFile,
    [string]$ReadyFile,
    [string]$ReleaseFile,
    [switch]$ColdDatabase
  )

  return Invoke-UnitCacheHarnessProcess @{
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_ROLE = if ($ColdDatabase) { 'cold-holder' } else { 'holder' }
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CACHE = $CacheFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_READY = $ReadyFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_RELEASE = $ReleaseFile
  }
}

function Invoke-UnitCacheSourceProcess {
  param(
    [string]$Role,
    [string]$CacheFile,
    [string]$SourceFile,
    [string]$ExpectedTypeName,
    [string]$ReadyFile,
    [string]$StartFile,
    [string]$AttemptFile,
    [string]$ProceedFile,
    [int]$BusyTimeoutMs = 0,
    [switch]$ExpectInvalidation,
    [switch]$ExpectContention
  )

  return Invoke-UnitCacheHarnessProcess @{
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_ROLE = $Role
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CACHE = $CacheFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_SOURCE = $SourceFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECTED_TYPE = $ExpectedTypeName
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_READY = $ReadyFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_START = $StartFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_ATTEMPT = $AttemptFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_PROCEED = $ProceedFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_INVALIDATION = if ($ExpectInvalidation) { '1' } else { '0' }
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_CONTENTION = if ($ExpectContention) { '1' } else { '0' }
    DELPHI_SEMANTICS_TEST_UNIT_CACHE_BUSY_TIMEOUT_MS = if ($BusyTimeoutMs -gt 0) { [string]$BusyTimeoutMs } else { '' }
  }
}

function Invoke-UnitCacheCorruptEntry {
  param(
    [string]$CacheFile,
    [string]$Name
  )

  $lCorruptor = Invoke-UnitCacheHarnessProcess @{
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_ROLE = 'corrupt-entry'
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CACHE = $CacheFile
  }
  Wait-HarnessProcess -Process $lCorruptor -Name $Name -TimeoutMs 20000
}

function Invoke-UnitCacheVerifier {
  param(
    [string]$CacheFile,
    [string[]]$ExpectedSources,
    [string]$Name,
    [switch]$ExpectHolderSentinel,
    [switch]$ExpectColdHolderSentinel
  )

  $lVerifier = Invoke-UnitCacheHarnessProcess @{
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_ROLE = 'verify'
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CACHE = $CacheFile
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECTED_SOURCES = ($ExpectedSources -join ';')
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_HOLDER_SENTINEL = if ($ExpectHolderSentinel) { '1' } else { '0' }
    DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_COLD_HOLDER_SENTINEL = if ($ExpectColdHolderSentinel) { '1' } else { '0' }
  }
  Wait-HarnessProcess -Process $lVerifier -Name $Name -TimeoutMs 20000
}

function Invoke-UnitCacheWarmHitCheck {
  param(
    [string]$CacheFile,
    [string]$SourceFile,
    [string]$ExpectedTypeName,
    [string]$Name
  )

  $lReader = Invoke-UnitCacheSourceProcess -Role reader -CacheFile $CacheFile `
    -SourceFile $SourceFile -ExpectedTypeName $ExpectedTypeName
  Wait-HarnessProcess -Process $lReader -Name $Name -TimeoutMs 20000
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

function Test-UnitCacheSqliteConcurrentColdWriterPairPreservesCache {
  Assert-True (Test-Path -LiteralPath $TestExe) `
    "Expected DelphiSemantics SQLite test executable at $TestExe."

  $lWorkspace = Initialize-UnitCacheScenario 'unit-cold-writers'
  $lCacheFile = Join-Path $lWorkspace 'shared-unit-cache.sqlite3'
  $lSourceA = Join-Path $lWorkspace 'ConcurrentColdA.pas'
  $lSourceB = Join-Path $lWorkspace 'ConcurrentColdB.pas'
  $lReadyFile = Join-Path $lWorkspace 'holder.ready'
  $lReleaseFile = Join-Path $lWorkspace 'holder.release'
  $lStartFile = Join-Path $lWorkspace 'children.start'
  $lWriterReadyA = Join-Path $lWorkspace 'writer-a.ready'
  $lWriterReadyB = Join-Path $lWorkspace 'writer-b.ready'
  $lWriterAttemptA = Join-Path $lWorkspace 'writer-a.attempt'
  $lWriterAttemptB = Join-Path $lWorkspace 'writer-b.attempt'
  Write-UnitCacheSource -Path $lSourceA -UnitName 'ConcurrentColdA' -TypeName 'TConcurrentColdA'
  Write-UnitCacheSource -Path $lSourceB -UnitName 'ConcurrentColdB' -TypeName 'TConcurrentColdB'
  $lHolder = $null
  $lWriters = @()

  try {
    $lHolder = Invoke-UnitCacheHolderProcess -CacheFile $lCacheFile -ReadyFile $lReadyFile `
      -ReleaseFile $lReleaseFile
    Wait-ForFile -Path $lReadyFile -TimeoutMs 15000
    $lWriters += Invoke-UnitCacheSourceProcess -Role writer -CacheFile $lCacheFile `
      -SourceFile $lSourceA -ExpectedTypeName 'TConcurrentColdA' `
      -ReadyFile $lWriterReadyA -StartFile $lStartFile -AttemptFile $lWriterAttemptA `
      -ExpectContention
    $lWriters += Invoke-UnitCacheSourceProcess -Role writer -CacheFile $lCacheFile `
      -SourceFile $lSourceB -ExpectedTypeName 'TConcurrentColdB' `
      -ReadyFile $lWriterReadyB -StartFile $lStartFile -AttemptFile $lWriterAttemptB `
      -ExpectContention

    Wait-ForFile -Path $lWriterReadyA -TimeoutMs 15000
    Wait-ForFile -Path $lWriterReadyB -TimeoutMs 15000
    Set-Content -LiteralPath $lStartFile -Value 'start' -Encoding UTF8
    Wait-ForFile -Path $lWriterAttemptA -TimeoutMs 15000
    Wait-ForFile -Path $lWriterAttemptB -TimeoutMs 15000
    Start-Sleep -Milliseconds 750
    Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    Wait-HarnessProcess -Process $lHolder -Name 'unit-cache lock holder' -TimeoutMs 20000
    foreach ($lWriter in $lWriters) {
      Wait-HarnessProcess -Process $lWriter -Name 'cold unit-cache writer' -TimeoutMs 20000
    }
    Invoke-UnitCacheVerifier -CacheFile $lCacheFile -ExpectedSources @($lSourceA, $lSourceB) `
      -Name 'cold-writer unit-cache verifier' -ExpectHolderSentinel
    Invoke-UnitCacheWarmHitCheck -CacheFile $lCacheFile -SourceFile $lSourceA `
      -ExpectedTypeName 'TConcurrentColdA' -Name 'cold-writer A warm reload'
    Invoke-UnitCacheWarmHitCheck -CacheFile $lCacheFile -SourceFile $lSourceB `
      -ExpectedTypeName 'TConcurrentColdB' -Name 'cold-writer B warm reload'
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

function Test-UnitCacheSqliteReaderWriterPairSurvivesPartialInvalidation {
  $lWorkspace = Initialize-UnitCacheScenario 'unit-reader-writer'
  $lCacheFile = Join-Path $lWorkspace 'shared-unit-cache.sqlite3'
  $lSourceA = Join-Path $lWorkspace 'ConcurrentChangedA.pas'
  $lSourceB = Join-Path $lWorkspace 'ConcurrentUnchangedB.pas'
  $lReadyFile = Join-Path $lWorkspace 'holder.ready'
  $lReleaseFile = Join-Path $lWorkspace 'holder.release'
  $lStartFile = Join-Path $lWorkspace 'children.start'
  $lWriterReadyFile = Join-Path $lWorkspace 'writer.ready'
  $lWriterAttemptFile = Join-Path $lWorkspace 'writer.attempt'
  $lReaderReadyFile = Join-Path $lWorkspace 'reader.ready'
  $lReaderAttemptFile = Join-Path $lWorkspace 'reader.attempt'
  Write-UnitCacheSource -Path $lSourceA -UnitName 'ConcurrentChangedA' -TypeName 'TBeforeChange'
  Write-UnitCacheSource -Path $lSourceB -UnitName 'ConcurrentUnchangedB' -TypeName 'TUnchanged'

  $lSeed = Invoke-UnitCacheSourceProcess -Role seed -CacheFile $lCacheFile `
    -SourceFile $lSourceA -ExpectedTypeName 'TBeforeChange'
  Wait-HarnessProcess -Process $lSeed -Name 'changed unit-cache seed' -TimeoutMs 20000
  $lSeed = Invoke-UnitCacheSourceProcess -Role seed -CacheFile $lCacheFile `
    -SourceFile $lSourceB -ExpectedTypeName 'TUnchanged'
  Wait-HarnessProcess -Process $lSeed -Name 'unchanged unit-cache seed' -TimeoutMs 20000
  Write-UnitCacheSource -Path $lSourceA -UnitName 'ConcurrentChangedA' -TypeName 'TAfterChange'

  $lHolder = $null
  $lWriter = $null
  $lReader = $null
  try {
    $lHolder = Invoke-UnitCacheHolderProcess -CacheFile $lCacheFile -ReadyFile $lReadyFile `
      -ReleaseFile $lReleaseFile
    Wait-ForFile -Path $lReadyFile -TimeoutMs 15000
    $lWriter = Invoke-UnitCacheSourceProcess -Role writer -CacheFile $lCacheFile `
      -SourceFile $lSourceA -ExpectedTypeName 'TAfterChange' `
      -ReadyFile $lWriterReadyFile -StartFile $lStartFile -AttemptFile $lWriterAttemptFile `
      -ExpectInvalidation -ExpectContention
    $lReader = Invoke-UnitCacheSourceProcess -Role reader -CacheFile $lCacheFile `
      -SourceFile $lSourceB -ExpectedTypeName 'TUnchanged' `
      -ReadyFile $lReaderReadyFile -StartFile $lStartFile -AttemptFile $lReaderAttemptFile

    Wait-ForFile -Path $lWriterReadyFile -TimeoutMs 15000
    Wait-ForFile -Path $lReaderReadyFile -TimeoutMs 15000
    Set-Content -LiteralPath $lStartFile -Value 'start' -Encoding UTF8
    Wait-ForFile -Path $lWriterAttemptFile -TimeoutMs 15000
    Wait-ForFile -Path $lReaderAttemptFile -TimeoutMs 15000
    Wait-HarnessProcess -Process $lReader -Name 'unchanged reader under writer lock' -TimeoutMs 5000
    Start-Sleep -Milliseconds 750
    Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    Wait-HarnessProcess -Process $lHolder -Name 'unit-cache lock holder' -TimeoutMs 20000
    Wait-HarnessProcess -Process $lWriter -Name 'invalidated unit-cache writer' -TimeoutMs 20000
    Invoke-UnitCacheVerifier -CacheFile $lCacheFile -ExpectedSources @($lSourceA, $lSourceB) `
      -Name 'reader-writer unit-cache verifier' -ExpectHolderSentinel
    Invoke-UnitCacheWarmHitCheck -CacheFile $lCacheFile -SourceFile $lSourceA `
      -ExpectedTypeName 'TAfterChange' -Name 'invalidated unit-cache warm reload'
  } finally {
    if (-not (Test-Path -LiteralPath $lReleaseFile)) {
      Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    }
    Close-HarnessProcess -Process $lHolder
    Close-HarnessProcess -Process $lWriter
    Close-HarnessProcess -Process $lReader
  }
}

function Test-UnitCacheSqliteWarmReaderPairReusesCache {
  $lWorkspace = Initialize-UnitCacheScenario 'unit-warm-readers'
  $lCacheFile = Join-Path $lWorkspace 'shared-unit-cache.sqlite3'
  $lSourceA = Join-Path $lWorkspace 'ConcurrentWarmA.pas'
  $lSourceB = Join-Path $lWorkspace 'ConcurrentWarmB.pas'
  $lStartFile = Join-Path $lWorkspace 'readers.start'
  $lProceedFile = Join-Path $lWorkspace 'readers.proceed'
  $lReaderReadyA = Join-Path $lWorkspace 'reader-a.ready'
  $lReaderReadyB = Join-Path $lWorkspace 'reader-b.ready'
  $lReaderAttemptA = Join-Path $lWorkspace 'reader-a.attempt'
  $lReaderAttemptB = Join-Path $lWorkspace 'reader-b.attempt'
  Write-UnitCacheSource -Path $lSourceA -UnitName 'ConcurrentWarmA' -TypeName 'TConcurrentWarmA'
  Write-UnitCacheSource -Path $lSourceB -UnitName 'ConcurrentWarmB' -TypeName 'TConcurrentWarmB'

  $lSeed = Invoke-UnitCacheSourceProcess -Role seed -CacheFile $lCacheFile `
    -SourceFile $lSourceA -ExpectedTypeName 'TConcurrentWarmA'
  Wait-HarnessProcess -Process $lSeed -Name 'warm A unit-cache seed' -TimeoutMs 20000
  $lSeed = Invoke-UnitCacheSourceProcess -Role seed -CacheFile $lCacheFile `
    -SourceFile $lSourceB -ExpectedTypeName 'TConcurrentWarmB'
  Wait-HarnessProcess -Process $lSeed -Name 'warm B unit-cache seed' -TimeoutMs 20000

  $lReaders = @(
    (Invoke-UnitCacheSourceProcess -Role reader -CacheFile $lCacheFile `
      -SourceFile $lSourceA -ExpectedTypeName 'TConcurrentWarmA' `
      -ReadyFile $lReaderReadyA -StartFile $lStartFile -AttemptFile $lReaderAttemptA `
      -ProceedFile $lProceedFile),
    (Invoke-UnitCacheSourceProcess -Role reader -CacheFile $lCacheFile `
      -SourceFile $lSourceB -ExpectedTypeName 'TConcurrentWarmB' `
      -ReadyFile $lReaderReadyB -StartFile $lStartFile -AttemptFile $lReaderAttemptB `
      -ProceedFile $lProceedFile)
  )
  try {
    Wait-ForFile -Path $lReaderReadyA -TimeoutMs 15000
    Wait-ForFile -Path $lReaderReadyB -TimeoutMs 15000
    Set-Content -LiteralPath $lStartFile -Value 'start' -Encoding UTF8
    Wait-ForFile -Path $lReaderAttemptA -TimeoutMs 15000
    Wait-ForFile -Path $lReaderAttemptB -TimeoutMs 15000
    Set-Content -LiteralPath $lProceedFile -Value 'proceed' -Encoding UTF8
    foreach ($lReader in $lReaders) {
      Wait-HarnessProcess -Process $lReader -Name 'warm unit-cache reader' -TimeoutMs 20000
    }
    Invoke-UnitCacheVerifier -CacheFile $lCacheFile -ExpectedSources @($lSourceA, $lSourceB) `
      -Name 'warm-reader unit-cache verifier'
  } finally {
    foreach ($lReader in $lReaders) {
      Close-HarnessProcess -Process $lReader
    }
  }
}

function Test-UnitCacheSqliteInvalidEntryCleanupContentionFallsBack {
  $lWorkspace = Initialize-UnitCacheScenario 'unit-invalid-entry-contention'
  $lCacheFile = Join-Path $lWorkspace 'shared-unit-cache.sqlite3'
  $lSource = Join-Path $lWorkspace 'ConcurrentInvalidEntry.pas'
  $lReadyFile = Join-Path $lWorkspace 'holder.ready'
  $lReleaseFile = Join-Path $lWorkspace 'holder.release'
  $lChildReadyFile = Join-Path $lWorkspace 'reader.ready'
  $lStartFile = Join-Path $lWorkspace 'reader.start'
  $lAttemptFile = Join-Path $lWorkspace 'reader.attempt'
  Write-UnitCacheSource -Path $lSource -UnitName 'ConcurrentInvalidEntry' `
    -TypeName 'TConcurrentInvalidEntry'

  $lSeed = Invoke-UnitCacheSourceProcess -Role seed -CacheFile $lCacheFile `
    -SourceFile $lSource -ExpectedTypeName 'TConcurrentInvalidEntry'
  Wait-HarnessProcess -Process $lSeed -Name 'invalid-entry unit-cache seed' -TimeoutMs 20000
  Invoke-UnitCacheCorruptEntry -CacheFile $lCacheFile -Name 'unit-cache entry corruptor'

  $lHolder = $null
  $lReader = $null
  try {
    $lHolder = Invoke-UnitCacheHolderProcess -CacheFile $lCacheFile -ReadyFile $lReadyFile `
      -ReleaseFile $lReleaseFile
    Wait-ForFile -Path $lReadyFile -TimeoutMs 15000
    $lReader = Invoke-UnitCacheSourceProcess -Role invalid-reader -CacheFile $lCacheFile `
      -SourceFile $lSource -ExpectedTypeName 'TConcurrentInvalidEntry' `
      -ReadyFile $lChildReadyFile -StartFile $lStartFile -AttemptFile $lAttemptFile `
      -BusyTimeoutMs 500
    Wait-ForFile -Path $lChildReadyFile -TimeoutMs 15000
    Set-Content -LiteralPath $lStartFile -Value 'start' -Encoding UTF8
    Wait-ForFile -Path $lAttemptFile -TimeoutMs 15000
    Wait-HarnessProcess -Process $lReader -Name 'contended invalid-entry reader' -TimeoutMs 5000

    Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    Wait-HarnessProcess -Process $lHolder -Name 'invalid-entry lock holder' -TimeoutMs 20000
    Invoke-UnitCacheVerifier -CacheFile $lCacheFile -ExpectedSources @($lSource) `
      -Name 'invalid-entry unit-cache verifier' -ExpectHolderSentinel
  } finally {
    if (-not (Test-Path -LiteralPath $lReleaseFile)) {
      Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    }
    Close-HarnessProcess -Process $lHolder
    Close-HarnessProcess -Process $lReader
  }
}

function Test-UnitCacheSqliteTimeoutFallsBackWithoutRebuild {
  $lWorkspace = Initialize-UnitCacheScenario 'unit-timeout-fallback'
  $lCacheFile = Join-Path $lWorkspace 'shared-unit-cache.sqlite3'
  $lReadyFile = Join-Path $lWorkspace 'holder.ready'
  $lReleaseFile = Join-Path $lWorkspace 'holder.release'
  $lChildReadyFile = Join-Path $lWorkspace 'child.ready'
  $lStartFile = Join-Path $lWorkspace 'child.start'
  $lAttemptFile = Join-Path $lWorkspace 'child.attempt'
  $lHolder = $null
  $lTimeoutOpen = $null

  try {
    $lHolder = Invoke-UnitCacheHolderProcess -CacheFile $lCacheFile -ReadyFile $lReadyFile `
      -ReleaseFile $lReleaseFile -ColdDatabase
    Wait-ForFile -Path $lReadyFile -TimeoutMs 15000
    $lTimeoutOpen = Invoke-UnitCacheSourceProcess -Role timeout-open -CacheFile $lCacheFile `
      -ReadyFile $lChildReadyFile -StartFile $lStartFile -AttemptFile $lAttemptFile `
      -BusyTimeoutMs 500
    Wait-ForFile -Path $lChildReadyFile -TimeoutMs 15000
    Set-Content -LiteralPath $lStartFile -Value 'start' -Encoding UTF8
    Wait-ForFile -Path $lAttemptFile -TimeoutMs 15000
    Wait-HarnessProcess -Process $lTimeoutOpen -Name 'unit-cache timeout fallback' -TimeoutMs 5000

    Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    Wait-HarnessProcess -Process $lHolder -Name 'unit-cache timeout lock holder' -TimeoutMs 20000
    Invoke-UnitCacheVerifier -CacheFile $lCacheFile -ExpectedSources @() `
      -Name 'timeout unit-cache verifier' -ExpectColdHolderSentinel
  } finally {
    if (-not (Test-Path -LiteralPath $lReleaseFile)) {
      Set-Content -LiteralPath $lReleaseFile -Value 'release' -Encoding UTF8
    }
    Close-HarnessProcess -Process $lHolder
    Close-HarnessProcess -Process $lTimeoutOpen
  }
}

try {
  Invoke-ScriptTests
} finally {
  if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
  }
}
