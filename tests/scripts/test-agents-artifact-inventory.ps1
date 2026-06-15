[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$InventoryScript = Join-Path $RepoRoot 'scripts\inventory-agents-artifacts.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\agents-artifact-inventory-tests'

. (Join-Path $ScriptRoot 'test-support.ps1')

function Reset-TestWorkspace {
  if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
  }
  [IO.Directory]::CreateDirectory($TempRoot) | Out-Null
}

function New-TestAgentsRoot {
  $lAgentsRoot = Join-Path $TempRoot '.agents'
  [IO.Directory]::CreateDirectory((Join-Path $lAgentsRoot 'plans')) | Out-Null
  [IO.Directory]::CreateDirectory((Join-Path $lAgentsRoot 'resolved-plans')) | Out-Null

  Set-Content -LiteralPath (Join-Path $lAgentsRoot 'handoff.md') -Value '# handoff' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lAgentsRoot 'resolve-task-run.md') -Value '# run' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lAgentsRoot 'plans\active.md') -Value '# plan' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lAgentsRoot 'resolved-plans\done.md') -Value '# done' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lAgentsRoot 'InspectMaxTdb.exe') -Value 'binary' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lAgentsRoot 'InspectMaxTdb.dpr') -Value 'program x;' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lAgentsRoot 't141-production.patch') -Value 'diff --git' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $lAgentsRoot 'scratch.log') -Value 'log' -Encoding UTF8
  return $lAgentsRoot
}

function Test-InventoryClassifiesArtifactsWithoutDeletingFiles {
  Reset-TestWorkspace
  $lAgentsRoot = New-TestAgentsRoot

  $lInventory = & pwsh -NoProfile -ExecutionPolicy Bypass -File $InventoryScript `
    -AgentsRoot $lAgentsRoot -Format Json | ConvertFrom-Json

  Assert-Equal '8' @($lInventory.items).Count 'Inventory should include all files.'
  Assert-Equal '1' $lInventory.schemaVersion 'Inventory JSON should expose schemaVersion.'
  Assert-True (@($lInventory.summary | Where-Object { $_.category -eq 'generated-binary' }).Count -eq 1) `
    'Inventory JSON should expose category summary rows.'
  Assert-True (@($lInventory.nextActions).Count -gt 0) 'Inventory JSON should expose next actions.'
  Assert-True (@($lInventory.items | Where-Object { $_.relativePath -eq 'handoff.md' -and $_.category -eq 'handoff-note' }).Count -eq 1) `
    'Handoff notes should have a dedicated category.'
  Assert-True (@($lInventory.items | Where-Object { $_.relativePath -eq 'resolve-task-run.md' -and $_.category -eq 'run-log' }).Count -eq 1) `
    'Run logs should have a dedicated category.'
  Assert-True (@($lInventory.items | Where-Object { $_.relativePath -eq 'plans\active.md' -and $_.category -eq 'active-plan' }).Count -eq 1) `
    'Plan markdown should be active plans.'
  Assert-True (@($lInventory.items | Where-Object { $_.relativePath -eq 'resolved-plans\done.md' -and $_.category -eq 'resolved-plan' }).Count -eq 1) `
    'Resolved plan markdown should be resolved plans.'
  Assert-True (@($lInventory.items | Where-Object { $_.relativePath -eq 'InspectMaxTdb.exe' -and $_.category -eq 'generated-binary' }).Count -eq 1) `
    'Executable scratch artifacts should be classified separately.'
  Assert-True (@($lInventory.items | Where-Object { $_.relativePath -eq 'InspectMaxTdb.dpr' -and $_.category -eq 'scratch-delphi-source' }).Count -eq 1) `
    'Scratch Delphi sources should be classified separately.'
  Assert-True (@($lInventory.items | Where-Object { $_.relativePath -eq 't141-production.patch' -and $_.category -eq 'saved-patch' }).Count -eq 1) `
    'Patch artifacts should be classified separately.'

  Assert-True (Test-Path -LiteralPath (Join-Path $lAgentsRoot 'InspectMaxTdb.exe')) `
    'Inventory must not delete generated executables.'
}

function Test-TextInventoryPrintsNextActions {
  Reset-TestWorkspace
  $lAgentsRoot = New-TestAgentsRoot

  $lText = & pwsh -NoProfile -ExecutionPolicy Bypass -File $InventoryScript `
    -AgentsRoot $lAgentsRoot
  $lJoined = @($lText) -join "`n"

  Assert-True ($lJoined -like '*Next actions*') 'Text output should print explicit next actions.'
  Assert-True ($lJoined -like '*Review generated-binary*') `
    'Next actions should mention review-only generated artifact pruning.'
}

function Test-CleanupModeFailsClosed {
  Reset-TestWorkspace
  $lAgentsRoot = New-TestAgentsRoot

  $lOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $InventoryScript `
    -AgentsRoot $lAgentsRoot -Cleanup 2>&1
  $lExit = $LASTEXITCODE

  Assert-True ($lExit -ne 0) 'Cleanup mode should fail closed.'
  Assert-True ((@($lOutput) -join "`n") -like '*read-only*') `
    'Cleanup failure should explain that the helper is read-only.'
  Assert-True (Test-Path -LiteralPath (Join-Path $lAgentsRoot 't141-production.patch')) `
    'Cleanup mode must not delete patch artifacts.'
}

Invoke-ScriptTests
