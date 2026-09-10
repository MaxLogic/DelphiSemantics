unit PrivateProcedureConsumer;

interface

type
  TPrivateRecord = record
    Count: Integer;
  end;

procedure RunPrivate(var aValue: TPrivateRecord);

implementation

uses
  UnimportedProcedureProvider;

procedure RunPrivate(var aValue: TPrivateRecord);
begin
  with aValue do
  begin
    HiddenAdvanceCount(Count);
  end;
end;

end.
