unit Unit1;
interface
uses DataUnit, HelperUnit;
procedure Run;
implementation
procedure Run;
var
  lRec: TRec;
  lCount: Integer;
begin
  lCount := 13;
  lRec.Value := 2;
  with lRec do Value := lCount;
  Writeln(lRec.Value, ':', lCount);
end;
end.
