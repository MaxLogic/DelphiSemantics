unit DelphiSemantics.SourceContext;

interface

uses
  DelphiSemantics.ProjectContext;

type
  TDelphiSemanticSourceContextSnippet = record
    FileName: string;
    TargetLine: Integer;
    StartLine: Integer;
    Lines: TArray<string>;
  end;

  TDelphiSemanticSourceContext = record
  public
    class function TryParseFindingLocationWithColumn(const aFinding: string; out aFileToken: string;
      out aLine, aColumn: Integer): Boolean; static;
    class function TryResolve(const aProject: TDelphiSemanticProjectInfo; const aFileToken: string;
      const aLine, aContextLines: Integer; out aContext: TDelphiSemanticSourceContextSnippet;
      out aError: string): Boolean; static;
    class function TryResolveCandidate(const aProject: TDelphiSemanticProjectInfo;
      const aFinding: string; const aContextLines: Integer;
      out aContext: TDelphiSemanticSourceContextSnippet; out aToken, aEnclosingSymbol,
      aError: string): Boolean; static;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.Math,
  System.RegularExpressions, System.StrUtils, System.SysUtils,
  DelphiSemantics.Source;

procedure AddCandidate(const aCandidates: TList<string>; const aSeen: TDictionary<string, Boolean>;
  const aValue: string);
var
  lPath: string;
begin
  lPath := aValue.Trim;
  if lPath = '' then
    Exit;

  try
    lPath := TPath.GetFullPath(lPath);
  except
    Exit;
  end;
  if not aSeen.ContainsKey(UpperCase(lPath)) then
  begin
    aSeen.Add(UpperCase(lPath), True);
    aCandidates.Add(lPath);
  end;
end;

function TryResolveSourceFile(const aProject: TDelphiSemanticProjectInfo; const aFileToken: string;
  out aResolvedFileName: string): Boolean;
var
  lBaseName: string;
  lCandidates: TList<string>;
  lFileToken: string;
  lHasDirs: Boolean;
  lPath: string;
  lSearchPath: string;
  lSeen: TDictionary<string, Boolean>;
begin
  aResolvedFileName := '';
  lFileToken := Trim(aFileToken).Replace('/', '\', [rfReplaceAll]);
  if lFileToken = '' then
    Exit(False);

  try
    Result := TPath.IsPathRooted(lFileToken);
  except
    Exit(False);
  end;
  if Result then
  begin
    try
      Result := TFile.Exists(lFileToken);
    except
      Exit(False);
    end;
    if Result then
    begin
      aResolvedFileName := TPath.GetFullPath(lFileToken);
      Exit(True);
    end;
    Exit(False);
  end;

  lHasDirs := (Pos('\', lFileToken) > 0) or (Pos('/', lFileToken) > 0);
  try
    lBaseName := TPath.GetFileName(lFileToken);
  except
    Exit(False);
  end;
  lCandidates := nil;
  lSeen := nil;
  try
    lCandidates := TList<string>.Create;
    lSeen := TDictionary<string, Boolean>.Create;
    AddCandidate(lCandidates, lSeen, TPath.Combine(aProject.ProjectDirectory, lFileToken));
    if aProject.MainSourceFileName <> '' then
      AddCandidate(lCandidates, lSeen, TPath.Combine(ExtractFilePath(aProject.MainSourceFileName),
        lFileToken));

    for lSearchPath in aProject.SearchPaths do
    begin
      AddCandidate(lCandidates, lSeen, TPath.Combine(lSearchPath, lFileToken));
      if lHasDirs then
        AddCandidate(lCandidates, lSeen, TPath.Combine(lSearchPath, lBaseName));
    end;
    AddCandidate(lCandidates, lSeen, lFileToken);

    for lPath in lCandidates do
      if TFile.Exists(lPath) then
      begin
        aResolvedFileName := lPath;
        Exit(True);
      end;
  finally
    lSeen.Free;
    lCandidates.Free;
  end;

  Result := False;
end;

function TryLoadLines(const aFileName: string; const aLines: TStrings): Boolean;
var
  lResult: TDelphiSemanticSourceLoadResult;
begin
  lResult := TDelphiSemanticSourceLoader.LoadFile(aFileName);
  if not lResult.Success then
    Exit(False);

  aLines.Text := lResult.Source.Text;
  Result := True;
end;

function TryReadSourceContext(const aFileName: string; const aLine, aContextLines: Integer;
  out aContext: TDelphiSemanticSourceContextSnippet; out aError: string): Boolean;
var
  i: Integer;
  lEndLine: Integer;
  lLines: TStringList;
  lStartLine: Integer;
begin
  aContext := Default(TDelphiSemanticSourceContextSnippet);
  aError := '';
  if (aFileName = '') or not TFile.Exists(aFileName) then
  begin
    aError := 'Source file not found: ' + aFileName;
    Exit(False);
  end;

  if aLine <= 0 then
  begin
    aError := 'Source line number must be greater than zero.';
    Exit(False);
  end;

  lLines := TStringList.Create;
  try
    if not TryLoadLines(aFileName, lLines) then
    begin
      aError := 'Failed to read source file: ' + aFileName;
      Exit(False);
    end;

    if aLine > lLines.Count then
    begin
      aError := Format('Source line %d is outside %s.', [aLine, aFileName]);
      Exit(False);
    end;

    lStartLine := Max(1, aLine - Max(0, aContextLines));
    lEndLine := Min(lLines.Count, aLine + Max(0, aContextLines));
    aContext.FileName := TPath.GetFullPath(aFileName);
    aContext.TargetLine := aLine;
    aContext.StartLine := lStartLine;
    SetLength(aContext.Lines, lEndLine - lStartLine + 1);
    for i := lStartLine to lEndLine do
      aContext.Lines[i - lStartLine] := lLines[i - 1];
    Result := True;
  finally
    lLines.Free;
  end;
end;

function IsIdentifierChar(const aChar: Char): Boolean;
begin
  Result := (aChar = '_') or CharInSet(aChar, ['A'..'Z', 'a'..'z', '0'..'9']);
end;

function IsPascalKeyword(const aToken: string): Boolean;
begin
  Result := MatchText(aToken, ['begin', 'class', 'const', 'constructor', 'destructor', 'do',
    'else', 'end', 'except', 'finally', 'for', 'function', 'implementation', 'interface',
    'operator', 'procedure', 'record', 'then', 'try', 'unit']);
end;

function TryExtractIdentifierAtColumn(const aLineText: string; const aColumn: Integer;
  out aToken: string): Boolean;
var
  lIndex: Integer;
  lLeft: Integer;
  lRight: Integer;
begin
  aToken := '';
  if (aLineText = '') or (aColumn <= 0) or (aColumn > Length(aLineText) + 1) then
    Exit(False);

  lIndex := aColumn;
  if lIndex > Length(aLineText) then
    Dec(lIndex);
  if not IsIdentifierChar(aLineText[lIndex]) then
  begin
    if (lIndex > 1) and IsIdentifierChar(aLineText[lIndex - 1]) then
      Dec(lIndex)
    else
      Exit(False);
  end;

  lLeft := lIndex;
  while (lLeft > 1) and IsIdentifierChar(aLineText[lLeft - 1]) do
    Dec(lLeft);

  lRight := lIndex;
  while (lRight < Length(aLineText)) and IsIdentifierChar(aLineText[lRight + 1]) do
    Inc(lRight);

  aToken := Copy(aLineText, lLeft, lRight - lLeft + 1);
  Result := (aToken <> '') and not IsPascalKeyword(aToken);
end;

function TryExtractFirstIdentifierFromLine(const aLineText: string; out aToken: string): Boolean;
var
  lIndex: Integer;
  lStart: Integer;
begin
  aToken := '';
  lIndex := 1;
  while lIndex <= Length(aLineText) do
  begin
    if IsIdentifierChar(aLineText[lIndex]) and not CharInSet(aLineText[lIndex], ['0'..'9']) then
    begin
      lStart := lIndex;
      Inc(lIndex);
      while (lIndex <= Length(aLineText)) and IsIdentifierChar(aLineText[lIndex]) do
        Inc(lIndex);
      aToken := Copy(aLineText, lStart, lIndex - lStart);
      if (aToken <> '') and not IsPascalKeyword(aToken) then
        Exit(True);
    end;
    Inc(lIndex);
  end;
  Result := False;
end;

function TryExtractEnclosingSymbolFromLine(const aLineText: string; out aSymbol: string): Boolean;
var
  lMatch: TMatch;
begin
  aSymbol := '';
  lMatch := TRegEx.Match(aLineText,
    '^\s*(?:class\s+)?(?:procedure|function|constructor|destructor)\s+([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)',
    [roIgnoreCase]);
  if not lMatch.Success then
  begin
    lMatch := TRegEx.Match(aLineText, '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*class\b',
      [roIgnoreCase]);
    if not lMatch.Success then
      Exit(False);
  end;

  aSymbol := lMatch.Groups[1].Value;
  Result := aSymbol <> '';
end;

function TryExtractQuotedIdentifier(const aFinding: string; out aIdentifier: string): Boolean;
var
  lMatch: TMatch;
begin
  aIdentifier := '';
  lMatch := TRegEx.Match(aFinding, '''([A-Za-z_][A-Za-z0-9_]*)''');
  if not lMatch.Success then
    Exit(False);

  aIdentifier := lMatch.Groups[1].Value;
  Result := aIdentifier <> '';
end;

function TryFindIdentifierInContext(const aContext: TDelphiSemanticSourceContextSnippet;
  const aIdentifier: string; out aCandidate: string): Boolean;
var
  lLineText: string;
  lPattern: string;
begin
  aCandidate := '';
  if aIdentifier = '' then
    Exit(False);

  lPattern := '\b' + TRegEx.Escape(aIdentifier) + '\b';
  for lLineText in aContext.Lines do
    if TRegEx.IsMatch(lLineText, lPattern) then
    begin
      aCandidate := aIdentifier;
      Exit(True);
    end;

  Result := False;
end;

class function TDelphiSemanticSourceContext.TryParseFindingLocationWithColumn(
  const aFinding: string; out aFileToken: string; out aLine, aColumn: Integer): Boolean;
var
  lMatch: TMatch;
begin
  aFileToken := '';
  aLine := 0;
  aColumn := 0;
  lMatch := TRegEx.Match(aFinding, '^(.+)\((\d+)(?:,(\d+))?\):');
  if not lMatch.Success then
    Exit(False);

  aFileToken := Trim(lMatch.Groups[1].Value);
  aLine := StrToIntDef(lMatch.Groups[2].Value, 0);
  if lMatch.Groups.Count >= 4 then
    aColumn := StrToIntDef(lMatch.Groups[3].Value, 0);
  Result := (aFileToken <> '') and (aLine > 0) and (aColumn >= 0);
end;

class function TDelphiSemanticSourceContext.TryResolve(const aProject: TDelphiSemanticProjectInfo;
  const aFileToken: string; const aLine, aContextLines: Integer;
  out aContext: TDelphiSemanticSourceContextSnippet; out aError: string): Boolean;
var
  lResolvedFileName: string;
begin
  aContext := Default(TDelphiSemanticSourceContextSnippet);
  aError := '';
  if not TryResolveSourceFile(aProject, aFileToken, lResolvedFileName) then
  begin
    aError := 'Could not resolve source file: ' + aFileToken;
    Exit(False);
  end;
  Result := TryReadSourceContext(lResolvedFileName, aLine, aContextLines, aContext, aError);
end;

class function TDelphiSemanticSourceContext.TryResolveCandidate(
  const aProject: TDelphiSemanticProjectInfo; const aFinding: string; const aContextLines: Integer;
  out aContext: TDelphiSemanticSourceContextSnippet; out aToken, aEnclosingSymbol,
  aError: string): Boolean;
var
  lColumn: Integer;
  lFileToken: string;
  lIndex: Integer;
  lLine: Integer;
  lLineText: string;
begin
  aContext := Default(TDelphiSemanticSourceContextSnippet);
  aToken := '';
  aEnclosingSymbol := '';
  aError := '';
  if not TryParseFindingLocationWithColumn(aFinding, lFileToken, lLine, lColumn) then
  begin
    aError := 'Could not parse compiler failure location: ' + aFinding;
    Exit(False);
  end;

  if not TryResolve(aProject, lFileToken, lLine, aContextLines, aContext, aError) then
    Exit(False);

  lIndex := aContext.TargetLine - aContext.StartLine;
  if (lIndex < 0) or (lIndex > High(aContext.Lines)) then
  begin
    aError := Format('Could not derive enrichment candidate from %s(%d,%d).',
      [lFileToken, lLine, lColumn]);
    Exit(False);
  end;

  lLineText := aContext.Lines[lIndex];
  if (lColumn > 0) and TryExtractIdentifierAtColumn(lLineText, lColumn, aToken) then
    Exit(True);
  if TryExtractQuotedIdentifier(aFinding, aToken) and TryFindIdentifierInContext(aContext, aToken,
    aToken) then
    Exit(True);
  if TryExtractFirstIdentifierFromLine(lLineText, aToken) then
    Exit(True);

  while lIndex >= 0 do
  begin
    if TryExtractEnclosingSymbolFromLine(aContext.Lines[lIndex], aEnclosingSymbol) then
      Exit(True);
    Dec(lIndex);
  end;

  aError := Format('Could not derive enrichment candidate from %s(%d,%d).',
    [lFileToken, lLine, lColumn]);
  Result := False;
end;

end.
