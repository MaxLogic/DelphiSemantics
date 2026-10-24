unit Unit1;
interface
uses ControlUnit;
type
 TFoo = class(ControlUnit.TFoo) end;
var Arr: array[0..0] of TFoo;
procedure Run;
implementation
procedure Run;
begin
  Arr[0] := TFoo.Create; Arr[0].Count := 5;
  with Arr[0] do Count := Count + 1;
  Writeln(Arr[0].Count);
end;
end.
