unit Unit1;
interface
type TRec = record Value: Integer; procedure Unused; end;
procedure Work(var aItem: TRec);
procedure Run;
implementation
procedure TRec.Unused; begin end;
procedure Run;
var lItem: TRec;
begin Work(lItem); Writeln(lItem.Value); end;
procedure Work(var aItem: TRec);
begin with aItem do Value := 7; end;
end.
