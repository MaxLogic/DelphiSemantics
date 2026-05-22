unit FunctionResultUnit;

interface

uses
  System.SysUtils;

type
  TWithLegacyRecord = record
    WithLegacyValue: Integer;
  end;

function LegacyValue(aValue: Integer): Integer;
function NestedLegacyValue: Integer;
function TryFinallyLegacyValue: Integer;
function WithLegacyValue: Integer;
function OtherLegacyValue: Integer;

implementation

function LegacyValue(aValue: Integer): Integer;
begin
  LegacyValue := aValue;
  if aValue > 0 then
    LegacyValue := LegacyValue + 1;
  Result := LegacyValue;
  Result := FunctionResultUnit.LegacyValue(0);
  Result := LegacyValue(aValue - 1);
  Result := StrToIntDef('LegacyValue', 0);
  // LegacyValue := 1;
end;

function NestedLegacyValue: Integer;
  function LocalHelper: Integer;
  begin
    LocalHelper := 1;
  end;
begin
  NestedLegacyValue := LocalHelper;
  NestedLegacyValue := NestedLegacyValue + 1;
end;

function TryFinallyLegacyValue: Integer;
begin
  TryFinallyLegacyValue := 1;
  try
    TryFinallyLegacyValue := TryFinallyLegacyValue + 1;
  finally
    TryFinallyLegacyValue := TryFinallyLegacyValue + 1;
  end;
  TryFinallyLegacyValue := TryFinallyLegacyValue + 1;
end;

function WithLegacyValue: Integer;
var
  lRecord: TWithLegacyRecord;
begin
  WithLegacyValue := 1;
  with lRecord do
  begin
    WithLegacyValue := 42;
  end;
  WithLegacyValue := WithLegacyValue + 1;
end;

function OtherLegacyValue: Integer;
begin
  OtherLegacyValue := 2;
end;

end.
