unit Unit1;
interface
uses A, U;
procedure Run;
implementation
procedure Run;
var
  lItem: TRec;
  lPointer: ^TRec;
begin
  lItem.Value := 0;
  lPointer := @lItem;
  with lPointer^ do
  begin
    Value := 7;
  end;
  Writeln(lItem.Value);
end;
end.
