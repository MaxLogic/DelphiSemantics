unit BodyRangesControlsUnit;

interface

uses
  BodyRangesUnit;

procedure BraceBoundary(var aItem: TItem; const aRun: Boolean);
procedure ParenBoundary(var aItem: TItem; const aRun: Boolean);
procedure MultilineBoundary(var aItem: TItem; const aRun: Boolean);
procedure NestedWithoutElse(var aItem: TItem; const aRun: Boolean);

implementation

procedure BraceBoundary(var aItem: TItem; const aRun: Boolean);
begin
  if aRun then
    with aItem do
    begin
      Value := Value + 1
    end { boundary comment } else
    aItem.Value := 99
end;

procedure ParenBoundary(var aItem: TItem; const aRun: Boolean);
begin
  if aRun then
    with aItem do
    begin
      Value := Value + 1
    end (* boundary comment *) else
    aItem.Value := 99
end;

procedure MultilineBoundary(var aItem: TItem; const aRun: Boolean);
begin
  if aRun then
    with aItem do
    begin
      Value := Value + 1
    end { boundary
      comment } else
    aItem.Value := 99
end;

procedure NestedWithoutElse(var aItem: TItem; const aRun: Boolean);
begin
  if aRun then
    with aItem do
    begin
      begin
        Value := Value + 1
      end
    end;
end;

end.
