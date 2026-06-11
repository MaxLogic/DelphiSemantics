unit Test.WithDiscovery;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model;

type
  [TestFixture]
  TWithDiscoveryTests = class
  private
    function FixturePath(const aFileName: string): string;
    function LoadModel(const aFileName: string;
      const aDefines: TArray<string> = nil): TDelphiSemanticUnitModel;
    function TempPath(const aName: string): string;
  public
    [Test]
    procedure DiscoversSingleMultipleNestedAndScopedWithStatements;
    [Test]
    procedure ReportsSelectorBodyAndWholeWithRanges;
    [Test]
    procedure KeepsUtf8BomLineOneColumnMapping;
    [Test]
    procedure IgnoresInactiveConditionalBranches;
    [Test]
    procedure SourceModelCapturesDeclarationsAndRoutineScopes;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils;

var
  GWithDiscoveryTempRoot: string;

function WithDiscoveryTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GWithDiscoveryTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GWithDiscoveryTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'with-discovery-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GWithDiscoveryTempRoot);
  Result := GWithDiscoveryTempRoot;
end;

function TWithDiscoveryTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'WithDiscovery', aFileName]));
end;

function TWithDiscoveryTests.LoadModel(const aFileName: string;
  const aDefines: TArray<string>): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath(aFileName);
  lOptions.ProjectContextApplied := True;
  lOptions.Defines := aDefines;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TWithDiscoveryTests.TempPath(const aName: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(WithDiscoveryTempRoot, aName));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
end;

procedure TWithDiscoveryTests.DiscoversSingleMultipleNestedAndScopedWithStatements;
var
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel('WithDiscoveryUnit.pas');

  Assert.AreEqual(5, Integer(Length(lModel.WithStatements)));
  Assert.AreEqual('lFirst', lModel.WithStatements[0].SelectorText);
  Assert.AreEqual(1, lModel.WithStatements[0].SelectorCount);
  Assert.AreEqual(0, lModel.WithStatements[0].NestingDepth);
  Assert.AreEqual('lFirst, lSecond', lModel.WithStatements[1].SelectorText);
  Assert.AreEqual(2, lModel.WithStatements[1].SelectorCount);
  Assert.AreEqual(0, lModel.WithStatements[2].NestingDepth);
  Assert.AreEqual(1, lModel.WithStatements[3].NestingDepth);
  Assert.IsTrue(lModel.WithStatements[4].HasScopedDeclaration);
end;

procedure TWithDiscoveryTests.ReportsSelectorBodyAndWholeWithRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lStatement: TDelphiSemanticWithStatement;
begin
  lModel := LoadModel('WithDiscoveryUnit.pas');
  lStatement := lModel.WithStatements[1];

  Assert.AreEqual(23, lStatement.Line);
  Assert.IsTrue(lStatement.EndLine > lStatement.Line);
  Assert.AreEqual(23, lStatement.BodyLine);
  Assert.IsTrue(Pos('Shared := Value', lStatement.BodyText) > 0, lStatement.BodyText);
  Assert.IsTrue(Pos('with lFirst, lSecond do', lStatement.Text) > 0, lStatement.Text);
end;

procedure TWithDiscoveryTests.KeepsUtf8BomLineOneColumnMapping;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('BomWithUnit.pas');
  TFile.WriteAllText(lPath, 'unit BomWithUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TBomRecord = record Value: Integer; end;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure Run;' + sLineBreak + 'var' + sLineBreak +
    '  lValue: TBomRecord;' + sLineBreak + 'begin' + sLineBreak + '  with lValue do' +
    sLineBreak + '    Value := 1;' + sLineBreak + 'end;' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.AreEqual(10, lModel.WithStatements[0].Line);
  Assert.AreEqual(3, lModel.WithStatements[0].Column);
end;

procedure TWithDiscoveryTests.IgnoresInactiveConditionalBranches;
var
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel('WithDiscoveryUnit.pas');
  Assert.AreEqual(5, Integer(Length(lModel.WithStatements)));

  lModel := LoadModel('WithDiscoveryUnit.pas', ['INCLUDE_INACTIVE_WITH']);
  Assert.AreEqual(6, Integer(Length(lModel.WithStatements)));
  Assert.AreEqual('lSecond', lModel.WithStatements[5].SelectorText);
end;

procedure TWithDiscoveryTests.SourceModelCapturesDeclarationsAndRoutineScopes;
var
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel('WithDiscoveryUnit.pas');

  Assert.AreEqual('WithDiscoveryUnit', lModel.UnitName);
  Assert.IsTrue(Length(lModel.Declarations) >= 2);
  Assert.IsTrue(Length(lModel.Routines) >= 1);
  Assert.IsTrue(Length(lModel.Locals) >= 2);
  Assert.AreEqual('RunDiscovery', lModel.Routines[0].Name);
  Assert.AreEqual('lFirst', lModel.Locals[0].Name);
end;

initialization
  TDUnitX.RegisterTestFixture(TWithDiscoveryTests);

end.
