unit ControlledArrayShadowUnit;

interface

type
  TShadowItem = record
    Value: Integer;
  end;
  TShadowContainer = record
    Items: array[0..2] of TShadowItem;
  end;
var
  ShadowContainer: TShadowContainer;
  RoutineContainer: TShadowContainer;
  GetterCount: Integer;
  ItemsCount: Integer;

type
  TShadowArray = array of TShadowItem;
  TShadowAccessor = class
    function Items: TShadowArray;
  end;
  TShadowHost = class
  private
    fAccessor: TShadowAccessor;
    function GetContainer: TShadowAccessor;
  public
    constructor Create;
    destructor Destroy; override;
    function ReadShadow(var aIndex: Integer): Integer;
    property ShadowContainer: TShadowAccessor read GetContainer;
  end;

function RunShadowControl: string;
function RunRoutineShadowControl: string;

implementation

uses
  System.SysUtils;

constructor TShadowHost.Create;
begin
  inherited Create;
  fAccessor := TShadowAccessor.Create;
end;

destructor TShadowHost.Destroy;
begin
  fAccessor.Free;
  inherited;
end;

function TShadowAccessor.Items: TShadowArray;
begin
  Inc(ItemsCount);
  SetLength(Result, 3);
  Result[0].Value := 41;
end;

function TShadowHost.GetContainer: TShadowAccessor;
begin
  Inc(GetterCount);
  Result := fAccessor;
end;

function TShadowHost.ReadShadow(var aIndex: Integer): Integer;
begin
  Result := 0;
  if aIndex = 0 then
    with ShadowContainer.Items[aIndex] do
    begin
      Result := Value;
      Inc(aIndex);
    end;
end;

function RunShadowControl: string;
var
  lHost: TShadowHost;
  lIndex: Integer;
  lValue: Integer;
begin
  ShadowContainer.Items[0].Value := 13;
  lIndex := 0;
  lHost := TShadowHost.Create;
  try
    lValue := lHost.ReadShadow(lIndex);
    Result := Format('%d,%d,%d,%d,%d', [lValue, lIndex,
      ShadowContainer.Items[0].Value, GetterCount, ItemsCount]);
  finally
    lHost.Free;
  end;
end;

function RunRoutineShadowControl: string;
var
  lAccessor: TShadowAccessor;
  i: Integer;
  lValue: Integer;

  function RoutineContainer: TShadowAccessor;
  begin
    Inc(GetterCount);
    Result := lAccessor;
  end;

begin
  ControlledArrayShadowUnit.RoutineContainer.Items[0].Value := 17;
  i := 0;
  lValue := 0;
  lAccessor := TShadowAccessor.Create;
  try
    if i = 0 then
      with RoutineContainer.Items[i] do
      begin
        lValue := Value;
        Inc(i);
      end;
    Result := Format('%d,%d,%d,%d,%d', [lValue, i,
      ControlledArrayShadowUnit.RoutineContainer.Items[0].Value, GetterCount, ItemsCount]);
  finally
    lAccessor.Free;
  end;
end;

end.
