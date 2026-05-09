unit Test.GlobalVars;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.GlobalVars, DelphiSemantics.Model;

type
  [TestFixture]
  TGlobalVarsSemanticTests = class
  private
    function FixturePath(const aFileName: string): string;
    function LoadModel(const aFileName: string): TDelphiSemanticUnitModel;
    function HasDeclaration(const aAnalysis: TDelphiSemanticGlobalAnalysis;
      const aName, aKind: string): Boolean;
    function DeclarationColumn(const aAnalysis: TDelphiSemanticGlobalAnalysis;
      const aName, aKind: string): Integer;
    function CountUsages(const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName,
      aAccess: string): Integer;
    function CountUsagesInUnit(const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName,
      aAccess, aUnitName: string): Integer;
    function CountAmbiguities(const aAnalysis: TDelphiSemanticGlobalAnalysis;
      const aName: string): Integer;
    function DescribeGCounter(const aAnalysis: TDelphiSemanticGlobalAnalysis): string;
    function HasDiagnostic(const aAnalysis: TDelphiSemanticGlobalAnalysis;
      const aCode: string): Boolean;
  public
    [Test]
    procedure AnalyzesGlobalDeclarationsUsagesShadowingAndAmbiguity;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TGlobalVarsSemanticTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'GlobalVars', aFileName]));
end;

function TGlobalVarsSemanticTests.LoadModel(const aFileName: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath(aFileName);
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TGlobalVarsSemanticTests.HasDeclaration(
  const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName, aKind: string): Boolean;
var
  lDeclaration: TDelphiSemanticGlobalDeclaration;
begin
  for lDeclaration in aAnalysis.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, aKind) then
      Exit(True);

  Result := False;
end;

function TGlobalVarsSemanticTests.DeclarationColumn(
  const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName, aKind: string): Integer;
var
  lDeclaration: TDelphiSemanticGlobalDeclaration;
begin
  for lDeclaration in aAnalysis.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, aKind) then
      Exit(lDeclaration.Column);

  Result := 0;
end;

function TGlobalVarsSemanticTests.CountUsages(const aAnalysis: TDelphiSemanticGlobalAnalysis;
  const aName, aAccess: string): Integer;
var
  lUsage: TDelphiSemanticGlobalUsage;
begin
  Result := 0;
  for lUsage in aAnalysis.Usages do
    if SameText(lUsage.Name, aName) and SameText(lUsage.Access, aAccess) then
      Inc(Result);
end;

function TGlobalVarsSemanticTests.CountUsagesInUnit(
  const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName, aAccess,
  aUnitName: string): Integer;
var
  lUsage: TDelphiSemanticGlobalUsage;
begin
  Result := 0;
  for lUsage in aAnalysis.Usages do
    if SameText(lUsage.Name, aName) and SameText(lUsage.Access, aAccess) and
      SameText(lUsage.UnitName, aUnitName) then
      Inc(Result);
end;

function TGlobalVarsSemanticTests.CountAmbiguities(
  const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName: string): Integer;
var
  lAmbiguity: TDelphiSemanticGlobalAmbiguity;
begin
  Result := 0;
  for lAmbiguity in aAnalysis.Ambiguities do
    if SameText(lAmbiguity.Name, aName) then
      Inc(Result);
end;

function TGlobalVarsSemanticTests.DescribeGCounter(
  const aAnalysis: TDelphiSemanticGlobalAnalysis): string;
var
  lAmbiguity: TDelphiSemanticGlobalAmbiguity;
  lDeclaration: TDelphiSemanticGlobalDeclaration;
  lUsage: TDelphiSemanticGlobalUsage;
begin
  Result := '';
  for lDeclaration in aAnalysis.Declarations do
    if SameText(lDeclaration.Name, 'GCounter') then
      Result := Result + Format(' decl=%s/%s/%s', [lDeclaration.UnitName, lDeclaration.Kind,
        lDeclaration.SectionKind]);
  for lUsage in aAnalysis.Usages do
    if SameText(lUsage.Name, 'GCounter') then
      Result := Result + Format(' usage=%s/%s/%s', [lUsage.UnitName, lUsage.DeclaringUnitName,
        lUsage.Access]);
  for lAmbiguity in aAnalysis.Ambiguities do
    if SameText(lAmbiguity.Name, 'GCounter') then
      Result := Result + Format(' ambiguity=%s/%s', [lAmbiguity.UnitName,
        lAmbiguity.Candidates]);
end;

function TGlobalVarsSemanticTests.HasDiagnostic(
  const aAnalysis: TDelphiSemanticGlobalAnalysis; const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticGlobalDiagnostic;
begin
  for lDiagnostic in aAnalysis.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

procedure TGlobalVarsSemanticTests.AnalyzesGlobalDeclarationsUsagesShadowingAndAmbiguity;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lFiltered: TDelphiSemanticGlobalAnalysis;
  lFilters: TDelphiSemanticGlobalFilterOptions;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := [LoadModel('GlobalVarsFixture.Globals.pas'),
    LoadModel('GlobalVarsFixture.Consumer.pas')];

  lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(lModels);

  Assert.IsTrue(HasDeclaration(lAnalysis, 'GCounter', 'var'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GSecondCounter', 'var'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GThreadCounter', 'threadvar'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GOtherThreadCounter', 'threadvar'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GTypedValue', 'typedconst'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'sCache', 'classvar'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'sOtherCache', 'classvar'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GUnusedValue', 'var'));
  Assert.AreEqual(3, DeclarationColumn(lAnalysis, 'GCounter', 'var'));
  Assert.AreEqual(7, DeclarationColumn(lAnalysis, 'sCache', 'classvar'));
  Assert.IsTrue(DeclarationColumn(lAnalysis, 'GSecondCounter', 'var') >
    DeclarationColumn(lAnalysis, 'GCounter', 'var'));
  Assert.IsTrue(DeclarationColumn(lAnalysis, 'sOtherCache', 'classvar') >
    DeclarationColumn(lAnalysis, 'sCache', 'classvar'));
  Assert.AreEqual(1, CountUsages(lAnalysis, 'GThreadCounter', 'read'), 'GThreadCounter reads');
  Assert.AreEqual(1, CountUsages(lAnalysis, 'GCounter', 'readwrite'), 'GCounter readwrite');
  Assert.AreEqual(2, CountUsages(lAnalysis, 'sCache', 'write'), 'sCache writes');
  Assert.AreEqual(0, CountUsagesInUnit(lAnalysis, 'GTypedValue', 'read',
    'GlobalVarsFixture.Consumer'), 'consumer GTypedValue shadow');
  Assert.AreEqual(1, CountAmbiguities(lAnalysis, 'GCounter'), 'GCounter ambiguities' +
    DescribeGCounter(lAnalysis));

  lFilters := Default(TDelphiSemanticGlobalFilterOptions);
  lFilters.UnusedOnly := True;
  lFiltered := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(lModels, lFilters);

  Assert.IsTrue(HasDeclaration(lFiltered, 'GUnusedValue', 'var'));
  Assert.IsFalse(HasDeclaration(lFiltered, 'GTypedValue', 'typedconst'));

  lFilters := Default(TDelphiSemanticGlobalFilterOptions);
  lFilters.ReadsOnly := True;
  lFiltered := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(lModels, lFilters);

  Assert.IsTrue(HasDeclaration(lFiltered, 'GThreadCounter', 'threadvar'));
  Assert.IsFalse(HasDeclaration(lFiltered, 'sCache', 'classvar'));

  lFilters := Default(TDelphiSemanticGlobalFilterOptions);
  lFilters.WritesOnly := True;
  lFiltered := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(lModels, lFilters);

  Assert.IsTrue(HasDeclaration(lFiltered, 'sCache', 'classvar'));
  Assert.IsFalse(HasDeclaration(lFiltered, 'GTypedValue', 'typedconst'));

  lFilters := Default(TDelphiSemanticGlobalFilterOptions);
  lFilters.NamePattern := 'GThread*';
  lFiltered := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(lModels, lFilters);

  Assert.IsTrue(HasDeclaration(lFiltered, 'GThreadCounter', 'threadvar'));
  Assert.IsFalse(HasDeclaration(lFiltered, 'GCounter', 'var'));

  lModels := [Default(TDelphiSemanticUnitModel)];
  lModels[0].Success := False;
  lModels[0].FileName := 'missing.pas';
  lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(lModels);

  Assert.IsTrue(HasDiagnostic(lAnalysis, 'MODEL_FAILED'));
end;

initialization
  TDUnitX.RegisterTestFixture(TGlobalVarsSemanticTests);

end.
