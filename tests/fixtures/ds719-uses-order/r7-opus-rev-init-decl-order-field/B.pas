unit B;
interface
procedure Run;
implementation
uses
  A;
type
  TOuter = record
    Sub: TX;
  end;
type
  TX = record
    X, Y, Padding: Integer;
  end;
var
  O: TOuter;
  Y: Integer;
procedure Run;
begin
  Writeln('VALUE=', Y, ' ', O.Sub.X);
end;
initialization
  O.Sub.X := 0;
  Y := 0;
  with O.Sub do
  begin
    X := 1;
    Y := 5;
  end;
end.
