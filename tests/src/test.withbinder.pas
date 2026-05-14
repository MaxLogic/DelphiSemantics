unit Test.WithBinder;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TWithBinderTests = class
  private
    function FixturePath(const aFileName: string): string;
    function LoadModel: TDelphiSemanticUnitModel;
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
    procedure AnonymousNestedRecordSelectorsUseSyntheticOwner;
    [Test]
    procedure GlobalAnonymousRecordSelectorUsesSyntheticOwner;
    [Test]
    procedure DefaultIndexedPropertyPointerSelectorDereferencesToRecord;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  maxLogic.IOUtils;

function TWithBinderTests.FixturePath(const aFileName: string): string;
begin
  Result := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', 'fixtures',
    'WithBinder', aFileName]));
end;

function TWithBinderTests.LoadModel: TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinderUnit.pas');
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
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

  Assert.AreEqual(10, Length(lBindings));
  Assert.AreEqual(1, Length(lBindings[0].Selectors));
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

  Assert.AreEqual(2, Length(lBindings[1].Selectors));
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

  Assert.AreEqual(1, Length(lBindings[3].Selectors));
  Assert.AreEqual('TFirstRecord', lBindings[3].Selectors[0].TypeName);
  Assert.IsFalse(HasAnyReference(lBindings[3], 'SecondOnly'));
  for lReference in lBindings[3].References do
    if SameText(lReference.Name, 'FirstOnly') and SameText(lReference.Classification, 'member') and
      (lReference.Line = 57) and (lReference.Column = 5) and (lReference.EndLine = 57) and
      (lReference.EndColumn = 13) then
      lFoundOuterAfterInnerRange := True;
  Assert.IsTrue(lFoundOuterAfterInnerRange, 'Expected outer reference after inner with to keep range.');
  Assert.AreEqual(2, Length(lBindings[4].Selectors));
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
  Assert.AreEqual(1, Length(lInventory.Bindings[0].Selectors));
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
  lOptions.SourceFileName := FixturePath('SourceModelGoldenUnit.pas');
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

procedure TWithBinderTests.AnonymousNestedRecordSelectorsUseSyntheticOwner;
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('NestedAnonymousWithUnit.pas');
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

  Assert.AreEqual(1, Length(lBindings));
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
  lOptions.SourceFileName := FixturePath('GlobalAnonymousWithUnit.pas');
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

  Assert.AreEqual(1, Length(lBindings));
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
  lOptions.SourceFileName := FixturePath('DefaultPointerWithUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Length(lBindings));
  Assert.AreEqual('lList[0]^', lBindings[0].Selectors[0].SelectorText);
  Assert.AreEqual('TDefaultRecord', lBindings[0].Selectors[0].TypeName);
  Assert.IsTrue(HasReference(lBindings[0], 'Value', 'member'));
  Assert.AreEqual('TDefaultRecord', ReceiverOf(lBindings[0], 'Value', 'member'));
end;

initialization
  TDUnitX.RegisterTestFixture(TWithBinderTests);

end.
