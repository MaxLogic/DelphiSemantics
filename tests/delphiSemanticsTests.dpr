program delphiSemanticsTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Test.ProjectContext in 'src\test.projectcontext.pas',
  Test.Smoke in 'src\test.smoke.pas';

var
  lRunner: ITestRunner;
  lResults: IRunResults;
  lLogger: ITestLogger;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;
    lRunner := TDUnitX.CreateRunner;
    lRunner.UseRTTI := True;
    lRunner.FailsOnNoAsserts := True;

    lLogger := TDUnitXConsoleLogger.Create(True);
    lRunner.AddLogger(lLogger);

    lResults := lRunner.Execute;
    if not lResults.AllPassed then
      System.ExitCode := 1
    else
      System.ExitCode := 0;
  except
    on E: Exception do
    begin
      Writeln(E.ClassName, ': ', E.Message);
      System.ExitCode := 1;
    end;
  end;
end.
