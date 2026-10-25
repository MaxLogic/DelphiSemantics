unit Unit1;
interface
uses A, U;
procedure Run;
implementation
procedure Change(var aItem: PRec);
begin
  with aItem^ do
  begin
    Value := 7;
  end;
end;
procedure Run;
var
  lItem: TRec;
  lPointer: PRec;
begin
  lItem.Value := 0;
  lPointer := @lItem;
  Change(lPointer);
  Writeln(lItem.Value);
end;
end.
