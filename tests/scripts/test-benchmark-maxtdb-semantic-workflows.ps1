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
    summary = [ordered]@{ withStatements = 667; plannedEdits = 215; skipped = 452 }
    withStatements = @()
    plannedEdits = @(for (`$i = 1; `$i -le 215; `$i++) {
      [ordered]@{ statementId = "planned-`$i" }
    })
    skipped = @(for (`$i = 1; `$i -le 452; `$i++) {
      [ordered]@{ statementId = "skipped-`$i"; reason = 'symbol-not-found' }
    })
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

function New-CleanDakScript {
  param([string]$Path)

  $lScript = @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Arguments)
`$lModeIndex = [Array]::IndexOf(`$Arguments, '--mode')
`$lMode = if (`$lModeIndex -ge 0) { `$Arguments[`$lModeIndex + 1] } else { 'scan' }
if (`$lMode -eq 'plan') {
  [ordered]@{
    operation = 'remove-with'
    mode = 'plan'
    summary = [ordered]@{ withStatements = 667; plannedEdits = 215; skipped = 452 }
    withStatements = @()
    plannedEdits = @(for (`$i = 1; `$i -le 215; `$i++) {
      [ordered]@{ statementId = "planned-`$i" }
    })
    skipped = @(for (`$i = 1; `$i -le 452; `$i++) {
      [ordered]@{ statementId = "skipped-`$i"; reason = 'symbol-not-found' }
    })
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

function Write-DiagnosticSensitiveDakScript {
  param(
    [string]$Path,
    [string]$ArgsLogPath
  )

  $lScript = @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Arguments)
Set-Content -LiteralPath '$ArgsLogPath' -Value (`$Arguments -join ' ') -Encoding UTF8
`$lModeIndex = [Array]::IndexOf(`$Arguments, '--mode')
`$lMode = if (`$lModeIndex -ge 0) { `$Arguments[`$lModeIndex + 1] } else { 'scan' }
`$lDiagnosticsIndex = [Array]::IndexOf(`$Arguments, '--diagnostics')
`$lHasDiagnostics = (`$lDiagnosticsIndex -ge 0) -and
  (`$lDiagnosticsIndex + 1 -lt `$Arguments.Count) -and
  (`$Arguments[`$lDiagnosticsIndex + 1] -eq 'true')
if (`$lMode -eq 'plan') {
  `$lPlan = [ordered]@{
    operation = 'remove-with'
    mode = 'plan'
    summary = [ordered]@{ withStatements = 667; plannedEdits = 215; skipped = 452 }
    withStatements = @()
    plannedEdits = @(for (`$i = 1; `$i -le 215; `$i++) {
      [ordered]@{ statementId = "planned-`$i" }
    })
    skipped = @(for (`$i = 1; `$i -le 452; `$i++) {
      [ordered]@{ statementId = "skipped-`$i"; reason = 'symbol-not-found' }
    })
    semanticDtoParity = [ordered]@{
      status = 'passed'
      mismatchCount = 0
      summaryText = 'test parity'
      mismatches = @()
    }
  }
  if (`$lHasDiagnostics) {
    `$lPlan.plannerPhaseMetrics = [ordered]@{ totalMs = 1 }
  }
  `$lPlan | ConvertTo-Json -Depth 8
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

function Initialize-TestGitRepository {
  param([string]$Path)

  git -C $Path init | Out-Null
  Set-Content -LiteralPath (Join-Path $Path '.gitignore') -Value @"
out/
docs/
benchmark.stdout.txt
benchmark.stderr.txt
summarize.stdout.txt
summarize.stderr.txt
*.stdout.json
"@ -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $Path 'tracked.txt') -Value 'clean' -Encoding UTF8
  git -C $Path add . | Out-Null
  git -C $Path -c user.name='Benchmark Test' -c user.email='benchmark@example.test' `
    commit -m init | Out-Null
}

function New-PlanJson {
  param(
    [string]$Path,
    [int]$WithCount,
    [int]$PlannedCount,
    [int]$MismatchCount,
    [int]$SkippedCount = -1,
    [int]$CoveredCount = 0,
    [switch]$OmitMismatchCount,
    [switch]$OmitCovered
  )

  if ($SkippedCount -lt 0) {
    $SkippedCount = $WithCount - $PlannedCount - $CoveredCount
  }

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
      skipped = $SkippedCount
      covered = $CoveredCount
    }
    withStatements = @()
    plannedEdits = @(for ($i = 1; $i -le $PlannedCount; $i++) {
      [ordered]@{ statementId = "planned-$i" }
    })
    skipped = @(for ($i = 1; $i -le $SkippedCount; $i++) {
      [ordered]@{ statementId = "skipped-$i"; reason = 'symbol-not-found' }
    })
    covered = @(for ($i = 1; $i -le $CoveredCount; $i++) {
      [ordered]@{
        statementId = "covered-$i"
        reason = 'covered-by-parent-rewrite'
        coveredByStatementId = 'planned-1'
      }
    })
    semanticDtoParity = $lParity
    plannerPhaseMetrics = [ordered]@{
      totalMs = 1
    }
  }
  if ($OmitCovered) {
    $lJson.summary.Remove('covered')
    $lJson.Remove('covered')
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
    [double]$ElapsedSeconds = 1,
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
    ElapsedSeconds = $ElapsedSeconds
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

function Invoke-BenchmarkRun {
  param(
    [string]$Workspace,
    [switch]$PromoteBaseline,
    [switch]$SummarizeOnly,
    [switch]$AllowHistoricalSummary,
    [switch]$AllowHistoricalPromotion
  )

  $lDakExe = Join-Path $Workspace 'dak.ps1'
  $lProject = Join-Path $Workspace 'project.dpr'
  $lStdout = Join-Path $Workspace 'benchmark.stdout.txt'
  $lStderr = Join-Path $Workspace 'benchmark.stderr.txt'
  $lArgs = @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass',
    '-File', $BenchmarkScript,
    '-DakExe', $lDakExe,
    '-Project', $lProject,
    '-Workflow', 'remove-with-scan-all',
    '-Repeat', '1',
    '-CacheMode', 'cold',
    '-OutDir', 'out'
  )
  if ($SummarizeOnly) {
    $lArgs += '-SummarizeOnly'
  }
  if ($PromoteBaseline) {
    $lArgs += '-PromoteBaseline'
  }
  if ($AllowHistoricalSummary) {
    $lArgs += '-AllowHistoricalSummary'
  }
  if ($AllowHistoricalPromotion) {
    $lArgs += '-AllowHistoricalPromotion'
  }

  Push-Location $Workspace
  try {
    & pwsh @lArgs 1> $lStdout 2> $lStderr
    return $LASTEXITCODE
  } finally {
    Pop-Location
  }
}

function Test-BenchmarkDoesNotPromoteBaselineByDefault {
  $lWorkspace = New-TestWorkspace 'default-no-baseline-promotion'
  New-CleanDakScript -Path (Join-Path $lWorkspace 'dak.ps1')

  $lExit = Invoke-BenchmarkRun -Workspace $lWorkspace
  Assert-Equal 0 $lExit 'Default benchmark run should pass.'
  Assert-True (Test-Path -LiteralPath (Join-Path $lWorkspace 'out\baseline.json')) `
    'Default benchmark run must still write baseline.json under OutDir.'
  Assert-True (-not (Test-Path -LiteralPath (Join-Path $lWorkspace 'docs\benchmarks'))) `
    'Default benchmark run must not promote artifacts to docs\benchmarks.'
}

function Test-RemoveWithPlanBenchmarkRequestsDiagnosticForPlannerMetric {
  $lWorkspace = New-TestWorkspace 'plan-diagnostics-for-metrics'
  $lDak = Join-Path $lWorkspace 'dak.ps1'
  $lArgsLog = Join-Path $lWorkspace 'dak.args.txt'
  Write-DiagnosticSensitiveDakScript -Path $lDak -ArgsLogPath $lArgsLog

  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe $lDak -Project (Join-Path $lWorkspace 'project.dpr') `
    -Workflow remove-with-plan-all -Repeat 1 -CacheMode cold `
    -OutDir $lWorkspace -NoBaselineCopy `
    1> (Join-Path $lWorkspace 'diagnostics.stdout.txt') `
    2> (Join-Path $lWorkspace 'diagnostics.stderr.txt')

  Assert-Equal 0 $LASTEXITCODE `
    'remove-with-plan-all benchmark must request diagnostics so planner metrics are emitted.'
  $lArgs = Get-Content -LiteralPath $lArgsLog -Raw
  if ($lArgs -notmatch '--diagnostics true') {
    throw 'remove-with-plan-all benchmark command must pass --diagnostics true.'
  }
}

function Test-RemoveWithPlanWarmTargetMissIsBestEffort {
  $lWorkspace = New-TestWorkspace 'plan-warm-target-best-effort'
  New-CleanDakScript -Path (Join-Path $lWorkspace 'dak.ps1')

  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe (Join-Path $lWorkspace 'dak.ps1') `
    -Project (Join-Path $lWorkspace 'project.dpr') `
    -Workflow remove-with-plan-all `
    -Repeat 1 `
    -CacheMode warm `
    -WarmTargetSeconds 0.000001 `
    -OutDir $lWorkspace `
    -NoBaselineCopy `
    1> (Join-Path $lWorkspace 'warm-target.stdout.txt') `
    2> (Join-Path $lWorkspace 'warm-target.stderr.txt')

  Assert-Equal 0 $LASTEXITCODE `
    'remove-with-plan-all warm target miss should be a best-effort signal, not a hard failure.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  $lResult = @($lBaseline.results | Where-Object {
    ($_.Id -eq 'remove-with-plan-all') -and ($_.CacheMode -eq 'warm')
  })[0]
  Assert-Equal 'missed' $lResult.TargetStatus `
    'Warm target miss must remain visible in baseline JSON.'
  Assert-Equal 215 $lResult.ResultCount `
    'Correctness signal must still report planned edits.'
  Assert-Equal 'clean' $lResult.SourceMutationStatus `
    'Report-only source mutation status must stay clean.'

  $lMarkdown = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.md') -Raw
  if ($lMarkdown -notmatch 'missed') {
    throw 'Markdown summary must still show the missed warm target.'
  }
}

function Test-BenchmarkPromotesBaselineOnlyWhenExplicit {
  $lWorkspace = New-TestWorkspace 'explicit-baseline-promotion'
  New-CleanDakScript -Path (Join-Path $lWorkspace 'dak.ps1')
  Initialize-TestGitRepository -Path $lWorkspace

  $lExit = Invoke-BenchmarkRun -Workspace $lWorkspace -PromoteBaseline
  Assert-Equal 0 $lExit 'Explicit benchmark promotion should pass for a clean workspace.'
  Assert-True (Test-Path -LiteralPath (Join-Path $lWorkspace 'docs\benchmarks\maxtdb-semantic-out.json')) `
    'Explicit custom benchmark promotion must copy JSON to docs\benchmarks.'
  Assert-True (Test-Path -LiteralPath (Join-Path $lWorkspace 'docs\benchmarks\maxtdb-semantic-out.md')) `
    'Explicit custom benchmark promotion must copy Markdown to docs\benchmarks.'
}

function Test-BenchmarkPromotionRefusesDirtyDelphiSemanticsWorkspace {
  $lWorkspace = New-TestWorkspace 'dirty-baseline-promotion'
  New-CleanDakScript -Path (Join-Path $lWorkspace 'dak.ps1')
  Initialize-TestGitRepository -Path $lWorkspace
  Add-Content -LiteralPath (Join-Path $lWorkspace 'tracked.txt') -Value 'dirty'

  $lExit = Invoke-BenchmarkRun -Workspace $lWorkspace -PromoteBaseline
  if ($lExit -eq 0) {
    throw 'Benchmark promotion must fail for a dirty DelphiSemantics workspace.'
  }
  $lStderr = Get-Content -LiteralPath (Join-Path $lWorkspace 'benchmark.stderr.txt') -Raw
  if ($lStderr -notmatch 'dirty') {
    throw 'Dirty promotion failure must explain dirty provenance.'
  }
}

function Test-BenchmarkHistoricalPromotionRequiresExplicitOverride {
  $lWorkspace = New-TestWorkspace 'historical-promotion'
  New-CleanDakScript -Path (Join-Path $lWorkspace 'dak.ps1')
  Initialize-TestGitRepository -Path $lWorkspace
  New-Item -ItemType Directory -Force -Path (Join-Path $lWorkspace 'out') | Out-Null
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 667 -PlannedCount 215 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'out\baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  ) -DelphiSemanticsSha 'stale-delphi-semantics-sha'

  $lBlockedExit = Invoke-BenchmarkRun -Workspace $lWorkspace -SummarizeOnly -PromoteBaseline `
    -AllowHistoricalSummary
  if ($lBlockedExit -eq 0) {
    throw 'Historical benchmark promotion must require AllowHistoricalPromotion.'
  }

  $lAllowedExit = Invoke-BenchmarkRun -Workspace $lWorkspace -SummarizeOnly -PromoteBaseline `
    -AllowHistoricalPromotion
  Assert-Equal 0 $lAllowedExit 'Explicit historical promotion should pass.'
  Assert-True (Test-Path -LiteralPath (Join-Path $lWorkspace 'docs\benchmarks\maxtdb-semantic-out.json')) `
    'Explicit historical promotion must copy JSON to docs\benchmarks.'
  $lPromoted = Get-Content -LiteralPath (Join-Path $lWorkspace 'docs\benchmarks\maxtdb-semantic-out.json') `
    -Raw | ConvertFrom-Json
  Assert-Equal 'historical' $lPromoted.provenance.status `
    'Historical promotion must preserve historical provenance status.'
}

function Test-CompactPlanSummaryCountsDriveDogfoodExport {
  $lWorkspace = New-TestWorkspace 'compact-summary-counts'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 12 -PlannedCount 4 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  Assert-Equal 0 $lExit 'SummarizeOnly should pass for compact plan output.'

  $lDogfood = Get-Content -LiteralPath (Join-Path $lWorkspace 'dogfood.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 'passed' $lDogfood.status 'dogfood.json must pass for complete accounting.'
  Assert-Equal 12 $lDogfood.latest.discoveredCount 'dogfood.json must use summary.withStatements.'
  Assert-Equal 4 $lDogfood.latest.plannedCount 'dogfood.json must use summary.plannedEdits.'
  Assert-Equal 8 $lDogfood.latest.skippedCount 'dogfood.json must use summary.skipped.'
  Assert-Equal 'complete' $lDogfood.latest.completeness.status `
    'dogfood.json must report complete statement accounting.'
  Assert-Equal 0 $lDogfood.latest.completeness.unaccountedCount `
    'dogfood.json must expose no unaccounted statements.'
  $lBucket = @($lDogfood.latest.skipBuckets | Where-Object { $_.reason -eq 'symbol-not-found' })[0]
  Assert-Equal 8 $lBucket.count 'dogfood.json must bucket skipped statements by reason.'
  Assert-Equal 'clean' $lDogfood.latest.sourceMutationStatus `
    'dogfood.json must preserve report-only mutation status.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 4 $lBaseline.results[0].ResultCount 'summary result count must use compact summary plannedEdits.'
  Assert-Equal 'current' $lBaseline.provenance.status `
    'SummarizeOnly with matching current provenance must mark current status.'

  $lMarkdown = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.md') -Raw
  if ($lMarkdown -notmatch 'Provenance: `current`') {
    throw 'Markdown summary must mark current provenance.'
  }
}

function Test-CoveredPlanRowsCompleteAccounting {
  $lWorkspace = New-TestWorkspace 'covered-plan-accounting'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 12 -PlannedCount 4 -SkippedCount 6 `
    -CoveredCount 2 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  Assert-Equal 0 $lExit 'SummarizeOnly should accept covered rows as complete accounting.'

  $lDogfood = Get-Content -LiteralPath (Join-Path $lWorkspace 'dogfood.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 'passed' $lDogfood.status 'Covered plan accounting must pass.'
  Assert-Equal 12 $lDogfood.latest.discoveredCount 'Expected discovered count.'
  Assert-Equal 4 $lDogfood.latest.plannedCount 'Expected planned count.'
  Assert-Equal 6 $lDogfood.latest.skippedCount 'Expected skipped count.'
  Assert-Equal 2 $lDogfood.latest.coveredCount 'Expected covered count.'
  Assert-Equal 12 $lDogfood.latest.completeness.accountedCount `
    'Covered rows must contribute to accounted statements.'
  Assert-Equal 0 $lDogfood.latest.completeness.unaccountedCount `
    'Covered rows must leave no unaccounted statements.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 2 $lBaseline.results[0].CoveredCount `
    'Benchmark results must preserve the covered count.'
  $lMarkdown = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.md') -Raw
  if ($lMarkdown -notmatch 'covered=2') {
    throw 'Markdown summary must report the covered count.'
  }
}

function Test-PlanRunCountDriftIsReportedAsDogfoodEvidence {
  $lWorkspace = New-TestWorkspace 'plan-count-drift'
  $lFirstPlanPath = Join-Path $lWorkspace 'plan-1.stdout.json'
  $lSecondPlanPath = Join-Path $lWorkspace 'plan-2.stdout.json'
  New-PlanJson -Path $lFirstPlanPath -WithCount 12 -PlannedCount 4 -MismatchCount 0
  New-PlanJson -Path $lSecondPlanPath -WithCount 13 -PlannedCount 4 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lFirstPlanPath -Run 1),
    (New-PlanRun -Stdout $lSecondPlanPath -Run 2)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  Assert-Equal 0 $lExit 'SummarizeOnly must not fail just because dogfood counts changed.'

  $lDogfood = Get-Content -LiteralPath (Join-Path $lWorkspace 'dogfood.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 2 @($lDogfood.runs).Count 'dogfood.json must record every successful plan run.'
  Assert-Equal 13 $lDogfood.latest.discoveredCount 'dogfood.json latest run must report current discovered count.'
  Assert-Equal 4 $lDogfood.latest.plannedCount 'dogfood.json latest run must report current planned count.'
  Assert-Equal 9 $lDogfood.latest.skippedCount 'dogfood.json latest run must report current skipped count.'
}

function Test-LegacyPlanWithoutCoveredStillSummarizes {
  $lWorkspace = New-TestWorkspace 'legacy-plan-without-covered'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 12 -PlannedCount 4 -SkippedCount 8 `
    -MismatchCount 0 -OmitCovered
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  Assert-Equal 0 $lExit 'Legacy plan output without covered must remain summarizable.'

  $lDogfood = Get-Content -LiteralPath (Join-Path $lWorkspace 'dogfood.json') -Raw |
    ConvertFrom-Json
  Assert-Equal 12 $lDogfood.latest.completeness.accountedCount `
    'Legacy planned and skipped rows must still complete accounting.'
  Assert-Equal 0 $lDogfood.latest.coveredCount `
    'Legacy plan output must be interpreted as zero covered rows.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  Assert-True ([string]::IsNullOrWhiteSpace([string]$lBaseline.results[0].CoveredCount)) `
    'Legacy plan summaries must leave the additive covered metric blank.'
}

function Test-PlanRunIncompleteAccountingFailsClosed {
  $lWorkspace = New-TestWorkspace 'plan-incomplete-accounting'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 12 -PlannedCount 4 -SkippedCount 7 -MismatchCount 0
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs @(
    (New-PlanRun -Stdout $lPlanPath -Run 1)
  )

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  if ($lExit -eq 0) {
    throw 'SummarizeOnly must fail when planned and skipped counts do not account for discovered statements.'
  }
  $lStderr = Get-Content -LiteralPath (Join-Path $lWorkspace 'summarize.stderr.txt') -Raw
  if ($lStderr -notmatch 'accounting') {
    throw 'Incomplete accounting failure must name the accounting problem.'
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

function Test-SummaryUsesNearestRankP95 {
  $lWorkspace = New-TestWorkspace 'nearest-rank-p95'
  $lPlanPath = Join-Path $lWorkspace 'plan.stdout.json'
  New-PlanJson -Path $lPlanPath -WithCount 12 -PlannedCount 4 -SkippedCount 6 `
    -CoveredCount 2 -MismatchCount 0
  $lSamples = @(20, 1, 19, 2, 18, 3, 17, 4, 16, 5, 15, 6, 14, 7, 13, 8, 12, 9, 11, 10)
  $lRuns = @(for ($i = 0; $i -lt $lSamples.Count; $i++) {
    New-PlanRun -Stdout $lPlanPath -Run ($i + 1) -ElapsedSeconds $lSamples[$i]
  })
  $lScanPath = Join-Path $lWorkspace 'scan.stdout.json'
  New-ScanJson -Path $lScanPath -WithCount 12
  $lRuns += New-PlanRun -Stdout $lScanPath -Run 1 -Id 'remove-with-scan-all' `
    -ElapsedSeconds 7.5
  New-BaselineJson -Path (Join-Path $lWorkspace 'baseline.json') -Runs $lRuns

  $lExit = Invoke-BenchmarkSummarize -Workspace $lWorkspace
  Assert-Equal 0 $lExit 'SummarizeOnly should calculate p95 for valid runs.'

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  $lPlanResult = $lBaseline.results | Where-Object { $_.Id -eq 'remove-with-plan-all' }
  $lScanResult = $lBaseline.results | Where-Object { $_.Id -eq 'remove-with-scan-all' }
  Assert-Equal 19 $lPlanResult.P95Seconds `
    'p95 must use one-based nearest rank ceil(0.95 * N), not the maximum sample.'
  Assert-Equal 7.5 $lScanResult.P95Seconds `
    'A one-sample p95 must clamp to the only sample.'
  $lMarkdown = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.md') -Raw
  if ($lMarkdown -notmatch 'P95 seconds') {
    throw 'Markdown summary must report p95.'
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

function Test-WarmCacheIsPrimedAndIsolatedPerWorkflow {
  $lWorkspace = New-TestWorkspace 'warm-cache-workflow-isolation'
  $lProject = Join-Path $lWorkspace 'project.dpr'
  $lDak = Join-Path $lWorkspace 'dak.ps1'
  $lInvocationLog = Join-Path $lWorkspace 'dak-invocations.jsonl'
  foreach ($lWorkflow in @('find-usages-allfiles', 'rename-dry-run-allfiles')) {
    $lCacheDirectory = Join-Path $lWorkspace "semantic-cache\$lWorkflow"
    New-Item -ItemType Directory -Force -Path $lCacheDirectory | Out-Null
    Set-Content -LiteralPath (Join-Path $lCacheDirectory 'unit-models.sqlite3') `
      -Value 'pre-existing cache' -Encoding UTF8
  }
  $lScript = @"
param([Parameter(ValueFromRemainingArguments = `$true)][string[]]`$Arguments)
`$lCacheIndex = [Array]::IndexOf(`$Arguments, '--semantic-cache')
`$lCachePath = if (`$lCacheIndex -ge 0) { `$Arguments[`$lCacheIndex + 1] } else { '' }
if (-not [string]::IsNullOrWhiteSpace(`$lCachePath)) {
  New-Item -ItemType Directory -Force -Path (Split-Path -Parent `$lCachePath) | Out-Null
  Set-Content -LiteralPath `$lCachePath -Value 'primed' -Encoding UTF8
}
[ordered]@{
  command = `$Arguments[0]
  cachePath = `$lCachePath
} | ConvertTo-Json -Compress | Add-Content -LiteralPath '$lInvocationLog' -Encoding UTF8
[ordered]@{
  count = 1
  referenceReconciliationFallbackCount = 0
} | ConvertTo-Json
exit 0
"@
  Set-Content -LiteralPath $lDak -Value $lScript -Encoding UTF8

  & pwsh -NoProfile -ExecutionPolicy Bypass -File $BenchmarkScript `
    -DakExe $lDak -Project $lProject `
    -Workflow 'find-usages-allfiles,rename-dry-run-allfiles' `
    -Repeat 1 -CacheMode warm -OutDir $lWorkspace -NoBaselineCopy `
    1> (Join-Path $lWorkspace 'warm-isolation.stdout.txt') `
    2> (Join-Path $lWorkspace 'warm-isolation.stderr.txt')
  Assert-Equal 0 $LASTEXITCODE 'Warm benchmark should pass.'

  $lInvocations = @(Get-Content -LiteralPath $lInvocationLog | ForEach-Object {
    $_ | ConvertFrom-Json
  })
  Assert-Equal 4 $lInvocations.Count `
    'Each workflow needs one unmeasured prime and one measured warm run.'
  $lCachePaths = @($lInvocations | Select-Object -ExpandProperty cachePath -Unique)
  Assert-Equal 2 $lCachePaths.Count 'Each workflow must use an isolated cache path.'
  foreach ($lCachePath in $lCachePaths) {
    $lCacheUseCount = @($lInvocations | Where-Object { $_.cachePath -eq $lCachePath }).Count
    Assert-Equal 2 $lCacheUseCount 'Each workflow cache must be primed before its measured run.'
  }

  $lBaseline = Get-Content -LiteralPath (Join-Path $lWorkspace 'baseline.json') -Raw |
    ConvertFrom-Json
  $lRunCacheDirectories = @($lBaseline.runs |
    Select-Object -ExpandProperty CacheDirectory -Unique)
  Assert-Equal 2 $lRunCacheDirectories.Count `
    'Measured rows must identify their workflow-isolated cache directories.'
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

function Test-BenchmarkExplicitContextArgument {
  $lTokens = $null
  $lErrors = $null
  $lAst = [System.Management.Automation.Language.Parser]::ParseFile(
    $BenchmarkScript, [ref]$lTokens, [ref]$lErrors)
  Assert-Equal 0 @($lErrors).Count 'The benchmark script must parse.'
  foreach ($lName in @('Get-BenchmarkDefinition', 'Test-RequiresPlannerPhaseMetric', 'Get-BenchmarkArgument')) {
    $lDefinition = @($lAst.FindAll({
      param($Node)
      $Node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $false) | Where-Object Name -EQ $lName)
    Assert-Equal 1 $lDefinition.Count "Expected the real function $lName."
    . ([scriptblock]::Create($lDefinition[0].Extent.Text))
  }

  $lBenchmarks = @(Get-BenchmarkDefinition -ProjectPath 'C:\fixture\sample.dproj' |
    Where-Object Id -In @('remove-with-plan-all', 'rename-dry-run-allfiles'))
  Assert-Equal 2 $lBenchmarks.Count 'Both certified workflows must be checked.'
  foreach ($lBenchmark in $lBenchmarks) {
    foreach ($lCacheMode in @('default', 'cold', 'warm')) {
      foreach ($lExplicit in @($false, $true)) {
        $lContext = if ($lExplicit) {
          @{ Platform = 'Win64'; Config = 'Release'; DelphiVersion = '23.0' }
        } else { @{} }
        $lArguments = @(Get-BenchmarkArgument -Benchmark $lBenchmark -CacheMode $lCacheMode `
          -SemanticCacheFile 'C:\fixture\cache.sqlite3' @lContext)
        $lLabel = "$($lBenchmark.Id)/$lCacheMode/explicit=$lExplicit"
        foreach ($lOption in @('--platform', '--config', '--delphi')) {
          $lCount = @($lArguments | Where-Object { $_ -eq $lOption }).Count
          Assert-Equal ([int]$lExplicit) $lCount "$lLabel must emit $lOption exactly when requested."
        }
        if ($lExplicit) {
          Assert-Equal 'Win64' $lArguments[([array]::IndexOf($lArguments, '--platform') + 1)] $lLabel
          Assert-Equal 'Release' $lArguments[([array]::IndexOf($lArguments, '--config') + 1)] $lLabel
          Assert-Equal '23.0' $lArguments[([array]::IndexOf($lArguments, '--delphi') + 1)] $lLabel
        }
        Assert-Equal ($lBenchmark.Arguments -join '|') `
          ($lArguments[0..($lBenchmark.Arguments.Count - 1)] -join '|') `
          "$lLabel must preserve project, mode, symbol and new-name arguments."
        Assert-True ($lArguments -notcontains '--apply') "$lLabel must remain report-only."
        if ($lBenchmark.Id -eq 'remove-with-plan-all') {
          Assert-Equal 1 @($lArguments | Where-Object { $_ -eq '--diagnostics' }).Count $lLabel
          Assert-Equal 'true' $lArguments[([array]::IndexOf($lArguments, '--diagnostics') + 1)] $lLabel
        }
        Assert-Equal ([int]($lCacheMode -ne 'default')) `
          @($lArguments | Where-Object { $_ -eq '--semantic-cache' }).Count $lLabel
        if ($lCacheMode -ne 'default') {
          Assert-Equal 'C:\fixture\cache.sqlite3' `
            $lArguments[([array]::IndexOf($lArguments, '--semantic-cache') + 1)] $lLabel
        }
      }
    }
  }
}

function Test-BenchmarkListShowsExplicitContextWithoutRunning {
  $lDakExe = Join-Path (Split-Path $RepoRoot -Parent) 'DelphiAiKit\bin\DelphiAIKit.exe'
  $lProject = Join-Path $RepoRoot 'tests\fixtures\RemoveWithInlinePrecedence\InlineHeader.dproj'
  $lOutputDir = Join-Path $TempRoot ('list-context-' + [guid]::NewGuid().ToString('N'))
  $lBefore = (Get-FileHash -LiteralPath $lProject -Algorithm SHA256).Hash
  $lOutput = (& pwsh -NoProfile -File $BenchmarkScript -DakExe $lDakExe -Project $lProject `
    -Workflow 'remove-with-plan-all,rename-dry-run-allfiles' -CacheMode 'cold,warm' `
    -Platform Win64 -Config Release -DelphiVersion 23.0 -OutputDir $lOutputDir -List 2>&1) -join "`n"
  Assert-Equal 0 $LASTEXITCODE 'List must accept explicit semantic context.'
  foreach ($lPattern in @('--platform\s+Win64', '--config\s+Release', '--delphi\s+23\.0')) {
    Assert-Equal 4 ([regex]::Matches($lOutput, $lPattern).Count) `
      "Both workflows and cache modes must display $lPattern. Output: $lOutput"
  }
  Assert-Equal 4 ([regex]::Matches($lOutput, '--semantic-cache').Count) `
    'Every cold/warm command must show its actual cache argument.'
  Assert-Equal 2 ([regex]::Matches($lOutput, '--diagnostics\s+true').Count) `
    'Both remove-with commands must show diagnostics.'
  Assert-True (-not (Test-Path -LiteralPath $lOutputDir)) 'List must not create benchmark output.'
  Assert-Equal $lBefore (Get-FileHash -LiteralPath $lProject -Algorithm SHA256).Hash `
    'List must not modify the project.'
}

Invoke-ScriptTests
