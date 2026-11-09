program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas'{$IFDEF RELEASE}, UUser in 'UUser.pas'{$ENDIF};
begin
  Touch;
{$IFDEF RELEASE}
  Bump;
{$ENDIF}
  WriteLn('v=', UCertified.SharedValue);
end.
