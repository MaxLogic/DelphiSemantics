program ImportedProcedure;

{$APPTYPE CONSOLE}

uses
  ImportedProcedureConsumer in 'ImportedProcedureConsumer.pas',
  ImportedProcedureControls in 'ImportedProcedureControls.pas',
  ImportedProcedureProvider in 'ImportedProcedureProvider.pas';

procedure RunCases;
var
  lMember: TMethodRecord;
  lValue: TImportedRecord;
begin
  lValue.Count := 4;
  RunImported(lValue);
  Writeln(lValue.Count);
  lValue.Count := 4;
  RunQualified(lValue);
  Writeln(lValue.Count);
  lValue.Count := 4;
  RunValue(lValue);
  Writeln(lValue.Count);
  lValue.Count := 4;
  RunLocal(lValue);
  Writeln(lValue.Count);
  lMember.Count := 4;
  RunMember(lMember);
  Writeln(lMember.Count);
  lValue.Count := 4;
  RunAmbiguous(lValue);
  Writeln(lValue.Count);
end;

begin
  RunCases;
end.
