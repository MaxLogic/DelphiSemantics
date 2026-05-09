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
  public
    [Test]
    procedure ResolvesSelectorTypesAndClassifiesBodyIdentifiers;
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
  end;

implementation

uses
  System.IOUtils, System.SysUtils,
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
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := LoadModel;

  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);

  Assert.AreEqual(1, Length(lBindings[3].Selectors));
  Assert.AreEqual('TFirstRecord', lBindings[3].Selectors[0].TypeName);
  Assert.IsFalse(HasAnyReference(lBindings[3], 'SecondOnly'));
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
  Assert.AreEqual(4, lBinding.MemberReferenceCount);
  Assert.AreEqual(2, lBinding.LexicalReferenceCount);
  Assert.AreEqual(2, lBinding.ExternalReferenceCount);
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

  Assert.AreEqual(5, CountReferences(lBinding, 'FirstOnly'));
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

initialization
  TDUnitX.RegisterTestFixture(TWithBinderTests);

end.
