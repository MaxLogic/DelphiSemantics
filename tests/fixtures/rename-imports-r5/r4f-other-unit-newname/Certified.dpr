program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas', UUser in 'UUser.pas';
begin
  Touch;
  Bump;
  WriteLn('v=', UUser.Extra);
end.
