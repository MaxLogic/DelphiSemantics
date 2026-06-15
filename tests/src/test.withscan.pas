unit Test.WithScan;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.WithScan;

type
  [TestFixture]
  TWithScanTests = class
  private
  public
    [Test]
    procedure ScannerReturnsWithStatementsWithoutProjectSession;
    [Test]
    procedure ApiFacadeReturnsLightweightWithScan;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils,
  Test.Support;


procedure TWithScanTests.ScannerReturnsWithStatementsWithoutProjectSession;
var
  lOptions: TDelphiSemanticWithScanOptions;
  lResult: TDelphiSemanticWithScanResult;
begin
  lOptions := Default(TDelphiSemanticWithScanOptions);
  lOptions.SourceFileName := FixturePath('WithDiscovery', 'WithDiscoveryUnit.pas');
  lOptions.ProjectContextApplied := True;

  lResult := TDelphiSemanticWithScanner.ScanFile(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(lResult.ProjectSessionUsed);
  Assert.AreEqual('WithDiscoveryUnit', lResult.UnitName);
  Assert.AreEqual(5, Integer(Length(lResult.WithStatements)));
  Assert.AreEqual('lFirst', lResult.WithStatements[0].SelectorText);
  Assert.AreEqual('lFirst, lSecond', lResult.WithStatements[1].SelectorText);
end;

procedure TWithScanTests.ApiFacadeReturnsLightweightWithScan;
var
  lOptions: TDelphiSemanticApiOptions;
  lResult: TDelphiSemanticWithScanResult;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.SourceFileName := FixturePath('WithDiscovery', 'WithDiscoveryUnit.pas');
  lOptions.ProjectContextApplied := True;

  lResult := TDelphiSemanticApi.ScanWithStatements(lOptions);

  Assert.IsTrue(lResult.Success);
  Assert.IsFalse(lResult.ProjectSessionUsed);
  Assert.AreEqual(5, Integer(Length(lResult.WithStatements)));
end;

initialization
  TDUnitX.RegisterTestFixture(TWithScanTests);

end.
