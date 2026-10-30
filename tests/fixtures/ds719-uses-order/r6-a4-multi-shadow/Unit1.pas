unit Unit1;
interface
uses A, B;
procedure Run;
implementation
var
  Extra: Integer;
  O: TOuter;
  O2: TOuter;
procedure Run;
begin
  Extra := 0;
  with O2, O.Sub do
  begin
    OnlyA := 1;
    Extra := 5;
  end;

  Writeln(O.Sub.OnlyA, ' ', Extra);
end;
end.
