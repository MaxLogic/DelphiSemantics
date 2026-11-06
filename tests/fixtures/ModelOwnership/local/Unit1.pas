unit Unit1;

interface

procedure Run;

implementation

procedure Run;
var
  X: record A: Integer; end;
  Following: Integer;
begin
  X.A := 2;
  Following := 7;
  with X do
    A := A + Following;
  Writeln(X.A, ':', Following);
end;
end.
