unit Test.UnitResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.UnitResolver;

type
  [TestFixture]
  TUnitResolverTests = class
  private
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function ProjectModel(const aUnitName, aFileName: string): TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ExplicitAliasResolvesToCanonicalTarget;
    [Test]
    procedure ExactScopedUnitNameResolvesWithoutNamespaceFallback;
    [Test]
    procedure NamespaceFallbackResolvesWindowsWhenCompilerContextSelectsWinapi;
    [Test]
    procedure SearchPathOrderChoosesFirstCompilerCandidate;
    [Test]
    procedure PrecompiledDcuCandidateResolvesWhenSourceIsMissing;
    [Test]
    procedure CompilerEquivalentProjectCandidatesReportAmbiguity;
    [Test]
    procedure DottedNameUsesCompilerNamespaceFallback;
  end;

implementation

uses
  System.IOUtils, System.SysUtils, System.Types,
  Winapi.Windows,
  maxLogic.IOUtils,
  Test.Support;

var
  GUnitResolverTempRoot: string;

function UnitResolverTempPath(const aName: string): string;
begin
  if GUnitResolverTempRoot = '' then
  begin
    GUnitResolverTempRoot := CreateTestTempRoot('unit-resolver-temp');
  end;
  TDirectory.CreateDirectory(GUnitResolverTempRoot);
  Result := TPath.Combine(GUnitResolverTempRoot, aName);
end;


function TUnitResolverTests.ProjectInfo: TDelphiSemanticProjectInfo;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('UnitResolver', 'UnitResolverProject.dproj'));
  Assert.IsTrue(lResult.Success);
  Result := lResult.Project;
end;

function TUnitResolverTests.ProjectModel(const aUnitName, aFileName: string):
  TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aFileName;
end;

procedure TUnitResolverTests.ExplicitAliasResolvesToCanonicalTarget;
var
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticUnitResolutionResult;
begin
  lProject := ProjectInfo;

  lResult := TDelphiSemanticUnitResolver.Resolve(lProject, 'LegacyAlias');

  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('AliasTarget', lResult.CanonicalUnitName);
  Assert.AreEqual('alias', lResult.MatchKind);
  Assert.AreEqual(FixturePath('UnitResolver', 'Alias\AliasTarget.pas'), lResult.FileName);
end;

procedure TUnitResolverTests.ExactScopedUnitNameResolvesWithoutNamespaceFallback;
var
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticUnitResolutionResult;
begin
  lProject := ProjectInfo;

  lResult := TDelphiSemanticUnitResolver.Resolve(lProject, 'Scoped.TargetUnit');

  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('Scoped.TargetUnit', lResult.CanonicalUnitName);
  Assert.AreEqual('exact', lResult.MatchKind);
  Assert.AreEqual(FixturePath('UnitResolver', 'Scoped\Scoped.TargetUnit.pas'), lResult.FileName);
end;

procedure TUnitResolverTests.NamespaceFallbackResolvesWindowsWhenCompilerContextSelectsWinapi;
var
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticUnitResolutionResult;
begin
  lProject := ProjectInfo;

  lResult := TDelphiSemanticUnitResolver.Resolve(lProject, 'Windows');

  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('Winapi.Windows', lResult.CanonicalUnitName);
  Assert.AreEqual('scope', lResult.MatchKind);
  Assert.AreEqual('Winapi', lResult.UnitScopeName);
  Assert.AreEqual(FixturePath('UnitResolver', 'Rtl\Winapi.Windows.pas'), lResult.FileName);
end;

procedure TUnitResolverTests.SearchPathOrderChoosesFirstCompilerCandidate;
var
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticUnitResolutionResult;
begin
  lProject := ProjectInfo;

  lResult := TDelphiSemanticUnitResolver.Resolve(lProject, 'DuplicateUnit');

  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('DuplicateUnit', lResult.CanonicalUnitName);
  Assert.AreEqual(FixturePath('UnitResolver', 'First\DuplicateUnit.pas'), lResult.FileName);
  Assert.AreEqual(2, lResult.SearchPathIndex);
end;

procedure TUnitResolverTests.PrecompiledDcuCandidateResolvesWhenSourceIsMissing;
var
  lDcuPath: string;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticUnitResolutionResult;
  lTempDir: string;
begin
  lTempDir := UnitResolverTempPath('precompiled-dcu');
  TDirectory.CreateDirectory(lTempDir);
  lDcuPath := TPath.Combine(lTempDir, 'PackageOnly.dcu');
  TFile.WriteAllBytes(lDcuPath, TBytes.Create(1, 2, 3, 4));
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectDirectory := lTempDir;
  lProject.SearchPaths := [lTempDir];

  lResult := TDelphiSemanticUnitResolver.Resolve(lProject, 'PackageOnly');

  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('PackageOnly', lResult.CanonicalUnitName);
  Assert.AreEqual(lDcuPath, lResult.FileName);
  Assert.AreEqual('precompiled', lResult.SourceKind);
end;

procedure TUnitResolverTests.CompilerEquivalentProjectCandidatesReportAmbiguity;
var
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticUnitResolutionResult;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lProject := ProjectInfo;
  lModels := [
    ProjectModel('AmbiguousUnit', FixturePath('UnitResolver', 'First\AmbiguousUnit.pas')),
    ProjectModel('AmbiguousUnit', FixturePath('UnitResolver', 'Second\AmbiguousUnit.pas'))];

  lResult := TDelphiSemanticUnitResolver.Resolve(lProject, 'AmbiguousUnit', lModels);

  Assert.IsFalse(lResult.Found);
  Assert.IsTrue(lResult.Ambiguous);
  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.AreEqual(2, Integer(Length(lResult.Candidates)));
end;

procedure TUnitResolverTests.DottedNameUsesCompilerNamespaceFallback;
var
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticUnitResolutionResult;
begin
  lProject := ProjectInfo;
  lProject.UnitScopeNames := ['System'];
  lResult := TDelphiSemanticUnitResolver.Resolve(lProject, 'Generics.Collections',
    [ProjectModel('System.Generics.Collections', 'System.Generics.Collections.pas')]);
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('System.Generics.Collections', lResult.CanonicalUnitName);
end;

initialization
  TDUnitX.RegisterTestFixture(TUnitResolverTests);

end.
