unit DelphiSemantics.Api;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.Index, DelphiSemantics.Model,
  DelphiSemantics.ProjectContext, DelphiSemantics.Query, DelphiSemantics.Symbols,
  DelphiSemantics.WithBinding;

type
  TDelphiSemanticDiagnosticSeverity =
    DelphiSemantics.ProjectContext.TDelphiSemanticDiagnosticSeverity;
  TDelphiSemanticProperty = DelphiSemantics.ProjectContext.TDelphiSemanticProperty;
  TDelphiSemanticDiagnostic = DelphiSemantics.ProjectContext.TDelphiSemanticDiagnostic;
  TDelphiSemanticProjectInfo = DelphiSemantics.ProjectContext.TDelphiSemanticProjectInfo;
  TDelphiSemanticContextResult = DelphiSemantics.ProjectContext.TDelphiSemanticContextResult;
  TDelphiSemanticCacheOptions = DelphiSemantics.Cache.TDelphiSemanticCacheOptions;
  TDelphiSemanticCacheMetrics = DelphiSemantics.Cache.TDelphiSemanticCacheMetrics;
  TDelphiSemanticCacheDiagnostic = DelphiSemantics.Cache.TDelphiSemanticCacheDiagnostic;
  TDelphiSemanticProjectSymbolIndex =
    DelphiSemantics.Index.TDelphiSemanticProjectSymbolIndex;
  TDelphiSemanticUnitModel = DelphiSemantics.Model.TDelphiSemanticUnitModel;
  TDelphiSemanticSymbolQueryContext =
    DelphiSemantics.Query.TDelphiSemanticSymbolQueryContext;
  TDelphiSemanticSymbolId = DelphiSemantics.Symbols.TDelphiSemanticSymbolId;
  TDelphiSemanticIndexedSymbol = DelphiSemantics.Symbols.TDelphiSemanticIndexedSymbol;
  TDelphiSemanticIndexedReference =
    DelphiSemantics.Symbols.TDelphiSemanticIndexedReference;
  TDelphiSemanticInventorySymbol = DelphiSemantics.WithBinding.TDelphiSemanticInventorySymbol;
  TDelphiSemanticWithBinding = DelphiSemantics.WithBinding.TDelphiSemanticWithBinding;
  TDelphiSemanticRemoveWithInventory =
    DelphiSemantics.WithBinding.TDelphiSemanticRemoveWithInventory;
  TDelphiSemanticWithBinder = DelphiSemantics.WithBinding.TDelphiSemanticWithBinder;

const
  dsInfo = DelphiSemantics.ProjectContext.dsInfo;
  dsWarning = DelphiSemantics.ProjectContext.dsWarning;
  dsError = DelphiSemantics.ProjectContext.dsError;

type
  TDelphiSemanticApiOptions = record
    ProjectFileName: string;
    SourceFileName: string;
    Configuration: string;
    Platform: string;
    DelphiVersion: string;
    RsVarsPath: string;
    EnvOptionsPath: string;
    EnvironmentVariables: TArray<TDelphiSemanticProperty>;
    Defines: TArray<string>;
    SearchPaths: TArray<string>;
    ProjectContextApplied: Boolean;
    Cache: TDelphiSemanticCacheOptions;
    UseLspEnrichment: Boolean;
  end;

  TDelphiSemanticUnitIndex = record
    Success: Boolean;
    Model: TDelphiSemanticUnitModel;
    Inventory: TDelphiSemanticRemoveWithInventory;
    Bindings: TArray<TDelphiSemanticWithBinding>;
    CacheMetrics: TDelphiSemanticCacheMetrics;
    CacheDiagnostics: TArray<TDelphiSemanticCacheDiagnostic>;
  end;

  TDelphiSemanticApi = record
  public
    class function LoadProjectContext(const aFileName: string;
      const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticContextResult; static;
    class function BuildUnitIndex(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticUnitIndex; static;
    class function BuildProjectSymbolIndex(const aContext: TDelphiSemanticSymbolQueryContext):
      TDelphiSemanticProjectSymbolIndex; static;
  end;

implementation

uses
  DelphiSemantics.Cache.Sqlite;

function ProjectOptionsFromApiOptions(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticOptions;
begin
  Result := Default(TDelphiSemanticOptions);
  Result.ProjectPath := aOptions.ProjectFileName;
  Result.Configuration := aOptions.Configuration;
  Result.Platform := aOptions.Platform;
  Result.DelphiVersion := aOptions.DelphiVersion;
  Result.RsVarsPath := aOptions.RsVarsPath;
  Result.EnvOptionsPath := aOptions.EnvOptionsPath;
  Result.EnvironmentVariables := aOptions.EnvironmentVariables;
  Result.SqliteCacheFileName := aOptions.Cache.SqliteCacheFileName;
  Result.UseLspEnrichment := aOptions.UseLspEnrichment;
end;

function ModelOptionsFromApiOptions(const aOptions: TDelphiSemanticApiOptions;
  const aSourceFileName: string): TDelphiSemanticModelOptions;
begin
  Result := Default(TDelphiSemanticModelOptions);
  Result.SourceFileName := aSourceFileName;
  Result.Defines := aOptions.Defines;
  Result.SearchPaths := aOptions.SearchPaths;
  Result.ProjectContextApplied := aOptions.ProjectContextApplied;
end;

function EmptyUnitIndex(const aCache: TDelphiSemanticUnitCache): TDelphiSemanticUnitIndex;
begin
  Result := Default(TDelphiSemanticUnitIndex);
  if Assigned(aCache) then
  begin
    Result.CacheMetrics := aCache.Metrics;
    Result.CacheDiagnostics := aCache.Diagnostics;
  end;
end;

class function TDelphiSemanticApi.LoadProjectContext(const aFileName: string;
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticContextResult;
var
  lOptions: TDelphiSemanticOptions;
begin
  lOptions := ProjectOptionsFromApiOptions(aOptions);
  Result := TDelphiSemanticProject.Load(aFileName, lOptions);
end;

class function TDelphiSemanticApi.BuildUnitIndex(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticUnitIndex;
var
  lCache: TDelphiSemanticUnitCache;
  lModelOptions: TDelphiSemanticModelOptions;
  lSourceFileName: string;
begin
  if aOptions.Cache.SqliteCacheFileName <> '' then
    lCache := TDelphiSemanticSqliteUnitCache.Create(aOptions.Cache)
  else
    lCache := TDelphiSemanticUnitCache.Create(aOptions.Cache);
  try
    lSourceFileName := aOptions.SourceFileName;
    if (lSourceFileName = '') and (aOptions.ProjectFileName <> '') then
      lSourceFileName := LoadProjectContext(aOptions.ProjectFileName, aOptions).Project.MainSourceFileName;

    if lSourceFileName = '' then
      Exit(EmptyUnitIndex(lCache));

    lModelOptions := ModelOptionsFromApiOptions(aOptions, lSourceFileName);
    Result.Model := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.Success := Result.Model.Success;
    Result.Inventory := TDelphiSemanticWithBinder.BuildInventory(Result.Model);
    Result.Bindings := Result.Inventory.Bindings;
    Result.CacheMetrics := lCache.Metrics;
    Result.CacheDiagnostics := lCache.Diagnostics;
  finally
    lCache.Free;
  end;
end;

class function TDelphiSemanticApi.BuildProjectSymbolIndex(
  const aContext: TDelphiSemanticSymbolQueryContext): TDelphiSemanticProjectSymbolIndex;
begin
  Result := TDelphiSemanticProjectSymbolIndexer.Build(aContext);
end;

end.
