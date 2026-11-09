unit UCertified;
interface
type TC = class
public
function GetValue: Integer; property Value: Integer read GetValue;
end;
implementation
function TC.GetValue: Integer; begin Result := 1; end;

end.
