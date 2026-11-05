unit Unit1;
interface
uses Unit2;
type
  THost = class
  public
    type TC = record Extra, Value: Integer; end;
    procedure Execute;
  end;
procedure Run;
implementation
procedure THost.Execute;
begin
  with Item do Value := 19;
  Writeln(Item.Value, ':', Item.Guard);
end;
procedure Run;
var lObject: THost;
begin
  lObject := THost.Create;
  try lObject.Execute; finally lObject.Free; end;
end;
end.
