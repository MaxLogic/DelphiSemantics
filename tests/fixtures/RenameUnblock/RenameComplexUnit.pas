unit RenameComplexUnit;

interface

type
  TWorkerValue = Integer;

  TWorker = class
  private
    fStoredValue: TWorkerValue;
  public
    function ExecuteTask(aInput: TWorkerValue): TWorkerValue;
    class function BuildValue(aSeed: TWorkerValue): TWorkerValue;
  end;

var
  SharedCounter: Integer;

implementation

function TWorker.ExecuteTask(aInput: TWorkerValue): TWorkerValue;
var
  lCounter: Integer;
begin
  lCounter := aInput + SharedCounter;
  fStoredValue := lCounter;
  Result := lCounter;
end;

class function TWorker.BuildValue(aSeed: TWorkerValue): TWorkerValue;
begin
  Result := aSeed;
end;

procedure UseWorker;
var
  lWorker: TWorker;
  lCounter: Integer;
begin
  lCounter := SharedCounter;
  lWorker := TWorker.Create;
  try
    SharedCounter := lWorker.ExecuteTask(lCounter);
    SharedCounter := TWorker.BuildValue(SharedCounter);
  finally
    lWorker.Free;
  end;
end;

end.
