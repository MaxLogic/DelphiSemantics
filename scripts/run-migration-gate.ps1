[CmdletBinding()]
param(
  [string]$DelphiSemanticsRoot = '',
  [string]$DakRoot = 'F:\projects\MaxLogic\DelphiAiKit',
  [string]$WorkRoot = '',
  [ValidateRange(1, 16)][int]$DakTestShards = 1,
  [ValidateSet('Gate', 'Full')][string]$DakTestProfile = 'Gate',
  [switch]$SkipBuild,
  [switch]$AllowDirty,
  [switch]$ImportOnly,
  [switch]$Help
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if ($Help) {
  Write-Host 'Usage: run-migration-gate.ps1 [-DelphiSemanticsRoot <path>] [-DakRoot <path>] [-WorkRoot <path>] [-SkipBuild] [-AllowDirty]'
  Write-Host 'Runs the DelphiSemantics/DAK migration gate on a maxTdb clone.'
  Write-Host 'The gate snapshots cloned Delphi source before report-only plan mode and records a sourceMutation manifest step before apply.'
  return
}

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
    [object[]]$Steps = @(),
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
    steps = @($Steps)
  }

  $lParent = Split-Path -Parent $Path
  if (-not [string]::IsNullOrWhiteSpace($lParent)) {
    [IO.Directory]::CreateDirectory($lParent) | Out-Null
  }
  $lManifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function New-MigrationGateWorkRootLock {
  param(
    [Parameter(Mandatory = $true)][string]$WorkRoot
  )

  $lRoot = [IO.Path]::GetFullPath($WorkRoot)
  [IO.Directory]::CreateDirectory($lRoot) | Out-Null
  $lPath = Join-Path $lRoot 'migration-gate.lock'
  try {
    $lStream = [IO.File]::Open($lPath, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
  } catch [IO.IOException] {
    throw "WorkRoot is already locked by another migration gate run: $lRoot"
  }

  $lText = "pid=$PID`nstartedAt=$((Get-Date).ToString('o'))`nworkRoot=$lRoot`n"
  $lBytes = [Text.Encoding]::UTF8.GetBytes($lText)
  try {
    $lStream.SetLength(0)
    $lStream.Write($lBytes, 0, $lBytes.Length)
    $lStream.Flush()
  } catch {
    $lStream.Dispose()
    throw
  }

  return [pscustomobject]@{
    WorkRoot = $lRoot
    Path = $lPath
    Stream = $lStream
  }
}

function Close-MigrationGateWorkRootLock {
  param(
    [object]$Lock
  )

  if ($null -eq $Lock) {
    return
  }

  if ($null -ne $Lock.Stream) {
    $Lock.Stream.Dispose()
  }
  if ((-not [string]::IsNullOrWhiteSpace($Lock.Path)) -and (Test-Path -LiteralPath $Lock.Path)) {
    Remove-Item -LiteralPath $Lock.Path -Force -ErrorAction SilentlyContinue
  }
}

function Invoke-GateStep {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @(),
    [string]$ArtifactDirectory = '',
    [switch]$NoThrow,
    [int]$MaxOutputLines = 400
  )

  Write-Host "== $Name"
  $lWorkingDirectory = [IO.Path]::GetFullPath($WorkingDirectory)
  $lCommand = ('{0} {1}' -f $FilePath, ($Arguments -join ' ')).Trim()
  Write-Host "   cwd: $lWorkingDirectory"
  Write-Host "   run: $FilePath $($Arguments -join ' ')"

  if ([string]::IsNullOrWhiteSpace($ArtifactDirectory)) {
    $ArtifactDirectory = Join-Path ([IO.Path]::GetTempPath()) 'delphi-semantics-migration-gate-step-logs'
  }
  [IO.Directory]::CreateDirectory($ArtifactDirectory) | Out-Null
  $lSafeName = [Regex]::Replace($Name.ToLowerInvariant(), '[^a-z0-9]+', '-').Trim('-')
  if ([string]::IsNullOrWhiteSpace($lSafeName)) {
    $lSafeName = 'step'
  }
  $lStamp = Get-Date -Format 'yyyyMMdd-HHmmss-fff'
  $lStdout = Join-Path $ArtifactDirectory "$lStamp-$lSafeName.stdout.txt"
  $lStderr = Join-Path $ArtifactDirectory "$lStamp-$lSafeName.stderr.txt"

  $lOldLocation = Get-Location
  $lTimer = [Diagnostics.Stopwatch]::StartNew()
  try {
    Set-Location -LiteralPath $lWorkingDirectory
    & $FilePath @Arguments 1> $lStdout 2> $lStderr
    $lExitCode = $LASTEXITCODE
  } finally {
    Set-Location -LiteralPath $lOldLocation
    $lTimer.Stop()
  }

  $lOutputLines = @()
  if (Test-Path -LiteralPath $lStdout -PathType Leaf) {
    $lOutputLines = @(Get-Content -LiteralPath $lStdout)
  }
  if (Test-Path -LiteralPath $lStderr -PathType Leaf) {
    $lOutputLines += @(Get-Content -LiteralPath $lStderr)
  }
  if ($lOutputLines.Count -gt 0) {
    if ($MaxOutputLines -eq 0) {
      Write-Host "   output suppressed; see $lStdout and $lStderr."
    } elseif (($MaxOutputLines -gt 0) -and ($lOutputLines.Count -gt $MaxOutputLines)) {
      $lOutputLines | Select-Object -First $MaxOutputLines | ForEach-Object { Write-Host $_ }
      Write-Host "   ... suppressed $($lOutputLines.Count - $MaxOutputLines) output line(s); see $lStdout and $lStderr."
    } else {
      $lOutputLines | ForEach-Object { Write-Host $_ }
    }
  }

  $lResult = [pscustomobject]@{
    name = $Name
    workingDirectory = $lWorkingDirectory
    filePath = $FilePath
    arguments = @($Arguments)
    command = $lCommand
    exitCode = $lExitCode
    elapsedSeconds = [Math]::Round($lTimer.Elapsed.TotalSeconds, 1)
    stdout = $lStdout
    stderr = $lStderr
  }

  if ($lExitCode -ne 0) {
    Write-Host "!! $Name failed in $($lResult.elapsedSeconds)s with exit code $lExitCode"
    if (-not $NoThrow) {
      throw "$Name failed with exit code $lExitCode"
    }
    return $lResult
  }

  Write-Host "-- $Name passed in $($lResult.elapsedSeconds)s"
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
    [Parameter(Mandatory = $true)][string]$Profile,
    [string]$ArtifactDirectory = '',
    [switch]$NoThrow
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
    -Arguments @('--hidebanner', '--consolemode:quiet', "-r:$($lFilters -join ',')") `
    -ArtifactDirectory $ArtifactDirectory `
    -NoThrow:$NoThrow
}

function Add-GateStepResult {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Results,
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][string]$DelphiSemanticsRoot,
    [Parameter(Mandatory = $true)][string]$DakRoot,
    [object[]]$Provenance = @(),
    [switch]$AllowDirty,
    [switch]$NoThrow
  )

  $Results.Add($Result)
  Write-MigrationGateManifest `
    -Path $ManifestPath `
    -WorkRoot $WorkRoot `
    -DelphiSemanticsRoot $DelphiSemanticsRoot `
    -DakRoot $DakRoot `
    -Provenance $Provenance `
    -Steps $Results.ToArray() `
    -AllowDirty:$AllowDirty

  if (([int]$Result.exitCode -ne 0) -and (-not $NoThrow)) {
    throw "$($Result.name) failed with exit code $($Result.exitCode)"
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

function Get-MigrationGateObjectProperty {
  param(
    [object]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  $lProperty = $Object.PSObject.Properties[$Name]
  if ($null -eq $lProperty) {
    return $null
  }
  return $lProperty.Value
}

function Test-MigrationGateObjectProperty {
  param(
    [object]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Object) {
    return $false
  }
  return $null -ne $Object.PSObject.Properties[$Name]
}

function ConvertTo-MigrationGateStableJson {
  param([object]$Value)

  if ($null -eq $Value) {
    return ''
  }
  return ($Value | ConvertTo-Json -Depth 16 -Compress)
}

function Get-MigrationGateTextHash {
  param([object]$Value)

  $lText = [string]$Value
  $lBytes = [Text.Encoding]::UTF8.GetBytes($lText)
  $lHash = [Security.Cryptography.SHA256]::Create()
  try {
    return ([BitConverter]::ToString($lHash.ComputeHash($lBytes))).Replace('-', '').ToLowerInvariant()
  } finally {
    $lHash.Dispose()
  }
}

function Get-MigrationGatePlannedEditShape {
  param([Parameter(Mandatory = $true)][object]$PlannedEdit)

  $lEditShapes = @(
    @(Get-MigrationGateObjectProperty -Object $PlannedEdit -Name 'edits') |
      ForEach-Object {
        [ordered]@{
          hasKind = Test-MigrationGateObjectProperty -Object $_ -Name 'kind'
          kind = [string](Get-MigrationGateObjectProperty -Object $_ -Name 'kind')
          hasFile = Test-MigrationGateObjectProperty -Object $_ -Name 'file'
          file = [string](Get-MigrationGateObjectProperty -Object $_ -Name 'file')
          hasStatementId = Test-MigrationGateObjectProperty -Object $_ -Name 'statementId'
          statementId = [string](Get-MigrationGateObjectProperty -Object $_ -Name 'statementId')
          hasRange = Test-MigrationGateObjectProperty -Object $_ -Name 'range'
          range = ConvertTo-MigrationGateStableJson (Get-MigrationGateObjectProperty -Object $_ -Name 'range')
          hasReplacementText = Test-MigrationGateObjectProperty -Object $_ -Name 'replacementText'
          replacementHash = Get-MigrationGateTextHash (Get-MigrationGateObjectProperty -Object $_ -Name 'replacementText')
        }
      } |
      ForEach-Object { ConvertTo-MigrationGateStableJson $_ } |
      Sort-Object
  )

  $lShape = [ordered]@{
    hasStatementId = Test-MigrationGateObjectProperty -Object $PlannedEdit -Name 'statementId'
    statementId = [string](Get-MigrationGateObjectProperty -Object $PlannedEdit -Name 'statementId')
    hasFile = Test-MigrationGateObjectProperty -Object $PlannedEdit -Name 'file'
    file = [string](Get-MigrationGateObjectProperty -Object $PlannedEdit -Name 'file')
    hasRange = Test-MigrationGateObjectProperty -Object $PlannedEdit -Name 'range'
    range = ConvertTo-MigrationGateStableJson (Get-MigrationGateObjectProperty -Object $PlannedEdit -Name 'range')
    hasStatus = Test-MigrationGateObjectProperty -Object $PlannedEdit -Name 'status'
    status = [string](Get-MigrationGateObjectProperty -Object $PlannedEdit -Name 'status')
    hasReason = Test-MigrationGateObjectProperty -Object $PlannedEdit -Name 'reason'
    reason = [string](Get-MigrationGateObjectProperty -Object $PlannedEdit -Name 'reason')
    hasReplacementText = Test-MigrationGateObjectProperty -Object $PlannedEdit -Name 'replacementText'
    replacementHash = Get-MigrationGateTextHash (Get-MigrationGateObjectProperty -Object $PlannedEdit -Name 'replacementText')
    edits = @($lEditShapes)
  }
  return ConvertTo-MigrationGateStableJson $lShape
}

function Assert-MigrationGatePlannedEditParity {
  param(
    [Parameter(Mandatory = $true)][object]$PlanJson,
    [Parameter(Mandatory = $true)][object]$ApplyJson
  )

  $lPlanShapes = @(
    @(Get-MigrationGateObjectProperty -Object $PlanJson -Name 'plannedEdits') |
      ForEach-Object { Get-MigrationGatePlannedEditShape -PlannedEdit $_ } |
      Sort-Object
  )
  $lApplyShapes = @(
    @(Get-MigrationGateObjectProperty -Object $ApplyJson -Name 'plannedEdits') |
      ForEach-Object { Get-MigrationGatePlannedEditShape -PlannedEdit $_ } |
      Sort-Object
  )
  $lDifferences = @(Compare-Object $lPlanShapes $lApplyShapes)
  if ($lDifferences.Count -ne 0) {
    $lSample = @($lDifferences | Select-Object -First 4 | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" })
    throw "Expected maxTdb report-only and apply planned edit shapes to match. Differences: $($lSample -join ' | ')"
  }
}

function Get-MigrationGateSourceRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $lRelative = [IO.Path]::GetRelativePath([IO.Path]::GetFullPath($Root), [IO.Path]::GetFullPath($Path))
  return $lRelative.Replace([IO.Path]::AltDirectorySeparatorChar, [IO.Path]::DirectorySeparatorChar)
}

function Get-MigrationGateFileHash {
  param([Parameter(Mandatory = $true)][string]$Path)

  $lHash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
  return $lHash.Hash.ToLowerInvariant()
}

function New-MigrationGateSourceSnapshot {
  param([Parameter(Mandatory = $true)][string]$Root)

  $lRoot = [IO.Path]::GetFullPath($Root)
  $lExtensions = @('.pas', '.dpr', '.inc', '.dfm')
  $lSnapshot = New-Object System.Collections.Generic.List[object]
  if (-not (Test-Path -LiteralPath $lRoot -PathType Container)) {
    throw "Source snapshot root not found: $lRoot"
  }

  Get-ChildItem -LiteralPath $lRoot -Recurse -File |
    Where-Object { $lExtensions -contains $_.Extension.ToLowerInvariant() } |
    Sort-Object FullName |
    ForEach-Object {
      $lRelative = Get-MigrationGateSourceRelativePath -Root $lRoot -Path $_.FullName
      $lSnapshot.Add([pscustomobject]@{
        path = $lRelative
        hash = Get-MigrationGateFileHash -Path $_.FullName
      })
    }
  return [pscustomobject]@{
    root = $lRoot
    files = $lSnapshot.ToArray()
  }
}

function Compare-MigrationGateSourceSnapshot {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][object]$Snapshot
  )

  $lCurrent = New-MigrationGateSourceSnapshot -Root $Root
  $lBefore = @{}
  foreach ($lFile in @($Snapshot.files)) {
    $lBefore[[string]$lFile.path] = [string]$lFile.hash
  }
  $lAfter = @{}
  foreach ($lFile in @($lCurrent.files)) {
    $lAfter[[string]$lFile.path] = [string]$lFile.hash
  }

  $lBeforeNames = @($lBefore.Keys | Sort-Object)
  $lAfterNames = @($lAfter.Keys | Sort-Object)
  $lAdded = @($lAfterNames | Where-Object { -not $lBefore.ContainsKey($_) })
  $lRemoved = @($lBeforeNames | Where-Object { -not $lAfter.ContainsKey($_) })
  $lChanged = @($lBeforeNames | Where-Object { $lAfter.ContainsKey($_) -and ($lBefore[$_] -ne $lAfter[$_]) })
  $lMutated = (($lAdded.Count + $lRemoved.Count + $lChanged.Count) -gt 0)

  return [pscustomobject]@{
    status = if ($lMutated) { 'mutated' } else { 'unchanged' }
    beforeCount = $lBeforeNames.Count
    afterCount = $lAfterNames.Count
    addedFiles = @($lAdded)
    removedFiles = @($lRemoved)
    changedFiles = @($lChanged)
  }
}

function New-MigrationGatePlanSourceMutationResult {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][object]$Snapshot
  )

  $lMutation = Compare-MigrationGateSourceSnapshot -Root $Root -Snapshot $Snapshot
  return [pscustomobject]@{
    name = $Name
    workingDirectory = [IO.Path]::GetFullPath($Root)
    filePath = ''
    arguments = @()
    command = 'compare report-only plan source snapshot'
    exitCode = if ($lMutation.status -eq 'mutated') { 1 } else { 0 }
    elapsedSeconds = 0
    stdout = ''
    stderr = ''
    sourceMutation = $lMutation
  }
}

function Add-MigrationGateReportOnlyPlanResult {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[object]]$Results,
    [Parameter(Mandatory = $true)][object]$PlanResult,
    [Parameter(Mandatory = $true)][string]$ManifestPath,
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][string]$DelphiSemanticsRoot,
    [Parameter(Mandatory = $true)][string]$DakRoot,
    [Parameter(Mandatory = $true)][object]$MutationSnapshot,
    [Parameter(Mandatory = $true)][string]$MutationRoot,
    [object[]]$Provenance = @(),
    [switch]$AllowDirty
  )

  Add-GateStepResult `
    -Results $Results `
    -Result $PlanResult `
    -ManifestPath $ManifestPath `
    -WorkRoot $WorkRoot `
    -DelphiSemanticsRoot $DelphiSemanticsRoot `
    -DakRoot $DakRoot `
    -Provenance $Provenance `
    -AllowDirty:$AllowDirty `
    -NoThrow

  Add-GateStepResult `
    -Results $Results `
    -Result (New-MigrationGatePlanSourceMutationResult `
      -Name 'Check report-only plan source mutation' `
      -Root $MutationRoot `
      -Snapshot $MutationSnapshot) `
    -ManifestPath $ManifestPath `
    -WorkRoot $WorkRoot `
    -DelphiSemanticsRoot $DelphiSemanticsRoot `
    -DakRoot $DakRoot `
    -Provenance $Provenance `
    -AllowDirty:$AllowDirty

  if ([int]$PlanResult.exitCode -ne 0) {
    throw "$($PlanResult.name) failed with exit code $($PlanResult.exitCode)"
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
$lLogDir = Join-Path $WorkRoot 'logs'

if (-not (Test-Path -LiteralPath $lFixture -PathType Container)) {
  throw "maxTdb fixture not found: $lFixture"
}

Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath $WorkRoot -Description 'Gate work root'
Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath $lClone -Description 'maxTdb clone path'
Assert-NoFixtureCollision -FixtureRoot $lFixture -CandidatePath (Split-Path -Parent $lReport) -Description 'maxTdb report directory'

$lWorkRootLock = New-MigrationGateWorkRootLock -WorkRoot $WorkRoot
try {

Write-MigrationGateManifest `
  -Path $lManifest `
  -WorkRoot $WorkRoot `
  -DelphiSemanticsRoot $DelphiSemanticsRoot `
  -DakRoot $DakRoot `
  -Provenance $lGateProvenance `
  -AllowDirty:$AllowDirty

$lResults = New-Object System.Collections.Generic.List[object]

if (-not $SkipBuild) {
  Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
    -Name 'Build DelphiSemantics tests' `
    -WorkingDirectory $DelphiSemanticsRoot `
    -FilePath 'cmd.exe' `
    -Arguments @('/C', 'build-delphi.bat', 'tests\delphiSemanticsTests.dproj', '-config', 'Debug', '-platform', 'Win32', '-target', 'Rebuild', '-test-output-dir', 'tests\bin') `
    -ArtifactDirectory $lLogDir `
    -NoThrow)
}

Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
  -Name 'Run DelphiSemantics tests' `
  -WorkingDirectory $DelphiSemanticsRoot `
  -FilePath 'tests\bin\delphiSemanticsTests.exe' `
  -Arguments @('--hidebanner', '--consolemode:quiet') `
  -ArtifactDirectory $lLogDir `
  -NoThrow)

if (-not $SkipBuild) {
  Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
    -Name 'Build DAK tests' `
    -WorkingDirectory $DakRoot `
    -FilePath 'cmd.exe' `
    -Arguments @('/C', 'build-delphi.bat', 'tests\DelphiAIKit.Tests.dproj', '-config', 'Debug', '-platform', 'Win64', '-target', 'Rebuild') `
    -ArtifactDirectory $lLogDir `
    -NoThrow)
}

Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-DakRemoveWithTests `
  -DakRoot $DakRoot `
  -WorkRoot $WorkRoot `
  -ShardCount $DakTestShards `
  -Profile $DakTestProfile `
  -ArtifactDirectory $lLogDir `
  -NoThrow)

if (-not $SkipBuild) {
  Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
    -Name 'Build DAK CLI' `
    -WorkingDirectory $DakRoot `
    -FilePath 'cmd.exe' `
    -Arguments @('/C', 'build-delphi.bat', 'projects\DelphiAIKit.dproj', '-config', 'Debug', '-platform', 'Win64', '-target', 'Rebuild') `
    -ArtifactDirectory $lLogDir `
    -NoThrow)
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
$lPlanSourceSnapshot = New-MigrationGateSourceSnapshot -Root $lClone
Add-MigrationGateReportOnlyPlanResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -MutationRoot $lClone -MutationSnapshot $lPlanSourceSnapshot -PlanResult (Invoke-GateStep `
  -Name 'Run cloned maxTdb report-only plan' `
  -WorkingDirectory $DakRoot `
  -FilePath 'bin\DelphiAIKit.exe' `
  -Arguments @('remove-with', '--project', $lProject, '--all', '--mode', 'plan', '--format', 'json', '--output', $lPlanReport) `
  -ArtifactDirectory $lLogDir `
  -NoThrow `
  -MaxOutputLines 0)

Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
  -Name 'Run cloned maxTdb smoke' `
  -WorkingDirectory $DakRoot `
  -FilePath 'bin\DelphiAIKit.exe' `
  -Arguments @('remove-with', '--project', $lProject, '--all', '--mode', 'apply', '--format', 'json', '--output', $lReport) `
  -ArtifactDirectory $lLogDir `
  -NoThrow `
  -MaxOutputLines 0)

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
Assert-MigrationGatePlannedEditParity -PlanJson $lPlanJson -ApplyJson $lJson
if ($lAppliedEdits -lt 1) {
  throw "Expected at least one applied maxTdb edit"
}

$lSkipBuckets = @($lJson.skipped | Group-Object reason | Sort-Object Count -Descending |
  Select-Object Count, Name)

Write-MigrationGateManifest `
  -Path $lManifest `
  -WorkRoot $WorkRoot `
  -DelphiSemanticsRoot $DelphiSemanticsRoot `
  -DakRoot $DakRoot `
  -Provenance $lGateProvenance `
  -Steps $lResults.ToArray() `
  -AllowDirty:$AllowDirty

Write-Host ''
Write-Host '== Migration gate summary'
$lResults | Format-Table -AutoSize | Out-String | Write-Host

$lTotalSeconds = ($lResults | Measure-Object -Property elapsedSeconds -Sum).Sum
$lDominantPhases = @($lResults | Sort-Object elapsedSeconds -Descending | Select-Object -First 3 | ForEach-Object {
  [pscustomobject]@{
    Name = $_.name
    Seconds = $_.elapsedSeconds
    Percent = if ($lTotalSeconds -gt 0) { [Math]::Round(($_.elapsedSeconds / $lTotalSeconds) * 100, 1) } else { 0 }
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
} finally {
  Close-MigrationGateWorkRootLock -Lock $lWorkRootLock
}
