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
    ReceiverTypeName: string;
    Kind: string;
    TypeName: string;
    ReasonCode: string;
  end;

  TDelphiSemanticWithBinding = record
    Line: Integer;
    Column: Integer;
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
  System.Generics.Collections, System.RegularExpressions, System.StrUtils, System.SysUtils;

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

function MakeSelectorBinding(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
  aSelectorText: string): TDelphiSemanticWithSelectorBinding;
var
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
begin
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lResult := TDelphiSemanticResolver.ResolveName(aModel, lContext, aSelectorText.Trim);
  Result.SelectorText := aSelectorText.Trim;
  Result.Status := lResult.Status;
  Result.ReasonCode := lResult.ReasonCode;
  Result.TypeName := lResult.TypeName;
end;

function MakeBoundReference(const aName, aClassification: string;
  const aResult: TDelphiSemanticResolveResult): TDelphiSemanticBoundReference;
begin
  Result.Name := aName;
  Result.Classification := aClassification;
  Result.ReceiverTypeName := aResult.OwnerName;
  Result.Kind := aResult.Kind;
  Result.TypeName := aResult.TypeName;
  Result.ReasonCode := aResult.ReasonCode;
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
  const aRoutineName: string; const aSelectors: TArray<TDelphiSemanticWithSelectorBinding>;
  const aName: string):
  TDelphiSemanticBoundReference;
var
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
begin
  if (Pos('.', aName) > 0) or (Pos('[', aName) > 0) or (Pos('(', aName) > 0) then
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

  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := aRoutineName;
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lResult := TDelphiSemanticResolver.ResolveName(aModel, lContext, aName);
  if lResult.Found then
    Exit(MakeBoundReference(aName, 'lexical', lResult));

  if AnySelectorUnresolved(aSelectors) then
    Exit(MakeBoundReference(aName, 'external', lResult));

  Result := MakeBoundReference(aName, 'unresolved', lResult);
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
  aSelectorText: string): TArray<TDelphiSemanticWithSelectorBinding>;
var
  lPart: string;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
begin
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  try
    for lPart in SplitSelectors(aSelectorText) do
      lSelectors.Add(MakeSelectorBinding(aModel, aRoutineName, lPart));
    Result := lSelectors.ToArray;
  finally
    lSelectors.Free;
  end;
end;

function BindReferences(const aModel: TDelphiSemanticUnitModel;
  const aStatement: TDelphiSemanticWithStatement;
  const aAllStatements: TArray<TDelphiSemanticWithStatement>;
  const aStatementIndex: Integer;
  const aRoutineName: string;
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
        AddReference(lReferences, BindReference(aModel, aRoutineName, aSelectors, lMatch.Value));
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
  const aRoutineName: string): TArray<TDelphiSemanticWithSelectorBinding>;
var
  i: Integer;
  lSelector: TDelphiSemanticWithSelectorBinding;
  lSelectors: TList<TDelphiSemanticWithSelectorBinding>;
begin
  lSelectors := TList<TDelphiSemanticWithSelectorBinding>.Create;
  try
    for i := 0 to Pred(aStatementIndex) do
      if StatementContains(aStatements[i], aStatements[aStatementIndex]) then
        for lSelector in BindSelectors(aModel, aRoutineName, aStatements[i].SelectorText) do
          lSelectors.Add(lSelector);
    for lSelector in BindSelectors(aModel, aRoutineName, aStatements[aStatementIndex].SelectorText) do
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
      lRoutineName := FindRoutineNameForLine(aModel, lStatement.Line);
      lBinding.Selectors := CombinedSelectors(aModel, aModel.WithStatements, i, lRoutineName);
      lBinding.References := BindReferences(aModel, lStatement, aModel.WithStatements, i,
        lRoutineName, lBinding.Selectors);
      lBindings.Add(lBinding);
    end;
    Result := lBindings.ToArray;
  finally
    lBindings.Free;
  end;
end;

end.
