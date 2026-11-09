unit UCertified;
interface
type
  TC = class
  public
    Value: Integer;
{$IFDEF RELEASE}
    function GetRenamedValue: Integer;
    property RenamedValue: Integer read GetRenamedValue;
{$ENDIF}
  end;
var SharedValue: Integer;
procedure Touch;
implementation
{$IFDEF RELEASE}
function TC.GetRenamedValue: Integer;
begin
  Result := 1000;
end;
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
