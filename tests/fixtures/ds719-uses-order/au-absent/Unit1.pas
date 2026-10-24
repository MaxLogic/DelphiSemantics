unit Unit1;
interface
uses A, U;
procedure Run;
implementation
var
  Item: TX;
  OnlyA: Integer;
procedure Run;
begin
  with Item do OnlyA := 5;
  Writeln(Item.OnlyA, ' ', OnlyA);
end;
end.
