unit Test.ProjectContext;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TProjectContextTests = class
  private
    function FixturePath(const aRelativePath: string): string;
  public
    [Test]
    procedure DprojResolvesBasicMetadata;
    [Test]
    procedure DprResolvesThroughSiblingDproj;
    [Test]
    procedure MissingProjectReturnsDeterministicDiagnostic;
  end;

implementation

uses
  System.IOUtils,
  System.SysUtils,
  DelphiSemantics.ProjectContext;

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
