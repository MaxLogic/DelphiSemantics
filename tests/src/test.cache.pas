unit Test.Cache;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Cache, DelphiSemantics.Cache.Sqlite, DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model;

type
  [TestFixture]
  TCacheTests = class
  private
    procedure AssertIndexedProfileNameKind(const aProfile: TDelphiSemanticCompilerProfile;
      const aName, aKind: string);
    function FindDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string;
      out aDeclaration: TDelphiSemanticDeclaration): Boolean;
    function FindLocal(const aModel: TDelphiSemanticUnitModel; const aRoutineName, aName: string;
      out aLocal: TDelphiSemanticLocal): Boolean;
    function FindMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName, aName: string;
      out aMember: TDelphiSemanticMember): Boolean;
    function FindReferenceAtOffset(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aOffset: Integer; out aReference: TDelphiSemanticReference): Boolean;
    function FindRoutine(const aModel: TDelphiSemanticUnitModel; const aName, aOwnerName: string;
      out aRoutine: TDelphiSemanticRoutine): Boolean;
    function HasDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string):
      Boolean;
    function TempPath(const aName: string): string;
  public
    [Test]
    procedure DefaultOptionsUseInMemoryCache;
    [Test]
    procedure TempPathUsesPerRunRoot;
    [Test]
    procedure InMemoryMetricsExposeEmptyCacheFileName;
    [Test]
    procedure SharedUnitCacheRejectsReentrantAccess;
    [Test]
    procedure CacheIdentityIncludesLexicalOwnershipModelShape;
    [Test]
    procedure UnitCacheIdentityBuilderReusesSingleSourceLoad;
    [Test]
    procedure RepeatedUnchangedUnitHitsInMemoryCache;
    [Test]
    procedure CacheHitReturnsIndependentUnitModelCopy;
    [Test]
    procedure SourceChangeInvalidatesCachedUnitModel;
    [Test]
    procedure SourceTimestampChangeReusesCachedUnitModel;
    [Test]
    procedure SemanticContextChangeInvalidatesCachedUnitModel;
    [Test]
    procedure ReferenceExtractionOptionInvalidatesCachedUnitModel;
    [Test]
    procedure WritableTypedConstantsOptionInvalidatesCachedUnitModel;
    [Test]
    procedure EquivalentDefineOrderReusesCachedUnitModel;
    [Test]
    procedure SearchPathOrderChangeInvalidatesCachedUnitModel;
    [Test]
    procedure IncludeChangeInvalidatesCachedUnitModel;
    [Test]
    procedure CompilerProfileChangeInvalidatesCachedUnitModel;
    [Test]
    procedure ToolchainOptionsChangeInvalidatesSqliteCachedUnitModel;
    [Test]
    procedure CompilerProfileSeedsIntrinsicRows;
    [Test]
    procedure CompilerProfileLoadsCachedRtlSourceModels;
    [Test]
    procedure CompilerProfileDiscoversScopedRtlUnitsFromSourceRoot;
    [Test]
    procedure CompilerProfileIndexesRecursiveRtlSourceLookup;
    [Test]
    procedure CompilerProfileRecursiveRtlSourceLookupPreservesOrder;
    [Test]
    procedure CompilerProfileRtlSourceRootBuildsSharedUnitModels;
    [Test]
    procedure CompilerProfileResolvesRtlSourceRootFromRsVars;
    [Test]
    procedure ParserVersionChangeInvalidatesCachedUnitModel;
    [Test]
    [TestCase('Before inline extraction', '4')]
    [TestCase('Before lexical directive handling', '5')]
    [TestCase('Before selector literal preservation', '6')]
    [TestCase('Before initialized variable types', '8')]
    [TestCase('Before program body references', '9')]
    [TestCase('Before LF body coordinates', '10')]
    [TestCase('Before owned WITH body ends', '11')]
    [TestCase('Before multiline routine headers', '12')]
    [TestCase('Before assignment exclusion', '13')]
    [TestCase('Before class declaration scope exclusion', '14')]
    [TestCase('Before packed record fields', '15')]
    [TestCase('Before multiline record fields', '16')]
    [TestCase('Before split variant field recovery', '17')]
    [TestCase('Before indented alias coordinates', '18')]
    [TestCase('Before exclusive routine scope positions', '19')]
    procedure DefaultParserInvalidatesObsoleteModels(const aVersion: string);
    [Test]
    procedure ModelVersionChangeInvalidatesCachedUnitModel;
    [Test]
    procedure CacheAccessResultReportsPerCallHitAndIdentity;
    [Test]
    procedure SqliteCacheHitRestoresSourceSections;
    [Test]
    procedure SqliteCacheHitRestoresOriginalRanges;
    [Test]
    procedure SqliteCacheHitRestoresReferenceRanges;
    [Test]
    procedure SymbolMapCompatibleIdentityReusesSharedSourceAcrossProjects;
    [Test]
    procedure SymbolMapCompatibleIdentitySeparatesSearchAndConfiguration;
    [Test]
    procedure CanonicalSemanticIdentityNormalizesPathVariantsAndIgnoresStorageRoot;
    [Test]
    procedure SymbolMapCompatibleIdentitySeparatesExtractionOptions;
    [Test]
    procedure CompilerProfileExposesDakIntrinsicSeedFacts;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  DelphiSemantics.Resolve, Test.Support;

var
  GCacheTempRoot: string;

function CacheTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GCacheTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}', '',
      [rfReplaceAll]);
    GCacheTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp',
      'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GCacheTempRoot);
  Result := GCacheTempRoot;
end;

procedure TCacheTests.AssertIndexedProfileNameKind(
  const aProfile: TDelphiSemanticCompilerProfile; const aName, aKind: string);
var
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
  lSourceModel: TDelphiSemanticUnitModel;
begin
  lSourceModel := Default(TDelphiSemanticUnitModel);
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.ConformanceLevel := 3;
  lContext.IntrinsicSymbols := aProfile.IntrinsicSymbols;
  lContext.IndexedUnitModels := aProfile.RtlSourceUnitModels;

  lResult := TDelphiSemanticResolver.ResolveName(lSourceModel, lContext, aName);

  Assert.IsTrue(lResult.Found, 'Expected "' + aName + '" to resolve.');
  Assert.AreEqual(aKind, lResult.Kind);
end;

function TCacheTests.FindDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string;
  out aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) then
    begin
      aDeclaration := lDeclaration;
      Exit(True);
    end;

  aDeclaration := Default(TDelphiSemanticDeclaration);
  Result := False;
end;

function TCacheTests.FindLocal(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
  aName: string; out aLocal: TDelphiSemanticLocal): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) then
    begin
      aLocal := lLocal;
      Exit(True);
    end;

  aLocal := Default(TDelphiSemanticLocal);
  Result := False;
end;

function TCacheTests.FindMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName,
  aName: string; out aMember: TDelphiSemanticMember): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
    begin
      aMember := lMember;
      Exit(True);
    end;

  aMember := Default(TDelphiSemanticMember);
  Result := False;
end;

function TCacheTests.FindReferenceAtOffset(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aOffset: Integer; out aReference: TDelphiSemanticReference):
  Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Offset = aOffset) then
    begin
      aReference := lReference;
      Exit(True);
    end;

  aReference := Default(TDelphiSemanticReference);
  Result := False;
end;

function TCacheTests.FindRoutine(const aModel: TDelphiSemanticUnitModel; const aName,
  aOwnerName: string; out aRoutine: TDelphiSemanticRoutine): Boolean;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) and SameText(lRoutine.OwnerName, aOwnerName) then
    begin
      aRoutine := lRoutine;
      Exit(True);
    end;

  aRoutine := Default(TDelphiSemanticRoutine);
  Result := False;
end;

function TCacheTests.HasDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName: string): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) then
      Exit(True);

  Result := False;
end;

function TCacheTests.TempPath(const aName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([CacheTempRoot, aName]));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
end;

procedure TCacheTests.TempPathUsesPerRunRoot;
var
  lFixedRoot: string;
  lPath: string;
begin
  lFixedRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp']));
  lPath := TempPath('temp-root-guard.sqlite3');

  Assert.IsFalse(SameText(TPath.GetDirectoryName(lPath), lFixedRoot),
    'Cache tests must use a per-run temp root, not the fixed binary-local cache-temp directory.');
  Assert.IsTrue(Pos(GetCurrentProcessId.ToString, lPath) > 0,
    'Cache temp path should include the current process id. Actual: ' + lPath);
end;

procedure TCacheTests.DefaultOptionsUseInMemoryCache;
var
  lCache: TDelphiSemanticUnitCache;
  lOptions: TDelphiSemanticCacheOptions;
begin
  lOptions := Default(TDelphiSemanticCacheOptions);

  lCache := TDelphiSemanticUnitCache.Create(lOptions);
  try
    Assert.AreEqual('', lOptions.SqliteCacheFileName);
    Assert.AreEqual('in-memory', lCache.Metrics.CacheKind);
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.InMemoryMetricsExposeEmptyCacheFileName;
var
  lCache: TDelphiSemanticUnitCache;
  lOptions: TDelphiSemanticCacheOptions;
begin
  lOptions := Default(TDelphiSemanticCacheOptions);

  lCache := TDelphiSemanticUnitCache.Create(lOptions);
  try
    Assert.AreEqual('', lCache.Metrics.CacheFileName);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SharedUnitCacheRejectsReentrantAccess;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFailedFast: Boolean;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('SharedCacheGuardUnit.pas');
  TFile.WriteAllText(lPath, 'unit SharedCacheGuardUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lFailedFast := False;
    try
      lCache.GetOrBuildUnitModelWithStatus(lModelOptions,
        function(const aBuildOptions: TDelphiSemanticModelOptions): TDelphiSemanticUnitModel
        begin
          Result := lCache.GetOrExtractUnitModel(aBuildOptions);
        end);
    except
      on E: Exception do
      begin
        lFailedFast := True;
        Assert.IsTrue(Pos('single-threaded', E.Message) > 0,
          'Expected single-threaded cache contract message. Actual: ' + E.Message);
      end;
    end;
    Assert.IsTrue(lFailedFast,
      'A shared unit cache instance must fail fast when one access re-enters another.');
    Assert.AreEqual(0, lCache.Metrics.CacheHits);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
    lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CacheIdentityIncludesLexicalOwnershipModelShape;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lIdentity: TDelphiSemanticUnitCacheIdentity;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('SourceProvenanceSchemaUnit.pas');
  TFile.WriteAllText(lPath, 'unit SourceProvenanceSchemaUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lIdentity := lCache.BuildIdentity(lModelOptions);

    Assert.AreEqual('9', lIdentity.SchemaVersion,
      'Lexical ownership fields changed the persisted unit-model shape.');
    Assert.AreEqual('DelphiSemantics.Model.Parser.36', lIdentity.ParserVersion,
      'Facts attributed to include files require fresh facts.');
    Assert.AreEqual(lIdentity.ParserVersion,
      TDelphiSemanticCacheIdentityBuilder.ModelParserVersion,
      'Dependent caches chain to the unit-model parser version.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.UnitCacheIdentityBuilderReusesSingleSourceLoad;
const
  cLoadCall = 'TDelphiSemanticSourceLoader.LoadFile';
var
  lBody: string;
  lEndIndex: Integer;
  lLoadCount: Integer;
  lPreprocessCount: Integer;
  lSource: string;
  lStartIndex: Integer;
begin
  lSource := ReadRepoSource('src\DelphiSemantics.Cache.pas');
  lStartIndex := Pos('function BuildLoadedUnitIdentity', lSource);
  Assert.IsTrue(lStartIndex > 0,
    'Expected one loaded-source unit identity builder.');
  lEndIndex := Pos('procedure TDelphiSemanticUnitCache.AddDiagnostic', lSource);
  Assert.IsTrue(lEndIndex > lStartIndex,
    'Expected unit identity builder to stay before cache methods.');
  lBody := Copy(lSource, lStartIndex, lEndIndex - lStartIndex);

  lLoadCount := (Length(lBody) - Length(StringReplace(lBody, cLoadCall, '',
    [rfReplaceAll]))) div Length(cLoadCall);
  lPreprocessCount := (Length(lBody) - Length(StringReplace(lBody,
    'BuildPreprocessResult', '', [rfReplaceAll]))) div Length('BuildPreprocessResult');

  Assert.AreEqual(1, lLoadCount,
    'Unit cache identity should load the source once and reuse that result.');
  Assert.AreEqual(1, lPreprocessCount,
    'Unit cache identity should preprocess once and reuse the include graph.');
  Assert.IsFalse(ContainsText(lBody, 'BuildCacheKey('),
    'Unit cache identity should derive UnitCacheKey from the one identity record.');
  Assert.IsFalse(ContainsText(lBody, 'HashFileIfExists('),
    'Unit cache identity should reuse the content hash from the loaded source result.');
end;

procedure TCacheTests.RepeatedUnchangedUnitHitsInMemoryCache;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('RepeatedHitUnit.pas');
  TFile.WriteAllText(lPath, 'unit RepeatedHitUnit;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;

  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.AreEqual('RepeatedHitUnit', lModel.UnitName);
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual('RepeatedHitUnit', lModel.UnitName);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CacheHitReturnsIndependentUnitModelCopy;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('IndependentCopyUnit.pas');
  TFile.WriteAllText(lPath, 'unit IndependentCopyUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TOriginalCachedType = procedure(aValue: TObject) of object;' + sLineBreak +
    '  THandler = class' + sLineBreak + '  published' + sLineBreak +
    '    procedure Handle(aValue: TObject);' + sLineBreak + '  end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(Length(lModel.Declarations) > 0);
    lModel.Declarations[0].Name := 'TCorruptedCachedType';
    Assert.IsTrue(lModel.Declarations[0].ProcedureSignature.Known);
    lModel.Declarations[0].ProcedureSignature.Parameters[0].TypeName := 'TCorruptedType';
    Assert.AreEqual(1, Integer(Length(lModel.Members)));
    Assert.IsTrue(lModel.Members[0].ProcedureSignature.Known);
    lModel.Members[0].ProcedureSignature.Parameters[0].TypeName := 'TCorruptedMemberType';

    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TOriginalCachedType'));
    Assert.IsFalse(HasDeclaration(lModel, 'TCorruptedCachedType'));
    Assert.AreEqual('TObject', lModel.Declarations[0].ProcedureSignature.Parameters[0].TypeName,
      'Nested signature arrays must be independent of cached storage');
    Assert.AreEqual('TObject', lModel.Members[0].ProcedureSignature.Parameters[0].TypeName,
      'Member signature arrays must be independent of cached storage');
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CacheAccessResultReportsPerCallHitAndIdentity;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFirst: TDelphiSemanticUnitCacheAccessResult;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSecond: TDelphiSemanticUnitCacheAccessResult;
begin
  lPath := TempPath('AccessResultUnit.pas');
  TFile.WriteAllText(lPath, 'unit AccessResultUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lFirst := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
    lSecond := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);

    Assert.IsFalse(lFirst.CacheHit);
    Assert.IsTrue(lSecond.CacheHit);
    Assert.AreEqual('AccessResultUnit', lSecond.Model.UnitName);
    Assert.IsNotEmpty(lSecond.Identity.UnitCacheKey);
    Assert.AreEqual(TDelphiSemanticCacheIdentityBuilder.CanonicalPath(lPath),
      lSecond.Identity.SourceFileName);
    Assert.IsNotEmpty(lSecond.Identity.FileHash);
    Assert.IsNotEmpty(lSecond.Identity.ContextHash);
    Assert.IsNotEmpty(lSecond.Identity.DefinesHash);
    Assert.IsNotEmpty(lSecond.Identity.SearchPathHash);
    Assert.IsNotEmpty(lSecond.Identity.ExtractionOptionsHash);
    Assert.AreEqual('default', lSecond.Identity.CompilerProfileName);
    Assert.IsNotEmpty(lSecond.Identity.ModelVersion);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.ReferenceExtractionOptionInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFull: TDelphiSemanticUnitCacheAccessResult;
  lFullOptions: TDelphiSemanticModelOptions;
  lLean: TDelphiSemanticUnitCacheAccessResult;
  lLeanOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('ReferenceExtractionOptionUnit.pas');
  TFile.WriteAllText(lPath, 'unit ReferenceExtractionOptionUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TReferenceExtractionBase = record' + sLineBreak + '    Value: Integer;' +
    sLineBreak + '  end;' + sLineBreak +
    '  TReferenceExtractionAlias = TReferenceExtractionBase;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure UseAlias;' + sLineBreak + 'var' +
    sLineBreak + '  lValue: TReferenceExtractionAlias;' + sLineBreak + 'begin' +
    sLineBreak + '  lValue.Value := 1;' + sLineBreak + 'end;' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lFullOptions := Default(TDelphiSemanticModelOptions);
  lFullOptions.SourceFileName := lPath;
  lFullOptions.ProjectContextApplied := True;
  lLeanOptions := lFullOptions;
  lLeanOptions.SkipReferenceExtraction := True;

  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lFull := lCache.GetOrExtractUnitModelWithStatus(lFullOptions);
    lLean := lCache.GetOrExtractUnitModelWithStatus(lLeanOptions);

    Assert.IsFalse(lFull.CacheHit);
    Assert.IsFalse(lLean.CacheHit,
      'Changing reference extraction must not reuse a full-reference cache entry.');
    Assert.IsTrue(Length(lFull.Model.References) > 0);
    Assert.AreEqual(0, Integer(Length(lLean.Model.References)));
    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.WritableTypedConstantsOptionInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lDisabled: TDelphiSemanticUnitCacheAccessResult;
  lDisabledOptions: TDelphiSemanticModelOptions;
  lEnabled: TDelphiSemanticUnitCacheAccessResult;
  lEnabledOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('WritableTypedConstantsOptionUnit.pas');
  TFile.WriteAllText(lPath, 'unit WritableTypedConstantsOptionUnit;' + sLineBreak +
    'interface' + sLineBreak + 'const' + sLineBreak + '  GValue: Integer = 1;' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lDisabledOptions := Default(TDelphiSemanticModelOptions);
  lDisabledOptions.SourceFileName := lPath;
  lDisabledOptions.ProjectContextApplied := True;
  lEnabledOptions := lDisabledOptions;
  lEnabledOptions.WritableTypedConstants := True;

  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lDisabled := lCache.GetOrExtractUnitModelWithStatus(lDisabledOptions);
    lEnabled := lCache.GetOrExtractUnitModelWithStatus(lEnabledOptions);

    Assert.IsFalse(lDisabled.CacheHit);
    Assert.IsFalse(lEnabled.CacheHit,
      'Changing writable typed constants must not reuse an incompatible model.');
    Assert.AreNotEqual(lDisabled.Identity.ExtractionOptionsHash,
      lEnabled.Identity.ExtractionOptionsHash);
    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SqliteCacheHitRestoresSourceSections;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFirst: TDelphiSemanticUnitCacheAccessResult;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSecond: TDelphiSemanticUnitCacheAccessResult;
  lSource: string;
begin
  lPath := TempPath('SourceSectionsSqliteUnit.pas');
  lSource := 'unit SourceSectionsSqliteUnit;' + sLineBreak + 'interface' + sLineBreak +
    'const' + sLineBreak + '  FakeImplementation = ''implementation'';' + sLineBreak +
    '{ implementation in a comment }' + sLineBreak + 'implementation' + sLineBreak +
    'initialization' + sLineBreak + 'finalization' + sLineBreak + 'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('source-sections-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lFirst := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lSecond := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);

    Assert.IsFalse(lFirst.CacheHit);
    Assert.IsTrue(lSecond.CacheHit);
    Assert.AreEqual(Pos('interface', lSource), lSecond.Model.SourceSections.InterfaceOffset);
    Assert.AreEqual(PosEx('implementation', lSource, Pos('{ implementation', lSource) +
      Length('{ implementation in a comment }')),
      lSecond.Model.SourceSections.ImplementationOffset);
    Assert.AreEqual(Pos('initialization', lSource), lSecond.Model.SourceSections.InitializationOffset);
    Assert.AreEqual(Pos('finalization', lSource), lSecond.Model.SourceSections.FinalizationOffset);
    Assert.AreEqual('utf-8', lSecond.Model.EncodingName);
    Assert.AreEqual('crlf', lSecond.Model.LineEndingName);
    Assert.AreEqual(sLineBreak, lSecond.Model.LineBreak);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SqliteCacheHitRestoresOriginalRanges;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRoutine: TDelphiSemanticRoutine;
  lSecond: TDelphiSemanticUnitCacheAccessResult;
  lSource: string;
begin
  lPath := TempPath('OriginalRangesSqliteUnit.pas');
  lSource := 'unit OriginalRangesSqliteUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TCacheRange = class' + sLineBreak +
    '  private' + sLineBreak + '    FRange: Integer;' + sLineBreak + '  end;' +
    sLineBreak + 'implementation' + sLineBreak + 'procedure TCacheRange.Run;' +
    sLineBreak + 'var' + sLineBreak + '  lRange: Integer;' + sLineBreak + 'begin' +
    sLineBreak + '  lRange := FRange;' + sLineBreak + 'end;' + sLineBreak + 'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('source-range-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lSecond := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);

    Assert.IsTrue(lSecond.CacheHit);
    Assert.IsTrue(FindDeclaration(lSecond.Model, 'TCacheRange', lDeclaration));
    Assert.AreEqual('TCacheRange', Copy(lSource, lDeclaration.Offset,
      lDeclaration.EndOffset - lDeclaration.Offset));
    Assert.IsTrue(FindMember(lSecond.Model, 'TCacheRange', 'FRange', lMember));
    Assert.AreEqual('FRange', Copy(lSource, lMember.Offset, lMember.EndOffset -
      lMember.Offset));
    Assert.IsTrue(FindRoutine(lSecond.Model, 'Run', 'TCacheRange', lRoutine));
    Assert.AreEqual('Run', Copy(lSource, lRoutine.Offset, lRoutine.EndOffset -
      lRoutine.Offset));
    Assert.IsTrue(FindLocal(lSecond.Model, 'TCacheRange.Run', 'lRange', lLocal));
    Assert.AreEqual('lRange', Copy(lSource, lLocal.Offset, lLocal.EndOffset -
      lLocal.Offset));
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SqliteCacheHitRestoresReferenceRanges;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticReference;
  lSecond: TDelphiSemanticUnitCacheAccessResult;
  lSource: string;
begin
  lPath := TempPath('ReferenceRangesSqliteUnit.pas');
  lSource := 'unit ReferenceRangesSqliteUnit;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TTarget = record end;' + sLineBreak +
    '  TAlias = TTarget;' + sLineBreak + 'var' + sLineBreak + '  GRef: TAlias;' +
    sLineBreak + 'implementation' + sLineBreak + 'procedure Touch;' + sLineBreak +
    'begin' + sLineBreak + '  GRef := GRef;' + sLineBreak + 'end;' + sLineBreak + 'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('reference-range-cache.sqlite3');
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
  finally
    lCache.Free;
  end;

  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lSecond := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);

    Assert.IsTrue(lSecond.CacheHit);
    Assert.IsTrue(FindReferenceAtOffset(lSecond.Model, 'TTarget',
      Pos('TAlias = TTarget', lSource) + Length('TAlias = '), lReference));
    Assert.AreEqual('TTarget', Copy(lSource, lReference.Offset, lReference.EndOffset -
      lReference.Offset));
    Assert.IsTrue(FindReferenceAtOffset(lSecond.Model, 'GRef', Pos('GRef :=', lSource),
      lReference));
    Assert.AreEqual('GRef', Copy(lSource, lReference.Offset, lReference.EndOffset -
      lReference.Offset));
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SourceChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('SourceChangeUnit.pas');
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    TFile.WriteAllText(lPath, 'unit SourceChangeUnit;' + sLineBreak + 'interface' + sLineBreak +
      'type' + sLineBreak + '  TFirstCacheType = class end;' + sLineBreak +
      'implementation' + sLineBreak +
      'end.', TEncoding.UTF8);
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, 'TFirstCacheType'));

    TFile.WriteAllText(lPath, 'unit SourceChangeUnit;' + sLineBreak + 'interface' + sLineBreak +
      'type' + sLineBreak + '  TSecondCacheType = class end;' + sLineBreak +
      'implementation' + sLineBreak +
      'end.', TEncoding.UTF8);
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSecondCacheType'));
    Assert.IsFalse(HasDeclaration(lModel, 'TFirstCacheType'));
    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SourceTimestampChangeReusesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFirst: TDelphiSemanticUnitCacheAccessResult;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSecond: TDelphiSemanticUnitCacheAccessResult;
begin
  lPath := TempPath('SourceTimestampChangeUnit.pas');
  TFile.WriteAllText(lPath, 'unit SourceTimestampChangeUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'type' + sLineBreak + '  TTimestampCacheType = class end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lFirst := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
    TFile.SetLastWriteTimeUtc(lPath, TFile.GetLastWriteTimeUtc(lPath) + EncodeTime(0, 0, 5, 0));
    lSecond := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);

    Assert.IsFalse(lFirst.CacheHit);
    Assert.IsTrue(lSecond.CacheHit);
    Assert.AreEqual(lFirst.Identity.UnitCacheKey, lSecond.Identity.UnitCacheKey);
    Assert.AreNotEqual(lFirst.Identity.FileTimestampUtc, lSecond.Identity.FileTimestampUtc);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CompilerProfileExposesDakIntrinsicSeedFacts;
var
  lFoundString: Boolean;
  lFoundSystem: Boolean;
  lFoundTypeInfo: Boolean;
  lIntrinsic: TDelphiSemanticIntrinsicSymbol;
  lProfile: TDelphiSemanticCompilerProfile;
begin
  lFoundString := False;
  lFoundSystem := False;
  lFoundTypeInfo := False;

  lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTarget('Delphi-12-Win32-Debug',
    '23.0', 'Win32', 'C:\rtl\source');

  Assert.AreEqual('Delphi-12-Win32-Debug', lProfile.Name);
  Assert.AreEqual('23.0', lProfile.DelphiVersion);
  Assert.AreEqual('Win32', lProfile.Platform);
  Assert.AreEqual('delphi-intrinsics-v2', lProfile.IntrinsicSeedVersion);
  Assert.IsNotEmpty(lProfile.ProfileKey);
  Assert.IsTrue(Length(lProfile.IntrinsicSymbols) >= 47);

  for lIntrinsic in lProfile.IntrinsicSymbols do
  begin
    if SameText(lIntrinsic.Name, 'string') and SameText(lIntrinsic.Kind, 'intrinsic-type') then
      lFoundString := True
    else if SameText(lIntrinsic.Name, 'System') and SameText(lIntrinsic.Kind, 'intrinsic-unit') then
      lFoundSystem := True
    else if SameText(lIntrinsic.Name, 'TypeInfo') and SameText(lIntrinsic.Signature,
      'function TypeInfo(TypeIdentifier): Pointer') then
      lFoundTypeInfo := True;
  end;

  Assert.IsTrue(lFoundString);
  Assert.IsTrue(lFoundSystem);
  Assert.IsTrue(lFoundTypeInfo);
end;

procedure TCacheTests.SemanticContextChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('ContextChangeUnit.pas');
  TFile.WriteAllText(lPath, 'unit ContextChangeUnit;' + sLineBreak + 'interface' + sLineBreak +
    '{$IFDEF CACHE_ACTIVE}' + sLineBreak + 'type' + sLineBreak +
    '  TActiveCacheType = class end;' + sLineBreak + '{$ELSE}' + sLineBreak + 'type' +
    sLineBreak + '  TInactiveCacheType = class end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, 'TInactiveCacheType'));

    lModelOptions.Defines := ['CACHE_ACTIVE'];
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TActiveCacheType'));
    Assert.IsFalse(HasDeclaration(lModel, 'TInactiveCacheType'));
    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.EquivalentDefineOrderReusesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('EquivalentDefinesUnit.pas');
  TFile.WriteAllText(lPath, 'unit EquivalentDefinesUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lModelOptions.Defines := ['PROFILE_A', 'PROFILE_B'];
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
    lModelOptions.Defines := ['PROFILE_B', 'PROFILE_A'];
    lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.CacheHits);
    Assert.AreEqual(0, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SearchPathOrderChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFirstDir: string;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSecondDir: string;
begin
  lPath := TempPath('SearchPathOrderUnit.pas');
  lFirstDir := TPath.GetFullPath(CombinePath([CacheTempRoot, 'search-a']));
  lSecondDir := TPath.GetFullPath(CombinePath([CacheTempRoot, 'search-b']));
  TDirectory.CreateDirectory(lFirstDir);
  TDirectory.CreateDirectory(lSecondDir);
  TFile.WriteAllText(lPath, 'unit SearchPathOrderUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lModelOptions.SearchPaths := [lFirstDir, lSecondDir];
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
    lModelOptions.SearchPaths := [lSecondDir, lFirstDir];
    lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.IncludeChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModel: TDelphiSemanticUnitModel;
  lModelOptions: TDelphiSemanticModelOptions;
  lRoot: string;
  lSourceFileName: string;
begin
  lRoot := TPath.GetDirectoryName(TempPath('IncludeChangeUnit.pas'));
  lSourceFileName := TPath.Combine(lRoot, 'IncludeChangeUnit.pas');
  TFile.WriteAllText(TPath.Combine(lRoot, 'CacheInclude.inc'),
    'type' + sLineBreak + '  TFirstIncludeType = class end;', TEncoding.UTF8);
  TFile.WriteAllText(lSourceFileName, 'unit IncludeChangeUnit;' + sLineBreak + 'interface' +
    sLineBreak + '{$I CacheInclude.inc}' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lSourceFileName;
  lModelOptions.SearchPaths := [lRoot];
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);
    Assert.IsTrue(HasDeclaration(lModel, 'TFirstIncludeType'));

    TFile.WriteAllText(TPath.Combine(lRoot, 'CacheInclude.inc'),
      'type' + sLineBreak + '  TSecondIncludeType = class end;', TEncoding.UTF8);
    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TSecondIncludeType'));
    Assert.IsFalse(HasDeclaration(lModel, 'TFirstIncludeType'));
    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.SymbolMapCompatibleIdentityReusesSharedSourceAcrossProjects;
var
  lContextA: TDelphiSemanticCacheIdentityContext;
  lContextB: TDelphiSemanticCacheIdentityContext;
  lFirst: TDelphiSemanticUnitCacheIdentity;
  lPathA: string;
  lPathB: string;
  lSecond: TDelphiSemanticUnitCacheIdentity;
begin
  lPathA := TempPath('SharedProjectA\SharedUnit.pas');
  lPathB := TempPath('SharedProjectB\SharedUnit.pas');
  TFile.WriteAllText(lPathA, 'unit SharedUnit;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lPathB));
  TFile.Copy(lPathA, lPathB, True);

  lContextA := Default(TDelphiSemanticCacheIdentityContext);
  lContextA.DelphiVersion := '23.0';
  lContextA.Platform := 'Win32';
  lContextA.Defines := ['DEBUG', 'TRACE'];
  lContextA.UnitScopes := ['System', 'Vcl'];
  lContextA.UnitAliases := ['WinTypes=Windows'];
  lContextB := lContextA;
  lContextB.Defines := ['TRACE', 'DEBUG'];

  lFirst := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPathA, lContextA);
  lSecond := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPathB, lContextB);

  Assert.AreEqual(lFirst.FileHash, lSecond.FileHash);
  Assert.AreEqual(lFirst.ContextHash, lSecond.ContextHash);
  Assert.AreEqual(lFirst.UnitCacheKey, lSecond.UnitCacheKey);

  lContextB.Defines := ['RELEASE'];
  lSecond := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPathB, lContextB);

  Assert.AreNotEqual(lFirst.ContextHash, lSecond.ContextHash);
  Assert.AreNotEqual(lFirst.UnitCacheKey, lSecond.UnitCacheKey);
end;

procedure TCacheTests.SymbolMapCompatibleIdentitySeparatesSearchAndConfiguration;
var
  lContextA: TDelphiSemanticCacheIdentityContext;
  lContextB: TDelphiSemanticCacheIdentityContext;
  lConfigOnly: TDelphiSemanticUnitCacheIdentity;
  lFirst: TDelphiSemanticUnitCacheIdentity;
  lPathA: string;
  lPathB: string;
  lSearchOnly: TDelphiSemanticUnitCacheIdentity;
  lSecond: TDelphiSemanticUnitCacheIdentity;
begin
  lPathA := TempPath('SharedContextA\ContextUnit.pas');
  lPathB := TempPath('SharedContextB\ContextUnit.pas');
  TFile.WriteAllText(lPathA, 'unit ContextUnit;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lPathB));
  TFile.Copy(lPathA, lPathB, True);

  lContextA := Default(TDelphiSemanticCacheIdentityContext);
  lContextA.DelphiVersion := '23.0';
  lContextA.Platform := 'Win32';
  lContextA.Configuration := 'Debug';
  lContextA.SearchPaths := ['C:\project\src', 'C:\project\lib'];
  lContextB := lContextA;
  lContextB.Configuration := 'Release';
  lContextB.SearchPaths := ['C:\project\lib', 'C:\project\src'];

  lFirst := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPathA, lContextA);
  lSecond := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPathB, lContextB);

  Assert.AreEqual(lFirst.FileHash, lSecond.FileHash);
  Assert.AreNotEqual(lFirst.SearchPathHash, lSecond.SearchPathHash);
  Assert.AreNotEqual(lFirst.ContextHash, lSecond.ContextHash);
  Assert.AreNotEqual(lFirst.UnitCacheKey, lSecond.UnitCacheKey);

  lContextB := lContextA;
  lContextB.SearchPaths := ['C:\project\lib', 'C:\project\src'];
  lSearchOnly := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPathB, lContextB);
  Assert.AreNotEqual(lFirst.SearchPathHash, lSearchOnly.SearchPathHash);
  Assert.AreNotEqual(lFirst.UnitCacheKey, lSearchOnly.UnitCacheKey);

  lContextB := lContextA;
  lContextB.Configuration := 'Release';
  lConfigOnly := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPathB, lContextB);
  Assert.AreEqual(lFirst.SearchPathHash, lConfigOnly.SearchPathHash);
  Assert.AreNotEqual(lFirst.ContextHash, lConfigOnly.ContextHash);
  Assert.AreNotEqual(lFirst.UnitCacheKey, lConfigOnly.UnitCacheKey);
end;

procedure TCacheTests.CanonicalSemanticIdentityNormalizesPathVariantsAndIgnoresStorageRoot;
var
  lContextA: TDelphiSemanticCacheIdentityContext;
  lContextB: TDelphiSemanticCacheIdentityContext;
  lFirstProject: TDelphiSemanticProjectCacheIdentity;
  lFirstUnit: TDelphiSemanticUnitCacheIdentity;
  lProjectFileName: string;
  lProjectVariant: string;
  lSearchPath: string;
  lSearchVariant: string;
  lSecondProject: TDelphiSemanticProjectCacheIdentity;
  lSecondUnit: TDelphiSemanticUnitCacheIdentity;
  lSourceFileName: string;
  lSourceVariant: string;
begin
  lProjectFileName := TempPath('CanonicalIdentity\Project\IdentityProject.dproj');
  lSearchPath := TempPath('CanonicalIdentity\Source');
  lSourceFileName := TPath.Combine(lSearchPath, 'IdentityUnit.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lProjectFileName));
  TDirectory.CreateDirectory(lSearchPath);
  TFile.WriteAllText(lProjectFileName, '<Project />', TEncoding.UTF8);
  TFile.WriteAllText(lSourceFileName, 'unit IdentityUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lProjectVariant := StringReplace(UpperCase(CombinePath([TPath.GetDirectoryName(
    lProjectFileName), '..', 'Project', 'IdentityProject.dproj'])), '\', '/', [rfReplaceAll]);
  lSearchVariant := StringReplace(UpperCase(CombinePath([lSearchPath, '..', 'Source'])),
    '\', '/', [rfReplaceAll]);
  lSourceVariant := StringReplace(UpperCase(CombinePath([lSearchPath, '..', 'Source',
    'IdentityUnit.pas'])), '\', '/', [rfReplaceAll]);

  lContextA := Default(TDelphiSemanticCacheIdentityContext);
  lContextA.ProjectPath := lProjectFileName;
  lContextA.DelphiVersion := '23.0';
  lContextA.Platform := 'Win32';
  lContextA.Configuration := 'Debug';
  lContextA.SearchPaths := [lSearchPath];
  lContextA.Defines := ['TRACE', 'DEBUG'];
  lContextA.UnitScopes := ['System', 'Vcl'];
  lContextA.UnitAliases := ['WinTypes=Windows'];
  lContextA.CentralCacheRoot := TempPath('CanonicalIdentity\cache-a');
  lContextB := lContextA;
  lContextB.ProjectPath := lProjectVariant;
  lContextB.SearchPaths := [lSearchVariant];
  lContextB.Defines := ['debug', 'trace'];
  lContextB.UnitScopes := ['system', 'vcl'];
  lContextB.UnitAliases := ['wintypes=windows'];
  lContextB.CentralCacheRoot := TempPath('CanonicalIdentity\cache-b');

  lFirstProject := TDelphiSemanticCacheIdentityBuilder.BuildProjectIdentity(lContextA);
  lSecondProject := TDelphiSemanticCacheIdentityBuilder.BuildProjectIdentity(lContextB);
  lFirstUnit := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lSourceFileName,
    lContextA);
  lSecondUnit := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lSourceVariant,
    lContextB);

  Assert.AreEqual(lFirstProject.ProjectKey, lSecondProject.ProjectKey);
  Assert.AreEqual(lFirstProject.SearchPathHash, lSecondProject.SearchPathHash);
  Assert.AreEqual(lFirstProject.DefinesHash, lSecondProject.DefinesHash);
  Assert.AreEqual(lFirstProject.UnitScopeHash, lSecondProject.UnitScopeHash);
  Assert.AreEqual(lFirstProject.AliasHash, lSecondProject.AliasHash);
  Assert.AreEqual(lFirstUnit.ContextHash, lSecondUnit.ContextHash);
  Assert.AreEqual(lFirstUnit.SearchPathHash, lSecondUnit.SearchPathHash);
  Assert.AreEqual(lFirstUnit.UnitCacheKey, lSecondUnit.UnitCacheKey);

  lContextB.Platform := 'Win64';
  lSecondProject := TDelphiSemanticCacheIdentityBuilder.BuildProjectIdentity(lContextB);
  lSecondUnit := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lSourceVariant,
    lContextB);

  Assert.AreNotEqual(lFirstProject.ProjectKey, lSecondProject.ProjectKey);
  Assert.AreNotEqual(lFirstUnit.ContextHash, lSecondUnit.ContextHash);
  Assert.AreNotEqual(lFirstUnit.UnitCacheKey, lSecondUnit.UnitCacheKey);
end;

procedure TCacheTests.SymbolMapCompatibleIdentitySeparatesExtractionOptions;
var
  lContextA: TDelphiSemanticCacheIdentityContext;
  lContextB: TDelphiSemanticCacheIdentityContext;
  lFirst: TDelphiSemanticUnitCacheIdentity;
  lPath: string;
  lSecond: TDelphiSemanticUnitCacheIdentity;
begin
  lPath := TempPath('ExtractionOptions\ContextUnit.pas');
  TFile.WriteAllText(lPath, 'unit ContextUnit;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lContextA := Default(TDelphiSemanticCacheIdentityContext);
  lContextA.DelphiVersion := '23.0';
  lContextA.Platform := 'Win32';
  lContextA.Configuration := 'Debug';
  lContextA.ExtractionOptionsHash := 'options-a';
  lContextB := lContextA;
  lContextB.ExtractionOptionsHash := 'options-b';

  lFirst := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPath, lContextA);
  lSecond := TDelphiSemanticCacheIdentityBuilder.BuildUnitIdentity(lPath, lContextB);

  Assert.AreNotEqual(lFirst.ExtractionOptionsHash, lSecond.ExtractionOptionsHash);
  Assert.AreNotEqual(lFirst.UnitCacheKey, lSecond.UnitCacheKey);
end;

procedure TCacheTests.CompilerProfileChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('CompilerProfileUnit.pas');
  TFile.WriteAllText(lPath, 'unit CompilerProfileUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Win32-Debug';
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
    lCache.CompilerProfileName := 'Delphi-12-Win64-Release';
    lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.ToolchainOptionsChangeInvalidatesSqliteCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lFirst: TDelphiSemanticUnitCacheAccessResult;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSecond: TDelphiSemanticUnitCacheAccessResult;
begin
  lPath := TempPath('ToolchainChangeUnit.pas');
  TFile.WriteAllText(lPath, 'unit ToolchainChangeUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('toolchain-change-cache.sqlite3');
  lCacheOptions.CompilerProfileName := 'Delphi-12-Win32-Debug';
  lCacheOptions.DelphiVersion := '23.0';
  lCacheOptions.Configuration := 'Debug';
  lCacheOptions.Platform := 'Win32';
  if TFile.Exists(lCacheOptions.SqliteCacheFileName) then
    TFile.Delete(lCacheOptions.SqliteCacheFileName);
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lFirst := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
  finally
    lCache.Free;
  end;

  lCacheOptions.Configuration := 'Release';
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lSecond := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);

    Assert.IsFalse(lFirst.CacheHit);
    Assert.IsFalse(lSecond.CacheHit);
    Assert.AreNotEqual(lFirst.Identity.UnitCacheKey, lSecond.Identity.UnitCacheKey);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CompilerProfileSeedsIntrinsicRows;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticResolveResult;
begin
  lProfile := TDelphiSemanticCompilerProfileBuilder.DefaultProfile('Delphi-12-Win32-Debug');
  lModel := Default(TDelphiSemanticUnitModel);
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.ConformanceLevel := 3;
  lContext.IntrinsicSymbols := lProfile.IntrinsicSymbols;

  Assert.AreEqual('Delphi-12-Win32-Debug', lProfile.Name);
  Assert.AreEqual('delphi-intrinsics-v2', lProfile.IntrinsicSeedVersion);
  Assert.IsTrue(Length(lProfile.IntrinsicSymbols) >= 47);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Length');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('intrinsic-routine', lResult.Kind);
  Assert.AreEqual('compiler', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TObject');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('intrinsic-type', lResult.Kind);
  Assert.AreEqual('rtl', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Random');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('intrinsic-routine', lResult.Kind);
  Assert.AreEqual('compiler', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'NativeUInt');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('intrinsic-type', lResult.Kind);
  Assert.AreEqual('compiler', lResult.OwnerName);
end;

procedure TCacheTests.CompilerProfileLoadsCachedRtlSourceModels;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lContext: TDelphiSemanticResolveContext;
  lPath: string;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticResolveResult;
  lSourceModel: TDelphiSemanticUnitModel;
begin
  lPath := TempPath('CachedRtlSourceUnit.pas');
  TFile.WriteAllText(lPath, 'unit CachedRtlSourceUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'type' + sLineBreak + '  TCachedRtlIndexedType = class end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-RTL-Source';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache, [lPath]);
    lSourceModel := Default(TDelphiSemanticUnitModel);
    lContext := Default(TDelphiSemanticResolveContext);
    lContext.ConformanceLevel := 3;
    lContext.IntrinsicSymbols := lProfile.IntrinsicSymbols;
    lContext.IndexedUnitModels := lProfile.RtlSourceUnitModels;

    lResult := TDelphiSemanticResolver.ResolveName(lSourceModel, lContext,
      'TCachedRtlIndexedType');

    Assert.AreEqual('Delphi-12-RTL-Source', lProfile.Name);
    Assert.AreEqual(1, Integer(Length(lProfile.RtlSourceUnitModels)));
    Assert.AreEqual('ast', lProfile.RtlSourceUnitModels[0].ScopeModelStatus,
      'Valid source retains complete syntax facts');
    Assert.IsTrue(lResult.Found);
    Assert.AreEqual('CachedRtlSourceUnit', lResult.OwnerName);
    Assert.AreEqual('type', lResult.Kind);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CompilerProfileDiscoversScopedRtlUnitsFromSourceRoot;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCommonRoot: string;
  lContext: TDelphiSemanticResolveContext;
  lMemberResult: TDelphiSemanticResolveResult;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticResolveResult;
  lRtlRoot: string;
  lSourceModel: TDelphiSemanticUnitModel;
begin
  lRtlRoot := TPath.GetFullPath(CombinePath([CacheTempRoot, 'fake-delphi-source']));
  lCommonRoot := CombinePath([lRtlRoot, 'rtl', 'common']);
  TDirectory.CreateDirectory(lCommonRoot);
  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'System.Math.pas'),
    'unit System.Math;' + sLineBreak + 'interface' + sLineBreak +
    'function Min(const A, B: Integer): Integer;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'System.SysUtils.pas'),
    'unit System.SysUtils;' + sLineBreak + 'interface' + sLineBreak +
    '{$IFDEF MSWINDOWS}' + sLineBreak + 'type' + sLineBreak +
    '  TSearchRec = record' + sLineBreak + '    Attr: Integer;' + sLineBreak +
    '  end;' + sLineBreak + '{$ENDIF}' + sLineBreak + 'type' + sLineBreak +
    '  Exception = class end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'Winapi.Windows.pas'),
    'unit Winapi.Windows;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  THandle = NativeUInt;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-RTL-Discovery';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceRoot(lCache,
      'Delphi-12-RTL-Discovery', '23.0', 'Win32', lRtlRoot, ['Math', 'SysUtils', 'Windows',
      'Classes']);
    lSourceModel := Default(TDelphiSemanticUnitModel);
    lContext := Default(TDelphiSemanticResolveContext);
    lContext.ConformanceLevel := 3;
    lContext.IntrinsicSymbols := lProfile.IntrinsicSymbols;
    lContext.IndexedUnitModels := lProfile.RtlSourceUnitModels;

    lResult := TDelphiSemanticResolver.ResolveName(lSourceModel, lContext, 'Min');

    Assert.AreEqual('Delphi-12-RTL-Discovery', lProfile.Name);
    Assert.AreEqual(lRtlRoot, lProfile.RtlSourceRoot);
    Assert.AreEqual(3, Integer(Length(lProfile.RtlSourceUnitModels)));
    Assert.IsTrue(HasDeclaration(lProfile.RtlSourceUnitModels[1], 'TSearchRec'),
      'Expected Win32 RTL profile extraction to enable MSWINDOWS declarations.');
    Assert.IsTrue(lResult.Found);
    Assert.AreEqual('System.Math', lResult.OwnerName);
    Assert.AreEqual('routine', lResult.Kind);
    Assert.AreEqual(3, lCache.Metrics.CacheMisses,
      'Expected each discovered RTL source model to be written through the cache on first use.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CompilerProfileIndexesRecursiveRtlSourceLookup;
var
  lSourceFileName: string;
  lSourceText: string;
begin
  lSourceFileName := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..',
    '..', 'src', 'DelphiSemantics.CompilerProfile.pas']));
  lSourceText := TFile.ReadAllText(lSourceFileName, TEncoding.UTF8);

  Assert.IsTrue(ContainsText(lSourceText, 'BuildRecursiveRtlSourceFileIndex'),
    'RTL source discovery must build one recursive filename index instead of walking the tree per unit.');
  Assert.IsFalse(ContainsText(lSourceText, 'TDirectory.GetFiles(aRtlSourceRoot, lFileName'),
    'RTL source discovery must not call recursive GetFiles once per candidate filename.');
end;

procedure TCacheTests.CompilerProfileRecursiveRtlSourceLookupPreservesOrder;
var
  lCommonRoot: string;
  lDeepRoot: string;
  lFiles: TArray<string>;
  lRtlRoot: string;
begin
  lRtlRoot := TPath.GetFullPath(CombinePath([CacheTempRoot, 'fake-indexed-rtl-source']));
  if TDirectory.Exists(lRtlRoot) then
    TDirectory.Delete(lRtlRoot, True);

  lCommonRoot := CombinePath([lRtlRoot, 'rtl', 'common']);
  lDeepRoot := CombinePath([lRtlRoot, 'rtl', 'deep']);
  TDirectory.CreateDirectory(lCommonRoot);
  TDirectory.CreateDirectory(lDeepRoot);

  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'System.DirectWins.pas'),
    'unit System.DirectWins; interface implementation end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lDeepRoot, 'System.DirectWins.pas'),
    'unit System.DirectWins; interface implementation end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lDeepRoot, 'Ambiguous.pas'),
    'unit Ambiguous; interface implementation end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lDeepRoot, 'System.Ambiguous.pas'),
    'unit System.Ambiguous; interface implementation end.', TEncoding.UTF8);

  lFiles := TDelphiSemanticCompilerProfileBuilder.DiscoverRtlSourceFiles(lRtlRoot,
    ['DirectWins', 'Ambiguous', 'Ambiguous', 'System.Ambiguous']);

  Assert.AreEqual(3, Integer(Length(lFiles)), 'Expected duplicate requests to be deduplicated.');
  Assert.AreEqual(TPath.GetFullPath(TPath.Combine(lCommonRoot, 'System.DirectWins.pas')),
    lFiles[0], 'Direct search roots must win before recursive fallback.');
  Assert.AreEqual(TPath.GetFullPath(TPath.Combine(lDeepRoot, 'Ambiguous.pas')),
    lFiles[1], 'Unscoped recursive lookup must preserve candidate order before System.*.');
  Assert.AreEqual(TPath.GetFullPath(TPath.Combine(lDeepRoot, 'System.Ambiguous.pas')),
    lFiles[2], 'Scoped recursive lookup must resolve the scoped file name.');
end;

procedure TCacheTests.CompilerProfileRtlSourceRootBuildsSharedUnitModels;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCommonRoot: string;
  lContext: TDelphiSemanticResolveContext;
  lMemberResult: TDelphiSemanticResolveResult;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticResolveResult;
  lRtlRoot: string;
  lSource: string;
  lSourceModel: TDelphiSemanticUnitModel;
begin
  lRtlRoot := TPath.GetFullPath(CombinePath([CacheTempRoot, 'fake-fast-delphi-source']));
  lCommonRoot := CombinePath([lRtlRoot, 'rtl', 'common']);
  TDirectory.CreateDirectory(lCommonRoot);

  lSource := 'unit System.FastRtl;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TFastRtlRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak +
    '  _SECURITY_ATTRIBUTES = record' + sLineBreak + '    nLength: DWORD;' + sLineBreak +
    '    lpSecurityDescriptor: Pointer;' + sLineBreak + '    bInheritHandle: BOOL;' +
    sLineBreak + '  end;' + sLineBreak +
    '  TSecurityAttributes = _SECURITY_ATTRIBUTES;' + sLineBreak +
    '  TFastRtlEnum = (freOne, freTwo);' + sLineBreak +
    '  TFastRtlMultilineEnum = (' + sLineBreak + '    fmOne,' + sLineBreak +
    '    fmTwo' + sLineBreak + '  );' + sLineBreak +
    '  TFastRtlForward = class;' + sLineBreak +
    'const' + sLineBreak + '  FastRtlConst = 42;' + sLineBreak +
    '  FastRtlTypedConst: Integer = 7;' + sLineBreak +
    'resourcestring' + sLineBreak + '  rsFastRtlMessage = ''message'';' + sLineBreak +
    'var' + sLineBreak + '  FastRtlGlobal: Integer;' + sLineBreak +
    'threadvar' + sLineBreak + '  FastRtlThreadGlobal: Integer;' + sLineBreak +
    'function FastMin(const A, B: Integer): Integer;' + sLineBreak +
    'implementation' + sLineBreak;
  lSource := lSource + DupeString(
    'this is intentionally not parsed as Delphi implementation body' + sLineBreak, 5000);
  lSource := lSource + 'end.';
  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'System.FastRtl.pas'), lSource, TEncoding.UTF8);

  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Fast-RTL';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTargetFromRtlSourceRoot(lCache,
      'Delphi-12-Fast-RTL', '23.0', 'Win32', lRtlRoot, ['FastRtl']);
    lSourceModel := Default(TDelphiSemanticUnitModel);
    lContext := Default(TDelphiSemanticResolveContext);
    lContext.ConformanceLevel := 3;
    lContext.IntrinsicSymbols := lProfile.IntrinsicSymbols;
    lContext.IndexedUnitModels := lProfile.RtlSourceUnitModels;

    lResult := TDelphiSemanticResolver.ResolveName(lSourceModel, lContext, 'FastMin');
    lMemberResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lProfile.RtlSourceUnitModels[0],
      'TSecurityAttributes', 'nLength', 3);

    Assert.AreEqual(1, Integer(Length(lProfile.RtlSourceUnitModels)));
    Assert.AreEqual('ast-interface-only', lProfile.RtlSourceUnitModels[0].ScopeModelStatus,
      'A projection recovered from an invalid body must not claim complete syntax facts');
    Assert.IsTrue(HasDeclaration(lProfile.RtlSourceUnitModels[0], 'TFastRtlRecord'),
      'Expected the fast RTL profile to keep interface record declarations.');
    AssertIndexedProfileNameKind(lProfile, 'freOne', 'enum-value');
    AssertIndexedProfileNameKind(lProfile, 'fmOne', 'enum-value');
    AssertIndexedProfileNameKind(lProfile, 'FastRtlConst', 'const');
    AssertIndexedProfileNameKind(lProfile, 'FastRtlTypedConst', 'typed-const');
    AssertIndexedProfileNameKind(lProfile, 'rsFastRtlMessage', 'resourcestring');
    AssertIndexedProfileNameKind(lProfile, 'FastRtlGlobal', 'var');
    AssertIndexedProfileNameKind(lProfile, 'FastRtlThreadGlobal', 'threadvar');
    Assert.IsTrue(lResult.Found, 'Expected the fast RTL profile to keep interface routines.');
    Assert.AreEqual('System.FastRtl', lResult.OwnerName);
    Assert.AreEqual('routine', lResult.Kind);
    Assert.IsTrue(lMemberResult.Found, 'Expected RTL alias members to resolve through the aliased record type.');
    Assert.AreEqual('_SECURITY_ATTRIBUTES', lMemberResult.OwnerName);
    Assert.AreEqual(1, lCache.Metrics.CacheMisses,
      'RTL source-root profiles must cache shared unit-model projections.');
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.CompilerProfileResolvesRtlSourceRootFromRsVars;
var
  lBdsRoot: string;
  lResolvedRoot: string;
  lRsVarsPath: string;
  lSourceRoot: string;
begin
  lBdsRoot := TPath.GetFullPath(CombinePath([CacheTempRoot, 'fake-bds']));
  lRsVarsPath := CombinePath([lBdsRoot, 'bin', 'rsvars.bat']);
  lSourceRoot := TPath.Combine(lBdsRoot, 'source');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lRsVarsPath));
  TDirectory.CreateDirectory(lSourceRoot);
  TFile.WriteAllText(lRsVarsPath, '@echo off' + sLineBreak, TEncoding.ASCII);

  lResolvedRoot := TDelphiSemanticCompilerProfileBuilder.ResolveRtlSourceRoot('23.0',
    lRsVarsPath);

  Assert.AreEqual(lSourceRoot, lResolvedRoot);
end;

procedure TCacheTests.ModelVersionChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('VersionChangeUnit.pas');
  TFile.WriteAllText(lPath, 'unit VersionChangeUnit;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.ModelVersion := 'cache-model-v1';
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
    lCache.ModelVersion := 'cache-model-v2';
    lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.ParserVersionChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TempPath('ParserVersionChangeUnit.pas');
  TFile.WriteAllText(lPath, 'unit ParserVersionChangeUnit;' + sLineBreak + 'interface' +
    sLineBreak + 'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.ParserVersion := 'cache-parser-v1';
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := lPath;
  lModelOptions.ProjectContextApplied := True;
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
    lCache.ParserVersion := 'cache-parser-v2';
    lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
  finally
    lCache.Free;
  end;
end;

procedure TCacheTests.DefaultParserInvalidatesObsoleteModels(const aVersion: string);
var
  lAccess: TDelphiSemanticUnitCacheAccessResult;
  lCache: TDelphiSemanticSqliteUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lModelOptions := Default(TDelphiSemanticModelOptions);
  lModelOptions.SourceFileName := TempPath('InlineSectionCacheUnit.pas');
  lModelOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lModelOptions.SourceFileName,
    'unit InlineSectionCacheUnit;' + sLineBreak + 'interface' + sLineBreak +
    'var ScopeTarget: Integer;' + sLineBreak + 'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TempPath('obsolete-parser-' + aVersion + '.sqlite3');
  lCacheOptions.ParserVersion := 'DelphiSemantics.Model.Parser.' + aVersion;
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lCache.GetOrExtractUnitModel(lModelOptions);
  finally
    lCache.Free;
  end;
  lCacheOptions.ParserVersion := '';
  lCache := TDelphiSemanticSqliteUnitCache.Create(lCacheOptions);
  try
    lAccess := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
    Assert.IsFalse(lAccess.CacheHit,
      'The default parser must reject persisted models from obsolete extraction rules.');
    lAccess := lCache.GetOrExtractUnitModelWithStatus(lModelOptions);
    Assert.IsTrue(lAccess.CacheHit, 'The rebuilt model must remain reusable.');
  finally
    lCache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCacheTests);

end.
