[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$GuardScript = Join-Path $RepoRoot 'scripts\invoke-encodingfix-guarded.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\encodingfix-guard-tests'

. (Join-Path $ScriptRoot 'test-support.ps1')

function Reset-TestWorkspace {
  if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
  }
  [IO.Directory]::CreateDirectory($TempRoot) | Out-Null
  foreach ($lPath in @('src', 'tests\src', 'projects', 'tests\bin', '.dak', 'lib')) {
    [IO.Directory]::CreateDirectory((Join-Path $TempRoot $lPath)) | Out-Null
  }
}

function Invoke-Guard {
  param([string[]]$Arguments)

  $lOutput = & pwsh -NoProfile -ExecutionPolicy Bypass -File $GuardScript @Arguments 2>&1
  return [pscustomobject]@{
    ExitCode = $LASTEXITCODE
    Text = @($lOutput) -join "`n"
  }
}

function Test-BroadRootFailsClosedWithoutOptIn {
  Reset-TestWorkspace

  $lResult = Invoke-Guard -Arguments @('-RepoRoot', $TempRoot, '-Path', '.', '-DryRun')

  Assert-True ($lResult.ExitCode -ne 0) 'Broad root cleanup should fail without opt-in.'
  Assert-True ($lResult.Text -like '*broad root*') 'Broad root failure should name the unsafe scope.'
}

function Test-NarrowSourceRootDryRunPasses {
  Reset-TestWorkspace

  $lResult = Invoke-Guard -Arguments @('-RepoRoot', $TempRoot, '-Path', 'src', '-DryRun')

  Assert-Equal '0' $lResult.ExitCode 'Narrow source root dry-run should pass.'
  Assert-True ($lResult.Text -like '*EncodingFixTool path=*src*scope=git-changed*') `
    'Dry-run output should show the guarded EncodingFixTool command.'
  Assert-True ($lResult.Text -like '*CRLF audit*') 'Dry-run output should include the CRLF audit step.'
}

function Test-GeneratedAndVendorRootsFailClosed {
  Reset-TestWorkspace

  foreach ($lPath in @('tests\bin', '.dak', 'lib')) {
    $lResult = Invoke-Guard -Arguments @('-RepoRoot', $TempRoot, '-Path', $lPath, '-DryRun')

    Assert-True ($lResult.ExitCode -ne 0) "Generated/vendor path should fail: $lPath"
    Assert-True ($lResult.Text -like '*excluded*') "Failure should name excluded path: $lPath"
  }
}

function Test-BroadRootRequiresExplicitOptIn {
  Reset-TestWorkspace

  $lResult = Invoke-Guard -Arguments @('-RepoRoot', $TempRoot, '-Path', '.', '-DryRun',
    '-AllowBroadRoot')

  Assert-Equal '0' $lResult.ExitCode 'Explicitly opted-in broad root dry-run should pass.'
  Assert-True ($lResult.Text -like '*AllowBroadRoot*') 'Opt-in output should make the risk visible.'
}

Invoke-ScriptTests
