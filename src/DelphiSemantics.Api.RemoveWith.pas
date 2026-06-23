unit DelphiSemantics.Api.RemoveWith;

interface

uses
  DelphiSemantics.Api, DelphiSemantics.RemoveWithPlan;

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
  TDelphiSemanticRemoveWithPlan =
    DelphiSemantics.RemoveWithPlan.TDelphiSemanticRemoveWithPlan;

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
  DelphiSemantics.ProjectSession;

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

    Result := lSession.Session.PlanRemoveWith(aRequest.BodyAnalysisSourceFileNames);
    Result.Diagnostics := Copy(lSession.Diagnostics);
  finally
    lSession.Session.Free;
  end;
end;

end.
