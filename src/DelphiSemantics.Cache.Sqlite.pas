unit DelphiSemantics.Cache.Sqlite;

interface

uses
  System.SysUtils,
  DelphiSemantics.Cache, DelphiSemantics.Model, DelphiSemantics.Model.Json;

type
  TDelphiSemanticSqliteUnitCache = class(TDelphiSemanticUnitCache)
  private
    fCacheFileName: string;
    fConnection: TObject;
    fDriverLink: TObject;
    fPersistenceAvailable: Boolean;
    procedure DiscardUnreadablePersistentEntry(const aConnection: TObject;
      const aKey, aMessage: string);
    function OpenConnection(out aConnection: TObject; out aDriverLink: TObject;
      out aError: string; out aBusy, aCorrupt: Boolean): Boolean;
    function SharedConnection(out aConnection: TObject; out aError: string): Boolean;
    procedure CloseSharedConnection;
    procedure DisablePersistence(const aCode, aMessage: string);
    procedure RebuildDatabase(const aCode, aMessage: string);
    procedure EnsureDatabase;
    procedure EnsureDatabaseOnce;
  protected
    class function SqliteBusyError(const aException: Exception): Boolean; static;
    function PersistentEntryExistsForIdentity(const aIdentity: string): Boolean; override;
    procedure RecordPersistentInvalidation(const aIdentity, aKey: string); override;
    procedure StorePersistentEntry(const aIdentity, aKey: string;
      const aCacheIdentity: TDelphiSemanticUnitCacheIdentity;
      const aModel: TDelphiSemanticUnitModel); override;
    function TryLoadPersistentEntry(const aIdentity, aKey: string;
      out aModel: TDelphiSemanticUnitModel): Boolean; override;
  public
    constructor Create(const aOptions: TDelphiSemanticCacheOptions);
    destructor Destroy; override;
  end;

implementation

uses
  System.Classes, System.DateUtils, System.IOUtils,
  Winapi.Windows,
  Data.DB,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def,
  FireDAC.Stan.Error;

type
  EUnitCacheSqliteBusy = class(Exception);
  EUnitCacheSqliteCorrupt = class(Exception);
  EUnitCacheSqliteSchemaMismatch = class(Exception);

const
  cPersistentKeysPerIdentity = 4;
  cSqliteSchemaVersion = '9';
  cUnitCacheSqliteBusyAttemptTimeoutMs = 250;
  cUnitCacheSqliteBusyRetryDelayMs = 50;
  cUnitCacheSqliteBusyTimeoutMs = 30000;
  cUnitCacheSqliteJournalMode = 'WAL';
  cUnitCacheSqliteLockingMode = 'Normal';
  cUnitCacheSqliteTestBusyTimeoutEnv =
    'DELPHI_SEMANTICS_TEST_UNIT_CACHE_BUSY_TIMEOUT_MS';

function PhysicalUnitCachePath(const aPath: string): string;
begin
  Result := aPath;
  if (Length(Result) < MAX_PATH) or TPath.IsExtendedPrefixed(Result) then
    Exit;
  Result := TPath.GetFullPath(Result);
  if Result.StartsWith('\\') then
    Result := '\\?\UNC\' + Copy(Result, 3, MaxInt)
  else
    Result := '\\?\' + Result;
end;

function UnitCacheSqliteBusyTimeoutMs: UInt64;
var
  lConfigured: Integer;
begin
  Result := cUnitCacheSqliteBusyTimeoutMs;
  if TryStrToInt(GetEnvironmentVariable(cUnitCacheSqliteTestBusyTimeoutEnv), lConfigured) and
    (lConfigured > 0) and (lConfigured <= cUnitCacheSqliteBusyTimeoutMs) then
    Result := UInt64(lConfigured);
end;

function UnitCacheSqliteBusyAttemptTimeoutMs: UInt64;
begin
  Result := UnitCacheSqliteBusyTimeoutMs;
  if Result > cUnitCacheSqliteBusyAttemptTimeoutMs then
    Result := cUnitCacheSqliteBusyAttemptTimeoutMs;
end;

procedure ConfigureUnitCacheSqliteConnection(const aConnection: TFDConnection;
  const aDatabase: string);
begin
  aConnection.LoginPrompt := False;
  aConnection.Params.Values['DriverID'] := 'SQLite';
  aConnection.Params.Values['Database'] := aDatabase;
  aConnection.Params.Values['BusyTimeout'] :=
    UIntToStr(UnitCacheSqliteBusyAttemptTimeoutMs);
  aConnection.Params.Values['JournalMode'] := cUnitCacheSqliteJournalMode;
  aConnection.Params.Values['LockingMode'] := cUnitCacheSqliteLockingMode;
  aConnection.Params.Values['SharedCache'] := 'False';
end;

class function TDelphiSemanticSqliteUnitCache.SqliteBusyError(
  const aException: Exception): Boolean;
var
  lMessage: string;
begin
  if (aException is EUnitCacheSqliteBusy) or
    ((aException is EFDDBEngineException) and
    (EFDDBEngineException(aException).Kind = ekRecordLocked)) then
    Exit(True);

  lMessage := LowerCase(aException.Message);
  Result := (Pos('database is locked', lMessage) > 0) or
    (Pos('database schema is locked', lMessage) > 0) or
    (Pos('database table is locked', lMessage) > 0) or
    (Pos('database is busy', lMessage) > 0) or
    (Pos('sqlite_busy', lMessage) > 0) or
    (Pos('sqlite_locked', lMessage) > 0);
end;

function UnitCacheSqliteCorruptionError(const aException: Exception): Boolean;
var
  lErrorCode: Integer;
  lMessage: string;
begin
  if aException is EUnitCacheSqliteCorrupt then
    Exit(True);
  if aException is EFDDBEngineException then
  begin
    lErrorCode := EFDDBEngineException(aException).ErrorCode and $FF;
    if (lErrorCode = 11) or (lErrorCode = 26) then
      Exit(True);
  end;

  lMessage := LowerCase(aException.Message);
  Result := (Pos('database disk image is malformed', lMessage) > 0) or
    (Pos('file is not a database', lMessage) > 0) or
    (Pos('database is malformed', lMessage) > 0);
end;

function NewQuery(const aConnection: TFDConnection; const aSql: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := aConnection;
  Result.SQL.Text := aSql;
end;

procedure SetWideParam(const aQuery: TFDQuery; const aIndex: Integer; const aValue: string;
  const aDataType: TFieldType = ftWideString);
begin
  if aQuery.Params[aIndex].DataType <> aDataType then
    aQuery.Params[aIndex].DataType := aDataType;
  aQuery.Params[aIndex].AsWideString := aValue;
end;

procedure ExecWideSql(const aConnection: TFDConnection; const aSql, aValue: string); overload;
var
  lQuery: TFDQuery;
begin
  lQuery := NewQuery(aConnection, aSql);
  try
    SetWideParam(lQuery, 0, aValue);
    lQuery.Prepare;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

procedure ExecWideSql(const aConnection: TFDConnection; const aSql, aFirstValue,
  aSecondValue: string); overload;
var
  lQuery: TFDQuery;
begin
  lQuery := NewQuery(aConnection, aSql);
  try
    SetWideParam(lQuery, 0, aFirstValue);
    SetWideParam(lQuery, 1, aSecondValue);
    lQuery.Prepare;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

function QueryInteger(const aConnection: TFDConnection; const aSql: string): Int64; overload;
var
  lQuery: TFDQuery;
begin
  Result := 0;
  lQuery := NewQuery(aConnection, aSql);
  try
    lQuery.Open;
    if not lQuery.Eof then
      Result := lQuery.Fields[0].AsLargeInt;
  finally
    lQuery.Free;
  end;
end;

function QueryInteger(const aConnection: TFDConnection; const aSql, aValue: string): Int64;
  overload;
var
  lQuery: TFDQuery;
begin
  Result := 0;
  lQuery := NewQuery(aConnection, aSql);
  try
    SetWideParam(lQuery, 0, aValue);
    lQuery.Open;
    if not lQuery.Eof then
      Result := lQuery.Fields[0].AsLargeInt;
  finally
    lQuery.Free;
  end;
end;

function QueryWideString(const aConnection: TFDConnection; const aSql: string): string; overload;
var
  lQuery: TFDQuery;
begin
  Result := '';
  lQuery := NewQuery(aConnection, aSql);
  try
    lQuery.Open;
    if not lQuery.Eof then
      Result := lQuery.Fields[0].AsWideString;
  finally
    lQuery.Free;
  end;
end;

function QueryWideString(const aConnection: TFDConnection; const aSql, aValue: string): string;
  overload;
var
  lQuery: TFDQuery;
begin
  Result := '';
  lQuery := NewQuery(aConnection, aSql);
  try
    SetWideParam(lQuery, 0, aValue);
    lQuery.Open;
    if not lQuery.Eof then
      Result := lQuery.Fields[0].AsWideString;
  finally
    lQuery.Free;
  end;
end;

procedure CreateUnitCacheSqliteSchema(const aConnection: TFDConnection);
begin
  aConnection.ExecSQL('create table if not exists meta (' +
    'key_name text primary key not null, value_text text not null)');
  aConnection.ExecSQL('create table if not exists unit_models (' +
    'cache_key text primary key not null, identity_key text not null, ' +
    'source_file_name text not null, file_hash text not null, delphi_version text not null, ' +
    'configuration text not null, platform text not null, compiler_profile_name text not null, ' +
    'schema_version text not null, parser_version text not null, model_version text not null, ' +
    'include_graph_hash text not null, context_hash text not null, defines_hash text not null, ' +
    'search_path_hash text not null, extraction_options_hash text not null, ' +
    'model_json text not null, stored_at_utc text not null)');
  aConnection.ExecSQL('create index if not exists idx_unit_models_identity on ' +
    'unit_models(identity_key)');
  ExecWideSql(aConnection, 'insert or replace into meta(key_name, value_text) values ' +
    '(?, ?)', 'schema_version', cSqliteSchemaVersion);
end;

function UnitCacheSqliteSchemaReady(const aConnection: TFDConnection;
  out aVersion: string): Boolean;
begin
  aVersion := '';
  if QueryInteger(aConnection, 'select count(*) from sqlite_master where type = ''table'' ' +
    'and name = ''meta''') = 0 then
    Exit(False);
  aVersion := QueryWideString(aConnection,
    'select value_text from meta where key_name = ''schema_version''');
  Result := (aVersion = cSqliteSchemaVersion) and
    (QueryInteger(aConnection, 'select count(*) from sqlite_master where type = ''table'' ' +
    'and name = ''unit_models''') = 1) and
    (QueryInteger(aConnection, 'select count(*) from sqlite_master where type = ''index'' ' +
    'and name = ''idx_unit_models_identity''') = 1);
end;

function UnitCacheUtcTimestamp: string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"',
    TTimeZone.Local.ToUniversalTime(Now));
end;

procedure DeleteUnitCacheEntryWithRetry(const aConnection: TFDConnection;
  const aKey: string);
var
  lRetryStart: UInt64;
  lRetryTimeoutMs: UInt64;
begin
  lRetryStart := TThread.GetTickCount64;
  lRetryTimeoutMs := UnitCacheSqliteBusyTimeoutMs;
  repeat
    try
      ExecWideSql(aConnection, 'delete from unit_models where cache_key = ?', aKey);
      Exit;
    except
      on E: Exception do
      begin
        if TDelphiSemanticSqliteUnitCache.SqliteBusyError(E) and
          (TThread.GetTickCount64 - lRetryStart < lRetryTimeoutMs) then
        begin
          TThread.Sleep(cUnitCacheSqliteBusyRetryDelayMs);
          Continue;
        end;
        raise;
      end;
    end;
  until False;
end;

procedure ExecuteUnitCacheStoreTransaction(const aConnection: TFDConnection;
  const aQuery: TFDQuery; const aIdentity: string);
var
  lRetryStart: UInt64;
  lRetryTimeoutMs: UInt64;
begin
  lRetryStart := TThread.GetTickCount64;
  lRetryTimeoutMs := UnitCacheSqliteBusyTimeoutMs;
  repeat
    try
      aQuery.Prepare;
      aConnection.StartTransaction;
      aQuery.ExecSQL;
      ExecWideSql(aConnection, 'delete from unit_models where identity_key = ? and ' +
        'cache_key not in (select cache_key from unit_models where identity_key = ? ' +
        'order by rowid desc limit ' +
        IntToStr(cPersistentKeysPerIdentity) + ')', aIdentity, aIdentity);
      aConnection.Commit;
      Exit;
    except
      on E: Exception do
      begin
        if aConnection.InTransaction then
          aConnection.Rollback;
        if TDelphiSemanticSqliteUnitCache.SqliteBusyError(E) and
          (TThread.GetTickCount64 - lRetryStart < lRetryTimeoutMs) then
        begin
          TThread.Sleep(cUnitCacheSqliteBusyRetryDelayMs);
          Continue;
        end;
        raise;
      end;
    end;
  until False;
end;

constructor TDelphiSemanticSqliteUnitCache.Create(const aOptions: TDelphiSemanticCacheOptions);
begin
  inherited Create(aOptions);
  fCacheFileName := aOptions.SqliteCacheFileName;
  fPersistenceAvailable := True;
  SetCacheKind('sqlite');
  EnsureDatabase;
  if not fPersistenceAvailable then
    SetCacheKind('in-memory-fallback');
end;

destructor TDelphiSemanticSqliteUnitCache.Destroy;
begin
  CloseSharedConnection;
  inherited;
end;

procedure TDelphiSemanticSqliteUnitCache.EnsureDatabase;
var
  lRetryStart: UInt64;
  lRetryTimeoutMs: UInt64;
begin
  lRetryStart := TThread.GetTickCount64;
  lRetryTimeoutMs := UnitCacheSqliteBusyTimeoutMs;
  repeat
    try
      EnsureDatabaseOnce;
      Exit;
    except
      on E: EUnitCacheSqliteSchemaMismatch do
      begin
        RebuildDatabase('SQLITE_CACHE_SCHEMA_REBUILT', E.Message);
        Exit;
      end;
      on E: Exception do
      begin
        if SqliteBusyError(E) then
        begin
          if TThread.GetTickCount64 - lRetryStart < lRetryTimeoutMs then
          begin
            TThread.Sleep(cUnitCacheSqliteBusyRetryDelayMs);
            Continue;
          end;
          DisablePersistence('SQLITE_CACHE_BUSY',
            'SQLite cache contention timed out without rebuilding the database: ' + E.Message);
          Exit;
        end;
        if UnitCacheSqliteCorruptionError(E) then
          RebuildDatabase('SQLITE_CACHE_REBUILT', E.Message)
        else
          DisablePersistence('SQLITE_CACHE_UNAVAILABLE',
            'SQLite cache is unavailable; continuing in memory: ' + E.Message);
        Exit;
      end;
    end;
  until False;
end;

procedure TDelphiSemanticSqliteUnitCache.EnsureDatabaseOnce;
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lCorrupt: Boolean;
  lDriverLinkObject: TObject;
  lError: string;
  lBusy: Boolean;
  lVersion: string;
begin
  if not OpenConnection(lConnectionObject, lDriverLinkObject, lError, lBusy, lCorrupt) then
  begin
    if lBusy then
      raise EUnitCacheSqliteBusy.Create(lError);
    if lCorrupt then
      raise EUnitCacheSqliteCorrupt.Create(lError);
    raise Exception.Create(lError);
  end;
  try
    lConnection := lConnectionObject as TFDConnection;
    if UnitCacheSqliteSchemaReady(lConnection, lVersion) then
      Exit;
    if (lVersion <> '') and (lVersion <> cSqliteSchemaVersion) then
      raise EUnitCacheSqliteSchemaMismatch.Create(
        'Unsupported SQLite cache schema version: ' + lVersion);
    CreateUnitCacheSqliteSchema(lConnection);
  finally
    lConnectionObject.Free;
    lDriverLinkObject.Free;
  end;
end;

procedure TDelphiSemanticSqliteUnitCache.CloseSharedConnection;
begin
  fConnection.Free;
  fConnection := nil;
  fDriverLink.Free;
  fDriverLink := nil;
end;

procedure TDelphiSemanticSqliteUnitCache.DisablePersistence(const aCode, aMessage: string);
begin
  AddDiagnostic(aCode, aMessage, fCacheFileName);
  CloseSharedConnection;
  fPersistenceAvailable := False;
  SetCacheKind('in-memory-fallback');
end;

function TDelphiSemanticSqliteUnitCache.OpenConnection(out aConnection: TObject;
  out aDriverLink: TObject; out aError: string; out aBusy, aCorrupt: Boolean): Boolean;
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lDirectory: string;
  lPhysicalFileName: string;
begin
  Result := False;
  aConnection := nil;
  aDriverLink := nil;
  aError := '';
  aBusy := False;
  aCorrupt := False;
  lConnection := nil;
  lDriverLink := nil;
  try
    lPhysicalFileName := PhysicalUnitCachePath(fCacheFileName);
    lDirectory := ExtractFilePath(lPhysicalFileName);
    if lDirectory <> '' then
      ForceDirectories(lDirectory);
    lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    lConnection := TFDConnection.Create(nil);
    ConfigureUnitCacheSqliteConnection(lConnection, lPhysicalFileName);
    lConnection.Connected := True;
    aConnection := lConnection;
    aDriverLink := lDriverLink;
    Result := True;
  except
    on E: Exception do
    begin
      aError := E.Message;
      aBusy := SqliteBusyError(E);
      aCorrupt := UnitCacheSqliteCorruptionError(E);
      lConnection.Free;
      lDriverLink.Free;
    end;
  end;
end;

function TDelphiSemanticSqliteUnitCache.SharedConnection(out aConnection: TObject;
  out aError: string): Boolean;
var
  lBusy: Boolean;
  lCorrupt: Boolean;
begin
  aConnection := nil;
  aError := '';
  if not fPersistenceAvailable then
    Exit(False);
  if Assigned(fConnection) then
  begin
    aConnection := fConnection;
    Exit(True);
  end;

  Result := OpenConnection(fConnection, fDriverLink, aError, lBusy, lCorrupt);
  if Result then
  begin
    aConnection := fConnection;
    RecordPersistentConnectionOpen;
  end else if lBusy then
    DisablePersistence('SQLITE_CACHE_BUSY',
      'SQLite cache contention prevented a persistent connection; continuing in memory: ' +
      aError)
  else if lCorrupt then
    DisablePersistence('SQLITE_CACHE_UNAVAILABLE',
      'SQLite cache became corrupt after initialization; continuing in memory: ' + aError)
  else begin
    DisablePersistence('SQLITE_CACHE_UNAVAILABLE',
      'SQLite cache is unavailable; continuing in memory: ' + aError);
  end;
end;

function TDelphiSemanticSqliteUnitCache.PersistentEntryExistsForIdentity(
  const aIdentity: string): Boolean;
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
begin
  Result := False;
  if not fPersistenceAvailable then
    Exit;
  if not SharedConnection(lConnectionObject, lError) then
    Exit;
  lConnection := lConnectionObject as TFDConnection;
  Result := QueryInteger(lConnection, 'select count(*) from unit_models where identity_key = ?',
    aIdentity) > 0;
end;

procedure TDelphiSemanticSqliteUnitCache.RebuildDatabase(const aCode, aMessage: string);
var
  lBusy: Boolean;
  lConnection: TFDConnection;
  lConnectionObject: TObject;
  lCorrupt: Boolean;
  lDriverLinkObject: TObject;
  lError: string;
  lPhysicalFileName: string;
begin
  CloseSharedConnection;
  try
    lPhysicalFileName := PhysicalUnitCachePath(fCacheFileName);
    if FileExists(lPhysicalFileName) and not System.SysUtils.DeleteFile(lPhysicalFileName) then
      raise Exception.Create('Could not delete the prior SQLite cache file.');
    if not OpenConnection(lConnectionObject, lDriverLinkObject, lError, lBusy, lCorrupt) then
      raise Exception.Create('Could not reopen the SQLite cache database: ' + lError);
    try
      lConnection := lConnectionObject as TFDConnection;
      lConnection.ExecSQL('drop table if exists unit_models');
      lConnection.ExecSQL('drop table if exists meta');
      CreateUnitCacheSqliteSchema(lConnection);
    finally
      lConnectionObject.Free;
      lDriverLinkObject.Free;
    end;
    fPersistenceAvailable := True;
    AddDiagnostic(aCode, aMessage, fCacheFileName);
  except
    on E: Exception do
      DisablePersistence('SQLITE_CACHE_UNAVAILABLE',
        'SQLite cache rebuild failed; continuing in memory: ' + E.Message);
  end;
end;

procedure TDelphiSemanticSqliteUnitCache.RecordPersistentInvalidation(const aIdentity,
  aKey: string);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lProfile: string;
begin
  if not fPersistenceAvailable then
    Exit;
  if not SharedConnection(lConnectionObject, lError) then
    Exit;
  lConnection := lConnectionObject as TFDConnection;
  lProfile := QueryWideString(lConnection,
    'select compiler_profile_name from unit_models where identity_key = ? limit 1',
    aIdentity);
  if (lProfile <> '') and (not SameText(lProfile, CurrentCompilerProfileName)) then
    AddDiagnostic('SQLITE_CACHE_STALE_PROFILE_REBUILT',
      'SQLite cache entry was rebuilt for compiler profile: ' + CurrentCompilerProfileName,
      fCacheFileName)
  else
    AddDiagnostic('SQLITE_CACHE_STALE_ENTRY_REBUILT',
      'SQLite cache entry was stale for source identity: ' + aIdentity, fCacheFileName);
end;

procedure TDelphiSemanticSqliteUnitCache.StorePersistentEntry(const aIdentity, aKey: string;
  const aCacheIdentity: TDelphiSemanticUnitCacheIdentity;
  const aModel: TDelphiSemanticUnitModel);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lQuery: TFDQuery;
begin
  if not fPersistenceAvailable then
    Exit;
  if not SharedConnection(lConnectionObject, lError) then
    Exit;
  lConnection := lConnectionObject as TFDConnection;
  lQuery := NewQuery(lConnection, 'insert or replace into unit_models(cache_key, identity_key, ' +
    'source_file_name, file_hash, delphi_version, configuration, platform, compiler_profile_name, ' +
    'schema_version, parser_version, model_version, include_graph_hash, context_hash, ' +
    'defines_hash, search_path_hash, extraction_options_hash, model_json, stored_at_utc) ' +
    'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    SetWideParam(lQuery, 0, aKey);
    SetWideParam(lQuery, 1, aIdentity);
    SetWideParam(lQuery, 2, aCacheIdentity.SourceFileName);
    SetWideParam(lQuery, 3, aCacheIdentity.FileHash);
    SetWideParam(lQuery, 4, DelphiVersion);
    SetWideParam(lQuery, 5, Configuration);
    SetWideParam(lQuery, 6, Platform);
    SetWideParam(lQuery, 7, CurrentCompilerProfileName);
    SetWideParam(lQuery, 8, aCacheIdentity.SchemaVersion);
    SetWideParam(lQuery, 9, aCacheIdentity.ParserVersion);
    SetWideParam(lQuery, 10, aCacheIdentity.ModelVersion);
    SetWideParam(lQuery, 11, aCacheIdentity.IncludeGraphHash);
    SetWideParam(lQuery, 12, aCacheIdentity.ContextHash);
    SetWideParam(lQuery, 13, aCacheIdentity.DefinesHash);
    SetWideParam(lQuery, 14, aCacheIdentity.SearchPathHash);
    SetWideParam(lQuery, 15, aCacheIdentity.ExtractionOptionsHash);
    SetWideParam(lQuery, 16, ModelToJson(aModel), ftWideMemo);
    SetWideParam(lQuery, 17, UnitCacheUtcTimestamp);
    ExecuteUnitCacheStoreTransaction(lConnection, lQuery, aIdentity);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSqliteUnitCache.DiscardUnreadablePersistentEntry(
  const aConnection: TObject; const aKey, aMessage: string);
begin
  AddDiagnostic('SQLITE_CACHE_ENTRY_REBUILT', aMessage, fCacheFileName);
  try
    DeleteUnitCacheEntryWithRetry(aConnection as TFDConnection, aKey);
  except
    on E: Exception do
    begin
      if SqliteBusyError(E) then
        DisablePersistence('SQLITE_CACHE_BUSY',
          'SQLite cache entry cleanup timed out; continuing in memory: ' + E.Message)
      else
        DisablePersistence('SQLITE_CACHE_UNAVAILABLE',
          'SQLite cache entry cleanup failed; continuing in memory: ' + E.Message);
    end;
  end;
end;

function TDelphiSemanticSqliteUnitCache.TryLoadPersistentEntry(const aIdentity, aKey: string;
  out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lJson: string;
begin
  aModel := Default(TDelphiSemanticUnitModel);
  Result := False;
  if not fPersistenceAvailable then
    Exit;
  if not SharedConnection(lConnectionObject, lError) then
    Exit;
  lConnection := lConnectionObject as TFDConnection;
  lJson := QueryWideString(lConnection,
    'select model_json from unit_models where cache_key = ?', aKey);
  if lJson = '' then
    Exit(False);
  try
    aModel := JsonToModel(lJson);
  except
    on E: Exception do
    begin
      DiscardUnreadablePersistentEntry(lConnectionObject, aKey,
        'SQLite cache entry could not be read and will be rebuilt: ' + E.Message);
      Exit(False);
    end;
  end;
  Result := aModel.UnitName <> '';
  if not Result then
    DiscardUnreadablePersistentEntry(lConnectionObject, aKey,
      'SQLite cache entry was unreadable and will be rebuilt.');
end;

end.
