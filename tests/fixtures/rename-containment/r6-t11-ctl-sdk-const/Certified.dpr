program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas', UNames in 'UNames.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
