unit UCertified;
interface
var SharedValue: Integer;
procedure Touch;
implementation
uses UMid;
procedure Touch;
begin
  SharedValue := 4;
  MidBump;
end;
end.
