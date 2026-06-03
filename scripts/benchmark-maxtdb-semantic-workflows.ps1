[CmdletBinding()]
param(
  [string]$DakExe = 'F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe',
  [string]$Project = 'F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr',
  [Alias('OutDir')]
  [string]$OutputDir = '.dak\benchmarks\maxtdb-semantic',
  [string[]]$Workflow = @(),
  [string[]]$CacheMode = @('default'),
  [int]$Repeat = 1,
  [double]$WarmTargetSeconds = 10.0,
  [switch]$List,
  [switch]$SummarizeOnly,
  [switch]$NoBaselineCopy
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-OutputPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return $Path
  }

  return Join-Path (Get-Location) $Path
}

function Split-ArgumentValues {
  param([string[]]$Values)

  $lResult = New-Object System.Collections.Generic.List[string]
  foreach ($lValue in $Values) {
    foreach ($lPart in ([string]$lValue).Split(',')) {
      $lTrimmed = $lPart.Trim()
      if ($lTrimmed -ne '') {
        $lResult.Add($lTrimmed)
      }
    }
  }

  return @($lResult.ToArray())
}

function Get-GitSha {
  param([string]$Path)

  try {
    $lSha = git -C $Path rev-parse HEAD 2>$null
    if ($LASTEXITCODE -eq 0) {
      return [string]$lSha
    }
  } catch {
    Write-Verbose "Unable to read git SHA from $Path"
  }

  return ''
}

function New-BenchmarkDefinitions {
  param([string]$ProjectPath)

  @(
    [ordered]@{
      Id = 'remove-with-scan-all'
      Feature = 'with-removal'
      Description = 'Scan all project units for with statements'
      Arguments = @('remove-with', '--project', $ProjectPath, '--all', '--mode', 'scan', '--format', 'json')
    },
    [ordered]@{
      Id = 'remove-with-plan-all'
      Feature = 'with-removal'
      Description = 'Plan safe with-removal edits for all project units'
      Arguments = @('remove-with', '--project', $ProjectPath, '--all', '--mode', 'plan', '--format', 'json')
    },
    [ordered]@{
      Id = 'dead-code-legacy-static'
      Feature = 'dead-code-detection'
      Description = 'Report dead-code candidates with legacy-static profile'
      Arguments = @('dead-code', '--project', $ProjectPath, '--profile', 'legacy-static', '--format', 'json')
    },
    [ordered]@{
      Id = 'find-usages-allfiles'
      Feature = 'find-usages'
      Description = 'Find usages for routine AllFiles'
      Arguments = @('find-usages', '--project', $ProjectPath, '--symbol', 'AllFiles', '--format', 'json')
    },
    [ordered]@{
      Id = 'find-usages-sourcevarrecptr'
      Feature = 'find-usages'
      Description = 'Find usages for type alias SourceVarRecPtr'
      Arguments = @('find-usages', '--project', $ProjectPath, '--symbol', 'SourceVarRecPtr', '--format', 'json')
    },
    [ordered]@{
      Id = 'rename-dry-run-allfiles'
      Feature = 'rename'
      Description = 'Dry-run rename plan for routine AllFiles'
      Arguments = @('rename', '--project', $ProjectPath, '--symbol', 'AllFiles', '--new-name', 'BenchmarkRenameAllFiles', '--format', 'json')
    },
    [ordered]@{
      Id = 'rename-dry-run-sourcevarrecptr'
      Feature = 'rename'
      Description = 'Dry-run rename plan for type alias SourceVarRecPtr'
      Arguments = @('rename', '--project', $ProjectPath, '--symbol', 'SourceVarRecPtr', '--new-name', 'TBenchmarkRenameSourceVarRecPtr', '--format', 'json')
    }
  )
}

function Get-JsonCount {
  param([object]$Json)

  if (($Json.PSObject.Properties.Name -contains 'operation') -and ($Json.operation -eq 'remove-with')) {
    if (($Json.PSObject.Properties.Name -contains 'mode') -and ($Json.mode -eq 'plan')) {
      if ($Json.PSObject.Properties.Name -contains 'plannedEdits') {
        return [string]@($Json.plannedEdits).Count
      }
    }

    if ($Json.PSObject.Properties.Name -contains 'withStatements') {
      return [string]@($Json.withStatements).Count
    }
  }

  foreach ($lName in @('count', 'usageCount', 'editCount', 'candidateCount')) {
    if ($Json.PSObject.Properties.Name -contains $lName) {
      return [string]$Json.$lName
    }
  }

  foreach ($lName in @('usages', 'references', 'edits', 'candidates')) {
    if ($Json.PSObject.Properties.Name -contains $lName) {
      return [string]@($Json.$lName).Count
    }
  }

  if (($Json.PSObject.Properties.Name -contains 'plan') -and ($null -ne $Json.plan)) {
    foreach ($lName in @('edits', 'changes')) {
      if ($Json.plan.PSObject.Properties.Name -contains $lName) {
        return [string]@($Json.plan.$lName).Count
      }
    }
  }

  return ''
}

function Read-ResultCount {
  param([string]$Path)

  try {
    $lText = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($lText)) {
      return ''
    }

    $lJson = $lText | ConvertFrom-Json
    return Get-JsonCount $lJson
  } catch {
    return ''
  }
}

function Get-JsonReferenceFallbackCount {
  param([object]$Json)

  if ($Json.PSObject.Properties.Name -contains 'referenceReconciliationFallbackCount') {
    return [string]$Json.referenceReconciliationFallbackCount
  }

  if (($Json.PSObject.Properties.Name -contains 'metrics') -and ($null -ne $Json.metrics) -and
      ($Json.metrics.PSObject.Properties.Name -contains 'referenceReconciliationFallbackCount')) {
    return [string]$Json.metrics.referenceReconciliationFallbackCount
  }

  return ''
}

function Get-JsonNumericProperty {
  param(
    [object]$Json,
    [string]$Name
  )

  if ($Json.PSObject.Properties.Name -contains $Name) {
    return [string]$Json.$Name
  }

  return ''
}

function Read-ReferenceFallbackCount {
  param([string]$Path)

  try {
    $lText = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($lText)) {
      return ''
    }

    $lJson = $lText | ConvertFrom-Json
    return Get-JsonReferenceFallbackCount $lJson
  } catch {
    return ''
  }
}

function Read-SemanticCacheMetric {
  param(
    [string]$Path,
    [string]$Name
  )

  try {
    $lText = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($lText)) {
      return ''
    }

    $lJson = $lText | ConvertFrom-Json
    return Get-JsonNumericProperty -Json $lJson -Name $Name
  } catch {
    return ''
  }
}

function Export-RemoveWithPlanParityReport {
  param(
    [object[]]$RunRows,
    [string]$OutputDirectory
  )

  $lPlanRuns = @($RunRows | Where-Object {
    ($_.Id -eq 'remove-with-plan-all') -and
    ($_.ExitCode -eq 0) -and
    (-not [string]::IsNullOrWhiteSpace($_.Stdout)) -and
    (Test-Path -LiteralPath $_.Stdout -PathType Leaf)
  })
  if ($lPlanRuns.Count -eq 0) {
    return
  }

  $lRun = $lPlanRuns[0]
  try {
    $lJson = Get-Content -LiteralPath $lRun.Stdout -Raw | ConvertFrom-Json
  } catch {
    return
  }

  if (-not ($lJson.PSObject.Properties.Name -contains 'semanticDtoParity')) {
    return
  }

  $lParity = $lJson.semanticDtoParity
  $lReport = [ordered]@{
    status = $lParity.status
    withStatementCount = @($lJson.withStatements).Count
    plannedEditCount = @($lJson.plannedEdits).Count
    mismatchCount = [int]$lParity.mismatchCount
    summaryText = $lParity.summaryText
    mismatches = $lParity.mismatches
    source = $lRun.Stdout
  }

  $lReport | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'parity.json') `
    -Encoding UTF8
}

function Read-SemanticPhaseMetrics {
  param([string]$Path)

  try {
    $lText = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($lText)) {
      return $null
    }

    $lJson = $lText | ConvertFrom-Json
    if ($lJson.PSObject.Properties.Name -contains 'semanticPhaseMetrics') {
      return $lJson.semanticPhaseMetrics
    }
  } catch {
    return $null
  }

  return $null
}

function Read-PlannerPhaseMetrics {
  param([string]$Path)

  try {
    $lText = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($lText)) {
      return $null
    }

    $lJson = $lText | ConvertFrom-Json
    if ($lJson.PSObject.Properties.Name -contains 'plannerPhaseMetrics') {
      return $lJson.plannerPhaseMetrics
    }
  } catch {
    return $null
  }

  return $null
}

function Requires-ReferenceFallbackCount {
  param([object]$Row)

  return @('find-usages', 'rename', 'dead-code-detection') -contains $Row.Feature
}

function Requires-PlannerPhaseMetrics {
  param([object]$Row)

  return ($Row.Feature -eq 'with-removal') -and ($Row.Id -eq 'remove-with-plan-all')
}

function Get-Median {
  param([double[]]$Values)

  if ($Values.Count -eq 0) {
    return 0
  }

  $lValues = @($Values | Sort-Object)
  $lMiddle = [int][Math]::Floor($lValues.Count / 2)
  if (($lValues.Count % 2) -eq 1) {
    return $lValues[$lMiddle]
  }

  return ($lValues[$lMiddle - 1] + $lValues[$lMiddle]) / 2
}

function ConvertTo-MarkdownTable {
  param([object[]]$Rows)

  $lCulture = [System.Globalization.CultureInfo]::InvariantCulture
  $lLines = New-Object System.Collections.Generic.List[string]
  $lLines.Add('| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks |')
  $lLines.Add('|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|')
  foreach ($lRow in $Rows) {
    $lCount = if ([string]::IsNullOrWhiteSpace($lRow.ResultCount)) { '' } else { $lRow.ResultCount }
    $lHits = if ([string]::IsNullOrWhiteSpace($lRow.SemanticCacheHits)) { '' } else { $lRow.SemanticCacheHits }
    $lMisses = if ([string]::IsNullOrWhiteSpace($lRow.SemanticCacheMisses)) { '' } else { $lRow.SemanticCacheMisses }
    $lFallbacks = if ([string]::IsNullOrWhiteSpace($lRow.ReferenceFallbackCount)) { '' } else { $lRow.ReferenceFallbackCount }
    $lTargetSeconds = if (($lRow.PSObject.Properties.Name -contains 'TargetSeconds') -and
        -not [string]::IsNullOrWhiteSpace($lRow.TargetSeconds)) {
      ([double]$lRow.TargetSeconds).ToString('F3', $lCulture)
    } else {
      ''
    }
    $lTargetStatus = if (($lRow.PSObject.Properties.Name -contains 'TargetStatus') -and
        -not [string]::IsNullOrWhiteSpace($lRow.TargetStatus)) { $lRow.TargetStatus } else { '' }
    $lMedian = ([double]$lRow.MedianSeconds).ToString('F3', $lCulture)
    $lMin = ([double]$lRow.MinSeconds).ToString('F3', $lCulture)
    $lMax = ([double]$lRow.MaxSeconds).ToString('F3', $lCulture)
    $lLines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} | {14} |' -f $lRow.Feature, $lRow.Id, $lRow.CacheMode, $lRow.Runs, $lRow.Status, $lRow.ExitCode, $lMedian, $lTargetSeconds, $lTargetStatus, $lMin, $lMax, $lCount, $lHits, $lMisses, $lFallbacks))
  }

  return ($lLines -join [Environment]::NewLine)
}

function Format-BenchmarkTimestamp {
  param([object]$Value)

  if ($Value -is [datetime]) {
    return $Value.ToString('o')
  }

  return [string]$Value
}

function Remove-ColdCacheArtifacts {
  param(
    [string]$CacheDirectory,
    [string]$OutputDirectory
  )

  $lCachePath = [System.IO.Path]::GetFullPath($CacheDirectory)
  $lOutputPath = [System.IO.Path]::GetFullPath($OutputDirectory)
  if (-not $lCachePath.StartsWith($lOutputPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to remove cache outside benchmark output directory: $CacheDirectory"
  }

  if (Test-Path -LiteralPath $CacheDirectory) {
    Remove-Item -LiteralPath $CacheDirectory -Recurse -Force
  }
}

function New-SummaryRows {
  param([object[]]$RunRows)

  $lSummaryRows = New-Object System.Collections.Generic.List[object]
  $lGroups = $RunRows | Group-Object Id, CacheMode
  foreach ($lGroup in $lGroups) {
    $lRows = @($lGroup.Group)
    $lSeconds = @($lRows | ForEach-Object { [double]$_.ElapsedSeconds })
    $lFirst = $lRows[0]
    $lExit = if (@($lRows | Where-Object { $_.ExitCode -ne 0 }).Count -gt 0) { 1 } else { 0 }
    $lStatus = if ($lExit -eq 0) { 'passed' } else { 'failed' }
    $lMedianSeconds = [Math]::Round((Get-Median -Values $lSeconds), 3)
    $lTargetSeconds = ''
    $lTargetStatus = ''
    if ($lFirst.CacheMode -eq 'warm') {
      $lTargetSeconds = [Math]::Round($WarmTargetSeconds, 3)
      if ($lStatus -ne 'passed') {
        $lTargetStatus = 'not-run'
      } elseIf ($lMedianSeconds -le $WarmTargetSeconds) {
        $lTargetStatus = 'met'
      } else {
        $lTargetStatus = 'missed'
      }
    }
    $lSummaryRows.Add([pscustomobject]@{
      Id = $lFirst.Id
      Feature = $lFirst.Feature
      Description = $lFirst.Description
      CacheMode = $lFirst.CacheMode
      Runs = $lRows.Count
      Status = $lStatus
      ExitCode = $lExit
      MedianSeconds = $lMedianSeconds
      TargetSeconds = $lTargetSeconds
      TargetStatus = $lTargetStatus
      MinSeconds = [Math]::Round((@($lSeconds | Measure-Object -Minimum).Minimum), 3)
      MaxSeconds = [Math]::Round((@($lSeconds | Measure-Object -Maximum).Maximum), 3)
      ResultCount = $lFirst.ResultCount
      SemanticCacheHits = $lFirst.SemanticCacheHits
      SemanticCacheMisses = $lFirst.SemanticCacheMisses
      ReferenceFallbackCount = $lFirst.ReferenceFallbackCount
      PlannerPhaseMetrics = if ($lFirst.PSObject.Properties.Name -contains 'PlannerPhaseMetrics') { $lFirst.PlannerPhaseMetrics } else { $null }
      Command = $lFirst.Command
    })
  }

  return @($lSummaryRows.ToArray())
}

function Get-BenchmarkArguments {
  param(
    [object]$Benchmark,
    [string]$CacheMode,
    [string]$SemanticCacheFile
  )

  $lArguments = New-Object System.Collections.Generic.List[string]
  $lArguments.AddRange([string[]]$Benchmark.Arguments)
  if ($CacheMode -ne 'default') {
    $lArguments.Add('--semantic-cache')
    $lArguments.Add($SemanticCacheFile)
  }

  return @($lArguments.ToArray())
}

if ($Repeat -lt 1) {
  throw 'Repeat must be at least 1.'
}

if (-not (Test-Path -LiteralPath $DakExe -PathType Leaf)) {
  throw "DAK executable not found: $DakExe"
}

if (-not (Test-Path -LiteralPath $Project -PathType Leaf)) {
  throw "Project fixture not found: $Project"
}

$lWorkflowFilter = @(Split-ArgumentValues -Values $Workflow)
$lCacheModes = @(Split-ArgumentValues -Values $CacheMode)
if ($lCacheModes.Count -eq 0) {
  $lCacheModes = @('default')
}
foreach ($lCacheMode in $lCacheModes) {
  if (@('default', 'cold', 'warm') -notcontains $lCacheMode) {
    throw "Unknown cache mode: $lCacheMode"
  }
}

$lBenchmarks = @(New-BenchmarkDefinitions -ProjectPath $Project)
if ($lWorkflowFilter.Count -gt 0) {
  $lKnown = @($lBenchmarks | ForEach-Object { $_.Id })
  foreach ($lWorkflow in $lWorkflowFilter) {
    if ($lKnown -notcontains $lWorkflow) {
      throw "Unknown workflow: $lWorkflow"
    }
  }
  $lBenchmarks = @($lBenchmarks | Where-Object { $lWorkflowFilter -contains $_.Id })
}

if ($List) {
  $lBenchmarks | ForEach-Object {
    [pscustomobject]@{
      Id = $_.Id
      Feature = $_.Feature
      Description = $_.Description
      Command = ('{0} {1}' -f $DakExe, ($_.Arguments -join ' '))
    }
  } | Format-Table -AutoSize
  exit 0
}

$lOutputDir = Resolve-OutputPath $OutputDir
New-Item -ItemType Directory -Force -Path $lOutputDir | Out-Null
$lJsonPath = Join-Path $lOutputDir 'baseline.json'
$lMarkdownPath = Join-Path $lOutputDir 'baseline.md'
$lRunRows = @()

if ($SummarizeOnly) {
  if (-not (Test-Path -LiteralPath $lJsonPath -PathType Leaf)) {
    throw "Existing baseline JSON not found: $lJsonPath"
  }

  $lExistingSummary = Get-Content -LiteralPath $lJsonPath -Raw | ConvertFrom-Json
  if ($lExistingSummary.PSObject.Properties.Name -contains 'runs') {
    $lRunRows = @($lExistingSummary.runs)
  } else {
    $lRunRows = @($lExistingSummary.results)
    foreach ($lRow in $lRunRows) {
      if (-not ($lRow.PSObject.Properties.Name -contains 'CacheMode')) {
        Add-Member -InputObject $lRow -NotePropertyName CacheMode -NotePropertyValue 'default'
      }
      if (-not ($lRow.PSObject.Properties.Name -contains 'CacheDirectory')) {
        Add-Member -InputObject $lRow -NotePropertyName CacheDirectory -NotePropertyValue ''
      }
    }
  }
  foreach ($lRow in $lRunRows) {
    if (-not ($lRow.PSObject.Properties.Name -contains 'Status')) {
      $lStatus = if (($lRow.PSObject.Properties.Name -contains 'ExitCode') -and ($lRow.ExitCode -eq 0)) { 'passed' } else { 'failed' }
      Add-Member -InputObject $lRow -NotePropertyName Status -NotePropertyValue $lStatus
    }
    if (($lRow.PSObject.Properties.Name -contains 'Stdout') -and (Test-Path -LiteralPath $lRow.Stdout -PathType Leaf)) {
      $lRow.ResultCount = Read-ResultCount -Path $lRow.Stdout
      if (-not ($lRow.PSObject.Properties.Name -contains 'ReferenceFallbackCount')) {
        Add-Member -InputObject $lRow -NotePropertyName ReferenceFallbackCount -NotePropertyValue ''
      }
      if (-not ($lRow.PSObject.Properties.Name -contains 'SemanticCacheHits')) {
        Add-Member -InputObject $lRow -NotePropertyName SemanticCacheHits -NotePropertyValue ''
      }
      if (-not ($lRow.PSObject.Properties.Name -contains 'SemanticCacheMisses')) {
        Add-Member -InputObject $lRow -NotePropertyName SemanticCacheMisses -NotePropertyValue ''
      }
      if (-not ($lRow.PSObject.Properties.Name -contains 'SemanticPhaseMetrics')) {
        Add-Member -InputObject $lRow -NotePropertyName SemanticPhaseMetrics -NotePropertyValue $null
      }
      if (-not ($lRow.PSObject.Properties.Name -contains 'PlannerPhaseMetrics')) {
        Add-Member -InputObject $lRow -NotePropertyName PlannerPhaseMetrics -NotePropertyValue $null
      }
      $lRow.ReferenceFallbackCount = Read-ReferenceFallbackCount -Path $lRow.Stdout
      $lRow.SemanticCacheHits = Read-SemanticCacheMetric -Path $lRow.Stdout -Name 'semanticCacheHits'
      $lRow.SemanticCacheMisses = Read-SemanticCacheMetric -Path $lRow.Stdout -Name 'semanticCacheMisses'
      $lRow.SemanticPhaseMetrics = Read-SemanticPhaseMetrics -Path $lRow.Stdout
      $lRow.PlannerPhaseMetrics = Read-PlannerPhaseMetrics -Path $lRow.Stdout
      if (($lRow.ExitCode -eq 0) -and (Requires-ReferenceFallbackCount -Row $lRow) -and
          [string]::IsNullOrWhiteSpace($lRow.ReferenceFallbackCount)) {
        throw "Missing referenceReconciliationFallbackCount in successful benchmark output: $($lRow.Stdout)"
      }
      if (($lRow.ExitCode -eq 0) -and (Requires-PlannerPhaseMetrics -Row $lRow) -and
          ($null -eq $lRow.PlannerPhaseMetrics)) {
        throw "Missing plannerPhaseMetrics in successful benchmark output: $($lRow.Stdout)"
      }
    } elseif (-not ($lRow.PSObject.Properties.Name -contains 'ReferenceFallbackCount')) {
      Add-Member -InputObject $lRow -NotePropertyName ReferenceFallbackCount -NotePropertyValue ''
    }
  }
  $lResultRows = New-SummaryRows -RunRows $lRunRows

  $lSummary = [ordered]@{
    name = $lExistingSummary.name
    startedAt = Format-BenchmarkTimestamp $lExistingSummary.startedAt
    completedAt = Format-BenchmarkTimestamp $lExistingSummary.completedAt
    elapsedSeconds = $lExistingSummary.elapsedSeconds
    dakExe = $lExistingSummary.dakExe
    project = $lExistingSummary.project
    repeat = $lExistingSummary.repeat
    cacheModes = if ($lExistingSummary.PSObject.Properties.Name -contains 'cacheModes') { $lExistingSummary.cacheModes } else { @('default') }
    cacheDirectory = if ($lExistingSummary.PSObject.Properties.Name -contains 'cacheDirectory') { $lExistingSummary.cacheDirectory } else { '' }
    machine = if ($lExistingSummary.PSObject.Properties.Name -contains 'machine') { $lExistingSummary.machine } else { $env:COMPUTERNAME }
    delphiSemanticsSha = if ($lExistingSummary.PSObject.Properties.Name -contains 'delphiSemanticsSha') { $lExistingSummary.delphiSemanticsSha } else { Get-GitSha -Path (Get-Location) }
    dakSha = if ($lExistingSummary.PSObject.Properties.Name -contains 'dakSha') { $lExistingSummary.dakSha } else { Get-GitSha -Path (Split-Path (Split-Path $DakExe -Parent) -Parent) }
    results = $lResultRows
    runs = $lRunRows
  }
} else {
  $lStartedAt = Get-Date
  $lRows = New-Object System.Collections.Generic.List[object]
  $lRunsJsonlPath = Join-Path $lOutputDir 'runs.jsonl'
  if (Test-Path -LiteralPath $lRunsJsonlPath) {
    Remove-Item -LiteralPath $lRunsJsonlPath
  }

  $lCacheDirectory = Join-Path $lOutputDir 'semantic-cache'
  $lSemanticCacheFile = Join-Path $lCacheDirectory 'unit-models.sqlite3'
  foreach ($lCacheMode in $lCacheModes) {
    New-Item -ItemType Directory -Force -Path $lCacheDirectory | Out-Null

    foreach ($lBenchmark in $lBenchmarks) {
      if (($lCacheMode -eq 'warm') -and (-not (Test-Path -LiteralPath $lSemanticCacheFile -PathType Leaf))) {
        $lWarmupId = '{0}-{1}-warmup' -f $lBenchmark.Id, $lCacheMode
        $lWarmupStdout = Join-Path $lOutputDir ($lWarmupId + '.stdout.json')
        $lWarmupStderr = Join-Path $lOutputDir ($lWarmupId + '.stderr.txt')
        $env:DELPHISEMANTICS_BENCHMARK_CACHE_DIR = $lCacheDirectory
        $env:DELPHISEMANTICS_BENCHMARK_CACHE_MODE = $lCacheMode
        $lWarmupArguments = @(Get-BenchmarkArguments -Benchmark $lBenchmark -CacheMode $lCacheMode -SemanticCacheFile $lSemanticCacheFile)
        & $DakExe @($lWarmupArguments) 1> $lWarmupStdout 2> $lWarmupStderr
        $lWarmupExitCode = $LASTEXITCODE
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_MODE -ErrorAction SilentlyContinue
        if ($lWarmupExitCode -ne 0) {
          throw "Warm-cache priming failed for $($lBenchmark.Id). See: $lWarmupStderr"
        }
        if ((Requires-ReferenceFallbackCount -Row $lBenchmark) -and
            [string]::IsNullOrWhiteSpace((Read-ReferenceFallbackCount -Path $lWarmupStdout))) {
          throw "Warm-cache priming output is missing referenceReconciliationFallbackCount: $lWarmupStdout"
        }
        if ((Requires-PlannerPhaseMetrics -Row $lBenchmark) -and
            ($null -eq (Read-PlannerPhaseMetrics -Path $lWarmupStdout))) {
          throw "Warm-cache priming output is missing plannerPhaseMetrics: $lWarmupStdout"
        }
      }

      for ($i = 1; $i -le $Repeat; $i++) {
        if ($lCacheMode -eq 'cold') {
          Remove-ColdCacheArtifacts -CacheDirectory $lCacheDirectory -OutputDirectory $lOutputDir
          New-Item -ItemType Directory -Force -Path $lCacheDirectory | Out-Null
        }

        $lRunId = '{0}-{1}-run{2}' -f $lBenchmark.Id, $lCacheMode, $i
        $lStdout = Join-Path $lOutputDir ($lRunId + '.stdout.json')
        $lStderr = Join-Path $lOutputDir ($lRunId + '.stderr.txt')

        $env:DELPHISEMANTICS_BENCHMARK_CACHE_DIR = $lCacheDirectory
        $env:DELPHISEMANTICS_BENCHMARK_CACHE_MODE = $lCacheMode
        $lStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $lArguments = @(Get-BenchmarkArguments -Benchmark $lBenchmark -CacheMode $lCacheMode -SemanticCacheFile $lSemanticCacheFile)
        & $DakExe @($lArguments) 1> $lStdout 2> $lStderr
        $lExitCode = $LASTEXITCODE
        $lStopwatch.Stop()
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_MODE -ErrorAction SilentlyContinue
        $lReferenceFallbackCount = Read-ReferenceFallbackCount -Path $lStdout
        $lSemanticCacheHits = Read-SemanticCacheMetric -Path $lStdout -Name 'semanticCacheHits'
        $lSemanticCacheMisses = Read-SemanticCacheMetric -Path $lStdout -Name 'semanticCacheMisses'
        $lSemanticPhaseMetrics = Read-SemanticPhaseMetrics -Path $lStdout
        $lPlannerPhaseMetrics = Read-PlannerPhaseMetrics -Path $lStdout
        if (($lExitCode -eq 0) -and (Requires-ReferenceFallbackCount -Row $lBenchmark) -and
            [string]::IsNullOrWhiteSpace($lReferenceFallbackCount)) {
          throw "Missing referenceReconciliationFallbackCount in successful benchmark output: $lStdout"
        }
        if (($lExitCode -eq 0) -and (Requires-PlannerPhaseMetrics -Row $lBenchmark) -and
            ($null -eq $lPlannerPhaseMetrics)) {
          throw "Missing plannerPhaseMetrics in successful benchmark output: $lStdout"
        }

        $lRow = [pscustomobject]@{
          Id = $lBenchmark.Id
          Run = $i
          Feature = $lBenchmark.Feature
          Description = $lBenchmark.Description
          CacheMode = $lCacheMode
          CacheDirectory = $lCacheDirectory
          Status = if ($lExitCode -eq 0) { 'passed' } else { 'failed' }
          ExitCode = $lExitCode
          ElapsedSeconds = [Math]::Round($lStopwatch.Elapsed.TotalSeconds, 3)
          ResultCount = Read-ResultCount -Path $lStdout
          SemanticCacheHits = $lSemanticCacheHits
          SemanticCacheMisses = $lSemanticCacheMisses
          ReferenceFallbackCount = $lReferenceFallbackCount
          SemanticPhaseMetrics = $lSemanticPhaseMetrics
          PlannerPhaseMetrics = $lPlannerPhaseMetrics
          Stdout = $lStdout
          Stderr = $lStderr
          Command = ('{0} {1}' -f $DakExe, ($lArguments -join ' '))
        }
        $lRows.Add($lRow)
        $lRow | ConvertTo-Json -Depth 5 -Compress | Add-Content -LiteralPath $lRunsJsonlPath -Encoding UTF8
      }
    }
  }

  $lCompletedAt = Get-Date
  $lRunRows = @($lRows.ToArray())
  $lResultRows = New-SummaryRows -RunRows $lRunRows
  $lDakRoot = Split-Path (Split-Path $DakExe -Parent) -Parent
  $lSummary = [ordered]@{
    name = 'maxTdb semantic workflow benchmark'
    startedAt = $lStartedAt.ToString('o')
    completedAt = $lCompletedAt.ToString('o')
    elapsedSeconds = [Math]::Round(($lCompletedAt - $lStartedAt).TotalSeconds, 3)
    dakExe = $DakExe
    project = $Project
    repeat = $Repeat
    cacheModes = $lCacheModes
    warmTargetSeconds = $WarmTargetSeconds
    cacheDirectory = $lCacheDirectory
    machine = $env:COMPUTERNAME
    delphiSemanticsSha = Get-GitSha -Path (Get-Location)
    dakSha = Get-GitSha -Path $lDakRoot
    results = $lResultRows
    runs = $lRunRows
  }
}

$lSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lJsonPath -Encoding UTF8
Export-RemoveWithPlanParityReport -RunRows $lRunRows -OutputDirectory $lOutputDir

$lWarmTargetSeconds = $WarmTargetSeconds
if (($lSummary -is [System.Collections.IDictionary]) -and $lSummary.Contains('warmTargetSeconds')) {
  $lWarmTargetSeconds = [double]$lSummary.warmTargetSeconds
} elseif ($lSummary.PSObject.Properties.Name -contains 'warmTargetSeconds') {
  $lWarmTargetSeconds = [double]$lSummary.warmTargetSeconds
}

$lMarkdown = @(
  '# maxTdb semantic workflow benchmark baseline'
  ''
  ('Started: `{0}`' -f $lSummary.startedAt)
  ('Completed: `{0}`' -f $lSummary.completedAt)
  ('DAK: `{0}`' -f $DakExe)
  ('Project: `{0}`' -f $Project)
  ('Machine: `{0}`' -f $lSummary.machine)
  ('DelphiSemantics SHA: `{0}`' -f $lSummary.delphiSemanticsSha)
  ('DAK SHA: `{0}`' -f $lSummary.dakSha)
  ('Warm target: `{0}` seconds' -f ([double]$lWarmTargetSeconds).ToString('F3',
    [System.Globalization.CultureInfo]::InvariantCulture))
  ('Cache directory: `{0}`' -f $lSummary.cacheDirectory)
  ''
  (ConvertTo-MarkdownTable -Rows $lResultRows)
  ''
  'Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.'
) -join [Environment]::NewLine
$lMarkdown | Set-Content -LiteralPath $lMarkdownPath -Encoding UTF8

if ((-not $NoBaselineCopy) -and ($lWorkflowFilter.Count -eq 0) -and ($OutputDir -eq '.dak\benchmarks\maxtdb-semantic')) {
  $lBaselineDir = Join-Path (Get-Location) 'docs\benchmarks'
  New-Item -ItemType Directory -Force -Path $lBaselineDir | Out-Null
  Copy-Item -LiteralPath $lJsonPath -Destination (Join-Path $lBaselineDir 'maxtdb-semantic-baseline.json') -Force
  Copy-Item -LiteralPath $lMarkdownPath -Destination (Join-Path $lBaselineDir 'maxtdb-semantic-baseline.md') -Force
} elseif (-not $NoBaselineCopy) {
  $lBaselineDir = Join-Path (Get-Location) 'docs\benchmarks'
  New-Item -ItemType Directory -Force -Path $lBaselineDir | Out-Null
  $lResultName = Split-Path $lOutputDir -Leaf
  if ([string]::IsNullOrWhiteSpace($lResultName)) {
    $lResultName = 'custom'
  }
  Copy-Item -LiteralPath $lJsonPath -Destination (Join-Path $lBaselineDir ('maxtdb-semantic-{0}.json' -f $lResultName)) -Force
  Copy-Item -LiteralPath $lMarkdownPath -Destination (Join-Path $lBaselineDir ('maxtdb-semantic-{0}.md' -f $lResultName)) -Force
}

ConvertTo-MarkdownTable -Rows $lResultRows
Write-Host ''
Write-Host "Baseline JSON: $lJsonPath"
Write-Host "Baseline Markdown: $lMarkdownPath"

if (@($lResultRows | Where-Object { $_.ExitCode -ne 0 }).Count -gt 0) {
  exit 1
}

if (@($lResultRows | Where-Object { $_.TargetStatus -eq 'missed' }).Count -gt 0) {
  exit 2
}
