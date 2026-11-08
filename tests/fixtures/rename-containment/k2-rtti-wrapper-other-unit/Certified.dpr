program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas', UReflect in 'UReflect.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
