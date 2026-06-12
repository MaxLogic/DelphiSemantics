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

$lTests = @(
  'Test-DefaultWorkRootsAreRunScoped',
  'Test-DirtyWorktreeFailsUnlessAllowed',
  'Test-ManifestRecordsGitProvenance',
  'Test-ManifestUsesAcceptedProvenanceSnapshot'
)

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
