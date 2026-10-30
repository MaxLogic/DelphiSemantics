unit Unit1;
interface
type
  TRec = class
  public
    Count: Integer;
  end;
  THelp = class helper for TRec
    function GetCount: Integer;
    property Count: Integer read GetCount;
  end;
procedure Run;
implementation
function THelp.GetCount: Integer;
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
