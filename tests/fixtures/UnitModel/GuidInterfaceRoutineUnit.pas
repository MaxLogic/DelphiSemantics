unit GuidInterfaceRoutineUnit;

interface

type
  IGuidInline = interface(IInterface) ['{12345678-1234-1234-1234-123456789ABC}'] end;

function RoutineAfterGuidInterface: Integer;

implementation

function RoutineAfterGuidInterface: Integer;
begin
  Result := 1;
end;

end.
