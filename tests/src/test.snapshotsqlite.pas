unit Test.SnapshotSqlite;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Snapshot.Cache.Sqlite;

type
  [TestFixture]
  TSnapshotSqliteTests = class
  private
    procedure AssertImportGraphRoundTrip(const aCorruption: string; const aBatch: Boolean);
    function CreateConcurrencyIdentity(const aCacheFileName, aName: string):
      TDelphiSemanticSnapshotCacheIdentity;
    function CreateIdentity(const aName, aFileHash, aContextHash, aIncludeGraphHash,
      aSchemaVersion: string): TDelphiSemanticSnapshotCacheIdentity;
    function CacheTextRowCount(const aCacheFileName, aTableName, aCacheKey,
      aTextValue: string): Integer;
    procedure ExecCacheSql(const aCacheFileName, aSql: string);
    procedure HoldConcurrencyWriteLock(const aCacheFileName, aReadyFileName,
      aReleaseFileName: string);
    procedure StoreDemoUnit(const aCacheFileName: string;
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity);
    procedure StoreConcurrencyIdentity(const aCacheFileName, aName: string);
    function TableRowCount(const aCacheFileName, aTableName: string): Integer;
    function TempPath(const aName: string): string;
    procedure AssertSourceRoutineSymbolsReload(const aName, aSource: string;
      const aExpectedNames: array of string);
    procedure AssertIdentityChangeMissesWithoutEviction(const aName: string; const aChangedIdentity:
      TDelphiSemanticSnapshotCacheIdentity);
    procedure VerifyConcurrencyIdentities(const aCacheFileName: string;
      const aNames: TArray<string>);
  public
    [Test]
    [TestCase('Unit children', 'False')]
    [TestCase('Project children', 'True')]
    procedure ChildRowsUseIntegerOwnerKeys(const aProject: Boolean);
    [Test]
    procedure PhysicalOccurrencesSurviveSqliteRoundTrip;
    [Test]
    [TestCase('Legacy references present', 'False')]
    [TestCase('Physical occurrences only', 'True')]
    procedure IncludedPathsKeepOriginalSpelling(const aPhysicalOnly: Boolean);
    [Test]
    [TestCase('Standalone load', 'False')]
    [TestCase('Batch load', 'True')]
    procedure AvailableSymbolsRejectMalformedProjection(const aBatch: Boolean);
    [Test]
    [TestCase('Every truncation', 'truncated')]
    [TestCase('Trailing bytes', 'trailing')]
    [TestCase('Unknown format', 'format')]
    [TestCase('Nonminimal varint', 'overlong')]
    [TestCase('Overflowing varint', 'overflow')]
    [TestCase('Continued tenth byte', 'continued')]
    [TestCase('Invalid semantic ID', 'semantic')]
    [TestCase('Binding outside reference array', 'binding')]
    [TestCase('Unverified binding', 'binding-unverified')]
    [TestCase('Missing collection', 'missing')]
    [TestCase('Extra collection', 'extra')]
    [TestCase('Header count', 'count')]
    [TestCase('Seeded byte fuzz', 'fuzz')]
    procedure PhysicalOccurrencePayloadRejectsMalformedData(const aMutation: string);
    [Test]
    [TestCase('Unavailable source row', 'source,False')]
    [TestCase('Available source row', 'source,True')]
    [TestCase('Unavailable unverified reference', 'reference,False')]
    [TestCase('Available unverified reference', 'reference,True')]
    [TestCase('Unavailable unverified symbol', 'symbol,False')]
    [TestCase('Available unverified symbol', 'symbol,True')]
    procedure HasIncludesMutationRejectsEveryNonrootCollection(const aCollection: string;
      const aAvailable: Boolean);
    [Test]
    procedure SharedSourceTextReplacementAndGcAreAtomic;
    [Test]
    [TestCase('Stored text altered', 'text')]
    [TestCase('Stored hash malformed', 'hash')]
    [TestCase('Shared row missing', 'missing')]
    [TestCase('Two backing modes', 'backing')]
    procedure SharedSourceTextRejectsCorruptBacking(const aMutation: string);
    [Test]
    procedure UnitLoadBatchKeepsOneReadGeneration;
    [Test]
    [TestCase('Has includes', 'includes')]
    [TestCase('Captured count', 'count')]
    [TestCase('Captured ordinal', 'ordinal')]
    [TestCase('Captured unit ID', 'unit')]
    [TestCase('Captured status', 'status')]
    [TestCase('Import ordinal', 'import')]
    [TestCase('Occurrence BLOB', 'blob')]
    [TestCase('Target lineage', 'lineage')]
    [TestCase('Shared text hash', 'hash')]
    [TestCase('Reference null', 'null')]
    [TestCase('Reference negative', 'negative')]
    [TestCase('Reference overflow', 'overflow')]
    [TestCase('Symbol overflow', 'symbol')]
    [TestCase('Header type', 'type')]
    [TestCase('Possible import header', 'possible-header')]
    [TestCase('Possible import ordering', 'possible-order')]
    [TestCase('Possible import count', 'possible-count')]
    [TestCase('Possible import type', 'possible-type')]
    [TestCase('Import provenance missing', 'provenance-missing')]
    [TestCase('Import provenance malformed', 'provenance-payload')]
    [TestCase('Import provenance count', 'provenance-count')]
    [TestCase('Import provenance overflow', 'provenance-overflow')]
    procedure UnitLoadBatchRejectsOnlyCorruptUnit(const aMutation: string);
    [Test]
    [TestCase('Reload physical file', 'file')]
    [TestCase('Reload captured access', 'access')]
    procedure IncludedGlobalEvidenceSurvivesReload(const aCheck: string);
    [Category('Fast')]
    [Test]
    procedure CacheKeyReuseWithDifferentIdentityDoesNotLoadStoredUnit;
    [Category('Fast')]
    [Test]
    procedure CachedTargetSurvivesCaseOnlyPoolSpelling;
    [Category('Fast')]
    [Test]
    procedure PackedTargetLineageUsesOneBlobPerUnit;
    [Category('Fast')]
    [Test]
    [TestCase('Unknown format', 'format')]
    [TestCase('Truncated payload', 'truncated')]
    [TestCase('Trailing bytes', 'trailing')]
    [TestCase('Nonminimal varint', 'overlong')]
    [TestCase('Overflowing varint', 'overflow')]
    [TestCase('Negative value count', 'negative-count')]
    [TestCase('Mismatched value count', 'count')]
    [TestCase('Wrong owning unit', 'unit')]
    procedure PackedTargetLineageRejectsCorruption(const aMutation: string);
    [Category('Fast')]
    [Test]
    procedure ContextSpecificSnapshotVariantsShareIdentityWithoutEviction;
    [Category('Fast')]
    [Test]
    procedure CorruptStringIdInvalidatesStoredSnapshot;
    [Category('Fast')]
    [Test]
    [TestCase('Round trip', 'none')]
    [TestCase('Missing graph header', 'header')]
    [TestCase('Missing graph edge', 'edge')]
    [TestCase('Invalid graph file ID', 'id')]
    [TestCase('Missing import provenance', 'provenance')]
    [TestCase('Truncated import provenance', 'count')]
    [TestCase('Malformed import provenance', 'payload')]
    procedure ImportGraphPersistsWithoutTokenReferences(const aCorruption: string);
    [Test]
    [TestCase('Round trip', 'none')]
    [TestCase('Missing graph header', 'header')]
    [TestCase('Missing graph edge', 'edge')]
    [TestCase('Invalid graph file ID', 'id')]
    [TestCase('Missing import provenance', 'provenance')]
    [TestCase('Truncated import provenance', 'count')]
    [TestCase('Malformed import provenance', 'payload')]
    procedure ImportGraphBatchPersistsWithoutTokenReferences(const aCorruption: string);
    [Category('Fast')]
    [Test]
    procedure DefaultSnapshotBuildDoesNotRequireSqliteCache;
    [Category('Fast')]
    [Test]
    procedure DeepSnapshotCachePersistsAndReusesAcrossInstances;
    [Category('Fast')]
    [Test]
    procedure BuildProjectSnapshotFromUnitSnapshotsDoesNotPromoteProjectRemoveWithPlanningFacts;
    [Category('Fast')]
    [Test]
    procedure BuildProjectSnapshotFromMixedUnitSnapshotsDropsProjectRemoveWithPlanningFacts;
    [Category('Fast')]
    [Test]
    procedure InvalidationDeletesAtomicallyWhenDeleteFails;
    [Category('Fast')]
    [Test]
    procedure MalformedLoadIdentityDoesNotDeleteStoredUnit;
    [Category('Fast')]
    [Test]
    procedure MetricsReportHitTimingAndUsefulness;
    [Category('Fast')]
    [Test]
    procedure MetricsReportMissTelemetry;
    [Category('Fast')]
    [Test]
    procedure MetricsRequirePositiveParseSavingsForUsefulCache;
    [Category('Fast')]
    [Test]
    procedure StoreRejectsAmbiguousIdentityValues;
    [Category('Fast')]
    [Test]
    procedure SnapshotSqliteCacheUsesPreparedStatementsAndCachedFields;
    [Category('Fast')]
    [Test]
    procedure SnapshotSqliteConnectionsDeclareBusyJournalAndLockingPolicy;
    [Category('Fast')]
    [Test]
    procedure SnapshotSqliteConcurrencyHarness;
    [Category('Fast')]
    [Test]
    procedure SnapshotSqliteRemoveWithLoadsPreSizeStoredFactArrays;
    [Category('Fast')]
    [Test]
    procedure SnapshotSqliteCacheUsesWideTextAccessors;
    [Category('Fast')]
    [Test]
    procedure SnapshotCacheSourceDoesNotUseJsonRepresentation;
    [Category('Fast')]
    [Test]
    procedure StoreUnitFromSnapshotPreservesUnicodeTextValues;
    [Category('Fast')]
    [Test]
    procedure StoreUnitFromSnapshotStoresOnlyReachableUnitStrings;
    [Category('Fast')]
    [Test]
    procedure StoreProjectRemoveWithPlanningFactsUsesProjectIdentity;
    [Category('Fast')]
    [Test]
    procedure RemoveWithTypeIdentityReloadRejectsMissingRows;
    [Category('Fast')]
    [Test]
    procedure LocalTypeIdentityReloadRejectsMissingScope;
    [Category('Fast')]
    [Test]
    procedure SourceRoutineSymbolsReloadWithRoutineScopes;
    [TestCase('Depth1', '1')]
    [TestCase('Depth2', '2')]
    procedure ProjectGenericMethodSymbolsReloadWithScopes(const aDepth: Integer);
    [Category('Fast')]
    [Test]
    procedure ParameterNamedInsideRoutineNameReloadsWithScope;
    [Test]
    procedure RoutineBoundaryTextTwinsReloadWithScopes;
    [Test]
    procedure EscapedMethodSymbolsReloadWithScopes;
    [Category('Fast')]
    [Test]
    procedure LocalNamedInsideEarlierLocalReloadsWithScope;
    [Category('Fast')]
    [Test]
    procedure MultiLineSignatureParametersReloadWithScope;
    [Category('Fast')]
    [Test]
    procedure OverloadParametersReloadWithTheirOwnScopes;
    [Category('Fast')]
    [Test]
    procedure CommentedParameterNameReloadsWithScope;
    [Category('Fast')]
    [Test]
    procedure RemoveWithAccessOwnerIdentityReloadRejectsMissingRows;
    [Category('Fast')]
    [Test]
    [TestCase('Before integer owner keys', '60')]
    [TestCase('Schema13', '13')]
    [TestCase('Schema17', '17')]
    [TestCase('Schema24', '24')]
    [TestCase('Before indexed record helper completeness', '27')]
    procedure Schema13PlanningRowsRebuildWholeSnapshotCache(const aOldSchema: string);
    [Category('Fast')]
    [Test]
    procedure CastMemberRefusesMismatchedSourceOffset;
    [Category('Fast')]
    [Test]
    procedure ProjectPlanningCachePreservesDirectImportVisibility;
    [Category('Fast')]
    [Test]
    procedure StoreUnitFromSnapshotDoesNotPersistRemoveWithPlanningFacts;
    [Category('Fast')]
    [Test]
    procedure SparseChildRowsInvalidateStoredSnapshot;
    [Category('Fast')]
    [Test]
    procedure StoresAndLoadsUnitSnapshotDenseFacts;
    [Category('Fast')]
    [Test]
    procedure SecondCacheInstanceReusesStoredUnitSnapshot;
    [Category('Fast')]
    [Test]
    procedure SourcePathVariantsReuseStoredUnitSnapshotIdentity;
    [Category('Fast')]
    [Test]
    procedure SourceContextIncludeAndSchemaChangesMissWithoutIdentityWideEviction;
  end;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.Hash, System.IOUtils, System.StrUtils,
  System.SysUtils, System.Variants,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def, FireDAC.Stan.Intf,
  maxLogic.IOUtils,
  DelphiSemantics.Cache, DelphiSemantics.Cache.Sqlite, DelphiSemantics.GlobalVars, DelphiSemantics.ImportFacts,
  DelphiSemantics.Model,
  DelphiSemantics.Model.Json, DelphiSemantics.RemoveWith.Visibility,
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder, DelphiSemantics.Snapshot.Evidence, DelphiSemantics.Snapshot.OccurrenceCodec,
  DelphiSemantics.Snapshot.RemoveWith, DelphiSemantics.Snapshot.TargetIdentity, DelphiSemantics.WithBinding,
  Test.SnapshotEvidence.Support, Test.Support;

var
  GSnapshotSqliteTempRoot: string;

function SnapshotUnicodeText: string;
begin
  Result := 'Za' + #$017C + #$00F3 + #$0142 + #$0107 + '-' + #$6F22 + #$5B57;
end;

function SnapshotSqliteTempRoot: string;
begin
  if GSnapshotSqliteTempRoot = '' then
  begin
    GSnapshotSqliteTempRoot := CreateTestTempRoot('snapshot-sqlite-temp');
  end;
  TDirectory.CreateDirectory(GSnapshotSqliteTempRoot);
  Result := GSnapshotSqliteTempRoot;
end;

function CasePoolUnitSnapshot(const aRoot, aName, aSymbolName: string; const id: TSemanticUnitId;
  const aField, aReference: Boolean): TDelphiProjectSnapshot;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lSymbol: TSemanticSymbolFact;
  lReference: TSemanticReferenceFact;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnit := TUnitSnapshot.Create(id, lBuilder.Strings.Intern(TPath.Combine(aRoot, aName + '.pas')),
      lBuilder.Strings.Intern(aName));
    try
      if aReference then
      begin
        lReference := Default(TSemanticReferenceFact);
        lReference.NameId := lBuilder.Strings.Intern('Value');
        lReference.TargetUnitId := 1;
        lReference.TargetSymbolId := 1;
        lUnit.AddReference(lReference);
      end else begin
        lSymbol := Default(TSemanticSymbolFact);
        lSymbol.NameId := lBuilder.Strings.Intern(aSymbolName);
        if aField then
        begin
          lSymbol.KindId := lBuilder.Strings.Intern('field');
          lSymbol.OwnerTypeId := lBuilder.Strings.Intern('Holder');
        end else begin
          lSymbol.KindId := lBuilder.Strings.Intern('var');
          lSymbol.SemanticSymbolId := lBuilder.Strings.Intern('a|var|value');
        end;
        lUnit.AddSymbol(lSymbol);
      end;
      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

function CasePoolIdentity(const aRoot, aName: string): TDelphiSemanticSnapshotCacheIdentity;
begin
  Result := Default(TDelphiSemanticSnapshotCacheIdentity);
  Result.SourceFileName := TPath.Combine(aRoot, aName + '.pas');
  Result.CacheKey := THashSHA2.GetHashString(Result.SourceFileName);
  Result.IdentityKey := Result.CacheKey;
  Result.FileHash := THashSHA2.GetHashString(aName);
  Result.ContextHash := THashSHA2.GetHashString('case-probe');
  Result.IncludeGraphHash := THashSHA2.GetHashString('no-includes');
  Result.SchemaVersion := 'case-probe';
end;

procedure TSnapshotSqliteTests.UnitLoadBatchKeepsOneReadGeneration;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lWriter: TFDConnection;
  lIdentityA, lIdentityB: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModelA, lModelB: TDelphiSemanticUnitModel;
  lRoot, lDatabase: string;
begin
  lRoot := TempPath('ds697-batch-read-generation');
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lModelA := PhysicalEvidenceModel(lRoot, 'BatchA');
  lModelB := PhysicalEvidenceModel(lRoot, 'BatchB');
  lIdentityA := CasePoolIdentity(lRoot, 'BatchA');
  lIdentityB := CasePoolIdentity(lRoot, 'BatchB');
  lSnapshot := nil;
  lLoaded := nil;
  lCache := nil;
  lWriter := nil;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    lSnapshot := BuildProjectUnitSnapshotFromModels([lModelA], 0, 17, lMetrics);
    lCache.StoreUnitFromSnapshot(lIdentityA, lSnapshot, 0);
    FreeAndNil(lSnapshot);
    lSnapshot := BuildProjectUnitSnapshotFromModels([lModelB], 0, 19, lMetrics);
    lCache.StoreUnitFromSnapshot(lIdentityB, lSnapshot, 0);
    FreeAndNil(lSnapshot);
    lWriter := TFDConnection.Create(nil);
    lWriter.LoginPrompt := False;
    lWriter.Params.Values['DriverID'] := 'SQLite';
    lWriter.Params.Values['Database'] := lDatabase;
    lWriter.Params.Values['JournalMode'] := 'WAL';
    lWriter.Params.Values['LockingMode'] := 'Normal';
    lWriter.Params.Values['SharedCache'] := 'False';
    lWriter.Connected := True;
    lCache.BeginUnitLoadBatch([lIdentityB, lIdentityA]);
    try
      lWriter.ExecSQL('update snapshot_units set has_includes=0 where cache_key=' +
        QuotedStr(lIdentityB.CacheKey));
      Assert.IsTrue(lCache.TryLoadUnit(lIdentityA, lLoaded));
      AssertPhysicalEvidence(lLoaded, lModelA);
      FreeAndNil(lLoaded);
      Assert.IsTrue(lCache.TryLoadUnit(lIdentityB, lLoaded),
        'A batch must load every unit from its captured read generation.');
      AssertPhysicalEvidence(lLoaded, lModelB);
      FreeAndNil(lLoaded);
    finally
      lCache.EndUnitLoadBatch;
    end;
    Assert.IsFalse(lCache.TryLoadUnit(lIdentityB, lLoaded),
      'A later load must validate the has_includes mutation, without reusing the prior batch.');
    Assert.IsNull(lLoaded);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentityA, lLoaded));
    AssertPhysicalEvidence(lLoaded, lModelA);
  finally
    lWriter.Free;
    lLoaded.Free;
    lSnapshot.Free;
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.UnitLoadBatchRejectsOnlyCorruptUnit(const aMutation: string);
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentityA, lIdentityB, lMissing: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModelA, lModelB: TDelphiSemanticUnitModel;
  lRoot, lDatabase, lSql: string;
begin
  lRoot := TempPath('ds697-batch-corrupt-' + aMutation);
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lModelA := PhysicalEvidenceModel(lRoot, 'ValidA');
  lModelB := PhysicalEvidenceModel(lRoot, 'CorruptB');
  lIdentityA := CasePoolIdentity(lRoot, 'ValidA');
  lIdentityB := CasePoolIdentity(lRoot, 'CorruptB');
  lMissing := CasePoolIdentity(lRoot, 'Missing');
  lSnapshot := nil;
  lLoaded := nil;
  lCache := nil;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    lSnapshot := BuildProjectUnitSnapshotFromModels([lModelA], 0, 17, lMetrics);
    lCache.StoreUnitFromSnapshot(lIdentityA, lSnapshot, 0);
    FreeAndNil(lSnapshot);
    lSnapshot := BuildProjectUnitSnapshotFromModels([lModelB], 0, 19, lMetrics);
    lCache.StoreUnitFromSnapshot(lIdentityB, lSnapshot, 0);
    FreeAndNil(lSnapshot);
    FreeAndNil(lCache);
    if aMutation = 'includes' then
      lSql := 'update snapshot_units set has_includes=0'
    else if aMutation = 'count' then
      lSql := 'update snapshot_units set captured_source_count=captured_source_count+1'
    else if aMutation = 'ordinal' then
      lSql := 'update snapshot_captured_sources set source_ordinal=source_ordinal+100'
    else if aMutation = 'unit' then
      lSql := 'update snapshot_captured_sources set unit_id=99'
    else if aMutation = 'status' then
      lSql := 'update snapshot_captured_sources set status=99'
    else if aMutation = 'import' then
      lSql := 'update snapshot_visible_units set import_ordinal=99'
    else if aMutation = 'blob' then
      lSql := 'update snapshot_unit_occurrences set payload=x''ff'''
    else if aMutation = 'lineage' then
      lSql := 'update snapshot_target_lineage set payload=x''ff'''
    else if aMutation = 'hash' then
      lSql := 'update snapshot_exact_strings set source_content_hash=' + QuotedStr(StringOfChar('0', 64))
    else if aMutation = 'null' then
      lSql := 'update snapshot_references set line=null'
    else if aMutation = 'negative' then
      lSql := 'update snapshot_references set line=-1'
    else if aMutation = 'overflow' then
      lSql := 'update snapshot_references set target_unit_id=4294967296'
    else if aMutation = 'symbol' then
      lSql := 'update snapshot_symbols set name_id=4294967296'
    else if aMutation = 'type' then
      lSql := 'update snapshot_units set unit_id=''invalid'''
    else if aMutation = 'possible-header' then
      lSql := 'delete from snapshot_possible_imports'
    else if aMutation = 'possible-order' then
      lSql := 'update snapshot_possible_imports set item_index=7'
    else if aMutation = 'possible-count' then
      lSql := 'update snapshot_possible_imports set import_count=import_count+1'
    else if aMutation = 'possible-type' then
      lSql := 'update snapshot_possible_imports set import_count=''invalid'''
    else if aMutation = 'provenance-missing' then
      lSql := 'delete from snapshot_import_facts'
    else if aMutation = 'provenance-payload' then
      lSql := 'update snapshot_import_facts set payload=''{}'''
    else if aMutation = 'provenance-count' then
      lSql := 'update snapshot_import_facts set fact_count=fact_count+1'
    else if aMutation = 'provenance-overflow' then
      lSql := 'update snapshot_import_facts set fact_count=4294967296'
    else
      raise EInvalidOpException.Create('Unknown batch mutation.');
    if aMutation = 'null' then
    begin
      // Only this damaged-cache fixture omits NOT NULL constraints, so the
      // reader must reject nulls even when a database was externally rewritten.
      ExecCacheSql(lDatabase, 'create table nullable_references as select * from snapshot_references');
      ExecCacheSql(lDatabase, 'drop table snapshot_references');
      ExecCacheSql(lDatabase, 'alter table nullable_references rename to snapshot_references');
    end;
    lSql := lSql + ' where unit_key=(select unit_key from snapshot_units where cache_key=' +
      QuotedStr(lIdentityB.CacheKey) + ')';
    if aMutation = 'hash' then
      lSql := lSql + ' and source_content_hash is not null';
    ExecCacheSql(lDatabase, lSql);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    lCache.BeginUnitLoadBatch([lIdentityB, lMissing, lIdentityA, lIdentityA]);
    try
      Assert.IsFalse(lCache.TryLoadUnit(lIdentityB, lLoaded), aMutation);
      Assert.IsNull(lLoaded);
      Assert.IsTrue(lCache.LastInvalidationReason <> '', aMutation);
      Assert.IsTrue(lCache.TryLoadUnit(lIdentityA, lLoaded),
        'An unusable unit must not prevent another unit from being reused.');
      AssertPhysicalEvidence(lLoaded, lModelA);
      FreeAndNil(lLoaded);
      Assert.IsFalse(lCache.TryLoadUnit(lMissing, lLoaded));
      Assert.IsNull(lLoaded);
      Assert.IsFalse(lCache.TryLoadUnit(lIdentityB, lLoaded),
        'An invalidated entry must stay unavailable inside the batch.');
      Assert.IsNull(lLoaded);
    finally
      lCache.EndUnitLoadBatch;
    end;
    FreeAndNil(lCache);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentityA, lLoaded));
    AssertPhysicalEvidence(lLoaded, lModelA);
    FreeAndNil(lLoaded);
    Assert.IsFalse(lCache.TryLoadUnit(lIdentityB, lLoaded));
    Assert.IsNull(lLoaded);
  finally
    lLoaded.Free;
    lSnapshot.Free;
    lCache.Free;
  end;
end;

function EvidenceBlobSql(const aPayload: TBytes): string;
var
  b: Byte;
begin
  Result := 'x' + #39;
  for b in aPayload do
    Result := Result + IntToHex(b, 2);
  Result := Result + #39;
end;

procedure TSnapshotSqliteTests.AvailableSymbolsRejectMalformedProjection(const aBatch: Boolean);
var
  lRoot, lDatabase: string;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot, lLoaded: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lValues: TArray<Int64>;
begin
  lRoot := TempPath('malformed-available-symbol-' + BoolToStr(aBatch, True));
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lModel := PhysicalEvidenceModel(lRoot, 'MalformedSymbol');
  lIdentity := CasePoolIdentity(lRoot, 'MalformedSymbol');
  lSnapshot := BuildProjectUnitSnapshotFromModels([lModel], 0, 19, lMetrics);
  lLoaded := nil;
  lCache := nil;
  try
    Assert.IsTrue(lSnapshot.UnitByIndex(0).PhysicalSymbolOccurrencesAvailable);
    lValues := DecodeOccurrenceValues(PackPhysicalOccurrences(lSnapshot.UnitByIndex(0), 1),
      lSnapshot.UnitByIndex(0).PhysicalSymbolOccurrenceCount, cPhysicalSymbolColumnCount);
    Assert.IsTrue(Length(lValues) >= cPhysicalSymbolColumnCount);
    lValues[14] := 0;
    lValues[15] := cPhysicalProjectionMalformed;
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    FreeAndNil(lCache);
    ExecCacheSql(lDatabase, 'update snapshot_unit_occurrences set payload=' +
      EvidenceBlobSql(EncodeOccurrenceValues(lValues, cPhysicalSymbolColumnCount)) +
      ' where collection=1 and unit_key=(select unit_key from snapshot_units where cache_key=' +
      QuotedStr(lIdentity.CacheKey) + ')');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    if aBatch then
      lCache.BeginUnitLoadBatch([lIdentity]);
    try
      Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lLoaded),
        'Malformed symbol evidence cannot coexist with an available header.');
      Assert.IsNull(lLoaded);
      Assert.IsTrue(ContainsText(lCache.LastInvalidationReason, 'SNAPSHOT_EVIDENCE_LINK_INVALID'));
    finally
      if aBatch then
        lCache.EndUnitLoadBatch;
    end;
  finally
    lLoaded.Free;
    lCache.Free;
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.IncludedPathsKeepOriginalSpelling(const aPhysicalOnly: Boolean);
var
  lRoot, lInclude: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSnapshot, lLoaded: TDelphiProjectSnapshot;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  i, lCount: Integer;
begin
  lRoot := TempPath('OriginalIncludeSpelling');
  TDirectory.CreateDirectory(lRoot);
  lInclude := TPath.Combine(lRoot, 'MixedCaseBody.inc');
  TFile.WriteAllText(lInclude, 'GF := 7;', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'PathUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit PathUnit;'#13#10'interface'#13#10'var GF: Integer;'#13#10'implementation'#13#10 +
    'procedure Run;'#13#10'begin'#13#10'{$I MixedCaseBody.inc}'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  if aPhysicalOnly then
    lModel.References := nil;
  lSnapshot := BuildProjectUnitSnapshotFromModels([lModel], 0, 19, lMetrics);
  lCache := nil;
  lLoaded := nil;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'cache.db'));
    lIdentity := CasePoolIdentity(lRoot, 'PathUnit');
    lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    FreeAndNil(lCache);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'cache.db'));
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoaded));
    for i := 0 to 2 do
    begin
      if i = 0 then
        lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits([lModel])
      else if i = 1 then
        lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot)
      else
        lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lLoaded);
      lCount := 0;
      for var lUsage in lAnalysis.Usages do
        if lUsage.Name = 'GF' then
        begin
          Inc(lCount);
          Assert.AreEqual(lInclude, lUsage.FileName, False, 'Reports preserve original include-path spelling.');
        end;
      Assert.AreEqual(1, lCount);
    end;
  finally
    lLoaded.Free;
    lCache.Free;
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.PhysicalOccurrencePayloadRejectsMalformedData(const aMutation: string);
var
  i, j, lCount, lAttempts: Integer;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot, lLoaded: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lRoot, lDatabase, lSql: string;
  lPayload, lBad: TBytes;
  lValues: TArray<Int64>;
  lRandom: Cardinal;
begin
  lRoot := TempPath('physical-codec-' + aMutation);
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lModel := PhysicalEvidenceModel(lRoot, 'CodecUnit');
  lIdentity := CasePoolIdentity(lRoot, 'CodecUnit');
  lSnapshot := BuildProjectUnitSnapshotFromModels([lModel], 0, 19, lMetrics);
  lCache := nil;
  lLoaded := nil;
  try
    lCount := lSnapshot.UnitByIndex(0).PhysicalReferenceOccurrenceCount;
    SetLength(lValues, lCount * cPhysicalReferenceColumnCount);
    // A literal valid unverified record set exercises the codec separately
    // from the builder's choice of IDs and token coordinates.
    lPayload := EncodeOccurrenceValues(lValues, cPhysicalReferenceColumnCount);
    lAttempts := 1;
    if aMutation = 'truncated' then
      lAttempts := Length(lPayload);
    if aMutation = 'fuzz' then
      lAttempts := 300;
    lRandom := $697691;
    for i := 0 to lAttempts - 1 do
    begin
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
      FreeAndNil(lCache);
      lBad := Copy(lPayload);
      if aMutation = 'truncated' then
        SetLength(lBad, i)
      else if aMutation = 'trailing' then
        lBad := lBad + [0]
      else if aMutation = 'format' then
        lBad[0] := 2
      else if aMutation = 'overlong' then
        lBad := [1, $80, 0] + Copy(lPayload, 2, MaxInt)
      else if (aMutation = 'overflow') or (aMutation = 'continued') then
      begin
        lBad := [1, $80, $80, $80, $80, $80, $80, $80, $80, $80, 2] + Copy(lPayload, 2, MaxInt);
        if aMutation = 'continued' then
          lBad[10] := $80;
      end else if aMutation = 'semantic' then
      begin
        lValues[0] := High(Cardinal);
        lBad := EncodeOccurrenceValues(lValues, cPhysicalReferenceColumnCount);
      end else if (aMutation = 'binding') or (aMutation = 'binding-unverified') then
      begin
        lValues[13] := 1;
        if aMutation = 'binding' then
          lValues[13] := High(Cardinal);
        lBad := EncodeOccurrenceValues(lValues, cPhysicalReferenceColumnCount);
      end else if aMutation = 'fuzz' then
      begin
        lRandom := lRandom xor (lRandom shl 13);
        lRandom := lRandom xor (lRandom shr 17);
        lRandom := lRandom xor (lRandom shl 5);
        SetLength(lBad, Integer(lRandom mod (Length(lPayload) + 15)));
        for j := 0 to High(lBad) do
        begin
          lRandom := lRandom xor (lRandom shl 13);
          lRandom := lRandom xor (lRandom shr 17);
          lRandom := lRandom xor (lRandom shl 5);
          lBad[j] := Byte(lRandom and $FF);
        end;
      end;
      lSql := 'update snapshot_unit_occurrences set payload=' + EvidenceBlobSql(lBad) +
        ' where unit_key=(select unit_key from snapshot_units where cache_key=' +
        QuotedStr(lIdentity.CacheKey) + ') and collection=0';
      if aMutation = 'missing' then
        lSql := 'delete from snapshot_unit_occurrences where unit_key=(select unit_key from snapshot_units where cache_key=' +
          QuotedStr(lIdentity.CacheKey) + ')' +
          ' and collection=0'
      else if aMutation = 'extra' then
        lSql := 'insert into snapshot_unit_occurrences select unit_key,unit_id,2,payload ' +
          'from snapshot_unit_occurrences where unit_key=(select unit_key from snapshot_units where cache_key=' +
          QuotedStr(lIdentity.CacheKey) + ') and collection=0'
      else if aMutation = 'count' then
        lSql := 'update snapshot_units set physical_reference_count=physical_reference_count+1 where cache_key=' +
          QuotedStr(lIdentity.CacheKey);
      ExecCacheSql(lDatabase, lSql);
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
      if aMutation = 'fuzz' then
      begin
        if lCache.TryLoadUnit(lIdentity, lLoaded) then
        begin
          // A randomly valid payload may publish only through the full strict
          // loader; exercise its owned/frozen result and both collection counts.
          Assert.AreEqual(lCount, lLoaded.UnitByIndex(0).PhysicalReferenceOccurrenceCount);
          Assert.AreEqual(lSnapshot.UnitByIndex(0).PhysicalSymbolOccurrenceCount,
            lLoaded.UnitByIndex(0).PhysicalSymbolOccurrenceCount);
          FreeAndNil(lLoaded);
        end else
          Assert.IsNull(lLoaded);
      end else begin
        Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lLoaded), aMutation + ':' + IntToStr(i));
        Assert.IsNull(lLoaded);
        Assert.IsNotEmpty(lCache.LastInvalidationReason);
      end;
      FreeAndNil(lCache);
    end;
  finally
    lLoaded.Free;
    lCache.Free;
    lSnapshot.Free;
  end;
end;

function MinimalPhysicalSnapshot(const aRoot, aName, aCollection, aText: string;
  const aAvailable: Boolean): TDelphiProjectSnapshot;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lUnit: TUnitSnapshot;
  lFileId, lIncludeId, lTextId: TSemanticStringId;
  lSource: TSemanticCapturedSourceFact;
  lReference: TSemanticPhysicalReferenceOccurrence;
  lSymbol: TSemanticPhysicalSymbolOccurrence;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileId := lBuilder.Strings.Intern(TDelphiSemanticCacheIdentityBuilder.CanonicalPath(
      TPath.Combine(aRoot, aName + '.pas')));
    lIncludeId := lBuilder.Strings.Intern(TDelphiSemanticCacheIdentityBuilder.CanonicalPath(
      TPath.Combine(aRoot, 'shared.inc')));
    lTextId := lBuilder.ExactStrings.Intern(aText);
    lUnit := TUnitSnapshot.Create(1, lFileId, lBuilder.Strings.Intern(aName), lTextId);
    lBuilder.AddUnit(lUnit);
    lUnit.SetHasIncludes(True);
    if aCollection = 'source' then
    begin
      lSource := Default(TSemanticCapturedSourceFact);
      lSource.FileId := lIncludeId;
      lSource.TextId := lTextId;
      if aText = '' then
        lSource.Status := cCapturedSourceUnavailable
      else
        lSource.Status := cCapturedSourceText;
      lUnit.SetCapturedSources([lSource], aAvailable);
    end else if aCollection = 'reference' then
    begin
      lReference := Default(TSemanticPhysicalReferenceOccurrence);
      lReference.FileId := lIncludeId;
      lUnit.SetPhysicalReferenceOccurrences([lReference], aAvailable);
    end else if aCollection = 'symbol' then
    begin
      lSymbol := Default(TSemanticPhysicalSymbolOccurrence);
      lSymbol.FileId := lIncludeId;
      lSymbol.FactKindId := lBuilder.Strings.Intern('routine');
      lSymbol.KindId := lBuilder.Strings.Intern('body');
      lSymbol.ParentFactIndex := -1;
      lUnit.SetPhysicalSymbolOccurrences([lSymbol], aAvailable);
    end;
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

procedure TSnapshotSqliteTests.HasIncludesMutationRejectsEveryNonrootCollection(
  const aCollection: string; const aAvailable: Boolean);
var
  lRoot, lDatabase: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot, lLoaded: TDelphiProjectSnapshot;
  lCache: TDelphiSemanticSnapshotSqliteCache;
begin
  lRoot := TempPath('has-includes-' + aCollection + BoolToStr(aAvailable, True));
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lIdentity := CasePoolIdentity(lRoot, 'Owner');
  lSnapshot := MinimalPhysicalSnapshot(lRoot, 'Owner', aCollection, '', aAvailable);
  lLoaded := nil;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
  try
    lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    FreeAndNil(lCache);
    ExecCacheSql(lDatabase, 'update snapshot_units set has_includes=0');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lLoaded));
    Assert.IsNull(lLoaded);
    Assert.IsTrue(ContainsText(lCache.LastInvalidationReason, 'HAS_INCLUDES'));
  finally
    lCache.Free;
    lLoaded.Free;
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.SharedSourceTextReplacementAndGcAreAtomic;
var
  lRoot, lDatabase: string;
  lIdentityA, lIdentityB: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshotA, lSnapshotB, lReplacementA, lReplacementB, lFailed, lLoaded: TDelphiProjectSnapshot;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lRejected: Boolean;
begin
  lRoot := TempPath('shared-text-atomic');
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lIdentityA := CasePoolIdentity(lRoot, 'OwnerA');
  lIdentityB := CasePoolIdentity(lRoot, 'OwnerB');
  lSnapshotA := MinimalPhysicalSnapshot(lRoot, 'OwnerA', 'source', 'one'#13#10#0 + Chr($E9) + '  ', True);
  lSnapshotB := MinimalPhysicalSnapshot(lRoot, 'OwnerB', 'source', 'one'#13#10#0 + Chr($E9) + '  ', True);
  lReplacementA := MinimalPhysicalSnapshot(lRoot, 'OwnerA', 'source', 'two'#10' ', True);
  lReplacementB := MinimalPhysicalSnapshot(lRoot, 'OwnerB', 'source', 'two'#10' ', True);
  lFailed := MinimalPhysicalSnapshot(lRoot, 'OwnerA', 'source', 'three', True);
  lLoaded := nil;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
  try
    lCache.StoreUnitFromSnapshot(lIdentityA, lSnapshotA, 0);
    lCache.StoreUnitFromSnapshot(lIdentityB, lSnapshotB, 0);
    FreeAndNil(lCache);
    Assert.AreEqual(1, TableRowCount(lDatabase, 'snapshot_source_texts'),
      'Equal root/include source text shares one backing across keys.');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentityA, lLoaded));
    Assert.AreEqual('one'#13#10#0 + Chr($E9) + '  ', lLoaded.ExactTextOf(lLoaded.UnitByIndex(0).SourceTextId));
    FreeAndNil(lLoaded);
    lCache.StoreUnitFromSnapshot(lIdentityA, lReplacementA, 0);
    FreeAndNil(lCache);
    Assert.AreEqual(2, TableRowCount(lDatabase, 'snapshot_source_texts'), 'Other unit retains the first hash.');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    lCache.StoreUnitFromSnapshot(lIdentityB, lReplacementB, 0);
    FreeAndNil(lCache);
    Assert.AreEqual(1, TableRowCount(lDatabase, 'snapshot_source_texts'), 'Last reference collects the orphan.');
    // Move B away so replacing A removes the last reference to its old text.
    FreeAndNil(lReplacementB);
    lReplacementB := MinimalPhysicalSnapshot(lRoot, 'OwnerB', 'source', 'kept by B', True);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    lCache.StoreUnitFromSnapshot(lIdentityB, lReplacementB, 0);
    FreeAndNil(lCache);
    Assert.AreEqual(2, TableRowCount(lDatabase, 'snapshot_source_texts'));
    ExecCacheSql(lDatabase, 'create trigger fail_gc before delete on snapshot_source_texts ' +
      'begin select raise(ABORT,' + QuotedStr('owned GC failure') + '); end');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    lRejected := False;
    try
      lCache.StoreUnitFromSnapshot(lIdentityA, lFailed, 0);
    except
      on E: Exception do
      begin
        lRejected := ContainsText(E.Message, 'owned GC failure');
        if not lRejected then
          raise;
      end;
    end;
    Assert.IsTrue(lRejected, 'The failure must occur inside orphan collection.');
    FreeAndNil(lCache);
    Assert.AreEqual(2, TableRowCount(lDatabase, 'snapshot_source_texts'), 'GC and insertion roll back together.');
    ExecCacheSql(lDatabase, 'drop trigger fail_gc');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentityA, lLoaded));
    Assert.AreEqual('two'#10' ', lLoaded.ExactTextOf(lLoaded.UnitByIndex(0).SourceTextId));
    FreeAndNil(lLoaded);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentityB, lLoaded));
    Assert.AreEqual('kept by B', lLoaded.ExactTextOf(lLoaded.UnitByIndex(0).SourceTextId));
  finally
    lLoaded.Free;
    lCache.Free;
    lFailed.Free;
    lReplacementB.Free;
    lReplacementA.Free;
    lSnapshotB.Free;
    lSnapshotA.Free;
  end;
end;

procedure TSnapshotSqliteTests.SharedSourceTextRejectsCorruptBacking(const aMutation: string);
var
  lRoot, lDatabase, lSql: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot, lLoaded: TDelphiProjectSnapshot;
  lCache: TDelphiSemanticSnapshotSqliteCache;
begin
  lRoot := TempPath('shared-text-corrupt-' + aMutation);
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lIdentity := CasePoolIdentity(lRoot, 'Owner');
  lSnapshot := MinimalPhysicalSnapshot(lRoot, 'Owner', 'source', 'text'#13#10' ', True);
  lLoaded := nil;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
  try
    lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    FreeAndNil(lCache);
    if aMutation = 'text' then
      lSql := 'update snapshot_source_texts set text=' + QuotedStr('changed')
    else if aMutation = 'hash' then
      lSql := 'update snapshot_exact_strings set source_content_hash=' + QuotedStr('INVALID') +
        ' where source_content_hash is not null'
    else if aMutation = 'missing' then
      lSql := 'delete from snapshot_source_texts'
    else
      lSql := 'update snapshot_exact_strings set text_value=' + QuotedStr('inline and shared') +
        ' where source_content_hash is not null';
    if aMutation = 'backing' then
    begin
      // Damage only this fixture's table so loader validation is exercised even
      // when the database no longer has its normal schema CHECK constraint.
      ExecCacheSql(lDatabase, 'alter table snapshot_exact_strings rename to damaged_exact_strings');
      ExecCacheSql(lDatabase, 'create table snapshot_exact_strings as select * from damaged_exact_strings');
      ExecCacheSql(lDatabase, 'drop table damaged_exact_strings');
    end;
    ExecCacheSql(lDatabase, lSql);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lLoaded));
    Assert.IsNull(lLoaded);
    Assert.IsNotEmpty(lCache.LastInvalidationReason);
  finally
    lCache.Free;
    lLoaded.Free;
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.ChildRowsUseIntegerOwnerKeys(const aProject: Boolean);
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lSnapshot: TDelphiProjectSnapshot;
  lCacheFileName, lParent, lOwner, lTable: string;
  lTables: TArray<string>;
  lQuery: TFDQuery;
  lFound: Boolean;
begin
  lCacheFileName := TempPath('snapshot-integer-owner-' + BoolToStr(aProject, True) + '.sqlite3');
  lIdentity := CreateIdentity('IntegerOwner', 'file-a', 'context-a', 'include-a', 'snapshot-v1');
  lParent := 'snapshot_units';
  lOwner := 'unit_key';
  lTables := ['snapshot_strings', 'snapshot_exact_strings', 'snapshot_symbols',
    'snapshot_references', 'snapshot_with_statements', 'snapshot_captured_sources',
    'snapshot_unit_occurrences', 'snapshot_visible_units', 'snapshot_target_lineage',
    'snapshot_possible_imports', 'snapshot_import_facts'];
  if aProject then
  begin
    lParent := 'snapshot_project_remove_with_facts';
    lOwner := 'project_key';
    lTables := ['snapshot_project_exact_strings', 'snapshot_remove_with_facts',
      'snapshot_remove_with_value_evidence', 'snapshot_remove_with_visibility',
      'snapshot_remove_with_visible_units', 'snapshot_remove_with_routine_owners',
      'snapshot_remove_with_symbols', 'snapshot_remove_with_bindings',
      'snapshot_remove_with_binding_selectors', 'snapshot_remove_with_binding_references',
      'snapshot_remove_with_type_identities'];
    lBuilder := TDelphiProjectSnapshotBuilder.Create;
    try
      lFacts := Default(TSemanticRemoveWithPlanningFacts);
      lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('IntegerOwnerContext');
      lBuilder.SetRemoveWithPlanningFacts(lFacts);
      lSnapshot := lBuilder.Build;
    finally
      lBuilder.Free;
    end;
    try
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
      try
        lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot);
      finally
        lCache.Free;
      end;
    finally
      lSnapshot.Free;
    end;
  end else begin
    StoreDemoUnit(lCacheFileName, lIdentity);
  end;
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  lQuery := TFDQuery.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := lCacheFileName;
    lConnection.Connected := True;
    lQuery.Connection := lConnection;
    // Match the full-width SQLite integer mapping used by cache reads.
    lQuery.FormatOptions.OwnMapRules := True;
    lQuery.FormatOptions.MapRules.Add(dtInt32, dtInt64);
    for lTable in lTables do
    begin
      lQuery.SQL.Text := 'pragma table_info(' + lTable + ')';
      lQuery.Open;
      lFound := False;
      while not lQuery.Eof do
      begin
        Assert.AreNotEqual('cache_key', lQuery.Fields[1].AsWideString,
          lTable + ' must not repeat the text cache key');
        if lQuery.Fields[1].AsWideString = lOwner then
        begin
          lFound := True;
          Assert.AreEqual('INTEGER', UpperCase(lQuery.Fields[2].AsWideString));
          Assert.AreEqual(1, lQuery.Fields[5].AsInteger, lTable + ' owner leads its primary key');
        end;
        lQuery.Next;
      end;
      lQuery.Close;
      Assert.IsTrue(lFound, lTable + ' must have an integer owner');
      lQuery.SQL.Text := 'select count(*) from ' + lTable + ' c left join ' + lParent +
        ' p on p.rowid=c.' + lOwner + ' where p.rowid is null or typeof(c.' + lOwner + ')<>''integer''';
      lQuery.Open;
      Assert.AreEqual(0, lQuery.Fields[0].AsInteger, lTable + ' rows belong to the parent rowid');
      lQuery.Close;
    end;
    lQuery.SQL.Text := 'select count(*) from ' + lParent + ' where rowid<>' + lOwner;
    lQuery.Open;
    Assert.AreEqual(0, lQuery.Fields[0].AsInteger, 'The explicit key aliases rowid');
    lQuery.Close;
    // Exercise 64-bit ownership independently of the small semantic UnitId.
    lConnection.StartTransaction;
    for lTable in lTables do
      lConnection.ExecSQL('update ' + lTable + ' set ' + lOwner + '=4294967296');
    lConnection.ExecSQL('update ' + lParent + ' set ' + lOwner + '=4294967296');
    lConnection.Commit;
    // An INTEGER PRIMARY KEY alias remains stable when SQLite compacts the file.
    lConnection.ExecSQL('vacuum');
    lQuery.SQL.Text := 'select rowid, ' + lOwner + ' from ' + lParent;
    lQuery.Open;
    Assert.AreEqual<Int64>(4294967296, lQuery.Fields[0].AsLargeInt,
      'The parent rowid survives vacuum without 32-bit narrowing');
    Assert.AreEqual<Int64>(lQuery.Fields[0].AsLargeInt, lQuery.Fields[1].AsLargeInt);
    lQuery.Close;
  finally
    lQuery.Free;
    lConnection.Free;
    lDriverLink.Free;
  end;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  lLoaded := nil;
  try
    if aProject then
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoaded))
    else
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoaded));
    Assert.IsNotNull(lLoaded);
  finally
    lLoaded.Free;
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.PhysicalOccurrencesSurviveSqliteRoundTrip;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lRoot, lDatabase: string;
begin
  lRoot := TempPath('ds697-all-evidence');
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lModel := PhysicalEvidenceModel(lRoot, 'Evidence');
  lSnapshot := nil;
  lLoaded := nil;
  lCache := nil;
  try
    lSnapshot := BuildProjectUnitSnapshotFromModels([lModel], 0, 17, lMetrics);
    lIdentity := CasePoolIdentity(lRoot, 'Evidence');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    try
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    except
      on E: Exception do
        Assert.Fail('Valid original symbol associations must store: ' + E.Message);
    end;
    FreeAndNil(lCache);
    FreeAndNil(lSnapshot);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoaded), 'Complete physical evidence must reload');
    AssertPhysicalEvidence(lLoaded, lModel);
  finally
    lCache.Free;
    lLoaded.Free;
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.PackedTargetLineageUsesOneBlobPerUnit;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lConnection: TFDConnection;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lSnapshot: TDelphiProjectSnapshot;
  lQuery: TFDQuery;
  lRoot, lDatabase: string;
begin
  lRoot := TempPath('ds794-packed-lineage');
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lIdentity := CasePoolIdentity(lRoot, 'BTarget');
  lSnapshot := CasePoolUnitSnapshot(lRoot, 'BTarget', 'Value', 1, True, False);
  lLoaded := nil;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
  try
    lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    FreeAndNil(lCache);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoaded));
    lConnection := TFDConnection.Create(nil);
    try
      lConnection.Params.Values['DriverID'] := 'SQLite';
      lConnection.Params.Values['Database'] := lDatabase;
      lConnection.LoginPrompt := False;
      lConnection.Connected := True;
      lQuery := TFDQuery.Create(nil);
      try
        lQuery.Connection := lConnection;
        lQuery.SQL.Text := 'select count(*) from sqlite_master where type=''table'' and name=''snapshot_target_lineage''';
        lQuery.Open;
        Assert.AreEqual(1, lQuery.Fields[0].AsInteger,
          'Target evidence must use the packed per-unit lineage table');
        lQuery.Close;
        lQuery.SQL.Text := 'select count(*) from snapshot_target_lineage where length(payload)>1 and value_count>0';
        lQuery.Open;
        Assert.AreEqual(1, lQuery.Fields[0].AsInteger);
      finally
        lQuery.Free;
      end;
    finally
      lConnection.Free;
    end;
  finally
    lCache.Free;
    lLoaded.Free;
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.PackedTargetLineageRejectsCorruption(const aMutation: string);
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoaded, lSnapshot: TDelphiProjectSnapshot;
  lDatabase, lRoot, lSql: string;
begin
  lRoot := TempPath('ds794-lineage-' + aMutation);
  TDirectory.CreateDirectory(lRoot);
  lDatabase := TPath.Combine(lRoot, 'cache.db');
  lIdentity := CasePoolIdentity(lRoot, 'BTarget');
  lSnapshot := CasePoolUnitSnapshot(lRoot, 'BTarget', 'Value', 1, True, False);
  lLoaded := nil;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
  try
    lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    FreeAndNil(lCache);
    if aMutation = 'format' then
      lSql := 'payload=cast(x''ff'' || substr(payload,2) as blob)'
    else if aMutation = 'truncated' then
      lSql := 'payload=substr(payload,1,length(payload)-1)'
    else if aMutation = 'trailing' then
      lSql := 'payload=cast(payload || x''00'' as blob)'
    else if aMutation = 'overlong' then
      lSql := 'payload=cast(substr(payload,1,1) || x''8000'' || substr(payload,3) as blob)'
    else if aMutation = 'overflow' then
      lSql := 'payload=cast(substr(payload,1,1) || x''80808080808080808002'' || substr(payload,3) as blob)'
    else if aMutation = 'negative-count' then
      lSql := 'value_count=-1'
    else if aMutation = 'count' then
      lSql := 'value_count=value_count+1'
    else if aMutation = 'unit' then
      lSql := 'unit_id=unit_id+1'
    else
      raise EArgumentException.Create('Unknown lineage corruption case.');
    ExecCacheSql(lDatabase, 'update snapshot_target_lineage set ' + lSql);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lLoaded),
      'Corrupt target lineage must invalidate before publication: ' + aMutation);
    Assert.IsNull(lLoaded);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
    Assert.AreEqual(0, TableRowCount(lDatabase, 'snapshot_target_lineage'));

    // A refused row must remain rebuildable and reusable after close/reopen.
    lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    FreeAndNil(lCache);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lDatabase);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoaded));
    Assert.AreEqual(1, lLoaded.UnitCount);
  finally
    lCache.Free;
    lLoaded.Free;
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.CachedTargetSurvivesCaseOnlyPoolSpelling;
var
  lRoot: string;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lOther, lTarget, lSource, lLoadedTarget, lLoadedSource, lMerged: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lResolver: TSnapshotTargetResolver;
begin
  lRoot := TempPath('ds794-case-pool');
  TDirectory.CreateDirectory(lRoot);
  lOther := nil;
  lTarget := nil;
  lSource := nil;
  lLoadedTarget := nil;
  lLoadedSource := nil;
  lMerged := nil;
  lCache := nil;
  lResolver := nil;
  try
    lOther := CasePoolUnitSnapshot(lRoot, 'AOther', 'value', 3, False, False);
    lTarget := CasePoolUnitSnapshot(lRoot, 'BTarget', 'Value', 1, True, False);
    lSource := CasePoolUnitSnapshot(lRoot, 'CSource', '', 2, False, True);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'cache.db'));
    lCache.StoreUnitFromSnapshot(CasePoolIdentity(lRoot, 'BTarget'), lTarget, 0);
    if not lCache.TryLoadUnit(CasePoolIdentity(lRoot, 'BTarget'), lLoadedTarget) then
      raise Exception.Create('Target did not hit');
    lMerged := BuildProjectSnapshotFromUnitSnapshots([lOther, lLoadedTarget, lSource], lMetrics);
    lCache.StoreUnitFromSnapshot(CasePoolIdentity(lRoot, 'CSource'), lMerged, 2);
    FreeAndNil(lCache);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(TPath.Combine(lRoot, 'cache.db'));
    if not lCache.TryLoadUnit(CasePoolIdentity(lRoot, 'CSource'), lLoadedSource) then
      raise Exception.Create('Source did not hit');
    lResolver := TSnapshotTargetResolver.Create([lLoadedSource, lLoadedTarget]);
    Assert.IsTrue(CachedSnapshotTargetsMatch(lLoadedSource, lResolver, False, []),
      'Case-only pool spelling must preserve a genuine source hit');
  finally
    lResolver.Free;
    lCache.Free;
    lMerged.Free;
    lLoadedSource.Free;
    lLoadedTarget.Free;
    lSource.Free;
    lTarget.Free;
    lOther.Free;
  end;
end;

procedure TSnapshotSqliteTests.AssertIdentityChangeMissesWithoutEviction(const aName: string;
  const aChangedIdentity: TDelphiSemanticSnapshotCacheIdentity);
var
  lBaseIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath(aName + '.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lBaseIdentity := CreateIdentity(aName, 'file-a', 'context-a', 'include-a', 'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lBaseIdentity);

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lSnapshot := nil;
    Assert.IsFalse(lCache.TryLoadUnit(aChangedIdentity, lSnapshot));
    Assert.IsNull(lSnapshot);
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
    Assert.AreEqual(1, lCache.Metrics.SnapshotCacheProbes);
    Assert.IsTrue(lCache.Metrics.SnapshotSqlReadMilliseconds >= 1);
    Assert.IsTrue(lCache.Metrics.SnapshotDeserializeMilliseconds >= 0);
    Assert.IsTrue(lCache.Metrics.SnapshotIndexRebuildMilliseconds >= 0);
    Assert.AreEqual(Int64(0), lCache.Metrics.SnapshotParseAvoidedEstimateMilliseconds);
    Assert.IsFalse(lCache.Metrics.SnapshotCacheUseful);
    Assert.IsTrue(lCache.TryLoadUnit(lBaseIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lCache.Free;
  end;
end;

function TSnapshotSqliteTests.CacheTextRowCount(const aCacheFileName, aTableName, aCacheKey,
  aTextValue: string): Integer;
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lQuery: TFDQuery;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Connected := True;
    lQuery := TFDQuery.Create(nil);
    try
      lQuery.Connection := lConnection;
      lQuery.SQL.Text := 'select count(*) from ' + aTableName +
        ' where unit_key = (select unit_key from snapshot_units where cache_key = ?) and text_value = ?';
      lQuery.Params[0].AsWideString := aCacheKey;
      lQuery.Params[1].AsWideString := aTextValue;
      lQuery.Open;
      Result := lQuery.Fields[0].AsInteger;
    finally
      lQuery.Free;
    end;
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

function TSnapshotSqliteTests.CreateConcurrencyIdentity(const aCacheFileName,
  aName: string): TDelphiSemanticSnapshotCacheIdentity;
begin
  Result := CreateIdentity('SnapshotConcurrency' + aName, 'file-' + aName, 'context-a',
    'include-a', 'snapshot-v1');
  Result.SourceFileName := TPath.Combine(ExtractFilePath(aCacheFileName),
    Result.IdentityKey + '.pas');
end;

function TSnapshotSqliteTests.CreateIdentity(const aName, aFileHash, aContextHash,
  aIncludeGraphHash, aSchemaVersion: string): TDelphiSemanticSnapshotCacheIdentity;
begin
  Result.IdentityKey := aName;
  Result.SourceFileName := TempPath(aName + '.pas');
  Result.FileHash := aFileHash;
  Result.ContextHash := aContextHash;
  Result.IncludeGraphHash := aIncludeGraphHash;
  Result.SchemaVersion := aSchemaVersion;
  Result.ParseAvoidedEstimateMilliseconds := 60000;
  Result.CacheKey := aName + '|' + aFileHash + '|' + aContextHash + '|' + aIncludeGraphHash +
    '|' + aSchemaVersion;
end;

procedure TSnapshotSqliteTests.CacheKeyReuseWithDifferentIdentityDoesNotLoadStoredUnit;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lOtherIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lStoredIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-cache-key-identity.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lStoredIdentity := CreateIdentity('SnapshotStoredIdentityUnit', 'file-a', 'context-a',
    'include-a', 'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lStoredIdentity);
  lOtherIdentity := lStoredIdentity;
  lOtherIdentity.IdentityKey := 'SnapshotOtherIdentityUnit';

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lSnapshot := nil;
    try
      Assert.IsFalse(lCache.TryLoadUnit(lOtherIdentity, lSnapshot));
      Assert.IsNull(lSnapshot);
    finally
      lSnapshot.Free;
      lSnapshot := nil;
    end;
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
    Assert.IsTrue(lCache.TryLoadUnit(lStoredIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.ContextSpecificSnapshotVariantsShareIdentityWithoutEviction;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lFirstIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSecondIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
  lStaleIdentity: TDelphiSemanticSnapshotCacheIdentity;
begin
  lCacheFileName := TempPath('snapshot-context-variants.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lFirstIdentity := CreateIdentity('SnapshotContextVariantUnit', 'file-a', 'context-a',
    'include-a', 'snapshot-v1');
  lSecondIdentity := CreateIdentity('SnapshotContextVariantUnit', 'file-a', 'context-b',
    'include-a', 'snapshot-v1');

  StoreDemoUnit(lCacheFileName, lFirstIdentity);
  StoreDemoUnit(lCacheFileName, lSecondIdentity);

  Assert.AreEqual(2, TableRowCount(lCacheFileName, 'snapshot_units'));

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    Assert.IsTrue(lCache.TryLoadUnit(lFirstIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
    Assert.IsTrue(lCache.TryLoadUnit(lSecondIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
    Assert.IsTrue(lCache.TryLoadUnit(lFirstIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;

    lStaleIdentity := lFirstIdentity;
    lStaleIdentity.FileHash := 'file-stale';
    Assert.IsFalse(lCache.TryLoadUnit(lStaleIdentity, lSnapshot));
    Assert.IsNull(lSnapshot);
    Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_units'));
    Assert.IsTrue(lCache.TryLoadUnit(lSecondIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
    Assert.AreEqual(4, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.ImportGraphPersistsWithoutTokenReferences(const aCorruption: string);
begin
  AssertImportGraphRoundTrip(aCorruption, False);
end;

procedure TSnapshotSqliteTests.ImportGraphBatchPersistsWithoutTokenReferences(const aCorruption: string);
begin
  AssertImportGraphRoundTrip(aCorruption, True);
end;

procedure TSnapshotSqliteTests.AssertImportGraphRoundTrip(const aCorruption: string; const aBatch: Boolean);
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lOriginal, lLoaded, lMerged: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lUnit: TUnitSnapshot;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lCacheFileName, lImport: string;
  lFact: TDelphiSemanticImportFact;
begin
  lCacheFileName := TempPath('import-graph-' + aCorruption + BoolToStr(aBatch, True) + '.sqlite3');
  lImport := TempPath('ImportTarget.pas');
  lIdentity := CreateIdentity('ImportGraph' + aCorruption, 'file-a', 'context-a',
    'include-a', 'snapshot-v1');
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern(lIdentity.SourceFileName),
      lBuilder.Strings.Intern('ImportGraph'));
    lBuilder.AddUnit(lUnit);
    lUnit.AddPossibleUnitImport(lBuilder.Strings.Intern(lImport));
    lFact := Default(TDelphiSemanticImportFact);
    lFact.OwnerFileName := lIdentity.SourceFileName;
    lFact.Name := 'ImportTarget';
    lFact.TargetFileName := lImport;
    lFact.SectionKind := 'implementation';
    lFact.Cause := 'occurrence-in-inactive-configuration';
    lFact.GapReason := 'possible-unit-source-unavailable';
    lFact.ResolutionVaries := True;
    lFact.OrderIndex := 7;
    lUnit.SetImportFacts([lFact]);
    lOriginal := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lCache.StoreUnitFromSnapshot(lIdentity, lOriginal, 0);
    FreeAndNil(lCache);
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    if aBatch then
      lCache.BeginUnitLoadBatch([lIdentity]);
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoaded));
    try
      Assert.AreEqual(0, lLoaded.UnitByIndex(0).ReferenceCount,
        'Import provenance must not become a symbol occurrence.');
      Assert.AreEqual(1, lLoaded.UnitByIndex(0).PossibleUnitImportCount);
      Assert.AreEqual(lImport, lLoaded.TextOf(lLoaded.UnitByIndex(0).PossibleUnitImportByIndex(0)));
      lMerged := BuildProjectSnapshotFromUnitSnapshots([lLoaded], lMetrics);
      try
        Assert.AreEqual(1, Integer(Length(lMerged.UnitByIndex(0).ImportFacts)));
        Assert.AreEqual(ImportFactsToJson([lFact]), ImportFactsToJson(lMerged.UnitByIndex(0).ImportFacts),
          'Section, order, activity and alternate-resolution evidence survive caching and merge.');
        Assert.AreEqual(0, lMerged.UnitByIndex(0).ReferenceCount);
        Assert.AreEqual(1, lMerged.UnitByIndex(0).PossibleUnitImportCount);
        Assert.AreEqual(lImport, lMerged.TextOf(lMerged.UnitByIndex(0).PossibleUnitImportByIndex(0)));
      finally
        lMerged.Free;
      end;
    finally
      lLoaded.Free;
    end;
    if aBatch then
      lCache.EndUnitLoadBatch;
    if aCorruption <> 'none' then
    begin
      if aCorruption = 'header' then
        ExecCacheSql(lCacheFileName, 'delete from snapshot_possible_imports where item_index = 0')
      else if aCorruption = 'edge' then
        ExecCacheSql(lCacheFileName, 'delete from snapshot_possible_imports where item_index = 1')
      else if aCorruption = 'provenance' then
        ExecCacheSql(lCacheFileName, 'delete from snapshot_import_facts')
      else if aCorruption = 'count' then
        ExecCacheSql(lCacheFileName, 'update snapshot_import_facts set payload = ''[]''')
      else if aCorruption = 'payload' then
        ExecCacheSql(lCacheFileName, 'update snapshot_import_facts set payload = ''{}''')
      else
        ExecCacheSql(lCacheFileName, 'update snapshot_possible_imports set file_name_id = 999999 where item_index = 1');
      if aBatch then
        lCache.BeginUnitLoadBatch([lIdentity]);
      Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lLoaded));
      Assert.IsNull(lLoaded);
      if aBatch then
        lCache.EndUnitLoadBatch;
      Assert.AreEqual(1, lCache.Metrics.Invalidations);
    end;
  finally
    lCache.Free;
    lOriginal.Free;
  end;
end;

procedure TSnapshotSqliteTests.CorruptStringIdInvalidatesStoredSnapshot;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-corrupt-string-id.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotCorruptStringIdUnit', 'file-a', 'context-a',
    'include-a', 'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lIdentity);
  ExecCacheSql(lCacheFileName, 'update snapshot_units set file_name_id = 999999');

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lSnapshot := nil;
    try
      Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lSnapshot));
      Assert.IsNull(lSnapshot);
    finally
      lSnapshot.Free;
    end;
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.DefaultSnapshotBuildDoesNotRequireSqliteCache;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFileNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('MemoryOnlyUnit.pas');
    lUnitNameId := lBuilder.Strings.Intern('MemoryOnlyUnit');
    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    lBuilder.AddUnit(lUnit);
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    Assert.AreEqual(1, lProject.UnitCount);
    Assert.AreEqual('MemoryOnlyUnit.pas', lProject.TextOf(lFileNameId));
  finally
    lProject.Free;
  end;
end;

procedure TSnapshotSqliteTests.BuildProjectSnapshotFromUnitSnapshotsDoesNotPromoteProjectRemoveWithPlanningFacts;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lFileNameId: TSemanticStringId;
  lMergedSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lSnapshot: TDelphiProjectSnapshot;
  lSnapshots: TArray<TDelphiProjectSnapshot>;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('MergeRemoveWithUnit.pas');
    lUnitNameId := lBuilder.Strings.Intern('MergeRemoveWithUnit');
    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    lBuilder.AddUnit(lUnit);
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('Merge-Context');
    SetLength(lFacts.Bindings, 1);
    lFacts.Bindings[0].SelectorTextId := lBuilder.ExactStrings.Intern('DF[D]^');
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    SetLength(lSnapshots, 1);
    lSnapshots[0] := lSnapshot;
    lMergedSnapshot := BuildProjectSnapshotFromUnitSnapshots(lSnapshots, lMetrics);
    try
      Assert.IsFalse(lMergedSnapshot.HasRemoveWithPlanningFacts,
        'Unit snapshot merge must not promote project-wide remove-with planning facts.');
    finally
      lMergedSnapshot.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.BuildProjectSnapshotFromMixedUnitSnapshotsDropsProjectRemoveWithPlanningFacts;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lFileNameId: TSemanticStringId;
  lMergedSnapshot: TDelphiProjectSnapshot;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lSnapshotA: TDelphiProjectSnapshot;
  lSnapshotB: TDelphiProjectSnapshot;
  lSnapshots: TArray<TDelphiProjectSnapshot>;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lSnapshotA := nil;
  lSnapshotB := nil;
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('StaleFactsA.pas');
    lUnitNameId := lBuilder.Strings.Intern('StaleFactsA');
    lUnit := TUnitSnapshot.Create(1, lFileNameId, lUnitNameId);
    lBuilder.AddUnit(lUnit);
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('stale-context');
    SetLength(lFacts.Bindings, 1);
    lFacts.Bindings[0].SelectorTextId := lBuilder.ExactStrings.Intern('OldSelector');
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshotA := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('RebuiltFactsB.pas');
    lUnitNameId := lBuilder.Strings.Intern('RebuiltFactsB');
    lUnit := TUnitSnapshot.Create(2, lFileNameId, lUnitNameId);
    lBuilder.AddUnit(lUnit);
    lSnapshotB := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    SetLength(lSnapshots, 2);
    lSnapshots[0] := lSnapshotA;
    lSnapshots[1] := lSnapshotB;
    lMergedSnapshot := BuildProjectSnapshotFromUnitSnapshots(lSnapshots, lMetrics);
    try
      Assert.IsFalse(lMergedSnapshot.HasRemoveWithPlanningFacts,
        'Merged unit snapshots must not promote stale project-wide remove-with planning facts.');
    finally
      lMergedSnapshot.Free;
    end;
  finally
    lSnapshotA.Free;
    lSnapshotB.Free;
  end;
end;

procedure TSnapshotSqliteTests.ExecCacheSql(const aCacheFileName, aSql: string);
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

procedure TSnapshotSqliteTests.InvalidationDeletesAtomicallyWhenDeleteFails;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lChangedIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lDeleteFailed: Boolean;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-atomic-delete.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotAtomicDeleteUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lIdentity);
  ExecCacheSql(lCacheFileName, 'create trigger block_snapshot_symbol_delete before delete on ' +
    'snapshot_symbols begin select raise(abort, ''blocked delete''); end');
  lChangedIdentity := lIdentity;
  lChangedIdentity.FileHash := 'file-b';

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lSnapshot := nil;
    lDeleteFailed := False;
    try
      lCache.TryLoadUnit(lChangedIdentity, lSnapshot);
    except
      lDeleteFailed := True;
    end;
    Assert.IsTrue(lDeleteFailed, 'Expected the SQLite trigger to block invalidation.');
    Assert.IsNull(lSnapshot);
  finally
    lCache.Free;
  end;

  Assert.IsTrue(TableRowCount(lCacheFileName, 'snapshot_strings') > 0);
  Assert.IsTrue(TableRowCount(lCacheFileName, 'snapshot_symbols') > 0);
  Assert.IsTrue(TableRowCount(lCacheFileName, 'snapshot_with_statements') > 0);
  Assert.IsTrue(TableRowCount(lCacheFileName, 'snapshot_references') > 0);
  Assert.IsTrue(TableRowCount(lCacheFileName, 'snapshot_units') > 0);
end;

procedure TSnapshotSqliteTests.MalformedLoadIdentityDoesNotDeleteStoredUnit;
var
  lBadIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lCaseIndex: Integer;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-invalid-load-identity.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotInvalidLoadIdentityUnit', 'file-a', 'context-a',
    'include-a', 'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lIdentity);

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    for lCaseIndex := 0 to 6 do
    begin
      lBadIdentity := lIdentity;
      case lCaseIndex of
        0:
          lBadIdentity.CacheKey := '';
        1:
          lBadIdentity.IdentityKey := '';
        2:
          lBadIdentity.SourceFileName := '';
        3:
          lBadIdentity.FileHash := '';
        4:
          lBadIdentity.ContextHash := '';
        5:
          lBadIdentity.IncludeGraphHash := '';
        6:
          lBadIdentity.SchemaVersion := '';
      end;

      lSnapshot := nil;
      Assert.WillRaise(
        procedure
        begin
          lCache.TryLoadUnit(lBadIdentity, lSnapshot);
        end, Exception);
      Assert.IsNull(lSnapshot);
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lSnapshot));
      try
        Assert.AreEqual(1, lSnapshot.UnitCount);
      finally
        lSnapshot.Free;
      end;
    end;
  finally
    lCache.Free;
  end;

  Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_units'));
end;

procedure TSnapshotSqliteTests.SecondCacheInstanceReusesStoredUnitSnapshot;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-reuse.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotReuseUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v1');

  StoreDemoUnit(lCacheFileName, lIdentity);

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.DeepSnapshotCachePersistsAndReusesAcrossInstances;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lDirectory: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
begin
  lDirectory := TempPath('deep-snapshot-cache');
  lDirectory := TPath.Combine(lDirectory, StringOfChar('a', 70));
  lDirectory := TPath.Combine(lDirectory, StringOfChar('b', 70));
  lDirectory := TPath.Combine(lDirectory, StringOfChar('c', 70));
  lDirectory := TPath.Combine(lDirectory, StringOfChar('d', 70));
  lCacheFileName := TPath.Combine(lDirectory, 'semantic-unit-cache.sqlite3');
  Assert.IsTrue(TPath.IsPathRooted(lCacheFileName));
  Assert.IsTrue(Length(lCacheFileName) > 300);
  Assert.IsFalse(TPath.IsExtendedPrefixed(lCacheFileName));
  lIdentity := CreateIdentity('DeepSnapshotCacheUnit', 'file-a', 'context-a',
    'include-a', 'snapshot-v1');

  StoreDemoUnit(lCacheFileName, lIdentity);
  Assert.IsTrue(GetFileAttributes(PChar('\\?\' + lCacheFileName)) <>
    INVALID_FILE_ATTRIBUTES, 'The SQLite database must exist at the requested deep path.');

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lSnapshot));
    try
      Assert.IsTrue(lSnapshot.TryFindUnitByFileName('demounit.pas', lUnitId));
      Assert.IsTrue(lSnapshot.TryFindUnitById(lUnitId, lUnit));
      Assert.AreEqual(2, lUnit.SymbolCount);
      Assert.AreEqual(1, lUnit.ReferenceCount);
      Assert.AreEqual('DemoTypes.inc', lSnapshot.TextOf(lUnit.SymbolById(1).FileId));
    finally
      lSnapshot.Free;
    end;
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.SourcePathVariantsReuseStoredUnitSnapshotIdentity;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lStoredIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lVariantIdentity: TDelphiSemanticSnapshotCacheIdentity;
begin
  lCacheFileName := TempPath('snapshot-source-path-identity.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);

  lStoredIdentity := CreateIdentity('SnapshotSourcePathIdentityUnit', 'file-a',
    'context-a', 'include-a', 'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lStoredIdentity);

  lVariantIdentity := lStoredIdentity;
  lVariantIdentity.SourceFileName := StringReplace(UpperCase(lStoredIdentity.SourceFileName),
    '\', '/', [rfReplaceAll]);

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lLoadedSnapshot := nil;
    Assert.IsTrue(lCache.TryLoadUnit(lVariantIdentity, lLoadedSnapshot));
    try
      Assert.AreEqual(1, lLoadedSnapshot.UnitCount);
    finally
      lLoadedSnapshot.Free;
    end;
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.MetricsReportHitTimingAndUsefulness;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-hit-metrics.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotHitMetricsUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lIdentity);

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;

    Assert.AreEqual(1, lCache.Metrics.SnapshotCacheProbes);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
    Assert.IsTrue(lCache.Metrics.SnapshotSqlReadMilliseconds > 0);
    Assert.IsTrue(lCache.Metrics.SnapshotDeserializeMilliseconds >= 0);
    Assert.IsTrue(lCache.Metrics.SnapshotIndexRebuildMilliseconds >= 0);
    Assert.AreEqual(Int64(60000), lCache.Metrics.SnapshotParseAvoidedEstimateMilliseconds);
    Assert.IsTrue(lCache.Metrics.SnapshotCacheUseful);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.MetricsReportMissTelemetry;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-miss-metrics.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotMissMetricsUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v1');

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lSnapshot := nil;
    Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lSnapshot));
    Assert.IsNull(lSnapshot);

    Assert.AreEqual(1, lCache.Metrics.SnapshotCacheProbes);
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
    Assert.IsTrue(lCache.Metrics.SnapshotSqlReadMilliseconds > 0);
    Assert.IsTrue(lCache.Metrics.SnapshotDeserializeMilliseconds >= 0);
    Assert.IsTrue(lCache.Metrics.SnapshotIndexRebuildMilliseconds >= 0);
    Assert.AreEqual(Int64(0), lCache.Metrics.SnapshotParseAvoidedEstimateMilliseconds);
    Assert.IsFalse(lCache.Metrics.SnapshotCacheUseful);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.MetricsRequirePositiveParseSavingsForUsefulCache;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-usefulness-zero-estimate.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotZeroEstimateUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v1');
  lIdentity.ParseAvoidedEstimateMilliseconds := 0;
  StoreDemoUnit(lCacheFileName, lIdentity);

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lSnapshot));
    try
      Assert.AreEqual(1, lSnapshot.UnitCount);
    finally
      lSnapshot.Free;
    end;
    Assert.AreEqual(Int64(0), lCache.Metrics.SnapshotParseAvoidedEstimateMilliseconds);
    Assert.IsFalse(lCache.Metrics.SnapshotCacheUseful);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.SnapshotCacheSourceDoesNotUseJsonRepresentation;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.Cache.Sqlite.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lSourceText, 'System.JSON'));
  Assert.IsFalse(ContainsText(lSourceText, 'TJSONObject'));
  Assert.IsFalse(ContainsText(lSourceText, 'TJSONArray'));
  Assert.IsFalse(ContainsText(lSourceText, 'model_json'));
end;

procedure TSnapshotSqliteTests.SnapshotSqliteCacheUsesPreparedStatementsAndCachedFields;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.Cache.Sqlite.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lSourceText, 'FieldByName('),
    'Snapshot SQLite load paths should cache fields once per result set.');
  Assert.IsFalse(ContainsText(lSourceText, 'ExecSQL(''insert into snapshot_strings'),
    'Snapshot string facts should use a prepared insert query.');
  Assert.IsFalse(ContainsText(lSourceText, 'ExecSQL(''insert into snapshot_symbols'),
    'Snapshot symbol facts should use a prepared insert query.');
  Assert.IsFalse(ContainsText(lSourceText, 'ExecSQL(''insert into snapshot_with_statements'),
    'Snapshot with-statement facts should use a prepared insert query.');
  Assert.IsFalse(ContainsText(lSourceText, 'ExecSQL(''insert into snapshot_references'),
    'Snapshot reference facts should use a prepared insert query.');
end;

procedure TSnapshotSqliteTests.SnapshotSqliteConnectionsDeclareBusyJournalAndLockingPolicy;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.Cache.Sqlite.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText, 'BusyTimeout'),
    'Snapshot SQLite connections must declare an explicit busy timeout.');
  Assert.IsTrue(ContainsText(lSourceText, 'JournalMode') and ContainsText(lSourceText, 'WAL'),
    'Snapshot SQLite connections must declare an explicit journal policy.');
  Assert.IsTrue(ContainsText(lSourceText, 'LockingMode') and ContainsText(lSourceText, 'Normal'),
    'Snapshot SQLite connections must declare an explicit locking policy for multi-process writers.');
end;

procedure TSnapshotSqliteTests.SnapshotSqliteConcurrencyHarness;
var
  lCacheFileName: string;
  lIdentityName: string;
  lIdentityNames: TArray<string>;
  lReadyFileName: string;
  lReleaseFileName: string;
  lRole: string;
begin
  lRole := GetEnvironmentVariable(
    'DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_ROLE');
  lCacheFileName := GetEnvironmentVariable(
    'DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_CACHE');
  if Trim(lCacheFileName) = '' then
    lCacheFileName := TempPath('snapshot-concurrency-harness.sqlite3');

  if SameText(lRole, 'holder') then
  begin
    lReadyFileName := GetEnvironmentVariable(
      'DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_READY');
    lReleaseFileName := GetEnvironmentVariable(
      'DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_RELEASE');
    HoldConcurrencyWriteLock(lCacheFileName, lReadyFileName, lReleaseFileName);
    Assert.Pass('Held and released the SQLite write lock.');
    Exit;
  end;

  if SameText(lRole, 'writer') then
  begin
    lIdentityName := GetEnvironmentVariable(
      'DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_IDENTITY');
    if Trim(lIdentityName) = '' then
      raise Exception.Create('Missing snapshot SQLite concurrency identity.');
    StoreConcurrencyIdentity(lCacheFileName, lIdentityName);
    VerifyConcurrencyIdentities(lCacheFileName, [lIdentityName]);
    Exit;
  end;

  if SameText(lRole, 'verify') then
  begin
    lIdentityNames := SplitString(GetEnvironmentVariable(
      'DELPHI_SEMANTICS_SNAPSHOT_SQLITE_CONCURRENCY_IDENTITIES'), ';');
    VerifyConcurrencyIdentities(lCacheFileName, lIdentityNames);
    Exit;
  end;

  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  StoreConcurrencyIdentity(lCacheFileName, 'LocalA');
  StoreConcurrencyIdentity(lCacheFileName, 'LocalB');
  VerifyConcurrencyIdentities(lCacheFileName, ['LocalA', 'LocalB']);
end;

procedure TSnapshotSqliteTests.SnapshotSqliteRemoveWithLoadsPreSizeStoredFactArrays;
var
  lBindingGrowth: string;
  lBindingPreSize: string;
  lLoadEnd: Integer;
  lLoadSource: string;
  lLoadStart: Integer;
  lRoutineOwnerGrowth: string;
  lRoutineOwnerPreSize: string;
  lSourceFileName: string;
  lSourceText: string;
  lSymbolGrowth: string;
  lSymbolPreSize: string;

  procedure AssertContainsInOrder(const aSource, aFirst, aSecond, aMessage: string);
  var
    lFirstIndex: Integer;
    lSecondIndex: Integer;
  begin
    lFirstIndex := Pos(aFirst, aSource);
    lSecondIndex := Pos(aSecond, aSource);
    Assert.IsTrue((lFirstIndex > 0) and (lSecondIndex > lFirstIndex), aMessage);
  end;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.Cache.Sqlite.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);
  lLoadStart := Pos('procedure TDelphiSemanticSnapshotSqliteCache.LoadRemoveWithPlanningFacts',
    lSourceText);
  lLoadEnd := PosEx('function TDelphiSemanticSnapshotSqliteCache.LoadUnitHeader', lSourceText,
    lLoadStart);
  Assert.IsTrue((lLoadStart > 0) and (lLoadEnd > lLoadStart),
    'Expected remove-with planning fact load implementation.');
  lLoadSource := Copy(lSourceText, lLoadStart, lLoadEnd - lLoadStart);

  lRoutineOwnerGrowth := 'SetLength(lFacts.RoutineOwners, ' + 'i + 1)';
  lSymbolGrowth := 'SetLength(lFacts.Symbols, ' + 'i + 1)';
  lBindingGrowth := 'SetLength(lFacts.Bindings, ' + 'i + 1)';
  Assert.IsFalse(ContainsText(lLoadSource, lRoutineOwnerGrowth),
    'Routine owner loads must not grow fact arrays per row.');
  Assert.IsFalse(ContainsText(lLoadSource, lSymbolGrowth),
    'Symbol loads must not grow fact arrays per row.');
  Assert.IsFalse(ContainsText(lLoadSource, lBindingGrowth),
    'Binding loads must not grow fact arrays per row.');

  lRoutineOwnerPreSize := 'SetLength(lFacts.RoutineOwners, lExpectedRoutineOwnerCount)';
  lSymbolPreSize := 'SetLength(lFacts.Symbols, lExpectedSymbolCount)';
  lBindingPreSize := 'SetLength(lFacts.Bindings, lExpectedBindingCount)';
  AssertContainsInOrder(lLoadSource, 'lExpectedRoutineOwnerCount := lQuery.Fields[1].AsInteger',
    lRoutineOwnerPreSize, 'Routine owners should use the stored row count before loading rows.');
  AssertContainsInOrder(lLoadSource, 'lExpectedSymbolCount := lQuery.Fields[2].AsInteger',
    lSymbolPreSize, 'Symbols should use the stored row count before loading rows.');
  AssertContainsInOrder(lLoadSource, 'lExpectedBindingCount := lQuery.Fields[3].AsInteger',
    lBindingPreSize, 'Bindings should use the stored row count before loading rows.');
  AssertContainsInOrder(lLoadSource, lRoutineOwnerPreSize,
    'Snapshot remove-with routine owner row count mismatch.',
    'Routine owner mismatch guard should remain after loading rows.');
  AssertContainsInOrder(lLoadSource, lSymbolPreSize,
    'Snapshot remove-with symbol row count mismatch.',
    'Symbol mismatch guard should remain after loading rows.');
  AssertContainsInOrder(lLoadSource, lBindingPreSize,
    'Snapshot remove-with binding row count mismatch.',
    'Binding mismatch guard should remain after loading rows.');
end;

procedure TSnapshotSqliteTests.SnapshotSqliteCacheUsesWideTextAccessors;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Snapshot.Cache.Sqlite.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lSourceText, '.AsString'),
    'Snapshot SQLite text fields and parameters should use Unicode-safe accessors.');
  Assert.IsFalse(ContainsText(lSourceText, 'DataType := ftString'),
    'Snapshot SQLite text parameters should be declared as wide text.');
  Assert.IsTrue(ContainsText(lSourceText, '.AsWideString'),
    'Snapshot SQLite cache should read/write text through wide accessors.');
end;

procedure TSnapshotSqliteTests.SparseChildRowsInvalidateStoredSnapshot;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-sparse-child-rows.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotSparseRowsUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lIdentity);
  ExecCacheSql(lCacheFileName, 'delete from snapshot_references');

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lSnapshot := nil;
    try
      Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lSnapshot));
      Assert.IsNull(lSnapshot);
    finally
      lSnapshot.Free;
    end;
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.SourceContextIncludeAndSchemaChangesMissWithoutIdentityWideEviction;
begin
  AssertIdentityChangeMissesWithoutEviction('SnapshotSourceInvalidationUnit',
    CreateIdentity('SnapshotSourceInvalidationUnit', 'file-b', 'context-a', 'include-a',
    'snapshot-v1'));
  AssertIdentityChangeMissesWithoutEviction('SnapshotContextInvalidationUnit',
    CreateIdentity('SnapshotContextInvalidationUnit', 'file-a', 'context-b', 'include-a',
    'snapshot-v1'));
  AssertIdentityChangeMissesWithoutEviction('SnapshotIncludeInvalidationUnit',
    CreateIdentity('SnapshotIncludeInvalidationUnit', 'file-a', 'context-a', 'include-b',
    'snapshot-v1'));
  AssertIdentityChangeMissesWithoutEviction('SnapshotSchemaInvalidationUnit',
    CreateIdentity('SnapshotSchemaInvalidationUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v2'));
end;

procedure TSnapshotSqliteTests.StoreUnitFromSnapshotPreservesUnicodeTextValues;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lExactContextText: string;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lFileNameId: TSemanticStringId;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lLoadedUnit: TUnitSnapshot;
  lMemberName: string;
  lMemberNameId: TSemanticStringId;
  lProjectFactsIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceText: string;
  lSourceTextId: TSemanticStringId;
  lSourceFileName: string;
  lSymbol: TSemanticSymbolFact;
  lTypeName: string;
  lTypeNameId: TSemanticStringId;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
  lUnicodeText: string;
  lVisibilityModel: TDelphiSemanticUnitModel;
begin
  lCacheFileName := TempPath('snapshot-unicode.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);

  lUnicodeText := SnapshotUnicodeText;
  lSourceFileName := TempPath('Snapshot-' + lUnicodeText + '.pas');
  lTypeName := 'T' + lUnicodeText;
  lMemberName := 'Value' + lUnicodeText;
  lExactContextText := '  Context-' + lUnicodeText + #9 + sLineBreak + '  ';
  lSourceText := 'unit SnapshotUnicodeUnit;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + '// ExactSource ' + lUnicodeText + ' Aa' + sLineBreak +
    'end.' + sLineBreak + '  ' + sLineBreak;
  lIdentity := CreateIdentity('SnapshotUnicodeUnit', 'file-unicode', 'context-unicode',
    'include-unicode', 'snapshot-v1');
  lIdentity.IdentityKey := 'SnapshotIdentity-' + lUnicodeText;
  lIdentity.SourceFileName := lSourceFileName;
  lIdentity.CacheKey := lIdentity.IdentityKey + '|file-unicode|context-unicode|' +
    'include-unicode|snapshot-v1';
  lProjectFactsIdentity := CreateIdentity('SnapshotUnicodeProjectRemoveWith',
    'project-file-unicode', 'project-context-unicode', 'project-include-unicode',
    'snapshot-project-remove-with-v1');
  lProjectFactsIdentity.SourceFileName := TempPath('Project-' + lUnicodeText + '.dproj');
  lProjectFactsIdentity.CacheKey := lProjectFactsIdentity.IdentityKey +
    '|project-file-unicode|project-context-unicode|project-include-unicode|' +
    'snapshot-project-remove-with-v1';

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern(lSourceFileName);
    lVisibilityModel := Default(TDelphiSemanticUnitModel);
    lVisibilityModel.FileName := lSourceFileName;
    lVisibilityModel.UnitName := 'SnapshotUnicodeUnit';
    AttachRemoveWithVisibility(lBuilder, [lVisibilityModel]);
    lUnitNameId := lBuilder.Strings.Intern('SnapshotUnicodeUnit');
    lTypeNameId := lBuilder.Strings.Intern(lTypeName);
    lMemberNameId := lBuilder.Strings.Intern(lMemberName);
    lSourceTextId := lBuilder.ExactStrings.Intern(lSourceText);
    lUnit := TUnitSnapshot.Create(19, lFileNameId, lUnitNameId, lSourceTextId);
    lUnit.SetVerifiedActiveSourceTextId(lBuilder.ExactStrings.Intern(
      '  ' + Copy(lSourceText, 3, MaxInt)));

    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lTypeNameId;
    lSymbol.KindId := lBuilder.Strings.Intern('type');
    lSymbol.SignatureId := lBuilder.Strings.Intern('type ' + lTypeName + ' = class end');
    lUnit.AddSymbol(lSymbol);

    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lMemberNameId;
    lSymbol.OwnerTypeId := lTypeNameId;
    lSymbol.TypeId := lBuilder.Strings.Intern('string');
    lSymbol.KindId := lBuilder.Strings.Intern('property');
    lSymbol.SignatureId := lBuilder.Strings.Intern('property ' + lMemberName + ': string');
    lUnit.AddSymbol(lSymbol);

    lBuilder.AddUnit(lUnit);
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern(lExactContextText);
    SetLength(lFacts.Bindings, 1);
    lFacts.Bindings[0].SelectorTextId := lBuilder.ExactStrings.Intern(lMemberName);
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
      lCache.StoreProjectRemoveWithPlanningFacts(lProjectFactsIdentity, lSnapshot);
    finally
      lCache.Free;
    end;

    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoadedSnapshot));
      try
        lLoadedUnit := lLoadedSnapshot.UnitByIndex(0);
        Assert.AreEqual(lSourceFileName, lLoadedSnapshot.TextOf(lLoadedUnit.FileNameId));
        Assert.AreEqual(lTypeName,
          lLoadedSnapshot.TextOf(lLoadedUnit.SymbolById(TSemanticSymbolId(1)).NameId));
        Assert.AreEqual(lMemberName,
          lLoadedSnapshot.TextOf(lLoadedUnit.SymbolById(TSemanticSymbolId(2)).NameId));
        Assert.AreEqual(lSourceText, lLoadedSnapshot.ExactTextOf(lLoadedUnit.SourceTextId));
        Assert.AreEqual('  ' + Copy(lSourceText, 3, MaxInt),
          lLoadedSnapshot.ExactTextOf(lLoadedUnit.VerifiedActiveSourceTextId));
        Assert.IsFalse(lLoadedSnapshot.HasRemoveWithPlanningFacts,
          'Unit cache entries must not carry project remove-with planning facts.');
      finally
        lLoadedSnapshot.Free;
      end;

      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lProjectFactsIdentity,
        lLoadedSnapshot));
      try
        Assert.AreEqual(lExactContextText, lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningContextFingerprintId));
        Assert.AreEqual(lMemberName, lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningBindingByIndex(0).SelectorTextId));
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.StoreUnitFromSnapshotStoresOnlyReachableUnitStrings;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceAText: string;
  lSourceAId: TSemanticStringId;
  lSourceBText: string;
  lSourceBId: TSemanticStringId;
  lStringId: TSemanticStringId;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
  lUnitANameId: TSemanticStringId;
  lUnitBNameId: TSemanticStringId;
  lUnitATypeName: string;
  lUnitBTypeName: string;
begin
  lCacheFileName := TempPath('snapshot-local-string-pool.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);

  lUnitATypeName := 'TOnlyUnitAType';
  lUnitBTypeName := 'TOnlyUnitBType';
  lSourceAText := 'unit LocalPoolUnitA; interface type ' + lUnitATypeName +
    ' = class end; implementation end.';
  lSourceBText := 'unit LocalPoolUnitB; interface type ' + lUnitBTypeName +
    ' = class end; implementation end.';
  lIdentity := CreateIdentity('LocalPoolUnitA', 'file-local-a', 'context-local',
    'include-local', 'snapshot-v1');

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnitANameId := lBuilder.Strings.Intern('LocalPoolUnitA');
    lSourceAId := lBuilder.ExactStrings.Intern(lSourceAText);
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('LocalPoolUnitA.pas'),
      lUnitANameId, lSourceAId);
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lBuilder.Strings.Intern(lUnitATypeName);
      lSymbol.KindId := lBuilder.Strings.Intern('type');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('interface');
      lUnit.AddSymbol(lSymbol);
      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;

    lUnitBNameId := lBuilder.Strings.Intern('LocalPoolUnitB');
    lSourceBId := lBuilder.ExactStrings.Intern(lSourceBText);
    lUnit := TUnitSnapshot.Create(2, lBuilder.Strings.Intern('LocalPoolUnitB.pas'),
      lUnitBNameId, lSourceBId);
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lBuilder.Strings.Intern(lUnitBTypeName);
      lSymbol.KindId := lBuilder.Strings.Intern('type');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('interface');
      lUnit.AddSymbol(lSymbol);
      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;

    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    finally
      lCache.Free;
    end;

    Assert.AreEqual(1, CacheTextRowCount(lCacheFileName, 'snapshot_strings',
      lIdentity.CacheKey, lUnitATypeName), 'Expected unit A string to be stored.');
    Assert.AreEqual(0, CacheTextRowCount(lCacheFileName, 'snapshot_strings',
      lIdentity.CacheKey, lUnitBTypeName),
      'Unit A cache key must not store strings reachable only from unit B.');
    Assert.AreEqual(0, CacheTextRowCount(lCacheFileName, 'snapshot_exact_strings',
      lIdentity.CacheKey, lSourceBText),
      'Unit A cache key must not store exact source text reachable only from unit B.');

    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoadedSnapshot));
      try
        Assert.IsTrue(lLoadedSnapshot.TryFindStringId(lUnitATypeName, lStringId));
        Assert.IsFalse(lLoadedSnapshot.TryFindStringId(lUnitBTypeName, lStringId));
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.HoldConcurrencyWriteLock(const aCacheFileName,
  aReadyFileName, aReleaseFileName: string);
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lStopwatch: TStopwatch;
begin
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
  try
    // Create the schema before holding the write lock used by the script-level contention proof.
  finally
    lCache.Free;
  end;

  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Params.Values['BusyTimeout'] := '10000';
    lConnection.Params.Values['JournalMode'] := 'WAL';
    lConnection.Params.Values['LockingMode'] := 'Normal';
    lConnection.Connected := True;
    lConnection.StartTransaction;
    try
      lConnection.ExecSQL(
        'insert or replace into meta(key_name, value_text) values(' +
        '''snapshot_concurrency_holder'', ''locked'')');
      if aReadyFileName <> '' then
        TFile.WriteAllText(aReadyFileName, 'ready', TEncoding.UTF8);

      lStopwatch := TStopwatch.StartNew;
      while (aReleaseFileName <> '') and not TFile.Exists(aReleaseFileName) do
      begin
        if lStopwatch.ElapsedMilliseconds > 15000 then
          raise Exception.Create('Timed out waiting to release the SQLite write lock.');
        Sleep(50);
      end;
      lConnection.Commit;
    except
      if lConnection.InTransaction then
        lConnection.Rollback;
      raise;
    end;
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure TSnapshotSqliteTests.StoreConcurrencyIdentity(const aCacheFileName,
  aName: string);
begin
  StoreDemoUnit(aCacheFileName, CreateConcurrencyIdentity(aCacheFileName, aName));
end;

procedure TSnapshotSqliteTests.StoreDemoUnit(const aCacheFileName: string;
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity);
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lFileNameId: TSemanticStringId;
  lImplementationId: TSemanticStringId;
  lIntegerId: TSemanticStringId;
  lInterfaceId: TSemanticStringId;
  lMemberKindId: TSemanticStringId;
  lMemberNameId: TSemanticStringId;
  lProjectSourceId: TSemanticStringId;
  lPublishedId: TSemanticStringId;
  lReference: TSemanticReferenceFact;
  lRoutineId: TSemanticStringId;
  lSignatureId: TSemanticStringId;
  lSymbol: TSemanticSymbolFact;
  lTypeKindId: TSemanticStringId;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
  lValueSymbolId: TSemanticSymbolId;
  lWidgetTypeId: TSemanticStringId;
  lWith: TSemanticWithStatementFact;
  lWithId: TSemanticWithId;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lCache := nil;
  lUnit := nil;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
    lFileNameId := lBuilder.Strings.Intern('DemoUnit.pas');
    lUnitNameId := lBuilder.Strings.Intern('DemoUnit');
    lWidgetTypeId := lBuilder.Strings.Intern('TWidget');
    lMemberNameId := lBuilder.Strings.Intern('Value');
    lIntegerId := lBuilder.Strings.Intern('Integer');
    lTypeKindId := lBuilder.Strings.Intern('type');
    lMemberKindId := lBuilder.Strings.Intern('property');
    lRoutineId := lBuilder.Strings.Intern('UseWidget');
    lInterfaceId := lBuilder.Strings.Intern('interface');
    lImplementationId := lBuilder.Strings.Intern('implementation');
    lProjectSourceId := lBuilder.Strings.Intern('project-source');
    lPublishedId := lBuilder.Strings.Intern('published');
    lSignatureId := lBuilder.Strings.Intern('property Value: Integer');

    lUnit := TUnitSnapshot.Create(7, lFileNameId, lUnitNameId);
    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lWidgetTypeId;
    lSymbol.KindId := lTypeKindId;
    lSymbol.SectionKindId := lInterfaceId;
    lSymbol.SourceKindId := lProjectSourceId;
    lSymbol.FileId := lBuilder.Strings.Intern('DemoTypes.inc');
    lSymbol.Line := 4;
    lSymbol.Column := 3;
    lSymbol.EndLine := 8;
    lSymbol.EndColumn := 6;
    lUnit.AddSymbol(lSymbol);

    lSymbol := Default(TSemanticSymbolFact);
    lSymbol.NameId := lMemberNameId;
    lSymbol.OwnerTypeId := lWidgetTypeId;
    lSymbol.TypeId := lIntegerId;
    lSymbol.RoutineId := lRoutineId;
    lSymbol.KindId := lMemberKindId;
    lSymbol.SectionKindId := lInterfaceId;
    lSymbol.SourceKindId := lProjectSourceId;
    lSymbol.VisibilityId := lPublishedId;
    lSymbol.SignatureId := lSignatureId;
    lSymbol.Line := 6;
    lSymbol.Column := 5;
    lSymbol.EndLine := 6;
    lSymbol.EndColumn := 10;
    lValueSymbolId := lUnit.AddSymbol(lSymbol);

    lWith := Default(TSemanticWithStatementFact);
    lWith.RoutineId := lRoutineId;
    lWith.SelectorStartLine := 20;
    lWith.SelectorStartColumn := 8;
    lWith.BodyStartLine := 21;
    lWith.BodyStartColumn := 3;
    lWith.BodyEndLine := 23;
    lWith.BodyEndColumn := 6;
    lWithId := lUnit.AddWithStatement(lWith);

    lReference := Default(TSemanticReferenceFact);
    lReference.WithId := lWithId;
    lReference.TargetUnitId := 7;
    lReference.TargetSymbolId := lValueSymbolId;
    lReference.NameId := lMemberNameId;
    lReference.ReceiverTypeId := lWidgetTypeId;
    lReference.TypeId := lIntegerId;
    lReference.RoutineId := lRoutineId;
    lReference.SectionKindId := lImplementationId;
    lReference.SourceKindId := lProjectSourceId;
    lReference.ClassificationId := lMemberKindId;
    // DS-659: a reference from an include file keeps that file through the cache.
    lReference.FileId := lBuilder.Strings.Intern('DemoBody.inc');
    lReference.Line := 22;
    lReference.Column := 7;
    lReference.EndLine := 22;
    lReference.EndColumn := 12;
    lUnit.AddReference(lReference);

    lCache.StoreUnit(aIdentity, lBuilder.Strings, lUnit);
  finally
    lUnit.Free;
    lCache.Free;
    lBuilder.Free;
  end;
end;

procedure TSnapshotSqliteTests.VerifyConcurrencyIdentities(const aCacheFileName: string;
  const aNames: TArray<string>);
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lName: string;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
  try
    for lName in aNames do
    begin
      if Trim(lName) = '' then
        Continue;
      lIdentity := CreateConcurrencyIdentity(aCacheFileName, lName);
      lSnapshot := nil;
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lSnapshot),
        'Expected concurrency identity to load: ' + lName);
      try
        Assert.AreEqual(1, lSnapshot.UnitCount);
      finally
        lSnapshot.Free;
      end;
    end;
  finally
    lCache.Free;
  end;
end;

procedure TSnapshotSqliteTests.ProjectPlanningCachePreservesDirectImportVisibility;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lExtension: TObject;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lVisibility: TRemoveWithUnitVisibility;
begin
  lCacheFileName := TempPath('snapshot-project-import-visibility.sqlite3');
  lIdentity := CreateIdentity('SnapshotProjectImportVisibility', 'project-file-a',
    'project-context-a', 'project-include-a', 'snapshot-project-imports-v1');
  lIdentity.SourceFileName := TempPath('ProjectImportVisibility.dproj');
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lFacts.ContextFingerprint := 'Project-Import-Visibility';
  SetLength(lFacts.UnitModels, 2);
  lFacts.UnitModels[0].FileName := TempPath('Consumer.pas');
  lFacts.UnitModels[0].UnitName := 'Consumer';
  lFacts.UnitModels[0].InterfaceUses := ['Provider', 'provider'];
  lFacts.UnitModels[0].ImplementationUses := ['DirectTypes'];
  lFacts.UnitModels[1].FileName := TempPath('Provider.pas');
  lFacts.UnitModels[1].UnitName := 'Provider';
  lFacts.UnitModels[1].InterfaceUses := ['HiddenTypes'];
  lSnapshot := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
  try
    Assert.IsTrue(lSnapshot.TryGetExtension('DelphiSemantics.RemoveWithVisibility', lExtension),
      'Planning snapshots must retain direct imports independently from transitive lookup symbols.');
    Assert.IsTrue(TryGetRemoveWithVisibility(lSnapshot, lVisibility));
    Assert.IsTrue(lVisibility.HasUnit(lFacts.UnitModels[0].FileName));
    Assert.IsTrue(lVisibility.IsUnitVisible(lFacts.UnitModels[0].FileName, 'consumer'));
    Assert.IsTrue(lVisibility.IsUnitVisible(lFacts.UnitModels[0].FileName, 'PROVIDER'));
    Assert.IsTrue(lVisibility.IsUnitVisible(lFacts.UnitModels[0].FileName, 'DirectTypes'));
    Assert.IsFalse(lVisibility.IsUnitVisible(lFacts.UnitModels[0].FileName, 'HiddenTypes'),
      'Lookup availability through Provider must not make its imports directly visible in Consumer.');
    Assert.IsFalse(lVisibility.HasUnit(TempPath('Unknown.pas')));
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot);
    finally
      lCache.Free;
    end;
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot),
        'Standalone cache loads must preserve planning facts without a ProjectSession rebuild.');
      try
        Assert.IsTrue(lLoadedSnapshot.TryGetExtension('DelphiSemantics.RemoveWithVisibility', lExtension),
          'Standalone cached planning facts must retain direct-import visibility.');
        Assert.IsTrue(TryGetRemoveWithVisibility(lLoadedSnapshot, lVisibility));
        Assert.IsTrue(lVisibility.IsUnitVisible(lFacts.UnitModels[0].FileName, 'PROVIDER'));
        Assert.IsTrue(lVisibility.IsUnitVisible(lFacts.UnitModels[0].FileName, 'DirectTypes'));
        Assert.IsFalse(lVisibility.IsUnitVisible(lFacts.UnitModels[0].FileName, 'HiddenTypes'));
        Assert.IsTrue(lVisibility.IsUnitVisible(lFacts.UnitModels[1].FileName, 'HiddenTypes'));
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
    Assert.AreEqual(5, TableRowCount(lCacheFileName,
      'snapshot_remove_with_visible_units'),
      'A transitive import must be stored only for its direct importing unit.');
    ExecCacheSql(lCacheFileName, 'delete from snapshot_remove_with_visible_units ' +
      'where visible_unit_name = ''HiddenTypes''');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot),
        'Truncated visibility rows must invalidate the cache instead of changing planner decisions.');
      Assert.IsNull(lLoadedSnapshot);
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.RemoveWithTypeIdentityReloadRejectsMissingRows;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lTypeIdentity: TSemanticRemoveWithTypeIdentityFact;
begin
  lCacheFileName := TempPath('snapshot-remove-with-type-identity.sqlite3');
  lIdentity := CreateIdentity('SnapshotRemoveWithTypeIdentity', 'project-file-a',
    'project-context-a', 'project-include-a', 'snapshot-remove-with-type-v1');
  lIdentity.SourceFileName := TempPath('RemoveWithTypeIdentity.dproj');
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('Type-Identity-Context');
    SetLength(lFacts.Bindings, 1);
    SetLength(lFacts.Bindings[0].Selectors, 1);
    lFacts.Bindings[0].Selectors[0].SelectorTextId := lBuilder.ExactStrings.Intern('Receiver');
    lFacts.Bindings[0].Selectors[0].StatusId := lBuilder.ExactStrings.Intern('resolved');
    lFacts.Bindings[0].Selectors[0].TypeNameId := lBuilder.ExactStrings.Intern('TReceiver');
    lTypeIdentity := Default(TSemanticRemoveWithTypeIdentityFact);
    lTypeIdentity.UnitIdId := lBuilder.ExactStrings.Intern('unit-id');
    lTypeIdentity.UnitNameId := lBuilder.ExactStrings.Intern('OwnerUnit');
    lTypeIdentity.NameId := lBuilder.ExactStrings.Intern('TReceiver');
    lTypeIdentity.KindId := lBuilder.ExactStrings.Intern('record');
    lTypeIdentity.DeclaredIdId := lBuilder.ExactStrings.Intern('declared-id');
    lTypeIdentity.CanonicalIdId := lBuilder.ExactStrings.Intern('canonical-id');
    lTypeIdentity.FileNameId := lBuilder.ExactStrings.Intern('OwnerUnit.pas');
    lTypeIdentity.SectionKindId := lBuilder.ExactStrings.Intern('interface');
    lTypeIdentity.Line := 10;
    lTypeIdentity.Column := 3;
    lTypeIdentity.EndLine := 12;
    lTypeIdentity.EndColumn := 6;
    lFacts.Bindings[0].Selectors[0].TypeIdentity := lTypeIdentity;
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot);
    finally
      lCache.Free;
    end;
    Assert.AreEqual(1, TableRowCount(lCacheFileName,
      'snapshot_remove_with_type_identities'));
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot));
      try
        Assert.AreEqual('declared-id', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningBindingByIndex(0).Selectors[0].TypeIdentity.DeclaredIdId));
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
    ExecCacheSql(lCacheFileName, 'delete from snapshot_remove_with_type_identities');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lLoadedSnapshot := nil;
      try
        Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot),
          'A removed receiver identity must invalidate the persisted planning facts.');
        Assert.IsNull(lLoadedSnapshot);
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.LocalTypeIdentityReloadRejectsMissingScope;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lTypeIdentity: TSemanticRemoveWithTypeIdentityFact;
  lUnitModel: TDelphiSemanticUnitModel;
begin
  lCacheFileName := TempPath('snapshot-local-type-scope.sqlite3');
  lIdentity := CreateIdentity('SnapshotLocalTypeScope', 'project-file-a',
    'project-context-a', 'project-include-a', 'snapshot-local-type-scope-v1');
  lIdentity.SourceFileName := TempPath('LocalTypeScope.dproj');
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lUnitModel := Default(TDelphiSemanticUnitModel);
    lUnitModel.FileName := 'LocalUnit.pas';
    lUnitModel.UnitName := 'LocalUnit';
    AttachRemoveWithVisibility(lBuilder, [lUnitModel]);
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('Local-Scope-Context');
    SetLength(lFacts.RoutineOwners, 2);
    lFacts.RoutineOwners[0].NameId := lBuilder.ExactStrings.Intern('Outer');
    lFacts.RoutineOwners[0].SymbolClassId := lBuilder.ExactStrings.Intern('routine');
    lFacts.RoutineOwners[0].RoutineScopeIdId := lBuilder.ExactStrings.Intern('outer-scope');
    lFacts.RoutineOwners[0].FileNameId := lBuilder.ExactStrings.Intern('LocalUnit.pas');
    lFacts.RoutineOwners[0].UnitNameId := lBuilder.ExactStrings.Intern('LocalUnit');
    lFacts.RoutineOwners[1].NameId := lBuilder.ExactStrings.Intern('Inner');
    lFacts.RoutineOwners[1].SymbolClassId := lBuilder.ExactStrings.Intern('routine');
    lFacts.RoutineOwners[1].RoutineScopeIdId := lBuilder.ExactStrings.Intern('inner-scope');
    lFacts.RoutineOwners[1].ParentScopeIdId := lBuilder.ExactStrings.Intern('outer-scope');
    lFacts.RoutineOwners[1].FileNameId := lFacts.RoutineOwners[0].FileNameId;
    lFacts.RoutineOwners[1].UnitNameId := lFacts.RoutineOwners[0].UnitNameId;
    SetLength(lFacts.Bindings, 1);
    lFacts.Bindings[0].FileNameId := lFacts.RoutineOwners[0].FileNameId;
    lFacts.Bindings[0].UnitNameId := lFacts.RoutineOwners[0].UnitNameId;
    lFacts.Bindings[0].RoutineNameId := lBuilder.ExactStrings.Intern('Inner');
    lFacts.Bindings[0].RoutineScopeIdId := lBuilder.ExactStrings.Intern('inner-scope');
    SetLength(lFacts.Bindings[0].Selectors, 1);
    lFacts.Bindings[0].Selectors[0].SelectorTextId := lBuilder.ExactStrings.Intern('Item');
    lFacts.Bindings[0].Selectors[0].StatusId := lBuilder.ExactStrings.Intern('resolved');
    lFacts.Bindings[0].Selectors[0].TypeNameId := lBuilder.ExactStrings.Intern('TLocal');
    lTypeIdentity := Default(TSemanticRemoveWithTypeIdentityFact);
    lTypeIdentity.UnitIdId := lBuilder.ExactStrings.Intern('local-unit-id');
    lTypeIdentity.UnitNameId := lBuilder.ExactStrings.Intern('LocalUnit');
    lTypeIdentity.NameId := lBuilder.ExactStrings.Intern('TLocal');
    lTypeIdentity.KindId := lBuilder.ExactStrings.Intern('type');
    lTypeIdentity.DeclaredIdId := lBuilder.ExactStrings.Intern('local-declared-id');
    lTypeIdentity.CanonicalIdId := lBuilder.ExactStrings.Intern('local-canonical-id');
    lTypeIdentity.UnderlyingIdId := lBuilder.ExactStrings.Intern('local-underlying-id');
    lTypeIdentity.ScopeKindId := lBuilder.ExactStrings.Intern('routine');
    lTypeIdentity.OwnerScopeIdId := lBuilder.ExactStrings.Intern('outer-scope');
    lTypeIdentity.SemanticSymbolIdId := lBuilder.ExactStrings.Intern('outer-type-symbol');
    lTypeIdentity.SectionKindId := lBuilder.ExactStrings.Intern('implementation');
    lTypeIdentity.FileNameId := lBuilder.ExactStrings.Intern('LocalUnit.pas');
    lTypeIdentity.Line := 10;
    lTypeIdentity.Column := 3;
    lFacts.Bindings[0].Selectors[0].TypeIdentity := lTypeIdentity;
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot);
    finally
      lCache.Free;
    end;
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity,
        lLoadedSnapshot));
      try
        Assert.AreEqual('outer-scope', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningBindingByIndex(0).Selectors[0].
          TypeIdentity.OwnerScopeIdId));
        Assert.AreEqual('inner-scope', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningBindingByIndex(0).RoutineScopeIdId));
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
    ExecCacheSql(lCacheFileName,
      'update snapshot_remove_with_type_identities set owner_scope_id_id = 0');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lLoadedSnapshot := nil;
      Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity,
        lLoadedSnapshot), 'A local identity without its owner scope must rebuild.');
      Assert.IsNull(lLoadedSnapshot);
    finally
      lCache.Free;
    end;
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot);
    finally
      lCache.Free;
    end;
    ExecCacheSql(lCacheFileName,
      'update snapshot_remove_with_type_identities set underlying_id_id = 0');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lLoadedSnapshot := nil;
      Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity,
        lLoadedSnapshot), 'A local identity without its underlying ID must rebuild.');
      Assert.IsNull(lLoadedSnapshot);
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.AssertSourceRoutineSymbolsReload(const aName, aSource: string;
  const aExpectedNames: array of string);
var
  lAstPositions: TDictionary<string, Byte>;
  lModelCache: TDelphiSemanticSqliteUnitCache;
  lModelCacheOptions: TDelphiSemanticCacheOptions;
  lFreshJson: string;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lExpectedName: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lInventorySymbol: TDelphiSemanticInventorySymbol;
  lLoaded: Boolean;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lLocal: TDelphiSemanticLocal;
  lMisplaced: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lScopeless: string;
  lSeen: Boolean;
  lSnapshot: TDelphiProjectSnapshot;
  lSymbol: TSemanticRemoveWithInventorySymbolFact;
  lSymbolClass: string;
  i: Integer;
  lWarm: Integer;
begin
  // Regression for DS-685 C1: the source-text compatibility inventory adds a
  // twin for every AST local and parameter. A twin without a routine scope
  // made every snapshot reload fail and silently rebuild the cache.
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TempPath(CombinePath(['routine-scope-' + aName,
    'RoutineScopeUnit.pas']));
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, aSource, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The routine scope fixture must extract from source.');
  lFreshJson := ModelToJson(lModel);
  lModelCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelCacheOptions.SqliteCacheFileName := TempPath('model-scope-' + aName + '.sqlite3');
  for lWarm := 0 to 2 do
  begin
    lModelCache := TDelphiSemanticSqliteUnitCache.Create(lModelCacheOptions);
    try
      lModel := lModelCache.GetOrExtractUnitModel(lOptions);
      Assert.AreEqual(lFreshJson, ModelToJson(lModel),
        'The reloaded unit model must equal the fresh parse byte for byte.');
      Assert.AreEqual(Integer(Ord(lWarm > 0)), lModelCache.Metrics.CacheHits);
    finally
      lModelCache.Free;
    end;
  end;
  lFacts := TDelphiSemanticWithBinder.BindProject('Routine-Scope-Context', nil, [lModel]);
  lAstPositions := TDictionary<string, Byte>.Create;
  try
    for lRoutine in lModel.Routines do
      for lParameter in lRoutine.Parameters do
        lAstPositions.AddOrSetValue('parameter|' + LowerCase(lParameter.Name) + '|' +
          lParameter.Line.ToString + ':' + lParameter.Column.ToString, 1);
    for lLocal in lModel.Locals do
      lAstPositions.AddOrSetValue('local|' + LowerCase(lLocal.Name) + '|' +
        lLocal.Line.ToString + ':' + lLocal.Column.ToString, 1);
    lScopeless := '';
    lMisplaced := '';
    for lInventorySymbol in lFacts.Symbols do
      if SameText(lInventorySymbol.SymbolClass, 'local') or
        SameText(lInventorySymbol.SymbolClass, 'parameter') then
      begin
        if lInventorySymbol.RoutineScopeId = '' then
          lScopeless := lScopeless + ' ' + lInventorySymbol.Name + '@' +
            lInventorySymbol.Line.ToString + ':' + lInventorySymbol.Column.ToString;
        if not lAstPositions.ContainsKey(LowerCase(lInventorySymbol.SymbolClass) + '|' +
          LowerCase(lInventorySymbol.Name) + '|' + lInventorySymbol.Line.ToString + ':' +
          lInventorySymbol.Column.ToString) then
          lMisplaced := lMisplaced + ' ' + lInventorySymbol.Name + '@' +
            lInventorySymbol.Line.ToString + ':' + lInventorySymbol.Column.ToString;
      end;
  finally
    lAstPositions.Free;
  end;
  lCacheFileName := TempPath('snapshot-routine-symbol-scope-' + aName + '.sqlite3');
  lIdentity := CreateIdentity('SnapshotRoutineSymbolScope-' + aName, 'project-file-a',
    'project-context-a', 'project-include-a', 'snapshot-routine-symbol-scope-v1');
  lIdentity.SourceFileName := TempPath('RoutineSymbolScope-' + aName + '.dproj');
  lSnapshot := BuildCompatibilityRemoveWithPlanningSnapshotFromFacts(lFacts);
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      // ProjectSession persists the bound inventory as the lookup symbols.
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot, lFacts.Symbols);
    finally
      lCache.Free;
    end;
    // Two warm loads: the first must not invalidate the entry for the second.
    for lWarm := 1 to 2 do
    begin
      lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
      try
        Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot),
          'Routine symbols must reload from SQLite; scope-less local or parameter symbols:' +
          lScopeless);
        try
          Assert.AreEqual(1, lCache.Metrics.CacheHits,
            'Warm load ' + lWarm.ToString + ' must hit the cache.');
          Assert.AreEqual(0, lCache.Metrics.CacheMisses,
            'Warm load ' + lWarm.ToString + ' must not miss.');
          Assert.AreEqual(0, lCache.Metrics.Invalidations,
            'Warm load ' + lWarm.ToString + ' must not invalidate.');
          // SQLite retains the lookup inventory in item_index order. Compare
          // exact rows: compatibility twins can share names and coordinates.
          Assert.AreEqual<NativeInt>(Length(lFacts.Symbols), lLoadedSnapshot.RemoveWithPlanningSymbolCount);
          for i := 0 to High(lFacts.Symbols) do
          begin
            lInventorySymbol := lFacts.Symbols[i];
            lSymbol := lLoadedSnapshot.RemoveWithPlanningSymbolByIndex(i);
            Assert.AreEqual(lInventorySymbol.Name, lLoadedSnapshot.ExactTextOf(lSymbol.NameId));
            Assert.AreEqual(lInventorySymbol.SymbolClass, lLoadedSnapshot.ExactTextOf(lSymbol.SymbolClassId));
            Assert.AreEqual(lInventorySymbol.RoutineScopeId, lLoadedSnapshot.ExactTextOf(lSymbol.RoutineScopeIdId));
            Assert.AreEqual(lInventorySymbol.Line, lSymbol.Line);
            Assert.AreEqual(lInventorySymbol.Column, lSymbol.Column);
            Assert.AreEqual(lInventorySymbol.HeadingLine, lSymbol.HeadingLine);
            Assert.AreEqual(lInventorySymbol.HeadingColumn, lSymbol.HeadingColumn);
            Assert.AreEqual(lInventorySymbol.HeadingEndLine, lSymbol.HeadingEndLine);
            Assert.AreEqual(lInventorySymbol.HeadingEndColumn, lSymbol.HeadingEndColumn);
          end;
          for lExpectedName in aExpectedNames do
          begin
            lSeen := False;
            for i := 0 to lLoadedSnapshot.RemoveWithPlanningSymbolCount - 1 do
            begin
              lSymbol := lLoadedSnapshot.RemoveWithPlanningSymbolByIndex(i);
              lSymbolClass := lLoadedSnapshot.ExactTextOf(lSymbol.SymbolClassId);
              if (SameText(lSymbolClass, 'local') or SameText(lSymbolClass, 'parameter')) and
                SameText(lLoadedSnapshot.ExactTextOf(lSymbol.NameId), lExpectedName) then
              begin
                lSeen := True;
                Assert.AreNotEqual(0, Integer(lSymbol.RoutineScopeIdId),
                  lExpectedName + ' must keep its routine scope after reload.');
                for lInventorySymbol in lFacts.Symbols do
                  if SameText(lInventorySymbol.Name, lExpectedName) and
                    SameText(lInventorySymbol.SymbolClass, lSymbolClass) and
                    (lInventorySymbol.Line = lSymbol.Line) and
                    (lInventorySymbol.Column = lSymbol.Column) then
                    Assert.AreEqual(lInventorySymbol.RoutineScopeId,
                      lLoadedSnapshot.ExactTextOf(lSymbol.RoutineScopeIdId),
                      'A round trip must preserve the original scope identity.');
              end;
            end;
            Assert.IsTrue(lSeen, lExpectedName + ' must be persisted as a routine symbol.');
          end;
        finally
          lLoadedSnapshot.Free;
        end;
      finally
        lCache.Free;
      end;
    end;
    Assert.AreEqual('', lScopeless, 'No persisted local or parameter may lack a routine scope.');
    Assert.AreEqual('', lMisplaced,
      'Every local or parameter must sit at its AST declaration position.');
    // A routine symbol without a source scope must still reject the stored facts.
    ExecCacheSql(lCacheFileName,
      'update snapshot_remove_with_symbols set routine_scope_id_id = 0 ' +
      'where symbol_class_id in (select string_id from snapshot_project_exact_strings ' +
      'where snapshot_project_exact_strings.project_key = snapshot_remove_with_symbols.project_key ' +
      'and text_value in (''local'', ''parameter''))');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lLoaded := lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot);
      lLoadedSnapshot.Free;
      Assert.IsFalse(lLoaded, 'A routine symbol without its source scope must rebuild.');
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.ProjectGenericMethodSymbolsReloadWithScopes(const aDepth: Integer);
var
  lDescendant: string;
begin
  lDescendant := '  TIntList = class(TMyList<Integer>) end;'#13#10;
  if aDepth = 2 then
    lDescendant := lDescendant + '  TFinalList = class(TIntList) end;'#13#10;
  AssertSourceRoutineSymbolsReload('generic-' + IntToStr(aDepth),
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TMyList<T> = class'#13#10 +
    '    procedure Add(const aValue: T);'#13#10 +
    '  end;'#13#10 + lDescendant +
    'implementation'#13#10 +
    'procedure TMyList<T>.Add(const aValue: T);'#13#10 +
    'var'#13#10 +
    '  lCopy: T;'#13#10 +
    'begin'#13#10 +
    '  lCopy := aValue;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10,
    ['aValue', 'lCopy']);
end;

procedure TSnapshotSqliteTests.SourceRoutineSymbolsReloadWithRoutineScopes;
begin
  AssertSourceRoutineSymbolsReload('basic',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TCounter = record'#13#10 +
    '    Value: Integer;'#13#10 +
    '    procedure Advance(const aStep: Integer);'#13#10 +
    '  end;'#13#10 +
    'function Combine(aCount: Integer; const aText: string): string;'#13#10 +
    'implementation'#13#10 +
    'procedure TCounter.Advance(const aStep: Integer);'#13#10 +
    'begin'#13#10 +
    '  Value := Value + aStep;'#13#10 +
    'end;'#13#10 +
    'function Combine(aCount: Integer; const aText: string): string;'#13#10 +
    'var'#13#10 +
    '  lFirst, lSecond: Integer;'#13#10 +
    '  lTotal: TCounter;'#13#10 +
    'begin'#13#10 +
    '  lFirst := aCount;'#13#10 +
    '  lSecond := lFirst + 1;'#13#10 +
    '  lTotal.Value := lSecond;'#13#10 +
    '  with lTotal do Advance(lFirst);'#13#10 +
    '  Result := aText + IntToStr(lTotal.Value);'#13#10 +
    'end;'#13#10 +
    'end.'#13#10,
    ['aCount', 'aText', 'aStep', 'lFirst', 'lSecond', 'lTotal']);
end;

procedure TSnapshotSqliteTests.ParameterNamedInsideRoutineNameReloadsWithScope;
begin
  // "Value" also occurs inside "SetValue"; the parameter is after "(".
  AssertSourceRoutineSymbolsReload('routine-name',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TFoo = class'#13#10 +
    '  private'#13#10 +
    '    fValue: Integer;'#13#10 +
    '  public'#13#10 +
    '    procedure SetValue(const Value: Integer);'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'procedure TFoo.SetValue(const Value: Integer);'#13#10 +
    'begin'#13#10 +
    '  fValue := Value;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10,
    ['Value']);
end;

procedure TSnapshotSqliteTests.RoutineBoundaryTextTwinsReloadWithScopes;
begin
  AssertSourceRoutineSymbolsReload('routine-boundary',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'implementation'#13#10 +
    'procedure Before;'#13#10'begin'#13#10'end;'#13#10 +
    'procedure Run(const s: Integer);'#13#10 +
    'var lCopy: Integer;'#13#10 +
    'begin'#13#10 +
    '  lCopy := s;'#13#10 +
    '  Writeln(lCopy);'#13#10 +
    'end;'#13#10'end.'#13#10,
    ['s', 'lCopy']);
end;

procedure TSnapshotSqliteTests.EscapedMethodSymbolsReloadWithScopes;
begin
  AssertSourceRoutineSymbolsReload('escaped-method',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'type TBox = class'#13#10 +
    '  function &Label(aField, aMode: Integer): Integer; overload;'#13#10 +
    '  function &Label(const aField: string; aMode: Integer): Integer; overload;'#13#10 +
    'end;'#13#10'implementation'#13#10 +
    'function TBox.&Label(aField, aMode: Integer): Integer;'#13#10 +
    'begin'#13#10'  Result := aField + aMode;'#13#10'end;'#13#10 +
    'function TBox.&Label(const aField: string; aMode: Integer): Integer;'#13#10 +
    'begin'#13#10'  Result := Length(aField) + aMode;'#13#10'end;'#13#10 +
    'end.'#13#10,
    ['aField', 'aMode']);
end;

procedure TSnapshotSqliteTests.LocalNamedInsideEarlierLocalReloadsWithScope;
begin
  // "i" also occurs inside "lList"; the local is the whole identifier.
  AssertSourceRoutineSymbolsReload('local-prefix',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'procedure Run;'#13#10 +
    'implementation'#13#10 +
    'procedure Run;'#13#10 +
    'var'#13#10 +
    '  lList, i: Integer;'#13#10 +
    'begin'#13#10 +
    '  lList := 0;'#13#10 +
    '  for i := 1 to 3 do'#13#10 +
    '    lList := lList + i;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10,
    ['lList', 'i']);
end;

procedure TSnapshotSqliteTests.MultiLineSignatureParametersReloadWithScope;
begin
  // "Count" occurs inside "SetCount" on the routine line and "aCount" inside
  // "aCountLimit" on an earlier parameter line.
  AssertSourceRoutineSymbolsReload('multi-line',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'procedure SetCount(aCountLimit: Integer;'#13#10 +
    '  aCount: Integer;'#13#10 +
    '  const Count: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure SetCount(aCountLimit: Integer;'#13#10 +
    '  aCount: Integer;'#13#10 +
    '  const Count: Integer);'#13#10 +
    'var'#13#10 +
    '  lSum: Integer;'#13#10 +
    'begin'#13#10 +
    '  lSum := aCountLimit + aCount + Count;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10,
    ['aCountLimit', 'aCount', 'Count', 'lSum']);
end;

procedure TSnapshotSqliteTests.OverloadParametersReloadWithTheirOwnScopes;
begin
  AssertSourceRoutineSymbolsReload('overloads',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'procedure Put(const aValue: Integer); overload;'#13#10 +
    'procedure Put(const aValue: string); overload;'#13#10 +
    'implementation'#13#10 +
    'procedure Put(const aValue: Integer);'#13#10 +
    'var'#13#10 +
    '  lText: string;'#13#10 +
    'begin'#13#10 +
    '  lText := IntToStr(aValue);'#13#10 +
    'end;'#13#10 +
    'procedure Put(const aValue: string);'#13#10 +
    'var'#13#10 +
    '  lText: string;'#13#10 +
    'begin'#13#10 +
    '  lText := aValue;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10,
    ['aValue', 'lText']);
end;

procedure TSnapshotSqliteTests.CommentedParameterNameReloadsWithScope;
begin
  // The comment holds the name before the declaration, so the text scanner
  // cannot place the parameter at its AST position.
  AssertSourceRoutineSymbolsReload('comment',
    'unit RoutineScopeUnit;'#13#10 +
    'interface'#13#10 +
    'procedure Run({ aValue is legacy } aValue: Integer);'#13#10 +
    'implementation'#13#10 +
    'procedure Run({ aValue is legacy } aValue: Integer);'#13#10 +
    'begin'#13#10 +
    '  if aValue > 0 then'#13#10 +
    '    Exit;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10,
    ['aValue']);
end;

procedure TSnapshotSqliteTests.RemoveWithAccessOwnerIdentityReloadRejectsMissingRows;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lLookupSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lSnapshot: TDelphiProjectSnapshot;
  lTypeIdentity: TSemanticRemoveWithTypeIdentityFact;
begin
  lCacheFileName := TempPath('snapshot-remove-with-access-owner.sqlite3');
  lIdentity := CreateIdentity('SnapshotRemoveWithAccessOwner', 'project-file-a',
    'project-context-a', 'project-include-a', 'snapshot-access-owner-v1');
  lIdentity.SourceFileName := TempPath('RemoveWithAccessOwner.dproj');
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('Access-Owner-Context');
    SetLength(lFacts.Symbols, 1);
    lFacts.Symbols[0].NameId := lBuilder.ExactStrings.Intern('Child');
    lFacts.Symbols[0].SymbolClassId := lBuilder.ExactStrings.Intern('field');
    lFacts.Symbols[0].OwnerNameId := lBuilder.ExactStrings.Intern('TDerived');
    lFacts.Symbols[0].OwnerTypeId := lFacts.Symbols[0].OwnerNameId;
    lTypeIdentity := Default(TSemanticRemoveWithTypeIdentityFact);
    lTypeIdentity.UnitIdId := lBuilder.ExactStrings.Intern('base-unit-id');
    lTypeIdentity.UnitNameId := lBuilder.ExactStrings.Intern('BaseUnit');
    lTypeIdentity.NameId := lBuilder.ExactStrings.Intern('TBase');
    lTypeIdentity.KindId := lBuilder.ExactStrings.Intern('class');
    lTypeIdentity.DeclaredIdId := lBuilder.ExactStrings.Intern('base-declared-id');
    lTypeIdentity.CanonicalIdId := lBuilder.ExactStrings.Intern('base-canonical-id');
    lTypeIdentity.SectionKindId := lBuilder.ExactStrings.Intern('interface');
    lTypeIdentity.FileNameId := lBuilder.ExactStrings.Intern('BaseUnit.pas');
    lTypeIdentity.Line := 10;
    lTypeIdentity.Column := 3;
    lFacts.Symbols[0].OwnerIdentity := lTypeIdentity;
    lTypeIdentity.UnitIdId := lBuilder.ExactStrings.Intern('derived-unit-id');
    lTypeIdentity.UnitNameId := lBuilder.ExactStrings.Intern('DerivedUnit');
    lTypeIdentity.NameId := lBuilder.ExactStrings.Intern('TDerived');
    lTypeIdentity.DeclaredIdId := lBuilder.ExactStrings.Intern('derived-declared-id');
    lTypeIdentity.CanonicalIdId := lBuilder.ExactStrings.Intern('derived-canonical-id');
    lTypeIdentity.FileNameId := lBuilder.ExactStrings.Intern('DerivedUnit.pas');
    lTypeIdentity.Line := 8;
    lFacts.Symbols[0].AccessOwnerIdentity := lTypeIdentity;
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    SetLength(lLookupSymbols, 1);
    lLookupSymbols[0] := Default(TDelphiSemanticInventorySymbol);
    lLookupSymbols[0].Name := 'Child';
    lLookupSymbols[0].SymbolClass := 'field';
    lLookupSymbols[0].OwnerName := 'TDerived';
    lLookupSymbols[0].OwnerType := 'TDerived';
    lLookupSymbols[0].OwnerIdentity.UnitId.Value := 'base-unit-id';
    lLookupSymbols[0].OwnerIdentity.UnitName := 'BaseUnit';
    lLookupSymbols[0].OwnerIdentity.Name := 'TBase';
    lLookupSymbols[0].OwnerIdentity.Kind := 'class';
    lLookupSymbols[0].OwnerIdentity.DeclaredId.Value := 'base-declared-id';
    lLookupSymbols[0].OwnerIdentity.CanonicalId.Value := 'base-canonical-id';
    lLookupSymbols[0].OwnerIdentity.SectionKind := 'interface';
    lLookupSymbols[0].OwnerIdentity.SourceRange.FileName := 'BaseUnit.pas';
    lLookupSymbols[0].OwnerIdentity.SourceRange.Line := 10;
    lLookupSymbols[0].OwnerIdentity.SourceRange.Column := 3;
    lLookupSymbols[0].AccessOwnerIdentity := lLookupSymbols[0].OwnerIdentity;
    lLookupSymbols[0].AccessOwnerIdentity.UnitId.Value := 'derived-unit-id';
    lLookupSymbols[0].AccessOwnerIdentity.UnitName := 'DerivedUnit';
    lLookupSymbols[0].AccessOwnerIdentity.Name := 'TDerived';
    lLookupSymbols[0].AccessOwnerIdentity.DeclaredId.Value := 'derived-declared-id';
    lLookupSymbols[0].AccessOwnerIdentity.CanonicalId.Value := 'derived-canonical-id';
    lLookupSymbols[0].AccessOwnerIdentity.SourceRange.FileName := 'DerivedUnit.pas';
    lLookupSymbols[0].AccessOwnerIdentity.SourceRange.Line := 8;
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot, lLookupSymbols);
    finally
      lCache.Free;
    end;
    Assert.AreEqual(2, TableRowCount(lCacheFileName,
      'snapshot_remove_with_type_identities'));
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot));
      try
        Assert.AreEqual('base-declared-id', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningSymbolByIndex(0).OwnerIdentity.DeclaredIdId));
        Assert.AreEqual('derived-declared-id', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningSymbolByIndex(0).AccessOwnerIdentity.DeclaredIdId));
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
    ExecCacheSql(lCacheFileName,
      'delete from snapshot_remove_with_type_identities where entity_kind = ''symbol-access-owner''');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lLoadedSnapshot := nil;
      try
        Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity, lLoadedSnapshot),
          'Missing inherited access provenance must invalidate the persisted facts.');
        Assert.IsNull(lLoadedSnapshot);
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.CastMemberRefusesMismatchedSourceOffset;
var
  i: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TSemanticReferenceFact;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lFound: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TempPath('cast-offset.pas');
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CastOffset;'#13#10'interface'#13#10'type'#13#10 +
    '  TRec = record FieldValue: Integer; OtherValue: Integer; end;'#13#10 +
    '  PRec = ^TRec;'#13#10'implementation'#13#10'procedure Run;'#13#10 +
    'begin'#13#10'  PRec(nil)^.OtherValue := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lFound := 0;
  for i := 0 to High(lModel.References) do
    if SameText(lModel.References[i].Name, 'OtherValue') then
    begin
      Inc(lFound);
      lModel.References[i].Name := 'FieldValue';
    end;
  Assert.AreEqual(1, lFound, 'A real cast-member reference must reach the guard.');
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  lSnapshot := BuildProjectSnapshotFromModels([lModel], lFacts,
    Default(TDelphiSnapshotBuildOptions), lMetrics);
  try
    lUnit := lSnapshot.UnitByIndex(0);
    lFound := 0;
    for i := 1 to lUnit.ReferenceCount do
    begin
      lReference := lUnit.ReferenceById(i);
      if (lSnapshot.TextOf(lReference.NameId) = 'FieldValue') and
        (lReference.Line = 9) then
      begin
        Inc(lFound);
        Assert.AreEqual<Cardinal>(0, lReference.TargetSymbolId,
          'A mismatched source position cannot prove a cast-member target.');
      end;
    end;
    Assert.AreEqual(1, lFound);
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.Schema13PlanningRowsRebuildWholeSnapshotCache(const aOldSchema: string);
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lProjectIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lSnapshot: TDelphiProjectSnapshot;
  lUnitIdentity: TDelphiSemanticSnapshotCacheIdentity;
begin
  lCacheFileName := TempPath('snapshot-schema-' + aOldSchema + '-rebuild.sqlite3');
  lUnitIdentity := CreateIdentity('SnapshotSchema13Unit', 'file-a', 'context-a',
    'include-a', 'snapshot-v1');
  lProjectIdentity := CreateIdentity('SnapshotSchema13Project', 'file-a',
    'context-a', 'include-a', 'snapshot-v1');
  StoreDemoUnit(lCacheFileName, lUnitIdentity);
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('Schema13Context');
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lProjectIdentity, lSnapshot);
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
  Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_units'));
  Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_project_remove_with_facts'));
  ExecCacheSql(lCacheFileName,
    'create table source_owner_marker (value_text text not null)');
  ExecCacheSql(lCacheFileName,
    'insert into source_owner_marker(value_text) values (''source-data'')');
  ExecCacheSql(lCacheFileName,
    'create table old_remove_with_facts as select p.cache_key, context_fingerprint_id, ' +
    'routine_owner_count, symbol_count, binding_count from snapshot_remove_with_facts f ' +
    'join snapshot_project_remove_with_facts p on p.project_key=f.project_key');
  ExecCacheSql(lCacheFileName, 'drop table snapshot_remove_with_facts');
  ExecCacheSql(lCacheFileName,
    'alter table old_remove_with_facts rename to snapshot_remove_with_facts');
  ExecCacheSql(lCacheFileName,
    'update meta set value_text = ' + QuotedStr(aOldSchema) +
    ' where key_name = ''snapshot_schema_version''');
  Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_remove_with_facts'));
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    lLoadedSnapshot := nil;
    try
      Assert.IsFalse(lCache.TryLoadUnit(lUnitIdentity, lLoadedSnapshot));
      Assert.IsNull(lLoadedSnapshot);
      Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lProjectIdentity,
        lLoadedSnapshot));
      Assert.IsNull(lLoadedSnapshot);
    finally
      lLoadedSnapshot.Free;
    end;
  finally
    lCache.Free;
  end;
  Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_units'));
  Assert.AreEqual(0, TableRowCount(lCacheFileName,
    'snapshot_project_remove_with_facts'));
  Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_remove_with_facts'));
  Assert.AreEqual(1, TableRowCount(lCacheFileName, 'source_owner_marker'));
end;

procedure TSnapshotSqliteTests.StoreProjectRemoveWithPlanningFactsUsesProjectIdentity;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lChangedIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lLookupSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lCacheFileName := TempPath('snapshot-project-remove-with-facts.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);

  lIdentity := CreateIdentity('SnapshotProjectRemoveWithFacts', 'project-file-a',
    'project-context-a', 'project-include-a', 'snapshot-project-remove-with-v1');
  lIdentity.SourceFileName := TempPath('ProjectRemoveWithFacts.dproj');

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('Project-Context-A');
    SetLength(lFacts.Bindings, 1);
    lFacts.Bindings[0].SelectorTextId := lBuilder.ExactStrings.Intern('CurrentSelector');
    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    SetLength(lLookupSymbols, 1);
    lLookupSymbols[0].Name := 'CurrentSelector';
    lLookupSymbols[0].SymbolClass := 'type-member';
    lLookupSymbols[0].Kind := 'property';
    lLookupSymbols[0].OwnerType := 'TProjectRemoveWithFacts';
    lLookupSymbols[0].TypeName := 'Integer';

    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreProjectRemoveWithPlanningFacts(lIdentity, lSnapshot,
        lLookupSymbols);
    finally
      lCache.Free;
    end;

    Assert.AreEqual(1, TableRowCount(lCacheFileName,
      'snapshot_project_remove_with_facts'));
    Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_remove_with_facts'));
    Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_remove_with_symbols'));
    Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_units'));

    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadProjectRemoveWithPlanningFacts(lIdentity,
        lLoadedSnapshot));
      try
        Assert.AreEqual('Project-Context-A', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningContextFingerprintId));
        Assert.AreEqual('CurrentSelector', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningBindingByIndex(0).SelectorTextId));
      finally
        lLoadedSnapshot.Free;
      end;

      lChangedIdentity := lIdentity;
      lChangedIdentity.ContextHash := 'project-context-b';
      lLoadedSnapshot := nil;
      Assert.IsFalse(lCache.TryLoadProjectRemoveWithPlanningFacts(lChangedIdentity,
        lLoadedSnapshot));
      Assert.IsNull(lLoadedSnapshot);
      Assert.AreEqual(1, lCache.Metrics.Invalidations);
      Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    finally
      lCache.Free;
    end;

    Assert.AreEqual(0, TableRowCount(lCacheFileName,
      'snapshot_project_remove_with_facts'));
    Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_remove_with_facts'));
    Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_remove_with_symbols'));
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.StoreRejectsAmbiguousIdentityValues;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCaseIndex: Integer;
  lCacheFileName: string;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lUnit: TUnitSnapshot;
begin
  lCacheFileName := TempPath('snapshot-invalid-identity.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lCache := nil;
  lUnit := nil;
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('InvalidIdentityUnit.pas'),
      lBuilder.Strings.Intern('InvalidIdentityUnit'));

    for lCaseIndex := 0 to 6 do
    begin
      lIdentity := CreateIdentity('SnapshotInvalidIdentityUnit' + IntToStr(lCaseIndex),
        'file-a', 'context-a', 'include-a', 'snapshot-v1');
      case lCaseIndex of
        0:
          lIdentity.CacheKey := '';
        1:
          lIdentity.IdentityKey := '';
        2:
          lIdentity.SourceFileName := '';
        3:
          lIdentity.FileHash := '';
        4:
          lIdentity.ContextHash := '';
        5:
          lIdentity.IncludeGraphHash := '';
        6:
          lIdentity.SchemaVersion := '';
      end;

      Assert.WillRaise(
        procedure
        begin
          lCache.StoreUnit(lIdentity, lBuilder.Strings, lUnit);
        end, Exception);
      Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_units'));
    end;
  finally
    lUnit.Free;
    lCache.Free;
    lBuilder.Free;
  end;
end;

procedure TSnapshotSqliteTests.StoreUnitFromSnapshotDoesNotPersistRemoveWithPlanningFacts;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lFileNameId: TSemanticStringId;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lSnapshot: TDelphiProjectSnapshot;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
begin
  lCacheFileName := TempPath('snapshot-remove-with-facts.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotRemoveWithFactsUnit', 'file-a', 'context-a',
    'include-a', 'snapshot-v1');

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern('RemoveWithUnit.pas');
    lUnitNameId := lBuilder.Strings.Intern('RemoveWithUnit');
    lUnit := TUnitSnapshot.Create(3, lFileNameId, lUnitNameId);
    lBuilder.AddUnit(lUnit);

    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := lBuilder.ExactStrings.Intern('Context-A');
    SetLength(lFacts.RoutineOwners, 1);
    lFacts.RoutineOwners[0].NameId := lBuilder.ExactStrings.Intern('UseWidget');
    lFacts.RoutineOwners[0].SymbolClassId := lBuilder.ExactStrings.Intern('routine');
    lFacts.RoutineOwners[0].KindId := lBuilder.ExactStrings.Intern('procedure');
    lFacts.RoutineOwners[0].FileNameId := lBuilder.ExactStrings.Intern('RemoveWithUnit.pas');
    lFacts.RoutineOwners[0].Line := 10;
    lFacts.RoutineOwners[0].Column := 3;
    lFacts.RoutineOwners[0].EndLine := 12;
    lFacts.RoutineOwners[0].EndColumn := 6;

    SetLength(lFacts.Bindings, 1);
    lFacts.Bindings[0].SemanticIdId := lBuilder.ExactStrings.Intern('with-1');
    lFacts.Bindings[0].FileNameId := lBuilder.ExactStrings.Intern('RemoveWithUnit.pas');
    lFacts.Bindings[0].UnitNameId := lBuilder.ExactStrings.Intern('RemoveWithUnit');
    lFacts.Bindings[0].RoutineNameId := lBuilder.ExactStrings.Intern('UseWidget');
    lFacts.Bindings[0].SelectorTextId := lBuilder.ExactStrings.Intern('DF[D]^');
    lFacts.Bindings[0].StatusId := lBuilder.ExactStrings.Intern('planned');
    lFacts.Bindings[0].Line := 20;
    lFacts.Bindings[0].Column := 5;
    lFacts.Bindings[0].EndLine := 23;
    lFacts.Bindings[0].EndColumn := 8;
    SetLength(lFacts.Bindings[0].Selectors, 1);
    lFacts.Bindings[0].Selectors[0].SelectorTextId := lFacts.Bindings[0].SelectorTextId;
    lFacts.Bindings[0].Selectors[0].StatusId := lFacts.Bindings[0].StatusId;
    lFacts.Bindings[0].Selectors[0].ReasonCodeId := lBuilder.ExactStrings.Intern('ok');
    lFacts.Bindings[0].Selectors[0].TypeNameId := lBuilder.ExactStrings.Intern('TWidget');
    SetLength(lFacts.Bindings[0].References, 1);
    lFacts.Bindings[0].References[0].SemanticIdId := lBuilder.ExactStrings.Intern('ref-1');
    lFacts.Bindings[0].References[0].NameId := lBuilder.ExactStrings.Intern('Value');
    lFacts.Bindings[0].References[0].ClassificationId := lBuilder.ExactStrings.Intern('member');
    lFacts.Bindings[0].References[0].Line := 21;
    lFacts.Bindings[0].References[0].Column := 7;

    lBuilder.SetRemoveWithPlanningFacts(lFacts);
    lSnapshot := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    finally
      lCache.Free;
    end;

    Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_remove_with_facts'));
    Assert.AreEqual(0, TableRowCount(lCacheFileName,
      'snapshot_remove_with_routine_owners'));
    Assert.AreEqual(0, TableRowCount(lCacheFileName, 'snapshot_remove_with_bindings'));
    Assert.AreEqual(0, TableRowCount(lCacheFileName,
      'snapshot_remove_with_binding_selectors'));
    Assert.AreEqual(0, TableRowCount(lCacheFileName,
      'snapshot_remove_with_binding_references'));

    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoadedSnapshot));
      try
        Assert.IsFalse(lLoadedSnapshot.HasRemoveWithPlanningFacts,
          'Unit cache entries must not persist project-wide remove-with planning facts.');
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
end;

procedure TSnapshotSqliteTests.StoresAndLoadsUnitSnapshotDenseFacts;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lHighIndex: Integer;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lImplementationId: TSemanticStringId;
  lInterfaceId: TSemanticStringId;
  lLowIndex: Integer;
  lMemberNameId: TSemanticStringId;
  lProject: TDelphiProjectSnapshot;
  lProjectSourceId: TSemanticStringId;
  lPublishedId: TSemanticStringId;
  lReference: TSemanticReferenceFact;
  lReferenceRef: TSemanticReferenceRef;
  lRoutineId: TSemanticStringId;
  lSignatureId: TSemanticStringId;
  lSymbol: TSemanticSymbolFact;
  lSymbolRef: TSemanticSymbolRef;
  lUnit: TUnitSnapshot;
  lUnitId: TSemanticUnitId;
  lWidgetTypeId: TSemanticStringId;
begin
  lCacheFileName := TempPath('snapshot-roundtrip.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);
  lIdentity := CreateIdentity('SnapshotRoundtripUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v1');

  StoreDemoUnit(lCacheFileName, lIdentity);

  Assert.IsTrue(TableRowCount(lCacheFileName, 'snapshot_strings') >= 8);
  Assert.AreEqual(2, TableRowCount(lCacheFileName, 'snapshot_symbols'));
  Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_with_statements'));
  Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_references'));

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
  try
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lProject));
    try
      Assert.IsTrue(lProject.TryFindUnitByFileName('demounit.pas', lUnitId));
      Assert.AreEqual(7, Integer(lUnitId));
      Assert.IsTrue(lProject.TryFindUnitById(7, lUnit));
      Assert.AreEqual(2, lUnit.SymbolCount);
      Assert.IsTrue(lProject.TryFindStringId('interface', lInterfaceId));
      Assert.IsTrue(lProject.TryFindStringId('project-source', lProjectSourceId));
      Assert.IsTrue(lProject.TryFindStringId('published', lPublishedId));
      Assert.IsTrue(lProject.TryFindStringId('UseWidget', lRoutineId));
      Assert.IsTrue(lProject.TryFindStringId('property Value: Integer', lSignatureId));
      lSymbol := lUnit.SymbolById(2);
      Assert.AreEqual(Integer(lInterfaceId), Integer(lSymbol.SectionKindId));
      Assert.AreEqual(Integer(lProjectSourceId), Integer(lSymbol.SourceKindId));
      Assert.AreEqual(Integer(lPublishedId), Integer(lSymbol.VisibilityId));
      Assert.AreEqual(Integer(lSignatureId), Integer(lSymbol.SignatureId));
      Assert.AreEqual(1, lUnit.WithStatementCount);
      Assert.AreEqual(1, lUnit.ReferenceCount);
      Assert.AreEqual(22, lUnit.ReferenceById(1).Line);
      Assert.IsTrue(lProject.TryFindStringId('TWidget', lWidgetTypeId));
      Assert.IsTrue(lProject.TryFindStringId('Value', lMemberNameId));
      Assert.IsTrue(lProject.TryFindMember(lWidgetTypeId, lMemberNameId, lSymbolRef));
      Assert.AreEqual(7, Integer(lSymbolRef.UnitId));
      Assert.AreEqual(2, Integer(lSymbolRef.SymbolId));
      Assert.IsTrue(lProject.TryReferencesForSymbol(lSymbolRef, lLowIndex, lHighIndex));
      lReferenceRef := lProject.ReferenceRefBySymbolIndex(lLowIndex);
      Assert.AreEqual(7, Integer(lReferenceRef.UnitId));
      Assert.AreEqual(1, Integer(lReferenceRef.ReferenceId));
      lReference := lUnit.ReferenceById(lReferenceRef.ReferenceId);
      Assert.IsTrue(lProject.TryFindStringId('implementation', lImplementationId));
      Assert.AreEqual(Integer(lMemberNameId), Integer(lReference.NameId));
      Assert.AreEqual(Integer(lRoutineId), Integer(lReference.RoutineId));
      Assert.AreEqual(Integer(lImplementationId), Integer(lReference.SectionKindId));
      Assert.AreEqual(Integer(lProjectSourceId), Integer(lReference.SourceKindId));
      Assert.AreEqual('DemoBody.inc', lProject.TextOf(lReference.FileId));
      Assert.AreEqual('DemoTypes.inc', lProject.TextOf(lUnit.SymbolById(1).FileId));
      Assert.AreEqual(0, Integer(lUnit.SymbolById(2).FileId));
    finally
      lProject.Free;
    end;
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
  finally
    lCache.Free;
  end;
end;

function TSnapshotSqliteTests.TableRowCount(const aCacheFileName,
  aTableName: string): Integer;
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
    Result := Integer(lConnection.ExecSQLScalar('select count(*) from ' + aTableName));
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

function TSnapshotSqliteTests.TempPath(const aName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([SnapshotSqliteTempRoot, aName]));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
end;

procedure TSnapshotSqliteTests.IncludedGlobalEvidenceSurvivesReload(const aCheck: string);
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCount: Integer;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot, lInclude, lCacheFile: string;
  lSnapshot, lLoaded: TDelphiProjectSnapshot;
  lUsage: TDelphiSemanticGlobalUsage;
begin
  lRoot := CreateTestTempRoot('include-sqlite-probe-temp');
  lInclude := TPath.Combine(lRoot, 'body.inc');
  lCacheFile := TPath.Combine(lRoot, 'probe.sqlite3');
  TFile.WriteAllText(lInclude, 'GF := 7;', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeSqliteProbe.pas'),
    'unit IncludeSqliteProbe;'#13#10'interface'#13#10'var GF: Integer;'#13#10 +
    'implementation'#13#10'procedure Run;'#13#10'begin'#13#10 +
    '{$I body.inc}'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeSqliteProbe.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lIdentity := CreateIdentity('IncludeSqliteProbe', 'captured-unit', 'context',
    'captured-include', 'include-reconciliation-probe');
  lIdentity.SourceFileName := lOptions.SourceFileName;
  lSnapshot := BuildProjectSnapshotFromModels([lModel],
    Default(TDelphiSemanticProjectWithBindingFacts),
    Default(TDelphiSnapshotBuildOptions), lMetrics);
  try
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFile);
    try
      lCache.StoreUnitFromSnapshot(lIdentity, lSnapshot, 0);
    finally
      lCache.Free;
    end;
  finally
    lSnapshot.Free;
  end;
  lModel := Default(TDelphiSemanticUnitModel);
  TFile.WriteAllText(lInclude, 'Inc(GF);', TEncoding.ASCII);
  lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFile);
  try
    Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoaded), 'Stored facts must actually reload.');
    try
      Assert.AreEqual(1, lCache.Metrics.CacheHits);
      lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lLoaded);
      lCount := 0;
      for lUsage in lAnalysis.Usages do
        if lUsage.Name = 'GF' then
        begin
          Inc(lCount);
          if aCheck = 'file' then
          begin
            Assert.AreEqual(lInclude, lUsage.FileName);
            Assert.AreEqual(1, lUsage.Line);
            Assert.AreEqual(1, lUsage.Column);
          end else
            Assert.AreEqual('write', lUsage.Access, 'Reload must retain the captured assignment.');
        end;
      Assert.AreEqual(1, lCount);
    finally
      lLoaded.Free;
    end;
  finally
    lCache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSnapshotSqliteTests);

end.
