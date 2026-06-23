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
  [switch]$AllowHistoricalSummary,
  [switch]$AllowHistoricalPromotion,
  [switch]$PromoteBaseline,
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

function Test-GitDirty {
  param([string]$Path)

  try {
    $lRepositoryRoot = git -C $Path rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -ne 0) {
      return $false
    }
    $lExpectedRoot = [IO.Path]::GetFullPath($Path).TrimEnd([IO.Path]::DirectorySeparatorChar,
      [IO.Path]::AltDirectorySeparatorChar)
    $lActualRoot = [IO.Path]::GetFullPath([string]$lRepositoryRoot).TrimEnd(
      [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)
    if ($lActualRoot -ne $lExpectedRoot) {
      return $false
    }

    git -C $Path diff --quiet --ignore-submodules -- 2>$null
    if ($LASTEXITCODE -ne 0) {
      return $true
    }

    git -C $Path diff --cached --quiet --ignore-submodules -- 2>$null
    if ($LASTEXITCODE -ne 0) {
      return $true
    }

    $lUntracked = @(git -C $Path ls-files --others --exclude-standard 2>$null)
    if ($LASTEXITCODE -ne 0) {
      return $true
    }

    return $lUntracked.Count -gt 0
  } catch {
    Write-Verbose "Unable to read git dirty state from $Path"
  }

  return $false
}

function Get-ObjectPropertyValue {
  param(
    [object]$Object,
    [string]$Name,
    [object]$Default = ''
  )

  if (($null -ne $Object) -and ($Object.PSObject.Properties.Name -contains $Name)) {
    return $Object.$Name
  }

  return $Default
}

function Test-BenchmarkProvenance {
  param(
    [string]$StoredDelphiSemanticsSha,
    [string]$StoredDakSha,
    [string]$CurrentDelphiSemanticsSha,
    [string]$CurrentDakSha,
    [switch]$AllowHistorical
  )

  $lMismatches = New-Object System.Collections.Generic.List[string]
  if ((-not [string]::IsNullOrWhiteSpace($StoredDelphiSemanticsSha)) -and
      (-not [string]::IsNullOrWhiteSpace($CurrentDelphiSemanticsSha)) -and
      ($StoredDelphiSemanticsSha -ne $CurrentDelphiSemanticsSha)) {
    $lMismatches.Add("DelphiSemantics stored=$StoredDelphiSemanticsSha current=$CurrentDelphiSemanticsSha")
  }
  if ((-not [string]::IsNullOrWhiteSpace($StoredDakSha)) -and
      (-not [string]::IsNullOrWhiteSpace($CurrentDakSha)) -and
      ($StoredDakSha -ne $CurrentDakSha)) {
    $lMismatches.Add("DAK stored=$StoredDakSha current=$CurrentDakSha")
  }

  if (($lMismatches.Count -gt 0) -and (-not $AllowHistorical)) {
    throw "SummarizeOnly baseline provenance is stale. Re-run the benchmark or pass -AllowHistoricalSummary to summarize historical artifacts. $($lMismatches -join '; ')"
  }

  if ($lMismatches.Count -gt 0) {
    return [ordered]@{
      status = 'historical'
      mismatches = @($lMismatches.ToArray())
      currentDelphiSemanticsSha = $CurrentDelphiSemanticsSha
      currentDakSha = $CurrentDakSha
    }
  }

  return [ordered]@{
    status = 'current'
    mismatches = @()
    currentDelphiSemanticsSha = $CurrentDelphiSemanticsSha
    currentDakSha = $CurrentDakSha
  }
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
      # T-583: explicit multi-minute maxTdb proof lane; use -OutDir .dak\benchmarks\maxtdb-semantic\remove-with-plan-proof-lane.
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
    if (($Json.PSObject.Properties.Name -contains 'summary') -and ($null -ne $Json.summary)) {
      if (($Json.PSObject.Properties.Name -contains 'mode') -and ($Json.mode -eq 'plan') -and
          ($Json.summary.PSObject.Properties.Name -contains 'plannedEdits')) {
        return [string]$Json.summary.plannedEdits
      }
      if ($Json.summary.PSObject.Properties.Name -contains 'withStatements') {
        return [string]$Json.summary.withStatements
      }
    }

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

function Get-RemoveWithSummaryCount {
  param(
    [object]$Json,
    [string]$Name
  )

  if (($Json.PSObject.Properties.Name -contains 'summary') -and ($null -ne $Json.summary) -and
      ($Json.summary.PSObject.Properties.Name -contains $Name)) {
    return [int]$Json.summary.$Name
  }

  if ($Json.PSObject.Properties.Name -contains $Name) {
    return @($Json.$Name).Count
  }

  return 0
}

function Get-JsonArrayCount {
  param(
    [object]$Json,
    [string]$Name
  )

  if (-not ($Json.PSObject.Properties.Name -contains $Name)) {
    return 0
  }

  if ($null -eq $Json.$Name) {
    return 0
  }

  return @($Json.$Name).Count
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

function Get-BenchmarkPromotionBlocker {
  param(
    [object]$Summary,
    [string]$DelphiSemanticsRoot,
    [string]$DakRoot,
    [switch]$AllowHistoricalPromotion
  )

  $lBlockers = New-Object System.Collections.Generic.List[string]
  if (Test-GitDirty -Path $DelphiSemanticsRoot) {
    $lBlockers.Add("DelphiSemantics workspace is dirty: $DelphiSemanticsRoot")
  }
  if ((-not [string]::IsNullOrWhiteSpace($DakRoot)) -and (Test-GitDirty -Path $DakRoot)) {
    $lBlockers.Add("DAK workspace is dirty: $DakRoot")
  }

  $lProvenanceStatus = ''
  $lProvenance = $null
  if (($Summary -is [System.Collections.IDictionary]) -and $Summary.Contains('provenance')) {
    $lProvenance = $Summary.provenance
  } elseif (($null -ne $Summary) -and ($Summary.PSObject.Properties.Name -contains 'provenance')) {
    $lProvenance = $Summary.provenance
  }
  if (($lProvenance -is [System.Collections.IDictionary]) -and $lProvenance.Contains('status')) {
    $lProvenanceStatus = [string]$lProvenance.status
  } elseif (($null -ne $lProvenance) -and
      ($lProvenance.PSObject.Properties.Name -contains 'status')) {
    $lProvenanceStatus = [string]$lProvenance.status
  }
  if (($lProvenanceStatus -eq 'historical') -and (-not $AllowHistoricalPromotion)) {
    $lBlockers.Add('Benchmark provenance is historical; pass -AllowHistoricalPromotion to publish stale evidence intentionally.')
  }

  return @($lBlockers.ToArray())
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

function Get-RemoveWithSkipBuckets {
  param([object]$Json)

  if (-not ($Json.PSObject.Properties.Name -contains 'skipped') -or ($null -eq $Json.skipped)) {
    return @()
  }

  return @($Json.skipped |
    ForEach-Object {
      $lReason = ''
      if (($_.PSObject.Properties.Name -contains 'reason') -and
          -not [string]::IsNullOrWhiteSpace([string]$_.reason)) {
        $lReason = [string]$_.reason
      } else {
        $lReason = 'unknown'
      }
      [pscustomobject]@{ Reason = $lReason }
    } |
    Group-Object -Property Reason |
    Sort-Object Name |
    ForEach-Object {
      [ordered]@{
        reason = $_.Name
        count = $_.Count
      }
    })
}

function Export-RemoveWithPlanDogfoodReport {
  param(
    [object[]]$RunRows,
    [string]$OutputDirectory
  )

  $lPlanRuns = @($RunRows | Where-Object {
    ($_.Id -eq 'remove-with-plan-all') -and ($_.ExitCode -eq 0)
  })
  if ($lPlanRuns.Count -eq 0) {
    return
  }

  $lReports = New-Object System.Collections.Generic.List[object]
  foreach ($lCandidateRun in $lPlanRuns) {
    if ([string]::IsNullOrWhiteSpace($lCandidateRun.Stdout) -or
        (-not (Test-Path -LiteralPath $lCandidateRun.Stdout -PathType Leaf))) {
      throw "Missing remove-with plan benchmark output: $($lCandidateRun.Stdout)"
    }

    try {
      $lCandidateJson = Get-Content -LiteralPath $lCandidateRun.Stdout -Raw |
        ConvertFrom-Json
    } catch {
      throw "Unable to read remove-with plan benchmark output: $($lCandidateRun.Stdout)"
    }

    if (-not ($lCandidateJson.PSObject.Properties.Name -contains 'semanticDtoParity')) {
      throw "Missing semanticDtoParity in successful remove-with plan output: $($lCandidateRun.Stdout)"
    }

    $lCandidateParity = $lCandidateJson.semanticDtoParity
    if (-not ($lCandidateParity.PSObject.Properties.Name -contains 'mismatchCount')) {
      throw "Missing semanticDtoParity.mismatchCount in successful remove-with plan output: $($lCandidateRun.Stdout)"
    }

    $lWithStatementCount = Get-RemoveWithSummaryCount -Json $lCandidateJson `
      -Name 'withStatements'
    $lPlannedEditCount = Get-RemoveWithSummaryCount -Json $lCandidateJson `
      -Name 'plannedEdits'
    $lSkippedCount = Get-RemoveWithSummaryCount -Json $lCandidateJson `
      -Name 'skipped'
    $lPlannedArrayCount = Get-JsonArrayCount -Json $lCandidateJson -Name 'plannedEdits'
    $lSkippedArrayCount = Get-JsonArrayCount -Json $lCandidateJson -Name 'skipped'
    $lMismatchCount = [int]$lCandidateParity.mismatchCount
    if ($lMismatchCount -ne 0) {
      throw ('remove-with plan semantic DTO parity failed in {0}: mismatchCount={1}' -f
        $lCandidateRun.Stdout, $lMismatchCount)
    }

    if ($lPlannedArrayCount -ne $lPlannedEditCount) {
      throw ('remove-with plan report accounting mismatch in {0}: summary.plannedEdits={1}, plannedEdits array={2}' -f
        $lCandidateRun.Stdout, $lPlannedEditCount, $lPlannedArrayCount)
    }

    if ($lSkippedArrayCount -ne $lSkippedCount) {
      throw ('remove-with plan report accounting mismatch in {0}: summary.skipped={1}, skipped array={2}' -f
        $lCandidateRun.Stdout, $lSkippedCount, $lSkippedArrayCount)
    }

    $lAccountedCount = $lPlannedEditCount + $lSkippedCount
    $lUnaccountedCount = $lWithStatementCount - $lAccountedCount
    $lCompletenessStatus = if ($lUnaccountedCount -eq 0) { 'complete' } else { 'incomplete' }
    if ($lUnaccountedCount -ne 0) {
      throw ('remove-with plan accounting incomplete in {0}: discovered={1}, planned={2}, skipped={3}, unaccounted={4}' -f
        $lCandidateRun.Stdout, $lWithStatementCount, $lPlannedEditCount, $lSkippedCount,
        $lUnaccountedCount)
    }

    $lReports.Add([ordered]@{
      status = 'passed'
      run = $lCandidateRun.Run
      cacheMode = $lCandidateRun.CacheMode
      sourceMutationStatus = $lCandidateRun.SourceMutationStatus
      discoveredCount = $lWithStatementCount
      plannedCount = $lPlannedEditCount
      skippedCount = $lSkippedCount
      plannedArrayCount = $lPlannedArrayCount
      skippedArrayCount = $lSkippedArrayCount
      completeness = [ordered]@{
        status = $lCompletenessStatus
        accountedCount = $lAccountedCount
        unaccountedCount = $lUnaccountedCount
      }
      skipBuckets = @(Get-RemoveWithSkipBuckets -Json $lCandidateJson)
      semanticDtoParity = [ordered]@{
        status = $lCandidateParity.status
        mismatchCount = $lMismatchCount
        summaryText = $lCandidateParity.summaryText
        mismatches = $lCandidateParity.mismatches
      }
      source = $lCandidateRun.Stdout
    }) | Out-Null
  }

  $lReport = [ordered]@{
    status = 'passed'
    workflow = 'remove-with-plan-all'
    mode = 'dogfood'
    generatedAt = (Get-Date).ToString('o')
    runCount = $lReports.Count
    latest = $lReports[($lReports.Count - 1)]
    runs = @($lReports.ToArray())
  }

  $lReport | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $OutputDirectory 'dogfood.json') `
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

function Test-BestEffortTargetMiss {
  param([object]$Row)

  # T-582: keep remove-with-plan-all warm target misses as best-effort performance signals.
  return ($Row.Id -eq 'remove-with-plan-all') -and
    ($Row.CacheMode -eq 'warm') -and
    ($Row.TargetStatus -eq 'missed')
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
  $lLines.Add('| Feature | Benchmark | Cache mode | Runs | Status | Exit | Median seconds | Target seconds | Target status | Min | Max | Result count | Cache hits | Cache misses | Reference fallbacks | Snapshot SQL write ms | Snapshot SQL read ms | Snapshot deserialize ms | Snapshot index rebuild ms | Source mutation |')
  $lLines.Add('|---|---|---|---:|---|---:|---:|---:|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|')
  foreach ($lRow in $Rows) {
    $lCount = if ([string]::IsNullOrWhiteSpace($lRow.ResultCount)) { '' } else { $lRow.ResultCount }
    $lHits = if ([string]::IsNullOrWhiteSpace($lRow.SemanticCacheHits)) { '' } else { $lRow.SemanticCacheHits }
    $lMisses = if ([string]::IsNullOrWhiteSpace($lRow.SemanticCacheMisses)) { '' } else { $lRow.SemanticCacheMisses }
    $lFallbacks = if ([string]::IsNullOrWhiteSpace($lRow.ReferenceFallbackCount)) { '' } else { $lRow.ReferenceFallbackCount }
    $lSnapshotSqlWriteMs = if ([string]::IsNullOrWhiteSpace($lRow.SnapshotSqlWriteMs)) { '' } else { $lRow.SnapshotSqlWriteMs }
    $lSnapshotSqlReadMs = if ([string]::IsNullOrWhiteSpace($lRow.SnapshotSqlReadMs)) { '' } else { $lRow.SnapshotSqlReadMs }
    $lSnapshotDeserializeMs = if ([string]::IsNullOrWhiteSpace($lRow.SnapshotDeserializeMs)) { '' } else { $lRow.SnapshotDeserializeMs }
    $lSnapshotIndexRebuildMs = if ([string]::IsNullOrWhiteSpace($lRow.SnapshotIndexRebuildMs)) { '' } else { $lRow.SnapshotIndexRebuildMs }
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
    $lMutation = if (($lRow.PSObject.Properties.Name -contains 'SourceMutationStatus') -and
        -not [string]::IsNullOrWhiteSpace($lRow.SourceMutationStatus)) { $lRow.SourceMutationStatus } else { '' }
    $lLines.Add(('| {0} | {1} | {2} | {3} | {4} | {5} | {6} | {7} | {8} | {9} | {10} | {11} | {12} | {13} | {14} | {15} | {16} | {17} | {18} | {19} |' -f $lRow.Feature, $lRow.Id, $lRow.CacheMode, $lRow.Runs, $lRow.Status, $lRow.ExitCode, $lMedian, $lTargetSeconds, $lTargetStatus, $lMin, $lMax, $lCount, $lHits, $lMisses, $lFallbacks, $lSnapshotSqlWriteMs, $lSnapshotSqlReadMs, $lSnapshotDeserializeMs, $lSnapshotIndexRebuildMs, $lMutation))
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

function Get-ProjectSourceRoot {
  param([string]$ProjectPath)

  return Split-Path -Parent ([System.IO.Path]::GetFullPath($ProjectPath))
}

function Get-ProjectDprojPath {
  param([string]$ProjectPath)

  if ([System.IO.Path]::GetExtension($ProjectPath).Equals('.dproj',
      [System.StringComparison]::OrdinalIgnoreCase)) {
    return [System.IO.Path]::GetFullPath($ProjectPath)
  }

  $lCandidate = [System.IO.Path]::ChangeExtension($ProjectPath, '.dproj')
  if (Test-Path -LiteralPath $lCandidate -PathType Leaf) {
    return [System.IO.Path]::GetFullPath($lCandidate)
  }

  return ''
}

function Resolve-ProjectPathToken {
  param(
    [string]$BaseDirectory,
    [string]$Path
  )

  $lPath = $Path.Trim()
  if ([string]::IsNullOrWhiteSpace($lPath) -or $lPath.StartsWith('$(')) {
    return ''
  }

  if ([System.IO.Path]::IsPathRooted($lPath)) {
    return [System.IO.Path]::GetFullPath($lPath)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $BaseDirectory $lPath))
}

function Get-ProjectSearchPathDirectories {
  param([string]$ProjectPath)

  $lDprojPath = Get-ProjectDprojPath -ProjectPath $ProjectPath
  if ($lDprojPath -eq '') {
    return @()
  }

  $lDprojDirectory = Split-Path -Parent $lDprojPath
  $lDirectories = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
  $lText = Get-Content -LiteralPath $lDprojPath -Raw
  foreach ($lMatch in [regex]::Matches($lText,
      '<DCC_UnitSearchPath>(.*?)</DCC_UnitSearchPath>',
      [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
    foreach ($lPart in $lMatch.Groups[1].Value.Split(';')) {
      $lDirectory = Resolve-ProjectPathToken -BaseDirectory $lDprojDirectory `
        -Path $lPart
      if (($lDirectory -ne '') -and (Test-Path -LiteralPath $lDirectory -PathType Container)) {
        [void]$lDirectories.Add($lDirectory)
      }
    }
  }

  return @($lDirectories)
}

function Get-ProjectSourceFiles {
  param([string]$ProjectPath)

  $lRoot = Get-ProjectSourceRoot -ProjectPath $ProjectPath
  $lFiles = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
  if (-not (Test-Path -LiteralPath $lRoot -PathType Container)) {
    return @()
  }

  $lExtensions = @('.pas', '.dpr', '.dpk', '.inc', '.dfm', '.fmx')
  Get-ChildItem -LiteralPath $lRoot -Recurse -File | Where-Object {
    $lExtensions -contains $_.Extension.ToLowerInvariant()
  } | ForEach-Object { [void]$lFiles.Add($_.FullName) }

  foreach ($lDirectory in Get-ProjectSearchPathDirectories -ProjectPath $ProjectPath) {
    Get-ChildItem -LiteralPath $lDirectory -Recurse -File | Where-Object {
      $lExtensions -contains $_.Extension.ToLowerInvariant()
    } | ForEach-Object { [void]$lFiles.Add($_.FullName) }
  }

  if (Test-Path -LiteralPath $ProjectPath -PathType Leaf) {
    [void]$lFiles.Add([System.IO.Path]::GetFullPath($ProjectPath))
    $lProjectText = Get-Content -LiteralPath $ProjectPath -Raw
    foreach ($lMatch in [regex]::Matches($lProjectText, "\bin\s+'([^']+)'",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
      $lReferencedPath = $lMatch.Groups[1].Value
      if ([string]::IsNullOrWhiteSpace($lReferencedPath)) {
        Continue
      }

      $lFullPath = Resolve-ProjectPathToken -BaseDirectory $lRoot `
        -Path $lReferencedPath
      if ((Test-Path -LiteralPath $lFullPath -PathType Leaf) -and
          ($lExtensions -contains ([System.IO.Path]::GetExtension($lFullPath).ToLowerInvariant()))) {
        [void]$lFiles.Add($lFullPath)
      }
    }
  }

  return @($lFiles)
}

function New-SourceSnapshot {
  param([string]$ProjectPath)

  $lSnapshot = @{}
  foreach ($lPath in Get-ProjectSourceFiles -ProjectPath $ProjectPath) {
    $lSnapshot[$lPath] = [pscustomobject]@{
      Hash = (Get-FileHash -LiteralPath $lPath -Algorithm SHA256).Hash
      Bytes = [System.IO.File]::ReadAllBytes($lPath)
    }
  }

  return $lSnapshot
}

function Test-SourceSnapshotChanged {
  param(
    [string]$ProjectPath,
    [hashtable]$Snapshot
  )

  foreach ($lPath in Get-ProjectSourceFiles -ProjectPath $ProjectPath) {
    if (-not $Snapshot.ContainsKey($lPath)) {
      return $true
    }
  }

  foreach ($lPath in $Snapshot.Keys) {
    if (-not (Test-Path -LiteralPath $lPath -PathType Leaf)) {
      return $true
    }
    if ((Get-FileHash -LiteralPath $lPath -Algorithm SHA256).Hash -ne $Snapshot[$lPath].Hash) {
      return $true
    }
  }

  return $false
}

function Restore-SourceSnapshot {
  param(
    [string]$ProjectPath,
    [hashtable]$Snapshot
  )

  foreach ($lPath in $Snapshot.Keys) {
    $lExpected = $Snapshot[$lPath]
    if ((-not (Test-Path -LiteralPath $lPath -PathType Leaf)) -or
        ((Get-FileHash -LiteralPath $lPath -Algorithm SHA256).Hash -ne $lExpected.Hash)) {
      [System.IO.File]::WriteAllBytes($lPath, [byte[]]$lExpected.Bytes)
    }
  }

  foreach ($lPath in Get-ProjectSourceFiles -ProjectPath $ProjectPath) {
    if (-not $Snapshot.ContainsKey($lPath)) {
      Remove-Item -LiteralPath $lPath -Force
    }
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
    $lSuccessfulCounts = @($lRows | Where-Object {
      ($_.ExitCode -eq 0) -and (-not [string]::IsNullOrWhiteSpace($_.ResultCount))
    } | ForEach-Object { [string]$_.ResultCount } | Select-Object -Unique)
    if ($lSuccessfulCounts.Count -gt 1) {
      throw ('Result count drift for {0}/{1}: {2}' -f $lFirst.Id, $lFirst.CacheMode,
        ($lSuccessfulCounts -join ', '))
    }
    $lResultCount = if ($lSuccessfulCounts.Count -eq 1) { $lSuccessfulCounts[0] } else { $lFirst.ResultCount }
    $lMutationStatuses = @($lRows | Where-Object {
      $_.PSObject.Properties.Name -contains 'SourceMutationStatus'
    } | ForEach-Object { [string]$_.SourceMutationStatus } | Select-Object -Unique)
    $lMutationStatus = if ($lMutationStatuses.Count -eq 0) {
      ''
    } elseif (($lMutationStatuses.Count -eq 1) -and ($lMutationStatuses[0] -eq 'clean')) {
      'clean'
    } elseif ($lMutationStatuses -contains 'mutated') {
      'mutated'
    } else {
      ($lMutationStatuses -join ',')
    }
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
    $lPlannerPhaseMetrics = if ($lFirst.PSObject.Properties.Name -contains 'PlannerPhaseMetrics') {
      $lFirst.PlannerPhaseMetrics
    } else {
      $null
    }
    $lSnapshotSqlWriteMs = if (($null -ne $lPlannerPhaseMetrics) -and
        ($lPlannerPhaseMetrics.PSObject.Properties.Name -contains 'snapshotSqlWriteMs')) {
      $lPlannerPhaseMetrics.snapshotSqlWriteMs
    } else { '' }
    $lSnapshotSqlReadMs = if (($null -ne $lPlannerPhaseMetrics) -and
        ($lPlannerPhaseMetrics.PSObject.Properties.Name -contains 'snapshotSqlReadMs')) {
      $lPlannerPhaseMetrics.snapshotSqlReadMs
    } else { '' }
    $lSnapshotDeserializeMs = if (($null -ne $lPlannerPhaseMetrics) -and
        ($lPlannerPhaseMetrics.PSObject.Properties.Name -contains 'snapshotDeserializeMs')) {
      $lPlannerPhaseMetrics.snapshotDeserializeMs
    } else { '' }
    $lSnapshotIndexRebuildMs = if (($null -ne $lPlannerPhaseMetrics) -and
        ($lPlannerPhaseMetrics.PSObject.Properties.Name -contains 'snapshotIndexRebuildMs')) {
      $lPlannerPhaseMetrics.snapshotIndexRebuildMs
    } else { '' }
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
      ResultCount = $lResultCount
      SemanticCacheHits = $lFirst.SemanticCacheHits
      SemanticCacheMisses = $lFirst.SemanticCacheMisses
      ReferenceFallbackCount = $lFirst.ReferenceFallbackCount
      SnapshotSqlWriteMs = $lSnapshotSqlWriteMs
      SnapshotSqlReadMs = $lSnapshotSqlReadMs
      SnapshotDeserializeMs = $lSnapshotDeserializeMs
      SnapshotIndexRebuildMs = $lSnapshotIndexRebuildMs
      SourceMutationStatus = $lMutationStatus
      PlannerPhaseMetrics = $lPlannerPhaseMetrics
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
  if (Requires-PlannerPhaseMetrics -Row $Benchmark) {
    $lDiagnosticsIndex = $lArguments.IndexOf('--diagnostics')
    if ($lDiagnosticsIndex -lt 0) {
      $lArguments.Add('--diagnostics')
      $lArguments.Add('true')
    } elseif ($lDiagnosticsIndex + 1 -lt $lArguments.Count) {
      $lArguments[$lDiagnosticsIndex + 1] = 'true'
    } else {
      $lArguments.Add('true')
    }
  }
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
if ($PromoteBaseline -and $NoBaselineCopy) {
  throw 'Use either -PromoteBaseline or -NoBaselineCopy, not both.'
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
    $lHasSourceMutationStatus = $lRow.PSObject.Properties.Name -contains 'SourceMutationStatus'
    if (($lRow.ExitCode -eq 0) -and
        ((-not $lHasSourceMutationStatus) -or
        [string]::IsNullOrWhiteSpace([string]$lRow.SourceMutationStatus))) {
      throw "Successful benchmark row missing SourceMutationStatus: $($lRow.Id) run $($lRow.Run)"
    }
    if (-not $lHasSourceMutationStatus) {
      Add-Member -InputObject $lRow -NotePropertyName SourceMutationStatus `
        -NotePropertyValue 'not-applicable'
    }
  }
  $lResultRows = New-SummaryRows -RunRows $lRunRows
  $lCurrentDelphiSemanticsSha = Get-GitSha -Path (Get-Location)
  $lCurrentDakSha = Get-GitSha -Path (Split-Path (Split-Path $DakExe -Parent) -Parent)
  $lStoredDelphiSemanticsSha = [string](Get-ObjectPropertyValue -Object $lExistingSummary `
    -Name 'delphiSemanticsSha' -Default $lCurrentDelphiSemanticsSha)
  $lStoredDakSha = [string](Get-ObjectPropertyValue -Object $lExistingSummary `
    -Name 'dakSha' -Default $lCurrentDakSha)
  $lAllowHistoricalSummary = $AllowHistoricalSummary -or $AllowHistoricalPromotion
  $lProvenance = Test-BenchmarkProvenance `
    -StoredDelphiSemanticsSha $lStoredDelphiSemanticsSha `
    -StoredDakSha $lStoredDakSha `
    -CurrentDelphiSemanticsSha $lCurrentDelphiSemanticsSha `
    -CurrentDakSha $lCurrentDakSha `
    -AllowHistorical:$lAllowHistoricalSummary

  $lSummary = [ordered]@{
    name = $lExistingSummary.name
    startedAt = Format-BenchmarkTimestamp $lExistingSummary.startedAt
    completedAt = Format-BenchmarkTimestamp $lExistingSummary.completedAt
    elapsedSeconds = $lExistingSummary.elapsedSeconds
    dakExe = $lExistingSummary.dakExe
    project = $lExistingSummary.project
    repeat = $lExistingSummary.repeat
    cacheModes = if ($lExistingSummary.PSObject.Properties.Name -contains 'cacheModes') { $lExistingSummary.cacheModes } else { @('default') }
    warmTargetSeconds = if ($lExistingSummary.PSObject.Properties.Name -contains 'warmTargetSeconds') { $lExistingSummary.warmTargetSeconds } else { $WarmTargetSeconds }
    cacheDirectory = if ($lExistingSummary.PSObject.Properties.Name -contains 'cacheDirectory') { $lExistingSummary.cacheDirectory } else { '' }
    machine = if ($lExistingSummary.PSObject.Properties.Name -contains 'machine') { $lExistingSummary.machine } else { $env:COMPUTERNAME }
    delphiSemanticsSha = $lStoredDelphiSemanticsSha
    dakSha = $lStoredDakSha
    provenance = $lProvenance
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
        $lWarmupSourceSnapshot = New-SourceSnapshot -ProjectPath $Project
        & $DakExe @($lWarmupArguments) 1> $lWarmupStdout 2> $lWarmupStderr
        $lWarmupExitCode = $LASTEXITCODE
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_MODE -ErrorAction SilentlyContinue
        if (Test-SourceSnapshotChanged -ProjectPath $Project -Snapshot $lWarmupSourceSnapshot) {
          Restore-SourceSnapshot -ProjectPath $Project -Snapshot $lWarmupSourceSnapshot
          throw "Warm-cache priming mutated source files for $($lBenchmark.Id). Source was restored."
        }
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
        $lSourceSnapshot = New-SourceSnapshot -ProjectPath $Project
        & $DakExe @($lArguments) 1> $lStdout 2> $lStderr
        $lExitCode = $LASTEXITCODE
        $lStopwatch.Stop()
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_DIR -ErrorAction SilentlyContinue
        Remove-Item Env:\DELPHISEMANTICS_BENCHMARK_CACHE_MODE -ErrorAction SilentlyContinue
        $lSourceMutationStatus = 'clean'
        if (Test-SourceSnapshotChanged -ProjectPath $Project -Snapshot $lSourceSnapshot) {
          Restore-SourceSnapshot -ProjectPath $Project -Snapshot $lSourceSnapshot
          $lSourceMutationStatus = 'mutated'
          if ($lExitCode -eq 0) {
            $lExitCode = 1
          }
          Add-Content -LiteralPath $lStderr -Value 'Report-only benchmark mutated source files; source was restored.'
        }
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
          SourceMutationStatus = $lSourceMutationStatus
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
  $lDelphiSemanticsSha = Get-GitSha -Path (Get-Location)
  $lDakSha = Get-GitSha -Path $lDakRoot
  $lProvenance = Test-BenchmarkProvenance `
    -StoredDelphiSemanticsSha $lDelphiSemanticsSha `
    -StoredDakSha $lDakSha `
    -CurrentDelphiSemanticsSha $lDelphiSemanticsSha `
    -CurrentDakSha $lDakSha
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
    delphiSemanticsSha = $lDelphiSemanticsSha
    dakSha = $lDakSha
    provenance = $lProvenance
    results = $lResultRows
    runs = $lRunRows
  }
}

$lSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lJsonPath -Encoding UTF8
Export-RemoveWithPlanDogfoodReport -RunRows $lRunRows -OutputDirectory $lOutputDir

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
  ('Provenance: `{0}`' -f $lSummary.provenance.status)
  ('Warm target: `{0}` seconds' -f ([double]$lWarmTargetSeconds).ToString('F3',
    [System.Globalization.CultureInfo]::InvariantCulture))
  ('Cache directory: `{0}`' -f $lSummary.cacheDirectory)
  ''
  (ConvertTo-MarkdownTable -Rows $lResultRows)
  ''
  'Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.'
) -join [Environment]::NewLine
$lMarkdown | Set-Content -LiteralPath $lMarkdownPath -Encoding UTF8

if ($PromoteBaseline) {
  $lPromotionDakRoot = Split-Path (Split-Path $DakExe -Parent) -Parent
  $lPromotionBlockers = @(Get-BenchmarkPromotionBlocker `
    -Summary $lSummary `
    -DelphiSemanticsRoot (Get-Location) `
    -DakRoot $lPromotionDakRoot `
    -AllowHistoricalPromotion:$AllowHistoricalPromotion)
  if ($lPromotionBlockers.Count -gt 0) {
    throw "Benchmark baseline promotion refused. $($lPromotionBlockers -join '; ')"
  }

  $lBaselineDir = Join-Path (Get-Location) 'docs\benchmarks'
  New-Item -ItemType Directory -Force -Path $lBaselineDir | Out-Null
  if (($lWorkflowFilter.Count -eq 0) -and ($OutputDir -eq '.dak\benchmarks\maxtdb-semantic')) {
    Copy-Item -LiteralPath $lJsonPath -Destination (Join-Path $lBaselineDir 'maxtdb-semantic-baseline.json') -Force
    Copy-Item -LiteralPath $lMarkdownPath -Destination (Join-Path $lBaselineDir 'maxtdb-semantic-baseline.md') -Force
  } else {
    $lResultName = Split-Path $lOutputDir -Leaf
    if ([string]::IsNullOrWhiteSpace($lResultName)) {
      $lResultName = 'custom'
    }
    Copy-Item -LiteralPath $lJsonPath -Destination (Join-Path $lBaselineDir ('maxtdb-semantic-{0}.json' -f $lResultName)) -Force
    Copy-Item -LiteralPath $lMarkdownPath -Destination (Join-Path $lBaselineDir ('maxtdb-semantic-{0}.md' -f $lResultName)) -Force
  }
}

ConvertTo-MarkdownTable -Rows $lResultRows
Write-Host ''
Write-Host "Baseline JSON: $lJsonPath"
Write-Host "Baseline Markdown: $lMarkdownPath"

if (@($lResultRows | Where-Object { $_.ExitCode -ne 0 }).Count -gt 0) {
  exit 1
}

if (@($lResultRows | Where-Object {
      ($_.TargetStatus -eq 'missed') -and (-not (Test-BestEffortTargetMiss -Row $_))
    }).Count -gt 0) {
  exit 2
}
