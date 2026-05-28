program delphiSemanticsTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.Loggers.Console,
  DUnitX.TestFramework,
  Test.Api in 'src\test.api.pas',
  Test.Cache in 'src\test.cache.pas',
  Test.DependencyGraph in 'src\test.dependencygraph.pas',
  Test.DeadCode in 'src\test.deadcode.pas',
  Test.ExternalSymbols in 'src\test.externalsymbols.pas',
  Test.GlobalVars in 'src\test.globalvars.pas',
  Test.LspBoundary in 'src\test.lspboundary.pas',
  Test.MemberResolver in 'src\test.memberresolver.pas',
  Test.MemberResolverAccessOverloads in 'src\test.memberresolveraccessoverloads.pas',
  Test.MemberResolverInheritedHelpers in 'src\test.memberresolverinheritedhelpers.pas',
  Test.Preprocess in 'src\test.preprocess.pas',
  Test.ProjectContext in 'src\test.projectcontext.pas',
  Test.ProjectMsBuild in 'src\test.projectmsbuild.pas',
  Test.ProjectSession in 'src\test.projectsession.pas',
  Test.Refactor.FunctionResult in 'src\test.refactor.functionresult.pas',
  Test.Refactor.Rename in 'src\test.refactor.rename.pas',
  Test.Refactor.RemoveDeadCode in 'src\test.refactor.removedeadcode.pas',
  Test.RemoveWithPlan in 'src\test.removewithplan.pas',
  Test.ResolverLevel1 in 'src\test.resolverlevel1.pas',
  Test.ResolverLevel2 in 'src\test.resolverlevel2.pas',
  Test.ResolverLevel3 in 'src\test.resolverlevel3.pas',
  Test.ScopeResolver in 'src\test.scoperesolver.pas',
  Test.Search in 'src\test.search.pas',
  Test.SemanticInvalidation in 'src\test.semanticinvalidation.pas',
  Test.SemanticGraph in 'src\test.semanticgraph.pas',
  Test.SemanticGraphDeclarations in 'src\test.semanticgraphdeclarations.pas',
  Test.SemanticGraphReferences in 'src\test.semanticgraphreferences.pas',
  Test.SourceContext in 'src\test.sourcecontext.pas',
  Test.Smoke in 'src\test.smoke.pas',
  Test.SymbolQuery in 'src\test.symbolquery.pas',
  Test.TypeResolver in 'src\test.typeresolver.pas',
  Test.UnitResolver in 'src\test.unitresolver.pas',
  Test.Usage in 'src\test.usage.pas',
  Test.UnitModel in 'src\test.unitmodel.pas',
  Test.WithDiscovery in 'src\test.withdiscovery.pas',
  Test.WithBinding in 'src\test.withbinding.pas',
  Test.WithScan in 'src\test.withscan.pas',
  Test.WithBinder in 'src\test.withbinder.pas';

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
