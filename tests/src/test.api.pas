unit Test.Api;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api;

type
  [TestFixture]
  TApiTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    function TryFindDiagnostic(const aResult: TDelphiSemanticContextResult;
      const aCode: string; out aDiagnostic: TDelphiSemanticDiagnostic): Boolean;
  public
    [Test]
    procedure LoadsProjectContextThroughStableFacade;
    [Test]
    procedure LoadProjectContextMergesApiSearchPaths;
    [Test]
    procedure LoadProjectContextReportsExplicitLspEnrichmentStatus;
  end;

implementation

uses
  System.IOUtils, System.SysUtils;

function TApiTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
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

initialization
  TDUnitX.RegisterTestFixture(TApiTests);

end.
