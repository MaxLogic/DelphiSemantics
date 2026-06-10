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
    procedure AssertIdentityChangeInvalidates(const aName: string; const aChangedIdentity:
      TDelphiSemanticSnapshotCacheIdentity);
  public
    [Test]
    procedure CacheKeyReuseWithDifferentIdentityDoesNotLoadStoredUnit;
    [Test]
    procedure CorruptStringIdInvalidatesStoredSnapshot;
    [Test]
    procedure DefaultSnapshotBuildDoesNotRequireSqliteCache;
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
    procedure SnapshotCacheSourceDoesNotUseJsonRepresentation;
    [Test]
    procedure SparseChildRowsInvalidateStoredSnapshot;
    [Test]
    procedure StoresAndLoadsUnitSnapshotDenseFacts;
    [Test]
    procedure SecondCacheInstanceReusesStoredUnitSnapshot;
    [Test]
    procedure SourceContextIncludeAndSchemaChangesInvalidateStoredSnapshot;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils, System.Variants,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def,
  maxLogic.IOUtils,
  DelphiSemantics.Snapshot;

procedure TSnapshotSqliteTests.AssertIdentityChangeInvalidates(const aName: string;
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
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
    Assert.AreEqual(1, lCache.Metrics.SnapshotCacheProbes);
    Assert.IsTrue(lCache.Metrics.SnapshotSqlReadMilliseconds >= 2);
    Assert.IsTrue(lCache.Metrics.SnapshotDeserializeMilliseconds >= 0);
    Assert.IsTrue(lCache.Metrics.SnapshotIndexRebuildMilliseconds >= 0);
    Assert.AreEqual(Int64(0), lCache.Metrics.SnapshotParseAvoidedEstimateMilliseconds);
    Assert.IsFalse(lCache.Metrics.SnapshotCacheUseful);
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
  lChangedIdentity := CreateIdentity('SnapshotAtomicDeleteUnit', 'file-b', 'context-a',
    'include-a', 'snapshot-v1');

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

procedure TSnapshotSqliteTests.SourceContextIncludeAndSchemaChangesInvalidateStoredSnapshot;
begin
  AssertIdentityChangeInvalidates('SnapshotSourceInvalidationUnit',
    CreateIdentity('SnapshotSourceInvalidationUnit', 'file-b', 'context-a', 'include-a',
    'snapshot-v1'));
  AssertIdentityChangeInvalidates('SnapshotContextInvalidationUnit',
    CreateIdentity('SnapshotContextInvalidationUnit', 'file-a', 'context-b', 'include-a',
    'snapshot-v1'));
  AssertIdentityChangeInvalidates('SnapshotIncludeInvalidationUnit',
    CreateIdentity('SnapshotIncludeInvalidationUnit', 'file-a', 'context-a', 'include-b',
    'snapshot-v1'));
  AssertIdentityChangeInvalidates('SnapshotSchemaInvalidationUnit',
    CreateIdentity('SnapshotSchemaInvalidationUnit', 'file-a', 'context-a', 'include-a',
    'snapshot-v2'));
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
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
    'snapshot-sqlite-temp', aName]));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
end;

initialization
  TDUnitX.RegisterTestFixture(TSnapshotSqliteTests);

end.
