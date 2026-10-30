unit Unit1;
interface
uses TypesUnit, BaseHelp;
type TOwnHelp = class helper for TRec
  function AbsentCount: Integer;
end;
var Count: Integer;
procedure Run;
implementation
function TOwnHelp.AbsentCount: Integer;
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

  finally
    R.Free;
  end;
end;
end.
