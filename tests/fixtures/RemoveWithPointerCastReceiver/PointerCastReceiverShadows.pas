unit PointerCastReceiverShadows;

interface

uses
  PointerCastReceiverUnit;

type
  TCallableRecord = record
    fCalls: Integer;
    function PItem(const aData: Pointer): TItemPointer;
  end;

procedure ExecuteComma(var aOuter: TCallableRecord; var aSlot: TSlot; var aOther: TItem);
procedure ExecuteNested(var aOuter: TCallableRecord; var aSlot: TSlot; var aOther: TItem);
procedure ExecuteLocalShadow(var aSlot: TSlot; var aOther: TItem);
procedure RunShadowCases;

implementation

function TCallableRecord.PItem(const aData: Pointer): TItemPointer;
begin
  Inc(fCalls);
  Result := TItemPointer(aData);
end;

procedure ExecuteComma(var aOuter: TCallableRecord; var aSlot: TSlot; var aOther: TItem);
begin
  with aOuter, PItem(aSlot.fData)^ do
  begin
    fValue := fValue + 1;
    aSlot.fData := @aOther;
    fValue := fValue + 10;
  end;
end;

procedure ExecuteNested(var aOuter: TCallableRecord; var aSlot: TSlot; var aOther: TItem);
begin
  with aOuter do
    with PItem(aSlot.fData)^ do
    begin
      fValue := fValue + 1;
      aSlot.fData := @aOther;
      fValue := fValue + 10;
    end;
end;

function GetItem(const aData: Pointer): TItemPointer;
begin
  Result := TItemPointer(aData);
end;

procedure ExecuteLocalShadow(var aSlot: TSlot; var aOther: TItem);
type
  TItemFactory = function(const aData: Pointer): TItemPointer;
var
  PItem: TItemFactory;
begin
  PItem := GetItem;
  with PItem(aSlot.fData)^ do
  begin
    fValue := fValue + 1;
    aSlot.fData := @aOther;
    fValue := fValue + 10;
  end;
end;

procedure RunShadowCases;
var
  lFirst, lOther: TItem;
  lOuter: TCallableRecord;
  lSlot: TSlot;
begin
  lFirst := Default(TItem);
  lOther := Default(TItem);
  lOuter := Default(TCallableRecord);
  lSlot.fData := @lFirst;
  ExecuteComma(lOuter, lSlot, lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue, ',', lOuter.fCalls);
  lFirst.fValue := 0;
  lOuter.fCalls := 0;
  lSlot.fData := @lFirst;
  ExecuteNested(lOuter, lSlot, lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue, ',', lOuter.fCalls);
  lFirst.fValue := 0;
  lSlot.fData := @lFirst;
  ExecuteLocalShadow(lSlot, lOther);
  Writeln(lFirst.fValue, ',', lOther.fValue);
end;

end.
