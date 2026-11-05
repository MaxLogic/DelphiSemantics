unit Unit1;
interface
type
  TDataClass = record
    Value: Integer;
  end;
procedure Run;
implementation
procedure Run;
var
  lItem: TDataClass;
begin
  lItem.Value := 5;
  with lItem do
  begin
    Value := Value + 1;
  end;
  Writeln(lItem.Value);
end;
end.
