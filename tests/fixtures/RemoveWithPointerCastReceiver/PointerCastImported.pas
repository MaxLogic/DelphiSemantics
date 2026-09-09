unit PointerCastImported;

interface

procedure RunImportedCase;

implementation

uses
  PointerCastReceiverUnit, PointerCastCallable;

procedure RunImportedCase;
var
  lFirst, lOther: TItem;
  lSlot: TSlot;
begin
  lFirst := Default(TItem);
  lOther := Default(TItem);
  lSlot.fData := @lFirst;
  with PItem(lSlot.fData)^ do
  begin
    fValue := fValue + 1;
    lSlot.fData := @lOther;
    fValue := fValue + 10;
  end;
  Writeln(lFirst.fValue, ',', lOther.fValue);
end;

end.
