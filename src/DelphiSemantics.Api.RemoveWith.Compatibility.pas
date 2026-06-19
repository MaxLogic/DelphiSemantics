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
  TDelphiSemanticRemoveWithOptions =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithOptions;
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

  TDelphiSemanticRemoveWithFactBuildResult = record
    Success: Boolean;
    Facts: TDelphiSemanticProjectWithBindingFacts;
    Metrics: TDelphiSemanticProjectWithBindingMetrics;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
  end;

  TDelphiSemanticRemoveWithCompatibilityApi = record
  public
    class function BuildProjectWithBindingFacts(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticProjectWithBindingFacts; overload; static;
    class function BuildProjectWithBindingFacts(const aRequest: TDelphiSemanticRemoveWithRequest):
      TDelphiSemanticProjectWithBindingFacts; overload; static;
    class function BuildProjectWithBindingFactsResult(
      const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticRemoveWithFactBuildResult; overload; static;
    class function BuildProjectWithBindingFactsResult(
      const aRequest: TDelphiSemanticRemoveWithRequest):
      TDelphiSemanticRemoveWithFactBuildResult; overload; static;
    class function PlanRemoveWith(const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; static;
    class function PlanRemoveWithSnapshot(
      const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; static;
  end;

implementation

uses
  System.SysUtils,
  DelphiSemantics.Api.ProjectOptions, DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder;

function ProjectOptionsFromRemoveWithRequest(
  const aRequest: TDelphiSemanticRemoveWithRequest): TDelphiSemanticOptions;
begin
  Result := ProjectOptionsFromApiOptions(aRequest.Options);
  Result.SkipWithBindingSemanticGraph := aRequest.RemoveWithOptions.SkipSemanticGraph;
end;

function OpenProjectSession(const aRequest: TDelphiSemanticRemoveWithRequest):
  TDelphiSemanticProjectSessionResult;
begin
  Result := TDelphiSemanticProjectSession.Open(
    ProjectOptionsFromRemoveWithRequest(aRequest));
end;

function FactBuildFailure(const aCode, aMessage, aFileName: string):
  TDelphiSemanticRemoveWithFactBuildResult;
begin
  Result := Default(TDelphiSemanticRemoveWithFactBuildResult);
  Result.Success := False;
  SetLength(Result.Diagnostics, 1);
  Result.Diagnostics[0].Code := aCode;
  Result.Diagnostics[0].Message := aMessage;
  Result.Diagnostics[0].FileName := aFileName;
  Result.Diagnostics[0].Severity := dsError;
end;

function FactBuildSessionFailure(const aSession:
  TDelphiSemanticProjectSessionResult): TDelphiSemanticRemoveWithFactBuildResult;
begin
  Result := Default(TDelphiSemanticRemoveWithFactBuildResult);
  Result.Success := False;
  Result.Diagnostics := Copy(aSession.Diagnostics);
  if Length(Result.Diagnostics) = 0 then
    Result := FactBuildFailure('REMOVE_WITH_PROJECT_SESSION_FAILED',
      'Cannot open project session.', '');
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
  lResult: TDelphiSemanticRemoveWithFactBuildResult;
begin
  lResult := BuildProjectWithBindingFactsResult(aRequest);
  Result := lResult.Facts;
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFactsResult(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticRemoveWithFactBuildResult;
var
  lRequest: TDelphiSemanticRemoveWithRequest;
begin
  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options := aOptions;
  Result := BuildProjectWithBindingFactsResult(lRequest);
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFactsResult(
  const aRequest: TDelphiSemanticRemoveWithRequest):
  TDelphiSemanticRemoveWithFactBuildResult;
var
  lSession: TDelphiSemanticProjectSessionResult;
begin
  Result := Default(TDelphiSemanticRemoveWithFactBuildResult);
  try
    lSession := OpenProjectSession(aRequest);
    try
      if (not lSession.Success) or (lSession.Session = nil) then
        Exit(FactBuildSessionFailure(lSession));

      Result.Facts := lSession.Session.BuildWithBindingFacts(
        aRequest.BodyAnalysisSourceFileNames);
      Result.Metrics := Result.Facts.Metrics;
      Result.Diagnostics := Copy(lSession.Diagnostics);
      Result.Success := Result.Facts.ContextFingerprint <> '';
      if not Result.Success then
        Result := FactBuildFailure('REMOVE_WITH_FACTS_CONTEXT_FINGERPRINT_MISSING',
          'DelphiSemantics project facts did not return a context fingerprint.',
          aRequest.Options.ProjectFileName);
    finally
      lSession.Session.Free;
    end;
  except
    on E: Exception do
      Result := FactBuildFailure('REMOVE_WITH_FACT_BUILD_EXCEPTION', E.Message,
        aRequest.Options.ProjectFileName);
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
