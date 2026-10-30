unit Unit1;
interface
type
  TBase = class
  public
    function Count: Integer;
  end;
  TRec = class(TBase) end;
  THelp = class helper for TBase
    function AbsentCount: Integer;
  end;
procedure Run;
implementation
function TBase.Count: Integer;
begin
  Result := 11;
end;
function THelp.AbsentCount: Integer;
begin
  Result := 19;
end;
procedure Run;
var
  R: TRec;
begin
  R := TRec.Create;
  try
  with R do
  begin
    Writeln('WITH=', Count);
  end;
  Writeln('QUAL=', R.Count);
  finally
    R.Free;
  end;
end;
end.
