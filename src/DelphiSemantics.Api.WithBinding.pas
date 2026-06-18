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
  System.SysUtils,
  DelphiSemantics.Api.ProjectOptions, DelphiSemantics.Cache.Sqlite,
  DelphiSemantics.ProjectContext;

function ModelOptionsFromApiOptions(const aOptions: TDelphiSemanticApiOptions;
  const aSourceFileName: string): TDelphiSemanticModelOptions;
begin
  Result := Default(TDelphiSemanticModelOptions);
  Result.SourceFileName := aSourceFileName;
  Result.Defines := aOptions.Defines;
  Result.SearchPaths := aOptions.SearchPaths;
  Result.ProjectContextApplied := aOptions.ProjectContextApplied;
end;

function ModelOptionsFromProjectContext(const aProject: TDelphiSemanticProjectInfo;
  const aSourceFileName: string): TDelphiSemanticModelOptions;
begin
  Result := Default(TDelphiSemanticModelOptions);
  Result.SourceFileName := aSourceFileName;
  Result.Defines := aProject.Defines;
  Result.SearchPaths := aProject.SourceLookupPaths;
  Result.ProjectContextApplied := True;
end;

function ModelDiagnosticFromProjectDiagnostic(
  const aDiagnostic: TDelphiSemanticDiagnostic): TDelphiSemanticModelDiagnostic;
begin
  Result := Default(TDelphiSemanticModelDiagnostic);
  Result.Code := aDiagnostic.Code;
  Result.Message := aDiagnostic.Message;
  Result.FileName := aDiagnostic.FileName;
  Result.Line := aDiagnostic.Line;
end;

function EmptyUnitIndex(const aCache: TDelphiSemanticUnitCache):
  TDelphiSemanticUnitIndex; forward;

function ProjectContextFailureIndex(const aProjectFileName: string;
  const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  const aCache: TDelphiSemanticUnitCache): TDelphiSemanticUnitIndex;
var
  i: Integer;
begin
  Result := EmptyUnitIndex(aCache);
  Result.Model.Success := False;
  Result.Model.FileName := aProjectFileName;
  SetLength(Result.Model.Diagnostics, Length(aDiagnostics));
  for i := 0 to High(aDiagnostics) do
    Result.Model.Diagnostics[i] := ModelDiagnosticFromProjectDiagnostic(aDiagnostics[i]);
end;

procedure ApplyProjectMainUnitName(const aProject: TDelphiSemanticProjectInfo;
  var aModel: TDelphiSemanticUnitModel);
begin
  if aModel.Success and (aModel.UnitName = '') and
    SameText(aModel.FileName, aProject.MainSourceFileName) then
    aModel.UnitName := aProject.ProjectName;
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
  lContext: TDelphiSemanticContextResult;
  lModelOptions: TDelphiSemanticModelOptions;
  lProject: TDelphiSemanticProjectInfo;
  lProjectOptions: TDelphiSemanticOptions;
  lSourceFileName: string;
begin
  if aOptions.Cache.SqliteCacheFileName <> '' then
    lCache := TDelphiSemanticSqliteUnitCache.Create(aOptions.Cache)
  else
    lCache := TDelphiSemanticUnitCache.Create(aOptions.Cache);
  try
    lSourceFileName := aOptions.SourceFileName;
    if aOptions.ProjectFileName <> '' then
    begin
      lProjectOptions := ProjectOptionsFromApiOptions(aOptions);
      lContext := TDelphiSemanticProject.Load(aOptions.ProjectFileName, lProjectOptions);
      if not lContext.Success then
        Exit(ProjectContextFailureIndex(aOptions.ProjectFileName, lContext.Diagnostics,
          lCache));

      lProject := lContext.Project;
      if lSourceFileName = '' then
        lSourceFileName := lProject.MainSourceFileName;
      if lSourceFileName = '' then
        Exit(EmptyUnitIndex(lCache));

      lModelOptions := ModelOptionsFromProjectContext(lProject, lSourceFileName);
    end else begin
      if lSourceFileName = '' then
        Exit(EmptyUnitIndex(lCache));

      lModelOptions := ModelOptionsFromApiOptions(aOptions, lSourceFileName);
    end;

    Result.Model := lCache.GetOrExtractUnitModel(lModelOptions);
    if aOptions.ProjectFileName <> '' then
      ApplyProjectMainUnitName(lProject, Result.Model);
    Result.Success := Result.Model.Success;
    Result.Bindings := TDelphiSemanticWithBinder.BuildInventory(Result.Model).Bindings;
    Result.CacheMetrics := lCache.Metrics;
    Result.CacheDiagnostics := lCache.Diagnostics;
  finally
    lCache.Free;
  end;
end;

end.
