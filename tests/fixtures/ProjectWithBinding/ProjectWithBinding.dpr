program ProjectWithBinding;

type
  TProjectWithRecord = record
    Value: Integer;
  end;
  PProjectWithRecord = ^TProjectWithRecord;

var
  lRecord: TProjectWithRecord;

begin
  with lRecord do
    Value := 1;
end.
