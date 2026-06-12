[CmdletBinding()]
param(
  [string]$DelphiSemanticsRoot = '',
  [string]$DakRoot = 'F:\projects\MaxLogic\DelphiAiKit',
  [string]$WorkRoot = '',
  [ValidateRange(1, 16)][int]$DakTestShards = 1,
  [ValidateSet('Gate', 'Full')][string]$DakTestProfile = 'Gate',
  [switch]$SkipBuild,
  [switch]$AllowDirty,
  [switch]$ImportOnly
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

function New-MigrationGateDefaultWorkRoot {
  $lBase = Join-Path $env:TEMP 'delphi-semantics-migration-gate'
  $lStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
  $lGuid = [Guid]::NewGuid().ToString('N').Substring(0, 12)
  return [IO.Path]::GetFullPath((Join-Path $lBase "run-$lStamp-$PID-$lGuid"))
}

function Invoke-GitText {
  param(
    [Parameter(Mandatory = $true)][string]$RepositoryPath,
    [Parameter(Mandatory = $true)][string[]]$Arguments
  )

  $lOutput = & git -C $RepositoryPath @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed in ${RepositoryPath}: $lOutput"
  }
  return (@($lOutput) -join "`n").Trim()
}

function Get-GateGitProvenance {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$RepositoryPath
  )

  $lPath = [IO.Path]::GetFullPath($RepositoryPath)
  $lInside = Invoke-GitText -RepositoryPath $lPath -Arguments @('rev-parse', '--is-inside-work-tree')
  if ($lInside -ne 'true') {
    throw "Not a Git worktree: $lPath"
  }

  $lBranch = Invoke-GitText -RepositoryPath $lPath -Arguments @('branch', '--show-current')
  if ([string]::IsNullOrWhiteSpace($lBranch)) {
    $lBranch = Invoke-GitText -RepositoryPath $lPath -Arguments @('rev-parse', '--abbrev-ref', 'HEAD')
  }

  $lCommit = Invoke-GitText -RepositoryPath $lPath -Arguments @('rev-parse', 'HEAD')
  $lStatus = Invoke-GitText -RepositoryPath $lPath -Arguments @('status', '--porcelain=v1', '--untracked-files=all')
  $lStatusLines = @()
  if (-not [string]::IsNullOrWhiteSpace($lStatus)) {
    $lStatusLines = @($lStatus -split "`r?`n")
  }

  return [pscustomobject]@{
    Name = $Name
    Path = $lPath
    Branch = $lBranch
    Commit = $lCommit
    Dirty = $lStatusLines.Count -gt 0
    StatusLines = $lStatusLines
  }
}

function Get-GateRepositoryProvenanceSet {
  param(
    [Parameter(Mandatory = $true)][object[]]$Repositories
  )

  $lProvenance = New-Object System.Collections.Generic.List[object]
  foreach ($lRepository in $Repositories) {
    $lProvenance.Add((Get-GateGitProvenance -Name $lRepository.Name -RepositoryPath $lRepository.Path))
  }
  return $lProvenance.ToArray()
}

function Select-GateRepositoryProvenance {
  param(
    [Parameter(Mandatory = $true)][object[]]$Provenance,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $lMatches = @($Provenance | Where-Object { $_.Name -ieq $Name })
  if ($lMatches.Count -ne 1) {
    throw "Expected exactly one $Name provenance entry, found $($lMatches.Count)."
  }
  return $lMatches[0]
}

function Assert-GateWorktreesClean {
  param(
    [object[]]$Repositories = @(),
    [object[]]$Provenance = @(),
    [switch]$AllowDirty
  )

  if (($Provenance.Count -eq 0) -and ($Repositories.Count -gt 0)) {
    $Provenance = Get-GateRepositoryProvenanceSet -Repositories $Repositories
  }

  foreach ($lProvenance in $Provenance) {
    if ($lProvenance.Dirty -and (-not $AllowDirty)) {
      throw "Refusing to run migration gate with dirty $($lProvenance.Name) worktree: $($lProvenance.Path). Commit/stash changes or pass -AllowDirty."
    }
  }
}

function Write-MigrationGateManifest {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][string]$DelphiSemanticsRoot,
    [Parameter(Mandatory = $true)][string]$DakRoot,
    [object[]]$Provenance = @(),
    [switch]$AllowDirty
  )

  if ($Provenance.Count -eq 0) {
    $Provenance = Get-GateRepositoryProvenanceSet -Repositories @(
      [pscustomobject]@{ Name = 'DelphiSemantics'; Path = $DelphiSemanticsRoot },
      [pscustomobject]@{ Name = 'DAK'; Path = $DakRoot }
    )
  }
  $lSemantics = Select-GateRepositoryProvenance -Provenance $Provenance -Name 'DelphiSemantics'
  $lDak = Select-GateRepositoryProvenance -Provenance $Provenance -Name 'DAK'
  $lManifest = [ordered]@{
    generatedAt = (Get-Date).ToString('o')
    workRoot = [IO.Path]::GetFullPath($WorkRoot)
    allowDirty = [bool]$AllowDirty
    repositories = [ordered]@{
      delphiSemantics = [ordered]@{
        path = $lSemantics.Path
        branch = $lSemantics.Branch
        commit = $lSemantics.Commit
        dirty = $lSemantics.Dirty
        statusLines = $lSemantics.StatusLines
      }
      dak = [ordered]@{
        path = $lDak.Path
        branch = $lDak.Branch
        commit = $lDak.Commit
        dirty = $lDak.Dirty
        statusLines = $lDak.StatusLines
      }
    }
  }

  $lParent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($lParent)) {
    [IO.Directory]::CreateDirectory($lParent) | Out-Null
  }
  $lManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
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

function Get-DakRemoveWithTestFilters {
  param([Parameter(Mandatory = $true)][string]$DakRoot)

  $lTestUnit = Join-Path $DakRoot 'tests\units\test.removewith.pas'
  Assert-ExistingFile $lTestUnit

  $lMatches = Select-String `
    -LiteralPath $lTestUnit `
    -Pattern '^\s*(TRemoveWith[A-Za-z0-9_]+Tests)\s*=\s*class\b'

  $lFilters = @($lMatches | ForEach-Object {
    'Test.RemoveWith.{0}' -f $_.Matches[0].Groups[1].Value
  })

  if ($lFilters.Count -eq 0) {
    throw "No DAK RemoveWith DUnitX fixtures discovered in $lTestUnit"
  }

  return $lFilters
}

function Invoke-DakRemoveWithTests {
  param(
    [Parameter(Mandatory = $true)][string]$DakRoot,
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][int]$ShardCount,
    [Parameter(Mandatory = $true)][string]$Profile
  )

  $lFilters = @(Get-DakRemoveWithTestFilters -DakRoot $DakRoot)

  if ($ShardCount -ne 1) {
    throw 'Parallel DAK RemoveWith shards are disabled. Isolated DAK_TEST_OUTPUT_ROOT was not sufficient; previous parallel runs failed through additional shared state/codepage sensitivity. Use -DakTestShards 1.'
  }

  if ($Profile -eq 'Gate') {
    $lFilters = @($lFilters | Where-Object { $_ -ne 'Test.RemoveWith.TRemoveWithProprietaryProjectTests' })
  }

  if ($lFilters.Count -eq 0) {
    throw "DAK RemoveWith test profile '$Profile' selected no fixtures"
  }

  Write-Host "   DAK_TEST_OUTPUT_ROOT: <default DAK test root>"
  Write-Host "   DAK test profile: $Profile"
  Write-Host "   DAK test fixtures: $($lFilters.Count)"
  if ($Profile -eq 'Gate') {
    Write-Host "   policy: gate profile is sequential and excludes TRemoveWithProprietaryProjectTests because cloned maxTdb smoke verifies the proprietary path."
  } else {
    Write-Host "   policy: full profile is sequential and covers every RemoveWith fixture."
  }

  return Invoke-GateStep `
    -Name 'Run DAK remove-with tests' `
    -WorkingDirectory $DakRoot `
    -FilePath 'tests\DelphiAIKit.Tests.exe' `
    -Arguments @('--hidebanner', '--consolemode:quiet', "-r:$($lFilters -join ',')")
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

if ($ImportOnly) {
  return
}

if ([string]::IsNullOrWhiteSpace($WorkRoot)) {
  $WorkRoot = New-MigrationGateDefaultWorkRoot
} else {
  $WorkRoot = [IO.Path]::GetFullPath($WorkRoot)
}

Assert-ExistingFile (Join-Path $DelphiSemanticsRoot 'tests\delphiSemanticsTests.dproj')
Assert-ExistingFile (Join-Path $DakRoot 'tests\DelphiAIKit.Tests.dproj')
Assert-ExistingFile (Join-Path $DakRoot 'projects\DelphiAIKit.dproj')

if ($DakTestShards -ne 1) {
  throw 'Parallel DAK RemoveWith shards are disabled. Isolated DAK_TEST_OUTPUT_ROOT was not sufficient; previous parallel runs failed through additional shared state/codepage sensitivity. Use -DakTestShards 1.'
}

$lGateRepositories = @(
  [pscustomobject]@{ Name = 'DelphiSemantics'; Path = $DelphiSemanticsRoot },
  [pscustomobject]@{ Name = 'DAK'; Path = $DakRoot }
)
$lGateProvenance = Get-GateRepositoryProvenanceSet -Repositories $lGateRepositories
Assert-GateWorktreesClean -Provenance $lGateProvenance -AllowDirty:$AllowDirty

$lFixture = Join-Path $DakRoot 'tests\fixtures\test-projects\maxTdb'
$lClone = Join-Path $WorkRoot 'maxTdb'
$lPlanReport = Join-Path $WorkRoot 'maxTdb-plan-only.json'
$lReport = Join-Path $WorkRoot 'maxTdb-remove-with.json'
$lManifest = Join-Path $WorkRoot 'migration-gate-manifest.json'

if (-not (Test-Path -LiteralPath $lFixture -PathType Container)) {
  throw "maxTdb fixture not found: $lFixture"
}

Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath $WorkRoot -Description 'Gate work root'
Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath $lClone -Description 'maxTdb clone path'
Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath (Split-Path -Parent $lReport) -Description 'maxTdb report directory'

[IO.Directory]::CreateDirectory($WorkRoot) | Out-Null
Write-MigrationGateManifest `
  -Path $lManifest `
  -WorkRoot $WorkRoot `
  -DelphiSemanticsRoot $DelphiSemanticsRoot `
  -DakRoot $DakRoot `
  -Provenance $lGateProvenance `
  -AllowDirty:$AllowDirty

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
    -Arguments @('/C', 'build-delphi.bat', 'tests\DelphiAIKit.Tests.dproj', '-config', 'Debug', '-platform', 'Win64', '-target', 'Rebuild')))
}

$lResults.Add((Invoke-DakRemoveWithTests `
  -DakRoot $DakRoot `
  -WorkRoot $WorkRoot `
  -ShardCount $DakTestShards `
  -Profile $DakTestProfile))

if (-not $SkipBuild) {
  $lResults.Add((Invoke-GateStep `
    -Name 'Build DAK CLI' `
    -WorkingDirectory $DakRoot `
    -FilePath 'cmd.exe' `
    -Arguments @('/C', 'build-delphi.bat', 'projects\DelphiAIKit.dproj', '-config', 'Debug', '-platform', 'Win64', '-target', 'Rebuild')))
}

Reset-DirectoryUnder -Path $lClone -AllowedRoot $WorkRoot
if (Test-Path -LiteralPath $lPlanReport) {
  Remove-Item -LiteralPath $lPlanReport -Force
}
if (Test-Path -LiteralPath $lReport) {
  Remove-Item -LiteralPath $lReport -Force
}

Copy-Item -LiteralPath $lFixture -Destination $lClone -Recurse -Force

$lProject = Join-Path $lClone 'src\maxtdb.dproj'
$lResults.Add((Invoke-GateStep `
  -Name 'Run cloned maxTdb report-only plan' `
  -WorkingDirectory $DakRoot `
  -FilePath 'bin\DelphiAIKit.exe' `
  -Arguments @('remove-with', '--project', $lProject, '--all', '--mode', 'plan', '--format', 'json', '--output', $lPlanReport) `
  -MaxOutputLines 0))

$lResults.Add((Invoke-GateStep `
  -Name 'Run cloned maxTdb smoke' `
  -WorkingDirectory $DakRoot `
  -FilePath 'bin\DelphiAIKit.exe' `
  -Arguments @('remove-with', '--project', $lProject, '--all', '--mode', 'apply', '--format', 'json', '--output', $lReport) `
  -MaxOutputLines 0))

Assert-ExistingFile $lPlanReport
Assert-ExistingFile $lReport
$lPlanJson = Get-Content -LiteralPath $lPlanReport -Raw | ConvertFrom-Json
$lJson = Get-Content -LiteralPath $lReport -Raw | ConvertFrom-Json
$lPlanWithStatements = [int]$lPlanJson.summary.withStatements
$lApplyWithStatements = [int]$lJson.summary.withStatements
$lPlanPlannedEdits = [int]$lPlanJson.summary.plannedEdits
$lApplyPlannedEdits = [int]$lJson.summary.plannedEdits
$lAppliedEdits = [int]$lJson.summary.appliedEdits
$lSkipped = [int]$lJson.summary.skipped
$lVerification = [string]$lJson.verification.status
$lPlanStatus = [string]$lPlanJson.status
$lStatus = [string]$lJson.status

if ($lPlanStatus -ne 'ok') {
  throw "Expected maxTdb report-only status ok, got $lPlanStatus"
}
if ($lStatus -ne 'applied') {
  throw "Expected maxTdb status applied, got $lStatus"
}
if ($lVerification -ne 'passed') {
  throw "Expected maxTdb verification passed, got $lVerification"
}
if (($lPlanWithStatements -ne 667) -or ($lApplyWithStatements -ne 667)) {
  throw "Expected maxTdb scan count 667 in plan/apply reports, got plan=$lPlanWithStatements apply=$lApplyWithStatements"
}
if (($lPlanPlannedEdits -ne 215) -or ($lApplyPlannedEdits -ne $lPlanPlannedEdits)) {
  throw "Expected maxTdb planned edit parity at 215, got plan=$lPlanPlannedEdits apply=$lApplyPlannedEdits"
}
$lPlanIds = @($lPlanJson.plannedEdits | ForEach-Object { [string]$_.statementId })
$lApplyIds = @($lJson.plannedEdits | ForEach-Object { [string]$_.statementId })
if (@(Compare-Object $lPlanIds $lApplyIds).Count -ne 0) {
  throw 'Expected maxTdb report-only and apply planned statement IDs to match.'
}
if ($lAppliedEdits -lt 1) {
  throw "Expected at least one applied maxTdb edit"
}

$lSkipBuckets = @($lJson.skipped | Group-Object reason | Sort-Object Count -Descending |
  Select-Object Count, Name)

Write-Host ''
Write-Host '== Migration gate summary'
$lResults | Format-Table -AutoSize | Out-String | Write-Host

$lTotalSeconds = ($lResults | Measure-Object -Property Seconds -Sum).Sum
$lDominantPhases = @($lResults | Sort-Object Seconds -Descending | Select-Object -First 3 | ForEach-Object {
  [pscustomobject]@{
    Name = $_.Name
    Seconds = $_.Seconds
    Percent = if ($lTotalSeconds -gt 0) { [Math]::Round(($_.Seconds / $lTotalSeconds) * 100, 1) } else { 0 }
  }
})

Write-Host '== Dominant migration gate phases'
$lDominantPhases | Format-Table -AutoSize | Out-String | Write-Host

[pscustomobject]@{
  Status = $lStatus
  Verification = $lVerification
  WithStatements = $lApplyWithStatements
  PlannedEdits = $lApplyPlannedEdits
  AppliedEdits = $lAppliedEdits
  Skipped = $lSkipped
  PlanReport = $lPlanReport
  ApplyReport = $lReport
  Manifest = $lManifest
  Clone = $lClone
} | Format-List | Out-String | Write-Host

Write-Host '== maxTdb skip buckets'
$lSkipBuckets | Format-Table -AutoSize | Out-String | Write-Host

Write-Host "Migration gate passed. Reports: $lPlanReport, $lReport"
