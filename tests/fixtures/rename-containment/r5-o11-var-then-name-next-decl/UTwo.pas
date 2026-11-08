unit UTwo;
interface
procedure P;
implementation
uses UCertified;
var
  Dummy: Integer; RenamedValue: Integer;
procedure P;
begin
  SharedValue := 2;
end;
end.
