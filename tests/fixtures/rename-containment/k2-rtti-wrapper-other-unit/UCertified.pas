unit UCertified;
interface
type
  TC = class
  public
    Count: Integer;
  end;
var SharedValue: Integer;
procedure Touch;
implementation
uses UReflect;
procedure Touch;
var
  lObj: TC;
begin
  lObj := TC.Create;
  lObj.Count := 4;
  SharedValue := FieldInt(lObj, 'Count');
  lObj.Free;
end;
end.
