unit Test.ExternalSymbols;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Cache, DelphiSemantics.CompilerProfile, DelphiSemantics.ExternalSymbols;

type
  [TestFixture]
  TExternalSymbolsTests = class
  private
    function TempPath(const aRelativePath: string): string;
  public
    [Test]
    procedure CompilerIntrinsicsResolveFromExternalService;
    [Test]
    procedure RtlSourceUnitsLoadLazilyAndExposeMetrics;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TExternalSymbolsTests.TempPath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
    'external-symbols-temp', aRelativePath]));
end;

procedure TExternalSymbolsTests.CompilerIntrinsicsResolveFromExternalService;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lMetrics: TDelphiSemanticExternalSymbolMetrics;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticExternalSymbolResult;
  lService: TDelphiSemanticExternalSymbolService;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-ExternalSymbols';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTarget(
      'Delphi-12-ExternalSymbols', '23.0', 'Win32', '');
    lService := TDelphiSemanticExternalSymbolService.Open(lCache, lProfile);

    lResult := lService.ResolveIntrinsic('NativeUInt');
    lMetrics := lService.Metrics;

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('intrinsic-type', lResult.Kind);
    Assert.AreEqual('compiler-intrinsic', lResult.SourceKind);
    Assert.AreEqual(1, lMetrics.IntrinsicLookupCount);
    Assert.AreEqual(1, lMetrics.IntrinsicResolvedCount);
  finally
    lCache.Free;
  end;
end;

procedure TExternalSymbolsTests.RtlSourceUnitsLoadLazilyAndExposeMetrics;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCommonRoot: string;
  lMetrics: TDelphiSemanticExternalSymbolMetrics;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticExternalSymbolResult;
  lRtlRoot: string;
  lService: TDelphiSemanticExternalSymbolService;
  lTypeResult: TDelphiSemanticExternalSymbolResult;
begin
  lRtlRoot := TempPath('fake-delphi-source');
  if TDirectory.Exists(lRtlRoot) then
    TDirectory.Delete(lRtlRoot, True);
  lCommonRoot := CombinePath([lRtlRoot, 'rtl', 'common']);
  TDirectory.CreateDirectory(lCommonRoot);
  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'Winapi.Windows.pas'),
    'unit Winapi.Windows;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  THandle = NativeUInt;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);

  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-ExternalSymbols-RTL';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lProfile := TDelphiSemanticCompilerProfileBuilder.ProfileForTarget(
      'Delphi-12-ExternalSymbols-RTL', '23.0', 'Win32', lRtlRoot);
    lService := TDelphiSemanticExternalSymbolService.Open(lCache, lProfile);
    lMetrics := lService.Metrics;
    Assert.AreEqual(0, lMetrics.RtlUnitLoadCount,
      'Opening the external service must not eagerly load source-available RTL units.');

    lResult := lService.ResolveRtlUnit('Windows');
    lMetrics := lService.Metrics;

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('Winapi.Windows', lResult.UnitModel.UnitName);
    Assert.AreEqual('rtl-source', lResult.SourceKind);
    lResult := lService.ResolveRtlUnit('Windows');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual(2, lMetrics.RtlUnitLookupCount);
    Assert.AreEqual(1, lMetrics.RtlUnitLoadCount,
      'Repeated alias lookups must reuse the in-memory external unit model.');

    lTypeResult := lService.ResolveType('THandle');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lTypeResult.Found);
    Assert.AreEqual(2, lMetrics.RtlUnitLookupCount);
    Assert.AreEqual(1, lMetrics.RtlUnitLoadCount);
    Assert.AreEqual(1, lMetrics.RtlTypeResolvedCount);
    Assert.AreEqual(1, lMetrics.RtlTypeIndexBuildCount);
    lTypeResult := lService.ResolveType('THandle');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lTypeResult.Found);
    Assert.AreEqual(2, lMetrics.RtlTypeResolvedCount);
    Assert.AreEqual(1, lMetrics.RtlTypeIndexBuildCount,
      'Repeated type lookups must reuse the in-memory external type index.');
    Assert.AreEqual(0, lMetrics.IntrinsicLookupCount,
      'Type fallback intrinsic probes must not inflate direct intrinsic lookup metrics.');
    Assert.AreEqual(1, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExternalSymbolsTests);

end.
