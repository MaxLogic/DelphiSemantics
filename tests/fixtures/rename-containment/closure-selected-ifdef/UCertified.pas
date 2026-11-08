unit UCertified;
interface
var Counter: Integer;
procedure Touch;
implementation
{$IFDEF MSWINDOWS}
uses UHelp;
{$ENDIF}
procedure Touch;
begin
  Counter := Counter + Counter;
end;
end.
