program BodyRanges;

{$APPTYPE CONSOLE}

uses
  BodyRangesControlsUnit in 'BodyRangesControlsUnit.pas',
  BodyRangesUnit in 'BodyRangesUnit.pas';

var
  lOuter, lInner: TItem;
begin
  lOuter := Default(TItem);
  lInner := Default(TItem);
  Nested(lOuter, @lInner, True);
  Writeln(lOuter.Value, ',', lInner.Value);
  Nested(lOuter, nil, False);
  Writeln(lOuter.Value, ',', lInner.Value);
  lInner.Value := -1;
  Writeln(Branches(@lInner, False));
  lInner.Value := 7;
  Writeln(Branches(@lInner, True), ',', Branches(@lInner, False));
  lOuter.Value := 0;
  SupportedNested(lOuter, True);
  Writeln(lOuter.Value);
  SupportedNested(lOuter, False);
  Writeln(lOuter.Value);
  lOuter.Value := -1;
  Writeln(SupportedBranches(lOuter, False));
  lOuter.Value := 7;
  Writeln(SupportedBranches(lOuter, True), ',', SupportedBranches(lOuter, False));
  SupportedString(lOuter);
  Writeln(lOuter.Text);
  lOuter.Value := 0;
  BraceBoundary(lOuter, True);
  Writeln(lOuter.Value);
  lOuter.Value := 0;
  BraceBoundary(lOuter, False);
  Writeln(lOuter.Value);
  lOuter.Value := 0;
  ParenBoundary(lOuter, True);
  Writeln(lOuter.Value);
  lOuter.Value := 0;
  ParenBoundary(lOuter, False);
  Writeln(lOuter.Value);
  lOuter.Value := 0;
  MultilineBoundary(lOuter, True);
  Writeln(lOuter.Value);
  lOuter.Value := 0;
  MultilineBoundary(lOuter, False);
  Writeln(lOuter.Value);
  lOuter.Value := 0;
  NestedWithoutElse(lOuter, True);
  Writeln(lOuter.Value);
  lOuter.Value := 0;
  NestedWithoutElse(lOuter, False);
  Writeln(lOuter.Value);
end.
