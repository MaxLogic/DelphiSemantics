unit PointerCastRepeated;

interface

procedure RunRepeatedCase;

implementation

uses
  PointerCastRepeatedTarget;

procedure RunRepeatedCase;
var
  lFirst, lOther: TRepeatedItem;
  lSlot: Pointer;
begin
  lFirst := Default(TRepeatedItem);
  lOther := Default(TRepeatedItem);
  lSlot := @lFirst;
  with PRepeatedItem(lSlot)^ do
    with PRepeatedItem(lSlot)^ do
    begin
      fValue := fValue + 1;
      lSlot := @lOther;
      fValue := fValue + 10;
    end;
  Writeln(lFirst.fValue, ',', lOther.fValue, ',', lFirst.fCalls);
end;

end.
