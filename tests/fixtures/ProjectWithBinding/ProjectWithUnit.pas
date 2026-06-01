unit ProjectWithUnit;

interface

type
  TProjectUnitRecord = record
    Count: Integer;
  end;
  TProjectUnitScope = class
    procedure Run(const aScopeValue: Integer);
  end;

procedure TouchProjectUnitRecord(const aValue: Integer);

implementation

procedure TouchProjectUnitRecord(const aValue: Integer);
var
  lRecord: TProjectUnitRecord;
begin
  with lRecord do
    Count := aValue;
end;

procedure TProjectUnitScope.Run(const aScopeValue: Integer);
var
  lScopedRecord: TProjectUnitRecord;
begin
  with lScopedRecord do
    Count := aScopeValue;
end;

end.
