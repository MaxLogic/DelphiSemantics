unit DelphiSemantics.ProjectSession;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.GlobalVars, DelphiSemantics.Model,
  DelphiSemantics.ProjectContext, DelphiSemantics.Query, DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.Graph, DelphiSemantics.SemanticGraph, DelphiSemantics.Snapshot,
  DelphiSemantics.WithBinding;

type
  TDelphiSemanticProjectSession = class;

  TDelphiSemanticProjectSessionStatus = (psUnavailable, psOpen, psInvalidProject);

  TDelphiSemanticProjectSessionResult = record
    Success: Boolean;
    Status: TDelphiSemanticProjectSessionStatus;
    Provenance: string;
    Session: TDelphiSemanticProjectSession;
    Diagnostics: TArray<TDelphiSemanticDiagnostic>;
  end;

  TDelphiSemanticSessionChange = record
    FileName: string;
    ChangeKind: string;
  end;

  TDelphiSemanticSessionInvalidationPlan = record
    RequiresFullSessionRebuild: Boolean;
    ContextInvalidated: Boolean;
    IncludeGraphInvalidated: Boolean;
    LookupMemoizationInvalidated: Boolean;
    AffectedUnitFiles: TArray<string>;
    AffectedUnitNames: TArray<string>;
    Reasons: TArray<string>;
  end;

  TDelphiSemanticProjectSnapshotBuildMetrics = record
    UnitCount: Integer;
    SymbolCount: Integer;
    ReferenceCount: Integer;
    WithStatementCount: Integer;
    BuildMilliseconds: Int64;
    SnapshotCacheProbes: Integer;
    SnapshotCacheHits: Integer;
    SnapshotCacheMisses: Integer;
    SnapshotCacheInvalidations: Integer;
    SnapshotCacheFullHitCount: Integer;
    SnapshotCachePartialHitCount: Integer;
    SnapshotCacheMissRebuildCount: Integer;
    SnapshotCacheUnitHits: Integer;
    SnapshotCacheUnitMisses: Integer;
    SnapshotCacheUnitStaleEntries: Integer;
    SnapshotCacheUnitBuildMilliseconds: Int64;
    SnapshotCacheUnitMergeMilliseconds: Int64;
    SnapshotSqlWriteMilliseconds: Int64;
    SnapshotSqlReadMilliseconds: Int64;
    SnapshotDeserializeMilliseconds: Int64;
    SnapshotIndexRebuildMilliseconds: Int64;
    SnapshotParseAvoidedEstimateMilliseconds: Int64;
    SnapshotCacheUseful: Boolean;
    SnapshotBuilderWorkerCount: Integer;
    SnapshotBuilderQueueMilliseconds: Int64;
    SnapshotBuilderParseExtractMilliseconds: Int64;
    SnapshotBuilderMergeMilliseconds: Int64;
    SnapshotBuilderDeterministicFactCount: Integer;
  end;

  TDelphiSemanticProjectSession = class
  private
    fDiagnostics: TArray<TDelphiSemanticDiagnostic>;
    fLastSnapshotBuildMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
    fLastSemanticGraphBuildMetrics: TDelphiSemanticGraphBuildMetrics;
    fOptions: TDelphiSemanticOptions;
    fProject: TDelphiSemanticProjectInfo;
    fProvenance: string;
    fStatus: TDelphiSemanticProjectSessionStatus;
  public
    constructor Create(const aOptions: TDelphiSemanticOptions;
      const aProject: TDelphiSemanticProjectInfo;
      const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
      const aStatus: TDelphiSemanticProjectSessionStatus; const aProvenance: string);
    function BuildGlobalAnalysis(out aCacheIdentities:
      TArray<TDelphiSemanticUnitCacheIdentity>; out aCacheMetrics:
      TDelphiSemanticCacheMetrics; out aExtractionMilliseconds: Int64):
      TDelphiSemanticGlobalAnalysis;
    function BuildGlobalCacheIdentities:
      TArray<TDelphiSemanticUnitCacheIdentity>;
    function BuildDependencyGraph: TDelphiSemanticDependencyGraph;
    function BuildSemanticGraph: TDelphiSemanticSemanticGraph;
    function BuildSymbolQueryContext(out aCacheMetrics: TDelphiSemanticCacheMetrics;
      out aExtractionMilliseconds: Int64): TDelphiSemanticSymbolQueryContext;
    function BuildSnapshot: TDelphiProjectSnapshot; overload;
    function BuildSnapshot(const aScopedSourceFileNames: TArray<string>):
      TDelphiProjectSnapshot; overload;
    function BuildWithBindingFacts: TDelphiSemanticProjectWithBindingFacts; overload;
    function BuildWithBindingFacts(const aScopedSourceFileNames: TArray<string>):
      TDelphiSemanticProjectWithBindingFacts; overload;
    function PlanRemoveWith: TDelphiSemanticRemoveWithPlan; overload;
    function PlanRemoveWith(const aScopedSourceFileNames: TArray<string>):
      TDelphiSemanticRemoveWithPlan; overload;
    function PlanInvalidation(const aChanges: TArray<TDelphiSemanticSessionChange>):
      TDelphiSemanticSessionInvalidationPlan;
    class function Open(const aOptions: TDelphiSemanticOptions):
      TDelphiSemanticProjectSessionResult; static;
    property Diagnostics: TArray<TDelphiSemanticDiagnostic> read fDiagnostics;
    property LastSnapshotBuildMetrics: TDelphiSemanticProjectSnapshotBuildMetrics
      read fLastSnapshotBuildMetrics;
    property LastSemanticGraphBuildMetrics: TDelphiSemanticGraphBuildMetrics
      read fLastSemanticGraphBuildMetrics;
    property Options: TDelphiSemanticOptions read fOptions;
    property Project: TDelphiSemanticProjectInfo read fProject;
    property Provenance: string read fProvenance;
    property Status: TDelphiSemanticProjectSessionStatus read fStatus;
  end;

implementation

uses
  System.Diagnostics, System.Generics.Collections, System.Hash, System.IOUtils,
  System.RegularExpressions, System.SysUtils,
  DelphiAST.ProjectIndexer,
  DelphiSemantics.Cache.Sqlite, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.Cache.Sqlite, DelphiSemantics.Snapshot.RemoveWith,
  DelphiSemantics.Source,
  MaxLogic.StrUtils;

const
  cProjectSnapshotCacheIdentitySchemaVersion = 'project-session-snapshot-v2';
  cProjectRemoveWithFactsCacheIdentitySchemaVersion =
    'project-session-remove-with-facts-v1';

function MainModelOptions(const aProject: TDelphiSemanticProjectInfo):
  TDelphiSemanticModelOptions;
begin
  Result := Default(TDelphiSemanticModelOptions);
  Result.SourceFileName := aProject.MainSourceFileName;
  Result.Defines := aProject.Defines;
  Result.SearchPaths := aProject.SourceLookupPaths;
  Result.ProjectContextApplied := True;
end;

procedure ApplyProjectMainUnitName(const aProject: TDelphiSemanticProjectInfo;
  var aModel: TDelphiSemanticUnitModel);
begin
  if aModel.Success and (aModel.UnitName = '') and
    SameText(aModel.FileName, aProject.MainSourceFileName) then
    aModel.UnitName := aProject.ProjectName;
end;

function VisibleMetricMilliseconds(const aMilliseconds: Int64): Int64;
begin
  Result := aMilliseconds;
  if Result <= 0 then
    Result := 1;
end;

function ExtractUnitModel(const aProject: TDelphiSemanticProjectInfo; const aFileName: string):
  TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := MainModelOptions(aProject);
  lOptions.SourceFileName := aFileName;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  ApplyProjectMainUnitName(aProject, Result);
end;

function CacheOptionsFromSessionOptions(const aOptions: TDelphiSemanticOptions):
  TDelphiSemanticCacheOptions;
begin
  Result := Default(TDelphiSemanticCacheOptions);
  Result.SqliteCacheFileName := aOptions.SqliteCacheFileName;
  Result.CompilerProfileName := Format('ProjectSession-%s-%s-%s',
    [aOptions.DelphiVersion, aOptions.Platform, aOptions.Configuration]);
  Result.DelphiVersion := aOptions.DelphiVersion;
  Result.Configuration := aOptions.Configuration;
  Result.Platform := aOptions.Platform;
end;

function ExtractProjectUnitModel(const aProject: TDelphiSemanticProjectInfo;
  const aFileName: string; const aCache: TDelphiSemanticUnitCache;
  const aSkipBodyAnalysis: Boolean;
  out aIdentity: TDelphiSemanticUnitCacheIdentity):
  TDelphiSemanticUnitModel; overload;
var
  lAccessResult: TDelphiSemanticUnitCacheAccessResult;
  lOptions: TDelphiSemanticModelOptions;
begin
  aIdentity := Default(TDelphiSemanticUnitCacheIdentity);
  lOptions := MainModelOptions(aProject);
  lOptions.SourceFileName := aFileName;
  lOptions.SkipBodyAnalysis := aSkipBodyAnalysis;
  lOptions.SkipReferenceExtraction := aSkipBodyAnalysis;
  if aCache = nil then
  begin
    Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    ApplyProjectMainUnitName(aProject, Result);
    Exit;
  end;

  lAccessResult := aCache.GetOrBuildUnitModelWithStatus(lOptions,
    function(const aBuildOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel
    begin
      Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(aBuildOptions);
      ApplyProjectMainUnitName(aProject, Result);
    end);
  aIdentity := lAccessResult.Identity;
  Result := lAccessResult.Model;
  ApplyProjectMainUnitName(aProject, Result);
end;

function ProjectModelFileNames(const aProject: TDelphiSemanticProjectInfo):
  TArray<string>;
var
  lFileName: string;
  lFiles: TList<string>;
  lMatch: TMatch;
  lReferenceFileName: string;
  lSeen: TDictionary<string, Byte>;
  lSourceLoad: TDelphiSemanticSourceLoadResult;
  lSourceText: string;
  lSourceFileName: string;
begin
  lFiles := TList<string>.Create;
  lSeen := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    if aProject.MainSourceFileName <> '' then
    begin
      lSourceFileName := TPath.GetFullPath(aProject.MainSourceFileName);
      lSeen.AddOrSetValue(lSourceFileName, 0);
      lFiles.Add(lSourceFileName);
    end;

    if (aProject.MainSourceFileName <> '') and TFile.Exists(aProject.MainSourceFileName) then
    begin
      lSourceLoad := TDelphiSemanticSourceLoader.LoadFile(aProject.MainSourceFileName);
      if not lSourceLoad.Success then
        lSourceText := ''
      else
        lSourceText := lSourceLoad.Source.Text;
      for lMatch in TRegEx.Matches(lSourceText, '\bin\s+''([^'']+)''',
        [roIgnoreCase]) do
      begin
        lReferenceFileName := TPath.GetFullPath(TPath.Combine(
          TPath.GetDirectoryName(aProject.MainSourceFileName),
          lMatch.Groups[1].Value));
        if (not TFile.Exists(lReferenceFileName)) or
          lSeen.ContainsKey(lReferenceFileName) then
          Continue;
        lSeen.Add(lReferenceFileName, 0);
        lFiles.Add(lReferenceFileName);
      end;
    end;

    for lFileName in aProject.SourceFileNames do
    begin
      lSourceFileName := TPath.GetFullPath(lFileName);
      if lSeen.ContainsKey(lSourceFileName) then
        Continue;
      lSeen.Add(lSourceFileName, 0);
      lFiles.Add(lSourceFileName);
    end;
    Result := lFiles.ToArray;
  finally
    lSeen.Free;
    lFiles.Free;
  end;
end;

function DependencyGraphSearchPaths(const aProject: TDelphiSemanticProjectInfo): TArray<string>; forward;

procedure CollectDependencyGraphFacts(const aProject: TDelphiSemanticProjectInfo;
  out aSourceFileNames: TArray<string>; out aGraphOptions: TDelphiSemanticDependencyGraphOptions);
var
  lFile: string;
  lFiles: TList<string>;
  lIndexer: TProjectIndexer;
  lNode: TProjectIndexer.TUnitInfo;
  lProblem: TProjectIndexer.TProblemInfo;
  lSeen: TDictionary<string, Byte>;
begin
  aSourceFileNames := [];
  aGraphOptions := Default(TDelphiSemanticDependencyGraphOptions);
  aGraphOptions.SearchPaths := DependencyGraphSearchPaths(aProject);
  aGraphOptions.ProjectUnitName := aProject.ProjectName;

  lFiles := TList<string>.Create;
  lSeen := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  lIndexer := TProjectIndexer.Create;
  try
    lIndexer.Options := lIndexer.Options - [piUseDefinesDefinedByCompiler];
    lIndexer.Defines := String.Join(';', aProject.Defines);
    lIndexer.SearchPath := String.Join(';', aProject.SourceLookupPaths);
    lIndexer.Index(aProject.MainSourceFileName);

    if aProject.MainSourceFileName <> '' then
    begin
      lFile := TPath.GetFullPath(aProject.MainSourceFileName);
      if (lFile <> '') and (not lSeen.ContainsKey(lFile)) then
      begin
        lSeen.Add(lFile, 0);
        lFiles.Add(lFile);
      end;
    end;

    for lNode in lIndexer.ParsedUnits do
    begin
      lFile := TPath.GetFullPath(lNode.Path);
      if (lFile = '') or lSeen.ContainsKey(lFile) or (not TFile.Exists(lFile)) then
        Continue;
      lSeen.Add(lFile, 0);
      lFiles.Add(lFile);
    end;

    SetLength(aGraphOptions.ParserProblems, lIndexer.Problems.Count);
    for var i := 0 to Pred(lIndexer.Problems.Count) do
    begin
      lProblem := lIndexer.Problems[i];
      aGraphOptions.ParserProblems[i].UnitName := TPath.GetFileNameWithoutExtension(lProblem.FileName);
      aGraphOptions.ParserProblems[i].FileName := lProblem.FileName;
      aGraphOptions.ParserProblems[i].Description := lProblem.Description;
    end;

    SetLength(aGraphOptions.UnresolvedUnits, lIndexer.NotFoundUnits.Count);
    for var i := 0 to Pred(lIndexer.NotFoundUnits.Count) do
      aGraphOptions.UnresolvedUnits[i] := lIndexer.NotFoundUnits[i];

    aSourceFileNames := lFiles.ToArray;
  finally
    lIndexer.Free;
    lSeen.Free;
    lFiles.Free;
  end;
end;

function SnapshotCacheContextHash(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions): string;
var
  lContext: TDelphiSemanticCacheIdentityContext;
  lProjectIdentity: TDelphiSemanticProjectCacheIdentity;
begin
  lContext := Default(TDelphiSemanticCacheIdentityContext);
  lContext.SchemaVersion := cProjectSnapshotCacheIdentitySchemaVersion;
  lContext.ProjectPath := aOptions.ProjectPath;
  lContext.DelphiVersion := aOptions.DelphiVersion;
  lContext.Configuration := aOptions.Configuration;
  lContext.Platform := aOptions.Platform;
  lContext.Defines := aProject.Defines;
  lContext.SearchPaths := aProject.SourceLookupPaths;
  lContext.UnitScopes := aProject.UnitScopeNames;
  lContext.UnitAliases := aProject.UnitAliases;
  lProjectIdentity := TDelphiSemanticCacheIdentityBuilder.BuildProjectIdentity(lContext);
  Result := THashSHA2.GetHashString(
    'canonicalProjectContext=' + aProject.ContextFingerprint + sLineBreak +
    'projectIdentity=' + lProjectIdentity.ProjectKey + sLineBreak +
    'skipWithGraph=' + BoolToStr(aOptions.SkipWithBindingSemanticGraph, True));
end;

function SnapshotCacheIdentityForUnit(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aSourceFileName: string;
  const aUnitCacheIdentity: TDelphiSemanticUnitCacheIdentity;
  const aParseAvoidedEstimateMilliseconds: Int64): TDelphiSemanticSnapshotCacheIdentity;
var
  lProjectContextHash: string;
  lSourceFileName: string;
begin
  if Trim(aUnitCacheIdentity.SourceFileName) <> '' then
    lSourceFileName := aUnitCacheIdentity.SourceFileName
  else
    lSourceFileName := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aSourceFileName);
  Result := Default(TDelphiSemanticSnapshotCacheIdentity);
  Result.IdentityKey := lSourceFileName;
  Result.SourceFileName := lSourceFileName;
  if Trim(aUnitCacheIdentity.FileHash) <> '' then
    Result.FileHash := aUnitCacheIdentity.FileHash
  else
    Result.FileHash := 'missing';
  lProjectContextHash := SnapshotCacheContextHash(aProject, aOptions);
  Result.ContextHash := THashSHA2.GetHashString(lProjectContextHash + sLineBreak +
    'unitCache=' + aUnitCacheIdentity.UnitCacheKey);
  Result.IncludeGraphHash := aUnitCacheIdentity.IncludeGraphHash;
  if Result.IncludeGraphHash = '' then
    Result.IncludeGraphHash := 'no-includes-v1';
  Result.SchemaVersion := cProjectSnapshotCacheIdentitySchemaVersion;
  Result.ParseAvoidedEstimateMilliseconds := aParseAvoidedEstimateMilliseconds;
  Result.CacheKey := THashSHA2.GetHashString('snapshot|' + Result.SchemaVersion + '|' +
    Result.SourceFileName + '|' + Result.FileHash + '|' + Result.ContextHash + '|' +
    Result.IncludeGraphHash);
end;

function ProjectRemoveWithFactsCacheIdentity(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aSourceFileNames,
  aScopedSourceFileNames: TArray<string>;
  const aUnitCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>):
  TDelphiSemanticSnapshotCacheIdentity;
var
  i: Integer;
  lFileName: string;
  lFullSourceFileName: string;
  lIdentityText: string;
  lIncludeGraphText: string;
  lProjectFileName: string;
  lScopedFileName: string;
  lScopedFiles: TList<string>;
begin
  lProjectFileName := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aOptions.ProjectPath);
  lIdentityText := 'projectContext=' + SnapshotCacheContextHash(aProject, aOptions) +
    sLineBreak + 'project=' + lProjectFileName;
  lIncludeGraphText := '';

  for i := 0 to High(aSourceFileNames) do
  begin
    lFullSourceFileName := TDelphiSemanticCacheIdentityBuilder.CanonicalPath(aSourceFileNames[i]);
    lIdentityText := lIdentityText + sLineBreak + 'source[' + IntToStr(i) + ']=' +
      lFullSourceFileName;
    if i <= High(aUnitCacheIdentities) then
    begin
      lIdentityText := lIdentityText + sLineBreak + 'unitCache[' + IntToStr(i) + ']=' +
        aUnitCacheIdentities[i].UnitCacheKey;
      lIncludeGraphText := lIncludeGraphText + sLineBreak + 'includeGraph[' +
        IntToStr(i) + ']=' + aUnitCacheIdentities[i].IncludeGraphHash;
    end;
  end;

  lScopedFiles := TList<string>.Create;
  try
    for lFileName in aScopedSourceFileNames do
      if Trim(lFileName) <> '' then
        lScopedFiles.Add(TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lFileName));
    lScopedFiles.Sort;
    for lScopedFileName in lScopedFiles do
      lIdentityText := lIdentityText + sLineBreak + 'scoped=' + lScopedFileName;
  finally
    lScopedFiles.Free;
  end;

  Result := Default(TDelphiSemanticSnapshotCacheIdentity);
  Result.IdentityKey := lProjectFileName + '|remove-with-facts';
  Result.SourceFileName := lProjectFileName;
  if TFile.Exists(lProjectFileName) then
    Result.FileHash := THashSHA2.GetHashStringFromFile(lProjectFileName)
  else
    Result.FileHash := 'missing';
  Result.ContextHash := THashSHA2.GetHashString(lIdentityText);
  if Trim(lIncludeGraphText) = '' then
    Result.IncludeGraphHash := 'no-includes-v1'
  else
    Result.IncludeGraphHash := THashSHA2.GetHashString(lIncludeGraphText);
  Result.SchemaVersion := cProjectRemoveWithFactsCacheIdentitySchemaVersion;
  Result.ParseAvoidedEstimateMilliseconds := 0;
  Result.CacheKey := THashSHA2.GetHashString('project-remove-with-facts|' +
    Result.SchemaVersion + '|' + Result.SourceFileName + '|' + Result.FileHash + '|' +
    Result.ContextHash + '|' + Result.IncludeGraphHash);
end;

procedure AccumulateSnapshotCacheMetrics(var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  const aCacheMetrics: TDelphiSemanticSnapshotCacheMetrics);
begin
  Inc(aMetrics.SnapshotCacheProbes, aCacheMetrics.SnapshotCacheProbes);
  Inc(aMetrics.SnapshotCacheHits, aCacheMetrics.CacheHits);
  Inc(aMetrics.SnapshotCacheMisses, aCacheMetrics.CacheMisses);
  Inc(aMetrics.SnapshotCacheInvalidations, aCacheMetrics.Invalidations);
  Inc(aMetrics.SnapshotCacheUnitHits, aCacheMetrics.CacheHits);
  Inc(aMetrics.SnapshotCacheUnitMisses, aCacheMetrics.CacheMisses);
  Inc(aMetrics.SnapshotCacheUnitStaleEntries, aCacheMetrics.Invalidations);
  Inc(aMetrics.SnapshotSqlWriteMilliseconds, aCacheMetrics.SnapshotSqlWriteMilliseconds);
  Inc(aMetrics.SnapshotSqlReadMilliseconds, aCacheMetrics.SnapshotSqlReadMilliseconds);
  Inc(aMetrics.SnapshotDeserializeMilliseconds,
    aCacheMetrics.SnapshotDeserializeMilliseconds);
  Inc(aMetrics.SnapshotIndexRebuildMilliseconds,
    aCacheMetrics.SnapshotIndexRebuildMilliseconds);
  Inc(aMetrics.SnapshotParseAvoidedEstimateMilliseconds,
    aCacheMetrics.SnapshotParseAvoidedEstimateMilliseconds);
  aMetrics.SnapshotCacheUseful := aMetrics.SnapshotCacheUseful or
    aCacheMetrics.SnapshotCacheUseful;
end;

procedure AddSnapshotCacheMetricTotals(var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  const aCacheMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
begin
  Inc(aMetrics.SnapshotCacheProbes, aCacheMetrics.SnapshotCacheProbes);
  Inc(aMetrics.SnapshotCacheHits, aCacheMetrics.SnapshotCacheHits);
  Inc(aMetrics.SnapshotCacheMisses, aCacheMetrics.SnapshotCacheMisses);
  Inc(aMetrics.SnapshotCacheInvalidations, aCacheMetrics.SnapshotCacheInvalidations);
  Inc(aMetrics.SnapshotCacheUnitHits, aCacheMetrics.SnapshotCacheUnitHits);
  Inc(aMetrics.SnapshotCacheUnitMisses, aCacheMetrics.SnapshotCacheUnitMisses);
  Inc(aMetrics.SnapshotCacheUnitStaleEntries, aCacheMetrics.SnapshotCacheUnitStaleEntries);
  Inc(aMetrics.SnapshotCacheUnitBuildMilliseconds,
    aCacheMetrics.SnapshotCacheUnitBuildMilliseconds);
  Inc(aMetrics.SnapshotCacheUnitMergeMilliseconds,
    aCacheMetrics.SnapshotCacheUnitMergeMilliseconds);
  Inc(aMetrics.SnapshotSqlWriteMilliseconds, aCacheMetrics.SnapshotSqlWriteMilliseconds);
  Inc(aMetrics.SnapshotSqlReadMilliseconds, aCacheMetrics.SnapshotSqlReadMilliseconds);
  Inc(aMetrics.SnapshotDeserializeMilliseconds,
    aCacheMetrics.SnapshotDeserializeMilliseconds);
  Inc(aMetrics.SnapshotIndexRebuildMilliseconds,
    aCacheMetrics.SnapshotIndexRebuildMilliseconds);
  Inc(aMetrics.SnapshotParseAvoidedEstimateMilliseconds,
    aCacheMetrics.SnapshotParseAvoidedEstimateMilliseconds);
  aMetrics.SnapshotCacheUseful := aMetrics.SnapshotCacheUseful or
    aCacheMetrics.SnapshotCacheUseful;
end;

procedure AccumulateProjectFactsCacheMetrics(
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  const aCacheMetrics: TDelphiSemanticSnapshotCacheMetrics);
begin
  Inc(aMetrics.SnapshotCacheProbes, aCacheMetrics.SnapshotCacheProbes);
  Inc(aMetrics.SnapshotCacheHits, aCacheMetrics.CacheHits);
  Inc(aMetrics.SnapshotCacheMisses, aCacheMetrics.CacheMisses);
  Inc(aMetrics.SnapshotCacheInvalidations, aCacheMetrics.Invalidations);
  Inc(aMetrics.SnapshotSqlWriteMilliseconds, aCacheMetrics.SnapshotSqlWriteMilliseconds);
  Inc(aMetrics.SnapshotSqlReadMilliseconds, aCacheMetrics.SnapshotSqlReadMilliseconds);
  Inc(aMetrics.SnapshotDeserializeMilliseconds,
    aCacheMetrics.SnapshotDeserializeMilliseconds);
  Inc(aMetrics.SnapshotIndexRebuildMilliseconds,
    aCacheMetrics.SnapshotIndexRebuildMilliseconds);
  Inc(aMetrics.SnapshotParseAvoidedEstimateMilliseconds,
    aCacheMetrics.SnapshotParseAvoidedEstimateMilliseconds);
  aMetrics.SnapshotCacheUseful := aMetrics.SnapshotCacheUseful or
    aCacheMetrics.SnapshotCacheUseful;
end;

function SnapshotBuildCacheMetricsAsSemanticCacheMetrics(
  const aOptions: TDelphiSemanticOptions;
  const aSnapshotMetrics: TDelphiSemanticProjectSnapshotBuildMetrics):
  TDelphiSemanticCacheMetrics;
begin
  Result := Default(TDelphiSemanticCacheMetrics);
  Result.CacheFileName := aOptions.SqliteCacheFileName;
  Result.CacheKind := 'snapshot';
  Result.CacheHits := aSnapshotMetrics.SnapshotCacheHits;
  Result.CacheMisses := aSnapshotMetrics.SnapshotCacheMisses;
  Result.Invalidations := aSnapshotMetrics.SnapshotCacheInvalidations;
end;

function ScopedSourceFileSet(const aScopedSourceFileNames: TArray<string>):
  TDictionary<string, Byte>;
var
  lFileName: string;
begin
  if Length(aScopedSourceFileNames) = 0 then
    Exit(nil);

  Result := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lFileName in aScopedSourceFileNames do
    if Trim(lFileName) <> '' then
      Result.AddOrSetValue(TPath.GetFullPath(lFileName), 0);
end;

function IntersectSourceFileNames(const aLeft, aRight: TArray<string>): TArray<string>;
var
  lFileName: string;
  lItems: TList<string>;
  lRightSet: TDictionary<string, Byte>;
begin
  lItems := nil;
  lRightSet := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    for lFileName in aRight do
      if Trim(lFileName) <> '' then
        lRightSet.AddOrSetValue(TPath.GetFullPath(lFileName), 0);

    lItems := TList<string>.Create;
    for lFileName in aLeft do
      if lRightSet.ContainsKey(TPath.GetFullPath(lFileName)) then
        lItems.Add(lFileName);
    Result := lItems.ToArray;
  finally
    lItems.Free;
    lRightSet.Free;
  end;
end;

function BuildProjectUnitCacheIdentities(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aSourceFileNames,
  aScopedSourceFileNames: TArray<string>):
  TArray<TDelphiSemanticUnitCacheIdentity>;
var
  i: Integer;
  lBodyAnalysisSourceFiles: TDictionary<string, Byte>;
  lCache: TDelphiSemanticUnitCache;
  lOptions: TDelphiSemanticModelOptions;
begin
  lBodyAnalysisSourceFiles := nil;
  lCache := nil;
  try
    lBodyAnalysisSourceFiles := ScopedSourceFileSet(aScopedSourceFileNames);
    lCache := TDelphiSemanticUnitCache.Create(CacheOptionsFromSessionOptions(aOptions));
    lOptions := MainModelOptions(aProject);
    SetLength(Result, Length(aSourceFileNames));
    for i := 0 to High(aSourceFileNames) do
    begin
      lOptions.SourceFileName := aSourceFileNames[i];
      lOptions.SkipBodyAnalysis := Assigned(lBodyAnalysisSourceFiles) and
        (not lBodyAnalysisSourceFiles.ContainsKey(aSourceFileNames[i]));
      lOptions.SkipReferenceExtraction := lOptions.SkipBodyAnalysis;
      Result[i] := lCache.BuildIdentity(lOptions);
    end;
  finally
    lCache.Free;
    lBodyAnalysisSourceFiles.Free;
  end;
end;

type
  TProjectModelExtractionResult = record
    Models: TArray<TDelphiSemanticUnitModel>;
    CacheMetrics: TDelphiSemanticCacheMetrics;
    CacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
    ExtractionMilliseconds: Int64;
  end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aSourceFileNames,
  aScopedSourceFileNames: TArray<string>; const aUseScopedSourceFileNames: Boolean):
  TProjectModelExtractionResult;
var
  lBodyAnalysisSourceFiles: TDictionary<string, Byte>;
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  i: Integer;
  lIdentity: TDelphiSemanticUnitCacheIdentity;
  lFileName: string;
  lModel: TDelphiSemanticUnitModel;
  lModels: TList<TDelphiSemanticUnitModel>;
  lSkipBodyAnalysis: Boolean;
  lStopwatch: TStopwatch;
begin
  lBodyAnalysisSourceFiles := nil;
  lModels := nil;
  lCache := nil;
  Result := Default(TProjectModelExtractionResult);
  lStopwatch := TStopwatch.StartNew;
  try
    if Trim(aOptions.SqliteCacheFileName) <> '' then
    begin
      lCacheOptions := CacheOptionsFromSessionOptions(aOptions);
      lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    end;

    SetLength(Result.CacheIdentities, Length(aSourceFileNames));
    if aUseScopedSourceFileNames then
    begin
      lBodyAnalysisSourceFiles := TDictionary<string, Byte>.Create(
        TFastCaseAwareComparer.OrdinalIgnoreCase);
      for lFileName in aScopedSourceFileNames do
        if Trim(lFileName) <> '' then
          lBodyAnalysisSourceFiles.AddOrSetValue(TPath.GetFullPath(lFileName), 1);
    end;
    lModels := TList<TDelphiSemanticUnitModel>.Create;
    for i := 0 to High(aSourceFileNames) do
    begin
      lSkipBodyAnalysis := Assigned(lBodyAnalysisSourceFiles) and
        (not lBodyAnalysisSourceFiles.ContainsKey(aSourceFileNames[i]));
      lModel := ExtractProjectUnitModel(aProject, aSourceFileNames[i], lCache,
        lSkipBodyAnalysis, lIdentity);
      Result.CacheIdentities[i] := lIdentity;
      if (i = 0) and (lModel.Success) and (lModel.UnitName = '') and
        SameText(lModel.FileName, aProject.MainSourceFileName) then
        lModel.UnitName := aProject.ProjectName;
      lModels.Add(lModel);
    end;

    Result.Models := lModels.ToArray;
  finally
    lStopwatch.Stop;
    Result.ExtractionMilliseconds := lStopwatch.ElapsedMilliseconds;
    if Assigned(lCache) then
      Result.CacheMetrics := lCache.Metrics;
    lCache.Free;
    lBodyAnalysisSourceFiles.Free;
    lModels.Free;
  end;
end;

function DependencyGraphSearchPaths(const aProject: TDelphiSemanticProjectInfo): TArray<string>;
var
  lItems: TList<string>;
  lPath: string;
begin
  lItems := TList<string>.Create;
  try
    for lPath in aProject.SourceLookupPaths do
      if (Trim(lPath) <> '') and (not lItems.Contains(lPath)) then
        lItems.Add(lPath);
    if (Trim(aProject.ProjectDirectory) <> '') and
      (not lItems.Contains(aProject.ProjectDirectory)) then
      lItems.Add(aProject.ProjectDirectory);
    Result := lItems.ToArray;
  finally
    lItems.Free;
  end;
end;

procedure ApplySnapshotBuilderMetrics(var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  const aBuilderMetrics: TDelphiSnapshotBuilderMetrics);
begin
  aMetrics.UnitCount := aBuilderMetrics.UnitCount;
  aMetrics.SymbolCount := aBuilderMetrics.SymbolCount;
  aMetrics.ReferenceCount := aBuilderMetrics.ReferenceCount;
  aMetrics.WithStatementCount := aBuilderMetrics.WithStatementCount;
  aMetrics.BuildMilliseconds := aBuilderMetrics.BuildMilliseconds;
  aMetrics.SnapshotBuilderWorkerCount := aBuilderMetrics.WorkerCount;
  aMetrics.SnapshotBuilderQueueMilliseconds := aBuilderMetrics.QueueMilliseconds;
  aMetrics.SnapshotBuilderParseExtractMilliseconds :=
    aBuilderMetrics.ParseExtractMilliseconds;
  aMetrics.SnapshotBuilderMergeMilliseconds := aBuilderMetrics.MergeMilliseconds;
  aMetrics.SnapshotBuilderDeterministicFactCount :=
    aBuilderMetrics.DeterministicFactCount;
end;

function BuildSnapshotFromModels(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aRemoveWithFacts: TDelphiSemanticProjectWithBindingFacts;
  const aResolveReferenceTargets: Boolean; const aWorkerCount: Integer;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TDelphiProjectSnapshot; overload;
var
  lBuilderMetrics: TDelphiSnapshotBuilderMetrics;
  lOptions: TDelphiSnapshotBuildOptions;
begin
  aMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.ResolveReferenceTargets := aResolveReferenceTargets;
  lOptions.WorkerCount := aWorkerCount;
  Result := BuildProjectSnapshotFromModels(aModels, aRemoveWithFacts, lOptions,
    lBuilderMetrics);
  ApplySnapshotBuilderMetrics(aMetrics, lBuilderMetrics);
end;

function BuildSnapshotFromModels(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aWorkerCount: Integer;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TDelphiProjectSnapshot; overload;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
begin
  lFacts := Default(TDelphiSemanticProjectWithBindingFacts);
  Result := BuildSnapshotFromModels(aModels, lFacts, True, aWorkerCount, aMetrics);
end;

function CachedInventorySymbol(const aExactStrings: TSemanticStringPool;
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
  Result.UnitName := aExactStrings.TextOf(aSymbol.UnitNameId);
  Result.FileName := aExactStrings.TextOf(aSymbol.FileNameId);
  Result.SectionKind := aExactStrings.TextOf(aSymbol.SectionKindId);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReason := aExactStrings.TextOf(aSymbol.UnsupportedReasonId);
  Result.IsHelper := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsHelper) <> 0;
  Result.IsOverride := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsOverride) <> 0;
  Result.IsDefault := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsDefault) <> 0;
  Result.IsIndexed := (aSymbol.Flags and cSemanticRemoveWithSymbolFlagIsIndexed) <> 0;
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategory := aExactStrings.TextOf(aSymbol.TypeCategoryId);
end;

function CachedRoutineOwnerSymbols(const aExactStrings: TSemanticStringPool;
  const aFacts: TSemanticRemoveWithPlanningFacts): TArray<TDelphiSemanticInventorySymbol>;
var
  i: Integer;
begin
  SetLength(Result, Length(aFacts.RoutineOwners));
  for i := 0 to High(aFacts.RoutineOwners) do
    Result[i] := CachedInventorySymbol(aExactStrings, aFacts.RoutineOwners[i]);
end;

function BuildCachedRemoveWithSnapshotWithLookup(const aCachedSnapshot:
  TDelphiProjectSnapshot; const aModels: TArray<TDelphiSemanticUnitModel>):
  TDelphiProjectSnapshot;
var
  i: Cardinal;
  lBuilder: TDelphiProjectSnapshotBuilder;
  lFacts: TSemanticRemoveWithPlanningFacts;
  lLookupSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  Result := nil;
  if (aCachedSnapshot = nil) or not aCachedSnapshot.HasRemoveWithPlanningFacts then
    Exit;

  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  try
    for i := 1 to aCachedSnapshot.ExactStringCount do
      lBuilder.ExactStrings.Intern(aCachedSnapshot.ExactTextOf(TSemanticStringId(i)));
    lFacts := aCachedSnapshot.RemoveWithPlanningFacts;
    if not lFacts.LookupIndex.IsAvailable then
    begin
      lLookupSymbols := CachedRoutineOwnerSymbols(lBuilder.ExactStrings, lFacts);
      lFacts.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(aModels,
        lLookupSymbols);
    end;
    lBuilder.SetRemoveWithPlanningFactsOwned(lFacts);
    Result := lBuilder.Build;
  finally
    lBuilder.Free;
  end;
end;

function CachedRemoveWithPlanNeedsModelRebuild(
  const aPlan: TDelphiSemanticRemoveWithPlan): Boolean;
var
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
begin
  Result := False;
  for lStatement in aPlan.FinalStatements do
    if SameText(lStatement.Status, 'skipped') and
      SameText(lStatement.Reason, 'type-source-not-indexed') then
      Exit(True);
end;

function TryLoadSingleUnitSnapshotFromCache(const aCacheFileName: string;
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  out aSnapshot: TDelphiProjectSnapshot;
  out aCacheMetrics: TDelphiSemanticSnapshotCacheMetrics): Boolean;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
begin
  Result := False;
  aSnapshot := nil;
  aCacheMetrics := Default(TDelphiSemanticSnapshotCacheMetrics);
  if Trim(aCacheFileName) = '' then
    Exit;

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
  try
    Result := lCache.TryLoadUnit(aIdentity, aSnapshot);
    aCacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function TryLoadProjectRemoveWithFactsFromCache(const aCacheFileName: string;
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  out aSnapshot: TDelphiProjectSnapshot;
  out aCacheMetrics: TDelphiSemanticSnapshotCacheMetrics): Boolean;
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
begin
  Result := False;
  aSnapshot := nil;
  aCacheMetrics := Default(TDelphiSemanticSnapshotCacheMetrics);
  if Trim(aCacheFileName) = '' then
    Exit;

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
  try
    Result := lCache.TryLoadProjectRemoveWithPlanningFacts(aIdentity, aSnapshot);
    aCacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

function BuildSingleUnitSnapshotFromModels(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aModelIndex: Integer; const aUnitId: TSemanticUnitId;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TDelphiProjectSnapshot;
var
  lBuilderMetrics: TDelphiSnapshotBuilderMetrics;
begin
  Result := BuildProjectUnitSnapshotFromModels(aModels, aModelIndex, aUnitId,
    lBuilderMetrics);
  Inc(aMetrics.SnapshotCacheUnitBuildMilliseconds, lBuilderMetrics.BuildMilliseconds);
end;

procedure FreeSnapshots(var aSnapshots: TArray<TDelphiProjectSnapshot>);
var
  i: Integer;
begin
  for i := 0 to High(aSnapshots) do
  begin
    aSnapshots[i].Free;
    aSnapshots[i] := nil;
  end;
end;

procedure StoreProjectRemoveWithFactsCacheEntry(const aCacheFileName: string;
  const aIdentity: TDelphiSemanticSnapshotCacheIdentity;
  const aSnapshot: TDelphiProjectSnapshot;
  const aLookupSymbols: TArray<TDelphiSemanticInventorySymbol>;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lCache: TDelphiSemanticSnapshotSqliteCache;
begin
  if (Trim(aCacheFileName) = '') or (aSnapshot = nil) or
    not aSnapshot.HasRemoveWithPlanningFacts then
    Exit;

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
  try
    lCache.StoreProjectRemoveWithPlanningFacts(aIdentity, aSnapshot, aLookupSymbols);
    Inc(aMetrics.SnapshotSqlWriteMilliseconds,
      lCache.Metrics.SnapshotSqlWriteMilliseconds);
  finally
    lCache.Free;
  end;
end;

procedure StoreSnapshotCacheEntries(const aCacheFileName: string;
  const aProject: TDelphiSemanticProjectInfo; const aOptions: TDelphiSemanticOptions;
  const aSourceFileNames: TArray<string>;
  const aUnitCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  const aStoreUnitFlags: TArray<Boolean>;
  const aSnapshot: TDelphiProjectSnapshot;
  const aParseAvoidedEstimateMilliseconds: Int64;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  i: Integer;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lUnitCacheIdentity: TDelphiSemanticUnitCacheIdentity;
begin
  if (Trim(aCacheFileName) = '') or (aSnapshot = nil) then
    Exit;

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
  try
    for i := 0 to High(aSourceFileNames) do
    begin
      if (Length(aStoreUnitFlags) > 0) and (not aStoreUnitFlags[i]) then
        Continue;
      if i <= High(aUnitCacheIdentities) then
        lUnitCacheIdentity := aUnitCacheIdentities[i]
      else
        lUnitCacheIdentity := Default(TDelphiSemanticUnitCacheIdentity);
      lIdentity := SnapshotCacheIdentityForUnit(aProject, aOptions, aSourceFileNames[i],
        lUnitCacheIdentity, aParseAvoidedEstimateMilliseconds);
      lCache.StoreUnitFromSnapshot(lIdentity, aSnapshot, i);
    end;
    Inc(aMetrics.SnapshotSqlWriteMilliseconds,
      lCache.Metrics.SnapshotSqlWriteMilliseconds);
  finally
    lCache.Free;
  end;
end;

procedure AddUniqueText(const aValues: TList<string>; const aValue: string);
var
  lValue: string;
begin
  if Trim(aValue) = '' then
    Exit;

  for lValue in aValues do
    if SameText(lValue, aValue) then
      Exit;
  aValues.Add(aValue);
end;

function UnitUsesName(const aModel: TDelphiSemanticUnitModel; const aUnitName: string): Boolean;
var
  lUsedUnit: string;
begin
  for lUsedUnit in aModel.InterfaceUses do
    if SameText(lUsedUnit, aUnitName) then
      Exit(True);

  for lUsedUnit in aModel.ImplementationUses do
    if SameText(lUsedUnit, aUnitName) then
      Exit(True);

  Result := False;
end;

function ListContainsText(const aValues: TList<string>; const aValue: string): Boolean;
var
  lValue: string;
begin
  for lValue in aValues do
    if SameText(lValue, aValue) then
      Exit(True);

  Result := False;
end;

function FindModelByFileName(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aFileName: string; out aModel: TDelphiSemanticUnitModel): Boolean;
var
  lFileName: string;
  lModel: TDelphiSemanticUnitModel;
begin
  lFileName := TPath.GetFullPath(aFileName);
  for lModel in aModels do
    if SameText(TPath.GetFullPath(lModel.FileName), lFileName) then
    begin
      aModel := lModel;
      Exit(True);
    end;

  aModel := Default(TDelphiSemanticUnitModel);
  Result := False;
end;

procedure AddAffectedModel(const aModel: TDelphiSemanticUnitModel; const aFiles,
  aUnits: TList<string>);
begin
  AddUniqueText(aFiles, aModel.FileName);
  AddUniqueText(aUnits, aModel.UnitName);
end;

procedure AddAllModels(const aModels: TArray<TDelphiSemanticUnitModel>; const aFiles,
  aUnits: TList<string>);
var
  lModel: TDelphiSemanticUnitModel;
begin
  for lModel in aModels do
    AddAffectedModel(lModel, aFiles, aUnits);
end;

procedure AddDependentClosure(const aModels: TArray<TDelphiSemanticUnitModel>;
  const aChangedModel: TDelphiSemanticUnitModel; const aFiles, aUnits: TList<string>);
var
  lAdded: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lUnitIndex: Integer;
begin
  AddAffectedModel(aChangedModel, aFiles, aUnits);
  lUnitIndex := 0;
  while lUnitIndex < aUnits.Count do
  begin
    lAdded := False;
    for lModel in aModels do
    begin
      if UnitUsesName(lModel, aUnits[lUnitIndex]) then
      begin
        if not SameText(lModel.UnitName, aUnits[lUnitIndex]) then
        begin
          if not ListContainsText(aUnits, lModel.UnitName) then
            lAdded := True;
          AddAffectedModel(lModel, aFiles, aUnits);
        end;
      end;
    end;
    if not lAdded then
      Inc(lUnitIndex);
  end;
end;

function SessionDiagnostic(const aCode, aMessage, aFileName: string;
  const aSeverity: TDelphiSemanticDiagnosticSeverity): TDelphiSemanticDiagnostic;
begin
  Result := Default(TDelphiSemanticDiagnostic);
  Result.Code := aCode;
  Result.Message := aMessage;
  Result.FileName := aFileName;
  Result.Severity := aSeverity;
end;

function SessionFailure(const aContext: TDelphiSemanticContextResult):
  TDelphiSemanticProjectSessionResult;
begin
  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := False;
  Result.Status := psInvalidProject;
  Result.Provenance := 'project-context';
  Result.Diagnostics := Copy(aContext.Diagnostics);
end;

function MissingProjectPathFailure: TDelphiSemanticProjectSessionResult;
begin
  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := False;
  Result.Status := psInvalidProject;
  Result.Provenance := 'project-context';
  SetLength(Result.Diagnostics, 1);
  Result.Diagnostics[0] := SessionDiagnostic('PROJECT_FILE_NOT_SPECIFIED',
    'Project file was not specified.', '', dsError);
end;

constructor TDelphiSemanticProjectSession.Create(const aOptions: TDelphiSemanticOptions;
  const aProject: TDelphiSemanticProjectInfo;
  const aDiagnostics: TArray<TDelphiSemanticDiagnostic>;
  const aStatus: TDelphiSemanticProjectSessionStatus; const aProvenance: string);
begin
  inherited Create;
  fOptions := aOptions;
  fProject := aProject;
  fDiagnostics := Copy(aDiagnostics);
  fStatus := aStatus;
  fProvenance := aProvenance;
end;

function TDelphiSemanticProjectSession.BuildGlobalAnalysis(out aCacheIdentities:
  TArray<TDelphiSemanticUnitCacheIdentity>; out aCacheMetrics: TDelphiSemanticCacheMetrics;
  out aExtractionMilliseconds: Int64): TDelphiSemanticGlobalAnalysis;
var
  lSnapshot: TDelphiProjectSnapshot;
begin
  aCacheIdentities := BuildGlobalCacheIdentities;
  aCacheMetrics := Default(TDelphiSemanticCacheMetrics);
  aExtractionMilliseconds := 0;
  lSnapshot := BuildSnapshot;
  try
    aExtractionMilliseconds := fLastSnapshotBuildMetrics.SnapshotBuilderParseExtractMilliseconds +
      fLastSnapshotBuildMetrics.SnapshotCacheUnitBuildMilliseconds;
    aCacheMetrics := SnapshotBuildCacheMetricsAsSemanticCacheMetrics(fOptions,
      fLastSnapshotBuildMetrics);
    Result := TDelphiSemanticGlobalAnalyzer.AnalyzeSnapshot(lSnapshot);
  finally
    lSnapshot.Free;
  end;
end;

function TDelphiSemanticProjectSession.BuildGlobalCacheIdentities:
  TArray<TDelphiSemanticUnitCacheIdentity>;
var
  i: Integer;
  lCache: TDelphiSemanticUnitCache;
  lOptions: TDelphiSemanticModelOptions;
  lSourceFileNames: TArray<string>;
begin
  lCache := TDelphiSemanticUnitCache.Create(CacheOptionsFromSessionOptions(fOptions));
  try
    lOptions := MainModelOptions(fProject);
    lSourceFileNames := ProjectModelFileNames(fProject);
    SetLength(Result, Length(lSourceFileNames));
    for i := 0 to High(lSourceFileNames) do
    begin
      lOptions.SourceFileName := lSourceFileNames[i];
      Result[i] := lCache.BuildIdentity(lOptions);
    end;
  finally
    lCache.Free;
  end;
end;

function TDelphiSemanticProjectSession.BuildDependencyGraph:
  TDelphiSemanticDependencyGraph;
var
  lExtraction: TProjectModelExtractionResult;
  lGraphOptions: TDelphiSemanticDependencyGraphOptions;
  lSourceFileNames: TArray<string>;
begin
  CollectDependencyGraphFacts(fProject, lSourceFileNames, lGraphOptions);
  lExtraction := ExtractProjectModels(fProject, fOptions, lSourceFileNames, [], False);
  Result := TDelphiSemanticDependencyGraphBuilder.Build(lExtraction.Models, lGraphOptions);
end;

function TDelphiSemanticProjectSession.BuildSemanticGraph: TDelphiSemanticSemanticGraph;
var
  lExtraction: TProjectModelExtractionResult;
begin
  lExtraction := ExtractProjectModels(fProject, fOptions, ProjectModelFileNames(fProject),
    [], False);
  Result := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lExtraction.Models);
  fLastSemanticGraphBuildMetrics := Result.Metrics;
end;

function TDelphiSemanticProjectSession.BuildSymbolQueryContext(
  out aCacheMetrics: TDelphiSemanticCacheMetrics; out aExtractionMilliseconds: Int64):
  TDelphiSemanticSymbolQueryContext;
var
  i: Integer;
  lExtraction: TProjectModelExtractionResult;
begin
  Result := Default(TDelphiSemanticSymbolQueryContext);
  aCacheMetrics := Default(TDelphiSemanticCacheMetrics);
  aExtractionMilliseconds := 0;
  lExtraction := ExtractProjectModels(fProject, fOptions, ProjectModelFileNames(fProject),
    [], False);
  aCacheMetrics := lExtraction.CacheMetrics;
  aExtractionMilliseconds := lExtraction.ExtractionMilliseconds;
  if Length(lExtraction.Models) = 0 then
    Exit;

  Result.UnitModel := lExtraction.Models[0];
  if Length(lExtraction.Models) > 1 then
  begin
    SetLength(Result.IndexedUnitModels, Length(lExtraction.Models) - 1);
    SetLength(Result.IndexedUnitSourceKinds, Length(lExtraction.Models) - 1);
    for i := 1 to High(lExtraction.Models) do
    begin
      Result.IndexedUnitModels[i - 1] := lExtraction.Models[i];
      Result.IndexedUnitSourceKinds[i - 1] := 'project-source';
    end;
  end;
end;

function TDelphiSemanticProjectSession.BuildSnapshot: TDelphiProjectSnapshot;
begin
  Result := BuildSnapshot([]);
end;

function TDelphiSemanticProjectSession.BuildSnapshot(
  const aScopedSourceFileNames: TArray<string>): TDelphiProjectSnapshot;
var
  lCacheIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lCacheHadPartialHit: Boolean;
  lCacheMetrics: TDelphiSemanticSnapshotCacheMetrics;
  lCacheSnapshot: TDelphiProjectSnapshot;
  lCacheSnapshotMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lExtractionSourceFileNames: TArray<string>;
  lExtractionScopeSourceFileNames: TArray<string>;
  lExtractionUsesScopedSourceFileNames: Boolean;
  lLoadedAllUnits: Boolean;
  lLoadedAnyUnit: Boolean;
  lBuilderMetrics: TDelphiSnapshotBuilderMetrics;
  lExtraction: TProjectModelExtractionResult;
  i: Integer;
  lMissingSourceFileNames: TArray<string>;
  lParseAvoidedEstimateMilliseconds: Int64;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceFileNames: TArray<string>;
  lStoreCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lStoreUnitFlags: TArray<Boolean>;
  lUnitCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lUnitSnapshots: TArray<TDelphiProjectSnapshot>;
begin
  Result := nil;
  fLastSnapshotBuildMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
  lSourceFileNames := ProjectModelFileNames(fProject);
  SetLength(lUnitCacheIdentities, 0);
  SetLength(lMissingSourceFileNames, 0);
  SetLength(lStoreUnitFlags, 0);
  lCacheHadPartialHit := False;
  lCacheSnapshotMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
  SetLength(lUnitSnapshots, 0);
  if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
  begin
    lUnitCacheIdentities := BuildProjectUnitCacheIdentities(fProject, fOptions,
      lSourceFileNames, aScopedSourceFileNames);
    SetLength(lUnitSnapshots, Length(lSourceFileNames));
    lLoadedAllUnits := True;
    lLoadedAnyUnit := False;
    for i := 0 to High(lSourceFileNames) do
    begin
      lCacheIdentity := SnapshotCacheIdentityForUnit(fProject, fOptions, lSourceFileNames[i],
        lUnitCacheIdentities[i], 0);
      lCacheSnapshot := nil;
      if TryLoadSingleUnitSnapshotFromCache(fOptions.SqliteCacheFileName, lCacheIdentity,
        lCacheSnapshot, lCacheMetrics) then
      begin
        lUnitSnapshots[i] := lCacheSnapshot;
        lLoadedAnyUnit := True;
      end else begin
        lCacheSnapshot.Free;
        lLoadedAllUnits := False;
        SetLength(lMissingSourceFileNames, Length(lMissingSourceFileNames) + 1);
        lMissingSourceFileNames[High(lMissingSourceFileNames)] := lSourceFileNames[i];
      end;
      AccumulateSnapshotCacheMetrics(lCacheSnapshotMetrics, lCacheMetrics);
    end;
    lCacheHadPartialHit := lLoadedAnyUnit and (not lLoadedAllUnits);

    if lLoadedAllUnits then
    begin
      try
        lSnapshot := BuildProjectSnapshotFromUnitSnapshots(lUnitSnapshots, lBuilderMetrics);
        try
          fLastSnapshotBuildMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
          ApplySnapshotBuilderMetrics(fLastSnapshotBuildMetrics, lBuilderMetrics);
          AddSnapshotCacheMetricTotals(fLastSnapshotBuildMetrics, lCacheSnapshotMetrics);
          fLastSnapshotBuildMetrics.SnapshotCacheFullHitCount := 1;
          fLastSnapshotBuildMetrics.SnapshotCacheUnitMergeMilliseconds :=
            lBuilderMetrics.MergeMilliseconds;
          Result := lSnapshot;
          lSnapshot := nil;
          Exit;
        finally
          lSnapshot.Free;
        end;
      finally
        FreeSnapshots(lUnitSnapshots);
      end;
    end;
  end;

  lExtractionSourceFileNames := lSourceFileNames;
  lExtractionScopeSourceFileNames := aScopedSourceFileNames;
  lExtractionUsesScopedSourceFileNames := Length(aScopedSourceFileNames) > 0;
  if lCacheHadPartialHit then
  begin
    lExtractionUsesScopedSourceFileNames := True;
    if Length(aScopedSourceFileNames) = 0 then
      lExtractionScopeSourceFileNames := lMissingSourceFileNames
    else
      lExtractionScopeSourceFileNames := IntersectSourceFileNames(
        lMissingSourceFileNames, aScopedSourceFileNames);
  end;
  lExtraction := ExtractProjectModels(fProject, fOptions, lExtractionSourceFileNames,
    lExtractionScopeSourceFileNames, lExtractionUsesScopedSourceFileNames);
  lParseAvoidedEstimateMilliseconds :=
    VisibleMetricMilliseconds(lExtraction.ExtractionMilliseconds);
  if Length(lUnitSnapshots) > 0 then
  begin
    try
      SetLength(lStoreUnitFlags, Length(lSourceFileNames));
      for i := 0 to High(lSourceFileNames) do
        if lUnitSnapshots[i] = nil then
        begin
          lUnitSnapshots[i] := BuildSingleUnitSnapshotFromModels(lExtraction.Models, i,
            TSemanticUnitId(i + 1), lCacheSnapshotMetrics);
          lStoreUnitFlags[i] := True;
        end;
      lSnapshot := BuildProjectSnapshotFromUnitSnapshots(lUnitSnapshots, lBuilderMetrics);
    finally
      FreeSnapshots(lUnitSnapshots);
    end;
    ApplySnapshotBuilderMetrics(fLastSnapshotBuildMetrics, lBuilderMetrics);
  end else
    lSnapshot := BuildSnapshotFromModels(lExtraction.Models, fOptions.SnapshotBuildWorkerCount,
      fLastSnapshotBuildMetrics);
  try
    AddSnapshotCacheMetricTotals(fLastSnapshotBuildMetrics, lCacheSnapshotMetrics);
    if Length(lUnitSnapshots) > 0 then
      if lCacheHadPartialHit then
        fLastSnapshotBuildMetrics.SnapshotCachePartialHitCount := 1
      else
        fLastSnapshotBuildMetrics.SnapshotCacheMissRebuildCount := 1;
    if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
      fLastSnapshotBuildMetrics.SnapshotCacheUnitMergeMilliseconds :=
        lBuilderMetrics.MergeMilliseconds;
    fLastSnapshotBuildMetrics.SnapshotParseAvoidedEstimateMilliseconds :=
      lParseAvoidedEstimateMilliseconds;
    if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
    begin
      lStoreCacheIdentities := lExtraction.CacheIdentities;
      if Length(lUnitCacheIdentities) = Length(lSourceFileNames) then
        lStoreCacheIdentities := lUnitCacheIdentities;
      StoreSnapshotCacheEntries(fOptions.SqliteCacheFileName, fProject, fOptions,
        lSourceFileNames, lStoreCacheIdentities, lStoreUnitFlags, lSnapshot,
        lParseAvoidedEstimateMilliseconds, fLastSnapshotBuildMetrics);
    end;
    Result := lSnapshot;
    lSnapshot := nil;
  finally
    lSnapshot.Free;
  end;
end;

function TDelphiSemanticProjectSession.BuildWithBindingFacts:
  TDelphiSemanticProjectWithBindingFacts;
begin
  Result := BuildWithBindingFacts([]);
end;

function TDelphiSemanticProjectSession.BuildWithBindingFacts(
  const aScopedSourceFileNames: TArray<string>):
  TDelphiSemanticProjectWithBindingFacts;
var
  lExtraction: TProjectModelExtractionResult;
  lGraph: TDelphiSemanticSemanticGraph;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lExtraction := ExtractProjectModels(fProject, fOptions, ProjectModelFileNames(fProject),
    aScopedSourceFileNames, Length(aScopedSourceFileNames) > 0);

  if fOptions.SkipWithBindingSemanticGraph then
    lGraph := nil
  else
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lExtraction.Models);
  try
    if lGraph <> nil then
      fLastSemanticGraphBuildMetrics := lGraph.Metrics
    else
      fLastSemanticGraphBuildMetrics := Default(TDelphiSemanticGraphBuildMetrics);
    Result := TDelphiSemanticWithBinder.BindProject(fProject.ContextFingerprint, lGraph,
      lExtraction.Models);
    Result.Metrics.ModelExtractionMilliseconds := lExtraction.ExtractionMilliseconds;
    Result.Metrics.SemanticCacheHits := lExtraction.CacheMetrics.CacheHits;
    Result.Metrics.SemanticCacheMisses := lExtraction.CacheMetrics.CacheMisses;
    Result.Metrics.SemanticCacheInvalidations := lExtraction.CacheMetrics.Invalidations;
    Result.Metrics.SemanticCachePersistentConnectionOpenCount :=
      lExtraction.CacheMetrics.PersistentConnectionOpenCount;
    if Trim(fOptions.SqliteCacheFileName) <> '' then
    begin
      lSnapshot := BuildSnapshot(aScopedSourceFileNames);
      try
        Result.Metrics.SnapshotSqlWriteMilliseconds :=
          fLastSnapshotBuildMetrics.SnapshotSqlWriteMilliseconds;
        Result.Metrics.SnapshotSqlReadMilliseconds :=
          fLastSnapshotBuildMetrics.SnapshotSqlReadMilliseconds;
        Result.Metrics.SnapshotDeserializeMilliseconds :=
          fLastSnapshotBuildMetrics.SnapshotDeserializeMilliseconds;
        Result.Metrics.SnapshotIndexRebuildMilliseconds :=
          fLastSnapshotBuildMetrics.SnapshotIndexRebuildMilliseconds;
      finally
        lSnapshot.Free;
      end;
    end;
  finally
    lGraph.Free;
  end;
end;

function TDelphiSemanticProjectSession.PlanRemoveWith: TDelphiSemanticRemoveWithPlan;
begin
  Result := PlanRemoveWith([]);
end;

function TDelphiSemanticProjectSession.PlanRemoveWith(
  const aScopedSourceFileNames: TArray<string>): TDelphiSemanticRemoveWithPlan;
var
  lCacheSnapshotMetrics: TDelphiSemanticSnapshotCacheMetrics;
  lCacheSnapshot: TDelphiProjectSnapshot;
  lCachedPlan: TDelphiSemanticRemoveWithPlan;
  lProjectFactsIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lExtraction: TProjectModelExtractionResult;
  lFallbackMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGraph: TDelphiSemanticSemanticGraph;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceFileNames: TArray<string>;
  lUnitCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
begin
  fLastSnapshotBuildMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
  lCacheSnapshotMetrics := Default(TDelphiSemanticSnapshotCacheMetrics);
  lSourceFileNames := ProjectModelFileNames(fProject);
  SetLength(lUnitCacheIdentities, 0);
  if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
  begin
    lUnitCacheIdentities := BuildProjectUnitCacheIdentities(fProject, fOptions,
      lSourceFileNames, aScopedSourceFileNames);
    lProjectFactsIdentity := ProjectRemoveWithFactsCacheIdentity(fProject, fOptions,
      lSourceFileNames, aScopedSourceFileNames, lUnitCacheIdentities);
    lCacheSnapshot := nil;
    if TryLoadProjectRemoveWithFactsFromCache(fOptions.SqliteCacheFileName,
      lProjectFactsIdentity, lCacheSnapshot, lCacheSnapshotMetrics) then
    begin
      try
        AccumulateProjectFactsCacheMetrics(fLastSnapshotBuildMetrics,
          lCacheSnapshotMetrics);
        fLastSemanticGraphBuildMetrics := Default(TDelphiSemanticGraphBuildMetrics);
        lExtraction := ExtractProjectModels(fProject, fOptions, lSourceFileNames,
          aScopedSourceFileNames, Length(aScopedSourceFileNames) > 0);
        lSnapshot := BuildCachedRemoveWithSnapshotWithLookup(lCacheSnapshot,
          lExtraction.Models);
        try
          lCachedPlan := TDelphiSemanticRemoveWithPlanner.Plan(lSnapshot);
          if not CachedRemoveWithPlanNeedsModelRebuild(lCachedPlan) then
            Exit(lCachedPlan);
        finally
          lSnapshot.Free;
        end;
        if fOptions.SkipWithBindingSemanticGraph then
          lGraph := nil
        else
          lGraph := TDelphiSemanticSemanticGraphBuilder.Build(fProject,
            lExtraction.Models);
        try
          if lGraph <> nil then
            fLastSemanticGraphBuildMetrics := lGraph.Metrics
          else
            fLastSemanticGraphBuildMetrics := Default(TDelphiSemanticGraphBuildMetrics);
          lFacts := TDelphiSemanticWithBinder.BindProject(fProject.ContextFingerprint,
            lGraph, lExtraction.Models);
          lSnapshot := BuildSnapshotFromModels(lExtraction.Models, lFacts, False,
            fOptions.SnapshotBuildWorkerCount, lFallbackMetrics);
          try
            Exit(TDelphiSemanticRemoveWithPlanner.Plan(lSnapshot));
          finally
            lSnapshot.Free;
          end;
        finally
          lGraph.Free;
        end;
      finally
        lCacheSnapshot.Free;
      end;
    end;
    AccumulateProjectFactsCacheMetrics(fLastSnapshotBuildMetrics,
      lCacheSnapshotMetrics);
  end;

  lExtraction := ExtractProjectModels(fProject, fOptions, lSourceFileNames,
    aScopedSourceFileNames, Length(aScopedSourceFileNames) > 0);
  if fOptions.SkipWithBindingSemanticGraph then
    lGraph := nil
  else
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lExtraction.Models);
  try
    if lGraph <> nil then
      fLastSemanticGraphBuildMetrics := lGraph.Metrics
    else
      fLastSemanticGraphBuildMetrics := Default(TDelphiSemanticGraphBuildMetrics);

    lFacts := TDelphiSemanticWithBinder.BindProject(fProject.ContextFingerprint, lGraph,
      lExtraction.Models);
    lFacts.Metrics.ModelExtractionMilliseconds := lExtraction.ExtractionMilliseconds;
    lFacts.Metrics.SemanticCacheHits := lExtraction.CacheMetrics.CacheHits;
    lFacts.Metrics.SemanticCacheMisses := lExtraction.CacheMetrics.CacheMisses;
    lFacts.Metrics.SemanticCacheInvalidations := lExtraction.CacheMetrics.Invalidations;
    lFacts.Metrics.SemanticCachePersistentConnectionOpenCount :=
      lExtraction.CacheMetrics.PersistentConnectionOpenCount;

    lSnapshot := BuildSnapshotFromModels(lExtraction.Models, lFacts, False,
      fOptions.SnapshotBuildWorkerCount, fLastSnapshotBuildMetrics);
    try
      if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
      begin
        AccumulateProjectFactsCacheMetrics(fLastSnapshotBuildMetrics,
          lCacheSnapshotMetrics);
        if Length(lUnitCacheIdentities) = 0 then
          lUnitCacheIdentities := lExtraction.CacheIdentities;
        lProjectFactsIdentity := ProjectRemoveWithFactsCacheIdentity(fProject, fOptions,
          lSourceFileNames, aScopedSourceFileNames, lUnitCacheIdentities);
        StoreProjectRemoveWithFactsCacheEntry(fOptions.SqliteCacheFileName,
          lProjectFactsIdentity, lSnapshot, lFacts.Symbols, fLastSnapshotBuildMetrics);
      end;
      Result := TDelphiSemanticRemoveWithPlanner.Plan(lSnapshot);
    finally
      lSnapshot.Free;
    end;
  finally
    lGraph.Free;
  end;
end;

function TDelphiSemanticProjectSession.PlanInvalidation(
  const aChanges: TArray<TDelphiSemanticSessionChange>):
  TDelphiSemanticSessionInvalidationPlan;
var
  lChange: TDelphiSemanticSessionChange;
  lExtraction: TProjectModelExtractionResult;
  lFiles: TList<string>;
  lModel: TDelphiSemanticUnitModel;
  lReasons: TList<string>;
  lUnits: TList<string>;
begin
  Result := Default(TDelphiSemanticSessionInvalidationPlan);
  lFiles := TList<string>.Create;
  lUnits := TList<string>.Create;
  lReasons := TList<string>.Create;
  try
    lExtraction := ExtractProjectModels(fProject, fOptions, ProjectModelFileNames(fProject),
      [], False);
    for lChange in aChanges do
    begin
      if SameText(lChange.ChangeKind, 'context') then
      begin
        Result.ContextInvalidated := True;
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'CONTEXT_CHANGED');
        AddAllModels(lExtraction.Models, lFiles, lUnits);
      end else if SameText(lChange.ChangeKind, 'include') or
        SameText(TPath.GetExtension(lChange.FileName), '.inc') then
      begin
        Result.IncludeGraphInvalidated := True;
        AddUniqueText(lReasons, 'INCLUDE_GRAPH_CHANGED');
        AddAllModels(lExtraction.Models, lFiles, lUnits);
      end else if SameText(lChange.ChangeKind, 'unknown') then
      begin
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'UNKNOWN_CHANGE');
        AddAllModels(lExtraction.Models, lFiles, lUnits);
      end else if FindModelByFileName(lExtraction.Models, lChange.FileName, lModel) then
      begin
        if (not lModel.Success) or (Trim(lModel.UnitName) = '') then
        begin
          Result.RequiresFullSessionRebuild := True;
          AddUniqueText(lReasons, 'CHANGED_UNIT_MODEL_UNAVAILABLE');
          AddAllModels(lExtraction.Models, lFiles, lUnits);
          Continue;
        end;

        if SameText(lChange.ChangeKind, 'implementation') then
        begin
          AddUniqueText(lReasons, 'IMPLEMENTATION_CHANGED');
          AddAffectedModel(lModel, lFiles, lUnits);
        end else
        begin
          if SameText(lChange.ChangeKind, 'type-ancestor') or
            SameText(lChange.ChangeKind, 'helper') then
            Result.LookupMemoizationInvalidated := True;
          AddUniqueText(lReasons, UpperCase(StringReplace(lChange.ChangeKind, '-',
            '_', [rfReplaceAll])) + '_CHANGED');
          AddDependentClosure(lExtraction.Models, lModel, lFiles, lUnits);
        end;
      end else
      begin
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'CHANGE_OUTSIDE_PROJECT_MODEL');
        AddAllModels(lExtraction.Models, lFiles, lUnits);
      end;
    end;

    Result.AffectedUnitFiles := lFiles.ToArray;
    Result.AffectedUnitNames := lUnits.ToArray;
    Result.Reasons := lReasons.ToArray;
  finally
    lReasons.Free;
    lUnits.Free;
    lFiles.Free;
  end;
end;

class function TDelphiSemanticProjectSession.Open(const aOptions: TDelphiSemanticOptions):
  TDelphiSemanticProjectSessionResult;
var
  lContext: TDelphiSemanticContextResult;
begin
  if Trim(aOptions.ProjectPath) = '' then
    Exit(MissingProjectPathFailure);

  lContext := TDelphiSemanticProject.Load(aOptions.ProjectPath, aOptions);
  if not lContext.Success then
    Exit(SessionFailure(lContext));

  Result := Default(TDelphiSemanticProjectSessionResult);
  Result.Success := True;
  Result.Status := psOpen;
  Result.Provenance := 'project-context';
  Result.Diagnostics := Copy(lContext.Diagnostics);
  Result.Session := TDelphiSemanticProjectSession.Create(aOptions, lContext.Project,
    lContext.Diagnostics, Result.Status, Result.Provenance);
end;

end.
