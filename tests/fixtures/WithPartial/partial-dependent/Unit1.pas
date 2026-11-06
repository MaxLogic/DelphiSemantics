unit Unit1;
interface
uses System.SysUtils, BaseUnit;
type
 TOther = record B: Integer; end;
 TItem = class(TGeneric<Integer>)
  Other: TOther;
  const Count = 7;
 end;
var Item: TItem; Other: TOther; A, Count: Integer;
procedure Run;
implementation
procedure Work(var aOther: TOther);
begin
 with Item do begin A := Count; with aOther do B := 2; end;
end;
procedure Run;
begin
 Item := TItem.Create; Item.Other.B := 0; Other.B := 0; Count := 100; A := 0;
 Work(Other); Writeln(A, ' ', Item.Other.B, ' ', Other.B); Item.Free;
end;
end.
