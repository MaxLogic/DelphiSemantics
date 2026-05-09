unit DelphiSemantics.WithBinding;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve;

type
  TDelphiSemanticWithSelectorBinding = record
    SelectorText: string;
    Status: string;
    ReasonCode: string;
    TypeName: string;
  end;

  TDelphiSemanticBoundReference = record
    Name: string;
    Classification: string;
    LookupSource: string;
    ReceiverTypeName: string;
    Kind: string;
    TypeName: string;
    ReasonCode: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
  end;

  TDelphiSemanticInventorySymbol = record
    Name: string;
    SymbolClass: string;
    Kind: string;
    TypeName: string;
    OwnerName: string;
    RoutineName: string;
    UnitName: string;
    FileName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    IsDefault: Boolean;
    IsIndexed: Boolean;
  end;

  TDelphiSemanticWithBinding = record
    FileName: string;
    UnitName: string;
    RoutineName: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    BodyLine: Integer;
    BodyColumn: Integer;
    BodyEndLine: Integer;
    BodyEndColumn: Integer;
    SelectorText: string;
    Status: string;
    SkipReason: string;
    HasScopedDeclaration: Boolean;
    MemberReferenceCount: Integer;
    LexicalReferenceCount: Integer;
    ExternalReferenceCount: Integer;
    IntrinsicReferenceCount: Integer;
    UnsupportedReferenceCount: Integer;
    UnresolvedReferenceCount: Integer;
    Selectors: TArray<TDelphiSemanticWithSelectorBinding>;
    References: TArray<TDelphiSemanticBoundReference>;
  end;

  TDelphiSemanticRemoveWithInventory = record
    FileName: string;
    UnitName: string;
    Symbols: TArray<TDelphiSemanticInventorySymbol>;
    Bindings: TArray<TDelphiSemanticWithBinding>;
  end;

  TDelphiSemanticWithBinder = record
  public
    class function BindModel(const aModel: TDelphiSemanticUnitModel):
      TArray<TDelphiSemanticWithBinding>; static;
    class function BuildInventory(const aModel: TDelphiSemanticUnitModel):
      TDelphiSemanticRemoveWithInventory; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils;

type
  TRoutineFrame = record
    Name: string;
    Begun: Boolean;
    BlockDepth: Integer;
  end;

function IsBinderKeyword(const aName: string): Boolean;
begin
  Result := MatchText(aName, ['begin', 'do', 'end', 'with']);
end;

function IsSelectorName(const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aName: string): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  for lSelector in aSelectors do
    if SameText(lSelector.SelectorText, aName) then
      Exit(True);

  Result := False;
end;

function SanitizeBodyText(const aText: string): string;
  procedure BlankAt(const aIndex: Integer);
  begin
    if not CharInSet(Result[aIndex], [#10, #13]) then
      Result[aIndex] := ' ';
  end;

var
  i: Integer;
begin
  Result := aText;
  i := 1;
  while i <= Length(Result) do
  begin
    if aText[i] = '''' then
    begin
      BlankAt(i);
      Inc(i);
      while i <= Length(Result) do
      begin
        BlankAt(i);
        if aText[i] = '''' then
        begin
          if (i < Length(aText)) and (aText[i + 1] = '''') then
          begin
            Inc(i);
            BlankAt(i);
          end else
            Break;
        end;
        Inc(i);
      end;
    end else if (aText[i] = '/') and (i < Length(aText)) and (aText[i + 1] = '/') then
    begin
      while (i <= Length(Result)) and not CharInSet(Result[i], [#10, #13]) do
      begin
        BlankAt(i);
        Inc(i);
      end;
      Continue;
    end else if aText[i] = '{' then
    begin
      BlankAt(i);
      Inc(i);
      while i <= Length(Result) do
      begin
        BlankAt(i);
        if aText[i] = '}' then
          Break;
        Inc(i);
      end;
    end else if (aText[i] = '(') and (i < Length(aText)) and (aText[i + 1] = '*') then
    begin
      BlankAt(i);
      Inc(i);
      BlankAt(i);
      Inc(i);
      while i <= Length(Result) do
      begin
        BlankAt(i);
        if (aText[i] = '*') and (i < Length(aText)) and (aText[i + 1] = ')') then
        begin
          Inc(i);
          BlankAt(i);
          Break;
        end;
        Inc(i);
      end;
    end;
    Inc(i);
  end;
end;

function ExtractWithBodyText(const aStatement: TDelphiSemanticWithStatement;
  const aAllStatements: TArray<TDelphiSemanticWithStatement>; const aStatementIndex: Integer):
  string;
var
  i: Integer;
  lMatch: TMatch;

  function BlankTextPreservingLines(const aText: string): string;
  var
    j: Integer;
  begin
    Result := aText;
    for j := 1 to Length(Result) do
      if not CharInSet(Result[j], [#10, #13]) then
        Result[j] := ' ';
  end;

begin
  lMatch := TRegEx.Match(aStatement.Text, '\bdo\b(.*)$', [roIgnoreCase, roSingleLine]);
  if lMatch.Success then
    Result := lMatch.Groups[1].Value
  else
    Result := aStatement.Text;
  for i := Succ(aStatementIndex) to High(aAllStatements) do
    if Pos(aAllStatements[i].Text, Result) > 0 then
      Result := StringReplace(Result, aAllStatements[i].Text,
        BlankTextPreservingLines(aAllStatements[i].Text), []);
  Result := SanitizeBodyText(Result);
end;

function FindRoutineNameForLine(const aModel: TDelphiSemanticUnitModel; const aLine: Integer): string;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  for lRoutine in aModel.Routines do
    if (lRoutine.Line <= aLine) and ((Result = '') or (lRoutine.Line > 0)) then
      Result := lRoutine.Name;
end;

function ContainsRoutineName(const aNames: TList<string>; const aName: string): Boolean;
var
  lName: string;
begin
  for lName in aNames do
    if SameText(lName, aName) then
      Exit(True);

  Result := False;
end;

function ParentRoutineNamesForLine(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aLine: Integer): TArray<string>;
var
  i: Integer;
  lFrame: TRoutineFrame;
  lFrames: TList<TRoutineFrame>;
  lInImplementation: Boolean;
  lLine: string;
  lLines: TStringList;
  lNames: TList<string>;
  lRoutineName: string;
  lMatch: TMatch;
begin
  lNames := TList<string>.Create;
  lFrames := TList<TRoutineFrame>.Create;
  lLines := TStringList.Create;
  try
    if not TFile.Exists(aModel.FileName) then
      Exit(lNames.ToArray);

    lLines.Text := TFile.ReadAllText(aModel.FileName);
    lInImplementation := False;
    for i := 0 to Min(aLine - 2, lLines.Count - 1) do
    begin
      lLine := TRegEx.Replace(lLines[i], '''(?:''''|[^''])*''', ' ', [roSingleLine]);
      lLine := TRegEx.Replace(lLine, '//.*$', ' ', [roIgnoreCase]);
      if SameText(lLine.Trim, 'implementation') then
      begin
        lInImplementation := True;
        Continue;
      end;

      if not lInImplementation then
        Continue;

      lMatch := TRegEx.Match(lLine,
        '^\s*(?:procedure|function)\s+(?:[A-Za-z_][A-Za-z0-9_]*\.)?' +
        '([A-Za-z_][A-Za-z0-9_]*)\b', [roIgnoreCase]);
      if lMatch.Success then
      begin
        lFrame := Default(TRoutineFrame);
        lFrame.Name := lMatch.Groups[1].Value;
        lFrames.Add(lFrame);
      end;

      lMatch := TRegEx.Match(lLine, '\b(begin|end)\b', [roIgnoreCase]);
      while lMatch.Success do
      begin
        if lFrames.Count > 0 then
        begin
          lFrame := lFrames.Last;
          if SameText(lMatch.Value, 'begin') then
          begin
            lFrame.Begun := True;
            Inc(lFrame.BlockDepth);
            lFrames[Pred(lFrames.Count)] := lFrame;
          end else if lFrame.Begun and (lFrame.BlockDepth > 0) then
          begin
            Dec(lFrame.BlockDepth);
            if lFrame.BlockDepth = 0 then
              lFrames.Delete(Pred(lFrames.Count))
            else
              lFrames[Pred(lFrames.Count)] := lFrame;
          end;
        end;
        lMatch := lMatch.NextMatch;
      end;
    end;

    for i := Pred(lFrames.Count) downto 0 do
    begin
      lRoutineName := lFrames[i].Name;
      if not SameText(lRoutineName, aRoutineName) and
        not ContainsRoutineName(lNames, lRoutineName) then
        lNames.Add(lRoutineName);
    end;

    Result := lNames.ToArray;
  finally
    lLines.Free;
    lFrames.Free;
    lNames.Free;
  end;
end;

function MakeSelectorBinding(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
  aSelectorText: string; const aParentRoutineNames: TArray<string>):
  TDelphiSemanticWithSelectorBinding;
var
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
begin
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.ParentRoutineNames := aParentRoutineNames;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lResult := TDelphiSemanticResolver.ResolveName(aModel, lContext, aSelectorText.Trim);
  Result.SelectorText := aSelectorText.Trim;
  Result.Status := lResult.Status;
  Result.ReasonCode := lResult.ReasonCode;
  Result.TypeName := lResult.TypeName;
end;

function LookupSourceForClassification(const aClassification: string): string;
begin
  if SameText(aClassification, 'member') then
    Result := 'receiver'
  else if SameText(aClassification, 'lexical') then
    Result := 'lexical'
  else if SameText(aClassification, 'intrinsic') then
    Result := 'intrinsic'
  else if SameText(aClassification, 'external') then
    Result := 'external'
  else
    Result := 'none';
end;

function MakeBoundReference(const aName, aClassification: string;
  const aResult: TDelphiSemanticResolveResult): TDelphiSemanticBoundReference;
begin
  Result.Name := aName;
  Result.Classification := aClassification;
  Result.LookupSource := LookupSourceForClassification(aClassification);
  Result.ReceiverTypeName := aResult.OwnerName;
  Result.Kind := aResult.Kind;
  Result.TypeName := aResult.TypeName;
  Result.ReasonCode := aResult.ReasonCode;
end;

function LineOfOffset(const aText: string; const aOffset: Integer): Integer;
var
  i: Integer;
  lOffset: Integer;
begin
  Result := 1;
  lOffset := EnsureRange(aOffset, 1, Length(aText));
  for i := 1 to lOffset do
    if aText[i] = #10 then
      Inc(Result);
end;

function ColumnOfOffset(const aText: string; const aOffset: Integer): Integer;
var
  i: Integer;
  lColumn: Integer;
  lOffset: Integer;
begin
  lColumn := 1;
  lOffset := EnsureRange(aOffset, 1, Length(aText));
  for i := 1 to lOffset - 1 do
  begin
    if aText[i] = #10 then
      lColumn := 1
    else
      Inc(lColumn);
  end;
  Result := lColumn;
end;

procedure ApplyBodyRange(var aReference: TDelphiSemanticBoundReference;
  const aStatement: TDelphiSemanticWithStatement; const aStartOffset, aLength: Integer);
var
  lEndColumn: Integer;
  lEndLine: Integer;
  lEndOffset: Integer;
  lStartColumn: Integer;
  lStartLine: Integer;
begin
  if (aStartOffset <= 0) or (aLength <= 0) or (aStatement.BodyText = '') then
    Exit;

  lEndOffset := aStartOffset + aLength - 1;
  lStartLine := LineOfOffset(aStatement.BodyText, aStartOffset);
  lStartColumn := ColumnOfOffset(aStatement.BodyText, aStartOffset);
  lEndLine := LineOfOffset(aStatement.BodyText, lEndOffset);
  lEndColumn := ColumnOfOffset(aStatement.BodyText, lEndOffset);

  aReference.Line := aStatement.BodyLine + lStartLine - 1;
  if lStartLine = 1 then
    aReference.Column := aStatement.BodyColumn + lStartColumn - 1
  else
    aReference.Column := lStartColumn;
  aReference.EndLine := aStatement.BodyLine + lEndLine - 1;
  if lEndLine = 1 then
    aReference.EndColumn := aStatement.BodyColumn + lEndColumn - 1
  else
    aReference.EndColumn := lEndColumn;
end;

function MakeSyntheticResolveResult(const aName, aKind, aTypeName, aOwnerName,
  aReasonCode: string): TDelphiSemanticResolveResult;
begin
  Result := Default(TDelphiSemanticResolveResult);
  Result.Found := aKind <> '';
  Result.Authoritative := Result.Found;
  if Result.Found then
    Result.Status := 'resolved'
  else
    Result.Status := 'unresolved';
  Result.Name := aName;
  Result.Kind := aKind;
  Result.TypeName := aTypeName;
  Result.OwnerName := aOwnerName;
  Result.ReasonCode := aReasonCode;
end;

function TryExtractCallName(const aName: string; out aCallName: string): Boolean;
var
  lParenPos: Integer;
begin
  lParenPos := Pos('(', aName);
  Result := lParenPos > 1;
  if Result then
    aCallName := Copy(aName, 1, lParenPos - 1).Trim
  else
    aCallName := '';
end;

function TryExtractCallArguments(const aName: string; out aArguments: string): Boolean;
var
  lClosePos: Integer;
  lParenPos: Integer;
begin
  lParenPos := Pos('(', aName);
  lClosePos := LastDelimiter(')', aName);
  Result := (lParenPos > 1) and (lClosePos > lParenPos);
  if Result then
    aArguments := Copy(aName, lParenPos + 1, lClosePos - lParenPos - 1)
  else
    aArguments := '';
end;

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  i: Integer;
begin
  for i := High(aSelectors) downto 0 do
    if SameText(aSelectors[i].Status, 'resolved') then
    begin
      aResult := TDelphiSemanticResolver.ResolveMemberAtLevel(aModel, aSelectors[i].TypeName,
        aName, 3);
      if aResult.Found or SameText(aResult.Status, 'ambiguous') or
        SameText(aResult.Status, 'unsupported') then
        Exit(True);
    end;

  aResult := Default(TDelphiSemanticResolveResult);
  Result := False;
end;

function AnySelectorUnresolved(const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>): Boolean;
var
  lSelector: TDelphiSemanticWithSelectorBinding;
begin
  for lSelector in aSelectors do
    if not SameText(lSelector.Status, 'resolved') then
      Exit(True);

  Result := False;
end;

procedure AddReference(const aReferences: TList<TDelphiSemanticBoundReference>;
  const aReference: TDelphiSemanticBoundReference);
begin
  aReferences.Add(aReference);
end;

procedure AddInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbol: TDelphiSemanticInventorySymbol);
begin
  if aSymbol.Name <> '' then
    aSymbols.Add(aSymbol);
end;

function BindReference(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName: string; const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>; const aName: string):
  TDelphiSemanticBoundReference;
var
  lCallName: string;
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
begin
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.ParentRoutineNames := aParentRoutineNames;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;

  if TryExtractCallName(aName, lCallName) then
  begin
    if TryResolveReceiverMember(aModel, aSelectors, lCallName, lResult) then
      if SameText(lResult.Kind, 'method') then
        Exit(MakeBoundReference(lCallName, 'member', lResult))
      else
        Exit(MakeBoundReference(lCallName, 'unsupported',
          MakeSyntheticResolveResult(lCallName, lResult.Kind, lResult.TypeName,
          lResult.OwnerName, 'CALL_SELECTOR_UNSUPPORTED')));

    lResult := TDelphiSemanticResolver.ResolveName(aModel, lContext, lCallName);
    if lResult.Found and SameText(lResult.Kind, 'intrinsic-routine') then
      Exit(MakeBoundReference(lCallName, 'intrinsic', lResult));
    if lResult.Found and SameText(lResult.Kind, 'routine') then
      Exit(MakeBoundReference(lCallName, 'external',
        MakeSyntheticResolveResult(lCallName, 'routine', lResult.TypeName, lResult.OwnerName,
        'EXTERNAL_ROUTINE_CALL')));
    if lResult.Found then
      Exit(MakeBoundReference(lCallName, 'unsupported',
        MakeSyntheticResolveResult(lCallName, lResult.Kind, lResult.TypeName, lResult.OwnerName,
        'CALL_SELECTOR_UNSUPPORTED')));
    Exit(MakeBoundReference(lCallName, 'external',
      MakeSyntheticResolveResult(lCallName, 'routine', '', '', 'UNKNOWN_ROUTINE_CALL')));
  end;

  if (Pos('.', aName) > 0) or (Pos('[', aName) > 0) then
    Exit(MakeBoundReference(aName, 'unsupported',
      TDelphiSemanticResolver.ResolveName(aModel, Default(TDelphiSemanticResolveContext), aName)));

  if TryResolveReceiverMember(aModel, aSelectors, aName, lResult) then
  begin
    if SameText(lResult.Status, 'ambiguous') then
      Exit(MakeBoundReference(aName, 'ambiguous', lResult));
    if SameText(lResult.Status, 'unsupported') then
      Exit(MakeBoundReference(aName, 'unsupported', lResult));
    Exit(MakeBoundReference(aName, 'member', lResult));
  end;

  lResult := TDelphiSemanticResolver.ResolveName(aModel, lContext, aName);
  if lResult.Found then
    Exit(MakeBoundReference(aName, 'lexical', lResult));

  if AnySelectorUnresolved(aSelectors) then
    Exit(MakeBoundReference(aName, 'external', lResult));

  Result := MakeBoundReference(aName, 'unresolved', lResult);
end;

procedure CountBindingReference(var aBinding: TDelphiSemanticWithBinding;
  const aReference: TDelphiSemanticBoundReference);
begin
  if SameText(aReference.Classification, 'member') then
    Inc(aBinding.MemberReferenceCount)
  else if SameText(aReference.Classification, 'lexical') then
    Inc(aBinding.LexicalReferenceCount)
  else if SameText(aReference.Classification, 'external') then
    Inc(aBinding.ExternalReferenceCount)
  else if SameText(aReference.Classification, 'intrinsic') then
    Inc(aBinding.IntrinsicReferenceCount)
  else if SameText(aReference.Classification, 'unsupported') then
    Inc(aBinding.UnsupportedReferenceCount)
  else if SameText(aReference.Classification, 'unresolved') then
    Inc(aBinding.UnresolvedReferenceCount);
end;

procedure FinalizeBinding(var aBinding: TDelphiSemanticWithBinding;
  const aStatement: TDelphiSemanticWithStatement);
var
  lReference: TDelphiSemanticBoundReference;
begin
  aBinding.HasScopedDeclaration := aStatement.HasScopedDeclaration;
  for lReference in aBinding.References do
    CountBindingReference(aBinding, lReference);

  if aBinding.HasScopedDeclaration then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'SCOPED_DECLARATION';
  end else if aBinding.UnsupportedReferenceCount > 0 then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'UNSUPPORTED_REFERENCE';
  end else if aBinding.UnresolvedReferenceCount > 0 then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'UNRESOLVED_REFERENCE';
  end else if aBinding.ExternalReferenceCount > 0 then
  begin
    aBinding.Status := 'skipped';
    aBinding.SkipReason := 'EXTERNAL_REFERENCE';
  end else
  begin
    aBinding.Status := 'planned';
    aBinding.SkipReason := '';
  end;
end;

function SplitSelectors(const aSelectorText: string): TArray<string>;
var
  lPart: string;
  lParts: TList<string>;
begin
  lParts := TList<string>.Create;
  try
    for lPart in aSelectorText.Split([',']) do
      if lPart.Trim <> '' then
        lParts.Add(lPart.Trim);
    Result := lParts.ToArray;
  finally
    lParts.Free;
  end;
end;

function BindSelectors(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
  aSelectorText: string; const aParentRoutineNames: TArray<string>):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  lPart: string;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
begin
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  try
    for lPart in SplitSelectors(aSelectorText) do
      lSelectors.Add(MakeSelectorBinding(aModel, aRoutineName, lPart, aParentRoutineNames));
    Result := lSelectors.ToArray;
  finally
    lSelectors.Free;
  end;
end;

procedure AddArgumentReferences(const aReferences: TList<TDelphiSemanticBoundReference>;
  const aModel: TDelphiSemanticUnitModel; const aRoutineName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aStatement: TDelphiSemanticWithStatement; const aToken: string;
  const aTokenStartOffset: Integer);
var
  lArgumentMatch: TMatch;
  lArgumentStartOffset: Integer;
  lArguments: string;
  lParenPos: Integer;
  lReference: TDelphiSemanticBoundReference;
begin
  if not TryExtractCallArguments(aToken, lArguments) then
    Exit;

  lParenPos := Pos('(', aToken);
  lArguments := SanitizeBodyText(lArguments);
  lArgumentMatch := TRegEx.Match(lArguments,
    '\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?(?:\[[^\]]+\])?',
    [roIgnoreCase]);
  while lArgumentMatch.Success do
  begin
    if not IsBinderKeyword(lArgumentMatch.Value) and
      not IsSelectorName(aSelectors, lArgumentMatch.Value) then
    begin
      lReference := BindReference(aModel, aRoutineName, aParentRoutineNames, aSelectors,
        lArgumentMatch.Value);
      lArgumentStartOffset := aTokenStartOffset + lParenPos + lArgumentMatch.Index - 1;
      ApplyBodyRange(lReference, aStatement, lArgumentStartOffset, Length(lArgumentMatch.Value));
      AddReference(aReferences, lReference);
    end;
    lArgumentMatch := lArgumentMatch.NextMatch;
  end;
end;

function BindReferences(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement;
  const aAllStatements: TArray<TDelphiSemanticWithStatement>;
  const aStatementIndex: Integer;
  const aRoutineName: string;
  const aParentRoutineNames: TArray<string>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>):
  TArray<TDelphiSemanticBoundReference>;
var
  lBodyText: string;
  lMatch: TMatch;
  lReference: TDelphiSemanticBoundReference;
  lReferences: TList<TDelphiSemanticBoundReference>;
begin
  lReferences := TList<TDelphiSemanticBoundReference>.Create;
  try
    lBodyText := ExtractWithBodyText(aStatement, aAllStatements, aStatementIndex);
    lMatch := TRegEx.Match(lBodyText,
      '\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?(?:\[[^\]]+\]|\([^)]*\))?',
      [roIgnoreCase]);
    while lMatch.Success do
    begin
      if not IsBinderKeyword(lMatch.Value) and not IsSelectorName(aSelectors, lMatch.Value) then
      begin
        lReference := BindReference(aModel, aRoutineName, aParentRoutineNames, aSelectors,
          lMatch.Value);
        ApplyBodyRange(lReference, aStatement, lMatch.Index, Length(lMatch.Value));
        AddReference(lReferences, lReference);
        AddArgumentReferences(lReferences, aModel, aRoutineName, aParentRoutineNames,
          aSelectors, aStatement, lMatch.Value, lMatch.Index);
      end;
      lMatch := lMatch.NextMatch;
    end;
    Result := lReferences.ToArray;
  finally
    lReferences.Free;
  end;
end;

function StatementContains(const aOuter, aInner: TDelphiSemanticWithStatement): Boolean;
begin
  Result := ((aOuter.Line < aInner.Line) or ((aOuter.Line = aInner.Line) and
    (aOuter.Column < aInner.Column))) and ((aOuter.EndLine > aInner.EndLine) or
    ((aOuter.EndLine = aInner.EndLine) and (aOuter.EndColumn >= aInner.EndColumn)));
end;

function CombinedSelectors(const aModel: TDelphiSemanticUnitModel;
  const aStatements: TArray<TDelphiSemanticWithStatement>; const aStatementIndex: Integer;
  const aRoutineName: string; const aParentRoutineNames: TArray<string>):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  i: Integer;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
begin
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  try
    for i := 0 to Pred(aStatementIndex) do
      if StatementContains(aStatements[i], aStatements[aStatementIndex]) then
        for lSelector in BindSelectors(aModel, aRoutineName, aStatements[i].SelectorText,
          aParentRoutineNames) do
          lSelectors.Add(lSelector);
    for lSelector in BindSelectors(aModel, aRoutineName, aStatements[aStatementIndex].SelectorText,
      aParentRoutineNames) do
      lSelectors.Add(lSelector);
    Result := lSelectors.ToArray;
  finally
    lSelectors.Free;
  end;
end;

class function TDelphiSemanticWithBinder.BindModel(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticWithBinding>;
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TList<TDelphiSemanticWithBinding>;
  lParentRoutineNames: TArray<string>;
  lRoutineName: string;
  lStatement: TDelphiSemanticWithStatement;
begin
  lBindings := TList<TDelphiSemanticWithBinding>.Create;
  try
    for i := 0 to High(aModel.WithStatements) do
    begin
      lStatement := aModel.WithStatements[i];
      lBinding := Default(TDelphiSemanticWithBinding);
      lBinding.FileName := aModel.FileName;
      lBinding.UnitName := aModel.UnitName;
      lBinding.Line := lStatement.Line;
      lBinding.Column := lStatement.Column;
      lBinding.EndLine := lStatement.EndLine;
      lBinding.EndColumn := lStatement.EndColumn;
      lBinding.BodyLine := lStatement.BodyLine;
      lBinding.BodyColumn := lStatement.BodyColumn;
      lBinding.BodyEndLine := lStatement.BodyEndLine;
      lBinding.BodyEndColumn := lStatement.BodyEndColumn;
      lBinding.SelectorText := lStatement.SelectorText;
      lRoutineName := FindRoutineNameForLine(aModel, lStatement.Line);
      lBinding.RoutineName := lRoutineName;
      lParentRoutineNames := ParentRoutineNamesForLine(aModel, lRoutineName, lStatement.Line);
      lBinding.Selectors := CombinedSelectors(aModel, aModel.WithStatements, i, lRoutineName,
        lParentRoutineNames);
      lBinding.References := BindReferences(aModel, lStatement, aModel.WithStatements, i,
        lRoutineName, lParentRoutineNames, lBinding.Selectors);
      FinalizeBinding(lBinding, lStatement);
      lBindings.Add(lBinding);
    end;
    Result := lBindings.ToArray;
  finally
    lBindings.Free;
  end;
end;

class function TDelphiSemanticWithBinder.BuildInventory(
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticRemoveWithInventory;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  Result := Default(TDelphiSemanticRemoveWithInventory);
  Result.FileName := aModel.FileName;
  Result.UnitName := aModel.UnitName;

  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  try
    lSymbol := Default(TDelphiSemanticInventorySymbol);
    lSymbol.Name := aModel.UnitName;
    lSymbol.SymbolClass := 'unit';
    lSymbol.Kind := 'unit';
    lSymbol.UnitName := aModel.UnitName;
    lSymbol.FileName := aModel.FileName;
    lSymbol.Line := 1;
    lSymbol.Column := 1;
    AddInventorySymbol(lSymbols, lSymbol);

    for lDeclaration in aModel.Declarations do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lDeclaration.Name;
      lSymbol.SymbolClass := 'declaration';
      lSymbol.Kind := lDeclaration.Kind;
      lSymbol.TypeName := lDeclaration.TypeName;
      lSymbol.OwnerName := aModel.UnitName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lDeclaration.SectionKind;
      lSymbol.Line := lDeclaration.Line;
      lSymbol.Column := lDeclaration.Column;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    for lMember in aModel.Members do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMember.Name;
      lSymbol.SymbolClass := 'member';
      lSymbol.Kind := lMember.Kind;
      lSymbol.TypeName := lMember.TypeName;
      lSymbol.OwnerName := lMember.OwnerName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.Line := lMember.Line;
      lSymbol.Column := lMember.Column;
      lSymbol.IsDefault := lMember.IsDefault;
      lSymbol.IsIndexed := lMember.IsIndexed;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    for lRoutine in aModel.Routines do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lRoutine.Name;
      lSymbol.SymbolClass := 'routine';
      lSymbol.Kind := 'routine';
      lSymbol.TypeName := lRoutine.ReturnType;
      lSymbol.OwnerName := lRoutine.OwnerName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lRoutine.SectionKind;
      lSymbol.Line := lRoutine.Line;
      lSymbol.Column := lRoutine.Column;
      AddInventorySymbol(lSymbols, lSymbol);

      for lParameter in lRoutine.Parameters do
      begin
        lSymbol := Default(TDelphiSemanticInventorySymbol);
        lSymbol.Name := lParameter.Name;
        lSymbol.SymbolClass := 'parameter';
        lSymbol.Kind := 'parameter';
        lSymbol.TypeName := lParameter.TypeName;
        lSymbol.RoutineName := lParameter.RoutineName;
        lSymbol.UnitName := aModel.UnitName;
        lSymbol.FileName := aModel.FileName;
        AddInventorySymbol(lSymbols, lSymbol);
      end;
    end;

    for lLocal in aModel.Locals do
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lLocal.Name;
      lSymbol.SymbolClass := 'local';
      lSymbol.Kind := lLocal.Kind;
      lSymbol.TypeName := lLocal.TypeName;
      lSymbol.RoutineName := lLocal.RoutineName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.Line := lLocal.Line;
      lSymbol.Column := lLocal.Column;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    Result.Symbols := lSymbols.ToArray;
  finally
    lSymbols.Free;
  end;

  Result.Bindings := BindModel(aModel);
end;

end.
