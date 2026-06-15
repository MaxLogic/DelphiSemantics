Set-StrictMode -Version Latest

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

function Get-ScriptTestNames {
  param([string]$ScriptPath = $MyInvocation.ScriptName)

  if ([string]::IsNullOrWhiteSpace($ScriptPath)) {
    $ScriptPath = $PSCommandPath
  }

  $lScriptPath = [IO.Path]::GetFullPath($ScriptPath)
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

function Invoke-ScriptTests {
  param([string]$ScriptPath = $MyInvocation.ScriptName)

  $lTests = @(Get-ScriptTestNames -ScriptPath $ScriptPath)
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
}
