unit Test.ProjectMsBuild;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.ProjectContext;

type
  [TestFixture]
  TProjectMsBuildTests = class
  private
    function ContainsPath(const aItems: TArray<string>; const aExpectedPath: string): Boolean;
    function ContainsText(const aItems: TArray<string>; const aExpectedText: string): Boolean;
    function HasDiagnostic(const aResult: TDelphiSemanticContextResult; const aCode: string): Boolean;
    function HasUnresolvedMacro(const aItems: TArray<string>): Boolean;
    function PathIndex(const aItems: TArray<string>; const aExpectedPath: string): Integer;
  public
    [Test]
    procedure DebugContextAppliesOptsetAndNormalizesPaths;
    [Test]
    procedure ContextFingerprintChangesWithSemanticInputs;
    [Test]
    procedure ContextIncludesIncludePathsCompilerProfileAndFingerprint;
    [Test]
    procedure MigratedDakConditionCasesApplyExpectedProperties;
    [Test]
    procedure MigratedDakImportAndSelfReferenceCasesApplyExpectedProperties;
    [Test]
    procedure MigratedDakInvalidConditionCasesProduceDiagnostics;
    [Test]
    procedure OptionsSelectActiveConfigurationAndPlatform;
    [Test]
    procedure TargetPlatformCompilerDefinesUseRequestedPlatform;
    [Test]
    procedure ExplicitPlatformOverridesProjectPlatformProperty;
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
    [Test]
    procedure OptionsExposeDelphiVersionAndEnvironmentProperties;
    [Test]
    procedure SourceLookupPathsMergeReferencesBeforeSearchPaths;
    [Test]
    procedure PublicMacroExpansionRecursesAndReportsUnknowns;
    [Test]
    procedure PublicConditionEvaluationMatchesDakFunctionCases;
    [Test]
    procedure PublicConditionEvaluationKeepsDakBooleanLiteralCases;
    [Test]
    procedure DakNamespaceAndPluralAliasesFeedSemanticLists;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  Test.Support;

var
  GProjectMsBuildTempRoot: string;

function ProjectMsBuildTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GProjectMsBuildTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GProjectMsBuildTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'project-msbuild-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GProjectMsBuildTempRoot);
  Result := TPath.Combine(GProjectMsBuildTempRoot, aName);
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

function HasAnyInvalidConditionDiagnostic(const aResult: TDelphiSemanticContextResult): Boolean;
var
  lDiagnostic: TDelphiSemanticDiagnostic;
begin
  for lDiagnostic in aResult.Diagnostics do
    if SameText(lDiagnostic.Code, 'INVALID_MSBUILD_CONDITION') then
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

function TProjectMsBuildTests.PathIndex(const aItems: TArray<string>;
  const aExpectedPath: string): Integer;
var
  i: Integer;
  lExpectedPath: string;
begin
  lExpectedPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(aExpectedPath));
  for i := 0 to High(aItems) do
    if SameText(ExcludeTrailingPathDelimiter(TPath.GetFullPath(aItems[i])), lExpectedPath) then
      Exit(i);

  Result := -1;
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

procedure TProjectMsBuildTests.ContextFingerprintChangesWithSemanticInputs;
var
  lDebugOptions: TDelphiSemanticOptions;
  lDebugResult: TDelphiSemanticContextResult;
  lReleaseOptions: TDelphiSemanticOptions;
  lReleaseResult: TDelphiSemanticContextResult;
begin
  lDebugOptions := Default(TDelphiSemanticOptions);
  lDebugOptions.Configuration := 'Debug';
  lDebugOptions.Platform := 'Win32';
  lDebugOptions.DelphiVersion := '23.0';

  lReleaseOptions := lDebugOptions;
  lReleaseOptions.Configuration := 'Release';

  lDebugResult := TDelphiSemanticProject.Load(
    FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'), lDebugOptions);
  lReleaseResult := TDelphiSemanticProject.Load(
    FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'), lReleaseOptions);

  Assert.IsTrue(lDebugResult.Success);
  Assert.IsTrue(lReleaseResult.Success);
  Assert.AreNotEqual('', lDebugResult.Project.ContextFingerprint);
  Assert.AreNotEqual(lDebugResult.Project.ContextFingerprint,
    lReleaseResult.Project.ContextFingerprint);
end;

procedure TProjectMsBuildTests.ContextIncludesIncludePathsCompilerProfileAndFingerprint;
var
  lOptions: TDelphiSemanticOptions;
  lProjectDir: string;
  lResult: TDelphiSemanticContextResult;
begin
  lProjectDir := FixturePath('ProjectContext\MsBuild');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';
  lOptions.DelphiVersion := '23.0';

  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'),
    lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsPath(lResult.Project.IncludePaths, TPath.Combine(lProjectDir, 'Includes')));
  Assert.IsTrue(ContainsPath(lResult.Project.IncludePaths,
    TPath.Combine(lProjectDir, 'SharedIncludes')));
  Assert.AreEqual('Delphi-23.0-Win32-Debug', lResult.Project.CompilerProfileName);
  Assert.AreNotEqual('', lResult.Project.ContextFingerprint);
end;

procedure TProjectMsBuildTests.MigratedDakConditionCasesApplyExpectedProperties;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'LITERAL_COMPARISON_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'COMPACT_OR_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'NOT_EQUAL_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'EXISTS_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'NOT_EXISTS_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'NOT_TRAILING_SLASH_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'TRAILING_SLASH_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'UNQUOTED_HAS_TRAILING_SLASH_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'PARENTHESIZED_OR_DEFINE'));
end;

procedure TProjectMsBuildTests.MigratedDakImportAndSelfReferenceCasesApplyExpectedProperties;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'IMPORTED_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'IMPORT_ORDER_DEFINE'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'POST_IMPORT_OVERRIDE_DEFINE'));
  Assert.IsFalse(ContainsText(lResult.Project.Defines, 'LANGDIR_SHOULD_NOT_APPLY'));
  Assert.AreEqual('echo before', lResult.Project.PropertyValue('PreBuildEvent'));
  Assert.AreEqual('project', lResult.Project.PropertyValue('ImportedOverride'));
end;

procedure TProjectMsBuildTests.MigratedDakInvalidConditionCasesProduceDiagnostics;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\InvalidConditionProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(HasAnyInvalidConditionDiagnostic(lResult));
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

procedure TProjectMsBuildTests.TargetPlatformCompilerDefinesUseRequestedPlatform;
var
  lLinuxOptions: TDelphiSemanticOptions;
  lLinuxResult: TDelphiSemanticContextResult;
  lWin32Options: TDelphiSemanticOptions;
  lWin32Result: TDelphiSemanticContextResult;
begin
  lLinuxOptions := Default(TDelphiSemanticOptions);
  lLinuxOptions.Configuration := 'Debug';
  lLinuxOptions.Platform := 'Linux64';
  lLinuxOptions.DelphiVersion := '23.0';

  lWin32Options := lLinuxOptions;
  lWin32Options.Platform := 'Win32';

  lLinuxResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'),
    lLinuxOptions);
  lWin32Result := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'),
    lWin32Options);

  Assert.IsTrue(lLinuxResult.Success);
  Assert.IsTrue(ContainsText(lLinuxResult.Project.Defines, 'PROJECT_DEBUG'), 'PROJECT_DEBUG');
  Assert.IsTrue(ContainsText(lLinuxResult.Project.Defines, 'LINUX'), 'LINUX');
  Assert.IsTrue(ContainsText(lLinuxResult.Project.Defines, 'POSIX'), 'POSIX');
  Assert.IsTrue(ContainsText(lLinuxResult.Project.Defines, 'CPUX64'), 'CPUX64');
  Assert.IsFalse(ContainsText(lLinuxResult.Project.Defines, 'MSWINDOWS'), 'MSWINDOWS');
  Assert.IsFalse(ContainsText(lLinuxResult.Project.Defines, 'WIN32'), 'WIN32');

  Assert.IsTrue(lWin32Result.Success);
  Assert.IsTrue(ContainsText(lWin32Result.Project.Defines, 'MSWINDOWS'), 'MSWINDOWS');
  Assert.IsTrue(ContainsText(lWin32Result.Project.Defines, 'WIN32'), 'WIN32');
  Assert.IsTrue(ContainsText(lWin32Result.Project.Defines, 'CPUX86'), 'CPUX86');
  Assert.IsFalse(ContainsText(lWin32Result.Project.Defines, 'LINUX'), 'LINUX');
  Assert.IsFalse(ContainsText(lWin32Result.Project.Defines, 'POSIX'), 'POSIX');
end;

procedure TProjectMsBuildTests.ExplicitPlatformOverridesProjectPlatformProperty;
var
  lOptions: TDelphiSemanticOptions;
  lProjectPath: string;
  lResult: TDelphiSemanticContextResult;
  lRoot: string;
begin
  lRoot := ProjectMsBuildTempPath('project-platform-override');
  TDirectory.CreateDirectory(lRoot);

  TFile.WriteAllText(TPath.Combine(lRoot, 'PlatformOverride.dpr'),
    'program PlatformOverride;' + sLineBreak +
    'begin' + sLineBreak +
    'end.', TEncoding.UTF8);
  lProjectPath := TPath.Combine(lRoot, 'PlatformOverride.dproj');
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + sLineBreak +
    '  <PropertyGroup>' + sLineBreak +
    '    <MainSource>PlatformOverride.dpr</MainSource>' + sLineBreak +
    '    <Platform>Win32</Platform>' + sLineBreak +
    '    <DCC_Define>PROJECT_OVERRIDE</DCC_Define>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    '</Project>', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Linux64';
  lOptions.DelphiVersion := '23.0';

  lResult := TDelphiSemanticProject.Load(lProjectPath, lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('Linux64', lResult.Project.Platform);
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'PROJECT_OVERRIDE'), 'PROJECT_OVERRIDE');
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'LINUX'), 'LINUX');
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'POSIX'), 'POSIX');
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'CPUX64'), 'CPUX64');
  Assert.IsFalse(ContainsText(lResult.Project.Defines, 'MSWINDOWS'), 'MSWINDOWS');
  Assert.IsFalse(ContainsText(lResult.Project.Defines, 'WIN32'), 'WIN32');
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

procedure TProjectMsBuildTests.OptionsExposeDelphiVersionAndEnvironmentProperties;
var
  lEnv: TDelphiSemanticProperty;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticContextResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';
  lOptions.DelphiVersion := '23.0';
  lEnv.Name := 'ExternalDefine';
  lEnv.Value := 'ENVIRONMENT_DEFINE';
  lOptions.EnvironmentVariables := [lEnv];

  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'),
    lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('23.0', lResult.Project.PropertyValue('DelphiVersion'));
  Assert.IsTrue(ContainsText(lResult.Project.Defines, 'ENVIRONMENT_DEFINE'));
end;

procedure TProjectMsBuildTests.SourceLookupPathsMergeReferencesBeforeSearchPaths;
var
  lProjectDir: string;
  lReferenceIndex: Integer;
  lResult: TDelphiSemanticContextResult;
  lSearchIndex: Integer;
begin
  lProjectDir := FixturePath('ProjectContext\MsBuild');
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  lReferenceIndex := PathIndex(lResult.Project.SourceLookupPaths,
    TPath.Combine(lProjectDir, 'Source'));
  lSearchIndex := PathIndex(lResult.Project.SourceLookupPaths,
    TPath.Combine(lProjectDir, 'Generated'));
  Assert.IsTrue(lReferenceIndex >= 0, 'Expected reference directory in source lookup paths.');
  Assert.IsTrue(lSearchIndex >= 0, 'Expected DCC search path in source lookup paths.');
  Assert.IsTrue(lReferenceIndex < lSearchIndex,
    'Expected DCCReference directories before DCC_UnitSearchPath entries.');
end;

procedure TProjectMsBuildTests.PublicMacroExpansionRecursesAndReportsUnknowns;
var
  lDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  lProperties: TArray<TDelphiSemanticProperty>;
begin
  SetLength(lProperties, 2);
  lProperties[0].Name := 'OuterValue';
  lProperties[0].Value := 'prefix-$(InnerValue)';
  lProperties[1].Name := 'InnerValue';
  lProperties[1].Value := 'expanded';

  Assert.AreEqual('prefix-expanded|$(MissingValue)', TDelphiSemanticMsBuild.ExpandMacros(
    '$(OuterValue)|$(MissingValue)', lProperties, nil, False, lDiagnostics));
  Assert.AreEqual(1, Integer(Length(lDiagnostics)));
  Assert.AreEqual('UNRESOLVED_MSBUILD_MACRO', lDiagnostics[0].Code);
end;

procedure TProjectMsBuildTests.PublicConditionEvaluationMatchesDakFunctionCases;
var
  lDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  lError: string;
  lProperties: TArray<TDelphiSemanticProperty>;
  lResult: Boolean;
begin
  SetLength(lProperties, 1);
  lProperties[0].Name := 'Config';
  lProperties[0].Value := 'Debug';

  Assert.IsTrue(TDelphiSemanticMsBuild.TryEvaluateCondition(
    '''$(Config)''==''Debug'' and !HasTrailingSlash(C:\Build Output)',
    FixturePath('ProjectContext\MsBuild'), lProperties, nil, lResult, lError, lDiagnostics), lError);
  Assert.IsTrue(lResult);
  Assert.AreEqual(0, Integer(Length(lDiagnostics)));
end;

procedure TProjectMsBuildTests.PublicConditionEvaluationKeepsDakBooleanLiteralCases;
var
  lDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  lError: string;
  lResult: Boolean;
begin
  Assert.IsTrue(TDelphiSemanticMsBuild.TryEvaluateCondition('true',
    FixturePath('ProjectContext\MsBuild'), nil, nil, lResult, lError, lDiagnostics), lError);
  Assert.IsTrue(lResult);

  Assert.IsTrue(TDelphiSemanticMsBuild.TryEvaluateCondition('!(''Debug''==''Release'')',
    FixturePath('ProjectContext\MsBuild'), nil, nil, lResult, lError, lDiagnostics), lError);
  Assert.IsTrue(lResult);

  Assert.IsTrue(TDelphiSemanticMsBuild.TryEvaluateCondition('!true or true',
    FixturePath('ProjectContext\MsBuild'), nil, nil, lResult, lError, lDiagnostics), lError);
  Assert.IsTrue(lResult, 'Expected unary ! to bind tighter than or.');

  Assert.IsTrue(TDelphiSemanticMsBuild.TryEvaluateCondition('!false and false',
    FixturePath('ProjectContext\MsBuild'), nil, nil, lResult, lError, lDiagnostics), lError);
  Assert.IsFalse(lResult, 'Expected unary ! to bind tighter than and.');
end;

procedure TProjectMsBuildTests.DakNamespaceAndPluralAliasesFeedSemanticLists;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\MsBuild\MsBuildProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsText(lResult.Project.UnitScopeNames, 'Namespace.Scope'),
    'Expected DCC_Namespace to feed semantic unit scopes.');
  Assert.IsTrue(ContainsText(lResult.Project.UnitAliases, 'Project.PluralLegacy=Project.PluralModern'),
    'Expected DCC_UnitAliases to feed semantic aliases.');
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectMsBuildTests);

end.
