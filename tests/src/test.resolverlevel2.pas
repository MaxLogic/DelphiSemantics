unit Test.ResolverLevel2;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve;

type
  [TestFixture]
  TResolverLevel2Tests = class
  private
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
    procedure ResolvesCrossUnitPointerArraySelectorsWithoutGuessing;
    [Test]
    procedure ResolvesSourceBackedCrossUnitSelectors;
    [Test]
    procedure FinalSelectorOriginSurvivesHiddenAliasAndRefusesMissingProvenance;
    [Test]
    procedure BareImportedOriginKeepsDeclaringUnitWithoutMovingCallerOwners;
    [Test]
    procedure BareImportedOriginRequiresVisibleDeclaration;
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
  maxLogic.IOUtils,
  Test.Support;


function TResolverLevel2Tests.LoadInventoryModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('Resolver', 'InventoryResolverUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TResolverLevel2Tests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('Resolver', 'Level2ResolverUnit.pas');
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

procedure TResolverLevel2Tests.ResolvesCrossUnitPointerArraySelectorsWithoutGuessing;
var
  lConsumer: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticResolveContext;
  lOther: TDelphiSemanticUnitModel;
  lProvider: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lConsumer := Default(TDelphiSemanticUnitModel);
  lConsumer.UnitName := 'Consumer';
  lConsumer.ImplementationUses := ['Provider'];
  SetLength(lConsumer.Declarations, 4);
  lConsumer.Declarations[0].Name := 'DF';
  lConsumer.Declarations[0].Kind := 'var';
  lConsumer.Declarations[0].TypeName := 'array of TPtr';
  lConsumer.Declarations[0].SectionKind := 'implementation';
  lConsumer.Declarations[1] := lConsumer.Declarations[0];
  lConsumer.Declarations[1].Name := 'X';
  lConsumer.Declarations[1].TypeName := 'TPtr';
  lConsumer.Declarations[2] := lConsumer.Declarations[0];
  lConsumer.Declarations[2].Name := 'A';
  lConsumer.Declarations[2].TypeName := 'TArrayAlias';
  lConsumer.Declarations[3] := lConsumer.Declarations[0];
  lConsumer.Declarations[3].Name := 'P';
  lConsumer.Declarations[3].TypeName := '^array[0..1] of TRec';

  lProvider := Default(TDelphiSemanticUnitModel);
  lProvider.UnitName := 'Provider';
  SetLength(lProvider.Declarations, 3);
  lProvider.Declarations[0].Name := 'TPtr';
  lProvider.Declarations[0].Kind := 'type-alias';
  lProvider.Declarations[0].TypeName := '^TRec';
  lProvider.Declarations[0].SectionKind := 'interface';
  lProvider.Declarations[1] := lProvider.Declarations[0];
  lProvider.Declarations[1].Name := 'TArrayAlias';
  lProvider.Declarations[1].TypeName := 'array of TRec';
  lProvider.Declarations[2] := lProvider.Declarations[0];
  lProvider.Declarations[2].Name := 'TRec';
  lProvider.Declarations[2].Kind := 'type';
  lProvider.Declarations[2].TypeName := 'record';
  SetLength(lProvider.Members, 1);
  lProvider.Members[0].OwnerName := 'TRec';
  lProvider.Members[0].Name := 'Value';
  lProvider.Members[0].Kind := 'field';
  lProvider.Members[0].TypeName := 'Integer';

  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := [lProvider];
  for var lSelector in ['X^.Value', 'A[0].Value', 'DF[0]^.Value', 'P^[0].Value'] do
  begin
    lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, lSelector);
    Assert.IsTrue(lResult.Found, lSelector + ': ' + lResult.ReasonCode);
    Assert.AreEqual('TRec', lResult.OwnerName);
    Assert.AreEqual('Integer', lResult.TypeName);
  end;

  // Array-prefixed identifiers are aliases, not inline array declarations.
  lProvider.Declarations[0].Name := 'ArrayVarRecPtr';
  lProvider.Declarations[0].TypeName := '^ArrayRec';
  lProvider.Declarations[1].Name := 'ArrayValues';
  lProvider.Declarations[1].TypeName := 'array of ArrayRec';
  lProvider.Declarations[2].Name := 'ArrayRec';
  lProvider.Members[0].OwnerName := 'ArrayRec';
  lConsumer.Declarations[0].TypeName := 'array of ArrayVarRecPtr';
  lConsumer.Declarations[1].TypeName := 'ArrayVarRecPtr';
  lConsumer.Declarations[2].TypeName := 'ArrayValues';
  lConsumer.Declarations[3].TypeName := '^array[0..1] of ArrayRec';
  lContext.IndexedUnitModels := [lProvider];
  for var lSelector in ['X^.Value', 'A[0].Value', 'DF[0]^.Value', 'P^[0].Value'] do
  begin
    lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, lSelector);
    Assert.IsTrue(lResult.Found, lSelector + ': Array-prefixed alias: ' + lResult.ReasonCode);
    Assert.AreEqual('ArrayRec', lResult.OwnerName);
    Assert.AreEqual('Integer', lResult.TypeName);
  end;

  lProvider.Declarations[0].Name := 'TPtr';
  lProvider.Declarations[0].TypeName := '^TRec';
  lProvider.Declarations[1].Name := 'TArrayAlias';
  lProvider.Declarations[1].TypeName := 'array of TRec';
  lProvider.Declarations[2].Name := 'TRec';
  lProvider.Members[0].OwnerName := 'TRec';
  lConsumer.Declarations[0].TypeName := 'array of TPtr';
  lConsumer.Declarations[1].TypeName := 'TPtr';
  lConsumer.Declarations[2].TypeName := 'TArrayAlias';
  lConsumer.Declarations[3].TypeName := '^array[0..1] of TRec';

  lProvider.Members[0].TypeName := 'TMissingResult';
  lContext.IndexedUnitModels := [lProvider];
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value');
  Assert.IsTrue(lResult.Found, 'A bound terminal member keeps its unknown result type.');
  Assert.AreEqual('TMissingResult', lResult.TypeName);
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value.Other');
  Assert.IsFalse(lResult.Found, 'An unknown result type cannot justify another member hop.');
  Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED', lResult.ReasonCode);
  lProvider.Members[0].TypeName := 'Integer';

  lOther := lProvider;
  lOther.UnitName := 'OtherProvider';
  lConsumer.ImplementationUses := ['Provider', 'OtherProvider'];
  lContext.IndexedUnitModels := [lProvider, lOther];
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'DF[0]^.Value');
  Assert.IsFalse(lResult.Found, 'Duplicate provider aliases must stay unresolved.');

  lConsumer.ImplementationUses := ['Provider'];
  lProvider.Declarations[0].SectionKind := 'implementation';
  lContext.IndexedUnitModels := [lProvider];
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value');
  Assert.IsFalse(lResult.Found, 'Private provider aliases must stay unresolved.');

  lProvider.Declarations[0].SectionKind := 'interface';
  lProvider.Declarations[0].TypeName := 'TCycle';
  lProvider.Declarations[1].Name := 'TCycle';
  lProvider.Declarations[1].TypeName := 'TPtr';
  lContext.IndexedUnitModels := [lProvider];
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value');
  Assert.IsFalse(lResult.Found, 'Cyclic aliases must stay unresolved.');

  lProvider.Declarations[0].TypeName := '^TRec';
  lConsumer.ImplementationUses := nil;
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'DF[0]^.Value');
  Assert.IsFalse(lResult.Found, 'An unimported provider variable must stay invisible.');
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value');
  Assert.IsFalse(lResult.Found, 'A project model alone does not establish visibility.');

  lConsumer.ImplementationUses := ['Provider'];
  lConsumer.Declarations[1].SectionKind := 'interface';
  lContext.SectionKind := 'interface';
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value');
  Assert.IsFalse(lResult.Found, 'An implementation import is invisible to interface declarations.');
  lConsumer.InterfaceUses := ['Provider'];
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value');
  Assert.IsTrue(lResult.Found, 'An interface import is visible to interface declarations.');
  lConsumer.InterfaceUses := nil;
  lConsumer.Declarations[1].SectionKind := 'implementation';
  lContext.SectionKind := 'implementation';

  lConsumer.ImplementationUses := ['Provider'];
  SetLength(lConsumer.Declarations, 5);
  lConsumer.Declarations[3] := lProvider.Declarations[0];
  lConsumer.Declarations[3].TypeName := '^TLocal';
  lConsumer.Declarations[4] := lProvider.Declarations[2];
  lConsumer.Declarations[4].Name := 'TLocal';
  SetLength(lConsumer.Members, 1);
  lConsumer.Members[0] := lProvider.Members[0];
  lConsumer.Members[0].OwnerName := 'TLocal';
  lConsumer.Members[0].Name := 'LocalValue';
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.LocalValue');
  Assert.IsTrue(lResult.Found, 'The local alias should shadow the import.');
  Assert.AreEqual('TLocal', lResult.OwnerName);
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'X^.Value');
  Assert.IsFalse(lResult.Found, 'Shadowing must not capture provider members.');
end;

procedure TResolverLevel2Tests.ResolvesSourceBackedCrossUnitSelectors;
var
  lConsumer: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticResolveContext;
  lOptions: TDelphiSemanticModelOptions;
  lProvider: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
  lSelector: string;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  lOptions.SourceFileName := FixturePath('Resolver', 'SelectorAliasConsumer.pas');
  lConsumer := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lConsumer.Success);
  lOptions.SourceFileName := FixturePath('Resolver', 'SelectorAliasProvider.pas');
  lProvider := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lProvider.Success);

  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := [lConsumer, lProvider];
  for lSelector in ['DF[0]^.Value', 'X^.Value', 'A[0].Value'] do
  begin
    lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, lSelector);
    Assert.IsTrue(lResult.Found, lSelector + ': ' + lResult.ReasonCode);
    Assert.AreEqual('field', lResult.Kind);
    Assert.AreEqual('TSelectorRecord', lResult.OwnerName);
    Assert.AreEqual('Integer', lResult.TypeName);
  end;
  lConsumer.InterfaceUses := nil;
  lResult := TDelphiSemanticResolver.ResolveName(lConsumer, lContext, 'DF[0]^.Value');
  Assert.IsFalse(lResult.Found, 'A project-indexed variable without an import is invisible.');
end;

procedure TResolverLevel2Tests.FinalSelectorOriginSurvivesHiddenAliasAndRefusesMissingProvenance;
var
  i: Integer;
  lContext: TDelphiSemanticResolveContext;
  lFinalModel: TDelphiSemanticUnitModel;
  lFinalSection: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lOwnerUses: TArray<string>;
  lResult: TDelphiSemanticResolveResult;
  lUnitName: string;
begin
  SetLength(lModels, 4);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to 3 do
  begin
    case i of
      0: lUnitName := 'ReceiverSafetyHidden';
      1: lUnitName := 'ReceiverSafetyAlias';
      2: lUnitName := 'ReceiverSafetyOwner';
    else
      lUnitName := 'ReceiverSafetyCaller';
    end;
    lOptions.SourceFileName := FixturePath('WithBinder\ReceiverSafetyIdentity',
      lUnitName + '.pas');
    lModels[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModels[i].Success, lUnitName + ' source model');
  end;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'Run';
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := lModels;
  lResult := ResolveNameWithFinalTypeOrigin(lModels[3], lContext,
    'lOuter.Item^', lFinalModel, lFinalSection);
  Assert.IsTrue(lResult.Found, lResult.ReasonCode);
  Assert.AreEqual('THiddenEntry', lResult.TypeName);
  Assert.AreEqual('ReceiverSafetyHidden', lFinalModel.UnitName,
    'Final type belongs to the hidden declaration, beyond owner and alias units');
  Assert.AreEqual('interface', lFinalSection);

  lOwnerUses := lModels[2].InterfaceUses;
  lModels[2].InterfaceUses := nil;
  lContext.IndexedUnitModels := lModels;
  lResult := ResolveNameWithFinalTypeOrigin(lModels[3], lContext,
    'lOuter.Item^', lFinalModel, lFinalSection);
  Assert.IsFalse(lResult.Found, 'Missing alias import must refuse the selector');
  Assert.AreEqual('', lFinalModel.UnitName,
    'Failed selector cannot carry a stale final identity');
  lModels[2].InterfaceUses := lOwnerUses;
end;

procedure TResolverLevel2Tests.BareImportedOriginKeepsDeclaringUnitWithoutMovingCallerOwners;
var
  i: Integer;
  lContext: TDelphiSemanticResolveContext;
  lDeclaration: TDelphiSemanticDeclaration;
  lFinalModel: TDelphiSemanticUnitModel;
  lFinalSection: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lResult: TDelphiSemanticResolveResult;
  lUnitName: string;
begin
  SetLength(lModels, 3);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to 2 do
  begin
    case i of
      0: lUnitName := 'ReceiverSafetyHidden';
      1: lUnitName := 'ReceiverSafetyBareOwner';
    else
      lUnitName := 'ReceiverSafetyBareCaller';
    end;
    lOptions.SourceFileName := FixturePath('WithBinder\ReceiverSafetyIdentity',
      lUnitName + '.pas');
    lModels[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModels[i].Success, lUnitName + ' source model');
  end;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := lModels;
  lContext.RoutineName := 'RunBare';
  lResult := ResolveNameWithFinalTypeOrigin(lModels[2], lContext, 'G',
    lFinalModel, lFinalSection);
  Assert.IsTrue(lResult.Found, 'Imported G must resolve');
  Assert.AreEqual('ReceiverSafetyBareOwner', lResult.OwnerName);
  Assert.AreEqual('ReceiverSafetyBareOwner', lFinalModel.UnitName,
    'Bare imported variable type belongs to its declaring unit context');
  Assert.AreEqual('interface', lFinalSection);

  lContext.RoutineName := 'RunLocal';
  lResult := ResolveNameWithFinalTypeOrigin(lModels[2], lContext, 'lLocal',
    lFinalModel, lFinalSection);
  Assert.IsTrue(lResult.Found, 'Caller local must resolve');
  Assert.AreEqual('ReceiverSafetyBareCaller', lFinalModel.UnitName);
  lContext.RoutineName := 'RunParameter';
  lResult := ResolveNameWithFinalTypeOrigin(lModels[2], lContext, 'aValue',
    lFinalModel, lFinalSection);
  Assert.IsTrue(lResult.Found, 'Caller parameter must resolve');
  Assert.AreEqual('ReceiverSafetyBareCaller', lFinalModel.UnitName);
  lContext.RoutineName := 'TContainer.RunMember';
  lContext.CurrentTypeName := 'TContainer';
  lResult := ResolveNameWithFinalTypeOrigin(lModels[2], lContext, 'FValue',
    lFinalModel, lFinalSection);
  Assert.IsTrue(lResult.Found, 'Caller class member must resolve');
  Assert.AreEqual('ReceiverSafetyBareCaller', lFinalModel.UnitName);

  lContext.RoutineName := 'RunBare';
  lContext.CurrentTypeName := '';
  for lDeclaration in lModels[1].Declarations do
    if SameText(lDeclaration.Name, 'G') then
    begin
      SetLength(lModels[1].Declarations, Length(lModels[1].Declarations) + 1);
      lModels[1].Declarations[High(lModels[1].Declarations)] := lDeclaration;
      Break;
    end;
  lContext.IndexedUnitModels := lModels;
  lResult := ResolveNameWithFinalTypeOrigin(lModels[2], lContext, 'G',
    lFinalModel, lFinalSection);
  Assert.IsFalse(lResult.Found, 'Ambiguous imported G must refuse');
  Assert.AreEqual('', lFinalModel.UnitName,
    'Ambiguous result cannot retain a source origin');
end;

procedure TResolverLevel2Tests.BareImportedOriginRequiresVisibleDeclaration;
var
  i: Integer;
  lContext: TDelphiSemanticResolveContext;
  lFinalModel: TDelphiSemanticUnitModel;
  lFinalSection: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lResult: TDelphiSemanticResolveResult;
  lUnitName: string;
begin
  SetLength(lModels, 3);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.ProjectContextApplied := True;
  for i := 0 to 2 do
  begin
    case i of
      0: lUnitName := 'ReceiverSafetyHidden';
      1: lUnitName := 'ReceiverSafetyBareOwner';
    else
      lUnitName := 'ReceiverSafetyBareCaller';
    end;
    lOptions.SourceFileName := FixturePath('WithBinder\ReceiverSafetyIdentity',
      lUnitName + '.pas');
    lModels[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModels[i].Success, lUnitName + ' source model');
  end;
  lModels[2].InterfaceUses := nil;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';
  lContext.ConformanceLevel := 3;
  lContext.IndexedUnitModels := lModels;
  lContext.RoutineName := 'RunBare';

  lResult := TDelphiSemanticResolver.ResolveName(lModels[2], lContext, 'G');
  Assert.IsTrue(lResult.Found,
    'Public ResolveName retains its indexed lookup behavior');
  lResult := ResolveNameWithFinalTypeOrigin(lModels[2], lContext, 'G',
    lFinalModel, lFinalSection);
  Assert.IsFalse(lResult.Found,
    'Companion must refuse indexed G without a visible declaring unit');
  Assert.AreEqual('unresolved', lResult.Status);
  Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED', lResult.ReasonCode);
  Assert.AreEqual('', lFinalModel.UnitName);
  Assert.AreEqual('', lFinalSection);
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
