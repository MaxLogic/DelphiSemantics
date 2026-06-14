unit DelphiSemantics.Usage;

interface

uses
  DelphiSemantics.Index, DelphiSemantics.Query, DelphiSemantics.Symbols;

type
  TDelphiSemanticUsage = record
    Name: string;
    RoutineName: string;
    Role: string;
    SectionKind: string;
    SourceKind: string;
    FileName: string;
    UnitName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticUsageResult = record
    Status: string;
    Diagnostic: string;
    Symbol: TDelphiSemanticIndexedSymbol;
    Usages: TArray<TDelphiSemanticUsage>;
    IndexMetrics: TDelphiSemanticProjectSymbolIndexMetrics;
  end;

  TDelphiSemanticUsageFinder = record
  public
    class function FindUsagesAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
      const aFileName: string; const aLine, aColumn: Integer): TDelphiSemanticUsageResult;
      overload; static;
    class function FindUsagesAtPosition(const aIndex: TDelphiSemanticProjectSymbolIndex;
      const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string;
      const aLine, aColumn: Integer): TDelphiSemanticUsageResult; overload; static;
    class function FindUsagesByName(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName: string): TDelphiSemanticUsageResult; overload; static;
    class function FindUsagesByName(const aIndex: TDelphiSemanticProjectSymbolIndex;
      const aName: string): TDelphiSemanticUsageResult; overload; static;
  end;

implementation

uses
  System.Generics.Collections, System.StrUtils, System.SysUtils,
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.Snapshot.QuerySupport;

function MakeDiagnosticResult(const aStatus, aDiagnostic: string): TDelphiSemanticUsageResult;
begin
  Result := Default(TDelphiSemanticUsageResult);
  Result.Status := aStatus;
  Result.Diagnostic := aDiagnostic;
end;

function SnapshotEndLine(const aLine, aEndLine: Integer): Integer;
begin
  Result := aEndLine;
  if Result <= 0 then
    Result := aLine;
end;

function SnapshotEndColumn(const aColumn: Integer; const aName: string;
  const aEndColumn: Integer): Integer;
begin
  Result := aEndColumn;
  if Result <= 0 then
    Result := aColumn + Length(aName) - 1;
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

function FindSymbolById(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aId: TDelphiSemanticSymbolId; out aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
var
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  for lSymbol in aIndex.Symbols do
    if lSymbol.Id.Value = aId.Value then
    begin
      aSymbol := lSymbol;
      Exit(True);
    end;

  aSymbol := Default(TDelphiSemanticIndexedSymbol);
  Result := False;
end;

function SymbolMatchesName(const aSymbol: TDelphiSemanticIndexedSymbol; const aName: string):
  Boolean;
begin
  Result := (aSymbol.OwnerName = '') and (SameText(aSymbol.Kind, 'unit') or
    SameText(aSymbol.Kind, 'type') or SameText(aSymbol.Kind, 'type-alias') or
    SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'const') or
    SameText(aSymbol.Kind, 'routine')) and SameText(aSymbol.Name, aName);
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

function MakeUsage(const aReference: TDelphiSemanticIndexedReference): TDelphiSemanticUsage;
begin
  Result := Default(TDelphiSemanticUsage);
  Result.Name := aReference.Name;
  Result.RoutineName := aReference.RoutineName;
  Result.Role := 'reference';
  Result.SectionKind := aReference.SectionKind;
  Result.SourceKind := aReference.SourceKind;
  Result.FileName := aReference.FileName;
  Result.UnitName := aReference.UnitName;
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
end;

function MakeDeclarationUsage(const aSymbol: TDelphiSemanticIndexedSymbol): TDelphiSemanticUsage;
begin
  Result := Default(TDelphiSemanticUsage);
  Result.Name := aSymbol.Name;
  Result.Role := 'declaration';
  Result.SectionKind := aSymbol.SectionKind;
  Result.SourceKind := aSymbol.SourceKind;
  Result.FileName := aSymbol.FileName;
  Result.UnitName := aSymbol.UnitName;
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.Line;
  Result.EndColumn := aSymbol.Column + Length(aSymbol.Name) - 1;
end;

function MakeSnapshotReferenceUsage(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aReference: TSemanticReferenceFact): TDelphiSemanticUsage;
begin
  Result := Default(TDelphiSemanticUsage);
  Result.Name := SnapshotText(aSnapshot, aReference.NameId);
  Result.RoutineName := SnapshotText(aSnapshot, aReference.RoutineId);
  Result.Role := SnapshotText(aSnapshot, aReference.ClassificationId);
  if Result.Role = '' then
    Result.Role := 'reference';
  Result.SectionKind := SnapshotText(aSnapshot, aReference.SectionKindId);
  if Result.SectionKind = '' then
    Result.SectionKind := 'implementation';
  Result.SourceKind := SnapshotText(aSnapshot, aReference.SourceKindId);
  if Result.SourceKind = '' then
    Result.SourceKind := 'project-snapshot';
  Result.FileName := SnapshotText(aSnapshot, aUnit.FileNameId);
  Result.UnitName := SnapshotText(aSnapshot, aUnit.UnitNameId);
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := SnapshotEndLine(aReference.Line, aReference.EndLine);
  Result.EndColumn := SnapshotEndColumn(aReference.Column, Result.Name, aReference.EndColumn);
end;

function SnapshotSymbolMatchesUsageName(const aSymbol: TDelphiSemanticIndexedSymbol;
  const aName: string): Boolean;
begin
  Result := (aSymbol.OwnerName = '') and (SameText(aSymbol.Kind, 'unit') or
    SameText(aSymbol.Kind, 'type') or SameText(aSymbol.Kind, 'type-alias') or
    SameText(aSymbol.Kind, 'var') or SameText(aSymbol.Kind, 'const') or
    SameText(aSymbol.Kind, 'routine')) and SameText(aSymbol.Name, aName);
end;

function SnapshotSymbolRefInList(const aRefs: TList<TSemanticSymbolRef>;
  const aRef: TSemanticSymbolRef): Boolean;
var
  lRef: TSemanticSymbolRef;
begin
  for lRef in aRefs do
    if (lRef.UnitId = aRef.UnitId) and (lRef.SymbolId = aRef.SymbolId) then
      Exit(True);

  Result := False;
end;

procedure AddSnapshotSymbolRef(const aRefs: TList<TSemanticSymbolRef>;
  const aRef: TSemanticSymbolRef);
begin
  if not SnapshotSymbolRefInList(aRefs, aRef) then
    aRefs.Add(aRef);
end;

function TryFindSnapshotUsageSymbolByName(const aSnapshot: TDelphiProjectSnapshot;
  const aName: string; out aSymbolRef: TSemanticSymbolRef; out aSymbol:
  TDelphiSemanticIndexedSymbol): Boolean;
var
  i: Integer;
  lCount: Integer;
  lCandidate: TDelphiSemanticIndexedSymbol;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lNameId: TSemanticStringId;
  lSnapshotSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
begin
  aSymbolRef := Default(TSemanticSymbolRef);
  aSymbol := Default(TDelphiSemanticIndexedSymbol);
  if (aSnapshot = nil) or not aSnapshot.TryFindStringId(aName, lNameId) or
    not aSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex) then
    Exit(False);

  lCount := 0;
  for i := lLowIndex to lHighIndex do
  begin
    lSymbolRef := aSnapshot.SymbolRefByNameIndex(i);
    if not aSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
      Continue;
    lSnapshotSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
    lCandidate := SnapshotIndexedSymbol(aSnapshot, lUnit, lSymbolRef, lSnapshotSymbol);
    if not SnapshotSymbolMatchesUsageName(lCandidate, aName) then
      Continue;

    Inc(lCount);
    if lCount = 1 then
    begin
      aSymbolRef := lSymbolRef;
      aSymbol := lCandidate;
    end else
    begin
      aSymbolRef := Default(TSemanticSymbolRef);
      aSymbol := Default(TDelphiSemanticIndexedSymbol);
      Exit(False);
    end;
  end;

  Result := lCount = 1;
end;

function SymbolIsMethodPair(const aLeft, aRight: TDelphiSemanticIndexedSymbol): Boolean; forward;

function BuildSnapshotResultForSymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbolRef: TSemanticSymbolRef; const aSymbol: TDelphiSemanticIndexedSymbol):
  TDelphiSemanticUsageResult;
var
  i: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lEquivalentRef: TSemanticSymbolRef;
  lEquivalentRefs: TList<TSemanticSymbolRef>;
  lEquivalentSnapshotSymbol: TSemanticSymbolFact;
  lEquivalentSymbol: TDelphiSemanticIndexedSymbol;
  lOriginalSymbol: TSemanticSymbolFact;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lUnit: TUnitSnapshot;
  lUsages: TList<TDelphiSemanticUsage>;
begin
  lEquivalentRefs := TList<TSemanticSymbolRef>.Create;
  lUsages := TList<TDelphiSemanticUsage>.Create;
  try
    AddSnapshotSymbolRef(lEquivalentRefs, aSymbolRef);
    if aSnapshot.TryFindUnitById(aSymbolRef.UnitId, lUnit) then
    begin
      lOriginalSymbol := lUnit.SymbolById(aSymbolRef.SymbolId);
      if aSnapshot.TryRoutineMethodEquivalents(lOriginalSymbol, lLowIndex, lHighIndex) then
        for i := lLowIndex to lHighIndex do
        begin
          lEquivalentRef := aSnapshot.RoutineMethodEquivalentRefByIndex(i);
          if SnapshotSymbolRefInList(lEquivalentRefs, lEquivalentRef) then
            Continue;
          if not aSnapshot.TryFindUnitById(lEquivalentRef.UnitId, lUnit) then
            Continue;
          lEquivalentSnapshotSymbol := lUnit.SymbolById(lEquivalentRef.SymbolId);
          lEquivalentSymbol := SnapshotIndexedSymbol(aSnapshot, lUnit, lEquivalentRef,
            lEquivalentSnapshotSymbol);
          if SymbolIsMethodPair(lEquivalentSymbol, aSymbol) then
            AddSnapshotSymbolRef(lEquivalentRefs, lEquivalentRef);
        end;
    end;

    for lEquivalentRef in lEquivalentRefs do
      if aSnapshot.TryFindUnitById(lEquivalentRef.UnitId, lUnit) then
      begin
        lEquivalentSnapshotSymbol := lUnit.SymbolById(lEquivalentRef.SymbolId);
        lEquivalentSymbol := SnapshotIndexedSymbol(aSnapshot, lUnit, lEquivalentRef,
          lEquivalentSnapshotSymbol);
        lUsages.Add(MakeDeclarationUsage(lEquivalentSymbol));
      end;

    for lEquivalentRef in lEquivalentRefs do
      if aSnapshot.TryReferencesForSymbol(lEquivalentRef, lLowIndex, lHighIndex) then
        for i := lLowIndex to lHighIndex do
        begin
          lReferenceRef := aSnapshot.ReferenceRefBySymbolIndex(i);
          if not aSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit) then
            Continue;
          lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
          lUsages.Add(MakeSnapshotReferenceUsage(aSnapshot, lUnit, lReference));
        end;

    Result := Default(TDelphiSemanticUsageResult);
    Result.Status := 'resolved';
    Result.Symbol := aSymbol;
    Result.Usages := lUsages.ToArray;
    Result.IndexMetrics.BuildInvocationCount := 0;
  finally
    lUsages.Free;
    lEquivalentRefs.Free;
  end;
end;

function FindSnapshotUsagesByName(const aContext: TDelphiSemanticSymbolQueryContext;
  const aName: string): TDelphiSemanticUsageResult;
var
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolRef: TSemanticSymbolRef;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot = nil then
    Exit(MakeDiagnosticResult('unresolved', 'No project snapshot is available.'));

  if not TryFindSnapshotUsageSymbolByName(lSnapshot, aName, lSymbolRef, lSymbol) then
    Exit(MakeDiagnosticResult('unresolved', 'No visible symbol named "' + aName +
      '" was found.'));

  Result := BuildSnapshotResultForSymbol(lSnapshot, lSymbolRef, lSymbol);
end;

function FindSnapshotUsagesAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
  const aFileName: string; const aLine, aColumn: Integer): TDelphiSemanticUsageResult;
var
  lPositionResolution: TDelphiSemanticSnapshotPositionResolution;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot = nil then
    Exit(MakeDiagnosticResult('unresolved', 'No project snapshot is available.'));
  if not TryResolveSnapshotPosition(lSnapshot, aFileName, aLine, aColumn, '',
    lPositionResolution) then
    Exit(MakeDiagnosticResult('not-found', 'No symbol found at the requested position.'));

  lSymbol := SnapshotIndexedSymbol(lSnapshot, lPositionResolution.SymbolUnit,
    lPositionResolution.SymbolRef, lPositionResolution.Symbol);
  Result := BuildSnapshotResultForSymbol(lSnapshot, lPositionResolution.SymbolRef, lSymbol);
end;

function SymbolIsMethodPair(const aLeft, aRight: TDelphiSemanticIndexedSymbol): Boolean;
begin
  Result := SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.OwnerName, aRight.OwnerName) and SameText(aLeft.Name, aRight.Name) and
    ((SameText(aLeft.Kind, 'method') and SameText(aRight.Kind, 'routine')) or
    (SameText(aLeft.Kind, 'routine') and SameText(aRight.Kind, 'method')));
end;

function ReferenceMatchesSymbol(const aReference: TDelphiSemanticIndexedReference;
  const aSymbol: TDelphiSemanticIndexedSymbol): Boolean;
begin
  if (aReference.Status = 'resolved') and (aReference.SymbolId.Value = aSymbol.Id.Value) then
    Exit(True);

  Result := SameText(aSymbol.Kind, 'var') and (aSymbol.OwnerName <> '') and
    SameText(aReference.Name, aSymbol.Name) and SameText(aReference.UnitName, aSymbol.UnitName) and
    SameText(aReference.RoutineName, aSymbol.OwnerName);
end;

function BuildResultForSymbol(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aSymbol: TDelphiSemanticIndexedSymbol): TDelphiSemanticUsageResult;
var
  lSymbol: TDelphiSemanticIndexedSymbol;
  lReference: TDelphiSemanticIndexedReference;
  lUsages: TList<TDelphiSemanticUsage>;
begin
  lUsages := TList<TDelphiSemanticUsage>.Create;
  try
    for lSymbol in aIndex.Symbols do
      if (lSymbol.Id.Value = aSymbol.Id.Value) or SymbolIsMethodPair(lSymbol, aSymbol) then
        lUsages.Add(MakeDeclarationUsage(lSymbol));
    for lReference in aIndex.References do
      if ReferenceMatchesSymbol(lReference, aSymbol) then
        lUsages.Add(MakeUsage(lReference));

    Result := Default(TDelphiSemanticUsageResult);
    Result.Status := 'resolved';
    Result.Symbol := aSymbol;
    Result.Usages := lUsages.ToArray;
    Result.IndexMetrics := aIndex.Metrics;
  finally
    lUsages.Free;
  end;
end;

function ResolveSymbolByName(const aIndex: TDelphiSemanticProjectSymbolIndex; const aName: string;
  out aSymbol: TDelphiSemanticIndexedSymbol; out aDiagnostic: string): string;
var
  lCount: Integer;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolIds: TList<TDelphiSemanticSymbolId>;
begin
  lCount := 0;
  aDiagnostic := '';
  lSymbolIds := TList<TDelphiSemanticSymbolId>.Create;
  try
    for lSymbol in aIndex.Symbols do
      if SymbolMatchesName(lSymbol, aName) and not SymbolIdInList(lSymbolIds, lSymbol.Id) then
      begin
        Inc(lCount);
        lSymbolIds.Add(lSymbol.Id);
        if lCount = 1 then
          aSymbol := lSymbol;
      end;
  finally
    lSymbolIds.Free;
  end;

  if lCount = 1 then
    Exit('resolved');
  if lCount > 1 then
  begin
    aSymbol := Default(TDelphiSemanticIndexedSymbol);
    aDiagnostic := 'Multiple visible symbols named "' + aName + '" were found.';
    Exit('ambiguous');
  end;

  aSymbol := Default(TDelphiSemanticIndexedSymbol);
  aDiagnostic := 'No visible symbol named "' + aName + '" was found.';
  Result := 'unresolved';
end;

function ResolveSymbolByDefinition(const aIndex: TDelphiSemanticProjectSymbolIndex;
  const aDefinition: TDelphiSemanticSymbolQueryResult; out aSymbol: TDelphiSemanticIndexedSymbol;
  out aDiagnostic: string): string;
var
  lCount: Integer;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lCount := 0;
  aDiagnostic := '';
  for lSymbol in aIndex.Symbols do
    if SameText(lSymbol.Name, aDefinition.Name) and
      (SameText(lSymbol.Kind, aDefinition.Kind) or
      (SameText(lSymbol.Kind, 'routine') and SameText(aDefinition.Kind, 'method'))) and
      SameText(lSymbol.UnitName, aDefinition.UnitName) and (lSymbol.Line = aDefinition.Line) and
      (lSymbol.Column = aDefinition.Column) then
    begin
      Inc(lCount);
      aSymbol := lSymbol;
    end;

  if lCount = 1 then
    Exit('resolved');

  if lCount > 1 then
  begin
    aSymbol := Default(TDelphiSemanticIndexedSymbol);
    aDiagnostic := 'Multiple indexed symbols match the requested source position.';
    Exit('ambiguous');
  end;

  aSymbol := Default(TDelphiSemanticIndexedSymbol);
  aDiagnostic := 'No indexed symbol matches the requested source position.';
  Result := 'unresolved';
end;

class function TDelphiSemanticUsageFinder.FindUsagesAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer): TDelphiSemanticUsageResult;
var
  lIndex: TDelphiSemanticProjectSymbolIndex;
begin
  if ContextProjectSnapshot(aContext) <> nil then
    Exit(FindSnapshotUsagesAtPosition(aContext, aFileName, aLine, aColumn));

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  Result := FindUsagesAtPosition(lIndex, aContext, aFileName, aLine, aColumn);
  Result.IndexMetrics := lIndex.Metrics;
end;

class function TDelphiSemanticUsageFinder.FindUsagesAtPosition(
  const aIndex: TDelphiSemanticProjectSymbolIndex; const aContext:
  TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer): TDelphiSemanticUsageResult;
var
  lDefinition: TDelphiSemanticSymbolQueryResult;
  lDiagnostic: string;
  lStatus: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lDefinition := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(aContext, aFileName, aLine,
    aColumn);
  if not lDefinition.Found then
  begin
    Result := MakeDiagnosticResult(lDefinition.Status, 'No symbol found at the requested position.');
    Result.IndexMetrics := aIndex.Metrics;
    Exit;
  end;

  lStatus := ResolveSymbolByDefinition(aIndex, lDefinition, lSymbol, lDiagnostic);
  if lStatus <> 'resolved' then
  begin
    Result := MakeDiagnosticResult(lStatus, lDiagnostic);
    Result.IndexMetrics := aIndex.Metrics;
    Exit;
  end;

  Result := BuildResultForSymbol(aIndex, lSymbol);
end;

class function TDelphiSemanticUsageFinder.FindUsagesByName(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string):
  TDelphiSemanticUsageResult;
var
  lIndex: TDelphiSemanticProjectSymbolIndex;
begin
  if ContextProjectSnapshot(aContext) <> nil then
    Exit(FindSnapshotUsagesByName(aContext, aName));

  lIndex := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
  Result := FindUsagesByName(lIndex, aName);
  Result.IndexMetrics := lIndex.Metrics;
end;

class function TDelphiSemanticUsageFinder.FindUsagesByName(
  const aIndex: TDelphiSemanticProjectSymbolIndex; const aName: string):
  TDelphiSemanticUsageResult;
var
  lDiagnostic: string;
  lStatus: string;
  lSymbol: TDelphiSemanticIndexedSymbol;
begin
  lStatus := ResolveSymbolByName(aIndex, aName, lSymbol, lDiagnostic);
  if lStatus <> 'resolved' then
  begin
    Result := MakeDiagnosticResult(lStatus, lDiagnostic);
    Result.IndexMetrics := aIndex.Metrics;
    Exit;
  end;

  Result := BuildResultForSymbol(aIndex, lSymbol);
end;

end.
