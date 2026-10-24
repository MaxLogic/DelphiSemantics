unit Unit1;
interface
uses A, B, U, Unit3;
procedure Run;
implementation
procedure Run;
begin
  with Item do OnlyB := 5;
  Writeln(Item.OnlyB);
end;
end.
