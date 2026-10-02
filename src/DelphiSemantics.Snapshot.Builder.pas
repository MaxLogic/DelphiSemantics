unit DelphiSemantics.Snapshot.Builder;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Workers,
  DelphiSemantics.WithBinding;

type
  TDelphiSnapshotImportBindingComparison = record
    Complete: Boolean;
    Preserved: Boolean;
    ReferenceCount: Integer;
    Reason: string;
  end;

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
function BuildProjectSnapshotFromModelsWithExtension(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aOptions: TDelphiSnapshotBuildOptions;
  const aExtensionName: string; var aOwnedExtension: TObject;
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

function ResolveSnapshotReferenceTargets(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel): TArray<TSemanticSymbolRef>;

function CompareSnapshotImportBindings(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel;
  const aInterfaceImports, aImplementationImports: TArray<string>):
  TDelphiSnapshotImportBindingComparison;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.IOUtils,
  System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils,
  DelphiSemantics.Model.Text, DelphiSemantics.RemoveWith.Visibility, DelphiSemantics.Snapshot.RemoveWith;

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
  // Pseudo entries in the by-name map; '#' never starts a Delphi identifier.
  cSnapshotUsesKeyPrefix = '#uses|';
  cSnapshotHelperKeyPrefix = '#helper|';
  cSnapshotMaxNameResolutionDepth = 8;
  cSnapshotMaxTypeChainDepth = 32;

type
  TSnapshotTargetSymbol = record
    Ref: TSemanticSymbolRef;
    Name: string;
    Kind: string;
    OwnerName: string;
    UnitName: string;
    SectionKind: string;
    Signature: string;
    RoutineScopeId: string;
    Line: Integer;
    Column: Integer;
    IsRoutineFact: Boolean;
    // Declared type text of a variable, parameter, field or property; the type kind
    // (class, record, interface, ...) of a type declaration.
    TypeName: string;
    // Declared ancestor of a class or interface type. Only unit models carry it, so BaseKnown
    // stays False for symbols read back from a snapshot.
    BaseTypeName: string;
    BaseKnown: Boolean;
    // False when the declaring unit's syntax facts are unverified (scope status other than ast).
    UnitVerified: Boolean;
    // Sanitized source of a class, record or interface type from its name to its matching end.
    // Members the model does not record (constants, nested types) can only occur in it, so a
    // name absent from this text is proven not to be declared by the type. Empty when unknown.
    DeclarationText: string;
  end;

  // DS-652: proves member access through a typed receiver, Self, an ancestor or a with selector.
  // smlAbsent is returned only when the complete member set of the type chain is known.
  TSnapshotMemberLookup = (smlFound, smlAbsent, smlUnknown);

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
    if (lRoutine.Line <= 0) or (lRoutine.Line > aLine) or
      ((lRoutine.EndLine > 0) and (aLine > lRoutine.EndLine)) then
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

function SnapshotIncludesDeclaration(
  const aDeclaration: TDelphiSemanticDeclaration): Boolean;
begin
  Result := SameText(aDeclaration.DeclarationRole, 'declaration') and
    SameText(aDeclaration.ScopeKind, 'unit');
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

function SnapshotUnitStatusVerified(const aScopeStatus: string): Boolean;
begin
  // Hand-built facts without scope metadata are left to their builder, as in Usage.
  Result := (aScopeStatus = '') or SameText(aScopeStatus, 'ast');
end;

procedure AddSnapshotPseudoSymbol(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aKey, aName, aSectionKind: string);
var
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  if aName = '' then
    Exit;
  lSymbol := Default(TSnapshotTargetSymbol);
  lSymbol.Name := aName;
  lSymbol.SectionKind := aSectionKind;
  if not aSymbolsByName.TryGetValue(aKey, lSymbols) then
  begin
    lSymbols := TSnapshotTargetSymbolList.Create;
    try
      aSymbolsByName.Add(aKey, lSymbols);
    except
      lSymbols.Free;
      raise;
    end;
  end;
  lSymbols.Add(lSymbol);
end;

procedure AddSnapshotTargetSymbol(const aSymbols: TSnapshotTargetSymbolList;
  const aSymbolsByName: TSnapshotTargetSymbolsByName; const aUnitName, aKind,
  aOwnerName, aName, aSectionKind, aSignature, aRoutineScopeId, aTypeName,
  aBaseTypeName, aDeclarationText: string; const aUnitVerified: Boolean;
  const aUnitId: TSemanticUnitId; const aLine, aColumn: Integer;
  const aIsRoutineFact: Boolean; var aNextSymbolId: TSemanticSymbolId);
var
  lSymbol: TSnapshotTargetSymbol;
begin
  Inc(aNextSymbolId);
  if aName = '' then
    Exit;

  lSymbol := Default(TSnapshotTargetSymbol);
  lSymbol.DeclarationText := aDeclarationText;
  lSymbol.TypeName := Trim(aTypeName);
  lSymbol.BaseTypeName := Trim(aBaseTypeName);
  lSymbol.BaseKnown := True;
  lSymbol.UnitVerified := aUnitVerified;
  lSymbol.Ref.UnitId := aUnitId;
  lSymbol.Ref.SymbolId := aNextSymbolId;
  lSymbol.Name := aName;
  lSymbol.Kind := aKind;
  lSymbol.OwnerName := aOwnerName;
  lSymbol.UnitName := aUnitName;
  lSymbol.SectionKind := aSectionKind;
  lSymbol.Signature := aSignature;
  lSymbol.RoutineScopeId := aRoutineScopeId;
  lSymbol.Line := aLine;
  lSymbol.Column := aColumn;
  lSymbol.IsRoutineFact := aIsRoutineFact;
  aSymbols.Add(lSymbol);
  AddTargetSymbolByName(aSymbolsByName, lSymbol);
end;

function SnapshotTextOffset(const aText: string; const aLine, aColumn: Integer): Integer;
var
  i: Integer;
  lLine: Integer;
begin
  Result := 0;
  if (aLine <= 0) or (aColumn <= 0) then
    Exit;
  lLine := 1;
  i := 1;
  while (lLine < aLine) and (i <= Length(aText)) do
  begin
    if aText[i] = #10 then
      Inc(lLine);
    Inc(i);
  end;
  if (lLine = aLine) and (i + aColumn - 1 <= Length(aText)) then
    Result := i + aColumn - 1;
end;

function SnapshotNextWord(const aText: string; aIndex: Integer): string;
var
  lStart: Integer;
begin
  while (aIndex <= Length(aText)) and CharInSet(aText[aIndex], [#9, #10, #13, ' ']) do
    Inc(aIndex);
  lStart := aIndex;
  while (aIndex <= Length(aText)) and IsIdentifierChar(aText[aIndex]) do
    Inc(aIndex);
  Result := Copy(aText, lStart, aIndex - lStart);
end;

// The sanitized text of a structured type from its name to the end that closes it. A body the
// scan cannot delimit (class of, a forward declaration, a statement ending before any body
// opens, an unmatched end) yields '' so member absence stays unknown.
function SnapshotTypeBodyText(const aSanitized: string; const aOffset: Integer): string;
var
  i: Integer;
  lDepth: Integer;
  lOpened: Boolean;
  lPrevious: string;
  lStart: Integer;
  lWord: string;
begin
  Result := '';
  if aOffset <= 0 then
    Exit;
  i := aOffset;
  lDepth := 0;
  lOpened := False;
  lPrevious := '';
  while i <= Length(aSanitized) do
  begin
    if not IsIdentifierStart(aSanitized[i]) then
    begin
      // The declaration ended before a body opened: class of, a forward or an alias.
      if (aSanitized[i] = ';') and not lOpened then
        Exit('');
      Inc(i);
      Continue;
    end;
    lStart := i;
    while (i <= Length(aSanitized)) and IsIdentifierChar(aSanitized[i]) do
      Inc(i);
    // An escaped identifier (&End) is never a keyword.
    if (lStart > 1) and (aSanitized[lStart - 1] = '&') then
      Continue;
    lWord := Copy(aSanitized, lStart, i - lStart);
    if SameText(lWord, 'end') then
    begin
      if not lOpened then
        Exit('');
      Dec(lDepth);
      if lOpened and (lDepth <= 0) then
        Exit(Copy(aSanitized, aOffset, i - aOffset));
    end else if MatchText(lWord, ['record', 'interface', 'dispinterface']) or
      (SameText(lWord, 'object') and not SameText(lPrevious, 'of')) or
      (SameText(lWord, 'class') and not MatchText(SnapshotNextWord(aSanitized, i),
      ['function', 'procedure', 'var', 'threadvar', 'property', 'operator', 'constructor',
      'destructor', 'of']) and not ((SnapshotNextWord(aSanitized, i) = '') and
      (Pos(';', TrimLeft(Copy(aSanitized, i, 8))) = 1))) then
    begin
      Inc(lDepth);
      lOpened := True;
    end;
    lPrevious := lWord;
  end;
  // The body never closed.
  Result := '';
end;

// True when the raw text holds an include directive ({$I file}, {$INCLUDE file}, or the (*$ *)
// form). {$I+} and {$I-} are the I/O checking switch, not includes.
function SnapshotTextHasIncludeDirective(const aRawText: string): Boolean;
var
  i: Integer;
  lAfter: Integer;
  lUpper: string;
begin
  lUpper := UpperCase(aRawText);
  i := PosEx('$I', lUpper, 1);
  while i > 0 do
  begin
    if ((i > 1) and (lUpper[i - 1] = '{')) or ((i > 2) and (lUpper[i - 1] = '*') and
      (lUpper[i - 2] = '(')) then
    begin
      lAfter := i + 2;
      if Copy(lUpper, lAfter, 6) = 'NCLUDE' then
        Inc(lAfter, 6);
      if (lAfter <= Length(lUpper)) and CharInSet(lUpper[lAfter], [#9, #10, #13, ' ', '''']) then
        Exit(True);
    end;
    i := PosEx('$I', lUpper, i + 2);
  end;
  Result := False;
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
  lDeclarationOffset: Integer;
  lDeclarationText: string;
  lSanitized: string;
  lSymbolId: TSemanticSymbolId;
  lUsedUnit: string;
  lVerified: Boolean;
begin
  lSymbolId := 0;
  lSanitized := '';
  lVerified := SnapshotUnitStatusVerified(aModel.ScopeModelStatus);
  for lDeclaration in aModel.Declarations do
  begin
    if not SnapshotIncludesDeclaration(lDeclaration) then
      Continue;
    if SameText(SnapshotDeclarationKind(lDeclaration.Kind), cSnapshotSymbolKindRoutine) then
      Continue;
    lDeclarationText := '';
    if SameText(lDeclaration.Kind, 'type') and MatchText(lDeclaration.TypeName,
      ['class', 'record', 'interface']) then
    begin
      if lSanitized = '' then
        lSanitized := SanitizeCodeText(aModel.SourceText);
      lDeclarationOffset := SnapshotTextOffset(lSanitized, lDeclaration.Line,
        lDeclaration.Column);
      lDeclarationText := SnapshotTypeBodyText(lSanitized, lDeclarationOffset);
      // Sanitizing keeps both branches of conditional code, but an included file's members
      // are not in this text at all, so their absence cannot be proven.
      if SnapshotTextHasIncludeDirective(Copy(aModel.SourceText, lDeclarationOffset,
        Length(lDeclarationText))) then
        lDeclarationText := '';
    end;
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      SnapshotDeclarationKind(lDeclaration.Kind), '', lDeclaration.Name,
      lDeclaration.SectionKind, '', '', lDeclaration.TypeName, lDeclaration.BaseTypeName,
      lDeclarationText, lVerified, aUnitId, lDeclaration.Line, lDeclaration.Column, False,
      lSymbolId);
    // A helper adds members to its target, so member absence on that target is unprovable.
    if lDeclaration.HelperTargetName <> '' then
      AddSnapshotPseudoSymbol(aSymbolsByName, cSnapshotHelperKeyPrefix +
        lDeclaration.HelperTargetName, lDeclaration.Name, lDeclaration.SectionKind);
  end;
  for lMember in aModel.Members do
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      lMember.Kind, lMember.OwnerName, lMember.Name, '', lMember.Signature, '',
      lMember.TypeName, '', '', lVerified, aUnitId, lMember.Line, lMember.Column, False,
      lSymbolId);
  for lRoutine in aModel.Routines do
  begin
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      cSnapshotSymbolKindRoutine, lRoutine.OwnerName, lRoutine.Name,
      lRoutine.SectionKind, lRoutine.Signature, lRoutine.ScopeId, lRoutine.ReturnType, '',
      '', lVerified, aUnitId, lRoutine.Line, lRoutine.Column, True, lSymbolId);
    for lParameter in lRoutine.Parameters do
      AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
        cSnapshotSymbolKindParameter, SnapshotRoutineName(lRoutine),
        lParameter.Name, lRoutine.SectionKind, lRoutine.Signature, lRoutine.ScopeId,
        lParameter.TypeName, '', '', lVerified, aUnitId, lParameter.Line, lParameter.Column,
        False, lSymbolId);
  end;
  for lLocal in aModel.Locals do
    AddSnapshotTargetSymbol(aSymbols, aSymbolsByName, aModel.UnitName,
      lLocal.Kind, lLocal.RoutineName, lLocal.Name, '', '', lLocal.RoutineScopeId,
      lLocal.TypeName, '', '', lVerified, aUnitId, lLocal.Line, lLocal.Column, False,
      lSymbolId);
  // Type names in this unit resolve through its own uses clauses.
  for lUsedUnit in aModel.InterfaceUses do
    AddSnapshotPseudoSymbol(aSymbolsByName, cSnapshotUsesKeyPrefix + aModel.UnitName,
      lUsedUnit, 'interface');
  for lUsedUnit in aModel.ImplementationUses do
    AddSnapshotPseudoSymbol(aSymbolsByName, cSnapshotUsesKeyPrefix + aModel.UnitName,
      lUsedUnit, 'implementation');
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
      if (lSymbol.OwnerName = '') and not SameText(lKind, cSnapshotSymbolKindRoutine) then
        lSymbol.OwnerName := aSnapshot.TextOf(lFact.RoutineId);
      lSymbol.UnitName := aSnapshot.TextOf(lUnit.UnitNameId);
      lSymbol.SectionKind := aSnapshot.TextOf(lFact.SectionKindId);
      lSymbol.Signature := aSnapshot.TextOf(lFact.SignatureId);
      lSymbol.RoutineScopeId := aSnapshot.TextOf(lFact.RoutineScopeId);
      lSymbol.Line := lFact.Line;
      lSymbol.Column := lFact.Column;
      lSymbol.IsRoutineFact := SameText(lKind, cSnapshotSymbolKindRoutine);
      lSymbol.TypeName := Trim(aSnapshot.TextOf(lFact.TypeId));
      lSymbol.UnitVerified := SnapshotUnitStatusVerified(
        aSnapshot.TextOf(lUnit.ScopeModelStatusId));
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
  Result := NormalizeRoutineSignature(aSignature);
end;

function SnapshotLocalSymbolMatchesReference(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference; const aRoutineSignature: string;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
begin
  Result := SameText(aSymbol.UnitName, aModel.UnitName) and
    SnapshotLocalSymbolKind(aSymbol.Kind);
  if Result and (aReference.RoutineScopeId <> '') and
    (aSymbol.RoutineScopeId <> '') then
    Exit(SameText(aSymbol.RoutineScopeId, aReference.RoutineScopeId))
  else if Result then
    Result := SameText(aSymbol.OwnerName, aReference.RoutineName);
  if Result and (aRoutineSignature <> '') and (aSymbol.Signature <> '') then
    Result := (NormalizeSnapshotSignature(aSymbol.Signature) = aRoutineSignature);
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

  if (aLeft.RoutineScopeId <> '') and (aRight.RoutineScopeId <> '') then
    Exit(SameText(aLeft.RoutineScopeId, aRight.RoutineScopeId));

  Result := (NormalizeSnapshotSignature(aLeft.Signature) =
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
  const aModel: TDelphiSemanticUnitModel; const aRoutineName,
  aRoutineScopeId: string;
  out aRoutineRef: TSemanticSymbolRef; out aRoutineSignature: string;
  out aAmbiguous: Boolean): Boolean;
var
  lCount: Integer;
  lScopeId: string;
  lSignature: string;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  aRoutineRef := Default(TSemanticSymbolRef);
  aRoutineSignature := '';
  aAmbiguous := False;
  lCount := 0;
  lSignature := '';
  lScopeId := '';
  if not aSymbolsByName.TryGetValue(SnapshotRoutineSimpleName(aRoutineName),
    lSymbols) then
    Exit(False);

  for lSymbol in lSymbols do
    if SameText(lSymbol.UnitName, aModel.UnitName)
      and SameText(lSymbol.Kind, cSnapshotSymbolKindRoutine)
      and lSymbol.IsRoutineFact
      and SameText(SnapshotQualifiedRoutineName(lSymbol), aRoutineName)
      and ((aRoutineScopeId = '') or (lSymbol.RoutineScopeId = '') or
      SameText(lSymbol.RoutineScopeId, aRoutineScopeId)) then
    begin
      if lCount = 0 then
      begin
        Inc(lCount);
        aRoutineRef := lSymbol.Ref;
        lScopeId := lSymbol.RoutineScopeId;
        lSignature := NormalizeSnapshotSignature(lSymbol.Signature);
        aRoutineSignature := lSignature;
      end else if (lSignature <> NormalizeSnapshotSignature(lSymbol.Signature)) and
        not ((aRoutineScopeId <> '') and (lScopeId <> '') and
        (lSymbol.RoutineScopeId <> '') and
        SameText(lScopeId, lSymbol.RoutineScopeId)) then
      begin
        Inc(lCount);
        aRoutineRef := Default(TSemanticSymbolRef);
        aAmbiguous := True;
        Exit(False);
      end;
      if lSymbol.RoutineScopeId = '' then
        lScopeId := '';
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
    aReference.RoutineName, aReference.RoutineScopeId, lRoutineRef,
    lRoutineSignature, lAmbiguousRoutine) then
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

function IsPotentialIdentifierCharacter(const c: Char): Boolean;
begin
  // Retain non-ASCII code units so unsupported Unicode cannot become an ASCII suffix.
  Result := IsIdentifierChar(c) or (Ord(c) > 127);
end;

function ReferenceIsPartialIdentifier(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): Boolean;
var
  lStart, lAfter: Integer;
begin
  Result := False;
  if aReference.Name = '' then
    Exit;
  lStart := aReference.Offset;
  if lStart < 0 then
    Exit;
  if lStart = 0 then
    lStart := 1;
  if not SameText(Copy(aModel.SourceText, lStart, Length(aReference.Name)), aReference.Name) then
    if SameText(Copy(aModel.SourceText, lStart + 1, Length(aReference.Name)), aReference.Name) then
      Inc(lStart)
    else
      Exit;
  lAfter := lStart + Length(aReference.Name);
  Result := ((lStart > 1) and IsPotentialIdentifierCharacter(aModel.SourceText[lStart - 1])) or
    ((lAfter <= Length(aModel.SourceText)) and IsPotentialIdentifierCharacter(aModel.SourceText[lAfter]));
end;

function ReferenceReceiverName(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): string;
var
  i: Integer;
  lEnd: Integer;
  lStart: Integer;
begin
  Result := '';
  lStart := aReference.Offset;
  if (lStart <= 0) or not SameText(Copy(aModel.SourceText, lStart,
    Length(aReference.Name)), aReference.Name) then
    if SameText(Copy(aModel.SourceText, lStart + 1, Length(aReference.Name)),
      aReference.Name) then
      Inc(lStart)
    else
      Exit;

  i := lStart - 1;
  while (i > 0) and CharInSet(aModel.SourceText[i], [#9, #10, #13, ' ']) do
    Dec(i);
  if not IsMemberAccessDot(aModel.SourceText, i) then
    Exit;
  Dec(i);
  while (i > 0) and CharInSet(aModel.SourceText[i], [#9, #10, #13, ' ']) do
    Dec(i);
  lEnd := i;
  while (i > 0) and IsPotentialIdentifierCharacter(aModel.SourceText[i]) do
    Dec(i);
  Result := Copy(aModel.SourceText, i + 1, lEnd - i);
end;

function OwnedSymbolIsVisibleFromReference(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference;
  const aSymbol: TSnapshotTargetSymbol): Boolean;
var
  lReceiverName: string;
  lSectionKind: string;
begin
  if aSymbol.OwnerName = '' then
    Exit(False);
  if SameText(aSymbol.Kind, 'class-var') then
  begin
    lReceiverName := ReferenceReceiverName(aModel, aReference);
    if (lReceiverName <> '') and not SameText(lReceiverName,
      aSymbol.OwnerName) then
      Exit(False);
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

function IsSnapshotPlainIdentifier(const aText: string): Boolean;
var
  c: Char;
begin
  if (aText = '') or not IsIdentifierStart(aText[1]) then
    Exit(False);
  for c in aText do
    if not IsIdentifierChar(c) then
      Exit(False);
  Result := True;
end;

function IsSnapshotMemberKind(const aKind: string): Boolean;
begin
  Result := MatchText(aKind, ['field', 'property', 'class-var', 'method']);
end;

function IsSnapshotStructuredTypeKind(const aTypeKind: string): Boolean;
begin
  Result := MatchText(aTypeKind, ['class', 'record', 'interface']);
end;

// Members every class inherits from TObject (or every interface from IInterface). A chain that
// ends at the implicit root proves only other names absent.
function IsImplicitRootMemberName(const aTypeKind, aName: string): Boolean;
begin
  if SameText(aTypeKind, 'interface') then
    Exit(MatchText(aName, ['QueryInterface', '_AddRef', '_Release']));
  Result := MatchText(aName, ['Create', 'Free', 'DisposeOf', 'Destroy', 'InitInstance',
    'CleanupInstance', 'ClassType', 'ClassName', 'ClassNameIs', 'ClassParent', 'ClassInfo',
    'InstanceSize', 'InheritsFrom', 'MethodAddress', 'MethodName', 'QualifiedClassName',
    'FieldAddress', 'GetInterface', 'GetInterfaceEntry', 'GetInterfaceTable', 'UnitName',
    'UnitScope', 'Equals', 'GetHashCode', 'ToString', 'SafeCallException',
    'AfterConstruction', 'BeforeDestruction', 'Dispatch', 'DefaultHandler', 'NewInstance',
    'FreeInstance', 'CheckDisposed', 'Disposed', 'GetDisposed']);
end;

function SnapshotSectionForSymbol(const aSymbol: TSnapshotTargetSymbol): string;
begin
  if SameText(aSymbol.SectionKind, 'interface') then
    Exit('interface');
  Result := 'implementation';
end;

function SnapshotSectionForReference(const aReference: TDelphiSemanticReference): string;
begin
  if SameText(aReference.SectionKind, 'interface') then
    Exit('interface');
  Result := 'implementation';
end;

// Unit models and snapshot facts can both describe one declaration.
function SnapshotSameDeclaration(const aLeft, aRight: TSnapshotTargetSymbol): Boolean;
begin
  Result := SameText(aLeft.UnitName, aRight.UnitName) and SameText(aLeft.Name, aRight.Name) and
    (aLeft.Line = aRight.Line) and (aLeft.Column = aRight.Column);
end;

function SnapshotRoutineOwnerName(const aRoutineName: string): string;
begin
  Result := Copy(aRoutineName, 1, LastDelimiter('.', aRoutineName) - 1);
end;

function SnapshotUnitUsesUnit(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aUnitName, aSectionKind, aUsedUnitName: string): Boolean;
var
  lUse: TSnapshotTargetSymbol;
  lUses: TSnapshotTargetSymbolList;
begin
  Result := False;
  if not aSymbolsByName.TryGetValue(cSnapshotUsesKeyPrefix + aUnitName, lUses) then
    Exit;
  for lUse in lUses do
    if SameText(lUse.Name, aUsedUnitName) and (SameText(lUse.SectionKind, 'interface') or
      SameText(aSectionKind, 'implementation')) then
      Exit(True);
end;

// Resolves a structured type name as unit aUnitName sees it: its own declarations win, else
// exactly one interface-section type of a project unit it uses. Types outside the project stay
// unresolved, so nothing is proven about their members.
function TryResolveSnapshotTypeFromUnit(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aUnitName, aSectionKind, aTypeName: string; out aType: TSnapshotTargetSymbol): Boolean;
var
  lLocal: TSnapshotTargetSymbol;
  lLocalCount: Integer;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
  lUsed: TSnapshotTargetSymbol;
  lUsedCount: Integer;
begin
  Result := False;
  aType := Default(TSnapshotTargetSymbol);
  if not IsSnapshotPlainIdentifier(aTypeName) or
    not aSymbolsByName.TryGetValue(aTypeName, lSymbols) then
    Exit;

  lLocal := Default(TSnapshotTargetSymbol);
  lUsed := Default(TSnapshotTargetSymbol);
  lLocalCount := 0;
  lUsedCount := 0;
  for lSymbol in lSymbols do
  begin
    if not SameText(lSymbol.Kind, 'type') or (lSymbol.OwnerName <> '') or
      not IsSnapshotStructuredTypeKind(lSymbol.TypeName) then
      Continue;
    if SameText(lSymbol.UnitName, aUnitName) then
    begin
      if (lLocalCount = 0) or not SnapshotSameDeclaration(lLocal, lSymbol) then
      begin
        Inc(lLocalCount);
        lLocal := lSymbol;
      end;
    end else if SameText(lSymbol.SectionKind, 'interface') and
      SnapshotUnitUsesUnit(aSymbolsByName, aUnitName, aSectionKind, lSymbol.UnitName) then
    begin
      if (lUsedCount = 0) or not SnapshotSameDeclaration(lUsed, lSymbol) then
      begin
        Inc(lUsedCount);
        lUsed := lSymbol;
      end;
    end;
  end;

  if lLocalCount > 0 then
  begin
    Result := lLocalCount = 1;
    if Result then
      aType := lLocal;
    Exit;
  end;
  Result := lUsedCount = 1;
  if Result then
    aType := lUsed;
end;

// Finds aName on aType or its project ancestors. Unverified units, helpers, overloads, types
// outside the project and inherited root members leave the answer unknown.
function LookupSnapshotTypeMember(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aType: TSnapshotTargetSymbol; const aName: string;
  out aTarget: TSemanticSymbolRef): TSnapshotMemberLookup;
var
  lBase: TSnapshotTargetSymbol;
  lCount: Integer;
  lCurrent: TSnapshotTargetSymbol;
  lDepth: Integer;
  lFound: TSnapshotTargetSymbol;
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  aTarget := Default(TSemanticSymbolRef);
  if not aSymbolsByName.TryGetValue(aName, lSymbols) then
    lSymbols := nil;
  lFound := Default(TSnapshotTargetSymbol);
  lCurrent := aType;
  for lDepth := 1 to cSnapshotMaxTypeChainDepth do
  begin
    if not lCurrent.UnitVerified or
      aSymbolsByName.ContainsKey(cSnapshotHelperKeyPrefix + lCurrent.Name) then
      Exit(smlUnknown);

    lCount := 0;
    if lSymbols <> nil then
      for lSymbol in lSymbols do
        if IsSnapshotMemberKind(lSymbol.Kind) and SameText(lSymbol.OwnerName, lCurrent.Name) and
          SameText(lSymbol.UnitName, lCurrent.UnitName) and
          ((lCount = 0) or not SnapshotSameDeclaration(lFound, lSymbol)) then
        begin
          Inc(lCount);
          lFound := lSymbol;
        end;
    if lCount = 1 then
    begin
      aTarget := lFound.Ref;
      Exit(smlFound);
    end;
    if lCount > 1 then
      Exit(smlUnknown);
    // The model records fields, properties, methods and class vars only. A constant, nested
    // type or anything else the type declares still spells the name in its declaration.
    if (lCurrent.DeclarationText = '') or
      TextContainsIdentifier(lCurrent.DeclarationText, aName) then
      Exit(smlUnknown);

    if not lCurrent.BaseKnown then
      Exit(smlUnknown);
    if (lCurrent.BaseTypeName = '') or MatchText(lCurrent.BaseTypeName, ['TObject',
      'System.TObject', 'IInterface', 'System.IInterface', 'IUnknown', 'System.IUnknown']) then
    begin
      if SameText(lCurrent.TypeName, 'record') or
        not IsImplicitRootMemberName(lCurrent.TypeName, aName) then
        Exit(smlAbsent);
      Exit(smlUnknown);
    end;
    if not TryResolveSnapshotTypeFromUnit(aSymbolsByName, lCurrent.UnitName,
      SnapshotSectionForSymbol(lCurrent), lCurrent.BaseTypeName, lBase) or
      SnapshotSameDeclaration(lBase, lCurrent) then
      Exit(smlUnknown);
    lCurrent := lBase;
  end;
  Result := smlUnknown;
end;

function TryFindSnapshotTargetSymbol(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aName: string; const aRef: TSemanticSymbolRef;
  out aSymbol: TSnapshotTargetSymbol): Boolean;
var
  lSymbol: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
begin
  aSymbol := Default(TSnapshotTargetSymbol);
  if aSymbolsByName.TryGetValue(aName, lSymbols) then
    for lSymbol in lSymbols do
      if (lSymbol.Ref.UnitId = aRef.UnitId) and (lSymbol.Ref.SymbolId = aRef.SymbolId) then
      begin
        aSymbol := lSymbol;
        Exit(True);
      end;
  Result := False;
end;

// The structured type a resolved symbol denotes: a type itself, or the declared type of a
// variable, parameter, field or property, resolved where that symbol is declared.
function TryResolveSnapshotSymbolType(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aName: string; const aRef: TSemanticSymbolRef;
  out aType: TSnapshotTargetSymbol): Boolean;
var
  lSymbol: TSnapshotTargetSymbol;
begin
  Result := False;
  aType := Default(TSnapshotTargetSymbol);
  if not TryFindSnapshotTargetSymbol(aSymbolsByName, aName, aRef, lSymbol) then
    Exit;
  if SameText(lSymbol.Kind, 'type') then
  begin
    Result := IsSnapshotStructuredTypeKind(lSymbol.TypeName);
    if Result then
      aType := lSymbol;
    Exit;
  end;
  if not MatchText(lSymbol.Kind, ['var', 'threadvar', cSnapshotSymbolKindLocal,
    cSnapshotSymbolKindParameter, 'field', 'class-var', 'property']) then
    Exit;
  Result := TryResolveSnapshotTypeFromUnit(aSymbolsByName, lSymbol.UnitName,
    SnapshotSectionForSymbol(lSymbol), lSymbol.TypeName, aType);
end;

function TryResolveSnapshotNameCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aDepth: Integer; out aTargetRef: TSemanticSymbolRef): Boolean; forward;

function SnapshotPositionInWith(const aWith: TDelphiSemanticWithStatement;
  const aLine, aColumn: Integer): Boolean;
var
  lEndColumn: Integer;
  lEndLine: Integer;
  lStartColumn: Integer;
  lStartLine: Integer;
begin
  if aWith.BodyLine > 0 then
  begin
    lStartLine := aWith.BodyLine;
    lStartColumn := aWith.BodyColumn;
    lEndLine := aWith.BodyEndLine;
    lEndColumn := aWith.BodyEndColumn;
  end else begin
    lStartLine := aWith.Line;
    lStartColumn := aWith.Column;
    lEndLine := aWith.EndLine;
    lEndColumn := aWith.EndColumn;
  end;
  if (lStartLine <= 0) or (aLine < lStartLine) or
    ((aLine = lStartLine) and (aColumn < lStartColumn)) then
    Exit(False);
  if lEndLine <= 0 then
    Exit(aLine = lStartLine);
  if (aLine > lEndLine) or ((aLine = lEndLine) and (lEndColumn > 0) and (aColumn > lEndColumn)) then
    Exit(False);
  Result := True;
end;

function TryResolveWithSelectorType(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aWith: TDelphiSemanticWithStatement; const aSelector: string; const aDepth: Integer;
  out aType: TSnapshotTargetSymbol): Boolean;
var
  lSelectorReference: TDelphiSemanticReference;
  lSelectorRef: TSemanticSymbolRef;
begin
  aType := Default(TSnapshotTargetSymbol);
  if SameText(aSelector, 'Self') then
    Exit(TryResolveSnapshotTypeFromUnit(aSymbolsByName, aModel.UnitName,
      SnapshotSectionForReference(aReference), SnapshotRoutineOwnerName(aReference.RoutineName),
      aType));
  if not IsSnapshotPlainIdentifier(aSelector) then
    Exit(False);

  // The selector is resolved where the with statement starts, in the same routine.
  lSelectorReference := aReference;
  lSelectorReference.Name := aSelector;
  lSelectorReference.Line := aWith.Line;
  lSelectorReference.Column := aWith.Column;
  lSelectorReference.Offset := 0;
  lSelectorReference.EndOffset := 0;
  lSelectorReference.EndLine := 0;
  lSelectorReference.EndColumn := 0;
  Result := TryResolveSnapshotNameCandidates(aSymbolsByName, aModel, lSelectorReference,
    aDepth + 1, lSelectorRef) and TryResolveSnapshotSymbolType(aSymbolsByName, aSelector,
    lSelectorRef, aType);
end;

// Delphi binds a name in a with body to the innermost selector, last selector first, before any
// lexical scope. smlAbsent means no selector has the member, so lexical resolution applies.
function ResolveWithScopedSnapshotName(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aDepth: Integer; out aTarget: TSemanticSymbolRef): TSnapshotMemberLookup;
var
  i: Integer;
  j: Integer;
  lIndex: Integer;
  lIndexes: TArray<Integer>;
  lSelectors: TArray<string>;
  lType: TSnapshotTargetSymbol;
  lWith: TDelphiSemanticWithStatement;
begin
  Result := smlAbsent;
  aTarget := Default(TSemanticSymbolRef);
  if aReference.Line <= 0 then
    Exit;
  lIndexes := [];
  for i := 0 to High(aModel.WithStatements) do
    if SnapshotPositionInWith(aModel.WithStatements[i], aReference.Line, aReference.Column) then
      lIndexes := lIndexes + [i];
  if Length(lIndexes) = 0 then
    Exit;
  if aDepth > cSnapshotMaxNameResolutionDepth then
    Exit(smlUnknown);

  // Innermost first: a nested body starts after the bodies that contain it.
  for i := 1 to High(lIndexes) do
  begin
    lIndex := lIndexes[i];
    j := i - 1;
    while (j >= 0) and ((aModel.WithStatements[lIndexes[j]].BodyLine <
      aModel.WithStatements[lIndex].BodyLine) or
      ((aModel.WithStatements[lIndexes[j]].BodyLine = aModel.WithStatements[lIndex].BodyLine) and
      (aModel.WithStatements[lIndexes[j]].BodyColumn <
      aModel.WithStatements[lIndex].BodyColumn))) do
    begin
      lIndexes[j + 1] := lIndexes[j];
      Dec(j);
    end;
    lIndexes[j + 1] := lIndex;
  end;

  for lIndex in lIndexes do
  begin
    lWith := aModel.WithStatements[lIndex];
    if Pos(',', lWith.SelectorText) = 0 then
      lSelectors := [Trim(lWith.SelectorText)]
    else if not TrySplitTopLevelCommaList(lWith.SelectorText, lSelectors) then
      Exit(smlUnknown);
    for j := High(lSelectors) downto 0 do
    begin
      if not TryResolveWithSelectorType(aSymbolsByName, aModel, aReference, lWith,
        Trim(lSelectors[j]), aDepth, lType) then
        Exit(smlUnknown);
      Result := LookupSnapshotTypeMember(aSymbolsByName, lType, aReference.Name, aTarget);
      if Result <> smlAbsent then
        Exit;
    end;
  end;
  Result := smlAbsent;
end;

// The class whose members an unqualified name in a method body can denote: the owner of the
// method, also for a routine nested inside it. Empty outside methods.
function SnapshotMethodOwnerName(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := SnapshotRoutineOwnerName(aReference.RoutineName);
  if (Result <> '') or (aReference.Line <= 0) then
    Exit;
  lBestLine := 0;
  for lRoutine in aModel.Routines do
    if (lRoutine.OwnerName <> '') and (lRoutine.Line > lBestLine) and
      (lRoutine.Line <= aReference.Line) and (lRoutine.EndLine >= aReference.Line) then
    begin
      lBestLine := lRoutine.Line;
      Result := lRoutine.OwnerName;
    end;
end;

// An unqualified name in a method may denote a member of the class or a project ancestor. Outside
// a method the lookup is smlAbsent; an owner chain that cannot be proven complete (an ancestor
// outside the project, a helper, an inherited TObject name) is smlUnknown.
function ResolveInheritedReferenceCandidate(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateRefs: TList<TSemanticSymbolRef>): TSnapshotMemberLookup;
var
  lOwner: string;
  lTarget: TSemanticSymbolRef;
  lType: TSnapshotTargetSymbol;
begin
  lOwner := SnapshotMethodOwnerName(aModel, aReference);
  if lOwner = '' then
    Exit(smlAbsent);
  if not TryResolveSnapshotTypeFromUnit(aSymbolsByName, aModel.UnitName,
    SnapshotSectionForReference(aReference), lOwner, lType) then
    Exit(smlUnknown);
  Result := LookupSnapshotTypeMember(aSymbolsByName, lType, aReference.Name, lTarget);
  if (Result = smlFound) and not SymbolRefInList(aCandidateRefs, lTarget) then
    aCandidateRefs.Add(lTarget);
end;

function TryResolveSnapshotNameCandidates(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aDepth: Integer; out aTargetRef: TSemanticSymbolRef): Boolean;
var
  lCandidateRefs: TList<TSemanticSymbolRef>;
  lWithLookup: TSnapshotMemberLookup;
begin
  lWithLookup := ResolveWithScopedSnapshotName(aSymbolsByName, aModel, aReference, aDepth,
    aTargetRef);
  if lWithLookup = smlFound then
    Exit(True);
  aTargetRef := Default(TSemanticSymbolRef);
  // An unprovable with selector may own the name, so no lexical binding is proven.
  if lWithLookup = smlUnknown then
    Exit(False);

  lCandidateRefs := TList<TSemanticSymbolRef>.Create;
  try
    if not AddLocalReferenceCandidates(aSymbolsByName, aModel, aReference,
      lCandidateRefs) and not AddOwnedReferenceCandidates(aSymbolsByName, aModel, aReference,
      lCandidateRefs) then
      case ResolveInheritedReferenceCandidate(aSymbolsByName, aModel, aReference,
        lCandidateRefs) of
        smlAbsent:
          AddTopLevelReferenceCandidates(aSymbolsByName, aModel, aReference, lCandidateRefs);
        // A member of an unproven ancestor may own the name, as with an unprovable selector.
        smlUnknown:
          Exit(False);
      end;

    Result := lCandidateRefs.Count = 1;
    if Result then
      aTargetRef := lCandidateRefs[0];
  finally
    lCandidateRefs.Free;
  end;
end;

// receiver.Name where receiver is a variable, parameter, field, property or type whose declared
// type is a project class, record or interface.
function TryResolveTypedReceiverReference(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aReceiver: string; out aTarget: TSemanticSymbolRef): Boolean;
var
  lReceiverReference: TDelphiSemanticReference;
  lReceiverRef: TSemanticSymbolRef;
  lType: TSnapshotTargetSymbol;
begin
  aTarget := Default(TSemanticSymbolRef);
  if not IsSnapshotPlainIdentifier(aReceiver) then
    Exit(False);
  lReceiverReference := aReference;
  lReceiverReference.Name := aReceiver;
  lReceiverReference.Offset := 0;
  lReceiverReference.EndOffset := 0;
  lReceiverReference.EndLine := 0;
  lReceiverReference.EndColumn := 0;
  Result := TryResolveSnapshotNameCandidates(aSymbolsByName, aModel, lReceiverReference, 1,
    lReceiverRef) and TryResolveSnapshotSymbolType(aSymbolsByName, aReceiver, lReceiverRef,
    lType) and (LookupSnapshotTypeMember(aSymbolsByName, lType, aReference.Name,
    aTarget) = smlFound);
  if not Result then
    aTarget := Default(TSemanticSymbolRef);
end;

function ReferenceHasQualifier(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): Boolean; forward;
function TryResolveQualifiedReference(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTarget: TSemanticSymbolRef): Boolean; forward;
function TryResolveSnapshotReferenceTarget(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTargetRef: TSemanticSymbolRef): Boolean;
begin
  aTargetRef := Default(TSemanticSymbolRef);
  if ReferenceIsPartialIdentifier(aModel, aReference) then
    Exit(False);
  if ReferenceHasQualifier(aModel, aReference) then
    Exit(TryResolveQualifiedReference(aSymbolsByName, aModel, aReference, aTargetRef));
  Result := TryResolveSnapshotNameCandidates(aSymbolsByName, aModel, aReference, 0, aTargetRef);
end;

procedure AddModelReferenceTargets(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel;
  const aRoutineNamesByLine: TDictionary<Integer, string>;
  const aTargets: TSnapshotReferenceTargetMap);
var
  lReference: TDelphiSemanticReference;
  lResolutionReference: TDelphiSemanticReference;
  lResolutionModel: TDelphiSemanticUnitModel;
  lTargetRef: TSemanticSymbolRef;
begin
  lResolutionModel := aModel;
  lResolutionModel.SourceText := SanitizeCodeText(aModel.SourceText);
  for lReference in aModel.References do
  begin
    lResolutionReference := lReference;
    lResolutionReference.RoutineName := SnapshotReferenceRoutineNameForResolution(
      aModel, aRoutineNamesByLine, lReference);
    if TryResolveSnapshotReferenceTarget(aSymbolsByName, lResolutionModel,
      lResolutionReference, lTargetRef) then
      aTargets.AddOrSetValue(SnapshotReferenceMatchKey(aModel.UnitName,
        lReference.RoutineName, lReference.Name, lReference.Line,
        lReference.Column), lTargetRef);
  end;
end;

function BuildSnapshotReferenceTargetsForModelsAndSnapshots(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aModelUnitIds: TArray<TSemanticUnitId>;
  const aReferenceSnapshots: TArray<TDelphiProjectSnapshot>):
  TSnapshotReferenceTargetLookup;
var
  lTargets: TSnapshotReferenceTargetMap;
  lRoutineNamesByLine: TDictionary<Integer, string>;
  lSymbols: TSnapshotTargetSymbolList;
  lSymbolsByName: TSnapshotTargetSymbolsByName;
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
      AddModelReferenceTargets(lSymbolsByName, lUnitModel, lRoutineNamesByLine, lTargets);
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

function ReferenceHasQualifier(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): Boolean;
var
  i: Integer;
begin
  i := aReference.Offset;
  if not SameText(Copy(aModel.SourceText, i, Length(aReference.Name)),
    aReference.Name) then
    if SameText(Copy(aModel.SourceText, i + 1, Length(aReference.Name)),
      aReference.Name) then
      Inc(i)
    else
      Exit(False);
  Dec(i);
  while (i > 0) and CharInSet(aModel.SourceText[i], [#9, #10, #13, ' ']) do
    Dec(i);
  Result := IsMemberAccessDot(aModel.SourceText, i);
end;

function SimpleUnitReceiver(const aModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference): string;
var
  i: Integer;
begin
  Result := ReferenceReceiverName(aModel, aReference);
  if Result = '' then
    Exit;
  i := aReference.Offset;
  if not SameText(Copy(aModel.SourceText, i, Length(aReference.Name)), aReference.Name) then
    Inc(i);
  Dec(i);
  while (i > 0) and CharInSet(aModel.SourceText[i], [#9, #10, #13, ' ']) do
    Dec(i);
  Dec(i);
  while (i > 0) and CharInSet(aModel.SourceText[i], [#9, #10, #13, ' ']) do
    Dec(i);
  Dec(i, Length(Result));
  while (i > 0) and CharInSet(aModel.SourceText[i], [#9, #10, #13, ' ']) do
    Dec(i);
  if IsMemberAccessDot(aModel.SourceText, i) then
    Result := '';
end;

function TryResolveQualifiedUnitReference(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTarget: TSemanticSymbolRef): Boolean;
var
  lReceiver: string;
  lSymbols: TSnapshotTargetSymbolList;
  lSymbol: TSnapshotTargetSymbol;
  lCount: Integer;
begin
  aTarget := Default(TSemanticSymbolRef);
  lSymbols := nil;
  lReceiver := SimpleUnitReceiver(aModel, aReference);
  if (lReceiver = '') or
    not ModelUsesUnitInSection(aModel, aReference.SectionKind, lReceiver) then
    Exit(False);
  // A same-named declaration may shadow the unit qualifier. Keep that case unknown.
  if aSymbolsByName.TryGetValue(lReceiver, lSymbols) then
    for lSymbol in lSymbols do
      if not SameText(lSymbol.Kind, 'unit') then
        Exit(False);
  if not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit(False);
  lCount := 0;
  for lSymbol in lSymbols do
    if SameText(lSymbol.UnitName, lReceiver) and
      TopLevelSymbolIsVisibleFromReference(aModel, aReference.SectionKind, lSymbol) then
    begin
      Inc(lCount);
      aTarget := lSymbol.Ref;
    end;
  Result := lCount = 1;
  if not Result then
    aTarget := Default(TSemanticSymbolRef);
end;

function TryResolveClassVariableReference(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aReceiver: string; out aTarget: TSemanticSymbolRef): Boolean;
var
  lReceiverReference: TDelphiSemanticReference;
  lCandidates: TList<TSemanticSymbolRef>;
  lSymbols: TSnapshotTargetSymbolList;
  lSymbol: TSnapshotTargetSymbol;
  lOwnerUnit: string;
  lCount: Integer;
begin
  aTarget := Default(TSemanticSymbolRef);
  if aReceiver = '' then
    Exit(False);
  lReceiverReference := aReference;
  lReceiverReference.Name := aReceiver;
  lCandidates := TList<TSemanticSymbolRef>.Create;
  try
    // A local receiver may shadow the class name; it does not prove a type qualifier.
    if AddLocalReferenceCandidates(aSymbolsByName, aModel, lReceiverReference, lCandidates) then
      Exit(False);
    AddTopLevelReferenceCandidates(aSymbolsByName, aModel, lReceiverReference, lCandidates);
    if lCandidates.Count <> 1 then
      Exit(False);
    if not aSymbolsByName.TryGetValue(aReceiver, lSymbols) then
      Exit(False);
    lOwnerUnit := '';
    for lSymbol in lSymbols do
      if (lSymbol.Ref.UnitId = lCandidates[0].UnitId) and
        (lSymbol.Ref.SymbolId = lCandidates[0].SymbolId) and SameText(lSymbol.Kind, 'type') then
        lOwnerUnit := lSymbol.UnitName;
  finally
    lCandidates.Free;
  end;
  if (lOwnerUnit = '') or not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit(False);
  lCount := 0;
  for lSymbol in lSymbols do
    if SameText(lSymbol.UnitName, lOwnerUnit) and SameText(lSymbol.OwnerName, aReceiver) and
      SameText(lSymbol.Kind, 'class-var') then
    begin
      Inc(lCount);
      aTarget := lSymbol.Ref;
    end;
  Result := lCount = 1;
  if not Result then
    aTarget := Default(TSemanticSymbolRef);
end;
function TryResolveQualifiedReference(const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTarget: TSemanticSymbolRef): Boolean;
var
  lReceiver, lOwner: string;
  lOwnerType: TSnapshotTargetSymbol;
  lSymbols: TSnapshotTargetSymbolList;
  lSymbol: TSnapshotTargetSymbol;
  lCount: Integer;
begin
  aTarget := Default(TSemanticSymbolRef);
  lReceiver := SimpleUnitReceiver(aModel, aReference);
  if not SameText(lReceiver, 'Self') then
  begin
    if TryResolveQualifiedUnitReference(aSymbolsByName, aModel, aReference, aTarget) then
      Exit(True);
    if TryResolveClassVariableReference(aSymbolsByName, aModel, aReference, lReceiver,
      aTarget) then
      Exit(True);
    Exit(TryResolveTypedReceiverReference(aSymbolsByName, aModel, aReference, lReceiver,
      aTarget));
  end;
  lOwner := SnapshotRoutineOwnerName(aReference.RoutineName);
  lSymbols := nil;
  if (lOwner = '') or not aSymbolsByName.TryGetValue(aReference.Name, lSymbols) then
    Exit(False);
  lCount := 0;
  for lSymbol in lSymbols do
    if SameText(lSymbol.UnitName, aModel.UnitName) and SameText(lSymbol.OwnerName, lOwner) and
      MatchText(lSymbol.Kind, ['field', 'property', 'class-var', 'method']) then
    begin
      Inc(lCount);
      aTarget := lSymbol.Ref;
    end;
  Result := lCount = 1;
  if Result then
    Exit;
  aTarget := Default(TSemanticSymbolRef);
  // Self.Member may name a member inherited from a class in another unit.
  if (lCount = 0) and TryResolveSnapshotTypeFromUnit(aSymbolsByName, aModel.UnitName,
    SnapshotSectionForReference(aReference), lOwner, lOwnerType) then
    Result := LookupSnapshotTypeMember(aSymbolsByName, lOwnerType, aReference.Name,
      aTarget) = smlFound;
  if not Result then
    aTarget := Default(TSemanticSymbolRef);
end;

function TryResolveResultReference(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTarget: TSemanticSymbolRef): Boolean;
var
  lSignature: string;
  lAmbiguous: Boolean;
  lUnit: TUnitSnapshot;
  lOwner: TSemanticSymbolFact;
begin
  aTarget := Default(TSemanticSymbolRef);
  if (aReference.RoutineScopeId = '') or
    not TryResolveUniqueSnapshotRoutineRef(aSymbolsByName, aModel,
      aReference.RoutineName, aReference.RoutineScopeId, aTarget, lSignature,
      lAmbiguous) then
    Exit(False);
  if not aSnapshot.TryFindUnitById(aTarget.UnitId, lUnit) then
    Exit(False);
  lOwner := lUnit.SymbolById(aTarget.SymbolId);
  if aSnapshot.TextOf(lOwner.TypeId) <> '' then
    Exit(True);
  // Procedures have no implicit result; ordinary locals/imports still apply.
  Result := TryResolveSnapshotReferenceTarget(aSymbolsByName, aModel, aReference, aTarget);
end;

function TryResolveAlternateReference(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbolsByName: TSnapshotTargetSymbolsByName;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  out aTarget: TSemanticSymbolRef): Boolean;
begin
  if ReferenceIsPartialIdentifier(aModel, aReference) then
  begin
    aTarget := Default(TSemanticSymbolRef);
    Exit(False);
  end;
  if ReferenceHasQualifier(aModel, aReference) then
    Result := TryResolveQualifiedReference(aSymbolsByName, aModel, aReference, aTarget)
  else if SameText(aReference.Name, 'Result') and (aReference.RoutineName <> '') then
    Result := TryResolveResultReference(aSnapshot, aSymbolsByName, aModel, aReference, aTarget)
  else
    Result := TryResolveSnapshotReferenceTarget(aSymbolsByName, aModel, aReference, aTarget);
end;

function ResolveSnapshotReferenceTargets(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel): TArray<TSemanticSymbolRef>;
var
  lSymbols: TSnapshotTargetSymbolList;
  lSymbolsByName: TSnapshotTargetSymbolsByName;
  lRoutineNames: TDictionary<Integer, string>;
  lReference: TDelphiSemanticReference;
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
begin
  SetLength(Result, Length(aModel.References));
  if aSnapshot = nil then
    Exit;
  lModel := aModel;
  lModel.SourceText := SanitizeCodeText(aModel.SourceText);
  lSymbolsByName := BuildSnapshotTargetSymbolsByName([], [], [aSnapshot], lSymbols);
  lRoutineNames := nil;
  try
    lRoutineNames := TDictionary<Integer, string>.Create;
    for i := 0 to High(aModel.References) do
    begin
      lReference := aModel.References[i];
      lReference.RoutineName := SnapshotReferenceRoutineNameForResolution(
        lModel, lRoutineNames, lReference);
      if not TryResolveAlternateReference(aSnapshot, lSymbolsByName, lModel,
        lReference, Result[i]) then
        Result[i] := Default(TSemanticSymbolRef);
    end;
  finally
    lRoutineNames.Free;
    lSymbolsByName.Free;
    lSymbols.Free;
  end;
end;

function CompareSnapshotImportBindings(const aSnapshot: TDelphiProjectSnapshot;
  const aModel: TDelphiSemanticUnitModel;
  const aInterfaceImports, aImplementationImports: TArray<string>):
  TDelphiSnapshotImportBindingComparison;
var
  lBefore: TArray<TSemanticSymbolRef>;
  lAfter: TArray<TSemanticSymbolRef>;
  lModel: TDelphiSemanticUnitModel;
  lPreserved: Boolean;
  i: Integer;
begin
  Result := Default(TDelphiSnapshotImportBindingComparison);
  Result.Reason := 'uses.reference-binding-unknown';
  if (aSnapshot = nil) or (Length(aModel.References) = 0) then
    Exit;
  lBefore := ResolveSnapshotReferenceTargets(aSnapshot, aModel);
  lModel := aModel;
  lModel.InterfaceUses := aInterfaceImports;
  lModel.ImplementationUses := aImplementationImports;
  lAfter := ResolveSnapshotReferenceTargets(aSnapshot, lModel);
  lPreserved := True;
  for i := 0 to High(lBefore) do
  begin
    if (lBefore[i].UnitId = 0) or (lBefore[i].SymbolId = 0) or
      (lAfter[i].UnitId = 0) or (lAfter[i].SymbolId = 0) then
      Exit;
    if (lBefore[i].UnitId <> lAfter[i].UnitId) or
      (lBefore[i].SymbolId <> lAfter[i].SymbolId) then
      lPreserved := False;
    Inc(Result.ReferenceCount);
  end;
  Result.Complete := True;
  Result.Preserved := lPreserved;
  if lPreserved then
    Result.Reason := ''
  else
    Result.Reason := 'uses.reference-binding-changed';
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
  if not SnapshotIncludesDeclaration(aDeclaration) then
    Exit;
  if SameText(SnapshotDeclarationKind(aDeclaration.Kind), cSnapshotSymbolKindRoutine) then
    Exit;

  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aDeclaration.Name);
  lSymbol.TypeId := aStrings.Intern(aDeclaration.TypeName);
  lSymbol.KindId := aStrings.Intern(SnapshotDeclarationKind(aDeclaration.Kind));
  lSymbol.SectionKindId := aStrings.Intern(aDeclaration.SectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.DeclarationRoleId := aStrings.Intern(aDeclaration.DeclarationRole);
  lSymbol.ScopeKindId := aStrings.Intern(aDeclaration.ScopeKind);
  lSymbol.OwnerScopeId := aStrings.Intern(aDeclaration.OwnerScopeId);
  lSymbol.SemanticSymbolId := aStrings.Intern(aDeclaration.SymbolId);
  if SameText(aDeclaration.Kind, 'typed-const') and not aDeclaration.Mutable then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagImmutableTypedConstant;
  lSymbol.Line := aDeclaration.Line;
  lSymbol.Column := aDeclaration.Column;
  lSymbol.EndLine := aDeclaration.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aDeclaration.Column, aDeclaration.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotMember(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aUnitName: string;
  const aMember: TDelphiSemanticMember;
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
  if SameText(aMember.Kind, 'class-var') and
    (Trim(aMember.OwnerName) <> '') then
  begin
    lSymbol.DeclarationRoleId := aStrings.Intern('declaration');
    lSymbol.ScopeKindId := aStrings.Intern('type');
    lSymbol.OwnerScopeId := aStrings.Intern(LowerCase(aUnitName) + '|type|' +
      LowerCase(aMember.OwnerName));
    lSymbol.SemanticSymbolId := aStrings.Intern(aStrings.TextOf(
      lSymbol.OwnerScopeId) + '|classvar|' + LowerCase(aMember.Name));
  end;
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
  aRoutineSignature, aRoutineScopeId: string;
  const aParameter: TDelphiSemanticParameter;
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
  lSymbol.RoutineScopeId := aStrings.Intern(aRoutineScopeId);
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
  lSymbol.RoutineScopeId := aStrings.Intern(aRoutine.ScopeId);
  lSymbol.Line := aRoutine.Line;
  lSymbol.Column := aRoutine.Column;
  lSymbol.EndLine := aRoutine.EndLine;
  if lSymbol.EndLine <= 0 then
    lSymbol.EndLine := aRoutine.Line;
  lSymbol.EndColumn := aRoutine.EndColumn;
  if lSymbol.EndColumn <= 0 then
    lSymbol.EndColumn := SnapshotEndColumn(aRoutine.Column, aRoutine.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);

  for lParameter in aRoutine.Parameters do
    AddSnapshotParameter(aStrings, aUnit, lRoutineName, aRoutine.SectionKind,
      aRoutine.Signature, aRoutine.ScopeId, lParameter, aMetrics);
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
  lSymbol.RoutineScopeId := aStrings.Intern(aLocal.RoutineScopeId);
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
  lReference.RoutineScopeId := aStrings.Intern(aReference.RoutineScopeId);
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
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lScopeDiagnostic: string;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lReference: TDelphiSemanticReference;
  lRoutine: TDelphiSemanticRoutine;
  lWith: TDelphiSemanticWithStatement;
begin
  Result := TUnitSnapshot.Create(aUnitId, aStrings.Intern(SnapshotFullPath(aModel.FileName)),
    aStrings.Intern(aModel.UnitName), aExactStrings.Intern(aModel.SourceText));
  try
    lScopeDiagnostic := '';
    for lDiagnostic in aModel.Diagnostics do
      if SameText(lDiagnostic.Code, 'SCOPE_MODEL_FAILED') then
      begin
        lScopeDiagnostic := lDiagnostic.Message;
        Break;
      end;
    Result.SetScopeModelMetadata(aStrings.Intern(aModel.ScopeModelStatus),
      aStrings.Intern(aModel.ScopeModelVersion), aStrings.Intern(lScopeDiagnostic),
      aModel.RejectedDeclarationCount);
    for lWith in aModel.WithStatements do
      AddSnapshotWithStatement(aStrings, Result, aModel, lWith, aMetrics);
    for lDeclaration in aModel.Declarations do
      AddSnapshotDeclaration(aStrings, Result, lDeclaration, aMetrics);
    for lMember in aModel.Members do
      AddSnapshotMember(aStrings, Result, aModel.UnitName, lMember, aMetrics);
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
  Result.DeclarationRoleId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.DeclarationRoleId);
  Result.ScopeKindId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.ScopeKindId);
  Result.OwnerScopeId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.OwnerScopeId);
  Result.SemanticSymbolId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.SemanticSymbolId);
  Result.RoutineScopeId := RemapStringId(aSourceStrings, aTargetStrings,
    aSymbol.RoutineScopeId);
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
  Result.RoutineScopeId := RemapStringId(aSourceStrings, aTargetStrings,
    aReference.RoutineScopeId);
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
    Result.SetScopeModelMetadata(RemapStringId(aSourceStrings, aTargetStrings,
      aUnit.ScopeModelStatusId), RemapStringId(aSourceStrings, aTargetStrings,
      aUnit.ScopeModelVersionId), RemapStringId(aSourceStrings, aTargetStrings,
      aUnit.ScopeDiagnosticId), aUnit.RejectedDeclarationCount);
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
    Result.SetScopeModelMetadata(RemapStringId(aSourceStrings, aTargetStrings,
      aUnit.ScopeModelStatusId), RemapStringId(aSourceStrings, aTargetStrings,
      aUnit.ScopeModelVersionId), RemapStringId(aSourceStrings, aTargetStrings,
      aUnit.ScopeDiagnosticId), aUnit.RejectedDeclarationCount);
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
  const aExtensionName: string; var aOwnedExtension: TObject;
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
    if aOwnedExtension <> nil then
    begin
      lBuilder.SetExtensionOwned(aExtensionName, aOwnedExtension);
      aOwnedExtension := nil;
    end;
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
      AttachRemoveWithVisibility(lBuilder, aModels);
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
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aExtensionName: string; var aOwnedExtension: TObject;
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
    if aOwnedExtension <> nil then
    begin
      lBuilder.SetExtensionOwned(aExtensionName, aOwnedExtension);
      aOwnedExtension := nil;
    end;
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
    AttachRemoveWithVisibility(lBuilder, aModels);
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
  lOwnedExtension: TObject;
begin
  lOwnedExtension := nil;
  Result := BuildProjectSnapshotFromModelsWithExtension(aModels, aRemoveWithFacts,
    aOptions, '', lOwnedExtension, aMetrics);
end;

function BuildProjectSnapshotFromModelsWithExtension(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aOptions: TDelphiSnapshotBuildOptions;
  const aExtensionName: string; var aOwnedExtension: TObject;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot;
var
  lOwnedExtension: TObject;
  lReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  lResults: TArray<TSnapshotUnitBuildResult>;
  lStopwatch: TStopwatch;
begin
  lOwnedExtension := aOwnedExtension;
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lReferenceTargetLookup := Default(TSnapshotReferenceTargetLookup);
  lResults := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    if aOptions.ResolveReferenceTargets then
      lReferenceTargetLookup := BuildSnapshotReferenceTargets(aModels);
    if aOptions.WorkerCount <= 1 then
      Result := BuildSequentialProjectSnapshotFromModels(aModels, aRemoveWithFacts,
        lReferenceTargetLookup, aExtensionName, lOwnedExtension, aMetrics)
    else begin
      lResults := BuildUnitResults(aModels, lReferenceTargetLookup,
        aOptions.WorkerCount, aMetrics);
      Result := MergeUnitResults(lResults, aModels, aRemoveWithFacts,
        aExtensionName, lOwnedExtension, aMetrics);
    end;
  finally
    lStopwatch.Stop;
    aMetrics.BuildMilliseconds := lStopwatch.ElapsedMilliseconds;
    FreeSnapshotUnitBuildResults(lResults);
    lOwnedExtension.Free;
    aOwnedExtension := nil;
  end;
end;

function BuildProjectUnitSnapshotFromModels(
  const aModels: TArray<TDelphiSemanticUnitModel>;
  const aModelUnitIds: TArray<TSemanticUnitId>; const aModelIndex: Integer;
  const aReferenceSnapshots: TArray<TDelphiProjectSnapshot>;
  out aMetrics: TDelphiSnapshotBuilderMetrics): TDelphiProjectSnapshot; overload;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOwnedExtension: TObject;
  lReferenceTargetLookup: TSnapshotReferenceTargetLookup;
  lResults: TArray<TSnapshotUnitBuildResult>;
  lStopwatch: TStopwatch;
begin
  aMetrics := Default(TDelphiSnapshotBuilderMetrics);
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lOwnedExtension := nil;
  lReferenceTargetLookup := Default(TSnapshotReferenceTargetLookup);
  lResults := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    lReferenceTargetLookup := BuildSnapshotReferenceTargetsForModelsAndSnapshots(aModels,
      aModelUnitIds, aReferenceSnapshots);
    SetLength(lResults, 1);
    lResults[0] := BuildUnitResult(aModels[aModelIndex],
      ModelUnitIdAt(aModelUnitIds, aModelIndex), lReferenceTargetLookup);
    Result := MergeUnitResults(lResults, [aModels[aModelIndex]], lFacts, '',
      lOwnedExtension, aMetrics);
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
    AttachRemoveWithVisibility(lBuilder, aFacts.UnitModels);
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

end.
