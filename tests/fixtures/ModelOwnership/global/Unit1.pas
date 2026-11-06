unit Unit1;

interface

var
  X: record A: Integer; end;
  Following: Integer;

procedure Run;

implementation

procedure Run;
begin
  X.A := 2;
  Following := 7;
  with X do
    A := A + Following;
  Writeln(X.A, ':', Following);
end;
end.
