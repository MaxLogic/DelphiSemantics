[CmdletBinding()]
param(
  [string]$DelphiSemanticsRoot = '',
  [string]$DakRoot = 'F:\projects\MaxLogic\DelphiAiKit',
  [string]$WorkRoot = '',
  [ValidateRange(1, 16)][int]$DakTestShards = 1,
  [ValidateSet('Gate', 'Full')][string]$DakTestProfile = 'Gate',
  [ValidateRange(1, 86400)][int]$StepTimeoutSeconds = 14400,
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
  Write-Host 'Each native step has a finite deadline (-StepTimeoutSeconds, default 14400); timeout exits 124.'
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
$DelphiSemanticsRoot = [IO.Path]::GetFullPath($DelphiSemanticsRoot)
$DakRoot = [IO.Path]::GetFullPath($DakRoot)

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

function ConvertTo-WindowsCommandArgument {
  param([AllowEmptyString()][string]$Value)

  if (($Value.Length -gt 0) -and ($Value -notmatch '[\s"]')) {
    return $Value
  }
  $lQuoted = New-Object Text.StringBuilder
  [void]$lQuoted.Append('"')
  $lBackslashes = 0
  foreach ($lChar in $Value.ToCharArray()) {
    if ($lChar -eq '\') {
      $lBackslashes++
    } elseif ($lChar -eq '"') {
      [void]$lQuoted.Append(('\' * ($lBackslashes * 2 + 1)))
      [void]$lQuoted.Append('"')
      $lBackslashes = 0
    } else {
      [void]$lQuoted.Append(('\' * $lBackslashes))
      [void]$lQuoted.Append($lChar)
      $lBackslashes = 0
    }
  }
  [void]$lQuoted.Append(('\' * ($lBackslashes * 2)))
  [void]$lQuoted.Append('"')
  return $lQuoted.ToString()
}

function Invoke-GateStep {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$WorkingDirectory,
    [Parameter(Mandatory = $true)][string]$FilePath,
    [string[]]$Arguments = @(),
    [string]$ArtifactDirectory = '',
    [switch]$NoThrow,
    [int]$MaxOutputLines = 400,
    [ValidateRange(1, 86400)][int]$TimeoutSeconds = $StepTimeoutSeconds
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
  $lStamp += '-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
  $lStdout = Join-Path $ArtifactDirectory "$lStamp-$lSafeName.stdout.txt"
  $lStderr = Join-Path $ArtifactDirectory "$lStamp-$lSafeName.stderr.txt"
  $lMetadata = Join-Path $ArtifactDirectory "$lStamp-$lSafeName.process.json"
  $lTrace = $null
  $lFailure = ''
  $lExitCode = 125
  $lNativeExitCode = $null
  $lTimedOut = $false
  $lCleanupComplete = $false

  $lTimer = [Diagnostics.Stopwatch]::StartNew()
  try {
    $lExecutable = if ([IO.Path]::IsPathRooted($FilePath)) {
      $FilePath
    } else {
      Join-Path $lWorkingDirectory $FilePath
    }
    Assert-ExistingFile $lExecutable
    # DS-687: the job owns descendants before the suspended root can launch them.
    # Direct file handles also avoid an unbounded drain after a parent exits.
    . (Join-Path $DakRoot 'tests\scripts\Dak.ProcessTrace.ps1')
    $lCommandLine = ((@($lExecutable) + @($Arguments) | ForEach-Object { ConvertTo-WindowsCommandArgument $_ }) -join ' ')
    $lTrace = Invoke-TracedProcess -CommandLine $lCommandLine -WorkingDirectory $lWorkingDirectory -Environment @{} -LogPath $lMetadata -TimeoutSeconds $TimeoutSeconds -NoOutputText -StdoutPath $lStdout -StderrPath $lStderr
    $lNativeExitCode = $lTrace.exit_code
    $lTimedOut = $lTrace.timed_out
    $lCleanupComplete = $lTrace.cleanup_complete
    if (-not $lCleanupComplete) {
      $lFailure = 'Owned process supervision is incomplete.'
    } elseif ($lTimedOut) {
      $lExitCode = 124
    } else {
      $lExitCode = $lNativeExitCode
    }
  } catch {
    $lFailure = $_.Exception.ToString()
  } finally {
    $lTimer.Stop()
  }

  $lOutputLines = @()
  if (Test-Path -LiteralPath $lStdout -PathType Leaf) {
    $lOutputLines = @(if ($MaxOutputLines -lt 0) { Get-Content -LiteralPath $lStdout } else { Get-Content -LiteralPath $lStdout -TotalCount ([Math]::Max(1, $MaxOutputLines + 1)) })
  }
  if (Test-Path -LiteralPath $lStderr -PathType Leaf) {
    $lOutputLines += @(if ($MaxOutputLines -lt 0) { Get-Content -LiteralPath $lStderr } else { Get-Content -LiteralPath $lStderr -TotalCount ([Math]::Max(1, $MaxOutputLines + 1)) })
  }
  if ($lOutputLines.Count -gt 0) {
    if ($MaxOutputLines -eq 0) {
      Write-Host "   output suppressed; see $lStdout and $lStderr."
    } elseif (($MaxOutputLines -gt 0) -and ($lOutputLines.Count -gt $MaxOutputLines)) {
      $lOutputLines | Select-Object -First $MaxOutputLines | ForEach-Object { Write-Host $_ }
      Write-Host "   ... output truncated; see $lStdout and $lStderr."
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
    nativeExitCode = $lNativeExitCode
    timedOut = $lTimedOut
    cleanupComplete = $lCleanupComplete
    timeoutSeconds = $TimeoutSeconds
    failure = $lFailure
    processes = if ($null -eq $lTrace) { @() } else { @($lTrace.processes) }
    elapsedSeconds = [Math]::Round($lTimer.Elapsed.TotalSeconds, 1)
    stdout = $lStdout
    stderr = $lStderr
    metadata = $lMetadata
  }
  $lResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $lMetadata -Encoding UTF8

  if ($lExitCode -ne 0) {
    Write-Host "!! $Name failed in $($lResult.elapsedSeconds)s with exit code $lExitCode"
    if (-not $NoThrow) {
      throw "$Name failed with exit code $lExitCode; details: $lMetadata; $lFailure"
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
    [Parameter(Mandatory = $true)][string]$TestExecutable,
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
    -FilePath $TestExecutable `
    -Arguments @('--hidebanner', '--consolemode:quiet', "-r:$($lFilters -join ',')") `
    -ArtifactDirectory $ArtifactDirectory `
    -NoThrow:$NoThrow
}

function Get-DakSemanticConsumerTestFilters {
  param([Parameter(Mandatory = $true)][string]$DakRoot)

  $lRequiredUnits = @(
    [pscustomobject]@{ Unit = 'test.symbolmap.pas'; UnitName = 'Test.SymbolMap'; Filter = 'Test.SymbolMap' },
    [pscustomobject]@{ Unit = 'test.deps.pas'; UnitName = 'Test.Deps'; Filter = 'Test.Deps' },
    [pscustomobject]@{ Unit = 'test.globalvars.pas'; UnitName = 'Test.GlobalVars'; Filter = 'Test.GlobalVars' }
  )

  $lFilters = New-Object System.Collections.Generic.List[string]
  foreach ($lRequiredUnit in $lRequiredUnits) {
    $lUnitPath = Join-Path $DakRoot "tests\units\$($lRequiredUnit.Unit)"
    Assert-ExistingFile $lUnitPath
    $lSource = Get-Content -LiteralPath $lUnitPath -Raw
    if ($lSource -notmatch "(?im)^\s*unit\s+$([Regex]::Escape($lRequiredUnit.UnitName))\s*;") {
      throw "DAK semantic-consumer unit $lUnitPath does not declare unit $($lRequiredUnit.UnitName)."
    }
    if ($lSource -notmatch '(?im)^\s*\[TestFixture\]\s*$') {
      throw "DAK semantic-consumer unit $lUnitPath declares no DUnitX TestFixture."
    }
    if ($lSource -notmatch '(?im)^\s*\[Test\](\s*procedure\b)?') {
      throw "DAK semantic-consumer unit $lUnitPath declares no DUnitX Test methods."
    }
    if ($lSource -notmatch '(?im)TDUnitX\.RegisterTestFixture\(') {
      throw "DAK semantic-consumer unit $lUnitPath registers no DUnitX fixtures."
    }
    $lFilters.Add([string]$lRequiredUnit.Filter)
  }

  if ($lFilters.Count -eq 0) {
    throw 'No DAK semantic-consumer DUnitX filters selected.'
  }

  return $lFilters.ToArray()
}

function Get-DakSemanticConsumerTestArguments {
  param(
    [Parameter(Mandatory = $true)][string]$DakRoot,
    [Parameter(Mandatory = $true)][string]$Profile,
    [string[]]$Filters = @()
  )

  $lFilters = @($Filters)
  if ($lFilters.Count -eq 0) {
    $lFilters = @(Get-DakSemanticConsumerTestFilters -DakRoot $DakRoot)
  }
  if ($Profile -eq 'Gate') {
    $lFilters = @($lFilters | Sort-Object)
  }
  if ($lFilters.Count -eq 0) {
    throw "DAK semantic-consumer test profile '$Profile' selected no filters"
  }

  return @('--hidebanner', '--consolemode:quiet', "-r:$($lFilters -join ',')")
}

function Assert-DUnitXStepDiscoveredTests {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$StepName
  )

  if ([int]$Result.exitCode -ne 0) {
    return
  }
  if ([string]::IsNullOrWhiteSpace([string]$Result.stdout) -or
      (-not (Test-Path -LiteralPath $Result.stdout -PathType Leaf))) {
    throw "$StepName did not produce a readable stdout artifact for DUnitX discovery."
  }

  $lText = Get-Content -LiteralPath $Result.stdout -Raw
  $lMatch = [Regex]::Match($lText, 'Tests\s+Found\s*:\s*(\d+)', [Text.RegularExpressions.RegexOptions]::IgnoreCase)
  if (-not $lMatch.Success) {
    throw "$StepName output did not include a DUnitX Tests Found count."
  }
  if ([int]$lMatch.Groups[1].Value -le 0) {
    throw "$StepName selected no DUnitX tests."
  }
}

function Set-GateStepFailure {
  param(
    [Parameter(Mandatory = $true)][object]$Result,
    [Parameter(Mandatory = $true)][string]$Message
  )

  $Result.exitCode = 1
  $Result | Add-Member -MemberType NoteProperty -Name failureReason -Value $Message -Force
  return $Result
}

function Invoke-DakSemanticConsumerTestFilter {
  param(
    [Parameter(Mandatory = $true)][string]$DakRoot,
    [Parameter(Mandatory = $true)][string]$TestExecutable,
    [Parameter(Mandatory = $true)][string]$WorkRoot,
    [Parameter(Mandatory = $true)][string]$Profile,
    [Parameter(Mandatory = $true)][string]$Filter,
    [string]$ArtifactDirectory = '',
    [switch]$NoThrow
  )

  $lArguments = @(Get-DakSemanticConsumerTestArguments -DakRoot $DakRoot -Profile $Profile `
    -Filters @($Filter))
  Write-Host "   DAK semantic-consumer profile: $Profile"
  Write-Host "   DAK semantic-consumer filters: $($lArguments[-1])"
  Write-Host '   policy: semantic-consumer gate covers SymbolMap, deps, and GlobalVars separately from remove-with.'

  $lResult = Invoke-GateStep `
    -Name "Run DAK semantic-consumer tests $Filter" `
    -WorkingDirectory $DakRoot `
    -FilePath $TestExecutable `
    -Arguments $lArguments `
    -ArtifactDirectory $ArtifactDirectory `
    -NoThrow:$NoThrow
  try {
    Assert-DUnitXStepDiscoveredTests -Result $lResult `
      -StepName "Run DAK semantic-consumer tests $Filter"
  } catch {
    if ($NoThrow) {
      return Set-GateStepFailure -Result $lResult -Message $_.Exception.Message
    }
    throw
  }
  return $lResult
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

function Get-MigrationGateArrayProperty {
  param(
    [object]$Object,
    [Parameter(Mandatory = $true)][string]$Name
  )

  if ($null -eq $Object) {
    return @()
  }

  $lProperty = $Object.PSObject.Properties[$Name]
  if ($null -eq $lProperty) {
    throw "Expected report array property $Name."
  }

  $lValue = $lProperty.Value
  if ($null -eq $lValue) {
    throw "Expected report array property $Name to be non-null."
  }
  if ($lValue -isnot [array]) {
    throw "Expected report property $Name to be a $Name array."
  }
  return @($lValue)
}

function Get-MigrationGateNestedIntProperty {
  param(
    [object]$Object,
    [Parameter(Mandatory = $true)][string]$ParentName,
    [Parameter(Mandatory = $true)][string]$Name
  )

  $lParent = Get-MigrationGateObjectProperty -Object $Object -Name $ParentName
  if (-not (Test-MigrationGateObjectProperty -Object $lParent -Name $Name)) {
    throw "Expected report property $ParentName.$Name."
  }
  $lValue = Get-MigrationGateObjectProperty -Object $lParent -Name $Name
  if ((($lValue -isnot [int]) -and ($lValue -isnot [long])) -or ($lValue -lt 0)) {
    throw "Expected report property $ParentName.$Name to be a nonnegative integer."
  }
  return [long]$lValue
}

function Assert-MigrationGateNonblankStringProperty {
  param([object]$Object, [string]$Name, [string]$Context)

  $lValue = Get-MigrationGateObjectProperty -Object $Object -Name $Name
  if (($lValue -isnot [string]) -or [string]::IsNullOrWhiteSpace($lValue)) {
    throw "Expected $Context.$Name to be a nonblank string."
  }
  return $lValue
}

function Assert-MigrationGateReportAccounting {
  param([Parameter(Mandatory = $true)][object]$ReportJson)

  $lDiscovered = Get-MigrationGateNestedIntProperty -Object $ReportJson -ParentName 'summary' -Name 'withStatements'
  $lPlannedCount = Get-MigrationGateNestedIntProperty -Object $ReportJson -ParentName 'summary' -Name 'plannedEdits'
  $lSkippedCount = Get-MigrationGateNestedIntProperty -Object $ReportJson -ParentName 'summary' -Name 'skipped'
  $lCoveredCount = Get-MigrationGateNestedIntProperty -Object $ReportJson -ParentName 'summary' -Name 'covered'
  $lPlanned = @(Get-MigrationGateArrayProperty -Object $ReportJson -Name 'plannedEdits')
  $lSkipped = @(Get-MigrationGateArrayProperty -Object $ReportJson -Name 'skipped')
  $lCovered = @(Get-MigrationGateArrayProperty -Object $ReportJson -Name 'covered')
  if (($lDiscovered -ne ($lPlannedCount + $lSkippedCount + $lCoveredCount)) -or
      ($lPlanned.Count -ne $lPlannedCount) -or ($lSkipped.Count -ne $lSkippedCount) -or
      ($lCovered.Count -ne $lCoveredCount)) {
    throw 'Expected discovered statements and planned/skipped/covered summary counts to match report arrays.'
  }

  $lIds = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::Ordinal)
  $lParents = New-Object 'System.Collections.Generic.Dictionary[string,object]' ([StringComparer]::Ordinal)
  foreach ($lEntry in $lPlanned) {
    $lId = Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'statementId' -Context 'planned edit'
    Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'file' -Context 'planned edit' | Out-Null
    if (-not $lIds.Add($lId)) { throw "Duplicate statement identity $lId" }
    if ((Get-MigrationGateObjectProperty -Object $lEntry -Name 'status') -ne 'planned') {
      throw "Expected planned status for $lId"
    }
    $lEdits = @(Get-MigrationGateArrayProperty -Object $lEntry -Name 'edits')
    if ($lEdits.Count -eq 0) { throw "Expected actionable edits for planned statement $lId" }
    $lProvenRewrite = @($lEdits | Where-Object {
      ($_.kind -eq 'replace-statement') -and ($_.statementId -ceq $lId) -and
      ($_.file -ceq $lEntry.file) -and (-not [string]::IsNullOrWhiteSpace([string]$_.replacementText))
    })
    if ($lProvenRewrite.Count -eq 0) { throw "Expected a parent replacement edit for $lId" }
    $lParents[$lId] = $lEntry
  }
  foreach ($lEntry in $lSkipped) {
    $lId = Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'statementId' -Context 'skipped statement'
    Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'file' -Context 'skipped statement' | Out-Null
    Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'reason' -Context 'skipped statement' | Out-Null
    if (-not $lIds.Add($lId)) { throw "Duplicate statement identity $lId" }
  }
  foreach ($lEntry in $lCovered) {
    $lId = Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'statementId' -Context 'covered statement'
    $lFile = Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'file' -Context 'covered statement'
    $lReason = Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'reason' -Context 'covered statement'
    $lParentId = Assert-MigrationGateNonblankStringProperty -Object $lEntry -Name 'coveredByStatementId' -Context 'covered statement'
    if (-not $lIds.Add($lId)) { throw "Duplicate statement identity $lId" }
    if (($lEntry.status -ne 'planned') -or ($lReason -ne 'covered-by-parent-rewrite') -or
        (-not $lParents.ContainsKey($lParentId)) -or
        ($lFile -ne (Get-MigrationGateObjectProperty -Object $lParents[$lParentId] -Name 'file'))) {
      throw "Invalid covered parent rewrite for $lId ($lParentId)"
    }
  }
}

function Assert-MigrationGatePlanDtoParity {
  param([Parameter(Mandatory = $true)][object]$PlanJson)

  $lParity = Get-MigrationGateObjectProperty -Object $PlanJson -Name 'semanticDtoParity'
  if ((Get-MigrationGateObjectProperty -Object $lParity -Name 'status') -cne 'passed') {
    throw 'Expected semanticDtoParity.status=passed in report-only plan.'
  }
  $lMismatchCount = Get-MigrationGateNestedIntProperty -Object $PlanJson -ParentName 'semanticDtoParity' -Name 'mismatchCount'
  if ($lMismatchCount -ne 0) { throw "Expected semanticDtoParity.mismatchCount=0, got $lMismatchCount" }
}

function Assert-MigrationGateAccountingParity {
  param([Parameter(Mandatory = $true)][object]$PlanJson,
    [Parameter(Mandatory = $true)][object]$ApplyJson)

  foreach ($lName in @('withStatements', 'plannedEdits', 'skipped', 'covered')) {
    $lPlanCount = Get-MigrationGateNestedIntProperty -Object $PlanJson -ParentName 'summary' -Name $lName
    $lApplyCount = Get-MigrationGateNestedIntProperty -Object $ApplyJson -ParentName 'summary' -Name $lName
    if ($lPlanCount -ne $lApplyCount) { throw "Expected plan/apply $lName parity: plan=$lPlanCount apply=$lApplyCount" }
  }
  $lPlanCovered = @((Get-MigrationGateArrayProperty -Object $PlanJson -Name 'covered') |
    ForEach-Object { ConvertTo-MigrationGateStableJson ([ordered]@{
      statementId = $_.statementId; file = $_.file; status = $_.status
      reason = $_.reason; coveredByStatementId = $_.coveredByStatementId
    }) } | Sort-Object)
  $lApplyCovered = @((Get-MigrationGateArrayProperty -Object $ApplyJson -Name 'covered') |
    ForEach-Object { ConvertTo-MigrationGateStableJson ([ordered]@{
      statementId = $_.statementId; file = $_.file; status = $_.status
      reason = $_.reason; coveredByStatementId = $_.coveredByStatementId
    }) } | Sort-Object)
  if (@(Compare-Object $lPlanCovered $lApplyCovered).Count -ne 0) {
    throw 'Expected plan/apply covered statement shapes and parent relationships to match.'
  }
}

function Assert-MigrationGateObjectRequiredProperty {
  param(
    [object]$Object,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Context
  )

  if (-not (Test-MigrationGateObjectProperty -Object $Object -Name $Name)) {
    throw "Expected $Context.$Name."
  }
  if ($null -eq (Get-MigrationGateObjectProperty -Object $Object -Name $Name)) {
    throw "Expected $Context.$Name to be non-null."
  }
}

function Assert-MigrationGateSkippedStatementContract {
  param([Parameter(Mandatory = $true)][object]$SkippedStatement)

  foreach ($lName in @('statementId', 'file', 'reason')) {
    Assert-MigrationGateObjectRequiredProperty -Object $SkippedStatement -Name $lName `
      -Context 'skipped statement'
  }

  if (Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'range') {
    $lRange = Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'range'
    foreach ($lRangeName in @('startLine', 'startCol', 'endLine', 'endCol')) {
      Assert-MigrationGateObjectRequiredProperty -Object $lRange -Name $lRangeName `
        -Context "skipped statement range"
    }
  }
}

function Get-MigrationGateSkippedStatementShape {
  param([Parameter(Mandatory = $true)][object]$SkippedStatement)

  Assert-MigrationGateSkippedStatementContract -SkippedStatement $SkippedStatement

  $lShape = [ordered]@{
    hasStatementId = Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'statementId'
    statementId = [string](Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'statementId')
    hasFile = Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'file'
    file = [string](Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'file')
    hasRange = Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'range'
    range = ConvertTo-MigrationGateStableJson (Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'range')
    hasReason = Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'reason'
    reason = [string](Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'reason')
    hasDetailedReason = Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'detailedReason'
    detailedReason = [string](Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'detailedReason')
    hasUnsupportedIdentifierRole = Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'unsupportedIdentifierRole'
    unsupportedIdentifierRole = [string](Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'unsupportedIdentifierRole')
    hasSignature = Test-MigrationGateObjectProperty -Object $SkippedStatement -Name 'signature'
    signature = [string](Get-MigrationGateObjectProperty -Object $SkippedStatement -Name 'signature')
  }
  return ConvertTo-MigrationGateStableJson $lShape
}

function Get-MigrationGateSkippedReasonBucketShapes {
  param([object[]]$SkippedStatements)

  return @(
    $SkippedStatements |
      Group-Object { [string](Get-MigrationGateObjectProperty -Object $_ -Name 'reason') } |
      ForEach-Object {
        ConvertTo-MigrationGateStableJson ([ordered]@{
          reason = [string]$_.Name
          count = [int]$_.Count
        })
      } |
      Sort-Object
  )
}

function Assert-MigrationGateSkippedParity {
  param(
    [Parameter(Mandatory = $true)][object]$PlanJson,
    [Parameter(Mandatory = $true)][object]$ApplyJson
  )

  $lPlanSkippedSummary = Get-MigrationGateNestedIntProperty -Object $PlanJson `
    -ParentName 'summary' -Name 'skipped'
  $lApplySkippedSummary = Get-MigrationGateNestedIntProperty -Object $ApplyJson `
    -ParentName 'summary' -Name 'skipped'
  if ($lPlanSkippedSummary -ne $lApplySkippedSummary) {
    throw "Expected maxTdb report-only and apply skipped summary counts to match, got plan=$lPlanSkippedSummary apply=$lApplySkippedSummary"
  }

  $lPlanSkipped = @(Get-MigrationGateArrayProperty -Object $PlanJson -Name 'skipped')
  $lApplySkipped = @(Get-MigrationGateArrayProperty -Object $ApplyJson -Name 'skipped')
  if (($lPlanSkipped.Count -ne $lPlanSkippedSummary) -or
      ($lApplySkipped.Count -ne $lApplySkippedSummary) -or
      ($lPlanSkipped.Count -ne $lApplySkipped.Count)) {
    throw "Expected maxTdb report-only and apply skipped array counts to match summary skipped count, got planSummary=$lPlanSkippedSummary planArray=$($lPlanSkipped.Count) applySummary=$lApplySkippedSummary applyArray=$($lApplySkipped.Count)"
  }

  $lPlanReasonBuckets = @(Get-MigrationGateSkippedReasonBucketShapes -SkippedStatements $lPlanSkipped)
  $lApplyReasonBuckets = @(Get-MigrationGateSkippedReasonBucketShapes -SkippedStatements $lApplySkipped)
  $lReasonDifferences = @(Compare-Object $lPlanReasonBuckets $lApplyReasonBuckets)
  if ($lReasonDifferences.Count -ne 0) {
    $lSample = @($lReasonDifferences | Select-Object -First 4 | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" })
    throw "Expected maxTdb report-only and apply skipped reason buckets to match. Differences: $($lSample -join ' | ')"
  }

  $lPlanShapes = @(
    $lPlanSkipped |
      ForEach-Object { Get-MigrationGateSkippedStatementShape -SkippedStatement $_ } |
      Sort-Object
  )
  $lApplyShapes = @(
    $lApplySkipped |
      ForEach-Object { Get-MigrationGateSkippedStatementShape -SkippedStatement $_ } |
      Sort-Object
  )
  $lShapeDifferences = @(Compare-Object $lPlanShapes $lApplyShapes)
  if ($lShapeDifferences.Count -ne 0) {
    $lSample = @($lShapeDifferences | Select-Object -First 4 | ForEach-Object { "$($_.SideIndicator) $($_.InputObject)" })
    throw "Expected maxTdb report-only and apply skipped shapes to match. Differences: $($lSample -join ' | ')"
  }
}

function Get-MigrationGateSourceRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $lRoot = [IO.Path]::GetFullPath($Root)
  $lPath = [IO.Path]::GetFullPath($Path)
  $lGetRelativePath = [IO.Path].GetMethod('GetRelativePath', [type[]]@([string], [string]))
  if ($null -ne $lGetRelativePath) {
    $lRelative = [IO.Path]::GetRelativePath($lRoot, $lPath)
    return $lRelative.Replace([IO.Path]::AltDirectorySeparatorChar, [IO.Path]::DirectorySeparatorChar)
  }

  $lDirectorySeparator = [IO.Path]::DirectorySeparatorChar.ToString()
  $lAltDirectorySeparator = [IO.Path]::AltDirectorySeparatorChar.ToString()
  if ((-not $lRoot.EndsWith($lDirectorySeparator)) -and
    (-not $lRoot.EndsWith($lAltDirectorySeparator))) {
    $lRoot = $lRoot + $lDirectorySeparator
  }

  $lRootUri = [Uri]$lRoot
  $lPathUri = [Uri]$lPath
  $lRelative = [Uri]::UnescapeDataString($lRootUri.MakeRelativeUri($lPathUri).ToString())
  $lRelative = $lRelative.Replace('/', [IO.Path]::DirectorySeparatorChar)
  return $lRelative.Replace([IO.Path]::AltDirectorySeparatorChar, [IO.Path]::DirectorySeparatorChar)
}

function Get-MigrationGateFileHash {
  param([Parameter(Mandatory = $true)][string]$Path)

  $lGetFileHash = Get-Command Get-FileHash -ErrorAction SilentlyContinue
  if ($null -ne $lGetFileHash) {
    $lHash = Get-FileHash -LiteralPath $Path -Algorithm SHA256
    return $lHash.Hash.ToLowerInvariant()
  }

  $lSha256 = [Security.Cryptography.SHA256]::Create()
  $lStream = [IO.File]::OpenRead($Path)
  try {
    $lBytes = $lSha256.ComputeHash($lStream)
    return (($lBytes | ForEach-Object { $_.ToString('x2') }) -join '')
  }
  finally {
    $lStream.Dispose()
    $lSha256.Dispose()
  }
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
if (-not $SkipBuild) {
  Assert-ExistingFile (Join-Path $DakRoot 'bin\DelphiAIKit.exe')
}

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
$lDakBuildHost = Join-Path $DakRoot 'bin\DelphiAIKit.exe'
$lBuildRunId = 'ds642-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$lSemanticsTestOutput = Join-Path $DelphiSemanticsRoot "tests\.dak\delphiSemanticsTests\build\$lBuildRunId"
$lDakTestOutput = Join-Path $DakRoot "tests\.dak\DelphiAIKit.Tests\build\$lBuildRunId"
$lDakCliOutput = Join-Path $DakRoot "projects\.dak\DelphiAIKit\build\$lBuildRunId"
$lSemanticsPrivateExe = Join-Path $lSemanticsTestOutput 'delphiSemanticsTests.exe'
$lSemanticsTestExe = if ($SkipBuild) { Join-Path $DelphiSemanticsRoot 'tests\bin\delphiSemanticsTests.exe' } else { Join-Path $DelphiSemanticsRoot "tests\bin\$lBuildRunId.exe" }
$lDakTestExe = if ($SkipBuild) { Join-Path $DakRoot 'tests\DelphiAIKit.Tests.exe' } else { Join-Path $lDakTestOutput 'DelphiAIKit.Tests.exe' }
$lDakCliExe = if ($SkipBuild) { $lDakBuildHost } else { Join-Path $lDakCliOutput 'DelphiAIKit.exe' }
$lMaxTdbRemoveWithBuildArgs = @('--delphi', '23.0', '--platform', 'Win32', '--config', 'Debug')

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
    -FilePath $lDakBuildHost `
    -Arguments @('build', '--project', (Join-Path $DelphiSemanticsRoot 'tests\delphiSemanticsTests.dproj'), '--delphi', '23.0', '--config', 'Debug', '--platform', 'Win32', '--target', 'Rebuild', '--test-output-dir', $lSemanticsTestOutput, '--build-timeout-sec', '1800', '--ai', '--show-warnings', '--keep-logs') `
    -ArtifactDirectory $lLogDir `
    -NoThrow)

  # The DelphiSemantics test support derives its repository root from the EXE's parent directories.
  # Keep compiler outputs private and copy only the proven EXE into a unique tests\bin name.
  Assert-ExistingFile $lSemanticsPrivateExe
  if (Test-Path -LiteralPath $lSemanticsTestExe) {
    throw "Refusing to overwrite an existing DelphiSemantics test EXE: $lSemanticsTestExe"
  }
  Copy-Item -LiteralPath $lSemanticsPrivateExe -Destination $lSemanticsTestExe -ErrorAction Stop
  $lPrivateHash = (Get-FileHash -LiteralPath $lSemanticsPrivateExe -Algorithm SHA256).Hash
  $lConsumerHash = (Get-FileHash -LiteralPath $lSemanticsTestExe -Algorithm SHA256).Hash
  if ($lPrivateHash -cne $lConsumerHash) {
    throw "DelphiSemantics test EXE copy differs from private build: $lSemanticsTestExe"
  }
  Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result ([pscustomobject]@{
    name = 'Bind DelphiSemantics test executable'
    filePath = $lSemanticsTestExe
    privateExecutable = $lSemanticsPrivateExe
    sha256 = $lConsumerHash
    exitCode = 0
    elapsedSeconds = 0
  })
}

Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
  -Name 'Run DelphiSemantics tests' `
  -WorkingDirectory $DelphiSemanticsRoot `
  -FilePath $lSemanticsTestExe `
  -Arguments @('--hidebanner', '--consolemode:quiet') `
  -ArtifactDirectory $lLogDir `
  -NoThrow)

if (-not $SkipBuild) {
  Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
    -Name 'Build DAK tests' `
    -WorkingDirectory $DakRoot `
    -FilePath $lDakBuildHost `
    -Arguments @('build', '--project', (Join-Path $DakRoot 'tests\DelphiAIKit.Tests.dproj'), '--delphi', '23.0', '--config', 'Debug', '--platform', 'Win64', '--target', 'Rebuild', '--test-output-dir', $lDakTestOutput, '--build-timeout-sec', '1800', '--ai', '--show-warnings', '--keep-logs') `
    -ArtifactDirectory $lLogDir `
    -NoThrow)
}

Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-DakRemoveWithTests `
  -DakRoot $DakRoot `
  -TestExecutable $lDakTestExe `
  -WorkRoot $WorkRoot `
  -ShardCount $DakTestShards `
  -Profile $DakTestProfile `
  -ArtifactDirectory $lLogDir `
  -NoThrow)

$lDakSemanticConsumerFilters = @(Get-DakSemanticConsumerTestFilters -DakRoot $DakRoot)
foreach ($lDakSemanticConsumerFilter in $lDakSemanticConsumerFilters) {
  Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-DakSemanticConsumerTestFilter `
    -DakRoot $DakRoot `
    -TestExecutable $lDakTestExe `
    -WorkRoot $WorkRoot `
    -Profile $DakTestProfile `
    -Filter $lDakSemanticConsumerFilter `
    -ArtifactDirectory $lLogDir `
    -NoThrow)
}

if (-not $SkipBuild) {
  Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
    -Name 'Build DAK CLI' `
    -WorkingDirectory $DakRoot `
    -FilePath $lDakBuildHost `
    -Arguments @('build', '--project', (Join-Path $DakRoot 'projects\DelphiAIKit.dproj'), '--delphi', '23.0', '--config', 'Debug', '--platform', 'Win64', '--target', 'Rebuild', '--test-output-dir', $lDakCliOutput, '--build-timeout-sec', '1800', '--ai', '--show-warnings', '--keep-logs') `
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
  -FilePath $lDakCliExe `
  -Arguments (@('remove-with', '--project', $lProject, '--all', '--mode', 'plan', '--format', 'json', '--diagnostics', 'true', '--output', $lPlanReport) + $lMaxTdbRemoveWithBuildArgs) `
  -ArtifactDirectory $lLogDir `
  -NoThrow `
  -MaxOutputLines 0)

Assert-ExistingFile $lPlanReport
$lPlanJson = Get-Content -LiteralPath $lPlanReport -Raw | ConvertFrom-Json
if ((Get-MigrationGateObjectProperty -Object $lPlanJson -Name 'status') -cne 'ok') {
  throw 'Expected maxTdb report-only status ok.'
}
Assert-MigrationGateReportAccounting -ReportJson $lPlanJson
Assert-MigrationGatePlanDtoParity -PlanJson $lPlanJson

Add-GateStepResult -Results $lResults -ManifestPath $lManifest -WorkRoot $WorkRoot -DelphiSemanticsRoot $DelphiSemanticsRoot -DakRoot $DakRoot -Provenance $lGateProvenance -AllowDirty:$AllowDirty -Result (Invoke-GateStep `
  -Name 'Run cloned maxTdb smoke' `
  -WorkingDirectory $DakRoot `
  -FilePath $lDakCliExe `
  -Arguments (@('remove-with', '--project', $lProject, '--all', '--mode', 'apply', '--format', 'json', '--output', $lReport) + $lMaxTdbRemoveWithBuildArgs) `
  -ArtifactDirectory $lLogDir `
  -NoThrow `
  -MaxOutputLines 0)

Assert-ExistingFile $lReport
$lJson = Get-Content -LiteralPath $lReport -Raw | ConvertFrom-Json
Assert-MigrationGateReportAccounting -ReportJson $lJson
Assert-MigrationGateAccountingParity -PlanJson $lPlanJson -ApplyJson $lJson
$lApplyWithStatements = Get-MigrationGateNestedIntProperty -Object $lJson -ParentName 'summary' -Name 'withStatements'
$lApplyPlannedEdits = Get-MigrationGateNestedIntProperty -Object $lJson -ParentName 'summary' -Name 'plannedEdits'
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
Assert-MigrationGatePlannedEditParity -PlanJson $lPlanJson -ApplyJson $lJson
Assert-MigrationGateSkippedParity -PlanJson $lPlanJson -ApplyJson $lJson
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
