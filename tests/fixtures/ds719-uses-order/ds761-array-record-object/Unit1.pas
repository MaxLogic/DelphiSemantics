unit Unit1;
interface
type
  TDataObject = record
    Value: Integer;
  end;
procedure Run;
implementation
procedure Run;
var
  lArr: TArray<TDataObject>;
  i: Integer;
begin
  SetLength(lArr, 1);
  i := 0;
  lArr[0].Value := 5;
  with lArr[i] do
  begin
    Value := Value + 1;
  end;
  Writeln(lArr[0].Value);
end;
end.
