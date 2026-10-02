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
    // Why an occurrence in Unresolved could not be classified; empty for proven usages.
    Reason: string;
  end;

  TDelphiSemanticUsageResult = record
    Status: string;
    Diagnostic: string;
    Symbol: TDelphiSemanticIndexedSymbol;
    Usages: TArray<TDelphiSemanticUsage>;
    // Same-name occurrences that are proven neither to be nor not to be the symbol (role
    // 'unresolved'). Filled for project-snapshot results.
    Unresolved: TArray<TDelphiSemanticUsage>;
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
    // Refuses a resolved result whose declaring unit lacks syntax-verified facts.
    class function RequireVerifiedDeclaringUnit(const aContext: TDelphiSemanticSymbolQueryContext;
      const aResult: TDelphiSemanticUsageResult): TDelphiSemanticUsageResult; static;
    // True when the symbol's declaring unit (matched by file, else by unit name) has a scope
    // status other than ast, so its member and reference facts are unverified.
    class function TryFindUnverifiedDeclaringUnit(
      const aContext: TDelphiSemanticSymbolQueryContext;
      const aSymbol: TDelphiSemanticIndexedSymbol; out aUnitName, aScopeStatus: string):
      Boolean; static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.StrUtils, System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Model.Text, DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.Snapshot.QuerySupport;

function MakeDiagnosticResult(const aStatus, aDiagnostic: string): TDelphiSemanticUsageResult;
begin
  Result := Default(TDelphiSemanticUsageResult);
  Result.Status := aStatus;
  Result.Diagnostic := aDiagnostic;
end;

// Usages and renames need complete syntax facts for the declaring unit. A unit whose syntax
// tree failed (members from an unverified line scan) or covers only the interface cannot
// prove its member ownership or every reference, so the result becomes unknown.
function UnverifiedDeclarationResult(const aSymbolName, aUnitName,
  aScopeStatus: string): TDelphiSemanticUsageResult;
begin
  Result := MakeDiagnosticResult('unknown', 'Symbol "' + aSymbolName + '" is declared in unit "' +
    aUnitName + '" whose syntax facts are unverified (scope status: ' + aScopeStatus +
    '); its usages cannot be proven.');
end;

// Extraction always records a scope status. Only hand-built facts without scope metadata
// (an empty status) are left to their builder.
function IsVerifiedScopeStatus(const aScopeStatus: string): Boolean;
begin
  Result := (aScopeStatus = '') or SameText(aScopeStatus, 'ast');
end;

function GateSnapshotDeclaringUnit(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aResult: TDelphiSemanticUsageResult):
  TDelphiSemanticUsageResult;
var
  lStatus: string;
begin
  Result := aResult;
  if (aUnit = nil) or (aResult.Status <> 'resolved') then
    Exit;
  lStatus := SnapshotText(aSnapshot, aUnit.ScopeModelStatusId);
  if not IsVerifiedScopeStatus(lStatus) then
  begin
    Result := UnverifiedDeclarationResult(aResult.Symbol.Name,
      SnapshotText(aSnapshot, aUnit.UnitNameId), lStatus);
    Result.IndexMetrics := aResult.IndexMetrics;
  end;
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

function UsageRoleRank(const aRole: string): Integer;
begin
  if SameText(aRole, 'declaration') then
    Exit(0);

  Result := 1;
end;

function CompareIntegerValues(const aLeft, aRight: Integer): Integer;
begin
  if aLeft < aRight then
    Exit(-1);
  if aLeft > aRight then
    Exit(1);

  Result := 0;
end;

function CompareStringValues(const aLeft, aRight: string): Integer;
begin
  Result := CompareText(aLeft, aRight);
  if Result = 0 then
    Result := CompareStr(aLeft, aRight);
end;

function CompareUsages(const aLeft, aRight: TDelphiSemanticUsage): Integer;
begin
  Result := CompareIntegerValues(UsageRoleRank(aLeft.Role), UsageRoleRank(aRight.Role));
  if Result <> 0 then
    Exit;

  Result := CompareStringValues(aLeft.FileName, aRight.FileName);
  if Result <> 0 then
    Exit;
  Result := CompareStringValues(aLeft.UnitName, aRight.UnitName);
  if Result <> 0 then
    Exit;
  Result := CompareIntegerValues(aLeft.Line, aRight.Line);
  if Result <> 0 then
    Exit;
  Result := CompareIntegerValues(aLeft.Column, aRight.Column);
  if Result <> 0 then
    Exit;
  Result := CompareIntegerValues(aLeft.EndLine, aRight.EndLine);
  if Result <> 0 then
    Exit;
  Result := CompareIntegerValues(aLeft.EndColumn, aRight.EndColumn);
  if Result <> 0 then
    Exit;
  Result := CompareStringValues(aLeft.Role, aRight.Role);
  if Result <> 0 then
    Exit;
  Result := CompareStringValues(aLeft.Name, aRight.Name);
  if Result <> 0 then
    Exit;
  Result := CompareStringValues(aLeft.RoutineName, aRight.RoutineName);
  if Result <> 0 then
    Exit;
  Result := CompareStringValues(aLeft.SectionKind, aRight.SectionKind);
  if Result <> 0 then
    Exit;

  Result := CompareStringValues(aLeft.SourceKind, aRight.SourceKind);
end;

function SameUsageRange(const aLeft, aRight: TDelphiSemanticUsage): Boolean;
begin
  Result := SameText(aLeft.FileName, aRight.FileName) and
    SameText(aLeft.UnitName, aRight.UnitName) and SameText(aLeft.Role, aRight.Role) and
    SameText(aLeft.Name, aRight.Name) and SameText(aLeft.RoutineName, aRight.RoutineName) and
    SameText(aLeft.SectionKind, aRight.SectionKind) and
    SameText(aLeft.SourceKind, aRight.SourceKind) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column) and (aLeft.EndLine = aRight.EndLine) and
    (aLeft.EndColumn = aRight.EndColumn);
end;

function SortedUsages(const aUsages: TList<TDelphiSemanticUsage>): TArray<TDelphiSemanticUsage>;
var
  i: Integer;
  lCount: Integer;
  lSorted: TArray<TDelphiSemanticUsage>;
begin
  lSorted := aUsages.ToArray;
  TArray.Sort<TDelphiSemanticUsage>(lSorted,
    TComparer<TDelphiSemanticUsage>.Construct(CompareUsages));
  SetLength(Result, Length(lSorted));
  lCount := 0;
  for i := 0 to High(lSorted) do
    if (i = 0) or not SameUsageRange(lSorted[i], lSorted[i - 1]) then
    begin
      Result[lCount] := lSorted[i];
      Inc(lCount);
    end;
  SetLength(Result, lCount);
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
  Result.FileName := SnapshotFactFileName(aSnapshot, aUnit, aReference.FileId);
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

function NormalizedSymbolSignature(const aSignature: string): string; forward;
function SymbolIsMethodPair(const aLeft, aRight: TDelphiSemanticIndexedSymbol): Boolean; forward;

function SnapshotUsageRoutineSimpleName(const aRoutineName: string): string;
var
  lIndex: Integer;
begin
  lIndex := LastDelimiter('.', aRoutineName);
  if lIndex > 0 then
    Exit(Copy(aRoutineName, lIndex + 1, MaxInt));

  Result := aRoutineName;
end;

function SnapshotSymbolKindIs(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact; const aKind: string): Boolean;
begin
  Result := SameText(SnapshotText(aSnapshot, aSymbol.KindId), aKind);
end;

function SnapshotSignaturesMatch(const aLeft, aRight: string): Boolean;
begin
  if (aLeft = '') or (aRight = '') then
    Exit(True);

  Result := NormalizedSymbolSignature(aLeft) = NormalizedSymbolSignature(aRight);
end;

function TryFindSnapshotRoutineForParameter(const aSnapshot: TDelphiProjectSnapshot;
  const aParameterRef: TSemanticSymbolRef; const aParameter: TSemanticSymbolFact;
  out aRoutineRef: TSemanticSymbolRef; out aRoutineUnit: TUnitSnapshot;
  out aRoutine: TSemanticSymbolFact): Boolean;
var
  i: Integer;
  lCandidate: TSemanticSymbolFact;
  lCandidateRef: TSemanticSymbolRef;
  lCandidateUnit: TUnitSnapshot;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lNameId: TSemanticStringId;
  lRoutineName: string;
begin
  Result := False;
  aRoutineRef := Default(TSemanticSymbolRef);
  aRoutineUnit := nil;
  aRoutine := Default(TSemanticSymbolFact);
  if not SnapshotSymbolKindIs(aSnapshot, aParameter, 'parameter') then
    Exit;

  lRoutineName := SnapshotText(aSnapshot, aParameter.RoutineId);
  if lRoutineName = '' then
    Exit;
  if not aSnapshot.TryFindStringId(SnapshotUsageRoutineSimpleName(lRoutineName),
    lNameId) then
    Exit;
  if not aSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex) then
    Exit;

  for i := lLowIndex to lHighIndex do
  begin
    lCandidateRef := aSnapshot.SymbolRefByNameIndex(i);
    if lCandidateRef.UnitId <> aParameterRef.UnitId then
      Continue;
    if not aSnapshot.TryFindUnitById(lCandidateRef.UnitId, lCandidateUnit) then
      Continue;

    lCandidate := lCandidateUnit.SymbolById(lCandidateRef.SymbolId);
    if not SnapshotSymbolKindIs(aSnapshot, lCandidate, 'routine') then
      Continue;
    if not SameText(SnapshotText(aSnapshot, lCandidate.RoutineId), lRoutineName) then
      Continue;
    if (aParameter.Line > 0) and (lCandidate.Line > aParameter.Line) then
      Continue;
    if Result and (lCandidate.Line < aRoutine.Line) then
      Continue;

    aRoutineRef := lCandidateRef;
    aRoutineUnit := lCandidateUnit;
    aRoutine := lCandidate;
    Result := True;
  end;
end;

procedure AddSnapshotParametersForRoutine(const aSnapshot: TDelphiProjectSnapshot;
  const aRoutineRef: TSemanticSymbolRef; const aRoutine,
  aOriginalParameter: TSemanticSymbolFact; const aRefs: TList<TSemanticSymbolRef>);
var
  i: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lParameter: TSemanticSymbolFact;
  lParameterRef: TSemanticSymbolRef;
  lParameterUnit: TUnitSnapshot;
  lRoutineSignature: string;
begin
  if not aSnapshot.TrySymbolsByName(aOriginalParameter.NameId, lLowIndex,
    lHighIndex) then
    Exit;

  lRoutineSignature := SnapshotText(aSnapshot, aRoutine.SignatureId);
  for i := lLowIndex to lHighIndex do
  begin
    lParameterRef := aSnapshot.SymbolRefByNameIndex(i);
    if lParameterRef.UnitId <> aRoutineRef.UnitId then
      Continue;
    if not aSnapshot.TryFindUnitById(lParameterRef.UnitId, lParameterUnit) then
      Continue;

    lParameter := lParameterUnit.SymbolById(lParameterRef.SymbolId);
    if not SnapshotSymbolKindIs(aSnapshot, lParameter, 'parameter') then
      Continue;
    if lParameter.RoutineId <> aRoutine.RoutineId then
      Continue;
    if not SnapshotSignaturesMatch(lRoutineSignature,
      SnapshotText(aSnapshot, lParameter.SignatureId)) then
      Continue;

    AddSnapshotSymbolRef(aRefs, lParameterRef);
  end;
end;

procedure AddSnapshotParameterEquivalentRefs(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbolRef: TSemanticSymbolRef; const aSymbol: TSemanticSymbolFact;
  const aRefs: TList<TSemanticSymbolRef>);
var
  i: Integer;
  lEquivalentRef: TSemanticSymbolRef;
  lEquivalentRoutine: TSemanticSymbolFact;
  lEquivalentRoutineSymbol: TDelphiSemanticIndexedSymbol;
  lEquivalentUnit: TUnitSnapshot;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lRoutine: TSemanticSymbolFact;
  lRoutineRef: TSemanticSymbolRef;
  lRoutineSymbol: TDelphiSemanticIndexedSymbol;
  lRoutineUnit: TUnitSnapshot;
begin
  if not TryFindSnapshotRoutineForParameter(aSnapshot, aSymbolRef, aSymbol,
    lRoutineRef, lRoutineUnit, lRoutine) then
    Exit;

  lRoutineSymbol := SnapshotIndexedSymbol(aSnapshot, lRoutineUnit, lRoutineRef,
    lRoutine);
  if not aSnapshot.TryRoutineMethodEquivalents(lRoutine, lLowIndex,
    lHighIndex) then
    Exit;

  for i := lLowIndex to lHighIndex do
  begin
    lEquivalentRef := aSnapshot.RoutineMethodEquivalentRefByIndex(i);
    if not aSnapshot.TryFindUnitById(lEquivalentRef.UnitId, lEquivalentUnit) then
      Continue;

    lEquivalentRoutine := lEquivalentUnit.SymbolById(lEquivalentRef.SymbolId);
    lEquivalentRoutineSymbol := SnapshotIndexedSymbol(aSnapshot, lEquivalentUnit,
      lEquivalentRef, lEquivalentRoutine);
    if not SymbolIsMethodPair(lEquivalentRoutineSymbol, lRoutineSymbol) then
      Continue;

    AddSnapshotParametersForRoutine(aSnapshot, lEquivalentRef,
      lEquivalentRoutine, aSymbol, aRefs);
  end;
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

    if lCount = 0 then
    begin
      Inc(lCount);
      aSymbolRef := lSymbolRef;
      aSymbol := lCandidate;
    end else if SymbolIsMethodPair(lCandidate, aSymbol) then
    begin
      Continue;
    end else
    begin
      aSymbolRef := Default(TSemanticSymbolRef);
      aSymbol := Default(TDelphiSemanticIndexedSymbol);
      Exit(False);
    end;
  end;

  Result := lCount = 1;
end;

function SnapshotPositionKey(const aFileName: string; const aLine, aColumn: Integer): string;
begin
  Result := LowerCase(aFileName) + '|' + aLine.ToString + '|' + aColumn.ToString;
end;

function SameSnapshotSymbolRef(const aLeft, aRight: TSemanticSymbolRef): Boolean;
begin
  Result := (aLeft.UnitId = aRight.UnitId) and (aLeft.SymbolId = aRight.SymbolId);
end;

// aFileId names the include file that holds the occurrence; 0 for the unit's own file.
procedure AddUnresolvedUsage(const aUnresolved: TList<TDelphiSemanticUsage>;
  const aSnapshot: TDelphiProjectSnapshot; const aUnit: TUnitSnapshot; const aName,
  aRoutineName, aSectionKind: string; const aLine, aColumn: Integer; const aReason: string;
  const aFileId: TSemanticStringId = 0);
var
  lUsage: TDelphiSemanticUsage;
begin
  lUsage := Default(TDelphiSemanticUsage);
  lUsage.Name := aName;
  lUsage.RoutineName := aRoutineName;
  lUsage.Role := 'unresolved';
  lUsage.SectionKind := aSectionKind;
  lUsage.SourceKind := 'project-snapshot';
  lUsage.FileName := SnapshotFactFileName(aSnapshot, aUnit, aFileId);
  lUsage.UnitName := SnapshotText(aSnapshot, aUnit.UnitNameId);
  lUsage.Line := aLine;
  lUsage.Column := aColumn;
  lUsage.EndLine := aLine;
  lUsage.EndColumn := aColumn + Length(aName) - 1;
  lUsage.Reason := aReason;
  aUnresolved.Add(lUsage);
end;

function SnapshotOffsetOfPosition(const aText: string; const aLine, aColumn: Integer): Integer;
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

// Walks a sanitized method declaration from its name over the header and the directive list
// after it. Only these directives let a same-named method in another type override, implement
// or reintroduce it.
function MethodDeclarationIsVirtual(const aSanitized: string; const aOffset: Integer): Boolean;
var
  i: Integer;
  lDepth: Integer;
  lStart: Integer;
  lWord: string;
begin
  Result := False;
  if aOffset <= 0 then
    Exit;
  i := aOffset;
  lDepth := 0;
  while i <= Length(aSanitized) do
  begin
    if CharInSet(aSanitized[i], ['(', '[']) then
      Inc(lDepth)
    else if CharInSet(aSanitized[i], [')', ']']) then
      Dec(lDepth)
    else if (aSanitized[i] = ';') and (lDepth <= 0) then
      Break;
    Inc(i);
  end;
  while i <= Length(aSanitized) do
  begin
    Inc(i);
    while (i <= Length(aSanitized)) and CharInSet(aSanitized[i], [#9, #10, #13, ' ']) do
      Inc(i);
    lStart := i;
    while (i <= Length(aSanitized)) and IsIdentifierChar(aSanitized[i]) do
      Inc(i);
    lWord := Copy(aSanitized, lStart, i - lStart);
    if MatchText(lWord, ['virtual', 'dynamic', 'override', 'abstract', 'reintroduce',
      'message', 'final']) then
      Exit(True);
    if not MatchText(lWord, ['overload', 'static', 'inline', 'cdecl', 'stdcall', 'register',
      'pascal', 'safecall', 'varargs', 'deprecated', 'platform', 'library', 'experimental',
      'assembler', 'export', 'far', 'near', 'unsafe']) then
      Exit;
    while (i <= Length(aSanitized)) and (aSanitized[i] <> ';') do
      Inc(i);
  end;
end;

function SnapshotOwnerIsInterface(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aSymbol: TSemanticSymbolFact): Boolean;
var
  i: Integer;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lType: TSemanticSymbolFact;
  lTypeRef: TSemanticSymbolRef;
begin
  Result := False;
  if (aSymbol.OwnerTypeId = 0) or
    not aSnapshot.TrySymbolsByName(aSymbol.OwnerTypeId, lLowIndex, lHighIndex) then
    Exit;
  for i := lLowIndex to lHighIndex do
  begin
    lTypeRef := aSnapshot.SymbolRefByNameIndex(i);
    if lTypeRef.UnitId <> aUnit.UnitId then
      Continue;
    lType := aUnit.SymbolById(lTypeRef.SymbolId);
    if SameText(SnapshotText(aSnapshot, lType.KindId), 'type') and
      SameText(SnapshotText(aSnapshot, lType.TypeId), 'interface') then
      Exit(True);
  end;
end;

// True unless the method's own declaration proves it static: unreadable source counts as
// virtual, and interface methods are implemented by same-named class methods.
function SnapshotMethodMayBeVirtual(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aSymbol: TSemanticSymbolFact): Boolean;
var
  lOffset: Integer;
  lSanitized: string;
begin
  if SnapshotOwnerIsInterface(aSnapshot, aUnit, aSymbol) then
    Exit(True);
  lSanitized := SanitizeCodeText(aSnapshot.ExactTextOf(aUnit.SourceTextId));
  lOffset := SnapshotOffsetOfPosition(lSanitized, aSymbol.Line, aSymbol.Column);
  Result := (lOffset = 0) or MethodDeclarationIsVirtual(lSanitized, lOffset);
end;

// Overrides are not linked to their base method, so a same-named method of another type is
// proven unrelated only when neither declaration is virtual.
procedure AddPossibleOverrideUsages(const aUnresolved: TList<TDelphiSemanticUsage>;
  const aSnapshot: TDelphiProjectSnapshot; const aSymbol: TDelphiSemanticIndexedSymbol;
  const aEquivalentRefs: TList<TSemanticSymbolRef>; const aNameId: TSemanticStringId);
var
  i: Integer;
  lCandidate: TSemanticSymbolFact;
  lCandidateRef: TSemanticSymbolRef;
  lCandidateUnit: TUnitSnapshot;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lRef: TSemanticSymbolRef;
  lRenamed: TSemanticSymbolFact;
  lRenamedUnit: TUnitSnapshot;
  lRenamedVirtual: Boolean;
begin
  if aSymbol.OwnerName = '' then
    Exit;
  lRenamedVirtual := False;
  for lRef in aEquivalentRefs do
    if aSnapshot.TryFindUnitById(lRef.UnitId, lRenamedUnit) then
    begin
      lRenamed := lRenamedUnit.SymbolById(lRef.SymbolId);
      if SameText(SnapshotText(aSnapshot, lRenamed.KindId), 'method') and
        SnapshotMethodMayBeVirtual(aSnapshot, lRenamedUnit, lRenamed) then
        lRenamedVirtual := True;
    end;
  if not aSnapshot.TrySymbolsByName(aNameId, lLowIndex, lHighIndex) then
    Exit;
  for i := lLowIndex to lHighIndex do
  begin
    lCandidateRef := aSnapshot.SymbolRefByNameIndex(i);
    if SnapshotSymbolRefInList(aEquivalentRefs, lCandidateRef) or
      not aSnapshot.TryFindUnitById(lCandidateRef.UnitId, lCandidateUnit) then
      Continue;
    lCandidate := lCandidateUnit.SymbolById(lCandidateRef.SymbolId);
    if not SameText(SnapshotText(aSnapshot, lCandidate.KindId), 'method') or
      SameText(SnapshotText(aSnapshot, lCandidate.OwnerTypeId), aSymbol.OwnerName) then
      Continue;
    if lRenamedVirtual or SnapshotMethodMayBeVirtual(aSnapshot, lCandidateUnit, lCandidate) then
      AddUnresolvedUsage(aUnresolved, aSnapshot, lCandidateUnit, aSymbol.Name, '',
        SnapshotText(aSnapshot, lCandidate.SectionKindId), lCandidate.Line, lCandidate.Column,
        'possible-override', lCandidate.FileId);
  end;
end;

// DS-652/DAK-392: every same-name occurrence that is proven neither to be nor not to be the
// symbol. Proven usages, declarations and references bound to other symbols are skipped. Listed:
// unresolved references, facts that contradict each other, methods that may override or
// implement it, any occurrence in a unit whose syntax facts are unverified, and occurrences no
// fact describes at all.
function CollectSnapshotUnresolvedUsages(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TDelphiSemanticIndexedSymbol; const aEquivalentRefs: TList<TSemanticSymbolRef>;
  const aUsages: TList<TDelphiSemanticUsage>): TArray<TDelphiSemanticUsage>;
var
  i: Integer;
  lColumn: Integer;
  lCovered: TDictionary<string, Byte>;
  lDeclarations: TDictionary<string, TSemanticSymbolRef>;
  lDeclaredRef: TSemanticSymbolRef;
  lFileName: string;
  lHandled: TDictionary<string, Byte>;
  lHighIndex: Integer;
  lIsEquivalentTarget: Boolean;
  lKey: string;
  lLine: Integer;
  lLineStart: Integer;
  lLowIndex: Integer;
  lName: string;
  lNameId: TSemanticStringId;
  lNameKnown: Boolean;
  lNeedle: string;
  lPosition: Integer;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lScanned: Integer;
  lSource: string;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lTarget: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnresolved: TList<TDelphiSemanticUsage>;
  lUpperSource: string;
  lUsage: TDelphiSemanticUsage;
  lVerified: Boolean;
begin
  lCovered := TDictionary<string, Byte>.Create;
  lDeclarations := TDictionary<string, TSemanticSymbolRef>.Create;
  lHandled := TDictionary<string, Byte>.Create;
  lUnresolved := TList<TDelphiSemanticUsage>.Create;
  try
    for lUsage in aUsages do
      lCovered.AddOrSetValue(SnapshotPositionKey(lUsage.FileName, lUsage.Line, lUsage.Column), 0);
    lName := aSymbol.Name;
    lNameKnown := aSnapshot.TryFindStringId(lName, lNameId);
    if lNameKnown then
      AddPossibleOverrideUsages(lUnresolved, aSnapshot, aSymbol, aEquivalentRefs, lNameId);

    // Two different symbols declared at one position means the facts contradict each other.
    if lNameKnown and aSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex) then
      for i := lLowIndex to lHighIndex do
      begin
        lSymbolRef := aSnapshot.SymbolRefByNameIndex(i);
        if not aSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
          Continue;
        lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
        if (lSymbol.Line <= 0) or (lSymbol.Column <= 0) then
          Continue;
        lKey := SnapshotPositionKey(SnapshotFactFileName(aSnapshot, lUnit, lSymbol.FileId),
          lSymbol.Line, lSymbol.Column);
        if not lDeclarations.TryGetValue(lKey, lDeclaredRef) then
          lDeclarations.Add(lKey, lSymbolRef)
        else if not SameSnapshotSymbolRef(lDeclaredRef, lSymbolRef) and
          (SnapshotSymbolRefInList(aEquivalentRefs, lDeclaredRef) or
          SnapshotSymbolRefInList(aEquivalentRefs, lSymbolRef)) then
          AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit, lName,
            SnapshotText(aSnapshot, lSymbol.RoutineId), SnapshotText(aSnapshot,
            lSymbol.SectionKindId), lSymbol.Line, lSymbol.Column, 'conflicting-facts',
            lSymbol.FileId);
      end;

    if lNameKnown and aSnapshot.TryReferencesByName(lNameId, lLowIndex, lHighIndex) then
      for i := lLowIndex to lHighIndex do
      begin
        lReferenceRef := aSnapshot.ReferenceRefByNameIndex(i);
        if not aSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit) then
          Continue;
        lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
        // DS-659: an include fact without a position is still listed, never dropped.
        if (lReference.FileId <> 0) and ((lReference.Line <= 0) or (lReference.Column <= 0) or
          (lReference.FileId = lUnit.FileNameId)) then
        begin
          if not lCovered.ContainsKey(SnapshotPositionKey(SnapshotFactFileName(aSnapshot, lUnit,
            lReference.FileId), lReference.Line, lReference.Column)) then
            AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit, lName,
              SnapshotText(aSnapshot, lReference.RoutineId), SnapshotText(aSnapshot,
              lReference.SectionKindId), lReference.Line, lReference.Column,
              'include-position-unknown', lReference.FileId);
          Continue;
        end;
        if (lReference.Line <= 0) or (lReference.Column <= 0) then
          Continue;
        lKey := SnapshotPositionKey(SnapshotFactFileName(aSnapshot, lUnit, lReference.FileId),
          lReference.Line, lReference.Column);
        lHandled.AddOrSetValue(lKey, 0);
        lTarget.UnitId := lReference.TargetUnitId;
        lTarget.SymbolId := lReference.TargetSymbolId;
        lIsEquivalentTarget := (lTarget.SymbolId <> 0) and
          SnapshotSymbolRefInList(aEquivalentRefs, lTarget);
        if not IsVerifiedScopeStatus(SnapshotText(aSnapshot, lUnit.ScopeModelStatusId)) then
        begin
          if not lCovered.ContainsKey(lKey) then
            AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit, lName,
              SnapshotText(aSnapshot, lReference.RoutineId), SnapshotText(aSnapshot,
              lReference.SectionKindId), lReference.Line, lReference.Column, 'unverified-unit',
              lReference.FileId);
        end else if lDeclarations.TryGetValue(lKey, lDeclaredRef) and
          not SameSnapshotSymbolRef(lDeclaredRef, lTarget) and (lIsEquivalentTarget or
          SnapshotSymbolRefInList(aEquivalentRefs, lDeclaredRef)) then
          AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit, lName,
            SnapshotText(aSnapshot, lReference.RoutineId), SnapshotText(aSnapshot,
            lReference.SectionKindId), lReference.Line, lReference.Column, 'conflicting-facts',
            lReference.FileId)
        else if lTarget.SymbolId = 0 then
          AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit, lName,
            SnapshotText(aSnapshot, lReference.RoutineId), SnapshotText(aSnapshot,
            lReference.SectionKindId), lReference.Line, lReference.Column,
            'unresolved-reference', lReference.FileId);
      end;

    // Occurrences no fact describes: extraction gaps, unverified units, inactive code.
    lNeedle := UpperCase(lName);
    for i := 0 to Pred(aSnapshot.UnitCount) do
    begin
      lUnit := aSnapshot.UnitByIndex(i);
      lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
      if (lSource = '') or not ContainsText(lSource, lName) then
        Continue;
      lVerified := IsVerifiedScopeStatus(SnapshotText(aSnapshot, lUnit.ScopeModelStatusId));
      lFileName := SnapshotText(aSnapshot, lUnit.FileNameId);
      lUpperSource := UpperCase(SanitizeCodeText(lSource));
      lLine := 1;
      lLineStart := 1;
      lScanned := 1;
      lPosition := Pos(lNeedle, lUpperSource);
      while lPosition > 0 do
      begin
        while lScanned < lPosition do
        begin
          if lUpperSource[lScanned] = #10 then
          begin
            Inc(lLine);
            lLineStart := lScanned + 1;
          end;
          Inc(lScanned);
        end;
        if IsWordAt(lUpperSource, lPosition, lNeedle) then
        begin
          lColumn := lPosition - lLineStart + 1;
          lKey := SnapshotPositionKey(lFileName, lLine, lColumn);
          if not lCovered.ContainsKey(lKey) and not lHandled.ContainsKey(lKey) and
            not (lVerified and lDeclarations.ContainsKey(lKey)) then
          begin
            if lVerified then
              AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit,
                Copy(lSource, lPosition, Length(lName)), '', '', lLine, lColumn,
                'unclassified-occurrence')
            else
              AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit,
                Copy(lSource, lPosition, Length(lName)), '', '', lLine, lColumn,
                'unverified-unit');
          end;
        end;
        lPosition := PosEx(lNeedle, lUpperSource, lPosition + 1);
      end;
    end;

    Result := SortedUsages(lUnresolved);
  finally
    lUnresolved.Free;
    lHandled.Free;
    lDeclarations.Free;
    lCovered.Free;
  end;
end;

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
      AddSnapshotParameterEquivalentRefs(aSnapshot, aSymbolRef, lOriginalSymbol,
        lEquivalentRefs);
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
          // A unit with unverified syntax facts proves no reference; the completeness scan
          // lists its occurrences instead.
          if not IsVerifiedScopeStatus(SnapshotText(aSnapshot, lUnit.ScopeModelStatusId)) then
            Continue;
          lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
          lUsages.Add(MakeSnapshotReferenceUsage(aSnapshot, lUnit, lReference));
        end;

    Result := Default(TDelphiSemanticUsageResult);
    Result.Status := 'resolved';
    Result.Symbol := aSymbol;
    Result.Usages := SortedUsages(lUsages);
    Result.Unresolved := CollectSnapshotUnresolvedUsages(aSnapshot, aSymbol, lEquivalentRefs,
      lUsages);
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
  lUnit: TUnitSnapshot;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot = nil then
    Exit(MakeDiagnosticResult('unresolved', 'No project snapshot is available.'));

  if not TryFindSnapshotUsageSymbolByName(lSnapshot, aName, lSymbolRef, lSymbol) then
    Exit(MakeDiagnosticResult('unresolved', 'No visible symbol named "' + aName +
      '" was found.'));

  Result := BuildSnapshotResultForSymbol(lSnapshot, lSymbolRef, lSymbol);
  if lSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit) then
    Result := GateSnapshotDeclaringUnit(lSnapshot, lUnit, Result);
end;

function UsagesCoverPosition(const aUsages: TArray<TDelphiSemanticUsage>;
  const aFileName: string; const aLine, aColumn: Integer): Boolean;
var
  lFileName: string;
  lUsage: TDelphiSemanticUsage;
begin
  lFileName := ExpandFileName(aFileName);
  for lUsage in aUsages do
    if (lUsage.Line = aLine) and (lUsage.Column <= aColumn) and
      ((aColumn <= lUsage.EndColumn) or (aColumn = lUsage.Column)) and
      SameText(ExpandFileName(lUsage.FileName), lFileName) then
      Exit(True);
  Result := False;
end;

// The identifier covering aLine:aColumn in the unit's snapshot source, if the unit is known.
function TryReadSnapshotIdentifierAt(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string; const aLine, aColumn: Integer; out aIdentifier: string): Boolean;
var
  lEnd: Integer;
  lOffset: Integer;
  lSource: string;
  lStart: Integer;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
begin
  aIdentifier := '';
  Result := False;
  if not (aSnapshot.TryFindUnitByFileName(aFileName, lUnitId) or
    aSnapshot.TryFindUnitByFileName(ExpandFileName(aFileName), lUnitId)) or
    not aSnapshot.TryFindUnitById(lUnitId, lUnit) then
    Exit;
  lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
  lOffset := SnapshotOffsetOfPosition(lSource, aLine, aColumn);
  if (lOffset = 0) or not IsIdentifierChar(lSource[lOffset]) then
    Exit;
  lStart := lOffset;
  while (lStart > 1) and IsIdentifierChar(lSource[lStart - 1]) do
    Dec(lStart);
  lEnd := lOffset;
  while (lEnd < Length(lSource)) and IsIdentifierChar(lSource[lEnd + 1]) do
    Inc(lEnd);
  aIdentifier := Copy(lSource, lStart, lEnd - lStart + 1);
  Result := True;
end;

function FindSnapshotUsagesAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
  const aFileName: string; const aLine, aColumn: Integer): TDelphiSemanticUsageResult;
var
  lIdentifier: string;
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
  // A declaration or reference of a symbol always spells its name, so a different identifier
  // at the position means the resolver matched an enclosing range (a routine body), not it.
  if TryReadSnapshotIdentifierAt(lSnapshot, aFileName, aLine, aColumn, lIdentifier) and
    not SameText(lIdentifier, lSymbol.Name) then
    Exit(MakeDiagnosticResult('unknown', 'The identifier "' + lIdentifier +
      '" at the requested position was resolved to "' + lSymbol.Name +
      '"; its own symbol cannot be proven.'));
  Result := BuildSnapshotResultForSymbol(lSnapshot, lPositionResolution.SymbolRef, lSymbol);
  Result := GateSnapshotDeclaringUnit(lSnapshot, lPositionResolution.SymbolUnit, Result);
  // The requested position must be one of the symbol's own declarations or proven references;
  // whitespace or punctuation in a routine body only matched the routine's range.
  if (Result.Status = 'resolved') and not UsagesCoverPosition(Result.Usages, aFileName, aLine,
    aColumn) then
    Result := MakeDiagnosticResult('unknown', 'The requested position is not a declaration ' +
      'or proven reference of "' + lSymbol.Name + '".');
end;

function NormalizedSymbolSignature(const aSignature: string): string;
begin
  Result := NormalizeRoutineSignature(aSignature);
end;

function SymbolIsMethodPair(const aLeft, aRight: TDelphiSemanticIndexedSymbol): Boolean;
begin
  if not (SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.OwnerName, aRight.OwnerName) and SameText(aLeft.Name, aRight.Name)) then
    Exit(False);

  if (SameText(aLeft.Kind, 'method') and SameText(aRight.Kind, 'routine')) or
    (SameText(aLeft.Kind, 'routine') and SameText(aRight.Kind, 'method')) then
    Exit(True);

  Result := SameText(aLeft.Kind, 'routine') and SameText(aRight.Kind, 'routine') and
    ((NormalizedSymbolSignature(aLeft.Signature) =
    NormalizedSymbolSignature(aRight.Signature)) or
    ((aLeft.Line > 0) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column)));
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
    Result.Usages := SortedUsages(lUsages);
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
  Result := RequireVerifiedDeclaringUnit(aContext,
    FindUsagesAtPosition(lIndex, aContext, aFileName, aLine, aColumn));
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
  Result := RequireVerifiedDeclaringUnit(aContext, FindUsagesByName(lIndex, aName));
  Result.IndexMetrics := lIndex.Metrics;
end;

class function TDelphiSemanticUsageFinder.RequireVerifiedDeclaringUnit(
  const aContext: TDelphiSemanticSymbolQueryContext;
  const aResult: TDelphiSemanticUsageResult): TDelphiSemanticUsageResult;
var
  lScopeStatus: string;
  lUnitName: string;
begin
  Result := aResult;
  if (aResult.Status = 'resolved') and TryFindUnverifiedDeclaringUnit(aContext, aResult.Symbol,
    lUnitName, lScopeStatus) then
  begin
    Result := UnverifiedDeclarationResult(aResult.Symbol.Name, lUnitName, lScopeStatus);
    Result.IndexMetrics := aResult.IndexMetrics;
  end;
end;

// File identity also covers a program file, whose model has no unit name. A symbol declared in
// an include file (DS-659) matches its unit by name only (aByUnitName).
function DeclaresSymbol(const aSymbol: TDelphiSemanticIndexedSymbol; const aFileName,
  aUnitName: string; const aByUnitName: Boolean): Boolean;
begin
  if not aByUnitName and (aSymbol.FileName <> '') and (aFileName <> '') then
    Exit(SameText(aSymbol.FileName, aFileName));
  Result := (aUnitName <> '') and SameText(aUnitName, aSymbol.UnitName);
end;

class function TDelphiSemanticUsageFinder.TryFindUnverifiedDeclaringUnit(
  const aContext: TDelphiSemanticSymbolQueryContext;
  const aSymbol: TDelphiSemanticIndexedSymbol; out aUnitName, aScopeStatus: string): Boolean;
var
  i: Integer;
  lByUnitName: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
begin
  aUnitName := '';
  aScopeStatus := '';
  lSnapshot := ContextProjectSnapshot(aContext);
  lModels := [aContext.UnitModel] + aContext.IndexedUnitModels;
  // The second pass finds the unit of a symbol whose file is an include, not a unit.
  for lByUnitName := False to True do
  begin
    if lSnapshot <> nil then
      for i := 0 to Pred(lSnapshot.UnitCount) do
      begin
        lUnit := lSnapshot.UnitByIndex(i);
        if DeclaresSymbol(aSymbol, SnapshotText(lSnapshot, lUnit.FileNameId),
          SnapshotText(lSnapshot, lUnit.UnitNameId), lByUnitName) then
        begin
          aUnitName := SnapshotText(lSnapshot, lUnit.UnitNameId);
          aScopeStatus := SnapshotText(lSnapshot, lUnit.ScopeModelStatusId);
          Exit(not IsVerifiedScopeStatus(aScopeStatus));
        end;
      end;
    for lModel in lModels do
      if DeclaresSymbol(aSymbol, lModel.FileName, lModel.UnitName, lByUnitName) then
      begin
        aUnitName := lModel.UnitName;
        if aUnitName = '' then
          aUnitName := ExtractFileName(lModel.FileName);
        aScopeStatus := lModel.ScopeModelStatus;
        Exit(not IsVerifiedScopeStatus(aScopeStatus));
      end;
  end;
  Result := False;
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
