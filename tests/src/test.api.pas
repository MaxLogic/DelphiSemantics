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
    procedure BuildsCacheBackedUnitIndexWithWithBindings;
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

procedure TApiTests.BuildsCacheBackedUnitIndexWithWithBindings;
var
  lIndex: TDelphiSemanticUnitIndex;
  lOptions: TDelphiSemanticApiOptions;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.SourceFileName := FixturePath('WithBinder\WithBinderUnit.pas');
  lOptions.ProjectContextApplied := True;

  lIndex := TDelphiSemanticApi.BuildUnitIndex(lOptions);

  Assert.IsTrue(lIndex.Success);
  Assert.AreEqual('WithBinderUnit', lIndex.Model.UnitName);
  Assert.IsTrue(Length(lIndex.Bindings) > 0, 'Expected stable facade to expose with bindings.');
  Assert.IsTrue(Length(lIndex.Inventory.Symbols) > 0, 'Expected stable facade to expose inventory symbols.');
  Assert.AreEqual('in-memory', lIndex.CacheMetrics.CacheKind);
end;

initialization
  TDUnitX.RegisterTestFixture(TApiTests);

end.
