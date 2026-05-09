unit Test.SymbolQuery;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Model,
  DelphiSemantics.Query;

type
  [TestFixture]
  TSymbolQueryTests = class
  private
    function FixturePath(const aFileName: string): string;
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure FindsProjectDefinitionByPositionAndName;
    [Test]
    procedure SearchesProjectMembersRtlSourceAndIntrinsics;
    [Test]
    procedure DescribesOwnedMembersAndIntrinsics;
    [Test]
    procedure FindsTokenReferencesInProjectScope;
    [Test]
    procedure LimitsTokenReferenceResults;
    [Test]
    procedure ResolvesCoreSymbolKindsWithoutShellingOut;
    [Test]
    procedure ResolvesSourcePositionAndReportsCacheStatus;
    [Test]
    procedure CacheStatusExposesProfileKeyAndCacheFileName;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TSymbolQueryTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'SymbolQuery', aFileName]));
end;

function TSymbolQueryTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lModelOptions: TDelphiSemanticModelOptions;
begin
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.CompilerProfileName := 'Delphi-12-SymbolQuery';
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

procedure TSymbolQueryTests.FindsProjectDefinitionByPositionAndName;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'TDeclarationRecord');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('TDeclarationRecord', lResult.Name);
  Assert.AreEqual('type', lResult.Kind);
  Assert.AreEqual('semantic-model', lResult.Provenance);
  Assert.AreEqual(FixturePath('SymbolQueryUnit.pas'), lResult.FileName);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQueryUnit.pas'), 32, 13);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('TSymbolMapFixture', lResult.Name);
  Assert.AreEqual('type', lResult.Kind);
end;

procedure TSymbolQueryTests.SearchesProjectMembersRtlSourceAndIntrinsics;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResults: TArray<TDelphiSemanticSymbolQueryResult>;
begin
  lContext := LoadContext;

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'Enabled', 10);

  Assert.AreEqual(1, Length(lResults));
  Assert.AreEqual('Enabled', lResults[0].Name);
  Assert.AreEqual('property', lResults[0].Kind);
  Assert.AreEqual('TSymbolMapFixture', lResults[0].OwnerName);

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'TSystemFixture', 10);

  Assert.AreEqual(1, Length(lResults));
  Assert.AreEqual('rtl-source', lResults[0].SourceKind);
  Assert.AreEqual('SymbolQueryRtlUnit', lResults[0].OwnerName);

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'Length', 10);

  Assert.AreEqual(1, Length(lResults));
  Assert.AreEqual('intrinsic-routine', lResults[0].Kind);
  Assert.AreEqual('compiler-profile', lResults[0].SourceKind);
end;

procedure TSymbolQueryTests.DescribesOwnedMembersAndIntrinsics;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.DescribeOwnedMember(lContext, 'TSymbolMapFixture',
    'Name');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('Name: string', lResult.Description);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'Length');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('Length: Integer', lResult.Description);
end;

procedure TSymbolQueryTests.FindsTokenReferencesInProjectScope;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
begin
  lContext := LoadContext;

  lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
    'TSymbolMapFixture', 10);

  Assert.IsTrue(Length(lReferences) >= 2);
  Assert.AreEqual('token-name-match', lReferences[0].Confidence);
  Assert.AreEqual('project-source', lReferences[0].SourceKind);
  Assert.AreEqual(FixturePath('SymbolQueryUnit.pas'), lReferences[0].FileName);
end;

procedure TSymbolQueryTests.LimitsTokenReferenceResults;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
begin
  lContext := LoadContext;

  lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
    'TSymbolMapFixture', 1);

  Assert.AreEqual(1, Length(lReferences));
end;

procedure TSymbolQueryTests.ResolvesCoreSymbolKindsWithoutShellingOut;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'TSymbolMapFixture');
  Assert.AreEqual('type', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.DescribeOwnedMember(lContext, 'TSymbolMapFixture',
    'Enabled');
  Assert.AreEqual('property', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'Execute');
  Assert.AreEqual('routine', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'GlobalQueryValue');
  Assert.AreEqual('var', lResult.Kind);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionByName(lContext, 'TObject');
  Assert.AreEqual('intrinsic-type', lResult.Kind);
end;

procedure TSymbolQueryTests.ResolvesSourcePositionAndReportsCacheStatus;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lResult: TDelphiSemanticSymbolQueryResult;
  lStatus: TDelphiSemanticSymbolQueryCacheStatus;
begin
  lContext := LoadContext;

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQueryUnit.pas'), 36, 3);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('GlobalQueryValue', lResult.Name);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQueryRtlUnit.pas'), 10, 3);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('TDeclarationRecord', lResult.Name);
  Assert.AreEqual('rtl-source', lResult.SourceKind);
  Assert.AreEqual(FixturePath('SymbolQueryRtlUnit.pas'), lResult.FileName);

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQueryUnit.pas'), 39, 3);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('Length', lResult.Name);
  Assert.AreEqual('intrinsic-routine', lResult.Kind);
  Assert.AreEqual('compiler-profile', lResult.SourceKind);

  lStatus := TDelphiSemanticSymbolQuery.GetCacheStatus(lContext);

  Assert.AreEqual('in-memory', lStatus.CacheKind);
  Assert.AreEqual(2, lStatus.CacheMisses);
  Assert.AreEqual('Delphi-12-SymbolQuery', lStatus.CompilerProfileName);
  Assert.AreEqual(3, lStatus.IntrinsicCount);
  Assert.AreEqual(1, lStatus.RtlSourceUnitCount);
end;

procedure TSymbolQueryTests.CacheStatusExposesProfileKeyAndCacheFileName;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lStatus: TDelphiSemanticSymbolQueryCacheStatus;
begin
  lContext := LoadContext;

  lStatus := TDelphiSemanticSymbolQuery.GetCacheStatus(lContext);

  Assert.AreEqual('', lStatus.CacheFileName);
  Assert.AreEqual('Delphi-12-SymbolQuery', lStatus.CompilerProfileKey);
end;

initialization
  TDUnitX.RegisterTestFixture(TSymbolQueryTests);

end.
