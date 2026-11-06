unit Unit1;
interface
procedure Run;
type
  TR = record
    Inner: record
      Value: Integer;
    end;
    const
      cValue = 1;
  end;
  TC = record
    Value: Integer;
    function Get: Integer;
  end;
var
  Item: TC;
  G: Integer;
implementation
function TC.Get: Integer; begin Result := Value; end;
procedure Run;
begin
  Item.Value := 41;
  with Item do G := Get + 1;
  Writeln(G);
end;
end.
