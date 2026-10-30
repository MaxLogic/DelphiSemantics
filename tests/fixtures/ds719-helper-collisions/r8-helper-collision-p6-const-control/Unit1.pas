unit Unit1;
interface
type
  TRec = record
    const Count = 11;
  end;
  THelp = record helper for TRec
    function AbsentCount: Integer;
  end;
procedure Run;
implementation
function THelp.AbsentCount: Integer;
begin
  Result := 19;
end;
procedure Run;
var
  R: TRec;
begin
  R := Default(TRec);
  with R do
  begin
    Writeln('WITH=', Count);
  end;
  Writeln('QUAL=', R.Count);
end;
end.
