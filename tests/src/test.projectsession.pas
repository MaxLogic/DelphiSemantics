unit Test.ProjectSession;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Graph,
  DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TRequestPublicationTests = class
  public
    [Test]
    [TestCase('Facts', 'facts')]
    [TestCase('Plan', 'plan')]
    [TestCase('Combined', 'combined')]
    procedure BindingCallbackDriftRefusesPublication(const aRoute: string);
    [Test]
    procedure OwnerBypassesPersistedWithFacts;
  end;

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
    [TestCase('Referenced refusal', 'reject')]
    [TestCase('Warm snapshot refusal', 'hit-reject')]
    [TestCase('Owner exception', 'raise')]
    [TestCase('Referenced drift', 'drift')]
    [TestCase('Include drift', 'include-drift')]
    [TestCase('Cold accepted', 'accept')]
    [TestCase('Warm accepted', 'hit-accept')]
    procedure RequestOwnerSealsEveryModelBeforePublication(const aMode: string);
    [Test]
    [TestCase('Before guard-only anonymous evidence', '65')]
    [TestCase('Before RTL root evidence', '64')]
    [TestCase('Before alias receiver members', '63')]
    [TestCase('Before receiver-owned value members', '62')]
    [TestCase('Before inactive nested WITH shadow refusal', '61')]
    [TestCase('Before unindexed record helper refusal', '60')]
    [TestCase('Before receiver member scopes', '2')]
    [TestCase('Before compiler body casts', '3')]
    [TestCase('Before pointer cast receivers', '4')]
    [TestCase('Before routine body extents', '5')]
    [TestCase('Before balanced WITH selectors', '6')]
    [TestCase('Round 14 M2 facts generation', '52')]
    [TestCase('Before raw-source inactive reference parity', '54')]

    [TestCase('Before declaration-identity lineage', '59')]
    [TestCase('Before include body containment', '58')]
    [TestCase('Before receiver owner identity and member activity', '57')]
    [TestCase('Before public inactive-only refusal reason', '56')]
    [TestCase('Before separate inactive-span verification', '55')]
    [TestCase('Before known-inactive range restoration', '53')]
    procedure RebuildsRemoveWithFactsWithOlderSchemaMarker(const aVersion: string);
    [Test]
    procedure ProjectSessionOpensFromProjectFileName;
    [Test]
    procedure RebuildsSnapshotBeforeInactiveNestedWithSafety;
    [Test]
    [Category('DS731Generations')]
    procedure RebuildsSnapshotBeforeReceiverValueMembers;
    [Test]
    [Category('DS741Generations')]
    procedure RebuildsSnapshotBeforeAliasReceiverMembers;
    [Test]
    procedure EmptyProjectPathReturnsStructuredSessionDiagnostic;
    [Test]
    procedure OpensProjectSessionThroughExistingProjectContext;
    [Test]
    [TestCase('Accepted actual profile', 'accept')]
    [TestCase('Rejected profile', 'reject')]
    [TestCase('Validator exception', 'raise')]
    procedure RootAbsenceValidatesActualProjectProfile(const aMode: string);
    [TestCase('Defines drift', 'defines')]
    [TestCase('Search path drift', 'paths')]
    procedure RootAbsenceRejectsSameLabelDifferentProfile(const aInput: string);
    [Test]
    procedure ProjectSessionModelExtractionUsesSingleResultRecord;
    [Test]
    procedure IdentifierScopedQueryContractIsAdditiveAndForceFullIsInternal;
    [Test]
    procedure IdentifierCandidateCollectorFindsOnlyCodeTokens;
    [Test]
    procedure IdentifierCandidateCollectorIncludesLocalAndPrivateDeclarations;
    [Test]
    procedure IdentifierCandidateCollectorSupportsWindows1252;
    [Test]
    procedure IdentifierCandidateCollectorIncludesTransitiveAndSharedOwners;
    [Test]
    procedure IdentifierCandidateCollectorHandlesAliasesAndAmbiguity;
    [Test]
    procedure IdentifierCandidateCollectorFailsOpenForUnsafeInputs;
    [Test]
    procedure IdentifierScopedSessionMatchesForcedFullRename;
    [Test]
    procedure InlineSectionRenameProducesThreeEdits;
    [Test]
    [Category('RefactoringLightReuse')]
    procedure IdentifierScopedRenameMatchesColdWarmAndInvalidatedCache;
    [Test]
    [Category('RefactoringLightReuse')]
    [TestCase('No persistent cache', 'False')]
    [TestCase('SQLite cache', 'True')]
    procedure TenAlternativePlansReuseOwnedContext(const aPersistent: Boolean);
    [Test]
    [Category('RefactoringLightReuse')]
    procedure ChangedCompilerContextInvalidatesSnapshotCache;
    [Test]
    procedure ProjectSessionSnapshotIdentityReusesUnitCacheIdentityRecord;
    [Test]
    procedure ProjectSessionGlobalAnalysisUsesSnapshotAuthority;
    [Test]
    procedure ProjectSessionGlobalAnalysisReportsSnapshotCacheMetrics;
    [Test]
    procedure ProjectSessionGlobalAnalysisHonorsWritableTypedConstants;
    [Test]
    procedure ProjectSessionDependencyGraphCollectsRecursiveProjectFacts;
    [Test]
    procedure ProjectSessionDependencyGraphUsesLinux64TargetDefines;
    [Test]
    procedure ProjectSessionBuildsSnapshotFromExtractedModels;
    [Test]
    procedure ProjectSessionBuildsOwnedSnapshotQueryContext;
    [Test]
    procedure TypedConstantsRemainQueryableAcrossSnapshotCacheModes;
    [Test]
    procedure ProjectSessionSnapshotParityComparesSemanticFacts;
    [Test]
    procedure ProjectSessionParallelSnapshotBuildMatchesSequentialFacts;
    [Test]
    procedure ProjectSessionParallelRemoveWithPlanMatchesSequentialCounts;
    [Test]
    procedure CombinedRemoveWithApiExposesOneSessionContract;
    [Test]
    procedure ProjectSessionOperationResultsKeepMetricsStableAcrossLaterOperations;
    [Test]
    procedure ProjectSessionBuildWithBindingFactsDoesNotBuildDiscardedSnapshot;
    [Test]
    [TestCase('indexed-named-tag', 'indexed-named-tag')]
    [TestCase('strong-alias-qualified-target', 'strong-alias-qualified-target')]
    [TestCase('indexed-inline-cross-unit', 'indexed-inline-cross-unit')]
    [TestCase('num-rec', 'num-rec')]
    [Category('DS731SessionPersistence')]
    procedure ValueMembersSessionColdWarm(const aShape: string);
    [Test]
    procedure ProjectSessionPlanRemoveWithCachesProjectFactsByProjectIdentity;
    [Test]
    procedure ProjectSessionPlanRemoveWithInvalidatesLegacyParentSelectorFacts;
    [Test]
    procedure ProjectSessionPlanRemoveWithInvalidatesLegacySimpleInheritedChildFacts;
    [Test]
    procedure ProjectSessionPlanRemoveWithInvalidatesLegacyReceiverSafetyFacts;
    [Test]
    procedure ProjectSessionPlanRemoveWithInvalidatesPreCorrectionV29ReceiverSafetyFacts;
    [Test]
    procedure ProjectSessionPlanRemoveWithInvalidatesPreIntrinsicV30Facts;
    [Test]
    procedure ProjectSessionPlanRemoveWithInvalidatesPreArrayAliasV32Facts;
    [Test]
    procedure ProjectSessionPlanRemoveWithInvalidatesPreQualifiedV31Facts;
    [Test]
    procedure ProjectSessionPreservesInheritedAccessIdentityColdAndWarm;
    [Test]
    procedure ProjectSessionInheritedAccessWithRootProofPlans;
    [Test]
    procedure ProjectSessionInheritedAccessWithoutRootProofRefuses;
    [Test]
    procedure ProjectSessionSnapshotMetricsExposeCacheUsefulnessTelemetry;
    [Test]
    procedure ProjectSessionReusesUnchangedMultiUnitSnapshotCacheEntries;
    [Test]
    procedure ProjectSessionPartialSnapshotCacheFullyAnalyzesOnlyMissedUnits;
    [Test]
    procedure ProjectSessionSnapshotCacheReusesPathVariantProjectIdentity;
    [Test]
    procedure ProjectSessionSnapshotCacheReusesTimestampOnlyChangedSource;
    [Test]
    procedure ProjectSessionScopedPartialSnapshotCacheHitStoresMissedUnitUnderScopedIdentity;
    [Test]
    procedure ProjectSessionPartialSnapshotCacheRebuildResolvesReferencesToCachedUnits;
    [Test]
    procedure ProjectSessionPartialSnapshotCacheRebuildPreservesCrossMissReferences;
    [Test]
    procedure ProjectSessionPartialSnapshotCacheInvalidationMatchesFullRebuildFacts;
    [Test]
    procedure ProjectSessionDiscoversAnsiDprInReferencesThroughSourceLoader;
    [Test]
    [Category('RefactoringLightReuse')]
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
  System.Classes, System.Hash, System.IOUtils, System.JSON.Serializers, System.StrUtils,
  System.SysUtils,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite,
  maxLogic.IOUtils,
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith.Compatibility, DelphiSemantics.Cache,
  DelphiSemantics.Cache.Sqlite,
  DelphiSemantics.GlobalVars, DelphiSemantics.IdentifierScope, DelphiSemantics.Index,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession,
  DelphiSemantics.Query, DelphiSemantics.Refactor, DelphiSemantics.RootMemberAbsence, DelphiSemantics.Snapshot.Cache.Sqlite,
  DelphiSemantics.Snapshot.RemoveWith,
  DelphiSemantics.WithBinding,
  Test.Support;

var
  GProjectSessionTempRoot: string;

function ProjectSessionTempRoot: string;
begin
  if GProjectSessionTempRoot = '' then
  begin
    GProjectSessionTempRoot := CreateTestTempRoot('project-session-temp');
  end;
  TDirectory.CreateDirectory(GProjectSessionTempRoot);
  Result := GProjectSessionTempRoot;
end;

function ProjectSessionTempPath(const aName: string): string;
begin
  Result := TPath.Combine(ProjectSessionTempRoot, aName);
end;

type
  TIdentifierScopePlanResult = record
    Plan: TDelphiSemanticRenamePlan;
    ScopeMetrics: TDelphiSemanticIdentifierScopeMetrics;
  end;

function CreateIdentifierScopeProject(const aRoot: string): string;
var
  lConsumerFileName: string;
  lDprFileName: string;
  lNoiseFileName: string;
  lProviderFileName: string;
begin
  TDirectory.CreateDirectory(aRoot);
  lDprFileName := TPath.Combine(aRoot, 'IdentifierScopeProject.dpr');
  Result := TPath.Combine(aRoot, 'IdentifierScopeProject.dproj');
  lProviderFileName := TPath.Combine(aRoot, 'IdentifierScopeProvider.pas');
  lConsumerFileName := TPath.Combine(aRoot, 'IdentifierScopeConsumer.pas');
  lNoiseFileName := TPath.Combine(aRoot, 'IdentifierScopeNoise.pas');
  TFile.WriteAllText(lDprFileName, 'program IdentifierScopeProject;' +
    sLineBreak + 'uses IdentifierScopeProvider, IdentifierScopeConsumer,' +
    ' IdentifierScopeNoise;' + sLineBreak + 'begin' + sLineBreak + 'end.',
    TEncoding.UTF8);
  TFile.WriteAllText(Result, '<Project>' + sLineBreak +
    '  <PropertyGroup><MainSource>IdentifierScopeProject.dpr</MainSource>' +
    '</PropertyGroup>' + sLineBreak + '  <ItemGroup>' + sLineBreak +
    '    <DCCReference Include="IdentifierScopeProvider.pas"/>' + sLineBreak +
    '    <DCCReference Include="IdentifierScopeConsumer.pas"/>' + sLineBreak +
    '    <DCCReference Include="IdentifierScopeNoise.pas"/>' + sLineBreak +
    '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lProviderFileName, 'unit IdentifierScopeProvider;' +
    sLineBreak + 'interface' + sLineBreak + 'var' + sLineBreak +
    '  ScopeTarget: Integer;' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lConsumerFileName, 'unit IdentifierScopeConsumer;' +
    sLineBreak + 'interface' + sLineBreak + 'uses IdentifierScopeProvider;' +
    sLineBreak + 'procedure TouchTarget;' + sLineBreak + 'implementation' +
    sLineBreak + 'procedure TouchTarget;' + sLineBreak + 'begin' + sLineBreak +
    '  ScopeTarget := ScopeTarget + 1;' + sLineBreak + 'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lNoiseFileName, 'unit IdentifierScopeNoise;' + sLineBreak +
    'interface' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);
end;

function BuildIdentifierScopePlan(const aOptions: TDelphiSemanticOptions):
  TIdentifierScopePlanResult;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lSessionResult: TDelphiSemanticProjectSessionResult;
begin
  lSessionResult := TDelphiSemanticProjectSession.Open(aOptions);
  try
    Assert.IsTrue(lSessionResult.Success);
    lContext := lSessionResult.Session.
      BuildSnapshotSymbolQueryContextForIdentifier('ScopeTarget', lCacheMetrics,
      lExtractionMilliseconds, Result.ScopeMetrics);
    Result.Plan := TDelphiSemanticRenamePlanner.PlanRename(lContext,
      'ScopeTarget', 'RenamedScopeTarget');
  finally
    lSessionResult.Session.Free;
  end;
end;

procedure AssertRenamePlansEqual(const aExpected,
  aActual: TDelphiSemanticRenamePlan);
var
  i: Integer;
begin
  Assert.AreEqual(aExpected.Status, aActual.Status);
  Assert.AreEqual(aExpected.Diagnostic, aActual.Diagnostic);
  Assert.AreEqual(aExpected.ContextFingerprint, aActual.ContextFingerprint);
  Assert.AreEqual(Integer(Length(aExpected.Edits)),
    Integer(Length(aActual.Edits)));
  for i := 0 to High(aExpected.Edits) do
  begin
    Assert.AreEqual(aExpected.Edits[i].FileName, aActual.Edits[i].FileName);
    Assert.AreEqual(aExpected.Edits[i].Role, aActual.Edits[i].Role);
    Assert.AreEqual(aExpected.Edits[i].ExpectedFileHash,
      aActual.Edits[i].ExpectedFileHash);
    Assert.AreEqual(aExpected.Edits[i].ExpectedSourceText,
      aActual.Edits[i].ExpectedSourceText);
    Assert.AreEqual(aExpected.Edits[i].StartLine, aActual.Edits[i].StartLine);
    Assert.AreEqual(aExpected.Edits[i].StartColumn,
      aActual.Edits[i].StartColumn);
    Assert.AreEqual(aExpected.Edits[i].EndLine, aActual.Edits[i].EndLine);
    Assert.AreEqual(aExpected.Edits[i].EndColumn, aActual.Edits[i].EndColumn);
    Assert.AreEqual(aExpected.Edits[i].NewText, aActual.Edits[i].NewText);
  end;
end;

function BuildSnapshotWithMetrics(const aSession: TDelphiSemanticProjectSession;
  out aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TDelphiProjectSnapshot; overload;
var
  lResult: TDelphiSemanticProjectSnapshotBuildResult;
begin
  lResult := aSession.BuildSnapshotResult;
  aMetrics := lResult.Metrics;
  Result := lResult.Snapshot;
  lResult.Snapshot := nil;
end;

function BuildSnapshotWithMetrics(const aSession: TDelphiSemanticProjectSession;
  const aScopedSourceFileNames: TArray<string>;
  out aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TDelphiProjectSnapshot; overload;
var
  lResult: TDelphiSemanticProjectSnapshotBuildResult;
begin
  lResult := aSession.BuildSnapshotResult(aScopedSourceFileNames);
  aMetrics := lResult.Metrics;
  Result := lResult.Snapshot;
  lResult.Snapshot := nil;
end;

function PlanRemoveWithWithMetrics(const aSession: TDelphiSemanticProjectSession;
  out aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TDelphiSemanticRemoveWithPlan;
var
  lResult: TDelphiSemanticRemoveWithPlanBuildResult;
begin
  lResult := aSession.PlanRemoveWithResult;
  aMetrics := lResult.SnapshotMetrics;
  Result := lResult.Plan;
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

function ReadProjectRemoveWithFactsIdentity(const aCacheFileName: string):
  TDelphiSemanticSnapshotCacheIdentity;
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lQuery: TFDQuery;
begin
  Result := Default(TDelphiSemanticSnapshotCacheIdentity);
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  lQuery := TFDQuery.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Connected := True;
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := 'select cache_key, identity_key, source_file_name, file_hash, ' +
      'context_hash, include_graph_hash, schema_version from ' +
      'snapshot_project_remove_with_facts';
    lQuery.Open;
    Assert.IsFalse(lQuery.Eof, 'Expected a persisted project remove-with facts row.');
    Result.CacheKey := lQuery.FieldByName('cache_key').AsWideString;
    Result.IdentityKey := lQuery.FieldByName('identity_key').AsWideString;
    Result.SourceFileName := lQuery.FieldByName('source_file_name').AsWideString;
    Result.FileHash := lQuery.FieldByName('file_hash').AsWideString;
    Result.ContextHash := lQuery.FieldByName('context_hash').AsWideString;
    Result.IncludeGraphHash := lQuery.FieldByName('include_graph_hash').AsWideString;
    Result.SchemaVersion := lQuery.FieldByName('schema_version').AsWideString;
    lQuery.Next;
    Assert.IsTrue(lQuery.Eof, 'Expected exactly one project remove-with facts row.');
  finally
    lQuery.Free;
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure SeedLegacyParentSelectorFacts(const aCacheFileName: string;
  const aCurrentIdentity, aLegacyIdentity: TDelphiSemanticSnapshotCacheIdentity);
const
  cProjectFactTables: array[0..8] of string = (
    'snapshot_exact_strings', 'snapshot_remove_with_facts',
    'snapshot_remove_with_visibility', 'snapshot_remove_with_visible_units',
    'snapshot_remove_with_routine_owners', 'snapshot_remove_with_symbols',
    'snapshot_remove_with_bindings', 'snapshot_remove_with_binding_selectors',
    'snapshot_remove_with_binding_references');
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lMissingBindingIndex: Integer;
  lMissingReasonId: Integer;
  lMissingStatusId: Integer;
  lMissingTypeId: Integer;
  lQuery: TFDQuery;
  lRunNestedBindingIndex: Integer;
  lTableName: string;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  lQuery := TFDQuery.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Connected := True;
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := 'select b.binding_index, s.status_id, s.reason_code_id, ' +
      's.type_name_id from snapshot_remove_with_bindings b ' +
      'join snapshot_exact_strings r on r.cache_key = b.cache_key and ' +
      'r.string_id = b.routine_name_id ' +
      'join snapshot_remove_with_binding_selectors s on ' +
      's.cache_key = b.cache_key and s.binding_index = b.binding_index and ' +
      's.selector_index = 1 where b.cache_key = :cache_key and ' +
      'r.text_value = :routine';
    lQuery.ParamByName('cache_key').AsWideString := aCurrentIdentity.CacheKey;
    lQuery.ParamByName('routine').AsWideString := 'RunUnresolved';
    lQuery.Open;
    Assert.IsFalse(lQuery.Eof, 'Expected unresolved control selector.');
    lMissingBindingIndex := lQuery.FieldByName('binding_index').AsInteger;
    lMissingStatusId := lQuery.FieldByName('status_id').AsInteger;
    lMissingReasonId := lQuery.FieldByName('reason_code_id').AsInteger;
    lMissingTypeId := lQuery.FieldByName('type_name_id').AsInteger;
    lQuery.Next;
    Assert.IsTrue(lQuery.Eof, 'Expected one unresolved control selector.');
    lQuery.Close;
    lQuery.ParamByName('routine').AsWideString := 'RunNested';
    lQuery.Open;
    Assert.IsFalse(lQuery.Eof, 'Expected nested parent selector.');
    lRunNestedBindingIndex := lQuery.FieldByName('binding_index').AsInteger;
    lQuery.Next;
    Assert.IsTrue(lQuery.Eof, 'Expected one nested parent selector.');
    lQuery.Close;
    Assert.AreNotEqual(lMissingBindingIndex, lRunNestedBindingIndex);

    lConnection.StartTransaction;
    try
      if aCurrentIdentity.CacheKey <> aLegacyIdentity.CacheKey then
      begin
        for lTableName in cProjectFactTables do
          lConnection.ExecSQL('update ' + lTableName + ' set cache_key = ' +
            QuotedStr(aLegacyIdentity.CacheKey) + ' where cache_key = ' +
            QuotedStr(aCurrentIdentity.CacheKey));
        lConnection.ExecSQL('update snapshot_project_remove_with_facts set ' +
          'cache_key = ' + QuotedStr(aLegacyIdentity.CacheKey) +
          ', schema_version = ' + QuotedStr(aLegacyIdentity.SchemaVersion) +
          ' where cache_key = ' + QuotedStr(aCurrentIdentity.CacheKey));
      end;
      lConnection.ExecSQL('update snapshot_remove_with_binding_selectors set ' +
        'status_id = ' + IntToStr(lMissingStatusId) + ', reason_code_id = ' +
        IntToStr(lMissingReasonId) + ', type_name_id = ' +
        IntToStr(lMissingTypeId) + ' where cache_key = ' +
        QuotedStr(aLegacyIdentity.CacheKey) + ' and binding_index = ' +
        IntToStr(lRunNestedBindingIndex) + ' and selector_index = 1');
      lConnection.Commit;
    except
      if lConnection.InTransaction then
        lConnection.Rollback;
      raise;
    end;
  finally
    lQuery.Free;
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure SeedLegacySimpleInheritedChildFacts(const aCacheFileName: string;
  const aCurrentIdentity, aLegacyIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aUnitFileName: string; const aRunALine, aRunAColumn,
  aUnknownLine, aUnknownColumn: Integer);
const
  cProjectFactTables: array[0..10] of string = (
    'snapshot_remove_with_value_evidence',
    'snapshot_exact_strings', 'snapshot_remove_with_facts',
    'snapshot_remove_with_visibility', 'snapshot_remove_with_visible_units',
    'snapshot_remove_with_routine_owners', 'snapshot_remove_with_symbols',
    'snapshot_remove_with_bindings', 'snapshot_remove_with_binding_selectors',
    'snapshot_remove_with_binding_references', 'snapshot_remove_with_type_identities');
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lQuery: TFDQuery;
  lRunABindingIndex: Integer;
  lRunAIdentityCount: Integer;
  lTableName: string;
  lUnknownBindingIndex: Integer;
  lUnknownReasonId: Integer;
  lUnknownStatusId: Integer;
  lUnknownTypeId: Integer;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  lQuery := TFDQuery.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Connected := True;
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := 'select b.binding_index, s.status_id, ' +
      's.reason_code_id, s.type_name_id from snapshot_remove_with_bindings b ' +
      'join snapshot_exact_strings f on f.cache_key = b.cache_key and ' +
      'f.string_id = b.file_name_id ' +
      'join snapshot_exact_strings u on u.cache_key = b.cache_key and ' +
      'u.string_id = b.unit_name_id ' +
      'join snapshot_exact_strings r on r.cache_key = b.cache_key and ' +
      'r.string_id = b.routine_name_id ' +
      'join snapshot_exact_strings t on t.cache_key = b.cache_key and ' +
      't.string_id = b.selector_text_id ' +
      'join snapshot_remove_with_binding_selectors s on ' +
      's.cache_key = b.cache_key and s.binding_index = b.binding_index and ' +
      's.selector_index = 1 where b.cache_key = :cache_key and ' +
      'f.text_value = :file_name and u.text_value = ''AUnit'' and ' +
      'r.text_value = :routine and t.text_value = ''Child'' and ' +
      'b.line = :line and b.column = :column';
    lQuery.ParamByName('cache_key').AsWideString := aCurrentIdentity.CacheKey;
    lQuery.ParamByName('file_name').AsWideString := aUnitFileName;
    lQuery.ParamByName('routine').AsWideString := 'RunA';
    lQuery.ParamByName('line').AsInteger := aRunALine;
    lQuery.ParamByName('column').AsInteger := aRunAColumn;
    lQuery.Open;
    Assert.IsFalse(lQuery.Eof, 'Expected exact RunA.Child source binding.');
    lRunABindingIndex := lQuery.FieldByName('binding_index').AsInteger;
    lQuery.Next;
    Assert.IsTrue(lQuery.Eof, 'Expected one exact RunA.Child source binding.');
    lQuery.Close;
    lQuery.ParamByName('routine').AsWideString := 'RunUnknown';
    lQuery.ParamByName('line').AsInteger := aUnknownLine;
    lQuery.ParamByName('column').AsInteger := aUnknownColumn;
    lQuery.Open;
    Assert.IsFalse(lQuery.Eof, 'Expected exact RunUnknown.Child control binding.');
    lUnknownBindingIndex := lQuery.FieldByName('binding_index').AsInteger;
    lUnknownStatusId := lQuery.FieldByName('status_id').AsInteger;
    lUnknownReasonId := lQuery.FieldByName('reason_code_id').AsInteger;
    lUnknownTypeId := lQuery.FieldByName('type_name_id').AsInteger;
    lQuery.Next;
    Assert.IsTrue(lQuery.Eof, 'Expected one exact RunUnknown.Child control binding.');
    lQuery.Close;
    Assert.AreNotEqual(lRunABindingIndex, lUnknownBindingIndex);
    lQuery.SQL.Text := 'select count(*) as identity_count from ' +
      'snapshot_remove_with_type_identities where cache_key = :cache_key and ' +
      'entity_kind = ''selector'' and item_index = :binding_index and sub_index = 1';
    lQuery.ParamByName('cache_key').AsWideString := aCurrentIdentity.CacheKey;
    lQuery.ParamByName('binding_index').AsInteger := lRunABindingIndex;
    lQuery.Open;
    lRunAIdentityCount := lQuery.FieldByName('identity_count').AsInteger;
    lQuery.Close;
    Assert.AreEqual(1, lRunAIdentityCount, 'Resolved RunA.Child must own one identity.');
    lQuery.ParamByName('binding_index').AsInteger := lUnknownBindingIndex;
    lQuery.Open;
    Assert.AreEqual(0, lQuery.FieldByName('identity_count').AsInteger,
      'Unknown Child must have no persisted selector identity.');
    lQuery.Close;

    lConnection.StartTransaction;
    try
      for lTableName in cProjectFactTables do
        lConnection.ExecSQL('update ' + lTableName + ' set cache_key = ' +
          QuotedStr(aLegacyIdentity.CacheKey) + ' where cache_key = ' +
          QuotedStr(aCurrentIdentity.CacheKey));
      lConnection.ExecSQL('update snapshot_project_remove_with_facts set ' +
        'cache_key = ' + QuotedStr(aLegacyIdentity.CacheKey) +
        ', schema_version = ' + QuotedStr(aLegacyIdentity.SchemaVersion) +
        ' where cache_key = ' + QuotedStr(aCurrentIdentity.CacheKey));
      lConnection.ExecSQL('update snapshot_remove_with_binding_selectors set ' +
        'status_id = ' + IntToStr(lUnknownStatusId) + ', reason_code_id = ' +
        IntToStr(lUnknownReasonId) + ', type_name_id = ' +
        IntToStr(lUnknownTypeId) + ' where cache_key = ' +
        QuotedStr(aLegacyIdentity.CacheKey) + ' and binding_index = ' +
        IntToStr(lRunABindingIndex) + ' and selector_index = 1');
      lConnection.ExecSQL('delete from snapshot_remove_with_type_identities ' +
        'where cache_key = ' + QuotedStr(aLegacyIdentity.CacheKey) +
        ' and entity_kind = ''selector'' and item_index = ' +
        IntToStr(lRunABindingIndex) + ' and sub_index = 1');
      lConnection.ExecSQL('update snapshot_remove_with_facts set ' +
        'type_identity_count = type_identity_count - 1 where cache_key = ' +
        QuotedStr(aLegacyIdentity.CacheKey));
      lConnection.ExecSQL('update snapshot_remove_with_bindings set ' +
        'status_id = (select status_id from snapshot_remove_with_bindings ' +
        'where cache_key = ' + QuotedStr(aLegacyIdentity.CacheKey) +
        ' and binding_index = ' + IntToStr(lUnknownBindingIndex) + '), ' +
        'skip_reason_id = (select skip_reason_id from ' +
        'snapshot_remove_with_bindings where cache_key = ' +
        QuotedStr(aLegacyIdentity.CacheKey) + ' and binding_index = ' +
        IntToStr(lUnknownBindingIndex) + ') where cache_key = ' +
        QuotedStr(aLegacyIdentity.CacheKey) + ' and binding_index = ' +
        IntToStr(lRunABindingIndex));
      lConnection.Commit;
    except
      if lConnection.InTransaction then
        lConnection.Rollback;
      raise;
    end;
  finally
    lQuery.Free;
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure SeedLegacyReceiverSafetyFacts(const aCacheFileName: string;
  const aCurrentIdentity, aLegacyIdentity: TDelphiSemanticSnapshotCacheIdentity);
const
  cProjectFactTables: array[0..8] of string = (
    'snapshot_exact_strings', 'snapshot_remove_with_facts',
    'snapshot_remove_with_visibility', 'snapshot_remove_with_visible_units',
    'snapshot_remove_with_routine_owners', 'snapshot_remove_with_symbols',
    'snapshot_remove_with_bindings', 'snapshot_remove_with_binding_selectors',
    'snapshot_remove_with_binding_references');
var
  lBindingIndex: Integer;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lQuery: TFDQuery;
  lReasonId: Integer;
  lTableName: string;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  lQuery := TFDQuery.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Connected := True;
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := 'select b.binding_index from snapshot_remove_with_bindings b ' +
      'join snapshot_exact_strings r on r.cache_key = b.cache_key and ' +
      'r.string_id = b.routine_name_id join snapshot_exact_strings s on ' +
      's.cache_key = b.cache_key and s.string_id = b.selector_text_id ' +
      'where b.cache_key = :cache_key and r.text_value = :routine and ' +
      's.text_value = :selector';
    lQuery.ParamByName('cache_key').AsWideString := aCurrentIdentity.CacheKey;
    lQuery.ParamByName('routine').AsWideString := 'Run';
    lQuery.ParamByName('selector').AsWideString := 'Item^';
    lQuery.Open;
    Assert.IsFalse(lQuery.Eof, 'Expected the nested hidden receiver binding.');
    lBindingIndex := lQuery.FieldByName('binding_index').AsInteger;
    lQuery.Next;
    Assert.IsTrue(lQuery.Eof, 'Expected exactly one hidden receiver binding.');
    lQuery.Close;

    lQuery.SQL.Text := 'select coalesce(max(string_id), 0) + 1 as next_id ' +
      'from snapshot_exact_strings where cache_key = :cache_key';
    lQuery.ParamByName('cache_key').AsWideString := aCurrentIdentity.CacheKey;
    lQuery.Open;
    lReasonId := lQuery.FieldByName('next_id').AsInteger;
    lQuery.Close;

    lConnection.StartTransaction;
    try
      for lTableName in cProjectFactTables do
        lConnection.ExecSQL('update ' + lTableName + ' set cache_key = ' +
          QuotedStr(aLegacyIdentity.CacheKey) + ' where cache_key = ' +
          QuotedStr(aCurrentIdentity.CacheKey));
      lConnection.ExecSQL('update snapshot_project_remove_with_facts set ' +
        'cache_key = ' + QuotedStr(aLegacyIdentity.CacheKey) +
        ', schema_version = ' + QuotedStr(aLegacyIdentity.SchemaVersion) +
        ' where cache_key = ' + QuotedStr(aCurrentIdentity.CacheKey));
      lConnection.ExecSQL('insert into snapshot_exact_strings ' +
        '(cache_key, string_id, text_value) values (' +
        QuotedStr(aLegacyIdentity.CacheKey) + ', ' + IntToStr(lReasonId) +
        ', ''MEMBERS_INCOMPLETE'')');
      lConnection.ExecSQL('update snapshot_remove_with_bindings set ' +
        'skip_reason_id = ' + IntToStr(lReasonId) + ' where cache_key = ' +
        QuotedStr(aLegacyIdentity.CacheKey) + ' and binding_index = ' +
        IntToStr(lBindingIndex));
      lConnection.Commit;
    except
      if lConnection.InTransaction then
        lConnection.Rollback;
      raise;
    end;
  finally
    lQuery.Free;
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

procedure TProjectSessionTests.IdentifierScopedQueryContractIsAdditiveAndForceFullIsInternal;
var
  lContextSource: string;
  lSessionSource: string;
begin
  lContextSource := ReadRepoSource('src\DelphiSemantics.ProjectContext.pas');
  lSessionSource := ReadRepoSource('src\DelphiSemantics.ProjectSession.pas');

  Assert.IsTrue(ContainsText(lContextSource,
    'ForceFullIdentifierAnalysis: Boolean'),
    'The internal session option must make scoped/full parity testable.');
  Assert.IsTrue(ContainsText(lSessionSource,
    'TDelphiSemanticIdentifierScopeMetrics = record'),
    'Identifier scoping must expose additive performance metrics.');
  Assert.IsTrue(ContainsText(lSessionSource,
    'BuildSnapshotSymbolQueryContextForIdentifier'),
    'Name targets need an additive scoped-query session entry point.');
  Assert.IsTrue(ContainsText(lSessionSource,
    'TDelphiSemanticIdentifierCandidateCollector.Collect'),
    'The session must delegate candidate semantics to the collector.');
  Assert.IsTrue(ContainsText(lSessionSource,
    'BuildSnapshotResult(lScope.SourceFileNames)'),
    'The scoped query must reuse the existing full-plus-lean snapshot path.');
end;

procedure TProjectSessionTests.IdentifierCandidateCollectorFindsOnlyCodeTokens;
var
  lCandidateFileName: string;
  lNoiseFileName: string;
  lOtherFileName: string;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticIdentifierScopeResult;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('identifier-code-tokens');
  TDirectory.CreateDirectory(lRoot);
  lCandidateFileName := TPath.Combine(lRoot, 'CandidateUnit.pas');
  lNoiseFileName := TPath.Combine(lRoot, 'NoiseUnit.pas');
  lOtherFileName := TPath.Combine(lRoot, 'OtherUnit.pas');
  TFile.WriteAllText(lCandidateFileName, 'unit CandidateUnit;' + sLineBreak +
    'interface' + sLineBreak + 'const tArGeTnAmE = 1;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lNoiseFileName, 'unit NoiseUnit;' + sLineBreak +
    'interface' + sLineBreak + 'const TargetNameSuffix = 1;' + sLineBreak +
    '  TextValue = ''TargetName''; // TargetName' + sLineBreak +
    '{ TargetName } (* TargetName *)' + sLineBreak + 'implementation' +
    sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lOtherFileName, 'unit OtherUnit;' + sLineBreak +
    'interface' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectDirectory := lRoot;
  lProject.SourceFileNames := TArray<string>.Create(lCandidateFileName,
    lNoiseFileName, lOtherFileName);
  lProject.SearchPaths := TArray<string>.Create(lRoot);

  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'TargetName');

  Assert.IsTrue(lResult.UseScopedAnalysis);
  Assert.IsFalse(lResult.FailOpen);
  Assert.AreEqual(1, lResult.FullModelCount);
  Assert.AreEqual(2, lResult.LeanModelCount);
  Assert.AreEqual(1, Integer(Length(lResult.SourceFileNames)));
  Assert.AreEqual(lCandidateFileName, lResult.SourceFileNames[0]);
end;

procedure TProjectSessionTests.
  IdentifierCandidateCollectorIncludesLocalAndPrivateDeclarations;
var
  lFileName: string;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticIdentifierScopeResult;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('identifier-local-private');
  TDirectory.CreateDirectory(lRoot);
  lFileName := TPath.Combine(lRoot, 'LocalPrivateUnit.pas');
  TFile.WriteAllText(lFileName, 'unit LocalPrivateUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type TScopedType = class' + sLineBreak +
    'private' + sLineBreak + '  fPrivateTarget: Integer;' + sLineBreak +
    'end;' + sLineBreak + 'procedure TouchTarget;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure TouchTarget;' + sLineBreak +
    'var' + sLineBreak + '  lLocalTarget: Integer;' + sLineBreak +
    'begin' + sLineBreak + '  lLocalTarget := 0;' + sLineBreak + 'end;' +
    sLineBreak + 'end.', TEncoding.UTF8);
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectDirectory := lRoot;
  lProject.SourceFileNames := TArray<string>.Create(lFileName);
  lProject.SearchPaths := TArray<string>.Create(lRoot);

  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'fPrivateTarget');
  Assert.AreEqual(1, lResult.FullModelCount,
    'Private declarations must retain their owning unit.');
  Assert.AreEqual(lFileName, lResult.SourceFileNames[0]);

  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'lLocalTarget');
  Assert.AreEqual(1, lResult.FullModelCount,
    'Local declarations must retain their owning unit.');
  Assert.AreEqual(lFileName, lResult.SourceFileNames[0]);
end;

procedure TProjectSessionTests.IdentifierCandidateCollectorSupportsWindows1252;
var
  lEncoding: TEncoding;
  lFileName: string;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticIdentifierScopeResult;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('identifier-windows-1252');
  TDirectory.CreateDirectory(lRoot);
  lFileName := TPath.Combine(lRoot, 'Windows1252Unit.pas');
  lEncoding := TEncoding.GetEncoding(1252);
  try
    TFile.WriteAllText(lFileName, 'unit Windows1252Unit;' + sLineBreak +
      'interface' + sLineBreak + '// Café' + sLineBreak +
      'const AnsiTarget = 1;' + sLineBreak + 'implementation' + sLineBreak +
      'end.', lEncoding);
  finally
    lEncoding.Free;
  end;
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectDirectory := lRoot;
  lProject.SourceFileNames := TArray<string>.Create(lFileName);
  lProject.SearchPaths := TArray<string>.Create(lRoot);

  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'AnsiTarget');

  Assert.IsTrue(lResult.UseScopedAnalysis,
    'The source loader-supported Windows-1252 encoding must remain scannable.');
  Assert.IsFalse(lResult.FailOpen);
  Assert.AreEqual(1, lResult.FullModelCount);
end;

procedure TProjectSessionTests.
  IdentifierCandidateCollectorIncludesTransitiveAndSharedOwners;
var
  lOtherFileName: string;
  lOwnerOneFileName: string;
  lOwnerTwoFileName: string;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticIdentifierScopeResult;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('identifier-include-owners');
  TDirectory.CreateDirectory(lRoot);
  lOwnerOneFileName := TPath.Combine(lRoot, 'OwnerOne.pas');
  lOwnerTwoFileName := TPath.Combine(lRoot, 'OwnerTwo.pas');
  lOtherFileName := TPath.Combine(lRoot, 'OwnerOther.pas');
  TFile.WriteAllText(TPath.Combine(lRoot, 'Direct.inc'), '{$I Shared.inc}',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Shared.inc'),
    'const IncludeTarget = 1;', TEncoding.UTF8);
  TFile.WriteAllText(lOwnerOneFileName, 'unit OwnerOne;' + sLineBreak +
    'interface' + sLineBreak + '{$I Direct.inc}' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lOwnerTwoFileName, 'unit OwnerTwo;' + sLineBreak +
    'interface' + sLineBreak + '{$I Shared.inc}' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lOtherFileName, 'unit OwnerOther;' + sLineBreak +
    'interface' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectDirectory := lRoot;
  lProject.SourceFileNames := TArray<string>.Create(lOwnerOneFileName,
    lOwnerTwoFileName, lOtherFileName);
  lProject.SearchPaths := TArray<string>.Create(lRoot);

  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'IncludeTarget');

  Assert.IsTrue(lResult.UseScopedAnalysis);
  Assert.IsFalse(lResult.FailOpen);
  Assert.AreEqual(2, lResult.FullModelCount);
  Assert.AreEqual(1, lResult.LeanModelCount);
  Assert.AreEqual(2, Integer(Length(lResult.SourceFileNames)));
  Assert.AreEqual(lOwnerOneFileName, lResult.SourceFileNames[0]);
  Assert.AreEqual(lOwnerTwoFileName, lResult.SourceFileNames[1]);
end;

procedure TProjectSessionTests.IdentifierCandidateCollectorHandlesAliasesAndAmbiguity;
var
  lAliasFileName: string;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticIdentifierScopeResult;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('identifier-aliases');
  TDirectory.CreateDirectory(lRoot);
  lAliasFileName := TPath.Combine(lRoot, 'AliasConsumer.pas');
  TFile.WriteAllText(lAliasFileName, 'unit AliasConsumer;' + sLineBreak +
    'interface' + sLineBreak + 'uses OldUnit;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectDirectory := lRoot;
  lProject.SourceFileNames := TArray<string>.Create(lAliasFileName);
  lProject.SearchPaths := TArray<string>.Create(lRoot);
  lProject.UnitAliases := TArray<string>.Create('OldUnit=NewUnit');

  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'NewUnit');
  Assert.IsTrue(lResult.UseScopedAnalysis);
  Assert.IsFalse(lResult.FailOpen);
  Assert.AreEqual(1, lResult.FullModelCount);

  lProject.UnitAliases := TArray<string>.Create('OldUnit=NewUnit',
    'OldUnit=DifferentUnit');
  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'NewUnit');
  Assert.IsTrue(lResult.FailOpen);
  Assert.IsFalse(lResult.UseScopedAnalysis);
  Assert.AreEqual(1, lResult.FullModelCount);
  Assert.AreNotEqual('', lResult.FailOpenReason);
end;

procedure TProjectSessionTests.IdentifierCandidateCollectorFailsOpenForUnsafeInputs;
var
  lMissingFileName: string;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticIdentifierScopeResult;
  lRoot: string;
  lUtf16FileName: string;
begin
  lRoot := ProjectSessionTempPath('identifier-unsafe-inputs');
  TDirectory.CreateDirectory(lRoot);
  lUtf16FileName := TPath.Combine(lRoot, 'Utf16Unit.pas');
  lMissingFileName := TPath.Combine(lRoot, 'MissingUnit.pas');
  TFile.WriteAllText(lUtf16FileName, 'unit Utf16Unit;' + sLineBreak +
    'interface' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.Unicode);
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectDirectory := lRoot;
  lProject.SourceFileNames := TArray<string>.Create(lUtf16FileName);
  lProject.SearchPaths := TArray<string>.Create(lRoot);

  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'AsciiName');
  Assert.IsTrue(lResult.FailOpen, 'UTF-16 must fail open to full analysis.');
  Assert.AreEqual(1, lResult.FullModelCount);

  lProject.SourceFileNames := TArray<string>.Create(lMissingFileName);
  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'AsciiName');
  Assert.IsTrue(lResult.FailOpen, 'Unreadable input must fail open.');

  lProject.SourceFileNames := TArray<string>.Create(lUtf16FileName);
  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'Náme');
  Assert.IsTrue(lResult.FailOpen, 'Unicode identifiers must fail open.');
  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'Unit.Name');
  Assert.IsTrue(lResult.FailOpen, 'Non-simple identifiers must fail open.');

  TDirectory.CreateDirectory(TPath.Combine(lRoot, 'include-one'));
  TDirectory.CreateDirectory(TPath.Combine(lRoot, 'include-two'));
  TFile.WriteAllText(TPath.Combine(lRoot, 'include-one\Ambiguous.inc'),
    'const AmbiguousTarget = 1;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'include-two\Ambiguous.inc'),
    'const AmbiguousTarget = 2;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'AmbiguousOwner.pas'),
    'unit AmbiguousOwner;' + sLineBreak +
    'interface' + sLineBreak + '{$I Ambiguous.inc}' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lProject.SourceFileNames := TArray<string>.Create(
    TPath.Combine(lRoot, 'AmbiguousOwner.pas'));
  lProject.SearchPaths := TArray<string>.Create(
    TPath.Combine(lRoot, 'include-one'), TPath.Combine(lRoot, 'include-two'));
  lResult := TDelphiSemanticIdentifierCandidateCollector.Collect(lProject,
    lProject.SourceFileNames, 'AmbiguousTarget');
  Assert.IsTrue(lResult.FailOpen, 'Ambiguous includes must fail open.');
  Assert.AreEqual('ambiguous-include', lResult.FailOpenReason,
    'Configured project search paths must participate in ambiguity checks.');
end;

procedure TProjectSessionTests.IdentifierScopedSessionMatchesForcedFullRename;
var
  lAutomatic: TIdentifierScopePlanResult;
  lDprojFileName: string;
  lForced: TIdentifierScopePlanResult;
  lOptions: TDelphiSemanticOptions;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('identifier-scoped-session-parity');
  lDprojFileName := CreateIdentifierScopeProject(lRoot);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win32';
  lAutomatic := BuildIdentifierScopePlan(lOptions);
  lOptions.ForceFullIdentifierAnalysis := True;
  lForced := BuildIdentifierScopePlan(lOptions);

  Assert.AreEqual('planned', lAutomatic.Plan.Status, lAutomatic.Plan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lAutomatic.Plan.Edits)));
  Assert.IsFalse(lAutomatic.ScopeMetrics.FailOpen);
  Assert.AreEqual(2, lAutomatic.ScopeMetrics.FullModelCount);
  Assert.AreEqual(2, lAutomatic.ScopeMetrics.LeanModelCount);
  Assert.IsTrue(lForced.ScopeMetrics.FailOpen);
  Assert.AreEqual(4, lForced.ScopeMetrics.FullModelCount);
  Assert.AreEqual(0, lForced.ScopeMetrics.LeanModelCount);
  AssertRenamePlansEqual(lForced.Plan, lAutomatic.Plan);
end;

procedure TProjectSessionTests.IdentifierScopedRenameMatchesColdWarmAndInvalidatedCache;
var
  lCached: TIdentifierScopePlanResult;
  lCacheFileName: string;
  lConsumerFileName: string;
  lExpected: TIdentifierScopePlanResult;
  lOptions: TDelphiSemanticOptions;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('identifier-scoped-cache-parity');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := CreateIdentifierScopeProject(lRoot);
  lOptions.Configuration := 'Release';
  lOptions.Platform := 'Win64';
  lCacheFileName := CombinePath([lRoot, '.dak', 'semantic-cache.sqlite3']);
  lExpected := BuildIdentifierScopePlan(lOptions);
  Assert.AreEqual('planned', lExpected.Plan.Status, lExpected.Plan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lExpected.Plan.Edits)));
  lOptions.SqliteCacheFileName := lCacheFileName;
  lCached := BuildIdentifierScopePlan(lOptions);
  AssertRenamePlansEqual(lExpected.Plan, lCached.Plan);
  lCached := BuildIdentifierScopePlan(lOptions);
  AssertRenamePlansEqual(lExpected.Plan, lCached.Plan);

  lConsumerFileName := TPath.Combine(lRoot, 'IdentifierScopeConsumer.pas');
  TFile.WriteAllText(lConsumerFileName,
    StringReplace(TFile.ReadAllText(lConsumerFileName),
      'ScopeTarget + 1', 'ScopeTarget + ScopeTarget', []), TEncoding.UTF8);
  lCached := BuildIdentifierScopePlan(lOptions);
  lOptions.SqliteCacheFileName := '';
  lExpected := BuildIdentifierScopePlan(lOptions);
  Assert.AreEqual(4, Integer(Length(lExpected.Plan.Edits)));
  AssertRenamePlansEqual(lExpected.Plan, lCached.Plan);
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
    Assert.AreEqual(2, lAnalysis.SnapshotUnitCount);
    Assert.AreEqual(2, lAnalysis.VerifiedScopeUnitCount);
    Assert.IsTrue(lCacheMetrics.CacheMisses > 0,
      'Snapshot-backed global analysis should preserve cache miss metrics.');
  finally
    lResult.Session.Free;
  end;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lAnalysis := lResult.Session.BuildGlobalAnalysis(lIdentities, lCacheMetrics,
      lExtractionMilliseconds);
    Assert.IsTrue(Length(lAnalysis.Declarations) > 0,
      'A cache hit must preserve explicit declaration facts.');
    Assert.AreEqual(2, lAnalysis.SnapshotUnitCount);
    Assert.AreEqual(2, lAnalysis.VerifiedScopeUnitCount,
      'A cache hit must preserve verified lexical-scope provenance.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionGlobalAnalysisHonorsWritableTypedConstants;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lDeclaration: TDelphiSemanticGlobalDeclaration;
  lDprPath: string;
  lDprojPath: string;
  lExtractionMilliseconds: Int64;
  lFound: Boolean;
  lIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lUnitPath: string;
begin
  lRootPath := ProjectSessionTempPath('global-analysis-writable-typed-constants');
  TDirectory.CreateDirectory(lRootPath);
  lDprPath := TPath.Combine(lRootPath, 'WritableTypedConstants.dpr');
  lDprojPath := TPath.Combine(lRootPath, 'WritableTypedConstants.dproj');
  lUnitPath := TPath.Combine(lRootPath, 'WritableTypedConstantsUnit.pas');
  TFile.WriteAllText(lDprPath, 'program WritableTypedConstants;' + sLineBreak +
    'uses WritableTypedConstantsUnit;' + sLineBreak + 'begin' + sLineBreak +
    'end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <MainSource>WritableTypedConstants.dpr</MainSource>' + sLineBreak +
    '    <DCC_WriteableConstants>true</DCC_WriteableConstants>' + sLineBreak +
    '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' + sLineBreak +
    '    <DCCReference Include="WritableTypedConstantsUnit.pas"/>' + sLineBreak +
    '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit WritableTypedConstantsUnit;' + sLineBreak +
    'interface' + sLineBreak + 'const' + sLineBreak +
    '  GMutableValue: Integer = 1;' + sLineBreak + 'implementation' +
    sLineBreak + 'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojPath;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lAnalysis := lResult.Session.BuildGlobalAnalysis(lIdentities, lCacheMetrics,
      lExtractionMilliseconds);
    lFound := False;
    for lDeclaration in lAnalysis.Declarations do
      if SameText(lDeclaration.Name, 'GMutableValue') then
      begin
        lFound := True;
        Break;
      end;
    Assert.IsTrue(lFound,
      'DCC_WriteableConstants=true must make typed constants mutable globals.');
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
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lTypeNameId: TSemanticStringId;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
  i: Integer;
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
      Inc(lExpectedWithStatementCount, Length(lModel.WithStatements));
    end;

    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, lMetrics);
    try
      Assert.AreEqual(Integer(Length(lFacts.UnitModels)), lSnapshot.UnitCount);
      Assert.AreEqual(lSnapshot.UnitCount, lMetrics.UnitCount);
      for i := 0 to lSnapshot.UnitCount - 1 do
        Inc(lExpectedSymbolCount, lSnapshot.UnitByIndex(i).SymbolCount);
      Assert.AreEqual(lExpectedSymbolCount, lMetrics.SymbolCount);
      Assert.AreEqual(lExpectedReferenceCount, lMetrics.ReferenceCount);
      Assert.AreEqual(lExpectedWithStatementCount, lMetrics.WithStatementCount);
      Assert.AreEqual(Integer(Length(lFacts.Bindings)), lMetrics.WithStatementCount);
      Assert.IsTrue(lMetrics.BuildMilliseconds >= 0);

      Assert.IsTrue(lSnapshot.TryFindUnitByFileName(
        FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'), lUnitId),
        'Expected project DPR unit in snapshot.');
      Assert.IsTrue(lSnapshot.TryFindUnitById(lUnitId, lUnit),
        'Expected project DPR unit ID to resolve.');
      Assert.AreEqual(FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'),
        lSnapshot.TextOf(lUnit.FileNameId));

      Assert.IsTrue(lSnapshot.TryFindStringId('TProjectWithRecord', lTypeNameId),
        'Expected TProjectWithRecord string in snapshot.');
      Assert.IsTrue(lSnapshot.TryTypesByName(lTypeNameId, lLowIndex, lHighIndex),
        'Expected TProjectWithRecord type index entry.');
      Assert.IsTrue(lSnapshot.TryFindStringId('Value', lMemberNameId),
        'Expected Value member string in snapshot.');
      Assert.IsTrue(lSnapshot.TryFindMember(lTypeNameId, lMemberNameId, lSymbolRef),
        'Expected TProjectWithRecord.Value member index entry.');
      Assert.IsTrue(lSnapshot.TryFindUnitById(lSymbolRef.UnitId, lUnit),
        'Expected member unit ID to resolve.');
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

procedure TProjectSessionTests.TenAlternativePlansReuseOwnedContext(const aPersistent: Boolean);
var
  i, j: Integer;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext, lRetainedContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lPlan: TDelphiSemanticRenamePlan;
  lPlans: array[0..9] of TDelphiSemanticRenamePlan;
  lResult: TDelphiSemanticProjectSessionResult;
  lRoot: string;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := ProjectSessionTempPath('refactoring-light-reuse-' + BoolToStr(aPersistent, True));
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := CreateIdentifierScopeProject(lRoot);
  lOptions.Platform := 'Win64';
  if aPersistent then
    lOptions.SqliteCacheFileName := CombinePath([lRoot, '.dak', 'IdentifierScopeProject',
      'semantic-cache.sqlite3']);
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lContext := lResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    lSnapshot := lContext.ProjectSnapshot.Snapshot;
    for i := 0 to High(lPlans) do
    begin
      lPlans[i] := TDelphiSemanticRenamePlanner.PlanRename(lContext,
        'ScopeTarget', 'Alternative' + IntToStr(i));
      Assert.AreEqual('planned', lPlans[i].Status, lPlans[i].Diagnostic);
      Assert.AreEqual(3, Integer(Length(lPlans[i].Edits)));
      Assert.AreEqual(0, lPlans[i].IndexMetrics.BuildInvocationCount);
      Assert.AreEqual(0, lPlans[i].IndexMetrics.ReferenceResolutionSymbolScanCount);
      Assert.IsTrue(lSnapshot = lContext.ProjectSnapshot.Snapshot);
    end;
    lRetainedContext := lContext;
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    Assert.IsTrue(lContext.ProjectSnapshot = nil);
  finally
    lResult.Session.Free;
  end;
  // A copied context owns the immutable snapshot independently of its session.
  for i := High(lPlans) downto 0 do
  begin
    lPlan := TDelphiSemanticRenamePlanner.PlanRename(lRetainedContext,
      'ScopeTarget', 'Alternative' + IntToStr(i));
    AssertRenamePlansEqual(lPlans[i], lPlan);
    Assert.AreEqual(lPlans[i].BaselineSemanticModelVersion, lPlan.BaselineSemanticModelVersion);
    Assert.AreEqual(Length(lPlans[i].RequiredVerification), Length(lPlan.RequiredVerification));
    for j := 0 to High(lPlan.RequiredVerification) do
    begin
      Assert.AreEqual(lPlans[i].RequiredVerification[j].Kind, lPlan.RequiredVerification[j].Kind);
      Assert.AreEqual(lPlans[i].RequiredVerification[j].Description,
        lPlan.RequiredVerification[j].Description);
    end;
    Assert.AreEqual(0, lPlan.IndexMetrics.BuildInvocationCount);
    Assert.IsTrue(lSnapshot = lRetainedContext.ProjectSnapshot.Snapshot);
  end;
end;

procedure TProjectSessionTests.ChangedCompilerContextInvalidatesSnapshotCache;
var
  i: Integer;
  lContext: TDelphiSemanticSymbolQueryContext;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRoot, lUnitFileName: string;
begin
  lRoot := ProjectSessionTempPath('refactoring-light-context');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := CreateIdentifierScopeProject(lRoot);
  lOptions.SqliteCacheFileName := CombinePath([lRoot, '.dak', 'IdentifierScopeProject',
    'semantic-cache.sqlite3']);
  lUnitFileName := TPath.Combine(lRoot, 'IdentifierScopeProvider.pas');
  TFile.WriteAllText(lUnitFileName, 'unit IdentifierScopeProvider;' + sLineBreak +
    'interface' + sLineBreak + '{$IFDEF WIN64}' + sLineBreak +
    'var Context64: Integer;' + sLineBreak + '{$ELSE}' + sLineBreak +
    'var Context32: Integer;' + sLineBreak + '{$ENDIF}' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  for i := 0 to 2 do
  begin
    if i = 1 then
      lOptions.Platform := 'Win32'
    else
      lOptions.Platform := 'Win64';
    lResult := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lResult.Success);
      lContext := lResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
        lExtractionMilliseconds);
      Assert.AreEqual(i <> 1,
        TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'Context64').Found);
      Assert.AreEqual(i = 1,
        TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'Context32').Found);
    finally
      lResult.Session.Free;
    end;
  end;
end;

procedure TProjectSessionTests.ProjectSessionBuildsOwnedSnapshotQueryContext;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lDefinition: TDelphiSemanticSymbolQueryResult;
  lExtractionMilliseconds: Int64;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lContext := lResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
      lExtractionMilliseconds);
    Assert.IsTrue(lContext.ProjectSnapshot <> nil,
      'Expected session-built query context to own a project snapshot.');
    Assert.IsTrue(lContext.ProjectSnapshot.Snapshot <> nil,
      'Expected session-built query context to expose an owned project snapshot.');
    Assert.AreEqual(2, lContext.ProjectSnapshot.Snapshot.UnitCount);

    lDefinition := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext,
      'TProjectWithRecord');
    Assert.IsTrue(lDefinition.Found,
      'Expected TProjectWithRecord definition in owned snapshot context.');
    Assert.AreEqual('project-snapshot', lDefinition.Provenance);
    lIndex := TDelphiSemanticProjectSymbolIndexer.Build(lContext);
    Assert.AreEqual(0, lIndex.Metrics.BuildInvocationCount,
      'Owned snapshot query context should use the snapshot index path.');
  finally
    lResult.Session.Free;
  end;

  try
    lDefinition := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext,
      'TProjectWithRecord');
    Assert.IsTrue(lDefinition.Found,
      'Owned snapshot query context should remain valid after the session is freed.');
    Assert.AreEqual('project-snapshot', lDefinition.Provenance);
  finally
    lContext.ProjectSnapshot := nil;
  end;
end;

function CreateTypedConstantQueryFixture: string;
var
  lUnitPath: string;
begin
  Result := ProjectSessionTempPath('typed-constant-query-cache');
  TDirectory.CreateDirectory(Result);
  lUnitPath := TPath.Combine(Result, 'TypedValues.pas');
  TFile.WriteAllText(TPath.Combine(Result, 'TypedValuesProject.dpr'),
    'program TypedValuesProject;' + sLineBreak + 'uses TypedValues;' +
    sLineBreak + 'begin end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(Result, 'TypedValuesProject.dproj'),
    '<Project><PropertyGroup><MainSource>TypedValuesProject.dpr</MainSource>' +
    '</PropertyGroup><ItemGroup><DCCReference Include="TypedValues.pas"/>' +
    '</ItemGroup></Project>', TEncoding.UTF8);
  TFile.WriteAllText(lUnitPath, 'unit TypedValues;' + sLineBreak +
    'interface' + sLineBreak + '{$J-}' + sLineBreak + 'const' + sLineBreak +
    '  ReadOnlyValue: Integer = 1;' + sLineBreak + '{$J+}' + sLineBreak +
    'const' + sLineBreak + '  WritableValue: Integer = 2;' + sLineBreak +
    'function ReadBoth: Integer;' + sLineBreak + 'implementation' + sLineBreak +
    'function ReadBoth: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  Result := ReadOnlyValue;' + sLineBreak +
    '  Result := Result + WritableValue;' + sLineBreak + 'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
end;

procedure AssertTypedConstantQuery(const aContext: TDelphiSemanticSymbolQueryContext;
  const aUnitPath: string; j: Integer);
var
  lDefinition: TDelphiSemanticSymbolQueryResult;
  lName: string;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  lSnapshot := aContext.ProjectSnapshot.Snapshot;
  if j = 0 then
    lName := 'ReadOnlyValue'
  else
    lName := 'WritableValue';
  lDefinition := TDelphiSemanticSymbolQuery.FindDefinitionByName(aContext, lName);
  Assert.IsTrue(lDefinition.Found, lName + ' must remain in shared symbols.');
  lDefinition := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(aContext,
    aUnitPath, 13 + j, 13 + j * 9);
  Assert.IsTrue(lDefinition.Found, lName + ' must resolve at its read site.');
  Assert.IsTrue(lSnapshot.TryReferenceAt(aUnitPath, 13 + j, 13 + j * 9,
    lReferenceRef));
  Assert.IsTrue(lSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit));
  lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
  Assert.AreNotEqual(0, Integer(lReference.TargetSymbolId),
    lName + ' must have a resolved reference target.');
  Assert.IsTrue(lSnapshot.TryFindUnitById(lReference.TargetUnitId, lUnit));
  lSymbol := lUnit.SymbolById(lReference.TargetSymbolId);
  Assert.AreEqual(lName, lSnapshot.TextOf(lSymbol.NameId));
end;

procedure SetTypedConstantCacheMode(var aOptions: TDelphiSemanticOptions;
  const aRootPath: string; i: Integer);
begin
  if i > 0 then
    aOptions.SqliteCacheFileName := TPath.Combine(aRootPath, 'snapshot.sqlite');
  if i = 3 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v6''');
  if i = 4 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v9''');
  if i = 5 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v10''');
  if i = 6 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v11''');
  if i = 7 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v12''');
  if i = 8 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v13''');
  if i = 9 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v14''');
  if i = 10 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v15''');
  if i = 11 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v16''');
  if i = 12 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v40''');
  if i = 13 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v41''');
  if i = 17 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v45''');
  if i = 16 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v44''');
  if i = 15 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v43''');
  if i = 14 then
    ExecProjectSessionCacheSql(aOptions.SqliteCacheFileName,
      'update snapshot_units set schema_version = ''project-session-snapshot-v42''');
end;

procedure TProjectSessionTests.RebuildsSnapshotBeforeInactiveNestedWithSafety;
var
  i: Integer;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lOpened: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
begin
  lRootPath := CreateTypedConstantQueryFixture;
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'TypedValuesProject.dproj');
  lOptions.SqliteCacheFileName := TPath.Combine(lRootPath, 'ds724-snapshot-v46.sqlite');
  for i := 0 to 3 do
  begin
    if i = 2 then
      ExecProjectSessionCacheSql(lOptions.SqliteCacheFileName,
        'update snapshot_units set schema_version = ''project-session-snapshot-v46''');
    lOpened := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lOpened.Success);
      lContext := lOpened.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
        lExtractionMilliseconds);
      if (i = 0) or (i = 2) then
      begin
        Assert.IsTrue(lCacheMetrics.CacheMisses > 0, 'Snapshot-v46 must rebuild.');
        Assert.AreEqual(0, lCacheMetrics.CacheHits);
      end else begin
        Assert.IsTrue(lCacheMetrics.CacheHits > 0, 'Fresh snapshot must hit.');
        Assert.AreEqual(0, lCacheMetrics.CacheMisses);
      end;
      AssertTypedConstantQuery(lContext, TPath.Combine(lRootPath, 'TypedValues.pas'), 0);
      AssertTypedConstantQuery(lContext, TPath.Combine(lRootPath, 'TypedValues.pas'), 1);
    finally
      lContext.ProjectSnapshot := nil;
      lOpened.Session.Free;
    end;
  end;
end;

procedure TProjectSessionTests.RebuildsSnapshotBeforeAliasReceiverMembers;
var
  i: Integer;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lOpened: TDelphiSemanticProjectSessionResult;
  lBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lRootPath: string;
begin
  lRootPath := ProjectSessionTempPath('ds741-snapshot-v48');
  TDirectory.CreateDirectory(lRootPath);
  TFile.WriteAllText(TPath.Combine(lRootPath, 'Unit1.pas'),
      'unit Unit1;'#13#10 +
      'interface'#13#10 +
      'procedure Run;'#13#10 +
      'type'#13#10 +
      ' TItem = record'#13#10 +
      '  var A: Integer;'#13#10 +
      '  var Z: Integer;'#13#10 +
      ' end;'#13#10 +
      ' TAlias = TItem;'#13#10 +
      'var'#13#10 +
      ' Item: TAlias;'#13#10 +
      ' A: Integer = 0;'#13#10 +
      'implementation'#13#10 +
      'procedure Run;'#13#10 +
      'begin'#13#10 +
      ' with Item do A := 7;'#13#10 +
      ' Writeln(Item.A, '' '', A);'#13#10 +
      'end;'#13#10 +
      'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRootPath, 'P.dpr'),
    'program P; uses Unit1; begin Run; end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRootPath, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lOptions.DelphiVersion := '23.0';
  lOptions.Platform := 'Win64';
  lOptions.Configuration := 'Debug';
  lOptions.SqliteCacheFileName := TPath.Combine(lRootPath, 'snapshot.sqlite');
  for i := 0 to 3 do
  begin
    if i = 2 then
      ExecProjectSessionCacheSql(lOptions.SqliteCacheFileName,
        'update snapshot_units set schema_version = ''project-session-snapshot-v48''');
    lOpened := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lOpened.Success);
      lContext := lOpened.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
        lExtractionMilliseconds);
      if (i = 0) or (i = 2) then
      begin
        Assert.IsTrue(lCacheMetrics.CacheMisses > 0, 'Snapshot-v48 must rebuild.');
        Assert.AreEqual(0, lCacheMetrics.CacheHits);
      end else begin
        Assert.IsTrue(lCacheMetrics.CacheHits > 0, 'Fresh alias snapshot must hit.');
        Assert.AreEqual(0, lCacheMetrics.CacheMisses);
      end;
      lBuild := lOpened.Session.PlanRemoveWithResult;
      Assert.AreEqual(1, Integer(Length(lBuild.Plan.FinalStatements)));
      Assert.AreEqual('planned', lBuild.Plan.FinalStatements[0].Status);
      Assert.AreEqual(' Item.A := 7;', lBuild.Plan.FinalStatements[0].ReplacementText);
    finally
      lContext.ProjectSnapshot := nil;
      lOpened.Session.Free;
    end;
  end;
end;

procedure TProjectSessionTests.RebuildsSnapshotBeforeReceiverValueMembers;
var
  i: Integer;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lExtractionMilliseconds: Int64;
  lOptions: TDelphiSemanticOptions;
  lOpened: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
begin
  lRootPath := CreateTypedConstantQueryFixture;
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'TypedValuesProject.dproj');
  lOptions.SqliteCacheFileName := TPath.Combine(lRootPath, 'ds731-snapshot-v47.sqlite');
  for i := 0 to 3 do
  begin
    if i = 2 then
      ExecProjectSessionCacheSql(lOptions.SqliteCacheFileName,
        'update snapshot_units set schema_version = ''project-session-snapshot-v47''');
    lOpened := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lOpened.Success);
      lContext := lOpened.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
        lExtractionMilliseconds);
      if (i = 0) or (i = 2) then
      begin
        Assert.IsTrue(lCacheMetrics.CacheMisses > 0, 'Snapshot-v47 must rebuild.');
        Assert.AreEqual(0, lCacheMetrics.CacheHits);
      end else begin
        Assert.IsTrue(lCacheMetrics.CacheHits > 0, 'Fresh snapshot must hit.');
        Assert.AreEqual(0, lCacheMetrics.CacheMisses);
      end;
      AssertTypedConstantQuery(lContext, TPath.Combine(lRootPath, 'TypedValues.pas'), 0);
      AssertTypedConstantQuery(lContext, TPath.Combine(lRootPath, 'TypedValues.pas'), 1);
    finally
      lContext.ProjectSnapshot := nil;
      lOpened.Session.Free;
    end;
  end;
end;

procedure TProjectSessionTests.TypedConstantsRemainQueryableAcrossSnapshotCacheModes;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lContext: TDelphiSemanticSymbolQueryContext;
  lDeclaration: TDelphiSemanticGlobalDeclaration;
  lExtractionMilliseconds: Int64;
  lFoundWritable: Boolean;
  lIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lUnitPath: string;
  i: Integer;
  j: Integer;
begin
  lRootPath := CreateTypedConstantQueryFixture;
  lUnitPath := TPath.Combine(lRootPath, 'TypedValues.pas');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'TypedValuesProject.dproj');
  for i := 0 to 18 do
  begin
    SetTypedConstantCacheMode(lOptions, lRootPath, i);
    lResult := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lResult.Success);
      lContext := lResult.Session.BuildSnapshotSymbolQueryContext(lCacheMetrics,
        lExtractionMilliseconds);
      if (i = 1) or (i = 3) then
        Assert.IsTrue(lCacheMetrics.CacheMisses > 0,
          'Cold or pre-immutable-inventory snapshot must miss.');
      if (i = 2) or (i = 18) then
      begin
        Assert.IsTrue(lCacheMetrics.CacheHits > 0, 'Warm snapshot must hit.');
        Assert.AreEqual(0, lCacheMetrics.CacheMisses);
      end;
      if (i >= 3) and (i <= 16) then
        Assert.IsTrue(lCacheMetrics.CacheMisses > 0, 'Older snapshot semantics must be rebuilt.');
      if i = 17 then
        Assert.IsTrue(lCacheMetrics.CacheMisses > 0, 'Parser-69 helper refusal requires rebuilding snapshot-v45.');
      for j := 0 to 1 do
        AssertTypedConstantQuery(lContext, lUnitPath, j);
      lAnalysis := lResult.Session.BuildGlobalAnalysis(lIdentities, lCacheMetrics,
        lExtractionMilliseconds);
      lFoundWritable := False;
      for lDeclaration in lAnalysis.Declarations do
      begin
        Assert.IsFalse(SameText(lDeclaration.Name, 'ReadOnlyValue'),
          'Read-only constants must stay out of mutable-global reporting.');
        if SameText(lDeclaration.Name, 'WritableValue') then
          lFoundWritable := True;
      end;
      Assert.IsTrue(lFoundWritable, 'Writable constants must remain mutable globals.');
    finally
      lContext.ProjectSnapshot := nil;
      lResult.Session.Free;
    end;
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
    lSequentialSnapshot := BuildSnapshotWithMetrics(lSequentialResult.Session,
      lSequentialMetrics);
    try
      Assert.AreEqual(1, lSequentialMetrics.SnapshotBuilderWorkerCount);

      lParallelResult := TDelphiSemanticProjectSession.Open(lParallelOptions);
      try
        Assert.IsTrue(lParallelResult.Success);
        lParallelSnapshot := BuildSnapshotWithMetrics(lParallelResult.Session,
          lParallelMetrics);
        try
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
    lSequentialPlan := PlanRemoveWithWithMetrics(lSequentialResult.Session,
      lSequentialMetrics);
    Assert.AreEqual(1, lSequentialMetrics.SnapshotBuilderWorkerCount);

    lParallelResult := TDelphiSemanticProjectSession.Open(lParallelOptions);
    try
      Assert.IsTrue(lParallelResult.Success);
      lParallelPlan := PlanRemoveWithWithMetrics(lParallelResult.Session,
        lParallelMetrics);

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

procedure AssertCombinedApiOpensOneSession(const aSource: string);
var
  lBody: string;
  lEndIndex: Integer;
  lFirstOpenIndex: Integer;
  lStartIndex: Integer;
begin
  lStartIndex := Pos('class function TDelphiSemanticRemoveWithCompatibilityApi.' +
    'BuildProjectWithBindingFactsAndPlanResult(' + sLineBreak +
    '  const aRequest', aSource);
  Assert.IsTrue(lStartIndex > 0,
    'Expected request-based combined compatibility implementation.');
  lEndIndex := PosEx('class function TDelphiSemanticRemoveWithCompatibilityApi.' +
    'PlanRemoveWith(', aSource, lStartIndex);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected combined compatibility implementation before PlanRemoveWith.');
  lBody := Copy(aSource, lStartIndex, lEndIndex - lStartIndex);
  lFirstOpenIndex := Pos('OpenProjectSession(', lBody);
  Assert.IsTrue(lFirstOpenIndex > 0,
    'Combined compatibility operation must open a project session.');
  Assert.AreEqual(0, PosEx('OpenProjectSession(', lBody, lFirstOpenIndex + 1),
    'Combined compatibility operation must open exactly one project session.');
  Assert.IsTrue(ContainsText(lBody, 'Inc(lSessionOpenCount)'),
    'Session metrics must increment at the actual open boundary.');
  Assert.IsFalse(ContainsText(lBody, 'SemanticSessionOpenCount := 1'),
    'Session metrics must not assert a literal count.');
  Assert.IsFalse(ContainsText(lBody, 'BuildProjectWithBindingFactsResult('),
    'Combined operation must not open the legacy facts-session path.');
end;

procedure AssertNoLegacyCombinedResultRoutes(const aBody: string);
begin
  Assert.IsFalse(ContainsText(aBody, 'BuildWithBindingFacts('),
    'Combined helper must not call the legacy raw facts overload.');
  Assert.IsFalse(ContainsText(aBody, 'BuildWithBindingFactsResult('),
    'Combined helper must not call the legacy facts-result overload.');
  Assert.IsFalse(ContainsText(aBody, 'BuildProjectWithBindingFacts('),
    'Combined helper must not open the legacy raw facts API route.');
  Assert.IsFalse(ContainsText(aBody, 'BuildProjectWithBindingFactsResult('),
    'Combined helper must not open the legacy facts-result API route.');
  Assert.IsFalse(ContainsText(aBody, 'PlanRemoveWith('),
    'Combined helper must not call a legacy raw planning route.');
  Assert.IsFalse(ContainsText(aBody, 'PlanRemoveWithResult('),
    'Combined helper must not call a legacy plan-result route.');
end;

procedure AssertCombinedResultHelperUsesOneSessionOperation(
  const aSource: string);
var
  lBody: string;
  lCombinedCallIndex: Integer;
  lEndIndex: Integer;
  lExceptionBody: string;
  lExceptionIndex: Integer;
  lStartIndex: Integer;
begin
  lStartIndex := Pos('function CombinedResultFromSession(', aSource);
  Assert.IsTrue(lStartIndex > 0,
    'Expected the combined result helper implementation.');
  lEndIndex := PosEx('function FactBuildDiagnosticsMessage(', aSource,
    lStartIndex);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected the combined helper before fact diagnostic formatting.');
  lBody := Copy(aSource, lStartIndex, lEndIndex - lStartIndex);
  lCombinedCallIndex := Pos(
    'aSession.Session.BuildRemoveWithFactsAndPlanResult(', lBody);
  Assert.IsTrue(lCombinedCallIndex > 0,
    'Combined helper must call the one-session facts-and-plan operation.');
  Assert.AreEqual(0, PosEx(
    'aSession.Session.BuildRemoveWithFactsAndPlanResult(', lBody,
    lCombinedCallIndex + 1),
    'Combined helper must call the facts-and-plan operation exactly once.');
  AssertNoLegacyCombinedResultRoutes(lBody);
  lExceptionIndex := Pos('except', lBody);
  Assert.IsTrue(lExceptionIndex > 0,
    'Combined helper must preserve metrics when its session operation raises.');
  lExceptionBody := Copy(lBody, lExceptionIndex, MaxInt);
  Assert.IsTrue(ContainsText(lExceptionBody,
    'aSession.Session.LastRemoveWithFactsAndPlanBuildMetrics'),
    'Combined exception handling must read the latest session metrics.');
  Assert.IsTrue(ContainsText(lExceptionBody,
    'ApplyCombinedBuildMetrics(lFailure.Metrics, lBuildMetrics,'),
    'Combined exception handling must publish the recovered phase metrics.');
end;

procedure AssertCombinedSessionExtractsOnce(const aSource: string);
var
  lBody: string;
  lEndIndex: Integer;
  lFirstFactsBuildIndex: Integer;
  lStartIndex: Integer;
begin
  lStartIndex := Pos('function TDelphiSemanticProjectSession.' +
    'BuildRemoveWithFactsAndPlanResult(' + sLineBreak +
    '  const aScopedSourceFileNames', aSource);
  Assert.IsTrue(lStartIndex > 0,
    'Expected scoped combined session implementation.');
  lEndIndex := PosEx('function TDelphiSemanticProjectSession.PlanRemoveWith:',
    aSource, lStartIndex);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected combined session implementation before PlanRemoveWith.');
  lBody := Copy(aSource, lStartIndex, lEndIndex - lStartIndex);
  lFirstFactsBuildIndex := Pos('BuildWithBindingFactsResultCore(', lBody);
  Assert.IsTrue(lFirstFactsBuildIndex > 0,
    'Combined session must build compatibility facts.');
  Assert.AreEqual(0, PosEx('BuildWithBindingFactsResultCore(', lBody,
    lFirstFactsBuildIndex + 1),
    'Combined session must perform one facts/model-extraction pass.');
  Assert.IsTrue(ContainsText(lBody,
    'Inc(fLastRemoveWithFactsAndPlanBuildMetrics.ModelExtractionPassCount)'),
    'Extraction metrics must increment at the actual facts-build boundary.');
  Assert.IsFalse(ContainsText(lBody, 'ModelExtractionPassCount := 1'),
    'Extraction metrics must not assert a literal count.');
  Assert.IsFalse(ContainsText(lBody, 'PlanRemoveWithResult'),
    'Combined session must not trigger the second extraction plan path.');
  Assert.IsTrue(ContainsText(lBody,
    'BuildCompatibilityRemoveWithPlanningSnapshotFromFacts'),
    'Combined session must build the canonical planning snapshot from its facts.');
  Assert.IsTrue(ContainsText(lBody,
    'TDelphiSemanticRemoveWithPlanner.Plan(lSnapshot,'),
    'Combined session must use the instrumented snapshot planner.');
  Assert.IsTrue(ContainsText(lBody,
    'fLastRemoveWithFactsAndPlanBuildMetrics.SemanticProjectFactsMilliseconds :='),
    'Facts timing must be published from its finally boundary.');
  Assert.IsTrue(ContainsText(lBody,
    'fLastRemoveWithFactsAndPlanBuildMetrics.SemanticPlanMilliseconds :='),
    'Planning timing must be published from its finally boundary.');
end;

procedure AssertFactsBuildExtractsOnce(const aSource: string);
var
  lBody: string;
  lEndIndex: Integer;
  lFirstExtractionIndex: Integer;
  lStartIndex: Integer;
begin
  lStartIndex := Pos('function BuildWithBindingFactsResultCore(' +
    'const aProject', aSource);
  Assert.IsTrue(lStartIndex > 0,
    'Expected scoped facts-build implementation.');
  lEndIndex := PosEx('function BuildWithBindingFactsResultCore(' +
    'const aProject', aSource, lStartIndex + 1);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected the state-returning facts core before its convenience overload.');
  lBody := Copy(aSource, lStartIndex, lEndIndex - lStartIndex);
  lFirstExtractionIndex := Pos('ExtractProjectModels(', lBody);
  Assert.IsTrue(lFirstExtractionIndex > 0,
    'Facts build must reach the project-model extraction boundary.');
  Assert.AreEqual(0, PosEx('ExtractProjectModels(', lBody,
    lFirstExtractionIndex + 1),
    'One facts build must perform exactly one project-model extraction pass.');
end;

procedure AssertCombinedMetricDeclarations(const aApiSource,
  aSessionSource: string);
begin
  Assert.IsTrue(ContainsText(aApiSource,
    'TDelphiSemanticRemoveWithCombinedMetrics = record'),
    'Combined API must expose narrow operation metrics.');
  Assert.IsTrue(ContainsText(aApiSource,
    'TDelphiSemanticRemoveWithCombinedResult = record'),
    'Combined API must expose one facts-and-plan result.');
  Assert.IsTrue(ContainsText(aApiSource, 'SemanticSessionOpenCount: Integer'),
    'Combined metrics must count semantic session opens.');
  Assert.IsTrue(ContainsText(aApiSource, 'ModelExtractionPassCount: Integer'),
    'Combined metrics must count model-extraction passes.');
  Assert.IsTrue(ContainsText(aApiSource,
    'SemanticProjectFactsMilliseconds: Int64'),
    'Combined metrics must preserve the existing DAK facts timing boundary.');
  Assert.IsTrue(ContainsText(aApiSource, 'SemanticPlanMilliseconds: Int64'),
    'Combined metrics must preserve the existing DAK planning timing boundary.');
  Assert.IsTrue(ContainsText(aApiSource,
    'SemanticCachePersistenceAvailable: Boolean'),
    'Combined metrics must report final cache persistence state.');
  Assert.IsTrue(ContainsText(aSessionSource,
    'TDelphiSemanticRemoveWithFactsAndPlanBuildMetrics = record'),
    'Combined session must expose its phase metrics.');
end;

procedure AssertCombinedMetricFlow(const aApiSource, aSessionSource: string);
begin
  Assert.IsTrue(ContainsText(aApiSource,
    'aMetrics.SemanticProjectFactsMilliseconds :='),
    'Combined API must map measured facts time instead of one outer total.');
  Assert.IsTrue(ContainsText(aApiSource,
    'aMetrics.SemanticPlanMilliseconds :='),
    'Combined API must map measured canonical planning time.');
  Assert.IsTrue(ContainsText(aApiSource,
    'aMetrics.SemanticCachePersistenceAvailable :='),
    'Combined API must map final cache persistence state.');
  Assert.IsTrue(ContainsText(aSessionSource,
    'property LastRemoveWithFactsAndPlanBuildMetrics:'),
    'Combined session metrics must remain readable after an exception.');
  Assert.IsTrue(ContainsText(aApiSource,
    'ApplyCombinedBuildMetrics(aResult.Metrics, aBuildMetrics,'),
    'Successful combined operations must map session-owned phase metrics.');
  Assert.IsFalse(ContainsText(aApiSource, 'SemanticPlanMilliseconds := 0'),
    'Combined planning time must not be hardcoded to zero.');
end;

procedure TProjectSessionTests.CombinedRemoveWithApiExposesOneSessionContract;
var
  lApiSource: string;
  lSessionSource: string;
begin
  lApiSource := ReadRepoSource(
    'src\DelphiSemantics.Api.RemoveWith.Compatibility.pas');
  lSessionSource := ReadRepoSource('src\DelphiSemantics.ProjectSession.pas');

  AssertCombinedMetricDeclarations(lApiSource, lSessionSource);
  AssertCombinedMetricFlow(lApiSource, lSessionSource);
  Assert.IsTrue(ContainsText(lApiSource,
    'BuildProjectWithBindingFactsAndPlanResult'),
    'Compatibility API must expose the combined operation.');
  Assert.IsTrue(ContainsText(lSessionSource,
    'BuildRemoveWithFactsAndPlanResult'),
    'Project session must own the one-extraction facts-and-plan operation.');
  AssertCombinedApiOpensOneSession(lApiSource);
  AssertCombinedResultHelperUsesOneSessionOperation(lApiSource);
  AssertCombinedSessionExtractsOnce(lSessionSource);
  AssertFactsBuildExtractsOnce(lSessionSource);
end;

procedure TProjectSessionTests.ProjectSessionOperationResultsKeepMetricsStableAcrossLaterOperations;
var
  lFactsResult: TDelphiSemanticProjectWithBindingFactsBuildResult;
  lOptions: TDelphiSemanticOptions;
  lPlanResult: TDelphiSemanticRemoveWithPlanBuildResult;
  lResult: TDelphiSemanticProjectSessionResult;
  lSnapshotMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lSnapshotResult: TDelphiSemanticProjectSnapshotBuildResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lSnapshotResult := lResult.Session.BuildSnapshotResult;
    try
      lSnapshotMetrics := lSnapshotResult.Metrics;
      Assert.AreEqual(2, lSnapshotResult.Snapshot.UnitCount);
      Assert.AreEqual(lSnapshotResult.Snapshot.UnitCount, lSnapshotMetrics.UnitCount);

      lFactsResult := lResult.Session.BuildWithBindingFactsResult;
      Assert.IsTrue(Length(lFactsResult.Facts.Bindings) > 0);
      Assert.AreEqual(2, lFactsResult.SemanticGraphMetrics.UnitCount);

      lPlanResult := lResult.Session.PlanRemoveWithResult;
      Assert.IsTrue(Length(lPlanResult.Plan.FinalStatements) > 0);
      Assert.AreEqual(lSnapshotMetrics.UnitCount, lSnapshotResult.Metrics.UnitCount,
        'Snapshot operation metrics must stay attached to their original result.');
      Assert.AreEqual(lSnapshotMetrics.SymbolCount, lSnapshotResult.Metrics.SymbolCount,
        'Snapshot operation metrics must not depend on later facts or plan calls.');
    finally
      lSnapshotResult.Snapshot.Free;
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ProjectSessionBuildWithBindingFactsDoesNotBuildDiscardedSnapshot;
var
  lCachePath: string;
  lFactsResult: TDelphiSemanticProjectWithBindingFactsBuildResult;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
begin
  lRootPath := ProjectSessionTempPath('with-binding-facts-no-discarded-snapshot');
  if TDirectory.Exists(lRootPath) then
    TDirectory.Delete(lRootPath, True);
  TDirectory.CreateDirectory(lRootPath);
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.SqliteCacheFileName := lCachePath;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFactsResult := lResult.Session.BuildWithBindingFactsResult;
    Assert.IsTrue(Length(lFactsResult.Facts.Bindings) > 0);
    Assert.AreEqual(0, lFactsResult.SnapshotMetrics.UnitCount,
      'BuildWithBindingFactsResult must not build a discarded snapshot for metrics.');
    Assert.AreEqual(0, lFactsResult.SnapshotMetrics.SnapshotCacheProbes,
      'Binding facts should report only cache work they actually perform.');
    Assert.AreEqual(Int64(0),
      lFactsResult.Facts.Metrics.SnapshotSqlWriteMilliseconds);
    Assert.AreEqual(Int64(0),
      lFactsResult.Facts.Metrics.SnapshotSqlReadMilliseconds);
    Assert.AreEqual(Int64(0),
      lFactsResult.Facts.Metrics.SnapshotDeserializeMilliseconds);
    Assert.AreEqual(Int64(0),
      lFactsResult.Facts.Metrics.SnapshotIndexRebuildMilliseconds);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.ValueMembersSessionColdWarm(const aShape: string);
var
  lBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lCold: TDelphiSemanticRemoveWithPlan;
  lOpened: TDelphiSemanticProjectSessionResult;
  lOptions: TDelphiSemanticOptions;
  lRoot, lType, lGlobal, lLocal, lBody: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lRoot := ProjectSessionTempPath('DS731-session-' + aShape);
  TDirectory.CreateDirectory(lRoot);
  lType := 'type TItem = record A: Integer; case Count: Integer of 0: (X: Integer); end;';
  lGlobal := 'var Count: Integer;';
  lLocal := 'var lItems: TArray<TItem>; lIndex: Integer;';
  lBody := '  with lItems[lIndex] do A := Count;';
  if aShape = 'strong-alias-qualified-target' then
  begin
    lType := lType + #13#10'  TAlias = type TItem;'#13#10'var Rec: TAlias;';
    lLocal := '';
    lBody := '  with Rec do Rec.A := Count;';
  end;
  if aShape = 'indexed-inline-cross-unit' then
  begin
    lType := 'uses Unit2;'#13#10 + lType.Replace('case Count:',
      'case {$IFDEF NEVER_DS731}RealTag{$ELSE}Count{$ENDIF}:');
    lGlobal := '';
  end;
  if aShape = 'num-rec' then
  begin
    lType := '';
    lGlobal := '';
    lLocal := 'var'#13#10'  num_rec: packed record'#13#10'    ll: Integer;'#13#10 +
      '    case n_id: Byte of'#13#10'      0: (r_b: Byte);'#13#10 +
      '      1: (r_w: Word);'#13#10'  end;';
    lBody := '  with num_rec do ll := n_id;';
  end;
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P; uses Unit1, Unit2; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="Unit1.pas"/>' +
    '<DCCReference Include="Unit2.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit1.pas'),
    'unit Unit1;'#13#10'interface'#13#10 + lType + #13#10 + lGlobal +
    #13#10'implementation'#13#10'procedure Run;'#13#10 + lLocal +
    #13#10'begin'#13#10 + lBody + #13#10'end;'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Unit2.pas'),
    'unit Unit2;'#13#10'interface'#13#10'var Count: Integer;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lOptions.DelphiVersion := '23.0';
  lOptions.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  Assert.IsTrue(lOptions.ImplicitRootMemberAbsence = nil);
  for var i := 0 to 1 do
  begin
    lOpened := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lOpened.Success);
      lBuild := lOpened.Session.PlanRemoveWithResult;
    finally
      lOpened.Session.Free;
    end;
    Assert.AreEqual(Integer(i), Integer(lBuild.SnapshotMetrics.SnapshotCacheHits),
      'Pass 1 must load the persisted project facts, not just warm unit models.');
    Assert.AreEqual(1, Integer(Length(lBuild.Plan.FinalStatements)));
    lStatement := lBuild.Plan.FinalStatements[0];
    if aShape = 'num-rec' then
    begin
      Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      Assert.AreEqual(' num_rec.ll := num_rec.n_id;', lStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
    end else if aShape = 'strong-alias-qualified-target' then
    begin
      Assert.AreEqual('planned', lStatement.Status, aShape + ' pass ' + IntToStr(i));
      Assert.AreEqual(' Rec.A := Rec.Count;', lStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(1, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(1, Integer(Length(lBuild.Plan.Edits)));
    end else begin
      Assert.AreEqual('skipped', lStatement.Status, aShape + ' pass ' + IntToStr(i));
      Assert.AreEqual('TYPE_VALUE_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
      Assert.AreEqual('', lStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(0, Integer(Length(lBuild.Plan.Edits)));
    end;
    if i = 0 then
      lCold := lBuild.Plan
    else
      Assert.AreEqual(lCold.FinalStatements[0].ReplacementText, lStatement.ReplacementText);
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
    lFirstPlan := PlanRemoveWithWithMetrics(lFirstResult.Session, lFirstMetrics);
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
    lSecondPlan := PlanRemoveWithWithMetrics(lSecondResult.Session, lSecondMetrics);
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
    lThirdPlan := PlanRemoveWithWithMetrics(lThirdResult.Session, lThirdMetrics);
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

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithInvalidatesLegacyParentSelectorFacts;
const
  cLegacySchemaVersion = 'project-session-remove-with-facts-v22';
  cRunNestedInnerSelectorLine = 60;
  cRunNestedInnerSelectorColumn = 5;
  cRunNestedOuterWithLine = 59;
  cRunNestedOuterWithColumn = 3;
  cFixtureFiles: array[0..4] of string = (
    'NestedParentDefaultPointerWith.dproj',
    'NestedParentDefaultPointerWith.dpr',
    'NestedParentDefaultPointerWithUnit.pas',
    'NestedParentBoundTypeOwnerA.pas',
    'NestedParentBoundTypeOwnerB.pas');
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lBoundDeclaredId: string;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCachePath: string;
  lColdPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lCurrentIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFixtureHashes: TArray<string>;
  lImportedDeclaredId: string;
  lImportedBindingCount: Integer;
  lImportedSnapshotCount: Integer;
  lLegacyIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lOptions: TDelphiSemanticOptions;
  lOwnerDeclaredId: string;
  lOwnerSymbol: TDelphiSemanticInventorySymbol;
  lOwnerSymbolCount: Integer;
  lPlannedStatementCount: Integer;
  lRebuiltPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lResult: TDelphiSemanticProjectSessionResult;
  lSerializer: TJsonSerializer;
  lSnapshot: TDelphiProjectSnapshot;
  lSnapshotBinding: TSemanticRemoveWithBindingFact;
  lSnapshotBindingCount: Integer;
  lSnapshotOwnerSymbol: TSemanticRemoveWithInventorySymbolFact;
  lSnapshotOwnerSymbolCount: Integer;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lStatementCount: Integer;
  lTargetColumn: Integer;
  lTargetLine: Integer;
  lWarmPlan: TDelphiSemanticRemoveWithPlanBuildResult;
begin
  lBoundDeclaredId := '';
  lImportedDeclaredId := '';
  lOwnerDeclaredId := '';
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('WithBinder', cFixtureFiles[0]);
  lCachePath := ProjectSessionTempPath('legacy-parent-selector-facts.sqlite3');
  lOptions.SqliteCacheFileName := lCachePath;
  lOptions.SkipWithBindingSemanticGraph := True;
  SetLength(lFixtureHashes, Length(cFixtureFiles));
  for i := 0 to High(cFixtureFiles) do
    lFixtureHashes[i] := THashSHA2.GetHashStringFromFile(
      FixturePath('WithBinder', cFixtureFiles[i]));

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lColdPlan := lResult.Session.PlanRemoveWithResult;
  finally
    lResult.Session.Free;
  end;
  Assert.AreEqual(1, lColdPlan.SnapshotMetrics.SnapshotCacheProbes);
  Assert.AreEqual(1, lColdPlan.SnapshotMetrics.SnapshotCacheMisses);
  lCurrentIdentity := ReadProjectRemoveWithFactsIdentity(lCachePath);
  lLegacyIdentity := RekeyProjectRemoveWithFactsIdentityForTest(lCurrentIdentity,
    cLegacySchemaVersion);
  Assert.AreEqual(lCurrentIdentity.IdentityKey, lLegacyIdentity.IdentityKey);
  Assert.AreEqual(lCurrentIdentity.FileHash, lLegacyIdentity.FileHash);
  Assert.AreEqual(lCurrentIdentity.ContextHash, lLegacyIdentity.ContextHash);
  Assert.AreEqual(lCurrentIdentity.IncludeGraphHash, lLegacyIdentity.IncludeGraphHash);
  SeedLegacyParentSelectorFacts(lCachePath, lCurrentIdentity, lLegacyIdentity);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lRebuiltPlan := lResult.Session.PlanRemoveWithResult;
    Assert.AreEqual(1, lRebuiltPlan.SnapshotMetrics.SnapshotCacheProbes);
    Assert.AreEqual(0, lRebuiltPlan.SnapshotMetrics.SnapshotCacheHits,
      'Current project facts must not reuse the persisted v22 unresolved selector.');
    Assert.AreEqual(1, lRebuiltPlan.SnapshotMetrics.SnapshotCacheMisses);
    lFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  lBindingCount := 0;
  lImportedBindingCount := 0;
  lTargetLine := 0;
  lTargetColumn := 0;
  for lBinding in lFacts.Bindings do
  begin
    if SameText(ExtractFileName(lBinding.FileName), cFixtureFiles[4]) and
      SameText(lBinding.RoutineName, 'RunImportedBoundType') and
      SameText(lBinding.SelectorText, 'Maske[0]^') then
    begin
      Inc(lImportedBindingCount);
      Assert.AreEqual('NestedParentBoundTypeOwnerA',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      lImportedDeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
      Assert.IsTrue(lImportedDeclaredId <> '');
    end;
    if SameText(ExtractFileName(lBinding.FileName), cFixtureFiles[2]) and
      SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Inc(lBindingCount);
      Assert.AreEqual(cRunNestedInnerSelectorLine, lBinding.Line,
        'RunNested inner selector source line changed.');
      Assert.AreEqual(cRunNestedInnerSelectorColumn, lBinding.Column,
        'RunNested inner selector source column changed.');
      lTargetLine := lBinding.Line;
      lTargetColumn := lBinding.Column;
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('NestedParentDefaultPointerWithUnit',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      lBoundDeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
      Assert.IsTrue(lBoundDeclaredId <> '');
    end;
  end;
  Assert.AreEqual(1, lBindingCount, 'Expected one rebound nested selector.');
  Assert.AreEqual(1, lImportedBindingCount,
    'Expected one imported owner A selector despite caller owner B homonym.');
  lOwnerSymbolCount := 0;
  for lOwnerSymbol in lFacts.Symbols do
    if SameText(lOwnerSymbol.SymbolClass, 'member') and
      SameText(lOwnerSymbol.Name, 'Maske') and
      SameText(lOwnerSymbol.OwnerName, 'TDatFile') and
      SameText(lOwnerSymbol.UnitName, 'NestedParentBoundTypeOwnerA') then
    begin
      Inc(lOwnerSymbolCount);
      Assert.AreEqual('NestedParentBoundTypeOwnerA',
        lOwnerSymbol.OwnerIdentity.UnitName);
      Assert.AreEqual('TDatFile', lOwnerSymbol.OwnerIdentity.Name);
      Assert.AreEqual(cFixtureFiles[3],
        ExtractFileName(lOwnerSymbol.OwnerIdentity.SourceRange.FileName));
      Assert.IsTrue(lOwnerSymbol.OwnerIdentity.DeclaredId.Value <> '');
      lOwnerDeclaredId := lOwnerSymbol.OwnerIdentity.DeclaredId.Value;
    end;
  Assert.IsTrue(lOwnerSymbolCount > 0,
    'Direct facts must retain the imported Maske member declaring owner.');
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCachePath);
  try
    lSnapshot := nil;
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lCurrentIdentity,
      lSnapshot));
    try
      lSnapshotBindingCount := 0;
      lImportedSnapshotCount := 0;
      lSnapshotOwnerSymbolCount := 0;
      for i := 0 to lSnapshot.RemoveWithPlanningSymbolCount - 1 do
      begin
        lSnapshotOwnerSymbol := lSnapshot.RemoveWithPlanningSymbolByIndex(i);
        if SameText(lSnapshot.ExactTextOf(lSnapshotOwnerSymbol.SymbolClassId), 'member') and
          SameText(lSnapshot.ExactTextOf(lSnapshotOwnerSymbol.NameId), 'Maske') and
          SameText(lSnapshot.ExactTextOf(lSnapshotOwnerSymbol.OwnerNameId), 'TDatFile') and
          SameText(lSnapshot.ExactTextOf(lSnapshotOwnerSymbol.UnitNameId),
            'NestedParentBoundTypeOwnerA') then
        begin
          Inc(lSnapshotOwnerSymbolCount);
          Assert.AreEqual(lOwnerDeclaredId, lSnapshot.ExactTextOf(
            lSnapshotOwnerSymbol.OwnerIdentity.DeclaredIdId));
          Assert.AreEqual('NestedParentBoundTypeOwnerA', lSnapshot.ExactTextOf(
            lSnapshotOwnerSymbol.OwnerIdentity.UnitNameId));
          Assert.AreEqual(cFixtureFiles[3], ExtractFileName(lSnapshot.ExactTextOf(
            lSnapshotOwnerSymbol.OwnerIdentity.FileNameId)));
        end;
      end;
      Assert.IsTrue(lSnapshotOwnerSymbolCount > 0,
        'SQLite reload must retain the imported member declaring owner.');
      for i := 0 to lSnapshot.RemoveWithPlanningBindingCount - 1 do
      begin
        lSnapshotBinding := lSnapshot.RemoveWithPlanningBindingByIndex(i);
        if SameText(lSnapshot.ExactTextOf(lSnapshotBinding.RoutineNameId),
          'RunImportedBoundType') and
          SameText(lSnapshot.ExactTextOf(lSnapshotBinding.SelectorTextId),
          'Maske[0]^') then
        begin
          Inc(lImportedSnapshotCount);
          Assert.AreEqual(lImportedDeclaredId,
            lSnapshot.ExactTextOf(lSnapshotBinding.Selectors[1].TypeIdentity.DeclaredIdId));
          Assert.AreEqual('NestedParentBoundTypeOwnerA',
            lSnapshot.ExactTextOf(lSnapshotBinding.Selectors[1].TypeIdentity.UnitNameId));
        end;
        if SameText(lSnapshot.ExactTextOf(lSnapshotBinding.RoutineNameId),
          'RunNested') and
          SameText(lSnapshot.ExactTextOf(lSnapshotBinding.SelectorTextId),
          'Maske[i]^') then
        begin
          Inc(lSnapshotBindingCount);
          Assert.AreEqual(lBoundDeclaredId,
            lSnapshot.ExactTextOf(lSnapshotBinding.Selectors[1].TypeIdentity.DeclaredIdId));
          Assert.AreEqual('NestedParentDefaultPointerWithUnit',
            lSnapshot.ExactTextOf(lSnapshotBinding.Selectors[1].TypeIdentity.UnitNameId));
          Assert.AreEqual(cFixtureFiles[2], ExtractFileName(lSnapshot.ExactTextOf(
            lSnapshotBinding.Selectors[1].TypeIdentity.FileNameId)));
        end;
      end;
      Assert.AreEqual(1, lSnapshotBindingCount,
        'Fresh SQLite reload must retain the bound nested receiver declaration.');
      Assert.AreEqual(1, lImportedSnapshotCount,
        'SQLite reload must retain imported owner A despite the B homonym.');
    finally
      lSnapshot.Free;
    end;
  finally
    lCache.Free;
  end;
  // The rebound inner receiver is the unit's own TMaskEntry (the unit has no uses
  // clause, so the unimported OwnerA homonym cannot hide it). RunNested is therefore
  // one planned statement at the outer WITH; dcc64 compiled this exact rewrite.
  lStatementCount := 0;
  lPlannedStatementCount := 0;
  for lStatement in lRebuiltPlan.Plan.FinalStatements do
    if SameText(lStatement.RoutineName, 'RunNested') and
      SameText(ExtractFileName(lStatement.FileName), cFixtureFiles[2]) then
    begin
      if (lStatement.Range.StartLine = lTargetLine) and
        (lStatement.Range.StartColumn = lTargetColumn) then
        Inc(lStatementCount);
      if (lStatement.Range.StartLine = cRunNestedOuterWithLine) and
        (lStatement.Range.StartColumn = cRunNestedOuterWithColumn) then
      begin
        Inc(lPlannedStatementCount);
        Assert.AreEqual('planned', lStatement.Status,
          'A rebound selector must not retain the stale selector-type refusal.');
        Assert.AreEqual('', lStatement.Reason);
        Assert.AreEqual(2, Integer(Length(lStatement.Temps)));
        Assert.AreEqual('lWithDatFilePtr: ^TDatFile;',
          lStatement.Temps[0].DeclarationText);
        Assert.AreEqual('lWithDatFilePtr := @D;', lStatement.Temps[0].InitializationText);
        Assert.AreEqual('TMaskEntry', lStatement.Temps[1].ReceiverType);
        Assert.AreEqual('lWithMaskEntryPtr: ^TMaskEntry;',
          lStatement.Temps[1].DeclarationText);
        Assert.AreEqual('lWithMaskEntryPtr := @lWithDatFilePtr^.Maske[i]^;',
          lStatement.Temps[1].InitializationText);
      end;
    end;
  Assert.AreEqual(0, lStatementCount,
    'The rebound inner selector must not remain a separate refused statement.');
  Assert.AreEqual(1, lPlannedStatementCount,
    'Expected one planned RunNested statement at the outer WITH.');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lWarmPlan := lResult.Session.PlanRemoveWithResult;
  finally
    lResult.Session.Free;
  end;
  Assert.AreEqual(1, lWarmPlan.SnapshotMetrics.SnapshotCacheProbes);
  Assert.AreEqual(1, lWarmPlan.SnapshotMetrics.SnapshotCacheHits);
  Assert.AreEqual(0, lWarmPlan.SnapshotMetrics.SnapshotCacheMisses);
  lSerializer := TJsonSerializer.Create;
  try
    Assert.AreEqual(lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lColdPlan.Plan),
      lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lRebuiltPlan.Plan),
      'Rebound project facts must match the uncached current plan.');
    Assert.AreEqual(lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lRebuiltPlan.Plan),
      lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lWarmPlan.Plan),
      'Fresh warm project facts must preserve the rebound plan exactly.');
  finally
    lSerializer.Free;
  end;
  for i := 0 to High(cFixtureFiles) do
    Assert.AreEqual(lFixtureHashes[i], THashSHA2.GetHashStringFromFile(
      FixturePath('WithBinder', cFixtureFiles[i])),
      'The analyzed application input must remain byte-identical: ' + cFixtureFiles[i]);
end;

type
  TInheritedAccessRootAbsenceStub = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence)
  public
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

function TInheritedAccessRootAbsenceStub.EvidenceFingerprint: string;
begin
  Result := 'ds742-inherited-access-avalue-only';
end;

function TInheritedAccessRootAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Result := SameText(aName, 'aValue');
end;

procedure TProjectSessionTests.ProjectSessionPreservesInheritedAccessIdentityColdAndWarm;
var
  i: Integer;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCachePath: string;
  lColdPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lColdCount: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSnapshot: TDelphiProjectSnapshot;
  lSnapshotCount: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSnapshotSymbol: TSemanticRemoveWithInventorySymbolFact;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lPlannedCount: Integer;
  lVisibleCompetingCount: Integer;
  lWarmPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lWarmCount: Integer;
begin
  lRootPath := ProjectSessionTempPath('inherited-access-owner');
  TDirectory.CreateDirectory(lRootPath);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dpr'),
    'program P;'#13#10'uses AUnit, BUnit;'#13#10'begin end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="BaseUnit.pas"/>' +
    '<DCCReference Include="MidUnit.pas"/>' +
    '<DCCReference Include="AUnit.pas"/>' +
    '<DCCReference Include="BUnit.pas"/></ItemGroup></Project>');
  WriteTextFile(TPath.Combine(lRootPath, 'BaseUnit.pas'),
    'unit BaseUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TLeaf = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    '  TBase = class'#13#10'  public'#13#10'    Child: TLeaf;'#13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'MidUnit.pas'),
    'unit MidUnit;'#13#10'interface'#13#10'uses BaseUnit;'#13#10'type'#13#10 +
    '  TIntermediate = class(TBase) end;'#13#10 +
    'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'AUnit.pas'),
    'unit AUnit;'#13#10'interface'#13#10'uses BaseUnit, MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunA(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure RunA(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'begin'#13#10'  with aDerived do'#13#10'    with Child do'#13#10 +
    '      aValue := Value;'#13#10'end;'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'BUnit.pas'),
    'unit BUnit;'#13#10'interface'#13#10'uses BaseUnit, MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunB(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure RunB(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'begin'#13#10'  with aDerived do'#13#10'    with Child do'#13#10 +
    '      aValue := Value;'#13#10'end;'#13#10'end.'#13#10);
  lCachePath := TPath.Combine(lRootPath, 'semantic-cache.sqlite3');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lOptions.SqliteCacheFileName := lCachePath;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lColdPlan := lResult.Session.PlanRemoveWithResult;
    Assert.AreEqual(1, lColdPlan.SnapshotMetrics.SnapshotCacheMisses);
    lFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  lColdCount := 0;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.Name, 'Child') and
      SameText(lSymbol.SymbolClass, 'field') and
      SameText(lSymbol.OwnerName, 'TDerived') then
    begin
      Inc(lColdCount);
      Assert.AreEqual('BaseUnit', lSymbol.OwnerIdentity.UnitName);
      Assert.IsTrue(MatchText(lSymbol.AccessOwnerIdentity.UnitName, ['AUnit', 'BUnit']));
      Assert.AreEqual('TDerived', lSymbol.AccessOwnerIdentity.Name);
    end;
  Assert.AreEqual(2, lColdCount);
  lPlannedCount := 0;
  for lStatement in lColdPlan.Plan.FinalStatements do
    if MatchText(lStatement.RoutineName, ['RunA', 'RunB']) and
      (lStatement.Range.StartLine = 10) then
    begin
      Inc(lPlannedCount);
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
      Assert.AreEqual('', lStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
    end;
  Assert.AreEqual(2, lPlannedCount);
  lIdentity := ReadProjectRemoveWithFactsIdentity(lCachePath);
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCachePath);
  try
    lSnapshot := nil;
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lSnapshot));
    try
      lSnapshotCount := 0;
      for i := 0 to lSnapshot.RemoveWithPlanningSymbolCount - 1 do
      begin
        lSnapshotSymbol := lSnapshot.RemoveWithPlanningSymbolByIndex(i);
        if SameText(lSnapshot.ExactTextOf(lSnapshotSymbol.NameId), 'Child') and
          SameText(lSnapshot.ExactTextOf(lSnapshotSymbol.SymbolClassId), 'field') and
          SameText(lSnapshot.ExactTextOf(lSnapshotSymbol.OwnerNameId), 'TDerived') then
        begin
          Inc(lSnapshotCount);
          Assert.AreEqual('BaseUnit', lSnapshot.ExactTextOf(
            lSnapshotSymbol.OwnerIdentity.UnitNameId));
          Assert.IsTrue(MatchText(lSnapshot.ExactTextOf(
            lSnapshotSymbol.AccessOwnerIdentity.UnitNameId), ['AUnit', 'BUnit']));
        end;
      end;
      Assert.AreEqual(2, lSnapshotCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lCache.Free;
  end;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lWarmPlan := lResult.Session.PlanRemoveWithResult;
    Assert.AreEqual(1, lWarmPlan.SnapshotMetrics.SnapshotCacheHits);
    lFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  lWarmCount := 0;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.Name, 'Child') and
      SameText(lSymbol.SymbolClass, 'field') and
      SameText(lSymbol.OwnerName, 'TDerived') and
      MatchText(lSymbol.AccessOwnerIdentity.UnitName, ['AUnit', 'BUnit']) and
      SameText(lSymbol.OwnerIdentity.UnitName, 'BaseUnit') then
      Inc(lWarmCount);
  Assert.AreEqual(2, lWarmCount);
  lPlannedCount := 0;
  for lStatement in lWarmPlan.Plan.FinalStatements do
    if MatchText(lStatement.RoutineName, ['RunA', 'RunB']) and
      (lStatement.Range.StartLine = 10) then
    begin
      Inc(lPlannedCount);
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
      Assert.AreEqual('', lStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
    end;
  Assert.AreEqual(2, lPlannedCount);
  WriteTextFile(TPath.Combine(lRootPath, 'AUnit.pas'),
    StringReplace(TFile.ReadAllText(TPath.Combine(lRootPath, 'AUnit.pas')),
      'uses BaseUnit, MidUnit;', 'uses BaseUnit, MidUnit, BUnit;', []));
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lColdPlan := lResult.Session.PlanRemoveWithResult;
  finally
    lResult.Session.Free;
  end;
  lVisibleCompetingCount := 0;
  for lStatement in lColdPlan.Plan.FinalStatements do
    if SameText(lStatement.RoutineName, 'RunA') and
      (lStatement.Range.StartLine = 10) then
    begin
      Inc(lVisibleCompetingCount);
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('receiver-type-not-visible', lStatement.Reason);
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
    end;
  Assert.AreEqual(1, lVisibleCompetingCount);
end;

procedure TProjectSessionTests.ProjectSessionInheritedAccessWithRootProofPlans;
var
  lOptions: TDelphiSemanticOptions;
  lPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lStatementCount: Integer;
begin
  lRootPath := ProjectSessionTempPath('inherited-access-root-proof');
  TDirectory.CreateDirectory(lRootPath);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dpr'),
    'program P;'#13#10'uses AUnit, BUnit;'#13#10'begin end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="BaseUnit.pas"/>' +
    '<DCCReference Include="MidUnit.pas"/>' +
    '<DCCReference Include="AUnit.pas"/>' +
    '<DCCReference Include="BUnit.pas"/></ItemGroup></Project>');
  WriteTextFile(TPath.Combine(lRootPath, 'BaseUnit.pas'),
    'unit BaseUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TLeaf = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    '  TBase = class'#13#10'  public'#13#10'    Child: TLeaf;'#13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'MidUnit.pas'),
    'unit MidUnit;'#13#10'interface'#13#10'uses BaseUnit;'#13#10'type'#13#10 +
    '  TIntermediate = class(TBase) end;'#13#10 +
    'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'AUnit.pas'),
    'unit AUnit;'#13#10'interface'#13#10'uses BaseUnit, MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunA(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure RunA(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'begin'#13#10'  with aDerived do'#13#10'    with Child do'#13#10 +
    '      aValue := Value;'#13#10'end;'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'BUnit.pas'),
    'unit BUnit;'#13#10'interface'#13#10'uses BaseUnit, MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunB(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure RunB(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'begin'#13#10'  with aDerived do'#13#10'    with Child do'#13#10 +
    '      aValue := Value;'#13#10'end;'#13#10'end.'#13#10);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lOptions.ImplicitRootMemberAbsence := TInheritedAccessRootAbsenceStub.Create;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lPlan := lResult.Session.PlanRemoveWithResult;
  finally
    lResult.Session.Free;
  end;
  lStatementCount := 0;
  for lStatement in lPlan.Plan.FinalStatements do
    if MatchText(lStatement.RoutineName, ['RunA', 'RunB']) and
      (lStatement.Range.StartLine = 10) then
    begin
      Inc(lStatementCount);
      Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
      Assert.AreEqual(2, Integer(Length(lStatement.Temps)));
      Assert.AreEqual('  lWithDerived := aDerived;'#13#10 +
        '      begin'#13#10 +
        '      lWithLeafPtr := @lWithDerived.Child;'#13#10 +
        '      aValue := lWithLeafPtr^.Value;'#13#10 +
        '    end;', lStatement.ReplacementText);
    end;
  Assert.AreEqual(2, lStatementCount);
end;

procedure TProjectSessionTests.ProjectSessionInheritedAccessWithoutRootProofRefuses;
var
  lCachePath: string;
  lOptions: TDelphiSemanticOptions;
  lPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lStatementCount: Integer;
begin
  lRootPath := ProjectSessionTempPath('inherited-access-no-root-proof');
  TDirectory.CreateDirectory(lRootPath);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dpr'),
    'program P;'#13#10'uses AUnit, BUnit;'#13#10'begin end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dproj'),
    '<Project><PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="BaseUnit.pas"/>' +
    '<DCCReference Include="MidUnit.pas"/>' +
    '<DCCReference Include="AUnit.pas"/>' +
    '<DCCReference Include="BUnit.pas"/></ItemGroup></Project>');
  WriteTextFile(TPath.Combine(lRootPath, 'BaseUnit.pas'),
    'unit BaseUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TLeaf = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    '  TBase = class'#13#10'  public'#13#10'    Child: TLeaf;'#13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'MidUnit.pas'),
    'unit MidUnit;'#13#10'interface'#13#10'uses BaseUnit;'#13#10'type'#13#10 +
    '  TIntermediate = class(TBase) end;'#13#10 +
    'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'AUnit.pas'),
    'unit AUnit;'#13#10'interface'#13#10'uses BaseUnit, MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunA(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure RunA(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'begin'#13#10'  with aDerived do'#13#10'    with Child do'#13#10 +
    '      aValue := Value;'#13#10'end;'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'BUnit.pas'),
    'unit BUnit;'#13#10'interface'#13#10'uses BaseUnit, MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunB(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure RunB(aDerived: TDerived; var aValue: Integer);'#13#10 +
    'begin'#13#10'  with aDerived do'#13#10'    with Child do'#13#10 +
    '      aValue := Value;'#13#10'end;'#13#10'end.'#13#10);
  lCachePath := TPath.Combine(lRootPath, 'semantic-cache.sqlite3');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lOptions.SqliteCacheFileName := lCachePath;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lPlan := lResult.Session.PlanRemoveWithResult;
  finally
    lResult.Session.Free;
  end;
  lStatementCount := 0;
  for lStatement in lPlan.Plan.FinalStatements do
    if MatchText(lStatement.RoutineName, ['RunA', 'RunB']) and
      (lStatement.Range.StartLine = 10) then
    begin
      Inc(lStatementCount);
      Assert.AreEqual('skipped', lStatement.Status);
      Assert.AreEqual('receiver-member-not-found', lStatement.Reason);
      Assert.AreEqual('OWNER_INHERITED_MEMBERS_UNVERIFIED', lStatement.SafetyReason);
      Assert.AreEqual('', lStatement.ReplacementText);
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)));
    end;
  Assert.AreEqual(2, lStatementCount);
end;

type
  TNearestRootAbsenceStub = class(TInterfacedObject, IDelphiSemanticImplicitRootMemberAbsence)
  public
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
  end;

function TNearestRootAbsenceStub.EvidenceFingerprint: string;
begin
  Result := 'ds715-exact-lNearest-root-absence';
end;

function TNearestRootAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Result := SameText(aName, 'lNearest');
end;

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithInvalidatesLegacySimpleInheritedChildFacts;
const
  cLegacySchemaVersion = 'project-session-remove-with-facts-v26';
  cFixtureFiles: array[0..5] of string = (
    'P.dproj', 'P.dpr', 'BaseUnit.pas', 'MidUnit.pas', 'AUnit.pas', 'BUnit.pas');
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCachePath: string;
  lColdPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lCurrentIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFixtureHashes: TArray<string>;
  lGuid: TGUID;
  lLegacyIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lOptions: TDelphiSemanticOptions;
  lProofOptions: TDelphiSemanticOptions;
  lProofPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lRebuiltPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lRunAColumn: Integer;
  lRunADeclaredId: string;
  lRunALine: Integer;
  lRunACount: Integer;
  lNearestCount: Integer;
  lOtherUnitCount: Integer;
  lSnapshot: TDelphiProjectSnapshot;
  lSnapshotBinding: TSemanticRemoveWithBindingFact;
  lSnapshotCount: Integer;
  lUnknownColumn: Integer;
  lUnknownCount: Integer;
  lUnknownLine: Integer;
  lUnknownReason: string;
  lWarmPlan: TDelphiSemanticRemoveWithPlanBuildResult;

  procedure AssertPlanDecisions(const aPlan: TDelphiSemanticRemoveWithPlan;
    const aNearestStatus: string);
  var
    lInheritedCount: Integer;
    lNearestCount: Integer;
    lStatement: TDelphiSemanticRemoveWithFinalStatement;
  begin
    lInheritedCount := 0;
    lNearestCount := 0;
    for lStatement in aPlan.FinalStatements do
    begin
      // Each fixture routine starts its outer WITH at column 7; refused nested statements have separate rows.
      if lStatement.Range.StartColumn <> 7 then
        Continue;
      if SameText(lStatement.RoutineName, 'RunA') or SameText(lStatement.RoutineName, 'RunB') then
      begin
        Inc(lInheritedCount);
        // TLeaf is not visible through AUnit/BUnit's direct uses; facts remain resolved but capture stays refused.
        Assert.AreEqual('skipped', lStatement.Status,
          lStatement.RoutineName + ': ' + lStatement.Reason + '; ' + lStatement.SafetyReason);
        Assert.AreEqual('receiver-type-not-visible', lStatement.Reason);
        Assert.AreEqual('', lStatement.ReplacementText);
      end else if SameText(lStatement.RoutineName, 'RunNearest') then
      begin
        Inc(lNearestCount);
        Assert.AreEqual(aNearestStatus, lStatement.Status,
          lStatement.RoutineName + ': ' + lStatement.Reason + '; ' + lStatement.SafetyReason);
        if aNearestStatus = 'planned' then
          Assert.IsTrue(Pos('.OtherValue', lStatement.ReplacementText) > 0,
            lStatement.ReplacementText)
        else
          Assert.AreEqual('', lStatement.ReplacementText);
      end;
    end;
    Assert.AreEqual(2, lInheritedCount);
    Assert.AreEqual(1, lNearestCount);
  end;

  procedure AssertChildFacts(const aFacts: TDelphiSemanticProjectWithBindingFacts;
    const aNearestStatus: string);
  var
    lBinding: TDelphiSemanticWithBinding;
  begin
    lRunACount := 0;
    lNearestCount := 0;
    lOtherUnitCount := 0;
    lUnknownCount := 0;
    for lBinding in aFacts.Bindings do
      if SameText(lBinding.SelectorText, 'Child') then
      begin
        if SameText(lBinding.UnitName, 'AUnit') and
          SameText(lBinding.RoutineName, 'RunA') then
        begin
          Inc(lRunACount);
          Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
          Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
            lBinding.Selectors[1].ReasonCode);
          Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeName);
          Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
          Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
          Assert.AreEqual(TPath.Combine(lRootPath, 'BaseUnit.pas'),
            lBinding.Selectors[1].TypeIdentity.SourceRange.FileName);
          Assert.AreEqual(lRunADeclaredId,
            lBinding.Selectors[1].TypeIdentity.DeclaredId.Value);
          Assert.AreEqual(lRunALine, lBinding.Line);
          Assert.AreEqual(lRunAColumn, lBinding.Column);
        end else if SameText(lBinding.UnitName, 'BUnit') and
          SameText(lBinding.RoutineName, 'RunB') then
        begin
          Inc(lOtherUnitCount);
          Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
          Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
          Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
          Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
          Assert.AreEqual(lRunADeclaredId, lBinding.Selectors[1].TypeIdentity.DeclaredId.Value);
          Assert.AreEqual(TPath.Combine(lRootPath, 'BaseUnit.pas'),
            lBinding.Selectors[1].TypeIdentity.SourceRange.FileName);
        end else if SameText(lBinding.UnitName, 'AUnit') and
          SameText(lBinding.RoutineName, 'RunNearest') then
        begin
          Inc(lNearestCount);
          Assert.AreEqual(3, Integer(Length(lBinding.Selectors)));
          Assert.AreEqual(aNearestStatus, lBinding.Selectors[2].Status);
          if aNearestStatus = 'resolved' then
          begin
            Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
            Assert.AreEqual('TNearest', lBinding.Selectors[1].TypeName);
            Assert.AreEqual('AUnit', lBinding.Selectors[2].TypeIdentity.UnitName);
            Assert.AreEqual('TWrongLeaf', lBinding.Selectors[2].TypeIdentity.Name);
            Assert.IsTrue(lBinding.Selectors[2].TypeIdentity.DeclaredId.Value <> '');
            Assert.AreEqual(TPath.Combine(lRootPath, 'AUnit.pas'),
              lBinding.Selectors[2].TypeIdentity.SourceRange.FileName);
          end else begin
            Assert.AreEqual('unsupported', lBinding.Selectors[1].Status);
            Assert.AreEqual('PARENT_SELECTOR_UNRESOLVED', lBinding.Selectors[1].ReasonCode);
          end;
        end else if SameText(lBinding.UnitName, 'AUnit') and
          SameText(lBinding.RoutineName, 'RunUnknown') then
        begin
          Inc(lUnknownCount);
          Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
          Assert.AreNotEqual('resolved', lBinding.Selectors[0].Status);
          Assert.AreNotEqual('resolved', lBinding.Selectors[1].Status,
            'Unknown parent must not borrow the global Child namesake.');
          Assert.AreEqual(lUnknownReason, lBinding.Selectors[1].ReasonCode);
          Assert.AreEqual(lUnknownLine, lBinding.Line);
          Assert.AreEqual(lUnknownColumn, lBinding.Column);
        end;
      end;
    Assert.AreEqual(1, lRunACount);
    Assert.AreEqual(1, lOtherUnitCount);
    Assert.AreEqual(1, lNearestCount);
    Assert.AreEqual(1, lUnknownCount);
  end;

  procedure AssertSnapshotChild(const aSnapshot: TDelphiProjectSnapshot;
    const aExpectStale: Boolean);
  var
    i: Integer;
  begin
    lSnapshotCount := 0;
    for i := 0 to aSnapshot.RemoveWithPlanningBindingCount - 1 do
    begin
      lSnapshotBinding := aSnapshot.RemoveWithPlanningBindingByIndex(i);
      if SameText(aSnapshot.ExactTextOf(lSnapshotBinding.FileNameId),
        TPath.Combine(lRootPath, 'AUnit.pas')) and
        SameText(aSnapshot.ExactTextOf(lSnapshotBinding.RoutineNameId), 'RunA') and
        SameText(aSnapshot.ExactTextOf(lSnapshotBinding.SelectorTextId), 'Child') and
        (lSnapshotBinding.Line = lRunALine) and
        (lSnapshotBinding.Column = lRunAColumn) then
      begin
        Inc(lSnapshotCount);
        Assert.AreEqual(2, Integer(Length(lSnapshotBinding.Selectors)));
        if aExpectStale then
        begin
          Assert.AreNotEqual('resolved', aSnapshot.ExactTextOf(
            lSnapshotBinding.Selectors[1].StatusId));
          Assert.AreEqual(lUnknownReason, aSnapshot.ExactTextOf(
            lSnapshotBinding.Selectors[1].ReasonCodeId));
          Assert.AreEqual(0, Integer(
            lSnapshotBinding.Selectors[1].TypeIdentity.DeclaredIdId));
        end else
        begin
          Assert.AreEqual('resolved', aSnapshot.ExactTextOf(
            lSnapshotBinding.Selectors[1].StatusId));
          Assert.AreEqual('BaseUnit', aSnapshot.ExactTextOf(
            lSnapshotBinding.Selectors[1].TypeIdentity.UnitNameId));
          Assert.AreEqual(lRunADeclaredId, aSnapshot.ExactTextOf(
            lSnapshotBinding.Selectors[1].TypeIdentity.DeclaredIdId));
          Assert.AreEqual(TPath.Combine(lRootPath, 'BaseUnit.pas'),
            aSnapshot.ExactTextOf(
              lSnapshotBinding.Selectors[1].TypeIdentity.FileNameId));
        end;
      end;
    end;
    Assert.AreEqual(1, lSnapshotCount);
  end;
begin
  CreateGUID(lGuid);
  lRootPath := ProjectSessionTempPath('simple-inherited-child-' +
    GUIDToString(lGuid));
  TDirectory.CreateDirectory(lRootPath);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dpr'),
    'program P;'#13#10'uses AUnit in ''AUnit.pas'', BUnit in ''BUnit.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'P.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="BaseUnit.pas"/><DCCReference Include="MidUnit.pas"/>' +
    '<DCCReference Include="AUnit.pas"/><DCCReference Include="BUnit.pas"/>' +
    '</ItemGroup></Project>');
  WriteTextFile(TPath.Combine(lRootPath, 'BaseUnit.pas'),
    'unit BaseUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TLeaf = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    '  TBase = class'#13#10'  public'#13#10'    Child: TLeaf;'#13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'MidUnit.pas'),
    'unit MidUnit;'#13#10'interface'#13#10'uses BaseUnit;'#13#10'type'#13#10 +
    '  TIntermediate = class(TBase) end;'#13#10 +
    'implementation'#13#10'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'AUnit.pas'),
    'unit AUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    '  TWrongLeaf = record OtherValue: Integer; end;'#13#10 +
    '  TGlobalLeaf = record GlobalValue: Integer; end;'#13#10 +
    '  TNearest = record Child: TWrongLeaf; end;'#13#10 +
    'var'#13#10'  Child: TGlobalLeaf;'#13#10 +
    'procedure RunA;'#13#10'procedure RunNearest;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'implementation'#13#10 +
    'procedure RunA;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 1; end;'#13#10 +
    'procedure RunNearest;'#13#10 +
    'var'#13#10'  lDerived: TDerived;'#13#10 +
    '  lNearest: TNearest;'#13#10 +
    'begin with lDerived do with lNearest do with Child do OtherValue := 1; end;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'begin with Missing do with Child do Value := 1; end;'#13#10 +
    'end.'#13#10);
  WriteTextFile(TPath.Combine(lRootPath, 'BUnit.pas'),
    'unit BUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunB;'#13#10'implementation'#13#10 +
    'procedure RunB;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 2; end;'#13#10 +
    'end.'#13#10);
  SetLength(lFixtureHashes, Length(cFixtureFiles));
  for i := 0 to High(cFixtureFiles) do
    lFixtureHashes[i] := THashSHA2.GetHashStringFromFile(
      TPath.Combine(lRootPath, cFixtureFiles[i]));
  lCachePath := TPath.Combine(lRootPath, 'semantic-cache.sqlite3');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'P.dproj');
  lOptions.SqliteCacheFileName := lCachePath;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lColdPlan := lResult.Session.PlanRemoveWithResult;
    AssertPlanDecisions(lColdPlan.Plan, 'skipped');
    Assert.AreEqual(1, lColdPlan.SnapshotMetrics.SnapshotCacheMisses);
    lFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  lRunAColumn := 0;
  lRunALine := 0;
  lRunADeclaredId := '';
  lUnknownColumn := 0;
  lUnknownLine := 0;
  lUnknownReason := '';
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'AUnit') and
      SameText(lBinding.SelectorText, 'Child') then
    begin
      if SameText(lBinding.RoutineName, 'RunA') then
      begin
        lRunADeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
        lRunALine := lBinding.Line;
        lRunAColumn := lBinding.Column;
      end else if SameText(lBinding.RoutineName, 'RunUnknown') then
      begin
        lUnknownReason := lBinding.Selectors[1].ReasonCode;
        lUnknownLine := lBinding.Line;
        lUnknownColumn := lBinding.Column;
      end;
    end;
  Assert.IsTrue(lRunADeclaredId <> '', 'Expected source-backed BaseUnit leaf identity.');
  Assert.IsTrue(lUnknownReason <> '', 'Expected source-backed unknown-parent reason.');
  AssertChildFacts(lFacts, 'unsupported');
  lCurrentIdentity := ReadProjectRemoveWithFactsIdentity(lCachePath);
  lLegacyIdentity := RekeyProjectRemoveWithFactsIdentityForTest(lCurrentIdentity,
    cLegacySchemaVersion);
  Assert.AreEqual(lCurrentIdentity.IdentityKey, lLegacyIdentity.IdentityKey);
  Assert.AreEqual(lCurrentIdentity.FileHash, lLegacyIdentity.FileHash);
  Assert.AreEqual(lCurrentIdentity.ContextHash, lLegacyIdentity.ContextHash);
  Assert.AreEqual(lCurrentIdentity.IncludeGraphHash, lLegacyIdentity.IncludeGraphHash);
  Assert.AreNotEqual(lCurrentIdentity.CacheKey, lLegacyIdentity.CacheKey);
  SeedLegacySimpleInheritedChildFacts(lCachePath, lCurrentIdentity,
    lLegacyIdentity, TPath.Combine(lRootPath, 'AUnit.pas'), lRunALine,
    lRunAColumn, lUnknownLine, lUnknownColumn);
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCachePath);
  try
    lSnapshot := nil;
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(
      lLegacyIdentity, lSnapshot), 'The stale v26 facts must be loadable.');
    try
      AssertSnapshotChild(lSnapshot, True);
    finally
      lSnapshot.Free;
    end;
    lSnapshot := nil;
    Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(
      lCurrentIdentity, lSnapshot), 'The current key must not hit v26 facts.');
    lSnapshot.Free;
  finally
    lCache.Free;
  end;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lRebuiltPlan := lResult.Session.PlanRemoveWithResult;
    AssertPlanDecisions(lRebuiltPlan.Plan, 'skipped');
    Assert.AreEqual(1, lRebuiltPlan.SnapshotMetrics.SnapshotCacheProbes);
    Assert.AreEqual(0, lRebuiltPlan.SnapshotMetrics.SnapshotCacheHits);
    Assert.AreEqual(1, lRebuiltPlan.SnapshotMetrics.SnapshotCacheMisses);
    lFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  AssertChildFacts(lFacts, 'unsupported');
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCachePath);
  try
    lSnapshot := nil;
    Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(
      lCurrentIdentity, lSnapshot));
    try
      AssertSnapshotChild(lSnapshot, False);
    finally
      lSnapshot.Free;
    end;
  finally
    lCache.Free;
  end;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lWarmPlan := lResult.Session.PlanRemoveWithResult;
    AssertPlanDecisions(lWarmPlan.Plan, 'skipped');
    Assert.AreEqual(1, lWarmPlan.SnapshotMetrics.SnapshotCacheProbes);
    Assert.AreEqual(1, lWarmPlan.SnapshotMetrics.SnapshotCacheHits);
    Assert.AreEqual(0, lWarmPlan.SnapshotMetrics.SnapshotCacheMisses);
    lFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  AssertChildFacts(lFacts, 'unsupported');
  // DS-715: keep the default-session cache proof above separate from optional evidence.
  lProofOptions := lOptions;
  lProofOptions.ImplicitRootMemberAbsence := TNearestRootAbsenceStub.Create;
  lResult := TDelphiSemanticProjectSession.Open(lProofOptions);
  try
    Assert.IsTrue(lResult.Success);
    lProofPlan := lResult.Session.PlanRemoveWithResult;
    AssertPlanDecisions(lProofPlan.Plan, 'planned');
    lFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  // Declaration IDs are scoped by compiler/proof context; compare A/B within this session.
  lRunADeclaredId := '';
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'AUnit') and SameText(lBinding.RoutineName, 'RunA') then
      lRunADeclaredId := lBinding.Selectors[High(lBinding.Selectors)].TypeIdentity.DeclaredId.Value;
  Assert.IsTrue(lRunADeclaredId <> '', 'Expected a source-backed leaf identity in the proof context.');
  AssertChildFacts(lFacts, 'resolved');
  for i := 0 to High(cFixtureFiles) do
    Assert.AreEqual(lFixtureHashes[i], THashSHA2.GetHashStringFromFile(
      TPath.Combine(lRootPath, cFixtureFiles[i])),
      'The generated project sources must remain unchanged.');
end;

function VerifyLegacyReceiverSafetyFactsMiss(const aLegacySchemaVersion: string): string;
// The legacy rows are a controlled rekey of rows that the current producer wrote,
// with the stale MEMBERS_INCOMPLETE refusal injected. They stand in for an older
// producer; they are not a database written by one. Returns the schema version of
// the current rows, which the warm open hits.
const
  cFixtureFiles: array[0..3] of string = (
    'ReceiverSafetyHidden.pas', 'ReceiverSafetyAlias.pas',
    'ReceiverSafetyOwner.pas', 'ReceiverSafetyCaller.pas');
var
  i: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lCachePath: string;
  lColdFacts: TDelphiSemanticProjectWithBindingFacts;
  lColdPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lCurrentIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lFixtureHashes: TArray<string>;
  lLegacyIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLegacyPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lOptions: TDelphiSemanticOptions;
  lProjectHash: string;
  lRebuiltPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lResult: TDelphiSemanticProjectSessionResult;
  lRootPath: string;
  lSerializer: TJsonSerializer;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lTargetCount: Integer;
  lWarmPlan: TDelphiSemanticRemoveWithPlanBuildResult;
begin
  lRootPath := ProjectSessionTempPath('legacy-receiver-safety-facts-' + aLegacySchemaVersion);
  TDirectory.CreateDirectory(lRootPath);
  SetLength(lFixtureHashes, Length(cFixtureFiles));
  for i := 0 to High(cFixtureFiles) do
  begin
    lFixtureHashes[i] := THashSHA2.GetHashStringFromFile(
      FixturePath('WithBinder\ReceiverSafetyIdentity', cFixtureFiles[i]));
    TFile.Copy(FixturePath('WithBinder\ReceiverSafetyIdentity', cFixtureFiles[i]),
      TPath.Combine(lRootPath, cFixtureFiles[i]), True);
  end;
  WriteTextFile(TPath.Combine(lRootPath, 'ReceiverSafetyFacts.dpr'),
    'program ReceiverSafetyFacts;' + sLineBreak +
    'uses ReceiverSafetyCaller;' + sLineBreak + 'begin end.');
  WriteTextFile(TPath.Combine(lRootPath, 'ReceiverSafetyFacts.dproj'),
    '<Project><PropertyGroup><MainSource>ReceiverSafetyFacts.dpr</MainSource>' +
    '</PropertyGroup><ItemGroup>' +
    '<DCCReference Include="ReceiverSafetyHidden.pas"/>' +
    '<DCCReference Include="ReceiverSafetyAlias.pas"/>' +
    '<DCCReference Include="ReceiverSafetyOwner.pas"/>' +
    '<DCCReference Include="ReceiverSafetyCaller.pas"/>' +
    '</ItemGroup></Project>');
  lCachePath := TPath.Combine(lRootPath, 'semantic-cache.sqlite3');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRootPath, 'ReceiverSafetyFacts.dproj');
  lOptions.SqliteCacheFileName := lCachePath;
  lOptions.SkipWithBindingSemanticGraph := True;
  lProjectHash := THashSHA2.GetHashStringFromFile(lOptions.ProjectPath);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lColdPlan := lResult.Session.PlanRemoveWithResult;
    lColdFacts := lResult.Session.BuildWithBindingFacts;
  finally
    lResult.Session.Free;
  end;
  Assert.AreEqual(1, lColdPlan.SnapshotMetrics.SnapshotCacheProbes);
  Assert.AreEqual(1, lColdPlan.SnapshotMetrics.SnapshotCacheMisses);
  lTargetCount := 0;
  for lBinding in lColdFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName), cFixtureFiles[3]) and
      SameText(lBinding.RoutineName, 'Run') and
      SameText(lBinding.SelectorText, 'Item^') then
    begin
      Inc(lTargetCount);
      Assert.AreEqual(22, lBinding.Line);
      Assert.AreEqual(5, lBinding.Column);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('THiddenEntry', lBinding.Selectors[1].TypeName);
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason);
    end;
  Assert.AreEqual(1, lTargetCount, 'Expected the cold hidden receiver fact.');
  lCurrentIdentity := ReadProjectRemoveWithFactsIdentity(lCachePath);
  lLegacyIdentity := RekeyProjectRemoveWithFactsIdentityForTest(lCurrentIdentity,
    aLegacySchemaVersion);
  Assert.AreEqual(lCurrentIdentity.IdentityKey, lLegacyIdentity.IdentityKey);
  Assert.AreEqual(lCurrentIdentity.FileHash, lLegacyIdentity.FileHash);
  Assert.AreEqual(lCurrentIdentity.ContextHash, lLegacyIdentity.ContextHash);
  Assert.AreEqual(lCurrentIdentity.IncludeGraphHash, lLegacyIdentity.IncludeGraphHash);
  SeedLegacyReceiverSafetyFacts(lCachePath, lCurrentIdentity, lLegacyIdentity);

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lLegacyPlan := lResult.Session.PlanRemoveWithResult;
  finally
    lResult.Session.Free;
  end;
  if lLegacyPlan.SnapshotMetrics.SnapshotCacheHits = 1 then
  begin
    lTargetCount := 0;
    for lStatement in lLegacyPlan.Plan.FinalStatements do
      if SameText(ExtractFileName(lStatement.FileName), cFixtureFiles[3]) and
        SameText(lStatement.RoutineName, 'Run') and
        (lStatement.Range.StartLine = 22) then
      begin
        Inc(lTargetCount);
        Assert.AreEqual('skipped', lStatement.Status);
        Assert.AreEqual('members-incomplete', lStatement.Reason);
        Assert.AreEqual('MEMBERS_INCOMPLETE', lStatement.SafetyReason,
          'A matching controlled ' + aLegacySchemaVersion +
          ' row must expose the stale refusal.');
        Assert.AreEqual(0, Integer(Length(lStatement.Edits)));
      end;
    Assert.AreEqual(1, lTargetCount, 'Expected one nested hidden receiver.');
  end;
  Assert.AreEqual(0, lLegacyPlan.SnapshotMetrics.SnapshotCacheHits,
    'Corrected receiver safety must not consume a controlled stale ' +
    aLegacySchemaVersion + ' row.');
  Assert.AreEqual(1, lLegacyPlan.SnapshotMetrics.SnapshotCacheMisses);
  Assert.AreNotEqual(aLegacySchemaVersion, lCurrentIdentity.SchemaVersion,
    'The current producer must not write rows under the legacy identity.');
  Assert.AreNotEqual(lCurrentIdentity.CacheKey, lLegacyIdentity.CacheKey);
  lRebuiltPlan := lLegacyPlan;
  lTargetCount := 0;
  for lStatement in lRebuiltPlan.Plan.FinalStatements do
    if SameText(ExtractFileName(lStatement.FileName), cFixtureFiles[3]) and
      SameText(lStatement.RoutineName, 'Run') and
      (lStatement.Range.StartLine = 22) then
    begin
      Inc(lTargetCount);
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lStatement.SafetyReason,
        'A rebuilt complete hidden receiver must lose the stale refusal.');
    end;
  Assert.AreEqual(1, lTargetCount, 'Expected one rebuilt hidden receiver.');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lWarmPlan := lResult.Session.PlanRemoveWithResult;
  finally
    lResult.Session.Free;
  end;
  Assert.AreEqual(1, lWarmPlan.SnapshotMetrics.SnapshotCacheProbes);
  Assert.AreEqual(1, lWarmPlan.SnapshotMetrics.SnapshotCacheHits);
  Assert.AreEqual(0, lWarmPlan.SnapshotMetrics.SnapshotCacheMisses);
  lSerializer := TJsonSerializer.Create;
  try
    Assert.AreEqual(lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lColdPlan.Plan),
      lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lRebuiltPlan.Plan),
      'Cold and rebuilt plans must agree for the current producer.');
    Assert.AreEqual(lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lRebuiltPlan.Plan),
      lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lWarmPlan.Plan),
      'New warm facts must preserve the rebuilt plan exactly.');
  finally
    lSerializer.Free;
  end;
  for i := 0 to High(cFixtureFiles) do
  begin
    Assert.AreEqual(lFixtureHashes[i], THashSHA2.GetHashStringFromFile(
      FixturePath('WithBinder\ReceiverSafetyIdentity', cFixtureFiles[i])),
      'The original receiver fixture must remain byte-identical.');
    Assert.AreEqual(lFixtureHashes[i], THashSHA2.GetHashStringFromFile(
      TPath.Combine(lRootPath, cFixtureFiles[i])),
      'The test-local receiver input must remain byte-identical.');
  end;
  Assert.AreEqual(lProjectHash, THashSHA2.GetHashStringFromFile(lOptions.ProjectPath),
    'The test-local project input must remain byte-identical.');
  Result := lCurrentIdentity.SchemaVersion;
end;

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithInvalidatesPreArrayAliasV32Facts;
begin
  // DS-709: array-prefixed pointer aliases change persisted receiver bindings.
  Assert.AreNotEqual('project-session-remove-with-facts-v32',
    VerifyLegacyReceiverSafetyFactsMiss('project-session-remove-with-facts-v32'));
end;

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithInvalidatesPreQualifiedV31Facts;
begin
  // DS-709: qualified components and compiler-active bodies change stored bindings.
  Assert.AreNotEqual('project-session-remove-with-facts-v31',
    VerifyLegacyReceiverSafetyFactsMiss('project-session-remove-with-facts-v31'));
end;

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithInvalidatesPreIntrinsicV30Facts;
begin
  // DS-709: compiler routine fallback changes persisted WITH classifications.
  // Reject v30 facts, rebuild once, then reuse the fresh facts on the warm query.
  Assert.AreNotEqual('project-session-remove-with-facts-v30',
    VerifyLegacyReceiverSafetyFactsMiss('project-session-remove-with-facts-v30'));
end;

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithInvalidatesLegacyReceiverSafetyFacts;
begin
  Assert.AreNotEqual('project-session-remove-with-facts-v23',
    VerifyLegacyReceiverSafetyFactsMiss('project-session-remove-with-facts-v23'));
end;

procedure TProjectSessionTests.ProjectSessionPlanRemoveWithInvalidatesPreCorrectionV29ReceiverSafetyFacts;
begin
  // DS-682: v29 rows predate the corrected receiver-safety lineage (DS-681), so the
  // current identity must not match them; current rows must still hit warm.
  Assert.AreNotEqual('project-session-remove-with-facts-v29',
    VerifyLegacyReceiverSafetyFactsMiss('project-session-remove-with-facts-v29'));
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
    lFirstSnapshot := BuildSnapshotWithMetrics(lFirstResult.Session, lFirstMetrics);
    try
      Assert.AreEqual(1, lFirstSnapshot.UnitCount);
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
    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, lMetrics);
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
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
    lFirstSnapshot := BuildSnapshotWithMetrics(lFirstResult.Session, lFirstMetrics);
    try
      Assert.AreEqual(2, lFirstSnapshot.UnitCount);
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
    lSecondSnapshot := BuildSnapshotWithMetrics(lResult.Session, lSecondMetrics);
    try
      Assert.AreEqual(2, lSecondSnapshot.UnitCount);
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
    lThirdSnapshot := BuildSnapshotWithMetrics(lResult.Session, lThirdMetrics);
    try
      Assert.AreEqual(2, lThirdSnapshot.UnitCount);
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

    lSecondSnapshot := BuildSnapshotWithMetrics(lResult.Session, lSecondMetrics);
    try
      Assert.AreEqual(2, lSecondSnapshot.UnitCount);
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
    lSnapshot := BuildSnapshotWithMetrics(lFirstResult.Session, lFirstMetrics);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
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
    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, lSecondMetrics);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
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
    lSnapshot := BuildSnapshotWithMetrics(lFirstResult.Session, lFirstMetrics);
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
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
    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, lSecondMetrics);
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
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

procedure TProjectSessionTests.ProjectSessionPartialSnapshotCacheFullyAnalyzesOnlyMissedUnits;
var
  lBuildBody: string;
  lBuildEnd: Integer;
  lBuildStart: Integer;
  lPartialBranch: string;
  lPartialEnd: Integer;
  lPartialStart: Integer;
  lSource: string;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.ProjectSession.pas');
  lBuildStart := Pos('function TDelphiSemanticProjectSession.BuildSnapshot(' +
    sLineBreak + '  const aScopedSourceFileNames', lSource);
  Assert.IsTrue(lBuildStart > 0, 'Expected scoped BuildSnapshot implementation.');
  lBuildEnd := PosEx('function TDelphiSemanticProjectSession.BuildWithBindingFacts',
    lSource, lBuildStart);
  Assert.IsTrue(lBuildEnd > lBuildStart,
    'Expected BuildSnapshot implementation to end before BuildWithBindingFacts.');
  lBuildBody := Copy(lSource, lBuildStart, lBuildEnd - lBuildStart);

  lPartialStart := PosEx('if lCacheHadPartialHit then', lBuildBody);
  Assert.IsTrue(lPartialStart > 0, 'Expected partial snapshot cache branch.');
  lPartialEnd := PosEx('lExtraction := ExtractProjectModels', lBuildBody,
    lPartialStart);
  Assert.IsTrue(lPartialEnd > lPartialStart,
    'Expected model extraction after partial snapshot cache branch.');
  lPartialBranch := Copy(lBuildBody, lPartialStart, lPartialEnd - lPartialStart);

  Assert.IsFalse(ContainsText(lPartialBranch,
    'lExtractionSourceFileNames := lMissingSourceFileNames'),
    'Partial cache rebuilds need lean models for cache hits as semantic context.');
  Assert.IsTrue(ContainsText(lPartialBranch,
    'lExtractionScopeSourceFileNames := lMissingSourceFileNames'),
    'Partial cache rebuilds must fully analyze only the missing units.');
  Assert.IsFalse(ContainsText(lBuildBody, 'lMissingModelIndex'),
    'Partial cache rebuilds should preserve full project model indexes.');
  Assert.IsTrue(ContainsText(lBuildBody,
    'lExtractionModelIndex := i'),
    'Missing unit snapshots must use their full project model indexes.');
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
    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, [lDprPath],
      lSecondMetrics);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
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
    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, [lDprPath],
      lThirdMetrics);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
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
    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, lMetrics);
    try
      Assert.AreEqual(3, lSnapshot.UnitCount);
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

procedure WritePartialCrossMissProjectBase(const aRootPath: string);
begin
  TFile.WriteAllText(TPath.Combine(aRootPath,
    'PartialCrossMissReference.dpr'), 'program PartialCrossMissReference;' +
    sLineBreak + 'uses PartialCrossMissTypes, PartialCrossMissDeclarations, ' +
    'PartialCrossMissConsumer;' + sLineBreak + 'begin' + sLineBreak +
    '  Touch;' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(aRootPath,
    'PartialCrossMissReference.dproj'),
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    sLineBreak + '  <PropertyGroup>' + sLineBreak +
    '    <ProjectGuid>{5B622D59-C51E-46E2-9046-5E3909DD2303}</ProjectGuid>' +
    sLineBreak + '    <MainSource>PartialCrossMissReference.dpr</MainSource>' +
    sLineBreak + '  </PropertyGroup>' + sLineBreak + '  <ItemGroup>' +
    sLineBreak + '    <DCCReference Include="PartialCrossMissTypes.pas"/>' +
    sLineBreak + '    <DCCReference Include="PartialCrossMissConsumer.pas"/>' +
    sLineBreak + '    <DCCReference Include="PartialCrossMissDeclarations.pas"/>' +
    sLineBreak + '  </ItemGroup>' + sLineBreak + '</Project>', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(aRootPath,
    'PartialCrossMissTypes.pas'), 'unit PartialCrossMissTypes;' +
    sLineBreak + 'interface' + sLineBreak + 'type' + sLineBreak +
    '  TSharedValue = Integer;' + sLineBreak + 'implementation' +
    sLineBreak + 'end.', TEncoding.UTF8);
end;

procedure WritePartialCrossMissDeclaration(const aRootPath: string;
  const aChanged: Boolean);
var
  lExpression: string;
begin
  if aChanged then
    lExpression := 'aValue + 0'
  else
    lExpression := 'aValue';
  TFile.WriteAllText(TPath.Combine(aRootPath,
    'PartialCrossMissDeclarations.pas'),
    'unit PartialCrossMissDeclarations;' + sLineBreak + 'interface' +
    sLineBreak + 'uses PartialCrossMissTypes;' + sLineBreak +
    'function SharedTarget(const aValue: TSharedValue): TSharedValue;' +
    sLineBreak + 'implementation' + sLineBreak +
    'function SharedTarget(const aValue: TSharedValue): TSharedValue;' +
    sLineBreak + 'begin' + sLineBreak + '  Result := ' + lExpression + ';' +
    sLineBreak + 'end;' + sLineBreak + 'end.', TEncoding.UTF8);
end;

procedure WritePartialCrossMissConsumer(const aRootPath: string;
  const aChanged: Boolean);
var
  lExpression: string;
begin
  if aChanged then
    lExpression := 'SharedTarget(1) + 1'
  else
    lExpression := 'SharedTarget(1)';
  TFile.WriteAllText(TPath.Combine(aRootPath,
    'PartialCrossMissConsumer.pas'), 'unit PartialCrossMissConsumer;' +
    sLineBreak + 'interface' + sLineBreak + 'procedure Touch;' +
    sLineBreak + 'implementation' + sLineBreak +
    'uses PartialCrossMissTypes, PartialCrossMissDeclarations;' +
    sLineBreak + 'procedure Touch;' + sLineBreak + 'var' + sLineBreak +
    '  lValue: TSharedValue;' + sLineBreak + 'begin' + sLineBreak +
    '  lValue := ' + lExpression + ';' + sLineBreak + 'end;' +
    sLineBreak + 'end.', TEncoding.UTF8);
end;

procedure WritePartialCrossMissProject(const aRootPath: string);
begin
  WritePartialCrossMissProjectBase(aRootPath);
  WritePartialCrossMissDeclaration(aRootPath, False);
  WritePartialCrossMissConsumer(aRootPath, False);
end;

function BuildPartialCrossMissSnapshot(const aProjectPath, aCachePath: string;
  out aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics):
  TDelphiProjectSnapshot;
var
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := aProjectPath;
  lOptions.SqliteCacheFileName := aCachePath;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    Result := BuildSnapshotWithMetrics(lResult.Session, aMetrics);
  finally
    lResult.Session.Free;
  end;
end;

procedure AssertPartialCrossMissReferenceResolved(
  const aSnapshot: TDelphiProjectSnapshot; const aConsumerPath: string);
var
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  Assert.IsTrue(aSnapshot.TryReferenceAt(aConsumerPath, 10, 13,
    lReferenceRef),
    'Expected the rebuilt consumer reference after a multi-unit cache miss.');
  Assert.IsTrue(aSnapshot.TryFindUnitById(lReferenceRef.UnitId, lUnit));
  lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
  Assert.AreNotEqual(0, Integer(lReference.TargetUnitId));
  Assert.IsTrue(aSnapshot.TryFindUnitById(lReference.TargetUnitId, lUnit));
  lSymbol := lUnit.SymbolById(lReference.TargetSymbolId);
  Assert.AreEqual('SharedTarget', aSnapshot.TextOf(lSymbol.NameId));
end;

procedure TProjectSessionTests.ProjectSessionPartialSnapshotCacheRebuildPreservesCrossMissReferences;
var
  lCachePath: string;
  lConsumerPath: string;
  lDprojPath: string;
  lExpectedSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lRootPath: string;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRootPath := ProjectSessionTempPath(
    'snapshot-session-partial-cross-miss-reference-temp');
  TDirectory.CreateDirectory(lRootPath);
  WritePartialCrossMissProject(lRootPath);
  lDprojPath := TPath.Combine(lRootPath, 'PartialCrossMissReference.dproj');
  lConsumerPath := TPath.Combine(lRootPath, 'PartialCrossMissConsumer.pas');
  lCachePath := CombinePath([lRootPath, '.dak', 'semantic-cache.sqlite3']);

  lSnapshot := BuildPartialCrossMissSnapshot(lDprojPath, lCachePath, lMetrics);
  try
    Assert.AreEqual(4, lSnapshot.UnitCount);
  finally
    lSnapshot.Free;
  end;

  WritePartialCrossMissDeclaration(lRootPath, True);
  WritePartialCrossMissConsumer(lRootPath, True);
  lSnapshot := BuildPartialCrossMissSnapshot(lDprojPath, lCachePath, lMetrics);
  try
    Assert.AreEqual(2, lMetrics.SnapshotCacheHits);
    Assert.AreEqual(2, lMetrics.SnapshotCacheMisses);
    Assert.AreEqual(1, lMetrics.SnapshotCachePartialHitCount);
    AssertPartialCrossMissReferenceResolved(lSnapshot, lConsumerPath);
    lExpectedSnapshot := BuildPartialCrossMissSnapshot(lDprojPath, '', lMetrics);
    try
      Assert.AreEqual(0, lMetrics.SnapshotCacheHits);
      AssertSnapshotFactsEqual(lExpectedSnapshot, lSnapshot);
    finally
      lExpectedSnapshot.Free;
    end;
  finally
    lSnapshot.Free;
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
    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, lMetrics);
    try
      Assert.AreEqual(3, lSnapshot.UnitCount);
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

    lSnapshot := BuildSnapshotWithMetrics(lResult.Session, lMetrics);
    try
      Assert.AreEqual(2, lSnapshot.UnitCount);
      Assert.IsTrue(lSnapshot.TryFindUnitByFileName(lUnitPath, lUnitId),
        'Expected source-loader-decoded DPR in-reference unit in project snapshot.');
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
    lFirstSnapshot := BuildSnapshotWithMetrics(lFirstResult.Session, lFirstMetrics);
    try
      Assert.AreEqual(2, lFirstSnapshot.UnitCount);
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
    lSecondSnapshot := BuildSnapshotWithMetrics(lSecondResult.Session, lSecondMetrics);
    try
      Assert.AreEqual(2, lSecondSnapshot.UnitCount);
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
    lThirdSnapshot := BuildSnapshotWithMetrics(lThirdResult.Session, lThirdMetrics);
    try
      Assert.AreEqual(2, lThirdSnapshot.UnitCount);
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

procedure TProjectSessionTests.InlineSectionRenameProducesThreeEdits;
var
  lExpected: TIdentifierScopePlanResult;
  lInline: TIdentifierScopePlanResult;
  lOptions: TDelphiSemanticOptions;
  lProviderFileName: string;
  lRoot: string;
begin
  lRoot := ProjectSessionTempPath('inline-section-rename');
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := CreateIdentifierScopeProject(lRoot);
  lOptions.Configuration := 'Release';
  lOptions.Platform := 'Win64';
  lExpected := BuildIdentifierScopePlan(lOptions);
  Assert.AreEqual('planned', lExpected.Plan.Status, lExpected.Plan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lExpected.Plan.Edits)));
  lProviderFileName := TPath.Combine(lRoot, 'IdentifierScopeProvider.pas');
  TFile.WriteAllText(lProviderFileName,
    StringReplace(TFile.ReadAllText(lProviderFileName),
      'var' + sLineBreak + '  ScopeTarget', 'var ScopeTarget', []), TEncoding.UTF8);
  lInline := BuildIdentifierScopePlan(lOptions);
  Assert.AreEqual('planned', lInline.Plan.Status, lInline.Plan.Diagnostic);
  Assert.AreEqual(3, Integer(Length(lInline.Plan.Edits)));
  lOptions.ForceFullIdentifierAnalysis := True;
  lExpected := BuildIdentifierScopePlan(lOptions);
  AssertRenamePlansEqual(lExpected.Plan, lInline.Plan);
end;

procedure TProjectSessionTests.RebuildsRemoveWithFactsWithOlderSchemaMarker(
  const aVersion: string);
var
  i: Integer;
  lExpectedPlan: string;
  lBuild: TDelphiSemanticRemoveWithPlanBuildResult;
  lOpened: TDelphiSemanticProjectSessionResult;
  lOptions: TDelphiSemanticOptions;
  lSerializer: TJsonSerializer;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath(
    'RemoveWithNestedForwardCapture\NestedForwardCapture.dproj');
  lOptions.Platform := 'Win64';
  lOptions.Configuration := 'Debug';
  lOptions.DelphiVersion := '23.0';
  lOptions.SqliteCacheFileName := ProjectSessionTempPath('older-remove-with-facts-' + aVersion + '.sqlite3');
  lOptions.SkipWithBindingSemanticGraph := True;
  lSerializer := TJsonSerializer.Create;
  try
    for i := 0 to 3 do
    begin
      if i = 2 then
        ExecProjectSessionCacheSql(lOptions.SqliteCacheFileName,
          'update snapshot_project_remove_with_facts ' +
          'set schema_version = ' + QuotedStr('project-session-remove-with-facts-v' + aVersion));
      lOpened := TDelphiSemanticProjectSession.Open(lOptions);
      try
        Assert.IsTrue(lOpened.Success);
        lBuild := lOpened.Session.PlanRemoveWithResult;
      finally
        lOpened.Session.Free;
      end;
      Assert.AreEqual(1, lBuild.SnapshotMetrics.SnapshotCacheProbes);
      Assert.AreEqual(i mod 2, lBuild.SnapshotMetrics.SnapshotCacheHits,
        'An older producer marker must miss without changing fixture sources.');
      Assert.AreEqual(1 - (i mod 2), lBuild.SnapshotMetrics.SnapshotCacheMisses);
      Assert.AreEqual(2, Integer(Length(lBuild.Plan.FinalStatements)));
      for lStatement in lBuild.Plan.FinalStatements do
      begin
        Assert.AreEqual('planned', lStatement.Status, lStatement.Reason);
        Assert.AreEqual('Observe', lStatement.RoutineName);
      end;
      Assert.AreEqual('declare-temp', lBuild.Plan.FinalStatements[0].Edits[0].Kind);
      Assert.AreEqual(20, lBuild.Plan.FinalStatements[0].Edits[0].Range.StartLine);
      Assert.AreEqual(1, lBuild.Plan.FinalStatements[0].Edits[0].Range.StartColumn);
      Assert.AreEqual(20, lBuild.Plan.FinalStatements[0].Edits[0].Range.EndLine);
      Assert.AreEqual(1, lBuild.Plan.FinalStatements[0].Edits[0].Range.EndColumn);
      if i = 0 then
        lExpectedPlan := lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lBuild.Plan)
      else
        Assert.AreEqual(lExpectedPlan,
          lSerializer.Serialize<TDelphiSemanticRemoveWithPlan>(lBuild.Plan));
    end;
  finally
    lSerializer.Free;
  end;
end;

type
  TProjectProfileAbsenceStub = class(TInterfacedObject,
    IDelphiSemanticImplicitRootMemberAbsence, IDelphiSemanticProjectProfileValidator)
  private
    fMode: string;
    fExpectedProfile: string;
    fValidationCallCount: Integer;
    fAbsenceCallCount: Integer;
    fLastProject: TDelphiSemanticProjectInfo;
  public
    constructor Create(const aMode: string; const aExpectedProfile: string = '');
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
    function ValidateProjectProfile(const aProject: TDelphiSemanticProjectInfo;
      out aReason: string): Boolean;
    property ValidationCallCount: Integer read fValidationCallCount;
    property AbsenceCallCount: Integer read fAbsenceCallCount;
    property LastProject: TDelphiSemanticProjectInfo read fLastProject;
  end;

constructor TProjectProfileAbsenceStub.Create(const aMode: string; const aExpectedProfile: string);
begin
  inherited Create;
  fMode := aMode;
  fExpectedProfile := aExpectedProfile;
end;

function TProjectProfileAbsenceStub.EvidenceFingerprint: string;
begin
  Result := 'project-profile-validation-test';
end;

function TProjectProfileAbsenceStub.IsNameAbsent(const aName: string): Boolean;
begin
  Inc(fAbsenceCallCount);
  Result := False;
end;

function ReviewProfileKey(const aProject: TDelphiSemanticProjectInfo): string;
begin
  Result := aProject.Configuration + #31 + aProject.Platform + #31 +
    string.Join(';', aProject.Defines) + #31 + string.Join(';', aProject.SearchPaths);
end;

function TProjectProfileAbsenceStub.ValidateProjectProfile(
  const aProject: TDelphiSemanticProjectInfo; out aReason: string): Boolean;
begin
  Inc(fValidationCallCount);
  fLastProject := aProject;
  aReason := 'The native source profile does not match the semantic session.';
  if fMode = 'raise' then
    raise EInvalidOpException.Create('Profile validation failed deliberately');
  if fMode = 'compare' then
    Result := ReviewProfileKey(aProject) = fExpectedProfile
  else
    Result := fMode = 'accept';
  if Result then
    aReason := '';
end;

procedure TProjectSessionTests.RootAbsenceValidatesActualProjectProfile(const aMode: string);
var
  lOptions: TDelphiSemanticOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lResult: TDelphiSemanticProjectSessionResult;
  lFacts: TDelphiSemanticProjectWithBindingFactsBuildResult;
  lRoot: string;
  lStub: TProjectProfileAbsenceStub;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lRoot := ProjectSessionTempPath('profile-binding-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'BasicProject.dproj');
  TFile.WriteAllText(lOptions.ProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>BasicProject.dpr</MainSource></PropertyGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'BasicProject.dpr'),
    'program BasicProject; uses ProfileWith in ''ProfileWith.pas''; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ProfileWith.pas'),
    'unit ProfileWith;'#13#10'interface'#13#10'type TReceiver = class end;'#13#10 +
    'var Receiver: TReceiver; Count: Integer;'#13#10'implementation'#13#10 +
    'procedure Run;'#13#10'begin'#13#10'  with Receiver do Count := 1;'#13#10 +
    'end;'#13#10'end.', TEncoding.ASCII);
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lStub := TProjectProfileAbsenceStub.Create(aMode);
  lProvider := lStub;
  lOptions.ImplicitRootMemberAbsence := lProvider;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.AreEqual(1, lStub.ValidationCallCount);
    Assert.AreEqual(0, lStub.AbsenceCallCount,
      'Our session must validate the source profile before any absence query.');
    Assert.AreEqual('BasicProject', lStub.LastProject.ProjectName);
    Assert.AreEqual('Debug', lStub.LastProject.Configuration);
    Assert.AreEqual('Win64', lStub.LastProject.Platform);
    if aMode = 'accept' then
    begin
      Assert.IsTrue(lResult.Success);
      Assert.IsNotNull(lResult.Session);
      lFacts := lResult.Session.BuildWithBindingFactsResult;
      Assert.AreEqual(1, Integer(Length(lFacts.Facts.Bindings)));
      Assert.IsTrue(lStub.AbsenceCallCount > 0, 'Accepted binding must query absence evidence.');
      Assert.AreEqual(lResult.Session.Project.ContextFingerprint,
        lStub.LastProject.ContextFingerprint);
      Assert.AreEqual(lResult.Session.Project.ProjectFileName,
        lStub.LastProject.ProjectFileName);
    end else
    begin
      Assert.IsFalse(lResult.Success);
      Assert.IsNull(lResult.Session);
      Assert.IsTrue(Length(lResult.Diagnostics) > 0);
      Assert.AreEqual('PROJECT_PROFILE_VALIDATION_FAILED',
        lResult.Diagnostics[High(lResult.Diagnostics)].Code);
    end;
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectSessionTests.RootAbsenceRejectsSameLabelDifferentProfile(const aInput: string);
var
  lExpectedProfile: string;
  lOptions: TDelphiSemanticOptions;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lResult: TDelphiSemanticProjectSessionResult;
  lRoot: string;
  lText: string;
begin
  lRoot := ProjectSessionTempPath('same-label-profile-' + aInput);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'P.dproj');
  lOptions.Platform := 'Win64';
  lOptions.Configuration := 'Debug';
  lText := '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource><DCC_Define>ORIGINAL</DCC_Define>' +
    '<DCC_UnitSearchPath>original</DCC_UnitSearchPath></PropertyGroup></Project>';
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'), 'program P; begin end.', TEncoding.ASCII);
  TFile.WriteAllText(lOptions.ProjectPath, lText, TEncoding.ASCII);
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lExpectedProfile := ReviewProfileKey(lResult.Session.Project);
  finally
    lResult.Session.Free;
  end;
  lProvider := TProjectProfileAbsenceStub.Create('compare', lExpectedProfile);
  lOptions.ImplicitRootMemberAbsence := lProvider;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success, 'Identical compiler inputs must pass the comparing validator.');
  finally
    lResult.Session.Free;
  end;
  if aInput = 'defines' then
    lText := StringReplace(lText, '>ORIGINAL<', '>CHANGED<', [])
  else
    lText := StringReplace(lText, '>original<', '>changed<', []);
  TFile.WriteAllText(lOptions.ProjectPath, lText, TEncoding.ASCII);
  lOptions.ImplicitRootMemberAbsence := lProvider;
  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsFalse(lResult.Success, 'A configuration label does not verify compiler inputs.');
    Assert.IsNull(lResult.Session);
    Assert.AreEqual('PROJECT_PROFILE_VALIDATION_FAILED',
      lResult.Diagnostics[High(lResult.Diagnostics)].Code);
  finally
    lResult.Session.Free;
  end;
end;

type
  TSessionObservationOwner = class(TInterfacedObject,
    IDelphiSemanticImplicitRootMemberAbsence, IDelphiSemanticModelObservationOwner)
  private
    fMode: string;
    fSource: string;
  public
    fCalls: Integer;
    fNameCalls: Integer;
    constructor Create(const aMode: string);
    function EvidenceFingerprint: string;
    function IsNameAbsent(const aName: string): Boolean;
    function ValidateModelSources(const aObservation: TDelphiSemanticModelObservation;
      out aReason: string): Boolean;
  end;

constructor TSessionObservationOwner.Create(const aMode: string);
begin
  inherited Create;
  fMode := aMode;
end;

function TSessionObservationOwner.EvidenceFingerprint: string;
begin
  Result := 'session-observation-owner';
end;

function TSessionObservationOwner.IsNameAbsent(const aName: string): Boolean;
begin
  Inc(fNameCalls);
  if (fMode = 'binding-drift') and (fNameCalls = 1) then
    TFile.AppendAllText(fSource, sLineBreak + '// callback changed consumed bytes', TEncoding.UTF8);
  Result := SameText(aName, 'lNearest');
end;

function TSessionObservationOwner.ValidateModelSources(
  const aObservation: TDelphiSemanticModelObservation; out aReason: string): Boolean;
var
  lPath: string;
begin
  Inc(fCalls);
  Assert.IsTrue(aObservation.ProjectContextFingerprint <> '');
  if fMode.StartsWith('binding-') then
  begin
    fSource := aObservation.ModelFileName;
    aReason := '';
    Exit(True);
  end;
  aReason := 'deliberate referenced-model refusal';
  if not SameText(TPath.GetFileName(aObservation.ModelFileName), 'OwnerUnit.pas') then
    Exit(True);
  Assert.AreEqual(fMode.StartsWith('hit-'), aObservation.CacheHit);
  Assert.AreEqual(1, Integer(Length(aObservation.IncludeFileNames)));
  Assert.AreEqual(2, aObservation.SourceObservations.Count);
  if fMode = 'raise' then
    raise EInvalidOpException.Create('deliberate owner exception');
  if fMode.EndsWith('drift') then
  begin
    lPath := aObservation.ModelFileName;
    if fMode = 'include-drift' then
      lPath := aObservation.IncludeFileNames[0];
    TFile.AppendAllText(lPath, sLineBreak + '// changed after read', TEncoding.UTF8);
  end;
  Result := not fMode.EndsWith('reject');
end;

procedure TProjectSessionTests.RequestOwnerSealsEveryModelBeforePublication(const aMode: string);
var
  lOptions: TDelphiSemanticOptions;
  lProject: TDelphiSemanticProjectInfo;
  lSession: TDelphiSemanticProjectSessionResult;
  lBuild: TDelphiSemanticProjectSnapshotBuildResult;
  lRoot, lSource, lUnit, lInclude, lCacheFile, lRefusalReason: string;
  lRefused: Boolean;
  lOwner: TSessionObservationOwner;
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lAccess: TDelphiSemanticUnitCacheAccessResult;
begin
  lRoot := ProjectSessionTempPath('ds717-' + aMode);
  TDirectory.CreateDirectory(lRoot);
  lSource := TPath.Combine(lRoot, 'OwnerProject.dpr');
  lUnit := TPath.Combine(lRoot, 'OwnerUnit.pas');
  lInclude := TPath.Combine(lRoot, 'Owner.inc');
  lCacheFile := TPath.Combine(lRoot, 'cache.sqlite');
  TFile.WriteAllText(lSource, 'program OwnerProject;' + sLineBreak +
    'uses OwnerUnit in ''OwnerUnit.pas'';' + sLineBreak + 'begin end.', TEncoding.UTF8);
  TFile.WriteAllText(lUnit, 'unit OwnerUnit;' + sLineBreak + 'interface' + sLineBreak +
    '{$I Owner.inc}' + sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lInclude, 'type TOwnerValue = record Value: Integer; end;', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'OwnerProject.dproj');
  TFile.WriteAllText(lOptions.ProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>OwnerProject.dpr</MainSource></PropertyGroup></Project>', TEncoding.UTF8);
  lOptions.Platform := 'Win64';
  lOptions.Configuration := 'Debug';
  lOptions.SqliteCacheFileName := lCacheFile;
  if aMode.StartsWith('hit-') then
  begin
    lSession := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lSession.Success);
      lBuild := lSession.Session.BuildSnapshotResult;
      Assert.IsNotNull(lBuild.Snapshot);
      lBuild.Snapshot.Free;
    finally
      lSession.Session.Free;
    end;
  end;
  lOwner := TSessionObservationOwner.Create(aMode);
  lOptions.ImplicitRootMemberAbsence := lOwner;
  lSession := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lSession.Success);
    lProject := lSession.Session.Project;
    lRefused := False;
    lRefusalReason := '';
    lBuild := Default(TDelphiSemanticProjectSnapshotBuildResult);
    try
      lBuild := lSession.Session.BuildSnapshotResult;
    except
      on E: EInvalidOpException do
      begin
        Assert.IsTrue(E.Message.StartsWith('MODEL_SOURCE_VALIDATION_FAILED'), E.Message);
        lRefused := True;
        lRefusalReason := E.Message;
        if aMode.EndsWith('drift') then
          Assert.IsTrue(E.Message.Contains('source drift'), E.Message)
        else
          Assert.IsTrue(E.Message.Contains('deliberate'), E.Message);
      end;
    end;
    if aMode.EndsWith('accept') then
      Assert.AreEqual(2, lOwner.fCalls, 'Both models require an owner callback');
    Assert.AreEqual(not aMode.EndsWith('accept'), lRefused, lRefusalReason);
    if lRefused then
      Assert.IsNull(lBuild.Snapshot)
    else
      Assert.IsNotNull(lBuild.Snapshot);
    lBuild.Snapshot.Free;
  finally
    lSession.Session.Free;
  end;
  // Refusal of a later referenced model must not have persisted the main model.
  if not aMode.StartsWith('hit-') then
  begin
    lCacheOptions := Default(TDelphiSemanticCacheOptions);
    lCacheOptions.SqliteCacheFileName := lCacheFile;
    lCacheOptions.CompilerProfileName := Format('ProjectSession-%s-%s-%s',
      [lOptions.DelphiVersion, lOptions.Platform, lOptions.Configuration]);
    lCacheOptions.DelphiVersion := lOptions.DelphiVersion;
    lCacheOptions.Configuration := lOptions.Configuration;
    lCacheOptions.Platform := lOptions.Platform;
    lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    try
      lModelOptions := Default(TDelphiSemanticModelOptions);
      lModelOptions.SourceFileName := lSource;
      lModelOptions.ProjectContextApplied := True;
      lModelOptions.Defines := lProject.Defines;
      lModelOptions.SearchPaths := lProject.SourceLookupPaths;
      lAccess := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
      Assert.IsFalse(lAccess.CacheHit);
    finally
      lCache.Free;
    end;
  end;
end;

procedure RunBindingPublicationControl(const aRoute: string; const aDrift: Boolean);
var
  lOptions: TDelphiSemanticOptions;
  lSession: TDelphiSemanticProjectSessionResult;
  lOwner: TSessionObservationOwner;
  lProvider: IDelphiSemanticImplicitRootMemberAbsence;
  lPlan: TDelphiSemanticRemoveWithPlanBuildResult;
  lFacts: TDelphiSemanticProjectWithBindingFactsBuildResult;
  lCombined: TDelphiSemanticRemoveWithFactsAndPlanBuildResult;
  lRoot, lSource: string;
  lRefused: Boolean;
  lPersistedIdentity, lOwnerIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lFactsCache: TDelphiSemanticSnapshotSqliteCache;
  lSeedSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := ProjectSessionTempPath('binding-publication-' + aRoute);
  TDirectory.CreateDirectory(lRoot);
  lSource := TPath.Combine(lRoot, 'P.dpr');
  TFile.WriteAllText(lSource, 'program P;' + sLineBreak +
    'uses OwnerUnit in ''OwnerUnit.pas'';' + sLineBreak + 'begin end.', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'OwnerUnit.pas'),
    'unit OwnerUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TLeft = class' + sLineBreak + '  public LeftOnly: Integer;' + sLineBreak + '  end;' + sLineBreak +
    '  TRight = class' + sLineBreak + '  public RightOnly: Integer;' + sLineBreak + '  end;' + sLineBreak +
    'procedure Run;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak + 'var lLeft: TLeft; lRight: TRight;' + sLineBreak +
    'begin' + sLineBreak + '  with lLeft, lRight do' + sLineBreak +
    '  begin' + sLineBreak + '    LeftOnly := 1;' + sLineBreak + '  end;' + sLineBreak +
    'end;' + sLineBreak + 'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := TPath.Combine(lRoot, 'P.dproj');
  TFile.WriteAllText(lOptions.ProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup></Project>', TEncoding.ASCII);
  lOptions.Platform := 'Win64';
  lOptions.Configuration := 'Debug';
  lOptions.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  if not aDrift then
  begin
    // Seed real WITH facts and verify their no-owner warm reuse.
    lSession := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lSession.Success);
      lPlan := lSession.Session.PlanRemoveWithResult;
      Assert.AreEqual(1, lPlan.SnapshotMetrics.SnapshotCacheMisses);
    finally
      lSession.Session.Free;
    end;
    lSession := TDelphiSemanticProjectSession.Open(lOptions);
    try
      lPlan := lSession.Session.PlanRemoveWithResult;
      Assert.AreEqual(1, lPlan.SnapshotMetrics.SnapshotCacheHits);
    finally
      lSession.Session.Free;
    end;
  end;
  if aDrift then
    lOwner := TSessionObservationOwner.Create('binding-drift')
  else
    lOwner := TSessionObservationOwner.Create('binding-accept');
  lProvider := lOwner;
  lOptions.ImplicitRootMemberAbsence := lProvider;
  if not aDrift then
  begin
    lPersistedIdentity := ReadProjectRemoveWithFactsIdentity(lOptions.SqliteCacheFileName);
    lSession := TDelphiSemanticProjectSession.Open(lOptions);
    try
      Assert.IsTrue(lSession.Success);
      lOwnerIdentity := ProjectRemoveWithFactsIdentityForTest(lSession.Session.Project, lOptions);
    finally
      lSession.Session.Free;
    end;
    // Match the owner context exactly, so identity mismatch cannot mask a missing bypass.
    lFactsCache := TDelphiSemanticSnapshotSqliteCache.Create(lOptions.SqliteCacheFileName);
    lSeedSnapshot := nil;
    try
      Assert.IsTrue(lFactsCache.TryLoadProjectRemoveWithPlanningFacts(lPersistedIdentity, lSeedSnapshot));
      lFactsCache.StoreProjectRemoveWithPlanningFacts(lOwnerIdentity, lSeedSnapshot);
      lSeedSnapshot.Free;
      lSeedSnapshot := nil;
      Assert.IsTrue(lFactsCache.TryLoadProjectRemoveWithPlanningFacts(lOwnerIdentity, lSeedSnapshot),
        'An exact owner-context WITH-fact entry must exist before the request');
    finally
      lSeedSnapshot.Free;
      lFactsCache.Free;
    end;
  end;
  lSession := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lSession.Success);
    lRefused := False;
    lPlan := Default(TDelphiSemanticRemoveWithPlanBuildResult);
    lFacts := Default(TDelphiSemanticProjectWithBindingFactsBuildResult);
    lCombined := Default(TDelphiSemanticRemoveWithFactsAndPlanBuildResult);
    try
      if aRoute = 'facts' then
        lFacts := lSession.Session.BuildWithBindingFactsResult
      else if aRoute = 'combined' then
        lCombined := lSession.Session.BuildRemoveWithFactsAndPlanResult
      else
        lPlan := lSession.Session.PlanRemoveWithResult;
    except
      on E: EInvalidOpException do
      begin
        Assert.IsTrue(E.Message.StartsWith('MODEL_SOURCE_VALIDATION_FAILED'), E.Message);
        Assert.IsTrue(E.Message.Contains('source drift'), E.Message);
        lRefused := True;
      end;
    end;
    Assert.IsTrue(lOwner.fCalls > 0, 'Owner observations must execute');
    Assert.IsTrue(lOwner.fNameCalls > 0, 'Binding must consume the provider');
    Assert.AreEqual(aDrift, lRefused, 'Callback drift must refuse publication');
    if aDrift then
    begin
      Assert.AreEqual<NativeInt>(0, Length(lPlan.Plan.FinalStatements));
      Assert.AreEqual<NativeInt>(0, Length(lFacts.Facts.Bindings));
      Assert.AreEqual<NativeInt>(0, Length(lCombined.Plan.FinalStatements));
    end else begin
      Assert.AreEqual(0, lPlan.SnapshotMetrics.SnapshotCacheProbes,
        'Owner planning must bypass persisted WITH facts');
      Assert.IsTrue(Length(lPlan.Plan.FinalStatements) > 0);
    end;
  finally
    lSession.Session.Free;
  end;
end;

procedure TRequestPublicationTests.BindingCallbackDriftRefusesPublication(const aRoute: string);
begin
  RunBindingPublicationControl(aRoute, True);
end;

procedure TRequestPublicationTests.OwnerBypassesPersistedWithFacts;
begin
  RunBindingPublicationControl('plan', False);
end;

initialization
  TDUnitX.RegisterTestFixture(TRequestPublicationTests);
  TDUnitX.RegisterTestFixture(TProjectSessionTests);

end.
