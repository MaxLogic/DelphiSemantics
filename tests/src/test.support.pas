unit Test.Support;

interface

uses
  System.Classes, DUnitX.TestFramework;

procedure WaitForTestThreads(const aThreads: array of TThread; const aTimeoutMs: Cardinal);

type
  [TestFixture]
  TSupportTests = class
  public
    [Test]
    procedure WaitForTestThreadsReturnsForCompletedWorker;
    [Test]
    procedure WaitForTestThreadsFailsTimedOutWorker;
    [Test]
    procedure WaitForTestThreadsFailsWorkerException;
  end;

implementation

uses
  System.StrUtils, System.SysUtils, Winapi.Windows;

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

initialization
  TDUnitX.RegisterTestFixture(TSupportTests);

end.
