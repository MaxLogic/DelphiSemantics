unit B;
interface
procedure Run;
implementation
uses
  System.Types;
type
  TOuter = record
    Sub: TPoint;
  end;
type
  TPoint = record
    X: Integer;
  end;
var
  O: TOuter;
  Y: Integer;
procedure Run;
begin
  O.Sub.X := 0;
  O.Sub.Y := 0;
  Y := 0;
  with O.Sub do
  begin
    X := 1;
    Y := 5;
  end;
  Writeln('VALUE=', Y, ' ', O.Sub.Y);
end;
end.
