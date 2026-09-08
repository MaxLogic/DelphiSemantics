unit LocalConsumer;

interface

function RunLocal: Integer;
function RunNested: Integer;

implementation

function RunLocal: Integer;
type
  TLocal = record
    Value: Integer;
  end;
var
  lItem: TLocal;
  lPointer: ^TLocal;
begin
  lItem.Value := 0;
  lPointer := @lItem;
  with lPointer^ do
    Value := Value + 1;
  Result := lItem.Value;
end;

function RunNested: Integer;
type
  TOuter = record
    Value: Integer;
  end;
var
  lItem: TOuter;
  lPointer: ^TOuter;

  procedure IncrementItem;
  begin
    with lPointer^ do
      Value := Value + 1;
  end;

begin
  lItem.Value := 0;
  lPointer := @lItem;
  IncrementItem;
  Result := lItem.Value;
end;

end.
