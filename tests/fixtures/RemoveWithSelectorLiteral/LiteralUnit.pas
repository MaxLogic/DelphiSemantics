unit LiteralUnit;

interface

function RunHex: Integer;
function RunChar: Integer;
function RunComment: Integer;

implementation

type
  TItem = record
    Value: Integer;
  end;
  PItem = ^TItem;
  TPointerArray = array[0..255] of PItem;
  TCharPointerArray = array['A'..'Z'] of PItem;
  THolder = record
    AB: Integer;
    Index: Integer;
    X: Char;
    Items: TPointerArray;
    Letters: TCharPointerArray;
  end;

var
  Holder: THolder;
  Item: TItem;
  OtherItem: TItem;
  Index: Integer;

function RunHex: Integer;
begin
  Item.Value := 0;
  Holder.Items[$AB] := @Item;
  Holder.AB := 0;
  with Holder, Items[$AB]^ do
    Value := 42;
  Result := Item.Value;
end;

function RunChar: Integer;
begin
  Item.Value := 0;
  Holder.Letters['X'] := @Item;
  Holder.X := 'A';
  with Holder, Letters['X']^ do
    Value := 43;
  Result := Item.Value;
end;

function RunComment: Integer;
begin
  Item.Value := 0;
  OtherItem.Value := 0;
  Holder.Items[0] := @OtherItem;
  Holder.Items[1] := @Item;
  Index := 0;
  Holder.Index := 1;
  with Holder, Items[{don't change} Index]^ do
    Value := 44;
  Result := Item.Value;
end;

end.
