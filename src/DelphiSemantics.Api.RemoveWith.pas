unit DelphiSemantics.Api.RemoveWith;

interface

uses
  DelphiSemantics.Api;

type
  TDelphiSemanticRemoveWithSourceRange = record
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticRemoveWithVerification = record
    Kind: string;
    Description: string;
  end;

  TDelphiSemanticRemoveWithEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    ExpectedFileHash: string;
    ExpectedSourceText: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    ApplyMode: string;
    SemanticReason: string;
    SemanticId: string;
    ReferenceIds: TArray<string>;
  end;

  TDelphiSemanticRemoveWithSkippedStatement = record
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    Reason: string;
    SafetyReason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithPlan = record
    Operation: string;
    Status: string;
    ContextFingerprint: string;
    BaselineSemanticModelVersion: string;
    Diagnostic: string;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
    RequiredVerification: TArray<TDelphiSemanticRemoveWithVerification>;
    Edits: TArray<TDelphiSemanticRemoveWithEdit>;
    SkippedStatements: TArray<TDelphiSemanticRemoveWithSkippedStatement>;
  end;

  TDelphiSemanticRemoveWithOptions = record
    SkipSemanticGraph: Boolean;
  end;

  TDelphiSemanticRemoveWithRequest = record
    Options: TDelphiSemanticApiOptions;
    RemoveWithOptions: TDelphiSemanticRemoveWithOptions;
    BodyAnalysisSourceFileNames: TArray<string>;
  end;

  TDelphiSemanticRemoveWithApi = record
  public
    class function PlanRemoveWith(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function PlanRemoveWith(const aRequest: TDelphiSemanticRemoveWithRequest):
      TDelphiSemanticRemoveWithPlan; overload; static;
  end;

implementation

uses
  DelphiSemantics.Api.ProjectOptions, DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession, DelphiSemantics.RemoveWithPlan;

function ProjectOptionsFromRemoveWithRequest(
  const aRequest: TDelphiSemanticRemoveWithRequest): TDelphiSemanticOptions;
begin
  Result := ProjectOptionsFromApiOptions(aRequest.Options);
  if Result.ProjectPath = '' then
    Result.ProjectPath := aRequest.Options.ProjectFileName;
  Result.SkipWithBindingSemanticGraph := aRequest.RemoveWithOptions.SkipSemanticGraph;
end;

function OpenProjectSession(const aRequest: TDelphiSemanticRemoveWithRequest):
  TDelphiSemanticProjectSessionResult;
begin
  Result := TDelphiSemanticProjectSession.Open(
    ProjectOptionsFromRemoveWithRequest(aRequest));
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

function PublicSourceRangeFromInternal(
  const aRange: DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSourceRange):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aRange.StartLine;
  Result.StartColumn := aRange.StartColumn;
  Result.EndLine := aRange.EndLine;
  Result.EndColumn := aRange.EndColumn;
end;

function PublicVerificationFromInternal(
  const aVerification:
  DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithVerification):
  TDelphiSemanticRemoveWithVerification;
begin
  Result.Kind := aVerification.Kind;
  Result.Description := aVerification.Description;
end;

function PublicEditFromInternal(
  const aEdit: DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithEdit):
  TDelphiSemanticRemoveWithEdit;
begin
  Result.Kind := aEdit.Kind;
  Result.FileName := aEdit.FileName;
  Result.StatementId := aEdit.StatementId;
  Result.ExpectedFileHash := aEdit.ExpectedFileHash;
  Result.ExpectedSourceText := aEdit.ExpectedSourceText;
  Result.Range := PublicSourceRangeFromInternal(aEdit.Range);
  Result.ReplacementText := aEdit.ReplacementText;
  Result.ApplyMode := aEdit.ApplyMode;
  Result.SemanticReason := aEdit.SemanticReason;
  Result.SemanticId := aEdit.SemanticId;
  Result.ReferenceIds := Copy(aEdit.ReferenceIds);
end;

function PublicSkippedStatementFromInternal(
  const aStatement:
  DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSkippedStatement):
  TDelphiSemanticRemoveWithSkippedStatement;
begin
  Result.FileName := aStatement.FileName;
  Result.StatementId := aStatement.StatementId;
  Result.Range := PublicSourceRangeFromInternal(aStatement.Range);
  Result.Reason := aStatement.Reason;
  Result.SafetyReason := aStatement.SafetyReason;
  Result.SemanticId := aStatement.SemanticId;
end;

function PublicVerificationsFromInternal(
  const aVerifications:
  TArray<DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithVerification>):
  TArray<TDelphiSemanticRemoveWithVerification>;
var
  lIndex: Integer;
begin
  SetLength(Result, Length(aVerifications));
  for lIndex := 0 to High(aVerifications) do
    Result[lIndex] := PublicVerificationFromInternal(aVerifications[lIndex]);
end;

function PublicEditsFromInternal(
  const aEdits: TArray<DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithEdit>):
  TArray<TDelphiSemanticRemoveWithEdit>;
var
  lIndex: Integer;
begin
  SetLength(Result, Length(aEdits));
  for lIndex := 0 to High(aEdits) do
    Result[lIndex] := PublicEditFromInternal(aEdits[lIndex]);
end;

function PublicSkippedStatementsFromInternal(
  const aStatements:
  TArray<DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithSkippedStatement>):
  TArray<TDelphiSemanticRemoveWithSkippedStatement>;
var
  lIndex: Integer;
begin
  SetLength(Result, Length(aStatements));
  for lIndex := 0 to High(aStatements) do
    Result[lIndex] := PublicSkippedStatementFromInternal(aStatements[lIndex]);
end;

function PublicPlanFromInternal(
  const aPlan: DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlan):
  TDelphiSemanticRemoveWithPlan;
begin
  Result.Operation := aPlan.Operation;
  Result.Status := aPlan.Status;
  Result.ContextFingerprint := aPlan.ContextFingerprint;
  Result.BaselineSemanticModelVersion := aPlan.BaselineSemanticModelVersion;
  Result.Diagnostic := aPlan.Diagnostic;
  Result.Diagnostics := Copy(aPlan.Diagnostics);
  Result.RequiredVerification := PublicVerificationsFromInternal(
    aPlan.RequiredVerification);
  Result.Edits := PublicEditsFromInternal(aPlan.Edits);
  Result.SkippedStatements := PublicSkippedStatementsFromInternal(
    aPlan.SkippedStatements);
end;

class function TDelphiSemanticRemoveWithApi.PlanRemoveWith(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticRemoveWithPlan;
var
  lRequest: TDelphiSemanticRemoveWithRequest;
begin
  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options := aOptions;
  Result := PlanRemoveWith(lRequest);
end;

class function TDelphiSemanticRemoveWithApi.PlanRemoveWith(
  const aRequest: TDelphiSemanticRemoveWithRequest): TDelphiSemanticRemoveWithPlan;
var
  lInternalPlan: DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlan;
  lSession: TDelphiSemanticProjectSessionResult;
begin
  lSession := OpenProjectSession(aRequest);
  try
    if (not lSession.Success) or (lSession.Session = nil) then
    begin
      Result := Default(TDelphiSemanticRemoveWithPlan);
      Result.Operation := 'remove-with';
      Result.Status := 'blocked';
      Result.BaselineSemanticModelVersion := 'project-snapshot-v1';
      Result.Diagnostics := SessionFailureDiagnostics(lSession);
      Result.Diagnostic := Result.Diagnostics[0].Message;
      Exit;
    end;

    lInternalPlan := lSession.Session.PlanRemoveWith(
      aRequest.BodyAnalysisSourceFileNames);
    lInternalPlan.Diagnostics := Copy(lSession.Diagnostics);
    Result := PublicPlanFromInternal(lInternalPlan);
  finally
    lSession.Session.Free;
  end;
end;

end.
