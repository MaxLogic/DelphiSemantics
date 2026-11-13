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
    // Same-name occurrences in other configurations or with uncertain identity (role
    // 'unresolved'). Filled for project-snapshot results.
    Unresolved: TArray<TDelphiSemanticUsage>;
    HasUnverifiedConditionalOccurrences: Boolean;
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
    // Missing imports can affect only nonlocal names in their possible uses closure.
    class function PossibleImportGaps(const aContext: TDelphiSemanticSymbolQueryContext;
      const aSymbol: TDelphiSemanticIndexedSymbol; const aNames: TArray<string>):
      TArray<TDelphiSemanticUsage>; static;
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
  System.Generics.Collections, System.Generics.Defaults, System.Math, System.RegularExpressions, System.StrUtils, System.SysUtils,
  SimpleParser.Lexer, SimpleParser.Lexer.Types,
  DelphiSemantics.ImportFacts, DelphiSemantics.Model, DelphiSemantics.Model.Text, DelphiSemantics.NameFlow.Facts, DelphiSemantics.Snapshot,
  DelphiSemantics.Snapshot.PositionResolver,
  DelphiSemantics.Snapshot.QuerySupport, DelphiSemantics.SourceConditionals, MaxLogic.StrUtils;

type
  TSnapshotRuntimeContextSpan = record
    Node: TDelphiNameFlowNode;
    Start, Finish, SubtreeFinish: Int64;
  end;

  // Query-owned interval index over immutable facts. Matching nodes retain
  // extraction order, including overlapping physical spans from includes.
  TSnapshotRuntimeContextIndex = record
  private
    fSpans: TArray<TSnapshotRuntimeContextSpan>;
    function BuildSubtree(const aFirst, aLast: Integer): Int64;
    procedure Collect(const aFirst, aLast: Integer; const aPosition: Int64;
      var aNodes: TArray<TDelphiNameFlowNode>);
  public
    procedure Initialize(const aFacts: IDelphiNameFlowFacts);
    function NodesAt(const aLine, aColumn: Integer): TArray<TDelphiNameFlowNode>;
  end;

function TSnapshotRuntimeContextIndex.BuildSubtree(const aFirst, aLast: Integer): Int64;
var
  lMiddle: Integer;
begin
  if aFirst > aLast then
    Exit(0);
  lMiddle := aFirst + (aLast - aFirst) div 2;
  Result := Max(fSpans[lMiddle].Finish, Max(BuildSubtree(aFirst, lMiddle - 1),
    BuildSubtree(lMiddle + 1, aLast)));
  fSpans[lMiddle].SubtreeFinish := Result;
end;

procedure TSnapshotRuntimeContextIndex.Initialize(const aFacts: IDelphiNameFlowFacts);
var
  lNode: TDelphiNameFlowNode;
  i, lCount: Integer;
begin
  SetLength(fSpans, aFacts.NodeCount);
  lCount := 0;
  for i := 1 to aFacts.NodeCount do
  begin
    lNode := aFacts.NodeById(i);
    if not lNode.SpanKnown then
      Continue;
    // Other nodes cannot change any lexical-context field.
    if (lNode.SyntaxKind <> 'interface') and (lNode.ScopeId = '') and
      (lNode.OwnerType = '') and (lNode.Kind <> TDelphiNameFlowNodeKind.Routine) and
      (lNode.SyntaxKind <> 'constant') then
      Continue;
    fSpans[lCount].Node := lNode;
    fSpans[lCount].Start := (Int64(lNode.Line) shl 32) + lNode.Column;
    fSpans[lCount].Finish := (Int64(lNode.EndLine) shl 32) + lNode.EndColumn;
    Inc(lCount);
  end;
  SetLength(fSpans, lCount);
  TArray.Sort<TSnapshotRuntimeContextSpan>(fSpans,
    TComparer<TSnapshotRuntimeContextSpan>.Construct(
      function(const aLeft, aRight: TSnapshotRuntimeContextSpan): Integer
      begin
        if aLeft.Start < aRight.Start then
          Exit(-1);
        if aLeft.Start > aRight.Start then
          Exit(1);
        Result := CompareValue(aLeft.Node.Id, aRight.Node.Id);
      end));
  BuildSubtree(0, High(fSpans));
end;

procedure TSnapshotRuntimeContextIndex.Collect(const aFirst, aLast: Integer;
  const aPosition: Int64; var aNodes: TArray<TDelphiNameFlowNode>);
var
  lMiddle: Integer;
begin
  if aFirst > aLast then
    Exit;
  lMiddle := aFirst + (aLast - aFirst) div 2;
  if (fSpans[aFirst].Start > aPosition) or (fSpans[lMiddle].SubtreeFinish <= aPosition) then
    Exit;
  Collect(aFirst, lMiddle - 1, aPosition, aNodes);
  if (fSpans[lMiddle].Start <= aPosition) and (aPosition < fSpans[lMiddle].Finish) then
    aNodes := aNodes + [fSpans[lMiddle].Node];
  if fSpans[lMiddle].Start <= aPosition then
    Collect(lMiddle + 1, aLast, aPosition, aNodes);
end;

function TSnapshotRuntimeContextIndex.NodesAt(const aLine, aColumn: Integer): TArray<TDelphiNameFlowNode>;
begin
  Result := nil;
  Collect(0, High(fSpans), (Int64(aLine) shl 32) + aColumn, Result);
  TArray.Sort<TDelphiNameFlowNode>(Result, TComparer<TDelphiNameFlowNode>.Construct(
    function(const aLeft, aRight: TDelphiNameFlowNode): Integer
    begin
      Result := CompareValue(aLeft.Id, aRight.Id);
    end));
end;


procedure SnapshotRuntimeCoordinatesAtOffset(const aLineStarts: TArray<Integer>;
  const aOffset: Integer; out aLine, aColumn: Integer);
var
  lLow, lHigh, lMiddle: Integer;
begin
  lLow := 0;
  lHigh := High(aLineStarts);
  while lLow < lHigh do
  begin
    lMiddle := lLow + (lHigh - lLow + 1) div 2;
    if aLineStarts[lMiddle] <= aOffset then
      lLow := lMiddle
    else
      lHigh := lMiddle - 1;
  end;
  aLine := lLow + 1;
  aColumn := aOffset - aLineStarts[lLow] + 1;
end;

function SnapshotUnknownActivity(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aFileId: TSemanticStringId;
  const aLine, aColumn: Integer): Boolean;
begin
  Result := False;
  if (aFileId <> 0) and (aFileId <> aUnit.FileNameId) then
    Exit;
  Result := TDelphiSemanticSourceConditionals.UnknownAtPosition(
    aSnapshot.ExactTextOf(aUnit.SourceTextId),
    aSnapshot.ExactTextOf(aUnit.VerifiedActiveSourceTextId), aLine, aColumn);
end;

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
    Result.HasUnverifiedConditionalOccurrences := aResult.HasUnverifiedConditionalOccurrences;
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
  if Result <> 0 then
    Exit;
  Result := CompareStringValues(aLeft.Reason, aRight.Reason);
end;

function SameUsageRange(const aLeft, aRight: TDelphiSemanticUsage): Boolean;
begin
  Result := SameText(aLeft.FileName, aRight.FileName) and
    SameText(aLeft.UnitName, aRight.UnitName) and SameText(aLeft.Role, aRight.Role) and
    SameText(aLeft.Name, aRight.Name) and SameText(aLeft.RoutineName, aRight.RoutineName) and
    SameText(aLeft.SectionKind, aRight.SectionKind) and
    SameText(aLeft.SourceKind, aRight.SourceKind) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column) and (aLeft.EndLine = aRight.EndLine) and
    (aLeft.EndColumn = aRight.EndColumn) and SameText(aLeft.Reason, aRight.Reason);
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
  if aColumn > 0 then
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
function SnapshotFactIsRoutineLocal(const aSymbol: TSemanticSymbolFact;
  const aSnapshot: TDelphiProjectSnapshot): Boolean;
begin
  Result := (aSymbol.RoutineId <> 0) and
    MatchText(SnapshotText(aSnapshot, aSymbol.KindId), ['local', 'var', 'parameter']);
end;

function SnapshotPositionInWith(const aUnit: TUnitSnapshot; const aLine, aColumn: Integer): Boolean;
var
  i: Integer;
  lWith: TSemanticWithStatementFact;
begin
  for i := 1 to aUnit.WithStatementCount do
  begin
    lWith := aUnit.WithStatementById(TSemanticWithId(i));
    if ((aLine > lWith.BodyStartLine) or
      ((aLine = lWith.BodyStartLine) and (aColumn >= lWith.BodyStartColumn))) and
      ((aLine < lWith.BodyEndLine) or
      ((aLine = lWith.BodyEndLine) and (aColumn <= lWith.BodyEndColumn))) then
      Exit(True);
  end;
  Result := False;
end;

// DS-797 slice 1: implicit Self lookup precedes unit-level declarations.
function SnapshotPositionInMethod(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aLine: Integer): Boolean;
var
  i: Integer;
  lFact: TSemanticSymbolFact;
begin
  for i := 1 to aUnit.SymbolCount do
  begin
    lFact := aUnit.SymbolById(TSemanticSymbolId(i));
    if (lFact.RoutineId <> 0) and (lFact.EndLine >= aLine) and
      (lFact.Line <= aLine) and
      (lFact.OwnerTypeId <> 0) and
      SameText(SnapshotText(aSnapshot, lFact.KindId), 'routine') then
      Exit(True);
  end;
  Result := False;
end;

function SnapshotLocalTarget(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TDelphiSemanticIndexedSymbol; out aUnit: TUnitSnapshot;
  out aFact: TSemanticSymbolFact): Boolean;
var
  i, j: Integer;
begin
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    aUnit := aSnapshot.UnitByIndex(i);
    for j := 1 to aUnit.SymbolCount do
    begin
      aFact := aUnit.SymbolById(TSemanticSymbolId(j));
      if (aFact.Line = aSymbol.Line) and (aFact.Column = aSymbol.Column) and
        SameText(SnapshotFactFileName(aSnapshot, aUnit, aFact.FileId), aSymbol.FileName) and
        SameText(SnapshotText(aSnapshot, aFact.NameId), aSymbol.Name) then
        Exit(SnapshotFactIsRoutineLocal(aFact, aSnapshot));
    end;
  end;
  Result := False;
end;

function SnapshotInsideLocalRoutine(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aLocal: TSemanticSymbolFact;
  const aFileName: string; const aLine: Integer): Boolean;
var
  i: Integer;
  lRoutine: TSemanticSymbolFact;
  lHasSpan: Boolean;
begin
  // Includes retain physical coordinates, which cannot be compared with the
  // owning routine's main-file span. The caller already proved unit identity;
  // absent a mapped routine span, keep every included name as a possible capture.
  if not SameText(aFileName, SnapshotFactFileName(aSnapshot, aUnit, aLocal.FileId)) then
    Exit(True);
  lHasSpan := False;
  for i := 1 to aUnit.SymbolCount do
  begin
    lRoutine := aUnit.SymbolById(TSemanticSymbolId(i));
    if not SameText(SnapshotText(aSnapshot, lRoutine.KindId), 'routine') or
      (lRoutine.RoutineId <> aLocal.RoutineId) or (lRoutine.EndLine <= lRoutine.Line) then
      Continue;
    // Include the heading, declarations, nested bodies and inactive text. Where
    // overload/scope identity is unavailable the larger matching span is safe.
    lHasSpan := True;
    if (aLine >= lRoutine.Line) and (aLine <= lRoutine.EndLine) then
      Exit(True);
  end;
  Result := not lHasSpan;
end;

// The lexical successor distinguishes a bare call from inherited MethodName,
// including a final inherited before END and a body following nested routines.
function SnapshotRoutineHasBareInherited(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aFact: TSemanticSymbolFact): Boolean;
var
  lLexer: TmwBasePasLex;
  lSource: string;
  lStart, lFinish: Integer;
begin
  Result := False;
  lSource := aSnapshot.ExactTextOf(aUnit.SourceTextId);
  if (aFact.FileId <> 0) and (aFact.FileId <> aUnit.FileNameId) then
    Exit(True); // No unit-relative span can prove an include body's absence.
  lStart := SnapshotOffsetOfPosition(lSource, aFact.Line, aFact.Column);
  lFinish := SnapshotOffsetOfPosition(lSource, aFact.EndLine, aFact.EndColumn);
  if (lStart = 0) or (lFinish < lStart) then
    Exit(True);
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := SanitizeCodeText(Copy(lSource, lStart, lFinish - lStart + 1));
    if lLexer.IsJunk then
      lLexer.NextNoJunk;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID = ptInherited then
      begin
        lLexer.NextNoJunk;
        if lLexer.TokenID <> ptIdentifier then
          Exit(True);
      end else
        lLexer.NextNoJunk;
    end;
  finally
    lLexer.Free;
  end;
end;

// Only a direct visibility section can prove a member explicit. Nested types'
// visibility does not change the enclosing class's default section.
function SnapshotMemberHasDefaultVisibility(const aCode: string;
  const aTypeOffset, aMemberOffset: Integer): Boolean;
var
  lLexer: TmwBasePasLex;
  lDepth: Integer;
begin
  Result := True;
  if (aTypeOffset <= 0) or (aMemberOffset <= aTypeOffset) then
    Exit;
  lDepth := 0;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := Copy(aCode, aTypeOffset, aMemberOffset - aTypeOffset);
    if lLexer.IsJunk then
      lLexer.NextNoJunk;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID in [ptClass, ptRecord, ptObject, ptInterface] then
        Inc(lDepth)
      else if lLexer.TokenID = ptEnd then
        Dec(lDepth);
      // Visibility words are contextual identifiers in SimpleParser.
      if (lDepth = 1) and (lLexer.TokenID = ptIdentifier) and (lLexer.ExID in
        [ptPrivate, ptProtected, ptPublic, ptPublished, ptAutomated]) then
        Result := False;
      lLexer.NextNoJunk;
    end;
  finally
    lLexer.Free;
  end;
end;

// A known plain TObject root is non-published only when no retained M+ switch
// can affect it. Unknown, ambiguous or cyclic source ancestry stays refused.
function SnapshotClassMayPublish(const aSnapshot: TDelphiProjectSnapshot;
  const aOwner: string; const aSeen: TArray<string>): Boolean;
var
  lUnit: TUnitSnapshot;
  lName, lRaw, lCode, lBase: string;
  lMatch: TMatch;
  lMatches: Integer;
  i: Integer;
begin
  Result := True;
  if MatchText(aOwner, aSeen) then
    Exit;
  lName := Copy(aOwner, LastDelimiter('.', aOwner) + 1, MaxInt);
  if MatchText(lName, ['TPersistent', 'TComponent', 'TDataModule', 'TForm', 'TFrame']) then
    Exit;
  lMatches := 0;
  lBase := '';
  for i := 0 to aSnapshot.UnitCount - 1 do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    lRaw := aSnapshot.ExactTextOf(lUnit.SourceTextId);
    lCode := SanitizeCodeText(lRaw);
    for lMatch in TRegEx.Matches(lCode, '\b' + TRegEx.Escape(lName) +
      '\s*=\s*class\b(?:\s+(?:sealed|abstract)\b)*(?:\s*\(\s*([\w.]+))?', [roIgnoreCase]) do
    begin
      Inc(lMatches);
      if HasPublishedTypeInfoSwitch(lRaw) then
        Exit;
      if lMatch.Groups.Count > 1 then
        lBase := lMatch.Groups[1].Value;
    end;
  end;
  if (lMatches = 0) and MatchText(aOwner, ['TObject', 'System.TObject']) then
    Exit(False);
  if lMatches <> 1 then
    Exit;
  if lBase = '' then
    Exit(False);
  Result := SnapshotClassMayPublish(aSnapshot, lBase, aSeen + [aOwner]);
end;

function ScopedSnapshotSourceGaps(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TDelphiSemanticIndexedSymbol; const aNames: TArray<string>): TArray<TDelphiSemanticUsage>;
var
  i, j: Integer;
  lUnit, lLocalUnit: TUnitSnapshot;
  lReference: TSemanticReferenceFact;
  lLocalFact: TSemanticSymbolFact;
  lImports: TObjectDictionary<string, TList<TDelphiSemanticImportFact>>;
  lSeen, lReported, lRetained: THashSet<string>;
  lResult: TList<TDelphiSemanticUsage>;
  lLocal, lLocalMemberContext, lPackage: Boolean;
  lFact: TDelphiSemanticImportFact;
  lEdges: TList<TDelphiSemanticImportFact>;
  lKey: string;

  procedure Report(const aOwner, aReason, aName: string; const aLine, aColumn: Integer);
  var
    lUsage: TDelphiSemanticUsage;
    lReportKey: string;
  begin
    lReportKey := aOwner + '|' + aReason + '|' + aName + '|' + aLine.ToString + ':' + aColumn.ToString;
    if lReported.Contains(lReportKey) then
      Exit;
    lReported.Add(lReportKey);
    lUsage := Default(TDelphiSemanticUsage);
    lUsage.FileName := aOwner;
    lUsage.Name := aName;
    lUsage.Line := aLine;
    lUsage.Column := aColumn;
    lUsage.Role := 'unresolved';
    lUsage.SourceKind := 'project';
    lUsage.Reason := aReason;
    lResult.Add(lUsage);
  end;

  procedure CheckImports(const aOwner, aSection, aProvider, aName: string;
    const aClosure, aIgnoreWinner: Boolean; const aLine, aColumn: Integer);
  var
    lQueue: TList<string>;
    lVisited: THashSet<string>;
    lOwner: string;
    lDirect: Boolean;
    lIndex, lWinner: Integer;
    lItems: TList<TDelphiSemanticImportFact>;
    lImport: TDelphiSemanticImportFact;
  begin
    lQueue := TList<string>.Create;
    lVisited := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      lQueue.Add(aOwner);
      lIndex := 0;
      while lIndex < lQueue.Count do
      begin
        lOwner := lQueue[lIndex];
        Inc(lIndex);
        if lVisited.Contains(lOwner) then
          Continue;
        lVisited.Add(lOwner);
        if not lImports.TryGetValue(lOwner, lItems) then
          Continue;
        lDirect := SameText(lOwner, aOwner);
        lWinner := -1;
        if lDirect and not aClosure and not aIgnoreWinner and (aProvider <> '') then
          for lImport in lItems do
            if SameText(lImport.TargetFileName, aProvider) and lImport.Unconditional and
              (lImport.Cause = '') and
              (lImport.GapReason = '') and
              ((aSection <> 'interface') or (lImport.SectionKind = 'interface')) then
              lWinner := Max(lWinner, lImport.OrderIndex);
        for lImport in lItems do
        begin
          // SDK units cannot reference project declarations, but an inactive
          // SDK import can still export a helper for a selector's SDK ancestor.
          if lImport.SdkBoundary and (lImport.GapReason = '') and
            not (aClosure and not lImport.Unconditional) then
            Continue;
          if ((not lDirect or (aSection = 'interface')) and
            (lImport.SectionKind <> 'interface')) or
            (lDirect and not aClosure and (lImport.OrderIndex < lWinner) and
            not lImport.ResolutionVaries) then
            Continue;
          // A unit's interface declarations shadow its interface imports. Its
          // implementation imports can shadow those declarations later on.
          if lDirect and not aClosure and not aIgnoreWinner and
            SameText(aProvider, aOwner) and (lImport.SectionKind = 'interface') and
            not lImport.ResolutionVaries then
            Continue;
          if lImport.GapReason <> '' then
            Report(lImport.OwnerFileName, lImport.GapReason, '', 0, 0)
          else if not lImport.Unconditional then
          begin
            if aClosure then
            begin
              Report(aOwner, 'inactive-import-may-capture-member', aName, aLine, aColumn);
            end
            else
              Report(aOwner, 'inactive-import-may-capture-name', aName, aLine, aColumn);
          end;
          if aClosure and (lImport.TargetFileName <> '') then
            lQueue.Add(lImport.TargetFileName);
        end;
      end;
    finally
      lVisited.Free;
      lQueue.Free;
    end;
  end;

  function ProvenUnitQualifiedReference(const aCurrentUnit: TUnitSnapshot;
    const aReference: TSemanticReferenceFact; const aLine, aColumn: Integer): Boolean;
  var
    lTargetUnit, lUnit: TUnitSnapshot;
    lImport: TDelphiSemanticImportFact;
    lLexer: TmwBasePasLex;
    lUnitName, lRaw: string;
    lOffset, lCurrentLine, i: Integer;
    lImportProved, lInHeader, lInUses: Boolean;
  begin
    Result := False;
    if (aReference.TargetSymbolId = 0) or
      ((aReference.FileId <> 0) and (aReference.FileId <> aCurrentUnit.FileNameId)) or
      not aSnapshot.TryFindUnitById(aReference.TargetUnitId, lTargetUnit) then
      Exit;
    lUnitName := SnapshotText(aSnapshot, lTargetUnit.UnitNameId);
    if (lUnitName = '') or ContainsText(lUnitName, '.') then
      Exit;
    lImportProved := False;
    for lImport in aCurrentUnit.ImportFacts do
      if SameText(lImport.Name, lUnitName) and lImport.Unconditional and
        not lImport.ResolutionVaries and (lImport.Cause = '') and
        (lImport.GapReason = '') and SameText(lImport.TargetFileName,
        SnapshotText(aSnapshot, lTargetUnit.FileNameId)) then
        lImportProved := True;
    if not lImportProved then
      Exit;
    lRaw := SanitizeCodeText(aSnapshot.ExactTextOf(aCurrentUnit.SourceTextId));
    lOffset := 1;
    lCurrentLine := 1;
    while (lOffset <= Length(lRaw)) and (lCurrentLine < aLine) do
    begin
      if lRaw[lOffset] = #10 then
        Inc(lCurrentLine);
      Inc(lOffset);
    end;
    Inc(lOffset, aColumn - 1);
    if not TRegEx.IsMatch(Copy(lRaw, 1, lOffset - 1),
      '\b' + TRegEx.Escape(lUnitName) + '\s*\.\s*$', [roIgnoreCase]) then
      Exit;
    // Rule out a configuration-dependent value/type/routine with the unit's
    // qualifier spelling. Unknown sources/includes/import selections withhold
    // this narrow proof; parsed selected bindings alone are insufficient.
    lLexer := nil;
    try
      for i := 0 to aSnapshot.UnitCount - 1 do
      begin
        lUnit := aSnapshot.UnitByIndex(i);
        for lImport in lUnit.ImportFacts do
          if (lImport.GapReason <> '') or lImport.ResolutionVaries or
            ((not lImport.Unconditional) and lImport.SdkBoundary) then
            Exit;
        lRaw := aSnapshot.ExactTextOf(lUnit.SourceTextId);
        if (lRaw = '') or TRegEx.IsMatch(lRaw,
          '(?:\{\$|\(\*\$)\s*(?:I|INCLUDE)\s', [roIgnoreCase]) then
          Exit;
        // This lexer's Origin setter allocates a new buffer without releasing
        // its previous one. Each physical source needs its own lexer lifetime.
        FreeAndNil(lLexer);
        lLexer := TmwBasePasLex.Create;
        lLexer.UseDefines := False;
        lLexer.Origin := lRaw;
        while lLexer.IsJunk do
          lLexer.Next;
        lInHeader := False;
        lInUses := False;
        while lLexer.TokenID <> ptNull do
        begin
          if lLexer.TokenID in [ptUnit, ptProgram, ptLibrary, ptPackage] then
            lInHeader := True
          else if lLexer.TokenID in [ptUses, ptContains] then
            lInUses := True
          else if lLexer.TokenID = ptSemiColon then
          begin
            lInHeader := False;
            lInUses := False;
          end else if SameText(lLexer.Token.TrimLeft(['&']), lUnitName) and
            not lInHeader and not lInUses then
          begin
            lLexer.NextNoJunk;
            if lLexer.Token <> '.' then
              Exit;
            Continue;
          end;
          lLexer.NextNoJunk;
        end;
      end;
      Result := True;
    finally
      lLexer.Free;
    end;
  end;

  procedure CheckOccurrence(const aCurrentUnit: TUnitSnapshot; const aFileName,
    aName: string; const aLine, aColumn: Integer; const aInactive, aMember: Boolean;
    const aReference: TSemanticReferenceFact);
  var
    lTarget: TSemanticSymbolFact;
    lTargetUnit: TUnitSnapshot;
    lProvider, lSection, lOwner: string;
    lInWith, lNewLocal: Boolean;
    lBeforeImports: Integer;
  begin
    if lLocal and ((aCurrentUnit.UnitId <> lLocalUnit.UnitId) or
      not SnapshotInsideLocalRoutine(aSnapshot, lLocalUnit, lLocalFact, aFileName, aLine)) then
    begin
      // A capture source need not be inside the local's owning routine. The
      // containment deliberately keeps all new-name tokens in the project
      // closure when a renamed local is used under WITH/member lookup.
      if lLocalMemberContext and not SameText(aName, aSymbol.Name) then
        Report(aFileName, 'containment-local-capture', aName, aLine, aColumn);
      Exit;
    end;
    // A new local spelling can capture an existing call/reference inside its
    // routine even when the provider is an intrinsic/SDK name with no project
    // declaration (for example WriteLn). Token presence is enough to refuse;
    // this containment does not try to prove the proposed binding harmless.
    if lLocal and not SameText(aName, aSymbol.Name) then
      Report(aFileName, 'containment-local-capture', aName, aLine, aColumn);
    // Includes have physical token coordinates but share their unit's imports.
    // Possible-only imported units retain their own owner when available.
    lOwner := aFileName;
    if not lImports.ContainsKey(lOwner) then
      lOwner := SnapshotText(aSnapshot, aCurrentUnit.FileNameId);
    lNewLocal := lLocal and not SameText(aName, aSymbol.Name);
    if aInactive then
    begin
      // M1 applies to prospective captures too, including names which never
      // occur in selected reference facts. Never-compiled text was excluded.
      if not SameText(aName, aSymbol.Name) then
        Report(aFileName, 'occurrence-in-inactive-configuration', aName, aLine, aColumn);
      CheckImports(lOwner, '', '', aName, aMember, True, aLine, aColumn);
      Exit;
    end;
    lInWith := (aReference.WithId <> 0) or SnapshotPositionInWith(aCurrentUnit, aLine, aColumn);
    if not lLocal and SnapshotPositionInMethod(aSnapshot, aCurrentUnit, aLine) then
    begin
      // Treat Self as a WITH receiver before considering the same-unit shortcut.
      if (aReference.TargetSymbolId <> 0) and
        aSnapshot.TryFindUnitById(aReference.TargetUnitId, lTargetUnit) and
        SnapshotFactIsRoutineLocal(lTargetUnit.SymbolById(aReference.TargetSymbolId), aSnapshot) then
        Exit;
      lInWith := True;
      lBeforeImports := lResult.Count;
      CheckImports(lOwner, '', '', aName, True, True, aLine, aColumn);
      if lResult.Count > lBeforeImports then
        Report(aFileName, 'implicit-self-may-capture-name', aName, aLine, aColumn);
    end;
    lProvider := '';
    if (aReference.TargetSymbolId <> 0) and
      aSnapshot.TryFindUnitById(aReference.TargetUnitId, lTargetUnit) then
    begin
      lTarget := lTargetUnit.SymbolById(aReference.TargetSymbolId);
      if not lInWith and not aMember and not lNewLocal then
      begin
        if SnapshotFactIsRoutineLocal(lTarget, aSnapshot) then
          Exit;
        if (lTargetUnit.UnitId = aCurrentUnit.UnitId) and
          (SameText(SnapshotText(aSnapshot, aReference.SectionKindId), 'interface') or
          SameText(SnapshotText(aSnapshot, lTarget.SectionKindId), 'implementation')) then
          Exit;
      end;
      lProvider := SnapshotText(aSnapshot, lTargetUnit.FileNameId);
    end;
    if aMember and not lInWith and
      ProvenUnitQualifiedReference(aCurrentUnit, aReference, aLine, aColumn) then
      Exit;
    lSection := SnapshotText(aSnapshot, aReference.SectionKindId);
    CheckImports(lOwner, lSection, lProvider, aName, lInWith or aMember, lNewLocal,
      aLine, aColumn);
  end;

  // Conservative implicit-consumer barriers. These are refusals, not a
  // substitute for the per-configuration binding matrix (DS-797 slice 4).
  procedure CheckImplicitConsumers(const aCurrentUnit: TUnitSnapshot);
  var
    lRaw, lCode, lConsumerRaw, lConsumerCode, lName, lPattern, lFileName, lKind, lBase: string;
    lConsumer: TSemanticReferenceFact;
    lTypeFact: TSemanticSymbolFact;
    lRttiUnit, lCodeOnly: Boolean;
    lCandidate: TDelphiSemanticStringLiteral;
    lOwnerIndex, lTypeOffset, lMemberOffset: Integer;
    lImport: TDelphiSemanticImportFact;
    lMatch: TMatch;
    lNames, lImportParts: TArray<string>;
    lExpression, lExternalReason: string;
    lMember, lType: Boolean;
    lFact: TSemanticSymbolFact;
    lIndex, lLine, lColumn: Integer;

    procedure Refuse(const aReason: string);
    begin
      Report(lFileName, aReason, lName, lLine, lColumn);
    end;

  begin
    lRaw := aSnapshot.ExactTextOf(aCurrentUnit.SourceTextId);
    lCode := SanitizeCodeText(lRaw);
    lFileName := SnapshotText(aSnapshot, aCurrentUnit.FileNameId);
    lConsumerRaw := lRaw;
    lConsumerCode := SanitizeCodeText(lConsumerRaw);
    lRttiUnit := False;
    for lImport in aCurrentUnit.ImportFacts do
      lRttiUnit := lRttiUnit or MatchText(lImport.Name,
        ['System.Rtti', 'System.TypInfo', 'Rtti', 'TypInfo']);
    lNames := [aSymbol.Name] + aNames;
    lMember := aSymbol.OwnerName <> '';
    lType := MatchText(aSymbol.Kind, ['class', 'type', 'alias']);
    for lName in lNames do
    begin
      lPattern := TRegEx.Escape(lName);
      // The rule is project-wide; absent a match span, do not misattribute
      // the target's coordinates to a different source unit.
      lLine := 0;
      lColumn := 0;
      for lIndex := 1 to aCurrentUnit.ReferenceCount do
      begin
        lConsumer := aCurrentUnit.ReferenceById(TSemanticReferenceId(lIndex));
        if SameText(SnapshotText(aSnapshot, lConsumer.ClassificationId), 'implicit-name-consumer') and
          (SameText(SnapshotText(aSnapshot, lConsumer.NameId), lName) or
          (lMember and (lConsumer.NameId = 0))) then
          Report(SnapshotFactFileName(aSnapshot, aCurrentUnit, lConsumer.FileId),
            SnapshotText(aSnapshot, lConsumer.ReasonId), lName, lConsumer.Line, lConsumer.Column);
      end;
      if SameText(lFileName, aSymbol.FileName) and SameText(aSymbol.Visibility, 'published') then
        Refuse('published-member');
      for lIndex := 1 to aCurrentUnit.SymbolCount do
      begin
        lFact := aCurrentUnit.SymbolById(TSemanticSymbolId(lIndex));
        if SameText(SnapshotText(aSnapshot, lFact.NameId), aSymbol.Name) and
          SameText(SnapshotText(aSnapshot, lFact.OwnerTypeId), aSymbol.OwnerName) and
          SameText(SnapshotText(aSnapshot, lFact.VisibilityId), 'published') then
          Refuse('published-member');
        if lMember and SameText(SnapshotText(aSnapshot, lFact.NameId), aSymbol.Name) and
          SameText(SnapshotText(aSnapshot, lFact.OwnerTypeId), aSymbol.OwnerName) and
          MatchText(SnapshotText(aSnapshot, lFact.KindId), ['method', 'field', 'property']) then
          for lOwnerIndex := 1 to aCurrentUnit.SymbolCount do
          begin
            lTypeFact := aCurrentUnit.SymbolById(TSemanticSymbolId(lOwnerIndex));
            if not SameText(SnapshotText(aSnapshot, lTypeFact.NameId), aSymbol.OwnerName) or
              not SameText(SnapshotText(aSnapshot, lTypeFact.TypeId), 'class') then
              Continue;
            lTypeOffset := SnapshotOffsetOfPosition(lCode, lTypeFact.Line, lTypeFact.Column);
            lMemberOffset := SnapshotOffsetOfPosition(lCode, lFact.Line, lFact.Column);
            if SnapshotMemberHasDefaultVisibility(lCode, lTypeOffset, lMemberOffset) and
              (SnapshotClassMayPublish(aSnapshot, aSymbol.OwnerName, []) or
              HasPublishedTypeInfoSwitch(lConsumerRaw)) then
              Refuse('published-member');
          end;
      end;
      if not lMember and SameText(aSymbol.Kind, 'routine') then
      begin
        lExternalReason := ImplicitExternalNameReason(lCode, lName);
        if lExternalReason <> '' then
          Refuse(lExternalReason);
      end;
      // Member facts do not carry a section; package methods still expose
      // their Pascal spelling through the package's external symbol names.
      if lPackage and SameText(lFileName, aSymbol.FileName) and
        (SameText(aSymbol.Kind, 'method') or
        (SameText(aSymbol.Kind, 'routine') and SameText(aSymbol.SectionKind, 'interface'))) then
        Refuse('package-exported-name');
      if lMember and (TRegEx.IsMatch(lCode, '\b(?:Variant|OleVariant)\b', [roIgnoreCase]) or
        TRegEx.IsMatch(lCode, '\b' + TRegEx.Escape(aSymbol.OwnerName) +
        '\s*=\s*dispinterface\b', [roIgnoreCase])) then
        Refuse('late-bound-member-name');
      // Some legacy dispinterface headings are modeled as ownerless routines.
      // Their source-level Automation contract still consumes the Pascal name.
      if TRegEx.IsMatch(lCode, '\bdispinterface\b(?:(?!\bend\b)[\s\S])*?' +
        '\b(?:procedure|function|property)\s+&?' + lPattern + '\b', [roIgnoreCase]) then
        Refuse('late-bound-member-name');
      for lExpression in DirectiveNameExpressions(lRaw) do
        if TextContainsIdentifier(lExpression, lName) then
          Refuse('directive-name-consumer');
      if lMember and MatchText(lName, ['GetEnumerator', 'MoveNext', 'Current']) then
        Refuse('implicit-for-in-protocol');
      if lMember then
        for lIndex := 1 to aCurrentUnit.SymbolCount do
        begin
          lFact := aCurrentUnit.SymbolById(TSemanticSymbolId(lIndex));
          if (lFact.OwnerTypeId <> 0) and
            SameText(SnapshotText(aSnapshot, lFact.KindId), 'routine') and
            SameText(SnapshotText(aSnapshot, lFact.NameId), lName) and
            SnapshotRoutineHasBareInherited(aSnapshot, aCurrentUnit, lFact) then
            Refuse('implicit-bare-inherited');
        end;
      // By-name implementation can be inherited or introduced by the new name.
      // Until the matrix owns interface obligations, any matching method in
      // a project containing an interface is a possible implementation.
      if lMember and TRegEx.IsMatch(lCode, '=\s*interface\b', [roIgnoreCase]) and
        TRegEx.IsMatch(lCode, '\b(?:procedure|function)\s+' + lPattern + '\b', [roIgnoreCase]) then
        Refuse('implicit-interface-method');
      if lMember and TRegEx.IsMatch(lCode,
        '\b(?:procedure|function)\s+[&\w]+\.[&\w]+\s*=\s*' + lPattern + '\b',
        [roIgnoreCase]) then
        Refuse('implicit-interface-method');
      if lMember and TRegEx.IsMatch(lCode, '\bproperty\b[^;]*\b(?:read|write)\s+' +
        lPattern + '\b', [roIgnoreCase]) then
        Refuse('implicit-property-accessor');
      if TRegEx.IsMatch(lCode, '\bproperty\b[^;]*\b' + lPattern +
        '\b[^;]*\bimplements\b', [roIgnoreCase]) then
        Refuse('implicit-implements');
      if lMember and TRegEx.IsMatch(lCode, '\bproperty\s+' + lPattern +
        '\b[^;]*\bimplements\b|\bimplements\s+' + lPattern + '\b', [roIgnoreCase]) then
        Refuse('implicit-implements');
      if lMember and TRegEx.IsMatch(lCode, '\boperator\s+(?:[&\w]+\.)?' + lPattern +
        '\b', [roIgnoreCase]) then
        Refuse('implicit-operator-method');
      lBase := lName;
      if EndsText('Attribute', lBase) then
        SetLength(lBase, Length(lBase) - Length('Attribute'));
      if lType and (EndsText('Attribute', lName) or
        (SameText(lFileName, aSymbol.FileName) and TRegEx.IsMatch(lCode,
        '\b' + TRegEx.Escape(aSymbol.Name) + '\s*=\s*class\s*\([^)]*\bTCustomAttribute\b',
        [roIgnoreCase])) or TRegEx.IsMatch(lCode, '\[\s*(?:' + lPattern + '|' +
        TRegEx.Escape(lBase) + '|' + TRegEx.Escape(lBase + 'Attribute') + ')(?:\s*[\],(])', [roIgnoreCase])) then
        Refuse('implicit-attribute-name');
      if not SameText(lName, aSymbol.Name) then
      begin
        lKind := SnapshotText(aSnapshot, aCurrentUnit.UnitNameId);
        if MatchText(lName, ['System', 'SysInit']) or MatchText(lName, lKind.Split(['.'])) or
          StartsText(lName + '.', lKind) then
          Refuse('unit-or-namespace-name');
        for lImport in aCurrentUnit.ImportFacts do
        begin
          lImportParts := lImport.Name.Split(['.']);
          if MatchText(lName, lImportParts) or StartsText(lName + '.', lImport.Name) then
            Refuse('unit-or-namespace-name');
        end;
      end;
      // Declared is a name consumer even when its condition is currently false.
      if TRegEx.IsMatch(lConsumerRaw, '\{\$\s*(?:IF|ELSEIF)\b[^}]*\bDeclared\s*\([^)]*\b' +
        lPattern + '\b[^)]*\)', [roIgnoreCase]) or
        TRegEx.IsMatch(lConsumerRaw, '\(\*\$\s*(?:IF|ELSEIF)\b[\s\S]*?\bDeclared\s*\([^)]*\b' +
        lPattern + '\b[^)]*\)', [roIgnoreCase]) then
        Refuse('declared-name-consumer');
      // A runtime consumer may live in another unit or receive a constant.
      // Every matching literal therefore refuses; call/import evidence only
      // selects the more specific diagnostic and never grants edit authority.
      // Retain raw conservative candidates, then scan code independently so
      // an unmatched quote in a comment cannot conceal a real literal.
      for lCodeOnly := False to True do
      begin
        for lCandidate in StringLiteralCandidates(lConsumerRaw, lCodeOnly) do
          if MatchText(lName, lCandidate.Value.Split(['.'])) then
          begin
            if lRttiUnit or HasRuntimeNameConsumerCode(lConsumerCode) then
              Refuse('rtti-string-name-consumer')
            else
              Refuse('string-name-consumer');
          end;
      end;
    end;
  end;

  // One retained expression inventory covers constants, initializers and code.
  // Equal duplicate values are safe containment evidence; ambiguity is unknown.
  // None of this inventory supplies binding or edits.
  procedure CheckStringConstants;
  type
    TConstant = record
      Item: TDelphiSemanticStringConstant;
      Owner, FileName, Kind: string;
      UnitIndex, Line, Column: Integer;
      SymbolId: TSemanticSymbolId;
      Scope, OwnerType, Section: string;
      UnprovedConstantBinding: Boolean;
    end;
  var
    lConstants: TArray<TConstant>;
    lUnitFacts: TArray<IDelphiNameFlowFacts>;
    lUnitContexts: TArray<TSnapshotRuntimeContextIndex>;
    lLineStarts: TArray<TArray<Integer>>;
    lUnitDefinitions: TArray<TDictionary<string, TArray<TDelphiNameFlowNode>>>;
    lValues: TArray<string>;
    lStates: TArray<Integer>;
    lVisiting, lIntegerValues: TArray<Boolean>;
    lByName: TDictionary<string, TArray<Integer>>;
    lAliases: TDictionary<string, string>;
    lConstant: TConstant;
    lUnit, lImportedUnit: TUnitSnapshot;
    lFact: TSemanticReferenceFact;
    lSymbol: TSemanticSymbolFact;
    lImport: TDelphiSemanticImportFact;
    lName, lOwnerType, lAlias, lUnitSource: string;
    lLineCount: Integer;
    lDefinition: TDelphiNameFlowNode;
    lDefinitionNodes: TArray<TDelphiNameFlowNode>;
    i, j, k: Integer;

    procedure IndexName(const aName: string; const aIndex: Integer);
    var
      lIndices: TArray<Integer>;
    begin
      if aName = '' then
        Exit;
      if not lByName.TryGetValue(aName, lIndices) then
        lIndices := nil;
      for var lIndex in lIndices do
        if lIndex = aIndex then
          Exit;
      lByName.AddOrSetValue(aName, lIndices + [aIndex]);
    end;

    function FindConstants(const aIndex: Integer; const aName: string): TArray<Integer>;
    var
      lQualified, lTarget: string;
      lRefs, lScopedRefs: TArray<TSemanticSymbolRef>;
      lRef: TSemanticSymbolRef;
      lBindingUnit: TUnitSnapshot;
      lComplete, lScopedComplete: Boolean;
      lExternalUnits: TArray<string>;
      lImport: TDelphiSemanticImportFact;
      lDot, lCandidate: Integer;
      lPossible: TArray<Integer>;
      lContext: TConstant;
      lDefinition: TDelphiNameFlowNode;
      lDefinitions: TArray<TDelphiNameFlowNode>;
    begin
      Result := nil;
      lContext := lConstants[aIndex];
      lQualified := aName;
      if (Pos('.', aName) = 0) and lUnitDefinitions[lContext.UnitIndex].TryGetValue(aName, lDefinitions) and
        SnapshotVisibleRuntimeDefinition(lDefinitions, aName, lContext.Scope, lContext.OwnerType,
          lContext.Line, lContext.Column, lDefinition, lComplete) then
      begin
        if lDefinition.SyntaxKind = 'constant' then
          lConstants[aIndex].UnprovedConstantBinding := lConstants[aIndex].UnprovedConstantBinding or not lComplete;
        if not lComplete or (lDefinition.SyntaxKind <> 'constant') then
          Exit; // A nearer unresolved/mutable declaration cannot expose an outer constant.
        if lByName.TryGetValue(aName, lPossible) then
          for lCandidate in lPossible do
            if (lConstants[lCandidate].UnitIndex = lContext.UnitIndex) and
              SameText(lConstants[lCandidate].Scope, lDefinition.ScopeId) and
              SameText(lConstants[lCandidate].OwnerType, lDefinition.OwnerType) and
              (lConstants[lCandidate].Item.Name <> '') and
              (lConstants[lCandidate].Item.Expression <> '') and
              (lConstants[lCandidate].Line >= lDefinition.Line) and
              (lConstants[lCandidate].Line <= lDefinition.EndLine) then
              Result := Result + [lCandidate];
        lConstants[aIndex].UnprovedConstantBinding := lConstants[aIndex].UnprovedConstantBinding or (Length(Result) <> 1);
        Exit;
      end;
      lDot := Pos('.', aName);
      if (lDot > 0) and lAliases.TryGetValue(lContext.Owner + '|' +
        Copy(aName, 1, lDot - 1), lTarget) then
        lQualified := lTarget + Copy(aName, lDot, MaxInt);
      lRefs := SnapshotVisibleDeclarations(aSnapshot, aSnapshot.UnitByIndex(lContext.UnitIndex),
        lQualified, lContext.Scope, lContext.OwnerType, lContext.Section,
        lContext.Line, lContext.Column, nil, lComplete, lUnitFacts[lContext.UnitIndex], lContext.FileName);
      if lComplete and (Length(lRefs) > 0) then
      begin
        // Uncaptured SDK exports still participate in effective uses order.
        // A later SDK unit can hide this project constant. Without its export
        // binding, preserve the constant-evaluator gap rather than fold the
        // earlier project's value (for example Winapi.Windows.VK_F6).
        lExternalUnits := nil;
        for lImport in aSnapshot.UnitByIndex(lContext.UnitIndex).ImportFacts do
          if lImport.SdkBoundary then
            lExternalUnits := lExternalUnits + [lImport.Name];
        lScopedRefs := SnapshotVisibleDeclarations(aSnapshot,
          aSnapshot.UnitByIndex(lContext.UnitIndex), lQualified, lContext.Scope,
          lContext.OwnerType, lContext.Section, lContext.Line, lContext.Column,
          lExternalUnits, lScopedComplete, lUnitFacts[lContext.UnitIndex], lContext.FileName);
        if not lScopedComplete then
        begin
          for lRef in lRefs do
            if aSnapshot.TryFindUnitById(lRef.UnitId, lBindingUnit) and
              SameText(SnapshotText(aSnapshot, lBindingUnit.SymbolById(lRef.SymbolId).KindId), 'const') then
              lConstants[aIndex].UnprovedConstantBinding := True;
          Exit;
        end;
        lRefs := lScopedRefs;
      end;
      // Only visible candidates can establish true-constant evidence. An
      // unrelated bare-name homonym cannot harden a mutable/unresolved value.
      if not lComplete or (Length(lRefs) <> 1) then
        for lRef in lRefs do
          if aSnapshot.TryFindUnitById(lRef.UnitId, lBindingUnit) and
            SameText(SnapshotText(aSnapshot, lBindingUnit.SymbolById(lRef.SymbolId).KindId), 'const') then
            lConstants[aIndex].UnprovedConstantBinding := True;
      if not lComplete then
        Exit;
      for lRef in lRefs do
      begin
        lPossible := nil;
        for lCandidate := 0 to High(lConstants) do
          if (aSnapshot.UnitByIndex(lConstants[lCandidate].UnitIndex).UnitId = lRef.UnitId) and
            (lConstants[lCandidate].SymbolId = lRef.SymbolId) and
            SameText(lConstants[lCandidate].Kind, 'const') and
            (lConstants[lCandidate].Item.Expression <> '') then
            lPossible := lPossible + [lCandidate];
        if Length(lPossible) = 0 then
          for lCandidate := 0 to High(lConstants) do
            if (aSnapshot.UnitByIndex(lConstants[lCandidate].UnitIndex).UnitId = lRef.UnitId) and
              (lConstants[lCandidate].SymbolId = lRef.SymbolId) and
              (lConstants[lCandidate].Item.Expression = '') then
            begin
              // A mutable initializer does not bound the value at later uses.
              // Retain its symbol-only unknown guard, including scoped aliases.
              lPossible := [lCandidate];
              Break;
            end;
        Result := Result + lPossible;
      end;

    end;

    function IntrinsicIsVisible(const aIndex: Integer; const aName: string): Boolean;
    var
      lRefs: TArray<TSemanticSymbolRef>;
      lComplete: Boolean;
      lContext: TConstant;
      lDefinitions: TArray<TDelphiNameFlowNode>;
      lNode: TDelphiNameFlowNode;
    begin
      lContext := lConstants[aIndex];
      lRefs := SnapshotVisibleDeclarations(aSnapshot, aSnapshot.UnitByIndex(lContext.UnitIndex),
        aName, lContext.Scope, lContext.OwnerType, lContext.Section,
        lContext.Line, lContext.Column, nil, lComplete, lUnitFacts[lContext.UnitIndex], lContext.FileName);
      Result := lComplete and (Length(lRefs) = 0);
      if not Result then
        Exit;
      if not lUnitDefinitions[lContext.UnitIndex].TryGetValue(aName, lDefinitions) then
        Exit;
      for lNode in lDefinitions do
      begin
        if (lNode.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) and
          SameText(lNode.Name, aName) and (lNode.ScopeId <> '') and
          (SameText(lNode.ScopeId, lContext.Scope) or StartsText(lNode.ScopeId + '/', lContext.Scope)) then
          Exit(False);
      end;
    end;

    procedure BindExpressionContexts;
    var
      lNode: TDelphiNameFlowNode;
      lSimple: string;
      lFact: TSemanticSymbolFact;
      lUnit: TUnitSnapshot;
      lBest, lScore, lIndex, lSymbolIndex: Integer;
    begin
      for lIndex := 0 to High(lConstants) do
      begin
        lUnit := aSnapshot.UnitByIndex(lConstants[lIndex].UnitIndex);
        if lConstants[lIndex].Item.Offset <= 0 then
          Continue; // Symbol-only guards already carry their declaration context.
        SnapshotRuntimeCoordinatesAtOffset(lLineStarts[lConstants[lIndex].UnitIndex],
          lConstants[lIndex].Item.Offset, lConstants[lIndex].Line, lConstants[lIndex].Column);
        lConstants[lIndex].Section := 'implementation';
        for lNode in lUnitContexts[lConstants[lIndex].UnitIndex].NodesAt(
          lConstants[lIndex].Line, lConstants[lIndex].Column) do
        begin
          if lNode.SyntaxKind = 'interface' then
            lConstants[lIndex].Section := 'interface';
          if Length(lNode.ScopeId) > Length(lConstants[lIndex].Scope) then
            lConstants[lIndex].Scope := lNode.ScopeId;
          if lNode.OwnerType <> '' then
            lConstants[lIndex].OwnerType := lNode.OwnerType;
          if (lNode.Kind = TDelphiNameFlowNodeKind.Routine) and (Pos('.', lNode.Name) > 0) then
            lConstants[lIndex].OwnerType := Copy(lNode.Name, 1, LastDelimiter('.', lNode.Name) - 1);
          // The lexical witness qualifies class constants with their owner;
          // AST definitions carry that owner separately from the simple name.
          if (lNode.SyntaxKind = 'constant') and SameText(lNode.Name,
            Copy(lConstants[lIndex].Item.Name,
              LastDelimiter('.', lConstants[lIndex].Item.Name) + 1, MaxInt)) then
            lConstants[lIndex].Kind := 'const';
        end;
        if lConstants[lIndex].SymbolId <> 0 then
          Continue;
        lSimple := Copy(lConstants[lIndex].Item.Name,
          LastDelimiter('.', lConstants[lIndex].Item.Name) + 1, MaxInt);
        lBest := -1;
        for lSymbolIndex := 1 to lUnit.SymbolCount do
        begin
          lFact := lUnit.SymbolById(lSymbolIndex);
          if not SameText(SnapshotText(aSnapshot, lFact.NameId), lSimple) or
            (lFact.Line > lConstants[lIndex].Line) or
            ((lFact.Line = lConstants[lIndex].Line) and (lFact.Column >= lConstants[lIndex].Column)) then
            Continue;
          if (SnapshotText(aSnapshot, lFact.OwnerTypeId) <> '') and
            not SameText(SnapshotText(aSnapshot, lFact.OwnerTypeId), lConstants[lIndex].OwnerType) then
            Continue;
          if not SameText(SnapshotText(aSnapshot, lFact.RoutineScopeId), lConstants[lIndex].Scope) then
            Continue;
          lScore := lFact.Line * 10000 + lFact.Column;
          if lScore > lBest then
          begin
            lBest := lScore;
            lConstants[lIndex].SymbolId := lFact.Id;
            lConstants[lIndex].Kind := SnapshotText(aSnapshot, lFact.KindId);
          end;
        end;
      end;
    end;

    function Evaluate(const aIndex, aDepth: Integer): Boolean; forward;

    function EvaluateName(const aIndex: Integer; const aName: string;
      const aDepth: Integer; out aValue: string; out aIsInteger: Boolean): Boolean;
    var
      lIndices: TArray<Integer>;
      lFirst: Boolean;
    begin
      Result := False;
      aValue := '';
      aIsInteger := False;
      lIndices := FindConstants(aIndex, aName);
      if Length(lIndices) <> 1 then
        Exit; // Ambiguous bindings are unknown even when their values agree.
      lFirst := True;
      for var lIndex in lIndices do
      begin
        if not SameText(lConstants[lIndex].Kind, 'const') or
          (lConstants[lIndex].Item.TypeName <> '') then
          Exit; // A mutable or typed initializer is not an immutable value binding.
        if not Evaluate(lIndex, aDepth) then
          Exit;
        if not lFirst and ((aValue <> lValues[lIndex]) or (aIsInteger <> lIntegerValues[lIndex])) then
          Exit;
        aValue := lValues[lIndex];
        aIsInteger := lIntegerValues[lIndex];
        lFirst := False;
      end;
      Result := True;
    end;

    function Evaluate(const aIndex, aDepth: Integer): Boolean;
    var
      lText: string;
      lOffset: Integer;

      procedure SkipTrivia;
      begin
        while lOffset <= Length(lText) do
        begin
          if CharInSet(lText[lOffset], [#9, #10, #13, #32]) then
            Inc(lOffset)
          else if (lText[lOffset] = '{') and (Copy(lText, lOffset, 2) <> '{$') then
          begin
            while (lOffset <= Length(lText)) and (lText[lOffset] <> '}') do
              Inc(lOffset);
            Inc(lOffset);
          end else if (Copy(lText, lOffset, 2) = '(*') and
            (Copy(lText, lOffset, 3) <> '(*$') then
          begin
            Inc(lOffset, 2);
            while (lOffset <= Length(lText)) and (Copy(lText, lOffset, 2) <> '*)') do
              Inc(lOffset);
            Inc(lOffset, 2);
          end else if Copy(lText, lOffset, 2) = '//' then
          begin
            while (lOffset <= Length(lText)) and not CharInSet(lText[lOffset], [#10, #13]) do
              Inc(lOffset);
          end else
            Break;
        end;
      end;

      function Expression(out aValue: string; out aIsInteger: Boolean;
        const aLevel: Integer): Boolean;
      var
        lPart: string;
        lPartInteger: Boolean;

        function Operand(out aPart: string; out aPartInteger: Boolean): Boolean;
        var
          lStart, lLiteralStart, lNumber, lStartIndex, lCount: Integer;
          lIdentifier, lArgument: string;
          lArguments: TArray<string>;
          lArgumentInteger: Boolean;
          lIntegerArguments: TArray<Boolean>;
        begin
          Result := False;
          aPart := '';
          aPartInteger := False;
          SkipTrivia;
          if (lOffset > Length(lText)) or (aLevel >= 64) then
            Exit;
          if lText[lOffset] = '(' then
          begin
            Inc(lOffset);
            if not Expression(aPart, aPartInteger, aLevel + 1) then
              Exit;
            SkipTrivia;
            if (lOffset > Length(lText)) or (lText[lOffset] <> ')') then
              Exit;
            Inc(lOffset);
            Exit(True);
          end;
          if CharInSet(lText[lOffset], [#39, '#']) then
          begin
            lStart := lOffset;
            Exit(NextRawStringLiteral(lText, lOffset, aPart, lLiteralStart, True) and
              (lLiteralStart = lStart));
          end;
          // Delphi caret character literals are string values, not identifiers.
          if (lText[lOffset] = '^') and (lOffset < Length(lText)) then
          begin
            while (lOffset < Length(lText)) and (lText[lOffset] = '^') do
            begin
              aPart := aPart + Char(Ord(UpCase(lText[lOffset + 1])) and 31);
              Inc(lOffset, 2);
            end;
            Exit(True);
          end;
          if CharInSet(lText[lOffset], ['0'..'9', '$']) then
          begin
            lStart := lOffset;
            Inc(lOffset);
            while (lOffset <= Length(lText)) and CharInSet(lText[lOffset], ['0'..'9', 'A'..'F', 'a'..'f']) do
              Inc(lOffset);
            Result := TryStrToInt(Copy(lText, lStart, lOffset - lStart), lNumber);
            if Result then
            begin
              aPart := IntToStr(lNumber);
              aPartInteger := True;
            end;
            Exit;
          end;
          if not IsIdentifierStart(lText[lOffset]) then
            Exit;
          lStart := lOffset;
          while (lOffset <= Length(lText)) and
            (IsIdentifierChar(lText[lOffset]) or (lText[lOffset] = '.')) do
            Inc(lOffset);
          lIdentifier := Copy(lText, lStart, lOffset - lStart);
          SkipTrivia;
          // These pure operations use only literal/immutable operands. A
          // project declaration with the same spelling keeps the call opaque.
          if (lOffset <= Length(lText)) and (lText[lOffset] = '(') and
            MatchText(lIdentifier, ['Chr', 'Ord', 'Copy', 'UpperCase', 'LowerCase', 'Concat',
              'System.Chr', 'System.Ord', 'System.Copy', 'System.Concat',
              'System.SysUtils.UpperCase', 'System.SysUtils.LowerCase']) and
            IntrinsicIsVisible(aIndex, lIdentifier) and IntrinsicIsVisible(aIndex, 'System') then
          begin
            Inc(lOffset);
            repeat
              if not Expression(lArgument, lArgumentInteger, aLevel + 1) then
                Exit;
              lArguments := lArguments + [lArgument];
              lIntegerArguments := lIntegerArguments + [lArgumentInteger];
              SkipTrivia;
              if (lOffset > Length(lText)) or (lText[lOffset] <> ',') then
                Break;
              Inc(lOffset);
            until Length(lArguments) > 256;
            if (lOffset > Length(lText)) or (lText[lOffset] <> ')') then
              Exit;
            Inc(lOffset);
            lIdentifier := lIdentifier.Split(['.'])[High(lIdentifier.Split(['.']))];
            if SameText(lIdentifier, 'Concat') then
            begin
              for lStartIndex := 0 to High(lArguments) do
              begin
                if lIntegerArguments[lStartIndex] then
                  Exit;
                aPart := aPart + lArguments[lStartIndex];
              end;
              Exit(True);
            end;
            if (Length(lArguments) = 3) and SameText(lIdentifier, 'Copy') then
            begin
              if lIntegerArguments[0] or not lIntegerArguments[1] or not lIntegerArguments[2] or
                not TryStrToInt(lArguments[1], lStartIndex) or
                not TryStrToInt(lArguments[2], lCount) then
                Exit;
              aPart := Copy(lArguments[0], lStartIndex, lCount);
              Exit(True);
            end;
            if Length(lArguments) <> 1 then
              Exit;
            lArgument := lArguments[0];
            if SameText(lIdentifier, 'Chr') then
            begin
              if not lIntegerArguments[0] or not TryStrToInt(lArgument, lNumber) or
                (lNumber < 0) or (lNumber > 65535) then
                Exit;
              aPart := Char(lNumber);
            end else if SameText(lIdentifier, 'Ord') then
            begin
              if lIntegerArguments[0] then
                aPart := lArgument
              else if Length(lArgument) = 1 then
                aPart := IntToStr(Ord(lArgument[1]))
              else
                Exit;
              aPartInteger := True;
            end else if MatchText(lIdentifier, ['UpperCase', 'LowerCase']) then
            begin
              // Avoid claiming locale-dependent Unicode casing as a constant.
              if lIntegerArguments[0] then
                Exit;
              for var ch in lArgument do
                if Ord(ch) > 127 then
                  Exit;
              if SameText(lIdentifier, 'UpperCase') then
                aPart := UpperCase(lArgument)
              else
                aPart := LowerCase(lArgument);
            end else
              Exit;
            Exit(True);
          end;
          Result := EvaluateName(aIndex, lIdentifier, aDepth + 1, aPart, aPartInteger);
        end;

      begin
        Result := Operand(aValue, aIsInteger);
        if not Result then
          Exit;
        while True do
        begin
          SkipTrivia;
          if (lOffset > Length(lText)) or (lText[lOffset] <> '+') then
            Break;
          Inc(lOffset);
          if not Operand(lPart, lPartInteger) or aIsInteger or lPartInteger then
            Exit(False); // Numeric operators require a separately typed evaluator.
          aValue := aValue + lPart;
        end;
      end;

    begin
      if lStates[aIndex] = 2 then
        Exit(True);
      if (lStates[aIndex] <> 0) or (aDepth >= 64) then
        Exit(False);
      lStates[aIndex] := 1;
      lText := lConstants[aIndex].Item.Expression;
      if lText = '' then
      begin
        lStates[aIndex] := 3;
        Exit(False);
      end;
      lOffset := 1;
      Result := Expression(lValues[aIndex], lIntegerValues[aIndex], 0);
      SkipTrivia;
      Result := Result and (lOffset > Length(lText));
      if Result then
        lStates[aIndex] := 2
      else
        lStates[aIndex] := 3;
    end;

    function ConstantOperation(const aIndex: Integer; const aName: string;
      const aDepth: Integer): Boolean;
    var
      lIndices: TArray<Integer>;
      lSource, lName: string;
    begin
      Result := False;
      if (aDepth >= 64) or (aName = '') then
        Exit;
      lIndices := FindConstants(aIndex, aName);
      if Length(lIndices) > 0 then
      begin
        // Project declarations take precedence over intrinsic spelling. Only
        // aliases to scalar types prove a cast; routines may read runtime state.
        for var lIndex in lIndices do
        begin
          if not MatchText(lConstants[lIndex].Kind, ['type', 'alias']) then
            Exit;
          lSource := aSnapshot.ExactTextOf(
            aSnapshot.UnitByIndex(lConstants[lIndex].UnitIndex).SourceTextId);
          if ContainsText(lSource, '{$IF') or ContainsText(lSource, '(*$IF') or
            ContainsText(lSource, '{$I ') or ContainsText(lSource, '{$INCLUDE') or
            not ConstantOperation(lIndex, lConstants[lIndex].Item.TypeName, aDepth + 1) then
            Exit;
        end;
        Exit(True);
      end;
      if not IntrinsicIsVisible(aIndex, aName) then
        Exit;
      lName := aName;
      if StartsText('System.SysUtils.', lName) then
        lName := Copy(lName, Length('System.SysUtils.') + 1, MaxInt)
      else if StartsText('System.', lName) then
        lName := Copy(lName, Length('System.') + 1, MaxInt);
      Result := MatchText(lName, ['Chr', 'Ord', 'Copy', 'UpperCase', 'LowerCase', 'Concat',
        'Succ', 'Pred', 'Low', 'High', 'Length', 'SizeOf', 'Abs', 'Sqr', 'Trunc', 'Round',
        'Char', 'WideChar', 'AnsiChar', 'String', 'WideString', 'AnsiString', 'ShortString',
        'UnicodeString', 'Integer', 'Byte', 'ShortInt', 'SmallInt', 'Word', 'LongInt', 'LongWord',
        'Cardinal', 'Int8', 'Int16', 'Int32', 'Int64', 'UInt8', 'UInt16', 'UInt32', 'UInt64',
        'NativeInt', 'NativeUInt', 'Boolean', 'ByteBool', 'WordBool', 'LongBool', 'Single',
        'Double', 'Extended', 'Real', 'Currency', 'Comp']);
    end;

    function ConstantOperands(const aIndex, aDepth: Integer): Boolean;
    var
      lCode, lIdentifier, lSource: string;
      lMatch: TMatch;
      lIndices: TArray<Integer>;
      lAfterIdentifier: Integer;
    begin
      Result := False;
      if (aDepth >= 64) or lVisiting[aIndex] or (lConstants[aIndex].Item.TypeName <> '') then
        Exit;
      lSource := aSnapshot.ExactTextOf(aSnapshot.UnitByIndex(lConstants[aIndex].UnitIndex).SourceTextId);
      if lConstants[aIndex].Item.Expression = '' then
        // The AST can retain an immutable declaration whose initializer the
        // lexical inventory cannot read. Its value is constant, not mutable.
        Exit(SameText(lConstants[aIndex].Kind, 'const') and
          not ContainsText(lSource, '{$IF') and not ContainsText(lSource, '(*$IF') and
          not ContainsText(lSource, '{$I ') and not ContainsText(lSource, '{$INCLUDE'));
      lCode := SanitizeCodeText(lConstants[aIndex].Item.Expression);
      lCode := TRegEx.Replace(lCode,
        '(?<![\p{L}\p{N}\p{M}_])(?:\$[0-9A-Fa-f]+|[0-9]+(?:\.[0-9]+)?(?:[Ee][+-]?[0-9]+)?)(?![\p{L}\p{N}\p{M}_])', ' ');
      lVisiting[aIndex] := True;
      try
        for lMatch in TRegEx.Matches(lCode,
          '[\p{L}_][\p{L}\p{N}\p{M}_]*(?:\.[\p{L}_][\p{L}\p{N}\p{M}_]*)*') do
        begin
          lIdentifier := lMatch.Value;
          // Prove the operation as well as its operands. A runtime call can
          // have constant arguments without returning a constant value.
          lAfterIdentifier := lMatch.Index + lMatch.Length;
          while (lAfterIdentifier <= Length(lCode)) and
            CharInSet(lCode[lAfterIdentifier], [#9, #10, #13, ' ']) do
            Inc(lAfterIdentifier);
          if (lAfterIdentifier <= Length(lCode)) and (lCode[lAfterIdentifier] = '(') then
          begin
            if not ConstantOperation(aIndex, lIdentifier, 0) then
              Exit;
            Continue;
          end;
          lConstants[aIndex].UnprovedConstantBinding := False;
          lIndices := FindConstants(aIndex, lIdentifier);
          if Length(lIndices) = 0 then
          begin
            // An uncertain true-constant binding is a constant-evaluator gap
            // only if every other operand is constant too. Mutable/runtime
            // operands still make this a soft unknown-value expression.
            if lConstants[aIndex].UnprovedConstantBinding then
              Continue;
            if MatchText(lIdentifier,
              ['div', 'mod', 'shl', 'shr', 'and', 'or', 'xor', 'not', 'true', 'false']) then
              Continue;
            Exit;
          end;
          // Direct literal operands cannot depend on an unrelated directive.
          // Named operands still need configuration-stable declaration evidence.
          if ContainsText(lSource, '{$IF') or ContainsText(lSource, '(*$IF') or
            ContainsText(lSource, '{$I ') or ContainsText(lSource, '{$INCLUDE') then
            Exit;
          for var lIndex in lIndices do
            if not ConstantOperands(lIndex, aDepth + 1) then
              Exit;
        end;
        Result := True;
      finally
        lVisiting[aIndex] := False;
      end;
    end;

    function NonStringType(const aType: string; const aDepth, aContext: Integer): Boolean;
    var
      lType: string;
      lIndices: TArray<Integer>;
    begin
      lType := LowerCase(Trim(aType));
      Result := False;
      if (lType = '') or (aDepth >= 64) then
        Exit;
      // A declared alias can shadow even Integer. Its retained type evidence
      // takes precedence over intrinsic spelling; ambiguity withholds proof.
      lIndices := FindConstants(aContext, lType);
      if Length(lIndices) > 0 then
      begin
        Result := False;
        if Length(lIndices) <> 1 then
          Exit;
        Result := True;
        for var lIndex in lIndices do
          if (lConstants[lIndex].Item.TypeName = '') or
            not NonStringType(lConstants[lIndex].Item.TypeName, aDepth + 1, lIndex) then
            Exit(False);
        Exit;
      end;
      if not IntrinsicIsVisible(aContext, lType) then
        Exit;
      Result := MatchText(lType, ['integer', 'byte', 'shortint', 'smallint', 'word',
        'longint', 'longword', 'cardinal', 'int8', 'int16', 'int32', 'int64',
        'uint8', 'uint16', 'uint32', 'uint64', 'nativeint', 'nativeuint',
        'boolean', 'bytebool', 'wordbool', 'longbool', 'single', 'double', 'extended',
        'real', 'currency', 'comp', 'pointer']) or StartsText('^', lType) or
        StartsText('set ', lType);
    end;

    // A primitive scalar cast or a complete intrinsic call proves a
    // non-string result without executing it. Nested arguments do not change
    // that result type, but their string/concatenation witnesses remain scanned.
    function NonStringCall(const aCode: string; const aContext: Integer): Boolean;
    var
      lOpen, lDepth, lIndex: Integer;
      lHead: string;
      lIndices: TArray<Integer>;
    begin
      Result := False;
      lOpen := Pos('(', aCode);
      if lOpen = 0 then
        Exit;
      lHead := Trim(Copy(aCode, 1, lOpen - 1));
      lIndices := FindConstants(aContext, lHead);
      if Length(lIndices) > 0 then
        for var lCandidateIndex in lIndices do
          if not NonStringType(lConstants[lCandidateIndex].Item.TypeName, 0, lCandidateIndex) then
            Exit; // A same-spelled declaration withholds intrinsic-call proof.
      if (Length(lIndices) = 0) and not IntrinsicIsVisible(aContext, lHead) then
        Exit;
      if not NonStringType(lHead, 0, aContext) and not MatchText(lHead,
        ['Ord', 'SizeOf', 'Length', 'Round', 'Trunc']) then
        Exit;
      lDepth := 0;
      for lIndex := lOpen to Length(aCode) do
      begin
        if aCode[lIndex] = '(' then
          Inc(lDepth)
        else if aCode[lIndex] = ')' then
        begin
          Dec(lDepth);
          if lDepth = 0 then
            Exit(Trim(Copy(aCode, lIndex + 1, MaxInt)) = '');
        end;
      end;
    end;

    function MaskNonStringCalls(const aCode: string; const aContext: Integer): string;
    var
      lMatch: TMatch;
      lStart, lIndex, lDepth: Integer;
    begin
      Result := aCode;
      // Preserve every physical offset for subsequent snapshot type lookups.
      for lMatch in TRegEx.Matches(aCode, '[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*\s*\(') do
      begin
        lStart := lMatch.Index;
        lIndex := lStart + Length(lMatch.Value) - 1;
        lDepth := 0;
        while lIndex <= Length(aCode) do
        begin
          if aCode[lIndex] = '(' then
            Inc(lDepth)
          else if aCode[lIndex] = ')' then
          begin
            Dec(lDepth);
            if lDepth = 0 then
            begin
              if NonStringCall(Copy(aCode, lStart, lIndex - lStart + 1), aContext) then
                Result := Copy(Result, 1, lStart - 1) +
                  StringOfChar(' ', lIndex - lStart) + '0' + Copy(Result, lIndex + 1, MaxInt);
              Break;
            end;
          end;
          Inc(lIndex);
        end;
      end;
    end;

    function OperandHasNonStringType(const aIndex, aRelativeOffset: Integer;
      const aIdentifier: string): Boolean;
    var
      lSource, lToken: string;
      lOffset, lLine, lColumn, lDot, i: Integer;
      lResolution: TDelphiSemanticSnapshotPositionResolution;
      lUnit: TUnitSnapshot;
      lReference: TSemanticReferenceFact;
      lScopedRefs: TArray<TSemanticSymbolRef>;
      lScopedUnit: TUnitSnapshot;
      lComplete, lMatched: Boolean;

      function ReferenceIsNonString: Boolean;
      var
        lIndex: Integer;
      begin
        Result := False;
        if not lResolution.ReferenceFound then
          Exit;
        if SameText(SnapshotText(aSnapshot, lResolution.Symbol.KindId), 'const') and
          (lResolution.Reference.WithId = 0) then
          Exit; // Constant values/types use lexical lookup, never a position fallback.
        for lIndex := 0 to High(lConstants) do
          if (lConstants[lIndex].SymbolId = lResolution.SymbolRef.SymbolId) and
            (aSnapshot.UnitByIndex(lConstants[lIndex].UnitIndex).UnitId = lResolution.SymbolRef.UnitId) then
          begin
            if NonStringType(SnapshotText(aSnapshot, lResolution.Symbol.TypeId), 0, lIndex) then
              Exit(True);
            // WITH binding is recorded by the DS resolver. It can prove that
            // this reference has a numeric value without folding a string via
            // the less precise position resolver or a bare-name index.
            if (lResolution.Reference.WithId <> 0) and
              SameText(SnapshotText(aSnapshot, lResolution.Symbol.KindId), 'const') and
              (lConstants[lIndex].Item.Expression <> '') and Evaluate(lIndex, 0) and
              lIntegerValues[lIndex] then
              Exit(True);
          end;
      end;

    begin
      Result := False;
      lUnit := aSnapshot.UnitByIndex(lConstants[aIndex].UnitIndex);
      lDot := LastDelimiter('.', aIdentifier);
      lToken := Copy(aIdentifier, lDot + 1, MaxInt);
      if not SameText(lConstants[aIndex].FileName, SnapshotText(aSnapshot, lUnit.FileNameId)) then
      begin
        // Include witnesses have no raw-unit offset. Join every retained
        // occurrence of the operand in that physical include; one unknown or
        // nonnumeric binding withholds type proof. No value is folded here.
        lMatched := False;
        for i := 1 to lUnit.ReferenceCount do
        begin
          lReference := lUnit.ReferenceById(i);
          if not SameText(SnapshotText(aSnapshot, lReference.NameId), lToken) or
            not SameText(SnapshotText(aSnapshot, lReference.FileId), lConstants[aIndex].FileName) then
            Continue;
          if lReference.Line <= 0 then
            Exit;
          // Unlinked include references retain lexical scope. Ask the same DS
          // resolver for the complete visible set, with same-file coordinates.
          lScopedRefs := SnapshotVisibleDeclarations(aSnapshot, lUnit, lToken,
            SnapshotText(aSnapshot, lReference.RoutineScopeId), '',
            SnapshotText(aSnapshot, lReference.SectionKindId), lReference.Line, lReference.Column,
            nil, lComplete, lUnitFacts[lConstants[aIndex].UnitIndex], lConstants[aIndex].FileName);
          if not lComplete or (Length(lScopedRefs) <> 1) or
            not aSnapshot.TryFindUnitById(lScopedRefs[0].UnitId, lScopedUnit) then
            Exit;
          lResolution := Default(TDelphiSemanticSnapshotPositionResolution);
          lResolution.SymbolRef := lScopedRefs[0];
          lResolution.Symbol := lScopedUnit.SymbolById(lScopedRefs[0].SymbolId);
          lResolution.ReferenceFound := True;
          if not ReferenceIsNonString then
            Exit;
          lMatched := True;
        end;
        Exit(lMatched);
      end;
      lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
      lOffset := lConstants[aIndex].Item.Offset + aRelativeOffset + lDot;
      if (lOffset < 1) or (lOffset > Length(lSource)) then
        Exit;
      SnapshotRuntimeCoordinatesAtOffset(lLineStarts[lConstants[aIndex].UnitIndex],
        lOffset, lLine, lColumn);
      if TryResolveSnapshotPosition(aSnapshot, lConstants[aIndex].FileName,
        lLine, lColumn, lToken, lResolution) then
        Result := ReferenceIsNonString;
    end;

    // A flat record/array does not concatenate its fields. Literal string
    // fields are already scanned, and non-string fields cannot supply a name.
    // Unknown field types, nested records and unknown string values withhold
    // this proof. AnsiChar/Char fields have a one-character value bound.
    function StructuredValueCovered(const aIndex: Integer): Boolean;
    var
      lLexer: TmwBasePasLex;
      lType, lField, lValue, lFieldType, lLiteral: string;
      lMatch: TMatch;
      lIndices: TArray<Integer>;
      lStart, lDepth, lCursor, lLiteralStart: Integer;
      lCovered, lSawField, lLongNames: Boolean;
    begin
      Result := False;
      lType := Trim(lConstants[aIndex].Item.TypeName);
      if StartsText('array', lType) then
      begin
        lMatch := TRegEx.Match(lType, '\bof\s+([A-Za-z_][A-Za-z_0-9.]*)\s*$', [roIgnoreCase]);
        if not lMatch.Success then
          Exit;
        lType := lMatch.Groups[1].Value;
      end;
      if (lType = '') or ContainsText(lType, 'string') then
        Exit;
      lLongNames := True;
      for var lName in aNames do
        lLongNames := lLongNames and (Length(lName) > 1);
      lLexer := TmwBasePasLex.Create;
      try
        lLexer.UseDefines := False;
        lLexer.Origin := lConstants[aIndex].Item.Expression;
        lSawField := False;
        while lLexer.TokenID <> ptNull do
        begin
          if lLexer.TokenID <> ptIdentifier then
          begin
            lLexer.NextNoJunk;
            Continue;
          end;
          lField := lLexer.Token.TrimLeft(['&']);
          lLexer.NextNoJunk;
          if lLexer.Token <> ':' then
            Exit; // An array scalar or another unsupported value shape.
          lSawField := True;
          lLexer.NextNoJunk;
          lStart := lLexer.TokenPos + 1;
          lDepth := 0;
          while lLexer.TokenID <> ptNull do
          begin
            if (lDepth = 0) and MatchText(lLexer.Token, [';', ')']) then
              Break;
            if lLexer.Token = ':' then
              Exit; // A nested record requires its own field-owner proof.
            if lLexer.Token = '(' then
              Inc(lDepth)
            else if lLexer.Token = ')' then
              Dec(lDepth);
            lLexer.NextNoJunk;
          end;
          lValue := Trim(Copy(lConstants[aIndex].Item.Expression, lStart,
            lLexer.TokenPos + 1 - lStart));
          lIndices := FindConstants(aIndex, lType + '.' + lField);
          if Length(lIndices) = 0 then
            Exit;
          for var lIndex in lIndices do
          begin
            lFieldType := Trim(lConstants[lIndex].Item.TypeName);
            lCovered := NonStringType(lFieldType, 0, aIndex) or (lLongNames and
              MatchText(lFieldType, ['Char', 'AnsiChar', 'WideChar', 'System.Char',
                'System.AnsiChar', 'System.WideChar']));
            if ContainsText(lFieldType, 'string') then
            begin
              lCursor := 1;
              lCovered := NextRawStringLiteral(lValue, lCursor, lLiteral, lLiteralStart, True) and
                (lLiteralStart = 1) and (Trim(Copy(lValue, lCursor, MaxInt)) = '');
            end;
            if not lCovered then
              Exit;
          end;
        end;
        Result := lSawField;
      finally
        lLexer.Free;
      end;
    end;

    function CouldSupplyName(const aIndex, aDepth: Integer): Boolean;
    var
      lText, lCode, lValue, lIdentifier: string;
      lMatch: TMatch;
      lLiteral: TDelphiSemanticStringLiteral;
      lDependencies: TArray<Integer>;
      lHasString, lUnknownString, lIncompatible, lKnownNonString, lRelevant, lStructured, lIsInteger: Boolean;

      procedure AddFragment(const aValue: string);
      var
        lFits: Boolean;
        lName: string;
      begin
        lHasString := True;
        lFits := aValue = '';
        for lName in aNames do
          lFits := lFits or ContainsText(lName, aValue);
        lIncompatible := lIncompatible or not lFits;
      end;

    begin
      if (aDepth >= 64) or lVisiting[aIndex] then
        Exit(True);
      lText := Trim(lConstants[aIndex].Item.Expression);
      if NonStringType(lConstants[aIndex].Item.TypeName, 0, aIndex) then
        Exit(False);
      // Structured values are not names. Their literals and nested '+'
      // expressions have their own independent witnesses.
      if StartsText('[', lText) then
        Exit(False); // A set's elements cannot turn its value into a string.
      lStructured := StartsText('array', Trim(lConstants[aIndex].Item.TypeName)) or
        StartsText('record', Trim(lConstants[aIndex].Item.TypeName)) or
        ((Copy(lText, 1, 1) = '(') and (Pos(':', SanitizeCodeText(lText)) > 0));
      if lStructured and StructuredValueCovered(aIndex) then
        Exit(False);
      lCode := MaskNonStringCalls(SanitizeCodeText(lText), aIndex);
      if lStructured then
        lCode := TRegEx.Replace(lCode, '\b[A-Za-z_][A-Za-z_0-9]*\s*:', ' ');
      if NonStringCall(Trim(lCode), aIndex) then
        Exit(False);
      if (lCode <> '') and TRegEx.IsMatch(lCode,
        '^(?:\s|(?:\$[0-9A-Fa-f]+)|(?:\d+(?:\.\d+)?(?:[Ee][+-]?\d+)?)|[.+*/()<>:=\-])+$') then
        Exit(False);
      lVisiting[aIndex] := True;
      try
        lHasString := not lStructured and (ContainsText(lConstants[aIndex].Item.TypeName, 'string') or
          MatchText(Trim(lConstants[aIndex].Item.TypeName), ['char', 'ansichar', 'widechar']));
        lUnknownString := False;
        lIncompatible := False;
        lKnownNonString := False;
        for lLiteral in StringLiteralCandidates(lText, True) do
          AddFragment(lLiteral.Value);
        for lMatch in TRegEx.Matches(lCode,
          '[A-Za-z_][A-Za-z_0-9]*(?:\.[A-Za-z_][A-Za-z_0-9]*)*') do
        begin
          lIdentifier := lMatch.Value;
          if MatchText(lIdentifier, ['nil', 'true', 'false', 'div', 'mod', 'shl', 'shr',
            'and', 'or', 'xor', 'not']) then
          begin
            lKnownNonString := True;
            Continue;
          end;
          if EvaluateName(aIndex, lIdentifier, aDepth + 1, lValue, lIsInteger) then
          begin
            if lIsInteger then
              lKnownNonString := True
            else
              AddFragment(lValue);
            Continue;
          end;
          if OperandHasNonStringType(aIndex, lMatch.Index - 1, lIdentifier) then
          begin
            lKnownNonString := True;
            Continue;
          end;
          lDependencies := FindConstants(aIndex, lIdentifier);
          if Length(lDependencies) = 0 then
          begin
            // Implicit System.sLineBreak is a control-character string on all
            // certified platforms. Imports or declarations can shadow its bare
            // spelling; without absence proof we keep the value unknown.
            if (SameText(lIdentifier, 'System.sLineBreak') and
              IntrinsicIsVisible(aIndex, 'System')) or
              (SameText(lIdentifier, 'sLineBreak') and
              (Length(aSnapshot.UnitByIndex(lConstants[aIndex].UnitIndex).ImportFacts) = 0)) then
              AddFragment(#10)
            else
              lUnknownString := True;
            Continue;
          end;
          lRelevant := False;
          for var lDependency in lDependencies do
            lRelevant := lRelevant or CouldSupplyName(lDependency, aDepth + 1);
          if lRelevant then
            lUnknownString := True
          else
            lKnownNonString := True;
        end;
        // Unknown string operands may themselves supply a complete name. A
        // known incompatible fragment alone cannot excuse such an operand.
        Result := lUnknownString or (not lStructured and lHasString and
          not lIncompatible and not lKnownNonString);
        if (lText = '') and not lKnownNonString then
          Result := not NonStringType(lConstants[aIndex].Item.TypeName, 0, aIndex);
      finally
        lVisiting[aIndex] := False;
      end;
    end;

  begin
    lByName := TDictionary<string, TArray<Integer>>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    lAliases := TDictionary<string, string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    try
      for i := 0 to aSnapshot.UnitCount - 1 do
      begin
        lUnit := aSnapshot.UnitByIndex(i);
        lConstant := Default(TConstant);
        lConstant.Owner := SnapshotText(aSnapshot, lUnit.UnitNameId);
        lConstant.FileName := SnapshotText(aSnapshot, lUnit.FileNameId);
        lConstant.UnitIndex := i;
        for var lItem in StringExpressionWitnesses(aSnapshot.ExactTextOf(lUnit.SourceTextId)) do
        begin
          lConstant.Item := lItem;
          lConstants := lConstants + [lConstant];
          if lConstant.Item.Name <> '' then
            IndexName(lConstant.Owner + '.' + lConstant.Item.Name, High(lConstants));
        end;
        for j := 1 to lUnit.ReferenceCount do
        begin
          lFact := lUnit.ReferenceById(TSemanticReferenceId(j));
          if not SameText(SnapshotText(aSnapshot, lFact.ClassificationId), 'string-constant-expression') then
            Continue;
          lConstant.Item := Default(TDelphiSemanticStringConstant);
          lConstant.Item.Name := SnapshotText(aSnapshot, lFact.ReasonId);
          lConstant.Item.TypeName := SnapshotText(aSnapshot, lFact.TypeId);
          lConstant.Item.Expression := SnapshotText(aSnapshot, lFact.LookupSourceId);
          lConstant.FileName := SnapshotText(aSnapshot, lFact.FileId);
          lConstant.SymbolId := 0;
          lConstant.Kind := '';
          lConstant.Line := 0;
          lConstant.Column := 0;
          lConstant.Scope := '';
          lConstant.OwnerType := '';
          lConstant.Section := '';
          if lConstant.Item.Name <> '' then
            for k := 1 to lUnit.SymbolCount do
            begin
              lSymbol := lUnit.SymbolById(k);
              if not SameText(SnapshotText(aSnapshot, lSymbol.NameId), lConstant.Item.Name) or
                not SameText(SnapshotText(aSnapshot, lSymbol.FileId), lConstant.FileName) then
                Continue;
              if lConstant.SymbolId <> 0 then
              begin
                lConstant.SymbolId := 0;
                Break; // Repeated include declarations cannot share a value binding.
              end;
              lConstant.SymbolId := lSymbol.Id;
              lConstant.Line := lSymbol.Line;
              lConstant.Column := lSymbol.Column;
              lConstant.Kind := SnapshotText(aSnapshot, lSymbol.KindId);
              lConstant.Scope := SnapshotText(aSnapshot, lSymbol.RoutineScopeId);
              lConstant.OwnerType := SnapshotText(aSnapshot, lSymbol.OwnerTypeId);
              lConstant.Section := SnapshotText(aSnapshot, lSymbol.SectionKindId);
            end;
          lConstants := lConstants + [lConstant];
          if lConstant.Item.Name <> '' then
            IndexName(lConstant.Owner + '.' + lConstant.Item.Name, High(lConstants));
        end;
        // Mutable and unresolved symbols participate only as unknown operands,
        // preventing a same-spelled constant from proving a shadowed value.
        for j := 1 to lUnit.SymbolCount do
        begin
          lSymbol := lUnit.SymbolById(TSemanticSymbolId(j));
          if not MatchText(SnapshotText(aSnapshot, lSymbol.KindId),
            ['const', 'var', 'threadvar', 'field', 'class-var', 'property', 'parameter', 'local', 'type', 'alias', 'enum-value', 'routine']) then
            Continue;
          lConstant.SymbolId := lSymbol.Id;
          lConstant.Line := lSymbol.Line;
          lConstant.Column := lSymbol.Column;
          lConstant.Scope := SnapshotText(aSnapshot, lSymbol.RoutineScopeId);
          lConstant.OwnerType := SnapshotText(aSnapshot, lSymbol.OwnerTypeId);
          lConstant.Section := SnapshotText(aSnapshot, lSymbol.SectionKindId);
          lConstant.Kind := SnapshotText(aSnapshot, lSymbol.KindId);
          lConstant.Item := Default(TDelphiSemanticStringConstant);
          lConstant.Item.Name := SnapshotText(aSnapshot, lSymbol.NameId);
          lConstant.Item.TypeName := SnapshotText(aSnapshot, lSymbol.TypeId);
          if SameText(SnapshotText(aSnapshot, lSymbol.KindId), 'enum-value') then
            lConstant.Item.TypeName := 'Integer';
          lOwnerType := SnapshotText(aSnapshot, lSymbol.OwnerTypeId);
          if lOwnerType <> '' then
            lConstant.Item.Name := lOwnerType + '.' + lConstant.Item.Name;
          // Preserve existing initializer values instead of adding an empty
          // duplicate. Missing AST-proved immutable declarations still guard
          // unsupported constant operations, including Unicode identifiers.
          if SameText(lConstant.Kind, 'const') and
            lByName.ContainsKey(lConstant.Owner + '.' + lConstant.Item.Name) then
            Continue;
          lConstants := lConstants + [lConstant];
        end;
        for lImport in lUnit.ImportFacts do
          for k := 0 to aSnapshot.UnitCount - 1 do
          begin
            lImportedUnit := aSnapshot.UnitByIndex(k);
            if SameText(lImport.TargetFileName, SnapshotText(aSnapshot, lImportedUnit.FileNameId)) then
            begin
              lAlias := lConstant.Owner + '|' + lImport.Name;
              lName := SnapshotText(aSnapshot, lImportedUnit.UnitNameId);
              if lAliases.ContainsKey(lAlias) and not SameText(lAliases[lAlias], lName) then
                lAliases[lAlias] := '<ambiguous-import>'
              else
                lAliases.AddOrSetValue(lAlias, lName);
            end;
          end;
      end;
      SetLength(lUnitFacts, aSnapshot.UnitCount);
      SetLength(lUnitContexts, aSnapshot.UnitCount);
      SetLength(lLineStarts, aSnapshot.UnitCount);
      SetLength(lUnitDefinitions, aSnapshot.UnitCount);
      for i := 0 to aSnapshot.UnitCount - 1 do
      begin
        lUnitFacts[i] := NameFlowFactsFromJson(aSnapshot.ExactTextOf(aSnapshot.UnitByIndex(i).NameFlowFactsJsonId));
        lUnitContexts[i].Initialize(lUnitFacts[i]);
        lUnitSource := aSnapshot.ExactTextOf(aSnapshot.UnitByIndex(i).SourceTextId);
        lLineCount := 1;
        for j := 1 to Length(lUnitSource) do
          if lUnitSource[j] = #10 then
            Inc(lLineCount);
        SetLength(lLineStarts[i], lLineCount);
        lLineStarts[i][0] := 1;
        lLineCount := 1;
        for j := 1 to Length(lUnitSource) do
          if lUnitSource[j] = #10 then
          begin
            lLineStarts[i][lLineCount] := j + 1;
            Inc(lLineCount);
          end;
        lUnitDefinitions[i] := TDictionary<string, TArray<TDelphiNameFlowNode>>.Create(
          TFastCaseAwareComparer.OrdinalIgnoreCase);
        // Runtime facts are immutable. Copy each definition once, then apply
        // lexical precedence only to its same-spelled candidate set.
        for j := 1 to lUnitFacts[i].NodeCount do
        begin
          lDefinition := lUnitFacts[i].NodeById(j);
          if not (lDefinition.Kind in [TDelphiNameFlowNodeKind.Definition, TDelphiNameFlowNodeKind.Formal]) or
            (lDefinition.Name = '') then
            Continue;
          if not lUnitDefinitions[i].TryGetValue(lDefinition.Name, lDefinitionNodes) then
            lDefinitionNodes := nil;
          lUnitDefinitions[i].AddOrSetValue(lDefinition.Name, lDefinitionNodes + [lDefinition]);
        end;
      end;
      BindExpressionContexts;

      SetLength(lValues, Length(lConstants));
      SetLength(lStates, Length(lConstants));
      SetLength(lVisiting, Length(lConstants));
      SetLength(lIntegerValues, Length(lConstants));
      for i := 0 to High(lConstants) do
        if lConstants[i].Item.Name <> '' then
        begin
          IndexName(lConstants[i].Item.Name, i);
          IndexName(lConstants[i].Owner + '.' + lConstants[i].Item.Name, i);
          if Pos('.', lConstants[i].Item.Name) > 0 then
            IndexName(lConstants[i].Item.Name.Split(['.'])[High(lConstants[i].Item.Name.Split(['.']))], i);
        end;
      for i := 0 to High(lConstants) do
      begin
        if lConstants[i].Item.Expression = '' then
          Continue;
        if Evaluate(i, 0) then
        begin
          for lName in aNames do
            if MatchText(lName, lValues[i].Split(['.'])) then
              Report(lConstants[i].FileName, 'string-name-consumer', lName, 0, 0);
        end else if CouldSupplyName(i, 0) or lConstants[i].UnprovedConstantBinding then
        begin
          lName := lConstants[i].Item.Name;
          if lName = '' then
            lName := lConstants[i].Item.Expression.Trim;
          if ConstantOperands(i, 0) then
            Report(lConstants[i].FileName, 'string-constant-evaluator-unsupported', lName, 0, 0)
          else
            Report(lConstants[i].FileName, 'string-constant-value-unproved', lName, 0, 0);
        end;
      end;
    finally
      for var lDefinitions in lUnitDefinitions do
        lDefinitions.Free;
      lAliases.Free;
      lByName.Free;
    end;
  end;

  procedure CheckUnitTokens(const aCurrentUnit: TUnitSnapshot);
  var
    lSource, lScan, lActive, lEvidence, lName, lFileName: string;
    lOffset, lScanned, lLine, lLineStart, lEnd, lPrevious, lIndex: Integer;
    lReference: TSemanticReferenceFact;
    lDeclaration: TSemanticSymbolFact;
    lIsDeclaration, lInAsm: Boolean;
  begin
    lInAsm := False;
    lSource := aSnapshot.ExactTextOf(aCurrentUnit.SourceTextId);
    lEvidence := aSnapshot.ExactTextOf(aCurrentUnit.VerifiedActiveSourceTextId);
    lScan := SanitizeCodeText(lSource);
    lActive := TDelphiSemanticSourceConditionals.SourceForScan(lSource, lEvidence);
    lFileName := SnapshotText(aSnapshot, aCurrentUnit.FileNameId);
    lScanned := 1;
    lLine := 1;
    lLineStart := 1;
    lOffset := 1;
    while lOffset <= Length(lScan) do
    begin
      if not CharInSet(lScan[lOffset], ['A'..'Z', 'a'..'z', '_', '&']) then
      begin
        Inc(lOffset);
        Continue;
      end;
      lEnd := lOffset + 1;
      while (lEnd <= Length(lScan)) and CharInSet(lScan[lEnd], ['A'..'Z', 'a'..'z', '0'..'9', '_']) do
        Inc(lEnd);
      lName := Copy(lScan, lOffset, lEnd - lOffset);
      if StartsText('&', lName) then
        Delete(lName, 1, 1);
      if SameText(lName, 'asm') then
        lInAsm := True
      else if SameText(lName, 'end') then
        lInAsm := False;
      if (lInAsm and (SameText(lName, aSymbol.Name) or MatchText(lName, aNames))) or
        (MatchText(lName, aNames) and
        not TDelphiSemanticSourceConditionals.NeverAtOffset(lSource, lEvidence, lOffset)) then
      begin
        while lScanned < lOffset do
        begin
          if lSource[lScanned] = #10 then
          begin
            Inc(lLine);
            lLineStart := lScanned + 1;
          end;
          Inc(lScanned);
        end;
        // Assembly tokens have no certified binding/edit facts. Reconcile both
        // spellings in every raw asm span, including conditional and pure bodies.
        if lInAsm then
        begin
          Report(lFileName, 'unclassified-occurrence', lName, lLine, lOffset - lLineStart + 1);
          lOffset := lEnd;
          Continue;
        end;
        lReference := Default(TSemanticReferenceFact);
        for lIndex := 1 to aCurrentUnit.ReferenceCount do
          if (aCurrentUnit.ReferenceById(TSemanticReferenceId(lIndex)).Line = lLine) and
            (aCurrentUnit.ReferenceById(TSemanticReferenceId(lIndex)).Column = lOffset - lLineStart + 1) and
            ((aCurrentUnit.ReferenceById(TSemanticReferenceId(lIndex)).FileId = 0) or
            (aCurrentUnit.ReferenceById(TSemanticReferenceId(lIndex)).FileId = aCurrentUnit.FileNameId)) then
          begin
            lReference := aCurrentUnit.ReferenceById(TSemanticReferenceId(lIndex));
            Break;
          end;
        lIsDeclaration := False;
        for lIndex := 1 to aCurrentUnit.SymbolCount do
        begin
          lDeclaration := aCurrentUnit.SymbolById(TSemanticSymbolId(lIndex));
          if (lDeclaration.Line = lLine) and (lDeclaration.Column = lOffset - lLineStart + 1) and
            ((lDeclaration.FileId = 0) or (lDeclaration.FileId = aCurrentUnit.FileNameId)) then
          begin
            lIsDeclaration := True;
            Break;
          end;
        end;
        if not lIsDeclaration and (lReference.NameId = 0) and
          not SameText(lName, aSymbol.Name) then
          Report(lFileName, 'unclassified-new-name-occurrence', lName,
            lLine, lOffset - lLineStart + 1);
        lPrevious := lOffset - 1;
        while (lPrevious > 0) and CharInSet(lScan[lPrevious], [#9, #10, #13, ' ']) do
          Dec(lPrevious);
        if lIsDeclaration and not lLocal and SameText(lName, aSymbol.Name) and
          (lDeclaration.RoutineId = 0) and
          SameText(SnapshotText(aSnapshot, lDeclaration.SectionKindId), 'interface') then
          CheckImports(lFileName, 'implementation', lFileName, lName, False, True, lLine,
            lOffset - lLineStart + 1)
        else if lIsDeclaration and not lLocal and SameText(lName, aSymbol.Name) and
          SameText(SnapshotText(aSnapshot, lDeclaration.KindId), 'routine') and
          SameText(SnapshotText(aSnapshot, lDeclaration.SectionKindId), 'interface') then
          // An unseen direct import can itself reference an exported declaration,
          // even when the declaring unit has no expression using its old name.
          CheckImports(lFileName, 'implementation', lFileName, lName, False, True, lLine,
            lOffset - lLineStart + 1)
        else if (lLocalMemberContext and not SameText(lName, aSymbol.Name)) or not lIsDeclaration or
          (lLocal and (not SameText(lName, aSymbol.Name) or
          SnapshotPositionInWith(aCurrentUnit, lLine, lOffset - lLineStart + 1))) then
          CheckOccurrence(aCurrentUnit, lFileName, lName, lLine, lOffset - lLineStart + 1,
            (Copy(lActive, lOffset, lEnd - lOffset) <> Copy(lSource, lOffset, lEnd - lOffset)) or
            TDelphiSemanticSourceConditionals.UnknownAtOffset(lSource, lEvidence, lOffset),
            (lPrevious > 0) and (lScan[lPrevious] = '.'), lReference);
      end;
      lOffset := lEnd;
    end;
    // Included and possible-only files have physical reference coordinates;
    // their selected/inactive provenance remains authoritative for refusal.
    for lIndex := 1 to aCurrentUnit.ReferenceCount do
    begin
      lReference := aCurrentUnit.ReferenceById(TSemanticReferenceId(lIndex));
      if (lReference.FileId = 0) or (lReference.FileId = aCurrentUnit.FileNameId) or
        not MatchText(SnapshotText(aSnapshot, lReference.NameId), aNames) then
        Continue;
      CheckOccurrence(aCurrentUnit, SnapshotText(aSnapshot, lReference.FileId),
        SnapshotText(aSnapshot, lReference.NameId), lReference.Line, lReference.Column,
        MatchText(SnapshotText(aSnapshot, lReference.ReasonId),
          ['occurrence-in-inactive-configuration', 'unverified-condition']),
        lReference.ReceiverTypeId <> 0, lReference);
    end;
  end;

begin
  lImports := TObjectDictionary<string, TList<TDelphiSemanticImportFact>>.Create(
    [doOwnsValues], TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSeen := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lReported := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lResult := TList<TDelphiSemanticUsage>.Create;
  lRetained := THashSet<string>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lPackage := False;
    for i := 0 to aSnapshot.UnitCount - 1 do
    begin
      lUnit := aSnapshot.UnitByIndex(i);
      lPackage := lPackage or TRegEx.IsMatch(SanitizeCodeText(
        aSnapshot.ExactTextOf(lUnit.SourceTextId)), '^\s*package\b', [roIgnoreCase]);
      if aSnapshot.ExactTextOf(lUnit.SourceTextId) <> '' then
        lRetained.Add(SnapshotText(aSnapshot, lUnit.FileNameId));
    end;
    lLocal := SnapshotLocalTarget(aSnapshot, aSymbol, lLocalUnit, lLocalFact);
    lLocalMemberContext := False;
    if lLocal then
      for i := 1 to lLocalUnit.ReferenceCount do
      begin
        lReference := lLocalUnit.ReferenceById(TSemanticReferenceId(i));
        if SameText(SnapshotText(aSnapshot, lReference.NameId), aSymbol.Name) and
          ((lReference.WithId <> 0) or (lReference.ReceiverTypeId <> 0) or
          SnapshotPositionInWith(lLocalUnit, lReference.Line, lReference.Column) or
          SnapshotPositionInMethod(aSnapshot, lLocalUnit, lReference.Line)) then
          lLocalMemberContext := True;
      end;
    for i := 0 to aSnapshot.UnitCount - 1 do
      for lFact in aSnapshot.UnitByIndex(i).ImportFacts do
      begin
        lKey := lFact.OwnerFileName + '|' + lFact.SectionKind + '|' + lFact.OrderIndex.ToString +
          '|' + lFact.Name + '|' + lFact.TargetFileName + '|' + lFact.Cause + '|' + lFact.GapReason +
          '|' + BoolToStr(lFact.ResolutionVaries, True) + '|' + BoolToStr(lFact.Unconditional, True);
        if lSeen.Contains(lKey) then
          Continue;
        lSeen.Add(lKey);
        if not lImports.TryGetValue(lFact.OwnerFileName, lEdges) then
        begin
          lEdges := TList<TDelphiSemanticImportFact>.Create;
          lImports.Add(lFact.OwnerFileName, lEdges);
        end;
        lEdges.Add(lFact);
        // Coverage is independent of lexical shadowing and local scope.
        // Every retained active import must itself have captured raw text;
        // otherwise its inactive names and further imports are unknown.
        if (lFact.Cause = '') and not lFact.SdkBoundary and
          (lFact.TargetFileName <> '') and not lRetained.Contains(lFact.TargetFileName) then
          Report(lFact.TargetFileName, 'active-import-source-not-retained', aSymbol.Name, 0, 0);
      end;
    for i := 0 to aSnapshot.UnitCount - 1 do
    begin
      lUnit := aSnapshot.UnitByIndex(i);
      CheckUnitTokens(lUnit);
      CheckImplicitConsumers(lUnit);
      for j := 1 to lUnit.ReferenceCount do
      begin
        lReference := lUnit.ReferenceById(TSemanticReferenceId(j));
        if not SameText(SnapshotText(aSnapshot, lReference.ClassificationId),
          cSnapshotReferenceClassificationUnseenSource) then
          Continue;
        if SameText(SnapshotText(aSnapshot, lReference.ReasonId), 'possible-unit-source-unavailable') then
          Continue;
        AddUnresolvedUsage(lResult, aSnapshot, lUnit, '', '', '', lReference.Line, 0,
          SnapshotText(aSnapshot, lReference.ReasonId), lReference.FileId);
      end;
    end;
    CheckStringConstants;

    Result := SortedUsages(lResult);
  finally
    lRetained.Free;
    lResult.Free;
    lReported.Free;
    lSeen.Free;
    lImports.Free;
  end;
end;

class function TDelphiSemanticUsageFinder.PossibleImportGaps(
  const aContext: TDelphiSemanticSymbolQueryContext;
  const aSymbol: TDelphiSemanticIndexedSymbol; const aNames: TArray<string>): TArray<TDelphiSemanticUsage>;
var
  lSnapshot: TDelphiProjectSnapshot;
begin
  lSnapshot := ContextProjectSnapshot(aContext);
  if lSnapshot = nil then
    Exit(nil);
  Result := ScopedSnapshotSourceGaps(lSnapshot, aSymbol, aNames);
end;

function CollectSnapshotUnresolvedUsages(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TDelphiSemanticIndexedSymbol; const aEquivalentRefs: TList<TSemanticSymbolRef>;
  const aUsages: TList<TDelphiSemanticUsage>;
  out aHasUnverifiedConditionals: Boolean): TArray<TDelphiSemanticUsage>;
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
  lScanSource: string;
  lSource: string;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lTarget: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnresolved: TList<TDelphiSemanticUsage>;
  lUpperSource: string;
  lActiveSource: string;
  lUsage: TDelphiSemanticUsage;
  lVerified: Boolean;
begin
  aHasUnverifiedConditionals := False;
  lCovered := TDictionary<string, Byte>.Create;
  lDeclarations := TDictionary<string, TSemanticSymbolRef>.Create;
  lHandled := TDictionary<string, Byte>.Create;
  lUnresolved := TList<TDelphiSemanticUsage>.Create;
  try
    for lUsage in aUsages do
      lCovered.AddOrSetValue(SnapshotPositionKey(lUsage.FileName, lUsage.Line, lUsage.Column), 0);
    lName := aSymbol.Name;
    // Includes retain their coverage barrier. Missing imports are scoped to
    // nonlocal occurrences and possible uses reachability, including inactive uses.
    lUnresolved.AddRange(ScopedSnapshotSourceGaps(aSnapshot, aSymbol, [lName]));
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
        if SameText(SnapshotText(aSnapshot, lReference.ClassificationId),
          'occurrence-in-inactive-configuration') then
        begin
          lKey := SnapshotPositionKey(SnapshotFactFileName(aSnapshot, lUnit, lReference.FileId),
            lReference.Line, lReference.Column);
          if not lCovered.ContainsKey(lKey) and not lDeclarations.ContainsKey(lKey) then
            AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit, lName, '', '',
              lReference.Line, lReference.Column,
              SnapshotText(aSnapshot, lReference.ClassificationId), lReference.FileId);
          Continue;
        end;
        if SameText(SnapshotText(aSnapshot, lReference.ClassificationId),
          'unverified-condition') then
        begin
          aHasUnverifiedConditionals := True;
          AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit, lName,
            SnapshotText(aSnapshot, lReference.RoutineId), SnapshotText(aSnapshot,
            lReference.SectionKindId), lReference.Line, lReference.Column,
            'unclassified-occurrence', lReference.FileId);
          Continue;
        end;
        if SnapshotUnknownActivity(aSnapshot, lUnit, lReference.FileId,
          lReference.Line, lReference.Column) then
          Continue;
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

    // Occurrences no fact describes: extraction gaps and unverified conditional activity.
    lNeedle := UpperCase(lName);
    for i := 0 to Pred(aSnapshot.UnitCount) do
    begin
      lUnit := aSnapshot.UnitByIndex(i);
      lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
      if (lSource = '') or not ContainsText(lSource, lName) then
        Continue;
      lVerified := IsVerifiedScopeStatus(SnapshotText(aSnapshot, lUnit.ScopeModelStatusId));
      lFileName := SnapshotText(aSnapshot, lUnit.FileNameId);
      lActiveSource := aSnapshot.ExactTextOf(lUnit.VerifiedActiveSourceTextId);
      // A certificate proves one configuration. Keep other configurations' tokens
      // visible to generic usage/rename completeness, without binding or editing them.
      lScanSource := TDelphiSemanticSourceConditionals.SourceForScan(lSource, lActiveSource);
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
        if IsWordAt(lUpperSource, lPosition, lNeedle) and
          not TDelphiSemanticSourceConditionals.NeverAtOffset(lSource, lActiveSource, lPosition) then
        begin
          lColumn := lPosition - lLineStart + 1;
          lKey := SnapshotPositionKey(lFileName, lLine, lColumn);
          if TDelphiSemanticSourceConditionals.UnknownAtOffset(lSource, lActiveSource, lPosition) then
            aHasUnverifiedConditionals := True;
          if lVerified and (lScanSource[lPosition] <> lSource[lPosition]) then
            AddUnresolvedUsage(lUnresolved, aSnapshot, lUnit,
              Copy(lSource, lPosition, Length(lName)), '', '', lLine, lColumn,
              'occurrence-in-inactive-configuration')
          else if TDelphiSemanticSourceConditionals.UnknownAtOffset(lSource, lActiveSource,
            lPosition) or (not lCovered.ContainsKey(lKey) and not lHandled.ContainsKey(lKey) and
            not (lVerified and lDeclarations.ContainsKey(lKey))) then
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
        if not SnapshotUnknownActivity(aSnapshot, lUnit, lEquivalentSnapshotSymbol.FileId,
          lEquivalentSnapshotSymbol.Line, lEquivalentSnapshotSymbol.Column) then
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
          if SameText(SnapshotText(aSnapshot, lReference.ClassificationId),
            'unverified-condition') or SnapshotUnknownActivity(aSnapshot, lUnit,
            lReference.FileId, lReference.Line, lReference.Column) then
            Continue;
          lUsages.Add(MakeSnapshotReferenceUsage(aSnapshot, lUnit, lReference));
        end;

    Result := Default(TDelphiSemanticUsageResult);
    Result.Status := 'resolved';
    Result.Symbol := aSymbol;
    Result.Usages := SortedUsages(lUsages);
    Result.Unresolved := CollectSnapshotUnresolvedUsages(aSnapshot, aSymbol, lEquivalentRefs,
      lUsages, Result.HasUnverifiedConditionalOccurrences);
    Result.IndexMetrics.BuildInvocationCount := 0;
  finally
    lUsages.Free;
    lEquivalentRefs.Free;
  end;
end;

// The initial parse may omit a conditional declaration entirely. A failed lookup
// still needs a certificate retry when the queried identifier has unknown activity.
function SnapshotHasUnverifiedNameOccurrence(const aSnapshot: TDelphiProjectSnapshot;
  const aName: string): Boolean;
var
  i, lLow, lHigh, lPosition: Integer;
  lNameId: TSemanticStringId;
  lReferenceRef: TSemanticReferenceRef;
  lReference: TSemanticReferenceFact;
  lUnit: TUnitSnapshot;
  lSource, lEvidence, lUpperSource, lNeedle: string;
begin
  Result := False;
  if aName = '' then
    Exit;
  if aSnapshot.TryFindStringId(aName, lNameId) and
    aSnapshot.TryReferencesByName(lNameId, lLow, lHigh) then
    for i := lLow to lHigh do
    begin
      lReferenceRef := aSnapshot.ReferenceRefByNameIndex(i);
      if not aSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit) then
        Continue;
      lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
      if SameText(SnapshotText(aSnapshot, lReference.ClassificationId), 'unverified-condition') then
        Exit(True);
    end;
  lNeedle := UpperCase(aName);
  for i := 0 to Pred(aSnapshot.UnitCount) do
  begin
    lUnit := aSnapshot.UnitByIndex(i);
    lSource := aSnapshot.ExactTextOf(lUnit.SourceTextId);
    if not ContainsText(lSource, aName) then
      Continue;
    lEvidence := aSnapshot.ExactTextOf(lUnit.VerifiedActiveSourceTextId);
    lUpperSource := UpperCase(SanitizeCodeText(lSource));
    lPosition := Pos(lNeedle, lUpperSource);
    while lPosition > 0 do
    begin
      if IsWordAt(lUpperSource, lPosition, lNeedle) and
        TDelphiSemanticSourceConditionals.UnknownAtOffset(lSource, lEvidence, lPosition) then
        Exit(True);
      lPosition := PosEx(lNeedle, lUpperSource, lPosition + 1);
    end;
  end;
end;

function SnapshotLookupDiagnostic(const aSnapshot: TDelphiProjectSnapshot;
  const aStatus, aDiagnostic, aName: string): TDelphiSemanticUsageResult;
begin
  Result := MakeDiagnosticResult(aStatus, aDiagnostic);
  Result.HasUnverifiedConditionalOccurrences := SnapshotHasUnverifiedNameOccurrence(aSnapshot, aName);
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
    Exit(SnapshotLookupDiagnostic(lSnapshot, 'unresolved', 'No visible symbol named "' + aName +
      '" was found.', aName));

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
  TryReadSnapshotIdentifierAt(lSnapshot, aFileName, aLine, aColumn, lIdentifier);
  if not TryResolveSnapshotPosition(lSnapshot, aFileName, aLine, aColumn, '',
    lPositionResolution) then
    Exit(SnapshotLookupDiagnostic(lSnapshot, 'not-found', 'No symbol found at the requested position.',
      lIdentifier));

  lSymbol := SnapshotIndexedSymbol(lSnapshot, lPositionResolution.SymbolUnit,
    lPositionResolution.SymbolRef, lPositionResolution.Symbol);
  // A declaration or reference of a symbol always spells its name, so a different identifier
  // at the position means the resolver matched an enclosing range (a routine body), not it.
  if TryReadSnapshotIdentifierAt(lSnapshot, aFileName, aLine, aColumn, lIdentifier) and
    not SameText(lIdentifier, lSymbol.Name) then
    Exit(SnapshotLookupDiagnostic(lSnapshot, 'unknown', 'The identifier "' + lIdentifier +
      '" at the requested position was resolved to "' + lSymbol.Name +
      '"; its own symbol cannot be proven.', lIdentifier));
  Result := BuildSnapshotResultForSymbol(lSnapshot, lPositionResolution.SymbolRef, lSymbol);
  Result := GateSnapshotDeclaringUnit(lSnapshot, lPositionResolution.SymbolUnit, Result);
  // The requested position must be one of the symbol's own declarations or proven references;
  // whitespace or punctuation in a routine body only matched the routine's range.
  if (Result.Status = 'resolved') and not UsagesCoverPosition(Result.Usages, aFileName, aLine,
    aColumn) then
    Result := SnapshotLookupDiagnostic(lSnapshot, 'unknown', 'The requested position is not a declaration ' +
      'or proven reference of "' + lSymbol.Name + '".', lIdentifier);
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
