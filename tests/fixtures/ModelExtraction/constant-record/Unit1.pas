unit Unit1;

interface

procedure Run;

implementation

const
  Limit = 99;

type
  TBox = record
  public
  const
    Limit = 5;
  public
    Value: Integer;
  end;

procedure Run;
var
  Item: TBox;
  Limit: Integer;
  G: Integer;
begin
  Limit := 100;
  Item.Value := 0;
  with Item do
    Value := Limit + 1;
  G := Item.Value;
  WriteLn(G, ':', Limit);
end;

end.
