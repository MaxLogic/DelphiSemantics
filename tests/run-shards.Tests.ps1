#Requires -Version 7.3
# Synthetic Windows process tests; no Delphi build or retained proof root required.
Describe 'DS shard runner contracts' {
    BeforeEach {
        $script:lane = Split-Path $PSScriptRoot -Parent
        . (Join-Path $PSScriptRoot 'run-shards.ps1')
        $script:proof = [IO.Directory]::CreateTempSubdirectory('ds767-').FullName
        $script:probeExe = Join-Path $script:proof 'runner-probe.exe'
        $sourcePath = Join-Path $script:proof 'runner-probe.cs'
        $probeSource = @'
using System;
using System.IO;
using System.Diagnostics;
using System.Threading;
using System.Runtime.InteropServices;
using System.Text;
class RunnerProbe {
 [StructLayout(LayoutKind.Sequential)] struct ProcessInformation {public IntPtr process,thread;public uint pid,tid;}
 [DllImport("kernel32.dll",CharSet=CharSet.Unicode,SetLastError=true)] static extern bool CreateProcessW(string exe,StringBuilder command,IntPtr pa,IntPtr ta,bool inherit,uint flags,IntPtr env,string cwd,IntPtr startup,out ProcessInformation process);
 [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
 static Process Detached() {
  int size=IntPtr.Size==8?104:68;IntPtr startup=Marshal.AllocHGlobal(size);
  try {
   Marshal.Copy(new byte[size],0,startup,size);Marshal.WriteInt32(startup,size);
   string exe=Process.GetCurrentProcess().MainModule.FileName;
   ProcessInformation pi;
   if(!CreateProcessW(exe,new StringBuilder("\""+exe+"\" --idle"),IntPtr.Zero,IntPtr.Zero,false,0x08000000,IntPtr.Zero,Environment.CurrentDirectory,startup,out pi))throw new System.ComponentModel.Win32Exception();
   try {Process child=Process.GetProcessById((int)pi.pid);IntPtr retained=child.Handle;return child;}
   finally {CloseHandle(pi.thread);CloseHandle(pi.process);}
  }finally {Marshal.FreeHGlobal(startup);}
 }

 static void Main(string[] args) {
  if(args.Length>0 && args[0]=="--idle") {Thread.Sleep(60000);return;}
  string roster=Environment.GetEnvironmentVariable("DS_TEST_LIST_PATH");
  if(!String.IsNullOrEmpty(roster)) {
   File.WriteAllText(roster,"[{\"fixture\":\"Probe.Tests\",\"selector\":\"Probe.Tests.One\",\"id\":\"Probe.Tests.One\"},{\"fixture\":\"Probe.Tests\",\"selector\":\"Probe.Tests.Two(a,b)\",\"id\":\"Probe.Tests.Two(a,b)\"}]");return;
  }
  string mode=Environment.GetEnvironmentVariable("DS767_PROBE_MODE")??"success";
  if(mode=="timeout" || mode=="detached" || mode=="detached-pipes") {
   ProcessStartInfo info=new ProcessStartInfo(Process.GetCurrentProcess().MainModule.FileName,"--idle");
   info.WorkingDirectory=Environment.CurrentDirectory;info.UseShellExecute=false;info.CreateNoWindow=true;
   if(mode=="detached") {info.RedirectStandardOutput=true;info.RedirectStandardError=true;}
   Process child=mode=="detached"?Detached():Process.Start(info);
   File.WriteAllText(Path.Combine(Environment.GetEnvironmentVariable("DS_TEST_OUTPUT_ROOT"),"descendant.pid"),child.Id.ToString()+"|"+child.StartTime.ToUniversalTime().Ticks.ToString());
   if(mode=="timeout") {Thread.Sleep(60000);return;}
  }
  string xml="",runlist="";
  foreach(string arg in args) {if(arg.StartsWith("--xmlfile:"))xml=arg.Substring(10);if(arg.StartsWith("--runlist:"))runlist=arg.Substring(10);}
  string[] selected=File.ReadAllLines(runlist);
  string result=mode=="failure"?"Failure":mode=="ignored"?"Ignored":mode=="leak"?"MemoryLeak":"Success";
  int count=selected.Length;
  using(StreamWriter writer=new StreamWriter(xml)) {
   writer.Write("<test-results><test-suite type=\"Fixture\" name=\"Probe.Tests\"><results>");
   foreach(string row in selected) {
    if(mode=="missing")continue;
    string name=row.Substring("Probe.Tests.".Length);
    string node="<test-case name=\""+name+"\" executed=\"True\" result=\""+result+"\" time=\"0.001\"/>";
    writer.Write(node);if(mode=="duplicate")writer.Write(node);
   }
   if(mode=="extra")writer.Write("<test-case name=\"Extra\" executed=\"True\" result=\"Success\" time=\"0.001\"/>");
   writer.Write("</results></test-suite></test-results>");
  }
  Console.WriteLine("Tests Found   : "+count);
  Console.WriteLine("Tests Passed  : "+(result=="Success"?count:0));
  Console.WriteLine("Tests Failed  : "+(result=="Failure"?count:0));
  Console.WriteLine("Tests Errored : 0");
  Console.WriteLine("Tests Leaked  : "+(result=="MemoryLeak"?count:0));
  Console.WriteLine("Tests Ignored : "+(result=="Ignored"?count:0));
  if(mode=="shutdown-leak")Console.Error.WriteLine("An unexpected memory leak has occurred.");
  // Deliberately return zero even for bad cases: wrapper must enforce evidence.
 }
}
'@
        Set-Content -LiteralPath $sourcePath -Value $probeSource
        $compiler = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
        function Invoke-ProbeProcess {
            param([string]$Exe, [string[]]$Arguments, [string]$Mode = '')
            $process = [Diagnostics.Process]::new()
            $process.StartInfo.FileName = $Exe
            $process.StartInfo.WorkingDirectory = $script:lane
            $process.StartInfo.UseShellExecute = $false
            $process.StartInfo.CreateNoWindow = $true
            $process.StartInfo.RedirectStandardOutput = $true
            $process.StartInfo.RedirectStandardError = $true
            foreach ($argument in $Arguments) { $process.StartInfo.ArgumentList.Add($argument) }
            $process.StartInfo.Environment['DS767_PROBE_MODE'] = $Mode
            try {
                [void]$process.Start()
                $stdout = $process.StandardOutput.ReadToEndAsync()
                $stderr = $process.StandardError.ReadToEndAsync()
                if (-not $process.WaitForExit(60000)) {
                    $process.Kill($true)
                    $process.WaitForExit()
                    throw 'Probe wrapper exceeded its 60-second test deadline.'
                }
                if (-not [Threading.Tasks.Task]::WaitAll(@($stdout, $stderr), 10000)) {
                    throw 'Probe output pipes remained open after process exit.'
                }
                [pscustomobject]@{ exit = $process.ExitCode; stdout = $stdout.Result; stderr = $stderr.Result }
            } finally { $process.Dispose() }
        }
        $compile = Invoke-ProbeProcess -Exe $compiler -Arguments @('/nologo', '/target:exe', "/out:$script:probeExe", $sourcePath)
        if ($compile.exit -ne 0) { throw "Probe compile failed: $($compile.stdout) $($compile.stderr)" }
        function Invoke-ProbeMode {
            param([string]$Mode, [string]$OutputRoot = $script:proof)
            $result = Invoke-ProbeProcess -Exe (Join-Path $PSHOME 'pwsh.exe') -Mode $Mode -Arguments @(
                '-NoProfile', '-File', (Join-Path $PSScriptRoot 'run-shards.ps1'),
                '-ExecutablePath', $script:probeExe, '-LogRoot', (Join-Path $script:proof "probe-$Mode\logs"),
                '-OutputRoot', $OutputRoot, '-TimeoutSeconds', '2', '-ShardCount', '2')
            $aggregateLines = @($result.stdout -split '\r?\n' | Where-Object { $_.StartsWith('Aggregate: ') })
            $aggregate = if ($aggregateLines.Count) {
                Get-Content -LiteralPath $aggregateLines[-1].Substring(11) -Raw | ConvertFrom-Json
            } else { $null }
            [pscustomobject]@{ exit = $result.exit; aggregate = $aggregate; stderr = $result.stderr }
        }
    }
    AfterEach {
        # A failing lifetime assertion must not leave the stand-in sleeper running.
        foreach ($file in Get-ChildItem -LiteralPath $script:proof -Filter descendant.pid -Recurse) {
            $identity = (Get-Content -LiteralPath $file.FullName).Split('|')
            $child = Get-Process -Id ([int]$identity[0]) -ErrorAction SilentlyContinue
            if ($child -and $child.StartTime.ToUniversalTime().Ticks -eq [long]$identity[1] -and $child.Path -eq $script:probeExe) {
                $child.Kill($true)
                $child.WaitForExit()
                $child.Dispose()
            }
        }
        $root = [IO.Path]::GetFullPath($script:proof)
        $parent = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\') + '\'
        if (-not $root.StartsWith($parent, [StringComparison]::OrdinalIgnoreCase)) { throw "Unsafe scratch root: $root" }
        $items = @(Get-Item -LiteralPath $root) + @(Get-ChildItem -LiteralPath $root -Recurse -Force)
        if (@($items | Where-Object { $_.Attributes -band [IO.FileAttributes]::ReparsePoint }).Count) {
            throw "Refusing scratch cleanup through a reparse point: $root"
        }
        Remove-Item -LiteralPath $root -Recurse -Force
    }
    It 'balances individual cases deterministically regardless of input order' {
        $rows=@(1..12|ForEach-Object{[pscustomobject]@{id="case$_";selector="case$_";fixture='OneFixture'}})
        $weights=@{case1=99;case2=70;case3=10}
        $first=@(Get-DsShardPlan -Roster $rows -Count 4 -Weights $weights)|ConvertTo-Json -Depth 8 -Compress
        [array]::Reverse($rows)
        $second=@(Get-DsShardPlan -Roster $rows -Count 4 -Weights $weights)|ConvertTo-Json -Depth 8 -Compress
        $second|Should BeExactly $first
    }
    It 'accepts a complete successful execution' {
        $r=Invoke-ProbeMode success
        $r.exit|Should Be 0
        $r.aggregate.counts.Found|Should Be 2
        $r.aggregate.identityDifferences.Count|Should Be 0
    }
    It 'rejects <Mode> evidence even when the binary returns zero' -TestCases @(
        @{Mode='failure'},@{Mode='ignored'},@{Mode='leak'},@{Mode='shutdown-leak'},
        @{Mode='duplicate'},@{Mode='missing'},@{Mode='extra'}
    ) {
        param($Mode)
        $r=Invoke-ProbeMode $Mode
        $r.exit|Should Be 1
        if($Mode -in 'duplicate','missing','extra') {
            $r.aggregate.identityDifferences.Count|Should BeGreaterThan 0
        }
    }
    It 'rejects and reaps a detached descendant: <Mode>' -TestCases @(
        @{Mode='detached'},@{Mode='detached-pipes'}
    ) {
        param($Mode)
        $r=Invoke-ProbeMode $Mode
        $r.exit|Should Be 1
        foreach($shard in $r.aggregate.shards) {
            $identity=(Get-Content (Join-Path $shard.status.outputRoot 'descendant.pid')).Split('|')
            $live=Get-Process -Id ([int]$identity[0]) -ErrorAction SilentlyContinue
            [bool]($live -and $live.StartTime.ToUniversalTime().Ticks -eq [long]$identity[1])|Should Be $false
            $reported=@($shard.status.descendants|Where-Object pid -eq ([int]$identity[0]))
            $reported.Count|Should Be 1
            $reported[0].name|Should Be 'runner-probe'
            $reported[0].commandLine|Should Match '--idle'
            foreach($descendant in $shard.status.descendants) {
                $live=Get-Process -Id $descendant.pid -ErrorAction SilentlyContinue
                [bool]($live -and $live.StartTime.ToUniversalTime().Ticks -eq $descendant.creationUtcTicks)|Should Be $false
            }
        }
    }
    It 'kills timed-out shard process trees and returns distinct exit 124' {
        $r=Invoke-ProbeMode timeout
        $r.exit|Should Be 124
        foreach($shard in $r.aggregate.shards) {
            $shard.status.state|Should Be 'timeout'
            $shard.status.nativeExit|Should Not BeNullOrEmpty
            $pidFile=Join-Path $shard.status.outputRoot 'descendant.pid'
            $identity=(Get-Content $pidFile).Split('|')
            $live=Get-Process -Id ([int]$identity[0]) -ErrorAction SilentlyContinue
            [bool]($live -and $live.StartTime.ToUniversalTime().Ticks -eq [long]$identity[1])|Should Be $false
            $parent=Get-Process -Id $shard.status.pid -ErrorAction SilentlyContinue
            [bool]($parent -and $parent.Path -eq $script:probeExe)|Should Be $false
        }
    }
    It 'refuses an over-budget output root before creating it' {
        $longRoot = Join-Path $script:proof ('x' * 90)
        $expectedLength = (Join-Path (Join-Path $longRoot 's-12345678') '2\out').Length
        $result = Invoke-ProbeMode -Mode success -OutputRoot $longRoot
        $result.exit | Should Not Be 0
        $result.stderr | Should Match "root length $expectedLength exceeds"
        Test-Path -LiteralPath $longRoot | Should Be $false
        Test-Path -LiteralPath (Join-Path $script:proof 'probe-success\logs') | Should Be $false
    }
}
