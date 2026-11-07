unit UCertified;
interface
type
  TC = class
  public
    Value: Integer;
    procedure Run;
  end;
var SharedValue: Integer;
procedure Touch;
implementation
{$IFDEF RELEASE}
uses UHelp;
{$ENDIF}
var ImplCount: Integer;
procedure TC.Run;
begin
  Value := ImplCount;
end;
procedure Touch;
var
  Obj: TC;
begin
  ImplCount := 4;
  Obj := TC.Create;
  Obj.Run;
  SharedValue := Obj.Value;
  Obj.Free;
end;
end.
