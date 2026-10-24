unit Unit1;
interface
uses A, System.Types;
procedure Run;
implementation
var
  Item: TPoint;
  Y: Integer;
procedure Run;
begin
  Y := 0;
  with Item do
  begin
    X := 1;
    Y := 5;
  end;
  Writeln(SizeOf(Item), ' ', Y);
end;
end.
