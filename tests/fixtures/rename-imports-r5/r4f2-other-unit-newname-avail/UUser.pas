unit UUser;
interface
var Extra: Integer;
procedure Bump;
implementation
uses
{$IFDEF RELEASE}
  UHelp,
{$ENDIF}
  UCertified;
procedure Bump;
begin
  Extra := 7;
{$IFDEF RELEASE}
  Extra := RenamedValue;
{$ENDIF}
end;
end.
