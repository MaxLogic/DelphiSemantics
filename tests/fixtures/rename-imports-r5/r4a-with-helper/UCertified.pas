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
procedure Touch;
var
  LocalCount: Integer;
  Obj: TC;
begin
  Obj := TC.Create;
  LocalCount := 4;
  with Obj do
    Value := LocalCount;
  SharedValue := Obj.Value;
  Obj.Free;
end;
end.
