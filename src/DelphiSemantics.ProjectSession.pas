unit DelphiSemantics.ProjectSession;

interface

uses
  DelphiSemantics.Cache, DelphiSemantics.Model, DelphiSemantics.ProjectContext,
  DelphiSemantics.Query, DelphiSemantics.RemoveWithPlan, DelphiSemantics.SemanticGraph,
  DelphiSemantics.Snapshot, DelphiSemantics.WithBinding;

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
    SnapshotCacheUnitHits: Integer;
    SnapshotCacheUnitMisses: Integer;
    SnapshotCacheUnitStaleEntries: Integer;
    SnapshotCacheUnitBuildMilliseconds: Int64;
    SnapshotCacheUnitMergeMilliseconds: Int64;
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
    function BuildSemanticGraph: TDelphiSemanticSemanticGraph;
    function BuildSymbolQueryContext(out aCacheMetrics: TDelphiSemanticCacheMetrics;
      out aExtractionMilliseconds: Int64): TDelphiSemanticSymbolQueryContext;
    function BuildSnapshot: TDelphiProjectSnapshot;
    function BuildWithBindingFacts: TDelphiSemanticProjectWithBindingFacts;
    function PlanRemoveWith: TDelphiSemanticRemoveWithPlan;
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
  System.SysUtils,
  DelphiSemantics.Cache.Sqlite, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.Cache.Sqlite, DelphiSemantics.Snapshot.RemoveWith,
  MaxLogic.StrUtils;

const
  cProjectSnapshotCacheIdentitySchemaVersion = 'project-session-snapshot-v2';
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
  lSeen: TDictionary<string, Byte>;
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

function SnapshotCacheContextHash(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions): string;
begin
  Result := THashSHA2.GetHashString(
    'projectContext=' + aProject.ContextFingerprint + sLineBreak +
    'project=' + TPath.GetFullPath(aOptions.ProjectPath) + sLineBreak +
    'delphi=' + aOptions.DelphiVersion + sLineBreak +
    'configuration=' + aOptions.Configuration + sLineBreak +
    'platform=' + aOptions.Platform + sLineBreak +
    'skipWithGraph=' + BoolToStr(aOptions.SkipWithBindingSemanticGraph, True));
end;

function SnapshotCacheIdentityForUnit(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; const aSourceFileName: string;
  const aParseAvoidedEstimateMilliseconds: Int64): TDelphiSemanticSnapshotCacheIdentity;
var
  lFullSourceFileName: string;
begin
  lFullSourceFileName := TPath.GetFullPath(aSourceFileName);
  Result := Default(TDelphiSemanticSnapshotCacheIdentity);
  Result.IdentityKey := lFullSourceFileName;
  Result.SourceFileName := lFullSourceFileName;
  if TFile.Exists(lFullSourceFileName) then
    Result.FileHash := THashSHA2.GetHashStringFromFile(lFullSourceFileName)
  else
    Result.FileHash := 'missing';
  Result.ContextHash := SnapshotCacheContextHash(aProject, aOptions);
  Result.IncludeGraphHash := aProject.ContextFingerprint;
  if Result.IncludeGraphHash = '' then
    Result.IncludeGraphHash := 'no-project-context';
  Result.SchemaVersion := cProjectSnapshotCacheIdentitySchemaVersion;
  Result.ParseAvoidedEstimateMilliseconds := aParseAvoidedEstimateMilliseconds;
  Result.CacheKey := THashSHA2.GetHashString('snapshot|' + Result.SchemaVersion + '|' +
    Result.SourceFileName + '|' + Result.FileHash + '|' + Result.ContextHash + '|' +
    Result.IncludeGraphHash);
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

function BodyAnalysisSourceFileSet(const aOptions: TDelphiSemanticOptions):
  TDictionary<string, Byte>;
var
  lFileName: string;
begin
  if Length(aOptions.BodyAnalysisSourceFileNames) = 0 then
    Exit(nil);

  Result := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lFileName in aOptions.BodyAnalysisSourceFileNames do
    if Trim(lFileName) <> '' then
      Result.AddOrSetValue(TPath.GetFullPath(lFileName), 0);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64):
  TArray<TDelphiSemanticUnitModel>; overload; forward;
function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics): TArray<TDelphiSemanticUnitModel>;
  overload; forward;
function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics;
  out aCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>):
  TArray<TDelphiSemanticUnitModel>; overload; forward;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions):
  TArray<TDelphiSemanticUnitModel>; overload;
var
  lCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lExtractionMilliseconds: Int64;
begin
  Result := ExtractProjectModels(aProject, aOptions, lExtractionMilliseconds,
    lCacheMetrics, lCacheIdentities);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64):
  TArray<TDelphiSemanticUnitModel>; overload;
var
  lCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
  lCacheMetrics: TDelphiSemanticCacheMetrics;
begin
  Result := ExtractProjectModels(aProject, aOptions, aExtractionMilliseconds,
    lCacheMetrics, lCacheIdentities);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics): TArray<TDelphiSemanticUnitModel>;
  overload;
var
  lCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>;
begin
  Result := ExtractProjectModels(aProject, aOptions, aExtractionMilliseconds,
    aCacheMetrics, lCacheIdentities);
end;

function ExtractProjectModels(const aProject: TDelphiSemanticProjectInfo;
  const aOptions: TDelphiSemanticOptions; out aExtractionMilliseconds: Int64;
  out aCacheMetrics: TDelphiSemanticCacheMetrics;
  out aCacheIdentities: TArray<TDelphiSemanticUnitCacheIdentity>):
  TArray<TDelphiSemanticUnitModel>;
  overload;
var
  lBodyAnalysisSourceFiles: TDictionary<string, Byte>;
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  i: Integer;
  lIdentity: TDelphiSemanticUnitCacheIdentity;
  lModel: TDelphiSemanticUnitModel;
  lModels: TList<TDelphiSemanticUnitModel>;
  lSkipBodyAnalysis: Boolean;
  lSourceFileNames: TArray<string>;
  lStopwatch: TStopwatch;
begin
  lBodyAnalysisSourceFiles := nil;
  lModels := nil;
  lCache := nil;
  aExtractionMilliseconds := 0;
  aCacheMetrics := Default(TDelphiSemanticCacheMetrics);
  SetLength(aCacheIdentities, 0);
  lStopwatch := TStopwatch.StartNew;
  try
    if Trim(aOptions.SqliteCacheFileName) <> '' then
    begin
      lCacheOptions := CacheOptionsFromSessionOptions(aOptions);
      lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
    end;

    lSourceFileNames := ProjectModelFileNames(aProject);
    SetLength(aCacheIdentities, Length(lSourceFileNames));
    lBodyAnalysisSourceFiles := BodyAnalysisSourceFileSet(aOptions);
    lModels := TList<TDelphiSemanticUnitModel>.Create;
    for i := 0 to High(lSourceFileNames) do
    begin
      lSkipBodyAnalysis := Assigned(lBodyAnalysisSourceFiles) and
        (not lBodyAnalysisSourceFiles.ContainsKey(lSourceFileNames[i]));
      lModel := ExtractProjectUnitModel(aProject, lSourceFileNames[i], lCache,
        lSkipBodyAnalysis, lIdentity);
      aCacheIdentities[i] := lIdentity;
      if (i = 0) and (lModel.Success) and (lModel.UnitName = '') and
        SameText(lModel.FileName, aProject.MainSourceFileName) then
        lModel.UnitName := aProject.ProjectName;
      lModels.Add(lModel);
    end;

    Result := lModels.ToArray;
  finally
    lStopwatch.Stop;
    aExtractionMilliseconds := lStopwatch.ElapsedMilliseconds;
    if Assigned(lCache) then
      aCacheMetrics := lCache.Metrics;
    lCache.Free;
    lBodyAnalysisSourceFiles.Free;
    lModels.Free;
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

procedure StoreSnapshotCacheEntries(const aCacheFileName: string;
  const aProject: TDelphiSemanticProjectInfo; const aOptions: TDelphiSemanticOptions;
  const aSourceFileNames: TArray<string>; const aSnapshot: TDelphiProjectSnapshot;
  const aParseAvoidedEstimateMilliseconds: Int64);
var
  i: Integer;
  lCache: TDelphiSemanticSnapshotSqliteCache;
  lIdentity: TDelphiSemanticSnapshotCacheIdentity;
begin
  if (Trim(aCacheFileName) = '') or (aSnapshot = nil) then
    Exit;

  lCache := TDelphiSemanticSnapshotSqliteCache.Create(aCacheFileName);
  try
    for i := 0 to High(aSourceFileNames) do
    begin
      lIdentity := SnapshotCacheIdentityForUnit(aProject, aOptions, aSourceFileNames[i],
        aParseAvoidedEstimateMilliseconds);
      lCache.StoreUnitFromSnapshot(lIdentity, aSnapshot, i);
    end;
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

function TDelphiSemanticProjectSession.BuildSemanticGraph: TDelphiSemanticSemanticGraph;
var
  lExtractionMilliseconds: Int64;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := ExtractProjectModels(fProject, fOptions, lExtractionMilliseconds);
  Result := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lModels);
  fLastSemanticGraphBuildMetrics := Result.Metrics;
end;

function TDelphiSemanticProjectSession.BuildSymbolQueryContext(
  out aCacheMetrics: TDelphiSemanticCacheMetrics; out aExtractionMilliseconds: Int64):
  TDelphiSemanticSymbolQueryContext;
var
  i: Integer;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  Result := Default(TDelphiSemanticSymbolQueryContext);
  aCacheMetrics := Default(TDelphiSemanticCacheMetrics);
  aExtractionMilliseconds := 0;
  lModels := ExtractProjectModels(fProject, fOptions, aExtractionMilliseconds,
    aCacheMetrics);
  if Length(lModels) = 0 then
    Exit;

  Result.UnitModel := lModels[0];
  if Length(lModels) > 1 then
  begin
    SetLength(Result.IndexedUnitModels, Length(lModels) - 1);
    SetLength(Result.IndexedUnitSourceKinds, Length(lModels) - 1);
    for i := 1 to High(lModels) do
    begin
      Result.IndexedUnitModels[i - 1] := lModels[i];
      Result.IndexedUnitSourceKinds[i - 1] := 'project-source';
    end;
  end;
end;

function TDelphiSemanticProjectSession.BuildSnapshot: TDelphiProjectSnapshot;
var
  lCacheIdentity: TDelphiSemanticSnapshotCacheIdentity;
  lCacheMetrics: TDelphiSemanticSnapshotCacheMetrics;
  lCacheSnapshot: TDelphiProjectSnapshot;
  lCacheSnapshotMetrics: TDelphiSemanticProjectSnapshotBuildMetrics;
  lLoadedAllUnits: Boolean;
  lBuilderMetrics: TDelphiSnapshotBuilderMetrics;
  lExtractionMilliseconds: Int64;
  i: Integer;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lParseAvoidedEstimateMilliseconds: Int64;
  lSnapshot: TDelphiProjectSnapshot;
  lSourceFileNames: TArray<string>;
  lUnitSnapshots: TArray<TDelphiProjectSnapshot>;
begin
  Result := nil;
  fLastSnapshotBuildMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
  lSourceFileNames := ProjectModelFileNames(fProject);
  lCacheSnapshotMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
  SetLength(lUnitSnapshots, 0);
  if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
  begin
    SetLength(lUnitSnapshots, Length(lSourceFileNames));
    lLoadedAllUnits := True;
    for i := 0 to High(lSourceFileNames) do
    begin
      lCacheIdentity := SnapshotCacheIdentityForUnit(fProject, fOptions, lSourceFileNames[i],
        0);
      lCacheSnapshot := nil;
      if TryLoadSingleUnitSnapshotFromCache(fOptions.SqliteCacheFileName, lCacheIdentity,
        lCacheSnapshot, lCacheMetrics) then
        lUnitSnapshots[i] := lCacheSnapshot
      else begin
        lCacheSnapshot.Free;
        lLoadedAllUnits := False;
      end;
      AccumulateSnapshotCacheMetrics(lCacheSnapshotMetrics, lCacheMetrics);
    end;

    if lLoadedAllUnits then
    begin
      try
        lSnapshot := BuildProjectSnapshotFromUnitSnapshots(lUnitSnapshots, lBuilderMetrics);
        try
          fLastSnapshotBuildMetrics := Default(TDelphiSemanticProjectSnapshotBuildMetrics);
          ApplySnapshotBuilderMetrics(fLastSnapshotBuildMetrics, lBuilderMetrics);
          AddSnapshotCacheMetricTotals(fLastSnapshotBuildMetrics, lCacheSnapshotMetrics);
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

  lModels := ExtractProjectModels(fProject, fOptions, lExtractionMilliseconds);
  lParseAvoidedEstimateMilliseconds := VisibleMetricMilliseconds(lExtractionMilliseconds);
  if Length(lUnitSnapshots) > 0 then
  begin
    try
      for i := 0 to High(lSourceFileNames) do
        if lUnitSnapshots[i] = nil then
          lUnitSnapshots[i] := BuildSingleUnitSnapshotFromModels(lModels, i,
            TSemanticUnitId(i + 1), lCacheSnapshotMetrics);
      lSnapshot := BuildProjectSnapshotFromUnitSnapshots(lUnitSnapshots, lBuilderMetrics);
    finally
      FreeSnapshots(lUnitSnapshots);
    end;
    ApplySnapshotBuilderMetrics(fLastSnapshotBuildMetrics, lBuilderMetrics);
  end else
    lSnapshot := BuildSnapshotFromModels(lModels, fOptions.SnapshotBuildWorkerCount,
      fLastSnapshotBuildMetrics);
  try
    AddSnapshotCacheMetricTotals(fLastSnapshotBuildMetrics, lCacheSnapshotMetrics);
    if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
      fLastSnapshotBuildMetrics.SnapshotCacheUnitMergeMilliseconds :=
        lBuilderMetrics.MergeMilliseconds;
    fLastSnapshotBuildMetrics.SnapshotParseAvoidedEstimateMilliseconds :=
      lParseAvoidedEstimateMilliseconds;
    if (Length(lSourceFileNames) > 0) and (Trim(fOptions.SqliteCacheFileName) <> '') then
      StoreSnapshotCacheEntries(fOptions.SqliteCacheFileName, fProject, fOptions,
        lSourceFileNames, lSnapshot, lParseAvoidedEstimateMilliseconds);
    Result := lSnapshot;
    lSnapshot := nil;
  finally
    lSnapshot.Free;
  end;
end;

function TDelphiSemanticProjectSession.BuildWithBindingFacts:
  TDelphiSemanticProjectWithBindingFacts;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lGraph: TDelphiSemanticSemanticGraph;
  lExtractionMilliseconds: Int64;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := ExtractProjectModels(fProject, fOptions, lExtractionMilliseconds,
    lCacheMetrics);

  if fOptions.SkipWithBindingSemanticGraph then
    lGraph := nil
  else
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lModels);
  try
    if lGraph <> nil then
      fLastSemanticGraphBuildMetrics := lGraph.Metrics
    else
      fLastSemanticGraphBuildMetrics := Default(TDelphiSemanticGraphBuildMetrics);
    Result := TDelphiSemanticWithBinder.BindProject(fProject.ContextFingerprint, lGraph,
      lModels);
    Result.Metrics.ModelExtractionMilliseconds := lExtractionMilliseconds;
    Result.Metrics.SemanticCacheHits := lCacheMetrics.CacheHits;
    Result.Metrics.SemanticCacheMisses := lCacheMetrics.CacheMisses;
    Result.Metrics.SemanticCacheInvalidations := lCacheMetrics.Invalidations;
    Result.Metrics.SemanticCachePersistentConnectionOpenCount :=
      lCacheMetrics.PersistentConnectionOpenCount;
  finally
    lGraph.Free;
  end;
end;

function TDelphiSemanticProjectSession.PlanRemoveWith: TDelphiSemanticRemoveWithPlan;
var
  lCacheMetrics: TDelphiSemanticCacheMetrics;
  lExtractionMilliseconds: Int64;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGraph: TDelphiSemanticSemanticGraph;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lModels := ExtractProjectModels(fProject, fOptions, lExtractionMilliseconds, lCacheMetrics);
  if fOptions.SkipWithBindingSemanticGraph then
    lGraph := nil
  else
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(fProject, lModels);
  try
    if lGraph <> nil then
      fLastSemanticGraphBuildMetrics := lGraph.Metrics
    else
      fLastSemanticGraphBuildMetrics := Default(TDelphiSemanticGraphBuildMetrics);

    lFacts := TDelphiSemanticWithBinder.BindProject(fProject.ContextFingerprint, lGraph,
      lModels);
    lFacts.Metrics.ModelExtractionMilliseconds := lExtractionMilliseconds;
    lFacts.Metrics.SemanticCacheHits := lCacheMetrics.CacheHits;
    lFacts.Metrics.SemanticCacheMisses := lCacheMetrics.CacheMisses;
    lFacts.Metrics.SemanticCacheInvalidations := lCacheMetrics.Invalidations;
    lFacts.Metrics.SemanticCachePersistentConnectionOpenCount :=
      lCacheMetrics.PersistentConnectionOpenCount;

    lSnapshot := BuildSnapshotFromModels(lModels, lFacts, False,
      fOptions.SnapshotBuildWorkerCount, fLastSnapshotBuildMetrics);
    try
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
  lFiles: TList<string>;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lReasons: TList<string>;
  lUnits: TList<string>;
begin
  Result := Default(TDelphiSemanticSessionInvalidationPlan);
  lFiles := TList<string>.Create;
  lUnits := TList<string>.Create;
  lReasons := TList<string>.Create;
  try
    lModels := ExtractProjectModels(fProject, fOptions);
    for lChange in aChanges do
    begin
      if SameText(lChange.ChangeKind, 'context') then
      begin
        Result.ContextInvalidated := True;
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'CONTEXT_CHANGED');
        AddAllModels(lModels, lFiles, lUnits);
      end else if SameText(lChange.ChangeKind, 'include') or
        SameText(TPath.GetExtension(lChange.FileName), '.inc') then
      begin
        Result.IncludeGraphInvalidated := True;
        AddUniqueText(lReasons, 'INCLUDE_GRAPH_CHANGED');
        AddAllModels(lModels, lFiles, lUnits);
      end else if SameText(lChange.ChangeKind, 'unknown') then
      begin
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'UNKNOWN_CHANGE');
        AddAllModels(lModels, lFiles, lUnits);
      end else if FindModelByFileName(lModels, lChange.FileName, lModel) then
      begin
        if (not lModel.Success) or (Trim(lModel.UnitName) = '') then
        begin
          Result.RequiresFullSessionRebuild := True;
          AddUniqueText(lReasons, 'CHANGED_UNIT_MODEL_UNAVAILABLE');
          AddAllModels(lModels, lFiles, lUnits);
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
          AddDependentClosure(lModels, lModel, lFiles, lUnits);
        end;
      end else
      begin
        Result.RequiresFullSessionRebuild := True;
        AddUniqueText(lReasons, 'CHANGE_OUTSIDE_PROJECT_MODEL');
        AddAllModels(lModels, lFiles, lUnits);
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
