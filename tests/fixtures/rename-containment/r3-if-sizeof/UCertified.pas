unit UCertified;
interface
type TC = class
end;
procedure Touch;
implementation
procedure Touch;
begin
{$IF SizeOf(TC) > 0}
{$IFEND}
end;
end.
