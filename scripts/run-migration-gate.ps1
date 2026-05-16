[CmdletBinding()]
param(
  [string]$DelphiSemanticsRoot = '',
  [string]$DakRoot = 'F:\projects\MaxLogic\DelphiAiKit',
  [string]$WorkRoot = (Join-Path $env:TEMP 'delphi-semantics-migration-gate'),
  [switch]$SkipBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($DelphiSemanticsRoot)) {
  $lScriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($lScriptRoot)) {
    $lScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
  }
  $DelphiSemanticsRoot = Split-Path -Parent $lScriptRoot
}

function Invoke-GateStep {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @(),
    [int]$MaxOutputLines = 400
  )

  Write-Host "== $Name"
  Write-Host "   cwd: $WorkingDirectory"
  Write-Host "   run: $FilePath $($Arguments -join ' ')"

  $lOldLocation = Get-Location
  $lTimer = [Diagnostics.Stopwatch]::StartNew()
  try {
    Set-Location -LiteralPath $WorkingDirectory
    $lOutput = & $FilePath @Arguments 2>&1
    $lExitCode = $LASTEXITCODE
  } finally {
    Set-Location -LiteralPath $lOldLocation
    $lTimer.Stop()
  }

  if ($null -ne $lOutput) {
    $lOutputLines = @($lOutput)
    if ($MaxOutputLines -eq 0) {
      Write-Host "   output suppressed; see generated report or rerun the command for full output."
    } elseif (($MaxOutputLines -gt 0) -and ($lOutputLines.Count -gt $MaxOutputLines)) {
      $lOutputLines | Select-Object -First $MaxOutputLines | ForEach-Object { Write-Host $_ }
      Write-Host "   ... suppressed $($lOutputLines.Count - $MaxOutputLines) output line(s); see generated report or rerun the command for full output."
    } else {
      $lOutputLines | ForEach-Object { Write-Host $_ }
    }
  }

  $lResult = [pscustomobject]@{
    Name = $Name
    ExitCode = $lExitCode
    Seconds = [Math]::Round($lTimer.Elapsed.TotalSeconds, 1)
  }

  if ($lExitCode -ne 0) {
    Write-Host "!! $Name failed in $($lResult.Seconds)s with exit code $lExitCode"
    throw "$Name failed with exit code $lExitCode"
  }

  Write-Host "-- $Name passed in $($lResult.Seconds)s"
  return $lResult
}

function Reset-DirectoryUnder {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$AllowedRoot
  )

  $lAllowedRoot = [IO.Path]::GetFullPath($AllowedRoot)
  if (-not $lAllowedRoot.EndsWith([IO.Path]::DirectorySeparatorChar)) {
    $lAllowedRoot = $lAllowedRoot + [IO.Path]::DirectorySeparatorChar
  }

  if (Test-Path -LiteralPath $Path) {
    $lResolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $Path).Path)
    if (-not $lResolved.StartsWith($lAllowedRoot, [StringComparison]::OrdinalIgnoreCase)) {
      throw "Refusing to delete outside gate work root: $lResolved"
    }
    Remove-Item -LiteralPath $lResolved -Recurse -Force
  }
}

function Assert-ExistingFile {
  param([Parameter(Mandatory = $true)][string]$Path)

  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "Required file not found: $Path"
  }
}

function Get-NormalizedDirectoryPath {
  param([Parameter(Mandatory = $true)][string]$Path)

  $lPath = [IO.Path]::GetFullPath($Path)
  if (-not $lPath.EndsWith([IO.Path]::DirectorySeparatorChar)) {
    $lPath = $lPath + [IO.Path]::DirectorySeparatorChar
  }
  return $lPath
}

function Assert-NoFixtureCollision {
  param(
    [Parameter(Mandatory = $true)][string]$FixtureRoot,
    [Parameter(Mandatory = $true)][string]$CandidatePath,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $lFixtureRoot = Get-NormalizedDirectoryPath $FixtureRoot
  $lCandidate = Get-NormalizedDirectoryPath $CandidatePath

  if ($lCandidate.StartsWith($lFixtureRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description must not be inside the external fixture tree: $CandidatePath"
  }
  if ($lFixtureRoot.StartsWith($lCandidate, [StringComparison]::OrdinalIgnoreCase)) {
    throw "$Description must not contain the external fixture tree: $CandidatePath"
  }
}

Assert-ExistingFile (Join-Path $DelphiSemanticsRoot 'tests\delphiSemanticsTests.dproj')
Assert-ExistingFile (Join-Path $DakRoot 'tests\DelphiAIKit.Tests.dproj')
Assert-ExistingFile (Join-Path $DakRoot 'projects\DelphiAIKit.dproj')

$lFixture = Join-Path $DakRoot 'tests\fixtures\test-projects\maxTdb'
$lClone = Join-Path $WorkRoot 'maxTdb'
$lReport = Join-Path $WorkRoot 'maxTdb-remove-with.json'

if (-not (Test-Path -LiteralPath $lFixture -PathType Container)) {
  throw "maxTdb fixture not found: $lFixture"
}

Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath $WorkRoot -Description 'Gate work root'
Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath $lClone -Description 'maxTdb clone path'
Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath (Split-Path -Parent $lReport) -Description 'maxTdb report directory'

$lResults = New-Object System.Collections.Generic.List[object]

if (-not $SkipBuild) {
  $lResults.Add((Invoke-GateStep `
    -Name 'Build DelphiSemantics tests' `
    -WorkingDirectory $DelphiSemanticsRoot `
    -FilePath 'cmd.exe' `
    -Arguments @('/C', 'build-delphi.bat', 'tests\delphiSemanticsTests.dproj', '-config', 'Debug', '-platform', 'Win32', '-target', 'Rebuild', '-test-output-dir', 'tests\bin')))
}

$lResults.Add((Invoke-GateStep `
  -Name 'Run DelphiSemantics tests' `
  -WorkingDirectory $DelphiSemanticsRoot `
  -FilePath 'tests\bin\delphiSemanticsTests.exe' `
  -Arguments @('--hidebanner', '--consolemode:quiet')))

if (-not $SkipBuild) {
  $lResults.Add((Invoke-GateStep `
    -Name 'Build DAK tests' `
    -WorkingDirectory $DakRoot `
    -FilePath 'cmd.exe' `
    -Arguments @('/C', 'build-delphi.bat', 'tests\DelphiAIKit.Tests.dproj', '-config', 'Debug', '-platform', 'Win32', '-target', 'Rebuild')))
}

# Keep this as one sequential DUnitX process. Parallel DAK RemoveWith filters
# contend for shared test output/temp files and have caused runtime 217 failures.
$lResults.Add((Invoke-GateStep `
  -Name 'Run DAK remove-with tests' `
  -WorkingDirectory $DakRoot `
  -FilePath 'tests\DelphiAIKit.Tests.exe' `
  -Arguments @('--hidebanner', '--consolemode:quiet', '-r:Test.RemoveWith')))

if (-not $SkipBuild) {
  $lResults.Add((Invoke-GateStep `
    -Name 'Build DAK CLI' `
    -WorkingDirectory $DakRoot `
    -FilePath 'cmd.exe' `
    -Arguments @('/C', 'build-delphi.bat', 'projects\DelphiAIKit.dproj', '-config', 'Debug', '-platform', 'Win32', '-target', 'Rebuild')))
}

New-Item -ItemType Directory -Force -Path $WorkRoot | Out-Null
Reset-DirectoryUnder -Path $lClone -AllowedRoot $WorkRoot
if (Test-Path -LiteralPath $lReport) {
  Remove-Item -LiteralPath $lReport -Force
}

Copy-Item -LiteralPath $lFixture -Destination $lClone -Recurse -Force

$lProject = Join-Path $lClone 'src\maxtdb.dproj'
$lResults.Add((Invoke-GateStep `
  -Name 'Run cloned maxTdb smoke' `
  -WorkingDirectory $DakRoot `
  -FilePath 'bin\DelphiAIKit.exe' `
  -Arguments @('remove-with', '--project', $lProject, '--all', '--mode', 'apply', '--format', 'json', '--output', $lReport) `
  -MaxOutputLines 0))

Assert-ExistingFile $lReport
$lJson = Get-Content -LiteralPath $lReport -Raw | ConvertFrom-Json
$lWithStatements = @($lJson.withStatements).Count
$lAppliedEdits = [int]$lJson.summary.appliedEdits
$lSkipped = [int]$lJson.summary.skipped
$lVerification = [string]$lJson.verification.status
$lStatus = [string]$lJson.status

if ($lStatus -ne 'applied') {
  throw "Expected maxTdb status applied, got $lStatus"
}
if ($lVerification -ne 'passed') {
  throw "Expected maxTdb verification passed, got $lVerification"
}
if ($lAppliedEdits -lt 1) {
  throw "Expected at least one applied maxTdb edit"
}
if ($lSkipped -gt 20) {
  throw "Unexpected maxTdb skip regression: $lSkipped"
}

$lSkipBuckets = @($lJson.skipped | Group-Object reason | Sort-Object Count -Descending |
  Select-Object Count, Name)

Write-Host ''
Write-Host '== Migration gate summary'
$lResults | Format-Table -AutoSize | Out-String | Write-Host

[pscustomobject]@{
  Status = $lStatus
  Verification = $lVerification
  WithStatements = $lWithStatements
  AppliedEdits = $lAppliedEdits
  Skipped = $lSkipped
  Report = $lReport
  Clone = $lClone
} | Format-List | Out-String | Write-Host

Write-Host '== maxTdb skip buckets'
$lSkipBuckets | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "Migration gate passed. Report: $lReport"
