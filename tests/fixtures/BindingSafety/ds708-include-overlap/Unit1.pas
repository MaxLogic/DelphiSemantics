unit Unit1;
interface
type
  TInner = record Count: Integer; end;
  TOuter = record
    Inner: TInner;
  end;
var Item: TOuter;
procedure Run;
implementation
{$I overlap.inc}
procedure Run;
begin
  Item.Inner.Count := 0;
  with Item.Inner do Count := 7;
  Writeln(Item.Inner.Count);
end;
end.
