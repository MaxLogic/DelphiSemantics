program delphiSemanticsTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Test.Cache in 'src\test.cache.pas',
  Test.Preprocess in 'src\test.preprocess.pas',
  Test.ProjectContext in 'src\test.projectcontext.pas',
  Test.ProjectMsBuild in 'src\test.projectmsbuild.pas',
  Test.SourceContext in 'src\test.sourcecontext.pas',
  Test.Smoke in 'src\test.smoke.pas',
  Test.UnitModel in 'src\test.unitmodel.pas';

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
