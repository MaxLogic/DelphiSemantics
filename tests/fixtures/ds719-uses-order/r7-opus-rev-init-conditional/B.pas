unit B;
interface
procedure Run;
implementation
uses
  A, U;
var
  Item: TX;
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
