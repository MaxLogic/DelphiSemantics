unit DelphiSemantics.Cache;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Model;

type
  TDelphiSemanticCacheOptions = record
    SqliteCacheFileName: string;
    CompilerProfileName: string;
    DelphiVersion: string;
    Configuration: string;
    Platform: string;
    ParserVersion: string;
    ModelVersion: string;
  end;

  TDelphiSemanticCacheMetrics = record
    CacheFileName: string;
    CacheKind: string;
    CacheHits: Integer;
    CacheMisses: Integer;
    Invalidations: Integer;
    PersistentConnectionOpenCount: Integer;
  end;

  TDelphiSemanticCacheIdentityContext = record
    SchemaVersion: string;
    ParserVersion: string;
    IncludeGraphHash: string;
    DelphiVersion: string;
    Platform: string;
    ParserDefines: string;
    Defines: TArray<string>;
    UnitScopes: TArray<string>;
    UnitAliases: TArray<string>;
    ProjectPath: string;
    Configuration: string;
    SearchPaths: TArray<string>;
    ExtractionOptionsHash: string;
    CentralCacheRoot: string;
  end;

  TDelphiSemanticUnitCacheIdentity = record
    UnitCacheKey: string;
    SourceFileName: string;
    FileHash: string;
    FileTimestampUtc: string;
    ContextHash: string;
    IncludeGraphHash: string;
    DefinesHash: string;
    SearchPathHash: string;
    ExtractionOptionsHash: string;
    CompilerProfileName: string;
    DelphiVersion: string;
    Configuration: string;
    Platform: string;
    ParserVersion: string;
    ModelVersion: string;
    SchemaVersion: string;
  end;

  TDelphiSemanticProjectCacheIdentity = record
    ProjectKey: string;
    DefinesHash: string;
    SearchPathHash: string;
    UnitScopeHash: string;
    AliasHash: string;
  end;

  TDelphiSemanticCacheDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
  end;

  TDelphiSemanticUnitCacheAccessResult = record
    Model: TDelphiSemanticUnitModel;
    Identity: TDelphiSemanticUnitCacheIdentity;
    CacheHit: Boolean;
  end;

  TDelphiSemanticUnitModelBuilder = reference to function(
    const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel;

  TDelphiSemanticCacheIdentityBuilder = record
  public
    class function CanonicalPath(const aPath: string): string; static;
    class function BuildContextHash(const aContext: TDelphiSemanticCacheIdentityContext):
      string; static;
    class function BuildProjectIdentity(const aContext: TDelphiSemanticCacheIdentityContext):
      TDelphiSemanticProjectCacheIdentity; static;
    class function BuildUnitIdentity(const aSourceFileName: string;
      const aContext: TDelphiSemanticCacheIdentityContext):
      TDelphiSemanticUnitCacheIdentity; static;
  end;

  TDelphiSemanticUnitCache = class
  private
    type
      TCacheEntry = record
        Key: string;
        Model: TDelphiSemanticUnitModel;
      end;
      TCacheDictionary = TDictionary<string, TCacheEntry>;
  private
    fEntries: TCacheDictionary;
    fDiagnostics: TList<TDelphiSemanticCacheDiagnostic>;
    fMetrics: TDelphiSemanticCacheMetrics;
    fAccessLock: TObject;
    fAccessActive: Boolean;
    fCompilerProfileName: string;
    fConfiguration: string;
    fDelphiVersion: string;
    fParserVersion: string;
    fPlatform: string;
    fModelVersion: string;
    procedure EnterAccess(const aMarkActive: Boolean);
    procedure LeaveAccess(const aMarkedActive: Boolean);
    function GetCompilerProfileName: string;
    function GetDiagnostics: TArray<TDelphiSemanticCacheDiagnostic>;
    function GetMetrics: TDelphiSemanticCacheMetrics;
    function GetModelVersion: string;
    function GetParserVersion: string;
  protected
    procedure AddDiagnostic(const aCode, aMessage, aFileName: string);
    function CurrentCompilerProfileName: string;
    procedure RecordPersistentInvalidation(const aIdentity, aKey: string); virtual;
    procedure RecordPersistentConnectionOpen;
    function PersistentEntryExistsForIdentity(const aIdentity: string): Boolean; virtual;
    procedure SetCacheKind(const aValue: string);
    procedure StorePersistentEntry(const aIdentity, aKey: string;
      const aCacheIdentity: TDelphiSemanticUnitCacheIdentity;
      const aModel: TDelphiSemanticUnitModel); virtual;
    function TryLoadPersistentEntry(const aIdentity, aKey: string;
      out aModel: TDelphiSemanticUnitModel): Boolean; virtual;
    procedure SetCompilerProfileName(const aValue: string);
    procedure SetModelVersion(const aValue: string);
    procedure SetParserVersion(const aValue: string);
  public
    constructor Create(const aOptions: TDelphiSemanticCacheOptions);
    destructor Destroy; override;
    function GetOrExtractUnitModel(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitModel;
    function GetOrExtractUnitModelWithStatus(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitCacheAccessResult;
    function GetOrBuildUnitModelWithStatus(const aOptions: TDelphiSemanticModelOptions;
      const aBuilder: TDelphiSemanticUnitModelBuilder): TDelphiSemanticUnitCacheAccessResult;
    function BuildIdentity(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitCacheIdentity;
    property Diagnostics: TArray<TDelphiSemanticCacheDiagnostic> read GetDiagnostics;
    property Metrics: TDelphiSemanticCacheMetrics read GetMetrics;
    property CompilerProfileName: string read GetCompilerProfileName write SetCompilerProfileName;
    property Configuration: string read fConfiguration;
    property DelphiVersion: string read fDelphiVersion;
    property ModelVersion: string read GetModelVersion write SetModelVersion;
    property ParserVersion: string read GetParserVersion write SetParserVersion;
    property Platform: string read fPlatform;
  end;

implementation

uses
  System.Classes, System.Hash, System.IOUtils, System.SysUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source, DelphiSemantics.Version;

const
  cCacheSchemaVersion = '9';
  cDefaultCompilerProfileName = 'default';
  cDefaultIdentityIncludeGraphHash = 'no-includes-v1';
  cDefaultIdentityParserVersion = 'symbol-map-parser-v2';
  cDefaultIdentitySchemaVersion = '1';
  cDefaultParserVersion = 'DelphiSemantics.Model.Parser.13';
  cUnitCacheSingleThreadMessage = 'TDelphiSemanticUnitCache instances are single-threaded; use one cache instance per operation or add external synchronization.';

function StableHash(const aText: string): string;
begin
  Result := THashSHA2.GetHashString(aText);
end;

function HashBytes(const aBytes: TBytes): string;
var
  lHash: THashSHA2;
begin
  lHash := THashSHA2.Create;
  if Length(aBytes) > 0 then
    lHash.Update(aBytes);
  Result := lHash.HashAsString;
end;

function HashFileIfExists(const aFileName: string): string;
begin
  if TFile.Exists(aFileName) then
    Result := HashBytes(TFile.ReadAllBytes(aFileName))
  else
    Result := '';
end;

function FileTimestampIfExists(const aFileName: string): string;
begin
  if TFile.Exists(aFileName) then
    Result := FormatDateTime('yyyymmddhhnnsszzz', TFile.GetLastWriteTimeUtc(aFileName))
  else
    Result := '';
end;

function EffectiveIdentityValue(const aValue, aDefault: string): string;
begin
  Result := Trim(aValue);
  if Result = '' then
    Result := aDefault;
end;

function CanonicalIdentityText(const aValue: string): string;
begin
  Result := LowerCase(Trim(aValue));
end;

function CanonicalIdentityPath(const aPath: string): string;
var
  lPath: string;
  lRoot: string;
begin
  lPath := Trim(aPath);
  if lPath = '' then
    Exit('');

  lPath := StringReplace(lPath, '/', '\', [rfReplaceAll]);
  if Pos('$(', lPath) > 0 then
  begin
    Result := LowerCase(lPath);
    Exit;
  end;
  try
    Result := LowerCase(TPath.GetFullPath(lPath));
  except
    // MSBuild macros and unresolved variables are still stable identity text.
    Result := LowerCase(lPath);
  end;
  try
    lRoot := LowerCase(TPath.GetPathRoot(Result));
  except
    lRoot := '';
  end;
  if (Result <> '') and (not SameText(Result, lRoot)) then
    Result := ExcludeTrailingPathDelimiter(Result);
end;

function CanonicalIdentityArrayText(const aValues: TArray<string>;
  const aSortValues, aValuesArePaths: Boolean): string;
var
  lList: TStringList;
  lNormalized: string;
  lValue: string;
begin
  lList := TStringList.Create;
  try
    lList.CaseSensitive := False;
    lList.Sorted := aSortValues;
    if aSortValues then
      lList.Duplicates := dupIgnore;
    for lValue in aValues do
    begin
      if aValuesArePaths then
        lNormalized := CanonicalIdentityPath(lValue)
      else
        lNormalized := CanonicalIdentityText(lValue);
      if lNormalized <> '' then
        lList.Add(lNormalized);
    end;
    Result := lList.Text;
  finally
    lList.Free;
  end;
end;

function CanonicalIdentityDefinesText(const aContext: TDelphiSemanticCacheIdentityContext):
  string;
begin
  if Length(aContext.Defines) > 0 then
    Exit(CanonicalIdentityArrayText(aContext.Defines, True, False));

  Result := CanonicalIdentityArrayText(aContext.ParserDefines.Split([';']), True, False);
end;

function ExtractionOptionsIdentityText(const aOptions: TDelphiSemanticModelOptions): string;
begin
  Result := 'projectContextApplied=' + BoolToStr(aOptions.ProjectContextApplied, True) +
    sLineBreak + 'skipBodyAnalysis=' + BoolToStr(aOptions.SkipBodyAnalysis, True) +
    sLineBreak + 'skipReferenceExtraction=' + BoolToStr(aOptions.SkipReferenceExtraction, True) +
    sLineBreak + 'writableTypedConstants=' + BoolToStr(aOptions.WritableTypedConstants, True);
end;

function ModelOptionsIdentityContext(const aOptions: TDelphiSemanticModelOptions;
  const aSchemaVersion, aParserVersion, aDelphiVersion, aConfiguration,
  aPlatform: string): TDelphiSemanticCacheIdentityContext;
begin
  Result := Default(TDelphiSemanticCacheIdentityContext);
  Result.SchemaVersion := aSchemaVersion;
  Result.ParserVersion := aParserVersion;
  Result.DelphiVersion := aDelphiVersion;
  Result.Configuration := aConfiguration;
  Result.Platform := aPlatform;
  Result.Defines := aOptions.Defines;
  Result.SearchPaths := aOptions.SearchPaths;
  Result.ExtractionOptionsHash := StableHash(ExtractionOptionsIdentityText(aOptions));
end;

class function TDelphiSemanticCacheIdentityBuilder.CanonicalPath(
  const aPath: string): string;
begin
  Result := CanonicalIdentityPath(aPath);
end;

class function TDelphiSemanticCacheIdentityBuilder.BuildContextHash(
  const aContext: TDelphiSemanticCacheIdentityContext): string;
var
  lBuilder: TStringBuilder;
begin
  lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendLine('schema=' + EffectiveIdentityValue(aContext.SchemaVersion,
      cDefaultIdentitySchemaVersion));
    lBuilder.AppendLine('parser=' + EffectiveIdentityValue(aContext.ParserVersion,
      cDefaultIdentityParserVersion));
    lBuilder.AppendLine('includeGraph=' + EffectiveIdentityValue(aContext.IncludeGraphHash,
      cDefaultIdentityIncludeGraphHash));
    lBuilder.AppendLine('delphi=' + CanonicalIdentityText(aContext.DelphiVersion));
    lBuilder.AppendLine('config=' + CanonicalIdentityText(aContext.Configuration));
    lBuilder.AppendLine('platform=' + CanonicalIdentityText(aContext.Platform));
    lBuilder.AppendLine('defines=' + CanonicalIdentityDefinesText(aContext));
    lBuilder.AppendLine('search=' + CanonicalIdentityArrayText(aContext.SearchPaths,
      False, True));
    lBuilder.AppendLine('unitScopes=' + CanonicalIdentityArrayText(aContext.UnitScopes,
      False, False));
    lBuilder.AppendLine('unitAliases=' + CanonicalIdentityArrayText(aContext.UnitAliases,
      False, False));
    Result := StableHash(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

class function TDelphiSemanticCacheIdentityBuilder.BuildProjectIdentity(
  const aContext: TDelphiSemanticCacheIdentityContext): TDelphiSemanticProjectCacheIdentity;
var
  lBuilder: TStringBuilder;
begin
  Result := Default(TDelphiSemanticProjectCacheIdentity);
  Result.DefinesHash := StableHash(CanonicalIdentityDefinesText(aContext));
  Result.SearchPathHash := StableHash(CanonicalIdentityArrayText(aContext.SearchPaths,
    False, True));
  Result.UnitScopeHash := StableHash(CanonicalIdentityArrayText(aContext.UnitScopes,
    False, False));
  Result.AliasHash := StableHash(CanonicalIdentityArrayText(aContext.UnitAliases,
    False, False));

  lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendLine('project=' + CanonicalIdentityPath(aContext.ProjectPath));
    lBuilder.AppendLine('config=' + CanonicalIdentityText(aContext.Configuration));
    lBuilder.AppendLine('platform=' + CanonicalIdentityText(aContext.Platform));
    lBuilder.AppendLine('delphi=' + CanonicalIdentityText(aContext.DelphiVersion));
    lBuilder.AppendLine('defines=' + CanonicalIdentityDefinesText(aContext));
    lBuilder.AppendLine('search=' + CanonicalIdentityArrayText(aContext.SearchPaths,
      False, True));
    lBuilder.AppendLine('scopes=' + CanonicalIdentityArrayText(aContext.UnitScopes,
      False, False));
    lBuilder.AppendLine('aliases=' + CanonicalIdentityArrayText(aContext.UnitAliases,
      False, False));
    Result.ProjectKey := StableHash(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

class function TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(const aSourceFileName: string;
  const aContext: TDelphiSemanticCacheIdentityContext): TDelphiSemanticUnitCacheIdentity;
var
  lSourceFileName: string;
begin
  lSourceFileName := CanonicalIdentityPath(aSourceFileName);
  Result := Default(TDelphiSemanticUnitCacheIdentity);
  Result.SourceFileName := lSourceFileName;
  Result.SchemaVersion := EffectiveIdentityValue(aContext.SchemaVersion,
    cDefaultIdentitySchemaVersion);
  Result.ParserVersion := EffectiveIdentityValue(aContext.ParserVersion,
    cDefaultIdentityParserVersion);
  Result.IncludeGraphHash := EffectiveIdentityValue(aContext.IncludeGraphHash,
    cDefaultIdentityIncludeGraphHash);
  Result.FileHash := HashFileIfExists(lSourceFileName);
  Result.FileTimestampUtc := FileTimestampIfExists(lSourceFileName);
  Result.ContextHash := BuildContextHash(aContext);
  Result.DefinesHash := StableHash(CanonicalIdentityDefinesText(aContext));
  Result.SearchPathHash := StableHash(CanonicalIdentityArrayText(aContext.SearchPaths,
    False, True));
  Result.ExtractionOptionsHash := StableHash('');
  if Trim(aContext.ExtractionOptionsHash) <> '' then
    Result.ExtractionOptionsHash := Trim(aContext.ExtractionOptionsHash);
  Result.DelphiVersion := aContext.DelphiVersion;
  Result.Configuration := aContext.Configuration;
  Result.Platform := aContext.Platform;
  Result.UnitCacheKey := StableHash('unit|' + Result.SchemaVersion + '|' + Result.ParserVersion +
    '|' + Result.FileHash + '|' + Result.IncludeGraphHash + '|' + Result.ContextHash + '|' +
    Result.SearchPathHash + '|' + Result.ExtractionOptionsHash + '|' +
    CanonicalIdentityText(Result.Configuration));
end;

function CloneUnitModel(const aModel: TDelphiSemanticUnitModel): TDelphiSemanticUnitModel;
var
  i: Integer;
begin
  Result := aModel;
  Result.InterfaceUses := Copy(aModel.InterfaceUses);
  Result.ImplementationUses := Copy(aModel.ImplementationUses);
  Result.Declarations := Copy(aModel.Declarations);
  Result.Members := Copy(aModel.Members);
  Result.Routines := Copy(aModel.Routines);
  for i := 0 to Pred(Length(Result.Routines)) do
    Result.Routines[i].Parameters := Copy(aModel.Routines[i].Parameters);
  Result.Locals := Copy(aModel.Locals);
  Result.References := Copy(aModel.References);
  Result.WithStatements := Copy(aModel.WithStatements);
  Result.Diagnostics := Copy(aModel.Diagnostics);
end;

function BuildPreprocessResult(const aSource: TDelphiSemanticSourceLoadResult;
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticPreprocessResult;
var
  lOptions: TDelphiSemanticPreprocessOptions;
begin
  lOptions := Default(TDelphiSemanticPreprocessOptions);
  lOptions.SourceFileName := aOptions.SourceFileName;
  lOptions.SourceText := aSource.Source.Text;
  lOptions.Defines := aOptions.Defines;
  lOptions.SearchPaths := aOptions.SearchPaths;
  Result := TDelphiSemanticPreprocessor.PreprocessFile(lOptions);
end;

function BuildUnitCacheKey(const aIdentity: TDelphiSemanticUnitCacheIdentity): string;
begin
  Result := StableHash(
    'schema=' + aIdentity.SchemaVersion + sLineBreak +
    'library=' + DelphiSemanticsVersionText + sLineBreak +
    'compilerProfile=' + aIdentity.CompilerProfileName + sLineBreak +
    'delphi=' + aIdentity.DelphiVersion + sLineBreak +
    'configuration=' + aIdentity.Configuration + sLineBreak +
    'platform=' + aIdentity.Platform + sLineBreak +
    'parser=' + aIdentity.ParserVersion + sLineBreak +
    'model=' + aIdentity.ModelVersion + sLineBreak +
    'file=' + aIdentity.SourceFileName + sLineBreak +
    'source=' + aIdentity.FileHash + sLineBreak +
    'include=' + aIdentity.IncludeGraphHash + sLineBreak +
    'context=' + aIdentity.ContextHash);
end;

function BuildLoadedUnitIdentity(const aOptions: TDelphiSemanticModelOptions;
  const aCompilerProfileName, aParserVersion, aModelVersion, aDelphiVersion, aConfiguration,
  aPlatform: string):
  TDelphiSemanticUnitCacheIdentity;
var
  lContext: TDelphiSemanticCacheIdentityContext;
  lPreprocessResult: TDelphiSemanticPreprocessResult;
  lSourceFileName: string;
  lSourceResult: TDelphiSemanticSourceLoadResult;
begin
  lSourceFileName := CanonicalIdentityPath(aOptions.SourceFileName);
  lSourceResult := TDelphiSemanticSourceLoader.LoadFile(lSourceFileName);
  if lSourceResult.Success then
    lPreprocessResult := BuildPreprocessResult(lSourceResult, aOptions)
  else
    lPreprocessResult := Default(TDelphiSemanticPreprocessResult);

  Result := Default(TDelphiSemanticUnitCacheIdentity);
  Result.SourceFileName := lSourceFileName;
  Result.SchemaVersion := cCacheSchemaVersion;
  Result.ParserVersion := aParserVersion;
  Result.IncludeGraphHash := lPreprocessResult.IncludeGraphHash;
  if lSourceResult.Success then
    Result.FileHash := lSourceResult.Source.ContentHash
  else
    Result.FileHash := '';
  Result.FileTimestampUtc := FileTimestampIfExists(lSourceFileName);
  Result.CompilerProfileName := aCompilerProfileName;
  Result.DelphiVersion := aDelphiVersion;
  Result.Configuration := aConfiguration;
  Result.Platform := aPlatform;
  Result.ModelVersion := aModelVersion;
  lContext := ModelOptionsIdentityContext(aOptions, cCacheSchemaVersion,
    cDefaultParserVersion, '', '', '');
  Result.ContextHash := StableHash('context=' +
    TDelphiSemanticCacheIdentityBuilder.BuildContextHash(lContext) + sLineBreak +
    'extraction=' + lContext.ExtractionOptionsHash);
  Result.DefinesHash := StableHash(CanonicalIdentityDefinesText(lContext));
  Result.SearchPathHash := StableHash(CanonicalIdentityArrayText(lContext.SearchPaths,
    False, True));
  Result.ExtractionOptionsHash := lContext.ExtractionOptionsHash;
  Result.UnitCacheKey := BuildUnitCacheKey(Result);
end;

procedure TDelphiSemanticUnitCache.AddDiagnostic(const aCode, aMessage, aFileName: string);
var
  lDiagnostic: TDelphiSemanticCacheDiagnostic;
begin
  lDiagnostic.Code := aCode;
  lDiagnostic.Message := aMessage;
  lDiagnostic.FileName := aFileName;
  fDiagnostics.Add(lDiagnostic);
end;

constructor TDelphiSemanticUnitCache.Create(const aOptions: TDelphiSemanticCacheOptions);
begin
  inherited Create;
  fAccessLock := TObject.Create;
  fEntries := TCacheDictionary.Create;
  fDiagnostics := TList<TDelphiSemanticCacheDiagnostic>.Create;
  fMetrics.CacheKind := 'in-memory';
  fMetrics.CacheFileName := aOptions.SqliteCacheFileName;
  fCompilerProfileName := aOptions.CompilerProfileName;
  if fCompilerProfileName = '' then
    fCompilerProfileName := cDefaultCompilerProfileName;
  fDelphiVersion := aOptions.DelphiVersion;
  fConfiguration := aOptions.Configuration;
  fPlatform := aOptions.Platform;
  fParserVersion := aOptions.ParserVersion;
  if fParserVersion = '' then
    fParserVersion := cDefaultParserVersion;
  fModelVersion := aOptions.ModelVersion;
  if fModelVersion = '' then
    fModelVersion := DelphiSemanticsVersionText;
end;

destructor TDelphiSemanticUnitCache.Destroy;
begin
  fDiagnostics.Free;
  fEntries.Free;
  fAccessLock.Free;
  inherited;
end;

procedure TDelphiSemanticUnitCache.EnterAccess(const aMarkActive: Boolean);
begin
  if not TMonitor.TryEnter(fAccessLock) then
    raise EInvalidOperation.Create(cUnitCacheSingleThreadMessage);
  try
    if fAccessActive then
      raise EInvalidOperation.Create(cUnitCacheSingleThreadMessage);
    if aMarkActive then
      fAccessActive := True;
  except
    TMonitor.Exit(fAccessLock);
    raise;
  end;
end;

procedure TDelphiSemanticUnitCache.LeaveAccess(const aMarkedActive: Boolean);
begin
  if aMarkedActive then
    fAccessActive := False;
  TMonitor.Exit(fAccessLock);
end;

function TDelphiSemanticUnitCache.GetCompilerProfileName: string;
begin
  EnterAccess(False);
  try
    Result := fCompilerProfileName;
  finally
    LeaveAccess(False);
  end;
end;

function TDelphiSemanticUnitCache.CurrentCompilerProfileName: string;
begin
  Result := fCompilerProfileName;
end;

function TDelphiSemanticUnitCache.GetDiagnostics: TArray<TDelphiSemanticCacheDiagnostic>;
begin
  EnterAccess(False);
  try
    Result := fDiagnostics.ToArray;
  finally
    LeaveAccess(False);
  end;
end;

function TDelphiSemanticUnitCache.GetMetrics: TDelphiSemanticCacheMetrics;
begin
  EnterAccess(False);
  try
    Result := fMetrics;
  finally
    LeaveAccess(False);
  end;
end;

function TDelphiSemanticUnitCache.GetModelVersion: string;
begin
  EnterAccess(False);
  try
    Result := fModelVersion;
  finally
    LeaveAccess(False);
  end;
end;

function TDelphiSemanticUnitCache.GetParserVersion: string;
begin
  EnterAccess(False);
  try
    Result := fParserVersion;
  finally
    LeaveAccess(False);
  end;
end;

function TDelphiSemanticUnitCache.BuildIdentity(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitCacheIdentity;
begin
  EnterAccess(False);
  try
    Result := BuildLoadedUnitIdentity(aOptions, fCompilerProfileName, fParserVersion,
      fModelVersion, fDelphiVersion, fConfiguration, fPlatform);
  finally
    LeaveAccess(False);
  end;
end;

function TDelphiSemanticUnitCache.PersistentEntryExistsForIdentity(
  const aIdentity: string): Boolean;
begin
  Result := False;
end;

procedure TDelphiSemanticUnitCache.RecordPersistentInvalidation(const aIdentity, aKey: string);
begin
end;

function TDelphiSemanticUnitCache.GetOrExtractUnitModel(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel;
begin
  Result := GetOrExtractUnitModelWithStatus(aOptions).Model;
end;

function TDelphiSemanticUnitCache.GetOrExtractUnitModelWithStatus(
  const aOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitCacheAccessResult;
begin
  Result := GetOrBuildUnitModelWithStatus(aOptions,
    function(const aBuildOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel
    begin
      Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(aBuildOptions);
    end);
end;

function TDelphiSemanticUnitCache.GetOrBuildUnitModelWithStatus(
  const aOptions: TDelphiSemanticModelOptions;
  const aBuilder: TDelphiSemanticUnitModelBuilder): TDelphiSemanticUnitCacheAccessResult;
var
  lDictionary: TCacheDictionary;
  lEntry: TCacheEntry;
  lIdentity: string;
  lKey: string;
begin
  EnterAccess(True);
  try
    Result := Default(TDelphiSemanticUnitCacheAccessResult);
    Result.Identity := BuildLoadedUnitIdentity(aOptions, fCompilerProfileName, fParserVersion,
      fModelVersion, fDelphiVersion, fConfiguration, fPlatform);
    lIdentity := CanonicalIdentityPath(aOptions.SourceFileName);
    lKey := Result.Identity.UnitCacheKey;
    lDictionary := fEntries;
    if lDictionary.TryGetValue(lIdentity, lEntry) then
    begin
      if lEntry.Key = lKey then
      begin
        Inc(fMetrics.CacheHits);
        Result.CacheHit := True;
        Result.Model := CloneUnitModel(lEntry.Model);
        Exit;
      end;
      Inc(fMetrics.Invalidations);
    end;

    if TryLoadPersistentEntry(lIdentity, lKey, Result.Model) then
    begin
      Inc(fMetrics.CacheHits);
      Result.CacheHit := True;
      lEntry.Key := lKey;
      lEntry.Model := CloneUnitModel(Result.Model);
      lDictionary.AddOrSetValue(lIdentity, lEntry);
      Result.Model := CloneUnitModel(Result.Model);
      Exit;
    end;

    if PersistentEntryExistsForIdentity(lIdentity) then
    begin
      Inc(fMetrics.Invalidations);
      RecordPersistentInvalidation(lIdentity, lKey);
    end;

    Inc(fMetrics.CacheMisses);
    Result.Model := aBuilder(aOptions);
    lEntry.Key := lKey;
    lEntry.Model := CloneUnitModel(Result.Model);
    lDictionary.AddOrSetValue(lIdentity, lEntry);
    StorePersistentEntry(lIdentity, lKey, Result.Identity, Result.Model);
  finally
    LeaveAccess(True);
  end;
end;

procedure TDelphiSemanticUnitCache.SetCompilerProfileName(const aValue: string);
begin
  EnterAccess(False);
  try
    fCompilerProfileName := aValue;
    if fCompilerProfileName = '' then
      fCompilerProfileName := cDefaultCompilerProfileName;
  finally
    LeaveAccess(False);
  end;
end;

procedure TDelphiSemanticUnitCache.SetModelVersion(const aValue: string);
begin
  EnterAccess(False);
  try
    fModelVersion := aValue;
  finally
    LeaveAccess(False);
  end;
end;

procedure TDelphiSemanticUnitCache.SetCacheKind(const aValue: string);
begin
  fMetrics.CacheKind := aValue;
end;

procedure TDelphiSemanticUnitCache.RecordPersistentConnectionOpen;
begin
  Inc(fMetrics.PersistentConnectionOpenCount);
end;

procedure TDelphiSemanticUnitCache.SetParserVersion(const aValue: string);
begin
  EnterAccess(False);
  try
    fParserVersion := aValue;
  finally
    LeaveAccess(False);
  end;
end;

procedure TDelphiSemanticUnitCache.StorePersistentEntry(const aIdentity, aKey: string;
  const aCacheIdentity: TDelphiSemanticUnitCacheIdentity;
  const aModel: TDelphiSemanticUnitModel);
begin
end;

function TDelphiSemanticUnitCache.TryLoadPersistentEntry(const aIdentity, aKey: string;
  out aModel: TDelphiSemanticUnitModel): Boolean;
begin
  aModel := Default(TDelphiSemanticUnitModel);
  Result := False;
end;

end.
