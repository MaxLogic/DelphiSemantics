unit Unit1;
interface
uses A, B;
procedure Run;
implementation
var
  Item: TX;
  OnlyB: Integer;
procedure Run;
begin
  with Item do OnlyB := 5;
  Writeln(Item.OnlyB, ' ', OnlyB);
end;
end.
