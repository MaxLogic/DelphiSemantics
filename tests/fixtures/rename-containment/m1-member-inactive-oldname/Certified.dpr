program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas', UUser in 'UUser.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
