program InlineHeader;
{$APPTYPE CONSOLE}
uses System.SysUtils, InlineHeaderUnit in 'InlineHeaderUnit.pas';
var
  lValue: TVector;
begin
  lValue := Default(TVector);
  lValue.v[2, 1] := 99;
  RunArray(lValue);
  Writeln(lValue.v[1, 1], ',', lValue.v[2, 1]);
  lValue := Default(TVector);
  lValue.n := 3;
  RunInitializer(lValue);
  Writeln(lValue.n, ',', lValue.v[1, 1]);
  lValue := Default(TVector);
  lValue.n := 3;
  RunFor(lValue);
  Writeln(lValue.n, ',', lValue.v[1, 1]);
  lValue := Default(TVector);
  lValue.e := Exception.Create('field');
  try
    RunHandler(lValue);
    Writeln(lValue.v[1, 1]);
  finally
    lValue.e.Free;
  end;
end.
