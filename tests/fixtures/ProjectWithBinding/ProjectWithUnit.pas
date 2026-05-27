unit ProjectWithUnit;

interface

type
  TProjectUnitRecord = record
    Count: Integer;
  end;

procedure TouchProjectUnitRecord;

implementation

procedure TouchProjectUnitRecord;
var
  lRecord: TProjectUnitRecord;
begin
  with lRecord do
    Count := 2;
end;

end.
