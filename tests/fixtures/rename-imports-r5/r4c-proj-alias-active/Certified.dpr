program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
