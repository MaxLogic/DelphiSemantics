unit CapturedIndentUnit;

interface

function RunPointer: Integer;
function RunIndexed: Integer;
function RunControlled(const aRun: Boolean): Integer;

implementation

type
  TItem = record
    Value: Integer;
  end;
  PItem = ^TItem;

var
  Item: TItem;
  ItemPtr: PItem;
  Items: array[0..0] of PItem;

function RunPointer: Integer;
begin
  Item.Value := 0;
  ItemPtr := @Item;
  begin
    with ItemPtr^ do
      Value := 1;
  end;
  Result := Item.Value;
end;

function RunIndexed: Integer;
begin
  Item.Value := 0;
  Items[0] := @Item;
  begin
    begin
      with Items[0]^ do
        Value := 2;
    end;
  end;
  Result := Item.Value;
end;

function RunControlled(const aRun: Boolean): Integer;
begin
  Item.Value := 0;
  ItemPtr := @Item;
  if aRun then
    with ItemPtr^ do
      Value := 3;
  Inc(Item.Value, 10);
  Result := Item.Value;
end;

end.
