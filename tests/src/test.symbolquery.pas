unit Test.SymbolQuery;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Cache,
  DelphiSemantics.CompilerProfile,
  DelphiSemantics.Index,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Symbols;

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
    [Test]
    procedure BuildsProjectSymbolIndexWithResolvedAmbiguousAndUnresolvedReferences;
    [Test]
    procedure ProjectSymbolIndexUsesCaseInsensitiveLookupMaps;
  end;

implementation

uses
  System.Classes, System.IOUtils, System.SysUtils,
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

  lResult := TDelphiSemanticSymbolQuery.FindDefinitionAtPosition(lContext,
    FixturePath('SymbolQueryUnit.pas'), 1, 1);

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('SymbolQueryUnit', lResult.Name);
  Assert.AreEqual('unit', lResult.Kind);
  Assert.AreEqual('project-source', lResult.SourceKind);
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
  i: Integer;
  lContext: TDelphiSemanticSymbolQueryContext;
  lReferences: TArray<TDelphiSemanticSymbolReferenceResult>;
  lReferenceIndex: Integer;
begin
  lContext := LoadContext;
  lReferenceIndex := -1;
  for i := 0 to High(lContext.UnitModel.References) do
    if SameText(lContext.UnitModel.References[i].Name, 'TSymbolMapFixture') then
    begin
      lReferenceIndex := i;
      Break;
    end;
  Assert.IsTrue(lReferenceIndex >= 0, 'Expected fixture reference.');
  lContext.UnitModel.References[lReferenceIndex].Role := 'type-reference';
  lContext.UnitModel.References[lReferenceIndex].SectionKind := 'interface';
  lContext.UnitModel.References[lReferenceIndex].EndLine :=
    lContext.UnitModel.References[lReferenceIndex].Line;
  lContext.UnitModel.References[lReferenceIndex].EndColumn :=
    lContext.UnitModel.References[lReferenceIndex].Column + 18;

  lReferences := TDelphiSemanticSymbolQuery.FindTokenReferences(lContext,
    'TSymbolMapFixture', 1);

  Assert.AreEqual(1, Length(lReferences));
  Assert.AreEqual('SymbolQueryUnit', lReferences[0].UnitName);
  Assert.AreEqual('type-reference', lReferences[0].Role);
  Assert.AreEqual('interface', lReferences[0].SectionKind);
  Assert.AreEqual(lContext.UnitModel.References[lReferenceIndex].EndColumn, lReferences[0].EndColumn);
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
  SetLength(lSibling.Declarations, 2);
  lSibling.Declarations[0].Name := 'SiblingExact';
  lSibling.Declarations[0].Kind := 'type';
  lSibling.Declarations[0].Line := 3;
  lSibling.Declarations[0].Column := 3;
  lSibling.Declarations[1].Name := 'SiblingExactExtended';
  lSibling.Declarations[1].Kind := 'type';
  lSibling.Declarations[1].Line := 4;
  lSibling.Declarations[1].Column := 3;
  SetLength(lSibling.Members, 1);
  lSibling.Members[0].OwnerName := 'TSiblingOwner';
  lSibling.Members[0].Name := 'SiblingName';
  lSibling.Members[0].Kind := 'property';
  lSibling.Members[0].TypeName := 'string';
  lSibling.Members[0].Line := 5;
  lSibling.Members[0].Column := 5;
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

  lResult := TDelphiSemanticSymbolQuery.DescribeOwnedMember(lContext, 'TSiblingOwner',
    'SiblingName');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('property', lResult.Kind);
  Assert.AreEqual('project-source', lResult.SourceKind);

  lResults := TDelphiSemanticSymbolQuery.SearchAllMatches(lContext, 'SiblingExact', 10);

  Assert.AreEqual(2, Length(lResults));
end;

procedure TSymbolQueryTests.BuildsProjectSymbolIndexWithResolvedAmbiguousAndUnresolvedReferences;
var
  lAmbiguous: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticSymbolQueryContext;
  lHidden: TDelphiSemanticUnitModel;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lReference: TDelphiSemanticIndexedReference;
  lResolvedFixture: Boolean;
  lResolvedLowerCase: Boolean;
  lSawAmbiguous: Boolean;
  lSawHidden: Boolean;
  lSawImplementationOnly: Boolean;
  lSawUnresolved: Boolean;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbolIds: TStringList;
begin
  lContext := LoadContext;
  lAmbiguous := Default(TDelphiSemanticUnitModel);
  lAmbiguous.UnitName := 'AmbiguousSymbolUnit';
  lAmbiguous.FileName := FixturePath('AmbiguousSymbolUnit.pas');
  SetLength(lAmbiguous.Declarations, 2);
  lAmbiguous.Declarations[0].Name := 'GlobalQueryValue';
  lAmbiguous.Declarations[0].Kind := 'var';
  lAmbiguous.Declarations[0].SectionKind := 'interface';
  lAmbiguous.Declarations[0].Line := 3;
  lAmbiguous.Declarations[0].Column := 3;
  lAmbiguous.Declarations[1].Name := 'ImplementationOnlyValue';
  lAmbiguous.Declarations[1].Kind := 'var';
  lAmbiguous.Declarations[1].SectionKind := 'implementation';
  lAmbiguous.Declarations[1].Line := 4;
  lAmbiguous.Declarations[1].Column := 3;
  lHidden := Default(TDelphiSemanticUnitModel);
  lHidden.UnitName := 'HiddenSymbolUnit';
  lHidden.FileName := FixturePath('HiddenSymbolUnit.pas');
  SetLength(lHidden.Declarations, 1);
  lHidden.Declarations[0].Name := 'HiddenUniqueValue';
  lHidden.Declarations[0].Kind := 'var';
  lHidden.Declarations[0].SectionKind := 'interface';
  lHidden.Declarations[0].Line := 4;
  lHidden.Declarations[0].Column := 3;
  lContext.IndexedUnitModels := lContext.IndexedUnitModels + [lAmbiguous, lHidden];
  lContext.IndexedUnitSourceKinds := lContext.IndexedUnitSourceKinds +
    ['project-source', 'project-source'];
  lContext.UnitModel.ImplementationUses := lContext.UnitModel.ImplementationUses +
    ['AmbiguousSymbolUnit'];
  SetLength(lContext.UnitModel.References, Length(lContext.UnitModel.References) + 3);
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 1].Name := 'globalqueryvalue';
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 1].Line := 99;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 1].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Name :=
    'HiddenUniqueValue';
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Line := 100;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].Name := 'DoesNotExist';
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].Line := 101;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References) - 2].SectionKind :=
    'implementation';
  SetLength(lContext.UnitModel.References, Length(lContext.UnitModel.References) + 1);
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Name :=
    'ImplementationOnlyValue';
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Line := 102;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].SectionKind :=
    'implementation';
  SetLength(lContext.UnitModel.References, Length(lContext.UnitModel.References) + 1);
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Name := 'Name';
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Line := 103;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].Column := 3;
  lContext.UnitModel.References[High(lContext.UnitModel.References)].SectionKind :=
    'implementation';
  lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

  lSymbolIds := TStringList.Create;
  try
    lSymbolIds.Sorted := True;
    lSymbolIds.Duplicates := dupError;
    for lSymbol in lIndex.Symbols do
    begin
      Assert.AreNotEqual('', lSymbol.Id.Value);
      lSymbolIds.Add(lSymbol.Id.Value);
    end;
  finally
    lSymbolIds.Free;
  end;

  lResolvedFixture := False;
  lResolvedLowerCase := False;
  lSawAmbiguous := False;
  lSawHidden := False;
  lSawImplementationOnly := False;
  lSawUnresolved := False;
  for lReference in lIndex.References do
  begin
    if lReference.Name = 'globalqueryvalue' then
    begin
      lResolvedLowerCase := lReference.Status = 'ambiguous';
      Assert.AreEqual('case-insensitive-name-match', lReference.Confidence);
    end else if SameText(lReference.Name, 'TSymbolMapFixture') and
      (lReference.Status = 'resolved') then
    begin
      lResolvedFixture := True;
      Assert.AreNotEqual('', lReference.SymbolId.Value);
    end else if SameText(lReference.Name, 'GlobalQueryValue') then
    begin
      if lReference.Status = 'ambiguous' then
        lSawAmbiguous := True;
    end else if lReference.Name = 'DoesNotExist' then
    begin
      lSawUnresolved := lReference.Status = 'unresolved';
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end else if lReference.Name = 'HiddenUniqueValue' then
    begin
      lSawHidden := True;
      Assert.AreEqual('unresolved', lReference.Status);
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end else if lReference.Name = 'Name' then
    begin
      Assert.AreEqual('unresolved', lReference.Status);
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end else if lReference.Name = 'ImplementationOnlyValue' then
    begin
      lSawImplementationOnly := True;
      Assert.AreEqual('unresolved', lReference.Status);
      Assert.AreEqual('no-candidates', lReference.Confidence);
    end;
  end;

  Assert.IsTrue(lResolvedFixture, 'Expected a resolved TSymbolMapFixture reference.');
  Assert.IsTrue(lSawAmbiguous, 'Expected an ambiguous GlobalQueryValue reference.');
  Assert.IsTrue(lSawHidden, 'Expected hidden unit reference to stay unresolved.');
  Assert.IsTrue(lSawImplementationOnly,
    'Expected implementation-only cross-unit reference to stay unresolved.');
  Assert.IsTrue(lResolvedLowerCase, 'Expected lower-case reference to match case-insensitively.');
  Assert.IsTrue(lSawUnresolved, 'Expected unresolved reference diagnostic.');
end;

procedure TSymbolQueryTests.ProjectSymbolIndexUsesCaseInsensitiveLookupMaps;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lIndex: TDelphiSemanticProjectSymbolIndex;
  lModel: TDelphiSemanticUnitModel;
  lParameterLocal: TDelphiSemanticLocal;
  lReference: TDelphiSemanticIndexedReference;
  lReferences: TArray<TDelphiSemanticIndexedReference>;
  lScope: TDelphiSemanticUnitModel;
  lScopes: TArray<TDelphiSemanticUnitModel>;
  lSymbol: TDelphiSemanticIndexedSymbol;
  lSymbols: TArray<TDelphiSemanticIndexedSymbol>;
  lHidden: TDelphiSemanticUnitModel;
  lFoundReference: Boolean;
  lFoundRtlScope: Boolean;
  lSawHiddenScope: Boolean;
begin
  lContext := LoadContext;
  lHidden := Default(TDelphiSemanticUnitModel);
  lHidden.UnitName := 'HiddenSymbolUnit';
  lHidden.FileName := FixturePath('HiddenSymbolUnit.pas');
  lContext.IndexedUnitModels := lContext.IndexedUnitModels + [lHidden];
  lContext.IndexedUnitSourceKinds := lContext.IndexedUnitSourceKinds + ['project-source'];
  lContext.UnitModel.ImplementationUses := lContext.UnitModel.ImplementationUses +
    ['SymbolQueryRtlUnit'];
  lParameterLocal := Default(TDelphiSemanticLocal);
  lParameterLocal.RoutineName := 'UseSymbols';
  lParameterLocal.Name := 'aInjectedParam';
  lParameterLocal.Kind := 'parameter';
  lParameterLocal.TypeName := 'Integer';
  lParameterLocal.Line := 200;
  lParameterLocal.Column := 7;
  lContext.UnitModel.Locals := lContext.UnitModel.Locals + [lParameterLocal];
  lIndex := TDelphiSemanticApi.BuildProjectSymbolIndex(lContext);

  lSymbols := lIndex.FindTopLevelSymbolsByName('globalqueryvalue');

  Assert.AreEqual(1, Length(lSymbols));
  Assert.AreEqual('GlobalQueryValue', lSymbols[0].Name);
  Assert.IsTrue(lIndex.FindSymbolById(lSymbols[0].Id, lSymbol));
  Assert.AreEqual('GlobalQueryValue', lSymbol.Name);
  lReferences := lIndex.FindReferencesBySymbolId(lSymbol.Id);
  Assert.IsTrue(Length(lReferences) > 0);

  lSymbols := lIndex.FindSymbolsByName('tsymbolmapfixture');
  Assert.IsTrue(Length(lSymbols) > 0);
  Assert.AreEqual('TSymbolMapFixture', lSymbols[0].Name);

  lSymbols := lIndex.FindLocalSymbolsByRoutineAndName('usesymbols', 'lfixture');
  Assert.AreEqual(1, Length(lSymbols));
  Assert.AreEqual('UseSymbols', lSymbols[0].OwnerName);
  Assert.AreEqual('var', lSymbols[0].Kind);

  lSymbols := lIndex.FindLocalSymbolsByRoutineAndName('usesymbols', 'ainjectedparam');
  Assert.AreEqual(1, Length(lSymbols));
  Assert.AreEqual('UseSymbols', lSymbols[0].OwnerName);
  Assert.AreEqual('parameter', lSymbols[0].Kind);

  lSymbols := lIndex.FindMembersByOwnerAndName('tsymbolmapfixture', 'enabled');
  Assert.AreEqual(1, Length(lSymbols));
  Assert.AreEqual('TSymbolMapFixture', lSymbols[0].OwnerName);
  Assert.AreEqual('property', lSymbols[0].Kind);

  lReferences := lIndex.FindReferencesByName('tsymbolmapfixture');
  lFoundReference := False;
  for lReference in lReferences do
    if SameText(lReference.Name, 'TSymbolMapFixture') then
      lFoundReference := True;

  Assert.IsTrue(lFoundReference);
  Assert.IsTrue(lIndex.FindUnitModelByName('symbolqueryunit', lModel));
  Assert.AreEqual('SymbolQueryUnit', lModel.UnitName);

  lFoundRtlScope := False;
  lSawHiddenScope := False;
  lScopes := lIndex.FindVisibleUnitScopes('symbolqueryunit', 'implementation');
  Assert.IsTrue(Length(lScopes) >= 2);
  Assert.AreEqual('SymbolQueryUnit', lScopes[0].UnitName);
  for lScope in lScopes do
  begin
    if SameText(lScope.UnitName, 'SymbolQueryRtlUnit') then
      lFoundRtlScope := True;
    if SameText(lScope.UnitName, 'HiddenSymbolUnit') then
      lSawHiddenScope := True;
  end;
  Assert.IsTrue(lFoundRtlScope);
  Assert.IsFalse(lSawHiddenScope);
end;

initialization
  TDUnitX.RegisterTestFixture(TSymbolQueryTests);

end.
