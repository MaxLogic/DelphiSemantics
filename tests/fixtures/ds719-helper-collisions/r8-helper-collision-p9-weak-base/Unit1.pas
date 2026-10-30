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
  R: TRec;
begin
  Count := 23;
  R := Default(TRec);
  with R do
  begin
    Writeln('WITH=', Count);
  end;
  Writeln('QUAL=', R.Count);
end;
end.
