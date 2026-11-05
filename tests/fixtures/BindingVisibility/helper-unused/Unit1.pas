unit Unit1;
interface
uses Unit2;
procedure Run;
implementation
function Foo: Integer;
begin Result := 17; end;
procedure Run;
var lRecord: TRec;
begin
  lRecord.Other := 0;
  with lRecord do Other := Foo;
  Writeln(lRecord.Other);
end;
end.
