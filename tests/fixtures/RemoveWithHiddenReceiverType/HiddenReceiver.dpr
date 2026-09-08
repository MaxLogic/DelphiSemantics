program HiddenReceiver;

{$APPTYPE CONSOLE}

uses
  AliasConsumer in 'AliasConsumer.pas',
  Consumer in 'Consumer.pas',
  DirectConsumer in 'DirectConsumer.pas',
  HiddenTypes in 'HiddenTypes.pas',
  InactiveConsumer in 'InactiveConsumer.pas',
  Provider in 'Provider.pas';

begin
  RunHidden;
  Writeln(FirstItem.Value, ',', SecondItem.Value);
  RunInactive;
  Writeln(FirstItem.Value, ',', SecondItem.Value);
  RunDirect;
  Writeln(FirstItem.Value, ',', SecondItem.Value);
  RunAlias;
  Writeln(FirstItem.Value, ',', SecondItem.Value);
end.
