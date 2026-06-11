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
    CentralCacheRoot: string;
  end;

  TDelphiSemanticUnitCacheIdentity = record
    UnitCacheKey: string;
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
    fCompilerProfileName: string;
    fConfiguration: string;
    fDelphiVersion: string;
    fParserVersion: string;
    fPlatform: string;
    fModelVersion: string;
    function GetCompilerProfileName: string;
    function GetDiagnostics: TArray<TDelphiSemanticCacheDiagnostic>;
    function GetMetrics: TDelphiSemanticCacheMetrics;
    function GetModelVersion: string;
    function GetParserVersion: string;
  protected
    procedure AddDiagnostic(const aCode, aMessage, aFileName: string);
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
  System.Classes, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source, DelphiSemantics.Version;

const
  cCacheSchemaVersion = '7';
  cDefaultCompilerProfileName = 'default';
  cDefaultIdentityIncludeGraphHash = 'no-includes-v1';
  cDefaultIdentityParserVersion = 'symbol-map-parser-v2';
  cDefaultIdentitySchemaVersion = '1';
  cDefaultParserVersion = 'DelphiSemantics.Model.Parser.2';

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

function SortedArrayText(const aValues: TArray<string>): string;
var
  lList: TStringList;
  lValue: string;
begin
  lList := TStringList.Create;
  try
    lList.CaseSensitive := False;
    lList.Sorted := True;
    lList.Duplicates := dupIgnore;
    for lValue in aValues do
      if lValue.Trim <> '' then
        lList.Add(lValue.Trim);
    Result := lList.Text;
  finally
    lList.Free;
  end;
end;

function NormalizeIdentityArray(const aValues: TArray<string>; const aSortValues: Boolean): string;
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
      lNormalized := LowerCase(Trim(lValue));
      if lNormalized <> '' then
        lList.Add(lNormalized);
    end;
    Result := lList.Text;
  finally
    lList.Free;
  end;
end;

function NormalizeIdentityDefines(const aContext: TDelphiSemanticCacheIdentityContext): string;
begin
  if Length(aContext.Defines) > 0 then
    Exit(NormalizeIdentityArray(aContext.Defines, True));

  Result := NormalizeIdentityArray(aContext.ParserDefines.Split([';']), True);
end;

function OrderedArrayText(const aValues: TArray<string>): string;
var
  lValue: string;
  sb: TStringBuilder;
begin
  sb := TStringBuilder.Create;
  try
    for lValue in aValues do
      if lValue.Trim <> '' then
        sb.AppendLine(lValue.Trim);
    Result := sb.ToString;
  finally
    sb.Free;
  end;
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
    lBuilder.AppendLine('delphi=' + LowerCase(Trim(aContext.DelphiVersion)));
    lBuilder.AppendLine('platform=' + LowerCase(Trim(aContext.Platform)));
    lBuilder.AppendLine('defines=' + NormalizeIdentityDefines(aContext));
    lBuilder.AppendLine('unitScopes=' + NormalizeIdentityArray(aContext.UnitScopes, False));
    lBuilder.AppendLine('unitAliases=' + NormalizeIdentityArray(aContext.UnitAliases, False));
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
  Result.DefinesHash := StableHash(NormalizeIdentityDefines(aContext));
  Result.SearchPathHash := StableHash(NormalizeIdentityArray(aContext.SearchPaths, False));
  Result.UnitScopeHash := StableHash(NormalizeIdentityArray(aContext.UnitScopes, False));
  Result.AliasHash := StableHash(NormalizeIdentityArray(aContext.UnitAliases, False));

  lBuilder := TStringBuilder.Create;
  try
    lBuilder.AppendLine('project=' + LowerCase(Trim(aContext.ProjectPath)));
    lBuilder.AppendLine('config=' + LowerCase(Trim(aContext.Configuration)));
    lBuilder.AppendLine('platform=' + LowerCase(Trim(aContext.Platform)));
    lBuilder.AppendLine('delphi=' + LowerCase(Trim(aContext.DelphiVersion)));
    lBuilder.AppendLine('defines=' + NormalizeIdentityDefines(aContext));
    lBuilder.AppendLine('search=' + NormalizeIdentityArray(aContext.SearchPaths, False));
    lBuilder.AppendLine('scopes=' + NormalizeIdentityArray(aContext.UnitScopes, False));
    lBuilder.AppendLine('aliases=' + NormalizeIdentityArray(aContext.UnitAliases, False));
    lBuilder.AppendLine('central=' + LowerCase(Trim(aContext.CentralCacheRoot)));
    Result.ProjectKey := StableHash(lBuilder.ToString);
  finally
    lBuilder.Free;
  end;
end;

class function TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(const aSourceFileName: string;
  const aContext: TDelphiSemanticCacheIdentityContext): TDelphiSemanticUnitCacheIdentity;
begin
  Result := Default(TDelphiSemanticUnitCacheIdentity);
  Result.SchemaVersion := EffectiveIdentityValue(aContext.SchemaVersion,
    cDefaultIdentitySchemaVersion);
  Result.ParserVersion := EffectiveIdentityValue(aContext.ParserVersion,
    cDefaultIdentityParserVersion);
  Result.IncludeGraphHash := EffectiveIdentityValue(aContext.IncludeGraphHash,
    cDefaultIdentityIncludeGraphHash);
  Result.FileHash := HashFileIfExists(aSourceFileName);
  Result.FileTimestampUtc := FileTimestampIfExists(aSourceFileName);
  Result.ContextHash := BuildContextHash(aContext);
  Result.DefinesHash := StableHash(NormalizeIdentityDefines(aContext));
  Result.SearchPathHash := StableHash(NormalizeIdentityArray(aContext.SearchPaths, False));
  Result.ExtractionOptionsHash := StableHash('');
  Result.DelphiVersion := aContext.DelphiVersion;
  Result.Configuration := aContext.Configuration;
  Result.Platform := aContext.Platform;
  Result.UnitCacheKey := StableHash('unit|' + Result.SchemaVersion + '|' + Result.ParserVersion +
    '|' + Result.FileHash + '|' + Result.FileTimestampUtc + '|' + Result.IncludeGraphHash + '|' +
    Result.ContextHash);
end;

function BuildSemanticContextHash(const aOptions: TDelphiSemanticModelOptions): string;
begin
  Result := StableHash(
    'defines=' + SortedArrayText(aOptions.Defines) + sLineBreak +
    'searchPaths=' + OrderedArrayText(aOptions.SearchPaths) + sLineBreak +
    'projectContextApplied=' + BoolToStr(aOptions.ProjectContextApplied, True) + sLineBreak +
    'skipBodyAnalysis=' + BoolToStr(aOptions.SkipBodyAnalysis, True) + sLineBreak +
    'skipReferenceExtraction=' + BoolToStr(aOptions.SkipReferenceExtraction, True));
end;

function BuildSemanticDefinesHash(const aOptions: TDelphiSemanticModelOptions): string;
begin
  Result := StableHash(SortedArrayText(aOptions.Defines));
end;

function BuildSemanticSearchPathHash(const aOptions: TDelphiSemanticModelOptions): string;
begin
  Result := StableHash(OrderedArrayText(aOptions.SearchPaths));
end;

function BuildSemanticExtractionOptionsHash(const aOptions: TDelphiSemanticModelOptions):
  string;
begin
  Result := StableHash(
    'projectContextApplied=' + BoolToStr(aOptions.ProjectContextApplied, True) + sLineBreak +
    'skipBodyAnalysis=' + BoolToStr(aOptions.SkipBodyAnalysis, True) + sLineBreak +
    'skipReferenceExtraction=' + BoolToStr(aOptions.SkipReferenceExtraction, True));
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

function BuildCacheKey(const aOptions: TDelphiSemanticModelOptions; const aCompilerProfileName,
  aParserVersion, aModelVersion, aDelphiVersion, aConfiguration, aPlatform: string): string;
var
  lPreprocessResult: TDelphiSemanticPreprocessResult;
  lSourceResult: TDelphiSemanticSourceLoadResult;
  lSourceFileName: string;
  lSourceHash: string;
begin
  lSourceFileName := TPath.GetFullPath(aOptions.SourceFileName);
  if TFile.Exists(lSourceFileName) then
    lSourceHash := THashSHA2.GetHashStringFromFile(lSourceFileName)
  else
    lSourceHash := '';

  lSourceResult := TDelphiSemanticSourceLoader.LoadFile(lSourceFileName);
  if lSourceResult.Success then
    lPreprocessResult := BuildPreprocessResult(lSourceResult, aOptions)
  else
    lPreprocessResult := Default(TDelphiSemanticPreprocessResult);

  Result := StableHash(
    'schema=' + cCacheSchemaVersion + sLineBreak +
    'library=' + DelphiSemanticsVersionText + sLineBreak +
    'compilerProfile=' + aCompilerProfileName + sLineBreak +
    'delphi=' + aDelphiVersion + sLineBreak +
    'configuration=' + aConfiguration + sLineBreak +
    'platform=' + aPlatform + sLineBreak +
    'parser=' + aParserVersion + sLineBreak +
    'model=' + aModelVersion + sLineBreak +
    'file=' + UpperCase(lSourceFileName) + sLineBreak +
    'source=' + lSourceHash + sLineBreak +
    'timestamp=' + FileTimestampIfExists(lSourceFileName) + sLineBreak +
    'include=' + lPreprocessResult.IncludeGraphHash + sLineBreak +
    'context=' + BuildSemanticContextHash(aOptions));
end;

function BuildInternalUnitIdentity(const aOptions: TDelphiSemanticModelOptions;
  const aCompilerProfileName, aParserVersion, aModelVersion, aDelphiVersion, aConfiguration,
  aPlatform: string):
  TDelphiSemanticUnitCacheIdentity;
var
  lPreprocessResult: TDelphiSemanticPreprocessResult;
  lSourceFileName: string;
  lSourceResult: TDelphiSemanticSourceLoadResult;
begin
  lSourceFileName := TPath.GetFullPath(aOptions.SourceFileName);
  lSourceResult := TDelphiSemanticSourceLoader.LoadFile(lSourceFileName);
  if lSourceResult.Success then
    lPreprocessResult := BuildPreprocessResult(lSourceResult, aOptions)
  else
    lPreprocessResult := Default(TDelphiSemanticPreprocessResult);

  Result := Default(TDelphiSemanticUnitCacheIdentity);
  Result.SchemaVersion := cCacheSchemaVersion;
  Result.ParserVersion := aParserVersion;
  Result.IncludeGraphHash := lPreprocessResult.IncludeGraphHash;
  Result.FileHash := HashFileIfExists(lSourceFileName);
  Result.FileTimestampUtc := FileTimestampIfExists(lSourceFileName);
  Result.ContextHash := BuildSemanticContextHash(aOptions);
  Result.DefinesHash := BuildSemanticDefinesHash(aOptions);
  Result.SearchPathHash := BuildSemanticSearchPathHash(aOptions);
  Result.ExtractionOptionsHash := BuildSemanticExtractionOptionsHash(aOptions);
  Result.CompilerProfileName := aCompilerProfileName;
  Result.DelphiVersion := aDelphiVersion;
  Result.Configuration := aConfiguration;
  Result.Platform := aPlatform;
  Result.ModelVersion := aModelVersion;
  Result.UnitCacheKey := BuildCacheKey(aOptions, aCompilerProfileName, aParserVersion,
    aModelVersion, aDelphiVersion, aConfiguration, aPlatform);
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
  inherited;
end;

function TDelphiSemanticUnitCache.GetCompilerProfileName: string;
begin
  Result := fCompilerProfileName;
end;

function TDelphiSemanticUnitCache.GetDiagnostics: TArray<TDelphiSemanticCacheDiagnostic>;
begin
  Result := fDiagnostics.ToArray;
end;

function TDelphiSemanticUnitCache.GetMetrics: TDelphiSemanticCacheMetrics;
begin
  Result := fMetrics;
end;

function TDelphiSemanticUnitCache.GetModelVersion: string;
begin
  Result := fModelVersion;
end;

function TDelphiSemanticUnitCache.GetParserVersion: string;
begin
  Result := fParserVersion;
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
  Result := Default(TDelphiSemanticUnitCacheAccessResult);
  Result.Identity := BuildInternalUnitIdentity(aOptions, fCompilerProfileName, fParserVersion,
    fModelVersion, fDelphiVersion, fConfiguration, fPlatform);
  lIdentity := UpperCase(TPath.GetFullPath(aOptions.SourceFileName));
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
end;

procedure TDelphiSemanticUnitCache.SetCompilerProfileName(const aValue: string);
begin
  fCompilerProfileName := aValue;
  if fCompilerProfileName = '' then
    fCompilerProfileName := cDefaultCompilerProfileName;
end;

procedure TDelphiSemanticUnitCache.SetModelVersion(const aValue: string);
begin
  fModelVersion := aValue;
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
  fParserVersion := aValue;
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
