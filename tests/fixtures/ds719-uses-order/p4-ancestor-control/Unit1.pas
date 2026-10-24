unit Unit1;
interface
type TBase = class {$IF Declared(TBase)} Count: Integer; {$IFEND} end;
TRec = class(TBase) end;
var Rec: TRec;
implementation
end.
