program ControlledArray;

{$APPTYPE CONSOLE}

uses
  ControlledArrayShadowUnit in 'ControlledArrayShadowUnit.pas',
  ControlledArrayUnit in 'ControlledArrayUnit.pas',
  ControlledArrayUnsafeUnit in 'ControlledArrayUnsafeUnit.pas';

var
  lIndex: Integer;

procedure Report;
begin
  Writeln(Container.Items[0].Value, ',', Container.Items[1].Value, ',',
    Container.Items[2].Value, ',', lIndex);
end;

begin
  Container := Default(TContainer);
  RunLoop(0, 2, lIndex);
  Report;
  Container := Default(TContainer);
  RunLoop(3, 3, lIndex);
  Report;
  Container := Default(TContainer);
  lIndex := 3;
  RunGuard(False, lIndex);
  Report;
  lIndex := 0;
  RunGuard(True, lIndex);
  Report;
  Container := Default(TContainer);
  lIndex := 0;
  RunPlain(lIndex);
  Report;
  Container := Default(TContainer);
  lIndex := 0;
  RunPointer(lIndex);
  Report;
  Writeln(ReadMethodValue);
  Writeln(ReadIndexerValue);
  Writeln(RunShadowControl);
  Writeln(RunRoutineShadowControl);
end.
