unit PointerCastVisible;

interface

uses
  PointerCastReceiverUnit;

procedure ExecuteVisible(var aSlot: TSlot; const aOther: Pointer);
procedure ExecuteTargetCollision(var aSlot: TSlot; const aOther: Pointer);
procedure RunVisibilityCases;

implementation

uses
  PointerCastAliases, PointerCastIndirect, PointerCastTarget;

procedure ExecuteVisible(var aSlot: TSlot; const aOther: Pointer);
begin
  with PForeignItem(aSlot.fData)^ do
  begin
    fValue := fValue + 1;
    aSlot.fData := aOther;
    fValue := fValue + 10;
  end;
end;

procedure ExecuteTargetCollision(var aSlot: TSlot; const aOther: Pointer);
type
  TForeignItem = record
    fOther: Int64;
  end;
begin
  with PForeignItem(aSlot.fData)^ do
  begin
    fValue := fValue + 1;
    aSlot.fData := aOther;
    fValue := fValue + 10;
  end;
end;

procedure RunVisibilityCases;
var
  lFirst, lOther: TForeignItem;
  lSlot: TSlot;
begin
  lFirst := Default(TForeignItem);
  lOther := Default(TForeignItem);
  lSlot.fData := @lFirst;
  ExecuteVisible(lSlot, @lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lFirst.fValue := 0;
  lSlot.fData := @lFirst;
  ExecuteTargetCollision(lSlot, @lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lFirst.fValue := 0;
  lSlot.fData := @lFirst;
  ExecuteIndirect(lSlot, @lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue);
end;

end.
