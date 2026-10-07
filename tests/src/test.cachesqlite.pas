unit Test.CacheSqlite;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Cache,
  DelphiSemantics.Cache.Sqlite,
  DelphiSemantics.Model;

type
  [TestFixture]
  TCacheSqliteTests = class
  private
    function HasCacheDiagnostic(const aCache: TDelphiSemanticSqliteUnitCache;
      const aCode: string): Boolean;
    function HasDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string):
      Boolean;
    procedure AssertReuseModelFacts(const aModel: TDelphiSemanticUnitModel);
    procedure AssertUnitCacheRetention(const aCacheFileName: string);
    procedure CorruptStoredModelJson(const aFileName: string);
    procedure AwaitUnitCacheConcurrencyStart;
    procedure AwaitUnitCacheConcurrencyRelease(const aReleaseFileName: string);
    procedure HoldUnitCacheConcurrencyWriteLock(const aCacheFileName, aReadyFileName,
      aReleaseFileName: string; const aColdDatabase: Boolean);
    procedure OpenContendedUnitCache(const aCacheFileName: string);
    procedure ReadContendedInvalidUnit(const aCacheFileName, aSourceFileName,
      aExpectedTypeName: string);
    procedure RunLocalUnitCacheConcurrencyScenario(const aCacheFileName: string);
    procedure RunUnitCacheConcurrencySourceRole(const aRole, aCacheFileName,
      aSourceFileName: string);
    procedure SetStoredTimestampForConfiguration(const aCacheFileName, aConfiguration,
      aStoredAtUtc: string);
    procedure StoreConcurrencyUnit(const aCacheFileName, aSourceFileName: string;
      const aExpectedTypeName: string; const aExpectInvalidation,
      aExpectContention: Boolean);
    procedure StoreRetentionVariant(const aCacheOptions: TDelphiSemanticCacheOptions;
      const aModelOptions: TDelphiSemanticModelOptions; const aUnitName, aTypeName: string);
    procedure VerifyConcurrencyCache(const aCacheFileName: string;
      const aExpectedSourceFileNames: TArray<string>; const aExpectHolderSentinel,
      aExpectColdHolderSentinel: Boolean);
    procedure VerifyConcurrencyUnitHit(const aCacheFileName, aSourceFileName,
      aExpectedTypeName: string);
    procedure WriteIncompatibleSchema(const aFileName: string);
    function BoundaryDirectory(const aTargetLength: Integer): string;
    function RecordBoundaryObservation(const aPhase, aRawFileName,
      aResolvedFileName: string; const aCache: TDelphiSemanticSqliteUnitCache): string;
    function TempPath(const aName: string): string;
    function WriteUnitFile(const aName, aTypeName: string): string;
  public
    [Test]
    procedure NonEmptySqliteFileNameCreatesPersistentCacheFile;
    [Test]
    procedure DeepSqliteFileNamePersistsAndReusesAcrossInstances;

    [Test]
    procedure RelativeSqliteFileNamePersistsBeyondMaxPath;

    [Test]
    procedure NearMaxPathSqliteFileNamePersistsWithSidecars;

    [Test]
    procedure SqliteMemoryNameStaysSpecialUnderDeepCurrentDirectory;
    [Test]
    procedure DeepSqliteIncompatibleSchemaRebuildsPhysicalFile;
    [Test]
    procedure SqliteMetricsExposeCacheFileName;
    [Test]
    procedure UnavailableSqlitePathFallsBackToInMemoryWithoutDeletion;
    [Test]
    procedure PostInitializationSqliteOpenFailureDisablesPersistence;
    [Test]
    procedure SqliteCacheKeepsOnePersistentConnectionPerInstance;
    [Test]
    procedure SecondCacheInstanceReusesStoredUnitModel;
    [Test]
    procedure SecondCacheInstancePreservesReferenceRoutineName;
    [Test]
    procedure SecondCacheInstancePreservesSourceText;
    [Test]
    procedure SecondCacheInstancePreservesUnicodeSourceText;
    [Test]
    procedure SqliteUnitCacheUsesWideTextAccessors;
    [Test]
    procedure SqliteConnectionsDeclareBusyJournalAndLockingPolicy;
    [Test]
    procedure SqliteLockedErrorsUseNonDestructiveClassifier;
    [Test]
    procedure RebuildFailureDisablesPersistenceWithoutRetry;
    [Test]
    procedure SourceChangeInvalidatesPersistentEntry;
    [Test]
    procedure SourceTimestampChangeReusesPersistentEntry;
    [Test]
    procedure ApiBuildUnitIndexUsesSqliteCacheWhenFileNameConfigured;
    [Test]
    procedure EquivalentDefineOrderReusesStoredUnitModel;
    [Test]
    procedure CompilerProfileChangeInvalidatesPersistentEntry;
    [Test]
    procedure StoredRowsPersistSourcePathFromCacheIdentity;
    [Test]
    procedure StoreAndRetentionUseRetryingTransaction;
    [Test]
    procedure StoredRowsKeepSharedCompilerContextKeys;
    [Test]
    procedure StoresRetainFourNewestKeysPerSourceIdentity;
    [Test]
    procedure RtlSourceRootProfilesReuseSharedSqliteCache;
    [Test]
    procedure CorruptCacheFileRebuildsWithDiagnostic;
    [Test]
    procedure CorruptStoredEntryRebuildsWithDiagnostic;
    [Test]
    procedure IncompatibleSchemaRebuildsWithDiagnostic;
    [Test]
    procedure UnitModelJsonSerializationIsOutsideSqlitePersistence;
    [Test]
    procedure UnitCacheSqliteConcurrencyHarness;
  end;

implementation

uses
  System.Diagnostics, System.IOUtils, System.StrUtils, System.SysUtils, System.Variants,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def,
  FireDAC.Stan.Error,
  DelphiSemantics.Api, DelphiSemantics.Api.WithBinding, DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model.Json,
  maxLogic.IOUtils, Test.Support;

type
  TTestableDelphiSemanticSqliteUnitCache = class(TDelphiSemanticSqliteUnitCache)
  public
    class function IsSqliteBusyError(const aException: Exception): Boolean; static;
  end;

var
  GCacheSqliteTempRoot: string;

class function TTestableDelphiSemanticSqliteUnitCache.IsSqliteBusyError(
  const aException: Exception): Boolean;
begin
  Result := SqliteBusyError(aException);
end;

function CacheSqliteUnicodeText: string;
begin
  Result := 'Za' + #$017C + #$00F3 + #$0142 + #$0107 + '-' + #$6F22 + #$5B57;
end;

function CacheSqliteTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GCacheSqliteTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}', '',
      [rfReplaceAll]);
    GCacheSqliteTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'cache-sqlite-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GCacheSqliteTempRoot);
  Result := GCacheSqliteTempRoot;
end;

function TCacheSqliteTests.HasCacheDiagnostic(const aCache: TDelphiSemanticSqliteUnitCache;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticCacheDiagnostic;
begin
  for lDiagnostic in aCache.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function TCacheSqliteTests.HasDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName: string): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) then
      Exit(True);

  Result := False;
end;

procedure TCacheSqliteTests.AssertUnitCacheRetention(const aCacheFileName: string);
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

    Assert.AreEqual(8, Integer(lConnection.ExecSQLScalar(
      'select count(*) from unit_models')),
      'Two source identities must independently retain four persistent keys.');
    Assert.AreEqual(0, Integer(lConnection.ExecSQLScalar(
      'select count(*) from unit_models where configuration in (''Config1'', ''Config2'')')),
      'Retention must prune the oldest insertions despite misleading wall-clock values.');
    Assert.AreEqual(8, Integer(lConnection.ExecSQLScalar(
      'select count(*) from unit_models where configuration in ' +
      '(''Config3'', ''Config4'', ''Config5'', ''Config6'')')),
      'Retention must preserve four newest keys for each identity.');

    lQuery := TFDQuery.Create(nil);
    try
      lQuery.Connection := lConnection;
      lQuery.SQL.Text := 'select count(*) from unit_models where source_file_name = ?';
      lQuery.Params[0].AsWideString :=
        TDelphiSemanticCacheIdentityBuilder.CanonicalPath(TempPath('SqliteRetentionUnitA.pas'));
      lQuery.Open;
      Assert.AreEqual(4, lQuery.Fields[0].AsInteger,
        'The first source identity must retain four keys.');
      lQuery.Close;
      lQuery.Params[0].AsWideString :=
        TDelphiSemanticCacheIdentityBuilder.CanonicalPath(TempPath('SqliteRetentionUnitB.pas'));
      lQuery.Open;
      Assert.AreEqual(4, lQuery.Fields[0].AsInteger,
        'The second source identity must retain four keys.');
    finally
      lQuery.Free;
    end;
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure TCacheSqliteTests.CorruptStoredModelJson(const aFileName: string);
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aFileName;
    lConnection.Connected := True;
    lConnection.ExecSQL('update unit_models set model_json = ''{broken-json''');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

function TCacheSqliteTests.BoundaryDirectory(const aTargetLength: Integer): string;
var
  i: Integer;
  lBase: string;
  lCandidate: string;
  lGuid: TGUID;
  lPadding: Integer;
  lParent: string;
  lProbe: string;
begin
  CreateGUID(lGuid);
  lCandidate := GetCurrentDir;
  lBase := '';
  while lCandidate <> '' do
  begin
    for i := 0 to 1 do
    begin
      lProbe := lCandidate;
      if i = 1 then
        lProbe := CombinePath([lCandidate, 'DelphiSemantics']);
      if TFile.Exists(CombinePath([lProbe, 'tests', 'delphiSemanticsSqliteTests.dproj'])) and
        TFile.Exists(CombinePath([lProbe, 'src', 'DelphiSemantics.Cache.Sqlite.pas'])) then
      begin
        lBase := CombinePath([lProbe, 'tests', '.dak', 'delphiSemanticsSqliteTests',
          'ds673-boundaries-r1']);
        Break;
      end;
    end;
    if lBase <> '' then
      Break;
    lParent := TPath.GetDirectoryName(lCandidate);
    if SameText(lParent, lCandidate) then
      Break;
    lCandidate := lParent;
  end;
  if lBase = '' then
    raise Exception.Create('DS-673 boundary tests could not locate DelphiSemantics.');
  lBase := TPath.GetFullPath(CombinePath([lBase,
    'run-' + GetCurrentProcessId.ToString + '-' + GUIDToString(lGuid)]));
  lPadding := aTargetLength - Length(lBase) - 1;
  if (lPadding < 1) or (lPadding > 200) then
    raise Exception.CreateFmt('Invalid DS-673 boundary directory padding: %d', [lPadding]);
  Result := CombinePath([lBase, StringOfChar('d', lPadding)]);
  TDirectory.CreateDirectory(Result);
  Assert.AreEqual(aTargetLength, Length(Result));
end;

function TCacheSqliteTests.RecordBoundaryObservation(const aPhase, aRawFileName,
  aResolvedFileName: string; const aCache: TDelphiSemanticSqliteUnitCache): string;
var
  lDiagnostic: TDelphiSemanticCacheDiagnostic;
  lPhysicalFileName: string;
  lReceiptFileName: string;
begin
  lPhysicalFileName := '\\?\' + aResolvedFileName;
  lReceiptFileName := CombinePath([TPath.GetDirectoryName(
    TPath.GetDirectoryName(aResolvedFileName)), aPhase + '.txt']);
  Result := 'phase=' + aPhase + sLineBreak +
    'raw=' + aRawFileName + sLineBreak +
    'raw-length=' + IntToStr(Length(aRawFileName)) + sLineBreak +
    'cwd=' + GetCurrentDir + sLineBreak +
    'cwd-length=' + IntToStr(Length(GetCurrentDir)) + sLineBreak +
    'resolved=' + aResolvedFileName + sLineBreak +
    'resolved-length=' + IntToStr(Length(aResolvedFileName)) + sLineBreak +
    'physical=' + lPhysicalFileName + sLineBreak +
    'database-exists=' + BoolToStr(TFile.Exists(lPhysicalFileName), True) + sLineBreak +
    'wal-exists=' + BoolToStr(TFile.Exists(lPhysicalFileName + '-wal'), True) + sLineBreak +
    'shm-exists=' + BoolToStr(TFile.Exists(lPhysicalFileName + '-shm'), True) + sLineBreak +
    'journal-exists=' + BoolToStr(TFile.Exists(lPhysicalFileName + '-journal'), True) +
      sLineBreak +
    'cache-kind=' + aCache.Metrics.CacheKind + sLineBreak +
    'cache-file-name=' + aCache.Metrics.CacheFileName + sLineBreak +
    'cache-hits=' + IntToStr(aCache.Metrics.CacheHits) + sLineBreak +
    'cache-misses=' + IntToStr(aCache.Metrics.CacheMisses) + sLineBreak +
    'diagnostic-count=' + IntToStr(Length(aCache.Diagnostics)) + sLineBreak;
  for lDiagnostic in aCache.Diagnostics do
    Result := Result + 'diagnostic=' + lDiagnostic.Code + ' | ' +
      lDiagnostic.Message + ' | ' + lDiagnostic.FileName + sLineBreak;
  TFile.WriteAllText(lReceiptFileName, Result, TEncoding.UTF8);
end;

function TCacheSqliteTests.TempPath(const aName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([CacheSqliteTempRoot, aName]));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
end;

procedure TCacheSqliteTests.WriteIncompatibleSchema(const aFileName: string);
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
begin
  TDirectory.CreateDirectory(TPath.GetDirectoryName(aFileName));
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aFileName;
    lConnection.Connected := True;
    lConnection.ExecSQL('create table if not exists meta (' +
      'key_name text primary key not null, value_text text not null)');
    lConnection.ExecSQL('delete from meta');
    lConnection.ExecSQL('insert into meta(key_name, value_text) values (''schema_version'', ''999'')');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure TCacheSqliteTests.SetStoredTimestampForConfiguration(const aCacheFileName,
  aConfiguration, aStoredAtUtc: string);
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
      lQuery.SQL.Text := 'update unit_models set stored_at_utc = ? where configuration = ?';
      lQuery.Params[0].AsWideString := aStoredAtUtc;
      lQuery.Params[1].AsWideString := aConfiguration;
      lQuery.ExecSQL;
    finally
      lQuery.Free;
    end;
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure TCacheSqliteTests.StoreRetentionVariant(
  const aCacheOptions: TDelphiSemanticCacheOptions;
  const aModelOptions: TDelphiSemanticModelOptions; const aUnitName, aTypeName: string);
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lModelOptions := aModelOptions;
  lModelOptions.SourceFileName := WriteUnitFile(aUnitName, aTypeName);
  lCache := TDelphiSemanticSqliteUnitCache.Create(aCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, aTypeName));
  finally
    lCache.Free;
  end;
end;

function TCacheSqliteTests.WriteUnitFile(const aName, aTypeName: string): string;
begin
  Result := TempPath(aName + '.pas');
  TFile.WriteAllText(Result, 'unit ' + aName + ';' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  ' + aTypeName + ' = class end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
end;

procedure TCacheSqliteTests.NonEmptySqliteFileNameCreatesPersistentCacheFile;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('create-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteCreateUnit', 'TSqliteCreateType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind);
    Assert.IsTrue(TFile.Exists(lCacheOptions.SqliteCacheFileName));
    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteCreateType'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.DeepSqliteFileNamePersistsAndReusesAcrossInstances;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCacheRoot: string;
  lGuid: TGUID;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPhysicalFileName: string;
begin
  CreateGUID(lGuid);
  lCacheRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '.dak', 'delphiSemanticsSqliteTests', 'ds-672-long-paths',
    'run-' + GetCurrentProcessId.ToString + '-' + GUIDToString(lGuid)]));
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TPath.GetFullPath(CombinePath([lCacheRoot,
    StringOfChar('a', 110), StringOfChar('b', 110), 'symbol-map', 'v2',
    'semantic-unit-cache.sqlite3']));
  Assert.IsTrue(Length(lCacheOptions.SqliteCacheFileName) > 300,
    'The semantic-unit database path must exceed 300 characters.');
  lPhysicalFileName := '\\?\' + lCacheOptions.SqliteCacheFileName;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteDeepCacheUnit',
    'TSqliteDeepCacheType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteDeepCacheType'));
    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind);
    Assert.AreEqual(lCacheOptions.SqliteCacheFileName, lCache.Metrics.CacheFileName);
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_UNAVAILABLE'));
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
  Assert.IsTrue(TFile.Exists(lPhysicalFileName),
    'A memory fallback cannot substitute for the deep SQLite database.');

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteDeepCacheType'));
    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind);
    Assert.AreEqual(lCacheOptions.SqliteCacheFileName, lCache.Metrics.CacheFileName);
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_UNAVAILABLE'));
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.RelativeSqliteFileNamePersistsBeyondMaxPath;
const
  cDatabaseName = 'semantic-unit-cache.sqlite3';
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lDirectory: string;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lObservation: string;
  lOriginalDirectory: string;
  lResolvedFileName: string;
begin
  lDirectory := BoundaryDirectory(MAX_PATH - 15);
  lResolvedFileName := TPath.GetFullPath(CombinePath([lDirectory, cDatabaseName]));
  Writeln(Format('DS-673 relative SQLite raw=%s raw-length=%d cwd=%s cwd-length=%d ' +
    'resolved=%s resolved-length=%d', [cDatabaseName, Length(cDatabaseName), lDirectory,
    Length(lDirectory), lResolvedFileName, Length(lResolvedFileName)]));
  Assert.IsTrue(Length(cDatabaseName) < MAX_PATH);
  Assert.IsTrue(Length(lDirectory) < MAX_PATH);
  Assert.IsTrue(Length(lResolvedFileName) > MAX_PATH);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := cDatabaseName;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteRelativeBoundaryUnit',
    'TSqliteRelativeBoundaryType');
  lModelOptions.ProjectContextApplied := True;

  lOriginalDirectory := GetCurrentDir;
  Assert.IsTrue(SetCurrentDir(lDirectory), 'The disposable test process must enter its deep CWD.');
  try
    Assert.AreEqual(lResolvedFileName, TPath.GetFullPath(cDatabaseName));
    lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    try
      lModel := lCache.GetOrExtractUnitModel(lModelOptions);
      lObservation := RecordBoundaryObservation('initial', cDatabaseName,
        lResolvedFileName, lCache);
      Assert.IsTrue(HasDeclaration(lModel, 'TSqliteRelativeBoundaryType'));
      Assert.AreEqual('sqlite', lCache.Metrics.CacheKind, lObservation);
      Assert.AreEqual(cDatabaseName, lCache.Metrics.CacheFileName);
      Assert.AreEqual(1, lCache.Metrics.CacheMisses);
      Assert.AreEqual(0, lCache.Metrics.CacheHits);
    finally
      lCache.Free;
    end;
    Assert.IsTrue(TFile.Exists('\\?\' + lResolvedFileName),
      'The resolved physical SQLite database must exist after the first cache closes.');

    lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    try
      lModel := lCache.GetOrExtractUnitModel(lModelOptions);
      lObservation := RecordBoundaryObservation('reopen', cDatabaseName,
        lResolvedFileName, lCache);
      Assert.IsTrue(HasDeclaration(lModel, 'TSqliteRelativeBoundaryType'));
      Assert.AreEqual('sqlite', lCache.Metrics.CacheKind, lObservation);
      Assert.AreEqual(cDatabaseName, lCache.Metrics.CacheFileName);
      Assert.AreEqual(1, lCache.Metrics.CacheHits);
      Assert.AreEqual(0, lCache.Metrics.CacheMisses);
    finally
      lCache.Free;
    end;
  finally
    if not SetCurrentDir(lOriginalDirectory) then
      raise Exception.Create('DS-673 test could not restore the original process directory.');
  end;
end;

procedure TCacheSqliteTests.NearMaxPathSqliteFileNamePersistsWithSidecars;
const
  cDatabaseName = 'semantic-unit-cache.sqlite3';
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lDatabaseFileName: string;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lObservation: string;
  lPhysicalFileName: string;
begin
  lDatabaseFileName := CombinePath([
    BoundaryDirectory(MAX_PATH - 2 - Length(cDatabaseName) - 1), cDatabaseName]);
  lPhysicalFileName := '\\?\' + lDatabaseFileName;
  Writeln(Format('DS-673 near-limit SQLite db=%s db-length=%d wal=%d shm=%d journal=%d',
    [lDatabaseFileName, Length(lDatabaseFileName), Length(lDatabaseFileName + '-wal'),
    Length(lDatabaseFileName + '-shm'), Length(lDatabaseFileName + '-journal')]));
  Assert.AreEqual(MAX_PATH - 2, Length(lDatabaseFileName));
  Assert.IsTrue(Length(lDatabaseFileName + '-wal') >= MAX_PATH);
  Assert.IsTrue(Length(lDatabaseFileName + '-shm') >= MAX_PATH);
  Assert.IsTrue(Length(lDatabaseFileName + '-journal') >= MAX_PATH);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := lDatabaseFileName;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteNearBoundaryUnit',
    'TSqliteNearBoundaryType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    lObservation := RecordBoundaryObservation('initial', lDatabaseFileName,
      lDatabaseFileName, lCache);
    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteNearBoundaryType'));
    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind, lObservation);
    Assert.AreEqual(lDatabaseFileName, lCache.Metrics.CacheFileName);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.IsTrue(TFile.Exists(lPhysicalFileName), 'The physical SQLite database must exist.');
    Assert.IsTrue(TFile.Exists(lPhysicalFileName + '-wal'),
      'The live cache connection must create its WAL sidecar past MAX_PATH.');
    Assert.IsTrue(TFile.Exists(lPhysicalFileName + '-shm'),
      'The live cache connection must create its SHM sidecar past MAX_PATH.');
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    lObservation := RecordBoundaryObservation('reopen', lDatabaseFileName,
      lDatabaseFileName, lCache);
    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteNearBoundaryType'));
    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind, lObservation);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SqliteMemoryNameStaysSpecialUnderDeepCurrentDirectory;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lDirectory: string;
  lOriginalDirectory: string;
begin
  lDirectory := BoundaryDirectory(MAX_PATH - 15);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := ':memory:';
  lOriginalDirectory := GetCurrentDir;
  Assert.IsTrue(SetCurrentDir(lDirectory), 'The disposable test process must enter its deep CWD.');
  try
    lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    try
      Assert.AreEqual('sqlite', lCache.Metrics.CacheKind);
      Assert.AreEqual(':memory:', lCache.Metrics.CacheFileName);
      Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_UNAVAILABLE'));
    finally
      lCache.Free;
    end;
  finally
    if not SetCurrentDir(lOriginalDirectory) then
      raise Exception.Create('DS-673 test could not restore the original process directory.');
  end;
end;

procedure TCacheSqliteTests.DeepSqliteIncompatibleSchemaRebuildsPhysicalFile;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCacheRoot: string;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lGuid: TGUID;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPhysicalFileName: string;
begin
  CreateGUID(lGuid);
  lCacheRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '.dak', 'delphiSemanticsSqliteTests', 'ds-672-long-paths',
    'rebuild-' + GetCurrentProcessId.ToString + '-' + GUIDToString(lGuid)]));
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TPath.GetFullPath(CombinePath([lCacheRoot,
    StringOfChar('a', 110), StringOfChar('b', 110), 'symbol-map', 'v2',
    'semantic-unit-cache.sqlite3']));
  Assert.IsTrue(Length(lCacheOptions.SqliteCacheFileName) > 300);
  lPhysicalFileName := '\\?\' + lCacheOptions.SqliteCacheFileName;
  WriteIncompatibleSchema(lPhysicalFileName);
  Assert.IsTrue(TFile.Exists(lPhysicalFileName));

  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := lPhysicalFileName;
    lConnection.Connected := True;
    lConnection.ExecSQL('create table legacy_sentinel (id integer)');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;

  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteDeepRebuildUnit',
    'TSqliteDeepRebuildType');
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteDeepRebuildType'));
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_SCHEMA_REBUILT'));
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_UNAVAILABLE'));
    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind);
    Assert.AreEqual(lCacheOptions.SqliteCacheFileName, lCache.Metrics.CacheFileName);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
  Assert.IsTrue(TFile.Exists(lPhysicalFileName));

  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := lPhysicalFileName;
    lConnection.Connected := True;
    Assert.AreEqual(0, Integer(lConnection.ExecSQLScalar(
      'select count(*) from sqlite_master where type = ''table'' and name = ''legacy_sentinel''')),
      'Rebuilding the schema must delete the old physical database file.');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteDeepRebuildType'));
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_UNAVAILABLE'));
    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind);
    Assert.AreEqual(lCacheOptions.SqliteCacheFileName, lCache.Metrics.CacheFileName);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SqliteMetricsExposeCacheFileName;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('metrics-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    Assert.AreEqual(lCacheOptions.SqliteCacheFileName, lCache.Metrics.CacheFileName);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.UnavailableSqlitePathFallsBackToInMemoryWithoutDeletion;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('unavailable-cache.sqlite3');
  TDirectory.CreateDirectory(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteUnavailableUnit',
    'TSqliteUnavailableType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteUnavailableType'));
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_UNAVAILABLE'));
    Assert.AreEqual(1, Integer(Length(lCache.Diagnostics)),
      'In-memory fallback must not append an empty SQLite open failure per extracted unit.');
    Assert.AreEqual('in-memory-fallback', lCache.Metrics.CacheKind);
    Assert.IsTrue(TDirectory.Exists(lCacheOptions.SqliteCacheFileName),
      'An unavailable cache path must never be deleted during fallback.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.PostInitializationSqliteOpenFailureDisablesPersistence;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('post-init-open-failure.sqlite3');
  if TDirectory.Exists(lCacheOptions.SqliteCacheFileName) then
    TDirectory.Delete(lCacheOptions.SqliteCacheFileName, True);
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqlitePostInitFailureUnit',
    'TSqlitePostInitFailureType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    Assert.AreEqual('sqlite', lCache.Metrics.CacheKind);
    Assert.IsTrue(TFile.Exists(lCacheOptions.SqliteCacheFileName));
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
    TDirectory.CreateDirectory(lCacheOptions.SqliteCacheFileName);

    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqlitePostInitFailureType'));
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_UNAVAILABLE'));
    Assert.AreEqual(1, Integer(Length(lCache.Diagnostics)),
      'A shared-open failure must transition once to in-memory fallback.');
    Assert.AreEqual('in-memory-fallback', lCache.Metrics.CacheKind);
    Assert.IsTrue(TDirectory.Exists(lCacheOptions.SqliteCacheFileName),
      'A post-initialization open failure must not delete the unavailable path.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.AwaitUnitCacheConcurrencyStart;
var
  lAttemptFileName: string;
  lProceedFileName: string;
  lReadyFileName: string;
  lStartFileName: string;
  lStopwatch: TStopwatch;
begin
  lReadyFileName := GetEnvironmentVariable(
    'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_READY');
  if lReadyFileName <> '' then
    TFile.WriteAllText(lReadyFileName, 'ready', TEncoding.UTF8);

  lStartFileName := GetEnvironmentVariable(
    'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_START');
  lStopwatch := TStopwatch.StartNew;
  while (lStartFileName <> '') and not TFile.Exists(lStartFileName) do
  begin
    if lStopwatch.ElapsedMilliseconds > 15000 then
      raise Exception.Create('Timed out waiting to start unit-cache concurrency access.');
    Sleep(25);
  end;

  lAttemptFileName := GetEnvironmentVariable(
    'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_ATTEMPT');
  if lAttemptFileName <> '' then
    TFile.WriteAllText(lAttemptFileName, 'attempt', TEncoding.UTF8);

  lProceedFileName := GetEnvironmentVariable(
    'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CHILD_PROCEED');
  lStopwatch := TStopwatch.StartNew;
  while (lProceedFileName <> '') and not TFile.Exists(lProceedFileName) do
  begin
    if lStopwatch.ElapsedMilliseconds > 15000 then
      raise Exception.Create('Timed out waiting to enter unit-cache concurrency access.');
    Sleep(25);
  end;
end;

procedure TCacheSqliteTests.AwaitUnitCacheConcurrencyRelease(
  const aReleaseFileName: string);
var
  lStopwatch: TStopwatch;
begin
  lStopwatch := TStopwatch.StartNew;
  while (aReleaseFileName <> '') and not TFile.Exists(aReleaseFileName) do
  begin
    if lStopwatch.ElapsedMilliseconds > 15000 then
      raise Exception.Create('Timed out waiting to release the unit-cache SQLite write lock.');
    Sleep(50);
  end;
end;

procedure TCacheSqliteTests.HoldUnitCacheConcurrencyWriteLock(const aCacheFileName,
  aReadyFileName, aReleaseFileName: string; const aColdDatabase: Boolean);
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
begin
  if not aColdDatabase then
  begin
    lCacheOptions := Default(TDelphiSemanticCacheOptions);
    lCacheOptions.SqliteCacheFileName := aCacheFileName;
    lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    try
      // Create the schema before holding the write lock used by the process-level proof.
    finally
      lCache.Free;
    end;
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
    lConnection.Params.Values['SharedCache'] := 'False';
    lConnection.Connected := True;
    lConnection.StartTransaction;
    try
      if aColdDatabase then
      begin
        lConnection.ExecSQL('create table unit_cache_concurrency_holder(' +
          'value_text text not null)');
        lConnection.ExecSQL('insert into unit_cache_concurrency_holder(value_text) ' +
          'values(''locked'')');
      end else
        lConnection.ExecSQL('insert or replace into meta(key_name, value_text) values(' +
          '''unit_cache_concurrency_holder'', ''locked'')');
      if aReadyFileName <> '' then
        TFile.WriteAllText(aReadyFileName, 'ready', TEncoding.UTF8);
      AwaitUnitCacheConcurrencyRelease(aReleaseFileName);
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

procedure TCacheSqliteTests.StoreConcurrencyUnit(const aCacheFileName,
  aSourceFileName: string; const aExpectedTypeName: string;
  const aExpectInvalidation, aExpectContention: Boolean);
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lStopwatch: TStopwatch;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := aCacheFileName;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := aSourceFileName;
  lModelOptions.ProjectContextApplied := True;

  lStopwatch := TStopwatch.StartNew;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(lModel.UnitName <> '', 'Expected concurrency unit model to be stored.');
    if aExpectedTypeName <> '' then
      Assert.IsTrue(HasDeclaration(lModel, aExpectedTypeName),
        'Expected concurrency declaration: ' + aExpectedTypeName);
    if aExpectInvalidation then
      Assert.AreEqual(1, lCache.Metrics.Invalidations,
        'The changed concurrency source must invalidate its prior key.');
    if aExpectContention then
      Assert.IsTrue(lStopwatch.ElapsedMilliseconds >= 250,
        'The writer must overlap the held SQLite lock instead of starting after release.');
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_REBUILT'),
      'Lock contention must never rebuild the unit-cache database.');
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_SCHEMA_REBUILT'),
      'Lock contention must never rebuild the unit-cache schema.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.OpenContendedUnitCache(const aCacheFileName: string);
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := aCacheFileName;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_BUSY'),
      'Exhausted lock contention must report in-memory fallback.');
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_REBUILT'),
      'Exhausted lock contention must never rebuild the unit cache.');
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_SCHEMA_REBUILT'),
      'Exhausted lock contention must never rebuild the unit-cache schema.');
    Assert.AreEqual('in-memory-fallback', lCache.Metrics.CacheKind);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.ReadContendedInvalidUnit(const aCacheFileName,
  aSourceFileName, aExpectedTypeName: string);
var
  lAccessResult: TDelphiSemanticUnitCacheAccessResult;
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := aCacheFileName;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := aSourceFileName;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lAccessResult := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
    Assert.IsFalse(lAccessResult.CacheHit,
      'An invalid persistent model must be extracted again after cleanup contention.');
    Assert.IsTrue(HasDeclaration(lAccessResult.Model, aExpectedTypeName),
      'In-memory fallback must still return the extracted semantic model.');
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_ENTRY_REBUILT'));
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_BUSY'));
    Assert.AreEqual('in-memory-fallback', lCache.Metrics.CacheKind);
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_REBUILT'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.RunUnitCacheConcurrencySourceRole(const aRole,
  aCacheFileName, aSourceFileName: string);
var
  lExpectContention: Boolean;
  lExpectInvalidation: Boolean;
  lExpectedTypeName: string;
begin
  AwaitUnitCacheConcurrencyStart;
  if SameText(aRole, 'timeout-open') then
  begin
    OpenContendedUnitCache(aCacheFileName);
    Exit;
  end;
  if Trim(aSourceFileName) = '' then
    raise Exception.Create('Missing unit-cache SQLite concurrency source.');

  lExpectedTypeName := GetEnvironmentVariable(
    'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECTED_TYPE');
  if SameText(aRole, 'invalid-reader') then
  begin
    ReadContendedInvalidUnit(aCacheFileName, aSourceFileName, lExpectedTypeName);
    Exit;
  end;
  if SameText(aRole, 'reader') then
  begin
    VerifyConcurrencyUnitHit(aCacheFileName, aSourceFileName, lExpectedTypeName);
    Exit;
  end;

  lExpectInvalidation := SameText(GetEnvironmentVariable(
    'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_INVALIDATION'), '1');
  lExpectContention := SameText(GetEnvironmentVariable(
    'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_CONTENTION'), '1');
  StoreConcurrencyUnit(aCacheFileName, aSourceFileName, lExpectedTypeName,
    lExpectInvalidation, lExpectContention);
end;

procedure TCacheSqliteTests.VerifyConcurrencyCache(const aCacheFileName: string;
  const aExpectedSourceFileNames: TArray<string>; const aExpectHolderSentinel,
  aExpectColdHolderSentinel: Boolean);
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lQuery: TFDQuery;
  lSourceFileName: string;
begin
  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := aCacheFileName;
    lConnection.Params.Values['BusyTimeout'] := '10000';
    lConnection.Connected := True;
    Assert.AreEqual('ok', VarToStr(lConnection.ExecSQLScalar('pragma integrity_check')),
      'Concurrent unit-cache access must preserve SQLite integrity.');
    if aExpectHolderSentinel then
      Assert.AreEqual('locked', VarToStr(lConnection.ExecSQLScalar(
        'select value_text from meta where key_name = ''unit_cache_concurrency_holder''')),
        'The committed holder sentinel must survive without cache deletion or rebuilding.');
    if aExpectColdHolderSentinel then
      Assert.AreEqual('locked', VarToStr(lConnection.ExecSQLScalar(
        'select value_text from unit_cache_concurrency_holder limit 1')),
        'The cold-database holder sentinel must survive without cache deletion or rebuilding.');

    lQuery := TFDQuery.Create(nil);
    try
      lQuery.Connection := lConnection;
      lQuery.SQL.Text := 'select count(*) from unit_models where source_file_name = ?';
      for lSourceFileName in aExpectedSourceFileNames do
      begin
        if Trim(lSourceFileName) = '' then
          Continue;
        lQuery.Params[0].AsWideString :=
          TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lSourceFileName);
        lQuery.Open;
        Assert.IsTrue(lQuery.Fields[0].AsInteger > 0,
          'Expected concurrent cache row for source: ' + lSourceFileName);
        Assert.IsTrue(lQuery.Fields[0].AsInteger <= 4,
          'Concurrent cache rows must obey the per-source retention bound.');
        lQuery.Close;
      end;
    finally
      lQuery.Free;
    end;
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure TCacheSqliteTests.VerifyConcurrencyUnitHit(const aCacheFileName,
  aSourceFileName, aExpectedTypeName: string);
var
  lAccessResult: TDelphiSemanticUnitCacheAccessResult;
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := aCacheFileName;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := aSourceFileName;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lAccessResult := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
    Assert.IsTrue(lAccessResult.CacheHit,
      'Expected unchanged concurrency source to load from the persistent cache.');
    if aExpectedTypeName <> '' then
      Assert.IsTrue(HasDeclaration(lAccessResult.Model, aExpectedTypeName),
        'Expected warm concurrency declaration: ' + aExpectedTypeName);
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_REBUILT'),
      'Concurrent reads must never rebuild the unit-cache database.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SqliteConnectionsDeclareBusyJournalAndLockingPolicy;
var
  lBody: string;
  lBusyIndex: Integer;
  lDiagnosticIndex: Integer;
  lExitIndex: Integer;
  lRebuildIndex: Integer;
  lSource: string;
  lStartIndex: Integer;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Cache.Sqlite.pas');

  Assert.IsTrue(ContainsText(lSource, 'BusyTimeout'),
    'Unit-cache SQLite connections must declare an explicit busy timeout.');
  Assert.IsTrue(ContainsText(lSource, 'JournalMode') and ContainsText(lSource, 'WAL'),
    'Unit-cache SQLite connections must use WAL for concurrent readers and writers.');
  Assert.IsTrue(ContainsText(lSource, 'LockingMode') and ContainsText(lSource, 'Normal'),
    'Unit-cache SQLite connections must use normal multi-process locking.');
  Assert.IsTrue(ContainsText(lSource, 'SqliteBusyError'),
    'Unit-cache SQLite failures must classify BUSY and LOCKED separately from corruption.');
  Assert.IsTrue(ContainsText(lSource, 'aException is EFDDBEngineException') and
    ContainsText(lSource, 'ekRecordLocked'),
    'FireDAC-native SQLite BUSY and LOCKED errors must use the typed lock classification.');
  Assert.IsTrue(ContainsText(lSource, 'database schema is locked'),
    'Generic SQLite schema-lock errors must remain a non-destructive contention fallback.');
  Assert.IsTrue(ContainsText(lSource, 'UnitCacheSqliteCorruptionError') and
    ContainsText(lSource, 'SQLITE_CACHE_UNAVAILABLE'),
    'Only positively classified corruption may rebuild; unknown failures must disable persistence.');
  Assert.IsTrue(ContainsText(lSource, 'SharedCache') and ContainsText(lSource, 'False'),
    'WAL unit-cache connections must opt out of FireDAC global shared-cache locking.');

  lStartIndex := Pos('procedure TDelphiSemanticSqliteUnitCache.EnsureDatabase;', lSource);
  lBody := Copy(lSource, lStartIndex, PosEx(
    'procedure TDelphiSemanticSqliteUnitCache.EnsureDatabaseOnce;', lSource,
    lStartIndex) - lStartIndex);
  Assert.IsTrue((lStartIndex > 0) and (lBody <> ''),
    'Expected the SQLite unit-cache database initialization methods.');
  lBusyIndex := Pos('if SqliteBusyError(E', lBody);
  lDiagnosticIndex := PosEx('SQLITE_CACHE_BUSY', lBody, lBusyIndex);
  lExitIndex := PosEx('Exit;', lBody, lDiagnosticIndex);
  lRebuildIndex := PosEx('RebuildDatabase(', lBody, lBusyIndex);
  Assert.IsTrue((lBusyIndex > 0) and (lDiagnosticIndex > lBusyIndex) and
    (lExitIndex > lDiagnosticIndex) and (lRebuildIndex > lExitIndex),
    'An exhausted BUSY or LOCKED failure must exit before the rebuild path.');
end;

procedure TCacheSqliteTests.SqliteLockedErrorsUseNonDestructiveClassifier;
var
  lDbException: EFDDBEngineException;
  lException: Exception;
begin
  lDbException := EFDDBEngineException.Create;
  try
    Assert.IsNotNull(lDbException.AppendError(1, 6, 'database table is locked', '',
      ekRecordLocked, -1, -1));
    Assert.IsTrue(TTestableDelphiSemanticSqliteUnitCache.IsSqliteBusyError(lDbException),
      'A typed FireDAC SQLITE_LOCKED error must take the non-destructive BUSY path.');
  finally
    lDbException.Free;
  end;

  lException := Exception.Create('database schema is locked: main');
  try
    Assert.IsTrue(TTestableDelphiSemanticSqliteUnitCache.IsSqliteBusyError(lException),
      'A generic SQLite schema-lock error must take the non-destructive BUSY path.');
  finally
    lException.Free;
  end;

  lException := Exception.Create('unclassified SQLite failure');
  try
    Assert.IsFalse(TTestableDelphiSemanticSqliteUnitCache.IsSqliteBusyError(lException),
      'Unknown SQLite failures must not be reclassified as lock contention.');
  finally
    lException.Free;
  end;
end;

procedure TCacheSqliteTests.RebuildFailureDisablesPersistenceWithoutRetry;
var
  lBody: string;
  lDiagnosticIndex: Integer;
  lSchemaIndex: Integer;
  lSource: string;
  lStartIndex: Integer;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Cache.Sqlite.pas');
  lStartIndex := Pos('procedure TDelphiSemanticSqliteUnitCache.RebuildDatabase', lSource);
  lBody := Copy(lSource, lStartIndex, PosEx(
    'procedure TDelphiSemanticSqliteUnitCache.RecordPersistentInvalidation', lSource,
    lStartIndex) - lStartIndex);

  Assert.IsTrue((lStartIndex > 0) and (lBody <> ''),
    'Expected the SQLite rebuild failure boundary.');
  Assert.IsTrue(ContainsText(lBody,
    'not System.SysUtils.DeleteFile(lPhysicalFileName)'),
    'Rebuild must detect a cache file that cannot be deleted.');
  Assert.IsTrue(ContainsText(lBody, 'except') and
    ContainsText(lBody, 'DisablePersistence'),
    'Delete, reopen, drop, and create failures must disable persistence without escaping.');
  lSchemaIndex := Pos('CreateUnitCacheSqliteSchema', lBody);
  lDiagnosticIndex := Pos('AddDiagnostic(aCode', lBody);
  Assert.IsTrue((lSchemaIndex > 0) and (lDiagnosticIndex > lSchemaIndex),
    'A rebuild diagnostic is valid only after the replacement schema succeeds.');
end;

procedure TCacheSqliteTests.SqliteCacheKeepsOnePersistentConnectionPerInstance;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFirstOptions: TDelphiSemanticModelOptions;
  lSecondOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('single-connection-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);

  lFirstOptions := Default(TDelphiSemanticModelOptions);
  lFirstOptions.SourceFileName := WriteUnitFile('CacheConnectionOneUnit', 'Integer');
  lSecondOptions := Default(TDelphiSemanticModelOptions);
  lSecondOptions.SourceFileName := WriteUnitFile('CacheConnectionTwoUnit', 'string');

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lFirstOptions);
    lCache.GetOrExtractUnitModel(lSecondOptions);

    Assert.AreEqual(1, lCache.Metrics.PersistentConnectionOpenCount,
      'One SQLite cache instance should reuse its persistent connection.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.AssertReuseModelFacts(const aModel: TDelphiSemanticUnitModel);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lForward: Boolean;
  lEnumCount: Integer;
begin
  Assert.IsTrue(aModel.Success);
  lForward := False;
  lEnumCount := 0;
  for lDeclaration in aModel.Declarations do
  begin
    if lDeclaration.Name = 'TPending' then
    begin
      lForward := True;
      Assert.AreEqual('forward', lDeclaration.DeclarationRole);
    end;
    if lDeclaration.Kind = 'enum-value' then
    begin
      Inc(lEnumCount);
      Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
      Assert.AreEqual('type', lDeclaration.ScopeKind);
      Assert.AreEqual('TMode', lDeclaration.OwnerName);
      Assert.IsFalse(lDeclaration.Mutable);
      Assert.AreEqual(lDeclaration.Name,
        Copy(aModel.SourceText, lDeclaration.Offset, Length(lDeclaration.Name)));
    end;
  end;
  Assert.IsTrue(lForward);
  Assert.AreEqual(2, lEnumCount);
  Assert.IsTrue(aModel.Declarations[0].ProcedureSignature.Known);
  Assert.AreEqual(1, Integer(Length(aModel.Members)));
  Assert.IsTrue(aModel.Members[0].ProcedureSignature.Known);
  Assert.AreEqual('stdcall', aModel.Members[0].ProcedureSignature.CallingConvention);
  Assert.IsTrue(aModel.DependencyFacts.Known);
  Assert.AreEqual('BetaUnit', aModel.DependencyFacts.InterfaceImports[0]);
  Assert.AreEqual('AlphaUnit', aModel.DependencyFacts.InterfaceImports[1]);
  Assert.AreEqual('LeafUnit', aModel.DependencyFacts.ImplementationImports[0]);
  Assert.IsTrue(aModel.DependencyFacts.HasInitialization);
  Assert.IsTrue(aModel.DependencyFacts.HasFinalization);
end;

procedure TCacheSqliteTests.SecondCacheInstanceReusesStoredUnitModel;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lFreshJson: string;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('reuse-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteReuseUnit', 'TSqliteReuseType');
  TFile.WriteAllText(lModelOptions.SourceFileName,
    'unit SqliteReuseUnit;' + sLineBreak + 'interface' + sLineBreak +
    'uses BetaUnit, AlphaUnit;' + sLineBreak + '{$SCOPEDENUMS ON}' + sLineBreak +
    'type' + sLineBreak +
    '  TSqliteReuseType = procedure(var aValue: TObject) of object; stdcall;' + sLineBreak +
    '  THandler = class' + sLineBreak + '  published' + sLineBreak +
    '    procedure Handle(var aValue: TObject); stdcall;' + sLineBreak + '  end;' + sLineBreak +
    '  IService = interface' + sLineBreak +
    '    [''{11111111-2222-3333-4444-555555555555}'']' + sLineBreak +
    '  end;' + sLineBreak +
    '  TMode = (first, second);' + sLineBreak +
    '  TPending = class;' + sLineBreak +
    'implementation' + sLineBreak + 'uses LeafUnit;' + sLineBreak +
    'initialization' + sLineBreak + 'finalization' + sLineBreak + 'end.', TEncoding.UTF8);
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    AssertReuseModelFacts(lModel);
    lFreshJson := ModelToJson(lModel);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteReuseType'));
    Assert.AreEqual(lFreshJson, ModelToJson(lModel), 'Persistent facts must equal fresh extraction');
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SecondCacheInstancePreservesReferenceRoutineName;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('reference-routine-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);

  lPath := TempPath('SqliteReferenceRoutineUnit.pas');
  TFile.WriteAllText(lPath, 'unit SqliteReferenceRoutineUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'var' + sLineBreak + '  GlobalValue: Integer;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure UseGlobal;' + sLineBreak + 'begin' +
    sLineBreak + '  GlobalValue := 1;' + sLineBreak + 'end;' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(Length(lModel.References) > 0);
    Assert.AreEqual('UseGlobal', lModel.References[0].RoutineName);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SecondCacheInstancePreservesSourceText;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSourceText: string;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('source-text-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);

  lPath := TempPath('SqliteSourceTextUnit.pas');
  lSourceText := 'unit SqliteSourceTextUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TSqliteSourceTextType = record' + sLineBreak +
    '    Name: string;' + sLineBreak + '  end;' + sLineBreak + 'implementation' +
    sLineBreak + 'end.';
  TFile.WriteAllText(lPath, lSourceText, TEncoding.ASCII);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(lSourceText, lModel.SourceText);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SecondCacheInstancePreservesUnicodeSourceText;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lEncoding: TEncoding;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSourceText: string;
  lUnicodeText: string;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('unicode-source-text-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);

  lUnicodeText := CacheSqliteUnicodeText;
  lPath := TempPath('SqliteUnicodeSourceTextUnit-' + lUnicodeText + '.pas');
  lSourceText := 'unit SqliteUnicodeSourceTextUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TSqliteUnicodeSourceTextType = record' + sLineBreak +
    '    Name: string;' + sLineBreak + '  end;' + sLineBreak + 'implementation' +
    sLineBreak + '// ' + lUnicodeText + sLineBreak +
    'const LocalText = ''' + lUnicodeText + ''';' + sLineBreak + 'end.';
  lEncoding := TUTF8Encoding.Create(False);
  try
    TFile.WriteAllText(lPath, lSourceText, lEncoding);
  finally
    lEncoding.Free;
  end;
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(lSourceText, lModel.SourceText);
    Assert.AreEqual(lPath, lModel.FileName);
    Assert.IsTrue(ContainsText(lModel.SourceText, lUnicodeText));
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SqliteUnitCacheUsesWideTextAccessors;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.Cache.Sqlite.pas']));

  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lSourceText, 'VarToStr(lConnection.ExecSQLScalar'),
    'SQLite cache text reads should use wide field accessors, not scalar variant string conversion.');
  Assert.IsFalse(ContainsText(lSourceText, 'ExecSQL(''insert or replace into unit_models'),
    'SQLite cache text writes should use prepared wide parameters.');
  Assert.IsTrue(ContainsText(lSourceText, '.AsWideString'),
    'SQLite cache text paths should use Unicode-safe FireDAC accessors.');
end;

procedure TCacheSqliteTests.SourceChangeInvalidatesPersistentEntry;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('source-change-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteSourceUnit', 'TFirstSqliteType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  lModelOptions.SourceFileName := WriteUnitFile('SqliteSourceUnit', 'TSecondSqliteType');
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSecondSqliteType'));
    Assert.IsFalse(HasDeclaration(lModel, 'TFirstSqliteType'));
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_STALE_ENTRY_REBUILT'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.SourceTimestampChangeReusesPersistentEntry;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lResult: TDelphiSemanticUnitCacheAccessResult;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('timestamp-change-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteTimestampUnit', 'TSqliteTimestampType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  TFile.SetLastWriteTimeUtc(lModelOptions.SourceFileName,
    TFile.GetLastWriteTimeUtc(lModelOptions.SourceFileName) + EncodeTime(0, 0, 5, 0));
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lResult := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);

    Assert.IsTrue(lResult.CacheHit);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
    Assert.IsFalse(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_STALE_ENTRY_REBUILT'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.ApiBuildUnitIndexUsesSqliteCacheWhenFileNameConfigured;
var
  lIndex: TDelphiSemanticUnitIndex;
  lOptions: TDelphiSemanticApiOptions;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.SourceFileName := WriteUnitFile('SqliteApiUnit', 'TSqliteApiType');
  lOptions.ProjectContextApplied := True;
  lOptions.Cache.SqliteCacheFileName := TempPath('api-cache.sqlite3');
  if TFile.Exists(lOptions.Cache.SqliteCacheFileName) then
    TFile.Delete(lOptions.Cache.SqliteCacheFileName);

  lIndex := TDelphiSemanticWithBindingApi.BuildUnitIndex(lOptions);

  Assert.IsTrue(lIndex.Success);
  Assert.AreEqual('sqlite', lIndex.CacheMetrics.CacheKind);
  Assert.AreEqual(lOptions.Cache.SqliteCacheFileName, lIndex.CacheMetrics.CacheFileName);
  Assert.IsTrue(TFile.Exists(lOptions.Cache.SqliteCacheFileName));
end;

procedure TCacheSqliteTests.EquivalentDefineOrderReusesStoredUnitModel;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('equivalent-context-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteEquivalentContextUnit',
    'TSqliteEquivalentContextType');
  lModelOptions.ProjectContextApplied := True;
  lModelOptions.Defines := ['PROFILE_A', 'PROFILE_B'];

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  lModelOptions.Defines := ['PROFILE_B', 'PROFILE_A'];
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteEquivalentContextType'));
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.CompilerProfileChangeInvalidatesPersistentEntry;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('compiler-profile-cache.sqlite3');
  lCacheOptions.CompilerProfileName := 'Delphi-12-Win32-Debug';
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteCompilerProfileUnit',
    'TSqliteCompilerProfileType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  lCacheOptions.CompilerProfileName := 'Delphi-12-Win64-Release';
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteCompilerProfileType'));
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_STALE_PROFILE_REBUILT'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.StoredRowsKeepSharedCompilerContextKeys;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lFileName: string;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('shared-context-keys-cache.sqlite3');
  lCacheOptions.DelphiVersion := '23.0';
  lCacheOptions.Configuration := 'Debug';
  lCacheOptions.Platform := 'Win32';
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteSharedContextUnit', 'TSqliteSharedContextType');
  lModelOptions.ProjectContextApplied := True;
  lFileName := TPath.GetFullPath(lModelOptions.SourceFileName);

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
  lConnection := TFDConnection.Create(nil);
  try
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := lCacheOptions.SqliteCacheFileName;
    lConnection.Connected := True;

    Assert.AreEqual(lFileName, VarToStr(lConnection.ExecSQLScalar(
      'select source_file_name from unit_models limit 1')), 'Expected source filename in SQLite cache row.');
    Assert.IsTrue(VarToStr(lConnection.ExecSQLScalar(
      'select file_hash from unit_models limit 1')) <> '', 'Expected source file hash in SQLite cache row.');
    Assert.AreEqual('23.0', VarToStr(lConnection.ExecSQLScalar(
      'select delphi_version from unit_models limit 1')), 'Expected Delphi version in SQLite cache row.');
    Assert.AreEqual('Debug', VarToStr(lConnection.ExecSQLScalar(
      'select configuration from unit_models limit 1')), 'Expected configuration in SQLite cache row.');
    Assert.AreEqual('Win32', VarToStr(lConnection.ExecSQLScalar(
      'select platform from unit_models limit 1')), 'Expected platform in SQLite cache row.');
  finally
    lConnection.Free;
    lDriverLink.Free;
  end;
end;

procedure TCacheSqliteTests.StoredRowsPersistSourcePathFromCacheIdentity;
var
  lBody: string;
  lEndIndex: Integer;
  lSource: string;
  lStartIndex: Integer;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Cache.Sqlite.pas');
  lStartIndex := Pos('procedure TDelphiSemanticSqliteUnitCache.StorePersistentEntry',
    lSource);
  Assert.IsTrue(lStartIndex > 0, 'Expected SQLite unit persistence helper.');
  lEndIndex := PosEx('function TDelphiSemanticSqliteUnitCache.TryLoadPersistentEntry',
    lSource, lStartIndex);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected SQLite unit persistence helper before load helper.');
  lBody := Copy(lSource, lStartIndex, lEndIndex - lStartIndex);

  Assert.IsTrue(ContainsText(lBody, 'SetWideParam(lQuery, 2, aCacheIdentity.SourceFileName)'),
    'SQLite unit rows should persist the normalized source path from the unit identity record.');
  Assert.IsFalse(ContainsText(lBody, 'SetWideParam(lQuery, 2, aModel.FileName)'),
    'SQLite unit rows should not derive source_file_name from the serialized model.');
end;

procedure TCacheSqliteTests.StoreAndRetentionUseRetryingTransaction;
var
  lBody: string;
  lEndIndex: Integer;
  lSource: string;
  lStartIndex: Integer;
  lTransactionBody: string;
  lTransactionEndIndex: Integer;
  lTransactionStartIndex: Integer;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Cache.Sqlite.pas');
  lStartIndex := Pos('procedure TDelphiSemanticSqliteUnitCache.StorePersistentEntry', lSource);
  Assert.IsTrue(lStartIndex > 0, 'Expected SQLite unit persistence helper.');
  lEndIndex := PosEx('function TDelphiSemanticSqliteUnitCache.TryLoadPersistentEntry',
    lSource, lStartIndex);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected SQLite unit persistence helper before load helper.');
  lBody := Copy(lSource, lStartIndex, lEndIndex - lStartIndex);

  Assert.IsTrue(ContainsText(lBody, 'ExecuteUnitCacheStoreTransaction'),
    'Unit-model persistence must use the transactional retention helper.');
  lTransactionStartIndex := Pos('procedure ExecuteUnitCacheStoreTransaction', lSource);
  lTransactionEndIndex := PosEx('constructor TDelphiSemanticSqliteUnitCache.Create', lSource,
    lTransactionStartIndex);
  Assert.IsTrue((lTransactionStartIndex > 0) and
    (lTransactionEndIndex > lTransactionStartIndex),
    'Expected the unit-cache store transaction helper.');
  lTransactionBody := Copy(lSource, lTransactionStartIndex,
    lTransactionEndIndex - lTransactionStartIndex);

  Assert.IsTrue(ContainsText(lTransactionBody, 'aConnection.StartTransaction'),
    'The unit-model insert and retention prune must share one transaction.');
  Assert.IsTrue(ContainsText(lTransactionBody, 'aQuery.Prepare'),
    'Statement preparation must remain inside the BUSY or LOCKED retry boundary.');
  Assert.IsTrue(ContainsText(lTransactionBody, 'aConnection.Commit'),
    'A successful unit-model write must commit its insert and retention prune together.');
  Assert.IsTrue(ContainsText(lTransactionBody, 'aConnection.Rollback'),
    'A failed unit-model write must roll back before retrying.');
  Assert.IsTrue(ContainsText(lTransactionBody, 'SqliteBusyError') and
    (ContainsText(lTransactionBody, 'GetTickCount64') or
    ContainsText(lTransactionBody, 'ElapsedMilliseconds')),
    'Unit-model writes must retry bounded BUSY or LOCKED contention.');
  Assert.IsTrue(ContainsText(lTransactionBody, 'order by rowid desc'),
    'Retention must rank keys by monotonic insertion order.');
  Assert.IsFalse(ContainsText(lTransactionBody, 'order by stored_at_utc desc'),
    'Wall-clock text must not outrank insertion order during retention.');
end;

procedure TCacheSqliteTests.StoresRetainFourNewestKeysPerSourceIdentity;
var
  i: Integer;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('bounded-retention-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.ProjectContextApplied := True;

  for i := 1 to 6 do
  begin
    lModelOptions.SkipBodyAnalysis := (i mod 2) = 0;
    lModelOptions.SkipReferenceExtraction := (i mod 3) = 0;
    lCacheOptions.Configuration := 'Config' + i.ToString;
    StoreRetentionVariant(lCacheOptions, lModelOptions, 'SqliteRetentionUnitA',
      'TSqliteRetentionTypeA' + i.ToString);
    StoreRetentionVariant(lCacheOptions, lModelOptions, 'SqliteRetentionUnitB',
      'TSqliteRetentionTypeB' + i.ToString);
    if i = 4 then
      SetStoredTimestampForConfiguration(lCacheOptions.SqliteCacheFileName, 'Config1',
        '9999-12-31T23:59:59Z');
  end;
  AssertUnitCacheRetention(lCacheOptions.SqliteCacheFileName);
end;

procedure TCacheSqliteTests.RtlSourceRootProfilesReuseSharedSqliteCache;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCommonRoot: string;
  lProfile: TDelphiSemanticCompilerProfile;
  lRtlRoot: string;
begin
  lRtlRoot := TPath.GetFullPath(CombinePath([CacheSqliteTempRoot, 'fake-shared-rtl-source']));
  lCommonRoot := CombinePath([lRtlRoot, 'rtl', 'common']);
  TDirectory.CreateDirectory(lCommonRoot);
  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'System.SharedRtl.pas'),
    'unit System.SharedRtl;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TSharedRtlRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('shared-rtl-source-cache.sqlite3');
  lCacheOptions.CompilerProfileName := 'Delphi-12-Win32-Debug-RTL';
  lCacheOptions.DelphiVersion := '23.0';
  lCacheOptions.Configuration := 'Debug';
  lCacheOptions.Platform := 'Win32';
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceRoot(lCache,
      lCacheOptions.CompilerProfileName, '23.0', 'Win32', lRtlRoot, ['SharedRtl']);

    Assert.AreEqual(1, Integer(Length(lProfile.RtlSourceUnitModels)));
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceRoot(lCache,
      lCacheOptions.CompilerProfileName, '23.0', 'Win32', lRtlRoot, ['SharedRtl']);

    Assert.AreEqual(1, Integer(Length(lProfile.RtlSourceUnitModels)));
    Assert.IsTrue(HasDeclaration(lProfile.RtlSourceUnitModels[0], 'TSharedRtlRecord'));
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.CorruptCacheFileRebuildsWithDiagnostic;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('corrupt-cache.sqlite3');
  TFile.WriteAllText(lCacheOptions.SqliteCacheFileName, 'not a sqlite database', TEncoding.UTF8);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteCorruptUnit', 'TSqliteCorruptType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteCorruptType'));
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_REBUILT'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.CorruptStoredEntryRebuildsWithDiagnostic;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('corrupt-entry-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteCorruptEntryUnit',
    'TSqliteCorruptEntryType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;

  CorruptStoredModelJson(lCacheOptions.SqliteCacheFileName);
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteCorruptEntryType'));
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_ENTRY_REBUILT'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.IncompatibleSchemaRebuildsWithDiagnostic;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('schema-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  WriteIncompatibleSchema(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteSchemaUnit', 'TSqliteSchemaType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteSchemaType'));
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_SCHEMA_REBUILT'));
  finally
    lCache.Free;
  end;
end;

procedure TCacheSqliteTests.UnitModelJsonSerializationIsOutsideSqlitePersistence;
var
  lCacheSource: string;
  lJsonPath: string;
  lJsonSource: string;
begin
  lCacheSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
    '..', '..', 'src', 'DelphiSemantics.Cache.Sqlite.pas'])), TEncoding.UTF8);
  lJsonPath := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', '..',
    'src', 'DelphiSemantics.Model.Json.pas']));

  Assert.IsTrue(TFile.Exists(lJsonPath), 'Expected focused UnitModel JSON serialization unit.');
  lJsonSource := TFile.ReadAllText(lJsonPath, TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lCacheSource, 'DelphiSemantics.Model.Json'),
    'SQLite cache should call the model JSON serializer unit.');
  Assert.IsFalse(ContainsText(lCacheSource, 'System.JSON'),
    'SQLite cache persistence must not own JSON encoding details.');
  Assert.IsTrue(ContainsText(lJsonSource, 'ModelToJson'),
    'Model JSON unit should own UnitModel serialization.');
  Assert.IsTrue(ContainsText(lJsonSource, 'JsonToModel'),
    'Model JSON unit should own UnitModel deserialization.');
  Assert.IsFalse(ContainsText(lJsonSource, 'FireDAC'),
    'Model JSON serialization must not depend on SQLite persistence.');
end;

procedure TCacheSqliteTests.RunLocalUnitCacheConcurrencyScenario(
  const aCacheFileName: string);
var
  lSourceFileName: string;
begin
  if TFile.Exists(aCacheFileName) then
    TFile.Delete(aCacheFileName);
  lSourceFileName := WriteUnitFile('SqliteLocalConcurrencyUnit',
    'TSqliteLocalConcurrencyType');
  StoreConcurrencyUnit(aCacheFileName, lSourceFileName, 'TSqliteLocalConcurrencyType',
    False, False);
  VerifyConcurrencyUnitHit(aCacheFileName, lSourceFileName,
    'TSqliteLocalConcurrencyType');
  VerifyConcurrencyCache(aCacheFileName, [lSourceFileName], False, False);
end;

procedure TCacheSqliteTests.UnitCacheSqliteConcurrencyHarness;
var
  lCacheFileName: string;
  lRole: string;
begin
  lRole := GetEnvironmentVariable('DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_ROLE');
  lCacheFileName := GetEnvironmentVariable('DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_CACHE');
  if Trim(lCacheFileName) = '' then
    lCacheFileName := TempPath('unit-cache-concurrency-harness.sqlite3');

  if SameText(lRole, 'holder') or SameText(lRole, 'cold-holder') then
  begin
    HoldUnitCacheConcurrencyWriteLock(lCacheFileName, GetEnvironmentVariable(
      'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_READY'), GetEnvironmentVariable(
      'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_RELEASE'), SameText(lRole, 'cold-holder'));
    Assert.Pass('Held and released the unit-cache SQLite write lock.');
    Exit;
  end;

  if SameText(lRole, 'corrupt-entry') then
  begin
    CorruptStoredModelJson(lCacheFileName);
    Assert.Pass('Corrupted the stored unit-cache model JSON.');
    Exit;
  end;

  if SameText(lRole, 'writer') or SameText(lRole, 'seed') or
    SameText(lRole, 'reader') or SameText(lRole, 'invalid-reader') or
    SameText(lRole, 'timeout-open') then
  begin
    RunUnitCacheConcurrencySourceRole(lRole, lCacheFileName, GetEnvironmentVariable(
      'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_SOURCE'));
    Exit;
  end;

  if SameText(lRole, 'verify') then
  begin
    VerifyConcurrencyCache(lCacheFileName, SplitString(GetEnvironmentVariable(
      'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECTED_SOURCES'), ';'),
      SameText(GetEnvironmentVariable(
      'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_HOLDER_SENTINEL'), '1'),
      SameText(GetEnvironmentVariable(
      'DELPHI_SEMANTICS_UNIT_SQLITE_CONCURRENCY_EXPECT_COLD_HOLDER_SENTINEL'), '1'));
    Exit;
  end;

  RunLocalUnitCacheConcurrencyScenario(lCacheFileName);
end;

initialization
  TDUnitX.RegisterTestFixture(TCacheSqliteTests);

end.
