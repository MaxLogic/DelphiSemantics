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
uses System.Rtti, UNames;
procedure Touch;
var
  lCtx: TRttiContext;
  lObj: TC;
  lField: TRttiField;
begin
  lObj := TC.Create;
  lObj.Count := 4;
  lField := lCtx.GetType(TC).GetField(TNames.Pre + TNames.Suf);
  if lField <> nil then
    SharedValue := lField.GetValue(lObj).AsInteger
  else
    SharedValue := -1;
  lObj.Free;
end;
end.
