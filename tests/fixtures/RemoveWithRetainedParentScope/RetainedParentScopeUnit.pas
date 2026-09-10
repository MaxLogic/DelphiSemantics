unit RetainedParentScopeUnit;

interface

function RunIndexed: Integer;
function RunShadowed: Integer;
function RunOrdinary: Integer;
function RunInitializer: Integer; function RunPacked: Integer;

implementation

uses
  RetainedParentScopeProvider;

type
  TOuter = record
    v: array[0..0] of Integer;
    Value: Integer;
  end;
  TInner = record
    Count: Integer;
  end;
  PInner = ^TInner;
  TShadow = record
    Count: Integer;
    v: array[0..0] of Integer;
  end;

function RunIndexed: Integer;
var
  v: TOuter;
  lInner: TInner;
  lGuard: Integer;
begin
  v := Default(TOuter);
  lInner := Default(TInner);
  v.v[0] := 7;
  lGuard := 0;
  with v do
  begin
    PreserveBoundary(lGuard);
    with lInner do
      Count := v[0];
  end;
  Result := lInner.Count;
end;

function RunShadowed: Integer;
var
  v: TOuter;
  lInner: TShadow;
  lGuard: Integer;
begin
  v := Default(TOuter);
  lInner := Default(TShadow);
  v.v[0] := 7;
  lInner.v[0] := 13;
  lGuard := 0;
  with v do
  begin
    PreserveBoundary(lGuard);
    with lInner do
      Count := v[0];
  end;
  Result := lInner.Count;
end;

function RunOrdinary: Integer;
var
  v: TOuter;
  lInner: TInner;
  lGuard: Integer;
begin
  v := Default(TOuter);
  lInner := Default(TInner);
  v.Value := 11;
  lGuard := 0;
  with v do
  begin
    PreserveBoundary(lGuard);
    with lInner do
      Count := Value;
  end;
  Result := lInner.Count;
end;

function RunInitializer: Integer;
var
  v: TOuter;
  lFirst, lSecond: TInner;
  lItems: array[0..1] of PInner;
  lGuard: Integer;
begin
  v := Default(TOuter);
  v.v[0] := 1;
  lFirst.Count := 3;
  lSecond.Count := 5;
  lItems[0] := @lFirst;
  lItems[1] := @lSecond;
  lGuard := 0;
  with v do
  begin
    PreserveBoundary(lGuard);
    with lItems[v[0]]^ do
      Inc(Count);
  end;
  Result := lFirst.Count * 100 + lSecond.Count;
end;

type
  TPackedOuter = packed record
    Value: Integer;
  end;

function RunPacked: Integer;
var
  v: TPackedOuter;
  lInner: TInner;
  lGuard: Integer;
begin
  v.Value := 17;
  lInner := Default(TInner);
  lGuard := 0;
  with v do
  begin
    PreserveBoundary(lGuard);
    with lInner do
      Count := Value;
  end;
  Result := lInner.Count;
end;

end.
