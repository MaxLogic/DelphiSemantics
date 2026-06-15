unit Test.Support;

interface

uses
  System.Classes, DUnitX.TestFramework;

function RepoRoot: string;
function FixturePath(const aRelativePath: string): string; overload;
function FixturePath(const aFolder, aFileName: string): string; overload;
function RepoSourcePath(const aRelativePath: string): string;
function ReadRepoSource(const aRelativePath: string): string;
procedure WaitForTestThreads(const aThreads: array of TThread; const aTimeoutMs: Cardinal);

type
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
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SyncObjs, System.SysUtils,
  Winapi.Windows;

var
  gEnvironmentLock: TCriticalSection;

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

initialization
  gEnvironmentLock := TCriticalSection.Create;
  TDUnitX.RegisterTestFixture(TSupportTests);

finalization
  gEnvironmentLock.Free;

end.
