unit Test.ProjectContext;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TProjectContextTests = class
  private
    function ContainsPath(const aItems: TArray<string>; const aExpectedPath: string): Boolean;
    function FixturePath(const aRelativePath: string): string;
  public
    [Test]
    procedure DprojResolvesBasicMetadata;
    [Test]
    procedure DprResolvesThroughSiblingDproj;
    [Test]
    procedure StaleDccReferenceResolvesThroughSearchPath;
    [Test]
    procedure MissingProjectReturnsDeterministicDiagnostic;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  DelphiSemantics.ProjectContext;

function TProjectContextTests.ContainsPath(const aItems: TArray<string>;
  const aExpectedPath: string): Boolean;
var
  lExpectedPath: string;
  lItem: string;
begin
  lExpectedPath := ExcludeTrailingPathDelimiter(TPath.GetFullPath(aExpectedPath));
  for lItem in aItems do
    if SameText(ExcludeTrailingPathDelimiter(TPath.GetFullPath(lItem)), lExpectedPath) then
      Exit(True);

  Result := False;
end;

function TProjectContextTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
end;

procedure TProjectContextTests.DprojResolvesBasicMetadata;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\Basic\BasicProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('BasicProject', lResult.Project.ProjectName);
  Assert.AreEqual('Release', lResult.Project.Configuration);
  Assert.AreEqual('Win64', lResult.Project.Platform);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dproj'), lResult.Project.ProjectFileName);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dpr'), lResult.Project.MainSourceFileName);
end;

procedure TProjectContextTests.StaleDccReferenceResolvesThroughSearchPath;
var
  lProjectDir: string;
  lResult: TDelphiSemanticContextResult;
begin
  lProjectDir := FixturePath('ProjectContext\DccReferenceFallback');
  lResult := TDelphiSemanticProject.Load(TPath.Combine(lProjectDir,
    'DccReferenceFallbackProject.dproj'));

  Assert.IsTrue(lResult.Success);
  Assert.IsTrue(ContainsPath(lResult.Project.ReferenceDirectories,
    TPath.Combine(lProjectDir, 'RealLib')), 'Expected fallback unit directory from search path.');
  Assert.IsFalse(ContainsPath(lResult.Project.ReferenceDirectories,
    TPath.Combine(lProjectDir, 'OldLocation')), 'Stale DCCReference directory must not be retained.');
end;

procedure TProjectContextTests.DprResolvesThroughSiblingDproj;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\Basic\BasicProject.dpr'));

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dproj'), lResult.Project.ProjectFileName);
  Assert.AreEqual(FixturePath('ProjectContext\Basic\BasicProject.dpr'), lResult.Project.MainSourceFileName);
end;

procedure TProjectContextTests.MissingProjectReturnsDeterministicDiagnostic;
var
  lResult: TDelphiSemanticContextResult;
begin
  lResult := TDelphiSemanticProject.Load(FixturePath('ProjectContext\Missing\MissingProject.dproj'));

  Assert.IsFalse(lResult.Success);
  Assert.AreEqual(1, Length(lResult.Diagnostics));
  Assert.AreEqual('PROJECT_FILE_NOT_FOUND', lResult.Diagnostics[0].Code);
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectContextTests);

end.
