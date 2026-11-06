unit Unit1;
interface
uses System.SysUtils;
type
  TFoo = record X, B: Integer; end;
  TItem = record
    var A: Integer;
    var Other: TFoo;
    const Count = 7;
  end;
  TAlias = TItem;
  TOther = record B: Integer; end;
var
  Item: TAlias;
  Other: TOther;
  A: Integer; Count: Integer;
procedure Run;
implementation
procedure Run;
begin
  Item.A := 0; Item.Other.X := 0; Item.Other.B := 0; Other.B := 0; Count := 100;
  with Item do begin Writeln(Count); with Other do B := 2; end;
  Writeln(Item.Other.X, ' ', Item.Other.B, ' ', Other.B);
end;
end.
