unit Test.ProjectSession;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TProjectSessionTests = class
  private
    function FixturePath(const aRelativePath: string): string;
    procedure AssertReferenceFactsEqual(const aExpectedSnapshot,
      aActualSnapshot: TDelphiProjectSnapshot; const aExpectedUnit,
      aActualUnit: TUnitSnapshot; const aReferenceId: TSemanticReferenceId);
    procedure AssertSnapshotFactsEqual(const aExpectedSnapshot,
      aActualSnapshot: TDelphiProjectSnapshot);
    procedure AssertSymbolFactsEqual(const aExpectedSnapshot,
      aActualSnapshot: TDelphiProjectSnapshot; const aExpectedUnit,
      aActualUnit: TUnitSnapshot; const aSymbolId: TSemanticSymbolId);
    procedure AssertWithFactsEqual(const aExpectedSnapshot,
      aActualSnapshot: TDelphiProjectSnapshot; const aExpectedUnit,
      aActualUnit: TUnitSnapshot; const aWithId: TSemanticWithId);
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
    procedure ProjectSessionBuildsSnapshotFromExtractedModels;
    [Test]
    procedure ProjectSessionParallelSnapshotBuildMatchesSequentialFacts;
    [Test]
    procedure ProjectSessionParallelRemoveWithPlanMatchesSequentialCounts;
    [Test]
    procedure ProjectSessionSnapshotMetricsExposeCacheUsefulnessTelemetry;
    [Test]
    procedure ProjectSessionReusesUnchangedMultiUnitSnapshotCacheEntries;
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
  System.IOUtils,
  System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.Api,
  DelphiSemantics.Api.RemoveWith,
  DelphiSemantics.Model,
  DelphiSemantics.ProjectContext,
  DelphiSemantics.ProjectSession;

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

function TProjectSessionTests.FixturePath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(
    TPath.Combine(ExtractFilePath(ParamStr(0)), '..\fixtures'),
    aRelativePath));
end;

procedure TProjectSessionTests.AssertReferenceFactsEqual(const aExpectedSnapshot,
  aActualSnapshot: TDelphiProjectSnapshot; const aExpectedUnit,
  aActualUnit: TUnitSnapshot; const aReferenceId: TSemanticReferenceId);
var
  lActual: TSemanticReferenceFact;
  lExpected: TSemanticReferenceFact;
begin
  lExpected := aExpectedUnit.ReferenceById(aReferenceId);
  lActual := aActualUnit.ReferenceById(aReferenceId);
  Assert.AreEqual(Integer(lExpected.Id), Integer(lActual.Id));
  Assert.AreEqual(Integer(lExpected.UnitId), Integer(lActual.UnitId));
  Assert.AreEqual(Integer(lExpected.WithId), Integer(lActual.WithId));
  Assert.AreEqual(Integer(lExpected.TargetUnitId), Integer(lActual.TargetUnitId));
  Assert.AreEqual(Integer(lExpected.TargetSymbolId), Integer(lActual.TargetSymbolId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.NameId),
    aActualSnapshot.TextOf(lActual.NameId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.ReceiverTypeId),
    aActualSnapshot.TextOf(lActual.ReceiverTypeId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.TypeId),
    aActualSnapshot.TextOf(lActual.TypeId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.RoutineId),
    aActualSnapshot.TextOf(lActual.RoutineId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.SectionKindId),
    aActualSnapshot.TextOf(lActual.SectionKindId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.SourceKindId),
    aActualSnapshot.TextOf(lActual.SourceKindId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.ClassificationId),
    aActualSnapshot.TextOf(lActual.ClassificationId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.LookupSourceId),
    aActualSnapshot.TextOf(lActual.LookupSourceId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.ReasonId),
    aActualSnapshot.TextOf(lActual.ReasonId));
  Assert.AreEqual(lExpected.Line, lActual.Line);
  Assert.AreEqual(lExpected.Column, lActual.Column);
  Assert.AreEqual(lExpected.EndLine, lActual.EndLine);
  Assert.AreEqual(lExpected.EndColumn, lActual.EndColumn);
end;

procedure TProjectSessionTests.AssertSnapshotFactsEqual(const aExpectedSnapshot,
  aActualSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  lActualUnit: TUnitSnapshot;
  lExpectedUnit: TUnitSnapshot;
  lReferenceId: TSemanticReferenceId;
  lSymbolId: TSemanticSymbolId;
  lWithId: TSemanticWithId;
begin
  Assert.AreEqual(aExpectedSnapshot.UnitCount, aActualSnapshot.UnitCount);
  for i := 0 to aExpectedSnapshot.UnitCount - 1 do
  begin
    lExpectedUnit := aExpectedSnapshot.UnitByIndex(i);
    lActualUnit := aActualSnapshot.UnitByIndex(i);
    Assert.AreEqual(Integer(lExpectedUnit.UnitId), Integer(lActualUnit.UnitId));
    Assert.AreEqual(aExpectedSnapshot.TextOf(lExpectedUnit.FileNameId),
      aActualSnapshot.TextOf(lActualUnit.FileNameId));
    Assert.AreEqual(aExpectedSnapshot.TextOf(lExpectedUnit.UnitNameId),
      aActualSnapshot.TextOf(lActualUnit.UnitNameId));
    Assert.AreEqual(lExpectedUnit.SymbolCount, lActualUnit.SymbolCount);
    Assert.AreEqual(lExpectedUnit.WithStatementCount, lActualUnit.WithStatementCount);
    Assert.AreEqual(lExpectedUnit.ReferenceCount, lActualUnit.ReferenceCount);

    for lSymbolId := 1 to TSemanticSymbolId(lExpectedUnit.SymbolCount) do
      AssertSymbolFactsEqual(aExpectedSnapshot, aActualSnapshot, lExpectedUnit,
        lActualUnit, lSymbolId);
    for lWithId := 1 to TSemanticWithId(lExpectedUnit.WithStatementCount) do
      AssertWithFactsEqual(aExpectedSnapshot, aActualSnapshot, lExpectedUnit,
        lActualUnit, lWithId);
    for lReferenceId := 1 to TSemanticReferenceId(lExpectedUnit.ReferenceCount) do
      AssertReferenceFactsEqual(aExpectedSnapshot, aActualSnapshot, lExpectedUnit,
        lActualUnit, lReferenceId);
  end;
end;

procedure TProjectSessionTests.AssertSymbolFactsEqual(const aExpectedSnapshot,
  aActualSnapshot: TDelphiProjectSnapshot; const aExpectedUnit,
  aActualUnit: TUnitSnapshot; const aSymbolId: TSemanticSymbolId);
var
  lActual: TSemanticSymbolFact;
  lExpected: TSemanticSymbolFact;
begin
  lExpected := aExpectedUnit.SymbolById(aSymbolId);
  lActual := aActualUnit.SymbolById(aSymbolId);
  Assert.AreEqual(Integer(lExpected.Id), Integer(lActual.Id));
  Assert.AreEqual(Integer(lExpected.UnitId), Integer(lActual.UnitId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.NameId),
    aActualSnapshot.TextOf(lActual.NameId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.OwnerTypeId),
    aActualSnapshot.TextOf(lActual.OwnerTypeId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.TypeId),
    aActualSnapshot.TextOf(lActual.TypeId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.RoutineId),
    aActualSnapshot.TextOf(lActual.RoutineId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.KindId),
    aActualSnapshot.TextOf(lActual.KindId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.SectionKindId),
    aActualSnapshot.TextOf(lActual.SectionKindId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.SourceKindId),
    aActualSnapshot.TextOf(lActual.SourceKindId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.VisibilityId),
    aActualSnapshot.TextOf(lActual.VisibilityId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.SignatureId),
    aActualSnapshot.TextOf(lActual.SignatureId));
  Assert.AreEqual(Int64(lExpected.Flags), Int64(lActual.Flags));
  Assert.AreEqual(lExpected.Line, lActual.Line);
  Assert.AreEqual(lExpected.Column, lActual.Column);
  Assert.AreEqual(lExpected.EndLine, lActual.EndLine);
  Assert.AreEqual(lExpected.EndColumn, lActual.EndColumn);
end;

procedure TProjectSessionTests.AssertWithFactsEqual(const aExpectedSnapshot,
  aActualSnapshot: TDelphiProjectSnapshot; const aExpectedUnit,
  aActualUnit: TUnitSnapshot; const aWithId: TSemanticWithId);
var
  lActual: TSemanticWithStatementFact;
  lExpected: TSemanticWithStatementFact;
begin
  lExpected := aExpectedUnit.WithStatementById(aWithId);
  lActual := aActualUnit.WithStatementById(aWithId);
  Assert.AreEqual(Integer(lExpected.Id), Integer(lActual.Id));
  Assert.AreEqual(Integer(lExpected.UnitId), Integer(lActual.UnitId));
  Assert.AreEqual(aExpectedSnapshot.TextOf(lExpected.RoutineId),
    aActualSnapshot.TextOf(lActual.RoutineId));
  Assert.AreEqual(lExpected.SelectorStartLine, lActual.SelectorStartLine);
  Assert.AreEqual(lExpected.SelectorStartColumn, lActual.SelectorStartColumn);
  Assert.AreEqual(lExpected.BodyStartLine, lActual.BodyStartLine);
  Assert.AreEqual(lExpected.BodyStartColumn, lActual.BodyStartColumn);
  Assert.AreEqual(lExpected.BodyEndLine, lActual.BodyEndLine);
  Assert.AreEqual(lExpected.BodyEndColumn, lActual.BodyEndColumn);
  Assert.AreEqual(Int64(lExpected.Flags), Int64(lActual.Flags));
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
  lSymbolRef: TSemanticSymbolRef;
  lTypeNameId: TSemanticStringId;
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
      Assert.AreEqual(1, Integer(lUnitId));

      Assert.IsTrue(lSnapshot.TryFindStringId('TProjectWithRecord', lTypeNameId));
      Assert.IsTrue(lSnapshot.TryTypesByName(lTypeNameId, lLowIndex, lHighIndex));
      Assert.IsTrue(lSnapshot.TryFindStringId('Value', lMemberNameId));
      Assert.IsTrue(lSnapshot.TryFindMember(lTypeNameId, lMemberNameId, lSymbolRef));
      Assert.AreEqual(1, Integer(lSymbolRef.UnitId));
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
