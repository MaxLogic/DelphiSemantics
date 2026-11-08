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
uses System.Rtti;
procedure Touch;
var
  lCtx: TRttiContext;
  lObj: TC;
  lField: TRttiField;
begin
  lObj := TC.Create;
  lObj.Count := 4;
  lField := lCtx.GetType(TC).GetField('Count');
  if lField = nil then SharedValue := -1 else SharedValue := lField.GetValue(lObj).AsInteger;
  lObj.Free;
end;
end.
