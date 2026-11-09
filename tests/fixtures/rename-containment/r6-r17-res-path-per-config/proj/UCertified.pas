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
{$R names.res}
uses System.Rtti, System.Classes, System.SysUtils, Winapi.Windows;
procedure Touch;
var
  lCtx: TRttiContext;
  lObj: TC;
  lField: TRttiField;
  lName: string;
  lRS: TResourceStream;
  lSS: TStringStream;
  lZ: TStream;
begin
  lRS := TResourceStream.Create(HInstance, 'NAMES', RT_RCDATA);
  lSS := TStringStream.Create;
  lSS.LoadFromStream(lRS);
  lName := Trim(lSS.DataString);
  lSS.Free;
  lRS.Free;
  lObj := TC.Create;
  lObj.Count := 4;
  lField := lCtx.GetType(TC).GetField(lName);
  if lField <> nil then
    SharedValue := lField.GetValue(lObj).AsInteger
  else
    SharedValue := -1;
  lObj.Free;
end;
end.
