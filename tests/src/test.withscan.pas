unit Test.WithScan;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.Model, DelphiSemantics.WithScan;

type
  [TestFixture]
  TWithScanTests = class
  private
  public
    [Test]
    [TestCase('Scanner Nested parent', '0,True')]
    [TestCase('Scanner Nested child', '1,True')]
    [TestCase('Scanner Conditional cast', '2,True')]
    [TestCase('Scanner Supported compound', '3,True')]
    [TestCase('Scanner Supported conditional', '4,True')]
    [TestCase('Scanner Literal and comment', '5,True')]
    [TestCase('Model Nested parent', '0,False')]
    [TestCase('Model Nested child', '1,False')]
    [TestCase('Model Conditional cast', '2,False')]
    [TestCase('Model Supported compound', '3,False')]
    [TestCase('Model Supported conditional', '4,False')]
    [TestCase('Model Literal and comment', '5,False')]
    procedure ModelAndScannerPreserveBodyRanges(const aCase: Integer; const aLightweight: Boolean);
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

procedure TWithScanTests.ModelAndScannerPreserveBodyRanges(
  const aCase: Integer; const aLightweight: Boolean);
const
  cStartLines: array[0..5] of Integer = (23, 25, 35, 48, 57, 69);
  cStartColumns: array[0..5] of Integer = (5, 7, 3, 5, 3, 3);
  cEndLines: array[0..5] of Integer = (29, 28, 42, 51, 64, 70);
  cEndColumns: array[0..5] of Integer = (7, 9, 17, 7, 17, 37);
var
  i: Integer;
  lExpected: string;
  lLines: TArray<string>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticWithScanOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lResult: TDelphiSemanticWithScanResult;
  lStatement: TDelphiSemanticWithStatement;
  lStatements: TArray<TDelphiSemanticWithStatement>;
begin
  lOptions := Default(TDelphiSemanticWithScanOptions);
  lOptions.SourceFileName := FixturePath('RemoveWithBodyRanges', 'BodyRangesUnit.pas');
  lOptions.ProjectContextApplied := True;
  if aLightweight then
  begin
    lResult := TDelphiSemanticWithScanner.ScanFile(lOptions);
    Assert.IsTrue(lResult.Success);
    Assert.IsFalse(lResult.ProjectSessionUsed);
    lStatements := lResult.WithStatements;
  end else begin
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := lOptions.SourceFileName;
    lModelOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
    Assert.IsTrue(lModel.Success);
    lStatements := lModel.WithStatements;
  end;
  Assert.AreEqual(6, Integer(Length(lStatements)));
  lStatement := lStatements[aCase];
  Assert.AreEqual(cStartLines[aCase], lStatement.Line);
  Assert.AreEqual(cStartColumns[aCase], lStatement.Column);
  Assert.AreEqual(cEndLines[aCase], lStatement.EndLine, lStatement.Text);
  Assert.AreEqual(cEndColumns[aCase], lStatement.EndColumn, lStatement.Text);
  Assert.AreEqual(cEndLines[aCase], lStatement.BodyEndLine);
  Assert.AreEqual(cEndColumns[aCase], lStatement.BodyEndColumn);
  Assert.AreEqual(Integer(Ord(aCase = 1)), lStatement.NestingDepth);
  lLines := TFile.ReadAllLines(lOptions.SourceFileName, TEncoding.UTF8);
  lExpected := Copy(lLines[cStartLines[aCase] - 1], cStartColumns[aCase], MaxInt);
  for i := cStartLines[aCase] to cEndLines[aCase] - 2 do
    lExpected := lExpected + sLineBreak + lLines[i];
  lExpected := lExpected + sLineBreak +
    Copy(lLines[cEndLines[aCase] - 1], 1, cEndColumns[aCase]);
  Assert.AreEqual(lExpected, lStatement.Text);
  Assert.AreEqual(Copy(lExpected, Pos(sLineBreak, lExpected), MaxInt), lStatement.BodyText);
end;

initialization
  TDUnitX.RegisterTestFixture(TWithScanTests);

end.
