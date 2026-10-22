unit Test.Support;

interface

uses
  System.Classes, DUnitX.TestFramework,
  DelphiSemantics.Query, DelphiSemantics.Snapshot;

function CreateTestTempRoot(const aFolderName: string): string;
function RepoRoot: string;
function FixturePath(const aRelativePath: string): string; overload;
function FixturePath(const aFolder, aFileName: string): string; overload;
function RepoSourcePath(const aRelativePath: string): string;
function ReadRepoSource(const aRelativePath: string): string;
procedure WaitForTestThreads(const aThreads: array of TThread; const aTimeoutMs: Cardinal);

type
  TScopedSnapshotQueryContext = class
  private
    fContext: TDelphiSemanticSymbolQueryContext;
  public
    constructor Create(const aSnapshot: TDelphiProjectSnapshot);
    destructor Destroy; override;
    property Context: TDelphiSemanticSymbolQueryContext read fContext;
  end;

  TScopedEnvironmentVariable = class
  private
    fHadPreviousValue: Boolean;
    fLockHeld: Boolean;
    fName: string;
    fPreviousValue: string;
    fValueApplied: Boolean;
  public
    constructor Create(const aName, aValue: string);
    destructor Destroy; override;
  end;

  [TestFixture]
  TSupportTests = class
  public
    [Test]
    procedure WaitForTestThreadsReturnsForCompletedWorker;
    [Test]
    procedure WaitForTestThreadsFailsTimedOutWorker;
    [Test]
    procedure WaitForTestThreadsFailsWorkerException;
    [Test]
    procedure SnapshotTestsUseScopedEnvironmentHelper;
    [Test]
    procedure ScopedEnvironmentRestoresMissingValue;
    [Test]
    procedure ScopedEnvironmentRestoresEmptyValue;
    [Test]
    procedure ScopedEnvironmentRestoresPreviousValue;
    [Test]
    procedure ScopedEnvironmentGuardsFullScopeWithLock;
    [Test]
    procedure ScopedEnvironmentSerializesOverlappingScopes;
    [Test]
    procedure ScopedEnvironmentConstructorFailureReleasesLock;
    [Test]
    procedure RepoPathHelpersResolveFixturesAndSource;
    [Test]
    procedure SnapshotBackedQueryContextsUseScopedHelper;
  end;

  [TestFixture]
  TTestTempCleanupTests = class
  public
    [Test]
    procedure CleanupKeepsReplacedDirectoryOutsideRoot;
    [Test]
    procedure CleanupKeepsReplacedFileOutsideRoot;
    [Test]
    procedure OwnerPidRequiresPidAndGuidSuffix;
    [Test]
    procedure SweepRemovesOnlyDeadUnkeptOwnerRoots;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SyncObjs, System.SysUtils,
  Winapi.Windows,
  maxLogic.ioutils;

{$SCOPEDENUMS ON}

type
  TTestTempOutcome = (Removed, Missing, RetainedLive, RetainedKeep, Refused);
  TTestTempEntryKind = (Directory, RegularFile);
  TTestTempLivenessLog = (Quiet, LogReuse);
  // Which validated entry the replacement tests try to swap while cleanup holds it.
  TTestTempSwapTarget = (ParentDirectory, ValidatedFile);
  // Test-only observer; it runs after an entry is opened and validated, before deletion.
  TTestTempValidatedHook = reference to procedure(const aPath: string);

  TTestTempAttributeTagInfo = record
    FileAttributes: DWORD;
    ReparseTag: DWORD;
  end;

  TTestTempStandardInfo = record
    AllocationSize: Int64;
    EndOfFile: Int64;
    NumberOfLinks: DWORD;
    DeletePending: Boolean;
    Directory: Boolean;
  end;

  TTestTempDispositionInfoEx = record
    Flags: DWORD;
  end;

const
  // FILE_INFO_BY_HANDLE_CLASS values and flags from the Windows SDK (WinBase.h).
  cFileStandardInfo = 1;
  cFileAttributeTagInfo = 9;
  cFileDispositionInfoEx = 21;
  cFileDispositionFlagDelete = $00000001;
  cFileDispositionFlagPosixSemantics = $00000002;
  cFileDispositionFlagIgnoreReadOnly = $00000010;
  // WinBase.h values; the RTL marks its copies platform-specific and this unit is Windows-only.
  cFileFlagOpenReparsePoint = $00200000;
  cFileNameNormalized = $0;
  cVolumeNameDos = $0;
  cProcessQueryLimitedInformation = $1000;
  cTestTempKeepMarker = '.keep';
  cTestTempKeepVariable = 'DS_KEEP_TEST_TEMP';

function GetFileInformationByHandleEx(aFile: THandle; aInfoClass: Integer; aInfo: Pointer;
  aSize: DWORD): BOOL; stdcall; external kernel32 name 'GetFileInformationByHandleEx';
function SetFileInformationByHandle(aFile: THandle; aInfoClass: Integer; aInfo: Pointer;
  aSize: DWORD): BOOL; stdcall; external kernel32 name 'SetFileInformationByHandle';
function GetFinalPathNameByHandleW(aFile: THandle; aPath: PWideChar; aLength: DWORD;
  aFlags: DWORD): DWORD; stdcall; external kernel32 name 'GetFinalPathNameByHandleW';

var
  gEnvironmentLock: TCriticalSection;
  gTestTempRoots: TStringList;
  gTestTempBytesFreed: UInt64;
  gTestTempValidatedHook: TTestTempValidatedHook;

function TestTempBinRoot: string;
const
  cProjectId = 'e56126d2-2e3c-4730-a86e-d3b94f4febbe';
var
  lIdentity: string;
begin
  Result := TPath.GetFullPath(TPath.Combine(RepoRoot, 'tests\bin'));
  lIdentity := TPath.Combine(RepoRoot, '.tasks.json');
  // DS units are also consumed by other runners. Never sweep their checkout.
  if not TFile.Exists(lIdentity) then
    Exit('');
  if Pos(cProjectId, TFile.ReadAllText(lIdentity, TEncoding.UTF8)) = 0 then
    Exit('');
end;

function TestTempNativePath(const aPath: string): string;
begin
  if StartsStr('\\', aPath) then
    Result := '\\?\UNC\' + Copy(aPath, 3, MaxInt)
  else
    Result := '\\?\' + aPath;
end;

function TestTempEntries(const aPath: string): TArray<string>;
var
  i: Integer;
begin
  Result := TDirectory.GetFileSystemEntries(TestTempNativePath(aPath));
  for i := 0 to High(Result) do
    if StartsStr('\\?\UNC\', Result[i]) then
      Result[i] := '\\' + Copy(Result[i], 9, MaxInt)
    else
      Result[i] := Copy(Result[i], 5, MaxInt);
end;

procedure RaiseTestTempOSError(const aAction, aPath: string; const aError: DWORD);
var
  lError: EOSError;
begin
  lError := EOSError.CreateFmt('%s failed for %s: %s (code %d)',
    [aAction, aPath, SysErrorMessage(aError), aError]);
  lError.ErrorCode := aError;
  raise lError;
end;

procedure CheckTestTempPath(const aPath: string);
var
  lAttributes: DWORD;
  lPath: string;
begin
  lPath := TPath.GetFullPath(aPath);
  repeat
    lAttributes := GetFileAttributes(PChar(TestTempNativePath(lPath)));
    if lAttributes = INVALID_FILE_ATTRIBUTES then
      RaiseTestTempOSError('Query attributes', lPath, GetLastError);
    if (lAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
      raise Exception.CreateFmt('Refusing reparse point: %s', [lPath]);
    lPath := TPath.GetDirectoryName(ExcludeTrailingPathDelimiter(lPath));
  until lPath = '';
end;

function IsTestTempGuidText(const aText: string): Boolean;
begin
  // Braced GUIDToString shape: {8-4-4-4-12} hexadecimal groups.
  if (Length(aText) <> 38) or (aText[1] <> '{') or (aText[38] <> '}') then
    Exit(False);
  for var i := 2 to 37 do
    if (i = 10) or (i = 15) or (i = 20) or (i = 25) then
    begin
      if aText[i] <> '-' then
        Exit(False);
    end else if not CharInSet(aText[i], ['0'..'9', 'A'..'F', 'a'..'f']) then
      Exit(False);
  Result := True;
end;

function TestTempOwnerPid(const aRoot: string; out aPid: Cardinal): Boolean;
var
  lName, lPidText, lSuffix: string;
  lSeparator: Integer;
  c: Char;
begin
  aPid := 0;
  lName := ExtractFileName(aRoot);
  if not StartsStr('run-', lName) then
    Exit(False);
  lSeparator := Pos('-', lName, 5);
  if (lSeparator <= 5) or (lSeparator = Length(lName)) then
    Exit(False);
  lPidText := Copy(lName, 5, lSeparator - 5);
  for c in lPidText do
    if not CharInSet(c, ['0'..'9']) then
      Exit(False);
  // Owned roots are run-<PID>-<GUID>: braced from this helper, unbraced from earlier
  // allocators. A legacy run-<GUID> root has no PID, even when its first group is all digits.
  lSuffix := Copy(lName, lSeparator + 1, MaxInt);
  if Length(lSuffix) = 36 then
    lSuffix := '{' + lSuffix + '}';
  if not IsTestTempGuidText(lSuffix) then
    Exit(False);
  Result := TryStrToUInt(lPidText, aPid) and (aPid > 0);
end;

function TestTempOwnerMayBeAlive(const aRoot: string; const aPid: Cardinal;
  const aLog: TTestTempLivenessLog): Boolean;
var
  lCreation, lExit, lKernel, lUser: TFileTime;
  lHandle: THandle;
  lInfo: TWin32FileAttributeData;
begin
  // An access failure is not evidence that an owner is dead.
  lHandle := OpenProcess(cProcessQueryLimitedInformation or SYNCHRONIZE, False, aPid);
  if lHandle = 0 then
    Exit(GetLastError <> ERROR_INVALID_PARAMETER);
  try
    // Only a signaled process object proves exit; a failed wait is treated as alive.
    if WaitForSingleObject(lHandle, 0) = WAIT_OBJECT_0 then
      Exit(False);
    Result := True;
    // Even a reused live PID is protected. Compare creation times for diagnosis,
    // rather than allowing timestamp uncertainty to authorize deletion.
    if (aLog = TTestTempLivenessLog.LogReuse) and
      GetProcessTimes(lHandle, lCreation, lExit, lKernel, lUser) and
      GetFileAttributesEx(PChar(TestTempNativePath(aRoot)), GetFileExInfoStandard, @lInfo) then
      if CompareFileTime(lInfo.ftCreationTime, lCreation) < 0 then
        Writeln('[DS-698] retained root with reused/live PID: ', aRoot);
  finally
    CloseHandle(lHandle);
  end;
end;

procedure NotifyTestTempValidated(const aPath: string);
begin
  if Assigned(gTestTempValidatedHook) then
    gTestTempValidatedHook(aPath);
end;

function OpenTestTempEntry(const aPath: string; const aKind: TTestTempEntryKind): THandle;
var
  lAccess, lFlags: DWORD;
  lInfo: TTestTempAttributeTagInfo;
begin
  lAccess := _DELETE or FILE_READ_ATTRIBUTES or SYNCHRONIZE;
  lFlags := cFileFlagOpenReparsePoint;
  if aKind = TTestTempEntryKind.Directory then
  begin
    lAccess := lAccess or FILE_LIST_DIRECTORY;
    lFlags := lFlags or FILE_FLAG_BACKUP_SEMANTICS;
  end;
  // No FILE_SHARE_DELETE: while we hold this handle nobody can rename, replace or
  // delete the entry, and NTFS refuses to rename any directory above it.
  Result := CreateFile(PChar(TestTempNativePath(aPath)), lAccess, FILE_SHARE_READ or FILE_SHARE_WRITE,
    nil, OPEN_EXISTING, lFlags, 0);
  if Result = INVALID_HANDLE_VALUE then
    RaiseTestTempOSError('Open', aPath, GetLastError);
  try
    lInfo := Default(TTestTempAttributeTagInfo);
    if not GetFileInformationByHandleEx(Result, cFileAttributeTagInfo, @lInfo, SizeOf(lInfo)) then
      RaiseTestTempOSError('Query attributes', aPath, GetLastError);
    if (lInfo.FileAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
      raise Exception.CreateFmt('Refusing reparse point: %s', [aPath]);
    if ((lInfo.FileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0) <>
      (aKind = TTestTempEntryKind.Directory) then
      raise Exception.CreateFmt('Refusing entry whose type changed: %s', [aPath]);
  except
    CloseHandle(Result);
    raise;
  end;
end;

procedure CheckTestTempIdentity(const aHandle: THandle; const aPath: string);
var
  lFinalPath: string;
  lLength: DWORD;
begin
  // The handle must name the expected path through real directories, not a former link target.
  SetLength(lFinalPath, MAX_PATH);
  lLength := GetFinalPathNameByHandleW(aHandle, PChar(lFinalPath), Length(lFinalPath),
    cFileNameNormalized or cVolumeNameDos);
  if lLength >= DWORD(Length(lFinalPath)) then
  begin
    SetLength(lFinalPath, lLength);
    lLength := GetFinalPathNameByHandleW(aHandle, PChar(lFinalPath), Length(lFinalPath),
      cFileNameNormalized or cVolumeNameDos);
  end;
  if (lLength = 0) or (lLength >= DWORD(Length(lFinalPath))) then
    RaiseTestTempOSError('Resolve final path', aPath, GetLastError);
  SetLength(lFinalPath, lLength);
  if not SameText(lFinalPath, TestTempNativePath(aPath)) then
    raise Exception.CreateFmt('Refusing identity mismatch: %s resolves to %s', [aPath, lFinalPath]);
end;

procedure MarkTestTempDeleted(const aHandle: THandle; const aPath: string);
var
  lError: DWORD;
  lInfo: TTestTempDispositionInfoEx;
begin
  // Delete the exact object behind the validated handle; never re-resolve its path.
  lInfo.Flags := cFileDispositionFlagDelete or cFileDispositionFlagPosixSemantics or
    cFileDispositionFlagIgnoreReadOnly;
  if SetFileInformationByHandle(aHandle, cFileDispositionInfoEx, @lInfo, SizeOf(lInfo)) then
    Exit;
  lError := GetLastError;
  if (lError <> ERROR_INVALID_PARAMETER) and (lError <> ERROR_NOT_SUPPORTED) then
    RaiseTestTempOSError('Delete', aPath, lError);
  // Some file systems lack POSIX delete semantics; the name then goes when the handle closes.
  lInfo.Flags := cFileDispositionFlagDelete or cFileDispositionFlagIgnoreReadOnly;
  if not SetFileInformationByHandle(aHandle, cFileDispositionInfoEx, @lInfo, SizeOf(lInfo)) then
    RaiseTestTempOSError('Delete', aPath, GetLastError);
end;

procedure DeleteTestTempFile(const aPath: string; var aBytesFreed: UInt64);
var
  lHandle: THandle;
  lInfo: TTestTempStandardInfo;
begin
  lHandle := OpenTestTempEntry(aPath, TTestTempEntryKind.RegularFile);
  try
    lInfo := Default(TTestTempStandardInfo);
    if not GetFileInformationByHandleEx(lHandle, cFileStandardInfo, @lInfo, SizeOf(lInfo)) then
      RaiseTestTempOSError('Query size', aPath, GetLastError);
    NotifyTestTempValidated(aPath);
    MarkTestTempDeleted(lHandle, aPath);
    aBytesFreed := aBytesFreed + UInt64(lInfo.EndOfFile);
  finally
    CloseHandle(lHandle);
  end;
end;

procedure DeleteTestTempChildren(const aPath: string; var aBytesFreed: UInt64); forward;

procedure DeleteTestTempDirectory(const aPath: string; var aBytesFreed: UInt64);
var
  lHandle: THandle;
begin
  // The pinned handle stays open until its children are gone and it is marked deleted.
  lHandle := OpenTestTempEntry(aPath, TTestTempEntryKind.Directory);
  try
    NotifyTestTempValidated(aPath);
    DeleteTestTempChildren(aPath, aBytesFreed);
    MarkTestTempDeleted(lHandle, aPath);
  finally
    CloseHandle(lHandle);
  end;
end;

procedure DeleteTestTempChildren(const aPath: string; var aBytesFreed: UInt64);
var
  lAttributes: DWORD;
  lEntry: string;
begin
  // aPath and all its ancestors are pinned, so each child name resolves inside the tree.
  for lEntry in TestTempEntries(aPath) do
  begin
    lAttributes := GetFileAttributes(PChar(TestTempNativePath(lEntry)));
    if lAttributes = INVALID_FILE_ATTRIBUTES then
      RaiseTestTempOSError('Query attributes', lEntry, GetLastError);
    // The handle open revalidates the type and refuses any reparse point.
    if (lAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
      DeleteTestTempDirectory(lEntry, aBytesFreed)
    else
      DeleteTestTempFile(lEntry, aBytesFreed);
  end;
end;

procedure DeleteTestTempRootTree(const aRoot: string; var aBytesFreed: UInt64);
var
  lHandle: THandle;
begin
  lHandle := OpenTestTempEntry(aRoot, TTestTempEntryKind.Directory);
  try
    // Pinning the root also pins its ancestors, so rechecking them now is final.
    CheckTestTempPath(aRoot);
    CheckTestTempIdentity(lHandle, aRoot);
    NotifyTestTempValidated(aRoot);
    DeleteTestTempChildren(aRoot, aBytesFreed);
    MarkTestTempDeleted(lHandle, aRoot);
  finally
    CloseHandle(lHandle);
  end;
end;

procedure CheckTestTempTree(const aPath: string);
var
  lEntry: string;
begin
  CheckTestTempPath(aPath);
  if (GetFileAttributes(PChar(TestTempNativePath(aPath))) and FILE_ATTRIBUTE_DIRECTORY) = 0 then
    Exit;
  for lEntry in TestTempEntries(aPath) do
    CheckTestTempTree(lEntry);
end;

function RemoveTestTempRoot(const aRoot: string; const aOwnRoot: Boolean): TTestTempOutcome;
var
  lBin, lParent, lRoot: string;
  lBytesFreed: UInt64;
  lPid: Cardinal;
begin
  lBytesFreed := 0;
  try
    lBin := TestTempBinRoot;
    lRoot := TPath.GetFullPath(aRoot);
    lParent := TPath.GetDirectoryName(lRoot);
    if (lBin = '') or not SameText(TPath.GetDirectoryName(lParent), lBin) or
      not EndsStr('-temp', ExtractFileName(lParent)) or not TestTempOwnerPid(lRoot, lPid) then
      raise Exception.CreateFmt('Refusing temp root outside DS tests\bin\*-temp\run-<PID>-*: %s', [aRoot]);
    if not TDirectory.Exists(lRoot) then
      Exit(TTestTempOutcome.Missing);
    CheckTestTempPath(lRoot);
    if aOwnRoot then
    begin
      if (lPid <> GetCurrentProcessId) or (gTestTempRoots.IndexOf(lRoot) < 0) then
        raise Exception.CreateFmt('Refusing unregistered current-run root: %s', [lRoot]);
    end else begin
      if TFile.Exists(TPath.Combine(lRoot, cTestTempKeepMarker)) then
      begin
        Writeln('[DS-698] retained kept root (', cTestTempKeepMarker, ' marker): ', lRoot);
        Exit(TTestTempOutcome.RetainedKeep);
      end;
      if TestTempOwnerMayBeAlive(lRoot, lPid, TTestTempLivenessLog.LogReuse) then
        Exit(TTestTempOutcome.RetainedLive);
    end;
    CheckTestTempTree(lRoot);
    // Preflight can take time on legacy trees; a PID may have been reused.
    if not aOwnRoot and TestTempOwnerMayBeAlive(lRoot, lPid, TTestTempLivenessLog.Quiet) then
      Exit(TTestTempOutcome.RetainedLive);
    DeleteTestTempRootTree(lRoot, lBytesFreed);
    Writeln('[DS-698] removed ', lRoot, ' bytes=', lBytesFreed);
    Result := TTestTempOutcome.Removed;
  except
    on E: Exception do
    begin
      Writeln('[DS-698] cleanup failed for ', aRoot, ': ', E.ClassName, ': ', E.Message);
      Result := TTestTempOutcome.Refused;
    end;
  end;
  Inc(gTestTempBytesFreed, lBytesFreed);
end;

procedure SweepTestTempParent(const aParent: string);
var
  lRoot: string;
  lPid: Cardinal;
begin
  try
    CheckTestTempPath(aParent);
    for lRoot in TDirectory.GetDirectories(aParent) do
      if TestTempOwnerPid(lRoot, lPid) then
        RemoveTestTempRoot(lRoot, False);
  except
    on E: Exception do
      Writeln('[DS-698] startup sweep failed for ', aParent, ': ', E.ClassName, ': ', E.Message);
  end;
end;

procedure SweepTestTempRoots;
var
  lBin, lParent: string;
begin
  try
    lBin := TestTempBinRoot;
    if (lBin = '') or not TDirectory.Exists(lBin) then
      Exit;
    CheckTestTempPath(lBin);
    for lParent in TDirectory.GetDirectories(lBin, '*-temp', TSearchOption.soTopDirectoryOnly) do
      SweepTestTempParent(lParent);
  except
    on E: Exception do
      Writeln('[DS-698] startup sweep failed: ', E.ClassName, ': ', E.Message);
  end;
end;

function CreateTestTempRoot(const aFolderName: string): string;
begin
  if (ExtractFileName(aFolderName) <> aFolderName) or not EndsStr('-temp', aFolderName) then
    raise Exception.CreateFmt('Invalid test temp folder: %s', [aFolderName]);
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), aFolderName,
    'run-' + GetCurrentProcessId.ToString + '-' + GUIDToString(TGUID.NewGuid)]));
  gEnvironmentLock.Enter;
  try
    // Registration precedes creation so a partial allocation is cleaned too.
    gTestTempRoots.Add(Result);
    TDirectory.CreateDirectory(Result);
  finally
    gEnvironmentLock.Leave;
  end;
end;

procedure KeepTestTempRoot(const aRoot: string);
begin
  try
    if not TDirectory.Exists(aRoot) then
      Exit;
    // Later startup sweeps skip a marked root even after its owner PID has exited.
    TFile.WriteAllText(TPath.Combine(aRoot, cTestTempKeepMarker),
      cTestTempKeepVariable + '=1 kept this failed-run root; delete it manually.');
    Writeln('[DS-698] kept failed-run root: ', aRoot);
  except
    on E: Exception do
      Writeln('[DS-698] could not mark kept root ', aRoot, ': ', E.ClassName, ': ', E.Message);
  end;
end;

procedure CleanupOwnedTestTempRoots;
var
  lRoot: string;
begin
  // Failed runs retain fixtures only by explicit developer opt-in.
  if (System.ExitCode <> 0) and (GetEnvironmentVariable(cTestTempKeepVariable) = '1') then
  begin
    Writeln('[DS-698] retaining failed-run roots because ', cTestTempKeepVariable, '=1');
    for lRoot in gTestTempRoots do
      KeepTestTempRoot(lRoot);
  end else
    for lRoot in gTestTempRoots do
      RemoveTestTempRoot(lRoot, True);
  Writeln('[DS-698] reclaimed file bytes=', gTestTempBytesFreed);
end;

constructor TScopedSnapshotQueryContext.Create(const aSnapshot: TDelphiProjectSnapshot);
begin
  inherited Create;
  fContext := Default(TDelphiSemanticSymbolQueryContext);
  fContext.ProjectSnapshot := BorrowProjectSnapshot(aSnapshot);
end;

destructor TScopedSnapshotQueryContext.Destroy;
begin
  fContext.ProjectSnapshot := nil;
  inherited;
end;

function RepoRoot: string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)), '..\..'));
end;

function FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(TPath.Combine(RepoRoot, 'tests\fixtures'),
    aRelativePath));
end;

function FixturePath(const aFolder, aFileName: string): string;
begin
  Result := FixturePath(TPath.Combine(aFolder, aFileName));
end;

function RepoSourcePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(RepoRoot, aRelativePath));
end;

function ReadRepoSource(const aRelativePath: string): string;
begin
  Result := TFile.ReadAllText(RepoSourcePath(aRelativePath), TEncoding.UTF8);
end;

function TryReadEnvironmentVariable(const aName: string; out aValue: string): Boolean;
var
  lLength: DWORD;
  lValue: string;
begin
  SetLastError(ERROR_SUCCESS);
  lLength := Winapi.Windows.GetEnvironmentVariable(PChar(aName), nil, 0);
  if lLength = 0 then
  begin
    aValue := '';
    Result := GetLastError <> ERROR_ENVVAR_NOT_FOUND;
    Exit;
  end;
  if lLength = 1 then
  begin
    aValue := '';
    Result := True;
    Exit;
  end;

  SetLength(lValue, lLength - 1);
  if Winapi.Windows.GetEnvironmentVariable(PChar(aName), PChar(lValue), lLength) = 0 then
    RaiseLastOSError;
  aValue := lValue;
  Result := True;
end;

procedure SetEnvironmentVariableValue(const aName: string; const aValue: string;
  const aPresent: Boolean);
var
  lValue: PChar;
begin
  if aPresent then
    lValue := PChar(aValue)
  else
    lValue := nil;
  if not Winapi.Windows.SetEnvironmentVariable(PChar(aName), lValue) then
    RaiseLastOSError;
end;

constructor TScopedEnvironmentVariable.Create(const aName, aValue: string);
begin
  inherited Create;
  fLockHeld := False;
  fValueApplied := False;
  gEnvironmentLock.Enter;
  fLockHeld := True;
  try
    fName := aName;
    fHadPreviousValue := TryReadEnvironmentVariable(fName, fPreviousValue);
    SetEnvironmentVariableValue(fName, aValue, True);
    fValueApplied := True;
  except
    if fValueApplied then
      SetEnvironmentVariableValue(fName, fPreviousValue, fHadPreviousValue);
    if fLockHeld then
    begin
      fLockHeld := False;
      gEnvironmentLock.Leave;
    end;
    raise;
  end;
end;

destructor TScopedEnvironmentVariable.Destroy;
begin
  if fLockHeld then
  begin
    try
      if fValueApplied then
        SetEnvironmentVariableValue(fName, fPreviousValue, fHadPreviousValue);
    finally
      fValueApplied := False;
      fLockHeld := False;
      gEnvironmentLock.Leave;
    end;
  end;
  inherited;
end;

procedure WaitForTestThreads(const aThreads: array of TThread; const aTimeoutMs: Cardinal);
var
  lException: Exception;
  i: Integer;
  lDeadline: UInt64;
  lPending: Boolean;
  lTimedOut: Boolean;
begin
  lDeadline := GetTickCount64 + aTimeoutMs;
  repeat
    lPending := False;
    for i := Low(aThreads) to High(aThreads) do
      if Assigned(aThreads[i]) and
        (WaitForSingleObject(aThreads[i].Handle, 0) <> WAIT_OBJECT_0) then
      begin
        lPending := True;
        Break;
      end;

    if not lPending then
    begin
      for i := Low(aThreads) to High(aThreads) do
        if Assigned(aThreads[i]) and Assigned(aThreads[i].FatalException) then
        begin
          lException := Exception(aThreads[i].FatalException);
          Assert.Fail(Format('Worker thread failed with %s: %s', [lException.ClassName,
            lException.Message]));
        end;
      Exit;
    end;

    lTimedOut := GetTickCount64 >= lDeadline;
    if lTimedOut then
    begin
      for i := Low(aThreads) to High(aThreads) do
        if Assigned(aThreads[i]) and
          (WaitForSingleObject(aThreads[i].Handle, 0) <> WAIT_OBJECT_0) then
        begin
          // These are test-owned workers; terminate them so fixture cleanup cannot hang forever.
          aThreads[i].Terminate;
          TerminateThread(aThreads[i].Handle, 1);
        end;
      Assert.Fail(Format('Worker thread did not finish within %d ms', [aTimeoutMs]));
    end;

    Sleep(10);
  until False;
end;

procedure TSupportTests.WaitForTestThreadsReturnsForCompletedWorker;
var
  lThread: TThread;
begin
  lThread := TThread.CreateAnonymousThread(
    procedure
    begin
    end);
  try
    lThread.FreeOnTerminate := False;
    lThread.Start;
    WaitForTestThreads([lThread], 1000);
    Assert.AreEqual(Cardinal(WAIT_OBJECT_0), Cardinal(WaitForSingleObject(lThread.Handle, 0)),
      'completed worker should be signaled');
  finally
    lThread.Free;
  end;
end;

procedure TSupportTests.RepoPathHelpersResolveFixturesAndSource;
begin
  Assert.IsTrue(DirectoryExists(FixturePath('DependencyGraph')),
    'FixturePath should resolve under tests\fixtures.');
  Assert.IsTrue(FileExists(RepoSourcePath('src\DelphiSemantics.Api.pas')),
    'RepoSourcePath should resolve from the repository root.');
  Assert.IsTrue(ContainsText(ReadRepoSource('src\DelphiSemantics.Api.pas'),
    'unit DelphiSemantics.Api;'));
end;

procedure TSupportTests.SnapshotBackedQueryContextsUseScopedHelper;
var
  lDeadCodeSource: string;
  lDirectSnapshotBorrow: string;
  lDirectSnapshotClear: string;
  lHelperTypeName: string;
  lSupportSource: string;
  lSymbolQuerySource: string;
  lUsageSource: string;
begin
  lSupportSource := ReadRepoSource('tests\src\test.support.pas');
  lSymbolQuerySource := ReadRepoSource('tests\src\test.symbolquery.pas');
  lUsageSource := ReadRepoSource('tests\src\test.usage.pas');
  lDeadCodeSource := ReadRepoSource('tests\src\test.deadcode.pas');
  lDirectSnapshotBorrow := 'ProjectSnapshot := ' + 'BorrowProjectSnapshot';
  lDirectSnapshotClear := 'ProjectSnapshot := ' + 'nil';
  lHelperTypeName := 'TScoped' + 'SnapshotQueryContext = class';

  Assert.IsTrue(ContainsText(lSupportSource, lHelperTypeName),
    'Expected one shared scoped snapshot query-context helper.');
  Assert.IsFalse(ContainsText(lSymbolQuerySource, lDirectSnapshotBorrow),
    'SymbolQuery tests should use the shared snapshot context helper.');
  Assert.IsFalse(ContainsText(lUsageSource, lDirectSnapshotBorrow),
    'Usage tests should use the shared snapshot context helper.');
  Assert.IsFalse(ContainsText(lDeadCodeSource, lDirectSnapshotBorrow),
    'DeadCode tests should use the shared snapshot context helper.');
  Assert.IsFalse(ContainsText(lDeadCodeSource, lDirectSnapshotClear),
    'DeadCode tests should let the shared helper clear snapshot context state.');
end;

procedure TSupportTests.WaitForTestThreadsFailsTimedOutWorker;
var
  lRaised: Boolean;
  lThread: TThread;
begin
  lRaised := False;
  lThread := TThread.CreateAnonymousThread(
    procedure
    begin
      Sleep(5000);
    end);
  try
    lThread.FreeOnTerminate := False;
    lThread.Start;
    try
      WaitForTestThreads([lThread], 20);
    except
      on E: Exception do
      begin
        lRaised := SameText(E.ClassName, 'ETestFailure') and
          ContainsText(E.Message, 'Worker thread did not finish within');
      end;
    end;
    Assert.IsTrue(lRaised, 'timed-out worker should raise a DUnitX timeout failure');
  finally
    lThread.Free;
  end;
end;

procedure TSupportTests.WaitForTestThreadsFailsWorkerException;
var
  lRaised: Boolean;
  lThread: TThread;
begin
  lRaised := False;
  lThread := TThread.CreateAnonymousThread(
    procedure
    begin
      raise Exception.Create('worker failure');
    end);
  try
    lThread.FreeOnTerminate := False;
    lThread.Start;
    try
      WaitForTestThreads([lThread], 1000);
    except
      on E: Exception do
      begin
        lRaised := SameText(E.ClassName, 'ETestFailure') and ContainsText(E.Message,
          'Worker thread failed with Exception: worker failure');
      end;
    end;
    Assert.IsTrue(lRaised, 'worker exception should raise a DUnitX failure');
  finally
    lThread.Free;
  end;
end;

procedure TSupportTests.SnapshotTestsUseScopedEnvironmentHelper;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\src\test.snapshot.pas'));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lSourceText, 'Winapi.Windows.SetEnvironmentVariable'),
    'Snapshot tests must mutate environment variables through the scoped support helper.');
end;

procedure TSupportTests.ScopedEnvironmentRestoresMissingValue;
var
  lName: string;
  lScoped: TScopedEnvironmentVariable;
  lValue: string;
begin
  lName := 'DELPHI_SEMANTICS_TEST_SCOPED_ENV_MISSING_' + GUIDToString(TGUID.NewGuid);
  SetEnvironmentVariableValue(lName, '', False);
  Assert.IsFalse(TryReadEnvironmentVariable(lName, lValue));

  lScoped := TScopedEnvironmentVariable.Create(lName, 'temporary');
  try
    Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue));
    Assert.AreEqual('temporary', lValue);
  finally
    lScoped.Free;
  end;

  Assert.IsFalse(TryReadEnvironmentVariable(lName, lValue),
    'Missing environment values must be restored as missing, not empty.');
end;

procedure TSupportTests.ScopedEnvironmentRestoresEmptyValue;
var
  lName: string;
  lScoped: TScopedEnvironmentVariable;
  lValue: string;
begin
  lName := 'DELPHI_SEMANTICS_TEST_SCOPED_ENV_EMPTY_' + GUIDToString(TGUID.NewGuid);
  SetEnvironmentVariableValue(lName, '', True);
  try
    Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue));
    Assert.AreEqual('', lValue);

    lScoped := TScopedEnvironmentVariable.Create(lName, 'temporary');
    try
      Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue));
      Assert.AreEqual('temporary', lValue);
    finally
      lScoped.Free;
    end;

    Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue),
      'Existing empty environment values must stay present after restoration.');
    Assert.AreEqual('', lValue);
  finally
    SetEnvironmentVariableValue(lName, '', False);
  end;
end;

procedure TSupportTests.ScopedEnvironmentRestoresPreviousValue;
var
  lName: string;
  lScoped: TScopedEnvironmentVariable;
  lValue: string;
begin
  lName := 'DELPHI_SEMANTICS_TEST_SCOPED_ENV_PREVIOUS_' + GUIDToString(TGUID.NewGuid);
  SetEnvironmentVariableValue(lName, 'previous', True);
  try
    lScoped := TScopedEnvironmentVariable.Create(lName, 'temporary');
    try
      Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue));
      Assert.AreEqual('temporary', lValue);
    finally
      lScoped.Free;
    end;

    Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue));
    Assert.AreEqual('previous', lValue);
  finally
    SetEnvironmentVariableValue(lName, '', False);
  end;
end;

procedure TSupportTests.ScopedEnvironmentGuardsFullScopeWithLock;
var
  lLockVariableIndex: Integer;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\src\test.support.pas'));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  lLockVariableIndex := Pos('gEnvironmentLock: TCriticalSection', lSourceText);
  Assert.IsTrue(lLockVariableIndex > 0,
    'Environment helper must use one shared lock for process-wide mutation.');
  Assert.IsTrue(PosEx('gEnvironmentLock.Enter', lSourceText, lLockVariableIndex) > 0,
    'Environment helper must enter the shared lock before changing process state.');
  Assert.IsTrue(PosEx('gEnvironmentLock.Leave', lSourceText, lLockVariableIndex) > 0,
    'Environment helper must leave the shared lock after restoring process state.');
end;

procedure TSupportTests.ScopedEnvironmentSerializesOverlappingScopes;
var
  lAttemptingInnerScope: TEvent;
  lEnteredInnerScope: Integer;
  lName: string;
  lOuterScope: TScopedEnvironmentVariable;
  lThread: TThread;
  lValue: string;
begin
  lName := 'DELPHI_SEMANTICS_TEST_SCOPED_ENV_OVERLAP_' + GUIDToString(TGUID.NewGuid);
  SetEnvironmentVariableValue(lName, '', False);
  lEnteredInnerScope := 0;
  lAttemptingInnerScope := TEvent.Create(nil, True, False, '');
  try
    lOuterScope := TScopedEnvironmentVariable.Create(lName, 'outer');
    try
      lThread := TThread.CreateAnonymousThread(
        procedure
        var
          lInnerScope: TScopedEnvironmentVariable;
          lInnerValue: string;
        begin
          lAttemptingInnerScope.SetEvent;
          lInnerScope := TScopedEnvironmentVariable.Create(lName, 'inner');
          try
            TInterlocked.Exchange(lEnteredInnerScope, 1);
            Assert.IsTrue(TryReadEnvironmentVariable(lName, lInnerValue));
            Assert.AreEqual('inner', lInnerValue);
          finally
            lInnerScope.Free;
          end;
        end);
      try
        lThread.FreeOnTerminate := False;
        lThread.Start;
        Assert.AreEqual(wrSignaled, lAttemptingInnerScope.WaitFor(1000),
          'Worker must reach the inner environment scope attempt before the lock check.');
        Sleep(50);
        Assert.AreEqual(0, TInterlocked.CompareExchange(lEnteredInnerScope, 0, 0),
          'Overlapping environment scopes must wait until the outer scope restores.');
        Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue));
        Assert.AreEqual('outer', lValue);
        FreeAndNil(lOuterScope);
        WaitForTestThreads([lThread], 1000);
        Assert.AreEqual(1, TInterlocked.CompareExchange(lEnteredInnerScope, 0, 0),
          'Inner scope should run after the outer scope releases the environment lock.');
        Assert.IsFalse(TryReadEnvironmentVariable(lName, lValue));
      finally
        lThread.Free;
      end;
    finally
      lOuterScope.Free;
      SetEnvironmentVariableValue(lName, '', False);
    end;
  finally
    lAttemptingInnerScope.Free;
  end;
end;

procedure TSupportTests.ScopedEnvironmentConstructorFailureReleasesLock;
var
  lName: string;
  lRaised: Boolean;
  lScoped: TScopedEnvironmentVariable;
  lValue: string;
begin
  lRaised := False;
  try
    lScoped := TScopedEnvironmentVariable.Create('', 'temporary');
    lScoped.Free;
  except
    on E: EOSError do
      lRaised := True;
  end;
  Assert.IsTrue(lRaised, 'Invalid environment variable names must surface constructor failure.');

  lName := 'DELPHI_SEMANTICS_TEST_SCOPED_ENV_AFTER_FAILURE_' + GUIDToString(TGUID.NewGuid);
  SetEnvironmentVariableValue(lName, '', False);
  lScoped := TScopedEnvironmentVariable.Create(lName, 'temporary');
  try
    Assert.IsTrue(TryReadEnvironmentVariable(lName, lValue));
    Assert.AreEqual('temporary', lValue);
  finally
    lScoped.Free;
    SetEnvironmentVariableValue(lName, '', False);
  end;
end;

function StartHiddenTestProcess(const aArguments: string): TProcessInformation;
var
  lCommandLine, lShell: string;
  lStartup: TStartupInfo;
begin
  lShell := GetEnvironmentVariable('ComSpec');
  if lShell = '' then
    raise Exception.Create('ComSpec is not set; cannot start the test helper process.');
  lCommandLine := '"' + lShell + '" ' + aArguments;
  UniqueString(lCommandLine);
  lStartup := Default(TStartupInfo);
  lStartup.cb := SizeOf(lStartup);
  lStartup.dwFlags := STARTF_USESHOWWINDOW;
  lStartup.wShowWindow := SW_HIDE;
  Result := Default(TProcessInformation);
  if not CreateProcess(nil, PChar(lCommandLine), nil, nil, False, CREATE_NO_WINDOW, nil, nil,
    lStartup, Result) then
    RaiseLastOSError;
  CloseHandle(Result.hThread);
  Result.hThread := 0;
end;

procedure CreateTestJunction(const aLink, aTarget: string);
var
  lExitCode: DWORD;
  lProcess: TProcessInformation;
begin
  lProcess := StartHiddenTestProcess(Format('/c mklink /J "%s" "%s"', [aLink, aTarget]));
  try
    if WaitForSingleObject(lProcess.hProcess, 30000) <> WAIT_OBJECT_0 then
      raise Exception.CreateFmt('mklink did not finish for %s', [aLink]);
    if not GetExitCodeProcess(lProcess.hProcess, lExitCode) then
      RaiseLastOSError;
    if lExitCode <> 0 then
      raise Exception.CreateFmt('mklink /J failed with exit code %d for %s', [lExitCode, aLink]);
  finally
    CloseHandle(lProcess.hProcess);
  end;
end;

procedure RemoveTestJunction(const aLink: string);
var
  lAttributes: DWORD;
begin
  lAttributes := GetFileAttributes(PChar(aLink));
  if (lAttributes = INVALID_FILE_ATTRIBUTES) or ((lAttributes and FILE_ATTRIBUTE_REPARSE_POINT) = 0) then
    Exit;
  // RemoveDirectory on a junction removes only the link, never its target.
  if not Winapi.Windows.RemoveDirectory(PChar(aLink)) then
    RaiseTestTempOSError('Remove junction', aLink, GetLastError);
end;

procedure PlantTestTempRoot(const aRoot: string);
begin
  TDirectory.CreateDirectory(TPath.Combine(aRoot, 'nested'));
  TFile.WriteAllText(CombinePath([aRoot, 'nested', 'payload.txt']), 'payload');
end;

procedure RunTestTempSwapCase(const aSwap: TTestTempSwapTarget);
var
  lExternal, lMoved, lOutside, lRoot, lSentinel, lTarget, lTrigger, lVictim: string;
  lFired, lLinkMade, lSwapped: Boolean;
  lOutcome: TTestTempOutcome;
begin
  lRoot := CreateTestTempRoot('support-cleanup-temp');
  lOutside := CreateTestTempRoot('support-outside-temp');
  lExternal := TPath.Combine(lOutside, 'external');
  lSentinel := TPath.Combine(lExternal, 'target.txt');
  lVictim := TPath.Combine(lRoot, 'victim');
  lTarget := TPath.Combine(lVictim, 'target.txt');
  if aSwap = TTestTempSwapTarget.ParentDirectory then
  begin
    // Fire before any child is opened, so only the directory's own pin can block the swap.
    lTrigger := lVictim;
    lMoved := TPath.Combine(lRoot, 'victim-moved');
  end else begin
    lTrigger := lTarget;
    lMoved := TPath.Combine(lVictim, 'target-moved.txt');
  end;
  lFired := False;
  lLinkMade := False;
  lSwapped := False;
  lOutcome := TTestTempOutcome.Missing;
  try
    TDirectory.CreateDirectory(lExternal);
    TFile.WriteAllText(lSentinel, 'outside');
    TDirectory.CreateDirectory(lVictim);
    TFile.WriteAllText(lTarget, 'inside');
    // Once the trigger entry is validated, move it away and put a link to the outside in its place.
    gTestTempValidatedHook :=
      procedure(const aPath: string)
      begin
        if lFired or not SameText(aPath, lTrigger) then
          Exit;
        lFired := True;
        lSwapped := MoveFile(PChar(lTrigger), PChar(lMoved));
        if not lSwapped then
          Exit;
        if aSwap = TTestTempSwapTarget.ParentDirectory then
          CreateTestJunction(lVictim, lExternal)
        else if not CreateHardLink(PChar(lTarget), PChar(lSentinel), nil) then
          RaiseTestTempOSError('Create hard link', lTarget, GetLastError);
        lLinkMade := True;
      end;
    try
      lOutcome := RemoveTestTempRoot(lRoot, True);
    finally
      gTestTempValidatedHook := nil;
    end;

    Assert.IsTrue(lFired, 'The validated-entry hook must reach the trigger entry.');
    Assert.IsTrue((not lSwapped) or lLinkMade, 'A successful rename must be followed by the link.');
    Assert.IsTrue(TFile.Exists(lSentinel), 'Cleanup must never delete through a substituted link.');
    Assert.AreEqual('outside', TFile.ReadAllText(lSentinel), 'The outside sentinel must stay unchanged.');
    Assert.AreEqual(1, Integer(Length(TDirectory.GetFileSystemEntries(lExternal))),
      'Nothing may be added to or removed from the outside folder.');
    Assert.IsFalse(lSwapped, 'A validated entry must stay pinned against rename during cleanup.');
    Assert.IsTrue(lOutcome = TTestTempOutcome.Removed, 'The pinned tree should be removed completely.');
    Assert.IsFalse(TDirectory.Exists(lRoot), 'The cleaned root must be gone.');
  finally
    // Undo a junction substitution before any root cleanup can meet it.
    RemoveTestJunction(lVictim);
    RemoveTestTempRoot(lRoot, True);
    RemoveTestTempRoot(lOutside, True);
  end;
end;

procedure TTestTempCleanupTests.CleanupKeepsReplacedDirectoryOutsideRoot;
begin
  RunTestTempSwapCase(TTestTempSwapTarget.ParentDirectory);
end;

procedure TTestTempCleanupTests.CleanupKeepsReplacedFileOutsideRoot;
begin
  RunTestTempSwapCase(TTestTempSwapTarget.ValidatedFile);
end;

procedure TTestTempCleanupTests.OwnerPidRequiresPidAndGuidSuffix;
const
  cGuid = '2E39EBD0-0B41-4856-92C6-CBE253C4D01B';
var
  lPid: Cardinal;
begin
  Assert.IsTrue(TestTempOwnerPid('run-4242-{' + cGuid + '}', lPid), 'Current helper roots carry a PID.');
  Assert.AreEqual(Cardinal(4242), lPid);
  Assert.IsTrue(TestTempOwnerPid('run-4242-' + cGuid, lPid), 'Earlier allocators wrote unbraced GUIDs.');
  Assert.AreEqual(Cardinal(4242), lPid);
  Assert.IsFalse(TestTempOwnerPid('run-12345678-1234-1234-1234-123456789012', lPid),
    'A legacy run-<GUID> root must never be read as a PID owner.');
  Assert.IsFalse(TestTempOwnerPid('run-4242-scratch', lPid), 'The suffix must be a GUID.');
  Assert.IsFalse(TestTempOwnerPid('run-4242', lPid), 'A root without a suffix has no owner.');
end;

procedure TTestTempCleanupTests.SweepRemovesOnlyDeadUnkeptOwnerRoots;
var
  lDead, lKept, lLive, lParent: string;
  lProcess: TProcessInformation;
begin
  lDead := '';
  lKept := '';
  lLive := CreateTestTempRoot('support-sweep-temp');
  lParent := TPath.GetDirectoryName(lLive);
  lProcess := StartHiddenTestProcess('/c exit 0');
  try
    // Holding the exited process handle keeps its PID from being reused during the sweep.
    Assert.AreEqual(Cardinal(WAIT_OBJECT_0), Cardinal(WaitForSingleObject(lProcess.hProcess, 30000)),
      'The short-lived owner process must exit.');
    lDead := TPath.Combine(lParent, Format('run-%d-%s', [lProcess.dwProcessId,
      GUIDToString(TGUID.NewGuid)]));
    lKept := TPath.Combine(lParent, Format('run-%d-%s', [lProcess.dwProcessId,
      GUIDToString(TGUID.NewGuid)]));
    PlantTestTempRoot(lDead);
    PlantTestTempRoot(lKept);
    PlantTestTempRoot(lLive);
    TFile.WriteAllText(TPath.Combine(lKept, cTestTempKeepMarker), 'kept');

    SweepTestTempParent(lParent);

    Assert.IsFalse(TDirectory.Exists(lDead), 'A dead owner''s root must be swept.');
    Assert.IsTrue(TFile.Exists(CombinePath([lLive, 'nested', 'payload.txt'])),
      'A live owner''s root must survive the sweep.');
    Assert.IsTrue(TFile.Exists(CombinePath([lKept, 'nested', 'payload.txt'])),
      'A root marked as kept must survive the sweep.');
  finally
    if (lKept <> '') and TFile.Exists(TPath.Combine(lKept, cTestTempKeepMarker)) then
      TFile.Delete(TPath.Combine(lKept, cTestTempKeepMarker));
    if lKept <> '' then
      RemoveTestTempRoot(lKept, False);
    if lDead <> '' then
      RemoveTestTempRoot(lDead, False);
    CloseHandle(lProcess.hProcess);
    RemoveTestTempRoot(lLive, True);
  end;
end;

initialization
  gEnvironmentLock := TCriticalSection.Create;
  gTestTempRoots := TStringList.Create;
  SweepTestTempRoots;
  TDUnitX.RegisterTestFixture(TSupportTests);
  TDUnitX.RegisterTestFixture(TTestTempCleanupTests);

finalization
  CleanupOwnedTestTempRoots;
  gTestTempRoots.Free;
  gEnvironmentLock.Free;

end.
