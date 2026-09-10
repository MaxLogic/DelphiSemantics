program RetainedParentScope;

{$APPTYPE CONSOLE}

uses
  RetainedParentScopeProvider in 'RetainedParentScopeProvider.pas',
  RetainedParentScopeUnit in 'RetainedParentScopeUnit.pas';

begin
  Writeln(RunIndexed);
  Writeln(RunShadowed);
  Writeln(RunOrdinary);
  Writeln(RunInitializer);
  Writeln(RunPacked);
end.
