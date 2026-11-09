program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas', Names in 'Names.pas', Lib.Pre in 'Lib.Pre.pas';
begin
  Touch;
  WriteLn('v=', UCertified.SharedValue);
end.
