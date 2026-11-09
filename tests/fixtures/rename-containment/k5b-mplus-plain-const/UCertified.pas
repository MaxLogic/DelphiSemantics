unit UCertified;
interface
uses System.TypInfo, UNames;
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
  try
    SharedValue := GetPropValue(Obj, cName);
  except
    SharedValue := -1;
  end;
  Obj.Free;
end;
end.
