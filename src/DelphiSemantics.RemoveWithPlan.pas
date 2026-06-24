unit DelphiSemantics.RemoveWithPlan;

interface

uses
  DelphiSemantics.ProjectContext, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.RemoveWith,
  DelphiSemantics.WithBinding;

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

  TDelphiSemanticRemoveWithStatement = record
    FileName: string;
    StatementId: string;
    Range: TDelphiSemanticRemoveWithSourceRange;
    Status: string;
    Reason: string;
    SafetyReason: string;
    SemanticId: string;
    CoveredByStatementId: string;
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
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
    RequiredVerification: TArray<TDelphiSemanticRemoveWithVerification>;
    Statements: TArray<TDelphiSemanticRemoveWithStatement>;
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
  DelphiSemantics.RemoveWithPlan.FinalBodyRenderer,
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

function TryFindDecisionForSelector(const aDecisions: TArray<TFinalSelectorDecision>;
  const aSelectorText: string; out aDecision: TFinalSelectorDecision): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  aDecision := Default(TFinalSelectorDecision);
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.SelectorText, aSelectorText) then
    begin
      aDecision := lDecision;
      Exit(True);
    end;
  end;
end;

function HasDecisionForSelector(const aDecisions: TArray<TFinalSelectorDecision>;
  const aSelectorText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := TryFindDecisionForSelector(aDecisions, aSelectorText, lDecision);
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

function SelectorBaseDeclaredShapeType(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string): string;
var
  lBaseName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  lBaseName := SelectorBaseIdentifier(aSelectorText);
  if lBaseName = '' then
    Exit;
  if aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, lBaseName,
    lSymbol) then
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
  for lSymbol in aFacts.LookupIndex.FindUnitOrGlobalByName(lBaseName) do
  begin
    Result := SelectorShapeType(aFacts, lSymbol.TypeName, aSelectorText);
    if Result <> '' then
      Exit;
  end;
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

function BindingDependentSelectorQualifier(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aSelectorText,
  aSelectorName: string; out aQualifierText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lPreviousSelector: TDelphiSemanticWithSelectorBinding;
  lPreviousTypeName: string;
begin
  Result := False;
  for lPreviousSelector in aBinding.Selectors do
  begin
    if SameText(lPreviousSelector.SelectorText, aSelectorText) then
      Exit;
    if not TryFindDecisionForSelector(aDecisions, lPreviousSelector.SelectorText,
      lDecision) then
      Continue;
    if SameText(lDecision.Reason, 'skipped-parent-context') or
      (Trim(lDecision.QualifierText) = '') then
      Continue;
    lPreviousTypeName := SelectorShapeType(aFacts, lPreviousSelector.TypeName,
      lPreviousSelector.SelectorText);
    if lPreviousTypeName = '' then
      lPreviousTypeName := SelectorBaseDeclaredShapeType(aFacts, aBinding,
        lPreviousSelector.SelectorText);
    if lPreviousTypeName = '' then
      lPreviousTypeName := lDecision.ReceiverType;
    if (lPreviousTypeName <> '') and
      OwnerHasMemberNamed(aFacts, lPreviousTypeName, aSelectorName) then
    begin
      aQualifierText := lDecision.QualifierText + '.' + aSelectorText;
      Exit(True);
    end;
  end;
end;

function DependentSelectorQualifier(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>; const aSelectorText: string;
  out aQualifierText: string): Boolean;
var
  lDecision: TFinalSelectorDecision;
  lSelectorName: string;
begin
  Result := False;
  aQualifierText := '';
  lSelectorName := SelectorBaseIdentifier(aSelectorText);
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
  Result := BindingDependentSelectorQualifier(aFacts, aBinding, aDecisions,
    aSelectorText, lSelectorName, aQualifierText);
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

function BodyOffsetAppearsQualified(const aBodyText: string;
  const aOffset: Integer): Boolean;
var
  lOffset: Integer;
begin
  Result := False;
  lOffset := aOffset - 1;
  while (lOffset > 0) and CharInSet(aBodyText[lOffset], [#9, #10, #13, ' ']) do
    Dec(lOffset);
  Result := (lOffset > 0) and (aBodyText[lOffset] = '.');
end;

function LineOffsetAppearsQualified(const aLineText: string;
  const aOffset: Integer): Boolean;
var
  lOffset: Integer;
begin
  Result := False;
  lOffset := aOffset - 1;
  while (lOffset > 0) and CharInSet(aLineText[lOffset], [#9, ' ']) do
    Dec(lOffset);
  Result := (lOffset > 0) and (aLineText[lOffset] = '.');
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
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) and
      (not LineOffsetAppearsQualified(lLineText, lSearchOffset)) then
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
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) and
      (not LineOffsetAppearsQualified(lLineText, lSearchOffset)) then
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

function ReferenceLineHasQualifiedOccurrence(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLine: Integer;
  const aLineBreak: string): Boolean;
var
  lCandidateOffset: Integer;
  lLineText: string;
  lSearchOffset: Integer;
begin
  Result := False;
  if (aLine < aBodyRange.StartLine) or (aLine > aBodyRange.EndLine) or
    (aLine < 1) or (aLine > Length(aLines)) or (aReference.Name = '') then
    Exit;

  lLineText := aLines[aLine - 1];
  lSearchOffset := PosEx(aReference.Name, lLineText);
  while lSearchOffset > 0 do
  begin
    if BodyTextIdentifierAt(lLineText, aReference.Name, lSearchOffset) and
      LineOffsetAppearsQualified(lLineText, lSearchOffset) then
    begin
      lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines, aLine,
        lSearchOffset, aLineBreak);
      if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) then
        Exit(True);
    end;
    lSearchOffset := PosEx(aReference.Name, lLineText,
      lSearchOffset + Length(aReference.Name));
  end;
end;

function ReferenceHasQualifiedOccurrenceNearReference(
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference;
  const aLineBreak: string): Boolean;
begin
  Result := ReferenceLineHasQualifiedOccurrence(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line, aLineBreak);
  if Result or (aReference.Line <= aBodyRange.StartLine) then
    Exit;
  Result := ReferenceLineHasQualifiedOccurrence(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line - 1, aLineBreak);
end;

function ReferenceRelativeOffset(const aBodyRange: TDelphiSemanticRemoveWithSourceRange;
  const aLines: TArray<string>; const aBodyText: string;
  const aReference: TDelphiSemanticBoundReference; const aLineBreak: string): Integer;
var
  lCandidateOffset: Integer;
begin
  Result := RangeRelativeOffset(aBodyRange, aLines, aReference.Line,
    aReference.Column, aLineBreak);
  if ReferenceTextMatchesAt(aBodyText, aReference, Result) and
    (not BodyOffsetAppearsQualified(aBodyText, Result)) then
    Exit;

  if aReference.Line > aBodyRange.StartLine then
  begin
    lCandidateOffset := RangeRelativeOffset(aBodyRange, aLines,
      aReference.Line - 1, aReference.Column, aLineBreak);
    if ReferenceTextMatchesAt(aBodyText, aReference, lCandidateOffset) and
      (not BodyOffsetAppearsQualified(aBodyText, lCandidateOffset)) then
      Exit(lCandidateOffset);
  end;

  Result := ReferenceLineOccurrenceRelativeOffset(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line, aLineBreak);
  if Result > 0 then
    Exit;

  if aReference.Line <= aBodyRange.StartLine then
  begin
    Result := 0;
    Exit;
  end;

  Result := ReferenceLineOccurrenceRelativeOffset(aBodyRange, aLines, aBodyText,
    aReference, aReference.Line - 1, aLineBreak);
end;

function ReferenceLookupName(const aReferenceName: string): string;
var
  lDelimiterPos: Integer;

  procedure ConsiderDelimiter(const aPos: Integer);
  begin
    if (aPos > 0) and ((lDelimiterPos = 0) or (aPos < lDelimiterPos)) then
      lDelimiterPos := aPos;
  end;

begin
  Result := aReferenceName;
  lDelimiterPos := 0;
  ConsiderDelimiter(Pos('[', Result));
  ConsiderDelimiter(Pos('.', Result));
  ConsiderDelimiter(Pos('^', Result));
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

function HasHiddenUnresolvedPointerSelectorDecision(
  const aEditDecisions, aValidationDecisions: TArray<TFinalSelectorDecision>):
  Boolean;
var
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  for lDecision in aValidationDecisions do
  begin
    if (Trim(lDecision.ReceiverType) = '') and
      IsSimplePointerDereferenceSelector(lDecision.SelectorText) and
      (not HasDecisionForSelector(aEditDecisions, lDecision.SelectorText)) then
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
    lNextChar := BodyNextNonWhitespaceChar(aBodyText, i);
    if lNextChar = '^' then
      Continue;

    if (not lHasQualifyingReference) and
      ((not BodyOffsetInsideCallOrCastArgument(aBodyText, lStartOffset)) or
      (not DecisionCanQualifyMemberName(aFacts, aDecisions, lName))) then
      Continue;

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

function FinalBodyHasIncompleteReceiverReference(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aLineCache: TDelphiSemanticSourceContextCache;
  const aBodyRange: TDelphiSemanticRemoveWithSourceRange; const aBodyText: string):
  Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
  lQualified: Boolean;
  lReference: TDelphiSemanticBoundReference;
  lName: string;
  lRequiresQualification: Boolean;
  lStartOffset: Integer;

  procedure BodyOffsetToReferenceLocation(var aReference:
    TDelphiSemanticBoundReference; const aOffset: Integer);
  var
    lBodyLine: Integer;
    lColumn: Integer;
    lLineStartOffset: Integer;
    lTextIndex: Integer;
  begin
    lBodyLine := 1;
    lLineStartOffset := 1;
    lTextIndex := 1;
    while (lTextIndex < aOffset) and (lTextIndex <= Length(aBodyText)) do
    begin
      if aBodyText[lTextIndex] = #10 then
      begin
        Inc(lBodyLine);
        lLineStartOffset := lTextIndex + 1;
      end;
      Inc(lTextIndex);
    end;

    lColumn := aOffset - lLineStartOffset + 1;
    aReference.Line := aBodyRange.StartLine + lBodyLine - 1;
    if lBodyLine = 1 then
      aReference.Column := aBodyRange.StartColumn + lColumn - 1
    else
      aReference.Column := lColumn;
    aReference.EndLine := aReference.Line;
    aReference.EndColumn := aReference.Column + Length(aReference.Name) - 1;
  end;
begin
  Result := False;
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

    if BodyOffsetInsideStringLiteral(aBodyText, lStartOffset) or
      BodyOffsetInsideComment(aBodyText, lStartOffset) or
      BodyOffsetAppearsQualified(aBodyText, lStartOffset) or
      RoutineScopeSymbolNamed(aFacts, aBinding, lName) or
      BodyDeclaresInlineVarName(aBodyText, lName) then
      Continue;

    lReference := Default(TDelphiSemanticBoundReference);
    lReference.Name := lName;
    BodyOffsetToReferenceLocation(lReference, lStartOffset);
    if ReferenceCanRemainUnchanged(aFacts, aBinding, lReference) or
      ReferenceLooksLikeLocalLabel(aBinding, lReference, aLineCache) then
      Continue;

    lQualified := False;
    lRequiresQualification := False;
    for lDecision in aDecisions do
    begin
      if (Trim(lDecision.QualifierText) = '') or
        (Trim(lDecision.ReceiverType) = '') then
        Continue;
      if not OwnerHasMemberNamed(aFacts, lDecision.ReceiverType, lName) then
        Continue;

      lRequiresQualification := True;
      if BodyOffsetInsideTextOccurrence(aBodyText, lDecision.QualifierText,
        lStartOffset) or BodyOffsetHasTextQualifier(aBodyText,
        lDecision.QualifierText, lStartOffset) then
        lQualified := True;
    end;
    if lRequiresQualification and (not lQualified) then
      Exit(True);
  end;
end;

function PrepareFinalBodyText(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aEditDecisions, aValidationDecisions: TArray<TFinalSelectorDecision>;
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
    if ReferenceBlocksFinalRewrite(aFacts, aBinding, aEditDecisions, lReference,
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
        (not ActiveDecisionHasMember(aFacts, aEditDecisions, lReference.Name)) then
        Continue;
    end;
    if not QualifierForReference(aFacts, aBinding, aEditDecisions, lReference, lQualifierText) then
    begin
      if HasHiddenUnresolvedPointerSelectorDecision(aEditDecisions,
        aValidationDecisions) and
        (not ReferenceCanRemainUnchanged(aFacts, aBinding, lReference)) and
        (not ReferenceLooksLikeLocalLabel(aBinding, lReference, aLineCache)) and
        (not ReferenceAppearsQualified(lReference, aBinding, aLineCache)) then
      begin
        aReason := 'semantic-rewrite-incomplete';
        Exit;
      end;
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
      if ReferenceHasQualifiedOccurrenceNearReference(lBodyRange, lLines,
        aReplacementText, lReference, lLineBreak) then
        Continue;
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
    lReferenceName := ReferenceNameWithQualifiedArguments(aFacts, aEditDecisions,
      lReference.Name);
    AddFinalBodyEdit(lBodyEdits, lOffset, Length(lReference.Name),
      lReference.Name, lQualifierText + '.' + lReferenceName);
  end;
  AddSimpleMemberBodyEdits(aFacts, aBinding, aEditDecisions, aReplacementText,
    lBodyEdits);
  AddIndexedMemberBodyEdits(aFacts, aBinding, aEditDecisions, aReplacementText,
    lBodyEdits);
  AddDependentSelectorBodyEdits(aEditDecisions, aReplacementText, lBodyEdits);
  ApplyFinalBodyEdits(lBodyEdits, aReplacementText);
  if FinalBodyHasIncompleteReceiverReference(aFacts, aBinding, aValidationDecisions,
    aLineCache, lBodyRange, aReplacementText) then
  begin
    aReason := 'semantic-rewrite-incomplete';
    Exit;
  end;
  while StartsText(lLineBreak, aReplacementText) do
    Delete(aReplacementText, 1, Length(lLineBreak));
  while StartsText(#13, aReplacementText) or StartsText(#10, aReplacementText) do
    Delete(aReplacementText, 1, 1);
  if (not aPreserveLeadingIndent) and
    StartsText(IndentText(aBinding.Column), aReplacementText) then
    Delete(aReplacementText, 1, Length(IndentText(aBinding.Column)));

  Result := True;
end;

function RendererRange(const aRange: TDelphiSemanticRemoveWithSourceRange):
  TFinalBodyRendererRange;
begin
  Result.StartLine := aRange.StartLine;
  Result.StartColumn := aRange.StartColumn;
  Result.EndLine := aRange.EndLine;
  Result.EndColumn := aRange.EndColumn;
end;

function PlannerRange(const aRange: TFinalBodyRendererRange):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aRange.StartLine;
  Result.StartColumn := aRange.StartColumn;
  Result.EndLine := aRange.EndLine;
  Result.EndColumn := aRange.EndColumn;
end;

function RendererSelectorDecision(const aDecision: TFinalSelectorDecision):
  TFinalBodyRendererSelectorDecision;
begin
  Result.SelectorText := aDecision.SelectorText;
  Result.QualifierText := aDecision.QualifierText;
  Result.Strategy := aDecision.Strategy;
  Result.ReceiverType := aDecision.ReceiverType;
  Result.TempName := aDecision.TempName;
  Result.DeclarationText := aDecision.DeclarationText;
  Result.InitializationText := aDecision.InitializationText;
  Result.Reason := aDecision.Reason;
end;

function RendererSelectorDecisions(const aDecisions: TArray<TFinalSelectorDecision>):
  TArray<TFinalBodyRendererSelectorDecision>;
var
  i: Integer;
begin
  SetLength(Result, Length(aDecisions));
  for i := 0 to High(aDecisions) do
    Result[i] := RendererSelectorDecision(aDecisions[i]);
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

function TryRenderFinalReplacementText(const aFacts: TRemoveWithPlanFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aVisibleDecisions, aValidationDecisions,
  aTempDecisions: TArray<TFinalSelectorDecision>;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aLineCache: TDelphiSemanticSourceContextCache; out aReplacementText,
  aReason: string; out aReplacementRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
var
  lBodyText: string;
  lControlledStatement: Boolean;
  lOriginalRange: TDelphiSemanticRemoveWithSourceRange;
  lRendererRange: TFinalBodyRendererRange;
  lRequest: TFinalBodyRendererRequest;
  lTrimmedBeforeOuterElse: Boolean;
begin
  Result := False;
  aReplacementRange := BindingRange(aBinding);
  lOriginalRange := aReplacementRange;
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
  if not PrepareFinalBodyText(aFacts, aBinding, aVisibleDecisions,
    aValidationDecisions, aNestedReplacements, aLineCache, lControlledStatement,
    lBodyText, aReason) then
  begin
    Exit;
  end;

  lRequest := Default(TFinalBodyRendererRequest);
  lRequest.Binding := aBinding;
  lRequest.BodyText := lBodyText;
  lRequest.OriginalRange := RendererRange(lOriginalRange);
  lRequest.ReplacementRange := RendererRange(aReplacementRange);
  lRequest.TempDecisions := RendererSelectorDecisions(aTempDecisions);
  lRequest.ControlledStatement := lControlledStatement;
  lRequest.TrimmedBeforeOuterElse := lTrimmedBeforeOuterElse;
  Result := DelphiSemantics.RemoveWithPlan.FinalBodyRenderer.BuildFinalReplacementText(
    lRequest, aLineCache, aReplacementText, lRendererRange, aReason);
  aReplacementRange := PlannerRange(lRendererRange);
end;

function ReplacementRangeCoversExpectedWithRange(
  const aBinding: TDelphiSemanticWithBinding;
  const aReplacementRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TDelphiSemanticSourceContextCache): Boolean;
var
  lExpectedRange: TDelphiSemanticRemoveWithSourceRange;
begin
  lExpectedRange := BindingRange(aBinding);
  TrimRangeBeforeOuterElse(aBinding, aLineCache, lExpectedRange);
  Result := ((aReplacementRange.StartLine < lExpectedRange.StartLine) or
    ((aReplacementRange.StartLine = lExpectedRange.StartLine) and
    (aReplacementRange.StartColumn <= lExpectedRange.StartColumn))) and
    ((aReplacementRange.EndLine > lExpectedRange.EndLine) or
    ((aReplacementRange.EndLine = lExpectedRange.EndLine) and
    (aReplacementRange.EndColumn >= lExpectedRange.EndColumn)));
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

function SelectorDecisionsWithAdditional(
  const aBaseDecisions, aAdditionalDecisions: TArray<TFinalSelectorDecision>):
  TArray<TFinalSelectorDecision>;
var
  lDecision: TFinalSelectorDecision;
  lIndex: Integer;
begin
  Result := Copy(aBaseDecisions);
  for lDecision in aAdditionalDecisions do
  begin
    lIndex := Length(Result);
    SetLength(Result, lIndex + 1);
    Result[lIndex] := lDecision;
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
  lReason: string;
  lReplacementText: string;
  lRecipe: TDelphiSemanticRemoveWithRewriteRecipe;
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
  lVisibleDecisions := Copy(aInheritedDecisions);
  if BindingFactSkipReason(aFacts, lBinding, aLineCache, lReason) then
  begin
    Result.Status := 'skipped';
    Result.Reason := lReason;
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
      Result.SafetyReason := Result.Reason;
      Exit;
    end;
    if not BuildSelectorDecision(aFacts, lBinding, lSelector.SelectorText,
      aReservedNames, aInheritedDecisions, aLineCache, lDecision, lReason) then
    begin
      RollbackReservedTempNamesForDecisions(aReservedNames,
        lBinding.RoutineName, lSelectorDecisions);
      Result.Status := 'skipped';
      Result.Reason := lReason;
      Result.SafetyReason := Result.Reason;
      Exit;
    end;
    QualifyDecisionInitializationDependencies(aFacts, lSelectorDecisions,
      lDecision);
    if DependentSelectorQualifier(aFacts, lBinding, lSelectorDecisions,
      lSelector.SelectorText, lSelectorQualifierText) then
    begin
      lDecision.Strategy := 'direct-qualification';
      lDecision.TempName := '';
      lDecision.DeclarationText := '';
      lDecision.InitializationText := '';
      lDecision.QualifierText := lSelectorQualifierText;
      lDecision.Reason := 'dependent-selector-direct-qualification';
    end else if SameText(lDecision.Strategy, 'direct-qualification') and
      DependentSelectorQualifier(aFacts, lBinding, aInheritedDecisions,
      lSelector.SelectorText, lSelectorQualifierText) then
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
      if SameText(lChildStatement.Reason, 'semantic-rewrite-incomplete') or
        SameText(lChildStatement.Reason, 'covered-child-rewrite-incomplete') then
      begin
        Result.Reason := 'covered-child-rewrite-incomplete';
        Result.SafetyReason := Result.Reason;
      end else
      begin
        Result.Reason := lChildStatement.Reason;
        Result.SafetyReason := lChildStatement.SafetyReason;
      end;
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

  lDecisions := SelectorDecisionsWithAdditional(aInheritedDecisions,
    lSelectorDecisions);
  if not TryRenderFinalReplacementText(aFacts, lBinding, lVisibleDecisions,
    lDecisions, lSelectorDecisions, lNestedReplacements, aLineCache,
    lReplacementText, lReason, lReplacementRange) then
  begin
    RollbackReservedTempNamesForDecisions(aReservedNames,
      lBinding.RoutineName, lSelectorDecisions);
    RollbackReservedTempNamesForFinalTemps(aReservedNames,
      lBinding.RoutineName, Result.Temps);
    Result.Status := 'skipped';
    Result.Reason := lReason;
    Result.SafetyReason := Result.Reason;
    Exit;
  end;
  if not ReplacementRangeCoversExpectedWithRange(lBinding, lReplacementRange,
    aLineCache) then
  begin
    RollbackReservedTempNamesForDecisions(aReservedNames,
      lBinding.RoutineName, lSelectorDecisions);
    RollbackReservedTempNamesForFinalTemps(aReservedNames,
      lBinding.RoutineName, Result.Temps);
    Result.Status := 'skipped';
    Result.Reason := 'replace-statement-range-mismatch';
    Result.SafetyReason := Result.Reason;
    Exit;
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

function SkippedStatementFromStatement(
  const aStatement: TDelphiSemanticRemoveWithStatement):
  TDelphiSemanticRemoveWithSkippedStatement;
begin
  Result.FileName := aStatement.FileName;
  Result.StatementId := aStatement.StatementId;
  Result.Range := aStatement.Range;
  Result.Reason := aStatement.Reason;
  Result.SafetyReason := aStatement.SafetyReason;
  Result.SemanticId := aStatement.SemanticId;
end;

function FindFinalStatementById(const aPlan: TDelphiSemanticRemoveWithPlan;
  const aStatementId: string;
  out aStatement: TDelphiSemanticRemoveWithFinalStatement): Boolean;
var
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  Result := False;
  aStatement := Default(TDelphiSemanticRemoveWithFinalStatement);
  for lStatement in aPlan.FinalStatements do
  begin
    if SameText(lStatement.StatementId, aStatementId) then
    begin
      aStatement := lStatement;
      Exit(True);
    end;
  end;
end;

function FinalBindingParentIndexesFromTree(
  const aBindingTree: TFinalBindingTree): TFinalBindingIndexArray;
var
  lChildIndex: Integer;
  lIndex: Integer;
  lParentIndex: Integer;
begin
  SetLength(Result, Length(aBindingTree.ChildIndexes));
  for lIndex := 0 to High(Result) do
    Result[lIndex] := -1;

  for lParentIndex := 0 to High(aBindingTree.ChildIndexes) do
    for lChildIndex in aBindingTree.ChildIndexes[lParentIndex] do
      Result[lChildIndex] := lParentIndex;
end;

function CoveringFinalStatementId(const aPlan: TDelphiSemanticRemoveWithPlan;
  const aParentIndexes: TFinalBindingIndexArray; const aBindingIndex: Integer):
  string;
var
  lParentIndex: Integer;
  lParentStatement: TDelphiSemanticRemoveWithFinalStatement;
  lParentStatementId: string;
begin
  Result := '';
  lParentIndex := aParentIndexes[aBindingIndex];
  while lParentIndex >= 0 do
  begin
    lParentStatementId := FinalStatementId(lParentIndex + 1);
    if FindFinalStatementById(aPlan, lParentStatementId, lParentStatement) and
      SameText(lParentStatement.Status, 'planned') then
      Exit(lParentStatementId);
    lParentIndex := aParentIndexes[lParentIndex];
  end;
end;

function StatementFromBinding(const aBinding: TDelphiSemanticWithBinding;
  const aStatementId: string): TDelphiSemanticRemoveWithStatement;
begin
  Result := Default(TDelphiSemanticRemoveWithStatement);
  Result.FileName := aBinding.FileName;
  Result.StatementId := aStatementId;
  Result.Range := BindingRange(aBinding);
  Result.SemanticId := aBinding.SemanticId;
end;

procedure ApplyFinalStatementToStatement(
  const aFinalStatement: TDelphiSemanticRemoveWithFinalStatement;
  var aStatement: TDelphiSemanticRemoveWithStatement);
begin
  aStatement.FileName := aFinalStatement.FileName;
  aStatement.StatementId := aFinalStatement.StatementId;
  aStatement.Range := aFinalStatement.Range;
  aStatement.Status := aFinalStatement.Status;
  aStatement.Reason := aFinalStatement.Reason;
  aStatement.SafetyReason := aFinalStatement.SafetyReason;
  aStatement.SemanticId := aFinalStatement.SemanticId;
  aStatement.CoveredByStatementId := '';
end;

procedure RefreshSkippedStatementsFromStatements(
  var aPlan: TDelphiSemanticRemoveWithPlan);
var
  lIndex: Integer;
  lStatementIndex: Integer;
begin
  SetLength(aPlan.SkippedStatements, 0);
  for lStatementIndex := 0 to High(aPlan.Statements) do
  begin
    if not SameText(aPlan.Statements[lStatementIndex].Status, 'skipped') then
      Continue;
    lIndex := Length(aPlan.SkippedStatements);
    SetLength(aPlan.SkippedStatements, lIndex + 1);
    aPlan.SkippedStatements[lIndex] := SkippedStatementFromStatement(
      aPlan.Statements[lStatementIndex]);
  end;
end;

procedure RefreshStatementsFromBindings(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aBindingSource: TRemoveWithPlanBindingSource;
  const aBindingTree: TFinalBindingTree);
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingIndex: Integer;
  lCoveredByStatementId: string;
  lFinalStatement: TDelphiSemanticRemoveWithFinalStatement;
  lParentIndexes: TFinalBindingIndexArray;
  lStatement: TDelphiSemanticRemoveWithStatement;
  lStatementId: string;
begin
  lParentIndexes := FinalBindingParentIndexesFromTree(aBindingTree);
  SetLength(aPlan.Statements, aBindingSource.BindingCount);
  for lBindingIndex := 0 to aBindingSource.BindingCount - 1 do
  begin
    lBinding := aBindingSource.BindingByIndex(lBindingIndex);
    lStatementId := FinalStatementId(lBindingIndex + 1);
    lStatement := StatementFromBinding(lBinding, lStatementId);
    if FindFinalStatementById(aPlan, lStatementId, lFinalStatement) then
      ApplyFinalStatementToStatement(lFinalStatement, lStatement)
    else
    begin
      lCoveredByStatementId := CoveringFinalStatementId(aPlan, lParentIndexes,
        lBindingIndex);
      if lCoveredByStatementId <> '' then
      begin
        lStatement.Status := 'planned';
        lStatement.Reason := 'covered-by-parent-rewrite';
        lStatement.CoveredByStatementId := lCoveredByStatementId;
      end else
      begin
        lStatement.Status := 'skipped';
        lStatement.Reason := 'planner-status-unresolved';
        lStatement.SafetyReason :=
          'planner did not produce a final decision for this with statement';
      end;
    end;
    aPlan.Statements[lBindingIndex] := lStatement;
  end;
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
    RefreshStatementsFromBindings(Result, aBindingSource, lBindingTree);
    RefreshSkippedStatementsFromStatements(Result);
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
