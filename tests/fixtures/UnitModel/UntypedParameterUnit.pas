unit UntypedParameterUnit;

interface

type
  TUntypedParameterScope = class
  public
    class procedure Run(const aValue; var aOther);
  end;

function RunMixed(aFirst: Integer; var aUntyped; aLast: Integer): Integer;
function RunInventory(aFirst: Integer;
  var aInventoryUntyped; aLast: Integer): Integer;

implementation

class procedure TUntypedParameterScope.Run(const aValue; var aOther);
begin
end;

function RunMixed(aFirst: Integer; var aUntyped; aLast: Integer): Integer;
begin
  Result := aFirst + aLast;
end;

function RunInventory(aFirst: Integer;
  var aInventoryUntyped; aLast: Integer): Integer;
begin
  Result := aFirst + aLast;
end;

end.
