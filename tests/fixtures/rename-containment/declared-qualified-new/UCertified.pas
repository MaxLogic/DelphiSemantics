unit UCertified;
interface
var Counter: Integer;
implementation
{$IF Declared(UCertified.Renamed)}{$ENDIF}
procedure Touch; begin Counter := Counter + Counter; end;
end.
