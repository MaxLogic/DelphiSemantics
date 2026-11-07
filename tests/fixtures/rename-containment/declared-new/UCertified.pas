unit UCertified;
interface
var Counter: Integer;
implementation
{$IF Declared(Renamed)}{$ENDIF}
procedure Touch; begin Counter := Counter + Counter; end;
end.
