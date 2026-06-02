unit DelphiSemantics.RemoveWithPlan;

interface

uses
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
      TDelphiSemanticRemoveWithPlan; static;
  end;

  TDelphiSemanticRemoveWithPlanParity = record
  public
    class function Compare(const aSemanticPlan: TDelphiSemanticRemoveWithPlan;
      const aExpectedStatements: TArray<TDelphiSemanticRemoveWithPlanParityStatement>):
      TDelphiSemanticRemoveWithPlanParityReport; static;
  end;

implementation

uses
  System.Generics.Collections, System.Hash, System.IOUtils, System.StrUtils,
  System.SysUtils;

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
    ReplacementText: string;
  end;

  TFinalNestedReplacement = record
    Range: TDelphiSemanticRemoveWithSourceRange;
    ReplacementText: string;
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

function SourceTextForRange(const aFileName: string;
  const aRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TDictionary<string, TArray<string>>): string;
var
  lBuilder: TStringBuilder;
  lEndColumn: Integer;
  lLine: string;
  lLineIndex: Integer;
  lLines: TArray<string>;
  lStartColumn: Integer;
begin
  Result := '';
  if (aRange.StartLine <= 0) or (aRange.EndLine <= 0) or
    (not TFile.Exists(aFileName)) then
    Exit;

  if (not Assigned(aLineCache)) or (not aLineCache.TryGetValue(aFileName, lLines)) then
  begin
    lLines := TFile.ReadAllLines(aFileName);
    if Assigned(aLineCache) then
      aLineCache.AddOrSetValue(aFileName, lLines);
  end;
  if (aRange.StartLine > Length(lLines)) or (aRange.EndLine > Length(lLines)) then
    Exit;

  lBuilder := TStringBuilder.Create;
  try
    for lLineIndex := aRange.StartLine to aRange.EndLine do
    begin
      lLine := lLines[lLineIndex - 1];
      lStartColumn := 1;
      if lLineIndex = aRange.StartLine then
        lStartColumn := aRange.StartColumn;
      lEndColumn := Length(lLine) + 1;
      if lLineIndex = aRange.EndLine then
        lEndColumn := aRange.EndColumn;
      if lStartColumn < 1 then
        lStartColumn := 1;
      if lEndColumn < lStartColumn then
        lEndColumn := lStartColumn;
      if lEndColumn > Length(lLine) then
        lEndColumn := Length(lLine);
      if lStartColumn <= Length(lLine) then
        lBuilder.Append(Copy(lLine, lStartColumn, lEndColumn - lStartColumn + 1));
      if lLineIndex < aRange.EndLine then
        lBuilder.Append(sLineBreak);
    end;
    Result := lBuilder.ToString;
  finally
    lBuilder.Free;
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

function BindingBodyRange(const aBinding: TDelphiSemanticWithBinding):
  TDelphiSemanticRemoveWithSourceRange;
begin
  Result.StartLine := aBinding.BodyLine;
  Result.StartColumn := aBinding.BodyColumn;
  Result.EndLine := aBinding.BodyEndLine;
  Result.EndColumn := aBinding.BodyEndColumn;
end;

function ReferenceInsideRange(const aReference: TDelphiSemanticBoundReference;
  const aRange: TDelphiSemanticRemoveWithSourceRange): Boolean;
begin
  Result := ((aReference.Line > aRange.StartLine) or
    ((aReference.Line = aRange.StartLine) and (aReference.Column >= aRange.StartColumn))) and
    ((aReference.Line < aRange.EndLine) or
    ((aReference.Line = aRange.EndLine) and (aReference.Column <= aRange.EndColumn)));
end;

function TypeIsClassLike(const aFacts: TDelphiSemanticProjectWithBindingFacts;
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

function SelectorTypeName(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aSelectorText: string): string;
var
  lReference: TDelphiSemanticBoundReference;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectorName: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := '';
  for lSelector in aBinding.Selectors do
  begin
    if SameText(lSelector.SelectorText, aSelectorText) and (Trim(lSelector.TypeName) <> '') then
      Exit(lSelector.TypeName);
  end;
  lSelectorName := Trim(aSelectorText);
  if EndsText('^', lSelectorName) then
    lSelectorName := Copy(lSelectorName, 1, Length(lSelectorName) - 1);
  if aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, lSelectorName,
    lSymbol) then
  begin
    Result := lSymbol.TypeName;
    if EndsText('^', Trim(aSelectorText)) then
      Result := aFacts.LookupIndex.PointerTargetType(Result);
    if Result <> '' then
      Exit;
  end;
  for lReference in aBinding.References do
  begin
    if Trim(lReference.ReceiverTypeName) <> '' then
      Exit(lReference.ReceiverTypeName);
  end;
end;

function ReferenceIsRoutineSymbol(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBinding: TDelphiSemanticWithBinding; const aReferenceName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := aFacts.LookupIndex.FindRoutineSymbol(aBinding.RoutineName, aReferenceName,
    lSymbol);
end;

function ReservedTempName(const aReservedNames: TDictionary<string, Integer>;
  const aRoutineName, aBaseName: string): string;
var
  lCount: Integer;
  lKey: string;
begin
  lKey := aRoutineName + #31 + aBaseName;
  if not aReservedNames.TryGetValue(lKey, lCount) then
    lCount := 0;
  if lCount = 0 then
    Result := aBaseName
  else
    Result := aBaseName + IntToStr(lCount);
  aReservedNames.AddOrSetValue(lKey, lCount + 1);
end;

function BuildSelectorDecision(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBinding: TDelphiSemanticWithBinding; const aSelectorText: string;
  const aReservedNames: TDictionary<string, Integer>; out aDecision: TFinalSelectorDecision;
  out aReason: string): Boolean;
var
  lBaseName: string;
  lTypeSuffix: string;
begin
  Result := False;
  aReason := '';
  aDecision := Default(TFinalSelectorDecision);
  aDecision.SelectorText := aSelectorText;
  aDecision.ReceiverType := SelectorTypeName(aFacts, aBinding, aSelectorText);

  if ContainsText(aSelectorText, '(') then
  begin
    aReason := 'call-selector';
    Exit;
  end;
  if ContainsText(aSelectorText, '.') then
  begin
    aReason := 'property-selector';
    Exit;
  end;
  if ContainsText(aSelectorText, '^') then
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

  lTypeSuffix := RemoveLeadingTypePrefix(aDecision.ReceiverType);
  if TypeIsClassLike(aFacts, aDecision.ReceiverType) then
  begin
    lBaseName := 'lWith' + lTypeSuffix;
    aDecision.Strategy := 'reference-temp';
    aDecision.TempName := ReservedTempName(aReservedNames, aBinding.RoutineName, lBaseName);
    aDecision.QualifierText := aDecision.TempName;
    aDecision.DeclarationText := aDecision.TempName + ': ' + aDecision.ReceiverType + ';';
    aDecision.InitializationText := aDecision.TempName + ' := ' + aSelectorText + ';';
    aDecision.Reason := 'reference-temp-preserves-evaluation';
  end else
  begin
    lBaseName := 'lWith' + lTypeSuffix + 'Ptr';
    aDecision.Strategy := 'record-pointer-temp';
    aDecision.TempName := ReservedTempName(aReservedNames, aBinding.RoutineName, lBaseName);
    aDecision.QualifierText := aDecision.TempName + '^';
    aDecision.DeclarationText := aDecision.TempName + ': ^' + aDecision.ReceiverType + ';';
    aDecision.InitializationText := aDecision.TempName + ' := @' + aSelectorText + ';';
    aDecision.Reason := 'record-pointer-preserves-alias';
  end;
  Result := True;
end;

procedure AddFinalBodyEdit(var aEdits: TArray<TFinalBodyEdit>; const aOffset,
  aLength: Integer; const aReplacementText: string);
var
  lIndex: Integer;
begin
  lIndex := Length(aEdits);
  SetLength(aEdits, lIndex + 1);
  aEdits[lIndex].Offset := aOffset;
  aEdits[lIndex].Length := aLength;
  aEdits[lIndex].ReplacementText := aReplacementText;
end;

function RangeRelativeOffset(const aRange: TDelphiSemanticRemoveWithSourceRange;
  const aLineCache: TArray<string>; const aLine, aColumn: Integer): Integer;
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
    Inc(Result, Length(sLineBreak));
  end;
  if aLine = aRange.StartLine then
    Inc(Result, aColumn - aRange.StartColumn)
  else
    Inc(Result, aColumn - 1);
end;

function QualifierForReference(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aReference: TDelphiSemanticBoundReference; out aQualifierText: string): Boolean;
var
  i: Integer;
  lDecision: TFinalSelectorDecision;
begin
  Result := False;
  aQualifierText := '';
  if aReference.ReceiverTypeName = '' then
  begin
    for i := High(aDecisions) downto 0 do
    begin
      lDecision := aDecisions[i];
      if Length(aFacts.LookupIndex.FindMembersByOwnerAndName(
        lDecision.ReceiverType, aReference.Name)) > 0 then
      begin
        aQualifierText := lDecision.QualifierText;
        Exit(True);
      end;
    end;
    Exit;
  end;
  for lDecision in aDecisions do
  begin
    if SameText(lDecision.ReceiverType, aReference.ReceiverTypeName) then
    begin
      aQualifierText := lDecision.QualifierText;
      Exit(True);
    end;
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
    Delete(aText, aEdits[lBestIndex].Offset, aEdits[lBestIndex].Length);
    Insert(aEdits[lBestIndex].ReplacementText, aText, aEdits[lBestIndex].Offset);
  end;
end;

function RewrittenBodyText(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aDecisions: TArray<TFinalSelectorDecision>;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aLineCache: TDictionary<string, TArray<string>>; out aReplacementText,
  aReason: string): Boolean;
var
  lBodyEdits: TArray<TFinalBodyEdit>;
  lBodyRange: TDelphiSemanticRemoveWithSourceRange;
  lLines: TArray<string>;
  lNestedRange: TDelphiSemanticRemoveWithSourceRange;
  lNestedReplacement: TFinalNestedReplacement;
  lOffset: Integer;
  lQualifierText: string;
  lReference: TDelphiSemanticBoundReference;
begin
  Result := False;
  aReason := '';
  lBodyRange := BindingBodyRange(aBinding);
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

  for lNestedReplacement in aNestedReplacements do
  begin
    lNestedRange := lNestedReplacement.Range;
    lNestedRange.StartColumn := 1;
    lOffset := RangeRelativeOffset(lBodyRange, lLines, lNestedRange.StartLine,
      lNestedRange.StartColumn);
    AddFinalBodyEdit(lBodyEdits, lOffset,
      Length(SourceTextForRange(aBinding.FileName, lNestedRange, aLineCache)),
      lNestedReplacement.ReplacementText);
  end;

  for lReference in aBinding.References do
  begin
    if not ReferenceInsideRange(lReference, lBodyRange) then
      Continue;
    if not QualifierForReference(aFacts, aDecisions, lReference, lQualifierText) then
    begin
      if SameText(lReference.Classification, 'unresolved') then
      begin
        if ReferenceIsRoutineSymbol(aFacts, aBinding, lReference.Name) then
          Continue;
        aReason := 'symbol-not-found';
        Exit;
      end;
      Continue;
    end;
    lOffset := RangeRelativeOffset(lBodyRange, lLines, lReference.Line,
      lReference.Column);
    AddFinalBodyEdit(lBodyEdits, lOffset, Length(lReference.Name),
      lQualifierText + '.' + lReference.Name);
  end;
  ApplyFinalBodyEdits(lBodyEdits, aReplacementText);
  while StartsText(sLineBreak, aReplacementText) do
    Delete(aReplacementText, 1, Length(sLineBreak));
  while StartsText(#13, aReplacementText) or StartsText(#10, aReplacementText) do
    Delete(aReplacementText, 1, 1);
  if StartsText(IndentText(aBinding.Column), aReplacementText) then
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

function BuildFinalReplacementText(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBinding: TDelphiSemanticWithBinding;
  const aVisibleDecisions, aTempDecisions: TArray<TFinalSelectorDecision>;
  const aNestedReplacements: TArray<TFinalNestedReplacement>;
  const aLineCache: TDictionary<string, TArray<string>>; out aReplacementText,
  aReason: string): Boolean;
var
  lBodyText: string;
  lControlledStatement: Boolean;
  lIndentColumn: Integer;
  lLines: TArray<string>;
  lLineText: string;
  lPreviousLineIndex: Integer;
  lStatementIndent: string;
  lTempText: string;
begin
  Result := False;
  if not RewrittenBodyText(aFacts, aBinding, aVisibleDecisions,
    aNestedReplacements, aLineCache, lBodyText, aReason) then
    Exit;

  lControlledStatement := False;
  if aLineCache.TryGetValue(aBinding.FileName, lLines) then
  begin
    for lPreviousLineIndex := aBinding.Line - 1 downto 1 do
    begin
      lLineText := Trim(lLines[lPreviousLineIndex - 1]);
      if (lLineText = '') or StartsText('//', lLineText) then
        Continue;
      lControlledStatement := EndsText(' then', LowerCase(lLineText)) or
        SameText(lLineText, 'then') or EndsText(' do', LowerCase(lLineText)) or
        SameText(lLineText, 'do') or EndsText(':', lLineText);
      Break;
    end;
  end;
  if lControlledStatement then
    lIndentColumn := aBinding.Column + 2
  else
    lIndentColumn := aBinding.Column;
  lTempText := BuildTempInitializationText(aTempDecisions, lIndentColumn);
  aReplacementText := lTempText + IndentText(lIndentColumn) + lBodyText;
  if lControlledStatement then
  begin
    lStatementIndent := IndentText(aBinding.Column);
    aReplacementText := lStatementIndent + 'begin' + sLineBreak +
      aReplacementText + sLineBreak + lStatementIndent + 'end;';
  end;
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

procedure AddFinalTextEdit(var aStatement: TDelphiSemanticRemoveWithFinalStatement;
  const aEdit: TDelphiSemanticRemoveWithFinalTextEdit; const aPrepend: Boolean);
var
  i: Integer;
  lIndex: Integer;
begin
  if aPrepend then
  begin
    SetLength(aStatement.Edits, Length(aStatement.Edits) + 1);
    for i := High(aStatement.Edits) downto 1 do
      aStatement.Edits[i] := aStatement.Edits[i - 1];
    aStatement.Edits[0] := aEdit;
  end else
  begin
    lIndex := Length(aStatement.Edits);
    SetLength(aStatement.Edits, lIndex + 1);
    aStatement.Edits[lIndex] := aEdit;
  end;
end;

procedure AddFinalStatement(var aPlan: TDelphiSemanticRemoveWithPlan;
  const aStatement: TDelphiSemanticRemoveWithFinalStatement);
var
  lIndex: Integer;
begin
  lIndex := Length(aPlan.FinalStatements);
  SetLength(aPlan.FinalStatements, lIndex + 1);
  aPlan.FinalStatements[lIndex] := aStatement;
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

function BuildFinalStatement(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBindings: TArray<TDelphiSemanticWithBinding>; const aBindingIndex: Integer;
  const aStatementId: string; const aCandidateEdit: TDelphiSemanticRemoveWithEdit;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDictionary<string, TArray<string>>;
  const aInheritedDecisions: TArray<TFinalSelectorDecision>):
  TDelphiSemanticRemoveWithFinalStatement; overload; forward;

function IsDirectNestedBinding(const aBindings: TArray<TDelphiSemanticWithBinding>;
  const aOuter, aInner: TDelphiSemanticWithBinding): Boolean; forward;

function BuildFinalStatement(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBinding: TDelphiSemanticWithBinding; const aStatementId: string;
  const aCandidateEdit: TDelphiSemanticRemoveWithEdit;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDictionary<string, TArray<string>>):
  TDelphiSemanticRemoveWithFinalStatement; overload;
begin
  Result := BuildFinalStatement(aFacts, [aBinding], 0, aStatementId,
    aCandidateEdit, aReservedNames, aLineCache, nil);
end;

function BuildFinalStatement(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aBindings: TArray<TDelphiSemanticWithBinding>; const aBindingIndex: Integer;
  const aStatementId: string; const aCandidateEdit: TDelphiSemanticRemoveWithEdit;
  const aReservedNames: TDictionary<string, Integer>;
  const aLineCache: TDictionary<string, TArray<string>>;
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
  lReason: string;
  lReplacementText: string;
  lSelectorDecisions: TArray<TFinalSelectorDecision>;
  lTempIndex: Integer;
  lVisibleDecisions: TArray<TFinalSelectorDecision>;
  lBinding: TDelphiSemanticWithBinding;
  i: Integer;
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  lBinding := aBindings[aBindingIndex];
  Result := Default(TDelphiSemanticRemoveWithFinalStatement);
  Result.FileName := lBinding.FileName;
  Result.StatementId := aStatementId;
  Result.SemanticId := lBinding.SemanticId;
  Result.RoutineName := lBinding.RoutineName;
  Result.Range := BindingRange(lBinding);
  Result.Verification := FinalVerification(aCandidateEdit);
  Result.ReferenceIds := aCandidateEdit.ReferenceIds;

  lVisibleDecisions := Copy(aInheritedDecisions);
  for lSelector in lBinding.Selectors do
  begin
    if HasDecisionForSelector(aInheritedDecisions, lSelector.SelectorText) then
      Continue;
    if not BuildSelectorDecision(aFacts, lBinding, lSelector.SelectorText,
      aReservedNames, lDecision, lReason) then
    begin
      Result.Status := 'skipped';
      Result.Reason := lReason;
      Result.SafetyReason := lReason;
      Exit;
    end;
    lIndex := Length(lSelectorDecisions);
    SetLength(lSelectorDecisions, lIndex + 1);
    lSelectorDecisions[lIndex] := lDecision;
    lIndex := Length(lVisibleDecisions);
    SetLength(lVisibleDecisions, lIndex + 1);
    lVisibleDecisions[lIndex] := lDecision;
  end;

  for i := 0 to High(aBindings) do
  begin
    if not IsDirectNestedBinding(aBindings, lBinding, aBindings[i]) then
      Continue;
    lChildStatement := BuildFinalStatement(aFacts, aBindings, i,
      FinalStatementId(i + 1), aCandidateEdit, aReservedNames, aLineCache,
      lVisibleDecisions);
    if not SameText(lChildStatement.Status, 'planned') then
    begin
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

  if not BuildFinalReplacementText(aFacts, lBinding, lVisibleDecisions,
    lSelectorDecisions, lNestedReplacements, aLineCache, lReplacementText,
    lReason) then
  begin
    Result.Status := 'skipped';
    Result.Reason := lReason;
    Result.SafetyReason := lReason;
    Exit;
  end;

  Result.Status := 'planned';
  Result.ReplacementText := lReplacementText;
  for lIndex := 0 to High(lSelectorDecisions) do
  begin
    if lSelectorDecisions[lIndex].TempName = '' then
      Continue;
    lTempIndex := Length(Result.Temps);
    SetLength(Result.Temps, lTempIndex + 1);
    for i := High(Result.Temps) downto 1 do
      Result.Temps[i] := Result.Temps[i - 1];
    Result.Temps[0] := FinalTempDecision(lSelectorDecisions[lIndex],
      lBinding.SemanticId);
  end;

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
end;

function FindRoutineDeclarationRange(const aFileName: string;
  const aBeforeLine: Integer; const aRoutineName: string;
  const aLineCache: TDictionary<string, TArray<string>>;
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
      ContainsText(lLines[lLineIndex - 1], 'function')) then
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
  const aLineCache: TDictionary<string, TArray<string>>;
  const aHashCache: TDictionary<string, string>);
var
  lDeclarationByRoutine: TDictionary<string, string>;
  lDeclarationText: string;
  lEdit: TDelphiSemanticRemoveWithFinalTextEdit;
  lFirstIndexByRoutine: TDictionary<string, Integer>;
  lHasVarSection: Boolean;
  lKey: string;
  lRange: TDelphiSemanticRemoveWithSourceRange;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lTemp: TDelphiSemanticRemoveWithFinalTempDecision;
  i: Integer;
begin
  lDeclarationByRoutine := TDictionary<string, string>.Create;
  lFirstIndexByRoutine := TDictionary<string, Integer>.Create;
  try
    for i := 0 to High(aPlan.FinalStatements) do
    begin
      lStatement := aPlan.FinalStatements[i];
      if not SameText(lStatement.Status, 'planned') then
        Continue;
      if not FindRoutineDeclarationRange(lStatement.FileName,
        lStatement.Range.StartLine, lStatement.RoutineName, aLineCache, lRange,
        lHasVarSection) then
        Continue;
      lKey := lStatement.FileName + #31 + lStatement.RoutineName;
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
  TDictionary<string, string>; const aLineCache: TDictionary<string, TArray<string>>):
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
    RangeContainsRange(BindingRange(aOuter), BindingRange(aInner));
end;

function HasBindingAncestor(const aBindings: TArray<TDelphiSemanticWithBinding>;
  const aBinding: TDelphiSemanticWithBinding): Boolean;
var
  lCandidate: TDelphiSemanticWithBinding;
begin
  Result := False;
  for lCandidate in aBindings do
  begin
    if BindingContainsBinding(lCandidate, aBinding) then
      Exit(True);
  end;
end;

function IsDirectNestedBinding(const aBindings: TArray<TDelphiSemanticWithBinding>;
  const aOuter, aInner: TDelphiSemanticWithBinding): Boolean;
var
  lCandidate: TDelphiSemanticWithBinding;
begin
  Result := False;
  if not BindingContainsBinding(aOuter, aInner) then
    Exit;
  for lCandidate in aBindings do
  begin
    if SameText(lCandidate.SemanticId, aOuter.SemanticId) or
      SameText(lCandidate.SemanticId, aInner.SemanticId) then
      Continue;
    if BindingContainsBinding(aOuter, lCandidate) and
      BindingContainsBinding(lCandidate, aInner) then
      Exit(False);
  end;
  Result := True;
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
      AddEditMismatch(aReport, 'replacement-text-mismatch', aExpectedStatement, lExpectedEdit);
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

class function TDelphiSemanticRemoveWithPlanner.Plan(
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TDelphiSemanticRemoveWithPlan;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingIndex: Integer;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lHashCache: TDictionary<string, string>;
  lLineCache: TDictionary<string, TArray<string>>;
  lReservedNames: TDictionary<string, Integer>;
  lStatementIndex: Integer;
begin
  Result := Default(TDelphiSemanticRemoveWithPlan);
  Result.Operation := 'remove-with';
  Result.Status := 'planned';
  Result.ContextFingerprint := aFacts.ContextFingerprint;
  Result.BaselineSemanticModelVersion := 'project-with-binding-v1';

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
  lLineCache := TDictionary<string, TArray<string>>.Create;
  lReservedNames := TDictionary<string, Integer>.Create;
  try
    lStatementIndex := 0;
    for lBindingIndex := 0 to High(aFacts.Bindings) do
    begin
      lBinding := aFacts.Bindings[lBindingIndex];
      Inc(lStatementIndex);
      if HasStableSourceRange(lBinding) then
      begin
        lEdit := AddEdit(Result, lBinding, lHashCache, lLineCache);
        if not HasBindingAncestor(aFacts.Bindings, lBinding) then
          AddFinalStatement(Result, BuildFinalStatement(aFacts, aFacts.Bindings,
            lBindingIndex, FinalStatementId(lStatementIndex), lEdit,
            lReservedNames, lLineCache, nil));
      end
      else
      begin
        AddSkippedStatement(Result, lBinding, 'SOURCE_RANGE_UNAVAILABLE',
          'stable source file, hash, and source range are required');
        AddFinalStatement(Result, BuildSkippedFinalStatement(lBinding,
          FinalStatementId(lStatementIndex), 'SOURCE_RANGE_UNAVAILABLE',
          'stable source file, hash, and source range are required'));
      end;
    end;
    AddRoutineDeclarationEdits(Result, lLineCache, lHashCache);
  finally
    lReservedNames.Free;
    lLineCache.Free;
    lHashCache.Free;
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
