unit Test.ResolverLevel2;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve;

type
  [TestFixture]
  TResolverLevel2Tests = class
  private
    function FixturePath(const aFileName: string): string;
    function LoadInventoryModel: TDelphiSemanticUnitModel;
    function LoadModel: TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ResolvesAliasesArraysAndPointers;
    [Test]
    procedure ResolvesAliasMembersAndCurrentTypeMembers;
    [Test]
    procedure ResolvesArrayPointerAndIndexedSelectors;
    [Test]
    procedure ResolvesIndexedDefaultProperties;
    [Test]
    procedure NestedRoutineScopesSearchParentRoutines;
    [Test]
    procedure ResolvesInventoryDeclarationsAndImplementationGlobals;
    [Test]
    procedure DuplicateDirectMembersAreAmbiguous;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils;

function TResolverLevel2Tests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'Resolver', aFileName]));
end;

function TResolverLevel2Tests.LoadInventoryModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('InventoryResolverUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TResolverLevel2Tests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('Level2ResolverUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

procedure TResolverLevel2Tests.ResolvesAliasesArraysAndPointers;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TAliasRecord');

  Assert.IsTrue(lResult.Found, 'ArrayValue[0].Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('type-alias', lResult.Kind);
  Assert.AreEqual('TBaseRecord', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TPointerRecord');

  Assert.IsTrue(lResult.Found, 'PointerValue^.Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('type-alias', lResult.Kind);
  Assert.AreEqual('^TBaseRecord', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TRecordArray');

  Assert.IsTrue(lResult.Found, 'IndexedValue.Items[0].Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('type-alias', lResult.Kind);
  Assert.AreEqual('array[0..1] of TBaseRecord', lResult.TypeName);
end;

procedure TResolverLevel2Tests.ResolvesAliasMembersAndCurrentTypeMembers;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;

  lResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lModel, 'TAliasRecord', 'Value', 2);

  Assert.IsTrue(lResult.Found, 'TAliasRecord.Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.IsTrue(lResult.Authoritative, 'TAliasRecord.Value authoritative: ' + lResult.Status +
    '/' + lResult.ReasonCode);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
  Assert.AreEqual('TBaseRecord', lResult.OwnerName);

  lContext := Default(TDelphiSemanticResolveContext);
  lContext.CurrentTypeName := 'TAliasRecord';
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 2;

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Value');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
end;

procedure TResolverLevel2Tests.ResolvesArrayPointerAndIndexedSelectors;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'InnerScope';
  lContext.ParentRoutineNames := ['OuterScope'];
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 2;

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ArrayValue[0].Value');

  Assert.IsTrue(lResult.Found, 'ArrayValue[0].Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.IsTrue(lResult.Authoritative, 'ArrayValue[0].Value authoritative: ' + lResult.Status +
    '/' + lResult.ReasonCode);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ArrayValue[0]');

  Assert.IsTrue(lResult.Found, 'ArrayValue[0] found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('TBaseRecord', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'PointerValue^.Value');

  Assert.IsTrue(lResult.Found, 'PointerValue^.Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'PointerValue^');

  Assert.IsTrue(lResult.Found, 'PointerValue^ found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('TBaseRecord', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'IndexedValue.Items[0].Value');

  Assert.IsTrue(lResult.Found, 'IndexedValue.Items[0].Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'IndexedValue[0].Value');

  Assert.IsTrue(lResult.Found, 'IndexedValue[0].Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'IndexedValue[0]');

  Assert.IsTrue(lResult.Found, 'IndexedValue[0] found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('TBaseRecord', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext,
    'IndexedPointerValue[0]^.Value');

  Assert.IsTrue(lResult.Found, 'IndexedPointerValue[0]^.Value found: ' + lResult.Status + '/' +
    lResult.ReasonCode);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
end;

procedure TResolverLevel2Tests.ResolvesIndexedDefaultProperties;
var
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;

  lResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lModel, 'TIndexedRecord', 'Items', 2);

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('property', lResult.Kind);
  Assert.AreEqual('TBaseRecord', lResult.TypeName);
end;

procedure TResolverLevel2Tests.NestedRoutineScopesSearchParentRoutines;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'InnerScope';
  lContext.ParentRoutineNames := ['OuterScope'];
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 2;

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'OuterValue');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('local', lResult.Kind);
  Assert.AreEqual('TBaseRecord', lResult.TypeName);
  Assert.AreEqual('OuterScope', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'OuterParam');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('parameter', lResult.Kind);
  Assert.AreEqual('TBaseRecord', lResult.TypeName);
  Assert.AreEqual('OuterScope', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Shadowed');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('parameter', lResult.Kind);
  Assert.AreEqual('TIndexedRecord', lResult.TypeName);
  Assert.AreEqual('InnerScope', lResult.OwnerName);
end;

procedure TResolverLevel2Tests.ResolvesInventoryDeclarationsAndImplementationGlobals;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadInventoryModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 2;

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ikSecond');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('enum-value', lResult.Kind);
  Assert.AreEqual('TInventoryEnum', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'cTypedInventory');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('typed-const', lResult.Kind);
  Assert.AreEqual('TInventoryEnum', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'gImplementationRecord');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('var', lResult.Kind);
  Assert.AreEqual('TOverloadHolder', lResult.TypeName);

  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'interface';
  lContext.ConformanceLevel := 2;

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'gImplementationRecord');

  Assert.IsFalse(lResult.Found);
  Assert.AreEqual('NAME_NOT_FOUND', lResult.ReasonCode);
end;

procedure TResolverLevel2Tests.DuplicateDirectMembersAreAmbiguous;
var
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
  lMember: TDelphiSemanticMember;
  lLength: Integer;
begin
  lModel := LoadModel;
  lLength := Length(lModel.Members);
  SetLength(lModel.Members, lLength + 1);
  lMember := lModel.Members[0];
  lMember.OwnerName := 'TBaseRecord';
  lMember.Name := 'Value';
  lMember.TypeName := 'string';
  lModel.Members[lLength] := lMember;

  lResult := TDelphiSemanticResolver.ResolveMember(lModel, 'TBaseRecord', 'Value');

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.AreEqual('MULTIPLE_MEMBER_CANDIDATES', lResult.ReasonCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TResolverLevel2Tests);

end.
