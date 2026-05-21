unit DelphiSemantics.Index;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  TDelphiSemanticProjectSymbolIndex = record
    Symbols: TArray<TDelphiSemanticIndexedSymbol>;
    References: TArray<TDelphiSemanticIndexedReference>;
  end;

  TDelphiSemanticProjectSymbolIndexer = record
  public
    class function Build(const aContext: TDelphiSemanticSymbolQueryContext):
      TDelphiSemanticProjectSymbolIndex; static;
  end;

implementation

uses
  System.Generics.Collections, System.SysUtils;

type
  TDelphiSemanticSymbolList = TList<TDelphiSemanticIndexedSymbol>;

function MakeSymbolId(const aModel: TDelphiSemanticUnitModel; const aKind, aOwnerName,
  aName: string; const aLine, aColumn, aOrdinal: Integer): TDelphiSemanticSymbolId;
begin
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
  const aSectionKind, aVisibility: string; const aLine, aColumn: Integer);
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if aName = '' then
    Exit;

  lSymbol := Default(TDelphiSemanticIndexedSymbol);
  lSymbol.Id := MakeSymbolId(aModel, aKind, aOwnerName, aName, aLine, aColumn,
    aSymbols.Count);
  lSymbol.Name := aName;
  lSymbol.Kind := aKind;
  lSymbol.OwnerName := aOwnerName;
  lSymbol.UnitName := aModel.UnitName;
  lSymbol.SectionKind := aSectionKind;
  lSymbol.SourceKind := aSourceKind;
  lSymbol.Visibility := aVisibility;
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
  AddSymbol(aSymbols, aModel, aSourceKind, 'unit', '', aModel.UnitName, 'interface', '', 1, 1);

  for lDeclaration in aModel.Declarations do
    AddSymbol(aSymbols, aModel, aSourceKind, lDeclaration.Kind, '', lDeclaration.Name,
      lDeclaration.SectionKind, '', lDeclaration.Line, lDeclaration.Column);

  for lRoutine in aModel.Routines do
    AddSymbol(aSymbols, aModel, aSourceKind, 'routine', lRoutine.OwnerName, lRoutine.Name,
      lRoutine.SectionKind, '', lRoutine.Line, lRoutine.Column);

  for lMember in aModel.Members do
    AddSymbol(aSymbols, aModel, aSourceKind, lMember.Kind, lMember.OwnerName, lMember.Name,
      '', lMember.Visibility, lMember.Line, lMember.Column);

  for lLocal in aModel.Locals do
    AddSymbol(aSymbols, aModel, aSourceKind, lLocal.Kind, lLocal.RoutineName, lLocal.Name,
      '', '', lLocal.Line, lLocal.Column);
end;

function ReferenceConfidence(const aReferenceName: string;
  const aCandidates: TList<TDelphiSemanticSymbolId>;
  const aSymbols: TDelphiSemanticSymbolList): string;
var
  lCandidate: TDelphiSemanticSymbolId;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  if aCandidates.Count = 0 then
    Exit('no-candidates');

  for lCandidate in aCandidates do
    for lSymbol in aSymbols do
      if (lSymbol.Id.Value = lCandidate.Value) and (lSymbol.Name = aReferenceName) then
        Exit('exact-name-match');

  Result := 'case-insensitive-name-match';
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

function SymbolIsVisibleFromReference(const aReferenceModel: TDelphiSemanticUnitModel;
  const aReference: TDelphiSemanticReference; const aSymbol: TDelphiSemanticIndexedSymbol):
  Boolean;
var
  lSectionKind: string;
begin
  if not ((aSymbol.OwnerName = '') and (SameText(aSymbol.Kind, 'unit') or
    SameText(aSymbol.Kind, 'type') or SameText(aSymbol.Kind, 'type-alias') or
    SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'const') or
    SameText(aSymbol.Kind, 'routine'))) then
    Exit(False);

  lSectionKind := aReference.SectionKind;
  if lSectionKind = '' then
    lSectionKind := 'implementation';

  if not UnitNameIsUsedBySection(aReferenceModel, lSectionKind, aSymbol.UnitName) then
    Exit(False);

  if SameText(aReferenceModel.UnitName, aSymbol.UnitName) then
    Exit(SameText(lSectionKind, 'implementation') or SameText(aSymbol.SectionKind, 'interface') or
      SameText(aSymbol.Kind, 'unit'));

  Result := SameText(aSymbol.SectionKind, 'interface') or SameText(aSymbol.Kind, 'unit');
end;

procedure ResolveReference(const aSymbols: TDelphiSemanticSymbolList;
  const aModel: TDelphiSemanticUnitModel; const aReference: TDelphiSemanticReference;
  var aIndexedReference: TDelphiSemanticIndexedReference);
var
  lCandidateIds: TList<TDelphiSemanticSymbolId>;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lCandidateIds := TList<TDelphiSemanticSymbolId>.Create;
  try
    for lSymbol in aSymbols do
      if SameText(lSymbol.Name, aReference.Name) and SymbolIsVisibleFromReference(aModel,
        aReference, lSymbol) then
        lCandidateIds.Add(lSymbol.Id);

    aIndexedReference.CandidateSymbolIds := lCandidateIds.ToArray;
    aIndexedReference.Confidence := ReferenceConfidence(aReference.Name, lCandidateIds,
      aSymbols);
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

procedure AddModelReferences(const aSymbols: TDelphiSemanticSymbolList;
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
    ResolveReference(aSymbols, aModel, lReference, lIndexedReference);
    aReferences.Add(lIndexedReference);
  end;
end;

class function TDelphiSemanticProjectSymbolIndexer.Build(
  const aContext: TDelphiSemanticSymbolQueryContext): TDelphiSemanticProjectSymbolIndex;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lReferences: TList<TDelphiSemanticIndexedReference>;
  lSymbols: TDelphiSemanticSymbolList;
begin
  lSymbols := TDelphiSemanticSymbolList.Create;
  lReferences := TList<TDelphiSemanticIndexedReference>.Create;
  try
    AddModelSymbols(lSymbols, aContext.UnitModel, 'project-source');
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      AddModelSymbols(lSymbols, lModel, IndexedSourceKind(aContext, i));
    end;

    AddModelReferences(lSymbols, lReferences, aContext.UnitModel, 'project-source');
    for i := 0 to High(aContext.IndexedUnitModels) do
    begin
      lModel := aContext.IndexedUnitModels[i];
      AddModelReferences(lSymbols, lReferences, lModel, IndexedSourceKind(aContext, i));
    end;

    Result.Symbols := lSymbols.ToArray;
    Result.References := lReferences.ToArray;
  finally
    lReferences.Free;
    lSymbols.Free;
  end;
end;

end.
