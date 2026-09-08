unit PointerReceiverUnit;

interface

function RunObservation: string;
function RunIndexedObservation: string;
function RunFieldObservation: string;
function RunDependentObservation: string;
function RunNestedObservation: string;
function RunRepeatedObservation: string;
function RunRepeatedHeaderObservation: string;
function RunShadowedReceiverObservation: string;

implementation

uses
  System.SysUtils;

type
  TPointerRecord = record
    Value: Integer;
  end;
  PPointerRecord = ^TPointerRecord;

var
  FirstRecord: TPointerRecord;
  SecondRecord: TPointerRecord;
  CurrentPointer: PPointerRecord;

procedure SwitchReceiver;
begin
  CurrentPointer := @SecondRecord;
end;

function RunObservation: string;
begin
  FirstRecord.Value := 0;
  SecondRecord.Value := 0;
  CurrentPointer := @FirstRecord;
  with CurrentPointer^ do
  begin
    Value := 1;
    SwitchReceiver;
    Value := Value + 1;
  end;
  Result := Format('%d,%d', [FirstRecord.Value, SecondRecord.Value]);
end;

type
  TPointerHolder = record
    Current: PPointerRecord;
  end;

var
  Pointers: array[0..1] of PPointerRecord;
  CurrentIndex: Integer;
  Holder: TPointerHolder;

procedure SwitchIndex;
begin
  CurrentIndex := 1;
end;

function RunIndexedObservation: string;
begin
  FirstRecord.Value := 0;
  SecondRecord.Value := 0;
  Pointers[0] := @FirstRecord;
  Pointers[1] := @SecondRecord;
  CurrentIndex := 0;
  with Pointers[CurrentIndex]^ do
  begin
    Value := 1;
    SwitchIndex;
    Value := Value + 1;
  end;
  Result := Format('%d,%d', [FirstRecord.Value, SecondRecord.Value]);
end;

procedure SwitchField;
begin
  Holder.Current := @SecondRecord;
end;

function RunFieldObservation: string;
begin
  FirstRecord.Value := 0;
  SecondRecord.Value := 0;
  Holder.Current := @FirstRecord;
  with Holder.Current^ do
  begin
    Value := 1;
    SwitchField;
    Value := Value + 1;
  end;
  Result := Format('%d,%d', [FirstRecord.Value, SecondRecord.Value]);
end;

function RunDependentObservation: string;
begin
  FirstRecord.Value := 0;
  SecondRecord.Value := 0;
  Holder.Current := @FirstRecord;
  with Holder, Current^ do
  begin
    Value := 1;
    SwitchField;
    Value := Value + 1;
  end;
  Result := Format('%d,%d', [FirstRecord.Value, SecondRecord.Value]);
end;

function RunNestedObservation: string;
begin
  FirstRecord.Value := 0;
  SecondRecord.Value := 0;
  Holder.Current := @FirstRecord;
  with Holder do
    with Current^ do
    begin
      Value := 1;
      SwitchField;
      Value := Value + 1;
    end;
  Result := Format('%d,%d', [FirstRecord.Value, SecondRecord.Value]);
end;

function RunRepeatedObservation: string;
begin
  FirstRecord.Value := 0;
  SecondRecord.Value := 0;
  CurrentPointer := @FirstRecord;
  with CurrentPointer^ do
  begin
    Value := 1;
    SwitchReceiver;
    with CurrentPointer^ do
      Value := 2;
  end;
  Result := Format('%d,%d', [FirstRecord.Value, SecondRecord.Value]);
end;

type
  PNode = ^TNode;
  TNode = record
    n: PNode;
    Value: Integer;
  end;

function RunRepeatedHeaderObservation: string;
var
  lFirstNode: TNode;
  lSecondNode: TNode;
  n: PNode;
begin
  lFirstNode := Default(TNode);
  lSecondNode := Default(TNode);
  lFirstNode.n := @lSecondNode;
  n := @lFirstNode;
  with Holder do
    with n^, n^ do
      Value := 2;
  Result := Format('%d,%d', [lFirstNode.Value, lSecondNode.Value]);
end;

type
  TInner = record
    Value: Integer;
    Padding: NativeInt;
  end;
  PInner = ^TInner;
  TOuter = record
    Current: PInner;
    Value: Integer;
  end;
  POuter = ^TOuter;

var
  Current: POuter;

function RunShadowedReceiverObservation: string;
var
  lOuter: TOuter;
  lInner: TInner;
begin
  lOuter := Default(TOuter);
  lInner := Default(TInner);
  lOuter.Current := @lInner;
  Current := @lOuter;
  with Current^ do
    with Current^ do
      Value := 2;
  Result := Format('%d,%d', [lOuter.Value, lInner.Value]);
end;

end.
