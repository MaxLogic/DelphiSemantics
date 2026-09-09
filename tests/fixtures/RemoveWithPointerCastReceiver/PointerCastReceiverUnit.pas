unit PointerCastReceiverUnit;

interface

type
  TItem = record
    fValue: Integer;
  end;
  PItem = ^TItem;
  TItemPointer = ^TItem;
  TSlot = record
    fData: Pointer;
  end;

procedure ExecuteDirect(var aSlot: TSlot; var aOther: TItem);
procedure ExecuteGuarded(var aSlot: TSlot; var aOther: TItem; const aRun: Boolean);
procedure ExecuteLoop(var aSlot: TSlot; var aOther: TItem; aCount: Integer);
procedure ExecuteIndexed(var aSlots: array of TSlot; var aOther: TItem);
procedure ExecuteOrdinary(var aReceiver: PItem; var aOther: TItem);
procedure ExecuteRoutineShadow(var aSlot: TSlot; var aOther: TItem; out aCalls: Integer);

implementation

procedure ExecuteDirect(var aSlot: TSlot; var aOther: TItem);
begin
  with PItem(aSlot.fData)^ do
  begin
    fValue := fValue + 1;
    aSlot.fData := @aOther;
    fValue := fValue + 10;
  end;
end;

procedure ExecuteGuarded(var aSlot: TSlot; var aOther: TItem; const aRun: Boolean);
begin
  if aRun then
    with PItem(aSlot.fData)^ do
    begin
      fValue := fValue + 1;
      aSlot.fData := @aOther;
      fValue := fValue + 10;
    end;
end;

procedure ExecuteLoop(var aSlot: TSlot; var aOther: TItem; aCount: Integer);
begin
  while aCount > 0 do
    with PItem(aSlot.fData)^ do
    begin
      fValue := fValue + 1;
      aSlot.fData := @aOther;
      fValue := fValue + 10;
      Dec(aCount);
    end;
end;

procedure ExecuteIndexed(var aSlots: array of TSlot; var aOther: TItem);
begin
  with PItem(aSlots[0].fData)^ do
  begin
    fValue := fValue + 1;
    aSlots[0].fData := @aOther;
    fValue := fValue + 10;
  end;
end;

procedure ExecuteOrdinary(var aReceiver: PItem; var aOther: TItem);
begin
  with aReceiver^ do
  begin
    fValue := fValue + 1;
    aReceiver := @aOther;
    fValue := fValue + 10;
  end;
end;

procedure ExecuteRoutineShadow(var aSlot: TSlot; var aOther: TItem; out aCalls: Integer);
var
  lCalls: Integer;

  function PItem(const aData: Pointer): TItemPointer;
  begin
    Inc(lCalls);
    Result := TItemPointer(aData);
  end;

begin
  lCalls := 0;
  with PItem(aSlot.fData)^ do
  begin
    fValue := fValue + 1;
    aSlot.fData := @aOther;
    fValue := fValue + 10;
  end;
  aCalls := lCalls;
end;

end.
