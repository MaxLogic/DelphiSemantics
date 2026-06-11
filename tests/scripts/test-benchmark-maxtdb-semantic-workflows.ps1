[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$BenchmarkScript = Join-Path $RepoRoot 'scripts\benchmark-maxtdb-semantic-workflows.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\benchmark-script-tests'

function New-TestWorkspace {
  param([string]$Name)

  $lPath = Join-Path $TempRoot $Name
  if (Test-Path -LiteralPath $lPath) {
    Remove-Item -LiteralPath $lPath -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $lPath | Out-Null
  Set-Content -LiteralPath (Join-Path $lPath 'dak.exe') -Value '' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lPath 'project.dpr') -Value 'program project;' -Encoding UTF8
  return $lPath
}

function New-PlanJson {
  param(
    [string]$Path,
    [int]$WithCount,
    [int]$PlannedCount,
    [int]$MismatchCount,
    [switch]$OmitMismatchCount
  )

  $lParity = [ordered]@{
    status = if ($MismatchCount -eq 0) { 'passed' } else { 'failed' }
    summaryText = 'test parity'
    mismatches = @()
  }
  if (-not $OmitMismatchCount) {
    $lParity.mismatchCount = $MismatchCount
  }

  $lJson = [ordered]@{
    operation = 'remove-with'
    mode = 'plan'
    summary = [ordered]@{
      withStatements = $WithCount
      plannedEdits = $PlannedCount
    }
    withStatements = @()
    plannedEdits = @()
    semanticDtoParity = $lParity
    plannerPhaseMetrics = [ordered]@{
      totalMs = 1
    }
  }
  $lJson | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-ScanJson {
  param(
    [string]$Path,
    [int]$WithCount
  )

  $lJson = [ordered]@{
    operation = 'remove-with'
    mode = 'scan'
    summary = [ordered]@{
      withStatements = $WithCount
    }
    withStatements = @()
  }
  $lJson | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-BaselineJson {
  param(
    [string]$Path,
    [object[]]$Runs
  )

  $lBaseline = [ordered]@{
    name = 'test benchmark'
    startedAt = '2026-06-11T00:00:00.0000000+02:00'
    completedAt = '2026-06-11T00:00:01.0000000+02:00'
    elapsedSeconds = 1
    dakExe = 'dak.exe'
    project = 'project.dpr'
    repeat = $Runs.Count
    cacheModes = @('default')
    cacheDirectory = ''
    machine = 'test'
    results = @()
    runs = $Runs
  }
  $lBaseline | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-PlanRun {
  param(
    [string]$Stdout,
    [int]$Run,
    [string]$Id = 'remove-with-plan-all'
  )

  return [pscustomobject]@{
    Id = $Id
    Run = $Run
    Feature = 'with-removal'
    Description = if ($Id -eq 'remove-with-plan-all') {
      'Plan safe with-removal edits for all project units'
    } else {
      'Scan all project units for with statements'
    }
    CacheMode = 'default'
    CacheDirectory = ''
    Status = 'passed'
    ExitCode = 0
    ElapsedSeconds = 1
    ResultCount = ''
    SemanticCacheHits = ''
    SemanticCacheMisses = ''
    ReferenceFallbackCount = ''
    SemanticPhaseMetrics = $null
    PlannerPhaseMetrics = $null
    Stdout = $Stdout
    Stderr = ''
    Command = 'dak remove-with'
  }
}

function Invoke-BenchmarkSummarize {
  param([string]$Workspace)

  $lDakExe = Join-Path $Workspace 'dak.exe'
  $lProject = Join-Path $Workspace 'project.dpr'
  $lStdout = Join-Path $Workspace 'summarize.stdout.txt'
  $lStderr = Join-Path $Workspace 'summarize.stderr.txt'
  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe $lDakExe -Project $lProject -SummarizeOnly -OutDir $Workspace -NoBaselineCopy `
    1> $lStdout 2> $lStderr
  return $LASTEXITCODE
}

function Assert-Equal {
  param(
    [object]$Expected,
    [object]$Actual,
    [string]$Message
  )

  if ([string]$Expected -ne [string]$Actual) {
    throw "$Message Expected=[$Expected] Actual=[$Actual]"
  }
}

function Test-CompactPlanSummaryCountsDriveParityExport {
  $lWorkspace = New-TestWorkspace 'compact-summary-counts'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  Assert-Equal 0 $lExit 'SummarizeOnly should pass for compact plan output.'

  $lParity = Get-Content -LiteralPath (Join-Path $lWorkspace 'parity.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 667 $lParity.withStatementCount 'parity.json must use summary.withStatements.'
  Assert-Equal 215 $lParity.plannedEditCount 'parity.json must use summary.plannedEdits.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 215 $lBaseline.results[0].ResultCount 'summary result count must use compact summary plannedEdits.'
}

function Test-PlanRunCountDriftFailsClosed {
  $lWorkspace = New-TestWorkspace 'plan-count-drift'
  $lFirstPlanPath = Join-Path $lWorkspace 'plan-1.stdout.json'
  $lSecondPlanPath = Join-Path $lWorkspace 'plan-2.stdout.json'
  New-PlanJson -Path $lFirstPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0
  New-PlanJson -Path $lSecondPlanPath -WithCount 667 -PlannedCount 214 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lFirstPlanPath -Run 1),
    (New-PlanRun -Stdout $lSecondPlanPath -Run 2)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when any successful plan run drifts from 667/215/0.'
  }
}

function Test-SummaryCountDriftFailsClosed {
  $lWorkspace = New-TestWorkspace 'summary-count-drift'
  $lFirstScanPath = Join-Path $lWorkspace 'scan-1.stdout.json'
  $lSecondScanPath = Join-Path $lWorkspace 'scan-2.stdout.json'
  New-ScanJson -Path $lFirstScanPath -WithCount 667
  New-ScanJson -Path $lSecondScanPath -WithCount 666
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lFirstScanPath -Run 1 -Id 'remove-with-scan-all'),
    (New-PlanRun -Stdout $lSecondScanPath -Run 2 -Id 'remove-with-scan-all')
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when grouped successful result counts drift.'
  }
}

function Test-PlanRunMissingStdoutFailsClosed {
  $lWorkspace = New-TestWorkspace 'missing-plan-stdout'
  $lMissingPlanPath = Join-Path $lWorkspace 'missing-plan.stdout.json'
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lMissingPlanPath -Run 1)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when a successful plan run has missing stdout.'
  }
}

function Test-PlanRunMissingMismatchCountFailsClosed {
  $lWorkspace = New-TestWorkspace 'missing-mismatch-count'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0 `
    -OmitMismatchCount
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when semanticDtoParity.mismatchCount is missing.'
  }
}

$lTests = @(
  'Test-CompactPlanSummaryCountsDriveParityExport',
  'Test-PlanRunCountDriftFailsClosed',
  'Test-SummaryCountDriftFailsClosed',
  'Test-PlanRunMissingStdoutFailsClosed',
  'Test-PlanRunMissingMismatchCountFailsClosed'
)
$lFailures = New-Object System.Collections.Generic.List[string]
foreach ($lTest in $lTests) {
  try {
    & $lTest
    Write-Host "PASS $lTest"
  } catch {
    $lFailures.Add("FAIL ${lTest}: $($_.Exception.Message)")
    Write-Host "FAIL ${lTest}: $($_.Exception.Message)"
  }
}

if ($lFailures.Count -gt 0) {
  exit 1
}
