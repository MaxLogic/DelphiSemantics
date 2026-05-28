unit DelphiSemantics.ProjectContext;

interface

type
  TDelphiSemanticDiagnosticSeverity = (dsInfo, dsWarning, dsError);

  TDelphiSemanticProperty = record
    Name: string;
    Value: string;
  end;

  TDelphiSemanticOptions = record
    ProjectPath: string;
    Configuration: string;
    Platform: string;
    DelphiVersion: string;
    RsVarsPath: string;
    EnvOptionsPath: string;
    EnvironmentVariables: TArray<TDelphiSemanticProperty>;
    AdditionalSourceFileNames: TArray<string>;
    SqliteCacheFileName: string;
    UseLspEnrichment: Boolean;
  end;

  TDelphiSemanticDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
    Severity: TDelphiSemanticDiagnosticSeverity;
  end;

  TDelphiSemanticProjectInfo = record
    ProjectFileName: string;
    ProjectDirectory: string;
    ProjectName: string;
    Configuration: string;
    Platform: string;
    MainSourceFileName: string;
    SourceFileNames: TArray<string>;
    Defines: TArray<string>;
    IncludePaths: TArray<string>;
    SearchPaths: TArray<string>;
    UnitScopeNames: TArray<string>;
    UnitAliases: TArray<string>;
    ReferenceDirectories: TArray<string>;
    Properties: TArray<TDelphiSemanticProperty>;
    CompilerProfileName: string;
    ContextFingerprint: string;
    function PropertyValue(const aName: string): string;
    function SourceLookupPaths: TArray<string>;
  end;

  TDelphiSemanticContextResult = record
    Success: Boolean;
    Project: TDelphiSemanticProjectInfo;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
  end;

  TDelphiSemanticProject = record
  public
    class function Load(const aFileName: string): TDelphiSemanticContextResult; overload; static;
    class function Load(const aFileName: string; const aOptions: TDelphiSemanticOptions): TDelphiSemanticContextResult; overload; static;
  end;

  TDelphiSemanticMsBuild = record
  public
    class function ExpandMacros(const aValue: string; const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>;
      const aUnknownAsEmpty: Boolean; out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): string; static;
    class function TryEvaluateCondition(const aCondition, aBaseDirectory: string;
      const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>; out aResult: Boolean; out aError: string;
      out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): Boolean; static;
  end;

implementation

uses
  System.Generics.Collections,
  System.Hash,
  System.IOUtils,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils;

type
  TPropertyMap = TDictionary<string, string>;

function TDelphiSemanticProjectInfo.PropertyValue(const aName: string): string;
var
  lProperty: TDelphiSemanticProperty;
begin
  for lProperty in Properties do
    if SameText(lProperty.Name, aName) then
      Exit(lProperty.Value);

  Result := '';
end;

function DecodeXmlText(const aValue: string): string;
begin
  Result := aValue.Trim;
  Result := Result.Replace('&lt;', '<');
  Result := Result.Replace('&gt;', '>');
  Result := Result.Replace('&quot;', '"');
  Result := Result.Replace('&apos;', '''');
  Result := Result.Replace('&amp;', '&');
end;

function CreateDiagnostic(const aCode, aMessage, aFileName: string;
  const aSeverity: TDelphiSemanticDiagnosticSeverity): TDelphiSemanticDiagnostic;
begin
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Line := 0;
  Result.Column := 0;
  Result.Severity := aSeverity;
end;

function CreateErrorDiagnostic(const aCode, aMessage, aFileName: string): TDelphiSemanticDiagnostic;
begin
  Result := CreateDiagnostic(aCode, aMessage, aFileName, dsError);
end;

function CreateWarningDiagnostic(const aCode, aMessage, aFileName: string): TDelphiSemanticDiagnostic;
begin
  Result := CreateDiagnostic(aCode, aMessage, aFileName, dsWarning);
end;

function FailureResult(const aDiagnostic: TDelphiSemanticDiagnostic): TDelphiSemanticContextResult;
begin
  Result.Success := False;
  SetLength(Result.Diagnostics, 1);
  Result.Diagnostics[0] := aDiagnostic;
end;

function SuccessResult(const aProject: TDelphiSemanticProjectInfo;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): TDelphiSemanticContextResult;
begin
  Result.Success := True;
  Result.Project := aProject;
  Result.Diagnostics := aDiagnostics.ToArray;
end;

function PropertyKey(const aName: string): string;
begin
  Result := UpperCase(aName);
end;

function PropertyArrayToMap(const aProperties: TArray<TDelphiSemanticProperty>): TPropertyMap;
var
  lProperty: TDelphiSemanticProperty;
begin
  Result := TPropertyMap.Create;
  for lProperty in aProperties do
    Result.AddOrSetValue(PropertyKey(lProperty.Name), lProperty.Value);
end;

function TryGetPropertyValue(const aProperties: TPropertyMap; const aName: string;
  out aValue: string): Boolean;
begin
  Result := aProperties.TryGetValue(PropertyKey(aName), aValue);
  if not Result then
    aValue := '';
end;

function TryGetMacroValue(const aProperties, aEnvironment: TPropertyMap; const aName: string;
  out aValue: string): Boolean;
begin
  if (aProperties <> nil) and aProperties.TryGetValue(PropertyKey(aName), aValue) then
    Exit(True);
  if (aEnvironment <> nil) and aEnvironment.TryGetValue(PropertyKey(aName), aValue) then
    Exit(True);

  aValue := System.SysUtils.GetEnvironmentVariable(aName);
  Result := aValue <> '';
end;

function MacroStackContains(const aStack: TList<string>; const aName: string): Boolean;
var
  lItem: string;
begin
  for lItem in aStack do
    if SameText(lItem, aName) then
      Exit(True);

  Result := False;
end;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aDiagnostic: TDelphiSemanticDiagnostic); forward;
function TryEvaluateConditionExpression(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean): Boolean; forward;

function ExpandMacroText(const aValue: string; const aProperties, aEnvironment: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>; const aUnknownAsEmpty: Boolean;
  const aStack: TList<string>): string;
var
  lIndex: Integer;
  lMacroStart: Integer;
  lMacroValue: string;
  lName: string;
  lReplacement: string;
  lResult: TStringBuilder;
begin
  lResult := TStringBuilder.Create;
  try
    lIndex := 1;
    while lIndex <= Length(aValue) do
    begin
      if (aValue[lIndex] = '$') and (lIndex < Length(aValue)) and (aValue[lIndex + 1] = '(') then
      begin
        lMacroStart := lIndex + 2;
        Inc(lIndex, 2);
        while (lIndex <= Length(aValue)) and (aValue[lIndex] <> ')') do
          Inc(lIndex);

        if lIndex > Length(aValue) then
        begin
          lResult.Append('$(');
          lResult.Append(Copy(aValue, lMacroStart, MaxInt));
          Break;
        end;

        lName := Copy(aValue, lMacroStart, lIndex - lMacroStart);
        if MacroStackContains(aStack, lName) then
        begin
          if (aDiagnostics <> nil) and (not aUnknownAsEmpty) then
            AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('CYCLE_MSBUILD_MACRO',
              'Cycle in MSBuild macro: $(' + lName + ')', ''));
          if aUnknownAsEmpty then
            lReplacement := ''
          else
            lReplacement := '$(' + lName + ')';
        end else if TryGetMacroValue(aProperties, aEnvironment, lName, lMacroValue) then
        begin
          aStack.Add(lName);
          try
            lReplacement := ExpandMacroText(lMacroValue, aProperties, aEnvironment, aDiagnostics,
              aUnknownAsEmpty, aStack);
          finally
            aStack.Delete(aStack.Count - 1);
          end;
        end else
        begin
          if (aDiagnostics <> nil) and (not aUnknownAsEmpty) then
            AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('UNRESOLVED_MSBUILD_MACRO',
              'Unresolved MSBuild macro: $(' + lName + ')', ''));
          if aUnknownAsEmpty then
            lReplacement := ''
          else
            lReplacement := '$(' + lName + ')';
        end;

        lResult.Append(lReplacement);
        Inc(lIndex);
      end else
      begin
        lResult.Append(aValue[lIndex]);
        Inc(lIndex);
      end;
    end;

    Result := lResult.ToString;
  finally
    lResult.Free;
  end;
end;

class function TDelphiSemanticMsBuild.ExpandMacros(const aValue: string;
  const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>; const aUnknownAsEmpty: Boolean;
  out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): string;
var
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lEnvironment: TPropertyMap;
  lProperties: TPropertyMap;
  lStack: TList<string>;
begin
  lProperties := PropertyArrayToMap(aProperties);
  try
    lEnvironment := PropertyArrayToMap(aEnvironment);
    try
      lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
      try
        lStack := TList<string>.Create;
        try
          Result := ExpandMacroText(aValue, lProperties, lEnvironment, lDiagnostics,
            aUnknownAsEmpty, lStack);
          aDiagnostics := lDiagnostics.ToArray;
        finally
          lStack.Free;
        end;
      finally
        lDiagnostics.Free;
      end;
    finally
      lEnvironment.Free;
    end;
  finally
    lProperties.Free;
  end;
end;

class function TDelphiSemanticMsBuild.TryEvaluateCondition(const aCondition, aBaseDirectory: string;
  const aProperties, aEnvironment: TArray<TDelphiSemanticProperty>; out aResult: Boolean;
  out aError: string; out aDiagnostics: TArray<TDelphiSemanticDiagnostic>): Boolean;
var
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lEnvironment: TPropertyMap;
  lExpandedCondition: string;
  lProperties: TPropertyMap;
  lStack: TList<string>;
begin
  aResult := True;
  aError := '';
  lProperties := PropertyArrayToMap(aProperties);
  try
    lEnvironment := PropertyArrayToMap(aEnvironment);
    try
      lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
      try
        lStack := TList<string>.Create;
        try
          lExpandedCondition := ExpandMacroText(aCondition, lProperties, lEnvironment,
            lDiagnostics, True, lStack);
        finally
          lStack.Free;
        end;

        if lExpandedCondition.Trim = '' then
        begin
          aDiagnostics := lDiagnostics.ToArray;
          Exit(True);
        end;

        Result := TryEvaluateConditionExpression(lExpandedCondition, '', aBaseDirectory,
          lProperties, lDiagnostics, aResult);
        if not Result then
          aError := 'Unsupported or invalid Condition: ' + aCondition;
        aDiagnostics := lDiagnostics.ToArray;
      finally
        lDiagnostics.Free;
      end;
    finally
      lEnvironment.Free;
    end;
  finally
    lProperties.Free;
  end;
end;

function GetPropertyValue(const aProperties: TPropertyMap; const aName: string): string;
begin
  TryGetPropertyValue(aProperties, aName, Result);
end;

procedure SetPropertyValue(const aProperties: TPropertyMap; const aName, aValue: string);
var
  lKey: string;
  lValue: string;
begin
  lKey := PropertyKey(aName);
  lValue := aValue;
  if lValue.Trim = '''''' then
    lValue := '';

  if aProperties.ContainsKey(lKey) then
    aProperties[lKey] := lValue
  else
    aProperties.Add(lKey, lValue);
end;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aDiagnostic: TDelphiSemanticDiagnostic);
begin
  aDiagnostics.Add(aDiagnostic);
end;

function ExtractXmlElementText(const aText, aElementName: string): string;
var
  lMatch: TMatch;
  lPattern: string;
begin
  lPattern := Format('<%s(?:\s+[^>]*)?>(.*?)</%s>', [aElementName, aElementName]);
  lMatch := TRegEx.Match(aText, lPattern, [roIgnoreCase, roSingleLine]);
  if lMatch.Success then
    Result := DecodeXmlText(lMatch.Groups[1].Value)
  else
    Result := '';
end;

function ExtractAttributeValue(const aAttributes, aAttributeName: string): string;
var
  lMatch: TMatch;
  lPattern: string;
begin
  lPattern := Format('%s\s*=\s*"(.*?)"', [aAttributeName]);
  lMatch := TRegEx.Match(aAttributes, lPattern, [roIgnoreCase, roSingleLine]);
  if lMatch.Success then
    Result := DecodeXmlText(lMatch.Groups[1].Value)
  else
    Result := '';
end;

function NormalizeProjectPath(const aBaseDirectory, aFileName: string): string;
begin
  if TPath.IsPathRooted(aFileName) then
    Result := TPath.GetFullPath(aFileName)
  else
    Result := TPath.GetFullPath(TPath.Combine(aBaseDirectory, aFileName));
end;

function StripOuterParentheses(const aValue: string): string; forward;
function ExpandProperties(const aValue, aFileName: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): string; forward;

function IsQuotedConditionValue(const aValue: string): Boolean;
var
  lText: string;
begin
  lText := aValue.Trim;
  Result := (Length(lText) >= 2) and (lText[1] = '''') and (lText[Length(lText)] = '''');
end;

function TryGetConditionOperand(const aValue, aFileName: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>; out aOperand: string): Boolean;
var
  lText: string;
begin
  lText := StripOuterParentheses(aValue);
  if lText = '' then
  begin
    aOperand := '';
    Exit(True);
  end;

  if (lText[1] = '''') or (lText[Length(lText)] = '''') then
  begin
    if not IsQuotedConditionValue(lText) then
      Exit(False);

    lText := Copy(lText, 2, Length(lText) - 2);
  end;

  aOperand := ExpandProperties(lText, aFileName, aProperties, aDiagnostics);
  Result := True;
end;

function TryEvaluateConditionFunction(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean): Boolean;
var
  lArgument: string;
  lFunctionName: string;
  lMatch: TMatch;
  lNegated: Boolean;
  lPath: string;
  lText: string;
begin
  lText := StripOuterParentheses(aCondition);
  lNegated := StartsText('!', lText);
  if lNegated then
    lText := Copy(lText, 2, MaxInt).Trim;

  lMatch := TRegEx.Match(lText, '^(Exists|HasTrailingSlash)\((.*)\)$',
    [roIgnoreCase, roSingleLine]);
  if not lMatch.Success then
    Exit(False);

  lFunctionName := lMatch.Groups[1].Value;
  if not TryGetConditionOperand(lMatch.Groups[2].Value, aFileName, aProperties, aDiagnostics,
    lArgument) then
    Exit(False);

  if SameText(lFunctionName, 'Exists') then
  begin
    if TPath.IsPathRooted(lArgument) then
      lPath := TPath.GetFullPath(lArgument)
    else
      lPath := NormalizeProjectPath(aBaseDirectory, lArgument);
    aActive := TFile.Exists(lPath) or TDirectory.Exists(lPath);
  end else
    aActive := EndsText('\', lArgument) or EndsText('/', lArgument);

  if lNegated then
    aActive := not aActive;

  Result := True;
end;

function TryEvaluateConditionClause(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean): Boolean;
var
  lActualValue: string;
  lExpectedValue: string;
  lMatch: TMatch;
  lOperator: string;
  lText: string;
begin
  lText := StripOuterParentheses(aCondition);

  if TryEvaluateConditionFunction(lText, aFileName, aBaseDirectory, aProperties,
    aDiagnostics, aActive) then
    Exit(True);

  lMatch := TRegEx.Match(lText, '^(.+?)\s*(==|!=)\s*(.+)$', [roIgnoreCase, roSingleLine]);
  if not lMatch.Success then
    Exit(False);

  if not TryGetConditionOperand(lMatch.Groups[1].Value, aFileName, aProperties,
    aDiagnostics, lActualValue) then
    Exit(False);
  if not TryGetConditionOperand(lMatch.Groups[3].Value, aFileName, aProperties,
    aDiagnostics, lExpectedValue) then
    Exit(False);

  lOperator := lMatch.Groups[2].Value;
  if lOperator = '==' then
    aActive := SameText(lActualValue, lExpectedValue)
  else
    aActive := not SameText(lActualValue, lExpectedValue);

  Result := True;
end;

function IsConditionOperatorBoundary(const aText: string; const aIndex: Integer): Boolean;
begin
  Result := (aIndex < 1) or (aIndex > Length(aText)) or
    not CharInSet(aText[aIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function IsConditionOperatorAt(const aText: string; const aIndex: Integer;
  const aOperator: string): Boolean;
var
  lOperatorLength: Integer;
begin
  lOperatorLength := Length(aOperator);
  if (aIndex < 1) or (aIndex + lOperatorLength - 1 > Length(aText)) then
    Exit(False);

  Result := SameText(Copy(aText, aIndex, lOperatorLength), aOperator) and
    IsConditionOperatorBoundary(aText, aIndex - 1) and
    IsConditionOperatorBoundary(aText, aIndex + lOperatorLength);
end;

function TrySplitTopLevelCondition(const aText, aOperator: string;
  out aLeft, aRight: string): Boolean;
var
  i: Integer;
  lDepth: Integer;
  lInQuote: Boolean;
begin
  lDepth := 0;
  lInQuote := False;
  i := 1;
  while i <= Length(aText) do
  begin
    if aText[i] = '''' then
      lInQuote := not lInQuote
    else if not lInQuote then
    begin
      if aText[i] = '(' then
        Inc(lDepth)
      else if aText[i] = ')' then
        Dec(lDepth)
      else if (lDepth = 0) and IsConditionOperatorAt(aText, i, aOperator) then
      begin
        aLeft := Copy(aText, 1, i - 1).Trim;
        aRight := Copy(aText, i + Length(aOperator), MaxInt).Trim;
        Exit((aLeft <> '') and (aRight <> ''));
      end;
    end;
    Inc(i);
  end;

  Result := False;
end;

function TryEvaluateConditionExpression(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  out aActive: Boolean): Boolean;
var
  lLeft: string;
  lLeftActive: Boolean;
  lRight: string;
  lRightActive: Boolean;
  lText: string;
begin
  lText := StripOuterParentheses(aCondition);

  if SameText(lText, 'true') then
  begin
    aActive := True;
    Exit(True);
  end;

  if SameText(lText, 'false') then
  begin
    aActive := False;
    Exit(True);
  end;

  if TrySplitTopLevelCondition(lText, 'or', lLeft, lRight) then
  begin
    if not TryEvaluateConditionExpression(lLeft, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lLeftActive) then
      Exit(False);

    if lLeftActive then
    begin
      aActive := True;
      Exit(True);
    end;

    if not TryEvaluateConditionExpression(lRight, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lRightActive) then
      Exit(False);

    aActive := lRightActive;
    Exit(True);
  end;

  if TrySplitTopLevelCondition(lText, 'and', lLeft, lRight) then
  begin
    if not TryEvaluateConditionExpression(lLeft, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lLeftActive) then
      Exit(False);

    if not lLeftActive then
    begin
      aActive := False;
      Exit(True);
    end;

    if not TryEvaluateConditionExpression(lRight, aFileName, aBaseDirectory, aProperties,
      aDiagnostics, lRightActive) then
      Exit(False);

    aActive := lRightActive;
    Exit(True);
  end;

  if StartsText('!', lText) and (not StartsText('!=', lText)) then
  begin
    if not TryEvaluateConditionExpression(Copy(lText, 2, MaxInt), aFileName, aBaseDirectory,
      aProperties, aDiagnostics, aActive) then
      Exit(False);
    aActive := not aActive;
    Exit(True);
  end;

  Result := TryEvaluateConditionClause(lText, aFileName, aBaseDirectory, aProperties,
    aDiagnostics, aActive);
end;

function StripOuterParentheses(const aValue: string): string;
var
  i: Integer;
  lDepth: Integer;
  lText: string;
begin
  lText := aValue.Trim;
  while (Length(lText) >= 2) and (lText[1] = '(') and (lText[Length(lText)] = ')') do
  begin
    lDepth := 0;
    for i := 1 to Length(lText) do
    begin
      if lText[i] = '(' then
        Inc(lDepth)
      else if lText[i] = ')' then
      begin
        Dec(lDepth);
        if (lDepth = 0) and (i < Length(lText)) then
        begin
          Result := lText;
          Exit;
        end;
      end;
    end;
    lText := Copy(lText, 2, Length(lText) - 2).Trim;
  end;
  Result := lText;
end;

function IsConditionActive(const aCondition, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>): Boolean;
var
  lActive: Boolean;
begin
  if aCondition.Trim = '' then
    Exit(True);

  if not TryEvaluateConditionExpression(aCondition, aFileName, aBaseDirectory, aProperties,
    aDiagnostics, lActive) then
  begin
    AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('INVALID_MSBUILD_CONDITION',
      'Unsupported or invalid Condition: ' + aCondition, aFileName));
    Exit(False);
  end;

  Result := lActive;
end;

function HasUnresolvedPropertyReference(const aValue: string; const aProperties: TPropertyMap): Boolean;
var
  lMacroName: string;
  lMacroStart: Integer;
  lMacroStop: Integer;
  lMacroValue: string;
begin
  lMacroStart := Pos('$(', aValue);
  while lMacroStart > 0 do
  begin
    lMacroStop := PosEx(')', aValue, lMacroStart + 2);
    if lMacroStop = 0 then
      Break;

    lMacroName := Copy(aValue, lMacroStart + 2, lMacroStop - lMacroStart - 2);
    if not TryGetPropertyValue(aProperties, lMacroName, lMacroValue) then
      Exit(True);

    lMacroStart := PosEx('$(', aValue, lMacroStop + 1);
  end;

  Result := False;
end;

function ExpandProperties(const aValue, aFileName: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): string;
var
  lMacroName: string;
  lMacroStart: Integer;
  lMacroStop: Integer;
  lReplacement: string;
begin
  Result := aValue;
  lMacroStart := Pos('$(', Result);
  while lMacroStart > 0 do
  begin
    lMacroStop := PosEx(')', Result, lMacroStart + 2);
    if lMacroStop = 0 then
      Break;

    lMacroName := Copy(Result, lMacroStart + 2, lMacroStop - lMacroStart - 2);
    if not TryGetPropertyValue(aProperties, lMacroName, lReplacement) then
    begin
      AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('UNRESOLVED_MSBUILD_MACRO',
        'Unresolved MSBuild macro: $(' + lMacroName + ')', aFileName));
      Delete(Result, lMacroStart, lMacroStop - lMacroStart + 1);
      lMacroStart := PosEx('$(', Result, lMacroStart);
    end else
    begin
      Delete(Result, lMacroStart, lMacroStop - lMacroStart + 1);
      Insert(lReplacement, Result, lMacroStart);
      lMacroStart := PosEx('$(', Result, lMacroStart + Length(lReplacement));
    end;
  end;
end;

procedure AddUniqueText(const aItems: TList<string>; const aValue: string);
var
  lItem: string;
  lValue: string;
begin
  lValue := aValue.Trim;
  if lValue = '' then
    Exit;

  for lItem in aItems do
    if SameText(lItem, lValue) then
      Exit;

  aItems.Add(lValue);
end;

procedure AddUniquePath(const aItems: TList<string>; const aBaseDirectory, aValue: string);
var
  lItem: string;
  lPath: string;
  lValue: string;
begin
  lValue := aValue.Trim;
  if (lValue = '') or (Pos('$(', lValue) > 0) then
    Exit;

  lPath := ExcludeTrailingPathDelimiter(NormalizeProjectPath(aBaseDirectory, lValue));
  for lItem in aItems do
    if SameText(lItem, lPath) then
      Exit;

  aItems.Add(lPath);
end;

procedure AddDelimitedTexts(const aItems: TList<string>; const aValue: string);
var
  lPart: string;
  lParts: TArray<string>;
begin
  lParts := aValue.Split([';']);
  for lPart in lParts do
    AddUniqueText(aItems, lPart);
end;

procedure AddDelimitedPaths(const aItems: TList<string>; const aBaseDirectory, aValue: string);
var
  lPart: string;
  lParts: TArray<string>;
begin
  lParts := aValue.Split([';']);
  for lPart in lParts do
    AddUniquePath(aItems, aBaseDirectory, lPart);
end;

function TDelphiSemanticProjectInfo.SourceLookupPaths: TArray<string>;
var
  lItem: string;
  lItems: TList<string>;
begin
  lItems := TList<string>.Create;
  try
    for lItem in ReferenceDirectories do
      AddUniquePath(lItems, ProjectDirectory, lItem);
    for lItem in SearchPaths do
      AddUniquePath(lItems, ProjectDirectory, lItem);
    Result := lItems.ToArray;
  finally
    lItems.Free;
  end;
end;

procedure ApplyPropertyFile(const aFileName, aBaseDirectory: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>); forward;

procedure ApplyImport(const aAttributes, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
var
  lCondition: string;
  lImportFileName: string;
  lProject: string;
begin
  lCondition := ExtractAttributeValue(aAttributes, 'Condition');
  if IsConditionActive(lCondition, aFileName, aBaseDirectory, aProperties, aDiagnostics) then
  begin
    lProject := ExtractAttributeValue(aAttributes, 'Project');
    lProject := ExpandProperties(lProject, aFileName, aProperties, aDiagnostics);
    if lProject <> '' then
    begin
      lImportFileName := NormalizeProjectPath(aBaseDirectory, lProject);
      ApplyPropertyFile(lImportFileName, ExtractFilePath(lImportFileName), aProperties,
        aDiagnostics);
    end;
  end;
end;

procedure ApplyPropertyGroup(const aAttributes, aBody, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
var
  lChild: TMatch;
  lCondition: string;
  lExpandedValue: string;
  lName: string;
  lOptsetPath: string;
  lPart: string;
  lParts: TArray<string>;
  lValue: string;
begin
  lCondition := ExtractAttributeValue(aAttributes, 'Condition');
  if IsConditionActive(lCondition, aFileName, aBaseDirectory, aProperties, aDiagnostics) then
  begin
    lChild := TRegEx.Match(aBody, '<([A-Za-z_][A-Za-z0-9_\.]*)([^>]*)>(.*?)</\1>',
      [roIgnoreCase, roSingleLine]);
    while lChild.Success do
    begin
      lName := lChild.Groups[1].Value;
      lCondition := ExtractAttributeValue(lChild.Groups[2].Value, 'Condition');
      if IsConditionActive(lCondition, aFileName, aBaseDirectory, aProperties, aDiagnostics) then
      begin
        lValue := DecodeXmlText(lChild.Groups[3].Value);
        lExpandedValue := ExpandProperties(lValue, aFileName, aProperties, aDiagnostics);
        if SameText(lName, 'CfgDependentOn') then
        begin
          lParts := lExpandedValue.Split([';']);
          for lPart in lParts do
          begin
            if lPart.Trim = '' then
              Continue;

            lOptsetPath := NormalizeProjectPath(aBaseDirectory, lPart.Trim);
            ApplyPropertyFile(lOptsetPath, ExtractFilePath(lOptsetPath), aProperties, aDiagnostics);
          end;
        end;
        SetPropertyValue(aProperties, lName, lExpandedValue);
      end;
      lChild := lChild.NextMatch;
    end;
  end;
end;

procedure ApplyPropertyText(const aText, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
var
  lNode: TMatch;
begin
  lNode := TRegEx.Match(aText,
    '<(PropertyGroup)([^>]*)>(.*?)</PropertyGroup>|<Import\b\s+([^>]*)/?\s*>',
    [roIgnoreCase, roSingleLine]);
  while lNode.Success do
  begin
    if SameText(lNode.Groups[1].Value, 'PropertyGroup') then
      ApplyPropertyGroup(lNode.Groups[2].Value, lNode.Groups[3].Value, aFileName,
        aBaseDirectory, aProperties, aDiagnostics)
    else
      ApplyImport(lNode.Groups[4].Value, aFileName, aBaseDirectory, aProperties,
        aDiagnostics);
    lNode := lNode.NextMatch;
  end;
end;

procedure ApplyPropertyFile(const aFileName, aBaseDirectory: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
var
  lText: string;
begin
  if not TFile.Exists(aFileName) then
  begin
    AddDiagnostic(aDiagnostics, CreateWarningDiagnostic('OPTSET_FILE_NOT_FOUND',
      'Optset file not found: ' + aFileName, aFileName));
    Exit;
  end;

  lText := TFile.ReadAllText(aFileName, TEncoding.UTF8);
  ApplyPropertyText(lText, aFileName, aBaseDirectory, aProperties, aDiagnostics);
end;

function TryResolveDccReferenceDirectory(const aProjectDirectory, aInclude: string;
  const aSearchPaths: TList<string>; out aDirectory: string): Boolean;
var
  lCandidate: string;
  lFileName: string;
  lIncludeFileName: string;
  lSearchPath: string;
begin
  aDirectory := '';
  if aInclude.Trim = '' then
    Exit(False);

  try
    lIncludeFileName := NormalizeProjectPath(aProjectDirectory, aInclude);
    lFileName := TPath.GetFileName(aInclude);
  except
    Exit(False);
  end;

  if TFile.Exists(lIncludeFileName) then
  begin
    aDirectory := ExtractFilePath(lIncludeFileName);
    Exit(True);
  end;

  if lFileName <> '' then
  begin
    for lSearchPath in aSearchPaths do
    begin
      lCandidate := TPath.Combine(lSearchPath, lFileName);
      if TFile.Exists(lCandidate) then
      begin
        aDirectory := lSearchPath;
        Exit(True);
      end;
    end;
  end;

  aDirectory := ExtractFilePath(aInclude);
  Result := aDirectory <> '';
end;

function TryResolveDccReferenceFileName(const aProjectDirectory, aInclude: string;
  const aSearchPaths: TList<string>; out aFileName: string): Boolean;
var
  lCandidate: string;
  lIncludeFileName: string;
  lSearchPath: string;
begin
  aFileName := '';
  if aInclude.Trim = '' then
    Exit(False);

  try
    lIncludeFileName := NormalizeProjectPath(aProjectDirectory, aInclude);
  except
    Exit(False);
  end;

  if TFile.Exists(lIncludeFileName) then
  begin
    aFileName := lIncludeFileName;
    Exit(True);
  end;

  for lSearchPath in aSearchPaths do
  begin
    lCandidate := TPath.Combine(lSearchPath, TPath.GetFileName(aInclude));
    if TFile.Exists(lCandidate) then
    begin
      aFileName := TPath.GetFullPath(lCandidate);
      Exit(True);
    end;
  end;

  Result := False;
end;

procedure AddReferenceDirectories(const aText, aProjectFileName, aProjectDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aSearchPaths, aItems, aSourceFiles: TList<string>);
var
  lCondition: string;
  lDirectory: string;
  lFileName: string;
  lGroup: TMatch;
  lGroupBody: string;
  lInclude: string;
  lMatch: TMatch;
begin
  lGroup := TRegEx.Match(aText, '<ItemGroup([^>]*)>(.*?)</ItemGroup>',
    [roIgnoreCase, roSingleLine]);
  while lGroup.Success do
  begin
    lCondition := ExtractAttributeValue(lGroup.Groups[1].Value, 'Condition');
    if IsConditionActive(lCondition, aProjectFileName, aProjectDirectory, aProperties,
      aDiagnostics) then
    begin
      lGroupBody := lGroup.Groups[2].Value;
      lMatch := TRegEx.Match(lGroupBody, '<DCCReference\s+([^>]*)>',
        [roIgnoreCase, roSingleLine]);
      while lMatch.Success do
      begin
        lCondition := ExtractAttributeValue(lMatch.Groups[1].Value, 'Condition');
        if IsConditionActive(lCondition, aProjectFileName, aProjectDirectory, aProperties,
          aDiagnostics) then
        begin
          lInclude := ExtractAttributeValue(lMatch.Groups[1].Value, 'Include');
          if HasUnresolvedPropertyReference(lInclude, aProperties) then
          begin
            ExpandProperties(lInclude, aProjectFileName, aProperties, aDiagnostics);
            lMatch := lMatch.NextMatch;
            Continue;
          end;

          lInclude := ExpandProperties(lInclude, aProjectFileName, aProperties, aDiagnostics);
          if TryResolveDccReferenceFileName(aProjectDirectory, lInclude, aSearchPaths,
            lFileName) then
            AddUniquePath(aSourceFiles, aProjectDirectory, lFileName);
          if not TryResolveDccReferenceDirectory(aProjectDirectory, lInclude, aSearchPaths,
            lDirectory) then
            AddUniquePath(aItems, aProjectDirectory, '.')
          else
            AddUniquePath(aItems, aProjectDirectory, lDirectory);
        end;
        lMatch := lMatch.NextMatch;
      end;
    end;
    lGroup := lGroup.NextMatch;
  end;
end;

procedure PopulateProjectSemanticContext(var aProject: TDelphiSemanticProjectInfo;
  const aText: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
var
  lDefines: TList<string>;
  lIncludePaths: TList<string>;
  lReferenceDirectories: TList<string>;
  lSearchPaths: TList<string>;
  lSourceFiles: TList<string>;
  lUnitAliases: TList<string>;
  lUnitScopeNames: TList<string>;
begin
  lDefines := nil;
  lIncludePaths := nil;
  lReferenceDirectories := nil;
  lSearchPaths := nil;
  lSourceFiles := nil;
  lUnitAliases := nil;
  lUnitScopeNames := nil;
  try
    lDefines := TList<string>.Create;
    lIncludePaths := TList<string>.Create;
    lReferenceDirectories := TList<string>.Create;
    lSearchPaths := TList<string>.Create;
    lSourceFiles := TList<string>.Create;
    lUnitAliases := TList<string>.Create;
    lUnitScopeNames := TList<string>.Create;

    AddDelimitedTexts(lDefines, GetPropertyValue(aProperties, 'DCC_Define'));
    AddDelimitedPaths(lIncludePaths, aProject.ProjectDirectory,
      GetPropertyValue(aProperties, 'DCC_IncludePath'));
    AddDelimitedPaths(lSearchPaths, aProject.ProjectDirectory,
      GetPropertyValue(aProperties, 'DCC_UnitSearchPath'));
    AddDelimitedTexts(lUnitScopeNames, GetPropertyValue(aProperties, 'DCC_UnitScopeNames'));
    AddDelimitedTexts(lUnitScopeNames, GetPropertyValue(aProperties, 'DCC_Namespace'));
    AddDelimitedTexts(lUnitAliases, GetPropertyValue(aProperties, 'DCC_UnitAlias'));
    AddDelimitedTexts(lUnitAliases, GetPropertyValue(aProperties, 'DCC_UnitAliases'));
    AddReferenceDirectories(aText, aProject.ProjectFileName, aProject.ProjectDirectory,
      aProperties, aDiagnostics, lSearchPaths, lReferenceDirectories, lSourceFiles);

    aProject.Defines := lDefines.ToArray;
    aProject.IncludePaths := lIncludePaths.ToArray;
    aProject.SearchPaths := lSearchPaths.ToArray;
    aProject.UnitScopeNames := lUnitScopeNames.ToArray;
    aProject.UnitAliases := lUnitAliases.ToArray;
    aProject.ReferenceDirectories := lReferenceDirectories.ToArray;
    aProject.SourceFileNames := lSourceFiles.ToArray;
  finally
    lUnitScopeNames.Free;
    lUnitAliases.Free;
    lSearchPaths.Free;
    lSourceFiles.Free;
    lReferenceDirectories.Free;
    lIncludePaths.Free;
    lDefines.Free;
  end;
end;

procedure AddAdditionalSourceFiles(var aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions);
var
  lFileName: string;
  lSourceFiles: TList<string>;
begin
  if Length(aOptions.AdditionalSourceFileNames) = 0 then
    Exit;

  lSourceFiles := TList<string>.Create;
  try
    for lFileName in aProject.SourceFileNames do
      AddUniquePath(lSourceFiles, aProject.ProjectDirectory, lFileName);
    for lFileName in aOptions.AdditionalSourceFileNames do
      AddUniquePath(lSourceFiles, aProject.ProjectDirectory, lFileName);
    aProject.SourceFileNames := lSourceFiles.ToArray;
  finally
    lSourceFiles.Free;
  end;
end;

function NormalizeFingerprintPart(const aValue, aFallback: string): string;
begin
  Result := Trim(aValue);
  if Result = '' then
    Result := aFallback;
end;

function BuildCompilerProfileName(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions): string;
var
  lConfiguration: string;
  lPlatform: string;
  lVersion: string;
begin
  lVersion := NormalizeFingerprintPart(aOptions.DelphiVersion, 'default');
  lPlatform := NormalizeFingerprintPart(aProject.Platform, 'default');
  lConfiguration := NormalizeFingerprintPart(aProject.Configuration, 'default');
  Result := Format('Delphi-%s-%s-%s', [lVersion, lPlatform, lConfiguration]);
end;

procedure AppendFingerprintItem(const aBuilder: TStringBuilder; const aName, aValue: string);
begin
  aBuilder.Append(aName);
  aBuilder.Append('=');
  aBuilder.AppendLine(aValue);
end;

procedure AppendFingerprintItems(const aBuilder: TStringBuilder; const aName: string;
  const aItems: TArray<string>);
var
  lItem: string;
begin
  aBuilder.Append(aName);
  aBuilder.Append('=');
  for lItem in aItems do
  begin
    aBuilder.Append(lItem);
    aBuilder.Append('|');
  end;
  aBuilder.AppendLine;
end;

function BuildContextFingerprint(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions): string;
var
  lBuilder: TStringBuilder;
begin
  lBuilder := TStringBuilder.Create;
  try
    AppendFingerprintItem(lBuilder, 'project', AnsiLowerCase(aProject.ProjectFileName));
    AppendFingerprintItem(lBuilder, 'main', AnsiLowerCase(aProject.MainSourceFileName));
    AppendFingerprintItem(lBuilder, 'configuration', aProject.Configuration);
    AppendFingerprintItem(lBuilder, 'platform', aProject.Platform);
    AppendFingerprintItem(lBuilder, 'delphiVersion', aOptions.DelphiVersion);
    AppendFingerprintItem(lBuilder, 'rsvars', AnsiLowerCase(aOptions.RsVarsPath));
    AppendFingerprintItem(lBuilder, 'envoptions', AnsiLowerCase(aOptions.EnvOptionsPath));
    AppendFingerprintItem(lBuilder, 'compilerProfile', aProject.CompilerProfileName);
    AppendFingerprintItems(lBuilder, 'defines', aProject.Defines);
    AppendFingerprintItems(lBuilder, 'includePaths', aProject.IncludePaths);
    AppendFingerprintItems(lBuilder, 'searchPaths', aProject.SearchPaths);
    AppendFingerprintItems(lBuilder, 'unitScopes', aProject.UnitScopeNames);
    AppendFingerprintItems(lBuilder, 'unitAliases', aProject.UnitAliases);
    AppendFingerprintItems(lBuilder, 'references', aProject.ReferenceDirectories);
    AppendFingerprintItems(lBuilder, 'sourceFiles', aProject.SourceFileNames);
    Result := THashSHA2.GetHashString(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

procedure PopulateProjectProperties(var aProject: TDelphiSemanticProjectInfo;
  const aProperties: TPropertyMap);
var
  lPair: TPair<string, string>;
  lProperties: TList<TDelphiSemanticProperty>;
  lProperty: TDelphiSemanticProperty;
begin
  lProperties := TList<TDelphiSemanticProperty>.Create;
  try
    for lPair in aProperties do
    begin
      lProperty.Name := lPair.Key;
      lProperty.Value := lPair.Value;
      lProperties.Add(lProperty);
    end;
    aProject.Properties := lProperties.ToArray;
  finally
    lProperties.Free;
  end;
end;

function CreateInitialProperties(const aProjectFileName, aText: string;
  const aOptions: TDelphiSemanticOptions): TPropertyMap;
var
  lEnvironmentProperty: TDelphiSemanticProperty;
  lProjectDirectory: string;
  lProjectFile: string;
  lProjectName: string;
begin
  Result := TPropertyMap.Create;
  lProjectDirectory := TPath.GetDirectoryName(aProjectFileName);
  lProjectFile := TPath.GetFileName(aProjectFileName);
  lProjectName := TPath.GetFileNameWithoutExtension(aProjectFileName);
  SetPropertyValue(Result, 'MSBuildProjectDirectory', lProjectDirectory);
  SetPropertyValue(Result, 'ProjectDir', IncludeTrailingPathDelimiter(lProjectDirectory));
  SetPropertyValue(Result, 'PROJECTDIR', IncludeTrailingPathDelimiter(lProjectDirectory));
  SetPropertyValue(Result, 'ProjectName', lProjectName);
  SetPropertyValue(Result, 'MSBuildProjectName', lProjectName);
  SetPropertyValue(Result, 'MSBuildProjectFullPath', aProjectFileName);
  SetPropertyValue(Result, 'MSBuildProjectFile', lProjectFile);
  SetPropertyValue(Result, 'Config', aOptions.Configuration);
  SetPropertyValue(Result, 'Platform', aOptions.Platform);
  SetPropertyValue(Result, 'DelphiVersion', aOptions.DelphiVersion);
  for lEnvironmentProperty in aOptions.EnvironmentVariables do
    if not Result.ContainsKey(PropertyKey(lEnvironmentProperty.Name)) then
      SetPropertyValue(Result, lEnvironmentProperty.Name, lEnvironmentProperty.Value);
  if GetPropertyValue(Result, 'Config') = '' then
    SetPropertyValue(Result, 'Config', ExtractXmlElementText(aText, 'Config'));
  if GetPropertyValue(Result, 'Platform') = '' then
    SetPropertyValue(Result, 'Platform', ExtractXmlElementText(aText, 'Platform'));
end;

function CreateProjectInfoFromProperties(const aProjectFileName, aText: string;
  const aProperties: TPropertyMap): TDelphiSemanticProjectInfo;
var
  lMainSource: string;
begin
  Result.ProjectFileName := aProjectFileName;
  Result.ProjectDirectory := TPath.GetDirectoryName(aProjectFileName);
  Result.ProjectName := GetPropertyValue(aProperties, 'ProjectName');
  if Result.ProjectName = '' then
    Result.ProjectName := TPath.GetFileNameWithoutExtension(aProjectFileName);

  Result.Configuration := GetPropertyValue(aProperties, 'Config');
  Result.Platform := GetPropertyValue(aProperties, 'Platform');

  lMainSource := GetPropertyValue(aProperties, 'MainSource');
  if lMainSource = '' then
    lMainSource := ExtractXmlElementText(aText, 'MainSource');
  if lMainSource = '' then
    lMainSource := TPath.ChangeExtension(TPath.GetFileName(aProjectFileName), '.dpr');
  Result.MainSourceFileName := NormalizeProjectPath(Result.ProjectDirectory, lMainSource);
  PopulateProjectProperties(Result, aProperties);
end;

function ResolveProjectFileName(const aFileName: string; out aProjectFileName: string;
  out aFailure: TDelphiSemanticContextResult): Boolean;
var
  lExtension: string;
  lInputFileName: string;
begin
  lInputFileName := TPath.GetFullPath(aFileName);
  if not TFile.Exists(lInputFileName) then
  begin
    aFailure := FailureResult(CreateErrorDiagnostic('PROJECT_FILE_NOT_FOUND',
      'Project file not found: ' + lInputFileName, lInputFileName));
    Exit(False);
  end;

  lExtension := TPath.GetExtension(lInputFileName).ToLowerInvariant;
  if lExtension = '.dproj' then
  begin
    aProjectFileName := lInputFileName;
    Exit(True);
  end;

  if lExtension = '.dpr' then
  begin
    aProjectFileName := TPath.ChangeExtension(lInputFileName, '.dproj');
    if TFile.Exists(aProjectFileName) then
      Exit(True);

    aFailure := FailureResult(CreateErrorDiagnostic('PROJECT_FILE_NOT_FOUND',
      'Sibling .dproj file not found: ' + aProjectFileName, aProjectFileName));
    Exit(False);
  end;

  aFailure := FailureResult(CreateErrorDiagnostic('PROJECT_FILE_UNSUPPORTED',
    'Unsupported project file extension: ' + lExtension, lInputFileName));
  Result := False;
end;

function LoadProjectInfo(const aProjectFileName: string; const aOptions: TDelphiSemanticOptions;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>): TDelphiSemanticProjectInfo;
var
  lProperties: TPropertyMap;
  lText: string;
begin
  lText := TFile.ReadAllText(aProjectFileName, TEncoding.UTF8);
  lProperties := CreateInitialProperties(aProjectFileName, lText, aOptions);
  try
    ApplyPropertyText(lText, aProjectFileName, TPath.GetDirectoryName(aProjectFileName),
      lProperties, aDiagnostics);
    Result := CreateProjectInfoFromProperties(aProjectFileName, lText, lProperties);
    PopulateProjectSemanticContext(Result, lText, lProperties, aDiagnostics);
    AddAdditionalSourceFiles(Result, aOptions);
    Result.CompilerProfileName := BuildCompilerProfileName(Result, aOptions);
    Result.ContextFingerprint := BuildContextFingerprint(Result, aOptions);
  finally
    lProperties.Free;
  end;
end;

class function TDelphiSemanticProject.Load(const aFileName: string): TDelphiSemanticContextResult;
var
  lOptions: TDelphiSemanticOptions;
begin
  lOptions := Default(TDelphiSemanticOptions);
  Result := Load(aFileName, lOptions);
end;

class function TDelphiSemanticProject.Load(const aFileName: string;
  const aOptions: TDelphiSemanticOptions): TDelphiSemanticContextResult;
var
  lDiagnostics: TList<TDelphiSemanticDiagnostic>;
  lFailure: TDelphiSemanticContextResult;
  lProject: TDelphiSemanticProjectInfo;
  lProjectFileName: string;
begin
  if not ResolveProjectFileName(aFileName, lProjectFileName, lFailure) then
    Exit(lFailure);

  lDiagnostics := TList<TDelphiSemanticDiagnostic>.Create;
  try
    lProject := LoadProjectInfo(lProjectFileName, aOptions, lDiagnostics);
    Result := SuccessResult(lProject, lDiagnostics);
  finally
    lDiagnostics.Free;
  end;
end;

end.
