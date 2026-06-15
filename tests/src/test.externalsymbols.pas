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
  Winapi.Windows,
  maxLogic.IOUtils;

var
  GExternalSymbolsTempRoot: string;

function ExternalSymbolsTempRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GExternalSymbolsTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GExternalSymbolsTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'external-symbols-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GExternalSymbolsTempRoot);
  Result := GExternalSymbolsTempRoot;
end;

function TExternalSymbolsTests.TempPath(const aRelativePath: string): string;
begin
  Result := TPath.GetFullPath(TPath.Combine(ExternalSymbolsTempRoot, aRelativePath));
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
    lResult := lService.ResolveIntrinsic('Random');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('intrinsic-routine', lResult.Kind);
    Assert.AreEqual('compiler-intrinsic', lResult.SourceKind);
    Assert.AreEqual(2, lMetrics.IntrinsicLookupCount);
    Assert.AreEqual(2, lMetrics.IntrinsicResolvedCount);
  finally
    lCache.Free;
  end;
end;

procedure TExternalSymbolsTests.RtlSourceUnitsLoadLazilyAndExposeMetrics;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lCommonRoot: string;
  lDeepRoot: string;
  lMetrics: TDelphiSemanticExternalSymbolMetrics;
  lProfile: TDelphiSemanticCompilerProfile;
  lResult: TDelphiSemanticExternalSymbolResult;
  lRtlRoot: string;
  lService: TDelphiSemanticExternalSymbolService;
  lTypeResult: TDelphiSemanticExternalSymbolResult;
begin
  lRtlRoot := TempPath('fake-delphi-source');
  lCommonRoot := CombinePath([lRtlRoot, 'rtl', 'common']);
  lDeepRoot := CombinePath([lRtlRoot, 'rtl', 'custom', 'deep']);
  TDirectory.CreateDirectory(lCommonRoot);
  TDirectory.CreateDirectory(lDeepRoot);
  TFile.WriteAllText(TPath.Combine(lCommonRoot, 'Winapi.Windows.pas'),
    'unit Winapi.Windows;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  THandle = NativeUInt;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lDeepRoot, 'System.FirstLazy.pas'),
    'unit System.FirstLazy;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TFirstLazy = record end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lDeepRoot, 'System.SecondLazy.pas'),
    'unit System.SecondLazy;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TSecondLazy = record end;' + sLineBreak +
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
    Assert.AreEqual(0, lMetrics.RtlSourceDiscoveryIndexBuildCount,
      'Direct RTL loads should not build the recursive discovery index.');
    lResult := lService.ResolveRtlUnit('Windows');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual(2, lMetrics.RtlUnitLookupCount,
      'Two explicit Windows unit lookups should be counted before recursive loads.');
    Assert.AreEqual(1, lMetrics.RtlUnitLoadCount,
      'Repeated alias lookups must reuse the in-memory external unit model.');

    lResult := lService.ResolveRtlUnit('FirstLazy');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('System.FirstLazy', lResult.UnitModel.UnitName);
    Assert.AreEqual(1, lMetrics.RtlSourceDiscoveryIndexBuildCount,
      'First recursive fallback load should build one reusable discovery index.');

    lResult := lService.ResolveRtlUnit('SecondLazy');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('System.SecondLazy', lResult.UnitModel.UnitName);
    Assert.AreEqual(1, lMetrics.RtlSourceDiscoveryIndexBuildCount,
      'Second recursive fallback load should reuse the first discovery index.');
    Assert.AreEqual(3, lMetrics.RtlUnitLoadCount);

    lTypeResult := lService.ResolveType('THandle');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lTypeResult.Found);
    Assert.AreEqual(4, lMetrics.RtlUnitLookupCount,
      'Type lookup should not increment the four explicit RTL unit lookup requests.');
    Assert.AreEqual(3, lMetrics.RtlUnitLoadCount);
    Assert.AreEqual(1, lMetrics.RtlTypeResolvedCount);
    Assert.AreEqual(1, lMetrics.RtlTypeIndexBuildCount);
    lTypeResult := lService.ResolveType('THandle');
    lMetrics := lService.Metrics;
    Assert.IsTrue(lTypeResult.Found);
    Assert.AreEqual(2, lMetrics.RtlTypeResolvedCount,
      'Repeated type lookup should count two resolved type requests.');
    Assert.AreEqual(1, lMetrics.RtlTypeIndexBuildCount,
      'Repeated type lookups must reuse the in-memory external type index.');
    Assert.AreEqual(0, lMetrics.IntrinsicLookupCount,
      'Type fallback intrinsic probes must not inflate direct intrinsic lookup metrics.');
    Assert.AreEqual(3, lCache.Metrics.CacheMisses);
  finally
    lCache.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TExternalSymbolsTests);

end.
