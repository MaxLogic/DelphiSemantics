[CmdletBinding()]
param([string]$DakExe = 'F:\projects\MaxLogic\DelphiAiKit\bin\DelphiAIKit.exe')

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'test-support.ps1')
if (-not (Test-Path -LiteralPath $DakExe -PathType Leaf)) {
  throw "Real DAK executable not found: $DakExe"
}

function Test-WorkflowTimerExcludesSnapshotSetup {
  $lDakRoot = Split-Path -Parent (Split-Path -Parent $DakExe)
  $lRoot = Join-Path $lDakRoot ('tests\.dak\DelphiAIKit.Tests\timing-' + [guid]::NewGuid().ToString('N'))
  $lFixture = Join-Path $lRoot 'fixture'
  $lOutput = Join-Path $lFixture '.dak\RemoveWithImplementationGlobalFixture\timing'
  New-Item -ItemType Directory -Path $lOutput -Force | Out-Null
  $lOriginal = Join-Path $lDakRoot 'tests\fixtures\RemoveWithImplementationGlobalFixture'
  foreach ($lName in @('RemoveWithImplementationGlobalFixture.dproj',
      'RemoveWithImplementationGlobalFixture.dpr', 'ImplementationGlobalUnit.pas')) {
    Copy-Item -LiteralPath (Join-Path $lOriginal $lName) -Destination $lFixture
  }
  $lBenchmark = Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) `
    'scripts\benchmark-maxtdb-semantic-workflows.ps1'
  $lSource = [IO.File]::ReadAllText($lBenchmark).Replace("`r`n", "`n")

  # Instrument a private copy; the real snapshot, DAK process and result parsing still run.
  # Independent enclosing/contained timers avoid a machine-speed-dependent assertion.
  $lInsertions = [ordered]@{
    '  return $lSnapshot' = '  [Threading.Thread]::Sleep(2000)' + "`n" + '  return $lSnapshot'
    '        $lSourceSnapshot = Get-SourceSnapshot -ProjectPath $Project' =
      '        $lSourceSnapshot = Get-SourceSnapshot -ProjectPath $Project' + "`n" +
      '        $lOuterProbe = [Diagnostics.Stopwatch]::StartNew()'
    '        & $DakExe @($lArguments) 1> $lStdout 2> $lStderr' =
      '        $lInnerProbe = [Diagnostics.Stopwatch]::StartNew()' + "`n" +
      '        & $DakExe @($lArguments) 1> $lStdout 2> $lStderr' + "`n" +
      '        $lInnerProbe.Stop()'
    '        $lStopwatch.Stop()' = '        $lStopwatch.Stop()' + "`n" +
      '        $lOuterProbe.Stop()' + "`n" +
      '        @{ Outer = $lOuterProbe.Elapsed.TotalSeconds; Inner = $lInnerProbe.Elapsed.TotalSeconds } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $lOutputDir "timing-probe.json")'
  }
  foreach ($lAnchor in $lInsertions.Keys) {
    Assert-Equal 1 ([regex]::Matches($lSource, [regex]::Escape($lAnchor)).Count) `
      "Timing instrumentation anchor must occur once: $lAnchor"
    $lSource = $lSource.Replace($lAnchor, $lInsertions[$lAnchor])
  }
  $lCopy = Join-Path $lRoot 'benchmark-instrumented.ps1'
  [IO.File]::WriteAllText($lCopy, $lSource)
  $lHashes = @{}
  Get-ChildItem -LiteralPath $lFixture -File | ForEach-Object {
    $lHashes[$_.FullName] = (Get-FileHash -LiteralPath $_.FullName).Hash
  }
  & (Join-Path $PSHOME 'pwsh.exe') -NoProfile -File $lCopy -DakExe $DakExe `
    -Project (Join-Path $lFixture 'RemoveWithImplementationGlobalFixture.dproj') `
    -Workflow remove-with-plan-all -CacheMode cold -Repeat 1 -Platform Win64 `
    -Config Release -DelphiVersion 23.0 -OutputDir $lOutput -NoBaselineCopy
  Assert-Equal 0 $LASTEXITCODE 'Real DAK benchmark must succeed before timing is assessed.'
  $lReport = Get-Content -LiteralPath (Join-Path $lOutput 'baseline.json') -Raw | ConvertFrom-Json
  $lRows = @($lReport.runs)
  Assert-Equal 1 $lRows.Count 'One measured workflow is required.'
  Assert-Equal 1 $lRows[0].ResultCount 'The real fixture must produce its one WITH plan.'
  Assert-Equal 'clean' $lRows[0].SourceMutationStatus 'Isolated source must remain unchanged.'
  foreach ($lPath in $lHashes.Keys) {
    Assert-Equal $lHashes[$lPath] (Get-FileHash -LiteralPath $lPath).Hash 'Fixture hash changed.'
  }
  $lProbe = Get-Content -LiteralPath (Join-Path $lOutput 'timing-probe.json') -Raw | ConvertFrom-Json
  $lElapsed = [double]$lRows[0].ElapsedSeconds
  Write-Output "Timing evidence: $lOutput; reported=$lElapsed inner=$($lProbe.Inner) outer=$($lProbe.Outer)"
  Assert-True ($lElapsed -ge ($lProbe.Inner - 0.001)) 'Reported time must include actual DAK execution.'
  Assert-True ($lElapsed -le ($lProbe.Outer + 0.001)) 'Reported time must exclude source snapshot setup.'
}

Invoke-ScriptTests -ScriptPath $PSCommandPath
