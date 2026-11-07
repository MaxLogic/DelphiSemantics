unit UCertified;
interface
var Counter: Integer;
implementation
{$IF Declared(UCertified.Counter)}{$ENDIF}
procedure Touch; begin Counter := Counter + Counter; end;
end.
