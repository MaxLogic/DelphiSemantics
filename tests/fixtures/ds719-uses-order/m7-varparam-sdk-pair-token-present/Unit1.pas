unit Unit1;
interface
uses A, System.Types;
procedure Run;
implementation
var
  Y: Integer;
procedure Work(var P: TPoint);
begin
  with P do
  begin
    X := 1;
    Y := 5;
  end;
end;
procedure Run;
var
  P: TPoint;
begin
  Y := 0;
  Work(P);
  Writeln(SizeOf(P), ' ', Y);
end;
end.
