unit UnreferencedWithUnit;

interface

implementation

type
  TUnreferencedRecord = record
    Hidden: Integer;
  end;

procedure TouchUnreferencedRecord;
var
  lRecord: TUnreferencedRecord;
begin
  with lRecord do
    Hidden := 3;
end;

end.
