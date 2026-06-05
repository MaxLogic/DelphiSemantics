unit Test.MemberResolverAccessOverloads;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.MemberResolver,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TMemberResolverAccessOverloadTests = class
  private
    function Graph: TDelphiSemanticSemanticGraph;
    function MemberIndex(const aGraph: TDelphiSemanticSemanticGraph):
      TDelphiSemanticMemberIdentityIndex;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel: TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ReportsInaccessibleHiddenAndResolvedMembers;
    [Test]
    procedure ReportsOverloadedAndResolvesByArgumentType;
  end;

implementation

function TMemberResolverAccessOverloadTests.Graph: TDelphiSemanticSemanticGraph;
begin
  Result := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel]);
end;

function TMemberResolverAccessOverloadTests.MemberIndex(
  const aGraph: TDelphiSemanticSemanticGraph): TDelphiSemanticMemberIdentityIndex;
var
  lTypeIndex: TDelphiSemanticTypeIdentityIndex;
begin
  lTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(aGraph);
  Result := TDelphiSemanticMemberResolver.BuildIndex(aGraph, lTypeIndex);
end;

function TMemberResolverAccessOverloadTests.ProjectInfo: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectName := 'MemberResolverAccessOverloadProject';
  Result.ContextFingerprint := 'member-resolver-access-overload-context';
end;

function TMemberResolverAccessOverloadTests.UnitModel: TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := 'MemberAccessUnit';
  Result.FileName := 'MemberAccessUnit.pas';

  SetLength(Result.Declarations, 3);
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
  Result.Declarations[1].Line := 12;
  Result.Declarations[1].Column := 3;
  Result.Declarations[2].Name := 'TOtherChild';
  Result.Declarations[2].Kind := 'type';
  Result.Declarations[2].TypeName := 'class';
  Result.Declarations[2].BaseTypeName := 'TBase';
  Result.Declarations[2].SectionKind := 'interface';
  Result.Declarations[2].Line := 18;
  Result.Declarations[2].Column := 3;

  SetLength(Result.Members, 10);
  Result.Members[0].OwnerName := 'TBase';
  Result.Members[0].Name := 'Secret';
  Result.Members[0].Kind := 'field';
  Result.Members[0].TypeName := 'Integer';
  Result.Members[0].Visibility := 'private';
  Result.Members[0].Line := 5;
  Result.Members[0].Column := 5;
  Result.Members[1].OwnerName := 'TBase';
  Result.Members[1].Name := 'Visible';
  Result.Members[1].Kind := 'field';
  Result.Members[1].TypeName := 'Integer';
  Result.Members[1].Visibility := 'public';
  Result.Members[1].Line := 6;
  Result.Members[1].Column := 5;
  Result.Members[2].OwnerName := 'TChild';
  Result.Members[2].Name := 'Visible';
  Result.Members[2].Kind := 'field';
  Result.Members[2].TypeName := 'string';
  Result.Members[2].Visibility := 'public';
  Result.Members[2].Line := 13;
  Result.Members[2].Column := 5;
  Result.Members[3].OwnerName := 'TBase';
  Result.Members[3].Name := 'StrictSecret';
  Result.Members[3].Kind := 'field';
  Result.Members[3].TypeName := 'Integer';
  Result.Members[3].Visibility := 'strict private';
  Result.Members[3].Line := 7;
  Result.Members[3].Column := 5;
  Result.Members[4].OwnerName := 'TBase';
  Result.Members[4].Name := 'ProtectedValue';
  Result.Members[4].Kind := 'field';
  Result.Members[4].TypeName := 'Integer';
  Result.Members[4].Visibility := 'protected';
  Result.Members[4].Line := 8;
  Result.Members[4].Column := 5;
  Result.Members[5].OwnerName := 'TBase';
  Result.Members[5].Name := 'Pick';
  Result.Members[5].Kind := 'method';
  Result.Members[5].TypeName := 'string';
  Result.Members[5].Visibility := 'public';
  Result.Members[5].Signature := 'Pick(const aValue: Integer): string';
  Result.Members[5].Line := 9;
  Result.Members[5].Column := 5;
  Result.Members[6] := Result.Members[5];
  Result.Members[6].Signature := 'Pick(const aValue: string): string';
  Result.Members[6].Line := 10;
  Result.Members[7].OwnerName := 'TBase';
  Result.Members[7].Name := 'Duplicate';
  Result.Members[7].Kind := 'field';
  Result.Members[7].TypeName := 'Integer';
  Result.Members[7].Visibility := 'public';
  Result.Members[7].Line := 11;
  Result.Members[7].Column := 5;
  Result.Members[8] := Result.Members[7];
  Result.Members[8].TypeName := 'string';
  Result.Members[8].Line := 12;
  Result.Members[9] := Result.Members[5];
  Result.Members[9].Name := 'Pair';
  Result.Members[9].Signature := 'Pair(const aLeft, aRight: Integer): string';
  Result.Members[9].Line := 14;
end;

procedure TMemberResolverAccessOverloadTests.ReportsInaccessibleHiddenAndResolvedMembers;
var
  lContext: TDelphiSemanticMemberLookupContext;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticMemberIdentityIndex;
  lResult: TDelphiSemanticMemberLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := MemberIndex(lGraph);
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := 'OtherUnit';

    lResult := lIndex.ResolveMember(lContext, 'TBase', 'Secret');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('inaccessible', lResult.Status);

    lContext.CallerUnitName := 'MemberAccessUnit';
    lResult := lIndex.ResolveMember(lContext, 'TBase', 'StrictSecret');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('inaccessible', lResult.Status);

    lContext.CallerUnitName := 'OtherUnit';
    lContext.CurrentTypeName := 'TOtherChild';
    lResult := lIndex.ResolveMember(lContext, 'TBase', 'ProtectedValue');
    Assert.IsTrue(lResult.Found, lResult.Reason);

    lContext.CurrentTypeName := '';
    lResult := lIndex.ResolveMember(lContext, 'TChild', 'Visible');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('hidden', lResult.Status);

    lResult := lIndex.ResolveMember(lContext, 'TChild', 'Secret');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('inaccessible', lResult.Status);
  finally
    lGraph.Free;
  end;
end;

procedure TMemberResolverAccessOverloadTests.ReportsOverloadedAndResolvesByArgumentType;
var
  lContext: TDelphiSemanticMemberLookupContext;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticMemberIdentityIndex;
  lResult: TDelphiSemanticMemberLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := MemberIndex(lGraph);
    lContext := Default(TDelphiSemanticMemberLookupContext);
    lContext.CallerUnitName := 'MemberAccessUnit';

    lResult := lIndex.ResolveMember(lContext, 'TBase', 'Pick');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('overloaded', lResult.Status);
    Assert.AreEqual(2, Integer(Length(lResult.Candidates)));

    lResult := lIndex.ResolveMember(lContext, 'TBase', 'Duplicate');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('ambiguous', lResult.Status);

    lContext.ArgumentTypeNames := ['Integer'];
    lResult := lIndex.ResolveMember(lContext, 'TBase', 'Pick');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('resolved', lResult.Status);
    Assert.AreEqual('Pick(const aValue: Integer): string', lResult.Member.Signature);

    lContext.ArgumentTypeNames := ['Integer', 'Integer'];
    lResult := lIndex.ResolveMember(lContext, 'TBase', 'Pair');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('Pair(const aLeft, aRight: Integer): string', lResult.Member.Signature);

    lContext.ArgumentTypeNames := ['Boolean'];
    lResult := lIndex.ResolveMember(lContext, 'TBase', 'Pick');
    Assert.IsFalse(lResult.Found);
    Assert.AreEqual('unresolved', lResult.Status);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMemberResolverAccessOverloadTests);

end.
