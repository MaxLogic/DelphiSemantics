unit Test.Refactor.Consistency;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Consistency.GuidInventory, DelphiSemantics.Model;

type
  [TestFixture]
  [Category('RefactoringLightConsistency')]
  TRefactorConsistencyTests = class
  private
    function ExtractModel(const aUnitName, aSource: string): TDelphiSemanticUnitModel;
    function FindDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string;
      out aDeclaration: TDelphiSemanticDeclaration): Boolean;
    function FindInventoryItem(const aInventory: TDelphiSemanticGuidInventory;
      const aName: string; out aItem: TDelphiSemanticGuidInventoryItem): Boolean;
    function MakeDeclaration(const aName, aTypeName, aGuid: string;
      const aIsDispInterface: Boolean; const aRole: string): TDelphiSemanticDeclaration;
    function AncestryModels(const aShape: string): TArray<TDelphiSemanticUnitModel>;
    function AliasContextModels(const aShape: string): TArray<TDelphiSemanticUnitModel>;
  public
    [Test]
    procedure ExtractsInterfaceAndDispinterfaceGuidFacts;
    [Test]
    [TestCase('Class', 'class')]
    [TestCase('Interface', 'interface')]
    [TestCase('Dispinterface', 'dispinterface')]
    procedure PreservesForwardTypeDeclarationRole(const aKind: string);
    [Test]
    procedure InventoryClassifiesPairsDuplicatesMissingAndUnknown;
    [Test]
    procedure ExtractsHandlerCallingConvention;
    [Test]
    procedure ExtractsStructuredEventSignatures;
    [Test]
    procedure RefusesIncompleteStructuredParameterTypes;
    [Test]
    procedure PreservesConsistencyFactsThroughModelJson;
    [Test]
    procedure ComparesSourceResolvedSignatureTypes;
    [Test]
    [TestCase('Mode', 'mode,mismatch,signature.parameter-mode')]
    [TestCase('Convention', 'convention,mismatch,signature.calling-convention')]
    [TestCase('Count', 'count,mismatch,signature.parameter-count')]
    [TestCase('Distinct type', 'type,mismatch,signature.parameter-type')]
    [TestCase('Missing type', 'missing,unknown,signature.parameter-type')]
    procedure RejectsIncompatibleEventSignatures(const aChange, aStatus, aReason: string);
    [Test]
    [TestCase('Both default', 'default')]
    [TestCase('Explicit event register', 'event')]
    [TestCase('Explicit handler register', 'handler')]
    procedure ResolvesInheritedEventAndHandler(const aConventionAt: string);
    [Test]
    procedure RefusesSameLineHandlerOverloads;
    [Test]
    [TestCase('Second of two handlers', 'two-methods,HandleData')]
    [TestCase('First of two handlers', 'two-methods,HandleOther')]
    [TestCase('Handler after field and visibility', 'field-visibility,HandleOther')]
    [TestCase('Next-line handler after mixed line', 'field-visibility,HandleData')]
    procedure ResolvesHandlersSharingOnePhysicalLine(const aLayout, aHandler: string);
    [Test]
    [TestCase('Unsupported procedural field layout', 'True,unknown')]
    [TestCase('Supported control layout', 'False,match')]
    procedure RefusesUnitWithIncompleteMembers(const aProceduralField: Boolean;
      const aStatus: string);
    [Test]
    [TestCase('Unrelated incomplete class', 'unrelated,match')]
    [TestCase('Unattributed file', 'file,unknown')]
    [TestCase('Missing location', 'location,unknown')]
    [TestCase('Unrelated diagnostic', 'other,unknown')]
    [TestCase('Duplicate diagnostic owner', 'duplicate,unknown')]
    procedure IsolatesIncompleteMemberOwners(const aFault, aStatus: string);
    [Test]
    [TestCase('Direct parameter alias', 'direct,match')]
    [TestCase('Chained parameter alias', 'chain,match')]
    [TestCase('Distinct parameter type', 'distinct,mismatch')]
    [TestCase('Same distinct parameter type', 'same-distinct,match')]
    [TestCase('Event type alias', 'event,match')]
    [TestCase('Event type alias chain', 'event-chain,match')]
    [TestCase('Alias cycle', 'cycle,unknown')]
    [TestCase('Ordinary alias property', 'ordinary,not-event')]
    procedure ResolvesAliasSignatures(const aShape, aStatus: string);
    [Test]
    [TestCase('Complete context', 'complete,match')]
    [TestCase('Missing event context', 'missing,unknown')]
    [TestCase('Missing handler context', 'handler,unknown')]
    [TestCase('Partial context', 'partial,unknown')]
    [TestCase('Duplicate context', 'duplicate,unknown')]
    procedure RequiresCompleteSignatureContext(const aShape, aStatus: string);
    [Test]
    [TestCase('Alias declaration imports', 'visible,match')]
    [TestCase('Original event declaration scope', 'event-origin,match')]
    [TestCase('Caller import is insufficient', 'hidden,unknown')]
    [TestCase('Qualified caller import is insufficient', 'qualified-hidden,unknown')]
    [TestCase('Mismatched source position', 'position,unknown')]
    [TestCase('Mismatched source file', 'file,unknown')]
    [TestCase('Missing target source', 'missing,unknown')]
    [TestCase('Partial target source', 'partial,unknown')]
    procedure ResolvesAliasInDeclarationContext(const aShape, aStatus: string);
    [Test]
    [TestCase('Missing handler', 'complete,missing-handler')]
    [TestCase('Unknown ancestor', 'external,unknown')]
    [TestCase('Forward-only ancestor', 'forward,unknown')]
    [TestCase('Incomplete declarations', 'incomplete,unknown')]
    [TestCase('Recovered existing handler', 'recovered-match,unknown')]
    [TestCase('Rejected existing handler', 'rejected-match,unknown')]
    procedure DistinguishesMissingHandlerFromUnknownAncestry(const aShape, aStatus: string);
    [Test]
    [TestCase('Complete', 'complete,ancestry.complete,2')]
    [TestCase('Hidden base', 'hidden,ancestry.type-unresolved,1')]
    [TestCase('Source-less base', 'external,ancestry.type-unresolved,1')]
    [TestCase('Forward base', 'forward,ancestry.declaration-incomplete,1')]
    [TestCase('Cycle', 'cycle,ancestry.cycle,2')]
    [TestCase('Partial model', 'partial,ancestry.model-incomplete,1')]
    [TestCase('Duplicate model', 'duplicate,ancestry.model-incomplete,1')]
    [TestCase('Non-class base', 'record,ancestry.not-source-class,1')]
    [TestCase('Alias base', 'alias,ancestry.class-alias-unsupported,1')]
    procedure ReportsGuardedClassAncestry(const aShape, aReason: string; const aCount: Integer);
    [Test]
    [TestCase('Inherited scope', 'normal,match')]
    [TestCase('Descendant name hiding', 'hiding,match')]
    [TestCase('Missing declaration scope', 'missing,unknown')]
    procedure ResolvesComponentInAncestorDeclarationScope(const aShape, aStatus: string);
    [Test]
    [TestCase('Enumeration', 'enum,not-event')]
    [TestCase('Class', 'class,not-event')]
    [TestCase('Record', 'record,not-event')]
    [TestCase('Interface', 'interface,not-event')]
    [TestCase('Forward class', 'forward,unknown')]
    [TestCase('Unavailable type', 'missing,unknown')]
    [TestCase('Event missing handler', 'event,missing-handler')]
    procedure ClassifiesOrdinaryPublishedProperty(const aShape, aStatus: string);
    [Test]
    [TestCase('Single line', 'single')]
    [TestCase('Multiple lines', 'multiple')]
    [TestCase('Scoped', 'scoped')]
    procedure PreservesEnumValuePositionsAndScopes(const aShape: string);
    [Test]
    [TestCase('Spaces', 'space')]
    [TestCase('Tab', 'tab')]
    [TestCase('Mixed case', 'case')]
    [TestCase('Newline control', 'newline')]
    procedure PreservesTypesBesideKeyword(const aShape: string);
    [Test]
    [TestCase('Scoped values', 'scoped')]
    [TestCase('Unscoped values', 'unscoped')]
    [TestCase('Deep nesting', 'deep')]
    procedure PreservesNestedEnumOwnership(const aShape: string);
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  DelphiSemantics.Consistency.EventBindings, DelphiSemantics.Consistency.EventSignatures,
  DelphiSemantics.Consistency.Types,
  DelphiSemantics.Model.Extract, DelphiSemantics.Model.Json,
  DelphiSemantics.ProjectContext, DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

procedure TRefactorConsistencyTests.PreservesTypesBesideKeyword(const aShape: string);
var
  lKeyword, lSource: string;
  lModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lClasses, lMembers: Integer;
begin
  lKeyword := 'type ';
  if aShape = 'tab' then
    lKeyword := 'type' + #9
  else if aShape = 'case' then
    lKeyword := 'TyPe '
  else if aShape = 'newline' then
    lKeyword := 'type' + sLineBreak;
  lSource := 'unit KeywordTypes;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TBase = class end;' + sLineBreak +
    lKeyword + 'TChild = class(TBase)' + sLineBreak + 'public' + sLineBreak +
    '  procedure Handle(aValue: Integer);' + sLineBreak + 'end;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure TChild.Handle(aValue: Integer);' + sLineBreak +
    'begin end;' + sLineBreak + 'end.';
  lModel := ExtractModel('KeywordTypes', lSource);
  Assert.IsTrue(lModel.Success, ModelToJson(lModel));
  Assert.AreEqual(0, lModel.RejectedDeclarationCount, ModelToJson(lModel));
  lClasses := 0;
  for lDeclaration in lModel.Declarations do
  begin
    Assert.AreNotEqual('Handle', lDeclaration.Name, 'A class method is not a unit routine.');
    if lDeclaration.Name = 'TChild' then
    begin
      Inc(lClasses);
      Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
      Assert.AreEqual('TBase', lDeclaration.BaseTypeName);
      Assert.AreEqual('TChild', Copy(lSource, lDeclaration.Offset, Length(lDeclaration.Name)));
    end;
  end;
  lMembers := 0;
  for lMember in lModel.Members do
    if (lMember.OwnerName = 'TChild') and (lMember.Name = 'Handle') then
    begin
      Inc(lMembers);
      Assert.IsTrue(lMember.ProcedureSignature.Known);
    end;
  Assert.AreEqual(1, lClasses);
  Assert.AreEqual(1, lMembers);
end;

function NestedEnumSource(const aShape: string): string;
var
  lSwitch, lLeftValues, lRightValues, lTypes: string;
begin
  lSwitch := '{$SCOPEDENUMS ON}';
  lLeftValues := 'one, two';
  lRightValues := 'one, two';
  if aShape = 'unscoped' then
  begin
    lSwitch := '{$SCOPEDENUMS OFF}';
    lLeftValues := 'leftOne, leftTwo';
    lRightValues := 'rightOne, rightTwo';
  end;
  lTypes := '  TLeft = class' + sLineBreak + '  public type' + sLineBreak +
    '    TMode = (' + lLeftValues + ');' + sLineBreak + '  end;' + sLineBreak +
    '  TRight = class' + sLineBreak + '  public type' + sLineBreak +
    '    TMode = (' + lRightValues + ');' + sLineBreak + '  end;';
  if aShape = 'deep' then
    lTypes := '  TShell = class' + sLineBreak + '  public type' + sLineBreak +
      '    TInner = class' + sLineBreak + '    public type' + sLineBreak +
      '      TMode = (one, two);' + sLineBreak + '    end;' + sLineBreak + '  end;';
  Result := 'unit NestedFacts;' + sLineBreak + 'interface' + sLineBreak + lSwitch + sLineBreak +
    'type' + sLineBreak + lTypes + sLineBreak + 'implementation' + sLineBreak + 'end.';
end;

procedure AssertDistinctDeclarationIdentities(const aModel: TDelphiSemanticUnitModel);
var
  i, j: Integer;
begin
  for i := 0 to High(aModel.Declarations) do
    for j := 0 to Pred(i) do
      Assert.AreNotEqual(aModel.Declarations[i].SymbolId, aModel.Declarations[j].SymbolId,
        'Separate declarations must retain distinct identities.');
end;

procedure TRefactorConsistencyTests.PreservesNestedEnumOwnership(const aShape: string);
var
  lSource, lOwner: string;
  lModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lValues, lTypes: Integer;
begin
  lSource := NestedEnumSource(aShape);
  lModel := JsonToModel(ModelToJson(ExtractModel('NestedFacts', lSource)));
  Assert.IsTrue(lModel.Success, ModelToJson(lModel));
  Assert.AreEqual(0, lModel.RejectedDeclarationCount, ModelToJson(lModel));
  AssertDistinctDeclarationIdentities(lModel);
  lValues := 0;
  lTypes := 0;
  for lDeclaration in lModel.Declarations do
  begin
    lOwner := 'TLeft';
    if aShape = 'deep' then
      lOwner := 'TShell.TInner'
    else if lDeclaration.Offset > Pos('TRight = class', lSource) then
      lOwner := 'TRight';
    if lDeclaration.Name = 'TMode' then
    begin
      Inc(lTypes);
      Assert.AreEqual('type', lDeclaration.ScopeKind);
      Assert.AreEqual(lOwner, lDeclaration.OwnerName);
    end;
    if lDeclaration.Kind <> 'enum-value' then
      Continue;
    Inc(lValues);
    Assert.IsFalse(lDeclaration.Mutable);
    Assert.AreEqual(lDeclaration.Name, Copy(lSource, lDeclaration.Offset, Length(lDeclaration.Name)));
    if aShape = 'unscoped' then
    begin
      Assert.AreEqual('unit', lDeclaration.ScopeKind);
      Assert.AreEqual('NestedFacts', lDeclaration.OwnerName);
    end else begin
      Assert.AreEqual('type', lDeclaration.ScopeKind);
      Assert.AreEqual(lOwner + '.TMode', lDeclaration.OwnerName);
    end;
  end;
  if aShape = 'deep' then
    Assert.AreEqual(1, lTypes)
  else
    Assert.AreEqual(2, lTypes);
  Assert.AreEqual(lTypes * 2, lValues);
end;

procedure TRefactorConsistencyTests.PreservesEnumValuePositionsAndScopes(const aShape: string);
var
  lSource, lValues: string;
  lModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lCount: Integer;
begin
  lValues := 'one = 1, two = 2';
  if aShape = 'multiple' then
    lValues := sLineBreak + '    one = 1,' + sLineBreak + '    two = 2' + sLineBreak;
  lSource := 'unit EnumFacts;' + sLineBreak + 'interface' + sLineBreak;
  if aShape = 'scoped' then
    lSource := lSource + '{$SCOPEDENUMS ON}' + sLineBreak;
  lSource := lSource + 'type' + sLineBreak + '  TValue = (' + lValues + ');' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
  lModel := JsonToModel(ModelToJson(ExtractModel('EnumFacts', lSource)));
  Assert.AreEqual(0, lModel.RejectedDeclarationCount, ModelToJson(lModel));
  lCount := 0;
  for lDeclaration in lModel.Declarations do
    if lDeclaration.Kind = 'enum-value' then
    begin
      Inc(lCount);
      Assert.AreEqual(lDeclaration.Name, Copy(lSource, lDeclaration.Offset, Length(lDeclaration.Name)));
      Assert.AreEqual('TValue', lDeclaration.TypeName);
      Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
      Assert.IsFalse(lDeclaration.Mutable);
      if aShape = 'scoped' then
      begin
        Assert.AreEqual('type', lDeclaration.ScopeKind);
        Assert.AreEqual('TValue', lDeclaration.OwnerName);
      end else
        Assert.AreEqual('unit', lDeclaration.ScopeKind);
    end;
  Assert.AreEqual(2, lCount);
end;
procedure TRefactorConsistencyTests.ClassifiesOrdinaryPublishedProperty(const aShape, aStatus: string);
var
  lDefinition: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lBinding: TDelphiSemanticEventBinding;
  lResult: TDelphiSemanticEventBindingResult;
begin
  lDefinition := '  TValue = ' + aShape + ' end;' + sLineBreak;
  if aShape = 'enum' then
    lDefinition := '  TValue = (one, two);' + sLineBreak;
  if aShape = 'forward' then
    lDefinition := '  TValue = class;' + sLineBreak;
  if aShape = 'missing' then
    lDefinition := '';
  if aShape = 'event' then
    lDefinition := '  TValue = procedure of object;' + sLineBreak;
  lModels := [ExtractModel('PropertyUnit', 'unit PropertyUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak + lDefinition +
    '  TBox = class' + sLineBreak + '  private' + sLineBreak + '    FValue: TValue;' + sLineBreak +
    '  published' + sLineBreak + '    property OnValue: TValue read FValue write FValue;' + sLineBreak +
    '  end;' + sLineBreak + '  TForm = class end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.')];
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, lModels);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := 'PropertyUnit';
    lBinding.FormClassName := 'TForm';
    lBinding.ComponentClassName := 'TBox';
    lBinding.EventName := 'OnValue';
    lBinding.HandlerName := 'ValueToken';
    lResult := TDelphiSemanticEventBindingResolver.Resolve(lModels,
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason + sLineBreak + ModelToJson(lModels[0]));
    if aStatus = 'not-event' then
    begin
      Assert.AreEqual('binding.property-not-event', lResult.Reason);
      Assert.AreEqual('OnValue', lResult.EventProperty.Name);
      Assert.AreEqual('TValue', lResult.EventType.Name);
      Assert.AreEqual('', lResult.Handler.Name);
    end;
  finally
    lGraph.Free;
  end;
end;
function TRefactorConsistencyTests.AncestryModels(const aShape: string):
  TArray<TDelphiSemanticUnitModel>;
var
  lBase, lBaseUses, lChildUses: string;
begin
  lBase := '  TBase = class end;';
  lBaseUses := '';
  lChildUses := 'uses BaseUnit;';
  if aShape = 'hidden' then
    lChildUses := '';
  if aShape = 'forward' then
    lBase := '  TBase = class;';
  if aShape = 'record' then
    lBase := '  TBase = record end;';
  if aShape = 'alias' then
    lBase := '  TActual = class end;' + sLineBreak + '  TBase = TActual;';
  if aShape = 'cycle' then
  begin
    lBaseUses := 'uses ChildUnit;';
    lBase := '  TBase = class(ChildUnit.TChild) end;';
  end;
  Result := [ExtractModel('ChildUnit', 'unit ChildUnit;' + sLineBreak +
    'interface' + sLineBreak + lChildUses + sLineBreak + 'type' + sLineBreak +
    '  TChild = class(BaseUnit.TBase) end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.'),
    ExtractModel('BaseUnit', 'unit BaseUnit;' + sLineBreak + 'interface' + sLineBreak +
      lBaseUses + sLineBreak + 'type' + sLineBreak + lBase + sLineBreak +
      'implementation' + sLineBreak + 'end.')];
  Assert.IsTrue(Result[0].Success, aShape);
  Assert.IsTrue(Result[1].Success, aShape);
  if aShape = 'external' then
    SetLength(Result, 1)
  else if aShape = 'partial' then
    Result[1].ScopeModelStatus := 'ast-interface-only'
  else if aShape = 'duplicate' then
    Result := [Result[0], Result[1], Result[1]];
end;

procedure TRefactorConsistencyTests.ReportsGuardedClassAncestry(const aShape, aReason: string;
  const aCount: Integer);
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticClassAncestry;
begin
  lModels := AncestryModels(aShape);
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, lModels);
  try
    lResult := TDelphiSemanticEventBindingResolver.InspectClassAncestry(lModels,
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), 'ChildUnit', 'TChild');
    Assert.AreEqual(aReason, lResult.Reason);
    Assert.AreEqual(aReason = 'ancestry.complete', lResult.Complete);
    Assert.AreEqual<NativeInt>(aCount, Length(lResult.Classes));
    Assert.AreEqual('TChild', lResult.Classes[0].Name);
    Assert.AreEqual(lModels[0].FileName, lResult.Classes[0].SourceRange.FileName);
    if aCount = 2 then
    begin
      Assert.AreEqual('TBase', lResult.Classes[1].Name);
      Assert.AreEqual(lModels[1].FileName, lResult.Classes[1].SourceRange.FileName);
    end;
  finally
    lGraph.Free;
  end;
end;

function TRefactorConsistencyTests.ExtractModel(const aUnitName, aSource: string):
  TDelphiSemanticUnitModel;
var
  lGuid: TGUID;
  lGuidText: string;
  lDirectory: string;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
    '', [rfReplaceAll]);
  lDirectory := TPath.GetFullPath(TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\.dak\delphiSemanticsTests\refactoring-light-consistency'));
  TDirectory.CreateDirectory(lDirectory);
  lPath := TPath.Combine(lDirectory, aUnitName + '-' + lGuidText + '.pas');
  try
    TFile.WriteAllText(lPath, aSource, TEncoding.UTF8);
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TRefactorConsistencyTests.ResolvesComponentInAncestorDeclarationScope(
  const aShape, aStatus: string);
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lBinding: TDelphiSemanticEventBinding;
  lResult: TDelphiSemanticEventBindingResult;
  lExtra, lComponentUnit: string;
begin
  lExtra := '';
  if aShape = 'hiding' then
    lExtra := '  TWidget = class end;' + sLineBreak;
  lComponentUnit := 'BaseFormUnit';
  if aShape = 'missing' then
    lComponentUnit := 'Unavailable';
  lModels := [ExtractModel('ComponentUnit', 'unit ComponentUnit;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak + '  TValue = class end;' + sLineBreak +
    '  TEvent = procedure(aValue: TValue) of object;' + sLineBreak +
    '  TWidget = class' + sLineBreak + '  private' + sLineBreak + '    FEvent: TEvent;' + sLineBreak +
    '  published' + sLineBreak + '    property Changed: TEvent read FEvent write FEvent;' + sLineBreak +
    '  end;' + sLineBreak + 'implementation' + sLineBreak + 'end.'),
    ExtractModel('BaseFormUnit', 'unit BaseFormUnit;' + sLineBreak + 'interface' + sLineBreak +
      'uses ComponentUnit;' + sLineBreak + 'type' + sLineBreak +
      '  TBaseForm = class' + sLineBreak + '  published' + sLineBreak +
      '    procedure HandleData(aValue: TValue);' + sLineBreak + '  end;' + sLineBreak +
      'implementation' + sLineBreak + 'procedure TBaseForm.HandleData(aValue: TValue);' + sLineBreak +
      'begin end;' + sLineBreak + 'end.'),
    ExtractModel('ChildFormUnit', 'unit ChildFormUnit;' + sLineBreak + 'interface' + sLineBreak +
      'uses BaseFormUnit;' + sLineBreak + 'type' + sLineBreak + lExtra +
      '  TChildForm = class(TBaseForm) end;' + sLineBreak + 'implementation' + sLineBreak + 'end.')];
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, lModels);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := 'ChildFormUnit';
    lBinding.FormClassName := 'TChildForm';
    lBinding.ComponentClassName := 'TWidget';
    lBinding.EventName := 'Changed';
    lBinding.HandlerName := 'HandleData';
    lResult := TDelphiSemanticEventBindingResolver.ResolveInContext(lModels,
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding, lComponentUnit);
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason);
    if aStatus = 'match' then
    begin
      Assert.AreEqual('ComponentUnit', lResult.EventProperty.UnitName);
      Assert.AreEqual('BaseFormUnit', lResult.Handler.UnitName);
    end;
  finally
    lGraph.Free;
  end;
end;

function TRefactorConsistencyTests.FindDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) then
    begin
      aDeclaration := lDeclaration;
      Exit(True);
    end;
  aDeclaration := Default(TDelphiSemanticDeclaration);
  Result := False;
end;

function TRefactorConsistencyTests.FindInventoryItem(
  const aInventory: TDelphiSemanticGuidInventory; const aName: string;
  out aItem: TDelphiSemanticGuidInventoryItem): Boolean;
var
  lItem: TDelphiSemanticGuidInventoryItem;
begin
  for lItem in aInventory.Items do
    if SameText(lItem.Name, aName) then
    begin
      aItem := lItem;
      Exit(True);
    end;
  aItem := Default(TDelphiSemanticGuidInventoryItem);
  Result := False;
end;

function TRefactorConsistencyTests.MakeDeclaration(const aName, aTypeName, aGuid: string;
  const aIsDispInterface: Boolean; const aRole: string): TDelphiSemanticDeclaration;
begin
  Result := Default(TDelphiSemanticDeclaration);
  Result.Name := aName;
  Result.Kind := 'type';
  Result.TypeName := aTypeName;
  Result.InterfaceGuid := aGuid;
  Result.IsDispInterface := aIsDispInterface;
  Result.DeclarationRole := aRole;
  Result.ScopeKind := 'unit';
end;

procedure TRefactorConsistencyTests.ExtractsInterfaceAndDispinterfaceGuidFacts;
const
  cGuid = '{11111111-2222-3333-4444-555555555555}';
var
  lDispInterfaceDeclaration: TDelphiSemanticDeclaration;
  lInterfaceDeclaration: TDelphiSemanticDeclaration;
  lMissingGuidDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := ExtractModel('GuidFacts',
    'unit GuidFacts;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  IGuidService = interface(IInterface)' + sLineBreak +
    '    [''' + cGuid + ''']' + sLineBreak +
    '    procedure Execute;' + sLineBreak +
    '  end;' + sLineBreak +
    '  DGuidService = dispinterface' + sLineBreak +
    '    [''' + cGuid + ''']' + sLineBreak +
    '    procedure Execute;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.');

  Assert.IsTrue(lModel.Success, 'The source model must be complete.');
  Assert.IsTrue(FindDeclaration(lModel, 'IGuidService', lInterfaceDeclaration),
    'IGuidService declaration');
  Assert.AreEqual('interface', lInterfaceDeclaration.TypeName);
  Assert.AreEqual(cGuid, lInterfaceDeclaration.InterfaceGuid);
  Assert.IsFalse(lInterfaceDeclaration.IsDispInterface);
  Assert.IsTrue(FindDeclaration(lModel, 'DGuidService', lDispInterfaceDeclaration),
    'DGuidService declaration');
  Assert.AreEqual('dispinterface', lDispInterfaceDeclaration.TypeName);
  Assert.AreEqual(cGuid, lDispInterfaceDeclaration.InterfaceGuid);
  Assert.IsTrue(lDispInterfaceDeclaration.IsDispInterface);
  lModel := ExtractModel('MissingGuidFacts',
    'unit MissingGuidFacts;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  IGuidWithoutId = interface(IInterface)' + sLineBreak +
    '    procedure Execute;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.');
  Assert.IsTrue(lModel.Success, 'The GUID-less source model must be complete.');
  Assert.IsTrue(FindDeclaration(lModel, 'IGuidWithoutId', lMissingGuidDeclaration),
    'IGuidWithoutId declaration');
  Assert.AreEqual('', lMissingGuidDeclaration.InterfaceGuid);
  Assert.IsFalse(lMissingGuidDeclaration.IsDispInterface);
end;

procedure TRefactorConsistencyTests.InventoryClassifiesPairsDuplicatesMissingAndUnknown;
const
  cPairGuid = '{AAAAAAAA-1111-2222-3333-444444444444}';
  cDuplicateGuid = '{BBBBBBBB-1111-2222-3333-444444444444}';
  cUniqueGuid = '{CCCCCCCC-1111-2222-3333-444444444444}';
  cUnknownGuid = '{DDDDDDDD-1111-2222-3333-444444444444}';
var
  lDeclarations: TArray<TDelphiSemanticDeclaration>;
  lInventory: TDelphiSemanticGuidInventory;
  lItem: TDelphiSemanticGuidInventoryItem;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.Success := True;
  lModel.FileName := 'GuidInventory.pas';
  lModel.UnitName := 'GuidInventory';
  lModel.ScopeModelStatus := 'ast';
  lDeclarations := [
    MakeDeclaration('IPaired', 'interface', cPairGuid, False, 'declaration'),
    MakeDeclaration('DPaired', 'dispinterface', cPairGuid, True, 'declaration'),
    MakeDeclaration('IDuplicateOne', 'interface', cDuplicateGuid, False, 'declaration'),
    MakeDeclaration('IDuplicateTwo', 'interface', LowerCase(cDuplicateGuid), False,
      'declaration'),
    MakeDeclaration('IUnique', 'interface', cUniqueGuid, False, 'declaration'),
    MakeDeclaration('IMissingGuid', 'interface', '', False, 'declaration'),
    MakeDeclaration('IUnknownGuidFacts', 'interface', cUnknownGuid, False, 'invalid')];
  lModel.Declarations := lDeclarations;

  lInventory := TDelphiSemanticGuidInventoryPlanner.Inspect([lModel]);

  Assert.IsTrue(FindInventoryItem(lInventory, 'IPaired', lItem));
  Assert.AreEqual(TDelphiSemanticGuidStatus.gsValidPair, lItem.Status);
  Assert.IsTrue(FindInventoryItem(lInventory, 'DPaired', lItem));
  Assert.AreEqual(TDelphiSemanticGuidStatus.gsValidPair, lItem.Status);
  Assert.IsTrue(FindInventoryItem(lInventory, 'IDuplicateOne', lItem));
  Assert.AreEqual(TDelphiSemanticGuidStatus.gsDuplicate, lItem.Status);
  Assert.IsTrue(FindInventoryItem(lInventory, 'IDuplicateTwo', lItem));
  Assert.AreEqual(TDelphiSemanticGuidStatus.gsDuplicate, lItem.Status);
  Assert.IsTrue(FindInventoryItem(lInventory, 'IUnique', lItem));
  Assert.AreEqual(TDelphiSemanticGuidStatus.gsUnique, lItem.Status);
  Assert.IsTrue(FindInventoryItem(lInventory, 'IMissingGuid', lItem));
  Assert.AreEqual(TDelphiSemanticGuidStatus.gsMissingGuid, lItem.Status);
  Assert.IsTrue(FindInventoryItem(lInventory, 'IUnknownGuidFacts', lItem));
  Assert.AreEqual(TDelphiSemanticGuidStatus.gsUnknown, lItem.Status);
end;

procedure TRefactorConsistencyTests.ExtractsHandlerCallingConvention;
var
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lFound: Boolean;
begin
  lModel := ExtractModel('EventHandlerFacts',
    'unit EventHandlerFacts;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TForm1 = class' + sLineBreak +
    '    procedure HandleData(Sender: TObject); stdcall;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TForm1.HandleData(Sender: TObject); stdcall;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'end.');
  Assert.IsTrue(lModel.Success, 'The handler source model must be complete.');
  lFound := False;
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.OwnerName, 'TForm1') and SameText(lRoutine.Name, 'HandleData') then
    begin
      Assert.AreEqual('stdcall', LowerCase(lRoutine.CallingConvention));
      Assert.IsTrue(lRoutine.ProcedureSignature.Known, 'Structured handler signature must be retained');
      Assert.AreEqual('procedure', lRoutine.ProcedureSignature.Kind);
      Assert.AreEqual('stdcall', lRoutine.ProcedureSignature.CallingConvention);
      Assert.AreEqual(Integer(1), Integer(Length(lRoutine.ProcedureSignature.Parameters)));
      Assert.AreEqual('TObject', lRoutine.ProcedureSignature.Parameters[0].TypeName);
      lFound := True;
    end;
  Assert.IsTrue(lFound, 'The handler declaration must be extracted.');
end;

procedure TRefactorConsistencyTests.ExtractsStructuredEventSignatures;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := ExtractModel('StructuredEvents',
    'unit StructuredEvents;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TDataEvent = function(const aFirst, aSecond: TObject; var aValue: TObject): TObject of object; stdcall;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.');
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'TDataEvent', lDeclaration));
  Assert.IsTrue(lDeclaration.ProcedureSignature.Known, 'AST procedural signature must be retained');
  Assert.IsTrue(lDeclaration.ProcedureSignature.OfObject);
  Assert.AreEqual('function', lDeclaration.ProcedureSignature.Kind);
  Assert.AreEqual('stdcall', lDeclaration.ProcedureSignature.CallingConvention);
  Assert.AreEqual('TObject', lDeclaration.ProcedureSignature.ReturnType);
  Assert.AreEqual(Integer(3), Integer(Length(lDeclaration.ProcedureSignature.Parameters)));
  Assert.AreEqual('const', lDeclaration.ProcedureSignature.Parameters[0].Modifier);
  Assert.AreEqual('TObject', lDeclaration.ProcedureSignature.Parameters[1].TypeName);
  Assert.AreEqual('var', lDeclaration.ProcedureSignature.Parameters[2].Modifier);
end;
procedure TRefactorConsistencyTests.RefusesIncompleteStructuredParameterTypes;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := ExtractModel('ComplexEvents',
    'unit ComplexEvents;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TDataEvent = procedure(aValues: array of TObject) of object;' + sLineBreak +
    'implementation' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success, 'Complex event source must parse');
  Assert.IsTrue(FindDeclaration(lModel, 'TDataEvent', lDeclaration), 'Event declaration must exist');
  Assert.IsFalse(lDeclaration.ProcedureSignature.Known,
    'An open array must not be certified as its element type');
end;

procedure TRefactorConsistencyTests.PreservesConsistencyFactsThroughModelJson;
var
  lModel: TDelphiSemanticUnitModel;
  lRestored: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lRoutine: TDelphiSemanticRoutine;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lDeclaration := MakeDeclaration('IService', 'interface',
    '{11111111-2222-3333-4444-555555555555}', True, 'declaration');
  lDeclaration.ProcedureSignature.Known := True;
  lDeclaration.ProcedureSignature.OfObject := True;
  lDeclaration.ProcedureSignature.Kind := 'procedure';
  lDeclaration.ProcedureSignature.CallingConvention := 'stdcall';
  SetLength(lDeclaration.ProcedureSignature.Parameters, 1);
  lDeclaration.ProcedureSignature.Parameters[0].Name := 'aValue';
  lDeclaration.ProcedureSignature.Parameters[0].TypeName := 'TValue';
  lDeclaration.ProcedureSignature.Parameters[0].Modifier := 'var';
  lRoutine := Default(TDelphiSemanticRoutine);
  lRoutine.CallingConvention := 'stdcall';
  lRoutine.ProcedureSignature := lDeclaration.ProcedureSignature;
  lModel.Declarations := [lDeclaration];
  lModel.Routines := [lRoutine];
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.AreEqual(lDeclaration.InterfaceGuid, lRestored.Declarations[0].InterfaceGuid);
  Assert.IsTrue(lRestored.Declarations[0].IsDispInterface);
  Assert.IsTrue(lRestored.Declarations[0].ProcedureSignature.Known);
  Assert.IsTrue(lRestored.Declarations[0].ProcedureSignature.OfObject);
  Assert.AreEqual('stdcall', lRestored.Routines[0].CallingConvention);
  Assert.IsTrue(lRestored.Routines[0].ProcedureSignature.Known);
  Assert.AreEqual('procedure', lRestored.Routines[0].ProcedureSignature.Kind);
  Assert.AreEqual('stdcall', lRestored.Routines[0].ProcedureSignature.CallingConvention);
  Assert.AreEqual(Integer(1), Integer(Length(lRestored.Routines[0].ProcedureSignature.Parameters)));
  Assert.AreEqual('var', lRestored.Routines[0].ProcedureSignature.Parameters[0].Modifier);
  Assert.AreEqual('TValue', lRestored.Routines[0].ProcedureSignature.Parameters[0].TypeName);
  Assert.AreEqual('aValue', lRestored.Routines[0].ProcedureSignature.Parameters[0].Name);
end;

procedure TRefactorConsistencyTests.ComparesSourceResolvedSignatureTypes;
var
  lModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lEvent: TDelphiSemanticProcedureSignature;
  lHandler: TDelphiSemanticProcedureSignature;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticEventComparison;
begin
  lModel := ExtractModel('ComparisonTypes', 'unit ComparisonTypes;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TEvent = procedure(var aValue: TValue) of object; stdcall;' + sLineBreak +
    'implementation' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'TEvent', lDeclaration));
  lEvent := lDeclaration.ProcedureSignature;
  lHandler := lEvent;
  lHandler.Parameters := Copy(lEvent.Parameters);
  lHandler.Parameters[0].Name := 'DifferentParameterName';
  lHandler.Parameters[0].TypeName := 'ComparisonTypes.TValue';
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectName := 'EventComparison';
  lProject.ContextFingerprint := 'event-comparison';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lResult := TDelphiSemanticEventSignatureComparer.Compare(lEvent, lHandler,
      lModel.UnitName, lModel.UnitName, [], [], TDelphiSemanticTypeResolver.BuildIndex(lGraph));
    Assert.AreEqual('match', lResult.Status, lResult.Reason + sLineBreak + ModelToJson(lModel));
  finally
    lGraph.Free;
  end;
end;

procedure TRefactorConsistencyTests.RejectsIncompatibleEventSignatures(
  const aChange, aStatus, aReason: string);
var
  lModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lEvent: TDelphiSemanticProcedureSignature;
  lHandler: TDelphiSemanticProcedureSignature;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticEventComparison;
begin
  lModel := ExtractModel('MismatchTypes', 'unit MismatchTypes;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TOther = class end;' + sLineBreak +
    '  TEvent = procedure(var aValue: TValue) of object; stdcall;' + sLineBreak +
    'implementation' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'TEvent', lDeclaration));
  lEvent := lDeclaration.ProcedureSignature;
  lHandler := lEvent;
  lHandler.Parameters := Copy(lEvent.Parameters);
  if aChange = 'mode' then
    lHandler.Parameters[0].Modifier := 'const'
  else if aChange = 'convention' then
    lHandler.CallingConvention := 'cdecl'
  else if aChange = 'count' then
    lHandler.Parameters := nil
  else if aChange = 'type' then
    lHandler.Parameters[0].TypeName := 'TOther'
  else if aChange = 'missing' then
    lHandler.Parameters[0].TypeName := 'TUnknown';
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectName := 'EventMismatch';
  lProject.ContextFingerprint := 'event-mismatch';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lResult := TDelphiSemanticEventSignatureComparer.Compare(lEvent, lHandler,
      lModel.UnitName, lModel.UnitName, [], [], TDelphiSemanticTypeResolver.BuildIndex(lGraph));
    Assert.AreEqual(aStatus, lResult.Status);
    Assert.AreEqual(aReason, lResult.Reason);
  finally
    lGraph.Free;
  end;
end;

procedure TRefactorConsistencyTests.ResolvesInheritedEventAndHandler(const aConventionAt: string);
var
  lEventConvention, lHandlerConvention: string;
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lBinding: TDelphiSemanticEventBinding;
  lResult: TDelphiSemanticEventBindingResult;
begin
  lEventConvention := '';
  lHandlerConvention := '';
  if aConventionAt = 'event' then
    lEventConvention := ' register;'
  else if aConventionAt = 'handler' then
    lHandlerConvention := ' register;';
  lModel := ExtractModel('InheritedEvents', 'unit InheritedEvents;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TEvent = procedure(aValue: TValue) of object;' + lEventConvention + sLineBreak +
    '  TControlBase = class' + sLineBreak +
    '  private' + sLineBreak + '    FEvent: TEvent;' + sLineBreak +
    '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak + '  end;' + sLineBreak +
    '  TControlChild = class(TControlBase) end;' + sLineBreak +
    '  TFormBase = class' + sLineBreak + '  published' + sLineBreak +
    '    procedure HandleData(aValue: TValue);' + lHandlerConvention + sLineBreak +
    '  end;' + sLineBreak +
    '  TFormChild = class(TFormBase) end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TFormBase.HandleData(aValue: TValue);' + lHandlerConvention + sLineBreak +
    'begin end;' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  lProject := Default(TDelphiSemanticProjectInfo);
  lModel := JsonToModel(ModelToJson(lModel));
  lProject.ProjectName := 'InheritedEvents';
  lProject.ContextFingerprint := 'inherited-events';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FormClassName := 'TFormChild';
    lBinding.ComponentClassName := 'TControlChild';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := 'HandleData';
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel], TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual('match', lResult.Status, lResult.Reason + sLineBreak + ModelToJson(lModel));
    Assert.AreEqual('TControlBase', lResult.EventProperty.OwnerName);
    Assert.AreEqual('TFormBase', lResult.Handler.OwnerName);
    Assert.AreEqual('TEvent', lResult.EventType.Name);
    Assert.IsTrue(lResult.Handler.Line > 0);
  finally
    lGraph.Free;
  end;
end;

procedure TRefactorConsistencyTests.RequiresCompleteSignatureContext(const aShape, aStatus: string);
var
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lDeclaration: TDelphiSemanticDeclaration;
  lTypes: TDelphiSemanticTypeIdentityIndex;
  lComparison: TDelphiSemanticEventComparison;
  lHandlerUnit: string;
begin
  lModel := ExtractModel('ContextEvents', 'unit ContextEvents;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TEvent = procedure of object;' + sLineBreak + 'implementation' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'TEvent', lDeclaration));
  Assert.IsTrue(lDeclaration.ProcedureSignature.Known);
  lHandlerUnit := lModel.UnitName;
  if aShape = 'partial' then
    lModel.ScopeModelStatus := 'ast-interface-only';
  lModels := [lModel];
  if aShape = 'duplicate' then
    lModels := [lModel, lModel]
  else if aShape = 'missing' then
    lModels := nil
  else if aShape = 'handler' then
    lHandlerUnit := 'UnavailableUnit';
  lTypes := Default(TDelphiSemanticTypeIdentityIndex);
  lComparison := TDelphiSemanticEventSignatureComparer.CompareInContext(
    lDeclaration.ProcedureSignature, lDeclaration.ProcedureSignature, lModel.UnitName,
    lHandlerUnit, lModels, lTypes);
  Assert.AreEqual(aStatus, lComparison.Status, lComparison.Reason);
end;

function TRefactorConsistencyTests.AliasContextModels(const aShape: string):
  TArray<TDelphiSemanticUnitModel>;
var
  lImports, lAlias, lEvent, lExtra: string;
begin
  SetLength(Result, 3);
  Result[0] := ExtractModel('BaseTypes', 'unit BaseTypes;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak + '  TBase = (one, two);' + sLineBreak +
    '  TOriginal = procedure(var aValue: TBase) of object;' +
    sLineBreak + 'implementation' + sLineBreak + 'end.');
  lImports := 'uses BaseTypes;' + sLineBreak;
  lAlias := 'TBase';
  lEvent := '  TEvent = procedure(var aValue: TAlias) of object;';
  lExtra := '';
  if aShape = 'event-origin' then
  begin
    lEvent := '  TEvent = BaseTypes.TOriginal;';
    lExtra := '  TBase = (aliasOne, aliasTwo);' + sLineBreak;
  end;
  if (aShape = 'hidden') or (aShape = 'qualified-hidden') then
    lImports := '';
  if aShape = 'qualified-hidden' then
    lAlias := 'BaseTypes.TBase';
  Result[1] := ExtractModel('AliasTypes', 'unit AliasTypes;' + sLineBreak +
    'interface' + sLineBreak + '{$M+}' + sLineBreak + lImports + 'type' + sLineBreak + lExtra +
    '  TAlias = ' + lAlias + ';' + sLineBreak +
    lEvent + sLineBreak +
    '  TControl = class' + sLineBreak + '  private' + sLineBreak +
    '    FEvent: TEvent;' + sLineBreak + '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak +
    '  end;' + sLineBreak + 'implementation' + sLineBreak + 'end.');
  Result[2] := ExtractModel('FormTypes', 'unit FormTypes;' + sLineBreak +
    'interface' + sLineBreak + '{$M+}' + sLineBreak + 'uses AliasTypes, BaseTypes;' + sLineBreak +
    'type' + sLineBreak + '  TBase = (otherOne, otherTwo);' + sLineBreak +
    '  TForm = class' + sLineBreak + '  published' + sLineBreak +
    '    procedure Handle(var aValue: BaseTypes.TBase);' + sLineBreak +
    '  end;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure TForm.Handle(var aValue: BaseTypes.TBase);' + sLineBreak +
    'begin end;' + sLineBreak + 'end.');
  if aShape = 'partial' then
    Result[0].ScopeModelStatus := 'ast-interface-only';
end;

procedure TRefactorConsistencyTests.ResolvesAliasInDeclarationContext(const aShape, aStatus: string);
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lBinding: TDelphiSemanticEventBinding;
  lResult: TDelphiSemanticEventBindingResult;
  lModel: TDelphiSemanticUnitModel;
  i: Integer;
begin
  lModels := AliasContextModels(aShape);
  for lModel in lModels do
  begin
    Assert.IsTrue(lModel.Success, ModelToJson(lModel));
    Assert.AreEqual(0, lModel.RejectedDeclarationCount, ModelToJson(lModel));
  end;
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectName := 'AliasContexts';
  lProject.ContextFingerprint := 'alias-contexts';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, lModels);
  try
    if aShape = 'missing' then
      lModels := [lModels[1], lModels[2]]
    else if aShape = 'file' then
      lModels[0].FileName := lModels[0].FileName + '.other'
    else if aShape = 'position' then
      for i := 0 to High(lModels[0].Declarations) do
        if lModels[0].Declarations[i].Name = 'TBase' then
          Inc(lModels[0].Declarations[i].Offset);
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := 'FormTypes';
    lBinding.FormClassName := 'TForm';
    lBinding.ComponentClassName := 'AliasTypes.TControl';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := 'Handle';
    lResult := TDelphiSemanticEventBindingResolver.Resolve(lModels,
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason);
    if aShape = 'event-origin' then
    begin
      Assert.AreEqual('BaseTypes', lResult.EventType.UnitName);
      Assert.AreEqual('TOriginal', lResult.EventType.Name);
    end;
  finally
    lGraph.Free;
  end;
end;

function AliasBindingSource(const aShape: string): string;
var
  lAlias, lIntermediate, lEvent, lHandlerType: string;
begin
  lAlias := 'TBase';
  lIntermediate := 'TBase';
  lHandlerType := 'TBase';
  lEvent := '  TEvent = procedure(var aValue: TAlias) of object;';
  if aShape = 'chain' then
    lAlias := 'TIntermediate'
  else if (aShape = 'distinct') or (aShape = 'same-distinct') then
    lAlias := 'type TBase'
  else if aShape = 'cycle' then
  begin
    lAlias := 'TIntermediate';
    lIntermediate := 'TAlias';
  end;
  if aShape = 'ordinary' then
    lEvent := '  TEvent = TAlias;';
  if aShape = 'same-distinct' then
    lHandlerType := 'TAlias';
  if (aShape = 'event') or (aShape = 'event-chain') then
  begin
    lEvent := '  TOriginal = procedure(var aValue: TBase) of object;' + sLineBreak;
    if aShape = 'event-chain' then
      lEvent := lEvent + '  TEventIntermediate = TOriginal;' + sLineBreak +
        '  TEvent = TEventIntermediate;'
    else
      lEvent := lEvent + '  TEvent = TOriginal;';
  end;
  Result := 'unit AliasEvents;' + sLineBreak + 'interface' + sLineBreak + '{$M+}' +
    sLineBreak + 'type' + sLineBreak + '  TBase = (one, two);' + sLineBreak +
    '  TIntermediate = ' + lIntermediate + ';' + sLineBreak +
    '  TAlias = ' + lAlias + ';' + sLineBreak + lEvent + sLineBreak +
    '  TReceiver = class' + sLineBreak + '  private' + sLineBreak +
    '    FEvent: TEvent;' + sLineBreak + '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak +
    '    procedure Handle(var aValue: ' + lHandlerType + ');' + sLineBreak +
    '  end;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure TReceiver.Handle(var aValue: ' + lHandlerType + ');' + sLineBreak +
    'begin end;' + sLineBreak + 'end.';
end;

procedure TRefactorConsistencyTests.ResolvesAliasSignatures(const aShape, aStatus: string);
var
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lBinding: TDelphiSemanticEventBinding;
  lResult: TDelphiSemanticEventBindingResult;
begin
  lModel := ExtractModel('AliasEvents', AliasBindingSource(aShape));
  Assert.IsTrue(lModel.Success, ModelToJson(lModel));
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual(0, lModel.RejectedDeclarationCount);
  lModel := JsonToModel(ModelToJson(lModel));
  lProject := Default(TDelphiSemanticProjectInfo);
  lProject.ProjectName := 'AliasEvents';
  lProject.ContextFingerprint := 'alias-events';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FormClassName := 'TReceiver';
    lBinding.ComponentClassName := 'TReceiver';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := 'Handle';
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason + sLineBreak + ModelToJson(lModel));
    if aStatus = 'not-event' then
    begin
      Assert.AreEqual('TBase', lResult.EventType.Name);
      Assert.AreEqual('', lResult.Handler.Name);
    end;
  finally
    lGraph.Free;
  end;
end;

procedure TRefactorConsistencyTests.RefusesSameLineHandlerOverloads;
var
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lBinding: TDelphiSemanticEventBinding;
  lResult: TDelphiSemanticEventBindingResult;
begin
  lModel := ExtractModel('OverloadedEvents', 'unit OverloadedEvents;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TOther = class end;' + sLineBreak +
    '  TEvent = procedure(aValue: TValue) of object;' + sLineBreak +
    '  TControl = class' + sLineBreak +
    '  private' + sLineBreak + '    FEvent: TEvent;' + sLineBreak +
    '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak + '  end;' + sLineBreak +
    '  TForm = class' + sLineBreak + '  published' + sLineBreak +
    '    procedure Handle(aValue: TValue); overload; procedure Handle(aValue: TOther); overload;' +
    sLineBreak + '  end;' + sLineBreak + 'implementation' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FormClassName := 'TForm';
    lBinding.ComponentClassName := 'TControl';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := 'Handle';
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual('unknown', lResult.Status,
      'Overloads must not collapse into the last AST signature on a source line');
  finally
    lGraph.Free;
  end;
end;

procedure TRefactorConsistencyTests.ResolvesHandlersSharingOnePhysicalLine(const aLayout,
  aHandler: string);
var
  lBinding: TDelphiSemanticEventBinding;
  lGraph: TDelphiSemanticSemanticGraph;
  lLine: string;
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticEventBindingResult;
begin
  if aLayout = 'two-methods' then
    lLine := '  published procedure HandleOther(aValue: TValue); ' +
      'procedure HandleData(aValue: TValue);'
  else
    lLine := '  private FOther: TEvent; published procedure HandleOther(aValue: TValue);' +
      sLineBreak + '    procedure HandleData(aValue: TValue);';
  lModel := ExtractModel('SameLineEvents', 'unit SameLineEvents;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TEvent = procedure(aValue: TValue) of object;' + sLineBreak +
    '  TControl = class' + sLineBreak +
    '  private' + sLineBreak + '    FEvent: TEvent;' + sLineBreak +
    '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak + '  end;' + sLineBreak +
    '  TForm = class' + sLineBreak + lLine + sLineBreak + '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TForm.HandleOther(aValue: TValue); begin end;' + sLineBreak +
    'procedure TForm.HandleData(aValue: TValue); begin end;' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FormClassName := 'TForm';
    lBinding.ComponentClassName := 'TControl';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := aHandler;
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual('match', lResult.Status, lResult.Reason + sLineBreak + ModelToJson(lModel));
    Assert.AreEqual(aHandler, lResult.Handler.Name);
  finally
    lGraph.Free;
  end;
end;

// The line scan cannot read an inline procedural field type, so the syntax tree reconciliation
// records MEMBERS_INCOMPLETE and consistency refuses the whole unit instead of trusting it.
procedure TRefactorConsistencyTests.RefusesUnitWithIncompleteMembers(
  const aProceduralField: Boolean; const aStatus: string);
var
  lBinding: TDelphiSemanticEventBinding;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lField: string;
  lGraph: TDelphiSemanticSemanticGraph;
  lIncomplete: string;
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticEventBindingResult;
begin
  lField := '    FOnX: TEvent;';
  if aProceduralField then
    lField := '    FOnX: procedure(a: Integer) of object;';
  lModel := ExtractModel('IncompleteEvents', 'unit IncompleteEvents;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TEvent = procedure(aValue: TValue) of object;' + sLineBreak +
    '  TControl = class' + sLineBreak +
    '  private' + sLineBreak + '    FEvent: TEvent;' + sLineBreak +
    '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak + '  end;' + sLineBreak +
    '  TForm = class' + sLineBreak + '  private' + sLineBreak + lField + sLineBreak +
    '  published' + sLineBreak + '    procedure HandleData(aValue: TValue);' + sLineBreak +
    '  end;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure TForm.HandleData(aValue: TValue); begin end;' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lIncomplete := '';
  for lDiagnostic in lModel.Diagnostics do
    if SameText(lDiagnostic.Code, 'MEMBERS_INCOMPLETE') then
      lIncomplete := lDiagnostic.Message;
  if aProceduralField then
  begin
    // The diagnostic names the type and the member the scan missed.
    Assert.IsTrue(Pos('TForm', lIncomplete) > 0, lIncomplete);
    Assert.IsTrue(Pos('FOnX', lIncomplete) > 0, lIncomplete);
  end else
    Assert.AreEqual('', lIncomplete);
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FormClassName := 'TForm';
    lBinding.ComponentClassName := 'TControl';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := 'HandleData';
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason);
  finally
    lGraph.Free;
  end;
end;

procedure TRefactorConsistencyTests.IsolatesIncompleteMemberOwners(
  const aFault, aStatus: string);
var
  lBinding: TDelphiSemanticEventBinding;
  lGraph: TDelphiSemanticSemanticGraph;
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lResult: TDelphiSemanticEventBindingResult;
  lCount, i, lOwner: Integer;
  lSource: string;
begin
  lSource := 'unit OwnerCompleteness;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TEvent = procedure(aValue: TValue) of object;' + sLineBreak +
    '  TControl = class' + sLineBreak +
    '    FEvent: TEvent;' + sLineBreak +
    '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TForm = class' + sLineBreak +
    '  published' + sLineBreak +
    '    procedure HandleData(aValue: TValue);' + sLineBreak +
    '  end;' + sLineBreak +
    '  TBroken = class' + sLineBreak +
    '    FUnscanned: procedure(aValue: Integer) of object;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TForm.HandleData(aValue: TValue); begin end;' + sLineBreak + 'end.';
  lModel := ExtractModel('OwnerCompleteness', lSource);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual(0, lModel.RejectedDeclarationCount);
  if aFault = 'duplicate' then
  begin
    lOwner := -1;
    for i := 0 to High(lModel.Declarations) do
      if SameText(lModel.Declarations[i].Name, 'TBroken') then
        lOwner := i;
    Assert.IsTrue(lOwner >= 0);
    // Duplicate facts cannot establish one reliable diagnostic owner.
    SetLength(lModel.Declarations, Length(lModel.Declarations) + 1);
    lModel.Declarations[High(lModel.Declarations)] := lModel.Declarations[lOwner];
  end;
  lCount := 0;
  for i := 0 to High(lModel.Diagnostics) do
    if SameText(lModel.Diagnostics[i].Code, 'MEMBERS_INCOMPLETE') then
    begin
      Inc(lCount);
      Assert.IsTrue(Pos('TBroken', lModel.Diagnostics[i].Message) > 0);
      if aFault = 'file' then
        lModel.Diagnostics[i].FileName := lModel.FileName + '.other'
      else if aFault = 'location' then
        lModel.Diagnostics[i].Line := 0
      else if aFault = 'other' then
        lModel.Diagnostics[i].Code := 'MEMBERS_UNVERIFIED';
    end;
  Assert.AreEqual(1, lCount, 'The source must actually exercise incomplete member extraction.');
  if aFault = 'unrelated' then
    Assert.AreEqual(0, TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(
      [lModel], lModel.UnitName))
  else
    Assert.AreEqual(-1, TDelphiSemanticConsistencyTypeResolver.FindCompleteModelIndex(
      [lModel], lModel.UnitName));
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FormClassName := 'TForm';
    lBinding.ComponentClassName := 'TControl';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := 'HandleData';
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason);
    lBinding.FormClassName := 'TBroken';
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual('unknown', lResult.Status, lResult.Reason);
  finally
    lGraph.Free;
  end;
end;

procedure TRefactorConsistencyTests.DistinguishesMissingHandlerFromUnknownAncestry(
  const aShape, aStatus: string);
var
  lModel: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lBinding: TDelphiSemanticEventBinding;
  lResult: TDelphiSemanticEventBindingResult;
  lBase: string;
begin
  lBase := ' end';
  if aShape = 'external' then
    lBase := '(TUnavailableBase) end';
  if aShape = 'forward' then
    lBase := '';
  lModel := ExtractModel('MissingEvents', 'unit MissingEvents;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TValue = class end;' + sLineBreak +
    '  TEvent = procedure(aValue: TValue) of object;' + sLineBreak +
    '  TControl = class' + sLineBreak + '  private' + sLineBreak +
    '    FEvent: TEvent;' + sLineBreak + '  published' + sLineBreak +
    '    property OnData: TEvent read FEvent write FEvent;' + sLineBreak +
    '  end;' + sLineBreak + '  TBaseForm = class' + lBase + ';' + sLineBreak +
    '  TForm = class(TBaseForm)' + sLineBreak + '  published' + sLineBreak +
    '    procedure PresentHandler(aValue: TValue);' + sLineBreak + '  end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  if (aShape = 'incomplete') or (aShape = 'recovered-match') then
    lModel.ScopeModelStatus := 'ast-interface-only';
  if aShape = 'rejected-match' then
    lModel.RejectedDeclarationCount := 1;
  lProject := Default(TDelphiSemanticProjectInfo);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel]);
  try
    lBinding := Default(TDelphiSemanticEventBinding);
    lBinding.UnitName := lModel.UnitName;
    lBinding.FormClassName := 'TForm';
    lBinding.ComponentClassName := 'TControl';
    lBinding.EventName := 'OnData';
    lBinding.HandlerName := 'AbsentHandler';
    if aShape.EndsWith('-match') then
      lBinding.HandlerName := 'PresentHandler';
    lResult := TDelphiSemanticEventBindingResolver.Resolve([lModel],
      TDelphiSemanticTypeResolver.BuildIndex(lGraph), lBinding);
    Assert.AreEqual(aStatus, lResult.Status, lResult.Reason);
    if aStatus = 'missing-handler' then
    begin
      Assert.AreEqual('binding.handler-missing', lResult.Reason);
      Assert.AreEqual('OnData', lResult.EventProperty.Name);
      Assert.AreEqual('TEvent', lResult.EventType.Name);
      Assert.AreEqual('', lResult.Handler.Name);
    end;
  finally
    lGraph.Free;
  end;
end;
procedure TRefactorConsistencyTests.PreservesForwardTypeDeclarationRole(const aKind: string);
var
  lModel: TDelphiSemanticUnitModel;
  lRestored: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
begin
  lModel := ExtractModel('ForwardFacts', 'unit ForwardFacts;' + sLineBreak +
    'interface' + sLineBreak + 'type TPending = ' + aKind + ';' + sLineBreak +
    'implementation' + sLineBreak + 'end.');
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindDeclaration(lModel, 'TPending', lDeclaration));
  Assert.AreEqual('forward', lDeclaration.DeclarationRole);
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(FindDeclaration(lRestored, 'TPending', lDeclaration));
  Assert.AreEqual('forward', lDeclaration.DeclarationRole);
end;
initialization
  TDUnitX.RegisterTestFixture(TRefactorConsistencyTests);

end.
