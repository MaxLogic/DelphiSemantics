unit Unit1;
interface
uses ControlUnit;
type
 TFoo = class(ControlUnit.TFoo) end;
var Ptr: ^TFoo; Obj: TFoo;
procedure Run;
implementation
procedure Run;
begin
  Obj := TFoo.Create; Obj.Count := 5; Ptr := @Obj;
  with Ptr^ do Count := Count + 1;
  Writeln(Obj.Count);
end;
end.
