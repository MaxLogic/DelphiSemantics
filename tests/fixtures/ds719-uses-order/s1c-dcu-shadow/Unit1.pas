unit Unit1;
interface
uses A, U;
procedure Run;
implementation
var
  Item: TX;
  Extra: Integer;
procedure Run;
begin
  Extra := 0;
  with Item do
  begin
    OnlyA := 1;
    Extra := 5;
  end;
  Writeln(SizeOf(Item), ' ', Extra);
end;
end.
