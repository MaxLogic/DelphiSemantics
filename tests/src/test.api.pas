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

initialization
  TDUnitX.RegisterTestFixture(TApiTests);

end.
