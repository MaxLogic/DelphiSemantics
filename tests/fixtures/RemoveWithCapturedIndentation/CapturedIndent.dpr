program CapturedIndent;

{$APPTYPE CONSOLE}

uses
  CapturedIndentUnit in 'CapturedIndentUnit.pas';

begin
  Writeln(RunPointer);
  Writeln(RunIndexed);
  Writeln(RunControlled(True));
  Writeln(RunControlled(False));
end.
