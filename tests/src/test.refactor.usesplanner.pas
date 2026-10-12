unit Test.Refactor.UsesPlanner;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectSession, DelphiSemantics.Refactor.Binding,
  DelphiSemantics.Refactor.Plan, DelphiSemantics.Refactor.UsesPlanner,
  DelphiSemantics.Snapshot, DelphiSemantics.Snapshot.ContextEvidence;

type
  [TestFixture]
  [Category('RefactoringLightUses')]
  TRefactoringUsesTests = class
  private
    function NewProjectRoot: string;
    procedure AssertRetainedLinkProperty(const aContext: TDelphiSemanticContextEvidenceExtension;
      const aName, aValue: string);
    function ImportReferenceModels: TArray<TDelphiSemanticUnitModel>;
    function ModelEvidence(const aSnapshot: TDelphiProjectSnapshot;
      const aFileName: string): TDelphiSemanticContextModelEvidence;
    procedure CreateBoundContext(const aRoot, aConsumerText, aLeafText: string;
      const aScoped: Boolean; var aSession: TDelphiSemanticProjectSession;
      var aSnapshot: TDelphiProjectSnapshot;
      var aBinding: TDelphiSemanticBoundPlanResult;
      var aConsumerFileName: string);
    procedure CreateBoundContextForOperation(const aRoot, aConsumerText,
      aLeafText: string; const aScoped: Boolean; const aOperationIdentity: string;
      const aNoChange: Boolean; var aSession: TDelphiSemanticProjectSession;
      var aSnapshot: TDelphiProjectSnapshot;
      var aBinding: TDelphiSemanticBoundPlanResult;
      var aConsumerFileName: string; const aProjectProperties: string = '');
    procedure AssertRemovalClassification(const aConsumerText, aLeafText: string;
      const aScoped: Boolean; const aExpectedClassification: TDelphiSemanticUsesClassification;
      const aExpectedStatus: TSemanticPlanStatus);
    procedure AssertAddClassification(const aConsumerText, aProviderText,
      aUnitName, aIdentifier, aReasonFragment: string;
      const aExpectedClassification: TDelphiSemanticUsesClassification);
  public
    [Test]
    procedure RetainsOrderedImportsAndLifecycleFacts;
    [Test]
    procedure RetainsExecutableRootAndOrderedImports;
    [Test]
    [TestCase('Package list', 'DCC_UsePackage,rtl;vcl')]
    [TestCase('Packages enabled', 'UsePackages,true')]
    [TestCase('Enabled packages', 'DCC_EnabledPackages,true')]
    [TestCase('Effective package list', '_UsePackage,rtl;vcl')]
    [TestCase('Compiler switches', 'DCC_AdditionalSwitches,-DFIRST')]
    procedure RetainsIndependentCompilerLinkEvidence(const aName, aValue: string);
    [Test]
    procedure RetainsIndependentReferenceEvidence;
    [Test]
    procedure ResolvesReferencesUnderAlternateImports;
    [Test]
    procedure ComparesKnownBindingsUnderAlternateImports;
    [Test]
    [TestCase('Later unknown reference', 'unknown')]
    [TestCase('Missing snapshot', 'snapshot')]
    [TestCase('Empty references', 'empty')]
    procedure RejectsIncompleteBindingComparison(const aCase: string);
    [Test]
    procedure ResolvesQualifiedImportsWithoutUnqualifiedFallback;
    [Test]
    [TestCase('Compound qualifier', 'Gone.Leaf.LeafValue')]
    [TestCase('Comment before name', 'Gone.{comment}LeafValue')]
    [TestCase('Expression receiver', '(Leaf).LeafValue')]
    procedure RefusesUnsupportedQualifiedReceiver(const aSource: string);
    [Test]
    procedure DetectsInitializationOrderChangedByImportMove;
    [Test]
    [TestCase('Missing unit', 'missing')]
    [TestCase('Unknown facts', 'unknown')]
    [TestCase('Cycle', 'cycle')]
    [TestCase('Duplicate unit', 'duplicate')]
    [TestCase('Missing roots', 'roots')]
    procedure RefusesIncompleteUnitOrder(const aCase: string);
    [Test]
    procedure PersistsOrderedDependencyFacts;
    [Test]
    procedure RefusesMalformedPersistedDependencyFacts;
    [Test]
    procedure RefusesNonBooleanDependencyEvidence;
    [Test]
    procedure RefusesNonObjectDependencyEvidence;
    [Test]
    procedure PlansRemovalOfAnEmptyImplementationOnlyLeafImport;
    [Test]
    procedure BlocksInitializationSensitiveLeafImport;
    [Test]
    procedure BlocksInterfaceVisibleImport;
    [Test]
    procedure BlocksConditionalUsesClause;
    [Test]
    procedure UnverifiedProviderConditionCannotAuthorizeImportRemoval;
    [Test]
    procedure BlocksSubsetAnalysisForProjectWideImportRemoval;
    [Test]
    procedure BlocksLeafWithTransitiveOrderUnknown;
    [Test]
    procedure BlocksHelperOrOperatorProvider;
    [Test]
    procedure ReportsMissingImplementationImportAsNoOp;
    [Test]
    procedure SuggestsUniqueAndAmbiguousExplicitImportCandidates;
    [Test]
    [TestCase('Default linking', 'default')]
    [TestCase('Disabled packages', 'disabled')]
    [TestCase('Inactive package list', 'inactive-list')]
    procedure ReportsInterfaceImportMoveAsCandidateOnly(const aLinkMode: string);

    [Test]

    [TestCase('Active conditional clause', 'conditional')]

    [TestCase('Real class helper provider', 'helper')]

    [TestCase('Real record operator provider', 'operator')]

    procedure BlocksInterfaceImportMoveForConditionalOrLookupProvider(const aCase: string);
    [Test]
    [TestCase('Runtime packages', 'UsePackages,true,uses.runtime-packages-unsupported')]
    [TestCase('Enabled packages', 'DCC_EnabledPackages,true,uses.runtime-packages-unsupported')]
    [TestCase('Effective package list', '_UsePackage,rtl,uses.runtime-packages-unsupported')]
    [TestCase('Raw switches', 'DCC_AdditionalSwitches,-LUrtl,uses.compiler-switches-unsupported')]
    [TestCase('Unknown package mode', 'UsePackages,perhaps,uses.compiler-link-context-unknown')]
    procedure BlocksMoveWithUnsupportedCompilerLinkSettings(const aName, aValue, aReason: string);
    [Test]
    procedure BlocksMoveWithUnresolvedUnrelatedReference;

    [Test]

    procedure BlocksMoveWithUnresolvedIntrinsicReference;
    [Test]
    procedure BlocksInterfaceDefaultReferenceMove;
    [Test]
    [TestCase('Missing reachable unit', 'MissingUnit')]
    [TestCase('Reachable dependency cycle', 'QuietLeaf')]
    procedure BlocksMoveWithIncompleteReachableOrder(const aImport: string);
    [Test]
    procedure PlansExplicitlySelectedUniqueImport;
    [Test]
    procedure BlocksAmbiguousExplicitImportSelection;
    [Test]
    procedure BlocksQualifiedReferenceImportRequest;
    [Test]
    procedure BlocksProviderWithoutCoProducedSource;
    [Test]
    procedure BlocksConditionalExplicitImportRequest;
    [Test]
    procedure BlocksInitializationSensitiveExplicitImportProvider;
    [Test]
    procedure BlocksHelperExplicitImportProvider;
    [Test]
    procedure BlocksUnknownExplicitImportReference;
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
  Winapi.Windows,
  DelphiSemantics.Model.Json, DelphiSemantics.ProjectContext,
  DelphiSemantics.Refactor.UnitOrder, DelphiSemantics.Snapshot.Builder, DelphiSemantics.WithBinding;

function TRefactoringUsesTests.ModelEvidence(const aSnapshot: TDelphiProjectSnapshot;
  const aFileName: string): TDelphiSemanticContextModelEvidence;
var
  lExtension: TObject;
  lEvidence: TDelphiSemanticContextEvidenceExtension;
  i: Integer;
begin
  Result := Default(TDelphiSemanticContextModelEvidence);
  Assert.IsTrue(aSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
    lExtension));
  lEvidence := lExtension as TDelphiSemanticContextEvidenceExtension;
  for i := 0 to lEvidence.ModelCount - 1 do
    if SameText(lEvidence.ModelEvidence[i].SourceFileName, aFileName) then
      Exit(lEvidence.ModelEvidence[i]);
  Assert.Fail('Expected co-produced model evidence for ' + aFileName);
end;

procedure TRefactoringUsesTests.RetainsOrderedImportsAndLifecycleFacts;
var
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lEvidence: TDelphiSemanticContextModelEvidence;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContext(lRoot, 'unit UsesConsumer;' + sLineBreak +
      'interface' + sLineBreak + 'uses ProviderBeta, ProviderAlpha;' + sLineBreak +
      'implementation' + sLineBreak + 'uses QuietLeaf;' + sLineBreak +
      'initialization' + sLineBreak + 'finalization' + sLineBreak + 'end.',
      'unit QuietLeaf; interface implementation end.', False,
      lSession, lSnapshot, lBinding, lConsumerFileName);
    lEvidence := ModelEvidence(lSnapshot, lConsumerFileName);
    Assert.IsTrue(lEvidence.DependencyFacts.Known, 'Ordered facts require the original successful AST');
    Assert.AreEqual(2, Integer(Length(lEvidence.DependencyFacts.InterfaceImports)));
    Assert.AreEqual('ProviderBeta', lEvidence.DependencyFacts.InterfaceImports[0]);
    Assert.AreEqual('ProviderAlpha', lEvidence.DependencyFacts.InterfaceImports[1]);
    Assert.AreEqual(1, Integer(Length(lEvidence.DependencyFacts.ImplementationImports)));
    Assert.AreEqual('QuietLeaf', lEvidence.DependencyFacts.ImplementationImports[0]);
    Assert.IsTrue(lEvidence.DependencyFacts.HasInitialization);
    Assert.IsTrue(lEvidence.DependencyFacts.HasFinalization);
    lEvidence.DependencyFacts.InterfaceImports[0] := 'CallerMutation';
    lEvidence := ModelEvidence(lSnapshot, lConsumerFileName);
    Assert.AreEqual('ProviderBeta', lEvidence.DependencyFacts.InterfaceImports[0],
      'Snapshot evidence owns its ordered arrays');
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.AssertRetainedLinkProperty(
  const aContext: TDelphiSemanticContextEvidenceExtension;
  const aName, aValue: string);
var
  lProperties: TArray<TDelphiSemanticProperty>;
  i: Integer;
begin
  lProperties := aContext.CompilerLinkProperties;
  for i := 0 to High(lProperties) do
    if SameText(lProperties[i].Name, aName) then
    begin
      Assert.AreEqual(aValue, lProperties[i].Value);
      lProperties[i].Value := 'CallerMutation';
      Assert.AreEqual(aValue, aContext.CompilerLinkProperties[i].Value);
      Exit;
    end;
  Assert.Fail('Captured compiler-link property missing: ' + aName);
end;

procedure TRefactoringUsesTests.RetainsIndependentCompilerLinkEvidence(
  const aName, aValue: string);
var
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lExtension: TObject;
  lContext: TDelphiSemanticContextEvidenceExtension;
begin
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(NewProjectRoot,
      'unit UsesConsumer; interface implementation end.',
      'unit QuietLeaf; interface implementation end.', False,
      'uses.analyze-interface-import-move', True, lSession, lSnapshot,
      lBinding, lConsumerFileName, '<' + aName + '>' + aValue + '</' + aName + '>');
    FreeAndNil(lSession);
    Assert.IsTrue(lSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
      lExtension));
    lContext := lExtension as TDelphiSemanticContextEvidenceExtension;
    AssertRetainedLinkProperty(lContext, aName, aValue);
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.RetainsExecutableRootAndOrderedImports;
var
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lExtension: TObject;
  lContext: TDelphiSemanticContextEvidenceExtension;
  lEvidence: TDelphiSemanticContextModelEvidence;
begin
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContext(NewProjectRoot, 'unit UsesConsumer; interface implementation end.',
      'unit QuietLeaf; interface implementation end.', False,
      lSession, lSnapshot, lBinding, lConsumerFileName);
    lSession.Free;
    lSession := nil;
    Assert.IsTrue(lSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
      lExtension));
    lContext := lExtension as TDelphiSemanticContextEvidenceExtension;
    Assert.AreEqual(TPath.Combine(TPath.GetDirectoryName(lConsumerFileName), 'UsesProject.dpr'),
      lContext.MainSourceFileName,
      'The executable root must come from the captured project context');
    lEvidence := ModelEvidence(lSnapshot, lContext.MainSourceFileName);
    Assert.IsTrue(lEvidence.ModelSucceeded);
    Assert.IsTrue(lEvidence.DependencyFacts.Known);
    Assert.AreEqual('UsesConsumer,ProviderAlpha,ProviderBeta,QuietLeaf',
      string.Join(',', lEvidence.DependencyFacts.RootImports));
    lEvidence.DependencyFacts.RootImports[0] := 'CallerMutation';
    lEvidence := ModelEvidence(lSnapshot, lContext.MainSourceFileName);
    Assert.AreEqual('UsesConsumer', lEvidence.DependencyFacts.RootImports[0]);
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.RetainsIndependentReferenceEvidence;
var
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lEvidence: TDelphiSemanticContextModelEvidence;
  lReferenceIndex: Integer;
  i: Integer;
begin
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContext(NewProjectRoot, 'unit UsesConsumer;' + sLineBreak +
      'interface uses QuietLeaf;' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak +
      'begin Result := LeafValue; end;' + sLineBreak + 'end.',
      'unit QuietLeaf; interface const LeafValue = 7; implementation end.',
      False, lSession, lSnapshot, lBinding, lConsumerFileName);
    lSession.Free;
    lSession := nil;
    lEvidence := ModelEvidence(lSnapshot, lConsumerFileName);
    Assert.IsTrue(lEvidence.ReferenceExtractionIncluded);
    lReferenceIndex := -1;
    for i := 0 to High(lEvidence.References) do
      if lEvidence.References[i].Name = 'LeafValue' then
        lReferenceIndex := i;
    Assert.IsTrue(lReferenceIndex >= 0, 'Original reference evidence must survive session disposal');
    Assert.AreEqual('implementation', lEvidence.References[lReferenceIndex].SectionKind);
    Assert.IsTrue(lEvidence.References[lReferenceIndex].Offset > 0);
    Assert.IsTrue(lEvidence.References[lReferenceIndex].RoutineScopeId <> '');
    lEvidence.References[lReferenceIndex].Name := 'CallerMutation';
    lEvidence := ModelEvidence(lSnapshot, lConsumerFileName);
    Assert.AreEqual('LeafValue', lEvidence.References[lReferenceIndex].Name,
      'Snapshot evidence must own its reference array');
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

function TRefactoringUsesTests.ImportReferenceModels: TArray<TDelphiSemanticUnitModel>;
begin
  SetLength(Result, 2);
  Result[0].UnitName := 'Consumer';
  Result[0].FileName := 'Consumer.pas';
  Result[0].InterfaceUses := ['Leaf'];
  SetLength(Result[0].References, 2);
  Result[0].References[0].Name := 'LeafValue';
  Result[0].References[0].SectionKind := 'interface';
  Result[0].References[1].Name := 'LeafValue';
  Result[0].References[1].SectionKind := 'implementation';
  Result[1].UnitName := 'Leaf';
  Result[1].FileName := 'Leaf.pas';
  SetLength(Result[1].Declarations, 1);
  Result[1].Declarations[0].Name := 'LeafValue';
  Result[1].Declarations[0].Kind := 'const';
  Result[1].Declarations[0].SectionKind := 'interface';
  Result[1].Declarations[0].ScopeKind := 'unit';
  Result[1].Declarations[0].DeclarationRole := 'declaration';
end;

procedure TRefactoringUsesTests.ResolvesReferencesUnderAlternateImports;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lOptions: TDelphiSnapshotBuildOptions;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lTargets: TArray<TSemanticSymbolRef>;
begin
  lModels := ImportReferenceModels;
  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    lTargets := ResolveSnapshotReferenceTargets(lSnapshot, lModels[0]);
    Assert.AreEqual(2, Integer(Length(lTargets)));
    Assert.IsTrue(lTargets[0].SymbolId <> 0);
    Assert.IsTrue(lTargets[1].SymbolId <> 0);
    lModels[0].InterfaceUses := nil;
    lModels[0].ImplementationUses := ['Leaf'];
    lTargets := ResolveSnapshotReferenceTargets(lSnapshot, lModels[0]);
    Assert.AreEqual(0, Integer(lTargets[0].SymbolId), 'Interface binding is lost after move');
    Assert.IsTrue(lTargets[1].SymbolId <> 0, 'Implementation still sees imported constant');
    lModels[0].ImplementationUses := nil;
    lTargets := ResolveSnapshotReferenceTargets(lSnapshot, lModels[0]);
    Assert.AreEqual(0, Integer(lTargets[1].SymbolId), 'Removed import cannot retain stale target');
  finally
    lSnapshot.Free;
  end;
end;

procedure TRefactoringUsesTests.ResolvesQualifiedImportsWithoutUnqualifiedFallback;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lOptions: TDelphiSnapshotBuildOptions;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lTargets: TArray<TSemanticSymbolRef>;
  lUnit: TUnitSnapshot;
begin
  lModels := ImportReferenceModels;
  SetLength(lModels, 3);
  lModels[2] := lModels[1];
  lModels[2].UnitName := 'Other';
  lModels[2].FileName := 'Other.pas';
  lModels[0].InterfaceUses := ['Leaf', 'Other'];
  lModels[0].SourceText := 'Leaf.LeafValue';
  lModels[0].References := [lModels[0].References[1]];
  lModels[0].References[0].Offset := 6;
  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    lTargets := ResolveSnapshotReferenceTargets(lSnapshot, lModels[0]);
    Assert.IsTrue(lTargets[0].SymbolId <> 0, 'Qualifier must select the correct imported unit');
    Assert.IsTrue(lSnapshot.TryFindUnitById(lTargets[0].UnitId, lUnit));
    Assert.AreEqual('Leaf', lSnapshot.TextOf(lUnit.UnitNameId));
    lModels[0].SourceText := 'Gone.LeafValue';
    lTargets := ResolveSnapshotReferenceTargets(lSnapshot, lModels[0]);
    Assert.AreEqual(0, Integer(lTargets[0].SymbolId), 'Unknown receiver cannot fall back');
    lModels[0].InterfaceUses := ['Leaf'];
    lModels[0].SourceText := 'Other.LeafValue';
    lModels[0].References[0].Offset := 7;
    lTargets := ResolveSnapshotReferenceTargets(lSnapshot, lModels[0]);
    Assert.AreEqual(0, Integer(lTargets[0].SymbolId), 'Unimported receiver cannot fall back');
  finally
    lSnapshot.Free;
  end;
end;

procedure TRefactoringUsesTests.RefusesUnsupportedQualifiedReceiver(const aSource: string);
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lOptions: TDelphiSnapshotBuildOptions;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lTargets: TArray<TSemanticSymbolRef>;
begin
  lModels := ImportReferenceModels;
  lModels[0].SourceText := aSource;
  lModels[0].References := [lModels[0].References[1]];
  lModels[0].References[0].Offset := Pos('LeafValue', aSource);
  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    lTargets := ResolveSnapshotReferenceTargets(lSnapshot, lModels[0]);
    Assert.AreEqual(0, Integer(lTargets[0].SymbolId), aSource);
  finally
    lSnapshot.Free;
  end;
end;

procedure TRefactoringUsesTests.ComparesKnownBindingsUnderAlternateImports;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lOptions: TDelphiSnapshotBuildOptions;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lComparison: TDelphiSnapshotImportBindingComparison;
begin
  lModels := ImportReferenceModels;
  SetLength(lModels, 3);
  lModels[2] := lModels[1];
  lModels[2].UnitName := 'Other';
  lModels[2].FileName := 'Other.pas';
  lModels[0].References := [lModels[0].References[1]];
  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    lComparison := CompareSnapshotImportBindings(lSnapshot, lModels[0], [], ['Leaf']);
    Assert.IsTrue(lComparison.Complete);
    Assert.IsTrue(lComparison.Preserved, 'Implementation reference retains the same declaration');
    Assert.AreEqual(1, lComparison.ReferenceCount);
    lComparison := CompareSnapshotImportBindings(lSnapshot, lModels[0], [], ['Other']);
    Assert.IsTrue(lComparison.Complete);
    Assert.IsFalse(lComparison.Preserved, 'A concrete target change cannot be called preserved');
    Assert.AreEqual('uses.reference-binding-changed', lComparison.Reason);
    lComparison := CompareSnapshotImportBindings(lSnapshot, lModels[0], [], []);
    Assert.IsFalse(lComparison.Complete, 'An unresolved target is incomplete evidence');
    Assert.IsFalse(lComparison.Preserved);
    lModels[0].InterfaceUses := nil;
    lComparison := CompareSnapshotImportBindings(lSnapshot, lModels[0], [], []);
    Assert.IsFalse(lComparison.Complete, 'Matching unresolved targets are not proof');
    Assert.IsFalse(lComparison.Preserved);
  finally
    lSnapshot.Free;
  end;
end;

procedure TRefactoringUsesTests.RejectsIncompleteBindingComparison(const aCase: string);
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lSnapshot: TDelphiProjectSnapshot;
  lInputSnapshot: TDelphiProjectSnapshot;
  lOptions: TDelphiSnapshotBuildOptions;
  lMetrics: TDelphiSnapshotBuilderMetrics;
  lComparison: TDelphiSnapshotImportBindingComparison;
begin
  lModels := ImportReferenceModels;
  lModels[0].References[0].SectionKind := 'implementation';
  lModels[0].References[1].Name := 'UnknownValue';
  if aCase = 'empty' then
    lModels[0].References := nil;
  lOptions := Default(TDelphiSnapshotBuildOptions);
  lOptions.WorkerCount := 1;
  lSnapshot := BuildProjectSnapshotFromModels(lModels,
    Default(TDelphiSemanticProjectWithBindingFacts), lOptions, lMetrics);
  try
    lInputSnapshot := lSnapshot;
    if aCase = 'snapshot' then
      lInputSnapshot := nil;
    lComparison := CompareSnapshotImportBindings(lInputSnapshot, lModels[0], [], ['Leaf']);
    Assert.IsFalse(lComparison.Complete, aCase);
    Assert.IsFalse(lComparison.Preserved, aCase);
    Assert.AreEqual('uses.reference-binding-unknown', lComparison.Reason);
    if aCase = 'unknown' then
      Assert.AreEqual(1, lComparison.ReferenceCount, 'Known prefix cannot hide an unknown suffix');
  finally
    lSnapshot.Free;
  end;
end;

procedure TRefactoringUsesTests.PersistsOrderedDependencyFacts;
var
  lModel: TDelphiSemanticUnitModel;
  lRestored: TDelphiSemanticUnitModel;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.DependencyFacts.Known := True;
  lModel.DependencyFacts.InterfaceImports := ['Beta', 'Alpha'];
  lModel.DependencyFacts.ImplementationImports := ['Leaf'];
  lModel.DependencyFacts.RootImports := ['RootB', 'RootA'];
  lModel.DependencyFacts.HasInitialization := True;
  lModel.DependencyFacts.HasFinalization := True;
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(lRestored.DependencyFacts.Known, 'Persistence must retain known ordered facts');
  Assert.AreEqual('Beta', lRestored.DependencyFacts.InterfaceImports[0]);
  Assert.AreEqual('Alpha', lRestored.DependencyFacts.InterfaceImports[1]);
  Assert.AreEqual('Leaf', lRestored.DependencyFacts.ImplementationImports[0]);
  Assert.AreEqual('RootB', lRestored.DependencyFacts.RootImports[0]);
  Assert.AreEqual('RootA', lRestored.DependencyFacts.RootImports[1]);
  Assert.IsTrue(lRestored.DependencyFacts.HasInitialization);
  Assert.IsTrue(lRestored.DependencyFacts.HasFinalization);
  lRestored := JsonToModel('{}');
  Assert.IsFalse(lRestored.DependencyFacts.Known, 'Old cache entries cannot certify dependency facts');
end;
procedure TRefactoringUsesTests.RefusesMalformedPersistedDependencyFacts;
var
  lModel: TDelphiSemanticUnitModel;
  lEntry: string;
begin
  for lEntry in ['42', 'null', 'true', '""', '"   "'] do
  begin
    lModel := JsonToModel('{"DependencyFacts":{"Known":true,' +
      '"InterfaceImports":[' + lEntry + '],"ImplementationImports":[],"RootImports":[],' +
      '"HasInitialization":false,"HasFinalization":false}}');
    Assert.IsFalse(lModel.DependencyFacts.Known,
      'Malformed imports cannot certify a dependency graph: ' + lEntry);
  end;
end;
procedure TRefactoringUsesTests.RefusesNonBooleanDependencyEvidence;
var
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := JsonToModel('{"DependencyFacts":{"Known":"true",' +
    '"InterfaceImports":["Leaf"],"ImplementationImports":[],"RootImports":[],' +
    '"HasInitialization":false,"HasFinalization":false}}');
  Assert.IsFalse(lModel.DependencyFacts.Known, 'String true is not proof of known facts');
  Assert.IsTrue(Length(lModel.DependencyFacts.InterfaceImports) = 0);
end;

procedure TRefactoringUsesTests.RefusesNonObjectDependencyEvidence;
var
  lValue: string;
  lModel: TDelphiSemanticUnitModel;
begin
  for lValue in ['true', '42', '[]', '"facts"', 'null'] do
  begin
    lModel := JsonToModel('{"DependencyFacts":' + lValue + '}');
    Assert.IsFalse(lModel.DependencyFacts.Known, 'Malformed evidence must remain unknown: ' + lValue);
    Assert.IsTrue(Length(lModel.DependencyFacts.InterfaceImports) = 0);
  end;
end;

procedure TRefactoringUsesTests.DetectsInitializationOrderChangedByImportMove;
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lBefore, lAfter: TDelphiSemanticUnitOrderResult;
  i: Integer;
begin
  SetLength(lModels, 3);
  for i := 0 to High(lModels) do
  begin
    lModels[i].Success := True;
    lModels[i].DependencyFacts.Known := True;
  end;
  lModels[0].UnitName := 'Consumer';
  lModels[1].UnitName := 'First';
  lModels[2].UnitName := 'Second';
  lModels[0].DependencyFacts.InterfaceImports := ['First', 'Second'];
  lBefore := TDelphiSemanticUnitOrder.Analyze(lModels, ['Consumer']);
  Assert.IsTrue(lBefore.Known, lBefore.Reason);
  Assert.AreEqual('First,Second,Consumer', string.Join(',', lBefore.InitializationOrder));
  Assert.AreEqual('Consumer,Second,First', string.Join(',', lBefore.FinalizationOrder));
  lModels[0].DependencyFacts.InterfaceImports := ['Second'];
  lModels[0].DependencyFacts.ImplementationImports := ['First'];
  lAfter := TDelphiSemanticUnitOrder.Analyze(lModels, ['Consumer']);
  Assert.IsTrue(lAfter.Known, lAfter.Reason);
  Assert.AreEqual('Second,First,Consumer', string.Join(',', lAfter.InitializationOrder));
  Assert.AreEqual('Consumer,First,Second', string.Join(',', lAfter.FinalizationOrder));
  Assert.AreNotEqual(string.Join(',', lBefore.InitializationOrder),
    string.Join(',', lAfter.InitializationOrder));
end;
procedure TRefactoringUsesTests.RefusesIncompleteUnitOrder(const aCase: string);
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lRoots: TArray<string>;
  lResult: TDelphiSemanticUnitOrderResult;
begin
  SetLength(lModels, 2);
  lModels[0].UnitName := 'Consumer';
  lModels[0].Success := True;
  lModels[0].DependencyFacts.Known := True;
  lModels[0].DependencyFacts.InterfaceImports := ['Leaf'];
  lModels[1].UnitName := 'Leaf';
  lModels[1].Success := True;
  lModels[1].DependencyFacts.Known := True;
  lRoots := ['Consumer'];
  if aCase = 'missing' then
    SetLength(lModels, 1)
  else if aCase = 'unknown' then
    lModels[1].DependencyFacts.Known := False
  else if aCase = 'cycle' then
    lModels[1].DependencyFacts.ImplementationImports := ['Consumer']
  else if aCase = 'duplicate' then
    lModels[1].UnitName := 'CONSUMER'
  else if aCase = 'roots' then
    lRoots := nil;
  lResult := TDelphiSemanticUnitOrder.Analyze(lModels, lRoots);
  Assert.IsFalse(lResult.Known, aCase);
  Assert.AreEqual('uses.order-unresolved', lResult.Reason);
  Assert.AreEqual(0, Integer(Length(lResult.InitializationOrder)));
  Assert.AreEqual(0, Integer(Length(lResult.FinalizationOrder)));
end;
function TRefactoringUsesTests.NewProjectRoot: string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  CreateGUID(lGuid);
  lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]),
    '}', '', [rfReplaceAll]);
  Result := TPath.GetFullPath(TPath.Combine([ExtractFilePath(ParamStr(0)), '..', '.dak',
    'delphiSemanticsTests', 'RefactoringLightUses',
    'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  TDirectory.CreateDirectory(Result);
end;

procedure TRefactoringUsesTests.CreateBoundContext(const aRoot, aConsumerText,
  aLeafText: string; const aScoped: Boolean; var aSession: TDelphiSemanticProjectSession;
  var aSnapshot: TDelphiProjectSnapshot; var aBinding: TDelphiSemanticBoundPlanResult;
  var aConsumerFileName: string);
begin
  CreateBoundContextForOperation(aRoot, aConsumerText, aLeafText, aScoped,
    'uses.remove-implementation-import', True, aSession, aSnapshot, aBinding,
    aConsumerFileName);
end;

procedure TRefactoringUsesTests.CreateBoundContextForOperation(const aRoot,
  aConsumerText, aLeafText: string; const aScoped: Boolean;
  const aOperationIdentity: string; const aNoChange: Boolean;
  var aSession: TDelphiSemanticProjectSession; var aSnapshot: TDelphiProjectSnapshot;
  var aBinding: TDelphiSemanticBoundPlanResult; var aConsumerFileName: string;
  const aProjectProperties: string);
var
  lBindingRequest: TDelphiSemanticPlanBindingRequest;
  lContextEvidence: TDelphiSemanticContextEvidenceExtension;
  lDprojFileName: string;
  lEdit: TSemanticPlanEdit;
  lExtension: TObject;
  lLeafFileName: string;
  lProviderAlphaFileName: string;
  lProviderBetaFileName: string;
  lEndColumn: Integer;
  lEndLine: Integer;
  lEndOffset: Integer;
  i: Integer;
  lLine: Integer;
  lOptions: TDelphiSemanticOptions;
  lOffset: Integer;
  lColumn: Integer;
  lProjectDprFileName: string;
  lSessionResult: TDelphiSemanticProjectSessionResult;
  lSnapshotResult: TDelphiSemanticProjectSnapshotBuildResult;
begin
  aSession := nil;
  aSnapshot := nil;
  aBinding := nil;
  aConsumerFileName := TPath.Combine(aRoot, 'UsesConsumer.pas');
  lLeafFileName := TPath.Combine(aRoot, 'QuietLeaf.pas');
  lProjectDprFileName := TPath.Combine(aRoot, 'UsesProject.dpr');
  lDprojFileName := TPath.Combine(aRoot, 'UsesProject.dproj');
  lProviderAlphaFileName := TPath.Combine(aRoot, 'ProviderAlpha.pas');
  lProviderBetaFileName := TPath.Combine(aRoot, 'ProviderBeta.pas');
  TFile.WriteAllText(aConsumerFileName, aConsumerText, TEncoding.UTF8);
  TFile.WriteAllText(lLeafFileName, aLeafText, TEncoding.UTF8);
  TFile.WriteAllText(lProviderAlphaFileName,
    'unit ProviderAlpha;' + sLineBreak + 'interface' + sLineBreak + 'const' + sLineBreak +
    'AlphaOnlyValue = 1;' + sLineBreak + 'SharedValue = 2;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lProviderBetaFileName,
    'unit ProviderBeta;' + sLineBreak + 'interface' + sLineBreak + 'const' + sLineBreak +
    'BetaOnlyValue = 3;' + sLineBreak + 'SharedValue = 4;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  TFile.WriteAllText(lProjectDprFileName,
    'program UsesProject;' + sLineBreak +
    'uses UsesConsumer in ''UsesConsumer.pas'', ProviderAlpha in ''ProviderAlpha.pas'', ' +
    'ProviderBeta in ''ProviderBeta.pas'', QuietLeaf in ''QuietLeaf.pas'';' + sLineBreak +
    'begin end.', TEncoding.UTF8);
  TFile.WriteAllText(lDprojFileName,
    '<Project xmlns="http://schemas.microsoft.com/developer/msbuild/2003">' +
    '<PropertyGroup><MainSource>UsesProject.dpr</MainSource>' + aProjectProperties +
    '</PropertyGroup>' +
    '<ItemGroup><DCCReference Include="UsesConsumer.pas"/>' +
    '<DCCReference Include="QuietLeaf.pas"/>' +
    '<DCCReference Include="ProviderAlpha.pas"/>' +
    '<DCCReference Include="ProviderBeta.pas"/></ItemGroup></Project>', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := lDprojFileName;
  lOptions.Configuration := 'Debug';
  lOptions.Platform := 'Win64';
  lSessionResult := TDelphiSemanticProjectSession.Open(lOptions);
  Assert.IsTrue(lSessionResult.Success, 'The owned project fixture must open.');
  aSession := lSessionResult.Session;
  if aScoped then
    lSnapshotResult := aSession.BuildSnapshotResult([aConsumerFileName])
  else
    lSnapshotResult := aSession.BuildSnapshotResult;
  aSnapshot := lSnapshotResult.Snapshot;
  Assert.IsTrue(aSnapshot.TryGetExtension(cDelphiSemanticContextEvidenceExtensionName,
    lExtension));
  lContextEvidence := lExtension as TDelphiSemanticContextEvidenceExtension;
  lBindingRequest := Default(TDelphiSemanticPlanBindingRequest);
  lBindingRequest.OperationIdentity := aOperationIdentity;
  lBindingRequest.SelectedConfigurationIdentities := [
    lContextEvidence.ProjectConfigurationIdentity];
  lBindingRequest.RequiredAnalysisKinds := [TSemanticPlanAnalysisKind.pakBodyAnalysis,
    TSemanticPlanAnalysisKind.pakReferenceExtraction];
  if aNoChange then
    lBindingRequest.Status := TSemanticPlanStatus.NoChange
  else
    lBindingRequest.Status := TSemanticPlanStatus.Complete;
  if not aNoChange then
  begin
  lEdit := Default(TSemanticPlanEdit);
  lEdit.FileName := aConsumerFileName;
  lOffset := Pos('uses QuietLeaf;', aConsumerText);
  Assert.IsTrue(lOffset > 0, 'The binding fixture contains the candidate import.');
  lLine := 1;
  lColumn := 1;
  i := 1;
  while i < lOffset do
  begin
    if aConsumerText[i] = #13 then
    begin
      Inc(lLine);
      lColumn := 1;
      Inc(i);
      if (i < lOffset) and (aConsumerText[i] = #10) then
        Inc(i);
    end else if aConsumerText[i] = #10 then
    begin
      Inc(lLine);
      lColumn := 1;
      Inc(i);
    end else begin
      Inc(lColumn);
      Inc(i);
    end;
  end;
  lEdit.StartLine := lLine;
  lEdit.StartColumn := lColumn;
  lEndOffset := lOffset + Length('uses QuietLeaf;');
  lLine := 1;
  lColumn := 1;
  i := 1;
  while i < lEndOffset do
  begin
    if aConsumerText[i] = #13 then
    begin
      Inc(lLine);
      lColumn := 1;
      Inc(i);
      if (i < lEndOffset) and (aConsumerText[i] = #10) then
        Inc(i);
    end else if aConsumerText[i] = #10 then
    begin
      Inc(lLine);
      lColumn := 1;
      Inc(i);
    end else begin
      Inc(lColumn);
      Inc(i);
    end;
  end;
  lEndLine := lLine;
  lEndColumn := lColumn;
  lEdit.EndLine := lEndLine;
  lEdit.EndColumn := lEndColumn;
  lEdit.ExpectedText := 'uses QuietLeaf;';
  lBindingRequest.Edits := [lEdit];
  end;
  if aScoped then
    lBindingRequest.ScopeRootFileNames := [aConsumerFileName];
  aBinding := TDelphiSemanticPlanBinder.Bind(aSnapshot, lBindingRequest);
end;

procedure TRefactoringUsesTests.AssertRemovalClassification(const aConsumerText,
  aLeafText: string; const aScoped: Boolean;
  const aExpectedClassification: TDelphiSemanticUsesClassification;
  const aExpectedStatus: TSemanticPlanStatus);
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lBinding := nil;
  lSession := nil;
  lSnapshot := nil;
  try
    CreateBoundContext(lRoot, aConsumerText, aLeafText, aScoped, lSession, lSnapshot,
      lBinding, lConsumerFileName);
      Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The binder must retain context only; the planner derives the edit.');
    lPlanResult := TDelphiSemanticUsesPlanner.PlanRemoveImplementationImport(
      lSnapshot, lBinding, lConsumerFileName, 'QuietLeaf');
    try
      Assert.AreEqual(aExpectedClassification, lPlanResult.Classification,
        lPlanResult.Reason);
      Assert.IsNotNull(lPlanResult.Plan, 'Refusal results retain a non-applicable plan.');
      Assert.AreEqual(aExpectedStatus, lPlanResult.Plan.Status, lPlanResult.Reason);
      if aExpectedStatus <> TSemanticPlanStatus.Complete then
        Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.AssertAddClassification(const aConsumerText,
  aProviderText, aUnitName, aIdentifier, aReasonFragment: string;
  const aExpectedClassification: TDelphiSemanticUsesClassification);
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot, aConsumerText, aProviderText, False,
      'uses.add-explicit-import', True, lSession, lSnapshot, lBinding,
      lConsumerFileName);
    lPlanResult := TDelphiSemanticUsesPlanner.PlanAddExplicitImport(lSnapshot,
      lBinding, lConsumerFileName, aUnitName, aIdentifier);
    try
      Assert.AreEqual(aExpectedClassification, lPlanResult.Classification,
        lPlanResult.Reason);
      Assert.IsNotNull(lPlanResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
      Assert.IsTrue(Pos(aReasonFragment, lPlanResult.Reason) > 0,
        'Expected refusal reason fragment: ' + aReasonFragment);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.PlansRemovalOfAnEmptyImplementationOnlyLeafImport;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContext(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'uses QuietLeaf;' + sLineBreak + 'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False, lSession, lSnapshot,
      lBinding, lConsumerFileName);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The fixture must first establish full-project context evidence without edits: ' +
      lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.PlanRemoveImplementationImport(
      lSnapshot, lBinding, lConsumerFileName, 'QuietLeaf');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucSafeImplementationImportRemoval,
        lPlanResult.Classification, lPlanResult.Reason);
      Assert.AreEqual(TSemanticPlanStatus.Complete, lPlanResult.Plan.Status);
      Assert.AreEqual(1, lPlanResult.Plan.EditCount);
      Assert.AreEqual(4, lPlanResult.Plan.Edits[0].StartLine);
      Assert.AreEqual(1, lPlanResult.Plan.Edits[0].StartColumn);
      Assert.AreEqual(4, lPlanResult.Plan.Edits[0].EndLine);
      Assert.AreEqual(16, lPlanResult.Plan.Edits[0].EndColumn);
      Assert.AreEqual('uses QuietLeaf;', lPlanResult.Plan.Edits[0].ExpectedText);
      Assert.AreEqual('', lPlanResult.Plan.Edits[0].ReplacementText);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksInitializationSensitiveLeafImport;
begin
  AssertRemovalClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'uses QuietLeaf;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak + 'implementation' +
    sLineBreak + 'procedure InitProc;' + sLineBreak + 'begin' + sLineBreak +
    'end;' + sLineBreak + 'initialization' + sLineBreak + 'InitProc;' + sLineBreak + 'end.',
    False, TDelphiSemanticUsesClassification.ucInitializationSensitive,
    TSemanticPlanStatus.Blocked);
end;

procedure TRefactoringUsesTests.BlocksInterfaceVisibleImport;
begin
  AssertRemovalClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'uses QuietLeaf;' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', False,
    TDelphiSemanticUsesClassification.ucInterfaceVisibleUse,
    TSemanticPlanStatus.Blocked);
end;

procedure TRefactoringUsesTests.BlocksConditionalUsesClause;
begin
  AssertRemovalClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + '{$IFDEF USE_LEAF}' + sLineBreak +
    'uses QuietLeaf;' + sLineBreak + '{$ENDIF}' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', False,
    TDelphiSemanticUsesClassification.ucConditionalClause,
    TSemanticPlanStatus.Blocked);
end;

procedure TRefactoringUsesTests.UnverifiedProviderConditionCannotAuthorizeImportRemoval;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lBinding := nil;
  lSession := nil;
  lSnapshot := nil;
  try
    CreateBoundContext(NewProjectRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'uses QuietLeaf;' + sLineBreak + 'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + '{$IFDEF UNICODE}' + sLineBreak +
      'initialization' + sLineBreak + 'Assert(True);' + sLineBreak +
      '{$ENDIF}' + sLineBreak + 'end.', False,
      lSession, lSnapshot, lBinding, lConsumerFileName);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status);
    Assert.AreEqual('', lBinding.Reason,
      'The context-only exception must reach the uses planner, rather than fail binding.');
    Assert.IsNotNull(lBinding.Plan);
    Assert.AreEqual(Integer(Length(lBinding.ExpectedRootFileNames)), lBinding.Plan.SourceCount);
    Assert.IsTrue(lBinding.Plan.SourceCount > 0, 'The binding must carry real full-project evidence.');
    lPlanResult := TDelphiSemanticUsesPlanner.PlanRemoveImplementationImport(
      lSnapshot, lBinding, lConsumerFileName, 'QuietLeaf');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucIncompleteScope, lPlanResult.Classification);
      Assert.IsNotNull(lPlanResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.Incomplete, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksSubsetAnalysisForProjectWideImportRemoval;
begin
  AssertRemovalClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'uses QuietLeaf;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', True,
    TDelphiSemanticUsesClassification.ucIncompleteScope,
    TSemanticPlanStatus.Incomplete);
end;

procedure TRefactoringUsesTests.BlocksLeafWithTransitiveOrderUnknown;
begin
  AssertRemovalClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'uses QuietLeaf;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'uses System.SysUtils;' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    False, TDelphiSemanticUsesClassification.ucInitializationSensitive,
    TSemanticPlanStatus.Blocked);
end;

procedure TRefactoringUsesTests.BlocksHelperOrOperatorProvider;
begin
  AssertRemovalClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'uses QuietLeaf;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'type TQuietHelper = class helper for TObject end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', False,
    TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown,
    TSemanticPlanStatus.Blocked);
end;

procedure TRefactoringUsesTests.ReportsMissingImplementationImportAsNoOp;
begin
  AssertRemovalClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'uses ProviderAlpha;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', False,
    TDelphiSemanticUsesClassification.ucNoOp, TSemanticPlanStatus.NoChange);
end;

procedure TRefactoringUsesTests.SuggestsUniqueAndAmbiguousExplicitImportCandidates;
var
  lAmbiguousResult: TDelphiSemanticUsesPlanningResult;
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
  lUniqueResult: TDelphiSemanticUsesPlanningResult;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValues: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := AlphaOnlyValue + SharedValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False,
      'uses.suggest-explicit-import-candidates', True, lSession, lSnapshot,
      lBinding, lConsumerFileName);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The fixture must first bind an observed no-change planning request: ' +
      lBinding.Reason);
    lUniqueResult := TDelphiSemanticUsesPlanner.SuggestExplicitImportCandidates(
      lSnapshot, lBinding, lConsumerFileName, 'AlphaOnlyValue');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucExplicitImportCandidate,
        lUniqueResult.Classification, lUniqueResult.Reason);
      Assert.IsTrue(Length(lUniqueResult.CandidateUnitNames) = 1);
      Assert.AreEqual('ProviderAlpha', lUniqueResult.CandidateUnitNames[0]);
      Assert.IsNotNull(lUniqueResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.NoChange, lUniqueResult.Plan.Status);
      Assert.AreEqual(0, lUniqueResult.Plan.EditCount,
        'Candidate discovery must not auto-select or apply an import.');
    finally
      lUniqueResult.Plan.Free;
    end;

    lAmbiguousResult := TDelphiSemanticUsesPlanner.SuggestExplicitImportCandidates(
      lSnapshot, lBinding, lConsumerFileName, 'SharedValue');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucAmbiguousExplicitImportCandidate,
        lAmbiguousResult.Classification, lAmbiguousResult.Reason);
      Assert.IsTrue(Length(lAmbiguousResult.CandidateUnitNames) = 2);
      Assert.AreEqual('ProviderAlpha', lAmbiguousResult.CandidateUnitNames[0]);
      Assert.AreEqual('ProviderBeta', lAmbiguousResult.CandidateUnitNames[1]);
      Assert.AreEqual(TSemanticPlanStatus.NoChange, lAmbiguousResult.Plan.Status);
      Assert.AreEqual(0, lAmbiguousResult.Plan.EditCount,
        'Ambiguous candidates remain a report, never an automatic choice.');
    finally
      lAmbiguousResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksMoveWithUnsupportedCompilerLinkSettings(
  const aName, aValue, aReason: string);
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(NewProjectRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'uses ProviderAlpha;' + sLineBreak + 'function ReadValue: Integer;' + sLineBreak +
      'implementation' + sLineBreak + 'function ReadValue: Integer;' + sLineBreak +
      'begin' + sLineBreak + '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.', 'unit QuietLeaf; interface implementation end.', False,
      'uses.analyze-interface-import-move', True, lSession, lSnapshot,
      lBinding, lConsumerFileName, '<' + aName + '>' + aValue + '</' + aName + '>');
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status, lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
      lSnapshot, lBinding, lConsumerFileName, 'ProviderAlpha');
    try
      Assert.AreEqual(aReason, lPlanResult.Reason);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.ReportsInterfaceImportMoveAsCandidateOnly(
  const aLinkMode: string);
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lProjectProperties: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lProjectProperties := '';
  if aLinkMode = 'disabled' then
    lProjectProperties := '<UsePackages>false</UsePackages>' +
      '<DCC_EnabledPackages>false</DCC_EnabledPackages>'
  else if aLinkMode = 'inactive-list' then
    lProjectProperties := '<DCC_UsePackage>rtl;vcl</DCC_UsePackage>';
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'uses ProviderAlpha;' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False,
      'uses.analyze-interface-import-move', True, lSession, lSnapshot,
      lBinding, lConsumerFileName, lProjectProperties);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The fixture must first bind an observed no-change request: ' + lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
      lSnapshot, lBinding, lConsumerFileName, 'ProviderAlpha');
    try
      Assert.AreEqual(
        TDelphiSemanticUsesClassification.ucInterfaceImplementationMoveCandidate,
        lPlanResult.Classification, lPlanResult.Reason);
      Assert.IsNotNull(lPlanResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status,
        'Candidate-only analysis cannot claim post-move binding/order proof.');
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
      Assert.AreEqual('ProviderAlpha', lPlanResult.CandidateUnitNames[0]);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksInterfaceImportMoveForConditionalOrLookupProvider(
  const aCase: string);
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lConsumerText: string;
  lEvidence: TDelphiSemanticContextModelEvidence;
  lExpectedClassification: TDelphiSemanticUsesClassification;
  lExpectedReason: string;
  lImportText: string;
  lLeafText: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lImportText := 'uses QuietLeaf;' + sLineBreak;
  lLeafText := 'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'const QuietValue = 7;' + sLineBreak;
  if aCase = 'conditional' then
  begin
    lImportText := '{$IFDEF MSWINDOWS}' + sLineBreak + lImportText +
      '{$ENDIF}' + sLineBreak;
    lExpectedClassification := TDelphiSemanticUsesClassification.ucConditionalClause;
    lExpectedReason := 'uses.conditional-clause';
  end else if aCase = 'helper' then
  begin
    lLeafText := lLeafText + 'type TQuietTarget = class end;' + sLineBreak +
      'TQuietHelper = class helper for TQuietTarget' + sLineBreak +
      'procedure Touch;' + sLineBreak + 'end;' + sLineBreak +
      'implementation' + sLineBreak +
      'procedure TQuietHelper.Touch;' + sLineBreak +
      'begin' + sLineBreak + 'end;' + sLineBreak;
    lExpectedClassification :=
      TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown;
    lExpectedReason := 'uses.helper-or-operator-visibility-unknown';
  end else begin
    Assert.AreEqual('operator', aCase, 'Unknown refusal fixture case');
    lLeafText := lLeafText + 'type TOperatorValue = record' + sLineBreak +
      'Value: Integer;' + sLineBreak +
      'class operator Implicit(const aValue: Integer): TOperatorValue;' + sLineBreak +
      'end;' + sLineBreak + 'implementation' + sLineBreak +
      'class operator TOperatorValue.Implicit(const aValue: Integer): TOperatorValue;' +
      sLineBreak + 'begin' + sLineBreak + 'Result.Value := aValue;' +
      sLineBreak + 'end;' + sLineBreak;
    lExpectedClassification :=
      TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown;
    lExpectedReason := 'uses.helper-or-operator-visibility-unknown';
  end;
  if aCase = 'conditional' then
    lLeafText := lLeafText + 'implementation' + sLineBreak;
  lLeafText := lLeafText + 'end.';
  lConsumerText := 'unit UsesConsumer;' + sLineBreak + 'interface' +
    sLineBreak + lImportText + 'function ReadValue: Integer;' + sLineBreak +
    'implementation' + sLineBreak + 'function ReadValue: Integer;' +
    sLineBreak + 'begin' + sLineBreak + 'Result := QuietValue;' +
    sLineBreak + 'end;' + sLineBreak + 'end.';
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot, lConsumerText, lLeafText, False,
      'uses.analyze-interface-import-move', True, lSession, lSnapshot,
      lBinding, lConsumerFileName);
    lEvidence := ModelEvidence(lSnapshot, lConsumerFileName);
    Assert.IsTrue(lEvidence.ModelSucceeded, 'Consumer model must succeed: ' + aCase);
    Assert.IsTrue(lEvidence.DependencyFacts.Known, 'Consumer imports must be retained');
    Assert.AreEqual(1, Integer(Length(lEvidence.DependencyFacts.InterfaceImports)));
    Assert.AreEqual('QuietLeaf', lEvidence.DependencyFacts.InterfaceImports[0]);
    lEvidence := ModelEvidence(lSnapshot, TPath.Combine(lRoot, 'QuietLeaf.pas'));
    Assert.IsTrue(lEvidence.ModelSucceeded, 'Provider model must succeed: ' + aCase);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The fixture must bind a no-change request: ' + lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
      lSnapshot, lBinding, lConsumerFileName, 'QuietLeaf');
    try
      Assert.AreEqual(lExpectedClassification, lPlanResult.Classification,
        lPlanResult.Reason);
      Assert.AreEqual(lExpectedReason, lPlanResult.Reason);
      Assert.IsNotNull(lPlanResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksInterfaceDefaultReferenceMove;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(NewProjectRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'uses ProviderAlpha;' + sLineBreak +
      'function ReadValue(aValue: Integer = AlphaOnlyValue): Integer;' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue(aValue: Integer): Integer;' + sLineBreak +
      'begin' + sLineBreak + '  Result := aValue + AlphaOnlyValue;' + sLineBreak +
      'end;' + sLineBreak + 'end.', 'unit QuietLeaf; interface implementation end.', False,
      'uses.analyze-interface-import-move', True, lSession, lSnapshot,
      lBinding, lConsumerFileName);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status, lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
      lSnapshot, lBinding, lConsumerFileName, 'ProviderAlpha');
    try
      Assert.AreEqual('uses.interface-reference-remains', lPlanResult.Reason);
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucInterfaceVisibleUse,
        lPlanResult.Classification);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksMoveWithUnresolvedUnrelatedReference;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'uses ProviderAlpha;' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := AlphaOnlyValue + UnknownValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False,
      'uses.analyze-interface-import-move', True, lSession, lSnapshot,
      lBinding, lConsumerFileName);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The fixture must first bind an observed no-change request: ' + lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
      lSnapshot, lBinding, lConsumerFileName, 'ProviderAlpha');
    try
      Assert.AreEqual('uses.reference-binding-unknown', lPlanResult.Reason);
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucUnknown, lPlanResult.Classification);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksMoveWithUnresolvedIntrinsicReference;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lEvidence: TDelphiSemanticContextModelEvidence;
  lIntrinsicIndex: Integer;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
  lValueIndex: Integer;
  i: Integer;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'uses QuietLeaf;' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      'Result := SizeOf(QuietValue);' + sLineBreak + 'end;' + sLineBreak + 'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'const QuietValue = 7;' + sLineBreak + 'implementation' + sLineBreak +
      'end.', False, 'uses.analyze-interface-import-move', True,
      lSession, lSnapshot, lBinding, lConsumerFileName);
    lEvidence := ModelEvidence(lSnapshot, lConsumerFileName);
    Assert.IsTrue(lEvidence.ModelSucceeded, 'Consumer model must succeed');
    Assert.IsTrue(lEvidence.ReferenceExtractionIncluded,
      'The intrinsic and provider references must be extracted');
    Assert.IsTrue(lEvidence.DependencyFacts.Known);
    Assert.AreEqual(1, Integer(Length(lEvidence.DependencyFacts.InterfaceImports)));
    Assert.AreEqual('QuietLeaf', lEvidence.DependencyFacts.InterfaceImports[0]);
    lEvidence := ModelEvidence(lSnapshot, TPath.Combine(lRoot, 'QuietLeaf.pas'));
    Assert.IsTrue(lEvidence.ModelSucceeded, 'Provider model must succeed');
    lEvidence := ModelEvidence(lSnapshot, lConsumerFileName);
    lIntrinsicIndex := -1;
    lValueIndex := -1;
    for i := 0 to High(lEvidence.References) do
    begin
      if SameText(lEvidence.References[i].Name, 'SizeOf') then
        lIntrinsicIndex := i
      else if SameText(lEvidence.References[i].Name, 'QuietValue') then
        lValueIndex := i;
    end;
    Assert.IsTrue(lIntrinsicIndex >= 0, 'SizeOf reference must be extracted');
    Assert.IsTrue(lValueIndex >= 0, 'QuietValue reference must be extracted');
    Assert.AreEqual('implementation', lEvidence.References[lIntrinsicIndex].SectionKind);
    Assert.AreEqual('implementation', lEvidence.References[lValueIndex].SectionKind);
    Assert.AreEqual('ReadValue', lEvidence.References[lIntrinsicIndex].RoutineName);
    Assert.AreEqual('ReadValue', lEvidence.References[lValueIndex].RoutineName);
    Assert.IsTrue(lEvidence.References[lIntrinsicIndex].RoutineScopeId <> '');
    Assert.AreEqual(lEvidence.References[lIntrinsicIndex].RoutineScopeId,
      lEvidence.References[lValueIndex].RoutineScopeId);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The fixture must first bind an observed no-change request: ' + lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
      lSnapshot, lBinding, lConsumerFileName, 'QuietLeaf');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucUnknown,
        lPlanResult.Classification, lPlanResult.Reason);
      Assert.AreEqual('uses.reference-binding-unknown', lPlanResult.Reason);
      Assert.IsNotNull(lPlanResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksMoveWithIncompleteReachableOrder(const aImport: string);
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'uses ProviderAlpha;' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'uses ' + aImport + ';' + sLineBreak + 'implementation' + sLineBreak + 'end.', False,
      'uses.analyze-interface-import-move', True, lSession, lSnapshot,
      lBinding, lConsumerFileName);
    Assert.AreEqual(TSemanticPlanStatus.NoChange, lBinding.Status,
      'The fixture must first bind an observed no-change request: ' + lBinding.Reason);
    lPlanResult := TDelphiSemanticUsesPlanner.AnalyzeInterfaceImportMoveCandidate(
      lSnapshot, lBinding, lConsumerFileName, 'ProviderAlpha');
    try
      Assert.AreEqual('uses.order-unresolved', lPlanResult.Reason);
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucUnknown, lPlanResult.Classification);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.PlansExplicitlySelectedUniqueImport;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False,
      'uses.add-explicit-import', True, lSession, lSnapshot, lBinding,
      lConsumerFileName);
    lPlanResult := TDelphiSemanticUsesPlanner.PlanAddExplicitImport(lSnapshot,
      lBinding, lConsumerFileName, 'ProviderAlpha', 'AlphaOnlyValue');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucSafeExplicitImportAddition,
        lPlanResult.Classification, lPlanResult.Reason);
      Assert.IsNotNull(lPlanResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.Complete, lPlanResult.Plan.Status);
      Assert.AreEqual(1, lPlanResult.Plan.EditCount);
      Assert.AreEqual(4, lPlanResult.Plan.Edits[0].StartLine);
      Assert.AreEqual(1, lPlanResult.Plan.Edits[0].StartColumn);
      Assert.AreEqual(4, lPlanResult.Plan.Edits[0].EndLine);
      Assert.AreEqual(1, lPlanResult.Plan.Edits[0].EndColumn);
      Assert.AreEqual('', lPlanResult.Plan.Edits[0].ExpectedText);
      Assert.AreEqual('uses ProviderAlpha;' + sLineBreak,
        lPlanResult.Plan.Edits[0].ReplacementText);
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksAmbiguousExplicitImportSelection;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := SharedValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False,
      'uses.add-explicit-import', True, lSession, lSnapshot, lBinding,
      lConsumerFileName);
    lPlanResult := TDelphiSemanticUsesPlanner.PlanAddExplicitImport(lSnapshot,
      lBinding, lConsumerFileName, 'ProviderAlpha', 'SharedValue');
    try
      Assert.AreEqual(
        TDelphiSemanticUsesClassification.ucAmbiguousExplicitImportCandidate,
        lPlanResult.Classification, lPlanResult.Reason);
      Assert.IsNotNull(lPlanResult.Plan);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
      Assert.IsTrue(Length(lPlanResult.CandidateUnitNames) = 2);
      Assert.AreEqual('ProviderAlpha', lPlanResult.CandidateUnitNames[0]);
      Assert.AreEqual('ProviderBeta', lPlanResult.CandidateUnitNames[1]);
      Assert.IsTrue(lPlanResult.Reason.Contains('lookup-order'));
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksQualifiedReferenceImportRequest;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := ProviderAlpha.AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False,
      'uses.add-explicit-import', True, lSession, lSnapshot, lBinding,
      lConsumerFileName);
    lPlanResult := TDelphiSemanticUsesPlanner.PlanAddExplicitImport(lSnapshot,
      lBinding, lConsumerFileName, 'ProviderAlpha', 'AlphaOnlyValue');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucUnsupportedShape,
        lPlanResult.Classification, lPlanResult.Reason);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
      Assert.IsTrue(lPlanResult.Reason.Contains('qualified'));
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksProviderWithoutCoProducedSource;
var
  lBinding: TDelphiSemanticBoundPlanResult;
  lConsumerFileName: string;
  lPlanResult: TDelphiSemanticUsesPlanningResult;
  lRoot: string;
  lSession: TDelphiSemanticProjectSession;
  lSnapshot: TDelphiProjectSnapshot;
begin
  lRoot := NewProjectRoot;
  lSession := nil;
  lSnapshot := nil;
  lBinding := nil;
  try
    CreateBoundContextForOperation(lRoot,
      'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak +
      'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
      '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak +
      'end.',
      'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
      'implementation' + sLineBreak + 'end.', False,
      'uses.add-explicit-import', True, lSession, lSnapshot, lBinding,
      lConsumerFileName);
    lPlanResult := TDelphiSemanticUsesPlanner.PlanAddExplicitImport(lSnapshot,
      lBinding, lConsumerFileName, 'BinaryOnlyProvider', 'AlphaOnlyValue');
    try
      Assert.AreEqual(TDelphiSemanticUsesClassification.ucUnsupportedShape,
        lPlanResult.Classification, lPlanResult.Reason);
      Assert.AreEqual(TSemanticPlanStatus.Blocked, lPlanResult.Plan.Status);
      Assert.AreEqual(0, lPlanResult.Plan.EditCount);
      Assert.IsTrue(lPlanResult.Reason.Contains('source-backed'));
    finally
      lPlanResult.Plan.Free;
    end;
  finally
    lBinding.Free;
    lSnapshot.Free;
    lSession.Free;
  end;
end;

procedure TRefactoringUsesTests.BlocksConditionalExplicitImportRequest;
begin
  AssertAddClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + '{$IFDEF USE_VALUE}' + sLineBreak +
    'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak +
    '{$ENDIF}' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', 'ProviderAlpha', 'AlphaOnlyValue',
    'conditional-clause', TDelphiSemanticUsesClassification.ucConditionalClause);
end;

procedure TRefactoringUsesTests.BlocksInitializationSensitiveExplicitImportProvider;
begin
  AssertAddClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak + 'const' + sLineBreak +
    'AlphaOnlyValue = 5;' + sLineBreak + 'implementation' + sLineBreak +
    'initialization' + sLineBreak + 'Assert(True);' + sLineBreak + 'end.',
    'QuietLeaf', 'AlphaOnlyValue', 'initialization-order',
    TDelphiSemanticUsesClassification.ucInitializationSensitive);
end;

procedure TRefactoringUsesTests.BlocksHelperExplicitImportProvider;
begin
  AssertAddClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  Result := AlphaOnlyValue;' + sLineBreak + 'end;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak + 'const' + sLineBreak +
    'AlphaOnlyValue = 5;' + sLineBreak +
    'type TQuietHelper = class helper for TObject end;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', 'QuietLeaf', 'AlphaOnlyValue',
    'helper-or-operator',
    TDelphiSemanticUsesClassification.ucHelperOrOperatorVisibilityUnknown);
end;

procedure TRefactoringUsesTests.BlocksUnknownExplicitImportReference;
begin
  AssertAddClassification(
    'unit UsesConsumer;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'function ReadValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  Result := MissingValue;' + sLineBreak + 'end;' + sLineBreak + 'end.',
    'unit QuietLeaf;' + sLineBreak + 'interface' + sLineBreak +
    'implementation' + sLineBreak + 'end.', 'ProviderAlpha', 'MissingValue',
    'selected-provider-does-not-declare',
    TDelphiSemanticUsesClassification.ucUnsupportedShape);
end;

initialization
  TDUnitX.RegisterTestFixture(TRefactoringUsesTests);

end.
