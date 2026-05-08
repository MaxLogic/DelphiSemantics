unit DelphiSemantics.Preprocess;

interface

type
  TDelphiSemanticPreprocessOptions = record
    SourceFileName: string;
    SourceText: string;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
  end;

  TDelphiSemanticPreprocessDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
    Line: Integer;
    Column: Integer;
  end;

  TDelphiSemanticSourceRegion = record
    FileName: string;
    StartLine: Integer;
    EndLine: Integer;
    Active: Boolean;
  end;

  TDelphiSemanticIncludeFile = record
    FileName: string;
    ContentHash: string;
  end;

  TDelphiSemanticPreprocessResult = record
    Success: Boolean;
    OutputText: string;
    IncludeGraphHash: string;
    Regions: TArray<TDelphiSemanticSourceRegion>;
    Includes: TArray<TDelphiSemanticIncludeFile>;
    Diagnostics: TArray<TDelphiSemanticPreprocessDiagnostic>;
  end;

  TDelphiSemanticPreprocessor = record
  public
    class function PreprocessFile(const aOptions: TDelphiSemanticPreprocessOptions):
      TDelphiSemanticPreprocessResult; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils;

type
  TDefineMap = TDictionary<string, Boolean>;

  TPreprocessFrame = record
    ParentActive: Boolean;
    Active: Boolean;
    BranchTaken: Boolean;
  end;

function CreateDiagnostic(const aCode, aMessage, aFileName: string;
  const aLine: Integer): TDelphiSemanticPreprocessDiagnostic;
begin
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Line := aLine;
  Result.Column := 1;
end;

procedure AddDiagnostic(const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  const aCode, aMessage, aFileName: string; const aLine: Integer);
begin
  aDiagnostics.Add(CreateDiagnostic(aCode, aMessage, aFileName, aLine));
end;

function DefineKey(const aName: string): string;
begin
  Result := UpperCase(aName.Trim);
end;

function IsDefined(const aDefines: TDefineMap; const aName: string): Boolean;
begin
  Result := aDefines.ContainsKey(DefineKey(aName));
end;

function CalculateTextHash(const aText: string): string;
var
  i: Integer;
  lHash: UInt64;
begin
  lHash := 2166136261;
  for i := 1 to Length(aText) do
  begin
    lHash := lHash xor Ord(aText[i]);
    lHash := (lHash * 16777619) mod $100000000;
  end;
  Result := IntToHex(Int64(lHash), 8);
end;

function CurrentActive(const aStack: TList<TPreprocessFrame>): Boolean;
begin
  if aStack.Count = 0 then
    Exit(True);

  Result := aStack[Pred(aStack.Count)].Active;
end;

function TryExtractDirective(const aLine: string; out aDirective: string): Boolean;
var
  lStart: Integer;
  lStop: Integer;
begin
  lStart := Pos('{$', aLine);
  if lStart > 0 then
  begin
    lStop := PosEx('}', aLine, lStart + 2);
    if lStop > lStart then
    begin
      aDirective := Copy(aLine, lStart + 2, lStop - lStart - 2).Trim;
      Exit(True);
    end;
  end;

  lStart := Pos('(*$', aLine);
  if lStart > 0 then
  begin
    lStop := PosEx('*)', aLine, lStart + 3);
    if lStop > lStart then
    begin
      aDirective := Copy(aLine, lStart + 3, lStop - lStart - 3).Trim;
      Exit(True);
    end;
  end;

  Result := False;
end;

function StripOuterParentheses(const aText: string): string;
var
  i: Integer;
  lDepth: Integer;
  lText: string;
begin
  lText := aText.Trim;
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
          Exit(lText);
      end;
    end;
    lText := Copy(lText, 2, Length(lText) - 2).Trim;
  end;
  Result := lText;
end;

function IsOperatorBoundary(const aText: string; const aIndex: Integer): Boolean;
begin
  Result := (aIndex < 1) or (aIndex > Length(aText)) or
    not CharInSet(aText[aIndex], ['A'..'Z', 'a'..'z', '0'..'9', '_']);
end;

function IsOperatorAt(const aText: string; const aIndex: Integer; const aOperator: string): Boolean;
var
  lOperatorLength: Integer;
begin
  lOperatorLength := Length(aOperator);
  if (aIndex < 1) or (aIndex + lOperatorLength - 1 > Length(aText)) then
    Exit(False);

  Result := SameText(Copy(aText, aIndex, lOperatorLength), aOperator) and
    IsOperatorBoundary(aText, aIndex - 1) and
    IsOperatorBoundary(aText, aIndex + lOperatorLength);
end;

function TrySplitTopLevelExpression(const aText, aOperator: string;
  out aLeft, aRight: string): Boolean;
var
  i: Integer;
  lDepth: Integer;
begin
  lDepth := 0;
  i := 1;
  while i <= Length(aText) do
  begin
    if aText[i] = '(' then
      Inc(lDepth)
    else if aText[i] = ')' then
      Dec(lDepth)
    else if (lDepth = 0) and IsOperatorAt(aText, i, aOperator) then
    begin
      aLeft := Copy(aText, 1, i - 1).Trim;
      aRight := Copy(aText, i + Length(aOperator), MaxInt).Trim;
      Exit((aLeft <> '') and (aRight <> ''));
    end;
    Inc(i);
  end;

  Result := False;
end;

function TryEvaluateIfExpression(const aExpression: string; const aDefines: TDefineMap;
  out aActive: Boolean): Boolean;
var
  lLeft: string;
  lLeftActive: Boolean;
  lName: string;
  lRight: string;
  lRightActive: Boolean;
  lText: string;
begin
  lText := StripOuterParentheses(aExpression);

  if TrySplitTopLevelExpression(lText, 'or', lLeft, lRight) then
  begin
    if not TryEvaluateIfExpression(lLeft, aDefines, lLeftActive) then
      Exit(False);
    if lLeftActive then
    begin
      aActive := True;
      Exit(True);
    end;
    if not TryEvaluateIfExpression(lRight, aDefines, lRightActive) then
      Exit(False);
    aActive := lRightActive;
    Exit(True);
  end;

  if TrySplitTopLevelExpression(lText, 'and', lLeft, lRight) then
  begin
    if not TryEvaluateIfExpression(lLeft, aDefines, lLeftActive) then
      Exit(False);
    if not lLeftActive then
    begin
      aActive := False;
      Exit(True);
    end;
    if not TryEvaluateIfExpression(lRight, aDefines, lRightActive) then
      Exit(False);
    aActive := lRightActive;
    Exit(True);
  end;

  if StartsText('not ', lText) then
  begin
    if not TryEvaluateIfExpression(Copy(lText, 5, MaxInt), aDefines, lLeftActive) then
      Exit(False);
    aActive := not lLeftActive;
    Exit(True);
  end;

  if StartsText('Defined(', lText) and EndsText(')', lText) then
  begin
    lName := Copy(lText, 9, Length(lText) - 9);
    aActive := IsDefined(aDefines, lName);
    Exit(True);
  end;

  if SameText(lText, 'True') then
  begin
    aActive := True;
    Exit(True);
  end;

  if SameText(lText, 'False') then
  begin
    aActive := False;
    Exit(True);
  end;

  if (Pos('(', lText) > 0) or (Pos(')', lText) > 0) then
    Exit(False);

  if lText <> '' then
  begin
    aActive := IsDefined(aDefines, lText);
    Exit(True);
  end;

  Result := False;
end;

procedure AddRegion(const aRegions: TList<TDelphiSemanticSourceRegion>; const aFileName: string;
  const aLine: Integer; const aActive: Boolean);
var
  lRegion: TDelphiSemanticSourceRegion;
begin
  lRegion.FileName := aFileName;
  lRegion.StartLine := aLine;
  lRegion.EndLine := aLine;
  lRegion.Active := aActive;
  aRegions.Add(lRegion);
end;

function ResolveIncludeFileName(const aIncludeName, aCurrentDirectory: string;
  const aOptions: TDelphiSemanticPreprocessOptions; out aFileName: string): Boolean;
var
  lPath: string;
  lSearchPath: string;
begin
  if TPath.IsPathRooted(aIncludeName) then
  begin
    aFileName := TPath.GetFullPath(aIncludeName);
    Exit(TFile.Exists(aFileName));
  end;

  lPath := TPath.GetFullPath(TPath.Combine(aCurrentDirectory, aIncludeName));
  if TFile.Exists(lPath) then
  begin
    aFileName := lPath;
    Exit(True);
  end;

  for lSearchPath in aOptions.SearchPaths do
  begin
    lPath := TPath.GetFullPath(TPath.Combine(lSearchPath, aIncludeName));
    if TFile.Exists(lPath) then
    begin
      aFileName := lPath;
      Exit(True);
    end;
  end;

  aFileName := '';
  Result := False;
end;

function IncludeArgumentFromDirective(const aDirective: string): string;
var
  lText: string;
begin
  lText := aDirective.Trim;
  if StartsText('I ', lText) then
    lText := Copy(lText, 3, MaxInt).Trim
  else if StartsText('INCLUDE ', lText) then
    lText := Copy(lText, 9, MaxInt).Trim
  else
    Exit('');

  if (Length(lText) >= 2) and (lText[1] = '''') and (lText[Length(lText)] = '''') then
    lText := Copy(lText, 2, Length(lText) - 2);

  Result := lText;
end;

procedure PushConditionalFrame(const aStack: TList<TPreprocessFrame>;
  const aActive: Boolean);
var
  lFrame: TPreprocessFrame;
begin
  lFrame.ParentActive := CurrentActive(aStack);
  lFrame.Active := lFrame.ParentActive and aActive;
  lFrame.BranchTaken := aActive;
  aStack.Add(lFrame);
end;

procedure PushUnsupportedConditionalFrame(const aStack: TList<TPreprocessFrame>);
var
  lFrame: TPreprocessFrame;
begin
  lFrame.ParentActive := CurrentActive(aStack);
  lFrame.Active := False;
  lFrame.BranchTaken := True;
  aStack.Add(lFrame);
end;

procedure DisableUnsupportedConditionalFrame(const aStack: TList<TPreprocessFrame>);
var
  lFrame: TPreprocessFrame;
begin
  if aStack.Count = 0 then
    Exit;

  lFrame := aStack[Pred(aStack.Count)];
  lFrame.Active := False;
  lFrame.BranchTaken := True;
  aStack[Pred(aStack.Count)] := lFrame;
end;

procedure UpdateElseFrame(const aStack: TList<TPreprocessFrame>);
var
  lFrame: TPreprocessFrame;
begin
  lFrame := aStack[Pred(aStack.Count)];
  lFrame.Active := lFrame.ParentActive and not lFrame.BranchTaken;
  lFrame.BranchTaken := True;
  aStack[Pred(aStack.Count)] := lFrame;
end;

procedure UpdateElseIfFrame(const aStack: TList<TPreprocessFrame>; const aActive: Boolean);
var
  lFrame: TPreprocessFrame;
begin
  lFrame := aStack[Pred(aStack.Count)];
  lFrame.Active := lFrame.ParentActive and not lFrame.BranchTaken and aActive;
  lFrame.BranchTaken := lFrame.BranchTaken or aActive;
  aStack[Pred(aStack.Count)] := lFrame;
end;

function IsFileInStack(const aStack: TList<string>; const aFileName: string): Boolean;
var
  lFileName: string;
begin
  for lFileName in aStack do
    if SameText(lFileName, aFileName) then
      Exit(True);

  Result := False;
end;

function ProcessDirective(const aDirective, aFileName: string; const aLine: Integer;
  const aOptions: TDelphiSemanticPreprocessOptions; const aDefines: TDefineMap;
  const aStack: TList<TPreprocessFrame>; const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  const aOutput: TStringBuilder; const aRegions: TList<TDelphiSemanticSourceRegion>;
  const aIncludes: TList<TDelphiSemanticIncludeFile>; const aIncludeStack: TList<string>;
  var aOutputLineWritten: Boolean): Boolean; forward;

function IsRootSourceFile(const aFileName: string;
  const aOptions: TDelphiSemanticPreprocessOptions): Boolean;
begin
  Result := SameText(TPath.GetFullPath(aOptions.SourceFileName), aFileName);
end;

procedure ProcessSourceFile(const aFileName: string; const aOptions: TDelphiSemanticPreprocessOptions;
  const aDefines: TDefineMap; const aStack: TList<TPreprocessFrame>;
  const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>; const aOutput: TStringBuilder;
  const aRegions: TList<TDelphiSemanticSourceRegion>; const aIncludes: TList<TDelphiSemanticIncludeFile>;
  const aIncludeStack: TList<string>; var aSuccess: Boolean);
var
  i: Integer;
  lDirective: string;
  lLines: TStringList;
  lOutputLineWritten: Boolean;
  lText: string;
begin
  if not TFile.Exists(aFileName) then
  begin
    AddDiagnostic(aDiagnostics, 'SOURCE_FILE_NOT_FOUND', 'Source file not found: ' + aFileName,
      aFileName, 0);
    aSuccess := False;
    Exit;
  end;

  if IsFileInStack(aIncludeStack, aFileName) then
  begin
    AddDiagnostic(aDiagnostics, 'INCLUDE_CYCLE', 'Include cycle detected: ' + aFileName,
      aFileName, 0);
    aSuccess := False;
    Exit;
  end;

  if IsRootSourceFile(aFileName, aOptions) and (aOptions.SourceText <> '') then
    lText := aOptions.SourceText
  else
    lText := TFile.ReadAllText(aFileName, TEncoding.UTF8);
  lLines := TStringList.Create;
  try
    aIncludeStack.Add(aFileName);
    lLines.Text := lText;
    for i := 0 to Pred(lLines.Count) do
    begin
      if TryExtractDirective(lLines[i], lDirective) then
      begin
        lOutputLineWritten := False;
        if not ProcessDirective(lDirective, aFileName, i + 1, aOptions, aDefines, aStack,
          aDiagnostics, aOutput, aRegions, aIncludes, aIncludeStack, lOutputLineWritten) then
          aSuccess := False;
        if not lOutputLineWritten then
          aOutput.AppendLine('');
      end else
      begin
        AddRegion(aRegions, aFileName, i + 1, CurrentActive(aStack));
        if CurrentActive(aStack) then
          aOutput.AppendLine(lLines[i])
        else
          aOutput.AppendLine('');
      end;
    end;
  finally
    if aIncludeStack.Count > 0 then
      aIncludeStack.Delete(Pred(aIncludeStack.Count));
    lLines.Free;
  end;
end;

function ProcessDirective(const aDirective, aFileName: string; const aLine: Integer;
  const aOptions: TDelphiSemanticPreprocessOptions; const aDefines: TDefineMap;
  const aStack: TList<TPreprocessFrame>; const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  const aOutput: TStringBuilder; const aRegions: TList<TDelphiSemanticSourceRegion>;
  const aIncludes: TList<TDelphiSemanticIncludeFile>; const aIncludeStack: TList<string>;
  var aOutputLineWritten: Boolean): Boolean;
var
  lActive: Boolean;
  lInclude: TDelphiSemanticIncludeFile;
  lIncludeFileName: string;
  lIncludeName: string;
  lIncludeOutput: TStringBuilder;
  lSuccess: Boolean;
  lText: string;
begin
  Result := True;
  aOutputLineWritten := False;
  lText := aDirective.Trim;

  if StartsText('IFDEF ', lText) then
  begin
    PushConditionalFrame(aStack, IsDefined(aDefines, Copy(lText, 7, MaxInt)));
    Exit(True);
  end;

  if StartsText('IFNDEF ', lText) then
  begin
    PushConditionalFrame(aStack, not IsDefined(aDefines, Copy(lText, 8, MaxInt)));
    Exit(True);
  end;

  if StartsText('IF ', lText) then
  begin
    if TryEvaluateIfExpression(Copy(lText, 4, MaxInt), aDefines, lActive) then
      PushConditionalFrame(aStack, lActive)
    else
    begin
      AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
        'Unsupported conditional directive: ' + aDirective, aFileName, aLine);
      PushUnsupportedConditionalFrame(aStack);
      Exit(False);
    end;
    Exit(True);
  end;

  if StartsText('DEFINE ', lText) then
  begin
    if CurrentActive(aStack) then
      aDefines.AddOrSetValue(DefineKey(Copy(lText, 8, MaxInt)), True);
    Exit(True);
  end;

  if StartsText('UNDEF ', lText) then
  begin
    if CurrentActive(aStack) then
      aDefines.Remove(DefineKey(Copy(lText, 7, MaxInt)));
    Exit(True);
  end;

  if StartsText('ELSEIF ', lText) then
  begin
    if aStack.Count = 0 then
    begin
      AddDiagnostic(aDiagnostics, 'UNMATCHED_PREPROCESS_DIRECTIVE',
        'Unmatched conditional directive: ' + aDirective, aFileName, aLine);
      Exit(False);
    end;

    if TryEvaluateIfExpression(Copy(lText, 8, MaxInt), aDefines, lActive) then
      UpdateElseIfFrame(aStack, lActive)
    else
    begin
      AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
        'Unsupported conditional directive: ' + aDirective, aFileName, aLine);
      DisableUnsupportedConditionalFrame(aStack);
      Exit(False);
    end;
    Exit(True);
  end;

  if SameText(lText, 'ELSE') then
  begin
    if aStack.Count = 0 then
    begin
      AddDiagnostic(aDiagnostics, 'UNMATCHED_PREPROCESS_DIRECTIVE',
        'Unmatched conditional directive: ' + aDirective, aFileName, aLine);
      Exit(False);
    end;

    UpdateElseFrame(aStack);
    Exit(True);
  end;

  if SameText(lText, 'ENDIF') or SameText(lText, 'IFEND') then
  begin
    if aStack.Count = 0 then
    begin
      AddDiagnostic(aDiagnostics, 'UNMATCHED_PREPROCESS_DIRECTIVE',
        'Unmatched conditional directive: ' + aDirective, aFileName, aLine);
      Exit(False);
    end;

    aStack.Delete(Pred(aStack.Count));
    Exit(True);
  end;

  lIncludeName := IncludeArgumentFromDirective(lText);
  if lIncludeName <> '' then
  begin
    if not CurrentActive(aStack) then
      Exit(True);

    if not ResolveIncludeFileName(lIncludeName, TPath.GetDirectoryName(aFileName), aOptions,
      lIncludeFileName) then
    begin
      AddDiagnostic(aDiagnostics, 'INCLUDE_FILE_NOT_FOUND', 'Include file not found: ' +
        lIncludeName, aFileName, aLine);
      Exit(False);
    end;

    lInclude.FileName := lIncludeFileName;
    lInclude.ContentHash := CalculateTextHash(TFile.ReadAllText(lIncludeFileName, TEncoding.UTF8));
    aIncludes.Add(lInclude);
    lSuccess := True;
    lIncludeOutput := TStringBuilder.Create;
    try
      ProcessSourceFile(lIncludeFileName, aOptions, aDefines, aStack, aDiagnostics,
        lIncludeOutput, aRegions, aIncludes, aIncludeStack, lSuccess);
      aOutput.Append(lIncludeOutput.ToString);
      aOutputLineWritten := True;
    finally
      lIncludeOutput.Free;
    end;
    Exit(lSuccess);
  end;

  if StartsText('IFOPT ', lText) then
  begin
    AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
      'Unsupported conditional directive: ' + aDirective, aFileName, aLine);
    PushUnsupportedConditionalFrame(aStack);
    Exit(False);
  end;

  AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
    'Unsupported preprocessing directive: ' + aDirective, aFileName, aLine);
  Result := False;
end;

function CreateDefineMap(const aDefines: TArray<string>): TDefineMap;
var
  lDefine: string;
begin
  Result := TDefineMap.Create;
  for lDefine in aDefines do
    if lDefine.Trim <> '' then
      Result.AddOrSetValue(DefineKey(lDefine), True);
end;

function CalculateIncludeGraphHash(const aIncludes: TList<TDelphiSemanticIncludeFile>): string;
var
  lInclude: TDelphiSemanticIncludeFile;
  lText: string;
begin
  lText := '';
  for lInclude in aIncludes do
    lText := lText + lInclude.FileName + '=' + lInclude.ContentHash + ';';

  Result := CalculateTextHash(lText);
end;

class function TDelphiSemanticPreprocessor.PreprocessFile(
  const aOptions: TDelphiSemanticPreprocessOptions): TDelphiSemanticPreprocessResult;
var
  lDefines: TDefineMap;
  lDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  lIncludeStack: TList<string>;
  lIncludes: TList<TDelphiSemanticIncludeFile>;
  lOutput: TStringBuilder;
  lRegions: TList<TDelphiSemanticSourceRegion>;
  lStack: TList<TPreprocessFrame>;
  lSuccess: Boolean;
begin
  lDefines := nil;
  lDiagnostics := nil;
  lIncludes := nil;
  lIncludeStack := nil;
  lOutput := nil;
  lRegions := nil;
  lStack := nil;
  try
    lDefines := CreateDefineMap(aOptions.Defines);
    lDiagnostics := TList<TDelphiSemanticPreprocessDiagnostic>.Create;
    lIncludes := TList<TDelphiSemanticIncludeFile>.Create;
    lIncludeStack := TList<string>.Create;
    lOutput := TStringBuilder.Create;
    lRegions := TList<TDelphiSemanticSourceRegion>.Create;
    lStack := TList<TPreprocessFrame>.Create;

    lSuccess := True;
    ProcessSourceFile(TPath.GetFullPath(aOptions.SourceFileName), aOptions, lDefines, lStack,
      lDiagnostics, lOutput, lRegions, lIncludes, lIncludeStack, lSuccess);
    if lStack.Count > 0 then
    begin
      AddDiagnostic(lDiagnostics, 'UNTERMINATED_PREPROCESS_CONDITIONAL',
        'Unterminated conditional directive stack.', aOptions.SourceFileName, 0);
      lSuccess := False;
    end;
    Result.Success := lSuccess;
    Result.OutputText := lOutput.ToString;
    Result.IncludeGraphHash := CalculateIncludeGraphHash(lIncludes);
    Result.Regions := lRegions.ToArray;
    Result.Includes := lIncludes.ToArray;
    Result.Diagnostics := lDiagnostics.ToArray;
  finally
    lStack.Free;
    lRegions.Free;
    lOutput.Free;
    lIncludeStack.Free;
    lIncludes.Free;
    lDiagnostics.Free;
    lDefines.Free;
  end;
end;

end.
