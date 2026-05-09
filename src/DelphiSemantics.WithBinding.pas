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
  end;

  TDelphiSemanticWithBinding = record
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

  TDelphiSemanticWithBinder = record
  public
    class function BindModel(const aModel: TDelphiSemanticUnitModel):
      TArray<TDelphiSemanticWithBinding>; static;
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
var
  lText: string;
begin
  lText := TRegEx.Replace(aText, '''(?:''''|[^''])*''', ' ', [roSingleLine]);
  lText := TRegEx.Replace(lText, '\(\*.*?\*\)', ' ', [roSingleLine]);
  lText := TRegEx.Replace(lText, '\{.*?\}', ' ', [roSingleLine]);
  Result := TRegEx.Replace(lText, '//[^\r\n]*', ' ', [roMultiLine]);
end;

function ExtractWithBodyText(const aStatement: TDelphiSemanticWithStatement;
  const aAllStatements: TArray<TDelphiSemanticWithStatement>; const aStatementIndex: Integer):
  string;
var
  i: Integer;
  lMatch: TMatch;
begin
  lMatch := TRegEx.Match(aStatement.Text, '\bdo\b(.*)$', [roIgnoreCase, roSingleLine]);
  if lMatch.Success then
    Result := lMatch.Groups[1].Value
  else
    Result := aStatement.Text;
  for i := Succ(aStatementIndex) to High(aAllStatements) do
    if Pos(aAllStatements[i].Text, Result) > 0 then
      Result := StringReplace(Result, aAllStatements[i].Text, ' ', []);
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
  const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>; const aToken: string);
var
  lArgumentMatch: TMatch;
  lArguments: string;
begin
  if not TryExtractCallArguments(aToken, lArguments) then
    Exit;

  lArguments := SanitizeBodyText(lArguments);
  lArgumentMatch := TRegEx.Match(lArguments,
    '\b[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)?(?:\[[^\]]+\])?',
    [roIgnoreCase]);
  while lArgumentMatch.Success do
  begin
    if not IsBinderKeyword(lArgumentMatch.Value) and
      not IsSelectorName(aSelectors, lArgumentMatch.Value) then
      AddReference(aReferences, BindReference(aModel, aRoutineName, aParentRoutineNames,
        aSelectors, lArgumentMatch.Value));
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
        AddReference(lReferences, BindReference(aModel, aRoutineName, aParentRoutineNames,
          aSelectors, lMatch.Value));
        AddArgumentReferences(lReferences, aModel, aRoutineName, aParentRoutineNames,
          aSelectors, lMatch.Value);
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

end.
