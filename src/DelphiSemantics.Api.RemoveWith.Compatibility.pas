unit DelphiSemantics.Api.RemoveWith.Compatibility;

interface

uses
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith, DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.WithBinding;

type
  TDelphiSemanticRemoveWithRequest =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithRequest;
  TDelphiSemanticRemoveWithSourceRange =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSourceRange;
  TDelphiSemanticRemoveWithVerification =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithVerification;
  TDelphiSemanticRemoveWithEdit =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithEdit;
  TDelphiSemanticRemoveWithSkippedStatement =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSkippedStatement;
  TDelphiSemanticRemoveWithStatement =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithStatement;
  TDelphiSemanticRemoveWithSourceVerification =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSourceVerification;
  TDelphiSemanticRemoveWithPlan =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlan;
  TDelphiSemanticRemoveWithApi =
    DelphiSemantics.Api.RemoveWith.TDelphiSemanticRemoveWithApi;
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

  TDelphiSemanticRemoveWithCombinedMetrics = record
    Facts: TDelphiSemanticProjectWithBindingMetrics;
    SemanticSessionOpenCount: Integer;
    ModelExtractionPassCount: Integer;
  end;

  TDelphiSemanticRemoveWithCombinedResult = record
    Success: Boolean;
    Facts: TDelphiSemanticProjectWithBindingFacts;
    Plan: TDelphiSemanticRemoveWithPlan;
    Metrics: TDelphiSemanticRemoveWithCombinedMetrics;
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
    class function BuildProjectWithBindingFactsAndPlanResult(
      const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticRemoveWithCombinedResult; overload; static;
    class function BuildProjectWithBindingFactsAndPlanResult(
      const aRequest: TDelphiSemanticRemoveWithRequest):
      TDelphiSemanticRemoveWithCombinedResult; overload; static;
    class function PlanRemoveWith(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function PlanRemoveWith(const aRequest: TDelphiSemanticRemoveWithRequest):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function PlanRemoveWith(const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function PlanRemoveWithCompatibilitySnapshot(
      const aFacts: TDelphiSemanticProjectWithBindingFacts):
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

function SessionFailureDiagnostics(const aSession: TDelphiSemanticProjectSessionResult):
  TArray<TDelphiSemanticDiagnostic>;
begin
  Result := Copy(aSession.Diagnostics);
  if Length(Result) > 0 then
    Exit;

  SetLength(Result, 1);
  Result[0].Code := 'REMOVE_WITH_PROJECT_SESSION_FAILED';
  Result[0].Severity := dsError;
  Result[0].Message := 'Cannot open project session.';
end;

function PlanSessionFailure(const aSession: TDelphiSemanticProjectSessionResult):
  TDelphiSemanticRemoveWithPlan;
begin
  Result := Default(TDelphiSemanticRemoveWithPlan);
  Result.Operation := 'remove-with';
  Result.Status := 'blocked';
  Result.BaselineSemanticModelVersion := 'project-snapshot-v1';
  Result.Diagnostics := SessionFailureDiagnostics(aSession);
  Result.Diagnostic := Result.Diagnostics[0].Message;
end;

function CombinedFailure(const aCode, aMessage, aFileName: string):
  TDelphiSemanticRemoveWithCombinedResult;
var
  lFactFailure: TDelphiSemanticRemoveWithFactBuildResult;
begin
  Result := Default(TDelphiSemanticRemoveWithCombinedResult);
  lFactFailure := FactBuildFailure(aCode, aMessage, aFileName);
  Result.Diagnostics := Copy(lFactFailure.Diagnostics);
  Result.Plan.Operation := 'remove-with';
  Result.Plan.Status := 'blocked';
  Result.Plan.BaselineSemanticModelVersion := 'project-snapshot-v1';
  Result.Plan.Diagnostics := Copy(Result.Diagnostics);
  Result.Plan.Diagnostic := Result.Diagnostics[0].Message;
end;

function FactBuildDiagnosticsMessage(const aResult:
  TDelphiSemanticRemoveWithFactBuildResult): string;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
  lLine: string;
begin
  Result := '';
  for lDiagnostic in aResult.Diagnostics do
  begin
    if lDiagnostic.Code <> '' then
      lLine := lDiagnostic.Code
    else begin
      lLine := 'REMOVE_WITH_FACT_BUILD_FAILED';
    end;
    if lDiagnostic.Message <> '' then
      lLine := lLine + ': ' + lDiagnostic.Message;
    if lDiagnostic.FileName <> '' then
      lLine := lLine + ' (' + lDiagnostic.FileName + ')';

    if Result <> '' then
      Result := Result + sLineBreak;
    Result := Result + lLine;
  end;
  if Result = '' then
    Result := 'Remove-with fact building failed without diagnostics.';
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
  if not lResult.Success then
    raise Exception.Create(FactBuildDiagnosticsMessage(lResult));

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

class function TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFactsAndPlanResult(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticRemoveWithCombinedResult;
var
  lRequest: TDelphiSemanticRemoveWithRequest;
begin
  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options := aOptions;
  Result := BuildProjectWithBindingFactsAndPlanResult(lRequest);
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFactsAndPlanResult(
  const aRequest: TDelphiSemanticRemoveWithRequest):
  TDelphiSemanticRemoveWithCombinedResult;
var
  lBuildResult: TDelphiSemanticRemoveWithFactsAndPlanBuildResult;
  lExtractionPassCount: Integer;
  lFailure: TDelphiSemanticRemoveWithCombinedResult;
  lSession: TDelphiSemanticProjectSessionResult;
  lSessionOpenCount: Integer;
begin
  Result := Default(TDelphiSemanticRemoveWithCombinedResult);
  lExtractionPassCount := 0;
  lSessionOpenCount := 0;
  try
    Inc(lSessionOpenCount);
    lSession := OpenProjectSession(aRequest);
    Result.Metrics.SemanticSessionOpenCount := lSessionOpenCount;
    try
      if (not lSession.Success) or (lSession.Session = nil) then
      begin
        Result.Diagnostics := SessionFailureDiagnostics(lSession);
        Result.Plan := PlanSessionFailure(lSession);
        Exit;
      end;

      Inc(lExtractionPassCount);
      lBuildResult := lSession.Session.BuildRemoveWithFactsAndPlanResult(
        aRequest.BodyAnalysisSourceFileNames);
      Result.Facts := lBuildResult.Facts;
      Result.Plan := lBuildResult.Plan;
      Result.Plan.Diagnostics := Copy(lSession.Diagnostics);
      Result.Metrics.Facts := Result.Facts.Metrics;
      Result.Metrics.ModelExtractionPassCount :=
        lBuildResult.ModelExtractionPassCount;
      Result.Diagnostics := Copy(lSession.Diagnostics);
      if Result.Facts.ContextFingerprint = '' then
      begin
        lFailure := CombinedFailure(
          'REMOVE_WITH_FACTS_CONTEXT_FINGERPRINT_MISSING',
          'DelphiSemantics project facts did not return a context fingerprint.',
          aRequest.Options.ProjectFileName);
        lFailure.Metrics.SemanticSessionOpenCount := lSessionOpenCount;
        lFailure.Metrics.ModelExtractionPassCount :=
          Result.Metrics.ModelExtractionPassCount;
        Exit(lFailure);
      end;
      Result.Success := SameText(Result.Plan.Status, 'planned');
    finally
      lSession.Session.Free;
    end;
  except
    on E: Exception do
    begin
      Result := CombinedFailure('REMOVE_WITH_COMBINED_BUILD_EXCEPTION', E.Message,
        aRequest.Options.ProjectFileName);
      Result.Metrics.SemanticSessionOpenCount := lSessionOpenCount;
      Result.Metrics.ModelExtractionPassCount := lExtractionPassCount;
    end;
  end;
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticRemoveWithPlan;
var
  lRequest: TDelphiSemanticRemoveWithRequest;
begin
  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options := aOptions;
  Result := PlanRemoveWith(lRequest);
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(
  const aRequest: TDelphiSemanticRemoveWithRequest): TDelphiSemanticRemoveWithPlan;
var
  lSession: TDelphiSemanticProjectSessionResult;
begin
  lSession := OpenProjectSession(aRequest);
  try
    if (not lSession.Success) or (lSession.Session = nil) then
      Exit(PlanSessionFailure(lSession));

    Result := lSession.Session.PlanRemoveWith(aRequest.BodyAnalysisSourceFileNames);
    Result.Diagnostics := Copy(lSession.Diagnostics);
  finally
    lSession.Session.Free;
  end;
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
begin
  Result := TDelphiSemanticRemoveWithPlanner.Plan(aFacts);
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithCompatibilitySnapshot(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
var
  lSnapshot: TDelphiProjectSnapshot;
begin
  lSnapshot := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(aFacts);
  try
    Result := TDelphiSemanticRemoveWithPlanner.Plan(lSnapshot);
  finally
    lSnapshot.Free;
  end;
end;

class function TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWithSnapshot(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
begin
  Result := PlanRemoveWithCompatibilitySnapshot(aFacts);
end;

end.
