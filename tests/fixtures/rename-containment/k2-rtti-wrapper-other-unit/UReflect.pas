unit UReflect;
interface
function FieldInt(aObj: TObject; const aName: string): Integer;
implementation
uses System.Rtti;
function FieldInt(aObj: TObject; const aName: string): Integer;
var
  lCtx: TRttiContext;
  lField: TRttiField;
begin
  lField := lCtx.GetType(aObj.ClassType).GetField(aName);
  if lField <> nil then
    Result := lField.GetValue(aObj).AsInteger
  else
    Result := -1;
end;
end.
