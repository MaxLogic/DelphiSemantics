#Requires -Version 5.1
[CmdletBinding()]
param(
  [string]$DakRoot = 'F:\projects\MaxLogic\DelphiAiKit',
  [string]$EvidenceDirectory = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$lRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..\..'))
if ([string]::IsNullOrWhiteSpace($EvidenceDirectory)) {
  $EvidenceDirectory = Join-Path $lRoot ('tests\.dak\delphiSemanticsTests\ds687-process-deadline-r1\proof-' + [Guid]::NewGuid().ToString('N'))
}
[IO.Directory]::CreateDirectory($EvidenceDirectory) | Out-Null
. (Join-Path $lRoot 'scripts\run-migration-gate.ps1') -ImportOnly -DakRoot $DakRoot
# Setting the default also exercises existing call sites that supply no timeout.
$StepTimeoutSeconds = 5
$lHostPath = (Get-Process -Id $PID).Path
$lChild = Join-Path $EvidenceDirectory 'child with spaces.ps1'
$lGrandchild = Join-Path $EvidenceDirectory 'grandchild with spaces.ps1'
$lPidFile = Join-Path $EvidenceDirectory 'owned-processes.txt'
$lChildSource = @'
param([string]$Mode, [string]$Value, [string]$Grandchild, [string]$PidFile)
$ErrorActionPreference = 'Stop'
[Console]::Out.WriteLine('stdout:' + $Value)
[Console]::Error.WriteLine('stderr:' + $Value)
if ($Mode -eq 'normal') { exit 0 }
if ($Mode -eq 'failure') { exit 7 }
[IO.File]::AppendAllText($PidFile, "$PID|$((Get-Process -Id $PID).StartTime.Ticks)`n")
$lInfo = New-Object Diagnostics.ProcessStartInfo
$lInfo.FileName = (Get-Process -Id $PID).Path
$lInfo.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $Grandchild + '" -PidFile "' + $PidFile + '"'
$lInfo.UseShellExecute = $false
$lInfo.CreateNoWindow = $true
$lInfo.WindowStyle = [Diagnostics.ProcessWindowStyle]::Hidden
$lProcess = [Diagnostics.Process]::Start($lInfo)
$lWait = [Diagnostics.Stopwatch]::StartNew()
while (([IO.File]::ReadAllLines($PidFile).Length -lt 2) -and $lWait.Elapsed.TotalSeconds -lt 3) { Start-Sleep -Milliseconds 20 }
[Console]::Out.WriteLine('grandchild-started')
[Console]::Out.Flush()
[Console]::Error.Flush()
if ($Mode -eq 'exit-parent') { exit 0 }
Start-Sleep -Seconds 60
'@
$lGrandchildSource = @'
param([string]$PidFile)
[IO.File]::AppendAllText($PidFile, "$PID|$((Get-Process -Id $PID).StartTime.Ticks)`n")
Start-Sleep -Seconds 60
'@
[IO.File]::WriteAllText($lChild, $lChildSource, [Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText($lGrandchild, $lGrandchildSource, [Text.UTF8Encoding]::new($false))
$lRecords = New-Object 'Collections.Generic.List[object]'
$lValue = 'space "quote" trailing\'
foreach ($lMode in @('normal', 'failure', 'hang', 'exit-parent')) {
  if (Test-Path -LiteralPath $lPidFile) { Remove-Item -LiteralPath $lPidFile }
  $lTimer = [Diagnostics.Stopwatch]::StartNew()
  $lResult = Invoke-GateStep -Name $lMode -WorkingDirectory $EvidenceDirectory -FilePath $lHostPath -Arguments @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $lChild, '-Mode', $lMode,
    '-Value', $lValue, '-Grandchild', $lGrandchild, '-PidFile', $lPidFile
  ) -ArtifactDirectory $EvidenceDirectory -NoThrow -MaxOutputLines 0
  $lTimer.Stop()
  $lExpected = if ($lMode -eq 'normal') { 0 } elseif ($lMode -eq 'failure') { 7 } else { 124 }
  if ($lResult.exitCode -ne $lExpected) { throw "$lMode expected exit $lExpected, got $($lResult.exitCode)" }
  foreach ($lStream in @('stdout', 'stderr')) {
    $lText = [IO.File]::ReadAllText($lResult.$lStream)
    if (-not $lText.Contains($lStream + ':' + $lValue)) { throw "$lMode lost $lStream/argument value" }
  }
  if ($lMode -in @('hang', 'exit-parent')) {
    if (-not $lResult.timedOut -or -not $lResult.cleanupComplete -or $lTimer.Elapsed.TotalSeconds -gt 20) { throw "$lMode timeout or cleanup incomplete" }
    if (-not [IO.File]::ReadAllText($lResult.stdout).Contains('grandchild-started')) { throw "$lMode did not reach descendant seam" }
    $lOwned = [IO.File]::ReadAllLines($lPidFile)
    if ($lOwned.Length -ne 2) { throw "$lMode did not start both owned processes" }
    foreach ($lIdentity in $lOwned) {
      $lFields = $lIdentity.Split('|')
      $lLive = Get-Process -Id ([int]$lFields[0]) -ErrorAction SilentlyContinue
      if ($lLive -and $lLive.StartTime.Ticks -eq [long]$lFields[1]) { throw "$lMode left owned process $($lFields[0]) alive" }
    }
    $lMetadata = Get-Content -LiteralPath $lResult.metadata -Raw | ConvertFrom-Json
    if ($lMetadata.exitCode -ne 124 -or -not $lMetadata.timedOut -or -not $lMetadata.cleanupComplete) { throw "$lMode metadata invalid" }
  }
  $lRecords.Add([pscustomobject]@{ mode = $lMode; passed = $true; result = $lResult; seconds = $lTimer.Elapsed.TotalSeconds })
}
$lRecords.ToArray() | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $EvidenceDirectory 'results.json') -Encoding UTF8
Write-Host "PASS: 4 process cases; failures/errors/ignored 0; evidence $EvidenceDirectory"
