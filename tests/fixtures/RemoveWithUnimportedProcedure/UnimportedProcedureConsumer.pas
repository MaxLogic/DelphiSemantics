unit UnimportedProcedureConsumer;

interface

type
  TImportedRecord = record
    Count: Integer;
  end;

procedure RunImported(var aValue: TImportedRecord);

implementation

procedure RunImported(var aValue: TImportedRecord);
begin
  with aValue do
  begin
    AdvanceCount(Count);
  end;
end;

end.
