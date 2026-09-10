unit ImportedProcedureControls;

interface

uses
  ImportedProcedureConsumer;

type
  TMethodRecord = record
    Count: Integer;
    procedure AdvanceCount(var aCount: Integer);
  end;

procedure RunLocal(var aValue: TImportedRecord);
procedure RunMember(var aValue: TMethodRecord);
procedure RunAmbiguous(var aValue: TImportedRecord);

implementation

uses
  ImportedProcedureProvider;

procedure TMethodRecord.AdvanceCount(var aCount: Integer);
begin
  Inc(aCount, 100);
end;

procedure RunLocal(var aValue: TImportedRecord);

  procedure AdvanceCount(var aCount: Integer);
  begin
    Inc(aCount, 30);
  end;

begin
  with aValue do
  begin
    AdvanceCount(Count);
  end;
end;

procedure RunMember(var aValue: TMethodRecord);
begin
  with aValue do
  begin
    AdvanceCount(Count);
  end;
end;

procedure RunAmbiguous(var aValue: TImportedRecord);
begin
  with aValue do
  begin
    AmbiguousAdvance(Count);
  end;
end;

end.
