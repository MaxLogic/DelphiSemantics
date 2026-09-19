unit Test.WithBinding;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.ProjectSession, DelphiSemantics.WithBinding;

type
  [TestFixture]
  TProjectWithBindingTests = class
  private
    function BindingByUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): TDelphiSemanticWithBinding;
    function HasBindingForUnit(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aUnitName: string): Boolean;
    function HasProjectSymbol(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass: string): Boolean;
    function HasProjectSymbolSource(const aFacts: TDelphiSemanticProjectWithBindingFacts;
      const aName, aSymbolClass, aSourceKind: string): Boolean;
    function HasLookupSymbol(const aSymbols: TArray<TDelphiSemanticInventorySymbol>;
      const aName, aSymbolClass: string): Boolean;
    function HasReference(const aBinding: TDelphiSemanticWithBinding; const aName,
      aClassification: string): Boolean;
  public
    [Test]
    [TestCase('ordinary list', '0')]
    [TestCase('nested index', '1')]
    [TestCase('round arguments', '2')]
    [TestCase('mixed nesting', '3')]
    [TestCase('string comma', '4')]
    [TestCase('doubled quote', '5')]
    [TestCase('brace comment', '6')]
    [TestCase('round comment', '7')]
    [TestCase('line comment', '8')]
    [TestCase('directive', '9')]
    [TestCase('repeated list', '10')]
    [TestCase('empty', '11')]
    [TestCase('empty first', '12')]
    [TestCase('empty middle', '13')]
    [TestCase('empty last', '14')]
    [TestCase('unclosed index', '15')]
    [TestCase('misnested', '16')]
    [TestCase('unmatched close', '17')]
    [TestCase('unclosed string', '18')]
    [TestCase('unclosed brace', '19')]
    [TestCase('unclosed comment', '20')]
    procedure SelectorPartitionPreservesCompleteParts(const aCase: Integer);
    [Test]
    [TestCase('LF', 'LF,False,False')]
    [TestCase('LF with comment', 'LF,False,True')]
    [TestCase('LF with blank lines', 'LF,True,True')]
    [TestCase('CRLF with blank lines', 'CRLF,True,True')]
    procedure WithBodyReferencesKeepSourceCoordinates(const aLineEnding: string;
      const aBlankLines, aComment: Boolean);
    [Test]
    procedure CallReferencesSpanTheCompleteBalancedCall;
    [Test]
    procedure IndexReferencesSpanTheIndexAndBindItsIdentifiers;
    [Test]
    procedure IndexedDeclarationsPreserveBindingPrecedence;
    [Test]
    procedure IndexedDeclarationCandidatesPreserveDuplicatesAndRefresh;
    [Test]
    procedure ProjectSessionBuildsProjectLevelWithBindingFacts;
    [Test]
    procedure ProjectSessionCanSkipGraphForRangeMappedWithBindingFacts;
    [Test]
    procedure ProjectSessionIncludesExplicitAdditionalSourceFiles;
    [Test]
    procedure ProjectSessionLimitsBodyAnalysisToRequestedSourceFiles;
    [Test]
    procedure ProjectSessionBuildsRemoveWithLookupIndex;
    [Test]
    procedure RemoveWithLookupIndexReturnsIndependentMutableCopies;
    [Test]
    procedure RemoveWithLookupIndexIncludesCompatibilityExternalSymbols;
    [Test]
    procedure BindingReferenceCacheUsesStatementPrefix;
    [Test]
    procedure BindingReferencesUsePrecomputedBodyLineStarts;
    [Test]
    procedure BindProjectSkipsScopeIndexForUnitsWithoutWithStatements;
    [Test]
    procedure BindProjectBuildsScopeIndexOnlyForWithLines;
    [Test]
    procedure BindProjectPreallocatesHotFactLists;
    [Test]
    procedure BindProjectCachesParentSelectorStacks;
    [Test]
    procedure ReceiverMemberBindingUsesSemanticMemberIndex;
    [Test]
    procedure ReceiverMemberIndexDoesNotWalkVisibleUnitsPerLookup;
    [Test]
    procedure WithBindingUsesSingleResolverAuthorityAdapter;
    [Test]
    procedure WithBindingDelegatesCompatibilityInventory;
  end;

implementation

uses
  System.IOUtils, System.StrUtils, System.SysUtils,
  DelphiSemantics.Api.RemoveWith.Compatibility, DelphiSemantics.Model,
  DelphiSemantics.ProjectContext, maxLogic.IOUtils,
  Test.Support;


procedure TProjectWithBindingTests.WithBodyReferencesKeepSourceCoordinates(
  const aLineEnding: string; const aBlankLines, aComment: Boolean);
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLineBreak: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPlan: TDelphiSemanticRemoveWithPlan;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
  lSourceLines: TArray<string>;
  lValueLine: Integer;
begin
  if aLineEnding = 'LF' then
    lLineBreak := #10
  else
    lLineBreak := #13#10;
  lSource := 'unit WithBodyCoordinates;' + lLineBreak +
    'interface' + lLineBreak +
    'type' + lLineBreak +
    '  PChild = ^TChild;' + lLineBreak +
    '  TChild = record' + lLineBreak +
    '    Value: Integer;' + lLineBreak +
    '  end;' + lLineBreak +
    '  TContainer = record' + lLineBreak +
    '    Child: PChild;' + lLineBreak +
    '  end;' + lLineBreak +
    'function ReadValue(var aContainer: TContainer): Integer;' + lLineBreak +
    'implementation' + lLineBreak +
    'function ReadValue(var aContainer: TContainer): Integer;' + lLineBreak +
    'begin' + lLineBreak +
    '  if aContainer.Child <> nil then' + lLineBreak +
    '    with aContainer do' + lLineBreak;
  lValueLine := 18;
  if aBlankLines then
  begin
    lSource := lSource + lLineBreak + lLineBreak;
    Inc(lValueLine, 2);
  end;
  if aComment then
  begin
    lSource := lSource + '      // a comment before the qualified access' + lLineBreak;
    Inc(lValueLine);
  end;
  lSource := lSource + '    begin' + lLineBreak +
    '      ReadValue := Child^.Value;' + lLineBreak +
    '    end' + lLineBreak +
    '  else' + lLineBreak +
    '    ReadValue := 0;' + lLineBreak +
    'end;' + lLineBreak +
    'end.' + lLineBreak;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(RepoRoot,
    'tests\.dak\delphiSemanticsTests\t276-with-body-' + aLineEnding + '-' +
    BoolToStr(aBlankLines, True) + '-' + BoolToStr(aComment, True) + '.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lOptions.SourceFileName));
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('with-body-coordinates', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lBinding := lFacts.Bindings[0];
  Assert.AreEqual(16, lBinding.Line);
  Assert.AreEqual(5, lBinding.Column);
  Assert.AreEqual(16, lBinding.BodyLine);
  Assert.AreEqual(23, lBinding.BodyColumn);
  lSourceLines := StringReplace(lSource, #13#10, #10, [rfReplaceAll]).Split([#10]);
  Assert.IsTrue(Length(lBinding.References) > 0);
  for lReference in lBinding.References do
  begin
    Assert.AreEqual(lValueLine, lReference.Line, lReference.Name);
    Assert.AreEqual(lValueLine, lReference.EndLine, lReference.Name);
    Assert.AreEqual(lReference.Name, Copy(lSourceLines[lReference.Line - 1],
      lReference.Column, Length(lReference.Name)));
  end;
  Assert.IsTrue(HasReference(lBinding, 'Child', 'member'), 'Expected the receiver member.');
  Assert.IsTrue(HasReference(lBinding, 'ReadValue', 'lexical'),
    'Expected the named function result.');
  lPlan := TDelphiSemanticRemoveWithCompatibilityApi.PlanRemoveWith(lFacts);
  Assert.AreEqual(1, Integer(Length(lPlan.FinalStatements)));
  Assert.AreEqual('planned', lPlan.FinalStatements[0].Status,
    lPlan.FinalStatements[0].Reason);
  Assert.IsTrue(ContainsText(lPlan.FinalStatements[0].ReplacementText,
    'lWithContainerPtr^.Child^.Value'), lPlan.FinalStatements[0].ReplacementText);
end;

// T-277: a call-shaped reference spans the complete balanced call, not the text up to the first
// inner closing parenthesis (maxTdb md5.pas:245 recorded `FillChar(Buffer, SizeOf(TMD5Buffer)`).
procedure TProjectWithBindingTests.CallReferencesSpanTheCompleteBalancedCall;
var
  lBinding: TDelphiSemanticWithBinding;
  lCalls: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
  lSourceLines: TArray<string>;
  lSpan: string;
begin
  lSource := 'unit NestedCallExtents;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TMD5Buffer = array[0..63] of Byte;'#13#10 +
    '  TContext = record'#13#10 +
    '    Buffer: TMD5Buffer;'#13#10 +
    '    Count: Integer;'#13#10 +
    '  end;'#13#10 +
    'procedure Reset(var aContext: TContext);'#13#10 +
    'implementation'#13#10 +
    'procedure Reset(var aContext: TContext);'#13#10 +
    'begin'#13#10 +
    '  with aContext do'#13#10 +
    '  begin'#13#10 +
    '    FillChar(Buffer, SizeOf(TMD5Buffer), 0);'#13#10 +
    '    Count := Length(Buffer);'#13#10 +
    '    Inc(Count, SizeOf(Buffer) + Count);'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(RepoRoot,
    'tests\.dak\delphiSemanticsTests\t277-nested-call-extents.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lOptions.SourceFileName));
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('nested-call-extents', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lBinding := lFacts.Bindings[0];
  lSourceLines := StringReplace(lSource, #13#10, #10, [rfReplaceAll]).Split([#10]);
  lCalls := '|';
  for lReference in lBinding.References do
  begin
    // The name starts at the recorded column; the recorded span runs to EndColumn on the same line.
    Assert.AreEqual(lReference.Name, Copy(lSourceLines[lReference.Line - 1], lReference.Column,
      Length(lReference.Name)), lReference.Name);
    Assert.AreEqual(lReference.Line, lReference.EndLine, lReference.Name);
    lSpan := Copy(lSourceLines[lReference.Line - 1], lReference.Column,
      lReference.EndColumn - lReference.Column + 1);
    if Pos('(', lSpan) > 0 then
      lCalls := lCalls + lSpan + '|';
  end;
  Assert.IsTrue(lCalls.Contains('|FillChar(Buffer, SizeOf(TMD5Buffer), 0)|'), lCalls);
  Assert.IsTrue(lCalls.Contains('|Inc(Count, SizeOf(Buffer) + Count)|'), lCalls);
  Assert.IsTrue(lCalls.Contains('|Length(Buffer)|'), 'ordinary call control: ' + lCalls);
  Assert.IsTrue(HasReference(lBinding, 'Count', 'member'), 'Expected the Count member references.');
end;

// T-350: an index reference spans its complete balanced index, and the identifiers inside the index
// are bound references of their own, as call arguments are (tdbutils.pas:2069, tdbvars.pas:1130).
procedure TProjectWithBindingTests.IndexReferencesSpanTheIndexAndBindItsIdentifiers;
var
  lBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
  lSourceLines: TArray<string>;
  lSpans: string;
  lInner: string;
  lSpan: string;
begin
  lSource := 'unit NestedIndexExtents;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TContext = record'#13#10 +
    '    Values: array[0..9] of Integer;'#13#10 +
    '    Lookup: array[0..9] of Integer;'#13#10 +
    '    Index: Integer;'#13#10 +
    '    Total: Integer;'#13#10 +
    '    Name: string;'#13#10 +
    '  end;'#13#10 +
    'procedure Sum(var aContext: TContext);'#13#10 +
    'implementation'#13#10 +
    'procedure Sum(var aContext: TContext);'#13#10 +
    'begin'#13#10 +
    '  with aContext do'#13#10 +
    '  begin'#13#10 +
    '    Total := Values[Index];'#13#10 +
    '    Total := Total + Values[Lookup[Index]];'#13#10 +
    '    Total := Total + Values[Length(Name)];'#13#10 +
    '  end;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(RepoRoot,
    'tests\.dak\delphiSemanticsTests\t350-nested-index-extents.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lOptions.SourceFileName));
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lFacts := TDelphiSemanticWithBinder.BindProject('nested-index-extents', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lBinding := lFacts.Bindings[0];
  lSourceLines := StringReplace(lSource, #13#10, #10, [rfReplaceAll]).Split([#10]);
  lSpans := '|';
  lInner := '|';
  for lReference in lBinding.References do
  begin
    Assert.AreEqual(lReference.Name, Copy(lSourceLines[lReference.Line - 1], lReference.Column,
      Length(lReference.Name)), lReference.Name);
    lSpan := Copy(lSourceLines[lReference.Line - 1], lReference.Column,
      lReference.EndColumn - lReference.Column + 1);
    lSpans := lSpans + lSpan + '|';
    // Identifiers bound inside an index: the column lies after the first '[' of the line.
    if lReference.Column > Pos('[', lSourceLines[lReference.Line - 1]) then
      lInner := lInner + lReference.Line.ToString + ':' + lReference.Name + ':' + lReference.Classification + '|';
  end;
  Assert.IsTrue(lSpans.Contains('|Values[Lookup[Index]]|'), 'complete nested index: ' + lSpans);
  Assert.IsTrue(lSpans.Contains('|Values[Index]|'), 'simple index control: ' + lSpans);
  Assert.IsTrue(lInner.Contains('|17:Index:member|'), 'simple index identifier: ' + lInner);
  // An indexed reference keeps its index in its name, as Values[Index] does at top level.
  Assert.IsTrue(lInner.Contains('|18:Lookup[Index]:'), 'nested index receiver: ' + lInner);
  Assert.IsTrue(lInner.Contains('|18:Index:member|'), 'nested index identifier: ' + lInner);
  Assert.IsTrue(lInner.Contains('|19:Name:member|'), 'call inside an index: ' + lInner);
  // Each identifier inside an index is bound once.
  Assert.AreEqual(Pos('|19:Name:member|', lInner), lInner.LastIndexOf('|19:Name:member|') + 1, lInner);
end;

function LoadIndexedBindingModel(const aFileName: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('WithBinder', aFileName);
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(Result.Success);
end;

function BindingReferenceByName(const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aRoutineName, aName: string): TDelphiSemanticBoundReference;
var
  lBinding: TDelphiSemanticWithBinding;
  lReference: TDelphiSemanticBoundReference;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.RoutineName, aRoutineName) then
      for lReference in lBinding.References do
        if SameText(lReference.Name, aName) then
          Exit(lReference);
  Assert.Fail('Missing reference ' + aRoutineName + '.' + aName);
  Result := Default(TDelphiSemanticBoundReference);
end;

procedure AssertBindingReferencesEqual(const aExpected,
  aActual: TDelphiSemanticBoundReference);
begin
  Assert.AreEqual(aExpected.SemanticId, aActual.SemanticId);
  Assert.AreEqual(aExpected.Name, aActual.Name);
  Assert.AreEqual(aExpected.Classification, aActual.Classification);
  Assert.AreEqual(aExpected.LookupSource, aActual.LookupSource);
  Assert.AreEqual(aExpected.ReceiverTypeName, aActual.ReceiverTypeName);
  Assert.AreEqual(aExpected.Kind, aActual.Kind);
  Assert.AreEqual(aExpected.TypeName, aActual.TypeName);
  Assert.AreEqual(aExpected.ReasonCode, aActual.ReasonCode);
  Assert.AreEqual(aExpected.ScopeConflictKind, aActual.ScopeConflictKind);
  Assert.AreEqual(aExpected.ScopeConflictName, aActual.ScopeConflictName);
  Assert.AreEqual(aExpected.Line, aActual.Line);
  Assert.AreEqual(aExpected.Column, aActual.Column);
  Assert.AreEqual(aExpected.EndLine, aActual.EndLine);
  Assert.AreEqual(aExpected.EndColumn, aActual.EndColumn);
end;

procedure TProjectWithBindingTests.IndexedDeclarationsPreserveBindingPrecedence;
var
  lBaseline: TDelphiSemanticProjectWithBindingFacts;
  lConsumer: TDelphiSemanticUnitModel;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lName: string;
  lProvider: TDelphiSemanticUnitModel;
  lReference: TDelphiSemanticBoundReference;
begin
  lConsumer := LoadIndexedBindingModel('WithBinderUnit.pas');
  lProvider := LoadIndexedBindingModel('IndexedBindingProvider.pas');
  lBaseline := TDelphiSemanticWithBinder.BindProject('indexed-binding', nil, [lConsumer]);
  lFacts := TDelphiSemanticWithBinder.BindProject('indexed-binding', nil, [lConsumer, lProvider]);
  lReference := BindingReferenceByName(lFacts, 'RunWithBinder', 'MissingValue');
  Assert.AreEqual('lexical', lReference.Classification);
  Assert.AreEqual('var', lReference.Kind);
  Assert.AreEqual('Integer', lReference.TypeName);
  Assert.AreEqual('IndexedBindingProvider', lReference.ReceiverTypeName);
  Assert.AreEqual('', lReference.ReasonCode);
  Assert.AreEqual(40, lReference.Line);
  Assert.AreEqual(5, lReference.Column);
  Assert.AreEqual(40, lReference.EndLine);
  Assert.AreEqual(16, lReference.EndColumn);
  Assert.IsNotEmpty(lReference.SemanticId);
  for lName in ['lLocalValue', 'aParamValue', 'FirstOnly', 'lSecond.SecondOnly'] do
    AssertBindingReferencesEqual(
      BindingReferenceByName(lBaseline, 'RunWithBinder', lName),
      BindingReferenceByName(lFacts, 'RunWithBinder', lName));
  AssertBindingReferencesEqual(
    BindingReferenceByName(lBaseline, 'RunPlanningBinder', 'MissingPlanValue'),
    BindingReferenceByName(lFacts, 'RunPlanningBinder', 'MissingPlanValue'));
end;

procedure TProjectWithBindingTests.IndexedDeclarationCandidatesPreserveDuplicatesAndRefresh;
var
  lConsumer: TDelphiSemanticUnitModel;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOtherProvider: TDelphiSemanticUnitModel;
  lProvider: TDelphiSemanticUnitModel;
  lReference: TDelphiSemanticBoundReference;
begin
  lConsumer := LoadIndexedBindingModel('WithBinderUnit.pas');
  lProvider := LoadIndexedBindingModel('IndexedBindingProvider.pas');
  lOtherProvider := lProvider;
  lOtherProvider.UnitName := 'OtherIndexedBindingProvider';
  lFacts := TDelphiSemanticWithBinder.BindProject('indexed-binding', nil,
    [lConsumer, lProvider, lOtherProvider]);
  lReference := BindingReferenceByName(lFacts, 'RunWithBinder', 'MissingValue');
  Assert.AreEqual('MULTIPLE_INDEXED_DECLARATIONS', lReference.ReasonCode);
  SetLength(lProvider.Declarations, Length(lProvider.Declarations) + 1);
  lProvider.Declarations[High(lProvider.Declarations)] := lProvider.Declarations[0];
  lFacts := TDelphiSemanticWithBinder.BindProject('indexed-binding', nil, [lConsumer, lProvider]);
  lReference := BindingReferenceByName(lFacts, 'RunWithBinder', 'MissingValue');
  Assert.AreEqual('MULTIPLE_INDEXED_DECLARATIONS', lReference.ReasonCode);
  SetLength(lProvider.Declarations, 1);
  lProvider.Declarations[0].TypeName := 'Int64';
  lFacts := TDelphiSemanticWithBinder.BindProject('indexed-binding', nil, [lConsumer, lProvider]);
  lReference := BindingReferenceByName(lFacts, 'RunWithBinder', 'MissingValue');
  Assert.AreEqual('lexical', lReference.Classification);
  Assert.AreEqual('Int64', lReference.TypeName);
  lProvider.Declarations := nil;
  lFacts := TDelphiSemanticWithBinder.BindProject('indexed-binding', nil, [lConsumer, lProvider]);
  lReference := BindingReferenceByName(lFacts, 'RunWithBinder', 'MissingValue');
  Assert.AreEqual('unresolved', lReference.Classification);
  Assert.AreEqual('NAME_NOT_FOUND', lReference.ReasonCode);
end;

function TProjectWithBindingTests.BindingByUnit(
  const aFacts: TDelphiSemanticProjectWithBindingFacts;
  const aUnitName: string): TDelphiSemanticWithBinding;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.UnitName, aUnitName) then
      Exit(lBinding);

  Assert.Fail('Missing binding for unit ' + aUnitName);
  Result := Default(TDelphiSemanticWithBinding);
end;

function TProjectWithBindingTests.HasReference(const aBinding: TDelphiSemanticWithBinding;
  const aName, aClassification: string): Boolean;
var
  lReference: TDelphiSemanticBoundReference;
begin
  for lReference in aBinding.References do
    if SameText(lReference.Name, aName) and SameText(lReference.Classification,
      aClassification) then
      Exit(lReference.SemanticId <> '');

  Result := False;
end;

function TProjectWithBindingTests.HasBindingForUnit(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aUnitName: string): Boolean;
var
  lBinding: TDelphiSemanticWithBinding;
begin
  for lBinding in aFacts.Bindings do
    if SameText(lBinding.UnitName, aUnitName) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasProjectSymbol(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aName,
  aSymbolClass: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aFacts.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasProjectSymbolSource(
  const aFacts: TDelphiSemanticProjectWithBindingFacts; const aName,
  aSymbolClass, aSourceKind: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aFacts.Symbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) and
      SameText(lSymbol.SourceOwnerType, aSourceKind) then
      Exit(True);

  Result := False;
end;

function TProjectWithBindingTests.HasLookupSymbol(
  const aSymbols: TArray<TDelphiSemanticInventorySymbol>; const aName,
  aSymbolClass: string): Boolean;
var
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  for lSymbol in aSymbols do
    if SameText(lSymbol.Name, aName) and SameText(lSymbol.SymbolClass, aSymbolClass) then
      Exit(True);

  Result := False;
end;

procedure TProjectWithBindingTests.ProjectSessionBuildsProjectLevelWithBindingFacts;
var
  lProgramBinding: TDelphiSemanticWithBinding;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lUnitBinding: TDelphiSemanticWithBinding;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.AreEqual(lResult.Session.Project.ContextFingerprint, lFacts.ContextFingerprint);
    Assert.IsTrue(lFacts.Metrics.SemanticGraphUsed);
    Assert.IsFalse(lFacts.Metrics.BuildUnitIndexUsed);
    Assert.IsTrue(lFacts.Metrics.ModelExtractionMilliseconds >= 0);
    Assert.AreEqual(2, lFacts.Metrics.UnitCount);
    Assert.AreEqual(3, lFacts.Metrics.BindingCount);
    Assert.AreEqual(3, Integer(Length(lFacts.Bindings)));
    Assert.IsTrue(Length(lFacts.Symbols) > 0,
      'Expected project facts to carry reusable semantic inventory symbols.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TProjectWithRecord', 'declaration'));
    Assert.IsTrue(HasProjectSymbol(lFacts, 'Value', 'member'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'SizeOf', 'routine', 'compiler-intrinsic'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'NativeUInt', 'type', 'compiler-intrinsic'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'FreeAndNil', 'routine', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'Push', 'routine', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'TSearchRec', 'type-member', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'Name', 'field', 'rtl-source'));
    Assert.IsTrue(HasProjectSymbolSource(lFacts, 'Message', 'property', 'rtl-source'));
    Assert.IsFalse(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Unreferenced .pas files in the project directory must not be scanned as project units.');

    lProgramBinding := BindingByUnit(lFacts, 'ProjectWithBinding');
    Assert.IsNotEmpty(lProgramBinding.SemanticId);
    Assert.AreEqual('with-binding:project-session', lProgramBinding.Provenance);
    Assert.IsFalse(lProgramBinding.HasScopedDeclaration);
    Assert.IsTrue(HasReference(lProgramBinding, 'Value', 'member'));

    lUnitBinding := BindingByUnit(lFacts, 'ProjectWithUnit');
    Assert.IsTrue(HasReference(lUnitBinding, 'Count', 'member'));
    Assert.IsNotEmpty(lUnitBinding.References[0].SemanticId);
    Assert.AreNotEqual(lUnitBinding.SemanticId, lUnitBinding.References[0].SemanticId);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionCanSkipGraphForRangeMappedWithBindingFacts;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lProgramBinding: TDelphiSemanticWithBinding;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.SkipWithBindingSemanticGraph := True;

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsFalse(lFacts.Metrics.SemanticGraphUsed);
    Assert.AreEqual(3, lFacts.Metrics.BindingCount);
    lProgramBinding := BindingByUnit(lFacts, 'ProjectWithBinding');
    Assert.AreEqual('with-binding:model', lProgramBinding.Provenance);
    Assert.IsNotEmpty(lProgramBinding.SemanticId);
    Assert.IsTrue(HasReference(lProgramBinding, 'Value', 'member'));
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionIncludesExplicitAdditionalSourceFiles;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.AdditionalSourceFileNames := [
    FixturePath('ProjectWithBinding\UnreferencedWithUnit.pas')];

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsTrue(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Explicit additional source files must participate in project semantic facts.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TUnreferencedRecord', 'declaration'),
      'Explicit additional source files must contribute semantic inventory symbols.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionLimitsBodyAnalysisToRequestedSourceFiles;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');
  lOptions.AdditionalSourceFileNames := [
    FixturePath('ProjectWithBinding\UnreferencedWithUnit.pas')];

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts([
      FixturePath('ProjectWithBinding\ProjectWithBinding.dpr'),
      FixturePath('ProjectWithBinding\ProjectWithUnit.pas')]);

    Assert.IsFalse(HasBindingForUnit(lFacts, 'UnreferencedWithUnit'),
      'Sources outside the body-analysis set must not contribute with bindings.');
    Assert.IsTrue(HasProjectSymbol(lFacts, 'TUnreferencedRecord', 'declaration'),
      'Sources outside the body-analysis set must still contribute declarations.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.ProjectSessionBuildsRemoveWithLookupIndex;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalSymbol: TDelphiSemanticInventorySymbol;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    Assert.IsTrue(lFacts.LookupIndex.IsAvailable);
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindMembersByOwnerAndName(
      'TProjectWithRecord', 'Value'), 'Value', 'member'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindMembersByOwnerAndName(
      'tprojectwithrecord', 'value'), 'Value', 'member'));
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('TouchProjectUnitRecord',
      'aValue', lLocalSymbol));
    Assert.AreEqual('parameter', lLocalSymbol.SymbolClass);
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('TouchProjectUnitRecord',
      'lRecord', lLocalSymbol));
    Assert.AreEqual('local', lLocalSymbol.SymbolClass);
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('TProjectUnitScope.Run',
      'lScopedRecord', lLocalSymbol));
    Assert.AreEqual('local', lLocalSymbol.SymbolClass);
    Assert.IsTrue(lFacts.LookupIndex.FindRoutineSymbol('Run', 'lScopedRecord',
      lLocalSymbol));
    Assert.AreEqual('local', lLocalSymbol.SymbolClass);
    Assert.AreEqual('TProjectWithRecord', lFacts.LookupIndex.PointerTargetType(
      'PProjectWithRecord'));
    Assert.AreEqual('TProjectWithRecord', lFacts.LookupIndex.PointerTargetType(
      'pprojectwithrecord'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindDeclarationOrTypeAliasByName(
      'TProjectWithRecord'), 'TProjectWithRecord', 'declaration'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindDeclarationOrTypeAliasByName(
      'tprojectwithrecord'), 'TProjectWithRecord', 'declaration'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindUnitOrGlobalByName(
      'ProjectWithUnit'), 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindUnitOrGlobalByName(
      'projectwithunit'), 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindSymbolsByName(
      'ProjectWithUnit'), 'ProjectWithUnit', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lFacts.LookupIndex.FindSymbolsByOwnerType(
      'TProjectWithRecord'), 'Value', 'member'));
    Assert.IsTrue(lFacts.LookupIndex.Metrics.BuildMilliseconds >= 0);
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.RemoveWithLookupIndexReturnsIndependentMutableCopies;
var
  lExpectedName: string;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lFirst: TArray<TDelphiSemanticInventorySymbol>;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lSecond: TArray<TDelphiSemanticInventorySymbol>;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;
    lFirst := lFacts.LookupIndex.FindMembersByOwnerAndName(
      'TProjectWithRecord', 'Value');
    lSecond := lFacts.LookupIndex.FindMembersByOwnerAndName(
      'TProjectWithRecord', 'Value');

    Assert.IsTrue(Length(lFirst) > 0);
    Assert.AreEqual(Length(lFirst), Length(lSecond));
    lExpectedName := lSecond[0].Name;
    lFirst[0].Name := 'mutated-public-copy';
    Assert.AreEqual(lExpectedName, lSecond[0].Name,
      'A public lookup result must not alias an earlier mutable result.');
    lSecond := lFacts.LookupIndex.FindMembersByOwnerAndName(
      'TProjectWithRecord', 'Value');
    Assert.AreEqual(lExpectedName, lSecond[0].Name,
      'Mutating a public lookup result must not alter the lookup index.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.RemoveWithLookupIndexIncludesCompatibilityExternalSymbols;
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lLocalSymbol: TDelphiSemanticInventorySymbol;
  lLookupIndex: TDelphiSemanticRemoveWithLookupIndex;
  lOptions: TDelphiSemanticOptions;
  lResult: TDelphiSemanticProjectSessionResult;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  lOptions := Default(TDelphiSemanticOptions);
  lOptions.ProjectPath := FixturePath('ProjectWithBinding\ProjectWithBinding.dproj');

  lResult := TDelphiSemanticProjectSession.Open(lOptions);
  try
    Assert.IsTrue(lResult.Success);
    lFacts := lResult.Session.BuildWithBindingFacts;

    SetLength(lSymbols, 8);
    lSymbols[0] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[0].Name := 'TCompatibilityType';
    lSymbols[0].SymbolClass := 'external';
    lSymbols[0].Kind := 'external';
    lSymbols[0].TypeName := 'TCompatibilityType';

    lSymbols[1] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[1].Name := 'Compatibility.Unit';
    lSymbols[1].SymbolClass := 'external';
    lSymbols[1].Kind := 'external';
    lSymbols[1].UnitName := 'ProjectWithBinding';

    lSymbols[2] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[2].Name := 'Compatibility.Unit.Sub';
    lSymbols[2].SymbolClass := 'unit';
    lSymbols[2].Kind := 'unit';
    lSymbols[2].UnitName := 'Compatibility.Unit.Sub';

    lSymbols[3] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[3].Name := 'PCompatibilityType';
    lSymbols[3].SymbolClass := 'type-member';
    lSymbols[3].Kind := 'type-member';
    lSymbols[3].TypeName := '^TCompatibilityType';

    lSymbols[4] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[4].Name := 'NestedMember';
    lSymbols[4].SymbolClass := 'current-class-member';
    lSymbols[4].Kind := 'current-class-member';
    lSymbols[4].TypeName := 'TCompatibilityType';
    lSymbols[4].RoutineName := 'TCompatibilityScope.Run';

    lSymbols[5] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[5].Name := 'CompatibilityMember';
    lSymbols[5].SymbolClass := 'field';
    lSymbols[5].Kind := 'field';
    lSymbols[5].TypeName := 'Integer';
    lSymbols[5].OwnerType := 'TCompatibilityType';

    lSymbols[6] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[6].Name := 'PointerValue';
    lSymbols[6].SymbolClass := 'member';
    lSymbols[6].Kind := 'field';
    lSymbols[6].TypeName := '^TCompatibilityType';
    lSymbols[6].OwnerType := 'TCompatibilityType';

    lSymbols[7] := Default(TDelphiSemanticInventorySymbol);
    lSymbols[7].Name := 'ExpandedExternalMember';
    lSymbols[7].SymbolClass := 'field';
    lSymbols[7].Kind := 'field';
    lSymbols[7].TypeName := 'TExpandedExternalType';
    lSymbols[7].OwnerType := 'TCompatibilityType';

    lSymbols := TDelphiSemanticWithBinder.ExpandInventorySymbols(lSymbols);
    lLookupIndex := TDelphiSemanticRemoveWithLookupIndex.Build(lFacts.UnitModels, lSymbols);

    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindDeclarationOrTypeAliasByName(
      'tcompatibilitytype'), 'TCompatibilityType', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindDeclarationOrTypeAliasByName(
      'texpandedexternaltype'), 'TExpandedExternalType', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindUnitOrGlobalByName(
      'compatibility.unit'), 'Compatibility.Unit', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindUnitOrGlobalByPrefix(
      'compatibility'), 'Compatibility.Unit', 'external'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindUnitOrGlobalByPrefix(
      'compatibility.unit'), 'Compatibility.Unit.Sub', 'unit'));
    Assert.IsTrue(HasLookupSymbol(lLookupIndex.FindMembersByOwnerAndName(
      'TCompatibilityType', 'CompatibilityMember'), 'CompatibilityMember', 'field'));
    Assert.AreEqual('TCompatibilityType', lLookupIndex.PointerTargetType(
      'pcompatibilitytype'));
    Assert.AreEqual('', lLookupIndex.PointerTargetType('PointerValue'));
    Assert.IsFalse(lLookupIndex.FindRoutineSymbol('Run', 'NestedMember', lLocalSymbol),
      'Current-class members are member facts, not routine local/parameter facts.');
  finally
    lResult.Session.Free;
  end;
end;

procedure TProjectWithBindingTests.BindingReferenceCacheUsesStatementPrefix;
var
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');

  Assert.IsTrue(ContainsText(lSourceText, 'BoundReferenceCachePrefix'),
    'binding should build the shared reference-cache key prefix once per statement');
  Assert.IsTrue(ContainsText(lSourceText, 'ResolveNameCachePrefix'),
    'binding should build the shared resolver-cache key prefix once per statement');
  Assert.IsTrue(ContainsText(lSourceText, 'ReceiverMemberCachePrefix'),
    'binding should build the receiver/member cache key prefix once per statement');
end;

procedure TProjectWithBindingTests.BindingReferencesUsePrecomputedBodyLineStarts;
var
  lBindEnd: Integer;
  lBindSource: string;
  lBindStart: Integer;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lBindStart := Pos('function BindReferences(', lSourceText);
  lBindEnd := Pos('function StatementContains(', lSourceText);
  Assert.IsTrue((lBindStart > 0) and (lBindEnd > lBindStart),
    'Expected BindReferences implementation section.');

  lBindSource := Copy(lSourceText, lBindStart, lBindEnd - lBindStart);
  Assert.IsTrue(ContainsText(lSourceText, 'BuildBodyLineStarts'),
    'With-binding should build line starts once per body text.');
  Assert.IsTrue(ContainsText(lBindSource, 'lBodyLineStarts := BuildBodyLineStarts(lBodyText)'),
    'BindReferences should precompute body line starts once per statement.');
  Assert.IsTrue(ContainsText(lBindSource,
    'ApplyBodyRange(lReference, aStatement, lTokenStart, Length(lToken), lBodyLineStarts)'),
    'Reference body ranges should use the precomputed line-start table.');
  Assert.IsFalse(ContainsText(lSourceText, 'LineOfOffset(aStatement.BodyText'),
    'ApplyBodyRange must not rescan the body text for every reference line lookup.');
end;

procedure TProjectWithBindingTests.BindProjectSkipsScopeIndexForUnitsWithoutWithStatements;
var
  lBindProjectEnd: Integer;
  lBindProjectSource: string;
  lBindProjectStart: Integer;
  lScopeIndexPos: Integer;
  lSourceText: string;
  lWithGuardPos: Integer;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lBindProjectStart := Pos('class function TDelphiSemanticWithBinder.BindProject',
    lSourceText);
  lBindProjectEnd := Pos('class function TDelphiSemanticWithBinder.ExpandInventorySymbols',
    lSourceText);
  Assert.IsTrue((lBindProjectStart > 0) and (lBindProjectEnd > lBindProjectStart),
    'Expected BindProject implementation section.');

  lBindProjectSource := Copy(lSourceText, lBindProjectStart,
    lBindProjectEnd - lBindProjectStart);
  lWithGuardPos := Pos('if Length(lModel.WithStatements) = 0 then',
    lBindProjectSource);
  lScopeIndexPos := Pos('TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel',
    lBindProjectSource);
  Assert.IsTrue((lWithGuardPos > 0) and (lWithGuardPos < lScopeIndexPos),
    'BindProject should not build a routine scope index for units without with statements.');
end;

procedure TProjectWithBindingTests.BindProjectBuildsScopeIndexOnlyForWithLines;
var
  lBindProjectEnd: Integer;
  lBindProjectSource: string;
  lBindProjectStart: Integer;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lBindProjectStart := Pos('class function TDelphiSemanticWithBinder.BindProject',
    lSourceText);
  lBindProjectEnd := Pos('class function TDelphiSemanticWithBinder.ExpandInventorySymbols',
    lSourceText);
  Assert.IsTrue((lBindProjectStart > 0) and (lBindProjectEnd > lBindProjectStart),
    'Expected BindProject implementation section.');

  lBindProjectSource := Copy(lSourceText, lBindProjectStart,
    lBindProjectEnd - lBindProjectStart);
  Assert.IsTrue(ContainsText(lBindProjectSource,
    'TDelphiSemanticScopeResolver.BuildRoutineScopeIndex(lModel') and
    ContainsText(lBindProjectSource, 'lWithStatementLines'),
    'BindProject should build routine-scope line data only for with-statement lines.');
end;

procedure TProjectWithBindingTests.BindProjectPreallocatesHotFactLists;
var
  lBindProjectEnd: Integer;
  lBindProjectSource: string;
  lBindProjectStart: Integer;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lBindProjectStart := Pos('class function TDelphiSemanticWithBinder.BindProject',
    lSourceText);
  lBindProjectEnd := Pos('class function TDelphiSemanticWithBinder.ExpandInventorySymbols',
    lSourceText);
  Assert.IsTrue((lBindProjectStart > 0) and (lBindProjectEnd > lBindProjectStart),
    'Expected BindProject implementation section.');

  lBindProjectSource := Copy(lSourceText, lBindProjectStart,
    lBindProjectEnd - lBindProjectStart);
  Assert.IsTrue(ContainsText(lBindProjectSource, 'lBindings.Capacity := lBindingCapacity'),
    'BindProject should preallocate the binding list from with-statement counts.');
  Assert.IsTrue(ContainsText(lBindProjectSource, 'lSymbols.Capacity := lSymbolCapacity'),
    'BindProject should preallocate the inventory symbol list from model symbol counts.');
end;

procedure TProjectWithBindingTests.BindProjectCachesParentSelectorStacks;
var
  lBindProjectEnd: Integer;
  lBindProjectSource: string;
  lBindProjectStart: Integer;
  lSelectorStackEnd: Integer;
  lSelectorStackSource: string;
  lSelectorStackStart: Integer;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lSelectorStackStart := Pos('function StatementContains(', lSourceText);
  lSelectorStackEnd := Pos('class function TDelphiSemanticWithBinder.BindModel',
    lSourceText);
  Assert.IsTrue((lSelectorStackStart > 0) and (lSelectorStackEnd > lSelectorStackStart),
    'Expected selector-stack helper implementation section.');

  lSelectorStackSource := Copy(lSourceText, lSelectorStackStart,
    lSelectorStackEnd - lSelectorStackStart);
  Assert.IsTrue(ContainsText(lSelectorStackSource, 'function BuildParentStatementIndexes'),
    'With-binding should precompute parent statement indexes once per model.');
  Assert.IsTrue(ContainsText(lSelectorStackSource, 'function BuildSelectorStackCache'),
    'With-binding should cache combined selector stacks instead of rebuilding parent chains.');
  Assert.IsFalse(ContainsText(lSelectorStackSource, 'for i := 0 to Pred(aStatementIndex)'),
    'Selector inheritance must not scan all previous statements for every binding.');

  lBindProjectStart := Pos('class function TDelphiSemanticWithBinder.BindProject',
    lSourceText);
  lBindProjectEnd := Pos('class function TDelphiSemanticWithBinder.ExpandInventorySymbols',
    lSourceText);
  Assert.IsTrue((lBindProjectStart > 0) and (lBindProjectEnd > lBindProjectStart),
    'Expected BindProject implementation section.');
  lBindProjectSource := Copy(lSourceText, lBindProjectStart,
    lBindProjectEnd - lBindProjectStart);
  Assert.IsTrue(ContainsText(lBindProjectSource, 'lSelectorStacks := BuildSelectorStackCache'),
    'BindProject should build selector stacks once for each model.');
  Assert.IsTrue(ContainsText(lBindProjectSource, 'lBinding.Selectors := lSelectorStacks[i]'),
    'Binding construction should consume the cached selector stack for each statement.');
end;

procedure TProjectWithBindingTests.ReceiverMemberBindingUsesSemanticMemberIndex;
var
  lReceiverMemberEnd: Integer;
  lReceiverMemberStart: Integer;
  lReceiverMemberText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lReceiverMemberStart := Pos('function ReceiverMemberCacheKey', lSourceText);
  lReceiverMemberEnd := Pos('function AnySelectorUnresolved', lSourceText);
  Assert.IsTrue((lReceiverMemberStart > 0) and (lReceiverMemberEnd > lReceiverMemberStart),
    'Expected receiver-member binding source section.');
  lReceiverMemberText := Copy(lSourceText, lReceiverMemberStart,
    lReceiverMemberEnd - lReceiverMemberStart);

  Assert.IsTrue(ContainsText(lSourceText, 'TDelphiSemanticMemberResolver.BuildIndex'),
    'Receiver/member binding must build an operation-local semantic member index.');
  Assert.IsFalse(ContainsText(lReceiverMemberText, 'for lModel in aProjectModels do'),
    'Receiver/member binding must not scan every project model for each unresolved lookup.');
  Assert.IsFalse(ContainsText(lReceiverMemberText, 'ResolveMemberAtLevel(lModel'),
    'Receiver/member binding must not use project-model resolver fallback for every miss.');
end;

procedure TProjectWithBindingTests.ReceiverMemberIndexDoesNotWalkVisibleUnitsPerLookup;
var
  lIndexEnd: Integer;
  lIndexStart: Integer;
  lIndexText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lIndexStart := Pos('function TWithBindingProjectMemberIndex.TryResolveDirectMember',
    lSourceText);
  lIndexEnd := Pos('function IsBinderKeyword', lSourceText);
  Assert.IsTrue((lIndexStart > 0) and (lIndexEnd > lIndexStart),
    'Expected receiver-member index lookup source section.');
  lIndexText := Copy(lSourceText, lIndexStart, lIndexEnd - lIndexStart);

  Assert.IsTrue(ContainsText(lSourceText, 'fDirectMembersByContextOwnerName'),
    'Receiver/member binding must precompute current/visible-unit owner-name lookup keys.');
  Assert.IsTrue(ContainsText(lSourceText, 'fSemanticMemberResultsByOwnerName'),
    'Receiver/member binding must cache semantic member-index results by owner and member name.');
  Assert.IsFalse(ContainsText(lIndexText, 'for lUnitName in lVisibleUnits do'),
    'Receiver/member lookup must not walk visible units for each lookup.');
  Assert.IsFalse(ContainsText(lIndexText, 'for lUnitName in fUnitNames do'),
    'Receiver/member lookup must not walk all project units for each lookup.');
end;

procedure TProjectWithBindingTests.WithBindingUsesSingleResolverAuthorityAdapter;
var
  lAdapterStart: Integer;
  lAdapterText: string;
  lCount: Integer;
  lOffset: Integer;
  lResolveNameCachedStart: Integer;
  lResolveNameCachedText: string;
  lScopeConflictStart: Integer;
  lSelectorBindingStart: Integer;
  lSelectorBindingText: string;
  lSelectorPropertyStart: Integer;
  lSelectorPropertyText: string;
  lSourceText: string;
begin
  lSourceText := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  Assert.IsTrue(ContainsText(lSourceText, 'ResolveNameThroughWithBindingAuthority'),
    'WithBinding must route legacy name resolution through one documented adapter.');
  Assert.IsTrue(ContainsText(lSourceText, 'Compatibility adapter for model-array name resolution'),
    'The remaining compatibility adapter must explain why it exists.');

  lAdapterStart := Pos('function ResolveNameThroughWithBindingAuthority', lSourceText);
  lSelectorPropertyStart := Pos('function SelectorPrefixUsesProperty', lSourceText);
  lSelectorBindingStart := Pos('function MakeSelectorBinding', lSourceText);
  lResolveNameCachedStart := Pos('function ResolveNameCached', lSourceText);
  lScopeConflictStart := Pos('procedure ApplyScopeConflictFact', lSourceText);
  Assert.IsTrue((lAdapterStart > 0) and (lSelectorPropertyStart > lAdapterStart),
    'Expected resolver adapter before selector property resolution.');
  Assert.IsTrue((lSelectorBindingStart > lSelectorPropertyStart) and
    (lResolveNameCachedStart > lSelectorBindingStart) and
    (lScopeConflictStart > lResolveNameCachedStart),
    'Expected selector and cached lexical resolver sections.');

  lAdapterText := Copy(lSourceText, lAdapterStart, lSelectorPropertyStart - lAdapterStart);
  lSelectorPropertyText := Copy(lSourceText, lSelectorPropertyStart,
    lSelectorBindingStart - lSelectorPropertyStart);
  lSelectorBindingText := Copy(lSourceText, lSelectorBindingStart,
    lResolveNameCachedStart - lSelectorBindingStart);
  lResolveNameCachedText := Copy(lSourceText, lResolveNameCachedStart,
    lScopeConflictStart - lResolveNameCachedStart);
  Assert.IsTrue(ContainsText(lAdapterText, 'TDelphiSemanticResolver.ResolveName('),
    'Only the adapter should call the legacy resolver directly.');
  Assert.IsTrue(ContainsText(lSelectorPropertyText,
    'ResolveNameThroughWithBindingAuthority'),
    'Selector property checks must route through the adapter.');
  Assert.IsTrue(ContainsText(lSelectorBindingText, 'ResolveNameThroughWithBindingAuthority'),
    'Selector binding fallback must route through the adapter.');
  Assert.IsTrue(ContainsText(lResolveNameCachedText, 'ResolveNameThroughWithBindingAuthority'),
    'Cached lexical and scope-conflict resolution must route through the adapter.');

  lCount := 0;
  lOffset := Pos('TDelphiSemanticResolver.ResolveName(', lSourceText);
  while lOffset > 0 do
  begin
    Inc(lCount);
    lOffset := PosEx('TDelphiSemanticResolver.ResolveName(', lSourceText, lOffset + 1);
  end;

  Assert.AreEqual(1, lCount,
    'WithBinding must have exactly one direct legacy ResolveName call.');
end;

procedure TProjectWithBindingTests.WithBindingDelegatesCompatibilityInventory;
var
  lInventoryPath: string;
  lInventorySource: string;
  lWithBindingSource: string;
begin
  lInventoryPath := RepoSourcePath('src\DelphiSemantics.WithBinding.Inventory.pas');
  Assert.IsTrue(TFile.Exists(lInventoryPath),
    'Compatibility inventory construction should live in a focused unit.');

  lWithBindingSource := ReadRepoSource('src\DelphiSemantics.WithBinding.pas');
  lInventorySource := ReadRepoSource('src\DelphiSemantics.WithBinding.Inventory.pas');

  Assert.IsTrue(ContainsText(lWithBindingSource, 'DelphiSemantics.WithBinding.Inventory'),
    'WithBinding should delegate compatibility inventory construction to the focused unit.');
  Assert.IsTrue(ContainsText(lInventorySource, 'BuildInventorySymbols'),
    'The inventory unit should own model-to-inventory symbol construction.');
  Assert.IsTrue(ContainsText(lInventorySource, 'ExpandInventorySymbols'),
    'The inventory unit should own compatibility inventory expansion.');
  Assert.IsFalse(ContainsText(lWithBindingSource, 'function BuildInventorySymbols'),
    'WithBinding should not keep the compatibility inventory builder implementation.');
  Assert.IsFalse(ContainsText(lWithBindingSource, 'InventoryDecodeSourceText'),
    'WithBinding should not own legacy file-byte source decoding.');
  Assert.IsFalse(ContainsText(lWithBindingSource, 'TFile.ReadAllBytes'),
    'WithBinding compatibility inventory must not directly decode source bytes.');
  Assert.IsTrue(ContainsText(lInventorySource, 'aModel.SourceText') or
    ContainsText(lInventorySource, 'TDelphiSemanticSourceLoader'),
    'Compatibility inventory source fallback should use model source text or the shared source loader.');
end;

procedure TProjectWithBindingTests.SelectorPartitionPreservesCompleteParts(const aCase: Integer);
var
  lBindings: TArray<TDelphiSemanticWithBinding>;
  lExpected: TArray<string>;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lText: string;
  i: Integer;
begin
  case aCase of
    0:
    begin
      lText := 'aKnown, aOuter';
      lExpected := ['aKnown', 'aOuter'];
    end;
    1:
    begin
      lText := 'gOwners[Indexes[0, 0]]^';
      lExpected := ['gOwners[Indexes[0, 0]]^'];
    end;
    2:
    begin
      lText := 'Choose(aKnown, aOuter)';
      lExpected := ['Choose(aKnown, aOuter)'];
    end;
    3:
    begin
      lText := 'gOwners[Choose(Indexes[0, 0], 1)]^, aKnown';
      lExpected := ['gOwners[Choose(Indexes[0, 0], 1)]^', 'aKnown'];
    end;
    4:
    begin
      lText := 'Choose(''a,b'', aKnown)';
      lExpected := ['Choose(''a,b'', aKnown)'];
    end;
    5:
    begin
      lText := 'Choose(''a''''b,c'', aKnown)';
      lExpected := ['Choose(''a''''b,c'', aKnown)'];
    end;
    6:
    begin
      lText := 'aKnown { [,)] }, aOuter';
      lExpected := ['aKnown { [,)] }', 'aOuter'];
    end;
    7:
    begin
      lText := 'aKnown (* [,)] *), aOuter';
      lExpected := ['aKnown (* [,)] *)', 'aOuter'];
    end;
    8:
    begin
      lText := 'aKnown // [,)]' + #13#10 + ', aOuter';
      lExpected := ['aKnown // [,)]', 'aOuter'];
    end;
    9:
    begin
      lText := 'aKnown {$IFDEF UNUSED} {$ENDIF}, aOuter';
      lExpected := ['aKnown {$IFDEF UNUSED} {$ENDIF}', 'aOuter'];
    end;
    10:
    begin
      lText := 'aKnown, aKnown';
      lExpected := ['aKnown', 'aKnown'];
    end;
    11:
    begin
      lText := '';
      lExpected := [];
    end;
    12:
    begin
      lText := ', aKnown';
      lExpected := [];
    end;
    13:
    begin
      lText := 'aKnown, , aOuter';
      lExpected := [];
    end;
    14:
    begin
      lText := 'aKnown,';
      lExpected := [];
    end;
    15:
    begin
      lText := 'aKnown[0';
      lExpected := [];
    end;
    16:
    begin
      lText := 'aKnown[(0])';
      lExpected := [];
    end;
    17:
    begin
      lText := 'aKnown)';
      lExpected := [];
    end;
    18:
    begin
      lText := 'aKnown[''x';
      lExpected := [];
    end;
    19:
    begin
      lText := 'aKnown { x';
      lExpected := [];
    end;
    20:
    begin
      lText := 'aKnown (* x';
      lExpected := [];
    end;
  end;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('RemoveWithSelectorCoverage\SelectorCoverageUnit.pas');
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(8, Integer(Length(lModel.WithStatements)));
  // Exercise the binder's model boundary, including malformed incoming selector text.
  lModel.WithStatements := [lModel.WithStatements[4]];
  lModel.WithStatements[0].SelectorText := lText;
  lBindings := TDelphiSemanticWithBinder.BindModel(lModel);
  Assert.AreEqual(1, Integer(Length(lBindings)));
  Assert.AreEqual(Length(lExpected), Length(lBindings[0].Selectors));
  for i := 0 to High(lExpected) do
    Assert.AreEqual(lExpected[i], lBindings[0].Selectors[i].SelectorText);
end;

initialization
  TDUnitX.RegisterTestFixture(TProjectWithBindingTests);

end.
