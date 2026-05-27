unit Test.TypeResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TTypeResolverTests = class
  private
    function Graph: TDelphiSemanticSemanticGraph;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ResolvesSimpleQualifiedAndVisibleTypeNames;
    [Test]
    procedure PreservesDeclaredCanonicalAndUnderlyingAliasIdentities;
    [Test]
    procedure ReportsAmbiguousSimpleNames;
    [Test]
    procedure FindsAncestorTypeChain;
  end;

implementation

function TTypeResolverTests.Graph: TDelphiSemanticSemanticGraph;
begin
  Result := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel('TypeUnitA'),
    UnitModel('TypeUnitB'), UnitModel('TypeUnitC')]);
end;

function TTypeResolverTests.ProjectInfo: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectName := 'TypeResolverProject';
  Result.ContextFingerprint := 'type-resolver-context';
end;

function TTypeResolverTests.UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aUnitName + '.pas';

  if aUnitName = 'TypeUnitA' then
  begin
    SetLength(Result.Declarations, 5);
    Result.Declarations[0].Name := 'TBase';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'class';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
    Result.Declarations[1].Name := 'TChild';
    Result.Declarations[1].Kind := 'type';
    Result.Declarations[1].TypeName := 'class';
    Result.Declarations[1].BaseTypeName := 'TBase';
    Result.Declarations[1].SectionKind := 'interface';
    Result.Declarations[1].Line := 5;
    Result.Declarations[1].Column := 3;
    Result.Declarations[2].Name := 'TAlias';
    Result.Declarations[2].Kind := 'type-alias';
    Result.Declarations[2].TypeName := 'TChild';
    Result.Declarations[2].SectionKind := 'interface';
    Result.Declarations[2].Line := 6;
    Result.Declarations[2].Column := 3;
    Result.Declarations[3].Name := 'TShared';
    Result.Declarations[3].Kind := 'type';
    Result.Declarations[3].TypeName := 'record';
    Result.Declarations[3].SectionKind := 'interface';
    Result.Declarations[3].Line := 7;
    Result.Declarations[3].Column := 3;
    Result.Declarations[4].Name := 'TImplOnly';
    Result.Declarations[4].Kind := 'type';
    Result.Declarations[4].TypeName := 'record';
    Result.Declarations[4].SectionKind := 'implementation';
    Result.Declarations[4].Line := 20;
    Result.Declarations[4].Column := 3;
  end else if aUnitName = 'TypeUnitB' then
  begin
    SetLength(Result.Declarations, 1);
    Result.Declarations[0].Name := 'TShared';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'record';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
  end else
  begin
    SetLength(Result.Declarations, 2);
    Result.Declarations[0].Name := 'TExternalOnly';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'record';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
    Result.Declarations[1].Name := 'TQualifiedAlias';
    Result.Declarations[1].Kind := 'type-alias';
    Result.Declarations[1].TypeName := 'TypeUnitA.TChild';
    Result.Declarations[1].SectionKind := 'interface';
    Result.Declarations[1].Line := 5;
    Result.Declarations[1].Column := 3;
  end;
end;

procedure TTypeResolverTests.FindsAncestorTypeChain;
var
  lAncestors: TArray<TDelphiSemanticTypeIdentity>;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TChild');
    Assert.IsTrue(lResult.Found, lResult.Reason);

    lAncestors := lIndex.FindAncestors(lResult.Identity);

    Assert.AreEqual(1, Length(lAncestors));
    Assert.AreEqual('TBase', lAncestors[0].Name);

    lResult := lIndex.ResolveQualifiedName('TypeUnitC.TQualifiedAlias');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    lAncestors := lIndex.FindAncestors(lResult.Identity);

    Assert.AreEqual(2, Length(lAncestors));
    Assert.AreEqual('TChild', lAncestors[0].Name);
    Assert.AreEqual('TBase', lAncestors[1].Name);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.PreservesDeclaredCanonicalAndUnderlyingAliasIdentities;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TAlias');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TAlias', lResult.Identity.Name);
    Assert.AreEqual('TChild', lResult.Identity.CanonicalName);
    Assert.AreEqual('class', lResult.Identity.UnderlyingName);
    Assert.AreEqual(lResult.Identity.UnderlyingName,
      lIndex.FindByUnderlyingId(lResult.Identity.UnderlyingId)[0].UnderlyingName);
    Assert.AreNotEqual(lResult.Identity.DeclaredId.Value,
      lResult.Identity.CanonicalId.Value);
    Assert.AreNotEqual(lResult.Identity.CanonicalId.Value,
      lResult.Identity.UnderlyingId.Value);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ReportsAmbiguousSimpleNames;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TShared');

    Assert.IsFalse(lResult.Found);
    Assert.IsTrue(lResult.Ambiguous);
    Assert.AreEqual('ambiguous', lResult.Status);
    Assert.AreEqual(2, Length(lResult.Candidates));
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ResolvesSimpleQualifiedAndVisibleTypeNames;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TBase');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitA', lResult.Identity.UnitName);

    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TChild');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TChild', lResult.Identity.Name);

    lResult := lIndex.ResolveVisibleName('TExternalOnly', 'TypeUnitA',
      ['TypeUnitA', 'TypeUnitC']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitC', lResult.Identity.UnitName);

    lResult := lIndex.ResolveVisibleName('TShared', 'TypeUnitA', ['TypeUnitA', 'TypeUnitB']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitA', lResult.Identity.UnitName);

    lResult := lIndex.ResolveVisibleName('TImplOnly', 'TypeUnitA', [],
      'implementation');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TImplOnly', lResult.Identity.Name);

    lResult := lIndex.ResolveVisibleName('TQualifiedAlias', 'TypeUnitA', ['TypeUnitC']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('class', lResult.Identity.UnderlyingName);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTypeResolverTests);

end.
