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

  TDelphiSemanticRemoveWithRequest = record
    Options: TDelphiSemanticApiOptions;
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
  lSession := OpenProjectSession(aRequest.Options);
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

    Result := lSession.Session.PlanRemoveWith(aRequest.BodyAnalysisSourceFileNames);
  finally
    lSession.Session.Free;
  end;
end;

end.
