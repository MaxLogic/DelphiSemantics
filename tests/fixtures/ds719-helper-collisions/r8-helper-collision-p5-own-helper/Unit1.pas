unit Unit1;
interface
uses TypesUnit, BaseHelp;
type TOwnHelp = class helper for TRec
  function Count: Integer;
end;
var Count: Integer;
procedure Run;
implementation
function TOwnHelp.Count: Integer;
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
