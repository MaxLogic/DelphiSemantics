unit Test.Usage;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Usage;

type
  [TestFixture]
  TUsageTests = class
  private
    function FixturePath(const aFileName: string): string;
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure FindsUsagesForSourceLocationAndExplicitName;
    [Test]
    procedure BlocksAmbiguousUsageTargets;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TUsageTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'SymbolQuery', aFileName]));
end;

function TUsageTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-Usage';
  lCache := TDelphiSemanticUnitCache.Create(lCacheOptions);
  try
    lModelOptions := Default(TDelphiSemanticModelOptions);
    lModelOptions.SourceFileName := FixturePath('SymbolQueryUnit.pas');
    lModelOptions.ProjectContextApplied := True;
    Result.UnitModel := lCache.GetOrExtractUnitModel(lModelOptions);

    Result.CompilerProfile := TDelphiSemanticCompilerProfileBuilder.FromCachedSources(lCache,
      [FixturePath('SymbolQueryRtlUnit.pas')]);
    Result.IndexedUnitModels := Result.CompilerProfile.RtlSourceUnitModels;
    Result.CacheMetrics := lCache.Metrics;
  finally
    lCache.Free;
  end;
end;

procedure TUsageTests.FindsUsagesForSourceLocationAndExplicitName;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticUsageResult;
  lUsage: TDelphiSemanticUsage;
  lFoundDeclaration: Boolean;
  lFoundImplementationReference: Boolean;
begin
  lFoundDeclaration := False;
  lFoundImplementationReference := False;
  lContext := LoadContext;

  lResult := TDelphiSemanticApi.FindUsagesAtPosition(lContext,
    FixturePath('SymbolQueryUnit.pas'), 6, 3);

  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('TSymbolMapFixture', lResult.Symbol.Name);
  Assert.IsTrue(Length(lResult.Usages) >= 3);

  for lUsage in lResult.Usages do
  begin
    if SameText(lUsage.Role, 'declaration') and SameText(lUsage.SectionKind, 'interface') then
      lFoundDeclaration := True;
    if (lUsage.Line > 20) and SameText(lUsage.SectionKind, 'implementation') then
      lFoundImplementationReference := True;
  end;

  Assert.IsTrue(lFoundDeclaration);
  Assert.IsTrue(lFoundImplementationReference);

  lResult := TDelphiSemanticApi.FindUsagesByName(lContext, 'GlobalQueryValue');

  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('GlobalQueryValue', lResult.Symbol.Name);
  Assert.IsTrue(Length(lResult.Usages) >= 3);
end;

procedure TUsageTests.BlocksAmbiguousUsageTargets;
var
  lAmbiguous: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticUsageResult;
begin
  lContext := LoadContext;
  lAmbiguous := Default(TDelphiSemanticUnitModel);
  lAmbiguous.UnitName := 'AmbiguousUsageUnit';
  lAmbiguous.FileName := FixturePath('AmbiguousUsageUnit.pas');
  SetLength(lAmbiguous.Declarations, 1);
  lAmbiguous.Declarations[0].Name := 'GlobalQueryValue';
  lAmbiguous.Declarations[0].Kind := 'var';
  lAmbiguous.Declarations[0].SectionKind := 'interface';
  lAmbiguous.Declarations[0].Line := 3;
  lAmbiguous.Declarations[0].Column := 3;
  lContext.IndexedUnitModels := lContext.IndexedUnitModels + [lAmbiguous];
  lContext.IndexedUnitSourceKinds := lContext.IndexedUnitSourceKinds + ['project-source'];
  lContext.UnitModel.ImplementationUses := lContext.UnitModel.ImplementationUses +
    ['AmbiguousUsageUnit'];

  lResult := TDelphiSemanticUsageFinder.FindUsagesByName(lContext, 'GlobalQueryValue');

  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.IsTrue(lResult.Diagnostic <> '');
  Assert.AreEqual(0, Integer(Length(lResult.Usages)));
end;

initialization
  TDUnitX.RegisterTestFixture(TUsageTests);

end.
