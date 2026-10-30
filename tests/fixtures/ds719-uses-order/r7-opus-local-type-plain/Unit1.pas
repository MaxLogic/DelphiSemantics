unit Unit1;
interface
uses
  A;
procedure Run;
implementation
procedure Run;
type
  TX = record
    X, Y, Padding: Integer;
  end;
var
  Item: TX;
  Y: Integer;
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
