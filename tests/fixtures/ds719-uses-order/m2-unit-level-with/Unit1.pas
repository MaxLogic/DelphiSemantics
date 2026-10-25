unit Unit1;
interface
uses A, DsrU719;
procedure Run;
implementation
var
  Item: TX;
  Extra: Integer;
procedure Run;
begin
  Writeln(SizeOf(Item), ' ', Extra);
end;
initialization
  Extra := 0;
  with Item do
  begin
    OnlyA := 1;
    Extra := 5;
  end;
end.
