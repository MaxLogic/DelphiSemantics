unit Test.Api;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith, DelphiSemantics.Api.RemoveWith.Compatibility,
  DelphiSemantics.Api.WithBinding;

type
  [TestFixture]
  TApiTests = class
  private
    function BlockerReason(const aPlan: TDelphiSemanticDeadCodeRemovalPlan;
      const aName: string): string;
    function HasBindingForUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): Boolean;
    function HasProjectSymbol(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass: string): Boolean;
    function LoadCachedContext(const aCompilerProfileName, aSourceFileName: string;
      const aIndexedSourceFileNames: TArray<string>; const aIndexedSourceKinds:
      TArray<string>): TDelphiSemanticSymbolQueryContext;
    function ReportCandidateStatus(const aReport: TDelphiSemanticDeadCodeReport;
      const aName: string): string;
    function TryFindDiagnostic(const aResult: TDelphiSemanticContextResult;
      const aCode: string; out aDiagnostic: TDelphiSemanticDiagnostic): Boolean;
  public
    [Test]
    procedure LoadsProjectContextThroughStableFacade;
    [Test]
    procedure LoadProjectContextMergesApiSearchPaths;
    [Test]
    procedure LoadProjectContextReportsExplicitLspEnrichmentStatus;
    [Test]
    procedure WithBindingBuildUnitIndexAppliesProjectDefines;
    [Test]
    procedure WithBindingBuildUnitIndexReportsMissingProjectContext;
    [Test]
    procedure ScanWithAndSymbolIndexRoutesReturnStableShapes;
    [Test]
    procedure UsageRoutesReturnStableShapes;
    [Test]
    procedure RenameAndFunctionResultRoutesReturnStableShapes;
    [Test]
    procedure DeadCodeAndSearchRoutesReturnStableShapes;
    [Test]
    procedure CommonOptionsDoNotExposeRemoveWithBodyAnalysisScope;
    [Test]
    procedure RemoveWithPrimaryFacadeHidesInternalAliases;
    [Test]
    procedure RemoveWithRequestOwnsBodyAnalysisScope;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.Model,
  maxLogic.IOUtils,
  Test.Support;


var
  GApiTempRoot: string;

function ApiTempRoot: string;
begin
  if GApiTempRoot = '' then
    GApiTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'api-temp', 'default']));
  TDirectory.CreateDirectory(GApiTempRoot);
  Result := GApiTempRoot;
end;

function ApiTempPath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ApiTempRoot, aRelativePath));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
end;

function TApiTests.BlockerReason(const aPlan: TDelphiSemanticDeadCodeRemovalPlan;
  const aName: string): string;
var
  lBlocker: TDelphiSemanticDeadCodeRemovalBlocker;
begin
  for lBlocker in aPlan.Blockers do
    if SameText(lBlocker.Name, aName) then
      Exit(lBlocker.Reason);

  Result := '';
end;

function TApiTests.HasBindingForUnit(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aUnitName: string): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.UnitName, aUnitName) then
      Exit(True);

  Result := False;
end;

function TApiTests.HasProjectSymbol(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aName, aSymbolClass: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aFacts.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) then
      Exit(True);

  Result := False;
end;

function TApiTests.LoadCachedContext(const aCompilerProfileName, aSourceFileName: string;
  const aIndexedSourceFileNames: TArray<string>; const aIndexedSourceKinds: TArray<string>):
  TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := aCompilerProfileName;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := aSourceFileName;
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      aIndexedSourceFileNames);
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels;
    Result.IndexedUnitSourceKinds := aIndexedSourceKinds;
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function TApiTests.ReportCandidateStatus(const aReport: TDelphiSemanticDeadCodeReport;
  const aName: string): string;
var
  lCandidate: TDelphiSemanticDeadCodeCandidate;
begin
  for lCandidate in aReport.Candidates do
    if SameText(lCandidate.Name, aName) then
      Exit(lCandidate.Status);

  Result := '';
end;

function TApiTests.TryFindDiagnostic(const aResult: TDelphiSemanticContextResult;
  const aCode: string; out aDiagnostic: TDelphiSemanticDiagnostic): Boolean;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  for lDiagnostic in aResult.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
    begin
      aDiagnostic := lDiagnostic;
      Exit(True);
    end;

  aDiagnostic := Default(TDelphiSemanticDiagnostic);
  Result := False;
end;

function ContainsPath(const aPaths: TArray<string>; const aPath: string): Boolean;
var
  lPath: string;
begin
  for lPath in aPaths do
    if SameText(ExcludeTrailingPathDelimiter(lPath), ExcludeTrailingPathDelimiter(aPath)) then
      Exit(True);

  Result := False;
end;

procedure TApiTests.LoadsProjectContextThroughStableFacade;
var
  lOptions: TDelphiSemanticApiOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';

  lResult := TDelphiSemanticApi.LoadProjectContext(
    FixturePath('ProjectContext\Basic\BasicProject.dproj'), lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('BasicProject', lResult.Project.ProjectName);
  Assert.AreEqual('Debug', lResult.Project.Configuration);
  Assert.AreEqual('Win32', lResult.Project.Platform);
end;

procedure TApiTests.LoadProjectContextMergesApiSearchPaths;
var
  lAdditionalPath: string;
  lMacroPath: string;
  lOptions: TDelphiSemanticApiOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lAdditionalPath := TPath.Combine(FixturePath('ProjectContext\Basic'), 'ApiSearchPath');
  lMacroPath := TPath.Combine(FixturePath('ProjectContext\Basic'), 'ApiMacroPath\Win32\Debug');
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';
  lOptions.SearchPaths := [lAdditionalPath, 'ApiMacroPath\$(Platform)\$(Config)'];

  lResult := TDelphiSemanticApi.LoadProjectContext(
    FixturePath('ProjectContext\Basic\BasicProject.dproj'), lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsPath(lResult.Project.SearchPaths, lAdditionalPath),
    'Expected API search paths to be merged into semantic project search paths.');
  Assert.IsTrue(ContainsPath(lResult.Project.SourceLookupPaths, lAdditionalPath),
    'Expected API search paths to participate in source lookup paths.');
  Assert.IsTrue(ContainsPath(lResult.Project.SearchPaths, lMacroPath),
    'Expected API search paths to expand project macros.');
end;

procedure TApiTests.LoadProjectContextReportsExplicitLspEnrichmentStatus;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
  lDisabledOptions: TDelphiSemanticApiOptions;
  lDisabledResult: TDelphiSemanticContextResult;
  lEnabledOptions: TDelphiSemanticApiOptions;
  lEnabledResult: TDelphiSemanticContextResult;
  lProjectFileName: string;
begin
  lProjectFileName := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lDisabledOptions := Default(TDelphiSemanticApiOptions);
  lDisabledOptions.Configuration := 'Debug';
  lDisabledOptions.Platform := 'Win32';

  lDisabledResult := TDelphiSemanticApi.LoadProjectContext(lProjectFileName,
    lDisabledOptions);

  Assert.IsTrue(lDisabledResult.Success);
  Assert.IsFalse(TryFindDiagnostic(lDisabledResult, 'lsp.enrichment.not-implemented',
    lDiagnostic), 'UseLspEnrichment=False must keep semantic-model-only behavior.');

  lEnabledOptions := lDisabledOptions;
  lEnabledOptions.UseLspEnrichment := True;

  lEnabledResult := TDelphiSemanticApi.LoadProjectContext(lProjectFileName,
    lEnabledOptions);

  Assert.IsTrue(lEnabledResult.Success);
  Assert.IsTrue(TryFindDiagnostic(lEnabledResult, 'lsp.enrichment.not-implemented',
    lDiagnostic), 'UseLspEnrichment=True must return an explicit enrichment diagnostic.');
  Assert.AreEqual(dsWarning, lDiagnostic.Severity);
  Assert.AreEqual(lProjectFileName, lDiagnostic.FileName);
  Assert.AreEqual('LSP enrichment was requested, but no DelphiSemantics LSP enrichment adapter is configured.',
    lDiagnostic.Message);
end;

procedure TApiTests.WithBindingBuildUnitIndexAppliesProjectDefines;
var
  lDprFileName: string;
  lDprojFileName: string;
  lIndex: TDelphiSemanticUnitIndex;
  lOptions: TDelphiSemanticApiOptions;
begin
  lDprFileName := ApiTempPath('withbinding-project-define\ApiProjectDefine.dpr');
  lDprojFileName := ApiTempPath('withbinding-project-define\ApiProjectDefine.dproj');

  TFile.WriteAllText(lDprFileName,
    'program ApiProjectDefine;' + sLineBreak +
    sLineBreak +
    '{$IFDEF API_PROJECT_DEFINE}' + sLineBreak +
    'type' + sLineBreak +
    '  TApiProjectRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TApiProjectRecord;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    sLineBreak +
    'begin' + sLineBreak +
    '{$IFDEF API_PROJECT_DEFINE}' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '    Value := 7;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    'end.', TEncoding.ASCII);
  TFile.WriteAllText(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + sLineBreak +
    '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{B98F61BE-6A87-4335-9F54-B539A0660C62}</ProjectGuid>' + sLineBreak +
    '    <MainSource>ApiProjectDefine.dpr</MainSource>' + sLineBreak +
    '    <Config Condition="''$(Config)''==''''">Debug</Config>' + sLineBreak +
    '    <Platform Condition="''$(Platform)''==''''">Win32</Platform>' + sLineBreak +
    '    <DCC_Define>API_PROJECT_DEFINE</DCC_Define>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    '</Project>', TEncoding.ASCII);

  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';

  lIndex := TDelphiSemanticWithBindingApi.BuildUnitIndex(lOptions);

  Assert.IsTrue(lIndex.Success);
  Assert.AreEqual(1, Integer(Length(lIndex.Bindings)),
    'Project-file BuildUnitIndex must apply project DCC_Define before extracting with bindings.');
end;

procedure TApiTests.WithBindingBuildUnitIndexReportsMissingProjectContext;
var
  lIndex: TDelphiSemanticUnitIndex;
  lOptions: TDelphiSemanticApiOptions;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := ApiTempPath('missing-project-context\MissingProject.dproj');

  lIndex := TDelphiSemanticWithBindingApi.BuildUnitIndex(lOptions);

  Assert.IsFalse(lIndex.Success);
  Assert.IsFalse(lIndex.Model.Success);
  Assert.AreEqual(1, Integer(Length(lIndex.Model.Diagnostics)),
    'Project context failures must be reported through deterministic model diagnostics.');
  Assert.AreEqual('PROJECT_FILE_NOT_FOUND', lIndex.Model.Diagnostics[0].Code);
  Assert.AreEqual(lOptions.ProjectFileName, lIndex.Model.Diagnostics[0].FileName);
end;

procedure TApiTests.ScanWithAndSymbolIndexRoutesReturnStableShapes;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lOptions: TDelphiSemanticApiOptions;
  lScan: TDelphiSemanticWithScanResult;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.SourceFileName := FixturePath('WithDiscovery', 'WithDiscoveryUnit.pas');
  lOptions.ProjectContextApplied := True;

  lScan := TDelphiSemanticApi.ScanWithStatements(lOptions);

  Assert.IsTrue(lScan.Success);
  Assert.IsFalse(lScan.ProjectSessionUsed);
  Assert.AreEqual('WithDiscoveryUnit', lScan.UnitName);
  Assert.AreEqual(5, Integer(Length(lScan.WithStatements)));

  lContext := LoadCachedContext('Delphi-12-Api-SymbolQuery',
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'),
    [FixturePath('SymbolQuery', 'SymbolQueryRtlUnit.pas')], ['rtl-source']);

  lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

  Assert.IsTrue(Length(lIndex.Symbols) > 0);
  Assert.AreEqual(1, lIndex.Metrics.BuildInvocationCount);
  Assert.IsTrue(Length(lIndex.FindSymbolsByName('GlobalQueryValue')) > 0);
  Assert.AreEqual('project-source',
    lIndex.FindSymbolsByName('GlobalQueryValue')[0].SourceKind);
end;

procedure TApiTests.UsageRoutesReturnStableShapes;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lNameResult: TDelphiSemanticUsageResult;
  lPositionResult: TDelphiSemanticUsageResult;
begin
  lContext := LoadCachedContext('Delphi-12-Api-Usage',
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'),
    [FixturePath('SymbolQuery', 'SymbolQueryRtlUnit.pas')], ['rtl-source']);

  lPositionResult := TDelphiSemanticApi.FindUsagesAtPosition(lContext,
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'), 6, 3);
  lNameResult := TDelphiSemanticApi.FindUsagesByName(lContext, 'GlobalQueryValue');

  Assert.AreEqual('resolved', lPositionResult.Status);
  Assert.AreEqual('TSymbolMapFixture', lPositionResult.Symbol.Name);
  Assert.IsTrue(Length(lPositionResult.Usages) >= 3);
  Assert.AreEqual('resolved', lNameResult.Status);
  Assert.AreEqual('GlobalQueryValue', lNameResult.Symbol.Name);
  Assert.IsTrue(Length(lNameResult.Usages) >= 3);
end;

procedure TApiTests.RenameAndFunctionResultRoutesReturnStableShapes;
var
  lFunctionContext: TDelphiSemanticSymbolQueryContext;
  lFunctionPlan: TDelphiSemanticRenamePlan;
  lRenameContext: TDelphiSemanticSymbolQueryContext;
  lRenamePlan: TDelphiSemanticRenamePlan;
  lRoutineContext: TDelphiSemanticSymbolQueryContext;
  lRoutinePlan: TDelphiSemanticRenamePlan;
begin
  lRenameContext := LoadCachedContext('Delphi-12-Api-Rename',
    FixturePath('Rename', 'RenameUnit.pas'), [FixturePath('Rename', 'RenameConsumerUnit.pas')],
    ['project-source']);

  lRenamePlan := TDelphiSemanticApi.PlanRename(lRenameContext, 'GlobalQueryValue',
    'RenamedGlobalQueryValue');

  Assert.AreEqual('planned', lRenamePlan.Status, lRenamePlan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lRenamePlan.Edits)));
  Assert.IsNotEmpty(lRenamePlan.ContextFingerprint);
  Assert.IsNotEmpty(lRenamePlan.BaselineSemanticModelVersion);
  Assert.IsTrue(Length(lRenamePlan.RequiredVerification) >= 3);
  Assert.AreEqual('GlobalQueryValue', lRenamePlan.Edits[0].ExpectedSourceText);
  Assert.IsNotEmpty(lRenamePlan.Edits[0].ExpectedFileHash);

  lRoutineContext := LoadCachedContext('Delphi-12-Api-Rename-Routine',
    FixturePath('RenameUnblock', 'RenameRoutineUnit.pas'),
    [FixturePath('RenameUnblock', 'RenameRoutineConsumerUnit.pas')], ['project-source']);

  lRoutinePlan := TDelphiSemanticApi.PlanRenameAtPosition(lRoutineContext,
    FixturePath('RenameUnblock', 'RenameRoutineUnit.pas'), 8, 10, 'RenamedRoutineTarget');

  Assert.AreEqual('planned', lRoutinePlan.Status, lRoutinePlan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lRoutinePlan.Edits)));
  Assert.IsNotEmpty(lRoutinePlan.ContextFingerprint);
  Assert.IsNotEmpty(lRoutinePlan.Edits[0].ExpectedSourceText);
  Assert.IsNotEmpty(lRoutinePlan.Edits[0].ExpectedFileHash);

  lFunctionContext := LoadCachedContext('Delphi-12-Api-Function-Result',
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), [], []);

  lFunctionPlan := TDelphiSemanticApi.PlanFunctionResultRefactorAtPosition(lFunctionContext,
    FixturePath('FunctionResult', 'FunctionResultUnit.pas'), 23, 3);

  Assert.AreEqual('planned', lFunctionPlan.Status, lFunctionPlan.Diagnostic);
  Assert.AreEqual(4, Integer(Length(lFunctionPlan.Edits)));
  Assert.IsNotEmpty(lFunctionPlan.ContextFingerprint);
  Assert.AreEqual('LegacyValue', lFunctionPlan.Edits[0].ExpectedSourceText);
  Assert.IsNotEmpty(lFunctionPlan.Edits[0].ExpectedFileHash);
end;

procedure TApiTests.DeadCodeAndSearchRoutesReturnStableShapes;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lRemovalByName: TDelphiSemanticDeadCodeRemovalPlan;
  lRemovalByProfile: TDelphiSemanticDeadCodeRemovalPlan;
  lReportByName: TDelphiSemanticDeadCodeReport;
  lReportByProfile: TDelphiSemanticDeadCodeReport;
  lSearchQuery: TDelphiSemanticSearchQuery;
  lSearchResult: TDelphiSemanticSearchResult;
begin
  lContext := LoadCachedContext('Delphi-12-Api-DeadCode',
    FixturePath('DeadCode', 'DeadCodeUnit.pas'),
    [FixturePath('DeadCode', 'DeadCodeOtherUnit.pas'),
    FixturePath('DeadCode', 'DeadCodeRtlUnit.pas')], ['project-source', 'rtl-source']);

  lReportByProfile := TDelphiSemanticApi.ReportDeadCode(lContext,
    TDelphiSemanticDeadCodeSafetyProfile.dcspAudit);
  lReportByName := TDelphiSemanticApi.ReportDeadCode(lContext, 'audit');

  Assert.AreEqual('audit', lReportByProfile.Profile);
  Assert.AreEqual('audit', lReportByName.Profile);
  Assert.AreEqual('definitely-unused', ReportCandidateStatus(lReportByName,
    'StaticUnusedValue'));

  lRemovalByProfile := TDelphiSemanticApi.PlanDeadCodeRemoval(lContext,
    TDelphiSemanticDeadCodeSafetyProfile.dcspConservative);
  lRemovalByName := TDelphiSemanticApi.PlanDeadCodeRemoval(lContext, 'audit');

  Assert.AreEqual('planned', lRemovalByProfile.Status);
  Assert.AreEqual('conservative', lRemovalByProfile.Profile);
  Assert.IsTrue(Length(lRemovalByProfile.Edits) > 0);
  Assert.AreEqual('planned', lRemovalByName.Status);
  Assert.AreEqual('audit', lRemovalByName.Profile);
  Assert.AreEqual('audit-profile', BlockerReason(lRemovalByName, 'StaticUnusedValue'));

  lContext := LoadCachedContext('Delphi-12-Api-Search',
    FixturePath('SymbolQuery', 'SymbolQueryUnit.pas'),
    [FixturePath('SymbolQuery', 'SymbolQueryRtlUnit.pas')], ['rtl-source']);
  lSearchQuery := Default(TDelphiSemanticSearchQuery);
  lSearchQuery.Pattern := 'GlobalQuery';

  lSearchResult := TDelphiSemanticApi.Search(lContext, lSearchQuery);

  Assert.AreEqual('resolved', lSearchResult.Status);
  Assert.IsTrue(Length(lSearchResult.Matches) > 0);
  Assert.AreEqual('GlobalQueryValue', lSearchResult.Matches[0].Name);
end;

procedure TApiTests.CommonOptionsDoNotExposeRemoveWithBodyAnalysisScope;
var
  lApiSource: string;
  lProjectContextSource: string;
begin
  lApiSource := ReadRepoSource('src\DelphiSemantics.Api.pas');
  lProjectContextSource := ReadRepoSource('src\DelphiSemantics.ProjectContext.pas');

  Assert.IsFalse(Pos('BodyAnalysisSourceFileNames', lApiSource) > 0,
    'Common API options must not expose remove-with-only body-analysis scope.');
  Assert.IsFalse(Pos('BodyAnalysisSourceFileNames', lProjectContextSource) > 0,
    'Common project/session options must not expose remove-with-only body-analysis scope.');
end;

procedure TApiTests.RemoveWithPrimaryFacadeHidesInternalAliases;
var
  lInterfaceSource: string;
  lSource: string;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Api.RemoveWith.pas');
  lInterfaceSource := Copy(lSource, 1, Pos('implementation', lSource) - 1);

  Assert.IsFalse(ContainsText(lInterfaceSource, 'FinalTextEdit'),
    'Primary remove-with API facade must not expose final-edit internals.');
  Assert.IsFalse(ContainsText(lInterfaceSource, 'FinalStatement'),
    'Primary remove-with API facade must not expose final-statement internals.');
  Assert.IsFalse(ContainsText(lInterfaceSource, 'RewriteRecipe'),
    'Primary remove-with API facade must not expose rewrite recipe internals.');
  Assert.IsFalse(ContainsText(lInterfaceSource, 'LookupIndex'),
    'Primary remove-with API facade must not expose lookup internals.');
  Assert.IsFalse(ContainsText(lInterfaceSource, 'Inventory'),
    'Primary remove-with API facade must not expose inventory internals.');
  Assert.IsFalse(ContainsText(lInterfaceSource, 'WithBinding'),
    'Primary remove-with API facade must not expose with-binding internals.');
  Assert.IsTrue(ContainsText(ReadRepoSource('src\DelphiSemantics.Api.RemoveWith.Compatibility.pas'),
    'TDelphiSemanticRemoveWithCompatibilityApi'),
    'Compatibility remove-with API should own internal adapter aliases.');
end;

procedure TApiTests.RemoveWithRequestOwnsBodyAnalysisScope;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lRequest: TDelphiSemanticRemoveWithRequest;
begin
  lRequest := Default(TDelphiSemanticRemoveWithRequest);
  lRequest.Options.ProjectFileName := FixturePath(
    'ProjectWithBinding\ProjectWithBinding.dproj');
  lRequest.Options.AdditionalSourceFileNames := [
    FixturePath('ProjectWithBinding\UnreferencedWithUnit.pas')];
  lRequest.BodyAnalysisSourceFileNames := [
    FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'),
    FixturePath('ProjectWithBinding\ProjectWithUnit.pas')];

  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lRequest);

  Assert.IsFalse(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
    'Remove-with request scope must suppress bindings for non-scoped source files.');
  Assert.IsTrue(HasProjectSymbol(lFacts, 'TUnreferencedRecord', 'declaration'),
    'Remove-with request scope must still preserve declarations from loaded sources.');
end;

initialization
  TDUnitX.RegisterTestFixture(TApiTests);

end.
