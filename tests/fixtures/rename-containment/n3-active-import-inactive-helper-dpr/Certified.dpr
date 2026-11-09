program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas', UHelp in 'UHelp.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
