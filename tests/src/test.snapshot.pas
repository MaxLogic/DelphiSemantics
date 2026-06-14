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
    procedure SnapshotReferenceTargetsKeepOverloadedRoutineLocalAmbiguityUnresolved;
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
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.Model, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.WithBinding;

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
    lReference.EndLine := 22;
    lReference.EndColumn := 12;
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
  lHadPreviousTimeout: Boolean;
  lHadPreviousStallFile: Boolean;
  lHadPreviousStallMs: Boolean;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSnapshotBuildOptions;
  lPreviousStallFile: string;
  lPreviousStallMs: string;
  lPreviousTimeout: string;
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
  lPreviousTimeout := GetEnvironmentVariable(cSnapshotWorkerJoinTimeoutEnv);
  lPreviousStallFile := GetEnvironmentVariable(cSnapshotWorkerTestStallFileEnv);
  lPreviousStallMs := GetEnvironmentVariable(cSnapshotWorkerTestStallMsEnv);
  lHadPreviousTimeout := lPreviousTimeout <> '';
  lHadPreviousStallFile := lPreviousStallFile <> '';
  lHadPreviousStallMs := lPreviousStallMs <> '';
  Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerJoinTimeoutEnv),
    PChar('50'));
  Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerTestStallFileEnv),
    PChar('TimeoutUnit0.pas'));
  Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerTestStallMsEnv),
    PChar('500'));
  Assert.AreEqual('50', GetEnvironmentVariable(cSnapshotWorkerJoinTimeoutEnv),
    'Expected the snapshot worker timeout override to be visible to the builder.');
  try
    lSnapshot := nil;
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
    if lHadPreviousTimeout then
      Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerJoinTimeoutEnv),
        PChar(lPreviousTimeout))
    else
      Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerJoinTimeoutEnv),
        nil);
    if lHadPreviousStallFile then
      Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerTestStallFileEnv),
        PChar(lPreviousStallFile))
    else
      Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerTestStallFileEnv),
        nil);
    if lHadPreviousStallMs then
      Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerTestStallMsEnv),
        PChar(lPreviousStallMs))
    else
      Winapi.Windows.SetEnvironmentVariable(PChar(cSnapshotWorkerTestStallMsEnv),
        nil);
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
  lBuilderSource: string;
  lFunctionEnd: Integer;
  lFunctionSource: string;
  lFunctionStart: Integer;
begin
  lBuilderSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([
    ExtractFilePath(ParamStr(0)), '..', '..', 'src',
    'DelphiSemantics.Snapshot.Builder.pas'])));
  lFunctionStart := Pos('function BuildUnitResults', lBuilderSource);
  lFunctionEnd := PosEx('function MergeUnitResults', lBuilderSource,
    lFunctionStart);
  Assert.IsTrue((lFunctionStart > 0) and (lFunctionEnd > lFunctionStart),
    'Expected BuildUnitResults implementation section.');

  lFunctionSource := Copy(lBuilderSource, lFunctionStart,
    lFunctionEnd - lFunctionStart);
  Assert.IsFalse(ContainsText(lFunctionSource, '.WaitFor'),
    'Parallel snapshot workers must use bounded joins, not unbounded TThread.WaitFor.');
  Assert.IsTrue(ContainsText(lBuilderSource, 'WaitForSingleObject'),
    'Bounded joins should poll worker handles with an explicit timeout.');
  Assert.IsTrue(ContainsText(lBuilderSource,
    'DELPHI_SEMANTICS_SNAPSHOT_WORKER_JOIN_TIMEOUT_MS'),
    'Timeout must be configurable for deterministic tests and diagnostics.');
  Assert.IsTrue(ContainsText(lBuilderSource, 'RequestCancel'),
    'Timed-out snapshot workers should receive cooperative cancellation.');
  Assert.IsTrue(ContainsText(lBuilderSource, 'Snapshot worker'),
    'Timeout diagnostics should identify the affected worker/source file.');
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
