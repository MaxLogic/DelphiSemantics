unit DelphiSemantics.Search;

interface

uses
  DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  TDelphiSemanticSearchQuery = record
    Pattern: string;
    DeclarationKind: string;
    OwnerName: string;
    Scope: string;
    UnitName: string;
    ResolvedSymbolName: string;
    Limit: Integer;
  end;

  TDelphiSemanticSearchMatch = record
    SymbolId: TDelphiSemanticSymbolId;
    Name: string;
    Kind: string;
    OwnerName: string;
    UnitName: string;
    Scope: string;
    SourceKind: string;
    MatchKind: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticSearchResult = record
    Status: string;
    Diagnostic: string;
    Matches: TArray<TDelphiSemanticSearchMatch>;
  end;

  TDelphiSemanticSearch = record
  public
    class function Search(const aContext: TDelphiSemanticSymbolQueryContext;
      const aQuery: TDelphiSemanticSearchQuery): TDelphiSemanticSearchResult; static;
  end;

implementation

uses
  System.Generics.Collections, System.StrUtils, System.SysUtils,
  DelphiSemantics.Index, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.QuerySupport;

function MakeBlockedResult(const aDiagnostic: string): TDelphiSemanticSearchResult;
begin
  Result := Default(TDelphiSemanticSearchResult);
  Result.Status := 'blocked';
  Result.Diagnostic := aDiagnostic;
end;

function PatternMatches(const aPattern, aName: string): Boolean;
begin
  Result := (aPattern = '') or ContainsText(aName, aPattern);
end;

function SymbolMatchesFilters(const aSymbol: TDelphiSemanticIndexedSymbol;
  const aQuery: TDelphiSemanticSearchQuery): Boolean;
begin
  if not PatternMatches(aQuery.Pattern, aSymbol.Name) then
    Exit(False);
  if (aQuery.DeclarationKind <> '') and not SameText(aSymbol.Kind, aQuery.DeclarationKind) then
    Exit(False);
  if (aQuery.OwnerName <> '') and not SameText(aSymbol.OwnerName, aQuery.OwnerName) then
    Exit(False);
  if (aQuery.Scope <> '') and not SameText(aSymbol.SectionKind, aQuery.Scope) then
    Exit(False);
  if (aQuery.UnitName <> '') and not SameText(aSymbol.UnitName, aQuery.UnitName) then
    Exit(False);

  Result := True;
end;

function MakeMatch(const aSymbol: TDelphiSemanticIndexedSymbol; const aMatchKind: string):
  TDelphiSemanticSearchMatch;
begin
  Result := Default(TDelphiSemanticSearchMatch);
  Result.SymbolId := aSymbol.Id;
  Result.Name := aSymbol.Name;
  Result.Kind := aSymbol.Kind;
  Result.OwnerName := aSymbol.OwnerName;
  Result.UnitName := aSymbol.UnitName;
  Result.Scope := aSymbol.SectionKind;
  Result.SourceKind := aSymbol.SourceKind;
  Result.MatchKind := aMatchKind;
  Result.FileName := aSymbol.FileName;
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
end;

function SnapshotUnitSymbolId(const aUnit: TUnitSnapshot): TDelphiSemanticSymbolId;
begin
  Result.Value := 'snapshot:' + IntToStr(Integer(aUnit.UnitId)) + ':unit';
end;

function SnapshotSourceKindForUnit(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): string;
var
  lSymbol: TSemanticSymbolFact;
begin
  Result := 'project-snapshot';
  if aUnit.SymbolCount <= 0 then
    Exit;

  lSymbol := aUnit.SymbolById(TSemanticSymbolId(1));
  if SnapshotText(aSnapshot, lSymbol.SourceKindId) <> '' then
    Result := SnapshotText(aSnapshot, lSymbol.SourceKindId);
end;

function SnapshotUnitIndexedSymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): TDelphiSemanticIndexedSymbol;
begin
  Result := Default(TDelphiSemanticIndexedSymbol);
  Result.Id := SnapshotUnitSymbolId(aUnit);
  Result.Name := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.Kind := 'unit';
  Result.UnitName := Result.Name;
  Result.SectionKind := 'interface';
  Result.SourceKind := SnapshotSourceKindForUnit(aSnapshot, aUnit);
  Result.FileName := SnapshotText(aSnapshot, aUnit.FileNameId);
  Result.Line := 1;
  Result.Column := 1;
end;

function SnapshotIndexedSymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aSymbolRef: TSemanticSymbolRef;
  const aSymbol: TSemanticSymbolFact): TDelphiSemanticIndexedSymbol;
var
  lKind: string;
begin
  lKind := SnapshotPublicSymbolKind(SnapshotText(aSnapshot, aSymbol.KindId));
  Result := Default(TDelphiSemanticIndexedSymbol);
  Result.Id := SnapshotSymbolId(aSymbolRef);
  Result.Name := SnapshotText(aSnapshot, aSymbol.NameId);
  Result.Kind := lKind;
  Result.OwnerName := SnapshotSymbolOwnerName(aSnapshot, aSymbol, lKind);
  Result.UnitName := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.SectionKind := SnapshotText(aSnapshot, aSymbol.SectionKindId);
  Result.SourceKind := SnapshotText(aSnapshot, aSymbol.SourceKindId);
  if Result.SourceKind = '' then
    Result.SourceKind := 'project-snapshot';
  Result.Visibility := SnapshotText(aSnapshot, aSymbol.VisibilityId);
  Result.Signature := SnapshotText(aSnapshot, aSymbol.SignatureId);
  Result.FileName := SnapshotText(aSnapshot, aUnit.FileNameId);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
end;

function TryResolveSymbolFilter(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aName: string; out aSymbolId: TDelphiSemanticSymbolId; out aDiagnostic: string):
  Boolean;
var
  lMatchCount: Integer;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  aSymbolId := Default(TDelphiSemanticSymbolId);
  aDiagnostic := '';
  lMatchCount := 0;
  for lSymbol in aIndex.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SourceKind, 'project-source') then
    begin
      Inc(lMatchCount);
      aSymbolId := lSymbol.Id;
    end;

  if lMatchCount = 1 then
    Exit(True);
  if lMatchCount = 0 then
    aDiagnostic := 'resolved-symbol-not-found'
  else
    aDiagnostic := 'resolved-symbol-ambiguous';
  Result := False;
end;

function TryResolveSnapshotSymbolFilter(const aSnapshot: TDelphiProjectSnapshot;
  const aName: string; out aSymbolId: TDelphiSemanticSymbolId; out aDiagnostic: string):
  Boolean;
var
  i: Integer;
  lMatchCount: Integer;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitIndex: Integer;
  lIndexedSymbol: TDelphiSemanticIndexedSymbol;
begin
  aSymbolId := Default(TDelphiSemanticSymbolId);
  aDiagnostic := '';
  lMatchCount := 0;
  for lUnitIndex := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(lUnitIndex);
    for i := 1 to lUnit.SymbolCount do
    begin
      lSymbol := lUnit.SymbolById(TSemanticSymbolId(i));
      if not SnapshotSymbolVisibleToPublicNameQuery(aSnapshot, lSymbol) then
        Continue;
      lSymbolRef.UnitId := lUnit.UnitId;
      lSymbolRef.SymbolId := lSymbol.Id;
      lIndexedSymbol := SnapshotIndexedSymbol(aSnapshot, lUnit, lSymbolRef, lSymbol);
      if SameText(lIndexedSymbol.Name, aName) and SameText(lIndexedSymbol.SourceKind,
        'project-source') then
      begin
        Inc(lMatchCount);
        aSymbolId := lIndexedSymbol.Id;
      end;
    end;
  end;

  if lMatchCount = 1 then
    Exit(True);
  if lMatchCount = 0 then
    aDiagnostic := 'resolved-symbol-not-found'
  else
    aDiagnostic := 'resolved-symbol-ambiguous';
  Result := False;
end;

function SearchSnapshot(const aSnapshot: TDelphiProjectSnapshot;
  const aQuery: TDelphiSemanticSearchQuery): TDelphiSemanticSearchResult;
var
  i: Integer;
  lDiagnostic: string;
  lLimit: Integer;
  lMatchKind: string;
  lMatches: TList<TDelphiSemanticSearchMatch>;
  lResolvedSymbolId: TDelphiSemanticSymbolId;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitIndex: Integer;
  lIndexedSymbol: TDelphiSemanticIndexedSymbol;
begin
  lMatchKind := 'syntax-only';
  lResolvedSymbolId := Default(TDelphiSemanticSymbolId);
  if aQuery.ResolvedSymbolName <> '' then
  begin
    if not TryResolveSnapshotSymbolFilter(aSnapshot, aQuery.ResolvedSymbolName,
      lResolvedSymbolId, lDiagnostic) then
      Exit(MakeBlockedResult(lDiagnostic));
    lMatchKind := 'semantic';
  end;

  lLimit := aQuery.Limit;
  if lLimit <= 0 then
    lLimit := 50;

  lMatches := TList<TDelphiSemanticSearchMatch>.Create;
  try
    for lUnitIndex := 0 to aSnapshot.UnitCount - 1 do
    begin
      lUnit := aSnapshot.UnitByIndex(lUnitIndex);
      for i := 1 to lUnit.SymbolCount do
      begin
        lSymbol := lUnit.SymbolById(TSemanticSymbolId(i));
        if not SnapshotSymbolVisibleToPublicNameQuery(aSnapshot, lSymbol) then
          Continue;
        lSymbolRef.UnitId := lUnit.UnitId;
        lSymbolRef.SymbolId := lSymbol.Id;
        lIndexedSymbol := SnapshotIndexedSymbol(aSnapshot, lUnit, lSymbolRef, lSymbol);
        if (aQuery.ResolvedSymbolName <> '') and
          (lIndexedSymbol.Id.Value <> lResolvedSymbolId.Value) then
          Continue;
        if not SymbolMatchesFilters(lIndexedSymbol, aQuery) then
          Continue;
        lMatches.Add(MakeMatch(lIndexedSymbol, lMatchKind));
        if lMatches.Count >= lLimit then
          Break;
      end;
      if lMatches.Count >= lLimit then
        Break;
    end;

    Result := Default(TDelphiSemanticSearchResult);
    Result.Status := 'resolved';
    Result.Matches := lMatches.ToArray;
  finally
    lMatches.Free;
  end;
end;

class function TDelphiSemanticSearch.Search(const aContext: TDelphiSemanticSymbolQueryContext;
  const aQuery: TDelphiSemanticSearchQuery): TDelphiSemanticSearchResult;
var
  lDiagnostic: string;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lLimit: Integer;
  lMatchKind: string;
  lMatches: TList<TDelphiSemanticSearchMatch>;
  lResolvedSymbolId: TDelphiSemanticSymbolId;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot <> nil then
    Exit(SearchSnapshot(lSnapshot, aQuery));

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  lMatchKind := 'syntax-only';
  lResolvedSymbolId := Default(TDelphiSemanticSymbolId);
  if aQuery.ResolvedSymbolName <> '' then
  begin
    if not TryResolveSymbolFilter(lIndex, aQuery.ResolvedSymbolName, lResolvedSymbolId,
      lDiagnostic) then
      Exit(MakeBlockedResult(lDiagnostic));
    lMatchKind := 'semantic';
  end;

  lLimit := aQuery.Limit;
  if lLimit <= 0 then
    lLimit := 50;

  lMatches := TList<TDelphiSemanticSearchMatch>.Create;
  try
    for lSymbol in lIndex.Symbols do
    begin
      if (aQuery.ResolvedSymbolName <> '') and
        (lSymbol.Id.Value <> lResolvedSymbolId.Value) then
        Continue;
      if not SymbolMatchesFilters(lSymbol, aQuery) then
        Continue;
      lMatches.Add(MakeMatch(lSymbol, lMatchKind));
      if lMatches.Count >= lLimit then
        Break;
    end;

    Result := Default(TDelphiSemanticSearchResult);
    Result.Status := 'resolved';
    Result.Matches := lMatches.ToArray;
  finally
    lMatches.Free;
  end;
end;

end.
