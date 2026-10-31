unit Unit1;
interface
procedure Run;
implementation
type TRec = record Value: Integer; end;
procedure Work(var aItem: TRec);
begin
{$I body.inc}
end;
procedure Run;
var lItem: TRec;
begin
  Work(lItem);
  Writeln(lItem.Value);
end;
end.
