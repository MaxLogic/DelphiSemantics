unit ControlUnit;
interface
type TRec = record Count: Integer; end;
var Rec: TRec;
procedure Run;
implementation
procedure Run;
begin
  Rec.Count := 5;
  with Rec do Count := Count + 1;
  Writeln(Rec.Count);
end;
end.
