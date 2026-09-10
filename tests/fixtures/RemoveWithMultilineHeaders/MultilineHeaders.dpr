program MultilineHeaders;

{$APPTYPE CONSOLE}

uses
  MultilineHeadersUnit in 'MultilineHeadersUnit.pas';

var
  lItem: TItem;
  lRaw, lResult: Integer;
begin
  lItem.Value := 10;
  lRaw := 0;
  lResult := SingleLine(lItem, lRaw, 3);
  Writeln(lResult, ',', lRaw, ',', lItem.Value);
  lRaw := 0;
  lResult := Wrapped(lItem, lRaw, 3);
  Writeln(lResult, ',', lRaw, ',', lItem.Value);
  Writeln(Shadowed(lItem, 7));
  Writeln(HeaderExtent);
  NestedCalls(lItem, 5);
  Writeln(lItem.Value);
end.
