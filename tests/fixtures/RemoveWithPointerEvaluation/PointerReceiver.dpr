program PointerReceiver;

{$APPTYPE CONSOLE}

uses
  PointerReceiverUnit in 'PointerReceiverUnit.pas';

begin
  Writeln(RunObservation);
  Writeln(RunIndexedObservation);
  Writeln(RunFieldObservation);
  Writeln(RunDependentObservation);
  Writeln(RunNestedObservation);
  Writeln(RunRepeatedObservation);
  Writeln(RunRepeatedHeaderObservation);
  Writeln(RunShadowedReceiverObservation);
end.
