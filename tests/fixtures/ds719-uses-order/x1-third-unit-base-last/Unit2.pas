unit Unit2;
interface
uses ControlUnit;
type TFoo = class(ControlUnit.TFoo) Extra: Integer; end;
var Obj: TFoo;
implementation
end.
