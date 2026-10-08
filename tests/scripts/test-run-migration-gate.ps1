[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$GateScript = Join-Path $RepoRoot 'scripts\run-migration-gate.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\migration-gate-script-tests'
$ProcessTraceScript = Join-Path (Split-Path -Parent $RepoRoot) 'DelphiAiKit\tests\scripts\Dak.ProcessTrace.ps1'

. (Join-Path $ScriptRoot 'test-support.ps1')
. $GateScript -ImportOnly

function Invoke-MigrationGateTestChild {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$CommandLine,
    [Parameter(Mandatory = $true)][hashtable]$Environment,
    [int]$TimeoutSeconds = 30
  )

  Assert-ExistingFile $ProcessTraceScript
  . $ProcessTraceScript
  $lBase = Join-Path $TempRoot $Name
  $lResult = Invoke-TracedProcess -CommandLine $CommandLine -WorkingDirectory $TempRoot `
    -Environment $Environment -LogPath "$lBase.process.json" -TimeoutSeconds $TimeoutSeconds `
    -NoOutputText -StdoutPath "$lBase.stdout.txt" -StderrPath "$lBase.stderr.txt"
  $lResult | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath "$lBase.process.json"
  return $lResult
}

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

function Test-MainScriptValidatesDiagnosticPlanBeforeApply {
  Reset-TestWorkspace
  $lAmbientNames = @('DAK_GATE_TEST_TRACE', 'DAK_GATE_TEST_PLAN', 'DAK_GATE_TEST_APPLY')
  $lAmbientBefore = @{}
  foreach ($lName in $lAmbientNames) {
    $lAmbientBefore[$lName] = [pscustomobject]@{
      present = [Environment]::GetEnvironmentVariables().Contains($lName)
      value = [Environment]::GetEnvironmentVariable($lName, 'Process')
    }
  }
  $lSemanticsRepo = New-TestGitRepo 'boundary-semantics-repo'
  Add-TestRepoFile -Repo $lSemanticsRepo -RelativePath 'tests\delphiSemanticsTests.dproj'
  Add-TestRepoFile -Repo $lSemanticsRepo -RelativePath 'tests\bin\delphiSemanticsTests.exe'
  Invoke-Git -Repo $lSemanticsRepo commit -m 'add semantics markers' | Out-Null

  $lDakRepo = New-TestGitRepo 'boundary-dak-repo'
  foreach ($lMarker in @(
      'tests\DelphiAIKit.Tests.dproj', 'projects\DelphiAIKit.dproj',
      'tests\DelphiAIKit.Tests.exe', 'bin\DelphiAIKit.exe',
      'tests\fixtures\test-projects\maxTdb\src\maxtdb.dproj')) {
    Add-TestRepoFile -Repo $lDakRepo -RelativePath $lMarker
  }
  foreach ($lUnit in @('symbolmap', 'deps', 'globalvars')) {
    $lName = switch ($lUnit) {
      'symbolmap' { 'SymbolMap' }
      'deps' { 'Deps' }
      'globalvars' { 'GlobalVars' }
    }
    Add-TestRepoFile -Repo $lDakRepo -RelativePath "tests\units\test.$lUnit.pas" `
      -Value "unit Test.$lName;`n[TestFixture]`n[Test] procedure Check;`nTDUnitX.RegisterTestFixture(TCheck);"
  }
  Add-TestRepoFile -Repo $lDakRepo -RelativePath 'tests\units\test.removewith.pas' `
    -Value 'TRemoveWithBoundaryTests = class'

  $lTraceHelper = @'
function Invoke-TracedProcess {
  param($CommandLine, $WorkingDirectory, $Environment, $LogPath, $TimeoutSeconds,
    [switch]$NoOutputText, $StdoutPath, $StderrPath)
  Add-Content -LiteralPath $env:DAK_GATE_TEST_TRACE -Value $CommandLine
  Set-Content -LiteralPath $StdoutPath -Value 'Tests Found: 1'
  Set-Content -LiteralPath $StderrPath -Value ''
  if ($CommandLine -match 'remove-with') {
    $lOutput = [regex]::Match($CommandLine, '--output\s+(?:"([^"]+)"|(\S+))')
    if (-not $lOutput.Success) { throw 'Mock process received no report output path.' }
    $lPath = if ($lOutput.Groups[1].Success) { $lOutput.Groups[1].Value } else { $lOutput.Groups[2].Value }
    $lFixture = if ($CommandLine -match '--mode\s+plan') {
      $env:DAK_GATE_TEST_PLAN
    } else {
      $env:DAK_GATE_TEST_APPLY
    }
    Copy-Item -LiteralPath $lFixture -Destination $lPath
  }
  return [pscustomobject]@{ exit_code = 0; timed_out = $false; cleanup_complete = $true; processes = @() }
}
'@
  Add-TestRepoFile -Repo $lDakRepo -RelativePath 'tests\scripts\Dak.ProcessTrace.ps1' -Value $lTraceHelper
  Invoke-Git -Repo $lDakRepo commit -m 'add dak markers' | Out-Null

  $lPlan = Get-TestAccountingReport
  $lPlanFile = Join-Path $TempRoot 'boundary-plan.json'
  $lApply = Get-TestAccountingReport
  $lApply.PSObject.Properties.Remove('semanticDtoParity')
  $lApply.status = 'applied'
  $lApply.summary | Add-Member -NotePropertyName appliedEdits -NotePropertyValue 2
  $lApply | Add-Member -NotePropertyName verification -NotePropertyValue ([pscustomobject]@{ status = 'passed' })
  $lApplyFile = Join-Path $TempRoot 'boundary-apply.json'
  $lApply | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $lApplyFile

  foreach ($lCase in @('bad-accounting', 'bad-dto', 'valid')) {
      $lCandidate = $lPlan | ConvertTo-Json -Depth 20 | ConvertFrom-Json
      switch ($lCase) {
        'bad-accounting' { $lCandidate.summary.covered = '1' }
        'bad-dto' { $lCandidate.semanticDtoParity.mismatchCount = 1 }
      }
      $lCandidate | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $lPlanFile
      $lTrace = Join-Path $TempRoot "boundary-$lCase.trace.txt"
      $lWorkRoot = Join-Path $TempRoot "boundary-$lCase-work"
      $lHostPath = [Diagnostics.Process]::GetCurrentProcess().Path
      $lCommandLine = ((@($lHostPath, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
          $GateScript, '-DelphiSemanticsRoot', $lSemanticsRepo, '-DakRoot', $lDakRepo,
          '-WorkRoot', $lWorkRoot, '-SkipBuild') |
        ForEach-Object { ConvertTo-WindowsCommandArgument $_ }) -join ' ')
      $lChild = Invoke-MigrationGateTestChild -Name "boundary-$lCase" -CommandLine $lCommandLine `
        -Environment @{
          DAK_GATE_TEST_TRACE = $lTrace
          DAK_GATE_TEST_PLAN = $lPlanFile
          DAK_GATE_TEST_APPLY = $lApplyFile
        }
      $lOutput = [IO.File]::ReadAllText($lChild.stdout_path) + [IO.File]::ReadAllText($lChild.stderr_path)
      Assert-True (-not $lChild.timed_out) "Mock gate timed out: $lCase; $($lChild.stdout_path); $($lChild.stderr_path)"
      Assert-True ($lChild.cleanup_complete -and $lChild.complete) `
        "Mock gate process cleanup incomplete: $lCase; $($lChild.stdout_path); $($lChild.stderr_path)"
      $lExitCode = $lChild.exit_code
      $lCommands = @(Get-Content -LiteralPath $lTrace)
      $lPlanCommands = @($lCommands | Where-Object { $_ -match '--mode\s+plan' })
      $lApplyCommands = @($lCommands | Where-Object { $_ -match '--mode\s+apply' })
      Assert-Equal 1 $lPlanCommands.Count "Main gate must launch one plan: $lCase"
      Assert-True ($lPlanCommands[0] -match '--diagnostics\s+true') `
        "Main gate must request diagnostic parity: $lCase"
      if ($lCase -eq 'valid') {
        Assert-Equal 1 $lApplyCommands.Count 'Valid plan must reach apply.'
        Assert-Equal 0 $lExitCode 'Valid plan and apply reports must complete the main gate.'
        Assert-True ($lApplyCommands[0] -notmatch '--diagnostics') `
          'Apply command must not request diagnostic DTO parity.'
      } else {
        Assert-True ($lExitCode -ne 0) "Invalid plan must fail: $lCase"
        Assert-Equal 0 $lApplyCommands.Count "Invalid plan must fail before apply: $lCase"
        $lReason = if ($lCase -eq 'bad-accounting') { 'Expected report property summary.covered to be a nonnegative integer.' } else { 'Expected semanticDtoParity.mismatchCount=0' }
        Assert-True ($lOutput -like "*$lReason*") "Invalid plan failed for another reason: $lCase $lOutput"
      }
  }
  foreach ($lName in $lAmbientNames) {
    $lCurrentPresent = [Environment]::GetEnvironmentVariables().Contains($lName)
    $lCurrentValue = [Environment]::GetEnvironmentVariable($lName, 'Process')
    Assert-True (($lCurrentPresent -eq $lAmbientBefore[$lName].present) -and
      ($lCurrentValue -ceq $lAmbientBefore[$lName].value)) `
      "Main gate test changed ambient environment variable $lName."
  }
}

function Test-ZBoundaryChildTimeoutCleansGrandchild {
  Reset-TestWorkspace
  $lChild = Join-Path $TempRoot 'boundary-hanging-child.ps1'
  $lGrandchild = Join-Path $TempRoot 'boundary-hanging-grandchild.ps1'
  $lIdentityFile = Join-Path $TempRoot 'boundary-owned-processes.txt'
  $lChildSource = @'
param([string]$Grandchild, [string]$IdentityFile)
[IO.File]::AppendAllText($IdentityFile, "$PID|$((Get-Process -Id $PID).StartTime.Ticks)`n")
$lInfo = New-Object Diagnostics.ProcessStartInfo
$lInfo.FileName = (Get-Process -Id $PID).Path
$lInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Grandchild + '" -IdentityFile "' + $IdentityFile + '"'
$lInfo.UseShellExecute = $false
$lInfo.CreateNoWindow = $true
$lInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$lProcess = [Diagnostics.Process]::Start($lInfo)
$lWait = [Diagnostics.Stopwatch]::StartNew()
while (([IO.File]::ReadAllLines($IdentityFile).Length -lt 2) -and $lWait.Elapsed.TotalSeconds -lt 3) { Start-Sleep -Milliseconds 20 }
[Console]::Out.WriteLine('grandchild-started')
[Console]::Out.Flush()
Start-Sleep -Seconds 60
'@
  $lGrandchildSource = @'
param([string]$IdentityFile)
[IO.File]::AppendAllText($IdentityFile, "$PID|$((Get-Process -Id $PID).StartTime.Ticks)`n")
Start-Sleep -Seconds 60
'@
  [IO.File]::WriteAllText($lChild, $lChildSource, (New-Object Text.UTF8Encoding $false))
  [IO.File]::WriteAllText($lGrandchild, $lGrandchildSource, (New-Object Text.UTF8Encoding $false))
  $lHostPath = [Diagnostics.Process]::GetCurrentProcess().Path
  $lCommandLine = ((@($lHostPath, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File',
      $lChild, '-Grandchild', $lGrandchild, '-IdentityFile', $lIdentityFile) |
    ForEach-Object { ConvertTo-WindowsCommandArgument $_ }) -join ' ')
  $lTimer = [Diagnostics.Stopwatch]::StartNew()
  $lResult = Invoke-MigrationGateTestChild -Name 'boundary-timeout' -CommandLine $lCommandLine `
    -Environment @{} -TimeoutSeconds 5
  $lTimer.Stop()
  Assert-True ($lResult.timed_out -and ($lResult.exit_code -ne 0)) 'Hanging child must return a nonzero timeout.'
  Assert-True ($lResult.cleanup_complete -and ($lResult.active_processes -eq 0)) `
    'Timeout must finish whole job cleanup.'
  Assert-True ($lTimer.Elapsed.TotalSeconds -lt 20) 'Timeout cleanup exceeded its bounded budget.'
  Assert-True ([IO.File]::ReadAllText($lResult.stdout_path).Contains('grandchild-started')) `
    'Timeout probe did not reach the grandchild.'
  $lIdentities = @([IO.File]::ReadAllLines($lIdentityFile))
  Assert-Equal 2 $lIdentities.Count 'Timeout probe must record parent and grandchild identities.'
  foreach ($lIdentity in $lIdentities) {
    $lFields = $lIdentity.Split('|')
    Assert-True (@($lResult.processes | Where-Object { $_.pid -eq [int]$lFields[0] }).Count -eq 1) `
      "Owned PID missing from job trace: $($lFields[0])"
    $lLive = Get-Process -Id ([int]$lFields[0]) -ErrorAction SilentlyContinue
    Assert-True (-not ($lLive -and $lLive.StartTime.Ticks -eq [long]$lFields[1])) `
      "Timeout left an owned process alive: $($lFields[0])"
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

function Get-TestAccountingReport {
  return ('{"status":"ok","summary":{"withStatements":4,"plannedEdits":2,"skipped":1,"covered":1},"plannedEdits":[{"statementId":"with-1","file":"Unit.pas","status":"planned","edits":[{"kind":"replace-statement","statementId":"with-1","file":"Unit.pas","replacementText":"A"}]},{"statementId":"with-2","file":"Unit.pas","status":"planned","edits":[{"kind":"replace-statement","statementId":"with-2","file":"Unit.pas","replacementText":"B"}]}],"skipped":[{"statementId":"with-3","file":"Unit.pas","reason":"unresolved"}],"covered":[{"statementId":"with-4","file":"Unit.pas","status":"planned","reason":"covered-by-parent-rewrite","coveredByStatementId":"with-2"}],"semanticDtoParity":{"status":"passed","mismatchCount":0}}' | ConvertFrom-Json)
}

function Test-CurrentAccountingAcceptsCoveredWithoutHistoricCount {
  $lPlan = Get-TestAccountingReport
  Assert-MigrationGateReportAccounting -ReportJson $lPlan
  Assert-MigrationGatePlanDtoParity -PlanJson $lPlan
  $lApply = Get-TestAccountingReport
  $lApply.PSObject.Properties.Remove('semanticDtoParity')
  Assert-MigrationGateReportAccounting -ReportJson $lApply
  Assert-MigrationGateAccountingParity -PlanJson $lPlan -ApplyJson $lApply
}

function Test-CurrentAccountingRejectsInvalidCountsAndIdentity {
  foreach ($lCase in @('missing-count', 'string-count', 'negative-count', 'array-count', 'duplicate-id', 'blank-id', 'missing-reason', 'missing-array')) {
    $lReport = Get-TestAccountingReport
    switch ($lCase) {
      'missing-count' { $lReport.summary.PSObject.Properties.Remove('covered') }
      'string-count' { $lReport.summary.covered = '1' }
      'negative-count' { $lReport.summary.covered = -1 }
      'array-count' { $lReport.summary.covered = 2 }
      'duplicate-id' { $lReport.covered[0].statementId = 'with-2' }
      'blank-id' { $lReport.covered[0].statementId = ' ' }
      'missing-reason' { $lReport.skipped[0].reason = '' }
      'missing-array' { $lReport.PSObject.Properties.Remove('covered') }
    }
    $lFailed = $false
    try { Assert-MigrationGateReportAccounting -ReportJson $lReport } catch {
      Assert-True (($_.Exception.Message -like 'Expected *') -or
        ($_.Exception.Message -like 'Duplicate statement identity*')) "Unexpected accounting failure for ${lCase}: $($_.Exception.Message)"
      $lFailed = $true
    }
    Assert-True $lFailed "Invalid report accounting must fail: $lCase"
  }
}

function Test-CurrentAccountingRejectsInvalidCoveredParent {
  foreach ($lCase in @('missing', 'self', 'skipped', 'other-file', 'wrong-reason', 'wrong-status')) {
    $lReport = Get-TestAccountingReport
    switch ($lCase) {
      'missing' { $lReport.covered[0].coveredByStatementId = 'absent' }
      'self' { $lReport.covered[0].coveredByStatementId = 'with-4' }
      'skipped' { $lReport.covered[0].coveredByStatementId = 'with-3' }
      'other-file' { $lReport.covered[0].file = 'Other.pas' }
      'wrong-reason' { $lReport.covered[0].reason = 'safe' }
      'wrong-status' { $lReport.covered[0].status = 'skipped' }
    }
    $lFailed = $false
    try { Assert-MigrationGateReportAccounting -ReportJson $lReport } catch {
      Assert-True ($_.Exception.Message -like 'Invalid covered parent rewrite*') `
        "Unexpected covered-parent failure for ${lCase}: $($_.Exception.Message)"
      $lFailed = $true
    }
    Assert-True $lFailed "Invalid covered parent must fail: $lCase"
  }
}

function Test-PlanDtoParityRequiresTypedPassedZero {
  foreach ($lCase in @('missing', 'failed', 'missing-count', 'string-count', 'nonzero')) {
    $lReport = Get-TestAccountingReport
    switch ($lCase) {
      'missing' { $lReport.PSObject.Properties.Remove('semanticDtoParity') }
      'failed' { $lReport.semanticDtoParity.status = 'failed' }
      'missing-count' { $lReport.semanticDtoParity.PSObject.Properties.Remove('mismatchCount') }
      'string-count' { $lReport.semanticDtoParity.mismatchCount = '0' }
      'nonzero' { $lReport.semanticDtoParity.mismatchCount = 1 }
    }
    $lFailed = $false
    try { Assert-MigrationGatePlanDtoParity -PlanJson $lReport } catch {
      Assert-True (($_.Exception.Message -like 'Expected semanticDtoParity*') -or
        ($_.Exception.Message -like 'Expected report property semanticDtoParity*')) `
        "Unexpected DTO parity failure for ${lCase}: $($_.Exception.Message)"
      $lFailed = $true
    }
    Assert-True $lFailed "Invalid semantic DTO parity must fail: $lCase"
  }
}

function Test-CurrentAccountingRejectsApplyDrift {
  foreach ($lCase in @('count', 'covered-parent', 'covered-reason')) {
    $lPlan = Get-TestAccountingReport
    $lApply = Get-TestAccountingReport
    switch ($lCase) {
      'count' { $lApply.summary.withStatements = 5 }
      'covered-parent' { $lApply.covered[0].coveredByStatementId = 'with-1' }
      'covered-reason' { $lApply.covered[0].reason = 'different' }
    }
    $lFailed = $false
    try { Assert-MigrationGateAccountingParity -PlanJson $lPlan -ApplyJson $lApply } catch {
      Assert-True ($_.Exception.Message -like 'Expected plan/apply*') `
        "Unexpected plan/apply failure for ${lCase}: $($_.Exception.Message)"
      $lFailed = $true
    }
    Assert-True $lFailed "Apply accounting drift must fail: $lCase"
  }
}

Invoke-ScriptTests
