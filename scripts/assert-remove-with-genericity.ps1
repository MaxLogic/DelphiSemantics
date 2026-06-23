[CmdletBinding()]
param(
  [string[]]$SourceFiles = @(),
  [switch]$ImportOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-RemoveWithGenericityDefaultFiles {
  $lScriptRoot = $PSScriptRoot
  if ([string]::IsNullOrWhiteSpace($lScriptRoot)) {
    $lScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
  }
  $lRepoRoot = Split-Path -Parent $lScriptRoot
  return @(
    (Join-Path $lRepoRoot 'src\DelphiSemantics.RemoveWithPlan.pas'),
    (Join-Path $lRepoRoot 'src\DelphiSemantics.RemoveWithPlan.FinalBodyRenderer.pas')
  )
}

function Invoke-RemoveWithAstGrepJson {
  param(
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string[]]$Paths
  )

  $lStderrPath = [IO.Path]::GetTempFileName()
  try {
    $lStdout = & sgp run -p $Pattern -l pascal @Paths --json=compact 2> $lStderrPath
    if ($LASTEXITCODE -ne 0) {
      $lStderr = Get-Content -LiteralPath $lStderrPath -Raw
      throw "sgp pattern [$Pattern] failed: $lStderr"
    }

    $lJsonText = (@($lStdout) -join "`n").Trim()
    if ([string]::IsNullOrWhiteSpace($lJsonText)) {
      return @()
    }

    return @($lJsonText | ConvertFrom-Json)
  } finally {
    if (Test-Path -LiteralPath $lStderrPath) {
      Remove-Item -LiteralPath $lStderrPath -Force
    }
  }
}

function Add-RemoveWithGenericityTextViolations {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyCollection()][System.Collections.Generic.List[string]]$Violations,
    [Parameter(Mandatory = $true)][string[]]$Paths,
    [Parameter(Mandatory = $true)][string]$Pattern,
    [Parameter(Mandatory = $true)][string]$Description
  )

  $lMatches = @(Select-String -LiteralPath $Paths -Pattern $Pattern)
  foreach ($lMatch in $lMatches) {
    $Violations.Add(('{0}: {1} at {2}:{3}: {4}' -f $Description, $lMatch.Line.Trim(),
      $lMatch.Path, $lMatch.LineNumber, $lMatch.Line.Trim()))
  }
}

function Assert-RemoveWithProductionGenericity {
  param([string[]]$SourceFiles = @())

  $lFiles = @($SourceFiles)
  if ($lFiles.Count -eq 0) {
    $lFiles = @(Get-RemoveWithGenericityDefaultFiles)
  }

  foreach ($lFile in $lFiles) {
    if (-not (Test-Path -LiteralPath $lFile -PathType Leaf)) {
      throw "Missing remove-with production source file: $lFile"
    }
  }

  $lViolations = New-Object System.Collections.Generic.List[string]

  $lFilenameMatches = @(Invoke-RemoveWithAstGrepJson -Pattern 'ExtractFileName(_A)' -Paths $lFiles)
  foreach ($lMatch in $lFilenameMatches) {
    if ($null -ne $lMatch) {
      $lText = ''
      if ($lMatch.PSObject.Properties.Name -contains 'text') {
        $lText = [string]$lMatch.text
      }
      $lFile = ''
      if ($lMatch.PSObject.Properties.Name -contains 'file') {
        $lFile = [string]$lMatch.file
      }
      $lViolations.Add(("filename extraction found by AST search: {0} {1}" -f $lFile, $lText).Trim())
    }
  }

  Add-RemoveWithGenericityTextViolations -Violations $lViolations -Paths $lFiles `
    -Pattern '\bExtractFileName\s*\(' `
    -Description 'filename extraction'
  Add-RemoveWithGenericityTextViolations -Violations $lViolations -Paths $lFiles `
    -Pattern '(?i)\b(maxtdb|TDB0[0-9]|Tdbutils|Tdbf|MaxLogic)\b' `
    -Description 'fixture-specific token'
  Add-RemoveWithGenericityTextViolations -Violations $lViolations -Paths $lFiles `
    -Pattern '(?i)\b(OriginalRange|BindingRange|StartLine|\.Line)\b[^\r\n]*(?<![:<>])=\s*[1-9]\d+' `
    -Description 'exact source-line predicate'
  Add-RemoveWithGenericityTextViolations -Violations $lViolations -Paths $lFiles `
    -Pattern '(?i)\b(legacy-final-statement-patch|TryFinalReadNBytesFileSizePatch)\b' `
    -Description 'known source-specific hard patch'

  if ($lViolations.Count -gt 0) {
    throw "remove-with production genericity failed:`n$($lViolations -join "`n")"
  }
}

if ($ImportOnly) {
  return
}

Assert-RemoveWithProductionGenericity -SourceFiles $SourceFiles
Write-Host 'remove-with production genericity: passed'
