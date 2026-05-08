unit Test.ProjectMsBuild;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.ProjectContext;

type
  [TestFixture]
  TProjectMsBuildTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    function ContainsPath(const aItems: TArray<string>; const aExpectedPath: string): Boolean;
    function ContainsText(const aItems: TArray<string>; const aExpectedText: string): Boolean;
    function HasDiagnostic(const aResult: TDelphiSemanticContextResult; const aCode: string): Boolean;
    function HasUnresolvedMacro(const aItems: TArray<string>): Boolean;
  public
    [Test]
    procedure DebugContextAppliesOptsetAndNormalizesPaths;
    [Test]
    procedure OptionsSelectActiveConfigurationAndPlatform;
    [Test]
    procedure UnresolvedMacrosProduceDiagnostics;
    [Test]
    procedure InactiveCompoundConditionsAreSkipped;
    [Test]
    procedure ActiveParenthesizedAndConditionsAreApplied;
    [Test]
    procedure ActiveSplitParenthesizedAndConditionsAreApplied;
    [Test]
    procedure FinalSemanticListsDoNotContainUnresolvedMacros;
    [Test]
    procedure InactiveReferenceDirectoriesAreSkipped;
    [Test]
    procedure InactiveItemGroupReferenceDirectoriesAreSkipped;
    [Test]
    procedure UnresolvedReferenceMacrosDoNotCreateDirectories;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils;

function TProjectMsBuildTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
end;

function TProjectMsBuildTests.ContainsPath(const aItems: TArray<string>;
  const aExpectedPath: string): Boolean;
var
  lItem: string;
  lExpectedPath: string;
begin
  lExpectedPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(aExpectedPath));
  for lItem in aItems do
    if SameText(ExcludeTrailingPathDelimiter(TPath.GetFullPath(lItem)), lExpectedPath) then
      Exit(True);

  Result := False;
end;

function TProjectMsBuildTests.ContainsText(const aItems: TArray<string>;
  const aExpectedText: string): Boolean;
var
  lItem: string;
begin
  for lItem in aItems do
    if SameText(lItem, aExpectedText) then
      Exit(True);

  Result := False;
end;

function TProjectMsBuildTests.HasDiagnostic(const aResult: TDelphiSemanticContextResult;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  for lDiagnostic in aResult.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function TProjectMsBuildTests.HasUnresolvedMacro(const aItems: TArray<string>): Boolean;
var
  lItem: string;
begin
  for lItem in aItems do
    if Pos('$(', lItem) > 0 then
      Exit(True);

  Result := False;
end;

procedure TProjectMsBuildTests.DebugContextAppliesOptsetAndNormalizesPaths;
var
  lProjectDir: string;
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));
  lProjectDir := FixturePath('ProjectContext\MsBuild');

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('Debug', lResult.Project.Configuration);
  Assert.AreEqual('Win32', lResult.Project.Platform);
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'PROJECT_DEBUG'), 'PROJECT_DEBUG');
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'OPTSET_DEFINE'), 'OPTSET_DEFINE');
  Assert.IsTrue(ContainsPath(lResult.Project.SearchPaths, TPath.Combine(lProjectDir, 'Source')), 'Source path');
  Assert.IsTrue(ContainsPath(lResult.Project.SearchPaths, TPath.Combine(lProjectDir, 'Generated')), 'Generated path');
  Assert.IsTrue(ContainsPath(lResult.Project.SearchPaths, TPath.Combine(lProjectDir, 'OptsetUnits')), 'Optset path');
  Assert.IsTrue(ContainsText(lResult.Project.UnitScopeNames, 'Project.Scope'), 'Project scope');
  Assert.IsTrue(ContainsText(lResult.Project.UnitScopeNames, 'Optset.Scope'), 'Optset scope');
  Assert.IsTrue(ContainsText(lResult.Project.UnitAliases, 'Project.Legacy=Project.Modern'), 'Project alias');
  Assert.IsTrue(ContainsText(lResult.Project.UnitAliases, 'Optset.Legacy=Optset.Modern'), 'Optset alias');
  Assert.IsTrue(ContainsPath(lResult.Project.ReferenceDirectories, TPath.Combine(lProjectDir, 'Source')), 'Source reference');
  Assert.IsTrue(ContainsPath(lResult.Project.ReferenceDirectories, FixturePath('ProjectContext\Shared')), 'Shared reference');
end;

procedure TProjectMsBuildTests.OptionsSelectActiveConfigurationAndPlatform;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.Configuration := 'Release';
  lOptions.Platform := 'Win64';

  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'), lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('Release', lResult.Project.Configuration);
  Assert.AreEqual('Win64', lResult.Project.Platform);
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'PROJECT_RELEASE'));
  Assert.IsFalse(ContainsText(lResult.Project.Defines, 'PROJECT_DEBUG'));
end;

procedure TProjectMsBuildTests.UnresolvedMacrosProduceDiagnostics;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasDiagnostic(lResult, 'UNRESOLVED_MSBUILD_MACRO'));
end;

procedure TProjectMsBuildTests.InactiveCompoundConditionsAreSkipped;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(ContainsText(lResult.Project.Defines, 'INACTIVE_AND_DEFINE'));
end;

procedure TProjectMsBuildTests.ActiveParenthesizedAndConditionsAreApplied;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'ACTIVE_AND_DEFINE'));
end;

procedure TProjectMsBuildTests.ActiveSplitParenthesizedAndConditionsAreApplied;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'ACTIVE_SPLIT_PAREN_DEFINE'));
end;

procedure TProjectMsBuildTests.FinalSemanticListsDoNotContainUnresolvedMacros;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(HasUnresolvedMacro(lResult.Project.Defines), 'Defines');
  Assert.IsFalse(HasUnresolvedMacro(lResult.Project.UnitScopeNames), 'Unit scopes');
  Assert.IsFalse(HasUnresolvedMacro(lResult.Project.UnitAliases), 'Unit aliases');
end;

procedure TProjectMsBuildTests.InactiveReferenceDirectoriesAreSkipped;
var
  lProjectDir: string;
  lResult: TDelphiSemanticContextResult;
begin
  lProjectDir := FixturePath('ProjectContext\MsBuild');
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(ContainsPath(lResult.Project.ReferenceDirectories,
    TPath.Combine(lProjectDir, 'Inactive')));
end;

procedure TProjectMsBuildTests.InactiveItemGroupReferenceDirectoriesAreSkipped;
var
  lProjectDir: string;
  lResult: TDelphiSemanticContextResult;
begin
  lProjectDir := FixturePath('ProjectContext\MsBuild');
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(ContainsPath(lResult.Project.ReferenceDirectories,
    TPath.Combine(lProjectDir, 'InactiveGroup')));
end;

procedure TProjectMsBuildTests.UnresolvedReferenceMacrosDoNotCreateDirectories;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(ContainsPath(lResult.Project.ReferenceDirectories, '\'));
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectMsBuildTests);

end.
