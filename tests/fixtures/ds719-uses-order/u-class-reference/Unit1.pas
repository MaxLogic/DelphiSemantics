unit Unit1;
interface
uses A, U;
procedure Run;
implementation
procedure Change(var aItem: TRec);
begin
  with aItem do
  begin
    Value := 7;
  end;
end;
procedure Run;
var
  lItem: TRec;
begin
  lItem := TRec.Create;
  lItem.Value := 0;
  Change(lItem);
  Writeln(lItem.Value);
  lItem.Free;
end;
end.
