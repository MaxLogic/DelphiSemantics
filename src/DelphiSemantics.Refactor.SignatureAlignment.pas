unit DelphiSemantics.Refactor.SignatureAlignment;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Refactor.Binding, DelphiSemantics.Resolve.TypeResolver,
  DelphiSemantics.Snapshot;

type
  TDelphiSemanticAlignmentComparison = record
    Status: string;
    Reason: string;
    DeclarationIndex: Integer;
    ImplementationIndex: Integer;
  end;

  TDelphiSemanticAlignmentParameterChange = record
    ParameterIndex: Integer;
    Original: TDelphiSemanticParameter;
    ReplacementName: string;
  end;

  // Known certifies parameter locations only, never body coverage or edit authorization.
  TDelphiSemanticAlignmentParameterChanges = record
    Comparison: TDelphiSemanticAlignmentComparison;
    Known: Boolean;
    Reason: string;
    Changes: TArray<TDelphiSemanticAlignmentParameterChange>;
  end;

  // Comparison facts are not an applicable edit plan or compiler certification.
  TDelphiSemanticSignatureAlignment = record
    class function Compare(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex; const aFileName: string;
      const aDeclarationOffset: Integer): TDelphiSemanticAlignmentComparison; static;
    // Caller owns the result. Required build/replan verifications remain mandatory.
    class function PlanAlignment(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex; const aSnapshot: TDelphiProjectSnapshot;
      const aFileName: string; const aDeclarationOffset: Integer):
      TDelphiSemanticBoundPlanResult; static;
    class function InspectParameterChanges(const aModels: TArray<TDelphiSemanticUnitModel>;
      const aTypes: TDelphiSemanticTypeIdentityIndex; const aFileName: string;
      const aDeclarationOffset: Integer): TDelphiSemanticAlignmentParameterChanges; static;
  end;

implementation

uses
  System.Generics.Collections, System.SysUtils,
  DelphiSemantics.Consistency.EventSignatures, DelphiSemantics.Consistency.Types,
  DelphiSemantics.Model.Text, DelphiSemantics.Refactor.Plan,
  DelphiSemantics.Snapshot.ContextEvidence;

type
  TImplementationCandidates = record
    Count: Integer;
    Matches: Integer;
    MatchIndex: Integer;
    LastIndex: Integer;
    Unknown: Boolean;
    LastComparison: TDelphiSemanticEventComparison;
  end;

function UnknownComparison(const aReason: string): TDelphiSemanticAlignmentComparison;
begin
  Result := Default(TDelphiSemanticAlignmentComparison);
  Result.Status := 'unknown';
  Result.Reason := aReason;
  Result.DeclarationIndex := -1;
  Result.ImplementationIndex := -1;
end;

function FindSelectedModel(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aFileName: string): Integer;
var
  i: Integer;
begin
  Result := -1;
  if aFileName = '' then
    Exit;
  for i := 0 to High(aModels) do
    if SameText(aModels[i].FileName, aFileName) then
    begin
      if Result >= 0 then
        Exit(-1);
      Result := i;
    end;
  if (Result >= 0) and
    (TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(aModels,
    aModels[Result].UnitName) <> Result) then
    Result := -1;
end;

function FindSelectedMember(const aModel: TDelphiSemanticUnitModel;
  const aOffset: Integer): Integer;
var
  i: Integer;
begin
  Result := -1;
  if aOffset < 1 then
    Exit;
  for i := 0 to High(aModel.Members) do
    if aModel.Members[i].Offset = aOffset then
    begin
      if Result >= 0 then
        Exit(-1);
      Result := i;
    end;
  if Result < 0 then
    Exit;
  if not SameText(aModel.Members[Result].Kind, 'method') or
    not SameText(Copy(aModel.SourceText, aOffset, Length(aModel.Members[Result].Name)),
    aModel.Members[Result].Name) then
    Result := -1;
end;

function CompareMethods(const aDeclaration, aImplementation: TDelphiSemanticProcedureSignature;
  const aUnit: string; const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex): TDelphiSemanticEventComparison;
var
  lExpected: TDelphiSemanticProcedureSignature;
begin
  lExpected := aDeclaration;
  // The selected source class method supplies the expected method-pointer shape.
  // Reuse parameter/type/convention comparison without changing retained model facts.
  lExpected.OfObject := True;
  Result := TDelphiSemanticEventSignatureComparer.CompareInContext(lExpected,
    aImplementation, aUnit, aUnit, aModels, aTypes);
end;

function FindImplementations(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aModelIndex, aMemberIndex: Integer):
  TImplementationCandidates;
var
  i: Integer;
  lMember: TDelphiSemanticMember;
  lRoutine: TDelphiSemanticRoutine;
  lComparison: TDelphiSemanticEventComparison;
begin
  Result := Default(TImplementationCandidates);
  Result.MatchIndex := -1;
  Result.LastIndex := -1;
  lMember := aModels[aModelIndex].Members[aMemberIndex];
  for i := 0 to High(aModels[aModelIndex].Routines) do
  begin
    lRoutine := aModels[aModelIndex].Routines[i];
    if not SameText(lRoutine.Name, lMember.Name) or
      not SameText(lRoutine.OwnerName, lMember.OwnerName) or
      not SameText(lRoutine.SectionKind, 'implementation') or (lRoutine.ParentScopeId <> '') then
      Continue;
    Inc(Result.Count);
    Result.LastIndex := i;
    lComparison := CompareMethods(lMember.ProcedureSignature, lRoutine.ProcedureSignature,
      aModels[aModelIndex].UnitName, aModels, aTypes);
    Result.LastComparison := lComparison;
    if lComparison.Status = 'match' then
    begin
      Inc(Result.Matches);
      Result.MatchIndex := i;
    end else if lComparison.Status = 'unknown' then
      Result.Unknown := True;
  end;
end;

function DeclarationIsUnique(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aModelIndex, aMemberIndex: Integer): Boolean;
var
  i: Integer;
  lSelected, lOther: TDelphiSemanticMember;
  lComparison: TDelphiSemanticEventComparison;
begin
  lSelected := aModels[aModelIndex].Members[aMemberIndex];
  for i := 0 to High(aModels[aModelIndex].Members) do
  begin
    lOther := aModels[aModelIndex].Members[i];
    if (i = aMemberIndex) or not SameText(lOther.OwnerName, lSelected.OwnerName) or
      not SameText(lOther.Name, lSelected.Name) or not SameText(lOther.Kind, 'method') then
      Continue;
    lComparison := CompareMethods(lSelected.ProcedureSignature, lOther.ProcedureSignature,
      aModels[aModelIndex].UnitName, aModels, aTypes);
    if lComparison.Status <> 'mismatch' then
      Exit(False);
  end;
  Result := True;
end;

function ParameterNamesMatch(const aDeclaration, aImplementation:
  TDelphiSemanticProcedureSignature): Boolean;
var
  i: Integer;
begin
  for i := 0 to High(aDeclaration.Parameters) do
    if not SameText(aDeclaration.Parameters[i].Name, aImplementation.Parameters[i].Name) then
      Exit(False);
  Result := True;
end;

function CompareSelectedMember(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aModelIndex, aMemberIndex: Integer):
  TDelphiSemanticAlignmentComparison;
var
  lCandidates: TImplementationCandidates;
begin
  Result := UnknownComparison('alignment.implementation-unpaired');
  Result.DeclarationIndex := aMemberIndex;
  lCandidates := FindImplementations(aModels, aTypes, aModelIndex, aMemberIndex);
  if lCandidates.Unknown or (lCandidates.Matches > 1) or
    not DeclarationIsUnique(aModels, aTypes, aModelIndex, aMemberIndex) then
  begin
    Result.Reason := 'alignment.pair-ambiguous';
    Exit;
  end;
  if lCandidates.Matches = 1 then
  begin
    Result.ImplementationIndex := lCandidates.MatchIndex;
    Result.Status := 'name-drift';
    Result.Reason := 'alignment.parameter-names';
    if ParameterNamesMatch(aModels[aModelIndex].Members[aMemberIndex].ProcedureSignature,
      aModels[aModelIndex].Routines[lCandidates.MatchIndex].ProcedureSignature) then
    begin
      Result.Status := 'aligned';
      Result.Reason := '';
    end;
  end else if lCandidates.Count = 1 then
  begin
    Result.ImplementationIndex := lCandidates.LastIndex;
    Result.Status := lCandidates.LastComparison.Status;
    Result.Reason := lCandidates.LastComparison.Reason;
  end;
end;

class function TDelphiSemanticSignatureAlignment.Compare(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aFileName: string;
  const aDeclarationOffset: Integer): TDelphiSemanticAlignmentComparison;
var
  lModel, lMember: Integer;
  lOwner: TDelphiSemanticConsistencyType;
begin
  Result := UnknownComparison('alignment.model-incomplete');
  lModel := FindSelectedModel(aModels, aFileName);
  if lModel < 0 then
    Exit;
  Result.Reason := 'alignment.declaration-unavailable';
  lMember := FindSelectedMember(aModels[lModel], aDeclarationOffset);
  if lMember < 0 then
    Exit;
  lOwner := TDelphiSemanticConsistencyTypeResolver.Resolve(aModels, aTypes,
    aModels[lModel].Members[lMember].OwnerName, aModels[lModel].UnitName);
  if not lOwner.Known or (lOwner.ModelIndex <> lModel) then
    Exit;
  if not SameText(aModels[lModel].Declarations[lOwner.DeclarationIndex].TypeName, 'class') then
    Exit;
  Result := CompareSelectedMember(aModels, aTypes, lModel, lMember);
end;

function WholeSourceIdentifier(const aText, aName: string; const aOffset: Integer): Boolean;
var
  lAfter: Integer;
begin
  Result := False;
  if (aName = '') or (aOffset < 1) or (aOffset > Length(aText)) then
    Exit;
  if Copy(aText, aOffset, Length(aName)) <> aName then
    Exit;
  lAfter := aOffset + Length(aName);
  if (aOffset > 1) and (IsIdentifierChar(aText[aOffset - 1]) or (Ord(aText[aOffset - 1]) > 127)) then
    Exit;
  if (lAfter <= Length(aText)) and (IsIdentifierChar(aText[lAfter]) or (Ord(aText[lAfter]) > 127)) then
    Exit;
  Result := True;
end;

function ParameterCoordinatesMatch(const aText: string;
  const aParameter: TDelphiSemanticParameter): Boolean;
var
  i, lLine, lColumn: Integer;
begin
  lLine := 1;
  lColumn := 1;
  for i := 1 to aParameter.Offset - 1 do
    if aText[i] = #10 then
    begin
      Inc(lLine);
      lColumn := 1;
    end else if aText[i] <> #13 then
      Inc(lColumn);
  Result := (aParameter.Line = lLine) and (aParameter.Column = lColumn);
end;

function TryParameterHeaderRange(const aText: string; const aRoutine: TDelphiSemanticRoutine;
  out aStart, aFinish: Integer): Boolean;
var
  i, lDepth: Integer;
begin
  Result := False;
  aStart := aRoutine.EndOffset;
  aFinish := 0;
  if not WholeSourceIdentifier(aText, aRoutine.Name, aRoutine.Offset) or
    (aStart <> aRoutine.Offset + Length(aRoutine.Name)) then
    Exit;
  while (aStart <= Length(aText)) and CharInSet(aText[aStart], [#9, #10, #13, ' ']) do
    Inc(aStart);
  if (aStart > Length(aText)) or (aText[aStart] <> '(') then
    Exit;
  lDepth := 0;
  for i := aStart to Length(aText) do
  begin
    if aText[i] = '(' then
      Inc(lDepth)
    else if aText[i] = ')' then
    begin
      Dec(lDepth);
      if lDepth = 0 then
      begin
        aFinish := i;
        Exit(True);
      end;
    end;
  end;
end;

function ParameterMatchesSignature(const aParameter: TDelphiSemanticParameter;
  const aSignature: TDelphiSemanticSignatureParameter): Boolean;
begin
  Result := SameText(aParameter.Name, aSignature.Name) and
    SameText(aParameter.TypeName, aSignature.TypeName) and
    SameText(aParameter.Modifier, aSignature.Modifier);
end;

function ParameterNameEndsAtSeparator(const aCode: string; const aEndOffset: Integer): Boolean;
var
  i: Integer;
begin
  i := aEndOffset;
  while (i <= Length(aCode)) and CharInSet(aCode[i], [#9, #10, #13, ' ']) do
    Inc(i);
  // The type or default expression can repeat a parameter name in the same header.
  Result := (i <= Length(aCode)) and CharInSet(aCode[i], [',', ':']);
end;

function ParameterPositionsKnown(const aModel: TDelphiSemanticUnitModel;
  const aRoutine: TDelphiSemanticRoutine): Boolean;
var
  i, lStart, lFinish, lPreviousEnd: Integer;
  lCode: string;
  lParameter: TDelphiSemanticParameter;
begin
  Result := False;
  if Length(aRoutine.Parameters) <> Length(aRoutine.ProcedureSignature.Parameters) then
    Exit;
  if Length(aRoutine.Parameters) = 0 then
    Exit(True);
  lCode := SanitizeCodeText(aModel.SourceText);
  if not TryParameterHeaderRange(lCode, aRoutine, lStart, lFinish) then
    Exit;
  if NormalizeRoutineSignature(Copy(aModel.SourceText, lStart, lFinish - lStart + 1)) <>
    NormalizeRoutineSignature(aRoutine.Signature) then
    Exit;
  lPreviousEnd := lStart + 1;
  for i := 0 to High(aRoutine.Parameters) do
  begin
    lParameter := aRoutine.Parameters[i];
    if not SameText(lParameter.RoutineName, aRoutine.Name) or
      not ParameterMatchesSignature(lParameter, aRoutine.ProcedureSignature.Parameters[i]) or
      (lParameter.Offset < lPreviousEnd) or (lParameter.EndOffset > lFinish) or
      (lParameter.EndOffset <= lParameter.Offset) then
      Exit;
    if not WholeSourceIdentifier(lCode, lParameter.Name, lParameter.Offset) or
      (lParameter.EndOffset - lParameter.Offset <> Length(lParameter.Name)) then
      Exit;
    if not ParameterNameEndsAtSeparator(lCode, lParameter.EndOffset) or
      not ParameterCoordinatesMatch(aModel.SourceText, lParameter) then
      Exit;
    lPreviousEnd := lParameter.EndOffset;
  end;
  Result := True;
end;

class function TDelphiSemanticSignatureAlignment.InspectParameterChanges(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aFileName: string;
  const aDeclarationOffset: Integer): TDelphiSemanticAlignmentParameterChanges;
var
  i, lCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lExpected: TDelphiSemanticProcedureSignature;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := Default(TDelphiSemanticAlignmentParameterChanges);
  Result.Comparison := Compare(aModels, aTypes, aFileName, aDeclarationOffset);
  Result.Reason := 'alignment.parameter-positions-unavailable';
  if (Result.Comparison.Status <> 'aligned') and (Result.Comparison.Status <> 'name-drift') then
  begin
    Result.Reason := Result.Comparison.Reason;
    Exit;
  end;
  lModel := aModels[FindSelectedModel(aModels, aFileName)];
  lExpected := lModel.Members[Result.Comparison.DeclarationIndex].ProcedureSignature;
  lRoutine := lModel.Routines[Result.Comparison.ImplementationIndex];
  if not ParameterPositionsKnown(lModel, lRoutine) then
    Exit;
  SetLength(Result.Changes, Length(lExpected.Parameters));
  lCount := 0;
  for i := 0 to High(lRoutine.Parameters) do
  begin
    if SameText(lRoutine.Parameters[i].Name, lExpected.Parameters[i].Name) then
      Continue;
    Result.Changes[lCount].ParameterIndex := i;
    Result.Changes[lCount].Original := lRoutine.Parameters[i];
    Result.Changes[lCount].ReplacementName := lExpected.Parameters[i].Name;
    Inc(lCount);
  end;
  SetLength(Result.Changes, lCount);
  Result.Known := True;
  Result.Reason := '';
end;

function AlignmentRequest(const aSnapshot: TDelphiProjectSnapshot): TDelphiSemanticPlanBindingRequest;
var
  lExtension: TObject;
begin
  Result := Default(TDelphiSemanticPlanBindingRequest);
  Result.OperationIdentity := 'signature.align-implementation';
  Result.Status := TSemanticPlanStatus.NoChange;
  Result.RequiredAnalysisKinds := [pakBodyAnalysis, pakReferenceExtraction];
  if Assigned(aSnapshot) and aSnapshot.TryGetExtension(
    cDelphiSemanticContextEvidenceExtensionName, lExtension) and
    (lExtension is TDelphiSemanticContextEvidenceExtension) then
    Result.SelectedConfigurationIdentities := [
      (lExtension as TDelphiSemanticContextEvidenceExtension).ProjectConfigurationIdentity];
end;

function ModelMatchesBoundSource(const aModel: TDelphiSemanticUnitModel;
  const aBinding: TDelphiSemanticBoundPlanResult): Boolean;
var
  i: Integer;
begin
  Result := False;
  if not Assigned(aBinding.Plan) then
    Exit;
  for i := 0 to aBinding.Plan.SourceCount - 1 do
    if SameText(aBinding.Plan.Sources[i].FileName, aModel.FileName) then
      Exit(aBinding.Plan.Sources[i].OriginalText = aModel.SourceText);
end;

function ModelsMatchCapturedEvidence(const aSnapshot: TDelphiProjectSnapshot;
  const aModels: TArray<TDelphiSemanticUnitModel>): Boolean;
var
  lExtension: TObject;
  lEvidence: TDelphiSemanticContextEvidenceExtension;
  lModel: TDelphiSemanticUnitModel;
begin
  Result := False;
  if not aSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName, lExtension) or
    not (lExtension is TDelphiSemanticContextEvidenceExtension) then
    Exit;
  lEvidence := (lExtension as TDelphiSemanticContextEvidenceExtension);
  for lModel in aModels do
    if not lEvidence.MatchesModel(lModel) then
      Exit;
  Result := Length(aModels) > 0;
end;

function FindAlignmentUnit(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string): TUnitSnapshot;
var
  i: Integer;
  lUnit: TUnitSnapshot;
begin
  Result := nil;
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    if SameText(aSnapshot.TextOf(lUnit.FileNameId), aFileName) then
    begin
      if Assigned(Result) then
        Exit(nil);
      Result := lUnit;
    end;
  end;
end;

function AlignmentEdit(const aFileName, aName, aReplacement: string;
  const aLine, aColumn: Integer): TSemanticPlanEdit;
begin
  Result := Default(TSemanticPlanEdit);
  Result.FileName := aFileName;
  Result.StartLine := aLine;
  Result.StartColumn := aColumn;
  Result.EndLine := aLine;
  Result.EndColumn := aColumn + Length(aName);
  Result.ExpectedText := aName;
  Result.ReplacementText := aReplacement;
end;

function FindParameterTarget(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aParameter: TDelphiSemanticParameter;
  const aScope: string): TSemanticSymbolId;
var
  i: Integer;
  lSymbol: TSemanticSymbolFact;
begin
  Result := 0;
  for i := 1 to aUnit.SymbolCount do
  begin
    lSymbol := aUnit.SymbolById(i);
    if (lSymbol.Line <> aParameter.Line) or (lSymbol.Column <> aParameter.Column) then
      Continue;
    if not SameText(aSnapshot.TextOf(lSymbol.NameId), aParameter.Name) or
      not SameText(aSnapshot.TextOf(lSymbol.KindId), 'parameter') or
      (aSnapshot.TextOf(lSymbol.RoutineScopeId) <> aScope) then
      Exit(0);
    if Result <> 0 then
      Exit(0);
    Result := lSymbol.Id;
  end;
end;

function ScopeWithinRoutine(const aModel: TDelphiSemanticUnitModel;
  const aScope, aRoot: string): Boolean;
var
  i, lDepth: Integer;
  lScope, lParent: string;
begin
  lScope := aScope;
  lDepth := Length(aModel.Routines) + 1;
  while lDepth > 0 do
  begin
    Dec(lDepth);
    if lScope = aRoot then
      Exit(True);
    if lScope = '' then
      Exit(False);
    lParent := '';
    for i := 0 to High(aModel.Routines) do
      if aModel.Routines[i].ScopeId = lScope then
      begin
        lParent := aModel.Routines[i].ParentScopeId;
        Break;
      end;
    lScope := lParent;
  end;
  Result := False;
end;

function ReferenceIsQualified(const aCode: string; const aOffset: Integer): Boolean;
var
  i: Integer;
begin
  i := aOffset - 1;
  if i > Length(aCode) then
    Exit(False);
  while (i > 0) and CharInSet(aCode[i], [#9, #10, #13, ' ']) do
    Dec(i);
  Result := (i > 0) and (aCode[i] = '.');
end;

function IsMovingAlignmentName(const aEdits: TArray<TSemanticPlanEdit>;
  const aName: string; const aLine, aColumn: Integer): Boolean;
var
  lEdit: TSemanticPlanEdit;
begin
  for lEdit in aEdits do
    if (lEdit.StartLine = aLine) and (lEdit.StartColumn = aColumn) and
      SameText(lEdit.ExpectedText, aName) and not SameText(lEdit.ReplacementText, aName) then
      Exit(True);
  Result := False;
end;

function ParameterNameWouldCapture(const aModel: TDelphiSemanticUnitModel;
  const aScope, aReplacement: string; const aEdits: TArray<TSemanticPlanEdit>): Boolean;
var
  lLocal: TDelphiSemanticLocal;
  lRoutine: TDelphiSemanticRoutine;
  lParameter: TDelphiSemanticParameter;
  lReference: TDelphiSemanticReference;
  lCode: string;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.Name, aReplacement) and
      ScopeWithinRoutine(aModel, lLocal.RoutineScopeId, aScope) then
      Exit(True);
  for lRoutine in aModel.Routines do
    if ScopeWithinRoutine(aModel, lRoutine.ScopeId, aScope) then
      for lParameter in lRoutine.Parameters do
        if SameText(lParameter.Name, aReplacement) and
          not ((lRoutine.ScopeId = aScope) and
          IsMovingAlignmentName(aEdits, lParameter.Name, lParameter.Line, lParameter.Column)) then
          Exit(True);
  lCode := SanitizeCodeText(aModel.SourceText);
  for lReference in aModel.References do
    if SameText(lReference.Name, aReplacement) and
      ScopeWithinRoutine(aModel, lReference.RoutineScopeId, aScope) and
      not ReferenceIsQualified(lCode, lReference.Offset) and
      not IsMovingAlignmentName(aEdits, lReference.Name, lReference.Line, lReference.Column) then
      Exit(True);
  Result := False;
end;

function AlignmentWouldCapture(const aModel: TDelphiSemanticUnitModel;
  const aChanges: TDelphiSemanticAlignmentParameterChanges;
  const aEdits: TArray<TSemanticPlanEdit>): Boolean;
var
  lChange: TDelphiSemanticAlignmentParameterChange;
  lScope: string;
begin
  lScope := aModel.Routines[aChanges.Comparison.ImplementationIndex].ScopeId;
  for lChange in aChanges.Changes do
    if ParameterNameWouldCapture(aModel, lScope, lChange.ReplacementName, aEdits) then
      Exit(True);
  Result := False;
end;

function AddBoundParameterEdits(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel; const aUnit: TUnitSnapshot;
  const aChange: TDelphiSemanticAlignmentParameterChange; const aScope: string;
  const aEdits: TList<TSemanticPlanEdit>): Boolean;
var
  i: Integer;
  lTarget: TSemanticSymbolId;
  lReference: TSemanticReferenceFact;
  lName: string;
begin
  Result := False;
  lTarget := FindParameterTarget(aSnapshot, aUnit, aChange.Original, aScope);
  if lTarget = 0 then
    Exit;
  aEdits.Add(AlignmentEdit(aModel.FileName, aChange.Original.Name, aChange.ReplacementName,
    aChange.Original.Line, aChange.Original.Column));
  for i := 1 to aUnit.ReferenceCount do
  begin
    lReference := aUnit.ReferenceById(i);
    lName := aSnapshot.TextOf(lReference.NameId);
    if (lReference.TargetUnitId = aUnit.UnitId) and (lReference.TargetSymbolId = lTarget) then
    begin
      if not SameText(lName, aChange.Original.Name) or
        (lReference.EndLine <> lReference.Line) or
        (lReference.EndColumn <> lReference.Column + Length(lName) - 1) then
        Exit;
      aEdits.Add(AlignmentEdit(aModel.FileName, lName, aChange.ReplacementName,
        lReference.Line, lReference.Column));
    end else if SameText(lName, aChange.Original.Name) and
      ScopeWithinRoutine(aModel, aSnapshot.TextOf(lReference.RoutineScopeId), aScope) and
      ((lReference.TargetUnitId = 0) or (lReference.TargetSymbolId = 0)) then
      Exit;
  end;
  Result := True;
end;

function RoutineEndOffset(const aText: string; const aRoutine: TDelphiSemanticRoutine): Integer;
var
  i, lLine, lColumn: Integer;
begin
  lLine := 1;
  lColumn := 1;
  for i := 1 to Length(aText) do
  begin
    if (lLine = aRoutine.EndLine) and (lColumn = aRoutine.EndColumn) then
      Exit(i);
    if aText[i] = #10 then
    begin
      Inc(lLine);
      lColumn := 1;
    end else if aText[i] <> #13 then
      Inc(lColumn);
  end;
  Result := 0;
end;

function HasModelTokenFact(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aOffset: Integer): Boolean;
var
  lReference: TDelphiSemanticReference;
  lRoutine: TDelphiSemanticRoutine;
  lParameter: TDelphiSemanticParameter;
  lLocal: TDelphiSemanticLocal;
begin
  for lReference in aModel.References do
    if (lReference.Offset = aOffset) and
      (lReference.EndOffset = aOffset + Length(aName)) and SameText(lReference.Name, aName) then
      Exit(True);
  for lRoutine in aModel.Routines do
    for lParameter in lRoutine.Parameters do
      if (lParameter.Offset = aOffset) and
        (lParameter.EndOffset = aOffset + Length(aName)) and SameText(lParameter.Name, aName) then
        Exit(True);
  for lLocal in aModel.Locals do
    if (lLocal.Offset = aOffset) and
      (lLocal.EndOffset = aOffset + Length(aName)) and SameText(lLocal.Name, aName) then
      Exit(True);
  Result := False;
end;

function ParameterTokensCovered(const aModel: TDelphiSemanticUnitModel;
  const aCode: string; const aChange: TDelphiSemanticAlignmentParameterChange;
  const aStart, aFinish: Integer): Boolean;
var
  i, lStart: Integer;
  lName: string;
begin
  i := aStart;
  while i < aFinish do
  begin
    if not (IsIdentifierChar(aCode[i]) or (Ord(aCode[i]) > 127)) then
    begin
      Inc(i);
      Continue;
    end;
    lStart := i;
    while (i < aFinish) and (IsIdentifierChar(aCode[i]) or (Ord(aCode[i]) > 127)) do
      Inc(i);
    lName := Copy(aCode, lStart, i - lStart);
    if (SameText(lName, aChange.Original.Name) or SameText(lName, aChange.ReplacementName)) and
      not HasModelTokenFact(aModel, lName, lStart) then
      Exit(False);
  end;
  Result := True;
end;

function AlignmentTokensCovered(const aModel: TDelphiSemanticUnitModel;
  const aChanges: TDelphiSemanticAlignmentParameterChanges): Boolean;
var
  lCode: string;
  lRoutine: TDelphiSemanticRoutine;
  lChange: TDelphiSemanticAlignmentParameterChange;
  lFinish: Integer;
begin
  lRoutine := aModel.Routines[aChanges.Comparison.ImplementationIndex];
  lCode := SanitizeCodeText(aModel.SourceText);
  lFinish := RoutineEndOffset(lCode, lRoutine);
  if (lRoutine.Offset < 1) or (lFinish <= lRoutine.EndOffset) then
    Exit(False);
  for lChange in aChanges.Changes do
    if not ParameterTokensCovered(aModel, lCode, lChange, lRoutine.Offset, lFinish) then
      Exit(False);
  Result := True;
end;
function CollectAlignmentEdits(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel; const aChanges: TDelphiSemanticAlignmentParameterChanges;
  out aEdits: TArray<TSemanticPlanEdit>): Boolean;
var
  lUnit: TUnitSnapshot;
  lScope: string;
  lChange: TDelphiSemanticAlignmentParameterChange;
  lEdits: TList<TSemanticPlanEdit>;
begin
  Result := False;
  aEdits := nil;
  if not AlignmentTokensCovered(aModel, aChanges) then
    Exit;
  lUnit := FindAlignmentUnit(aSnapshot, aModel.FileName);
  lScope := aModel.Routines[aChanges.Comparison.ImplementationIndex].ScopeId;
  if not Assigned(lUnit) or (lScope = '') or
    (aSnapshot.ExactTextOf(lUnit.SourceTextId) <> aModel.SourceText) then
    Exit;
  lEdits := TList<TSemanticPlanEdit>.Create;
  try
    for lChange in aChanges.Changes do
      if not AddBoundParameterEdits(aSnapshot, aModel, lUnit, lChange, lScope, lEdits) then
        Exit;
    aEdits := lEdits.ToArray;
    Result := True;
  finally
    lEdits.Free;
  end;
end;

class function TDelphiSemanticSignatureAlignment.PlanAlignment(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aTypes: TDelphiSemanticTypeIdentityIndex; const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aDeclarationOffset: Integer): TDelphiSemanticBoundPlanResult;
var
  i: Integer;
  lRequest: TDelphiSemanticPlanBindingRequest;
  lChanges: TDelphiSemanticAlignmentParameterChanges;
  lEdits: TArray<TSemanticPlanEdit>;
  lReferencesProven: Boolean;
begin
  lRequest := AlignmentRequest(aSnapshot);
  Result := TDelphiSemanticPlanBinder.Bind(aSnapshot, lRequest);
  if Result.Status <> TSemanticPlanStatus.NoChange then
    Exit;
  try
    lRequest.Status := TSemanticPlanStatus.Incomplete;
    lRequest.Reason := 'alignment.model-source-mismatch';
    for i := 0 to High(aModels) do
      if not ModelMatchesBoundSource(aModels[i], Result) then
        Exit;
    lRequest.Reason := 'alignment.model-evidence-mismatch';
    if not ModelsMatchCapturedEvidence(aSnapshot, aModels) then
      Exit;
    lChanges := InspectParameterChanges(aModels, aTypes, aFileName, aDeclarationOffset);
    lRequest.Reason := lChanges.Reason;
    if not lChanges.Known then
      Exit;
    // Only a complete snapshot-bound edit set may exempt a simultaneous rename from capture.
    lReferencesProven := CollectAlignmentEdits(aSnapshot,
      aModels[FindSelectedModel(aModels, aFileName)], lChanges, lEdits);
    lRequest.Reason := 'alignment.name-capture';
    if AlignmentWouldCapture(aModels[FindSelectedModel(aModels, aFileName)], lChanges, lEdits) then
      Exit;
    lRequest.Reason := 'alignment.reference-proof-unavailable';
    if not lReferencesProven then
      Exit;
    lRequest.Edits := lEdits;
    lRequest.Status := TSemanticPlanStatus.NoChange;
    if Length(lRequest.Edits) > 0 then
      lRequest.Status := TSemanticPlanStatus.Complete;
    lRequest.Reason := '';
  finally
    Result.Free;
    Result := TDelphiSemanticPlanBinder.Bind(aSnapshot, lRequest);
  end;
end;

end.