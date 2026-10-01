unit DelphiSemantics.Refactor.Binding;

interface

uses
  DelphiSemantics.Refactor.Plan, DelphiSemantics.Snapshot;

type
  TSemanticPlanAnalysisKind = (pakBodyAnalysis, pakReferenceExtraction);
  TSemanticPlanAnalysisKinds = set of TSemanticPlanAnalysisKind;

  TSemanticPlanVerificationFact = (pvFreshContextRevalidation,
    pvSameIntentFeatureReplan, pvBaselineBuild, pvPostEditBuild);
  TSemanticPlanVerificationFacts = set of TSemanticPlanVerificationFact;

  TDelphiSemanticPlanBindingRequest = record
    OperationIdentity: string;
    SelectedConfigurationIdentities: TArray<string>;
    ScopeRootFileNames: TArray<string>;
    RequiredAnalysisKinds: TSemanticPlanAnalysisKinds;
    Status: TSemanticPlanStatus;
    Reason: string;
    Edits: TArray<TSemanticPlanEdit>;
  end;

  // This result binds captured context and scope only. It does not establish
  // that caller-supplied edits are semantically authorized for the operation.
  TDelphiSemanticBoundPlanResult = class sealed
  private
    fStatus: TSemanticPlanStatus;
    fReason: string;
    fOperationIdentity: string;
    fContextFingerprint: string;
    fBindingFingerprint: string;
    fSelectedConfigurationIdentities: TArray<string>;
    fScopeRootFileNames: TArray<string>;
    fExpectedRootFileNames: TArray<string>;
    fAnalyzedRootFileNames: TArray<string>;
    fDiagnostics: TArray<string>;
    fRequiredAnalysisKinds: TSemanticPlanAnalysisKinds;
    fRequiredVerifications: TSemanticPlanVerificationFacts;
    fPlan: TSemanticRefactoringPlan;
    function GetSelectedConfigurationIdentities: TArray<string>;
    function GetScopeRootFileNames: TArray<string>;
    function GetExpectedRootFileNames: TArray<string>;
    function GetAnalyzedRootFileNames: TArray<string>;
    function GetDiagnostics: TArray<string>;
    procedure Initialize(const aStatus: TSemanticPlanStatus; const aReason,
      aOperationIdentity, aContextFingerprint, aBindingFingerprint: string;
      const aSelectedConfigurationIdentities, aScopeRootFileNames,
      aExpectedRootFileNames, aAnalyzedRootFileNames, aDiagnostics: TArray<string>;
      const aRequiredAnalysisKinds: TSemanticPlanAnalysisKinds;
      const aRequiredVerifications: TSemanticPlanVerificationFacts;
      const aPlan: TSemanticRefactoringPlan);
  public
    constructor Create;
    destructor Destroy; override;
    property Status: TSemanticPlanStatus read fStatus;
    property Reason: string read fReason;
    property OperationIdentity: string read fOperationIdentity;
    property ContextFingerprint: string read fContextFingerprint;
    property BindingFingerprint: string read fBindingFingerprint;
    property SelectedConfigurationIdentities: TArray<string>
      read GetSelectedConfigurationIdentities;
    property ScopeRootFileNames: TArray<string> read GetScopeRootFileNames;
    // Exact full project root inventory and extractor scope retained with this result.
    // A scoped result does not imply global reference-graph completeness.
    property ExpectedRootFileNames: TArray<string> read GetExpectedRootFileNames;
    property AnalyzedRootFileNames: TArray<string> read GetAnalyzedRootFileNames;
    property Diagnostics: TArray<string> read GetDiagnostics;
    property RequiredAnalysisKinds: TSemanticPlanAnalysisKinds read fRequiredAnalysisKinds;
    property RequiredVerifications: TSemanticPlanVerificationFacts read fRequiredVerifications;
    // Borrowed immutable DTO; its lifetime is bounded by this result.
    property Plan: TSemanticRefactoringPlan read fPlan;
  end;

  TDelphiSemanticPlanBinder = record
  public
    class function Bind(const aSnapshot: TDelphiProjectSnapshot;
      const aRequest: TDelphiSemanticPlanBindingRequest):
      TDelphiSemanticBoundPlanResult; static;
  end;

implementation

uses
  System.Generics.Collections, System.Hash, System.IOUtils, System.SysUtils,
  AutoFree, DelphiSemantics.Model, DelphiSemantics.ProjectContext,
  DelphiSemantics.Snapshot.ContextEvidence, DelphiSemantics.Source, MaxLogic.StrUtils;

const
  cRequiredVerifications: TSemanticPlanVerificationFacts = [
    TSemanticPlanVerificationFact.pvFreshContextRevalidation,
    TSemanticPlanVerificationFact.pvSameIntentFeatureReplan,
    TSemanticPlanVerificationFact.pvBaselineBuild,
    TSemanticPlanVerificationFact.pvPostEditBuild];

constructor TDelphiSemanticBoundPlanResult.Create;
begin
  inherited Create;
  fStatus := TSemanticPlanStatus.Incomplete;
  fReason := 'binding.result-not-initialized';
end;

procedure TDelphiSemanticBoundPlanResult.Initialize(const aStatus: TSemanticPlanStatus;
  const aReason, aOperationIdentity, aContextFingerprint: string;
  const aBindingFingerprint: string;
  const aSelectedConfigurationIdentities, aScopeRootFileNames,
  aExpectedRootFileNames, aAnalyzedRootFileNames, aDiagnostics: TArray<string>;
  const aRequiredAnalysisKinds: TSemanticPlanAnalysisKinds;
  const aRequiredVerifications: TSemanticPlanVerificationFacts;
  const aPlan: TSemanticRefactoringPlan);
begin
  fStatus := aStatus;
  fReason := aReason;
  fOperationIdentity := aOperationIdentity;
  fContextFingerprint := aContextFingerprint;
  fBindingFingerprint := aBindingFingerprint;
  fSelectedConfigurationIdentities := Copy(aSelectedConfigurationIdentities);
  fScopeRootFileNames := Copy(aScopeRootFileNames);
  fExpectedRootFileNames := Copy(aExpectedRootFileNames);
  fAnalyzedRootFileNames := Copy(aAnalyzedRootFileNames);
  fDiagnostics := Copy(aDiagnostics);
  fRequiredAnalysisKinds := aRequiredAnalysisKinds;
  fRequiredVerifications := aRequiredVerifications;
  fPlan := aPlan;
end;

destructor TDelphiSemanticBoundPlanResult.Destroy;
begin
  fPlan.Free;
  inherited Destroy;
end;

function TDelphiSemanticBoundPlanResult.GetSelectedConfigurationIdentities:
  TArray<string>;
begin
  Result := Copy(fSelectedConfigurationIdentities);
end;

function TDelphiSemanticBoundPlanResult.GetScopeRootFileNames: TArray<string>;
begin
  Result := Copy(fScopeRootFileNames);
end;

function TDelphiSemanticBoundPlanResult.GetExpectedRootFileNames: TArray<string>;
begin
  Result := Copy(fExpectedRootFileNames);
end;

function TDelphiSemanticBoundPlanResult.GetAnalyzedRootFileNames: TArray<string>;
begin
  Result := Copy(fAnalyzedRootFileNames);
end;

function TDelphiSemanticBoundPlanResult.GetDiagnostics: TArray<string>;
begin
  Result := Copy(fDiagnostics);
end;

procedure AppendFingerprintField(const aBuilder: TStringBuilder; const aName,
  aValue: string);
begin
  aBuilder.Append(aName).Append(':').Append(Length(aValue)).Append(':').Append(aValue)
    .Append(#10);
end;

function HashBuilder(const aBuilder: TStringBuilder): string;
begin
  Result := THashSHA2.GetHashString(aBuilder.ToString);
end;

function TryCanonicalPath(const aFileName: string; out aCanonicalPath: string): Boolean;
begin
  aCanonicalPath := '';
  Result := False;
  if Trim(aFileName) = '' then
    Exit;
  try
    aCanonicalPath := TPath.GetFullPath(aFileName);
    Result := True;
  except
    on E: Exception do
      aCanonicalPath := '';
  end;
end;

procedure AddDiagnostic(const aDiagnostics: TList<string>; const aCode: string);
begin
  if (Trim(aCode) <> '') and (aDiagnostics.IndexOf(aCode) < 0) then
    aDiagnostics.Add(aCode);
end;

function CreateBindingResult(const aRequest: TDelphiSemanticPlanBindingRequest;
  const aStatus: TSemanticPlanStatus; const aReason, aContextFingerprint,
  aBindingFingerprint: string; const aScopeRootFileNames, aDiagnostics: TArray<string>;
  const aPlan: TSemanticRefactoringPlan): TDelphiSemanticBoundPlanResult;
begin
  Result := TDelphiSemanticBoundPlanResult.Create;
  Result.Initialize(aStatus, aReason,
    aRequest.OperationIdentity, aContextFingerprint, aBindingFingerprint,
    aRequest.SelectedConfigurationIdentities, aScopeRootFileNames, nil, nil, aDiagnostics,
    aRequest.RequiredAnalysisKinds, cRequiredVerifications, aPlan);
end;

function CreateBindingResultWithCoverage(const aRequest: TDelphiSemanticPlanBindingRequest;
  const aStatus: TSemanticPlanStatus; const aReason, aContextFingerprint,
  aBindingFingerprint: string; const aScopeRootFileNames, aExpectedRootFileNames,
  aAnalyzedRootFileNames, aDiagnostics: TArray<string>;
  const aPlan: TSemanticRefactoringPlan): TDelphiSemanticBoundPlanResult;
begin
  Result := TDelphiSemanticBoundPlanResult.Create;
  Result.Initialize(aStatus, aReason,
    aRequest.OperationIdentity, aContextFingerprint, aBindingFingerprint,
    aRequest.SelectedConfigurationIdentities, aScopeRootFileNames,
    aExpectedRootFileNames, aAnalyzedRootFileNames, aDiagnostics,
    aRequest.RequiredAnalysisKinds, cRequiredVerifications, aPlan);
end;

function TryCreateModelSourceLookup(
  const aModelEvidence: TDelphiSemanticContextModelEvidence;
  aLookup: TDictionary<string, TDelphiSemanticSourceText>): Boolean;
var
  i: Integer;
  lCanonicalPath: string;
  lSource: TDelphiSemanticSourceText;
begin
  Result := False;
  aLookup.Clear;
  if not Assigned(aModelEvidence.SourceObservations) then
    Exit;
  for i := 0 to aModelEvidence.SourceObservations.Count - 1 do
  begin
    lSource := aModelEvidence.SourceObservations.Items[i];
    if not TryCanonicalPath(lSource.FileName, lCanonicalPath) or
      (lSource.ContentHash = '') or aLookup.ContainsKey(lCanonicalPath) then
      Exit;
    aLookup.Add(lCanonicalPath, lSource);
  end;
  Result := aLookup.Count > 0;
end;

function TryBuildIncludeGraphHash(const aModelEvidence: TDelphiSemanticContextModelEvidence;
  const aRootFileName: string;
  const aModelSources: TDictionary<string, TDelphiSemanticSourceText>;
  out aIncludeGraphHash: string): Boolean;
var
  g: TGarbos;
  i: Integer;
  lBuilder: TStringBuilder;
  lCanonicalPath: string;
  lSource: TDelphiSemanticSourceText;
begin
  Result := False;
  aIncludeGraphHash := '';
  g := Default(TGarbos);
  GC(lBuilder, TStringBuilder.Create, g);
  AppendFingerprintField(lBuilder, 'schema', 'delphi-semantic-raw-include-manifest-v1');
  AppendFingerprintField(lBuilder, 'root', aRootFileName);
  AppendFingerprintField(lBuilder, 'include-count',
    IntToStr(Length(aModelEvidence.IncludeFileNames)));
  for i := 0 to High(aModelEvidence.IncludeFileNames) do
  begin
    if not TryCanonicalPath(aModelEvidence.IncludeFileNames[i], lCanonicalPath) or
      (not aModelSources.TryGetValue(lCanonicalPath, lSource)) then
      Exit;
    AppendFingerprintField(lBuilder, 'include-path', lCanonicalPath);
    AppendFingerprintField(lBuilder, 'include-raw-hash', lSource.ContentHash);
  end;
  aIncludeGraphHash := HashBuilder(lBuilder);
  Result := aIncludeGraphHash <> '';
end;

function TryBuildContextFingerprints(
  const aEvidence: TDelphiSemanticContextEvidenceExtension;
  const aProjectFingerprint: string;
  const aSources: TArray<TSemanticPlanSource>;
  out aConfigurationFingerprint, aContextFingerprint: string): Boolean;
var
  g: TGarbos;
  i: Integer;
  lBuilder: TStringBuilder;
begin
  aConfigurationFingerprint := '';
  aContextFingerprint := '';
  g := Default(TGarbos);
  GC(lBuilder, TStringBuilder.Create, g);
  AppendFingerprintField(lBuilder, 'schema', 'delphi-semantic-plan-configuration-v1');
  AppendFingerprintField(lBuilder, 'configuration',
    aEvidence.ProjectConfigurationIdentity);
  AppendFingerprintField(lBuilder, 'project-observations',
    aEvidence.ProjectObservationsFingerprint);
  AppendFingerprintField(lBuilder, 'project-context', aProjectFingerprint);
  aConfigurationFingerprint := HashBuilder(lBuilder);

  lBuilder.Clear;
  AppendFingerprintField(lBuilder, 'schema', 'delphi-semantic-plan-context-v2');
  AppendFingerprintField(lBuilder, 'configuration-fingerprint', aConfigurationFingerprint);
  AppendFingerprintField(lBuilder, 'project-file', aEvidence.ProjectFileName);
  AppendFingerprintField(lBuilder, 'compiler', aEvidence.CompilerIdentity);
  AppendFingerprintField(lBuilder, 'model-version', aEvidence.ModelVersion);
  for i := 0 to High(aSources) do
  begin
    AppendFingerprintField(lBuilder, 'source-path', aSources[i].FileName);
    AppendFingerprintField(lBuilder, 'source-hash', aSources[i].ContentHash);
    AppendFingerprintField(lBuilder, 'include-manifest', aSources[i].IncludeGraphHash);
  end;
  for i := 0 to aEvidence.ModelCount - 1 do
  begin
    AppendFingerprintField(lBuilder, 'semantic-source-path', aEvidence.ModelEvidence[i].SourceFileName);
    AppendFingerprintField(lBuilder, 'semantic-model-fingerprint',
      aEvidence.ModelEvidence[i].SemanticModelFingerprint);
  end;
  aContextFingerprint := HashBuilder(lBuilder);
  Result := (aConfigurationFingerprint <> '') and (aContextFingerprint <> '');
end;

function TryBuildBindingFingerprint(const aRequest: TDelphiSemanticPlanBindingRequest;
  const aContextFingerprint: string; const aScopeRootFileNames,
  aExpectedRootFileNames, aAnalyzedRootFileNames: TArray<string>;
  out aBindingFingerprint: string): Boolean;
var
  g: TGarbos;
  i: Integer;
  lBuilder: TStringBuilder;
  lEdit: TSemanticPlanEdit;
  lAnalysisKind: TSemanticPlanAnalysisKind;
begin
  aBindingFingerprint := '';
  g := Default(TGarbos);
  GC(lBuilder, TStringBuilder.Create, g);
  AppendFingerprintField(lBuilder, 'schema', 'delphi-semantic-bound-plan-v2');
  AppendFingerprintField(lBuilder, 'context', aContextFingerprint);
  AppendFingerprintField(lBuilder, 'operation', aRequest.OperationIdentity);
  AppendFingerprintField(lBuilder, 'status', IntToStr(Ord(aRequest.Status)));
  AppendFingerprintField(lBuilder, 'reason', aRequest.Reason);
  for i := 0 to High(aRequest.SelectedConfigurationIdentities) do
    AppendFingerprintField(lBuilder, 'selected-configuration',
      aRequest.SelectedConfigurationIdentities[i]);
  for i := 0 to High(aScopeRootFileNames) do
    AppendFingerprintField(lBuilder, 'scope-root', aScopeRootFileNames[i]);
  for i := 0 to High(aExpectedRootFileNames) do
    AppendFingerprintField(lBuilder, 'expected-root', aExpectedRootFileNames[i]);
  for i := 0 to High(aAnalyzedRootFileNames) do
    AppendFingerprintField(lBuilder, 'analyzed-root', aAnalyzedRootFileNames[i]);
  for lAnalysisKind := Low(TSemanticPlanAnalysisKind) to High(TSemanticPlanAnalysisKind) do
    if lAnalysisKind in aRequest.RequiredAnalysisKinds then
      AppendFingerprintField(lBuilder, 'analysis-kind', IntToStr(Ord(lAnalysisKind)));
  for lEdit in aRequest.Edits do
  begin
    AppendFingerprintField(lBuilder, 'edit-file', lEdit.FileName);
    AppendFingerprintField(lBuilder, 'edit-start-line', IntToStr(lEdit.StartLine));
    AppendFingerprintField(lBuilder, 'edit-start-column', IntToStr(lEdit.StartColumn));
    AppendFingerprintField(lBuilder, 'edit-end-line', IntToStr(lEdit.EndLine));
    AppendFingerprintField(lBuilder, 'edit-end-column', IntToStr(lEdit.EndColumn));
    AppendFingerprintField(lBuilder, 'edit-expected-text', lEdit.ExpectedText);
    AppendFingerprintField(lBuilder, 'edit-replacement-text', lEdit.ReplacementText);
  end;
  aBindingFingerprint := HashBuilder(lBuilder);
  Result := aBindingFingerprint <> '';
end;

function TryRequestedScope(const aRequest: TDelphiSemanticPlanBindingRequest;
  const aExpectedRootFileNames: TArray<string>;
  const aExpectedRoots: TDictionary<string, Integer>;
  out aScopeRootFileNames: TArray<string>; out aErrorCode: string): Boolean;
var
  lRequestedRoots: TDictionary<string, Byte>;
  lRootFileName: string;
  lCanonicalPath: string;
  lIndex: Integer;
begin
  Result := False;
  aErrorCode := 'binding.scope-not-observed';
  aScopeRootFileNames := nil;
  lRequestedRoots := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for lRootFileName in aRequest.ScopeRootFileNames do
    begin
      if not TryCanonicalPath(lRootFileName, lCanonicalPath) or
        (not aExpectedRoots.ContainsKey(lCanonicalPath)) or
        lRequestedRoots.ContainsKey(lCanonicalPath) then
        Exit;
      lRequestedRoots.Add(lCanonicalPath, 0);
    end;

    SetLength(aScopeRootFileNames, Length(aExpectedRootFileNames));
    lIndex := 0;
    for lRootFileName in aExpectedRootFileNames do
    begin
      if (Length(aRequest.ScopeRootFileNames) = 0) or
        lRequestedRoots.ContainsKey(lRootFileName) then
      begin
        aScopeRootFileNames[lIndex] := lRootFileName;
        Inc(lIndex);
      end;
    end;
    SetLength(aScopeRootFileNames, lIndex);
    if (Length(aRequest.ScopeRootFileNames) > 0) and
      (lIndex <> lRequestedRoots.Count) then
      Exit;
    if Length(aScopeRootFileNames) = 0 then
      Exit;
    aErrorCode := '';
    Result := True;
  finally
    lRequestedRoots.Free;
  end;
end;

function HasDiagnosticErrors(const aDiagnostics: TArray<TDelphiSemanticDiagnostic>): Boolean;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  for lDiagnostic in aDiagnostics do
    if (lDiagnostic.Severity = TDelphiSemanticDiagnosticSeverity.dsWarning) or
      (lDiagnostic.Severity = TDelphiSemanticDiagnosticSeverity.dsError) then
      Exit(True);
  Result := False;
end;

procedure AppendProjectDiagnosticCodes(const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  const aTarget: TList<string>);
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  for lDiagnostic in aDiagnostics do
    AddDiagnostic(aTarget, lDiagnostic.Code);
end;

procedure AppendModelDiagnosticCodes(const aModelEvidence: TDelphiSemanticContextModelEvidence;
  const aTarget: TList<string>);
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  for lDiagnostic in aModelEvidence.ModelDiagnostics do
    AddDiagnostic(aTarget, lDiagnostic.Code);
end;

function CreateRefusal(const aRequest: TDelphiSemanticPlanBindingRequest;
  const aReason, aContextFingerprint: string; const aDiagnostics: TList<string>;
  const aScopeRootFileNames: TArray<string>): TDelphiSemanticBoundPlanResult;
begin
  AddDiagnostic(aDiagnostics, aReason);
  Result := CreateBindingResult(aRequest, TSemanticPlanStatus.Incomplete, aReason,
    aContextFingerprint, '', aScopeRootFileNames, aDiagnostics.ToArray, nil);
end;

class function TDelphiSemanticPlanBinder.Bind(const aSnapshot: TDelphiProjectSnapshot;
  const aRequest: TDelphiSemanticPlanBindingRequest): TDelphiSemanticBoundPlanResult;
var
  g: TGarbos;
  i, lModelIndex: Integer;
  lAnalysisScope: TDictionary<string, Byte>;
  lScopeRootLookup: TDictionary<string, Byte>;
  lContext: TSemanticPlanContext;
  lContextEvidence: TDelphiSemanticContextEvidenceExtension;
  lContextFingerprint: string;
  lConfigurationFingerprint: string;
  lDiagnostics: TList<string>;
  lExtension: TObject;
  lExpectedRootFileNames: TArray<string>;
  lAnalyzedRootFileNames: TArray<string>;
  lExpectedRoots: TDictionary<string, Integer>;
  lErrorCode: string;
  lIncludeGraphHash: string;
  lModelEvidence: TDelphiSemanticContextModelEvidence;
  lModelIndexes: TDictionary<string, Integer>;
  lModelSources: TDictionary<string, TDelphiSemanticSourceText>;
  lPlan: TSemanticRefactoringPlan;
  lPlanSource: TSemanticPlanSource;
  lPlanSources: TArray<TSemanticPlanSource>;
  lRootFileName: string;
  lRootPath: string;
  lRootSource: TDelphiSemanticSourceText;
  lScopeRootFileNames: TArray<string>;
  lSelectedConfiguration: string;
  lBindingFingerprint: string;
  lSourcePath: string;
begin
  g := Default(TGarbos);
  lContextFingerprint := '';
  lDiagnostics := nil;
  lExtension := nil;
  lExpectedRoots := nil;
  lModelIndexes := nil;
  lModelSources := nil;
  lAnalysisScope := nil;
  lScopeRootLookup := nil;
  GC(lDiagnostics, TList<string>.Create, g);

  if aRequest.Status in [TSemanticPlanStatus.Incomplete, TSemanticPlanStatus.Blocked] then
  begin
    lErrorCode := aRequest.Reason;
    if Trim(lErrorCode) = '' then
      lErrorCode := 'binding.missing-completeness-reason';
    AddDiagnostic(lDiagnostics, lErrorCode);
    Result := CreateBindingResult(aRequest, aRequest.Status, lErrorCode, '', '',
      aRequest.ScopeRootFileNames, lDiagnostics.ToArray, nil);
    Exit;
  end;

  if Trim(aRequest.OperationIdentity) = '' then
  begin
    Result := CreateRefusal(aRequest, 'binding.operation-required', '', lDiagnostics,
      aRequest.ScopeRootFileNames);
    Exit;
  end;
  if not Assigned(aSnapshot) then
  begin
    Result := CreateRefusal(aRequest, 'binding.snapshot-required', '', lDiagnostics,
      aRequest.ScopeRootFileNames);
    Exit;
  end;
  if not aSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
    lExtension) or not (lExtension is TDelphiSemanticContextEvidenceExtension) then
  begin
    Result := CreateRefusal(aRequest, 'binding.context-evidence-missing', '', lDiagnostics,
      aRequest.ScopeRootFileNames);
    Exit;
  end;
  lContextEvidence := lExtension as TDelphiSemanticContextEvidenceExtension;
  if not lContextEvidence.HasCoProducedEvidence or
    (not lContextEvidence.SessionOpen) or
    (Trim(lContextEvidence.ProjectFileName) = '') or
    (Trim(lContextEvidence.CompilerIdentity) = '') or
    (Trim(lContextEvidence.ModelVersion) = '') or
    (Trim(lContextEvidence.ProjectContextFingerprint) = '') or
    (Trim(lContextEvidence.ProjectConfigurationIdentity) = '') or
    (Trim(lContextEvidence.ProjectObservationsFingerprint) = '') then
  begin
    Result := CreateRefusal(aRequest, 'binding.context-evidence-incomplete', '', lDiagnostics,
      aRequest.ScopeRootFileNames);
    Exit;
  end;

  AppendProjectDiagnosticCodes(lContextEvidence.ProjectDiagnostics, lDiagnostics);
  if HasDiagnosticErrors(lContextEvidence.ProjectDiagnostics) then
  begin
    Result := CreateRefusal(aRequest, 'binding.project-context-diagnostic', '', lDiagnostics,
      aRequest.ScopeRootFileNames);
    Exit;
  end;
  if Length(aRequest.SelectedConfigurationIdentities) <> 1 then
  begin
    Result := CreateRefusal(aRequest, 'binding.configuration-set-unsupported', '',
      lDiagnostics, aRequest.ScopeRootFileNames);
    Exit;
  end;
  lSelectedConfiguration := aRequest.SelectedConfigurationIdentities[0];
  if lSelectedConfiguration <> lContextEvidence.ProjectConfigurationIdentity then
  begin
    Result := CreateRefusal(aRequest, 'binding.configuration-not-observed', '',
      lDiagnostics, aRequest.ScopeRootFileNames);
    Exit;
  end;
  if aRequest.RequiredAnalysisKinds = [] then
  begin
    Result := CreateRefusal(aRequest, 'binding.analysis-kind-required', '',
      lDiagnostics, aRequest.ScopeRootFileNames);
    Exit;
  end;

  lExpectedRootFileNames := lContextEvidence.ExpectedRootFileNames;
  if (Length(lExpectedRootFileNames) = 0) or
    (Length(lExpectedRootFileNames) <> lContextEvidence.ModelCount) then
  begin
    Result := CreateRefusal(aRequest, 'binding.expected-root-set-incomplete', '',
      lDiagnostics, aRequest.ScopeRootFileNames);
    Exit;
  end;

  GC(lExpectedRoots, TDictionary<string, Integer>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  GC(lModelIndexes, TDictionary<string, Integer>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  GC(lModelSources, TDictionary<string, TDelphiSemanticSourceText>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  for i := 0 to High(lExpectedRootFileNames) do
  begin
    if not TryCanonicalPath(lExpectedRootFileNames[i], lRootPath) or
      lExpectedRoots.ContainsKey(lRootPath) then
    begin
      Result := CreateRefusal(aRequest, 'binding.expected-root-set-invalid', '',
        lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    lExpectedRootFileNames[i] := lRootPath;
    lExpectedRoots.Add(lRootPath, i);
  end;
  for i := 0 to lContextEvidence.ModelCount - 1 do
  begin
    lModelEvidence := lContextEvidence.ModelEvidence[i];
    if not TryCanonicalPath(lModelEvidence.SourceFileName, lRootPath) or
      lModelIndexes.ContainsKey(lRootPath) then
    begin
      Result := CreateRefusal(aRequest, 'binding.observed-root-set-invalid', '',
        lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    lModelIndexes.Add(lRootPath, i);
  end;
  if lModelIndexes.Count <> lExpectedRoots.Count then
  begin
    Result := CreateRefusal(aRequest, 'binding.observed-root-set-incomplete', '',
      lDiagnostics, aRequest.ScopeRootFileNames);
    Exit;
  end;

  GC(lAnalysisScope, TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  for lRootFileName in lContextEvidence.RequestedAnalysisFileNames do
  begin
    if not TryCanonicalPath(lRootFileName, lRootPath) or
      (not lExpectedRoots.ContainsKey(lRootPath)) or lAnalysisScope.ContainsKey(lRootPath) then
    begin
      Result := CreateRefusal(aRequest, 'binding.analysis-scope-invalid', '',
        lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    lAnalysisScope.Add(lRootPath, 0);
  end;

  SetLength(lPlanSources, Length(lExpectedRootFileNames));
  for i := 0 to High(lExpectedRootFileNames) do
  begin
    lRootFileName := lExpectedRootFileNames[i];
    if not lModelIndexes.TryGetValue(lRootFileName, lModelIndex) then
    begin
      Result := CreateRefusal(aRequest, 'binding.observed-root-set-incomplete', '',
        lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    lModelEvidence := lContextEvidence.ModelEvidence[lModelIndex];
    AppendModelDiagnosticCodes(lModelEvidence, lDiagnostics);
    if not lModelEvidence.ModelSucceeded or (Length(lModelEvidence.ModelDiagnostics) > 0) then
    begin
      if lModelEvidence.ModelSucceeded then
        lErrorCode := 'binding.model-diagnostic'
      else
        lErrorCode := 'binding.model-failed';
      Result := CreateRefusal(aRequest, lErrorCode, '', lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    if not TryCreateModelSourceLookup(lModelEvidence, lModelSources) then
    begin
      Result := CreateRefusal(aRequest, 'binding.source-observations-incomplete', '',
        lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    if not lModelSources.TryGetValue(lRootFileName, lRootSource) or
      (lRootSource.ContentHash = '') or
      (lRootSource.ContentHash <> lModelEvidence.RootSourceContentHash) then
    begin
      Result := CreateRefusal(aRequest, 'binding.root-source-observation-missing', '',
        lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    if not TryBuildIncludeGraphHash(lModelEvidence, lRootFileName, lModelSources,
      lIncludeGraphHash) then
    begin
      Result := CreateRefusal(aRequest, 'binding.include-manifest-incomplete', '',
        lDiagnostics, aRequest.ScopeRootFileNames);
      Exit;
    end;
    lPlanSource := Default(TSemanticPlanSource);
    lPlanSource.FileName := lRootFileName;
    lPlanSource.ContentHash := lRootSource.ContentHash;
    lPlanSource.IncludeGraphHash := lIncludeGraphHash;
    lPlanSource.OriginalText := lRootSource.Text;
    lPlanSources[i] := lPlanSource;
  end;

  lErrorCode := '';
  if not TryRequestedScope(aRequest, lExpectedRootFileNames, lExpectedRoots,
    lScopeRootFileNames, lErrorCode) then
  begin
    Result := CreateRefusal(aRequest, lErrorCode, '', lDiagnostics,
      lScopeRootFileNames);
    Exit;
  end;
  for lRootFileName in lScopeRootFileNames do
  begin
    if not lModelIndexes.TryGetValue(lRootFileName, lModelIndex) then
    begin
      Result := CreateRefusal(aRequest, 'binding.scope-not-observed', '', lDiagnostics,
        lScopeRootFileNames);
      Exit;
    end;
    lModelEvidence := lContextEvidence.ModelEvidence[lModelIndex];
    if ((TSemanticPlanAnalysisKind.pakBodyAnalysis in aRequest.RequiredAnalysisKinds) and
      (not lModelEvidence.BodyAnalysisIncluded)) or
      ((TSemanticPlanAnalysisKind.pakReferenceExtraction in aRequest.RequiredAnalysisKinds) and
      (not lModelEvidence.ReferenceExtractionIncluded)) then
    begin
      Result := CreateRefusal(aRequest, 'binding.analysis-scope-incomplete', '',
        lDiagnostics, lScopeRootFileNames);
      Exit;
    end;
  end;

  GC(lScopeRootLookup, TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  for lRootFileName in lScopeRootFileNames do
    lScopeRootLookup.Add(lRootFileName, 0);

  for lModelIndex := 0 to lContextEvidence.ModelCount - 1 do
  begin
    lModelEvidence := lContextEvidence.ModelEvidence[lModelIndex];
    lRootFileName := '';
    if not TryCanonicalPath(lModelEvidence.SourceFileName, lRootFileName) then
    begin
      Result := CreateRefusal(aRequest, 'binding.observed-root-set-invalid', '',
        lDiagnostics, lScopeRootFileNames);
      Exit;
    end;
    if lAnalysisScope.Count = 0 then
    begin
      if not lModelEvidence.BodyAnalysisIncluded or
        not lModelEvidence.ReferenceExtractionIncluded then
      begin
        Result := CreateRefusal(aRequest, 'binding.analysis-scope-inconsistent', '',
          lDiagnostics, lScopeRootFileNames);
        Exit;
      end;
    end else if (lModelEvidence.BodyAnalysisIncluded <> lAnalysisScope.ContainsKey(lRootFileName)) or
      (lModelEvidence.ReferenceExtractionIncluded <> lAnalysisScope.ContainsKey(lRootFileName)) then
    begin
      Result := CreateRefusal(aRequest, 'binding.analysis-scope-inconsistent', '',
        lDiagnostics, lScopeRootFileNames);
      Exit;
    end;
  end;

  if lAnalysisScope.Count = 0 then
    lAnalyzedRootFileNames := Copy(lExpectedRootFileNames)
  else begin
    SetLength(lAnalyzedRootFileNames, lAnalysisScope.Count);
    lModelIndex := 0;
    for lRootFileName in lExpectedRootFileNames do
      if lAnalysisScope.ContainsKey(lRootFileName) then
      begin
        lAnalyzedRootFileNames[lModelIndex] := lRootFileName;
        Inc(lModelIndex);
      end;
    SetLength(lAnalyzedRootFileNames, lModelIndex);
  end;

  if not TryBuildContextFingerprints(lContextEvidence,
    lContextEvidence.ProjectContextFingerprint, lPlanSources,
    lConfigurationFingerprint, lContextFingerprint) then
  begin
    Result := CreateRefusal(aRequest, 'binding.context-fingerprint-invalid', '',
      lDiagnostics, lScopeRootFileNames);
    Exit;
  end;
  if not TryBuildBindingFingerprint(aRequest, lContextFingerprint,
    lScopeRootFileNames, lExpectedRootFileNames, lAnalyzedRootFileNames,
    lBindingFingerprint) then
  begin
    Result := CreateRefusal(aRequest, 'binding.binding-fingerprint-invalid',
      lContextFingerprint, lDiagnostics, lScopeRootFileNames);
    Exit;
  end;

  for lModelIndex := 0 to High(aRequest.Edits) do
  begin
    if not TryCanonicalPath(aRequest.Edits[lModelIndex].FileName, lSourcePath) or
      (not lExpectedRoots.ContainsKey(lSourcePath)) then
    begin
      Result := CreateRefusal(aRequest, 'binding.edit-source-not-observed',
        lContextFingerprint, lDiagnostics, lScopeRootFileNames);
      Exit;
    end;
    if not lScopeRootLookup.ContainsKey(lSourcePath) then
    begin
      Result := CreateRefusal(aRequest, 'binding.edit-outside-scope', lContextFingerprint,
        lDiagnostics, lScopeRootFileNames);
      Exit;
    end;
  end;

  lContext := Default(TSemanticPlanContext);
  if not TryCanonicalPath(lContextEvidence.ProjectFileName, lContext.ProjectIdentity) then
  begin
    Result := CreateRefusal(aRequest, 'binding.project-identity-invalid',
      lContextFingerprint, lDiagnostics, lScopeRootFileNames);
    Exit;
  end;
  lContext.CompilerIdentity := lContextEvidence.CompilerIdentity;
  lContext.ModelVersion := lContextEvidence.ModelVersion;
  lContext.ConfigurationFingerprint := lConfigurationFingerprint;
  lPlan := nil;
  if not TSemanticRefactoringPlan.TryCreate(lContext, aRequest.Status, aRequest.Reason,
    lPlanSources, aRequest.Edits, lPlan, lErrorCode) then
  begin
    AddDiagnostic(lDiagnostics, lErrorCode);
    Result := CreateBindingResult(aRequest, TSemanticPlanStatus.Blocked,
      'binding.plan-structure-invalid', lContextFingerprint, lBindingFingerprint,
      lScopeRootFileNames, lDiagnostics.ToArray, nil);
    Exit;
  end;
  Result := CreateBindingResultWithCoverage(aRequest, aRequest.Status,
    aRequest.Reason, lContextFingerprint, lBindingFingerprint,
    lScopeRootFileNames, lExpectedRootFileNames, lAnalyzedRootFileNames,
    lDiagnostics.ToArray, lPlan);
end;

end.
