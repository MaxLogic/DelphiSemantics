unit Unit1;

interface

procedure Run;

implementation

const
  Limit = 99;

type
  TBox = class
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
  Item := TBox.Create;
  with Item do
    Value := Limit + 1;
  G := Item.Value;
  WriteLn(G, ':', Limit);
  Item.Free;
end;

end.
