unit Test.MemberResolverInheritedHelpers;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.MemberResolver,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TMemberResolverInheritedHelperTests = class
  private
    function Graph: TDelphiSemanticSemanticGraph;
    function MemberIndex(const aGraph: TDelphiSemanticSemanticGraph):
      TDelphiSemanticMemberIdentityIndex;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel: TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ResolvesInheritedMembersFromAncestorTypes;
    [Test]
    procedure ResolvesHelperProvidedMembersForTargetTypes;
  end;

implementation

function TMemberResolverInheritedHelperTests.Graph: TDelphiSemanticSemanticGraph;
begin
  Result := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
end;

function TMemberResolverInheritedHelperTests.MemberIndex(
  const aGraph: TDelphiSemanticSemanticGraph): TDelphiSemanticMemberIdentityIndex;
var
  lTypeIndex: TDelphiSemanticTypeIdentityIndex;
begin
  lTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(aGraph);
  Result := TDelphiSemanticMemberResolver.BuildIndex(aGraph, lTypeIndex);
end;

function TMemberResolverInheritedHelperTests.ProjectInfo: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectName := 'MemberResolverInheritedHelperProject';
  Result.ContextFingerprint := 'member-resolver-inherited-helper-context';
end;

function TMemberResolverInheritedHelperTests.UnitModel: TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := 'MemberInheritedUnit';
  Result.FileName := 'MemberInheritedUnit.pas';

  SetLength(Result.Declarations, 8);
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
  Result.Declarations[1].Line := 8;
  Result.Declarations[1].Column := 3;
  Result.Declarations[2].Name := 'TRecord';
  Result.Declarations[2].Kind := 'type';
  Result.Declarations[2].TypeName := 'record';
  Result.Declarations[2].SectionKind := 'interface';
  Result.Declarations[2].Line := 12;
  Result.Declarations[2].Column := 3;
  Result.Declarations[3].Name := 'TRecordHelper';
  Result.Declarations[3].Kind := 'type';
  Result.Declarations[3].TypeName := 'record';
  Result.Declarations[3].HelperTargetName := 'TRecord';
  Result.Declarations[3].SectionKind := 'interface';
  Result.Declarations[3].Line := 16;
  Result.Declarations[3].Column := 3;
  Result.Declarations[4].Name := 'TRecordAlias';
  Result.Declarations[4].Kind := 'type-alias';
  Result.Declarations[4].TypeName := 'TRecord';
  Result.Declarations[4].SectionKind := 'interface';
  Result.Declarations[4].Line := 20;
  Result.Declarations[4].Column := 3;
  Result.Declarations[5].Name := 'TQualifiedRecordHelper';
  Result.Declarations[5].Kind := 'type';
  Result.Declarations[5].TypeName := 'record';
  Result.Declarations[5].HelperTargetName := 'MemberInheritedUnit.TRecord';
  Result.Declarations[5].SectionKind := 'interface';
  Result.Declarations[5].Line := 24;
  Result.Declarations[5].Column := 3;
  Result.Declarations[6].Name := 'TOrderedLateTargetHelper';
  Result.Declarations[6].Kind := 'type';
  Result.Declarations[6].TypeName := 'record';
  Result.Declarations[6].HelperTargetName := 'TLateTarget';
  Result.Declarations[6].SectionKind := 'interface';
  Result.Declarations[6].Line := 28;
  Result.Declarations[6].Column := 3;
  Result.Declarations[7].Name := 'TLateTarget';
  Result.Declarations[7].Kind := 'type';
  Result.Declarations[7].TypeName := 'record';
  Result.Declarations[7].SectionKind := 'interface';
  Result.Declarations[7].Line := 32;
  Result.Declarations[7].Column := 3;

  SetLength(Result.Members, 4);
  Result.Members[0].OwnerName := 'TBase';
  Result.Members[0].Name := 'BaseValue';
  Result.Members[0].Kind := 'field';
  Result.Members[0].TypeName := 'Integer';
  Result.Members[0].Visibility := 'public';
  Result.Members[0].Line := 5;
  Result.Members[0].Column := 5;
  Result.Members[1].OwnerName := 'TRecordHelper';
  Result.Members[1].Name := 'HelperValue';
  Result.Members[1].Kind := 'method';
  Result.Members[1].TypeName := 'Boolean';
  Result.Members[1].Visibility := 'public';
  Result.Members[1].Line := 17;
  Result.Members[1].Column := 5;
  Result.Members[2].OwnerName := 'TQualifiedRecordHelper';
  Result.Members[2].Name := 'QualifiedHelperValue';
  Result.Members[2].Kind := 'method';
  Result.Members[2].TypeName := 'string';
  Result.Members[2].Visibility := 'public';
  Result.Members[2].Line := 25;
  Result.Members[2].Column := 5;
  Result.Members[3].OwnerName := 'TOrderedLateTargetHelper';
  Result.Members[3].Name := 'LateHelperValue';
  Result.Members[3].Kind := 'method';
  Result.Members[3].TypeName := 'Currency';
  Result.Members[3].Visibility := 'public';
  Result.Members[3].Line := 29;
  Result.Members[3].Column := 5;
end;

procedure TMemberResolverInheritedHelperTests.ResolvesHelperProvidedMembersForTargetTypes;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticMemberIdentityIndex;
  lResult: TDelphiSemanticMemberLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := MemberIndex(lGraph);

    lResult := lIndex.ResolveMember('TRecord', 'HelperValue');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('helper', lResult.Status);
    Assert.AreEqual('TRecordHelper', lResult.Member.OwnerName);
    Assert.AreEqual('Boolean', lResult.Member.TypeName);

    lResult := lIndex.ResolveMember('TRecordAlias', 'QualifiedHelperValue');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('helper', lResult.Status);
    Assert.AreEqual('TQualifiedRecordHelper', lResult.Member.OwnerName);
    Assert.AreEqual('string', lResult.Member.TypeName);

    lResult := lIndex.ResolveMember('TLateTarget', 'LateHelperValue');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('helper', lResult.Status);
    Assert.AreEqual('TOrderedLateTargetHelper', lResult.Member.OwnerName);
  finally
    lGraph.Free;
  end;
end;

procedure TMemberResolverInheritedHelperTests.ResolvesInheritedMembersFromAncestorTypes;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticMemberIdentityIndex;
  lResult: TDelphiSemanticMemberLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := MemberIndex(lGraph);

    lResult := lIndex.ResolveMember('TChild', 'BaseValue');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('inherited', lResult.Status);
    Assert.AreEqual('TBase', lResult.Member.OwnerName);
    Assert.AreEqual('Integer', lResult.Member.TypeName);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMemberResolverInheritedHelperTests);

end.
