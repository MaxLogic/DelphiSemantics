[CmdletBinding()]
param(
  [string]$DakExe = 'F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe',
  [string]$Project = 'F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\maxTdb\src\maxtdb.dpr',
  [string]$OutputDir = '.dak\benchmarks\maxtdb-semantic',
  [int]$Repeat = 1,
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

function ConvertTo-MarkdownTable {
  param([object[]]$Rows)

  $lCulture = [System.Globalization.CultureInfo]::InvariantCulture
  $lLines = New-Object System.Collections.Generic.List[string]
  $lLines.Add('| Feature | Benchmark | Exit | Seconds | Result count |')
  $lLines.Add('|---|---|---:|---:|---:|')
  foreach ($lRow in $Rows) {
    $lCount = if ([string]::IsNullOrWhiteSpace($lRow.ResultCount)) { '' } else { $lRow.ResultCount }
    $lSeconds = ([double]$lRow.ElapsedSeconds).ToString('F3', $lCulture)
    $lLines.Add(('| {0} | {1} | {2} | {3} | {4} |' -f $lRow.Feature, $lRow.Id, $lRow.ExitCode, $lSeconds, $lCount))
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

if ($Repeat -lt 1) {
  throw 'Repeat must be at least 1.'
}

if (-not (Test-Path -LiteralPath $DakExe -PathType Leaf)) {
  throw "DAK executable not found: $DakExe"
}

if (-not (Test-Path -LiteralPath $Project -PathType Leaf)) {
  throw "Project fixture not found: $Project"
}

$lBenchmarks = @(New-BenchmarkDefinitions -ProjectPath $Project)

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

if ($SummarizeOnly) {
  if (-not (Test-Path -LiteralPath $lJsonPath -PathType Leaf)) {
    throw "Existing baseline JSON not found: $lJsonPath"
  }

  $lExistingSummary = Get-Content -LiteralPath $lJsonPath -Raw | ConvertFrom-Json
  $lResultRows = @($lExistingSummary.results)
  foreach ($lRow in $lResultRows) {
    if (($lRow.PSObject.Properties.Name -contains 'Stdout') -and (Test-Path -LiteralPath $lRow.Stdout -PathType Leaf)) {
      $lRow.ResultCount = Read-ResultCount -Path $lRow.Stdout
    }
  }

  $lSummary = [ordered]@{
    name = $lExistingSummary.name
    startedAt = Format-BenchmarkTimestamp $lExistingSummary.startedAt
    completedAt = Format-BenchmarkTimestamp $lExistingSummary.completedAt
    elapsedSeconds = $lExistingSummary.elapsedSeconds
    dakExe = $lExistingSummary.dakExe
    project = $lExistingSummary.project
    repeat = $lExistingSummary.repeat
    results = $lResultRows
  }
} else {

  $lStartedAt = Get-Date
  $lRows = New-Object System.Collections.Generic.List[object]
  $lRunsJsonlPath = Join-Path $lOutputDir 'runs.jsonl'
  if (Test-Path -LiteralPath $lRunsJsonlPath) {
    Remove-Item -LiteralPath $lRunsJsonlPath
  }

  foreach ($lBenchmark in $lBenchmarks) {
    for ($i = 1; $i -le $Repeat; $i++) {
      $lRunId = if ($Repeat -eq 1) { $lBenchmark.Id } else { '{0}-run{1}' -f $lBenchmark.Id, $i }
      $lStdout = Join-Path $lOutputDir ($lRunId + '.stdout.json')
      $lStderr = Join-Path $lOutputDir ($lRunId + '.stderr.txt')

      $lStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
      & $DakExe @($lBenchmark.Arguments) 1> $lStdout 2> $lStderr
      $lExitCode = $LASTEXITCODE
      $lStopwatch.Stop()

      $lRow = [pscustomobject]@{
        Id = $lBenchmark.Id
        Run = $i
        Feature = $lBenchmark.Feature
        Description = $lBenchmark.Description
        ExitCode = $lExitCode
        ElapsedSeconds = [Math]::Round($lStopwatch.Elapsed.TotalSeconds, 3)
        ResultCount = Read-ResultCount -Path $lStdout
        Stdout = $lStdout
        Stderr = $lStderr
        Command = ('{0} {1}' -f $DakExe, ($lBenchmark.Arguments -join ' '))
      }
      $lRows.Add($lRow)
      $lRow | ConvertTo-Json -Depth 5 -Compress | Add-Content -LiteralPath $lRunsJsonlPath -Encoding UTF8
    }
  }

  $lCompletedAt = Get-Date
  $lResultRows = @($lRows.ToArray())
  $lSummary = [ordered]@{
    name = 'maxTdb semantic workflow benchmark'
    startedAt = $lStartedAt.ToString('o')
    completedAt = $lCompletedAt.ToString('o')
    elapsedSeconds = [Math]::Round(($lCompletedAt - $lStartedAt).TotalSeconds, 3)
    dakExe = $DakExe
    project = $Project
    repeat = $Repeat
    results = $lResultRows
  }
}

$lSummary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lJsonPath -Encoding UTF8

$lMarkdown = @(
  '# maxTdb semantic workflow benchmark baseline'
  ''
  ('Started: `{0}`' -f $lSummary.startedAt)
  ('Completed: `{0}`' -f $lSummary.completedAt)
  ('DAK: `{0}`' -f $DakExe)
  ('Project: `{0}`' -f $Project)
  ''
  (ConvertTo-MarkdownTable -Rows $lResultRows)
  ''
  'Notes: all commands are report-only or dry-run; the maxTdb fixture is not modified.'
) -join [Environment]::NewLine
$lMarkdown | Set-Content -LiteralPath $lMarkdownPath -Encoding UTF8

if (-not $NoBaselineCopy) {
  $lBaselineDir = Join-Path (Get-Location) 'docs\benchmarks'
  New-Item -ItemType Directory -Force -Path $lBaselineDir | Out-Null
  Copy-Item -LiteralPath $lJsonPath -Destination (Join-Path $lBaselineDir 'maxtdb-semantic-baseline.json') -Force
  Copy-Item -LiteralPath $lMarkdownPath -Destination (Join-Path $lBaselineDir 'maxtdb-semantic-baseline.md') -Force
}

ConvertTo-MarkdownTable -Rows $lResultRows
Write-Host ''
Write-Host "Baseline JSON: $lJsonPath"
Write-Host "Baseline Markdown: $lMarkdownPath"
