unit DelphiSemantics.Snapshot.Workers;

interface

uses
  System.Generics.Collections, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Snapshot;

type
  ESnapshotWorkerJoinTimeout = class(Exception)
  private
    fAbandonedWorkers: Boolean;
  public
    constructor Create(const aMessage: string; const aAbandonedWorkers: Boolean);
    property AbandonedWorkers: Boolean read fAbandonedWorkers;
  end;

  TSnapshotUnitBuildResult = record
    ExactStrings: TSemanticStringPool;
    Strings: TSemanticStringPool;
    UnitSnapshot: TUnitSnapshot;
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
  end;

  TSnapshotWorkerPipelineMetrics = record
    WorkerCount: Integer;
    QueueMilliseconds: Int64;
    ParseExtractMilliseconds: Int64;
  end;

  TSnapshotReferenceTargetMap = TDictionary<string, TSemanticSymbolRef>;

  TSnapshotReferenceTargetLookupItem = record
    Key: string;
    Ref: TSemanticSymbolRef;
  end;

  TSnapshotReferenceTargetLookup = record
  private
    fItems: TArray<TSnapshotReferenceTargetLookupItem>;
  public
    class function FromMap(const aTargets: TSnapshotReferenceTargetMap):
      TSnapshotReferenceTargetLookup; static;
    function TryGetValue(const aKey: string; out aRef: TSemanticSymbolRef): Boolean;
  end;

  TSnapshotUnitBuildCallback = function(
    const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
    const aReferenceTargetLookup: TSnapshotReferenceTargetLookup):
    TSnapshotUnitBuildResult;

function BuildSnapshotUnitResults(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  const aWorkerCount: Integer; const aBuildUnit: TSnapshotUnitBuildCallback;
  out aMetrics: TSnapshotWorkerPipelineMetrics): TArray<TSnapshotUnitBuildResult>;
procedure FreeSnapshotUnitBuildResults(var aResults: TArray<TSnapshotUnitBuildResult>);

implementation

uses
  System.Classes, System.Diagnostics, System.Generics.Defaults,
  Winapi.Windows,
  MaxLogic.StrUtils;

const
  cSnapshotWorkerCleanupTimeoutMs = 1000;
  cSnapshotWorkerJoinMaxTimeoutMs = 10 * 60 * 1000;
  cSnapshotWorkerJoinPollMs = 20;
  cSnapshotWorkerJoinTimeoutEnv =
    'DELPHI_SEMANTICS_SNAPSHOT_WORKER_JOIN_TIMEOUT_MS';
  cSnapshotWorkerJoinTimeoutMs = 5 * 60 * 1000;
  cSnapshotWorkerTestStallFileEnv =
    'DELPHI_SEMANTICS_TEST_SNAPSHOT_WORKER_STALL_FILE';
  cSnapshotWorkerTestStallMsEnv =
    'DELPHI_SEMANTICS_TEST_SNAPSHOT_WORKER_STALL_MS';
  cUnassignedWorkerModelIndex = -1;

var
  GSnapshotReferenceTargetKeyComparer: IComparer<string>;

function CompareSnapshotReferenceTargetLookupItems(
  const aLeft, aRight: TSnapshotReferenceTargetLookupItem): Integer;
begin
  Result := GSnapshotReferenceTargetKeyComparer.Compare(aLeft.Key, aRight.Key);
end;

class function TSnapshotReferenceTargetLookup.FromMap(
  const aTargets: TSnapshotReferenceTargetMap): TSnapshotReferenceTargetLookup;
var
  i: Integer;
  lPair: TPair<string, TSemanticSymbolRef>;
begin
  Result := Default(TSnapshotReferenceTargetLookup);
  if aTargets = nil then
    Exit;

  SetLength(Result.fItems, aTargets.Count);
  i := 0;
  for lPair in aTargets do
  begin
    Result.fItems[i].Key := lPair.Key;
    Result.fItems[i].Ref := lPair.Value;
    Inc(i);
  end;
  TArray.Sort<TSnapshotReferenceTargetLookupItem>(Result.fItems,
    TComparer<TSnapshotReferenceTargetLookupItem>.Construct(
      CompareSnapshotReferenceTargetLookupItems));
end;

function TSnapshotReferenceTargetLookup.TryGetValue(const aKey: string;
  out aRef: TSemanticSymbolRef): Boolean;
var
  lCompare: Integer;
  lHigh: Integer;
  lLow: Integer;
  lMid: Integer;
begin
  aRef := Default(TSemanticSymbolRef);
  lLow := 0;
  lHigh := High(fItems);
  while lLow <= lHigh do
  begin
    lMid := lLow + ((lHigh - lLow) div 2);
    lCompare := GSnapshotReferenceTargetKeyComparer.Compare(aKey,
      fItems[lMid].Key);
    if lCompare = 0 then
    begin
      aRef := fItems[lMid].Ref;
      Exit(True);
    end;
    if lCompare < 0 then
      lHigh := lMid - 1
    else
      lLow := lMid + 1;
  end;
  Result := False;
end;

type
  TSnapshotBuildWorkerContext = class
  private
    fBuildUnit: TSnapshotUnitBuildCallback;
    fCancelRequested: Boolean;
    fLock: TObject;
    fNextIndex: Integer;
    fReferenceTargetLookup: TSnapshotReferenceTargetLookup;
    fUnitModels: TArray<TDelphiSemanticUnitModel>;
    fWorkerFileNames: TArray<string>;
    fWorkerModelIndexes: TArray<Integer>;
  public
    Results: TArray<TSnapshotUnitBuildResult>;
    procedure ClearWorkerState(const aWorkerIndex: Integer);
    procedure ConfigureWorkerCount(const aWorkerCount: Integer);
    constructor Create(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
      const aBuildUnit: TSnapshotUnitBuildCallback);
    destructor Destroy; override;
    function BuildUnit(const aModel: TDelphiSemanticUnitModel;
      const aUnitId: TSemanticUnitId): TSnapshotUnitBuildResult;
    procedure RequestCancel;
    procedure SetWorkerState(const aWorkerIndex, aModelIndex: Integer);
    function UnitModelByIndex(const aIndex: Integer): TDelphiSemanticUnitModel;
    function TryTakeNextIndex(out aIndex: Integer): Boolean;
    function WorkerDescription(const aWorkerIndex: Integer): string;
  end;

  TSnapshotBuildWorkerThread = class(TThread)
  private
    fContext: TSnapshotBuildWorkerContext;
    fWorkerIndex: Integer;
  protected
    procedure Execute; override;
  public
    constructor Create(const aContext: TSnapshotBuildWorkerContext;
      const aWorkerIndex: Integer);
  end;

function EffectiveWorkerCount(const aRequestedWorkerCount, aUnitCount: Integer):
  Integer;
begin
  if aUnitCount <= 0 then
    Exit(0);

  Result := aRequestedWorkerCount;
  if Result <= 0 then
    Result := TThread.ProcessorCount;
  if Result < 1 then
    Result := 1;
  if Result > aUnitCount then
    Result := aUnitCount;
end;

procedure FreeSnapshotUnitBuildResults(var aResults: TArray<TSnapshotUnitBuildResult>);
var
  i: Integer;
begin
  for i := 0 to High(aResults) do
  begin
    aResults[i].UnitSnapshot.Free;
    aResults[i].UnitSnapshot := nil;
    aResults[i].ExactStrings.Free;
    aResults[i].ExactStrings := nil;
    aResults[i].Strings.Free;
    aResults[i].Strings := nil;
  end;
end;

procedure RaiseThreadException(const aThread: TThread);
var
  lException: TObject;
begin
  lException := aThread.FatalException;
  if lException = nil then
    Exit;

  if lException is Exception then
    raise Exception.Create(Exception(lException).Message);

  raise Exception.Create(lException.ClassName);
end;

function SnapshotWorkerJoinTimeoutMs: Cardinal;
var
  lText: string;
  lValue: Integer;
begin
  Result := cSnapshotWorkerJoinTimeoutMs;
  lText := Trim(GetEnvironmentVariable(cSnapshotWorkerJoinTimeoutEnv));
  if lText = '' then
    Exit;

  if TryStrToInt(lText, lValue) and (lValue > 0) then
  begin
    if lValue > cSnapshotWorkerJoinMaxTimeoutMs then
      Result := cSnapshotWorkerJoinMaxTimeoutMs
    else
      Result := Cardinal(lValue);
  end;
end;

function ThreadFinished(const aThread: TThread): Boolean;
begin
  Result := WaitForSingleObject(aThread.Handle, 0) = WAIT_OBJECT_0;
end;

function TryJoinSnapshotWorkers(
  const aThreads: TArray<TSnapshotBuildWorkerThread>;
  const aStartedCount: Integer; const aTimeoutMs: Cardinal;
  out aUnfinishedWorkerIndex: Integer): Boolean;
var
  i: Integer;
  lAllFinished: Boolean;
  lStopwatch: TStopwatch;
begin
  Result := False;
  aUnfinishedWorkerIndex := -1;
  lStopwatch := TStopwatch.StartNew;
  while True do
  begin
    lAllFinished := True;
    for i := 0 to aStartedCount - 1 do
    begin
      if not ThreadFinished(aThreads[i]) then
      begin
        lAllFinished := False;
        aUnfinishedWorkerIndex := i;
        Break;
      end;
    end;
    if lAllFinished then
      Exit(True);

    if lStopwatch.ElapsedMilliseconds >= aTimeoutMs then
      Exit(False);

    Sleep(cSnapshotWorkerJoinPollMs);
  end;
end;

constructor ESnapshotWorkerJoinTimeout.Create(const aMessage: string;
  const aAbandonedWorkers: Boolean);
begin
  inherited Create(aMessage);
  fAbandonedWorkers := aAbandonedWorkers;
end;

procedure TerminateSnapshotWorkers(
  const aThreads: TArray<TSnapshotBuildWorkerThread>;
  const aStartedCount: Integer);
var
  i: Integer;
begin
  for i := 0 to aStartedCount - 1 do
    aThreads[i].Terminate;
end;

procedure RaiseSnapshotWorkerJoinTimeout(
  const aThreads: TArray<TSnapshotBuildWorkerThread>;
  const aStartedCount: Integer; const aContext: TSnapshotBuildWorkerContext;
  const aTimeoutMs: Cardinal; const aUnfinishedWorkerIndex: Integer;
  out aAbandonedWorkers: Boolean);
var
  lCleanupUnfinishedWorkerIndex: Integer;
  lDescription: string;
begin
  lDescription := aContext.WorkerDescription(aUnfinishedWorkerIndex);
  aContext.RequestCancel;
  TerminateSnapshotWorkers(aThreads, aStartedCount);
  aAbandonedWorkers := not TryJoinSnapshotWorkers(aThreads, aStartedCount,
    cSnapshotWorkerCleanupTimeoutMs, lCleanupUnfinishedWorkerIndex);
  raise ESnapshotWorkerJoinTimeout.Create(Format(
    'Snapshot worker join timed out after %d ms: %s',
    [aTimeoutMs, lDescription]), aAbandonedWorkers);
end;

procedure StallSnapshotWorkerForTest(const aFileName: string);
var
  lStallFileName: string;
  lStallMs: Integer;
  lStallText: string;
begin
  // Environment-gated so our timeout regression needs no public API test hook.
  lStallFileName := GetEnvironmentVariable(cSnapshotWorkerTestStallFileEnv);
  if (lStallFileName = '') or not SameText(lStallFileName, aFileName) then
    Exit;

  lStallText := Trim(GetEnvironmentVariable(cSnapshotWorkerTestStallMsEnv));
  if not TryStrToInt(lStallText, lStallMs) or (lStallMs <= 0) then
    Exit;

  Sleep(lStallMs);
end;

procedure TSnapshotBuildWorkerContext.ClearWorkerState(
  const aWorkerIndex: Integer);
begin
  TMonitor.Enter(fLock);
  try
    if (aWorkerIndex >= 0) and (aWorkerIndex <= High(fWorkerModelIndexes)) then
    begin
      fWorkerModelIndexes[aWorkerIndex] := cUnassignedWorkerModelIndex;
      fWorkerFileNames[aWorkerIndex] := '';
    end;
  finally
    TMonitor.Exit(fLock);
  end;
end;

procedure TSnapshotBuildWorkerContext.ConfigureWorkerCount(
  const aWorkerCount: Integer);
var
  i: Integer;
begin
  TMonitor.Enter(fLock);
  try
    SetLength(fWorkerModelIndexes, aWorkerCount);
    SetLength(fWorkerFileNames, aWorkerCount);
    for i := 0 to High(fWorkerModelIndexes) do
      fWorkerModelIndexes[i] := cUnassignedWorkerModelIndex;
  finally
    TMonitor.Exit(fLock);
  end;
end;

constructor TSnapshotBuildWorkerContext.Create(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  const aBuildUnit: TSnapshotUnitBuildCallback);
begin
  inherited Create;
  fBuildUnit := aBuildUnit;
  fLock := TObject.Create;
  fNextIndex := 0;
  fReferenceTargetLookup := aReferenceTargetLookup;
  fUnitModels := Copy(aModels);
  SetLength(Results, Length(aModels));
end;

destructor TSnapshotBuildWorkerContext.Destroy;
begin
  fLock.Free;
  inherited;
end;

function TSnapshotBuildWorkerContext.BuildUnit(
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId):
  TSnapshotUnitBuildResult;
begin
  Result := fBuildUnit(aModel, aUnitId, fReferenceTargetLookup);
end;

procedure TSnapshotBuildWorkerContext.RequestCancel;
begin
  TMonitor.Enter(fLock);
  try
    fCancelRequested := True;
  finally
    TMonitor.Exit(fLock);
  end;
end;

procedure TSnapshotBuildWorkerContext.SetWorkerState(
  const aWorkerIndex, aModelIndex: Integer);
begin
  TMonitor.Enter(fLock);
  try
    if (aWorkerIndex >= 0) and (aWorkerIndex <= High(fWorkerModelIndexes)) then
    begin
      fWorkerModelIndexes[aWorkerIndex] := aModelIndex;
      if (aModelIndex >= 0) and (aModelIndex <= High(fUnitModels)) then
        fWorkerFileNames[aWorkerIndex] := fUnitModels[aModelIndex].FileName
      else
        fWorkerFileNames[aWorkerIndex] := '';
    end;
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TSnapshotBuildWorkerContext.TryTakeNextIndex(out aIndex: Integer):
  Boolean;
begin
  TMonitor.Enter(fLock);
  try
    if fCancelRequested then
      Exit(False);

    Result := fNextIndex <= High(fUnitModels);
    if not Result then
      Exit;

    aIndex := fNextIndex;
    Inc(fNextIndex);
  finally
    TMonitor.Exit(fLock);
  end;
end;

function TSnapshotBuildWorkerContext.UnitModelByIndex(
  const aIndex: Integer): TDelphiSemanticUnitModel;
begin
  Result := fUnitModels[aIndex];
end;

function TSnapshotBuildWorkerContext.WorkerDescription(
  const aWorkerIndex: Integer): string;
var
  lFileName: string;
  lModelIndex: Integer;
begin
  TMonitor.Enter(fLock);
  try
    if (aWorkerIndex < 0) or (aWorkerIndex > High(fWorkerModelIndexes)) then
      Exit(Format('Snapshot worker %d has no state.', [aWorkerIndex]));

    lModelIndex := fWorkerModelIndexes[aWorkerIndex];
    lFileName := fWorkerFileNames[aWorkerIndex];
  finally
    TMonitor.Exit(fLock);
  end;

  if lFileName = '' then
    lFileName := '<idle or starting>';
  Result := Format('Snapshot worker %d source file %s model index %d.',
    [aWorkerIndex, lFileName, lModelIndex]);
end;

constructor TSnapshotBuildWorkerThread.Create(
  const aContext: TSnapshotBuildWorkerContext; const aWorkerIndex: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  fContext := aContext;
  fWorkerIndex := aWorkerIndex;
end;

procedure TSnapshotBuildWorkerThread.Execute;
var
  lIndex: Integer;
  lModel: TDelphiSemanticUnitModel;
begin
  while (not Terminated) and fContext.TryTakeNextIndex(lIndex) do
  begin
    lModel := fContext.UnitModelByIndex(lIndex);
    fContext.SetWorkerState(fWorkerIndex, lIndex);
    try
      StallSnapshotWorkerForTest(lModel.FileName);
      fContext.Results[lIndex] := fContext.BuildUnit(lModel,
        TSemanticUnitId(lIndex + 1));
    finally
      fContext.ClearWorkerState(fWorkerIndex);
    end;
  end;
end;

function BuildSnapshotUnitResults(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  const aWorkerCount: Integer; const aBuildUnit: TSnapshotUnitBuildCallback;
  out aMetrics: TSnapshotWorkerPipelineMetrics): TArray<TSnapshotUnitBuildResult>;
var
  i: Integer;
  lAbandonedWorkers: Boolean;
  lContext: TSnapshotBuildWorkerContext;
  lCreatedCount: Integer;
  lJoinTimeoutMs: Cardinal;
  lQueueStopwatch: TStopwatch;
  lStartedCount: Integer;
  lThreads: TArray<TSnapshotBuildWorkerThread>;
  lThreadsJoined: Boolean;
  lUnfinishedWorkerIndex: Integer;
  lWorkerStopwatch: TStopwatch;
begin
  aMetrics := Default(TSnapshotWorkerPipelineMetrics);
  SetLength(Result, Length(aModels));
  aMetrics.WorkerCount := EffectiveWorkerCount(aWorkerCount, Length(aModels));
  if Length(aModels) = 0 then
    Exit;

  if aMetrics.WorkerCount <= 1 then
  begin
    lWorkerStopwatch := TStopwatch.StartNew;
    try
      for i := 0 to High(aModels) do
        Result[i] := aBuildUnit(aModels[i], TSemanticUnitId(i + 1),
          aReferenceTargetLookup);
    finally
      lWorkerStopwatch.Stop;
      aMetrics.ParseExtractMilliseconds := lWorkerStopwatch.ElapsedMilliseconds;
    end;
    Exit;
  end;

  lAbandonedWorkers := False;
  lContext := TSnapshotBuildWorkerContext.Create(aModels,
    aReferenceTargetLookup, aBuildUnit);
  try
    try
      lCreatedCount := 0;
      lStartedCount := 0;
      lThreadsJoined := False;
      try
        lQueueStopwatch := TStopwatch.StartNew;
        try
          SetLength(lThreads, aMetrics.WorkerCount);
          lContext.ConfigureWorkerCount(aMetrics.WorkerCount);
          for i := 0 to High(lThreads) do
          begin
            lThreads[i] := TSnapshotBuildWorkerThread.Create(lContext, i);
            Inc(lCreatedCount);
          end;
          for i := 0 to lCreatedCount - 1 do
          begin
            lThreads[i].Start;
            Inc(lStartedCount);
          end;
        finally
          lQueueStopwatch.Stop;
          aMetrics.QueueMilliseconds := lQueueStopwatch.ElapsedMilliseconds;
        end;

        lWorkerStopwatch := TStopwatch.StartNew;
        try
          lJoinTimeoutMs := SnapshotWorkerJoinTimeoutMs;
          if not TryJoinSnapshotWorkers(lThreads, lStartedCount, lJoinTimeoutMs,
            lUnfinishedWorkerIndex) then
            RaiseSnapshotWorkerJoinTimeout(lThreads, lStartedCount, lContext,
              lJoinTimeoutMs, lUnfinishedWorkerIndex, lAbandonedWorkers);
          lThreadsJoined := True;
          for i := 0 to lStartedCount - 1 do
            RaiseThreadException(lThreads[i]);
        finally
          lWorkerStopwatch.Stop;
          aMetrics.ParseExtractMilliseconds := lWorkerStopwatch.ElapsedMilliseconds;
        end;

        Result := lContext.Results;
        SetLength(lContext.Results, 0);
      finally
        if not lThreadsJoined then
        begin
          if not lAbandonedWorkers then
          begin
            lContext.RequestCancel;
            TerminateSnapshotWorkers(lThreads, lStartedCount);
            lAbandonedWorkers := not TryJoinSnapshotWorkers(lThreads,
              lStartedCount, cSnapshotWorkerCleanupTimeoutMs,
              lUnfinishedWorkerIndex);
          end;
        end;
        // On timeout we leave ownership alive because a stuck worker can still read the context.
        if not lAbandonedWorkers then
        begin
          for i := 0 to lCreatedCount - 1 do
            lThreads[i].Free;
        end;
      end;
    except
      on E: Exception do
      begin
        if not lAbandonedWorkers then
          FreeSnapshotUnitBuildResults(lContext.Results)
        else if not (E is ESnapshotWorkerJoinTimeout) then
          raise ESnapshotWorkerJoinTimeout.Create(Format(
            'Snapshot workers were abandoned while handling %s: %s',
            [E.ClassName, E.Message]), True);
        raise;
      end;
    else
      begin
        if not lAbandonedWorkers then
          FreeSnapshotUnitBuildResults(lContext.Results)
        else
          raise ESnapshotWorkerJoinTimeout.Create(
            'Snapshot workers were abandoned while handling a non-Exception failure.',
            True);
        raise;
      end;
    end;
  finally
    if not lAbandonedWorkers then
      lContext.Free;
  end;
end;

initialization
  GSnapshotReferenceTargetKeyComparer := TStringComparer.OrdinalIgnoreCase;

finalization
  GSnapshotReferenceTargetKeyComparer := nil;

end.
