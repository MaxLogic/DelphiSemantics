unit UCertified;
interface
var SharedValue: Integer;
procedure Touch;
implementation
{$IFDEF RELEASE}
uses UHelp;
{$ENDIF}
procedure Touch;
var
  LocalCount: Integer;
begin
  LocalCount := 4;
  SharedValue := LocalCount;
{$I Extra.inc}
end;
end.
