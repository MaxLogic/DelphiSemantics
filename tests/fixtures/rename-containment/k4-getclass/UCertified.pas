unit UCertified;
interface
uses System.Classes;
type
  TC = class(TPersistent)
  end;
var SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
begin
  if GetClass('TC') <> nil then
    SharedValue := 4
  else
    SharedValue := -1;
end;
initialization
  RegisterClass(TC);
end.
