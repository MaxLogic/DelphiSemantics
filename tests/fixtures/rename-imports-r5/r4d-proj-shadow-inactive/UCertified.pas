unit UCertified;
interface
var SharedValue: Integer;
procedure Touch;
implementation
{$IFDEF RELEASE}
uses UOther;
{$ENDIF}
procedure Touch;
begin
  SharedValue := 4;
{$IFDEF RELEASE}
  Bump;
{$ENDIF}
end;
end.
