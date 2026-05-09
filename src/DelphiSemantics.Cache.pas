unit DelphiSemantics.Cache;

interface

uses
  System.Generics.Collections,
  DelphiSemantics.Model;

type
  TDelphiSemanticCacheOptions = record
    SqliteCacheFileName: string;
    ParserVersion: string;
    ModelVersion: string;
  end;

  TDelphiSemanticCacheMetrics = record
    CacheKind: string;
    CacheHits: Integer;
    CacheMisses: Integer;
    Invalidations: Integer;
  end;

  TDelphiSemanticCacheDiagnostic = record
    Code: string;
    Message: string;
    FileName: string;
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
    fParserVersion: string;
    fModelVersion: string;
    function GetDiagnostics: TArray<TDelphiSemanticCacheDiagnostic>;
    function GetMetrics: TDelphiSemanticCacheMetrics;
    function GetModelVersion: string;
    function GetParserVersion: string;
  protected
    procedure AddDiagnostic(const aCode, aMessage, aFileName: string);
    procedure RecordPersistentInvalidation(const aIdentity, aKey: string); virtual;
    function PersistentEntryExistsForIdentity(const aIdentity: string): Boolean; virtual;
    procedure SetCacheKind(const aValue: string);
    procedure StorePersistentEntry(const aIdentity, aKey: string;
      const aModel: TDelphiSemanticUnitModel); virtual;
    function TryLoadPersistentEntry(const aIdentity, aKey: string;
      out aModel: TDelphiSemanticUnitModel): Boolean; virtual;
    procedure SetModelVersion(const aValue: string);
    procedure SetParserVersion(const aValue: string);
  public
    constructor Create(const aOptions: TDelphiSemanticCacheOptions);
    destructor Destroy; override;
    function GetOrExtractUnitModel(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitModel;
    property Diagnostics: TArray<TDelphiSemanticCacheDiagnostic> read GetDiagnostics;
    property Metrics: TDelphiSemanticCacheMetrics read GetMetrics;
    property ModelVersion: string read GetModelVersion write SetModelVersion;
    property ParserVersion: string read GetParserVersion write SetParserVersion;
  end;

implementation

uses
  System.Classes, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source, DelphiSemantics.Version;

const
  cCacheSchemaVersion = '2';
  cDefaultParserVersion = 'DelphiSemantics.Model.Parser.1';

function StableHash(const aText: string): string;
begin
  Result := THashSHA2.GetHashString(aText);
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

function BuildSemanticContextHash(const aOptions: TDelphiSemanticModelOptions): string;
begin
  Result := StableHash(
    'defines=' + SortedArrayText(aOptions.Defines) + sLineBreak +
    'searchPaths=' + OrderedArrayText(aOptions.SearchPaths) + sLineBreak +
    'projectContextApplied=' + BoolToStr(aOptions.ProjectContextApplied, True));
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

function BuildCacheKey(const aOptions: TDelphiSemanticModelOptions; const aParserVersion,
  aModelVersion: string): string;
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
    'parser=' + aParserVersion + sLineBreak +
    'model=' + aModelVersion + sLineBreak +
    'file=' + UpperCase(lSourceFileName) + sLineBreak +
    'source=' + lSourceHash + sLineBreak +
    'include=' + lPreprocessResult.IncludeGraphHash + sLineBreak +
    'context=' + BuildSemanticContextHash(aOptions));
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
var
  lDictionary: TCacheDictionary;
  lEntry: TCacheEntry;
  lIdentity: string;
  lKey: string;
begin
  lIdentity := UpperCase(TPath.GetFullPath(aOptions.SourceFileName));
  lKey := BuildCacheKey(aOptions, fParserVersion, fModelVersion);
  lDictionary := fEntries;
  if lDictionary.TryGetValue(lIdentity, lEntry) then
  begin
    if lEntry.Key = lKey then
    begin
      Inc(fMetrics.CacheHits);
      Exit(CloneUnitModel(lEntry.Model));
    end;
    Inc(fMetrics.Invalidations);
  end;

  if TryLoadPersistentEntry(lIdentity, lKey, Result) then
  begin
    Inc(fMetrics.CacheHits);
    lEntry.Key := lKey;
    lEntry.Model := CloneUnitModel(Result);
    lDictionary.AddOrSetValue(lIdentity, lEntry);
    Exit(CloneUnitModel(Result));
  end;

  if PersistentEntryExistsForIdentity(lIdentity) then
  begin
    Inc(fMetrics.Invalidations);
    RecordPersistentInvalidation(lIdentity, lKey);
  end;

  Inc(fMetrics.CacheMisses);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(aOptions);
  lEntry.Key := lKey;
  lEntry.Model := CloneUnitModel(Result);
  lDictionary.AddOrSetValue(lIdentity, lEntry);
  StorePersistentEntry(lIdentity, lKey, Result);
end;

procedure TDelphiSemanticUnitCache.SetModelVersion(const aValue: string);
begin
  fModelVersion := aValue;
end;

procedure TDelphiSemanticUnitCache.SetCacheKind(const aValue: string);
begin
  fMetrics.CacheKind := aValue;
end;

procedure TDelphiSemanticUnitCache.SetParserVersion(const aValue: string);
begin
  fParserVersion := aValue;
end;

procedure TDelphiSemanticUnitCache.StorePersistentEntry(const aIdentity, aKey: string;
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
