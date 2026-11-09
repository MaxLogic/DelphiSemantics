unit UUser;
interface
procedure Bump;
implementation
uses UCertified;
procedure Bump;
begin
{$IFDEF RELEASE}
  SharedValue := SharedValue + 1000;
{$ENDIF}
end;
end.
