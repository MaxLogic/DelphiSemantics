unit Unit1;
interface
uses AliasScope, VendorB;
procedure Run;
implementation
procedure Run;
var lValue: TX;
begin
  lValue.X := 1;
  lValue.Guard := 2;
  with lValue do X := 9;
  Writeln(lValue.X, ' ', lValue.Guard);
end;
end.
