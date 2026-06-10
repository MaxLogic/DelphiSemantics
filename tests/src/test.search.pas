unit Test.Search;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api,
  DelphiSemantics.Model,
  DelphiSemantics.Query,
  DelphiSemantics.Search,
  DelphiSemantics.Snapshot;

type
  [TestFixture]
  TSearchTests = class
  private
    function LoadContext: TDelphiSemanticSymbolQueryContext;
  public
    [Test]
    procedure FiltersSyntaxPatternByKindScopeUnitAndOwner;
    [Test]
    procedure CombinesPatternWithResolvedSymbolFilter;
    [Test]
    procedure SnapshotBackedSearchUsesProjectSnapshotIndex;
    [Test]
    procedure BlocksAmbiguousResolvedSymbolFilter;
  end;

implementation

function TSearchTests.LoadContext: TDelphiSemanticSymbolQueryContext;
var
  lSibling: TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticSymbolQueryContext);
  Result.UnitModel.UnitName := 'SearchMainUnit';
  Result.UnitModel.FileName := 'SearchMainUnit.pas';
  SetLength(Result.UnitModel.Declarations, 1);
  Result.UnitModel.Declarations[0].Name := 'SearchType';
  Result.UnitModel.Declarations[0].Kind := 'type';
  Result.UnitModel.Declarations[0].SectionKind := 'interface';
  Result.UnitModel.Declarations[0].Line := 3;
  Result.UnitModel.Declarations[0].Column := 3;

  lSibling := Default(TDelphiSemanticUnitModel);
  lSibling.UnitName := 'SearchSiblingUnit';
  lSibling.FileName := 'SearchSiblingUnit.pas';
  SetLength(lSibling.Routines, 1);
  lSibling.Routines[0].Name := 'SearchRoutine';
  lSibling.Routines[0].SectionKind := 'implementation';
  lSibling.Routines[0].Line := 20;
  lSibling.Routines[0].Column := 3;
  SetLength(lSibling.Members, 1);
  lSibling.Members[0].Name := 'SearchMember';
  lSibling.Members[0].Kind := 'property';
  lSibling.Members[0].OwnerName := 'TSearchOwner';
  lSibling.Members[0].Visibility := 'public';
  lSibling.Members[0].Line := 9;
  lSibling.Members[0].Column := 5;
  Result.IndexedUnitModels := [lSibling];
  Result.IndexedUnitSourceKinds := ['project-source'];
end;

procedure TSearchTests.FiltersSyntaxPatternByKindScopeUnitAndOwner;
var
  lQuery: TDelphiSemanticSearchQuery;
  lResult: TDelphiSemanticSearchResult;
begin
  lQuery := Default(TDelphiSemanticSearchQuery);
  lQuery.Pattern := 'Search';
  lQuery.DeclarationKind := 'routine';
  lQuery.Scope := 'implementation';
  lQuery.UnitName := 'SearchSiblingUnit';

  lResult := TDelphiSemanticApi.Search(LoadContext, lQuery);

  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual(1, Integer(Length(lResult.Matches)));
  Assert.AreEqual('SearchRoutine', lResult.Matches[0].Name);
  Assert.AreEqual('syntax-only', lResult.Matches[0].MatchKind);

  lQuery := Default(TDelphiSemanticSearchQuery);
  lQuery.Pattern := 'Search';
  lQuery.OwnerName := 'TSearchOwner';
  lQuery.DeclarationKind := 'property';

  lResult := TDelphiSemanticApi.Search(LoadContext, lQuery);

  Assert.AreEqual(1, Integer(Length(lResult.Matches)));
  Assert.AreEqual('SearchMember', lResult.Matches[0].Name);
  Assert.AreEqual('TSearchOwner', lResult.Matches[0].OwnerName);
end;

procedure TSearchTests.CombinesPatternWithResolvedSymbolFilter;
var
  lQuery: TDelphiSemanticSearchQuery;
  lResult: TDelphiSemanticSearchResult;
begin
  lQuery := Default(TDelphiSemanticSearchQuery);
  lQuery.Pattern := 'Search';
  lQuery.DeclarationKind := 'type';
  lQuery.ResolvedSymbolName := 'SearchType';

  lResult := TDelphiSemanticApi.Search(LoadContext, lQuery);

  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual(1, Integer(Length(lResult.Matches)));
  Assert.AreEqual('SearchType', lResult.Matches[0].Name);
  Assert.AreEqual('semantic', lResult.Matches[0].MatchKind);
  Assert.IsTrue(lResult.Matches[0].SymbolId.Value <> '');
end;

procedure TSearchTests.SnapshotBackedSearchUsesProjectSnapshotIndex;
var
  lBuilder: TDelphiProjectSnapshotBuilder;
  lContext: TDelphiSemanticSymbolQueryContext;
  lProject: TDelphiProjectSnapshot;
  lQuery: TDelphiSemanticSearchQuery;
  lResult: TDelphiSemanticSearchResult;
  lAliasSymbol: TSemanticSymbolFact;
  lSymbol: TSemanticSymbolFact;
  lUnit: TUnitSnapshot;
begin
  lBuilder := TDelphiProjectSnapshotBuilder.Create;
  lProject := nil;
  try
    lUnit := TUnitSnapshot.Create(1, lBuilder.Strings.Intern('SnapshotSearchUnit.pas'),
      lBuilder.Strings.Intern('SnapshotSearchUnit'));
    try
      lSymbol := Default(TSemanticSymbolFact);
      lSymbol.NameId := lBuilder.Strings.Intern('SnapshotSearchType');
      lSymbol.KindId := lBuilder.Strings.Intern('type');
      lSymbol.SectionKindId := lBuilder.Strings.Intern('interface');
      lSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lSymbol.Line := 5;
      lSymbol.Column := 3;
      lSymbol.EndLine := 5;
      lSymbol.EndColumn := 20;
      lUnit.AddSymbol(lSymbol);

      lAliasSymbol := Default(TSemanticSymbolFact);
      lAliasSymbol.NameId := lBuilder.Strings.Intern('SnapshotSearchAlias');
      lAliasSymbol.KindId := lBuilder.Strings.Intern('alias');
      lAliasSymbol.SectionKindId := lBuilder.Strings.Intern('interface');
      lAliasSymbol.SourceKindId := lBuilder.Strings.Intern('project-source');
      lAliasSymbol.Line := 6;
      lAliasSymbol.Column := 3;
      lAliasSymbol.EndLine := 6;
      lAliasSymbol.EndColumn := 21;
      lUnit.AddSymbol(lAliasSymbol);

      lBuilder.AddUnit(lUnit);
      lUnit := nil;
    finally
      lUnit.Free;
    end;
    lProject := lBuilder.Build;
  finally
    lBuilder.Free;
  end;

  try
    lContext := Default(TDelphiSemanticSymbolQueryContext);
    lContext.ProjectSnapshot := BorrowProjectSnapshot(lProject);
    lQuery := Default(TDelphiSemanticSearchQuery);
    lQuery.Pattern := 'SnapshotSearch';
    lQuery.DeclarationKind := 'type';
    lQuery.ResolvedSymbolName := 'SnapshotSearchType';

    lResult := TDelphiSemanticApi.Search(lContext, lQuery);

    Assert.AreEqual('resolved', lResult.Status);
    Assert.AreEqual(1, Integer(Length(lResult.Matches)));
    Assert.AreEqual('SnapshotSearchType', lResult.Matches[0].Name);
    Assert.AreEqual('semantic', lResult.Matches[0].MatchKind);

    lQuery := Default(TDelphiSemanticSearchQuery);
    lQuery.Pattern := 'SnapshotSearchAlias';
    lQuery.DeclarationKind := 'type-alias';

    lResult := TDelphiSemanticApi.Search(lContext, lQuery);

    Assert.AreEqual('resolved', lResult.Status);
    Assert.AreEqual(1, Integer(Length(lResult.Matches)));
    Assert.AreEqual('SnapshotSearchAlias', lResult.Matches[0].Name);
    Assert.AreEqual('type-alias', lResult.Matches[0].Kind);
  finally
    lProject.Free;
  end;
end;

procedure TSearchTests.BlocksAmbiguousResolvedSymbolFilter;
var
  lContext: TDelphiSemanticSymbolQueryContext;
  lQuery: TDelphiSemanticSearchQuery;
  lResult: TDelphiSemanticSearchResult;
begin
  lContext := LoadContext;
  lContext.IndexedUnitModels[0].Declarations := lContext.IndexedUnitModels[0].Declarations +
    lContext.UnitModel.Declarations;
  lQuery := Default(TDelphiSemanticSearchQuery);
  lQuery.Pattern := 'Search';
  lQuery.ResolvedSymbolName := 'SearchType';

  lResult := TDelphiSemanticApi.Search(lContext, lQuery);

  Assert.AreEqual('blocked', lResult.Status);
  Assert.AreEqual('resolved-symbol-ambiguous', lResult.Diagnostic);
end;

initialization
  TDUnitX.RegisterTestFixture(TSearchTests);

end.
