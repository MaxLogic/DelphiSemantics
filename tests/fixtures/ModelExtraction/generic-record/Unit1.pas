unit Unit1;
interface
procedure Run;
type
  TItem = record
    Value: Integer;
    function Get: Integer;
  end;
  TGen<T> = record
    Data: T;
  end;
  TPad = record Pad: Integer; end;
  TX = TItem;
var
  Item: TX;
  G: Integer;
implementation
function TItem.Get: Integer; begin Result := Value; end;
procedure Run;
begin
  Item.Value := 41;
  with Item do G := Get + 1;
  Writeln(G);
end;
end.
