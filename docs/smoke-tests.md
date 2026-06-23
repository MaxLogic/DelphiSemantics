# Smoke Tests

## Proprietary Fixture Remove-With Smoke

The proprietary fixture under DelphiAIKit is read-only. Always clone it before
running `remove-with` in apply mode.

Run this from PowerShell:

```powershell
Set-Location F:\projects\MaxLogic\DelphiAiKit

$src = 'F:\projects\MaxLogic\DelphiAiKit\tests\fixtures\test-projects\<proprietary-fixture>'
$dst = Join-Path $env:TEMP 'dak-proprietary-fixture-remove-with-smoke'
$report = Join-Path $env:TEMP 'dak-proprietary-fixture-remove-with-smoke.json'
$tempRoot = [IO.Path]::GetFullPath($env:TEMP)

if (Test-Path -LiteralPath $dst) {
  $resolved = [IO.Path]::GetFullPath((Resolve-Path -LiteralPath $dst).Path)
  if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase)) {
    throw "Refusing to delete outside TEMP: $resolved"
  }
  Remove-Item -LiteralPath $resolved -Recurse -Force
}

Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force

bin\DelphiAIKit.exe remove-with `
  --project (Join-Path $dst 'src\<fixture>.dproj') `
  --all `
  --mode apply `
  --format json `
  --output $report

if ($LASTEXITCODE -ne 0) {
  throw "remove-with failed with exit code $LASTEXITCODE"
}

$json = Get-Content -LiteralPath $report -Raw | ConvertFrom-Json
$skipBuckets = @($json.skipped | Group-Object reason | Sort-Object Count -Descending |
  Select-Object Count, Name)
$summary = [pscustomobject]@{
  Status = $json.status
  Verification = $json.verification.status
  WithStatements = @($json.withStatements).Count
  AppliedEdits = $json.summary.appliedEdits
  Skipped = $json.summary.skipped
}

if ($summary.Status -ne 'applied') {
  throw "Expected applied status, got $($summary.Status)"
}
if ($summary.Verification -ne 'passed') {
  throw "Expected passed verification, got $($summary.Verification)"
}
if ($summary.AppliedEdits -lt 1) {
  throw "Expected at least one applied edit"
}
if ($summary.Skipped -gt 20) {
  throw "Unexpected skip regression: $($summary.Skipped)"
}

$summary
$skipBuckets
$report
```

Expected result:

- `Status` is `applied`.
- `Verification` is `passed`.
- `AppliedEdits` is greater than zero.
- `Skipped` stays within the smoke threshold.
- `$skipBuckets` lists the current remaining skip reasons for follow-up work.
- The original fixture path is never passed to `remove-with`; only the clone under
  `%TEMP%` is modified.
