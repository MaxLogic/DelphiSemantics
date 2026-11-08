unit UCertified;
interface
var Counter: Integer;
procedure Touch;
implementation
uses UHelp;
procedure Touch;
begin
  Counter := Counter + Counter;
end;
end.
