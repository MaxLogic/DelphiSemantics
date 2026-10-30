unit Unit1;
interface
type
  TRec = record
  end;
  TS = TRec;
  TS2 = TS;
  THelp = record helper for TS2
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
  R: TS2;
begin
  Count := 23;
  R := Default(TS2);
  with R do
  begin
    Writeln('WITH=', Count);
  end;
  Writeln('QUAL=', R.Count);
end;
end.
