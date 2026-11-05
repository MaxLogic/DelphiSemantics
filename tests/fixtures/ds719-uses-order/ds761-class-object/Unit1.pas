unit Unit1;
interface
type
  TDataObject = class
    Value: Integer;
  end;
procedure Run;
implementation
procedure Run;
var
  lItem: TDataObject;
begin
  lItem := TDataObject.Create;
  lItem.Value := 5;
  with lItem do
  begin
    Value := Value + 1;
  end;
  Writeln(lItem.Value);
  lItem.Free;
end;
end.
