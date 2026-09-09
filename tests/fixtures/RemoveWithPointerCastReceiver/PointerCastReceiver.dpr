program PointerCastReceiver;

{$APPTYPE CONSOLE}

uses
  PointerCastAliases in 'PointerCastAliases.pas',
  PointerCastCallable in 'PointerCastCallable.pas',
  PointerCastImported in 'PointerCastImported.pas',
  PointerCastIndirect in 'PointerCastIndirect.pas',
  PointerCastReceiverShadows in 'PointerCastReceiverShadows.pas',
  PointerCastReceiverUnit in 'PointerCastReceiverUnit.pas',
  PointerCastRepeated in 'PointerCastRepeated.pas',
  PointerCastRepeatedTarget in 'PointerCastRepeatedTarget.pas',
  PointerCastTarget in 'PointerCastTarget.pas',
  PointerCastVisible in 'PointerCastVisible.pas';

procedure RunCases;
var
  lCalls: Integer;
  lFirst, lOther: TItem;
  lReceiver: PItem;
  lSlot: TSlot;
  lSlots: array[0..0] of TSlot;
begin
  lFirst := Default(TItem);
  lOther := Default(TItem);
  lSlot.fData := @lFirst;
  ExecuteDirect(lSlot, lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lFirst.fValue := 0;
  lSlot.fData := @lFirst;
  ExecuteGuarded(lSlot, lOther, True);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lFirst.fValue := 0;
  lSlot.fData := nil;
  ExecuteGuarded(lSlot, lOther, False);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lSlot.fData := @lFirst;
  ExecuteLoop(lSlot, lOther, 1);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lFirst.fValue := 0;
  lSlot.fData := nil;
  ExecuteLoop(lSlot, lOther, 0);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lSlots[0].fData := @lFirst;
  ExecuteIndexed(lSlots, lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lFirst.fValue := 0;
  lReceiver := @lFirst;
  ExecuteOrdinary(lReceiver, lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue);
  lFirst.fValue := 0;
  lSlot.fData := @lFirst;
  ExecuteRoutineShadow(lSlot, lOther, lCalls);
  Writeln(lFirst.fValue, ',', lOther.fValue, ',', lCalls);
end;

begin
  RunCases;
  RunShadowCases;
  RunVisibilityCases;
  RunImportedCase;
  RunRepeatedCase;
end.
