unit Unit1;
interface
type
  TRec = record
  end;
  TS = type TRec;
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
  R: TS2;
begin
  Count := 23;
  R := Default(TS2);
  with R do
  begin
    Writeln('WITH=', Count);
  end;

end;
end.
