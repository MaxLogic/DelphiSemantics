program CollisionReceiver;

{$APPTYPE CONSOLE}

uses
  HiddenTypes in 'HiddenTypes.pas',
  Provider in 'Provider.pas',
  ShadowConsumer in 'ShadowConsumer.pas';

begin
  RunShadow;
  Writeln(FirstItem.Value, ',', SecondItem.Value);
end.
