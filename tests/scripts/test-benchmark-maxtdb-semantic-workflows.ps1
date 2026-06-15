[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$BenchmarkScript = Join-Path $RepoRoot 'scripts\benchmark-maxtdb-semantic-workflows.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\benchmark-script-tests'

. (Join-Path $ScriptRoot 'test-support.ps1')

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

function New-MutatingDakScript {
  param(
    [string]$Path,
    [string]$SourceFile
  )

  $lScript = @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Arguments)
Add-Content -LiteralPath '$SourceFile' -Value '// mutated by fake DAK'
`$lModeIndex = [Array]::IndexOf(`$Arguments, '--mode')
`$lMode = if (`$lModeIndex -ge 0) { `$Arguments[`$lModeIndex + 1] } else { 'scan' }
if (`$lMode -eq 'plan') {
  [ordered]@{
    operation = 'remove-with'
    mode = 'plan'
    summary = [ordered]@{ withStatements = 667; plannedEdits = 215 }
    withStatements = @()
    plannedEdits = @()
    semanticDtoParity = [ordered]@{
      status = 'passed'
      mismatchCount = 0
      summaryText = 'test parity'
      mismatches = @()
    }
    plannerPhaseMetrics = [ordered]@{ totalMs = 1 }
  } | ConvertTo-Json -Depth 8
} else {
  [ordered]@{
    operation = 'remove-with'
    mode = 'scan'
    summary = [ordered]@{ withStatements = 667 }
    withStatements = @()
  } | ConvertTo-Json -Depth 8
}
exit 0
"@
  Set-Content -LiteralPath $Path -Value $lScript -Encoding UTF8
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
    [object[]]$Runs,
    [string]$DelphiSemanticsSha = '',
    [string]$DakSha = ''
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
    delphiSemanticsSha = $DelphiSemanticsSha
    dakSha = $DakSha
    results = @()
    runs = $Runs
  }
  $lBaseline | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-PlanRun {
  param(
    [string]$Stdout,
    [int]$Run,
    [string]$Id = 'remove-with-plan-all',
    [switch]$OmitSourceMutationStatus
  )

  $lRun = [pscustomobject]@{
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
  if (-not $OmitSourceMutationStatus) {
    Add-Member -InputObject $lRun -NotePropertyName SourceMutationStatus `
      -NotePropertyValue 'clean'
  }
  return $lRun
}

function Invoke-BenchmarkSummarize {
  param(
    [string]$Workspace,
    [switch]$AllowHistoricalSummary
  )

  $lDakExe = Join-Path $Workspace 'dak.exe'
  $lProject = Join-Path $Workspace 'project.dpr'
  $lStdout = Join-Path $Workspace 'summarize.stdout.txt'
  $lStderr = Join-Path $Workspace 'summarize.stderr.txt'
  $lArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', $BenchmarkScript,
    '-DakExe', $lDakExe,
    '-Project', $lProject,
    '-SummarizeOnly',
    '-OutDir', $Workspace,
    '-NoBaselineCopy'
  )
  if ($AllowHistoricalSummary) {
    $lArgs += '-AllowHistoricalSummary'
  }
  & pwsh @lArgs 1> $lStdout 2> $lStderr
  return $LASTEXITCODE
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
  Assert-Equal 'current' $lBaseline.provenance.status `
    'SummarizeOnly with matching current provenance must mark current status.'

  $lMarkdown = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.md') -Raw
  if ($lMarkdown -notmatch 'Provenance: `current`') {
    throw 'Markdown summary must mark current provenance.'
  }
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

function Test-SummarizeOnlyMissingSourceMutationStatusFailsClosed {
  $lWorkspace = New-TestWorkspace 'missing-source-mutation-status'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1 -OmitSourceMutationStatus)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when a successful run is missing SourceMutationStatus.'
  }
  $lStderr = Get-Content -LiteralPath (Join-Path $lWorkspace 'summarize.stderr.txt') -Raw
  if ($lStderr -notmatch 'SourceMutationStatus') {
    throw 'SummarizeOnly missing mutation-status failure must name SourceMutationStatus.'
  }
}

function Test-SummarizeOnlyStaleProvenanceFailsClosed {
  $lWorkspace = New-TestWorkspace 'stale-provenance'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  ) -DelphiSemanticsSha 'stale-delphi-semantics-sha'

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when stored DelphiSemantics provenance is stale.'
  }
  $lStderr = Get-Content -LiteralPath (Join-Path $lWorkspace 'summarize.stderr.txt') -Raw
  if ($lStderr -notmatch 'provenance is stale') {
    throw 'SummarizeOnly stale-provenance failure must name stale provenance.'
  }
}

function Test-SummarizeOnlyStaleDakProvenanceFailsClosed {
  $lWorkspace = New-TestWorkspace 'stale-dak-provenance'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  ) -DakSha 'stale-dak-sha'

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when stored DAK provenance is stale.'
  }
  $lStderr = Get-Content -LiteralPath (Join-Path $lWorkspace 'summarize.stderr.txt') -Raw
  if ($lStderr -notmatch 'DAK stored=stale-dak-sha') {
    throw 'SummarizeOnly stale DAK provenance failure must name stored DAK SHA.'
  }
}

function Test-SummarizeOnlyAllowsHistoricalProvenanceWhenExplicit {
  $lWorkspace = New-TestWorkspace 'historical-provenance'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  ) -DelphiSemanticsSha 'stale-delphi-semantics-sha'

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace -AllowHistoricalSummary
  Assert-Equal 0 $lExit 'SummarizeOnly should allow stale provenance only when explicit.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 'historical' $lBaseline.provenance.status `
    'Historical summarize-only output must mark stale provenance.'

  $lMarkdown = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.md') -Raw
  if ($lMarkdown -notmatch 'Provenance: `historical`') {
    throw 'Markdown summary must mark historical provenance.'
  }
}

function Test-ReportOnlyBenchmarkMutationFailsClosedAndRestoresSource {
  $lWorkspace = New-TestWorkspace 'report-only-mutation'
  $lProject = Join-Path $lWorkspace 'project.dpr'
  $lSource = Join-Path $lWorkspace 'unit1.pas'
  $lDak = Join-Path $lWorkspace 'dak.ps1'
  Set-Content -LiteralPath $lProject -Value 'program project; uses unit1;' -Encoding UTF8
  Set-Content -LiteralPath $lSource -Value 'unit unit1; interface implementation end.' -Encoding UTF8
  $lBefore = Get-Content -LiteralPath $lSource -Raw
  New-MutatingDakScript -Path $lDak -SourceFile $lSource

  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe $lDak -Project $lProject -Workflow remove-with-scan-all `
    -Repeat 1 -CacheMode cold -OutDir $lWorkspace -NoBaselineCopy `
    1> (Join-Path $lWorkspace 'mutation.stdout.txt') `
    2> (Join-Path $lWorkspace 'mutation.stderr.txt')
  $lExit = $LASTEXITCODE
  if ($lExit -eq 0) {
    throw 'Benchmark must fail when a report-only workflow mutates source.'
  }

  $lAfter = Get-Content -LiteralPath $lSource -Raw
  Assert-Equal $lBefore $lAfter 'Benchmark mutation guard must restore the mutated source file.'
}

function Test-ReportOnlyBenchmarkRecordsCleanMutationStatus {
  $lWorkspace = New-TestWorkspace 'report-only-clean-status'
  $lProject = Join-Path $lWorkspace 'project.dpr'
  $lSource = Join-Path $lWorkspace 'unit1.pas'
  $lDak = Join-Path $lWorkspace 'dak.ps1'
  Set-Content -LiteralPath $lProject -Value 'program project; uses unit1;' -Encoding UTF8
  Set-Content -LiteralPath $lSource -Value 'unit unit1; interface implementation end.' -Encoding UTF8

  $lScript = @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Arguments)
[ordered]@{
  operation = 'remove-with'
  mode = 'scan'
  summary = [ordered]@{ withStatements = 667 }
  withStatements = @()
} | ConvertTo-Json -Depth 8
exit 0
"@
  Set-Content -LiteralPath $lDak -Value $lScript -Encoding UTF8

  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe $lDak -Project $lProject -Workflow remove-with-scan-all `
    -Repeat 1 -CacheMode cold -OutDir $lWorkspace -NoBaselineCopy `
    1> (Join-Path $lWorkspace 'clean.stdout.txt') `
    2> (Join-Path $lWorkspace 'clean.stderr.txt')
  Assert-Equal 0 $LASTEXITCODE 'Clean report-only benchmark should pass.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 'clean' $lBaseline.runs[0].SourceMutationStatus `
    'Run rows must record clean source mutation status.'
  Assert-Equal 'clean' $lBaseline.results[0].SourceMutationStatus `
    'Summary rows must record clean source mutation status.'
  $lMarkdown = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.md') -Raw
  if ($lMarkdown -notmatch 'Source mutation') {
    throw 'Markdown summary must include the source mutation status column.'
  }
}

function Test-ReportOnlyBenchmarkExternalProjectSourceMutationFailsClosed {
  $lWorkspace = New-TestWorkspace 'external-source-mutation'
  $lProjectDir = Join-Path $lWorkspace 'project'
  $lExternalDir = Join-Path $lWorkspace 'external'
  New-Item -ItemType Directory -Force -Path $lProjectDir, $lExternalDir | Out-Null
  $lProject = Join-Path $lProjectDir 'project.dpr'
  $lExternalSource = Join-Path $lExternalDir 'ExternalUnit.pas'
  $lDak = Join-Path $lWorkspace 'dak.ps1'
  Set-Content -LiteralPath $lProject -Value @"
program project;
uses
  ExternalUnit in '..\external\ExternalUnit.pas';
begin
end.
"@ -Encoding UTF8
  Set-Content -LiteralPath $lExternalSource -Value 'unit ExternalUnit; interface implementation end.' `
    -Encoding UTF8
  $lBefore = Get-Content -LiteralPath $lExternalSource -Raw
  New-MutatingDakScript -Path $lDak -SourceFile $lExternalSource

  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe $lDak -Project $lProject -Workflow remove-with-scan-all `
    -Repeat 1 -CacheMode cold -OutDir $lWorkspace -NoBaselineCopy `
    1> (Join-Path $lWorkspace 'external.stdout.txt') `
    2> (Join-Path $lWorkspace 'external.stderr.txt')
  $lExit = $LASTEXITCODE
  if ($lExit -eq 0) {
    throw 'Benchmark must fail when an externally referenced project source mutates.'
  }

  $lAfter = Get-Content -LiteralPath $lExternalSource -Raw
  Assert-Equal $lBefore $lAfter 'Benchmark mutation guard must restore externally referenced source.'
}

function Test-ReportOnlyBenchmarkSearchPathSourceMutationFailsClosed {
  $lWorkspace = New-TestWorkspace 'search-path-source-mutation'
  $lProjectDir = Join-Path $lWorkspace 'project'
  $lExternalDir = Join-Path $lWorkspace 'external'
  New-Item -ItemType Directory -Force -Path $lProjectDir, $lExternalDir | Out-Null
  $lProject = Join-Path $lProjectDir 'project.dpr'
  $lDproj = Join-Path $lProjectDir 'project.dproj'
  $lSearchPathSource = Join-Path $lExternalDir 'SearchPathUnit.pas'
  $lDak = Join-Path $lWorkspace 'dak.ps1'
  Set-Content -LiteralPath $lProject -Value @"
program project;
uses
  SearchPathUnit;
begin
end.
"@ -Encoding UTF8
  Set-Content -LiteralPath $lDproj -Value @"
<Project>
  <PropertyGroup>
    <DCC_UnitSearchPath>..\external;`$(DCC_UnitSearchPath)</DCC_UnitSearchPath>
  </PropertyGroup>
</Project>
"@ -Encoding UTF8
  Set-Content -LiteralPath $lSearchPathSource -Value 'unit SearchPathUnit; interface implementation end.' `
    -Encoding UTF8
  $lBefore = Get-Content -LiteralPath $lSearchPathSource -Raw
  New-MutatingDakScript -Path $lDak -SourceFile $lSearchPathSource

  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe $lDak -Project $lProject -Workflow remove-with-scan-all `
    -Repeat 1 -CacheMode cold -OutDir $lWorkspace -NoBaselineCopy `
    1> (Join-Path $lWorkspace 'searchpath.stdout.txt') `
    2> (Join-Path $lWorkspace 'searchpath.stderr.txt')
  $lExit = $LASTEXITCODE
  if ($lExit -eq 0) {
    throw 'Benchmark must fail when a search-path project source mutates.'
  }

  $lAfter = Get-Content -LiteralPath $lSearchPathSource -Raw
  Assert-Equal $lBefore $lAfter 'Benchmark mutation guard must restore search-path source.'
}

Invoke-ScriptTests
