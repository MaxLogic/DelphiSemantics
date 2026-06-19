unit DelphiSemantics.Cache.Sqlite;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.Model, DelphiSemantics.Model.Json;

type
  TDelphiSemanticSqliteUnitCache = class(TDelphiSemanticUnitCache)
  private
    fCacheFileName: string;
    fConnection: TObject;
    fDriverLink: TObject;
    function OpenConnection(out aConnection: TObject; out aDriverLink: TObject;
      out aError: string): Boolean;
    function SharedConnection(out aConnection: TObject; out aError: string): Boolean;
    procedure CloseSharedConnection;
    procedure RebuildDatabase(const aCode, aMessage: string);
    procedure EnsureDatabase;
  protected
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
  System.SysUtils,
  Data.DB,
  FireDAC.Comp.Client, FireDAC.Phys.SQLite, FireDAC.Stan.Async, FireDAC.Stan.Def;

const
  cSqliteSchemaVersion = '9';

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

function QueryInteger(const aConnection: TFDConnection; const aSql, aValue: string): Int64;
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

constructor TDelphiSemanticSqliteUnitCache.Create(const aOptions: TDelphiSemanticCacheOptions);
begin
  inherited Create(aOptions);
  fCacheFileName := aOptions.SqliteCacheFileName;
  SetCacheKind('sqlite');
  EnsureDatabase;
end;

destructor TDelphiSemanticSqliteUnitCache.Destroy;
begin
  CloseSharedConnection;
  inherited;
end;

procedure TDelphiSemanticSqliteUnitCache.EnsureDatabase;
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lDriverLinkObject: TObject;
  lError: string;
  lVersion: string;
begin
  if not OpenConnection(lConnectionObject, lDriverLinkObject, lError) then
  begin
    RebuildDatabase('SQLITE_CACHE_REBUILT', lError);
    Exit;
  end;
  try
    lConnection := TFDConnection(lConnectionObject);
    try
      lConnection.ExecSQL('create table if not exists meta (' +
        'key_name text primary key not null, value_text text not null)');
      lVersion := QueryWideString(lConnection,
        'select value_text from meta where key_name = ''schema_version''');
      if (lVersion <> '') and (lVersion <> cSqliteSchemaVersion) then
      begin
        RebuildDatabase('SQLITE_CACHE_SCHEMA_REBUILT',
          'Unsupported SQLite cache schema version: ' + lVersion);
        Exit;
      end;
      lConnection.ExecSQL('create table if not exists unit_models (' +
        'cache_key text primary key not null, identity_key text not null, ' +
        'source_file_name text not null, file_hash text not null, delphi_version text not null, ' +
        'configuration text not null, platform text not null, compiler_profile_name text not null, ' +
        'schema_version text not null, parser_version text not null, model_version text not null, ' +
        'include_graph_hash text not null, context_hash text not null, defines_hash text not null, ' +
        'search_path_hash text not null, extraction_options_hash text not null, ' +
        'model_json text not null, stored_at_utc text not null)');
      lConnection.ExecSQL('create index if not exists idx_unit_models_identity on ' +
        'unit_models(identity_key)');
      ExecWideSql(lConnection, 'insert or replace into meta(key_name, value_text) values ' +
        '(?, ?)', 'schema_version', cSqliteSchemaVersion);
    except
      on E: Exception do
      begin
        RebuildDatabase('SQLITE_CACHE_REBUILT', E.Message);
        Exit;
      end;
    end;
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

function TDelphiSemanticSqliteUnitCache.OpenConnection(out aConnection: TObject;
  out aDriverLink: TObject; out aError: string): Boolean;
var
  lConnection: TFDConnection;
  lDriverLink: TFDPhysSQLiteDriverLink;
  lDirectory: string;
begin
  Result := False;
  aConnection := nil;
  aDriverLink := nil;
  aError := '';
  lConnection := nil;
  lDriverLink := nil;
  try
    lDirectory := ExtractFilePath(fCacheFileName);
    if lDirectory <> '' then
      ForceDirectories(lDirectory);
    lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    lConnection := TFDConnection.Create(nil);
    lConnection.LoginPrompt := False;
    lConnection.Params.Values['DriverID'] := 'SQLite';
    lConnection.Params.Values['Database'] := fCacheFileName;
    lConnection.Connected := True;
    aConnection := lConnection;
    aDriverLink := lDriverLink;
    Result := True;
  except
    on E: Exception do
    begin
      aError := E.Message;
      lConnection.Free;
      lDriverLink.Free;
    end;
  end;
end;

function TDelphiSemanticSqliteUnitCache.SharedConnection(out aConnection: TObject;
  out aError: string): Boolean;
begin
  aConnection := nil;
  aError := '';
  if Assigned(fConnection) then
  begin
    aConnection := fConnection;
    Exit(True);
  end;

  Result := OpenConnection(fConnection, fDriverLink, aError);
  if Result then
  begin
    aConnection := fConnection;
    RecordPersistentConnectionOpen;
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
  if not SharedConnection(lConnectionObject, lError) then
    Exit;
  lConnection := TFDConnection(lConnectionObject);
  Result := QueryInteger(lConnection, 'select count(*) from unit_models where identity_key = ?',
    aIdentity) > 0;
end;

procedure TDelphiSemanticSqliteUnitCache.RebuildDatabase(const aCode, aMessage: string);
var
  lConnection: TFDConnection;
  lConnectionObject: TObject;
  lDriverLinkObject: TObject;
  lError: string;
begin
  AddDiagnostic(aCode, aMessage, fCacheFileName);
  CloseSharedConnection;
  if FileExists(fCacheFileName) then
    DeleteFile(fCacheFileName);
  if not OpenConnection(lConnectionObject, lDriverLinkObject, lError) then
  begin
    AddDiagnostic('SQLITE_CACHE_OPEN_FAILED', lError, fCacheFileName);
    Exit;
  end;
  try
    lConnection := TFDConnection(lConnectionObject);
    lConnection.ExecSQL('drop table if exists unit_models');
    lConnection.ExecSQL('drop table if exists meta');
    lConnection.ExecSQL('create table if not exists meta (' +
      'key_name text primary key not null, value_text text not null)');
    lConnection.ExecSQL('delete from meta');
    ExecWideSql(lConnection, 'insert or replace into meta(key_name, value_text) values ' +
      '(?, ?)', 'schema_version', cSqliteSchemaVersion);
    lConnection.ExecSQL('create table if not exists unit_models (' +
      'cache_key text primary key not null, identity_key text not null, ' +
      'source_file_name text not null, file_hash text not null, delphi_version text not null, ' +
      'configuration text not null, platform text not null, compiler_profile_name text not null, ' +
      'schema_version text not null, parser_version text not null, model_version text not null, ' +
      'include_graph_hash text not null, context_hash text not null, defines_hash text not null, ' +
      'search_path_hash text not null, extraction_options_hash text not null, ' +
      'model_json text not null, stored_at_utc text not null)');
    lConnection.ExecSQL('delete from unit_models');
    lConnection.ExecSQL('create index if not exists idx_unit_models_identity on ' +
      'unit_models(identity_key)');
  finally
    lConnectionObject.Free;
    lDriverLinkObject.Free;
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
  if not SharedConnection(lConnectionObject, lError) then
  begin
    AddDiagnostic('SQLITE_CACHE_STALE_ENTRY_REBUILT',
      'SQLite cache entry was stale for source identity: ' + aIdentity, fCacheFileName);
    Exit;
  end;
  lConnection := TFDConnection(lConnectionObject);
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
  if not SharedConnection(lConnectionObject, lError) then
  begin
    AddDiagnostic('SQLITE_CACHE_OPEN_FAILED', lError, fCacheFileName);
    Exit;
  end;
  lConnection := TFDConnection(lConnectionObject);
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
    SetWideParam(lQuery, 17, FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
    lQuery.Prepare;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
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
  if not SharedConnection(lConnectionObject, lError) then
    Exit;
  lConnection := TFDConnection(lConnectionObject);
  lJson := QueryWideString(lConnection,
    'select model_json from unit_models where cache_key = ?', aKey);
  if lJson = '' then
    Exit(False);
  try
    aModel := JsonToModel(lJson);
    Result := aModel.UnitName <> '';
    if not Result then
    begin
      AddDiagnostic('SQLITE_CACHE_ENTRY_REBUILT',
        'SQLite cache entry was unreadable and will be rebuilt.', fCacheFileName);
      ExecWideSql(lConnection, 'delete from unit_models where cache_key = ?', aKey);
    end;
  except
    on E: Exception do
    begin
      AddDiagnostic('SQLITE_CACHE_ENTRY_REBUILT',
        'SQLite cache entry could not be read and will be rebuilt: ' + E.Message,
        fCacheFileName);
      ExecWideSql(lConnection, 'delete from unit_models where cache_key = ?', aKey);
      Result := False;
    end;
  end;
end;

end.
