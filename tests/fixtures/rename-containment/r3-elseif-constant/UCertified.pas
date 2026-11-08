unit UCertified;
interface
const Limit = 4;
procedure Touch;
implementation
procedure Touch;
begin
{$IF False}
{$ELSEIF Limit > 0}
{$IFEND}
end;
end.
