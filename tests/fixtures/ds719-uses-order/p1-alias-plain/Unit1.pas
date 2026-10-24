unit Unit1;
interface
uses ControlUnit;
type
 TRec = ControlUnit.TRec;
var R: TRec;
procedure Run;
implementation
procedure Run;
begin
  R.Count := 5;
  with R do Count := Count + 1;
  Writeln(R.Count);
end;
end.
