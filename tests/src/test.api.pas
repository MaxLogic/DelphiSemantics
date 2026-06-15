unit Test.Api;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith, DelphiSemantics.Api.RemoveWith.Compatibility;

type
  [TestFixture]
  TApiTests = class
  private
    function HasBindingForUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): Boolean;
    function HasProjectSymbol(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass: string): Boolean;
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
    procedure CommonOptionsDoNotExposeRemoveWithBodyAnalysisScope;
    [Test]
    procedure RemoveWithPrimaryFacadeHidesInternalAliases;
    [Test]
    procedure RemoveWithRequestOwnsBodyAnalysisScope;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Test.Support;


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
