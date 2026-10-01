unit DelphiSemantics.Snapshot.ContextEvidence;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Source;

const
  cDelphiSemanticContextEvidenceExtensionName = 'DelphiSemantics.ContextEvidence';

type
  TDelphiSemanticContextEvidenceContext = record
    SessionOpen: Boolean;
    ProjectFileName: string;
    MainSourceFileName: string;
    CompilerLinkProperties: TArray<TDelphiSemanticProperty>;
    CompilerIdentity: string;
    ModelVersion: string;
    ProjectContextFingerprint: string;
    ExpectedRootFileNames: TArray<string>;
    RequestedAnalysisFileNames: TArray<string>;
    ProjectDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  end;

  TDelphiSemanticContextModelEvidence = record
    SourceFileName: string;
    SourceObservations: IDelphiSemanticSourceObservations;
    RootSourceContentHash: string;
    SemanticModelFingerprint: string;
    ModelSucceeded: Boolean;
    BodyAnalysisIncluded: Boolean;
    ReferenceExtractionIncluded: Boolean;
    IncludeFileNames: TArray<string>;
    ModelDiagnostics: TArray<TDelphiSemanticModelDiagnostic>;
    DependencyFacts: TDelphiSemanticUnitDependencyFacts;
    References: TArray<TDelphiSemanticReference>;
  end;

  TDelphiSemanticContextEvidenceExtension = class
  private
    fHasCoProducedEvidence: Boolean;
    fSessionOpen: Boolean;
    fProjectFileName: string;
    fMainSourceFileName: string;
    fCompilerLinkProperties: TArray<TDelphiSemanticProperty>;
    fCompilerIdentity: string;
    fModelVersion: string;
    fProjectContextFingerprint: string;
    fProjectConfigurationIdentity: string;
    fProjectObservationsFingerprint: string;
    fExpectedRootFileNames: TArray<string>;
    fRequestedAnalysisFileNames: TArray<string>;
    fModelEvidence: TArray<TDelphiSemanticContextModelEvidence>;
    fModelCount: Integer;
    fProjectObservations: IDelphiSemanticProjectContextObservations;
    fProjectDiagnostics: TArray<TDelphiSemanticDiagnostic>;
    fSourceObservations: IDelphiSemanticSourceObservations;
    procedure CopyModelEvidence(const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>);
    procedure Initialize(const aContext: TDelphiSemanticContextEvidenceContext;
      const aProjectObservations: IDelphiSemanticProjectContextObservations;
      const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>);
    function GetCompilerLinkProperties: TArray<TDelphiSemanticProperty>;
    function GetExpectedRootFileNames: TArray<string>;
    function GetModelEvidence(const aIndex: Integer): TDelphiSemanticContextModelEvidence;
    function GetProjectDiagnostics: TArray<TDelphiSemanticDiagnostic>;
    function GetRequestedAnalysisFileNames: TArray<string>;
  public
    class function FingerprintModel(const aModel: TDelphiSemanticUnitModel): string; static;
    function MatchesModel(const aModel: TDelphiSemanticUnitModel): Boolean;
    constructor Create(const aProjectObservations:
      IDelphiSemanticProjectContextObservations;
      const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>); overload;
    constructor Create(const aContext: TDelphiSemanticContextEvidenceContext;
      const aProjectObservations:
      IDelphiSemanticProjectContextObservations;
      const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>); overload;
    property HasCoProducedEvidence: Boolean read fHasCoProducedEvidence;
    property ModelCount: Integer read fModelCount;
    property ModelEvidence[const aIndex: Integer]: TDelphiSemanticContextModelEvidence
      read GetModelEvidence;
    property SessionOpen: Boolean read fSessionOpen;
    property ProjectFileName: string read fProjectFileName;
    property MainSourceFileName: string read fMainSourceFileName;
    property CompilerLinkProperties: TArray<TDelphiSemanticProperty> read GetCompilerLinkProperties;
    property CompilerIdentity: string read fCompilerIdentity;
    property ModelVersion: string read fModelVersion;
    property ProjectContextFingerprint: string read fProjectContextFingerprint;
    property ProjectConfigurationIdentity: string read fProjectConfigurationIdentity;
    property ProjectObservationsFingerprint: string read fProjectObservationsFingerprint;
    property ExpectedRootFileNames: TArray<string> read GetExpectedRootFileNames;
    property RequestedAnalysisFileNames: TArray<string> read GetRequestedAnalysisFileNames;
    property ProjectDiagnostics: TArray<TDelphiSemanticDiagnostic> read GetProjectDiagnostics;
    property ProjectObservations: IDelphiSemanticProjectContextObservations
      read fProjectObservations;
    property SourceObservations: IDelphiSemanticSourceObservations read fSourceObservations;
  end;

implementation

uses
  System.Hash, System.SysUtils,
  DelphiSemantics.Model.Json;

constructor TDelphiSemanticContextEvidenceExtension.Create(
  const aProjectObservations: IDelphiSemanticProjectContextObservations;
  const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>);
var
  lContext: TDelphiSemanticContextEvidenceContext;
begin
  inherited Create;
  lContext := Default(TDelphiSemanticContextEvidenceContext);
  Initialize(lContext, aProjectObservations, aModelEvidence);
end;

constructor TDelphiSemanticContextEvidenceExtension.Create(
  const aContext: TDelphiSemanticContextEvidenceContext;
  const aProjectObservations: IDelphiSemanticProjectContextObservations;
  const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>);
begin
  inherited Create;
  Initialize(aContext, aProjectObservations, aModelEvidence);
end;

procedure TDelphiSemanticContextEvidenceExtension.CopyModelEvidence(
  const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>);
var
  i: Integer;
begin
  fModelEvidence := Copy(aModelEvidence);
  fModelCount := Length(fModelEvidence);
  for i := 0 to High(fModelEvidence) do
  begin
    fModelEvidence[i].IncludeFileNames := Copy(aModelEvidence[i].IncludeFileNames);
    fModelEvidence[i].ModelDiagnostics := Copy(aModelEvidence[i].ModelDiagnostics);
    fModelEvidence[i].DependencyFacts := aModelEvidence[i].DependencyFacts.Clone;
    fModelEvidence[i].References := Copy(aModelEvidence[i].References);
  end;
end;

procedure TDelphiSemanticContextEvidenceExtension.Initialize(
  const aContext: TDelphiSemanticContextEvidenceContext;
  const aProjectObservations: IDelphiSemanticProjectContextObservations;
  const aModelEvidence: TArray<TDelphiSemanticContextModelEvidence>);
var
  lError: string;
  lIndex: Integer;
  lMergedObservations: IDelphiSemanticSourceObservations;
  lSource: TDelphiSemanticSourceText;
begin
  fSessionOpen := aContext.SessionOpen;
  fProjectFileName := aContext.ProjectFileName;
  fMainSourceFileName := aContext.MainSourceFileName;
  fCompilerLinkProperties := Copy(aContext.CompilerLinkProperties);
  fCompilerIdentity := aContext.CompilerIdentity;
  fModelVersion := aContext.ModelVersion;
  fProjectContextFingerprint := aContext.ProjectContextFingerprint;
  if Assigned(aProjectObservations) then
  begin
    fProjectConfigurationIdentity := aProjectObservations.ConfigurationIdentity;
    fProjectObservationsFingerprint := aProjectObservations.EvidenceFingerprint;
  end;
  fExpectedRootFileNames := Copy(aContext.ExpectedRootFileNames);
  fRequestedAnalysisFileNames := Copy(aContext.RequestedAnalysisFileNames);
  fProjectDiagnostics := Copy(aContext.ProjectDiagnostics);
  fProjectObservations := aProjectObservations;
  CopyModelEvidence(aModelEvidence);
  fHasCoProducedEvidence := Assigned(fProjectObservations) and
    (fProjectObservations.EvidenceFingerprint <> '') and (Length(fModelEvidence) > 0);

  for lIndex := 0 to High(fModelEvidence) do
  begin
    if (Trim(fModelEvidence[lIndex].SourceFileName) = '') or
      (not Assigned(fModelEvidence[lIndex].SourceObservations)) then
    begin
      fHasCoProducedEvidence := False;
      Continue;
    end;
    if (fSourceObservations = nil) then
      fSourceObservations := fModelEvidence[lIndex].SourceObservations
    else begin
      if TDelphiSemanticSourceEvidence.TryMerge(fSourceObservations,
        fModelEvidence[lIndex].SourceObservations, lMergedObservations, lError) then
        fSourceObservations := lMergedObservations
      else
        fHasCoProducedEvidence := False;
    end;
    if fModelEvidence[lIndex].SourceObservations.TryFind(
      fModelEvidence[lIndex].SourceFileName, lSource) then
    begin
      fModelEvidence[lIndex].RootSourceContentHash := lSource.ContentHash;
      if lSource.ContentHash = '' then
        fHasCoProducedEvidence := False;
    end else
      fHasCoProducedEvidence := False;
  end;
end;

function TDelphiSemanticContextEvidenceExtension.GetModelEvidence(
  const aIndex: Integer): TDelphiSemanticContextModelEvidence;
begin
  Result := fModelEvidence[aIndex];
  Result.IncludeFileNames := Copy(fModelEvidence[aIndex].IncludeFileNames);
  Result.ModelDiagnostics := Copy(fModelEvidence[aIndex].ModelDiagnostics);
  Result.DependencyFacts := fModelEvidence[aIndex].DependencyFacts.Clone;
  Result.References := Copy(fModelEvidence[aIndex].References);
end;

function TDelphiSemanticContextEvidenceExtension.GetCompilerLinkProperties:
  TArray<TDelphiSemanticProperty>;
begin
  Result := Copy(fCompilerLinkProperties);
end;

function TDelphiSemanticContextEvidenceExtension.GetExpectedRootFileNames:
  TArray<string>;
begin
  Result := Copy(fExpectedRootFileNames);
end;

function TDelphiSemanticContextEvidenceExtension.GetProjectDiagnostics:
  TArray<TDelphiSemanticDiagnostic>;
begin
  Result := Copy(fProjectDiagnostics);
end;

function TDelphiSemanticContextEvidenceExtension.GetRequestedAnalysisFileNames:
  TArray<string>;
begin
  Result := Copy(fRequestedAnalysisFileNames);
end;

class function TDelphiSemanticContextEvidenceExtension.FingerprintModel(
  const aModel: TDelphiSemanticUnitModel): string;
begin
  // Use the persisted semantic projection: no runtime metrics or observation objects.
  Result := THashSHA2.GetHashString('DelphiSemantics.ModelEvidence.1|' + ModelToJson(aModel));
end;

function TDelphiSemanticContextEvidenceExtension.MatchesModel(
  const aModel: TDelphiSemanticUnitModel): Boolean;
var
  i, lFound: Integer;
begin
  Result := False;
  if not fHasCoProducedEvidence then
    Exit;
  lFound := -1;
  for i := 0 to fModelCount - 1 do
    if SameText(fModelEvidence[i].SourceFileName, aModel.FileName) then
    begin
      if lFound >= 0 then
        Exit;
      lFound := i;
    end;
  if (lFound < 0) or (fModelEvidence[lFound].SemanticModelFingerprint = '') then
    Exit;
  Result := fModelEvidence[lFound].SemanticModelFingerprint = FingerprintModel(aModel);
end;

end.
