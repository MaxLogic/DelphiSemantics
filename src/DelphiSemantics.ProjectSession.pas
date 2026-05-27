unit DelphiSemantics.ProjectSession;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.SemanticGraph,
  DelphiSemantics.WithBinding;

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
    fLastSemanticGraphBuildMetrics: TDelphiSemanticGraphBuildMetrics;
    fOptions: TDelphiSemanticOptions;
    fProject: TDelphiSemanticProjectInfo;
    fProvenance: string;
    fStatus: TDelphiSemanticProjectSessionStatus;
  public
    constructor Create(const aOptions: TDelphiSemanticOptions;
      const aProject: TDelphiSemanticProjectInfo;
      const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
      const aStatus: TDelphiSemanticProjectSessionStatus; const aProvenance: string);
    function BuildSemanticGraph: TDelphiSemanticSemanticGraph;
    function BuildWithBindingFacts: TDelphiSemanticProjectWithBindingFacts;
    class function Open(const aOptions: TDelphiSemanticOptions):
      TDelphiSemanticProjectSessionResult; static;
    property Diagnostics: TArray<TDelphiSemanticDiagnostic> read fDiagnostics;
    property LastSemanticGraphBuildMetrics: TDelphiSemanticGraphBuildMetrics
      read fLastSemanticGraphBuildMetrics;
    property Options: TDelphiSemanticOptions read fOptions;
    property Project: TDelphiSemanticProjectInfo read fProject;
    property Provenance: string read fProvenance;
    property Status: TDelphiSemanticProjectSessionStatus read fStatus;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.SysUtils,
  MaxLogic.StrUtils;

function MainModelOptions(const aProject: TDelphiSemanticProjectInfo):
  TDelphiSemanticModelOptions;
begin
  Result := Default(TDelphiSemanticModelOptions);
  Result.SourceFileName := aProject.MainSourceFileName;
  Result.Defines := aProject.Defines;
  Result.SearchPaths := aProject.SourceLookupPaths;
  Result.ProjectContextApplied := True;
end;

function ExtractMainModel(const aProject: TDelphiSemanticProjectInfo):
  TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := MainModelOptions(aProject);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  if (Result.Success) and (Result.UnitName = '') and
    SameText(Result.FileName, aProject.MainSourceFileName) then
    Result.UnitName := aProject.ProjectName;
end;

function ExtractUnitModel(const aProject: TDelphiSemanticProjectInfo; const aFileName: string):
  TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := MainModelOptions(aProject);
  lOptions.SourceFileName := aFileName;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo):
  TArray<TDelphiSemanticUnitModel>;
var
  lFileName: string;
  lModel: TDelphiSemanticUnitModel;
  lModels: TList<TDelphiSemanticUnitModel>;
  lSeen: TDictionary<string, Byte>;
  lSourceFileName: string;
begin
  lModels := nil;
  lSeen := nil;
  try
    lModels := TList<TDelphiSemanticUnitModel>.Create;
    lSeen := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    lModel := ExtractMainModel(aProject);
    if lModel.FileName <> '' then
      lSeen.AddOrSetValue(TPath.GetFullPath(lModel.FileName), 0);
    lModels.Add(lModel);

    for lFileName in aProject.SourceFileNames do
    begin
      lSourceFileName := TPath.GetFullPath(lFileName);
      if lSeen.ContainsKey(lSourceFileName) then
        Continue;
      lSeen.Add(lSourceFileName, 0);
      lModels.Add(ExtractUnitModel(aProject, lSourceFileName));
    end;

    Result := lModels.ToArray;
  finally
    lSeen.Free;
    lModels.Free;
  end;
end;

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

function TDelphiSemanticProjectSession.BuildSemanticGraph: TDelphiSemanticSemanticGraph;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := ExtractProjectModels(fProject);
  Result := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lModels);
  fLastSemanticGraphBuildMetrics := Result.Metrics;
end;

function TDelphiSemanticProjectSession.BuildWithBindingFacts:
  TDelphiSemanticProjectWithBindingFacts;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := ExtractProjectModels(fProject);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lModels);
  try
    fLastSemanticGraphBuildMetrics := lGraph.Metrics;
    Result := TDelphiSemanticWithBinder.BindProject(fProject.ContextFingerprint, lGraph,
      lModels);
  finally
    lGraph.Free;
  end;
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
