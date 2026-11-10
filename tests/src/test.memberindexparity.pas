unit Test.MemberIndexParity;

interface

uses
  DelphiSemantics.SemanticGraph;

// Both indexes consume the same admitted graph. JSON compares every returned
// record field, refusal and candidate position without normalizing identities.
procedure AssertMemberIndexMatchesLegacy(const aGraph: TDelphiSemanticSemanticGraph;
  out aQueries, aFound, aRefused: Int64);

implementation

uses
  System.JSON.Serializers, System.SysUtils,
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve.MemberResolver,
  DelphiSemantics.Resolve.TypeResolver,
  Test.MemberResolver.Legacy809;

type
  [TestFixture]
  TMemberIndexParityTests = class
  public
    [TestCase('empty', '0')]
    [TestCase('ordinary and conflicting IDs', '1')]
    [TestCase('local overlap and scoped owner', '2')]
    [TestCase('non-ASCII names', '3')]
    [Category('Fast')]
    procedure GeneratedGraphMatchesLegacy(const aShape: Integer);
    [Test]
    [Category('Fast')]
    procedure ArraySnapshotsRemainIndependent;
  end;

function GeneratedGraph(const aShape: Integer): TDelphiSemanticSemanticGraph;
var
  i: Integer;
  lMembers: TArray<TDelphiSemanticGraphMember>;
  lRoutines: TArray<TDelphiSemanticGraphRoutine>;
  lTypes: TArray<TDelphiSemanticGraphType>;
  lUnits: TArray<TDelphiSemanticGraphUnit>;
begin
  if aShape = 0 then
    Exit(TDelphiSemanticSemanticGraph.Create(Default(TDelphiSemanticProjectGraphId),
      nil, nil, nil, nil, nil, nil, nil, nil, Default(TDelphiSemanticGraphBuildMetrics)));
  SetLength(lUnits, 2);
  for i := 0 to High(lUnits) do
  begin
    lUnits[i].Id.Value := 'unit' + IntToStr(i);
    lUnits[i].UnitName := 'Unit' + IntToStr(i);
  end;
  SetLength(lTypes, 5);
  for i := 0 to High(lTypes) do
  begin
    lTypes[i].UnitId := lUnits[0].Id;
    lTypes[i].Name := 'TItem';
    lTypes[i].DeclaredId.Value := 'type' + IntToStr(i);
    lTypes[i].SemanticSymbolId := 'symbol' + IntToStr(i);
    lTypes[i].ScopeKind := 'unit';
    lTypes[i].Kind := 'record';
    lTypes[i].SourceRange.Line := 5 + i;
  end;
  // Exact duplicate followed by conflicting IDs exercises the immediate break.
  lTypes[1] := lTypes[0];
  lTypes[3].UnitId := lUnits[1].Id;
  lTypes[4].Name := 'TMissingMembers';
  SetLength(lMembers, 8);
  for i := 0 to High(lMembers) do
  begin
    lMembers[i].UnitId := lUnits[0].Id;
    lMembers[i].SymbolId.Value := 'member' + IntToStr(i);
    lMembers[i].OwnerName := 'TItem';
    lMembers[i].Name := 'Value' + IntToStr(i mod 3);
    lMembers[i].Kind := 'field';
    lMembers[i].Visibility := 'public';
    lMembers[i].TypeName := 'Integer';
    lMembers[i].SourceRange.Line := 10 + i;
  end;
  lMembers[1].Visibility := 'private';
  lMembers[2].Kind := 'property';
  lMembers[2].IsIndexed := True;
  lMembers[2].IsDefault := True;
  lMembers[3].Kind := 'function';
  lMembers[3].Signature := 'function Value0(aValue: Integer): Integer';
  lMembers[4].UnitId := lUnits[1].Id;
  lMembers[5].OwnerName := 'TUnknown';
  SetLength(lRoutines, 2);
  for i := 0 to High(lRoutines) do
  begin
    lRoutines[i].UnitId := lUnits[0].Id;
    lRoutines[i].Name := 'Outer';
    lRoutines[i].ScopeId := 'outer';
    lRoutines[i].SourceRange.Line := 100;
    lRoutines[i].SourceRange.EndLine := 200;
  end;
  if aShape = 2 then
  begin
    lTypes[2].Name := 'TLocal';
    lTypes[2].ScopeKind := 'routine';
    lTypes[2].OwnerScopeId := 'outer';
    lMembers[6].OwnerName := 'TLocal';
    lMembers[7] := lMembers[6];
    lMembers[7].SymbolId.Value := 'scoped';
    lMembers[7].OwnerScopeId := 'outer';
    lMembers[7].OwnerSemanticSymbolId := lTypes[2].SemanticSymbolId;
  end;
  if aShape = 3 then
  begin
    lTypes[0].Name := 'T' + Char($00C4);
    lTypes[1].Name := 'T' + Char($00E4);
    lTypes[1].DeclaredId.Value := 'lower';
    lMembers[0].OwnerName := lTypes[0].Name;
    lMembers[1].OwnerName := lTypes[1].Name;
  end;
  Result := TDelphiSemanticSemanticGraph.Create(Default(TDelphiSemanticProjectGraphId),
    lUnits, nil, nil, lTypes, lMembers, lRoutines, nil, nil,
    Default(TDelphiSemanticGraphBuildMetrics));
end;

procedure AssertMemberIndexMatchesLegacy(const aGraph: TDelphiSemanticSemanticGraph;
  out aQueries, aFound, aRefused: Int64);
var
  i, j: Integer;
  lIndex: DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberIdentityIndex;
  lLegacy: Test.MemberResolver.Legacy809.TDelphiSemanticMemberIdentityIndex;
  lContext: DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberLookupContext;
  lOldContext: Test.MemberResolver.Legacy809.TDelphiSemanticMemberLookupContext;
  lMembers: TArray<TDelphiSemanticGraphMember>;
  lTypes: TArray<TDelphiSemanticGraphType>;
  lUnits: TArray<TDelphiSemanticGraphUnit>;
  lTypeIndex: TDelphiSemanticTypeIdentityIndex;
  lSerializer: TJsonSerializer;

  procedure Equal(const aOld: Test.MemberResolver.Legacy809.TDelphiSemanticMemberLookupResult;
    const aNew: DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberLookupResult);
  var
    lOldJson, lNewJson: string;
  begin
    lOldJson := lSerializer.Serialize<Test.MemberResolver.Legacy809.TDelphiSemanticMemberLookupResult>(aOld);
    lNewJson := lSerializer.Serialize<DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberLookupResult>(aNew);
    if lOldJson <> lNewJson then
      Assert.AreEqual(lOldJson, lNewJson, 'DS-809 ordered member lookup parity');
    Inc(aQueries);
    if aOld.Found then
      Inc(aFound)
    else
      Inc(aRefused);
  end;

  procedure Query(const aOwner, aName: string; const aTypeId: TDelphiSemanticGraphTypeId);
  var
    k: Integer;
  begin
    Equal(lLegacy.ResolveDirectMember(aOwner, aName), lIndex.ResolveDirectMember(aOwner, aName));
    Equal(lLegacy.ResolveDirectMemberByOwnerId(aTypeId, aName), lIndex.ResolveDirectMemberByOwnerId(aTypeId, aName));
    Equal(lLegacy.ResolveMember(aOwner, aName), lIndex.ResolveMember(aOwner, aName));
    for k := 0 to 5 do
    begin
      lContext := Default(DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberLookupContext);
      lContext.OwnerDeclaredId := aTypeId;
      if k > 0 then
      begin
        lContext.CurrentTypeName := aOwner;
        lContext.CurrentTypeId := aTypeId;
        if Length(lUnits) > 0 then
          lContext.CallerUnitName := lUnits[0].UnitName;
      end;
      lContext.StaticContext := k = 2;
      lContext.InstanceContext := k = 3;
      if k = 4 then
        lContext.ArgumentTypeNames := ['Integer'];
      if k = 5 then
      begin
        lContext.CallerUnitName := 'ForeignCaller809';
        lContext.ArgumentTypeNames := ['String', 'Integer'];
      end;
      lOldContext.CallerUnitName := lContext.CallerUnitName;
      lOldContext.CurrentTypeName := lContext.CurrentTypeName;
      lOldContext.CurrentTypeId := lContext.CurrentTypeId;
      lOldContext.OwnerDeclaredId := lContext.OwnerDeclaredId;
      lOldContext.StaticContext := lContext.StaticContext;
      lOldContext.InstanceContext := lContext.InstanceContext;
      lOldContext.ArgumentTypeNames := lContext.ArgumentTypeNames;
      Equal(lLegacy.ResolveMember(lOldContext, aOwner, aName),
        lIndex.ResolveMember(lContext, aOwner, aName));
    end;
  end;

begin
  aQueries := 0;
  aFound := 0;
  aRefused := 0;
  lTypes := aGraph.Types;
  lMembers := aGraph.Members;
  lUnits := aGraph.Units;
  lTypeIndex := TDelphiSemanticTypeResolver.BuildIndex(aGraph);
  lLegacy := Test.MemberResolver.Legacy809.TDelphiSemanticMemberResolver.BuildIndex(aGraph, lTypeIndex);
  lIndex := DelphiSemantics.Resolve.MemberResolver.TDelphiSemanticMemberResolver.BuildIndex(aGraph, lTypeIndex);
  lSerializer := TJsonSerializer.Create;
  try
    Query('MissingType809', 'MissingMember809', Default(TDelphiSemanticGraphTypeId));
    for i := 0 to High(lTypes) do
    begin
      Query(lTypes[i].Name, 'MissingMember809', lTypes[i].DeclaredId);
      // Probe each type's own names, including scoped owners, without a full
      // cross-product of unrelated type/member names in large SOAP models.
      for j := 0 to High(lMembers) do
        if SameText(lMembers[j].OwnerName, lTypes[i].Name) then
          Query(lTypes[i].Name, lMembers[j].Name, lTypes[i].DeclaredId);
    end;
    for i := 0 to High(lMembers) do
    begin
      Query(lMembers[i].OwnerName, lMembers[i].Name, Default(TDelphiSemanticGraphTypeId));
      for j := 0 to High(lUnits) do
        if lUnits[j].Id.Value = lMembers[i].UnitId.Value then
          Query(lUnits[j].UnitName + '.' + lMembers[i].OwnerName,
            lMembers[i].Name, Default(TDelphiSemanticGraphTypeId));
    end;
  finally
    lSerializer.Free;
  end;
end;

procedure TMemberIndexParityTests.GeneratedGraphMatchesLegacy(const aShape: Integer);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lQueries, lFound, lRefused: Int64;
begin
  lGraph := GeneratedGraph(aShape);
  try
    AssertMemberIndexMatchesLegacy(lGraph, lQueries, lFound, lRefused);
    Assert.IsTrue(lQueries > 0);
    Assert.IsTrue(lRefused > 0);
    if aShape <> 0 then
      Assert.IsTrue(lFound > 0);
  finally
    lGraph.Free;
  end;
end;

procedure TMemberIndexParityTests.ArraySnapshotsRemainIndependent;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lMembers: TArray<TDelphiSemanticGraphMember>;
  lRoutines: TArray<TDelphiSemanticGraphRoutine>;
  lTypes: TArray<TDelphiSemanticGraphType>;
  lUnits: TArray<TDelphiSemanticGraphUnit>;
begin
  lGraph := GeneratedGraph(1);
  try
    lTypes := lGraph.Types;
    lMembers := lGraph.Members;
    lRoutines := lGraph.Routines;
    lUnits := lGraph.Units;
    lTypes[0].Name := 'Changed';
    lMembers[0].Name := 'Changed';
    lRoutines[0].Name := 'Changed';
    lUnits[0].UnitName := 'Changed';
    Assert.AreEqual('TItem', lGraph.Types[0].Name);
    Assert.AreEqual('Value0', lGraph.Members[0].Name);
    Assert.AreEqual('Outer', lGraph.Routines[0].Name);
    Assert.AreEqual('Unit0', lGraph.Units[0].UnitName);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TMemberIndexParityTests);

end.
