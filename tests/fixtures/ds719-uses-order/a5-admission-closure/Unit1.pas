unit Unit1;
interface
uses A, DsrU719;
procedure Run;
implementation
type
  TInner = record
    Value: Integer;
  end;
var
  Extra: Integer;
  Inner: TInner;
procedure Work(var aItem: TX);
begin
  with aItem do
  begin
    OnlyA := 1;
    with Inner do
      Value := 3;
    Extra := 5;
  end;
end;
procedure Run;
var
  lItem: TX;
begin
  Extra := 0;
  Work(lItem);
  Writeln(SizeOf(lItem), ' ', Extra);
end;
end.
