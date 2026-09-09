unit NestedForwardCaptureUnit;

interface

function Observe: Integer;

implementation

type
  TItem = record
    Value: Integer;
  end;
  PItem = ^TItem;

function Observe: Integer;
var
  lItem: TItem;
  lPointer: PItem;

  procedure Touch; forward;

  procedure Touch;
  begin
    Inc(lItem.Value);
  end;

begin
  lItem.Value := 0;
  lPointer := @lItem;
  with lPointer^ do
    Value := 1;
  Touch;
  with lPointer^ do
    Inc(Value);
  Result := lItem.Value;
end;

end.
