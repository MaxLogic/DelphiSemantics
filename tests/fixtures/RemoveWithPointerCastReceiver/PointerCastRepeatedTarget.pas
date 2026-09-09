unit PointerCastRepeatedTarget;

interface

type
  TRepeatedPointer = ^TRepeatedItem;
  TRepeatedItem = record
    fValue: Integer;
    fCalls: Integer;
    function PRepeatedItem(const aData: Pointer): TRepeatedPointer;
  end;
  PRepeatedItem = ^TRepeatedItem;

implementation

function TRepeatedItem.PRepeatedItem(const aData: Pointer): TRepeatedPointer;
begin
  Inc(fCalls);
  Result := TRepeatedPointer(aData);
end;

end.
