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
    fMetrics: TDelphiSemanticCacheMetrics;
    fParserVersion: string;
    fModelVersion: string;
    function GetMetrics: TDelphiSemanticCacheMetrics;
    function GetModelVersion: string;
    function GetParserVersion: string;
    procedure SetModelVersion(const aValue: string);
    procedure SetParserVersion(const aValue: string);
  public
    constructor Create(const aOptions: TDelphiSemanticCacheOptions);
    destructor Destroy; override;
    function GetOrExtractUnitModel(const aOptions: TDelphiSemanticModelOptions):
      TDelphiSemanticUnitModel;
    property Metrics: TDelphiSemanticCacheMetrics read GetMetrics;
    property ModelVersion: string read GetModelVersion write SetModelVersion;
    property ParserVersion: string read GetParserVersion write SetParserVersion;
  end;

implementation

uses
  System.Classes, System.Hash, System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Preprocess, DelphiSemantics.Source, DelphiSemantics.Version;

const
  cCacheSchemaVersion = '1';
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

constructor TDelphiSemanticUnitCache.Create(const aOptions: TDelphiSemanticCacheOptions);
begin
  inherited Create;
  fEntries := TCacheDictionary.Create;
  if aOptions.SqliteCacheFileName = '' then
    fMetrics.CacheKind := 'in-memory'
  else
    fMetrics.CacheKind := 'sqlite';
  fParserVersion := aOptions.ParserVersion;
  if fParserVersion = '' then
    fParserVersion := cDefaultParserVersion;
  fModelVersion := aOptions.ModelVersion;
  if fModelVersion = '' then
    fModelVersion := DelphiSemanticsVersionText;
end;

destructor TDelphiSemanticUnitCache.Destroy;
begin
  fEntries.Free;
  inherited;
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

  Inc(fMetrics.CacheMisses);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(aOptions);
  lEntry.Key := lKey;
  lEntry.Model := CloneUnitModel(Result);
  lDictionary.AddOrSetValue(lIdentity, lEntry);
end;

procedure TDelphiSemanticUnitCache.SetModelVersion(const aValue: string);
begin
  fModelVersion := aValue;
end;

procedure TDelphiSemanticUnitCache.SetParserVersion(const aValue: string);
begin
  fParserVersion := aValue;
end;

end.
