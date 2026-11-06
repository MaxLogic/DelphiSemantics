BeforeAll {
    . (Join-Path $PSScriptRoot '..\run-shards.ps1')
    $emitter = Join-Path $TestDrive 'CrashEnvironment.exe'
    $source = Join-Path $TestDrive 'CrashEnvironment.cs'
    @'
using System;
class CrashEnvironment {
 static void Main() {
  Console.WriteLine(Environment.GetEnvironmentVariable("MAXLOGIC_MADEXCEPT_AI")+"|"+
   Environment.GetEnvironmentVariable("DAK_TEST_DISABLE_CRASH_SEND"));
 }
}
'@ | Set-Content -LiteralPath $source
    & "$env:WINDIR\Microsoft.NET\Framework64\v4.0.30319\csc.exe" /nologo /target:exe "/out:$emitter" $source
    if ($LASTEXITCODE -ne 0) { throw 'Crash environment emitter compilation failed.' }
}
Describe 'DS child crash environment' {
    It 'protects discovery and shard children even when the caller has unsafe values' {
        $savedAi = $env:MAXLOGIC_MADEXCEPT_AI
        $savedGuard = $env:DAK_TEST_DISABLE_CRASH_SEND
        $logs = Join-Path $TestDrive 'logs'
        $child = $null
        try {
            $env:MAXLOGIC_MADEXCEPT_AI = '0'
            $env:DAK_TEST_DISABLE_CRASH_SEND = '0'
            $child = New-DsProcess -Exe $emitter -Arguments @() -Cwd $TestDrive -Logs $logs -Scratch (Join-Path $TestDrive 'scratch') -Hash (Get-FileHash $emitter).Hash
            $child.process.WaitForExit(10000) | Should -BeTrue
            Complete-DsProcess -Child $child
            $exitCode = $child.status.exitCode
            $child = $null
            $exitCode | Should -Be 0
            [IO.File]::ReadAllText((Join-Path $logs 'stdout.log')).Trim() | Should -Be '1|1'
        } finally {
            if ($null -ne $child) { $child.job.Dispose(); $child.process.Dispose() }
            $env:MAXLOGIC_MADEXCEPT_AI = $savedAi
            $env:DAK_TEST_DISABLE_CRASH_SEND = $savedGuard
        }
    }
}
