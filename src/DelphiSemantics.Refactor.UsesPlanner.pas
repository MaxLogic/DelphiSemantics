unit DelphiSemantics.Refactor.UsesPlanner;

interface

uses
  DelphiSemantics.Refactor.Binding, DelphiSemantics.Refactor.Plan,
  DelphiSemantics.Snapshot;

type
  TDelphiSemanticUsesClassification = (ucUnknown, ucSafeImplementationImportRemoval,
    ucInitializationSensitive, ucConditionalClause, ucInterfaceVisibleUse,
    ucHelperOrOperatorVisibilityUnknown, ucInterfaceImplementationMoveCandidate,
    ucUnsupportedShape, ucIncompleteScope, ucExplicitImportCandidate,
    ucAmbiguousExplicitImportCandidate, ucNoOp, ucSafeExplicitImportAddition);

  TDelphiSemanticUsesPlanningResult = record
    Classification: TDelphiSemanticUsesClassification;
    Reason: string;
    CandidateUnitNames: TArray<string>;
    // Caller owns Plan. Complete means this planner generated a guarded edit from
    // retained context; it does not authorize applying caller-supplied artifacts.
    Plan: TSemanticRefactoringPlan;
  end;

  TDelphiSemanticUsesPlanner = record
  public
    class function PlanRemoveImplementationImport(
      const aSnapshot: TDelphiProjectSnapshot;
      const aBinding: TDelphiSemanticBoundPlanResult;
      const aConsumerFileName, aUnitName: string): TDelphiSemanticUsesPlanningResult; static;
    class function AnalyzeInterfaceImportMoveCandidate(
      const aSnapshot: TDelphiProjectSnapshot;
      const aBinding: TDelphiSemanticBoundPlanResult;
      const aConsumerFileName, aUnitName: string): TDelphiSemanticUsesPlanningResult; static;
    class function SuggestExplicitImportCandidates(
      const aSnapshot: TDelphiProjectSnapshot;
      const aBinding: TDelphiSemanticBoundPlanResult;
      const aConsumerFileName, aIdentifier: string): TDelphiSemanticUsesPlanningResult; static;
    class function PlanAddExplicitImport(
      const aSnapshot: TDelphiProjectSnapshot;
      const aBinding: TDelphiSemanticBoundPlanResult;
      const aConsumerFileName, aUnitName, aIdentifier: string):
      TDelphiSemanticUsesPlanningResult; static;
  end;

implementation

uses
  System.Generics.Collections, System.IOUtils, System.RegularExpressions, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Refactor.UnitOrder,
  DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.ContextEvidence,
  DelphiSemantics.Source;

const
  cRemoveImplementationImportOperation = 'uses.remove-implementation-import';
  cAddExplicitImportOperation = 'uses.add-explicit-import';
  cAnalyzeInterfaceImportMoveOperation = 'uses.analyze-interface-import-move';
  cSuggestExplicitImportCandidatesOperation = 'uses.suggest-explicit-import-candidates';
  cSimpleConsumerPattern =
    '(?is)\A\x{FEFF}?\s*unit\s+[A-Za-z_][A-Za-z0-9_]*\s*;\s*interface\s*implementation\s*' +
    '(?<clause>uses\s+(?<unit>[A-Za-z_][A-Za-z0-9_]*)\s*;)\s*end\s*\.\s*\z';
  cSimpleLeafPattern =
    '(?is)\A\x{FEFF}?\s*unit\s+(?<unit>[A-Za-z_][A-Za-z0-9_]*)\s*;\s*interface\s*' +
    'implementation\s*end\s*\.\s*\z';
  cSimpleConstantProviderPattern =
    '(?is)\A\x{FEFF}?\s*unit\s+(?<unit>[A-Za-z_][A-Za-z0-9_]*)\s*;\s*interface\s*' +
    'const\s+(?<declarations>(?:[A-Za-z_][A-Za-z0-9_]*\s*=\s*-?[0-9]+\s*;\s*)+)' +
    'implementation\s*end\s*\.\s*\z';
  cSimpleInterfaceUsesPattern =
    '(?is)\binterface\s+uses\s+(?<unit>[A-Za-z_][A-Za-z0-9_]*)\s*;';
  cSimpleExplicitImportConsumerPattern =
    '(?is)\A\x{FEFF}?\s*unit\s+[A-Za-z_][A-Za-z0-9_]*\s*;\s*interface\s*' +
    'implementation(?<gap>\s*)function\s+[A-Za-z_][A-Za-z0-9_]*\s*:\s*Integer\s*;' +
    '\s*begin\s*Result\s*:=\s*(?<identifier>[A-Za-z_][A-Za-z0-9_]*)\s*;' +
    '\s*end\s*;\s*end\s*\.\s*\z';

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

function SamePath(const aLeft, aRight: string): Boolean;
var
  lLeft: string;
  lRight: string;
begin
  Result := TryCanonicalPath(aLeft, lLeft) and TryCanonicalPath(aRight, lRight) and
    SameText(lLeft, lRight);
end;

function HasPath(const aFileNames: TArray<string>; const aFileName: string): Boolean;
var
  lFileName: string;
begin
  for lFileName in aFileNames do
    if SamePath(lFileName, aFileName) then
      Exit(True);
  Result := False;
end;

function SamePathSet(const aLeft, aRight: TArray<string>): Boolean;
var
  lFileName: string;
begin
  if Length(aLeft) <> Length(aRight) then
    Exit(False);
  for lFileName in aLeft do
    if not HasPath(aRight, lFileName) then
      Exit(False);
  Result := True;
end;

function TryFindPlanSource(const aPlan: TSemanticRefactoringPlan;
  const aFileName: string; out aSource: TSemanticPlanSource): Boolean;
var
  i: Integer;
begin
  aSource := Default(TSemanticPlanSource);
  if not Assigned(aPlan) then
    Exit(False);
  for i := 0 to aPlan.SourceCount - 1 do
    if SamePath(aPlan.Sources[i].FileName, aFileName) then
    begin
      aSource := aPlan.Sources[i];
      Exit(True);
    end;
  Result := False;
end;

function TryFindModelEvidence(const aEvidence: TDelphiSemanticContextEvidenceExtension;
  const aFileName: string; out aModelEvidence: TDelphiSemanticContextModelEvidence): Boolean;
var
  i: Integer;
begin
  aModelEvidence := Default(TDelphiSemanticContextModelEvidence);
  if not Assigned(aEvidence) then
    Exit(False);
  for i := 0 to aEvidence.ModelCount - 1 do
    if SamePath(aEvidence.ModelEvidence[i].SourceFileName, aFileName) then
    begin
      aModelEvidence := aEvidence.ModelEvidence[i];
      Exit(True);
    end;
  Result := False;
end;

function HasCoProducedFullAnalysis(const aEvidence: TDelphiSemanticContextEvidenceExtension;
  const aBinding: TDelphiSemanticBoundPlanResult): Boolean;
var
  i: Integer;
  lObservedSource: TDelphiSemanticSourceText;
  lRootSourceContentHash: string;
  lSourceFileName: string;
  lSource: TSemanticPlanSource;
begin
  Result := False;
  if not Assigned(aEvidence) or not aEvidence.HasCoProducedEvidence or
    not Assigned(aBinding) or not Assigned(aBinding.Plan) then
    Exit;
  if (aBinding.Plan.SourceCount <> aEvidence.ModelCount) or
    (aEvidence.ModelCount <> Length(aEvidence.ExpectedRootFileNames)) then
    Exit;
  for i := 0 to aEvidence.ModelCount - 1 do
  begin
    lSourceFileName := aEvidence.ModelEvidence[i].SourceFileName;
    lRootSourceContentHash := aEvidence.ModelEvidence[i].RootSourceContentHash;
    if not aEvidence.ModelEvidence[i].ModelSucceeded or
      not aEvidence.ModelEvidence[i].BodyAnalysisIncluded or
      not aEvidence.ModelEvidence[i].ReferenceExtractionIncluded or
      (Length(aEvidence.ModelEvidence[i].ModelDiagnostics) > 0) or
      not HasPath(aEvidence.ExpectedRootFileNames, lSourceFileName) or
      not TryFindPlanSource(aBinding.Plan, lSourceFileName, lSource) or
      not aEvidence.SourceObservations.TryFind(lSourceFileName, lObservedSource) then
      Exit;
    if (lRootSourceContentHash = '') or
      (lRootSourceContentHash <> lObservedSource.ContentHash) or
      (lSource.ContentHash = '') or (lSource.IncludeGraphHash = '') or
      (lSource.ContentHash <> lObservedSource.ContentHash) or
      (lSource.OriginalText <> lObservedSource.Text) then
      Exit;
  end;
  Result := True;
end;

function TryFindSnapshotUnitByFile(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; out aUnit: TUnitSnapshot): Boolean;
var
  i: Integer;
  lUnit: TUnitSnapshot;
begin
  aUnit := nil;
  if not Assigned(aSnapshot) then
    Exit(False);
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    if SamePath(aSnapshot.TextOf(lUnit.FileNameId), aFileName) then
    begin
      if Assigned(aUnit) then
        Exit(False);
      aUnit := lUnit;
    end;
  end;
  Result := Assigned(aUnit);
end;

function TryFindSnapshotUnitByName(const aSnapshot: TDelphiProjectSnapshot;
  const aUnitName: string; out aUnit: TUnitSnapshot): Boolean;
var
  i: Integer;
  lUnit: TUnitSnapshot;
begin
  aUnit := nil;
  if not Assigned(aSnapshot) then
    Exit(False);
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    if SameText(aSnapshot.TextOf(lUnit.UnitNameId), aUnitName) then
    begin
      if Assigned(aUnit) then
        Exit(False);
      aUnit := lUnit;
    end;
  end;
  Result := Assigned(aUnit);
end;

function TryPositionOfOffset(const aText: string; const aOffset: Integer;
  out aLine, aColumn: Integer): Boolean;
var
  i: Integer;
begin
  aLine := 1;
  aColumn := 1;
  Result := (aOffset >= 1) and (aOffset <= Length(aText) + 1);
  if not Result then
    Exit;
  i := 1;
  while i < aOffset do
  begin
    if aText[i] = #13 then
    begin
      Inc(aLine);
      aColumn := 1;
      Inc(i);
      if (i < aOffset) and (aText[i] = #10) then
        Inc(i);
    end else if aText[i] = #10 then
    begin
      Inc(aLine);
      aColumn := 1;
      Inc(i);
    end else begin
      Inc(aColumn);
      Inc(i);
    end;
  end;
end;

function TryCreateClauseEdit(const aFileName, aText: string; const aClauseMatch: TMatch;
  out aEdit: TSemanticPlanEdit): Boolean;
var
  lEndLine: Integer;
  lEndColumn: Integer;
  lStartLine: Integer;
  lStartColumn: Integer;
  lStartOffset: Integer;
  lEndOffset: Integer;
  lGroup: TGroup;
begin
  aEdit := Default(TSemanticPlanEdit);
  lGroup := aClauseMatch.Groups['clause'];
  lStartOffset := lGroup.Index;
  lEndOffset := lStartOffset + lGroup.Length;
  Result := TryPositionOfOffset(aText, lStartOffset, lStartLine, lStartColumn) and
    TryPositionOfOffset(aText, lEndOffset, lEndLine, lEndColumn);
  if not Result then
    Exit;
  aEdit.FileName := aFileName;
  aEdit.StartLine := lStartLine;
  aEdit.StartColumn := lStartColumn;
  aEdit.EndLine := lEndLine;
  aEdit.EndColumn := lEndColumn;
  aEdit.ExpectedText := lGroup.Value;
  aEdit.ReplacementText := '';
end;

procedure ClassifyRemovalConsumerClause(const aText, aUnitName: string;
  out aClassification: TDelphiSemanticUsesClassification; out aReason: string);
begin
  aClassification := TDelphiSemanticUsesClassification.ucUnsupportedShape;
  aReason := 'uses.consumer-shape-unsupported';
  if (Pos('{$IF', UpperCase(aText)) > 0) and
    (Pos(UpperCase(aUnitName), UpperCase(aText)) > 0) then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucConditionalClause;
    aReason := 'uses.conditional-clause';
    Exit;
  end;
  if TRegEx.IsMatch(aText,
    '(?is)\binterface\s+uses\s+' + TRegEx.Escape(aUnitName) + '\s*;') then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucInterfaceVisibleUse;
    aReason := 'uses.interface-visible';
    Exit;
  end;
end;

function TryGetObservedPlanSource(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aFileName: string; out aPlanSource: TSemanticPlanSource;
  out aObservedSource: TDelphiSemanticSourceText): Boolean;
var
  lModelEvidence: TDelphiSemanticContextModelEvidence;
  lUnit: TUnitSnapshot;
begin
  Result := False;
  if not TryFindPlanSource(aBinding.Plan, aFileName, aPlanSource) then
    Exit;
  if not TryFindModelEvidence(aContextEvidence, aFileName, lModelEvidence) then
    Exit;
  if not Assigned(lModelEvidence.SourceObservations) then
    Exit;
  if not lModelEvidence.SourceObservations.TryFind(aFileName, aObservedSource) or
    not TryFindSnapshotUnitByFile(aSnapshot, aFileName, lUnit) then
    Exit;
  Result := (aPlanSource.ContentHash = aObservedSource.ContentHash) and
    (aPlanSource.OriginalText = aObservedSource.Text) and
    (aSnapshot.ExactTextOf(lUnit.SourceTextId) = aPlanSource.OriginalText);
end;

function TryGetPlanUnitSource(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult; const aFileName: string;
  out aPlanSource: TSemanticPlanSource; out aUnit: TUnitSnapshot): Boolean;
begin
  aPlanSource := Default(TSemanticPlanSource);
  aUnit := nil;
  Result := False;
  if not TryFindPlanSource(aBinding.Plan, aFileName, aPlanSource) then
    Exit;
  if not TryFindSnapshotUnitByFile(aSnapshot, aFileName, aUnit) then
    Exit;
  Result := aSnapshot.ExactTextOf(aUnit.SourceTextId) = aPlanSource.OriginalText;
end;

function MakePlanResult(const aBinding: TDelphiSemanticBoundPlanResult;
  const aStatus: TSemanticPlanStatus; const aClassification: TDelphiSemanticUsesClassification;
  const aReason: string; const aEdits: TArray<TSemanticPlanEdit> = nil):
  TDelphiSemanticUsesPlanningResult;
var
  i: Integer;
  lError: string;
  lBoundPlan: TSemanticRefactoringPlan;
  lPlan: TSemanticRefactoringPlan;
  lSources: TArray<TSemanticPlanSource>;
begin
  Result := Default(TDelphiSemanticUsesPlanningResult);
  Result.Classification := aClassification;
  Result.Reason := aReason;
  if not Assigned(aBinding) or not Assigned(aBinding.Plan) then
    Exit;
  lBoundPlan := aBinding.Plan;
  SetLength(lSources, lBoundPlan.SourceCount);
  for i := 0 to lBoundPlan.SourceCount - 1 do
    lSources[i] := lBoundPlan.Sources[i];
  if not TSemanticRefactoringPlan.TryCreate(lBoundPlan.Context, aStatus, aReason,
    lSources, aEdits, lPlan, lError) then
  begin
    Result.Classification := TDelphiSemanticUsesClassification.ucUnknown;
    Result.Reason := lError;
  end else
    Result.Plan := lPlan;
end;

function HasFullAnalysisCoverage(const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aBinding: TDelphiSemanticBoundPlanResult; out aReason: string): Boolean;
var
  lAnalyzedRoots: TArray<string>;
  lExpectedRoots: TArray<string>;
begin
  Result := False;
  if not HasCoProducedFullAnalysis(aContextEvidence, aBinding) then
  begin
    aReason := 'uses.context-evidence-incomplete';
    Exit;
  end;
  if not ((TSemanticPlanAnalysisKind.pakBodyAnalysis in
      aBinding.RequiredAnalysisKinds) and
    (TSemanticPlanAnalysisKind.pakReferenceExtraction in
      aBinding.RequiredAnalysisKinds)) then
  begin
    aReason := 'uses.required-analysis-incomplete';
    Exit;
  end;
  lExpectedRoots := aBinding.ExpectedRootFileNames;
  lAnalyzedRoots := aBinding.AnalyzedRootFileNames;
  if not SamePathSet(lExpectedRoots, lAnalyzedRoots) or
    not SamePathSet(lExpectedRoots, aBinding.ScopeRootFileNames) then
  begin
    aReason := 'uses.scope-incomplete';
    Exit;
  end;
  aReason := '';
  Result := True;
end;

function HasUnverifiedNoChangeContext(const aBinding: TDelphiSemanticBoundPlanResult;
  const aOperationIdentity: string): Boolean;
var
  lDiagnostic: string;
begin
  Result := False;
  if not Assigned(aBinding) or not Assigned(aBinding.Plan) or
    (aBinding.Status <> TSemanticPlanStatus.NoChange) or
    (aBinding.Plan.Status <> TSemanticPlanStatus.NoChange) or
    (aBinding.Plan.EditCount <> 0) or
    (aBinding.OperationIdentity <> aOperationIdentity) then
    Exit;
  for lDiagnostic in aBinding.Diagnostics do
    if SameText(lDiagnostic, 'UNVERIFIED_PREPROCESS_CONDITION') then
      Exit(True);
end;

function TryGetFullNoChangeContext(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult; const aOperationIdentity: string;
  out aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  out aReason: string): Boolean;
var
  lExtension: TObject;
  lSelectedConfigurations: TArray<string>;
begin
  Result := False;
  aContextEvidence := nil;
  aReason := 'uses.binding-required';
  if not Assigned(aSnapshot) or not Assigned(aBinding) or
    not Assigned(aBinding.Plan) then
    Exit;
  if (aBinding.Status <> TSemanticPlanStatus.NoChange) or
    (aBinding.Plan.Status <> TSemanticPlanStatus.NoChange) or
    (aBinding.Plan.EditCount <> 0) or
    (aBinding.OperationIdentity <> aOperationIdentity) then
  begin
    aReason := 'uses.context-binding-required';
    Exit;
  end;
  if not aSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
    lExtension) or not (lExtension is TDelphiSemanticContextEvidenceExtension) then
  begin
    aReason := 'uses.context-evidence-missing';
    Exit;
  end;
  aContextEvidence := lExtension as TDelphiSemanticContextEvidenceExtension;
  if not HasFullAnalysisCoverage(aContextEvidence, aBinding, aReason) then
    Exit;
  lSelectedConfigurations := aBinding.SelectedConfigurationIdentities;
  if Length(lSelectedConfigurations) <> 1 then
  begin
    aReason := 'uses.configuration-unbound';
    Exit;
  end;
  if lSelectedConfigurations[0] <> aContextEvidence.ProjectConfigurationIdentity then
  begin
    aReason := 'uses.configuration-unbound';
    Exit;
  end;
  aReason := '';
  Result := True;
end;

function TryFindUnboundReference(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aIdentifier: string): Boolean;
var
  i: Integer;
  lReference: TSemanticReferenceFact;
  lFound: Boolean;
begin
  Result := False;
  lFound := False;
  for i := 1 to aUnit.ReferenceCount do
  begin
    lReference := aUnit.ReferenceById(TSemanticReferenceId(i));
    if not SameText(aSnapshot.TextOf(lReference.NameId), aIdentifier) then
      Continue;
    if (lReference.TargetUnitId <> 0) or (lReference.TargetSymbolId <> 0) then
      Exit(False);
    lFound := True;
  end;
  Result := lFound;
end;

function HasSingleUnboundImplementationReference(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aIdentifier: string): Boolean;
var
  i: Integer;
  lReference: TSemanticReferenceFact;
  lReferenceCount: Integer;
begin
  lReferenceCount := 0;
  for i := 1 to aUnit.ReferenceCount do
  begin
    lReference := aUnit.ReferenceById(TSemanticReferenceId(i));
    if not SameText(aSnapshot.TextOf(lReference.NameId), aIdentifier) then
      Continue;
    if (lReference.TargetUnitId <> 0) or (lReference.TargetSymbolId <> 0) or
      not SameText(aSnapshot.TextOf(lReference.SectionKindId), 'implementation') then
      Exit(False);
    Inc(lReferenceCount);
  end;
  Result := lReferenceCount = 1;
end;

function TryGetObservedProviderText(const aSnapshot: TDelphiProjectSnapshot;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aBinding: TDelphiSemanticBoundPlanResult; const aUnit: TUnitSnapshot;
  out aProviderText: string): Boolean;
var
  lObservedSource: TDelphiSemanticSourceText;
  lProviderSource: TSemanticPlanSource;
begin
  Result := False;
  aProviderText := '';
  if not TryGetObservedPlanSource(aSnapshot, aBinding, aContextEvidence,
    aSnapshot.TextOf(aUnit.FileNameId), lProviderSource, lObservedSource) then
    Exit;
  aProviderText := lProviderSource.OriginalText;
  Result := True;
end;

function ValidateSimpleConstantProvider(const aSnapshot: TDelphiProjectSnapshot;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aBinding: TDelphiSemanticBoundPlanResult; const aUnit: TUnitSnapshot;
  const aRequestedIdentifier: string): Boolean;
var
  i: Integer;
  lDeclarationMatch: TMatchCollection;
  lMatch: TMatch;
  lProviderText: string;
  lSymbol: TSemanticSymbolFact;
  lFoundRequestedSymbol: Boolean;
begin
  Result := False;
  if not TryGetObservedProviderText(aSnapshot, aContextEvidence, aBinding,
    aUnit, lProviderText) then
    Exit;
  lMatch := TRegEx.Match(lProviderText, cSimpleConstantProviderPattern);
  if not lMatch.Success or
    not SameText(lMatch.Groups['unit'].Value, aSnapshot.TextOf(aUnit.UnitNameId)) or
    (aUnit.ReferenceCount <> 0) then
    Exit;
  lDeclarationMatch := TRegEx.Matches(lMatch.Groups['declarations'].Value,
    '[A-Za-z_][A-Za-z0-9_]*\s*=\s*-?[0-9]+\s*;');
  if (lDeclarationMatch.Count = 0) or (lDeclarationMatch.Count <> aUnit.SymbolCount) then
    Exit;
  lFoundRequestedSymbol := aRequestedIdentifier = '';
  for i := 1 to aUnit.SymbolCount do
  begin
    lSymbol := aUnit.SymbolById(TSemanticSymbolId(i));
    if not SameText(aSnapshot.TextOf(lSymbol.KindId), 'const') or
      not SameText(aSnapshot.TextOf(lSymbol.SectionKindId), 'interface') or
      not SameText(aSnapshot.TextOf(lSymbol.ScopeKindId), 'unit') then
      Exit;
    if (aRequestedIdentifier <> '') and
      SameText(aSnapshot.TextOf(lSymbol.NameId), aRequestedIdentifier) then
      lFoundRequestedSymbol := True;
  end;
  Result := lFoundRequestedSymbol;
end;

function TryValidateMoveProvider(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aProviderUnit: TUnitSnapshot; out aClassification:
  TDelphiSemanticUsesClassification; out aReason: string): Boolean;
var
  lProviderText: string;
begin
  Result := ValidateSimpleConstantProvider(aSnapshot, aContextEvidence,
    aBinding, aProviderUnit, '');
  aClassification := TDelphiSemanticUsesClassification.ucUnsupportedShape;
  aReason := '';
  if Result then
    Exit;
  lProviderText := aSnapshot.ExactTextOf(aProviderUnit.SourceTextId);
  aReason := 'uses.provider-shape-unsupported';
  if TRegEx.IsMatch(lProviderText, '(?is)\b(helper|operator)\b') then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown;
    aReason := 'uses.helper-or-operator-visibility-unknown';
  end else if TRegEx.IsMatch(lProviderText, '(?is)\b(initialization|finalization|uses)\b') then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucInitializationSensitive;
    aReason := 'uses.initialization-order-unknown';
  end;
end;

function TryGetMoveSourceFacts(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aConsumerFileName, aUnitName: string; out aConsumerUnit,
  aProviderUnit: TUnitSnapshot; out aClassification: TDelphiSemanticUsesClassification;
  out aReason: string): Boolean;
var
  lInterfaceMatch: TMatch;
  lConsumerSource: TSemanticPlanSource;
  lConsumerText: string;
begin
  Result := False;
  aConsumerUnit := nil;
  aProviderUnit := nil;
  aClassification := TDelphiSemanticUsesClassification.ucUnsupportedShape;
  aReason := 'uses.consumer-source-mismatch';
  if not TryGetPlanUnitSource(aSnapshot, aBinding, aConsumerFileName,
    lConsumerSource, aConsumerUnit) then
    Exit;
  lConsumerText := lConsumerSource.OriginalText;
  if Pos('{$IF', UpperCase(lConsumerText)) > 0 then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucConditionalClause;
    aReason := 'uses.conditional-clause';
    Exit;
  end;
  if (TRegEx.Matches(lConsumerText, '(?i)\buses\b').Count <> 1) or
    TRegEx.IsMatch(lConsumerText, '//|\{|\(\*') then
  begin
    aReason := 'uses.interface-clause-shape-unsupported';
    Exit;
  end;
  lInterfaceMatch := TRegEx.Match(lConsumerText, cSimpleInterfaceUsesPattern);
  if not lInterfaceMatch.Success or
    not SameText(lInterfaceMatch.Groups['unit'].Value, aUnitName) then
  begin
    aReason := 'uses.interface-import-not-present';
    Exit;
  end;
  if not TryFindSnapshotUnitByName(aSnapshot, aUnitName, aProviderUnit) then
  begin
    aReason := 'uses.source-provider-required';
    Exit;
  end;
  if not TryValidateMoveProvider(aSnapshot, aBinding, aContextEvidence,
    aProviderUnit, aClassification, aReason) then
    Exit;
  aReason := '';
  Result := True;
end;

function HasImplementationOnlyProviderReferences(const aSnapshot: TDelphiProjectSnapshot;
  const aConsumerUnit, aProviderUnit: TUnitSnapshot;
  out aClassification: TDelphiSemanticUsesClassification; out aReason: string): Boolean;
var
  i: Integer;
  lReference: TSemanticReferenceFact;
  lReferenceCount: Integer;
  lSymbol: TSemanticSymbolFact;
begin
  Result := False;
  aClassification := TDelphiSemanticUsesClassification.ucUnknown;
  aReason := 'uses.move-implementation-reference-required';
  lReferenceCount := 0;
  for i := 1 to aConsumerUnit.ReferenceCount do
  begin
    lReference := aConsumerUnit.ReferenceById(TSemanticReferenceId(i));
    if lReference.TargetUnitId <> aProviderUnit.UnitId then
      Continue;
    if SameText(aSnapshot.TextOf(lReference.SectionKindId), 'interface') then
    begin
      aClassification := TDelphiSemanticUsesClassification.ucInterfaceVisibleUse;
      aReason := 'uses.interface-reference-remains';
      Exit;
    end;
    if not SameText(aSnapshot.TextOf(lReference.SectionKindId), 'implementation') or
      (lReference.TargetSymbolId = 0) then
    begin
      aReason := 'uses.reference-binding-unknown';
      Exit;
    end;
    lSymbol := aProviderUnit.SymbolById(lReference.TargetSymbolId);
    if not SameText(aSnapshot.TextOf(lSymbol.SectionKindId), 'interface') or
      not SameText(aSnapshot.TextOf(lSymbol.ScopeKindId), 'unit') then
    begin
      aClassification := TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown;
      aReason := 'uses.non-top-level-symbol-visibility-unknown';
      Exit;
    end;
    Inc(lReferenceCount);
  end;
  Result := lReferenceCount > 0;
  if Result then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucInterfaceImplementationMoveCandidate;
    aReason := 'uses.move-post-edit-revalidation-required';
  end;
end;

function HasPreservedMoveBindings(const aSnapshot: TDelphiProjectSnapshot;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aConsumerUnit: TUnitSnapshot; const aUnitName: string;
  out aReason: string): Boolean;
var
  lEvidence: TDelphiSemanticContextModelEvidence;
  lModel: TDelphiSemanticUnitModel;
  lComparison: TDelphiSnapshotImportBindingComparison;
begin
  Result := False;
  aReason := 'uses.reference-binding-unknown';
  if not TryFindModelEvidence(aContextEvidence,
    aSnapshot.TextOf(aConsumerUnit.FileNameId), lEvidence) then
    Exit;
  if not lEvidence.ModelSucceeded or not lEvidence.BodyAnalysisIncluded or
    not lEvidence.ReferenceExtractionIncluded or not lEvidence.DependencyFacts.Known or
    (Length(lEvidence.ModelDiagnostics) <> 0) or
    (aConsumerUnit.WithStatementCount <> 0) or
    not SameText(aSnapshot.TextOf(aConsumerUnit.ScopeModelStatusId), 'ast') then
    Exit;
  // The current move candidate has one interface import and no implementation clause.
  if (Length(lEvidence.DependencyFacts.InterfaceImports) <> 1) or
    not SameText(lEvidence.DependencyFacts.InterfaceImports[0], aUnitName) or
    (Length(lEvidence.DependencyFacts.ImplementationImports) <> 0) then
    Exit;
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.UnitName := aSnapshot.TextOf(aConsumerUnit.UnitNameId);
  lModel.SourceText := aSnapshot.ExactTextOf(aConsumerUnit.SourceTextId);
  lModel.InterfaceUses := lEvidence.DependencyFacts.InterfaceImports;
  lModel.ImplementationUses := lEvidence.DependencyFacts.ImplementationImports;
  lModel.References := lEvidence.References;
  lComparison := CompareSnapshotImportBindings(aSnapshot, lModel, [], [aUnitName]);
  Result := lComparison.Complete and lComparison.Preserved;
  if not Result then
    aReason := lComparison.Reason
  else
    aReason := 'uses.move-post-edit-revalidation-required';
end;

function TryCollectMoveOrderModels(const aSnapshot: TDelphiProjectSnapshot;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aConsumerUnit: TUnitSnapshot; out aModels: TArray<TDelphiSemanticUnitModel>;
  out aRootName: string; out aConsumerIndex: Integer): Boolean;
var
  lEvidence: TDelphiSemanticContextModelEvidence;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
  i: Integer;
begin
  Result := False;
  aModels := nil;
  aRootName := '';
  aConsumerIndex := -1;
  if aContextEvidence.MainSourceFileName = '' then
    Exit;
  SetLength(aModels, aContextEvidence.ModelCount);
  for i := 0 to aContextEvidence.ModelCount - 1 do
  begin
    lEvidence := aContextEvidence.ModelEvidence[i];
    if not lEvidence.ModelSucceeded or not lEvidence.DependencyFacts.Known or
      (Length(lEvidence.ModelDiagnostics) <> 0) or
      not aSnapshot.TryFindUnitByFileName(lEvidence.SourceFileName, lUnitId) or
      not aSnapshot.TryFindUnitById(lUnitId, lUnit) then
      Exit;
    aModels[i].UnitName := aSnapshot.TextOf(lUnit.UnitNameId);
    aModels[i].Success := True;
    aModels[i].DependencyFacts := lEvidence.DependencyFacts;
    if SameText(lEvidence.SourceFileName, aContextEvidence.MainSourceFileName) then
      aRootName := aModels[i].UnitName;
    if lUnit.UnitId = aConsumerUnit.UnitId then
      aConsumerIndex := i;
  end;
  Result := (aRootName <> '') and (aConsumerIndex >= 0);
end;

function HasPackageFreeCompilerContext(
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  out aReason: string): Boolean;
var
  lProperties: TArray<TDelphiSemanticProperty>;
  lValue: string;
  i: Integer;
begin
  Result := False;
  aReason := 'uses.compiler-link-context-unknown';
  lProperties := aContextEvidence.CompilerLinkProperties;
  if Length(lProperties) <> Length(cDelphiSemanticCompilerLinkPropertyNames) then
    Exit;
  for i := 0 to High(lProperties) do
    if not SameText(lProperties[i].Name, cDelphiSemanticCompilerLinkPropertyNames[i]) then
      Exit;
  if Trim(lProperties[4].Value) <> '' then
  begin
    aReason := 'uses.compiler-switches-unsupported';
    Exit;
  end;
  if Trim(lProperties[3].Value) <> '' then
  begin
    aReason := 'uses.runtime-packages-unsupported';
    Exit;
  end;
  for i := 1 to 2 do
  begin
    lValue := Trim(lProperties[i].Value);
    if (lValue <> '') and not SameText(lValue, 'false') then
    begin
      if SameText(lValue, 'true') then
        aReason := 'uses.runtime-packages-unsupported';
      Exit(False);
    end;
  end;
  // DCC_UsePackage is inactive when both enable flags and _UsePackage are empty/false.
  Result := True;
  aReason := '';
end;

function HasPreservedExplicitMoveOrder(const aSnapshot: TDelphiProjectSnapshot;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aConsumerUnit: TUnitSnapshot; const aUnitName: string;
  out aReason: string): Boolean;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lRootName: string;
  lConsumerIndex: Integer;
  lBefore, lAfter: TDelphiSemanticUnitOrderResult;
  i: Integer;
begin
  Result := False;
  if not HasPackageFreeCompilerContext(aContextEvidence, aReason) then
    Exit;
  aReason := 'uses.order-unresolved';
  if not TryCollectMoveOrderModels(aSnapshot, aContextEvidence, aConsumerUnit,
    lModels, lRootName, lConsumerIndex) then
    Exit;
  lBefore := TDelphiSemanticUnitOrder.Analyze(lModels, [lRootName]);
  if not lBefore.Known then
    Exit;
  lModels[lConsumerIndex].DependencyFacts.InterfaceImports := nil;
  lModels[lConsumerIndex].DependencyFacts.ImplementationImports := [aUnitName];
  lAfter := TDelphiSemanticUnitOrder.Analyze(lModels, [lRootName]);
  if not lAfter.Known then
    Exit;
  aReason := 'uses.order-changed';
  if Length(lBefore.InitializationOrder) <> Length(lAfter.InitializationOrder) then
    Exit;
  for i := 0 to High(lBefore.InitializationOrder) do
    if not SameText(lBefore.InitializationOrder[i], lAfter.InitializationOrder[i]) then
      Exit;
  // Finalization is the reverse of this complete explicit dependency traversal.
  // Implicit runtime/package behavior still needs proof before an edit is emitted.
  Result := True;
  aReason := 'uses.move-post-edit-revalidation-required';
end;

procedure AddSortedCandidate(const aCandidates: TList<string>; const aUnitName: string);
var
  i: NativeInt;
begin
  for i := 0 to aCandidates.Count - 1 do
  begin
    if SameText(aCandidates[i], aUnitName) then
      Exit;
    if CompareText(aUnitName, aCandidates[i]) < 0 then
    begin
      aCandidates.Insert(i, aUnitName);
      Exit;
    end;
  end;
  aCandidates.Add(aUnitName);
end;

function TryGetUnboundSuggestionInput(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult; const aConsumerFileName,
  aIdentifier: string; out aConsumerText, aReason: string): Boolean;
var
  lConsumerSource: TSemanticPlanSource;
  lConsumerUnit: TUnitSnapshot;
begin
  Result := False;
  aConsumerText := '';
  aReason := '';
  if not TryGetPlanUnitSource(aSnapshot, aBinding, aConsumerFileName,
    lConsumerSource, lConsumerUnit) then
  begin
    aReason := 'uses.consumer-source-mismatch';
    Exit;
  end;
  if not TryFindUnboundReference(aSnapshot, lConsumerUnit, aIdentifier) then
  begin
    aReason := 'uses.unbound-reference-required';
    Exit;
  end;
  aConsumerText := lConsumerSource.OriginalText;
  if TRegEx.IsMatch(aConsumerText, '(?i)\b[A-Za-z_][A-Za-z0-9_]*\s*\.\s*' +
    TRegEx.Escape(aIdentifier) + '\b') then
  begin
    aReason := 'uses.qualified-reference-not-importable';
    Result := False;
    Exit;
  end;
  aReason := '';
  Result := True;
end;

function FindExplicitImportCandidates(const aSnapshot: TDelphiProjectSnapshot;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aBinding: TDelphiSemanticBoundPlanResult; const aConsumerFileName,
  aIdentifier: string): TArray<string>;
var
  i: Integer;
  lCandidates: TList<string>;
  lUnit: TUnitSnapshot;
begin
  lCandidates := TList<string>.Create;
  try
    for i := 0 to aSnapshot.UnitCount - 1 do
    begin
      lUnit := aSnapshot.UnitByIndex(i);
      if SamePath(aSnapshot.TextOf(lUnit.FileNameId), aConsumerFileName) or
        not ValidateSimpleConstantProvider(aSnapshot, aContextEvidence, aBinding,
          lUnit, aIdentifier) then
        Continue;
      AddSortedCandidate(lCandidates, aSnapshot.TextOf(lUnit.UnitNameId));
    end;
    Result := lCandidates.ToArray;
  finally
    lCandidates.Free;
  end;
end;

function TryCreateRemovalConsumerEdit(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aConsumerFileName, aUnitName: string; out aStatus: TSemanticPlanStatus;
  out aClassification: TDelphiSemanticUsesClassification; out aReason: string;
  out aEdit: TSemanticPlanEdit): Boolean;
var
  lClauseMatch: TMatch;
  lConsumerSource: TSemanticPlanSource;
  lConsumerUnit: TUnitSnapshot;
begin
  aStatus := TSemanticPlanStatus.Blocked;
  aClassification := TDelphiSemanticUsesClassification.ucUnsupportedShape;
  aReason := 'uses.consumer-shape-unsupported';
  aEdit := Default(TSemanticPlanEdit);
  Result := False;
  if not TryFindPlanSource(aBinding.Plan, aConsumerFileName, lConsumerSource) or
    not TryFindSnapshotUnitByFile(aSnapshot, aConsumerFileName, lConsumerUnit) then
    Exit;
  if (aSnapshot.ExactTextOf(lConsumerUnit.SourceTextId) <> lConsumerSource.OriginalText) or
    (lConsumerUnit.SymbolCount <> 0) or (lConsumerUnit.ReferenceCount <> 0) then
    Exit;
  lClauseMatch := TRegEx.Match(lConsumerSource.OriginalText, cSimpleConsumerPattern);
  if not lClauseMatch.Success then
  begin
    ClassifyRemovalConsumerClause(lConsumerSource.OriginalText, aUnitName,
      aClassification, aReason);
    Exit;
  end;
  if not SameText(lClauseMatch.Groups['unit'].Value, aUnitName) then
  begin
    aStatus := TSemanticPlanStatus.NoChange;
    aClassification := TDelphiSemanticUsesClassification.ucNoOp;
    aReason := 'uses.import-absent';
    Result := True;
    Exit;
  end;
  if not TryCreateClauseEdit(lConsumerSource.FileName, lConsumerSource.OriginalText,
    lClauseMatch, aEdit) then
  begin
    aReason := 'uses.edit-range-invalid';
    Exit;
  end;
  aStatus := TSemanticPlanStatus.Complete;
  aClassification := TDelphiSemanticUsesClassification.ucSafeImplementationImportRemoval;
  aReason := '';
  Result := True;
end;

function TryValidateSafeRemovalLeaf(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aUnitName: string; out aClassification: TDelphiSemanticUsesClassification;
  out aReason: string): Boolean;
var
  lLeafMatch: TMatch;
  lLeafSource: TSemanticPlanSource;
  lLeafUnit: TUnitSnapshot;
  lObservedSource: TDelphiSemanticSourceText;
begin
  Result := False;
  aClassification := TDelphiSemanticUsesClassification.ucUnsupportedShape;
  aReason := 'uses.leaf-evidence-missing';
  if not TryFindSnapshotUnitByName(aSnapshot, aUnitName, lLeafUnit) then
    Exit;
  if not TryGetObservedPlanSource(aSnapshot, aBinding, aContextEvidence,
    aSnapshot.TextOf(lLeafUnit.FileNameId), lLeafSource, lObservedSource) then
  begin
    aReason := 'uses.leaf-source-mismatch';
    Exit;
  end;
  aReason := 'uses.leaf-source-mismatch';
  lLeafMatch := TRegEx.Match(lLeafSource.OriginalText, cSimpleLeafPattern);
  if not lLeafMatch.Success or not SameText(lLeafMatch.Groups['unit'].Value, aUnitName) or
    (lLeafUnit.SymbolCount <> 0) or (lLeafUnit.ReferenceCount <> 0) then
  begin
    if TRegEx.IsMatch(lLeafSource.OriginalText,
      '(?is)\b(initialization|finalization|uses)\b') then
    begin
      aClassification := TDelphiSemanticUsesClassification.ucInitializationSensitive;
      aReason := 'uses.initialization-order-unknown';
      Exit;
    end;
    if TRegEx.IsMatch(lLeafSource.OriginalText, '(?is)\b(helper|operator)\b') then
    begin
      aClassification := TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown;
      aReason := 'uses.helper-or-operator-visibility-unknown';
      Exit;
    end;
    aReason := 'uses.leaf-shape-unsupported';
    Exit;
  end;
  Result := True;
end;

class function TDelphiSemanticUsesPlanner.PlanRemoveImplementationImport(
  const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aConsumerFileName, aUnitName: string): TDelphiSemanticUsesPlanningResult;
var
  lClassification: TDelphiSemanticUsesClassification;
  lContextEvidence: TDelphiSemanticContextEvidenceExtension;
  lEdit: TSemanticPlanEdit;
  lReason: string;
  lStatus: TSemanticPlanStatus;
begin
  // Raw conditional syntax can establish refusal, never an active-code proof.
  if HasUnverifiedNoChangeContext(aBinding, cRemoveImplementationImportOperation) and
    not TryCreateRemovalConsumerEdit(aSnapshot, aBinding, aConsumerFileName,
      aUnitName, lStatus, lClassification, lReason, lEdit) and
    (lClassification = TDelphiSemanticUsesClassification.ucConditionalClause) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      lClassification, lReason));
  if not TryGetFullNoChangeContext(aSnapshot, aBinding,
    cRemoveImplementationImportOperation, lContextEvidence, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Incomplete,
      TDelphiSemanticUsesClassification.ucIncompleteScope, lReason));
  if not TryCreateRemovalConsumerEdit(aSnapshot, aBinding, aConsumerFileName,
    aUnitName, lStatus, lClassification, lReason, lEdit) then
    Exit(MakePlanResult(aBinding, lStatus, lClassification, lReason));
  if lStatus = TSemanticPlanStatus.NoChange then
    Exit(MakePlanResult(aBinding, lStatus, lClassification, lReason));
  if not TryValidateSafeRemovalLeaf(aSnapshot, aBinding, lContextEvidence,
    aUnitName, lClassification, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked, lClassification, lReason));
  Result := MakePlanResult(aBinding, TSemanticPlanStatus.Complete,
    TDelphiSemanticUsesClassification.ucSafeImplementationImportRemoval, '', [lEdit]);
end;

class function TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
  const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aConsumerFileName, aUnitName: string): TDelphiSemanticUsesPlanningResult;
var
  lConsumerUnit: TUnitSnapshot;
  lContextEvidence: TDelphiSemanticContextEvidenceExtension;
  lClassification: TDelphiSemanticUsesClassification;
  lReason: string;
  lProviderUnit: TUnitSnapshot;
begin
  Result := Default(TDelphiSemanticUsesPlanningResult);
  if not TryGetFullNoChangeContext(aSnapshot, aBinding,
    cAnalyzeInterfaceImportMoveOperation, lContextEvidence, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Incomplete,
      TDelphiSemanticUsesClassification.ucIncompleteScope, lReason));
  if not TryGetMoveSourceFacts(aSnapshot, aBinding, lContextEvidence,
    aConsumerFileName, aUnitName, lConsumerUnit, lProviderUnit,
    lClassification, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      lClassification, lReason));
  if not HasImplementationOnlyProviderReferences(aSnapshot, lConsumerUnit,
    lProviderUnit, lClassification, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      lClassification, lReason));
  if not HasPreservedMoveBindings(aSnapshot, lContextEvidence, lConsumerUnit,
    aUnitName, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      TDelphiSemanticUsesClassification.ucUnknown, lReason));
  if not HasPreservedExplicitMoveOrder(aSnapshot, lContextEvidence, lConsumerUnit,
    aUnitName, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      TDelphiSemanticUsesClassification.ucUnknown, lReason));
  Result := MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
    lClassification, lReason);
  Result.CandidateUnitNames := [aUnitName];
end;

class function TDelphiSemanticUsesPlanner.SuggestExplicitImportCandidates(
  const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aConsumerFileName, aIdentifier: string): TDelphiSemanticUsesPlanningResult;
var
  lCandidates: TArray<string>;
  lConsumerText: string;
  lContextEvidence: TDelphiSemanticContextEvidenceExtension;
  lReason: string;
begin
  Result := Default(TDelphiSemanticUsesPlanningResult);
  Result.Classification := TDelphiSemanticUsesClassification.ucUnknown;
  if not TRegEx.IsMatch(aIdentifier, '\A[A-Za-z_][A-Za-z0-9_]*\z') then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      TDelphiSemanticUsesClassification.ucUnsupportedShape,
      'uses.identifier-shape-unsupported'));
  if not TryGetFullNoChangeContext(aSnapshot, aBinding,
    cSuggestExplicitImportCandidatesOperation, lContextEvidence, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Incomplete,
      TDelphiSemanticUsesClassification.ucIncompleteScope, lReason));
  if not TryGetUnboundSuggestionInput(aSnapshot, aBinding, aConsumerFileName,
    aIdentifier, lConsumerText, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      TDelphiSemanticUsesClassification.ucUnsupportedShape,
      lReason));
  lCandidates := FindExplicitImportCandidates(aSnapshot, lContextEvidence,
    aBinding, aConsumerFileName, aIdentifier);
  if Length(lCandidates) = 0 then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      TDelphiSemanticUsesClassification.ucUnknown,
      'uses.no-source-backed-candidate'));
  if Length(lCandidates) = 1 then
    Result := MakePlanResult(aBinding, TSemanticPlanStatus.NoChange,
      TDelphiSemanticUsesClassification.ucExplicitImportCandidate,
      'uses.unique-explicit-import-candidate')
  else
    Result := MakePlanResult(aBinding, TSemanticPlanStatus.NoChange,
      TDelphiSemanticUsesClassification.ucAmbiguousExplicitImportCandidate,
      'uses.ambiguous-explicit-import-candidates');
  Result.CandidateUnitNames := lCandidates;
end;

function TryGetExplicitImportInput(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult; const aConsumerFileName,
  aIdentifier, aUnitName: string; out aConsumerSource: TSemanticPlanSource;
  out aClauseMatch: TMatch; out aClassification: TDelphiSemanticUsesClassification;
  out aReason: string): Boolean;
var
  lConsumerText: string;
  lConsumerUnit: TUnitSnapshot;
begin
  Result := False;
  aClassification := TDelphiSemanticUsesClassification.ucUnsupportedShape;
  aReason := 'uses.consumer-source-mismatch';
  if not TryGetPlanUnitSource(aSnapshot, aBinding, aConsumerFileName,
    aConsumerSource, lConsumerUnit) then
    Exit;
  lConsumerText := aConsumerSource.OriginalText;
  if TRegEx.IsMatch(lConsumerText, '(?i)\b' + TRegEx.Escape(aUnitName) +
    '\s*\.\s*' + TRegEx.Escape(aIdentifier) + '\b') then
  begin
    aReason := 'uses.qualified-reference-not-importable';
    Exit;
  end;
  if Pos('{$IF', UpperCase(lConsumerText)) > 0 then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucConditionalClause;
    aReason := 'uses.conditional-clause';
    Exit;
  end;
  if TRegEx.IsMatch(lConsumerText, '//|\{|\(\*') or
    (TRegEx.Matches(lConsumerText, '(?i)\buses\b').Count <> 0) then
  begin
    aReason := 'uses.consumer-shape-unsupported';
    Exit;
  end;
  aClauseMatch := TRegEx.Match(lConsumerText, cSimpleExplicitImportConsumerPattern);
  if not aClauseMatch.Success or
    not SameText(aClauseMatch.Groups['identifier'].Value, aIdentifier) or
    not HasSingleUnboundImplementationReference(aSnapshot, lConsumerUnit, aIdentifier) then
  begin
    aReason := 'uses.single-implementation-reference-required';
    Exit;
  end;
  aReason := '';
  Result := True;
end;

function TryGetUniqueSelectedImportProvider(const aSnapshot: TDelphiProjectSnapshot;
  const aContextEvidence: TDelphiSemanticContextEvidenceExtension;
  const aBinding: TDelphiSemanticBoundPlanResult; const aConsumerFileName,
  aUnitName, aIdentifier: string; out aCandidateUnitNames: TArray<string>;
  out aClassification: TDelphiSemanticUsesClassification;
  out aReason: string): Boolean;
var
  lProviderUnit: TUnitSnapshot;
  lProviderText: string;
begin
  Result := False;
  aCandidateUnitNames := nil;
  aClassification := TDelphiSemanticUsesClassification.ucUnsupportedShape;
  aReason := 'uses.source-backed-provider-required';
  if not TryFindSnapshotUnitByName(aSnapshot, aUnitName, lProviderUnit) then
    Exit;
  if not ValidateSimpleConstantProvider(aSnapshot, aContextEvidence, aBinding,
    lProviderUnit, aIdentifier) then
  begin
    lProviderText := aSnapshot.ExactTextOf(lProviderUnit.SourceTextId);
    if TRegEx.IsMatch(lProviderText, '(?is)\b(helper|operator)\b') then
    begin
      aClassification := TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown;
      aReason := 'uses.helper-or-operator-visibility-unknown';
    end else if TRegEx.IsMatch(lProviderText, '(?is)\b(initialization|finalization|uses)\b') then
    begin
      aClassification := TDelphiSemanticUsesClassification.ucInitializationSensitive;
      aReason := 'uses.initialization-order-unknown';
    end else
      aReason := 'uses.selected-provider-does-not-declare-identifier';
    Exit;
  end;
  aCandidateUnitNames := FindExplicitImportCandidates(aSnapshot, aContextEvidence,
    aBinding, aConsumerFileName, aIdentifier);
  if Length(aCandidateUnitNames) <> 1 then
  begin
    aClassification := TDelphiSemanticUsesClassification.ucAmbiguousExplicitImportCandidate;
    aReason := 'uses.import-lookup-order-unknown';
    Exit;
  end;
  if not SameText(aCandidateUnitNames[0], aUnitName) then
  begin
    aReason := 'uses.selected-provider-not-unique-candidate';
    Exit;
  end;
  Result := True;
end;

function TryCreateExplicitImportEdit(const aConsumerSource: TSemanticPlanSource;
  const aConsumerText: string; const aClauseMatch: TMatch; const aUnitName: string;
  out aEdit: TSemanticPlanEdit): Boolean;
var
  lNewLine: string;
  lOffset: Integer;
  lStartColumn: Integer;
  lStartLine: Integer;
begin
  aEdit := Default(TSemanticPlanEdit);
  lOffset := aClauseMatch.Groups['gap'].Index + aClauseMatch.Groups['gap'].Length;
  Result := TryPositionOfOffset(aConsumerText, lOffset, lStartLine, lStartColumn);
  if not Result then
    Exit;
  aEdit.FileName := aConsumerSource.FileName;
  aEdit.StartLine := lStartLine;
  aEdit.StartColumn := lStartColumn;
  aEdit.EndLine := lStartLine;
  aEdit.EndColumn := lStartColumn;
  aEdit.ExpectedText := '';
  lNewLine := #13#10;
  if (Pos(#10, aConsumerText) > 0) and (Pos(#13#10, aConsumerText) = 0) then
    lNewLine := #10
  else if (Pos(#13, aConsumerText) > 0) and (Pos(#10, aConsumerText) = 0) then
    lNewLine := #13;
  aEdit.ReplacementText := 'uses ' + aUnitName + ';' + lNewLine;
end;

class function TDelphiSemanticUsesPlanner.PlanAddExplicitImport(
  const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TDelphiSemanticBoundPlanResult;
  const aConsumerFileName, aUnitName, aIdentifier: string):
  TDelphiSemanticUsesPlanningResult;
var
  lCandidates: TArray<string>;
  lClauseMatch: TMatch;
  lConsumerSource: TSemanticPlanSource;
  lConsumerText: string;
  lContextEvidence: TDelphiSemanticContextEvidenceExtension;
  lEdit: TSemanticPlanEdit;
  lClassification: TDelphiSemanticUsesClassification;
  lReason: string;
begin
  Result := Default(TDelphiSemanticUsesPlanningResult);
  Result.Classification := TDelphiSemanticUsesClassification.ucUnknown;
  if not TRegEx.IsMatch(aIdentifier, '\A[A-Za-z_][A-Za-z0-9_]*\z') or
    not TRegEx.IsMatch(aUnitName, '\A[A-Za-z_][A-Za-z0-9_]*\z') then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      TDelphiSemanticUsesClassification.ucUnsupportedShape,
      'uses.import-request-shape-unsupported'));
  if HasUnverifiedNoChangeContext(aBinding, cAddExplicitImportOperation) and
    not TryGetExplicitImportInput(aSnapshot, aBinding, aConsumerFileName,
      aIdentifier, aUnitName, lConsumerSource, lClauseMatch, lClassification, lReason) and
    (lClassification = TDelphiSemanticUsesClassification.ucConditionalClause) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      lClassification, lReason));
  if not TryGetFullNoChangeContext(aSnapshot, aBinding,
    cAddExplicitImportOperation, lContextEvidence, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Incomplete,
      TDelphiSemanticUsesClassification.ucIncompleteScope, lReason));
  if not TryGetExplicitImportInput(aSnapshot, aBinding, aConsumerFileName,
    aIdentifier, aUnitName, lConsumerSource, lClauseMatch,
    lClassification, lReason) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      lClassification, lReason));
  lConsumerText := lConsumerSource.OriginalText;
  if not TryGetUniqueSelectedImportProvider(aSnapshot, lContextEvidence,
    aBinding, aConsumerFileName, aUnitName, aIdentifier, lCandidates,
    lClassification, lReason) then
  begin
    Result := MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      lClassification, lReason);
    Result.CandidateUnitNames := lCandidates;
    Exit;
  end;
  if not TryCreateExplicitImportEdit(lConsumerSource, lConsumerText, lClauseMatch,
    aUnitName, lEdit) then
    Exit(MakePlanResult(aBinding, TSemanticPlanStatus.Blocked,
      TDelphiSemanticUsesClassification.ucUnsupportedShape, 'uses.edit-range-invalid'));
  Result := MakePlanResult(aBinding, TSemanticPlanStatus.Complete,
    TDelphiSemanticUsesClassification.ucSafeExplicitImportAddition, '', [lEdit]);
end;

end.
