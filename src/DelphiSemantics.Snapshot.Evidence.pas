unit DelphiSemantics.Snapshot.Evidence;

interface

uses
  System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Snapshot;

type
  // Build scratch keyed by original model slots, never names or source positions.
  TSnapshotSymbolProjection = record
    Declarations: TArray<TSemanticSymbolId>;
    Members: TArray<TSemanticSymbolId>;
    Routines: TArray<TSemanticSymbolId>;
    Parameters: TArray<TArray<TSemanticSymbolId>>;
    Locals: TArray<TSemanticSymbolId>;
    function SymbolId(const aOccurrence: TDelphiSemanticPhysicalSymbolOccurrence): TSemanticSymbolId;
  end;

  TSnapshotEvidenceStrings = record
    Snapshot: TDelphiProjectSnapshot;
    Semantic: TSemanticStringPool;
    Exact: TSemanticStringPool;
    class function FromPools(const aSemantic, aExact: TSemanticStringPool): TSnapshotEvidenceStrings; static;
    class function FromSnapshot(const aSnapshot: TDelphiProjectSnapshot): TSnapshotEvidenceStrings; static;
    function TextOf(const id: TSemanticStringId; const aExact: Boolean): string;
    function Count(const aExact: Boolean): Cardinal;
  end;

procedure ProjectPhysicalEvidence(const aModel: TDelphiSemanticUnitModel;
  const aProjection: TSnapshotSymbolProjection; const aStrings, aExactStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot);
procedure RemapPhysicalEvidence(const aSource: TSnapshotEvidenceStrings;
  const aStrings, aExactStrings: TSemanticStringPool; const aSourceUnit, aTargetUnit: TUnitSnapshot);
function IsAbsoluteEvidenceFile(const aFile: string): Boolean;
function IsWellFormedEvidenceText(const aText: string): Boolean;

function PackPhysicalOccurrences(const aUnit: TUnitSnapshot; const aCollection: Integer): TBytes;
procedure UnpackPhysicalOccurrences(const aPayload: TBytes; const aCount: Int64;
  const aCollection: Integer; const aAvailable: Boolean; const aUnit: TUnitSnapshot);
procedure ValidatePhysicalEvidence(const aStrings, aExactStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot);

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.IOUtils,
  AutoFree, MaxLogic.StrUtils,
  DelphiSemantics.Cache, DelphiSemantics.Model.Coordinates, DelphiSemantics.Snapshot.OccurrenceCodec, DelphiSemantics.Source;

type
  TSourceCaptureGroup = class
    FileName: string;
    Required: Boolean;
    Count: Integer;
    Malformed: Boolean;
    Conflict: Boolean;
    First: TDelphiSemanticSourceText;
  end;

  TEvidenceRemapper = record
    Source: TSnapshotEvidenceStrings;
    Strings: TSemanticStringPool;
    ExactStrings: TSemanticStringPool;
    SemanticMap: TArray<TSemanticStringId>;
    ExactMap: TArray<TSemanticStringId>;
    function SemanticId(const id: TSemanticStringId): TSemanticStringId;
    function ExactId(const id: TSemanticStringId): TSemanticStringId;
  end;

function IsAbsoluteEvidenceFile(const aFile: string): Boolean;
begin
  Result := (Pos(#0, aFile) = 0) and
    (((Length(aFile) >= 3) and (aFile[2] = ':') and CharInSet(aFile[3], ['\', '/'])) or
      ((Length(aFile) > 2) and (Copy(aFile, 1, 2) = '\\')));
end;

function IsWellFormedEvidenceText(const aText: string): Boolean;
var
  i: Integer;
begin
  i := 1;
  while i <= Length(aText) do
  begin
    if (Ord(aText[i]) >= $D800) and (Ord(aText[i]) <= $DBFF) then
    begin
      Inc(i);
      if (i > Length(aText)) or (Ord(aText[i]) < $DC00) or (Ord(aText[i]) > $DFFF) then
        Exit(False);
    end else if (Ord(aText[i]) >= $DC00) and (Ord(aText[i]) <= $DFFF) then
      Exit(False);
    Inc(i);
  end;
  Result := True;
end;

function TSnapshotSymbolProjection.SymbolId(
  const aOccurrence: TDelphiSemanticPhysicalSymbolOccurrence): TSemanticSymbolId;
var
  i, j: Integer;
begin
  Result := 0;
  i := aOccurrence.FactIndex;
  j := aOccurrence.ParentFactIndex;
  if i < 0 then
    Exit;
  if aOccurrence.FactKind = 'parameter' then
  begin
    if (j >= 0) and (j < Length(Parameters)) and (i < Length(Parameters[j])) then
      Result := Parameters[j][i];
    Exit;
  end;
  if j <> -1 then
    Exit;
  if (aOccurrence.FactKind = 'declaration') and (i < Length(Declarations)) then
    Result := Declarations[i]
  else if (aOccurrence.FactKind = 'member') and (i < Length(Members)) then
    Result := Members[i]
  else if (aOccurrence.FactKind = 'routine') and (i < Length(Routines)) then
    Result := Routines[i]
  else if (aOccurrence.FactKind = 'local') and (i < Length(Locals)) then
    Result := Locals[i];
end;

class function TSnapshotEvidenceStrings.FromPools(const aSemantic,
  aExact: TSemanticStringPool): TSnapshotEvidenceStrings;
begin
  Result := Default(TSnapshotEvidenceStrings);
  Result.Semantic := aSemantic;
  Result.Exact := aExact;
end;

class function TSnapshotEvidenceStrings.FromSnapshot(
  const aSnapshot: TDelphiProjectSnapshot): TSnapshotEvidenceStrings;
begin
  Result := Default(TSnapshotEvidenceStrings);
  Result.Snapshot := aSnapshot;
end;

function TSnapshotEvidenceStrings.TextOf(const id: TSemanticStringId; const aExact: Boolean): string;
begin
  if Snapshot <> nil then
  begin
    if aExact then
      Exit(Snapshot.ExactTextOf(id));
    Exit(Snapshot.TextOf(id));
  end;
  if aExact then
    Exit(Exact.TextOf(id));
  Result := Semantic.TextOf(id);
end;

function TSnapshotEvidenceStrings.Count(const aExact: Boolean): Cardinal;
begin
  if Snapshot <> nil then
  begin
    if aExact then
      Exit(Snapshot.ExactStringCount);
    Exit(Snapshot.StringCount);
  end;
  if aExact then
    Exit(Exact.Count);
  Result := Semantic.Count;
end;

function TEvidenceRemapper.SemanticId(const id: TSemanticStringId): TSemanticStringId;
begin
  if id = 0 then
    Exit(0);
  if id >= Cardinal(Length(SemanticMap)) then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_SEMANTIC_ID_INVALID');
  if SemanticMap[id] = 0 then
    SemanticMap[id] := Strings.Intern(Source.TextOf(id, False));
  Result := SemanticMap[id];
end;

function TEvidenceRemapper.ExactId(const id: TSemanticStringId): TSemanticStringId;
begin
  if id = 0 then
    Exit(0);
  if id >= Cardinal(Length(ExactMap)) then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_EXACT_ID_INVALID');
  if ExactMap[id] = 0 then
    ExactMap[id] := ExactStrings.Intern(Source.TextOf(id, True));
  Result := ExactMap[id];
end;

procedure AddCaptureFile(const aGroups: TObjectDictionary<string, TSourceCaptureGroup>;
  const aFile: string; const aRequired: Boolean; var aAvailable: Boolean);
var
  lFile: string;
  lGroup: TSourceCaptureGroup;
begin
  if not IsAbsoluteEvidenceFile(aFile) then
  begin
    aAvailable := False;
    Exit;
  end;
  lFile := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aFile);
  if not aGroups.TryGetValue(lFile, lGroup) then
  begin
    lGroup := TSourceCaptureGroup.Create;
    lGroup.FileName := TPath.GetFullPath(aFile);
    aGroups.Add(lFile, lGroup);
  end;
  lGroup.Required := lGroup.Required or aRequired;
end;

procedure ProjectCapturedSources(const aModel: TDelphiSemanticUnitModel;
  const aStrings, aExactStrings: TSemanticStringPool; const aUnit: TUnitSnapshot);
var
  g: TGarbos;
  i: Integer;
  lAvailable, lHasIncludes: Boolean;
  lFile: string;
  lFiles: TArray<string>;
  lGroup: TSourceCaptureGroup;
  lGroups: TObjectDictionary<string, TSourceCaptureGroup>;
  lReference: TDelphiSemanticPhysicalReferenceOccurrence;
  lRows: TArray<TSemanticCapturedSourceFact>;
  lSource: TDelphiSemanticSourceText;
  lSymbol: TDelphiSemanticPhysicalSymbolOccurrence;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  GC(lGroups, TObjectDictionary<string, TSourceCaptureGroup>.Create([doOwnsValues],
    TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  lAvailable := aModel.SourceObservations <> nil;
  AddCaptureFile(lGroups, aModel.FileName, True, lAvailable);
  lHasIncludes := (Length(aModel.IncludeFileNames) > 0) or (Length(aModel.SkippedIncludeFileNames) > 0);
  for lDiagnostic in aModel.Diagnostics do
    if Pos('INCLUDE_', UpperCase(lDiagnostic.Code)) = 1 then
      lHasIncludes := True;
  for lFile in aModel.IncludeFileNames do
    AddCaptureFile(lGroups, lFile, True, lAvailable);
  for lFile in aModel.SkippedIncludeFileNames do
    AddCaptureFile(lGroups, lFile, False, lAvailable);
  for lReference in aModel.PhysicalReferenceOccurrences do
    if lReference.FileName <> '' then
      AddCaptureFile(lGroups, lReference.FileName, True, lAvailable);
  for lSymbol in aModel.PhysicalSymbolOccurrences do
    if lSymbol.FileName <> '' then
      AddCaptureFile(lGroups, lSymbol.FileName, True, lAvailable);
  if aModel.SourceObservations <> nil then
    for i := 0 to aModel.SourceObservations.Count - 1 do
    begin
      lSource := aModel.SourceObservations.Items[i];
      if not IsAbsoluteEvidenceFile(lSource.FileName) then
      begin
        lAvailable := False;
        Continue;
      end;
      lFile := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lSource.FileName);
      // An otherwise unknown observation has a consumer. Only an explicitly
      // skipped-only candidate remains textless.
      if not lGroups.ContainsKey(lFile) then
        AddCaptureFile(lGroups, lSource.FileName, True, lAvailable);
      lGroup := lGroups[lFile];
      Inc(lGroup.Count);
      lGroup.Malformed := lGroup.Malformed or not IsWellFormedEvidenceText(lSource.Text);
      if lGroup.Count = 1 then
        lGroup.First := lSource
      else if (lGroup.First.Text <> lSource.Text) or (lGroup.First.ContentHash <> lSource.ContentHash) then
        lGroup.Conflict := True;
    end;
  lFiles := lGroups.Keys.ToArray;
  TArray.Sort<string>(lFiles, TStringComparer.Ordinal);
  SetLength(lRows, Length(lFiles));
  for i := 0 to High(lFiles) do
  begin
    lGroup := lGroups[lFiles[i]];
    lRows[i].FileId := aStrings.Intern(lGroup.FileName);
    if lRows[i].FileId <> aUnit.FileNameId then
      lHasIncludes := True;
    if lGroup.Conflict then
      lRows[i].Status := cCapturedSourceConflict
    else if lGroup.Malformed then
      lRows[i].Status := cCapturedSourceMalformed
    else if lGroup.Count > 1 then
      lRows[i].Status := cCapturedSourceDuplicate
    else if (lGroup.Count = 0) or not lGroup.Required then
      lRows[i].Status := cCapturedSourceUnavailable
    else if lGroup.First.Text = '' then
      lRows[i].Status := cCapturedSourceEmpty
    else begin
      lRows[i].Status := cCapturedSourceText;
      lRows[i].TextId := aExactStrings.Intern(lGroup.First.Text);
    end;
  end;
  aUnit.SetCapturedSources(lRows, lAvailable);
  aUnit.SetHasIncludes(lHasIncludes);
end;

procedure ProjectVisibleUnits(const aModel: TDelphiSemanticUnitModel;
  const aStrings: TSemanticStringPool; const aUnit: TUnitSnapshot);
var
  g: TGarbos;
  lIds: TList<TSemanticStringId>;
  lNames: THashSet<string>;
  lName: string;
  lImports: TArray<string>;
begin
  GC(lIds, TList<TSemanticStringId>.Create, g);
  GC(lNames, THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase), g);
  for lImports in [aModel.InterfaceUses, aModel.ImplementationUses] do
    for lName in lImports do
      if (lName <> '') and lNames.Add(lName) then
        lIds.Add(aStrings.Intern(lName));
  aUnit.SetVisibleUnitNameIds(lIds.ToArray, aModel.Success);
end;

procedure ProjectPhysicalEvidence(const aModel: TDelphiSemanticUnitModel;
  const aProjection: TSnapshotSymbolProjection; const aStrings, aExactStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot);
var
  g: TGarbos;
  i, lPrevious: Integer;
  lAvailable: Boolean;
  lExpected: Int64;
  lKey: string;
  lRawReference: TDelphiSemanticPhysicalReferenceOccurrence;
  lRawSymbol: TDelphiSemanticPhysicalSymbolOccurrence;
  lReferences: TArray<TSemanticPhysicalReferenceOccurrence>;
  lSymbols: TArray<TSemanticPhysicalSymbolOccurrence>;
  lRoutine: TDelphiSemanticRoutine;
  lSeen: TDictionary<string, Integer>;
begin
  SetLength(lReferences, Length(aModel.PhysicalReferenceOccurrences));
  for i := 0 to High(lReferences) do
  begin
    lRawReference := aModel.PhysicalReferenceOccurrences[i];
    lReferences[i].NameId := aStrings.Intern(lRawReference.Name);
    lReferences[i].RoleId := aStrings.Intern(lRawReference.Role);
    lReferences[i].RoutineNameId := aStrings.Intern(lRawReference.RoutineName);
    lReferences[i].RoutineScopeId := aStrings.Intern(lRawReference.RoutineScopeId);
    if lRawReference.FileName <> '' then
      lReferences[i].FileId := aStrings.Intern(TPath.GetFullPath(lRawReference.FileName));
    lReferences[i].ExpansionId := aExactStrings.Intern(lRawReference.ExpansionId);
    lReferences[i].OutputStartOffset := lRawReference.OutputStartOffset;
    lReferences[i].OutputEndOffset := lRawReference.OutputEndOffset;
    lReferences[i].Line := lRawReference.Line;
    lReferences[i].Column := lRawReference.Column;
    lReferences[i].EndLine := lRawReference.EndLine;
    lReferences[i].EndColumn := lRawReference.EndColumn;
    lReferences[i].Verified := lRawReference.Verified;
  end;
  aUnit.SetPhysicalReferenceOccurrences(lReferences, aModel.PhysicalReferenceOccurrencesAvailable);
  SetLength(lSymbols, Length(aModel.PhysicalSymbolOccurrences));
  GC(lSeen, TDictionary<string, Integer>.Create(TFastCaseAwareComparer.Ordinal), g);
  lAvailable := aModel.PhysicalSymbolOccurrencesAvailable;
  for i := 0 to High(lSymbols) do
  begin
    lRawSymbol := aModel.PhysicalSymbolOccurrences[i];
    lSymbols[i].FactKindId := aStrings.Intern(lRawSymbol.FactKind);
    lSymbols[i].NameId := aStrings.Intern(lRawSymbol.Name);
    lSymbols[i].KindId := aStrings.Intern(lRawSymbol.Kind);
    lSymbols[i].OwnerNameId := aStrings.Intern(lRawSymbol.OwnerName);
    lSymbols[i].OwnerScopeId := aStrings.Intern(lRawSymbol.OwnerScopeId);
    lSymbols[i].SemanticSymbolId := aStrings.Intern(lRawSymbol.SymbolId);
    lSymbols[i].OwnerSymbolId := aStrings.Intern(lRawSymbol.OwnerSymbolId);
    lSymbols[i].RoutineNameId := aStrings.Intern(lRawSymbol.RoutineName);
    lSymbols[i].RoutineScopeId := aStrings.Intern(lRawSymbol.RoutineScopeId);
    lSymbols[i].SectionKindId := aStrings.Intern(lRawSymbol.SectionKind);
    if lRawSymbol.FileName <> '' then
      lSymbols[i].FileId := aStrings.Intern(TPath.GetFullPath(lRawSymbol.FileName));
    lSymbols[i].ExpansionId := aExactStrings.Intern(lRawSymbol.ExpansionId);
    lSymbols[i].OutputStartOffset := lRawSymbol.OutputStartOffset;
    lSymbols[i].OutputEndOffset := lRawSymbol.OutputEndOffset;
    lSymbols[i].Line := lRawSymbol.Line;
    lSymbols[i].Column := lRawSymbol.Column;
    lSymbols[i].EndLine := lRawSymbol.EndLine;
    lSymbols[i].EndColumn := lRawSymbol.EndColumn;
    lSymbols[i].Verified := lRawSymbol.Verified;
    lSymbols[i].FactIndex := lRawSymbol.FactIndex;
    lSymbols[i].ParentFactIndex := lRawSymbol.ParentFactIndex;
    lKey := lRawSymbol.FactKind + '|' + IntToStr(lRawSymbol.ParentFactIndex) + '|' + IntToStr(lRawSymbol.FactIndex);
    if not PhysicalSymbolFactMatches(lRawSymbol, aModel) then
      lSymbols[i].ProjectionStatus := cPhysicalProjectionMalformed
    else if lSeen.TryGetValue(lKey, lPrevious) then
    begin
      lSymbols[i].ProjectionStatus := cPhysicalProjectionMalformed;
      lSymbols[lPrevious].ProjectionStatus := cPhysicalProjectionMalformed;
      lSymbols[lPrevious].SnapshotSymbolId := 0;
    end else begin
      lSeen.Add(lKey, i);
      lSymbols[i].SnapshotSymbolId := aProjection.SymbolId(lRawSymbol);
      if lSymbols[i].SnapshotSymbolId <> 0 then
        lSymbols[i].ProjectionStatus := cPhysicalProjectionLinked;
    end;
    if lSymbols[i].ProjectionStatus = cPhysicalProjectionMalformed then
    begin
      lSymbols[i].SnapshotSymbolId := 0;
      lAvailable := False;
    end;
  end;
  lExpected := Int64(Length(aModel.Declarations)) + Length(aModel.Members) +
    Length(aModel.TypeValueMembers) + Length(aModel.Routines) + Length(aModel.Locals);
  for lRoutine in aModel.Routines do
    Inc(lExpected, Length(lRoutine.Parameters));
  aUnit.SetPhysicalSymbolOccurrences(lSymbols, lAvailable and (lSeen.Count = lExpected));
  ProjectCapturedSources(aModel, aStrings, aExactStrings, aUnit);
  ProjectVisibleUnits(aModel, aStrings, aUnit);
end;

procedure RemapPhysicalEvidence(const aSource: TSnapshotEvidenceStrings;
  const aStrings, aExactStrings: TSemanticStringPool; const aSourceUnit, aTargetUnit: TUnitSnapshot);
var
  i: Integer;
  lMap: TEvidenceRemapper;
  lReference: TSemanticPhysicalReferenceOccurrence;
  lReferences: TArray<TSemanticPhysicalReferenceOccurrence>;
  lSymbol: TSemanticPhysicalSymbolOccurrence;
  lSymbols: TArray<TSemanticPhysicalSymbolOccurrence>;
  lSourceFact: TSemanticCapturedSourceFact;
  lSources: TArray<TSemanticCapturedSourceFact>;
  lImports: TArray<TSemanticStringId>;
begin
  lMap.Source := aSource;
  lMap.Strings := aStrings;
  lMap.ExactStrings := aExactStrings;
  SetLength(lMap.SemanticMap, NativeInt(aSource.Count(False)) + 1);
  SetLength(lMap.ExactMap, NativeInt(aSource.Count(True)) + 1);
  SetLength(lReferences, aSourceUnit.PhysicalReferenceOccurrenceCount);
  for i := 0 to High(lReferences) do
  begin
    lReference := aSourceUnit.PhysicalReferenceOccurrenceByIndex(i);
    lReference.NameId := lMap.SemanticId(lReference.NameId);
    lReference.RoleId := lMap.SemanticId(lReference.RoleId);
    lReference.RoutineNameId := lMap.SemanticId(lReference.RoutineNameId);
    lReference.RoutineScopeId := lMap.SemanticId(lReference.RoutineScopeId);
    lReference.FileId := lMap.SemanticId(lReference.FileId);
    lReference.ExpansionId := lMap.ExactId(lReference.ExpansionId);
    lReferences[i] := lReference;
  end;
  aTargetUnit.SetPhysicalReferenceOccurrences(lReferences, aSourceUnit.PhysicalReferenceOccurrencesAvailable);
  SetLength(lSymbols, aSourceUnit.PhysicalSymbolOccurrenceCount);
  for i := 0 to High(lSymbols) do
  begin
    lSymbol := aSourceUnit.PhysicalSymbolOccurrenceByIndex(i);
    lSymbol.FactKindId := lMap.SemanticId(lSymbol.FactKindId);
    lSymbol.NameId := lMap.SemanticId(lSymbol.NameId);
    lSymbol.KindId := lMap.SemanticId(lSymbol.KindId);
    lSymbol.OwnerNameId := lMap.SemanticId(lSymbol.OwnerNameId);
    lSymbol.OwnerScopeId := lMap.SemanticId(lSymbol.OwnerScopeId);
    lSymbol.SemanticSymbolId := lMap.SemanticId(lSymbol.SemanticSymbolId);
    lSymbol.OwnerSymbolId := lMap.SemanticId(lSymbol.OwnerSymbolId);
    lSymbol.RoutineNameId := lMap.SemanticId(lSymbol.RoutineNameId);
    lSymbol.RoutineScopeId := lMap.SemanticId(lSymbol.RoutineScopeId);
    lSymbol.SectionKindId := lMap.SemanticId(lSymbol.SectionKindId);
    lSymbol.FileId := lMap.SemanticId(lSymbol.FileId);
    lSymbol.ExpansionId := lMap.ExactId(lSymbol.ExpansionId);
    lSymbols[i] := lSymbol;
  end;
  aTargetUnit.SetPhysicalSymbolOccurrences(lSymbols, aSourceUnit.PhysicalSymbolOccurrencesAvailable);
  SetLength(lSources, aSourceUnit.CapturedSourceCount);
  for i := 0 to High(lSources) do
  begin
    lSourceFact := aSourceUnit.CapturedSourceByIndex(i);
    lSourceFact.FileId := lMap.SemanticId(lSourceFact.FileId);
    lSourceFact.TextId := lMap.ExactId(lSourceFact.TextId);
    lSources[i] := lSourceFact;
  end;
  aTargetUnit.SetCapturedSources(lSources, aSourceUnit.CapturedSourcesAvailable);
  SetLength(lImports, aSourceUnit.VisibleUnitNameCount);
  for i := 0 to High(lImports) do
    lImports[i] := lMap.SemanticId(aSourceUnit.VisibleUnitNameByIndex(i));
  aTargetUnit.SetVisibleUnitNameIds(lImports, aSourceUnit.VisibleUnitNamesAvailable);
  aTargetUnit.SetHasIncludes(aSourceUnit.HasIncludes);
end;

function EvidenceInteger(const aValue: Int64; const aMinimum, aMaximum: Int64): Int64;
begin
  if (aValue < aMinimum) or (aValue > aMaximum) then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_INTEGER_INVALID');
  Result := aValue;
end;

function PackPhysicalOccurrences(const aUnit: TUnitSnapshot; const aCollection: Integer): TBytes;
var
  i, p: Integer;
  lValues: TArray<Int64>;
  lReference: TSemanticPhysicalReferenceOccurrence;
  lSymbol: TSemanticPhysicalSymbolOccurrence;
begin
  if aCollection = 0 then
  begin
    SetLength(lValues, NativeInt(aUnit.PhysicalReferenceOccurrenceCount) * cPhysicalReferenceColumnCount);
    for i := 0 to aUnit.PhysicalReferenceOccurrenceCount - 1 do
    begin
      lReference := aUnit.PhysicalReferenceOccurrenceByIndex(i);
      p := i * cPhysicalReferenceColumnCount;
      lValues[p + 0] := lReference.NameId;
      lValues[p + 1] := lReference.RoleId;
      lValues[p + 2] := lReference.RoutineNameId;
      lValues[p + 3] := lReference.RoutineScopeId;
      lValues[p + 4] := lReference.FileId;
      lValues[p + 5] := lReference.ExpansionId;
      lValues[p + 6] := lReference.OutputStartOffset;
      lValues[p + 7] := lReference.OutputEndOffset;
      lValues[p + 8] := lReference.Line;
      lValues[p + 9] := lReference.Column;
      lValues[p + 10] := lReference.EndLine;
      lValues[p + 11] := lReference.EndColumn;
      lValues[p + 12] := Ord(lReference.Verified);
    end;
    Exit(EncodeOccurrenceValues(lValues, cPhysicalReferenceColumnCount));
  end;
  if aCollection <> 1 then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_COLLECTION_INVALID');
  SetLength(lValues, NativeInt(aUnit.PhysicalSymbolOccurrenceCount) * cPhysicalSymbolColumnCount);
  for i := 0 to aUnit.PhysicalSymbolOccurrenceCount - 1 do
  begin
    lSymbol := aUnit.PhysicalSymbolOccurrenceByIndex(i);
    p := i * cPhysicalSymbolColumnCount;
    lValues[p + 0] := lSymbol.FactKindId;
    lValues[p + 1] := lSymbol.NameId;
    lValues[p + 2] := lSymbol.KindId;
    lValues[p + 3] := lSymbol.OwnerNameId;
    lValues[p + 4] := lSymbol.OwnerScopeId;
    lValues[p + 5] := lSymbol.SemanticSymbolId;
    lValues[p + 6] := lSymbol.OwnerSymbolId;
    lValues[p + 7] := lSymbol.RoutineNameId;
    lValues[p + 8] := lSymbol.RoutineScopeId;
    lValues[p + 9] := lSymbol.SectionKindId;
    lValues[p + 10] := lSymbol.FileId;
    lValues[p + 11] := lSymbol.ExpansionId;
    lValues[p + 12] := lSymbol.FactIndex;
    lValues[p + 13] := lSymbol.ParentFactIndex;
    lValues[p + 14] := lSymbol.SnapshotSymbolId;
    lValues[p + 15] := lSymbol.ProjectionStatus;
    lValues[p + 16] := lSymbol.OutputStartOffset;
    lValues[p + 17] := lSymbol.OutputEndOffset;
    lValues[p + 18] := lSymbol.Line;
    lValues[p + 19] := lSymbol.Column;
    lValues[p + 20] := lSymbol.EndLine;
    lValues[p + 21] := lSymbol.EndColumn;
    lValues[p + 22] := Ord(lSymbol.Verified);
  end;
  Result := EncodeOccurrenceValues(lValues, cPhysicalSymbolColumnCount);
end;

procedure UnpackPhysicalOccurrences(const aPayload: TBytes; const aCount: Int64;
  const aCollection: Integer; const aAvailable: Boolean; const aUnit: TUnitSnapshot);
var
  i, p: Integer;
  lValues: TArray<Int64>;
  lReferences: TArray<TSemanticPhysicalReferenceOccurrence>;
  lSymbols: TArray<TSemanticPhysicalSymbolOccurrence>;
begin
  if aCollection = 0 then
  begin
    lValues := DecodeOccurrenceValues(aPayload, aCount, cPhysicalReferenceColumnCount);
    if aCount > High(NativeInt) div SizeOf(TSemanticPhysicalReferenceOccurrence) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_ARRAY_UNADDRESSABLE');
    SetLength(lReferences, Integer(aCount));
    for i := 0 to High(lReferences) do
    begin
      p := i * cPhysicalReferenceColumnCount;
      lReferences[i].NameId := EvidenceInteger(lValues[p + 0], 0, High(Cardinal));
      lReferences[i].RoleId := EvidenceInteger(lValues[p + 1], 0, High(Cardinal));
      lReferences[i].RoutineNameId := EvidenceInteger(lValues[p + 2], 0, High(Cardinal));
      lReferences[i].RoutineScopeId := EvidenceInteger(lValues[p + 3], 0, High(Cardinal));
      lReferences[i].FileId := EvidenceInteger(lValues[p + 4], 0, High(Cardinal));
      lReferences[i].ExpansionId := EvidenceInteger(lValues[p + 5], 0, High(Cardinal));
      lReferences[i].OutputStartOffset := EvidenceInteger(lValues[p + 6], 0, MaxInt);
      lReferences[i].OutputEndOffset := EvidenceInteger(lValues[p + 7], 0, MaxInt);
      lReferences[i].Line := EvidenceInteger(lValues[p + 8], 0, MaxInt);
      lReferences[i].Column := EvidenceInteger(lValues[p + 9], 0, MaxInt);
      lReferences[i].EndLine := EvidenceInteger(lValues[p + 10], 0, MaxInt);
      lReferences[i].EndColumn := EvidenceInteger(lValues[p + 11], 0, MaxInt);
      lReferences[i].Verified := (EvidenceInteger(lValues[p + 12], 0, 1) = 1);
    end;
    aUnit.SetPhysicalReferenceOccurrences(lReferences, aAvailable);
    Exit;
  end;
  if aCollection <> 1 then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_COLLECTION_INVALID');
  lValues := DecodeOccurrenceValues(aPayload, aCount, cPhysicalSymbolColumnCount);
  if aCount > High(NativeInt) div SizeOf(TSemanticPhysicalSymbolOccurrence) then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_ARRAY_UNADDRESSABLE');
  SetLength(lSymbols, Integer(aCount));
  for i := 0 to High(lSymbols) do
  begin
    p := i * cPhysicalSymbolColumnCount;
    lSymbols[i].FactKindId := EvidenceInteger(lValues[p + 0], 0, High(Cardinal));
    lSymbols[i].NameId := EvidenceInteger(lValues[p + 1], 0, High(Cardinal));
    lSymbols[i].KindId := EvidenceInteger(lValues[p + 2], 0, High(Cardinal));
    lSymbols[i].OwnerNameId := EvidenceInteger(lValues[p + 3], 0, High(Cardinal));
    lSymbols[i].OwnerScopeId := EvidenceInteger(lValues[p + 4], 0, High(Cardinal));
    lSymbols[i].SemanticSymbolId := EvidenceInteger(lValues[p + 5], 0, High(Cardinal));
    lSymbols[i].OwnerSymbolId := EvidenceInteger(lValues[p + 6], 0, High(Cardinal));
    lSymbols[i].RoutineNameId := EvidenceInteger(lValues[p + 7], 0, High(Cardinal));
    lSymbols[i].RoutineScopeId := EvidenceInteger(lValues[p + 8], 0, High(Cardinal));
    lSymbols[i].SectionKindId := EvidenceInteger(lValues[p + 9], 0, High(Cardinal));
    lSymbols[i].FileId := EvidenceInteger(lValues[p + 10], 0, High(Cardinal));
    lSymbols[i].ExpansionId := EvidenceInteger(lValues[p + 11], 0, High(Cardinal));
    lSymbols[i].FactIndex := EvidenceInteger(lValues[p + 12], 0, MaxInt);
    lSymbols[i].ParentFactIndex := EvidenceInteger(lValues[p + 13], -1, MaxInt);
    lSymbols[i].SnapshotSymbolId := EvidenceInteger(lValues[p + 14], 0, High(Cardinal));
    lSymbols[i].ProjectionStatus := EvidenceInteger(lValues[p + 15], 0, 2);
    lSymbols[i].OutputStartOffset := EvidenceInteger(lValues[p + 16], 0, MaxInt);
    lSymbols[i].OutputEndOffset := EvidenceInteger(lValues[p + 17], 0, MaxInt);
    lSymbols[i].Line := EvidenceInteger(lValues[p + 18], 0, MaxInt);
    lSymbols[i].Column := EvidenceInteger(lValues[p + 19], 0, MaxInt);
    lSymbols[i].EndLine := EvidenceInteger(lValues[p + 20], 0, MaxInt);
    lSymbols[i].EndColumn := EvidenceInteger(lValues[p + 21], 0, MaxInt);
    lSymbols[i].Verified := (EvidenceInteger(lValues[p + 22], 0, 1) = 1);
  end;
  aUnit.SetPhysicalSymbolOccurrences(lSymbols, aAvailable);
end;

type
  TPhysicalAssociationKey = packed record
    Kind: Integer;
    Parent: Integer;
    Index: Integer;
  end;

  TPhysicalAssociationDensity = record
    Count: Integer;
    Maximum: Integer;
  end;

procedure CheckEvidenceId(const aPool: TSemanticStringPool; const id: TSemanticStringId);
begin
  if (id <> 0) and ((aPool = nil) or (id > aPool.Count)) then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_POOL_ID_INVALID');
end;

function CheckEvidenceFile(const aStrings: TSemanticStringPool; const id: TSemanticStringId;
  const aUnit: TUnitSnapshot; const aRequired: Boolean; var aCanonicalFiles: TArray<string>): string;
var
  lFile: string;
begin
  CheckEvidenceId(aStrings, id);
  Result := '';
  if id = 0 then
  begin
    if aRequired then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_FILE_MISSING');
    Exit;
  end;
  Result := aCanonicalFiles[id];
  if Result = '' then
  begin
    lFile := aStrings.TextOf(id);
    if not IsAbsoluteEvidenceFile(lFile) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_FILE_INVALID');
    Result := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lFile);
    if not SameText(lFile, Result) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_FILE_INVALID');
    aCanonicalFiles[id] := Result;
  end;
  if (id <> aUnit.FileNameId) and not aUnit.HasIncludes then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_HAS_INCLUDES_INVALID');
end;

procedure CheckEvidenceCoordinates(const aVerified: Boolean; const aName, aFile, aExpansion: Cardinal;
  const aStart, aEnd, aLine, aColumn, aEndLine, aEndColumn: Integer);
begin
  if (aStart < 0) or (aEnd < 0) or (aLine < 0) or (aColumn < 0) or
    (aEndLine < 0) or (aEndColumn < 0) then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_COORDINATES_INVALID');
  if aVerified and ((aName = 0) or (aFile = 0) or (aExpansion = 0) or
    (aStart <= 0) or (aEnd <= aStart) or (aLine <= 0) or (aColumn <= 0) or
    (aEndLine <> aLine) or (aEndColumn < aColumn) or
    (Int64(aEndColumn) - aColumn + 1 <> Int64(aEnd) - aStart)) then
    raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_VERIFICATION_INVALID');
end;

function PhysicalFactKindIndex(const aKind: string): Integer;
begin
  if aKind = 'declaration' then Exit(1);
  if aKind = 'member' then Exit(2);
  if aKind = 'type-value-member' then Exit(3);
  if aKind = 'routine' then Exit(4);
  if aKind = 'parameter' then Exit(5);
  if aKind = 'local' then Exit(6);
  raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_FACT_KIND_INVALID');
end;

procedure ValidatePhysicalEvidence(const aStrings, aExactStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot);
var
  g: TGarbos;
  i: Integer;
  id: Cardinal;
  lReference: TSemanticPhysicalReferenceOccurrence;
  lSymbol: TSemanticPhysicalSymbolOccurrence;
  lLegacy: TSemanticSymbolFact;
  lSource: TSemanticCapturedSourceFact;
  lPreviousFile, lFile, lKind: string;
  lCanonicalFiles: TArray<string>;
  lSeenImports: THashSet<Cardinal>;
  lSeen: THashSet<TPhysicalAssociationKey>;
  lRoutines: THashSet<Integer>;
  lDensities: TDictionary<UInt64, TPhysicalAssociationDensity>;
  lDensity: TPhysicalAssociationDensity;
  lKey: TPhysicalAssociationKey;
  lGroup: UInt64;
begin
  CheckEvidenceId(aExactStrings, aUnit.SourceTextId);
  CheckEvidenceId(aExactStrings, aUnit.VerifiedActiveSourceTextId);
  // This cache belongs only to this validation and its immutable string pool.
  // Every occurrence still checks ID bounds, required files and include state.
  if aStrings <> nil then
    SetLength(lCanonicalFiles, NativeInt(aStrings.Count) + 1);
  GC(lSeenImports, THashSet<Cardinal>.Create, g);
  for i := 0 to aUnit.VisibleUnitNameCount - 1 do
  begin
    id := aUnit.VisibleUnitNameByIndex(i);
    CheckEvidenceId(aStrings, id);
    if (id = 0) or not lSeenImports.Add(id) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_IMPORT_INVALID');
  end;
  lPreviousFile := '';
  for i := 0 to aUnit.CapturedSourceCount - 1 do
  begin
    lSource := aUnit.CapturedSourceByIndex(i);
    lFile := CheckEvidenceFile(aStrings, lSource.FileId, aUnit, True, lCanonicalFiles);
    CheckEvidenceId(aExactStrings, lSource.TextId);
    if (i > 0) and (CompareStr(lPreviousFile, lFile) >= 0) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_SOURCE_ORDER_INVALID');
    lPreviousFile := lFile;
    if (lSource.Status < cCapturedSourceUnavailable) or (lSource.Status > cCapturedSourceConflict) or
      ((lSource.Status = cCapturedSourceText) <> (lSource.TextId <> 0)) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_SOURCE_STATUS_INVALID');
  end;
  for i := 0 to aUnit.PhysicalReferenceOccurrenceCount - 1 do
  begin
    lReference := aUnit.PhysicalReferenceOccurrenceByIndex(i);
    CheckEvidenceId(aStrings, lReference.NameId);
    CheckEvidenceId(aStrings, lReference.RoleId);
    CheckEvidenceId(aStrings, lReference.RoutineNameId);
    CheckEvidenceId(aStrings, lReference.RoutineScopeId);
    CheckEvidenceId(aExactStrings, lReference.ExpansionId);
    CheckEvidenceFile(aStrings, lReference.FileId, aUnit, lReference.Verified, lCanonicalFiles);
    CheckEvidenceCoordinates(lReference.Verified, lReference.NameId, lReference.FileId,
      lReference.ExpansionId, lReference.OutputStartOffset, lReference.OutputEndOffset,
      lReference.Line, lReference.Column, lReference.EndLine, lReference.EndColumn);
  end;
  GC(lSeen, THashSet<TPhysicalAssociationKey>.Create, g);
  GC(lRoutines, THashSet<Integer>.Create, g);
  GC(lDensities, TDictionary<UInt64, TPhysicalAssociationDensity>.Create, g);
  for i := 0 to aUnit.PhysicalSymbolOccurrenceCount - 1 do
  begin
    lSymbol := aUnit.PhysicalSymbolOccurrenceByIndex(i);
    CheckEvidenceId(aStrings, lSymbol.FactKindId);
    CheckEvidenceId(aStrings, lSymbol.NameId);
    CheckEvidenceId(aStrings, lSymbol.KindId);
    CheckEvidenceId(aStrings, lSymbol.OwnerNameId);
    CheckEvidenceId(aStrings, lSymbol.OwnerScopeId);
    CheckEvidenceId(aStrings, lSymbol.SemanticSymbolId);
    CheckEvidenceId(aStrings, lSymbol.OwnerSymbolId);
    CheckEvidenceId(aStrings, lSymbol.RoutineNameId);
    CheckEvidenceId(aStrings, lSymbol.RoutineScopeId);
    CheckEvidenceId(aStrings, lSymbol.SectionKindId);
    CheckEvidenceId(aExactStrings, lSymbol.ExpansionId);
    CheckEvidenceFile(aStrings, lSymbol.FileId, aUnit, lSymbol.Verified, lCanonicalFiles);
    CheckEvidenceCoordinates(lSymbol.Verified, lSymbol.NameId, lSymbol.FileId,
      lSymbol.ExpansionId, lSymbol.OutputStartOffset, lSymbol.OutputEndOffset,
      lSymbol.Line, lSymbol.Column, lSymbol.EndLine, lSymbol.EndColumn);
    lKey.Kind := PhysicalFactKindIndex(aStrings.TextOf(lSymbol.FactKindId));
    lKey.Parent := lSymbol.ParentFactIndex;
    lKey.Index := lSymbol.FactIndex;
    if (lKey.Index < 0) or ((lKey.Kind = 5) and (lKey.Parent < 0)) or
      ((lKey.Kind <> 5) and (lKey.Parent <> -1)) or not lSeen.Add(lKey) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_ASSOCIATION_INVALID');
    if lKey.Kind = 4 then
      lRoutines.Add(lKey.Index);
    lGroup := (UInt64(lKey.Kind) shl 32) or UInt64(Int64(lKey.Parent) + 1);
    if not lDensities.TryGetValue(lGroup, lDensity) then
      lDensity := Default(TPhysicalAssociationDensity);
    Inc(lDensity.Count);
    if lKey.Index > lDensity.Maximum then
      lDensity.Maximum := lKey.Index;
    lDensities.AddOrSetValue(lGroup, lDensity);
    if (lSymbol.ProjectionStatus < cPhysicalProjectionNotProjected) or
      (lSymbol.ProjectionStatus > cPhysicalProjectionMalformed) or
      (aUnit.PhysicalSymbolOccurrencesAvailable and
        (lSymbol.ProjectionStatus = cPhysicalProjectionMalformed)) or
      ((lSymbol.ProjectionStatus = cPhysicalProjectionLinked) <> (lSymbol.SnapshotSymbolId <> 0)) or
      (lSymbol.SnapshotSymbolId > Cardinal(aUnit.SymbolCount)) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_LINK_INVALID');
    if lSymbol.SnapshotSymbolId <> 0 then
    begin
      lLegacy := aUnit.SymbolById(lSymbol.SnapshotSymbolId);
      lKind := aStrings.TextOf(lSymbol.KindId);
      if lKey.Kind = 4 then
        lKind := 'routine'
      else if lKey.Kind = 1 then
        lKind := SnapshotStoredSymbolKind(lKind)
      else if (lKey.Kind = 6) and (lKind = '') then
        lKind := 'local';
      if (lLegacy.NameId <> lSymbol.NameId) or
        not SameText(aStrings.TextOf(lLegacy.KindId), lKind) or
        ((lKey.Kind in [4, 5, 6]) and (lLegacy.RoutineScopeId <> lSymbol.RoutineScopeId)) or
        ((lKey.Kind = 1) and ((lLegacy.OwnerScopeId <> lSymbol.OwnerScopeId) or
          (lLegacy.SemanticSymbolId <> lSymbol.SemanticSymbolId))) then
        raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_LINK_METADATA_INVALID');
    end;
  end;
  for lKey in lSeen do
    if (lKey.Kind = 5) and not lRoutines.Contains(lKey.Parent) then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_PARAMETER_PARENT_INVALID');
  for lDensity in lDensities.Values do
    if Int64(lDensity.Maximum) + 1 <> lDensity.Count then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_FACT_DENSITY_INVALID');
end;

end.
