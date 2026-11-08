unit UCertified;
interface
type
  TC = class
  public
    Value: Integer;
  end;
var SharedValue: Integer;
procedure Touch;
implementation
uses UHelp;
procedure Touch;
var
  lLocalCount: Integer;
  lObj: TC;
begin
  lObj := TC.Create;
  lLocalCount := 4;
  with lObj do
    Value := lLocalCount;
  SharedValue := lObj.Value;
  lObj.Free;
end;
end.
