unit Unit1;
interface
uses A, B;
procedure Run;
implementation
var
  Extra: Integer;
  P: PX;
procedure Run;
begin
  Extra := 0;
  New(P);
  with P^ do
  begin
    OnlyA := 1;
    Extra := 5;
  end;

  Writeln(P^.OnlyA, ' ', Extra);
end;
end.
