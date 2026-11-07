unit Test.GlobalVars;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.GlobalVars, DelphiSemantics.Model,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TGlobalVarsSemanticTests = class
  private
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
    function HasUsageInRoutine(const aAnalysis: TDelphiSemanticGlobalAnalysis;
      const aName, aRoutineName: string): Boolean;
    function HasUsageForOwner(const aAnalysis: TDelphiSemanticGlobalAnalysis;
      const aName, aOwnerName: string): Boolean;
    function DescribeGCounter(const aAnalysis: TDelphiSemanticGlobalAnalysis): string;
    function DescribeDeclarations(const aAnalysis: TDelphiSemanticGlobalAnalysis): string;
    function HasDiagnostic(const aAnalysis: TDelphiSemanticGlobalAnalysis;
      const aCode: string): Boolean;
  public
    [Test]
    [TestCase('Direct unknown position', 'direct,unknown')]
    [TestCase('Direct file', 'direct,file')]
    [TestCase('Direct access', 'direct,access')]
    [TestCase('Direct distinct', 'direct,distinct')]
    [TestCase('Direct inactive', 'direct,inactive')]
    [TestCase('Direct missing captured source', 'direct,missing')]
    procedure IncludeUsageUsesCapturedPhysicalEvidence(const aRoute, aCheck: string);
    [Category('Fast')]
    [Test]
    procedure AnalyzesGlobalDeclarationsUsagesShadowingAndAmbiguity;
    [Category('Fast')]
    [Test]
    procedure AnalyzesProjectSnapshotUsingSnapshotSourceText;
    [Category('Fast')]
    [Test]
    procedure SnapshotGlobalAnalysisDoesNotUseHiddenDuplicateFallback;
    [Category('Fast')]
    [Test]
    procedure SnapshotGlobalAnalysisUsesDeclarationRolesAndLexicalOwnership;
    [Category('Fast')]
    [Test]
    procedure SnapshotGlobalAnalysisDeduplicatesSemanticDeclarationIdentity;
    [Category('Fast')]
    [Test]
    procedure UsageAccessUsesModelSourceText;
    [Test]
    [TestCase('Repeated expansion', 'repeat')]
    [TestCase('Distinct columns', 'columns')]
    [TestCase('Scoped shadow', 'shadow')]
    [TestCase('Unavailable capture', 'unavailable')]
    [TestCase('Unknown physical column', 'position')]
    [TestCase('Duplicate routine scope', 'scope')]
    procedure IncludedUsagesKeepTokenAndScopeIdentity(const aShape: string);
    [Test]
    [TestCase('Failed model', 'ast-failed,False')]
    [TestCase('Failed snapshot', 'ast-failed,True')]
    [TestCase('Partial model', 'ast-interface-only,False')]
    [TestCase('Partial snapshot', 'ast-interface-only,True')]
    procedure UnverifiedClassVarsNeverBecomeGlobalDeclarations(const aStatus: string;
      const aSnapshot: Boolean);
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils,
  DelphiSemantics.Cache, DelphiSemantics.Snapshot.Builder, DelphiSemantics.WithBinding,
  Test.Support;


function TGlobalVarsSemanticTests.LoadModel(const aFileName: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('GlobalVars', aFileName);
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

function TGlobalVarsSemanticTests.HasUsageInRoutine(
  const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName,
  aRoutineName: string): Boolean;
var
  lUsage: TDelphiSemanticGlobalUsage;
begin
  for lUsage in aAnalysis.Usages do
    if SameText(lUsage.Name, aName) and SameText(lUsage.RoutineName, aRoutineName) then
      Exit(True);

  Result := False;
end;

function TGlobalVarsSemanticTests.HasUsageForOwner(
  const aAnalysis: TDelphiSemanticGlobalAnalysis; const aName,
  aOwnerName: string): Boolean;
var
  lDeclaration: TDelphiSemanticGlobalDeclaration;
  lUsage: TDelphiSemanticGlobalUsage;
begin
  for lDeclaration in aAnalysis.Declarations do
    if SameText(lDeclaration.Name, aName) and
      SameText(lDeclaration.OwnerName, aOwnerName) then
      for lUsage in aAnalysis.Usages do
        if SameText(lUsage.DeclaringSymbolId, lDeclaration.SymbolId) then
          Exit(True);

  Result := False;
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

function TGlobalVarsSemanticTests.DescribeDeclarations(
  const aAnalysis: TDelphiSemanticGlobalAnalysis): string;
var
  lDeclaration: TDelphiSemanticGlobalDeclaration;
begin
  Result := '';
  for lDeclaration in aAnalysis.Declarations do
    Result := Result + Format(' %s/%s', [lDeclaration.Name, lDeclaration.Kind]);
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

procedure TGlobalVarsSemanticTests.AnalyzesProjectSnapshotUsingSnapshotSourceText;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lBuildMetrics: TDelphiSnapshotBuilderMetrics;
  lBuildOptions: TDelphiSnapshotBuildOptions;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lModels := [LoadModel('GlobalVarsFixture.Globals.pas'),
    LoadModel('GlobalVarsFixture.Consumer.pas')];
  lModels[0].SourceText := StringReplace(lModels[0].SourceText, '  Inc(GCounter);',
    '  GCounter := 1;', []);
  lBuildOptions := Default(TDelphiSnapshotBuildOptions);
  lBuildOptions.ResolveReferenceTargets := True;
  lBuildOptions.WorkerCount := 1;
  lRemoveWithFacts := Default(TDelphiSemanticProjectWithBindingFacts);

  lSnapshot := BuildProjectSnapshotFromModels(lModels, lRemoveWithFacts, lBuildOptions,
    lBuildMetrics);
  try
    lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot);
  finally
    lSnapshot.Free;
  end;

  Assert.IsTrue(HasDeclaration(lAnalysis, 'GCounter', 'var'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'sCache', 'classvar'));
  Assert.AreEqual(1, CountUsagesInUnit(lAnalysis, 'GCounter', 'write',
    'GlobalVarsFixture.Globals'),
    'Snapshot source text should classify the mutated assignment as a write.');
  Assert.AreEqual(0, CountUsagesInUnit(lAnalysis, 'GCounter', 'readwrite',
    'GlobalVarsFixture.Globals'),
    'Snapshot analysis must not classify from the original disk Inc(GCounter).');
  Assert.AreEqual(1, CountUsages(lAnalysis, 'GThreadCounter', 'read'),
    'Snapshot target IDs should preserve cross-unit global reads.');
  Assert.AreEqual(2, CountUsages(lAnalysis, 'sCache', 'write'),
    'Snapshot target IDs should preserve qualified class-var writes.');
end;

procedure TGlobalVarsSemanticTests.SnapshotGlobalAnalysisDoesNotUseHiddenDuplicateFallback;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lBuildMetrics: TDelphiSnapshotBuilderMetrics;
  lBuildOptions: TDelphiSnapshotBuildOptions;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  lSnapshot: TDelphiProjectSnapshot;
begin
  SetLength(lModels, 3);
  lModels[0].UnitName := 'VisibleGlobals';
  lModels[0].FileName := 'VisibleGlobals.pas';
  lModels[0].SourceText := 'unit VisibleGlobals;' + sLineBreak + 'interface' +
    sLineBreak + 'threadvar' + sLineBreak + '  GSharedThread: Integer;' +
    sLineBreak + 'implementation' + sLineBreak + 'end.';
  SetLength(lModels[0].Declarations, 1);
  lModels[0].Declarations[0].Name := 'GSharedThread';
  lModels[0].Declarations[0].Kind := 'threadvar';
  lModels[0].Declarations[0].TypeName := 'Integer';
  lModels[0].Declarations[0].SectionKind := 'interface';
  lModels[0].Declarations[0].DeclarationRole := 'declaration';
  lModels[0].Declarations[0].ScopeKind := 'unit';
  lModels[0].Declarations[0].OwnerScopeId := 'visibleglobals';
  lModels[0].Declarations[0].SymbolId :=
    'visibleglobals|threadvar|gsharedthread';
  lModels[0].Declarations[0].Line := 4;
  lModels[0].Declarations[0].Column := 3;

  lModels[1].UnitName := 'HiddenGlobals';
  lModels[1].FileName := 'HiddenGlobals.pas';
  lModels[1].SourceText := 'unit HiddenGlobals;' + sLineBreak + 'interface' +
    sLineBreak + 'threadvar' + sLineBreak + '  GSharedThread: Integer;' +
    sLineBreak + 'implementation' + sLineBreak + 'end.';
  SetLength(lModels[1].Declarations, 1);
  lModels[1].Declarations[0].Name := 'GSharedThread';
  lModels[1].Declarations[0].Kind := 'threadvar';
  lModels[1].Declarations[0].TypeName := 'Integer';
  lModels[1].Declarations[0].SectionKind := 'interface';
  lModels[1].Declarations[0].DeclarationRole := 'declaration';
  lModels[1].Declarations[0].ScopeKind := 'unit';
  lModels[1].Declarations[0].OwnerScopeId := 'hiddenglobals';
  lModels[1].Declarations[0].SymbolId :=
    'hiddenglobals|threadvar|gsharedthread';
  lModels[1].Declarations[0].Line := 4;
  lModels[1].Declarations[0].Column := 3;

  lModels[2].UnitName := 'ThreadConsumer';
  lModels[2].FileName := 'ThreadConsumer.pas';
  lModels[2].ImplementationUses := ['VisibleGlobals'];
  lModels[2].SourceText := 'unit ThreadConsumer;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'uses VisibleGlobals;' +
    sLineBreak + 'procedure RunConsumer;' + sLineBreak + 'begin' + sLineBreak +
    '  if GSharedThread > 0 then' + sLineBreak + '  begin' + sLineBreak +
    '  end;' + sLineBreak + 'end;' + sLineBreak + 'end.';
  SetLength(lModels[2].Routines, 1);
  lModels[2].Routines[0].Name := 'RunConsumer';
  lModels[2].Routines[0].SectionKind := 'implementation';
  lModels[2].Routines[0].Line := 5;
  lModels[2].Routines[0].Column := 11;
  SetLength(lModels[2].References, 1);
  lModels[2].References[0].Name := 'GSharedThread';
  lModels[2].References[0].RoutineName := 'RunConsumer';
  lModels[2].References[0].Role := 'reference';
  lModels[2].References[0].SectionKind := 'implementation';
  lModels[2].References[0].Line := 7;
  lModels[2].References[0].Column := 6;
  lModels[2].References[0].EndLine := 7;
  lModels[2].References[0].EndColumn := 18;

  lBuildOptions := Default(TDelphiSnapshotBuildOptions);
  lBuildOptions.ResolveReferenceTargets := True;
  lBuildOptions.WorkerCount := 1;
  lRemoveWithFacts := Default(TDelphiSemanticProjectWithBindingFacts);

  lSnapshot := BuildProjectSnapshotFromModels(lModels, lRemoveWithFacts, lBuildOptions,
    lBuildMetrics);
  try
    lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot);
  finally
    lSnapshot.Free;
  end;

  Assert.AreEqual(1, CountUsages(lAnalysis, 'GSharedThread', 'read'),
    'Snapshot analysis should resolve the visible threadvar target.');
  Assert.AreEqual(0, CountAmbiguities(lAnalysis, 'GSharedThread'),
    'Hidden same-name globals must not inflate snapshot ambiguities.');
end;

procedure TGlobalVarsSemanticTests.SnapshotGlobalAnalysisUsesDeclarationRolesAndLexicalOwnership;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lBuildMetrics: TDelphiSnapshotBuilderMetrics;
  lBuildOptions: TDelphiSnapshotBuildOptions;
  lDeclaration: TDelphiSemanticDeclaration;
  lFoundMutable: Boolean;
  lGlobalDeclaration: TDelphiSemanticGlobalDeclaration;
  lModelDescription: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lModels := [LoadModel('GlobalVarsFixture.ScopeRoles.pas')];
  lFoundMutable := False;
  lModelDescription := '';
  for lDeclaration in lModels[0].Declarations do
  begin
    lModelDescription := lModelDescription + Format(' %s/%s/%s/%s/%s',
      [lDeclaration.Name, lDeclaration.Kind, lDeclaration.DeclarationRole,
      lDeclaration.ScopeKind, BoolToStr(lDeclaration.Mutable, True)]);
    if SameText(lDeclaration.Name, 'GMutableValue') then
    begin
      lFoundMutable := True;
      Assert.IsTrue(lDeclaration.Mutable, Format(
        'GMutableValue role=%s scope=%s line=%d rejected=%d status=%s',
        [lDeclaration.DeclarationRole, lDeclaration.ScopeKind, lDeclaration.Line,
        lModels[0].RejectedDeclarationCount, lModels[0].ScopeModelStatus]));
    end;
  end;
  Assert.IsTrue(lFoundMutable, 'Missing model declaration:' + lModelDescription);
  lBuildOptions := Default(TDelphiSnapshotBuildOptions);
  lBuildOptions.ResolveReferenceTargets := True;
  lBuildOptions.WorkerCount := 1;
  lRemoveWithFacts := Default(TDelphiSemanticProjectWithBindingFacts);

  lSnapshot := BuildProjectSnapshotFromModels(lModels, lRemoveWithFacts, lBuildOptions,
    lBuildMetrics);
  try
    try
      lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot);
    except
      on e: Exception do
        Assert.Fail('Snapshot analysis: ' + e.Message);
    end;
  finally
    lSnapshot.Free;
  end;

  Assert.AreEqual(5, Integer(Length(lAnalysis.Declarations)), 'Exact shared-state inventory:' +
    DescribeDeclarations(lAnalysis) + ' model:' + lModelDescription);
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GUnitValue', 'var'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GThreadValue', 'threadvar'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'GMutableValue', 'typedconst'));
  Assert.IsTrue(HasDeclaration(lAnalysis, 'sSharedValue', 'classvar'));
  Assert.IsTrue(HasUsageForOwner(lAnalysis, 'sSharedValue', 'TScopeStore'),
    'TScopeStore.sSharedValue usage must target its stable declaration identity.');
  Assert.IsTrue(HasUsageForOwner(lAnalysis, 'sSharedValue', 'TSecondScopeStore'),
    'TSecondScopeStore.sSharedValue usage must target its stable declaration identity.');
  for lGlobalDeclaration in lAnalysis.Declarations do
  begin
    Assert.AreEqual('declaration', lGlobalDeclaration.DeclarationRole);
    Assert.IsNotEmpty(lGlobalDeclaration.SymbolId);
    Assert.IsNotEmpty(lGlobalDeclaration.OwnerScopeId);
    if SameText(lGlobalDeclaration.Kind, 'classvar') then
    begin
      Assert.AreEqual('type', lGlobalDeclaration.ScopeKind);
      Assert.IsNotEmpty(lGlobalDeclaration.OwnerName);
    end else
      Assert.AreEqual('unit', lGlobalDeclaration.ScopeKind);
  end;
  Assert.IsFalse(HasDeclaration(lAnalysis, 'GImmutableValue', 'typedconst'));
  Assert.IsFalse(HasDeclaration(lAnalysis, 'lValue', 'var'));
  Assert.IsFalse(HasDeclaration(lAnalysis, 'Result', 'var'));
  Assert.IsFalse(HasDeclaration(lAnalysis, 'CaseSensitive', 'var'));
  Assert.IsFalse(HasDeclaration(lAnalysis, 'NameValueSeparator', 'var'));
  Assert.IsFalse(HasDeclaration(lAnalysis, 'fValue', 'var'));
  Assert.IsTrue(HasUsageInRoutine(lAnalysis, 'GUnitValue', 'BuildNumber'));
  Assert.IsTrue(HasUsageInRoutine(lAnalysis, 'GMutableValue', 'TScopeStore.WriteField'));
  Assert.IsTrue(HasUsageInRoutine(lAnalysis, 'GThreadValue', 'TouchNested'));
  Assert.AreEqual(0, CountAmbiguities(lAnalysis, 'GThreadValue'),
    'Nested local shadow must resolve before global candidates.');
  Assert.AreEqual('snapshot', lAnalysis.FactSource);
  Assert.AreEqual(1, lAnalysis.SnapshotUnitCount);
  Assert.AreEqual(1, lAnalysis.VerifiedScopeUnitCount);
  Assert.AreEqual(0, lAnalysis.ModelFallbackUnitCount);
  Assert.AreEqual(0, lAnalysis.HeuristicFallbackUnitCount);
  Assert.IsTrue(lAnalysis.RejectedDeclarationCount > 0,
    'Rejected assignment-shaped candidates must remain visible in provenance.');
end;

procedure TGlobalVarsSemanticTests.
  SnapshotGlobalAnalysisDeduplicatesSemanticDeclarationIdentity;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lBuildMetrics: TDelphiSnapshotBuilderMetrics;
  lBuildOptions: TDelphiSnapshotBuildOptions;
  lModel: TDelphiSemanticUnitModel;
  lRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.Success := True;
  lModel.UnitName := 'DuplicateIdentityUnit';
  lModel.FileName := 'DuplicateIdentityUnit.pas';
  lModel.SourceText := 'unit DuplicateIdentityUnit;' + sLineBreak +
    'interface' + sLineBreak + 'var GValue: Integer;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure Run;' + sLineBreak +
    'begin' + sLineBreak + '  GValue := 1;' + sLineBreak + 'end;' +
    sLineBreak + 'end.';
  SetLength(lModel.Declarations, 2);
  lModel.Declarations[0].Name := 'GValue';
  lModel.Declarations[0].Kind := 'var';
  lModel.Declarations[0].TypeName := 'Integer';
  lModel.Declarations[0].SectionKind := 'interface';
  lModel.Declarations[0].DeclarationRole := 'declaration';
  lModel.Declarations[0].ScopeKind := 'unit';
  lModel.Declarations[0].OwnerScopeId := 'duplicateidentityunit';
  lModel.Declarations[0].SymbolId := 'duplicateidentityunit|var|gvalue';
  lModel.Declarations[0].Line := 3;
  lModel.Declarations[0].Column := 5;
  lModel.Declarations[1] := lModel.Declarations[0];
  SetLength(lModel.Routines, 1);
  lModel.Routines[0].Name := 'Run';
  lModel.Routines[0].SectionKind := 'implementation';
  lModel.Routines[0].Line := 5;
  lModel.Routines[0].Column := 11;
  SetLength(lModel.References, 1);
  lModel.References[0].Name := 'GValue';
  lModel.References[0].RoutineName := 'Run';
  lModel.References[0].Role := 'reference';
  lModel.References[0].SectionKind := 'implementation';
  lModel.References[0].Line := 7;
  lModel.References[0].Column := 3;
  lModel.References[0].EndLine := 7;
  lModel.References[0].EndColumn := 9;
  lModel.References[0].Offset := Pos('GValue :=', lModel.SourceText);
  lModel.References[0].EndOffset := lModel.References[0].Offset + Length('GValue');
  lBuildOptions := Default(TDelphiSnapshotBuildOptions);
  lBuildOptions.ResolveReferenceTargets := True;
  lBuildOptions.WorkerCount := 1;
  lRemoveWithFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lSnapshot := BuildProjectSnapshotFromModels([lModel], lRemoveWithFacts,
    lBuildOptions, lBuildMetrics);
  try
    lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot);
  finally
    lSnapshot.Free;
  end;

  Assert.AreEqual(1, Integer(Length(lAnalysis.Declarations)), 'declarations');
  Assert.AreEqual(1, Integer(Length(lAnalysis.Usages)), 'usages');
  Assert.AreEqual(0, Integer(Length(lAnalysis.Ambiguities)), 'ambiguities');
end;

procedure TGlobalVarsSemanticTests.UsageAccessUsesModelSourceText;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := [LoadModel('GlobalVarsFixture.Globals.pas')];
  lModels[0].SourceText := StringReplace(lModels[0].SourceText, '  Inc(GCounter);',
    '  GCounter := 1;', []);

  lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits(lModels);

  Assert.AreEqual(1, CountUsages(lAnalysis, 'GCounter', 'write'),
    'GCounter access should be classified from model SourceText.');
  Assert.AreEqual(0, CountUsages(lAnalysis, 'GCounter', 'readwrite'),
    'Disk source still has Inc(GCounter), but analysis should not reopen it.');
end;

procedure TGlobalVarsSemanticTests.UnverifiedClassVarsNeverBecomeGlobalDeclarations(
  const aStatus: string; const aSnapshot: Boolean);
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSnapshotBuildOptions;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lUnit: TUnitSnapshot;
begin
  lModel := LoadModel('GlobalVarsFixture.Globals.pas');
  Assert.IsTrue(Length(lModel.Members) > 0);
  lModel.ScopeModelStatus := aStatus;
  if aSnapshot then
  begin
    lOptions := Default(TDelphiSnapshotBuildOptions);
    lSnapshot := BuildProjectSnapshotFromModels([lModel],
      Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
    try
      lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot);
      lUnit := lSnapshot.UnitByIndex(0);
      for lSymbolId := 1 to TSemanticSymbolId(lUnit.SymbolCount) do
      begin
        lSymbol := lUnit.SymbolById(lSymbolId);
        if SameText(lSnapshot.TextOf(lSymbol.KindId), 'class-var') then
          Assert.AreNotEqual('declaration', lSnapshot.TextOf(lSymbol.DeclarationRoleId),
            'Unverified members remain queryable without claiming verified declarations.');
      end;
    finally
      lSnapshot.Free;
    end;
  end else
    lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits([lModel]);
  for var i := 0 to High(lAnalysis.Declarations) do
    Assert.AreNotEqual('classvar', lAnalysis.Declarations[i].Kind,
      'No class variable from an unverified unit is a verified global.');
  Assert.AreEqual(0, lAnalysis.VerifiedScopeUnitCount);
  Assert.IsTrue(HasDiagnostic(lAnalysis, 'SCOPE_MODEL_UNVERIFIED'));
end;

procedure TGlobalVarsSemanticTests.IncludeUsageUsesCapturedPhysicalEvidence(
  const aRoute, aCheck: string);
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lCache: TDelphiSemanticUnitCache;
  lCount: Integer;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
  lSnapshot, lReassembled: TDelphiProjectSnapshot;
  lUsage: TDelphiSemanticGlobalUsage;
begin
  lRoot := CreateTestTempRoot('include-global-probe-temp');
  TFile.WriteAllText(TPath.Combine(lRoot, 'first.inc'),
    'GF := 7;'#13#10'{$I nested.inc}'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'second.inc'), 'GF := 11;', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'nested.inc'), 'Inc(GF);', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeGlobalProbe.pas'),
    'unit IncludeGlobalProbe;'#13#10'interface'#13#10'var GF, GInactive: Integer;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '{$I first.inc}{$I second.inc}'#13#10 +
    '{$IF False}GInactive := 9;{$IFEND}'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeGlobalProbe.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  if aRoute = 'cache' then
  begin
    lCache := TDelphiSemanticUnitCache.Create(Default(TDelphiSemanticCacheOptions));
    try
      lModel := lCache.GetOrExtractUnitModel(lOptions);
      lModel := lCache.GetOrExtractUnitModel(lOptions);
      Assert.AreEqual(1, lCache.Metrics.CacheHits);
    finally
      lCache.Free;
    end;
  end else
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.PhysicalReferenceOccurrencesAvailable);
  if aCheck = 'unknown' then
  begin
    for var i := 0 to High(lModel.References) do
    begin
      lModel.References[i].Line := 0;
      lModel.References[i].Column := 0;
    end;
    for var i := 0 to High(lModel.PhysicalReferenceOccurrences) do
    begin
      lModel.PhysicalReferenceOccurrences[i].Line := 0;
      lModel.PhysicalReferenceOccurrences[i].Column := 0;
      lModel.PhysicalReferenceOccurrences[i].Verified := False;
    end;
  end;
  // Current disk text must not replace the bytes captured by extraction.
  TFile.WriteAllText(TPath.Combine(lRoot, 'first.inc'), 'Inc(GF);', TEncoding.ASCII);
  if aCheck = 'missing' then
    lModel.SourceObservations := nil;
  if (aRoute = 'direct') or (aRoute = 'cache') then
    lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits([lModel])
  else begin
    lSnapshot := BuildProjectSnapshotFromModels([lModel],
      Default(TDelphiSemanticProjectWithBindingFacts),
      Default(TDelphiSnapshotBuildOptions), lMetrics);
    try
      if aRoute = 'reassembled' then
      begin
        lReassembled := BuildProjectSnapshotFromUnitSnapshots([lSnapshot], lMetrics);
        try
          lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lReassembled);
        finally
          lReassembled.Free;
        end;
      end else
        lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot);
    finally
      lSnapshot.Free;
    end;
  end;
  lCount := 0;
  for lUsage in lAnalysis.Usages do
  begin
    if aCheck = 'inactive' then
      Assert.AreNotEqual('GInactive', lUsage.Name);
    if lUsage.Name <> 'GF' then
      Continue;
    Inc(lCount);
    if aCheck = 'file' then
    begin
      Assert.IsTrue(SameText(ExtractFileExt(lUsage.FileName), '.inc'),
        'Included usage must retain its captured physical file: ' + lUsage.FileName);
      Assert.AreEqual(1, lUsage.Line);
      Assert.IsTrue(lUsage.Column > 0);
    end;
    if aCheck = 'access' then
      if SameText(ExtractFileName(lUsage.FileName), 'nested.inc') then
        Assert.AreEqual('readwrite', lUsage.Access)
      else
        Assert.AreEqual('write', lUsage.Access, 'Captured assignment must not become a parent-line read.');
    if (aCheck = 'missing') or (aCheck = 'unknown') then
      Assert.IsFalse((lUsage.Access = 'read') or (lUsage.Access = 'write') or
        (lUsage.Access = 'readwrite'), 'Missing captured include text cannot certify an access.');
  end;
  if aCheck = 'distinct' then
    Assert.AreEqual(3, lCount, 'Two same-line include files plus their nested occurrence stay distinct.')
  else if (aCheck = 'missing') or (aCheck = 'unknown') then
    Assert.IsTrue((Length(lAnalysis.Diagnostics) > 0) or (Length(lAnalysis.Ambiguities) > 0),
      'Missing captured text must be named incomplete or ambiguous.')
  else
    Assert.IsTrue(lCount > 0, 'Public global analyzer must discover included GF usages.');
end;

procedure TGlobalVarsSemanticTests.IncludedUsagesKeepTokenAndScopeIdentity(const aShape: string);
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lBody, lRoot, lInclude, lStatements, lRoutines: string;
  lCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lUsage: TDelphiSemanticGlobalUsage;
begin
  lRoot := CreateTestTempRoot('include-global-identity-temp');
  lInclude := TPath.Combine(lRoot, 'body.inc');
  lBody := 'GF := 7;';
  if aShape = 'columns' then
    lBody := lBody + ' GF := 11;';
  TFile.WriteAllText(lInclude, lBody, TEncoding.ASCII);
  lStatements := '{$I body.inc}';
  if aShape = 'repeat' then
    lStatements := lStatements + '{$I body.inc}';
  lRoutines := 'procedure Run;'#13#10'begin'#13#10 + lStatements + #13#10'end;'#13#10;
  if aShape = 'shadow' then
    lRoutines := 'procedure Run;'#13#10'var GF: Integer;'#13#10'begin'#13#10 +
      lStatements + #13#10'end;'#13#10'procedure Outer;'#13#10'begin'#13#10 +
      lStatements + #13#10'end;'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'GlobalIdentity.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit GlobalIdentity;'#13#10'interface'#13#10'var GF: Integer;'#13#10 +
    'implementation'#13#10 + lRoutines + 'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.PhysicalReferenceOccurrencesAvailable);
  if aShape = 'unavailable' then
    lModel.PhysicalReferenceOccurrencesAvailable := False;
  if aShape = 'position' then
    for var i := 0 to High(lModel.PhysicalReferenceOccurrences) do
      lModel.PhysicalReferenceOccurrences[i].Column := 0;
  if aShape = 'scope' then
  begin
    Assert.AreEqual<Integer>(1, Length(lModel.Routines));
    lModel.Routines := lModel.Routines + [lModel.Routines[0]];
  end;
  TFile.WriteAllText(lInclude, 'Inc(GF);', TEncoding.ASCII);
  lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits([lModel]);
  if MatchText(aShape, ['unavailable', 'position', 'scope']) then
  begin
    Assert.AreEqual<Integer>(0, Length(lAnalysis.Usages));
    if aShape = 'scope' then
      Assert.IsTrue(HasDiagnostic(lAnalysis, 'GLOBAL_SCOPE_INCOMPLETE'))
    else
      Assert.IsTrue(HasDiagnostic(lAnalysis, 'GLOBAL_SOURCE_ORIGIN_INCOMPLETE'));
    Exit;
  end;
  lCount := 0;
  for lUsage in lAnalysis.Usages do
    if lUsage.Name = 'GF' then
    begin
      Inc(lCount);
      Assert.AreEqual(lInclude, lUsage.FileName);
      Assert.AreEqual(1, lUsage.Line);
      Assert.IsTrue(lUsage.Column > 0);
      Assert.AreEqual('write', lUsage.Access);
      Assert.AreNotEqual('', lUsage.RoutineScopeId);
      if aShape = 'shadow' then
        Assert.AreEqual('Outer', lUsage.RoutineName);
    end;
  if aShape = 'shadow' then
    Assert.AreEqual(1, lCount, 'An include in a different routine cannot borrow a homonym local.')
  else
    Assert.AreEqual(2, lCount, 'Each captured column or expansion contributes its own usage.');
end;

initialization
  TDUnitX.RegisterTestFixture(TGlobalVarsSemanticTests);

end.
