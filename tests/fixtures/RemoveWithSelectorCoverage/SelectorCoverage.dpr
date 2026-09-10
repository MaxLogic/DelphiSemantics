program SelectorCoverage;

{$APPTYPE CONSOLE}

uses
  SelectorCoverageProvider in 'SelectorCoverageProvider.pas',
  SelectorCoverageUnit in 'SelectorCoverageUnit.pas';

procedure RunCases;
var
  i: Integer;
  lContainer: TContainer;
  lKnown: TItem;
  lOuter: TOuter;
begin
  lOuter := Default(TOuter);
  lOuter.Indexes[0, 0] := 1;
  for i := 0 to 1 do
  begin
    lContainer.Items.Data[i].Value := 20;
  end;
  gOwners[0] := @lContainer;
  RunNested(lOuter);
  Writeln(lContainer.Items.Data[1].Value);
  lContainer.Items.Data[1].Value := 20;
  lKnown.Value := 100;
  RunPartial(lOuter, lKnown);
  Writeln(lContainer.Items.Data[1].Value, ',', lKnown.Value);
  RunNormal(lKnown);
  Writeln(lKnown.Value);
end;

begin
  RunCases;
end.
