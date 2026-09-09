unit BodyRangesUnit;

interface

type
  TItem = record
    Value: Integer;
    Text: string;
  end;
  PItem = ^TItem;

procedure Nested(var aOuter: TItem; aPointer: Pointer; const aRun: Boolean);
function Branches(aPointer: Pointer; const aFlag: Boolean): Integer;
procedure SupportedNested(var aItem: TItem; const aRun: Boolean);
function SupportedBranches(var aItem: TItem; const aFlag: Boolean): Integer;
procedure SupportedString(var aItem: TItem);

implementation

procedure Nested(var aOuter: TItem; aPointer: Pointer; const aRun: Boolean);
begin
  if aRun then
    with aOuter do
    begin
      with PItem(aPointer)^ do
      begin
        Value := Value + 1
      end
    end else
    aOuter.Value := 99
end;

function Branches(aPointer: Pointer; const aFlag: Boolean): Integer;
begin
  with PItem(aPointer)^ do
    if Value < 0 then
      Result := -1
    else if aFlag then
    begin
      Result := Value
    end else
      Result := 0
end;

procedure SupportedNested(var aItem: TItem; const aRun: Boolean);
begin
  if aRun then
    with aItem do
    begin
      Value := Value + 1
    end else
    aItem.Value := 99
end;

function SupportedBranches(var aItem: TItem; const aFlag: Boolean): Integer;
begin
  with aItem do
    if Value < 0 then
      Result := -1
    else if aFlag then
    begin
      Result := Value
    end else
      Result := 0
end;

procedure SupportedString(var aItem: TItem);
begin
  with aItem do
    Text := 'end; else' { end; else }
end;

end.
