unit UnimportedProcedureProvider;

interface

procedure AdvanceCount(var aCount: Integer);
function AdvancedCount(const aCount: Integer): Integer;

implementation

procedure AdvanceCount(var aCount: Integer);
begin
  Inc(aCount, 3);
end;

function AdvancedCount(const aCount: Integer): Integer;
begin
  Result := aCount + 3;
end;

procedure HiddenAdvanceCount(var aCount: Integer);
begin
  Inc(aCount, 9);
end;

end.
