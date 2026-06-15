unit DelphiSemantics.Index.LegacyModel;

interface

uses
  DelphiSemantics.Index, DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  TDelphiSemanticLegacyModelIndexer = record
  public
    class function BuildSymbols(const aContext: TDelphiSemanticSymbolQueryContext):
      TArray<TDelphiSemanticIndexedSymbol>; static;
    class function BuildReferences(const aIndex: TDelphiSemanticProjectSymbolIndex;
      const aContext: TDelphiSemanticSymbolQueryContext):
      TArray<TDelphiSemanticIndexedReference>; static;
  end;

implementation

uses
  System.Generics.Collections, System.StrUtils, System.SysUtils,
  DelphiSemantics.Model;

type
  TDelphiSemanticSymbolList = TList<TDelphiSemanticIndexedSymbol>;

function SymbolIdInList(const aIds: TList<TDelphiSemanticSymbolId>;
  const aId: TDelphiSemanticSymbolId): Boolean; forward;

function NormalizeModelSignatureForSymbolId(const aSignature: string): string;
begin
  Result := LowerCase(StringReplace(aSignature.Trim, ' ', '', [rfReplaceAll]));
end;

function QualifiedSymbolRoutineName(const aSymbol: TDelphiSemanticIndexedSymbol): string;
begin
  if aSymbol.OwnerName <> '' then
    Result := aSymbol.OwnerName + '.' + aSymbol.Name
  else
    Result := aSymbol.Name;
end;

function TryFindUniqueModelRoutineSymbolId(
  const aSymbols: TArray<TDelphiSemanticIndexedSymbol>; const aUnitName, aRoutineName: string;
  out aRoutineId: TDelphiSemanticSymbolId): Boolean;
var
  lCount: Integer;
  lSignature: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  aRoutineId := Default(TDelphiSemanticSymbolId);
  lCount := 0;
  lSignature := '';
  for lSymbol in aSymbols do
    if SameText(lSymbol.UnitName, aUnitName) and SameText(lSymbol.Kind, 'routine') and
      SameText(QualifiedSymbolRoutineName(lSymbol), aRoutineName) then
    begin
      if lCount = 0 then
      begin
        Inc(lCount);
        aRoutineId := lSymbol.Id;
        lSignature := NormalizeModelSignatureForSymbolId(lSymbol.Signature);
      end else if not SameText(lSignature, NormalizeModelSignatureForSymbolId(lSymbol.Signature)) then
      begin
        Inc(lCount);
        aRoutineId := Default(TDelphiSemanticSymbolId);
        Exit(False);
      end;
    end;

  Result := lCount = 1;
end;

function MakeSymbolId(const aModel: TDelphiSemanticUnitModel; const aKind, aOwnerName,
  aName, aSignature: string; const aLine, aColumn, aOrdinal: Integer): TDelphiSemanticSymbolId;
begin
  if SameText(aKind, 'routine') then
    Result.Value := LowerCase(aModel.UnitName) + ':' + LowerCase(aKind) + ':' +
      LowerCase(aOwnerName) + ':' + LowerCase(aName) + ':' +
      NormalizeModelSignatureForSymbolId(aSignature)
  else
    Result.Value := LowerCase(aModel.UnitName) + ':' + LowerCase(aKind) + ':' +
      LowerCase(aOwnerName) + ':' + LowerCase(aName) + ':' + IntToStr(aLine) + ':' +
      IntToStr(aColumn) + ':' + IntToStr(aOrdinal);
end;

function IndexedSourceKind(const aContext: TDelphiSemanticSymbolQueryContext;
  const aIndex: Integer): string;
begin
  if (aIndex >= 0) and (aIndex < Length(aContext.IndexedUnitSourceKinds)) and
    (aContext.IndexedUnitSourceKinds[aIndex] <> '') then
    Exit(aContext.IndexedUnitSourceKinds[aIndex]);

  Result := 'rtl-source';
end;

procedure AddSymbol(const aSymbols: TDelphiSemanticSymbolList;
  const aModel: TDelphiSemanticUnitModel; const aSourceKind, aKind, aOwnerName, aName: string;
  const aSectionKind, aVisibility, aSignature: string; const aLine, aColumn: Integer);
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if aName = '' then
    Exit;

  lSymbol := Default(TDelphiSemanticIndexedSymbol);
  lSymbol.Id := MakeSymbolId(aModel, aKind, aOwnerName, aName, aSignature, aLine, aColumn,
    aSymbols.Count);
  lSymbol.Name := aName;
  lSymbol.Kind := aKind;
  lSymbol.OwnerName := aOwnerName;
  lSymbol.UnitName := aModel.UnitName;
  lSymbol.SectionKind := aSectionKind;
  lSymbol.SourceKind := aSourceKind;
  lSymbol.Visibility := aVisibility;
  lSymbol.Signature := aSignature;
  lSymbol.FileName := aModel.FileName;
  lSymbol.Line := aLine;
  lSymbol.Column := aColumn;
  aSymbols.Add(lSymbol);
end;

procedure AddModelSymbols(const aSymbols: TDelphiSemanticSymbolList;
  const aModel: TDelphiSemanticUnitModel; const aSourceKind: string);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lRoutine: TDelphiSemanticRoutine;
begin
  AddSymbol(aSymbols, aModel, aSourceKind, 'unit', '', aModel.UnitName, 'interface', '', '', 1, 1);

  for lDeclaration in aModel.Declarations do
    if not SameText(lDeclaration.Kind, 'routine') then
      AddSymbol(aSymbols, aModel, aSourceKind, lDeclaration.Kind, '', lDeclaration.Name,
        lDeclaration.SectionKind, '', '', lDeclaration.Line, lDeclaration.Column);

  for lRoutine in aModel.Routines do
    AddSymbol(aSymbols, aModel, aSourceKind, 'routine', lRoutine.OwnerName, lRoutine.Name,
      lRoutine.SectionKind, '', lRoutine.Signature, lRoutine.Line, lRoutine.Column);

  for lMember in aModel.Members do
    AddSymbol(aSymbols, aModel, aSourceKind, lMember.Kind, lMember.OwnerName, lMember.Name,
      '', lMember.Visibility, lMember.Signature, lMember.Line, lMember.Column);

  for lLocal in aModel.Locals do
    AddSymbol(aSymbols, aModel, aSourceKind, lLocal.Kind, lLocal.RoutineName, lLocal.Name,
      '', '', '', lLocal.Line, lLocal.Column);
end;

function UnitNameIsUsedBySection(const aModel: TDelphiSemanticUnitModel; const aSourceKind,
  aTargetUnitName: string): Boolean;
var
  s: string;
begin
  if SameText(aModel.UnitName, aTargetUnitName) then
    Exit(True);

  for s in aModel.InterfaceUses do
    if SameText(s, aTargetUnitName) then
      Exit(True);

  if SameText(aSourceKind, 'implementation') then
    for s in aModel.ImplementationUses do
      if SameText(s, aTargetUnitName) then
        Exit(True);

  Result := False;
end;

function OwnedSymbolIsVisibleFromReference(const aReferenceModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference; const aSymbol: TDelphiSemanticIndexedSymbol):
  Boolean;
begin
  if aSymbol.OwnerName = '' then
    Exit(False);
  if not SameText(aReferenceModel.UnitName, aSymbol.UnitName) then
    Exit(False);
  if MatchText(aSymbol.Kind, ['field', 'class-var', 'property']) then
    Exit(StartsText(aSymbol.OwnerName + '.', aReference.RoutineName));

  Result := False;
end;

function IsOwnedMethodCandidate(const aModel: TDelphiSemanticUnitModel;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := (aSymbol.OwnerName <> '') and SameText(aModel.UnitName, aSymbol.UnitName) and
    SameText(aSymbol.Kind, 'method');
end;

function SectionCanSeeImplementationSymbols(const aSectionKind: string): Boolean;
begin
  Result := MatchText(aSectionKind, ['implementation', 'initialization', 'finalization']);
end;

function TopLevelSymbolIsVisibleFromReference(const aReferenceModel: TDelphiSemanticUnitModel;
  const aSectionKind: string; const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  if aSymbol.OwnerName <> '' then
    Exit(False);

  if not (SameText(aSymbol.Kind, 'unit') or SameText(aSymbol.Kind, 'type') or
    SameText(aSymbol.Kind, 'type-alias') or SameText(aSymbol.Kind, 'var') or
    SameText(aSymbol.Kind, 'const') or SameText(aSymbol.Kind, 'routine')) then
    Exit(False);

  if SameText(aReferenceModel.UnitName, aSymbol.UnitName) then
    Exit(SectionCanSeeImplementationSymbols(aSectionKind) or
      SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit'));

  Result := SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit');
end;

procedure AddCandidateId(const aCandidateIds: TList<TDelphiSemanticSymbolId>;
  const aSymbol: TDelphiSemanticIndexedSymbol);
begin
  if not SymbolIdInList(aCandidateIds, aSymbol.Id) then
    aCandidateIds.Add(aSymbol.Id);
end;

function RoutineSimpleName(const aRoutineName: string): string;
var
  lIndex: Integer;
begin
  lIndex := LastDelimiter('.', aRoutineName);
  if lIndex > 0 then
    Result := Copy(aRoutineName, lIndex + 1, MaxInt)
  else
    Result := aRoutineName;
end;

function TryResolveUniqueRoutineId(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aRoutineName: string;
  out aRoutineId: TDelphiSemanticSymbolId; out aAmbiguous: Boolean): Boolean;
var
  lCount: Integer;
  lSignature: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  aRoutineId := Default(TDelphiSemanticSymbolId);
  aAmbiguous := False;
  lCount := 0;
  lSignature := '';
  for lSymbol in aIndex.FindSymbolsByName(RoutineSimpleName(aRoutineName)) do
    if SameText(lSymbol.UnitName, aModel.UnitName) and SameText(lSymbol.Kind, 'routine') and
      SameText(QualifiedSymbolRoutineName(lSymbol), aRoutineName) then
    begin
      if lCount = 0 then
      begin
        Inc(lCount);
        aRoutineId := lSymbol.Id;
        lSignature := NormalizeModelSignatureForSymbolId(lSymbol.Signature);
      end else if not SameText(lSignature, NormalizeModelSignatureForSymbolId(lSymbol.Signature)) then
      begin
        Inc(lCount);
        aRoutineId := Default(TDelphiSemanticSymbolId);
        aAmbiguous := True;
        Exit(False);
      end;
    end;

  Result := lCount = 1;
end;

function SymbolIdInList(const aIds: TList<TDelphiSemanticSymbolId>;
  const aId: TDelphiSemanticSymbolId): Boolean;
var
  lId: TDelphiSemanticSymbolId;
begin
  for lId in aIds do
    if lId.Value = aId.Value then
      Exit(True);

  Result := False;
end;

function ReferenceConfidence(const aReferenceName: string;
  const aCandidates: TList<TDelphiSemanticSymbolId>;
  const aIndex: TDelphiSemanticProjectSymbolIndex): string;
var
  lCandidate: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if aCandidates.Count = 0 then
    Exit('no-candidates');

  for lCandidate in aCandidates do
    if aIndex.FindSymbolById(lCandidate, lSymbol) and (lSymbol.Name = aReferenceName) then
      Exit('exact-name-match');

  Result := 'case-insensitive-name-match';
end;

function AddLocalReferenceCandidates(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateIds: TList<TDelphiSemanticSymbolId>): Boolean;
var
  lAmbiguousRoutine: Boolean;
  lRoutineId: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  Result := False;
  if aReference.RoutineName = '' then
    Exit;

  if not TryResolveUniqueRoutineId(aIndex, aModel, aReference.RoutineName, lRoutineId,
    lAmbiguousRoutine) then
  begin
    Result := lAmbiguousRoutine;
    Exit;
  end;

  for lSymbol in aIndex.FindLocalSymbolsByRoutineIdAndName(lRoutineId, aReference.Name) do
    if SameText(lSymbol.UnitName, aModel.UnitName) then
      AddCandidateId(aCandidateIds, lSymbol);

  Result := aCandidateIds.Count > 0;
end;

procedure AddOwnedReferenceCandidates(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateIds: TList<TDelphiSemanticSymbolId>);
var
  lMethodCandidate: TDelphiSemanticIndexedSymbol;
  lMethodCount: Integer;
  lMethodOwnerName: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lMethodCandidate := Default(TDelphiSemanticIndexedSymbol);
  lMethodCount := 0;
  lMethodOwnerName := '';
  for lSymbol in aIndex.FindSymbolsByName(aReference.Name) do
  begin
    if OwnedSymbolIsVisibleFromReference(aModel, aReference, lSymbol) then
      AddCandidateId(aCandidateIds, lSymbol);
    if IsOwnedMethodCandidate(aModel, lSymbol) and not SameText(lSymbol.OwnerName,
      lMethodOwnerName) then
    begin
      Inc(lMethodCount);
      lMethodOwnerName := lSymbol.OwnerName;
      lMethodCandidate := lSymbol;
    end;
  end;

  if lMethodCount = 1 then
    AddCandidateId(aCandidateIds, lMethodCandidate);
end;

procedure AddTopLevelReferenceCandidates(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  const aCandidateIds: TList<TDelphiSemanticSymbolId>);
var
  lSectionKind: string;
  lScope: TDelphiSemanticUnitModel;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbols: TArray<TDelphiSemanticIndexedSymbol>;
begin
  lSectionKind := aReference.SectionKind;
  if lSectionKind = '' then
    lSectionKind := 'implementation';

  lSymbols := aIndex.FindSymbolsByName(aReference.Name);
  for lScope in aIndex.FindVisibleUnitScopes(aModel.UnitName, lSectionKind) do
    for lSymbol in lSymbols do
      if SameText(lSymbol.UnitName, lScope.UnitName) and
        TopLevelSymbolIsVisibleFromReference(aModel, lSectionKind, lSymbol) then
        AddCandidateId(aCandidateIds, lSymbol);
end;

procedure ResolveReference(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  var aIndexedReference: TDelphiSemanticIndexedReference);
var
  lCandidateIds: TList<TDelphiSemanticSymbolId>;
begin
  lCandidateIds := TList<TDelphiSemanticSymbolId>.Create;
  try
    if not AddLocalReferenceCandidates(aIndex, aModel, aReference, lCandidateIds) then
    begin
      AddOwnedReferenceCandidates(aIndex, aModel, aReference, lCandidateIds);
      AddTopLevelReferenceCandidates(aIndex, aModel, aReference, lCandidateIds);
    end;

    aIndexedReference.CandidateSymbolIds := lCandidateIds.ToArray;
    aIndexedReference.Confidence := ReferenceConfidence(aReference.Name, lCandidateIds,
      aIndex);
    if lCandidateIds.Count = 0 then
      aIndexedReference.Status := 'unresolved'
    else if lCandidateIds.Count = 1 then
    begin
      aIndexedReference.Status := 'resolved';
      aIndexedReference.SymbolId := lCandidateIds[0];
    end else
      aIndexedReference.Status := 'ambiguous';
  finally
    lCandidateIds.Free;
  end;
end;

procedure AddModelReferences(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aReferences: TList<TDelphiSemanticIndexedReference>; const aModel:
  TDelphiSemanticUnitModel; const aSourceKind: string);
var
  lIndexedReference: TDelphiSemanticIndexedReference;
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
  begin
    lIndexedReference := Default(TDelphiSemanticIndexedReference);
    lIndexedReference.Name := lReference.Name;
    lIndexedReference.RoutineName := lReference.RoutineName;
    lIndexedReference.UnitName := aModel.UnitName;
    lIndexedReference.SourceKind := aSourceKind;
    lIndexedReference.FileName := aModel.FileName;
    lIndexedReference.SectionKind := lReference.SectionKind;
    if lIndexedReference.SectionKind = '' then
      lIndexedReference.SectionKind := 'implementation';
    lIndexedReference.Line := lReference.Line;
    lIndexedReference.Column := lReference.Column;
    lIndexedReference.EndLine := lReference.EndLine;
    if lIndexedReference.EndLine = 0 then
      lIndexedReference.EndLine := lReference.Line;
    lIndexedReference.EndColumn := lReference.EndColumn;
    if lIndexedReference.EndColumn = 0 then
      lIndexedReference.EndColumn := lReference.Column + Length(lReference.Name) - 1;
    ResolveReference(aIndex, aModel, lReference, lIndexedReference);
    aReferences.Add(lIndexedReference);
  end;
end;

class function TDelphiSemanticLegacyModelIndexer.BuildSymbols(
  const aContext: TDelphiSemanticSymbolQueryContext): TArray<TDelphiSemanticIndexedSymbol>;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lSymbols: TDelphiSemanticSymbolList;
begin
  lSymbols := TDelphiSemanticSymbolList.Create;
  try
    AddModelSymbols(lSymbols, aContext.UnitModel, 'project-source');
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      AddModelSymbols(lSymbols, lModel, IndexedSourceKind(aContext, i));
    end;
    Result := lSymbols.ToArray;
  finally
    lSymbols.Free;
  end;
end;

class function TDelphiSemanticLegacyModelIndexer.BuildReferences(
  const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aContext: TDelphiSemanticSymbolQueryContext): TArray<TDelphiSemanticIndexedReference>;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lReferences: TList<TDelphiSemanticIndexedReference>;
begin
  lReferences := TList<TDelphiSemanticIndexedReference>.Create;
  try
    AddModelReferences(aIndex, lReferences, aContext.UnitModel, 'project-source');
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      AddModelReferences(aIndex, lReferences, lModel, IndexedSourceKind(aContext, i));
    end;
    Result := lReferences.ToArray;
  finally
    lReferences.Free;
  end;
end;

end.
