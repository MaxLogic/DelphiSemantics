unit DelphiSemantics.Snapshot.Cache.Sqlite;

interface

uses
  DelphiSemantics.Snapshot;

type
  TDelphiSemanticSnapshotCacheIdentity = record
    CacheKey: string;
    IdentityKey: string;
    SourceFileName: string;
    FileHash: string;
    ContextHash: string;
    IncludeGraphHash: string;
    SchemaVersion: string;
  end;

  TDelphiSemanticSnapshotCacheMetrics = record
    CacheHits: Integer;
    CacheMisses: Integer;
    Invalidations: Integer;
    PersistentConnectionOpenCount: Integer;
  end;

  TDelphiSemanticSnapshotSqliteCache = class
  private
    fCacheFileName: string;
    fConnection: TObject;
    fDriverLink: TObject;
    fMetrics: TDelphiSemanticSnapshotCacheMetrics;
    procedure CloseSharedConnection;
    procedure DeleteIdentity(const aIdentityKey: string);
    procedure DeleteIdentityRows(const aConnection: TObject; const aIdentityKey: string);
    procedure EnsureDatabase;
    function EntryExistsForIdentity(const aIdentityKey: string): Boolean;
    function IdentityMatches(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject): Boolean;
    procedure LoadReferences(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot);
    procedure LoadStrings(const aCacheKey: string; const aConnection: TObject;
      const aStrings: TSemanticStringPool);
    procedure LoadSymbols(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot);
    function LoadUnitHeader(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; out aUnit: TUnitSnapshot; out aStringCount,
      aSymbolCount, aWithStatementCount, aReferenceCount: Integer): Boolean;
    procedure LoadWithStatements(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot);
    function OpenConnection(out aConnection: TObject; out aDriverLink: TObject;
      out aError: string): Boolean;
    procedure RebuildSnapshotTables(const aConnection: TObject);
    function SharedConnection(out aConnection: TObject; out aError: string): Boolean;
    procedure StoreReferences(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot);
    procedure StoreStrings(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aStrings: TSemanticStringPool);
    procedure StoreSymbols(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot);
    procedure StoreUnitHeader(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot; const aStringCount: Integer);
    procedure StoreWithStatements(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot);
  public
    constructor Create(const aCacheFileName: string);
    destructor Destroy; override;
    procedure StoreUnit(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aStrings: TSemanticStringPool; const aUnit: TUnitSnapshot);
    function TryLoadUnit(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      out aSnapshot: TDelphiProjectSnapshot): Boolean;
    property Metrics: TDelphiSemanticSnapshotCacheMetrics read fMetrics;
  end;

implementation

uses
  System.DateUtils, System.SysUtils, System.Variants,
  FireDAC.Comp.Client, FireDAC.DApt, FireDAC.Phys.SQLite, FireDAC.Stan.Async,
  FireDAC.Stan.Def;

const
  cSnapshotCacheSchemaVersion = '2';
  cSnapshotSchemaMetaKey = 'snapshot_schema_version';

function NewQuery(const aConnection: TFDConnection; const aSql: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := aConnection;
  Result.SQL.Text := aSql;
end;

function SnapshotUtcTimestamp: string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"',
    TTimeZone.Local.ToUniversalTime(Now));
end;

procedure ValidateIdentityComplete(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aOperationName: string);
begin
  if aIdentity.CacheKey = '' then
    raise Exception.Create('Cannot ' + aOperationName + ' a unit snapshot without a cache key.');
  if aIdentity.IdentityKey = '' then
    raise Exception.Create('Cannot ' + aOperationName + ' a unit snapshot without an identity key.');
  if aIdentity.SourceFileName = '' then
    raise Exception.Create('Cannot ' + aOperationName +
      ' a unit snapshot without a source filename.');
  if aIdentity.FileHash = '' then
    raise Exception.Create('Cannot ' + aOperationName + ' a unit snapshot without a file hash.');
  if aIdentity.ContextHash = '' then
    raise Exception.Create('Cannot ' + aOperationName +
      ' a unit snapshot without a context hash.');
  if aIdentity.IncludeGraphHash = '' then
    raise Exception.Create('Cannot ' + aOperationName +
      ' a unit snapshot without an include graph hash.');
  if aIdentity.SchemaVersion = '' then
    raise Exception.Create('Cannot ' + aOperationName +
      ' a unit snapshot without a schema version.');
end;

procedure ValidateStringId(const aStrings: TSemanticStringPool; const aId: TSemanticStringId;
  const aFieldName: string);
begin
  if aId = 0 then
    Exit;

  if aId > aStrings.Count then
    raise Exception.Create('Snapshot string ID outside string pool: ' + aFieldName);
  if aStrings.TextOf(aId) = '' then
    raise Exception.Create('Snapshot string ID resolves to empty text: ' + aFieldName);
end;

procedure ValidateUnitStringIds(const aStrings: TSemanticStringPool; const aUnit: TUnitSnapshot);
var
  i: Integer;
  lReference: TSemanticReferenceFact;
  lSymbol: TSemanticSymbolFact;
  lWith: TSemanticWithStatementFact;
begin
  ValidateStringId(aStrings, aUnit.FileNameId, 'file_name_id');
  ValidateStringId(aStrings, aUnit.UnitNameId, 'unit_name_id');

  for i := 1 to aUnit.SymbolCount do
  begin
    lSymbol := aUnit.SymbolById(TSemanticSymbolId(i));
    ValidateStringId(aStrings, lSymbol.NameId, 'symbol.name_id');
    ValidateStringId(aStrings, lSymbol.OwnerTypeId, 'symbol.owner_type_id');
    ValidateStringId(aStrings, lSymbol.TypeId, 'symbol.type_id');
    ValidateStringId(aStrings, lSymbol.RoutineId, 'symbol.routine_id');
    ValidateStringId(aStrings, lSymbol.KindId, 'symbol.kind_id');
  end;

  for i := 1 to aUnit.WithStatementCount do
  begin
    lWith := aUnit.WithStatementById(TSemanticWithId(i));
    ValidateStringId(aStrings, lWith.RoutineId, 'with.routine_id');
  end;

  for i := 1 to aUnit.ReferenceCount do
  begin
    lReference := aUnit.ReferenceById(TSemanticReferenceId(i));
    ValidateStringId(aStrings, lReference.NameId, 'reference.name_id');
    ValidateStringId(aStrings, lReference.ReceiverTypeId, 'reference.receiver_type_id');
    ValidateStringId(aStrings, lReference.TypeId, 'reference.type_id');
    ValidateStringId(aStrings, lReference.ClassificationId, 'reference.classification_id');
    ValidateStringId(aStrings, lReference.LookupSourceId, 'reference.lookup_source_id');
    ValidateStringId(aStrings, lReference.ReasonId, 'reference.reason_id');
  end;
end;

procedure ValidateLoadedCounts(const aStrings: TSemanticStringPool; const aUnit: TUnitSnapshot;
  const aStringCount, aSymbolCount, aWithStatementCount, aReferenceCount: Integer);
begin
  if Integer(aStrings.Count) <> aStringCount then
    raise Exception.Create('Snapshot string row count mismatch.');
  if aUnit.SymbolCount <> aSymbolCount then
    raise Exception.Create('Snapshot symbol row count mismatch.');
  if aUnit.WithStatementCount <> aWithStatementCount then
    raise Exception.Create('Snapshot with row count mismatch.');
  if aUnit.ReferenceCount <> aReferenceCount then
    raise Exception.Create('Snapshot reference row count mismatch.');
end;

constructor TDelphiSemanticSnapshotSqliteCache.Create(const aCacheFileName: string);
begin
  inherited Create;
  fCacheFileName := aCacheFileName;
  EnsureDatabase;
end;

destructor TDelphiSemanticSnapshotSqliteCache.Destroy;
begin
  CloseSharedConnection;
  inherited;
end;

procedure TDelphiSemanticSnapshotSqliteCache.CloseSharedConnection;
begin
  fConnection.Free;
  fConnection := nil;
  fDriverLink.Free;
  fDriverLink := nil;
end;

procedure TDelphiSemanticSnapshotSqliteCache.DeleteIdentity(const aIdentityKey: string);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lOwnsTransaction: Boolean;
begin
  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);
  lConnection := TFDConnection(lConnectionObject);
  lOwnsTransaction := not lConnection.InTransaction;
  if lOwnsTransaction then
    lConnection.StartTransaction;
  try
    DeleteIdentityRows(lConnection, aIdentityKey);
    if lOwnsTransaction then
      lConnection.Commit;
  except
    if lOwnsTransaction and lConnection.InTransaction then
      lConnection.Rollback;
    raise;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.DeleteIdentityRows(const aConnection: TObject;
  const aIdentityKey: string);
var
  lConnection: TFDConnection;
begin
  lConnection := TFDConnection(aConnection);
  lConnection.ExecSQL('delete from snapshot_references where cache_key in ' +
    '(select cache_key from snapshot_units where identity_key = ?)', [aIdentityKey]);
  lConnection.ExecSQL('delete from snapshot_with_statements where cache_key in ' +
    '(select cache_key from snapshot_units where identity_key = ?)', [aIdentityKey]);
  lConnection.ExecSQL('delete from snapshot_symbols where cache_key in ' +
    '(select cache_key from snapshot_units where identity_key = ?)', [aIdentityKey]);
  lConnection.ExecSQL('delete from snapshot_strings where cache_key in ' +
    '(select cache_key from snapshot_units where identity_key = ?)', [aIdentityKey]);
  lConnection.ExecSQL('delete from snapshot_units where identity_key = ?', [aIdentityKey]);
end;

procedure TDelphiSemanticSnapshotSqliteCache.EnsureDatabase;
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lDriverLinkObject: TObject;
  lError: string;
  lVersion: string;
begin
  if not OpenConnection(lConnectionObject, lDriverLinkObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);
  try
    lConnection := TFDConnection(lConnectionObject);
    lConnection.ExecSQL('create table if not exists meta (' +
      'key_name text primary key not null, value_text text not null)');
    lVersion := VarToStr(lConnection.ExecSQLScalar(
      'select value_text from meta where key_name = ?', [cSnapshotSchemaMetaKey]));
    if (lVersion <> '') and (lVersion <> cSnapshotCacheSchemaVersion) then
      RebuildSnapshotTables(lConnection);

    lConnection.ExecSQL('create table if not exists snapshot_units (' +
      'cache_key text primary key not null, identity_key text not null, ' +
      'source_file_name text not null, file_hash text not null, context_hash text not null, ' +
      'include_graph_hash text not null, schema_version text not null, ' +
      'stored_at_utc text not null, unit_id integer not null, file_name_id integer not null, ' +
      'unit_name_id integer not null, string_count integer not null, ' +
      'symbol_count integer not null, with_statement_count integer not null, ' +
      'reference_count integer not null)');
    lConnection.ExecSQL('create index if not exists idx_snapshot_units_identity on ' +
      'snapshot_units(identity_key)');
    lConnection.ExecSQL('create table if not exists snapshot_strings (' +
      'cache_key text not null, string_id integer not null, text_value text not null, ' +
      'primary key(cache_key, string_id))');
    lConnection.ExecSQL('create table if not exists snapshot_symbols (' +
      'cache_key text not null, unit_id integer not null, symbol_id integer not null, ' +
      'name_id integer not null, owner_type_id integer not null, type_id integer not null, ' +
      'routine_id integer not null, kind_id integer not null, flags integer not null, ' +
      'line integer not null, column integer not null, end_line integer not null, ' +
      'end_column integer not null, primary key(cache_key, unit_id, symbol_id))');
    lConnection.ExecSQL('create table if not exists snapshot_with_statements (' +
      'cache_key text not null, unit_id integer not null, with_id integer not null, ' +
      'routine_id integer not null, selector_start_line integer not null, ' +
      'selector_start_column integer not null, body_start_line integer not null, ' +
      'body_start_column integer not null, body_end_line integer not null, ' +
      'body_end_column integer not null, flags integer not null, ' +
      'primary key(cache_key, unit_id, with_id))');
    lConnection.ExecSQL('create table if not exists snapshot_references (' +
      'cache_key text not null, unit_id integer not null, reference_id integer not null, ' +
      'with_id integer not null, target_unit_id integer not null, ' +
      'target_symbol_id integer not null, name_id integer not null, ' +
      'receiver_type_id integer not null, type_id integer not null, ' +
      'classification_id integer not null, lookup_source_id integer not null, ' +
      'reason_id integer not null, line integer not null, column integer not null, ' +
      'end_line integer not null, end_column integer not null, ' +
      'primary key(cache_key, unit_id, reference_id))');
    lConnection.ExecSQL('insert or replace into meta(key_name, value_text) values (?, ?)',
      [cSnapshotSchemaMetaKey, cSnapshotCacheSchemaVersion]);
  finally
    lConnectionObject.Free;
    lDriverLinkObject.Free;
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.EntryExistsForIdentity(
  const aIdentityKey: string): Boolean;
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
begin
  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);
  lConnection := TFDConnection(lConnectionObject);
  Result := lConnection.ExecSQLScalar(
    'select count(*) from snapshot_units where identity_key = ?', [aIdentityKey]) > 0;
end;

function TDelphiSemanticSnapshotSqliteCache.IdentityMatches(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aConnection: TObject): Boolean;
var
  lQuery: TFDQuery;
begin
  Result := False;
  lQuery := NewQuery(TFDConnection(aConnection), 'select source_file_name, file_hash, ' +
    'context_hash, include_graph_hash, schema_version from snapshot_units where cache_key = ? ' +
    'and identity_key = ?');
  try
    lQuery.Params[0].AsString := aIdentity.CacheKey;
    lQuery.Params[1].AsString := aIdentity.IdentityKey;
    lQuery.Open;
    if lQuery.Eof then
      Exit;

    Result := SameText(lQuery.FieldByName('source_file_name').AsString, aIdentity.SourceFileName)
      and (lQuery.FieldByName('file_hash').AsString = aIdentity.FileHash)
      and (lQuery.FieldByName('context_hash').AsString = aIdentity.ContextHash)
      and (lQuery.FieldByName('include_graph_hash').AsString = aIdentity.IncludeGraphHash)
      and (lQuery.FieldByName('schema_version').AsString = aIdentity.SchemaVersion);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadReferences(const aCacheKey: string;
  const aConnection: TObject; const aUnit: TUnitSnapshot);
var
  lExpectedId: TSemanticReferenceId;
  lQuery: TFDQuery;
  lReference: TSemanticReferenceFact;
  lReferenceId: TSemanticReferenceId;
begin
  lExpectedId := 1;
  lQuery := NewQuery(TFDConnection(aConnection), 'select reference_id, with_id, ' +
    'target_unit_id, target_symbol_id, name_id, receiver_type_id, type_id, classification_id, ' +
    'lookup_source_id, reason_id, line, column, end_line, end_column from snapshot_references ' +
    'where cache_key = ? order by reference_id');
  try
    lQuery.Params[0].AsString := aCacheKey;
    lQuery.Open;
    while not lQuery.Eof do
    begin
      if TSemanticReferenceId(lQuery.FieldByName('reference_id').AsInteger) <> lExpectedId then
        raise Exception.Create('Snapshot reference IDs are not dense.');

      lReference := Default(TSemanticReferenceFact);
      lReference.WithId := TSemanticWithId(lQuery.FieldByName('with_id').AsInteger);
      lReference.TargetUnitId := TSemanticUnitId(lQuery.FieldByName('target_unit_id').AsInteger);
      lReference.TargetSymbolId := TSemanticSymbolId(lQuery.FieldByName('target_symbol_id').AsInteger);
      lReference.NameId := TSemanticStringId(lQuery.FieldByName('name_id').AsInteger);
      lReference.ReceiverTypeId := TSemanticStringId(lQuery.FieldByName('receiver_type_id').AsInteger);
      lReference.TypeId := TSemanticStringId(lQuery.FieldByName('type_id').AsInteger);
      lReference.ClassificationId := TSemanticStringId(lQuery.FieldByName('classification_id').AsInteger);
      lReference.LookupSourceId := TSemanticStringId(lQuery.FieldByName('lookup_source_id').AsInteger);
      lReference.ReasonId := TSemanticStringId(lQuery.FieldByName('reason_id').AsInteger);
      lReference.Line := lQuery.FieldByName('line').AsInteger;
      lReference.Column := lQuery.FieldByName('column').AsInteger;
      lReference.EndLine := lQuery.FieldByName('end_line').AsInteger;
      lReference.EndColumn := lQuery.FieldByName('end_column').AsInteger;
      lReferenceId := aUnit.AddReference(lReference);
      if lReferenceId <> lExpectedId then
        raise Exception.Create('Snapshot reference ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadStrings(const aCacheKey: string;
  const aConnection: TObject; const aStrings: TSemanticStringPool);
var
  lExpectedId: TSemanticStringId;
  lQuery: TFDQuery;
  lStringId: TSemanticStringId;
begin
  lExpectedId := 1;
  lQuery := NewQuery(TFDConnection(aConnection), 'select string_id, text_value from ' +
    'snapshot_strings where cache_key = ? order by string_id');
  try
    lQuery.Params[0].AsString := aCacheKey;
    lQuery.Open;
    while not lQuery.Eof do
    begin
      if TSemanticStringId(lQuery.FieldByName('string_id').AsInteger) <> lExpectedId then
        raise Exception.Create('Snapshot string IDs are not dense.');

      lStringId := aStrings.Intern(lQuery.FieldByName('text_value').AsString);
      if lStringId <> lExpectedId then
        raise Exception.Create('Snapshot string ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadSymbols(const aCacheKey: string;
  const aConnection: TObject; const aUnit: TUnitSnapshot);
var
  lExpectedId: TSemanticSymbolId;
  lQuery: TFDQuery;
  lSymbol: TSemanticSymbolFact;
  lSymbolId: TSemanticSymbolId;
begin
  lExpectedId := 1;
  lQuery := NewQuery(TFDConnection(aConnection), 'select symbol_id, name_id, owner_type_id, ' +
    'type_id, routine_id, kind_id, flags, line, column, end_line, end_column from ' +
    'snapshot_symbols where cache_key = ? order by symbol_id');
  try
    lQuery.Params[0].AsString := aCacheKey;
    lQuery.Open;
    while not lQuery.Eof do
    begin
      if TSemanticSymbolId(lQuery.FieldByName('symbol_id').AsInteger) <> lExpectedId then
        raise Exception.Create('Snapshot symbol IDs are not dense.');

      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := TSemanticStringId(lQuery.FieldByName('name_id').AsInteger);
      lSymbol.OwnerTypeId := TSemanticStringId(lQuery.FieldByName('owner_type_id').AsInteger);
      lSymbol.TypeId := TSemanticStringId(lQuery.FieldByName('type_id').AsInteger);
      lSymbol.RoutineId := TSemanticStringId(lQuery.FieldByName('routine_id').AsInteger);
      lSymbol.KindId := TSemanticStringId(lQuery.FieldByName('kind_id').AsInteger);
      lSymbol.Flags := Cardinal(lQuery.FieldByName('flags').AsInteger);
      lSymbol.Line := lQuery.FieldByName('line').AsInteger;
      lSymbol.Column := lQuery.FieldByName('column').AsInteger;
      lSymbol.EndLine := lQuery.FieldByName('end_line').AsInteger;
      lSymbol.EndColumn := lQuery.FieldByName('end_column').AsInteger;
      lSymbolId := aUnit.AddSymbol(lSymbol);
      if lSymbolId <> lExpectedId then
        raise Exception.Create('Snapshot symbol ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.LoadUnitHeader(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  out aUnit: TUnitSnapshot; out aStringCount, aSymbolCount, aWithStatementCount,
  aReferenceCount: Integer): Boolean;
var
  lQuery: TFDQuery;
begin
  aUnit := nil;
  aStringCount := 0;
  aSymbolCount := 0;
  aWithStatementCount := 0;
  aReferenceCount := 0;
  lQuery := NewQuery(TFDConnection(aConnection), 'select unit_id, file_name_id, unit_name_id, ' +
    'string_count, symbol_count, with_statement_count, reference_count from snapshot_units ' +
    'where cache_key = ? and identity_key = ?');
  try
    lQuery.Params[0].AsString := aIdentity.CacheKey;
    lQuery.Params[1].AsString := aIdentity.IdentityKey;
    lQuery.Open;
    Result := not lQuery.Eof;
    if Result then
    begin
      aUnit := TUnitSnapshot.Create(TSemanticUnitId(lQuery.FieldByName('unit_id').AsInteger),
        TSemanticStringId(lQuery.FieldByName('file_name_id').AsInteger),
        TSemanticStringId(lQuery.FieldByName('unit_name_id').AsInteger));
      aStringCount := lQuery.FieldByName('string_count').AsInteger;
      aSymbolCount := lQuery.FieldByName('symbol_count').AsInteger;
      aWithStatementCount := lQuery.FieldByName('with_statement_count').AsInteger;
      aReferenceCount := lQuery.FieldByName('reference_count').AsInteger;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadWithStatements(const aCacheKey: string;
  const aConnection: TObject; const aUnit: TUnitSnapshot);
var
  lExpectedId: TSemanticWithId;
  lQuery: TFDQuery;
  lWith: TSemanticWithStatementFact;
  lWithId: TSemanticWithId;
begin
  lExpectedId := 1;
  lQuery := NewQuery(TFDConnection(aConnection), 'select with_id, routine_id, ' +
    'selector_start_line, selector_start_column, body_start_line, body_start_column, ' +
    'body_end_line, body_end_column, flags from snapshot_with_statements where cache_key = ? ' +
    'order by with_id');
  try
    lQuery.Params[0].AsString := aCacheKey;
    lQuery.Open;
    while not lQuery.Eof do
    begin
      if TSemanticWithId(lQuery.FieldByName('with_id').AsInteger) <> lExpectedId then
        raise Exception.Create('Snapshot with IDs are not dense.');

      lWith := Default(TSemanticWithStatementFact);
      lWith.RoutineId := TSemanticStringId(lQuery.FieldByName('routine_id').AsInteger);
      lWith.SelectorStartLine := lQuery.FieldByName('selector_start_line').AsInteger;
      lWith.SelectorStartColumn := lQuery.FieldByName('selector_start_column').AsInteger;
      lWith.BodyStartLine := lQuery.FieldByName('body_start_line').AsInteger;
      lWith.BodyStartColumn := lQuery.FieldByName('body_start_column').AsInteger;
      lWith.BodyEndLine := lQuery.FieldByName('body_end_line').AsInteger;
      lWith.BodyEndColumn := lQuery.FieldByName('body_end_column').AsInteger;
      lWith.Flags := Cardinal(lQuery.FieldByName('flags').AsInteger);
      lWithId := aUnit.AddWithStatement(lWith);
      if lWithId <> lExpectedId then
        raise Exception.Create('Snapshot with ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.OpenConnection(out aConnection: TObject;
  out aDriverLink: TObject; out aError: string): Boolean;
var
  lConnection: TFDConnection;
  lDirectory: string;
  lDriverLink: TFDPhysSQLiteDriverLink;
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

procedure TDelphiSemanticSnapshotSqliteCache.RebuildSnapshotTables(const aConnection: TObject);
var
  lConnection: TFDConnection;
begin
  lConnection := TFDConnection(aConnection);
  lConnection.ExecSQL('drop table if exists snapshot_references');
  lConnection.ExecSQL('drop table if exists snapshot_with_statements');
  lConnection.ExecSQL('drop table if exists snapshot_symbols');
  lConnection.ExecSQL('drop table if exists snapshot_strings');
  lConnection.ExecSQL('drop table if exists snapshot_units');
  lConnection.ExecSQL('delete from meta where key_name = ?', [cSnapshotSchemaMetaKey]);
end;

function TDelphiSemanticSnapshotSqliteCache.SharedConnection(out aConnection: TObject;
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
    Inc(fMetrics.PersistentConnectionOpenCount);
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreReferences(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot);
var
  i: Integer;
  lConnection: TFDConnection;
  lReference: TSemanticReferenceFact;
begin
  lConnection := TFDConnection(aConnection);
  for i := 1 to aUnit.ReferenceCount do
  begin
    lReference := aUnit.ReferenceById(TSemanticReferenceId(i));
    lConnection.ExecSQL('insert into snapshot_references(cache_key, unit_id, reference_id, ' +
      'with_id, target_unit_id, target_symbol_id, name_id, receiver_type_id, type_id, ' +
      'classification_id, lookup_source_id, reason_id, line, column, end_line, end_column) ' +
      'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [aIdentity.CacheKey, Integer(aUnit.UnitId), i, Integer(lReference.WithId),
      Integer(lReference.TargetUnitId), Integer(lReference.TargetSymbolId),
      Integer(lReference.NameId), Integer(lReference.ReceiverTypeId),
      Integer(lReference.TypeId), Integer(lReference.ClassificationId),
      Integer(lReference.LookupSourceId), Integer(lReference.ReasonId), lReference.Line,
      lReference.Column, lReference.EndLine, lReference.EndColumn]);
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreStrings(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aStrings: TSemanticStringPool);
var
  i: Integer;
  lConnection: TFDConnection;
begin
  lConnection := TFDConnection(aConnection);
  for i := 1 to Integer(aStrings.Count) do
    lConnection.ExecSQL('insert into snapshot_strings(cache_key, string_id, text_value) ' +
      'values (?, ?, ?)', [aIdentity.CacheKey, i, aStrings.TextOf(TSemanticStringId(i))]);
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreSymbols(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot);
var
  i: Integer;
  lConnection: TFDConnection;
  lSymbol: TSemanticSymbolFact;
begin
  lConnection := TFDConnection(aConnection);
  for i := 1 to aUnit.SymbolCount do
  begin
    lSymbol := aUnit.SymbolById(TSemanticSymbolId(i));
    lConnection.ExecSQL('insert into snapshot_symbols(cache_key, unit_id, symbol_id, ' +
      'name_id, owner_type_id, type_id, routine_id, kind_id, flags, line, column, end_line, ' +
      'end_column) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [aIdentity.CacheKey, Integer(aUnit.UnitId), i, Integer(lSymbol.NameId),
      Integer(lSymbol.OwnerTypeId), Integer(lSymbol.TypeId), Integer(lSymbol.RoutineId),
      Integer(lSymbol.KindId), Integer(lSymbol.Flags), lSymbol.Line, lSymbol.Column,
      lSymbol.EndLine, lSymbol.EndColumn]);
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreUnit(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
begin
  if not Assigned(aStrings) then
    raise Exception.Create('Cannot store a unit snapshot without a string pool.');
  if not Assigned(aUnit) then
    raise Exception.Create('Cannot store a nil unit snapshot.');
  ValidateIdentityComplete(aIdentity, 'store');

  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);

  lConnection := TFDConnection(lConnectionObject);
  lConnection.StartTransaction;
  try
    DeleteIdentityRows(lConnection, aIdentity.IdentityKey);
    StoreUnitHeader(aIdentity, lConnection, aUnit, Integer(aStrings.Count));
    StoreStrings(aIdentity, lConnection, aStrings);
    StoreSymbols(aIdentity, lConnection, aUnit);
    StoreWithStatements(aIdentity, lConnection, aUnit);
    StoreReferences(aIdentity, lConnection, aUnit);
    lConnection.Commit;
  except
    lConnection.Rollback;
    raise;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreUnitHeader(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot; const aStringCount: Integer);
begin
  TFDConnection(aConnection).ExecSQL('insert into snapshot_units(cache_key, identity_key, ' +
    'source_file_name, file_hash, context_hash, include_graph_hash, schema_version, ' +
    'stored_at_utc, unit_id, file_name_id, unit_name_id, string_count, symbol_count, ' +
    'with_statement_count, reference_count) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [aIdentity.CacheKey, aIdentity.IdentityKey, aIdentity.SourceFileName, aIdentity.FileHash,
    aIdentity.ContextHash, aIdentity.IncludeGraphHash, aIdentity.SchemaVersion,
    SnapshotUtcTimestamp, Integer(aUnit.UnitId), Integer(aUnit.FileNameId),
    Integer(aUnit.UnitNameId), aStringCount, aUnit.SymbolCount, aUnit.WithStatementCount,
    aUnit.ReferenceCount]);
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreWithStatements(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot);
var
  i: Integer;
  lConnection: TFDConnection;
  lWith: TSemanticWithStatementFact;
begin
  lConnection := TFDConnection(aConnection);
  for i := 1 to aUnit.WithStatementCount do
  begin
    lWith := aUnit.WithStatementById(TSemanticWithId(i));
    lConnection.ExecSQL('insert into snapshot_with_statements(cache_key, unit_id, with_id, ' +
      'routine_id, selector_start_line, selector_start_column, body_start_line, ' +
      'body_start_column, body_end_line, body_end_column, flags) ' +
      'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [aIdentity.CacheKey, Integer(aUnit.UnitId), i, Integer(lWith.RoutineId),
      lWith.SelectorStartLine, lWith.SelectorStartColumn, lWith.BodyStartLine,
      lWith.BodyStartColumn, lWith.BodyEndLine, lWith.BodyEndColumn, Integer(lWith.Flags)]);
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.TryLoadUnit(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  out aSnapshot: TDelphiProjectSnapshot): Boolean;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lConnectionObject: TObject;
  lError: string;
  lReferenceCount: Integer;
  lStringCount: Integer;
  lSymbolCount: Integer;
  lUnit: TUnitSnapshot;
  lWithStatementCount: Integer;
begin
  Result := False;
  aSnapshot := nil;
  lUnit := nil;
  ValidateIdentityComplete(aIdentity, 'load');
  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);

  if not IdentityMatches(aIdentity, lConnectionObject) then
  begin
    if EntryExistsForIdentity(aIdentity.IdentityKey) then
    begin
      Inc(fMetrics.Invalidations);
      DeleteIdentity(aIdentity.IdentityKey);
    end;
    Inc(fMetrics.CacheMisses);
    Exit;
  end;

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    try
      LoadStrings(aIdentity.CacheKey, lConnectionObject, lBuilder.Strings);
      if not LoadUnitHeader(aIdentity, lConnectionObject, lUnit, lStringCount, lSymbolCount,
        lWithStatementCount, lReferenceCount) then
        raise Exception.Create('Snapshot unit header disappeared during load.');
      LoadSymbols(aIdentity.CacheKey, lConnectionObject, lUnit);
      LoadWithStatements(aIdentity.CacheKey, lConnectionObject, lUnit);
      LoadReferences(aIdentity.CacheKey, lConnectionObject, lUnit);
      ValidateLoadedCounts(lBuilder.Strings, lUnit, lStringCount, lSymbolCount,
        lWithStatementCount, lReferenceCount);
      ValidateUnitStringIds(lBuilder.Strings, lUnit);
      lBuilder.AddUnit(lUnit);
      lUnit := nil;
      aSnapshot := lBuilder.Build;
      Inc(fMetrics.CacheHits);
      Result := True;
    except
      on E: Exception do
      begin
        lUnit.Free;
        DeleteIdentity(aIdentity.IdentityKey);
        Inc(fMetrics.Invalidations);
        Inc(fMetrics.CacheMisses);
        Result := False;
      end;
    end;
  finally
    lBuilder.Free;
  end;
end;

end.
