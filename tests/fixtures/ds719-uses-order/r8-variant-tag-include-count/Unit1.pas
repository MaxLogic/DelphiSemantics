unit Unit1;
interface
var
  Rec: record
    A: Integer;
    {$I tag.inc}
      0: (X: Integer);
  end;
var Count: Integer;
procedure Run;
implementation
procedure Run;
begin
  Rec.A := -1;
  Rec.Count := 7;
  Count := 19;
  with Rec do A := Count;
  Writeln('VALUE=', Rec.A, ' ', Rec.Count, ' ', Count);
end;
end.
