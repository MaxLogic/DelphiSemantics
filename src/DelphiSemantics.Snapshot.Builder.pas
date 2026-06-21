unit DelphiSemantics.Snapshot.Builder;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Workers,
  DelphiSemantics.WithBinding;

type
  TDelphiSnapshotBuildOptions = record
    ResolveReferenceTargets: Boolean;
    WorkerCount: Integer;
  end;

  TDelphiSnapshotBuilderMetrics = record
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
    BuildMilliseconds: Int64;
    WorkerCount: Integer;
    QueueMilliseconds: Int64;
    ParseExtractMilliseconds: Int64;
    MergeMilliseconds: Int64;
    DeterministicFactCount: Integer;
  end;

function BuildProjectSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aOptions: TDelphiSnapshotBuildOptions;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
function BuildProjectSnapshotFromUnitSnapshots(
  const aSnapshots: TArray<TDelphiProjectSnapshot>;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
function BuildProjectUnitSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>; const aModelIndex: Integer;
  const aUnitId: TSemanticUnitId; out aMetrics: TDelphiSnapshotBuilderMetrics):
  TDelphiProjectSnapshot; overload;
function BuildProjectUnitSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aModelUnitIds: TArray<TSemanticUnitId>; const aModelIndex: Integer;
  const aReferenceSnapshots: TArray<TDelphiProjectSnapshot>;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot; overload;
function BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiProjectSnapshot;
function BuildSnapshotReferenceTargets(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TSnapshotReferenceTargetLookup;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.IOUtils,
  System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Snapshot.RemoveWith;

const
  cSnapshotDeclarationKindAlias = 'alias';
  cSnapshotDeclarationKindTypeAlias = 'type-alias';
  cSnapshotSymbolFlagIsDefault = 1;
  cSnapshotSymbolFlagIsIndexed = 2;
  cSnapshotSymbolKindLocal = 'local';
  cSnapshotSymbolKindParameter = 'parameter';
  cSnapshotSymbolKindRoutine = 'routine';
  cSnapshotSourceKindProject = 'project-source';
  cSnapshotWithFlagHasScopedDeclaration = 1;

type
  TSnapshotTargetSymbol = record
    Ref: TSemanticSymbolRef;
    Name: string;
    Kind: string;
    OwnerName: string;
    UnitName: string;
    SectionKind: string;
    Signature: string;
    Line: Integer;
    Column: Integer;
    IsRoutineFact: Boolean;
  end;

  TSnapshotTargetSymbolList = TList<TSnapshotTargetSymbol>;
  TSnapshotTargetSymbolsByName = TObjectDictionary<string, TSnapshotTargetSymbolList>;
  TOriginalTargetUnit = record
    Snapshot: TDelphiProjectSnapshot;
    UnitSnapshot: TUnitSnapshot;
  end;

function SnapshotDeclarationKind(const aKind: string): string;
begin
  if SameText(aKind, cSnapshotDeclarationKindTypeAlias) then
    Exit(cSnapshotDeclarationKindAlias);

  Result := aKind;
end;

function SnapshotEndColumn(const aColumn: Integer; const aName: string): Integer;
begin
  if (aColumn <= 0) or (aName = '') then
    Exit(0);

  Result := aColumn + Length(aName) - 1;
end;

function SnapshotFullPath(const aFileName: string): string;
begin
  if Trim(aFileName) = '' then
    Exit('');

  Result := TPath.GetFullPath(aFileName);
end;

function SnapshotRoutineName(const aRoutine: TDelphiSemanticRoutine): string;
begin
  if aRoutine.OwnerName <> '' then
    Exit(aRoutine.OwnerName + '.' + aRoutine.Name);

  Result := aRoutine.Name;
end;

function SnapshotRoutineNameForLine(const aModel: TDelphiSemanticUnitModel;
  const aLine: Integer): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  lBestLine := 0;
  if aLine <= 0 then
    Exit;

  for lRoutine in aModel.Routines do
  begin
    if (lRoutine.Line <= 0) or (lRoutine.Line > aLine) then
      Continue;
    if lRoutine.Line < lBestLine then
      Continue;

    lBestLine := lRoutine.Line;
    Result := SnapshotRoutineName(lRoutine);
  end;
end;

function SnapshotRoutineNameHasOwner(const aRoutineName: string): Boolean;
begin
  Result := Pos('.', aRoutineName) > 0;
end;

function SnapshotReferenceRoutineNameForResolution(
  const aModel: TDelphiSemanticUnitModel;
  const aRoutineNamesByLine: TDictionary<Integer, string>;
  const aReference: TDelphiSemanticReference): string;
var
  lLineRoutineName: string;
begin
  Result := aReference.RoutineName;
  if (Result = '') or SnapshotRoutineNameHasOwner(Result) or
    (aReference.Line <= 0) then
    Exit;

  if not aRoutineNamesByLine.TryGetValue(aReference.Line, lLineRoutineName) then
  begin
    lLineRoutineName := SnapshotRoutineNameForLine(aModel, aReference.Line);
    aRoutineNamesByLine.AddOrSetValue(aReference.Line, lLineRoutineName);
  end;

  if (lLineRoutineName <> '') and SnapshotRoutineNameHasOwner(lLineRoutineName) then
    Result := lLineRoutineName;
end;

function SnapshotWithIdForLine(const aUnit: TUnitSnapshot; const aLine: Integer):
  TSemanticWithId;
begin
  Result := 0;
  aUnit.TryFindInnermostWithStatementAtLine(aLine, Result);
end;

function SnapshotReferenceMatchKey(const aUnitName, aRoutineName, aName: string;
  const aLine, aColumn: Integer): string;
begin
  Result := aUnitName + #9 + aRoutineName + #9 + aName + #9 + IntToStr(aLine) +
    #9 + IntToStr(aColumn);
end;

procedure AddTargetSymbolByName(const aMap: TSnapshotTargetSymbolsByName;
  const aSymbol: TSnapshotTargetSymbol);
var
  lSymbols: TSnapshotTargetSymbolList;
begin
  if not aMap.TryGetValue(aSymbol.Name, lSymbols) then
  begin
    lSymbols := TSnapshotTargetSymbolList.Create;
    try
      aMap.Add(aSymbol.Name, lSymbols);
    except
      lSymbols.Free;
      raise;
    end;
  end;
  lSymbols.Add(aSymbol);
end;

procedure AddSnapshotTargetSymbol(const aSymbols: TSnapshotTargetSymbolList;
  const aSymbolsByName: TSnapshotTargetSymbolsByName; const aUnitName, aKind,
  aOwnerName, aName, aSectionKind, aSignature: string; const aUnitId: TSemanticUnitId;
  const aLine, aColumn: Integer; const aIsRoutineFact: Boolean;
  var aNextSymbolId: TSemanticSymbolId);
var
  lSymbol: TSnapshotTargetSymbol;
begin
  Inc(aNextSymbolId);
  if aName = '' then
    Exit;

  lSymbol := Default(TSnapshotTargetSymbol);
  lSymbol.Ref.UnitId := aUnitId;
  lSymbol.Ref.SymbolId := aNextSymbolId;
  lSymbol.Name := aName;
  lSymbol.Kind := aKind;
  lSymbol.OwnerName := aOwnerName;
  lSymbol.UnitName := aUnitName;
  lSymbol.SectionKind := aSectionKind;
  lSymbol.Signature := aSignature;
  lSymbol.Line := aLine;
  lSymbol.Column := aColumn;
  lSymbol.IsRoutineFact := aIsRoutineFact;
  aSymbols.Add(lSymbol);
  AddTargetSymbolByName(aSymbolsByName, lSymbol);
end;

procedure AddModelSnapshotTargetSymbols(const aSymbols: TSnapshotTargetSymbolList;
  const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbolId: TSemanticSymbolId;
begin
  lSymbolId := 0;
  for lDeclaration in aModel.Declarations do
  begin
    if SameText(SnapshotDeclarationKind(lDeclaration.Kind), cSnapshotSymbolKindRoutine) then
      Continue;
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      SnapshotDeclarationKind(lDeclaration.Kind), '', lDeclaration.Name,
      lDeclaration.SectionKind, '', aUnitId, lDeclaration.Line, lDeclaration.Column,
      False, lSymbolId);
  end;
  for lMember in aModel.Members do
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      lMember.Kind, lMember.OwnerName, lMember.Name, '', lMember.Signature,
      aUnitId, lMember.Line, lMember.Column, False, lSymbolId);
  for lRoutine in aModel.Routines do
  begin
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      cSnapshotSymbolKindRoutine, lRoutine.OwnerName, lRoutine.Name,
      lRoutine.SectionKind, lRoutine.Signature, aUnitId, lRoutine.Line,
      lRoutine.Column, True, lSymbolId);
    for lParameter in lRoutine.Parameters do
      AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
        cSnapshotSymbolKindParameter, SnapshotRoutineName(lRoutine),
        lParameter.Name, lRoutine.SectionKind, lRoutine.Signature, aUnitId,
        lParameter.Line, lParameter.Column, False, lSymbolId);
  end;
  for lLocal in aModel.Locals do
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      lLocal.Kind, lLocal.RoutineName, lLocal.Name, '', '', aUnitId, lLocal.Line,
      lLocal.Column, False, lSymbolId);
end;

function ModelUnitIdAt(const aModelUnitIds: TArray<TSemanticUnitId>;
  const aIndex: Integer): TSemanticUnitId;
begin
  if (aIndex >= 0) and (aIndex <= High(aModelUnitIds)) and
    (aModelUnitIds[aIndex] <> 0) then
    Exit(aModelUnitIds[aIndex]);

  Result := TSemanticUnitId(aIndex + 1);
end;

procedure AddSnapshotTargetSymbolsFromSnapshot(const aSymbols: TSnapshotTargetSymbolList;
  const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  lFact: TSemanticSymbolFact;
  lKind: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbolId: TSemanticSymbolId;
  lUnit: TUnitSnapshot;
begin
  if aSnapshot = nil then
    Exit;

  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    for lSymbolId := 1 to TSemanticSymbolId(lUnit.SymbolCount) do
    begin
      lFact := lUnit.SymbolById(lSymbolId);
      lSymbol := Default(TSnapshotTargetSymbol);
      lSymbol.Ref.UnitId := lUnit.UnitId;
      lSymbol.Ref.SymbolId := lFact.Id;
      lSymbol.Name := aSnapshot.TextOf(lFact.NameId);
      if lSymbol.Name = '' then
        Continue;

      lKind := aSnapshot.TextOf(lFact.KindId);
      lSymbol.Kind := lKind;
      lSymbol.OwnerName := aSnapshot.TextOf(lFact.OwnerTypeId);
      if lSymbol.OwnerName = '' then
        lSymbol.OwnerName := aSnapshot.TextOf(lFact.RoutineId);
      lSymbol.UnitName := aSnapshot.TextOf(lUnit.UnitNameId);
      lSymbol.SectionKind := aSnapshot.TextOf(lFact.SectionKindId);
      lSymbol.Signature := aSnapshot.TextOf(lFact.SignatureId);
      lSymbol.Line := lFact.Line;
      lSymbol.Column := lFact.Column;
      lSymbol.IsRoutineFact := SameText(lKind, cSnapshotSymbolKindRoutine);
      aSymbols.Add(lSymbol);
      AddTargetSymbolByName(aSymbolsByName, lSymbol);
    end;
  end;
end;

function BuildSnapshotTargetSymbolsByName(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aModelUnitIds: TArray<TSemanticUnitId>;
  const aReferenceSnapshots: TArray<TDelphiProjectSnapshot>;
  out aSymbols: TSnapshotTargetSymbolList): TSnapshotTargetSymbolsByName; overload;
var
  i: Integer;
begin
  Result := nil;
  aSymbols := TSnapshotTargetSymbolList.Create;
  try
    Result := TSnapshotTargetSymbolsByName.Create([doOwnsValues],
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      for i := 0 to High(aModels) do
        AddModelSnapshotTargetSymbols(aSymbols, Result, aModels[i],
          ModelUnitIdAt(aModelUnitIds, i));
      for i := 0 to High(aReferenceSnapshots) do
        AddSnapshotTargetSymbolsFromSnapshot(aSymbols, Result, aReferenceSnapshots[i]);
    except
      Result.Free;
      Result := nil;
      raise;
    end;
  except
    aSymbols.Free;
    raise;
  end;
end;

function BuildSnapshotTargetSymbolsByName(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  out aSymbols: TSnapshotTargetSymbolList): TSnapshotTargetSymbolsByName; overload;
begin
  Result := BuildSnapshotTargetSymbolsByName(aModels, [], [], aSymbols);
end;

function SymbolRefInList(const aRefs: TList<TSemanticSymbolRef>;
  const aRef: TSemanticSymbolRef): Boolean;
var
  lRef: TSemanticSymbolRef;
begin
  for lRef in aRefs do
    if (lRef.UnitId = aRef.UnitId) and (lRef.SymbolId = aRef.SymbolId) then
      Exit(True);

  Result := False;
end;

procedure AddCandidateRef(const aRefs: TList<TSemanticSymbolRef>;
  const aSymbol: TSnapshotTargetSymbol);
begin
  if not SymbolRefInList(aRefs, aSymbol.Ref) then
    aRefs.Add(aSymbol.Ref);
end;

function SnapshotLocalSymbolKind(const aKind: string): Boolean;
begin
  Result := MatchText(aKind, [cSnapshotSymbolKindLocal,
    cSnapshotSymbolKindParameter, 'var']);
end;

function SnapshotRoutineSimpleName(const aRoutineName: string): string;
var
  lIndex: Integer;
begin
  lIndex := LastDelimiter('.', aRoutineName);
  if lIndex > 0 then
    Exit(Copy(aRoutineName, lIndex + 1, MaxInt));

  Result := aRoutineName;
end;

function SnapshotQualifiedRoutineName(const aSymbol: TSnapshotTargetSymbol): string;
begin
  if aSymbol.OwnerName <> '' then
    Exit(aSymbol.OwnerName + '.' + aSymbol.Name);

  Result := aSymbol.Name;
end;

function NormalizeSnapshotSignature(const aSignature: string): string;
begin
  Result := LowerCase(StringReplace(aSignature.Trim, ' ', '', [rfReplaceAll]));
end;

function SnapshotLocalSymbolMatchesReference(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference; const aRoutineSignature: string;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  Result := SameText(aSymbol.UnitName, aModel.UnitName)
    and SameText(aSymbol.OwnerName, aReference.RoutineName)
    and SnapshotLocalSymbolKind(aSymbol.Kind);
  if Result and (aRoutineSignature <> '') and (aSymbol.Signature <> '') then
    Result := SameText(NormalizeSnapshotSignature(aSymbol.Signature),
      aRoutineSignature);
end;

function SnapshotLocalSymbolPrecedesReference(
  const aReference: TDelphiSemanticReference;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  if (aReference.Line <= 0) or (aSymbol.Line <= 0) then
    Exit(True);
  if aSymbol.Line < aReference.Line then
    Exit(True);
  if aSymbol.Line > aReference.Line then
    Exit(False);
  if (aReference.Column <= 0) or (aSymbol.Column <= 0) then
    Exit(True);

  Result := aSymbol.Column <= aReference.Column;
end;

function SnapshotLocalSymbolIsBetterForReference(
  const aReference: TDelphiSemanticReference;
  const aCandidate, aCurrent: TSnapshotTargetSymbol): Boolean;
begin
  if not SnapshotLocalSymbolPrecedesReference(aReference, aCandidate) then
    Exit(False);
  if not SnapshotLocalSymbolPrecedesReference(aReference, aCurrent) then
    Exit(True);
  if aCandidate.Line <> aCurrent.Line then
    Exit(aCandidate.Line > aCurrent.Line);

  Result := aCandidate.Column > aCurrent.Column;
end;

function SnapshotLocalSymbolsHaveSameLocation(const aLeft, aRight:
  TSnapshotTargetSymbol): Boolean;
begin
  Result := (aLeft.Line = aRight.Line) and (aLeft.Column = aRight.Column);
end;

function SnapshotTargetSymbolsAreEquivalent(const aLeft, aRight:
  TSnapshotTargetSymbol): Boolean;
begin
  if not (SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.OwnerName, aRight.OwnerName) and SameText(aLeft.Name, aRight.Name)) then
    Exit(False);
  if not (SameText(aLeft.Kind, cSnapshotSymbolKindRoutine) and
    SameText(aRight.Kind, cSnapshotSymbolKindRoutine)) then
    Exit(False);

  Result := SameText(NormalizeSnapshotSignature(aLeft.Signature),
    NormalizeSnapshotSignature(aRight.Signature)) or
    ((aLeft.Line > 0) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column));
end;

function TargetSymbolInList(const aSymbols: TSnapshotTargetSymbolList;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
var
  lSymbol: TSnapshotTargetSymbol;
begin
  for lSymbol in aSymbols do
    if SnapshotTargetSymbolsAreEquivalent(lSymbol, aSymbol) then
      Exit(True);

  Result := False;
end;

function TryResolveUniqueSnapshotRoutineRef(
  const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aRoutineName: string;
  out aRoutineRef: TSemanticSymbolRef; out aRoutineSignature: string;
  out aAmbiguous: Boolean): Boolean;
var
  lCount: Integer;
  lSignature: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  aRoutineRef := Default(TSemanticSymbolRef);
  aRoutineSignature := '';
  aAmbiguous := False;
  lCount := 0;
  lSignature := '';
  if not aSymbolsByName.TryGetValue(SnapshotRoutineSimpleName(aRoutineName),
    lSymbols) then
    Exit(False);

  for lSymbol in lSymbols do
    if SameText(lSymbol.UnitName, aModel.UnitName)
      and SameText(lSymbol.Kind, cSnapshotSymbolKindRoutine)
      and lSymbol.IsRoutineFact
      and SameText(SnapshotQualifiedRoutineName(lSymbol), aRoutineName) then
    begin
      if lCount = 0 then
      begin
        Inc(lCount);
        aRoutineRef := lSymbol.Ref;
        lSignature := NormalizeSnapshotSignature(lSymbol.Signature);
        aRoutineSignature := lSignature;
      end else if not SameText(lSignature,
        NormalizeSnapshotSignature(lSymbol.Signature)) then
      begin
        Inc(lCount);
        aRoutineRef := Default(TSemanticSymbolRef);
        aAmbiguous := True;
        Exit(False);
      end;
    end;

  Result := lCount = 1;
end;

function AddLocalReferenceCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateRefs: TList<TSemanticSymbolRef>): Boolean;
var
  lAmbiguousRoutine: Boolean;
  lBestCount: Integer;
  lBestSymbol: TSnapshotTargetSymbol;
  lHasBest: Boolean;
  lRoutineRef: TSemanticSymbolRef;
  lRoutineSignature: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  Result := False;
  if aReference.RoutineName = '' then
    Exit;
  if not TryResolveUniqueSnapshotRoutineRef(aSymbolsByName, aModel,
    aReference.RoutineName, lRoutineRef, lRoutineSignature, lAmbiguousRoutine) then
  begin
    Result := lAmbiguousRoutine;
    Exit;
  end;
  if lRoutineRef.SymbolId = 0 then
    Exit;
  if not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit;

  lBestSymbol := Default(TSnapshotTargetSymbol);
  lBestCount := 0;
  lHasBest := False;
  for lSymbol in lSymbols do
  begin
    if not SnapshotLocalSymbolMatchesReference(aModel, aReference,
      lRoutineSignature, lSymbol) then
      Continue;
    if not SnapshotLocalSymbolPrecedesReference(aReference, lSymbol) then
      Continue;

    if not lHasBest or SnapshotLocalSymbolIsBetterForReference(aReference,
      lSymbol, lBestSymbol) then
    begin
      lBestSymbol := lSymbol;
      lBestCount := 1;
      lHasBest := True;
    end else if SnapshotLocalSymbolsHaveSameLocation(lSymbol, lBestSymbol) then
      Inc(lBestCount);
  end;

  if lHasBest and (lBestCount = 1) then
    AddCandidateRef(aCandidateRefs, lBestSymbol);

  Result := aCandidateRefs.Count > 0;
end;

function ModelUsesUnitInSection(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind, aUnitName: string): Boolean; forward;

function OwnedSymbolIsVisibleFromReference(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
var
  lSectionKind: string;
begin
  if aSymbol.OwnerName = '' then
    Exit(False);
  if SameText(aSymbol.Kind, 'class-var') then
  begin
    lSectionKind := aReference.SectionKind;
    if lSectionKind = '' then
      lSectionKind := 'implementation';
    Exit(ModelUsesUnitInSection(aModel, lSectionKind, aSymbol.UnitName));
  end;
  if not SameText(aModel.UnitName, aSymbol.UnitName) then
    Exit(False);
  if MatchText(aSymbol.Kind, ['field', 'class-var', 'property']) then
    Exit(StartsText(aSymbol.OwnerName + '.', aReference.RoutineName));

  Result := False;
end;

function IsOwnedMethodCandidate(const aModel: TDelphiSemanticUnitModel;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  Result := (aSymbol.OwnerName <> '') and SameText(aModel.UnitName, aSymbol.UnitName)
    and SameText(aSymbol.Kind, 'method');
end;

function AddOwnedReferenceCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateRefs: TList<TSemanticSymbolRef>): Boolean;
var
  lOriginalCount: Integer;
  lMethodCandidate: TSnapshotTargetSymbol;
  lMethodCount: Integer;
  lMethodOwnerName: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  lOriginalCount := aCandidateRefs.Count;
  if not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit(False);

  lMethodCandidate := Default(TSnapshotTargetSymbol);
  lMethodCount := 0;
  lMethodOwnerName := '';
  for lSymbol in lSymbols do
  begin
    if OwnedSymbolIsVisibleFromReference(aModel, aReference, lSymbol) then
      AddCandidateRef(aCandidateRefs, lSymbol);
    if IsOwnedMethodCandidate(aModel, lSymbol) and not SameText(lSymbol.OwnerName,
      lMethodOwnerName) then
    begin
      Inc(lMethodCount);
      lMethodOwnerName := lSymbol.OwnerName;
      lMethodCandidate := lSymbol;
    end;
  end;

  if lMethodCount = 1 then
    AddCandidateRef(aCandidateRefs, lMethodCandidate);

  Result := aCandidateRefs.Count > lOriginalCount;
end;

function SectionCanSeeImplementationSymbols(const aSectionKind: string): Boolean;
begin
  Result := MatchText(aSectionKind, ['implementation', 'initialization',
    'finalization']);
end;

function TopLevelSymbolIsVisibleFromReference(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind: string; const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  if aSymbol.OwnerName <> '' then
    Exit(False);

  if not (SameText(aSymbol.Kind, 'unit') or SameText(aSymbol.Kind, 'type') or
    SameText(aSymbol.Kind, cSnapshotDeclarationKindAlias) or
    SameText(aSymbol.Kind, cSnapshotDeclarationKindTypeAlias) or
    SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'threadvar') or
    SameText(aSymbol.Kind, 'const') or SameText(aSymbol.Kind, 'typed-const') or
    SameText(aSymbol.Kind, 'resourcestring') or SameText(aSymbol.Kind,
    cSnapshotSymbolKindRoutine)) then
    Exit(False);

  if SameText(aModel.UnitName, aSymbol.UnitName) then
    Exit(SectionCanSeeImplementationSymbols(aSectionKind)
      or SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit'));

  Result := SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit');
end;

function ModelUsesUnitInSection(const aModel: TDelphiSemanticUnitModel;
  const aSectionKind, aUnitName: string): Boolean;
var
  s: string;
begin
  if SameText(aModel.UnitName, aUnitName) then
    Exit(True);

  for s in aModel.InterfaceUses do
    if SameText(s, aUnitName) then
      Exit(True);

  if SameText(aSectionKind, 'implementation') then
    for s in aModel.ImplementationUses do
      if SameText(s, aUnitName) then
        Exit(True);

  Result := False;
end;

procedure AddTopLevelReferenceCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateRefs: TList<TSemanticSymbolRef>);
var
  lSectionKind: string;
  lSelectedSymbols: TSnapshotTargetSymbolList;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  if not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit;

  lSectionKind := aReference.SectionKind;
  if lSectionKind = '' then
    lSectionKind := 'implementation';

  lSelectedSymbols := TSnapshotTargetSymbolList.Create;
  try
    for lSymbol in lSymbols do
      if ModelUsesUnitInSection(aModel, lSectionKind, lSymbol.UnitName)
        and TopLevelSymbolIsVisibleFromReference(aModel, lSectionKind, lSymbol) and
        not TargetSymbolInList(lSelectedSymbols, lSymbol) then
      begin
        lSelectedSymbols.Add(lSymbol);
        AddCandidateRef(aCandidateRefs, lSymbol);
      end;
  finally
    lSelectedSymbols.Free;
  end;
end;

function TryResolveSnapshotReferenceTarget(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTargetRef: TSemanticSymbolRef): Boolean;
var
  lCandidateRefs: TList<TSemanticSymbolRef>;
begin
  aTargetRef := Default(TSemanticSymbolRef);
  lCandidateRefs := TList<TSemanticSymbolRef>.Create;
  try
    if not AddLocalReferenceCandidates(aSymbolsByName, aModel, aReference,
      lCandidateRefs) then
    begin
      if not AddOwnedReferenceCandidates(aSymbolsByName, aModel, aReference,
        lCandidateRefs) then
        AddTopLevelReferenceCandidates(aSymbolsByName, aModel, aReference,
          lCandidateRefs);
    end;

    Result := lCandidateRefs.Count = 1;
    if Result then
      aTargetRef := lCandidateRefs[0];
  finally
    lCandidateRefs.Free;
  end;
end;

function BuildSnapshotReferenceTargetsForModelsAndSnapshots(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aModelUnitIds: TArray<TSemanticUnitId>;
  const aReferenceSnapshots: TArray<TDelphiProjectSnapshot>):
  TSnapshotReferenceTargetLookup;
var
  lTargets: TSnapshotReferenceTargetMap;
  lReference: TDelphiSemanticReference;
  lResolutionReference: TDelphiSemanticReference;
  lRoutineNamesByLine: TDictionary<Integer, string>;
  lSymbols: TSnapshotTargetSymbolList;
  lSymbolsByName: TSnapshotTargetSymbolsByName;
  lTargetRef: TSemanticSymbolRef;
  lUnitModel: TDelphiSemanticUnitModel;
begin
  lTargets := TSnapshotReferenceTargetMap.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSymbolsByName := BuildSnapshotTargetSymbolsByName(aModels, aModelUnitIds,
    aReferenceSnapshots, lSymbols);
  lRoutineNamesByLine := TDictionary<Integer, string>.Create;
  try
    for lUnitModel in aModels do
    begin
      lRoutineNamesByLine.Clear;
      for lReference in lUnitModel.References do
      begin
        lResolutionReference := lReference;
        lResolutionReference.RoutineName := SnapshotReferenceRoutineNameForResolution(
          lUnitModel, lRoutineNamesByLine, lReference);
        if TryResolveSnapshotReferenceTarget(lSymbolsByName, lUnitModel,
          lResolutionReference, lTargetRef) then
          lTargets.AddOrSetValue(SnapshotReferenceMatchKey(lUnitModel.UnitName,
            lReference.RoutineName, lReference.Name, lReference.Line,
            lReference.Column), lTargetRef);
      end;
    end;
    Result := TSnapshotReferenceTargetLookup.FromMap(lTargets);
  finally
    lRoutineNamesByLine.Free;
    lSymbolsByName.Free;
    lSymbols.Free;
    lTargets.Free;
  end;
end;

function BuildSnapshotReferenceTargets(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TSnapshotReferenceTargetLookup;
begin
  Result := BuildSnapshotReferenceTargetsForModelsAndSnapshots(aModels, [], []);
end;

procedure AddSnapshotWithStatement(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aModel: TDelphiSemanticUnitModel;
  const aWith: TDelphiSemanticWithStatement;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lWith: TSemanticWithStatementFact;
begin
  lWith := Default(TSemanticWithStatementFact);
  lWith.RoutineId := aStrings.Intern(SnapshotRoutineNameForLine(aModel, aWith.Line));
  lWith.SelectorStartLine := aWith.Line;
  lWith.SelectorStartColumn := aWith.Column;
  lWith.BodyStartLine := aWith.BodyLine;
  lWith.BodyStartColumn := aWith.BodyColumn;
  lWith.BodyEndLine := aWith.BodyEndLine;
  lWith.BodyEndColumn := aWith.BodyEndColumn;
  if aWith.HasScopedDeclaration then
    lWith.Flags := cSnapshotWithFlagHasScopedDeclaration;
  aUnit.AddWithStatement(lWith);
  Inc(aMetrics.WithStatementCount);
end;

procedure AddSnapshotDeclaration(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aDeclaration: TDelphiSemanticDeclaration;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lSymbol: TSemanticSymbolFact;
begin
  if SameText(SnapshotDeclarationKind(aDeclaration.Kind), cSnapshotSymbolKindRoutine) then
    Exit;

  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aDeclaration.Name);
  lSymbol.TypeId := aStrings.Intern(aDeclaration.TypeName);
  lSymbol.KindId := aStrings.Intern(SnapshotDeclarationKind(aDeclaration.Kind));
  lSymbol.SectionKindId := aStrings.Intern(aDeclaration.SectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aDeclaration.Line;
  lSymbol.Column := aDeclaration.Column;
  lSymbol.EndLine := aDeclaration.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aDeclaration.Column, aDeclaration.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotMember(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aMember: TDelphiSemanticMember;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aMember.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aMember.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aMember.TypeName);
  lSymbol.KindId := aStrings.Intern(aMember.Kind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.VisibilityId := aStrings.Intern(aMember.Visibility);
  lSymbol.SignatureId := aStrings.Intern(aMember.Signature);
  lSymbol.Line := aMember.Line;
  lSymbol.Column := aMember.Column;
  lSymbol.EndLine := aMember.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aMember.Column, aMember.Name);
  if aMember.IsDefault then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsDefault;
  if aMember.IsIndexed then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsIndexed;
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotParameter(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutineName, aRoutineSectionKind,
  aRoutineSignature: string; const aParameter: TDelphiSemanticParameter;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aParameter.Name);
  lSymbol.TypeId := aStrings.Intern(aParameter.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindParameter);
  lSymbol.SectionKindId := aStrings.Intern(aRoutineSectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.SignatureId := aStrings.Intern(aRoutineSignature);
  lSymbol.Line := aParameter.Line;
  lSymbol.Column := aParameter.Column;
  lSymbol.EndLine := aParameter.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aParameter.Column, aParameter.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotRoutine(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutine: TDelphiSemanticRoutine;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lParameter: TDelphiSemanticParameter;
  lRoutineName: string;
  lSymbol: TSemanticSymbolFact;
begin
  lRoutineName := SnapshotRoutineName(aRoutine);
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aRoutine.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aRoutine.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aRoutine.ReturnType);
  lSymbol.RoutineId := aStrings.Intern(lRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindRoutine);
  lSymbol.SectionKindId := aStrings.Intern(aRoutine.SectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.SignatureId := aStrings.Intern(aRoutine.Signature);
  lSymbol.Line := aRoutine.Line;
  lSymbol.Column := aRoutine.Column;
  lSymbol.EndLine := aRoutine.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aRoutine.Column, aRoutine.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);

  for lParameter in aRoutine.Parameters do
    AddSnapshotParameter(aStrings, aUnit, lRoutineName, aRoutine.SectionKind,
      aRoutine.Signature, lParameter, aMetrics);
end;

procedure AddSnapshotLocal(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aLocal: TDelphiSemanticLocal;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lKind: string;
  lSymbol: TSemanticSymbolFact;
begin
  lKind := aLocal.Kind;
  if lKind = '' then
    lKind := cSnapshotSymbolKindLocal;
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aLocal.Name);
  lSymbol.TypeId := aStrings.Intern(aLocal.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aLocal.RoutineName);
  lSymbol.KindId := aStrings.Intern(lKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aLocal.Line;
  lSymbol.Column := aLocal.Column;
  lSymbol.EndLine := aLocal.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aLocal.Column, aLocal.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotReference(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aUnitName: string;
  const aReference: TDelphiSemanticReference;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  var aMetrics: TSnapshotUnitBuildResult);
var
  lReference: TSemanticReferenceFact;
  lTarget: TSemanticSymbolRef;
begin
  lReference := Default(TSemanticReferenceFact);
  lReference.WithId := SnapshotWithIdForLine(aUnit, aReference.Line);
  lReference.NameId := aStrings.Intern(aReference.Name);
  lReference.RoutineId := aStrings.Intern(aReference.RoutineName);
  lReference.SectionKindId := aStrings.Intern(aReference.SectionKind);
  lReference.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lReference.ClassificationId := aStrings.Intern(aReference.Role);
  lReference.Line := aReference.Line;
  lReference.Column := aReference.Column;
  lReference.EndLine := aReference.EndLine;
  if lReference.EndLine <= 0 then
    lReference.EndLine := aReference.Line;
  lReference.EndColumn := aReference.EndColumn;
  if lReference.EndColumn <= 0 then
    lReference.EndColumn := SnapshotEndColumn(aReference.Column, aReference.Name);
  if aReferenceTargetLookup.TryGetValue(
    SnapshotReferenceMatchKey(aUnitName, aReference.RoutineName, aReference.Name,
    aReference.Line, aReference.Column), lTarget) then
  begin
    lReference.TargetUnitId := lTarget.UnitId;
    lReference.TargetSymbolId := lTarget.SymbolId;
  end;
  aUnit.AddReference(lReference);
  Inc(aMetrics.ReferenceCount);
end;

function CreateSnapshotUnitModel(const aStrings, aExactStrings: TSemanticStringPool;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  var aMetrics: TSnapshotUnitBuildResult): TUnitSnapshot;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lReference: TDelphiSemanticReference;
  lRoutine: TDelphiSemanticRoutine;
  lWith: TDelphiSemanticWithStatement;
begin
  Result := TUnitSnapshot.Create(aUnitId, aStrings.Intern(SnapshotFullPath(aModel.FileName)),
    aStrings.Intern(aModel.UnitName), aExactStrings.Intern(aModel.SourceText));
  try
    for lWith in aModel.WithStatements do
      AddSnapshotWithStatement(aStrings, Result, aModel, lWith, aMetrics);
    for lDeclaration in aModel.Declarations do
      AddSnapshotDeclaration(aStrings, Result, lDeclaration, aMetrics);
    for lMember in aModel.Members do
      AddSnapshotMember(aStrings, Result, lMember, aMetrics);
    for lRoutine in aModel.Routines do
      AddSnapshotRoutine(aStrings, Result, lRoutine, aMetrics);
    for lLocal in aModel.Locals do
      AddSnapshotLocal(aStrings, Result, lLocal, aMetrics);
    for lReference in aModel.References do
      AddSnapshotReference(aStrings, Result, aModel.UnitName, lReference,
        aReferenceTargetLookup, aMetrics);
  except
    Result.Free;
    raise;
  end;
end;

procedure AddSnapshotFlag(var aFlags: Cardinal; const aFlag: Cardinal;
  const aEnabled: Boolean);
begin
  if aEnabled then
    aFlags := aFlags or aFlag;
end;

function SnapshotInventorySymbol(const aExactStrings: TSemanticStringPool;
  const aSymbol: TDelphiSemanticInventorySymbol): TSemanticRemoveWithInventorySymbolFact;
begin
  Result := Default(TSemanticRemoveWithInventorySymbolFact);
  Result.NameId := aExactStrings.Intern(aSymbol.Name);
  Result.SymbolClassId := aExactStrings.Intern(aSymbol.SymbolClass);
  Result.KindId := aExactStrings.Intern(aSymbol.Kind);
  Result.TypeNameId := aExactStrings.Intern(aSymbol.TypeName);
  Result.ModifierId := aExactStrings.Intern(aSymbol.Modifier);
  Result.OwnerNameId := aExactStrings.Intern(aSymbol.OwnerName);
  Result.OwnerTypeId := aExactStrings.Intern(aSymbol.OwnerType);
  Result.SourceOwnerTypeId := aExactStrings.Intern(aSymbol.SourceOwnerType);
  Result.RelatedTypeNameId := aExactStrings.Intern(aSymbol.RelatedTypeName);
  Result.RoutineNameId := aExactStrings.Intern(aSymbol.RoutineName);
  Result.UnitNameId := aExactStrings.Intern(aSymbol.UnitName);
  Result.FileNameId := aExactStrings.Intern(aSymbol.FileName);
  Result.SectionKindId := aExactStrings.Intern(aSymbol.SectionKind);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReasonId := aExactStrings.Intern(aSymbol.UnsupportedReason);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsHelper,
    aSymbol.IsHelper);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsOverride,
    aSymbol.IsOverride);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsDefault,
    aSymbol.IsDefault);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsIndexed,
    aSymbol.IsIndexed);
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategoryId := aExactStrings.Intern(aSymbol.TypeCategory);
end;

function SnapshotSelectorBinding(const aExactStrings: TSemanticStringPool;
  const aSelector: TDelphiSemanticWithSelectorBinding):
  TSemanticRemoveWithSelectorBindingFact;
begin
  Result := Default(TSemanticRemoveWithSelectorBindingFact);
  Result.SelectorTextId := aExactStrings.Intern(aSelector.SelectorText);
  Result.StatusId := aExactStrings.Intern(aSelector.Status);
  Result.ReasonCodeId := aExactStrings.Intern(aSelector.ReasonCode);
  Result.TypeNameId := aExactStrings.Intern(aSelector.TypeName);
end;

function SnapshotBoundReference(const aExactStrings: TSemanticStringPool;
  const aReference: TDelphiSemanticBoundReference):
  TSemanticRemoveWithBoundReferenceFact;
begin
  Result := Default(TSemanticRemoveWithBoundReferenceFact);
  Result.SemanticIdId := aExactStrings.Intern(aReference.SemanticId);
  Result.NameId := aExactStrings.Intern(aReference.Name);
  Result.ClassificationId := aExactStrings.Intern(aReference.Classification);
  Result.LookupSourceId := aExactStrings.Intern(aReference.LookupSource);
  Result.ReceiverTypeNameId := aExactStrings.Intern(aReference.ReceiverTypeName);
  Result.KindId := aExactStrings.Intern(aReference.Kind);
  Result.TypeNameId := aExactStrings.Intern(aReference.TypeName);
  Result.ReasonCodeId := aExactStrings.Intern(aReference.ReasonCode);
  Result.ScopeConflictKindId := aExactStrings.Intern(aReference.ScopeConflictKind);
  Result.ScopeConflictNameId := aExactStrings.Intern(aReference.ScopeConflictName);
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
end;

function SnapshotWithBinding(const aExactStrings: TSemanticStringPool;
  const aBinding: TDelphiSemanticWithBinding): TSemanticRemoveWithBindingFact;
var
  i: Integer;
begin
  Result := Default(TSemanticRemoveWithBindingFact);
  Result.SemanticIdId := aExactStrings.Intern(aBinding.SemanticId);
  Result.ProvenanceId := aExactStrings.Intern(aBinding.Provenance);
  Result.FileNameId := aExactStrings.Intern(aBinding.FileName);
  Result.UnitNameId := aExactStrings.Intern(aBinding.UnitName);
  Result.RoutineNameId := aExactStrings.Intern(aBinding.RoutineName);
  Result.Line := aBinding.Line;
  Result.Column := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
  Result.BodyLine := aBinding.BodyLine;
  Result.BodyColumn := aBinding.BodyColumn;
  Result.BodyEndLine := aBinding.BodyEndLine;
  Result.BodyEndColumn := aBinding.BodyEndColumn;
  Result.SelectorTextId := aExactStrings.Intern(aBinding.SelectorText);
  Result.StatusId := aExactStrings.Intern(aBinding.Status);
  Result.SkipReasonId := aExactStrings.Intern(aBinding.SkipReason);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithBindingFlagHasScopedDeclaration,
    aBinding.HasScopedDeclaration);
  Result.MemberReferenceCount := aBinding.MemberReferenceCount;
  Result.LexicalReferenceCount := aBinding.LexicalReferenceCount;
  Result.ExternalReferenceCount := aBinding.ExternalReferenceCount;
  Result.IntrinsicReferenceCount := aBinding.IntrinsicReferenceCount;
  Result.UnsupportedReferenceCount := aBinding.UnsupportedReferenceCount;
  Result.UnresolvedReferenceCount := aBinding.UnresolvedReferenceCount;
  SetLength(Result.Selectors, Length(aBinding.Selectors));
  for i := 0 to High(aBinding.Selectors) do
    Result.Selectors[i] := SnapshotSelectorBinding(aExactStrings, aBinding.Selectors[i]);
  SetLength(Result.References, Length(aBinding.References));
  for i := 0 to High(aBinding.References) do
    Result.References[i] := SnapshotBoundReference(aExactStrings, aBinding.References[i]);
end;

function CreateRemoveWithPlanningFacts(const aExactStrings: TSemanticStringPool;
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TSemanticRemoveWithPlanningFacts;
var
  i: Integer;
  lRoutineOwners: TList<TSemanticRemoveWithInventorySymbolFact>;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := Default(TSemanticRemoveWithPlanningFacts);
  Result.ContextFingerprintId := aExactStrings.Intern(aFacts.ContextFingerprint);
  if aFacts.LookupIndex.IsAvailable then
    Result.LookupIndex := aFacts.LookupIndex
  else
    Result.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(
      aFacts.UnitModels, aFacts.Symbols);
  lRoutineOwners := TList<TSemanticRemoveWithInventorySymbolFact>.Create;
  try
    for lSymbol in aFacts.Symbols do
      if SameText(lSymbol.SymbolClass, 'routine') or SameText(lSymbol.Kind, 'routine') then
        lRoutineOwners.Add(SnapshotInventorySymbol(aExactStrings, lSymbol));
    Result.RoutineOwners := lRoutineOwners.ToArray;
  finally
    lRoutineOwners.Free;
  end;
  SetLength(Result.Bindings, Length(aFacts.Bindings));
  for i := 0 to High(aFacts.Bindings) do
    Result.Bindings[i] := SnapshotWithBinding(aExactStrings, aFacts.Bindings[i]);
end;

function RemapStringId(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aId: TSemanticStringId): TSemanticStringId;
begin
  if aId = 0 then
    Exit(0);

  Result := aTargetStrings.Intern(aSourceStrings.TextOf(aId));
end;

function RemapSymbolFact(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aSymbol: TSemanticSymbolFact): TSemanticSymbolFact;
begin
  Result := aSymbol;
  Result.NameId := RemapStringId(aSourceStrings, aTargetStrings, aSymbol.NameId);
  Result.OwnerTypeId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.OwnerTypeId);
  Result.TypeId := RemapStringId(aSourceStrings, aTargetStrings, aSymbol.TypeId);
  Result.RoutineId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.RoutineId);
  Result.KindId := RemapStringId(aSourceStrings, aTargetStrings, aSymbol.KindId);
  Result.SectionKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.SectionKindId);
  Result.SourceKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.SourceKindId);
  Result.VisibilityId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.VisibilityId);
  Result.SignatureId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.SignatureId);
end;

function RemapWithFact(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aWith: TSemanticWithStatementFact): TSemanticWithStatementFact;
begin
  Result := aWith;
  Result.RoutineId := RemapStringId(aSourceStrings, aTargetStrings, aWith.RoutineId);
end;

function RemapReferenceFact(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aReference: TSemanticReferenceFact): TSemanticReferenceFact;
begin
  Result := aReference;
  Result.NameId := RemapStringId(aSourceStrings, aTargetStrings, aReference.NameId);
  Result.ReceiverTypeId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.ReceiverTypeId);
  Result.TypeId := RemapStringId(aSourceStrings, aTargetStrings, aReference.TypeId);
  Result.RoutineId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.RoutineId);
  Result.SectionKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.SectionKindId);
  Result.SourceKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.SourceKindId);
  Result.ClassificationId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.ClassificationId);
  Result.LookupSourceId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.LookupSourceId);
  Result.ReasonId := RemapStringId(aSourceStrings, aTargetStrings, aReference.ReasonId);
end;

function TargetNameKey(const aUnitId: TSemanticUnitId; const aName: string): string;
begin
  Result := 'name|' + IntToStr(Integer(aUnitId)) + '|' + aName;
end;

function TargetSymbolKey(const aUnitId: TSemanticUnitId; const aName, aOwnerType,
  aRoutine, aKind, aSectionKind, aSignature: string; const aLine,
  aColumn: Integer): string;
begin
  Result := 'symbol|' + IntToStr(Integer(aUnitId)) + '|' + aName + '|' +
    aOwnerType + '|' + aRoutine + '|' + aKind + '|' + aSectionKind + '|' +
    aSignature + '|' + IntToStr(aLine) + '|' + IntToStr(aColumn);
end;

function TargetSymbolKeyFromSnapshot(const aSnapshot: TDelphiProjectSnapshot;
  const aUnitId: TSemanticUnitId; const aSymbol: TSemanticSymbolFact): string;
begin
  Result := TargetSymbolKey(aUnitId, aSnapshot.TextOf(aSymbol.NameId),
    aSnapshot.TextOf(aSymbol.OwnerTypeId), aSnapshot.TextOf(aSymbol.RoutineId),
    aSnapshot.TextOf(aSymbol.KindId), aSnapshot.TextOf(aSymbol.SectionKindId),
    aSnapshot.TextOf(aSymbol.SignatureId), aSymbol.Line, aSymbol.Column);
end;

function TargetSymbolKeyFromStrings(const aStrings: TSemanticStringPool;
  const aUnitId: TSemanticUnitId; const aSymbol: TSemanticSymbolFact): string;
begin
  Result := TargetSymbolKey(aUnitId, aStrings.TextOf(aSymbol.NameId),
    aStrings.TextOf(aSymbol.OwnerTypeId), aStrings.TextOf(aSymbol.RoutineId),
    aStrings.TextOf(aSymbol.KindId), aStrings.TextOf(aSymbol.SectionKindId),
    aStrings.TextOf(aSymbol.SignatureId), aSymbol.Line, aSymbol.Column);
end;

procedure AddUniqueTargetSymbolRef(
  const aTargets: TSnapshotReferenceTargetMap;
  const aAmbiguous: TDictionary<string, Byte>; const aKey: string;
  const aRef: TSemanticSymbolRef);
begin
  if aKey = '' then
    Exit;
  if aAmbiguous.ContainsKey(aKey) then
    Exit;

  if aTargets.ContainsKey(aKey) then
  begin
    aTargets.Remove(aKey);
    aAmbiguous.Add(aKey, 0);
  end else begin
    aTargets.Add(aKey, aRef);
  end;
end;

function BuildUniqueTargetSymbolsByName(
  const aSnapshots: TArray<TDelphiProjectSnapshot>): TSnapshotReferenceTargetMap;
var
  i: Integer;
  lAmbiguous: TDictionary<string, Byte>;
  lKey: string;
  lRef: TSemanticSymbolRef;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lUnit: TUnitSnapshot;
begin
  Result := TSnapshotReferenceTargetMap.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lAmbiguous := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for i := 0 to High(aSnapshots) do
    begin
      lSnapshot := aSnapshots[i];
      if (lSnapshot = nil) or (lSnapshot.UnitCount <> 1) then
        Continue;
      lUnit := lSnapshot.UnitByIndex(0);
      for lSymbolId := 1 to TSemanticSymbolId(lUnit.SymbolCount) do
      begin
        lSymbol := lUnit.SymbolById(lSymbolId);
        lRef.UnitId := lUnit.UnitId;
        lRef.SymbolId := lSymbol.Id;
        lKey := TargetSymbolKeyFromSnapshot(lSnapshot, lUnit.UnitId, lSymbol);
        AddUniqueTargetSymbolRef(Result, lAmbiguous, lKey, lRef);
        lKey := TargetNameKey(lUnit.UnitId, lSnapshot.TextOf(lSymbol.NameId));
        AddUniqueTargetSymbolRef(Result, lAmbiguous, lKey, lRef);
      end;
    end;
  finally
    lAmbiguous.Free;
  end;
end;

function BuildOriginalTargetUnitsById(
  const aSnapshots: TArray<TDelphiProjectSnapshot>): TDictionary<Integer, TOriginalTargetUnit>;
var
  i: Integer;
  lOriginal: TOriginalTargetUnit;
begin
  Result := TDictionary<Integer, TOriginalTargetUnit>.Create;
  for i := 0 to High(aSnapshots) do
    if (aSnapshots[i] <> nil) and (aSnapshots[i].UnitCount = 1) then
    begin
      lOriginal.Snapshot := aSnapshots[i];
      lOriginal.UnitSnapshot := aSnapshots[i].UnitByIndex(0);
      if not Result.ContainsKey(Integer(lOriginal.UnitSnapshot.UnitId)) then
        Result.Add(Integer(lOriginal.UnitSnapshot.UnitId), lOriginal);
    end;
end;

function TryOriginalTargetSymbol(
  const aOriginalUnitsById: TDictionary<Integer, TOriginalTargetUnit>;
  const aReference: TSemanticReferenceFact; out aSnapshot: TDelphiProjectSnapshot;
  out aSymbol: TSemanticSymbolFact): Boolean;
var
  lOriginal: TOriginalTargetUnit;
begin
  aSnapshot := nil;
  aSymbol := Default(TSemanticSymbolFact);
  if (aOriginalUnitsById = nil) or (aReference.TargetUnitId = 0) or
    (aReference.TargetSymbolId = 0) or
    not aOriginalUnitsById.TryGetValue(Integer(aReference.TargetUnitId), lOriginal) or
    (Integer(aReference.TargetSymbolId) > lOriginal.UnitSnapshot.SymbolCount) then
    Exit(False);

  aSnapshot := lOriginal.Snapshot;
  aSymbol := lOriginal.UnitSnapshot.SymbolById(aReference.TargetSymbolId);
  Result := True;
end;

function RemapReferenceFactWithResolvedTargets(const aSourceStrings,
  aTargetStrings: TSemanticStringPool; const aReference: TSemanticReferenceFact;
  const aOriginalUnitsById: TDictionary<Integer, TOriginalTargetUnit>;
  const aTargetSymbolsByName: TSnapshotReferenceTargetMap):
  TSemanticReferenceFact;
var
  lKey: string;
  lReferenceName: string;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lTargetRef: TSemanticSymbolRef;
begin
  Result := RemapReferenceFact(aSourceStrings, aTargetStrings, aReference);
  if (aReference.TargetUnitId = 0) or (aReference.TargetSymbolId = 0) then
    Exit;

  if TryOriginalTargetSymbol(aOriginalUnitsById, aReference, lSnapshot, lSymbol) then
  begin
    lKey := TargetSymbolKeyFromSnapshot(lSnapshot, aReference.TargetUnitId, lSymbol);
    if aTargetSymbolsByName.TryGetValue(lKey, lTargetRef) then
    begin
      Result.TargetUnitId := lTargetRef.UnitId;
      Result.TargetSymbolId := lTargetRef.SymbolId;
      Exit;
    end;
  end;

  lReferenceName := aSourceStrings.TextOf(aReference.NameId);
  lKey := TargetNameKey(aReference.TargetUnitId, lReferenceName);
  if aTargetSymbolsByName.TryGetValue(lKey, lTargetRef) then
  begin
    Result.TargetUnitId := lTargetRef.UnitId;
    Result.TargetSymbolId := lTargetRef.SymbolId;
  end else begin
    Result.TargetUnitId := 0;
    Result.TargetSymbolId := 0;
  end;
end;

function RemapUnitSnapshot(const aSourceStrings, aTargetStrings: TSemanticStringPool;
  const aSourceExactStrings, aTargetExactStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot):
  TUnitSnapshot;
var
  lReferenceId: TSemanticReferenceId;
  lSymbolId: TSemanticSymbolId;
  lWithId: TSemanticWithId;
begin
  Result := TUnitSnapshot.Create(aUnit.UnitId, RemapStringId(aSourceStrings,
    aTargetStrings, aUnit.FileNameId), RemapStringId(aSourceStrings,
    aTargetStrings, aUnit.UnitNameId), RemapStringId(aSourceExactStrings,
    aTargetExactStrings, aUnit.SourceTextId));
  try
    for lSymbolId := 1 to TSemanticSymbolId(aUnit.SymbolCount) do
      Result.AddSymbol(RemapSymbolFact(aSourceStrings, aTargetStrings,
        aUnit.SymbolById(lSymbolId)));
    for lWithId := 1 to TSemanticWithId(aUnit.WithStatementCount) do
      Result.AddWithStatement(RemapWithFact(aSourceStrings, aTargetStrings,
        aUnit.WithStatementById(lWithId)));
    for lReferenceId := 1 to TSemanticReferenceId(aUnit.ReferenceCount) do
      Result.AddReference(RemapReferenceFact(aSourceStrings, aTargetStrings,
        aUnit.ReferenceById(lReferenceId)));
  except
    Result.Free;
    raise;
  end;
end;

function RemapUnitSnapshotWithResolvedTargets(const aSourceStrings,
  aTargetStrings: TSemanticStringPool; const aSourceExactStrings,
  aTargetExactStrings: TSemanticStringPool; const aUnit: TUnitSnapshot;
  const aOriginalUnitsById: TDictionary<Integer, TOriginalTargetUnit>;
  const aTargetSymbolsByName: TSnapshotReferenceTargetMap):
  TUnitSnapshot;
var
  lReferenceId: TSemanticReferenceId;
  lSymbolId: TSemanticSymbolId;
  lWithId: TSemanticWithId;
begin
  Result := TUnitSnapshot.Create(aUnit.UnitId, RemapStringId(aSourceStrings,
    aTargetStrings, aUnit.FileNameId), RemapStringId(aSourceStrings,
    aTargetStrings, aUnit.UnitNameId), RemapStringId(aSourceExactStrings,
    aTargetExactStrings, aUnit.SourceTextId));
  try
    for lSymbolId := 1 to TSemanticSymbolId(aUnit.SymbolCount) do
      Result.AddSymbol(RemapSymbolFact(aSourceStrings, aTargetStrings,
        aUnit.SymbolById(lSymbolId)));
    for lWithId := 1 to TSemanticWithId(aUnit.WithStatementCount) do
      Result.AddWithStatement(RemapWithFact(aSourceStrings, aTargetStrings,
        aUnit.WithStatementById(lWithId)));
    for lReferenceId := 1 to TSemanticReferenceId(aUnit.ReferenceCount) do
      Result.AddReference(RemapReferenceFactWithResolvedTargets(aSourceStrings,
        aTargetStrings, aUnit.ReferenceById(lReferenceId), aOriginalUnitsById,
        aTargetSymbolsByName));
  except
    Result.Free;
    raise;
  end;
end;

function CloneSnapshotStrings(const aSnapshot: TDelphiProjectSnapshot): TSemanticStringPool;
var
  i: Cardinal;
begin
  Result := TSemanticStringPool.Create;
  try
    for i := 1 to aSnapshot.StringCount do
      Result.Intern(aSnapshot.TextOf(TSemanticStringId(i)));
  except
    Result.Free;
    raise;
  end;
end;

function CloneSnapshotExactStrings(const aSnapshot: TDelphiProjectSnapshot):
  TSemanticStringPool;
var
  i: Cardinal;
begin
  Result := TSemanticStringPool.Create(True);
  try
    for i := 1 to aSnapshot.ExactStringCount do
      Result.Intern(aSnapshot.ExactTextOf(TSemanticStringId(i)));
  except
    Result.Free;
    raise;
  end;
end;

procedure AddSequentialSnapshotUnit(const aBuilder: TDelphiProjectSnapshotBuilder;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  var aMetrics: TDelphiSnapshotBuilderMetrics);
var
  lUnit: TUnitSnapshot;
  lUnitMetrics: TSnapshotUnitBuildResult;
begin
  lUnitMetrics := Default(TSnapshotUnitBuildResult);
  lUnit := CreateSnapshotUnitModel(aBuilder.Strings, aBuilder.ExactStrings, aModel, aUnitId,
    aReferenceTargetLookup, lUnitMetrics);
  try
    aBuilder.AddUnit(lUnit);
    lUnit := nil;
    Inc(aMetrics.UnitCount);
    Inc(aMetrics.SymbolCount, lUnitMetrics.SymbolCount);
    Inc(aMetrics.ReferenceCount, lUnitMetrics.ReferenceCount);
    Inc(aMetrics.WithStatementCount, lUnitMetrics.WithStatementCount);
  finally
    lUnit.Free;
  end;
end;

function BuildSequentialProjectSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  var aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lMergeStopwatch: TStopwatch;
  lPlanningFacts: TSemanticRemoveWithPlanningFacts;
  lWorkerStopwatch: TStopwatch;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    aMetrics.WorkerCount := 0;
    if Length(aModels) > 0 then
      aMetrics.WorkerCount := 1;

    lWorkerStopwatch := TStopwatch.StartNew;
    try
      for i := 0 to High(aModels) do
        AddSequentialSnapshotUnit(lBuilder, aModels[i], TSemanticUnitId(i + 1),
          aReferenceTargetLookup, aMetrics);
    finally
      lWorkerStopwatch.Stop;
      aMetrics.ParseExtractMilliseconds := lWorkerStopwatch.ElapsedMilliseconds;
    end;

    lMergeStopwatch := TStopwatch.StartNew;
    try
      lPlanningFacts := CreateRemoveWithPlanningFacts(lBuilder.ExactStrings,
        aRemoveWithFacts);
      lBuilder.SetRemoveWithPlanningFactsOwned(lPlanningFacts);
      aMetrics.DeterministicFactCount := aMetrics.UnitCount + aMetrics.SymbolCount +
        aMetrics.ReferenceCount + aMetrics.WithStatementCount;
      Result := lBuilder.Build;
    finally
      lMergeStopwatch.Stop;
      aMetrics.MergeMilliseconds := lMergeStopwatch.ElapsedMilliseconds;
    end;
  finally
    lBuilder.Free;
  end;
end;

function BuildUnitResult(const aModel: TDelphiSemanticUnitModel;
  const aUnitId: TSemanticUnitId;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup):
  TSnapshotUnitBuildResult;
begin
  Result := Default(TSnapshotUnitBuildResult);
  Result.Strings := TSemanticStringPool.Create;
  Result.ExactStrings := TSemanticStringPool.Create(True);
  try
    Result.UnitSnapshot := CreateSnapshotUnitModel(Result.Strings, Result.ExactStrings,
      aModel, aUnitId, aReferenceTargetLookup, Result);
    Result.UnitCount := 1;
  except
    Result.UnitSnapshot.Free;
    Result.ExactStrings.Free;
    Result.Strings.Free;
    Result := Default(TSnapshotUnitBuildResult);
    raise;
  end;
end;

procedure CopyWorkerMetrics(const aWorkerMetrics: TSnapshotWorkerPipelineMetrics;
  var aMetrics: TDelphiSnapshotBuilderMetrics);
begin
  aMetrics.WorkerCount := aWorkerMetrics.WorkerCount;
  aMetrics.QueueMilliseconds := aWorkerMetrics.QueueMilliseconds;
  aMetrics.ParseExtractMilliseconds := aWorkerMetrics.ParseExtractMilliseconds;
end;

function BuildUnitResults(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  const aWorkerCount: Integer; var aMetrics: TDelphiSnapshotBuilderMetrics):
  TArray<TSnapshotUnitBuildResult>;
var
  lWorkerMetrics: TSnapshotWorkerPipelineMetrics;
begin
  Result := BuildSnapshotUnitResults(aModels, aReferenceTargetLookup,
    aWorkerCount, BuildUnitResult, lWorkerMetrics);
  CopyWorkerMetrics(lWorkerMetrics, aMetrics);
end;

function MergeUnitResults(
  const aResults: TArray<TSnapshotUnitBuildResult>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  var aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lMergedUnit: TUnitSnapshot;
  lPlanningFacts: TSemanticRemoveWithPlanningFacts;
  lStopwatch: TStopwatch;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lStopwatch := TStopwatch.StartNew;
  try
    for i := 0 to High(aResults) do
    begin
      lMergedUnit := RemapUnitSnapshot(aResults[i].Strings, lBuilder.Strings,
        aResults[i].ExactStrings, lBuilder.ExactStrings, aResults[i].UnitSnapshot);
      try
        lBuilder.AddUnit(lMergedUnit);
        lMergedUnit := nil;
      finally
        lMergedUnit.Free;
      end;

      Inc(aMetrics.UnitCount, aResults[i].UnitCount);
      Inc(aMetrics.SymbolCount, aResults[i].SymbolCount);
      Inc(aMetrics.ReferenceCount, aResults[i].ReferenceCount);
      Inc(aMetrics.WithStatementCount, aResults[i].WithStatementCount);
    end;
    lPlanningFacts := CreateRemoveWithPlanningFacts(lBuilder.ExactStrings,
      aRemoveWithFacts);
    lBuilder.SetRemoveWithPlanningFactsOwned(lPlanningFacts);
    aMetrics.DeterministicFactCount := aMetrics.UnitCount + aMetrics.SymbolCount +
      aMetrics.ReferenceCount + aMetrics.WithStatementCount;
    Result := lBuilder.Build;
  finally
    lStopwatch.Stop;
    aMetrics.MergeMilliseconds := lStopwatch.ElapsedMilliseconds;
    lBuilder.Free;
  end;
end;

function BuildProjectSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aOptions: TDelphiSnapshotBuildOptions;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  lReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  lResults: TArray<TSnapshotUnitBuildResult>;
  lStopwatch: TStopwatch;
begin
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lReferenceTargetLookup := Default(TSnapshotReferenceTargetLookup);
  lResults := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    if aOptions.ResolveReferenceTargets then
      lReferenceTargetLookup := BuildSnapshotReferenceTargets(aModels);
    if aOptions.WorkerCount <= 1 then
      Result := BuildSequentialProjectSnapshotFromModels(aModels, aRemoveWithFacts,
        lReferenceTargetLookup, aMetrics)
    else begin
      lResults := BuildUnitResults(aModels, lReferenceTargetLookup,
        aOptions.WorkerCount, aMetrics);
      Result := MergeUnitResults(lResults, aRemoveWithFacts, aMetrics);
    end;
  finally
    lStopwatch.Stop;
    aMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    FreeSnapshotUnitBuildResults(lResults);
  end;
end;

function BuildProjectUnitSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aModelUnitIds: TArray<TSemanticUnitId>; const aModelIndex: Integer;
  const aReferenceSnapshots: TArray<TDelphiProjectSnapshot>;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot; overload;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  lResults: TArray<TSnapshotUnitBuildResult>;
  lStopwatch: TStopwatch;
begin
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lReferenceTargetLookup := Default(TSnapshotReferenceTargetLookup);
  lResults := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    lReferenceTargetLookup := BuildSnapshotReferenceTargetsForModelsAndSnapshots(aModels,
      aModelUnitIds, aReferenceSnapshots);
    SetLength(lResults, 1);
    lResults[0] := BuildUnitResult(aModels[aModelIndex],
      ModelUnitIdAt(aModelUnitIds, aModelIndex), lReferenceTargetLookup);
    Result := MergeUnitResults(lResults, lFacts, aMetrics);
  finally
    lStopwatch.Stop;
    aMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    FreeSnapshotUnitBuildResults(lResults);
  end;
end;

function BuildProjectUnitSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>; const aModelIndex: Integer;
  const aUnitId: TSemanticUnitId; out aMetrics: TDelphiSnapshotBuilderMetrics):
  TDelphiProjectSnapshot; overload;
var
  i: Integer;
  lModelUnitIds: TArray<TSemanticUnitId>;
begin
  SetLength(lModelUnitIds, Length(aModels));
  for i := 0 to High(lModelUnitIds) do
    lModelUnitIds[i] := TSemanticUnitId(i + 1);
  if (aModelIndex >= 0) and (aModelIndex <= High(lModelUnitIds)) then
    lModelUnitIds[aModelIndex] := aUnitId;

  Result := BuildProjectUnitSnapshotFromModels(aModels, lModelUnitIds, aModelIndex,
    [], aMetrics);
end;

function BuildProjectSnapshotFromUnitSnapshots(
  const aSnapshots: TArray<TDelphiProjectSnapshot>;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lMergedUnit: TUnitSnapshot;
  lSourceExactStrings: TSemanticStringPool;
  lSourceStrings: TSemanticStringPool;
  lStopwatch: TStopwatch;
  lOriginalUnitsById: TDictionary<Integer, TOriginalTargetUnit>;
  lTargetSymbolsByName: TSnapshotReferenceTargetMap;
  lUnit: TUnitSnapshot;
begin
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lOriginalUnitsById := nil;
  lTargetSymbolsByName := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    lOriginalUnitsById := BuildOriginalTargetUnitsById(aSnapshots);
    lTargetSymbolsByName := BuildUniqueTargetSymbolsByName(aSnapshots);
    for i := 0 to High(aSnapshots) do
    begin
      if (aSnapshots[i] = nil) or (aSnapshots[i].UnitCount <> 1) then
        raise Exception.Create('Project snapshot merge requires one-unit snapshot inputs.');

      lUnit := aSnapshots[i].UnitByIndex(0);
      lSourceStrings := CloneSnapshotStrings(aSnapshots[i]);
      lSourceExactStrings := nil;
      try
        lSourceExactStrings := CloneSnapshotExactStrings(aSnapshots[i]);
        lMergedUnit := RemapUnitSnapshotWithResolvedTargets(lSourceStrings,
          lBuilder.Strings, lSourceExactStrings, lBuilder.ExactStrings, lUnit,
          lOriginalUnitsById, lTargetSymbolsByName);
        try
          lBuilder.AddUnit(lMergedUnit);
          lMergedUnit := nil;
        finally
          lMergedUnit.Free;
        end;
      finally
        lSourceExactStrings.Free;
        lSourceStrings.Free;
      end;

      Inc(aMetrics.UnitCount);
      Inc(aMetrics.SymbolCount, lUnit.SymbolCount);
      Inc(aMetrics.ReferenceCount, lUnit.ReferenceCount);
      Inc(aMetrics.WithStatementCount, lUnit.WithStatementCount);
    end;
    aMetrics.DeterministicFactCount := aMetrics.UnitCount + aMetrics.SymbolCount +
      aMetrics.ReferenceCount + aMetrics.WithStatementCount;
    aMetrics.WorkerCount := 0;
    Result := lBuilder.Build;
  finally
    lStopwatch.Stop;
    aMetrics.MergeMilliseconds := lStopwatch.ElapsedMilliseconds;
    aMetrics.BuildMilliseconds := aMetrics.MergeMilliseconds;
    lOriginalUnitsById.Free;
    lTargetSymbolsByName.Free;
    lBuilder.Free;
  end;
end;

function BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiProjectSnapshot;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lPlanningFacts: TSemanticRemoveWithPlanningFacts;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lPlanningFacts := CreateRemoveWithPlanningFacts(lBuilder.ExactStrings,
      aFacts);
    lBuilder.SetRemoveWithPlanningFactsOwned(lPlanningFacts);
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

end.
