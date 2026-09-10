unit ImportedProcedureConsumer;

interface

type
  TImportedRecord = record
    Count: Integer;
  end;

procedure RunImported(var aValue: TImportedRecord);
procedure RunQualified(var aValue: TImportedRecord);
procedure RunValue(var aValue: TImportedRecord);

implementation

uses
  ImportedProcedureProvider;

procedure RunImported(var aValue: TImportedRecord);
begin
  with aValue do
  begin
    AdvanceCount(Count);
  end;
end;

procedure RunQualified(var aValue: TImportedRecord);
begin
  with aValue do
  begin
    ImportedProcedureProvider.AdvanceCount(Count);
  end;
end;

procedure RunValue(var aValue: TImportedRecord);
begin
  with aValue do
  begin
    Count := AdvancedCount(Count);
  end;
end;

end.
