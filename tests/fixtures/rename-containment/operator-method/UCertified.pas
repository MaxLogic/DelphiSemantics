unit UCertified;
interface
type TC = record
public
class operator Add(a, b: TC): TC;
end;
implementation
class operator TC.Add(a, b: TC): TC; begin Result := a; end;

end.
