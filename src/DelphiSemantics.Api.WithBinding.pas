unit DelphiSemantics.Api.WithBinding;

interface

uses
  DelphiSemantics.Api, DelphiSemantics.Cache, DelphiSemantics.Model, DelphiSemantics.WithBinding;

type
  TDelphiSemanticInventorySymbol = DelphiSemantics.WithBinding.TDelphiSemanticInventorySymbol;
  TDelphiSemanticWithBinding = DelphiSemantics.WithBinding.TDelphiSemanticWithBinding;

  TDelphiSemanticUnitIndex = record
    Success: Boolean;
    Model: TDelphiSemanticUnitModel;
    Bindings: TArray<TDelphiSemanticWithBinding>;
    CacheMetrics: TDelphiSemanticCacheMetrics;
    CacheDiagnostics: TArray<TDelphiSemanticCacheDiagnostic>;
  end;

  TDelphiSemanticWithBindingApi = record
  public
    class function BuildUnitIndex(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticUnitIndex; static;
  end;

implementation

uses
  DelphiSemantics.Cache.Sqlite;

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

class function TDelphiSemanticWithBindingApi.BuildUnitIndex(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticUnitIndex;
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
      lSourceFileName := TDelphiSemanticApi.LoadProjectContext(aOptions.ProjectFileName,
        aOptions).Project.MainSourceFileName;

    if lSourceFileName = '' then
      Exit(EmptyUnitIndex(lCache));

    lModelOptions := ModelOptionsFromApiOptions(aOptions, lSourceFileName);
    Result.Model := lCache.GetOrExtractUnitModel(lModelOptions);
    Result.Success := Result.Model.Success;
    Result.Bindings := TDelphiSemanticWithBinder.BuildInventory(Result.Model).Bindings;
    Result.CacheMetrics := lCache.Metrics;
    Result.CacheDiagnostics := lCache.Diagnostics;
  finally
    lCache.Free;
  end;
end;

end.
