[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent (Split-Path -Parent $ScriptRoot)
$GuardScript = Join-Path $RepoRoot 'scripts\assert-remove-with-genericity.ps1'
$TempRoot = Join-Path $RepoRoot 'tests\bin\remove-with-genericity-script-tests'

. (Join-Path $ScriptRoot 'test-support.ps1')
. $GuardScript -ImportOnly

function Reset-TestWorkspace {
  $lExpectedRoot = [IO.Path]::GetFullPath((Join-Path $RepoRoot 'tests\bin\remove-with-genericity-script-tests'))
  $lActualRoot = [IO.Path]::GetFullPath($TempRoot)
  if ($lActualRoot -ne $lExpectedRoot) {
    throw "Refusing to reset unexpected test workspace: $lActualRoot"
  }

  if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
  }
  [IO.Directory]::CreateDirectory($TempRoot) | Out-Null
}

function New-TestPascalFile {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$Body
  )

  $lPath = Join-Path $TempRoot $Name
  Set-Content -LiteralPath $lPath -Value $Body -Encoding UTF8
  return $lPath
}

function Assert-GuardFails {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedText
  )

  $lFailed = $false
  try {
    Assert-RemoveWithProductionGenericity -SourceFiles @($Path)
  } catch {
    $lFailed = $true
    if ($_.Exception.Message -notmatch [regex]::Escape($ExpectedText)) {
      throw "Guard failed for the wrong reason. Expected=[$ExpectedText] Actual=[$($_.Exception.Message)]"
    }
  }

  if (-not $lFailed) {
    throw "Guard should have failed for $Path."
  }
}

function Test-GuardAllowsSourceRangeAssignments {
  Reset-TestWorkspace
  $lPath = New-TestPascalFile -Name 'AllowedRange.pas' -Body @'
unit AllowedRange;

interface

implementation

procedure CaptureRange;
var
  lRange: record
    StartLine: Integer;
    EndLine: Integer;
  end;
begin
  lRange.StartLine := 10;
  lRange.EndLine := 12;
end;

end.
'@

  Assert-RemoveWithProductionGenericity -SourceFiles @($lPath)
}

function Test-GuardRejectsExactLinePredicate {
  Reset-TestWorkspace
  $lPath = New-TestPascalFile -Name 'ExactLine.pas' -Body @'
unit ExactLine;

interface

implementation

procedure BranchOnLine;
var
  lRange: record
    StartLine: Integer;
  end;
begin
  if lRange.StartLine = 597 then
    Exit;
end;

end.
'@

  Assert-GuardFails -Path $lPath -ExpectedText 'exact source-line predicate'
}

function Test-GuardRejectsFilenameExtraction {
  Reset-TestWorkspace
  $lPath = New-TestPascalFile -Name 'FilenameExtraction.pas' -Body @'
unit FilenameExtraction;

interface

implementation

uses
  System.SysUtils;

procedure BranchOnFile(const aName: string);
begin
  if SameText(ExtractFileName(aName), 'fixture.pas') then
    Exit;
end;

end.
'@

  Assert-GuardFails -Path $lPath -ExpectedText 'filename extraction'
}

function Test-GuardRejectsFixtureToken {
  Reset-TestWorkspace
  $lPath = New-TestPascalFile -Name 'FixtureToken.pas' -Body @'
unit FixtureToken;

interface

implementation

procedure BranchOnFixture(const aName: string);
begin
  if aName = 'TDB00.pas' then
    Exit;
end;

end.
'@

  Assert-GuardFails -Path $lPath -ExpectedText 'fixture-specific token'
}

Invoke-ScriptTests
