unit UTwo;
interface
procedure P;
implementation
uses UCertified;
{ shadow } var RenamedValue: Integer;
procedure P;
begin
  SharedValue := 2;
end;
end.
