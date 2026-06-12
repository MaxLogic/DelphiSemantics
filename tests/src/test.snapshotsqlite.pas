unit Test.SnapshotSqlite;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Snapshot.Cache.Sqlite;

type
  [TestFixture]
  TSnapshotSqliteTests = class
  private
    function CreateIdentity(const aName, aFileHash, aContextHash, aIncludeGraphHash,
      aSchemaVersion: string): TDelphiSemanticSnapshotCacheIdentity;
    procedure ExecCacheSql(const aCacheFileName, aSql: string);
    procedure StoreDemoUnit(const aCacheFileName: string;
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity);
    function TableRowCount(const aCacheFileName, aTableName: string): Integer;
    function TempPath(const aName: string): string;
    procedure AssertIdentityChangeMissesWithoutEviction(const aName: string; const aChangedIdentity:
      TDelphiSemanticSnapshotCacheIdentity);
  public
    [Test]
    procedure CacheKeyReuseWithDifferentIdentityDoesNotLoadStoredUnit;
    [Test]
    procedure ContextSpecificSnapshotVariantsShareIdentityWithoutEviction;
    [Test]
    procedure CorruptStringIdInvalidatesStoredSnapshot;
    [Test]
    procedure DefaultSnapshotBuildDoesNotRequireSqliteCache;
    [Test]
    procedure BuildProjectSnapshotFromUnitSnapshotsPreservesRemoveWithPlanningFacts;
    [Test]
    procedure InvalidationDeletesAtomicallyWhenDeleteFails;
    [Test]
    procedure MalformedLoadIdentityDoesNotDeleteStoredUnit;
    [Test]
    procedure MetricsReportHitTimingAndUsefulness;
    [Test]
    procedure MetricsReportMissTelemetry;
    [Test]
    procedure MetricsRequirePositiveParseSavingsForUsefulCache;
    [Test]
    procedure StoreRejectsAmbiguousIdentityValues;
    [Test]
    procedure SnapshotSqliteCacheUsesPreparedStatementsAndCachedFields;
    [Test]
    procedure SnapshotSqliteCacheUsesWideTextAccessors;
    [Test]
    procedure SnapshotCacheSourceDoesNotUseJsonRepresentation;
    [Test]
    procedure StoreUnitFromSnapshotPreservesUnicodeTextValues;
    [Test]
    procedure StoreUnitFromSnapshotPreservesRemoveWithPlanningFacts;
    [Test]
    procedure SparseChildRowsInvalidateStoredSnapshot;
    [Test]
    procedure StoresAndLoadsUnitSnapshotDenseFacts;
    [Test]
    procedure SecondCacheInstanceReusesStoredUnitSnapshot;
    [Test]
    procedure SourceContextIncludeAndSchemaChangesMissWithoutIdentityWideEviction;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils, System.Variants,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def,
  maxLogic.IOUtils,
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.RemoveWith;

var
  GSnapshotSqliteTempRoot: string;

function SnapshotUnicodeText: string;
begin
  Result := 'Za' + #$017C + #$00F3 + #$0142 + #$0107 + '-' + #$6F22 + #$5B57;
end;

function SnapshotSqliteTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GSnapshotSqliteTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}', '',
      [rfReplaceAll]);
    GSnapshotSqliteTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'snapshot-sqlite-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GSnapshotSqliteTempRoot);
  Result := GSnapshotSqliteTempRoot;
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

procedure TSnapshotSqliteTests.BuildProjectSnapshotFromUnitSnapshotsPreservesRemoveWithPlanningFacts;
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
      Assert.IsTrue(lMergedSnapshot.HasRemoveWithPlanningFacts);
      Assert.AreEqual('Merge-Context', lMergedSnapshot.ExactTextOf(
        lMergedSnapshot.RemoveWithPlanningContextFingerprintId));
      Assert.AreEqual('DF[D]^', lMergedSnapshot.ExactTextOf(
        lMergedSnapshot.RemoveWithPlanningBindingByIndex(0).SelectorTextId));
    finally
      lMergedSnapshot.Free;
    end;
  finally
    lSnapshot.Free;
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
  lSnapshot: TDelphiProjectSnapshot;
  lSourceFileName: string;
  lSymbol: TSemanticSymbolFact;
  lTypeName: string;
  lTypeNameId: TSemanticStringId;
  lUnit: TUnitSnapshot;
  lUnitNameId: TSemanticStringId;
  lUnicodeText: string;
begin
  lCacheFileName := TempPath('snapshot-unicode.sqlite3');
  if TFile.Exists(lCacheFileName) then
    TFile.Delete(lCacheFileName);

  lUnicodeText := SnapshotUnicodeText;
  lSourceFileName := TempPath('Snapshot-' + lUnicodeText + '.pas');
  lTypeName := 'T' + lUnicodeText;
  lMemberName := 'Value' + lUnicodeText;
  lExactContextText := 'Context-' + lUnicodeText;
  lIdentity := CreateIdentity('SnapshotUnicodeUnit', 'file-unicode', 'context-unicode',
    'include-unicode', 'snapshot-v1');
  lIdentity.IdentityKey := 'SnapshotIdentity-' + lUnicodeText;
  lIdentity.SourceFileName := lSourceFileName;
  lIdentity.CacheKey := lIdentity.IdentityKey + '|file-unicode|context-unicode|' +
    'include-unicode|snapshot-v1';

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    lFileNameId := lBuilder.Strings.Intern(lSourceFileName);
    lUnitNameId := lBuilder.Strings.Intern('SnapshotUnicodeUnit');
    lTypeNameId := lBuilder.Strings.Intern(lTypeName);
    lMemberNameId := lBuilder.Strings.Intern(lMemberName);
    lUnit := TUnitSnapshot.Create(19, lFileNameId, lUnitNameId);

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

procedure TSnapshotSqliteTests.StoreUnitFromSnapshotPreservesRemoveWithPlanningFacts;
var
  lBinding: TSemanticRemoveWithBindingFact;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lCacheFileName: string;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lFileNameId: TSemanticStringId;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lLoadedFacts: TSemanticRemoveWithPlanningFacts;
  lLoadedSnapshot: TDelphiProjectSnapshot;
  lRoutineOwner: TSemanticRemoveWithInventorySymbolFact;
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

    Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_remove_with_facts'));
    Assert.AreEqual(1, TableRowCount(lCacheFileName,
      'snapshot_remove_with_routine_owners'));
    Assert.AreEqual(1, TableRowCount(lCacheFileName, 'snapshot_remove_with_bindings'));
    Assert.AreEqual(1, TableRowCount(lCacheFileName,
      'snapshot_remove_with_binding_selectors'));
    Assert.AreEqual(1, TableRowCount(lCacheFileName,
      'snapshot_remove_with_binding_references'));

    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      Assert.IsTrue(lCache.TryLoadUnit(lIdentity, lLoadedSnapshot));
      try
        Assert.IsTrue(lLoadedSnapshot.HasRemoveWithPlanningFacts);
        Assert.AreEqual('Context-A', lLoadedSnapshot.ExactTextOf(
          lLoadedSnapshot.RemoveWithPlanningContextFingerprintId));
        Assert.AreEqual(1, lLoadedSnapshot.RemoveWithPlanningRoutineOwnerCount);
        Assert.AreEqual(1, lLoadedSnapshot.RemoveWithPlanningBindingCount);
        lRoutineOwner := lLoadedSnapshot.RemoveWithPlanningRoutineOwnerByIndex(0);
        Assert.AreEqual('UseWidget', lLoadedSnapshot.ExactTextOf(lRoutineOwner.NameId));
        lBinding := lLoadedSnapshot.RemoveWithPlanningBindingByIndex(0);
        Assert.AreEqual('DF[D]^', lLoadedSnapshot.ExactTextOf(lBinding.SelectorTextId));
        Assert.AreEqual(1, Length(lBinding.Selectors));
        Assert.AreEqual('TWidget', lLoadedSnapshot.ExactTextOf(
          lBinding.Selectors[0].TypeNameId));
        Assert.AreEqual(1, Length(lBinding.References));
        Assert.AreEqual('Value', lLoadedSnapshot.ExactTextOf(
          lBinding.References[0].NameId));
        lLoadedFacts := lLoadedSnapshot.RemoveWithPlanningFacts;
        Assert.AreEqual(1, Length(lLoadedFacts.Bindings));
      finally
        lLoadedSnapshot.Free;
      end;
    finally
      lCache.Free;
    end;

    ExecCacheSql(lCacheFileName, 'delete from snapshot_remove_with_binding_selectors');
    lCache := TDelphiSemanticSnapshotSqliteCache.Create(lCacheFileName);
    try
      lLoadedSnapshot := nil;
      try
        Assert.IsFalse(lCache.TryLoadUnit(lIdentity, lLoadedSnapshot));
        Assert.IsNull(lLoadedSnapshot);
      finally
        lLoadedSnapshot.Free;
      end;
      Assert.AreEqual(1, lCache.Metrics.Invalidations);
      Assert.AreEqual(1, lCache.Metrics.CacheMisses);
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

initialization
  TDUnitX.RegisterTestFixture(TSnapshotSqliteTests);

end.
