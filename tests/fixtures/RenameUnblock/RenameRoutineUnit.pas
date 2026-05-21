unit RenameRoutineUnit;

interface

type
  TRoutineValue = Integer;

function RoutineTarget(aValue: TRoutineValue): TRoutineValue;

implementation

function RoutineTarget(aValue: TRoutineValue): TRoutineValue;
begin
  Result := aValue;
end;

end.
