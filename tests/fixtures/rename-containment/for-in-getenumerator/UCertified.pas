unit UCertified;
interface
type TC = class
public
function GetEnumerator: TC;
end;
implementation
function TC.GetEnumerator: TC; begin Result := Self; end;

end.
