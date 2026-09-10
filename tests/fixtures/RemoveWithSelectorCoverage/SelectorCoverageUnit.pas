unit SelectorCoverageUnit;

interface

type
  PItem = ^TItem;
  TItem = record
    Value: Integer;
  end;
  TItemMap = record
  private
    function GetItem(aIndex: Integer): PItem;
  public
    Data: array[0..1] of TItem;
    property Items[aIndex: Integer]: PItem read GetItem; default;
  end;
  TContainer = record
    Items: TItemMap;
  end;
  TOuter = record
    Indexes: array[0..1, 0..1] of Integer;
  end;

var
  gOwners: array[0..1] of ^TContainer;

procedure RunNested(var aOuter: TOuter);
procedure RunPartial(var aOuter: TOuter; var aKnown: TItem);
procedure RunNormal(var aKnown: TItem);

implementation

uses
  SelectorCoverageProvider;

function TItemMap.GetItem(aIndex: Integer): PItem;
begin
  Result := @Data[aIndex];
end;

procedure RunNested(var aOuter: TOuter);
begin
  with aOuter do
    with gOwners[0]^.Items[Indexes[0, 0]]^ do
      AdvanceCount(Value);
end;

procedure RunPartial(var aOuter: TOuter; var aKnown: TItem);
begin
  with aOuter do
    with aKnown, gOwners[0]^.Items[Indexes[0, 0]]^ do
      AdvanceCount(Value);
end;

procedure RunNormal(var aKnown: TItem);
begin
  with aKnown do
    AdvanceCount(Value);
end;

procedure RunSame(var aKnown: TItem);
begin
  with aKnown do
    with aKnown do
      AdvanceCount(Value);
end;

procedure RunPair(var aFirst, aSecond: TItem);
begin
  with aFirst, aSecond do
    AdvanceCount(Value);
end;

end.
