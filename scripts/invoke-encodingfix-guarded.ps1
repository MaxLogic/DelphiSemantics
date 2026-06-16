[CmdletBinding()]
param(
  [string]$RepoRoot = (Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)),
  [string[]]$Path = @('src', 'tests\src', 'projects'),
  [string]$Scope = 'git-changed',
  [string]$Preset = 'delphi-ai',
  [string]$Format = 'json',
  [string]$EncodingFixTool = 'EncodingFixTool',
  [switch]$DryRun,
  [switch]$AllowBroadRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-NormalizedRelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Candidate
  )

  $lRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar)
  $lCandidate = [IO.Path]::GetFullPath((Join-Path $lRoot $Candidate)).TrimEnd(
    [IO.Path]::DirectorySeparatorChar, [IO.Path]::AltDirectorySeparatorChar)

  if (-not $lCandidate.StartsWith($lRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside repo root: $Candidate"
  }
  if ($lCandidate.Length -eq $lRoot.Length) {
    return '.'
  }

  return $lCandidate.Substring($lRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar)
}

function Assert-EncodingFixPathAllowed {
  param(
    [Parameter(Mandatory = $true)][string]$RelativePath,
    [bool]$AllowRoot
  )

  $lPath = $RelativePath -replace '/', '\'
  $lLower = $lPath.ToLowerInvariant()
  $lExcluded = @('.dak', '.agents', 'bin', 'lib', 'tests\bin', 'tests\fixtures')

  if (($lPath -eq '.') -and (-not $AllowRoot)) {
    throw 'Refusing broad root EncodingFix cleanup. Use a narrow path such as src, tests\src, or projects, or pass -AllowBroadRoot explicitly.'
  }

  foreach ($lPrefix in $lExcluded) {
    if (($lLower -eq $lPrefix) -or $lLower.StartsWith($lPrefix + '\')) {
      throw "Refusing excluded EncodingFix path: $RelativePath"
    }
  }
}

function Invoke-CrlfAudit {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$RelativePath
  )

  $lTarget = if ($RelativePath -eq '.') { $Root } else { Join-Path $Root $RelativePath }
  $lExtensions = @('.pas', '.dpr', '.dpk', '.inc', '.dfm', '.dproj')
  $lFiles = @(Get-ChildItem -LiteralPath $lTarget -Recurse -File -Force -ErrorAction SilentlyContinue |
    Where-Object { $lExtensions -contains $_.Extension.ToLowerInvariant() })
  foreach ($lFile in $lFiles) {
    $lText = [IO.File]::ReadAllText($lFile.FullName)
    if ($lText -match "(?<!`r)`n") {
      throw "CRLF audit failed: $($lFile.FullName)"
    }
  }
  Write-Output "CRLF audit passed for $RelativePath ($($lFiles.Count) Delphi file(s))."
}

$lRepoRoot = [IO.Path]::GetFullPath($RepoRoot)
if (-not (Test-Path -LiteralPath $lRepoRoot -PathType Container)) {
  throw "RepoRoot not found: $lRepoRoot"
}

foreach ($lPath in $Path) {
  $lRelativePath = Get-NormalizedRelativePath -Root $lRepoRoot -Candidate $lPath
  Assert-EncodingFixPathAllowed -RelativePath $lRelativePath -AllowRoot:$AllowBroadRoot

  if (($lRelativePath -eq '.') -and $AllowBroadRoot) {
    Write-Output 'AllowBroadRoot enabled: broad root cleanup is explicitly opted in.'
  }

  $lCommandText = "EncodingFixTool path=$lRelativePath preset=$Preset scope=$Scope format=$Format"
  if ($DryRun) {
    Write-Output "DRY RUN: $lCommandText"
  } else {
    Push-Location $lRepoRoot
    try {
      & $EncodingFixTool "path=$lRelativePath" "preset=$Preset" "scope=$Scope" "format=$Format"
      if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
      }
    } finally {
      Pop-Location
    }
  }

  Invoke-CrlfAudit -Root $lRepoRoot -RelativePath $lRelativePath
}
