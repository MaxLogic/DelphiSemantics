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
    [Test]
    procedure SearchMatchesSubstringsAndReturnsRanges;
    [Test]
    procedure TokenReferencesExposeMetadata;
    [Test]
    procedure VisibleUnitScopesIncludeProjectAndRtlModels;
    [Test]
    procedure IndexedProjectUnitsKeepSourceKindAndRoutineSearch;
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

procedure TSymbolQueryTests.SearchMatchesSubstringsAndReturnsRanges;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lFoundProjectType: Boolean;
  lFoundRtlType: Boolean;
  lResult: TDelphiSemanticSymbolQueryResult;
  lResults: TArray<TDelphiSemanticSymbolQueryResult>;
begin
  lFoundProjectType := False;
  lFoundRtlType := False;
  lContext := LoadContext;

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'Fixture', 10);

  for lResult in lResults do
  begin
    if SameText(lResult.Name, 'TSymbolMapFixture') then
    begin
      lFoundProjectType := True;
      Assert.AreEqual('SymbolQueryUnit', lResult.UnitName);
      Assert.IsTrue(lResult.EndLine >= lResult.Line);
      Assert.IsTrue(lResult.EndColumn >= lResult.Column);
    end else if SameText(lResult.Name, 'TSystemFixture') then
    begin
      lFoundRtlType := True;
      Assert.AreEqual('rtl-source', lResult.SourceKind);
      Assert.AreEqual('SymbolQueryRtlUnit', lResult.UnitName);
    end;
  end;

  Assert.IsTrue(lFoundProjectType);
  Assert.IsTrue(lFoundRtlType);
end;

procedure TSymbolQueryTests.TokenReferencesExposeMetadata;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
begin
  lContext := LoadContext;

  lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
    'TSymbolMapFixture', 1);

  Assert.AreEqual(1, Length(lReferences));
  Assert.AreEqual('SymbolQueryUnit', lReferences[0].UnitName);
  Assert.AreEqual('token', lReferences[0].Role);
  Assert.AreEqual('implementation', lReferences[0].SectionKind);
  Assert.IsTrue(lReferences[0].EndColumn >= lReferences[0].Column);
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

procedure TSymbolQueryTests.VisibleUnitScopesIncludeProjectAndRtlModels;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lFoundProject: Boolean;
  lFoundRtl: Boolean;
  lScope: TDelphiSemanticVisibleUnitScope;
  lScopes: TArray<TDelphiSemanticVisibleUnitScope>;
begin
  lFoundProject := False;
  lFoundRtl := False;
  lContext := LoadContext;

  lScopes := TDelphiSemanticSymbolQuery.GetVisibleUnitScopes(lContext);

  for lScope in lScopes do
  begin
    if SameText(lScope.UnitName, 'SymbolQueryUnit') then
    begin
      lFoundProject := True;
      Assert.AreEqual('project-source', lScope.SourceKind);
    end else if SameText(lScope.UnitName, 'SymbolQueryRtlUnit') then
    begin
      lFoundRtl := True;
      Assert.AreEqual('rtl-source', lScope.SourceKind);
    end;
  end;

  Assert.IsTrue(lFoundProject);
  Assert.IsTrue(lFoundRtl);
end;

procedure TSymbolQueryTests.IndexedProjectUnitsKeepSourceKindAndRoutineSearch;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lFoundScope: Boolean;
  lResult: TDelphiSemanticSymbolQueryResult;
  lResults: TArray<TDelphiSemanticSymbolQueryResult>;
  lScope: TDelphiSemanticVisibleUnitScope;
  lSibling: TDelphiSemanticUnitModel;
begin
  lContext := LoadContext;
  lSibling := Default(TDelphiSemanticUnitModel);
  lSibling.UnitName := 'SymbolQuerySiblingUnit';
  lSibling.FileName := FixturePath('SymbolQuerySiblingUnit.pas');
  SetLength(lSibling.Routines, 1);
  lSibling.Routines[0].Name := 'SiblingRoutine';
  lSibling.Routines[0].Signature := 'procedure SiblingRoutine';
  lSibling.Routines[0].Line := 7;
  lSibling.Routines[0].Column := 3;
  lContext.IndexedUnitModels := [lSibling, lContext.IndexedUnitModels[0]];
  lContext.IndexedUnitSourceKinds := ['project-source', 'rtl-source'];

  lFoundScope := False;
  for lScope in TDelphiSemanticSymbolQuery.GetVisibleUnitScopes(lContext) do
    if SameText(lScope.UnitName, 'SymbolQuerySiblingUnit') then
    begin
      lFoundScope := True;
      Assert.AreEqual('project-source', lScope.SourceKind);
    end;

  lResults := TDelphiSemanticSymbolQuery.Search(lContext, 'SiblingRoutine', 10);

  Assert.IsTrue(lFoundScope);
  Assert.AreEqual(1, Length(lResults));
  lResult := lResults[0];
  Assert.AreEqual('routine', lResult.Kind);
  Assert.AreEqual('project-source', lResult.SourceKind);
  Assert.AreEqual('procedure SiblingRoutine', lResult.Signature);
end;

initialization
  TDUnitX.RegisterTestFixture(TSymbolQueryTests);

end.
