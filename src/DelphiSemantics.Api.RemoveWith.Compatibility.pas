unit DelphiSemantics.Api.RemoveWith.Compatibility;

interface

uses
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith, DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.WithBinding;

type
  TDelphiSemanticRemoveWithRequest =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithRequest;
  TDelphiSemanticRemoveWithSourceRange =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithSourceRange;
  TDelphiSemanticRemoveWithVerification =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithVerification;
  TDelphiSemanticRemoveWithEdit =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithEdit;
  TDelphiSemanticRemoveWithSkippedStatement =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithSkippedStatement;
  TDelphiSemanticRemoveWithSourceVerification =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithSourceVerification;
  TDelphiSemanticRemoveWithPlan =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithPlan;
  TDelphiSemanticRemoveWithFinalTempDecision =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithFinalTempDecision;
  TDelphiSemanticRemoveWithFinalTextEdit =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithFinalTextEdit;
  TDelphiSemanticRemoveWithRewriteSelectorDecision =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithRewriteSelectorDecision;
  TDelphiSemanticRemoveWithRewriteRecipe =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithRewriteRecipe;
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

  TDelphiSemanticRemoveWithCompatibilityApi = record
  public
    class function BuildProjectWithBindingFacts(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticProjectWithBindingFacts; overload; static;
    class function BuildProjectWithBindingFacts(const aRequest: TDelphiSemanticRemoveWithRequest):
      TDelphiSemanticProjectWithBindingFacts; overload; static;
    class function PlanRemoveWith(const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; static;
    class function PlanRemoveWithSnapshot(
      const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; static;
  end;

implementation

uses
  DelphiSemantics.Api.ProjectOptions, DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder;

function OpenProjectSession(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticProjectSessionResult;
var
  lOptions: TDelphiSemanticOptions;
begin
  lOptions := ProjectOptionsFromApiOptions(aOptions);
  Result := TDelphiSemanticProjectSession.Open(lOptions);
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticProjectWithBindingFacts;
var
  lRequest: TDelphiSemanticRemoveWithRequest;
begin
  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options := aOptions;
  Result := BuildProjectWithBindingFacts(lRequest);
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(
  const aRequest: TDelphiSemanticRemoveWithRequest):
  TDelphiSemanticProjectWithBindingFacts;
var
  lSession: TDelphiSemanticProjectSessionResult;
begin
  lSession := OpenProjectSession(aRequest.Options);
  try
    if (not lSession.Success) or (lSession.Session = nil) then
      Exit(Default(TDelphiSemanticProjectWithBindingFacts));

    Result := lSession.Session.BuildWithBindingFacts(
      aRequest.BodyAnalysisSourceFileNames);
  finally
    lSession.Session.Free;
  end;
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
begin
  Result := TDelphiSemanticRemoveWithPlanner.Plan(aFacts);
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithSnapshot(
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
