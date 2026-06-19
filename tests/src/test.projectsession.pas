unit Test.ProjectSession;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Graph,
  DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TProjectSessionTests = class
  private
    procedure AssertSnapshotFactsEqual(const aExpectedSnapshot,
      aActualSnapshot: TDelphiProjectSnapshot);
    function DependencyGraphRegressionProjectPath: string;
    function FindComponentWithUnit(const aGraph: TDelphiSemanticDependencyGraph;
      const aUnitName: string; out aComponent: TDelphiSemanticDependencyCycleComponent): Boolean;
    function FindEdge(const aGraph: TDelphiSemanticDependencyGraph; const aSourceUnit,
      aTargetUnit, aSectionKind: string; out aEdge: TDelphiSemanticDependencyEdge): Boolean;
    function FindNode(const aGraph: TDelphiSemanticDependencyGraph; const aUnitName: string;
      out aNode: TDelphiSemanticDependencyNode): Boolean;
    function HasUnit(const aUnits: TArray<string>; const aUnitName: string): Boolean;
    function ParityStatementsFromPlan(const aPlan: TDelphiSemanticRemoveWithPlan):
      TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
  public
    [Test]
    procedure ProjectSessionOpensFromProjectFileName;
    [Test]
    procedure EmptyProjectPathReturnsStructuredSessionDiagnostic;
    [Test]
    procedure OpensProjectSessionThroughExistingProjectContext;
    [Test]
    procedure ProjectSessionModelExtractionUsesSingleResultRecord;
    [Test]
    procedure ProjectSessionSnapshotIdentityReusesUnitCacheIdentityRecord;
    [Test]
    procedure ProjectSessionGlobalAnalysisUsesSnapshotAuthority;
    [Test]
    procedure ProjectSessionGlobalAnalysisReportsSnapshotCacheMetrics;
    [Test]
    procedure ProjectSessionDependencyGraphCollectsRecursiveProjectFacts;
    [Test]
    procedure ProjectSessionDependencyGraphUsesLinux64TargetDefines;
    [Test]
    procedure ProjectSessionBuildsSnapshotFromExtractedModels;
    [Test]
    procedure ProjectSessionSnapshotParityComparesSemanticFacts;
    [Test]
    procedure ProjectSessionParallelSnapshotBuildMatchesSequentialFacts;
    [Test]
    procedure ProjectSessionParallelRemoveWithPlanMatchesSequentialCounts;
    [Test]
    procedure ProjectSessionPlanRemoveWithCachesProjectFactsByProjectIdentity;
    [Test]
    procedure ProjectSessionSnapshotMetricsExposeCacheUsefulnessTelemetry;
    [Test]
    procedure ProjectSessionReusesUnchangedMultiUnitSnapshotCacheEntries;
    [Test]
    procedure ProjectSessionSnapshotCacheReusesPathVariantProjectIdentity;
    [Test]
    procedure ProjectSessionSnapshotCacheReusesTimestampOnlyChangedSource;
    [Test]
    procedure ProjectSessionScopedPartialSnapshotCacheHitStoresMissedUnitUnderScopedIdentity;
    [Test]
    procedure ProjectSessionPartialSnapshotCacheRebuildResolvesReferencesToCachedUnits;
    [Test]
    procedure ProjectSessionPartialSnapshotCacheInvalidationMatchesFullRebuildFacts;
    [Test]
    procedure ProjectSessionDiscoversAnsiDprInReferencesThroughSourceLoader;
    [Test]
    procedure ProjectSessionSnapshotCacheRebuildsIncludedFileChanges;
    [Test]
    procedure ProjectSessionAssociatesNestedWithReferencesWithInnermostSnapshotFact;
    [Test]
    procedure BuildWithBindingFactsSkipsReferencesForNonBodyModels;
    [Test]
    procedure ScopedBuildWithBindingFactsDoesNotPolluteGenericCacheEntries;
    [Test]
    procedure BuildWithBindingFactsDoesNotWriteProjectFactsJsonSidecar;
    [Test]
    procedure InvalidProjectReturnsStructuredSessionDiagnostic;
  end;

implementation

uses
  System.Classes,
  System.IOUtils,
  System.StrUtils,
  System.SysUtils,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite,
  maxLogic.IOUtils,
  DelphiSemantics.Api,
  DelphiSemantics.Api.RemoveWith.Compatibility,
  DelphiSemantics.Cache,
  DelphiSemantics.GlobalVars,
  DelphiSemantics.Model,
  DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession,
  Test.Support;

var
  GProjectSessionTempRoot: string;

function ProjectSessionTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GProjectSessionTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}', '',
      [rfReplaceAll]);
    GProjectSessionTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'project-session-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GProjectSessionTempRoot);
  Result := GProjectSessionTempRoot;
end;

function ProjectSessionTempPath(const aName: string): string;
begin
  Result := TPath.Combine(ProjectSessionTempRoot, aName);
end;

function DependencyGraphRegressionProjectRoot: string;
begin
  Result := ProjectSessionTempPath('dependency-graph-regression');
  TDirectory.CreateDirectory(Result);
end;

procedure WriteTextFile(const aFileName, aText: string);
begin
  TDirectory.CreateDirectory(ExtractFileDir(aFileName));
  TFile.WriteAllText(aFileName, aText, TEncoding.UTF8);
end;

procedure ExecProjectSessionCacheSql(const aCacheFileName, aSql: string);
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Connected := True;
    lConnection.ExecSQL(aSql);
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

function TProjectSessionTests.DependencyGraphRegressionProjectPath: string;
var
  lRoot: string;
begin
  lRoot := DependencyGraphRegressionProjectRoot;

  Result := TPath.Combine(lRoot, 'DepsGraphRegression.dproj');
  if TFile.Exists(Result) then
    Exit;

  WriteTextFile(Result,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' + sLineBreak +
    '  <PropertyGroup>' + sLineBreak +
    '    <MainSource>DepsGraphRegression.dpr</MainSource>' + sLineBreak +
    '    <Config Condition="''$(Config)''==''''">Debug</Config>' + sLineBreak +
    '    <Platform Condition="''$(Platform)''==''''">Win32</Platform>' + sLineBreak +
    '    <ProjectName>DepsGraphRegression</ProjectName>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak +
    '</Project>');

  WriteTextFile(TPath.Combine(lRoot, 'DepsGraphRegression.dpr'),
    'program DepsGraphRegression;' + sLineBreak +
    sLineBreak +
    'uses' + sLineBreak +
    '  DepsGraphRegression.Main in ''DepsGraphRegression.Main.pas'';' + sLineBreak +
    sLineBreak +
    'begin' + sLineBreak +
    'end.');

  WriteTextFile(TPath.Combine(lRoot, 'DepsGraphRegression.Main.pas'),
    'unit DepsGraphRegression.Main;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'uses' + sLineBreak +
    '  DepsGraphRegression.CycleA,' + sLineBreak +
    '  DepsGraphRegression.Broken,' + sLineBreak +
    '  DepsGraphRegression.MissingUnit' + sLineBreak +
    '{$IFDEF LINUX}' + sLineBreak +
    '  , DepsGraphRegression.LinuxOnly' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IFDEF MSWINDOWS}' + sLineBreak +
    '  , DepsGraphRegression.HostOnly' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '  ;' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'end.');

  WriteTextFile(TPath.Combine(lRoot, 'DepsGraphRegression.CycleA.pas'),
    'unit DepsGraphRegression.CycleA;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'uses' + sLineBreak +
    '  DepsGraphRegression.CycleB;' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'end.');

  WriteTextFile(TPath.Combine(lRoot, 'DepsGraphRegression.CycleB.pas'),
    'unit DepsGraphRegression.CycleB;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'uses' + sLineBreak +
    '  DepsGraphRegression.CycleA;' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'end.');

  WriteTextFile(TPath.Combine(lRoot, 'DepsGraphRegression.Broken.pas'),
    'unit DepsGraphRegression.Broken;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'type' + sLineBreak +
    '  TBroken = class' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'end.');

  WriteTextFile(TPath.Combine(lRoot, 'DepsGraphRegression.LinuxOnly.pas'),
    'unit DepsGraphRegression.LinuxOnly;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'end.');

  WriteTextFile(TPath.Combine(lRoot, 'DepsGraphRegression.HostOnly.pas'),
    'unit DepsGraphRegression.HostOnly;' + sLineBreak +
    sLineBreak +
    'interface' + sLineBreak +
    sLineBreak +
    'implementation' + sLineBreak +
    sLineBreak +
    'end.');
end;

function TProjectSessionTests.FindComponentWithUnit(const aGraph: TDelphiSemanticDependencyGraph;
  const aUnitName: string; out aComponent: TDelphiSemanticDependencyCycleComponent): Boolean;
var
  lComponent: TDelphiSemanticDependencyCycleComponent;
begin
  for lComponent in aGraph.CycleComponents do
    if HasUnit(lComponent.Units, aUnitName) then
    begin
      aComponent := lComponent;
      Exit(True);
    end;

  aComponent := Default(TDelphiSemanticDependencyCycleComponent);
  Result := False;
end;

function TProjectSessionTests.FindEdge(const aGraph: TDelphiSemanticDependencyGraph;
  const aSourceUnit, aTargetUnit, aSectionKind: string;
  out aEdge: TDelphiSemanticDependencyEdge): Boolean;
var
  lEdge: TDelphiSemanticDependencyEdge;
begin
  for lEdge in aGraph.Edges do
    if SameText(lEdge.SourceUnit, aSourceUnit) and SameText(lEdge.TargetUnit, aTargetUnit) and
      SameText(lEdge.SectionKind, aSectionKind) then
    begin
      aEdge := lEdge;
      Exit(True);
    end;

  aEdge := Default(TDelphiSemanticDependencyEdge);
  Result := False;
end;

function TProjectSessionTests.FindNode(const aGraph: TDelphiSemanticDependencyGraph;
  const aUnitName: string; out aNode: TDelphiSemanticDependencyNode): Boolean;
var
  lNode: TDelphiSemanticDependencyNode;
begin
  for lNode in aGraph.Nodes do
    if SameText(lNode.UnitName, aUnitName) then
    begin
      aNode := lNode;
      Exit(True);
    end;

  aNode := Default(TDelphiSemanticDependencyNode);
  Result := False;
end;

function TProjectSessionTests.HasUnit(const aUnits: TArray<string>; const aUnitName: string): Boolean;
var
  lUnit: string;
begin
  for lUnit in aUnits do
    if SameText(lUnit, aUnitName) then
      Exit(True);

  Result := False;
end;

procedure TProjectSessionTests.ProjectSessionSnapshotParityComparesSemanticFacts;
var
  lAssertPrefix: string;
  lSource: string;
begin
  lSource := ReadRepoSource('tests\src\test.projectsession.pas');
  lAssertPrefix := 'Assert.AreEqual(Integer(lExpected.';

  Assert.IsFalse(ContainsText(lSource, lAssertPrefix + 'Id)'),
    'Project-session snapshot parity must not compare dense fact IDs.');
  Assert.IsFalse(ContainsText(lSource, lAssertPrefix + 'UnitId)'),
    'Project-session snapshot parity must not compare dense unit IDs.');
  Assert.IsFalse(ContainsText(lSource, lAssertPrefix + 'WithId)'),
    'Project-session snapshot parity must not compare dense with IDs.');
  Assert.IsFalse(ContainsText(lSource, lAssertPrefix + 'TargetUnitId)'),
    'Project-session snapshot parity must not compare dense target unit IDs.');
  Assert.IsFalse(ContainsText(lSource, lAssertPrefix + 'TargetSymbolId)'),
    'Project-session snapshot parity must not compare dense target symbol IDs.');
end;


function SnapshotUnitKey(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot): string;
begin
  Result := aSnapshot.TextOf(aUnit.FileNameId) + #31 + aSnapshot.TextOf(aUnit.UnitNameId);
end;

function SnapshotSymbolKey(const aSnapshot: TDelphiProjectSnapshot;
  const aSymbol: TSemanticSymbolFact): string;
begin
  Result := aSnapshot.TextOf(aSymbol.NameId) + #31 +
    aSnapshot.TextOf(aSymbol.OwnerTypeId) + #31 +
    aSnapshot.TextOf(aSymbol.TypeId) + #31 +
    aSnapshot.TextOf(aSymbol.RoutineId) + #31 +
    aSnapshot.TextOf(aSymbol.KindId) + #31 +
    aSnapshot.TextOf(aSymbol.SectionKindId) + #31 +
    aSnapshot.TextOf(aSymbol.SourceKindId) + #31 +
    aSnapshot.TextOf(aSymbol.VisibilityId) + #31 +
    aSnapshot.TextOf(aSymbol.SignatureId) + #31 + IntToStr(aSymbol.Flags) + #31 +
    IntToStr(aSymbol.Line) + #31 + IntToStr(aSymbol.Column) + #31 +
    IntToStr(aSymbol.EndLine) + #31 + IntToStr(aSymbol.EndColumn);
end;

function SnapshotWithKey(const aSnapshot: TDelphiProjectSnapshot;
  const aWith: TSemanticWithStatementFact): string;
begin
  Result := aSnapshot.TextOf(aWith.RoutineId) + #31 +
    IntToStr(aWith.SelectorStartLine) + #31 + IntToStr(aWith.SelectorStartColumn) + #31 +
    IntToStr(aWith.BodyStartLine) + #31 + IntToStr(aWith.BodyStartColumn) + #31 +
    IntToStr(aWith.BodyEndLine) + #31 + IntToStr(aWith.BodyEndColumn) + #31 +
    IntToStr(aWith.Flags);
end;

function SnapshotReferenceWithKey(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aReference: TSemanticReferenceFact): string;
begin
  Result := '';
  if aReference.WithId <> 0 then
    Result := SnapshotWithKey(aSnapshot, aUnit.WithStatementById(aReference.WithId));
end;

function SnapshotReferenceTargetKey(const aSnapshot: TDelphiProjectSnapshot;
  const aReference: TSemanticReferenceFact): string;
var
  lTargetUnit: TUnitSnapshot;
begin
  Result := '';
  if (aReference.TargetUnitId = 0) or (aReference.TargetSymbolId = 0) then
    Exit;

  Assert.IsTrue(aSnapshot.TryFindUnitById(aReference.TargetUnitId, lTargetUnit),
    'Expected reference target unit to exist.');
  Result := SnapshotUnitKey(aSnapshot, lTargetUnit) + #31 +
    SnapshotSymbolKey(aSnapshot, lTargetUnit.SymbolById(aReference.TargetSymbolId));
end;

function SnapshotReferenceKey(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aReference: TSemanticReferenceFact): string;
begin
  Result := SnapshotReferenceWithKey(aSnapshot, aUnit, aReference) + #31 +
    SnapshotReferenceTargetKey(aSnapshot, aReference) + #31 +
    aSnapshot.TextOf(aReference.NameId) + #31 +
    aSnapshot.TextOf(aReference.ReceiverTypeId) + #31 +
    aSnapshot.TextOf(aReference.TypeId) + #31 +
    aSnapshot.TextOf(aReference.RoutineId) + #31 +
    aSnapshot.TextOf(aReference.SectionKindId) + #31 +
    aSnapshot.TextOf(aReference.SourceKindId) + #31 +
    aSnapshot.TextOf(aReference.ClassificationId) + #31 +
    aSnapshot.TextOf(aReference.LookupSourceId) + #31 +
    aSnapshot.TextOf(aReference.ReasonId) + #31 + IntToStr(aReference.Line) + #31 +
    IntToStr(aReference.Column) + #31 + IntToStr(aReference.EndLine) + #31 +
    IntToStr(aReference.EndColumn);
end;

procedure AssertSemanticListEquals(const aLabel: string; const aExpected,
  aActual: TStringList);
var
  i: Integer;
begin
  aExpected.Sort;
  aActual.Sort;
  Assert.AreEqual(aExpected.Count, aActual.Count, aLabel + ' count mismatch.');
  for i := 0 to aExpected.Count - 1 do
    Assert.AreEqual(aExpected[i], aActual[i], aLabel + ' semantic fact mismatch.');
end;

procedure AddSnapshotUnitKeys(const aSnapshot: TDelphiProjectSnapshot; const aList: TStringList);
var
  i: Integer;
begin
  for i := 0 to aSnapshot.UnitCount - 1 do
    aList.Add(SnapshotUnitKey(aSnapshot, aSnapshot.UnitByIndex(i)));
end;

procedure AddSnapshotSymbolKeys(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aList: TStringList);
var
  lSymbolId: TSemanticSymbolId;
begin
  for lSymbolId := 1 to TSemanticSymbolId(aUnit.SymbolCount) do
    aList.Add(SnapshotSymbolKey(aSnapshot, aUnit.SymbolById(lSymbolId)));
end;

procedure AddSnapshotWithKeys(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aList: TStringList);
var
  lWithId: TSemanticWithId;
begin
  for lWithId := 1 to TSemanticWithId(aUnit.WithStatementCount) do
    aList.Add(SnapshotWithKey(aSnapshot, aUnit.WithStatementById(lWithId)));
end;

procedure AddSnapshotReferenceKeys(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aList: TStringList);
var
  lReferenceId: TSemanticReferenceId;
begin
  for lReferenceId := 1 to TSemanticReferenceId(aUnit.ReferenceCount) do
    aList.Add(SnapshotReferenceKey(aSnapshot, aUnit, aUnit.ReferenceById(lReferenceId)));
end;

procedure AssertSnapshotUnitSemanticFactsEqual(const aExpectedSnapshot,
  aActualSnapshot: TDelphiProjectSnapshot; const aExpectedUnit: TUnitSnapshot);
var
  lActualList: TStringList;
  lActualUnit: TUnitSnapshot;
  lActualUnitId: TSemanticUnitId;
  lExpectedFileName: string;
  lExpectedList: TStringList;
begin
  lExpectedFileName := aExpectedSnapshot.TextOf(aExpectedUnit.FileNameId);
  Assert.IsTrue(aActualSnapshot.TryFindUnitByFileName(lExpectedFileName, lActualUnitId),
    'Expected actual snapshot to contain unit ' + lExpectedFileName);
  Assert.IsTrue(aActualSnapshot.TryFindUnitById(lActualUnitId, lActualUnit),
    'Expected actual snapshot unit lookup to succeed for ' + lExpectedFileName);

  lExpectedList := TStringList.Create;
  lActualList := TStringList.Create;
  try
    AddSnapshotSymbolKeys(aExpectedSnapshot, aExpectedUnit, lExpectedList);
    AddSnapshotSymbolKeys(aActualSnapshot, lActualUnit, lActualList);
    AssertSemanticListEquals(lExpectedFileName + ' symbols', lExpectedList, lActualList);

    lExpectedList.Clear;
    lActualList.Clear;
    AddSnapshotWithKeys(aExpectedSnapshot, aExpectedUnit, lExpectedList);
    AddSnapshotWithKeys(aActualSnapshot, lActualUnit, lActualList);
    AssertSemanticListEquals(lExpectedFileName + ' with statements', lExpectedList,
      lActualList);

    lExpectedList.Clear;
    lActualList.Clear;
    AddSnapshotReferenceKeys(aExpectedSnapshot, aExpectedUnit, lExpectedList);
    AddSnapshotReferenceKeys(aActualSnapshot, lActualUnit, lActualList);
    AssertSemanticListEquals(lExpectedFileName + ' references', lExpectedList,
      lActualList);
  finally
    lActualList.Free;
    lExpectedList.Free;
  end;
end;

procedure TProjectSessionTests.AssertSnapshotFactsEqual(const aExpectedSnapshot,
  aActualSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  lActualUnits: TStringList;
  lExpectedUnit: TUnitSnapshot;
  lExpectedUnits: TStringList;
begin
  lExpectedUnits := TStringList.Create;
  lActualUnits := TStringList.Create;
  try
    AddSnapshotUnitKeys(aExpectedSnapshot, lExpectedUnits);
    AddSnapshotUnitKeys(aActualSnapshot, lActualUnits);
    AssertSemanticListEquals('snapshot units', lExpectedUnits, lActualUnits);
  finally
    lActualUnits.Free;
    lExpectedUnits.Free;
  end;

  for i := 0 to aExpectedSnapshot.UnitCount - 1 do
  begin
    lExpectedUnit := aExpectedSnapshot.UnitByIndex(i);
    AssertSnapshotUnitSemanticFactsEqual(aExpectedSnapshot, aActualSnapshot, lExpectedUnit);
  end;
end;

function TProjectSessionTests.ParityStatementsFromPlan(
  const aPlan: TDelphiSemanticRemoveWithPlan):
  TArray<TDelphiSemanticRemoveWithPlanParityStatement>;
var
  i: Integer;
  j: Integer;
begin
  SetLength(Result, Length(aPlan.FinalStatements));
  for i := 0 to High(aPlan.FinalStatements) do
  begin
    Result[i].StatementId := aPlan.FinalStatements[i].StatementId;
    Result[i].FileName := aPlan.FinalStatements[i].FileName;
    Result[i].Status := aPlan.FinalStatements[i].Status;
    Result[i].Reason := aPlan.FinalStatements[i].Reason;
    Result[i].UnsupportedIdentifierRole :=
      aPlan.FinalStatements[i].UnsupportedIdentifierRole;
    Result[i].ReplacementText := aPlan.FinalStatements[i].ReplacementText;
    SetLength(Result[i].Edits, Length(aPlan.FinalStatements[i].Edits));
    for j := 0 to High(aPlan.FinalStatements[i].Edits) do
    begin
      Result[i].Edits[j].Kind := aPlan.FinalStatements[i].Edits[j].Kind;
      Result[i].Edits[j].FileName := aPlan.FinalStatements[i].Edits[j].FileName;
      Result[i].Edits[j].StatementId :=
        aPlan.FinalStatements[i].Edits[j].StatementId;
      Result[i].Edits[j].Range := aPlan.FinalStatements[i].Edits[j].Range;
      Result[i].Edits[j].ReplacementText :=
        aPlan.FinalStatements[i].Edits[j].ReplacementText;
    end;
  end;
end;

procedure TProjectSessionTests.ProjectSessionOpensFromProjectFileName;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    Assert.AreEqual(psOpen, lResult.Status);
    Assert.IsNotNull(lResult.Session);
    Assert.AreEqual('BasicProject', lResult.Session.Project.ProjectName);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.EmptyProjectPathReturnsStructuredSessionDiagnostic;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsFalse(lResult.Success);
    Assert.AreEqual(psInvalidProject, lResult.Status);
    Assert.AreEqual('project-context', lResult.Provenance);
    Assert.IsNull(lResult.Session);
    Assert.AreEqual(1, Integer(Length(lResult.Diagnostics)));
    Assert.AreEqual('PROJECT_FILE_NOT_SPECIFIED', lResult.Diagnostics[0].Code);
    Assert.AreEqual(dsError, lResult.Diagnostics[0].Severity);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.OpensProjectSessionThroughExistingProjectContext;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Basic\BasicProject.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    Assert.AreEqual(psOpen, lResult.Status);
    Assert.AreEqual('project-context', lResult.Provenance);
    Assert.IsNotNull(lResult.Session);
    Assert.AreEqual(lOptions.ProjectPath, lResult.Session.Options.ProjectPath);
    Assert.AreEqual('BasicProject', lResult.Session.Project.ProjectName);
    Assert.AreEqual('Debug', lResult.Session.Project.Configuration);
    Assert.AreEqual('Win32', lResult.Session.Project.Platform);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionModelExtractionUsesSingleResultRecord;
var
  lExtractWithScopeModeName: string;
  lOutExtractionSignature: string;
  lSource: string;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.ProjectSession.pas');
  lExtractWithScopeModeName := 'ExtractProjectModels' + 'WithScopeMode';
  lOutExtractionSignature := 'function ExtractProjectModels' + '(const aProject: ' +
    'TDelphiSemanticProjectInfo;' + sLineBreak +
    '  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64';

  Assert.IsTrue(ContainsText(lSource, 'TProjectModelExtractionResult = record'),
    'Expected private project model extraction to return one result record.');
  Assert.IsFalse(ContainsText(lSource, lExtractWithScopeModeName),
    'Wrapper-only extraction scope-mode fan-out should be removed.');
  Assert.IsFalse(ContainsText(lSource, lOutExtractionSignature),
    'ExtractProjectModels should not thread elapsed time and cache data through out parameters.');
end;

procedure TProjectSessionTests.ProjectSessionSnapshotIdentityReusesUnitCacheIdentityRecord;
var
  lBody: string;
  lEndIndex: Integer;
  lSource: string;
  lStartIndex: Integer;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.ProjectSession.pas');
  lStartIndex := Pos('function SnapshotCacheIdentityForUnit', lSource);
  Assert.IsTrue(lStartIndex > 0, 'Expected snapshot unit identity helper.');
  lEndIndex := PosEx('function ProjectRemoveWithFactsCacheIdentity', lSource, lStartIndex);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected snapshot unit identity helper to stay before project facts identity.');
  lBody := Copy(lSource, lStartIndex, lEndIndex - lStartIndex);

  Assert.IsTrue(ContainsText(lBody, 'aUnitCacheIdentity.SourceFileName'),
    'Snapshot identity should reuse the normalized source path from the unit identity record.');
  Assert.IsTrue(ContainsText(lBody, 'aUnitCacheIdentity.FileHash'),
    'Snapshot identity should reuse the content hash from the unit identity record.');
  Assert.IsTrue(ContainsText(lBody, 'aUnitCacheIdentity.IncludeGraphHash'),
    'Snapshot identity should reuse the include/preprocess result from the unit identity record.');
  Assert.IsFalse(ContainsText(lBody, 'GetHashStringFromFile(lFullSourceFileName)'),
    'Snapshot identity should not re-hash the source file after unit identity building.');
  Assert.IsFalse(ContainsText(lBody, 'TFile.Exists(lFullSourceFileName)'),
    'Snapshot identity should not perform a second source-file probe.');
end;

procedure TProjectSessionTests.ProjectSessionGlobalAnalysisUsesSnapshotAuthority;
var
  lBody: string;
  lEndIndex: Integer;
  lSource: string;
  lStartIndex: Integer;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.ProjectSession.pas');
  lStartIndex := Pos('function TDelphiSemanticProjectSession.BuildGlobalAnalysis',
    lSource);
  Assert.IsTrue(lStartIndex > 0, 'Expected BuildGlobalAnalysis implementation.');
  lEndIndex := PosEx('function TDelphiSemanticProjectSession.BuildGlobalCacheIdentities',
    lSource, lStartIndex);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected BuildGlobalAnalysis to appear before BuildGlobalCacheIdentities.');
  lBody := Copy(lSource, lStartIndex, lEndIndex - lStartIndex);

  Assert.IsTrue(ContainsText(lBody, 'BuildSnapshot'),
    'Project-session global-vars analysis should use the session snapshot authority.');
  Assert.IsTrue(ContainsText(lBody, 'AnalyzeSnapshot'),
    'Global-vars analysis should consume snapshot-derived facts.');
  Assert.IsFalse(ContainsText(lBody, 'ExtractProjectModels'),
    'BuildGlobalAnalysis should not own a separate project model extraction path.');
end;

procedure TProjectSessionTests.ProjectSessionGlobalAnalysisReportsSnapshotCacheMetrics;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lExtractionMilliseconds: Int64;
  lIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('global-analysis-snapshot-cache-metrics');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'GlobalAnalysisCacheMetrics.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'GlobalAnalysisCacheMetrics.dproj');
  lUnitPath := TPath.Combine(lRootPath, 'GlobalAnalysisCacheMetricsUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  TFile.WriteAllText(lDprPath, 'program GlobalAnalysisCacheMetrics;' + sLineBreak +
    'uses GlobalAnalysisCacheMetricsUnit;' + sLineBreak + 'begin' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{3D3B94A9-B5F5-4F6D-8B9E-F55F3178419C}</ProjectGuid>' +
    sLineBreak + '    <MainSource>GlobalAnalysisCacheMetrics.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="GlobalAnalysisCacheMetricsUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit GlobalAnalysisCacheMetricsUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'var' + sLineBreak +
    '  GGlobalAnalysisMetricValue: Integer;' + sLineBreak + 'procedure TouchMetric;' +
    sLineBreak + 'implementation' + sLineBreak + 'procedure TouchMetric;' +
    sLineBreak + 'begin' + sLineBreak + '  Inc(GGlobalAnalysisMetricValue);' +
    sLineBreak + 'end;' + sLineBreak + 'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lAnalysis := lResult.Session.BuildGlobalAnalysis(lIdentities, lCacheMetrics,
      lExtractionMilliseconds);
    Assert.IsTrue(Length(lAnalysis.Declarations) > 0,
      'Expected snapshot-backed global analysis to return declarations.');
    Assert.AreEqual(2, Integer(Length(lIdentities)));
    Assert.IsTrue(lCacheMetrics.CacheMisses > 0,
      'Snapshot-backed global analysis should preserve cache miss metrics.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionDependencyGraphCollectsRecursiveProjectFacts;
var
  lComponent: TDelphiSemanticDependencyCycleComponent;
  lEdge: TDelphiSemanticDependencyEdge;
  lGraph: TDelphiSemanticDependencyGraph;
  lNode: TDelphiSemanticDependencyNode;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := DependencyGraphRegressionProjectPath;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lGraph := lResult.Session.BuildDependencyGraph;
    Assert.IsTrue(FindNode(lGraph, 'DepsGraphRegression.Main', lNode));
    Assert.AreEqual('project', lNode.Status);
    Assert.IsTrue(FindEdge(lGraph, 'DepsGraphRegression.Main', 'DepsGraphRegression.CycleA',
      'interface', lEdge));
    Assert.IsTrue(FindEdge(lGraph, 'DepsGraphRegression.CycleA', 'DepsGraphRegression.CycleB',
      'interface', lEdge));
    Assert.IsTrue(FindEdge(lGraph, 'DepsGraphRegression.CycleB', 'DepsGraphRegression.CycleA',
      'interface', lEdge));
    Assert.IsTrue(FindComponentWithUnit(lGraph, 'DepsGraphRegression.CycleA', lComponent));
    Assert.IsTrue(HasUnit(lComponent.Units, 'DepsGraphRegression.CycleB'));
    Assert.IsTrue(Length(lComponent.Path) >= 3);
    Assert.IsTrue(HasUnit(lGraph.UnresolvedUnits, 'DepsGraphRegression.MissingUnit'));
    Assert.IsTrue(Length(lGraph.ParserProblems) >= 1);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionDependencyGraphUsesLinux64TargetDefines;
var
  lGraph: TDelphiSemanticDependencyGraph;
  lNode: TDelphiSemanticDependencyNode;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := DependencyGraphRegressionProjectPath;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Linux64';

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    Assert.AreEqual('Linux64', lResult.Session.Project.Platform);
    Assert.IsTrue(Length(lResult.Session.Project.Defines) > 0);
    lGraph := lResult.Session.BuildDependencyGraph;
    Assert.IsTrue(FindNode(lGraph, 'DepsGraphRegression.LinuxOnly', lNode));
    Assert.AreEqual('project', lNode.Status);
    Assert.IsFalse(FindNode(lGraph, 'DepsGraphRegression.HostOnly', lNode));
    Assert.IsTrue(HasUnit(lResult.Session.Project.Defines, 'LINUX'));
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionBuildsSnapshotFromExtractedModels;
var
  lExpectedReferenceCount: Integer;
  lExpectedSymbolCount: Integer;
  lExpectedWithStatementCount: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lMemberNameId: TSemanticStringId;
  lMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRoutine: TDelphiSemanticRoutine;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lTypeNameId: TSemanticStringId;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    lExpectedReferenceCount := 0;
    lExpectedSymbolCount := 0;
    lExpectedWithStatementCount := 0;
    for lModel in lFacts.UnitModels do
    begin
      Inc(lExpectedReferenceCount, Length(lModel.References));
      Inc(lExpectedSymbolCount, Length(lModel.Declarations) + Length(lModel.Members) +
        Length(lModel.Routines) + Length(lModel.Locals));
      Inc(lExpectedWithStatementCount, Length(lModel.WithStatements));
      for lRoutine in lModel.Routines do
        Inc(lExpectedSymbolCount, Length(lRoutine.Parameters));
    end;

    lSnapshot := lResult.Session.BuildSnapshot;
    try
      lMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(Integer(Length(lFacts.UnitModels)), lSnapshot.UnitCount);
      Assert.AreEqual(lSnapshot.UnitCount, lMetrics.UnitCount);
      Assert.AreEqual(lExpectedSymbolCount, lMetrics.SymbolCount);
      Assert.AreEqual(lExpectedReferenceCount, lMetrics.ReferenceCount);
      Assert.AreEqual(lExpectedWithStatementCount, lMetrics.WithStatementCount);
      Assert.AreEqual(Integer(Length(lFacts.Bindings)), lMetrics.WithStatementCount);
      Assert.IsTrue(lMetrics.BuildMilliseconds >= 0);

      Assert.IsTrue(lSnapshot.TryFindUnitByFileName(
        FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'), lUnitId));
      Assert.IsTrue(lSnapshot.TryFindUnitById(lUnitId, lUnit));
      Assert.AreEqual(FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'),
        lSnapshot.TextOf(lUnit.FileNameId));

      Assert.IsTrue(lSnapshot.TryFindStringId('TProjectWithRecord', lTypeNameId));
      Assert.IsTrue(lSnapshot.TryTypesByName(lTypeNameId, lLowIndex, lHighIndex));
      Assert.IsTrue(lSnapshot.TryFindStringId('Value', lMemberNameId));
      Assert.IsTrue(lSnapshot.TryFindMember(lTypeNameId, lMemberNameId, lSymbolRef));
      Assert.IsTrue(lSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit));
      lSymbol := lUnit.SymbolById(lSymbolRef.SymbolId);
      Assert.AreEqual('Value', lSnapshot.TextOf(lSymbol.NameId));
      Assert.AreEqual('TProjectWithRecord', lSnapshot.TextOf(lSymbol.OwnerTypeId));
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionParallelSnapshotBuildMatchesSequentialFacts;
var
  lParallelMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lParallelOptions: TDelphiSemanticOptions;
  lParallelResult: TDelphiSemanticProjectSessionResult;
  lParallelSnapshot: TDelphiProjectSnapshot;
  lSequentialMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSequentialOptions: TDelphiSemanticOptions;
  lSequentialResult: TDelphiSemanticProjectSessionResult;
  lSequentialSnapshot: TDelphiProjectSnapshot;
begin
  lSequentialOptions := Default(TDelphiSemanticOptions);
  lSequentialOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lSequentialOptions.SnapshotBuildWorkerCount := 1;

  lParallelOptions := lSequentialOptions;
  lParallelOptions.SnapshotBuildWorkerCount := 2;

  lSequentialResult := TDelphiSemanticProjectSession.Open(lSequentialOptions);
  try
    Assert.IsTrue(lSequentialResult.Success);
    lSequentialSnapshot := lSequentialResult.Session.BuildSnapshot;
    try
      lSequentialMetrics := lSequentialResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(1, lSequentialMetrics.SnapshotBuilderWorkerCount);

      lParallelResult := TDelphiSemanticProjectSession.Open(lParallelOptions);
      try
        Assert.IsTrue(lParallelResult.Success);
        lParallelSnapshot := lParallelResult.Session.BuildSnapshot;
        try
          lParallelMetrics := lParallelResult.Session.LastSnapshotBuildMetrics;
          Assert.AreEqual(2, lParallelMetrics.SnapshotBuilderWorkerCount);
          Assert.IsTrue(lParallelMetrics.SnapshotBuilderQueueMilliseconds >= 0);
          Assert.IsTrue(lParallelMetrics.SnapshotBuilderParseExtractMilliseconds >= 0);
          Assert.IsTrue(lParallelMetrics.SnapshotBuilderMergeMilliseconds >= 0);
          Assert.AreEqual(lParallelMetrics.UnitCount + lParallelMetrics.SymbolCount +
            lParallelMetrics.ReferenceCount + lParallelMetrics.WithStatementCount,
            lParallelMetrics.SnapshotBuilderDeterministicFactCount);

          AssertSnapshotFactsEqual(lSequentialSnapshot, lParallelSnapshot);
          Assert.AreEqual(lSequentialMetrics.UnitCount, lParallelMetrics.UnitCount);
          Assert.AreEqual(lSequentialMetrics.SymbolCount, lParallelMetrics.SymbolCount);
          Assert.AreEqual(lSequentialMetrics.ReferenceCount,
            lParallelMetrics.ReferenceCount);
          Assert.AreEqual(lSequentialMetrics.WithStatementCount,
            lParallelMetrics.WithStatementCount);
        finally
          lParallelSnapshot.Free;
        end;
      finally
        lParallelResult.Session.Free;
      end;
    finally
      lSequentialSnapshot.Free;
    end;
  finally
    lSequentialResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionParallelRemoveWithPlanMatchesSequentialCounts;
var
  lParallelMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lParallelOptions: TDelphiSemanticOptions;
  lParallelPlan: TDelphiSemanticRemoveWithPlan;
  lParallelResult: TDelphiSemanticProjectSessionResult;
  lParityReport: TDelphiSemanticRemoveWithPlanParityReport;
  lSequentialMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSequentialOptions: TDelphiSemanticOptions;
  lSequentialPlan: TDelphiSemanticRemoveWithPlan;
  lSequentialResult: TDelphiSemanticProjectSessionResult;
begin
  lSequentialOptions := Default(TDelphiSemanticOptions);
  lSequentialOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lSequentialOptions.SnapshotBuildWorkerCount := 1;

  lParallelOptions := lSequentialOptions;
  lParallelOptions.SnapshotBuildWorkerCount := 2;

  lSequentialResult := TDelphiSemanticProjectSession.Open(lSequentialOptions);
  try
    Assert.IsTrue(lSequentialResult.Success);
    lSequentialPlan := lSequentialResult.Session.PlanRemoveWith;
    lSequentialMetrics := lSequentialResult.Session.LastSnapshotBuildMetrics;
    Assert.AreEqual(1, lSequentialMetrics.SnapshotBuilderWorkerCount);

    lParallelResult := TDelphiSemanticProjectSession.Open(lParallelOptions);
    try
      Assert.IsTrue(lParallelResult.Success);
      lParallelPlan := lParallelResult.Session.PlanRemoveWith;
      lParallelMetrics := lParallelResult.Session.LastSnapshotBuildMetrics;

      Assert.AreEqual(2, lParallelMetrics.SnapshotBuilderWorkerCount);
      Assert.AreEqual(lSequentialPlan.Operation, lParallelPlan.Operation);
      Assert.AreEqual(lSequentialPlan.Status, lParallelPlan.Status);
      Assert.AreEqual(lSequentialPlan.Diagnostic, lParallelPlan.Diagnostic);
      Assert.AreEqual(Length(lSequentialPlan.Edits), Length(lParallelPlan.Edits));
      Assert.AreEqual(Length(lSequentialPlan.SkippedStatements),
        Length(lParallelPlan.SkippedStatements));
      Assert.AreEqual(Length(lSequentialPlan.FinalStatements),
        Length(lParallelPlan.FinalStatements));
      Assert.IsTrue(Length(lParallelPlan.FinalStatements) > 0);

      lParityReport := TDelphiSemanticRemoveWithPlanParity.Compare(lParallelPlan,
        ParityStatementsFromPlan(lSequentialPlan));
      Assert.AreEqual(0, lParityReport.MismatchCount, lParityReport.SummaryText);
    finally
      lParallelResult.Session.Free;
    end;
  finally
    lSequentialResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithCachesProjectFactsByProjectIdentity;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lFirstPlan: TDelphiSemanticRemoveWithPlan;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lOptions: TDelphiSemanticOptions;
  lRootPath: string;
  lSecondMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSecondPlan: TDelphiSemanticRemoveWithPlan;
  lSecondResult: TDelphiSemanticProjectSessionResult;
  lThirdMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lThirdPlan: TDelphiSemanticRemoveWithPlan;
  lThirdResult: TDelphiSemanticProjectSessionResult;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('remove-with-project-facts-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'RemoveWithProjectFactsCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'RemoveWithProjectFactsCache.dproj');
  lUnitPath := TPath.Combine(lRootPath, 'RemoveWithProjectFactsCacheUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  TFile.WriteAllText(lDprPath, 'program RemoveWithProjectFactsCache;' + sLineBreak +
    'uses RemoveWithProjectFactsCacheUnit;' + sLineBreak + 'begin' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{A36F2B31-F86F-4B9D-8D24-3C60712BF150}</ProjectGuid>' +
    sLineBreak + '    <MainSource>RemoveWithProjectFactsCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="RemoveWithProjectFactsCacheUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit RemoveWithProjectFactsCacheUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'type' + sLineBreak +
    '  TRemoveWithProjectFactsCacheRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '    OtherValue: Integer;' + sLineBreak +
    '  end;' + sLineBreak + 'procedure UseCacheRecord;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure UseCacheRecord;' + sLineBreak +
    'var' + sLineBreak + '  lRecord: TRemoveWithProjectFactsCacheRecord;' +
    sLineBreak + 'begin' + sLineBreak + '  with lRecord do' + sLineBreak +
    '    Value := 1;' + sLineBreak + 'end;' + sLineBreak + 'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;
  lOptions.SkipWithBindingSemanticGraph := True;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lFirstPlan := lFirstResult.Session.PlanRemoveWith;
    lFirstMetrics := lFirstResult.Session.LastSnapshotBuildMetrics;
  finally
    lFirstResult.Session.Free;
  end;
  Assert.AreEqual(1, lFirstMetrics.SnapshotCacheProbes);
  Assert.AreEqual(0, lFirstMetrics.SnapshotCacheHits);
  Assert.AreEqual(1, lFirstMetrics.SnapshotCacheMisses);
  Assert.IsTrue(lFirstMetrics.SnapshotSqlWriteMilliseconds > 0,
    'First remove-with project facts cache miss should write project facts.');
  Assert.IsTrue(Length(lFirstPlan.FinalStatements) > 0,
    'Expected remove-with fixture to produce a final statement.');
  Assert.IsTrue(Pos('Value', lFirstPlan.FinalStatements[0].ReplacementText) > 0,
    'First remove-with plan should reference Value.');

  lSecondResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lSecondResult.Success);
    lSecondPlan := lSecondResult.Session.PlanRemoveWith;
    lSecondMetrics := lSecondResult.Session.LastSnapshotBuildMetrics;
  finally
    lSecondResult.Session.Free;
  end;
  Assert.AreEqual(1, lSecondMetrics.SnapshotCacheProbes);
  Assert.AreEqual(1, lSecondMetrics.SnapshotCacheHits);
  Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMisses);
  Assert.AreEqual(Int64(0), lSecondMetrics.SnapshotSqlWriteMilliseconds);
  Assert.AreEqual(lFirstPlan.FinalStatements[0].ReplacementText,
    lSecondPlan.FinalStatements[0].ReplacementText,
    'Warm cached status=' + lSecondPlan.FinalStatements[0].Status +
    '; reason=' + lSecondPlan.FinalStatements[0].Reason +
    '; safety=' + lSecondPlan.FinalStatements[0].SafetyReason);

  TFile.WriteAllText(lUnitPath, 'unit RemoveWithProjectFactsCacheUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'type' + sLineBreak +
    '  TRemoveWithProjectFactsCacheRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '    OtherValue: Integer;' + sLineBreak +
    '  end;' + sLineBreak + 'procedure UseCacheRecord;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure UseCacheRecord;' + sLineBreak +
    'var' + sLineBreak + '  lRecord: TRemoveWithProjectFactsCacheRecord;' +
    sLineBreak + 'begin' + sLineBreak + '  with lRecord do' + sLineBreak +
    '    OtherValue := 1;' + sLineBreak + 'end;' + sLineBreak + 'end.', TEncoding.UTF8);

  lThirdResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lThirdResult.Success);
    lThirdPlan := lThirdResult.Session.PlanRemoveWith;
    lThirdMetrics := lThirdResult.Session.LastSnapshotBuildMetrics;
  finally
    lThirdResult.Session.Free;
  end;
  Assert.AreEqual(1, lThirdMetrics.SnapshotCacheProbes);
  Assert.AreEqual(0, lThirdMetrics.SnapshotCacheHits);
  Assert.AreEqual(1, lThirdMetrics.SnapshotCacheMisses);
  Assert.IsTrue(lThirdMetrics.SnapshotSqlWriteMilliseconds > 0,
    'Changed remove-with project facts cache miss should write refreshed project facts.');
  Assert.IsTrue(Length(lThirdPlan.FinalStatements) > 0,
    'Expected changed remove-with fixture to produce a final statement.');
  Assert.IsTrue(Pos('OtherValue', lThirdPlan.FinalStatements[0].ReplacementText) > 0,
    'Changed remove-with plan should reference OtherValue, not stale Value facts.');
end;

procedure TProjectSessionTests.ProjectSessionAssociatesNestedWithReferencesWithInnermostSnapshotFact;
var
  i: Integer;
  lFoundInnerReference: Boolean;
  lHighIndex: Integer;
  lInnerWithId: TSemanticWithId;
  lLowIndex: Integer;
  lOptions: TDelphiSemanticOptions;
  lReference: TSemanticReferenceFact;
  lResult: TDelphiSemanticProjectSessionResult;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
  lWith: TSemanticWithStatementFact;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('WithDiscovery\WithDiscoveryProject.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.IsTrue(lSnapshot.TryFindUnitByFileName(
        FixturePath('WithDiscovery\WithDiscoveryUnit.pas'), lUnitId));
      Assert.IsTrue(lSnapshot.TryFindUnitById(lUnitId, lUnit));

      lInnerWithId := 0;
      for i := 1 to lUnit.WithStatementCount do
      begin
        lWith := lUnit.WithStatementById(TSemanticWithId(i));
        if lWith.SelectorStartLine = 30 then
          lInnerWithId := lWith.Id;
      end;
      Assert.IsTrue(lInnerWithId <> 0, 'Expected nested inner with statement at line 30.');
      Assert.IsTrue(lUnit.TryReferencesForWith(lInnerWithId, lLowIndex, lHighIndex));

      lFoundInnerReference := False;
      for i := lLowIndex to lHighIndex do
      begin
        lReference := lUnit.ReferenceById(lUnit.ReferenceIdByWithIndex(i));
        if (lReference.Line = 31) and SameText(lSnapshot.TextOf(lReference.NameId), 'Value') then
          lFoundInnerReference := True;
      end;
      Assert.IsTrue(lFoundInnerReference,
        'Expected the inner with statement to own its body reference.');
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionSnapshotMetricsExposeCacheUsefulnessTelemetry;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lFirstSnapshot: TDelphiProjectSnapshot;
  lLoadCostMilliseconds: Int64;
  lMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'SnapshotSessionCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'SnapshotSessionCache.dproj');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);
  TFile.WriteAllText(lDprPath, 'program SnapshotSessionCache;' + sLineBreak +
    'type' + sLineBreak + '  TSnapshotSessionRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak + 'begin' +
    sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{96B5DB71-379E-42CF-9336-35FD61F01F3B}</ProjectGuid>' +
    sLineBreak + '    <MainSource>SnapshotSessionCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lFirstSnapshot := lFirstResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(1, lFirstSnapshot.UnitCount);
      lFirstMetrics := lFirstResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(1, lFirstMetrics.SnapshotCacheProbes);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheHits);
      Assert.AreEqual(1, lFirstMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheInvalidations);
      Assert.IsTrue(lFirstMetrics.SnapshotSqlWriteMilliseconds > 0);
      Assert.IsTrue(lFirstMetrics.SnapshotSqlReadMilliseconds > 0);
      Assert.IsTrue(lFirstMetrics.SnapshotParseAvoidedEstimateMilliseconds > 0);
      Assert.IsFalse(lFirstMetrics.SnapshotCacheUseful);
    finally
      lFirstSnapshot.Free;
    end;
  finally
    lFirstResult.Session.Free;
  end;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
      lMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(1, lMetrics.SnapshotCacheProbes);
      Assert.AreEqual(1, lMetrics.SnapshotCacheHits);
      Assert.AreEqual(0, lMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(Int64(0), lMetrics.SnapshotSqlWriteMilliseconds);
      Assert.IsTrue(lMetrics.SnapshotSqlReadMilliseconds > 0);
      Assert.IsTrue(lMetrics.SnapshotDeserializeMilliseconds >= 0);
      Assert.IsTrue(lMetrics.SnapshotIndexRebuildMilliseconds >= 0);
      Assert.IsTrue(lMetrics.SnapshotParseAvoidedEstimateMilliseconds > 0);
      lLoadCostMilliseconds := lMetrics.SnapshotSqlReadMilliseconds +
        lMetrics.SnapshotDeserializeMilliseconds + lMetrics.SnapshotIndexRebuildMilliseconds;
      Assert.AreEqual(lMetrics.SnapshotParseAvoidedEstimateMilliseconds >
        lLoadCostMilliseconds, lMetrics.SnapshotCacheUseful);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionReusesUnchangedMultiUnitSnapshotCacheEntries;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lFirstSnapshot: TDelphiProjectSnapshot;
  lOptions: TDelphiSemanticOptions;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSecondMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSecondSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lThirdMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lThirdSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-multi-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'MultiUnitSnapshotCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'MultiUnitSnapshotCache.dproj');
  lUnitPath := TPath.Combine(lRootPath, 'MultiUnitSnapshotCacheUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  TFile.WriteAllText(lDprPath, 'program MultiUnitSnapshotCache;' + sLineBreak +
    'uses MultiUnitSnapshotCacheUnit;' + sLineBreak + 'var' + sLineBreak +
    '  lValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  lValue := ChangedValue;' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{7D145E4F-01E1-4C89-A928-0351274D43E8}</ProjectGuid>' +
    sLineBreak + '    <MainSource>MultiUnitSnapshotCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="MultiUnitSnapshotCacheUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit MultiUnitSnapshotCacheUnit;' + sLineBreak +
    'interface' + sLineBreak + 'const' + sLineBreak +
    '  ChangedValue = 1;' + sLineBreak + 'type' + sLineBreak +
    '  TMultiUnitSnapshotCacheRecord = record' + sLineBreak + '    Value: Integer;' +
    sLineBreak + '  end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lFirstSnapshot := lFirstResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lFirstSnapshot.UnitCount);
      lFirstMetrics := lFirstResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lFirstMetrics.SnapshotCacheProbes);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheHits);
      Assert.AreEqual(2, lFirstMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCachePartialHitCount);
      Assert.AreEqual(1, lFirstMetrics.SnapshotCacheMissRebuildCount);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheUnitHits);
      Assert.AreEqual(2, lFirstMetrics.SnapshotCacheUnitMisses);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheUnitStaleEntries);
      Assert.IsTrue(lFirstMetrics.SnapshotSqlWriteMilliseconds > 0);
      Assert.IsTrue(lFirstMetrics.SnapshotCacheUnitBuildMilliseconds >= 0);
      Assert.IsTrue(lFirstMetrics.SnapshotCacheUnitMergeMilliseconds >= 0);
    finally
      lFirstSnapshot.Free;
    end;
  finally
    lFirstResult.Session.Free;
  end;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSecondSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lSecondSnapshot.UnitCount);
      lSecondMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheProbes);
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCachePartialHitCount);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMissRebuildCount);
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheUnitHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheUnitMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheUnitStaleEntries);
      Assert.AreEqual(Int64(0), lSecondMetrics.SnapshotSqlWriteMilliseconds);
      Assert.AreEqual(Int64(0), lSecondMetrics.SnapshotCacheUnitBuildMilliseconds);
      Assert.IsTrue(lSecondMetrics.SnapshotCacheUnitMergeMilliseconds >= 0);
    finally
      lSecondSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;

  TFile.WriteAllText(lUnitPath, 'unit MultiUnitSnapshotCacheUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TMultiUnitSnapshotCacheChangedRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak +
    'const' + sLineBreak + '  ChangedValue = 2;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lThirdSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lThirdSnapshot.UnitCount);
      lThirdMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lThirdMetrics.SnapshotCacheProbes);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCacheHits);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCachePartialHitCount);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheMissRebuildCount);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCacheUnitHits);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCacheUnitMisses);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheUnitStaleEntries);
      Assert.IsTrue(lThirdMetrics.SnapshotCacheUnitBuildMilliseconds >= 0);
      Assert.IsTrue(lThirdMetrics.SnapshotCacheUnitMergeMilliseconds >= 0);
      Assert.IsTrue(lThirdSnapshot.TryReferenceAt(lDprPath, 6, 13, lReferenceRef),
        'Expected cached main unit reference to resolve after changed unit rebuild.');
      Assert.IsTrue(lThirdSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit));
      lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
      Assert.AreNotEqual(0, Integer(lReference.TargetUnitId));
      Assert.IsTrue(lThirdSnapshot.TryFindUnitById(lReference.TargetUnitId, lUnit));
      lSymbol := lUnit.SymbolById(lReference.TargetSymbolId);
      Assert.AreEqual('ChangedValue', lThirdSnapshot.TextOf(lSymbol.NameId));
    finally
      lThirdSnapshot.Free;
    end;

    lSecondSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lSecondSnapshot.UnitCount);
      lSecondMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheProbes);
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCachePartialHitCount);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMissRebuildCount);
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheUnitHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheUnitMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheUnitStaleEntries);
      Assert.AreEqual(Int64(0), lSecondMetrics.SnapshotCacheUnitBuildMilliseconds);
    finally
      lSecondSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionSnapshotCacheReusesPathVariantProjectIdentity;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lOptions: TDelphiSemanticOptions;
  lPathVariant: string;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootName: string;
  lRootPath: string;
  lSecondMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSnapshot: TDelphiProjectSnapshot;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-path-variant-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'PathVariantSnapshotCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'PathVariantSnapshotCache.dproj');
  lUnitPath := TPath.Combine(lRootPath, 'PathVariantSnapshotCacheUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);
  lRootName := TPath.GetFileName(lRootPath);
  lPathVariant := StringReplace(UpperCase(CombinePath([lRootPath, '..', lRootName,
    'PathVariantSnapshotCache.dproj'])), '\', '/', [rfReplaceAll]);

  TFile.WriteAllText(lDprPath, 'program PathVariantSnapshotCache;' + sLineBreak +
    'uses PathVariantSnapshotCacheUnit;' + sLineBreak + 'begin' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{8D42FE30-5BC2-4589-8EDE-A04E48506138}</ProjectGuid>' +
    sLineBreak + '    <MainSource>PathVariantSnapshotCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="PathVariantSnapshotCacheUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit PathVariantSnapshotCacheUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TPathVariantSnapshotCacheRecord = record' + sLineBreak + '    Value: Integer;' +
    sLineBreak + '  end;' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lSnapshot := lFirstResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
      lFirstMetrics := lFirstResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lFirstMetrics.SnapshotCacheProbes);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheHits);
      Assert.AreEqual(2, lFirstMetrics.SnapshotCacheMisses);
    finally
      lSnapshot.Free;
    end;
  finally
    lFirstResult.Session.Free;
  end;

  lOptions.ProjectPath := lPathVariant;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
      lSecondMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheProbes);
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheUnitHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheUnitMisses);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionSnapshotCacheReusesTimestampOnlyChangedSource;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSecondMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-timestamp-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'TimestampSnapshotCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'TimestampSnapshotCache.dproj');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);
  TFile.WriteAllText(lDprPath, 'program TimestampSnapshotCache;' + sLineBreak +
    'type' + sLineBreak + '  TTimestampSnapshotRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak + 'begin' +
    sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{44D64E93-7113-41BB-B0EA-FC1B9B444BF6}</ProjectGuid>' +
    sLineBreak + '    <MainSource>TimestampSnapshotCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lSnapshot := lFirstResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
      lFirstMetrics := lFirstResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(1, lFirstMetrics.SnapshotCacheProbes);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheHits);
      Assert.AreEqual(1, lFirstMetrics.SnapshotCacheMisses);
    finally
      lSnapshot.Free;
    end;
  finally
    lFirstResult.Session.Free;
  end;

  TFile.SetLastWriteTimeUtc(lDprPath, TFile.GetLastWriteTimeUtc(lDprPath) +
    EncodeTime(0, 0, 5, 0));
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
      lSecondMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheProbes);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheUnitHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheUnitMisses);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionScopedPartialSnapshotCacheHitStoresMissedUnitUnderScopedIdentity;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSecondMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSnapshot: TDelphiProjectSnapshot;
  lThirdMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-scoped-partial-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'ScopedPartialSnapshotCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'ScopedPartialSnapshotCache.dproj');
  lUnitPath := TPath.Combine(lRootPath, 'ScopedPartialSnapshotCacheUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  TFile.WriteAllText(lDprPath, 'program ScopedPartialSnapshotCache;' +
    sLineBreak + 'uses ScopedPartialSnapshotCacheUnit;' + sLineBreak +
    'begin' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{8D8D3663-8935-4B81-8BDE-2D621BD44534}</ProjectGuid>' +
    sLineBreak + '    <MainSource>ScopedPartialSnapshotCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="ScopedPartialSnapshotCacheUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit ScopedPartialSnapshotCacheUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'type' + sLineBreak +
    '  TScopedPartialSnapshotCacheRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot([lDprPath]);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;

  TFile.AppendAllText(lUnitPath, sLineBreak +
    '// scoped partial snapshot cache invalidation probe' + sLineBreak,
    TEncoding.UTF8);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot([lDprPath]);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
      lSecondMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheProbes);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheHits);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(1, lSecondMetrics.SnapshotCachePartialHitCount);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMissRebuildCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot([lDprPath]);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
      lThirdMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lThirdMetrics.SnapshotCacheProbes);
      Assert.AreEqual(2, lThirdMetrics.SnapshotCacheHits);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheMisses);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCachePartialHitCount);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheMissRebuildCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionPartialSnapshotCacheRebuildResolvesReferencesToCachedUnits;
var
  lCachePath: string;
  lChangingPath: string;
  lDprPath: string;
  lDprojPath: string;
  lMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lOptions: TDelphiSemanticOptions;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSnapshot: TDelphiProjectSnapshot;
  lStablePath: string;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-partial-reference-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'PartialReferenceCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'PartialReferenceCache.dproj');
  lStablePath := TPath.Combine(lRootPath, 'PartialReferenceStableUnit.pas');
  lChangingPath := TPath.Combine(lRootPath, 'PartialReferenceChangingUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  TFile.WriteAllText(lDprPath, 'program PartialReferenceCache;' + sLineBreak +
    'uses PartialReferenceStableUnit, PartialReferenceChangingUnit;' +
    sLineBreak + 'begin' + sLineBreak + '  Touch;' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{2451ECAB-05F3-48BD-A108-3F63707012C7}</ProjectGuid>' +
    sLineBreak + '    <MainSource>PartialReferenceCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="PartialReferenceStableUnit.pas"/>' +
    sLineBreak + '    <DCCReference Include="PartialReferenceChangingUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lStablePath, 'unit PartialReferenceStableUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'const' + sLineBreak +
    '  StableValue = 7;' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lChangingPath, 'unit PartialReferenceChangingUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'procedure Touch;' + sLineBreak +
    'implementation' + sLineBreak + 'uses PartialReferenceStableUnit;' +
    sLineBreak + 'procedure Touch;' + sLineBreak + 'var' + sLineBreak +
    '  lValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  lValue := StableValue;' + sLineBreak + 'end;' + sLineBreak + 'end.',
    TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(3, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;

  TFile.WriteAllText(lChangingPath, 'unit PartialReferenceChangingUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'procedure Touch;' + sLineBreak +
    'implementation' + sLineBreak + 'uses PartialReferenceStableUnit;' +
    sLineBreak + 'procedure Touch;' + sLineBreak + 'var' + sLineBreak +
    '  lValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  lValue := StableValue + 1;' + sLineBreak + 'end;' + sLineBreak +
    'end.', TEncoding.UTF8);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(3, lSnapshot.UnitCount);
      lMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(3, lMetrics.SnapshotCacheProbes);
      Assert.AreEqual(2, lMetrics.SnapshotCacheHits);
      Assert.AreEqual(1, lMetrics.SnapshotCacheMisses);
      Assert.AreEqual(1, lMetrics.SnapshotCachePartialHitCount);
      Assert.IsTrue(lSnapshot.TryReferenceAt(lChangingPath, 10, 13, lReferenceRef),
        'Expected rebuilt unit reference to remain indexed after partial cache hit.');
      Assert.IsTrue(lSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit));
      lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
      Assert.AreNotEqual(0, Integer(lReference.TargetUnitId));
      Assert.IsTrue(lSnapshot.TryFindUnitById(lReference.TargetUnitId, lUnit));
      lSymbol := lUnit.SymbolById(lReference.TargetSymbolId);
      Assert.AreEqual('StableValue', lSnapshot.TextOf(lSymbol.NameId));
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionPartialSnapshotCacheInvalidationMatchesFullRebuildFacts;
var
  lCacheOptions: TDelphiSemanticOptions;
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lExpectedResult: TDelphiSemanticProjectSessionResult;
  lExpectedSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSnapshot: TDelphiProjectSnapshot;
  lStablePath: string;
  lTouchedPath: string;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-partial-invalidation-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'PartialInvalidationCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'PartialInvalidationCache.dproj');
  lStablePath := TPath.Combine(lRootPath, 'PartialInvalidationStableUnit.pas');
  lTouchedPath := TPath.Combine(lRootPath, 'PartialInvalidationTouchedUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  TFile.WriteAllText(lDprPath, 'program PartialInvalidationCache;' + sLineBreak +
    'uses PartialInvalidationStableUnit, PartialInvalidationTouchedUnit;' +
    sLineBreak + 'begin' + sLineBreak + '  Touch;' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{8B704690-D5B1-4D52-B677-C4F8299148B2}</ProjectGuid>' +
    sLineBreak + '    <MainSource>PartialInvalidationCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="PartialInvalidationStableUnit.pas"/>' +
    sLineBreak + '    <DCCReference Include="PartialInvalidationTouchedUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lStablePath, 'unit PartialInvalidationStableUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'const' + sLineBreak +
    '  StableInvalidationValue = 11;' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lTouchedPath, 'unit PartialInvalidationTouchedUnit;' +
    sLineBreak + 'interface' + sLineBreak + 'procedure Touch;' + sLineBreak +
    'implementation' + sLineBreak + 'uses PartialInvalidationStableUnit;' +
    sLineBreak + 'procedure Touch;' + sLineBreak + 'var' + sLineBreak +
    '  lValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  lValue := StableInvalidationValue;' + sLineBreak + 'end;' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(3, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;

  ExecProjectSessionCacheSql(lCachePath,
    'update snapshot_units set file_hash = ''poisoned'' where source_file_name like ' +
    '''%PartialInvalidationStableUnit.pas''');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(3, lSnapshot.UnitCount);
      lMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(3, lMetrics.SnapshotCacheProbes);
      Assert.AreEqual(2, lMetrics.SnapshotCacheHits);
      Assert.AreEqual(1, lMetrics.SnapshotCacheMisses);
      Assert.AreEqual(1, lMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(0, lMetrics.SnapshotCacheFullHitCount);
      Assert.AreEqual(1, lMetrics.SnapshotCachePartialHitCount);
      Assert.AreEqual(0, lMetrics.SnapshotCacheMissRebuildCount);
      Assert.AreEqual(2, lMetrics.SnapshotCacheUnitHits);
      Assert.AreEqual(1, lMetrics.SnapshotCacheUnitMisses);
      Assert.AreEqual(1, lMetrics.SnapshotCacheUnitStaleEntries);

      lCacheOptions := lOptions;
      lCacheOptions.SqliteCacheFileName := '';
      lExpectedResult := TDelphiSemanticProjectSession.Open(lCacheOptions);
      try
        Assert.IsTrue(lExpectedResult.Success);
        lExpectedSnapshot := lExpectedResult.Session.BuildSnapshot;
        try
          AssertSnapshotFactsEqual(lExpectedSnapshot, lSnapshot);
        finally
          lExpectedSnapshot.Free;
        end;
      finally
        lExpectedResult.Session.Free;
      end;
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionDiscoversAnsiDprInReferencesThroughSourceLoader;
var
  lCachePath: string;
  lDprBytes: TBytes;
  lDprPath: string;
  lDprojPath: string;
  lIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSnapshot: TDelphiProjectSnapshot;
  lUnitId: TSemanticUnitId;
  lUnitFileName: string;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('project-session-ansi-dpr');
  TDirectory.CreateDirectory(lRootPath);

  lUnitFileName := 'AnsiDpr' + Chr(233) + 'Unit.pas';
  lDprPath := TPath.Combine(lRootPath, 'AnsiDprProject.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'AnsiDprProject.dproj');
  lUnitPath := TPath.Combine(lRootPath, lUnitFileName);
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  lDprBytes := TBytes.Create(
    Ord('p'), Ord('r'), Ord('o'), Ord('g'), Ord('r'), Ord('a'), Ord('m'), Ord(' '),
    Ord('A'), Ord('n'), Ord('s'), Ord('i'), Ord('D'), Ord('p'), Ord('r'), Ord('P'),
    Ord('r'), Ord('o'), Ord('j'), Ord('e'), Ord('c'), Ord('t'), Ord(';'), 13, 10,
    Ord('u'), Ord('s'), Ord('e'), Ord('s'), Ord(' '), Ord('A'), Ord('n'), Ord('s'),
    Ord('i'), Ord('D'), Ord('p'), Ord('r'), Ord('U'), Ord('n'), Ord('i'), Ord('t'),
    Ord(' '), Ord('i'), Ord('n'), Ord(' '), Ord(''''), Ord('A'), Ord('n'), Ord('s'),
    Ord('i'), Ord('D'), Ord('p'), Ord('r'), $E9, Ord('U'), Ord('n'), Ord('i'),
    Ord('t'), Ord('.'), Ord('p'), Ord('a'), Ord('s'), Ord(''''), Ord(';'), 13, 10,
    Ord('b'), Ord('e'), Ord('g'), Ord('i'), Ord('n'), 13, 10, Ord('e'), Ord('n'),
    Ord('d'), Ord('.'));
  TFile.WriteAllBytes(lDprPath, lDprBytes);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{762E6D41-4EAB-424E-94DE-72E9510E0C8B}</ProjectGuid>' +
    sLineBreak + '    <MainSource>AnsiDprProject.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit AnsiDprUnit;' + sLineBreak +
    'interface' + sLineBreak + 'const' + sLineBreak +
    '  AnsiDprValue = 7;' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lIdentities := lResult.Session.BuildGlobalCacheIdentities;
    Assert.AreEqual(2, Integer(Length(lIdentities)));
    Assert.IsNotEmpty(lIdentities[0].FileHash);
    Assert.IsNotEmpty(lIdentities[1].FileHash);

    lSnapshot := lResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
      Assert.IsTrue(lSnapshot.TryFindUnitByFileName(lUnitPath, lUnitId),
        'Expected source-loader-decoded DPR in-reference unit in project snapshot.');
      lMetrics := lResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lMetrics.SnapshotCacheProbes);
      Assert.AreEqual(0, lMetrics.SnapshotCacheHits);
      Assert.AreEqual(2, lMetrics.SnapshotCacheMisses);
    finally
      lSnapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionSnapshotCacheRebuildsIncludedFileChanges;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lFirstSnapshot: TDelphiProjectSnapshot;
  lHighIndex: Integer;
  lIncludePath: string;
  lLowIndex: Integer;
  lNameId: TSemanticStringId;
  lOptions: TDelphiSemanticOptions;
  lRootPath: string;
  lSecondMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSecondResult: TDelphiSemanticProjectSessionResult;
  lSecondSnapshot: TDelphiProjectSnapshot;
  lThirdMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lThirdResult: TDelphiSemanticProjectSessionResult;
  lThirdSnapshot: TDelphiProjectSnapshot;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('snapshot-session-include-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'IncludeSnapshotCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'IncludeSnapshotCache.dproj');
  lIncludePath := TPath.Combine(lRootPath, 'IncludeSnapshotCache.inc');
  lUnitPath := TPath.Combine(lRootPath, 'IncludeSnapshotCacheUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  TFile.WriteAllText(lDprPath, 'program IncludeSnapshotCache;' + sLineBreak +
    'uses IncludeSnapshotCacheUnit;' + sLineBreak + 'begin' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{5E0EA758-DB37-455F-9A26-E6077E9A7E3E}</ProjectGuid>' +
    sLineBreak + '    <MainSource>IncludeSnapshotCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="IncludeSnapshotCacheUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit IncludeSnapshotCacheUnit;' + sLineBreak +
    'interface' + sLineBreak + '{$I IncludeSnapshotCache.inc}' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lIncludePath, 'const' + sLineBreak +
    '  IncludeSnapshotCacheValue = 1;' + sLineBreak, TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lFirstSnapshot := lFirstResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lFirstSnapshot.UnitCount);
      lFirstMetrics := lFirstResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lFirstMetrics.SnapshotCacheProbes);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheHits);
      Assert.AreEqual(2, lFirstMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lFirstMetrics.SnapshotCacheInvalidations);
      Assert.IsTrue(lFirstSnapshot.TryFindStringId('IncludeSnapshotCacheValue', lNameId));
      Assert.IsTrue(lFirstSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex));
    finally
      lFirstSnapshot.Free;
    end;
  finally
    lFirstResult.Session.Free;
  end;

  lSecondResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lSecondResult.Success);
    lSecondSnapshot := lSecondResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lSecondSnapshot.UnitCount);
      lSecondMetrics := lSecondResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheProbes);
      Assert.AreEqual(2, lSecondMetrics.SnapshotCacheHits);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lSecondMetrics.SnapshotCacheInvalidations);
    finally
      lSecondSnapshot.Free;
    end;
  finally
    lSecondResult.Session.Free;
  end;

  TFile.WriteAllText(lIncludePath, 'const' + sLineBreak +
    '  IncludeSnapshotCacheChangedValue = 2;' + sLineBreak, TEncoding.UTF8);

  lThirdResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lThirdResult.Success);
    lThirdSnapshot := lThirdResult.Session.BuildSnapshot;
    try
      Assert.AreEqual(2, lThirdSnapshot.UnitCount);
      lThirdMetrics := lThirdResult.Session.LastSnapshotBuildMetrics;
      Assert.AreEqual(2, lThirdMetrics.SnapshotCacheProbes);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCacheHits);
      Assert.AreEqual(1, lThirdMetrics.SnapshotCacheMisses);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheInvalidations);
      Assert.AreEqual(0, lThirdMetrics.SnapshotCacheUnitStaleEntries);
      Assert.IsTrue(lThirdSnapshot.TryFindStringId('IncludeSnapshotCacheChangedValue',
        lNameId));
      Assert.IsTrue(lThirdSnapshot.TrySymbolsByName(lNameId, lLowIndex, lHighIndex));
    finally
      lThirdSnapshot.Free;
    end;
  finally
    lThirdResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.BuildWithBindingFactsDoesNotWriteProjectFactsJsonSidecar;
var
  lCachePath: string;
  lDprPath: string;
  lDprojPath: string;
  lFirstFacts: TDelphiSemanticProjectWithBindingFacts;
  lFirstResult: TDelphiSemanticProjectSessionResult;
  lFourthFacts: TDelphiSemanticProjectWithBindingFacts;
  lFourthResult: TDelphiSemanticProjectSessionResult;
  lIncludePath: string;
  lOptions: TDelphiSemanticOptions;
  lProjectFactsSidecar: string;
  lRootPath: string;
  lSecondFacts: TDelphiSemanticProjectWithBindingFacts;
  lSecondResult: TDelphiSemanticProjectSessionResult;
  lThirdFacts: TDelphiSemanticProjectWithBindingFacts;
  lThirdResult: TDelphiSemanticProjectSessionResult;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('project-session-cache-temp');
  TDirectory.CreateDirectory(lRootPath);

  lDprPath := TPath.Combine(lRootPath, 'ProjectFactsCache.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'ProjectFactsCache.dproj');
  lIncludePath := TPath.Combine(lRootPath, 'ProjectFactsCache.inc');
  lUnitPath := TPath.Combine(lRootPath, 'ProjectFactsCacheUnit.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);
  lProjectFactsSidecar := lCachePath + '.project-facts.json';

  TFile.WriteAllText(lDprPath, 'program ProjectFactsCache;' + sLineBreak +
    'uses ProjectFactsCacheUnit;' + sLineBreak + 'begin' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{7103CF49-42A8-4C33-A46C-C4409732D985}</ProjectGuid>' +
    sLineBreak + '    <MainSource>ProjectFactsCache.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="ProjectFactsCacheUnit.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit ProjectFactsCacheUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TProjectFactsCacheRecord = record' + sLineBreak + '    Value: Integer;' +
    sLineBreak + '  end;' + sLineBreak + 'procedure UseCacheRecord;' +
    sLineBreak + 'implementation' + sLineBreak + '{$I ProjectFactsCache.inc}' +
    sLineBreak + 'procedure UseCacheRecord;' + sLineBreak + 'var' + sLineBreak +
    '  lRecord: TProjectFactsCacheRecord;' + sLineBreak + 'begin' +
    sLineBreak + '  with lRecord do' + sLineBreak + '    Value := 1;' +
    sLineBreak + 'end;' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lIncludePath, '// include cache probe' + sLineBreak,
    TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lOptions.SqliteCacheFileName := lCachePath;
  lOptions.SkipWithBindingSemanticGraph := True;

  lFirstResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFirstResult.Success);
    lFirstFacts := lFirstResult.Session.BuildWithBindingFacts([lUnitPath]);
  finally
    lFirstResult.Session.Free;
  end;
  Assert.AreEqual(Int64(0), lFirstFacts.Metrics.ProjectFactsCacheHits);
  Assert.AreEqual(Int64(0), lFirstFacts.Metrics.ProjectFactsCacheMisses);
  Assert.IsFalse(TFile.Exists(lProjectFactsSidecar),
    'BuildWithBindingFacts must not write the obsolete project-facts JSON sidecar.');
  Assert.IsTrue(Length(lFirstFacts.Bindings) > 0,
    'Expected fixture to produce with-binding facts.');

  lSecondResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lSecondResult.Success);
    lSecondFacts := lSecondResult.Session.BuildWithBindingFacts([lUnitPath]);
  finally
    lSecondResult.Session.Free;
  end;
  Assert.IsTrue(lSecondFacts.Metrics.SemanticCacheHits > 0,
    'Expected unchanged unit models to be loaded from the persistent semantic cache.');
  Assert.AreEqual(Int64(0), lSecondFacts.Metrics.ProjectFactsCacheHits);
  Assert.AreEqual(Int64(0), lSecondFacts.Metrics.ProjectFactsCacheMisses);
  Assert.IsFalse(TFile.Exists(lProjectFactsSidecar),
    'BuildWithBindingFacts must not reuse the obsolete project-facts JSON sidecar.');
  Assert.AreEqual(Length(lFirstFacts.Bindings), Length(lSecondFacts.Bindings));
  Assert.AreEqual(Length(lFirstFacts.Symbols), Length(lSecondFacts.Symbols));
  Assert.AreEqual(lFirstFacts.Bindings[0].SemanticId,
    lSecondFacts.Bindings[0].SemanticId);
  Assert.AreEqual(lFirstFacts.Bindings[0].SelectorText,
    lSecondFacts.Bindings[0].SelectorText);
  Assert.AreEqual(lFirstFacts.Bindings[0].Status, lSecondFacts.Bindings[0].Status);
  Assert.IsTrue(Length(lFirstFacts.Bindings[0].References) > 0,
    'Expected fixture to produce cached binding references.');
  Assert.AreEqual(Length(lFirstFacts.Bindings[0].References),
    Length(lSecondFacts.Bindings[0].References));
  Assert.AreEqual(lFirstFacts.Bindings[0].References[0].Name,
    lSecondFacts.Bindings[0].References[0].Name);
  Assert.AreEqual(lFirstFacts.Bindings[0].References[0].Classification,
    lSecondFacts.Bindings[0].References[0].Classification);

  TFile.AppendAllText(lUnitPath, sLineBreak +
    '// project facts cache invalidation probe' + sLineBreak, TEncoding.UTF8);
  lThirdResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lThirdResult.Success);
    lThirdFacts := lThirdResult.Session.BuildWithBindingFacts([lUnitPath]);
  finally
    lThirdResult.Session.Free;
  end;
  Assert.IsTrue(lThirdFacts.Metrics.SemanticCacheInvalidations > 0,
    'Expected changed source to invalidate persistent unit models.');
  Assert.IsTrue(lThirdFacts.Metrics.SemanticCacheMisses > 0,
    'Expected changed source to rebuild stale unit models.');
  Assert.AreEqual(Int64(0), lThirdFacts.Metrics.ProjectFactsCacheInvalidations);
  Assert.AreEqual(Int64(0), lThirdFacts.Metrics.ProjectFactsCacheMisses);
  Assert.IsFalse(TFile.Exists(lProjectFactsSidecar),
    'Changed source must not resurrect the obsolete project-facts JSON sidecar.');

  TFile.AppendAllText(lIncludePath, sLineBreak +
    '// project facts include invalidation probe' + sLineBreak, TEncoding.UTF8);
  lFourthResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lFourthResult.Success);
    lFourthFacts := lFourthResult.Session.BuildWithBindingFacts([lUnitPath]);
  finally
    lFourthResult.Session.Free;
  end;
  Assert.IsTrue(lFourthFacts.Metrics.SemanticCacheInvalidations > 0,
    'Expected changed include to invalidate persistent unit models.');
  Assert.IsTrue(lFourthFacts.Metrics.SemanticCacheMisses > 0,
    'Expected changed include to rebuild stale unit models.');
  Assert.AreEqual(Int64(0), lFourthFacts.Metrics.ProjectFactsCacheInvalidations);
  Assert.AreEqual(Int64(0), lFourthFacts.Metrics.ProjectFactsCacheMisses);
  Assert.IsFalse(TFile.Exists(lProjectFactsSidecar),
    'Changed include must not resurrect the obsolete project-facts JSON sidecar.');
end;

procedure TProjectSessionTests.BuildWithBindingFactsSkipsReferencesForNonBodyModels;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMainModel: TDelphiSemanticUnitModel;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lUnitPath: string;
begin
  lUnitPath := FixturePath('ProjectWithBinding\ProjectWithUnit.pas');

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.SkipWithBindingSemanticGraph := True;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts([lUnitPath]);
  finally
    lResult.Session.Free;
  end;

  lMainModel := Default(TDelphiSemanticUnitModel);
  for lModel in lFacts.UnitModels do
    if SameText(ExtractFileName(lModel.FileName), 'ProjectWithBinding.dpr') then
    begin
      lMainModel := lModel;
      Break;
    end;

  Assert.AreEqual('ProjectWithBinding', lMainModel.UnitName);
  Assert.IsTrue(Length(lMainModel.Declarations) > 0);
  Assert.AreEqual(0, Integer(Length(lMainModel.WithStatements)));
  Assert.AreEqual(0, Integer(Length(lMainModel.References)));
  Assert.IsTrue(Length(lFacts.Bindings) > 0);
end;

procedure TProjectSessionTests.ScopedBuildWithBindingFactsDoesNotPolluteGenericCacheEntries;
var
  lCachePath: string;
  lGenericFacts: TDelphiSemanticProjectWithBindingFacts;
  lGenericResult: TDelphiSemanticProjectSessionResult;
  lMainModel: TDelphiSemanticUnitModel;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticOptions;
  lScopedFacts: TDelphiSemanticProjectWithBindingFacts;
  lScopedResult: TDelphiSemanticProjectSessionResult;
  lScopedUnitPath: string;
begin
  lCachePath := TPath.Combine(ProjectSessionTempPath('scoped-cache-contamination'),
    'semantic-cache.sqlite3');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lCachePath));
  lScopedUnitPath := FixturePath('ProjectWithBinding\ProjectWithUnit.pas');

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.SqliteCacheFileName := lCachePath;
  lOptions.SkipWithBindingSemanticGraph := True;

  lScopedResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lScopedResult.Success);
    lScopedFacts := lScopedResult.Session.BuildWithBindingFacts([lScopedUnitPath]);
  finally
    lScopedResult.Session.Free;
  end;
  Assert.IsTrue(Length(lScopedFacts.Bindings) > 0);

  lGenericResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lGenericResult.Success);
    lGenericFacts := lGenericResult.Session.BuildWithBindingFacts;
  finally
    lGenericResult.Session.Free;
  end;

  lMainModel := Default(TDelphiSemanticUnitModel);
  for lModel in lGenericFacts.UnitModels do
    if SameText(ExtractFileName(lModel.FileName), 'ProjectWithBinding.dpr') then
    begin
      lMainModel := lModel;
      Break;
    end;

  Assert.AreEqual('ProjectWithBinding', lMainModel.UnitName);
  Assert.IsTrue(Length(lMainModel.WithStatements) > 0,
    'Generic facts must not reuse scoped no-body cache entries.');
  Assert.IsTrue(Length(lMainModel.References) > 0,
    'Generic facts must not reuse scoped no-reference cache entries.');
end;

procedure TProjectSessionTests.InvalidProjectReturnsStructuredSessionDiagnostic;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectContext\Missing\MissingProject.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsFalse(lResult.Success);
    Assert.AreEqual(psInvalidProject, lResult.Status);
    Assert.AreEqual('project-context', lResult.Provenance);
    Assert.IsNull(lResult.Session);
    Assert.AreEqual(1, Integer(Length(lResult.Diagnostics)));
    Assert.AreEqual('PROJECT_FILE_NOT_FOUND', lResult.Diagnostics[0].Code);
    Assert.AreEqual(dsError, lResult.Diagnostics[0].Severity);
  finally
    lResult.Session.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectSessionTests);

end.
