unit Unit1;
interface
uses TypesUnit, ChildHelp, BaseHelp;
var Count: Integer;
procedure Run;
implementation
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
