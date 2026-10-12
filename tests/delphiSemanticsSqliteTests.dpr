program delphiSemanticsSqliteTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console, DUnitX.TestFramework,
  DelphiSemantics.Api in '..\src\DelphiSemantics.Api.pas',
  DelphiSemantics.Api.ProjectOptions in '..\src\DelphiSemantics.Api.ProjectOptions.pas',
  DelphiSemantics.Api.WithBinding in '..\src\DelphiSemantics.Api.WithBinding.pas',
  DelphiSemantics.Cache in '..\src\DelphiSemantics.Cache.pas',
  DelphiSemantics.Cache.Sqlite in '..\src\DelphiSemantics.Cache.Sqlite.pas',
  DelphiSemantics.CompilerProfile in '..\src\DelphiSemantics.CompilerProfile.pas',
  DelphiSemantics.DeadCode in '..\src\DelphiSemantics.DeadCode.pas',
  DelphiSemantics.ExternalSymbols in '..\src\DelphiSemantics.ExternalSymbols.pas',
  DelphiSemantics.Index in '..\src\DelphiSemantics.Index.pas',
  DelphiSemantics.Index.LegacyModel in '..\src\DelphiSemantics.Index.LegacyModel.pas',
  DelphiSemantics.Lsp in '..\src\DelphiSemantics.Lsp.pas',
  DelphiSemantics.Model in '..\src\DelphiSemantics.Model.pas',
  DelphiSemantics.Model.Coordinates in '..\src\DelphiSemantics.Model.Coordinates.pas',
  DelphiSemantics.Model.Extract in '..\src\DelphiSemantics.Model.Extract.pas',
  DelphiSemantics.Model.Json in '..\src\DelphiSemantics.Model.Json.pas',
  DelphiSemantics.Model.Text in '..\src\DelphiSemantics.Model.Text.pas',
  DelphiSemantics.Preprocess in '..\src\DelphiSemantics.Preprocess.pas',
  DelphiSemantics.ProjectContext in '..\src\DelphiSemantics.ProjectContext.pas',
  DelphiSemantics.Query in '..\src\DelphiSemantics.Query.pas',
  DelphiSemantics.Refactor in '..\src\DelphiSemantics.Refactor.pas',
  DelphiSemantics.RemoveWith.Visibility in '..\src\DelphiSemantics.RemoveWith.Visibility.pas',
  DelphiSemantics.Resolve in '..\src\DelphiSemantics.Resolve.pas',
  DelphiSemantics.Resolve.MemberResolver in '..\src\DelphiSemantics.Resolve.MemberResolver.pas',
  DelphiSemantics.Resolve.ScopeResolver in '..\src\DelphiSemantics.Resolve.ScopeResolver.pas',
  DelphiSemantics.Resolve.SelectorTypes in '..\src\DelphiSemantics.Resolve.SelectorTypes.pas',
  DelphiSemantics.Resolve.TypeResolver in '..\src\DelphiSemantics.Resolve.TypeResolver.pas',
  DelphiSemantics.Resolve.UnitResolver in '..\src\DelphiSemantics.Resolve.UnitResolver.pas',
  DelphiSemantics.Search in '..\src\DelphiSemantics.Search.pas',
  DelphiSemantics.SemanticGraph in '..\src\DelphiSemantics.SemanticGraph.pas',
  DelphiSemantics.RootMemberAbsence in '..\src\DelphiSemantics.RootMemberAbsence.pas',
  DelphiSemantics.Snapshot in '..\src\DelphiSemantics.Snapshot.pas',
  DelphiSemantics.Snapshot.Builder in '..\src\DelphiSemantics.Snapshot.Builder.pas',
  DelphiSemantics.Snapshot.Cache.Sqlite in '..\src\DelphiSemantics.Snapshot.Cache.Sqlite.pas',
  DelphiSemantics.Snapshot.PositionResolver in '..\src\DelphiSemantics.Snapshot.PositionResolver.pas',
  DelphiSemantics.Snapshot.QuerySupport in '..\src\DelphiSemantics.Snapshot.QuerySupport.pas',
  DelphiSemantics.Snapshot.RemoveWith in '..\src\DelphiSemantics.Snapshot.RemoveWith.pas',
  DelphiSemantics.Snapshot.Workers in '..\src\DelphiSemantics.Snapshot.Workers.pas',
  DelphiSemantics.Source in '..\src\DelphiSemantics.Source.pas',
  DelphiSemantics.SourceConditionals in '..\src\DelphiSemantics.SourceConditionals.pas',
  DelphiSemantics.SourceContext in '..\src\DelphiSemantics.SourceContext.pas',
  DelphiSemantics.SourceContext.Candidates in '..\src\DelphiSemantics.SourceContext.Candidates.pas',
  DelphiSemantics.Symbols in '..\src\DelphiSemantics.Symbols.pas',
  DelphiSemantics.Usage in '..\src\DelphiSemantics.Usage.pas',
  DelphiSemantics.Version in '..\src\DelphiSemantics.Version.pas',
  DelphiSemantics.WithBinding in '..\src\DelphiSemantics.WithBinding.pas',
  DelphiSemantics.WithBinding.Inventory in '..\src\DelphiSemantics.WithBinding.Inventory.pas',
  DelphiSemantics.WithScan in '..\src\DelphiSemantics.WithScan.pas',
  Test.CacheSqlite in 'src\test.cachesqlite.pas',
  Test.SnapshotSqlite in 'src\test.snapshotsqlite.pas',
  Test.Support in 'src\test.support.pas';

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
