program delphiSemanticsTests;

{$APPTYPE CONSOLE}
{$STRONGLINKTYPES ON}

uses
  System.SysUtils,
  DUnitX.FilterBuilder, DUnitX.Loggers.Console, DUnitX.TestFramework,
  DelphiSemantics.Api in '..\src\DelphiSemantics.Api.pas',
  DelphiSemantics.Api.ProjectOptions in '..\src\DelphiSemantics.Api.ProjectOptions.pas',
  DelphiSemantics.Api.RemoveWith in '..\src\DelphiSemantics.Api.RemoveWith.pas',
  DelphiSemantics.Api.RemoveWith.Compatibility in '..\src\DelphiSemantics.Api.RemoveWith.Compatibility.pas',
  DelphiSemantics.Api.WithBinding in '..\src\DelphiSemantics.Api.WithBinding.pas',
  DelphiSemantics.Cache in '..\src\DelphiSemantics.Cache.pas',
  DelphiSemantics.Cache.Sqlite in '..\src\DelphiSemantics.Cache.Sqlite.pas',
  DelphiSemantics.CompilerProfile in '..\src\DelphiSemantics.CompilerProfile.pas',
  DelphiSemantics.Consistency.EventBindings in '..\src\DelphiSemantics.Consistency.EventBindings.pas',
  DelphiSemantics.Consistency.EventSignatures in '..\src\DelphiSemantics.Consistency.EventSignatures.pas',
  DelphiSemantics.Consistency.GuidInventory in '..\src\DelphiSemantics.Consistency.GuidInventory.pas',
  DelphiSemantics.Consistency.Types in '..\src\DelphiSemantics.Consistency.Types.pas',
  DelphiSemantics.DeadCode in '..\src\DelphiSemantics.DeadCode.pas',
  DelphiSemantics.ExternalSymbols in '..\src\DelphiSemantics.ExternalSymbols.pas',
  DelphiSemantics.GlobalVars in '..\src\DelphiSemantics.GlobalVars.pas',
  DelphiSemantics.Graph in '..\src\DelphiSemantics.Graph.pas',
  DelphiSemantics.IdentifierScope in '..\src\DelphiSemantics.IdentifierScope.pas',
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
  DelphiSemantics.ProjectSession in '..\src\DelphiSemantics.ProjectSession.pas',
  DelphiSemantics.Query in '..\src\DelphiSemantics.Query.pas',
  DelphiSemantics.Refactor in '..\src\DelphiSemantics.Refactor.pas',
  DelphiSemantics.Refactor.Binding in '..\src\DelphiSemantics.Refactor.Binding.pas',
  DelphiSemantics.Refactor.Plan in '..\src\DelphiSemantics.Refactor.Plan.pas',
  DelphiSemantics.Refactor.SignatureAlignment in '..\src\DelphiSemantics.Refactor.SignatureAlignment.pas',
  DelphiSemantics.Refactor.UnitOrder in '..\src\DelphiSemantics.Refactor.UnitOrder.pas',
  DelphiSemantics.Refactor.UsesPlanner in '..\src\DelphiSemantics.Refactor.UsesPlanner.pas',
  DelphiSemantics.RemoveWith.Visibility in '..\src\DelphiSemantics.RemoveWith.Visibility.pas',
  DelphiSemantics.RemoveWithPlan in '..\src\DelphiSemantics.RemoveWithPlan.pas',
  DelphiSemantics.RemoveWithPlan.FinalBodyRenderer in '..\src\DelphiSemantics.RemoveWithPlan.FinalBodyRenderer.pas',
  DelphiSemantics.RemoveWithPlan.FinalRewrite in '..\src\DelphiSemantics.RemoveWithPlan.FinalRewrite.pas',
  DelphiSemantics.Resolve in '..\src\DelphiSemantics.Resolve.pas',
  DelphiSemantics.Resolve.MemberResolver in '..\src\DelphiSemantics.Resolve.MemberResolver.pas',
  DelphiSemantics.Resolve.ScopeResolver in '..\src\DelphiSemantics.Resolve.ScopeResolver.pas',
  DelphiSemantics.Resolve.SelectorTypes in '..\src\DelphiSemantics.Resolve.SelectorTypes.pas',
  DelphiSemantics.Resolve.TypeResolver in '..\src\DelphiSemantics.Resolve.TypeResolver.pas',
  DelphiSemantics.Resolve.UnitResolver in '..\src\DelphiSemantics.Resolve.UnitResolver.pas',
  DelphiSemantics.Search in '..\src\DelphiSemantics.Search.pas',
  DelphiSemantics.SemanticGraph in '..\src\DelphiSemantics.SemanticGraph.pas',
  DelphiSemantics.Snapshot in '..\src\DelphiSemantics.Snapshot.pas',
  DelphiSemantics.Snapshot.Builder in '..\src\DelphiSemantics.Snapshot.Builder.pas',
  DelphiSemantics.Snapshot.Cache.Sqlite in '..\src\DelphiSemantics.Snapshot.Cache.Sqlite.pas',
  DelphiSemantics.Snapshot.ContextEvidence in '..\src\DelphiSemantics.Snapshot.ContextEvidence.pas',
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
  Test.Api in 'src\test.api.pas',
  Test.Cache in 'src\test.cache.pas',
  Test.CacheSqlite in 'src\test.cachesqlite.pas',
  Test.CompilerProfile in 'src\test.compilerprofile.pas',
  Test.DeadCode in 'src\test.deadcode.pas',
  Test.DependencyGraph in 'src\test.dependencygraph.pas',
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
  Test.Refactor.Consistency in 'src\test.refactor.consistency.pas',
  Test.Refactor.FunctionResult in 'src\test.refactor.functionresult.pas',
  Test.Refactor.Plan in 'src\test.refactor.plan.pas',
  Test.Refactor.RemoveDeadCode in 'src\test.refactor.removedeadcode.pas',
  Test.Refactor.Rename in 'src\test.refactor.rename.pas',
  Test.Refactor.SignatureAlignment in 'src\test.refactor.signaturealignment.pas',
  Test.Refactor.UsesPlanner in 'src\test.refactor.usesplanner.pas',
  Test.RemoveWithPlan in 'src\test.removewithplan.pas',
  Test.ResolverLevel1 in 'src\test.resolverlevel1.pas',
  Test.ResolverLevel2 in 'src\test.resolverlevel2.pas',
  Test.ResolverLevel3 in 'src\test.resolverlevel3.pas',
  Test.ScopeResolver in 'src\test.scoperesolver.pas',
  Test.Search in 'src\test.search.pas',
  Test.SemanticGraph in 'src\test.semanticgraph.pas',
  Test.SemanticGraphDeclarations in 'src\test.semanticgraphdeclarations.pas',
  Test.SemanticGraphReferences in 'src\test.semanticgraphreferences.pas',
  Test.SemanticInvalidation in 'src\test.semanticinvalidation.pas',
  Test.Smoke in 'src\test.smoke.pas',
  Test.Snapshot in 'src\test.snapshot.pas',
  Test.SnapshotSqlite in 'src\test.snapshotsqlite.pas',
  Test.SourceContext in 'src\test.sourcecontext.pas',
  Test.SourceLoader in 'src\test.sourceloader.pas',
  Test.Support in 'src\test.support.pas',
  Test.SymbolQuery in 'src\test.symbolquery.pas',
  Test.TypeResolver in 'src\test.typeresolver.pas',
  Test.UnitModel in 'src\test.unitmodel.pas',
  Test.UnitResolver in 'src\test.unitresolver.pas',
  Test.Usage in 'src\test.usage.pas',
  Test.WithBinder in 'src\test.withbinder.pas',
  Test.WithBinding in 'src\test.withbinding.pas',
  Test.WithDiscovery in 'src\test.withdiscovery.pas',
  Test.WithScan in 'src\test.withscan.pas';

const
  cMaxTdbProofCategory = 'MaxTdbProof';

procedure ApplyDefaultCategoryExclusions;
begin
  if (TDUnitX.Options.Include = '') and (TDUnitX.Options.Exclude = '') then
  begin
    TDUnitX.Options.Exclude := cMaxTdbProofCategory;
    TDUnitX.Filter := TDUnitXFilterBuilder.BuildFilter(TDUnitX.Options);
  end;
end;

var
  lRunner: ITestRunner;
  lResults: IRunResults;
  lLogger: ITestLogger;
begin
  ReportMemoryLeaksOnShutdown := True;
  try
    TDUnitX.CheckCommandLine;
    ApplyDefaultCategoryExclusions;
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
