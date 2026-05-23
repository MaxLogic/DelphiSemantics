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
    function FindRoutine(const aModel: TDelphiSemanticUnitModel; const aName, aOwnerName: string;
      out aRoutine: TDelphiSemanticRoutine): Boolean;
    function HasDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string):
      Boolean;
    function TempPath(const aName: string): string;
  public
    [Test]
    procedure DefaultOptionsUseInMemoryCache;
    [Test]
    procedure InMemoryMetricsExposeEmptyCacheFileName;
    [Test]
    procedure RepeatedUnchangedUnitHitsInMemoryCache;
    [Test]
    procedure CacheHitReturnsIndependentUnitModelCopy;
    [Test]
    procedure SourceChangeInvalidatesCachedUnitModel;
    [Test]
    procedure SourceTimestampChangeInvalidatesCachedUnitModel;
    [Test]
    procedure SemanticContextChangeInvalidatesCachedUnitModel;
    [Test]
    procedure EquivalentDefineOrderReusesCachedUnitModel;
    [Test]
    procedure SearchPathOrderChangeInvalidatesCachedUnitModel;
    [Test]
    procedure IncludeChangeInvalidatesCachedUnitModel;
    [Test]
    procedure CompilerProfileChangeInvalidatesCachedUnitModel;
    [Test]
    procedure CompilerProfileSeedsIntrinsicRows;
    [Test]
    procedure CompilerProfileLoadsCachedRtlSourceModels;
    [Test]
    procedure CompilerProfileDiscoversScopedRtlUnitsFromSourceRoot;
    [Test]
    procedure CompilerProfileRtlSourceRootBuildsFastInterfaceModels;
    [Test]
    procedure CompilerProfileResolvesRtlSourceRootFromRsVars;
    [Test]
    procedure ParserVersionChangeInvalidatesCachedUnitModel;
    [Test]
    procedure ModelVersionChangeInvalidatesCachedUnitModel;
    [Test]
    procedure CacheAccessResultReportsPerCallHitAndIdentity;
    [Test]
    procedure SqliteCacheHitRestoresSourceSections;
    [Test]
    procedure SqliteCacheHitRestoresOriginalRanges;
    [Test]
    procedure SymbolMapCompatibleIdentityReusesSharedSourceAcrossProjects;
    [Test]
    procedure CompilerProfileExposesDakIntrinsicSeedFacts;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils,
  DelphiSemantics.Resolve;

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
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp', aName]));
  TDirectory.CreateDirectory(TPath.GetDirectoryName(Result));
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
    'type' + sLineBreak + '  TOriginalCachedType = class end;' + sLineBreak +
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

    lModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.IsTrue(HasDeclaration(lModel, 'TOriginalCachedType'));
    Assert.IsFalse(HasDeclaration(lModel, 'TCorruptedCachedType'));
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
    Assert.IsNotEmpty(lSecond.Identity.FileHash);
    Assert.IsNotEmpty(lSecond.Identity.ContextHash);
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

procedure TCacheTests.SourceTimestampChangeInvalidatesCachedUnitModel;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
  lPath: string;
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
    lCache.GetOrExtractUnitModel(lModelOptions);
    TFile.SetLastWriteTimeUtc(lPath, TFile.GetLastWriteTimeUtc(lPath) + EncodeTime(0, 0, 5, 0));
    lCache.GetOrExtractUnitModel(lModelOptions);

    Assert.AreEqual(2, lCache.Metrics.CacheMisses);
    Assert.AreEqual(1, lCache.Metrics.Invalidations);
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
  Assert.AreEqual('delphi-intrinsics-v1', lProfile.IntrinsicSeedVersion);
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
  lFirstDir := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp',
    'search-a']));
  lSecondDir := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp',
    'search-b']));
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
  Assert.AreEqual(3, Length(lProfile.IntrinsicSymbols));

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Length');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('intrinsic-routine', lResult.Kind);
  Assert.AreEqual('compiler', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TObject');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('intrinsic-type', lResult.Kind);
  Assert.AreEqual('rtl', lResult.OwnerName);
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
    Assert.AreEqual(1, Length(lProfile.RtlSourceUnitModels));
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
  lRtlRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp',
    'fake-delphi-source']));
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
    Assert.AreEqual(3, Length(lProfile.RtlSourceUnitModels));
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

procedure TCacheTests.CompilerProfileRtlSourceRootBuildsFastInterfaceModels;
var
  i: Integer;
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
  lRtlRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp',
    'fake-fast-delphi-source']));
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
  for i := 1 to 5000 do
    lSource := lSource + 'this is intentionally not parsed as Delphi implementation body' +
      sLineBreak;
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

    Assert.AreEqual(1, Length(lProfile.RtlSourceUnitModels));
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
      'RTL source-root profiles must cache fast interface models without using the full parser path.');
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
  lBdsRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), 'cache-temp',
    'fake-bds']));
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

initialization
  TDUnitX.RegisterTestFixture(TCacheTests);

end.
