unit PointerCastIndirect;

interface

uses
  PointerCastReceiverUnit;

procedure ExecuteIndirect(var aSlot: TSlot; const aOther: Pointer);

implementation

uses
  PointerCastAliases;

procedure ExecuteIndirect(var aSlot: TSlot; const aOther: Pointer);
begin
  with PForeignItem(aSlot.fData)^ do
  begin
    fValue := fValue + 1;
    aSlot.fData := aOther;
    fValue := fValue + 10;
  end;
end;

end.
