unit Test.Cache;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Cache,
  DelphiSemantics.Model;

type
  [TestFixture]
  TCacheTests = class
  private
    function HasDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string):
      Boolean;
    function TempPath(const aName: string): string;
  public
    [Test]
    procedure DefaultOptionsUseInMemoryCache;
    [Test]
    procedure RepeatedUnchangedUnitHitsInMemoryCache;
    [Test]
    procedure CacheHitReturnsIndependentUnitModelCopy;
    [Test]
    procedure SourceChangeInvalidatesCachedUnitModel;
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
    procedure ParserVersionChangeInvalidatesCachedUnitModel;
    [Test]
    procedure ModelVersionChangeInvalidatesCachedUnitModel;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils,
  DelphiSemantics.CompilerProfile, DelphiSemantics.Resolve;

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
