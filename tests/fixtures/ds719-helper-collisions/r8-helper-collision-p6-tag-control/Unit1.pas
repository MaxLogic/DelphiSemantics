unit Unit1;
interface
type
  TRec = record
    case Count: Integer of
      0: (Value: Integer);
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
