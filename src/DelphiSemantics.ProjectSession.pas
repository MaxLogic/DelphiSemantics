unit DelphiSemantics.ProjectSession;

interface

uses
  DelphiSemantics.ProjectContext;

type
  TDelphiSemanticProjectSession = class;

  TDelphiSemanticProjectSessionStatus = (psUnavailable, psOpen, psInvalidProject);

  TDelphiSemanticProjectSessionResult = record
    Success: Boolean;
    Status: TDelphiSemanticProjectSessionStatus;
    Provenance: string;
    Session: TDelphiSemanticProjectSession;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
  end;

  TDelphiSemanticProjectSession = class
  private
    fDiagnostics: TArray<TDelphiSemanticDiagnostic>;
    fOptions: TDelphiSemanticOptions;
    fProject: TDelphiSemanticProjectInfo;
    fProvenance: string;
    fStatus: TDelphiSemanticProjectSessionStatus;
  public
    constructor Create(const aOptions: TDelphiSemanticOptions;
      const aProject: TDelphiSemanticProjectInfo;
      const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
      const aStatus: TDelphiSemanticProjectSessionStatus; const aProvenance: string);
    class function Open(const aOptions: TDelphiSemanticOptions):
      TDelphiSemanticProjectSessionResult; static;
    property Diagnostics: TArray<TDelphiSemanticDiagnostic> read fDiagnostics;
    property Options: TDelphiSemanticOptions read fOptions;
    property Project: TDelphiSemanticProjectInfo read fProject;
    property Provenance: string read fProvenance;
    property Status: TDelphiSemanticProjectSessionStatus read fStatus;
  end;

implementation

uses
  System.SysUtils;

function SessionDiagnostic(const aCode, aMessage, aFileName: string;
  const aSeverity: TDelphiSemanticDiagnosticSeverity): TDelphiSemanticDiagnostic;
begin
  Result := Default(TDelphiSemanticDiagnostic);
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Severity := aSeverity;
end;

function SessionFailure(const aContext: TDelphiSemanticContextResult):
  TDelphiSemanticProjectSessionResult;
begin
  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := False;
  Result.Status := psInvalidProject;
  Result.Provenance := 'project-context';
  Result.Diagnostics := Copy(aContext.Diagnostics);
end;

function MissingProjectPathFailure: TDelphiSemanticProjectSessionResult;
begin
  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := False;
  Result.Status := psInvalidProject;
  Result.Provenance := 'project-context';
  SetLength(Result.Diagnostics, 1);
  Result.Diagnostics[0] := SessionDiagnostic('PROJECT_FILE_NOT_SPECIFIED',
    'Project file was not specified.', '', dsError);
end;

constructor TDelphiSemanticProjectSession.Create(const aOptions: TDelphiSemanticOptions;
  const aProject: TDelphiSemanticProjectInfo;
  const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  const aStatus: TDelphiSemanticProjectSessionStatus; const aProvenance: string);
begin
  inherited Create;
  fOptions := aOptions;
  fProject := aProject;
  fDiagnostics := Copy(aDiagnostics);
  fStatus := aStatus;
  fProvenance := aProvenance;
end;

class function TDelphiSemanticProjectSession.Open(const aOptions: TDelphiSemanticOptions):
  TDelphiSemanticProjectSessionResult;
var
  lContext: TDelphiSemanticContextResult;
begin
  if Trim(aOptions.ProjectPath) = '' then
    Exit(MissingProjectPathFailure);

  lContext := TDelphiSemanticProject.Load(aOptions.ProjectPath, aOptions);
  if not lContext.Success then
    Exit(SessionFailure(lContext));

  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := True;
  Result.Status := psOpen;
  Result.Provenance := 'project-context';
  Result.Diagnostics := Copy(lContext.Diagnostics);
  Result.Session := TDelphiSemanticProjectSession.Create(aOptions, lContext.Project,
    lContext.Diagnostics, Result.Status, Result.Provenance);
end;

end.
