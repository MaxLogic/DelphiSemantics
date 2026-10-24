unit Unit1;
interface
uses Unit2, ControlUnit;
type
 TDummy = Integer;
var G: Integer = 0;
procedure Run;
implementation
procedure Run;
begin
  Obj := Unit2.TFoo.Create; Obj.Count := 5;
  with Obj do Extra := Count + 1;
  Writeln(Obj.Extra);
end;
end.
