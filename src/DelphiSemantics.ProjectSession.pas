unit DelphiSemantics.ProjectSession;

interface

uses
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.RemoveWithPlan,
  DelphiSemantics.SemanticGraph, DelphiSemantics.Snapshot, DelphiSemantics.WithBinding;

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
  DelphiSemantics.Cache, DelphiSemantics.Cache.Sqlite, DelphiSemantics.Index,
  DelphiSemantics.Query, DelphiSemantics.Snapshot.Builder,
  DelphiSemantics.Snapshot.Cache.Sqlite, DelphiSemantics.Symbols, MaxLogic.StrUtils;

const
  cProjectSnapshotCacheIdentitySchemaVersion = 'project-session-snapshot-v2';
  cSnapshotDeclarationKindAlias = 'alias';
  cSnapshotDeclarationKindTypeAlias = 'type-alias';
  cSnapshotSymbolFlagIsDefault = 1;
  cSnapshotSymbolFlagIsIndexed = 2;
  cSnapshotSymbolKindLocal = 'local';
  cSnapshotSymbolKindParameter = 'parameter';
  cSnapshotSymbolKindRoutine = 'routine';
  cSnapshotSourceKindProject = 'project-source';
  cSnapshotWithFlagHasScopedDeclaration = 1;

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

function SnapshotDeclarationKind(const aKind: string): string;
begin
  if SameText(aKind, cSnapshotDeclarationKindTypeAlias) then
    Exit(cSnapshotDeclarationKindAlias);

  Result := aKind;
end;

function SnapshotEndColumn(const aColumn: Integer; const aName: string): Integer;
begin
  if (aColumn <= 0) or (aName = '') then
    Exit(0);

  Result := aColumn + Length(aName) - 1;
end;

function SnapshotFullPath(const aFileName: string): string;
begin
  if Trim(aFileName) = '' then
    Exit('');

  Result := TPath.GetFullPath(aFileName);
end;

function SnapshotRoutineName(const aRoutine: TDelphiSemanticRoutine): string;
begin
  if aRoutine.OwnerName <> '' then
    Exit(aRoutine.OwnerName + '.' + aRoutine.Name);

  Result := aRoutine.Name;
end;

function SnapshotRoutineNameForLine(const aModel: TDelphiSemanticUnitModel;
  const aLine: Integer): string;
var
  lBestLine: Integer;
  lRoutine: TDelphiSemanticRoutine;
begin
  Result := '';
  lBestLine := 0;
  if aLine <= 0 then
    Exit;

  for lRoutine in aModel.Routines do
  begin
    if (lRoutine.Line <= 0) or (lRoutine.Line > aLine) then
      Continue;
    if lRoutine.Line < lBestLine then
      Continue;

    lBestLine := lRoutine.Line;
    Result := SnapshotRoutineName(lRoutine);
  end;
end;

function SnapshotWithIdForLine(const aUnit: TUnitSnapshot; const aLine: Integer):
  TSemanticWithId;
begin
  Result := 0;
  aUnit.TryFindInnermostWithStatementAtLine(aLine, Result);
end;

function SnapshotSymbolMatchKey(const aUnitName, aKind, aOwnerName, aName,
  aSignature: string; const aLine, aColumn: Integer): string;
begin
  Result := aUnitName + #9 + aKind + #9 + aOwnerName + #9 + aName + #9 +
    aSignature + #9 + IntToStr(aLine) + #9 + IntToStr(aColumn);
end;

function SnapshotReferenceMatchKey(const aUnitName, aRoutineName, aName: string;
  const aLine, aColumn: Integer): string;
begin
  Result := aUnitName + #9 + aRoutineName + #9 + aName + #9 + IntToStr(aLine) +
    #9 + IntToStr(aColumn);
end;

procedure AddSnapshotSymbolOrigin(
  const aMap: TDictionary<string, TSemanticSymbolRef>;
  const aUnitName, aKind, aOwnerName, aName, aSignature: string; const aLine,
  aColumn: Integer; const aUnitId: TSemanticUnitId; var aNextSymbolId: TSemanticSymbolId);
var
  lRef: TSemanticSymbolRef;
begin
  Inc(aNextSymbolId);
  if aName = '' then
    Exit;

  lRef.UnitId := aUnitId;
  lRef.SymbolId := aNextSymbolId;
  aMap.AddOrSetValue(SnapshotSymbolMatchKey(aUnitName, aKind, aOwnerName, aName,
    aSignature, aLine, aColumn), lRef);
end;

function BuildSnapshotSymbolRefsByOrigin(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TDictionary<string, TSemanticSymbolRef>;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lParameter: TDelphiSemanticParameter;
  lRoutine: TDelphiSemanticRoutine;
  lSymbolId: TSemanticSymbolId;
  lUnitId: TSemanticUnitId;
  lUnitModel: TDelphiSemanticUnitModel;
begin
  Result := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  for lUnitId := 1 to TSemanticUnitId(Length(aModels)) do
  begin
    lUnitModel := aModels[Integer(lUnitId) - 1];
    lSymbolId := 0;
    for lDeclaration in lUnitModel.Declarations do
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, lDeclaration.Kind, '',
        lDeclaration.Name, '', lDeclaration.Line, lDeclaration.Column, lUnitId, lSymbolId);
    for lMember in lUnitModel.Members do
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, lMember.Kind, lMember.OwnerName,
        lMember.Name, lMember.Signature, lMember.Line, lMember.Column, lUnitId, lSymbolId);
    for lRoutine in lUnitModel.Routines do
    begin
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, cSnapshotSymbolKindRoutine,
        lRoutine.OwnerName, lRoutine.Name, lRoutine.Signature, lRoutine.Line, lRoutine.Column,
        lUnitId, lSymbolId);
      for lParameter in lRoutine.Parameters do
        AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, cSnapshotSymbolKindParameter,
          SnapshotRoutineName(lRoutine), lParameter.Name, '', lParameter.Line, lParameter.Column,
          lUnitId, lSymbolId);
    end;
    for lLocal in lUnitModel.Locals do
      AddSnapshotSymbolOrigin(Result, lUnitModel.UnitName, lLocal.Kind, lLocal.RoutineName,
        lLocal.Name, '', lLocal.Line, lLocal.Column, lUnitId, lSymbolId);
  end;
end;

function BuildProjectSymbolIndexContext(
  const aModels: TArray<TDelphiSemanticUnitModel>): TDelphiSemanticSymbolQueryContext;
var
  i: Integer;
begin
  Result := Default(TDelphiSemanticSymbolQueryContext);
  if Length(aModels) = 0 then
    Exit;

  Result.UnitModel := aModels[0];
  SetLength(Result.IndexedUnitModels, Length(aModels) - 1);
  SetLength(Result.IndexedUnitSourceKinds, Length(aModels) - 1);
  for i := 1 to High(aModels) do
  begin
    Result.IndexedUnitModels[i - 1] := aModels[i];
    Result.IndexedUnitSourceKinds[i - 1] := cSnapshotSourceKindProject;
  end;
end;

function BuildSnapshotReferenceTargets(
  const aModels: TArray<TDelphiSemanticUnitModel>):
  TDictionary<string, TSemanticSymbolRef>;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lReference: TDelphiSemanticIndexedReference;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolRef: TSemanticSymbolRef;
  lSymbolRefByLegacyId: TDictionary<string, TSemanticSymbolRef>;
  lSymbolRefsByOrigin: TDictionary<string, TSemanticSymbolRef>;
begin
  Result := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  lSymbolRefsByOrigin := BuildSnapshotSymbolRefsByOrigin(aModels);
  lSymbolRefByLegacyId := TDictionary<string, TSemanticSymbolRef>.Create(
    TFastCaseAwareComparer.OrdinalIgnoreCase);
  try
    lContext := BuildProjectSymbolIndexContext(aModels);
    lIndex := TDelphiSemanticProjectSymbolIndexer.Build(lContext);

    for lSymbol in lIndex.Symbols do
      if lSymbolRefsByOrigin.TryGetValue(SnapshotSymbolMatchKey(lSymbol.UnitName,
        lSymbol.Kind, lSymbol.OwnerName, lSymbol.Name, lSymbol.Signature, lSymbol.Line,
        lSymbol.Column), lSymbolRef) then
        lSymbolRefByLegacyId.AddOrSetValue(lSymbol.Id.Value, lSymbolRef);

    for lReference in lIndex.References do
      if SameText(lReference.Status, 'resolved') and
        lSymbolRefByLegacyId.TryGetValue(lReference.SymbolId.Value, lSymbolRef) then
        Result.AddOrSetValue(SnapshotReferenceMatchKey(lReference.UnitName,
          lReference.RoutineName, lReference.Name, lReference.Line, lReference.Column),
          lSymbolRef);
  finally
    lSymbolRefByLegacyId.Free;
    lSymbolRefsByOrigin.Free;
  end;
end;

procedure AddSnapshotWithStatement(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aModel: TDelphiSemanticUnitModel;
  const aWith: TDelphiSemanticWithStatement;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lWith: TSemanticWithStatementFact;
begin
  lWith := Default(TSemanticWithStatementFact);
  lWith.RoutineId := aStrings.Intern(SnapshotRoutineNameForLine(aModel, aWith.Line));
  lWith.SelectorStartLine := aWith.Line;
  lWith.SelectorStartColumn := aWith.Column;
  lWith.BodyStartLine := aWith.BodyLine;
  lWith.BodyStartColumn := aWith.BodyColumn;
  lWith.BodyEndLine := aWith.BodyEndLine;
  lWith.BodyEndColumn := aWith.BodyEndColumn;
  if aWith.HasScopedDeclaration then
    lWith.Flags := cSnapshotWithFlagHasScopedDeclaration;
  aUnit.AddWithStatement(lWith);
  Inc(aMetrics.WithStatementCount);
end;

procedure AddSnapshotDeclaration(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aDeclaration: TDelphiSemanticDeclaration;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aDeclaration.Name);
  lSymbol.TypeId := aStrings.Intern(aDeclaration.TypeName);
  lSymbol.KindId := aStrings.Intern(SnapshotDeclarationKind(aDeclaration.Kind));
  lSymbol.SectionKindId := aStrings.Intern(aDeclaration.SectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aDeclaration.Line;
  lSymbol.Column := aDeclaration.Column;
  lSymbol.EndLine := aDeclaration.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aDeclaration.Column, aDeclaration.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotMember(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aMember: TDelphiSemanticMember;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aMember.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aMember.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aMember.TypeName);
  lSymbol.KindId := aStrings.Intern(aMember.Kind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.VisibilityId := aStrings.Intern(aMember.Visibility);
  lSymbol.SignatureId := aStrings.Intern(aMember.Signature);
  lSymbol.Line := aMember.Line;
  lSymbol.Column := aMember.Column;
  lSymbol.EndLine := aMember.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aMember.Column, aMember.Name);
  if aMember.IsDefault then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsDefault;
  if aMember.IsIndexed then
    lSymbol.Flags := lSymbol.Flags or cSnapshotSymbolFlagIsIndexed;
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotParameter(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutineName: string;
  const aParameter: TDelphiSemanticParameter;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lSymbol: TSemanticSymbolFact;
begin
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aParameter.Name);
  lSymbol.TypeId := aStrings.Intern(aParameter.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindParameter);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aParameter.Line;
  lSymbol.Column := aParameter.Column;
  lSymbol.EndLine := aParameter.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aParameter.Column, aParameter.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotRoutine(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aRoutine: TDelphiSemanticRoutine;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lParameter: TDelphiSemanticParameter;
  lRoutineName: string;
  lSymbol: TSemanticSymbolFact;
begin
  lRoutineName := SnapshotRoutineName(aRoutine);
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aRoutine.Name);
  lSymbol.OwnerTypeId := aStrings.Intern(aRoutine.OwnerName);
  lSymbol.TypeId := aStrings.Intern(aRoutine.ReturnType);
  lSymbol.RoutineId := aStrings.Intern(lRoutineName);
  lSymbol.KindId := aStrings.Intern(cSnapshotSymbolKindRoutine);
  lSymbol.SectionKindId := aStrings.Intern(aRoutine.SectionKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.SignatureId := aStrings.Intern(aRoutine.Signature);
  lSymbol.Line := aRoutine.Line;
  lSymbol.Column := aRoutine.Column;
  lSymbol.EndLine := aRoutine.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aRoutine.Column, aRoutine.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);

  for lParameter in aRoutine.Parameters do
    AddSnapshotParameter(aStrings, aUnit, lRoutineName, lParameter, aMetrics);
end;

procedure AddSnapshotLocal(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aLocal: TDelphiSemanticLocal;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lKind: string;
  lSymbol: TSemanticSymbolFact;
begin
  lKind := aLocal.Kind;
  if lKind = '' then
    lKind := cSnapshotSymbolKindLocal;
  lSymbol := Default(TSemanticSymbolFact);
  lSymbol.NameId := aStrings.Intern(aLocal.Name);
  lSymbol.TypeId := aStrings.Intern(aLocal.TypeName);
  lSymbol.RoutineId := aStrings.Intern(aLocal.RoutineName);
  lSymbol.KindId := aStrings.Intern(lKind);
  lSymbol.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lSymbol.Line := aLocal.Line;
  lSymbol.Column := aLocal.Column;
  lSymbol.EndLine := aLocal.Line;
  lSymbol.EndColumn := SnapshotEndColumn(aLocal.Column, aLocal.Name);
  aUnit.AddSymbol(lSymbol);
  Inc(aMetrics.SymbolCount);
end;

procedure AddSnapshotReference(const aStrings: TSemanticStringPool;
  const aUnit: TUnitSnapshot; const aUnitName: string;
  const aReference: TDelphiSemanticReference;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lReference: TSemanticReferenceFact;
  lTarget: TSemanticSymbolRef;
begin
  lReference := Default(TSemanticReferenceFact);
  lReference.WithId := SnapshotWithIdForLine(aUnit, aReference.Line);
  lReference.NameId := aStrings.Intern(aReference.Name);
  lReference.RoutineId := aStrings.Intern(aReference.RoutineName);
  lReference.SectionKindId := aStrings.Intern(aReference.SectionKind);
  lReference.SourceKindId := aStrings.Intern(cSnapshotSourceKindProject);
  lReference.ClassificationId := aStrings.Intern(aReference.Role);
  lReference.Line := aReference.Line;
  lReference.Column := aReference.Column;
  lReference.EndLine := aReference.EndLine;
  if lReference.EndLine <= 0 then
    lReference.EndLine := aReference.Line;
  lReference.EndColumn := aReference.EndColumn;
  if lReference.EndColumn <= 0 then
    lReference.EndColumn := SnapshotEndColumn(aReference.Column, aReference.Name);
  if (aReferenceTargets <> nil) and aReferenceTargets.TryGetValue(
    SnapshotReferenceMatchKey(aUnitName, aReference.RoutineName, aReference.Name,
    aReference.Line, aReference.Column), lTarget) then
  begin
    lReference.TargetUnitId := lTarget.UnitId;
    lReference.TargetSymbolId := lTarget.SymbolId;
  end;
  aUnit.AddReference(lReference);
  Inc(aMetrics.ReferenceCount);
end;

function CreateSnapshotUnitModel(const aBuilder: TDelphiProjectSnapshotBuilder;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics): TUnitSnapshot;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lReference: TDelphiSemanticReference;
  lRoutine: TDelphiSemanticRoutine;
  lWith: TDelphiSemanticWithStatement;
begin
  Result := TUnitSnapshot.Create(aUnitId,
    aBuilder.Strings.Intern(SnapshotFullPath(aModel.FileName)),
    aBuilder.Strings.Intern(aModel.UnitName));
  try
    for lWith in aModel.WithStatements do
      AddSnapshotWithStatement(aBuilder.Strings, Result, aModel, lWith, aMetrics);
    for lDeclaration in aModel.Declarations do
      AddSnapshotDeclaration(aBuilder.Strings, Result, lDeclaration, aMetrics);
    for lMember in aModel.Members do
      AddSnapshotMember(aBuilder.Strings, Result, lMember, aMetrics);
    for lRoutine in aModel.Routines do
      AddSnapshotRoutine(aBuilder.Strings, Result, lRoutine, aMetrics);
    for lLocal in aModel.Locals do
      AddSnapshotLocal(aBuilder.Strings, Result, lLocal, aMetrics);
    for lReference in aModel.References do
      AddSnapshotReference(aBuilder.Strings, Result, aModel.UnitName, lReference,
        aReferenceTargets, aMetrics);

  except
    Result.Free;
    raise;
  end;
end;

procedure AddSnapshotUnitModel(const aBuilder: TDelphiProjectSnapshotBuilder;
  const aModel: TDelphiSemanticUnitModel; const aUnitId: TSemanticUnitId;
  const aReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  var aMetrics: TDelphiSemanticProjectSnapshotBuildMetrics);
var
  lUnit: TUnitSnapshot;
begin
  lUnit := CreateSnapshotUnitModel(aBuilder, aModel, aUnitId, aReferenceTargets, aMetrics);
  try
    aBuilder.AddUnit(lUnit);
    lUnit := nil;
    Inc(aMetrics.UnitCount);
  finally
    lUnit.Free;
  end;
end;

procedure AddSnapshotFlag(var aFlags: Cardinal; const aFlag: Cardinal;
  const aEnabled: Boolean);
begin
  if aEnabled then
    aFlags := aFlags or aFlag;
end;

function SnapshotInventorySymbol(const aExactStrings: TSemanticStringPool;
  const aSymbol: TDelphiSemanticInventorySymbol): TSemanticRemoveWithInventorySymbolFact;
begin
  Result := Default(TSemanticRemoveWithInventorySymbolFact);
  Result.NameId := aExactStrings.Intern(aSymbol.Name);
  Result.SymbolClassId := aExactStrings.Intern(aSymbol.SymbolClass);
  Result.KindId := aExactStrings.Intern(aSymbol.Kind);
  Result.TypeNameId := aExactStrings.Intern(aSymbol.TypeName);
  Result.ModifierId := aExactStrings.Intern(aSymbol.Modifier);
  Result.OwnerNameId := aExactStrings.Intern(aSymbol.OwnerName);
  Result.OwnerTypeId := aExactStrings.Intern(aSymbol.OwnerType);
  Result.SourceOwnerTypeId := aExactStrings.Intern(aSymbol.SourceOwnerType);
  Result.RelatedTypeNameId := aExactStrings.Intern(aSymbol.RelatedTypeName);
  Result.RoutineNameId := aExactStrings.Intern(aSymbol.RoutineName);
  Result.UnitNameId := aExactStrings.Intern(aSymbol.UnitName);
  Result.FileNameId := aExactStrings.Intern(aSymbol.FileName);
  Result.SectionKindId := aExactStrings.Intern(aSymbol.SectionKind);
  Result.Line := aSymbol.Line;
  Result.Column := aSymbol.Column;
  Result.EndLine := aSymbol.EndLine;
  Result.EndColumn := aSymbol.EndColumn;
  Result.UnsupportedReasonId := aExactStrings.Intern(aSymbol.UnsupportedReason);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsHelper,
    aSymbol.IsHelper);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsOverride,
    aSymbol.IsOverride);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsDefault,
    aSymbol.IsDefault);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithSymbolFlagIsIndexed,
    aSymbol.IsIndexed);
  Result.IndexParameterCount := aSymbol.IndexParameterCount;
  Result.TypeCategoryId := aExactStrings.Intern(aSymbol.TypeCategory);
end;

function SnapshotSelectorBinding(const aExactStrings: TSemanticStringPool;
  const aSelector: TDelphiSemanticWithSelectorBinding):
  TSemanticRemoveWithSelectorBindingFact;
begin
  Result := Default(TSemanticRemoveWithSelectorBindingFact);
  Result.SelectorTextId := aExactStrings.Intern(aSelector.SelectorText);
  Result.StatusId := aExactStrings.Intern(aSelector.Status);
  Result.ReasonCodeId := aExactStrings.Intern(aSelector.ReasonCode);
  Result.TypeNameId := aExactStrings.Intern(aSelector.TypeName);
end;

function SnapshotBoundReference(const aExactStrings: TSemanticStringPool;
  const aReference: TDelphiSemanticBoundReference):
  TSemanticRemoveWithBoundReferenceFact;
begin
  Result := Default(TSemanticRemoveWithBoundReferenceFact);
  Result.SemanticIdId := aExactStrings.Intern(aReference.SemanticId);
  Result.NameId := aExactStrings.Intern(aReference.Name);
  Result.ClassificationId := aExactStrings.Intern(aReference.Classification);
  Result.LookupSourceId := aExactStrings.Intern(aReference.LookupSource);
  Result.ReceiverTypeNameId := aExactStrings.Intern(aReference.ReceiverTypeName);
  Result.KindId := aExactStrings.Intern(aReference.Kind);
  Result.TypeNameId := aExactStrings.Intern(aReference.TypeName);
  Result.ReasonCodeId := aExactStrings.Intern(aReference.ReasonCode);
  Result.ScopeConflictKindId := aExactStrings.Intern(aReference.ScopeConflictKind);
  Result.ScopeConflictNameId := aExactStrings.Intern(aReference.ScopeConflictName);
  Result.Line := aReference.Line;
  Result.Column := aReference.Column;
  Result.EndLine := aReference.EndLine;
  Result.EndColumn := aReference.EndColumn;
end;

function SnapshotWithBinding(const aExactStrings: TSemanticStringPool;
  const aBinding: TDelphiSemanticWithBinding): TSemanticRemoveWithBindingFact;
var
  i: Integer;
begin
  Result := Default(TSemanticRemoveWithBindingFact);
  Result.SemanticIdId := aExactStrings.Intern(aBinding.SemanticId);
  Result.ProvenanceId := aExactStrings.Intern(aBinding.Provenance);
  Result.FileNameId := aExactStrings.Intern(aBinding.FileName);
  Result.UnitNameId := aExactStrings.Intern(aBinding.UnitName);
  Result.RoutineNameId := aExactStrings.Intern(aBinding.RoutineName);
  Result.Line := aBinding.Line;
  Result.Column := aBinding.Column;
  Result.EndLine := aBinding.EndLine;
  Result.EndColumn := aBinding.EndColumn;
  Result.BodyLine := aBinding.BodyLine;
  Result.BodyColumn := aBinding.BodyColumn;
  Result.BodyEndLine := aBinding.BodyEndLine;
  Result.BodyEndColumn := aBinding.BodyEndColumn;
  Result.SelectorTextId := aExactStrings.Intern(aBinding.SelectorText);
  Result.StatusId := aExactStrings.Intern(aBinding.Status);
  Result.SkipReasonId := aExactStrings.Intern(aBinding.SkipReason);
  AddSnapshotFlag(Result.Flags, cSemanticRemoveWithBindingFlagHasScopedDeclaration,
    aBinding.HasScopedDeclaration);
  Result.MemberReferenceCount := aBinding.MemberReferenceCount;
  Result.LexicalReferenceCount := aBinding.LexicalReferenceCount;
  Result.ExternalReferenceCount := aBinding.ExternalReferenceCount;
  Result.IntrinsicReferenceCount := aBinding.IntrinsicReferenceCount;
  Result.UnsupportedReferenceCount := aBinding.UnsupportedReferenceCount;
  Result.UnresolvedReferenceCount := aBinding.UnresolvedReferenceCount;
  SetLength(Result.Selectors, Length(aBinding.Selectors));
  for i := 0 to High(aBinding.Selectors) do
    Result.Selectors[i] := SnapshotSelectorBinding(aExactStrings, aBinding.Selectors[i]);
  SetLength(Result.References, Length(aBinding.References));
  for i := 0 to High(aBinding.References) do
    Result.References[i] := SnapshotBoundReference(aExactStrings, aBinding.References[i]);
end;

function CreateRemoveWithPlanningFacts(const aExactStrings: TSemanticStringPool;
  const aFacts: TDelphiSemanticProjectWithBindingFacts): TSemanticRemoveWithPlanningFacts;
var
  i: Integer;
  lRoutineOwners: TList<TSemanticRemoveWithInventorySymbolFact>;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  Result := Default(TSemanticRemoveWithPlanningFacts);
  Result.ContextFingerprintId := aExactStrings.Intern(aFacts.ContextFingerprint);
  if aFacts.LookupIndex.IsAvailable then
    Result.LookupIndex := aFacts.LookupIndex
  else
    Result.LookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(
      aFacts.UnitModels, aFacts.Symbols);
  lRoutineOwners := TList<TSemanticRemoveWithInventorySymbolFact>.Create;
  try
    for lSymbol in aFacts.Symbols do
      if SameText(lSymbol.SymbolClass, 'routine') or SameText(lSymbol.Kind, 'routine') then
        lRoutineOwners.Add(SnapshotInventorySymbol(aExactStrings, lSymbol));
    Result.RoutineOwners := lRoutineOwners.ToArray;
  finally
    lRoutineOwners.Free;
  end;
  SetLength(Result.Bindings, Length(aFacts.Bindings));
  for i := 0 to High(aFacts.Bindings) do
    Result.Bindings[i] := SnapshotWithBinding(aExactStrings, aFacts.Bindings[i]);
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
  lBuilder: TDelphiProjectSnapshotBuilder;
  lReferenceTargets: TDictionary<string, TSemanticSymbolRef>;
  lStopwatch: TStopwatch;
  lUnit: TUnitSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lReferenceTargets := nil;
  lUnit := nil;
  lStopwatch := TStopwatch.StartNew;
  try
    lReferenceTargets := BuildSnapshotReferenceTargets(aModels);
    lUnit := CreateSnapshotUnitModel(lBuilder, aModels[aModelIndex], aUnitId,
      lReferenceTargets, aMetrics);
    lBuilder.AddUnit(lUnit);
    lUnit := nil;
    Result := lBuilder.Build;
  finally
    lStopwatch.Stop;
    Inc(aMetrics.SnapshotCacheUnitBuildMilliseconds, lStopwatch.ElapsedMilliseconds);
    lUnit.Free;
    lReferenceTargets.Free;
    lBuilder.Free;
  end;
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
