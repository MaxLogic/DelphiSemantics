unit Unit1;
interface
type
  TRec = record
  end;
  TS = TRec;
  TS2 = TS;
  THelp = record helper for TS2
    function AbsentCount: Integer;
  end;
var Count: Integer;
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
  Count := 23;
  R := Default(TRec);
  with R do
  begin
    Writeln('WITH=', Count);
  end;

end;
end.
