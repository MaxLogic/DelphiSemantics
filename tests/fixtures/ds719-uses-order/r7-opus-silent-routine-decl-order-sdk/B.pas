unit B;
interface
procedure Run;
implementation
uses
  System.Types;
var
  Item: TPoint;
type
  TPoint = record
    X: Integer;
  end;
var
  Y: Integer;
procedure Run;
begin
  Item.X := 0;
  Item.Y := 0;
  Y := 0;
  with Item do
  begin
    X := 1;
    Y := 5;
  end;
  Writeln('VALUE=', Y, ' ', Item.Y);
end;
end.
