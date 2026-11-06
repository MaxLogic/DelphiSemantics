#Requires -Version 7.0
<#
.SYNOPSIS
Runs the default DS suite in isolated, case-balanced Windows processes.
#>
[CmdletBinding()]
param(
    [ValidateRange(1,16)][int]$ShardCount = 4,
    [string]$ExecutablePath = '',
    [string]$LogRoot = '',
    [string]$OutputRoot = '',
    [string[]]$Run = @(),
    [string]$RunList = '',
    [ValidateRange(1,604800)][int]$TimeoutSeconds = 900
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Read-DsCaseResult {
    [CmdletBinding()]
    param([string]$XmlPath)
    $document = [Xml.XmlDocument]::new()
    $document.XmlResolver = $null
    $document.Load($XmlPath)
    foreach ($node in $document.SelectNodes('//test-case')) {
        $fixture = $node.SelectSingleNode('ancestor::test-suite[@type="Fixture"][1]')
        if ($null -eq $fixture) { throw "Case without fixture: $XmlPath" }
        [pscustomobject]@{
            id = $fixture.GetAttribute('name') + '.' + $node.GetAttribute('name')
            result = $node.GetAttribute('result')
            executed = $node.GetAttribute('executed')
            seconds = [double]::Parse($node.GetAttribute('time'), [Globalization.CultureInfo]::InvariantCulture)
            detail = $node.InnerText
        }
    }
}

function Compare-DsIdentity {
    [CmdletBinding()]
    [OutputType([string])]
    param([object[]]$Roster, [AllowEmptyCollection()][object[]]$Cases)
    $expected = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $actual = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($row in $Roster) { if (-not $expected.Add($row.id)) { "Duplicate roster identity: $($row.id)" } }
    foreach ($case in $Cases) {
        if (-not $actual.Add($case.id)) { "Duplicate executed identity: $($case.id)" }
        if (-not $expected.Contains($case.id)) { "Extra executed identity: $($case.id)" }
    }
    foreach ($id in $expected) { if (-not $actual.Contains($id)) { "Missing executed identity: $id" } }
}

function Get-DsShardPlan {
    [CmdletBinding()]
    param([object[]]$Roster, [int]$Count, [hashtable]$Weights)
    $shards = @(1..$Count | ForEach-Object {
        [pscustomobject]@{number=$_;seconds=0.0;cases=[Collections.Generic.List[object]]::new()}
    })
    $weighted = @(foreach ($row in $Roster) {
        $seconds = if ($Weights.ContainsKey($row.selector)) { [double]$Weights[$row.selector] } else { 0.1 }
        [pscustomobject]@{row=$row;seconds=$seconds;id=$row.id}
    })
    foreach ($item in $weighted | Sort-Object @{Expression='seconds';Descending=$true},id -CaseSensitive) {
        $shard = $shards | Sort-Object seconds,number | Select-Object -First 1
        $shard.cases.Add($item.row)
        $shard.seconds += $item.seconds
    }
    $shards | Where-Object { $_.cases.Count -gt 0 }
}

function Initialize-DsJobType {
    [CmdletBinding()]
    param()
    if ('DsShardJob' -as [type]) { return }
    Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using Microsoft.Win32.SafeHandles;

// Developer-runner Win32 boundary: assign the suspended process before any user code runs.
public sealed class DsShardJob : IDisposable {
    SafeFileHandle job;
    public Process Process { get; private set; }
    [StructLayout(LayoutKind.Sequential)] struct SecurityAttributes {
        public int length; public IntPtr descriptor; [MarshalAs(UnmanagedType.Bool)] public bool inherit;
    }
    [StructLayout(LayoutKind.Sequential)] struct BasicLimits {
        public long processTime, jobTime; public uint flags;
        public UIntPtr minimumWorkingSet, maximumWorkingSet; public uint activeProcessLimit;
        public UIntPtr affinity; public uint priorityClass, schedulingClass;
    }
    [StructLayout(LayoutKind.Sequential)] struct IoCounters {
        public ulong readOperations, writeOperations, otherOperations, readBytes, writeBytes, otherBytes;
    }
    [StructLayout(LayoutKind.Sequential)] struct ExtendedLimits {
        public BasicLimits basic; public IoCounters io;
        public UIntPtr processMemory, jobMemory, peakProcessMemory, peakJobMemory;
    }
    [StructLayout(LayoutKind.Sequential, CharSet=CharSet.Unicode)] struct StartupInfo {
        public int size; public string reserved, desktop, title;
        public uint x,y,width,height,xChars,yChars,fill,flags;
        public ushort show, reservedSize; public IntPtr reservedData,input,output,error;
    }
    [StructLayout(LayoutKind.Sequential)] struct ProcessInfo {
        public IntPtr process, thread; public uint pid, tid;
    }
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateJobObjectW(IntPtr attributes,string name);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool SetInformationJobObject(SafeFileHandle handle,int kind,ref ExtendedLimits limits,int size);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool QueryInformationJobObject(SafeFileHandle handle,int kind,IntPtr data,int size,out int returned);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool AssignProcessToJobObject(SafeFileHandle job,IntPtr process);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool IsProcessInJob(IntPtr process,SafeFileHandle job,out bool result);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateJobObject(SafeFileHandle job,uint code);
    [DllImport("kernel32.dll", SetLastError=true)] static extern bool TerminateProcess(IntPtr process,uint code);
    [DllImport("kernel32.dll", SetLastError=true)] static extern uint ResumeThread(IntPtr thread);
    [DllImport("kernel32.dll")] static extern uint WaitForSingleObject(IntPtr handle,uint milliseconds);
    [DllImport("kernel32.dll")] static extern bool CloseHandle(IntPtr handle);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern IntPtr CreateFileW(string path,uint access,uint share,ref SecurityAttributes attributes,uint creation,uint flags,IntPtr template);
    [DllImport("kernel32.dll", CharSet=CharSet.Unicode, SetLastError=true)] static extern bool CreateProcessW(string exe,StringBuilder command,IntPtr processAttributes,IntPtr threadAttributes,bool inherit,uint flags,IntPtr environment,string cwd,ref StartupInfo startup,out ProcessInfo process);

    static string Quote(string value) {
        // Windows CRT argument quoting, including embedded quotes and trailing backslashes.
        var result=new StringBuilder("\""); int slashes=0;
        foreach(char ch in value) {
            if(ch=='\\') {slashes++;continue;}
            if(ch=='"') {result.Append('\\',slashes*2+1);result.Append(ch);}
            else {result.Append('\\',slashes);result.Append(ch);}
            slashes=0;
        }
        result.Append('\\',slashes*2);return result.Append('"').ToString();
    }
    static IntPtr OpenOutput(string path,ref SecurityAttributes attributes) {
        IntPtr handle=CreateFileW(path,0x40000000,3,ref attributes,2,0x80,IntPtr.Zero);
        if(handle==new IntPtr(-1))throw new Win32Exception(Marshal.GetLastWin32Error(),"Open shard output");
        return handle;
    }
    public DsShardJob(ProcessStartInfo start,string stdout,string stderr) {
        if(!Path.IsPathRooted(start.FileName) || !Path.IsPathRooted(start.WorkingDirectory))
            throw new ArgumentException("Absolute executable and working directory required.");
        IntPtr rawJob=CreateJobObjectW(IntPtr.Zero,null);
        if(rawJob==IntPtr.Zero)throw new Win32Exception(Marshal.GetLastWin32Error(),"Create shard job");
        job=new SafeFileHandle(rawJob,true);
        var limits=new ExtendedLimits(); limits.basic.flags=0x2000; // JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        var info=new ProcessInfo(); IntPtr output=IntPtr.Zero,error=IntPtr.Zero,input=IntPtr.Zero,environment=IntPtr.Zero;
        bool created=false;
        try {
            if(!SetInformationJobObject(job,9,ref limits,Marshal.SizeOf<ExtendedLimits>()))
                throw new Win32Exception(Marshal.GetLastWin32Error(),"Set shard job limits");
            var attributes=new SecurityAttributes();attributes.length=Marshal.SizeOf<SecurityAttributes>();attributes.inherit=true;
            output=OpenOutput(stdout,ref attributes);error=OpenOutput(stderr,ref attributes);
            input=CreateFileW("NUL",0x80000000,3,ref attributes,3,0x80,IntPtr.Zero);
            if(input==new IntPtr(-1))throw new Win32Exception(Marshal.GetLastWin32Error(),"Open shard stdin");
            var startup=new StartupInfo();startup.size=Marshal.SizeOf<StartupInfo>();
            startup.flags=0x100;startup.input=input;startup.output=output;startup.error=error;
            var command=new StringBuilder(Quote(start.FileName));
            foreach(string argument in start.ArgumentList)command.Append(' ').Append(Quote(argument));
            var keys=new List<string>(start.Environment.Keys);keys.Sort(StringComparer.OrdinalIgnoreCase);
            var block=new StringBuilder();
            foreach(string key in keys)block.Append(key).Append('=').Append(start.Environment[key]).Append('\0');
            block.Append('\0');environment=Marshal.StringToHGlobalUni(block.ToString());
            // CREATE_NO_WINDOW | CREATE_UNICODE_ENVIRONMENT | CREATE_SUSPENDED; breakaway is not allowed.
            if(!CreateProcessW(start.FileName,command,IntPtr.Zero,IntPtr.Zero,true,0x08000404,environment,start.WorkingDirectory,ref startup,out info))
                throw new Win32Exception(Marshal.GetLastWin32Error(),"Create suspended shard");
            created=true;
            if(!AssignProcessToJobObject(job,info.process))
                throw new Win32Exception(Marshal.GetLastWin32Error(),"Assign suspended shard to job");
            Process=System.Diagnostics.Process.GetProcessById((int)info.pid);
            // Retain a handle before resume so even an immediate exit has a stable native result.
            IntPtr retained=Process.Handle;
            if(ResumeThread(info.thread)==uint.MaxValue)
                throw new Win32Exception(Marshal.GetLastWin32Error(),"Resume shard");
        } catch {
            if(created) {TerminateProcess(info.process,1);WaitForSingleObject(info.process,10000);}
            Dispose();if(Process!=null)Process.Dispose();throw;
        } finally {
            if(info.thread!=IntPtr.Zero)CloseHandle(info.thread);
            if(info.process!=IntPtr.Zero)CloseHandle(info.process);
            if(output!=IntPtr.Zero)CloseHandle(output);
            if(error!=IntPtr.Zero)CloseHandle(error);
            if(input!=IntPtr.Zero && input!=new IntPtr(-1))CloseHandle(input);
            if(environment!=IntPtr.Zero)Marshal.FreeHGlobal(environment);
        }
    }
    public int[] MemberIds() {
        for(int capacity=64;capacity<=65536;capacity*=2) {
            int size=8+IntPtr.Size*capacity;IntPtr buffer=Marshal.AllocHGlobal(size);
            try {
                int returned;
                if(!QueryInformationJobObject(job,3,buffer,size,out returned)) {
                    int error=Marshal.GetLastWin32Error();if(error==234)continue;
                    throw new Win32Exception(error,"Query shard job members");
                }
                int count=Marshal.ReadInt32(buffer,4);var ids=new int[count];
                for(int index=0;index<count;index++)ids[index]=checked((int)Marshal.ReadIntPtr(buffer,8+index*IntPtr.Size).ToInt64());
                return ids;
            } finally {Marshal.FreeHGlobal(buffer);}
        }
        throw new InvalidOperationException("Shard job member list exceeds safety bound.");
    }
    public bool Contains(Process process) {
        bool result;if(!IsProcessInJob(process.Handle,job,out result))throw new Win32Exception(Marshal.GetLastWin32Error());
        return result;
    }
    public void Terminate() {
        if(!TerminateJobObject(job,1))throw new Win32Exception(Marshal.GetLastWin32Error(),"Terminate shard job");
    }
    public void WaitForEmpty(int milliseconds) {
        var timer=Stopwatch.StartNew();
        while(MemberIds().Length!=0) {
            if(timer.ElapsedMilliseconds>=milliseconds)throw new TimeoutException("Shard job did not empty.");
            Thread.Sleep(10);
        }
    }
    public void Dispose() {if(job!=null)job.Dispose();}
}

'@
}

function New-DsProcess {
    [CmdletBinding(SupportsShouldProcess)]
    param([string]$Exe, [string[]]$Arguments, [string]$Cwd, [string]$Logs, [string]$Scratch,
        [string]$Hash, [string]$RosterPath = '')
    if (-not $PSCmdlet.ShouldProcess($Exe, "Launch isolated test process")) { throw "Process launch declined." }
    foreach ($path in @($Logs,(Join-Path $Scratch 'tmp'),(Join-Path $Scratch 'out'))) {
        [void][IO.Directory]::CreateDirectory($path)
    }
    $process = [Diagnostics.Process]::new()
    $process.StartInfo.FileName = $Exe
    $process.StartInfo.WorkingDirectory = $Cwd
    $process.StartInfo.UseShellExecute = $false
    $process.StartInfo.CreateNoWindow = $true
    $process.StartInfo.RedirectStandardOutput = $true
    $process.StartInfo.RedirectStandardError = $true
    foreach ($argument in $Arguments) { $process.StartInfo.ArgumentList.Add($argument) }
    $process.StartInfo.Environment['TEMP'] = Join-Path $Scratch 'tmp'
    $process.StartInfo.Environment['TMP'] = Join-Path $Scratch 'tmp'
    $process.StartInfo.Environment['DS_TEST_OUTPUT_ROOT'] = Join-Path $Scratch 'out'
    $process.StartInfo.Environment['MAXLOGIC_MADEXCEPT_AI'] = '1'
    $process.StartInfo.Environment['DAK_TEST_DISABLE_CRASH_SEND'] = '1'
    $process.StartInfo.Environment['DS_TEST_RUNLIST_LITERAL'] = '1'
    # Never inherit a caller's roster-only mode into an executing shard.
    [void]$process.StartInfo.Environment.Remove('DS_TEST_LIST_PATH')
    if ($RosterPath) { $process.StartInfo.Environment['DS_TEST_LIST_PATH'] = $RosterPath }
    $status = [ordered]@{command=@($Exe)+$Arguments;cwd=$Cwd;binarySha256=$Hash;state='starting';
        nativeExit=$null;exitCode=$null;wallSeconds=$null;pid=$null;tempRoot=(Join-Path $Scratch 'tmp');
        outputRoot=(Join-Path $Scratch 'out')}
    $statusPath = Join-Path $Logs 'status.json'
    $status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statusPath
    $job = $null
    try {
        Initialize-DsJobType
        $timer = [Diagnostics.Stopwatch]::StartNew()
        $job = [DsShardJob]::new($process.StartInfo,(Join-Path $Logs 'stdout.log'),(Join-Path $Logs 'stderr.log'))
        $process.Dispose()
        $process = $job.Process
        $status.pid = $process.Id
        $status.state = 'running'
        $status.descendants = @()
        $status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statusPath
        [pscustomobject]@{process=$process;status=$status;statusPath=$statusPath;timer=$timer;
            job=$job;logs=$Logs}
    } catch {
        if ($null -ne $job) { $job.Dispose() }
        $status.state = 'start-failed'
        $status.exitCode = 1
        $status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $statusPath
        $process.Dispose()
        throw
    }
}

function Complete-DsProcess {
    [CmdletBinding()]
    param([object]$Child, [switch]$TimedOut)
    try {
        $descendants = [Collections.Generic.List[object]]::new()
        foreach ($memberId in $Child.job.MemberIds()) {
            if ($memberId -eq $Child.status.pid) { continue }
            $member = Get-Process -Id $memberId -ErrorAction SilentlyContinue
            if ($null -eq $member) { continue }
            try {
                if ($member.HasExited -or -not $Child.job.Contains($member)) { continue }
                # Keep its process handle open while resolving metadata, excluding PID reuse.
                $metadata = Get-CimInstance -ClassName Win32_Process -Filter "ProcessId=$memberId"
                $descendants.Add([pscustomobject]@{pid=$memberId;name=$member.ProcessName;
                    commandLine=$metadata.CommandLine;creationUtcTicks=$member.StartTime.ToUniversalTime().Ticks})
            } finally { $member.Dispose() }
        }
        $Child.status.descendants = @($descendants)
        # Terminate the owned job even after the direct child has exited. No descendant can escape.
        $Child.job.Terminate()
        $Child.job.WaitForEmpty(10000)
        if (-not $Child.process.WaitForExit(10000)) { throw 'Shard process did not terminate.' }
        $Child.status.nativeExit = $Child.process.ExitCode
        $Child.status.exitCode = if ($TimedOut) { 124 } elseif ($descendants.Count -gt 0) { 1 } else { $Child.process.ExitCode }
        $Child.status.state = if ($TimedOut) { 'timeout' } elseif ($descendants.Count -gt 0) { 'descendants-survived' } else { 'completed' }
    } catch {
        $Child.status.state = 'infrastructure-error'
        $Child.status.exitCode = if ($TimedOut) { 124 } else { 1 }
        throw
    } finally {
        # Safe handle closure also kills the job if querying or termination itself failed.
        $Child.job.Dispose()
        $Child.timer.Stop()
        $Child.status.wallSeconds = $Child.timer.Elapsed.TotalSeconds
        $Child.status | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $Child.statusPath
        $Child.process.Dispose()
    }
}

function Test-DsFooter {
    [CmdletBinding()]
    param([string]$Logs, [object[]]$Cases)
    $text = [IO.File]::ReadAllText((Join-Path $Logs 'stdout.log')) + [IO.File]::ReadAllText((Join-Path $Logs 'stderr.log'))
    $counts = [ordered]@{}
    foreach ($field in 'Found','Passed','Failed','Errored','Leaked','Ignored') {
        $footerMatches = [regex]::Matches($text, "(?m)^Tests $field\s*:\s*(\d+)\s*$")
        if ($footerMatches.Count -ne 1) { throw "Missing/ambiguous $field footer in $Logs" }
        $counts[$field] = [long]$footerMatches[0].Groups[1].Value
    }
    $problems = [Collections.Generic.List[string]]::new()
    if ($counts.Found -eq 0 -or $counts.Found -ne $Cases.Count -or
        $counts.Found -ne ($counts.Passed+$counts.Failed+$counts.Errored+$counts.Leaked+$counts.Ignored)) {
        $problems.Add('Footer/XML count mismatch or empty execution.')
    }
    foreach ($pair in @(@('Success','Passed'),@('Failure','Failed'),@('Error','Errored'),@('MemoryLeak','Leaked'))) {
        if (@($Cases | Where-Object result -EQ $pair[0]).Count -ne $counts[$pair[1]]) {
            $problems.Add("XML/footer mismatch: $($pair[1])")
        }
    }
    if (($counts.Failed+$counts.Errored+$counts.Leaked+$counts.Ignored) -gt 0) { $problems.Add('Non-passing footer counts.') }
    if (@($Cases | Where-Object { $_.result -ne 'Success' -or $_.executed -ne 'True' }).Count -gt 0) {
        $problems.Add('Non-passing or unexecuted XML cases.')
    }
    $leak = $text -match '(?i)memory leaks? (?:has|have) been detected|unexpected memory leak|shutdown leak'
    if ($leak) { $problems.Add('Shutdown memory leak report.') }
    [pscustomobject]@{counts=$counts;shutdownLeakReport=$leak;problems=@($problems)}
}

# Dot sourcing exposes bounded helpers to developer regression checks without starting a run.
if ($MyInvocation.InvocationName -eq '.') { return }
if (-not $IsWindows) { throw 'DS test processes require Windows PowerShell 7.' }
$cwd = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
if (-not $ExecutablePath) { $ExecutablePath = Join-Path $PSScriptRoot 'bin\delphiSemanticsTests.exe' }
$ExecutablePath = (Resolve-Path -LiteralPath $ExecutablePath).Path
$binaryHash = (Get-FileHash -LiteralPath $ExecutablePath -Algorithm SHA256).Hash
if (-not $LogRoot) { $LogRoot = Join-Path $PSScriptRoot '.dak\delphiSemanticsTests\test-runs' }
if (-not $OutputRoot) { $OutputRoot = [IO.Path]::GetTempPath() }
$token = 's-' + [guid]::NewGuid().ToString('N').Substring(0,8)
$runRoot = Join-Path ([IO.Path]::GetFullPath($LogRoot)) $token
$scratchRoot = Join-Path ([IO.Path]::GetFullPath($OutputRoot)) $token
# Native fixture compilers and SQLite still consume MAX_PATH-limited paths.
# Include the longest shard number before starting any process or creating outputs.
$generatedOutputLength = (Join-Path $scratchRoot "$ShardCount\out").Length
if ($generatedOutputLength -gt 89) {
    throw "Shard output root length $generatedOutputLength exceeds the native-fixture 89-character budget. Set -OutputRoot to a shorter owned root."
}
[void][IO.Directory]::CreateDirectory($runRoot)
$timer = [Diagnostics.Stopwatch]::StartNew()
$children = [Collections.Generic.List[object]]::new()
$errorsFound = [Collections.Generic.List[string]]::new()
$cases = [Collections.Generic.List[object]]::new()
$summaries = [Collections.Generic.List[object]]::new()
$roster = @()
$plan = @()
$exitCode = 0
try {
    $rosterPath = Join-Path $runRoot 'registered-tests.json'
    $listing = New-DsProcess -Exe $ExecutablePath -Arguments @('--exclude:MaxTdbProof') -Cwd $cwd `
        -Logs (Join-Path $runRoot 'roster') -Scratch (Join-Path $scratchRoot 'roster') -Hash $binaryHash -RosterPath $rosterPath
    $expired = -not $listing.process.WaitForExit(60000)
    Complete-DsProcess -Child $listing -TimedOut:$expired
    if ($listing.status.exitCode -ne 0) { $exitCode=$listing.status.exitCode; throw 'Binary roster enumeration failed.' }
    $roster = @(Get-Content -LiteralPath $rosterPath -Raw | ConvertFrom-Json)
    if ($roster.Count -eq 0) { throw 'Empty binary roster.' }
    $ids = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $selectors = [Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($row in $roster) {
        if (-not $row.id -or -not $row.fixture -or -not $row.selector) { throw 'Incomplete binary roster row.' }
        if (-not $ids.Add($row.id) -or -not $selectors.Add($row.selector)) { throw "Ambiguous binary roster: $($row.id)" }
    }
    if ($RunList) { $Run += @(Get-Content -LiteralPath $RunList | Where-Object { $_.Trim().Length -gt 0 }) }
    if ($Run.Count -gt 0) {
        foreach ($selection in $Run) {
            if (-not @($roster | Where-Object {
                $_.fixture.StartsWith($selection,[StringComparison]::OrdinalIgnoreCase) -or
                $_.selector.Equals($selection,[StringComparison]::OrdinalIgnoreCase)
            }).Count) { throw "Unknown selection: $selection" }
        }
        $roster = @($roster | Where-Object {
            $row=$_
            @($Run | Where-Object { $row.fixture.StartsWith($_,[StringComparison]::OrdinalIgnoreCase) -or
                $row.selector.Equals($_,[StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        })
    }
    if ($roster.Count -eq 0) { throw 'Empty selection.' }
    $roster | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot 'selected-roster.json')
    $weights = @{}
    foreach ($row in Get-Content -LiteralPath (Join-Path $PSScriptRoot 'scripts\case-durations.json') -Raw | ConvertFrom-Json) {
        $weights[$row.selection] = $row.seconds
    }
    $plan = @(Get-DsShardPlan -Roster $roster -Count $ShardCount -Weights $weights)
    $plan | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath (Join-Path $runRoot 'plan.json')
    foreach ($shard in $plan) {
        $logs = Join-Path $runRoot ([string]$shard.number)
        [void][IO.Directory]::CreateDirectory($logs)
        $runListPath = Join-Path $logs 'selection.txt'
        $shard.cases.selector | Set-Content -LiteralPath $runListPath -Encoding utf8BOM
        $xml = Join-Path $logs 'cases.xml'
        $child = New-DsProcess -Exe $ExecutablePath -Arguments @(("--runlist:$runListPath"),'--exclude:MaxTdbProof',("--xmlfile:$xml")) `
            -Cwd $cwd -Logs $logs -Scratch (Join-Path $scratchRoot ([string]$shard.number)) -Hash $binaryHash
        $children.Add([pscustomobject]@{number=$shard.number;child=$child;xml=$xml;roster=@($shard.cases);finished=$false})
    }
    while (@($children | Where-Object { -not $_.finished }).Count -gt 0) {
        foreach ($item in $children | Where-Object { -not $_.finished }) {
            $expired = $item.child.timer.Elapsed.TotalSeconds -ge $TimeoutSeconds
            if (-not $item.child.process.HasExited -and -not $expired) { continue }
            try { Complete-DsProcess -Child $item.child -TimedOut:$expired }
            catch { $errorsFound.Add("Shard $($item.number): $_") }
            $item.finished = $true
            if ($item.child.status.exitCode -eq 124) { $exitCode=124 }
            elseif ($item.child.status.exitCode -ne 0 -and $exitCode -eq 0) { $exitCode=1 }
            try {
                $rows = @(Read-DsCaseResult -XmlPath $item.xml)
                foreach ($row in $rows) { $cases.Add($row) }
                foreach ($problem in Compare-DsIdentity -Roster $item.roster -Cases $rows) {
                    $errorsFound.Add("Shard $($item.number): $problem")
                }
                $summary = Test-DsFooter -Logs $item.child.logs -Cases $rows
                $summaries.Add($summary)
                foreach ($problem in $summary.problems) { $errorsFound.Add("Shard $($item.number): $problem") }
            } catch { $errorsFound.Add("Shard $($item.number) evidence: $_") }
            Write-Output "Shard $($item.number): exit=$($item.child.status.exitCode), wall=$($item.child.status.wallSeconds)s"
        }
        if (@($children | Where-Object { -not $_.finished }).Count -gt 0) { Start-Sleep -Milliseconds 100 }
    }
} catch { $errorsFound.Add($_.ToString()) }
finally {
    foreach ($item in $children | Where-Object { -not $_.finished }) {
        try { Complete-DsProcess -Child $item.child -TimedOut } catch { $errorsFound.Add("Cleanup: $_") }
    }
    $timer.Stop()
}
$identityDifferences = @(Compare-DsIdentity -Roster $roster -Cases @($cases))
if ((Get-FileHash -LiteralPath $ExecutablePath -Algorithm SHA256).Hash -ne $binaryHash) { $errorsFound.Add('Binary changed during run.') }
if (($errorsFound.Count -gt 0 -or $identityDifferences.Count -gt 0 -or $cases.Count -eq 0) -and $exitCode -eq 0) { $exitCode=1 }
$counts = [ordered]@{Found=0L;Passed=0L;Failed=0L;Errored=0L;Leaked=0L;Ignored=0L}
foreach ($summary in $summaries) { foreach ($field in @($counts.Keys)) { $counts[$field] += $summary.counts[$field] } }
$result = [ordered]@{state= $(if ($exitCode -eq 124) {'timeout'} else {'completed'});exitCode=$exitCode;
    executableSha256=$binaryHash;registeredCount=$roster.Count;counts=$counts;
    errors=@($errorsFound);identityDifferences=$identityDifferences;durationSeconds=$timer.Elapsed.TotalSeconds;
    logicalProcessors=[Environment]::ProcessorCount;shardCount=$plan.Count;ownedOutputRoot=$scratchRoot;
    shards=@($children | ForEach-Object { [pscustomobject]@{number=$_.number;status=$_.child.status;logs=$_.child.logs} })}
$result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath (Join-Path $runRoot 'aggregate.json')
@($cases) | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $runRoot 'cases.json')
Write-Output ($result | ConvertTo-Json -Depth 3)
Write-Output "Aggregate: $runRoot\aggregate.json"
exit $exitCode
