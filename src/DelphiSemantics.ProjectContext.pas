unit DelphiSemantics.ProjectContext;

interface

type
  TDelphiSemanticDiagnosticSeverity = (dsInfo, dsWarning, dsError);

  TDelphiSemanticOptions = record
    Configuration: string;
    Platform: string;
    SqliteCacheFileName: string;
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
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
    UnitScopeNames: TArray<string>;
    UnitAliases: TArray<string>;
    ReferenceDirectories: TArray<string>;
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

implementation

uses
  System.Generics.Collections,
  System.IOUtils,
  System.RegularExpressions,
  System.StrUtils,
  System.SysUtils;

type
  TPropertyMap = TDictionary<string, string>;

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

function GetPropertyValue(const aProperties: TPropertyMap; const aName: string): string;
begin
  if not aProperties.TryGetValue(PropertyKey(aName), Result) then
    Result := '';
end;

procedure SetPropertyValue(const aProperties: TPropertyMap; const aName, aValue: string);
var
  lKey: string;
begin
  lKey := PropertyKey(aName);
  if aProperties.ContainsKey(lKey) then
    aProperties[lKey] := aValue
  else
    aProperties.Add(lKey, aValue);
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

function EvaluateConditionClause(const aCondition: string; const aProperties: TPropertyMap): Boolean;
var
  lActualValue: string;
  lExpectedValue: string;
  lMatch: TMatch;
  lOperator: string;
  lText: string;
begin
  lText := StripOuterParentheses(aCondition);

  lMatch := TRegEx.Match(lText,
    '^''\$\(([A-Za-z_][A-Za-z0-9_]*)\)''\s*(==|!=)\s*''([^'']*)''$',
    [roIgnoreCase, roSingleLine]);
  if not lMatch.Success then
    Exit(False);

  lActualValue := GetPropertyValue(aProperties, lMatch.Groups[1].Value);
  lOperator := lMatch.Groups[2].Value;
  lExpectedValue := lMatch.Groups[3].Value;
  if lOperator = '==' then
    Result := SameText(lActualValue, lExpectedValue)
  else
    Result := not SameText(lActualValue, lExpectedValue);
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

function IsConditionActive(const aCondition: string; const aProperties: TPropertyMap): Boolean;
var
  lAndClause: string;
  lAndClauses: TArray<string>;
  lClause: string;
  lClauses: TArray<string>;
  lResult: Boolean;
begin
  if aCondition.Trim = '' then
    Exit(True);

  lClauses := TRegEx.Split(StripOuterParentheses(aCondition), '\s+[Oo][Rr]\s+');
  for lClause in lClauses do
  begin
    lResult := True;
    lAndClauses := TRegEx.Split(StripOuterParentheses(lClause), '\s+[Aa][Nn][Dd]\s+');
    for lAndClause in lAndClauses do
    begin
      if not EvaluateConditionClause(lAndClause, aProperties) then
      begin
        lResult := False;
        Break;
      end;
    end;
    if lResult then
      Exit(True);
  end;

  Result := False;
end;

function HasUnresolvedPropertyReference(const aValue: string; const aProperties: TPropertyMap): Boolean;
var
  lMacroName: string;
  lMacroStart: Integer;
  lMacroStop: Integer;
begin
  lMacroStart := Pos('$(', aValue);
  while lMacroStart > 0 do
  begin
    lMacroStop := PosEx(')', aValue, lMacroStart + 2);
    if lMacroStop = 0 then
      Break;

    lMacroName := Copy(aValue, lMacroStart + 2, lMacroStop - lMacroStart - 2);
    if GetPropertyValue(aProperties, lMacroName) = '' then
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
    lReplacement := GetPropertyValue(aProperties, lMacroName);
    if lReplacement = '' then
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

procedure ApplyPropertyFile(const aFileName, aBaseDirectory: string; const aProperties: TPropertyMap;
  const aDiagnostics: TList<TDelphiSemanticDiagnostic>); forward;

procedure ApplyPropertyText(const aText, aFileName, aBaseDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>);
var
  lChild: TMatch;
  lCondition: string;
  lExpandedValue: string;
  lGroup: TMatch;
  lGroupBody: string;
  lName: string;
  lOptsetPath: string;
  lPart: string;
  lParts: TArray<string>;
  lValue: string;
begin
  lGroup := TRegEx.Match(aText, '<PropertyGroup([^>]*)>(.*?)</PropertyGroup>',
    [roIgnoreCase, roSingleLine]);
  while lGroup.Success do
  begin
    lCondition := ExtractAttributeValue(lGroup.Groups[1].Value, 'Condition');
    if IsConditionActive(lCondition, aProperties) then
    begin
      lGroupBody := lGroup.Groups[2].Value;
      lChild := TRegEx.Match(lGroupBody, '<([A-Za-z_][A-Za-z0-9_\.]*)([^>]*)>(.*?)</\1>',
        [roIgnoreCase, roSingleLine]);
      while lChild.Success do
      begin
        lName := lChild.Groups[1].Value;
        lCondition := ExtractAttributeValue(lChild.Groups[2].Value, 'Condition');
        if IsConditionActive(lCondition, aProperties) then
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
    lGroup := lGroup.NextMatch;
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

procedure AddReferenceDirectories(const aText, aProjectFileName, aProjectDirectory: string;
  const aProperties: TPropertyMap; const aDiagnostics: TList<TDelphiSemanticDiagnostic>;
  const aItems: TList<string>);
var
  lCondition: string;
  lDirectory: string;
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
    if IsConditionActive(lCondition, aProperties) then
    begin
      lGroupBody := lGroup.Groups[2].Value;
      lMatch := TRegEx.Match(lGroupBody, '<DCCReference\s+([^>]*)>',
        [roIgnoreCase, roSingleLine]);
      while lMatch.Success do
      begin
        lCondition := ExtractAttributeValue(lMatch.Groups[1].Value, 'Condition');
        if IsConditionActive(lCondition, aProperties) then
        begin
          lInclude := ExtractAttributeValue(lMatch.Groups[1].Value, 'Include');
          if HasUnresolvedPropertyReference(lInclude, aProperties) then
          begin
            ExpandProperties(lInclude, aProjectFileName, aProperties, aDiagnostics);
            lMatch := lMatch.NextMatch;
            Continue;
          end;

          lInclude := ExpandProperties(lInclude, aProjectFileName, aProperties, aDiagnostics);
          lDirectory := ExtractFilePath(lInclude);
          if lDirectory = '' then
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
  lReferenceDirectories: TList<string>;
  lSearchPaths: TList<string>;
  lUnitAliases: TList<string>;
  lUnitScopeNames: TList<string>;
begin
  lDefines := TList<string>.Create;
  lReferenceDirectories := TList<string>.Create;
  lSearchPaths := TList<string>.Create;
  lUnitAliases := TList<string>.Create;
  lUnitScopeNames := TList<string>.Create;
  try
    AddDelimitedTexts(lDefines, GetPropertyValue(aProperties, 'DCC_Define'));
    AddDelimitedPaths(lSearchPaths, aProject.ProjectDirectory,
      GetPropertyValue(aProperties, 'DCC_UnitSearchPath'));
    AddDelimitedTexts(lUnitScopeNames, GetPropertyValue(aProperties, 'DCC_UnitScopeNames'));
    AddDelimitedTexts(lUnitAliases, GetPropertyValue(aProperties, 'DCC_UnitAlias'));
    AddReferenceDirectories(aText, aProject.ProjectFileName, aProject.ProjectDirectory,
      aProperties, aDiagnostics, lReferenceDirectories);

    aProject.Defines := lDefines.ToArray;
    aProject.SearchPaths := lSearchPaths.ToArray;
    aProject.UnitScopeNames := lUnitScopeNames.ToArray;
    aProject.UnitAliases := lUnitAliases.ToArray;
    aProject.ReferenceDirectories := lReferenceDirectories.ToArray;
  finally
    lUnitScopeNames.Free;
    lUnitAliases.Free;
    lSearchPaths.Free;
    lReferenceDirectories.Free;
    lDefines.Free;
  end;
end;

function CreateInitialProperties(const aProjectFileName, aText: string;
  const aOptions: TDelphiSemanticOptions): TPropertyMap;
var
  lProjectDirectory: string;
begin
  Result := TPropertyMap.Create;
  lProjectDirectory := TPath.GetDirectoryName(aProjectFileName);
  SetPropertyValue(Result, 'MSBuildProjectDirectory', lProjectDirectory);
  SetPropertyValue(Result, 'ProjectDir', IncludeTrailingPathDelimiter(lProjectDirectory));
  SetPropertyValue(Result, 'Config', aOptions.Configuration);
  SetPropertyValue(Result, 'Platform', aOptions.Platform);
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
