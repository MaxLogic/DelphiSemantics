unit Unit1;
interface
uses A, B;
procedure Run;
implementation
var
  Extra: Integer;
  H: THolder;
procedure Run;
begin
  Extra := 0;
  H := THolder.Create;
  with H.FSub do
  begin
    OnlyA := 1;
    Extra := 5;
  end;

  Writeln(H.FSub.OnlyA, ' ', Extra);
end;
end.
