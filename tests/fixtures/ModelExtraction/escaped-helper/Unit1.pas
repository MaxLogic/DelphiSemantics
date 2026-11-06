unit Unit1;
interface
procedure Run;
type
  TItem = record Value: Integer; end;
  &THelp = record helper for TItem
    function Get: Integer;
  end;
var
  Item: TItem;
  G: Integer;
implementation
function THelp.Get: Integer; begin Result := Value; end;
procedure Run;
begin
  Item.Value := 41;
  with Item do G := Get + 1;
  Writeln(G);
end;
end.
