unit DelphiSemantics.IdentifierScope;

interface

uses
  DelphiSemantics.ProjectContext;

type
  TDelphiSemanticIdentifierScopeResult = record
    UseScopedAnalysis: Boolean;
    SourceFileNames: TArray<string>;
    CandidateScanMilliseconds: Int64;
    FullModelCount: Integer;
    LeanModelCount: Integer;
    FailOpen: Boolean;
    FailOpenReason: string;
  end;

  TDelphiSemanticIdentifierCandidateCollector = record
  public
    class function Collect(const aProject: TDelphiSemanticProjectInfo;
      const aSourceFileNames: TArray<string>; const aIdentifier: string):
      TDelphiSemanticIdentifierScopeResult; static;
  end;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.IOUtils,
  System.StrUtils, System.SysUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source,
  MaxLogic.StrUtils;

type
  TIdentifierAliasPair = record
    LeftName: string;
    RightName: string;
  end;

function IsAsciiIdentifierStart(const aChar: Char): Boolean;
begin
  Result := (aChar = '_') or CharInSet(aChar, ['A'..'Z']) or
    CharInSet(aChar, ['a'..'z']);
end;

function IsAsciiIdentifierChar(const aChar: Char): Boolean;
begin
  Result := IsAsciiIdentifierStart(aChar) or CharInSet(aChar, ['0'..'9']);
end;

function IsSimpleAsciiIdentifier(const aText: string): Boolean;
var
  i: Integer;
begin
  Result := (aText <> '') and IsAsciiIdentifierStart(aText[1]);
  if not Result then
    Exit;
  for i := 2 to Length(aText) do
  begin
    if not IsAsciiIdentifierChar(aText[i]) then
      Exit(False);
  end;
end;

function IsQualifiedAsciiIdentifier(const aText: string): Boolean;
var
  i: Integer;
  lAtStart: Boolean;
begin
  Result := aText <> '';
  if not Result then
    Exit;
  lAtStart := True;
  for i := 1 to Length(aText) do
  begin
    if aText[i] = '.' then
    begin
      if lAtStart then
        Exit(False);
      lAtStart := True;
      Continue;
    end;
    if lAtStart then
    begin
      if not IsAsciiIdentifierStart(aText[i]) then
        Exit(False);
      lAtStart := False;
    end else if not IsAsciiIdentifierChar(aText[i]) then
      Exit(False);
  end;
  Result := not lAtStart;
end;

function UnqualifiedIdentifier(const aText: string): string;
var
  lSeparator: Integer;
begin
  lSeparator := LastDelimiter('.', aText);
  if lSeparator > 0 then
    Result := Copy(aText, lSeparator + 1, MaxInt)
  else
    Result := aText;
end;

function SameAsciiTextAt(const aText: string; const aStart: Integer;
  const aCandidate: string): Boolean;
var
  i: Integer;
  lLeft: Char;
  lRight: Char;
begin
  Result := False;
  if (aStart < 1) or
    (aStart + Length(aCandidate) - 1 > Length(aText)) then
    Exit;
  for i := 1 to Length(aCandidate) do
  begin
    lLeft := aText[aStart + i - 1];
    lRight := aCandidate[i];
    if CharInSet(lLeft, ['a'..'z']) then
      Dec(lLeft, Ord('a') - Ord('A'));
    if CharInSet(lRight, ['a'..'z']) then
      Dec(lRight, Ord('a') - Ord('A'));
    if lLeft <> lRight then
      Exit;
  end;
  Result := True;
end;

function TokenMatchesCandidate(const aText: string; const aStart,
  aLength: Integer; const aCandidates: TArray<string>): Boolean;
var
  lCandidate: string;
begin
  for lCandidate in aCandidates do
  begin
    if (Length(lCandidate) = aLength) and
      SameAsciiTextAt(aText, aStart, lCandidate) then
      Exit(True);
  end;
  Result := False;
end;

procedure SkipQuotedString(const aText: string; var aIndex: Integer);
begin
  Inc(aIndex);
  while aIndex <= Length(aText) do
  begin
    if aText[aIndex] <> '''' then
    begin
      Inc(aIndex);
      Continue;
    end;
    if (aIndex < Length(aText)) and (aText[aIndex + 1] = '''') then
      Inc(aIndex, 2)
    else
    begin
      Inc(aIndex);
      Exit;
    end;
  end;
end;

procedure SkipLineComment(const aText: string; var aIndex: Integer);
begin
  Inc(aIndex, 2);
  while (aIndex <= Length(aText)) and
    (not CharInSet(aText[aIndex], [#10, #13])) do
    Inc(aIndex);
end;

procedure SkipBraceComment(const aText: string; var aIndex: Integer);
begin
  Inc(aIndex);
  while (aIndex <= Length(aText)) and (aText[aIndex] <> '}') do
    Inc(aIndex);
  if aIndex <= Length(aText) then
    Inc(aIndex);
end;

procedure SkipParenthesisComment(const aText: string; var aIndex: Integer);
begin
  Inc(aIndex, 2);
  while (aIndex < Length(aText)) and
    (not ((aText[aIndex] = '*') and (aText[aIndex + 1] = ')'))) do
    Inc(aIndex);
  if aIndex < Length(aText) then
    Inc(aIndex, 2)
  else
    Inc(aIndex);
end;

function SkipNonCode(const aText: string; var aIndex: Integer): Boolean;
begin
  Result := True;
  if aText[aIndex] = '''' then
    SkipQuotedString(aText, aIndex)
  else if (aText[aIndex] = '/') and (aIndex < Length(aText)) and
    (aText[aIndex + 1] = '/') then
    SkipLineComment(aText, aIndex)
  else if aText[aIndex] = '{' then
    SkipBraceComment(aText, aIndex)
  else if (aText[aIndex] = '(') and (aIndex < Length(aText)) and
    (aText[aIndex + 1] = '*') then
    SkipParenthesisComment(aText, aIndex)
  else
    Result := False;
end;

function ContainsCandidateToken(const aText: string;
  const aCandidates: TArray<string>): Boolean;
var
  i: Integer;
  lStart: Integer;
begin
  i := 1;
  while i <= Length(aText) do
  begin
    if SkipNonCode(aText, i) then
      Continue;
    if not IsAsciiIdentifierStart(aText[i]) then
    begin
      Inc(i);
      Continue;
    end;
    lStart := i;
    Inc(i);
    while (i <= Length(aText)) and IsAsciiIdentifierChar(aText[i]) do
      Inc(i);
    if TokenMatchesCandidate(aText, lStart, i - lStart, aCandidates) then
      Exit(True);
  end;
  Result := False;
end;

procedure SetFailOpen(var aResult: TDelphiSemanticIdentifierScopeResult;
  const aReason: string; const aSourceCount: Integer);
begin
  aResult.UseScopedAnalysis := False;
  aResult.SourceFileNames := nil;
  aResult.FullModelCount := aSourceCount;
  aResult.LeanModelCount := 0;
  aResult.FailOpen := True;
  aResult.FailOpenReason := aReason;
end;

procedure SetScopedResult(var aResult: TDelphiSemanticIdentifierScopeResult;
  const aFullSourceFiles: TList<string>; const aSourceCount: Integer);
begin
  aResult.UseScopedAnalysis := True;
  aResult.SourceFileNames := aFullSourceFiles.ToArray;
  aResult.FullModelCount := aFullSourceFiles.Count;
  aResult.LeanModelCount := aSourceCount - aFullSourceFiles.Count;
  aResult.FailOpen := False;
  aResult.FailOpenReason := '';
end;

function AliasSideMatches(const aCandidates: TDictionary<string, Byte>;
  const aName: string): Boolean;
begin
  Result := aCandidates.ContainsKey(aName) or
    aCandidates.ContainsKey(UnqualifiedIdentifier(aName));
end;

function TryParseAlias(const aAlias: string;
  out aPair: TIdentifierAliasPair): Boolean;
var
  lEqualsAt: Integer;
begin
  aPair := Default(TIdentifierAliasPair);
  lEqualsAt := Pos('=', aAlias);
  if (lEqualsAt <= 1) or (lEqualsAt >= Length(aAlias)) or
    (PosEx('=', aAlias, lEqualsAt + 1) > 0) then
    Exit(False);
  aPair.LeftName := Trim(Copy(aAlias, 1, lEqualsAt - 1));
  aPair.RightName := Trim(Copy(aAlias, lEqualsAt + 1, MaxInt));
  Result := IsQualifiedAsciiIdentifier(aPair.LeftName) and
    IsQualifiedAsciiIdentifier(aPair.RightName);
end;

function TryCollectAliasPairs(const aProject: TDelphiSemanticProjectInfo;
  out aPairs: TArray<TIdentifierAliasPair>): Boolean;
var
  lAlias: string;
  lExistingRight: string;
  lPair: TIdentifierAliasPair;
  lPairs: TList<TIdentifierAliasPair>;
  lRightByLeft: TDictionary<string, string>;
begin
  aPairs := nil;
  lPairs := nil;
  lRightByLeft := nil;
  try
    lPairs := TList<TIdentifierAliasPair>.Create;
    lRightByLeft := TDictionary<string, string>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    for lAlias in aProject.UnitAliases do
    begin
      if not TryParseAlias(lAlias, lPair) then
        Exit(False);
      if lRightByLeft.TryGetValue(lPair.LeftName, lExistingRight) and
        (not SameText(lExistingRight, lPair.RightName)) then
        Exit(False);
      lRightByLeft.AddOrSetValue(lPair.LeftName, lPair.RightName);
      lPairs.Add(lPair);
    end;
    aPairs := lPairs.ToArray;
    Result := True;
  finally
    lRightByLeft.Free;
    lPairs.Free;
  end;
end;

function AddCandidateName(const aMap: TDictionary<string, Byte>;
  const aNames: TList<string>; const aName: string): Boolean;
var
  lName: string;
begin
  lName := UnqualifiedIdentifier(aName);
  Result := not aMap.ContainsKey(lName);
  if Result then
  begin
    aMap.Add(lName, 0);
    aNames.Add(lName);
  end;
end;

function ExpandCandidateNames(const aIdentifier: string;
  const aAliases: TArray<TIdentifierAliasPair>): TArray<string>;
var
  lCandidateMap: TDictionary<string, Byte>;
  lCandidateNames: TList<string>;
  lChanged: Boolean;
  lPair: TIdentifierAliasPair;
begin
  lCandidateMap := nil;
  lCandidateNames := nil;
  try
    lCandidateMap := TDictionary<string, Byte>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    lCandidateNames := TList<string>.Create;
    lCandidateMap.Add(aIdentifier, 0);
    lCandidateNames.Add(aIdentifier);
    repeat
      lChanged := False;
      for lPair in aAliases do
      begin
        if AliasSideMatches(lCandidateMap, lPair.RightName) then
          lChanged := AddCandidateName(lCandidateMap, lCandidateNames,
            lPair.LeftName) or lChanged;
        if AliasSideMatches(lCandidateMap, lPair.LeftName) then
          lChanged := AddCandidateName(lCandidateMap, lCandidateNames,
            lPair.RightName) or lChanged;
      end;
    until not lChanged;
    Result := lCandidateNames.ToArray;
  finally
    lCandidateNames.Free;
    lCandidateMap.Free;
  end;
end;

function TryBuildCandidateNames(const aProject: TDelphiSemanticProjectInfo;
  const aIdentifier: string; out aCandidates: TArray<string>;
  out aFailOpenReason: string): Boolean;
var
  lAliases: TArray<TIdentifierAliasPair>;
begin
  aCandidates := nil;
  aFailOpenReason := '';
  if not IsSimpleAsciiIdentifier(aIdentifier) then
  begin
    aFailOpenReason := 'identifier-not-simple-ascii';
    Exit(False);
  end;
  if not TryCollectAliasPairs(aProject, lAliases) then
  begin
    aFailOpenReason := 'ambiguous-unit-alias';
    Exit(False);
  end;
  aCandidates := ExpandCandidateNames(aIdentifier, lAliases);
  Result := True;
end;

procedure AddUniquePath(const aPaths: TList<string>;
  const aSeen: TDictionary<string, Byte>; const aPath: string);
var
  lPath: string;
begin
  if Trim(aPath) = '' then
    Exit;
  lPath := TPath.GetFullPath(aPath);
  if aSeen.ContainsKey(lPath) then
    Exit;
  aSeen.Add(lPath, 0);
  aPaths.Add(lPath);
end;

function CandidateSearchPaths(const aProject: TDelphiSemanticProjectInfo;
  const aSourceFileNames: TArray<string>): TArray<string>;
var
  lFileName: string;
  lPath: string;
  lPaths: TList<string>;
  lSeen: TDictionary<string, Byte>;
begin
  lPaths := nil;
  lSeen := nil;
  try
    lPaths := TList<string>.Create;
    lSeen := TDictionary<string, Byte>.Create(
      TFastCaseAwareComparer.OrdinalIgnoreCase);
    AddUniquePath(lPaths, lSeen, aProject.ProjectDirectory);
    for lPath in aProject.IncludePaths do
      AddUniquePath(lPaths, lSeen, lPath);
    for lPath in aProject.SourceLookupPaths do
      AddUniquePath(lPaths, lSeen, lPath);
    for lFileName in aSourceFileNames do
      AddUniquePath(lPaths, lSeen, TPath.GetDirectoryName(lFileName));
    Result := lPaths.ToArray;
  finally
    lSeen.Free;
    lPaths.Free;
  end;
end;

function IncludePathIsAmbiguous(const aIncludeFileName: string;
  const aSearchPaths: TArray<string>): Boolean;
var
  lCandidate: string;
  lFileName: string;
  lFound: TDictionary<string, Byte>;
  lPath: string;
begin
  lFound := TDictionary<string, Byte>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lFileName := TPath.GetFileName(aIncludeFileName);
    lFound.AddOrSetValue(TPath.GetFullPath(aIncludeFileName), 0);
    for lPath in aSearchPaths do
    begin
      lCandidate := TPath.Combine(lPath, lFileName);
      if TFile.Exists(lCandidate) then
        lFound.AddOrSetValue(TPath.GetFullPath(lCandidate), 0);
    end;
    Result := lFound.Count > 1;
  finally
    lFound.Free;
  end;
end;

function SourceUsesSupportedEncoding(
  const aSource: TDelphiSemanticSourceLoadResult): Boolean;
begin
  Result := aSource.Success and MatchText(aSource.Source.EncodingName,
    ['utf-8', 'windows-1252']);
end;

function TryScanSourceFile(const aProject: TDelphiSemanticProjectInfo;
  const aFileName: string; const aSearchPaths, aCandidates: TArray<string>;
  out aIsCandidate: Boolean; out aFailOpenReason: string): Boolean;
var
  lInclude: TDelphiSemanticIncludeFile;
  lIncludeSource: TDelphiSemanticSourceLoadResult;
  lOptions: TDelphiSemanticPreprocessOptions;
  lPreprocess: TDelphiSemanticPreprocessResult;
  lSource: TDelphiSemanticSourceLoadResult;
begin
  aIsCandidate := False;
  aFailOpenReason := '';
  try
    lSource := TDelphiSemanticSourceLoader.LoadFile(aFileName);
    if not SourceUsesSupportedEncoding(lSource) then
    begin
      aFailOpenReason := 'unsupported-or-unreadable-source';
      Exit(False);
    end;

    lOptions := Default(TDelphiSemanticPreprocessOptions);
    lOptions.SourceFileName := aFileName;
    lOptions.SourceText := lSource.Source.Text;
    lOptions.Defines := aProject.Defines;
    lOptions.SearchPaths := aSearchPaths;
    lPreprocess := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
    if not lPreprocess.Success then
    begin
      aFailOpenReason := 'ambiguous-or-unreadable-include';
      Exit(False);
    end;
    for lInclude in lPreprocess.Includes do
    begin
      if IncludePathIsAmbiguous(lInclude.FileName, aSearchPaths) then
      begin
        aFailOpenReason := 'ambiguous-include';
        Exit(False);
      end;
      lIncludeSource := TDelphiSemanticSourceLoader.LoadFile(lInclude.FileName);
      if not SourceUsesSupportedEncoding(lIncludeSource) then
      begin
        aFailOpenReason := 'unsupported-include-encoding';
        Exit(False);
      end;
    end;
    aIsCandidate := ContainsCandidateToken(lPreprocess.OutputText, aCandidates);
    Result := True;
  except
    on E: Exception do
    begin
      aFailOpenReason := 'source-scan-exception:' + E.ClassName;
      Result := False;
    end;
  end;
end;

class function TDelphiSemanticIdentifierCandidateCollector.Collect(
  const aProject: TDelphiSemanticProjectInfo;
  const aSourceFileNames: TArray<string>; const aIdentifier: string):
  TDelphiSemanticIdentifierScopeResult;
var
  lCandidates: TArray<string>;
  lFailOpenReason: string;
  lFileName: string;
  lFullSourceFiles: TList<string>;
  lIsCandidate: Boolean;
  lSearchPaths: TArray<string>;
  lStopwatch: TStopwatch;
begin
  Result := Default(TDelphiSemanticIdentifierScopeResult);
  lFullSourceFiles := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    try
      if not TryBuildCandidateNames(aProject, aIdentifier, lCandidates,
        lFailOpenReason) then
      begin
        SetFailOpen(Result, lFailOpenReason, Length(aSourceFileNames));
        Exit;
      end;

      lSearchPaths := CandidateSearchPaths(aProject, aSourceFileNames);
      lFullSourceFiles := TList<string>.Create;
      for lFileName in aSourceFileNames do
      begin
        if not TryScanSourceFile(aProject, lFileName, lSearchPaths,
          lCandidates, lIsCandidate, lFailOpenReason) then
        begin
          SetFailOpen(Result, lFailOpenReason,
            Length(aSourceFileNames));
          Exit;
        end;
        if lIsCandidate then
          lFullSourceFiles.Add(lFileName);
      end;

      SetScopedResult(Result, lFullSourceFiles, Length(aSourceFileNames));
    except
      on E: Exception do
        SetFailOpen(Result, 'identifier-scope-exception:' + E.ClassName,
          Length(aSourceFileNames));
    end;
  finally
    lStopwatch.Stop;
    Result.CandidateScanMilliseconds := lStopwatch.ElapsedMilliseconds;
    lFullSourceFiles.Free;
  end;
end;

end.
