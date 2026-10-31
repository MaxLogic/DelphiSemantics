unit Unit1;
interface
procedure Run;
implementation
uses A, B;
type TSecond = {$IFDEF LINUX}TAlternate{$ELSE}TCapture{$ENDIF};
  TAlias = TSecond;
var Item: TAlias;
procedure Run;
begin
  Item.Data := 7;
  with Item do Writeln(Data);
end;
end.
