unit UCertified;
interface
var SharedValue: Integer;
procedure Touch;
implementation
uses UOther;
procedure Touch;
begin
  SharedValue := 4;
  Bump;
end;
end.
