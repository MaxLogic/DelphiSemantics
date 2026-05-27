program ProjectWithBinding;

type
  TProjectWithRecord = record
    Value: Integer;
  end;

var
  lRecord: TProjectWithRecord;

begin
  with lRecord do
    Value := 1;
end.
