unit Test.ResolverLevel1;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.Resolve;

type
  [TestFixture]
  TResolverLevel1Tests = class
  private
    function LoadModel: TDelphiSemanticUnitModel;
  public
    [Test]
    procedure OverloadedParameterWithoutRoutineIdentityRefuses;
    [Test]
    procedure ParameterCoordinatesNameTheParameterToken;
    [Category('Fast')]
    [Test]
    procedure LexicalSymbolsShadowUnitDeclarations;
    [Category('Fast')]
    [Test]
    procedure ParametersShadowUnitDeclarations;
    [Category('Fast')]
    [Test]
    procedure ResolvesUnitDeclarationsAndDirectMembers;
    [Category('Fast')]
    [Test]
    procedure InitializationAndFinalizationSeeImplementationDeclarations;
    [Category('Fast')]
    [Test]
    procedure UnitRoutineDeclarationAndImplementationResolveAsOneSymbol;
    [Category('Fast')]
    [Test]
    procedure IndexedDefaultMembersAreNonAuthoritativeUnsupported;
    [Category('Fast')]
    [Test]
    procedure UnknownNamesAreNonAuthoritativeUnresolved;
    [Category('Fast')]
    [Test]
    procedure DuplicateVisibleDeclarationsAreAmbiguous;
    [Category('Fast')]
    [Test]
    procedure AdvancedSelectorsAreNonAuthoritativeUnsupported;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  maxLogic.IOUtils,
  Test.Support;


function TResolverLevel1Tests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('Resolver', 'Level1ResolverUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

procedure TResolverLevel1Tests.LexicalSymbolsShadowUnitDeclarations;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'ResolveTarget';
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Value');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('local', lResult.Kind);
  Assert.AreEqual('TLevelRecord', lResult.TypeName);
end;

procedure TResolverLevel1Tests.ParametersShadowUnitDeclarations;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'ResolveTarget';
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'SharedName');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('parameter', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
end;

procedure TResolverLevel1Tests.ResolvesUnitDeclarationsAndDirectMembers;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ImplementationOnly');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('var', lResult.Kind);
  Assert.AreEqual('TLevelRecord', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'TLevelRecord');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('type', lResult.Kind);
  Assert.AreEqual('record', lResult.TypeName);

  lResult := TDelphiSemanticResolver.ResolveMember(lModel, 'TLevelRecord', 'Value');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('field', lResult.Kind);
  Assert.AreEqual('Integer', lResult.TypeName);
  Assert.AreEqual('TLevelRecord', lResult.OwnerName);
end;

procedure TResolverLevel1Tests.InitializationAndFinalizationSeeImplementationDeclarations;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'initialization';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ImplementationOnly');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('var', lResult.Kind);

  lContext.SectionKind := 'finalization';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ImplementationOnly');

  Assert.IsTrue(lResult.Found);
  Assert.AreEqual('var', lResult.Kind);
end;

procedure TResolverLevel1Tests.UnitRoutineDeclarationAndImplementationResolveAsOneSymbol;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ResolveTarget');

  Assert.IsTrue(lResult.Found);
  Assert.IsTrue(lResult.Authoritative);
  Assert.AreEqual('resolved', lResult.Status);
  Assert.AreEqual('routine', lResult.Kind);
end;

procedure TResolverLevel1Tests.IndexedDefaultMembersAreNonAuthoritativeUnsupported;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;

  lResult := TDelphiSemanticResolver.ResolveMember(lModel, 'TLevelRecord', 'Items');

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('unsupported', lResult.Status);
  Assert.AreEqual('INDEXED_PROPERTY_UNSUPPORTED', lResult.ReasonCode);

  lContext := Default(TDelphiSemanticResolveContext);
  lContext.CurrentTypeName := 'TLevelRecord';
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Items');

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('unsupported', lResult.Status);
  Assert.AreEqual('INDEXED_PROPERTY_UNSUPPORTED', lResult.ReasonCode);
end;

procedure TResolverLevel1Tests.UnknownNamesAreNonAuthoritativeUnresolved;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'MissingSymbol');

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('unresolved', lResult.Status);
  Assert.AreEqual('NAME_NOT_FOUND', lResult.ReasonCode);
  Assert.IsTrue(lResult.Reason <> '');
end;

procedure TResolverLevel1Tests.DuplicateVisibleDeclarationsAreAmbiguous;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'DuplicateName');

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.AreEqual('MULTIPLE_VISIBLE_DECLARATIONS', lResult.ReasonCode);
  Assert.IsTrue(lResult.Reason <> '');
end;

procedure TResolverLevel1Tests.AdvancedSelectorsAreNonAuthoritativeUnsupported;
var
  lContext: TDelphiSemanticResolveContext;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticResolveResult;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'ResolveTarget';
  lContext.SectionKind := 'implementation';

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Value.Value');

  Assert.IsFalse(lResult.Found);
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('unsupported', lResult.Status);
  Assert.AreEqual('QUALIFIED_SELECTOR_UNSUPPORTED', lResult.ReasonCode);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'Value[0]');

  Assert.AreEqual('unsupported', lResult.Status);
  Assert.AreEqual('INDEXED_SELECTOR_UNSUPPORTED', lResult.ReasonCode);

  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'ResolveTarget()');

  Assert.AreEqual('unsupported', lResult.Status);
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', lResult.ReasonCode);
end;

procedure TResolverLevel1Tests.OverloadedParameterWithoutRoutineIdentityRefuses;
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('BindingSafety', 'overloads\Unit1.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'Execute';
  lContext.SectionKind := 'implementation';
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'aRec');
  Assert.IsFalse(lResult.Found, 'A name-only context cannot select either overload.');
  Assert.IsFalse(lResult.Authoritative);
  Assert.AreEqual('ambiguous', lResult.Status);
  Assert.AreEqual('MULTIPLE_PARAMETER_DECLARATIONS', lResult.ReasonCode);
end;

procedure TResolverLevel1Tests.ParameterCoordinatesNameTheParameterToken;
var
  lModel: TDelphiSemanticUnitModel;
  lContext: TDelphiSemanticResolveContext;
  lResult: TDelphiSemanticResolveResult;
  lSeen: Integer;
begin
  lModel := LoadModel;
  lContext := Default(TDelphiSemanticResolveContext);
  lContext.RoutineName := 'ResolveTarget';
  lContext.SectionKind := 'implementation';
  lResult := TDelphiSemanticResolver.ResolveName(lModel, lContext, 'SharedName');
  Assert.IsTrue(lResult.Found);
  lSeen := 0;
  for var lRoutine in lModel.Routines do
    if lRoutine.Name = 'ResolveTarget' then
      for var lParameter in lRoutine.Parameters do
        if (lParameter.Name = 'SharedName') and (lParameter.Line = lResult.Line) and
          (lParameter.Column = lResult.Column) then
          Inc(lSeen);
  Assert.AreEqual(1, lSeen, 'Coordinates must identify the parameter, never the routine heading.');
end;

initialization
  TDUnitX.RegisterTestFixture(TResolverLevel1Tests);

end.
