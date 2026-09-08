program LocalReceiver;

{$APPTYPE CONSOLE}

uses
  LocalConsumer in 'LocalConsumer.pas';

begin
  Writeln(RunLocal);
  Writeln(RunNested);
end.
