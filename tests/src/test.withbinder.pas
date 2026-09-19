unit Test.WithBinder;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TWithBinderTests = class
  private
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
    procedure ClassMethodWithBindingUsesOwnedRoutineTypeForInheritedProtectedMembers;
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
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
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
  finally
    if TFile.Exists(lPath) then
      TFile.Delete(lPath);
  end;
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

initialization
  TDUnitX.RegisterTestFixture(TWithBinderTests);

end.
