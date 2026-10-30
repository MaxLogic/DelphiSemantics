unit B;
interface
procedure Run;
implementation
uses
  A;
var
  Item: TX;
type
  TX = record
    X, Y, Padding: Integer;
  end;
var
  Y: Integer;
procedure Run;
begin
  Writeln('VALUE=', Y, ' ', Item.X);
end;
initialization
  Item.X := 0;
  Y := 0;
  with Item do
  begin
    X := 1;
    Y := 5;
  end;
end.
