unit Unit1;
interface
var Count: Integer;
threadvar
  Rec: record
    A: Integer;
  end;
procedure Run;
implementation
procedure Run;
begin
  Count := 7;
  with Rec do A := Count;
  Writeln(Rec.A);
end;
end.
