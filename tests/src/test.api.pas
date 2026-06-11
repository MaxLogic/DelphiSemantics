unit Test.Api;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TApiTests = class
  private
    function FixturePath(const aRelativePath: string): string;
  public
    [Test]
    procedure LoadsProjectContextThroughStableFacade;
    [Test]
    procedure LoadProjectContextMergesApiSearchPaths;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Api;

function TApiTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
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

initialization
  TDUnitX.RegisterTestFixture(TApiTests);

end.
