program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas', UMid in 'UMid.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
