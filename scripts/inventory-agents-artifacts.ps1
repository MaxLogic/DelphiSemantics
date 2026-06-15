[CmdletBinding()]
param(
  [string]$AgentsRoot,
  [ValidateSet('Text', 'Json')][string]$Format = 'Text',
  [switch]$Cleanup
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoRoot = Split-Path -Parent $ScriptRoot
if ([string]::IsNullOrWhiteSpace($AgentsRoot)) {
  $AgentsRoot = Join-Path $RepoRoot '.agents'
}

function Get-RelativePath {
  param(
    [Parameter(Mandatory = $true)][string]$Root,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $lRoot = [IO.Path]::GetFullPath($Root).TrimEnd([IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar)
  $lPath = [IO.Path]::GetFullPath($Path)
  if (-not $lPath.StartsWith($lRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Path is outside .agents root: $lPath"
  }

  return $lPath.Substring($lRoot.Length).TrimStart([IO.Path]::DirectorySeparatorChar,
    [IO.Path]::AltDirectorySeparatorChar)
}

function Get-AgentArtifactCategory {
  param([Parameter(Mandatory = $true)][string]$RelativePath)

  $lPath = $RelativePath -replace '/', '\'
  $lExtension = [IO.Path]::GetExtension($lPath).ToLowerInvariant()

  if ($lPath -like 'plans\*.md') {
    return 'active-plan'
  }
  if ($lPath -like 'resolved-plans\*.md') {
    return 'resolved-plan'
  }
  if ($lPath -eq 'resolve-task-run.md') {
    return 'run-log'
  }
  if ($lPath -eq 'handoff.md') {
    return 'handoff-note'
  }
  if ($lExtension -eq '.md') {
    return 'durable-note'
  }
  if ($lExtension -eq '.exe') {
    return 'generated-binary'
  }
  if ($lExtension -in @('.dpr', '.pas', '.dfm')) {
    return 'scratch-delphi-source'
  }
  if ($lExtension -eq '.patch') {
    return 'saved-patch'
  }
  return 'unknown'
}

function Get-AgentArtifactAction {
  param([Parameter(Mandatory = $true)][string]$Category)

  switch ($Category) {
    'active-plan' { return 'Keep while plan is active.' }
    'resolved-plan' { return 'Keep as resolved planning record unless archived.' }
    'run-log' { return 'Keep while current goal/run evidence is useful.' }
    'handoff-note' { return 'Keep as durable handoff note.' }
    'durable-note' { return 'Keep unless content is obsolete.' }
    'generated-binary' { return 'Review for removal; generated executable.' }
    'scratch-delphi-source' { return 'Review with matching generated binary.' }
    'saved-patch' { return 'Keep only if referenced by task notes.' }
    default { return 'Review manually; category is unknown.' }
  }
}

function Get-AgentArtifactInventory {
  param([Parameter(Mandatory = $true)][string]$Root)

  if (-not (Test-Path -LiteralPath $Root -PathType Container)) {
    throw ".agents root not found: $Root"
  }

  $lItems = @(Get-ChildItem -LiteralPath $Root -Recurse -File -Force |
    Sort-Object FullName |
    ForEach-Object {
      $lRelativePath = Get-RelativePath -Root $Root -Path $_.FullName
      [pscustomobject]@{
        relativePath = $lRelativePath
        category = Get-AgentArtifactCategory -RelativePath $lRelativePath
        sizeBytes = [int64]$_.Length
        extension = $_.Extension
        lastWriteTime = $_.LastWriteTime.ToString('o')
      }
    })

  $lSummary = @{}
  $lBytes = @{}
  foreach ($lItem in $lItems) {
    if (-not $lSummary.ContainsKey($lItem.category)) {
      $lSummary[$lItem.category] = 0
      $lBytes[$lItem.category] = [int64]0
    }
    $lSummary[$lItem.category]++
    $lBytes[$lItem.category] += [int64]$lItem.sizeBytes
  }

  $lSummaryItems = @($lSummary.Keys | Sort-Object | ForEach-Object {
    [pscustomobject]@{
      category = $_
      count = $lSummary[$_]
      bytes = $lBytes[$_]
      action = Get-AgentArtifactAction -Category $_
    }
  })
  $lNextActions = @(
    'Review generated-binary and scratch-delphi-source items before manual pruning.'
    'Keep saved-patch items only when a task note still references them.'
    'Rerun this helper after review-approved cleanup; it never deletes files.'
  )

  return [pscustomobject]@{
    schemaVersion = 1
    agentsRoot = [IO.Path]::GetFullPath($Root)
    itemCount = $lItems.Count
    summary = $lSummaryItems
    items = $lItems
    nextActions = $lNextActions
  }
}

if ($Cleanup) {
  Write-Error 'This .agents inventory helper is read-only. Review the inventory output and delete approved generated artifacts manually.'
  exit 1
}

$lInventory = Get-AgentArtifactInventory -Root $AgentsRoot

if ($Format -eq 'Json') {
  $lInventory | ConvertTo-Json -Depth 6
  exit 0
}

Write-Output ".agents artifact inventory: $($lInventory.agentsRoot)"
Write-Output "Total files: $($lInventory.itemCount)"
Write-Output ''
Write-Output 'Summary:'
$lInventory.summary |
  ForEach-Object { Write-Output ("  {0}: {1} file(s), {2} bytes - {3}" -f $_.category, $_.count, $_.bytes, $_.action) }
Write-Output ''
Write-Output 'Items:'
$lInventory.items |
  ForEach-Object { Write-Output ("  [{0}] {1} ({2} bytes)" -f $_.category, $_.relativePath, $_.sizeBytes) }
Write-Output ''
Write-Output 'Next actions:'
$lInventory.nextActions | ForEach-Object { Write-Output "- $_" }
