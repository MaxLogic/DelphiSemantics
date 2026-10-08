unit Test.WithBinder;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Api, DelphiSemantics.Api.RemoveWith,
  DelphiSemantics.Api.RemoveWith.Compatibility,
  DelphiSemantics.Model, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TWithBinderTests = class
  private
    function LoadModel: TDelphiSemanticUnitModel;
    function LoadBareReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
    function LoadReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
    function HasReference(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): Boolean;
    function HasAnyReference(const aBinding: TDelphiSemanticWithBinding; const aName: string):
      Boolean;
    function ReceiverOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function CountReferences(const aBinding: TDelphiSemanticWithBinding; const aName: string):
      Integer;
    function LookupSourceOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function ReasonOf(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): string;
    function HasInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
      const aName, aSymbolClass, aRoutineName: string): Boolean;
    function TryFindInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
      const aName, aSymbolClass, aOwnerName: string; out aSymbol:
      TDelphiSemanticInventorySymbol): Boolean;
  public
    [Test]
    procedure ResolvesSelectorTypesAndClassifiesBodyIdentifiers;
    [Test]
    procedure BindingsExposeSourceRangesForDakPlanner;
    [Test]
    procedure MultipleSelectorsPreferInnermostReceiver;
    [Test]
    procedure AmbiguousReceiverMembersClassifyAsAmbiguous;
    [Test]
    procedure ClassMethodWithBindingUsesOwnedRoutineTypeForInheritedProtectedMembers;
    [Test]
    procedure InheritedHomonymProjectionsKeepTheirAccessDeclaration;
    [Test]
    procedure OneLineTypeDeclarationsDoNotOpenMemberBodies;
    [Test]
    procedure IndexedPropertySelectorWithoutDereferenceStaysUnsupported;
    [Test]
    procedure MemberReferenceReportsRoutineScopeConflict;
    [Test]
    procedure UnresolvedSelectorMarksBodyReferencesExternal;
    [Test]
    procedure NestedWithStatementsUseOuterReceiverStack;
    [Test]
    procedure NestedRoutineWithUsesParentRoutineScope;
    [Test]
    procedure SiblingRoutineLocalsDoNotLeakIntoNestedWith;
    [Test]
    procedure PlanningMetadataCountsLookupSourcesAndReasons;
    [Test]
    procedure ScopedDeclarationsMarkBindingSkipped;
    [Test]
    procedure ControlCharacterLiteralsAreIgnored;
    [Test]
    procedure SafeBindingsArePlannedDirectReferences;
    [Test]
    procedure SkipReasonsCoverExternalAndUnresolvedBranches;
    [Test]
    procedure CastExpressionRolesRemainUnsupported;
    [Test]
    procedure InventoryExposesFileAwareSymbolsAndBindings;
    [Test]
    procedure InventoryExposesDakPlannerSourceModelFacts;
    [Test]
    procedure InventoryExpansionUsesIndexedOwnMemberLookup;
    [Test]
    procedure InventoryExpansionUsesStableRelatedMemberOwnerIndex;
    [Test]
    procedure InventoryExpansionIndexesCurrentClassProjectionContexts;
    [Test]
    procedure InventoryExpansionScopesCurrentClassProjectionByUnit;
    [Test]
    procedure ReferenceScannerPreservesRepresentativeTokenShapes;
    [Test]
    procedure ReferenceBindingUsesManualIdentifierScanner;
    [Test]
    procedure InventoryExpansionUsesOrdinalIgnoreCaseSymbolKeys;
    [Test]
    procedure InventoryExpansionDeduplicatesSymbolsCaseInsensitively;
    [Test]
    procedure AnonymousNestedRecordSelectorsUseSyntheticOwner;
    [Test]
    procedure GlobalAnonymousRecordSelectorUsesSyntheticOwner;
    [Test]
    procedure DefaultIndexedPropertyPointerSelectorDereferencesToRecord;
    [Test]
    procedure NestedParentDefaultIndexedPropertyPointerSelectorDereferencesToRecord;
    [Test]
    procedure NestedParentIndexedSelectorPreservesPrecedenceAndSafety;
    [Test]
    procedure NestedUnresolvedSelectorRefusesFinalRewrite;
    [Test]
    procedure NestedIndexedSelectorPreservesBoundTypeDeclaringUnit;
    [Test]
    procedure HiddenCompleteReceiverIgnoresUnrelatedDiagnostics;
    [Test]
    procedure AmbiguousFinalReceiverTypeFailsClosed;
    [Test]
    procedure HiddenReceiverExactOwnerDiagnosticsRefuse;
    [Test]
    procedure BareImportedReceiverUsesActualOwnerForSafety;
    [Test]
    procedure BareImportedReceiverWithoutVisibleOwnerIsRefused;
    [Test]
    procedure NestedLocalReceiverKeepsSourceScopeAndIdentity;
    [Test]
    procedure LocalPointerPointeeShadowsImportedUnitHomonym;
    [Test]
    procedure PointerAliasesResolvePointeesFromTheirDeclarationScopes;
    [Test]
    procedure RoutineLocalHomonymMembersUseTheirOwnDeclaration;
    [Test]
    procedure RoutineLocalInheritedMembersNeverBindElsewhere;
    [Test]
    procedure MalformedPointerAliasOwnersAndAmbiguousPointeesAreRefused;
    [Test]
    procedure SelectorIdentityUsesTheDeclaringUnitScope;
    [Test]
    procedure ParameterTypesResolveInTheEnclosingScope;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  Winapi.Windows,
  maxLogic.IOUtils,
  Test.Support;

var
  GWithBinderTempRoot: string;

function WithBinderTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GWithBinderTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GWithBinderTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'with-binder-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GWithBinderTempRoot);
  Result := TPath.Combine(GWithBinderTempRoot, aName);
end;

procedure TWithBinderTests.NestedLocalReceiverKeepsSourceScopeAndIdentity;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lSeenNested: Boolean;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('RemoveWithLocalCaptureType',
    'LocalReceiver.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(
    lOptions);
  lSeenNested := False;
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName), 'LocalConsumer.pas') and
      (lBinding.Line = 37) then
    begin
      lSeenNested := True;
      Assert.IsNotEmpty(lBinding.RoutineScopeId);
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreEqual('TOuter', lBinding.Selectors[0].TypeIdentity.Name);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreNotEqual(lBinding.RoutineScopeId,
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId,
        'The receiver type belongs to the enclosing routine.');
    end;
  Assert.IsTrue(lSeenNested, 'The source-backed nested WITH must be discovered.');
end;

procedure TWithBinderTests.LocalPointerPointeeShadowsImportedUnitHomonym;
var
  lBinding: TDelphiSemanticWithBinding;
  lConsumerModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lLocal: TDelphiSemanticLocal;
  lLocalType: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lProviderTypeCount: Integer;
  lRoot: string;
  lSeenBinding: Boolean;
  lSeenConsumer: Boolean;
  lSeenLocalMember: Boolean;
  lSeenLocalType: Boolean;
  lSeenPointer: Boolean;
  lSeenProvider: Boolean;
  lSeenProviderUse: Boolean;
  lSeenSymbol: Boolean;
  lSymbol: TDelphiSemanticInventorySymbol;
  lUsedUnit: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-pointer-homonym-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'PointerScopeHomonym.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'PointerScopeHomonym.dpr'),
    'program PointerScopeHomonym;'#13#10 +
    'uses LocalPointerConsumer in ''LocalPointerConsumer.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>PointerScopeHomonym.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="LocalPointerProvider.pas"/>' +
    '<DCCReference Include="LocalPointerConsumer.pas"/></ItemGroup></Project>',
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'LocalPointerProvider.pas'),
    'unit LocalPointerProvider;'#13#10 +
    'interface'#13#10 +
    'type TNode = record UnitOnly: Integer; end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'LocalPointerConsumer.pas'),
    'unit LocalPointerConsumer;'#13#10 +
    'interface'#13#10 +
    'procedure Run;'#13#10 +
    'implementation'#13#10 +
    'uses LocalPointerProvider;'#13#10 +
    'procedure Run;'#13#10 +
    'type TNode = record LocalOnly: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lNode: TNode;'#13#10 +
    '  lPointer: ^TNode;'#13#10 +
    '  procedure Nested;'#13#10 +
    '  begin'#13#10 +
    '    with lPointer^ do LocalOnly := 1;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    '  lPointer := @lNode;'#13#10 +
    '  Nested;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lConsumerModel := Default(TDelphiSemanticUnitModel);
  lSeenConsumer := False;
  lSeenProvider := False;
  lSeenProviderUse := False;
  lProviderTypeCount := 0;
  for lModel in lFacts.UnitModels do
  begin
    if SameText(lModel.UnitName, 'LocalPointerConsumer') then
    begin
      lConsumerModel := lModel;
      lSeenConsumer := True;
      for lUsedUnit in lModel.ImplementationUses do
        if SameText(lUsedUnit, 'LocalPointerProvider') then
          lSeenProviderUse := True;
    end else if SameText(lModel.UnitName, 'LocalPointerProvider') then
    begin
      lSeenProvider := True;
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.Name, 'TNode') and
          SameText(lDeclaration.ScopeKind, 'unit') then
          Inc(lProviderTypeCount);
    end;
  end;
  Assert.IsTrue(lSeenConsumer and lConsumerModel.Success, 'Actual consumer AST model');
  Assert.IsTrue(lSeenProvider and lSeenProviderUse and (lProviderTypeCount = 1),
    'The imported unit homonym must be present and visible to the consumer.');
  lLocalType := Default(TDelphiSemanticDeclaration);
  lSeenLocalType := False;
  for lDeclaration in lConsumerModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'routine') then
    begin
      Assert.IsFalse(lSeenLocalType, 'Only one local TNode should be declared.');
      lLocalType := lDeclaration;
      lSeenLocalType := True;
    end;
  Assert.IsTrue(lSeenLocalType, 'The actual AST must retain the local declaration.');
  Assert.IsNotEmpty(lLocalType.OwnerScopeId);
  Assert.IsNotEmpty(lLocalType.SymbolId);
  lSeenPointer := False;
  for lLocal in lConsumerModel.Locals do
    if SameText(lLocal.Name, 'lPointer') then
    begin
      Assert.IsFalse(lSeenPointer, 'Only one pointer local should be extracted.');
      Assert.AreEqual('Run', lLocal.RoutineName);
      Assert.AreEqual('^TNode', lLocal.TypeName);
      Assert.AreEqual(lLocalType.OwnerScopeId, lLocal.RoutineScopeId);
      Assert.IsTrue(lLocal.Line > 0, 'The pointer local needs a source position.');
      lSeenPointer := True;
    end;
  Assert.IsTrue(lSeenPointer, 'The actual model must extract the pointer local.');
  lSeenLocalMember := False;
  for lMember in lConsumerModel.Members do
    if SameText(lMember.Name, 'LocalOnly') then
    begin
      Assert.AreEqual(lLocalType.OwnerScopeId, lMember.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId, lMember.OwnerSymbolId);
      lSeenLocalMember := True;
    end;
  Assert.IsTrue(lSeenLocalMember, 'The local member must retain its AST owner.');
  lSeenBinding := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'LocalPointerConsumer') and
      SameText(lBinding.RoutineName, 'Nested') and
      SameText(lBinding.SelectorText, 'lPointer^') then
    begin
      Assert.IsFalse(lSeenBinding, 'Only one nested pointer WITH should be bound.');
      lSeenBinding := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('LocalPointerConsumer',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalType.OwnerScopeId,
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual(TPath.Combine(lRoot, 'LocalPointerConsumer.pas'),
        lBinding.Selectors[0].TypeIdentity.SourceRange.FileName);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'));
    end;
  Assert.IsTrue(lSeenBinding, 'The source-backed nested pointer WITH must be found.');
  lSeenSymbol := False;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.UnitName, 'LocalPointerConsumer') and
      SameText(lSymbol.Name, 'LocalOnly') and
      SameText(lSymbol.SymbolClass, 'field') then
    begin
      Assert.AreEqual(lLocalType.OwnerScopeId, lSymbol.OwnerIdentity.OwnerScopeId);
      Assert.AreEqual(lLocalType.SymbolId, lSymbol.OwnerIdentity.SemanticSymbolId);
      lSeenSymbol := True;
    end;
  Assert.IsTrue(lSeenSymbol, 'The receiver member must use the local owner identity.');
end;

function BuildPointerAliasScopeModel: TDelphiSemanticUnitModel;
var
  lGuid: TGUID;
  lGuidText: string;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('pointer-alias-scope-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'PointerAliasScope.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit PointerAliasScope;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TNode = record UnitOnly: Integer; end;'#13#10 +
    '  PUnitNode = ^TNode;'#13#10 +
    'procedure UnitAliasRun(aItem: PUnitNode);'#13#10 +
    'procedure LocalAliasRun;'#13#10 +
    'implementation'#13#10 +
    'procedure UnitAliasRun(aItem: PUnitNode);'#13#10 +
    'type TNode = record LocalOnly: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aItem^ do UnitOnly := 1;'#13#10 +
    'end;'#13#10 +
    'procedure LocalAliasRun;'#13#10 +
    'type'#13#10 +
    '  TNode = record LocalOnly: Integer; end;'#13#10 +
    '  PLocalNode = ^TNode;'#13#10 +
    'var'#13#10 +
    '  lItem: PLocalNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem^ do LocalOnly := 1;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success, 'The pointer alias fixture must extract from source.');
end;

procedure TWithBinderTests.PointerAliasesResolvePointeesFromTheirDeclarationScopes;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalScopeId: string;
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lSeenLocal: Boolean;
  lSeenUnit: Boolean;
  lUnitNodeId: string;
  lLocalNodeId: string;
begin
  lModel := BuildPointerAliasScopeModel;
  lUnitNodeId := '';
  lLocalNodeId := '';
  lLocalScopeId := '';
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'LocalAliasRun') and
      SameText(lRoutine.SectionKind, 'implementation') then
      lLocalScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lLocalScopeId);
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'unit') then
      lUnitNodeId := lDeclaration.SymbolId
    else if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'routine') and
      SameText(lDeclaration.OwnerScopeId, lLocalScopeId) then
      lLocalNodeId := lDeclaration.SymbolId;
  Assert.IsNotEmpty(lUnitNodeId);
  Assert.IsNotEmpty(lLocalNodeId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeenUnit := False;
  lSeenLocal := False;
  for lBinding in lFacts.Bindings do
  begin
    if SameText(lBinding.RoutineName, 'UnitAliasRun') then
    begin
      Assert.IsFalse(lSeenUnit);
      lSeenUnit := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('unit', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lUnitNodeId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'UnitOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'LocalOnly', 'member'));
    end else if SameText(lBinding.RoutineName, 'LocalAliasRun') then
    begin
      Assert.IsFalse(lSeenLocal);
      lSeenLocal := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalNodeId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.AreEqual('TNode', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'));
    end;
  end;
  Assert.IsTrue(lSeenUnit and lSeenLocal, 'Both source-backed alias bindings are required.');
end;

procedure TWithBinderTests.RoutineLocalHomonymMembersUseTheirOwnDeclaration;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOwnName: string;
  lOtherName: string;
  lRoot: string;
  lSeenFirst: Boolean;
  lSeenSecond: Boolean;
begin
  // DS-685 C7: two routines each declare a local TNode, and the unit declares a
  // third TNode. Each WITH must bind only the members of its own local type.
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-homonym-members-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'LocalHomonymMembers.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalHomonymMembers;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TNode = record UnitOnly: Integer; Shared: Integer; end;'#13#10 +
    'procedure RunFirst(aValue: Integer);'#13#10 +
    'procedure RunSecond(const aText: string);'#13#10 +
    'implementation'#13#10 +
    'procedure RunFirst(aValue: Integer);'#13#10 +
    'type'#13#10 +
    '  TNode = record FirstOnly: Integer; Shared: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lItem: TNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin'#13#10 +
    '    FirstOnly := aValue;'#13#10 +
    '    Shared := 1;'#13#10 +
    '    SecondOnly := 2;'#13#10 +
    '    UnitOnly := 3;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'procedure RunSecond(const aText: string);'#13#10 +
    'type'#13#10 +
    '  TNode = record SecondOnly: Integer; Shared: Integer; end;'#13#10 +
    'var'#13#10 +
    '  lItem: TNode;'#13#10 +
    'begin'#13#10 +
    '  with lItem do'#13#10 +
    '  begin'#13#10 +
    '    SecondOnly := Length(aText);'#13#10 +
    '    Shared := 1;'#13#10 +
    '    FirstOnly := 2;'#13#10 +
    '    UnitOnly := 3;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The local homonym fixture must extract from source.');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeenFirst := False;
  lSeenSecond := False;
  for lBinding in lFacts.Bindings do
  begin
    Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
    Assert.AreEqual('resolved', lBinding.Selectors[0].Status, lBinding.Selectors[0].ReasonCode);
    Assert.AreEqual('routine', lBinding.Selectors[0].TypeIdentity.ScopeKind);
    if SameText(lBinding.RoutineName, 'RunFirst') then
    begin
      Assert.IsFalse(lSeenFirst);
      lSeenFirst := True;
      lOwnName := 'FirstOnly';
      lOtherName := 'SecondOnly';
    end else
    begin
      Assert.IsFalse(lSeenSecond);
      lSeenSecond := True;
      lOwnName := 'SecondOnly';
      lOtherName := 'FirstOnly';
    end;
    Assert.AreEqual('TNode', ReceiverOf(lBinding, lOwnName, 'member'),
      lOwnName + ' must bind to its own routine-local TNode: ' +
      ReasonOf(lBinding, lOwnName, 'ambiguous'));
    Assert.AreEqual('TNode', ReceiverOf(lBinding, 'Shared', 'member'),
      'Shared must bind to the routine-local TNode, not be ambiguous: ' +
      ReasonOf(lBinding, 'Shared', 'ambiguous'));
    Assert.IsFalse(HasReference(lBinding, lOtherName, 'member'),
      lOtherName + ' belongs to the other routine-local TNode.');
    Assert.IsFalse(HasReference(lBinding, 'UnitOnly', 'member'),
      'UnitOnly belongs to the unit-level TNode homonym.');
  end;
  Assert.IsTrue(lSeenFirst and lSeenSecond, 'Both routine-local bindings are required.');
end;

function RoutineLocalInheritedReferenceProblem(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  // A member a routine-local class may inherit must be refused or bound to its
  // declaring ancestor; it may never bind to an outer receiver or stay lexical.
  Result := '';
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and
      (not MatchText(lReference.Classification, ['unsupported', 'ambiguous'])) and
      (not (SameText(lReference.Classification, 'member') and
      SameText(lReference.ReceiverTypeName, 'TBase'))) then
      Result := Result + ' ' + aBinding.RoutineName + ':' + aName + '=' +
        lReference.Classification + '/' + lReference.ReceiverTypeName + '/' +
        lReference.ReasonCode;
end;

procedure TWithBinderTests.RoutineLocalInheritedMembersNeverBindElsewhere;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lGuid: TGUID;
  lGuidText: string;
  lInspected: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProblems: string;
  lRoot: string;
begin
  // DS-685 C7 review: an owner-identity lookup is direct only, so a direct miss
  // on a routine-local class must not be read as "not a member".
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  lRoot := WithBinderTempPath('local-inherited-members-' + lGuidText);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'LocalInheritedMembers.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit LocalInheritedMembers;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TBase = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '  end;'#13#10 +
    '  TOuter = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '  end;'#13#10 +
    '  TOwner = class'#13#10 +
    '  public'#13#10 +
    '    Caption: string;'#13#10 +
    '    procedure Ping;'#13#10 +
    '    procedure RunWithoutOuter;'#13#10 +
    '  end;'#13#10 +
    'procedure RunWithOuter(lOuter: TOuter);'#13#10 +
    'procedure RunWithAlias(lOuter: TOuter);'#13#10 +
    'implementation'#13#10 +
    'procedure TBase.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure TOuter.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure TOwner.Ping;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'procedure RunWithOuter(lOuter: TOuter);'#13#10 +
    'type'#13#10 +
    '  TLocal = class(TBase)'#13#10 +
    '    Extra: Integer;'#13#10 +
    '  end;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do'#13#10 +
    '    with lLocal do'#13#10 +
    '    begin'#13#10 +
    '      Extra := 1;'#13#10 +
    '      Caption := '''';'#13#10 +
    '      Ping;'#13#10 +
    '      Free;'#13#10 +
    '    end;'#13#10 +
    'end;'#13#10 +
    'procedure RunWithAlias(lOuter: TOuter);'#13#10 +
    'type'#13#10 +
    '  TLocal = TBase;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lOuter do'#13#10 +
    '    with lLocal do'#13#10 +
    '    begin'#13#10 +
    '      Caption := '''';'#13#10 +
    '      Ping;'#13#10 +
    '    end;'#13#10 +
    'end;'#13#10 +
    'procedure TOwner.RunWithoutOuter;'#13#10 +
    'type'#13#10 +
    '  TLocal = class(TBase)'#13#10 +
    '    Extra: Integer;'#13#10 +
    '  end;'#13#10 +
    'var'#13#10 +
    '  lLocal: TLocal;'#13#10 +
    'begin'#13#10 +
    '  with lLocal do'#13#10 +
    '  begin'#13#10 +
    '    Extra := 1;'#13#10 +
    '    Caption := '''';'#13#10 +
    '    Ping;'#13#10 +
    '    Free;'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The local inherited member fixture must extract from source.');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lProblems := '';
  lInspected := 0;
  for lBinding in lFacts.Bindings do
  begin
    // Every binding is inspected, including the outer WITH on lOuter.
    if (Length(lBinding.Selectors) > 0) and
      SameText(lBinding.Selectors[High(lBinding.Selectors)].SelectorText, 'lLocal') then
      Inc(lInspected);
    lProblems := lProblems + RoutineLocalInheritedReferenceProblem(lBinding, 'Caption') +
      RoutineLocalInheritedReferenceProblem(lBinding, 'Ping') +
      RoutineLocalInheritedReferenceProblem(lBinding, 'Free');
  end;
  Assert.AreEqual(3, lInspected, 'All three WITH statements on lLocal must be bound.');
  Assert.AreEqual('', lProblems,
    'Inherited members of a routine-local class must be refused or bound to TBase.');
end;

procedure TWithBinderTests.SelectorIdentityUsesTheDeclaringUnitScope;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalScopeId: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lPairScopeId: string;
  lProjectPath: string;
  lRoot: string;
  lRoutine: TDelphiSemanticRoutine;
  lSeen: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  c: Char;

  procedure AssertUnitIdentity(const aCase, aUnitName, aTypeName: string);
  begin
    Assert.AreEqual('resolved', lSelector.Status, aCase + ': ' + lSelector.ReasonCode);
    Assert.AreEqual(aTypeName, lSelector.TypeIdentity.Name, aCase);
    Assert.AreEqual(aUnitName, lSelector.TypeIdentity.UnitName, aCase);
    Assert.AreEqual('unit', lSelector.TypeIdentity.ScopeKind, aCase);
    Assert.IsNotEmpty(lSelector.TypeIdentity.SemanticSymbolId, aCase);
  end;

begin
  lRoot := WithBinderTempPath('declaring-unit-scope-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'DeclaringScope.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'DeclaringScope.dpr'),
    'program DeclaringScope;'#13#10 +
    'uses MaskConsumer in ''MaskConsumer.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>DeclaringScope.dpr</MainSource></PropertyGroup>' +
    '<ItemGroup><DCCReference Include="MaskProvider.pas"/>' +
    '<DCCReference Include="TableDecl.pas"/>' +
    '<DCCReference Include="MaskConsumer.pas"/></ItemGroup></Project>',
    TEncoding.ASCII);
  // The final record type lives in MaskProvider; the field and parameter that reach it
  // are declared in TableDecl (like maxTdb DatFile.Maske and MaskType).
  TFile.WriteAllText(TPath.Combine(lRoot, 'MaskProvider.pas'),
    'unit MaskProvider;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TMaskEntry = record Width: Integer; end;'#13#10 +
    '  PMaskEntry = ^TMaskEntry;'#13#10 +
    '  TMaskArray = array[1..4] of PMaskEntry;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'TableDecl.pas'),
    'unit TableDecl;'#13#10 +
    'interface'#13#10 +
    'uses MaskProvider;'#13#10 +
    'type'#13#10 +
    '  TTable = record Mask: TMaskArray; end;'#13#10 +
    '  PTable = ^TTable;'#13#10 +
    'var'#13#10 +
    '  Tables: array[1..2] of PTable;'#13#10 +
    'procedure CopyMask(const aMask: TMaskArray);'#13#10 +
    'implementation'#13#10 +
    'procedure CopyMask(const aMask: TMaskArray);'#13#10 +
    'begin'#13#10 +
    '  with aMask[1]^ do Width := 1;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'MaskConsumer.pas'),
    'unit MaskConsumer;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TCell = record Value: Integer; end;'#13#10 +
    '  TCellArray = array[1..4] of TCell;'#13#10 +
    '  PCellArray = ^TCellArray;'#13#10 +
    'procedure UseCells(aCells: PCellArray);'#13#10 +
    'procedure UseField;'#13#10 +
    'procedure UseNested;'#13#10 +
    'procedure UseLocal;'#13#10 +
    'procedure UseInline;'#13#10 +
    'procedure UsePair(aValue: Integer;aOther : Integer );'#13#10 +
    'implementation'#13#10 +
    'uses MaskProvider, TableDecl;'#13#10 +
    'procedure UseCells(aCells: PCellArray);'#13#10 +
    'begin'#13#10 +
    '  with aCells^[1] do Value := 1;'#13#10 +
    'end;'#13#10 +
    'procedure UseField;'#13#10 +
    'begin'#13#10 +
    '  with Tables[1]^.Mask[2]^ do Width := 2;'#13#10 +
    'end;'#13#10 +
    'procedure UseNested;'#13#10 +
    'begin'#13#10 +
    '  with Tables[1]^ do'#13#10 +
    '    with Mask[2]^ do Width := 3;'#13#10 +
    'end;'#13#10 +
    'procedure UseLocal;'#13#10 +
    'type TMaskEntry = record LocalOnly: Integer; end;'#13#10 +
    'var lEntry: TMaskEntry;'#13#10 +
    'begin'#13#10 +
    '  with lEntry do LocalOnly := 4;'#13#10 +
    'end;'#13#10 +
    'procedure UseInline;'#13#10 +
    'var lMasks: array[1..2] of PMaskEntry;'#13#10 +
    'begin'#13#10 +
    '  with lMasks[1]^ do Width := 5;'#13#10 +
    'end;'#13#10 +
    // The body repeats the header with different line breaks and spacing only.
    'procedure UsePair(aValue: Integer;'#13#10 +
    '  aOther: Integer);'#13#10 +
    'type TPairLocal = record PairOnly: Integer; end;'#13#10 +
    'var lPair: TPairLocal;'#13#10 +
    '  procedure Inner;'#13#10 +
    '  begin'#13#10 +
    '    with lPair do PairOnly := 6;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    '  Inner;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lLocalScopeId := '';
  lPairScopeId := '';
  for lModel in lFacts.UnitModels do
    if SameText(lModel.UnitName, 'MaskConsumer') then
    begin
      Assert.AreEqual('ast', lModel.ScopeModelStatus);
      for lRoutine in lModel.Routines do
        if SameText(lRoutine.SectionKind, 'implementation') and
          SameText(lRoutine.Name, 'UseLocal') then
          lLocalScopeId := lRoutine.ScopeId
        else if SameText(lRoutine.SectionKind, 'implementation') and
          SameText(lRoutine.Name, 'UsePair') then
          lPairScopeId := lRoutine.ScopeId;
    end;
  Assert.IsNotEmpty(lLocalScopeId);
  Assert.IsNotEmpty(lPairScopeId);
  lSeen := '';
  for lBinding in lFacts.Bindings do
  begin
    if Length(lBinding.Selectors) = 0 then
      Continue;
    lSelector := lBinding.Selectors[High(lBinding.Selectors)];
    if SameText(lBinding.RoutineName, 'CopyMask') then
    begin
      // Parameter declared in TableDecl; its final type comes from MaskProvider.
      AssertUnitIdentity('parameter', 'MaskProvider', 'TMaskEntry');
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Width', 'member'));
      lSeen := lSeen + 'P';
    end else if SameText(lBinding.RoutineName, 'UseCells') then
    begin
      // Same-unit parameter reached through its interface header coordinates.
      AssertUnitIdentity('same-unit parameter', 'MaskConsumer', 'TCell');
      lSeen := lSeen + 'C';
    end else if SameText(lBinding.RoutineName, 'UseField') then
    begin
      AssertUnitIdentity('field', 'MaskProvider', 'TMaskEntry');
      lSeen := lSeen + 'F';
    end else if SameText(lBinding.RoutineName, 'UseNested') and
      SameText(lSelector.SelectorText, 'Mask[2]^') then
    begin
      AssertUnitIdentity('bound field', 'MaskProvider', 'TMaskEntry');
      lSeen := lSeen + 'N';
    end else if SameText(lBinding.RoutineName, 'UseLocal') then
    begin
      // Negative control: the routine-local homonym keeps its routine identity.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lLocalScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'LocalOnly', 'member'));
      lSeen := lSeen + 'L';
    end else if SameText(lBinding.RoutineName, 'UseInline') then
    begin
      // Negative control: an inline local type cannot prove the scope of an imported
      // final type, so the identity stays unproven (blank), which member safety refuses.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TMaskEntry', lSelector.TypeName);
      Assert.IsEmpty(lSelector.TypeIdentity.Name, 'An unproven origin must stay blank.');
      Assert.IsEmpty(lSelector.TypeIdentity.UnitName, 'An unproven origin must stay blank.');
      lSeen := lSeen + 'I';
    end else if SameText(lBinding.RoutineName, 'Inner') then
    begin
      // Header and body differ only by whitespace, so the parent scope stays valid.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TPairLocal', lSelector.TypeIdentity.Name);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lPairScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TPairLocal', ReceiverOf(lBinding, 'PairOnly', 'member'));
      lSeen := lSeen + 'W';
    end;
  end;
  // Binding order follows the units, so compare the set of cases.
  Assert.AreEqual(7, Length(lSeen), 'Every source-backed WITH must be bound once: ' + lSeen);
  for c in 'PCFNLIW' do
    Assert.IsTrue(Pos(c, lSeen) > 0, 'Missing case ' + c + ' in ' + lSeen);
end;

procedure TWithBinderTests.ParameterTypesResolveInTheEnclosingScope;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOuterScopeId: string;
  lRoot: string;
  lRoutine: TDelphiSemanticRoutine;
  lSeen: string;
  lSelector: TDelphiSemanticWithSelectorBinding;
  c: Char;

  // Delphi resolves parameter types in the scope that encloses the routine heading, so
  // a routine's own local homonym never names its parameter's type (verified with a
  // dcc64 probe: Count binds to the parameter's unit-level record field).
  procedure AssertUnitParameterType(const aCase, aTypeName: string);
  begin
    Assert.AreNotEqual('routine', lSelector.TypeIdentity.ScopeKind,
      aCase + ': a routine-local homonym must never type a parameter.');
    if SameText(lSelector.Status, 'resolved') and (lSelector.TypeIdentity.Name <> '') then
    begin
      Assert.AreEqual(aTypeName, lSelector.TypeIdentity.Name, aCase);
      Assert.AreEqual('unit', lSelector.TypeIdentity.ScopeKind, aCase);
    end;
    Assert.IsFalse(HasReference(lBinding, 'Count', 'lexical'),
      aCase + ': Count must not bind to the global variable.');
    Assert.IsFalse(HasReference(lBinding, 'Other', 'member'), aCase);
  end;

begin
  lRoot := WithBinderTempPath('parameter-scope-' + TPath.GetGUIDFileName);
  TDirectory.CreateDirectory(lRoot);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'ParameterScope.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit ParameterScope;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TFoo = record Count: Integer; end;'#13#10 +
    '  TFooArr = array[0..1] of TFoo;'#13#10 +
    'var'#13#10 +
    '  Count: Integer;'#13#10 +
    'procedure OpenRun(const aItems: array of TFoo);'#13#10 +
    'procedure ArrayRun(var aArr: TFooArr);'#13#10 +
    'procedure PlainRun(var aOne: TFoo);'#13#10 +
    'procedure OuterRun;'#13#10 +
    'implementation'#13#10 +
    'procedure OpenRun(const aItems: array of TFoo);'#13#10 +
    'type TFoo = record Other: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aItems[0] do Count := 1;'#13#10 +
    'end;'#13#10 +
    'procedure ArrayRun(var aArr: TFooArr);'#13#10 +
    'type'#13#10 +
    '  TFoo = record Other: Integer; end;'#13#10 +
    '  TFooArr = array[0..1] of TFoo;'#13#10 +
    'begin'#13#10 +
    '  with aArr[1] do Count := 2;'#13#10 +
    'end;'#13#10 +
    'procedure PlainRun(var aOne: TFoo);'#13#10 +
    'type TFoo = record Other: Integer; end;'#13#10 +
    'begin'#13#10 +
    '  with aOne do Count := 3;'#13#10 +
    'end;'#13#10 +
    'procedure OuterRun;'#13#10 +
    'type TOuterRec = record Inner: Integer; end;'#13#10 +
    '  procedure NestedRun(var aRec: TOuterRec);'#13#10 +
    '  begin'#13#10 +
    '    with aRec do Inner := 4;'#13#10 +
    '  end;'#13#10 +
    'begin'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, 'The parameter scope fixture must extract from source.');
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lOuterScopeId := '';
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'OuterRun') and SameText(lRoutine.SectionKind, 'implementation') then
      lOuterScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lOuterScopeId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeen := '';
  for lBinding in lFacts.Bindings do
  begin
    if Length(lBinding.Selectors) <> 1 then
      Continue;
    lSelector := lBinding.Selectors[0];
    if SameText(lBinding.RoutineName, 'OpenRun') then
    begin
      AssertUnitParameterType('open array', 'TFoo');
      lSeen := lSeen + 'O';
    end else if SameText(lBinding.RoutineName, 'ArrayRun') then
    begin
      AssertUnitParameterType('identifier array', 'TFoo');
      lSeen := lSeen + 'A';
    end else if SameText(lBinding.RoutineName, 'PlainRun') then
    begin
      AssertUnitParameterType('plain parameter', 'TFoo');
      lSeen := lSeen + 'P';
    end else if SameText(lBinding.RoutineName, 'NestedRun') then
    begin
      // Positive control: a nested heading sees its parent's local types.
      Assert.AreEqual('resolved', lSelector.Status, lSelector.ReasonCode);
      Assert.AreEqual('TOuterRec', lSelector.TypeIdentity.Name);
      Assert.AreEqual('routine', lSelector.TypeIdentity.ScopeKind);
      Assert.AreEqual(lOuterScopeId, lSelector.TypeIdentity.OwnerScopeId);
      Assert.AreEqual('TOuterRec', ReceiverOf(lBinding, 'Inner', 'member'));
      lSeen := lSeen + 'N';
    end;
  end;
  Assert.AreEqual(4, Length(lSeen), 'Every source-backed WITH must be bound once: ' + lSeen);
  for c in 'OAPN' do
    Assert.IsTrue(Pos(c, lSeen) > 0, 'Missing case ' + c + ' in ' + lSeen);
end;

procedure TWithBinderTests.MalformedPointerAliasOwnersAndAmbiguousPointeesAreRefused;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSeen: Boolean;
  lUnitNode: TDelphiSemanticDeclaration;
  lUnitNodeCount: Integer;
begin
  lModel := BuildPointerAliasScopeModel;
  lUnitNode := Default(TDelphiSemanticDeclaration);
  lUnitNodeCount := 0;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TNode') and
      SameText(lDeclaration.ScopeKind, 'unit') then
    begin
      Inc(lUnitNodeCount);
      lUnitNode := lDeclaration;
    end;
  Assert.AreEqual(1, lUnitNodeCount, 'The unmutated source has one unit pointee.');
  Assert.IsNotEmpty(lUnitNode.SymbolId);
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
  lSeen := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.RoutineName, 'UnitAliasRun') then
    begin
      Assert.IsFalse(lSeen, 'The unmutated unit alias has one binding.');
      lSeen := True;
      Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual(lModel.UnitName, lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('unit', lBinding.Selectors[0].TypeIdentity.ScopeKind);
      Assert.AreEqual(LowerCase(lModel.UnitName),
        lBinding.Selectors[0].TypeIdentity.OwnerScopeId);
      Assert.AreEqual(lUnitNode.SymbolId,
        lBinding.Selectors[0].TypeIdentity.SemanticSymbolId);
      Assert.IsNotEmpty(lBinding.Selectors[0].TypeIdentity.DeclaredId.Value);
      Assert.AreEqual(lModel.FileName,
        lBinding.Selectors[0].TypeIdentity.SourceRange.FileName);
      Assert.AreEqual(lUnitNode.Line,
        lBinding.Selectors[0].TypeIdentity.SourceRange.Line);
      Assert.AreEqual(lUnitNode.Column,
        lBinding.Selectors[0].TypeIdentity.SourceRange.Column);
    end;
  Assert.IsTrue(lSeen, 'The unmutated source-backed unit alias must resolve.');
  for i := 0 to 2 do
  begin
    lModels := [lModel];
    lModels[0].Declarations := Copy(lModel.Declarations);
    for j := 0 to High(lModels[0].Declarations) do
      if SameText(lModels[0].Declarations[j].Name, 'PUnitNode') then
      begin
        if i = 0 then
          lModels[0].Declarations[j].OwnerScopeId := 'wrong-unit'
        else if i = 1 then
          lModels[0].Declarations[j].ScopeKind := 'unknown';
        Break;
      end;
    if i = 2 then
    begin
      for lDeclaration in lModel.Declarations do
        if SameText(lDeclaration.Name, 'TNode') and
          SameText(lDeclaration.ScopeKind, 'unit') then
        begin
          j := Length(lModels[0].Declarations);
          SetLength(lModels[0].Declarations, j + 1);
          lModels[0].Declarations[j] := lDeclaration;
          lModels[0].Declarations[j].SymbolId := lDeclaration.SymbolId + ':duplicate';
          lModels[0].Declarations[j].Line := lDeclaration.Line + 1;
          Break;
        end;
    end;
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lSeen := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.RoutineName, 'UnitAliasRun') then
      begin
        Assert.IsFalse(lSeen, 'The mutated unit alias has one binding.');
        lSeen := True;
        Assert.AreEqual(1, Integer(Length(lBinding.Selectors)));
        Assert.AreEqual('unresolved', lBinding.Selectors[0].Status);
        Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED',
          lBinding.Selectors[0].ReasonCode,
          'Malformed alias owner or ambiguous pointee must fail closed.');
      end;
    Assert.IsTrue(lSeen, 'The source-backed unit alias binding must be retained.');
  end;
end;


function TWithBinderTests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'WithBinderUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function TWithBinderTests.LoadBareReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lUnitName: string;
begin
  SetLength(Result, 3);
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
    Result[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(Result[i].Success, lUnitName + ' source model');
  end;
end;

function TWithBinderTests.LoadReceiverSafetyModels: TArray<TDelphiSemanticUnitModel>;
var
  i: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lUnitName: string;
begin
  SetLength(Result, 4);
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
    Result[i] := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(Result[i].Success, lUnitName + ' source model');
  end;
end;

function TWithBinderTests.HasReference(const aBinding: TDelphiSemanticWithBinding;
  const aName, aClassification: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.HasAnyReference(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.ReceiverOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.ReceiverTypeName);

  Result := '';
end;

function TWithBinderTests.CountReferences(const aBinding: TDelphiSemanticWithBinding;
  const aName: string): Integer;
var
  lReference: TDelphiSemanticBoundReference;
begin
  Result := 0;
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) then
      Inc(Result);
end;

function TWithBinderTests.LookupSourceOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.LookupSource);

  Result := '';
end;

function TWithBinderTests.ReasonOf(const aBinding: TDelphiSemanticWithBinding; const aName,
  aClassification: string): string;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification, aClassification) then
      Exit(lReference.ReasonCode);

  Result := '';
end;

function TWithBinderTests.HasInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
  const aName, aSymbolClass, aRoutineName: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aInventory.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.RoutineName, aRoutineName) then
      Exit(True);

  Result := False;
end;

function TWithBinderTests.TryFindInventorySymbol(const aInventory: TDelphiSemanticRemoveWithInventory;
  const aName, aSymbolClass, aOwnerName: string; out aSymbol:
  TDelphiSemanticInventorySymbol): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aInventory.Symbols do
  begin
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.OwnerName, aOwnerName) then
    begin
      aSymbol := lSymbol;
      Exit(True);
    end;
  end;

  aSymbol := Default(TDelphiSemanticInventorySymbol);
  Result := False;
end;

procedure TWithBinderTests.ResolvesSelectorTypesAndClassifiesBodyIdentifiers;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(10, Integer(Length(lBindings)));
  Assert.AreEqual(1, Integer(Length(lBindings[0].Selectors)));
  Assert.AreEqual('lFirst', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lBindings[0].Selectors[0].Status);
  Assert.AreEqual('TFirstRecord', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'aParamValue', 'lexical'));
  Assert.IsTrue(HasReference(lBindings[0], 'lLocalValue', 'lexical'));
  Assert.IsTrue(HasReference(lBindings[0], 'lSecond.SecondOnly', 'unsupported'));
  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly[0]', 'unsupported'));
  Assert.IsTrue(HasReference(lBindings[0], 'MissingValue', 'unresolved'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'PhantomMember'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'BracePhantom'));
  Assert.IsFalse(HasAnyReference(lBindings[0], 'ParenPhantom'));
end;

procedure TWithBinderTests.BindingsExposeSourceRangesForDakPlanner;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[0];

  Assert.AreEqual(lModel.WithStatements[0].Line, lBinding.Line);
  Assert.AreEqual(lModel.WithStatements[0].Column, lBinding.Column);
  Assert.AreEqual(lModel.WithStatements[0].EndLine, lBinding.EndLine);
  Assert.AreEqual(lModel.WithStatements[0].EndColumn, lBinding.EndColumn);
  Assert.AreEqual(lModel.WithStatements[0].BodyLine, lBinding.BodyLine);
  Assert.AreEqual(lModel.WithStatements[0].BodyColumn, lBinding.BodyColumn);
  Assert.AreEqual(lModel.WithStatements[0].BodyEndLine, lBinding.BodyEndLine);
  Assert.AreEqual(lModel.WithStatements[0].BodyEndColumn, lBinding.BodyEndColumn);
  Assert.AreEqual(lModel.WithStatements[0].SelectorText, lBinding.SelectorText);
end;

procedure TWithBinderTests.MultipleSelectorsPreferInnermostReceiver;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(2, Integer(Length(lBindings[1].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[1].Selectors[0].TypeName);
  Assert.AreEqual('TSecondRecord', lBindings[1].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lBindings[1], 'Shared', 'member'));
  Assert.AreEqual('TSecondRecord', ReceiverOf(lBindings[1], 'Shared', 'member'));
  Assert.IsTrue(HasReference(lBindings[1], 'SecondOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[1], 'FirstOnly', 'member'));
end;

procedure TWithBinderTests.AmbiguousReceiverMembersClassifyAsAmbiguous;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lLength: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;
  lLength := Length(lModel.Members);
  SetLength(lModel.Members, lLength + 1);
  lMember := lModel.Members[0];
  lMember.OwnerName := 'TFirstRecord';
  lMember.Name := 'FirstOnly';
  lModel.Members[lLength] := lMember;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.IsTrue(HasReference(lBindings[0], 'FirstOnly', 'ambiguous'));
end;

procedure TWithBinderTests.ClassMethodWithBindingUsesOwnedRoutineTypeForInheritedProtectedMembers;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lExpandedCount: Integer;
  lOwnerCount: Integer;
  lPath: string;
  lSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lPath := WithBinderTempPath('withbinder-current-type-regression.pas');
  lSource :=
    'unit WithBinderCurrentTypeRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TBase = class' + sLineBreak +
    '  protected' + sLineBreak +
    '    BaseValue: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TChild = class(TBase)' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'class procedure TChild.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lChild: TChild;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lChild do' + sLineBreak +
    '    BaseValue := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    lBinding := lBindings[0];
    Assert.AreEqual('TChild.Run', lBinding.RoutineName);
    Assert.IsTrue(HasReference(lBinding, 'BaseValue', 'member'),
      'Inherited protected receiver members need the owned routine type as access context.');
    Assert.AreEqual('TBase', ReceiverOf(lBinding, 'BaseValue', 'member'));
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, [lModel]);
    lExpandedCount := 0;
    lOwnerCount := 0;
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, 'BaseValue') then
      begin
        if SameText(lSymbol.SymbolClass, 'member') and
          SameText(lSymbol.OwnerName, 'TBase') then
          Inc(lOwnerCount)
        else if SameText(lSymbol.SymbolClass, 'field') and
          SameText(lSymbol.OwnerName, 'TChild') then
        begin
          Inc(lExpandedCount);
          Assert.AreEqual('TBase', lSymbol.SourceOwnerType);
          Assert.AreEqual('WithBinderCurrentTypeRegression',
            lSymbol.AccessOwnerIdentity.UnitName);
          Assert.AreEqual('TChild', lSymbol.AccessOwnerIdentity.Name);
          Assert.IsTrue(lSymbol.AccessOwnerIdentity.DeclaredId.Value <> '');
          Assert.AreEqual(lPath, lSymbol.AccessOwnerIdentity.SourceRange.FileName);
        end
        else
          Continue;
        Assert.AreEqual('WithBinderCurrentTypeRegression',
          lSymbol.OwnerIdentity.UnitName);
        Assert.AreEqual('TBase', lSymbol.OwnerIdentity.Name);
        Assert.IsTrue(lSymbol.OwnerIdentity.DeclaredId.Value <> '');
        Assert.AreEqual(lPath, lSymbol.OwnerIdentity.SourceRange.FileName);
      end;
    Assert.AreEqual(1, lOwnerCount,
      'Inherited BaseValue must retain its actual declaring TBase owner.');
    Assert.AreEqual(1, lExpandedCount,
      'The derived projection must retain the inherited declaration identity.');
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.InheritedHomonymProjectionsKeepTheirAccessDeclaration;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFirstCount: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lFirstBindingCount: Integer;
  lNearestBindingCount: Integer;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lRoot: string;
  lSecondCount: Integer;
  lSecondBindingCount: Integer;
  lUnknownBindingCount: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lRoot := WithBinderTempPath('inherited-homonym');
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'P.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P;'#13#10'uses AUnit in ''AUnit.pas'', BUnit in ''BUnit.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="BaseUnit.pas"/><DCCReference Include="MidUnit.pas"/>' +
    '<DCCReference Include="AUnit.pas"/><DCCReference Include="BUnit.pas"/>' +
    '</ItemGroup></Project>', TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'BaseUnit.pas'),
    'unit BaseUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TLeaf = record'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    '  TBase = class'#13#10'  public'#13#10'    Child: TLeaf;'#13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'MidUnit.pas'),
    'unit MidUnit;'#13#10'interface'#13#10'uses BaseUnit;'#13#10'type'#13#10 +
    '  TIntermediate = class(TBase) end;'#13#10 +
    'implementation'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'AUnit.pas'),
    'unit AUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    '  TWrongLeaf = record OtherValue: Integer; end;'#13#10 +
    '  TGlobalLeaf = record GlobalValue: Integer; end;'#13#10 +
    '  TNearest = record Child: TWrongLeaf; end;'#13#10 +
    'var'#13#10'  Child: TGlobalLeaf;'#13#10 +
    'procedure RunA;'#13#10'procedure RunNearest;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'implementation'#13#10 +
    'procedure RunA;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 1; end;'#13#10 +
    'procedure RunNearest;'#13#10 +
    'var'#13#10'  lDerived: TDerived;'#13#10 +
    '  lNearest: TNearest;'#13#10 +
    'begin with lDerived do with lNearest do with Child do OtherValue := 1; end;'#13#10 +
    'procedure RunUnknown;'#13#10 +
    'begin with Missing do with Child do Value := 1; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'BUnit.pas'),
    'unit BUnit;'#13#10'interface'#13#10'uses MidUnit;'#13#10'type'#13#10 +
    '  TDerived = class(TIntermediate) end;'#13#10 +
    'procedure RunB;'#13#10'implementation'#13#10 +
    'procedure RunB;'#13#10'var'#13#10'  lDerived: TDerived;'#13#10 +
    'begin with lDerived do with Child do Value := 2; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lFirstCount := 0;
  lSecondCount := 0;
  lFirstBindingCount := 0;
  lNearestBindingCount := 0;
  lSecondBindingCount := 0;
  lUnknownBindingCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.SelectorText, 'Child') and
      SameText(lBinding.UnitName, 'AUnit') and
      SameText(lBinding.RoutineName, 'RunA') then
    begin
      Inc(lFirstBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        'RunA parent: ' + lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'RunA child: ' + lBinding.Selectors[1].ReasonCode);
      Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
    end else if SameText(lBinding.SelectorText, 'Child') and
      SameText(lBinding.UnitName, 'BUnit') and
      SameText(lBinding.RoutineName, 'RunB') then
    begin
      Inc(lSecondBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[0].Status,
        'RunB parent: ' + lBinding.Selectors[0].ReasonCode);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'RunB child: ' + lBinding.Selectors[1].ReasonCode);
      Assert.AreEqual('BaseUnit', lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('TLeaf', lBinding.Selectors[1].TypeIdentity.Name);
    end else if SameText(lBinding.SelectorText, 'Child') and
      SameText(lBinding.UnitName, 'AUnit') and
      SameText(lBinding.RoutineName, 'RunNearest') then
    begin
      Inc(lNearestBindingCount);
      Assert.AreEqual(3, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('resolved', lBinding.Selectors[2].Status);
      Assert.AreEqual('TWrongLeaf', lBinding.Selectors[2].TypeName);
      Assert.AreEqual('AUnit', lBinding.Selectors[2].TypeIdentity.UnitName);
      Assert.AreEqual('TWrongLeaf', lBinding.Selectors[2].TypeIdentity.Name);
    end else if SameText(lBinding.SelectorText, 'Child') and
      SameText(lBinding.UnitName, 'AUnit') and
      SameText(lBinding.RoutineName, 'RunUnknown') then
    begin
      Inc(lUnknownBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreNotEqual('resolved', lBinding.Selectors[0].Status);
      Assert.AreNotEqual('resolved', lBinding.Selectors[1].Status,
        'An unknown parent must not turn the global Child namesake into a receiver.');
    end;
  Assert.AreEqual(1, lFirstBindingCount);
  Assert.AreEqual(1, lSecondBindingCount);
  Assert.AreEqual(1, lNearestBindingCount);
  Assert.AreEqual(1, lUnknownBindingCount);
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.Name, 'Child') and
      SameText(lSymbol.SymbolClass, 'field') and
      SameText(lSymbol.OwnerName, 'TDerived') then
    begin
      Assert.AreEqual('BaseUnit', lSymbol.OwnerIdentity.UnitName);
      Assert.AreEqual('TBase', lSymbol.OwnerIdentity.Name);
      Assert.AreEqual(TPath.Combine(lRoot, 'BaseUnit.pas'),
        lSymbol.OwnerIdentity.SourceRange.FileName);
      if SameText(lSymbol.AccessOwnerIdentity.UnitName, 'AUnit') then
      begin
        Inc(lFirstCount);
        Assert.AreEqual(TPath.Combine(lRoot, 'AUnit.pas'),
          lSymbol.AccessOwnerIdentity.SourceRange.FileName);
      end else if SameText(lSymbol.AccessOwnerIdentity.UnitName, 'BUnit') then
      begin
        Inc(lSecondCount);
        Assert.AreEqual(TPath.Combine(lRoot, 'BUnit.pas'),
          lSymbol.AccessOwnerIdentity.SourceRange.FileName);
      end else
        Assert.Fail('Inherited projection has no proven access declaration.');
      Assert.AreEqual('TDerived', lSymbol.AccessOwnerIdentity.Name);
      Assert.IsTrue(lSymbol.AccessOwnerIdentity.DeclaredId.Value <> '');
    end;
  Assert.AreEqual(1, lFirstCount);
  Assert.AreEqual(1, lSecondCount);
end;

procedure TWithBinderTests.OneLineTypeDeclarationsDoNotOpenMemberBodies;
const
  cFakeOwners: array[0..8] of string = ('TShortDerived', 'TEmptyDerived', 'TEmpty',
    'TEmptyRec', 'TMeta', 'IForward', 'IEmpty', 'TOddVis', 'TLocalDerived');
  cOneLineTypes: array[0..9] of string = ('TShortDerived', 'TEmptyDerived', 'TEmpty',
    'TEmptyRec', 'TMeta', 'IEmpty', 'TWrongLeaf', 'TNearest', 'TOddVis', 'TAfterOdd');
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lGlobalCount: Integer;
  lLines: TArray<string>;
  lMultiCount: Integer;
  lOptions: TDelphiSemanticApiOptions;
  lProjectPath: string;
  lRoot: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lTypeName: string;

  procedure AssertMember(const aName, aOwnerName, aTypeName: string; const aLine: Integer;
    const aExpectedCount: Integer = 1);
  var
    lCount: Integer;
    lMember: TDelphiSemanticInventorySymbol;
  begin
    lCount := 0;
    for lMember in lFacts.Symbols do
      if SameText(lMember.Name, aName) and SameText(lMember.SymbolClass, 'field') and
        SameText(lMember.OwnerName, aOwnerName) then
      begin
        Inc(lCount);
        Assert.AreEqual(aTypeName, lMember.TypeName, aOwnerName + '.' + aName + ' type');
        Assert.AreEqual(aLine, lMember.Line, aOwnerName + '.' + aName + ' line');
        Assert.AreEqual(Pos(aName, lLines[aLine - 1]), lMember.Column,
          aOwnerName + '.' + aName + ' column');
      end;
    Assert.AreEqual(aExpectedCount, lCount, 'Field count of ' + aOwnerName + '.' + aName);
  end;

  function CountFields(const aName, aOwnerName: string): Integer;
  var
    lMember: TDelphiSemanticInventorySymbol;
  begin
    Result := 0;
    for lMember in lFacts.Symbols do
      if SameText(lMember.Name, aName) and SameText(lMember.SymbolClass, 'field') and
        SameText(lMember.OwnerName, aOwnerName) then
        Inc(Result);
  end;

begin
  lRoot := WithBinderTempPath('one-line-types');
  TDirectory.CreateDirectory(lRoot);
  lProjectPath := TPath.Combine(lRoot, 'P.dproj');
  TFile.WriteAllText(TPath.Combine(lRoot, 'P.dpr'),
    'program P;'#13#10'uses OneLineUnit in ''OneLineUnit.pas'';'#13#10 +
    'begin'#13#10'end.'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(lProjectPath,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>P.dpr</MainSource></PropertyGroup><ItemGroup>' +
    '<DCCReference Include="OneLineUnit.pas"/></ItemGroup></Project>', TEncoding.ASCII);
  // Every one-line form is followed by declarations that a still-open body would claim,
  // including a unit global that shares the inherited field name Child.
  lLines := [
    'unit OneLineUnit;',
    'interface',
    'type',
    '  TBase = class',
    '  public',
    '    Child: Integer;',
    '  end;',
    '  TForward = class;',
    '  TShortDerived = class(TBase);',
    '  TEmptyDerived = class(TBase) end;',
    '  TEmpty = class end;',
    '  TEmptyRec = record end;',
    '  TMeta = class of TBase;',
    '  IForward = interface;',
    '  IEmpty = interface end;',
    '  TWrongLeaf = record OtherValue: Integer; end;',
    '  TNearest = record Child: TWrongLeaf; end;',
    '  TOddVis = class(TBase) public Extra: Integer; end;',
    '  TAfterOdd = record Kept, Also: Integer; end;',
    '  TForward = class',
    '  public',
    '    Value: Integer;',
    '  end;',
    '  IForward = interface',
    '  end;',
    '  TMixed = record First: Integer;',
    '    Second: Integer;',
    '  end;',
    '  TMixedOdd = class(TBase) public Extra2: Integer;',
    '  end;',
    '  THintClass = class end deprecated;',
    '  THintRec = record HintValue: Integer; end platform;',
    '  THintMsg = class(TBase) end deprecated ''Use TBase'';',
    '  THintMulti = class end platform experimental;',
    '  TAfterHints = class',
    '  public',
    '    AfterValue: Integer;',
    '  end;',
    'var',
    '  Child: Integer;',
    'procedure RunLocal;',
    'implementation',
    'procedure RunLocal;',
    'type',
    '  TLocalDerived = class(TBase) end;',
    '  TLocalRec = record LocalValue: Integer; end;',
    '  TLocalMulti = record',
    '    MultiValue: Integer;',
    '  end;',
    'var',
    '  lRec: TLocalRec;',
    'begin',
    '  lRec.LocalValue := Child;',
    'end;',
    'end.'];
  TFile.WriteAllText(TPath.Combine(lRoot, 'OneLineUnit.pas'),
    string.Join(#13#10, lLines) + #13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := lProjectPath;
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);

  lGlobalCount := 0;
  for lSymbol in lFacts.Symbols do
  begin
    if not SameText(lSymbol.UnitName, 'OneLineUnit') then
      Continue;
    if MatchText(lSymbol.SymbolClass, ['field', 'property', 'method', 'constant',
      'class-var']) then
    begin
      Assert.IsTrue((Pos('=', lSymbol.Name) = 0) and (Pos(' ', Trim(lSymbol.Name)) = 0),
        'A declaration line became member "' + lSymbol.Name + '" of ' + lSymbol.OwnerName);
      // Derived one-liners may only carry the inherited projection of TBase.Child, which
      // keeps the source line of the TBase declaration.
      if MatchText(lSymbol.OwnerName, cFakeOwners) then
        Assert.IsTrue(SameText(lSymbol.Name, 'Child') and (lSymbol.Line = 6),
          'Fake member ' + lSymbol.OwnerName + '.' + lSymbol.Name + ' at line ' +
          IntToStr(lSymbol.Line));
    end;
    if SameText(lSymbol.Name, 'Child') and (lSymbol.OwnerName = '') and
      SameText(lSymbol.SymbolClass, 'unit-global') then
    begin
      Inc(lGlobalCount);
      Assert.AreEqual(40, lSymbol.Line, 'Global Child line');
    end;
  end;
  Assert.AreEqual(1, lGlobalCount, 'The unit global Child must stay a unit global.');

  AssertMember('OtherValue', 'TWrongLeaf', 'Integer', 16);
  AssertMember('Child', 'TNearest', 'TWrongLeaf', 17);
  AssertMember('Kept', 'TAfterOdd', 'Integer', 19);
  AssertMember('Also', 'TAfterOdd', 'Integer', 19);
  AssertMember('Value', 'TForward', 'Integer', 22);
  // A routine-local record is reported by both the model and the text scanner, so the
  // one-line form must match the field count of the equivalent multi-line form.
  lMultiCount := CountFields('MultiValue', 'TLocalMulti');
  Assert.IsTrue(lMultiCount > 0, 'Expected the multi-line local record field.');
  AssertMember('LocalValue', 'TLocalRec', 'Integer', 46, lMultiCount);
  // A hint directive after the closing end still closes the type on its line, and the
  // following type keeps its own members.
  AssertMember('HintValue', 'THintRec', 'Integer', 32);
  AssertMember('AfterValue', 'TAfterHints', 'Integer', 37);
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') and
      MatchText(lSymbol.Name, ['THintClass', 'THintRec', 'THintMsg', 'THintMulti']) then
    begin
      Assert.AreEqual(lSymbol.Line, lSymbol.EndLine, lSymbol.Name + ' must end on its line.');
      Assert.AreEqual('', lSymbol.UnsupportedReason, lSymbol.Name + ' reason');
    end;
  for lSymbol in lFacts.Symbols do
    if MatchText(lSymbol.OwnerName, ['THintClass', 'THintRec', 'THintMsg', 'THintMulti']) and
      SameText(lSymbol.SymbolClass, 'field') then
      Assert.IsTrue(SameText(lSymbol.Name, 'HintValue') or
        (SameText(lSymbol.Name, 'Child') and (lSymbol.Line = 6)),
        'Fake member ' + lSymbol.OwnerName + '.' + lSymbol.Name);
  // A record whose first fields share the header line keeps its later body lines.
  AssertMember('First', 'TMixed', 'Integer', 26);
  AssertMember('Second', 'TMixed', 'Integer', 27);
  Assert.AreEqual(0, CountFields('Extra2', 'TMixedOdd'),
    'An unparsed header member must not be guessed.');
  lFound := False;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') and
      (SameText(lSymbol.Name, 'TMixed') or SameText(lSymbol.Name, 'TMixedOdd')) then
    begin
      lFound := True;
      if SameText(lSymbol.Name, 'TMixed') then
      begin
        Assert.AreEqual(28, lSymbol.EndLine, 'TMixed end line');
        Assert.AreEqual('', lSymbol.UnsupportedReason, 'TMixed reason');
      end else
      begin
        Assert.AreEqual(30, lSymbol.EndLine, 'TMixedOdd end line');
        Assert.AreNotEqual('', lSymbol.UnsupportedReason, 'TMixedOdd must fail closed.');
      end;
    end;
  Assert.IsTrue(lFound, 'Expected the mixed record types.');

  for lTypeName in cOneLineTypes do
  begin
    lFound := False;
    for lSymbol in lFacts.Symbols do
      if SameText(lSymbol.Name, lTypeName) and SameText(lSymbol.SymbolClass, 'type-member') and
        SameText(lSymbol.UnitName, 'OneLineUnit') then
      begin
        lFound := True;
        Assert.AreEqual(lSymbol.Line, lSymbol.EndLine, lTypeName + ' must end on its own line.');
        // An inline body that is not plain fields stays unsupported instead of guessed.
        if SameText(lTypeName, 'TOddVis') then
          Assert.AreNotEqual('', lSymbol.UnsupportedReason, 'TOddVis must fail closed.')
        else
          Assert.AreEqual('', lSymbol.UnsupportedReason, lTypeName + ' reason');
      end;
    Assert.IsTrue(lFound, 'Expected type ' + lTypeName);
  end;
  for lSymbol in lFacts.Symbols do
    if SameText(lSymbol.Name, 'TBase') and SameText(lSymbol.SymbolClass, 'type-member') and
      SameText(lSymbol.UnitName, 'OneLineUnit') then
      Assert.AreEqual(7, lSymbol.EndLine, 'TBase body must still end at its end line.');
end;

procedure TWithBinderTests.IndexedPropertySelectorWithoutDereferenceStaysUnsupported;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := WithBinderTempPath('withbinder-indexed-property-regression.pas');
  lSource :=
    'unit WithBinderIndexedPropertyRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TIndexedRecord = record' + sLineBreak +
    '    Name: string;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TIndexedBox = class' + sLineBreak +
    '  private' + sLineBreak +
    '    function GetItem(const aIndex: Integer): TIndexedRecord;' + sLineBreak +
    '  public' + sLineBreak +
    '    property Items[const aIndex: Integer]: TIndexedRecord read GetItem; default;' +
    sLineBreak +
    '  end;' + sLineBreak +
    '  TScope = class' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'function TIndexedBox.GetItem(const aIndex: Integer): TIndexedRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result.Name := '''';' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TScope.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lBox: TIndexedBox;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lBox[0] do' + sLineBreak +
    '    Name := ''indexed property'';' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    Assert.AreEqual('unsupported', lBindings[0].Selectors[0].Status);
    Assert.AreEqual('PROPERTY_SELECTOR_UNSUPPORTED', lBindings[0].Selectors[0].ReasonCode);
    Assert.AreEqual('', lBindings[0].Selectors[0].TypeName);
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.MemberReferenceReportsRoutineScopeConflict;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
begin
  lPath := WithBinderTempPath('withbinder-scope-conflict-regression.pas');
  lSource :=
    'unit WithBinderScopeConflictRegression;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TBox = class' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure Flush;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TScope = class' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'procedure Flush;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Flush;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TBox.Flush;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'class procedure TScope.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lBox: TBox;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lBox do' + sLineBreak +
    '    Flush;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  try
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lPath;
    lOptions.ProjectContextApplied := True;
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.IsTrue(lModel.Success);

    lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

    Assert.AreEqual(1, Integer(Length(lBindings)));
    for lReference in lBindings[0].References do
      if SameText(lReference.Name, 'Flush') and SameText(lReference.Classification, 'member') then
      begin
        Assert.AreEqual('routine', lReference.ScopeConflictKind);
        Assert.AreEqual('Flush', lReference.ScopeConflictName);
        Exit;
      end;
    Assert.Fail('Expected member-bound Flush reference.');
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
end;

procedure TWithBinderTests.UnresolvedSelectorMarksBodyReferencesExternal;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('MissingReceiver', lBindings[2].Selectors[0].SelectorText);
  Assert.AreEqual('unresolved', lBindings[2].Selectors[0].Status);
  Assert.IsTrue(HasReference(lBindings[2], 'MissingMember', 'external'));
end;

procedure TWithBinderTests.NestedWithStatementsUseOuterReceiverStack;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lFoundOuterAfterInnerRange: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lReference: TDelphiSemanticBoundReference;
begin
  lFoundOuterAfterInnerRange := False;
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings[3].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[3].Selectors[0].TypeName);
  Assert.IsFalse(HasAnyReference(lBindings[3], 'SecondOnly'));
  for lReference in lBindings[3].References do
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 57) and (lReference.Column = 5) and (lReference.EndLine = 57) and
      (lReference.EndColumn = 13) then
      lFoundOuterAfterInnerRange := True;
  Assert.IsTrue(lFoundOuterAfterInnerRange, 'Expected outer reference after inner with to keep range.');
  Assert.AreEqual(2, Integer(Length(lBindings[4].Selectors)));
  Assert.AreEqual('TFirstRecord', lBindings[4].Selectors[0].TypeName);
  Assert.AreEqual('TSecondRecord', lBindings[4].Selectors[1].TypeName);
  Assert.AreEqual('TFirstRecord', ReceiverOf(lBindings[4], 'FirstOnly', 'member'));
  Assert.AreEqual('TSecondRecord', ReceiverOf(lBindings[4], 'SecondOnly', 'member'));
end;

procedure TWithBinderTests.NestedRoutineWithUsesParentRoutineScope;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('lOuterReceiver', lBindings[5].Selectors[0].SelectorText);
  Assert.AreEqual('resolved', lBindings[5].Selectors[0].Status);
  Assert.AreEqual('TFirstRecord', lBindings[5].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[5], 'FirstOnly', 'member'));
  Assert.IsTrue(HasReference(lBindings[5], 'lInnerValue', 'lexical'));
end;

procedure TWithBinderTests.SiblingRoutineLocalsDoNotLeakIntoNestedWith;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('lSiblingReceiver', lBindings[6].Selectors[0].SelectorText);
  Assert.AreEqual('unresolved', lBindings[6].Selectors[0].Status);
  Assert.IsTrue(HasReference(lBindings[6], 'FirstOnly', 'external'));
end;

procedure TWithBinderTests.PlanningMetadataCountsLookupSourcesAndReasons;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.AreEqual('skipped', lBinding.Status);
  Assert.AreEqual('UNSUPPORTED_REFERENCE', lBinding.SkipReason);
  Assert.AreEqual(5, lBinding.MemberReferenceCount);
  Assert.AreEqual(2, lBinding.LexicalReferenceCount);
  Assert.AreEqual(3, lBinding.ExternalReferenceCount);
  Assert.AreEqual(1, lBinding.IntrinsicReferenceCount);
  Assert.AreEqual(3, lBinding.UnsupportedReferenceCount);
  Assert.AreEqual(1, lBinding.UnresolvedReferenceCount);
  Assert.AreEqual('receiver', LookupSourceOf(lBinding, 'FirstOnly', 'member'));
  Assert.AreEqual('lexical', LookupSourceOf(lBinding, 'lText', 'lexical'));
  Assert.AreEqual(2, CountReferences(lBinding, 'lText'));
  Assert.AreEqual('intrinsic', LookupSourceOf(lBinding, 'Length', 'intrinsic'));
  Assert.AreEqual('external', LookupSourceOf(lBinding, 'KnownExternalCall', 'external'));
  Assert.AreEqual('EXTERNAL_ROUTINE_CALL', ReasonOf(lBinding, 'KnownExternalCall', 'external'));
  Assert.AreEqual('UNKNOWN_ROUTINE_CALL', ReasonOf(lBinding, 'UnknownExternalCall', 'external'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'FirstOnly', 'unsupported'));
  Assert.AreEqual('INDEXED_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'FirstOnly[0]', 'unsupported'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('NAME_NOT_FOUND', ReasonOf(lBinding, 'MissingPlanValue', 'unresolved'));
end;

procedure TWithBinderTests.ScopedDeclarationsMarkBindingSkipped;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[8];

  Assert.IsTrue(lBinding.HasScopedDeclaration);
  Assert.AreEqual('skipped', lBinding.Status);
  Assert.AreEqual('SCOPED_DECLARATION', lBinding.SkipReason);
end;

procedure TWithBinderTests.ControlCharacterLiteralsAreIgnored;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.AreEqual(6, CountReferences(lBinding, 'FirstOnly'));
  Assert.IsFalse(HasAnyReference(lBinding, '13'));
  Assert.IsFalse(HasAnyReference(lBinding, '10'));
end;

procedure TWithBinderTests.SafeBindingsArePlannedDirectReferences;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[1];

  Assert.AreEqual('planned', lBinding.Status);
  Assert.AreEqual('', lBinding.SkipReason);
  Assert.AreEqual(3, lBinding.MemberReferenceCount);
  Assert.AreEqual(0, lBinding.UnsupportedReferenceCount);
  Assert.AreEqual(0, lBinding.UnresolvedReferenceCount);
  Assert.AreEqual(0, lBinding.ExternalReferenceCount);
end;

procedure TWithBinderTests.SkipReasonsCoverExternalAndUnresolvedBranches;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual('skipped', lBindings[6].Status);
  Assert.AreEqual('EXTERNAL_REFERENCE', lBindings[6].SkipReason);
  Assert.AreEqual('skipped', lBindings[9].Status);
  Assert.AreEqual('UNRESOLVED_REFERENCE', lBindings[9].SkipReason);
  Assert.IsTrue(HasReference(lBindings[9], 'MissingOnly', 'unresolved'));
end;

procedure TWithBinderTests.CastExpressionRolesRemainUnsupported;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lBinding := lBindings[7];

  Assert.IsTrue(HasReference(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('none', LookupSourceOf(lBinding, 'TFirstRecord', 'unsupported'));
  Assert.AreEqual('CALL_SELECTOR_UNSUPPORTED', ReasonOf(lBinding, 'TFirstRecord', 'unsupported'));
end;

procedure TWithBinderTests.InventoryExposesFileAwareSymbolsAndBindings;
var
  lFoundCallArgumentRange: Boolean;
  lFoundFirstOnlyRange: Boolean;
  lFoundRepeatedCallArgumentRange: Boolean;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lRangeDetails: string;
  lReference: TDelphiSemanticBoundReference;
begin
  lFoundCallArgumentRange := False;
  lFoundFirstOnlyRange := False;
  lFoundRepeatedCallArgumentRange := False;
  lRangeDetails := '';
  lModel := LoadModel;

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);

  Assert.AreEqual(lModel.FileName, lInventory.FileName);
  Assert.AreEqual('WithBinderUnit', lInventory.UnitName);
  Assert.IsTrue(HasInventorySymbol(lInventory, 'WithBinderUnit', 'unit', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'TFirstRecord', 'declaration', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'FirstOnly', 'member', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'RunWithBinder', 'routine', ''));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'aParamValue', 'parameter', 'RunWithBinder'));
  Assert.IsTrue(HasInventorySymbol(lInventory, 'lFirst', 'local', 'RunWithBinder'));
  Assert.IsTrue(Length(lInventory.Bindings) > 0, 'Expected with bindings.');
  Assert.AreEqual(lModel.FileName, lInventory.Bindings[0].FileName);
  Assert.AreEqual('WithBinderUnit', lInventory.Bindings[0].UnitName);
  Assert.AreEqual('RunWithBinder', lInventory.Bindings[0].RoutineName);
  Assert.AreEqual(1, Integer(Length(lInventory.Bindings[0].Selectors)));
  Assert.AreEqual('lFirst', lInventory.Bindings[0].Selectors[0].SelectorText);
  for lReference in lInventory.Bindings[0].References do
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 32) and (lReference.Column = 5) and (lReference.EndLine = 32) and
      (lReference.EndColumn = 13) then
      lFoundFirstOnlyRange := True;
  Assert.IsTrue(lFoundFirstOnlyRange, 'Expected exact source range for FirstOnly member reference.');
  for lReference in lInventory.Bindings[7].References do
  begin
    if SameText(lReference.Name, 'FirstOnly') then
      lRangeDetails := lRangeDetails + Format('%s:%d:%d-%d:%d ',
        [lReference.Classification, lReference.Line, lReference.Column, lReference.EndLine,
        lReference.EndColumn]);
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 99) and (lReference.Column = 23) and (lReference.EndLine = 99) and
      (lReference.EndColumn = 31) then
      lFoundCallArgumentRange := True;
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 100) and (lReference.Column = 23) and (lReference.EndLine = 100) and
      (lReference.EndColumn = 31) then
      lFoundRepeatedCallArgumentRange := True;
  end;
  Assert.IsTrue(lFoundCallArgumentRange, 'Expected exact source range for FirstOnly call argument. Actual: ' +
    lRangeDetails);
  Assert.IsTrue(lFoundRepeatedCallArgumentRange,
    'Expected exact source range for repeated FirstOnly call argument. Actual: ' + lRangeDetails);
end;

procedure TWithBinderTests.InventoryExposesDakPlannerSourceModelFacts;
var
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lIndentedDetails: string;
  lProjectedBaseName: Boolean;
  lScanSymbol: TDelphiSemanticInventorySymbol;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lProjectedBaseName := False;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'SourceModelGoldenUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  lInventory.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lInventory.Symbols);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenVariant', 'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(lSymbol.EndLine > lSymbol.Line, 'Expected declaration end range.');

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Mode', 'field', 'TGoldenVariant', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'MultiA', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'MultiB', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'RealValue', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'ExtraReal', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'HasReal', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TextValue', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Offset', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Size', 'field', 'TGoldenVariant', lSymbol));
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'cGoldenVariantReal', 'field',
    'TGoldenVariant', lSymbol));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'GoldenSplitGlobal', 'unit-global', '',
    lSymbol), 'Expected split unit-global declaration.');
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'gisSkip', 'constant', '', lSymbol),
    'Expected unit-global anonymous enum value.');
  Assert.AreEqual('(gisRead, gisSkip)', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'PGoldenRecord', 'type-member', '', lSymbol));
  Assert.AreEqual('^TGoldenRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenRecord', lSymbol.RelatedTypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenRecordAlias', 'type-member', '',
    lSymbol));
  Assert.AreEqual('TGoldenRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenRecord', lSymbol.RelatedTypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'RecordName', 'field', 'TGoldenRecordAlias',
    lSymbol));
  Assert.AreEqual('TGoldenRecord', lSymbol.SourceOwnerType);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Items', 'property', 'TGoldenDefaultList',
    lSymbol));
  Assert.IsTrue(lSymbol.IsDefault);
  Assert.IsTrue(lSymbol.IsIndexed);
  Assert.AreEqual(1, lSymbol.IndexParameterCount);
  Assert.AreEqual('PGoldenRecord', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lRecords', 'local', '', lSymbol));
  Assert.AreEqual('TArray<TGoldenRecord>', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lStaticRecordPtrs', 'local', '', lSymbol));
  Assert.AreEqual('array[1..2]ofPGoldenRecord', StringReplace(lSymbol.TypeName, ' ', '',
    [rfReplaceAll]));
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenLocalRecord', 'type-member', '',
    lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalName', 'field', 'TGoldenLocalRecord',
    lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalCount', 'field', 'TGoldenLocalRecord',
    lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lLocalRecord', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenLocalRecord', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenScope.Run.lAnonymousLocal',
    'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalFlag', 'field',
    'TGoldenScope.Run.lAnonymousLocal', lSymbol));
  Assert.AreEqual('Boolean', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LocalText', 'field',
    'TGoldenScope.Run.lAnonymousLocal', lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lAnonymousLocal', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenScope.Run.lAnonymousLocal', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenScope.Run.lVariantLocal',
    'type-member', '', lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Len', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Byte', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Kind', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'AsInteger', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('Integer', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'AsText', 'field',
    'TGoldenScope.Run.lVariantLocal', lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lVariantLocal', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenScope.Run.lVariantLocal', lSymbol.TypeName);
  Assert.AreEqual('TGoldenScope.Run', lSymbol.RoutineName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenLateLocalRecord', 'type-member', '',
    lSymbol));
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LateName', 'field', 'TGoldenLateLocalRecord',
    lSymbol));
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'lLateLocalRecord', 'local', '', lSymbol));
  Assert.AreEqual('TGoldenLateLocalRecord', lSymbol.TypeName);
  lIndentedDetails := '';
  for lScanSymbol in lInventory.Symbols do
    if ContainsText(lScanSymbol.Name, 'GoldenIndented') or ContainsText(lScanSymbol.TypeName,
      'GoldenIndented') then
      lIndentedDetails := lIndentedDetails + lScanSymbol.Name + ':' + lScanSymbol.SymbolClass + ':' +
        lScanSymbol.TypeName + ':' + lScanSymbol.OwnerType + '; ';
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'TGoldenIndentedState', 'type-member', '',
    lSymbol), 'Expected indented implementation type. Symbols=' + lIndentedDetails);
  Assert.AreEqual('record', lSymbol.TypeCategory);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'StateName', 'field',
    'TGoldenIndentedState', lSymbol), 'Expected indented implementation type field. Symbols=' +
    lIndentedDetails);
  Assert.AreEqual('string', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'GoldenIndentedState', 'unit-global', '',
    lSymbol), 'Expected indented implementation var. Symbols=' + lIndentedDetails);
  Assert.AreEqual('TGoldenIndentedState', lSymbol.TypeName);

  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'BaseName', 'field', 'TGoldenClass', lSymbol));
  Assert.AreEqual('TGoldenBase', lSymbol.SourceOwnerType);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'HelperTouch', 'method', 'TGoldenRecord',
    lSymbol));
  Assert.AreEqual('TGoldenRecordHelper', lSymbol.SourceOwnerType);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'Touch', 'method', 'TGoldenClass', lSymbol));
  Assert.IsTrue(lSymbol.IsOverride);
  for lScanSymbol in lInventory.Symbols do
    if SameText(lScanSymbol.Name, 'BaseName') and
      SameText(lScanSymbol.SymbolClass, 'current-class-member') and
      SameText(lScanSymbol.OwnerName, 'TGoldenClass') and
      SameText(lScanSymbol.RoutineName, 'TGoldenClass.Touch') then
      lProjectedBaseName := True;
  Assert.IsTrue(lProjectedBaseName);
end;

procedure TWithBinderTests.InventoryExpansionUsesIndexedOwnMemberLookup;
var
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');

  Assert.IsTrue(ContainsText(lSourceText, 'BuildInventoryOwnMemberKeys'),
    'Inventory expansion must build an indexed own-member lookup for large semantic inventories.');
  Assert.IsFalse(ContainsText(lSourceText, 'InventoryOwnerHasOwnMember(aSymbols'),
    'Inventory expansion must not scan every symbol for each related inherited member.');
end;

procedure TWithBinderTests.InventoryExpansionUsesStableRelatedMemberOwnerIndex;
var
  lExpansionEnd: Integer;
  lExpansionStart: Integer;
  lExpansionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lExpansionStart := Pos('procedure AddRelatedInventoryMemberSymbols', lSourceText);
  lExpansionEnd := Pos('procedure AddRelatedInventoryCurrentClassSymbols', lSourceText);
  lExpansionText := Copy(lSourceText, lExpansionStart, lExpansionEnd - lExpansionStart);

  Assert.IsTrue(ContainsText(lSourceText, 'BuildRelatedInventoryMemberRelations'),
    'Inventory expansion must index inherited/helper owner relations once for propagation.');
  Assert.IsFalse(ContainsText(lExpansionText, 'repeat'),
    'Inventory expansion must not rebuild related-member indexes in a repeat loop.');
end;

procedure TWithBinderTests.InventoryExpansionIndexesCurrentClassProjectionContexts;
var
  lExpansionEnd: Integer;
  lExpansionStart: Integer;
  lExpansionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lExpansionStart := Pos('procedure AddRelatedInventoryCurrentClassSymbols', lSourceText);
  lExpansionEnd := Pos('procedure AddExpandedExternalTypeSymbol', lSourceText);
  Assert.IsTrue((lExpansionStart > 0) and (lExpansionEnd > lExpansionStart),
    'Expected current-class expansion source section.');

  lExpansionText := Copy(lSourceText, lExpansionStart, lExpansionEnd - lExpansionStart);
  Assert.IsTrue(ContainsText(lExpansionText, 'lProjectedContextKeys'),
    'Current-class expansion must project each owner/routine context once.');
  Assert.IsTrue(ContainsText(lExpansionText,
    'lOwnerKey := lCurrentMember.UnitName + #31 + lCurrentMember.FileName'),
    'Current-class owner keys must include unit and file identity.');
  Assert.IsTrue(ContainsText(lExpansionText,
    'lProjectedContextKey := lOwnerKey + #31 + lCurrentMember.RoutineName'),
    'Current-class projection keys must include owner key plus routine identity.');
end;

procedure TWithBinderTests.InventoryExpansionScopesCurrentClassProjectionByUnit;
var
  lExpandedSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;

  function CountCurrentClassSymbol(const aName, aRoutineName,
    aUnitName: string): Integer;
  var
    lSymbol: TDelphiSemanticInventorySymbol;
  begin
    Result := 0;
    for lSymbol in lExpandedSymbols do
      if SameText(lSymbol.Name, aName) and
        SameText(lSymbol.SymbolClass, 'current-class-member') and
        SameText(lSymbol.RoutineName, aRoutineName) and
        SameText(lSymbol.UnitName, aUnitName) then
        Inc(Result);
  end;
begin
  SetLength(lSymbols, 8);

  lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[0].Name := 'UnitAOnly';
  lSymbols[0].SymbolClass := 'field';
  lSymbols[0].OwnerType := 'TDuplicate';
  lSymbols[0].UnitName := 'DuplicateA';
  lSymbols[0].FileName := 'DuplicateA.pas';

  lSymbols[1] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[1].Name := 'UnitBOnly';
  lSymbols[1].SymbolClass := 'field';
  lSymbols[1].OwnerType := 'TDuplicate';
  lSymbols[1].UnitName := 'DuplicateB';
  lSymbols[1].FileName := 'DuplicateB.pas';

  lSymbols[2] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[2].Name := 'ExistingA';
  lSymbols[2].SymbolClass := 'current-class-member';
  lSymbols[2].OwnerType := 'TDuplicate';
  lSymbols[2].RoutineName := 'RunA';
  lSymbols[2].UnitName := 'DuplicateA';
  lSymbols[2].FileName := 'DuplicateA.pas';

  lSymbols[3] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[3].Name := 'ExistingB';
  lSymbols[3].SymbolClass := 'current-class-member';
  lSymbols[3].OwnerType := 'TDuplicate';
  lSymbols[3].RoutineName := 'RunB';
  lSymbols[3].UnitName := 'DuplicateB';
  lSymbols[3].FileName := 'DuplicateB.pas';

  lSymbols[4] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[4].Name := 'UnitCOnly';
  lSymbols[4].SymbolClass := 'field';
  lSymbols[4].OwnerType := 'TDuplicate';
  lSymbols[4].UnitName := 'DuplicateC';
  lSymbols[4].FileName := 'DuplicateC.pas';

  lSymbols[5] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[5].Name := 'UnitDOnly';
  lSymbols[5].SymbolClass := 'field';
  lSymbols[5].OwnerType := 'TDuplicate';
  lSymbols[5].UnitName := 'DuplicateD';
  lSymbols[5].FileName := 'DuplicateD.pas';

  lSymbols[6] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[6].Name := 'ExistingC';
  lSymbols[6].SymbolClass := 'current-class-member';
  lSymbols[6].OwnerType := 'TDuplicate';
  lSymbols[6].RoutineName := 'RunShared';
  lSymbols[6].UnitName := 'DuplicateC';
  lSymbols[6].FileName := 'DuplicateC.pas';

  lSymbols[7] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[7].Name := 'ExistingD';
  lSymbols[7].SymbolClass := 'current-class-member';
  lSymbols[7].OwnerType := 'TDuplicate';
  lSymbols[7].RoutineName := 'RunShared';
  lSymbols[7].UnitName := 'DuplicateD';
  lSymbols[7].FileName := 'DuplicateD.pas';

  lExpandedSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);

  Assert.AreEqual(1, CountCurrentClassSymbol('UnitAOnly', 'RunA',
    'DuplicateA'));
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitBOnly', 'RunB',
    'DuplicateB'));
  Assert.AreEqual(0, CountCurrentClassSymbol('UnitAOnly', 'RunB',
    'DuplicateA'), 'Unit A members must not project into Unit B routines.');
  Assert.AreEqual(0, CountCurrentClassSymbol('UnitBOnly', 'RunA',
    'DuplicateB'), 'Unit B members must not project into Unit A routines.');
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitCOnly', 'RunShared',
    'DuplicateC'));
  Assert.AreEqual(1, CountCurrentClassSymbol('UnitDOnly', 'RunShared',
    'DuplicateD'));
end;

procedure TWithBinderTests.ReferenceScannerPreservesRepresentativeTokenShapes;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;

  procedure AssertReference(const aBinding: TDelphiSemanticWithBinding; const aName,
    aClassification: string; const aLine, aColumn, aEndLine, aEndColumn: Integer);
  var
    lDetails: string;
    lReference: TDelphiSemanticBoundReference;
  begin
    lDetails := '';
    for lReference in aBinding.References do
    begin
      lDetails := lDetails + Format('%s/%s@%d:%d-%d:%d ', [lReference.Name,
        lReference.Classification, lReference.Line, lReference.Column,
        lReference.EndLine, lReference.EndColumn]);
      if SameText(lReference.Name, aName) and
        SameText(lReference.Classification, aClassification) and
        (lReference.Line = aLine) and (lReference.Column = aColumn) and
        (lReference.EndLine = aEndLine) and (lReference.EndColumn = aEndColumn) then
        Exit;
    end;
    Assert.Fail(Format('Expected %s/%s at %d:%d-%d:%d. Actual: %s',
      [aName, aClassification, aLine, aColumn, aEndLine, aEndColumn, lDetails]));
  end;

begin
  lModel := LoadModel;
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  AssertReference(lBindings[0], 'FirstOnly', 'member', 32, 5, 32, 13);
  AssertReference(lBindings[0], 'aParamValue', 'lexical', 32, 18, 32, 28);
  AssertReference(lBindings[0], 'lSecond.SecondOnly', 'unsupported', 34, 5, 34, 22);
  AssertReference(lBindings[0], 'FirstOnly[0]', 'unsupported', 38, 5, 38, 16);
  AssertReference(lBindings[7], 'KnownExternalCall', 'external', 99, 5, 99, 32);
  AssertReference(lBindings[7], 'FirstOnly', 'member', 99, 23, 99, 31);
end;

procedure TWithBinderTests.ReferenceBindingUsesManualIdentifierScanner;
var
  lArgumentScannerText: string;
  lArgumentStart: Integer;
  lBindEnd: Integer;
  lBindStart: Integer;
  lBindText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');

  lArgumentStart := Pos('procedure AddArgumentReferences', lSourceText);
  lBindStart := Pos('function BindReferences', lSourceText);
  lBindEnd := Pos('function StatementContains', lSourceText);
  Assert.IsTrue((lArgumentStart > 0) and (lBindStart > lArgumentStart) and
    (lBindEnd > lBindStart), 'Expected reference binding source sections.');

  lArgumentScannerText := Copy(lSourceText, lArgumentStart, lBindStart - lArgumentStart);
  lBindText := Copy(lSourceText, lBindStart, lBindEnd - lBindStart);
  Assert.IsFalse(ContainsText(lArgumentScannerText, 'TRegEx.Match'),
    'Argument reference binding must use the manual identifier scanner.');
  Assert.IsFalse(ContainsText(lBindText, 'TRegEx.Match'),
    'Body reference binding must use the manual identifier scanner.');
end;

procedure TWithBinderTests.InventoryExpansionUsesOrdinalIgnoreCaseSymbolKeys;
var
  lKeyFunctionText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');
  lKeyFunctionText := Copy(lSourceText, Pos('function InventorySymbolKey', lSourceText), 900);

  Assert.IsTrue(ContainsText(lSourceText,
    'lKeys := TDictionary<string, Byte>.Create(TFastCaseAwareComparer.OrdinalIgnoreCase);'),
    'Inventory expansion symbol keys must use the Delphi ordinal-ignore-case comparer.');
  Assert.IsFalse(ContainsText(lKeyFunctionText, 'UpperCase('),
    'Inventory expansion must not allocate uppercase copies while building every symbol key.');
end;

procedure TWithBinderTests.InventoryExpansionDeduplicatesSymbolsCaseInsensitively;
var
  lExpandedSymbols: TArray<TDelphiSemanticInventorySymbol>;
  lLocalSymbolCount: Integer;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  SetLength(lSymbols, 2);
  lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
  lSymbols[0].Name := 'LocalName';
  lSymbols[0].SymbolClass := 'local';
  lSymbols[0].TypeName := 'TRecord';
  lSymbols[0].RoutineName := 'TRunner.Run';
  lSymbols[0].UnitName := 'CaseUnit';
  lSymbols[0].FileName := 'CaseUnit.pas';
  lSymbols[0].Line := 10;
  lSymbols[0].Column := 5;

  lSymbols[1] := lSymbols[0];
  lSymbols[1].Name := 'localname';
  lSymbols[1].TypeName := 'trecord';
  lSymbols[1].RoutineName := 'trunner.run';
  lSymbols[1].UnitName := 'caseunit';
  lSymbols[1].FileName := 'caseunit.pas';

  lExpandedSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);

  lLocalSymbolCount := 0;
  for lSymbol in lExpandedSymbols do
    if SameText(lSymbol.Name, 'LocalName') and SameText(lSymbol.SymbolClass, 'local') then
      Inc(lLocalSymbolCount);

  Assert.AreEqual(1, lLocalSymbolCount,
    'Inventory expansion must keep duplicate symbol identity case-insensitive.');
end;

procedure TWithBinderTests.AnonymousNestedRecordSelectorsUseSyntheticOwner;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'NestedAnonymousWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  lInventory.Symbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lInventory.Symbols);
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'Version', 'field', 'DBF_File', lSymbol),
    'Expected nested anonymous fields not to be flattened onto the outer record.');
  Assert.IsFalse(TryFindInventorySymbol(lInventory, 'RecSize', 'field', 'DBF_File', lSymbol),
    'Expected nested anonymous fields not to be flattened onto the outer record.');

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('DBF_File', lBindings[0].Selectors[0].TypeName);
  Assert.AreEqual('DBF_File.Struktur', lBindings[0].Selectors[1].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'Version', 'member'));
  Assert.AreEqual('DBF_File.Struktur', ReceiverOf(lBindings[0], 'Version', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'RecSize', 'member'));
end;

procedure TWithBinderTests.GlobalAnonymousRecordSelectorUsesSyntheticOwner;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'GlobalAnonymousWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'ModuleError', 'unit-global', '',
    lSymbol));
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', lSymbol.TypeName);
  Assert.IsTrue(TryFindInventorySymbol(lInventory, 'LineNo', 'field',
    'GlobalAnonymousWithUnit.ModuleError', lSymbol));

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('ModuleError', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'fc', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'LineNo', 'member'));
  Assert.IsTrue(HasReference(lBindings[0], 'ErrorChar', 'member'));
  Assert.AreEqual('GlobalAnonymousWithUnit.ModuleError', ReceiverOf(lBindings[0], 'fc', 'member'));
end;

procedure TWithBinderTests.DefaultIndexedPropertyPointerSelectorDereferencesToRecord;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', 'DefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual('lList[0]^', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('TDefaultRecord', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  Assert.AreEqual('TDefaultRecord', ReceiverOf(lBindings[0], 'Value', 'member'));
end;

procedure TWithBinderTests.NestedParentDefaultIndexedPropertyPointerSelectorDereferencesToRecord;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lCount: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lCount := 0;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Inc(lCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('TDatFile', lBinding.Selectors[0].TypeName);
      Assert.AreEqual('NestedParentDefaultPointerWithUnit',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('TDatFile', lBinding.Selectors[0].TypeIdentity.Name);
      Assert.IsTrue(lBinding.Selectors[0].TypeIdentity.DeclaredId.Value <> '');
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('NestedParentDefaultPointerWithUnit',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeIdentity.Name);
      Assert.IsTrue(lBinding.Selectors[1].TypeIdentity.DeclaredId.Value <> '');
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'));
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Value', 'member'));
    end;
  Assert.AreEqual(1, lCount);
end;

procedure TWithBinderTests.NestedParentIndexedSelectorPreservesPrecedenceAndSafety;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFoundAmbiguous: Boolean;
  lFoundIncomplete: Boolean;
  lFallbackCount: Integer;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lNearestCount: Integer;
  lOptions: TDelphiSemanticModelOptions;
  lShadowCount: Integer;
  lUnresolvedCount: Integer;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lShadowCount := 0;
  lNearestCount := 0;
  lFallbackCount := 0;
  lUnresolvedCount := 0;
  for lBinding in lBindings do
  begin
    if not SameText(lBinding.SelectorText, 'Maske[0]^') then
      Continue;
    if SameText(lBinding.RoutineName, 'RunShadow') then
    begin
      Inc(lShadowCount);
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'));
    end else if SameText(lBinding.RoutineName, 'RunNearestParent') then
    begin
      Inc(lNearestCount);
      Assert.AreEqual(3, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('TAltEntry', lBinding.Selectors[2].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'));
    end else if SameText(lBinding.RoutineName, 'RunLexicalFallback') then
    begin
      Inc(lFallbackCount);
      Assert.AreEqual('TAltEntry', lBinding.Selectors[1].TypeName);
      Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'));
    end;
  end;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunUnresolved') and
      SameText(lBinding.SelectorText, 'Missing[0]^') then
    begin
      Inc(lUnresolvedCount);
      Assert.AreEqual('unresolved', lBinding.Selectors[1].Status,
        'RunUnresolved selector status');
      Assert.AreEqual('NAME_NOT_FOUND', lBinding.Selectors[1].ReasonCode,
        'RunUnresolved selector reason');
      Assert.AreEqual('planned', lBinding.Status,
        'RunUnresolved raw binding summarizes body references; final plan must refuse selector');
    end;
  Assert.AreEqual(1, lShadowCount);
  Assert.AreEqual(1, lNearestCount);
  Assert.AreEqual(1, lFallbackCount);
  Assert.AreEqual(1, lUnresolvedCount);

  lFoundAmbiguous := False;
  for lMember in lModel.Members do
    if SameText(lMember.OwnerName, 'TDatFile') and
      SameText(lMember.Name, 'Maske') then
    begin
      lFoundAmbiguous := True;
      Break;
    end;
  Assert.IsTrue(lFoundAmbiguous);
  SetLength(lModel.Members, Length(lModel.Members) + 1);
  lModel.Members[High(lModel.Members)] := lMember;
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  lFoundAmbiguous := False;
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Assert.AreEqual('ambiguous', lBinding.Selectors[1].Status,
        'RunNested duplicate member selector status');
      Assert.AreEqual('MULTIPLE_MEMBER_CANDIDATES',
        lBinding.Selectors[1].ReasonCode,
        'RunNested duplicate member selector reason');
      Assert.AreEqual('skipped', lBinding.Status,
        'RunNested duplicate member raw body-reference status');
      lFoundAmbiguous := True;
    end;
  Assert.IsTrue(lFoundAmbiguous);
  SetLength(lModel.Members, Length(lModel.Members) - 1);

  lFoundIncomplete := False;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TMaskEntry') and
      SameText(lDeclaration.Kind, 'type') and
      SameText(lDeclaration.TypeName, 'record') then
    begin
      lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
      lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
      lDiagnostic.FileName := lDeclaration.FileName;
      if lDiagnostic.FileName = '' then
        lDiagnostic.FileName := lModel.FileName;
      lDiagnostic.Line := lDeclaration.Line;
      SetLength(lModel.Diagnostics, Length(lModel.Diagnostics) + 1);
      lModel.Diagnostics[High(lModel.Diagnostics)] := lDiagnostic;
      lFoundIncomplete := True;
      Break;
    end;
  Assert.IsTrue(lFoundIncomplete);
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  for lBinding in lBindings do
    if SameText(lBinding.RoutineName, 'RunNested') and
      SameText(lBinding.SelectorText, 'Maske[i]^') then
    begin
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'RunNested injected incomplete-owner selector status');
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('skipped', lBinding.Status,
        'RunNested injected incomplete-owner binding status');
      Assert.AreEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'RunNested injected incomplete-owner safety reason');
      Exit;
    end;
  Assert.Fail('Expected nested selector binding with incomplete owner.');
end;

procedure TWithBinderTests.NestedUnresolvedSelectorRefusesFinalRewrite;
var
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lEdit: TDelphiSemanticRemoveWithEdit;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticApiOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lStatement: TDelphiSemanticRemoveWithFinalStatement;
  lStatementCount: Integer;
  lTarget: TDelphiSemanticWithBinding;
begin
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWith.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lBindingCount := 0;
  lTarget := Default(TDelphiSemanticWithBinding);
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName),
      'NestedParentDefaultPointerWithUnit.pas') and
      SameText(lBinding.UnitName, 'NestedParentDefaultPointerWithUnit') and
      SameText(lBinding.RoutineName, 'RunUnresolved') and
      SameText(lBinding.SelectorText, 'Missing[0]^') then
    begin
      Inc(lBindingCount);
      lTarget := lBinding;
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'RunUnresolved project binding selector stack');
      Assert.AreEqual('unresolved', lBinding.Selectors[1].Status,
        'RunUnresolved project selector status');
      Assert.AreEqual('NAME_NOT_FOUND', lBinding.Selectors[1].ReasonCode,
        'RunUnresolved project selector reason');
    end;
  Assert.AreEqual(1, lBindingCount,
    'RunUnresolved must identify exactly one source binding');

  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  lStatementCount := 0;
  for lStatement in lPlan.FinalStatements do
    if SameText(ExtractFileName(lStatement.FileName),
      'NestedParentDefaultPointerWithUnit.pas') and
      SameText(lStatement.RoutineName, 'RunUnresolved') and
      (lStatement.Range.StartLine = lTarget.Line) and
      (lStatement.Range.StartColumn = lTarget.Column) then
    begin
      Inc(lStatementCount);
      Assert.AreEqual('skipped', lStatement.Status,
        'RunUnresolved final statement status');
      Assert.AreEqual('selector-type-not-resolved', lStatement.Reason,
        'RunUnresolved final selector refusal');
      Assert.AreEqual(0, Integer(Length(lStatement.Edits)),
        'RunUnresolved final statement edits');
      Assert.AreEqual(0, Integer(Length(lStatement.Temps)),
        'RunUnresolved final statement temps');
      for lEdit in lPlan.Edits do
        Assert.AreNotEqual(lStatement.StatementId, lEdit.StatementId,
          'RunUnresolved must have no plan edit');
    end;
  Assert.AreEqual(1, lStatementCount,
    'RunUnresolved must identify exactly one final source statement');
end;

procedure TWithBinderTests.NestedIndexedSelectorPreservesBoundTypeDeclaringUnit;
var
  lADeclaredId: string;
  lAMaskTypeCount: Integer;
  lAValueCount: Integer;
  lBDeclaredId: string;
  lBMaskTypeCount: Integer;
  lBAltValueCount: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticApiOptions;
  lRepeatedCount: Integer;
begin
  lADeclaredId := '';
  lBDeclaredId := '';
  lOptions := Default(TDelphiSemanticApiOptions);
  lOptions.ProjectFileName := FixturePath('WithBinder',
    'NestedParentDefaultPointerWith.dproj');
  lFacts := TDelphiSemanticRemoveWithCompatibilityApi.BuildProjectWithBindingFacts(lOptions);
  lAMaskTypeCount := 0;
  lAValueCount := 0;
  lBMaskTypeCount := 0;
  lBAltValueCount := 0;
  for lModel in lFacts.UnitModels do
  begin
    for lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.Name, 'TMaskType') and
        SameText(lDeclaration.Kind, 'type') then
      begin
        if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerA') then
          Inc(lAMaskTypeCount)
        else if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerB') then
          Inc(lBMaskTypeCount);
      end;
    for lMember in lModel.Members do
    begin
      if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerA') and
        SameText(lMember.OwnerName, 'TMaskEntry') and
        SameText(lMember.Name, 'Value') then
        Inc(lAValueCount);
      if SameText(lModel.UnitName, 'NestedParentBoundTypeOwnerB') and
        SameText(lMember.OwnerName, 'TAltEntry') and
        SameText(lMember.Name, 'AltValue') then
        Inc(lBAltValueCount);
    end;
  end;
  Assert.AreEqual(1, lAMaskTypeCount,
    'Imported owner A must declare one TMaskType');
  Assert.AreEqual(1, lBMaskTypeCount,
    'Caller B must declare a colliding local TMaskType');
  Assert.AreEqual(1, lAValueCount,
    'Value must belong to A.TMaskEntry');
  Assert.AreEqual(1, lBAltValueCount,
    'AltValue must belong to B.TAltEntry');

  lBindingCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(ExtractFileName(lBinding.FileName),
      'NestedParentBoundTypeOwnerB.pas') and
      SameText(lBinding.UnitName, 'NestedParentBoundTypeOwnerB') and
      SameText(lBinding.RoutineName, 'RunImportedBoundType') and
      SameText(lBinding.SelectorText, 'Maske[0]^') then
    begin
      Inc(lBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Imported nested selector must retain outer D');
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status,
        'Imported A.Maske selector status');
      Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName,
        'A.TDatFile.Maske must retain A.TMaskType despite caller B homonym');
      Assert.AreEqual('NestedParentBoundTypeOwnerA',
        lBinding.Selectors[1].TypeIdentity.UnitName);
      Assert.AreEqual('NestedParentBoundTypeOwnerA.pas',
        ExtractFileName(lBinding.Selectors[1].TypeIdentity.SourceRange.FileName));
      lADeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
      Assert.IsTrue(lADeclaredId <> '');
      Assert.IsTrue(HasReference(lBinding, 'Value', 'member'),
        'Value must bind to A.TMaskEntry member');
      Assert.AreEqual('TMaskEntry', ReceiverOf(lBinding, 'Value', 'member'),
        'Value receiver must retain A.TMaskEntry type');
    end;
  Assert.AreEqual(1, lBindingCount,
    'Expected one nested imported A.Maske binding in B');

  lRepeatedCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'NestedParentBoundTypeOwnerB') and
      (SameText(lBinding.RoutineName, 'RunLocalThenImported') or
      SameText(lBinding.RoutineName, 'RunImportedThenLocal')) and
      SameText(lBinding.SelectorText, 'Maske[0]^') then
    begin
      Inc(lRepeatedCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Repeated two-owner selector stack');
      if SameText(lBinding.Selectors[0].SelectorText, 'D') then
      begin
        Assert.AreEqual('TMaskEntry', lBinding.Selectors[1].TypeName,
          'Imported A receiver must retain A type in either order');
        Assert.AreEqual('NestedParentBoundTypeOwnerA',
          lBinding.Selectors[1].TypeIdentity.UnitName);
        Assert.IsTrue(HasReference(lBinding, 'Value', 'member'),
          'Imported A receiver must bind A.Value in either order');
      end else if SameText(lBinding.Selectors[0].SelectorText, 'L') then
      begin
        Assert.AreEqual('TAltEntry', lBinding.Selectors[1].TypeName,
          'Local B receiver must retain B type in either order');
        Assert.AreEqual('NestedParentBoundTypeOwnerB',
          lBinding.Selectors[1].TypeIdentity.UnitName);
        lBDeclaredId := lBinding.Selectors[1].TypeIdentity.DeclaredId.Value;
        Assert.IsTrue(lBDeclaredId <> '');
        Assert.IsTrue(HasReference(lBinding, 'AltValue', 'member'),
          'Local B receiver must bind B.AltValue in either order');
      end else
        Assert.Fail('Unexpected outer receiver in repeated two-owner case.');
    end;
  Assert.AreEqual(4, lRepeatedCount,
    'Both receiver orders must produce two distinct inner bindings');
  Assert.IsTrue((lADeclaredId <> '') and (lBDeclaredId <> '') and
    (lADeclaredId <> lBDeclaredId),
    'Same-name owner types in imported and caller units need distinct declarations.');
end;

procedure TWithBinderTests.HiddenCompleteReceiverIgnoresUnrelatedDiagnostics;
var
  i: Integer;
  lAliasDetails: string;
  lBinding: TDelphiSemanticWithBinding;
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarationFileName: string;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lDiagnosticDetails: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lHiddenOwnerLine: Integer;
  lIdentityDetails: string;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := LoadReceiverSafetyModels;
  lAliasDetails := '';
  lDiagnosticDetails := '';
  lHiddenOwnerLine := 0;
  Assert.AreEqual(1, Integer(Length(lModels[3].InterfaceUses)),
    'Caller imports only the intermediate owner');
  Assert.IsTrue(SameText(lModels[3].InterfaceUses[0], 'ReceiverSafetyOwner'),
    'Caller import must be the intermediate owner');
  for i := 0 to 3 do
    for lDeclaration in lModels[i].Declarations do
    begin
      lDeclarationFileName := lDeclaration.FileName;
      if lDeclarationFileName = '' then
        lDeclarationFileName := lModels[i].FileName;
      if (i = 0) and SameText(lDeclaration.Name, 'THiddenEntry') and
        SameText(lDeclaration.Kind, 'type') then
        lHiddenOwnerLine := lDeclaration.Line;
      if ((i = 0) and SameText(lDeclaration.Name, 'PHiddenEntry')) or
        ((i = 1) and SameText(lDeclaration.Name, 'TAliasPointer')) then
        lAliasDetails := lAliasDetails + Format('%s.%s=%s@%s:%d; ',
          [lModels[i].UnitName, lDeclaration.Name, lDeclaration.TypeName,
          ExtractFileName(lDeclarationFileName), lDeclaration.Line]);
      if ((i = 0) and SameText(lDeclaration.Name, 'TUnrelated')) or
        ((i = 2) and SameText(lDeclaration.Name, 'TOther')) or
        ((i = 3) and SameText(lDeclaration.Name, 'THiddenEntry')) then
      begin
        Assert.AreEqual('type', lDeclaration.Kind,
          lModels[i].UnitName + '.' + lDeclaration.Name + ' diagnostic owner kind');
        Assert.AreEqual('record', lDeclaration.TypeName,
          lModels[i].UnitName + '.' + lDeclaration.Name + ' diagnostic owner type');
        lDiagnosticDetails := lDiagnosticDetails + Format('%s.%s %s/%s@%s:%d; ',
          [lModels[i].UnitName, lDeclaration.Name, lDeclaration.Kind,
          lDeclaration.TypeName, ExtractFileName(lDeclarationFileName),
          lDeclaration.Line]);
        lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
        lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
        lDiagnostic.FileName := lModels[i].FileName;
        lDiagnostic.Line := lDeclaration.Line;
        SetLength(lModels[i].Diagnostics, Length(lModels[i].Diagnostics) + 1);
        lModels[i].Diagnostics[High(lModels[i].Diagnostics)] := lDiagnostic;
      end;
    end;
  Assert.IsTrue(lHiddenOwnerLine > 0, 'Hidden receiver declaration must have a line');
  Assert.AreEqual(1, Integer(Length(lModels[0].Diagnostics)),
    'Hidden unit has one unrelated diagnostic');
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)),
    'Intermediate owner has one unrelated diagnostic');
  Assert.AreEqual(1, Integer(Length(lModels[3].Diagnostics)),
    'Caller homonym has one unrelated diagnostic');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
      SameText(lBinding.SelectorText, 'Item^') then
    begin
      Inc(lCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)),
        'Nested selector keeps its parent');
      lIdentityDetails := Format(
        'parent=%s.%s id=%s source=%s:%d; receiver=%s.%s id=%s source=%s:%d; aliases=%s; diagnostics=%s',
        [lBinding.Selectors[0].TypeIdentity.UnitName,
        lBinding.Selectors[0].TypeIdentity.Name,
        lBinding.Selectors[0].TypeIdentity.DeclaredId.Value,
        ExtractFileName(lBinding.Selectors[0].TypeIdentity.SourceRange.FileName),
        lBinding.Selectors[0].TypeIdentity.SourceRange.Line,
        lBinding.Selectors[1].TypeIdentity.UnitName,
        lBinding.Selectors[1].TypeIdentity.Name,
        lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        ExtractFileName(lBinding.Selectors[1].TypeIdentity.SourceRange.FileName),
        lBinding.Selectors[1].TypeIdentity.SourceRange.Line,
        lAliasDetails, lDiagnosticDetails]);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('THiddenEntry', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('ReceiverSafetyOwner',
        lBinding.Selectors[0].TypeIdentity.UnitName, lIdentityDetails);
      Assert.AreEqual('ReceiverSafetyHidden',
        lBinding.Selectors[1].TypeIdentity.UnitName, lIdentityDetails);
      Assert.AreEqual('THiddenEntry',
        lBinding.Selectors[1].TypeIdentity.Name, lIdentityDetails);
      Assert.AreEqual(lHiddenOwnerLine,
        lBinding.Selectors[1].TypeIdentity.SourceRange.Line, lIdentityDetails);
      Assert.IsTrue(SameText(lModels[0].FileName,
        lBinding.Selectors[1].TypeIdentity.SourceRange.FileName), lIdentityDetails);
      Assert.IsNotEmpty(lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        lIdentityDetails);
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Complete hidden receiver must ignore unrelated diagnostics. ' +
        lIdentityDetails);
      Assert.AreNotEqual('MEMBERS_UNVERIFIED', lBinding.SkipReason,
        'No hidden owner has unverified members');
    end;
  Assert.AreEqual(1, lCount, 'Expected one nested hidden receiver');
end;

procedure TWithBinderTests.AmbiguousFinalReceiverTypeFailsClosed;
var
  i: Integer;
  j: Integer;
  lBinding: TDelphiSemanticWithBinding;
  lBindingCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lResultCount: Integer;
  lTemplate: TDelphiSemanticDeclaration;
  lTemplateFound: Boolean;
  lValueCount: Integer;
  lWithCount: Integer;
begin
  lModels := LoadReceiverSafetyModels;
  lTemplate := Default(TDelphiSemanticDeclaration);
  lTemplateFound := False;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
    begin
      Assert.IsFalse(lTemplateFound, 'Expected one parsed hidden record type');
      lTemplate := lDeclaration;
      lTemplateFound := True;
    end;
  Assert.IsTrue(lTemplateFound, 'Hidden record type must come from the parsed fixture');
  Assert.AreEqual('record', lTemplate.TypeName);
  Assert.AreEqual('unit', lTemplate.ScopeKind);
  Assert.AreEqual('interface', lTemplate.SectionKind);
  Assert.AreEqual(LowerCase(lModels[0].UnitName), lTemplate.OwnerScopeId);
  Assert.IsNotEmpty(lTemplate.SymbolId);
  for i := 0 to 1 do
  begin
    j := Length(lModels[0].Declarations);
    SetLength(lModels[0].Declarations, j + 1);
    lModels[0].Declarations[j] := lTemplate;
    lModels[0].Declarations[j].Name := 'TResult';
    lModels[0].Declarations[j].Line := lTemplate.Line + 20 + i;
    lModels[0].Declarations[j].Offset := lTemplate.Offset + 200 + i * 10;
    lModels[0].Declarations[j].EndOffset := lTemplate.EndOffset + 200 + i * 10;
    lModels[0].Declarations[j].SymbolId := lTemplate.SymbolId + ':result-' + IntToStr(i);
  end;
  lResultCount := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'TResult') and
      SameText(lDeclaration.ScopeKind, 'unit') and
      SameText(lDeclaration.SectionKind, 'interface') then
      Inc(lResultCount);
  Assert.AreEqual(2, lResultCount,
    'Two exported declarations share the final qualified type name');
  Assert.AreNotEqual(lModels[0].Declarations[High(lModels[0].Declarations) - 1].SymbolId,
    lModels[0].Declarations[High(lModels[0].Declarations)].SymbolId);
  lValueCount := 0;
  for i := 0 to High(lModels[0].Members) do
    if SameText(lModels[0].Members[i].OwnerName, 'THiddenEntry') and
      SameText(lModels[0].Members[i].Name, 'Value') then
    begin
      Inc(lValueCount);
      lModels[0].Members[i].TypeName := 'TResult';
    end;
  Assert.AreEqual(1, lValueCount, 'Mutated member must be the parsed hidden field');
  lWithCount := 0;
  for i := 0 to High(lModels[3].WithStatements) do
    if SameText(lModels[3].WithStatements[i].SelectorText, 'Item^') then
    begin
      Inc(lWithCount);
      lModels[3].WithStatements[i].SelectorText := 'Item^.Value';
    end;
  Assert.AreEqual(1, lWithCount, 'Mutated selector must be the parsed nested with');
  for i := 0 to 3 do
    for lDeclaration in lModels[i].Declarations do
      if ((i = 0) and SameText(lDeclaration.Name, 'TUnrelated')) or
        ((i = 2) and SameText(lDeclaration.Name, 'TOther')) or
        ((i = 3) and SameText(lDeclaration.Name, 'THiddenEntry')) then
      begin
        Assert.AreEqual('type', lDeclaration.Kind);
        Assert.AreEqual('record', lDeclaration.TypeName);
        lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
        lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
        lDiagnostic.FileName := lModels[i].FileName;
        lDiagnostic.Line := lDeclaration.Line;
        j := Length(lModels[i].Diagnostics);
        SetLength(lModels[i].Diagnostics, j + 1);
        lModels[i].Diagnostics[j] := lDiagnostic;
      end;
  Assert.AreEqual(1, Integer(Length(lModels[0].Diagnostics)));
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)));
  Assert.AreEqual(1, Integer(Length(lModels[3].Diagnostics)));
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lBindingCount := 0;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
      SameText(lBinding.SelectorText, 'Item^.Value') then
    begin
      Inc(lBindingCount);
      Assert.AreEqual(2, Integer(Length(lBinding.Selectors)));
      Assert.AreEqual('ReceiverSafetyOwner',
        lBinding.Selectors[0].TypeIdentity.UnitName);
      Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
      Assert.AreEqual('TResult', lBinding.Selectors[1].TypeName);
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.UnitName,
        'Ambiguous exported final type must not acquire a unit identity');
      Assert.AreEqual('', lBinding.Selectors[1].TypeIdentity.DeclaredId.Value,
        'Ambiguous exported final type must not acquire one declared ID');
      Assert.AreEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Ambiguous final receiver must refuse member-safety lineage');
    end;
  Assert.AreEqual(1, lBindingCount, 'Expected one mutated nested receiver');
end;

procedure TWithBinderTests.HiddenReceiverExactOwnerDiagnosticsRefuse;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOwnerLine: Integer;
  lReason: string;
begin
  lModels := LoadReceiverSafetyModels;
  lOwnerLine := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
      lOwnerLine := lDeclaration.Line;
  Assert.IsTrue(lOwnerLine > 0, 'Hidden receiver declaration must be source backed');
  for lReason in ['MEMBERS_INCOMPLETE', 'MEMBERS_UNVERIFIED'] do
  begin
    lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
    lDiagnostic.Code := lReason;
    lDiagnostic.FileName := lModels[0].FileName;
    if SameText(lReason, 'MEMBERS_INCOMPLETE') then
      lDiagnostic.Line := lOwnerLine;
    lModels[0].Diagnostics := [lDiagnostic];
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'ReceiverSafetyCaller') and
        SameText(lBinding.SelectorText, 'Item^') then
      begin
        lFound := True;
        Assert.AreEqual('resolved', lBinding.Selectors[1].Status);
        Assert.AreEqual(lReason, lBinding.SkipReason,
          'Exact hidden owner diagnostic must refuse the binding');
      end;
    Assert.IsTrue(lFound, 'Expected one nested hidden receiver');
  end;
end;

procedure TWithBinderTests.BareImportedReceiverUsesActualOwnerForSafety;
var
  lBinding: TDelphiSemanticWithBinding;
  lDeclaration: TDelphiSemanticDeclaration;
  lDiagnostic: TDelphiSemanticModelDiagnostic;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOwnerLine: Integer;
  lReason: string;
begin
  lModels := LoadBareReceiverSafetyModels;
  Assert.AreEqual(1, Integer(Length(lModels[2].InterfaceUses)),
    'Caller imports only the variable owner');
  Assert.IsTrue(SameText(lModels[2].InterfaceUses[0], 'ReceiverSafetyBareOwner'));
  lOwnerLine := 0;
  for lDeclaration in lModels[0].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
      lOwnerLine := lDeclaration.Line;
  Assert.IsTrue(lOwnerLine > 0, 'Hidden receiver declaration must be source backed');
  for lReason in ['MEMBERS_INCOMPLETE', 'MEMBERS_UNVERIFIED'] do
  begin
    lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
    lDiagnostic.Code := lReason;
    lDiagnostic.FileName := lModels[0].FileName;
    if SameText(lReason, 'MEMBERS_INCOMPLETE') then
      lDiagnostic.Line := lOwnerLine;
    lModels[0].Diagnostics := [lDiagnostic];
    lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
    lFound := False;
    for lBinding in lFacts.Bindings do
      if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
        SameText(lBinding.SelectorText, 'G') then
      begin
        lFound := True;
        Assert.AreEqual('resolved', lBinding.Selectors[0].Status);
        Assert.AreEqual('THiddenEntry', lBinding.Selectors[0].TypeName);
        Assert.AreEqual(lReason, lBinding.SkipReason,
          'Bare imported receiver must refuse exact hidden owner diagnostic');
      end;
    Assert.IsTrue(lFound, 'Expected bare imported G binding');
  end;
  lModels[0].Diagnostics := nil;
  for lDeclaration in lModels[2].Declarations do
    if SameText(lDeclaration.Name, 'THiddenEntry') and
      SameText(lDeclaration.Kind, 'type') then
    begin
      lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
      lDiagnostic.Code := 'MEMBERS_INCOMPLETE';
      lDiagnostic.FileName := lModels[2].FileName;
      lDiagnostic.Line := lDeclaration.Line;
      lModels[2].Diagnostics := [lDiagnostic];
    end;
  Assert.AreEqual(1, Integer(Length(lModels[2].Diagnostics)),
    'Caller homonym diagnostic must be source backed');
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
      SameText(lBinding.SelectorText, 'G') then
    begin
      lFound := True;
      Assert.AreNotEqual('MEMBERS_INCOMPLETE', lBinding.SkipReason,
        'Caller homonym diagnostic cannot refuse imported G');
    end;
  Assert.IsTrue(lFound, 'Expected bare imported G binding');
end;

procedure TWithBinderTests.BareImportedReceiverWithoutVisibleOwnerIsRefused;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFound: Boolean;
  lModels: TArray<TDelphiSemanticUnitModel>;
begin
  lModels := LoadBareReceiverSafetyModels;
  lModels[2].InterfaceUses := nil;
  Assert.AreEqual(0, Integer(Length(lModels[2].InterfaceUses)));
  lFacts := TDelphiSemanticWithBinder.BindProject('', nil, lModels);
  lFound := False;
  for lBinding in lFacts.Bindings do
    if SameText(lBinding.UnitName, 'ReceiverSafetyBareCaller') and
      SameText(lBinding.SelectorText, 'G') then
    begin
      lFound := True;
      Assert.AreEqual('unresolved', lBinding.Selectors[0].Status,
        'Indexed G without a visible declaring unit must not bind');
      Assert.AreEqual('SELECTOR_TYPE_NOT_RESOLVED',
        lBinding.Selectors[0].ReasonCode);
      Assert.AreNotEqual('', lBinding.SkipReason,
        'Missing receiver provenance must refuse the binding without diagnostics');
    end;
  Assert.IsTrue(lFound, 'Expected bare imported G binding');
end;

initialization
  TDUnitX.RegisterTestFixture(TWithBinderTests);

end.
