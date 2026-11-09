unit UCertified;
interface
uses System.TypInfo;
type
  TCBase = class
  protected
    FV: Integer;
  end;
{$M+}
  TC = class(TCBase)
    property Value: Integer read FV write FV;
  end;
{$M-}
var SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
var
  Obj: TC;
begin
  Obj := TC.Create;
  Obj.Value := 4;
  SharedValue := GetPropValue(Obj, 'Value');
  Obj.Free;
end;
end.
