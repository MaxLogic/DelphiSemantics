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
    procedure CorruptStoredModelJson(const aFileName: string);
    procedure WriteIncompatibleSchema(const aFileName: string);
    function TempPath(const aName: string): string;
    function WriteUnitFile(const aName, aTypeName: string): string;
  public
    [Test]
    procedure NonEmptySqliteFileNameCreatesPersistentCacheFile;
    [Test]
    procedure SqliteMetricsExposeCacheFileName;
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
    procedure SourceChangeInvalidatesPersistentEntry;
    [Test]
    procedure SourceTimestampChangeInvalidatesPersistentEntry;
    [Test]
    procedure ApiBuildUnitIndexUsesSqliteCacheWhenFileNameConfigured;
    [Test]
    procedure EquivalentDefineOrderReusesStoredUnitModel;
    [Test]
    procedure CompilerProfileChangeInvalidatesPersistentEntry;
    [Test]
    procedure StoredRowsKeepSharedCompilerContextKeys;
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
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils, System.Variants,
  Winapi.Windows,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def,
  DelphiSemantics.Api, DelphiSemantics.Api.WithBinding, DelphiSemantics.CompilerProfile,
  maxLogic.IOUtils;

var
  GCacheSqliteTempRoot: string;

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

procedure TCacheSqliteTests.SecondCacheInstanceReusesStoredUnitModel;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('reuse-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := WriteUnitFile('SqliteReuseUnit', 'TSqliteReuseType');
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSqliteReuseType'));
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

procedure TCacheSqliteTests.SourceTimestampChangeInvalidatesPersistentEntry;
var
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
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
    lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
    Assert.IsTrue(HasCacheDiagnostic(lCache, 'SQLITE_CACHE_STALE_ENTRY_REBUILT'));
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

initialization
  TDUnitX.RegisterTestFixture(TCacheSqliteTests);

end.
