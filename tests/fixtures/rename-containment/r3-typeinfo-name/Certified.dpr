program Certified;
{$APPTYPE CONSOLE}
uses System.TypInfo, UCertified in 'UCertified.pas';
var O: TObject;
begin
  O := MakeIt;
  if PTypeInfo(TypeInfo(TC))^.Name = 'TC' then WriteLn('v=1') else WriteLn('v=0');
  O.Free;
end.
