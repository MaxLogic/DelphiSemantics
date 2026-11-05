unit Unit1;
interface
uses Unit2, System.Types;
procedure Run;
implementation
procedure Run;
begin
  with Item do X := 29;
  Writeln(Item.X, ':', Item.Padding);
end;
end.
