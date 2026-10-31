unit Unit1;
interface
procedure Run;
implementation
uses A, B;
type TAlias = {$IFDEF LINUX}TAlternate{$ELSE}TCapture{$ENDIF};
var Item: TAlias;
procedure Run;
begin
  Item.Data := 7;
  with Item do Writeln(Data);
end;
end.
