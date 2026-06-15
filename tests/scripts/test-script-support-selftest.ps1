[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $ScriptRoot 'test-support.ps1')

function Test-AssertEqualAcceptsMatchingValues {
  Assert-Equal 42 42 'matching values should pass'
}

function Test-AssertEqualRejectsDifferentValues {
  $lFailed = $false
  try {
    Assert-Equal 42 43 'different values should fail'
  } catch {
    $lFailed = $true
    Assert-True ($_.Exception.Message.Contains('Expected=[42] Actual=[43]')) `
      'Assert-Equal failure should include expected and actual values.'
  }

  Assert-True $lFailed 'Assert-Equal should fail on different values.'
}

function Test-AssertTrueRejectsFalse {
  $lFailed = $false
  try {
    Assert-True $false 'false should fail'
  } catch {
    $lFailed = $true
    Assert-Equal 'false should fail' $_.Exception.Message `
      'Assert-True should use the provided failure message.'
  }

  Assert-True $lFailed 'Assert-True should fail on false conditions.'
}

function Test-DiscoveryUsesCurrentScriptOnly {
  $lTests = @(Get-ScriptTestNames)

  Assert-True ($lTests -contains 'Test-AssertEqualAcceptsMatchingValues') `
    'Discovery should include tests from this file.'
  Assert-True ($lTests -notcontains 'Test-SupportHelperDoesNotRun') `
    'Discovery should not include support helper functions from another file.'
}

Invoke-ScriptTests
