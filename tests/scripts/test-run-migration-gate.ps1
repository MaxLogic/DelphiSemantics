[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$GateScript = Join-Path $RepoRoot 'scripts\run-migration-gate.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\migration-gate-script-tests'

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

function Assert-Equal {
  param(
    [object]$Expected,
    [object]$Actual,
    [string]$Message
  )

  if ([string]$Expected -ne [string]$Actual) {
    throw "$Message Expected=[$Expected] Actual=[$Actual]"
  }
}

function Assert-True {
  param(
    [bool]$Condition,
    [string]$Message
  )

  if (-not $Condition) {
    throw $Message
  }
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

function Get-ScriptTestNames {
  $lScriptPath = [IO.Path]::GetFullPath($PSCommandPath)
  $lTests = @(Get-Command -CommandType Function -Name 'Test-*' |
    Where-Object {
      (-not [string]::IsNullOrWhiteSpace($_.ScriptBlock.File)) -and
      ([IO.Path]::GetFullPath($_.ScriptBlock.File) -eq $lScriptPath)
    } |
    Sort-Object Name |
    Select-Object -ExpandProperty Name)

  if ($lTests.Count -eq 0) {
    throw "No Test-* functions discovered in $lScriptPath."
  }
  return $lTests
}

$lTests = @(Get-ScriptTestNames)
Write-Host "Discovered $($lTests.Count) test(s)."

$lFailures = New-Object System.Collections.Generic.List[string]
foreach ($lTest in $lTests) {
  try {
    & $lTest
    Write-Host "PASS $lTest"
  } catch {
    $lFailures.Add("FAIL ${lTest}: $($_.Exception.Message)")
    Write-Host "FAIL ${lTest}: $($_.Exception.Message)"
  }
}

if ($lFailures.Count -gt 0) {
  exit 1
}
