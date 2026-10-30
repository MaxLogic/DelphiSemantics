unit Unit1;
interface
uses A, B;
procedure Run;
implementation
var
  Extra: Integer;
  Arr: TArr;
procedure Run;
begin
  Extra := 0;
  with Arr[1] do
  begin
    OnlyA := 1;
    Extra := 5;
  end;

  Writeln(Arr[1].OnlyA, ' ', Extra);
end;
end.
