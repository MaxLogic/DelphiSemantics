program Certified;
{$APPTYPE CONSOLE}
uses UCertified in 'UCertified.pas';
var O: TObject;
begin
  O := MakeIt;
  if O.ClassName = 'TC' then WriteLn('v=1') else WriteLn('v=0');
  O.Free;
end.
