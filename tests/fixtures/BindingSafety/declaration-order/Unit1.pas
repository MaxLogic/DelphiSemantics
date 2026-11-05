unit Unit1;
interface
type
  TFoo = record
    Count: Integer;
  end;
procedure Run;
implementation
procedure Run;
var
  lRec: TFoo;
type
  TFoo = record
    Other, Padding: Integer;
  end;
begin
  lRec.Count := 0;
  with lRec do Count := 7;
  Writeln(SizeOf(lRec), ':', lRec.Count);
end;
end.
