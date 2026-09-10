unit DelphiSemantics.SourceContext;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.ProjectContext;

type
  TDelphiSemanticSourceFile = record
    FileName: string;
    Text: string;
    LowerText: string;
    LineBreak: string;
    Lines: TArray<string>;
  end;

  TDelphiSemanticSourceContextSnippet = record
    FileName: string;
    TargetLine: Integer;
    StartLine: Integer;
    Lines: TArray<string>;
  end;

  TDelphiSemanticSourceContextCache = class
  private
    type
{$IFDEF MSWINDOWS}
      TSourceTimestamp = UInt64;
{$ELSE}
      TSourceTimestamp = TDateTime;
{$ENDIF}
      TCacheEntry = record
        LastWriteTimeUtc: TSourceTimestamp;
        Size: Int64;
        Source: TDelphiSemanticSourceFile;
      end;
    var
      fFiles: TDictionary<string, TCacheEntry>;
    class function CacheKey(const aFileName: string): string; static;
  public
    constructor Create;
    destructor Destroy; override;
    function TryLoad(const aFileName: string; out aSource: TDelphiSemanticSourceFile;
      out aError: string): Boolean;
    function TryGetValue(const aFileName: string; out aLines: TArray<string>): Boolean;
    function TryGetLine(const aFileName: string; const aLine: Integer;
      out aLineText: string): Boolean;
    function TryExtractRange(const aFileName: string; const aStartLine,
      aStartColumn, aEndLine, aEndColumn: Integer; out aText: string): Boolean;
    function LineHasConditionalDirective(const aFileName: string;
      const aLine: Integer): Boolean;
    function InsideInactiveNeverConditionalRegion(const aFileName: string;
      const aStartLine, aLine: Integer): Boolean;
    function LineBreakForFile(const aFileName: string): string;
  end;

  TDelphiSemanticSourceContext = record
  public
    class function TryParseFindingLocationWithColumn(const aFinding: string; out aFileToken: string;
      out aLine, aColumn: Integer): Boolean; static;
    class function TryResolve(const aProject: TDelphiSemanticProjectInfo; const aFileToken: string;
      const aLine, aContextLines: Integer; out aContext: TDelphiSemanticSourceContextSnippet;
      out aError: string): Boolean; overload; static;
    class function TryResolve(const aProject: TDelphiSemanticProjectInfo; const aFileToken: string;
      const aLine, aContextLines: Integer; const aCache: TDelphiSemanticSourceContextCache;
      out aContext: TDelphiSemanticSourceContextSnippet; out aError: string): Boolean; overload; static;
    class function TryResolveCandidate(const aProject: TDelphiSemanticProjectInfo;
      const aFinding: string; const aContextLines: Integer;
      out aContext: TDelphiSemanticSourceContextSnippet; out aToken, aEnclosingSymbol,
      aError: string): Boolean; overload; static;
    class function TryResolveCandidate(const aProject: TDelphiSemanticProjectInfo;
      const aFinding: string; const aContextLines: Integer; const aCache: TDelphiSemanticSourceContextCache;
      out aContext: TDelphiSemanticSourceContextSnippet; out aToken, aEnclosingSymbol,
      aError: string): Boolean; overload; static;
    class function TryResolveCandidate(const aProject: TDelphiSemanticProjectInfo; const aFileToken: string;
      const aLine, aColumn, aContextLines: Integer; const aCandidateText: string;
      const aCache: TDelphiSemanticSourceContextCache; out aContext: TDelphiSemanticSourceContextSnippet;
      out aToken, aEnclosingSymbol, aError: string): Boolean; overload; static;
    class function FormatLines(const aContext: TDelphiSemanticSourceContextSnippet): TArray<string>; static;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.Math,
  System.SysUtils,
{$IFDEF MSWINDOWS}
  Winapi.Windows,
{$ENDIF}
  DelphiSemantics.Source, DelphiSemantics.SourceConditionals,
  DelphiSemantics.SourceContext.Candidates;

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

class function TDelphiSemanticSourceContextCache.CacheKey(
  const aFileName: string): string;
begin
  Result := UpperCase(TPath.GetFullPath(aFileName));
end;

constructor TDelphiSemanticSourceContextCache.Create;
begin
  inherited Create;
  fFiles := TDictionary<string, TCacheEntry>.Create;
end;

destructor TDelphiSemanticSourceContextCache.Destroy;
begin
  fFiles.Free;
  inherited;
end;

function TryReadSourceMetadata(const aFileName: string;
  out aTimestampUtc: TDelphiSemanticSourceContextCache.TSourceTimestamp;
  out aSize: Int64): Boolean;
{$IFDEF MSWINDOWS}
var
  h: THandle;
  lHandleInfo: TByHandleFileInformation;
  lInfo: TWin32FileAttributeData;
  lPath: string;
begin
  aTimestampUtc := 0;
  aSize := 0;
  if aFileName = '' then
    Exit(False);
  lPath := aFileName;
  if (Length(lPath) >= MAX_PATH) and not TPath.IsExtendedPrefixed(lPath) then
  begin
    try
      lPath := TPath.GetFullPath(lPath);
    except
      on E: EArgumentException do
        Exit(False); // Invalid paths remain failed lookups, as with FileExists.
    end;
    if lPath.StartsWith('\\') then
      lPath := '\\?\UNC\' + Copy(lPath, 3, MaxInt)
    else
      lPath := '\\?\' + lPath;
  end;
  if not GetFileAttributesEx(PChar(lPath), GetFileExInfoStandard, @lInfo) then
    Exit(False);
  if (lInfo.dwFileAttributes and FILE_ATTRIBUTE_DIRECTORY) <> 0 then
    Exit(False);
  if (lInfo.dwFileAttributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0 then
  begin
    // Observe the opened target, so editing it invalidates cached linked source.
    h := CreateFile(PChar(lPath), FILE_READ_ATTRIBUTES,
      FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil,
      OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
    if h = INVALID_HANDLE_VALUE then
      Exit(False);
    try
      if not GetFileInformationByHandle(h, lHandleInfo) then
        Exit(False);
      lInfo.ftLastWriteTime := lHandleInfo.ftLastWriteTime;
      lInfo.nFileSizeHigh := lHandleInfo.nFileSizeHigh;
      lInfo.nFileSizeLow := lHandleInfo.nFileSizeLow;
    finally
      CloseHandle(h);
    end;
  end;
  aTimestampUtc := (UInt64(lInfo.ftLastWriteTime.dwHighDateTime) shl 32) or
    lInfo.ftLastWriteTime.dwLowDateTime;
  aSize := (Int64(lInfo.nFileSizeHigh) shl 32) or lInfo.nFileSizeLow;
  Result := True;
end;
{$ELSE}
begin
  aTimestampUtc := 0;
  aSize := 0;
  Result := (aFileName <> '') and TFile.Exists(aFileName);
  if Result then
  begin
    aTimestampUtc := TFile.GetLastWriteTimeUtc(aFileName);
    aSize := TFile.GetSize(aFileName);
  end;
end;
{$ENDIF}

function TDelphiSemanticSourceContextCache.TryLoad(const aFileName: string;
  out aSource: TDelphiSemanticSourceFile; out aError: string): Boolean;
var
  lEntry: TCacheEntry;
  lKey: string;
  lLines: TStringList;
  lResult: TDelphiSemanticSourceLoadResult;
  lSize: Int64;
  lTimestampUtc: TSourceTimestamp;
begin
  aSource := Default(TDelphiSemanticSourceFile);
  aError := '';
  if not TryReadSourceMetadata(aFileName, lTimestampUtc, lSize) then
  begin
    aError := 'Source file not found: ' + aFileName;
    Exit(False);
  end;

  lKey := CacheKey(aFileName);
  if fFiles.TryGetValue(lKey, lEntry) and
    (lEntry.LastWriteTimeUtc = lTimestampUtc) and (lEntry.Size = lSize) then
  begin
    aSource := lEntry.Source;
    Exit(True);
  end;

  lResult := TDelphiSemanticSourceLoader.LoadFile(aFileName);
  if not lResult.Success then
  begin
    aError := 'Failed to read source file: ' + aFileName;
    Exit(False);
  end;

  aSource.FileName := TPath.GetFullPath(aFileName);
  aSource.Text := lResult.Source.Text;
  aSource.LowerText := LowerCase(aSource.Text);
  aSource.LineBreak := lResult.Source.LineBreak;
  lLines := TStringList.Create;
  try
    lLines.Text := aSource.Text;
    aSource.Lines := lLines.ToStringArray;
  finally
    lLines.Free;
  end;

  lEntry.LastWriteTimeUtc := lTimestampUtc;
  lEntry.Size := lSize;
  lEntry.Source := aSource;
  fFiles.AddOrSetValue(lKey, lEntry);
  Result := True;
end;

function TDelphiSemanticSourceContextCache.TryGetLine(const aFileName: string;
  const aLine: Integer; out aLineText: string): Boolean;
var
  lError: string;
  lSource: TDelphiSemanticSourceFile;
begin
  aLineText := '';
  if (aLine <= 0) or (not TryLoad(aFileName, lSource, lError)) or
    (aLine > Length(lSource.Lines)) then
    Exit(False);
  aLineText := lSource.Lines[aLine - 1];
  Result := True;
end;

function TDelphiSemanticSourceContextCache.TryGetValue(const aFileName: string;
  out aLines: TArray<string>): Boolean;
var
  lError: string;
  lSource: TDelphiSemanticSourceFile;
begin
  aLines := nil;
  if not TryLoad(aFileName, lSource, lError) then
    Exit(False);
  aLines := lSource.Lines;
  Result := True;
end;

function TDelphiSemanticSourceContextCache.TryExtractRange(const aFileName: string;
  const aStartLine, aStartColumn, aEndLine, aEndColumn: Integer;
  out aText: string): Boolean;
var
  lBuilder: TStringBuilder;
  lEndColumn: Integer;
  lError: string;
  lLine: string;
  lLineIndex: Integer;
  lSource: TDelphiSemanticSourceFile;
  lStartColumn: Integer;
begin
  aText := '';
  if (aStartLine <= 0) or (aEndLine <= 0) or
    (not TryLoad(aFileName, lSource, lError)) or
    (aStartLine > Length(lSource.Lines)) or (aEndLine > Length(lSource.Lines)) then
    Exit(False);

  lBuilder := TStringBuilder.Create;
  try
    for lLineIndex := aStartLine to aEndLine do
    begin
      lLine := lSource.Lines[lLineIndex - 1];
      lStartColumn := 1;
      if lLineIndex = aStartLine then
        lStartColumn := aStartColumn;
      lEndColumn := Length(lLine) + 1;
      if lLineIndex = aEndLine then
        lEndColumn := aEndColumn;
      if lStartColumn < 1 then
        lStartColumn := 1;
      if lStartColumn > Length(lLine) + 1 then
        lStartColumn := Length(lLine) + 1;
      if lEndColumn < lStartColumn then
        lEndColumn := lStartColumn;
      if lEndColumn > Length(lLine) then
        lEndColumn := Length(lLine);
      if lStartColumn <= Length(lLine) then
        lBuilder.Append(Copy(lLine, lStartColumn, lEndColumn - lStartColumn + 1));
      if lLineIndex < aEndLine then
        lBuilder.Append(lSource.LineBreak);
    end;
    aText := lBuilder.ToString;
    Result := True;
  finally
    lBuilder.Free;
  end;
end;

function TDelphiSemanticSourceContextCache.LineHasConditionalDirective(
  const aFileName: string; const aLine: Integer): Boolean;
var
  lLines: TArray<string>;
begin
  Result := TryGetValue(aFileName, lLines) and
    TDelphiSemanticSourceConditionals.LineHasConditionalDirective(lLines, aLine);
end;

function TDelphiSemanticSourceContextCache.InsideInactiveNeverConditionalRegion(
  const aFileName: string; const aStartLine, aLine: Integer): Boolean;
var
  lLines: TArray<string>;
begin
  Result := TryGetValue(aFileName, lLines) and
    TDelphiSemanticSourceConditionals.InsideInactiveNeverConditionalRegion(lLines,
    aStartLine, aLine);
end;

function TDelphiSemanticSourceContextCache.LineBreakForFile(
  const aFileName: string): string;
var
  lError: string;
  lSource: TDelphiSemanticSourceFile;
begin
  Result := sLineBreak;
  if TryLoad(aFileName, lSource, lError) then
    Result := lSource.LineBreak;
end;

function TryReadSourceContext(const aFileName: string; const aLine, aContextLines: Integer;
  const aCache: TDelphiSemanticSourceContextCache; out aContext: TDelphiSemanticSourceContextSnippet;
  out aError: string): Boolean; overload;
var
  i: Integer;
  lEndLine: Integer;
  lSource: TDelphiSemanticSourceFile;
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

  if not aCache.TryLoad(aFileName, lSource, aError) then
    Exit(False);

  if aLine > Length(lSource.Lines) then
  begin
    aError := Format('Source line %d is outside %s.', [aLine, aFileName]);
    Exit(False);
  end;

  lStartLine := Max(1, aLine - Max(0, aContextLines));
  lEndLine := Min(Length(lSource.Lines), aLine + Max(0, aContextLines));
  aContext.FileName := TPath.GetFullPath(aFileName);
  aContext.TargetLine := aLine;
  aContext.StartLine := lStartLine;
  SetLength(aContext.Lines, lEndLine - lStartLine + 1);
  for i := lStartLine to lEndLine do
    aContext.Lines[i - lStartLine] := lSource.Lines[i - 1];
  Result := True;
end;

function TryReadSourceContext(const aFileName: string; const aLine, aContextLines: Integer;
  out aContext: TDelphiSemanticSourceContextSnippet; out aError: string): Boolean; overload;
var
  lCache: TDelphiSemanticSourceContextCache;
begin
  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Result := TryReadSourceContext(aFileName, aLine, aContextLines, lCache, aContext, aError);
  finally
    lCache.Free;
  end;
end;

class function TDelphiSemanticSourceContext.TryParseFindingLocationWithColumn(
  const aFinding: string; out aFileToken: string; out aLine, aColumn: Integer): Boolean;
begin
  Result := TDelphiSemanticSourceContextCandidates.TryParseFindingLocationWithColumn(aFinding,
    aFileToken, aLine, aColumn);
end;

class function TDelphiSemanticSourceContext.TryResolve(const aProject: TDelphiSemanticProjectInfo;
  const aFileToken: string; const aLine, aContextLines: Integer;
  out aContext: TDelphiSemanticSourceContextSnippet; out aError: string): Boolean;
var
  lCache: TDelphiSemanticSourceContextCache;
begin
  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Result := TryResolve(aProject, aFileToken, aLine, aContextLines, lCache, aContext, aError);
  finally
    lCache.Free;
  end;
end;

class function TDelphiSemanticSourceContext.TryResolve(const aProject: TDelphiSemanticProjectInfo;
  const aFileToken: string; const aLine, aContextLines: Integer;
  const aCache: TDelphiSemanticSourceContextCache;
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
  Result := TryReadSourceContext(lResolvedFileName, aLine, aContextLines, aCache, aContext, aError);
end;

class function TDelphiSemanticSourceContext.TryResolveCandidate(
  const aProject: TDelphiSemanticProjectInfo; const aFinding: string; const aContextLines: Integer;
  out aContext: TDelphiSemanticSourceContextSnippet; out aToken, aEnclosingSymbol,
  aError: string): Boolean;
var
  lCache: TDelphiSemanticSourceContextCache;
begin
  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Result := TryResolveCandidate(aProject, aFinding, aContextLines, lCache, aContext,
      aToken, aEnclosingSymbol, aError);
  finally
    lCache.Free;
  end;
end;

class function TDelphiSemanticSourceContext.TryResolveCandidate(
  const aProject: TDelphiSemanticProjectInfo; const aFinding: string; const aContextLines: Integer;
  const aCache: TDelphiSemanticSourceContextCache;
  out aContext: TDelphiSemanticSourceContextSnippet; out aToken, aEnclosingSymbol,
  aError: string): Boolean;
var
  lColumn: Integer;
  lFileToken: string;
  lLine: Integer;
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
  Result := TryResolveCandidate(aProject, lFileToken, lLine, lColumn, aContextLines, aFinding, aCache,
    aContext, aToken, aEnclosingSymbol, aError);
end;

class function TDelphiSemanticSourceContext.TryResolveCandidate(
  const aProject: TDelphiSemanticProjectInfo; const aFileToken: string; const aLine, aColumn,
  aContextLines: Integer; const aCandidateText: string; const aCache: TDelphiSemanticSourceContextCache;
  out aContext: TDelphiSemanticSourceContextSnippet; out aToken, aEnclosingSymbol,
  aError: string): Boolean;
var
  lIndex: Integer;
begin
  aContext := Default(TDelphiSemanticSourceContextSnippet);
  aToken := '';
  aEnclosingSymbol := '';
  aError := '';
  if not TryResolve(aProject, aFileToken, aLine, aContextLines, aCache, aContext, aError) then
    Exit(False);

  lIndex := aContext.TargetLine - aContext.StartLine;
  Result := TDelphiSemanticSourceContextCandidates.TrySelectCandidateFromText(aCandidateText, aContext.Lines,
    lIndex, aFileToken, aLine, aColumn, aToken, aEnclosingSymbol, aError);
end;

class function TDelphiSemanticSourceContext.FormatLines(
  const aContext: TDelphiSemanticSourceContextSnippet): TArray<string>;
var
  lIndex: Integer;
  lLineNo: Integer;
  lMarker: string;
begin
  SetLength(Result, Length(aContext.Lines) + 1);
  Result[0] := 'source context: ' + aContext.FileName;
  for lIndex := 0 to High(aContext.Lines) do
  begin
    lLineNo := aContext.StartLine + lIndex;
    if lLineNo = aContext.TargetLine then
      lMarker := '>'
    else
      lMarker := ' ';
    Result[lIndex + 1] := Format('%s %4d | %s', [lMarker, lLineNo,
      aContext.Lines[lIndex]]);
  end;
end;

end.
