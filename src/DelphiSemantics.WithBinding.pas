unit DelphiSemantics.WithBinding;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.Resolve, DelphiSemantics.Resolve.ScopeResolver,
  DelphiSemantics.SemanticGraph;

type
  TDelphiSemanticWithSelectorBinding = record
    SelectorText: string;
    Status: string;
    ReasonCode: string;
    TypeName: string;
  end;

  TDelphiSemanticBoundReference = record
    SemanticId: string;
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
    OwnerType: string;
    SourceOwnerType: string;
    RelatedTypeName: string;
    RoutineName: string;
    UnitName: string;
    FileName: string;
    SectionKind: string;
    Line: Integer;
    Column: Integer;
    EndLine: Integer;
    EndColumn: Integer;
    UnsupportedReason: string;
    IsHelper: Boolean;
    IsOverride: Boolean;
    IsDefault: Boolean;
    IsIndexed: Boolean;
    IndexParameterCount: Integer;
    TypeCategory: string;
  end;

  TDelphiSemanticWithBinding = record
    SemanticId: string;
    Provenance: string;
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

  TDelphiSemanticProjectWithBindingMetrics = record
    SemanticGraphUsed: Boolean;
    BuildUnitIndexUsed: Boolean;
    UnitCount: Integer;
    WithStatementCount: Integer;
    BindingCount: Integer;
    SemanticGraphBuildMilliseconds: Int64;
  end;

  TDelphiSemanticProjectWithBindingFacts = record
    ContextFingerprint: string;
    Metrics: TDelphiSemanticProjectWithBindingMetrics;
    Symbols: TArray<TDelphiSemanticInventorySymbol>;
    Bindings: TArray<TDelphiSemanticWithBinding>;
  end;

  TDelphiSemanticWithBinder = record
  public
    class function BindModel(const aModel: TDelphiSemanticUnitModel):
      TArray<TDelphiSemanticWithBinding>; static;
    class function BindProject(const aContextFingerprint: string;
      const aGraph: TDelphiSemanticSemanticGraph;
      const aModels: TArray<TDelphiSemanticUnitModel>):
      TDelphiSemanticProjectWithBindingFacts; static;
    class function BuildInventory(const aModel: TDelphiSemanticUnitModel):
      TDelphiSemanticRemoveWithInventory; static;
    class function ExpandInventorySymbols(const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
      TArray<TDelphiSemanticInventorySymbol>; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.Hash, System.IOUtils, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils;

function StableFactId(const aPrefix, aText: string): string;
begin
  Result := aPrefix + '-' + THashSHA2.GetHashString(aText);
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

function TryResolveReceiverMember(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean; forward;

function MakeSelectorBinding(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aSelectorText: string; const aParentRoutineNames: TArray<string>;
  const aPreviousSelectors: TArray<TDelphiSemanticWithSelectorBinding>):
  TDelphiSemanticWithSelectorBinding;
var
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
  lSelectorText: string;
begin
  lSelectorText := aSelectorText.Trim;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.ParentRoutineNames := aParentRoutineNames;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := aProjectModels;
  if not ((Length(aPreviousSelectors) > 0) and TRegEx.IsMatch(lSelectorText,
    '^[A-Za-z_][A-Za-z0-9_]*$') and
    TryResolveReceiverMember(aModel, aProjectModels, aPreviousSelectors, lSelectorText,
    lResult)) then
    lResult := TDelphiSemanticResolver.ResolveName(aModel, lContext, lSelectorText);
  Result.SelectorText := lSelectorText;
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

function BindingSemanticId(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement): string;
begin
  Result := StableFactId('with', LowerCase(aModel.FileName) + '|' +
    IntToStr(aStatement.Line) + '|' + IntToStr(aStatement.Column) + '|' +
    IntToStr(aStatement.EndLine) + '|' + IntToStr(aStatement.EndColumn) + '|' +
    aStatement.SelectorText);
end;

function ReferenceSemanticId(const aBindingId: string;
  const aReference: TDelphiSemanticBoundReference): string;
begin
  Result := StableFactId('with-ref', aBindingId + '|' + aReference.Name + '|' +
    aReference.Classification + '|' + IntToStr(aReference.Line) + '|' +
    IntToStr(aReference.Column) + '|' + IntToStr(aReference.EndLine) + '|' +
    IntToStr(aReference.EndColumn));
end;

function GraphWithStatementIdForBinding(const aGraph: TDelphiSemanticSemanticGraph;
  const aBinding: TDelphiSemanticWithBinding): string;
var
  lStatement: TDelphiSemanticGraphWithStatement;
begin
  if aGraph = nil then
    Exit(aBinding.SemanticId);

  for lStatement in aGraph.WithStatements do
    if SameText(lStatement.SourceRange.FileName, aBinding.FileName) and
      (lStatement.SourceRange.Line = aBinding.Line) and
      (lStatement.SourceRange.Column = aBinding.Column) and
      (lStatement.SourceRange.EndLine = aBinding.EndLine) and
      (lStatement.SourceRange.EndColumn = aBinding.EndColumn) then
      Exit(lStatement.Id.Value);

  Result := aBinding.SemanticId;
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
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>; const aName: string;
  out aResult: TDelphiSemanticResolveResult): Boolean;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
begin
  for i := High(aSelectors) downto 0 do
    if SameText(aSelectors[i].Status, 'resolved') then
    begin
      aResult := TDelphiSemanticResolver.ResolveMemberAtLevel(aModel, aSelectors[i].TypeName,
        aName, 3);
      if aResult.Found or SameText(aResult.Status, 'ambiguous') or
        SameText(aResult.Status, 'unsupported') then
        Exit(True);
      for lModel in aProjectModels do
      begin
        aResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lModel, aSelectors[i].TypeName,
          aName, 3);
        if aResult.Found or SameText(aResult.Status, 'ambiguous') or
          SameText(aResult.Status, 'unsupported') then
          Exit(True);
      end;
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

function InventoryCleanLine(const aLine: string): string;
var
  lCommentPos: Integer;
  lEndPos: Integer;
  lStartPos: Integer;
begin
  Result := Trim(aLine);
  if Result = '' then
    Exit;
  if StartsText('{$', Result) or StartsText('(*$', Result) then
    Exit;

  repeat
    lStartPos := Pos('{', Result);
    if lStartPos = 0 then
      Break;
    if Copy(Result, lStartPos, 2) = '{$' then
      Break;
    lEndPos := PosEx('}', Result, lStartPos + 1);
    if lEndPos = 0 then
    begin
      Delete(Result, lStartPos, MaxInt);
      Break;
    end;
    Delete(Result, lStartPos, lEndPos - lStartPos + 1);
    Result := Trim(Result);
  until False;

  repeat
    lStartPos := Pos('(*', Result);
    if lStartPos = 0 then
      Break;
    if Copy(Result, lStartPos, 3) = '(*$' then
      Break;
    lEndPos := PosEx('*)', Result, lStartPos + 2);
    if lEndPos = 0 then
    begin
      Delete(Result, lStartPos, MaxInt);
      Break;
    end;
    Delete(Result, lStartPos, lEndPos - lStartPos + 2);
    Result := Trim(Result);
  until False;

  lCommentPos := Pos('//', Result);
  if lCommentPos > 0 then
    Result := Trim(Copy(Result, 1, lCommentPos - 1));
end;

function InventoryIsIdentifierChar(const aValue: Char): Boolean;
begin
  Result := CharInSet(aValue, ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function InventoryRemoveInlineConditionalBlocks(const aText: string): string;
var
  lEndPos: Integer;
  lStartPos: Integer;
  lUpper: string;
begin
  Result := aText;
  repeat
    lUpper := UpperCase(Result);
    lStartPos := Pos('{$IF', lUpper);
    if lStartPos = 0 then
      Break;
    lEndPos := PosEx('{$ENDIF}', lUpper, lStartPos + 1);
    if lEndPos = 0 then
      Break;
    Delete(Result, lStartPos, lEndPos - lStartPos + Length('{$ENDIF}'));
  until False;

  repeat
    lStartPos := Pos('{$', Result);
    if lStartPos = 0 then
      Break;
    lEndPos := PosEx('}', Result, lStartPos + 1);
    if lEndPos = 0 then
      Break;
    Delete(Result, lStartPos, lEndPos - lStartPos + 1);
  until False;
  Result := Trim(Result);
end;

function InventoryIsTopLevelLine(const aLine: string): Boolean;
begin
  Result := (Trim(aLine) <> '') and (TrimLeft(aLine) = aLine);
end;

function InventoryIsVisibilityLine(const aLine: string): Boolean;
begin
  Result := MatchText(LowerCase(Trim(aLine)), ['private', 'protected', 'public', 'published',
    'strict private', 'strict protected']);
end;

function InventoryIsDirectMemberKind(const aKind: string): Boolean;
begin
  Result := MatchText(aKind, ['field', 'property', 'method', 'constant', 'class-var']);
end;

function InventoryIsRoutineStart(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := LowerCase(Trim(aLine));
  Result := StartsText('procedure ', lText) or StartsText('function ', lText) or
    StartsText('class procedure ', lText) or StartsText('class function ', lText) or
    StartsText('constructor ', lText) or StartsText('destructor ', lText);
end;

function InventoryIsAttributeLine(const aLine: string): Boolean;
begin
  Result := StartsText('[', Trim(aLine));
end;

function InventoryIsConditionalDirectiveLine(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$IF', lText) or StartsText('{$ELSE', lText) or
    StartsText('{$ELSEIF', lText) or StartsText('{$ENDIF', lText) or
    StartsText('{$IFEND', lText);
end;

function InventoryIsConditionalStartDirective(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$IF', lText) and (not StartsText('{$IFEND', lText));
end;

function InventoryIsConditionalEndDirective(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := UpperCase(Trim(aLine));
  Result := StartsText('{$ENDIF', lText) or StartsText('{$IFEND', lText);
end;

function InventoryIsMultilineDeclarationStart(const aLine: string): Boolean;
var
  lText: string;
begin
  lText := Trim(aLine);
  Result := (Pos(',', lText) > 0) and (Pos(':', lText) = 0) and (Pos(';', lText) = 0) and
    (not InventoryIsRoutineStart(lText));
end;

function InventoryFindColumn(const aLine, aName: string): Integer;
begin
  Result := Pos(aName, aLine);
  if Result = 0 then
    Result := 1;
end;

function InventorySimpleTypeName(const aTypeName: string): string;
var
  lDelimiterPos: Integer;
  lTypeName: string;
begin
  lTypeName := Trim(aTypeName);
  if StartsText('^', lTypeName) then
    Delete(lTypeName, 1, 1);
  lDelimiterPos := Pos('<', lTypeName);
  if lDelimiterPos = 0 then
    lDelimiterPos := Pos('[', lTypeName);
  if lDelimiterPos = 0 then
    lDelimiterPos := Pos(' ', lTypeName);
  if lDelimiterPos > 0 then
    lTypeName := Trim(Copy(lTypeName, 1, lDelimiterPos - 1));
  lDelimiterPos := LastDelimiter('.', lTypeName);
  if lDelimiterPos > 0 then
    lTypeName := Copy(lTypeName, lDelimiterPos + 1, MaxInt);
  Result := lTypeName;
end;

function InventoryTryDeclaration(const aLine: string; out aNames: TArray<string>;
  out aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lEqualsPos: Integer;
  lLeft: string;
  lLine: string;
  lNames: TList<string>;
  lPart: string;
  lParts: TArray<string>;
  lRawPart: string;
  lRight: string;
  lSemiPos: Integer;
begin
  Result := False;
  SetLength(aNames, 0);
  aTypeName := '';
  lLine := InventoryRemoveInlineConditionalBlocks(aLine);
  lColonPos := Pos(':', lLine);
  if lColonPos = 0 then
    Exit;

  lLeft := Trim(Copy(lLine, 1, lColonPos - 1));
  if (lLeft = '') or InventoryIsRoutineStart(lLeft) or StartsText('property ', LowerCase(lLeft)) then
    Exit;

  lRight := Trim(Copy(lLine, lColonPos + 1, MaxInt));
  lEqualsPos := Pos('=', lRight);
  if lEqualsPos > 0 then
    lRight := Trim(Copy(lRight, 1, lEqualsPos - 1));
  lSemiPos := Pos(';', lRight);
  if lSemiPos > 0 then
    lRight := Trim(Copy(lRight, 1, lSemiPos - 1));
  if lRight = '' then
    Exit;

  lNames := TList<string>.Create;
  try
    lParts := lLeft.Split([',']);
    for lRawPart in lParts do
    begin
      lPart := Trim(lRawPart);
      if lPart <> '' then
        lNames.Add(lPart);
    end;
    aNames := lNames.ToArray;
  finally
    lNames.Free;
  end;
  aTypeName := lRight;
  Result := Length(aNames) > 0;
end;

function InventoryTryConstDeclaration(const aLine: string; out aName: string;
  out aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lEqualsPos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  lColonPos := Pos(':', aLine);
  if (lColonPos > 0) and (lColonPos < lEqualsPos) then
  begin
    aName := Trim(Copy(aLine, 1, lColonPos - 1));
    aTypeName := Trim(Copy(aLine, lColonPos + 1, lEqualsPos - lColonPos - 1));
  end else
  begin
    aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
    aTypeName := '';
  end;
  Result := aName <> '';
end;

function InventoryTryEnumValues(const aTypeText: string; out aNames: TArray<string>): Boolean;
var
  i: Integer;
  lClosePos: Integer;
  lEqualsPos: Integer;
  lList: TList<string>;
  lName: string;
  lOpenPos: Integer;
  lPart: string;
  lParts: TArray<string>;
  lPrefix: string;
  lRawPart: string;
  lText: string;
begin
  Result := False;
  SetLength(aNames, 0);
  lText := Trim(aTypeText);
  lEqualsPos := Pos('=', lText);
  lOpenPos := Pos('(', lText);
  lClosePos := PosEx(')', lText, lOpenPos + 1);
  if (lEqualsPos = 0) or (lOpenPos <= lEqualsPos) or (lClosePos <= lOpenPos) then
    Exit;

  lPrefix := Copy(lText, 1, lOpenPos - 1);
  if ContainsText(lPrefix, 'procedure') or ContainsText(lPrefix, 'function') then
    Exit;

  lList := TList<string>.Create;
  try
    lParts := Copy(lText, lOpenPos + 1, lClosePos - lOpenPos - 1).Split([',']);
    for lRawPart in lParts do
    begin
      lPart := Trim(lRawPart);
      lName := '';
      i := 1;
      while (i <= Length(lPart)) and InventoryIsIdentifierChar(lPart[i]) do
      begin
        lName := lName + lPart[i];
        Inc(i);
      end;
      if lName <> '' then
        lList.Add(lName);
    end;
    aNames := lList.ToArray;
    Result := Length(aNames) > 0;
  finally
    lList.Free;
  end;
end;

function InventoryTryPropertyDeclaration(const aLine: string; out aName, aTypeName: string;
  out aIsDefault, aIsIndexed: Boolean; out aIndexParameterCount: Integer): Boolean;
var
  i: Integer;
  lBracketDepth: Integer;
  lIndexText: string;
  lMemberText: string;
  lNameEnd: Integer;
  lPropertyTypeEnd: Integer;
  lTypePos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  aIsDefault := False;
  aIsIndexed := False;
  aIndexParameterCount := 0;
  if not StartsText('property ', LowerCase(aLine)) then
    Exit;

  lMemberText := Trim(Copy(aLine, Length('property ') + 1, MaxInt));
  aIsDefault := ContainsText(LowerCase(lMemberText), ' default');
  lBracketDepth := 0;
  lTypePos := 0;
  for i := 1 to Length(lMemberText) do
  begin
    if lMemberText[i] = '[' then
      Inc(lBracketDepth)
    else if (lMemberText[i] = ']') and (lBracketDepth > 0) then
      Dec(lBracketDepth)
    else if (lMemberText[i] = ':') and (lBracketDepth = 0) then
    begin
      lTypePos := i;
      Break;
    end;
  end;

  if lTypePos > 0 then
  begin
    aTypeName := Trim(Copy(lMemberText, lTypePos + 1, MaxInt));
    lPropertyTypeEnd := Pos(' read ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' write ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' index ', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(' default', LowerCase(aTypeName));
    if lPropertyTypeEnd = 0 then
      lPropertyTypeEnd := Pos(';', aTypeName);
    if lPropertyTypeEnd > 0 then
      aTypeName := Trim(Copy(aTypeName, 1, lPropertyTypeEnd - 1));
    lMemberText := Trim(Copy(lMemberText, 1, lTypePos - 1));
  end;

  lNameEnd := Pos('[', lMemberText);
  if lNameEnd > 0 then
  begin
    aIsIndexed := True;
    lIndexText := Copy(lMemberText, lNameEnd + 1, LastDelimiter(']', lMemberText) - lNameEnd - 1);
    if Trim(lIndexText) <> '' then
      aIndexParameterCount := Length(lIndexText.Split([';']));
  end else
    lNameEnd := Pos(';', lMemberText);

  if lNameEnd > 0 then
    aName := Trim(Copy(lMemberText, 1, lNameEnd - 1))
  else
    aName := Trim(lMemberText);
  Result := aName <> '';
end;

function InventoryTryTypeAlias(const aLine: string; out aName: string;
  out aTypeName: string): Boolean;
var
  lEqualsPos: Integer;
  lRight: string;
  lSemiPos: Integer;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
  lRight := Trim(Copy(aLine, lEqualsPos + 1, MaxInt));
  lSemiPos := Pos(';', lRight);
  if lSemiPos > 0 then
    lRight := Trim(Copy(lRight, 1, lSemiPos - 1));

  aTypeName := lRight;
  Result := (aName <> '') and (aTypeName <> '');
end;

function InventoryTryTypeStart(const aLine: string; out aName, aCategory: string): Boolean;
var
  lEqualsPos: Integer;
  lLower: string;
begin
  Result := False;
  aName := '';
  aCategory := 'unknown';
  lEqualsPos := Pos('=', aLine);
  if lEqualsPos = 0 then
    Exit;

  lLower := LowerCase(aLine);
  if (Pos(' record', lLower) = 0) and (Pos(' class', lLower) = 0) and
    (Pos(' interface', lLower) = 0) then
    Exit;

  if Pos(' record', lLower) > 0 then
    aCategory := 'record'
  else if Pos(' interface', lLower) > 0 then
    aCategory := 'interface'
  else if Pos(' class', lLower) > 0 then
    aCategory := 'class';

  aName := Trim(Copy(aLine, 1, lEqualsPos - 1));
  Result := aName <> '';
end;

function InventoryTryVariantTagDeclaration(const aLine: string; out aName,
  aTypeName: string): Boolean;
var
  lColonPos: Integer;
  lOfPos: Integer;
  lRest: string;
  lRestLower: string;
  lText: string;
begin
  Result := False;
  aName := '';
  aTypeName := '';
  lText := Trim(aLine);
  if not StartsText('case ', LowerCase(lText)) then
    Exit;

  lRest := Trim(Copy(lText, Length('case ') + 1, MaxInt));
  lRestLower := LowerCase(lRest);
  lColonPos := Pos(':', lRest);
  lOfPos := Pos(' of', lRestLower);
  if (lColonPos = 0) or (lOfPos = 0) or (lOfPos < lColonPos) then
    Exit;

  aName := Trim(Copy(lRest, 1, lColonPos - 1));
  aTypeName := Trim(Copy(lRest, lColonPos + 1, lOfPos - lColonPos - 1));
  Result := (aName <> '') and (aTypeName <> '');
end;

function InventoryVariantFieldDeclarationLine(const aLine: string): string;
var
  lInnerText: string;
  lOpenPos: Integer;
  lText: string;
begin
  Result := aLine;
  lText := Trim(aLine);
  lOpenPos := Pos('(', lText);
  if (lOpenPos > 1) and (Pos(':', Copy(lText, 1, lOpenPos - 1)) > 0) then
  begin
    lInnerText := Copy(lText, lOpenPos + 1, MaxInt);
    if Pos(':', lInnerText) > 0 then
      lText := Trim(Copy(lText, lOpenPos, MaxInt));
  end;
  if StartsText('(', lText) then
  begin
    lText := Trim(Copy(lText, 2, MaxInt));
    if EndsText(');', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';'
    else if EndsText(')', lText) then
      Result := Trim(Copy(lText, 1, Length(lText) - 1)) + ';'
    else
      Result := lText;
  end else if EndsText(');', lText) then
    Result := Trim(Copy(lText, 1, Length(lText) - 2)) + ';';
end;

function InventoryTryTypeRelation(const aLine: string; out aRelatedTypeName: string;
  out aIsHelper: Boolean): Boolean;
var
  lClosePos: Integer;
  lLower: string;
  lRelationPos: Integer;
  lStartPos: Integer;
  lText: string;
begin
  aRelatedTypeName := '';
  aIsHelper := False;
  lText := Trim(aLine);
  lLower := LowerCase(lText);

  lRelationPos := Pos(' helper for ', lLower);
  if lRelationPos > 0 then
  begin
    aIsHelper := True;
    aRelatedTypeName := Trim(Copy(lText, lRelationPos + Length(' helper for '), MaxInt));
    lClosePos := Pos(';', aRelatedTypeName);
    if lClosePos > 0 then
      aRelatedTypeName := Trim(Copy(aRelatedTypeName, 1, lClosePos - 1));
    Exit(aRelatedTypeName <> '');
  end;
  if Pos(' helper(', lLower) > 0 then
  begin
    aIsHelper := True;
    Exit(False);
  end;

  lStartPos := Pos('class(', lLower);
  if lStartPos > 0 then
  begin
    Inc(lStartPos, Length('class('));
    lClosePos := PosEx(')', lText, lStartPos);
    if lClosePos > lStartPos then
      aRelatedTypeName := Trim(Copy(lText, lStartPos, lClosePos - lStartPos));
    lClosePos := Pos(',', aRelatedTypeName);
    if lClosePos > 0 then
      aRelatedTypeName := Trim(Copy(aRelatedTypeName, 1, lClosePos - 1));
  end;
  if aRelatedTypeName = '' then
  begin
    lStartPos := Pos('interface(', lLower);
    if lStartPos > 0 then
    begin
      Inc(lStartPos, Length('interface('));
      lClosePos := PosEx(')', lText, lStartPos);
      if lClosePos > lStartPos then
        aRelatedTypeName := Trim(Copy(lText, lStartPos, lClosePos - lStartPos));
    end;
  end;
  Result := aRelatedTypeName <> '';
end;

function InventoryTryRoutineName(const aLine: string; out aName: string): Boolean;
var
  lNameEnd: Integer;
  lNameStart: Integer;
  lText: string;
begin
  Result := False;
  aName := '';
  lText := Trim(aLine);
  if StartsText('class procedure ', lText) then
    lNameStart := Length('class procedure ') + 1
  else if StartsText('class function ', lText) then
    lNameStart := Length('class function ') + 1
  else if StartsText('procedure ', lText) then
    lNameStart := Length('procedure ') + 1
  else if StartsText('function ', lText) then
    lNameStart := Length('function ') + 1
  else if StartsText('constructor ', lText) then
    lNameStart := Length('constructor ') + 1
  else if StartsText('destructor ', lText) then
    lNameStart := Length('destructor ') + 1
  else
    Exit;

  lNameEnd := lNameStart;
  while lNameEnd <= Length(lText) do
  begin
    if InventoryIsIdentifierChar(lText[lNameEnd]) or (lText[lNameEnd] = '.') then
      Inc(lNameEnd)
    else
      Break;
  end;
  aName := Copy(lText, lNameStart, lNameEnd - lNameStart);
  Result := aName <> '';
end;

function InventoryTryRoutineOwner(const aRoutineName: string; out aOwnerType: string): Boolean;
var
  lDotPos: Integer;
begin
  lDotPos := LastDelimiter('.', aRoutineName);
  Result := lDotPos > 0;
  if Result then
    aOwnerType := Copy(aRoutineName, 1, lDotPos - 1)
  else
    aOwnerType := '';
end;

function InventoryTokenCount(const aText, aToken: string): Integer;
var
  i: Integer;
  lEndPos: Integer;
  lStartPos: Integer;
begin
  Result := 0;
  i := 1;
  while i <= Length(aText) do
  begin
    if not InventoryIsIdentifierChar(aText[i]) then
    begin
      Inc(i);
      Continue;
    end;
    lStartPos := i;
    while (i <= Length(aText)) and InventoryIsIdentifierChar(aText[i]) do
      Inc(i);
    lEndPos := i - 1;
    if SameText(Copy(aText, lStartPos, lEndPos - lStartPos + 1), aToken) then
      Inc(Result);
  end;
end;

function InventoryEndTerminatedBlockOpenCount(const aText: string): Integer;
begin
  Result := InventoryTokenCount(aText, 'begin') + InventoryTokenCount(aText, 'case') +
    InventoryTokenCount(aText, 'try') + InventoryTokenCount(aText, 'asm');
end;

function InventoryFindRoutineEndLine(const aLines: TArray<string>; const aStartIndex: Integer):
  Integer;
var
  i: Integer;
  lDepth: Integer;
  lLine: string;
  lNestedEndLine: Integer;
  lStarted: Boolean;
begin
  Result := 0;
  lDepth := 0;
  lStarted := False;
  i := aStartIndex + 1;
  while i <= High(aLines) do
  begin
    lLine := LowerCase(InventoryCleanLine(aLines[i]));
    if lLine = '' then
    begin
      Inc(i);
      Continue;
    end;
    if not lStarted then
    begin
      if InventoryIsTopLevelLine(aLines[i]) and (InventoryIsRoutineStart(lLine) or
        SameText(lLine, 'implementation') or SameText(lLine, 'interface')) then
        Exit(0);
      if InventoryIsRoutineStart(lLine) then
      begin
        lNestedEndLine := InventoryFindRoutineEndLine(aLines, i);
        if lNestedEndLine > 0 then
        begin
          i := lNestedEndLine;
          Continue;
        end;
      end;
      if (InventoryTokenCount(lLine, 'begin') = 0) and (InventoryTokenCount(lLine, 'asm') = 0) then
      begin
        Inc(i);
        Continue;
      end;
      lStarted := True;
    end;
    Inc(lDepth, InventoryEndTerminatedBlockOpenCount(lLine));
    Dec(lDepth, InventoryTokenCount(lLine, 'end'));
    if lStarted and (lDepth <= 0) then
      Exit(i + 1);
    Inc(i);
  end;
end;

function InventoryCollectDeclarationText(const aLines: TArray<string>; const aStartLine: Integer;
  out aEndLine: Integer): string;
var
  i: Integer;
  j: Integer;
  lLine: string;
  lParenDepth: Integer;
begin
  Result := '';
  aEndLine := aStartLine;
  lParenDepth := 0;
  for i := aStartLine to High(aLines) do
  begin
    aEndLine := i;
    lLine := InventoryCleanLine(aLines[i]);
    if lLine <> '' then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + lLine;
      for j := 1 to Length(lLine) do
      begin
        if lLine[j] = '(' then
          Inc(lParenDepth)
        else if (lLine[j] = ')') and (lParenDepth > 0) then
          Dec(lParenDepth);
      end;
    end;
    if (Pos(';', lLine) > 0) and (lParenDepth = 0) then
      Exit;
  end;
end;

function InventoryCollectTypeStartText(const aLines: TArray<string>;
  const aStartLine: Integer): string;
var
  i: Integer;
  lLine: string;
  lText: string;
begin
  Result := '';
  for i := aStartLine to High(aLines) do
  begin
    lLine := InventoryCleanLine(aLines[i]);
    if lLine <> '' then
    begin
      if Result <> '' then
        Result := Result + ' ';
      Result := Result + lLine;
      lText := LowerCase(Result);
      if (Pos(' class', lText) > 0) or (Pos(' record', lText) > 0) or
        (Pos(' interface', lText) > 0) or (Pos(';', lLine) > 0) then
        Exit;
    end;
  end;
end;

function InventoryUnsupportedReasonForTypeStart(const aTypeName, aPendingReason: string;
  const aConditionalDepth: Integer): string;
begin
  if aPendingReason <> '' then
    Exit(aPendingReason);
  if aConditionalDepth > 0 then
    Exit('unsupported-source-model-conditional-region');
  if Pos('<', aTypeName) > 0 then
    Exit('unsupported-source-model-generic-declaration');
  Result := '';
end;

function InventoryFindTypeEndLine(const aLines: TArray<string>; const aStartIndex: Integer):
  Integer;
var
  i: Integer;
  lLine: string;
begin
  Result := aStartIndex + 1;
  for i := aStartIndex + 1 to High(aLines) do
  begin
    lLine := LowerCase(InventoryCleanLine(aLines[i]));
    if SameText(lLine, 'end;') or SameText(lLine, 'end') or StartsText('end ', lLine) then
      Exit(i + 1);
  end;
end;

function InventoryFindNameSource(const aLines: TArray<string>; const aStartIndex,
  aEndIndex: Integer; const aName: string; out aLineNumber: Integer;
  out aLineText: string): Boolean;
var
  i: Integer;
  lEndIndex: Integer;
begin
  Result := False;
  aLineNumber := 0;
  aLineText := '';
  lEndIndex := aEndIndex;
  if lEndIndex > High(aLines) then
    lEndIndex := High(aLines);
  for i := aStartIndex to lEndIndex do
  begin
    if Pos(aName, aLines[i]) > 0 then
    begin
      aLineNumber := i + 1;
      aLineText := aLines[i];
      Exit(True);
    end;
  end;
end;

function InventoryDecodeSourceText(const aBytes: TBytes): string;
var
  lOffset: Integer;
begin
  lOffset := 0;
  if (Length(aBytes) >= 3) and (aBytes[0] = $EF) and (aBytes[1] = $BB) and
    (aBytes[2] = $BF) then
    lOffset := 3;

  try
    Result := TEncoding.UTF8.GetString(aBytes, lOffset, Length(aBytes) - lOffset);
  except
    on E: EEncodingError do
      Result := TEncoding.Default.GetString(aBytes, lOffset, Length(aBytes) - lOffset);
  end;
end;

function InventoryReadSourceLines(const aFileName: string): TArray<string>;
var
  i: Integer;
  lLines: TStringList;
  lText: string;
begin
  SetLength(Result, 0);
  if not TFile.Exists(aFileName) then
    Exit;

  lText := InventoryDecodeSourceText(TFile.ReadAllBytes(aFileName));
  lLines := TStringList.Create;
  try
    lLines.Text := lText;
    SetLength(Result, lLines.Count);
    for i := 0 to lLines.Count - 1 do
      Result[i] := lLines[i];
  finally
    lLines.Free;
  end;
end;

procedure AddDakInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aTypeName, aOwnerType, aRoutineName, aUnitName, aFileName: string;
  const aLineNumber: Integer; const aLineText, aKind: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aName;
  lSymbol.SymbolClass := aKind;
  lSymbol.Kind := aKind;
  lSymbol.TypeName := aTypeName;
  lSymbol.OwnerName := aOwnerType;
  lSymbol.OwnerType := aOwnerType;
  lSymbol.RoutineName := aRoutineName;
  lSymbol.UnitName := aUnitName;
  lSymbol.FileName := aFileName;
  lSymbol.Line := aLineNumber;
  lSymbol.EndLine := aLineNumber;
  lSymbol.Column := InventoryFindColumn(aLineText, aName);
  lSymbol.EndColumn := lSymbol.Column + Length(aName);
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddDakInventoryTypeSymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aTypeName, aTypeCategory, aUnitName, aFileName: string; const aLineNumber,
  aEndLine: Integer; const aLineText: string);
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aName;
  lSymbol.SymbolClass := 'type-member';
  lSymbol.Kind := 'type-member';
  lSymbol.TypeName := aTypeName;
  lSymbol.TypeCategory := aTypeCategory;
  lSymbol.UnitName := aUnitName;
  lSymbol.FileName := aFileName;
  lSymbol.Line := aLineNumber;
  lSymbol.EndLine := aEndLine;
  lSymbol.Column := InventoryFindColumn(aLineText, aName);
  lSymbol.EndColumn := lSymbol.Column + Length(aName);
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddDakInventorySymbolsFromSource(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aNames: TArray<string>; const aTypeName, aOwnerType, aRoutineName, aUnitName,
  aFileName: string; const aLines: TArray<string>; const aStartIndex, aEndIndex: Integer;
  const aKind: string);
var
  lLineNumber: Integer;
  lLineText: string;
  lName: string;
begin
  for lName in aNames do
  begin
    if not InventoryFindNameSource(aLines, aStartIndex, aEndIndex, lName, lLineNumber,
      lLineText) then
    begin
      lLineNumber := aStartIndex + 1;
      if (aStartIndex >= 0) and (aStartIndex <= High(aLines)) then
        lLineText := aLines[aStartIndex]
      else
        lLineText := lName;
    end;
    AddDakInventorySymbol(aSymbols, lName, aTypeName, aOwnerType, aRoutineName, aUnitName,
      aFileName, lLineNumber, lLineText, aKind);
  end;
end;

procedure MarkDakTypeUnsupported(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aTypeName, aReason: string);
var
  i: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;
begin
  if aReason = '' then
    Exit;
  lTypeName := InventorySimpleTypeName(aTypeName);
  for i := 0 to Pred(aSymbols.Count) do
  begin
    lSymbol := aSymbols[i];
    if SameText(lSymbol.SymbolClass, 'type-member') and SameText(lSymbol.Name, lTypeName) then
    begin
      if lSymbol.UnsupportedReason = '' then
      begin
        lSymbol.UnsupportedReason := aReason;
        aSymbols[i] := lSymbol;
      end;
      Exit;
    end;
  end;
end;

procedure AddDakTypedSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aNames: TArray<string>; const aTypeName, aOwnerType, aRoutineName, aUnitName,
  aFileName: string; const aLineNumber: Integer; const aLineText, aKind: string);
var
  lName: string;
begin
  for lName in aNames do
    AddDakInventorySymbol(aSymbols, lName, aTypeName, aOwnerType, aRoutineName, aUnitName,
      aFileName, aLineNumber, aLineText, aKind);
end;

function InventoryTryAnonymousRecordLocalStart(const aLine: string; out aName,
  aTypeCategory: string): Boolean;
var
  lColonPos: Integer;
  lRest: string;
begin
  Result := False;
  aName := '';
  aTypeCategory := '';
  lColonPos := Pos(':', aLine);
  if lColonPos = 0 then
    Exit;

  aName := Trim(Copy(aLine, 1, lColonPos - 1));
  lRest := LowerCase(Trim(Copy(aLine, lColonPos + 1, MaxInt)));
  if StartsText('packed record', lRest) or StartsText('record', lRest) then
    aTypeCategory := 'record'
  else
    Exit;

  Result := aName <> '';
end;

procedure AddDakInventoryRecordFieldsFromLine(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aLineIndex: Integer; const aOwnerType, aUnitName,
  aFileName: string);
var
  lDeclaration: string;
  lDeclarationParts: TArray<string>;
  lLine: string;
  lMemberName: string;
  lNames: TArray<string>;
  lRawDeclaration: string;
  lTypeName: string;
begin
  lLine := InventoryVariantFieldDeclarationLine(InventoryCleanLine(aLines[aLineIndex]));
  if lLine = '' then
    Exit;
  if InventoryTryVariantTagDeclaration(lLine, lMemberName, lTypeName) then
  begin
    AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, aOwnerType, '', aUnitName,
      aFileName, aLineIndex + 1, aLines[aLineIndex], 'field');
    Exit;
  end;

  lDeclarationParts := lLine.Split([';']);
  for lRawDeclaration in lDeclarationParts do
  begin
    lDeclaration := Trim(lRawDeclaration);
    if lDeclaration = '' then
      Continue;
    if InventoryTryDeclaration(lDeclaration + ';', lNames, lTypeName) then
      AddDakTypedSymbols(aSymbols, lNames, lTypeName, aOwnerType, '', aUnitName, aFileName,
        aLineIndex + 1, aLines[aLineIndex], 'field');
  end;
end;

procedure ParseDakInventoryParams(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aStartIndex: Integer; const aSignature, aRoutineName,
  aUnitName, aFileName: string);
var
  lClosePos: Integer;
  lEndIndex: Integer;
  lNames: TArray<string>;
  lOpenPos: Integer;
  lPart: string;
  lParts: TArray<string>;
  lText: string;
  lTypeName: string;
begin
  lOpenPos := Pos('(', aSignature);
  lClosePos := LastDelimiter(')', aSignature);
  if (lOpenPos = 0) or (lClosePos <= lOpenPos) then
    Exit;

  lParts := Copy(aSignature, lOpenPos + 1, lClosePos - lOpenPos - 1).Split([';']);
  for lPart in lParts do
  begin
    lText := Trim(lPart);
    if StartsText('const ', lText) then
      Delete(lText, 1, Length('const '))
    else if StartsText('var ', lText) then
      Delete(lText, 1, Length('var '))
    else if StartsText('out ', lText) then
      Delete(lText, 1, Length('out '));

    if InventoryTryDeclaration(lText, lNames, lTypeName) then
    begin
      lEndIndex := aStartIndex + 20;
      AddDakInventorySymbolsFromSource(aSymbols, lNames, lTypeName, '', aRoutineName, aUnitName,
        aFileName, aLines, aStartIndex, lEndIndex, 'parameter');
    end;
  end;
end;

procedure ParseDakInventoryLocals(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aStartLine: Integer; const aRoutineName, aUnitName,
  aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lConstName: string;
  lCurrentType: string;
  lDeclaration: string;
  lDeclarationLine: Integer;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInType: Boolean;
  lInConst: Boolean;
  lInVar: Boolean;
  lLine: string;
  lNames: TArray<string>;
  lRawTypeName: string;
  lSkipUntilLine: Integer;
  lTypeCategory: string;
  lTypeText: string;
  lTypeName: string;
begin
  lCurrentType := '';
  lDeclaration := '';
  lDeclarationLine := 0;
  lInConst := False;
  lInType := False;
  lInVar := False;
  lSkipUntilLine := 0;
  for i := aStartLine to High(aLines) do
  begin
    if i < lSkipUntilLine then
      Continue;
    lLine := InventoryCleanLine(aLines[i]);
    if SameText(lLine, 'const') then
    begin
      lCurrentType := '';
      lInConst := True;
      lInType := False;
      lInVar := False;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'type') then
    begin
      lCurrentType := '';
      lInConst := False;
      lInType := True;
      lInVar := False;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'var') then
    begin
      lCurrentType := '';
      lInConst := False;
      lInType := False;
      lInVar := True;
      lDeclaration := '';
      Continue;
    end;
    if SameText(lLine, 'begin') then
      Exit;
    if InventoryIsRoutineStart(lLine) then
    begin
      lSkipUntilLine := InventoryFindRoutineEndLine(aLines, i);
      if lSkipUntilLine = 0 then
        Exit;
      Continue;
    end;
    if StartsText('const ', LowerCase(lLine)) then
    begin
      lInConst := True;
      lInVar := False;
      lLine := Trim(Copy(lLine, Length('const ') + 1, MaxInt));
    end;
    if lInType and (lLine <> '') then
    begin
      if (lCurrentType <> '') and (SameText(lLine, 'end;') or SameText(lLine, 'end')) then
      begin
        lCurrentType := '';
        Continue;
      end;

      if lCurrentType = '' then
      begin
        lTypeText := InventoryCollectTypeStartText(aLines, i);
        if InventoryTryTypeStart(lTypeText, lRawTypeName, lTypeCategory) then
        begin
          lCurrentType := InventorySimpleTypeName(lRawTypeName);
          AddDakInventoryTypeSymbol(aSymbols, lCurrentType, '', lTypeCategory, aUnitName,
            aFileName, i + 1, InventoryFindTypeEndLine(aLines, i), aLines[i]);
          if InventoryTryEnumValues(lTypeText, lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', aRoutineName, aUnitName,
              aFileName, i + 1, aLines[i], 'constant');
        end else if InventoryTryTypeAlias(lTypeText, lCurrentType, lTypeName) then
        begin
          AddDakInventorySymbol(aSymbols, lCurrentType, lTypeName, '', '', aUnitName,
            aFileName, i + 1, aLines[i], 'type-member');
          if InventoryTryEnumValues(lTypeText, lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', aRoutineName, aUnitName,
              aFileName, i + 1, aLines[i], 'constant');
        end;
        Continue;
      end;

      AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, i, lCurrentType, aUnitName,
        aFileName);
      Continue;
    end;
    if lInConst and (lLine <> '') and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', aRoutineName, aUnitName,
        aFileName, i + 1, aLines[i], 'constant');
      Continue;
    end;
    if lInVar and (lLine <> '') then
    begin
      if InventoryTryAnonymousRecordLocalStart(lLine, lConstName, lTypeCategory) then
      begin
        lTypeName := aRoutineName + '.' + lConstName;
        lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
        AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
          aFileName, i + 1, lAnonymousEndLine, aLines[i]);
        AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', aRoutineName, aUnitName,
          aFileName, i + 1, aLines[i], 'local');
        for j := i + 1 to lAnonymousEndLine - 2 do
          AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
            aFileName);
        lSkipUntilLine := lAnonymousEndLine;
        lDeclaration := '';
        lDeclarationLine := 0;
        Continue;
      end;
      if lDeclaration = '' then
        lDeclarationLine := i + 1;
      if lDeclaration <> '' then
        lDeclaration := lDeclaration + ' ';
      lDeclaration := lDeclaration + lLine;
      if Pos(';', lLine) > 0 then
      begin
        if InventoryTryDeclaration(lDeclaration, lNames, lTypeName) then
        begin
          AddDakInventorySymbolsFromSource(aSymbols, lNames, lTypeName, '', aRoutineName,
            aUnitName, aFileName, aLines, lDeclarationLine - 1, i, 'local');
          lEnumMatch := TRegEx.Match(lDeclaration, ':\s*\(([^)]*)\)');
          if lEnumMatch.Success and
            InventoryTryEnumValues('TAnonymousEnum = (' + lEnumMatch.Groups[1].Value + ')', lEnumNames) then
            AddDakTypedSymbols(aSymbols, lEnumNames, lTypeName, '', aRoutineName, aUnitName,
              aFileName, lDeclarationLine, aLines[lDeclarationLine - 1], 'constant');
        end;
        lDeclaration := '';
        lDeclarationLine := 0;
      end;
    end;
  end;
end;

procedure ParseDakInventoryTypeMembers(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lCollectedEndLine: Integer;
  lConditionalDepth: Integer;
  lConstName: string;
  lCurrentType: string;
  lCurrentTypeUnsupportedReason: string;
  lDeclaration: string;
  lDeclarationAdded: Boolean;
  lDeclarationParts: TArray<string>;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInClassVar: Boolean;
  lInConst: Boolean;
  lInTypeSection: Boolean;
  lLine: string;
  lLower: string;
  lMemberName: string;
  lNames: TArray<string>;
  lPendingUnsupportedReason: string;
  lPropertyIndexed: Boolean;
  lPropertyIndexParameterCount: Integer;
  lPropertyIsDefault: Boolean;
  lPropertyType: string;
  lRawDeclaration: string;
  lRawLine: string;
  lRawTypeName: string;
  lRelatedTypeName: string;
  lSkipUntilLine: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeCategory: string;
  lTypeIsHelper: Boolean;
  lTypeName: string;
  lTypeText: string;
begin
  lConditionalDepth := 0;
  lCurrentType := '';
  lCurrentTypeUnsupportedReason := '';
  lInClassVar := False;
  lInConst := False;
  lInTypeSection := False;
  lPendingUnsupportedReason := '';
  lSkipUntilLine := 0;
  for i := 0 to High(aLines) do
  begin
    if i < lSkipUntilLine then
      Continue;
    lRawLine := aLines[i];
    lLine := InventoryCleanLine(lRawLine);
    lLower := LowerCase(lLine);
    if lLine = '' then
      Continue;

    if InventoryIsConditionalDirectiveLine(lLine) then
    begin
      if lCurrentType <> '' then
      begin
        lCurrentTypeUnsupportedReason := 'unsupported-source-model-conditional-region';
        MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      end else if lInTypeSection and (not InventoryIsConditionalEndDirective(lLine)) then
        lPendingUnsupportedReason := 'unsupported-source-model-conditional-region';

      if InventoryIsConditionalStartDirective(lLine) then
        Inc(lConditionalDepth)
      else if InventoryIsConditionalEndDirective(lLine) and (lConditionalDepth > 0) then
        Dec(lConditionalDepth);
      Continue;
    end;

    if InventoryIsAttributeLine(lLine) then
    begin
      if lCurrentType <> '' then
      begin
        lCurrentTypeUnsupportedReason := 'unsupported-source-model-attribute';
        MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      end else if lInTypeSection then
        lPendingUnsupportedReason := 'unsupported-source-model-attribute';
      Continue;
    end;

    if (lCurrentType = '') and SameText(lLine, 'type') then
    begin
      lConditionalDepth := 0;
      lInTypeSection := True;
      Continue;
    end;
    if SameText(lLine, 'implementation') or ((lCurrentType = '') and
      (SameText(lLine, 'const') or SameText(lLine, 'var') or SameText(lLine, 'threadvar') or
      InventoryIsRoutineStart(lLine))) then
    begin
      lCurrentType := '';
      lCurrentTypeUnsupportedReason := '';
      lInTypeSection := False;
      lInClassVar := False;
      lInConst := False;
      lPendingUnsupportedReason := '';
      Continue;
    end;

    if lCurrentType = '' then
    begin
      if not lInTypeSection then
        Continue;
      lTypeText := InventoryCollectTypeStartText(aLines, i);
      if InventoryTryTypeStart(lTypeText, lRawTypeName, lTypeCategory) then
      begin
        lCurrentType := InventorySimpleTypeName(lRawTypeName);
        lCurrentTypeUnsupportedReason := InventoryUnsupportedReasonForTypeStart(lRawTypeName,
          lPendingUnsupportedReason, lConditionalDepth);
        lInClassVar := False;
        lInConst := False;
        InventoryTryTypeRelation(lTypeText, lRelatedTypeName, lTypeIsHelper);
        lSymbol := Default(TDelphiSemanticInventorySymbol);
        lSymbol.Name := lCurrentType;
        lSymbol.SymbolClass := 'type-member';
        lSymbol.Kind := 'type-member';
        lSymbol.RelatedTypeName := lRelatedTypeName;
        lSymbol.IsHelper := lTypeIsHelper;
        lSymbol.TypeCategory := lTypeCategory;
        lSymbol.UnitName := aUnitName;
        lSymbol.FileName := aFileName;
        lSymbol.Line := i + 1;
        lSymbol.EndLine := InventoryFindTypeEndLine(aLines, i);
        lSymbol.Column := InventoryFindColumn(aLines[i], lCurrentType);
        lSymbol.EndColumn := lSymbol.Column + Length(lCurrentType);
        lSymbol.UnsupportedReason := lCurrentTypeUnsupportedReason;
        AddInventorySymbol(aSymbols, lSymbol);
        if InventoryTryEnumValues(lTypeText, lEnumNames) then
          AddDakTypedSymbols(aSymbols, lEnumNames, lCurrentType, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'constant');
        lPendingUnsupportedReason := '';
      end else if InventoryTryTypeAlias(lTypeText, lMemberName, lTypeName) then
      begin
        AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, '', '', aUnitName, aFileName,
          i + 1, aLines[i], 'type-member');
        lSymbol := aSymbols[Pred(aSymbols.Count)];
        lSymbol.RelatedTypeName := InventorySimpleTypeName(lTypeName);
        aSymbols[Pred(aSymbols.Count)] := lSymbol;
        if InventoryTryEnumValues(lTypeText, lEnumNames) then
          AddDakTypedSymbols(aSymbols, lEnumNames, lMemberName, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'constant');
        lPendingUnsupportedReason := '';
      end;
      Continue;
    end;

    if SameText(lLine, 'end;') or SameText(lLine, 'end') then
    begin
      lCurrentType := '';
      lCurrentTypeUnsupportedReason := '';
      Continue;
    end;
    if InventoryIsVisibilityLine(lLine) then
      Continue;
    if SameText(lLine, 'type') then
    begin
      lCurrentTypeUnsupportedReason := 'unsupported-source-model-nested-type';
      MarkDakTypeUnsupported(aSymbols, lCurrentType, lCurrentTypeUnsupportedReason);
      Continue;
    end;
    if InventoryIsMultilineDeclarationStart(lLine) then
    begin
      lLine := InventoryCollectDeclarationText(aLines, i, lCollectedEndLine);
      lSkipUntilLine := lCollectedEndLine + 1;
    end;
    if lCurrentTypeUnsupportedReason <> '' then
      Continue;
    if InventoryTryAnonymousRecordLocalStart(lLine, lMemberName, lTypeCategory) then
    begin
      lTypeName := lCurrentType + '.' + lMemberName;
      lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
      AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
        aFileName, i + 1, lAnonymousEndLine, aLines[i]);
      AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'field');
      for j := i + 1 to lAnonymousEndLine - 2 do
        AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
          aFileName);
      lSkipUntilLine := lAnonymousEndLine;
      Continue;
    end;
    lLine := InventoryVariantFieldDeclarationLine(lLine);
    lLower := LowerCase(lLine);
    if InventoryTryVariantTagDeclaration(lLine, lMemberName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lMemberName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'field');
      Continue;
    end;
    if StartsText('class var', lLower) then
    begin
      lInClassVar := True;
      lLine := Trim(Copy(lLine, Length('class var') + 1, MaxInt));
      if lLine = '' then
        Continue;
    end;
    if SameText(lLine, 'const') then
    begin
      lInConst := True;
      lInClassVar := False;
      Continue;
    end;
    if StartsText('const ', lLower) then
    begin
      lInConst := True;
      lLine := Trim(Copy(lLine, Length('const ') + 1, MaxInt));
    end;

    if lInConst and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
    begin
      AddDakInventorySymbol(aSymbols, lConstName, lTypeName, lCurrentType, '', aUnitName,
        aFileName, i + 1, aLines[i], 'constant');
      Continue;
    end;

    if InventoryTryPropertyDeclaration(lLine, lMemberName, lPropertyType, lPropertyIsDefault,
      lPropertyIndexed, lPropertyIndexParameterCount) then
    begin
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMemberName;
      lSymbol.SymbolClass := 'property';
      lSymbol.Kind := 'property';
      lSymbol.TypeName := lPropertyType;
      lSymbol.OwnerName := lCurrentType;
      lSymbol.OwnerType := lCurrentType;
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := i + 1;
      lSymbol.Column := InventoryFindColumn(aLines[i], lMemberName);
      lSymbol.EndColumn := lSymbol.Column + Length(lMemberName);
      lSymbol.IsDefault := lPropertyIsDefault;
      lSymbol.IsIndexed := lPropertyIndexed;
      lSymbol.IndexParameterCount := lPropertyIndexParameterCount;
      AddInventorySymbol(aSymbols, lSymbol);
      Continue;
    end;

    if InventoryIsRoutineStart(lLine) and InventoryTryRoutineName(lLine, lMemberName) then
    begin
      if Pos('.', lMemberName) > 0 then
        lMemberName := Copy(lMemberName, LastDelimiter('.', lMemberName) + 1, MaxInt);
      lSymbol := Default(TDelphiSemanticInventorySymbol);
      lSymbol.Name := lMemberName;
      lSymbol.SymbolClass := 'method';
      lSymbol.Kind := 'method';
      lSymbol.OwnerName := lCurrentType;
      lSymbol.OwnerType := lCurrentType;
      lSymbol.UnitName := aUnitName;
      lSymbol.FileName := aFileName;
      lSymbol.Line := i + 1;
      lSymbol.EndLine := i + 1;
      lSymbol.Column := InventoryFindColumn(aLines[i], lMemberName);
      lSymbol.EndColumn := lSymbol.Column + Length(lMemberName);
      lSymbol.IsOverride := Pos(' override', lLower) > 0;
      AddInventorySymbol(aSymbols, lSymbol);
      Continue;
    end;

    lDeclarationAdded := False;
    lDeclarationParts := lLine.Split([';']);
    for lRawDeclaration in lDeclarationParts do
    begin
      lDeclaration := Trim(lRawDeclaration);
      if lDeclaration = '' then
        Continue;
      if not InventoryTryDeclaration(lDeclaration + ';', lNames, lTypeName) then
        Continue;

      if lInClassVar then
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'class-var')
      else
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'field');
      lDeclarationAdded := True;
    end;
    if lDeclarationAdded then
      Continue;

    if InventoryTryDeclaration(lLine, lNames, lTypeName) then
    begin
      if lInClassVar then
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'class-var')
      else
        AddDakTypedSymbols(aSymbols, lNames, lTypeName, lCurrentType, '', aUnitName, aFileName,
          i + 1, aLines[i], 'field');
    end;
  end;
end;

procedure ParseDakInventoryUnitGlobals(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  j: Integer;
  lAnonymousEndLine: Integer;
  lConstName: string;
  lDeclaration: string;
  lDeclarationLine: Integer;
  lEnumMatch: TMatch;
  lEnumNames: TArray<string>;
  lInConst: Boolean;
  lInType: Boolean;
  lInVar: Boolean;
  lLine: string;
  lNames: TArray<string>;
  lRawLine: string;
  lRoutineEndLine: Integer;
  lTypeCategory: string;
  lTypeName: string;
begin
  lDeclaration := '';
  lDeclarationLine := 0;
  lInConst := False;
  lInType := False;
  lInVar := False;
  i := 0;
  while i <= High(aLines) do
  begin
    try
      lRawLine := aLines[i];
      lLine := InventoryCleanLine(lRawLine);
      if lLine = '' then
        Continue;

      if SameText(lLine, 'implementation') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInVar := False;
        lInConst := False;
        Continue;
      end;

      if SameText(lLine, 'type') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := True;
        lInVar := False;
        lInConst := False;
        Continue;
      end;
      if SameText(lLine, 'var') or SameText(lLine, 'threadvar') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInVar := True;
        lInConst := False;
        Continue;
      end;
      if SameText(lLine, 'const') then
      begin
        lDeclaration := '';
        lDeclarationLine := 0;
        lInType := False;
        lInConst := True;
        lInVar := False;
        Continue;
      end;

      if InventoryIsConditionalDirectiveLine(lLine) then
        Continue;

      if lInType then
        Continue;

      if InventoryIsRoutineStart(lLine) then
      begin
        lInVar := False;
        lInConst := False;
        lRoutineEndLine := InventoryFindRoutineEndLine(aLines, i);
        if lRoutineEndLine > 0 then
          i := lRoutineEndLine - 1;
        Continue;
      end;

      if lInVar and (lLine <> '') then
      begin
        if (lDeclaration = '') and InventoryTryAnonymousRecordLocalStart(lLine, lConstName,
          lTypeCategory) then
        begin
          lTypeName := aUnitName + '.' + lConstName;
          lAnonymousEndLine := InventoryFindTypeEndLine(aLines, i);
          AddDakInventoryTypeSymbol(aSymbols, lTypeName, '', lTypeCategory, aUnitName,
            aFileName, i + 1, lAnonymousEndLine, aLines[i]);
          AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', '', aUnitName, aFileName,
            i + 1, aLines[i], 'unit-global');
          for j := i + 1 to lAnonymousEndLine - 2 do
            AddDakInventoryRecordFieldsFromLine(aSymbols, aLines, j, lTypeName, aUnitName,
              aFileName);
          i := lAnonymousEndLine - 1;
          Continue;
        end;

        if lDeclaration = '' then
          lDeclarationLine := i + 1;
        if lDeclaration <> '' then
          lDeclaration := lDeclaration + ' ';
        lDeclaration := lDeclaration + lLine;
        if Pos(';', lLine) > 0 then
        begin
          if InventoryTryDeclaration(lDeclaration, lNames, lTypeName) then
          begin
            AddDakTypedSymbols(aSymbols, lNames, lTypeName, '', '', aUnitName, aFileName,
              lDeclarationLine, aLines[lDeclarationLine - 1], 'unit-global');
            lEnumMatch := TRegEx.Match(lDeclaration, ':\s*\(([^)]*)\)');
            if lEnumMatch.Success and
              InventoryTryEnumValues('TAnonymousEnum = (' + lEnumMatch.Groups[1].Value + ')',
              lEnumNames) then
              AddDakTypedSymbols(aSymbols, lEnumNames, lTypeName, '', '', aUnitName,
                aFileName, lDeclarationLine, aLines[lDeclarationLine - 1], 'constant');
          end;
          lDeclaration := '';
          lDeclarationLine := 0;
        end;
      end else if lInConst and InventoryTryConstDeclaration(lLine, lConstName, lTypeName) then
        AddDakInventorySymbol(aSymbols, lConstName, lTypeName, '', '', aUnitName, aFileName,
          i + 1, aLines[i], 'constant');
    finally
      Inc(i);
    end;
  end;
end;

procedure ParseDakInventoryRoutines(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aLines: TArray<string>; const aUnitName, aFileName: string);
var
  i: Integer;
  j: Integer;
  lEndLine: Integer;
  lInImplementation: Boolean;
  lInType: Boolean;
  lLine: string;
  lMember: TDelphiSemanticInventorySymbol;
  lMemberCount: Integer;
  lOwnerType: string;
  lRawLine: string;
  lRoutineName: string;
  lSignature: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTopLevelLine: Boolean;
begin
  lInImplementation := False;
  lInType := False;
  for i := 0 to High(aLines) do
  begin
    lRawLine := aLines[i];
    lLine := InventoryCleanLine(lRawLine);
    if lLine = '' then
      Continue;
    lTopLevelLine := InventoryIsTopLevelLine(lRawLine);
    if lTopLevelLine and SameText(lLine, 'type') then
    begin
      lInType := True;
      Continue;
    end;
    if lTopLevelLine and (SameText(lLine, 'const') or SameText(lLine, 'var') or
      SameText(lLine, 'threadvar') or SameText(lLine, 'implementation')) then
    begin
      lInType := False;
      if SameText(lLine, 'implementation') then
      begin
        lInImplementation := True;
        Continue;
      end;
    end;
    if lInImplementation and lTopLevelLine and InventoryIsRoutineStart(lLine) then
      lInType := False;
    if lInType then
      Continue;

    if (not lTopLevelLine) and (not InventoryIsRoutineStart(lLine)) then
      Continue;
    lSignature := InventoryCollectDeclarationText(aLines, i, lEndLine);
    if not InventoryTryRoutineName(lSignature, lRoutineName) then
      Continue;

    lSymbol := Default(TDelphiSemanticInventorySymbol);
    lSymbol.Name := lRoutineName;
    lSymbol.SymbolClass := 'routine';
    lSymbol.Kind := 'routine';
    lSymbol.UnitName := aUnitName;
    lSymbol.FileName := aFileName;
    lSymbol.Line := i + 1;
    lSymbol.EndLine := InventoryFindRoutineEndLine(aLines, i);
    if lSymbol.EndLine = 0 then
      Continue;
    lSymbol.Column := InventoryFindColumn(aLines[i], lRoutineName);
    lSymbol.EndColumn := lSymbol.Column + Length(lRoutineName);
    AddInventorySymbol(aSymbols, lSymbol);
    ParseDakInventoryParams(aSymbols, aLines, i, lSignature, lRoutineName, aUnitName, aFileName);
    ParseDakInventoryLocals(aSymbols, aLines, i + 1, lRoutineName, aUnitName, aFileName);

    if InventoryTryRoutineOwner(lRoutineName, lOwnerType) then
    begin
      lMemberCount := aSymbols.Count;
      for j := 0 to lMemberCount - 1 do
      begin
        lMember := aSymbols[j];
        if SameText(lMember.OwnerType, lOwnerType) and (lMember.RoutineName = '') and
          InventoryIsDirectMemberKind(lMember.SymbolClass) then
        begin
          lMember.SymbolClass := 'current-class-member';
          lMember.Kind := 'current-class-member';
          lMember.RoutineName := lRoutineName;
          AddInventorySymbol(aSymbols, lMember);
        end;
      end;
    end;
  end;
end;

procedure AddDakCompatibleInventorySymbols(const aModel: TDelphiSemanticUnitModel;
  const aSymbols: TList<TDelphiSemanticInventorySymbol>);
var
  lLines: TArray<string>;
begin
  AddDakInventorySymbol(aSymbols, aModel.UnitName, '', '', '', aModel.UnitName, aModel.FileName,
    1, aModel.UnitName, 'unit');
  lLines := InventoryReadSourceLines(aModel.FileName);
  ParseDakInventoryTypeMembers(aSymbols, lLines, aModel.UnitName, aModel.FileName);
  ParseDakInventoryUnitGlobals(aSymbols, lLines, aModel.UnitName, aModel.FileName);
  ParseDakInventoryRoutines(aSymbols, lLines, aModel.UnitName, aModel.FileName);
end;

function InventorySameSymbol(const aLeft, aRight: TDelphiSemanticInventorySymbol): Boolean;
begin
  Result := SameText(aLeft.SymbolClass, aRight.SymbolClass) and SameText(aLeft.Name, aRight.Name) and
    SameText(aLeft.TypeName, aRight.TypeName) and SameText(aLeft.OwnerType, aRight.OwnerType) and
    SameText(aLeft.SourceOwnerType, aRight.SourceOwnerType) and
    SameText(aLeft.RelatedTypeName, aRight.RelatedTypeName) and
    SameText(aLeft.RoutineName, aRight.RoutineName) and SameText(aLeft.UnitName, aRight.UnitName) and
    SameText(aLeft.FileName, aRight.FileName) and (aLeft.Line = aRight.Line) and
    (aLeft.Column = aRight.Column) and SameText(aLeft.UnsupportedReason, aRight.UnsupportedReason) and
    (aLeft.IsHelper = aRight.IsHelper) and (aLeft.IsOverride = aRight.IsOverride) and
    (aLeft.IsDefault = aRight.IsDefault) and SameText(aLeft.TypeCategory, aRight.TypeCategory);
end;

function InventorySymbolKey(const aSymbol: TDelphiSemanticInventorySymbol): string;
const
  cSeparator = #31;
begin
  Result := aSymbol.SymbolClass + cSeparator + aSymbol.Name + cSeparator +
    aSymbol.TypeName + cSeparator + aSymbol.OwnerType + cSeparator +
    aSymbol.SourceOwnerType + cSeparator + aSymbol.RelatedTypeName +
    cSeparator + aSymbol.RoutineName + cSeparator + aSymbol.UnitName +
    cSeparator + aSymbol.FileName + cSeparator + IntToStr(aSymbol.Line) +
    cSeparator + IntToStr(aSymbol.Column) + cSeparator + aSymbol.UnsupportedReason +
    cSeparator + IntToStr(Ord(aSymbol.IsHelper)) + cSeparator +
    IntToStr(Ord(aSymbol.IsOverride)) + cSeparator + IntToStr(Ord(aSymbol.IsDefault)) +
    cSeparator + aSymbol.TypeCategory;
end;

function AddExpandedInventorySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aSymbols do
    if InventorySameSymbol(lSymbol, aSymbol) then
      Exit(False);

  aSymbols.Add(aSymbol);
  Result := True;
end;

function AddExpandedInventorySymbolWithKeys(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>; const aSymbol: TDelphiSemanticInventorySymbol): Boolean;
var
  lKey: string;
begin
  lKey := InventorySymbolKey(aSymbol);
  if aKeys.ContainsKey(lKey) then
    Exit(False);

  aKeys.Add(lKey, 1);
  aSymbols.Add(aSymbol);
  Result := True;
end;

function InventoryOwnMemberKey(const aOwnerType, aName: string): string;
const
  cSeparator = #31;
begin
  Result := aOwnerType + cSeparator + aName;
end;

function BuildInventoryOwnMemberKeys(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aSymbolCount: Integer): TDictionary<string, Byte>;
var
  i: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for i := 0 to aSymbolCount - 1 do
  begin
    lSymbol := aSymbols[i];
    if (lSymbol.OwnerType <> '') and (lSymbol.SourceOwnerType = '') and
      InventoryIsDirectMemberKind(lSymbol.SymbolClass) then
      Result.AddOrSetValue(InventoryOwnMemberKey(lSymbol.OwnerType, lSymbol.Name), 1);
  end;
end;

procedure AddRelatedInventoryMemberSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lAdded: Boolean;
  lBeforeCount: Integer;
  lMember: TDelphiSemanticInventorySymbol;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lOwnMemberKeys: TDictionary<string, Byte>;
  lOwnerKey: string;
  lPair: TPair<string, TList<TDelphiSemanticInventorySymbol>>;
  lSourceOwnerType: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeSymbol: TDelphiSemanticInventorySymbol;
begin
  repeat
    lAdded := False;
    lBeforeCount := aSymbols.Count;
    lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    lOwnMemberKeys := BuildInventoryOwnMemberKeys(aSymbols, lBeforeCount);
    try
      for i := 0 to lBeforeCount - 1 do
      begin
        lMember := aSymbols[i];
        if (lMember.RoutineName <> '') or (not InventoryIsDirectMemberKind(lMember.SymbolClass)) then
          Continue;
        lOwnerKey := lMember.OwnerType;
        if not lMembersByOwner.TryGetValue(lOwnerKey, lMembers) then
        begin
          lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
          lMembersByOwner.Add(lOwnerKey, lMembers);
        end;
        lMembers.Add(lMember);
      end;

      for i := 0 to lBeforeCount - 1 do
      begin
        lTypeSymbol := aSymbols[i];
        if (not SameText(lTypeSymbol.SymbolClass, 'type-member')) or
          (lTypeSymbol.RelatedTypeName = '') or (lTypeSymbol.UnsupportedReason <> '') then
          Continue;

        if lTypeSymbol.IsHelper then
        begin
          if not lMembersByOwner.TryGetValue(lTypeSymbol.Name, lMembers) then
            Continue;
        end else
        begin
          if not lMembersByOwner.TryGetValue(lTypeSymbol.RelatedTypeName, lMembers) then
            Continue;
        end;

        for lMember in lMembers do
        begin
          lSymbol := lMember;
          if lTypeSymbol.IsHelper then
          begin
            lSymbol.OwnerName := lTypeSymbol.RelatedTypeName;
            lSymbol.OwnerType := lTypeSymbol.RelatedTypeName;
            lSymbol.SourceOwnerType := lTypeSymbol.Name;
          end else
          begin
            lSymbol.OwnerName := lTypeSymbol.Name;
            lSymbol.OwnerType := lTypeSymbol.Name;
            lSourceOwnerType := lMember.SourceOwnerType;
            if lSourceOwnerType = '' then
              lSourceOwnerType := lMember.OwnerType;
            lSymbol.SourceOwnerType := lSourceOwnerType;
          end;

          if lOwnMemberKeys.ContainsKey(InventoryOwnMemberKey(lSymbol.OwnerType, lSymbol.Name)) then
            Continue;
          lAdded := AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol) or lAdded;
        end;
      end;
    finally
      for lPair in lMembersByOwner do
        lPair.Value.Free;
      lOwnMemberKeys.Free;
      lMembersByOwner.Free;
    end;
  until not lAdded;
end;

procedure AddRelatedInventoryCurrentClassSymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aKeys: TDictionary<string, Byte>);
var
  i: Integer;
  lCurrentMember: TDelphiSemanticInventorySymbol;
  lMember: TDelphiSemanticInventorySymbol;
  lMembers: TList<TDelphiSemanticInventorySymbol>;
  lMembersByOwner: TDictionary<string, TList<TDelphiSemanticInventorySymbol>>;
  lOwnerKey: string;
  lPair: TPair<string, TList<TDelphiSemanticInventorySymbol>>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolCount: Integer;
begin
  lSymbolCount := aSymbols.Count;
  lMembersByOwner := TDictionary<string, TList<TDelphiSemanticInventorySymbol>>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for i := 0 to lSymbolCount - 1 do
    begin
      lMember := aSymbols[i];
      if (lMember.OwnerType = '') or (lMember.RoutineName <> '') or
        (not InventoryIsDirectMemberKind(lMember.SymbolClass)) then
        Continue;
      lOwnerKey := lMember.OwnerType;
      if not lMembersByOwner.TryGetValue(lOwnerKey, lMembers) then
      begin
        lMembers := TList<TDelphiSemanticInventorySymbol>.Create;
        lMembersByOwner.Add(lOwnerKey, lMembers);
      end;
      lMembers.Add(lMember);
    end;

    for i := 0 to lSymbolCount - 1 do
    begin
      lCurrentMember := aSymbols[i];
      if (not SameText(lCurrentMember.SymbolClass, 'current-class-member')) or
        (lCurrentMember.OwnerType = '') or (lCurrentMember.RoutineName = '') then
        Continue;
      if not lMembersByOwner.TryGetValue(lCurrentMember.OwnerType, lMembers) then
        Continue;

      for lMember in lMembers do
      begin
        lSymbol := lMember;
        lSymbol.SymbolClass := 'current-class-member';
        lSymbol.Kind := 'current-class-member';
        lSymbol.RoutineName := lCurrentMember.RoutineName;
        AddExpandedInventorySymbolWithKeys(aSymbols, aKeys, lSymbol);
      end;
    end;
  finally
    for lPair in lMembersByOwner do
      lPair.Value.Free;
    lMembersByOwner.Free;
  end;
end;

function BindReference(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
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
  lContext.IndexedUnitModels := aProjectModels;

  if TryExtractCallName(aName, lCallName) then
  begin
    if TryResolveReceiverMember(aModel, aProjectModels, aSelectors, lCallName, lResult) then
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

  if TryResolveReceiverMember(aModel, aProjectModels, aSelectors, aName, lResult) then
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

procedure ApplyBindingReferenceIds(var aBinding: TDelphiSemanticWithBinding);
var
  i: Integer;
begin
  for i := 0 to High(aBinding.References) do
    aBinding.References[i].SemanticId := ReferenceSemanticId(aBinding.SemanticId,
      aBinding.References[i]);
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

function BindSelectors(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName,
  aSelectorText: string; const aParentRoutineNames: TArray<string>):
  TArray<TDelphiSemanticWithSelectorBinding>;
var
  lPart: string;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
begin
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  try
    for lPart in SplitSelectors(aSelectorText) do
      lSelectors.Add(MakeSelectorBinding(aModel, aProjectModels, aRoutineName, lPart,
        aParentRoutineNames, lSelectors.ToArray));
    Result := lSelectors.ToArray;
  finally
    lSelectors.Free;
  end;
end;

procedure AddArgumentReferences(const aReferences: TList<TDelphiSemanticBoundReference>;
  const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>; const aRoutineName: string;
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
      lReference := BindReference(aModel, aProjectModels, aRoutineName, aParentRoutineNames,
        aSelectors, lArgumentMatch.Value);
      lArgumentStartOffset := aTokenStartOffset + lParenPos + lArgumentMatch.Index - 1;
      ApplyBodyRange(lReference, aStatement, lArgumentStartOffset, Length(lArgumentMatch.Value));
      AddReference(aReferences, lReference);
    end;
    lArgumentMatch := lArgumentMatch.NextMatch;
  end;
end;

function BindReferences(const aModel: TDelphiSemanticUnitModel;
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
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
        lReference := BindReference(aModel, aProjectModels, aRoutineName, aParentRoutineNames,
          aSelectors, lMatch.Value);
        ApplyBodyRange(lReference, aStatement, lMatch.Index, Length(lMatch.Value));
        AddReference(lReferences, lReference);
        AddArgumentReferences(lReferences, aModel, aProjectModels, aRoutineName,
          aParentRoutineNames,
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
  const aProjectModels: TArray<TDelphiSemanticUnitModel>;
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
        for lSelector in BindSelectors(aModel, aProjectModels, aRoutineName,
          aStatements[i].SelectorText, aParentRoutineNames) do
          lSelectors.Add(lSelector);
    for lSelector in BindSelectors(aModel, aProjectModels, aRoutineName,
      aStatements[aStatementIndex].SelectorText, aParentRoutineNames) do
      lSelectors.Add(lSelector);
    Result := lSelectors.ToArray;
  finally
    lSelectors.Free;
  end;
end;

class function TDelphiSemanticWithBinder.BindModel(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticWithBinding>;
begin
  Result := BindProject('', nil, [aModel]).Bindings;
end;

function BuildInventorySymbols(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticInventorySymbol>; forward;

procedure AddProjectCompatibilitySymbol(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aSymbolClass, aKind, aTypeName, aOwnerType, aSourceKind: string;
  const aTypeCategory: string = '');
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSymbol := Default(TDelphiSemanticInventorySymbol);
  lSymbol.Name := aName;
  lSymbol.SymbolClass := aSymbolClass;
  lSymbol.Kind := aKind;
  lSymbol.TypeName := aTypeName;
  lSymbol.OwnerName := aOwnerType;
  lSymbol.OwnerType := aOwnerType;
  lSymbol.SourceOwnerType := aSourceKind;
  lSymbol.UnitName := aSourceKind;
  lSymbol.TypeCategory := aTypeCategory;
  AddInventorySymbol(aSymbols, lSymbol);
end;

procedure AddProjectCompatibilityRoutine(const aSymbols: TList<TDelphiSemanticInventorySymbol>;
  const aName, aTypeName, aSourceKind: string);
begin
  AddProjectCompatibilitySymbol(aSymbols, aName, 'routine', 'routine', aTypeName, '',
    aSourceKind);
end;

procedure AddProjectCompatibilitySymbols(const aSymbols: TList<TDelphiSemanticInventorySymbol>);
const
  cCompilerIntrinsicRoutines: array [0..46] of string = ('Abs', 'Addr', 'Assert',
    'Assign', 'Assigned', 'BlockRead', 'BlockWrite', 'Close', 'Copy', 'Dec', 'Delete',
    'Dispose', 'EOF', 'Exclude', 'FilePos', 'FillChar', 'Flush', 'FreeMem',
    'GetMem', 'Halt', 'High', 'Inc', 'Include', 'Length', 'Low', 'Move', 'New',
    'Ord', 'Pred', 'Read', 'Readln', 'ReallocMem', 'Reset',
    'Rewrite', 'Round', 'Seek', 'SetLength', 'SizeOf', 'Sqr', 'Str', 'Succ',
    'Swap', 'UpCase', 'Val', 'Write', 'Writeln', 'IOResult');
  cRtlSourceRoutines: array [0..7] of string = ('ExpandFileName',
    'FileDateToDateTime', 'IntToStr', 'Max', 'Min', 'Pop', 'Push', 'Random');
var
  lName: string;
begin
  AddProjectCompatibilitySymbol(aSymbols, 'TFileName', 'type-member', 'type-member',
    'string', '', 'rtl-source');
  AddProjectCompatibilitySymbol(aSymbols, 'TSearchRec', 'type-member', 'type-member',
    'record', '', 'rtl-source', 'record');
  AddProjectCompatibilitySymbol(aSymbols, 'Exception', 'type-member', 'type-member',
    'class', '', 'rtl-source', 'class');
  AddProjectCompatibilitySymbol(aSymbols, 'Name', 'field', 'field', 'TFileName',
    'TSearchRec', 'rtl-source');
  AddProjectCompatibilitySymbol(aSymbols, 'Size', 'field', 'field', 'Int64',
    'TSearchRec', 'rtl-source');
  AddProjectCompatibilitySymbol(aSymbols, 'Attr', 'field', 'field', 'Integer',
    'TSearchRec', 'rtl-source');
  AddProjectCompatibilitySymbol(aSymbols, 'Time', 'field', 'field', 'Integer',
    'TSearchRec', 'rtl-source');
  AddProjectCompatibilitySymbol(aSymbols, 'Message', 'property', 'property', 'string',
    'Exception', 'rtl-source');
  for lName in cCompilerIntrinsicRoutines do
    AddProjectCompatibilityRoutine(aSymbols, lName, '', 'compiler-intrinsic');
  for lName in cRtlSourceRoutines do
    AddProjectCompatibilityRoutine(aSymbols, lName, '', 'rtl-source');
end;

class function TDelphiSemanticWithBinder.BindProject(const aContextFingerprint: string;
  const aGraph: TDelphiSemanticSemanticGraph;
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticProjectWithBindingFacts;
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TList<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lParentRoutineNames: TArray<string>;
  lRoutineName: string;
  lScopeIndex: TDelphiSemanticRoutineScopeIndex;
  lStatement: TDelphiSemanticWithStatement;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  Result := Default(TDelphiSemanticProjectWithBindingFacts);
  Result.ContextFingerprint := aContextFingerprint;
  lBindings := TList<TDelphiSemanticWithBinding>.Create;
  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  try
    for lModel in aModels do
    begin
      for lSymbol in BuildInventorySymbols(lModel) do
        lSymbols.Add(lSymbol);
      lScopeIndex := TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel);
      for i := 0 to High(lModel.WithStatements) do
      begin
        lStatement := lModel.WithStatements[i];
        lBinding := Default(TDelphiSemanticWithBinding);
        lBinding.SemanticId := BindingSemanticId(lModel, lStatement);
        lBinding.Provenance := 'with-binding:model';
        lBinding.FileName := lModel.FileName;
        lBinding.UnitName := lModel.UnitName;
        lBinding.Line := lStatement.Line;
        lBinding.Column := lStatement.Column;
        lBinding.EndLine := lStatement.EndLine;
        lBinding.EndColumn := lStatement.EndColumn;
        lBinding.BodyLine := lStatement.BodyLine;
        lBinding.BodyColumn := lStatement.BodyColumn;
        lBinding.BodyEndLine := lStatement.BodyEndLine;
        lBinding.BodyEndColumn := lStatement.BodyEndColumn;
        lBinding.SelectorText := lStatement.SelectorText;
        lBinding.SemanticId := GraphWithStatementIdForBinding(aGraph, lBinding);
        if aGraph <> nil then
          lBinding.Provenance := 'with-binding:project-session';
        lRoutineName := lScopeIndex.RoutineNameForLine(lStatement.Line);
        lBinding.RoutineName := lRoutineName;
        lParentRoutineNames := lScopeIndex.ParentRoutineNamesForLine(lRoutineName,
          lStatement.Line);
        lBinding.Selectors := CombinedSelectors(lModel, aModels, lModel.WithStatements, i,
          lRoutineName, lParentRoutineNames);
        lBinding.References := BindReferences(lModel, aModels, lStatement,
          lModel.WithStatements, i, lRoutineName, lParentRoutineNames, lBinding.Selectors);
        ApplyBindingReferenceIds(lBinding);
        FinalizeBinding(lBinding, lStatement);
        lBindings.Add(lBinding);
      end;
    end;
    AddProjectCompatibilitySymbols(lSymbols);
    Result.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols.ToArray);
    Result.Bindings := lBindings.ToArray;
    Result.Metrics.SemanticGraphUsed := aGraph <> nil;
    Result.Metrics.BuildUnitIndexUsed := False;
    Result.Metrics.UnitCount := Length(aModels);
    if aGraph <> nil then
    begin
      Result.Metrics.UnitCount := aGraph.Metrics.UnitCount;
      Result.Metrics.WithStatementCount := aGraph.Metrics.WithStatementCount;
      Result.Metrics.SemanticGraphBuildMilliseconds := aGraph.Metrics.BuildMilliseconds;
    end else
      Result.Metrics.WithStatementCount := Length(Result.Bindings);
    Result.Metrics.BindingCount := Length(Result.Bindings);
  finally
    lSymbols.Free;
    lBindings.Free;
  end;
end;

class function TDelphiSemanticWithBinder.ExpandInventorySymbols(
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>): TArray<TDelphiSemanticInventorySymbol>;
var
  lKeys: TDictionary<string, Byte>;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
  lKeys := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSymbols := TList<TDelphiSemanticInventorySymbol>.Create;
  try
    for lSymbol in aSymbols do
      AddExpandedInventorySymbolWithKeys(lSymbols, lKeys, lSymbol);
    AddRelatedInventoryMemberSymbols(lSymbols, lKeys);
    AddRelatedInventoryCurrentClassSymbols(lSymbols, lKeys);
    Result := lSymbols.ToArray;
  finally
    lSymbols.Free;
    lKeys.Free;
  end;
end;

function BuildInventorySymbols(const aModel: TDelphiSemanticUnitModel):
  TArray<TDelphiSemanticInventorySymbol>;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TList<TDelphiSemanticInventorySymbol>;
begin
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
      lSymbol.OwnerType := aModel.UnitName;
      lSymbol.RelatedTypeName := lDeclaration.BaseTypeName;
      if SameText(lDeclaration.Kind, 'type-alias') then
        lSymbol.RelatedTypeName := lDeclaration.TypeName;
      lSymbol.IsHelper := lDeclaration.HelperTargetName <> '';
      if lSymbol.IsHelper then
        lSymbol.RelatedTypeName := lDeclaration.HelperTargetName;
      if SameText(lDeclaration.TypeName, 'record') or SameText(lDeclaration.TypeName, 'class') or
        SameText(lDeclaration.TypeName, 'interface') then
        lSymbol.TypeCategory := lDeclaration.TypeName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lDeclaration.SectionKind;
      lSymbol.Line := lDeclaration.Line;
      lSymbol.Column := lDeclaration.Column;
      lSymbol.EndLine := lDeclaration.Line;
      lSymbol.EndColumn := lDeclaration.Column;
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
      lSymbol.OwnerType := lMember.OwnerName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.Line := lMember.Line;
      lSymbol.Column := lMember.Column;
      lSymbol.EndLine := lMember.Line;
      lSymbol.EndColumn := lMember.Column;
      lSymbol.IsDefault := lMember.IsDefault;
      lSymbol.IsIndexed := lMember.IsIndexed;
      if lMember.IsIndexed then
        lSymbol.IndexParameterCount := 1;
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
      lSymbol.OwnerType := lRoutine.OwnerName;
      lSymbol.UnitName := aModel.UnitName;
      lSymbol.FileName := aModel.FileName;
      lSymbol.SectionKind := lRoutine.SectionKind;
      lSymbol.Line := lRoutine.Line;
      lSymbol.Column := lRoutine.Column;
      lSymbol.EndLine := lRoutine.Line;
      lSymbol.EndColumn := lRoutine.Column;
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
        lSymbol.Line := lParameter.Line;
        lSymbol.Column := lParameter.Column;
        lSymbol.EndLine := lParameter.Line;
        lSymbol.EndColumn := lParameter.Column;
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
      lSymbol.EndLine := lLocal.Line;
      lSymbol.EndColumn := lLocal.Column;
      AddInventorySymbol(lSymbols, lSymbol);
    end;

    AddDakCompatibleInventorySymbols(aModel, lSymbols);
    Result := lSymbols.ToArray;
  finally
    lSymbols.Free;
  end;
end;

class function TDelphiSemanticWithBinder.BuildInventory(
  const aModel: TDelphiSemanticUnitModel): TDelphiSemanticRemoveWithInventory;
begin
  Result := Default(TDelphiSemanticRemoveWithInventory);
  Result.FileName := aModel.FileName;
  Result.UnitName := aModel.UnitName;
  Result.Symbols := BuildInventorySymbols(aModel);

  Result.Bindings := BindModel(aModel);
end;

end.
