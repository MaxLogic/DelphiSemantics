param(
    [string]$DakRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-RepoPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BasePath,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    if ([System.IO.Path]::IsPathRooted($RelativePath)) {
        return [System.IO.Path]::GetFullPath($RelativePath)
    }

    return [System.IO.Path]::GetFullPath((Join-Path $BasePath $RelativePath))
}

function Convert-ToCanonicalPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    return [System.IO.Path]::GetFullPath($Path).TrimEnd('\', '/').ToLowerInvariant()
}

function Get-RegisteredTestPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$ProjectFile
    )

    $projectDir = Split-Path -Parent $ProjectFile
    $text = [System.IO.File]::ReadAllText($ProjectFile)
    $matches = [regex]::Matches($text, "(?im)^\s*[\w\.]+\s+in\s+'([^']*test\.[^']*\.pas)'")
    $paths = New-Object System.Collections.Generic.List[string]

    foreach ($match in $matches) {
        $registeredPath = $match.Groups[1].Value -replace '\\\\', '\'
        [void]$paths.Add((Convert-ToCanonicalPath (Resolve-RepoPath $projectDir $registeredPath)))
    }

    return $paths.ToArray()
}

function Get-TestUnitPaths {
    param(
        [Parameter(Mandatory = $true)]
        [string]$TestRoot
    )

    if (-not (Test-Path -LiteralPath $TestRoot -PathType Container)) {
        throw "Test root not found: $TestRoot"
    }

    # The DUnitX projects register direct child test units from their configured root.
    return Get-ChildItem -LiteralPath $TestRoot -Filter 'test.*.pas' -File |
        ForEach-Object { Convert-ToCanonicalPath $_.FullName }
}

function Test-DUnitXRegistration {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [string]$ProjectFile,

        [Parameter(Mandatory = $true)]
        [string]$TestRoot
    )

    if (-not (Test-Path -LiteralPath $ProjectFile -PathType Leaf)) {
        throw "DUnitX project not found for ${Name}: $ProjectFile"
    }

    $expected = @(Get-TestUnitPaths -TestRoot $TestRoot | Sort-Object)
    $registered = @(Get-RegisteredTestPaths -ProjectFile $ProjectFile | Sort-Object -Unique)
    $expectedSet = @{}
    $registeredSet = @{}

    foreach ($path in $expected) {
        $expectedSet[$path] = $true
    }

    foreach ($path in $registered) {
        $registeredSet[$path] = $true
    }

    $missing = @($expected | Where-Object { -not $registeredSet.ContainsKey($_) })
    $stale = @($registered | Where-Object { -not $expectedSet.ContainsKey($_) })

    Write-Host ("{0}: files={1}; registered={2}" -f $Name, $expected.Count, $registered.Count)

    if (($missing.Count -eq 0) -and ($stale.Count -eq 0)) {
        return $true
    }

    if ($missing.Count -gt 0) {
        Write-Host ("{0}: missing DUnitX registrations:`n  {1}" -f $Name, ($missing -join "`n  "))
    }

    if ($stale.Count -gt 0) {
        Write-Host ("{0}: stale DUnitX registrations:`n  {1}" -f $Name, ($stale -join "`n  "))
    }

    return $false
}

$repoRoot = Resolve-RepoPath $PSScriptRoot '..\..'
if ([string]::IsNullOrWhiteSpace($DakRoot)) {
    $dakRoot = Resolve-RepoPath $repoRoot '..\DelphiAiKit'
} else {
    $dakRoot = Resolve-RepoPath (Get-Location).Path $DakRoot
}
$checks = @(
    @{
        Name = 'DelphiSemantics'
        ProjectFile = Resolve-RepoPath $repoRoot 'tests\delphiSemanticsTests.dpr'
        TestRoot = Resolve-RepoPath $repoRoot 'tests\src'
        TestPattern = 'tests/src/test.*.pas'
    },
    @{
        Name = 'DelphiAIKit'
        ProjectFile = Resolve-RepoPath $dakRoot 'tests\DelphiAIKit.Tests.dpr'
        TestRoot = Resolve-RepoPath $dakRoot 'tests\units'
        TestPattern = 'tests/units/test.*.pas'
    }
)

$ok = $true
foreach ($check in $checks) {
    Write-Host ("Checking {0}: {1}" -f $check['Name'], $check['TestPattern'])
    if (-not (Test-DUnitXRegistration -Name $check['Name'] -ProjectFile $check['ProjectFile'] -TestRoot $check['TestRoot'])) {
        $ok = $false
    }
}

if (-not $ok) {
    exit 1
}

Write-Host 'DUnitX registration guard passed.'
