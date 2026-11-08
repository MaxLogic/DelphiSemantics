unit UCertified;
interface
var SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
begin
  SharedValue := 4;
  {$I decl.inc}
end;
end.
