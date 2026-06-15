unit Test.ResolverLevel3;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve;

type
  [TestFixture]
  TResolverLevel3Tests = class
  private
    function LoadModel(const aFileName: string): TDelphiSemanticUnitModel;
  public
    [Test]
    procedure ResolvesInheritedMembers;
    [Test]
    procedure ResolvesHelperMembers;
    [Test]
    procedure ResolvesCompilerIntrinsicProfiles;
    [Test]
    procedure ResolvesSourceAvailableIndexedUnits;
    [Test]
    procedure ResolvesInterfaceAncestorsAndAmbiguousOverloads;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils,
  Test.Support;


function TResolverLevel3Tests.LoadModel(const aFileName: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('Resolver', aFileName);
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

procedure TResolverLevel3Tests.ResolvesInheritedMembers;
var
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel('Level3ResolverUnit.pas');

  lResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lModel, 'TChildClass', 'BaseValue', 3);

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
  Assert.AreEqual('TBaseClass', lResult.OwnerName);
end;

procedure TResolverLevel3Tests.ResolvesHelperMembers;
var
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel('Level3ResolverUnit.pas');

  lResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lModel, 'TChildRecord', 'HelperValue', 3);

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('method', lResult.Kind);
  Assert.AreEqual('Boolean', lResult.TypeName);
  Assert.AreEqual('TChildRecordHelper', lResult.OwnerName);
end;

procedure TResolverLevel3Tests.ResolvesCompilerIntrinsicProfiles;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel('Level3ResolverUnit.pas');
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Length');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('intrinsic-routine', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
  Assert.AreEqual('compiler', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TObject');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('intrinsic-type', lResult.Kind);
  Assert.AreEqual('class', lResult.TypeName);
  Assert.AreEqual('rtl', lResult.OwnerName);
end;

procedure TResolverLevel3Tests.ResolvesSourceAvailableIndexedUnits;
var
  lContext: TDelphiSemanticResolveContext;
  lIndexedModel: TDelphiSemanticUnitModel;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel('Level3ResolverUnit.pas');
  lIndexedModel := LoadModel('Level3IndexedUnit.pas');
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := [lIndexedModel];

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TIndexedExternalRecord');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('type', lResult.Kind);
  Assert.AreEqual('record', lResult.TypeName);
  Assert.AreEqual('Level3IndexedUnit', lResult.OwnerName);

  lContext.IndexedUnitModels := [lIndexedModel, lIndexedModel];

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TIndexedExternalRecord');

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.AreEqual('MULTIPLE_INDEXED_DECLARATIONS', lResult.ReasonCode);
end;

procedure TResolverLevel3Tests.ResolvesInterfaceAncestorsAndAmbiguousOverloads;
var
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel('InventoryResolverUnit.pas');

  lResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lModel, 'IInventoryChild',
    'BaseName', 3);

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('method', lResult.Kind);
  Assert.AreEqual('string', lResult.TypeName);
  Assert.AreEqual('IInventoryBase', lResult.OwnerName);

  lResult := TDelphiSemanticResolver.ResolveMemberAtLevel(lModel, 'TOverloadHolder', 'Pick', 3);

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.AreEqual('MULTIPLE_MEMBER_CANDIDATES', lResult.ReasonCode);
end;

initialization
  TDUnitX.RegisterTestFixture(TResolverLevel3Tests);

end.
