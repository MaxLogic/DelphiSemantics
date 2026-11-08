unit DelphiSemantics.Snapshot.Cache.Sqlite;

interface

uses
  System.SysUtils,
  DelphiSemantics.Model, DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.TargetIdentity, DelphiSemantics.WithBinding;

const
  cCombinedFactsPayloadMaxCharacters = 128 * 1024 * 1024;

{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
type
  TCombinedFactsBeforeStoreForTest = reference to procedure;
var
  CombinedFactsBeforeStoreForTest: TCombinedFactsBeforeStoreForTest;
threadvar
  CombinedFactsPayloadMaxCharactersForTest: Integer;
  SnapshotSqliteNativeBusyTimeoutForTest: Integer;
  SnapshotSqliteBusyRetryBudgetForTest: Integer;
{$ENDIF}

type
  ECombinedFactsCachePublication = class(EInvalidOpException);
  TDelphiSemanticSnapshotCacheIdentity = record
    CacheKey: string;
    IdentityKey: string;
    SourceFileName: string;
    FileHash: string;
    ContextHash: string;
    IncludeGraphHash: string;
    SchemaVersion: string;
    ParseAvoidedEstimateMilliseconds: Int64;
  end;

  TDelphiSemanticSnapshotCacheMetrics = record
    CacheHits: Integer;
    CacheMisses: Integer;
    Invalidations: Integer;
    PersistentConnectionOpenCount: Integer;
    SnapshotCacheProbes: Integer;
    SnapshotSqlWriteMilliseconds: Int64;
    SnapshotSqlReadMilliseconds: Int64;
    SnapshotDeserializeMilliseconds: Int64;
    SnapshotIndexRebuildMilliseconds: Int64;
    SnapshotParseAvoidedEstimateMilliseconds: Int64;
    SnapshotCacheUseful: Boolean;
  end;

  TDelphiSemanticSnapshotSqliteCache = class
  private
    fCacheFileName: string;
    fLastInvalidationReason: string;
    fCombinedFactsStoreOutcome: string;
    fConnection: TObject;
    fDriverLink: TObject;
    fMetrics: TDelphiSemanticSnapshotCacheMetrics;
    fTargetIdentities: TSnapshotTargetIdentities;
    fUnitLoadBatch: TObject;
    fBatchReadMilliseconds: Int64;
    fLastBatchReadFallbackReason: string;
    function NewUnitReadQuery(const aConnection: TObject; const aCacheKey, aTable,
      aSql: string): TObject;
    procedure StorePhysicalEvidence(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot);
    procedure LoadPhysicalEvidence(const aCacheKey: string; const aConnection: TObject;
      const aStrings, aExactStrings: TSemanticStringPool; const aUnit: TUnitSnapshot);
    procedure StoreTargetIdentities(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot; const aIdentities: TSnapshotTargetIdentities);
    procedure LoadTargetIdentities(const aCacheKey: string; const aConnection: TObject;
      const aBuilder: TDelphiProjectSnapshotBuilder; const aUnit: TUnitSnapshot);
    procedure CloseSharedConnection;
    procedure DeleteCacheKey(const aCacheKey: string);
    procedure DeleteCacheKeyRows(const aConnection: TObject; const aCacheKey: string);
    procedure EnsureDatabase;
    procedure EnsureDatabaseOnce;
    function IdentityMatches(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; out aEntryBelongsToIdentity: Boolean): Boolean;
    procedure LoadExactStrings(const aCacheKey: string; const aConnection: TObject;
      const aExactStrings: TSemanticStringPool);
    function ProjectRemoveWithIdentityMatches(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; out aEntryBelongsToIdentity: Boolean): Boolean;
    procedure LoadReferences(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot);
    function LoadValueMemberEvidence(const aCacheKey: string; const aConnection: TObject):
      TDelphiSemanticValueMemberEvidence;
    procedure StoreValueMemberEvidence(const aCacheKey: string; const aConnection: TObject;
      const aEvidence: TDelphiSemanticValueMemberEvidence);
    procedure LoadRemoveWithPlanningFacts(const aCacheKey: string; const aConnection: TObject;
      const aBuilder: TDelphiProjectSnapshotBuilder);
    procedure LoadRemoveWithVisibility(const aCacheKey: string; const aConnection: TObject;
      const aBuilder: TDelphiProjectSnapshotBuilder);
    procedure LoadRemoveWithVisibilityCounts(const aCacheKey: string; const aConnection: TObject;
      out aUnitCount, aRowCount: Integer);
    procedure LoadStrings(const aCacheKey: string; const aConnection: TObject;
      const aStrings: TSemanticStringPool);
    procedure LoadSymbols(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot);
    function LoadUnitHeader(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; out aUnit: TUnitSnapshot; out aStringCount,
      aSymbolCount, aWithStatementCount, aReferenceCount: Integer;
      out aParseAvoidedEstimateMilliseconds: Int64): Boolean;
    procedure LoadWithStatements(const aCacheKey: string; const aConnection: TObject;
      const aUnit: TUnitSnapshot);
    function OpenConnection(out aConnection: TObject; out aDriverLink: TObject;
      out aError: string): Boolean;
    procedure RebuildSnapshotTables(const aConnection: TObject);
    procedure ResetProbeMetrics;
    function SharedConnection(out aConnection: TObject; out aError: string): Boolean;
    procedure StoreExactStringPool(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aExactStrings: TSemanticStringPool;
      const aUnit: TUnitSnapshot = nil);
    procedure StoreRemoveWithVisibility(const aCacheKey: string; const aConnection: TObject;
      const aSnapshot: TDelphiProjectSnapshot);
    procedure StoreReferences(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot);
    procedure StoreRemoveWithPlanningFacts(
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
      const aSnapshot: TDelphiProjectSnapshot; const aExactStrings: TSemanticStringPool;
      const aLookupSymbols: TArray<TDelphiSemanticInventorySymbol>);
    procedure StoreStrings(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aStrings: TSemanticStringPool);
    procedure StoreSymbols(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot);
    procedure StoreUnitHeader(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot; const aStringCount, aExactStringCount: Integer);
    procedure StoreUnitFromProjectSnapshot(
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aSnapshot: TDelphiProjectSnapshot; const aUnit: TUnitSnapshot);
    procedure StoreUnitWithExactStrings(
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aStrings, aExactStrings: TSemanticStringPool; const aUnit: TUnitSnapshot;
      const aIdentities: TSnapshotTargetIdentities = nil);
    procedure StoreWithStatements(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aConnection: TObject; const aUnit: TUnitSnapshot);
  public
    constructor Create(const aCacheFileName: string);
    function TryLoadCombinedFactsPayload(const aIdentity: string; out aPayload: string;
      out aInvalid: Boolean): Boolean;
    procedure StoreCombinedFactsPayload(const aIdentity, aPayload: string);
    procedure DeleteCombinedFactsPayload(const aIdentity: string);
    destructor Destroy; override;
    procedure StoreUnit(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aStrings: TSemanticStringPool; const aUnit: TUnitSnapshot;
      const aSnapshot: TDelphiProjectSnapshot = nil);
    procedure StoreUnitFromSnapshot(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aSnapshot: TDelphiProjectSnapshot; const aUnitIndex: Integer);
    procedure StoreProjectRemoveWithPlanningFacts(
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aSnapshot: TDelphiProjectSnapshot); overload;
    procedure StoreProjectRemoveWithPlanningFacts(
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      const aSnapshot: TDelphiProjectSnapshot;
      const aLookupSymbols: TArray<TDelphiSemanticInventorySymbol>); overload;
    function TryLoadProjectRemoveWithPlanningFacts(
      const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      out aSnapshot: TDelphiProjectSnapshot): Boolean;
    procedure BeginUnitLoadBatch(const aIdentities: TArray<TDelphiSemanticSnapshotCacheIdentity>);
    procedure EndUnitLoadBatch;
    function TryLoadUnit(const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
      out aSnapshot: TDelphiProjectSnapshot): Boolean;
    property CombinedFactsStoreOutcome: string read fCombinedFactsStoreOutcome;
    property LastInvalidationReason: string read fLastInvalidationReason;
    property LastBatchReadFallbackReason: string read fLastBatchReadFallbackReason;
    property Metrics: TDelphiSemanticSnapshotCacheMetrics read fMetrics;
  end;

implementation

uses
  System.Classes, System.DateUtils, System.Diagnostics, System.Generics.Collections, System.Generics.Defaults,
  System.Hash, System.IOUtils,
  Winapi.Windows,
  Data.DB,
  FireDAC.Comp.Client, FireDAC.Comp.DataSet, FireDAC.DApt, FireDAC.Phys.SQLite, FireDAC.Stan.Async,
  FireDAC.Stan.Def, FireDAC.Stan.Intf,
  DelphiSemantics.Cache, DelphiSemantics.RemoveWith.Visibility,
  DelphiSemantics.Resolve.TypeResolver,
  DelphiSemantics.Snapshot.Evidence, DelphiSemantics.Snapshot.RemoveWith;

const
  // 11: DS-659 file_id; 12: include facts; 13: receiver identities;
  // 14: expected identity row count for complete project planning facts.
  // 25: lexical routine owners exclude header twins (DS-743/DS-763).
  // 25: DS-737/739 invalidate planning facts with unsafe conditional WITH ranges.
  // 26: DS-736/707 retain helper and receiver declaration identity.
  // 29: integrated lane identities invalidate every merged schema generation.
  // 31: DS-655 retains implementation owner type references.
  // 32: DS-762 refuses package-dependent unit-name absence evidence.
  // 33: integrate package witnesses, AST headings and implementation references.
  // 34: integrate DS-650/662/656 extraction with all previous schema identities.
  cSnapshotCacheSchemaVersion = '60';
  cSnapshotSchemaMetaKey = 'snapshot_schema_version';
  cSnapshotSqliteBusyTimeoutMs = 30000;
  cSnapshotSqliteBusyRetryDelayMs = 50;
  cSnapshotSqliteJournalMode = 'WAL';
  cSnapshotSqliteLockingMode = 'Normal';

type
  TSnapshotIntegerField = class(TIntegerField);
  TSnapshotLargeintField = class(TLargeintField);
  TSnapshotIntegerReader = record
    fField: TField;
    fNativeInteger: TSnapshotIntegerField;
    fNativeLargeint: TSnapshotLargeintField;
    class function Bind(const aField: TField): TSnapshotIntegerReader; static;
    function Read(const aMinimum, aMaximum: Int64): Int64;
  end;

  // Raw rows live only for this explicit read transaction. Each unit keeps its
  // own pools and executes the ordinary validators before publishing any row.
  TSnapshotUnitLoadBatch = class
  private
    fTables: TObjectDictionary<string, TFDQuery>;
    fSlots: TDictionary<string, Integer>;
    fRejected: TDictionary<string, Byte>;
    procedure AddQuery(const aConnection: TFDConnection; const aTable, aColumns,
      aOrder, aJoin: string);
  public
    constructor Create(const aConnection: TFDConnection;
      const aIdentities: TArray<TDelphiSemanticSnapshotCacheIdentity>);
    destructor Destroy; override;
    function UnitRows(const aTable, aKey: string): TFDDataSet;
    procedure Reject(const aKey: string);
    function RejectedKeys: TArray<string>;
  end;

function PhysicalSnapshotCachePath(const aPath: string): string;
begin
  Result := aPath;
  if (Length(Result) < MAX_PATH) or not TPath.IsPathRooted(Result) or
    TPath.IsExtendedPrefixed(Result) then
    Exit;
  Result := TPath.GetFullPath(Result);
  if Result.StartsWith('\\') then
    Result := '\\?\UNC\' + Copy(Result, 3, MaxInt)
  else
    Result := '\\?\' + Result;
end;

function SameCanonicalIdentityPath(const aLeft, aRight: string): Boolean;
begin
  Result := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aLeft) =
    TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aRight);
end;

procedure ConfigureSnapshotSqliteConnection(const aConnection: TFDConnection;
  const aDatabase: string);
begin
  aConnection.LoginPrompt := False;
  aConnection.Params.Values['DriverID'] := 'SQLite';
  aConnection.Params.Values['Database'] := aDatabase;
  aConnection.Params.Values['BusyTimeout'] := IntToStr(cSnapshotSqliteBusyTimeoutMs);
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  if SnapshotSqliteNativeBusyTimeoutForTest > 0 then
    aConnection.Params.Values['BusyTimeout'] := IntToStr(SnapshotSqliteNativeBusyTimeoutForTest);
{$ENDIF}
  aConnection.Params.Values['JournalMode'] := cSnapshotSqliteJournalMode;
  aConnection.Params.Values['LockingMode'] := cSnapshotSqliteLockingMode;
end;

function SnapshotSqliteBusyError(const aMessage: string): Boolean;
var
  lMessage: string;
begin
  lMessage := LowerCase(aMessage);
  Result := (Pos('database is locked', lMessage) > 0) or
    (Pos('database table is locked', lMessage) > 0) or
    (Pos('database is busy', lMessage) > 0);
end;

function RetrySnapshotSqliteBusy(const aMessage: string;
  const aStopwatch: TStopwatch): Boolean;
var
  lBudget: Integer;
begin
  lBudget := cSnapshotSqliteBusyTimeoutMs;
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  if SnapshotSqliteBusyRetryBudgetForTest > 0 then
    lBudget := SnapshotSqliteBusyRetryBudgetForTest;
{$ENDIF}
  Result := SnapshotSqliteBusyError(aMessage) and
    (aStopwatch.ElapsedMilliseconds < lBudget);
  if Result then
    TThread.Sleep(cSnapshotSqliteBusyRetryDelayMs);
end;

function NewQuery(const aConnection: TFDConnection; const aSql: string): TFDQuery;
begin
  Result := TFDQuery.Create(nil);
  Result.Connection := aConnection;
  // SQLite INTEGER stores signed 64-bit values. Keep their full width before
  // range validation; the default dtInt32 mapping can silently wrap an ID.
  Result.FormatOptions.OwnMapRules := True;
  Result.FormatOptions.MapRules.Add(dtInt32, dtInt64);
  Result.SQL.Text := aSql;
end;

function CheckedCacheInteger(const aField: TField; const aMinimum, aMaximum: Int64): Int64;
begin
  if aField.IsNull then
    raise EInvalidOpException.Create('SNAPSHOT_INTEGER_NULL:' + aField.FieldName);
  Result := aField.AsLargeInt;
  if (Result < aMinimum) or (Result > aMaximum) then
    raise EInvalidOpException.Create('SNAPSHOT_INTEGER_RANGE:' + aField.FieldName);
end;

class function TSnapshotIntegerReader.Bind(const aField: TField): TSnapshotIntegerReader;
begin
  Result := Default(TSnapshotIntegerReader);
  Result.fField := aField;
  if aField is TIntegerField then
    Result.fNativeInteger := TSnapshotIntegerField(aField)
  else if aField is TLargeintField then
    Result.fNativeLargeint := TSnapshotLargeintField(aField);
end;

function TSnapshotIntegerReader.Read(const aMinimum, aMaximum: Int64): Int64;
var
  lInteger: Integer;
begin
  if fNativeInteger <> nil then
  begin
    if not fNativeInteger.GetValue(lInteger) then
      raise EInvalidOpException.Create('SNAPSHOT_INTEGER_NULL:' + fField.FieldName);
    Result := lInteger;
  end else if fNativeLargeint <> nil then
  begin
    if not fNativeLargeint.GetValue(Result) then
      raise EInvalidOpException.Create('SNAPSHOT_INTEGER_NULL:' + fField.FieldName);
  end else begin
    if fField.IsNull then
      raise EInvalidOpException.Create('SNAPSHOT_INTEGER_NULL:' + fField.FieldName);
    Result := fField.AsLargeInt;
  end;
  if (Result < aMinimum) or (Result > aMaximum) then
    raise EInvalidOpException.Create('SNAPSHOT_INTEGER_RANGE:' + fField.FieldName);
end;

function SnapshotSourceHash(const aText: string): string;
begin
  if not IsWellFormedEvidenceText(aText) then
    raise EInvalidOpException.Create('SNAPSHOT_SHARED_TEXT_UTF16_INVALID');
  Result := LowerCase(THashSHA2.GetHashString(aText));
end;

function ValidSnapshotSourceHash(const aHash: string): Boolean;
var
  c: Char;
begin
  Result := Length(aHash) = 64;
  if not Result then
    Exit;
  for c in aHash do
    if not CharInSet(c, ['0'..'9', 'a'..'f']) then
      Exit(False);
end;

procedure CollectSnapshotSourceOrphans(const aConnection: TFDConnection);
begin
  aConnection.ExecSQL('delete from snapshot_source_texts where not exists ' +
    '(select 1 from snapshot_exact_strings where source_content_hash = snapshot_source_texts.content_hash)');
end;

function SnapshotEvidenceLayoutValid(const aConnection: TFDConnection): Boolean;
var
  lQuery: TFDQuery;
begin
  // Probe the physical layout as well as metadata. This rejects the DS-794
  // intermediate v71/36 generation and metadata-only upgrades of old caches.
  lQuery := NewQuery(aConnection, 'select u.physical_reference_available, u.physical_symbol_available, ' +
    'u.captured_sources_available, u.visible_unit_names_available, u.has_includes, ' +
    'u.physical_reference_count, u.physical_symbol_count, u.captured_source_count, u.visible_unit_count, ' +
    'u.exact_string_count, e.source_content_hash, s.content_hash, s.text, c.source_ordinal, c.file_id, ' +
    'c.text_id, c.status, o.collection, o.payload, v.import_ordinal, v.unit_name_id ' +
    'from snapshot_units u, snapshot_exact_strings e, snapshot_source_texts s, ' +
    'snapshot_captured_sources c, snapshot_unit_occurrences o, snapshot_visible_units v where 0');
  try
    try
      lQuery.Open;
      Result := True;
    except
      on E: Exception do
      begin
        if SnapshotSqliteBusyError(E.Message) then
          raise;
        Result := False;
      end;
    end;
  finally
    lQuery.Free;
  end;
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

function QueryWideString(const aConnection: TFDConnection; const aSql, aValue: string): string;
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

function SnapshotUtcTimestamp: string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"',
    TTimeZone.Local.ToUniversalTime(Now));
end;

function VisibleElapsedMilliseconds(const aStopwatch: TStopwatch): Int64;
begin
  Result := aStopwatch.ElapsedMilliseconds;
  if Result <= 0 then
    Result := 1;
end;

procedure CacheQueryFields(const aQuery: TFDQuery; var aFields: TArray<TField>);
var
  i: Integer;
begin
  SetLength(aFields, aQuery.FieldCount);
  for i := 0 to aQuery.FieldCount - 1 do
    aFields[i] := aQuery.Fields[i];
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

procedure ValidateStringId(const aStrings: TSemanticStringPool; const id: TSemanticStringId;
  const aFieldName: string);
begin
  if id = 0 then
    Exit;

  if id > aStrings.Count then
    raise Exception.Create('Snapshot string ID outside string pool: ' + aFieldName);
  if aStrings.TextOf(id) = '' then
    raise Exception.Create('Snapshot string ID resolves to empty text: ' + aFieldName);
end;

function LoadedTypeIdentity(const aExactStrings: TSemanticStringPool;
  const aFact: TSemanticRemoveWithTypeIdentityFact): TDelphiSemanticTypeIdentity;
begin
  Result := Default(TDelphiSemanticTypeIdentity);
  if aFact.DeclaredIdId = 0 then
    Exit;
  Result.UnitId.Value := aExactStrings.TextOf(aFact.UnitIdId);
  Result.UnitName := aExactStrings.TextOf(aFact.UnitNameId);
  Result.Name := aExactStrings.TextOf(aFact.NameId);
  Result.Kind := aExactStrings.TextOf(aFact.KindId);
  Result.DeclaredId.Value := aExactStrings.TextOf(aFact.DeclaredIdId);
  Result.CanonicalId.Value := aExactStrings.TextOf(aFact.CanonicalIdId);
  Result.UnderlyingId.Value := aExactStrings.TextOf(aFact.UnderlyingIdId);
  Result.CanonicalName := aExactStrings.TextOf(aFact.CanonicalNameId);
  Result.UnderlyingName := aExactStrings.TextOf(aFact.UnderlyingNameId);
  Result.BaseTypeName := aExactStrings.TextOf(aFact.BaseTypeNameId);
  Result.HelperTargetName := aExactStrings.TextOf(aFact.HelperTargetNameId);
  Result.SectionKind := aExactStrings.TextOf(aFact.SectionKindId);
  Result.ScopeKind := aExactStrings.TextOf(aFact.ScopeKindId);
  Result.OwnerScopeId := aExactStrings.TextOf(aFact.OwnerScopeIdId);
  Result.SemanticSymbolId := aExactStrings.TextOf(aFact.SemanticSymbolIdId);
  Result.SourceRange.FileName := aExactStrings.TextOf(aFact.FileNameId);
  Result.SourceRange.Line := aFact.Line;
  Result.SourceRange.Column := aFact.Column;
  Result.SourceRange.EndLine := aFact.EndLine;
  Result.SourceRange.EndColumn := aFact.EndColumn;
end;

function StoredTypeIdentity(const aExactStrings: TSemanticStringPool;
  const aIdentity: TDelphiSemanticTypeIdentity): TSemanticRemoveWithTypeIdentityFact;
begin
  Result := Default(TSemanticRemoveWithTypeIdentityFact);
  if SameText(aIdentity.ScopeKind, 'routine') and
    ((aIdentity.OwnerScopeId = '') or (aIdentity.SemanticSymbolId = '') or
      (aIdentity.CanonicalId.Value = '') or
      (aIdentity.UnderlyingId.Value = '')) then
    raise Exception.Create('Local type identity has incomplete declaring scope.');
  if (aIdentity.DeclaredId.Value = '') or
    (aIdentity.SourceRange.FileName = '') or
    (aIdentity.SourceRange.Line <= 0) then
    Exit;
  Result.UnitIdId := aExactStrings.Intern(aIdentity.UnitId.Value);
  Result.UnitNameId := aExactStrings.Intern(aIdentity.UnitName);
  Result.NameId := aExactStrings.Intern(aIdentity.Name);
  Result.KindId := aExactStrings.Intern(aIdentity.Kind);
  Result.DeclaredIdId := aExactStrings.Intern(aIdentity.DeclaredId.Value);
  Result.CanonicalIdId := aExactStrings.Intern(aIdentity.CanonicalId.Value);
  Result.UnderlyingIdId := aExactStrings.Intern(aIdentity.UnderlyingId.Value);
  Result.CanonicalNameId := aExactStrings.Intern(aIdentity.CanonicalName);
  Result.UnderlyingNameId := aExactStrings.Intern(aIdentity.UnderlyingName);
  Result.BaseTypeNameId := aExactStrings.Intern(aIdentity.BaseTypeName);
  Result.HelperTargetNameId := aExactStrings.Intern(aIdentity.HelperTargetName);
  Result.SectionKindId := aExactStrings.Intern(aIdentity.SectionKind);
  Result.ScopeKindId := aExactStrings.Intern(aIdentity.ScopeKind);
  Result.OwnerScopeIdId := aExactStrings.Intern(aIdentity.OwnerScopeId);
  Result.SemanticSymbolIdId := aExactStrings.Intern(aIdentity.SemanticSymbolId);
  Result.FileNameId := aExactStrings.Intern(aIdentity.SourceRange.FileName);
  Result.Line := aIdentity.SourceRange.Line;
  Result.Column := aIdentity.SourceRange.Column;
  Result.EndLine := aIdentity.SourceRange.EndLine;
  Result.EndColumn := aIdentity.SourceRange.EndColumn;
end;

function LoadedInventorySymbol(const aExactStrings: TSemanticStringPool;
  const aSymbol: TSemanticRemoveWithInventorySymbolFact): TDelphiSemanticInventorySymbol;
begin
  Result := Default(TDelphiSemanticInventorySymbol);
  Result.Name := aExactStrings.TextOf(aSymbol.NameId);
  Result.SymbolClass := aExactStrings.TextOf(aSymbol.SymbolClassId);
  Result.Kind := aExactStrings.TextOf(aSymbol.KindId);
  Result.TypeName := aExactStrings.TextOf(aSymbol.TypeNameId);
  Result.Modifier := aExactStrings.TextOf(aSymbol.ModifierId);
  Result.OwnerName := aExactStrings.TextOf(aSymbol.OwnerNameId);
  Result.OwnerType := aExactStrings.TextOf(aSymbol.OwnerTypeId);
  Result.SourceOwnerType := aExactStrings.TextOf(aSymbol.SourceOwnerTypeId);
  Result.RelatedTypeName := aExactStrings.TextOf(aSymbol.RelatedTypeNameId);
  Result.RoutineName := aExactStrings.TextOf(aSymbol.RoutineNameId);
  Result.RoutineScopeId := aExactStrings.TextOf(aSymbol.RoutineScopeIdId);
  Result.ParentScopeId := aExactStrings.TextOf(aSymbol.ParentScopeIdId);
  Result.OwnerScopeId := aExactStrings.TextOf(aSymbol.OwnerScopeIdId);
  Result.OwnerSymbolId := aExactStrings.TextOf(aSymbol.OwnerSymbolIdId);
  Result.UnitName := aExactStrings.TextOf(aSymbol.UnitNameId);
  Result.FileName := aExactStrings.TextOf(aSymbol.FileNameId);
  Result.SectionKind := aExactStrings.TextOf(aSymbol.SectionKindId);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.HeadingLine := aSymbol.HeadingLine;
  Result.HeadingColumn := aSymbol.HeadingColumn;
  Result.HeadingEndLine := aSymbol.HeadingEndLine;
  Result.HeadingEndColumn := aSymbol.HeadingEndColumn;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReason := aExactStrings.TextOf(aSymbol.UnsupportedReasonId);
  Result.IsHelper := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsHelper) <> 0;
  Result.IsOverride := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsOverride) <> 0;
  Result.IsDefault := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsDefault) <> 0;
  Result.IsIndexed := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsIndexed) <> 0;
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategory := aExactStrings.TextOf(aSymbol.TypeCategoryId);
  Result.OwnerIdentity := LoadedTypeIdentity(aExactStrings, aSymbol.OwnerIdentity);
  Result.AccessOwnerIdentity := LoadedTypeIdentity(aExactStrings,
    aSymbol.AccessOwnerIdentity);
  Result.AccessOwnerUnitName := aExactStrings.TextOf(aSymbol.AccessOwnerUnitNameId);
  Result.AccessOwnerFileName := aExactStrings.TextOf(aSymbol.AccessOwnerFileNameId);
  Result.AccessOwnerSectionKind := aExactStrings.TextOf(aSymbol.AccessOwnerSectionKindId);
  Result.AccessOwnerLine := aSymbol.AccessOwnerLine;
  Result.AccessOwnerColumn := aSymbol.AccessOwnerColumn;
end;

function LoadedInventorySymbols(const aExactStrings: TSemanticStringPool;
  const aSymbols: TArray<TSemanticRemoveWithInventorySymbolFact>):
  TArray<TDelphiSemanticInventorySymbol>;
var
  i: Integer;
begin
  SetLength(Result, Length(aSymbols));
  for i := 0 to High(aSymbols) do
    Result[i] := LoadedInventorySymbol(aExactStrings, aSymbols[i]);
end;

function StoredInventorySymbol(const aExactStrings: TSemanticStringPool;
  const aSymbol: TDelphiSemanticInventorySymbol): TSemanticRemoveWithInventorySymbolFact;
begin
  Result := Default(TSemanticRemoveWithInventorySymbolFact);
  Result.NameId := aExactStrings.Intern(aSymbol.Name);
  Result.SymbolClassId := aExactStrings.Intern(aSymbol.SymbolClass);
  Result.KindId := aExactStrings.Intern(aSymbol.Kind);
  Result.TypeNameId := aExactStrings.Intern(aSymbol.TypeName);
  Result.ModifierId := aExactStrings.Intern(aSymbol.Modifier);
  Result.OwnerNameId := aExactStrings.Intern(aSymbol.OwnerName);
  Result.OwnerTypeId := aExactStrings.Intern(aSymbol.OwnerType);
  Result.SourceOwnerTypeId := aExactStrings.Intern(aSymbol.SourceOwnerType);
  Result.RelatedTypeNameId := aExactStrings.Intern(aSymbol.RelatedTypeName);
  Result.RoutineNameId := aExactStrings.Intern(aSymbol.RoutineName);
  Result.RoutineScopeIdId := aExactStrings.Intern(aSymbol.RoutineScopeId);
  Result.ParentScopeIdId := aExactStrings.Intern(aSymbol.ParentScopeId);
  Result.OwnerScopeIdId := aExactStrings.Intern(aSymbol.OwnerScopeId);
  Result.OwnerSymbolIdId := aExactStrings.Intern(aSymbol.OwnerSymbolId);
  Result.UnitNameId := aExactStrings.Intern(aSymbol.UnitName);
  Result.FileNameId := aExactStrings.Intern(aSymbol.FileName);
  Result.SectionKindId := aExactStrings.Intern(aSymbol.SectionKind);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.HeadingLine := aSymbol.HeadingLine;
  Result.HeadingColumn := aSymbol.HeadingColumn;
  Result.HeadingEndLine := aSymbol.HeadingEndLine;
  Result.HeadingEndColumn := aSymbol.HeadingEndColumn;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReasonId := aExactStrings.Intern(aSymbol.UnsupportedReason);
  if aSymbol.IsHelper then
    Result.Flags := Result.Flags or cSemanticRemoveWithSymbolFlagIsHelper;
  if aSymbol.IsOverride then
    Result.Flags := Result.Flags or cSemanticRemoveWithSymbolFlagIsOverride;
  if aSymbol.IsDefault then
    Result.Flags := Result.Flags or cSemanticRemoveWithSymbolFlagIsDefault;
  if aSymbol.IsIndexed then
    Result.Flags := Result.Flags or cSemanticRemoveWithSymbolFlagIsIndexed;
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategoryId := aExactStrings.Intern(aSymbol.TypeCategory);
  Result.OwnerIdentity := StoredTypeIdentity(aExactStrings, aSymbol.OwnerIdentity);
  Result.AccessOwnerIdentity := StoredTypeIdentity(aExactStrings,
    aSymbol.AccessOwnerIdentity);
  Result.AccessOwnerUnitNameId := aExactStrings.Intern(aSymbol.AccessOwnerUnitName);
  Result.AccessOwnerFileNameId := aExactStrings.Intern(aSymbol.AccessOwnerFileName);
  Result.AccessOwnerSectionKindId := aExactStrings.Intern(aSymbol.AccessOwnerSectionKind);
  Result.AccessOwnerLine := aSymbol.AccessOwnerLine;
  Result.AccessOwnerColumn := aSymbol.AccessOwnerColumn;
end;

function StoredInventorySymbols(const aExactStrings: TSemanticStringPool;
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>):
  TArray<TSemanticRemoveWithInventorySymbolFact>;
var
  i: Integer;
begin
  SetLength(Result, Length(aSymbols));
  for i := 0 to High(aSymbols) do
    Result[i] := StoredInventorySymbol(aExactStrings, aSymbols[i]);
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
  ValidateStringId(aStrings, aUnit.ScopeModelStatusId,
    'scope_model_status_id');
  ValidateStringId(aStrings, aUnit.ScopeModelVersionId,
    'scope_model_version_id');
  ValidateStringId(aStrings, aUnit.ScopeDiagnosticId,
    'scope_diagnostic_id');

  for i := 1 to aUnit.SymbolCount do
  begin
    lSymbol := aUnit.SymbolById(TSemanticSymbolId(i));
    ValidateStringId(aStrings, lSymbol.NameId, 'symbol.name_id');
    ValidateStringId(aStrings, lSymbol.OwnerTypeId, 'symbol.owner_type_id');
    ValidateStringId(aStrings, lSymbol.TypeId, 'symbol.type_id');
    ValidateStringId(aStrings, lSymbol.RoutineId, 'symbol.routine_id');
    ValidateStringId(aStrings, lSymbol.KindId, 'symbol.kind_id');
    ValidateStringId(aStrings, lSymbol.SectionKindId, 'symbol.section_kind_id');
    ValidateStringId(aStrings, lSymbol.SourceKindId, 'symbol.source_kind_id');
    ValidateStringId(aStrings, lSymbol.VisibilityId, 'symbol.visibility_id');
    ValidateStringId(aStrings, lSymbol.SignatureId, 'symbol.signature_id');
    ValidateStringId(aStrings, lSymbol.DeclarationRoleId,
      'symbol.declaration_role_id');
    ValidateStringId(aStrings, lSymbol.ScopeKindId, 'symbol.scope_kind_id');
    ValidateStringId(aStrings, lSymbol.OwnerScopeId,
      'symbol.owner_scope_id');
    ValidateStringId(aStrings, lSymbol.SemanticSymbolId,
      'symbol.semantic_symbol_id');
    ValidateStringId(aStrings, lSymbol.RoutineScopeId,
      'symbol.routine_scope_id');
    ValidateStringId(aStrings, lSymbol.FileId, 'symbol.file_id');
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
    ValidateStringId(aStrings, lReference.RoutineId, 'reference.routine_id');
    ValidateStringId(aStrings, lReference.SectionKindId, 'reference.section_kind_id');
    ValidateStringId(aStrings, lReference.SourceKindId, 'reference.source_kind_id');
    ValidateStringId(aStrings, lReference.RoutineScopeId,
      'reference.routine_scope_id');
    ValidateStringId(aStrings, lReference.ClassificationId, 'reference.classification_id');
    ValidateStringId(aStrings, lReference.LookupSourceId, 'reference.lookup_source_id');
    ValidateStringId(aStrings, lReference.ReasonId, 'reference.reason_id');
    ValidateStringId(aStrings, lReference.FileId, 'reference.file_id');
  end;
end;

procedure ValidateUnitExactStringIds(const aExactStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot);
begin
  ValidateStringId(aExactStrings, aUnit.SourceTextId, 'source_text_id');
  ValidateStringId(aExactStrings, aUnit.VerifiedActiveSourceTextId, 'verified_active_source_text_id');
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

constructor TSnapshotUnitLoadBatch.Create(const aConnection: TFDConnection;
  const aIdentities: TArray<TDelphiSemanticSnapshotCacheIdentity>);
var
  i: Integer;
  lKeys: TList<string>;
  lQuery: TFDQuery;
begin
  inherited Create;
  fTables := TObjectDictionary<string, TFDQuery>.Create([doOwnsValues], TStringComparer.Ordinal);
  fSlots := TDictionary<string, Integer>.Create(Length(aIdentities), TStringComparer.Ordinal);
  fRejected := TDictionary<string, Byte>.Create(TStringComparer.Ordinal);
  lKeys := TList<string>.Create;
  try
    for i := 0 to High(aIdentities) do
      if not fSlots.ContainsKey(aIdentities[i].CacheKey) then
      begin
        fSlots.Add(aIdentities[i].CacheKey, -1);
        lKeys.Add(aIdentities[i].CacheKey);
      end;
    lKeys.Sort(TStringComparer.Ordinal);
    // This connection-local selector is never part of the persisted layout.
    aConnection.ExecSQL('create temp table if not exists snapshot_unit_load_keys (' +
      'cache_key text primary key, load_index integer not null)');
    aConnection.ExecSQL('delete from temp.snapshot_unit_load_keys');
    lQuery := NewQuery(aConnection,
      'insert into temp.snapshot_unit_load_keys(cache_key,load_index) values (?,?)');
    try
      lQuery.Params[0].DataType := ftWideString;
      lQuery.Params[1].DataType := ftInteger;
      lQuery.Prepare;
      for i := 0 to lKeys.Count - 1 do
      begin
        fSlots[lKeys[i]] := i;
        lQuery.Params[0].AsWideString := lKeys[i];
        lQuery.Params[1].AsInteger := i;
        lQuery.ExecSQL;
      end;
    finally
      lQuery.Free;
    end;
  finally
    lKeys.Free;
  end;
  AddQuery(aConnection, 'snapshot_units',
    't.unit_id,t.file_name_id,t.unit_name_id,t.source_text_id,t.scope_model_status_id,' +
    't.scope_model_version_id,t.scope_diagnostic_id,t.rejected_declaration_count,' +
    't.string_count,t.symbol_count,t.with_statement_count,t.reference_count,' +
    't.parse_avoided_estimate_ms,t.verified_active_source_text_id,' +
    't.identity_key,t.source_file_name,t.file_hash,t.context_hash,t.include_graph_hash,t.schema_version,' +
    't.physical_reference_available,t.physical_symbol_available,t.captured_sources_available,' +
    't.visible_unit_names_available,t.has_includes,t.physical_reference_count,' +
    't.physical_symbol_count,t.captured_source_count,t.visible_unit_count,t.exact_string_count', '', '');
  AddQuery(aConnection, 'snapshot_exact_strings',
    't.string_id,t.text_value,t.source_content_hash,s.text', 'string_id',
    ' left join snapshot_source_texts s on s.content_hash=t.source_content_hash');
  AddQuery(aConnection, 'snapshot_captured_sources',
    't.unit_id,t.source_ordinal,t.file_id,t.text_id,t.status', 'source_ordinal', '');
  AddQuery(aConnection, 'snapshot_visible_units',
    't.unit_id,t.import_ordinal,t.unit_name_id', 'import_ordinal', '');
  AddQuery(aConnection, 'snapshot_unit_occurrences',
    't.unit_id,t.collection,t.payload', 'collection', '');
  AddQuery(aConnection, 'snapshot_target_lineage',
    't.unit_id,t.value_count,t.payload', '', '');
end;

destructor TSnapshotUnitLoadBatch.Destroy;
begin
  fTables.Free;
  fSlots.Free;
  fRejected.Free;
  inherited;
end;

procedure TSnapshotUnitLoadBatch.AddQuery(const aConnection: TFDConnection;
  const aTable, aColumns, aOrder, aJoin: string);
var
  lQuery: TFDQuery;
  lOrder: string;
begin
  lOrder := 'k.load_index';
  if aOrder <> '' then
    lOrder := lOrder + ',t.' + aOrder;
  lQuery := NewQuery(aConnection, 'select ' + aColumns + ',k.load_index from ' + aTable +
    ' t inner join temp.snapshot_unit_load_keys k on k.cache_key=t.cache_key' + aJoin +
    ' order by ' + lOrder);
  try
    lQuery.FormatOptions.StrsTrim := False;
    lQuery.Open;
    lQuery.FetchAll;
    lQuery.IndexFieldNames := 'load_index';
    if aOrder <> '' then
      lQuery.IndexFieldNames := 'load_index;' + aOrder;
    fTables.Add(aTable, lQuery);
    lQuery := nil;
  finally
    lQuery.Free;
  end;
end;

function TSnapshotUnitLoadBatch.UnitRows(const aTable, aKey: string): TFDDataSet;
var
  lSlot: Integer;
  lRows: TFDMemTable;
begin
  if not fSlots.TryGetValue(aKey, lSlot) then
    raise EInvalidOpException.Create('SNAPSHOT_BATCH_KEY_NOT_SELECTED');
  if fRejected.ContainsKey(aKey) then
    lSlot := -1;
  lRows := TFDMemTable.Create(nil);
  try
    lRows.CloneCursor(fTables[aTable], False, False);
    lRows.SetRange([lSlot], [lSlot]);
    Result := lRows;
  except
    lRows.Free;
    raise;
  end;
end;

procedure TSnapshotUnitLoadBatch.Reject(const aKey: string);
begin
  fRejected.AddOrSetValue(aKey, 0);
end;

function TSnapshotUnitLoadBatch.RejectedKeys: TArray<string>;
begin
  Result := fRejected.Keys.ToArray;
end;

function TDelphiSemanticSnapshotSqliteCache.NewUnitReadQuery(const aConnection: TObject;
  const aCacheKey, aTable, aSql: string): TObject;
begin
  if fUnitLoadBatch <> nil then
    Result := TSnapshotUnitLoadBatch(fUnitLoadBatch).UnitRows(aTable, aCacheKey)
  else
    Result := NewQuery(aConnection as TFDConnection, aSql);
end;

constructor TDelphiSemanticSnapshotSqliteCache.Create(const aCacheFileName: string);
begin
  inherited Create;
  fCacheFileName := aCacheFileName;
  EnsureDatabase;
end;

destructor TDelphiSemanticSnapshotSqliteCache.Destroy;
begin
  try
    EndUnitLoadBatch;
  finally
    fTargetIdentities.Free;
    CloseSharedConnection;
    inherited;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.CloseSharedConnection;
begin
  fConnection.Free;
  fConnection := nil;
  fDriverLink.Free;
  fDriverLink := nil;
end;

procedure TDelphiSemanticSnapshotSqliteCache.DeleteCacheKey(const aCacheKey: string);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lOwnsTransaction: Boolean;
begin
  if fUnitLoadBatch <> nil then
  begin
    TSnapshotUnitLoadBatch(fUnitLoadBatch).Reject(aCacheKey);
    Exit;
  end;
  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);
  lConnection := lConnectionObject as TFDConnection;
  lOwnsTransaction := not lConnection.InTransaction;
  if lOwnsTransaction then
    lConnection.StartTransaction;
  try
    DeleteCacheKeyRows(lConnection, aCacheKey);
    CollectSnapshotSourceOrphans(lConnection);
    if lOwnsTransaction then
      lConnection.Commit;
  except
    if lOwnsTransaction and lConnection.InTransaction then
      lConnection.Rollback;
    raise;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.DeleteCacheKeyRows(const aConnection: TObject;
  const aCacheKey: string);
var
  lConnection: TFDConnection;
begin
  lConnection := aConnection as TFDConnection;
  ExecWideSql(lConnection, 'delete from snapshot_remove_with_visible_units where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_remove_with_visibility where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection,
    'delete from snapshot_remove_with_binding_references where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection,
    'delete from snapshot_remove_with_binding_selectors where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection,
    'delete from snapshot_remove_with_type_identities where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_remove_with_bindings where cache_key = ?',
    aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_remove_with_symbols where cache_key = ?',
    aCacheKey);
  ExecWideSql(lConnection,
    'delete from snapshot_remove_with_routine_owners where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection,
    'delete from snapshot_remove_with_value_evidence where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_remove_with_facts where cache_key = ?',
    aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_exact_strings where cache_key = ?',
    aCacheKey);
  ExecWideSql(lConnection,
    'delete from snapshot_project_remove_with_facts where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_references where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_with_statements where cache_key = ?',
    aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_symbols where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_strings where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_captured_sources where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_unit_occurrences where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_visible_units where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_target_lineage where cache_key = ?', aCacheKey);
  ExecWideSql(lConnection, 'delete from snapshot_units where cache_key = ?', aCacheKey);
end;

procedure TDelphiSemanticSnapshotSqliteCache.EnsureDatabase;
var
  lError: string;
  lRetryStopwatch: TStopwatch;
begin
  lRetryStopwatch := TStopwatch.StartNew;
  repeat
    try
      EnsureDatabaseOnce;
      Exit;
    except
      on E: Exception do
      begin
        lError := E.Message;
        if not RetrySnapshotSqliteBusy(lError, lRetryStopwatch) then
          raise;
      end;
    end;
  until False;
end;

procedure TDelphiSemanticSnapshotSqliteCache.EnsureDatabaseOnce;
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
    lConnection := lConnectionObject as TFDConnection;
    lConnection.StartTransaction;
    try
    lConnection.ExecSQL('create table if not exists meta (' +
      'key_name text primary key not null, value_text text not null)');
    lVersion := QueryWideString(lConnection, 'select value_text from meta where key_name = ?',
      cSnapshotSchemaMetaKey);
    if (lVersion <> '') and ((lVersion <> cSnapshotCacheSchemaVersion) or
      not SnapshotEvidenceLayoutValid(lConnection)) then
      RebuildSnapshotTables(lConnection);

    lConnection.ExecSQL('create table if not exists snapshot_target_lineage (' +
      'cache_key text primary key not null, unit_id integer not null, ' +
      'value_count integer not null, payload blob not null)');
    lConnection.ExecSQL('create table if not exists snapshot_units (' +
      'cache_key text primary key not null, identity_key text not null, ' +
      'source_file_name text not null, file_hash text not null, context_hash text not null, ' +
      'include_graph_hash text not null, schema_version text not null, ' +
      'stored_at_utc text not null, unit_id integer not null, file_name_id integer not null, ' +
      'unit_name_id integer not null, source_text_id integer not null, ' +
      'verified_active_source_text_id integer not null, ' +
      'scope_model_status_id integer not null, scope_model_version_id integer not null, ' +
      'scope_diagnostic_id integer not null, rejected_declaration_count integer not null, ' +
      'string_count integer not null, ' +
      'symbol_count integer not null, with_statement_count integer not null, ' +
      'reference_count integer not null, parse_avoided_estimate_ms integer not null, ' +
      'physical_reference_available integer not null, physical_symbol_available integer not null, ' +
      'captured_sources_available integer not null, visible_unit_names_available integer not null, ' +
      'has_includes integer not null, physical_reference_count integer not null, ' +
      'physical_symbol_count integer not null, captured_source_count integer not null, ' +
      'visible_unit_count integer not null, exact_string_count integer not null)');
    lConnection.ExecSQL('create index if not exists idx_snapshot_units_identity on ' +
      'snapshot_units(identity_key)');
    lConnection.ExecSQL('create table if not exists snapshot_strings (' +
      'cache_key text not null, string_id integer not null, text_value text not null, ' +
      'primary key(cache_key, string_id))');
    lConnection.ExecSQL('create table if not exists snapshot_source_texts (' +
      'content_hash text primary key not null, text text not null)');
    lConnection.ExecSQL('create table if not exists snapshot_exact_strings (' +
      'cache_key text not null, string_id integer not null, text_value text not null, ' +
      'source_content_hash text, primary key(cache_key, string_id), ' +
      'check (source_content_hash is null or text_value=''''))');
    lConnection.ExecSQL('create index if not exists idx_snapshot_exact_source on ' +
      'snapshot_exact_strings(source_content_hash)');
    lConnection.ExecSQL('create table if not exists snapshot_captured_sources (' +
      'cache_key text not null, unit_id integer not null, source_ordinal integer not null, ' +
      'file_id integer not null, text_id integer not null, status integer not null, ' +
      'primary key(cache_key, unit_id, source_ordinal), unique(cache_key, unit_id, file_id))');
    lConnection.ExecSQL('create table if not exists snapshot_unit_occurrences (' +
      'cache_key text not null, unit_id integer not null, collection integer not null, payload blob not null, ' +
      'primary key(cache_key, unit_id, collection))');
    lConnection.ExecSQL('create table if not exists snapshot_visible_units (' +
      'cache_key text not null, unit_id integer not null, import_ordinal integer not null, ' +
      'unit_name_id integer not null, primary key(cache_key, unit_id, import_ordinal), ' +
      'unique(cache_key, unit_id, unit_name_id))');
    lConnection.ExecSQL('create table if not exists snapshot_project_remove_with_facts (' +
      'cache_key text primary key not null, identity_key text not null, ' +
      'source_file_name text not null, file_hash text not null, context_hash text not null, ' +
      'include_graph_hash text not null, schema_version text not null, ' +
      'stored_at_utc text not null)');
    lConnection.ExecSQL('create index if not exists idx_snapshot_project_remove_with_identity on ' +
      'snapshot_project_remove_with_facts(identity_key)');
    lConnection.ExecSQL('create table if not exists snapshot_symbols (' +
      'cache_key text not null, unit_id integer not null, symbol_id integer not null, ' +
      'name_id integer not null, owner_type_id integer not null, type_id integer not null, ' +
      'routine_id integer not null, kind_id integer not null, flags integer not null, ' +
      'section_kind_id integer not null, source_kind_id integer not null, ' +
      'visibility_id integer not null, signature_id integer not null, ' +
      'declaration_role_id integer not null, scope_kind_id integer not null, ' +
      'owner_scope_id integer not null, semantic_symbol_id integer not null, ' +
      'routine_scope_id integer not null, file_id integer not null, ' +
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
      'routine_id integer not null, section_kind_id integer not null, ' +
      'routine_scope_id integer not null, ' +
      'source_kind_id integer not null, ' +
      'classification_id integer not null, lookup_source_id integer not null, ' +
      'reason_id integer not null, line integer not null, column integer not null, ' +
      'end_line integer not null, end_column integer not null, file_id integer not null, ' +
      'primary key(cache_key, unit_id, reference_id))');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_value_evidence (' +
      'cache_key text not null, row_kind integer not null, item_index integer not null, ' +
      'owner_index integer not null, declared_id text not null, unit_name text not null, ' +
      'file_name text not null, name text not null, next_id text not null, ' +
      'complete integer not null, terminal_verified integer not null, source_text text not null, ' +
      'active_source_text text not null, scope_status text not null, scope_version text not null, ' +
      'rejected_count integer not null, count1 integer not null, count2 integer not null, ' +
      'count3 integer not null, count4 integer not null, count5 integer not null, ' +
      'count6 integer not null, evidence_version integer not null, ' +
      'primary key(cache_key, row_kind, owner_index, item_index))');
  lConnection.ExecSQL('create table if not exists snapshot_remove_with_facts (' +
      'cache_key text primary key not null, context_fingerprint_id integer not null, ' +
      'routine_owner_count integer not null, symbol_count integer not null, ' +
      'binding_count integer not null, type_identity_count integer not null)');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_visibility (' +
      'cache_key text primary key not null, unit_count integer not null, row_count integer not null)');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_visible_units (' +
      'cache_key text not null, file_name text not null, visible_unit_name text not null, ' +
      'primary key(cache_key, file_name, visible_unit_name))');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_routine_owners (' +
      'cache_key text not null, item_index integer not null, name_id integer not null, ' +
      'symbol_class_id integer not null, kind_id integer not null, type_name_id integer not null, ' +
      'modifier_id integer not null, owner_name_id integer not null, owner_type_id integer not null, ' +
      'source_owner_type_id integer not null, related_type_name_id integer not null, ' +
      'routine_name_id integer not null, unit_name_id integer not null, file_name_id integer not null, ' +
      'section_kind_id integer not null, line integer not null, column integer not null, ' +
      'end_line integer not null, end_column integer not null, unsupported_reason_id integer not null, ' +
      'flags integer not null, index_parameter_count integer not null, type_category_id integer not null, ' +
      'routine_scope_id_id integer not null, parent_scope_id_id integer not null, ' +
      'owner_scope_id_id integer not null, owner_symbol_id_id integer not null, ' +
      'access_owner_unit_name_id integer not null, ' +
      'access_owner_file_name_id integer not null, ' +
      'access_owner_section_kind_id integer not null, ' +
      'access_owner_line integer not null, ' +
      'access_owner_column integer not null, ' +
      'heading_line integer not null, heading_column integer not null, ' +
      'heading_end_line integer not null, heading_end_column integer not null, ' +
      'primary key(cache_key, item_index))');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_symbols (' +
      'cache_key text not null, item_index integer not null, name_id integer not null, ' +
      'symbol_class_id integer not null, kind_id integer not null, type_name_id integer not null, ' +
      'modifier_id integer not null, owner_name_id integer not null, owner_type_id integer not null, ' +
      'source_owner_type_id integer not null, related_type_name_id integer not null, ' +
      'routine_name_id integer not null, unit_name_id integer not null, file_name_id integer not null, ' +
      'section_kind_id integer not null, line integer not null, column integer not null, ' +
      'end_line integer not null, end_column integer not null, unsupported_reason_id integer not null, ' +
      'flags integer not null, index_parameter_count integer not null, type_category_id integer not null, ' +
      'routine_scope_id_id integer not null, parent_scope_id_id integer not null, ' +
      'owner_scope_id_id integer not null, owner_symbol_id_id integer not null, ' +
      'access_owner_unit_name_id integer not null, ' +
      'access_owner_file_name_id integer not null, ' +
      'access_owner_section_kind_id integer not null, ' +
      'access_owner_line integer not null, ' +
      'access_owner_column integer not null, ' +
      'heading_line integer not null, heading_column integer not null, ' +
      'heading_end_line integer not null, heading_end_column integer not null, ' +
      'primary key(cache_key, item_index))');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_bindings (' +
      'cache_key text not null, binding_index integer not null, semantic_id_id integer not null, ' +
      'provenance_id integer not null, file_name_id integer not null, unit_name_id integer not null, ' +
      'routine_name_id integer not null, line integer not null, column integer not null, ' +
      'end_line integer not null, end_column integer not null, body_line integer not null, ' +
      'body_column integer not null, body_end_line integer not null, body_end_column integer not null, ' +
      'selector_text_id integer not null, status_id integer not null, skip_reason_id integer not null, ' +
      'flags integer not null, member_reference_count integer not null, lexical_reference_count integer not null, ' +
      'external_reference_count integer not null, intrinsic_reference_count integer not null, ' +
      'unsupported_reference_count integer not null, unresolved_reference_count integer not null, ' +
      'selector_count integer not null, reference_count integer not null, ' +
    'inactive_reference_count integer not null, inactive_skip_reason_id integer not null, ' +
      'routine_scope_id_id integer not null, primary key(cache_key, binding_index))');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_binding_selectors (' +
      'cache_key text not null, binding_index integer not null, selector_index integer not null, ' +
      'selector_text_id integer not null, status_id integer not null, reason_code_id integer not null, ' +
      'type_name_id integer not null, capture_type_name_id integer not null, ' +
      'capture_status_id integer not null, primary key(cache_key, binding_index, selector_index))');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_type_identities (' +
      'cache_key text not null, entity_kind text not null, item_index integer not null, ' +
      'sub_index integer not null, unit_id_id integer not null, unit_name_id integer not null, ' +
      'name_id integer not null, kind_id integer not null, declared_id_id integer not null, ' +
      'canonical_id_id integer not null, underlying_id_id integer not null, ' +
      'canonical_name_id integer not null, underlying_name_id integer not null, ' +
      'base_type_name_id integer not null, helper_target_name_id integer not null, ' +
      'section_kind_id integer not null, file_name_id integer not null, line integer not null, ' +
      'column integer not null, end_line integer not null, end_column integer not null, ' +
      'scope_kind_id integer not null, owner_scope_id_id integer not null, ' +
      'semantic_symbol_id_id integer not null, ' +
      'primary key(cache_key, entity_kind, item_index, sub_index))');
    lConnection.ExecSQL('create table if not exists snapshot_remove_with_binding_references (' +
      'cache_key text not null, binding_index integer not null, reference_index integer not null, ' +
      'semantic_id_id integer not null, name_id integer not null, classification_id integer not null, ' +
      'lookup_source_id integer not null, receiver_type_name_id integer not null, kind_id integer not null, ' +
      'type_name_id integer not null, reason_code_id integer not null, scope_conflict_kind_id integer not null, ' +
      'scope_conflict_name_id integer not null, line integer not null, column integer not null, ' +
      'end_line integer not null, end_column integer not null, primary key(cache_key, binding_index, reference_index))');
    ExecWideSql(lConnection, 'insert or replace into meta(key_name, value_text) values (?, ?)',
      cSnapshotSchemaMetaKey, cSnapshotCacheSchemaVersion);
    lConnection.Commit;
    except
      if lConnection.InTransaction then
        lConnection.Rollback;
      raise;
    end;
  finally
    lConnectionObject.Free;
    lDriverLinkObject.Free;
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.IdentityMatches(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aConnection: TObject; out aEntryBelongsToIdentity: Boolean): Boolean;
var
  lOffset: Integer;
  lContextHashField: TField;
  lFileHashField: TField;
  lIncludeGraphHashField: TField;
  lIdentityKeyField: TField;
  lQuery: TFDDataSet;
  lSchemaVersionField: TField;
  lSourceFileNameField: TField;
  lStopwatch: TStopwatch;
begin
  Result := False;
  aEntryBelongsToIdentity := False;
  lQuery := NewUnitReadQuery(aConnection, aIdentity.CacheKey, 'snapshot_units', 'select identity_key, source_file_name, ' +
    'file_hash, context_hash, include_graph_hash, schema_version from snapshot_units ' +
    'where cache_key = ?') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      TFDQuery(lQuery).Params[0].AsWideString := aIdentity.CacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    if lQuery.Eof then
      Exit;

    lOffset := 0;
    if fUnitLoadBatch <> nil then
      lOffset := 14;
    lIdentityKeyField := lQuery.Fields[lOffset];
    aEntryBelongsToIdentity := lIdentityKeyField.AsWideString = aIdentity.IdentityKey;
    if not aEntryBelongsToIdentity then
      Exit;

    lSourceFileNameField := lQuery.Fields[lOffset + 1];
    lFileHashField := lQuery.Fields[lOffset + 2];
    lContextHashField := lQuery.Fields[lOffset + 3];
    lIncludeGraphHashField := lQuery.Fields[lOffset + 4];
    lSchemaVersionField := lQuery.Fields[lOffset + 5];
    Result := SameCanonicalIdentityPath(lSourceFileNameField.AsWideString,
      aIdentity.SourceFileName)
      and (lFileHashField.AsWideString = aIdentity.FileHash)
      and (lContextHashField.AsWideString = aIdentity.ContextHash)
      and (lIncludeGraphHashField.AsWideString = aIdentity.IncludeGraphHash)
      and (lSchemaVersionField.AsWideString = aIdentity.SchemaVersion);
  finally
    lQuery.Free;
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.ProjectRemoveWithIdentityMatches(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aConnection: TObject; out aEntryBelongsToIdentity: Boolean): Boolean;
var
  lContextHashField: TField;
  lFileHashField: TField;
  lIncludeGraphHashField: TField;
  lIdentityKeyField: TField;
  lQuery: TFDQuery;
  lSchemaVersionField: TField;
  lSourceFileNameField: TField;
  lStopwatch: TStopwatch;
begin
  Result := False;
  aEntryBelongsToIdentity := False;
  lQuery := NewQuery(aConnection as TFDConnection, 'select identity_key, source_file_name, ' +
    'file_hash, context_hash, include_graph_hash, schema_version from ' +
    'snapshot_project_remove_with_facts where cache_key = ?');
  try
    lQuery.Params[0].AsWideString := aIdentity.CacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    if lQuery.Eof then
      Exit;

    lIdentityKeyField := lQuery.Fields[0];
    aEntryBelongsToIdentity := lIdentityKeyField.AsWideString = aIdentity.IdentityKey;
    if not aEntryBelongsToIdentity then
      Exit;

    lSourceFileNameField := lQuery.Fields[1];
    lFileHashField := lQuery.Fields[2];
    lContextHashField := lQuery.Fields[3];
    lIncludeGraphHashField := lQuery.Fields[4];
    lSchemaVersionField := lQuery.Fields[5];
    Result := SameCanonicalIdentityPath(lSourceFileNameField.AsWideString,
      aIdentity.SourceFileName)
      and (lFileHashField.AsWideString = aIdentity.FileHash)
      and (lContextHashField.AsWideString = aIdentity.ContextHash)
      and (lIncludeGraphHashField.AsWideString = aIdentity.IncludeGraphHash)
      and (lSchemaVersionField.AsWideString = aIdentity.SchemaVersion);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadExactStrings(const aCacheKey: string;
  const aConnection: TObject; const aExactStrings: TSemanticStringPool);
var
  lExpectedId: Int64;
  lHash, lText: string;
  lQuery: TFDDataSet;
  lStopwatch: TStopwatch;
begin
  lExpectedId := 1;
  lQuery := NewUnitReadQuery(aConnection, aCacheKey, 'snapshot_exact_strings', 'select e.string_id,e.text_value,' +
    'e.source_content_hash,s.text from snapshot_exact_strings e left join snapshot_source_texts s ' +
    'on s.content_hash=e.source_content_hash where e.cache_key=? order by e.string_id') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      TFDQuery(lQuery).FormatOptions.StrsTrim := False;
    if lQuery is TFDQuery then
      SetWideParam(TFDQuery(lQuery), 0, aCacheKey);
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lStopwatch := TStopwatch.StartNew;
    while not lQuery.Eof do
    begin
      if CheckedCacheInteger(lQuery.Fields[0], 1, High(Cardinal)) <> lExpectedId then
        raise EInvalidOpException.Create('SNAPSHOT_EXACT_IDS_NOT_DENSE');
      if lQuery.Fields[1].IsNull then
        raise EInvalidOpException.Create('SNAPSHOT_EXACT_TEXT_NULL');
      lText := lQuery.Fields[1].AsWideString;
      if not lQuery.Fields[2].IsNull then
      begin
        lHash := lQuery.Fields[2].AsWideString;
        if (lText <> '') or not ValidSnapshotSourceHash(lHash) or lQuery.Fields[3].IsNull then
          raise EInvalidOpException.Create('SNAPSHOT_SHARED_TEXT_BACKING_INVALID');
        lText := lQuery.Fields[3].AsWideString;
        if (lText = '') or (SnapshotSourceHash(lText) <> lHash) then
          raise EInvalidOpException.Create('SNAPSHOT_SHARED_TEXT_HASH_MISMATCH');
      end;
      if (lText = '') or not IsWellFormedEvidenceText(lText) or
        (aExactStrings.Intern(lText) <> lExpectedId) then
        raise EInvalidOpException.Create('SNAPSHOT_EXACT_ID_REBUILD_MISMATCH');
      Inc(lExpectedId);
      lQuery.Next;
    end;
    Inc(fMetrics.SnapshotDeserializeMilliseconds, lStopwatch.ElapsedMilliseconds);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadReferences(const aCacheKey: string;
  const aConnection: TObject; const aUnit: TUnitSnapshot);
var
  lClassificationIdField: TSnapshotIntegerReader;
  lColumnField: TSnapshotIntegerReader;
  lEndColumnField: TSnapshotIntegerReader;
  lEndLineField: TSnapshotIntegerReader;
  lExpectedId: TSemanticReferenceId;
  lLineField: TSnapshotIntegerReader;
  lLookupSourceIdField: TSnapshotIntegerReader;
  lNameIdField: TSnapshotIntegerReader;
  lQuery: TFDQuery;
  lUnitIdField: TSnapshotIntegerReader;
  lReasonIdField: TSnapshotIntegerReader;
  lReceiverTypeIdField: TSnapshotIntegerReader;
  lReference: TSemanticReferenceFact;
  lReferenceIdField: TSnapshotIntegerReader;
  lReferenceId: TSemanticReferenceId;
  lRoutineIdField: TSnapshotIntegerReader;
  lFileIdField: TSnapshotIntegerReader;
  lRoutineScopeIdField: TSnapshotIntegerReader;
  lSectionKindIdField: TSnapshotIntegerReader;
  lSourceKindIdField: TSnapshotIntegerReader;
  lStopwatch: TStopwatch;
  lTargetSymbolIdField: TSnapshotIntegerReader;
  lTargetUnitIdField: TSnapshotIntegerReader;
  lTypeIdField: TSnapshotIntegerReader;
  lWithIdField: TSnapshotIntegerReader;
begin
  lExpectedId := 1;
  lQuery := NewQuery(aConnection as TFDConnection, 'select reference_id, with_id, ' +
    'target_unit_id, target_symbol_id, name_id, receiver_type_id, type_id, classification_id, ' +
    'routine_id, section_kind_id, source_kind_id, lookup_source_id, reason_id, line, column, ' +
    'end_line, end_column, routine_scope_id, file_id, unit_id from snapshot_references ' +
    'where cache_key = ? order by reference_id');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lReferenceIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[0]);
    lWithIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[1]);
    lTargetUnitIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[2]);
    lTargetSymbolIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[3]);
    lNameIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[4]);
    lReceiverTypeIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[5]);
    lTypeIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[6]);
    lClassificationIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[7]);
    lRoutineIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[8]);
    lSectionKindIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[9]);
    lSourceKindIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[10]);
    lLookupSourceIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[11]);
    lReasonIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[12]);
    lLineField := TSnapshotIntegerReader.Bind(lQuery.Fields[13]);
    lColumnField := TSnapshotIntegerReader.Bind(lQuery.Fields[14]);
    lEndLineField := TSnapshotIntegerReader.Bind(lQuery.Fields[15]);
    lEndColumnField := TSnapshotIntegerReader.Bind(lQuery.Fields[16]);
    lRoutineScopeIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[17]);
    lFileIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[18]);
    lStopwatch := TStopwatch.StartNew;
    lUnitIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[19]);
    while not lQuery.Eof do
    begin
      if lUnitIdField.Read(1, High(Cardinal)) <> aUnit.UnitId then
        raise EInvalidOpException.Create('SNAPSHOT_CHILD_UNIT_INVALID');
      if TSemanticReferenceId(lReferenceIdField.Read(0, High(Cardinal))) <> lExpectedId then
        raise Exception.Create('Snapshot reference IDs are not dense.');

      lReference := Default(TSemanticReferenceFact);
      lReference.WithId := TSemanticWithId(lWithIdField.Read(0, High(Cardinal)));
      lReference.TargetUnitId := TSemanticUnitId(lTargetUnitIdField.Read(0, High(Cardinal)));
      lReference.TargetSymbolId := TSemanticSymbolId(lTargetSymbolIdField.Read(0, High(Cardinal)));
      lReference.NameId := TSemanticStringId(lNameIdField.Read(0, High(Cardinal)));
      lReference.ReceiverTypeId := TSemanticStringId(lReceiverTypeIdField.Read(0, High(Cardinal)));
      lReference.TypeId := TSemanticStringId(lTypeIdField.Read(0, High(Cardinal)));
      lReference.ClassificationId := TSemanticStringId(lClassificationIdField.Read(0, High(Cardinal)));
      lReference.RoutineId := TSemanticStringId(lRoutineIdField.Read(0, High(Cardinal)));
      lReference.SectionKindId := TSemanticStringId(lSectionKindIdField.Read(0, High(Cardinal)));
      lReference.SourceKindId := TSemanticStringId(lSourceKindIdField.Read(0, High(Cardinal)));
      lReference.LookupSourceId := TSemanticStringId(lLookupSourceIdField.Read(0, High(Cardinal)));
      lReference.ReasonId := TSemanticStringId(lReasonIdField.Read(0, High(Cardinal)));
      lReference.RoutineScopeId :=
        TSemanticStringId(lRoutineScopeIdField.Read(0, High(Cardinal)));
      lReference.FileId := TSemanticStringId(lFileIdField.Read(0, High(Cardinal)));
      lReference.Line := lLineField.Read(0, MaxInt);
      lReference.Column := lColumnField.Read(0, MaxInt);
      lReference.EndLine := lEndLineField.Read(0, MaxInt);
      lReference.EndColumn := lEndColumnField.Read(0, MaxInt);
      lReferenceId := aUnit.AddReference(lReference);
      if lReferenceId <> lExpectedId then
        raise Exception.Create('Snapshot reference ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
    Inc(fMetrics.SnapshotDeserializeMilliseconds, lStopwatch.ElapsedMilliseconds);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadStrings(const aCacheKey: string;
  const aConnection: TObject; const aStrings: TSemanticStringPool);
var
  lExpectedId: TSemanticStringId;
  lQuery: TFDQuery;
  lStringIdField: TField;
  lStringId: TSemanticStringId;
  lTextValueField: TField;
  lStopwatch: TStopwatch;
begin
  lExpectedId := 1;
  lQuery := NewQuery(aConnection as TFDConnection, 'select string_id, text_value from ' +
    'snapshot_strings where cache_key = ? order by string_id');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lStringIdField := lQuery.Fields[0];
    lTextValueField := lQuery.Fields[1];
    lStopwatch := TStopwatch.StartNew;
    while not lQuery.Eof do
    begin
      if TSemanticStringId(CheckedCacheInteger(lStringIdField, 1, High(Cardinal))) <> lExpectedId then
        raise Exception.Create('Snapshot string IDs are not dense.');

      if lTextValueField.IsNull then
        raise EInvalidOpException.Create('SNAPSHOT_SEMANTIC_TEXT_NULL');
      lStringId := aStrings.Intern(lTextValueField.AsWideString);
      if lStringId <> lExpectedId then
        raise Exception.Create('Snapshot string ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
    Inc(fMetrics.SnapshotDeserializeMilliseconds, lStopwatch.ElapsedMilliseconds);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadSymbols(const aCacheKey: string;
  const aConnection: TObject; const aUnit: TUnitSnapshot);
var
  lColumnField: TSnapshotIntegerReader;
  lDeclarationRoleIdField: TSnapshotIntegerReader;
  lEndColumnField: TSnapshotIntegerReader;
  lEndLineField: TSnapshotIntegerReader;
  lExpectedId: TSemanticSymbolId;
  lFlagsField: TSnapshotIntegerReader;
  lKindIdField: TSnapshotIntegerReader;
  lLineField: TSnapshotIntegerReader;
  lNameIdField: TSnapshotIntegerReader;
  lOwnerScopeIdField: TSnapshotIntegerReader;
  lQuery: TFDQuery;
  lUnitIdField: TSnapshotIntegerReader;
  lOwnerTypeIdField: TSnapshotIntegerReader;
  lRoutineIdField: TSnapshotIntegerReader;
  lFileIdField: TSnapshotIntegerReader;
  lRoutineScopeIdField: TSnapshotIntegerReader;
  lScopeKindIdField: TSnapshotIntegerReader;
  lSectionKindIdField: TSnapshotIntegerReader;
  lSignatureIdField: TSnapshotIntegerReader;
  lSemanticSymbolIdField: TSnapshotIntegerReader;
  lSourceKindIdField: TSnapshotIntegerReader;
  lStopwatch: TStopwatch;
  lSymbol: TSemanticSymbolFact;
  lSymbolIdField: TSnapshotIntegerReader;
  lSymbolId: TSemanticSymbolId;
  lTypeIdField: TSnapshotIntegerReader;
  lVisibilityIdField: TSnapshotIntegerReader;
begin
  lExpectedId := 1;
  lQuery := NewQuery(aConnection as TFDConnection, 'select symbol_id, name_id, owner_type_id, ' +
    'type_id, routine_id, kind_id, section_kind_id, source_kind_id, visibility_id, ' +
    'signature_id, declaration_role_id, scope_kind_id, owner_scope_id, semantic_symbol_id, ' +
    'routine_scope_id, flags, line, column, end_line, end_column, file_id, unit_id ' +
    'from snapshot_symbols where cache_key = ? order by symbol_id');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lSymbolIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[0]);
    lNameIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[1]);
    lOwnerTypeIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[2]);
    lTypeIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[3]);
    lRoutineIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[4]);
    lKindIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[5]);
    lSectionKindIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[6]);
    lSourceKindIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[7]);
    lVisibilityIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[8]);
    lSignatureIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[9]);
    lDeclarationRoleIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[10]);
    lScopeKindIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[11]);
    lOwnerScopeIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[12]);
    lSemanticSymbolIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[13]);
    lRoutineScopeIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[14]);
    lFlagsField := TSnapshotIntegerReader.Bind(lQuery.Fields[15]);
    lLineField := TSnapshotIntegerReader.Bind(lQuery.Fields[16]);
    lColumnField := TSnapshotIntegerReader.Bind(lQuery.Fields[17]);
    lEndLineField := TSnapshotIntegerReader.Bind(lQuery.Fields[18]);
    lEndColumnField := TSnapshotIntegerReader.Bind(lQuery.Fields[19]);
    lFileIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[20]);
    lStopwatch := TStopwatch.StartNew;
    lUnitIdField := TSnapshotIntegerReader.Bind(lQuery.Fields[21]);
    while not lQuery.Eof do
    begin
      if lUnitIdField.Read(1, High(Cardinal)) <> aUnit.UnitId then
        raise EInvalidOpException.Create('SNAPSHOT_CHILD_UNIT_INVALID');
      if TSemanticSymbolId(lSymbolIdField.Read(0, High(Cardinal))) <> lExpectedId then
        raise Exception.Create('Snapshot symbol IDs are not dense.');

      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := TSemanticStringId(lNameIdField.Read(0, High(Cardinal)));
      lSymbol.OwnerTypeId := TSemanticStringId(lOwnerTypeIdField.Read(0, High(Cardinal)));
      lSymbol.TypeId := TSemanticStringId(lTypeIdField.Read(0, High(Cardinal)));
      lSymbol.RoutineId := TSemanticStringId(lRoutineIdField.Read(0, High(Cardinal)));
      lSymbol.KindId := TSemanticStringId(lKindIdField.Read(0, High(Cardinal)));
      lSymbol.SectionKindId := TSemanticStringId(lSectionKindIdField.Read(0, High(Cardinal)));
      lSymbol.SourceKindId := TSemanticStringId(lSourceKindIdField.Read(0, High(Cardinal)));
      lSymbol.VisibilityId := TSemanticStringId(lVisibilityIdField.Read(0, High(Cardinal)));
      lSymbol.SignatureId := TSemanticStringId(lSignatureIdField.Read(0, High(Cardinal)));
      lSymbol.DeclarationRoleId :=
        TSemanticStringId(lDeclarationRoleIdField.Read(0, High(Cardinal)));
      lSymbol.ScopeKindId := TSemanticStringId(lScopeKindIdField.Read(0, High(Cardinal)));
      lSymbol.OwnerScopeId := TSemanticStringId(lOwnerScopeIdField.Read(0, High(Cardinal)));
      lSymbol.SemanticSymbolId :=
        TSemanticStringId(lSemanticSymbolIdField.Read(0, High(Cardinal)));
      lSymbol.RoutineScopeId :=
        TSemanticStringId(lRoutineScopeIdField.Read(0, High(Cardinal)));
      lSymbol.Flags := Cardinal(lFlagsField.Read(0, High(Cardinal)));
      lSymbol.FileId := TSemanticStringId(lFileIdField.Read(0, High(Cardinal)));
      lSymbol.Line := lLineField.Read(0, MaxInt);
      lSymbol.Column := lColumnField.Read(0, MaxInt);
      lSymbol.EndLine := lEndLineField.Read(0, MaxInt);
      lSymbol.EndColumn := lEndColumnField.Read(0, MaxInt);
      lSymbolId := aUnit.AddSymbol(lSymbol);
      if lSymbolId <> lExpectedId then
        raise Exception.Create('Snapshot symbol ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
    Inc(fMetrics.SnapshotDeserializeMilliseconds, lStopwatch.ElapsedMilliseconds);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreRemoveWithVisibility(
  const aCacheKey: string; const aConnection: TObject; const aSnapshot: TDelphiProjectSnapshot);
var
  i: Integer;
  lQuery: TFDQuery;
  lRow: TRemoveWithVisibleUnit;
  lRows: TArray<TRemoveWithVisibleUnit>;
  lUnitCount: Integer;
  lVisibility: TRemoveWithUnitVisibility;
begin
  lRows := nil;
  lUnitCount := 0;
  if TryGetRemoveWithVisibility(aSnapshot, lVisibility) then
  begin
    lRows := lVisibility.Rows;
    lUnitCount := lVisibility.UnitCount;
  end else begin
    if aSnapshot.UnitCount <> 0 then
      raise Exception.Create('Cannot store remove-with planning facts without unit visibility.');
    for i := 0 to aSnapshot.RemoveWithPlanningBindingCount - 1 do
      if aSnapshot.RemoveWithPlanningBindingByIndex(i).FileNameId <> 0 then
        raise Exception.Create('Cannot store bound remove-with facts without unit visibility.');
  end;

  lQuery := NewQuery(aConnection as TFDConnection,
    'insert into snapshot_remove_with_visibility(cache_key, unit_count, row_count) values (?, ?, ?)');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    lQuery.Params[1].AsInteger := lUnitCount;
    lQuery.Params[2].AsInteger := Length(lRows);
    lQuery.Prepare;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
  lQuery := NewQuery(aConnection as TFDConnection,
    'insert into snapshot_remove_with_visible_units(cache_key, file_name, visible_unit_name) values (?, ?, ?)');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    SetWideParam(lQuery, 1, '');
    SetWideParam(lQuery, 2, '');
    lQuery.Prepare;
    for lRow in lRows do
    begin
      lQuery.Params[1].AsWideString := lRow.FileName;
      lQuery.Params[2].AsWideString := lRow.UnitName;
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadRemoveWithVisibilityCounts(
  const aCacheKey: string; const aConnection: TObject; out aUnitCount, aRowCount: Integer);
var
  lQuery: TFDQuery;
  lStopwatch: TStopwatch;
begin
  lQuery := NewQuery(aConnection as TFDConnection,
    'select unit_count, row_count from snapshot_remove_with_visibility where cache_key = ?');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    if lQuery.Eof then
      raise Exception.Create('Cached remove-with unit visibility is missing.');
    aUnitCount := lQuery.Fields[0].AsInteger;
    aRowCount := lQuery.Fields[1].AsInteger;
    if (aUnitCount < 0) or (aRowCount < aUnitCount) then
      raise Exception.Create('Invalid cached remove-with visibility counts.');
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadRemoveWithVisibility(
  const aCacheKey: string; const aConnection: TObject;
  const aBuilder: TDelphiProjectSnapshotBuilder);
var
  i: Integer;
  lQuery: TFDQuery;
  lRowCount: Integer;
  lRows: TArray<TRemoveWithVisibleUnit>;
  lStopwatch: TStopwatch;
  lUnitCount: Integer;
  lVisibility: TRemoveWithUnitVisibility;
begin
  LoadRemoveWithVisibilityCounts(aCacheKey, aConnection, lUnitCount, lRowCount);
  lQuery := NewQuery(aConnection as TFDConnection,
    'select file_name, visible_unit_name from snapshot_remove_with_visible_units ' +
    'where cache_key = ? order by file_name, visible_unit_name');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lStopwatch := TStopwatch.StartNew;
    if lQuery.RecordCount <> lRowCount then
      raise Exception.Create('Cached remove-with visibility rows are incomplete.');
    SetLength(lRows, lRowCount);
    i := 0;
    while not lQuery.Eof do
    begin
      lRows[i].FileName := lQuery.Fields[0].AsWideString;
      lRows[i].UnitName := lQuery.Fields[1].AsWideString;
      Inc(i);
      lQuery.Next;
    end;
    lVisibility := TRemoveWithUnitVisibility.Create(lRows);
    try
      if lVisibility.UnitCount <> lUnitCount then
        raise Exception.Create('Cached remove-with visibility unit count does not match.');
      aBuilder.SetExtensionOwned(cRemoveWithVisibilityExtensionName, lVisibility);
      lVisibility := nil;
    finally
      lVisibility.Free;
    end;
    Inc(fMetrics.SnapshotDeserializeMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreValueMemberEvidence(
  const aCacheKey: string; const aConnection: TObject;
  const aEvidence: TDelphiSemanticValueMemberEvidence);
var
  i, j: Integer;
  lCounts: TArray<Integer>;
  lKind, lNameIndex, lOwnerNameIndex: Integer;
  lOwner: TDelphiSemanticValueEvidenceOwner;
  lQuery: TFDQuery;
begin
  lNameIndex := 0;
  for lOwner in aEvidence.Owners do
    Inc(lNameIndex, Length(lOwner.ValueNames));
  lCounts := [1, Length(aEvidence.Units), Length(aEvidence.Owners), lNameIndex,
    Length(aEvidence.Queries), Length(aEvidence.ValueNames), Length(aEvidence.UnverifiedOwnerKeys)];
  lQuery := NewQuery(aConnection as TFDConnection,
    'insert into snapshot_remove_with_value_evidence(cache_key, row_kind, item_index, ' +
    'owner_index, declared_id, unit_name, file_name, name, next_id, complete, terminal_verified, ' +
    'source_text, active_source_text, scope_status, scope_version, rejected_count, ' +
    'count1, count2, count3, count4, count5, count6, evidence_version) ' +
    'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    // Source/activity text is exact, including final whitespace and line breaks.
    lQuery.FormatOptions.StrsTrim := False;
    // Each kind has an explicit count witness, including every empty name set.
    for lKind := 0 to 6 do
    begin
      lNameIndex := 0;
      lOwnerNameIndex := 0;
      for i := 0 to lCounts[lKind] - 1 do
      begin
        SetWideParam(lQuery, 0, aCacheKey);
        lQuery.Params[1].AsInteger := lKind;
        lQuery.Params[2].AsInteger := i;
        lQuery.Params[3].AsInteger := -1;
        for j := 4 to 8 do
          SetWideParam(lQuery, j, '');
        lQuery.Params[9].AsInteger := 0;
        lQuery.Params[10].AsInteger := 0;
        for j := 11 to 14 do
          SetWideParam(lQuery, j, '');
        for j := 15 to 22 do
          lQuery.Params[j].AsInteger := 0;
        case lKind of
          0:
            begin
              lQuery.Params[9].AsInteger := Ord(aEvidence.Available);
              for j := 1 to 6 do
                lQuery.Params[15 + j].AsInteger := lCounts[j];
              lQuery.Params[22].AsInteger := 1;
            end;
          1:
            begin
              SetWideParam(lQuery, 5, aEvidence.Units[i].UnitName);
              SetWideParam(lQuery, 6, aEvidence.Units[i].FileName);
              SetWideParam(lQuery, 11, aEvidence.Units[i].SourceText);
              SetWideParam(lQuery, 12, aEvidence.Units[i].VerifiedActiveSourceText);
              SetWideParam(lQuery, 13, aEvidence.Units[i].ScopeModelStatus);
              SetWideParam(lQuery, 14, aEvidence.Units[i].ScopeModelVersion);
              lQuery.Params[15].AsInteger := aEvidence.Units[i].RejectedDeclarationCount;
            end;
          2:
            begin
              lOwner := aEvidence.Owners[i];
              SetWideParam(lQuery, 4, lOwner.DeclaredId);
              SetWideParam(lQuery, 5, lOwner.UnitName);
              SetWideParam(lQuery, 6, lOwner.FileName);
              SetWideParam(lQuery, 7, lOwner.Name);
              SetWideParam(lQuery, 8, lOwner.NextDeclaredId);
              lQuery.Params[9].AsInteger := Ord(lOwner.Complete);
              lQuery.Params[10].AsInteger := Ord(lOwner.TerminalVerified) + 2 * Ord(lOwner.UnindexedRoot);
              lQuery.Params[16].AsInteger := Length(lOwner.ValueNames);
            end;
          3:
            begin
              // The flat name sequence is partitioned by each owner's count.
              while lNameIndex < Length(aEvidence.Owners) do
              begin
                if lOwnerNameIndex < Length(aEvidence.Owners[lNameIndex].ValueNames) then
                  Break;
                Inc(lNameIndex);
                lOwnerNameIndex := 0;
              end;
              lQuery.Params[2].AsInteger := lOwnerNameIndex;
              lQuery.Params[3].AsInteger := lNameIndex;
              SetWideParam(lQuery, 7, aEvidence.Owners[lNameIndex].ValueNames[lOwnerNameIndex]);
              Inc(lOwnerNameIndex);
            end;
          4:
            begin
              SetWideParam(lQuery, 7, aEvidence.Queries[i].Name);
              SetWideParam(lQuery, 4, aEvidence.Queries[i].DeclaredId);
            end;
          5: SetWideParam(lQuery, 7, aEvidence.ValueNames[i]);
          6: SetWideParam(lQuery, 7, aEvidence.UnverifiedOwnerKeys[i]);
        end;
        if not lQuery.Prepared then
          lQuery.Prepare;
        lQuery.ExecSQL;
      end;
    end;
  finally
    lQuery.Free;
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.LoadValueMemberEvidence(
  const aCacheKey: string; const aConnection: TObject): TDelphiSemanticValueMemberEvidence;
var
  i, j: Integer;
  lCounts, lLoaded, lNameCounts, lLoadedNames: TArray<Integer>;
  lFields: TArray<TField>;
  lKind, lItem, lOwner: Integer;
  lQuery: TFDQuery;
begin
  Result := Default(TDelphiSemanticValueMemberEvidence);
  lQuery := NewQuery(aConnection as TFDConnection,
    'select row_kind, item_index, owner_index, declared_id, unit_name, file_name, name, ' +
    'next_id, complete, terminal_verified, source_text, active_source_text, scope_status, ' +
    'scope_version, rejected_count, count1, count2, count3, count4, count5, count6, ' +
    'evidence_version from snapshot_remove_with_value_evidence where cache_key = ? ' +
    'order by row_kind, owner_index, item_index');
  try
    // Source/activity text is exact, including final whitespace and line breaks.
    lQuery.FormatOptions.StrsTrim := False;
    SetWideParam(lQuery, 0, aCacheKey);
    lQuery.Open;
    lQuery.FetchAll;
    SetLength(lFields, lQuery.FieldCount);
    for i := 0 to High(lFields) do
      lFields[i] := lQuery.Fields[i];
    if lQuery.Eof or (lFields[0].AsInteger <> 0) or (lFields[1].AsInteger <> 0) or
      (lFields[2].AsInteger <> -1) or (lFields[21].AsInteger <> 1) then
      raise Exception.Create('Snapshot value evidence header is missing or obsolete.');
    SetLength(lCounts, 7);
    SetLength(lLoaded, 7);
    lCounts[0] := 1;
    for i := 1 to 6 do
    begin
      lCounts[i] := lFields[14 + i].AsInteger;
      if (lCounts[i] < 0) or (lCounts[i] > lQuery.RecordCount) then
        raise Exception.Create('Snapshot value evidence count is invalid.');
    end;
    Result.Available := lFields[8].AsInteger = 1;
    if Result.Available and (lCounts[1] = 0) then
      raise Exception.Create('Snapshot value evidence has no unit witnesses.');
    SetLength(Result.Units, lCounts[1]);
    SetLength(Result.Owners, lCounts[2]);
    SetLength(Result.Queries, lCounts[4]);
    SetLength(Result.ValueNames, lCounts[5]);
    SetLength(Result.UnverifiedOwnerKeys, lCounts[6]);
    SetLength(lNameCounts, lCounts[2]);
    SetLength(lLoadedNames, lCounts[2]);
    while not lQuery.Eof do
    begin
      lKind := lFields[0].AsInteger;
      lItem := lFields[1].AsInteger;
      lOwner := lFields[2].AsInteger;
      if (lKind < 0) or (lKind > 6) then
        raise Exception.Create('Snapshot value evidence row kind is invalid.');
      if lKind = 3 then
      begin
        if (lOwner < 0) or (lOwner >= Length(Result.Owners)) then
          raise Exception.Create('Snapshot value evidence name owner is missing.');
        if (lItem <> lLoadedNames[lOwner]) or (lItem >= lNameCounts[lOwner]) then
          raise Exception.Create('Snapshot value evidence names are incomplete.');
        Result.Owners[lOwner].ValueNames[lItem] := lFields[6].AsWideString;
        Inc(lLoadedNames[lOwner]);
      end else if (lOwner <> -1) or (lItem <> lLoaded[lKind]) or
        (lLoaded[lKind] >= lCounts[lKind]) then
        raise Exception.Create('Snapshot value evidence rows are incomplete.');
      case lKind of
        1:
          begin
            Result.Units[lItem].UnitName := lFields[4].AsWideString;
            Result.Units[lItem].FileName := lFields[5].AsWideString;
            Result.Units[lItem].SourceText := lFields[10].AsWideString;
            Result.Units[lItem].VerifiedActiveSourceText := lFields[11].AsWideString;
            Result.Units[lItem].ScopeModelStatus := lFields[12].AsWideString;
            Result.Units[lItem].ScopeModelVersion := lFields[13].AsWideString;
            Result.Units[lItem].RejectedDeclarationCount := lFields[14].AsInteger;
          end;
        2:
          begin
            Result.Owners[lItem].DeclaredId := lFields[3].AsWideString;
            Result.Owners[lItem].UnitName := lFields[4].AsWideString;
            Result.Owners[lItem].FileName := lFields[5].AsWideString;
            Result.Owners[lItem].Name := lFields[6].AsWideString;
            Result.Owners[lItem].NextDeclaredId := lFields[7].AsWideString;
            Result.Owners[lItem].Complete := lFields[8].AsInteger = 1;
            Result.Owners[lItem].TerminalVerified := (lFields[9].AsInteger and 1) = 1;
            Result.Owners[lItem].UnindexedRoot := (lFields[9].AsInteger and 2) = 2;
            lNameCounts[lItem] := lFields[15].AsInteger;
            if (lNameCounts[lItem] < 0) or (lNameCounts[lItem] > lCounts[3]) then
              raise Exception.Create('Snapshot value evidence owner count is invalid.');
            SetLength(Result.Owners[lItem].ValueNames, lNameCounts[lItem]);
          end;
        4:
          begin
            Result.Queries[lItem].Name := lFields[6].AsWideString;
            Result.Queries[lItem].DeclaredId := lFields[3].AsWideString;
          end;
        5: Result.ValueNames[lItem] := lFields[6].AsWideString;
        6: Result.UnverifiedOwnerKeys[lItem] := lFields[6].AsWideString;
      end;
      Inc(lLoaded[lKind]);
      lQuery.Next;
    end;
    for i := 0 to 6 do
      if lLoaded[i] <> lCounts[i] then
        raise Exception.Create('Snapshot value evidence count mismatch.');
    for j := 0 to High(lNameCounts) do
      if lLoadedNames[j] <> lNameCounts[j] then
        raise Exception.Create('Snapshot value evidence owner names are incomplete.');
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadRemoveWithPlanningFacts(
  const aCacheKey: string; const aConnection: TObject;
  const aBuilder: TDelphiProjectSnapshotBuilder);
var
  i: Integer;
  lEntityKind: string;
  lBinding: TSemanticRemoveWithBindingFact;
  lBindingIndexField: TField;
  lBodyColumnField: TField;
  lBodyEndColumnField: TField;
  lBodyEndLineField: TField;
  lBodyLineField: TField;
  lColumnField: TField;
  lContextFingerprintIdField: TField;
  lEndColumnField: TField;
  lEndLineField: TField;
  lExternalReferenceCountField: TField;
  lExpectedBindingCount: Integer;
  lExpectedIdentityCount: Integer;
  lExpectedReferenceCount: Integer;
  lExpectedRoutineOwnerCount: Integer;
  lExpectedSelectorCount: Integer;
  lExpectedSymbolCount: Integer;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lEvidence: TDelphiSemanticValueMemberEvidence;
  lEvidenceUnit: TDelphiSemanticValueEvidenceUnit;
  lUnit: TUnitSnapshot;
  lUnitId: Integer;
  lFields: TArray<TField>;
  lFileNameIdField: TField;
  lFlagsField: TField;
  lIntrinsicReferenceCountField: TField;
  lIdentity: TSemanticRemoveWithTypeIdentityFact;
  lItemIndex: Integer;
  lLexicalReferenceCountField: TField;
  lLineField: TField;
  lLoadedBindingCount: Integer;
  lLoadedIdentityCount: Integer;
  lMemberReferenceCountField: TField;
  lProvenanceIdField: TField;
  lQuery: TFDQuery;
  lReferenceCountField: TField;
  lRoutineNameIdField: TField;
  lSelectorCountField: TField;
  lSelectorIndex: Integer;
  lSubIndex: Integer;
  lSelectorTextIdField: TField;
  lSemanticIdIdField: TField;
  lSkipReasonIdField: TField;
  lStatusIdField: TField;
  lStopwatch: TStopwatch;
  lUnitNameIdField: TField;
  lLoadedReferenceCount: Integer;
  lLoadedRoutineOwnerCount: Integer;
  lLoadedSelectorCount: Integer;
  lLoadedSymbolCount: Integer;
  lUnresolvedReferenceCountField: TField;
  lUnsupportedReferenceCountField: TField;
  lReferenceIndex: Integer;
  lReference: TSemanticRemoveWithBoundReferenceFact;

  function VerifiedLocalBindingScope(const aBinding: TSemanticRemoveWithBindingFact;
    const aOwnerScopeId: TSemanticStringId): Boolean;
  var
    lCurrentScopeId: TSemanticStringId;
    lMatchCount: Integer;
    lOwnerFound: Boolean;
    lRoutineOwner: TSemanticRemoveWithInventorySymbolFact;
    lSeen: TDictionary<TSemanticStringId, Byte>;
    lSelected: TSemanticRemoveWithInventorySymbolFact;
  begin
    Result := False;
    if (aBinding.RoutineScopeIdId = 0) or (aOwnerScopeId = 0) then
      Exit;
    lSeen := TDictionary<TSemanticStringId, Byte>.Create;
    try
      lCurrentScopeId := aBinding.RoutineScopeIdId;
      lOwnerFound := False;
      while lCurrentScopeId <> 0 do
      begin
        if lSeen.ContainsKey(lCurrentScopeId) then
          Exit;
        lSeen.Add(lCurrentScopeId, 0);
        lMatchCount := 0;
        lSelected := Default(TSemanticRemoveWithInventorySymbolFact);
        for lRoutineOwner in lFacts.RoutineOwners do
          if (lRoutineOwner.RoutineScopeIdId = lCurrentScopeId) and
            (lRoutineOwner.FileNameId = aBinding.FileNameId) and
            (lRoutineOwner.UnitNameId = aBinding.UnitNameId) then
          begin
            Inc(lMatchCount);
            lSelected := lRoutineOwner;
          end;
        if lMatchCount <> 1 then
          Exit;
        if lCurrentScopeId = aOwnerScopeId then
          lOwnerFound := True;
        lCurrentScopeId := lSelected.ParentScopeIdId;
      end;
      Result := lOwnerFound;
    finally
      lSeen.Free;
    end;
  end;
begin
  lQuery := NewQuery(aConnection as TFDConnection, 'select context_fingerprint_id, ' +
    'routine_owner_count, symbol_count, binding_count, type_identity_count ' +
    'from snapshot_remove_with_facts ' +
    'where cache_key = ?');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    if lQuery.Eof then
      Exit;

    lContextFingerprintIdField := lQuery.Fields[0];
    lExpectedRoutineOwnerCount := lQuery.Fields[1].AsInteger;
    lExpectedSymbolCount := lQuery.Fields[2].AsInteger;
    lExpectedBindingCount := lQuery.Fields[3].AsInteger;
    lExpectedIdentityCount := lQuery.Fields[4].AsInteger;
    if lExpectedIdentityCount < 0 then
      raise Exception.Create('Snapshot remove-with type identity row count is negative.');
    lFacts := Default(TSemanticRemoveWithPlanningFacts);
    lFacts.ContextFingerprintId := TSemanticStringId(lContextFingerprintIdField.AsInteger);
    SetLength(lFacts.RoutineOwners, lExpectedRoutineOwnerCount);
    SetLength(lFacts.Symbols, lExpectedSymbolCount);
    SetLength(lFacts.Bindings, lExpectedBindingCount);
  finally
    lQuery.Free;
  end;

  lQuery := NewQuery(aConnection as TFDConnection, 'select name_id, symbol_class_id, kind_id, ' +
    'type_name_id, modifier_id, owner_name_id, owner_type_id, source_owner_type_id, ' +
    'related_type_name_id, routine_name_id, unit_name_id, file_name_id, section_kind_id, ' +
    'line, column, end_line, end_column, unsupported_reason_id, flags, ' +
    'index_parameter_count, type_category_id, item_index, routine_scope_id_id, ' +
    'parent_scope_id_id, owner_scope_id_id, owner_symbol_id_id, ' +
    'access_owner_unit_name_id, ' +
    'access_owner_file_name_id, ' +
    'access_owner_section_kind_id, ' +
    'access_owner_line, ' +
    'access_owner_column, heading_line, heading_column, heading_end_line, heading_end_column ' +
    'from snapshot_remove_with_routine_owners ' +
    'where cache_key = ? order by item_index');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    CacheQueryFields(lQuery, lFields);
    lLoadedRoutineOwnerCount := 0;
    while not lQuery.Eof do
    begin
      lItemIndex := lFields[21].AsInteger;
      if (lItemIndex < 0) or (lItemIndex >= lExpectedRoutineOwnerCount) then
        raise Exception.Create('Snapshot remove-with routine owner row count mismatch.');
      lFacts.RoutineOwners[lItemIndex].NameId := TSemanticStringId(lFields[0].AsInteger);
      lFacts.RoutineOwners[lItemIndex].SymbolClassId := TSemanticStringId(lFields[1].AsInteger);
      lFacts.RoutineOwners[lItemIndex].KindId := TSemanticStringId(lFields[2].AsInteger);
      lFacts.RoutineOwners[lItemIndex].TypeNameId := TSemanticStringId(lFields[3].AsInteger);
      lFacts.RoutineOwners[lItemIndex].ModifierId := TSemanticStringId(lFields[4].AsInteger);
      lFacts.RoutineOwners[lItemIndex].OwnerNameId := TSemanticStringId(lFields[5].AsInteger);
      lFacts.RoutineOwners[lItemIndex].OwnerTypeId := TSemanticStringId(lFields[6].AsInteger);
      lFacts.RoutineOwners[lItemIndex].SourceOwnerTypeId := TSemanticStringId(lFields[7].AsInteger);
      lFacts.RoutineOwners[lItemIndex].RelatedTypeNameId := TSemanticStringId(lFields[8].AsInteger);
      lFacts.RoutineOwners[lItemIndex].RoutineNameId := TSemanticStringId(lFields[9].AsInteger);
      lFacts.RoutineOwners[lItemIndex].UnitNameId := TSemanticStringId(lFields[10].AsInteger);
      lFacts.RoutineOwners[lItemIndex].FileNameId := TSemanticStringId(lFields[11].AsInteger);
      lFacts.RoutineOwners[lItemIndex].SectionKindId := TSemanticStringId(lFields[12].AsInteger);
      lFacts.RoutineOwners[lItemIndex].Line := lFields[13].AsInteger;
      lFacts.RoutineOwners[lItemIndex].Column := lFields[14].AsInteger;
      lFacts.RoutineOwners[lItemIndex].EndLine := lFields[15].AsInteger;
      lFacts.RoutineOwners[lItemIndex].EndColumn := lFields[16].AsInteger;
      lFacts.RoutineOwners[lItemIndex].UnsupportedReasonId := TSemanticStringId(lFields[17].AsInteger);
      lFacts.RoutineOwners[lItemIndex].Flags := Cardinal(lFields[18].AsInteger);
      lFacts.RoutineOwners[lItemIndex].IndexParameterCount := lFields[19].AsInteger;
      lFacts.RoutineOwners[lItemIndex].TypeCategoryId := TSemanticStringId(lFields[20].AsInteger);
      lFacts.RoutineOwners[lItemIndex].RoutineScopeIdId := TSemanticStringId(lFields[22].AsInteger);
      lFacts.RoutineOwners[lItemIndex].ParentScopeIdId := TSemanticStringId(lFields[23].AsInteger);
      lFacts.RoutineOwners[lItemIndex].OwnerScopeIdId := TSemanticStringId(lFields[24].AsInteger);
      lFacts.RoutineOwners[lItemIndex].OwnerSymbolIdId := TSemanticStringId(lFields[25].AsInteger);
      lFacts.RoutineOwners[lItemIndex].AccessOwnerUnitNameId := TSemanticStringId(lFields[26].AsInteger);
      lFacts.RoutineOwners[lItemIndex].AccessOwnerFileNameId := TSemanticStringId(lFields[27].AsInteger);
      lFacts.RoutineOwners[lItemIndex].AccessOwnerSectionKindId := TSemanticStringId(lFields[28].AsInteger);
      lFacts.RoutineOwners[lItemIndex].AccessOwnerLine := lFields[29].AsInteger;
      lFacts.RoutineOwners[lItemIndex].AccessOwnerColumn := lFields[30].AsInteger;
      lFacts.RoutineOwners[lItemIndex].HeadingLine := lFields[31].AsInteger;
      lFacts.RoutineOwners[lItemIndex].HeadingColumn := lFields[32].AsInteger;
      lFacts.RoutineOwners[lItemIndex].HeadingEndLine := lFields[33].AsInteger;
      lFacts.RoutineOwners[lItemIndex].HeadingEndColumn := lFields[34].AsInteger;
      Inc(lLoadedRoutineOwnerCount);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
  if lLoadedRoutineOwnerCount <> lExpectedRoutineOwnerCount then
    raise Exception.Create('Snapshot remove-with routine owner row count mismatch.');

  lQuery := NewQuery(aConnection as TFDConnection, 'select name_id, symbol_class_id, kind_id, ' +
    'type_name_id, modifier_id, owner_name_id, owner_type_id, source_owner_type_id, ' +
    'related_type_name_id, routine_name_id, unit_name_id, file_name_id, section_kind_id, ' +
    'line, column, end_line, end_column, unsupported_reason_id, flags, ' +
    'index_parameter_count, type_category_id, item_index, routine_scope_id_id, ' +
    'parent_scope_id_id, owner_scope_id_id, owner_symbol_id_id, ' +
    'access_owner_unit_name_id, ' +
    'access_owner_file_name_id, ' +
    'access_owner_section_kind_id, ' +
    'access_owner_line, ' +
    'access_owner_column, heading_line, heading_column, heading_end_line, heading_end_column ' +
    'from snapshot_remove_with_symbols ' +
    'where cache_key = ? order by item_index');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    CacheQueryFields(lQuery, lFields);
    lLoadedSymbolCount := 0;
    while not lQuery.Eof do
    begin
      lItemIndex := lFields[21].AsInteger;
      if (lItemIndex < 0) or (lItemIndex >= lExpectedSymbolCount) then
        raise Exception.Create('Snapshot remove-with symbol row count mismatch.');
      lFacts.Symbols[lItemIndex].NameId := TSemanticStringId(lFields[0].AsInteger);
      lFacts.Symbols[lItemIndex].SymbolClassId := TSemanticStringId(lFields[1].AsInteger);
      lFacts.Symbols[lItemIndex].KindId := TSemanticStringId(lFields[2].AsInteger);
      lFacts.Symbols[lItemIndex].TypeNameId := TSemanticStringId(lFields[3].AsInteger);
      lFacts.Symbols[lItemIndex].ModifierId := TSemanticStringId(lFields[4].AsInteger);
      lFacts.Symbols[lItemIndex].OwnerNameId := TSemanticStringId(lFields[5].AsInteger);
      lFacts.Symbols[lItemIndex].OwnerTypeId := TSemanticStringId(lFields[6].AsInteger);
      lFacts.Symbols[lItemIndex].SourceOwnerTypeId := TSemanticStringId(lFields[7].AsInteger);
      lFacts.Symbols[lItemIndex].RelatedTypeNameId := TSemanticStringId(lFields[8].AsInteger);
      lFacts.Symbols[lItemIndex].RoutineNameId := TSemanticStringId(lFields[9].AsInteger);
      lFacts.Symbols[lItemIndex].UnitNameId := TSemanticStringId(lFields[10].AsInteger);
      lFacts.Symbols[lItemIndex].FileNameId := TSemanticStringId(lFields[11].AsInteger);
      lFacts.Symbols[lItemIndex].SectionKindId := TSemanticStringId(lFields[12].AsInteger);
      lFacts.Symbols[lItemIndex].Line := lFields[13].AsInteger;
      lFacts.Symbols[lItemIndex].Column := lFields[14].AsInteger;
      lFacts.Symbols[lItemIndex].EndLine := lFields[15].AsInteger;
      lFacts.Symbols[lItemIndex].EndColumn := lFields[16].AsInteger;
      lFacts.Symbols[lItemIndex].RoutineScopeIdId := TSemanticStringId(lFields[22].AsInteger);
      lFacts.Symbols[lItemIndex].ParentScopeIdId := TSemanticStringId(lFields[23].AsInteger);
      lFacts.Symbols[lItemIndex].OwnerScopeIdId := TSemanticStringId(lFields[24].AsInteger);
      lFacts.Symbols[lItemIndex].OwnerSymbolIdId := TSemanticStringId(lFields[25].AsInteger);
      lFacts.Symbols[lItemIndex].AccessOwnerUnitNameId := TSemanticStringId(lFields[26].AsInteger);
      lFacts.Symbols[lItemIndex].AccessOwnerFileNameId := TSemanticStringId(lFields[27].AsInteger);
      lFacts.Symbols[lItemIndex].AccessOwnerSectionKindId := TSemanticStringId(lFields[28].AsInteger);
      lFacts.Symbols[lItemIndex].AccessOwnerLine := lFields[29].AsInteger;
      lFacts.Symbols[lItemIndex].AccessOwnerColumn := lFields[30].AsInteger;
      lFacts.Symbols[lItemIndex].HeadingLine := lFields[31].AsInteger;
      lFacts.Symbols[lItemIndex].HeadingColumn := lFields[32].AsInteger;
      lFacts.Symbols[lItemIndex].HeadingEndLine := lFields[33].AsInteger;
      lFacts.Symbols[lItemIndex].HeadingEndColumn := lFields[34].AsInteger;
      if SameText(aBuilder.ExactStrings.TextOf(lFacts.Symbols[lItemIndex].SymbolClassId),
        'local') or SameText(aBuilder.ExactStrings.TextOf(
        lFacts.Symbols[lItemIndex].SymbolClassId), 'parameter') then
        if lFacts.Symbols[lItemIndex].RoutineScopeIdId = 0 then
          raise Exception.Create('Snapshot routine symbol has no source scope.');
      if SameText(aBuilder.ExactStrings.TextOf(lFacts.Symbols[lItemIndex].SymbolClassId),
        'declaration') and (lFacts.Symbols[lItemIndex].OwnerScopeIdId <> 0) and
        (lFacts.Symbols[lItemIndex].OwnerSymbolIdId = 0) then
        raise Exception.Create('Snapshot local declaration has no source symbol.');
      lFacts.Symbols[lItemIndex].UnsupportedReasonId := TSemanticStringId(lFields[17].AsInteger);
      lFacts.Symbols[lItemIndex].Flags := Cardinal(lFields[18].AsInteger);
      lFacts.Symbols[lItemIndex].IndexParameterCount := lFields[19].AsInteger;
      lFacts.Symbols[lItemIndex].TypeCategoryId := TSemanticStringId(lFields[20].AsInteger);
      Inc(lLoadedSymbolCount);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
  if lLoadedSymbolCount <> lExpectedSymbolCount then
    raise Exception.Create('Snapshot remove-with symbol row count mismatch.');

  lQuery := NewQuery(aConnection as TFDConnection, 'select binding_index, semantic_id_id, ' +
    'provenance_id, file_name_id, unit_name_id, routine_name_id, line, column, end_line, ' +
    'end_column, body_line, body_column, body_end_line, body_end_column, selector_text_id, ' +
    'status_id, skip_reason_id, flags, member_reference_count, lexical_reference_count, ' +
    'external_reference_count, intrinsic_reference_count, unsupported_reference_count, ' +
    'unresolved_reference_count, selector_count, reference_count, routine_scope_id_id, ' +
    'inactive_reference_count, inactive_skip_reason_id ' +
    'from snapshot_remove_with_bindings ' +
    'where cache_key = ? order by binding_index');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lBindingIndexField := lQuery.Fields[0];
    lSemanticIdIdField := lQuery.Fields[1];
    lProvenanceIdField := lQuery.Fields[2];
    lFileNameIdField := lQuery.Fields[3];
    lUnitNameIdField := lQuery.Fields[4];
    lRoutineNameIdField := lQuery.Fields[5];
    lLineField := lQuery.Fields[6];
    lColumnField := lQuery.Fields[7];
    lEndLineField := lQuery.Fields[8];
    lEndColumnField := lQuery.Fields[9];
    lBodyLineField := lQuery.Fields[10];
    lBodyColumnField := lQuery.Fields[11];
    lBodyEndLineField := lQuery.Fields[12];
    lBodyEndColumnField := lQuery.Fields[13];
    lSelectorTextIdField := lQuery.Fields[14];
    lStatusIdField := lQuery.Fields[15];
    lSkipReasonIdField := lQuery.Fields[16];
    lFlagsField := lQuery.Fields[17];
    lMemberReferenceCountField := lQuery.Fields[18];
    lLexicalReferenceCountField := lQuery.Fields[19];
    lExternalReferenceCountField := lQuery.Fields[20];
    lIntrinsicReferenceCountField := lQuery.Fields[21];
    lUnsupportedReferenceCountField := lQuery.Fields[22];
    lUnresolvedReferenceCountField := lQuery.Fields[23];
    lSelectorCountField := lQuery.Fields[24];
    lReferenceCountField := lQuery.Fields[25];
    lExpectedSelectorCount := 0;
    lExpectedReferenceCount := 0;
    lLoadedBindingCount := 0;
    while not lQuery.Eof do
    begin
      i := lBindingIndexField.AsInteger;
      if (i < 0) or (i >= lExpectedBindingCount) then
        raise Exception.Create('Snapshot remove-with binding row count mismatch.');
      lBinding := Default(TSemanticRemoveWithBindingFact);
      lBinding.SemanticIdId := TSemanticStringId(lSemanticIdIdField.AsInteger);
      lBinding.ProvenanceId := TSemanticStringId(lProvenanceIdField.AsInteger);
      lBinding.FileNameId := TSemanticStringId(lFileNameIdField.AsInteger);
      lBinding.UnitNameId := TSemanticStringId(lUnitNameIdField.AsInteger);
      lBinding.RoutineNameId := TSemanticStringId(lRoutineNameIdField.AsInteger);
      lBinding.RoutineScopeIdId := TSemanticStringId(lQuery.Fields[26].AsInteger);
      lBinding.Line := lLineField.AsInteger;
      lBinding.Column := lColumnField.AsInteger;
      lBinding.EndLine := lEndLineField.AsInteger;
      lBinding.EndColumn := lEndColumnField.AsInteger;
      lBinding.BodyLine := lBodyLineField.AsInteger;
      lBinding.BodyColumn := lBodyColumnField.AsInteger;
      lBinding.BodyEndLine := lBodyEndLineField.AsInteger;
      lBinding.BodyEndColumn := lBodyEndColumnField.AsInteger;
      lBinding.SelectorTextId := TSemanticStringId(lSelectorTextIdField.AsInteger);
      lBinding.StatusId := TSemanticStringId(lStatusIdField.AsInteger);
      lBinding.SkipReasonId := TSemanticStringId(lSkipReasonIdField.AsInteger);
      lBinding.Flags := Cardinal(lFlagsField.AsInteger);
      lBinding.MemberReferenceCount := lMemberReferenceCountField.AsInteger;
      lBinding.LexicalReferenceCount := lLexicalReferenceCountField.AsInteger;
      lBinding.ExternalReferenceCount := lExternalReferenceCountField.AsInteger;
      lBinding.IntrinsicReferenceCount := lIntrinsicReferenceCountField.AsInteger;
      lBinding.UnsupportedReferenceCount := lUnsupportedReferenceCountField.AsInteger;
      lBinding.UnresolvedReferenceCount := lUnresolvedReferenceCountField.AsInteger;
      SetLength(lBinding.Selectors, lSelectorCountField.AsInteger);
      SetLength(lBinding.References, lReferenceCountField.AsInteger);
      SetLength(lBinding.InactiveSpanReferences, lQuery.Fields[27].AsInteger);
      lBinding.InactiveSpanSkipReasonId := TSemanticStringId(lQuery.Fields[28].AsInteger);
      Inc(lExpectedSelectorCount, lSelectorCountField.AsInteger);
      Inc(lExpectedReferenceCount, lReferenceCountField.AsInteger + lQuery.Fields[27].AsInteger);
      lFacts.Bindings[i] := lBinding;
      Inc(lLoadedBindingCount);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
  if lLoadedBindingCount <> lExpectedBindingCount then
    raise Exception.Create('Snapshot remove-with binding row count mismatch.');

  lQuery := NewQuery(aConnection as TFDConnection, 'select binding_index, selector_index, ' +
    'selector_text_id, status_id, reason_code_id, type_name_id, capture_type_name_id, ' +
    'capture_status_id from ' +
    'snapshot_remove_with_binding_selectors where cache_key = ? order by binding_index, selector_index');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    CacheQueryFields(lQuery, lFields);
    lLoadedSelectorCount := 0;
    while not lQuery.Eof do
    begin
      i := lFields[0].AsInteger;
      lSelectorIndex := lFields[1].AsInteger;
      lFacts.Bindings[i].Selectors[lSelectorIndex].SelectorTextId :=
        TSemanticStringId(lFields[2].AsInteger);
      lFacts.Bindings[i].Selectors[lSelectorIndex].StatusId :=
        TSemanticStringId(lFields[3].AsInteger);
      lFacts.Bindings[i].Selectors[lSelectorIndex].ReasonCodeId :=
        TSemanticStringId(lFields[4].AsInteger);
      lFacts.Bindings[i].Selectors[lSelectorIndex].TypeNameId :=
        TSemanticStringId(lFields[5].AsInteger);
      lFacts.Bindings[i].Selectors[lSelectorIndex].CaptureTypeNameId :=
        TSemanticStringId(lFields[6].AsInteger);
      lFacts.Bindings[i].Selectors[lSelectorIndex].CaptureTypeStatusId :=
        TSemanticStringId(lFields[7].AsInteger);
      Inc(lLoadedSelectorCount);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
  if lLoadedSelectorCount <> lExpectedSelectorCount then
    raise Exception.Create('Snapshot remove-with selector row count mismatch.');

  lQuery := NewQuery(aConnection as TFDConnection, 'select binding_index, reference_index, ' +
    'semantic_id_id, name_id, classification_id, lookup_source_id, receiver_type_name_id, ' +
    'kind_id, type_name_id, reason_code_id, scope_conflict_kind_id, scope_conflict_name_id, ' +
    'line, column, end_line, end_column from snapshot_remove_with_binding_references ' +
    'where cache_key = ? order by binding_index, reference_index');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    CacheQueryFields(lQuery, lFields);
    lLoadedReferenceCount := 0;
    while not lQuery.Eof do
    begin
      i := lFields[0].AsInteger;
      lReferenceIndex := lFields[1].AsInteger;
      lReference := Default(TSemanticRemoveWithBoundReferenceFact);
      lReference.SemanticIdId :=
        TSemanticStringId(lFields[2].AsInteger);
      lReference.NameId :=
        TSemanticStringId(lFields[3].AsInteger);
      lReference.ClassificationId :=
        TSemanticStringId(lFields[4].AsInteger);
      lReference.LookupSourceId :=
        TSemanticStringId(lFields[5].AsInteger);
      lReference.ReceiverTypeNameId :=
        TSemanticStringId(lFields[6].AsInteger);
      lReference.KindId :=
        TSemanticStringId(lFields[7].AsInteger);
      lReference.TypeNameId :=
        TSemanticStringId(lFields[8].AsInteger);
      lReference.ReasonCodeId :=
        TSemanticStringId(lFields[9].AsInteger);
      lReference.ScopeConflictKindId :=
        TSemanticStringId(lFields[10].AsInteger);
      lReference.ScopeConflictNameId :=
        TSemanticStringId(lFields[11].AsInteger);
      lReference.Line := lFields[12].AsInteger;
      lReference.Column := lFields[13].AsInteger;
      lReference.EndLine := lFields[14].AsInteger;
      lReference.EndColumn := lFields[15].AsInteger;
      if lReferenceIndex < 0 then
        lFacts.Bindings[i].InactiveSpanReferences[-lReferenceIndex - 1] := lReference
      else
        lFacts.Bindings[i].References[lReferenceIndex] := lReference;
      Inc(lLoadedReferenceCount);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
  if lLoadedReferenceCount <> lExpectedReferenceCount then
    raise Exception.Create('Snapshot remove-with reference row count mismatch.');

  lQuery := NewQuery(aConnection as TFDConnection,
    'select entity_kind, item_index, sub_index, unit_id_id, unit_name_id, ' +
    'name_id, kind_id, declared_id_id, canonical_id_id, underlying_id_id, ' +
    'canonical_name_id, underlying_name_id, base_type_name_id, helper_target_name_id, ' +
    'section_kind_id, file_name_id, line, column, end_line, end_column, ' +
    'scope_kind_id, owner_scope_id_id, semantic_symbol_id_id from ' +
    'snapshot_remove_with_type_identities where cache_key = ?');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    CacheQueryFields(lQuery, lFields);
    lLoadedIdentityCount := 0;
    while not lQuery.Eof do
    begin
      lEntityKind := lFields[0].AsWideString;
      lItemIndex := lFields[1].AsInteger;
      lSubIndex := lFields[2].AsInteger;
      lIdentity := Default(TSemanticRemoveWithTypeIdentityFact);
      lIdentity.UnitIdId := TSemanticStringId(lFields[3].AsInteger);
      lIdentity.UnitNameId := TSemanticStringId(lFields[4].AsInteger);
      lIdentity.NameId := TSemanticStringId(lFields[5].AsInteger);
      lIdentity.KindId := TSemanticStringId(lFields[6].AsInteger);
      lIdentity.DeclaredIdId := TSemanticStringId(lFields[7].AsInteger);
      lIdentity.CanonicalIdId := TSemanticStringId(lFields[8].AsInteger);
      lIdentity.UnderlyingIdId := TSemanticStringId(lFields[9].AsInteger);
      lIdentity.CanonicalNameId := TSemanticStringId(lFields[10].AsInteger);
      lIdentity.UnderlyingNameId := TSemanticStringId(lFields[11].AsInteger);
      lIdentity.BaseTypeNameId := TSemanticStringId(lFields[12].AsInteger);
      lIdentity.HelperTargetNameId := TSemanticStringId(lFields[13].AsInteger);
      lIdentity.SectionKindId := TSemanticStringId(lFields[14].AsInteger);
      lIdentity.FileNameId := TSemanticStringId(lFields[15].AsInteger);
      lIdentity.Line := lFields[16].AsInteger;
      lIdentity.Column := lFields[17].AsInteger;
      lIdentity.EndLine := lFields[18].AsInteger;
      lIdentity.EndColumn := lFields[19].AsInteger;
      lIdentity.ScopeKindId := TSemanticStringId(lFields[20].AsInteger);
      lIdentity.OwnerScopeIdId := TSemanticStringId(lFields[21].AsInteger);
      lIdentity.SemanticSymbolIdId := TSemanticStringId(lFields[22].AsInteger);
      ValidateStringId(aBuilder.ExactStrings, lIdentity.ScopeKindId,
        'remove-with scope kind');
      ValidateStringId(aBuilder.ExactStrings, lIdentity.OwnerScopeIdId,
        'remove-with owner scope');
      ValidateStringId(aBuilder.ExactStrings, lIdentity.SemanticSymbolIdId,
        'remove-with declaration symbol');
      if (lIdentity.UnitIdId = 0) or (lIdentity.UnitNameId = 0) or
        (lIdentity.NameId = 0) or (lIdentity.DeclaredIdId = 0) or
        (lIdentity.CanonicalIdId = 0) or (lIdentity.FileNameId = 0) or
        (lIdentity.Line <= 0) or (lIdentity.Column <= 0) then
        raise Exception.Create('Snapshot remove-with type identity is incomplete.');
      if SameText(aBuilder.ExactStrings.TextOf(lIdentity.ScopeKindId), 'routine') and
        ((lIdentity.OwnerScopeIdId = 0) or
          (lIdentity.SemanticSymbolIdId = 0) or
          (lIdentity.UnderlyingIdId = 0)) then
        raise Exception.Create('Snapshot local type identity has no declaring scope.');
      if SameText(lEntityKind, 'routine-owner') and (lSubIndex = 0) and
        (lItemIndex >= 0) and (lItemIndex < Length(lFacts.RoutineOwners)) and
        (lFacts.RoutineOwners[lItemIndex].OwnerIdentity.DeclaredIdId = 0) then
        lFacts.RoutineOwners[lItemIndex].OwnerIdentity := lIdentity
      else if SameText(lEntityKind, 'symbol') and (lSubIndex = 0) and
        (lItemIndex >= 0) and (lItemIndex < Length(lFacts.Symbols)) and
        (lFacts.Symbols[lItemIndex].OwnerIdentity.DeclaredIdId = 0) then
        lFacts.Symbols[lItemIndex].OwnerIdentity := lIdentity
      else if SameText(lEntityKind, 'symbol-access-owner') and (lSubIndex = 0) and
        (lItemIndex >= 0) and (lItemIndex < Length(lFacts.Symbols)) and
        (lFacts.Symbols[lItemIndex].AccessOwnerIdentity.DeclaredIdId = 0) then
        lFacts.Symbols[lItemIndex].AccessOwnerIdentity := lIdentity
      else if SameText(lEntityKind, 'selector') and
        (lItemIndex >= 0) and (lItemIndex < Length(lFacts.Bindings)) and
        (lSubIndex >= 0) and (lSubIndex < Length(lFacts.Bindings[lItemIndex].Selectors)) and
        (lFacts.Bindings[lItemIndex].Selectors[lSubIndex].TypeIdentity.DeclaredIdId = 0) then
        lFacts.Bindings[lItemIndex].Selectors[lSubIndex].TypeIdentity := lIdentity
      else if SameText(lEntityKind, 'selector-capture') and
        (lItemIndex >= 0) and (lItemIndex < Length(lFacts.Bindings)) and
        (lSubIndex >= 0) and (lSubIndex < Length(lFacts.Bindings[lItemIndex].Selectors)) and
        (lFacts.Bindings[lItemIndex].Selectors[lSubIndex].CaptureTypeIdentity.DeclaredIdId = 0) then
        lFacts.Bindings[lItemIndex].Selectors[lSubIndex].CaptureTypeIdentity := lIdentity
      else
        raise Exception.Create('Snapshot remove-with type identity row is unexpected.');
      Inc(lLoadedIdentityCount);
      lQuery.Next;
    end;
  finally
    lQuery.Free;
  end;
  if lLoadedIdentityCount <> lExpectedIdentityCount then
    raise Exception.Create('Snapshot remove-with type identity row count mismatch.');

  for i := 0 to High(lFacts.Bindings) do
    for lSelectorIndex := 0 to High(lFacts.Bindings[i].Selectors) do
    begin
      lIdentity := lFacts.Bindings[i].Selectors[lSelectorIndex].TypeIdentity;
      if SameText(aBuilder.ExactStrings.TextOf(lIdentity.ScopeKindId), 'routine') and
        not VerifiedLocalBindingScope(lFacts.Bindings[i], lIdentity.OwnerScopeIdId) then
        raise Exception.Create('Snapshot local receiver scope chain is incomplete.');
    end;

  lEvidence := LoadValueMemberEvidence(aCacheKey, aConnection);
  if not lFacts.LookupIndex.IsAvailable then
    lFacts.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build([],
      LoadedInventorySymbols(aBuilder.ExactStrings, lFacts.Symbols));
  lFacts.LookupIndex.AttachValueMemberEvidence(lEvidence);
  lUnitId := 0;
  for lEvidenceUnit in lEvidence.Units do
  begin
    Inc(lUnitId);
    lUnit := TUnitSnapshot.Create(TSemanticUnitId(lUnitId),
      aBuilder.Strings.Intern(lEvidenceUnit.FileName), aBuilder.Strings.Intern(lEvidenceUnit.UnitName),
      aBuilder.ExactStrings.Intern(lEvidenceUnit.SourceText));
    try
      lUnit.SetVerifiedActiveSourceTextId(
        aBuilder.ExactStrings.Intern(lEvidenceUnit.VerifiedActiveSourceText));
      lUnit.SetScopeModelMetadata(aBuilder.Strings.Intern(lEvidenceUnit.ScopeModelStatus),
        aBuilder.Strings.Intern(lEvidenceUnit.ScopeModelVersion), 0, lEvidenceUnit.RejectedDeclarationCount);
      aBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;
  end;
  aBuilder.SetRemoveWithPlanningFactsOwned(lFacts);
end;

function TDelphiSemanticSnapshotSqliteCache.LoadUnitHeader(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  out aUnit: TUnitSnapshot; out aStringCount, aSymbolCount, aWithStatementCount,
  aReferenceCount: Integer; out aParseAvoidedEstimateMilliseconds: Int64): Boolean;
var
  lFileNameIdField: TField;
  lParseAvoidedEstimateMillisecondsField: TField;
  lQuery: TFDDataSet;
  lRejectedDeclarationCountField: TField;
  lReferenceCountField: TField;
  lScopeDiagnosticIdField: TField;
  lScopeModelStatusIdField: TField;
  lScopeModelVersionIdField: TField;
  lSourceTextIdField: TField;
  lStopwatch: TStopwatch;
  lStringCountField: TField;
  lSymbolCountField: TField;
  lUnitIdField: TField;
  lUnitNameIdField: TField;
  lWithStatementCountField: TField;
begin
  aUnit := nil;
  aStringCount := 0;
  aSymbolCount := 0;
  aWithStatementCount := 0;
  aReferenceCount := 0;
  aParseAvoidedEstimateMilliseconds := 0;
  lQuery := NewUnitReadQuery(aConnection, aIdentity.CacheKey, 'snapshot_units', 'select unit_id, file_name_id, unit_name_id, ' +
    'source_text_id, scope_model_status_id, scope_model_version_id, scope_diagnostic_id, ' +
    'rejected_declaration_count, string_count, symbol_count, with_statement_count, ' +
    'reference_count, parse_avoided_estimate_ms, verified_active_source_text_id ' +
    'from snapshot_units where cache_key = ? ' +
    'and identity_key = ?') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      TFDQuery(lQuery).Params[0].AsWideString := aIdentity.CacheKey;
    if lQuery is TFDQuery then
      TFDQuery(lQuery).Params[1].AsWideString := aIdentity.IdentityKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lStopwatch := TStopwatch.StartNew;
    Result := not lQuery.Eof;
    if Result and (fUnitLoadBatch <> nil) then
      Result := lQuery.Fields[14].AsWideString = aIdentity.IdentityKey;
    if Result then
    begin
      lUnitIdField := lQuery.Fields[0];
      lFileNameIdField := lQuery.Fields[1];
      lUnitNameIdField := lQuery.Fields[2];
      lSourceTextIdField := lQuery.Fields[3];
      lScopeModelStatusIdField := lQuery.Fields[4];
      lScopeModelVersionIdField := lQuery.Fields[5];
      lScopeDiagnosticIdField := lQuery.Fields[6];
      lRejectedDeclarationCountField := lQuery.Fields[7];
      lStringCountField := lQuery.Fields[8];
      lSymbolCountField := lQuery.Fields[9];
      lWithStatementCountField := lQuery.Fields[10];
      lReferenceCountField := lQuery.Fields[11];
      lParseAvoidedEstimateMillisecondsField := lQuery.Fields[12];
      aUnit := TUnitSnapshot.Create(TSemanticUnitId(CheckedCacheInteger(lUnitIdField, 0, High(Cardinal))),
        TSemanticStringId(CheckedCacheInteger(lFileNameIdField, 0, High(Cardinal))),
        TSemanticStringId(CheckedCacheInteger(lUnitNameIdField, 0, High(Cardinal))),
        TSemanticStringId(CheckedCacheInteger(lSourceTextIdField, 0, High(Cardinal))));
      aUnit.SetVerifiedActiveSourceTextId(TSemanticStringId(CheckedCacheInteger(lQuery.Fields[13], 0, High(Cardinal))));
      aUnit.SetScopeModelMetadata(
        TSemanticStringId(CheckedCacheInteger(lScopeModelStatusIdField, 0, High(Cardinal))),
        TSemanticStringId(CheckedCacheInteger(lScopeModelVersionIdField, 0, High(Cardinal))),
        TSemanticStringId(CheckedCacheInteger(lScopeDiagnosticIdField, 0, High(Cardinal))),
        CheckedCacheInteger(lRejectedDeclarationCountField, 0, MaxInt));
      aStringCount := CheckedCacheInteger(lStringCountField, 0, MaxInt);
      aSymbolCount := CheckedCacheInteger(lSymbolCountField, 0, MaxInt);
      aWithStatementCount := CheckedCacheInteger(lWithStatementCountField, 0, MaxInt);
      aReferenceCount := CheckedCacheInteger(lReferenceCountField, 0, MaxInt);
      aParseAvoidedEstimateMilliseconds := CheckedCacheInteger(lParseAvoidedEstimateMillisecondsField, 0, High(Int64));
    end;
    Inc(fMetrics.SnapshotDeserializeMilliseconds, lStopwatch.ElapsedMilliseconds);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadWithStatements(const aCacheKey: string;
  const aConnection: TObject; const aUnit: TUnitSnapshot);
var
  lBodyEndColumnField: TField;
  lBodyEndLineField: TField;
  lBodyStartColumnField: TField;
  lBodyStartLineField: TField;
  lExpectedId: TSemanticWithId;
  lFlagsField: TField;
  lQuery: TFDQuery;
  lUnitIdField: TField;
  lRoutineIdField: TField;
  lSelectorStartColumnField: TField;
  lSelectorStartLineField: TField;
  lStopwatch: TStopwatch;
  lWith: TSemanticWithStatementFact;
  lWithIdField: TField;
  lWithId: TSemanticWithId;
begin
  lExpectedId := 1;
  lQuery := NewQuery(aConnection as TFDConnection, 'select with_id, routine_id, ' +
    'selector_start_line, selector_start_column, body_start_line, body_start_column, ' +
    'body_end_line, body_end_column, flags, unit_id from snapshot_with_statements where cache_key = ? ' +
    'order by with_id');
  try
    lQuery.Params[0].AsWideString := aCacheKey;
    lStopwatch := TStopwatch.StartNew;
    lQuery.Open;
    lQuery.FetchAll;
    Inc(fMetrics.SnapshotSqlReadMilliseconds, VisibleElapsedMilliseconds(lStopwatch));
    lWithIdField := lQuery.Fields[0];
    lRoutineIdField := lQuery.Fields[1];
    lSelectorStartLineField := lQuery.Fields[2];
    lSelectorStartColumnField := lQuery.Fields[3];
    lBodyStartLineField := lQuery.Fields[4];
    lBodyStartColumnField := lQuery.Fields[5];
    lBodyEndLineField := lQuery.Fields[6];
    lBodyEndColumnField := lQuery.Fields[7];
    lFlagsField := lQuery.Fields[8];
    lStopwatch := TStopwatch.StartNew;
    lUnitIdField := lQuery.Fields[9];
    while not lQuery.Eof do
    begin
      if CheckedCacheInteger(lUnitIdField, 1, High(Cardinal)) <> aUnit.UnitId then
        raise EInvalidOpException.Create('SNAPSHOT_CHILD_UNIT_INVALID');
      if TSemanticWithId(CheckedCacheInteger(lWithIdField, 0, High(Cardinal))) <> lExpectedId then
        raise Exception.Create('Snapshot with IDs are not dense.');

      lWith := Default(TSemanticWithStatementFact);
      lWith.RoutineId := TSemanticStringId(CheckedCacheInteger(lRoutineIdField, 0, High(Cardinal)));
      lWith.SelectorStartLine := CheckedCacheInteger(lSelectorStartLineField, 0, MaxInt);
      lWith.SelectorStartColumn := CheckedCacheInteger(lSelectorStartColumnField, 0, MaxInt);
      lWith.BodyStartLine := CheckedCacheInteger(lBodyStartLineField, 0, MaxInt);
      lWith.BodyStartColumn := CheckedCacheInteger(lBodyStartColumnField, 0, MaxInt);
      lWith.BodyEndLine := CheckedCacheInteger(lBodyEndLineField, 0, MaxInt);
      lWith.BodyEndColumn := CheckedCacheInteger(lBodyEndColumnField, 0, MaxInt);
      lWith.Flags := Cardinal(CheckedCacheInteger(lFlagsField, 0, High(Cardinal)));
      lWithId := aUnit.AddWithStatement(lWith);
      if lWithId <> lExpectedId then
        raise Exception.Create('Snapshot with ID rebuild mismatch.');
      Inc(lExpectedId);
      lQuery.Next;
    end;
    Inc(fMetrics.SnapshotDeserializeMilliseconds, lStopwatch.ElapsedMilliseconds);
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
  lPhysicalFileName: string;
  lStopwatch: TStopwatch;
begin
  Result := False;
  aConnection := nil;
  aDriverLink := nil;
  aError := '';

  lPhysicalFileName := PhysicalSnapshotCachePath(fCacheFileName);
  lDirectory := ExtractFilePath(lPhysicalFileName);
  if lDirectory <> '' then
    ForceDirectories(lDirectory);

  lStopwatch := TStopwatch.StartNew;
  repeat
    lConnection := nil;
    lDriverLink := TFDPhysSQLiteDriverLink.Create(nil);
    lConnection := TFDConnection.Create(nil);
    try
      ConfigureSnapshotSqliteConnection(lConnection, lPhysicalFileName);
      lConnection.Connected := True;
      aConnection := lConnection;
      aDriverLink := lDriverLink;
      Exit(True);
    except
      on E: Exception do
      begin
        aError := E.Message;
        lConnection.Free;
        lDriverLink.Free;
        if (not SnapshotSqliteBusyError(aError)) or
          (lStopwatch.ElapsedMilliseconds >= cSnapshotSqliteBusyTimeoutMs) then
          Exit(False);
        TThread.Sleep(cSnapshotSqliteBusyRetryDelayMs);
      end;
    end;
  until False;
end;

procedure TDelphiSemanticSnapshotSqliteCache.RebuildSnapshotTables(const aConnection: TObject);
var
  lConnection: TFDConnection;
begin
  lConnection := aConnection as TFDConnection;
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_visible_units');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_visibility');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_binding_references');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_binding_selectors');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_type_identities');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_bindings');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_symbols');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_routine_owners');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_value_evidence');
  lConnection.ExecSQL('drop table if exists snapshot_remove_with_facts');
  lConnection.ExecSQL('drop table if exists snapshot_project_remove_with_facts');
  lConnection.ExecSQL('drop table if exists snapshot_exact_strings');
  lConnection.ExecSQL('drop table if exists snapshot_references');
  lConnection.ExecSQL('drop table if exists snapshot_with_statements');
  lConnection.ExecSQL('drop table if exists snapshot_symbols');
  lConnection.ExecSQL('drop table if exists snapshot_strings');
  lConnection.ExecSQL('drop table if exists snapshot_target_lineage');
  lConnection.ExecSQL('drop table if exists snapshot_target_symbols');
  lConnection.ExecSQL('drop table if exists snapshot_target_units');
  lConnection.ExecSQL('drop table if exists snapshot_captured_sources');
  lConnection.ExecSQL('drop table if exists snapshot_unit_occurrences');
  lConnection.ExecSQL('drop table if exists snapshot_visible_units');
  lConnection.ExecSQL('drop table if exists snapshot_source_texts');
  lConnection.ExecSQL('drop table if exists snapshot_units');
  ExecWideSql(lConnection, 'delete from meta where key_name = ?', cSnapshotSchemaMetaKey);
end;

procedure TDelphiSemanticSnapshotSqliteCache.ResetProbeMetrics;
begin
  fMetrics.SnapshotSqlWriteMilliseconds := 0;
  fMetrics.SnapshotSqlReadMilliseconds := 0;
  fMetrics.SnapshotDeserializeMilliseconds := 0;
  fMetrics.SnapshotIndexRebuildMilliseconds := 0;
  fMetrics.SnapshotParseAvoidedEstimateMilliseconds := 0;
  fMetrics.SnapshotCacheUseful := False;
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

procedure TDelphiSemanticSnapshotSqliteCache.StoreExactStringPool(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aExactStrings: TSemanticStringPool; const aUnit: TUnitSnapshot);
var
  i: Integer;
  lSourceIds: TArray<Boolean>;
  lSource: TSemanticCapturedSourceFact;
  lHash, lText: string;
  lQuery, lFind, lInsert: TFDQuery;
begin
  if aExactStrings = nil then
    Exit;
  SetLength(lSourceIds, NativeInt(aExactStrings.Count) + 1);
  if aUnit <> nil then
  begin
    lSourceIds[aUnit.SourceTextId] := True;
    lSourceIds[aUnit.VerifiedActiveSourceTextId] := True;
    for i := 0 to aUnit.CapturedSourceCount - 1 do
    begin
      lSource := aUnit.CapturedSourceByIndex(i);
      if lSource.Status = cCapturedSourceText then
        lSourceIds[lSource.TextId] := True;
    end;
  end;
  lQuery := NewQuery(aConnection as TFDConnection, 'insert into snapshot_exact_strings ' +
    '(cache_key,string_id,text_value,source_content_hash) values (?,?,?,?)');
  lFind := NewQuery(aConnection as TFDConnection, 'select text from snapshot_source_texts where content_hash=?');
  lInsert := NewQuery(aConnection as TFDConnection, 'insert into snapshot_source_texts(content_hash,text) values (?,?)');
  try
    lQuery.FormatOptions.StrsTrim := False;
    lFind.FormatOptions.StrsTrim := False;
    lInsert.FormatOptions.StrsTrim := False;
    SetWideParam(lQuery, 0, aIdentity.CacheKey);
    lQuery.Params[1].DataType := ftLargeint;
    SetWideParam(lQuery, 2, '', ftWideMemo);
    SetWideParam(lQuery, 3, '');
    SetWideParam(lFind, 0, '');
    SetWideParam(lInsert, 0, '');
    SetWideParam(lInsert, 1, '', ftWideMemo);
    lQuery.Prepare;
    lFind.Prepare;
    lInsert.Prepare;
    for i := 1 to Integer(aExactStrings.Count) do
    begin
      lText := aExactStrings.TextOf(TSemanticStringId(i));
      lQuery.Params[1].AsLargeInt := i;
      if lSourceIds[i] then
      begin
        lHash := SnapshotSourceHash(lText);
        SetWideParam(lFind, 0, lHash);
        lFind.Open;
        if not lFind.Eof then
        begin
          if lFind.Fields[0].IsNull or (lFind.Fields[0].AsWideString <> lText) then
            raise EInvalidOpException.Create('SNAPSHOT_SHARED_TEXT_HASH_COLLISION');
        end else begin
          SetWideParam(lInsert, 0, lHash);
          SetWideParam(lInsert, 1, lText, ftWideMemo);
          lInsert.ExecSQL;
        end;
        lFind.Close;
        SetWideParam(lQuery, 2, '', ftWideMemo);
        SetWideParam(lQuery, 3, lHash);
      end else begin
        SetWideParam(lQuery, 2, lText, ftWideMemo);
        lQuery.Params[3].Clear;
      end;
      lQuery.ExecSQL;
    end;
  finally
    lInsert.Free;
    lFind.Free;
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreReferences(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot);
var
  i: Integer;
  lConnection: TFDConnection;
  lParamIndex: Integer;
  lQuery: TFDQuery;
  lReference: TSemanticReferenceFact;
begin
  lConnection := aConnection as TFDConnection;
  lQuery := NewQuery(lConnection, 'insert into snapshot_references(cache_key, unit_id, ' +
    'reference_id, with_id, target_unit_id, target_symbol_id, name_id, receiver_type_id, ' +
    'type_id, routine_id, section_kind_id, source_kind_id, classification_id, ' +
    'lookup_source_id, reason_id, line, column, end_line, end_column, routine_scope_id, ' +
    'file_id) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    for lParamIndex := 1 to 20 do
      lQuery.Params[lParamIndex].DataType := ftLargeint;
    lQuery.Prepare;
    for i := 1 to aUnit.ReferenceCount do
    begin
      lReference := aUnit.ReferenceById(TSemanticReferenceId(i));
      lQuery.Params[0].AsWideString := aIdentity.CacheKey;
      lQuery.Params[1].AsLargeInt := aUnit.UnitId;
      lQuery.Params[2].AsLargeInt := i;
      lQuery.Params[3].AsLargeInt := lReference.WithId;
      lQuery.Params[4].AsLargeInt := lReference.TargetUnitId;
      lQuery.Params[5].AsLargeInt := lReference.TargetSymbolId;
      lQuery.Params[6].AsLargeInt := lReference.NameId;
      lQuery.Params[7].AsLargeInt := lReference.ReceiverTypeId;
      lQuery.Params[8].AsLargeInt := lReference.TypeId;
      lQuery.Params[9].AsLargeInt := lReference.RoutineId;
      lQuery.Params[10].AsLargeInt := lReference.SectionKindId;
      lQuery.Params[11].AsLargeInt := lReference.SourceKindId;
      lQuery.Params[12].AsLargeInt := lReference.ClassificationId;
      lQuery.Params[13].AsLargeInt := lReference.LookupSourceId;
      lQuery.Params[14].AsLargeInt := lReference.ReasonId;
      lQuery.Params[15].AsLargeInt := lReference.Line;
      lQuery.Params[16].AsLargeInt := lReference.Column;
      lQuery.Params[17].AsLargeInt := lReference.EndLine;
      lQuery.Params[18].AsLargeInt := lReference.EndColumn;
      lQuery.Params[19].AsLargeInt := lReference.RoutineScopeId;
      lQuery.Params[20].AsLargeInt := lReference.FileId;
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreRemoveWithPlanningFacts(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aSnapshot: TDelphiProjectSnapshot; const aExactStrings: TSemanticStringPool;
  const aLookupSymbols: TArray<TDelphiSemanticInventorySymbol>);
var
  i: Integer;
  j: Integer;
  lBinding: TSemanticRemoveWithBindingFact;
  lConnection: TFDConnection;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lIdentityCount: Integer;
  lIdentityQuery: TFDQuery;
  lLookupSymbols: TArray<TSemanticRemoveWithInventorySymbolFact>;
  lParamIndex: Integer;
  lQuery: TFDQuery;
  lReference: TSemanticRemoveWithBoundReferenceFact;
  lSelector: TSemanticRemoveWithSelectorBindingFact;
  lSymbol: TSemanticRemoveWithInventorySymbolFact;

  procedure StoreTypeIdentity(const aKind: string; const aItemIndex,
    aSubIndex: Integer; const aFact: TSemanticRemoveWithTypeIdentityFact);
  begin
    if aFact.DeclaredIdId = 0 then
      Exit;
    lIdentityQuery.Params[0].AsWideString := aIdentity.CacheKey;
    lIdentityQuery.Params[1].AsWideString := aKind;
    lIdentityQuery.Params[2].AsInteger := aItemIndex;
    lIdentityQuery.Params[3].AsInteger := aSubIndex;
    lIdentityQuery.Params[4].AsInteger := Integer(aFact.UnitIdId);
    lIdentityQuery.Params[5].AsInteger := Integer(aFact.UnitNameId);
    lIdentityQuery.Params[6].AsInteger := Integer(aFact.NameId);
    lIdentityQuery.Params[7].AsInteger := Integer(aFact.KindId);
    lIdentityQuery.Params[8].AsInteger := Integer(aFact.DeclaredIdId);
    lIdentityQuery.Params[9].AsInteger := Integer(aFact.CanonicalIdId);
    lIdentityQuery.Params[10].AsInteger := Integer(aFact.UnderlyingIdId);
    lIdentityQuery.Params[11].AsInteger := Integer(aFact.CanonicalNameId);
    lIdentityQuery.Params[12].AsInteger := Integer(aFact.UnderlyingNameId);
    lIdentityQuery.Params[13].AsInteger := Integer(aFact.BaseTypeNameId);
    lIdentityQuery.Params[14].AsInteger := Integer(aFact.HelperTargetNameId);
    lIdentityQuery.Params[15].AsInteger := Integer(aFact.SectionKindId);
    lIdentityQuery.Params[16].AsInteger := Integer(aFact.FileNameId);
    lIdentityQuery.Params[17].AsInteger := aFact.Line;
    lIdentityQuery.Params[18].AsInteger := aFact.Column;
    lIdentityQuery.Params[19].AsInteger := aFact.EndLine;
    lIdentityQuery.Params[20].AsInteger := aFact.EndColumn;
    lIdentityQuery.Params[21].AsInteger := Integer(aFact.ScopeKindId);
    lIdentityQuery.Params[22].AsInteger := Integer(aFact.OwnerScopeIdId);
    lIdentityQuery.Params[23].AsInteger := Integer(aFact.SemanticSymbolIdId);
    lIdentityQuery.ExecSQL;
    Inc(lIdentityCount);
  end;

  procedure StoreInventoryFacts(const aTableName: string;
    const aSymbols: TArray<TSemanticRemoveWithInventorySymbolFact>);
  var
    lIndex: Integer;
    lInventoryQuery: TFDQuery;
    lParamIndex: Integer;
    lStoredSymbol: TSemanticRemoveWithInventorySymbolFact;
  begin
    lInventoryQuery := NewQuery(lConnection, 'insert into ' + aTableName +
      '(cache_key, item_index, name_id, symbol_class_id, kind_id, type_name_id, ' +
      'modifier_id, owner_name_id, owner_type_id, source_owner_type_id, related_type_name_id, ' +
      'routine_name_id, unit_name_id, file_name_id, section_kind_id, line, column, end_line, ' +
      'end_column, unsupported_reason_id, flags, index_parameter_count, type_category_id, ' +
      'routine_scope_id_id, parent_scope_id_id, owner_scope_id_id, owner_symbol_id_id, ' +
      'access_owner_unit_name_id, ' +
      'access_owner_file_name_id, ' +
      'access_owner_section_kind_id, ' +
      'access_owner_line, ' +
      'access_owner_column, heading_line, heading_column, heading_end_line, heading_end_column) ' +
      'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
    try
      lInventoryQuery.Params[0].DataType := ftWideString;
      for lParamIndex := 1 to 35 do
        lInventoryQuery.Params[lParamIndex].DataType := ftInteger;
      lInventoryQuery.Prepare;
      for lIndex := 0 to High(aSymbols) do
      begin
        lStoredSymbol := aSymbols[lIndex];
        lInventoryQuery.Params[0].AsWideString := aIdentity.CacheKey;
        lInventoryQuery.Params[1].AsInteger := lIndex;
        lInventoryQuery.Params[2].AsInteger := Integer(lStoredSymbol.NameId);
        lInventoryQuery.Params[3].AsInteger := Integer(lStoredSymbol.SymbolClassId);
        lInventoryQuery.Params[4].AsInteger := Integer(lStoredSymbol.KindId);
        lInventoryQuery.Params[5].AsInteger := Integer(lStoredSymbol.TypeNameId);
        lInventoryQuery.Params[6].AsInteger := Integer(lStoredSymbol.ModifierId);
        lInventoryQuery.Params[7].AsInteger := Integer(lStoredSymbol.OwnerNameId);
        lInventoryQuery.Params[8].AsInteger := Integer(lStoredSymbol.OwnerTypeId);
        lInventoryQuery.Params[9].AsInteger := Integer(lStoredSymbol.SourceOwnerTypeId);
        lInventoryQuery.Params[10].AsInteger := Integer(lStoredSymbol.RelatedTypeNameId);
        lInventoryQuery.Params[11].AsInteger := Integer(lStoredSymbol.RoutineNameId);
        lInventoryQuery.Params[12].AsInteger := Integer(lStoredSymbol.UnitNameId);
        lInventoryQuery.Params[13].AsInteger := Integer(lStoredSymbol.FileNameId);
        lInventoryQuery.Params[14].AsInteger := Integer(lStoredSymbol.SectionKindId);
        lInventoryQuery.Params[15].AsInteger := lStoredSymbol.Line;
        lInventoryQuery.Params[16].AsInteger := lStoredSymbol.Column;
        lInventoryQuery.Params[17].AsInteger := lStoredSymbol.EndLine;
        lInventoryQuery.Params[18].AsInteger := lStoredSymbol.EndColumn;
        lInventoryQuery.Params[19].AsInteger := Integer(lStoredSymbol.UnsupportedReasonId);
        lInventoryQuery.Params[20].AsInteger := Integer(lStoredSymbol.Flags);
        lInventoryQuery.Params[21].AsInteger := lStoredSymbol.IndexParameterCount;
        lInventoryQuery.Params[22].AsInteger := Integer(lStoredSymbol.TypeCategoryId);
        lInventoryQuery.Params[23].AsInteger := Integer(lStoredSymbol.RoutineScopeIdId);
        lInventoryQuery.Params[24].AsInteger := Integer(lStoredSymbol.ParentScopeIdId);
        lInventoryQuery.Params[25].AsInteger := Integer(lStoredSymbol.OwnerScopeIdId);
        lInventoryQuery.Params[26].AsInteger := Integer(lStoredSymbol.OwnerSymbolIdId);
        lInventoryQuery.Params[27].AsInteger := Integer(lStoredSymbol.AccessOwnerUnitNameId);
        lInventoryQuery.Params[28].AsInteger := Integer(lStoredSymbol.AccessOwnerFileNameId);
        lInventoryQuery.Params[29].AsInteger := Integer(lStoredSymbol.AccessOwnerSectionKindId);
        lInventoryQuery.Params[30].AsInteger := lStoredSymbol.AccessOwnerLine;
        lInventoryQuery.Params[31].AsInteger := lStoredSymbol.AccessOwnerColumn;
        lInventoryQuery.Params[32].AsInteger := lStoredSymbol.HeadingLine;
        lInventoryQuery.Params[33].AsInteger := lStoredSymbol.HeadingColumn;
        lInventoryQuery.Params[34].AsInteger := lStoredSymbol.HeadingEndLine;
        lInventoryQuery.Params[35].AsInteger := lStoredSymbol.HeadingEndColumn;
        lInventoryQuery.ExecSQL;
      end;
    finally
      lInventoryQuery.Free;
    end;
  end;
begin
  if (aSnapshot = nil) or not aSnapshot.HasRemoveWithPlanningFacts then
    Exit;

  lConnection := aConnection as TFDConnection;
  lFacts := aSnapshot.RemoveWithPlanningFacts;
  lLookupSymbols := StoredInventorySymbols(aExactStrings, aLookupSymbols);
  lIdentityCount := 0;
  lQuery := NewQuery(lConnection, 'insert into snapshot_remove_with_facts(cache_key, ' +
    'context_fingerprint_id, routine_owner_count, symbol_count, binding_count, ' +
    'type_identity_count) values (?, ?, ?, ?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    for lParamIndex := 1 to 5 do
      lQuery.Params[lParamIndex].DataType := ftInteger;
    lQuery.Prepare;
    lQuery.Params[0].AsWideString := aIdentity.CacheKey;
    lQuery.Params[1].AsInteger := Integer(lFacts.ContextFingerprintId);
    lQuery.Params[2].AsInteger := Length(lFacts.RoutineOwners);
    lQuery.Params[3].AsInteger := Length(lLookupSymbols);
    lQuery.Params[4].AsInteger := Length(lFacts.Bindings);
    lQuery.Params[5].AsInteger := 0;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;

  StoreInventoryFacts('snapshot_remove_with_routine_owners', lFacts.RoutineOwners);
  StoreInventoryFacts('snapshot_remove_with_symbols', lLookupSymbols);

  lIdentityQuery := NewQuery(lConnection,
    'insert into snapshot_remove_with_type_identities(cache_key, entity_kind, ' +
    'item_index, sub_index, unit_id_id, unit_name_id, name_id, kind_id, ' +
    'declared_id_id, canonical_id_id, underlying_id_id, canonical_name_id, ' +
    'underlying_name_id, base_type_name_id, helper_target_name_id, ' +
    'section_kind_id, file_name_id, line, column, end_line, end_column, ' +
    'scope_kind_id, owner_scope_id_id, semantic_symbol_id_id) ' +
    'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    for lParamIndex := 0 to 1 do
      lIdentityQuery.Params[lParamIndex].DataType := ftWideString;
    for lParamIndex := 2 to 23 do
      lIdentityQuery.Params[lParamIndex].DataType := ftInteger;
    lIdentityQuery.Prepare;
    for i := 0 to High(lFacts.RoutineOwners) do
      StoreTypeIdentity('routine-owner', i, 0, lFacts.RoutineOwners[i].OwnerIdentity);
    for i := 0 to High(lLookupSymbols) do
    begin
      StoreTypeIdentity('symbol', i, 0, lLookupSymbols[i].OwnerIdentity);
      StoreTypeIdentity('symbol-access-owner', i, 0,
        lLookupSymbols[i].AccessOwnerIdentity);
    end;
    for i := 0 to High(lFacts.Bindings) do
      for j := 0 to High(lFacts.Bindings[i].Selectors) do
      begin
        StoreTypeIdentity('selector', i, j,
          lFacts.Bindings[i].Selectors[j].TypeIdentity);
        StoreTypeIdentity('selector-capture', i, j,
          lFacts.Bindings[i].Selectors[j].CaptureTypeIdentity);
      end;
  finally
    lIdentityQuery.Free;
  end;
  lQuery := NewQuery(lConnection, 'update snapshot_remove_with_facts ' +
    'set type_identity_count = ? where cache_key = ?');
  try
    lQuery.Params[0].AsInteger := lIdentityCount;
    lQuery.Params[1].AsWideString := aIdentity.CacheKey;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;

  lQuery := NewQuery(lConnection, 'insert into snapshot_remove_with_bindings(cache_key, ' +
    'binding_index, semantic_id_id, provenance_id, file_name_id, unit_name_id, routine_name_id, ' +
    'line, column, end_line, end_column, body_line, body_column, body_end_line, body_end_column, ' +
    'selector_text_id, status_id, skip_reason_id, flags, member_reference_count, ' +
    'lexical_reference_count, external_reference_count, intrinsic_reference_count, ' +
    'unsupported_reference_count, unresolved_reference_count, selector_count, reference_count, ' +
    'routine_scope_id_id, inactive_reference_count, inactive_skip_reason_id) ' +
    'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    for lParamIndex := 1 to 29 do
      lQuery.Params[lParamIndex].DataType := ftInteger;
    lQuery.Prepare;
    for i := 0 to High(lFacts.Bindings) do
    begin
      lBinding := lFacts.Bindings[i];
      lQuery.Params[0].AsWideString := aIdentity.CacheKey;
      lQuery.Params[1].AsInteger := i;
      lQuery.Params[2].AsInteger := Integer(lBinding.SemanticIdId);
      lQuery.Params[3].AsInteger := Integer(lBinding.ProvenanceId);
      lQuery.Params[4].AsInteger := Integer(lBinding.FileNameId);
      lQuery.Params[5].AsInteger := Integer(lBinding.UnitNameId);
      lQuery.Params[6].AsInteger := Integer(lBinding.RoutineNameId);
      lQuery.Params[7].AsInteger := lBinding.Line;
      lQuery.Params[8].AsInteger := lBinding.Column;
      lQuery.Params[9].AsInteger := lBinding.EndLine;
      lQuery.Params[10].AsInteger := lBinding.EndColumn;
      lQuery.Params[11].AsInteger := lBinding.BodyLine;
      lQuery.Params[12].AsInteger := lBinding.BodyColumn;
      lQuery.Params[13].AsInteger := lBinding.BodyEndLine;
      lQuery.Params[14].AsInteger := lBinding.BodyEndColumn;
      lQuery.Params[15].AsInteger := Integer(lBinding.SelectorTextId);
      lQuery.Params[16].AsInteger := Integer(lBinding.StatusId);
      lQuery.Params[17].AsInteger := Integer(lBinding.SkipReasonId);
      lQuery.Params[18].AsInteger := Integer(lBinding.Flags);
      lQuery.Params[19].AsInteger := lBinding.MemberReferenceCount;
      lQuery.Params[20].AsInteger := lBinding.LexicalReferenceCount;
      lQuery.Params[21].AsInteger := lBinding.ExternalReferenceCount;
      lQuery.Params[22].AsInteger := lBinding.IntrinsicReferenceCount;
      lQuery.Params[23].AsInteger := lBinding.UnsupportedReferenceCount;
      lQuery.Params[24].AsInteger := lBinding.UnresolvedReferenceCount;
      lQuery.Params[25].AsInteger := Length(lBinding.Selectors);
      lQuery.Params[26].AsInteger := Length(lBinding.References);
      lQuery.Params[27].AsInteger := Integer(lBinding.RoutineScopeIdId);
      lQuery.Params[28].AsInteger := Length(lBinding.InactiveSpanReferences);
      lQuery.Params[29].AsInteger := Integer(lBinding.InactiveSpanSkipReasonId);
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;

  lQuery := NewQuery(lConnection, 'insert into snapshot_remove_with_binding_selectors(' +
    'cache_key, binding_index, selector_index, selector_text_id, status_id, reason_code_id, ' +
    'type_name_id, capture_type_name_id, capture_status_id) values (?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    for lParamIndex := 1 to 8 do
      lQuery.Params[lParamIndex].DataType := ftInteger;
    lQuery.Prepare;
    for i := 0 to High(lFacts.Bindings) do
      for j := 0 to High(lFacts.Bindings[i].Selectors) do
      begin
        lSelector := lFacts.Bindings[i].Selectors[j];
        lQuery.Params[0].AsWideString := aIdentity.CacheKey;
        lQuery.Params[1].AsInteger := i;
        lQuery.Params[2].AsInteger := j;
        lQuery.Params[3].AsInteger := Integer(lSelector.SelectorTextId);
        lQuery.Params[4].AsInteger := Integer(lSelector.StatusId);
        lQuery.Params[5].AsInteger := Integer(lSelector.ReasonCodeId);
        lQuery.Params[6].AsInteger := Integer(lSelector.TypeNameId);
        lQuery.Params[7].AsInteger := Integer(lSelector.CaptureTypeNameId);
        lQuery.Params[8].AsInteger := Integer(lSelector.CaptureTypeStatusId);
        lQuery.ExecSQL;
      end;
  finally
    lQuery.Free;
  end;

  lQuery := NewQuery(lConnection, 'insert into snapshot_remove_with_binding_references(' +
    'cache_key, binding_index, reference_index, semantic_id_id, name_id, classification_id, ' +
    'lookup_source_id, receiver_type_name_id, kind_id, type_name_id, reason_code_id, ' +
    'scope_conflict_kind_id, scope_conflict_name_id, line, column, end_line, end_column) ' +
    'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    for lParamIndex := 1 to 16 do
      lQuery.Params[lParamIndex].DataType := ftInteger;
    for lParamIndex := 3 to 12 do
      lQuery.Params[lParamIndex].DataType := ftLargeint;
    lQuery.Prepare;
    for i := 0 to High(lFacts.Bindings) do
      // Negative indexes persist WITH-only inactive verification in a separate partition.
      for j := -Length(lFacts.Bindings[i].InactiveSpanReferences) to High(lFacts.Bindings[i].References) do
      begin
        if j < 0 then
          lReference := lFacts.Bindings[i].InactiveSpanReferences[-j - 1]
        else
          lReference := lFacts.Bindings[i].References[j];
        lQuery.Params[0].AsWideString := aIdentity.CacheKey;
        lQuery.Params[1].AsInteger := i;
        lQuery.Params[2].AsInteger := j;
        lQuery.Params[3].AsLargeInt := lReference.SemanticIdId;
        lQuery.Params[4].AsLargeInt := lReference.NameId;
        lQuery.Params[5].AsLargeInt := lReference.ClassificationId;
        lQuery.Params[6].AsLargeInt := lReference.LookupSourceId;
        lQuery.Params[7].AsLargeInt := lReference.ReceiverTypeNameId;
        lQuery.Params[8].AsLargeInt := lReference.KindId;
        lQuery.Params[9].AsLargeInt := lReference.TypeNameId;
        lQuery.Params[10].AsLargeInt := lReference.ReasonCodeId;
        lQuery.Params[11].AsLargeInt := lReference.ScopeConflictKindId;
        lQuery.Params[12].AsLargeInt := lReference.ScopeConflictNameId;
        lQuery.Params[13].AsInteger := lReference.Line;
        lQuery.Params[14].AsInteger := lReference.Column;
        lQuery.Params[15].AsInteger := lReference.EndLine;
        lQuery.Params[16].AsInteger := lReference.EndColumn;
        lQuery.ExecSQL;
      end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreStrings(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aStrings: TSemanticStringPool);
var
  i: Integer;
  lConnection: TFDConnection;
  lQuery: TFDQuery;
begin
  lConnection := aConnection as TFDConnection;
  lQuery := NewQuery(lConnection, 'insert into snapshot_strings(cache_key, string_id, ' +
    'text_value) values (?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    lQuery.Params[1].DataType := ftInteger;
    lQuery.Params[2].DataType := ftWideString;
    lQuery.Prepare;
    for i := 1 to Integer(aStrings.Count) do
    begin
      lQuery.Params[0].AsWideString := aIdentity.CacheKey;
      lQuery.Params[1].AsInteger := i;
      lQuery.Params[2].AsWideString := aStrings.TextOf(TSemanticStringId(i));
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreSymbols(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot);
var
  i: Integer;
  lConnection: TFDConnection;
  lParamIndex: Integer;
  lQuery: TFDQuery;
  lSymbol: TSemanticSymbolFact;
begin
  lConnection := aConnection as TFDConnection;
  lQuery := NewQuery(lConnection, 'insert into snapshot_symbols(cache_key, unit_id, ' +
    'symbol_id, name_id, owner_type_id, type_id, routine_id, kind_id, flags, line, column, ' +
    'end_line, end_column, section_kind_id, source_kind_id, visibility_id, signature_id, ' +
    'declaration_role_id, scope_kind_id, owner_scope_id, semantic_symbol_id, ' +
    'routine_scope_id, file_id) values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ' +
    '?, ?, ?, ?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    for lParamIndex := 1 to 22 do
      lQuery.Params[lParamIndex].DataType := ftLargeint;
    lQuery.Prepare;
    for i := 1 to aUnit.SymbolCount do
    begin
      lSymbol := aUnit.SymbolById(TSemanticSymbolId(i));
      lQuery.Params[0].AsWideString := aIdentity.CacheKey;
      lQuery.Params[1].AsLargeInt := aUnit.UnitId;
      lQuery.Params[2].AsLargeInt := i;
      lQuery.Params[3].AsLargeInt := lSymbol.NameId;
      lQuery.Params[4].AsLargeInt := lSymbol.OwnerTypeId;
      lQuery.Params[5].AsLargeInt := lSymbol.TypeId;
      lQuery.Params[6].AsLargeInt := lSymbol.RoutineId;
      lQuery.Params[7].AsLargeInt := lSymbol.KindId;
      lQuery.Params[8].AsLargeInt := lSymbol.Flags;
      lQuery.Params[9].AsLargeInt := lSymbol.Line;
      lQuery.Params[10].AsLargeInt := lSymbol.Column;
      lQuery.Params[11].AsLargeInt := lSymbol.EndLine;
      lQuery.Params[12].AsLargeInt := lSymbol.EndColumn;
      lQuery.Params[13].AsLargeInt := lSymbol.SectionKindId;
      lQuery.Params[14].AsLargeInt := lSymbol.SourceKindId;
      lQuery.Params[15].AsLargeInt := lSymbol.VisibilityId;
      lQuery.Params[16].AsLargeInt := lSymbol.SignatureId;
      lQuery.Params[17].AsLargeInt := lSymbol.DeclarationRoleId;
      lQuery.Params[18].AsLargeInt := lSymbol.ScopeKindId;
      lQuery.Params[19].AsLargeInt := lSymbol.OwnerScopeId;
      lQuery.Params[20].AsLargeInt := lSymbol.SemanticSymbolId;
      lQuery.Params[21].AsLargeInt := lSymbol.RoutineScopeId;
      lQuery.Params[22].AsLargeInt := lSymbol.FileId;
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
end;

function RemapSnapshotStringId(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetStrings: TSemanticStringPool; const id: TSemanticStringId): TSemanticStringId;
begin
  if id = 0 then
    Exit(0);

  Result := aTargetStrings.Intern(aSnapshot.TextOf(id));
end;

function RemapSnapshotExactStringId(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetExactStrings: TSemanticStringPool; const id: TSemanticStringId):
  TSemanticStringId;
begin
  if id = 0 then
    Exit(0);

  Result := aTargetExactStrings.Intern(aSnapshot.ExactTextOf(id));
end;

function RemapSnapshotSymbolFact(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetStrings: TSemanticStringPool; const aSymbol: TSemanticSymbolFact):
  TSemanticSymbolFact;
begin
  Result := aSymbol;
  Result.NameId := RemapSnapshotStringId(aSnapshot, aTargetStrings, aSymbol.NameId);
  Result.OwnerTypeId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.OwnerTypeId);
  Result.TypeId := RemapSnapshotStringId(aSnapshot, aTargetStrings, aSymbol.TypeId);
  Result.RoutineId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.RoutineId);
  Result.KindId := RemapSnapshotStringId(aSnapshot, aTargetStrings, aSymbol.KindId);
  Result.SectionKindId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.SectionKindId);
  Result.SourceKindId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.SourceKindId);
  Result.VisibilityId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.VisibilityId);
  Result.SignatureId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.SignatureId);
  Result.DeclarationRoleId := RemapSnapshotStringId(aSnapshot,
    aTargetStrings, aSymbol.DeclarationRoleId);
  Result.ScopeKindId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.ScopeKindId);
  Result.OwnerScopeId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.OwnerScopeId);
  Result.SemanticSymbolId := RemapSnapshotStringId(aSnapshot,
    aTargetStrings, aSymbol.SemanticSymbolId);
  Result.RoutineScopeId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aSymbol.RoutineScopeId);
  Result.FileId := RemapSnapshotStringId(aSnapshot, aTargetStrings, aSymbol.FileId);
end;

function RemapSnapshotWithFact(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetStrings: TSemanticStringPool; const aWith: TSemanticWithStatementFact):
  TSemanticWithStatementFact;
begin
  Result := aWith;
  Result.RoutineId := RemapSnapshotStringId(aSnapshot, aTargetStrings, aWith.RoutineId);
end;

function RemapSnapshotReferenceFact(const aSnapshot: TDelphiProjectSnapshot;
  const aTargetStrings: TSemanticStringPool; const aReference: TSemanticReferenceFact):
  TSemanticReferenceFact;
begin
  Result := aReference;
  Result.NameId := RemapSnapshotStringId(aSnapshot, aTargetStrings, aReference.NameId);
  Result.ReceiverTypeId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.ReceiverTypeId);
  Result.TypeId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.TypeId);
  Result.RoutineId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.RoutineId);
  Result.SectionKindId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.SectionKindId);
  Result.SourceKindId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.SourceKindId);
  Result.ClassificationId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.ClassificationId);
  Result.LookupSourceId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.LookupSourceId);
  Result.ReasonId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.ReasonId);
  Result.RoutineScopeId := RemapSnapshotStringId(aSnapshot, aTargetStrings,
    aReference.RoutineScopeId);
  Result.FileId := RemapSnapshotStringId(aSnapshot, aTargetStrings, aReference.FileId);
end;

function BuildLocalUnitSnapshot(const aSnapshot: TDelphiProjectSnapshot;
  const aUnit: TUnitSnapshot; const aTargetStrings,
  aTargetExactStrings: TSemanticStringPool): TUnitSnapshot;
var
  lReferenceId: TSemanticReferenceId;
  lSymbolId: TSemanticSymbolId;
  lWithId: TSemanticWithId;
begin
  Result := TUnitSnapshot.Create(aUnit.UnitId, RemapSnapshotStringId(aSnapshot,
    aTargetStrings, aUnit.FileNameId), RemapSnapshotStringId(aSnapshot,
    aTargetStrings, aUnit.UnitNameId), RemapSnapshotExactStringId(aSnapshot,
    aTargetExactStrings, aUnit.SourceTextId));
  Result.SetVerifiedActiveSourceTextId(RemapSnapshotExactStringId(aSnapshot,
    aTargetExactStrings, aUnit.VerifiedActiveSourceTextId));
  Result.SetScopeModelMetadata(RemapSnapshotStringId(aSnapshot,
    aTargetStrings, aUnit.ScopeModelStatusId), RemapSnapshotStringId(aSnapshot,
    aTargetStrings, aUnit.ScopeModelVersionId), RemapSnapshotStringId(aSnapshot,
    aTargetStrings, aUnit.ScopeDiagnosticId), aUnit.RejectedDeclarationCount);
  try
    for lSymbolId := 1 to TSemanticSymbolId(aUnit.SymbolCount) do
      Result.AddSymbol(RemapSnapshotSymbolFact(aSnapshot, aTargetStrings,
        aUnit.SymbolById(lSymbolId)));
    for lWithId := 1 to TSemanticWithId(aUnit.WithStatementCount) do
      Result.AddWithStatement(RemapSnapshotWithFact(aSnapshot, aTargetStrings,
        aUnit.WithStatementById(lWithId)));
    for lReferenceId := 1 to TSemanticReferenceId(aUnit.ReferenceCount) do
      Result.AddReference(RemapSnapshotReferenceFact(aSnapshot, aTargetStrings,
        aUnit.ReferenceById(lReferenceId)));
    RemapPhysicalEvidence(TSnapshotEvidenceStrings.FromSnapshot(aSnapshot),
      aTargetStrings, aTargetExactStrings, aUnit, Result);
  except
    Result.Free;
    raise;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreUnitWithExactStrings(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aStrings, aExactStrings: TSemanticStringPool; const aUnit: TUnitSnapshot;
  const aIdentities: TSnapshotTargetIdentities);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lRetryStopwatch: TStopwatch;
  lWriteStopwatch: TStopwatch;
  lExactCount: Integer;
begin
  if not Assigned(aStrings) then
    raise Exception.Create('Cannot store a unit snapshot without a string pool.');
  if not Assigned(aUnit) then
    raise Exception.Create('Cannot store a nil unit snapshot.');
  ValidateIdentityComplete(aIdentity, 'store');
  ValidateUnitStringIds(aStrings, aUnit);
  ValidatePhysicalEvidence(aStrings, aExactStrings, aUnit);
  lExactCount := 0;
  if aExactStrings <> nil then
    lExactCount := aExactStrings.Count;

  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);

  lConnection := lConnectionObject as TFDConnection;
  lWriteStopwatch := TStopwatch.StartNew;
  lRetryStopwatch := TStopwatch.StartNew;
  repeat
    try
      lConnection.StartTransaction;
      DeleteCacheKeyRows(lConnection, aIdentity.CacheKey);
      StoreUnitHeader(aIdentity, lConnection, aUnit, Integer(aStrings.Count), lExactCount);
      StoreStrings(aIdentity, lConnection, aStrings);
      StoreSymbols(aIdentity, lConnection, aUnit);
      StoreWithStatements(aIdentity, lConnection, aUnit);
      StoreReferences(aIdentity, lConnection, aUnit);
      StoreExactStringPool(aIdentity, lConnection, aExactStrings, aUnit);
      StorePhysicalEvidence(aIdentity.CacheKey, lConnection, aUnit);
      StoreTargetIdentities(aIdentity.CacheKey, lConnection, aUnit, aIdentities);
      CollectSnapshotSourceOrphans(lConnection);
      lConnection.Commit;
      Inc(fMetrics.SnapshotSqlWriteMilliseconds, VisibleElapsedMilliseconds(lWriteStopwatch));
      Exit;
    except
      on E: Exception do
      begin
        if lConnection.InTransaction then
          lConnection.Rollback;
        if not RetrySnapshotSqliteBusy(E.Message, lRetryStopwatch) then
          raise;
      end;
    end;
  until False;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreUnit(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aSnapshot: TDelphiProjectSnapshot);
begin
  if aSnapshot <> nil then
  begin
    StoreUnitFromProjectSnapshot(aIdentity, aSnapshot, aUnit);
    Exit;
  end;

  StoreUnitWithExactStrings(aIdentity, aStrings, nil, aUnit);
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreUnitFromProjectSnapshot(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aSnapshot: TDelphiProjectSnapshot; const aUnit: TUnitSnapshot);
var
  lExactStrings: TSemanticStringPool;
  lLocalStrings: TSemanticStringPool;
  lLocalUnit: TUnitSnapshot;
begin
  if aSnapshot = nil then
    Exit;
  if not Assigned(aUnit) then
    raise Exception.Create('Cannot store a nil unit snapshot.');

  lLocalStrings := TSemanticStringPool.Create;
  lExactStrings := TSemanticStringPool.Create(True);
  lLocalUnit := nil;
  try
    lLocalUnit := BuildLocalUnitSnapshot(aSnapshot, aUnit, lLocalStrings,
      lExactStrings);
    FreeAndNil(fTargetIdentities);
    fTargetIdentities := BuildSnapshotTargetIdentities(aSnapshot, aUnit);
    StoreUnitWithExactStrings(aIdentity, lLocalStrings, lExactStrings, lLocalUnit, fTargetIdentities);
  finally
    lLocalUnit.Free;
    lExactStrings.Free;
    lLocalStrings.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreUnitFromSnapshot(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aSnapshot: TDelphiProjectSnapshot; const aUnitIndex: Integer);
begin
  if aSnapshot = nil then
    Exit;

  StoreUnitFromProjectSnapshot(aIdentity, aSnapshot, aSnapshot.UnitByIndex(aUnitIndex));
end;

function CombinedFactsPayloadCharacterLimit: Integer;
begin
  Result := cCombinedFactsPayloadMaxCharacters;
  {$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
  // Thread-local override keeps small boundary fixtures isolated from other tests.
  if CombinedFactsPayloadMaxCharactersForTest > 0 then
    Result := CombinedFactsPayloadMaxCharactersForTest;
  {$ENDIF}
end;

function TDelphiSemanticSnapshotSqliteCache.TryLoadCombinedFactsPayload(
  const aIdentity: string; out aPayload: string; out aInvalid: Boolean): Boolean;
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lQuery: TFDQuery;
begin
  Result := False;
  aPayload := '';
  aInvalid := False;
  if not SharedConnection(lConnectionObject, lError) then
    raise EInvalidOpException.Create('Combined facts cache open failed: ' + lError);
  lConnection := lConnectionObject as TFDConnection;
  lConnection.ExecSQL('CREATE TABLE IF NOT EXISTS combined_remove_with_facts (' +
    'identity TEXT PRIMARY KEY, payload TEXT NOT NULL, payload_hash TEXT NOT NULL)');
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := 'SELECT payload, payload_hash FROM combined_remove_with_facts WHERE identity = :identity';
    SetWideParam(lQuery, 0, aIdentity);
    lQuery.Open;
    if lQuery.Eof then
      Exit;
    aPayload := lQuery.Fields[0].AsWideString;
    aInvalid := (aPayload = '') or (Length(aPayload) > CombinedFactsPayloadCharacterLimit) or
      (THashSHA2.GetHashString(aPayload) <> lQuery.Fields[1].AsWideString);
    if aInvalid then
    begin
      aPayload := '';
      Exit;
    end;
    Result := True;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.DeleteCombinedFactsPayload(const aIdentity: string);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lQuery: TFDQuery;
  lRetryStopwatch: TStopwatch;
begin
  if not SharedConnection(lConnectionObject, lError) then
    raise EInvalidOpException.Create('Combined facts cache open failed: ' + lError);
  lConnection := lConnectionObject as TFDConnection;
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := 'DELETE FROM combined_remove_with_facts WHERE identity = :identity';
    SetWideParam(lQuery, 0, aIdentity);
    lRetryStopwatch := TStopwatch.StartNew;
    repeat
      try
        lQuery.ExecSQL;
        Exit;
      except
        on E: Exception do
          if not RetrySnapshotSqliteBusy(E.Message, lRetryStopwatch) then
            raise ECombinedFactsCachePublication.Create('Combined facts cache publication failed (delete): ' + E.Message);
      end;
    until False;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreCombinedFactsPayload(
  const aIdentity, aPayload: string);
var
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lQuery: TFDQuery;
  lRetryStopwatch: TStopwatch;
begin
  fCombinedFactsStoreOutcome := '';
  // Do not open, hash, replace or delete rows for a payload the loader cannot use.
  if Length(aPayload) > CombinedFactsPayloadCharacterLimit then
  begin
    fCombinedFactsStoreOutcome := 'payload-too-large';
    Exit;
  end;
  if not SharedConnection(lConnectionObject, lError) then
    raise EInvalidOpException.Create('Combined facts cache open failed: ' + lError);
  lConnection := lConnectionObject as TFDConnection;
  lQuery := TFDQuery.Create(nil);
  try
    lQuery.Connection := lConnection;
    lQuery.SQL.Text := 'INSERT OR REPLACE INTO combined_remove_with_facts ' +
      '(identity, payload, payload_hash) VALUES (:identity, :payload, :payload_hash)';
    SetWideParam(lQuery, 0, aIdentity);
    SetWideParam(lQuery, 1, aPayload);
    SetWideParam(lQuery, 2, THashSHA2.GetHashString(aPayload));
{$IFDEF DS_PROJECT_SESSION_TEST_SUPPORT}
    if Assigned(CombinedFactsBeforeStoreForTest) then
      CombinedFactsBeforeStoreForTest();
{$ENDIF}
    lRetryStopwatch := TStopwatch.StartNew;
    repeat
      try
        lConnection.ExecSQL('CREATE TABLE IF NOT EXISTS combined_remove_with_facts (' +
          'identity TEXT PRIMARY KEY, payload TEXT NOT NULL, payload_hash TEXT NOT NULL)');
        lConnection.StartTransaction;
        lConnection.ExecSQL('DELETE FROM combined_remove_with_facts');
        lQuery.ExecSQL;
        lConnection.Commit;
        fCombinedFactsStoreOutcome := 'stored';
        Exit;
      except
        on E: Exception do
        begin
          if lConnection.InTransaction then
            lConnection.Rollback;
          if not RetrySnapshotSqliteBusy(E.Message, lRetryStopwatch) then
          begin
            fCombinedFactsStoreOutcome := 'cache-publication-error';
            raise ECombinedFactsCachePublication.Create('Combined facts cache publication failed (store): ' + E.Message);
          end;
        end;
      end;
    until False;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreProjectRemoveWithPlanningFacts(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aSnapshot: TDelphiProjectSnapshot);
var
  lLookupSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  SetLength(lLookupSymbols, 0);
  StoreProjectRemoveWithPlanningFacts(aIdentity, aSnapshot, lLookupSymbols);
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreProjectRemoveWithPlanningFacts(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aSnapshot: TDelphiProjectSnapshot;
  const aLookupSymbols: TArray<TDelphiSemanticInventorySymbol>);
var
  i: Cardinal;
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lExactStrings: TSemanticStringPool;
  lQuery: TFDQuery;
  lRetryStopwatch: TStopwatch;
  lWriteStopwatch: TStopwatch;
begin
  if (aSnapshot = nil) or not aSnapshot.HasRemoveWithPlanningFacts then
    raise Exception.Create('Cannot store project remove-with planning facts from an empty snapshot.');
  ValidateIdentityComplete(aIdentity, 'store project remove-with planning facts for');

  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);

  lConnection := lConnectionObject as TFDConnection;
  lWriteStopwatch := TStopwatch.StartNew;
  lRetryStopwatch := TStopwatch.StartNew;
  lExactStrings := TSemanticStringPool.Create(True);
  try
    for i := 1 to aSnapshot.ExactStringCount do
      lExactStrings.Intern(aSnapshot.ExactTextOf(TSemanticStringId(i)));
    StoredInventorySymbols(lExactStrings, aLookupSymbols);
    repeat
      try
        lConnection.StartTransaction;
        DeleteCacheKeyRows(lConnection, aIdentity.CacheKey);
        lQuery := NewQuery(lConnection, 'insert into snapshot_project_remove_with_facts(' +
          'cache_key, identity_key, source_file_name, file_hash, context_hash, ' +
          'include_graph_hash, schema_version, stored_at_utc) values (?, ?, ?, ?, ?, ?, ?, ?)');
        try
          SetWideParam(lQuery, 0, aIdentity.CacheKey);
          SetWideParam(lQuery, 1, aIdentity.IdentityKey);
          SetWideParam(lQuery, 2, aIdentity.SourceFileName);
          SetWideParam(lQuery, 3, aIdentity.FileHash);
          SetWideParam(lQuery, 4, aIdentity.ContextHash);
          SetWideParam(lQuery, 5, aIdentity.IncludeGraphHash);
          SetWideParam(lQuery, 6, aIdentity.SchemaVersion);
          SetWideParam(lQuery, 7, SnapshotUtcTimestamp);
          lQuery.Prepare;
          lQuery.ExecSQL;
        finally
          lQuery.Free;
        end;
        StoreExactStringPool(aIdentity, lConnection, lExactStrings);
        StoreRemoveWithPlanningFacts(aIdentity, lConnection, aSnapshot, lExactStrings,
          aLookupSymbols);
        StoreValueMemberEvidence(aIdentity.CacheKey, lConnection,
          aSnapshot.RemoveWithPlanningFacts.LookupIndex.ExportValueMemberEvidence);
        StoreRemoveWithVisibility(aIdentity.CacheKey, lConnection, aSnapshot);
        lConnection.Commit;
        Inc(fMetrics.SnapshotSqlWriteMilliseconds, VisibleElapsedMilliseconds(lWriteStopwatch));
        Exit;
      except
        on E: Exception do
        begin
          if lConnection.InTransaction then
            lConnection.Rollback;
          if not RetrySnapshotSqliteBusy(E.Message, lRetryStopwatch) then
            raise;
        end;
      end;
    until False;
  finally
    lExactStrings.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StorePhysicalEvidence(const aCacheKey: string;
  const aConnection: TObject; const aUnit: TUnitSnapshot);
var
  i: Integer;
  lSource: TSemanticCapturedSourceFact;
  lQuery: TFDQuery;
  lStream: TBytesStream;
begin
  lQuery := NewQuery(aConnection as TFDConnection, 'insert into snapshot_captured_sources ' +
    '(cache_key,unit_id,source_ordinal,file_id,text_id,status) values (?,?,?,?,?,?)');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    lQuery.Params[1].AsLargeInt := aUnit.UnitId;
    for i := 2 to 5 do
      lQuery.Params[i].DataType := ftLargeint;
    lQuery.Prepare;
    for i := 0 to aUnit.CapturedSourceCount - 1 do
    begin
      lSource := aUnit.CapturedSourceByIndex(i);
      lQuery.Params[2].AsLargeInt := i;
      lQuery.Params[3].AsLargeInt := lSource.FileId;
      lQuery.Params[4].AsLargeInt := lSource.TextId;
      lQuery.Params[5].AsLargeInt := lSource.Status;
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
  lQuery := NewQuery(aConnection as TFDConnection, 'insert into snapshot_visible_units ' +
    '(cache_key,unit_id,import_ordinal,unit_name_id) values (?,?,?,?)');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    lQuery.Params[1].AsLargeInt := aUnit.UnitId;
    lQuery.Params[2].DataType := ftLargeint;
    lQuery.Params[3].DataType := ftLargeint;
    lQuery.Prepare;
    for i := 0 to aUnit.VisibleUnitNameCount - 1 do
    begin
      lQuery.Params[2].AsLargeInt := i;
      lQuery.Params[3].AsLargeInt := aUnit.VisibleUnitNameByIndex(i);
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
  lQuery := NewQuery(aConnection as TFDConnection, 'insert into snapshot_unit_occurrences ' +
    '(cache_key,unit_id,collection,payload) values (?,?,?,?)');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    lQuery.Params[1].AsLargeInt := aUnit.UnitId;
    lQuery.Params[2].DataType := ftInteger;
    lQuery.Params[3].DataType := ftBlob;
    lQuery.Prepare;
    for i := 0 to 1 do
    begin
      lQuery.Params[2].AsInteger := i;
      lStream := TBytesStream.Create(PackPhysicalOccurrences(aUnit, i));
      try
        lQuery.Params[3].LoadFromStream(lStream, ftBlob);
      finally
        lStream.Free;
      end;
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadPhysicalEvidence(const aCacheKey: string;
  const aConnection: TObject; const aStrings, aExactStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot);
var
  i, lOffset: Integer;
  lQuery: TFDDataSet;
  lAvailable: array[0..4] of Boolean;
  lCounts: array[0..4] of Integer;
  lSources: TArray<TSemanticCapturedSourceFact>;
  lImports: TArray<TSemanticStringId>;
begin
  lQuery := NewUnitReadQuery(aConnection, aCacheKey, 'snapshot_units', 'select physical_reference_available,' +
    'physical_symbol_available,captured_sources_available,visible_unit_names_available,has_includes,' +
    'physical_reference_count,physical_symbol_count,captured_source_count,visible_unit_count,exact_string_count ' +
    'from snapshot_units where cache_key=?') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      SetWideParam(TFDQuery(lQuery), 0, aCacheKey);
    lQuery.Open;
    if lQuery.Eof then
      raise EInvalidOpException.Create('SNAPSHOT_EVIDENCE_HEADER_MISSING');
    lOffset := 0;
    if fUnitLoadBatch <> nil then
      lOffset := 20;
    for i := 0 to 4 do
    begin
      lAvailable[i] := CheckedCacheInteger(lQuery.Fields[lOffset + i], 0, 1) = 1;
      lCounts[i] := CheckedCacheInteger(lQuery.Fields[lOffset + i + 5], 0, MaxInt);
    end;
    if lCounts[4] <> Integer(aExactStrings.Count) then
      raise EInvalidOpException.Create('SNAPSHOT_EXACT_COUNT_MISMATCH');
  finally
    lQuery.Free;
  end;
  aUnit.SetHasIncludes(lAvailable[4]);
  // Query rows before allocation, so a corrupt unbounded header cannot force a
  // giant allocation when the database has only a few (or zero) child rows.
  lQuery := NewUnitReadQuery(aConnection, aCacheKey, 'snapshot_captured_sources', 'select unit_id,source_ordinal,file_id,text_id,status ' +
    'from snapshot_captured_sources where cache_key=? order by source_ordinal') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      SetWideParam(TFDQuery(lQuery), 0, aCacheKey);
    lQuery.Open;
    lQuery.FetchAll;
    if lQuery.RecordCount <> lCounts[2] then
      raise EInvalidOpException.Create('SNAPSHOT_CAPTURE_COUNT_MISMATCH');
    SetLength(lSources, lCounts[2]);
    i := 0;
    while not lQuery.Eof do
    begin
      if (CheckedCacheInteger(lQuery.Fields[0], 1, High(Cardinal)) <> aUnit.UnitId) or
        (CheckedCacheInteger(lQuery.Fields[1], 0, MaxInt) <> i) then
        raise EInvalidOpException.Create('SNAPSHOT_CAPTURE_ORDINAL_INVALID');
      lSources[i].FileId := CheckedCacheInteger(lQuery.Fields[2], 1, High(Cardinal));
      lSources[i].TextId := CheckedCacheInteger(lQuery.Fields[3], 0, High(Cardinal));
      lSources[i].Status := CheckedCacheInteger(lQuery.Fields[4], 0, cCapturedSourceConflict);
      Inc(i);
      lQuery.Next;
    end;
    aUnit.SetCapturedSources(lSources, lAvailable[2]);
  finally
    lQuery.Free;
  end;
  lQuery := NewUnitReadQuery(aConnection, aCacheKey, 'snapshot_visible_units', 'select unit_id,import_ordinal,unit_name_id ' +
    'from snapshot_visible_units where cache_key=? order by import_ordinal') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      SetWideParam(TFDQuery(lQuery), 0, aCacheKey);
    lQuery.Open;
    lQuery.FetchAll;
    if lQuery.RecordCount <> lCounts[3] then
      raise EInvalidOpException.Create('SNAPSHOT_IMPORT_COUNT_MISMATCH');
    SetLength(lImports, lCounts[3]);
    i := 0;
    while not lQuery.Eof do
    begin
      if (CheckedCacheInteger(lQuery.Fields[0], 1, High(Cardinal)) <> aUnit.UnitId) or
        (CheckedCacheInteger(lQuery.Fields[1], 0, MaxInt) <> i) then
        raise EInvalidOpException.Create('SNAPSHOT_IMPORT_ORDINAL_INVALID');
      lImports[i] := CheckedCacheInteger(lQuery.Fields[2], 1, High(Cardinal));
      Inc(i);
      lQuery.Next;
    end;
    aUnit.SetVisibleUnitNameIds(lImports, lAvailable[3]);
  finally
    lQuery.Free;
  end;
  lQuery := NewUnitReadQuery(aConnection, aCacheKey, 'snapshot_unit_occurrences', 'select unit_id,collection,payload ' +
    'from snapshot_unit_occurrences where cache_key=? order by collection') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      SetWideParam(TFDQuery(lQuery), 0, aCacheKey);
    lQuery.Open;
    for i := 0 to 1 do
    begin
      if lQuery.Eof then
        raise EInvalidOpException.Create('SNAPSHOT_OCCURRENCE_COLLECTION_MISSING');
      if (CheckedCacheInteger(lQuery.Fields[0], 1, High(Cardinal)) <> aUnit.UnitId) or
        (CheckedCacheInteger(lQuery.Fields[1], 0, 1) <> i) or lQuery.Fields[2].IsNull then
        raise EInvalidOpException.Create('SNAPSHOT_OCCURRENCE_COLLECTION_INVALID');
      UnpackPhysicalOccurrences(lQuery.Fields[2].AsBytes, lCounts[i], i, lAvailable[i], aUnit);
      lQuery.Next;
    end;
    if not lQuery.Eof then
      raise EInvalidOpException.Create('SNAPSHOT_OCCURRENCE_COLLECTION_EXTRA');
  finally
    lQuery.Free;
  end;
  ValidatePhysicalEvidence(aStrings, aExactStrings, aUnit);
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreTargetIdentities(
  const aCacheKey: string; const aConnection: TObject; const aUnit: TUnitSnapshot;
  const aIdentities: TSnapshotTargetIdentities);
var
  lPayload: TBytes;
  lQuery: TFDQuery;
  lStream: TBytesStream;
  lValueCount: Integer;
begin
  if aIdentities = nil then
    Exit;
  lPayload := aIdentities.Encode(lValueCount);
  lQuery := NewQuery(aConnection as TFDConnection,
    'insert into snapshot_target_lineage(cache_key, unit_id, value_count, payload) values (?, ?, ?, ?)');
  try
    SetWideParam(lQuery, 0, aCacheKey);
    lQuery.Params[1].AsLargeInt := aUnit.UnitId;
    lQuery.Params[2].AsInteger := lValueCount;
    lStream := TBytesStream.Create(lPayload);
    try
      lQuery.Params[3].LoadFromStream(lStream, ftBlob);
    finally
      lStream.Free;
    end;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.LoadTargetIdentities(
  const aCacheKey: string; const aConnection: TObject;
  const aBuilder: TDelphiProjectSnapshotBuilder; const aUnit: TUnitSnapshot);
var
  lIdentities: TSnapshotTargetIdentities;
  lQuery: TFDDataSet;
begin
  lQuery := NewUnitReadQuery(aConnection, aCacheKey, 'snapshot_target_lineage',
    'select unit_id, value_count, payload from snapshot_target_lineage where cache_key = ?') as TFDDataSet;
  try
    if lQuery is TFDQuery then
      SetWideParam(TFDQuery(lQuery), 0, aCacheKey);
    lQuery.Open;
    // The low-level StoreUnit API can intentionally omit target evidence. Such
    // snapshots remain readable but cannot establish ProjectSession cache hits.
    if lQuery.Eof then
      Exit;
    if lQuery.Fields[0].AsLargeInt <> aUnit.UnitId then
      raise EInvalidOpException.Create('Snapshot target lineage unit mismatch.');
    lIdentities := TSnapshotTargetIdentities.Decode(lQuery.Fields[2].AsBytes,
      lQuery.Fields[1].AsLargeInt, aUnit, aBuilder.Strings.TextOf(aUnit.FileNameId));
    aBuilder.SetExtensionOwned(cSnapshotTargetIdentityExtension, lIdentities);
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreUnitHeader(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot; const aStringCount, aExactStringCount: Integer);
var
  lConnection: TFDConnection;
  lQuery: TFDQuery;
begin
  lConnection := aConnection as TFDConnection;
  lQuery := NewQuery(lConnection, 'insert into snapshot_units(cache_key, identity_key, ' +
    'source_file_name, file_hash, context_hash, include_graph_hash, schema_version, ' +
    'stored_at_utc, unit_id, file_name_id, unit_name_id, source_text_id, string_count, ' +
    'scope_model_status_id, scope_model_version_id, scope_diagnostic_id, ' +
    'rejected_declaration_count, symbol_count, with_statement_count, reference_count, ' +
    'parse_avoided_estimate_ms, verified_active_source_text_id, physical_reference_available, ' +
    'physical_symbol_available, captured_sources_available, visible_unit_names_available, has_includes, ' +
    'physical_reference_count, physical_symbol_count, captured_source_count, visible_unit_count, exact_string_count) ' +
    'values (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ' +
    '?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    SetWideParam(lQuery, 0, aIdentity.CacheKey);
    SetWideParam(lQuery, 1, aIdentity.IdentityKey);
    SetWideParam(lQuery, 2, aIdentity.SourceFileName);
    SetWideParam(lQuery, 3, aIdentity.FileHash);
    SetWideParam(lQuery, 4, aIdentity.ContextHash);
    SetWideParam(lQuery, 5, aIdentity.IncludeGraphHash);
    SetWideParam(lQuery, 6, aIdentity.SchemaVersion);
    SetWideParam(lQuery, 7, SnapshotUtcTimestamp);
    lQuery.Params[8].DataType := ftLargeint;
    lQuery.Params[8].AsLargeInt := aUnit.UnitId;
    lQuery.Params[9].DataType := ftLargeint;
    lQuery.Params[9].AsLargeInt := aUnit.FileNameId;
    lQuery.Params[10].DataType := ftLargeint;
    lQuery.Params[10].AsLargeInt := aUnit.UnitNameId;
    lQuery.Params[11].DataType := ftLargeint;
    lQuery.Params[11].AsLargeInt := aUnit.SourceTextId;
    lQuery.Params[12].DataType := ftLargeint;
    lQuery.Params[12].AsLargeInt := aStringCount;
    lQuery.Params[13].DataType := ftLargeint;
    lQuery.Params[13].AsLargeInt := aUnit.ScopeModelStatusId;
    lQuery.Params[14].DataType := ftLargeint;
    lQuery.Params[14].AsLargeInt := aUnit.ScopeModelVersionId;
    lQuery.Params[15].DataType := ftLargeint;
    lQuery.Params[15].AsLargeInt := aUnit.ScopeDiagnosticId;
    lQuery.Params[16].DataType := ftLargeint;
    lQuery.Params[16].AsLargeInt := aUnit.RejectedDeclarationCount;
    lQuery.Params[17].DataType := ftLargeint;
    lQuery.Params[17].AsLargeInt := aUnit.SymbolCount;
    lQuery.Params[18].DataType := ftLargeint;
    lQuery.Params[18].AsLargeInt := aUnit.WithStatementCount;
    lQuery.Params[19].DataType := ftLargeint;
    lQuery.Params[19].AsLargeInt := aUnit.ReferenceCount;
    lQuery.Params[20].DataType := ftLargeint;
    lQuery.Params[20].AsLargeInt := aIdentity.ParseAvoidedEstimateMilliseconds;
    lQuery.Params[21].DataType := ftLargeint;
    lQuery.Params[21].AsLargeInt := aUnit.VerifiedActiveSourceTextId;
    lQuery.Params[22].AsLargeInt := Ord(aUnit.PhysicalReferenceOccurrencesAvailable);
    lQuery.Params[23].AsLargeInt := Ord(aUnit.PhysicalSymbolOccurrencesAvailable);
    lQuery.Params[24].AsLargeInt := Ord(aUnit.CapturedSourcesAvailable);
    lQuery.Params[25].AsLargeInt := Ord(aUnit.VisibleUnitNamesAvailable);
    lQuery.Params[26].AsLargeInt := Ord(aUnit.HasIncludes);
    lQuery.Params[27].AsLargeInt := aUnit.PhysicalReferenceOccurrenceCount;
    lQuery.Params[28].AsLargeInt := aUnit.PhysicalSymbolOccurrenceCount;
    lQuery.Params[29].AsLargeInt := aUnit.CapturedSourceCount;
    lQuery.Params[30].AsLargeInt := aUnit.VisibleUnitNameCount;
    lQuery.Params[31].AsLargeInt := aExactStringCount;
    lQuery.Prepare;
    lQuery.ExecSQL;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.StoreWithStatements(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity; const aConnection: TObject;
  const aUnit: TUnitSnapshot);
var
  i: Integer;
  lConnection: TFDConnection;
  lParamIndex: Integer;
  lQuery: TFDQuery;
  lWith: TSemanticWithStatementFact;
begin
  lConnection := aConnection as TFDConnection;
  lQuery := NewQuery(lConnection, 'insert into snapshot_with_statements(cache_key, ' +
    'unit_id, with_id, routine_id, selector_start_line, selector_start_column, ' +
    'body_start_line, body_start_column, body_end_line, body_end_column, flags) values ' +
    '(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)');
  try
    lQuery.Params[0].DataType := ftWideString;
    for lParamIndex := 1 to 10 do
      lQuery.Params[lParamIndex].DataType := ftLargeint;
    lQuery.Prepare;
    for i := 1 to aUnit.WithStatementCount do
    begin
      lWith := aUnit.WithStatementById(TSemanticWithId(i));
      lQuery.Params[0].AsWideString := aIdentity.CacheKey;
      lQuery.Params[1].AsLargeInt := aUnit.UnitId;
      lQuery.Params[2].AsLargeInt := i;
      lQuery.Params[3].AsLargeInt := lWith.RoutineId;
      lQuery.Params[4].AsLargeInt := lWith.SelectorStartLine;
      lQuery.Params[5].AsLargeInt := lWith.SelectorStartColumn;
      lQuery.Params[6].AsLargeInt := lWith.BodyStartLine;
      lQuery.Params[7].AsLargeInt := lWith.BodyStartColumn;
      lQuery.Params[8].AsLargeInt := lWith.BodyEndLine;
      lQuery.Params[9].AsLargeInt := lWith.BodyEndColumn;
      lQuery.Params[10].AsLargeInt := lWith.Flags;
      lQuery.ExecSQL;
    end;
  finally
    lQuery.Free;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.BeginUnitLoadBatch(
  const aIdentities: TArray<TDelphiSemanticSnapshotCacheIdentity>);
var
  i: Integer;
  lConnectionObject: TObject;
  lConnection: TFDConnection;
  lError: string;
  lStopwatch: TStopwatch;
begin
  if fUnitLoadBatch <> nil then
    raise EInvalidOpException.Create('SNAPSHOT_BATCH_ALREADY_ACTIVE');
  fLastBatchReadFallbackReason := '';
  fBatchReadMilliseconds := 0;
  for i := 0 to High(aIdentities) do
    ValidateIdentityComplete(aIdentities[i], 'batch load');
  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);
  lConnection := lConnectionObject as TFDConnection;
  lConnection.StartTransaction;
  try
    lStopwatch := TStopwatch.StartNew;
    fUnitLoadBatch := TSnapshotUnitLoadBatch.Create(lConnection, aIdentities);
    fBatchReadMilliseconds := VisibleElapsedMilliseconds(lStopwatch);
  except
    on E: Exception do
    begin
      lConnection.Rollback;
      // A row conversion failure must not turn another unit's usable entry
      // into a miss. Retry through the ordinary individually validated reads.
      // Keep the fallback diagnostic visible to callers and proof harnesses.
      fLastBatchReadFallbackReason := Copy('SNAPSHOT_BATCH_READ_FALLBACK:' + E.Message, 1, 512);
    end;
  end;
end;

procedure TDelphiSemanticSnapshotSqliteCache.EndUnitLoadBatch;
var
  lConnection: TFDConnection;
  lRejected: TArray<string>;
  lKey: string;
begin
  if fUnitLoadBatch = nil then
    Exit;
  lRejected := TSnapshotUnitLoadBatch(fUnitLoadBatch).RejectedKeys;
  FreeAndNil(fUnitLoadBatch);
  fBatchReadMilliseconds := 0;
  lConnection := fConnection as TFDConnection;
  try
    lConnection.Commit;
  except
    if lConnection.InTransaction then
      lConnection.Rollback;
    raise;
  end;
  // Invalid entries are hidden immediately within the batch, then evicted
  // after all read cursors close. Other units keep their own valid rows.
  for lKey in lRejected do
    DeleteCacheKey(lKey);
end;

function TDelphiSemanticSnapshotSqliteCache.TryLoadUnit(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  out aSnapshot: TDelphiProjectSnapshot): Boolean;
var
  lOwnsTransaction: Boolean;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lConnection: TFDConnection;
  lConnectionObject: TObject;
  lEntryBelongsToIdentity: Boolean;
  lError: string;
  lIndexRebuildStopwatch: TStopwatch;
  lLoadCostMilliseconds: Int64;
  lParseAvoidedEstimateMilliseconds: Int64;
  lReferenceCount: Integer;
  lStringCount: Integer;
  lSymbolCount: Integer;
  lUnit: TUnitSnapshot;
  lWithStatementCount: Integer;
begin
  Result := False;
  fLastInvalidationReason := '';
  aSnapshot := nil;
  lUnit := nil;
  ValidateIdentityComplete(aIdentity, 'load');
  ResetProbeMetrics;
  Inc(fMetrics.SnapshotSqlReadMilliseconds, fBatchReadMilliseconds);
  fBatchReadMilliseconds := 0;
  Inc(fMetrics.SnapshotCacheProbes);
  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);

  lConnection := lConnectionObject as TFDConnection;
  lOwnsTransaction := fUnitLoadBatch = nil;
  if lOwnsTransaction then
    lConnection.StartTransaction;
  try
    if not IdentityMatches(aIdentity, lConnectionObject, lEntryBelongsToIdentity) then
    begin
      if lOwnsTransaction then
        lConnection.Commit;
      if lEntryBelongsToIdentity then
      begin
        fLastInvalidationReason := 'SNAPSHOT_IDENTITY_MISMATCH';
        Inc(fMetrics.Invalidations);
        DeleteCacheKey(aIdentity.CacheKey);
      end;
      Inc(fMetrics.CacheMisses);
      Exit;
    end;

    lBuilder := TDelphiProjectSnapshotBuilder.Create;
    lBuilder.DeferTargetMetadata := True;
    try
      try
        LoadStrings(aIdentity.CacheKey, lConnectionObject, lBuilder.Strings);
        LoadExactStrings(aIdentity.CacheKey, lConnectionObject, lBuilder.ExactStrings);
        if not LoadUnitHeader(aIdentity, lConnectionObject, lUnit, lStringCount, lSymbolCount,
          lWithStatementCount, lReferenceCount, lParseAvoidedEstimateMilliseconds) then
          raise Exception.Create('Snapshot unit header disappeared during load.');
        LoadSymbols(aIdentity.CacheKey, lConnectionObject, lUnit);
        LoadWithStatements(aIdentity.CacheKey, lConnectionObject, lUnit);
        LoadReferences(aIdentity.CacheKey, lConnectionObject, lUnit);
        LoadPhysicalEvidence(aIdentity.CacheKey, lConnectionObject, lBuilder.Strings, lBuilder.ExactStrings, lUnit);
        LoadTargetIdentities(aIdentity.CacheKey, lConnectionObject, lBuilder, lUnit);
        ValidateLoadedCounts(lBuilder.Strings, lUnit, lStringCount, lSymbolCount,
          lWithStatementCount, lReferenceCount);
        ValidateUnitStringIds(lBuilder.Strings, lUnit);
        ValidateUnitExactStringIds(lBuilder.ExactStrings, lUnit);
        lBuilder.AddUnit(lUnit);
        lUnit := nil;
        lIndexRebuildStopwatch := TStopwatch.StartNew;
        aSnapshot := lBuilder.Build;
        Inc(fMetrics.SnapshotIndexRebuildMilliseconds,
          VisibleElapsedMilliseconds(lIndexRebuildStopwatch));
        fMetrics.SnapshotParseAvoidedEstimateMilliseconds :=
          lParseAvoidedEstimateMilliseconds;
        lLoadCostMilliseconds := fMetrics.SnapshotSqlReadMilliseconds +
          fMetrics.SnapshotDeserializeMilliseconds +
          fMetrics.SnapshotIndexRebuildMilliseconds;
        fMetrics.SnapshotCacheUseful := (lParseAvoidedEstimateMilliseconds > 0)
          and (lParseAvoidedEstimateMilliseconds > lLoadCostMilliseconds);
        if lOwnsTransaction then
          lConnection.Commit;
        Inc(fMetrics.CacheHits);
        Result := True;
      except
        on E: Exception do
        begin
          FreeAndNil(aSnapshot);
          FreeAndNil(lUnit);
          if lOwnsTransaction and lConnection.InTransaction then
            lConnection.Rollback;
          fLastInvalidationReason := Copy('SNAPSHOT_LOAD_INVALID:' + E.Message, 1, 512);
          DeleteCacheKey(aIdentity.CacheKey);
          Inc(fMetrics.Invalidations);
          Inc(fMetrics.CacheMisses);
          Result := False;
        end;
      end;
    finally
      lBuilder.Free;
    end;
  finally
    if lOwnsTransaction and lConnection.InTransaction then
      lConnection.Rollback;
  end;
end;

function TDelphiSemanticSnapshotSqliteCache.TryLoadProjectRemoveWithPlanningFacts(
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  out aSnapshot: TDelphiProjectSnapshot): Boolean;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lConnectionObject: TObject;
  lEntryBelongsToIdentity: Boolean;
  lError: string;
  lIndexRebuildStopwatch: TStopwatch;
begin
  Result := False;
  aSnapshot := nil;
  ValidateIdentityComplete(aIdentity, 'load project remove-with planning facts for');
  ResetProbeMetrics;
  Inc(fMetrics.SnapshotCacheProbes);
  if not SharedConnection(lConnectionObject, lError) then
    raise Exception.Create('Cannot open SQLite snapshot cache: ' + lError);

  if not ProjectRemoveWithIdentityMatches(aIdentity, lConnectionObject,
    lEntryBelongsToIdentity) then
  begin
    if lEntryBelongsToIdentity then
    begin
      Inc(fMetrics.Invalidations);
      DeleteCacheKey(aIdentity.CacheKey);
    end;
    Inc(fMetrics.CacheMisses);
    Exit;
  end;

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    try
      LoadExactStrings(aIdentity.CacheKey, lConnectionObject, lBuilder.ExactStrings);
      LoadRemoveWithPlanningFacts(aIdentity.CacheKey, lConnectionObject, lBuilder);
      LoadRemoveWithVisibility(aIdentity.CacheKey, lConnectionObject, lBuilder);
      lIndexRebuildStopwatch := TStopwatch.StartNew;
      aSnapshot := lBuilder.Build;
      if not aSnapshot.HasRemoveWithPlanningFacts then
        raise Exception.Create('Snapshot project remove-with planning facts disappeared during load.');
      Inc(fMetrics.SnapshotIndexRebuildMilliseconds,
        VisibleElapsedMilliseconds(lIndexRebuildStopwatch));
      Inc(fMetrics.CacheHits);
      Result := True;
    except
      on E: Exception do
      begin
        aSnapshot.Free;
        aSnapshot := nil;
        DeleteCacheKey(aIdentity.CacheKey);
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
