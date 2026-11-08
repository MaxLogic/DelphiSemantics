program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'src\UCertified.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
