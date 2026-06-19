unit Test.Snapshot;

interface

uses
  DUnitX.TestFramework;

type
  [TestFixture]
  TSnapshotTests = class
  public
    [Test]
    procedure MemberKeyPacksOwnerAndNameIds;
    [Test]
    procedure ProjectSnapshotIndexesMembersPositionsAndReferences;
    [Test]
    procedure ProjectSnapshotIndexesOnlyExplicitTypeFacts;
    [Test]
    procedure ProjectSnapshotReferenceAtUsesFileLineIndex;
    [Test]
    procedure ProjectSnapshotFreezesUnitsAndExposesReadOnlyStrings;
    [Test]
    procedure ProjectSnapshotUsesPackedMemberKeysAndBuilderBoundary;
    [Test]
    procedure ParallelSnapshotWorkerTimeoutReportsWorkerAndSourceFile;
    [Test]
    procedure SnapshotBuilderResolvesReferenceTargetsWithoutLegacyProjectIndex;
    [Test]
    procedure SnapshotBuilderUsesBoundedWorkerJoins;
    [Test]
    procedure SnapshotWorkerPipelineLivesBehindFocusedBoundary;
    [Test]
    procedure SnapshotReferenceTargetsKeepOverloadedRoutineLocalAmbiguityUnresolved;
    [Test]
    procedure SnapshotReferenceTargetsUseLineQualifiedRoutineForWeakOwners;
    [Test]
    procedure SnapshotReferenceTargetsResolveExtractedClassMethodShadows;
    [Test]
    procedure SnapshotReferenceTargetsResolveSymbolMapFixtureShadows;
    [Test]
    procedure ProjectSnapshotMergePreservesCrossUnitDuplicateTargetReferences;
    [Test]
    procedure SnapshotUnitDoesNotUseJsonLiveRepresentation;
    [Test]
    procedure StringPoolInternsStableCaseAwareIds;
    [Test]
    procedure UnitSnapshotAssignsStableDenseFactIds;
    [Test]
    procedure UnitSnapshotFindsWithCandidatesBySourceLine;
    [Test]
    procedure UnitSnapshotChoosesInnermostWithCandidateForSourceLine;
    [Test]
    procedure UnitSnapshotReturnsReferencesForWithWithoutReferenceScan;
    [Test]
    procedure UnitSnapshotStoresFactsAsRecords;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils,
  DelphiSemantics.Model, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.PositionResolver, DelphiSemantics.WithBinding,
  Test.Support;

const
  cSnapshotWorkerJoinTimeoutEnv =
    'DELPHI_SEMANTICS_SNAPSHOT_WORKER_JOIN_TIMEOUT_MS';
  cSnapshotWorkerTestStallFileEnv =
    'DELPHI_SEMANTICS_TEST_SNAPSHOT_WORKER_STALL_FILE';
  cSnapshotWorkerTestStallMsEnv =
    'DELPHI_SEMANTICS_TEST_SNAPSHOT_WORKER_STALL_MS';

procedure TSnapshotTests.MemberKeyPacksOwnerAndNameIds;
var
  lExpected: UInt64;
  lFirst: UInt64;
  lOtherName: UInt64;
  lOtherOwner: UInt64;
begin
  lExpected := (UInt64(1) shl 32) or UInt64(2);

  lFirst := MemberKey(1, 2);
  lOtherName := MemberKey(1, 3);
  lOtherOwner := MemberKey(2, 2);

  Assert.AreEqual(lExpected, lFirst);
  Assert.IsTrue(lFirst <> lOtherName, 'Different names must not collide.');
  Assert.IsTrue(lFirst <> lOtherOwner, 'Different owners must not collide.');
end;

procedure TSnapshotTests.ProjectSnapshotIndexesMembersPositionsAndReferences;
var
  i: Integer;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFileNameId: TSemanticStringId;
  lFoundFirstUnit: Boolean;
  lFoundSecondUnit: Boolean;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lMemberNameId: TSemanticStringId;
  lMemberRef: TSemanticSymbolRef;
  lMemberSymbolId: TSemanticSymbolId;
  lOtherFileNameId: TSemanticStringId;
  lOtherUnit: TUnitSnapshot;
  lOtherUnitNameId: TSemanticStringId;
  lOwnerTypeId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
  lUnitNameId: TSemanticStringId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('UnitA.pas');
    lUnitNameId := lBuilder.Strings.Intern('UnitA');
    lOtherFileNameId := lBuilder.Strings.Intern('UnitB.pas');
    lOtherUnitNameId := lBuilder.Strings.Intern('UnitB');
    lOwnerTypeId := lBuilder.Strings.Intern('TWidget');
    lMemberNameId := lBuilder.Strings.Intern('Value');

    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.OwnerTypeId := lOwnerTypeId;
    lSymbol.NameId := lMemberNameId;
    lSymbol.Line := 12;
    lSymbol.Column := 5;
    lSymbol.EndLine := 12;
    lSymbol.EndColumn := 10;
    lMemberSymbolId := lUnit.AddSymbol(lSymbol);

    lReference := Default(TSemanticReferenceFact);
    lReference.TargetUnitId := 1;
    lReference.TargetSymbolId := lMemberSymbolId;
    lReference.Line := 22;
    lReference.Column := 7;
    lReference.EndLine := 23;
    lReference.EndColumn := 4;
    lUnit.AddReference(lReference);

    lOtherUnit := TUnitSnapshot.Create(2, lOtherFileNameId, lOtherUnitNameId);
    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.OwnerTypeId := lOwnerTypeId;
    lSymbol.NameId := lMemberNameId;
    lSymbol.Line := 8;
    lSymbol.Column := 3;
    lSymbol.EndLine := 8;
    lSymbol.EndColumn := 8;
    lOtherUnit.AddSymbol(lSymbol);

    lBuilder.AddUnit(lUnit);
    lBuilder.AddUnit(lOtherUnit);
    lProject := lBuilder.Build;
    Assert.AreEqual(0, lBuilder.UnitCount, 'Build must transfer unit ownership out of the builder.');
  finally
    lBuilder.Free;
  end;
  try
    Assert.AreEqual(2, lProject.UnitCount);
    Assert.IsTrue(lProject.TryFindUnitByFileName('unita.pas', lUnitId));
    Assert.AreEqual(1, Integer(lUnitId));
    Assert.IsTrue(lProject.TryFindUnitByFileName('unitb.pas', lUnitId));
    Assert.AreEqual(2, Integer(lUnitId));
    Assert.IsTrue(lProject.TryFindMember(lOwnerTypeId, lMemberNameId, lSymbolRef));
    Assert.AreEqual(1, Integer(lSymbolRef.UnitId));
    Assert.AreEqual(Integer(lMemberSymbolId), Integer(lSymbolRef.SymbolId));
    Assert.IsTrue(lProject.TryFindMembers(lOwnerTypeId, lMemberNameId, lLowIndex, lHighIndex));
    Assert.AreEqual(2, lHighIndex - lLowIndex + 1);
    lFoundFirstUnit := False;
    lFoundSecondUnit := False;
    for i := lLowIndex to lHighIndex do
    begin
      lMemberRef := lProject.MemberRefByOwnerAndNameIndex(i);
      lFoundFirstUnit := lFoundFirstUnit or (lMemberRef.UnitId = 1);
      lFoundSecondUnit := lFoundSecondUnit or (lMemberRef.UnitId = 2);
    end;
    Assert.IsTrue(lFoundFirstUnit, 'Expected duplicate member candidates to retain the first unit.');
    Assert.IsTrue(lFoundSecondUnit, 'Expected duplicate member candidates to retain the second unit.');
    Assert.IsTrue(lProject.TrySymbolAt('UnitA.pas', 12, 8, lSymbolRef));
    Assert.AreEqual(Integer(lMemberSymbolId), Integer(lSymbolRef.SymbolId));
    Assert.IsTrue(lProject.TryReferenceAt('UnitA.pas', 22, 9, lReferenceRef));
    Assert.AreEqual(1, Integer(lReferenceRef.ReferenceId));
    Assert.IsTrue(lProject.TryReferenceAt('UnitA.pas', 23, 3, lReferenceRef),
      'Reference file/line index must include every line in a multi-line reference span.');
    Assert.AreEqual(1, Integer(lReferenceRef.ReferenceId));
    Assert.IsFalse(lProject.TryReferenceAt('UnitA.pas', 23, 5, lReferenceRef),
      'Reference lookup must still respect the end column after indexed line selection.');
    Assert.IsTrue(lProject.TryReferencesForSymbol(lSymbolRef, lLowIndex, lHighIndex));
    Assert.AreEqual(1, lHighIndex - lLowIndex + 1);
    lReferenceRef := lProject.ReferenceRefBySymbolIndex(lLowIndex);
    Assert.AreEqual(1, Integer(lReferenceRef.UnitId));
    Assert.AreEqual(1, Integer(lReferenceRef.ReferenceId));
  finally
    lProject.Free;
  end;
end;

procedure TSnapshotTests.ProjectSnapshotIndexesOnlyExplicitTypeFacts;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFileNameId: TSemanticStringId;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lRoutineKindId: TSemanticStringId;
  lSymbol: TSemanticSymbolFact;
  lTypeKindId: TSemanticStringId;
  lTypeSymbolId: TSemanticSymbolId;
  lTypeRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('UnitA.pas');
    lUnitNameId := lBuilder.Strings.Intern('UnitA');
    lNameId := lBuilder.Strings.Intern('SharedName');
    lRoutineKindId := lBuilder.Strings.Intern('routine');
    lTypeKindId := lBuilder.Strings.Intern('type');

    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lNameId;
    lSymbol.KindId := lRoutineKindId;
    lUnit.AddSymbol(lSymbol);

    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lNameId;
    lSymbol.KindId := lTypeKindId;
    lTypeSymbolId := lUnit.AddSymbol(lSymbol);

    lBuilder.AddUnit(lUnit);
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    Assert.IsTrue(lProject.TryTypesByName(lNameId, lLowIndex, lHighIndex));
    Assert.AreEqual(1, lHighIndex - lLowIndex + 1);
    lTypeRef := lProject.TypeRefByNameIndex(lLowIndex);
    Assert.AreEqual(1, Integer(lTypeRef.UnitId));
    Assert.AreEqual(Integer(lTypeSymbolId), Integer(lTypeRef.SymbolId));
  finally
    lProject.Free;
  end;
end;

procedure TSnapshotTests.ProjectSnapshotReferenceAtUsesFileLineIndex;
var
  lNextFunctionStart: Integer;
  lSourceFileName: string;
  lSourceText: string;
  lTryReferenceAtStart: Integer;
  lTryReferenceAtText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lTryReferenceAtStart := Pos('function TDelphiProjectSnapshot.TryReferenceAt', lSourceText);
  lNextFunctionStart := PosEx('function TDelphiProjectSnapshot.TrySymbolsByName',
    lSourceText, lTryReferenceAtStart + 1);
  Assert.IsTrue((lTryReferenceAtStart > 0) and (lNextFunctionStart > lTryReferenceAtStart),
    'Expected TryReferenceAt source section.');

  lTryReferenceAtText := Copy(lSourceText, lTryReferenceAtStart,
    lNextFunctionStart - lTryReferenceAtStart);
  Assert.IsTrue(ContainsText(lSourceText, 'fReferencesByFileAndLine'),
    'Snapshot must build a reference file/line index.');
  Assert.IsTrue(ContainsText(lTryReferenceAtText, 'SourceLineKey('),
    'TryReferenceAt must probe the reference file/line index.');
  Assert.IsFalse(ContainsText(lTryReferenceAtText, 'for i := 1 to lUnit.ReferenceCount do'),
    'TryReferenceAt must not scan every reference in the unit.');
end;

procedure TSnapshotTests.ProjectSnapshotFreezesUnitsAndExposesReadOnlyStrings;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFileNameId: TSemanticStringId;
  lFoundFileNameId: TSemanticStringId;
  lPool: TSemanticStringPool;
  lProject: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lPool := lBuilder.Strings;
    lFileNameId := lBuilder.Strings.Intern('UnitA.pas');
    lUnitNameId := lBuilder.Strings.Intern('UnitA');
    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    lBuilder.AddUnit(lUnit);
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    Assert.AreEqual('UnitA.pas', lProject.TextOf(lFileNameId));
    Assert.IsTrue(lProject.TryFindStringId('unita.pas', lFoundFileNameId));
    Assert.AreEqual(Integer(lFileNameId), Integer(lFoundFileNameId));
    Assert.IsFalse(lProject.TryFindStringId('MissingName', lFoundFileNameId));

    lSymbol := Default(TSemanticSymbolFact);
    Assert.WillRaise(
      procedure
      begin
        lUnit.AddSymbol(lSymbol);
      end, Exception);
    Assert.WillRaise(
      procedure
      begin
        lPool.Intern('LateName');
      end, Exception);
  finally
    lProject.Free;
  end;
end;

procedure TSnapshotTests.ProjectSnapshotUsesPackedMemberKeysAndBuilderBoundary;
var
  lMutableStringPropertyIndex: Integer;
  lProjectClassEndIndex: Integer;
  lProjectClassIndex: Integer;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText,
    'fMembersByOwnerAndName: TDictionary<UInt64, TSemanticSymbolRef>'),
    'Project snapshot member lookup must use packed owner/name keys.');
  Assert.IsTrue(ContainsText(lSourceText, 'TDelphiProjectSnapshotBuilder'),
    'Construction should stay in a builder so project snapshots can be consumed as immutable.');
  lProjectClassIndex := Pos('TDelphiProjectSnapshot = class' + sLineBreak + '  private', lSourceText);
  lProjectClassEndIndex := PosEx('function MemberKey', lSourceText, lProjectClassIndex);
  lMutableStringPropertyIndex := PosEx('property Strings: TSemanticStringPool read fStrings',
    lSourceText, lProjectClassIndex);
  Assert.IsFalse((lMutableStringPropertyIndex > 0)
    and (lMutableStringPropertyIndex < lProjectClassEndIndex),
    'Built snapshots should expose read-only string lookup instead of the mutable string pool.');
  Assert.IsFalse(ContainsText(lSourceText, 'procedure TDelphiProjectSnapshot.AddUnit'),
    'Public consumers should not mutate a built project snapshot.');
end;

procedure TSnapshotTests.ParallelSnapshotWorkerTimeoutReportsWorkerAndSourceFile;
var
  i: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSnapshotBuildOptions;
  lScopedStallFile: TScopedEnvironmentVariable;
  lScopedStallMs: TScopedEnvironmentVariable;
  lScopedTimeout: TScopedEnvironmentVariable;
  lSnapshot: TDelphiProjectSnapshot;
begin
  SetLength(lModels, 2);
  lDeclaration := Default(TDelphiSemanticDeclaration);
  lDeclaration.Kind := 'type';
  lDeclaration.SectionKind := 'interface';
  lDeclaration.Line := 1;
  lDeclaration.Column := 1;
  for i := 0 to High(lModels) do
  begin
    lModels[i].Success := True;
    lModels[i].UnitName := 'TimeoutUnit' + IntToStr(i);
    lModels[i].FileName := 'TimeoutUnit' + IntToStr(i) + '.pas';
    SetLength(lModels[i].Declarations, 1);
  end;
  for i := 0 to High(lModels[0].Declarations) do
  begin
    lDeclaration.Name := 'TTimeoutSymbol' + IntToStr(i);
    lModels[0].Declarations[i] := lDeclaration;
    lModels[1].Declarations[i] := lDeclaration;
  end;

  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.ResolveReferenceTargets := False;
  lOptions.WorkerCount := 2;
  lSnapshot := nil;
  lScopedTimeout := nil;
  lScopedStallFile := nil;
  lScopedStallMs := nil;
  try
    lScopedTimeout := TScopedEnvironmentVariable.Create(cSnapshotWorkerJoinTimeoutEnv, '50');
    lScopedStallFile := TScopedEnvironmentVariable.Create(cSnapshotWorkerTestStallFileEnv,
      'TimeoutUnit0.pas');
    lScopedStallMs := TScopedEnvironmentVariable.Create(cSnapshotWorkerTestStallMsEnv,
      '500');
    Assert.AreEqual('50', GetEnvironmentVariable(cSnapshotWorkerJoinTimeoutEnv),
      'Expected the snapshot worker timeout override to be visible to the builder.');
    try
      lSnapshot := BuildProjectSnapshotFromModels(lModels,
        Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
      Assert.Fail('Expected parallel snapshot worker timeout.');
    except
      on E: Exception do
      begin
        Assert.IsTrue(ContainsText(E.Message, 'Snapshot worker join timed out'),
          'Timeout should fail through the bounded worker join diagnostic.');
        Assert.IsTrue(ContainsText(E.Message, 'Snapshot worker'),
          'Timeout should identify the worker.');
        Assert.IsTrue(ContainsText(E.Message, 'TimeoutUnit'),
          'Timeout should identify the source file being processed.');
      end;
    end;
  finally
    lSnapshot.Free;
    lScopedStallMs.Free;
    lScopedStallFile.Free;
    lScopedTimeout.Free;
  end;
end;

procedure TSnapshotTests.SnapshotBuilderResolvesReferenceTargetsWithoutLegacyProjectIndex;
var
  lBuilderSource: string;
  lFunctionEnd: Integer;
  lFunctionSource: string;
  lFunctionStart: Integer;
  lSessionSource: string;
begin
  lBuilderSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', 'src',
    'DelphiSemantics.Snapshot.Builder.pas'])));
  lFunctionStart := Pos('function BuildSnapshotReferenceTargets', lBuilderSource);
  lFunctionEnd := PosEx('procedure AddSnapshotWithStatement', lBuilderSource,
    lFunctionStart);
  Assert.IsTrue((lFunctionStart > 0) and (lFunctionEnd > lFunctionStart),
    'Expected BuildSnapshotReferenceTargets implementation section.');

  lFunctionSource := Copy(lBuilderSource, lFunctionStart,
    lFunctionEnd - lFunctionStart);
  Assert.IsFalse(ContainsText(lFunctionSource, 'TDelphiSemanticProjectSymbolIndexer.Build'),
    'Snapshot reference targets must resolve directly to snapshot-native symbol ids.');
  Assert.IsFalse(ContainsText(lFunctionSource, 'BuildProjectSymbolIndexContext'),
    'Snapshot reference targets must not build a legacy symbol-index context.');
  Assert.IsFalse(ContainsText(lFunctionSource, 'lSymbolRefByLegacyId'),
    'Snapshot reference targets must not remap legacy symbol ids back to snapshot ids.');

  lSessionSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', 'src',
    'DelphiSemantics.ProjectSession.pas'])));
  Assert.IsFalse(ContainsText(lSessionSource, 'TDelphiSemanticProjectSymbolIndexer.Build'),
    'Project-session snapshot cache rebuilds must not use the legacy symbol index.');
  Assert.IsFalse(ContainsText(lSessionSource, 'BuildProjectSymbolIndexContext'),
    'Project-session snapshot cache rebuilds must not build a legacy symbol-index context.');
  Assert.IsFalse(ContainsText(lSessionSource, 'lSymbolRefByLegacyId'),
    'Project-session snapshot cache rebuilds must not remap legacy symbol ids back to snapshot ids.');
end;

procedure TSnapshotTests.SnapshotBuilderUsesBoundedWorkerJoins;
var
  lWorkersSource: string;
  lFunctionEnd: Integer;
  lFunctionSource: string;
  lFunctionStart: Integer;
begin
  lWorkersSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', 'src',
    'DelphiSemantics.Snapshot.Workers.pas'])));
  lFunctionStart := Pos('function BuildSnapshotUnitResults', lWorkersSource);
  lFunctionEnd := PosEx('end.', lWorkersSource,
    lFunctionStart);
  Assert.IsTrue((lFunctionStart > 0) and (lFunctionEnd > lFunctionStart),
    'Expected BuildSnapshotUnitResults implementation section.');

  lFunctionSource := Copy(lWorkersSource, lFunctionStart,
    lFunctionEnd - lFunctionStart);
  Assert.IsFalse(ContainsText(lFunctionSource, '.WaitFor'),
    'Parallel snapshot workers must use bounded joins, not unbounded TThread.WaitFor.');
  Assert.IsTrue(ContainsText(lWorkersSource, 'WaitForSingleObject'),
    'Bounded joins should poll worker handles with an explicit timeout.');
  Assert.IsTrue(ContainsText(lWorkersSource,
    'DELPHI_SEMANTICS_SNAPSHOT_WORKER_JOIN_TIMEOUT_MS'),
    'Timeout must be configurable for deterministic tests and diagnostics.');
  Assert.IsTrue(ContainsText(lWorkersSource, 'RequestCancel'),
    'Timed-out snapshot workers should receive cooperative cancellation.');
  Assert.IsTrue(ContainsText(lWorkersSource, 'Snapshot worker'),
    'Timeout diagnostics should identify the affected worker/source file.');
end;

procedure TSnapshotTests.SnapshotWorkerPipelineLivesBehindFocusedBoundary;
var
  lBuilderSource: string;
  lWorkersPath: string;
  lWorkersSource: string;
begin
  lBuilderSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', 'src',
    'DelphiSemantics.Snapshot.Builder.pas'])));
  lWorkersPath := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
    '..', '..', 'src', 'DelphiSemantics.Snapshot.Workers.pas']));
  Assert.IsTrue(TFile.Exists(lWorkersPath),
    'Expected focused snapshot worker pipeline unit.');

  lWorkersSource := TFile.ReadAllText(lWorkersPath);
  Assert.IsTrue(ContainsText(lBuilderSource, 'DelphiSemantics.Snapshot.Workers'),
    'Snapshot builder should delegate worker orchestration to the worker pipeline.');
  Assert.IsFalse(ContainsText(lBuilderSource, 'TSnapshotBuildWorkerContext = class'),
    'Snapshot builder should not own worker queue state.');
  Assert.IsFalse(ContainsText(lBuilderSource, 'TSnapshotBuildWorkerThread = class'),
    'Snapshot builder should not own worker thread lifecycle.');
  Assert.IsFalse(ContainsText(lBuilderSource, 'WaitForSingleObject'),
    'Snapshot builder should not own bounded worker join policy.');
  Assert.IsTrue(ContainsText(lWorkersSource, 'TSnapshotBuildWorkerContext = class'),
    'Worker pipeline should own worker queue state.');
  Assert.IsTrue(ContainsText(lWorkersSource, 'TSnapshotBuildWorkerThread = class'),
    'Worker pipeline should own worker thread lifecycle.');
  Assert.IsTrue(ContainsText(lWorkersSource, 'WaitForSingleObject'),
    'Worker pipeline should own bounded worker join policy.');
end;

procedure TSnapshotTests.SnapshotReferenceTargetsKeepOverloadedRoutineLocalAmbiguityUnresolved;
var
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSnapshotBuildOptions;
  lReference: TSemanticReferenceFact;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.UnitName := 'SnapshotOverloadUnit';
  lModel.FileName := 'SnapshotOverloadUnit.pas';
  SetLength(lModel.Routines, 2);
  lModel.Routines[0].Name := 'DoWork';
  lModel.Routines[0].Signature := 'DoWork(Integer)';
  lModel.Routines[0].Line := 10;
  lModel.Routines[0].Column := 11;
  lModel.Routines[1].Name := 'DoWork';
  lModel.Routines[1].Signature := 'DoWork(string)';
  lModel.Routines[1].Line := 20;
  lModel.Routines[1].Column := 11;
  SetLength(lModel.Locals, 1);
  lModel.Locals[0].RoutineName := 'DoWork';
  lModel.Locals[0].Name := 'LocalOnlyInOneOverload';
  lModel.Locals[0].Kind := 'local';
  lModel.Locals[0].Line := 12;
  lModel.Locals[0].Column := 5;
  SetLength(lModel.References, 1);
  lModel.References[0].RoutineName := 'DoWork';
  lModel.References[0].Name := 'LocalOnlyInOneOverload';
  lModel.References[0].SectionKind := 'implementation';
  lModel.References[0].Line := 13;
  lModel.References[0].Column := 3;
  lModel.References[0].EndLine := 13;
  lModel.References[0].EndColumn := 24;

  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.ResolveReferenceTargets := True;
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels([lModel], Default(TDelphiSemanticProjectWithBindingFacts),
    lOptions, lMetrics);
  try
    lUnit := lSnapshot.UnitByIndex(0);
    lReference := lUnit.ReferenceById(1);
    Assert.AreEqual(0, Integer(lReference.TargetUnitId),
      'Ambiguous overloaded routine owner must not resolve a local target.');
    Assert.AreEqual(0, Integer(lReference.TargetSymbolId),
      'Ambiguous overloaded routine owner must not resolve a local target.');
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.SnapshotReferenceTargetsUseLineQualifiedRoutineForWeakOwners;
var
  lLocalResolution: TDelphiSemanticSnapshotPositionResolution;
  lMemberResolution: TDelphiSemanticSnapshotPositionResolution;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSnapshotBuildOptions;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceFileName: string;
begin
  lSourceFileName := TPath.GetFullPath('SnapshotWeakRoutineOwnerUnit.pas');
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.UnitName := 'SnapshotWeakRoutineOwnerUnit';
  lModel.FileName := lSourceFileName;

  SetLength(lModel.Declarations, 1);
  lModel.Declarations[0].Name := 'lShadowValue';
  lModel.Declarations[0].Kind := 'var';
  lModel.Declarations[0].SectionKind := 'interface';
  lModel.Declarations[0].Line := 5;
  lModel.Declarations[0].Column := 3;

  SetLength(lModel.Members, 1);
  lModel.Members[0].OwnerName := 'TMemberShadow';
  lModel.Members[0].Name := 'lShadowValue';
  lModel.Members[0].Kind := 'field';
  lModel.Members[0].Line := 10;
  lModel.Members[0].Column := 5;

  SetLength(lModel.Routines, 2);
  lModel.Routines[0].Name := 'Run';
  lModel.Routines[0].OwnerName := 'TLocalShadow';
  lModel.Routines[0].Line := 20;
  lModel.Routines[0].Column := 23;
  lModel.Routines[1].Name := 'Run';
  lModel.Routines[1].OwnerName := 'TMemberShadow';
  lModel.Routines[1].Line := 30;
  lModel.Routines[1].Column := 24;

  SetLength(lModel.Locals, 1);
  lModel.Locals[0].RoutineName := 'TLocalShadow.Run';
  lModel.Locals[0].Name := 'lShadowValue';
  lModel.Locals[0].Kind := 'var';
  lModel.Locals[0].Line := 22;
  lModel.Locals[0].Column := 3;

  SetLength(lModel.References, 2);
  lModel.References[0].RoutineName := 'Run';
  lModel.References[0].Name := 'lShadowValue';
  lModel.References[0].SectionKind := 'implementation';
  lModel.References[0].Line := 24;
  lModel.References[0].Column := 6;
  lModel.References[0].EndLine := 24;
  lModel.References[0].EndColumn := 17;
  lModel.References[1].RoutineName := 'Run';
  lModel.References[1].Name := 'lShadowValue';
  lModel.References[1].SectionKind := 'implementation';
  lModel.References[1].Line := 34;
  lModel.References[1].Column := 3;
  lModel.References[1].EndLine := 34;
  lModel.References[1].EndColumn := 14;

  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.ResolveReferenceTargets := True;
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels([lModel],
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lSourceFileName, 24, 6,
      'lShadowValue', lLocalResolution),
      'Expected weak-routine local reference to resolve through its line-qualified owner.');
    Assert.AreEqual('TLocalShadow.Run', lSnapshot.TextOf(
      lLocalResolution.Symbol.RoutineId));
    Assert.AreEqual('var', lSnapshot.TextOf(lLocalResolution.Symbol.KindId));

    Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lSourceFileName, 34, 3,
      'lShadowValue', lMemberResolution),
      'Expected weak-routine member reference to resolve through its line-qualified owner.');
    Assert.AreEqual('TMemberShadow', lSnapshot.TextOf(
      lMemberResolution.Symbol.OwnerTypeId));
    Assert.AreEqual('field', lSnapshot.TextOf(lMemberResolution.Symbol.KindId));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.SnapshotReferenceTargetsResolveExtractedClassMethodShadows;
var
  lLocalResolution: TDelphiSemanticSnapshotPositionResolution;
  lMemberResolution: TDelphiSemanticSnapshotPositionResolution;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lOptions: TDelphiSnapshotBuildOptions;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.Combine(TPath.GetTempPath,
    TPath.ChangeExtension(TPath.GetRandomFileName, '.pas'));
  lSourceText := 'unit SnapshotExtractedShadowUnit;' + sLineBreak + sLineBreak +
    'interface' + sLineBreak + sLineBreak + 'type' + sLineBreak +
    '  TLocalShadow = class' + sLineBreak + '  public' + sLineBreak +
    '    procedure Run;' + sLineBreak + '  end;' + sLineBreak + sLineBreak +
    '  TMemberShadow = class' + sLineBreak + '  private' + sLineBreak +
    '    lShadowValue: Integer;' + sLineBreak + '  public' + sLineBreak +
    '    procedure Run;' + sLineBreak + '  end;' + sLineBreak + sLineBreak +
    'var' + sLineBreak + '  lShadowValue: Integer;' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak + 'procedure TLocalShadow.Run;' +
    sLineBreak + 'var' + sLineBreak + '  lShadowValue: Integer;' + sLineBreak +
    'begin' + sLineBreak + '  lShadowValue := 1;' + sLineBreak +
    '  if lShadowValue > 0 then' + sLineBreak +
    '    lShadowValue := lShadowValue + 1;' + sLineBreak + 'end;' +
    sLineBreak + sLineBreak + 'procedure TMemberShadow.Run;' + sLineBreak +
    'begin' + sLineBreak + '  lShadowValue := 2;' + sLineBreak + 'end;' +
    sLineBreak + sLineBreak + 'end.';
  TFile.WriteAllText(lSourceFileName, lSourceText, TEncoding.UTF8);

  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lSourceFileName;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
  Assert.IsTrue(lModel.Success, 'Expected fixture model extraction to succeed.');

  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.ResolveReferenceTargets := True;
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels([lModel],
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lSourceFileName, 28, 6,
      'lShadowValue', lLocalResolution),
      'Expected extracted local shadow reference to resolve.');
    Assert.AreEqual('TLocalShadow.Run', lSnapshot.TextOf(
      lLocalResolution.Symbol.RoutineId));
    Assert.AreEqual('var', lSnapshot.TextOf(lLocalResolution.Symbol.KindId));

    Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lSourceFileName, 34, 3,
      'lShadowValue', lMemberResolution),
      'Expected extracted member shadow reference to resolve.');
    Assert.AreEqual('TMemberShadow', lSnapshot.TextOf(
      lMemberResolution.Symbol.OwnerTypeId));
    Assert.AreEqual('field', lSnapshot.TextOf(lMemberResolution.Symbol.KindId));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.SnapshotReferenceTargetsResolveSymbolMapFixtureShadows;
var
  lDummyModel: TDelphiSemanticUnitModel;
  lDummySnapshot: TDelphiProjectSnapshot;
  lLocalResolution: TDelphiSemanticSnapshotPositionResolution;
  lMemberResolution: TDelphiSemanticSnapshotPositionResolution;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceFileName: string;
  lSourceText: string;
  lUnitSnapshot: TDelphiProjectSnapshot;
begin
  lDummySnapshot := nil;
  lSnapshot := nil;
  lUnitSnapshot := nil;
  lSourceFileName := TPath.Combine(TPath.GetTempPath,
    TPath.ChangeExtension(TPath.GetRandomFileName, '.pas'));
  lSourceText := 'unit SymbolMapUnit;' + sLineBreak + sLineBreak + 'interface' +
    sLineBreak + sLineBreak + 'uses' + sLineBreak + '  System.SysUtils,' +
    sLineBreak + '  Winapi.Windows;' + sLineBreak + sLineBreak + 'type' +
    sLineBreak + '  TSymbolMapFixture = class' + sLineBreak + '  public' +
    sLineBreak + '    procedure Run;' + sLineBreak + '  end;' + sLineBreak +
    sLineBreak + '  TSymbolMapFixtureType = TSymbolMapFixture;' + sLineBreak +
    sLineBreak + '  TSymbolMapReferenceHolder = class' + sLineBreak +
    '  private' + sLineBreak + '    FValue: TSymbolMapFixtureType;' +
    sLineBreak + '  public' + sLineBreak +
    '    procedure UseValue(const aValue: TSymbolMapFixtureType);' + sLineBreak +
    '  end;' + sLineBreak + sLineBreak +
    '  TSymbolMapShadowCollision = class' + sLineBreak + '  public' +
    sLineBreak + '    procedure Run;' + sLineBreak + '  end;' + sLineBreak +
    sLineBreak + '  TSymbolMapMemberShadowCollision = class' + sLineBreak +
    '  private' + sLineBreak + '    lShadowValue: Integer;' + sLineBreak +
    '  public' + sLineBreak + '    procedure Run;' + sLineBreak + '  end;' +
    sLineBreak + sLineBreak + '  TSymbolMapOverloadCollision = class' +
    sLineBreak + '  public' + sLineBreak +
    '    procedure Select(const aValue: string); overload;' + sLineBreak +
    '    procedure Select(const aValue: Integer); overload;' + sLineBreak +
    '    procedure Run;' + sLineBreak + '  end;' + sLineBreak + sLineBreak +
    'var' + sLineBreak + '  lShadowValue: Integer;' + sLineBreak + sLineBreak +
    'implementation' + sLineBreak + sLineBreak + 'uses' + sLineBreak +
    '  System.Classes,' + sLineBreak + '  System.Generics.Collections;' +
    sLineBreak + sLineBreak + 'procedure TSymbolMapFixture.Run;' + sLineBreak +
    'begin' + sLineBreak + 'end;' + sLineBreak + sLineBreak +
    'procedure TSymbolMapReferenceHolder.UseValue(const aValue: TSymbolMapFixtureType);' +
    sLineBreak + 'begin' + sLineBreak + '  FValue := aValue;' + sLineBreak +
    '  if Assigned(FValue) then' + sLineBreak + '    FValue.Run;' +
    sLineBreak + 'end;' + sLineBreak + sLineBreak +
    'procedure TSymbolMapShadowCollision.Run;' + sLineBreak + 'var' +
    sLineBreak + '  lShadowValue: Integer;' + sLineBreak + 'begin' +
    sLineBreak + '  lShadowValue := 1;' + sLineBreak +
    '  if lShadowValue > 0 then' + sLineBreak +
    '    lShadowValue := lShadowValue + 1;' + sLineBreak + 'end;' +
    sLineBreak + sLineBreak + 'procedure TSymbolMapMemberShadowCollision.Run;' +
    sLineBreak + 'begin' + sLineBreak + '  lShadowValue := 2;' + sLineBreak +
    'end;' + sLineBreak + sLineBreak +
    'procedure TSymbolMapOverloadCollision.Select(const aValue: string);' +
    sLineBreak + 'begin' + sLineBreak + 'end;' + sLineBreak + sLineBreak +
    'procedure TSymbolMapOverloadCollision.Select(const aValue: Integer);' +
    sLineBreak + 'begin' + sLineBreak + 'end;' + sLineBreak + sLineBreak +
    'procedure TSymbolMapOverloadCollision.Run;' + sLineBreak + 'begin' +
    sLineBreak + '  Select(42);' + sLineBreak + 'end;' + sLineBreak +
    sLineBreak + 'end.';
  TFile.WriteAllText(lSourceFileName, lSourceText, TEncoding.UTF8);

  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lSourceFileName;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lModelOptions);
  Assert.IsTrue(lModel.Success, 'Expected SymbolMap fixture model extraction to succeed.');

  lDummyModel := Default(TDelphiSemanticUnitModel);
  lDummyModel.UnitName := 'SnapshotDummyUnit';
  lDummyModel.FileName := TPath.GetFullPath('SnapshotDummyUnit.pas');
  lModels := [lDummyModel, lModel];
  lDummySnapshot := BuildProjectUnitSnapshotFromModels(lModels, 0, 1, lMetrics);
  try
    lUnitSnapshot := BuildProjectUnitSnapshotFromModels(lModels, 1, 2, lMetrics);
    try
      lSnapshot := BuildProjectSnapshotFromUnitSnapshots([lDummySnapshot,
        lUnitSnapshot], lMetrics);
      try
        Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lSourceFileName, 68, 6,
          'lShadowValue', lLocalResolution),
          'Expected merged SymbolMap local shadow reference to resolve.');
        Assert.AreEqual('TSymbolMapShadowCollision.Run', lSnapshot.TextOf(
          lLocalResolution.Symbol.RoutineId));
        Assert.AreEqual('var', lSnapshot.TextOf(lLocalResolution.Symbol.KindId));

        Assert.IsTrue(TryResolveSnapshotPosition(lSnapshot, lSourceFileName, 74, 3,
          'lShadowValue', lMemberResolution),
          'Expected merged SymbolMap member shadow reference to resolve.');
        Assert.AreEqual('TSymbolMapMemberShadowCollision', lSnapshot.TextOf(
          lMemberResolution.Symbol.OwnerTypeId));
        Assert.AreEqual('field', lSnapshot.TextOf(lMemberResolution.Symbol.KindId));
      finally
        lSnapshot.Free;
      end;
    finally
      lUnitSnapshot.Free;
    end;
  finally
    lDummySnapshot.Free;
  end;
end;

procedure TSnapshotTests.ProjectSnapshotMergePreservesCrossUnitDuplicateTargetReferences;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lMerged: TDelphiProjectSnapshot;
  lMergedReference: TSemanticReferenceFact;
  lMergedSourceUnit: TUnitSnapshot;
  lMergedTargetSymbol: TSemanticSymbolFact;
  lMergedTargetUnit: TUnitSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lReference: TSemanticReferenceFact;
  lSourceSnapshot: TDelphiProjectSnapshot;
  lSourceUnit: TUnitSnapshot;
  lTargetSnapshot: TDelphiProjectSnapshot;
  lTargetSymbol: TSemanticSymbolFact;
  lTargetSymbolId: TSemanticSymbolId;
  lTargetUnit: TUnitSnapshot;
begin
  lMerged := nil;
  lSourceSnapshot := nil;
  lTargetSnapshot := nil;
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lTargetUnit := TUnitSnapshot.Create(2, lBuilder.Strings.Intern('UnitB.pas'),
      lBuilder.Strings.Intern('UnitB'));
    try
      lTargetSymbol := Default(TSemanticSymbolFact);
      lTargetSymbol.NameId := lBuilder.Strings.Intern('SharedTarget');
      lTargetSymbol.KindId := lBuilder.Strings.Intern('routine');
      lTargetSymbol.SectionKindId := lBuilder.Strings.Intern('interface');
      lTargetSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lTargetSymbol.SignatureId := lBuilder.Strings.Intern('(Integer)');
      lTargetSymbol.Line := 5;
      lTargetSymbol.Column := 11;
      lTargetUnit.AddSymbol(lTargetSymbol);

      lTargetSymbol := Default(TSemanticSymbolFact);
      lTargetSymbol.NameId := lBuilder.Strings.Intern('SharedTarget');
      lTargetSymbol.KindId := lBuilder.Strings.Intern('routine');
      lTargetSymbol.SectionKindId := lBuilder.Strings.Intern('interface');
      lTargetSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lTargetSymbol.SignatureId := lBuilder.Strings.Intern('(string)');
      lTargetSymbol.Line := 9;
      lTargetSymbol.Column := 11;
      lTargetSymbolId := lTargetUnit.AddSymbol(lTargetSymbol);

      lBuilder.AddUnit(lTargetUnit);
      lTargetUnit := nil;
    finally
      lTargetUnit.Free;
    end;
    lTargetSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lSourceUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('UnitA.pas'),
      lBuilder.Strings.Intern('UnitA'));
    try
      lReference := Default(TSemanticReferenceFact);
      lReference.NameId := lBuilder.Strings.Intern('SharedTarget');
      lReference.TargetUnitId := 2;
      lReference.TargetSymbolId := lTargetSymbolId;
      lReference.SectionKindId := lBuilder.Strings.Intern('implementation');
      lReference.SourceKindId := lBuilder.Strings.Intern('project-source');
      lReference.Line := 12;
      lReference.Column := 3;
      lReference.EndLine := 12;
      lReference.EndColumn := 14;
      lSourceUnit.AddReference(lReference);

      lBuilder.AddUnit(lSourceUnit);
      lSourceUnit := nil;
    finally
      lSourceUnit.Free;
    end;
    lSourceSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    lMerged := BuildProjectSnapshotFromUnitSnapshots([lSourceSnapshot, lTargetSnapshot],
      lMetrics);

    Assert.IsTrue(lMerged.TryFindUnitById(1, lMergedSourceUnit));
    lMergedReference := lMergedSourceUnit.ReferenceById(1);
    Assert.AreEqual(2, Integer(lMergedReference.TargetUnitId),
      'Expected cross-unit target unit to survive snapshot merge.');
    Assert.AreNotEqual(0, Integer(lMergedReference.TargetSymbolId),
      'Expected cross-unit target symbol to survive snapshot merge.');
    Assert.IsTrue(lMerged.TryFindUnitById(lMergedReference.TargetUnitId,
      lMergedTargetUnit));
    lMergedTargetSymbol := lMergedTargetUnit.SymbolById(lMergedReference.TargetSymbolId);
    Assert.AreEqual(9, lMergedTargetSymbol.Line,
      'Expected exact target symbol remap to avoid name-only ambiguity.');
  finally
    lMerged.Free;
    lSourceSnapshot.Free;
    lTargetSnapshot.Free;
  end;
end;

procedure TSnapshotTests.SnapshotUnitDoesNotUseJsonLiveRepresentation;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lSourceText, 'System.JSON'),
    'Snapshot primitives must not use JSON as the live representation.');
  Assert.IsFalse(ContainsText(lSourceText, 'TJSONObject'),
    'Snapshot primitives must not traverse JSON objects in hot paths.');
  Assert.IsFalse(ContainsText(lSourceText, 'TJSONArray'),
    'Snapshot primitives must not traverse JSON arrays in hot paths.');
end;

procedure TSnapshotTests.StringPoolInternsStableCaseAwareIds;
var
  lOtherId: TSemanticStringId;
  lPool: TSemanticStringPool;
  lTextId: TSemanticStringId;
begin
  lPool := TSemanticStringPool.Create;
  try
    Assert.AreEqual(0, Integer(lPool.Count));
    Assert.AreEqual('', lPool.TextOf(0));

    lTextId := lPool.Intern('TWidget');
    Assert.AreEqual(lTextId, lPool.Intern('twidget'));
    lOtherId := lPool.Intern('TOther');

    Assert.IsTrue(lTextId <> 0, 'Non-empty strings should not use the sentinel ID.');
    Assert.IsTrue(lTextId <> lOtherId, 'Different strings must get different IDs.');
    Assert.AreEqual('TWidget', lPool.TextOf(lTextId));
    Assert.AreEqual('TOther', lPool.TextOf(lOtherId));
    Assert.AreEqual(2, Integer(lPool.Count));
  finally
    lPool.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotAssignsStableDenseFactIds;
var
  lReference: TSemanticReferenceFact;
  lReferenceId: TSemanticReferenceId;
  lSnapshot: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
  lWith: TSemanticWithStatementFact;
  lWithId: TSemanticWithId;
begin
  lSnapshot := TUnitSnapshot.Create(42);
  try
    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := 10;
    lSymbolId := lSnapshot.AddSymbol(lSymbol);

    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 5;
    lWith.BodyEndLine := 7;
    lWithId := lSnapshot.AddWithStatement(lWith);

    lReference := Default(TSemanticReferenceFact);
    lReference.WithId := lWithId;
    lReference.NameId := 20;
    lReferenceId := lSnapshot.AddReference(lReference);

    Assert.AreEqual(1, Integer(lSymbolId));
    Assert.AreEqual(1, Integer(lWithId));
    Assert.AreEqual(1, Integer(lReferenceId));
    Assert.AreEqual(42, Integer(lSnapshot.SymbolById(lSymbolId).UnitId));
    Assert.AreEqual(42, Integer(lSnapshot.WithStatementById(lWithId).UnitId));
    Assert.AreEqual(42, Integer(lSnapshot.ReferenceById(lReferenceId).UnitId));
    Assert.AreEqual(1, lSnapshot.SymbolCount);
    Assert.AreEqual(1, lSnapshot.WithStatementCount);
    Assert.AreEqual(1, lSnapshot.ReferenceCount);
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotFindsWithCandidatesBySourceLine;
var
  i: Integer;
  lFoundFirst: Boolean;
  lFoundSecond: Boolean;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lSnapshot: TUnitSnapshot;
  lWith: TSemanticWithStatementFact;
  lWithFirst: TSemanticWithId;
  lWithSecond: TSemanticWithId;
begin
  lSnapshot := TUnitSnapshot.Create(7);
  try
    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 10;
    lWith.BodyEndLine := 12;
    lWithFirst := lSnapshot.AddWithStatement(lWith);

    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 12;
    lWith.BodyEndLine := 15;
    lWithSecond := lSnapshot.AddWithStatement(lWith);

    Assert.IsTrue(lSnapshot.TryWithStatementsAtLine(12, lLowIndex, lHighIndex));

    lFoundFirst := False;
    lFoundSecond := False;
    for i := lLowIndex to lHighIndex do
    begin
      lFoundFirst := lFoundFirst or (lSnapshot.WithIdBySourceLineIndex(i) = lWithFirst);
      lFoundSecond := lFoundSecond or (lSnapshot.WithIdBySourceLineIndex(i) = lWithSecond);
    end;

    Assert.IsTrue(lFoundFirst, 'Expected the first with statement to be indexed for line 12.');
    Assert.IsTrue(lFoundSecond, 'Expected the second with statement to be indexed for line 12.');
    Assert.IsFalse(lSnapshot.TryWithStatementsAtLine(9, lLowIndex, lHighIndex));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotChoosesInnermostWithCandidateForSourceLine;
var
  lSelectedWithId: TSemanticWithId;
  lSnapshot: TUnitSnapshot;
  lWith: TSemanticWithStatementFact;
  lWithNarrow: TSemanticWithId;
begin
  lSnapshot := TUnitSnapshot.Create(7);
  try
    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 10;
    lWith.BodyEndLine := 12;
    lWithNarrow := lSnapshot.AddWithStatement(lWith);

    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 12;
    lWith.BodyEndLine := 15;
    lSnapshot.AddWithStatement(lWith);

    Assert.IsTrue(lSnapshot.TryFindInnermostWithStatementAtLine(12, lSelectedWithId));
    Assert.AreEqual(Integer(lWithNarrow), Integer(lSelectedWithId));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotReturnsReferencesForWithWithoutReferenceScan;
var
  i: Integer;
  lFoundFirst: Boolean;
  lFoundSecond: Boolean;
  lHighIndex: Integer;
  lLowIndex: Integer;
  lReference: TSemanticReferenceFact;
  lReferenceFirst: TSemanticReferenceId;
  lReferenceSecond: TSemanticReferenceId;
  lSnapshot: TUnitSnapshot;
  lWith: TSemanticWithStatementFact;
  lWithFirst: TSemanticWithId;
  lWithSecond: TSemanticWithId;
begin
  lSnapshot := TUnitSnapshot.Create(7);
  try
    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 1;
    lWith.BodyEndLine := 1;
    lWithFirst := lSnapshot.AddWithStatement(lWith);

    lWith := Default(TSemanticWithStatementFact);
    lWith.BodyStartLine := 2;
    lWith.BodyEndLine := 2;
    lWithSecond := lSnapshot.AddWithStatement(lWith);

    lReference := Default(TSemanticReferenceFact);
    lReference.WithId := lWithSecond;
    lSnapshot.AddReference(lReference);

    lReference.WithId := lWithFirst;
    lReference.NameId := 101;
    lReferenceFirst := lSnapshot.AddReference(lReference);

    lReference.NameId := 102;
    lReferenceSecond := lSnapshot.AddReference(lReference);

    Assert.IsTrue(lSnapshot.TryReferencesForWith(lWithFirst, lLowIndex, lHighIndex));
    Assert.AreEqual(2, lHighIndex - lLowIndex + 1);

    lFoundFirst := False;
    lFoundSecond := False;
    for i := lLowIndex to lHighIndex do
    begin
      lFoundFirst := lFoundFirst or (lSnapshot.ReferenceIdByWithIndex(i) = lReferenceFirst);
      lFoundSecond := lFoundSecond or (lSnapshot.ReferenceIdByWithIndex(i) = lReferenceSecond);
    end;

    Assert.IsTrue(lFoundFirst, 'Expected first matching reference ID in the with-index range.');
    Assert.IsTrue(lFoundSecond, 'Expected second matching reference ID in the with-index range.');
    Assert.IsTrue(lSnapshot.TryReferencesForWith(lWithSecond, lLowIndex, lHighIndex));
    Assert.AreEqual(1, lHighIndex - lLowIndex + 1);
    Assert.IsFalse(lSnapshot.TryReferencesForWith(999, lLowIndex, lHighIndex));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotTests.UnitSnapshotStoresFactsAsRecords;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText, 'TSemanticSymbolFact = record'));
  Assert.IsTrue(ContainsText(lSourceText, 'TSemanticWithStatementFact = record'));
  Assert.IsTrue(ContainsText(lSourceText, 'TSemanticReferenceFact = record'));
  Assert.IsFalse(ContainsText(lSourceText, 'TSemanticSymbolFact = class'));
  Assert.IsFalse(ContainsText(lSourceText, 'TSemanticWithStatementFact = class'));
  Assert.IsFalse(ContainsText(lSourceText, 'TSemanticReferenceFact = class'));
end;

initialization
  TDUnitX.RegisterTestFixture(TSnapshotTests);

end.
