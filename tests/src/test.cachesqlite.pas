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
    procedure SecondCacheInstanceReusesStoredUnitModel;
    [Test]
    procedure SourceChangeInvalidatesPersistentEntry;
    [Test]
    procedure CorruptCacheFileRebuildsWithDiagnostic;
    [Test]
    procedure CorruptStoredEntryRebuildsWithDiagnostic;
    [Test]
    procedure IncompatibleSchemaRebuildsWithDiagnostic;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def,
  maxLogic.IOUtils;

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
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-sqlite-temp',
    aName]));
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

initialization
  TDUnitX.RegisterTestFixture(TCacheSqliteTests);

end.
