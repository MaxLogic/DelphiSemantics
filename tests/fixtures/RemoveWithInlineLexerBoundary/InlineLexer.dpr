program InlineLexer;
{$APPTYPE CONSOLE}
uses InlineLexerUnit in 'InlineLexerUnit.pas';
var
  lValue: TItem;
begin
  lValue := Default(TItem);
  RunOn(lValue);
  Writeln(lValue.n, ',', lValue.On);
  RunConditional(lValue);
  Writeln(lValue.n, ',', lValue.On);
end.
