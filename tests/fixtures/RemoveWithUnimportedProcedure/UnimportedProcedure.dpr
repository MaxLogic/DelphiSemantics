program UnimportedProcedure;

{$APPTYPE CONSOLE}

uses
  PrivateProcedureConsumer in 'PrivateProcedureConsumer.pas',
  UnimportedProcedureConsumer in 'UnimportedProcedureConsumer.pas',
  UnimportedProcedureProvider in 'UnimportedProcedureProvider.pas';

procedure RunCases;
var
  lValue: TImportedRecord;
begin
  lValue.Count := 4;
  RunImported(lValue);
  Writeln(lValue.Count);
end;

begin
  RunCases;
end.
