unit UCertified;
interface
type
  TC = class
  end;
var SharedValue: Integer;
procedure Touch;
implementation
procedure Touch;
var
  lObj: TObject;
begin
  lObj := TC.Create;
  if lObj.ClassNameIs('TC') then
    SharedValue := 4
  else
    SharedValue := -1;
  lObj.Free;
end;
end.
