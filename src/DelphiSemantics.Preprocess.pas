unit DelphiSemantics.Preprocess;

interface

uses
  DelphiSemantics.Source;

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
    SourceObservations: IDelphiSemanticSourceObservations;
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
  System.Classes, System.Generics.Collections, System.IOUtils, System.StrUtils, System.SysUtils,
  MaxLogic.StrUtils, SimpleParser.Lexer, SimpleParser.Lexer.Types;

type
  TDefineMap = TDictionary<string, Boolean>;
  TSourceTextCache = TDictionary<string, TDelphiSemanticSourceLoadResult>;

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
const
  cFnv32Mask: UInt64 = $FFFFFFFF;
  cFnvOffsetBasis: UInt64 = 2166136261;
  cFnvPrime: UInt64 = 16777619;
var
  i: Integer;
  lHash: UInt64;
begin
  lHash := cFnvOffsetBasis;
  for i := 1 to Length(aText) do
  begin
    lHash := lHash xor Ord(aText[i]);
    lHash := (lHash * cFnvPrime) and cFnv32Mask;
  end;
  Result := IntToHex(Int64(lHash), 8);
end;

function TryLoadPreprocessSource(const aFileName: string;
  const aSourceCache: TSourceTextCache;
  const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  out aSourceText: string): Boolean;
var
  lDiagnostic: TDelphiSemanticSourceDiagnostic;
  lFileName: string;
  lSourceLoad: TDelphiSemanticSourceLoadResult;
begin
  lFileName := TPath.GetFullPath(aFileName);
  if aSourceCache.TryGetValue(lFileName, lSourceLoad) then
  begin
    aSourceText := lSourceLoad.Source.Text;
    Exit(True);
  end;

  lSourceLoad := TDelphiSemanticSourceLoader.LoadFile(lFileName);
  if not lSourceLoad.Success then
  begin
    if Length(lSourceLoad.Diagnostics) > 0 then
    begin
      lDiagnostic := lSourceLoad.Diagnostics[0];
      AddDiagnostic(aDiagnostics, lDiagnostic.Code, lDiagnostic.Message,
        lDiagnostic.FileName, 0);
    end else
      AddDiagnostic(aDiagnostics, 'SOURCE_FILE_NOT_FOUND',
        'Source file not found: ' + lFileName, lFileName, 0);
    aSourceText := '';
    Exit(False);
  end;

  aSourceText := lSourceLoad.Source.Text;
  aSourceCache.Add(lFileName, lSourceLoad);
  Result := True;
end;

function CurrentActive(const aStack: TList<TPreprocessFrame>): Boolean;
begin
  if aStack.Count = 0 then
    Exit(True);

  Result := aStack[Pred(aStack.Count)].Active;
end;

function IsConditionalDirectiveText(const aDirective: string): Boolean;
var
  lText: string;
begin
  lText := aDirective.Trim;
  Result := StartsText('IFDEF ', lText) or StartsText('IFNDEF ', lText) or
    StartsText('IF ', lText) or StartsText('ELSEIF ', lText) or SameText(lText, 'ELSE') or
    StartsText('ELSE ', lText) or SameText(lText, 'ENDIF') or StartsText('ENDIF ', lText) or
    SameText(lText, 'IFEND') or StartsText('IFEND ', lText);
end;

function MaskDirectiveLookalikes(const aText: string): string;
var
  i: Integer;
  lLexer: TmwBasePasLex;
begin
  Result := aText;
  lLexer := TmwBasePasLex.Create;
  try
    lLexer.UseDefines := False;
    lLexer.Origin := aText;
    while lLexer.TokenID <> ptNull do
    begin
      if lLexer.TokenID in [ptBorComment, ptAnsiComment, ptSlashesComment, ptStringConst] then
        for i := lLexer.TokenPos + 1 to lLexer.TokenPos + lLexer.TokenLen do
          if Result[i] = '$' then
            Result[i] := ' ';
      lLexer.Next;
    end;
  finally
    lLexer.Free;
  end;
end;

function TryExtractDirective(const aLine: string; out aDirective: string;
  out aNeedsCloseBrace: Boolean): Boolean;
var
  lLine: string;
  lStart: Integer;
  lStop: Integer;
begin
  aNeedsCloseBrace := False;
  lLine := aLine;
  lStart := Pos('{$', lLine);
  if lStart > 0 then
  begin
    lStop := PosEx('}', lLine, lStart + 2);
    if lStop > lStart then
    begin
      aDirective := Copy(lLine, lStart + 2, lStop - lStart - 2).Trim;
      Exit(True);
    end;
    aDirective := Copy(lLine, lStart + 2, MaxInt).Trim;
    if IsConditionalDirectiveText(aDirective) then
    begin
      aNeedsCloseBrace := True;
      Exit(True);
    end;
  end;

  lStart := Pos('(*$', lLine);
  if lStart > 0 then
  begin
    lStop := PosEx('*)', lLine, lStart + 3);
    if lStop > lStart then
    begin
      aDirective := Copy(lLine, lStart + 3, lStop - lStart - 3).Trim;
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

function IsCompilerSwitchDirective(const aDirective: string): Boolean;
var
  lText: string;
begin
  lText := aDirective.Trim;
  Result := ((Length(lText) = 2) and CharInSet(UpCase(lText[1]), ['A'..'Z']) and
    CharInSet(lText[2], ['+', '-'])) or StartsText('APPTYPE ', lText) or
    StartsText('LEGACYIFEND ', lText) or StartsText('M ', lText) or StartsText('MESSAGE ', lText) or
    StartsText('ENDREGION', lText) or StartsText('MINENUMSIZE ', lText) or StartsText('MODE ', lText) or
    StartsText('POINTERMATH ', lText) or StartsText('R ', lText) or StartsText('REGION', lText) or
    StartsText('RESOURCE ', lText) or StartsText('RANGECHECKS ', lText) or StartsText('RTTI ', lText) or
    StartsText('SCOPEDENUMS ', lText) or StartsText('SETPEFLAGS ', lText) or
    StartsText('STRONGLINKTYPES ', lText) or StartsText('WARN ', lText) or
    StartsText('WARNINGS ', lText) or StartsText('WEAKLINKRTTI ', lText);
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
  const aSourceCache: TSourceTextCache; var aOutputLineWritten: Boolean): Boolean; forward;

function IsRootSourceFile(const aFileName: string;
  const aOptions: TDelphiSemanticPreprocessOptions): Boolean;
begin
  Result := SameText(TPath.GetFullPath(aOptions.SourceFileName), aFileName);
end;

function FindNextDirectiveStart(const aLine: string; const aStart: Integer): Integer;
var
  lBraceStart: Integer;
  lParenStart: Integer;
begin
  lBraceStart := PosEx('{$', aLine, aStart);
  lParenStart := PosEx('(*$', aLine, aStart);
  if lBraceStart = 0 then
    Exit(lParenStart);
  if lParenStart = 0 then
    Exit(lBraceStart);
  if lBraceStart < lParenStart then
    Result := lBraceStart
  else
    Result := lParenStart;
end;

function FindDirectiveStop(const aLine: string; const aDirectiveStart: Integer): Integer;
begin
  if Copy(aLine, aDirectiveStart, 3) = '(*$' then
    Result := PosEx('*)', aLine, aDirectiveStart + 3) + 1
  else
    Result := PosEx('}', aLine, aDirectiveStart + 2);

  if Result <= 1 then
    Result := 0;
end;

function RemoveInlineDirectivesForDetection(const aLine: string): string;
var
  lDirectiveStart: Integer;
  lDirectiveStop: Integer;
  lPos: Integer;
begin
  Result := '';
  lPos := 1;
  lDirectiveStart := FindNextDirectiveStart(aLine, lPos);
  while lDirectiveStart > 0 do
  begin
    Result := Result + Copy(aLine, lPos, lDirectiveStart - lPos);
    lDirectiveStop := FindDirectiveStop(aLine, lDirectiveStart);
    if lDirectiveStop = 0 then
      Exit(Result);
    lPos := lDirectiveStop + 1;
    lDirectiveStart := FindNextDirectiveStart(aLine, lPos);
  end;
  Result := Result + Copy(aLine, lPos, MaxInt);
end;

function ProcessInlineDirectiveLine(const aLine, aDirectiveLine, aFileName: string; const aLineNumber: Integer;
  const aOptions: TDelphiSemanticPreprocessOptions; const aDefines: TDefineMap;
  const aStack: TList<TPreprocessFrame>; const aDiagnostics:
  TList<TDelphiSemanticPreprocessDiagnostic>; const aOutput: TStringBuilder;
  const aRegions: TList<TDelphiSemanticSourceRegion>; const aIncludes:
  TList<TDelphiSemanticIncludeFile>; const aIncludeStack: TList<string>;
  const aSourceCache: TSourceTextCache): Boolean;
var
  lDirective: string;
  lDirectiveStart: Integer;
  lDirectiveStop: Integer;
  lLineOutput: TStringBuilder;
  lOutputLineWritten: Boolean;
  lPos: Integer;
begin
  Result := True;
  lLineOutput := TStringBuilder.Create;
  try
    lPos := 1;
    lDirectiveStart := FindNextDirectiveStart(aDirectiveLine, lPos);
    while lDirectiveStart > 0 do
    begin
      if CurrentActive(aStack) then
        lLineOutput.Append(Copy(aLine, lPos, lDirectiveStart - lPos))
      else
        lLineOutput.Append(StringOfChar(' ', lDirectiveStart - lPos));

      lDirectiveStop := FindDirectiveStop(aDirectiveLine, lDirectiveStart);
      if lDirectiveStop = 0 then
      begin
        lLineOutput.Append(StringOfChar(' ', Length(aLine) - lDirectiveStart + 1));
        Break;
      end;

      if Copy(aLine, lDirectiveStart, 3) = '(*$' then
        lDirective := Copy(aLine, lDirectiveStart + 3, lDirectiveStop - lDirectiveStart - 4).Trim
      else
        lDirective := Copy(aLine, lDirectiveStart + 2, lDirectiveStop - lDirectiveStart - 2).Trim;

      if IsCompilerSwitchDirective(lDirective) then
      begin
        if CurrentActive(aStack) then
          lLineOutput.Append(Copy(aLine, lDirectiveStart, lDirectiveStop - lDirectiveStart + 1))
        else
          lLineOutput.Append(StringOfChar(' ', lDirectiveStop - lDirectiveStart + 1));
      end else
      begin
        lOutputLineWritten := False;
        if not ProcessDirective(lDirective, aFileName, aLineNumber, aOptions, aDefines,
          aStack, aDiagnostics, lLineOutput, aRegions, aIncludes, aIncludeStack, aSourceCache,
          lOutputLineWritten) then
          Result := False;
        lLineOutput.Append(StringOfChar(' ', lDirectiveStop - lDirectiveStart + 1));
      end;
      lPos := lDirectiveStop + 1;
      lDirectiveStart := FindNextDirectiveStart(aDirectiveLine, lPos);
    end;

    if CurrentActive(aStack) then
      lLineOutput.Append(Copy(aLine, lPos, MaxInt))
    else
      lLineOutput.Append(StringOfChar(' ', Length(aLine) - lPos + 1));
    aOutput.AppendLine(lLineOutput.ToString);
  finally
    lLineOutput.Free;
  end;
end;

procedure ProcessLoadedSourceFile(const aFileName, aSourceText: string;
  const aOptions: TDelphiSemanticPreprocessOptions;
  const aDefines: TDefineMap; const aStack: TList<TPreprocessFrame>;
  const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>; const aOutput: TStringBuilder;
  const aRegions: TList<TDelphiSemanticSourceRegion>; const aIncludes: TList<TDelphiSemanticIncludeFile>;
  const aIncludeStack: TList<string>; const aSourceCache: TSourceTextCache;
  var aSuccess: Boolean);
var
  i: Integer;
  lDirective: string;
  lDirectiveLines: TStringList;
  lDirectiveStart: Integer;
  lDirectiveStop: Integer;
  lLines: TStringList;
  lOutputLineWritten: Boolean;
  lPendingDirectiveCloseBrace: Boolean;
begin
  if IsFileInStack(aIncludeStack, aFileName) then
  begin
    AddDiagnostic(aDiagnostics, 'INCLUDE_CYCLE', 'Include cycle detected: ' + aFileName,
      aFileName, 0);
    aSuccess := False;
    Exit;
  end;

  lLines := TStringList.Create;
  lDirectiveLines := nil;
  try
    lDirectiveLines := TStringList.Create;
    lDirectiveLines.Text := MaskDirectiveLookalikes(aSourceText);
    aIncludeStack.Add(aFileName);
    lLines.Text := aSourceText;
    lPendingDirectiveCloseBrace := False;
    for i := 0 to Pred(lLines.Count) do
    begin
      if lPendingDirectiveCloseBrace and (lLines[i].Trim = '}') then
      begin
        lPendingDirectiveCloseBrace := False;
        aOutput.AppendLine('');
        Continue;
      end;

      if TryExtractDirective(lDirectiveLines[i], lDirective, lPendingDirectiveCloseBrace) then
      begin
        lDirectiveStart := FindNextDirectiveStart(lDirectiveLines[i], 1);
        lDirectiveStop := FindDirectiveStop(lDirectiveLines[i], lDirectiveStart);
        if (RemoveInlineDirectivesForDetection(lDirectiveLines[i]).Trim <> '') or
          ((lDirectiveStop > 0) and
          (FindNextDirectiveStart(lDirectiveLines[i], lDirectiveStop + 1) > 0)) then
        begin
          AddRegion(aRegions, aFileName, i + 1, CurrentActive(aStack));
          if not ProcessInlineDirectiveLine(lLines[i], lDirectiveLines[i], aFileName, i + 1, aOptions, aDefines,
            aStack, aDiagnostics, aOutput, aRegions, aIncludes, aIncludeStack,
            aSourceCache) then
            aSuccess := False;
          Continue;
        end;

        lOutputLineWritten := False;
        if not ProcessDirective(lDirective, aFileName, i + 1, aOptions, aDefines, aStack,
          aDiagnostics, aOutput, aRegions, aIncludes, aIncludeStack, aSourceCache,
          lOutputLineWritten) then
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
    lDirectiveLines.Free;
    lLines.Free;
  end;
end;

procedure ProcessSourceFile(const aFileName: string; const aOptions: TDelphiSemanticPreprocessOptions;
  const aDefines: TDefineMap; const aStack: TList<TPreprocessFrame>;
  const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>; const aOutput: TStringBuilder;
  const aRegions: TList<TDelphiSemanticSourceRegion>; const aIncludes: TList<TDelphiSemanticIncludeFile>;
  const aIncludeStack: TList<string>; const aSourceCache: TSourceTextCache;
  var aSuccess: Boolean);
var
  lText: string;
begin
  if IsRootSourceFile(aFileName, aOptions) and (aOptions.SourceText <> '') then
    lText := aOptions.SourceText
  else if not TryLoadPreprocessSource(aFileName, aSourceCache, aDiagnostics, lText) then
  begin
    aSuccess := False;
    Exit;
  end;

  ProcessLoadedSourceFile(aFileName, lText, aOptions, aDefines, aStack, aDiagnostics,
    aOutput, aRegions, aIncludes, aIncludeStack, aSourceCache, aSuccess);
end;

function ProcessDirective(const aDirective, aFileName: string; const aLine: Integer;
  const aOptions: TDelphiSemanticPreprocessOptions; const aDefines: TDefineMap;
  const aStack: TList<TPreprocessFrame>; const aDiagnostics: TList<TDelphiSemanticPreprocessDiagnostic>;
  const aOutput: TStringBuilder; const aRegions: TList<TDelphiSemanticSourceRegion>;
  const aIncludes: TList<TDelphiSemanticIncludeFile>; const aIncludeStack: TList<string>;
  const aSourceCache: TSourceTextCache; var aOutputLineWritten: Boolean): Boolean;
var
  lActive: Boolean;
  lInclude: TDelphiSemanticIncludeFile;
  lIncludeFileName: string;
  lIncludeName: string;
  lIncludeOutput: TStringBuilder;
  lIncludeText: string;
  lSuccess: Boolean;
  lText: string;
begin
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

  if SameText(lText, 'ELSE') or StartsText('ELSE ', lText) then
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

  if SameText(lText, 'ENDIF') or StartsText('ENDIF ', lText) or SameText(lText, 'IFEND') or
    StartsText('IFEND ', lText) then
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
    if not TryLoadPreprocessSource(lIncludeFileName, aSourceCache, aDiagnostics,
      lIncludeText) then
      Exit(False);
    lInclude.ContentHash := CalculateTextHash(lIncludeText);
    aIncludes.Add(lInclude);
    lSuccess := True;
    lIncludeOutput := TStringBuilder.Create;
    try
      ProcessLoadedSourceFile(lIncludeFileName, lIncludeText, aOptions, aDefines,
        aStack, aDiagnostics, lIncludeOutput, aRegions, aIncludes, aIncludeStack,
        aSourceCache, lSuccess);
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

  if IsCompilerSwitchDirective(lText) then
  begin
    if CurrentActive(aStack) then
    begin
      aOutput.AppendLine('{$' + lText + '}');
      aOutputLineWritten := True;
    end;
    Exit(True);
  end;

  AddDiagnostic(aDiagnostics, 'UNSUPPORTED_PREPROCESS_DIRECTIVE',
    'Unsupported preprocessing directive: ' + aDirective, aFileName, aLine);
  Exit(False);
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
  lSourceCache: TSourceTextCache;
  lSourceLoad: TDelphiSemanticSourceLoadResult;
  lCombined: IDelphiSemanticSourceObservations;
  lObservationError: string;
  lStack: TList<TPreprocessFrame>;
  lSuccess: Boolean;
begin
  Result := Default(TDelphiSemanticPreprocessResult);
  lDefines := nil;
  lDiagnostics := nil;
  lIncludes := nil;
  lIncludeStack := nil;
  lOutput := nil;
  lRegions := nil;
  lSourceCache := nil;
  lStack := nil;
  try
    lDefines := CreateDefineMap(aOptions.Defines);
    lDiagnostics := TList<TDelphiSemanticPreprocessDiagnostic>.Create;
    lIncludes := TList<TDelphiSemanticIncludeFile>.Create;
    lIncludeStack := TList<string>.Create;
    lOutput := TStringBuilder.Create;
    lRegions := TList<TDelphiSemanticSourceRegion>.Create;
    lSourceCache := TSourceTextCache.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
    lStack := TList<TPreprocessFrame>.Create;

    lSuccess := True;
    ProcessSourceFile(TPath.GetFullPath(aOptions.SourceFileName), aOptions, lDefines, lStack,
      lDiagnostics, lOutput, lRegions, lIncludes, lIncludeStack, lSourceCache,
      lSuccess);
    if lStack.Count > 0 then
    begin
      AddDiagnostic(lDiagnostics, 'UNTERMINATED_PREPROCESS_CONDITIONAL',
        'Unterminated conditional directive stack.', aOptions.SourceFileName, 0);
      lSuccess := False;
    end;
    for lSourceLoad in lSourceCache.Values do
      if Result.SourceObservations = nil then
        Result.SourceObservations := lSourceLoad.SourceObservations
      else if TDelphiSemanticSourceEvidence.TryMerge(Result.SourceObservations,
        lSourceLoad.SourceObservations, lCombined, lObservationError) then
        Result.SourceObservations := lCombined
      else begin
        AddDiagnostic(lDiagnostics, lObservationError,
          'Source bytes changed during preprocessing.', aOptions.SourceFileName, 0);
        Result.SourceObservations := nil;
        lSuccess := False;
        Break;
      end;
    Result.Success := lSuccess;
    Result.OutputText := lOutput.ToString;
    Result.IncludeGraphHash := CalculateIncludeGraphHash(lIncludes);
    Result.Regions := lRegions.ToArray;
    Result.Includes := lIncludes.ToArray;
    Result.Diagnostics := lDiagnostics.ToArray;
  finally
    lStack.Free;
    lSourceCache.Free;
    lRegions.Free;
    lOutput.Free;
    lIncludeStack.Free;
    lIncludes.Free;
    lDiagnostics.Free;
    lDefines.Free;
  end;
end;

end.
