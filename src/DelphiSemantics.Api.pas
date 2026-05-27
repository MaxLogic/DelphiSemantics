unit DelphiSemantics.Api;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.DeadCode, DelphiSemantics.Index, DelphiSemantics.Model,
  DelphiSemantics.ProjectContext, DelphiSemantics.ProjectSession, DelphiSemantics.Query,
  DelphiSemantics.Refactor, DelphiSemantics.Resolve.MemberResolver,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.Resolve.UnitResolver,
  DelphiSemantics.Search, DelphiSemantics.SemanticGraph, DelphiSemantics.Symbols,
  DelphiSemantics.Usage, DelphiSemantics.WithBinding, DelphiSemantics.WithScan;

type
  TDelphiSemanticDiagnosticSeverity =
    DelphiSemantics.ProjectContext.TDelphiSemanticDiagnosticSeverity;
  TDelphiSemanticProperty = DelphiSemantics.ProjectContext.TDelphiSemanticProperty;
  TDelphiSemanticDiagnostic = DelphiSemantics.ProjectContext.TDelphiSemanticDiagnostic;
  TDelphiSemanticProjectInfo = DelphiSemantics.ProjectContext.TDelphiSemanticProjectInfo;
  TDelphiSemanticContextResult = DelphiSemantics.ProjectContext.TDelphiSemanticContextResult;
  TDelphiSemanticProjectSessionStatus =
    DelphiSemantics.ProjectSession.TDelphiSemanticProjectSessionStatus;
  TDelphiSemanticProjectSession =
    DelphiSemantics.ProjectSession.TDelphiSemanticProjectSession;
  TDelphiSemanticProjectSessionResult =
    DelphiSemantics.ProjectSession.TDelphiSemanticProjectSessionResult;
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
  TDelphiSemanticUsage = DelphiSemantics.Usage.TDelphiSemanticUsage;
  TDelphiSemanticUsageResult = DelphiSemantics.Usage.TDelphiSemanticUsageResult;
  TDelphiSemanticDeadCodeCandidate =
    DelphiSemantics.DeadCode.TDelphiSemanticDeadCodeCandidate;
  TDelphiSemanticDeadCodeReport = DelphiSemantics.DeadCode.TDelphiSemanticDeadCodeReport;
  TDelphiSemanticTextEdit = DelphiSemantics.Refactor.TDelphiSemanticTextEdit;
  TDelphiSemanticRenamePlan = DelphiSemantics.Refactor.TDelphiSemanticRenamePlan;
  TDelphiSemanticDeadCodeRemovalBlocker =
    DelphiSemantics.Refactor.TDelphiSemanticDeadCodeRemovalBlocker;
  TDelphiSemanticDeadCodeRemovalPlan =
    DelphiSemantics.Refactor.TDelphiSemanticDeadCodeRemovalPlan;
  TDelphiSemanticSearchQuery = DelphiSemantics.Search.TDelphiSemanticSearchQuery;
  TDelphiSemanticSearchMatch = DelphiSemantics.Search.TDelphiSemanticSearchMatch;
  TDelphiSemanticSearchResult = DelphiSemantics.Search.TDelphiSemanticSearchResult;
  TDelphiSemanticInventorySymbol = DelphiSemantics.WithBinding.TDelphiSemanticInventorySymbol;
  TDelphiSemanticWithBinding = DelphiSemantics.WithBinding.TDelphiSemanticWithBinding;
  TDelphiSemanticRemoveWithInventory =
    DelphiSemantics.WithBinding.TDelphiSemanticRemoveWithInventory;
  TDelphiSemanticWithBinder = DelphiSemantics.WithBinding.TDelphiSemanticWithBinder;
  TDelphiSemanticWithScanOptions =
    DelphiSemantics.WithScan.TDelphiSemanticWithScanOptions;
  TDelphiSemanticWithScanResult =
    DelphiSemantics.WithScan.TDelphiSemanticWithScanResult;
  TDelphiSemanticWithScanner = DelphiSemantics.WithScan.TDelphiSemanticWithScanner;
  TDelphiSemanticUnitResolutionCandidate =
    DelphiSemantics.Resolve.UnitResolver.TDelphiSemanticUnitResolutionCandidate;
  TDelphiSemanticUnitResolutionResult =
    DelphiSemantics.Resolve.UnitResolver.TDelphiSemanticUnitResolutionResult;
  TDelphiSemanticUnitResolver =
    DelphiSemantics.Resolve.UnitResolver.TDelphiSemanticUnitResolver;
  TDelphiSemanticProjectGraphId =
    DelphiSemantics.SemanticGraph.TDelphiSemanticProjectGraphId;
  TDelphiSemanticUnitGraphId = DelphiSemantics.SemanticGraph.TDelphiSemanticUnitGraphId;
  TDelphiSemanticGraphSymbolId =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphSymbolId;
  TDelphiSemanticGraphTypeId = DelphiSemantics.SemanticGraph.TDelphiSemanticGraphTypeId;
  TDelphiSemanticSourceRange = DelphiSemantics.SemanticGraph.TDelphiSemanticSourceRange;
  TDelphiSemanticGraphUnit = DelphiSemantics.SemanticGraph.TDelphiSemanticGraphUnit;
  TDelphiSemanticGraphSymbol = DelphiSemantics.SemanticGraph.TDelphiSemanticGraphSymbol;
  TDelphiSemanticGraphDeclaration =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphDeclaration;
  TDelphiSemanticGraphType = DelphiSemantics.SemanticGraph.TDelphiSemanticGraphType;
  TDelphiSemanticGraphMember = DelphiSemantics.SemanticGraph.TDelphiSemanticGraphMember;
  TDelphiSemanticGraphParameter =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphParameter;
  TDelphiSemanticGraphRoutine = DelphiSemantics.SemanticGraph.TDelphiSemanticGraphRoutine;
  TDelphiSemanticGraphLocal = DelphiSemantics.SemanticGraph.TDelphiSemanticGraphLocal;
  TDelphiSemanticGraphReferenceId =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphReferenceId;
  TDelphiSemanticGraphWithStatementId =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphWithStatementId;
  TDelphiSemanticGraphReference =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphReference;
  TDelphiSemanticGraphWithStatement =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphWithStatement;
  TDelphiSemanticGraphBuildMetrics =
    DelphiSemantics.SemanticGraph.TDelphiSemanticGraphBuildMetrics;
  TDelphiSemanticSemanticGraph =
    DelphiSemantics.SemanticGraph.TDelphiSemanticSemanticGraph;
  TDelphiSemanticSemanticGraphBuilder =
    DelphiSemantics.SemanticGraph.TDelphiSemanticSemanticGraphBuilder;
  TDelphiSemanticTypeIdentity =
    DelphiSemantics.Resolve.TypeResolver.TDelphiSemanticTypeIdentity;
  TDelphiSemanticTypeLookupResult =
    DelphiSemantics.Resolve.TypeResolver.TDelphiSemanticTypeLookupResult;
  TDelphiSemanticTypeIdentityIndex =
    DelphiSemantics.Resolve.TypeResolver.TDelphiSemanticTypeIdentityIndex;
  TDelphiSemanticTypeResolver =
    DelphiSemantics.Resolve.TypeResolver.TDelphiSemanticTypeResolver;
  TDelphiSemanticMemberIdentity =
    DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberIdentity;
  TDelphiSemanticMemberLookupResult =
    DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberLookupResult;
  TDelphiSemanticMemberLookupContext =
    DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberLookupContext;
  TDelphiSemanticMemberIdentityIndex =
    DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberIdentityIndex;
  TDelphiSemanticMemberResolver =
    DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberResolver;

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
    class function OpenProjectSession(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticProjectSessionResult; static;
    class function ScanWithStatements(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticWithScanResult; static;
    class function BuildUnitIndex(const aOptions: TDelphiSemanticApiOptions):
      TDelphiSemanticUnitIndex; static;
    class function BuildProjectSymbolIndex(const aContext: TDelphiSemanticSymbolQueryContext):
      TDelphiSemanticProjectSymbolIndex; static;
    class function FindUsagesByName(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName: string): TDelphiSemanticUsageResult; static;
    class function FindUsagesAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
      const aFileName: string; const aLine, aColumn: Integer): TDelphiSemanticUsageResult;
      static;
    class function PlanRename(const aContext: TDelphiSemanticSymbolQueryContext;
      const aName, aNewName: string): TDelphiSemanticRenamePlan; static;
    class function PlanRenameAtPosition(const aContext: TDelphiSemanticSymbolQueryContext;
      const aFileName: string; const aLine, aColumn: Integer; const aNewName: string):
      TDelphiSemanticRenamePlan; static;
    class function PlanFunctionResultRefactorAtPosition(
      const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string;
      const aLine, aColumn: Integer): TDelphiSemanticRenamePlan; static;
    class function ReportDeadCode(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: string): TDelphiSemanticDeadCodeReport; static;
    class function PlanDeadCodeRemoval(const aContext: TDelphiSemanticSymbolQueryContext;
      const aProfile: string): TDelphiSemanticDeadCodeRemovalPlan; static;
    class function Search(const aContext: TDelphiSemanticSymbolQueryContext;
      const aQuery: TDelphiSemanticSearchQuery): TDelphiSemanticSearchResult; static;
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

function WithScanOptionsFromApiOptions(const aOptions: TDelphiSemanticApiOptions):
  TDelphiSemanticWithScanOptions;
begin
  Result := Default(TDelphiSemanticWithScanOptions);
  Result.SourceFileName := aOptions.SourceFileName;
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

class function TDelphiSemanticApi.OpenProjectSession(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticProjectSessionResult;
var
  lOptions: TDelphiSemanticOptions;
begin
  lOptions := ProjectOptionsFromApiOptions(aOptions);
  if lOptions.ProjectPath = '' then
    lOptions.ProjectPath := aOptions.ProjectFileName;
  Result := DelphiSemantics.ProjectSession.TDelphiSemanticProjectSession.Open(lOptions);
end;

class function TDelphiSemanticApi.ScanWithStatements(
  const aOptions: TDelphiSemanticApiOptions): TDelphiSemanticWithScanResult;
begin
  Result := TDelphiSemanticWithScanner.ScanFile(WithScanOptionsFromApiOptions(aOptions));
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

class function TDelphiSemanticApi.FindUsagesByName(
  const aContext: TDelphiSemanticSymbolQueryContext; const aName: string):
  TDelphiSemanticUsageResult;
begin
  Result := TDelphiSemanticUsageFinder.FindUsagesByName(aContext, aName);
end;

class function TDelphiSemanticApi.FindUsagesAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer): TDelphiSemanticUsageResult;
begin
  Result := TDelphiSemanticUsageFinder.FindUsagesAtPosition(aContext, aFileName, aLine,
    aColumn);
end;

class function TDelphiSemanticApi.PlanRename(const aContext: TDelphiSemanticSymbolQueryContext;
  const aName, aNewName: string): TDelphiSemanticRenamePlan;
begin
  Result := TDelphiSemanticRenamePlanner.PlanRename(aContext, aName, aNewName);
end;

class function TDelphiSemanticApi.PlanRenameAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer; const aNewName: string): TDelphiSemanticRenamePlan;
begin
  Result := TDelphiSemanticRenamePlanner.PlanRenameAtPosition(aContext, aFileName, aLine,
    aColumn, aNewName);
end;

class function TDelphiSemanticApi.PlanFunctionResultRefactorAtPosition(
  const aContext: TDelphiSemanticSymbolQueryContext; const aFileName: string; const aLine,
  aColumn: Integer): TDelphiSemanticRenamePlan;
begin
  Result := TDelphiSemanticRenamePlanner.PlanFunctionResultRefactorAtPosition(aContext,
    aFileName, aLine, aColumn);
end;

class function TDelphiSemanticApi.ReportDeadCode(
  const aContext: TDelphiSemanticSymbolQueryContext; const aProfile: string):
  TDelphiSemanticDeadCodeReport;
begin
  Result := TDelphiSemanticDeadCodeReporter.Report(aContext, aProfile);
end;

class function TDelphiSemanticApi.PlanDeadCodeRemoval(
  const aContext: TDelphiSemanticSymbolQueryContext; const aProfile: string):
  TDelphiSemanticDeadCodeRemovalPlan;
begin
  Result := TDelphiSemanticRenamePlanner.PlanDeadCodeRemoval(aContext, aProfile);
end;

class function TDelphiSemanticApi.Search(const aContext: TDelphiSemanticSymbolQueryContext;
  const aQuery: TDelphiSemanticSearchQuery): TDelphiSemanticSearchResult;
begin
  Result := TDelphiSemanticSearch.Search(aContext, aQuery);
end;

end.
