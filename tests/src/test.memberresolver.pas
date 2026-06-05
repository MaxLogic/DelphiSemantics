unit Test.MemberResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.MemberResolver,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TMemberResolverTests = class
  private
    function Graph: TDelphiSemanticSemanticGraph;
    function MemberIndex(const aGraph: TDelphiSemanticSemanticGraph):
      TDelphiSemanticMemberIdentityIndex;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ResolvesDirectMemberByOwnerAndName;
    [Test]
    procedure ResolvesAliasOwnerThroughCanonicalType;
    [Test]
    procedure ReportsAmbiguousUnresolvedAndUnsupportedOutcomes;
  end;

implementation

function TMemberResolverTests.Graph: TDelphiSemanticSemanticGraph;
begin
  Result := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel('MemberUnit'),
    UnitModel('OtherMemberUnit')]);
end;

function TMemberResolverTests.MemberIndex(const aGraph: TDelphiSemanticSemanticGraph):
  TDelphiSemanticMemberIdentityIndex;
var
  lTypeIndex: TDelphiSemanticTypeIdentityIndex;
begin
  lTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(aGraph);
  Result := TDelphiSemanticMemberResolver.BuildIndex(aGraph, lTypeIndex);
end;

function TMemberResolverTests.ProjectInfo: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectName := 'MemberResolverProject';
  Result.ContextFingerprint := 'member-resolver-context';
end;

function TMemberResolverTests.UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aUnitName + '.pas';

  if aUnitName = 'OtherMemberUnit' then
  begin
    SetLength(Result.Declarations, 1);
    Result.Declarations[0].Name := 'TBase';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'record';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;

    SetLength(Result.Members, 1);
    Result.Members[0].OwnerName := 'TBase';
    Result.Members[0].Name := 'Value';
    Result.Members[0].Kind := 'field';
    Result.Members[0].TypeName := 'string';
    Result.Members[0].Visibility := 'public';
    Result.Members[0].Line := 5;
    Result.Members[0].Column := 5;
    Exit;
  end;

  SetLength(Result.Declarations, 3);
  Result.Declarations[0].Name := 'TBase';
  Result.Declarations[0].Kind := 'type';
  Result.Declarations[0].TypeName := 'record';
  Result.Declarations[0].SectionKind := 'interface';
  Result.Declarations[0].Line := 4;
  Result.Declarations[0].Column := 3;
  Result.Declarations[1].Name := 'TAlias';
  Result.Declarations[1].Kind := 'type-alias';
  Result.Declarations[1].TypeName := 'TBase';
  Result.Declarations[1].SectionKind := 'interface';
  Result.Declarations[1].Line := 8;
  Result.Declarations[1].Column := 3;
  Result.Declarations[2].Name := 'TQualifiedAlias';
  Result.Declarations[2].Kind := 'type-alias';
  Result.Declarations[2].TypeName := 'OtherMemberUnit.TBase';
  Result.Declarations[2].SectionKind := 'interface';
  Result.Declarations[2].Line := 10;
  Result.Declarations[2].Column := 3;

  SetLength(Result.Members, 4);
  Result.Members[0].OwnerName := 'TBase';
  Result.Members[0].Name := 'Value';
  Result.Members[0].Kind := 'field';
  Result.Members[0].TypeName := 'Integer';
  Result.Members[0].Visibility := 'public';
  Result.Members[0].Line := 5;
  Result.Members[0].Column := 5;
  Result.Members[1].OwnerName := 'TBase';
  Result.Members[1].Name := 'Duplicate';
  Result.Members[1].Kind := 'field';
  Result.Members[1].TypeName := 'Integer';
  Result.Members[1].Visibility := 'public';
  Result.Members[1].Line := 6;
  Result.Members[1].Column := 5;
  Result.Members[2] := Result.Members[1];
  Result.Members[2].TypeName := 'string';
  Result.Members[2].Line := 7;
  Result.Members[3].OwnerName := 'TBase';
  Result.Members[3].Name := 'Items';
  Result.Members[3].Kind := 'property';
  Result.Members[3].TypeName := 'Integer';
  Result.Members[3].Visibility := 'public';
  Result.Members[3].IsIndexed := True;
  Result.Members[3].IsDefault := True;
  Result.Members[3].Line := 9;
  Result.Members[3].Column := 5;
end;

procedure TMemberResolverTests.ReportsAmbiguousUnresolvedAndUnsupportedOutcomes;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticMemberIdentityIndex;
  lResult: TDelphiSemanticMemberLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := MemberIndex(lGraph);

    lResult := lIndex.ResolveDirectMember('TBase', 'Duplicate');
    Assert.IsFalse(lResult.Found);
    Assert.IsTrue(lResult.Ambiguous);
    Assert.AreEqual('ambiguous', lResult.Status);
    Assert.AreEqual(2, Integer(Length(lResult.Candidates)));

    lResult := lIndex.ResolveDirectMember('TBase', 'Missing');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('unresolved', lResult.Status);

    lResult := lIndex.ResolveDirectMember('TBase', 'Items');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('unsupported', lResult.Status);
    Assert.AreEqual('INDEXED_DEFAULT_MEMBER_UNSUPPORTED', lResult.ReasonCode);
  finally
    lGraph.Free;
  end;
end;

procedure TMemberResolverTests.ResolvesAliasOwnerThroughCanonicalType;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticMemberIdentityIndex;
  lResult: TDelphiSemanticMemberLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := MemberIndex(lGraph);

  lResult := lIndex.ResolveDirectMember('TAlias', 'Value');

  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('TBase', lResult.Member.OwnerName);
  Assert.AreEqual('Integer', lResult.Member.TypeName);

  lResult := lIndex.ResolveDirectMember('MemberUnit.TBase', 'Value');
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('MemberUnit', lResult.Member.UnitName);
  Assert.AreEqual('Integer', lResult.Member.TypeName);

  lResult := lIndex.ResolveDirectMember('TQualifiedAlias', 'Value');
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('OtherMemberUnit', lResult.Member.UnitName);
  Assert.AreEqual('string', lResult.Member.TypeName);
  finally
    lGraph.Free;
  end;
end;

procedure TMemberResolverTests.ResolvesDirectMemberByOwnerAndName;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticMemberIdentityIndex;
  lResult: TDelphiSemanticMemberLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := MemberIndex(lGraph);

    lResult := lIndex.ResolveDirectMember('TBase', 'Value');
    Assert.IsFalse(lResult.Found);
    Assert.IsTrue(lResult.Ambiguous);

    lResult := lIndex.ResolveDirectMember('MemberUnit.TBase', 'Value');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('resolved', lResult.Status);
    Assert.AreEqual('field', lResult.Member.Kind);
    Assert.AreEqual('Integer', lResult.Member.TypeName);
    Assert.AreEqual('MemberUnit', lResult.Member.UnitName);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMemberResolverTests);

end.
