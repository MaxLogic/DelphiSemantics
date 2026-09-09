unit PointerCastCallable;

interface

uses
  PointerCastReceiverUnit;

function PItem(const aData: Pointer): TItemPointer;

implementation

function PItem(const aData: Pointer): TItemPointer;
begin
  Result := TItemPointer(aData);
  Inc(Result.fValue, 100);
end;

end.
