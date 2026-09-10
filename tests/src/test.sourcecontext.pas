unit Test.SourceContext;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.ProjectContext,
  DelphiSemantics.SourceContext;

type
  [TestFixture]
  TSourceContextTests = class
  private
    function LoadProject(const aFileName: string): TDelphiSemanticProjectInfo;
  public
    [Test]
    procedure AbsolutePathSourceContextResolves;
    [Test]
    procedure ProjectRelativeSourceContextResolves;
    [Test]
    procedure ProjectRelativeSourceContextPrefersProjectLookupOverCurrentDirectoryShadow;
    [Test]
    procedure SearchPathSourceContextResolves;
    [Test]
    procedure MissingSourceContextFileReturnsFalse;
    [Test]
    procedure SourceContextCacheRefreshesWhenFileChanges;
    [Test]
    procedure SourceContextCacheDetectsSubmillisecondChanges;
    [Test]
    procedure SourceContextCacheRejectsNonFilesAndMalformedPaths;
    [Test]
    procedure SourceContextCacheRefreshesWhenLinkTargetChanges;
    [Test]
    procedure ParseFindingLocationExtractsColumn;
    [Test]
    procedure SourceContextCandidateUsesTokenAtColumn;
    [Test]
    procedure SourceContextCandidateUsesTokenWhenColumnPointsAfterIdentifier;
    [Test]
    procedure SourceContextCandidateReturnsFalseForMalformedPathToken;
    [Test]
    procedure SourceContextCandidateUsesFirstIdentifierWithoutColumn;
    [Test]
    procedure SourceContextCandidateFallsBackToEnclosingSymbol;
    [Test]
    procedure SourceContextCandidateReturnsFalseWithoutReasonableCandidate;
    [Test]
    procedure SourceContextCandidateParsingLivesInFocusedUnit;
    [Test]
    procedure SourceConditionalsOwnConditionalLineRules;
    [Test]
    procedure SourceContextImplementationOwnsSharedLoadingAndWindowLogic;
  end;

implementation

uses
  System.DateUtils, System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  Test.Support;

var
  GSourceContextTempRoot: string;

function SourceContextTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GSourceContextTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GSourceContextTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'source-context-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GSourceContextTempRoot);
  Result := TPath.Combine(GSourceContextTempRoot, aName);
end;


function TSourceContextTests.LoadProject(const aFileName: string): TDelphiSemanticProjectInfo;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(aFileName);
  Assert.IsTrue(lResult.Success);
  Result := lResult.Project;
end;

procedure TSourceContextTests.AbsolutePathSourceContextResolves;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lProjectFileName: string;
begin
  lProjectFileName := FixturePath('SourceContext', 'ProjectRelativeUnit.pas');
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, lProjectFileName, 7, 1,
    lContext, lError), lError);
  Assert.AreEqual(TPath.GetFullPath(lProjectFileName), lContext.FileName);
  Assert.IsTrue(Pos('ProjectRelativeValue := 1;', String.Join(sLineBreak, lContext.Lines)) > 0);
end;

procedure TSourceContextTests.ProjectRelativeSourceContextResolves;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, 'ProjectRelativeUnit.pas', 7,
    1, lContext, lError), lError);
  Assert.AreEqual(FixturePath('SourceContext', 'ProjectRelativeUnit.pas'), lContext.FileName);
end;

procedure TSourceContextTests.ProjectRelativeSourceContextPrefersProjectLookupOverCurrentDirectoryShadow;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lCurrentDir: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lShadowDir: string;
  lShadowFileName: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));
  lShadowDir := SourceContextTempPath('source-context-shadow');
  TDirectory.CreateDirectory(lShadowDir);
  lShadowFileName := TPath.Combine(lShadowDir, 'ProjectRelativeUnit.pas');
  TFile.WriteAllText(lShadowFileName,
    'unit ProjectRelativeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'begin' + sLineBreak +
    '  ShadowValue := 1;' + sLineBreak +
    'end.', TEncoding.UTF8);

  lCurrentDir := GetCurrentDir;
  try
    SetCurrentDir(lShadowDir);
    Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, 'ProjectRelativeUnit.pas',
      7, 1, lContext, lError), lError);
  finally
    SetCurrentDir(lCurrentDir);
  end;

  Assert.AreEqual(FixturePath('SourceContext', 'ProjectRelativeUnit.pas'), lContext.FileName);
  Assert.IsTrue(Pos('ProjectRelativeValue := 1;', String.Join(sLineBreak, lContext.Lines)) > 0);
end;

procedure TSourceContextTests.SearchPathSourceContextResolves;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, 'SearchHitUnit.pas', 7, 1,
    lContext, lError), lError);
  Assert.AreEqual(FixturePath('SourceContext', 'lib\SearchHitUnit.pas'), lContext.FileName);
end;

procedure TSourceContextTests.MissingSourceContextFileReturnsFalse;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextFixture.dproj'));

  Assert.IsFalse(TDelphiSemanticSourceContext.TryResolve(lProject, 'MissingUnit.pas', 7, 1,
    lContext, lError));
  Assert.IsTrue(Pos('Could not resolve source file', lError) > 0);
end;

procedure WriteSourceContextRefreshFixture(const aFileName, aLineBreak, aMarker: string;
  const aInactive: Boolean; const aTimestampUtc: TDateTime);
var
  lText: string;
begin
  if aInactive then
    lText := 'unit CacheRefreshUnit;' + aLineBreak +
      'interface' + aLineBreak +
      '{$IFDEF NEVER}' + aLineBreak +
      '  ' + aMarker + aLineBreak +
      '{$ENDIF}' + aLineBreak +
      'implementation' + aLineBreak +
      'end.'
  else
    lText := 'unit CacheRefreshUnit;' + aLineBreak +
      'interface' + aLineBreak +
      'implementation' + aLineBreak +
      '  ' + aMarker + aLineBreak +
      'end.';

  TFile.WriteAllText(aFileName, lText, TEncoding.UTF8);
  TFile.SetLastWriteTimeUtc(aFileName, aTimestampUtc);
end;

procedure TSourceContextTests.SourceContextCacheRefreshesWhenFileChanges;
var
  lCache: TDelphiSemanticSourceContextCache;
  lContext: TDelphiSemanticSourceContextSnippet;
  lError: string;
  lFileName: string;
  lLine: string;
  lProject: TDelphiSemanticProjectInfo;
  lRangeText: string;
  lSource: TDelphiSemanticSourceFile;
  lTimestampUtc: TDateTime;
begin
  lFileName := TPath.Combine(SourceContextTempPath('cache-refresh'), 'CacheRefreshUnit.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lFileName));
  lTimestampUtc := EncodeDateTime(2026, 6, 18, 8, 0, 0, 0);
  WriteSourceContextRefreshFixture(lFileName, #13#10, 'StaleValue := 1;', True,
    lTimestampUtc);

  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Assert.IsTrue(lCache.TryGetLine(lFileName, 4, lLine));
    Assert.AreEqual('  StaleValue := 1;', lLine);
    Assert.IsTrue(lCache.LineHasConditionalDirective(lFileName, 3));
    Assert.IsTrue(lCache.InsideInactiveNeverConditionalRegion(lFileName, 1, 4));
    Assert.AreEqual(#13#10, lCache.LineBreakForFile(lFileName));

    WriteSourceContextRefreshFixture(lFileName, #10, 'FreshValue := 2;', False,
      IncSecond(lTimestampUtc, 2));

    Assert.IsTrue(lCache.TryGetLine(lFileName, 4, lLine));
    Assert.AreEqual('  FreshValue := 2;', lLine);
    Assert.IsFalse(lCache.LineHasConditionalDirective(lFileName, 3));
    Assert.IsFalse(lCache.InsideInactiveNeverConditionalRegion(lFileName, 1, 4));
    Assert.AreEqual(#10, lCache.LineBreakForFile(lFileName));
    Assert.IsTrue(lCache.TryLoad(lFileName, lSource, lError), lError);
    Assert.IsTrue(Pos('FreshValue := 2;', lSource.Text) > 0);
    Assert.IsFalse(Pos('StaleValue := 1;', lSource.Text) > 0);
    Assert.IsTrue(lCache.TryExtractRange(lFileName, 4, 3, 4, 12, lRangeText));
    Assert.AreEqual('FreshValue', lRangeText);

    lProject := Default(TDelphiSemanticProjectInfo);
    Assert.IsTrue(TDelphiSemanticSourceContext.TryResolve(lProject, lFileName, 4, 1,
      lCache, lContext, lError), lError);
    Assert.IsTrue(Pos('FreshValue := 2;', String.Join(sLineBreak, lContext.Lines)) > 0);
    Assert.IsFalse(Pos('StaleValue := 1;', String.Join(sLineBreak, lContext.Lines)) > 0);
  finally
    lCache.Free;
  end;
end;

procedure SetSourceContextFileTime(const aFileName: string;
  const aTimestamp: UInt64);
var
  h: THandle;
  lFileTime: TFileTime;
  lInfo: TWin32FileAttributeData;
begin
  lFileTime.dwLowDateTime := Cardinal(aTimestamp);
  lFileTime.dwHighDateTime := Cardinal(aTimestamp shr 32);
  h := CreateFile(PChar(aFileName), FILE_WRITE_ATTRIBUTES,
    FILE_SHARE_READ or FILE_SHARE_WRITE or FILE_SHARE_DELETE, nil,
    OPEN_EXISTING, FILE_ATTRIBUTE_NORMAL, 0);
  Assert.IsTrue(h <> INVALID_HANDLE_VALUE, 'Open fixture timestamp handle');
  try
    Assert.IsTrue(SetFileTime(h, nil, nil, @lFileTime), 'Set exact fixture timestamp');
  finally
    CloseHandle(h);
  end;
  Assert.IsTrue(GetFileAttributesEx(PChar(aFileName), GetFileExInfoStandard,
    @lInfo), 'Read fixture metadata');
  Assert.AreEqual(aTimestamp, (UInt64(lInfo.ftLastWriteTime.dwHighDateTime) shl 32) or
    lInfo.ftLastWriteTime.dwLowDateTime, 'Filesystem must retain the exact timestamp');
end;

procedure TSourceContextTests.SourceContextCacheDetectsSubmillisecondChanges;
var
  lCache: TDelphiSemanticSourceContextCache;
  lCoarseTimestamp: TDateTime;
  lFileName: string;
  lFileTime: TFileTime;
  lLine: string;
  lSystemTime: TSystemTime;
  lTimestamp: UInt64;
begin
  lFileName := CombinePath([SourceContextTempPath('precise-cache-refresh'),
    'PreciseCacheUnit.pas']);
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lFileName));
  lCoarseTimestamp := EncodeDateTime(2026, 9, 10, 8, 0, 0, 0);
  DateTimeToSystemTime(lCoarseTimestamp, lSystemTime);
  Assert.IsTrue(SystemTimeToFileTime(lSystemTime, lFileTime));
  lTimestamp := (UInt64(lFileTime.dwHighDateTime) shl 32) or lFileTime.dwLowDateTime;
  WriteSourceContextRefreshFixture(lFileName, #13#10, 'OldValue := 1;', False,
    lCoarseTimestamp);
  SetSourceContextFileTime(lFileName, lTimestamp + 1);
  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Assert.IsTrue(lCache.TryGetLine(lFileName, 4, lLine));
    Assert.AreEqual('  OldValue := 1;', lLine);
    WriteSourceContextRefreshFixture(lFileName, #13#10, 'NewValue := 2;', False,
      lCoarseTimestamp);
    SetSourceContextFileTime(lFileName, lTimestamp + 2);
    Assert.AreEqual(lCoarseTimestamp, TFile.GetLastWriteTimeUtc(lFileName),
      'The old millisecond timestamp representation cannot distinguish this update');
    Assert.IsTrue(lCache.TryGetLine(lFileName, 4, lLine));
    Assert.AreEqual('  NewValue := 2;', lLine,
      'Distinct native timestamps must invalidate same-size cached source');
    TFile.Delete(lFileName);
    Assert.IsFalse(lCache.TryGetLine(lFileName, 4, lLine),
      'A deleted source file must not return cached text');
  finally
    lCache.Free;
  end;
end;

procedure TSourceContextTests.SourceContextCacheRejectsNonFilesAndMalformedPaths;
var
  lCache: TDelphiSemanticSourceContextCache;
  lDirectory: string;
  lError: string;
  lFileName: string;
  lSource: TDelphiSemanticSourceFile;
begin
  lDirectory := SourceContextTempPath('invalid-cache-path');
  TDirectory.CreateDirectory(lDirectory);
  lCache := TDelphiSemanticSourceContextCache.Create;
  try
    Assert.IsFalse(lCache.TryLoad('', lSource, lError));
    Assert.IsFalse(lCache.TryLoad(lDirectory, lSource, lError));
    Assert.IsFalse(lCache.TryLoad(CombinePath([lDirectory, 'Missing.pas']),
      lSource, lError));
    lFileName := CombinePath([lDirectory, StringOfChar('x', MAX_PATH) + '.pas']);
    lFileName[Length(lFileName)] := '|';
    Assert.IsFalse(lCache.TryLoad(lFileName, lSource, lError),
      'Malformed paths must remain a failed lookup');
  finally
    lCache.Free;
  end;
end;

// Delphi 12's TFile.CreateSymLink cannot pass the developer-mode creation flag.
function CreateSourceContextSymbolicLink(const aLink, aTarget: PWideChar;
  const aFlags: DWORD): ByteBool; stdcall; external kernel32 name 'CreateSymbolicLinkW';

procedure TSourceContextTests.SourceContextCacheRefreshesWhenLinkTargetChanges;
const
  cAllowUnprivilegedCreate = $2;
var
  lCache: TDelphiSemanticSourceContextCache;
  lDirectory: string;
  lLine: string;
  lLink: string;
  lTarget: string;
  lTimestamp: TDateTime;
begin
  lDirectory := SourceContextTempPath('linked-cache-refresh');
  TDirectory.CreateDirectory(lDirectory);
  lTarget := CombinePath([lDirectory, 'Target.pas']);
  lLink := CombinePath([lDirectory, 'Linked.pas']);
  lTimestamp := EncodeDateTime(2026, 9, 10, 8, 0, 0, 0);
  WriteSourceContextRefreshFixture(lTarget, #13#10, 'OldValue := 1;', False,
    lTimestamp);
  Assert.IsTrue(CreateSourceContextSymbolicLink(PWideChar(lLink), PWideChar(lTarget),
    cAllowUnprivilegedCreate), 'Create real source link');
  try
    lCache := TDelphiSemanticSourceContextCache.Create;
    try
      Assert.IsTrue(lCache.TryGetLine(lLink, 4, lLine));
      Assert.AreEqual('  OldValue := 1;', lLine);
      WriteSourceContextRefreshFixture(lTarget, #13#10, 'NewValue := 2;', False,
        IncSecond(lTimestamp));
      Assert.IsTrue(lCache.TryGetLine(lLink, 4, lLine));
      Assert.AreEqual('  NewValue := 2;', lLine,
        'A same-size target edit must invalidate cached text through its link');
      TFile.Delete(lTarget);
      Assert.IsFalse(lCache.TryGetLine(lLink, 4, lLine),
        'A dangling link must not return cached source');
    finally
      lCache.Free;
    end;
  finally
    Assert.IsTrue(Winapi.Windows.DeleteFile(PChar(lLink)), 'Remove source link');
    if TFile.Exists(lTarget) then
      TFile.Delete(lTarget);
    TDirectory.Delete(lDirectory);
  end;
end;

procedure TSourceContextTests.ParseFindingLocationExtractsColumn;
var
  lColumn: Integer;
  lFileToken: string;
  lLine: Integer;
begin
  Assert.IsTrue(TDelphiSemanticSourceContext.TryParseFindingLocationWithColumn(
    'TokenUnit.pas(7,5): error E2003: Undeclared identifier: ''MissingIdentifier''',
    lFileToken, lLine, lColumn));
  Assert.AreEqual('TokenUnit.pas', lFileToken);
  Assert.AreEqual(7, lLine);
  Assert.AreEqual(5, lColumn);
end;

procedure TSourceContextTests.SourceContextCandidateUsesTokenAtColumn;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'TokenUnit.pas(7,5): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('MissingIdentifier', lToken);
  Assert.AreEqual('', lEnclosingSymbol);
  Assert.AreEqual(FixturePath('SourceContext', 'TokenUnit.pas'), lContext.FileName);
  Assert.AreEqual(7, lContext.TargetLine);
end;

procedure TSourceContextTests.SourceContextCandidateUsesTokenWhenColumnPointsAfterIdentifier;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'TokenUnit.pas(7,22): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('MissingIdentifier', lToken);
end;

procedure TSourceContextTests.SourceContextCandidateReturnsFalseForMalformedPathToken;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsFalse(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'Bad'#0'Path.pas(7,5): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError));
  Assert.IsTrue(Pos('source file', LowerCase(lError)) > 0, lError);
end;

procedure TSourceContextTests.SourceContextCandidateUsesFirstIdentifierWithoutColumn;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'TokenUnit.pas(7): error E2003: Undeclared identifier', 1, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('MissingIdentifier', lToken);
  Assert.AreEqual('', lEnclosingSymbol);
end;

procedure TSourceContextTests.SourceContextCandidateFallsBackToEnclosingSymbol;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsTrue(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'SymbolUnit.pas(7,3): error E2029: Record not allowed here', 3, lContext, lToken,
    lEnclosingSymbol, lError), lError);
  Assert.AreEqual('', lToken);
  Assert.AreEqual('Trigger', lEnclosingSymbol);
  Assert.AreEqual(FixturePath('SourceContext', 'SymbolUnit.pas'), lContext.FileName);
  Assert.AreEqual(7, lContext.TargetLine);
end;

procedure TSourceContextTests.SourceContextCandidateReturnsFalseWithoutReasonableCandidate;
var
  lContext: TDelphiSemanticSourceContextSnippet;
  lEnclosingSymbol: string;
  lError: string;
  lProject: TDelphiSemanticProjectInfo;
  lToken: string;
begin
  lProject := LoadProject(FixturePath('SourceContext', 'SourceContextCandidateFixture.dproj'));

  Assert.IsFalse(TDelphiSemanticSourceContext.TryResolveCandidate(lProject,
    'NoCandidateUnit.pas(3,1): error E2010: Syntax error', 1, lContext, lToken,
    lEnclosingSymbol, lError));
  Assert.IsTrue(Pos('candidate', LowerCase(lError)) > 0, lError);
end;

procedure TSourceContextTests.SourceContextCandidateParsingLivesInFocusedUnit;
var
  lCandidateUnitSource: string;
  lSourceContextSource: string;
begin
  Assert.IsTrue(FileExists(RepoSourcePath('src\DelphiSemantics.SourceContext.Candidates.pas')),
    'Expected focused source-context candidate parsing unit.');

  lSourceContextSource := ReadRepoSource('src\DelphiSemantics.SourceContext.pas');
  lCandidateUnitSource := ReadRepoSource('src\DelphiSemantics.SourceContext.Candidates.pas');

  Assert.IsTrue(ContainsText(lSourceContextSource,
    'DelphiSemantics.SourceContext.Candidates'),
    'SourceContext should delegate candidate parsing to the focused unit.');
  Assert.IsFalse(ContainsText(lSourceContextSource, 'function TryExtractIdentifierAtColumn'),
    'SourceContext should not own identifier-at-column parsing.');
  Assert.IsFalse(ContainsText(lSourceContextSource, 'function TryExtractFirstIdentifierFromLine'),
    'SourceContext should not own first-identifier fallback parsing.');
  Assert.IsFalse(ContainsText(lSourceContextSource, 'function TryExtractEnclosingSymbolFromLine'),
    'SourceContext should not own enclosing-symbol fallback parsing.');
  Assert.IsFalse(ContainsText(lSourceContextSource, 'function TryExtractQuotedIdentifier'),
    'SourceContext should not own finding quoted-identifier parsing.');
  Assert.IsFalse(ContainsText(lSourceContextSource, 'TRegEx.Match(aFinding'),
    'SourceContext should not own diagnostic location parsing.');

  Assert.IsTrue(ContainsText(lCandidateUnitSource, 'TryExtractIdentifierAtColumn'),
    'Candidate unit should own identifier-at-column parsing.');
  Assert.IsTrue(ContainsText(lCandidateUnitSource, 'TryExtractEnclosingSymbolFromLine'),
    'Candidate unit should own enclosing-symbol fallback parsing.');
  Assert.IsTrue(ContainsText(lCandidateUnitSource, 'TryParseFindingLocationWithColumn'),
    'Candidate unit should own diagnostic location parsing.');
end;

procedure TSourceContextTests.SourceConditionalsOwnConditionalLineRules;
var
  lConditionalRule: string;
  lRemoveWithSource: string;
  lSourceContextSource: string;
begin
  lConditionalRule := 'StartsText(''{$IF';
  lSourceContextSource := ReadRepoSource('src\DelphiSemantics.SourceContext.pas');
  lRemoveWithSource := ReadRepoSource('src\DelphiSemantics.RemoveWithPlan.pas');

  Assert.IsTrue(FileExists(RepoSourcePath('src\DelphiSemantics.SourceConditionals.pas')),
    'Expected shared conditional-line helper unit.');
  Assert.IsFalse(ContainsText(lSourceContextSource, lConditionalRule),
    'SourceContext should delegate conditional-line rules to SourceConditionals.');
  Assert.IsFalse(ContainsText(lRemoveWithSource, lConditionalRule),
    'RemoveWithPlan should delegate conditional-line rules to SourceConditionals.');
end;

procedure TSourceContextTests.SourceContextImplementationOwnsSharedLoadingAndWindowLogic;
var
  lDakBuildRunnerText: string;
  lDakBuildSummaryText: string;
  lDakDfmCheckText: string;
  lDakSourceContextText: string;
  lRemoveWithPlanText: string;
begin
  lDakBuildRunnerText := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', '..', 'DelphiAiKit', 'src',
    'Dak.Build.Runner.pas'])), TEncoding.UTF8);
  lDakBuildSummaryText := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', '..', 'DelphiAiKit', 'src',
    'dak.build.summary.pas'])), TEncoding.UTF8);
  lDakDfmCheckText := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', '..', 'DelphiAiKit', 'src',
    'dak.dfmcheck.pas'])), TEncoding.UTF8);
  lDakSourceContextText := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', '..', 'DelphiAiKit', 'src',
    'dak.sourcecontext.pas'])), TEncoding.UTF8);
  lRemoveWithPlanText := ReadRepoSource('src\DelphiSemantics.RemoveWithPlan.pas');

  Assert.IsTrue(Pos('TDelphiSemanticSourceContext.', lDakSourceContextText) > 0,
    'DAK source-context should delegate parsing/resolution to DelphiSemantics.');
  Assert.IsFalse(Pos('function TryLoadLines(', lDakSourceContextText) > 0,
    'DAK should not own duplicate source loading.');
  Assert.IsFalse(Pos('function TryResolveSourceFile(', lDakSourceContextText) > 0,
    'DAK should not own duplicate source-file resolution.');
  Assert.IsFalse(Pos('TFile.ReadAllLines(aFileName)', lRemoveWithPlanText) > 0,
    'Remove-with planning should use the shared source-context cache.');
  Assert.IsTrue(Pos('TDelphiSemanticSourceContextCache', lRemoveWithPlanText) > 0,
    'Remove-with planning should share cached source text and line maps.');
  Assert.IsTrue(Pos('lBuildSourceContextCache := TSourceContextRunCache.Create(lProjectLookup)',
    lDakBuildRunnerText) > 0,
    'DAK build source-context enrichment should reuse one source cache per build run.');
  Assert.IsFalse(Pos('TSourceContextRunCache.Create(aLookup)', lDakBuildSummaryText) > 0,
    'DAK build summary parsing should not own source-context enrichment.');
  Assert.IsFalse(Pos('TryResolveSourceContext(aLookup', lDakBuildSummaryText) > 0,
    'DAK build-summary source-context enrichment should not use the stateless resolver.');
  Assert.IsTrue(Pos('lSourceContextCache := TSourceContextRunCache.Create', lDakDfmCheckText) > 0,
    'DAK DFM source-context enrichment should reuse one source cache per run.');
  Assert.IsTrue(Pos('SourceLineBreakForFile(aBinding.FileName, aLineCache)', lRemoveWithPlanText) > 0,
    'Remove-with line-break reads should use the plan source-context cache.');
end;

initialization
  TDUnitX.RegisterTestFixture(TSourceContextTests);

end.
