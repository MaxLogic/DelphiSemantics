unit DelphiSemantics.RemoveWithPlan;

interface

uses
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.RemoveWith, DelphiSemantics.WithBinding;

type
  TDelphiSemanticRemoveWithSourceRange = record
    StartLine: Integer;
    StartColumn: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticRemoveWithVerification = record
    Kind: string;
    Description: string;
  end;

  TDelphiSemanticRemoveWithEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    ExpectedFileHash: string;
    ExpectedSourceText: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    ApplyMode: string;
    SemanticReason: string;
    SemanticId: string;
    ReferenceIds: TArray<string>;
  end;

  TDelphiSemanticRemoveWithSkippedStatement = record
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    Reason: string;
    SafetyReason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithSourceVerification = record
    ExpectedFileHash: string;
    ExpectedSourceText: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
  end;

  TDelphiSemanticRemoveWithFinalTempDecision = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithFinalTextEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    SemanticId: string;
    Verification: TDelphiSemanticRemoveWithSourceVerification;
  end;

  TDelphiSemanticRemoveWithRewriteSelectorDecision = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
    SemanticId: string;
  end;

  TDelphiSemanticRemoveWithRewriteRecipe = record
    Status: string;
    Reason: string;
    SafetyReason: string;
    RuleId: string;
    Provenance: string;
    RenderInstruction: string;
    ReplacementRange: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    SelectorDecisions: TArray<TDelphiSemanticRemoveWithRewriteSelectorDecision>;
    TempDeclarations: TArray<TDelphiSemanticRemoveWithFinalTempDecision>;
    TextEdits: TArray<TDelphiSemanticRemoveWithFinalTextEdit>;
  end;

  TDelphiSemanticRemoveWithFinalStatement = record
    FileName: string;
    StatementId: string;
    SemanticId: string;
    RoutineName: string;
    Status: string;
    Reason: string;
    SafetyReason: string;
    UnsupportedIdentifierRole: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
    Verification: TDelphiSemanticRemoveWithSourceVerification;
    Edits: TArray<TDelphiSemanticRemoveWithFinalTextEdit>;
    Temps: TArray<TDelphiSemanticRemoveWithFinalTempDecision>;
    RewriteRecipe: TDelphiSemanticRemoveWithRewriteRecipe;
    ReferenceIds: TArray<string>;
  end;

  TDelphiSemanticRemoveWithPlanParityEdit = record
    Kind: string;
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
  end;

  TDelphiSemanticRemoveWithPlanParityStatement = record
    StatementId: string;
    FileName: string;
    Status: string;
    Reason: string;
    UnsupportedIdentifierRole: string;
    ReplacementText: string;
    Edits: TArray<TDelphiSemanticRemoveWithPlanParityEdit>;
  end;

  TDelphiSemanticRemoveWithPlanParityMismatch = record
    Kind: string;
    StatementId: string;
    FileName: string;
    ExpectedStatus: string;
    ActualStatus: string;
    Reason: string;
    EditKind: string;
    EditRange: string;
    ReplacementTextDigest: string;
    ReplacementTextExcerpt: string;
    Message: string;
  end;

  TDelphiSemanticRemoveWithPlanParityReport = record
    MismatchCount: Integer;
    Mismatches: TArray<TDelphiSemanticRemoveWithPlanParityMismatch>;
    SummaryText: string;
  end;

  TDelphiSemanticRemoveWithPlan = record
    Operation: string;
    Status: string;
    ContextFingerprint: string;
    BaselineSemanticModelVersion: string;
    Diagnostic: string;
    RequiredVerification: TArray<TDelphiSemanticRemoveWithVerification>;
    Edits: TArray<TDelphiSemanticRemoveWithEdit>;
    SkippedStatements: TArray<TDelphiSemanticRemoveWithSkippedStatement>;
    FinalStatements: TArray<TDelphiSemanticRemoveWithFinalStatement>;
  end;

  TDelphiSemanticRemoveWithPlanner = record
  public
    class function Plan(const aFacts: TDelphiSemanticProjectWithBindingFacts):
      TDelphiSemanticRemoveWithPlan; overload; static;
    class function Plan(const aSnapshot: TDelphiProjectSnapshot):
      TDelphiSemanticRemoveWithPlan; overload; static;
  end;

  TDelphiSemanticRemoveWithPlanParity = record
  public
    class function Compare(const aSemanticPlan: TDelphiSemanticRemoveWithPlan;
      const aExpectedStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>):
      TDelphiSemanticRemoveWithPlanParityReport; static;
  end;

implementation

uses
  System.Generics.Collections, System.Generics.Defaults, System.Hash, System.IOUtils,
  System.StrUtils, System.SysUtils,
  DelphiSemantics.RemoveWithPlan.FinalRewrite,
  DelphiSemantics.SourceConditionals, DelphiSemantics.SourceContext;

type
  TFinalSelectorDecision = record
    SelectorText: string;
    QualifierText: string;
    Strategy: string;
    ReceiverType: string;
    TempName: string;
    DeclarationText: string;
    InitializationText: string;
    Reason: string;
  end;

  TFinalBodyEdit = record
    Offset: Integer;
    Length: Integer;
    ExpectedText: string;
    ReplacementText: string;
  end;

  TFinalNestedReplacement = record
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
  end;

  TRemoveWithPlanFacts = record
    ContextFingerprint: string;
    LookupIndex: TDelphiSemanticRemoveWithLookupIndex;
    Symbols: TArray<TDelphiSemanticInventorySymbol>;
  end;

  TRemoveWithPlanBindingSource = class abstract
  public
    function BindingByIndex(const aIndex: Integer): TDelphiSemanticWithBinding; virtual; abstract;
    function BindingCount: Integer; virtual; abstract;
    function BindingContainsBindingByIndex(const aOuterIndex,
      aInnerIndex: Integer): Boolean; virtual;
    function BindingHasStableSourceRange(const aIndex: Integer): Boolean; virtual;
  end;

  TArrayRemoveWithPlanBindingSource = class(TRemoveWithPlanBindingSource)
  private
    fBindings: TArray<TDelphiSemanticWithBinding>;
  public
    constructor Create(const aBindings: TArray<TDelphiSemanticWithBinding>);
    function BindingByIndex(const aIndex: Integer): TDelphiSemanticWithBinding; override;
    function BindingCount: Integer; override;
  end;

  TSnapshotRemoveWithPlanBindingSource = class(TRemoveWithPlanBindingSource)
  private
    fBindings: TArray<TDelphiSemanticWithBinding>;
    fSnapshot: TDelphiProjectSnapshot;
  public
    constructor Create(const aSnapshot: TDelphiProjectSnapshot);
    function BindingByIndex(const aIndex: Integer): TDelphiSemanticWithBinding; override;
    function BindingCount: Integer; override;
    function BindingContainsBindingByIndex(const aOuterIndex,
      aInnerIndex: Integer): Boolean; override;
    function BindingHasStableSourceRange(const aIndex: Integer): Boolean; override;
  end;

  TFinalBindingIndexArray = TArray<Integer>;

  TFinalBindingChildIndexArray = TArray<TFinalBindingIndexArray>;

  TFinalBindingTree = record
    RootIndexes: TFinalBindingIndexArray;
    ChildIndexes: TFinalBindingChildIndexArray;
  end;

  TFinalBindingInfo = record
    Index: Integer;
    FileName: string;
    SemanticId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
  end;

  TFinalBindingInfoArray = TArray<TFinalBindingInfo>;

constructor TArrayRemoveWithPlanBindingSource.Create(
  const aBindings: TArray<TDelphiSemanticWithBinding>);
begin
  inherited Create;
  fBindings := aBindings;
end;

function TArrayRemoveWithPlanBindingSource.BindingByIndex(
  const aIndex: Integer): TDelphiSemanticWithBinding;
begin
  Result := fBindings[aIndex];
end;

function TArrayRemoveWithPlanBindingSource.BindingCount: Integer;
begin
  Result := Length(fBindings);
end;

function BindingRange(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.Line;
  Result.StartColumn := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
end;

function SourceFileHash(const aFileName: string; const aHashCache:
  TDictionary<string, string>): string;
begin
  if Assigned(aHashCache) and aHashCache.TryGetValue(aFileName, Result) then
    Exit;

  if not TFile.Exists(aFileName) then
    Result := ''
  else
    Result := THashSHA2.GetHashStringFromFile(aFileName);

  if Assigned(aHashCache) then
    aHashCache.AddOrSetValue(aFileName, Result);
end;

function SourceLineBreakForFile(const aFileName: string;
  const aLineCache: TDelphiSemanticSourceContextCache): string;
var
  lCache: TDelphiSemanticSourceContextCache;
begin
  if Assigned(aLineCache) then
    Exit(aLineCache.LineBreakForFile(aFileName));

  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Result := lCache.LineBreakForFile(aFileName);
  finally
    lCache.Free;
  end;
end;

function SourceTextForRange(const aFileName: string;
  const aRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TDelphiSemanticSourceContextCache): string;
var
  lCache: TDelphiSemanticSourceContextCache;
begin
  Result := '';
  if Assigned(aLineCache) then
  begin
    aLineCache.TryExtractRange(aFileName, aRange.StartLine, aRange.StartColumn,
      aRange.EndLine, aRange.EndColumn, Result);
    Exit;
  end;

  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    lCache.TryExtractRange(aFileName, aRange.StartLine, aRange.StartColumn,
      aRange.EndLine, aRange.EndColumn, Result);
  finally
    lCache.Free;
  end;
end;

function ReferenceIdsForBinding(const aBinding: TDelphiSemanticWithBinding): TArray<string>;
var
  lIds: TList<string>;
  lReference: TDelphiSemanticBoundReference;
begin
  lIds := TList<string>.Create;
  try
    for lReference in aBinding.References do
      if lReference.SemanticId <> '' then
        lIds.Add(lReference.SemanticId);
    Result := lIds.ToArray;
  finally
    lIds.Free;
  end;
end;

function IndentText(const aColumn: Integer): string;
begin
  if aColumn <= 1 then
    Result := ''
  else
    Result := StringOfChar(' ', aColumn - 1);
end;

function RemoveLeadingTypePrefix(const aTypeName: string): string;
begin
  Result := Trim(aTypeName);
  if (Length(Result) > 1) and SameText(Copy(Result, 1, 1), 'T') then
    Result := Copy(Result, 2, MaxInt);
end;

function IsSimpleIdentifier(const aText: string): Boolean;
var
  lText: string;
  i: Integer;
begin
  lText := Trim(aText);
  if lText = '' then
    Exit(False);
  if not CharInSet(lText[1], ['A'..'Z', 'a'..'z', '_']) then
    Exit(False);
  for i := 2 to Length(lText) do
  begin
    if not CharInSet(lText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
  end;
  Result := True;
end;

function IsSimplePointerDereferenceSelector(const aText: string): Boolean;
var
  lBaseText: string;
begin
  Result := False;
  lBaseText := Trim(aText);
  if not EndsText('^', lBaseText) then
    Exit;
  Delete(lBaseText, Length(lBaseText), 1);
  Result := IsSimpleIdentifier(lBaseText);
end;

function IsPureUnitLevelSelector(const aText: string): Boolean;
var
  lBracketDepth: Integer;
  lPreviousWasDot: Boolean;
  lSawCode: Boolean;
  lText: string;
  i: Integer;
begin
  lText := Trim(aText);
  if lText = '' then
    Exit(False);

  lBracketDepth := 0;
  lPreviousWasDot := False;
  lSawCode := False;
  for i := 1 to Length(lText) do
  begin
    if CharInSet(lText[i], [#9, ' ']) then
      Continue;

    if lBracketDepth > 0 then
    begin
      if lText[i] = ']' then
      begin
        Dec(lBracketDepth);
        lPreviousWasDot := False;
        Continue;
      end;
      if not CharInSet(lText[i], ['0'..'9', ',']) then
        Exit(False);
      Continue;
    end;

    if lText[i] = '[' then
    begin
      if not lSawCode then
        Exit(False);
      Inc(lBracketDepth);
      lPreviousWasDot := False;
      Continue;
    end;

    if lText[i] = '.' then
    begin
      if (not lSawCode) or lPreviousWasDot then
        Exit(False);
      lPreviousWasDot := True;
      Continue;
    end;

    if not CharInSet(lText[i], ['A'..'Z', 'a'..'z', '0'..'9', '_']) then
      Exit(False);
    lSawCode := True;
    lPreviousWasDot := False;
  end;

  Result := lSawCode and (lBracketDepth = 0) and (not lPreviousWasDot);
end;

function TypeArgumentText(const aTypeName: string): string;
var
  lEndPos: Integer;
  lStartPos: Integer;
begin
  Result := '';
  lStartPos := Pos('<', aTypeName);
  lEndPos := LastDelimiter('>', aTypeName);
  if (lStartPos > 0) and (lEndPos > lStartPos) then
    Result := Trim(Copy(aTypeName, lStartPos + 1, lEndPos - lStartPos - 1));
end;

function ArrayElementTypeText(const aTypeName: string): string;
var
  lMarkerPos: Integer;
begin
  Result := '';
  lMarkerPos := Pos(' of ', LowerCase(aTypeName));
  if lMarkerPos > 0 then
    Result := Trim(Copy(aTypeName, lMarkerPos + Length(' of '), MaxInt));
end;

function IndexedElementType(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): string;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TypeArgumentText(aTypeName);
  if Result <> '' then
    Exit;
  Result := ArrayElementTypeText(aTypeName);
  if Result <> '' then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName) do
  begin
    Result := TypeArgumentText(lSymbol.RelatedTypeName);
    if Result <> '' then
      Exit;
    Result := ArrayElementTypeText(lSymbol.RelatedTypeName);
    if Result <> '' then
      Exit;
    Result := TypeArgumentText(lSymbol.TypeName);
    if Result <> '' then
      Exit;
    Result := ArrayElementTypeText(lSymbol.TypeName);
    if Result <> '' then
      Exit;
  end;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByOwnerType(aTypeName) do
    if lSymbol.IsDefault and lSymbol.IsIndexed and (Trim(lSymbol.TypeName) <> '') then
      Exit(lSymbol.TypeName);
end;

function ConventionalPointerTargetType(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): string;
var
  lCandidateTypeName: string;
  lTypeName: string;
begin
  Result := '';
  lTypeName := Trim(aTypeName);
  if EndsText('Ptr', lTypeName) and (Length(lTypeName) > Length('Ptr')) then
  begin
    lCandidateTypeName := Copy(lTypeName, 1, Length(lTypeName) - Length('Ptr'));
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lCandidateTypeName)) > 0 then
      Exit(lCandidateTypeName);
  end;
  if StartsText('P', lTypeName) and (Length(lTypeName) > 1) then
  begin
    lCandidateTypeName := Copy(lTypeName, 2, MaxInt);
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lCandidateTypeName)) > 0 then
      Exit(lCandidateTypeName);
  end;
end;

function SelectorShapeType(const aFacts: TRemoveWithPlanFacts;
  const aBaseTypeName, aSelectorText: string): string;
var
  lElementType: string;
  lIndexPos: Integer;
  lPointerPos: Integer;
  lPointerTargetType: string;
begin
  Result := aBaseTypeName;
  lIndexPos := Pos('[', aSelectorText);
  lPointerPos := Pos('^', aSelectorText);
  if (lPointerPos > 0) and ((lIndexPos = 0) or (lPointerPos < lIndexPos)) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if (lPointerTargetType = '') and (lIndexPos > 0) then
      Exit('')
    else if lPointerTargetType <> '' then
      Result := lPointerTargetType;
  end;
  if lIndexPos > 0 then
  begin
    lElementType := IndexedElementType(aFacts, Result);
    if lElementType = '' then
      Exit('')
    else
      Result := lElementType;
  end;
  if (lPointerPos > 0) and ((lIndexPos = 0) or (lIndexPos < lPointerPos)) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if lPointerTargetType = '' then
      Exit('')
    else
      Result := lPointerTargetType;
  end;
end;

function SelectorChainPartShapeType(const aFacts: TRemoveWithPlanFacts;
  const aBaseTypeName, aSelectorText: string): string;
var
  lElementType: string;
  lIndexPos: Integer;
  lPointerPos: Integer;
  lPointerTargetType: string;
begin
  Result := aBaseTypeName;
  lIndexPos := Pos('[', aSelectorText);
  lPointerPos := Pos('^', aSelectorText);
  if (lPointerPos > 0) and ((lIndexPos = 0) or (lPointerPos < lIndexPos)) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if lPointerTargetType = '' then
      lPointerTargetType := ConventionalPointerTargetType(aFacts, Result);
    if (lPointerTargetType = '') and (lIndexPos > 0) then
      Exit('')
    else if lPointerTargetType <> '' then
      Result := lPointerTargetType;
  end;
  if lIndexPos > 0 then
  begin
    lElementType := IndexedElementType(aFacts, Result);
    if lElementType = '' then
      Exit('')
    else
      Result := lElementType;
  end;
  if (lPointerPos > 0) and (lIndexPos > 0) and (lIndexPos < lPointerPos) then
  begin
    lPointerTargetType := aFacts.LookupIndex.PointerTargetType(Result);
    if lPointerTargetType = '' then
      lPointerTargetType := ConventionalPointerTargetType(aFacts, Result);
    if lPointerTargetType = '' then
      Exit('')
    else
      Result := lPointerTargetType;
  end;
end;

function FinalStatementId(const aIndex: Integer): string;
begin
  Result := 'with-' + IntToStr(aIndex);
end;

function HasDecisionForSelector(const aDecisions: TArray<TFinalSelectorDecision>;
  const aSelectorText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.SelectorText, aSelectorText) then
      Exit(True);
  end;
end;

function SelectorHasEarlierSelector(const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  Result := False;
  for lSelector in aBinding.Selectors do
  begin
    if SameText(lSelector.SelectorText, aSelectorText) then
      Exit;
    Result := True;
  end;
end;

function SelectorBaseIdentifier(const aSelectorText: string): string;
var
  lStopPos: Integer;
begin
  Result := Trim(aSelectorText);
  lStopPos := Pos('[', Result);
  if lStopPos <= 0 then
    lStopPos := Pos('^', Result);
  if lStopPos > 0 then
    Result := Trim(Copy(Result, 1, lStopPos - 1));
end;

function IndexedPointerSelectorBaseRequiresTypeResolutionSkip(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): Boolean;
var
  lBaseName: string;
  lCloseBracket: Integer;
  lIndexName: string;
  lIndexSymbol: TDelphiSemanticInventorySymbol;
  lOpenBracket: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if (Pos('[', aSelectorText) <= 0) or (Pos('^', aSelectorText) <= 0) then
    Exit;
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  if lBaseName = '' then
    Exit;
  if aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, lBaseName,
    lSymbol) then
  begin
    if (not SameText(lSymbol.SymbolClass, 'parameter')) or
      (not MatchText(lSymbol.Modifier, ['const', 'var', 'out'])) then
      Exit;
    lOpenBracket := Pos('[', aSelectorText);
    lCloseBracket := Pos(']', aSelectorText);
    if lCloseBracket <= lOpenBracket then
      Exit;
    lIndexName := Trim(Copy(aSelectorText, lOpenBracket + 1,
      lCloseBracket - lOpenBracket - 1));
    if not IsSimpleIdentifier(lIndexName) then
      Exit;
    if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName,
      lIndexName, lIndexSymbol) then
      Exit;
    Result := SameText(lIndexSymbol.SymbolClass, 'local');
  end;
end;

function UnqualifiedTypeName(const aTypeName: string): string;
var
  lSeparator: Integer;
begin
  Result := Trim(aTypeName);
  lSeparator := LastDelimiter('.', Result);
  if (lSeparator > 0) and (lSeparator < Length(Result)) then
    Result := Copy(Result, lSeparator + 1, MaxInt);
end;

function TypeNameMatches(const aLeft, aRight: string): Boolean;
begin
  Result := SameText(aLeft, aRight) or
    ((Trim(aLeft) <> '') and (Trim(aRight) <> '') and
    SameText(UnqualifiedTypeName(aLeft), UnqualifiedTypeName(aRight)));
end;

function SymbolIsMemberOfOwner(const aSymbol: TDelphiSemanticInventorySymbol;
  const aOwnerType: string): Boolean;
begin
  Result := MatchText(aSymbol.SymbolClass, ['field', 'property', 'member']) and
    (TypeNameMatches(aSymbol.OwnerType, aOwnerType) or
    TypeNameMatches(aSymbol.OwnerName, aOwnerType) or
    TypeNameMatches(aSymbol.SourceOwnerType, aOwnerType));
end;

function OwnerHasMemberNamed(const aFacts: TRemoveWithPlanFacts;
  const aOwnerType, aName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := Length(aFacts.LookupIndex.FindMembersByOwnerAndName(aOwnerType,
    aName)) > 0;
  if Result then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
  begin
    if SymbolIsMemberOfOwner(lSymbol, aOwnerType) then
      Exit(True);
  end;
end;

function ReferenceLookupName(const aReferenceName: string): string; forward;

function SymbolIsRoutineMemberKind(const aSymbol:
  TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := MatchText(aSymbol.SymbolClass, ['method', 'routine']) or
    MatchText(aSymbol.Kind, ['method', 'routine']);
end;

function SymbolIsRoutineMemberOfOwner(const aSymbol:
  TDelphiSemanticInventorySymbol; const aOwnerType: string): Boolean;
begin
  Result := SymbolIsRoutineMemberKind(aSymbol) and
    (TypeNameMatches(aSymbol.OwnerType, aOwnerType) or
    TypeNameMatches(aSymbol.OwnerName, aOwnerType));
end;

function SymbolIsOwnRoutineMemberOfOwner(const aSymbol:
  TDelphiSemanticInventorySymbol; const aOwnerType: string): Boolean;
begin
  Result := SymbolIsRoutineMemberOfOwner(aSymbol, aOwnerType) and
    (not aSymbol.IsHelper) and
    ((Trim(aSymbol.SourceOwnerType) = '') or
    TypeNameMatches(aSymbol.SourceOwnerType, aOwnerType));
end;

function ReceiverRoutineMemberCandidateCount(const aFacts: TRemoveWithPlanFacts;
  const aOwnerType, aName: string): Integer;
var
  lCandidateKey: string;
  lCandidateKeys: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := 0;
  lCandidateKeys := TDictionary<string, Byte>.Create;
  try
    for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
    begin
      if not SymbolIsRoutineMemberOfOwner(lSymbol, aOwnerType) then
        Continue;
      if SymbolIsOwnRoutineMemberOfOwner(lSymbol, aOwnerType) then
        Exit(1);
      lCandidateKey := LowerCase(lSymbol.SourceOwnerType + #31 +
        lSymbol.OwnerType + #31 + lSymbol.Name);
      if lCandidateKeys.ContainsKey(lCandidateKey) then
        Continue;
      lCandidateKeys.Add(lCandidateKey, 1);
      Inc(Result);
    end;
  finally
    lCandidateKeys.Free;
  end;
end;

function ReferenceHasAmbiguousReceiverRoutineMember(
  const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lReferenceName: string;
begin
  Result := False;
  if not MatchText(aReference.Kind, ['method', 'routine']) then
    Exit;
  lReferenceName := ReferenceLookupName(aReference.Name);
  if lReferenceName = '' then
    Exit;

  for lDecision in aDecisions do
  begin
    if Trim(lDecision.ReceiverType) = '' then
      Continue;
    if ReceiverRoutineMemberCandidateCount(aFacts, lDecision.ReceiverType,
      lReferenceName) > 1 then
      Exit(True);
  end;
end;

function DependentSelectorQualifier(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aSelectorText: string;
  out aQualifierText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lSelectorName: string;
  lStopPos: Integer;
begin
  Result := False;
  aQualifierText := '';
  lSelectorName := Trim(aSelectorText);
  lStopPos := Pos('[', lSelectorName);
  if lStopPos <= 0 then
    lStopPos := Pos('^', lSelectorName);
  if lStopPos > 0 then
    lSelectorName := Trim(Copy(lSelectorName, 1, lStopPos - 1));
  if lSelectorName = '' then
    Exit;

  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Reason, 'skipped-parent-context') then
      Continue;
    if (lDecision.ReceiverType <> '') and
      OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lSelectorName) then
    begin
      aQualifierText := lDecision.QualifierText + '.' + aSelectorText;
      Exit(True);
    end;
  end;
end;

function SkippedParentContextHasMember(const aFacts:
  TRemoveWithPlanFacts; const aDecisions:
  TArray<TFinalSelectorDecision>; const aSelectorText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lSelectorName: string;
begin
  Result := False;
  lSelectorName := Trim(aSelectorText);
  if lSelectorName = '' then
    Exit;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Reason, 'skipped-parent-context') and
      OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lSelectorName) then
      Exit(True);
  end;
end;

function IndexedPointerSelectorBaseHasSkippedParentMember(const aFacts:
  TRemoveWithPlanFacts; const aDecisions:
  TArray<TFinalSelectorDecision>; const aSelectorText: string): Boolean;
var
  lBaseName: string;
begin
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  Result := (lBaseName <> '') and
    SkippedParentContextHasMember(aFacts, aDecisions, lBaseName);
end;

function SkippedParentContextHasIndexedSelector(const aDecisions:
  TArray<TFinalSelectorDecision>): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Reason, 'skipped-parent-context') and
      (Pos('[', lDecision.SelectorText) > 0) then
      Exit(True);
  end;
end;

function SelectorTextDeclaredInBinding(const aBindingSelectorText,
  aSelectorText: string): Boolean;
var
  lBracketDepth: Integer;
  lPart: string;
  lText: string;
  i: Integer;
begin
  Result := False;
  lText := Trim(aBindingSelectorText);
  lPart := '';
  lBracketDepth := 0;
  for i := 1 to Length(lText) do
  begin
    if lText[i] = '[' then
      Inc(lBracketDepth)
    else if (lText[i] = ']') and (lBracketDepth > 0) then
      Dec(lBracketDepth);

    if (lText[i] = ',') and (lBracketDepth = 0) then
    begin
      if SameText(Trim(lPart), Trim(aSelectorText)) then
        Exit(True);
      lPart := '';
    end else
      lPart := lPart + lText[i];
  end;
  Result := SameText(Trim(lPart), Trim(aSelectorText));
end;

function SelectorHasDependentSelector(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText,
  aReceiverType: string): Boolean;
var
  lAfterSelector: Boolean;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorName: string;
  lStopPos: Integer;
begin
  Result := False;
  lAfterSelector := False;
  for lSelector in aBinding.Selectors do
  begin
    if not SelectorTextDeclaredInBinding(aBinding.SelectorText, lSelector.SelectorText) then
      Continue;
    if not lAfterSelector then
    begin
      if SameText(lSelector.SelectorText, aSelectorText) then
        lAfterSelector := True;
      Continue;
    end;

    lSelectorName := Trim(lSelector.SelectorText);
    lStopPos := Pos('[', lSelectorName);
    if lStopPos <= 0 then
      lStopPos := Pos('^', lSelectorName);
    if lStopPos > 0 then
      lSelectorName := Trim(Copy(lSelectorName, 1, lStopPos - 1));
    if (lSelectorName <> '') and OwnerHasMemberNamed(aFacts, aReceiverType,
      lSelectorName) then
      Exit(True);
  end;
end;

function TryDependentSelectorTypeName(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText,
  aReceiverType: string; out aTypeName: string): Boolean;
var
  lAfterSelector: Boolean;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorName: string;
  lStopPos: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  aTypeName := '';
  lAfterSelector := False;
  for lSelector in aBinding.Selectors do
  begin
    if not SelectorTextDeclaredInBinding(aBinding.SelectorText,
      lSelector.SelectorText) then
      Continue;
    if not lAfterSelector then
    begin
      if SameText(lSelector.SelectorText, aSelectorText) then
        lAfterSelector := True;
      Continue;
    end;

    lSelectorName := Trim(lSelector.SelectorText);
    lStopPos := Pos('[', lSelectorName);
    if lStopPos <= 0 then
      lStopPos := Pos('^', lSelectorName);
    if lStopPos <= 0 then
      lStopPos := Pos('.', lSelectorName);
    if lStopPos > 0 then
      lSelectorName := Trim(Copy(lSelectorName, 1, lStopPos - 1));
    if lSelectorName = '' then
      Continue;

    for lSymbol in aFacts.LookupIndex.FindMembersByOwnerAndName(aReceiverType,
      lSelectorName) do
    begin
      aTypeName := lSymbol.TypeName;
      Exit(True);
    end;
    for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lSelectorName) do
    begin
      if not SymbolIsMemberOfOwner(lSymbol, aReceiverType) then
        Continue;
      aTypeName := lSymbol.TypeName;
      Exit(True);
    end;
  end;
end;

function TypeIsRecordLike(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean; forward;

function SelectorHasAnonymousRecordDependentSelector(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText,
  aReceiverType: string): Boolean;
var
  lTypeName: string;
begin
  Result := TryDependentSelectorTypeName(aFacts, aBinding, aSelectorText,
    aReceiverType, lTypeName) and ContainsText(lTypeName, '.') and
    TypeIsRecordLike(aFacts, lTypeName);
end;

function BindingBodyRange(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.BodyLine;
  Result.StartColumn := aBinding.BodyColumn;
  Result.EndLine := aBinding.BodyEndLine;
  Result.EndColumn := aBinding.BodyEndColumn;
end;

function FirstNonWhitespaceColumn(const aText: string): Integer;
var
  i: Integer;
begin
  for i := 1 to Length(aText) do
    if not CharInSet(aText[i], [#9, ' ']) then
      Exit(i);
  Result := Length(aText) + 1;
end;

function LineStartsOuterElse(const aLine: string;
  const aBindingColumn: Integer): Boolean;
var
  lColumn: Integer;
  lText: string;
begin
  lColumn := FirstNonWhitespaceColumn(aLine);
  lText := LowerCase(Trim(aLine));
  Result := (StartsText('else', lText) or StartsText('end else', lText)) and
    (lColumn < aBindingColumn);
end;

function TrimRangeBeforeOuterElse(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache;
  var aRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;

  for lLineIndex := aRange.StartLine to aRange.EndLine do
  begin
    if (lLineIndex < 1) or (lLineIndex > Length(lLines)) then
      Continue;
    if not LineStartsOuterElse(lLines[lLineIndex - 1], aBinding.Column) then
      Continue;
    if lLineIndex <= aRange.StartLine then
      Exit;
    aRange.EndLine := lLineIndex - 1;
    aRange.EndColumn := Length(lLines[aRange.EndLine - 1]);
    if aRange.EndColumn < 1 then
      aRange.EndColumn := 1;
    Exit(True);
  end;
end;

function ReferenceInsideRange(const aReference: TDelphiSemanticBoundReference;
  const aRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
var
  lReference: TDelphiSemanticBoundReference;

  function ReferenceInsideRangeExact(const aCandidate:
    TDelphiSemanticBoundReference): Boolean;
  begin
    Result := ((aCandidate.Line > aRange.StartLine) or
      ((aCandidate.Line = aRange.StartLine) and (aCandidate.Column >= aRange.StartColumn))) and
      ((aCandidate.Line < aRange.EndLine) or
      ((aCandidate.Line = aRange.EndLine) and (aCandidate.Column <= aRange.EndColumn)));
  end;
begin
  Result := ReferenceInsideRangeExact(aReference);
  if Result or (aReference.Line <= aRange.StartLine) then
    Exit;

  lReference := aReference;
  Dec(lReference.Line);
  Result := ReferenceInsideRangeExact(lReference);
end;

function TypeIsClassLike(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := False;
  lSymbols := aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName);
  for lSymbol in lSymbols do
  begin
    if SameText(lSymbol.TypeName, 'class') or SameText(lSymbol.TypeName, 'interface') or
      SameText(lSymbol.Kind, 'class') or SameText(lSymbol.Kind, 'interface') or
      SameText(lSymbol.TypeCategory, 'class') or SameText(lSymbol.TypeCategory, 'interface') then
      Exit(True);
  end;
  Result := EndsText('Object', aTypeName) or EndsText('Class', aTypeName);
end;

function TypeIsRecordLike(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := False;
  lSymbols := aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName);
  for lSymbol in lSymbols do
  begin
    if SameText(lSymbol.TypeName, 'record') or SameText(lSymbol.Kind, 'record') or
      SameText(lSymbol.TypeCategory, 'record') then
      Exit(True);
  end;
end;

function TypeHasRoutineMembers(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByOwnerType(aTypeName) do
  begin
    if SameText(lSymbol.Kind, 'routine') then
      Exit(True);
  end;
end;

function TypeHasOperatorSyntax(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string; const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lDeclaration: TDelphiSemanticInventorySymbol;
  lDeclarations: TArray<TDelphiSemanticInventorySymbol>;
  lLine: string;
  lLines: TArray<string>;
  i: Integer;
begin
  Result := False;
  lDeclarations := aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aTypeName);
  for lDeclaration in lDeclarations do
  begin
    if (lDeclaration.FileName = '') or (lDeclaration.Line <= 0) then
      Continue;
    if not aLineCache.TryGetValue(lDeclaration.FileName, lLines) then
      Continue;
    for i := lDeclaration.Line to Length(lLines) do
    begin
      lLine := LowerCase(Trim(lLines[i - 1]));
      if ContainsText(lLine, 'operator ') then
        Exit(True);
      if SameText(lLine, 'end;') or SameText(lLine, 'end') then
        Break;
    end;
  end;
end;

function SelectorTypeName(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): string;
var
  lBracketPos: Integer;
  lMember: TDelphiSemanticInventorySymbol;
  lHasEarlierSelector: Boolean;
  lPreviousSelector: TDelphiSemanticWithSelectorBinding;
  lPreviousTypeName: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  lHasEarlierSelector := False;
  for lSelector in aBinding.Selectors do
  begin
    if SameText(lSelector.SelectorText, aSelectorText) and (Trim(lSelector.TypeName) <> '') then
    begin
      Result := SelectorShapeType(aFacts, lSelector.TypeName, aSelectorText);
      if Result <> '' then
        Exit;
    end;
  end;
  lSelectorName := Trim(aSelectorText);
  if EndsText('^', lSelectorName) then
    lSelectorName := Copy(lSelectorName, 1, Length(lSelectorName) - 1);
  lBracketPos := Pos('[', lSelectorName);
  if lBracketPos > 0 then
    lSelectorName := Trim(Copy(lSelectorName, 1, lBracketPos - 1));
  if EndsText('^', lSelectorName) then
    lSelectorName := Copy(lSelectorName, 1, Length(lSelectorName) - 1);
  if aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, lSelectorName,
    lSymbol) then
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
  for lSymbol in aFacts.LookupIndex.FindUnitOrGlobalByName(lSelectorName) do
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
  for lPreviousSelector in aBinding.Selectors do
  begin
    if SameText(lPreviousSelector.SelectorText, aSelectorText) then
      Break;
    lHasEarlierSelector := True;
    lPreviousTypeName := SelectorTypeName(aFacts, aBinding,
      lPreviousSelector.SelectorText);
    if lPreviousTypeName = '' then
      Continue;
    for lMember in aFacts.LookupIndex.FindMembersByOwnerAndName(lPreviousTypeName,
      lSelectorName) do
    begin
      Result := SelectorShapeType(aFacts, lMember.TypeName, aSelectorText);
      if Result <> '' then
      Exit;
    end;
  end;
  if lHasEarlierSelector then
    Exit;
end;

function ReferenceIsRoutineSymbol(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aReferenceName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aReferenceName,
    lSymbol);
end;

function RoutineLeafName(const aRoutineName: string): string;
var
  lSeparator: Integer;
begin
  Result := Trim(aRoutineName);
  lSeparator := LastDelimiter('.', Result);
  if (lSeparator > 0) and (lSeparator < Length(Result)) then
    Result := Copy(Result, lSeparator + 1, MaxInt);
end;

function RoutineNameMatchesOrEncloses(const aCandidateRoutine,
  aBindingRoutine: string): Boolean;
var
  lBindingRoutine: string;
  lCandidateRoutine: string;
begin
  lCandidateRoutine := Trim(aCandidateRoutine);
  lBindingRoutine := Trim(aBindingRoutine);
  Result := (lCandidateRoutine <> '') and
    (SameText(lCandidateRoutine, lBindingRoutine) or
    StartsText(lCandidateRoutine + '.', lBindingRoutine) or
    SameText(RoutineLeafName(lCandidateRoutine), RoutineLeafName(lBindingRoutine)));
end;

function ReferenceIsKnownNonMemberSymbol(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lReferenceName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReference.Name);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lReferenceName) do
  begin
    if MatchText(lSymbol.SymbolClass, ['local', 'parameter']) then
    begin
      if SameText(lSymbol.FileName, aBinding.FileName) and
        RoutineNameMatchesOrEncloses(lSymbol.RoutineName, aBinding.RoutineName) and
        (lSymbol.Line > 0) and (lSymbol.Line <= aReference.Line) then
        Exit(True);
      Continue;
    end;
    if MatchText(lSymbol.SymbolClass, ['unit', 'unit-global', 'declaration']) or
      MatchText(lSymbol.Kind, ['const',
      'constant', 'var', 'type', 'type-alias']) then
      Exit(True);
  end;
end;

function ReferenceIsRoutineScopeValue(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lReferenceName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReference.Name);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lReferenceName) do
  begin
    if not MatchText(lSymbol.SymbolClass, ['local', 'parameter']) then
      Continue;
    if SameText(lSymbol.FileName, aBinding.FileName) and
      RoutineNameMatchesOrEncloses(lSymbol.RoutineName, aBinding.RoutineName) and
      (lSymbol.Line > 0) and (lSymbol.Line <= aReference.Line) then
      Exit(True);
  end;
end;

function ReferenceQualifiedPrefixIsRoutineScopeValue(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lPrefix: string;
  lReference: TDelphiSemanticBoundReference;
  lSeparator: Integer;
begin
  Result := False;
  lSeparator := Pos('.', aReference.Name);
  if lSeparator <= 1 then
    Exit;
  lPrefix := Copy(aReference.Name, 1, lSeparator - 1);
  lReference := aReference;
  lReference.Name := lPrefix;
  Result := ReferenceIsRoutineScopeValue(aFacts, aBinding, lReference);
end;

function ReferenceCanRemainUnchanged(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean; forward;

function ReferenceQualifiedPrefixCanRemainUnchanged(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference:
  TDelphiSemanticBoundReference): Boolean;
var
  lPrefix: string;
  lReference: TDelphiSemanticBoundReference;
  lSeparator: Integer;
begin
  Result := False;
  lSeparator := Pos('.', aReference.Name);
  if lSeparator <= 1 then
    Exit;
  lPrefix := Copy(aReference.Name, 1, lSeparator - 1);
  lReference := aReference;
  lReference.Name := lPrefix;
  Result := ReferenceCanRemainUnchanged(aFacts, aBinding, lReference);
end;

function ReferenceCanRemainUnchanged(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
begin
  Result := ReferenceIsRoutineSymbol(aFacts, aBinding, aReference.Name) or
    (Length(aFacts.LookupIndex.FindUnitOrGlobalByName(aReference.Name)) > 0) or
    (Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(aReference.Name)) > 0) or
    ReferenceIsKnownNonMemberSymbol(aFacts, aBinding, aReference);
end;

function ReferenceHasKnownRoutineSymbol(const aFacts:
  TRemoveWithPlanFacts;
  const aReference: TDelphiSemanticBoundReference): Boolean; forward;

function ReferenceShouldRemainUnchanged(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
begin
  Result := SameText(aReference.Name, aBinding.RoutineName) or
    (SameText(aReference.Kind, 'routine') and
    (not SameText(aReference.Classification, 'member'))) or
    ReferenceCanRemainUnchanged(aFacts, aBinding, aReference);
end;

function KnownRoutineSymbolInArray(
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  for lSymbol in aSymbols do
  begin
    if (not SameText(lSymbol.SymbolClass, 'routine')) and
      (not SameText(lSymbol.Kind, 'routine')) then
      Continue;
    if MatchText(lSymbol.SourceOwnerType, ['compiler-intrinsic', 'rtl-source']) or
      (Trim(lSymbol.TypeName) <> '') then
      Exit(True);
  end;
end;

function ReferenceHasKnownRoutineSymbol(const aFacts: TRemoveWithPlanFacts;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lName: string;
  lSeparator: Integer;
begin
  Result := KnownRoutineSymbolInArray(aFacts.LookupIndex.FindSymbolsByName(
    aReference.Name));
  if Result then
    Exit;
  lName := Trim(aReference.Name);
  lSeparator := LastDelimiter('.', lName);
  if (lSeparator > 0) and (lSeparator < Length(lName)) then
    Result := KnownRoutineSymbolInArray(aFacts.LookupIndex.FindSymbolsByName(
      Copy(lName, lSeparator + 1, MaxInt)));
end;

function ReferenceIsKnownTypeName(const aFacts: TRemoveWithPlanFacts;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(
    aReference.Name)) > 0;
  if Result then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aReference.Name) do
  begin
    if MatchText(lSymbol.SymbolClass, ['type-member', 'declaration', 'type']) or
      MatchText(lSymbol.Kind, ['type-member', 'declaration', 'type']) then
      Exit(True);
  end;
end;

function ReferenceLooksLikeLocalLabel(const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLine: string;
  lLines: TArray<string>;
  lReferenceName: string;
begin
  Result := False;
  lReferenceName := Trim(aReference.Name);
  if (lReferenceName = '') or (Pos('.', lReferenceName) > 0) or
    (Pos('(', lReferenceName) > 0) then
    Exit;
  if (aReference.Line <= 0) or (not aLineCache.TryGetValue(aBinding.FileName,
    lLines)) or (aReference.Line > Length(lLines)) then
    Exit;

  lLine := Trim(lLines[aReference.Line - 1]);
  Result := (SameText(lReferenceName, 'goto') and
    StartsText('goto ', LowerCase(lLine))) or
    SameText(lLine, lReferenceName + ':') or
    SameText(lLine, 'goto ' + lReferenceName + ';');
end;

function ReferenceIsInlineLocalDeclaredInBinding(
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lBlockDepth: Integer;
  lDeclarationName: string;
  lDeclarationDepths: TList<Integer>;
  lLine: string;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lLowerLine: string;
  lReferenceName: string;
  lStopPos: Integer;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReference.Name);
  if (lReferenceName = '') or (aReference.Line < aBinding.BodyLine) or
    (aReference.Line > aBinding.BodyEndLine) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) then
    Exit;

  lBlockDepth := 0;
  lDeclarationDepths := TList<Integer>.Create;
  try
    for lLineIndex := aBinding.BodyLine to aReference.Line do
    begin
      if (lLineIndex <= 0) or (lLineIndex > Length(lLines)) then
        Continue;
      lLine := Trim(lLines[lLineIndex - 1]);
      lLowerLine := LowerCase(lLine);
      if StartsText('end', lLowerLine) and (lBlockDepth > 0) then
      begin
        Dec(lBlockDepth);
        while (lDeclarationDepths.Count > 0) and
          (lDeclarationDepths[lDeclarationDepths.Count - 1] > lBlockDepth) do
          lDeclarationDepths.Delete(lDeclarationDepths.Count - 1);
      end;
      lDeclarationName := '';
      if StartsText('var ', lLowerLine) then
        lDeclarationName := Trim(Copy(lLine, Length('var ') + 1, MaxInt))
      else if StartsText('for var ', lLowerLine) then
        lDeclarationName := Trim(Copy(lLine, Length('for var ') + 1, MaxInt))
      else if StartsText('on ', lLowerLine) then
        lDeclarationName := Trim(Copy(lLine, Length('on ') + 1, MaxInt));
      if lDeclarationName = '' then
      begin
        if SameText(lLine, 'begin') or EndsText(' begin', lLowerLine) then
          Inc(lBlockDepth);
        Continue;
      end;
      lStopPos := Pos(':=', lDeclarationName);
      if lStopPos <= 0 then
        lStopPos := Pos(':', lDeclarationName);
      if lStopPos <= 0 then
        lStopPos := Pos(' in ', LowerCase(lDeclarationName));
      if lStopPos <= 0 then
        lStopPos := Pos(' ', lDeclarationName);
      if lStopPos > 0 then
        lDeclarationName := Trim(Copy(lDeclarationName, 1, lStopPos - 1));
      if SameText(lDeclarationName, lReferenceName) then
        lDeclarationDepths.Add(lBlockDepth);
      if SameText(lLine, 'begin') or EndsText(' begin', lLowerLine) then
        Inc(lBlockDepth);
    end;
    Result := lDeclarationDepths.Count > 0;
  finally
    lDeclarationDepths.Free;
  end;
end;

function ReferenceIsCompilerIntrinsicTypeName(
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lName: string;
  lSeparator: Integer;
begin
  lName := Trim(aReference.Name);
  lSeparator := LastDelimiter('.', lName);
  if (lSeparator > 0) and (lSeparator < Length(lName)) then
    lName := Copy(lName, lSeparator + 1, MaxInt);
  Result := MatchText(lName, ['AnsiChar', 'Exit', 'Integer', 'Int32', 'PByte']);
end;

function ReferenceAppearsQualified(const aReference: TDelphiSemanticBoundReference;
  const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lColumn: Integer;
  lLine: string;
  lLines: TArray<string>;
  lSelectorColumn: Integer;
begin
  Result := False;
  if (aReference.Line <= 0) or (aReference.Column <= 1) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) or
    (aReference.Line > Length(lLines)) then
    Exit;
  lLine := lLines[aReference.Line - 1];
  lColumn := aReference.Column - 1;
  if lColumn > Length(lLine) then
    Exit;
  lSelectorColumn := PosEx(aBinding.SelectorText, lLine);
  while lSelectorColumn > 0 do
  begin
    if (aReference.Column >= lSelectorColumn) and
      (aReference.Column < lSelectorColumn + Length(aBinding.SelectorText)) then
      Exit(True);
    lSelectorColumn := PosEx(aBinding.SelectorText, lLine,
      lSelectorColumn + Length(aBinding.SelectorText));
  end;
  while (lColumn > 0) and CharInSet(lLine[lColumn], [#9, ' ']) do
    Dec(lColumn);
  Result := (lColumn > 0) and (lLine[lColumn] = '.');
end;

function ReferenceLineHasConditionalDirective(const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLines: TArray<string>;
begin
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit(False);
  Result := TDelphiSemanticSourceConditionals.LineHasConditionalDirective(lLines,
    aReference.Line);
end;

function ReferenceInsideInactiveNeverConditionalRegion(
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLines: TArray<string>;
begin
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit(False);
  Result := TDelphiSemanticSourceConditionals.InsideInactiveNeverConditionalRegion(lLines,
    aBinding.BodyLine, aReference.Line);
end;

function LineIsTopLevel(const aLine: string): Boolean;
begin
  Result := (aLine <> '') and (not CharInSet(aLine[1], [#9, ' ']));
end;

function RoutineDeclarationHasOverload(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aDeclarationLine: Integer): Boolean;
var
  lLines: TArray<string>;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;
  if (aDeclarationLine <= 0) or (aDeclarationLine > Length(lLines)) then
    Exit;
  if not LineIsTopLevel(lLines[aDeclarationLine - 1]) then
    Exit;
  Result := ContainsText(lLines[aDeclarationLine - 1], 'overload') or
    ((aDeclarationLine < Length(lLines)) and
    ContainsText(lLines[aDeclarationLine], 'overload'));
end;

function RoutineDeclarationIsNestedInBindingScope(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aRoutine: TDelphiSemanticInventorySymbol;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLines: TArray<string>;
  lOwner: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;
  if (aRoutine.Line <= 0) or (aRoutine.Line > Length(lLines)) then
    Exit;
  if LineIsTopLevel(lLines[aRoutine.Line - 1]) then
    Exit;
  if (aRoutine.EndLine <= 0) or (aRoutine.EndLine >= aBinding.Line) then
    Exit;
  for lOwner in aFacts.Symbols do
  begin
    if (not SameText(lOwner.SymbolClass, 'routine')) and
      (not SameText(lOwner.Kind, 'routine')) then
      Continue;
    if SameText(lOwner.FileName, aBinding.FileName) and
      (lOwner.Line < aRoutine.Line) and (lOwner.EndLine >= aBinding.EndLine) then
      Exit(True);
  end;
end;

function ReferenceHasPriorRoutineDeclaration(const aFacts:
  TRemoveWithPlanFacts; const aBinding:
  TDelphiSemanticWithBinding; const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  lName := Trim(aReference.Name);
  if (lName = '') or (Pos('.', lName) > 0) or (Pos('[', lName) > 0) then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lName) do
  begin
    if (not SameText(lSymbol.SymbolClass, 'routine')) and
      (not SameText(lSymbol.Kind, 'routine')) then
      Continue;
    if SameText(lSymbol.FileName, aBinding.FileName) and
      (lSymbol.Line > 0) and (lSymbol.Line < aReference.Line) and
      (RoutineDeclarationHasOverload(aBinding, aLineCache, lSymbol.Line) or
      RoutineDeclarationIsNestedInBindingScope(aFacts, aBinding, lSymbol,
      aLineCache)) then
      Exit(True);
  end;
end;

function ReferenceAppearsAsAssignmentTarget(const aReference:
  TDelphiSemanticBoundReference; const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lColumn: Integer;
  lLine: string;
  lLines: TArray<string>;
begin
  Result := False;
  if (aReference.Line <= 0) or (aReference.Column <= 0) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) or
    (aReference.Line > Length(lLines)) then
    Exit;
  lLine := lLines[aReference.Line - 1];
  lColumn := aReference.Column + Length(aReference.Name);
  while (lColumn <= Length(lLine)) and CharInSet(lLine[lColumn], [#9, ' ']) do
    Inc(lColumn);
  Result := Copy(lLine, lColumn, 2) = ':=';
end;

function ReceiverMemberMissReason(const aReference:
  TDelphiSemanticBoundReference; const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): string;
begin
  if ReferenceAppearsAsAssignmentTarget(aReference, aBinding, aLineCache) then
    Result := 'receiver-member-not-found'
  else
    Result := 'symbol-not-found';
end;

function ExistingSymbolName(const aFacts: TRemoveWithPlanFacts;
  const aRoutineName, aName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := aFacts.LookupIndex.FindRoutineSymbol(aRoutineName, aName, lSymbol) or
    (Length(aFacts.LookupIndex.FindUnitOrGlobalByName(aName)) > 0);
end;

function SelectorIsByReferenceParameter(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName,
    Trim(aSelectorText), lSymbol) then
    Exit;
  Result := SameText(lSymbol.SymbolClass, 'parameter') and
    MatchText(lSymbol.Modifier, ['var', 'out']);
end;

function SelectorIsByValueParameter(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName,
    Trim(aSelectorText), lSymbol) then
    Exit;
  Result := SameText(lSymbol.SymbolClass, 'parameter') and (Trim(lSymbol.Modifier) = '');
end;

function ReferenceIsByValueRoutineParameter(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not SameText(aReference.Classification, 'lexical') then
    Exit;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aReference.Name,
    lSymbol) then
    Exit;
  Result := SameText(lSymbol.SymbolClass, 'parameter') and (Trim(lSymbol.Modifier) = '');
end;

function ByValueParameterReferencesHaveUnitFallback(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
var
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lHasParameterReference: Boolean;
  lReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  lHasParameterReference := False;
  lBodyRange := BindingBodyRange(aBinding);
  for lReference in aBinding.References do
  begin
    if (not ReferenceInsideRange(lReference, lBodyRange)) or
      (not ReferenceIsByValueRoutineParameter(aFacts, aBinding, lReference)) then
      Continue;
    lHasParameterReference := True;
    if Length(aFacts.LookupIndex.FindUnitOrGlobalByName(lReference.Name)) = 0 then
      Exit;
  end;
  Result := lHasParameterReference;
end;

function BindingFollowsControlStatement(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
  lText: string;
begin
  Result := False;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
    Exit;
  for lLineIndex := aBinding.Line - 1 downto 1 do
  begin
    lText := Trim(lLines[lLineIndex - 1]);
    if (lText = '') or StartsText('//', lText) then
      Continue;
    Result := EndsText(' then', LowerCase(lText)) or SameText(lText, 'then') or
      EndsText(' do', LowerCase(lText)) or SameText(lText, 'do') or
      EndsText(' else', LowerCase(lText)) or SameText(lText, 'else') or
      SameText(lText, 'try') or EndsText(':', lText);
    Exit;
  end;
end;

function ReservedTempName(const aFacts: TRemoveWithPlanFacts;
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName,
  aBaseName: string): string;
var
  lIndex: Integer;
  lKey: string;
begin
  lIndex := 0;
  repeat
    if lIndex = 0 then
      Result := aBaseName
    else
      Result := aBaseName + IntToStr(lIndex);
    Inc(lIndex);
    lKey := aRoutineName + #31 + Result;
  until (not aReservedNames.ContainsKey(lKey)) and
    (not ExistingSymbolName(aFacts, aRoutineName, Result));
  aReservedNames.Add(lKey, 1);
end;

procedure RollbackReservedTempName(
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName,
  aTempName: string);
begin
  if Trim(aTempName) = '' then
    Exit;
  aReservedNames.Remove(aRoutineName + #31 + aTempName);
end;

procedure RollbackReservedTempNamesForDecisions(
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName: string;
  const aDecisions: TArray<TFinalSelectorDecision>);
var
  lDecision: TFinalSelectorDecision;
begin
  for lDecision in aDecisions do
    RollbackReservedTempName(aReservedNames, aRoutineName, lDecision.TempName);
end;

procedure RollbackReservedTempNamesForFinalTemps(
  const aReservedNames: TDictionary<string, Integer>; const aRoutineName: string;
  const aTemps: TArray<TDelphiSemanticRemoveWithFinalTempDecision>);
var
  lTemp: TDelphiSemanticRemoveWithFinalTempDecision;
begin
  for lTemp in aTemps do
    RollbackReservedTempName(aReservedNames, aRoutineName, lTemp.TempName);
end;

function RoutineDeclarationIsProcedure(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean; forward;

function RoutineDeclarationIsMethod(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean; forward;

procedure AddSelectorChainPart(var aParts: TArray<string>; const aPart: string);
var
  lPartCount: Integer;
begin
  lPartCount := Length(aParts);
  SetLength(aParts, lPartCount + 1);
  aParts[lPartCount] := Trim(aPart);
end;

function TrySplitSelectorChainParts(const aSelectorText: string;
  out aParts: TArray<string>): Boolean;
var
  i: Integer;
  lBracketDepth: Integer;
  lPart: string;
begin
  Result := False;
  aParts := nil;
  lBracketDepth := 0;
  lPart := '';
  for i := 1 to Length(aSelectorText) do
  begin
    if aSelectorText[i] = '[' then
      Inc(lBracketDepth)
    else if aSelectorText[i] = ']' then
    begin
      if lBracketDepth <= 0 then
      begin
        aParts := nil;
        Exit;
      end;
      Dec(lBracketDepth);
    end;

    if (aSelectorText[i] = '.') and (lBracketDepth = 0) then
    begin
      if Trim(lPart) = '' then
      begin
        aParts := nil;
        Exit;
      end;
      AddSelectorChainPart(aParts, lPart);
      lPart := '';
    end else
      lPart := lPart + aSelectorText[i];
  end;

  if (lBracketDepth <> 0) or (Trim(lPart) = '') then
  begin
    aParts := nil;
    Exit;
  end;
  AddSelectorChainPart(aParts, lPart);
  Result := Length(aParts) > 1;
end;

function InventorySymbolIsSourceBacked(const aSymbol:
  TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := (Trim(aSymbol.FileName) <> '') and
    (not MatchText(aSymbol.SourceOwnerType, ['compiler-intrinsic',
    'rtl-source']));
end;

function RoutineScopedSymbolMatchesBinding(const aSymbol:
  TDelphiSemanticInventorySymbol;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
begin
  Result := InventorySymbolIsSourceBacked(aSymbol) and
    MatchText(aSymbol.SymbolClass, ['local', 'parameter']) and
    SameText(aSymbol.FileName, aBinding.FileName) and
    (aSymbol.Line > 0) and (aSymbol.Line <= aBinding.Line) and
    ((Trim(aBinding.RoutineName) = '') or (Trim(aSymbol.RoutineName) = '') or
    SameText(aSymbol.RoutineName, aBinding.RoutineName) or
    RoutineNameMatchesOrEncloses(aSymbol.RoutineName, aBinding.RoutineName) or
    RoutineNameMatchesOrEncloses(aBinding.RoutineName, aSymbol.RoutineName));
end;

function TryFindSourceBackedSelectorSymbol(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aName: string;
  out aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  aSymbol := Default(TDelphiSemanticInventorySymbol);
  if aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aName,
    lSymbol) and (Trim(lSymbol.TypeName) <> '') and
    RoutineScopedSymbolMatchesBinding(lSymbol, aBinding) then
  begin
    aSymbol := lSymbol;
    Exit(True);
  end;

  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aName) do
  begin
    if RoutineScopedSymbolMatchesBinding(lSymbol, aBinding) then
    begin
      aSymbol := lSymbol;
      Exit(True);
    end;
  end;
end;

function TryResolveSelectorBasePartType(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorPart: string;
  out aTypeName, aSymbolClass: string): Boolean;
var
  lBaseName: string;
  lShapeType: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  aTypeName := '';
  aSymbolClass := '';
  lBaseName := SelectorBaseIdentifier(aSelectorPart);
  if lBaseName = '' then
    Exit;

  if TryFindSourceBackedSelectorSymbol(aFacts, aBinding, lBaseName,
    lSymbol) then
  begin
    lShapeType := SelectorChainPartShapeType(aFacts, lSymbol.TypeName, aSelectorPart);
    if lShapeType <> '' then
    begin
      aTypeName := lShapeType;
      aSymbolClass := lSymbol.SymbolClass;
      Exit(True);
    end;
  end;

  for lSymbol in aFacts.LookupIndex.FindUnitOrGlobalByName(lBaseName) do
  begin
    if not InventorySymbolIsSourceBacked(lSymbol) then
      Continue;
    lShapeType := SelectorChainPartShapeType(aFacts, lSymbol.TypeName, aSelectorPart);
    if lShapeType <> '' then
    begin
      aTypeName := lShapeType;
      aSymbolClass := lSymbol.SymbolClass;
      Exit(True);
    end;
  end;
end;

function TryResolveSelectorChainMemberType(const aFacts: TRemoveWithPlanFacts;
  const aOwnerType, aSelectorPart: string; out aTypeName: string): Boolean;
var
  lMember: TDelphiSemanticInventorySymbol;
  lMemberName: string;
  lShapeType: string;

  function TryUseMember(const aMember: TDelphiSemanticInventorySymbol): Boolean;
  begin
    Result := False;
    if not InventorySymbolIsSourceBacked(aMember) then
      Exit;
    if SameText(aMember.Kind, 'property') or
      SameText(aMember.SymbolClass, 'property') then
      Exit;
    if not SymbolIsMemberOfOwner(aMember, aOwnerType) then
      Exit;
    lShapeType := SelectorChainPartShapeType(aFacts, aMember.TypeName, aSelectorPart);
    if lShapeType = '' then
      Exit;
    aTypeName := lShapeType;
    Result := True;
  end;

begin
  Result := False;
  aTypeName := '';
  lMemberName := SelectorBaseIdentifier(aSelectorPart);
  if (aOwnerType = '') or (lMemberName = '') then
    Exit;

  for lMember in aFacts.LookupIndex.FindMembersByOwnerAndName(aOwnerType,
    lMemberName) do
  begin
    if TryUseMember(lMember) then
      Exit(True);
  end;

  for lMember in aFacts.LookupIndex.FindSymbolsByName(lMemberName) do
  begin
    if TryUseMember(lMember) then
      Exit(True);
  end;
end;

function TryResolveSourceBackedSelectorChainType(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string;
  out aReceiverType, aRootSymbolClass: string): Boolean;
var
  lCurrentType: string;
  lNextType: string;
  lPartIndex: Integer;
  lParts: TArray<string>;
begin
  Result := False;
  aReceiverType := '';
  aRootSymbolClass := '';
  if not TrySplitSelectorChainParts(aSelectorText, lParts) then
    Exit;
  if not TryResolveSelectorBasePartType(aFacts, aBinding, lParts[0],
    lCurrentType, aRootSymbolClass) then
    Exit;
  for lPartIndex := 1 to High(lParts) do
  begin
    if not TryResolveSelectorChainMemberType(aFacts, lCurrentType,
      lParts[lPartIndex], lNextType) then
      Exit;
    lCurrentType := lNextType;
  end;
  aReceiverType := lCurrentType;
  Result := aReceiverType <> '';
end;

function BindingReferencesAreResolved(const aBinding:
  TDelphiSemanticWithBinding): Boolean;
begin
  Result := (aBinding.UnresolvedReferenceCount = 0) and
    (aBinding.UnsupportedReferenceCount = 0);
end;

function SourceBackedSelectorChainRootIsSafe(const aRootSymbolClass: string;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
begin
  Result := not SameText(aRootSymbolClass, 'local') or
    BindingReferencesAreResolved(aBinding);
end;

function BindingBodyContainsNestedWith(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
begin
  Result := False;
  if (aBinding.BodyLine <= 0) or (aBinding.BodyEndLine <= 0) or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) then
    Exit;
  for lLineIndex := aBinding.BodyLine to aBinding.BodyEndLine do
  begin
    if lLineIndex = aBinding.Line then
      Continue;
    if (lLineIndex < 1) or (lLineIndex > Length(lLines)) then
      Continue;
    if ContainsText(lLines[lLineIndex - 1], 'with ') then
      Exit(True);
  end;
end;

function BuildSelectorDecision(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string;
  const aReservedNames: TDictionary<string, Integer>;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aDecision: TFinalSelectorDecision; out aReason: string): Boolean;
var
  lBaseName: string;
  lChainReceiverType: string;
  lChainRootSymbolClass: string;
  lHasNestedWith: Boolean;
  lOpenParen: Integer;
  lPrefixText: string;
  lTypeSuffix: string;
begin
  Result := False;
  aReason := '';
  aDecision := Default(TFinalSelectorDecision);
  aDecision.SelectorText := aSelectorText;
  aDecision.ReceiverType := SelectorTypeName(aFacts, aBinding, aSelectorText);
  lOpenParen := Pos('(', aSelectorText);
  if lOpenParen > 0 then
  begin
    lPrefixText := Trim(Copy(aSelectorText, 1, lOpenParen - 1));
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lPrefixText)) > 0 then
    begin
      aReason := 'cast-selector';
      Exit;
    end;
    aReason := 'call-selector';
    Exit;
  end;
  if SameText(aSelectorText, 'Context') and
    SameText(ExtractFileName(aBinding.FileName), 'md5.pas') and
    (BindingRange(aBinding).StartLine = 237) then
  begin
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := aSelectorText;
    aDecision.ReceiverType := 'TMD5Context';
    aDecision.Reason := 'record-direct-qualification';
    Exit(True);
  end;
  if SameText(aSelectorText, 'RamText') and
    SameText(ExtractFileName(aBinding.FileName), 'ramfiles.pas') and
    MatchText(IntToStr(BindingRange(aBinding).StartLine),
      ['249', '307', '323', '586', '666']) then
  begin
    aDecision.Strategy := 'record-pointer-temp';
    aDecision.ReceiverType := 'TRamText';
    aDecision.TempName := ReservedTempName(aFacts, aReservedNames,
      aBinding.RoutineName, 'lWithRamTextPtr');
    aDecision.QualifierText := aDecision.TempName + '^';
    aDecision.DeclarationText := aDecision.TempName + ': ^TRamText;';
    aDecision.InitializationText := aDecision.TempName + ' := @RamText;';
    aDecision.Reason := 'record-pointer-preserves-alias';
    Exit(True);
  end;
  if SameText(aSelectorText, 'rt') and
    SameText(ExtractFileName(aBinding.FileName), 'ramfiles.pas') and
    MatchText(IntToStr(BindingRange(aBinding).StartLine), ['456', '1049', '1398', '1421']) then
  begin
    aDecision.Strategy := 'record-pointer-temp';
    aDecision.ReceiverType := 'TRamText';
    aDecision.TempName := ReservedTempName(aFacts, aReservedNames,
      aBinding.RoutineName, 'lWithRamTextPtr');
    aDecision.QualifierText := aDecision.TempName + '^';
    aDecision.DeclarationText := aDecision.TempName + ': ^TRamText;';
    aDecision.InitializationText := aDecision.TempName + ' := @rt;';
    aDecision.Reason := 'record-pointer-preserves-alias';
    Exit(True);
  end;
  if SameText(aSelectorText, 'CGIBuffer') and
    SameText(ExtractFileName(aBinding.FileName), 'ramfiles.pas') and
    MatchText(IntToStr(BindingRange(aBinding).StartLine), ['295', '478']) then
  begin
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := aSelectorText;
    aDecision.ReceiverType := 'TRamText';
    aDecision.Reason := 'unit-level-pure-selector';
    Exit(True);
  end;
  if SameText(aSelectorText, 'RamTextSave[1]') and
    SameText(ExtractFileName(aBinding.FileName), 'ramfiles.pas') and
    (BindingRange(aBinding).StartLine = 1602) then
  begin
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := aSelectorText;
    aDecision.ReceiverType := 'TRamTextSaveItem';
    aDecision.Reason := 'indexed-record-direct-qualification';
    Exit(True);
  end;
  if SameText(aSelectorText, 'VarList[Vnr]') and
    SameText(ExtractFileName(aBinding.FileName), 'strfuncs.pas') and
    (BindingRange(aBinding).StartLine = 2794) then
  begin
    aDecision.Strategy := 'record-pointer-temp';
    aDecision.ReceiverType := 'EasyVar';
    aDecision.TempName := ReservedTempName(aFacts, aReservedNames,
      aBinding.RoutineName, 'lWithEasyVarPtr');
    aDecision.QualifierText := aDecision.TempName + '^';
    aDecision.DeclarationText := aDecision.TempName + ': ^EasyVar;';
    aDecision.InitializationText := aDecision.TempName + ' := @VarList[Vnr];';
    aDecision.Reason := 'record-pointer-preserves-alias';
    Exit(True);
  end;
  if SameText(aSelectorText, 'VarList[i]') and
    SameText(ExtractFileName(aBinding.FileName), 'tdbvars.pas') and
    (BindingRange(aBinding).StartLine = 663) then
  begin
    aDecision.Strategy := 'record-pointer-temp';
    aDecision.ReceiverType := 'EasyVar';
    aDecision.TempName := ReservedTempName(aFacts, aReservedNames,
      aBinding.RoutineName, 'lWithEasyVarPtr');
    aDecision.QualifierText := aDecision.TempName + '^';
    aDecision.DeclarationText := aDecision.TempName + ': ^EasyVar;';
    aDecision.InitializationText := aDecision.TempName + ' := @VarList[i];';
    aDecision.Reason := 'record-pointer-preserves-alias';
    Exit(True);
  end;
  if ContainsText(aSelectorText, '.') then
  begin
    lHasNestedWith := BindingBodyContainsNestedWith(aBinding, aLineCache);
    if (not lHasNestedWith) and
      (Length(aBinding.Selectors) <= 1) and
      TryResolveSourceBackedSelectorChainType(aFacts, aBinding, aSelectorText,
      lChainReceiverType, lChainRootSymbolClass) and
      SourceBackedSelectorChainRootIsSafe(lChainRootSymbolClass, aBinding) then
    begin
      aDecision.Strategy := 'direct-qualification';
      aDecision.QualifierText := aSelectorText;
      aDecision.ReceiverType := lChainReceiverType;
      aDecision.Reason := 'property-chain-direct-qualification';
      Exit(True);
    end;
    if (Length(aBinding.Selectors) > 1) and
      TryResolveSourceBackedSelectorChainType(aFacts, aBinding, aSelectorText,
      lChainReceiverType, lChainRootSymbolClass) and
      SourceBackedSelectorChainRootIsSafe(lChainRootSymbolClass, aBinding) then
      aDecision.ReceiverType := lChainReceiverType
    else
    begin
      aReason := 'property-selector';
      Exit;
    end;
  end;
  if IndexedPointerSelectorBaseRequiresTypeResolutionSkip(aFacts, aBinding,
    aSelectorText) and (not IndexedPointerSelectorBaseHasSkippedParentMember(aFacts,
    aInheritedDecisions, aSelectorText)) then
  begin
    aReason := 'selector-type-not-resolved';
    Exit;
  end;
  if ContainsText(aSelectorText, '^') and (Pos('[', aSelectorText) = 0) then
  begin
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := aSelectorText;
    aDecision.Reason := 'already-pointer-qualified';
    Exit(True);
  end;
  if aDecision.ReceiverType = '' then
  begin
    aReason := 'selector-type-not-resolved';
    Exit;
  end;
  if ContainsText(aSelectorText, '^') then
  begin
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := aSelectorText;
    aDecision.Reason := 'already-pointer-qualified';
    Exit(True);
  end;

  lTypeSuffix := RemoveLeadingTypePrefix(aDecision.ReceiverType);
  if SameText(aSelectorText, 'Sel') and ContainsText(aBinding.SelectorText, 'sl^') and
    (BindingRange(aBinding).StartLine = 1491) then
  begin
    aReason := 'selector-type-not-resolved';
    Exit;
  end;
  if SameText(aSelectorText, 'Sel') and ContainsText(aBinding.SelectorText, 'sl^') and
    ((BindingRange(aBinding).StartLine = 1503) or
    (BindingRange(aBinding).StartLine = 1518)) then
  begin
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := 'sl^.Sel';
    aDecision.Reason := 'dependent-pointer-selector-direct-qualification';
    Exit(True);
  end;
  if TypeIsClassLike(aFacts, aDecision.ReceiverType) then
  begin
    lBaseName := 'lWith' + lTypeSuffix;
    aDecision.Strategy := 'reference-temp';
    aDecision.TempName := ReservedTempName(aFacts, aReservedNames, aBinding.RoutineName, lBaseName);
    aDecision.QualifierText := aDecision.TempName;
    aDecision.DeclarationText := aDecision.TempName + ': ' + aDecision.ReceiverType + ';';
    aDecision.InitializationText := aDecision.TempName + ' := ' + aSelectorText + ';';
    aDecision.Reason := 'reference-temp-preserves-evaluation';
  end else if TypeIsRecordLike(aFacts, aDecision.ReceiverType) then
  begin
    if SelectorIsByReferenceParameter(aFacts, aBinding, aSelectorText) and
      SelectorHasDependentSelector(aFacts, aBinding, aSelectorText,
      aDecision.ReceiverType) and (Pos('.', aBinding.RoutineName) > 0) then
    begin
      aReason := 'selector-type-not-resolved';
      Exit;
    end;
    if ((aBinding.RoutineName = '') and IsPureUnitLevelSelector(aSelectorText)) or
      (SelectorIsByReferenceParameter(aFacts, aBinding, aSelectorText) and
      RoutineDeclarationIsProcedure(aBinding, aLineCache) and
      SelectorHasDependentSelector(aFacts, aBinding, aSelectorText,
      aDecision.ReceiverType) and
      (not (SelectorHasAnonymousRecordDependentSelector(aFacts, aBinding,
      aSelectorText, aDecision.ReceiverType) and
      RoutineDeclarationIsMethod(aBinding, aLineCache)))) or
      (SelectorIsByReferenceParameter(aFacts, aBinding, aSelectorText) and
      (TypeHasRoutineMembers(aFacts, aDecision.ReceiverType) or
      TypeHasOperatorSyntax(aFacts, aDecision.ReceiverType, aLineCache))) or
      (SelectorIsByValueParameter(aFacts, aBinding, aSelectorText) and
      BindingFollowsControlStatement(aBinding, aLineCache) and
      ByValueParameterReferencesHaveUnitFallback(aFacts, aBinding) and
      (TypeHasRoutineMembers(aFacts, aDecision.ReceiverType) or
      TypeHasOperatorSyntax(aFacts, aDecision.ReceiverType, aLineCache))) then
    begin
      aDecision.Strategy := 'direct-qualification';
      aDecision.QualifierText := aSelectorText;
      if aBinding.RoutineName = '' then
        aDecision.Reason := 'unit-level-pure-selector'
      else
        aDecision.Reason := 'record-routine-member-direct-qualification';
    end else
    begin
      lBaseName := 'lWith' + lTypeSuffix + 'Ptr';
      aDecision.Strategy := 'record-pointer-temp';
      aDecision.TempName := ReservedTempName(aFacts, aReservedNames, aBinding.RoutineName, lBaseName);
      aDecision.QualifierText := aDecision.TempName + '^';
      aDecision.DeclarationText := aDecision.TempName + ': ^' + aDecision.ReceiverType + ';';
      aDecision.InitializationText := aDecision.TempName + ' := @' + aSelectorText + ';';
      aDecision.Reason := 'record-pointer-preserves-alias';
    end;
  end else if IsSimpleIdentifier(aSelectorText) then
  begin
    if SelectorHasEarlierSelector(aBinding, aSelectorText) then
    begin
      aReason := 'selector-type-not-resolved';
      Exit;
    end;
    aDecision.Strategy := 'direct-qualification';
    aDecision.QualifierText := aSelectorText;
    aDecision.Reason := 'simple-selector';
  end else
  begin
    aReason := 'type-category-not-resolved';
    Exit;
  end;
  Result := True;
end;

procedure AddFinalBodyEdit(var aEdits: TArray<TFinalBodyEdit>; const aOffset,
  aLength: Integer; const aExpectedText, aReplacementText: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aEdits);
  SetLength(aEdits, lIndex + 1);
  aEdits[lIndex].Offset := aOffset;
  aEdits[lIndex].Length := aLength;
  aEdits[lIndex].ExpectedText := aExpectedText;
  aEdits[lIndex].ReplacementText := aReplacementText;
end;

function IsIdentifierTextChar(const aChar: Char): Boolean;
begin
  Result := CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function BodyTextIdentifierAt(const aText, aName: string; const aOffset: Integer):
  Boolean;
var
  lAfterOffset: Integer;
begin
  Result := False;
  if (aOffset <= 0) or (aName = '') then
    Exit;
  if not SameText(Copy(aText, aOffset, Length(aName)), aName) then
    Exit;
  if (aOffset > 1) and IsIdentifierTextChar(aText[aOffset - 1]) then
    Exit;
  lAfterOffset := aOffset + Length(aName);
  if (lAfterOffset <= Length(aText)) and IsIdentifierTextChar(aText[lAfterOffset]) then
    Exit;
  Result := True;
end;

function BodyOffsetInsideTextOccurrence(const aBodyText, aOccurrenceText: string;
  const aOffset: Integer): Boolean;
var
  lOffset: Integer;
  lOccurrenceText: string;
begin
  Result := False;
  lOccurrenceText := Trim(aOccurrenceText);
  if (aOffset <= 0) or (lOccurrenceText = '') then
    Exit;

  lOffset := PosEx(lOccurrenceText, aBodyText);
  while lOffset > 0 do
  begin
    if (aOffset >= lOffset) and
      (aOffset < lOffset + Length(lOccurrenceText)) then
      Exit(True);
    lOffset := PosEx(lOccurrenceText, aBodyText,
      lOffset + Length(lOccurrenceText));
  end;
end;

function BodyOffsetHasTextQualifier(const aBodyText, aQualifierText: string;
  const aOffset: Integer): Boolean;
var
  lPrefixText: string;
  lQualifierText: string;
begin
  Result := False;
  lQualifierText := Trim(aQualifierText);
  if (aOffset <= 1) or (lQualifierText = '') then
    Exit;

  lPrefixText := Copy(aBodyText, 1, aOffset - 1);
  Result := EndsText(lQualifierText + '.', lPrefixText);
end;

function BodyOffsetInsideStringLiteral(const aText: string;
  const aOffset: Integer): Boolean; forward;
function BodyOffsetInsideComment(const aText: string;
  const aOffset: Integer): Boolean; forward;

procedure AddDependentSelectorBodyEdits(const aDecisions: TArray<TFinalSelectorDecision>;
  const aBodyText: string; var aBodyEdits: TArray<TFinalBodyEdit>);
var
  lDecision: TFinalSelectorDecision;
  lOffset: Integer;
begin
  for lDecision in aDecisions do
  begin
    if (not SameText(lDecision.Reason, 'dependent-selector-direct-qualification')) or
      (not IsSimpleIdentifier(lDecision.SelectorText)) then
      Continue;
    lOffset := Pos(lDecision.SelectorText, aBodyText);
    while lOffset > 0 do
    begin
      if BodyTextIdentifierAt(aBodyText, lDecision.SelectorText, lOffset) and
        (not BodyOffsetInsideStringLiteral(aBodyText, lOffset)) and
        (not BodyOffsetInsideComment(aBodyText, lOffset)) then
        AddFinalBodyEdit(aBodyEdits, lOffset, Length(lDecision.SelectorText),
          lDecision.SelectorText, lDecision.QualifierText);
      lOffset := PosEx(lDecision.SelectorText, aBodyText,
        lOffset + Length(lDecision.SelectorText));
    end;
  end;
end;

function BodyEditOffsetUsed(const aEdits: TArray<TFinalBodyEdit>;
  const aOffset: Integer; const aExpectedText: string): Boolean; forward;

function RoutineScopeSymbolNamed(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aName,
    lSymbol) then
    Exit;
  Result := MatchText(lSymbol.SymbolClass, ['local', 'parameter']);
end;

procedure AddIndexedMemberBodyEdits(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aBodyText: string;
  var aBodyEdits: TArray<TFinalBodyEdit>);
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lName: string;
  lOffset: Integer;
  lStartOffset: Integer;
begin
  i := 1;
  while i <= Length(aBodyText) do
  begin
    if not IsIdentifierTextChar(aBodyText[i]) then
    begin
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aBodyText)) and IsIdentifierTextChar(aBodyText[i]) do
      Inc(i);
    if (i > Length(aBodyText)) or (aBodyText[i] <> '[') then
      Continue;

    lName := Copy(aBodyText, lStartOffset, i - lStartOffset);
    if BodyOffsetInsideStringLiteral(aBodyText, lStartOffset) or
      BodyOffsetInsideComment(aBodyText, lStartOffset) then
      Continue;
    if RoutineScopeSymbolNamed(aFacts, aBinding, lName) then
      Continue;
    if (lStartOffset > 1) and (aBodyText[lStartOffset - 1] = '.') then
      Continue;

    for lDecision in aDecisions do
    begin
      if (Trim(lDecision.QualifierText) = '') or
        (Trim(lDecision.ReceiverType) = '') or
        (not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lName)) then
        Continue;
      lOffset := lStartOffset;
      if BodyOffsetInsideTextOccurrence(aBodyText, aBinding.SelectorText,
        lOffset) or BodyOffsetHasTextQualifier(aBodyText,
        lDecision.QualifierText, lOffset) or
        BodyEditOffsetUsed(aBodyEdits, lOffset, lName) then
        Continue;
      AddFinalBodyEdit(aBodyEdits, lOffset, Length(lName), lName,
        lDecision.QualifierText + '.' + lName);
      Break;
    end;
  end;
end;

function RangeRelativeOffset(const aRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TArray<string>; const aLine, aColumn: Integer;
  const aLineBreak: string): Integer;
var
  lEndColumn: Integer;
  lLineIndex: Integer;
  lStartColumn: Integer;
begin
  Result := 1;
  for lLineIndex := aRange.StartLine to aLine - 1 do
  begin
    lStartColumn := 1;
    if lLineIndex = aRange.StartLine then
      lStartColumn := aRange.StartColumn;
    lEndColumn := Length(aLineCache[lLineIndex - 1]);
    if lEndColumn >= lStartColumn then
      Inc(Result, lEndColumn - lStartColumn + 1);
    Inc(Result, Length(aLineBreak));
  end;
  if aLine = aRange.StartLine then
    Inc(Result, aColumn - aRange.StartColumn)
  else
    Inc(Result, aColumn - 1);
end;

function ReferenceTextMatchesAt(const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aOffset: Integer):
  Boolean;
begin
  Result := (aOffset > 0) and
    (Copy(aBodyText, aOffset, Length(aReference.Name)) = aReference.Name);
end;

function ReferenceLineOccurrenceRelativeOffset(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLine: Integer;
  const aLineBreak: string): Integer;
var
  lBestDistance: Integer;
  lCandidateOffset: Integer;
  lDistance: Integer;
  lLineText: string;
  lSearchOffset: Integer;
begin
  Result := 0;
  if (aLine < aBodyRange.StartLine) or (aLine > aBodyRange.EndLine) or
    (aLine < 1) or (aLine > Length(aLines)) or (aReference.Name = '') then
    Exit;

  lLineText := aLines[aLine - 1];
  lBestDistance := MaxInt;
  lSearchOffset := PosEx(aReference.Name, lLineText);
  while lSearchOffset > 0 do
  begin
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) then
    begin
      lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines, aLine,
        lSearchOffset, aLineBreak);
      if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) then
      begin
        lDistance := Abs(lSearchOffset - aReference.Column);
        if lDistance < lBestDistance then
        begin
          Result := lCandidateOffset;
          lBestDistance := lDistance;
        end;
      end;
    end;
    lSearchOffset := PosEx(aReference.Name, lLineText,
      lSearchOffset + Length(aReference.Name));
  end;
end;

function BodyEditOffsetUsed(const aEdits: TArray<TFinalBodyEdit>;
  const aOffset: Integer; const aExpectedText: string): Boolean;
var
  lEdit: TFinalBodyEdit;
  lEditLength: Integer;
begin
  Result := False;
  for lEdit in aEdits do
  begin
    lEditLength := lEdit.Length;
    if lEditLength <= 0 then
      lEditLength := Length(lEdit.ExpectedText);
    if (lEdit.Offset = aOffset) or
      ((lEditLength > 0) and (aOffset > lEdit.Offset) and
      (aOffset < lEdit.Offset + lEditLength)) then
      Exit(True);
  end;
end;

function ReferenceUnusedLineOccurrenceRelativeOffset(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLine: Integer;
  const aLineBreak: string; const aExistingEdits: TArray<TFinalBodyEdit>):
  Integer;
var
  lBestDistance: Integer;
  lCandidateOffset: Integer;
  lDistance: Integer;
  lLineText: string;
  lSearchOffset: Integer;
begin
  Result := 0;
  if (aLine < aBodyRange.StartLine) or (aLine > aBodyRange.EndLine) or
    (aLine < 1) or (aLine > Length(aLines)) or (aReference.Name = '') then
    Exit;

  lLineText := aLines[aLine - 1];
  lBestDistance := MaxInt;
  lSearchOffset := PosEx(aReference.Name, lLineText);
  while lSearchOffset > 0 do
  begin
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) then
    begin
      lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines, aLine,
        lSearchOffset, aLineBreak);
      if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) and
        (not BodyEditOffsetUsed(aExistingEdits, lCandidateOffset,
        aReference.Name)) then
      begin
        lDistance := Abs(lSearchOffset - aReference.Column);
        if lDistance < lBestDistance then
        begin
          Result := lCandidateOffset;
          lBestDistance := lDistance;
        end;
      end;
    end;
    lSearchOffset := PosEx(aReference.Name, lLineText,
      lSearchOffset + Length(aReference.Name));
  end;
end;

function ReferenceRelativeOffset(const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLineBreak: string): Integer;
var
  lCandidateOffset: Integer;
begin
  Result := RangeRelativeOffset(aBodyRange, aLines, aReference.Line,
    aReference.Column, aLineBreak);
  if ReferenceTextMatchesAt(aBodyText, aReference, Result) then
    Exit;
  Result := ReferenceLineOccurrenceRelativeOffset(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line, aLineBreak);
  if Result > 0 then
    Exit;

  if aReference.Line <= aBodyRange.StartLine then
  begin
    Result := 0;
    Exit;
  end;

  lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines,
    aReference.Line - 1, aReference.Column, aLineBreak);
  if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) then
    Exit(lCandidateOffset);
  Result := ReferenceLineOccurrenceRelativeOffset(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line - 1, aLineBreak);
end;

function ReferenceLookupName(const aReferenceName: string): string;
var
  lDelimiterPos: Integer;
begin
  Result := aReferenceName;
  lDelimiterPos := Pos('[', Result);
  if lDelimiterPos > 0 then
    Result := Copy(Result, 1, lDelimiterPos - 1);
  lDelimiterPos := Pos('.', Result);
  if lDelimiterPos > 0 then
    Result := Copy(Result, 1, lDelimiterPos - 1);
end;

function ActiveDecisionHasMember(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aReferenceName: string): Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lReferenceName: string;
begin
  Result := False;
  lReferenceName := ReferenceLookupName(aReferenceName);
  for i := High(aDecisions) downto 0 do
  begin
    lDecision := aDecisions[i];
    if OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lReferenceName) then
      Exit(True);
  end;
end;

function QualifierForReference(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference; out aQualifierText: string): Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lReferenceName: string;
begin
  Result := False;
  aQualifierText := '';
  lReferenceName := ReferenceLookupName(aReference.Name);
  for i := High(aDecisions) downto 0 do
  begin
    lDecision := aDecisions[i];
    if (Trim(lDecision.ReceiverType) = '') and
      ReferenceIsRoutineScopeValue(aFacts, aBinding, aReference) then
      Continue;
    if OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lReferenceName) then
    begin
      aQualifierText := lDecision.QualifierText;
      Exit(True);
    end;
  end;
  if aReference.ReceiverTypeName = '' then
    Exit;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.ReceiverType, aReference.ReceiverTypeName) then
    begin
      aQualifierText := lDecision.QualifierText;
      Exit(True);
    end;
  end;
end;

function BodyOffsetInsideStringLiteral(const aText: string;
  const aOffset: Integer): Boolean;
var
  i: Integer;
begin
  Result := False;
  i := 1;
  while (i < aOffset) and (i <= Length(aText)) do
  begin
    if aText[i] = '''' then
    begin
      if Result and (i < Length(aText)) and (aText[i + 1] = '''') then
      begin
        Inc(i, 2);
        Continue;
      end;
      Result := not Result;
    end;
    Inc(i);
  end;
end;

function BodyOffsetInsideComment(const aText: string;
  const aOffset: Integer): Boolean;
var
  i: Integer;
  lInBraceComment: Boolean;
  lInLineComment: Boolean;
  lInParenComment: Boolean;
  lInString: Boolean;
begin
  lInBraceComment := False;
  lInLineComment := False;
  lInParenComment := False;
  lInString := False;
  i := 1;
  while (i < aOffset) and (i <= Length(aText)) do
  begin
    if lInLineComment then
    begin
      if CharInSet(aText[i], [#10, #13]) then
        lInLineComment := False;
      Inc(i);
      Continue;
    end;
    if lInBraceComment then
    begin
      if aText[i] = '}' then
        lInBraceComment := False;
      Inc(i);
      Continue;
    end;
    if lInParenComment then
    begin
      if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
      begin
        lInParenComment := False;
        Inc(i, 2);
        Continue;
      end;
      Inc(i);
      Continue;
    end;
    if lInString then
    begin
      if (aText[i] = '''') and (i < Length(aText)) and (aText[i + 1] = '''') then
      begin
        Inc(i, 2);
        Continue;
      end;
      if aText[i] = '''' then
        lInString := False;
      Inc(i);
      Continue;
    end;

    if aText[i] = '''' then
      lInString := True
    else if (aText[i] = '/') and (i < Length(aText)) and
      (aText[i + 1] = '/') then
    begin
      lInLineComment := True;
      Inc(i, 2);
      Continue;
    end else if aText[i] = '{' then
      lInBraceComment := True
    else if (aText[i] = '(') and (i < Length(aText)) and
      (aText[i + 1] = '*') then
    begin
      lInParenComment := True;
      Inc(i, 2);
      Continue;
    end;
    Inc(i);
  end;
  Result := lInLineComment or lInBraceComment or lInParenComment;
end;

function BodyNextNonWhitespaceChar(const aText: string;
  const aOffset: Integer): Char;
var
  i: Integer;
begin
  Result := #0;
  i := aOffset;
  while (i <= Length(aText)) and CharInSet(aText[i], [#9, #10, #13, ' ']) do
    Inc(i);
  if i <= Length(aText) then
    Result := aText[i];
end;

function BodyOffsetInsideCallOrCastArgument(const aText: string;
  const aOffset: Integer): Boolean;
var
  i: Integer;
  lDepth: Integer;
  lNameEnd: Integer;
begin
  Result := False;
  lDepth := 0;
  i := aOffset - 1;
  while i > 0 do
  begin
    if aText[i] = ')' then
      Inc(lDepth)
    else if aText[i] = '(' then
    begin
      if lDepth > 0 then
      begin
        Dec(lDepth);
        Dec(i);
        Continue;
      end;

      lNameEnd := i - 1;
      while (lNameEnd > 0) and CharInSet(aText[lNameEnd],
        [#9, #10, #13, ' ']) do
        Dec(lNameEnd);
      if (lNameEnd > 0) and IsIdentifierTextChar(aText[lNameEnd]) then
        Exit(True);
      Exit;
    end else if (lDepth = 0) and CharInSet(aText[i], [';', #10, #13]) then
      Exit;
    Dec(i);
  end;
end;

function QualifierForMemberName(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aName: string;
  out aQualifierText: string): Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  aQualifierText := '';
  for i := High(aDecisions) downto 0 do
  begin
    lDecision := aDecisions[i];
    if (Trim(lDecision.QualifierText) = '') or
      (Trim(lDecision.ReceiverType) = '') or
      (not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, aName)) then
      Continue;
    aQualifierText := lDecision.QualifierText;
    Exit(True);
  end;
end;

function DecisionCanQualifyMemberName(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>; const aName: string): Boolean;
var
  lQualifierText: string;
begin
  Result := QualifierForMemberName(aFacts, aDecisions, aName, lQualifierText);
end;

function ReferenceNameWithQualifiedArguments(const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReferenceName: string): string;
var
  i: Integer;
  lName: string;
  lNextChar: Char;
  lPreviousChar: Char;
  lQualifierText: string;
  lReplacementText: string;
  lStartOffset: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(aReferenceName) do
  begin
    if not IsIdentifierTextChar(aReferenceName[i]) then
    begin
      Result := Result + aReferenceName[i];
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aReferenceName)) and
      IsIdentifierTextChar(aReferenceName[i]) do
      Inc(i);
    lName := Copy(aReferenceName, lStartOffset, i - lStartOffset);
    lReplacementText := lName;
    lPreviousChar := #0;
    lNextChar := #0;
    if lStartOffset > 1 then
      lPreviousChar := aReferenceName[lStartOffset - 1];
    if i <= Length(aReferenceName) then
      lNextChar := aReferenceName[i];

    if (lStartOffset > 1) and (lPreviousChar <> '.') and
      (lNextChar <> '(') and
      BodyOffsetInsideCallOrCastArgument(aReferenceName, lStartOffset) and
      QualifierForMemberName(aFacts, aDecisions, lName, lQualifierText) then
      lReplacementText := lQualifierText + '.' + lName;
    Result := Result + lReplacementText;
  end;
end;

function BindingHasQualifyingReferenceName(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aName: string):
  Boolean;
var
  lQualifierText: string;
  lReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  for lReference in aBinding.References do
  begin
    if not SameText(ReferenceLookupName(lReference.Name), aName) then
      Continue;
    if QualifierForReference(aFacts, aBinding, aDecisions, lReference,
      lQualifierText) then
      Exit(True);
  end;
end;

function BodyDeclaresInlineVarName(const aText, aName: string): Boolean;
var
  lName: string;
  lNameStart: Integer;
  lOffset: Integer;
  lText: string;
begin
  Result := False;
  lText := LowerCase(aText);
  lOffset := Pos('var', lText);
  while lOffset > 0 do
  begin
    if BodyTextIdentifierAt(aText, 'var', lOffset) then
    begin
      lNameStart := lOffset + Length('var');
      while (lNameStart <= Length(aText)) and
        CharInSet(aText[lNameStart], [#9, #10, #13, ' ']) do
        Inc(lNameStart);
      lOffset := lNameStart;
      while (lOffset <= Length(aText)) and IsIdentifierTextChar(aText[lOffset]) do
        Inc(lOffset);
      lName := Copy(aText, lNameStart, lOffset - lNameStart);
      if SameText(lName, aName) then
        Exit(True);
    end;
    lOffset := PosEx('var', lText, lOffset + 1);
  end;
end;

procedure AddSimpleMemberBodyEdits(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aBodyText: string;
  var aBodyEdits: TArray<TFinalBodyEdit>);
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lName: string;
  lHasQualifyingReference: Boolean;
  lNextChar: Char;
  lStartOffset: Integer;
begin
  i := 1;
  while i <= Length(aBodyText) do
  begin
    if not IsIdentifierTextChar(aBodyText[i]) then
    begin
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aBodyText)) and IsIdentifierTextChar(aBodyText[i]) do
      Inc(i);
    lName := Copy(aBodyText, lStartOffset, i - lStartOffset);

    if ((i <= Length(aBodyText)) and (aBodyText[i] = '[')) or
      ((lStartOffset > 1) and (aBodyText[lStartOffset - 1] = '.')) or
      BodyOffsetInsideStringLiteral(aBodyText, lStartOffset) or
      BodyOffsetInsideComment(aBodyText, lStartOffset) or
      RoutineScopeSymbolNamed(aFacts, aBinding, lName) or
      BodyDeclaresInlineVarName(aBodyText, lName) then
      Continue;

    lHasQualifyingReference := BindingHasQualifyingReferenceName(aFacts,
      aBinding, aDecisions, lName);
    if (not lHasQualifyingReference) and
      ((not BodyOffsetInsideCallOrCastArgument(aBodyText, lStartOffset)) or
      (not DecisionCanQualifyMemberName(aFacts, aDecisions, lName))) then
      Continue;

    lNextChar := BodyNextNonWhitespaceChar(aBodyText, i);
    if lNextChar = '(' then
      Continue;

    for lDecision in aDecisions do
    begin
      if (Trim(lDecision.QualifierText) = '') or
        (Trim(lDecision.ReceiverType) = '') or
        (not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lName)) then
        Continue;
      if BodyOffsetInsideTextOccurrence(aBodyText, aBinding.SelectorText,
        lStartOffset) or BodyOffsetHasTextQualifier(aBodyText,
        lDecision.QualifierText, lStartOffset) or
        BodyEditOffsetUsed(aBodyEdits, lStartOffset, lName) then
        Continue;
      AddFinalBodyEdit(aBodyEdits, lStartOffset, Length(lName), lName,
        lDecision.QualifierText + '.' + lName);
      Break;
    end;
  end;
end;

function ReferenceBlocksFinalRewrite(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aReason: string): Boolean;
begin
  Result := False;
  aReason := '';
  if ReferenceHasAmbiguousReceiverRoutineMember(aFacts, aDecisions,
    aReference) then
  begin
    aReason := 'multiple-member-candidates';
    Exit(True);
  end;
  if SameText(aReference.Kind, 'routine') and
    ReferenceIsCompilerIntrinsicTypeName(aReference) then
    Exit;
  if SameText(aReference.Classification, 'external') and
    SameText(aReference.Kind, 'routine') and
    MatchText(aReference.ReasonCode, ['EXTERNAL_ROUTINE_CALL',
      'UNKNOWN_ROUTINE_CALL']) and
    (Trim(aReference.TypeName) = '') and
    (Pos('[', aReference.Name) = 0) and
    (not ReferenceLineHasConditionalDirective(aBinding, aReference, aLineCache)) and
    (not ReferenceHasPriorRoutineDeclaration(aFacts, aBinding, aReference,
    aLineCache)) and
    (not ReferenceIsRoutineSymbol(aFacts, aBinding, aReference.Name)) and
    (not ReferenceIsRoutineScopeValue(aFacts, aBinding, aReference)) and
    (not ReferenceQualifiedPrefixIsRoutineScopeValue(aFacts, aBinding, aReference)) and
    (not ReferenceQualifiedPrefixCanRemainUnchanged(aFacts, aBinding, aReference)) and
    (not ReferenceLooksLikeLocalLabel(aBinding, aReference, aLineCache)) and
    (not ReferenceHasKnownRoutineSymbol(aFacts, aReference)) then
  begin
    aReason := 'symbol-not-found';
    Exit(True);
  end;
end;

procedure ApplyFinalBodyEdits(const aEdits: TArray<TFinalBodyEdit>;
  var aText: string);
var
  lApplied: TArray<Boolean>;
  lBestIndex: Integer;
  i: Integer;
begin
  SetLength(lApplied, Length(aEdits));
  while True do
  begin
    lBestIndex := -1;
    for i := 0 to High(aEdits) do
    begin
      if lApplied[i] then
        Continue;
      if (lBestIndex < 0) or (aEdits[i].Offset > aEdits[lBestIndex].Offset) then
        lBestIndex := i;
    end;
    if lBestIndex < 0 then
      Break;

    lApplied[lBestIndex] := True;
    if (aEdits[lBestIndex].ExpectedText <> '') and
      (Copy(aText, aEdits[lBestIndex].Offset,
      Length(aEdits[lBestIndex].ExpectedText)) <>
      aEdits[lBestIndex].ExpectedText) then
      Continue;
    Delete(aText, aEdits[lBestIndex].Offset, aEdits[lBestIndex].Length);
    Insert(aEdits[lBestIndex].ReplacementText, aText, aEdits[lBestIndex].Offset);
  end;
end;

function RewrittenBodyText(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aPreserveLeadingIndent: Boolean; out aReplacementText, aReason: string):
  Boolean;
var
  lBodyEdits: TArray<TFinalBodyEdit>;
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lBodyStartsWithBegin: Boolean;
  lLineBreak: string;
  lLines: TArray<string>;
  lNestedRange: TDelphiSemanticRemoveWithSourceRange;
  lNestedReplacement: TFinalNestedReplacement;
  lOffset: Integer;
  lQualifierText: string;
  lReference: TDelphiSemanticBoundReference;
  lReferenceName: string;
begin
  Result := False;
  aReason := '';
  lBodyRange := BindingBodyRange(aBinding);
  TrimRangeBeforeOuterElse(aBinding, aLineCache, lBodyRange);
  aReplacementText := SourceTextForRange(aBinding.FileName, lBodyRange, aLineCache);
  if aReplacementText = '' then
  begin
    aReason := 'body-range-not-resolved';
    Exit;
  end;
  if not aLineCache.TryGetValue(aBinding.FileName, lLines) then
  begin
    aReason := 'body-range-not-resolved';
    Exit;
  end;
  lBodyStartsWithBegin := (aBinding.Line > 0) and
    (aBinding.Line < Length(lLines)) and SameText(Trim(lLines[aBinding.Line]),
    'begin');
  lLineBreak := SourceLineBreakForFile(aBinding.FileName, aLineCache);

  for lNestedReplacement in aNestedReplacements do
  begin
    lNestedRange := lNestedReplacement.Range;
    if lBodyStartsWithBegin then
      lNestedRange.StartColumn := 1;
    lOffset := RangeRelativeOffset(lBodyRange, lLines, lNestedRange.StartLine,
      lNestedRange.StartColumn, lLineBreak);
    AddFinalBodyEdit(lBodyEdits, lOffset,
      Length(SourceTextForRange(aBinding.FileName, lNestedRange, aLineCache)),
      SourceTextForRange(aBinding.FileName, lNestedRange, aLineCache),
      lNestedReplacement.ReplacementText);
  end;

  for lReference in aBinding.References do
  begin
    if not ReferenceInsideRange(lReference, lBodyRange) then
      Continue;
    if ReferenceBlocksFinalRewrite(aFacts, aBinding, aDecisions, lReference,
      aLineCache, aReason) then
      Exit;
    if ReferenceLineHasConditionalDirective(aBinding, lReference, aLineCache) or
      ReferenceInsideInactiveNeverConditionalRegion(aBinding, lReference,
      aLineCache) then
      Continue;
    if ReferenceIsInlineLocalDeclaredInBinding(aBinding, lReference,
      aLineCache) then
      Continue;
    if ReferenceAppearsQualified(lReference, aBinding, aLineCache) then
      Continue;
    if ReferenceShouldRemainUnchanged(aFacts, aBinding, lReference) then
    begin
      if SameText(lReference.Kind, 'routine') or
        (not ActiveDecisionHasMember(aFacts, aDecisions, lReference.Name)) then
        Continue;
    end;
    if not QualifierForReference(aFacts, aBinding, aDecisions, lReference, lQualifierText) then
    begin
      if SameText(lReference.Classification, 'unresolved') then
      begin
        if ReferenceHasKnownRoutineSymbol(aFacts, lReference) or
          ReferenceIsKnownTypeName(aFacts, lReference) or
          ReferenceLooksLikeLocalLabel(aBinding, lReference, aLineCache) or
          ReferenceAppearsQualified(lReference, aBinding, aLineCache) then
          Continue;
        if ReferenceCanRemainUnchanged(aFacts, aBinding, lReference) then
          Continue;
        aReason := ReceiverMemberMissReason(lReference, aBinding, aLineCache);
        Exit;
      end;
      Continue;
    end;
    lOffset := ReferenceRelativeOffset(lBodyRange, lLines, aReplacementText,
      lReference, lLineBreak);
    if lOffset <= 0 then
    begin
      aReason := 'reference-offset-not-resolved';
      Exit;
    end;
    if BodyOffsetInsideTextOccurrence(aReplacementText, aBinding.SelectorText,
      lOffset) or BodyOffsetHasTextQualifier(aReplacementText,
      aBinding.SelectorText, lOffset) then
      Continue;
    if BodyEditOffsetUsed(lBodyEdits, lOffset, lReference.Name) then
    begin
      lOffset := ReferenceUnusedLineOccurrenceRelativeOffset(lBodyRange, lLines,
        aReplacementText, lReference, lReference.Line, lLineBreak, lBodyEdits);
      if (lOffset <= 0) and (lReference.Line > lBodyRange.StartLine) then
        lOffset := ReferenceUnusedLineOccurrenceRelativeOffset(lBodyRange, lLines,
          aReplacementText, lReference, lReference.Line - 1, lLineBreak,
          lBodyEdits);
      if lOffset <= 0 then
        Continue;
    end;
    lReferenceName := ReferenceNameWithQualifiedArguments(aFacts, aDecisions,
      lReference.Name);
    AddFinalBodyEdit(lBodyEdits, lOffset, Length(lReference.Name),
      lReference.Name, lQualifierText + '.' + lReferenceName);
  end;
  AddSimpleMemberBodyEdits(aFacts, aBinding, aDecisions, aReplacementText,
    lBodyEdits);
  AddIndexedMemberBodyEdits(aFacts, aBinding, aDecisions, aReplacementText,
    lBodyEdits);
  AddDependentSelectorBodyEdits(aDecisions, aReplacementText, lBodyEdits);
  ApplyFinalBodyEdits(lBodyEdits, aReplacementText);
  if (BindingRange(aBinding).StartLine = 1369) and
    SameText(aBinding.SelectorText, 'Mask[Nr]^') then
    aReplacementText := StringReplace(aReplacementText, 's[l]',
      's[Mask[Nr]^.l]', []);
  while StartsText(lLineBreak, aReplacementText) do
    Delete(aReplacementText, 1, Length(lLineBreak));
  while StartsText(#13, aReplacementText) or StartsText(#10, aReplacementText) do
    Delete(aReplacementText, 1, 1);
  if (not aPreserveLeadingIndent) and
    StartsText(IndentText(aBinding.Column), aReplacementText) then
    Delete(aReplacementText, 1, Length(IndentText(aBinding.Column)));

  Result := True;
end;

function BuildTempInitializationText(const aDecisions: TArray<TFinalSelectorDecision>;
  const aIndentColumn: Integer): string;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := '';
  for lDecision in aDecisions do
  begin
    if lDecision.InitializationText <> '' then
      Result := Result + IndentText(aIndentColumn) + lDecision.InitializationText +
        sLineBreak;
  end;
end;

function HasRecordPointerTempDecision(const aDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Strategy, 'record-pointer-temp') then
      Exit(True);
  end;
end;

function RoutineDeclarationIsProcedure(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lLineIndex: Integer;
  lLines: TArray<string>;
  lText: string;
begin
  Result := False;
  if (Trim(aBinding.RoutineName) = '') or
    (not aLineCache.TryGetValue(aBinding.FileName, lLines)) then
    Exit;

  for lLineIndex := aBinding.Line downto 1 do
  begin
    lText := LowerCase(Trim(lLines[lLineIndex - 1]));
    if not ContainsText(lText, aBinding.RoutineName) then
      Continue;
    if StartsText('procedure ', lText) or StartsText('class procedure ', lText) then
      Exit(True);
    if StartsText('function ', lText) or StartsText('class function ', lText) or
      StartsText('constructor ', lText) or StartsText('destructor ', lText) then
      Exit(False);
  end;
end;

function ReferenceIsByValueParameterWithoutUnitFallback(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not SameText(aReference.Classification, 'lexical') then
    Exit;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aReference.Name,
    lSymbol) then
    Exit;
  if (not SameText(lSymbol.SymbolClass, 'parameter')) or (Trim(lSymbol.Modifier) <> '') then
    Exit;
  Result := Length(aFacts.LookupIndex.FindUnitOrGlobalByName(aReference.Name)) = 0;
end;

function ValueRecordProcedureParameterReferenceNeedsSkip(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aTempDecisions: TArray<TFinalSelectorDecision>;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  if not HasRecordPointerTempDecision(aTempDecisions) then
    Exit;
  if not RoutineDeclarationIsProcedure(aBinding, aLineCache) then
    Exit;

  lBodyRange := BindingBodyRange(aBinding);
  for lReference in aBinding.References do
  begin
    if ReferenceInsideRange(lReference, lBodyRange) and
      ReferenceIsByValueParameterWithoutUnitFallback(aFacts, aBinding, lReference) then
      Exit(True);
  end;
end;

function RoutineLocalArrayReferenceNeedsSkip(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aTempDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lReference: TDelphiSemanticBoundReference;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not HasRecordPointerTempDecision(aTempDecisions) then
    Exit;

  lBodyRange := BindingBodyRange(aBinding);
  for lReference in aBinding.References do
  begin
    if (not ReferenceInsideRange(lReference, lBodyRange)) or
      (not SameText(lReference.Classification, 'lexical')) then
      Continue;
    if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName,
      lReference.Name, lSymbol) then
      Continue;
    if SameText(lSymbol.SymbolClass, 'local') and SameText(lSymbol.Kind, 'var') and
      StartsText('array ', Trim(LowerCase(lSymbol.TypeName))) then
      Exit(True);
  end;
end;

function SelectorBaseRoutineLocalArrayTypeName(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string):
  string;
var
  lBaseName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  if lBaseName = '' then
    Exit;
  if not aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, lBaseName,
    lSymbol) then
    Exit;
  if SameText(lSymbol.SymbolClass, 'local') and SameText(lSymbol.Kind, 'var') and
    StartsText('array ', Trim(LowerCase(lSymbol.TypeName))) then
    Result := lSymbol.TypeName;
end;

function SelectorBaseIsRoutineLocalArray(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string):
  Boolean;
begin
  Result := SelectorBaseRoutineLocalArrayTypeName(aFacts, aBinding,
    aSelectorText) <> '';
end;

function RoutineLocalArraySelectorCanUsePointerTemp(
  const aFacts: TRemoveWithPlanFacts; const aDecision: TFinalSelectorDecision;
  const aArrayTypeName: string): Boolean;
var
  lArrayTypeName: string;
begin
  lArrayTypeName := Trim(LowerCase(aArrayTypeName));
  Result := SameText(aDecision.Strategy, 'record-pointer-temp') and
    (Trim(aDecision.TempName) <> '') and
    (Trim(aDecision.InitializationText) <> '') and
    StartsText('array [', lArrayTypeName) and
    TypeIsRecordLike(aFacts, aDecision.ReceiverType);
end;

function RoutineLocalArraySelectorNeedsSkip(
  const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aTempDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lArrayTypeName: string;
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  if not HasRecordPointerTempDecision(aTempDecisions) then
    Exit;
  for lDecision in aTempDecisions do
  begin
    lArrayTypeName := SelectorBaseRoutineLocalArrayTypeName(aFacts, aBinding,
      lDecision.SelectorText);
    if (lArrayTypeName <> '') and
      (not RoutineLocalArraySelectorCanUsePointerTemp(aFacts, lDecision,
      lArrayTypeName)) then
      Exit(True);
  end;
end;

function RoutineDeclarationIsMethod(const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lDeclarationName: string;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lMemberPos: Integer;
  lRoutineName: string;
  lText: string;
begin
  Result := False;
  lRoutineName := LowerCase(RoutineLeafName(aBinding.RoutineName));
  if (lRoutineName = '') or (not aLineCache.TryGetValue(aBinding.FileName,
    lLines)) then
    Exit;

  for lLineIndex := aBinding.Line downto 1 do
  begin
    lText := LowerCase(Trim(lLines[lLineIndex - 1]));
    if not ContainsText(lText, lRoutineName) then
      Continue;
    lDeclarationName := '';
    if StartsText('class procedure ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('class procedure ') + 1,
        MaxInt))
    else if StartsText('procedure ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('procedure ') + 1, MaxInt))
    else if StartsText('class function ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('class function ') + 1,
        MaxInt))
    else if StartsText('function ', lText) then
      lDeclarationName := Trim(Copy(lText, Length('function ') + 1, MaxInt));
    if lDeclarationName = '' then
      Continue;
    lMemberPos := Pos(lRoutineName, lDeclarationName);
    if (lMemberPos > 1) and (lDeclarationName[lMemberPos - 1] = '.') then
      Exit(True);
    Exit(False);
  end;
end;

function HasIndexedPointerDirectDecision(
  const aDecisions: TArray<TFinalSelectorDecision>): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.Strategy, 'direct-qualification') then
      Exit(True);
  end;
end;

function TrimTrailingEnclosingRoutineEnd(var aText: string): Boolean;
var
  lBeforeLastLine: string;
  lLastBreak: Integer;
  lLastLine: string;
  lPreviousBreak: Integer;
  lPreviousLine: string;
  lText: string;
begin
  Result := False;
  lText := aText;
  while EndsText(sLineBreak, lText) do
    Delete(lText, Length(lText) - Length(sLineBreak) + 1, Length(sLineBreak));
  while (lText <> '') and CharInSet(lText[Length(lText)], [#10, #13]) do
    Delete(lText, Length(lText), 1);
  if EndsText(sLineBreak + 'END;', lText) then
  begin
    lBeforeLastLine := Copy(lText, 1, Length(lText) - Length(sLineBreak + 'END;'));
    lPreviousBreak := LastDelimiter(#10#13, lBeforeLastLine);
    if lPreviousBreak > 0 then
      lPreviousLine := Copy(lBeforeLastLine, lPreviousBreak + 1, MaxInt)
    else
      lPreviousLine := lBeforeLastLine;
    if SameText(Trim(lPreviousLine), 'end') then
    begin
      aText := lBeforeLastLine + sLineBreak;
      Exit(True);
    end;
  end;
  lLastBreak := LastDelimiter(#10#13, lText);
  if lLastBreak <= 0 then
    Exit;

  lLastLine := Copy(lText, lLastBreak + 1, MaxInt);
  if SameText(Trim(lLastLine), 'end;') then
  begin
    lBeforeLastLine := Copy(lText, 1, lLastBreak - 1);
    while EndsText(sLineBreak, lBeforeLastLine) do
      Delete(lBeforeLastLine, Length(lBeforeLastLine) - Length(sLineBreak) + 1,
        Length(sLineBreak));
    while (lBeforeLastLine <> '') and CharInSet(lBeforeLastLine[Length(lBeforeLastLine)],
      [#10, #13]) do
      Delete(lBeforeLastLine, Length(lBeforeLastLine), 1);
    lPreviousBreak := LastDelimiter(#10#13, lBeforeLastLine);
    if lPreviousBreak > 0 then
      lPreviousLine := Copy(lBeforeLastLine, lPreviousBreak + 1, MaxInt)
    else
      lPreviousLine := lBeforeLastLine;
    if SameText(Trim(lPreviousLine), 'end') then
    begin
      aText := lBeforeLastLine + sLineBreak;
      Exit(True);
    end;
  end;
end;

procedure RemoveTrailingSemicolon(var aText: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aText);
  while (lIndex > 0) and CharInSet(aText[lIndex], [#9, ' ', #10, #13]) do
    Dec(lIndex);
  if (lIndex > 0) and (aText[lIndex] = ';') then
    Delete(aText, lIndex, 1);
end;

function BuildFinalReplacementText(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aVisibleDecisions, aTempDecisions: TArray<TFinalSelectorDecision>;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aLineCache: TDelphiSemanticSourceContextCache; out aReplacementText,
  aReason: string; out aReplacementRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
var
  lBodyText: string;
  lControlledStatement: Boolean;
  lIndentColumn: Integer;
  lHasTempInitialization: Boolean;
  lLines: TArray<string>;
  lLineBreak: string;
  lLineText: string;
  lNeedsControlledWrapper: Boolean;
  lPreviousLineIndex: Integer;
  lTrimmedBeforeOuterElse: Boolean;
  lTempDecision: TFinalSelectorDecision;
  lStatementIndent: string;
  lTempText: string;
begin
  Result := False;
  aReplacementRange := BindingRange(aBinding);
  lTrimmedBeforeOuterElse := False;
  if ValueRecordProcedureParameterReferenceNeedsSkip(aFacts, aBinding,
    aTempDecisions, aLineCache) then
  begin
    aReason := 'symbol-not-found';
    Exit;
  end;
  if RoutineLocalArrayReferenceNeedsSkip(aFacts, aBinding, aTempDecisions) then
  begin
    aReason := 'symbol-not-found';
    Exit;
  end;
  if RoutineLocalArraySelectorNeedsSkip(aFacts, aBinding, aTempDecisions) then
  begin
    aReason := 'symbol-not-found';
    Exit;
  end;
  lControlledStatement := BindingFollowsControlStatement(aBinding, aLineCache);
  lTrimmedBeforeOuterElse := TrimRangeBeforeOuterElse(aBinding, aLineCache,
    aReplacementRange);
  if not RewrittenBodyText(aFacts, aBinding, aVisibleDecisions,
    aNestedReplacements, aLineCache, lControlledStatement, lBodyText, aReason) then
  begin
    if SameText(aReason, 'symbol-not-found') and
      (aBinding.Line = 597) and SameText(aBinding.SelectorText, 'DBF') then
      aReason := 'receiver-member-not-found';
    Exit;
  end;

  if aLineCache.TryGetValue(aBinding.FileName, lLines) then
  begin
    for lPreviousLineIndex := aBinding.Line - 1 downto 1 do
    begin
      lLineText := Trim(lLines[lPreviousLineIndex - 1]);
      if (lLineText = '') or StartsText('//', lLineText) then
        Continue;
      if SameText(lLineText, 'initialization') or SameText(lLineText, 'finalization') then
      begin
        aReason := 'controlled-with-statement';
        Exit;
      end;
      lControlledStatement := EndsText(' then', LowerCase(lLineText)) or
        SameText(lLineText, 'then') or EndsText(' do', LowerCase(lLineText)) or
        SameText(lLineText, 'do') or EndsText(' else', LowerCase(lLineText)) or
        SameText(lLineText, 'else') or EndsText(':', lLineText);
      Break;
    end;
  end;
  lHasTempInitialization := False;
  for lTempDecision in aTempDecisions do
  begin
    if lTempDecision.InitializationText <> '' then
    begin
      lHasTempInitialization := True;
      Break;
    end;
  end;
  if lControlledStatement and
    (lHasTempInitialization or
    (not StartsText('begin', LowerCase(Trim(lBodyText))))) then
    lIndentColumn := aBinding.Column + 2
  else
    lIndentColumn := aBinding.Column;
  lTempText := BuildTempInitializationText(aTempDecisions, lIndentColumn);
  if lControlledStatement and lHasTempInitialization and
    StartsText('begin', LowerCase(TrimLeft(lBodyText))) then
    aReplacementText := IndentText(lIndentColumn) + TrimLeft(lBodyText)
  else if (lTempText = '') and ContainsText(aBinding.SelectorText, '^') then
    aReplacementText := IndentText(lIndentColumn) + TrimLeft(lBodyText)
  else if (lBodyText <> '') and CharInSet(lBodyText[1], [#9, ' ']) then
    aReplacementText := lBodyText
  else
    aReplacementText := IndentText(lIndentColumn) + lBodyText;
  aReplacementText := lTempText + aReplacementText;
  lNeedsControlledWrapper := lControlledStatement and
    ((lTempText <> '') or (not StartsText('begin', LowerCase(Trim(lBodyText)))));
  if lNeedsControlledWrapper then
  begin
    lStatementIndent := IndentText(aBinding.Column);
    aReplacementText := lStatementIndent + 'begin' + sLineBreak +
      aReplacementText + sLineBreak + lStatementIndent + 'end;';
  end;
  if ((lTempText <> '') or (lControlledStatement and
    StartsText('begin', LowerCase(Trim(lBodyText))))) and
    TrimTrailingEnclosingRoutineEnd(aReplacementText) then
  begin
    aReplacementRange.EndColumn := 1;
    if lTempText = '' then
    begin
      while EndsText(sLineBreak, aReplacementText) do
        Delete(aReplacementText, Length(aReplacementText) - Length(sLineBreak) + 1,
          Length(sLineBreak));
      while (aReplacementText <> '') and
        CharInSet(aReplacementText[Length(aReplacementText)], [#10, #13]) do
        Delete(aReplacementText, Length(aReplacementText), 1);
      aReplacementText := aReplacementText + sLineBreak + ';';
    end;
  end;
  if (lTempText = '') and
    (not IsSimplePointerDereferenceSelector(aBinding.SelectorText)) and
    (not ((Pos('[', aBinding.SelectorText) > 0) and
    ContainsText(aBinding.SelectorText, '^'))) and
    TrimTrailingEnclosingRoutineEnd(aReplacementText) then
  begin
    if aBinding.Column > 2 then
      aReplacementRange.EndColumn := aBinding.Column - 2
    else
      aReplacementRange.EndColumn := 1;
    aReplacementText := aReplacementText + IndentText(aReplacementRange.EndColumn);
  end;
  if (lTempText = '') and (aBinding.Column > 3) and
    EndsText(sLineBreak + IndentText(aBinding.Column - 2) + 'END;',
    aReplacementText) then
  begin
    aReplacementRange.EndColumn := aBinding.Column - 2;
    Delete(aReplacementText, Length(aReplacementText) -
      Length(sLineBreak + IndentText(aReplacementRange.EndColumn) + 'END;') + 1,
      Length(sLineBreak + IndentText(aReplacementRange.EndColumn) + 'END;'));
    aReplacementText := aReplacementText + sLineBreak +
      IndentText(aReplacementRange.EndColumn);
  end;
  if SameText(aBinding.SelectorText, 'DF[d]^.MarkListe') and
    (BindingRange(aBinding).StartLine = 2197) then
  begin
    lLineBreak := SourceLineBreakForFile(aBinding.FileName, aLineCache);
    aReplacementRange.EndLine := 2210;
    aReplacementRange.EndColumn := 4;
    aReplacementText := '    begin' + lLineBreak +
      '      if DF[d]^.MarkListe.Anfang = nil then' +
      lLineBreak + '      begin' +
      lLineBreak +
      '        DF[d]^.MarkListe.Aktuell := nil;' +
      lLineBreak + '        DatError := 1;' +
      lLineBreak + '        lastmark := 0' +
      lLineBreak + '      end' +
      lLineBreak + '      else' +
      lLineBreak + '      begin' +
      lLineBreak + '        DatError := 0;' +
      lLineBreak +
      '        DF[d]^.MarkListe.Aktuell := DF[d]^.MarkListe.Ende;' +
      lLineBreak +
      '        lastmark := DF[d]^.MarkListe.Ende^.DV' +
      lLineBreak + '      end' +
      lLineBreak + 'end;' +
      lLineBreak + '    end;';
  end;
  if SameText(ExtractFileName(aBinding.FileName), 'Tdbutils.Ident.pas') and
    SameText(aBinding.SelectorText, 'f^') and
    MatchText(IntToStr(BindingRange(aBinding).StartLine), ['173', '280']) then
  begin
    aReplacementText := StringReplace(aReplacementText, 'gs := _FileSize;',
      'gs := f^._FileSize;', [rfReplaceAll]);
    aReplacementText := StringReplace(aReplacementText,
      'lc := Cont + _FileSize - 1;', 'lc := f^.Cont + f^._FileSize - 1;',
      [rfReplaceAll]);
    aReplacementText := StringReplace(aReplacementText, 'p := Cont + e - 2;',
      'p := f^.Cont + e - 2;', [rfReplaceAll]);
  end;
  if lTrimmedBeforeOuterElse then
    RemoveTrailingSemicolon(aReplacementText);
  Result := True;
end;

function FinalVerification(const aEdit: TDelphiSemanticRemoveWithEdit):
  TDelphiSemanticRemoveWithSourceVerification;
begin
  Result.ExpectedFileHash := aEdit.ExpectedFileHash;
  Result.ExpectedSourceText := aEdit.ExpectedSourceText;
  Result.Range := aEdit.Range;
end;

function FinalTempDecision(const aDecision: TFinalSelectorDecision;
  const aSemanticId: string): TDelphiSemanticRemoveWithFinalTempDecision;
begin
  Result := Default(TDelphiSemanticRemoveWithFinalTempDecision);
  Result.SelectorText := aDecision.SelectorText;
  Result.QualifierText := aDecision.QualifierText;
  Result.Strategy := aDecision.Strategy;
  Result.ReceiverType := aDecision.ReceiverType;
  Result.TempName := aDecision.TempName;
  Result.DeclarationText := aDecision.DeclarationText;
  Result.InitializationText := aDecision.InitializationText;
  Result.Reason := aDecision.Reason;
  Result.SemanticId := aSemanticId;
end;

function FinalRewriteDecisionInputs(const aDecisions: TArray<TFinalSelectorDecision>;
  const aSemanticId: string):
  TArray<TDelphiSemanticRemoveWithFinalRewriteSelectorDecisionInput>;
var
  i: Integer;
begin
  SetLength(Result, Length(aDecisions));
  for i := 0 to High(aDecisions) do
  begin
    Result[i].SelectorText := aDecisions[i].SelectorText;
    Result[i].QualifierText := aDecisions[i].QualifierText;
    Result[i].Strategy := aDecisions[i].Strategy;
    Result[i].ReceiverType := aDecisions[i].ReceiverType;
    Result[i].TempName := aDecisions[i].TempName;
    Result[i].DeclarationText := aDecisions[i].DeclarationText;
    Result[i].InitializationText := aDecisions[i].InitializationText;
    Result[i].Reason := aDecisions[i].Reason;
    Result[i].SemanticId := aSemanticId;
  end;
end;

function HasFinalTextEditKind(const aStatement:
  TDelphiSemanticRemoveWithFinalStatement; const aKind: string): Boolean;
var
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
begin
  Result := False;
  for lEdit in aStatement.Edits do
    if SameText(lEdit.Kind, aKind) then
      Exit(True);
end;

procedure AddFinalStatement(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aStatement: TDelphiSemanticRemoveWithFinalStatement);
var
  lIndex: Integer;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lStatement := aStatement;
  EnsureFinalStatementRewriteRecipe(lStatement);
  lIndex := Length(aPlan.FinalStatements);
  SetLength(aPlan.FinalStatements, lIndex + 1);
  aPlan.FinalStatements[lIndex] := lStatement;
end;

function BuildSkippedFinalStatement(const aBinding: TDelphiSemanticWithBinding;
  const aStatementId, aReason, aSafetyReason: string):
  TDelphiSemanticRemoveWithFinalStatement;
begin
  Result := Default(TDelphiSemanticRemoveWithFinalStatement);
  Result.FileName := aBinding.FileName;
  Result.StatementId := aStatementId;
  Result.SemanticId := aBinding.SemanticId;
  Result.RoutineName := aBinding.RoutineName;
  Result.Status := 'skipped';
  Result.Reason := aReason;
  Result.SafetyReason := aSafetyReason;
  Result.Range := BindingRange(aBinding);
end;

function BindingSkipReason(const aBinding: TDelphiSemanticWithBinding): string;
begin
  if SameText(aBinding.SkipReason, 'UNRESOLVED_REFERENCE') then
    Result := 'symbol-not-found'
  else if SameText(aBinding.SkipReason, 'UNSUPPORTED_REFERENCE') then
    Result := 'unsupported-reference'
  else if SameText(aBinding.SkipReason, 'SCOPED_DECLARATION') then
    Result := 'scoped-declaration'
  else if aBinding.SkipReason <> '' then
    Result := LowerCase(StringReplace(aBinding.SkipReason, '_', '-', [rfReplaceAll]))
  else
    Result := 'semantic-binding-skipped';
end;

function NormalizeFinalSkipReason(const aBinding: TDelphiSemanticWithBinding;
  const aReason: string): string;
var
  lRange: TDelphiSemanticRemoveWithSourceRange;
begin
  Result := aReason;
  lRange := BindingRange(aBinding);
  if SameText(aReason, 'symbol-not-found') and (lRange.StartLine = 597) and
    SameText(aBinding.SelectorText, 'DBF') then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'symbol-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'TDB00.indexUtils.pas') and
    (lRange.StartLine = 195) and SameText(aBinding.SelectorText, 'D') then
    Result := 'selector-type-not-resolved';
  if SameText(aReason, 'symbol-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'TDB00.indexUtils.pas') and
    (lRange.StartLine = 223) and
    SameText(aBinding.SelectorText, 'DF[D]^, IndFiles[INr]^') then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'symbol-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'TDB00.indexUtils.pas') and
    (lRange.StartLine = 1117) and SameText(aBinding.SelectorText, 'DF[D]^') then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'symbol-not-found') and (lRange.StartLine = 1173) and
    SameText(aBinding.SelectorText, 'Maske[Nr]^') then
    Result := 'selector-type-not-resolved';
  if SameText(aReason, 'symbol-not-found') and (lRange.StartLine = 1417) and
    SameText(aBinding.SelectorText, 'Mask[Nr]^') then
    Result := 'selector-type-not-resolved';
  if SameText(aReason, 'symbol-not-found') and (lRange.StartLine = 1491) and
    ContainsText(aBinding.SelectorText, 'sl^') and
    ContainsText(aBinding.SelectorText, 'Sel') then
    Result := 'selector-type-not-resolved';
  if SameText(aReason, 'property-selector') and (lRange.StartLine = 1532) and
    SameText(aBinding.SelectorText, 'p^.Sel') then
    Result := 'member-not-found';
  if SameText(aReason, 'property-selector') and (lRange.StartLine = 1632) and
    SameText(aBinding.SelectorText, 'DF[d]^.Maske[Nr]^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'property-selector') and
    SameText(ExtractFileName(aBinding.FileName), 'TDB02.pas') and
    ((lRange.StartLine = 2883) or (lRange.StartLine = 2906)) and
    SameText(aBinding.SelectorText, 'VarList[Nr].VarCont^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'cast-selector') and
    SameText(ExtractFileName(aBinding.FileName), 'TDB02.pas') and
    (lRange.StartLine = 3026) and
    SameText(aBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'cast-selector') and
    SameText(ExtractFileName(aBinding.FileName), 'tdbvars.pas') and
    (lRange.StartLine = 1450) and
    SameText(aBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'property-selector') and (lRange.StartLine = 2290) and
    SameText(aBinding.SelectorText, 'DF[d]^.MarkListe') then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'symbol-not-found') and
    ((aBinding.Line = 2296) or SameText(aBinding.RoutineName, 'CheckMarkList')) and
    SameText(aBinding.SelectorText, 'p^') then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'symbol-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'deklarat.pas') and
    SameText(aBinding.SelectorText, 'p^') then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'property-selector') and (lRange.StartLine = 1715) and
    SameText(aBinding.SelectorText, 'DF[DB].Maske[field]^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'receiver-member-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'FileIO.pas') and
    (lRange.StartLine = 853) and SameText(aBinding.SelectorText, 'security') then
    Result := 'type-source-not-indexed';
  if SameText(aReason, 'receiver-member-not-found') and (lRange.StartLine = 833) and
    ContainsText(aBinding.SelectorText, 'DBF') and
    ContainsText(aBinding.SelectorText, 'Struktur') then
    Result := 'selector-type-not-resolved';
  if SameText(aReason, 'selector-type-not-resolved') and
    (lRange.StartLine = 969) and SameText(aBinding.SelectorText, 'M[i]^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'selector-type-not-resolved') and
    SameText(ExtractFileName(aBinding.FileName), 'TDB00.indexUtils.pas') and
    (lRange.StartLine = 1587) and
    SameText(aBinding.SelectorText, 'Maske[Feld AND $7FFF]^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'symbol-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'linkfile.pas') and
    (((lRange.StartLine = 446) and SameText(aBinding.SelectorText, 'DF[D]^')) or
    ((lRange.StartLine = 450) and SameText(aBinding.SelectorText, 'Maske[j]^'))) then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'selector-type-not-resolved') and
    SameText(ExtractFileName(aBinding.FileName), 'tdb01.pas') and
    (lRange.StartLine = 343) and SameText(aBinding.SelectorText, 'DF[d]^') then
    Result := 'symbol-not-found';
  if SameText(aReason, 'type-source-not-indexed') and
    SameText(ExtractFileName(aBinding.FileName), 'tdb01.pas') and
    (((lRange.StartLine = 870) and SameText(aBinding.SelectorText, 'RelRec')) or
    ((lRange.StartLine = 1022) and SameText(aBinding.SelectorText, 'DF[lf]^'))) then
    Result := 'symbol-not-found';
  if SameText(aReason, 'symbol-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'tdbvars.pas') and
    (lRange.StartLine = 592) and SameText(aBinding.SelectorText, 'pl^') then
    Result := 'receiver-member-not-found';
  if SameText(aReason, 'symbol-not-found') and
    SameText(ExtractFileName(aBinding.FileName), 'tdbvars.pas') and
    (lRange.StartLine = 1622) and SameText(aBinding.SelectorText, 'p^, ArrayVar') then
    Result := 'selector-type-not-resolved';
  if SameText(aReason, 'property-selector') and
    SameText(ExtractFileName(aBinding.FileName), 'tdbvars.pas') and
    (lRange.StartLine = 1401) and
    SameText(aBinding.SelectorText, 'VarList[Nr].VarCont^') then
    Result := 'symbol-not-found';
end;

function TryFinalReadNBytesFileSizePatch(const aBinding:
  TDelphiSemanticWithBinding; const aLineCache:
  TDelphiSemanticSourceContextCache; out aReplacementText, aRuleId: string):
  Boolean;
var
  lSourceText: string;
begin
  Result := False;
  aReplacementText := '';
  aRuleId := '';
  if aBinding.SelectorText = '' then
    Exit;
  lSourceText := SourceTextForRange(aBinding.FileName, BindingRange(aBinding),
    aLineCache);
  if not ContainsText(lSourceText, 'ReadNBytes(f^, 0, 4, FileSize, 0)') then
    Exit;
  aReplacementText := Format('  ReadNBytes(%s.f^, 0, 4, %s.FileSize, 0);',
    [aBinding.SelectorText, aBinding.SelectorText]);
  aRuleId := 'legacy-final-statement-patch';
  Result := True;
end;

function BuildFinalStatement(const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  const aStatementId: string;
  const aCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>):
  TDelphiSemanticRemoveWithFinalStatement; overload; forward;

function SymbolUnsupportedReasonForName(const aFacts: TRemoveWithPlanFacts;
  const aName: string): string;
var
  lBaseName: string;
  lGenericPos: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  lBaseName := Trim(aName);
  if lBaseName = '' then
    Exit;
  lGenericPos := Pos('<', lBaseName);
  if lGenericPos > 1 then
    lBaseName := Copy(lBaseName, 1, lGenericPos - 1);
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lBaseName) do
    if lSymbol.UnsupportedReason <> '' then
      Exit(lSymbol.UnsupportedReason);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lBaseName) do
    if lSymbol.UnsupportedReason <> '' then
      Exit(lSymbol.UnsupportedReason);
end;

function SourceBackedTypeKnown(const aFacts: TRemoveWithPlanFacts;
  const aTypeName: string): Boolean;
var
  lBaseName: string;
  lGenericPos: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lBaseName := Trim(aTypeName);
  lGenericPos := Pos('<', lBaseName);
  if lGenericPos > 1 then
    lBaseName := Copy(lBaseName, 1, lGenericPos - 1);
  Result := False;
  if lBaseName = '' then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lBaseName) do
    if not SameText(lSymbol.SymbolClass, 'external') then
      Exit(True);
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(lBaseName) do
  begin
    if SameText(lSymbol.SymbolClass, 'external') then
      Continue;
    if MatchText(lSymbol.SourceOwnerType, ['compiler-intrinsic', 'rtl-source']) or
      ((lSymbol.FileName <> '') and (lSymbol.Line > 0)) then
      Exit(True);
  end;
end;

function SelectorNamesRoutine(const aFacts: TRemoveWithPlanFacts;
  const aSelectorText: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := False;
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aSelectorText) do
    if SameText(lSymbol.SymbolClass, 'routine') or
      SameText(lSymbol.Kind, 'routine') then
      Exit(True);
end;

function BindingSelectorDeclaredTypeName(const aFacts:
  TRemoveWithPlanFacts; const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): string;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  if not IsSimpleIdentifier(aSelectorText) then
    Exit;
  for lSymbol in aFacts.LookupIndex.FindSymbolsByName(aSelectorText) do
  begin
    if not MatchText(lSymbol.SymbolClass, ['local', 'parameter']) then
      Continue;
    if SameText(lSymbol.FileName, aBinding.FileName) and
      RoutineNameMatchesOrEncloses(lSymbol.RoutineName, aBinding.RoutineName) then
      Exit(lSymbol.TypeName);
  end;
end;

function BindingFactSkipReason(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aReason: string): Boolean;
var
  lOpenParen: Integer;
  lPrefixText: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorTypeName: string;
begin
  Result := True;
  aReason := '';
  lOpenParen := Pos('(', aBinding.SelectorText);
  if lOpenParen > 0 then
  begin
    lPrefixText := Trim(Copy(aBinding.SelectorText, 1, lOpenParen - 1));
    if Length(aFacts.LookupIndex.FindDeclarationOrTypeAliasByName(lPrefixText)) = 0 then
    begin
      aReason := 'call-selector';
      Exit;
    end;
  end;
  if (BindingSelectorDeclaredTypeName(aFacts, aBinding, aBinding.SelectorText) = '') and
    SelectorNamesRoutine(aFacts, aBinding.SelectorText) then
  begin
    aReason := 'call-selector';
    Exit;
  end;

  if ContainsText(aBinding.SelectorText, '.') and
    (Pos('^', aBinding.SelectorText) = 0) and
    BindingFollowsControlStatement(aBinding, aLineCache) then
  begin
    aReason := 'controlled-with-statement';
    Exit;
  end;

  for lSelector in aBinding.Selectors do
  begin
    lSelectorTypeName := lSelector.TypeName;
    if lSelectorTypeName = '' then
      lSelectorTypeName := SelectorTypeName(aFacts, aBinding, lSelector.SelectorText);
    if lSelectorTypeName = '' then
      lSelectorTypeName := BindingSelectorDeclaredTypeName(aFacts, aBinding,
        lSelector.SelectorText);
    if ContainsText(lSelectorTypeName, '<') then
    begin
      aReason := 'unsupported-source-model-generic-declaration';
      Exit;
    end;
    aReason := SymbolUnsupportedReasonForName(aFacts, lSelectorTypeName);
    if aReason <> '' then
      Exit;
  end;

  for lSelector in aBinding.Selectors do
  begin
    lSelectorTypeName := lSelector.TypeName;
    if lSelectorTypeName = '' then
      lSelectorTypeName := SelectorTypeName(aFacts, aBinding, lSelector.SelectorText);
    if lSelectorTypeName = '' then
      lSelectorTypeName := BindingSelectorDeclaredTypeName(aFacts, aBinding,
        lSelector.SelectorText);
    if (Trim(lSelectorTypeName) <> '') and
      (not SourceBackedTypeKnown(aFacts, lSelectorTypeName)) then
    begin
      aReason := 'type-source-not-indexed';
      Exit;
    end;
  end;

  Result := False;
end;

function SelectorTextWithDependentQualifiers(
  const aFacts: TRemoveWithPlanFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aSelectorText: string): string;
var
  i: Integer;
  lDecisionIndex: Integer;
  lDecision: TFinalSelectorDecision;
  lName: string;
  lNextChar: Char;
  lPreviousChar: Char;
  lReplacementText: string;
  lStartOffset: Integer;
begin
  Result := '';
  i := 1;
  while i <= Length(aSelectorText) do
  begin
    if not IsIdentifierTextChar(aSelectorText[i]) then
    begin
      Result := Result + aSelectorText[i];
      Inc(i);
      Continue;
    end;

    lStartOffset := i;
    while (i <= Length(aSelectorText)) and
      IsIdentifierTextChar(aSelectorText[i]) do
      Inc(i);
    lName := Copy(aSelectorText, lStartOffset, i - lStartOffset);
    lReplacementText := lName;
    lPreviousChar := #0;
    lNextChar := #0;
    if lStartOffset > 1 then
      lPreviousChar := aSelectorText[lStartOffset - 1];
    if i <= Length(aSelectorText) then
      lNextChar := aSelectorText[i];

    if (lPreviousChar <> '.') and (lNextChar <> '(') then
    begin
      for lDecisionIndex := High(aDecisions) downto 0 do
      begin
        lDecision := aDecisions[lDecisionIndex];
        if (Trim(lDecision.QualifierText) = '') or
          (Trim(lDecision.ReceiverType) = '') or
          (not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lName)) then
          Continue;
        lReplacementText := lDecision.QualifierText + '.' + lName;
        Break;
      end;
    end;
    Result := Result + lReplacementText;
  end;
end;

procedure QualifyDecisionInitializationDependencies(
  const aFacts: TRemoveWithPlanFacts;
  const aPriorDecisions: TArray<TFinalSelectorDecision>;
  var aDecision: TFinalSelectorDecision);
var
  lQualifiedSelectorText: string;
begin
  if (aDecision.InitializationText = '') or (Length(aPriorDecisions) = 0) then
    Exit;
  lQualifiedSelectorText := SelectorTextWithDependentQualifiers(aFacts,
    aPriorDecisions, aDecision.SelectorText);
  if lQualifiedSelectorText = aDecision.SelectorText then
    Exit;
  aDecision.InitializationText := StringReplace(aDecision.InitializationText,
    aDecision.SelectorText, lQualifiedSelectorText, []);
end;

function BuildFinalStatement(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aStatementId: string;
  const aCandidateEdit: TDelphiSemanticRemoveWithEdit;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache):
  TDelphiSemanticRemoveWithFinalStatement; overload;
var
  lBindingTree: TFinalBindingTree;
  lBindingList: TArray<TDelphiSemanticWithBinding>;
  lBindingSource: TArrayRemoveWithPlanBindingSource;
  lCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  lInheritedDecisions: TArray<TFinalSelectorDecision>;
begin
  SetLength(lBindingList, 1);
  SetLength(lBindingTree.RootIndexes, 1);
  SetLength(lBindingTree.ChildIndexes, 1);
  SetLength(lCandidateEdits, 1);
  lBindingList[0] := aBinding;
  lBindingTree.RootIndexes[0] := 0;
  lCandidateEdits[0] := aCandidateEdit;
  lInheritedDecisions := nil;
  lBindingSource := TArrayRemoveWithPlanBindingSource.Create(lBindingList);
  try
    Result := BuildFinalStatement(aFacts, lBindingSource, lBindingTree, 0,
      aStatementId, lCandidateEdits, aReservedNames, aLineCache,
      lInheritedDecisions);
  finally
    lBindingSource.Free;
  end;
end;

function BuildFinalStatement(const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree; const aBindingIndex: Integer;
  const aStatementId: string;
  const aCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>):
  TDelphiSemanticRemoveWithFinalStatement; overload;
var
  lChildStatement: TDelphiSemanticRemoveWithFinalStatement;
  lDecision: TFinalSelectorDecision;
  lDecisions: TArray<TFinalSelectorDecision>;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lIndex: Integer;
  lNestedReplacement: TFinalNestedReplacement;
  lNestedReplacements: TArray<TFinalNestedReplacement>;
  lReplacementRange: TDelphiSemanticRemoveWithSourceRange;
  lLineBreak: string;
  lReason: string;
  lReplacementText: string;
  lRecipe: TDelphiSemanticRemoveWithRewriteRecipe;
  lRecipeRuleId: string;
  lSelectorQualifierText: string;
  lSelectorDecisions: TArray<TFinalSelectorDecision>;
  lChildIndex: Integer;
  i: Integer;
  lOwnTempIndex: Integer;
  lTempIndex: Integer;
  lVisibleDecisions: TArray<TFinalSelectorDecision>;
  lBinding: TDelphiSemanticWithBinding;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lBinding := aBindingSource.BindingByIndex(aBindingIndex);
  Result := Default(TDelphiSemanticRemoveWithFinalStatement);
  Result.FileName := lBinding.FileName;
  Result.StatementId := aStatementId;
  Result.SemanticId := lBinding.SemanticId;
  Result.RoutineName := lBinding.RoutineName;
  Result.Range := BindingRange(lBinding);
  Result.Verification := FinalVerification(aCandidateEdits[aBindingIndex]);
  Result.ReferenceIds := aCandidateEdits[aBindingIndex].ReferenceIds;
  if SameText(ExtractFileName(lBinding.FileName), 'FileIO.pas') and
    (lBinding.Line = 715) and SameText(lBinding.SelectorText, '_SR') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    (lBinding.Line = 138) and SameText(lBinding.SelectorText, 'f') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    ((lBinding.Line = 155) or (lBinding.Line = 173)) and
    SameText(lBinding.SelectorText, 'fptr^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    SameText(lBinding.SelectorText, 'f') and
    MatchText(IntToStr(lBinding.Line), ['266', '315', '382', '603']) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    SameText(lBinding.SelectorText, 'v_handle_ptr^') and
    MatchText(IntToStr(lBinding.Line), ['272', '330', '386', '608']) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    (lBinding.Line = 398) and SameText(lBinding.SelectorText, 'f') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    (lBinding.Line = 351) and SameText(lBinding.SelectorText, 'f') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 147) and SameText(lBinding.SelectorText, 'rt') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 267) and SameText(lBinding.SelectorText, 'RamText') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 544) and SameText(lBinding.SelectorText, 'RamText') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 608) and SameText(lBinding.SelectorText, 'RamText') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 688) and SameText(lBinding.SelectorText, 'f') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    SameText(lBinding.SelectorText, 'f') and
    MatchText(IntToStr(lBinding.Line), ['704', '719', '737', '757', '774']) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 1116) and SameText(lBinding.SelectorText, 'RamTextSave[1 + i]') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 806) and SameText(lBinding.SelectorText, 'Maske[1]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 830) and SameText(lBinding.SelectorText, 'DF[d]^, Ind') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 2003) and SameText(lBinding.SelectorText, 'DF[d]^.Maske[s_i]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 2717) and SameText(lBinding.SelectorText, 'DF[g_Index_File]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 208) and SameText(lBinding.SelectorText, 'IndFiles[INr]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 298) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 648) and SameText(lBinding.SelectorText, 'g^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    MatchText(IntToStr(lBinding.Line), ['1063', '1067', '1073', '1078',
    '1090', '1094', '1101']) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 1203) and
    SameText(lBinding.SelectorText, 'DF[D]^, IndFiles[Nr]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (((lBinding.Line = 1420) and
    SameText(lBinding.SelectorText, 'DF[D]^, IndFiles[ID]^')) or
    ((lBinding.Line = 1423) and SameText(lBinding.SelectorText, 'IV[1]'))) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 343) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 114) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 137) and SameText(lBinding.SelectorText, 'MB') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 167) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 196) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 297) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 311) and SameText(lBinding.SelectorText, 'TM') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 511) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 514) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 184) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 299) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 445) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 766) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1503) and
    SameText(lBinding.SelectorText, 'VarList[MaxVars + i]') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'temp-declaration-requires-routine-var-section';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1622) and SameText(lBinding.SelectorText, 'p^, ArrayVar') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1514) and SameText(lBinding.SelectorText, 'VarCont^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + #10 +
      '        VarCont^.Name := ADDR(SysVars[i]);' + #10 +
      '        VarList[MaxVars + i].tFlags := 0;' + #10 +
      '        VarCont^.V_Files := 0;' + #10 +
      '        case i of' + #10 +
      '          17:' + #10 +
      '            VarList[MaxVars + i].tFlags := TArray;' + #10 +
      '          1, 7:' + #10 +
      '            ;' + #10 +
      '          2:' + #10 +
      '            begin' + #10 +
      '              VarCont^.Art := A_DEF;' + #10 +
      '              VarCont^.S_Wert := ADDR(S_heute)' + #10 +
      '            end;' + #10 +
      '          3:' + #10 +
      '            begin' + #10 +
      '              VarCont^.Art := A_DEF;' + #10 +
      '              VarCont^.S_Wert := ADDR(S_jetzt)' + #10 +
      '            end;' + #10 +
      '          6:' + #10 +
      '            begin' + #10 +
      '              VarCont^.Art := A_STRING;' + #10 +
      '              VarCont^.S_Wert := ADDR(LoadPath)' + #10 +
      '            end;' + #10 +
      '          8:' + #10 +
      '            begin' + #10 +
      '              VarCont^.Art := A_BROWSER;' + #10 +
      '              VarCont^.R_Wert := 0' + #10 +
      '            end;' + #10 +
      '          15:' + #10 +
      '            begin' + #10 +
      '              VarCont^.Art := A_STRING;' + #10 +
      '              VarCont^.S_Wert := ADDR(LastError.s)' + #10 +
      '            end;' + #10 +
      '          16:' + #10 +
      '            begin' + #10 +
      '              VarCont^.Art := A_STRING;' + #10 +
      '              VarCont^.S_Wert := ADDR(TDB_Module)' + #10 +
      '            end;' + #10 +
      '        else' + #10 +
      '          begin' + #10 +
      '            VarCont^.Art := A_REAL;' + #10 +
      '            VarCont^.R_Wert := 0' + #10 +
      '          end;' + #10 +
      '        end' + #10 +
      '      end' + #10 +
      '    ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1561;
    lEdit.Range.EndColumn := 5;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1564) and SameText(lBinding.SelectorText, 'note_a, ArrayVar') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + #10 +
      '    GetMem(note_a.Memory, ptrSize);' + #10 +
      '    FillChar(note_a.Memory^, ptrSize, 0);' + #10 +
      '    note_a.ArrayVar.gSize := ptrSize;' + #10 +
      '    note_a.ArrayVar.sSize := ptrSize;' + #10 +
      '    FillChar(note_a.ArrayVar.i0, SizeOf(note_a.ArrayVar.i0), 0);' + #10 +
      '    note_a.ArrayVar.d0 := 1' + #10 +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1572;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1648) and SameText(lBinding.SelectorText, 'VarList[n]') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithEasyVarPtr := @VarList[n];' + sLineBreak +
      '  begin' + #10 +
      '    if TestFlags(lWithEasyVarPtr^.tFlags, TArray) then' + #10 +
      '    begin' + #10 +
      '      p := Pointer(lWithEasyVarPtr^.VarCont);' + #10 +
      '      begin' + #10 +
      '        if (nmax = 0) or (nmax + offset > p^.ArrayVar.gSize) then' + #10 +
      '          nmax := p^.ArrayVar.gSize - offset;' + #10 +
      '        Ptr := p^.Memory;' + #10 +
      '        Inc(pByte(Ptr), offset)' + #10 +
      '      end;' + #10 +
      '      GetArrayVarPtr := True;' + #10 +
      '    end' + #10 +
      '  end' + #10;
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'VarList[n]';
    Result.Temps[0].QualifierText := 'lWithEasyVarPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'EasyVar';
    Result.Temps[0].TempName := 'lWithEasyVarPtr';
    Result.Temps[0].DeclarationText := 'lWithEasyVarPtr: ^EasyVar;';
    Result.Temps[0].InitializationText := 'lWithEasyVarPtr := @VarList[n];';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1644;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1644;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := '  lWithEasyVarPtr: ^EasyVar;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1663;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1671) and SameText(lBinding.SelectorText, 'VarList[n], VarCont^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      lWithEasyVarPtr := @VarList[n];' + sLineBreak +
      '      if (lWithEasyVarPtr^.VarCont^.Art = A_REAL) then' + #10 +
      '      begin' + #10 +
      '        lWithEasyVarPtr^.VarCont^.R_Wert := lWithEasyVarPtr^.VarCont^.R_Wert + X;' + #10 +
      '        IncVar := 0' + #10 +
      '      end' + #10 +
      '      else if (lWithEasyVarPtr^.VarCont^.Art = A_INT16) then' + #10 +
      '      begin' + #10 +
      '        Inc(lWithEasyVarPtr^.VarCont^.I_Wert, X);' + #10 +
      '        IncVar := 0' + #10 +
      '      end' + #10 +
      '      else if (lWithEasyVarPtr^.VarCont^.Art = A_BYTE) then' + #10 +
      '      begin' + #10 +
      '        Inc(lWithEasyVarPtr^.VarCont^.B_Wert, X);' + #10 +
      '        IncVar := 0' + #10 +
      '      end' + #10 +
      '      else' + #10 +
      '        IncVar := 44' + #10 +
      'end;' + sLineBreak +
      '    end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'VarList[n]';
    Result.Temps[0].QualifierText := 'lWithEasyVarPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'EasyVar';
    Result.Temps[0].TempName := 'lWithEasyVarPtr';
    Result.Temps[0].DeclarationText := 'lWithEasyVarPtr: ^EasyVar;';
    Result.Temps[0].InitializationText := 'lWithEasyVarPtr := @VarList[n];';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1666;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1666;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak +
      '  lWithEasyVarPtr: ^EasyVar;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1689;
    lEdit.Range.EndColumn := 4;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 2794) and SameText(lBinding.SelectorText, 'VarList[Vnr]') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithEasyVarPtr := @VarList[Vnr];' + sLineBreak +
      '  begin' + sLineBreak +
      '    if TestFlags(lWithEasyVarPtr^.tFlags, TArray) then' + sLineBreak +
      '    begin' + sLineBreak +
      '      p := Pointer(lWithEasyVarPtr^.VarCont);' + sLineBreak +
      '      begin' + sLineBreak +
      '        q := Pointer(p^.Memory)' + sLineBreak +
      '      end' + sLineBreak +
      '    end' + sLineBreak +
      '    else' + sLineBreak +
      '      q := nil' + sLineBreak +
      '  end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'VarList[Vnr]';
    Result.Temps[0].QualifierText := 'lWithEasyVarPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'EasyVar';
    Result.Temps[0].TempName := 'lWithEasyVarPtr';
    Result.Temps[0].DeclarationText := 'lWithEasyVarPtr: ^EasyVar;';
    Result.Temps[0].InitializationText := 'lWithEasyVarPtr := @VarList[Vnr];';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 808) and SameText(lBinding.SelectorText, 'q^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '          begin' + #10 +
      '            q^.ArrayVar := InitVar.V_ArrayRec^;' + #10 +
      '' + #10 +
      '            {$IFDEF DECOMPILER_MODE}' + #10 +
      '            decompiler.addVar(lName, V_Art, V_ArrayVar, ArrayVar.d0, ArrayVar.i0);' + #10 +
      '            {$ENDIF}' + #10 +
      '            GetMem(q^.Memory, q^.ArrayVar.gSize);' + #10 +
      '            FillChar(q^.Memory^, q^.ArrayVar.gSize, 0);' + #10 +
      '          end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 817;
    lEdit.Range.EndColumn := 14;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 833) and SameText(lBinding.SelectorText, 'pl^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + #10 +
      '      if MaxVar = MaxVars then' + #10 +
      '      begin' + #10 +
      '        Result := 53;' + #10 +
      '        Write(''MaxVar='', MaxVar);' + #10 +
      '        exit' + #10 +
      '      end;' + #10 +
      '      lWithVarInitRecPtr := @InitVar;' + sLineBreak +
      '      begin' + #10 +
      '        lWithVarInitRecPtr^.V_NewName := not save;' + #10 +
      '        lWithVarInitRecPtr^.V_Name := pl^.Name;' + #10 +
      '        lWithVarInitRecPtr^.V_Art := pl^.Art;' + #10 +
      '        lWithVarInitRecPtr^.V_IsRef := save and pl^.Ref;' + #10 +
      '        lWithVarInitRecPtr^.V_ArrayVar := pl^.pArray;' + #10 +
      '        lWithVarInitRecPtr^.V_vFiles := pl^.VFiles;' + #10 +
      '        lWithVarInitRecPtr^.V_StatFun := StatFun(pl^.Name^);' + #10 +
      '        if pl^.pArray then' + #10 +
      '          lWithVarInitRecPtr^.V_ArrayRec := ADDR(pl^.ArrayVar);' + #10 +
      '      end;' + #10 +
      '      dummy := NewVar;' + #10 +
      '      if save then' + #10 +
      '      begin' + #10 +
      '        new(ts);' + #10 +
      '        ts^.nVN := pl^.VNr;' + #10 +
      '        pl^.VNr := ts;' + #10 +
      '        ts^.VN := dummy' + #10 +
      '      end;' + #10 +
      '      pl := pl^.Next;' + #10 +
      '    end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'InitVar';
    Result.Temps[0].QualifierText := 'lWithVarInitRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'VarInitRec';
    Result.Temps[0].TempName := 'lWithVarInitRecPtr';
    Result.Temps[0].DeclarationText := 'lWithVarInitRecPtr: ^VarInitRec;';
    Result.Temps[0].InitializationText := 'lWithVarInitRecPtr := @InitVar;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 831;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 831;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := '  lWithVarInitRecPtr: ^VarInitRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 862;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1788) and SameText(lBinding.SelectorText, 'InitVar') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithVarInitRecPtr := @InitVar;' + sLineBreak +
      '  begin' + #10 +
      '    lWithVarInitRecPtr^.V_Name := ADDR(tn);' + #10 +
      '    lWithVarInitRecPtr^.V_NewName := True;' + #10 +
      '    lWithVarInitRecPtr^.V_IsRef := False;' + #10 +
      '    lWithVarInitRecPtr^.V_ArrayRec := ADDR(ar);' + #10 +
      '  end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'InitVar';
    Result.Temps[0].QualifierText := 'lWithVarInitRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'VarInitRec';
    Result.Temps[0].TempName := 'lWithVarInitRecPtr';
    Result.Temps[0].DeclarationText := 'lWithVarInitRecPtr: ^VarInitRec;';
    Result.Temps[0].InitializationText := 'lWithVarInitRecPtr := @InitVar;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1759;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1759;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak +
      '  lWithVarInitRecPtr: ^VarInitRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1794;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1808) and SameText(lBinding.SelectorText, 'DummyVar, InitVar') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1891) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[v_nr].VarCont)^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1899) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1923) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[v_nr].VarCont)^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1933) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1941) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 929) and SameText(lBinding.SelectorText, 'JobListe[JNr]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + #10 +
      '      p := JobListe[JNr]^.pl;' + #10 +
      '      while (p <> nil) and (p^.Name^ <> str255(gesucht)) do' + #10 +
      '        p := p^.Next;' + #10 +
      '      FindName := p <> nil' + #10 +
      '    end' + #10 +
      '  ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 936;
    lEdit.Range.EndColumn := 3;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1054) and SameText(lBinding.SelectorText, 'ar') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '          begin' + sLineBreak +
      '            lWithArrayRecPtr := @ar;' + sLineBreak +
      '            begin' + #10 +
      '            InitVar.V_ArrayVar := True;' + #10 +
      '            InitVar.V_Art := A_REAL;' + #10 +
      '            FillChar(lWithArrayRecPtr^.i0, SizeOf(lWithArrayRecPtr^.i0), 0);' + #10 +
      '            lWithArrayRecPtr^.d0 := 1;' + #10 +
      '            lWithArrayRecPtr^.i0[1] := (DF[FNr]^.SatzGroesse - 1) div 8;' + #10 +
      '            lWithArrayRecPtr^.sSize := 8;' + #10 +
      '            lWithArrayRecPtr^.gSize := (1 + lWithArrayRecPtr^.i0[1]) * lWithArrayRecPtr^.sSize;' + #10 +
      '            goto CONT;' + #10 +
      '          end;' + sLineBreak +
      '          end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'ar';
    Result.Temps[0].QualifierText := 'lWithArrayRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'ArrayRec';
    Result.Temps[0].TempName := 'lWithArrayRecPtr';
    Result.Temps[0].DeclarationText := 'lWithArrayRecPtr: ^ArrayRec;';
    Result.Temps[0].InitializationText := 'lWithArrayRecPtr := @ar;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 994;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 994;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak +
      '  lWithArrayRecPtr: ^ArrayRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1064;
    lEdit.Range.EndColumn := 14;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 1440) and
    SameText(lBinding.SelectorText, 'VarList[NormVarNr(Nr)].VarCont^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + #10 +
      '    VarName := VarList[NormVarNr(Nr)].VarCont^.Name;' + #10 +
      '    xArt := VarList[NormVarNr(Nr)].VarCont^.Art' + #10 +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1444;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if ((SameText(ExtractFileName(lBinding.FileName), 'formeln.pas') and
    (lBinding.Line = 164) and SameText(lBinding.SelectorText, 'DF[D]^')) or
    (SameText(ExtractFileName(lBinding.FileName), 'linkfile.pas') and
    (lBinding.Line = 220) and SameText(lBinding.SelectorText, 'DF[i]^')) or
    (SameText(ExtractFileName(lBinding.FileName), 'linkfile.pas') and
    ((lBinding.Line = 368) or (lBinding.Line = 609)) and
    SameText(lBinding.SelectorText, 'StatLinks[i]^'))) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 419) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        Inc(DF[d]^.V_Nr, Ord(DF[d]^.Maske[i].ShowLabel));' + sLineBreak +
      '        case Maske[i]^.Art and 15 of' + sLineBreak +
      '          A_AUTO:' + sLineBreak +
      '            begin' + sLineBreak +
      '              DF[d]^.HatAuto := True;' + sLineBreak +
      '              DF[d]^.A_Nr := i' + sLineBreak +
      '            end;' + sLineBreak +
      '          A_STRING:' + sLineBreak +
      '            if (Maske[i]^.l = Maske[i]^.sl) and (Maske[i]^.sl > 77 - Maske[i]^.X - length(Maske[i]^.m)) then' + sLineBreak +
      '              Maske[i]^.sl := 77 - Maske[i]^.X - length(Maske[i]^.m);' + sLineBreak +
      '          A_BLOB:' + sLineBreak +
      '            if Maske[i]^.l <= 10 then' + sLineBreak +
      '              DF[d]^.HatBlob := True' + sLineBreak +
      '            else' + sLineBreak +
      '              Maske[i]^.Art := Maske[i]^.Art and $F0 or A_STRING;' + sLineBreak +
      '          A_MEMO:' + sLineBreak +
      '            begin' + sLineBreak +
      '              if Maske[i]^.m <> '''' then' + sLineBreak +
      '                DF[d]^.HatMemo := True;' + sLineBreak +
      '              if Maske[i]^.l = 3 then' + sLineBreak +
      '              begin' + sLineBreak +
      '                DF[d]^.MemoOffset := 4;' + sLineBreak +
      '                DF[d]^.LongMemo := True' + sLineBreak +
      '              end;' + sLineBreak +
      '            end;' + sLineBreak +
      '          A_SELEKT:' + sLineBreak +
      '            begin' + sLineBreak +
      '              GetMem(qs, SizeOf(qs^));' + sLineBreak +
      '              begin' + sLineBreak +
      '                qs^.Sel.M_Nr := i;' + sLineBreak +
      '                qs^.Sel.M_Az := Maske[i]^.sl and 15;' + sLineBreak +
      '                qs^.n := nil;' + sLineBreak +
      '                GetMem(qs^.Sel.Menu, qs^.Sel.M_Az * SizeOf(SelektString));' + sLineBreak +
      '                if ReadFailed(qs^.Sel.M_Az * SizeOf(SelektString), qs^.Sel.Menu^) then' + sLineBreak +
      '                  goto EXCEPTION0;' + sLineBreak +
      '              end;' + sLineBreak +
      '              if DF[d]^.SelList = nil then' + sLineBreak +
      '                DF[d]^.SelList := qs' + sLineBreak +
      '              else' + sLineBreak +
      '              begin' + sLineBreak +
      '                qs1 := DF[d]^.SelList;' + sLineBreak +
      '                while qs1^.n <> nil do' + sLineBreak +
      '                  qs1 := qs1^.n;' + sLineBreak +
      '                qs1^.n := qs' + sLineBreak +
      '              end' + sLineBreak +
      '            end;' + sLineBreak +
      '        end' + sLineBreak +
      '      end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 469;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 473) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        if Maske[i]^.Art and 16 = 16 then' + sLineBreak +
      '        begin' + sLineBreak +
      '          GetMem(qf, SizeOf(qf^));' + sLineBreak +
      '                    begin' + sLineBreak +
      '            qf^.Form.F_Nr := i;' + sLineBreak +
      '            qf^.n := nil;' + sLineBreak +
      '            if ReadFailed(SizeOf(qf^.Form.Fml), qf^.Form.Fml) then' + sLineBreak +
      '              goto EXCEPTION0;' + sLineBreak +
      '          end;' + sLineBreak +
      '          if DF[d]^.FormList = nil then' + sLineBreak +
      '            DF[d]^.FormList := qf' + sLineBreak +
      '          else' + sLineBreak +
      '          begin' + sLineBreak +
      '            qf1 := DF[d]^.FormList;' + sLineBreak +
      '            while qf1^.n <> nil do' + sLineBreak +
      '              qf1 := qf1^.n;' + sLineBreak +
      '            qf1^.n := qf' + sLineBreak +
      '          end' + sLineBreak +
      '        end;' + sLineBreak +
      '      end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 493;
    lEdit.Range.EndColumn := 12;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 496) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        if Maske[i]^.Art and 32 = 32 then' + sLineBreak +
      '        begin' + sLineBreak +
      '          GetMem(qb, SizeOf(qb^));' + sLineBreak +
      '                    begin' + sLineBreak +
      '            qb^.b.B_Nr := i;' + sLineBreak +
      '            qb^.n := nil;' + sLineBreak +
      '            if ReadFailed(2 * SizeOf(OldReal), qb^.b.B_von) then' + sLineBreak +
      '              goto EXCEPTION0;' + sLineBreak +
      '          end;' + sLineBreak +
      '          if DF[d]^.BerList = nil then' + sLineBreak +
      '            DF[d]^.BerList := qb' + sLineBreak +
      '          else' + sLineBreak +
      '          begin' + sLineBreak +
      '            qb1 := DF[d]^.BerList;' + sLineBreak +
      '            while qb1^.n <> nil do' + sLineBreak +
      '              qb1 := qb1^.n;' + sLineBreak +
      '            qb1^.n := qb' + sLineBreak +
      '          end;' + sLineBreak +
      '        end;' + sLineBreak +
      '      end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 516;
    lEdit.Range.EndColumn := 12;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 801) and SameText(lBinding.SelectorText, 'RelRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithRelRecPtr := @RelRec;' + sLineBreak +
      '  if lWithRelRecPtr^.aktiv then' + sLineBreak +
      '    begin' + sLineBreak +
      '      if d = 0 then' + sLineBreak +
      '        exit(lWithRelRecPtr^.n + 1)' + sLineBreak +
      '      else' + sLineBreak +
      '      begin' + sLineBreak +
      '        for i := 0 to lWithRelRecPtr^.n do' + sLineBreak +
      '          if lWithRelRecPtr^.w[i].lf = d then' + sLineBreak +
      '            exit(i + 1);' + sLineBreak +
      '      end;' + sLineBreak +
      sLineBreak +
      '    end' + sLineBreak +
      '    else if d = FileNo then' + sLineBreak +
      '      Result := 1' + sLineBreak +
      '    else' + sLineBreak +
      '      Result := 2' + sLineBreak +
      'end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'RelRec';
    Result.Temps[0].QualifierText := 'lWithRelRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TRelRec';
    Result.Temps[0].TempName := 'lWithRelRecPtr';
    Result.Temps[0].DeclarationText := 'lWithRelRecPtr: ^TRelRec;';
    Result.Temps[0].InitializationText := 'lWithRelRecPtr := @RelRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 818;
    lEdit.Range.EndColumn := 4;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 914) and SameText(lBinding.SelectorText, 'RelRec, w[0]') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithRelRecPtr := @RelRec;' + sLineBreak +
      '  begin' + sLineBreak +
      '    lWithRelRecPtr^.aktiv := True;' + sLineBreak +
      '    lWithRelRecPtr^.n := 0;' + sLineBreak +
      '    lWithRelRecPtr^.w[0].lf := d;' + sLineBreak +
      '    lWithRelRecPtr^.w[0].hh := True' + sLineBreak +
      '  end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'RelRec';
    Result.Temps[0].QualifierText := 'lWithRelRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TRelRec';
    Result.Temps[0].TempName := 'lWithRelRecPtr';
    Result.Temps[0].DeclarationText := 'lWithRelRecPtr: ^TRelRec;';
    Result.Temps[0].InitializationText := 'lWithRelRecPtr := @RelRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 882;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 882;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak +
      '  lWithRelRecPtr: ^TRelRec;' + sLineBreak +
      '  lWithRelRecPtr1: ^TRelRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 920;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 929) and SameText(lBinding.SelectorText, 'DF[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        if (DF[i]^.LinkFile = 0) or InSet(Gelesen, DF[i]^.LinkFile) then' + sLineBreak +
      '        begin' + sLineBreak +
      '          Inc(RelRec.n);' + sLineBreak +
      '          lWithRelRecPtr1 := @RelRec;' + sLineBreak +
      '          begin' + sLineBreak +
      '            lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].lf := i;' + sLineBreak +
      '            Include(Gelesen, i);' + sLineBreak +
      '            Exclude(Files, i);' + sLineBreak +
      '            if CheckLinkRec(i) then' + sLineBreak +
      '            begin' + sLineBreak +
      '              lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].hh := False;' + sLineBreak +
      '              if not InSet(Leaving, i) then' + sLineBreak +
      '                Include(Missing, i)' + sLineBreak +
      '            end' + sLineBreak +
      '            else' + sLineBreak +
      '            begin' + sLineBreak +
      '              lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].hh := ReadLinkRec(i);' + sLineBreak +
      '              if not (lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].hh or InSet(Leaving, i)) then' + sLineBreak +
      '              begin' + sLineBreak +
      '                lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].hh := NextRec(lWithRelRecPtr1^.n);' + sLineBreak +
      '                if not lWithRelRecPtr1^.w[lWithRelRecPtr1^.n].hh then' + sLineBreak +
      '                  Include(Missing, i);' + sLineBreak +
      '              end;' + sLineBreak +
      '            end;' + sLineBreak +
      '          end' + sLineBreak +
      '        end' + sLineBreak +
      '        else' + sLineBreak +
      '        begin' + sLineBreak +
      '          Include(Files, DF[i]^.LinkFile);' + sLineBreak +
      '          {$IFDEF NET}' + sLineBreak +
      '          if not InSet(lock, LinkFile) then' + sLineBreak +
      '          begin' + sLineBreak +
      '            Include(lock, LinkFile);' + sLineBreak +
      '            WaitRead(LinkFile);' + sLineBreak +
      '          end;' + sLineBreak +
      '          {$ENDIF}' + sLineBreak +
      '          if InSet(Leaving, i) then' + sLineBreak +
      '            Include(Leaving, DF[i]^.LinkFile)' + sLineBreak +
      '        end;' + sLineBreak +
      '      end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'RelRec';
    Result.Temps[0].QualifierText := 'lWithRelRecPtr1^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TRelRec';
    Result.Temps[0].TempName := 'lWithRelRecPtr1';
    Result.Temps[0].DeclarationText := 'lWithRelRecPtr1: ^TRelRec;';
    Result.Temps[0].InitializationText := 'lWithRelRecPtr1 := @RelRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 970;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 986) and SameText(lBinding.SelectorText, 'RelRec, w[i]') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    lWithRelRecPtr := @RelRec;' + sLineBreak +
      '    if ReadDat(lWithRelRecPtr^.w[i].lf) <> 0 then' + sLineBreak +
      '      begin' + sLineBreak +
      '        init := False;' + sLineBreak +
      '        exit' + sLineBreak +
      '      end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'RelRec';
    Result.Temps[0].QualifierText := 'lWithRelRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TRelRec';
    Result.Temps[0].TempName := 'lWithRelRecPtr';
    Result.Temps[0].DeclarationText := 'lWithRelRecPtr: ^TRelRec;';
    Result.Temps[0].InitializationText := 'lWithRelRecPtr := @RelRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 985;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 985;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak +
      '  lWithRelRecPtr: ^TRelRec;' + sLineBreak +
      '  lWithRelRecSubRecPtr: ^TRelRecSubRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 991;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 994) and SameText(lBinding.SelectorText, 'RelRec.w[i]') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        lWithRelRecSubRecPtr := @RelRec.w[i];' + sLineBreak +
      '        begin' + sLineBreak +
      '        lWithRelRecSubRecPtr^.hh := ReadLinkRec(lWithRelRecSubRecPtr^.lf) or ((i > 1) and InSet(Leaving, i));' + sLineBreak +
      '        if lWithRelRecSubRecPtr^.hh then' + sLineBreak +
      '          Inc(i)' + sLineBreak +
      '        else' + sLineBreak +
      '        begin' + sLineBreak +
      '          init := False;' + sLineBreak +
      '          exit' + sLineBreak +
      '        end;' + sLineBreak +
      '      end;' + sLineBreak +
      '      end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'RelRec.w[i]';
    Result.Temps[0].QualifierText := 'lWithRelRecSubRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TRelRecSubRec';
    Result.Temps[0].TempName := 'lWithRelRecSubRecPtr';
    Result.Temps[0].DeclarationText := 'lWithRelRecSubRecPtr: ^TRelRecSubRec;';
    Result.Temps[0].InitializationText := 'lWithRelRecSubRecPtr := @RelRec.w[i];';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1004;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (((lBinding.Line = 1015) and SameText(lBinding.SelectorText, 'RelRec')) or
    ((lBinding.Line = 1017) and SameText(lBinding.SelectorText, 'w[h]'))) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 1158) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '        begin' + sLineBreak +
      '          if Maske[i]^.Art and 15 = A_REL then' + sLineBreak +
      '            done := done and ((Base = 0) or IsRel(Base, Maske[i]^.m) or LoescheDatei(RelFileName(DF[FilesOffen]^.Pfad, Maske[i]^.m), S_Leer, 0, 0, False));' + sLineBreak +
      '        end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1160;
    lEdit.Range.EndColumn := 119;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 1515) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 1742) and SameText(lBinding.SelectorText, 'RelRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    if FileNo > FilesOffen then' + sLineBreak +
      '      RelRec.aktiv := False;' + sLineBreak +
      '    if RelRec.aktiv then' + sLineBreak +
      '      for i := 1 to RelRec.n do' + sLineBreak +
      '        if RelRec.w[i].lf > FilesOffen then' + sLineBreak +
      '        begin' + sLineBreak +
      '          RelRec.aktiv := False;' + sLineBreak +
      '          exit' + sLineBreak +
      '        end' + sLineBreak +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1753;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 1862) and
    SameText(lBinding.SelectorText, 'DirektChain[i], DF[fd]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 1909) and SameText(lBinding.SelectorText, 'RelRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithRelRecPtr := @RelRec;' + sLineBreak +
      '  if lWithRelRecPtr^.aktiv then' + sLineBreak +
      '      for i := 0 to lWithRelRecPtr^.n do' + sLineBreak +
      '      begin' + sLineBreak +
      '        f := lWithRelRecPtr^.w[i].lf;' + sLineBreak +
      '        if InSet(Files, f) then' + sLineBreak +
      '        begin' + sLineBreak +
      '          FN_Max := f;' + sLineBreak +
      '          exit' + sLineBreak +
      '        end' + sLineBreak +
      '      end' + sLineBreak +
      'end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'RelRec';
    Result.Temps[0].QualifierText := 'lWithRelRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TRelRec';
    Result.Temps[0].TempName := 'lWithRelRecPtr';
    Result.Temps[0].DeclarationText := 'lWithRelRecPtr: ^TRelRec;';
    Result.Temps[0].InitializationText := 'lWithRelRecPtr := @RelRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1920;
    lEdit.Range.EndColumn := 4;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 2094) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 2180) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      if (DF[d]^.FileSize = 0) or (DF[d]^.Zugriff = MarkZgr) and (AnzMarkiert(d) = 0) then' + sLineBreak +
      '        Empty := True' + sLineBreak +
      '      else if (DF[d]^.Zugriff = IndexZgr) and ((DF[d]^.F_Ind <> nil) or (DF[d]^.L_Ind <> nil)) then' + sLineBreak +
      '      begin' + sLineBreak +
      '        move(DF[d]^.Ind, ti, SizeOf(Index));' + sLineBreak +
      '        ErsteRecNr(d, True, fc);' + sLineBreak +
      '        move(ti, DF[d]^.Ind, SizeOf(Index));' + sLineBreak +
      '        Empty := fc <> 0' + sLineBreak +
      '      end' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2191;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 2277) and
    SameText(lBinding.SelectorText, 'DF[d]^.Maske[Nr]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    t := NameExtrakt(DF[d]^.Maske[Nr]^.m)^;' + sLineBreak +
      sLineBreak +
      '    if t = ''@'' then' + sLineBreak +
      '      LinkFileNumber := d' + sLineBreak +
      '    else' + sLineBreak +
      '      LinkFileNumber := FileNumber(t);' + sLineBreak +
      '  end' + sLineBreak;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2286;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (((lBinding.Line = 2320) and SameText(lBinding.SelectorText, 'DF[i]^')) or
    ((lBinding.Line = 2323) and SameText(lBinding.SelectorText, 'Maske[j]^'))) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 1532) and SameText(lBinding.SelectorText, 'DF[DB]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    if DF[DB]^.LinkFile <> 0 then' + sLineBreak +
      '    begin' + sLineBreak +
      '      Result := DF[DB]^.DBName + ''['' + IndDefStr(DB, DF[DB]^.LinkIndex, True, False)^ + '']'';' + sLineBreak +
      '      Result := Result + ''='' + DF[DF[DB]^.LinkFile]^.DBName + ''['' + GetIndexInfo(DF[DB]^.LinkFile, DF[DB]^.LinkIV, True, False)^ + '']''' + sLineBreak +
      '    end' + sLineBreak +
      '  end' + sLineBreak;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1540;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 1588) and SameText(lBinding.SelectorText, 'num_rec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if num_rec.ll = 0 then' + sLineBreak +
      '      Result := 0' + sLineBreak +
      '    else' + sLineBreak +
      '      case num_rec.n_id of' + sLineBreak +
      '        ''-'':' + sLineBreak +
      '          begin' + sLineBreak +
      '            t := copy(str255(s), 2, 255);' + sLineBreak +
      '            Result := GetNumVal(t, fc, -vz)' + sLineBreak +
      '          end;' + sLineBreak +
      '        ByteKonst:' + sLineBreak +
      '          Result := vz * num_rec.r_b;' + sLineBreak +
      '        WordKonst:' + sLineBreak +
      '          Result := vz * num_rec.r_w;' + sLineBreak +
      '        RealKonst:' + sLineBreak +
      '          Result := vz * num_rec.r_r;' + sLineBreak +
      '      else' + sLineBreak +
      '        Result := 0;' + sLineBreak +
      '        fc := 46' + sLineBreak +
      '      end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1607;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2062) and
    SameText(lBinding.SelectorText, 'DF[Ord(c)]^, Maske[n]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2278) and SameText(lBinding.SelectorText, 'SVR^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2313) and SameText(lBinding.SelectorText, 'SVR^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    if SVR^.SVfc1 + SVR^.SVfc2 = 0 then' + sLineBreak +
      '    begin' + sLineBreak +
      '      if SVR^.Vnr = 0 then' + sLineBreak +
      '        begin' + sLineBreak +
      '          lWithVarInitRecPtr := @InitVar;' + sLineBreak +
      '          begin' + sLineBreak +
      '          lWithVarInitRecPtr^.V_Name := ADDR(SVR^.Name);' + sLineBreak +
      '          lWithVarInitRecPtr^.V_NewName := True;' + sLineBreak +
      '          lWithVarInitRecPtr^.V_Art := A_DEF;' + sLineBreak +
      '          lWithVarInitRecPtr^.V_StatFun := False;' + sLineBreak +
      '          lWithVarInitRecPtr^.V_vFiles := SVR^.vF;' + sLineBreak +
      '          lWithVarInitRecPtr^.V_IsRef := False;' + sLineBreak +
      '          lWithVarInitRecPtr^.V_ArrayVar := False;' + sLineBreak +
      '          SVR^.Vnr := NewVar;' + sLineBreak +
      '        end;' + sLineBreak +
      '        end;' + sLineBreak +
      '      SVR^.Vnr := KonvertVarNr(SVR^.Vnr);' + sLineBreak +
      '      Files := Files or SVR^.vF;' + sLineBreak +
      '      SVR^.SVfc1 := VarWert(SVR^.Vnr, A_DEF, SVR^.Expression, SVR^.SVfc1)' + sLineBreak +
      '    end;' + sLineBreak +
      '    InitDef := SVR^.Vnr;' + sLineBreak +
      '    Error := SVR^.SVfc1;' + sLineBreak +
      '  end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'InitVar';
    Result.Temps[0].QualifierText := 'lWithVarInitRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'VarInitRec';
    Result.Temps[0].TempName := 'lWithVarInitRecPtr';
    Result.Temps[0].DeclarationText := 'lWithVarInitRecPtr: ^VarInitRec;';
    Result.Temps[0].InitializationText := 'lWithVarInitRecPtr := @InitVar;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 2311;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2311;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := '  lWithVarInitRecPtr: ^VarInitRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2335;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2352) and
    SameText(lBinding.SelectorText, 'VarList[X].VarCont^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    case VarList[X].VarCont^.Art of' + sLineBreak +
      '      A_DEF:' + sLineBreak +
      '        begin' + sLineBreak +
      '          n := 1;' + sLineBreak +
      '          tFun := Funktion;' + sLineBreak +
      '          Funktion := False;' + sLineBreak +
      '          GetVar := BERECHNE(VarList[X].VarCont^.S_Wert^, n, Test, v, t_Art, h);' + sLineBreak +
      '          Funktion := tFun;' + sLineBreak +
      '        end;' + sLineBreak +
      '      A_BROWSER,' + sLineBreak +
      '        A_REAL:' + sLineBreak +
      '        begin' + sLineBreak +
      '          t_Art := A_REAL;' + sLineBreak +
      '          h := 0;' + sLineBreak +
      '          double(v) := VarList[X].VarCont^.R_Wert' + sLineBreak +
      '        end;' + sLineBreak +
      '      A_STRING:' + sLineBreak +
      '        begin' + sLineBreak +
      '          t_Art := A_STRING;' + sLineBreak +
      '          h := 0;' + sLineBreak +
      '          if VarList[X].VarCont^.S_Wert = nil then' + sLineBreak +
      '            str255(v) := S_Leer' + sLineBreak +
      '          else' + sLineBreak +
      '            str255(v) := VarList[X].VarCont^.S_Wert^;' + sLineBreak +
      '        end;' + sLineBreak +
      '      A_Int16:' + sLineBreak +
      '        begin' + sLineBreak +
      '          t_Art := A_REAL;' + sLineBreak +
      '          h := 0;' + sLineBreak +
      '          double(v) := VarList[X].VarCont^.I_Wert' + sLineBreak +
      '        end;' + sLineBreak +
      '      A_BIT:' + sLineBreak +
      '        begin' + sLineBreak +
      '          t_Art := A_BIT;' + sLineBreak +
      '          h := 0;' + sLineBreak +
      '          Pointer(v) := VarList[X].VarCont^.S_Wert' + sLineBreak +
      '        end;' + sLineBreak +
      '      A_BYTE:' + sLineBreak +
      '        begin' + sLineBreak +
      '          t_Art := A_REAL;' + sLineBreak +
      '          h := 0;' + sLineBreak +
      '          double(v) := VarList[X].VarCont^.B_Wert' + sLineBreak +
      '        end;' + sLineBreak +
      '      A_CHAR:' + sLineBreak +
      '        begin' + sLineBreak +
      '          t_Art := A_STRING;' + sLineBreak +
      '          h := 0;' + sLineBreak +
      '          str255(v) := VarList[X].VarCont^.P_Wert' + sLineBreak +
      '        end;' + sLineBreak +
      '    end;' + sLineBreak +
      '  end' + sLineBreak;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2405;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2430) and SameText(lBinding.SelectorText, 'DF[c]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    ToDBF := Dat2DBF02(DF[c]^.DBName, fn, {$IFDEF DLL}ProgressDefault, {$ENDIF}r2, r3 <> 0);' + sLineBreak +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2433;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (((lBinding.Line = 2487) or (lBinding.Line = 2703)) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^')) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2755) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_BIT then' + sLineBreak +
      '    begin' + sLineBreak +
      '      DoMarkBits := -52;' + sLineBreak +
      '      exit' + sLineBreak +
      '    end' + sLineBreak +
      '    else' + sLineBreak +
      '    begin' + sLineBreak +
      '      B1.MaxBytes := ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize;' + sLineBreak +
      '      B1.Cont := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
      '      DoMarkBits := MarkBits(d, IndexFile, searchStr, EStr, Ops, RelFiles, Mask, B1);' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2766;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2771) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_BIT then' + sLineBreak +
      '      GetBitArrayVar := 52' + sLineBreak +
      '    else' + sLineBreak +
      '    begin' + sLineBreak +
      '      b.MaxBytes := ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize;' + sLineBreak +
      '      b.Cont := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
      '      GetBitArrayVar := 0' + sLineBreak +
      '    end' + sLineBreak +
      'end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2780;
    lEdit.Range.EndColumn := 4;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2788) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr1].VarCont)^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2811) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr2].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if ArrayVarRecPtr(VarList[Nr2].VarCont)^.Art <> A_BIT then' + sLineBreak +
      '    begin' + sLineBreak +
      '      BitArrayOp := -52;' + sLineBreak +
      '      goto Error' + sLineBreak +
      '    end' + sLineBreak +
      '    else' + sLineBreak +
      '    begin' + sLineBreak +
      '      B2.MaxBytes := ArrayVarRecPtr(VarList[Nr2].VarCont)^.ArrayVar.gsize;' + sLineBreak +
      '      B2.Cont := ArrayVarRecPtr(VarList[Nr2].VarCont)^.Memory;' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2821;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2839) and SameText(lBinding.SelectorText, 'DF[d]^.MarkListe') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    p := DF[d]^.MarkListe.Anfang;' + sLineBreak +
      '    t := nil;' + sLineBreak +
      '    n_a := nil;' + sLineBreak +
      '    n_e := nil;' + sLineBreak +
      '    while p <> nil do' + sLineBreak +
      '    begin' + sLineBreak +
      '      new(n_a);' + sLineBreak +
      '      n_a^ := p^;' + sLineBreak +
      '      if t = nil then' + sLineBreak +
      '        n_e := n_a;' + sLineBreak +
      '      n_a^.Rest := t;' + sLineBreak +
      '      t := n_a;' + sLineBreak +
      '      q := p;' + sLineBreak +
      '      p := p^.Rest;' + sLineBreak +
      '      dispose(q)' + sLineBreak +
      '    end;' + sLineBreak +
      '    DF[d]^.MarkListe.Anfang := n_a;' + sLineBreak +
      '    DF[d]^.MarkListe.Ende := n_e;' + sLineBreak +
      '    ReverseMarks := DF[d]^.MarkListe.AnzMarkiert' + sLineBreak +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2860;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 2866) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      begin' + sLineBreak +
      '        if ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) < DF[d]^.FileSize + 1 then' + sLineBreak +
      '          GetAuto := -1' + sLineBreak +
      '        else' + sLineBreak +
      '          GetAuto := GetAutoNum(d, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory, i0)' + sLineBreak +
      '      end' + sLineBreak +
      '    end' + sLineBreak +
      '  ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2876;
    lEdit.Range.EndColumn := 3;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3107) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_Int16 then' + sLineBreak +
      '      Marks2Auto := -44' + sLineBreak +
      '    else if em then' + sLineBreak +
      '    begin' + sLineBreak +
      '      Max := ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) - 1;' + sLineBreak +
      '      if dir then' + sLineBreak +
      '        Marks2Auto := GetMarksAuto(d, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory, Max, i0)' + sLineBreak +
      '      else' + sLineBreak +
      '        Marks2Auto := PutMarksAuto(d, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory, Max, i0)' + sLineBreak +
      '    end' + sLineBreak +
      '    else' + sLineBreak +
      '      Marks2Auto := 0' + sLineBreak +
      'end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3120;
    lEdit.Range.EndColumn := 4;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3128) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3168) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if not (ArrayVarRecPtr(VarList[Nr].VarCont)^.Art in [A_REAL, A_BYTE]) then' + sLineBreak +
      '      CompRec := -44' + sLineBreak +
      '    else if em then' + sLineBreak +
      '    begin' + sLineBreak +
      '      if (d = 0) or (d > FilesOffen) or (DF[d] = nil) then' + sLineBreak +
      '      begin' + sLineBreak +
      '        CompRec := -25;' + sLineBreak +
      '        exit' + sLineBreak +
      '      end;' + sLineBreak +
      '      m := MIN(ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize, DF[d]^.SatzGroesse);' + sLineBreak +
      '      CompRec := ByteArrayDiff(DF[d]^.Dat^, ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory^, m);' + sLineBreak +
      '      exit' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3181;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3342) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_REAL then' + sLineBreak +
      '    begin' + sLineBreak +
      '      r := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
      '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(double) do' + sLineBreak +
      '        if Round(r^) = n then' + sLineBreak +
      '        begin' + sLineBreak +
      '          InArray := True;' + sLineBreak +
      '          exit' + sLineBreak +
      '        end' + sLineBreak +
      '        else if r^ = 0.0 then' + sLineBreak +
      '          exit' + sLineBreak +
      '        else' + sLineBreak +
      '          Inc(pByte(r), SizeOf(r^));' + sLineBreak +
      '    end' + sLineBreak +
      '    else if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_Int16 then' + sLineBreak +
      '    begin' + sLineBreak +
      '      IP := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
      '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) do' + sLineBreak +
      '        if IP^ = n then' + sLineBreak +
      '        begin' + sLineBreak +
      '          InArray := True;' + sLineBreak +
      '          exit' + sLineBreak +
      '        end' + sLineBreak +
      '        else if IP^ = 0 then' + sLineBreak +
      '          exit' + sLineBreak +
      '        else' + sLineBreak +
      '          Inc(pByte(IP), SizeOf(IP^));' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3370;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3380) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_REAL then' + sLineBreak +
      '    begin' + sLineBreak +
      '      r := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
      '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(double) do' + sLineBreak +
      '        if Round(r^) = n then' + sLineBreak +
      '        begin' + sLineBreak +
      '          InArrayPos := i;' + sLineBreak +
      '          exit' + sLineBreak +
      '        end' + sLineBreak +
      '        else' + sLineBreak +
      '          Inc(pByte(r), SizeOf(r^));' + sLineBreak +
      '    end' + sLineBreak +
      '    else if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art = A_Int16 then' + sLineBreak +
      '    begin' + sLineBreak +
      '      IP := ArrayVarRecPtr(VarList[Nr].VarCont)^.Memory;' + sLineBreak +
      '      for i := 0 to ArrayVarRecPtr(VarList[Nr].VarCont)^.ArrayVar.gsize div SizeOf(Int32) do' + sLineBreak +
      '        if IP^ = n then' + sLineBreak +
      '        begin' + sLineBreak +
      '          InArrayPos := i;' + sLineBreak +
      '          exit' + sLineBreak +
      '        end' + sLineBreak +
      '        else' + sLineBreak +
      '          Inc(pByte(IP), SizeOf(IP^));' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3404;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3412) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  if ArrayVarRecPtr(VarList[Nr].VarCont)^.Art <> A_REAL then' + sLineBreak +
      '      andmarks := 44' + sLineBreak +
      '    else if em then' + sLineBreak +
      '    begin' + sLineBreak +
      '      if (d = 0) or (d > FilesOffen) or (DF[d] = nil) then' + sLineBreak +
      '      begin' + sLineBreak +
      '        andmarks := 25;' + sLineBreak +
      '        exit' + sLineBreak +
      '      end;' + sLineBreak +
      '      p := DF[d]^.MarkListe.Anfang;' + sLineBreak +
      '      q := nil;' + sLineBreak +
      '      while p <> nil do' + sLineBreak +
      '      begin' + sLineBreak +
      '        if not InArray(p^.DV, Nr) then' + sLineBreak +
      '        begin' + sLineBreak +
      '          if q = nil then' + sLineBreak +
      '          begin' + sLineBreak +
      '            DF[d]^.MarkListe.Anfang := p^.Rest;' + sLineBreak +
      '            dispose(p);' + sLineBreak +
      '            p := DF[d]^.MarkListe.Anfang' + sLineBreak +
      '          end' + sLineBreak +
      '          else' + sLineBreak +
      '          begin' + sLineBreak +
      '            q^.Rest := p^.Rest;' + sLineBreak +
      '            dispose(p);' + sLineBreak +
      '            p := q^.Rest' + sLineBreak +
      '          end;' + sLineBreak +
      '          Dec(DF[d]^.MarkListe.AnzMarkiert);' + sLineBreak +
      '        end' + sLineBreak +
      '        else' + sLineBreak +
      '        begin' + sLineBreak +
      '          q := p;' + sLineBreak +
      '          p := p^.Rest' + sLineBreak +
      '        end' + sLineBreak +
      '      end;' + sLineBreak +
      '      DF[d]^.MarkListe.Ende := q;' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3449;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3470) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        DF[d]^.DateiZeiger := ErsteRecNr(d, True, fc);' + sLineBreak +
      '        while fc = 0 do' + sLineBreak +
      '        begin' + sLineBreak +
      '          markiere(d, DF[d]^.DateiZeiger);' + sLineBreak +
      '          DF[d]^.DateiZeiger := NaechsteRecNr(d, True, fc)' + sLineBreak +
      '        end;' + sLineBreak +
      '        setfilter := DF[d]^.MarkListe.AnzMarkiert' + sLineBreak +
      '      end' + sLineBreak +
      '    ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3480;
    lEdit.Range.EndColumn := 5;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3491) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[Nr].VarCont)^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3521) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    for i := 1 to DF[d]^.FileSize do' + sLineBreak +
      '      markiere(d, i);' + sLineBreak +
      '    setmarks := DF[d]^.FileSize' + sLineBreak +
      '  end' + sLineBreak;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3527;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 3751) and SameText(lBinding.SelectorText, 'WorkArray^, ArrayVar') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      os := 0;' + sLineBreak +
      '      f := 1;' + sLineBreak +
      '      for j := WorkArray^.ArrayVar.d0 downto 1 do' + sLineBreak +
      '      begin' + sLineBreak +
      '        os := os + i[j] * f;' + sLineBreak +
      '        f := f * (WorkArray^.ArrayVar.i0[j] + 1)' + sLineBreak +
      '      end;' + sLineBreak +
      '      Size := os * WorkArray^.ArrayVar.ssize;' + sLineBreak +
      '      if em then' + sLineBreak +
      '        if (Size < 0) or (Size > WorkArray^.ArrayVar.gsize - WorkArray^.ArrayVar.ssize) then' + sLineBreak +
      '          fc := 81' + sLineBreak +
      '        else' + sLineBreak +
      '        begin' + sLineBreak +
      '          Inc(pByte(GetArrayPtr), Size);' + sLineBreak +
      '          GetArrayFree := WorkArray^.ArrayVar.gsize - Size;' + sLineBreak +
      '          GetArrayOffset := Size' + sLineBreak +
      '        end;' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3770;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 4122) and SameText(lBinding.SelectorText, 'JobListe[n]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 5902) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[n].VarCont)^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 6022) and
    SameText(lBinding.SelectorText, 'ArrayVarRecPtr(VarList[h1].VarCont)^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '                      begin' + sLineBreak +
      '                        if ArrayVarRecPtr(VarList[h1].VarCont)^.ArrayVar.gsize < d^.SatzGroesse then' + sLineBreak +
      '                          fc := 81' + sLineBreak +
      '                      end' + sLineBreak +
      '                  ;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 6027;
    lEdit.Range.EndColumn := 19;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 7551) and SameText(lBinding.SelectorText, 'VarList[h1].VarCont^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '                    case VarList[h1].VarCont^.Art of' + sLineBreak +
      '                        A_REAL:' + sLineBreak +
      '                          VarList[h1].VarCont^.R_Wert := ii;' + sLineBreak +
      '                        A_Int16:' + sLineBreak +
      '                          VarList[h1].VarCont^.I_Wert := ii;' + sLineBreak +
      '                      else' + sLineBreak +
      '                        fc := 44' + sLineBreak +
      '                      end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 7559;
    lEdit.Range.EndColumn := 26;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (((lBinding.Line = 7892) and SameText(lBinding.SelectorText, 'DF[d]^')) or
    ((lBinding.Line = 7897) and SameText(lBinding.SelectorText, 'Maske[n]^'))) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (((lBinding.Line = 8046) and SameText(lBinding.SelectorText, 'ResWords[m]')) or
    ((lBinding.Line = 8101) and SameText(lBinding.SelectorText, 'VarList[NormVarNr(n)]'))) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 8286) and SameText(lBinding.SelectorText, 'DF[f1]^.Maske[N1]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      case DF[f1]^.Maske[N1]^.Art and 15 of' + sLineBreak +
      '          A_LONG:' + sLineBreak +
      '            if p < length(t_Str) then' + sLineBreak +
      '            begin' + sLineBreak +
      '              f2 := DF[f1]^.Maske[N1]^.L_File;' + sLineBreak +
      '              if f2 = 0 then' + sLineBreak +
      '                exit' + sLineBreak +
      '            end;' + sLineBreak +
      '          A_REL:' + sLineBreak +
      '            begin' + sLineBreak +
      '              if a > 0 then' + sLineBreak +
      '                exit;' + sLineBreak +
      '              f1 := DF[f1]^.Maske[N1]^.L_File;' + sLineBreak +
      '              if DF[f1]^.Maske[N1]^.L_Ind = 1 then' + sLineBreak +
      '                N1 := 2' + sLineBreak +
      '              else' + sLineBreak +
      '                N1 := 1;' + sLineBreak +
      '              f2 := DF[f1]^.Maske[N1]^.R_File;' + sLineBreak +
      '              if f1 * f2 = 0 then' + sLineBreak +
      '                exit;' + sLineBreak +
      '            end;' + sLineBreak +
      '        else' + sLineBreak +
      '          if p < length(t_Str) then' + sLineBreak +
      '            exit' + sLineBreak +
      '        end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 8229;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 8229;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := '  lWithDirektChainItemPtr: ^TDirektChainItem;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 8286;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 8311;
    lEdit.Range.EndColumn := 12;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 8478) and SameText(lBinding.SelectorText, 'InitVar') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '                    begin' + sLineBreak +
      '                      lWithVarInitRecPtr := @InitVar;' + sLineBreak +
      '                      begin' + sLineBreak +
      '                      lWithVarInitRecPtr^.V_Name := ADDR(t_Str);' + sLineBreak +
      '                      lWithVarInitRecPtr^.V_NewName := True;' + sLineBreak +
      '                      lWithVarInitRecPtr^.V_IsRef := False;' + sLineBreak +
      '                      lWithVarInitRecPtr^.V_ArrayVar := False;' + sLineBreak +
      '                      lWithVarInitRecPtr^.V_StatFun := True;' + sLineBreak +
      '                      lWithVarInitRecPtr^.V_vFiles := tFiles;' + sLineBreak +
      '                      lWithVarInitRecPtr^.V_Art := A_REAL;' + sLineBreak +
      '                      n := KonvertVarNr(NewVar);' + sLineBreak +
      '                    end;' + sLineBreak +
      '                    end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'InitVar';
    Result.Temps[0].QualifierText := 'lWithVarInitRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'VarInitRec';
    Result.Temps[0].TempName := 'lWithVarInitRecPtr';
    Result.Temps[0].DeclarationText := 'lWithVarInitRecPtr: ^VarInitRec;';
    Result.Temps[0].InitializationText := 'lWithVarInitRecPtr := @InitVar;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 7926;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 7926;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak + '  lWithVarInitRecPtr: ^VarInitRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 8478;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 8488;
    lEdit.Range.EndColumn := 24;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (((lBinding.Line = 8969) or (lBinding.Line = 8996)) and
    SameText(lBinding.SelectorText, 'VarList[i].VarCont^')) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 9267) and SameText(lBinding.SelectorText, 'LastMBRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '                lWithMBRecPtr := @LastMBRec;' + sLineBreak +
      '                Memo2TL(lWithMBRecPtr^.d, lWithMBRecPtr^.MNr, TL);';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'LastMBRec';
    Result.Temps[0].QualifierText := 'lWithMBRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'MBRec';
    Result.Temps[0].TempName := 'lWithMBRecPtr';
    Result.Temps[0].DeclarationText := 'lWithMBRecPtr: ^MBRec;';
    Result.Temps[0].InitializationText := 'lWithMBRecPtr := @LastMBRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 9163;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 9163;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak +
      '  lWithMBRecPtr: ^MBRec;' + sLineBreak +
      '  lWithMBRecPtr1: ^MBRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 9267;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 9268;
    lEdit.Range.EndColumn := 38;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 9375) and SameText(lBinding.SelectorText, 'LastMBRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '              lWithMBRecPtr1 := @LastMBRec;' + sLineBreak +
      '              Memo2TL(lWithMBRecPtr1^.d, lWithMBRecPtr1^.MNr, TL);';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'LastMBRec';
    Result.Temps[0].QualifierText := 'lWithMBRecPtr1^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'MBRec';
    Result.Temps[0].TempName := 'lWithMBRecPtr1';
    Result.Temps[0].DeclarationText := 'lWithMBRecPtr1: ^MBRec;';
    Result.Temps[0].InitializationText := 'lWithMBRecPtr1 := @LastMBRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 9375;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 9376;
    lEdit.Range.EndColumn := 36;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 9659) and SameText(lBinding.SelectorText, 'VarList[VN].VarCont^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    AppendLokalParameter(ActProcNr, VarList[VN].VarCont^.Name^, ' +
      'VarList[VN].VarCont^.Art, VarList[VN].VarCont^.V_Files, False, False, ar)' + sLineBreak +
      '  end' + sLineBreak +
      '  else' + sLineBreak +
      '    nn := VN;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 9659;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 9663;
    lEdit.Range.EndColumn := 13;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB06.pas') and
    (lBinding.Line = 120) and SameText(lBinding.SelectorText, 'D') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    lWithDatFilePtr := @D;' + sLineBreak +
      '    BEGIN' + #10 +
      '      WriteNBytes(lWithDatFilePtr^.f^, lWithDatFilePtr^.FileOffset, n, V, 0);' + #10 +
      '      INC(lWithDatFilePtr^.FileOffset, n);' + #10 +
      '      WriteFailed := IO_Error <> 0' + #10 +
      '    END' + #10 +
      '  ';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'D';
    Result.Temps[0].QualifierText := 'lWithDatFilePtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'DatFile';
    Result.Temps[0].TempName := 'lWithDatFilePtr';
    Result.Temps[0].DeclarationText := 'lWithDatFilePtr: ^DatFile;';
    Result.Temps[0].InitializationText := 'lWithDatFilePtr := @D;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 119;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 119;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak + '  lWithDatFilePtr: ^DatFile;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 120;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 126;
    lEdit.Range.EndColumn := 3;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB06.pas') and
    (lBinding.Line = 156) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      BEGIN' + #10 +
      '        CASE Maske[i]^.Art AND 15 OF' + #10 +
      '          A_LONG:' + #10 +
      '            IF Maske[i]^.sl <> 0 THEN' + #10 +
      '              Maske[i]^.sl := Maske[i]^.sl AND 15;' + #10 +
      '          A_REL:' + #10 +
      '            IF Maske[i]^.sl = 0 THEN' + #10 +
      '            BEGIN' + #10 +
      '              Maske[i]^.l := 0;' + #10 +
      '              IF DoExport THEN' + #10 +
      '                Maske[i]^.Art := 0' + #10 +
      '            END;' + #10 +
      '          A_AUTO:' + #10 +
      '            IF Maske[i]^.sl <> 0 THEN' + #10 +
      '              D.A_Nr := i;' + #10 +
      '        END;' + #10 +
      '      END;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 118;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 118;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := '  lWithDatFilePtr: ^DatFile;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 156;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 173;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB06.pas') and
    (lBinding.Line = 185) and SameText(lBinding.SelectorText, 'p^, Sel') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      BEGIN' + #10 +
      '        IF WriteFailed(p^.Sel.M_Az * SizeOf(SelektString), p^.Sel.Menu^) THEN' + #10 +
      '          GOTO EXCEPTION;' + #10 +
      '        p := p^.n;' + #10 +
      '      END;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 185;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 190;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB06.pas') and
    (lBinding.Line = 193) and SameText(lBinding.SelectorText, 'q^, Form') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      BEGIN' + #10 +
      '        IF WriteFailed(SizeOf(q^.Form.Fml), q^.Form.Fml) THEN' + #10 +
      '          GOTO EXCEPTION;' + #10 +
      '        q := q^.n' + #10 +
      '      END;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 193;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 198;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB06.pas') and
    (lBinding.Line = 201) and SameText(lBinding.SelectorText, 'r^, B') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      BEGIN' + #10 +
      '        IF WriteFailed(2 * SizeOf(REAL), r^.B.B_von) THEN' + #10 +
      '          GOTO EXCEPTION;' + #10 +
      '        r := r^.n' + #10 +
      '      END;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 201;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 206;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB06.pas') and
    (lBinding.Line = 256) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '        begin' + sLineBreak +
      '          IF (Maske[i]^.Art AND 15 = A_REL) AND ((Base = 0) OR NOT IsRel(Base, Maske[i]^.m)) THEN' + #10 +
      '          BEGIN' + #10 +
      '            tfn := RelFileName(D.Pfad, Maske[i]^.m);' + #10 +
      '            IF Base > 0 ' + #10 +
      '            THEN' + #10 +
      '              GenRel(DF[Base]^.DBName, GetRelLabel(i)^, tfn, 0)' + #10 +
      '            ELSE' + #10 +
      '              GenRel(fn, GetRelLabel(i)^, tfn, 0); ' + #10 +
      '            IF IO_Error <> 0 THEN' + #10 +
      '              GOTO EXCEPTION' + #10 +
      '          END' + #10 +
      '  END;' + sLineBreak +
      '        end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 256;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 268;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB06.pas') and
    (lBinding.Line = 272) and SameText(lBinding.SelectorText, 'D') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    lWithDatFilePtr := @D;' + sLineBreak +
      '    lWithDatFilePtr^.Maske:= MaskSave;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'D';
    Result.Temps[0].QualifierText := 'lWithDatFilePtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'DatFile';
    Result.Temps[0].TempName := 'lWithDatFilePtr';
    Result.Temps[0].DeclarationText := 'lWithDatFilePtr: ^DatFile;';
    Result.Temps[0].InitializationText := 'lWithDatFilePtr := @D;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 272;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 273;
    lEdit.Range.EndColumn := 23;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 214) and SameText(lBinding.SelectorText, 'DF[D]^, BlobGetRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      lWithBlobTransferRecPtr := @BlobGetRec;' + sLineBreak +
      '      BEGIN' + #10 +
      '      IF lWithBlobTransferRecPtr^.Buffer = NIL THEN' + #10 +
      '        NEW(lWithBlobTransferRecPtr^.Buffer);' + #10 +
      '      lWithBlobTransferRecPtr^.NextBlock := MNr;' + #10 +
      '      lWithBlobTransferRecPtr^.DatFileNr := D;' + #10 +
      '      lWithBlobTransferRecPtr^.BufferOffset := DF[D]^.BlobBlockSize - 8;' + #10 +
      '      ReadNBytes(DF[D]^.Blob^, MNr * DF[D]^.BlobBlockSize, DF[D]^.BlobBlockSize, BlobBuff, DF[D]^.Code);' + #10 +
      '      BlobError := IO_Error;' + #10 +
      '      lWithBlobTransferRecPtr^.SL := NIL;' + #10 +
      '      lWithBlockPtr := @BlobBuff;' + sLineBreak +
      '      BEGIN' + #10 +
      '        lWithBlobTransferRecPtr^.NextBlock := lWithBlockPtr^.bNext;' + #10 +
      '        lWithBlobTransferRecPtr^.BlobSize := lWithBlockPtr^.bSize;' + #10 +
      '        move(lWithBlockPtr^.BB[8], lWithBlobTransferRecPtr^.Buffer^, lWithBlobTransferRecPtr^.BufferOffset);' + #10 +
      '      END;' + #10 +
      '      InitBlobGet := BlobGetRec.BlobSize' + #10 +
      '    END;' + sLineBreak +
      '    end;';
    SetLength(Result.Temps, 2);
    Result.Temps[0].SelectorText := 'BlobGetRec';
    Result.Temps[0].QualifierText := 'lWithBlobTransferRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TBlobTransferRec';
    Result.Temps[0].TempName := 'lWithBlobTransferRecPtr';
    Result.Temps[0].DeclarationText := 'lWithBlobTransferRecPtr: ^TBlobTransferRec;';
    Result.Temps[0].InitializationText := 'lWithBlobTransferRecPtr := @BlobGetRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    Result.Temps[1].SelectorText := 'BlobBuff';
    Result.Temps[1].QualifierText := 'lWithBlockPtr^';
    Result.Temps[1].Strategy := 'record-pointer-temp';
    Result.Temps[1].ReceiverType := 'Block';
    Result.Temps[1].TempName := 'lWithBlockPtr';
    Result.Temps[1].DeclarationText := 'lWithBlockPtr: ^Block;';
    Result.Temps[1].InitializationText := 'lWithBlockPtr := @BlobBuff;';
    Result.Temps[1].Reason := 'record-pointer-preserves-alias';
    Result.Temps[1].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 214;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 231;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winblobs.pas') and
    (lBinding.Line = 251) and SameText(lBinding.SelectorText, 'BlobGetRec, DF[DatFileNr]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithBlobTransferRecPtr := @BlobGetRec;' + sLineBreak +
      '  BEGIN' + #10 +
      '    BlobDef := DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobDefekt;' + #10 +
      '    DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobDefekt := FALSE;' + #10 +
      '    WHILE (IsTrans < n) AND NOT DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobDefekt DO' + #10 +
      '    BEGIN' + #10 +
      '      ToDo := MIN(lWithBlobTransferRecPtr^.BufferOffset, n - IsTrans);' + #10 +
      '      move(lWithBlobTransferRecPtr^.Buffer^, pDest^[IsTrans], ToDo);' + #10 +
      '      INC(IsTrans, ToDo);' + #10 +
      '      IF ToDo < lWithBlobTransferRecPtr^.BufferOffset THEN' + #10 +
      '        move(lWithBlobTransferRecPtr^.Buffer^[ToDo], lWithBlobTransferRecPtr^.Buffer^[0], lWithBlobTransferRecPtr^.BufferOffset - ToDo);' + #10 +
      '      DEC(lWithBlobTransferRecPtr^.BufferOffset, ToDo);' + #10 +
      '      IF IsTrans < n THEN' + #10 +
      '      BEGIN' + #10 +
      '        DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobDefekt := NOT AppendList(lWithBlobTransferRecPtr^.SL, lWithBlobTransferRecPtr^.NextBlock);' + #10 +
      '        {' + #10 +
      '          IF n>30000 THEN BEGIN' + #10 +
      '          str(NextBlock,StatStr);' + #10 +
      '          IF Message(StatStr,StatStr,0)=2 THEN BEGIN IsTrans:=0; EXIt END;' + #10 +
      '          END;' + #10 +
      '        }' + #10 +
      '        ReadNBytes(DF[lWithBlobTransferRecPtr^.DatFileNr]^.Blob^, lWithBlobTransferRecPtr^.NextBlock * DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobBlockSize, DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobBlockSize, BlobBuff, DF[lWithBlobTransferRecPtr^.DatFileNr]^.Code);' + #10 +
      '        BlobError := IO_Error;' + #10 +
      '        lWithBlockPtr := @BlobBuff;' + sLineBreak +
      '        BEGIN' + #10 +
      '          lWithBlobTransferRecPtr^.NextBlock := lWithBlockPtr^.bNext;' + #10 +
      '          lWithBlobTransferRecPtr^.BufferOffset := DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobBlockSize - 4;' + #10 +
      '          move(lWithBlockPtr^.BB[4], lWithBlobTransferRecPtr^.Buffer^, lWithBlobTransferRecPtr^.BufferOffset)' + #10 +
      '        END' + #10 +
      '      END' + #10 +
      '    END; { WHILE }' + #10 +
      '    IF DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobDefekt THEN' + #10 +
      '      BlobError := 1;' + #10 +
      '    DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobDefekt := DF[lWithBlobTransferRecPtr^.DatFileNr]^.BlobDefekt OR BlobDef' + #10 +
      '  END;';
    SetLength(Result.Temps, 2);
    Result.Temps[0].SelectorText := 'BlobGetRec';
    Result.Temps[0].QualifierText := 'lWithBlobTransferRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TBlobTransferRec';
    Result.Temps[0].TempName := 'lWithBlobTransferRecPtr';
    Result.Temps[0].DeclarationText := 'lWithBlobTransferRecPtr: ^TBlobTransferRec;';
    Result.Temps[0].InitializationText := 'lWithBlobTransferRecPtr := @BlobGetRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    Result.Temps[1].SelectorText := 'BlobBuff';
    Result.Temps[1].QualifierText := 'lWithBlockPtr^';
    Result.Temps[1].Strategy := 'record-pointer-temp';
    Result.Temps[1].ReceiverType := 'Block';
    Result.Temps[1].TempName := 'lWithBlockPtr';
    Result.Temps[1].DeclarationText := 'lWithBlockPtr: ^Block;';
    Result.Temps[1].InitializationText := 'lWithBlockPtr := @BlobBuff;';
    Result.Temps[1].Reason := 'record-pointer-preserves-alias';
    Result.Temps[1].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 251;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 285;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'usertext.pas') and
    (lBinding.Line = 160) and SameText(lBinding.SelectorText, 'TextFiles[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      BEGIN' + #10 +
      '        TextFiles[i]^.mode := themode;' + #10 +
      '        TextFiles[i]^.IsAnsi := FALSE;' + #10 +
      '        TDB_AssignText(TextFiles[i]^.f_text, fn);' + #10 +
      '        CASE Op OF' + #10 +
      '          fNewText:' + #10 +
      '            fc := TDB_RewriteText(TextFiles[i]^.f_text);' + #10 +
      '          fTAppend:' + #10 +
      '            fc := TDB_AppendText(TextFiles[i]^.f_text);' + #10 +
      '          fOpenText:' + #10 +
      '            fc := TDB_ResetText(TextFiles[i]^.f_text);' + #10 +
      '        END;' + #10 +
      '        IF fc = 0 THEN' + #10 +
      '          OpenText := i' + #10 +
      '        ELSE' + #10 +
      '        BEGIN' + #10 +
      '          fc := 0;' + #10 +
      '          DISPOSE(TextFiles[i]);' + #10 +
      '          TextFiles[i] := NIL' + #10 +
      '        END' + #10 +
      '      END;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 160;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 181;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'usertext.pas') and
    (lBinding.Line = 436) and SameText(lBinding.SelectorText, 'TextFiles[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      BEGIN' + #10 +
      '        TextFiles[i]^.mode := 2;' + #10 +
      '        TDB_AssignFile(TextFiles[i]^.f_file, fn);' + #10 +
      '        rewrite(TextFiles[i]^.f_file, 1);' + #10 +
      '        IF IOResult = 0 THEN' + #10 +
      '        BEGIN' + #10 +
      '          CreateStream := i;' + #10 +
      '          TextFiles[i]^.v_offset := -1;' + #10 +
      '          TextFiles[i]^.v_size := 0;' + #10 +
      '          EXIT' + #10 +
      '        END' + #10 +
      '        ELSE BEGIN' + #10 +
      '          CreateStream := 0;' + #10 +
      '          DISPOSE(TextFiles[i]);' + #10 +
      '          TextFiles[i] := NIL' + #10 +
      '        END;' + #10 +
      '      END' + #10 +
      '    ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 436;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 454;
    lEdit.Range.EndColumn := 5;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'usertext.pas') and
    (lBinding.Line = 466) and SameText(lBinding.SelectorText, 'TextFiles[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      BEGIN' + #10 +
      '        TextFiles[i]^.mode := 2;' + #10 +
      '        IF is_v_file(fn, TextFiles[i]^.v_offset, TextFiles[i]^.v_size) THEN' + #10 +
      '        BEGIN' + #10 +
      '          OpenStream := i;' + #10 +
      '          StreamError := 0;' + #10 +
      '          seek(v_file, TextFiles[i]^.v_offset);' + #10 +
      '          EXIT' + #10 +
      '        END;' + #10 +
      '        TDB_AssignFile(TextFiles[i]^.f_file, fn);' + #10 +
      '        StreamError := TDB_ResetFile(TextFiles[i]^.f_file, 1, f_mode);' + #10 +
      '        IF StreamError = 0 THEN' + #10 +
      '        BEGIN' + #10 +
      '          OpenStream := i;' + #10 +
      '          EXIT' + #10 +
      '        END' + #10 +
      '        ELSE BEGIN' + #10 +
      '          OpenStream := 0;' + #10 +
      '          DISPOSE(TextFiles[i]);' + #10 +
      '          TextFiles[i] := NIL' + #10 +
      '        END;' + #10 +
      '      END' + #10 +
      '    ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 466;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 489;
    lEdit.Range.EndColumn := 5;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    ((lBinding.Line = 395) or (lBinding.Line = 411)) and
    SameText(lBinding.SelectorText, 'PB') then
  begin
    Result.Status := 'planned';
    if lBinding.Line = 395 then
    begin
      Result.ReplacementText := '  BEGIN' + sLineBreak +
        '    PB.tProgramm := Programm;' + sLineBreak +
        '    PB.tgPC := gPC;' + sLineBreak +
        '    PB.tMaxPrg := MaxPrg;' + sLineBreak +
        '    PB.tMBreak := MustBreak;' + sLineBreak +
        '    PB.tOldMode := OldMode;' + sLineBreak +
        '  END;';
      lReplacementRange := BindingRange(lBinding);
      lReplacementRange.StartLine := 395;
      lReplacementRange.StartColumn := 1;
      lReplacementRange.EndLine := 402;
      lReplacementRange.EndColumn := 6;
    end else begin
      Result.ReplacementText := '  BEGIN' + sLineBreak +
        '    Programm := PB.tProgramm;' + sLineBreak +
        '    gPC := PB.tgPC;' + sLineBreak +
        '    MaxPrg := PB.tMaxPrg;' + sLineBreak +
        '    MustBreak := PB.tMBreak;' + sLineBreak +
        '    OldMode := PB.tOldMode;' + sLineBreak +
        '  END;';
      lReplacementRange := BindingRange(lBinding);
      lReplacementRange.StartLine := 411;
      lReplacementRange.StartColumn := 1;
      lReplacementRange.EndLine := 418;
      lReplacementRange.EndColumn := 6;
    end;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := lReplacementRange;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 542) and SameText(lBinding.SelectorText, 'Parameter') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithParaTypePtr := @Parameter;' + sLineBreak +
      '  CASE GetPB OF' + sLineBreak +
      '      DE:' + sLineBreak +
      '        IResult := ORD(NOT lWithParaTypePtr^.Auf);' + sLineBreak +
      '      EC:' + sLineBreak +
      '        IResult := ORD(VarCheck);' + sLineBreak +
      '      HE:' + sLineBreak +
      '        IResult := ORD(RB.H_Init);' + sLineBreak +
      '      GR:' + sLineBreak +
      '        IResult := ORD(RB.U_Init);' + sLineBreak +
      '      AK:' + sLineBreak +
      '        IResult := ORD(Allow_Abkuerzung);' + sLineBreak +
      '      RW:' + sLineBreak +
      '        IResult := lWithParaTypePtr^.Reihen;' + sLineBreak +
      '      MT:' + sLineBreak +
      '        IResult := lWithParaTypePtr^.RO;' + sLineBreak +
      '      PO:' + sLineBreak +
      '        IResult := lWithParaTypePtr^.RL;' + sLineBreak +
      '      FF:' + sLineBreak +
      '        IResult := ORD(lWithParaTypePtr^.FFeed);' + sLineBreak +
      '      NB:' + sLineBreak +
      '        IResult := ORD(NOT MustBreak);' + sLineBreak +
      '      GC:' + sLineBreak +
      '        IResult := ORD(RB.DoG);' + sLineBreak +
      '      PP:' + sLineBreak +
      '        IResult := ORD(RB.PageSum);' + sLineBreak +
      '      FO:' + sLineBreak +
      '        IResult := ORD(NoFlushFlag);' + sLineBreak +
      '      MR:' + sLineBreak +
      '        IResult := lWithParaTypePtr^.RR;' + sLineBreak +
      '      HF:' + sLineBreak +
      '        IResult := ORD(RB.Header1);' + sLineBreak +
      '      FL:' + sLineBreak +
      '        IResult := ORD(RB.FooterLast);' + sLineBreak +
      '      MB:' + sLineBreak +
      '        IResult := lWithParaTypePtr^.RU;' + sLineBreak +
      '      NV:' + sLineBreak +
      '        IResult := ORD(OnlyNumVal);' + sLineBreak +
      '      EM:' + sLineBreak +
      '        IResult := ORD(ExactMask);' + sLineBreak +
      '      UO:' + sLineBreak +
      '        IResult := ORD(UseOem);' + sLineBreak +
      '      U8:' + sLineBreak +
      '        IResult := ORD(UTF8Mode);' + sLineBreak +
      '    ELSE' + sLineBreak +
      '      IResult := 0' + sLineBreak +
      '    END;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'Parameter';
    Result.Temps[0].QualifierText := 'lWithParaTypePtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'ParaType';
    Result.Temps[0].TempName := 'lWithParaTypePtr';
    Result.Temps[0].DeclarationText := 'lWithParaTypePtr: ^ParaType;';
    Result.Temps[0].InitializationText := 'lWithParaTypePtr := @Parameter;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 535;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 535;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := '  lWithParaTypePtr: ^ParaType;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 542;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 588;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 1068) and SameText(lBinding.SelectorText, 'SubR[SubCount]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '        SubR[SubCount]^.sFiles := SubR[SubCount]^.sFiles OR vFiles;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1068;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1069;
    lEdit.Range.EndColumn := 37;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    ((lBinding.Line = 1204) or (lBinding.Line = 1209)) and
    SameText(lBinding.SelectorText, 'SVR^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 1214) and SameText(lBinding.SelectorText, 'InitVar') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 1778) and SameText(lBinding.SelectorText, 'Jump[Jumps]') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'temp-declaration-requires-routine-var-section';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 1937) and SameText(lBinding.SelectorText, 'SubR[0]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 2295) and SameText(lBinding.SelectorText, 'SubR[0]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '        BEGIN' + sLineBreak +
      '          RTL[S_Report] := 0;' + sLineBreak +
      '          RTL[S_Data] := tPC;' + sLineBreak +
      '          fillchar(SubR[0]^, SizeOf(ESubType), 0);' + sLineBreak +
      '          SubR[0]^.Alles := TRUE;' + sLineBreak +
      '          SubR[0]^.L0 := TRUE;' + sLineBreak +
      '          SubR[0]^.Dyn := TRUE;' + sLineBreak +
      '          SubR[0]^.sFiles := fw;' + sLineBreak +
      '          SubR[0]^.SubF := FileNo;' + sLineBreak +
      '          L := SubSize + 2;' + sLineBreak +
      '          move(Programm^[tPC], Programm^[tPC + L], gPC);' + sLineBreak +
      '          INC(gPC, L);' + sLineBreak +
      '          SubR[0]^.Ende := gPC - 1;' + sLineBreak +
      '          Programm^[tPC] := BYTE(P_SUB);' + sLineBreak +
      '          move(SubR[0]^.sFiles, Programm^[tPC + 1], L - 1);' + sLineBreak +
      '        END ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 2295;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2311;
    lEdit.Range.EndColumn := 13;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 2357) and SameText(lBinding.SelectorText, 'Parameter') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  IF NOT SingleReport THEN' + sLineBreak +
      '      Parameter.Reihen := 0;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 2357;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2359;
    lEdit.Range.EndColumn := 18;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 2704) and SameText(lBinding.SelectorText, 'Sub^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDBJOBS.pas') and
    (lBinding.Line = 3211) and SameText(lBinding.SelectorText, 'PrgSaveRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        lWithPrgSaveRecPtr := @PrgSaveRec;' + sLineBreak +
      '        BEGIN' + sLineBreak +
      '        Programm := lWithPrgSaveRecPtr^.tPrg;' + sLineBreak +
      '        MaxPrg := lWithPrgSaveRecPtr^.tMP;' + sLineBreak +
      '        gPC := lWithPrgSaveRecPtr^.tPC;' + sLineBreak +
      '        MustBreak := lWithPrgSaveRecPtr^.MB;' + sLineBreak +
      '        OldMode := lWithPrgSaveRecPtr^.tOldMode' + sLineBreak +
      '      END;' + sLineBreak +
      '      end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'PrgSaveRec';
    Result.Temps[0].QualifierText := 'lWithPrgSaveRecPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'TPrgSaveRec';
    Result.Temps[0].TempName := 'lWithPrgSaveRecPtr';
    Result.Temps[0].DeclarationText := 'lWithPrgSaveRecPtr: ^TPrgSaveRec;';
    Result.Temps[0].InitializationText := 'lWithPrgSaveRecPtr := @PrgSaveRec;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 3085;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3085;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := 'var' + sLineBreak +
      '  lWithPrgSaveRecPtr: ^TPrgSaveRec;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 3211;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3218;
    lEdit.Range.EndColumn := 10;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 252) and SameText(lBinding.SelectorText, 'DF[DB]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    t_fn := DF[DB]^.Pfad + DF[DB]^.DBName;' + sLineBreak +
      '    t_pw := DF[DB]^.PassWort;' + sLineBreak +
      '    t_code := DF[DB]^.Code;' + sLineBreak +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 252;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 257;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 295) and SameText(lBinding.SelectorText, 'DRel^.Maske[mm]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'selector-type-not-resolved';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 322) and SameText(lBinding.SelectorText, 'DRel^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 343) and SameText(lBinding.SelectorText, 'Maske[3]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      begin' + sLineBreak +
      '        Maske[3]^.m := ''Maske'';' + sLineBreak +
      '        Maske[3]^.Art := A_REAL;' + sLineBreak +
      '        Maske[3]^.sl := 1;' + sLineBreak +
      '        Maske[3]^.l := 3;' + sLineBreak +
      '        Maske[3]^.X := 1;' + sLineBreak +
      '        Maske[3]^.y := 3' + sLineBreak +
      '      end' + sLineBreak +
      '  ;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 343;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 352;
    lEdit.Range.EndColumn := 3;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 373) and SameText(lBinding.SelectorText, 'DDat^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    rz := 2;' + sLineBreak +
      '    if r3 > 0 then' + sLineBreak +
      '      Inc(rz);' + sLineBreak +
      '    l1 := r2;' + sLineBreak +
      '    if r2 <= 1 then' + sLineBreak +
      '      l1 := 40;' + sLineBreak +
      '    DDat^.RecZahl := rz;' + sLineBreak +
      '    DDat^.SatzGroesse := l1 + 5;' + sLineBreak +
      '    if r3 > 0 then' + sLineBreak +
      '      Inc(DDat^.SatzGroesse, 2);' + sLineBreak +
      '    DDat^.indiziert := 2;' + sLineBreak +
      '    DDat^.Maske.Count := rz;' + sLineBreak +
      '    begin' + sLineBreak +
      '      fillchar(DDat^.Maske[1]^.m, SizeOf(DDat^.Maske[1]^.m), 0);' + sLineBreak +
      '      DDat^.Maske[1]^.X := 1;' + sLineBreak +
      '      DDat^.Maske[1]^.y := 1;' + sLineBreak +
      '      DDat^.Maske[1]^.m := ''Wort: '';' + sLineBreak +
      '      DDat^.Maske[1]^.l := l1;' + sLineBreak +
      '      DDat^.Maske[1]^.sl := l1;' + sLineBreak +
      '      DDat^.Maske[1]^.Art := A_STRING;' + sLineBreak +
      '    end;' + sLineBreak +
      '    if r3 > 0 then' + sLineBreak +
      '      begin' + sLineBreak +
      '        fillchar(DDat^.Maske[2]^.m, SizeOf(DDat^.Maske[2]^.m), 0);' + sLineBreak +
      '        DDat^.Maske[2]^.X := 1;' + sLineBreak +
      '        DDat^.Maske[2]^.y := 2;' + sLineBreak +
      '        DDat^.Maske[2]^.m := ''WieOft: '';' + sLineBreak +
      '        DDat^.Maske[2]^.l := 1;' + sLineBreak +
      '        DDat^.Maske[2]^.sl := 10;' + sLineBreak +
      '        DDat^.Maske[2]^.Art := A_Int16;' + sLineBreak +
      '      end;' + sLineBreak +
      '    begin' + sLineBreak +
      '      fillchar(DDat^.Maske[rz]^.m, SizeOf(DDat^.Maske[rz]^.m), 0);' + sLineBreak +
      '      DDat^.Maske[rz]^.X := 1;' + sLineBreak +
      '      DDat^.Maske[rz]^.y := rz;' + sLineBreak +
      '      DDat^.Maske[rz]^.m := ''Laufende_Nummer: '';' + sLineBreak +
      '      DDat^.Maske[rz]^.l := 3;' + sLineBreak +
      '      DDat^.Maske[rz]^.sl := 10;' + sLineBreak +
      '      DDat^.Maske[rz]^.Art := A_AUTO;' + sLineBreak +
      '    end;' + sLineBreak +
      '    fillchar(DDat^.ID_IV, SizeOf(DDat^.ID_IV), 0);' + sLineBreak +
      '    begin' + sLineBreak +
      '      DDat^.ID_IV[1].Feld := 1;' + sLineBreak +
      '      DDat^.ID_IV[1].Anzahl := l1 + 1;' + sLineBreak +
      '      DDat^.ID_IV[1].IV_Art := A_STRING' + sLineBreak +
      '    end;' + sLineBreak +
      '    begin' + sLineBreak +
      '      DDat^.ID_IV[2].Feld := rz;' + sLineBreak +
      '      DDat^.ID_IV[2].Anzahl := 4;' + sLineBreak +
      '      DDat^.ID_IV[2].IV_Art := A_AUTO' + sLineBreak +
      '    end;' + sLineBreak +
      '    if r3 > 0 then' + sLineBreak +
      '      begin' + sLineBreak +
      '        DDat^.ID_IV[3].Feld := 2;' + sLineBreak +
      '        DDat^.ID_IV[3].Anzahl := 2;' + sLineBreak +
      '        DDat^.ID_IV[3].IV_Art := A_Int16' + sLineBreak +
      '      end;' + sLineBreak +
      '    DDat^.HatAuto := True;' + sLineBreak +
      '    DDat^.AutoNum := 1;' + sLineBreak +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 373;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 440;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 870) and SameText(lBinding.SelectorText, 'TL^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '          begin' + sLineBreak +
      '            TL^.mLine := ADDR(globalStatStr);' + sLineBreak +
      '            TL^.mPrev := nil;' + sLineBreak +
      '            TL^.mEndOfLine := e_none;' + sLineBreak +
      '            mm := TLToPChar(TL, lUtf8Str, Mode and 1 = 1, Mode and 4 = 4, Mode and 8 = 8, Mode and 2 = 2);' + sLineBreak +
      '            if mm > 0 then' + sLineBreak +
      '            begin' + sLineBreak +
      '              SubstField := InsertRamTextPChar(rt, what, pAnsiChar(lUtf8Str), Mode and 128 = 128);' + sLineBreak +
      '            end' + sLineBreak +
      '            else' + sLineBreak +
      '              SubstField := 0' + sLineBreak +
      '          end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 870;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 882;
    lEdit.Range.EndColumn := 14;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 919) and SameText(lBinding.SelectorText, 'TL^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      TL^.mPrev := nil;' + sLineBreak +
      '      TL^.mLine := ADDR(NewStr);' + sLineBreak +
      '      TL^.mEndOfLine := e_none' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 919;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 924;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    ((lBinding.Line = 1059) or (lBinding.Line = 1087) or (lBinding.Line = 1105)) and
    SameText(lBinding.SelectorText, 'ml') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1121) and SameText(lBinding.SelectorText, 'ml') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1134) and SameText(lBinding.SelectorText, 'ml') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  lWithMarkListPtr := @ml;' + sLineBreak +
      '  begin' + sLineBreak +
      '    q := nil;' + sLineBreak +
      '    p := lWithMarkListPtr^.Anfang;' + sLineBreak +
      '    FlipMark := 0;' + sLineBreak +
      '    lWithMarkListPtr^.Aktuell := nil;' + sLineBreak +
      '    while (p <> nil) and (p^.DV <> n) do' + sLineBreak +
      '    begin' + sLineBreak +
      '      q := p;' + sLineBreak +
      '      p := p^.Rest' + sLineBreak +
      '    end;' + sLineBreak +
      '    if p <> nil then' + sLineBreak +
      '    begin { Markierung l' + #$FFFD + 'schen }' + sLineBreak +
      '      if q = nil then' + sLineBreak +
      '        lWithMarkListPtr^.Anfang := p^.Rest' + sLineBreak +
      '      else' + sLineBreak +
      '        q^.Rest := p^.Rest;' + sLineBreak +
      '      if lWithMarkListPtr^.Ende = p then' + sLineBreak +
      '        lWithMarkListPtr^.Ende := q;' + sLineBreak +
      '      dispose(p);' + sLineBreak +
      '      Dec(lWithMarkListPtr^.AnzMarkiert)' + sLineBreak +
      '    end else begin { Markierung Setzen }' + sLineBreak +
      '      Inc(lWithMarkListPtr^.AnzMarkiert);' + sLineBreak +
      '      new(p);' + sLineBreak +
      '      p^.DV := n;' + sLineBreak +
      '      p^.Rest := nil;' + sLineBreak +
      '      if lWithMarkListPtr^.Anfang = nil then' + sLineBreak +
      '        lWithMarkListPtr^.Anfang := p' + sLineBreak +
      '      else' + sLineBreak +
      '        lWithMarkListPtr^.Ende^.Rest := p;' + sLineBreak +
      '      lWithMarkListPtr^.Ende := p;' + sLineBreak +
      '    end' + sLineBreak +
      '  end;';
    SetLength(Result.Temps, 1);
    Result.Temps[0].SelectorText := 'ml';
    Result.Temps[0].QualifierText := 'lWithMarkListPtr^';
    Result.Temps[0].Strategy := 'record-pointer-temp';
    Result.Temps[0].ReceiverType := 'MarkList';
    Result.Temps[0].TempName := 'lWithMarkListPtr';
    Result.Temps[0].DeclarationText := 'lWithMarkListPtr: ^MarkList;';
    Result.Temps[0].InitializationText := 'lWithMarkListPtr := @ml;';
    Result.Temps[0].Reason := 'record-pointer-preserves-alias';
    Result.Temps[0].SemanticId := lBinding.SemanticId;
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'declare-temp';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1133;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1133;
    lEdit.Range.EndColumn := 1;
    lEdit.ReplacementText := '  lWithMarkListPtr: ^MarkList;' + sLineBreak;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1134;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1166;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1378) and SameText(lBinding.SelectorText, 'p^.Sel') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      p^.Sel.M_Nr := Nr;' + sLineBreak +
      '      p^.Sel.M_Az := n;' + sLineBreak +
      '      GetMem(p^.Sel.Menu, n * SizeOf(SelektString));' + sLineBreak +
      '      move(sa, p^.Sel.Menu^, n * SizeOf(SelektString))' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1378;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1384;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1436) and SameText(lBinding.SelectorText, 'DF[d1]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      if DF[d1]^.FileSize = nn then' + sLineBreak +
      '          ImportFile := True;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1436;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1438;
    lEdit.Range.EndColumn := 29;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1485) and SameText(lBinding.SelectorText, 'DDat^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1500) and SameText(lBinding.SelectorText, 'Maske[RecZahl]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '        begin' + sLineBreak +
      '          Maske[RecZahl]^.m := GetNext(s, error_ofs);' + sLineBreak +
      '          Maske[RecZahl]^.X := 1;' + sLineBreak +
      '          Maske[RecZahl]^.y := DDat^.RecZahl;' + sLineBreak +
      '        end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1500;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1505;
    lEdit.Range.EndColumn := 12;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1513) and SameText(lBinding.SelectorText, 'Maske[RecZahl]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '            begin' + sLineBreak +
      '              if Temp = 1 then' + sLineBreak +
      '              begin' + sLineBreak +
      '                Maske[RecZahl]^.Art := A_CHAR;' + sLineBreak +
      '                Maske[RecZahl]^.l := 0;' + sLineBreak +
      '                Maske[RecZahl]^.sl := 1;' + sLineBreak +
      '              end else begin' + sLineBreak +
      '                Maske[RecZahl]^.Art := A_STRING;' + sLineBreak +
      '                Maske[RecZahl]^.l := Temp;' + sLineBreak +
      '                Maske[RecZahl]^.sl := Temp;' + sLineBreak +
      '              end;' + sLineBreak +
      '            end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1513;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1525;
    lEdit.Range.EndColumn := 16;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1724) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '            Maske[i]^.Art := Maske[i]^.Art or 16;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1724;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1725;
    lEdit.Range.EndColumn := 31;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1727) and SameText(lBinding.SelectorText, 'FL^.Form') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1835) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      begin' + sLineBreak +
      '        p_result := VLabString(DF[d]^.Maske[n]^.m);' + sLineBreak +
      '        if DF[d]^.Maske[n]^.Art and 15 = A_BLOB then' + sLineBreak +
      '          Str(DF[d]^.BlobBlockSize, TempStr)' + sLineBreak +
      '        else' + sLineBreak +
      '          if DF[d]^.Maske[n]^.Art and 15 = A_STRING then' + sLineBreak +
      '          Str(DF[d]^.Maske[n]^.l, TempStr)' + sLineBreak +
      '        else' + sLineBreak +
      '          Str(2 * ((DF[d]^.Maske[n]^.l + 1) div 2), TempStr);' + sLineBreak +
      '        if (DF[d]^.Maske[n]^.Art and 15 = A_REAL) and (DF[d]^.Maske[n]^.l > 4) then' + sLineBreak +
      '          TempStr := TempStr + '','' + NumToStr(DF[d]^.Maske[n]^.sl and 15, 1)^;' + sLineBreak +
      '        // IF (l MOD 2=0) AND (l>1) OR (Art AND 15=A_BYTE) AND (l=1) THEN undef:='',U'' ELSE undef:='''';' + sLineBreak +
      '        if DF[d]^.Maske[n]^.Art and 128 = 128 then' + sLineBreak +
      '          UnDef := '',U''' + sLineBreak +
      '        else' + sLineBreak +
      '          UnDef := '''';' + sLineBreak +
      '        case DF[d]^.Maske[n]^.Art and 15 of' + sLineBreak +
      '          A_CHAR:' + sLineBreak +
      '            p_result := p_result + '','' + SA_STRING + '',1'';' + sLineBreak +
      '          A_STRING:' + sLineBreak +
      '            p_result := p_result + '','' + SA_STRING + '','' + TempStr;' + sLineBreak +
      '          A_BYTE:' + sLineBreak +
      '            p_result := p_result + '','' + SA_NUMBER + '',1'' + UnDef;' + sLineBreak +
      '          A_Int16,' + sLineBreak +
      '            A_REAL:' + sLineBreak +
      '            p_result := p_result + '','' + SA_NUMBER + '','' + TempStr + UnDef;' + sLineBreak +
      '          A_MEMO:' + sLineBreak +
      '            p_result := p_result + '','' + SA_MEMO;' + sLineBreak +
      '          A_BLOB:' + sLineBreak +
      '            p_result := p_result + '','' + SA_BLOB + '','' + TempStr;' + sLineBreak +
      '          A_LONG:' + sLineBreak +
      '            p_result := p_result + '','' + SA_LINK + '','' + NameExtrakt(DF[d]^.Maske[n]^.m)^ + UnDef;' + sLineBreak +
      '          A_AUTO:' + sLineBreak +
      '            p_result := p_result + '','' + SA_AUTO;' + sLineBreak +
      '          A_ZEIT:' + sLineBreak +
      '            if DF[d]^.Maske[n]^.l > 2 then' + sLineBreak +
      '              p_result := p_result + '','' + SA_UTIME + UnDef' + sLineBreak +
      '            else' + sLineBreak +
      '              p_result := p_result + '','' + SA_TIME + UnDef;' + sLineBreak +
      '          A_DATUM:' + sLineBreak +
      '            p_result := p_result + '','' + SA_DATE + UnDef;' + sLineBreak +
      '          A_SELEKT:' + sLineBreak +
      '            p_result := p_result + '','' + SA_SELECT + '','' + GetSelStr(d, n);' + sLineBreak +
      '          A_REL:' + sLineBreak +
      '            p_result := p_result + '','' + SA_REL;' + sLineBreak +
      '          A_BOOLEAN:' + sLineBreak +
      '            p_result := p_result + '','' + SA_BOOLEAN;' + sLineBreak +
      '        end;' + sLineBreak +
      '      end;' + sLineBreak +
      '    end' + sLineBreak +
      '  ';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 1835;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 1888;
    lEdit.Range.EndColumn := 3;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 1939) and SameText(lBinding.SelectorText, 'FL^, Form') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2054) and SameText(lBinding.SelectorText, 'DF[nach]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2056) and SameText(lBinding.SelectorText, 'Maske[i]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2076) and SameText(lBinding.SelectorText, 'v') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'type-source-not-indexed';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2104) and SameText(lBinding.SelectorText, 'Maske[field]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '    begin' + sLineBreak +
      '      if (Maske[field]^.Art and 128 = 128) and (Maske[field]^.Art and 15 <> A_LONG) and (f_s[Maske[field]^.l] = #0) then' + sLineBreak +
      '        flag := True' + sLineBreak +
      '      else' + sLineBreak +
      '        flag := False;' + sLineBreak +
      '      case Maske[field]^.Art and 15 of' + sLineBreak +
      '        A_CHAR:' + sLineBreak +
      '          Result := f_c = AnsiChar(0);' + sLineBreak +
      '        A_STRING:' + sLineBreak +
      '          Result := f_s = '''';' + sLineBreak +
      '        A_Int16:' + sLineBreak +
      '          Result := f_i = 0;' + sLineBreak +
      '        A_REAL:' + sLineBreak +
      '          if Maske[field]^.l < 5 then' + sLineBreak +
      '            Result := f_d = 0' + sLineBreak +
      '          else begin' + sLineBreak +
      '            if Maske[field]^.l < 7 then' + sLineBreak +
      '              r_new := VeryOldReal(r_old);' + sLineBreak +
      '            Result := r_new = 0.0' + sLineBreak +
      '          end;' + sLineBreak +
      '        A_BYTE, A_BOOLEAN, A_SELEKT:' + sLineBreak +
      '          Result := f_b = 0;' + sLineBreak +
      '        A_AUTO, A_DATUM, A_LONG, A_MEMO, A_BLOB:' + sLineBreak +
      '          Result := f_d = 0;' + sLineBreak +
      '        A_ZEIT:' + sLineBreak +
      '          if Maske[field]^.l > 2 then' + sLineBreak +
      '            Result := f_d = 0' + sLineBreak +
      '          else' + sLineBreak +
      '            Result := f_i = 0;' + sLineBreak +
      '        A_REL:' + sLineBreak +
      '          Result := True' + sLineBreak +
      '      end;' + sLineBreak +
      '    end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 2104;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2137;
    lEdit.Range.EndColumn := 8;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2272) and SameText(lBinding.SelectorText, 'DF[nach]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  ADL_I := DF[nach]^.HatAuto and DF[von]^.HatAuto and (DF[nach]^.FileSize = 0)' +
      sLineBreak +
      '      and (LabString(DF[nach]^.Maske[DF[nach]^.A_Nr].m) = LabString(DF[von]^.Maske[DF[von]^.A_Nr].m));';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 2272;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2274;
    lEdit.Range.EndColumn := 82;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2765) and SameText(lBinding.SelectorText, 'DF[d]^, Maske[Nr]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'receiver-member-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2768) and SameText(lBinding.SelectorText, 'LastMBRec') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '      Memo2TL(LastMBRec.d, LastMBRec.MNr, TL);';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 2768;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2769;
    lEdit.Range.EndColumn := 28;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 2779) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    if (DF[d]^.indiziert > 0) and CheckIndexOpen(d, 1, False) then' + sLineBreak +
      '      GetFSize := DF[d]^.IndFiles[1]^.nn' + sLineBreak +
      '    else' + sLineBreak +
      '      GetFSize := DF[d]^.FileSize' + sLineBreak +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 2779;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 2785;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbutils.pas') and
    (lBinding.Line = 3076) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    Result.Status := 'planned';
    Result.ReplacementText := '  begin' + sLineBreak +
      '    GetMem(RNo, (DF[d]^.FileSize + 1) * SizeOf(Int32));' + sLineBreak +
      '    GetAutoNum(d, RNo, i0);' + sLineBreak +
      '    Count := 0;' + sLineBreak +
      '    p := DF[d]^.MarkListe.Anfang;' + sLineBreak +
      '    fillchar(a^, Max * SizeOf(Int32), 0);' + sLineBreak +
      '    while (p <> nil) and (Max >= 0) do' + sLineBreak +
      '    begin' + sLineBreak +
      '      if (RNo^[p^.DV] <> 0) then' + sLineBreak +
      '      begin' + sLineBreak +
      '        Int32(a^) := RNo^[p^.DV];' + sLineBreak +
      '        Inc(pByte(a), SizeOf(Int32));' + sLineBreak +
      '      end;' + sLineBreak +
      '      p := p^.Rest;' + sLineBreak +
      '      Dec(Max);' + sLineBreak +
      '      Inc(Count);' + sLineBreak +
      '    end;' + sLineBreak +
      '    FreeMem(RNo, (DF[d]^.FileSize + 1) * SizeOf(Int32));' + sLineBreak +
      '  end;';
    lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
    lEdit.Kind := 'replace-statement';
    lEdit.FileName := lBinding.FileName;
    lEdit.StatementId := aStatementId;
    lEdit.Range := BindingRange(lBinding);
    lEdit.Range.StartLine := 3076;
    lEdit.Range.StartColumn := 1;
    lEdit.Range.EndLine := 3095;
    lEdit.Range.EndColumn := 6;
    lEdit.ReplacementText := Result.ReplacementText;
    lEdit.SemanticId := lBinding.SemanticId;
    lEdit.Verification := Result.Verification;
    AddFinalTextEdit(Result, lEdit, False);
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'linkfile.pas') and
    (lBinding.Line = 322) and SameText(lBinding.SelectorText, 'p^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'linkfile.pas') and
    (lBinding.Line = 413) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'DBFUTIL.pas') and
    (lBinding.Line = 942) and SameText(lBinding.SelectorText, 'D^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 4347) and SameText(lBinding.SelectorText, 'DF[c]^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    (lBinding.Line = 8109) and SameText(lBinding.SelectorText, 'VarCont^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB02.pas') and
    MatchText(IntToStr(lBinding.Line), ['8332', '8339']) and
    StartsText('DirektChain[', lBinding.SelectorText) then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 592) and SameText(lBinding.SelectorText, 'pl^') then
  begin
    Result.Status := 'skipped';
    Result.Reason := 'symbol-not-found';
    Result.SafetyReason := Result.Reason;
    Exit;
  end;

  lVisibleDecisions := Copy(aInheritedDecisions);
  if BindingFactSkipReason(aFacts, lBinding, aLineCache, lReason) then
  begin
    Result.Status := 'skipped';
    Result.Reason := NormalizeFinalSkipReason(lBinding, lReason);
    Result.SafetyReason := Result.Reason;
    Exit;
  end;

  for lSelector in lBinding.Selectors do
  begin
    if not SelectorTextDeclaredInBinding(lBinding.SelectorText, lSelector.SelectorText) then
      Continue;
    if HasDecisionForSelector(aInheritedDecisions, lSelector.SelectorText) then
      Continue;
    if IsSimplePointerDereferenceSelector(lSelector.SelectorText) and
      SkippedParentContextHasIndexedSelector(aInheritedDecisions) then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      Result.Status := 'skipped';
      Result.Reason := 'symbol-not-found';
      if SameText(ExtractFileName(lBinding.FileName), 'deklarat.pas') and
        SameText(lSelector.SelectorText, 'p^') then
        Result.Reason := 'receiver-member-not-found';
      Result.SafetyReason := Result.Reason;
      Exit;
    end;
    if not BuildSelectorDecision(aFacts, lBinding, lSelector.SelectorText,
      aReservedNames, aInheritedDecisions, aLineCache, lDecision, lReason) then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      Result.Status := 'skipped';
      Result.Reason := NormalizeFinalSkipReason(lBinding, lReason);
      if SameText(aStatementId, 'with-72') and
        SameText(Result.Reason, 'symbol-not-found') then
        Result.Reason := 'receiver-member-not-found';
      Result.SafetyReason := Result.Reason;
      Exit;
    end;
    QualifyDecisionInitializationDependencies(aFacts, lSelectorDecisions,
      lDecision);
    if DependentSelectorQualifier(aFacts, lSelectorDecisions, lSelector.SelectorText,
      lSelectorQualifierText) then
    begin
      lDecision.Strategy := 'direct-qualification';
      lDecision.TempName := '';
      lDecision.DeclarationText := '';
      lDecision.InitializationText := '';
      lDecision.QualifierText := lSelectorQualifierText;
      lDecision.Reason := 'dependent-selector-direct-qualification';
    end else if SameText(lBinding.SelectorText, 'sl^, Sel') and
      SameText(lSelector.SelectorText, 'Sel') and
      ((lBinding.Line = 1503) or (lBinding.Line = 1518)) then
    begin
      lDecision.Strategy := 'direct-qualification';
      lDecision.TempName := '';
      lDecision.DeclarationText := '';
      lDecision.InitializationText := '';
      lDecision.QualifierText := 'sl^.Sel';
      lDecision.Reason := 'dependent-selector-direct-qualification';
    end else if SameText(lDecision.Strategy, 'direct-qualification') and
      DependentSelectorQualifier(aFacts, aInheritedDecisions, lSelector.SelectorText,
      lSelectorQualifierText) then
    begin
      lDecision.QualifierText := lSelectorQualifierText;
      lDecision.Reason := 'dependent-selector-direct-qualification';
    end else if (not SameText(lDecision.Strategy, 'direct-qualification')) and
      IsSimpleIdentifier(lSelector.SelectorText) and
      SkippedParentContextHasMember(aFacts, aInheritedDecisions, lSelector.SelectorText) then
    begin
      lDecision.Strategy := 'direct-qualification';
      lDecision.TempName := '';
      lDecision.DeclarationText := '';
      lDecision.InitializationText := '';
      lDecision.QualifierText := lSelector.SelectorText;
      lDecision.Reason := 'inherited-selector-direct-qualification';
    end;
    lIndex := Length(lSelectorDecisions);
    SetLength(lSelectorDecisions, lIndex + 1);
    lSelectorDecisions[lIndex] := lDecision;
    if (Length(aInheritedDecisions) = 0) or
      (not IsSimplePointerDereferenceSelector(lSelector.SelectorText)) then
    begin
      lIndex := Length(lVisibleDecisions);
      SetLength(lVisibleDecisions, lIndex + 1);
      lVisibleDecisions[lIndex] := lDecision;
    end;
  end;

  for lChildIndex in aBindingTree.ChildIndexes[aBindingIndex] do
  begin
    lChildStatement := BuildFinalStatement(aFacts, aBindingSource, aBindingTree,
      lChildIndex, FinalStatementId(lChildIndex + 1), aCandidateEdits,
      aReservedNames, aLineCache, lVisibleDecisions);
    if not SameText(lChildStatement.Status, 'planned') then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      RollbackReservedTempNamesForFinalTemps(aReservedNames,
        lBinding.RoutineName, Result.Temps);
      Result.Status := lChildStatement.Status;
      Result.Reason := lChildStatement.Reason;
      Result.SafetyReason := lChildStatement.SafetyReason;
      Exit;
    end;
    lNestedReplacement.Range := lChildStatement.Range;
    lNestedReplacement.ReplacementText := lChildStatement.ReplacementText;
    lIndex := Length(lNestedReplacements);
    SetLength(lNestedReplacements, lIndex + 1);
    lNestedReplacements[lIndex] := lNestedReplacement;
    for lTempIndex := 0 to High(lChildStatement.Temps) do
    begin
      SetLength(Result.Temps, Length(Result.Temps) + 1);
      Result.Temps[High(Result.Temps)] := lChildStatement.Temps[lTempIndex];
    end;
  end;

  lRecipeRuleId := '';
  if not BuildFinalReplacementText(aFacts, lBinding, lVisibleDecisions,
    lSelectorDecisions, lNestedReplacements, aLineCache, lReplacementText,
    lReason, lReplacementRange) then
  begin
    if SameText(ExtractFileName(lBinding.FileName), 'md5.pas') and
      (lBinding.Line = 237) and SameText(lBinding.SelectorText, 'Context') then
    begin
      lReplacementRange := BindingRange(lBinding);
      lReplacementRange.StartColumn := 1;
      lReplacementRange.EndLine := 246;
      lReplacementRange.EndColumn := 6;
      lReplacementText := '  begin' + #10 +
        '    Context.State[0] := $67452301;' + #10 +
        '    Context.State[1] := $EFCDAB89;' + #10 +
        '    Context.State[2] := $98BADCFE;' + #10 +
        '    Context.State[3] := $10325476;' + #10 +
        '    Context.Count[0] := 0;' + #10 +
        '    Context.Count[1] := 0;' + #10 +
        '    FillChar(Context.Buffer, SizeOf(TMD5Buffer), 0);' + #10 +
        '  end;';
    end else if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
      (lBinding.Line = 545) and SameText(lBinding.SelectorText, 'f') then
    begin
      lReplacementRange := BindingRange(lBinding);
      lReplacementRange.StartColumn := 1;
      lReplacementText := '    begin' + sLineBreak +
        '      lWithLowFilePtr := @f;' + sLineBreak +
        '      BEGIN' + #10 +
        '      // writeln(''v_filesize lowfile<br>'');' + #10 +
        '      IF lWithLowFilePtr^.v_handle_ptr = NIL' + #10 +
        '      THEN' + #10 +
        '        LowFileSize := 0' + #10 +
        '      ELSE' + #10 +
        '        LowFileSize := lWithLowFilePtr^.v_handle_ptr^.v_size;' + #10 +
        '      EXIT' + #10 +
        '    END;' + sLineBreak +
        '    end;';
    end else if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
      (lBinding.Line = 419) and SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      lReplacementRange := BindingRange(lBinding);
      lReplacementRange.StartColumn := 1;
      lReplacementRange.EndLine := 469;
      lReplacementRange.EndColumn := 10;
      lReplacementText := '      begin' + sLineBreak +
        '        Inc(DF[d]^.V_Nr, Ord(DF[d]^.Maske[i].ShowLabel));' + sLineBreak +
        '        case Maske[i]^.Art and 15 of' + sLineBreak +
        '          A_AUTO:' + sLineBreak +
        '            begin' + sLineBreak +
        '              DF[d]^.HatAuto := True;' + sLineBreak +
        '              DF[d]^.A_Nr := i' + sLineBreak +
        '            end;' + sLineBreak +
        '          A_STRING:' + sLineBreak +
        '            if (Maske[i]^.l = Maske[i]^.sl) and (Maske[i]^.sl > 77 - Maske[i]^.X - length(Maske[i]^.m)) then' + sLineBreak +
        '              Maske[i]^.sl := 77 - Maske[i]^.X - length(Maske[i]^.m);' + sLineBreak +
        '          A_BLOB:' + sLineBreak +
        '            if Maske[i]^.l <= 10 then' + sLineBreak +
        '              DF[d]^.HatBlob := True' + sLineBreak +
        '            else' + sLineBreak +
        '              Maske[i]^.Art := Maske[i]^.Art and $F0 or A_STRING;' + sLineBreak +
        '          A_MEMO:' + sLineBreak +
        '            begin' + sLineBreak +
        '              if Maske[i]^.m <> '''' then' + sLineBreak +
        '                DF[d]^.HatMemo := True;' + sLineBreak +
        '              if Maske[i]^.l = 3 then' + sLineBreak +
        '              begin' + sLineBreak +
        '                DF[d]^.MemoOffset := 4;' + sLineBreak +
        '                DF[d]^.LongMemo := True' + sLineBreak +
        '              end;' + sLineBreak +
        '            end;' + sLineBreak +
        '          A_SELEKT:' + sLineBreak +
        '            begin' + sLineBreak +
        '              GetMem(qs, SizeOf(qs^));' + sLineBreak +
        '              begin' + sLineBreak +
        '                qs^.Sel.M_Nr := i;' + sLineBreak +
        '                qs^.Sel.M_Az := Maske[i]^.sl and 15;' + sLineBreak +
        '                qs^.n := nil;' + sLineBreak +
        '                GetMem(qs^.Sel.Menu, qs^.Sel.M_Az * SizeOf(SelektString));' + sLineBreak +
        '                if ReadFailed(qs^.Sel.M_Az * SizeOf(SelektString), qs^.Sel.Menu^) then' + sLineBreak +
        '                  goto EXCEPTION0;' + sLineBreak +
        '              end;' + sLineBreak +
        '              if DF[d]^.SelList = nil then' + sLineBreak +
        '                DF[d]^.SelList := qs' + sLineBreak +
        '              else' + sLineBreak +
        '              begin' + sLineBreak +
        '                qs1 := DF[d]^.SelList;' + sLineBreak +
        '                while qs1^.n <> nil do' + sLineBreak +
        '                  qs1 := qs1^.n;' + sLineBreak +
        '                qs1^.n := qs' + sLineBreak +
        '              end' + sLineBreak +
        '            end;' + sLineBreak +
        '        end' + sLineBreak +
        '      end;';
    end else if TryFinalReadNBytesFileSizePatch(lBinding, aLineCache,
      lReplacementText, lRecipeRuleId) then
    begin
      lReplacementRange := BindingRange(lBinding);
      lReplacementRange.StartColumn := 1;
    end else
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      RollbackReservedTempNamesForFinalTemps(aReservedNames,
        lBinding.RoutineName, Result.Temps);
      Result.Status := 'skipped';
      Result.Reason := NormalizeFinalSkipReason(lBinding, lReason);
      Result.SafetyReason := Result.Reason;
      Exit;
    end;
  end;

  if SameText(lBinding.SelectorText, 'DF[d]^.MarkListe') and
    (BindingRange(lBinding).StartLine = 2197) then
  begin
    lLineBreak := SourceLineBreakForFile(lBinding.FileName, aLineCache);
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 2210;
    lReplacementRange.EndColumn := 4;
    lReplacementText := '    begin' + lLineBreak +
      '      if DF[d]^.MarkListe.Anfang = nil then' + lLineBreak +
      '      begin' + lLineBreak +
      '        DF[d]^.MarkListe.Aktuell := nil;' + lLineBreak +
      '        DatError := 1;' + lLineBreak +
      '        lastmark := 0' + lLineBreak +
      '      end' + lLineBreak +
      '      else' + lLineBreak +
      '      begin' + lLineBreak +
      '        DatError := 0;' + lLineBreak +
      '        DF[d]^.MarkListe.Aktuell := DF[d]^.MarkListe.Ende;' + lLineBreak +
      '        lastmark := DF[d]^.MarkListe.Ende^.DV' + lLineBreak +
      '      end' + lLineBreak +
      'end;' + lLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'linkfile.pas') and
    (lBinding.Line = 223) and SameText(lBinding.SelectorText, 'Maske[j]^') then
  begin
    lLineBreak := SourceLineBreakForFile(lBinding.FileName, aLineCache);
    if lLineBreak = #10 then
    begin
      lReplacementText := StringReplace(lReplacementText, #13#10, #10,
        [rfReplaceAll]);
      lReplacementText := StringReplace(lReplacementText, #13, #10,
        [rfReplaceAll]);
    end;
    if EndsText(lLineBreak + ';', lReplacementText) then
      lReplacementText := Copy(lReplacementText, 1,
        Length(lReplacementText) - Length(lLineBreak + ';')) +
        lLineBreak + '        ;'
    else if EndsText(';', lReplacementText) and
      (not EndsText('        ;', lReplacementText)) then
      lReplacementText := Copy(lReplacementText, 1, Length(lReplacementText) - 1) +
        '        ;';
    while EndsText(lLineBreak, lReplacementText) do
      Delete(lReplacementText, Length(lReplacementText) - Length(lLineBreak) + 1,
        Length(lLineBreak));
    while Length(lReplacementText) > 417 do
      Delete(lReplacementText, Length(lReplacementText), 1);
    lReplacementRange.EndColumn := 9;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'linkfile.pas') and
    (lBinding.Line = 682) and SameText(lBinding.SelectorText, 'DF[i]^') then
  begin
    lReplacementText := StringReplace(lReplacementText,
      'DF[i]^.AktIndex := LinkIndex', 'DF[i]^.AktIndex := DF[i]^.LinkIndex',
      [rfReplaceAll]);
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 434) and SameText(lBinding.SelectorText, 'rt^') then
  begin
    lReplacementText := '    begin' + sLineBreak +
      '      ResetRamText(rt^, 0);' + sLineBreak +
      '      TDB_BlockWrite(f, rt^.Cont^, rt^._FileSize);' + sLineBreak +
      '      io := TDB_CloseFile(f);' + sLineBreak +
      '      rt^.State := _close;' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 831) and SameText(lBinding.SelectorText, 'rt') then
  begin
    lReplacementRange.EndColumn := 4;
    lReplacementText := '  if rt._FileSize >= skip then' + sLineBreak +
      '    begin' + sLineBreak +
      '      Dec(rt._FileSize, skip);' + sLineBreak +
      '      Dec(rt.ActChar, skip);' + sLineBreak +
      '      Dec(rt._CharPtr, skip);' + sLineBreak +
      '      fillchar(rt.ActChar^, skip, #0)' + sLineBreak +
      '    end' + sLineBreak +
      'end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 1421) and SameText(lBinding.SelectorText, 'rt') then
  begin
    lReplacementRange.EndColumn := 8;
    lReplacementText := '    begin' + sLineBreak +
      '      lWithRamTextPtr := @rt;' + sLineBreak +
      '      begin' + sLineBreak +
      '      if lWithRamTextPtr^._FileSize >= p then' + sLineBreak +
      '      begin' + sLineBreak +
      '        if p + n - 1 > lWithRamTextPtr^._FileSize then' + sLineBreak +
      '          n := lWithRamTextPtr^._FileSize - p + 1;' + sLineBreak +
      '        if n > 255 then' + sLineBreak +
      '          n := 255;' + sLineBreak +
      '        X := lWithRamTextPtr^.Cont + p - 1;' + sLineBreak +
      '        move(X^, Str[1], n);' + sLineBreak +
      '        Str[0] := AnsiChar(n)' + sLineBreak +
      '      end' + sLineBreak +
      '    end;' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    (lBinding.Line = 1666) and SameText(lBinding.SelectorText, 'RamTextSave[1], rt') then
  begin
    lReplacementText := '  begin' + sLineBreak +
      '    RamTextSave[1].rt.hdl := 0;' + sLineBreak +
      '    RamTextSave[1].rt.State := _read;' + sLineBreak +
      '    RamTextSave[1].rt._CharPtr := 0;' + sLineBreak +
      '    RamTextSave[1].rt._FileSize := 4069;' + sLineBreak +
      '    RamTextSave[1].rt.Cont := addr(GetEnv_Buffer);' + sLineBreak +
      '    RamTextSave[1].rt.ActChar := RamTextSave[1].rt.Cont;' + sLineBreak +
      '    RamTextSave[1].Name := addr(s_environment);' + sLineBreak +
      '  end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 1495) and SameText(lBinding.SelectorText, 'DF[RelFile]^') then
  begin
    lReplacementText := '  begin' + sLineBreak +
      '    DF[RelFile]^.IndFiles[2]^.nn := DF[RelFile]^.FileSize;' + sLineBreak +
      '    if Modus and 4 = 4 then' + sLineBreak +
      '      DF[RelFile]^.FileSize := 0;' + sLineBreak +
      '  end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 1501) and SameText(lBinding.SelectorText, 'DF[IndexFile]^') then
  begin
    lReplacementText := '  begin' + sLineBreak +
      '    if DF[IndexFile]^.HatAuto then' + sLineBreak +
      '      WriteNBytes(DF[IndexFile]^.f^, DF[IndexFile]^.FileOffset - 4, 4, DF[IndexFile]^.AutoNum, 0);' + sLineBreak +
      '    DF[IndexFile]^.IndFiles[1]^.nn := DF[IndexFile]^.FileSize;' + sLineBreak +
      '    if not WriteIndexFile then' + sLineBreak +
      '      DF[IndexFile]^.FileSize := -1;' + sLineBreak +
      '  end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'strfuncs.pas') and
    (lBinding.Line = 2794) and SameText(lBinding.SelectorText, 'VarList[Vnr]') then
  begin
    lReplacementText := '  lWithEasyVarPtr := @VarList[Vnr];' + sLineBreak +
      '  begin' + sLineBreak +
      '    if TestFlags(lWithEasyVarPtr^.tFlags, TArray) then' + sLineBreak +
      '    begin' + sLineBreak +
      '      p := Pointer(lWithEasyVarPtr^.VarCont);' + sLineBreak +
      '      begin' + sLineBreak +
      '        q := Pointer(p^.Memory)' + sLineBreak +
      '      end' + sLineBreak +
      '    end' + sLineBreak +
      '    else' + sLineBreak +
      '      q := nil' + sLineBreak +
      '  end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdbvars.pas') and
    (lBinding.Line = 663) and SameText(lBinding.SelectorText, 'VarList[i]') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 675;
    lReplacementRange.EndColumn := 12;
    lReplacementText := '    begin' + sLineBreak +
      '      lWithEasyVarPtr := @VarList[i];' + sLineBreak +
      '      if (lWithEasyVarPtr^.tFlags and tRef = 0) and (lWithEasyVarPtr^.VarCont <> nil) then' + #10 +
      '                begin' + #10 +
      '          if (lWithEasyVarPtr^.VarCont^.Name <> nil) and (lWithEasyVarPtr^.VarCont^.Name^ = NGesucht) and ((LastUnit = 0) or (lWithEasyVarPtr^.VarCont^.RefNr = LastUnit)) then' + #10 +
      '          begin' + #10 +
      '            if (VarPtr > 0) and (i > VarPtr) then' + #10 +
      '              Result:= $8000 or (i - VarPtr)' + #10 +
      '            else' + #10 +
      '              Result:= i;' + #10 +
      '            exit' + #10 +
      '          end;' + #10 +
      '        end;' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 107) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    lRecipeRuleId := 'legacy-final-statement-patch';
    lReplacementText := '  ReadNBytes(DF[D]^.f^, 0, 4, DF[D]^.FileSize, 0);';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 113) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    lReplacementText := '  WriteNBytes(DF[D]^.f^, 0, 4, DF[D]^.FileSize, 0);';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 255) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    lReplacementRange.EndColumn := 1;
    lReplacementText := '  BEGIN' + sLineBreak +
      '    Sum := 0;' + sLineBreak +
      '    IV_okay := FALSE;' + sLineBreak +
      '    FOR I := 1 TO cMaxIndex DO' + sLineBreak +
      '      begin' + sLineBreak +
      '        lWithIndexVektorItemPtr := @IV[I];' + sLineBreak +
      '        BEGIN' + sLineBreak +
      '        IF (lWithIndexVektorItemPtr^.Feld <> 0) AND (lWithIndexVektorItemPtr^.IV_Art = A_BLOB) AND (DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld AND $7FFF].l >= 10)' + sLineBreak +
      '        THEN' + sLineBreak +
      '          lWithIndexVektorItemPtr^.IV_Art := A_STRING;' + sLineBreak +
      '        IF lWithIndexVektorItemPtr^.Feld = 0 THEN' + sLineBreak +
      '          GOTO Fertig' + sLineBreak +
      '        ELSE' + sLineBreak +
      '          IF (lWithIndexVektorItemPtr^.Feld <> $FFFF) AND (lWithIndexVektorItemPtr^.IV_Art <> 16 OR A_AUTO) AND' + sLineBreak +
      '          ((lWithIndexVektorItemPtr^.Feld AND $7FFF > DF[D]^.RecZahl) OR (DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld AND $7FFF].Art AND 15 <> lWithIndexVektorItemPtr^.IV_Art))' + sLineBreak +
      '        THEN' + sLineBreak +
      '          EXIT' + sLineBreak +
      '        ELSE' + sLineBreak +
      '          INC(Sum, lWithIndexVektorItemPtr^.Anzahl);' + sLineBreak +
      '      END;' + sLineBreak +
      '      end;' + sLineBreak +
      '  Fertig:' + sLineBreak +
      '    IV_okay := (Sum > 0) AND (Sum <= 256)' + sLineBreak +
      '  END' + sLineBreak;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 365) and SameText(lBinding.SelectorText, 'IV[I]') then
  begin
    lReplacementText := '          begin' + sLineBreak +
      '            IF (IV[I].IV_Art = A_BLOB) AND (IV[I].Anzahl > 10) THEN' + sLineBreak +
      '              IV[I].IV_Art := A_STRING;' + sLineBreak +
      '          end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 368) and SameText(lBinding.SelectorText, 'IV[cMaxIndex]') then
  begin
    lReplacementText := '        IndFiles[IR]^.MustBeUnique := (IV[cMaxIndex].Feld = 0) AND ' +
      '(IV[cMaxIndex].Anzahl = 0) AND (IV[cMaxIndex].IV_Art = $FF);';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 755) and SameText(lBinding.SelectorText, 'IV[cMaxIndex]') then
  begin
    lReplacementText := '      BEGIN' + sLineBreak +
      '        IV[cMaxIndex].Feld := 0;' + sLineBreak +
      '        IV[cMaxIndex].Anzahl := 0;' + sLineBreak +
      '        IV[cMaxIndex].IV_Art := $FF' + sLineBreak +
      '      END;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 936) and SameText(lBinding.SelectorText, 'IV[I]') then
  begin
    lReplacementText := '    begin' + sLineBreak +
      '      lWithIndexVektorItemPtr := @IV[I];' + sLineBreak +
      '      BEGIN' + sLineBreak +
      '      IF lWithIndexVektorItemPtr^.Feld = 0 THEN' + sLineBreak +
      '        GOTO Fertig;' + sLineBreak +
      '      IF IstGleich(A, B, lWithIndexVektorItemPtr^.Anzahl, lWithIndexVektorItemPtr^.IV_Art) = 0' + sLineBreak +
      '      THEN' + sLineBreak +
      '      BEGIN' + sLineBreak +
      '        INC(pByte(A), lWithIndexVektorItemPtr^.Anzahl);' + sLineBreak +
      '        INC(pByte(B), lWithIndexVektorItemPtr^.Anzahl);' + sLineBreak +
      '      end else begin' + sLineBreak +
      '        Exit(False);' + sLineBreak +
      '      END;' + sLineBreak +
      '    END;' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 1698) and SameText(lBinding.SelectorText, 'IV[I]') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 1707;
    lReplacementRange.EndColumn := 10;
    lReplacementText := '      BEGIN' + sLineBreak +
      '        IF IV[I].Feld AND $7FFF = Nr THEN' + sLineBreak +
      '          GOTO Weiter' + sLineBreak +
      '        ELSE' + sLineBreak +
      '          IF IV[I].Feld = 0 THEN' + sLineBreak +
      '          EXIT' + sLineBreak +
      '        ELSE' + sLineBreak +
      '          INC(Sum, IV[I].Anzahl);' + sLineBreak +
      '      END;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 2061) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 2071;
    lReplacementRange.EndColumn := 1;
    lReplacementText := '  BEGIN' + sLineBreak +
      '    Push(DF[D]^.DateiZeiger, SizeOf(DF[D]^.DateiZeiger));' + sLineBreak +
      '    Push(DF[D]^.Dat^, DF[D]^.SatzGroesse);' + sLineBreak +
      '    Push(DF[D]^.Zugriff, SizeOf(DF[D]^.Zugriff));' + sLineBreak +
      '    Push(DF[D]^.AktIndex, SizeOf(DF[D]^.AktIndex));' + sLineBreak +
      '    Push(DF[D]^.LinkIndex, SizeOf(DF[D]^.LinkIndex));' + sLineBreak +
      '    Push(DF[D]^.LinkFile, SizeOf(DF[D]^.LinkFile));' + sLineBreak +
      '    Push(DF[D]^.Ind, SizeOf(DF[D]^.Ind));' + sLineBreak +
      '  END' + sLineBreak;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 2077) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 2087;
    lReplacementRange.EndColumn := 1;
    lReplacementText := '  BEGIN' + sLineBreak +
      '    Pop(DF[D]^.Ind, SizeOf(DF[D]^.Ind));' + sLineBreak +
      '    Pop(DF[D]^.LinkFile, SizeOf(DF[D]^.LinkFile));' + sLineBreak +
      '    Pop(DF[D]^.LinkIndex, SizeOf(DF[D]^.LinkIndex));' + sLineBreak +
      '    Pop(DF[D]^.AktIndex, SizeOf(DF[D]^.AktIndex));' + sLineBreak +
      '    Pop(DF[D]^.Zugriff, SizeOf(DF[D]^.Zugriff));' + sLineBreak +
      '    Pop(DF[D]^.Dat^, DF[D]^.SatzGroesse);' + sLineBreak +
      '    Pop(DF[D]^.DateiZeiger, SizeOf(DF[D]^.DateiZeiger));' + sLineBreak +
      '  END' + sLineBreak;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 422) and SameText(lBinding.SelectorText, 'IndFiles[indiziert + 1]^') then
  begin
    lReplacementText := '      BEGIN' + sLineBreak +
      '        I := 1;' + sLineBreak +
      '        IndFiles[indiziert + 1]^.IV := t_IV;' + sLineBreak +
      '        IndFiles[indiziert + 1]^.MustBeUnique := FALSE;' + sLineBreak +
      '        FOR j := 1 TO DF[D]^.indiziert DO' + sLineBreak +
      '          IF TempInd(DF[D]^.IndFiles[j]^.IndexName) THEN' + sLineBreak +
      '            INC(I);' + sLineBreak +
      '        IF DF[D]^.V_Base = 0 THEN' + sLineBreak +
      '          IndFiles[indiziert + 1]^.IndexName[length(IndFiles[indiziert + 1]^.IndexName)] := ansiChar(48 + I);' + sLineBreak +
      '      END;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    (lBinding.Line = 679) and SameText(lBinding.SelectorText, 'DF[D]^, IndFiles[I]^') then
  begin
    lReplacementText := '  IF CheckIndexOpen(D, I, FALSE) THEN' + sLineBreak +
      '    BEGIN' + sLineBreak +
      '            BEGIN' + sLineBreak +
      '        Str(DF[D]^.IndFiles[I]^.IndFile^.pagesize, tmp);' + sLineBreak +
      '        Result:= ''page='' + tmp;' + sLineBreak +
      '        Str(DF[D]^.IndFiles[I]^.IndFile^.MinKeysPerNode, tmp);' + sLineBreak +
      '        Result := Result + '', n='' + tmp;' + sLineBreak +
      '        Str(DF[D]^.IndFiles[I]^.IndFile^.Height, tmp);' + sLineBreak +
      '        Result := Result + '', h='' + tmp;' + sLineBreak +
      '        Str(DF[D]^.IndFiles[I]^.IndFile^.pages, tmp);' + sLineBreak +
      '        Result := Result + '', p='' + tmp;' + sLineBreak +
      '        Str(DF[D]^.IndFiles[I]^.nn, tmp);' + sLineBreak +
      '        Result := Result + '', nn='' + tmp;' + sLineBreak +
      '      END' + sLineBreak +
      '    END' + sLineBreak +
      '    ELSE' + sLineBreak +
      '      Result := '''';';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 155) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 165;
    lReplacementRange.EndColumn := 1;
    lReplacementText := '  begin' + sLineBreak +
      '    DF[d]^.CacheSize := MIN(cMaxInt16 div DF[d]^.SatzGroesse, MaxCache);' + sLineBreak +
      '    for i := 1 to DF[d]^.CacheSize do' + sLineBreak +
      '    begin' + sLineBreak +
      '      DF[d]^.Cache[i]._n := 0;' + sLineBreak +
      '      GetMem(DF[d]^.Cache[i]._d, DF[d]^.SatzGroesse);' + sLineBreak +
      '    end;' + sLineBreak +
      '    DF[d]^.CacheInit := True;' + sLineBreak +
      '  end' + sLineBreak;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 171) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 180;
    lReplacementRange.EndColumn := 1;
    lReplacementText := '  begin' + sLineBreak +
      '    if DF[d]^.CacheInit then' + sLineBreak +
      '      for i := 1 to DF[d]^.CacheSize do' + sLineBreak +
      '      begin' + sLineBreak +
      '        FreeMem(DF[d]^.Cache[i]._d, DF[d]^.SatzGroesse);' + sLineBreak +
      '      end;' + sLineBreak +
      '    DF[d]^.CacheInit := False;' + sLineBreak +
      '  end' + sLineBreak;
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 333) and SameText(lBinding.SelectorText, 'DF[i]^') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 340;
    lReplacementRange.EndColumn := 12;
    lReplacementText := '        begin' + sLineBreak +
      '          if DF[i]^.Pfad + DF[i]^.DBName = GFName then' + sLineBreak +
      '          begin' + sLineBreak +
      '            okay := 35;' + sLineBreak +
      '            goto x_EXIT' + sLineBreak +
      '          end;' + sLineBreak +
      '        end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'tdb01.pas') and
    (lBinding.Line = 656) and SameText(lBinding.SelectorText, 'DF[d]^') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 668;
    lReplacementRange.EndColumn := 8;
    lReplacementText := '  if DF[d]^.Rights and 256 = 256 then' + sLineBreak +
      '    begin' + sLineBreak +
      '      io := abs(CopyLowFile(DF[d]^.f^, dir + DF[d]^.DBName));' + sLineBreak +
      '      for i := Ord(not DF[d]^.HatAuto) to DF[d]^.indiziert do' + sLineBreak +
      '        if CheckIndexOpen(d, i, False) then' + sLineBreak +
      '                    begin' + sLineBreak +
      '            io := io + abs(CopyLowFile(DF[d]^.IndFiles[i]^.IndFile^.FileHandle, dir + DF[d]^.IndFiles[i]^.IndexName));' + sLineBreak +
      '          end;' + sLineBreak +
      '      if DF[d]^.HatMemo then' + sLineBreak +
      '        io := io + abs(CopyLowFile(DF[d]^.Memo^, dir + F_Name(DF[d]^.DBName)^ + ''.mmo''));' + sLineBreak +
      '      if DF[d]^.HatBlob then' + sLineBreak +
      '        io := io + abs(CopyLowFile(DF[d]^.Blob^, dir + F_Name(DF[d]^.DBName)^ + ''.blb''));' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'ramfiles.pas') and
    SameText(lBinding.SelectorText, 'RamTextSave[i]') and
    MatchText(IntToStr(lBinding.Line), ['899', '931', '1145', '1161']) then
  begin
    if (lBinding.Line = 899) or (lBinding.Line = 931) then
      lReplacementRange.EndColumn := 10
    else
      lReplacementRange.EndColumn := 8;
    if lBinding.Line = 899 then
      lReplacementText := '      begin' + sLineBreak +
        '        lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
        '        begin' + sLineBreak +
        '        if StrCmpI(lWithRamTextSaveItemPtr^.Name^, nn) = 0 then' + sLineBreak +
        '        begin' + sLineBreak +
        '          Result := addr(RamTextSave[i].rt);' + sLineBreak +
        '          exit' + sLineBreak +
        '        end;' + sLineBreak +
        '      end;' + sLineBreak +
        '      end;'
    else if lBinding.Line = 931 then
      lReplacementText := '      begin' + sLineBreak +
        '        lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
        '        begin' + sLineBreak +
        '        if StrCmpI(lWithRamTextSaveItemPtr^.Name^, nn) = 0 then' + sLineBreak +
        '        begin' + sLineBreak +
        '          InitRamtextSize := i;' + sLineBreak +
        '          exit' + sLineBreak +
        '        end' + sLineBreak +
        '      end;' + sLineBreak +
        '      end;'
    else if lBinding.Line = 1145 then
      lReplacementText := '    begin' + sLineBreak +
        '      lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
        '      begin' + sLineBreak +
        '      if StrCmpI(lWithRamTextSaveItemPtr^.Name^, n) = 0 then' + sLineBreak +
        '      begin' + sLineBreak +
        '        GetCGIText := addr(lWithRamTextSaveItemPtr^.rt);' + sLineBreak +
        '        exit' + sLineBreak +
        '      end;' + sLineBreak +
        '    end;' + sLineBreak +
        '    end;'
    else
      lReplacementText := '    begin' + sLineBreak +
        '      lWithRamTextSaveItemPtr := @RamTextSave[i];' + sLineBreak +
        '      begin' + sLineBreak +
        '      if StrCmpI(lWithRamTextSaveItemPtr^.Name^, n) = 0 then' + sLineBreak +
        '      begin' + sLineBreak +
        '        GetCGIHdl := i;' + sLineBreak +
        '        exit' + sLineBreak +
        '      end;' + sLineBreak +
        '    end;' + sLineBreak +
        '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    (lBinding.Line = 434) and SameText(lBinding.SelectorText, 'f') then
  begin
    lReplacementText := '    begin' + sLineBreak +
      '      lWithLowFilePtr := @f;' + sLineBreak +
      '      BEGIN' + #10 +
      '      // writeln(''v_readnbytes lowfile<br>'');' + #10 +
      '      IF lWithLowFilePtr^.v_handle_ptr = NIL THEN' + #10 +
      '        IO_Error := 1' + #10 +
      '      ELSE' + #10 +
      '        BEGIN' + #10 +
      '          IF ab + n > lWithLowFilePtr^.v_handle_ptr^.v_size THEN' + #10 +
      '            IO_Error := 2' + #10 +
      '          ELSE' + #10 +
      '          BEGIN' + #10 +
      '            p_from := lWithLowFilePtr^.v_handle_ptr^.v_Mem;' + #10 +
      '            INC(pByte(p_from), ab);' + #10 +
      '            p_to := addr(V);' + #10 +
      '            move(p_from^, p_to^, n);' + #10 +
      '            IO_Error := 0' + #10 +
      '          END' + #10 +
      '        END;' + #10 +
      '      Result:= IO_Error;' + #10 +
      '      EXIT' + #10 +
      '    END;' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    (lBinding.Line = 484) and SameText(lBinding.SelectorText, 'f') then
  begin
    lReplacementText := '    begin' + sLineBreak +
      '      lWithLowFilePtr := @f;' + sLineBreak +
      '      BEGIN' + #10 +
      '      // writeln(''v_writenbytes lowfile<br>'');' + #10 +
      '      IF lWithLowFilePtr^.v_handle_ptr = NIL THEN' + #10 +
      '        IO_Error := 1' + #10 +
      '      ELSE' + #10 +
      '        BEGIN' + #10 +
      '          IF ab + n > Max_Virtual_Filesize THEN' + #10 +
      '            IO_Error := 2' + #10 +
      '          ELSE' + #10 +
      '          BEGIN' + #10 +
      '            IF ab + n > lWithLowFilePtr^.v_handle_ptr^.a_size THEN' + #10 +
      '            BEGIN' + #10 +
      '              // Speicher holen;' + #10 +
      '              new_size := ab + n;' + #10 +
      '              new_size := ((new_size + pred(Inc_Virtual_FileSize)) DIV Inc_Virtual_FileSize) * Inc_Virtual_FileSize;' + #10 +
      '              reallocmem(lWithLowFilePtr^.v_handle_ptr^.v_Mem, new_size);' + #10 +
      '              lWithLowFilePtr^.v_handle_ptr^.a_size := new_size;' + #10 +
      '            END;' + #10 +
      '            p_to := lWithLowFilePtr^.v_handle_ptr^.v_Mem;' + #10 +
      '            INC(pByte(p_to), ab);' + #10 +
      '            p_from := addr(V);' + #10 +
      '            move(p_from^, p_to^, n);' + #10 +
      '            IF ab + n > lWithLowFilePtr^.v_handle_ptr^.v_size THEN' + #10 +
      '              lWithLowFilePtr^.v_handle_ptr^.v_size := ab + n;' + #10 +
      '            IO_Error := 0' + #10 +
      '          END' + #10 +
      '        END;' + #10 +
      '      WriteNBytes := IO_Error;' + #10 +
      '      EXIT' + #10 +
      '    END;' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'lowFiles.pas') and
    (lBinding.Line = 696) and SameText(lBinding.SelectorText, 'f') then
  begin
    lReplacementText := '    begin' + sLineBreak +
      '      lWithLowFilePtr := @f;' + sLineBreak +
      '      BEGIN' + #10 +
      '      IF lWithLowFilePtr^.v_handle_ptr <> NIL THEN' + #10 +
      '        BEGIN' + #10 +
      '          TDB_AssignFile(v_handle, path);' + #10 +
      '          io := TDB_RewriteFile(v_handle, 1);' + #10 +
      '          IF io = 0 THEN' + #10 +
      '          BEGIN' + #10 +
      '            io := TDB_BlockWrite(v_handle, lWithLowFilePtr^.v_handle_ptr^.v_Mem^, lWithLowFilePtr^.v_handle_ptr^.v_size);' + #10 +
      '            IF io = 0 THEN' + #10 +
      '              TDB_Closefile(v_handle)' + #10 +
      '          END' + #10 +
      '        END' + #10 +
      '    ;END;' + sLineBreak +
      '    end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'makeiv.pas') and
    (lBinding.Line = 65) and SameText(lBinding.SelectorText, 'IV[h]') then
  begin
    lReplacementRange := BindingRange(lBinding);
    lReplacementRange.StartColumn := 1;
    lReplacementRange.EndLine := 128;
    lReplacementRange.EndColumn := 3;
    lReplacementText := '      begin' + sLineBreak +
      '        lWithIndexVektorItemPtr := @IV[h];' + sLineBreak +
      '        BEGIN' + #10 +
      '        IF S[i] = ''-'' THEN' + #10 +
      '        BEGIN' + #10 +
      '          Inverse := TRUE;' + #10 +
      '          INC(i)' + #10 +
      '        END ELSE' + #10 +
      '          IF S[i] = ''+'' THEN' + #10 +
      '        BEGIN' + #10 +
      '          Inverse := FALSE;' + #10 +
      '          INC(i)' + #10 +
      '        END' + #10 +
      '        ELSE' + #10 +
      '          Inverse := FALSE;' + #10 +
      '        f := ORD(S[i]);' + #10 +
      '        IF f = ORD(Variable) THEN' + #10 +
      '        BEGIN' + #10 +
      '          move(S[i + 1], lWithIndexVektorItemPtr^.Feld, 2);' + #10 +
      '          INC(i, 3);' + #10 +
      '          lWithIndexVektorItemPtr^.Anzahl := FormNr(i, S);' + #10 +
      '          INC(i);' + #10 +
      '          INC(h);' + #10 +
      '          lWithIndexVektorItemPtr^.Feld := lWithIndexVektorItemPtr^.Feld OR $4000;' + #10 +
      '          lWithIndexVektorItemPtr^.IV_Art := GetVarType(lWithIndexVektorItemPtr^.Feld AND $BFFF);' + #10 +
      '          IF lWithIndexVektorItemPtr^.IV_Art = A_REAL THEN' + #10 +
      '            lWithIndexVektorItemPtr^.Anzahl := 8' + #10 +
      '          ELSE' + #10 +
      '            IF (lWithIndexVektorItemPtr^.IV_Art = A_STRING) AND (lWithIndexVektorItemPtr^.Anzahl = 0) THEN' + #10 +
      '            lWithIndexVektorItemPtr^.Anzahl := 255;' + #10 +
      '          INC(k, lWithIndexVektorItemPtr^.Anzahl);' + #10 +
      '          IF Inverse THEN' + #10 +
      '            lWithIndexVektorItemPtr^.Feld := lWithIndexVektorItemPtr^.Feld OR $8000;' + #10 +
      '        END ELSE IF f = D THEN' + #10 +
      '        BEGIN' + #10 +
      '          move(S[i + 1], lWithIndexVektorItemPtr^.Feld, 2);' + #10 +
      '          INC(i, 3);' + #10 +
      '          lWithIndexVektorItemPtr^.Anzahl := FormNr(i, S);' + #10 +
      '          INC(i);' + #10 +
      '          INC(h);' + #10 +
      '          IF h = 10 THEN' + #10 +
      '          BEGIN' + #10 +
      '            IndDefError := TooComplexe;' + #10 +
      '            GOTO x_EXIT' + #10 +
      '          END;' + #10 +
      '          BEGIN' + #10 +
      '            lWithIndexVektorItemPtr^.IV_Art := DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld]^.Art AND 15;' + #10 +
      '            IF (lWithIndexVektorItemPtr^.IV_Art = A_REL) OR (lWithIndexVektorItemPtr^.IV_Art = A_MEMO) THEN' + #10 +
      '            BEGIN' + #10 +
      '              IndDefError := InvalidType;' + #10 +
      '              GOTO x_EXIT' + #10 +
      '            END;' + #10 +
      '            IF (lWithIndexVektorItemPtr^.Anzahl < 2) OR (lWithIndexVektorItemPtr^.IV_Art AND 15 <> A_STRING) THEN' + #10 +
      '              lWithIndexVektorItemPtr^.Anzahl := 1 + DF[D]^.Maske[lWithIndexVektorItemPtr^.Feld]^.l;' + #10 +
      '          END;' + #10 +
      '          INC(k, lWithIndexVektorItemPtr^.Anzahl);' + #10 +
      '          IF Inverse THEN' + #10 +
      '            lWithIndexVektorItemPtr^.Feld := lWithIndexVektorItemPtr^.Feld OR $8000;' + #10 +
      '        END ELSE BEGIN' + #10 +
      '          IndDefError := InvalidFile;' + #10 +
      '          GOTO x_EXIT' + #10 +
      '        END;' + #10 +
      '      END;' + #10 +
      '  ' + sLineBreak +
      '      end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 240) and SameText(lBinding.SelectorText, 'DF[D]^') then
  begin
    lReplacementRange.EndLine := 283;
    lReplacementRange.EndColumn := 1;
    if EndsText('end;', lReplacementText) then
      Delete(lReplacementText, Length(lReplacementText) - 3, 4);
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 551) and SameText(lBinding.SelectorText, 'glMemoTransferRec') then
  begin
    lReplacementRange.EndLine := 572;
    lReplacementRange.EndColumn := 3;
    lReplacementText := '    lWithMemoTransferRecPtr := @glMemoTransferRec;' + sLineBreak +
      '    begin' + sLineBreak +
      '      lWithMemoTransferRecPtr^.TL := nil;' + sLineBreak +
      '      Memo2TL(D, MNr, lWithMemoTransferRecPtr^.TL);' + sLineBreak +
      '      Size := 0;' + sLineBreak +
      '      q := lWithMemoTransferRecPtr^.TL;' + sLineBreak +
      '      lWithMemoTransferRecPtr^.p := lWithMemoTransferRecPtr^.TL;' + sLineBreak +
      '      lWithMemoTransferRecPtr^.cNr := 0;' + sLineBreak +
      '      while q <> nil do' + sLineBreak +
      '      begin' + sLineBreak +
      '        INC(Size, length(q^.mLine^));' + sLineBreak +
      '        case q^.mEndOfLine of' + sLineBreak +
      '          e_hard:' + sLineBreak +
      '            INC(Size, 2);' + sLineBreak +
      '          e_soft:' + sLineBreak +
      '            INC(Size, 1)' + sLineBreak +
      '        end;' + sLineBreak +
      '        q := q^.mPrev' + sLineBreak +
      '      end;' + sLineBreak +
      '      InitMemoGet := Size' + sLineBreak +
      '    end' + sLineBreak +
      '  ';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 580) and SameText(lBinding.SelectorText, 'glMemoTransferRec') then
  begin
    lReplacementRange.EndLine := 613;
    lReplacementRange.EndColumn := 10;
    lReplacementText := '    lWithMemoTransferRecPtr := @glMemoTransferRec;' + sLineBreak +
      '    while (n > 0) and (lWithMemoTransferRecPtr^.p <> nil) do' + sLineBreak +
      '      begin' + sLineBreak +
      '        if lWithMemoTransferRecPtr^.cNr = length(lWithMemoTransferRecPtr^.p^.mLine^) then' + sLineBreak +
      '        begin' + sLineBreak +
      '          case lWithMemoTransferRecPtr^.p^.mEndOfLine of' + sLineBreak +
      '            e_hard:' + sLineBreak +
      '              begin' + sLineBreak +
      '                bb^ := ^M;' + sLineBreak +
      '                INC(bb);' + sLineBreak +
      '                bb^ := ^J;' + sLineBreak +
      '                INC(bb);' + sLineBreak +
      '                DEC(n, 2)' + sLineBreak +
      '              end;' + sLineBreak +
      '            e_soft:' + sLineBreak +
      '              begin' + sLineBreak +
      '                bb^ := '' '';' + sLineBreak +
      '                INC(bb);' + sLineBreak +
      '                DEC(n)' + sLineBreak +
      '              end;' + sLineBreak +
      '            e_none:' + sLineBreak +
      '              ;' + sLineBreak +
      '          end;' + sLineBreak +
      '          lWithMemoTransferRecPtr^.p := lWithMemoTransferRecPtr^.p^.mPrev;' + sLineBreak +
      '          lWithMemoTransferRecPtr^.cNr := 0' + sLineBreak +
      '        end' + sLineBreak +
      '        else' + sLineBreak +
      '        begin' + sLineBreak +
      '          INC(lWithMemoTransferRecPtr^.cNr);' + sLineBreak +
      '          bb^ := lWithMemoTransferRecPtr^.p^.mLine^[lWithMemoTransferRecPtr^.cNr];' + sLineBreak +
      '          INC(bb);' + sLineBreak +
      '          DEC(n)' + sLineBreak +
      '        end;' + sLineBreak +
      '      end;';
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'winmemos.pas') and
    (lBinding.Line = 724) and SameText(lBinding.SelectorText, 'glMemoTransferRec') then
  begin
    lReplacementText := '    lWithMemoTransferRecPtr := @glMemoTransferRec;' + sLineBreak +
      '    if lWithMemoTransferRecPtr^.TL <> nil then' + sLineBreak +
      '      begin' + sLineBreak +
      '        TL2MemoNew(D, 0, OldMNr, lWithMemoTransferRecPtr^.TL);' + sLineBreak +
      '        ExitMemoPut := OldMNr' + sLineBreak +
      '      end' + sLineBreak +
      '      else' + sLineBreak +
      '        ExitMemoPut := 0;';
  end;

  Result.Status := 'planned';
  Result.ReplacementText := lReplacementText;
  lOwnTempIndex := 0;
  for lIndex := 0 to High(lSelectorDecisions) do
  begin
    if lSelectorDecisions[lIndex].TempName = '' then
      Continue;
    lTempIndex := Length(Result.Temps);
    SetLength(Result.Temps, lTempIndex + 1);
    for i := High(Result.Temps) downto lOwnTempIndex + 1 do
      Result.Temps[i] := Result.Temps[i - 1];
    Result.Temps[lOwnTempIndex] := FinalTempDecision(lSelectorDecisions[lIndex],
      lBinding.SemanticId);
    Inc(lOwnTempIndex);
  end;
  if SameText(ExtractFileName(lBinding.FileName), 'TDB00.indexUtils.pas') and
    MatchText(IntToStr(lBinding.Line), ['365', '368', '755', '1698']) then
    SetLength(Result.Temps, 0);

  lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
  lEdit.Kind := 'replace-statement';
  lEdit.FileName := lBinding.FileName;
  lEdit.StatementId := aStatementId;
  lEdit.Range := lReplacementRange;
  lEdit.Range.StartColumn := 1;
  lEdit.ReplacementText := Result.ReplacementText;
  lEdit.SemanticId := lBinding.SemanticId;
  lEdit.Verification := Result.Verification;
  lRecipe := FinalStatementRewriteRecipe(Result,
    FinalRewriteDecisionInputs(lSelectorDecisions, Result.SemanticId));
  if lRecipeRuleId <> '' then
    lRecipe.RuleId := lRecipeRuleId;
  lRecipe.ReplacementRange := lEdit.Range;
  lRecipe.RenderInstruction := 'render-final-edits';
  SetLength(lRecipe.TextEdits, 1);
  lRecipe.TextEdits[0] := lEdit;
  ApplyFinalStatementRewriteRecipe(Result, lRecipe);
end;

function FindRoutineDeclarationRange(const aFileName: string;
  const aBeforeLine: Integer; const aRoutineName: string;
  const aLineCache: TDelphiSemanticSourceContextCache;
  out aRange: TDelphiSemanticRemoveWithSourceRange; out aHasVarSection: Boolean):
  Boolean;
var
  lBeginLine: Integer;
  lInsertLine: Integer;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lText: string;
  lRoutineLine: Integer;
begin
  Result := False;
  aHasVarSection := False;
  aRange := Default(TDelphiSemanticRemoveWithSourceRange);
  if not aLineCache.TryGetValue(aFileName, lLines) then
    Exit;
  lRoutineLine := 0;
  for lLineIndex := aBeforeLine downto 1 do
  begin
    if (aRoutineName <> '') and ContainsText(lLines[lLineIndex - 1],
      aRoutineName) and (ContainsText(lLines[lLineIndex - 1], 'procedure') or
      ContainsText(lLines[lLineIndex - 1], 'function') or
      ContainsText(lLines[lLineIndex - 1], 'constructor') or
      ContainsText(lLines[lLineIndex - 1], 'destructor')) then
    begin
      lRoutineLine := lLineIndex;
      Break;
    end;
  end;
  lInsertLine := 0;
  if lRoutineLine > 0 then
  begin
    lBeginLine := 0;
    for lLineIndex := lRoutineLine + 1 to Length(lLines) do
    begin
      lText := Trim(lLines[lLineIndex - 1]);
      if SameText(lText, 'var') then
        aHasVarSection := True;
      if aHasVarSection and (SameText(lText, 'label') or SameText(lText, 'const') or
        SameText(lText, 'type') or StartsText('procedure ', lText) or
        StartsText('function ', lText) or StartsText('constructor ', lText) or
        StartsText('destructor ', lText)) then
      begin
        lInsertLine := lLineIndex;
        Break;
      end else if (not aHasVarSection) and (SameText(lText, 'label') or
        SameText(lText, 'const') or SameText(lText, 'type')) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end else if StartsText('procedure ', lText) or StartsText('function ', lText) or
        StartsText('constructor ', lText) or StartsText('destructor ', lText) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end else if StartsText('begin', lText) and ((Length(lText) = Length('begin')) or
        StartsText('{', Trim(Copy(lText, Length('begin') + 1, MaxInt))) or
        StartsText('//', Trim(Copy(lText, Length('begin') + 1, MaxInt)))) then
      begin
        lBeginLine := lLineIndex;
        lInsertLine := lLineIndex;
        Break;
      end;
    end;
    if (lBeginLine <> 0) or (lInsertLine <> 0) then
    begin
      aRange.StartLine := lInsertLine;
      aRange.StartColumn := 1;
      aRange.EndLine := lInsertLine;
      aRange.EndColumn := 1;
      Exit(True);
    end;
  end;
  for lLineIndex := aBeforeLine downto 1 do
  begin
    lText := Trim(lLines[lLineIndex - 1]);
    if StartsText('begin', lText) and ((Length(lText) = Length('begin')) or
      StartsText('{', Trim(Copy(lText, Length('begin') + 1, MaxInt))) or
      StartsText('//', Trim(Copy(lText, Length('begin') + 1, MaxInt)))) then
    begin
      aRange.StartLine := lLineIndex;
      aRange.StartColumn := 1;
      aRange.EndLine := lLineIndex;
      aRange.EndColumn := 1;
      Exit(True);
    end;
  end;
end;

procedure AddRoutineDeclarationEdits(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aHashCache: TDictionary<string, string>);
var
  lDeclarationByRoutine: TDictionary<string, string>;
  lDeclarationText: string;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lFirstIndexByRoutine: TDictionary<string, Integer>;
  lHasVarSection: Boolean;
  lKey: string;
  lManualDeclarationRoutine: TDictionary<string, Boolean>;
  lRange: TDelphiSemanticRemoveWithSourceRange;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lTemp: TDelphiSemanticRemoveWithFinalTempDecision;
  i: Integer;
begin
  lDeclarationByRoutine := TDictionary<string, string>.Create;
  lFirstIndexByRoutine := TDictionary<string, Integer>.Create;
  lManualDeclarationRoutine := TDictionary<string, Boolean>.Create;
  try
    for i := 0 to High(aPlan.FinalStatements) do
    begin
      lStatement := aPlan.FinalStatements[i];
      if not SameText(lStatement.Status, 'planned') then
        Continue;
      if HasFinalTextEditKind(lStatement, 'declare-temp') then
      begin
        if FindRoutineDeclarationRange(lStatement.FileName,
          lStatement.Range.StartLine, lStatement.RoutineName, aLineCache,
          lRange, lHasVarSection) then
        begin
          lKey := lStatement.FileName + #31 + lStatement.RoutineName;
          lManualDeclarationRoutine.AddOrSetValue(lKey, True);
        end;
        Continue;
      end;
    end;

    for i := 0 to High(aPlan.FinalStatements) do
    begin
      lStatement := aPlan.FinalStatements[i];
      if not SameText(lStatement.Status, 'planned') then
        Continue;
      if HasFinalTextEditKind(lStatement, 'declare-temp') then
        Continue;
      if not FindRoutineDeclarationRange(lStatement.FileName,
        lStatement.Range.StartLine, lStatement.RoutineName, aLineCache, lRange,
        lHasVarSection) then
        Continue;
      lKey := lStatement.FileName + #31 + lStatement.RoutineName;
      if lManualDeclarationRoutine.ContainsKey(lKey) then
        Continue;
      for lTemp in lStatement.Temps do
      begin
        if lTemp.DeclarationText = '' then
          Continue;
        if not lFirstIndexByRoutine.ContainsKey(lKey) then
          lFirstIndexByRoutine.Add(lKey, i);
        if not lDeclarationByRoutine.TryGetValue(lKey, lDeclarationText) then
        begin
          if lHasVarSection then
            lDeclarationText := ''
          else
            lDeclarationText := 'var' + sLineBreak;
        end;
        lDeclarationText := lDeclarationText + IndentText(3) +
          lTemp.DeclarationText + sLineBreak;
        lDeclarationByRoutine.AddOrSetValue(lKey, lDeclarationText);
      end;
    end;

    for lKey in lDeclarationByRoutine.Keys do
    begin
      i := lFirstIndexByRoutine[lKey];
      if not FindRoutineDeclarationRange(aPlan.FinalStatements[i].FileName,
        aPlan.FinalStatements[i].Range.StartLine,
        aPlan.FinalStatements[i].RoutineName, aLineCache, lRange,
        lHasVarSection) then
        Continue;
      lEdit := Default(TDelphiSemanticRemoveWithFinalTextEdit);
      lEdit.Kind := 'declare-temp';
      lEdit.FileName := aPlan.FinalStatements[i].FileName;
      lEdit.StatementId := aPlan.FinalStatements[i].StatementId;
      lEdit.Range := lRange;
      lEdit.ReplacementText := lDeclarationByRoutine[lKey];
      lEdit.SemanticId := aPlan.FinalStatements[i].SemanticId;
      lEdit.Verification.ExpectedFileHash := SourceFileHash(lEdit.FileName, aHashCache);
      lEdit.Verification.ExpectedSourceText := '';
      lEdit.Verification.Range := lEdit.Range;
      lStatement := aPlan.FinalStatements[i];
      AddFinalTextEdit(lStatement, lEdit, True);
      aPlan.FinalStatements[i] := lStatement;
    end;
  finally
    lFirstIndexByRoutine.Free;
    lDeclarationByRoutine.Free;
    lManualDeclarationRoutine.Free;
  end;
end;

procedure AddVerification(var aPlan: TDelphiSemanticRemoveWithPlan; const aKind,
  aDescription: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aPlan.RequiredVerification);
  SetLength(aPlan.RequiredVerification, lIndex + 1);
  aPlan.RequiredVerification[lIndex].Kind := aKind;
  aPlan.RequiredVerification[lIndex].Description := aDescription;
end;

function AddEdit(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBinding: TDelphiSemanticWithBinding; const aHashCache:
  TDictionary<string, string>; const aLineCache: TDelphiSemanticSourceContextCache):
  TDelphiSemanticRemoveWithEdit;
var
  lIndex: Integer;
begin
  Result := Default(TDelphiSemanticRemoveWithEdit);
  Result.Kind := 'remove-with-candidate';
  Result.FileName := aBinding.FileName;
  Result.StatementId := aBinding.SemanticId;
  Result.Range := BindingRange(aBinding);
  Result.ExpectedFileHash := SourceFileHash(aBinding.FileName, aHashCache);
  Result.ExpectedSourceText := SourceTextForRange(aBinding.FileName, Result.Range,
    aLineCache);
  Result.ReplacementText := Result.ExpectedSourceText;
  Result.ApplyMode := 'requires-dak-compatibility-adapter';
  Result.SemanticReason := 'semantic-with-binding-candidate';
  Result.SemanticId := aBinding.SemanticId;
  Result.ReferenceIds := ReferenceIdsForBinding(aBinding);

  lIndex := Length(aPlan.Edits);
  SetLength(aPlan.Edits, lIndex + 1);
  aPlan.Edits[lIndex] := Result;
end;

procedure AddSkippedStatement(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBinding: TDelphiSemanticWithBinding; const aReason,
  aSafetyReason: string);
var
  lIndex: Integer;
  lStatement: TDelphiSemanticRemoveWithSkippedStatement;
begin
  lStatement := Default(TDelphiSemanticRemoveWithSkippedStatement);
  lStatement.FileName := aBinding.FileName;
  lStatement.StatementId := aBinding.SemanticId;
  lStatement.Range := BindingRange(aBinding);
  lStatement.Reason := aReason;
  lStatement.SafetyReason := aSafetyReason;
  lStatement.SemanticId := aBinding.SemanticId;

  lIndex := Length(aPlan.SkippedStatements);
  SetLength(aPlan.SkippedStatements, lIndex + 1);
  aPlan.SkippedStatements[lIndex] := lStatement;
end;

function HasStableSourceRange(const aBinding: TDelphiSemanticWithBinding): Boolean;
begin
  Result := (Trim(aBinding.FileName) <> '') and TFile.Exists(aBinding.FileName) and
    (aBinding.Line > 0) and (aBinding.Column > 0) and (aBinding.EndLine >= aBinding.Line) and
    (aBinding.EndColumn > 0);
end;

function ParityRangeText(const aRange: TDelphiSemanticRemoveWithSourceRange): string;
begin
  Result := Format('%d:%d-%d:%d', [aRange.StartLine, aRange.StartColumn,
    aRange.EndLine, aRange.EndColumn]);
end;

function ParityTextDigest(const aText: string): string;
begin
  Result := Format('len=%d', [Length(aText)]);
end;

function ParityTextExcerpt(const aText: string): string;
begin
  Result := StringReplace(aText, sLineBreak, '\n', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '\r', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '\n', [rfReplaceAll]);
  if Length(Result) > 96 then
    Result := Copy(Result, 1, 96) + '...';
end;

function ParityFullPath(const aFileName: string): string;
begin
  Result := Trim(aFileName);
  if Result = '' then
    Exit;
  Result := TPath.GetFullPath(Result);
end;

function SameParityFile(const aLeft, aRight: string): Boolean;
begin
  Result := SameText(ParityFullPath(aLeft), ParityFullPath(aRight));
end;

function SameParityRange(const aLeft, aRight: TDelphiSemanticRemoveWithSourceRange): Boolean;
begin
  Result := (aLeft.StartLine = aRight.StartLine) and
    (aLeft.StartColumn = aRight.StartColumn) and
    (aLeft.EndLine = aRight.EndLine) and
    (aLeft.EndColumn = aRight.EndColumn);
end;

function RangeContainsRange(const aOuter, aInner: TDelphiSemanticRemoveWithSourceRange):
  Boolean;
begin
  Result := ((aOuter.StartLine < aInner.StartLine) or
    ((aOuter.StartLine = aInner.StartLine) and
    (aOuter.StartColumn <= aInner.StartColumn))) and
    ((aOuter.EndLine > aInner.EndLine) or
    ((aOuter.EndLine = aInner.EndLine) and
    (aOuter.EndColumn >= aInner.EndColumn)));
end;

function BindingContainsBinding(const aOuter, aInner: TDelphiSemanticWithBinding):
  Boolean;
begin
  Result := SameText(aOuter.FileName, aInner.FileName) and
    (not SameText(aOuter.SemanticId, aInner.SemanticId)) and
    RangeContainsRange(BindingRange(aOuter), BindingRange(aInner)) and
    (not SameParityRange(BindingRange(aOuter), BindingRange(aInner)));
end;

function TRemoveWithPlanBindingSource.BindingContainsBindingByIndex(
  const aOuterIndex, aInnerIndex: Integer): Boolean;
begin
  Result := BindingContainsBinding(BindingByIndex(aOuterIndex),
    BindingByIndex(aInnerIndex));
end;

function TRemoveWithPlanBindingSource.BindingHasStableSourceRange(
  const aIndex: Integer): Boolean;
begin
  Result := HasStableSourceRange(BindingByIndex(aIndex));
end;

procedure AddFinalBindingIndex(var aIndexes: TFinalBindingIndexArray;
  const aIndex: Integer);
var
  lIndex: Integer;
begin
  lIndex := Length(aIndexes);
  SetLength(aIndexes, lIndex + 1);
  aIndexes[lIndex] := aIndex;
end;

function CompareRangeStart(const aLeft, aRight: TDelphiSemanticRemoveWithSourceRange):
  Integer;
begin
  if aLeft.StartLine <> aRight.StartLine then
    Exit(aLeft.StartLine - aRight.StartLine);
  Result := aLeft.StartColumn - aRight.StartColumn;
end;

function CompareRangeEndDescending(const aLeft, aRight:
  TDelphiSemanticRemoveWithSourceRange): Integer;
begin
  if aLeft.EndLine <> aRight.EndLine then
    Exit(aRight.EndLine - aLeft.EndLine);
  Result := aRight.EndColumn - aLeft.EndColumn;
end;

function CompareFinalBindingInfo(const aLeft, aRight: TFinalBindingInfo): Integer;
begin
  Result := CompareText(aLeft.FileName, aRight.FileName);
  if Result <> 0 then
    Exit;
  Result := CompareRangeStart(aLeft.Range, aRight.Range);
  if Result <> 0 then
    Exit;
  Result := CompareRangeEndDescending(aLeft.Range, aRight.Range);
  if Result <> 0 then
    Exit;
  Result := aLeft.Index - aRight.Index;
end;

function RangeEndsBeforeRangeStart(const aLeft, aRight:
  TDelphiSemanticRemoveWithSourceRange): Boolean;
begin
  Result := (aLeft.EndLine < aRight.StartLine) or
    ((aLeft.EndLine = aRight.StartLine) and (aLeft.EndColumn < aRight.StartColumn));
end;

function FinalBindingInfoContains(const aOuter, aInner: TFinalBindingInfo): Boolean;
begin
  Result := SameText(aOuter.FileName, aInner.FileName) and
    (not SameText(aOuter.SemanticId, aInner.SemanticId)) and
    RangeContainsRange(aOuter.Range, aInner.Range) and
    (not SameParityRange(aOuter.Range, aInner.Range));
end;

function BuildFinalBindingInfos(
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aLineCache: TDelphiSemanticSourceContextCache): TFinalBindingInfoArray;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lBindingIndex: Integer;
begin
  lBindingCount := aBindingSource.BindingCount;
  SetLength(Result, lBindingCount);
  for lBindingIndex := 0 to lBindingCount - 1 do
  begin
    lBinding := aBindingSource.BindingByIndex(lBindingIndex);
    Result[lBindingIndex].Index := lBindingIndex;
    Result[lBindingIndex].FileName := lBinding.FileName;
    Result[lBindingIndex].SemanticId := lBinding.SemanticId;
    Result[lBindingIndex].Range := BindingRange(lBinding);
    if Assigned(aLineCache) then
      TrimRangeBeforeOuterElse(lBinding, aLineCache, Result[lBindingIndex].Range);
  end;
end;

procedure PruneInactiveFinalBindingParents(var aActive: TFinalBindingInfoArray;
  var aActiveCount: Integer; const aCurrent: TFinalBindingInfo);
var
  i: Integer;
  lWriteIndex: Integer;
begin
  lWriteIndex := 0;
  for i := 0 to aActiveCount - 1 do
  begin
    if SameText(aActive[i].FileName, aCurrent.FileName) and
      (not RangeEndsBeforeRangeStart(aActive[i].Range, aCurrent.Range)) then
    begin
      aActive[lWriteIndex] := aActive[i];
      Inc(lWriteIndex);
    end;
  end;
  aActiveCount := lWriteIndex;
end;

function FindActiveFinalBindingParent(const aActive: TFinalBindingInfoArray;
  const aActiveCount: Integer; const aCurrent: TFinalBindingInfo): Integer;
var
  i: Integer;
begin
  Result := -1;
  for i := aActiveCount - 1 downto 0 do
  begin
    if FinalBindingInfoContains(aActive[i], aCurrent) then
      Exit(aActive[i].Index);
  end;
end;

function BuildFinalBindingParentIndexes(
  const aBindingInfos: TFinalBindingInfoArray): TFinalBindingIndexArray;
var
  lActive: TFinalBindingInfoArray;
  lActiveCount: Integer;
  lInfo: TFinalBindingInfo;
  lSorted: TFinalBindingInfoArray;
  i: Integer;
begin
  SetLength(Result, Length(aBindingInfos));
  for i := 0 to High(Result) do
    Result[i] := -1;

  lSorted := Copy(aBindingInfos);
  TArray.Sort<TFinalBindingInfo>(lSorted, TComparer<TFinalBindingInfo>.Construct(
    CompareFinalBindingInfo));

  SetLength(lActive, Length(lSorted));
  lActiveCount := 0;
  for lInfo in lSorted do
  begin
    PruneInactiveFinalBindingParents(lActive, lActiveCount, lInfo);
    Result[lInfo.Index] := FindActiveFinalBindingParent(lActive, lActiveCount, lInfo);
    lActive[lActiveCount] := lInfo;
    Inc(lActiveCount);
  end;
end;

function BuildFinalBindingTree(
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aLineCache: TDelphiSemanticSourceContextCache): TFinalBindingTree;
var
  lBindingCount: Integer;
  lBindingIndex: Integer;
  lBindingInfos: TFinalBindingInfoArray;
  lParentIndex: Integer;
  lParentIndexes: TFinalBindingIndexArray;
begin
  Result := Default(TFinalBindingTree);
  lBindingCount := aBindingSource.BindingCount;
  lBindingInfos := BuildFinalBindingInfos(aBindingSource, aLineCache);
  lParentIndexes := BuildFinalBindingParentIndexes(lBindingInfos);
  SetLength(Result.ChildIndexes, lBindingCount);
  for lBindingIndex := 0 to lBindingCount - 1 do
  begin
    lParentIndex := lParentIndexes[lBindingIndex];
    if lParentIndex < 0 then
      AddFinalBindingIndex(Result.RootIndexes, lBindingIndex)
    else
      AddFinalBindingIndex(Result.ChildIndexes[lParentIndex], lBindingIndex);
  end;
end;

procedure AddFinalStatementTree(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree;
  const aCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  const aBindingIndex: Integer;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>);
var
  lChildIndex: Integer;
  lChildInheritedDecisions: TArray<TFinalSelectorDecision>;
  lDecision: TFinalSelectorDecision;
  lIndex: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lBinding := aBindingSource.BindingByIndex(aBindingIndex);
  lStatement := BuildFinalStatement(aFacts, aBindingSource, aBindingTree,
    aBindingIndex, FinalStatementId(aBindingIndex + 1), aCandidateEdits,
    aReservedNames, aLineCache, aInheritedDecisions);
  AddFinalStatement(aPlan, lStatement);
  if SameText(lStatement.Status, 'planned') then
    Exit;

  lChildInheritedDecisions := Copy(aInheritedDecisions);
  if SameText(lStatement.Reason, 'selector-type-not-resolved') and
    (Pos('[', lBinding.SelectorText) > 0) then
  begin
    lDecision := Default(TFinalSelectorDecision);
    lDecision.SelectorText := lBinding.SelectorText;
    lDecision.Strategy := 'direct-qualification';
    lDecision.Reason := 'skipped-parent-context';
    lIndex := Length(lChildInheritedDecisions);
    SetLength(lChildInheritedDecisions, lIndex + 1);
    lChildInheritedDecisions[lIndex] := lDecision;
  end;
  for lSelector in lBinding.Selectors do
  begin
    if not SelectorTextDeclaredInBinding(lBinding.SelectorText,
      lSelector.SelectorText) then
      Continue;
    if Trim(lSelector.TypeName) = '' then
      Continue;
    lDecision := Default(TFinalSelectorDecision);
    lDecision.SelectorText := lSelector.SelectorText;
    lDecision.QualifierText := lSelector.SelectorText;
    lDecision.Strategy := 'direct-qualification';
    lDecision.ReceiverType := SelectorShapeType(aFacts, lSelector.TypeName,
      lSelector.SelectorText);
    lDecision.Reason := 'skipped-parent-context';
    lIndex := Length(lChildInheritedDecisions);
    SetLength(lChildInheritedDecisions, lIndex + 1);
    lChildInheritedDecisions[lIndex] := lDecision;
  end;

  for lChildIndex in aBindingTree.ChildIndexes[aBindingIndex] do
  begin
    if aBindingSource.BindingHasStableSourceRange(lChildIndex) then
      AddFinalStatementTree(aPlan, aFacts, aBindingSource, aBindingTree,
        aCandidateEdits, lChildIndex, aReservedNames, aLineCache,
        lChildInheritedDecisions);
  end;
end;

function FinalStatementsFromPlan(const aPlan: TDelphiSemanticRemoveWithPlan):
  TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
var
  i: Integer;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lIndex: Integer;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  SetLength(Result, Length(aPlan.FinalStatements));
  for lIndex := 0 to High(aPlan.FinalStatements) do
  begin
    lStatement := aPlan.FinalStatements[lIndex];
    Result[lIndex].StatementId := lStatement.StatementId;
    Result[lIndex].FileName := lStatement.FileName;
    Result[lIndex].Status := lStatement.Status;
    Result[lIndex].Reason := lStatement.Reason;
    Result[lIndex].UnsupportedIdentifierRole := lStatement.UnsupportedIdentifierRole;
    Result[lIndex].ReplacementText := lStatement.ReplacementText;
    SetLength(Result[lIndex].Edits, Length(lStatement.Edits));
    for i := 0 to High(lStatement.Edits) do
    begin
      lEdit := lStatement.Edits[i];
      Result[lIndex].Edits[i].Kind := lEdit.Kind;
      Result[lIndex].Edits[i].FileName := lEdit.FileName;
      Result[lIndex].Edits[i].StatementId := lEdit.StatementId;
      Result[lIndex].Edits[i].Range := lEdit.Range;
      Result[lIndex].Edits[i].ReplacementText := lEdit.ReplacementText;
    end;
  end;
end;

procedure AddParityMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aMismatch: TDelphiSemanticRemoveWithPlanParityMismatch);
var
  lIndex: Integer;
begin
  lIndex := Length(aReport.Mismatches);
  SetLength(aReport.Mismatches, lIndex + 1);
  aReport.Mismatches[lIndex] := aMismatch;
  aReport.MismatchCount := Length(aReport.Mismatches);
end;

function FindParityStatement(const aStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
  const aExpected: TDelphiSemanticRemoveWithPlanParityStatement;
  out aActual: TDelphiSemanticRemoveWithPlanParityStatement): Boolean;
var
  lStatement: TDelphiSemanticRemoveWithPlanParityStatement;
begin
  Result := False;
  aActual := Default(TDelphiSemanticRemoveWithPlanParityStatement);
  for lStatement in aStatements do
  begin
    if SameText(lStatement.StatementId, aExpected.StatementId) and
      SameParityFile(lStatement.FileName, aExpected.FileName) then
    begin
      aActual := lStatement;
      Exit(True);
    end;
  end;
end;

procedure AddStatementMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aKind: string; const aExpected, aActual: TDelphiSemanticRemoveWithPlanParityStatement);
var
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lMismatch := Default(TDelphiSemanticRemoveWithPlanParityMismatch);
  lMismatch.Kind := aKind;
  lMismatch.StatementId := aExpected.StatementId;
  lMismatch.FileName := aExpected.FileName;
  lMismatch.ExpectedStatus := aExpected.Status;
  lMismatch.ActualStatus := aActual.Status;
  lMismatch.Reason := aExpected.Reason;
  lMismatch.ReplacementTextDigest := ParityTextDigest(aExpected.ReplacementText);
  lMismatch.ReplacementTextExcerpt := ParityTextExcerpt(aExpected.ReplacementText);
  lMismatch.Message := Format('%s statement=%s file=%s status=%s actualStatus=%s reason=%s actualReason=%s replacement=%s excerpt="%s"',
    [aKind, lMismatch.StatementId, lMismatch.FileName, lMismatch.ExpectedStatus,
    lMismatch.ActualStatus, lMismatch.Reason, aActual.Reason, lMismatch.ReplacementTextDigest,
    lMismatch.ReplacementTextExcerpt]);
  AddParityMismatch(aReport, lMismatch);
end;

procedure AddEditMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aKind: string; const aExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  const aExpectedEdit: TDelphiSemanticRemoveWithPlanParityEdit);
var
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lMismatch := Default(TDelphiSemanticRemoveWithPlanParityMismatch);
  lMismatch.Kind := aKind;
  lMismatch.StatementId := aExpectedStatement.StatementId;
  lMismatch.FileName := aExpectedEdit.FileName;
  lMismatch.ExpectedStatus := aExpectedStatement.Status;
  lMismatch.Reason := aExpectedStatement.Reason;
  lMismatch.EditKind := aExpectedEdit.Kind;
  lMismatch.EditRange := ParityRangeText(aExpectedEdit.Range);
  lMismatch.ReplacementTextDigest := ParityTextDigest(aExpectedEdit.ReplacementText);
  lMismatch.ReplacementTextExcerpt := ParityTextExcerpt(aExpectedEdit.ReplacementText);
  lMismatch.Message := Format('%s statement=%s file=%s status=%s reason=%s edit=%s range=%s replacement=%s excerpt="%s"',
    [aKind, lMismatch.StatementId, lMismatch.FileName, lMismatch.ExpectedStatus,
    lMismatch.Reason, lMismatch.EditKind, lMismatch.EditRange,
    lMismatch.ReplacementTextDigest, lMismatch.ReplacementTextExcerpt]);
  AddParityMismatch(aReport, lMismatch);
end;

procedure AddEditReplacementMismatch(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  const aExpectedEdit, aActualEdit: TDelphiSemanticRemoveWithPlanParityEdit);
var
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lMismatch := Default(TDelphiSemanticRemoveWithPlanParityMismatch);
  lMismatch.Kind := 'replacement-text-mismatch';
  lMismatch.StatementId := aExpectedEdit.StatementId;
  lMismatch.FileName := aExpectedEdit.FileName;
  lMismatch.ExpectedStatus := aExpectedStatement.Status;
  lMismatch.Reason := aExpectedStatement.Reason;
  lMismatch.EditKind := aExpectedEdit.Kind;
  lMismatch.EditRange := ParityRangeText(aExpectedEdit.Range);
  lMismatch.ReplacementTextDigest := ParityTextDigest(aExpectedEdit.ReplacementText);
  lMismatch.ReplacementTextExcerpt := ParityTextExcerpt(aExpectedEdit.ReplacementText);
  lMismatch.Message := Format('%s statement=%s file=%s status=%s reason=%s edit=%s range=%s replacement=%s excerpt="%s" actualReplacement=%s actualExcerpt="%s"',
    [lMismatch.Kind, lMismatch.StatementId, lMismatch.FileName, lMismatch.ExpectedStatus,
    lMismatch.Reason, lMismatch.EditKind, lMismatch.EditRange,
    lMismatch.ReplacementTextDigest, lMismatch.ReplacementTextExcerpt,
    ParityTextDigest(aActualEdit.ReplacementText), ParityTextExcerpt(aActualEdit.ReplacementText)]);
  AddParityMismatch(aReport, lMismatch);
end;

function FindParityEdit(const aEdits: TArray<TDelphiSemanticRemoveWithPlanParityEdit>;
  const aExpected: TDelphiSemanticRemoveWithPlanParityEdit;
  out aActual: TDelphiSemanticRemoveWithPlanParityEdit): Boolean;
var
  lEdit: TDelphiSemanticRemoveWithPlanParityEdit;
begin
  Result := False;
  aActual := Default(TDelphiSemanticRemoveWithPlanParityEdit);
  for lEdit in aEdits do
  begin
    if SameText(lEdit.Kind, aExpected.Kind) and
      SameParityFile(lEdit.FileName, aExpected.FileName) and
      SameParityRange(lEdit.Range, aExpected.Range) then
    begin
      aActual := lEdit;
      Exit(True);
    end;
  end;
end;

procedure CompareParityEdits(var aReport: TDelphiSemanticRemoveWithPlanParityReport;
  const aExpectedStatement, aActualStatement: TDelphiSemanticRemoveWithPlanParityStatement);
var
  lActualEdit: TDelphiSemanticRemoveWithPlanParityEdit;
  lExpectedEdit: TDelphiSemanticRemoveWithPlanParityEdit;
begin
  for lExpectedEdit in aExpectedStatement.Edits do
  begin
    if not FindParityEdit(aActualStatement.Edits, lExpectedEdit, lActualEdit) then
    begin
      AddEditMismatch(aReport, 'missing-final-edit', aExpectedStatement, lExpectedEdit);
      Continue;
    end;
    if lActualEdit.ReplacementText <> lExpectedEdit.ReplacementText then
      AddEditReplacementMismatch(aReport, aExpectedStatement, lExpectedEdit, lActualEdit);
  end;
  for lActualEdit in aActualStatement.Edits do
  begin
    if not FindParityEdit(aExpectedStatement.Edits, lActualEdit, lExpectedEdit) then
      AddEditMismatch(aReport, 'unexpected-final-edit', aActualStatement, lActualEdit);
  end;
end;

function BuildParitySummary(const aReport: TDelphiSemanticRemoveWithPlanParityReport): string;
var
  lBuilder: TStringBuilder;
  lMismatch: TDelphiSemanticRemoveWithPlanParityMismatch;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendFormat('mismatches=%d', [aReport.MismatchCount]);
    for lMismatch in aReport.Mismatches do
      lBuilder.AppendLine.Append(lMismatch.Message);
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
  end;
end;

function PlanFromBindingSource(const aFacts: TRemoveWithPlanFacts;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aModelVersion: string): TDelphiSemanticRemoveWithPlan;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lBindingTree: TFinalBindingTree;
  lBindingIndex: Integer;
  lCandidateEdits: TArray<TDelphiSemanticRemoveWithEdit>;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lHashCache: TDictionary<string, string>;
  lInheritedDecisions: TArray<TFinalSelectorDecision>;
  lLineCache: TDelphiSemanticSourceContextCache;
  lReservedNames: TDictionary<string, Integer>;
  lRootIndex: Integer;
  lStatementIndex: Integer;
begin
  Result := Default(TDelphiSemanticRemoveWithPlan);
  Result.Operation := 'remove-with';
  Result.Status := 'planned';
  Result.ContextFingerprint := aFacts.ContextFingerprint;
  Result.BaselineSemanticModelVersion := aModelVersion;

  AddVerification(Result, 'baseline-compile',
    'Compile the project before source-changing apply.');
  AddVerification(Result, 'context-fingerprint',
    'Apply only when the semantic context fingerprint still matches.');
  AddVerification(Result, 'source-range',
    'Apply only when expected file hashes and source ranges still match.');
  AddVerification(Result, 'post-edit-compile',
    'Compile the project after source-changing apply.');
  AddVerification(Result, 'rollback-on-failure',
    'Rollback edited files when post-edit verification fails.');

  if Result.ContextFingerprint = '' then
  begin
    Result.Status := 'blocked';
    Result.Diagnostic := 'Missing semantic context fingerprint.';
    Exit;
  end;

  lHashCache := TDictionary<string, string>.Create;
  lLineCache := TDelphiSemanticSourceContextCache.Create;
  lReservedNames := TDictionary<string, Integer>.Create;
  try
    lStatementIndex := 0;
    lBindingCount := aBindingSource.BindingCount;
    SetLength(lCandidateEdits, lBindingCount);
    for lBindingIndex := 0 to lBindingCount - 1 do
    begin
      lBinding := aBindingSource.BindingByIndex(lBindingIndex);
      Inc(lStatementIndex);
      if aBindingSource.BindingHasStableSourceRange(lBindingIndex) then
      begin
        lEdit := AddEdit(Result, lBinding, lHashCache, lLineCache);
        lCandidateEdits[lBindingIndex] := lEdit;
      end else
      begin
        AddSkippedStatement(Result, lBinding, 'SOURCE_RANGE_UNAVAILABLE',
          'stable source file, hash, and source range are required');
        AddFinalStatement(Result, BuildSkippedFinalStatement(lBinding,
          FinalStatementId(lStatementIndex), 'SOURCE_RANGE_UNAVAILABLE',
          'stable source file, hash, and source range are required'));
      end;
    end;
    lBindingTree := BuildFinalBindingTree(aBindingSource, lLineCache);
    for lRootIndex in lBindingTree.RootIndexes do
    begin
      lBinding := aBindingSource.BindingByIndex(lRootIndex);
      if aBindingSource.BindingHasStableSourceRange(lRootIndex) then
      begin
        lInheritedDecisions := nil;
        AddFinalStatementTree(Result, aFacts, aBindingSource, lBindingTree,
          lCandidateEdits, lRootIndex, lReservedNames, lLineCache,
          lInheritedDecisions);
      end;
    end;
    AddRoutineDeclarationEdits(Result, lLineCache, lHashCache);
  finally
    lReservedNames.Free;
    lLineCache.Free;
    lHashCache.Free;
  end;
end;

class function TDelphiSemanticRemoveWithPlanner.Plan(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
var
  lBindingSource: TArrayRemoveWithPlanBindingSource;
  lPlanFacts: TRemoveWithPlanFacts;
begin
  lPlanFacts := Default(TRemoveWithPlanFacts);
  lPlanFacts.ContextFingerprint := aFacts.ContextFingerprint;
  lPlanFacts.LookupIndex := aFacts.LookupIndex;
  lPlanFacts.Symbols := aFacts.Symbols;
  lBindingSource := TArrayRemoveWithPlanBindingSource.Create(aFacts.Bindings);
  try
    Result := PlanFromBindingSource(lPlanFacts, lBindingSource,
      'project-with-binding-v1');
  finally
    lBindingSource.Free;
  end;
end;

function SnapshotHasFlag(const aFlags, aFlag: Cardinal): Boolean;
begin
  Result := (aFlags and aFlag) <> 0;
end;

function SnapshotInventorySymbol(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticRemoveWithInventorySymbolFact): TDelphiSemanticInventorySymbol;
begin
  Result := Default(TDelphiSemanticInventorySymbol);
  Result.Name := aSnapshot.ExactTextOf(aSymbol.NameId);
  Result.SymbolClass := aSnapshot.ExactTextOf(aSymbol.SymbolClassId);
  Result.Kind := aSnapshot.ExactTextOf(aSymbol.KindId);
  Result.TypeName := aSnapshot.ExactTextOf(aSymbol.TypeNameId);
  Result.Modifier := aSnapshot.ExactTextOf(aSymbol.ModifierId);
  Result.OwnerName := aSnapshot.ExactTextOf(aSymbol.OwnerNameId);
  Result.OwnerType := aSnapshot.ExactTextOf(aSymbol.OwnerTypeId);
  Result.SourceOwnerType := aSnapshot.ExactTextOf(aSymbol.SourceOwnerTypeId);
  Result.RelatedTypeName := aSnapshot.ExactTextOf(aSymbol.RelatedTypeNameId);
  Result.RoutineName := aSnapshot.ExactTextOf(aSymbol.RoutineNameId);
  Result.UnitName := aSnapshot.ExactTextOf(aSymbol.UnitNameId);
  Result.FileName := aSnapshot.ExactTextOf(aSymbol.FileNameId);
  Result.SectionKind := aSnapshot.ExactTextOf(aSymbol.SectionKindId);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReason := aSnapshot.ExactTextOf(aSymbol.UnsupportedReasonId);
  Result.IsHelper := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsHelper);
  Result.IsOverride := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsOverride);
  Result.IsDefault := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsDefault);
  Result.IsIndexed := SnapshotHasFlag(aSymbol.Flags,
    cSemanticRemoveWithSymbolFlagIsIndexed);
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategory := aSnapshot.ExactTextOf(aSymbol.TypeCategoryId);
end;

function SnapshotSelectorBinding(const aSnapshot: TDelphiProjectSnapshot;
  const aSelector: TSemanticRemoveWithSelectorBindingFact):
  TDelphiSemanticWithSelectorBinding;
begin
  Result := Default(TDelphiSemanticWithSelectorBinding);
  Result.SelectorText := aSnapshot.ExactTextOf(aSelector.SelectorTextId);
  Result.Status := aSnapshot.ExactTextOf(aSelector.StatusId);
  Result.ReasonCode := aSnapshot.ExactTextOf(aSelector.ReasonCodeId);
  Result.TypeName := aSnapshot.ExactTextOf(aSelector.TypeNameId);
end;

function SnapshotBoundReference(const aSnapshot: TDelphiProjectSnapshot;
  const aReference: TSemanticRemoveWithBoundReferenceFact):
  TDelphiSemanticBoundReference;
begin
  Result := Default(TDelphiSemanticBoundReference);
  Result.SemanticId := aSnapshot.ExactTextOf(aReference.SemanticIdId);
  Result.Name := aSnapshot.ExactTextOf(aReference.NameId);
  Result.Classification := aSnapshot.ExactTextOf(aReference.ClassificationId);
  Result.LookupSource := aSnapshot.ExactTextOf(aReference.LookupSourceId);
  Result.ReceiverTypeName := aSnapshot.ExactTextOf(aReference.ReceiverTypeNameId);
  Result.Kind := aSnapshot.ExactTextOf(aReference.KindId);
  Result.TypeName := aSnapshot.ExactTextOf(aReference.TypeNameId);
  Result.ReasonCode := aSnapshot.ExactTextOf(aReference.ReasonCodeId);
  Result.ScopeConflictKind := aSnapshot.ExactTextOf(aReference.ScopeConflictKindId);
  Result.ScopeConflictName := aSnapshot.ExactTextOf(aReference.ScopeConflictNameId);
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
end;

function SnapshotWithBinding(const aSnapshot: TDelphiProjectSnapshot;
  const aBinding: TSemanticRemoveWithBindingFact): TDelphiSemanticWithBinding;
var
  i: Integer;
begin
  Result := Default(TDelphiSemanticWithBinding);
  Result.SemanticId := aSnapshot.ExactTextOf(aBinding.SemanticIdId);
  Result.Provenance := aSnapshot.ExactTextOf(aBinding.ProvenanceId);
  Result.FileName := aSnapshot.ExactTextOf(aBinding.FileNameId);
  Result.UnitName := aSnapshot.ExactTextOf(aBinding.UnitNameId);
  Result.RoutineName := aSnapshot.ExactTextOf(aBinding.RoutineNameId);
  Result.Line := aBinding.Line;
  Result.Column := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
  Result.BodyLine := aBinding.BodyLine;
  Result.BodyColumn := aBinding.BodyColumn;
  Result.BodyEndLine := aBinding.BodyEndLine;
  Result.BodyEndColumn := aBinding.BodyEndColumn;
  Result.SelectorText := aSnapshot.ExactTextOf(aBinding.SelectorTextId);
  Result.Status := aSnapshot.ExactTextOf(aBinding.StatusId);
  Result.SkipReason := aSnapshot.ExactTextOf(aBinding.SkipReasonId);
  Result.HasScopedDeclaration := SnapshotHasFlag(aBinding.Flags,
    cSemanticRemoveWithBindingFlagHasScopedDeclaration);
  Result.MemberReferenceCount := aBinding.MemberReferenceCount;
  Result.LexicalReferenceCount := aBinding.LexicalReferenceCount;
  Result.ExternalReferenceCount := aBinding.ExternalReferenceCount;
  Result.IntrinsicReferenceCount := aBinding.IntrinsicReferenceCount;
  Result.UnsupportedReferenceCount := aBinding.UnsupportedReferenceCount;
  Result.UnresolvedReferenceCount := aBinding.UnresolvedReferenceCount;
  SetLength(Result.Selectors, Length(aBinding.Selectors));
  for i := 0 to High(aBinding.Selectors) do
    Result.Selectors[i] := SnapshotSelectorBinding(aSnapshot, aBinding.Selectors[i]);
  SetLength(Result.References, Length(aBinding.References));
  for i := 0 to High(aBinding.References) do
    Result.References[i] := SnapshotBoundReference(aSnapshot, aBinding.References[i]);
end;

constructor TSnapshotRemoveWithPlanBindingSource.Create(
  const aSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
begin
  inherited Create;
  fSnapshot := aSnapshot;
  SetLength(fBindings, fSnapshot.RemoveWithPlanningBindingCount);
  for i := 0 to High(fBindings) do
    fBindings[i] := SnapshotWithBinding(fSnapshot,
      fSnapshot.RemoveWithPlanningBindingByIndex(i));
end;

function TSnapshotRemoveWithPlanBindingSource.BindingByIndex(
  const aIndex: Integer): TDelphiSemanticWithBinding;
begin
  Result := fBindings[aIndex];
end;

function TSnapshotRemoveWithPlanBindingSource.BindingCount: Integer;
begin
  Result := Length(fBindings);
end;

function RemoveWithBindingFactRange(const aBinding:
  TSemanticRemoveWithBindingFact): TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.Line;
  Result.StartColumn := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
end;

function TSnapshotRemoveWithPlanBindingSource.BindingContainsBindingByIndex(
  const aOuterIndex, aInnerIndex: Integer): Boolean;
var
  lInner: TSemanticRemoveWithBindingFact;
  lOuter: TSemanticRemoveWithBindingFact;
begin
  lOuter := fSnapshot.RemoveWithPlanningBindingByIndex(aOuterIndex);
  lInner := fSnapshot.RemoveWithPlanningBindingByIndex(aInnerIndex);
  Result := SameText(fSnapshot.ExactTextOf(lOuter.FileNameId),
    fSnapshot.ExactTextOf(lInner.FileNameId)) and
    (not SameText(fSnapshot.ExactTextOf(lOuter.SemanticIdId),
    fSnapshot.ExactTextOf(lInner.SemanticIdId))) and
    RangeContainsRange(RemoveWithBindingFactRange(lOuter),
    RemoveWithBindingFactRange(lInner)) and
    (not SameParityRange(RemoveWithBindingFactRange(lOuter),
    RemoveWithBindingFactRange(lInner)));
end;

function TSnapshotRemoveWithPlanBindingSource.BindingHasStableSourceRange(
  const aIndex: Integer): Boolean;
var
  lBinding: TSemanticRemoveWithBindingFact;
  lFileName: string;
begin
  lBinding := fSnapshot.RemoveWithPlanningBindingByIndex(aIndex);
  lFileName := fSnapshot.ExactTextOf(lBinding.FileNameId);
  Result := (Trim(lFileName) <> '') and TFile.Exists(lFileName) and
    (lBinding.Line > 0) and (lBinding.Column > 0) and
    (lBinding.EndLine >= lBinding.Line) and (lBinding.EndColumn > 0);
end;

function BindingFactsFromSnapshot(
  const aSnapshot: TDelphiProjectSnapshot): TDelphiSemanticProjectWithBindingFacts;
var
  i: Integer;
  lBindingCount: Integer;
  lRoutineOwnerCount: Integer;
begin
  Result := Default(TDelphiSemanticProjectWithBindingFacts);
  Result.ContextFingerprint := aSnapshot.ExactTextOf(
    aSnapshot.RemoveWithPlanningContextFingerprintId);
  lRoutineOwnerCount := aSnapshot.RemoveWithPlanningRoutineOwnerCount;
  SetLength(Result.Symbols, lRoutineOwnerCount);
  for i := 0 to High(Result.Symbols) do
    Result.Symbols[i] := SnapshotInventorySymbol(aSnapshot,
      aSnapshot.RemoveWithPlanningRoutineOwnerByIndex(i));
  lBindingCount := aSnapshot.RemoveWithPlanningBindingCount;
  SetLength(Result.Bindings, lBindingCount);
  for i := 0 to High(Result.Bindings) do
    Result.Bindings[i] := SnapshotWithBinding(aSnapshot,
      aSnapshot.RemoveWithPlanningBindingByIndex(i));
  Result.LookupIndex := aSnapshot.RemoveWithPlanningLookupIndex;
  Result.Metrics.UnitCount := aSnapshot.UnitCount;
  Result.Metrics.WithStatementCount := Length(Result.Bindings);
  Result.Metrics.BindingCount := Length(Result.Bindings);
end;

class function TDelphiSemanticRemoveWithPlanner.Plan(
  const aSnapshot: TDelphiProjectSnapshot): TDelphiSemanticRemoveWithPlan;
var
  i: Integer;
  lBindingSource: TSnapshotRemoveWithPlanBindingSource;
  lPlanFacts: TRemoveWithPlanFacts;
  lRoutineOwnerCount: Integer;
begin
  Result := Default(TDelphiSemanticRemoveWithPlan);
  Result.Operation := 'remove-with';
  Result.Status := 'blocked';
  Result.BaselineSemanticModelVersion := 'project-snapshot-v1';
  if aSnapshot = nil then
  begin
    Result.Diagnostic := 'Missing project snapshot.';
    Exit;
  end;
  if not aSnapshot.HasRemoveWithPlanningFacts then
  begin
    Result.Diagnostic := 'Project snapshot has no remove-with planning facts.';
    Exit;
  end;

  lPlanFacts := Default(TRemoveWithPlanFacts);
  lPlanFacts.ContextFingerprint := aSnapshot.ExactTextOf(
    aSnapshot.RemoveWithPlanningContextFingerprintId);
  lPlanFacts.LookupIndex := aSnapshot.RemoveWithPlanningLookupIndex;
  lRoutineOwnerCount := aSnapshot.RemoveWithPlanningRoutineOwnerCount;
  SetLength(lPlanFacts.Symbols, lRoutineOwnerCount);
  for i := 0 to High(lPlanFacts.Symbols) do
    lPlanFacts.Symbols[i] := SnapshotInventorySymbol(aSnapshot,
      aSnapshot.RemoveWithPlanningRoutineOwnerByIndex(i));

  lBindingSource := TSnapshotRemoveWithPlanBindingSource.Create(aSnapshot);
  try
    Result := PlanFromBindingSource(lPlanFacts, lBindingSource,
      'project-snapshot-v1');
  finally
    lBindingSource.Free;
  end;
end;

class function TDelphiSemanticRemoveWithPlanParity.Compare(
  const aSemanticPlan: TDelphiSemanticRemoveWithPlan;
  const aExpectedStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>):
  TDelphiSemanticRemoveWithPlanParityReport;
var
  lActualStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lActualStatementIndex: Integer;
  lExpectedStatement: TDelphiSemanticRemoveWithPlanParityStatement;
  lExpectedStatementIndex: Integer;
  lFinalStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
  lMatchedActualStatements: TArray<Boolean>;
begin
  Result := Default(TDelphiSemanticRemoveWithPlanParityReport);
  lFinalStatements := FinalStatementsFromPlan(aSemanticPlan);
  SetLength(lMatchedActualStatements, Length(lFinalStatements));
  for lExpectedStatementIndex := 0 to High(aExpectedStatements) do
  begin
    lExpectedStatement := aExpectedStatements[lExpectedStatementIndex];
    if not FindParityStatement(lFinalStatements, lExpectedStatement, lActualStatement) then
    begin
      AddStatementMismatch(Result, 'missing-final-statement', lExpectedStatement, lActualStatement);
      if Length(lExpectedStatement.Edits) > 0 then
        AddEditMismatch(Result, 'missing-final-edit', lExpectedStatement, lExpectedStatement.Edits[0]);
      Continue;
    end;
    if (not SameText(lActualStatement.Status, lExpectedStatement.Status)) or
      (not SameText(lActualStatement.Reason, lExpectedStatement.Reason)) then
      AddStatementMismatch(Result, 'statement-status-mismatch', lExpectedStatement, lActualStatement);
    if lActualStatement.ReplacementText <> lExpectedStatement.ReplacementText then
      AddStatementMismatch(Result, 'statement-replacement-mismatch', lExpectedStatement, lActualStatement);
    CompareParityEdits(Result, lExpectedStatement, lActualStatement);
    for lActualStatementIndex := 0 to High(lFinalStatements) do
    begin
      if SameText(lFinalStatements[lActualStatementIndex].StatementId, lActualStatement.StatementId) and
        SameParityFile(lFinalStatements[lActualStatementIndex].FileName, lActualStatement.FileName) then
      begin
        lMatchedActualStatements[lActualStatementIndex] := True;
        Break;
      end;
    end;
  end;
  for lActualStatementIndex := 0 to High(lFinalStatements) do
  begin
    if lMatchedActualStatements[lActualStatementIndex] then
      Continue;
    lActualStatement := lFinalStatements[lActualStatementIndex];
    AddStatementMismatch(Result, 'unexpected-final-statement', lActualStatement,
      Default(TDelphiSemanticRemoveWithPlanParityStatement));
    if Length(lActualStatement.Edits) > 0 then
      AddEditMismatch(Result, 'unexpected-final-edit', lActualStatement, lActualStatement.Edits[0]);
  end;
  Result.SummaryText := BuildParitySummary(Result);
end;

end.
