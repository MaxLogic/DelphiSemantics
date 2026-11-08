unit UCertified;
interface uses UOther;
var SharedValue: Integer;
procedure Touch;
implementation

procedure Touch;
begin
  SharedValue := 4;
  Bump;
end;
end.
