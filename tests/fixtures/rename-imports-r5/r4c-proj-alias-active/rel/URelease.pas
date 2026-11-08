unit URelease;
interface
procedure Bump;
implementation
uses UCertified;
procedure Bump;
begin
  SharedValue := SharedValue + 1000;
end;
end.
