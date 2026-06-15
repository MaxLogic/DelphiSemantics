[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$GateScript = Join-Path $RepoRoot 'scripts\run-migration-gate.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\migration-gate-script-tests'

. (Join-Path $ScriptRoot 'test-support.ps1')
. $GateScript -ImportOnly

function Reset-TestWorkspace {
  $lExpectedRoot = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'tests\bin\migration-gate-script-tests'))
  $lActualRoot = [IO.Path]::GetFullPath($TempRoot)
  if ($lActualRoot -ne $lExpectedRoot) {
    throw "Refusing to reset unexpected test workspace: $lActualRoot"
  }

  if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
  }
  [IO.Directory]::CreateDirectory($TempRoot) | Out-Null
}

function Invoke-Git {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
  )

  $lOutput = & git -C $Repo @Arguments 2>&1
  if ($LASTEXITCODE -ne 0) {
    throw "git $($Arguments -join ' ') failed in ${Repo}: $lOutput"
  }
  return $lOutput
}

function New-TestGitRepo {
  param([Parameter(Mandatory = $true)][string]$Name)

  $lRepo = Join-Path $TempRoot $Name
  [IO.Directory]::CreateDirectory($lRepo) | Out-Null
  & git -C $lRepo init | Out-Null
  if ($LASTEXITCODE -ne 0) {
    throw "git init failed in $lRepo"
  }
  Invoke-Git -Repo $lRepo config user.email 'migration-gate-test@example.invalid' | Out-Null
  Invoke-Git -Repo $lRepo config user.name 'Migration Gate Test' | Out-Null
  Set-Content -LiteralPath (Join-Path $lRepo 'tracked.txt') -Value 'clean' -Encoding UTF8
  Invoke-Git -Repo $lRepo add tracked.txt | Out-Null
  Invoke-Git -Repo $lRepo commit -m 'initial' | Out-Null
  return $lRepo
}

function Add-TestRepoFile {
  param(
    [Parameter(Mandatory = $true)][string]$Repo,
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [string]$Value = 'test'
  )

  $lFile = Join-Path $Repo $RelativePath
  $lParent = Split-Path -Parent $lFile
  if (-not [string]::IsNullOrWhiteSpace($lParent)) {
    [IO.Directory]::CreateDirectory($lParent) | Out-Null
  }
  Set-Content -LiteralPath $lFile -Value $Value -Encoding UTF8
  Invoke-Git -Repo $Repo add $RelativePath | Out-Null
}

function New-TestGateProvenance {
  param(
    [Parameter(Mandatory = $true)][string]$DelphiSemanticsRoot,
    [Parameter(Mandatory = $true)][string]$DakRoot
  )

  return @(
    [pscustomobject]@{
      Name = 'DelphiSemantics'
      Path = $DelphiSemanticsRoot
      Branch = 'main'
      Commit = 'semantics-commit'
      Dirty = $false
      StatusLines = @()
    },
    [pscustomobject]@{
      Name = 'DAK'
      Path = $DakRoot
      Branch = 'master'
      Commit = 'dak-commit'
      Dirty = $false
      StatusLines = @()
    }
  )
}

function Test-DefaultWorkRootsAreRunScoped {
  $lFirst = New-MigrationGateDefaultWorkRoot
  Start-Sleep -Milliseconds 5
  $lSecond = New-MigrationGateDefaultWorkRoot

  Assert-True ($lFirst -ne $lSecond) 'Default WorkRoot must be unique per invocation.'
  Assert-True ($lFirst -like '*delphi-semantics-migration-gate*') 'Default WorkRoot must stay under the migration-gate temp namespace.'
  Assert-True ($lSecond -like '*delphi-semantics-migration-gate*') 'Second default WorkRoot must stay under the migration-gate temp namespace.'
}

function Test-DirtyWorktreeFailsUnlessAllowed {
  Reset-TestWorkspace
  $lRepo = New-TestGitRepo 'dirty-repo'
  Set-Content -LiteralPath (Join-Path $lRepo 'tracked.txt') -Value 'dirty' -Encoding UTF8

  $lFailed = $false
  try {
    Assert-GateWorktreesClean -Repositories @(
      [pscustomobject]@{ Name = 'dirty'; Path = $lRepo }
    ) -AllowDirty:$false
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*dirty*') 'Dirty failure should name the dirty repository.'
  }

  Assert-True $lFailed 'Dirty worktree must fail without -AllowDirty.'
  Assert-GateWorktreesClean -Repositories @(
    [pscustomobject]@{ Name = 'dirty'; Path = $lRepo }
  ) -AllowDirty:$true
}

function Test-ManifestRecordsGitProvenance {
  Reset-TestWorkspace
  $lSemanticsRepo = New-TestGitRepo 'semantics-repo'
  $lDakRepo = New-TestGitRepo 'dak-repo'
  Set-Content -LiteralPath (Join-Path $lDakRepo 'tracked.txt') -Value 'dirty dak' -Encoding UTF8
  $lWorkRoot = Join-Path $TempRoot 'gate-run'
  [IO.Directory]::CreateDirectory($lWorkRoot) | Out-Null
  $lManifest = Join-Path $lWorkRoot 'migration-gate-manifest.json'

  Write-MigrationGateManifest `
    -Path $lManifest `
    -WorkRoot $lWorkRoot `
    -DelphiSemanticsRoot $lSemanticsRepo `
    -DakRoot $lDakRepo `
    -AllowDirty:$true

  Assert-True (Test-Path -LiteralPath $lManifest -PathType Leaf) 'Manifest must be written.'
  $lJson = Get-Content -LiteralPath $lManifest -Raw | ConvertFrom-Json
  Assert-Equal $lWorkRoot $lJson.workRoot 'Manifest must record WorkRoot.'
  Assert-Equal 'True' $lJson.allowDirty 'Manifest must record AllowDirty.'
  Assert-Equal 'False' $lJson.repositories.delphiSemantics.dirty 'Semantics repo should be recorded clean.'
  Assert-Equal 'True' $lJson.repositories.dak.dirty 'DAK repo should be recorded dirty.'
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$lJson.repositories.delphiSemantics.commit)) `
    'Manifest must record Semantics commit.'
  Assert-True (-not [string]::IsNullOrWhiteSpace([string]$lJson.repositories.dak.branch)) `
    'Manifest must record DAK branch.'
}

function Test-ManifestUsesAcceptedProvenanceSnapshot {
  Reset-TestWorkspace
  $lSemanticsRepo = New-TestGitRepo 'snapshot-semantics-repo'
  $lDakRepo = New-TestGitRepo 'snapshot-dak-repo'
  $lProvenance = Get-GateRepositoryProvenanceSet -Repositories @(
    [pscustomobject]@{ Name = 'DelphiSemantics'; Path = $lSemanticsRepo },
    [pscustomobject]@{ Name = 'DAK'; Path = $lDakRepo }
  )

  Set-Content -LiteralPath (Join-Path $lDakRepo 'tracked.txt') -Value 'dirty after snapshot' -Encoding UTF8
  Assert-GateWorktreesClean -Provenance $lProvenance -AllowDirty:$false

  $lWorkRoot = Join-Path $TempRoot 'snapshot-gate-run'
  $lManifest = Join-Path $lWorkRoot 'migration-gate-manifest.json'
  Write-MigrationGateManifest `
    -Path $lManifest `
    -WorkRoot $lWorkRoot `
    -DelphiSemanticsRoot $lSemanticsRepo `
    -DakRoot $lDakRepo `
    -Provenance $lProvenance `
    -AllowDirty:$false

  $lJson = Get-Content -LiteralPath $lManifest -Raw | ConvertFrom-Json
  Assert-Equal 'False' $lJson.repositories.dak.dirty `
    'Manifest must use the provenance snapshot accepted by the dirty gate.'
}

function Test-GateStepRecordsCommandAndLogArtifacts {
  Reset-TestWorkspace
  $lWorkDir = Join-Path $TempRoot 'step-metadata'
  [IO.Directory]::CreateDirectory($lWorkDir) | Out-Null
  $lPowerShell = [Diagnostics.Process]::GetCurrentProcess().Path
  $lManifest = Join-Path $TempRoot 'metadata-manifest.json'
  $lResults = New-Object System.Collections.Generic.List[object]
  $lProvenance = New-TestGateProvenance -DelphiSemanticsRoot $RepoRoot -DakRoot $RepoRoot

  $lResult = Invoke-GateStep `
    -Name 'metadata probe' `
    -WorkingDirectory $lWorkDir `
    -FilePath $lPowerShell `
    -Arguments @('-NoProfile', '-Command', "[Console]::Out.WriteLine('step out'); [Console]::Error.WriteLine('step err')")

  Assert-Equal 'metadata probe' $lResult.Name 'Step result must record name.'
  Assert-Equal ([IO.Path]::GetFullPath($lWorkDir)) $lResult.WorkingDirectory `
    'Step result must record working directory.'
  Assert-Equal $lPowerShell $lResult.FilePath 'Step result must record executable.'
  Assert-True (@($lResult.Arguments).Count -gt 0) 'Step result must record arguments.'
  Assert-True ($lResult.Command -like '*step out*') 'Step result must record command text.'
  Assert-Equal '0' $lResult.ExitCode 'Step result must record exit code.'
  Assert-True ([double]$lResult.ElapsedSeconds -ge 0) 'Step result must record elapsed seconds.'
  Assert-True (Test-Path -LiteralPath $lResult.Stdout -PathType Leaf) `
    'Step result must record stdout artifact path.'
  Assert-True (Test-Path -LiteralPath $lResult.Stderr -PathType Leaf) `
    'Step result must record stderr artifact path.'
  Assert-True ((Get-Content -LiteralPath $lResult.Stdout -Raw) -like '*step out*') `
    'Stdout artifact must contain command output.'
  Assert-True ((Get-Content -LiteralPath $lResult.Stderr -Raw) -like '*step err*') `
    'Stderr artifact must contain command error output.'

  Add-GateStepResult `
    -Results $lResults `
    -Result $lResult `
    -ManifestPath $lManifest `
    -WorkRoot $TempRoot `
    -DelphiSemanticsRoot $RepoRoot `
    -DakRoot $RepoRoot `
    -Provenance $lProvenance `
    -AllowDirty:$false

  $lJson = Get-Content -LiteralPath $lManifest -Raw | ConvertFrom-Json
  $lStep = @($lJson.steps)[0]
  $lStepPropertyNames = @($lStep.PSObject.Properties.Name)
  foreach ($lProperty in @('name', 'workingDirectory', 'filePath', 'arguments', 'command', 'exitCode', 'elapsedSeconds', 'stdout', 'stderr')) {
    Assert-True ($lStepPropertyNames -contains $lProperty) `
      "Serialized manifest step must expose lower-camel property '$lProperty'."
  }
}

function Write-TestDakSemanticConsumerUnit {
  param(
    [Parameter(Mandatory = $true)][string]$DakRoot,
    [Parameter(Mandatory = $true)][string]$FileName,
    [Parameter(Mandatory = $true)][string]$UnitName,
    [Parameter(Mandatory = $true)][string]$FixtureName
  )

  $lUnitPath = Join-Path $DakRoot "tests\units\$FileName"
  @"
unit $UnitName;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  $FixtureName = class
  public
    [Test]
    procedure Smoke;
  end;

implementation

procedure $FixtureName.Smoke;
begin
end;

initialization
  TDUnitX.RegisterTestFixture($FixtureName);

end.
"@ | Set-Content -LiteralPath $lUnitPath -Encoding UTF8
}

function Write-TestDakSemanticConsumerUnits {
  param([Parameter(Mandatory = $true)][string]$DakRoot)

  [IO.Directory]::CreateDirectory((Join-Path $DakRoot 'tests\units')) | Out-Null
  Write-TestDakSemanticConsumerUnit -DakRoot $DakRoot -FileName 'test.symbolmap.pas' `
    -UnitName 'Test.SymbolMap' -FixtureName 'TSymbolMapSmokeTests'
  Write-TestDakSemanticConsumerUnit -DakRoot $DakRoot -FileName 'test.deps.pas' `
    -UnitName 'Test.Deps' -FixtureName 'TDepsSmokeTests'
  Write-TestDakSemanticConsumerUnit -DakRoot $DakRoot -FileName 'test.globalvars.pas' `
    -UnitName 'Test.GlobalVars' -FixtureName 'TGlobalVarsSmokeTests'
}

function Test-DakSemanticConsumerFiltersAreSelected {
  Reset-TestWorkspace
  $lDakRoot = Join-Path $TempRoot 'dak-semantic-consumers'
  Write-TestDakSemanticConsumerUnits -DakRoot $lDakRoot

  $lFilters = @(Get-DakSemanticConsumerTestFilters -DakRoot $lDakRoot)

  Assert-True ($lFilters.Count -ge 3) 'Semantic-consumer filters must be non-empty.'
  Assert-True ($lFilters -contains 'Test.SymbolMap') 'Gate filters must include SymbolMap coverage.'
  Assert-True ($lFilters -contains 'Test.Deps') 'Gate filters must include deps coverage.'
  Assert-True ($lFilters -contains 'Test.GlobalVars') 'Gate filters must include GlobalVars coverage.'
}

function Test-DakSemanticConsumerFiltersFailWhenMissing {
  Reset-TestWorkspace
  $lDakRoot = Join-Path $TempRoot 'dak-semantic-consumers-missing'
  [IO.Directory]::CreateDirectory((Join-Path $lDakRoot 'tests\units')) | Out-Null

  $lFailed = $false
  try {
    Get-DakSemanticConsumerTestFilters -DakRoot $lDakRoot | Out-Null
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*Required file not found*') `
      'Missing semantic-consumer test units should fail closed.'
  }

  Assert-True $lFailed 'Semantic-consumer discovery must fail when required test units are missing.'
}

function Test-DakSemanticConsumerFiltersFailWhenUnitHasNoTests {
  Reset-TestWorkspace
  $lDakRoot = Join-Path $TempRoot 'dak-semantic-consumers-empty'
  [IO.Directory]::CreateDirectory((Join-Path $lDakRoot 'tests\units')) | Out-Null
  foreach ($lUnit in @('test.symbolmap.pas', 'test.deps.pas', 'test.globalvars.pas')) {
    Set-Content -LiteralPath (Join-Path $lDakRoot "tests\units\$lUnit") -Value 'unit fake; end.' -Encoding UTF8
  }

  $lFailed = $false
  try {
    Get-DakSemanticConsumerTestFilters -DakRoot $lDakRoot | Out-Null
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*does not declare unit*') `
      'Empty semantic-consumer units should fail real DUnitX discovery.'
  }

  Assert-True $lFailed 'Semantic-consumer discovery must fail when units contain no DUnitX tests.'
}

function Test-DakSemanticConsumerStepArgumentsRecordManifestFilters {
  Reset-TestWorkspace
  $lDakRoot = Join-Path $TempRoot 'dak-semantic-step'
  Write-TestDakSemanticConsumerUnits -DakRoot $lDakRoot

  $lArguments = @(Get-DakSemanticConsumerTestArguments `
    -DakRoot $lDakRoot `
    -Profile 'Gate')

  Assert-True (($lArguments -join ' ') -like '*Test.SymbolMap*') `
    'Semantic-consumer manifest arguments must include SymbolMap filter.'
  Assert-True (($lArguments -join ' ') -like '*Test.Deps*') `
    'Semantic-consumer manifest arguments must include deps filter.'
  Assert-True (($lArguments -join ' ') -like '*Test.GlobalVars*') `
    'Semantic-consumer manifest arguments must include GlobalVars filter.'
}

function Test-DakSemanticConsumerStepPersistsManifestFilters {
  Reset-TestWorkspace
  $lDakRoot = Join-Path $TempRoot 'dak-semantic-manifest'
  $lWorkRoot = Join-Path $TempRoot 'dak-semantic-manifest-work'
  $lManifest = Join-Path $lWorkRoot 'manifest.json'
  [IO.Directory]::CreateDirectory($lWorkRoot) | Out-Null
  Write-TestDakSemanticConsumerUnits -DakRoot $lDakRoot
  $lProvenance = New-TestGateProvenance -DelphiSemanticsRoot $RepoRoot -DakRoot $lDakRoot
  $lResults = New-Object System.Collections.Generic.List[object]
  foreach ($lFilter in @(Get-DakSemanticConsumerTestFilters -DakRoot $lDakRoot)) {
    $lArguments = @(Get-DakSemanticConsumerTestArguments -DakRoot $lDakRoot -Profile 'Gate' `
      -Filters @($lFilter))
    $lResult = [pscustomobject]@{
      name = "Run DAK semantic-consumer tests $lFilter"
      workingDirectory = $lDakRoot
      filePath = 'tests\DelphiAIKit.Tests.exe'
      arguments = $lArguments
      command = "tests\DelphiAIKit.Tests.exe $($lArguments -join ' ')"
      exitCode = 0
      elapsedSeconds = 0
      stdout = ''
      stderr = ''
    }

    Add-GateStepResult `
      -Results $lResults `
      -Result $lResult `
      -ManifestPath $lManifest `
      -WorkRoot $lWorkRoot `
      -DelphiSemanticsRoot $RepoRoot `
      -DakRoot $lDakRoot `
      -Provenance $lProvenance `
      -AllowDirty:$false
  }

  $lJson = Get-Content -LiteralPath $lManifest -Raw | ConvertFrom-Json
  $lStepArguments = @($lJson.steps | Where-Object { $_.name -like 'Run DAK semantic-consumer tests*' } |
    ForEach-Object { $_.arguments -join ' ' })
  Assert-True (($lStepArguments -join ' ') -like '*Test.SymbolMap*') `
    'Manifest semantic-consumer step must persist SymbolMap filter.'
  Assert-True (($lStepArguments -join ' ') -like '*Test.Deps*') `
    'Manifest semantic-consumer step must persist deps filter.'
  Assert-True (($lStepArguments -join ' ') -like '*Test.GlobalVars*') `
    'Manifest semantic-consumer step must persist GlobalVars filter.'
}

function Test-DakSemanticConsumerStepFailsWhenDUnitXSelectsNoTests {
  Reset-TestWorkspace
  $lStdout = Join-Path $TempRoot 'dak-semantic-zero-tests.stdout.txt'
  Set-Content -LiteralPath $lStdout -Value @(
    'DUnitX - [DelphiAIKit.Tests.exe] - Starting Tests.'
    ''
    'Tests Found   : 0'
    'Tests Ignored : 0'
    'Tests Passed  : 0'
  ) -Encoding UTF8
  $lResult = [pscustomobject]@{
    name = 'Run DAK semantic-consumer tests'
    exitCode = 0
    stdout = $lStdout
  }

  $lFailed = $false
  try {
    Assert-DUnitXStepDiscoveredTests -Result $lResult -StepName 'Run DAK semantic-consumer tests'
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*selected no DUnitX tests*') `
      'Zero-match DUnitX output should fail the semantic-consumer gate.'
  }

  Assert-True $lFailed 'Semantic-consumer gate must fail when DUnitX finds zero tests.'
}

function Test-DakSemanticConsumerDiscoveryFailureCanBeManifested {
  $lResult = [pscustomobject]@{
    name = 'Run DAK semantic-consumer tests Test.Deps'
    exitCode = 0
  }

  $lFailedResult = Set-GateStepFailure -Result $lResult `
    -Message 'Run DAK semantic-consumer tests Test.Deps selected no DUnitX tests.'

  Assert-Equal '1' $lFailedResult.exitCode `
    'Discovery failure should mark the step result failed before manifest persistence.'
  Assert-True ($lFailedResult.failureReason -like '*selected no DUnitX tests*') `
    'Discovery failure reason should be serializable into the manifest step.'
}

function Test-DakSemanticConsumerStepAcceptsDiscoveredTests {
  Reset-TestWorkspace
  $lStdout = Join-Path $TempRoot 'dak-semantic-found-tests.stdout.txt'
  Set-Content -LiteralPath $lStdout -Value @(
    'DUnitX - [DelphiAIKit.Tests.exe] - Starting Tests.'
    ''
    'Tests Found   : 97'
    'Tests Ignored : 0'
    'Tests Passed  : 97'
  ) -Encoding UTF8
  $lResult = [pscustomobject]@{
    name = 'Run DAK semantic-consumer tests'
    exitCode = 0
    stdout = $lStdout
  }

  Assert-DUnitXStepDiscoveredTests -Result $lResult -StepName 'Run DAK semantic-consumer tests'
}

function Test-FailedGateStepPersistsManifestLogs {
  Reset-TestWorkspace
  $lWorkDir = Join-Path $TempRoot 'failed-step'
  [IO.Directory]::CreateDirectory($lWorkDir) | Out-Null
  $lPowerShell = [Diagnostics.Process]::GetCurrentProcess().Path
  $lManifest = Join-Path $TempRoot 'failed-manifest.json'
  $lResults = New-Object System.Collections.Generic.List[object]
  $lProvenance = New-TestGateProvenance -DelphiSemanticsRoot $RepoRoot -DakRoot $RepoRoot

  $lResult = Invoke-GateStep `
    -Name 'failed probe' `
    -WorkingDirectory $lWorkDir `
    -FilePath $lPowerShell `
    -Arguments @('-NoProfile', '-Command', "[Console]::Out.WriteLine('failed out'); [Console]::Error.WriteLine('failed err'); exit 7") `
    -NoThrow

  $lFailed = $false
  try {
    Add-GateStepResult `
      -Results $lResults `
      -Result $lResult `
      -ManifestPath $lManifest `
      -WorkRoot $TempRoot `
      -DelphiSemanticsRoot $RepoRoot `
      -DakRoot $RepoRoot `
      -Provenance $lProvenance `
      -AllowDirty:$false
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*failed probe*') `
      'Failed step exception should name the failed step.'
  }

  Assert-True $lFailed 'Failed recorded step must still fail the gate.'
  Assert-True (Test-Path -LiteralPath $lManifest -PathType Leaf) `
    'Failed step must persist the manifest before raising.'
  $lJson = Get-Content -LiteralPath $lManifest -Raw | ConvertFrom-Json
  $lStep = @($lJson.steps)[0]
  Assert-Equal 'failed probe' $lStep.name 'Manifest must record failed step name.'
  Assert-Equal '7' $lStep.exitCode 'Manifest must record failed step exit code.'
  Assert-True (Test-Path -LiteralPath $lStep.stdout -PathType Leaf) `
    'Manifest must link failed step stdout artifact.'
  Assert-True (Test-Path -LiteralPath $lStep.stderr -PathType Leaf) `
    'Manifest must link failed step stderr artifact.'
  Assert-True ((Get-Content -LiteralPath $lStep.stdout -Raw) -like '*failed out*') `
    'Failed step stdout artifact must contain output.'
  Assert-True ((Get-Content -LiteralPath $lStep.stderr -Raw) -like '*failed err*') `
    'Failed step stderr artifact must contain error output.'
}

function Test-ExplicitWorkRootLockBlocksConcurrentRuns {
  Reset-TestWorkspace
  $lWorkRoot = Join-Path $TempRoot 'explicit-work-root'
  $lFirstLock = New-MigrationGateWorkRootLock -WorkRoot $lWorkRoot
  try {
    $lFailed = $false
    $lSecondLock = $null
    try {
      $lSecondLock = New-MigrationGateWorkRootLock -WorkRoot $lWorkRoot
    } catch {
      $lFailed = $true
      Assert-True ($_.Exception.Message -like '*WorkRoot*') `
        'Concurrent explicit WorkRoot failure should name the guarded root.'
    } finally {
      if ($null -ne $lSecondLock) {
        Close-MigrationGateWorkRootLock -Lock $lSecondLock
      }
    }

    Assert-True $lFailed 'A second gate must not acquire the same explicit WorkRoot lock.'
  } finally {
    Close-MigrationGateWorkRootLock -Lock $lFirstLock
  }

  $lReusedLock = New-MigrationGateWorkRootLock -WorkRoot $lWorkRoot
  Close-MigrationGateWorkRootLock -Lock $lReusedLock
}

function Test-MainScriptFailsBeforeWorkRootMutationWhenExplicitRootLocked {
  Reset-TestWorkspace
  $lSemanticsRepo = New-TestGitRepo 'mainflow-semantics-repo'
  Add-TestRepoFile -Repo $lSemanticsRepo -RelativePath 'tests\delphiSemanticsTests.dproj'
  Invoke-Git -Repo $lSemanticsRepo commit -m 'add semantics markers' | Out-Null

  $lDakRepo = New-TestGitRepo 'mainflow-dak-repo'
  Add-TestRepoFile -Repo $lDakRepo -RelativePath 'tests\DelphiAIKit.Tests.dproj'
  Add-TestRepoFile -Repo $lDakRepo -RelativePath 'projects\DelphiAIKit.dproj'
  Add-TestRepoFile -Repo $lDakRepo -RelativePath 'tests\fixtures\test-projects\maxTdb\.keep'
  Invoke-Git -Repo $lDakRepo commit -m 'add dak markers' | Out-Null

  $lWorkRoot = Join-Path $TempRoot 'mainflow-explicit-work-root'
  $lCloneRoot = Join-Path $lWorkRoot 'maxTdb'
  [IO.Directory]::CreateDirectory($lCloneRoot) | Out-Null
  $lCloneSentinel = Join-Path $lCloneRoot 'sentinel.txt'
  Set-Content -LiteralPath $lCloneSentinel -Value 'keep me' -Encoding UTF8
  $lLock = New-MigrationGateWorkRootLock -WorkRoot $lWorkRoot
  try {
    $lPowerShell = [Diagnostics.Process]::GetCurrentProcess().Path
    $lOldErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
      $lOutput = & $lPowerShell `
        -NoProfile `
        -ExecutionPolicy Bypass `
        -File $GateScript `
        -DelphiSemanticsRoot $lSemanticsRepo `
        -DakRoot $lDakRepo `
        -WorkRoot $lWorkRoot `
        -SkipBuild 2>&1
      $lExitCode = $LASTEXITCODE
    } finally {
      $ErrorActionPreference = $lOldErrorActionPreference
    }
    $lText = @($lOutput) -join "`n"

    Assert-True ($lExitCode -ne 0) 'A contended explicit WorkRoot must fail the main script.'
    Assert-True ($lText -like '*WorkRoot is already locked*') `
      'Main script failure should report the explicit WorkRoot lock.'
    Assert-True (-not (Test-Path -LiteralPath (Join-Path $lWorkRoot 'migration-gate-manifest.json'))) `
      'Main script must fail before writing the manifest for a locked explicit WorkRoot.'
    Assert-True (Test-Path -LiteralPath $lCloneSentinel -PathType Leaf) `
      'Main script must fail before deleting an existing clone under a locked explicit WorkRoot.'
  } finally {
    Close-MigrationGateWorkRootLock -Lock $lLock
  }
}

function Test-PlannedEditParityDetectsShapeMismatch {
  $lPlan = [pscustomobject]@{
    plannedEdits = @(
      [pscustomobject]@{
        statementId = 'stmt-1'
        file = 'Unit1.pas'
        status = 'planned'
        reason = 'safe'
        replacementText = 'A := B;'
        edits = @(
          [pscustomobject]@{
            kind = 'replace'
            file = 'Unit1.pas'
            statementId = 'stmt-1'
            range = [pscustomobject]@{
              startLine = 10
              startCol = 3
              endLine = 10
              endCol = 11
            }
            replacementText = 'A := B;'
          }
        )
      }
    )
  }
  $lApply = [pscustomobject]@{
    plannedEdits = @(
      [pscustomobject]@{
        statementId = 'stmt-1'
        file = 'Unit1.pas'
        status = 'planned'
        reason = 'safe'
        replacementText = 'A := C;'
        edits = @(
          [pscustomobject]@{
            kind = 'replace'
            file = 'Unit1.pas'
            statementId = 'stmt-1'
            range = [pscustomobject]@{
              startLine = 10
              startCol = 3
              endLine = 10
              endCol = 11
            }
            replacementText = 'A := C;'
          }
        )
      }
    )
  }

  $lFailed = $false
  try {
    Assert-MigrationGatePlannedEditParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*planned edit shape*') `
      'Parity failure should report planned edit shape drift.'
    Assert-True ($_.Exception.Message -like '*stmt-1*') `
      'Parity failure should name the mismatched statement id.'
  }

  Assert-True $lFailed 'Planned edit parity must reject same-id replacement drift.'
}

function Test-PlannedEditParityDetectsReasonShapeMismatch {
  $lPlan = [pscustomobject]@{
    plannedEdits = @(
      [pscustomobject]@{
        statementId = 'stmt-2'
        file = 'Unit2.pas'
        status = 'planned'
        reason = 'safe'
        replacementText = 'A := B;'
        edits = @(
          [pscustomobject]@{
            kind = 'replace'
            file = 'Unit2.pas'
            statementId = 'stmt-2'
            range = [pscustomobject]@{
              startLine = 4
              startCol = 5
              endLine = 4
              endCol = 13
            }
            replacementText = 'A := B;'
          }
        )
      }
    )
  }
  $lApply = [pscustomobject]@{
    plannedEdits = @(
      [pscustomobject]@{
        statementId = 'stmt-2'
        file = 'Unit2.pas'
        status = 'planned'
        replacementText = 'A := B;'
        edits = @(
          [pscustomobject]@{
            kind = 'replace'
            file = 'Unit2.pas'
            statementId = 'stmt-2'
            range = [pscustomobject]@{
              startLine = 4
              startCol = 5
              endLine = 4
              endCol = 13
            }
            replacementText = 'A := B;'
          }
        )
      }
    )
  }

  $lFailed = $false
  try {
    Assert-MigrationGatePlannedEditParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*planned edit shape*') `
      'Reason shape failure should report planned edit shape drift.'
    Assert-True ($_.Exception.Message -like '*stmt-2*') `
      'Reason shape failure should name the mismatched statement id.'
    Assert-True ($_.Exception.Message -like '*hasReason*') `
      'Reason shape failure should expose field-presence drift.'
  }

  Assert-True $lFailed 'Planned edit parity must reject missing reason drift.'
}

function New-TestSkippedStatement {
  param(
    [string]$StatementId = 'skip-1',
    [string]$File = 'Unit1.pas',
    [string]$Reason = 'selector-type-not-resolved',
    [string]$Signature = 'Unit1.pas:10:3-10:15',
    [int]$StartLine = 10,
    [int]$StartCol = 3
  )

  return [pscustomobject]@{
    statementId = $StatementId
    file = $File
    reason = $Reason
    signature = $Signature
    range = [pscustomobject]@{
      startLine = $StartLine
      startCol = $StartCol
      endLine = $StartLine
      endCol = 15
    }
  }
}

function Test-SkippedParityDetectsSummaryMismatch {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = @((New-TestSkippedStatement))
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 2 }
    skipped = @((New-TestSkippedStatement))
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*skipped summary*') `
      'Skipped summary mismatch should name skipped summary parity.'
  }

  Assert-True $lFailed 'Skipped parity must reject summary skipped-count drift.'
}

function Test-SkippedParityDetectsArrayMismatch {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 2 }
    skipped = @(
      (New-TestSkippedStatement -StatementId 'skip-1'),
      (New-TestSkippedStatement -StatementId 'skip-2' -StartLine 20)
    )
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 2 }
    skipped = [object[]]@((New-TestSkippedStatement -StatementId 'skip-1'))
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*skipped array*') `
      'Skipped array mismatch should name skipped array parity.'
  }

  Assert-True $lFailed 'Skipped parity must reject skipped array count drift.'
}

function Test-SkippedParityAcceptsMatchingSkippedStatements {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 2 }
    skipped = @(
      (New-TestSkippedStatement -StatementId 'skip-1' -Reason 'selector-type-not-resolved'),
      (New-TestSkippedStatement -StatementId 'skip-2' -Reason 'property-selector' -StartLine 20)
    )
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 2 }
    skipped = @(
      (New-TestSkippedStatement -StatementId 'skip-2' -Reason 'property-selector' -StartLine 20),
      (New-TestSkippedStatement -StatementId 'skip-1' -Reason 'selector-type-not-resolved')
    )
  }

  Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
}

function Test-SkippedParityDetectsReasonBucketDrift {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 2 }
    skipped = @(
      (New-TestSkippedStatement -StatementId 'skip-1' -Reason 'selector-type-not-resolved'),
      (New-TestSkippedStatement -StatementId 'skip-2' -Reason 'property-selector' -StartLine 20)
    )
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 2 }
    skipped = @(
      (New-TestSkippedStatement -StatementId 'skip-1' -Reason 'selector-type-not-resolved'),
      (New-TestSkippedStatement -StatementId 'skip-2' -Reason 'call-selector' -StartLine 20)
    )
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*reason bucket*') `
      'Skipped reason drift should name reason bucket parity.'
    Assert-True ($_.Exception.Message -like '*property-selector*') `
      'Skipped reason drift should include the missing bucket.'
  }

  Assert-True $lFailed 'Skipped parity must reject reason-bucket drift.'
}

function Test-SkippedParityDetectsStatementIdentityMismatch {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@((New-TestSkippedStatement -StatementId 'skip-1'))
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@((New-TestSkippedStatement -StatementId 'skip-2'))
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*skipped shape*') `
      'Skipped identity mismatch should report skipped shape parity.'
    Assert-True ($_.Exception.Message -like '*skip-1*') `
      'Skipped identity mismatch should name the missing statement id.'
  }

  Assert-True $lFailed 'Skipped parity must reject statement identity drift.'
}

function Test-SkippedParityDetectsSignatureMismatch {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@((New-TestSkippedStatement -StatementId 'skip-1' -Signature 'old-signature'))
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@((New-TestSkippedStatement -StatementId 'skip-1' -Signature 'new-signature'))
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*skipped shape*') `
      'Skipped signature mismatch should report skipped shape parity.'
    Assert-True ($_.Exception.Message -like '*skip-1*') `
      'Skipped signature mismatch should name the statement id.'
  }

  Assert-True $lFailed 'Skipped parity must reject statement signature drift.'
}

function Test-SkippedParityRejectsScalarSkippedShape {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = (New-TestSkippedStatement)
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = (New-TestSkippedStatement)
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*skipped array*') `
      'Scalar skipped shape should report skipped array contract failure.'
  }

  Assert-True $lFailed 'Skipped parity must reject scalar skipped report shape.'
}

function Test-SkippedParityRejectsMissingRequiredReasonField {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@(
      [pscustomobject]@{
        statementId = 'skip-1'
        file = 'Unit1.pas'
        signature = 'Unit1.pas:10:3-10:15'
        range = [pscustomobject]@{
          startLine = 10
          startCol = 3
          endLine = 10
          endCol = 15
        }
      }
    )
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@(
      [pscustomobject]@{
        statementId = 'skip-1'
        file = 'Unit1.pas'
        signature = 'Unit1.pas:10:3-10:15'
        range = [pscustomobject]@{
          startLine = 10
          startCol = 3
          endLine = 10
          endCol = 15
        }
      }
    )
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*reason*') `
      'Missing skipped reason should name the required field.'
  }

  Assert-True $lFailed 'Skipped parity must reject missing required skipped fields.'
}

function Test-SkippedParityRejectsMissingRequiredRangeField {
  $lPlan = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@(
      [pscustomobject]@{
        statementId = 'skip-1'
        file = 'Unit1.pas'
        reason = 'selector-type-not-resolved'
        signature = 'Unit1.pas:10:3-10:15'
        range = [pscustomobject]@{
          startLine = 10
          startCol = 3
          endLine = 10
        }
      }
    )
  }
  $lApply = [pscustomobject]@{
    summary = [pscustomobject]@{ skipped = 1 }
    skipped = [object[]]@(
      [pscustomobject]@{
        statementId = 'skip-1'
        file = 'Unit1.pas'
        reason = 'selector-type-not-resolved'
        signature = 'Unit1.pas:10:3-10:15'
        range = [pscustomobject]@{
          startLine = 10
          startCol = 3
          endLine = 10
        }
      }
    )
  }

  $lFailed = $false
  try {
    Assert-MigrationGateSkippedParity -PlanJson $lPlan -ApplyJson $lApply
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*range.endCol*') `
      'Missing skipped range field should name the required range field.'
  }

  Assert-True $lFailed 'Skipped parity must reject missing required skipped range fields.'
}

function Test-PlanSourceMutationCheckRecordsAndFails {
  Reset-TestWorkspace
  $lClone = Join-Path $TempRoot 'plan-mutation-clone'
  $lSourceDir = Join-Path $lClone 'src'
  [IO.Directory]::CreateDirectory($lSourceDir) | Out-Null
  $lUnitPath = Join-Path $lSourceDir 'Unit1.pas'
  Set-Content -LiteralPath $lUnitPath -Value 'unit Unit1; interface implementation end.' -Encoding UTF8
  $lSnapshot = New-MigrationGateSourceSnapshot -Root $lClone
  Set-Content -LiteralPath $lUnitPath -Value 'unit Unit1; interface const Mutated = True; implementation end.' -Encoding UTF8

  $lManifest = Join-Path $TempRoot 'plan-mutation-manifest.json'
  $lResults = New-Object System.Collections.Generic.List[object]
  $lProvenance = New-TestGateProvenance -DelphiSemanticsRoot $RepoRoot -DakRoot $RepoRoot
  $lResult = New-MigrationGatePlanSourceMutationResult -Name 'Check report-only plan source mutation' `
    -Root $lClone `
    -Snapshot $lSnapshot

  $lFailed = $false
  try {
    Add-GateStepResult `
      -Results $lResults `
      -Result $lResult `
      -ManifestPath $lManifest `
      -WorkRoot $TempRoot `
      -DelphiSemanticsRoot $RepoRoot `
      -DakRoot $RepoRoot `
      -Provenance $lProvenance `
      -AllowDirty:$false
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*source mutation*') `
      'Plan mutation failure should name the mutation check step.'
  }

  Assert-True $lFailed 'A report-only source mutation must fail the gate.'
  $lJson = Get-Content -LiteralPath $lManifest -Raw | ConvertFrom-Json
  $lStep = @($lJson.steps)[0]
  Assert-Equal 'mutated' $lStep.sourceMutation.status `
    'Manifest step must record the plan source mutation status.'
  Assert-True (@($lStep.sourceMutation.changedFiles) -contains 'src\Unit1.pas') `
    'Manifest mutation status must list changed Delphi source files.'
}

function Test-FailedPlanStillRecordsSourceMutationBeforeFailing {
  Reset-TestWorkspace
  $lClone = Join-Path $TempRoot 'failed-plan-mutation-clone'
  $lSourceDir = Join-Path $lClone 'src'
  [IO.Directory]::CreateDirectory($lSourceDir) | Out-Null
  $lUnitPath = Join-Path $lSourceDir 'Unit2.pas'
  Set-Content -LiteralPath $lUnitPath -Value 'unit Unit2; interface implementation end.' -Encoding UTF8
  $lSnapshot = New-MigrationGateSourceSnapshot -Root $lClone
  Set-Content -LiteralPath $lUnitPath -Value 'unit Unit2; interface const Mutated = True; implementation end.' -Encoding UTF8

  $lManifest = Join-Path $TempRoot 'failed-plan-mutation-manifest.json'
  $lResults = New-Object System.Collections.Generic.List[object]
  $lProvenance = New-TestGateProvenance -DelphiSemanticsRoot $RepoRoot -DakRoot $RepoRoot
  $lPlanResult = [pscustomobject]@{
    name = 'Run cloned maxTdb report-only plan'
    workingDirectory = $RepoRoot
    filePath = 'fake-plan.exe'
    arguments = @()
    command = 'fake failed plan'
    exitCode = 7
    elapsedSeconds = 0
    stdout = ''
    stderr = ''
  }

  $lFailed = $false
  try {
    Add-MigrationGateReportOnlyPlanResult `
      -Results $lResults `
      -PlanResult $lPlanResult `
      -ManifestPath $lManifest `
      -WorkRoot $TempRoot `
      -DelphiSemanticsRoot $RepoRoot `
      -DakRoot $RepoRoot `
      -Provenance $lProvenance `
      -MutationRoot $lClone `
      -MutationSnapshot $lSnapshot `
      -AllowDirty:$false
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message -like '*source mutation*') `
      'Failed plan with source mutation should report the mutation check first.'
  }

  Assert-True $lFailed 'A failed report-only plan with source mutation must fail the gate.'
  $lJson = Get-Content -LiteralPath $lManifest -Raw | ConvertFrom-Json
  $lSteps = @($lJson.steps)
  Assert-Equal '2' $lSteps.Count 'Manifest must contain the failed plan step and the mutation check step.'
  Assert-Equal 'Run cloned maxTdb report-only plan' $lSteps[0].name `
    'Manifest must record the failed plan step.'
  Assert-Equal 'Check report-only plan source mutation' $lSteps[1].name `
    'Manifest must record the mutation check after the failed plan.'
  Assert-Equal 'mutated' $lSteps[1].sourceMutation.status `
    'Mutation check must record mutated status even when plan failed.'
}

Invoke-ScriptTests
