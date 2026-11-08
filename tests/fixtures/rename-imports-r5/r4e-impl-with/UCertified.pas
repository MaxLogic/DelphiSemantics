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
{$IFDEF RELEASE}
uses UHelp;
{$ENDIF}
var ImplCount: Integer;
procedure Touch;
var
  Obj: TC;
begin
  Obj := TC.Create;
  ImplCount := 4;
  with Obj do
    Value := ImplCount;
  SharedValue := Obj.Value;
  Obj.Free;
end;
end.
