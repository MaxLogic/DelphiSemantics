unit DelphiSemantics.Api.RemoveWith;

interface

uses
  DelphiSemantics.Api, DelphiSemantics.RemoveWithPlan, DelphiSemantics.WithBinding;

type
  TDelphiSemanticRemoveWithSourceRange =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSourceRange;
  TDelphiSemanticRemoveWithVerification =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithVerification;
  TDelphiSemanticRemoveWithEdit =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithEdit;
  TDelphiSemanticRemoveWithSkippedStatement =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSkippedStatement;
  TDelphiSemanticRemoveWithSourceVerification =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSourceVerification;
  TDelphiSemanticRemoveWithFinalTempDecision =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithFinalTempDecision;
  TDelphiSemanticRemoveWithFinalTextEdit =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithFinalTextEdit;
  TDelphiSemanticRemoveWithFinalStatement =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithFinalStatement;
  TDelphiSemanticRemoveWithPlanParityEdit =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlanParityEdit;
  TDelphiSemanticRemoveWithPlanParityStatement =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlanParityStatement;
  TDelphiSemanticRemoveWithPlanParityMismatch =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlanParityMismatch;
  TDelphiSemanticRemoveWithPlanParityReport =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlanParityReport;
  TDelphiSemanticRemoveWithPlan =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlan;
  TDelphiSemanticRemoveWithPlanner =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlanner;
  TDelphiSemanticRemoveWithPlanParity =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlanParity;
  TDelphiSemanticRemoveWithLookupMetrics =
    DelphiSemantics.WithBinding.TDelphiSemanticRemoveWithLookupMetrics;
  TDelphiSemanticRemoveWithLookupIndex =
    DelphiSemantics.WithBinding.TDelphiSemanticRemoveWithLookupIndex;
  TDelphiSemanticInventorySymbol = DelphiSemantics.WithBinding.TDelphiSemanticInventorySymbol;
  TDelphiSemanticWithBinding = DelphiSemantics.WithBinding.TDelphiSemanticWithBinding;
  TDelphiSemanticProjectWithBindingMetrics =
    DelphiSemantics.WithBinding.TDelphiSemanticProjectWithBindingMetrics;
  TDelphiSemanticProjectWithBindingFacts =
    DelphiSemantics.WithBinding.TDelphiSemanticProjectWithBindingFacts;
  TDelphiSemanticRemoveWithInventory =
    DelphiSemantics.WithBinding.TDelphiSemanticRemoveWithInventory;
  TDelphiSemanticWithBinder = DelphiSemantics.WithBinding.TDelphiSemanticWithBinder;

  TDelphiSemanticRemoveWithApi = record
  public
    class function BuildProjectWithBindingFacts(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticProjectWithBindingFacts; static;
    class function PlanRemoveWith(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function PlanRemoveWith(const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function PlanRemoveWithSnapshot(
      const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; static;
  end;

implementation

uses
  DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession, DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.Builder;

function ProjectOptionsFromApiOptions(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticOptions;
begin
  Result := Default(TDelphiSemanticOptions);
  Result.ProjectPath := aOptions.ProjectFileName;
  Result.Configuration := aOptions.Configuration;
  Result.Platform := aOptions.Platform;
  Result.DelphiVersion := aOptions.DelphiVersion;
  Result.RsVarsPath := aOptions.RsVarsPath;
  Result.EnvOptionsPath := aOptions.EnvOptionsPath;
  Result.EnvironmentVariables := aOptions.EnvironmentVariables;
  Result.AdditionalSourceFileNames := aOptions.AdditionalSourceFileNames;
  Result.BodyAnalysisSourceFileNames := aOptions.BodyAnalysisSourceFileNames;
  Result.SqliteCacheFileName := aOptions.Cache.SqliteCacheFileName;
  Result.UseLspEnrichment := aOptions.UseLspEnrichment;
  Result.SkipWithBindingSemanticGraph := aOptions.SkipWithBindingSemanticGraph;
end;

function OpenProjectSession(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticProjectSessionResult;
var
  lOptions: TDelphiSemanticOptions;
begin
  lOptions := ProjectOptionsFromApiOptions(aOptions);
  if lOptions.ProjectPath = '' then
    lOptions.ProjectPath := aOptions.ProjectFileName;
  Result := TDelphiSemanticProjectSession.Open(lOptions);
end;

class function TDelphiSemanticRemoveWithApi.BuildProjectWithBindingFacts(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticProjectWithBindingFacts;
var
  lSession: TDelphiSemanticProjectSessionResult;
begin
  lSession := OpenProjectSession(aOptions);
  try
    if (not lSession.Success) or (lSession.Session = nil) then
      Exit(Default(TDelphiSemanticProjectWithBindingFacts));

    Result := lSession.Session.BuildWithBindingFacts;
  finally
    lSession.Session.Free;
  end;
end;

class function TDelphiSemanticRemoveWithApi.PlanRemoveWith(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticRemoveWithPlan;
var
  lSession: TDelphiSemanticProjectSessionResult;
begin
  lSession := OpenProjectSession(aOptions);
  try
    if (not lSession.Success) or (lSession.Session = nil) then
    begin
      Result := Default(TDelphiSemanticRemoveWithPlan);
      Result.Operation := 'remove-with';
      Result.Status := 'blocked';
      Result.BaselineSemanticModelVersion := 'project-snapshot-v1';
      Result.Diagnostic := 'Cannot open project session.';
      Exit;
    end;

    Result := lSession.Session.PlanRemoveWith;
  finally
    lSession.Session.Free;
  end;
end;

class function TDelphiSemanticRemoveWithApi.PlanRemoveWith(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
begin
  Result := TDelphiSemanticRemoveWithPlanner.Plan(aFacts);
end;

class function TDelphiSemanticRemoveWithApi.PlanRemoveWithSnapshot(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
var
  lSnapshot: TDelphiProjectSnapshot;
begin
  lSnapshot := BuildRemoveWithPlanningSnapshotFromFacts(aFacts);
  try
    Result := TDelphiSemanticRemoveWithPlanner.Plan(lSnapshot);
  finally
    lSnapshot.Free;
  end;
end;

end.
