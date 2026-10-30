unit Unit1;
interface
type
  TBase = class
  public
  end;
  TRec = class(TBase) end;
  THelp = class helper for TBase
    function Count: Integer;
  end;
var Count: Integer;
procedure Run;
implementation
function THelp.Count: Integer;
begin
  Result := 19;
end;
procedure Run;
var
  R: TRec;
begin
  Count := 23;
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
