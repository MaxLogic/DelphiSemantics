unit Test.UnitModel;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.GlobalVars, DelphiSemantics.Model, DelphiSemantics.Source,
  DelphiSemantics.WithBinding;

type
  [TestFixture]
  TUnitModelTests = class
  private
    function AnonymousRecordLocalModel(out aSource: string): TDelphiSemanticUnitModel;
    function DefaultParameterSource(const aShape: string): string;
    function HasDeclaration(const aModel: TDelphiSemanticUnitModel; const aName, aKind,
      aSection: string): Boolean;
    function HasDiagnostic(const aModel: TDelphiSemanticUnitModel; const aCode: string): Boolean;
    function HasMemberOfOwner(const aModel: TDelphiSemanticUnitModel; const aOwnerName,
      aName: string): Boolean;
    function HasMemberOnLine(const aModel: TDelphiSemanticUnitModel; const aOwnerName,
      aName: string; const aLine: Integer): Boolean;
    function HasLocal(const aModel: TDelphiSemanticUnitModel; const aRoutineName, aName,
      aTypeName: string): Boolean;
    function HasLocalOnLine(const aModel: TDelphiSemanticUnitModel; const aRoutineName,
      aName: string; const aLine: Integer): Boolean;
    function FindLocal(const aModel: TDelphiSemanticUnitModel; const aRoutineName, aName:
      string; out aLocal: TDelphiSemanticLocal): Boolean;
    function HasMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName, aName, aKind,
      aTypeName: string): Boolean;
    function FindDeclaration(const aModel: TDelphiSemanticUnitModel; const aName, aKind,
      aSection: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
    function FindMember(const aModel: TDelphiSemanticUnitModel; const aOwnerName, aName, aKind:
      string; out aMember: TDelphiSemanticMember): Boolean;
    function ColumnOfSourceOffset(const aSource: string; const aOffset: Integer): Integer;
    function FindReferenceAtOffset(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aOffset: Integer; out aReference: TDelphiSemanticReference): Boolean;
    function HasReference(const aModel: TDelphiSemanticUnitModel; const aName: string): Boolean;
    function HasReferenceOnLine(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aLine: Integer): Boolean;
    function HasReferenceAtOffset(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aOffset: Integer): Boolean;
    function FindRoutine(const aModel: TDelphiSemanticUnitModel; const aName, aSection: string;
      out aRoutine: TDelphiSemanticRoutine): Boolean;
    function HasRoutine(const aModel: TDelphiSemanticUnitModel; const aName, aSection: string):
      Boolean;
    function HasRoutineOnLine(const aModel: TDelphiSemanticUnitModel; const aName: string;
      const aLine: Integer): Boolean;
    function LineContaining(const aText, aPattern: string): Integer;
    function StatementText(const aText: string; const aStartLine, aStartColumn, aEndLine,
      aEndColumn: Integer): string;
    function LineOfDeclaration(const aModel: TDelphiSemanticUnitModel; const aName: string):
      Integer;
    procedure AssertExpectedReentrantModel(const aModel: TDelphiSemanticUnitModel;
      const aUnitName, aTypeName, aRoutineName, aReferenceName: string);
    procedure ExtractReentrantLoop(const aPath, aUnitName, aTypeName, aRoutineName,
      aReferenceName: string; out aError: string);
  public
    [Test]
    [TestCase('Two methods', 'two-methods')]
    [TestCase('Field, visibility and method', 'field-visibility-method')]
    procedure ExtractsEveryMemberOnOnePhysicalLine(const aLayout: string);
    [Test]
    procedure MethodContinuationParametersAreNotFields;
    [Test]
    procedure EscapedIdentifierMembersAreKept;
    [Test]
    procedure NestedTypeMembersKeepQualifiedOwnerAndVisibility;
    [Test]
    procedure AstFailedUnitKeepsUnverifiedMembers;
    [Test]
    procedure InterfaceOnlyRetryKeepsOriginalParserMessage;
    [Test] procedure NestedRoutineDeclarationHasEnclosingScope;
    [Test]
    procedure RoutineLocalTypesRetainTheirDeclaringScope;
    [Test]
    procedure HomonymousAndDistinctRoutineLocalTypesKeepSourceIdentity;
    [Test]
    [TestCase('Multiple ordinary fields', 'ordinary')]
    [TestCase('Visibility changes on one line', 'visibility')]
    [TestCase('Persistent class var section', 'class-var')]
    procedure ExtractsCompoundVisibilityFields(const aLayout: string);
    [Test]
    [TestCase('Public inline', 'public,field,True')]
    [TestCase('Private inline', 'private,field,True')]
    [TestCase('Strict protected inline', 'strict protected,field,True')]
    [TestCase('Class variable inline', 'public,class-var,True')]
    [TestCase('Public multiline', 'public,field,False')]
    procedure ExtractsFieldAfterVisibility(const aVisibility, aKind: string; const aInline: Boolean);
    [Test]
    procedure SourceLoaderUsesAnsiFallbackForInvalidUtf8;
    [Test]
    procedure SourceLoaderUsesAnsiFallbackForMalformedUtf8;
    [Test]
    procedure SourceLoaderUsesUtf16LeBom;
    [Test]
    procedure ExtractsUnitNameUsesDeclarationsAndWithStatements;
    [Test]
    procedure ExtractsOnlyActiveUsesOutsideCommentsAndStrings;
    [Test]
    procedure ExtractsMembersRoutinesLocalsAndReferences;
    [Test]
    procedure ExtractsConstructorAndDestructorScopesAndLocals;
    [Test]
    procedure ExtractsCommaDeclaredRoutineLocals;
    [Test]
    procedure RoutineLocalsSurviveSameLineVarSections;
    [Test]
    procedure RoutineProceduralObjectLocalsKeepAstScopeModel;
    [Test]
    procedure RoutineAnonymousRecordLocalsUseSyntheticOwnerType;
    [Test]
    procedure RoutineAnonymousRecordLocalsKeepSyntheticInventoryOwner;
    [Test]
    procedure SkipReferenceExtractionKeepsSymbolsAndOmitsReferences;
    [Test]
    [TestCase('Interface', 'global,False')]
    [TestCase('Interface lean', 'global,True')]
    [TestCase('Method', 'method,False')]
    [TestCase('Method lean', 'method,True')]
    [TestCase('Implementation', 'private,False')]
    [TestCase('Implementation lean', 'private,True')]
    procedure ExtractsDefaultParameterReferences(const aShape: string; const aLean: Boolean);
    [Test]
    procedure DefaultParameterStringsAndCommentsDoNotCreateReferences;
    [Test]
    procedure SkipsDefaultParameterReferencesWhenExtractionDisabled;
    [Test]
    procedure ExtractsUntypedRoutineParameters;
    [Test]
    [TestCase('missing terminator', '0')]
    [TestCase('unclosed parameters', '1')]
    procedure IncompleteRoutineHeaderPreservesFollowingDeclaration(const aCase: Integer);
    [Test]
    procedure RoutineHeaderExtentPreservesDelimitersAndCommentBoundaries;
    [Test]
    procedure ExtractsRoutineAfterSingleLineGuidInterface;
    [Test]
    procedure ExtractsAnonymousNestedRecordMembers;
    [Test]
    procedure ExtractsUnprefixedConstVarAndTypedConstDeclarations;
    [Test]
    procedure ExtractsInlineConstVarSections;
    [Test]
    [Category('CompactConstantFacts')]
    [TestCase('Compact', 'True')]
    [TestCase('Multiline', 'False')]
    procedure PreservesUnitConstantsAcrossLineLayouts(const aCompact: Boolean);
    [Test]
    procedure InitializedVariablesRetainOnlyDeclaredTypes;
    [Test]
    procedure AssignmentsDoNotBecomeDeclarations;
    [Test]
    [TestCase('Globals first', 'True')]
    [TestCase('Globals after class', 'False')]
    procedure GlobalsAroundClassDeclarationsKeepTheirScope(const aGlobalsFirst: Boolean);
    [Test]
    [TestCase('Packed record', 'True')]
    [TestCase('Ordinary record', 'False')]
    procedure PackedAndOrdinaryFieldsKeepModelAndBindingIdentity(const aPacked: Boolean);
    [Test]
    [TestCase('Line comments', 'True')]
    [TestCase('Block comments', 'False')]
    procedure MultilineFieldsKeepSourceAndBindingIdentity(const aLineComment: Boolean);
    [Test]
    procedure LiteralFieldTypesKeepOriginalText;
    [Test]
    [TestCase('Split variant labels', 'True')]
    [TestCase('Inline variant labels', 'False')]
    procedure VariantLabelsKeepFollowingFields(const aSplit: Boolean);
    [Test]
    procedure ProgramBodyReferencesUseActualSyntaxScope;
    [Test]
    procedure InlineConstSectionEndsTypeDeclarations;
    [Test]
    procedure MultilineVarParametersAreNotUnitVariables;
    [Test]
    procedure CommentedRoutineHeaderDoesNotHideUnitVariables;
    [Test]
    procedure MigratedSymbolMapExtractsUnitNameAndUsesSections;
    [Test]
    procedure MigratedSymbolMapExtractsNamespacedUnitName;
    [Test]
    procedure MigratedSymbolMapExtractsTopLevelDeclarationsAndEnumValues;
    [Test]
    procedure MigratedSymbolMapExtractsMembersPropertiesAndMetadata;
    [Test]
    procedure PreprocessingRemovesInactiveDeclarations;
    [Test]
    procedure TypedConstantMutabilityUsesActivePreprocessedDirectives;
    [Test]
    [TestCase('Standalone include', '0')]
    [TestCase('Switch before include', '1')]
    [TestCase('Switch after include', '2')]
    procedure TypedConstantMutabilityUsesIncludedDirectives(const aCase: Integer);
    [Test]
    [TestCase('Line comment', '0')]
    [TestCase('Parenthesized block comment', '1')]
    [TestCase('Brace block comment', '2')]
    [TestCase('Quoted text', '3')]
    procedure TypedConstantMutabilityIgnoresCommentedDirective(const aCase: Integer);
    [Test]
    procedure TypedConstantMutabilityRespectsInlineSwitchOrder;
    [Test]
    [TestCase('Parenthesized pair', '0')]
    [TestCase('Brace then parenthesis', '1')]
    [TestCase('Parenthesis then brace', '2')]
    procedure TypedConstantMutabilityUsesLastStandaloneSwitch(const aCase: Integer);
    [Test]
    procedure ScopeModelFailureRejectsUnverifiedGlobalCandidates;
    [Test]
    procedure RejectedDeclarationsHaveDeterministicMutability;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentLineNumbers;
    [Test]
    procedure IncludeExpansionPreservesMultiLineIncludedDeclarations;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentWithRanges;
    // DS-659: facts whose text comes from an include file carry that file and its own
    // position; they are never mapped onto an unrelated position of the including unit.
    [Test]
    procedure IncludeInRoutineBodyAttributesReferencesToIncludeFiles;
    [Test]
    procedure IncludeBetweenDeclarationsAttributesFactsToIncludeFile;
    // DS-659 review: an include expanded inside a line has no exact position; its facts are kept
    // at the directive's own position instead of being dropped.
    [Test]
    procedure MidLineIncludeFactsStayAtTheDirective;
    [Test]
    procedure MidLineIncludesKeepDistinctPhysicalReferenceOccurrences;
    [Test]
    procedure RepeatedNestedAndInactiveIncludesKeepPhysicalOccurrences;
    [Test]
    procedure ModelUsesSourceLoaderFallbackWhenExtractingAnsiSource;
    [Test]
    procedure WithStatementsExposeSourceRanges;
    [Test]
    procedure WithDiscoveryIgnoresStringsAndCommentsAndKeepsRepeatedRanges;
    [Test]
    procedure ReferencesIgnoreStringsAndComments;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentReferences;
    [Test]
    procedure IncludeExpansionDoesNotShiftFollowingParentMembersRoutinesAndLocals;
    [Test]
    procedure WithStatementRangeCoversIfThenElseBodies;
    [Test]
    procedure ModelKeepsOriginalSourceLineNumbersAfterPreprocessing;
    [Test]
    procedure SourceSectionsExposeInitializationAndFinalizationBoundaries;
    [Test]
    procedure SourceSectionsHandleUnitsWithoutImplementation;
    [Test]
    procedure SourceSectionsIgnoreCommentsAndStringsWhenFindingImplementation;
    [Test]
    procedure ModelCarriesOriginalSourceRangesForDeclarationsRoutinesMembersAndLocals;
    [Test]
    procedure ReferencesCarryOriginalSourceRanges;
    [Test]
    procedure ReferenceReconciliationPreservesMixedLineEndings;
    [Test]
    procedure CoordinateMappingPreservesRangesAcrossModelKinds;
    [Test]
    procedure ReferencesCarryOriginalSourceRangesWithoutFallbackForPlainSource;
    [Test]
    procedure ModelPropagatesSourceAndPreprocessDiagnostics;
    [Test]
    procedure StandaloneExtractionReportsDegradedMode;
    [Test]
    procedure UnitModelExtractionIsReentrantForParallelUnits;
    [Test]
    procedure TypeBlockAnalysisIsBuiltOncePerExtraction;
    [Test]
    procedure ReferenceReconciliationScansRepeatedNamesOnce;
    [Test]
    procedure ReferenceReconciliationBuildsOccurrenceTableOnce;
    [Test]
    procedure RoutineReconciliationUsesOffsetMapBeforeFallback;
    [Test]
    procedure ModelJsonPreservesDeclarationRolesAndLexicalOwnership;
    [Test]
    procedure PhysicalOccurrencesJsonRoundTripRetainsStatusAndIndependentArray;
    [Test]
    procedure PhysicalOccurrencesAvailabilityDistinguishesOldAndEmptyModels;
    [Test]
    [TestCase('FlushLeftFull', 'False,False')]
    [TestCase('IndentedFull', 'True,False')]
    [TestCase('FlushLeftLean', 'False,True')]
    [TestCase('IndentedLean', 'True,True')]
    procedure PointerAliasRetainsUnitDeclarationScope(const aIndented, aLean: Boolean);
    [Test]
    procedure AdjacentRoutineHeadersKeepTheirOwnTypeReferenceScope;
    [Test]
    procedure SameLineNestedRoutineEndRestoresOuterReferenceScope;
    [Test]
    procedure PascalLexicalHelpersAreCentralized;
    [Test]
    procedure UnitModelImplementationIsSplitIntoFocusedUnits;
    [Test]
    procedure ProgramRoutineBodiesEndBeforeVarSectionsAndMainBlock;
    [Test]
    procedure InterfaceHeadersAndInitializationGetNoRoutineBody;
    [Test]
    procedure NestedAnonymousAsmAndLocalTypeBodiesAreBounded;
    [Test]
    procedure DeclarationExpressionsAreReferences;
  end;

implementation

uses
  System.Classes, System.Generics.Collections, System.IOUtils, System.JSON, System.StrUtils,
  System.SysUtils,
  Winapi.Windows,
  AutoFree, maxLogic.IOUtils,
  DelphiSemantics.Model.Coordinates, DelphiSemantics.Model.Json,
  DelphiSemantics.WithBinding.Inventory,
  Test.Support;

var
  GUnitModelTempRoot: string;

function UnitModelTempPath(const aName: string): string;
var
  lGuid: TGUID;
  lGuidText: string;
begin
  if GUnitModelTempRoot = '' then
  begin
    CreateGUID(lGuid);
    lGuidText := StringReplace(StringReplace(GUIDToString(lGuid), '{', '', [rfReplaceAll]), '}',
      '', [rfReplaceAll]);
    GUnitModelTempRoot := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
      'unit-model-temp', 'run-' + GetCurrentProcessId.ToString + '-' + lGuidText]));
  end;
  TDirectory.CreateDirectory(GUnitModelTempRoot);
  Result := TPath.Combine(GUnitModelTempRoot, aName);
end;

function UnitModelMemberKey(const aOwnerName, aName, aKind: string): string;
begin
  Result := aOwnerName + '.' + aName + ':' + aKind;
end;

function UnitModelDeclarationKey(const aName, aKind, aSectionKind: string): string;
begin
  Result := aName + ':' + aKind + ':' + aSectionKind;
end;

procedure AssertStringKeysExactly(const aActualKeys: TStringList; const aExpectedKeys: array of string;
  const aContext: string);
var
  lActualKey: string;
  lExpected: TStringList;
  lExpectedKey: string;
  i: Integer;
begin
  lExpected := TStringList.Create;
  try
    lExpected.Sorted := True;
    for i := Low(aExpectedKeys) to High(aExpectedKeys) do
    begin
      Assert.IsTrue(lExpected.IndexOf(aExpectedKeys[i]) < 0,
        'Duplicate expected ' + aContext + ' key: ' + aExpectedKeys[i]);
      lExpected.Add(aExpectedKeys[i]);
    end;

    for lExpectedKey in lExpected do
      Assert.IsTrue(aActualKeys.IndexOf(lExpectedKey) >= 0,
        'Missing ' + aContext + ' key: ' + lExpectedKey + '. Actual keys: ' + aActualKeys.CommaText);
    for lActualKey in aActualKeys do
      Assert.IsTrue(lExpected.IndexOf(lActualKey) >= 0,
        'Unexpected ' + aContext + ' key: ' + lActualKey + '. Expected keys: ' + lExpected.CommaText);
    Assert.AreEqual(lExpected.Count, aActualKeys.Count, 'Expected ' + aContext + ' key count to match.');
  finally
    lExpected.Free;
  end;
end;

procedure AssertUnitModelMemberKeysExactly(const aModel: TDelphiSemanticUnitModel;
  const aExpectedKeys: array of string);
var
  lActualKeys: TStringList;
  lKey: string;
  lMember: TDelphiSemanticMember;
begin
  lActualKeys := TStringList.Create;
  try
    lActualKeys.Sorted := True;
    for lMember in aModel.Members do
    begin
      lKey := UnitModelMemberKey(lMember.OwnerName, lMember.Name, lMember.Kind);
      Assert.IsTrue(lActualKeys.IndexOf(lKey) < 0, 'Duplicate member key: ' + lKey);
      lActualKeys.Add(lKey);
    end;
    AssertStringKeysExactly(lActualKeys, aExpectedKeys, 'member');
  finally
    lActualKeys.Free;
  end;
end;

procedure AssertTopLevelDeclarationKeysExactly(const aModel: TDelphiSemanticUnitModel;
  const aExpectedKeys: array of string);
var
  lActualKeys: TStringList;
  lDeclaration: TDelphiSemanticDeclaration;
  lKey: string;
  lRoutine: TDelphiSemanticRoutine;
  lTopLevelRoutine: Boolean;
begin
  lActualKeys := TStringList.Create;
  try
    lActualKeys.Sorted := True;
    for lDeclaration in aModel.Declarations do
    begin
      if SameText(lDeclaration.Kind, 'routine') then
      begin
        lTopLevelRoutine := False;
        for lRoutine in aModel.Routines do
          if (lRoutine.Offset = lDeclaration.Offset) and
            SameText(lRoutine.Name, lDeclaration.Name) and
            SameText(lRoutine.SectionKind, lDeclaration.SectionKind) and
            (lRoutine.OwnerName = '') and (lRoutine.ScopeId <> '') and
            (lRoutine.ParentScopeId = '') then
          begin
            lTopLevelRoutine := True;
            Break;
          end;
        if not lTopLevelRoutine then
          Continue;
      end else if not SameText(lDeclaration.ScopeKind, 'unit') then
        Continue;
      lKey := UnitModelDeclarationKey(lDeclaration.Name, lDeclaration.Kind,
        lDeclaration.SectionKind);
      Assert.IsTrue(lActualKeys.IndexOf(lKey) < 0, 'Duplicate declaration key: ' + lKey);
      lActualKeys.Add(lKey);
    end;
    AssertStringKeysExactly(lActualKeys, aExpectedKeys, 'declaration');
  finally
    lActualKeys.Free;
  end;
end;

function TUnitModelTests.HasDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName, aKind, aSection: string): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, aKind) and
      SameText(lDeclaration.SectionKind, aSection) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasDiagnostic(const aModel: TDelphiSemanticUnitModel;
  const aCode: string): Boolean;
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  for lDiagnostic in aModel.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasMemberOfOwner(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName: string): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasMemberOnLine(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName: string; const aLine: Integer): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) and
      (lMember.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasLocal(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aName, aTypeName: string): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) and
      SameText(lLocal.TypeName, aTypeName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasLocalOnLine(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aName: string; const aLine: Integer): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) and
      (lLocal.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.FindLocal(const aModel: TDelphiSemanticUnitModel;
  const aRoutineName, aName: string; out aLocal: TDelphiSemanticLocal): Boolean;
var
  lLocal: TDelphiSemanticLocal;
begin
  for lLocal in aModel.Locals do
    if SameText(lLocal.RoutineName, aRoutineName) and SameText(lLocal.Name, aName) then
    begin
      aLocal := lLocal;
      Exit(True);
    end;

  aLocal := Default(TDelphiSemanticLocal);
  Result := False;
end;

function TUnitModelTests.HasMember(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName, aKind, aTypeName: string): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) and
      SameText(lMember.Kind, aKind) and SameText(lMember.TypeName, aTypeName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.FindDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName, aKind, aSection: string; out aDeclaration: TDelphiSemanticDeclaration): Boolean;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) and SameText(lDeclaration.Kind, aKind) and
      SameText(lDeclaration.SectionKind, aSection) then
    begin
      aDeclaration := lDeclaration;
      Exit(True);
    end;

  aDeclaration := Default(TDelphiSemanticDeclaration);
  Result := False;
end;

function TUnitModelTests.FindMember(const aModel: TDelphiSemanticUnitModel;
  const aOwnerName, aName, aKind: string; out aMember: TDelphiSemanticMember): Boolean;
var
  lMember: TDelphiSemanticMember;
begin
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) and SameText(lMember.Name, aName) and
      SameText(lMember.Kind, aKind) then
    begin
      aMember := lMember;
      Exit(True);
    end;

  aMember := Default(TDelphiSemanticMember);
  Result := False;
end;

function TUnitModelTests.HasReference(const aModel: TDelphiSemanticUnitModel;
  const aName: string): Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.ColumnOfSourceOffset(const aSource: string;
  const aOffset: Integer): Integer;
var
  i: Integer;
begin
  Result := 1;
  for i := 1 to aOffset - 1 do
    if aSource[i] = #10 then
      Result := 1
    else if aSource[i] <> #13 then
      Inc(Result);
end;

function TUnitModelTests.FindReferenceAtOffset(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aOffset: Integer; out aReference: TDelphiSemanticReference):
  Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Offset = aOffset) then
    begin
      aReference := lReference;
      Exit(True);
    end;

  aReference := Default(TDelphiSemanticReference);
  Result := False;
end;

function TUnitModelTests.HasReferenceOnLine(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aLine: Integer): Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasReferenceAtOffset(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aOffset: Integer): Boolean;
var
  lReference: TDelphiSemanticReference;
begin
  for lReference in aModel.References do
    if SameText(lReference.Name, aName) and (lReference.Offset = aOffset) and
      (lReference.EndOffset = aOffset + Length(aName)) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.FindRoutine(const aModel: TDelphiSemanticUnitModel;
  const aName, aSection: string; out aRoutine: TDelphiSemanticRoutine): Boolean;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) and SameText(lRoutine.SectionKind, aSection) then
    begin
      aRoutine := lRoutine;
      Exit(True);
    end;

  aRoutine := Default(TDelphiSemanticRoutine);
  Result := False;
end;

function TUnitModelTests.HasRoutine(const aModel: TDelphiSemanticUnitModel;
  const aName, aSection: string): Boolean;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) and SameText(lRoutine.SectionKind, aSection) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.HasRoutineOnLine(const aModel: TDelphiSemanticUnitModel;
  const aName: string; const aLine: Integer): Boolean;
var
  lRoutine: TDelphiSemanticRoutine;
begin
  for lRoutine in aModel.Routines do
    if SameText(lRoutine.Name, aName) and (lRoutine.Line = aLine) then
      Exit(True);

  Result := False;
end;

function TUnitModelTests.LineOfDeclaration(const aModel: TDelphiSemanticUnitModel;
  const aName: string): Integer;
var
  lDeclaration: TDelphiSemanticDeclaration;
begin
  for lDeclaration in aModel.Declarations do
    if SameText(lDeclaration.Name, aName) then
      Exit(lDeclaration.Line);

  Result := 0;
end;

procedure TUnitModelTests.AssertExpectedReentrantModel(const aModel: TDelphiSemanticUnitModel;
  const aUnitName, aTypeName, aRoutineName, aReferenceName: string);
begin
  Assert.IsTrue(aModel.Success, aUnitName + ' extraction failed');
  Assert.AreEqual(aUnitName, aModel.UnitName, aUnitName + ' unit name');
  Assert.IsTrue(HasDeclaration(aModel, aTypeName, 'type', 'interface'), aUnitName + ' type');
  Assert.IsTrue(HasRoutine(aModel, aRoutineName, 'interface'), aUnitName +
    ' interface routine');
  Assert.IsTrue(HasRoutine(aModel, aRoutineName, 'implementation'), aUnitName +
    ' implementation routine');
  Assert.IsTrue(HasReference(aModel, aReferenceName), aUnitName + ' reference');
end;

procedure TUnitModelTests.ExtractReentrantLoop(const aPath, aUnitName, aTypeName, aRoutineName,
  aReferenceName: string; out aError: string);
const
  cIterations = 25;
var
  i: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  aError := '';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := aPath;
  lOptions.ProjectContextApplied := True;
  for i := 1 to cIterations do
  begin
    try
      lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
      AssertExpectedReentrantModel(lModel, aUnitName, aTypeName, aRoutineName, aReferenceName);
    except
      on E: Exception do
      begin
        aError := Format('iteration=%d %s: %s', [i, E.ClassName, E.Message]);
        Exit;
      end;
    end;
  end;
end;

function TUnitModelTests.LineContaining(const aText, aPattern: string): Integer;
var
  i: Integer;
  lLine: Integer;
begin
  Result := 0;
  lLine := 1;
  for i := 1 to Length(aText) do
  begin
    if SameText(Copy(aText, i, Length(aPattern)), aPattern) then
      Exit(lLine);
    if aText[i] = #10 then
      Inc(lLine);
  end;
end;

function TUnitModelTests.StatementText(const aText: string; const aStartLine, aStartColumn,
  aEndLine, aEndColumn: Integer): string;
var
  i: Integer;
  lColumn: Integer;
  lEndOffset: Integer;
  lLine: Integer;
  lStartOffset: Integer;
begin
  lLine := 1;
  lColumn := 1;
  lStartOffset := 0;
  lEndOffset := 0;
  for i := 1 to Length(aText) do
  begin
    if (lLine = aStartLine) and (lColumn = aStartColumn) and (lStartOffset = 0) then
      lStartOffset := i;
    if (lLine = aEndLine) and (lColumn = aEndColumn) then
    begin
      lEndOffset := i;
      Break;
    end;

    if aText[i] = #10 then
    begin
      Inc(lLine);
      lColumn := 1;
    end else if aText[i] <> #13 then
      Inc(lColumn);
  end;

  if (lStartOffset = 0) or (lEndOffset = 0) then
    Exit('');

  Result := Copy(aText, lStartOffset, lEndOffset - lStartOffset + 1);
end;

procedure TUnitModelTests.SourceLoaderUsesAnsiFallbackForInvalidUtf8;
var
  lBytes: TBytes;
  lResult: TDelphiSemanticSourceLoadResult;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-ansi-source.pas');
  lBytes := [$75, $6E, $69, $74, $20, $41, $6E, $73, $69, $46, $61, $6C, $6C, $62, $61, $63,
    $6B, $3B, $0D, $0A, $69, $6E, $74, $65, $72, $66, $61, $63, $65, $0D, $0A, $2F, $2F,
    $20, $E4, $0D, $0A, $69, $6D, $70, $6C, $65, $6D, $65, $6E, $74, $61, $74, $69,
    $6F, $6E, $0D, $0A, $65, $6E, $64, $2E];
  TFile.WriteAllBytes(lPath, lBytes);

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('windows-1252', lResult.Source.EncodingName);
  Assert.IsTrue(Pos('AnsiFallback', lResult.Source.Text) > 0);
end;

procedure TUnitModelTests.SourceLoaderUsesAnsiFallbackForMalformedUtf8;
var
  lBytes: TBytes;
  lResult: TDelphiSemanticSourceLoadResult;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-overlong-source.pas');
  lBytes := [$75, $6E, $69, $74, $20, $4F, $76, $65, $72, $6C, $6F, $6E, $67, $46, $61, $6C,
    $6C, $62, $61, $63, $6B, $3B, $0D, $0A, $69, $6E, $74, $65, $72, $66, $61, $63,
    $65, $0D, $0A, $2F, $2F, $20, $C0, $AF, $0D, $0A, $69, $6D, $70, $6C, $65, $6D,
    $65, $6E, $74, $61, $74, $69, $6F, $6E, $0D, $0A, $65, $6E, $64, $2E];
  TFile.WriteAllBytes(lPath, lBytes);

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('windows-1252', lResult.Source.EncodingName);
  Assert.IsTrue(Pos('OverlongFallback', lResult.Source.Text) > 0);
end;

procedure TUnitModelTests.SourceLoaderUsesUtf16LeBom;
var
  lBody: TBytes;
  lBytes: TBytes;
  lResult: TDelphiSemanticSourceLoadResult;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-utf16le-source.pas');
  lBody := TEncoding.Unicode.GetBytes('unit Utf16Bom;' + sLineBreak +
    'interface' + sLineBreak +
    '// Caf' + Char($00E9) + sLineBreak +
    'implementation' + sLineBreak +
    'end.');
  SetLength(lBytes, Length(lBody) + 2);
  lBytes[0] := $FF;
  lBytes[1] := $FE;
  Move(lBody[0], lBytes[2], Length(lBody));
  TFile.WriteAllBytes(lPath, lBytes);

  lResult := TDelphiSemanticSourceLoader.LoadFile(lPath);

  Assert.IsTrue(lResult.Success);
  Assert.AreEqual('utf-16le', lResult.Source.EncodingName);
  Assert.IsTrue(Pos('Caf' + Char($00E9), lResult.Source.Text) > 0);
end;

procedure TUnitModelTests.ExtractsOnlyActiveUsesOutsideCommentsAndStrings;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSource: string;
begin
  lSource := 'unit LexicalImports;' + sLineBreak + 'interface' + sLineBreak +
    '{ implementation uses HiddenBrace; }' + sLineBreak +
    '// uses HiddenLine;' + sLineBreak +
    '(* uses HiddenParen; *)' + sLineBreak +
    'uses ActiveInterface, { uses HiddenInline; }' + sLineBreak +
    '{$IFDEF IMPORT_ACTIVE}' + sLineBreak +
    '  ActiveConditional;' + sLineBreak +
    '{$ELSE}' + sLineBreak +
    '  HiddenInactive;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    'const cNoise = ''uses HiddenString;'';' + sLineBreak +
    'implementation' + sLineBreak +
    '// uses HiddenImplementation;' + sLineBreak +
    'uses ActiveImplementation;' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('lexical-imports.pas');
  lOptions.ProjectContextApplied := True;
  lOptions.Defines := ['IMPORT_ACTIVE'];
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(2, Integer(Length(lModel.InterfaceUses)),
    'Only active interface imports establish type visibility.');
  Assert.AreEqual('ActiveInterface', lModel.InterfaceUses[0]);
  Assert.AreEqual('ActiveConditional', lModel.InterfaceUses[1]);
  Assert.AreEqual(1, Integer(Length(lModel.ImplementationUses)),
    'Comments and string literals do not import units.');
  Assert.AreEqual('ActiveImplementation', lModel.ImplementationUses[0]);
end;

procedure TUnitModelTests.ExtractsUnitNameUsesDeclarationsAndWithStatements;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SemanticUnit', lModel.UnitName);
  Assert.AreEqual('utf-8', lModel.EncodingName);
  Assert.AreEqual(2, Integer(Length(lModel.InterfaceUses)));
  Assert.AreEqual('System.SysUtils', lModel.InterfaceUses[0]);
  Assert.AreEqual('Winapi.Windows', lModel.InterfaceUses[1]);
  Assert.AreEqual(1, Integer(Length(lModel.ImplementationUses)));
  Assert.AreEqual('System.Classes', lModel.ImplementationUses[0]);
  Assert.IsTrue(HasDeclaration(lModel, 'TSemanticEnum', 'type', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'seOne', 'enum-value', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TSemanticAlias', 'type-alias', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TSemanticRecord', 'type', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TAfterClassType', 'type', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'cSemanticConst', 'const', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'GSemanticGlobal', 'var', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'SemanticProcedure', 'routine', 'interface'));
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.AreNotEqual(0, lModel.WithStatements[0].Line);
end;

procedure TUnitModelTests.ExtractsMembersRoutinesLocalsAndReferences;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasMember(lModel, 'TSemanticRecord', 'Value', 'field', 'Integer'));
  Assert.IsTrue(HasMember(lModel, 'TSemanticClass', 'FName', 'field', 'string'));
  Assert.IsTrue(HasMember(lModel, 'TSemanticClass', 'Name', 'property', 'string'));
  Assert.IsTrue(HasRoutine(lModel, 'SemanticProcedure', 'interface'));
  Assert.IsTrue(HasRoutine(lModel, 'SetName', 'implementation'));
  Assert.IsFalse(HasDeclaration(lModel, 'SetName', 'routine', 'interface'));
  Assert.IsTrue(HasLocal(lModel, 'SemanticProcedure', 'lRecord', 'TSemanticRecord'));
  Assert.IsTrue(HasReference(lModel, 'Value'));
  Assert.IsTrue(HasReference(lModel, 'Length'));
  Assert.IsTrue(HasReference(lModel, 'SemanticGlobal'));
end;

procedure TUnitModelTests.ExtractsConstructorAndDestructorScopesAndLocals;
var
  lLocal: TDelphiSemanticLocal;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRoutine: TDelphiSemanticRoutine;
begin
  lPath := UnitModelTempPath('unit-model-lifecycle-scopes.pas');
  TFile.WriteAllText(lPath,
    'unit LifecycleScopesUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TStore = class' + sLineBreak +
    '    constructor Create;' + sLineBreak +
    '    destructor Destroy; override;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'constructor TStore.Create;' + sLineBreak +
    'var' + sLineBreak +
    '  lValue: Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  lValue := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'destructor TStore.Destroy;' + sLineBreak +
    'var' + sLineBreak +
    '  lValue: Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  lValue := 2;' + sLineBreak +
    '  inherited;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindRoutine(lModel, 'Create', 'implementation', lRoutine));
  Assert.AreEqual('TStore', lRoutine.OwnerName);
  Assert.IsNotEmpty(lRoutine.ScopeId);
  Assert.IsTrue(FindLocal(lModel, 'TStore.Create', 'lValue', lLocal));
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
  Assert.IsTrue(FindRoutine(lModel, 'Destroy', 'implementation', lRoutine));
  Assert.AreEqual('TStore', lRoutine.OwnerName);
  Assert.IsNotEmpty(lRoutine.ScopeId);
  Assert.IsTrue(FindLocal(lModel, 'TStore.Destroy', 'lValue', lLocal));
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
end;

procedure TUnitModelTests.ExtractsCommaDeclaredRoutineLocals;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-comma-locals.pas');
  TFile.WriteAllText(lPath,
    'unit CommaLocalsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lLeft, lRight: Integer;' + sLineBreak +
    '  lPtr, lOtherPtr: PChar;' + sLineBreak +
    'begin' + sLineBreak +
    '  lRight := lLeft;' + sLineBreak +
    '  lOtherPtr := lPtr;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasLocal(lModel, 'Run', 'lLeft', 'Integer'));
  Assert.IsTrue(HasLocal(lModel, 'Run', 'lRight', 'Integer'));
  Assert.IsTrue(HasLocal(lModel, 'Run', 'lPtr', 'PChar'));
  Assert.IsTrue(HasLocal(lModel, 'Run', 'lOtherPtr', 'PChar'));
end;

procedure TUnitModelTests.RoutineLocalsSurviveSameLineVarSections;
var
  lInner: TDelphiSemanticRoutine;
  lLocal: TDelphiSemanticLocal;
  lModel: TDelphiSemanticUnitModel;
  lName: string;
  lOptions: TDelphiSemanticModelOptions;
  lOuter: TDelphiSemanticRoutine;
  lPath: string;
  lSource: string;
begin
  lPath := UnitModelTempPath('unit-model-same-line-locals.pas');
  lSource :=
    'unit SameLineLocalsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'type TNode = record Value: Integer; end;' + sLineBreak +
    'procedure Outer;' + sLineBreak +
    'type TLocalRecord = record lField: Integer; end;' + sLineBreak +
    'const cText = ''var lString: Integer;'';' + sLineBreak +
    'label 1;' + sLineBreak +
    'var lNode: TNode; lPointer: ^TNode; lLeft, lRight, lThird: Integer;' + sLineBreak +
    '// var lComment: Integer;' + sLineBreak +
    'procedure Inner;' + sLineBreak +
    'var lInner: TNode;' + sLineBreak +
    'begin' + sLineBreak +
    '  lInner.Value := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'begin' + sLineBreak +
    '  1: lPointer := @lNode;' + sLineBreak +
    '  lLeft := lRight + lThird;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success, 'The source-backed unit must parse.');
  Assert.IsTrue(FindRoutine(lModel, 'Outer', 'implementation', lOuter),
    'Outer routine must be extracted from the fixture.');
  Assert.IsTrue(FindRoutine(lModel, 'Inner', 'implementation', lInner),
    'Nested Inner routine must be extracted from the fixture.');
  Assert.IsNotEmpty(lOuter.ScopeId, 'Outer AST scope must be verified.');
  Assert.IsNotEmpty(lInner.ScopeId, 'Inner AST scope must be verified.');
  Assert.AreEqual(lOuter.ScopeId, lInner.ParentScopeId,
    'Inner must belong to Outer AST scope.');
  Assert.AreNotEqual(lOuter.ScopeId, lInner.ScopeId,
    'Nested routine must have its own AST scope.');
  Assert.IsTrue(FindLocal(lModel, 'Outer', 'lNode', lLocal),
    'Outer lNode declaration must be extracted.');
  Assert.AreEqual('TNode', lLocal.TypeName, 'Outer lNode declared type.');
  Assert.AreEqual(Pos('lNode: TNode', lSource), lLocal.Offset);
  Assert.AreEqual(lLocal.Offset + Length(lLocal.Name), lLocal.EndOffset);
  Assert.AreEqual(9, lLocal.Line);
  Assert.AreEqual(ColumnOfSourceOffset(lSource, lLocal.Offset), lLocal.Column);
  Assert.AreEqual(lOuter.ScopeId, lLocal.RoutineScopeId);
  Assert.IsTrue(FindLocal(lModel, 'Outer', 'lPointer', lLocal),
    'Outer lPointer declaration must be extracted.');
  Assert.AreEqual('^TNode', lLocal.TypeName, 'Outer lPointer declared type.');
  Assert.AreEqual(Pos('lPointer: ^TNode', lSource), lLocal.Offset);
  Assert.AreEqual(lLocal.Offset + Length(lLocal.Name), lLocal.EndOffset);
  Assert.AreEqual(9, lLocal.Line);
  Assert.AreEqual(ColumnOfSourceOffset(lSource, lLocal.Offset), lLocal.Column);
  Assert.AreEqual(lOuter.ScopeId, lLocal.RoutineScopeId);
  for lName in ['lLeft', 'lRight', 'lThird'] do
  begin
    Assert.IsTrue(FindLocal(lModel, 'Outer', lName, lLocal),
      'Outer comma declaration must include ' + lName);
    Assert.AreEqual('Integer', lLocal.TypeName, 'Declared type of ' + lName);
    Assert.AreEqual(Pos(lName, lSource), lLocal.Offset);
    Assert.AreEqual(lLocal.Offset + Length(lName), lLocal.EndOffset);
    Assert.AreEqual(9, lLocal.Line);
    Assert.AreEqual(ColumnOfSourceOffset(lSource, lLocal.Offset), lLocal.Column);
    Assert.AreEqual(lOuter.ScopeId, lLocal.RoutineScopeId);
  end;
  Assert.IsTrue(FindLocal(lModel, 'Inner', 'lInner', lLocal),
    'Inner lInner declaration must be extracted.');
  Assert.AreEqual('TNode', lLocal.TypeName, 'Inner lInner declared type.');
  Assert.AreEqual(Pos('lInner: TNode', lSource), lLocal.Offset);
  Assert.AreEqual(12, lLocal.Line);
  Assert.AreEqual(ColumnOfSourceOffset(lSource, lLocal.Offset), lLocal.Column);
  Assert.AreEqual(lInner.ScopeId, lLocal.RoutineScopeId);
  Assert.IsFalse(FindLocal(lModel, 'Outer', 'lInner', lLocal),
    'Nested local must not leak into Outer.');
  Assert.IsFalse(FindLocal(lModel, 'Outer', 'lField', lLocal),
    'Record field must not become a routine local.');
  Assert.IsFalse(FindLocal(lModel, 'Outer', 'lString', lLocal),
    'String content must not become a routine local.');
  Assert.IsFalse(FindLocal(lModel, 'Outer', 'lComment', lLocal),
    'Comment content must not become a routine local.');
end;

procedure TUnitModelTests.RoutineProceduralObjectLocalsKeepAstScopeModel;
var
  lLocal: TDelphiSemanticLocal;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRoutine: TDelphiSemanticRoutine;
  lSource: string;
begin
  // "of object" ends a procedural type; it opens no structure that a later "end" closes.
  lPath := UnitModelTempPath('unit-model-procedural-object-locals.pas');
  lSource :=
    'unit ProceduralObjectLocalsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'procedure UsePoint;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure UsePoint;' + sLineBreak +
    'var' + sLineBreak +
    '  lEvent: procedure(a: Integer) of object;' + sLineBreak +
    '  lQuery: function: Integer of object;' + sLineBreak +
    '  lAfter: Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  lEvent := nil;' + sLineBreak +
    '  lQuery := nil;' + sLineBreak +
    '  lAfter := 0;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success, 'The source-backed unit must parse.');
  Assert.IsFalse(HasDiagnostic(lModel, 'SCOPE_MODEL_FAILED'),
    'Procedural object locals must not abandon the AST scope model.');
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindRoutine(lModel, 'UsePoint', 'implementation', lRoutine));
  Assert.IsNotEmpty(lRoutine.ScopeId, 'UsePoint AST scope must be verified.');
  Assert.IsTrue(FindLocal(lModel, 'UsePoint', 'lEvent', lLocal), 'lEvent must be extracted.');
  Assert.AreEqual('procedure(a: Integer) of object', lLocal.TypeName);
  Assert.AreEqual(Pos('lEvent:', lSource), lLocal.Offset);
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
  Assert.IsTrue(FindLocal(lModel, 'UsePoint', 'lQuery', lLocal), 'lQuery must be extracted.');
  Assert.AreEqual('function: Integer of object', lLocal.TypeName);
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
  Assert.IsTrue(FindLocal(lModel, 'UsePoint', 'lAfter', lLocal), 'lAfter must be extracted.');
  Assert.AreEqual('Integer', lLocal.TypeName);
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
end;

function TUnitModelTests.AnonymousRecordLocalModel(out aSource: string): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-anonymous-record-locals.pas');
  aSource :=
    'unit AnonymousRecordLocalsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TChild = record' + sLineBreak +
    '    Name: string;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TScope = class' + sLineBreak +
    '  public' + sLineBreak +
    '    class procedure Run;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'class procedure TScope.Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lAnonymous: packed record' + sLineBreak +
    '    Value: TChild;' + sLineBreak +
    '  end;' + sLineBreak +
    '  lInline: record Count: Integer; end; lAfter: Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  lAnonymous.Value.Name := '''';' + sLineBreak +
    '  lInline.Count := lAfter;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, aSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
end;

procedure TUnitModelTests.RoutineAnonymousRecordLocalsUseSyntheticOwnerType;
var
  lLocal: TDelphiSemanticLocal;
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lSource: string;
begin
  // An anonymous record has no declaration of its own; like a unit-level one, it is named after
  // its owner, here the routine that declares the local.
  lModel := AnonymousRecordLocalModel(lSource);

  Assert.IsTrue(lModel.Success, 'The source-backed unit must parse.');
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindRoutine(lModel, 'Run', 'implementation', lRoutine));
  Assert.IsNotEmpty(lRoutine.ScopeId, 'TScope.Run AST scope must be verified.');
  Assert.IsTrue(FindLocal(lModel, 'TScope.Run', 'lAnonymous', lLocal),
    'lAnonymous must be extracted.');
  Assert.AreEqual('TScope.Run.lAnonymous', lLocal.TypeName,
    'An anonymous record local is typed by its synthetic owner name.');
  Assert.AreEqual(Pos('lAnonymous:', lSource), lLocal.Offset);
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
  Assert.IsTrue(FindLocal(lModel, 'TScope.Run', 'lInline', lLocal), 'lInline must be extracted.');
  Assert.AreEqual('TScope.Run.lInline', lLocal.TypeName);
  Assert.AreEqual(Pos('lInline:', lSource), lLocal.Offset);
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
  Assert.IsTrue(FindLocal(lModel, 'TScope.Run', 'lAfter', lLocal),
    'A declaration after an inline record on the same line must be extracted.');
  Assert.AreEqual('Integer', lLocal.TypeName);
  Assert.AreEqual(Pos('lAfter:', lSource), lLocal.Offset);
  Assert.AreEqual(lRoutine.ScopeId, lLocal.RoutineScopeId);
  Assert.IsFalse(FindLocal(lModel, 'TScope.Run', 'Value', lLocal),
    'A record field must not become a routine local.');
  Assert.IsFalse(FindLocal(lModel, 'TScope.Run', 'Count', lLocal),
    'An inline record field must not become a routine local.');
end;

procedure TUnitModelTests.RoutineAnonymousRecordLocalsKeepSyntheticInventoryOwner;
var
  lIndex: TDelphiSemanticRemoveWithLookupIndex;
  lLocalCount: Integer;
  lMembers: TArray<TDelphiSemanticInventorySymbol>;
  lModel: TDelphiSemanticUnitModel;
  lSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbols: TArray<TDelphiSemanticInventorySymbol>;
begin
  // WITH consumers resolve the local through the lookup index; its type must name the
  // synthetic owner that carries the record fields.
  lModel := AnonymousRecordLocalModel(lSource);
  Assert.IsTrue(lModel.Success, 'The source-backed unit must parse.');
  lSymbols := TDelphiSemanticWithBindingInventory.BuildInventorySymbols(lModel);
  lIndex := TDelphiSemanticRemoveWithLookupIndex.Build([lModel], lSymbols);

  // Consumers may pick any of the local's inventory symbols, so none may disagree.
  lLocalCount := 0;
  for lSymbol in lSymbols do
    if SameText(lSymbol.SymbolClass, 'local') and SameText(lSymbol.Name, 'lAnonymous') then
    begin
      Inc(lLocalCount);
      Assert.AreEqual('TScope.Run.lAnonymous', lSymbol.TypeName,
        'Every inventory symbol of lAnonymous must name its synthetic owner.');
    end;
  Assert.IsTrue(lLocalCount > 0, 'lAnonymous must have an inventory symbol.');
  Assert.IsTrue(lIndex.FindRoutineSymbol('TScope.Run', 'lAnonymous', lSymbol),
    'lAnonymous must be visible to the routine lookup.');
  Assert.AreEqual('TScope.Run.lAnonymous', lSymbol.TypeName,
    'The routine lookup must type lAnonymous by its synthetic owner.');
  Assert.IsTrue(Length(lIndex.FindDeclarationOrTypeAliasByName('TScope.Run.lAnonymous')) > 0,
    'The synthetic owner type must be indexed.');
  lMembers := lIndex.FindMembersByOwnerAndName('TScope.Run.lAnonymous', 'Value');
  Assert.IsTrue(Length(lMembers) > 0, 'The synthetic owner must carry the Value field.');
  Assert.AreEqual('TChild', lMembers[0].TypeName);
end;

function TUnitModelTests.DefaultParameterSource(const aShape: string): string;
const
  cHeader = 'procedure Run(aValue: Integer = ProviderAlpha.AlphaOnlyValue);';
begin
  Result := 'unit ParameterDefaults;' + sLineBreak + 'interface' + sLineBreak +
    'uses ProviderAlpha;' + sLineBreak;
  if aShape = 'method' then
    Result := Result + 'type TWorker = class' + sLineBreak + cHeader + sLineBreak +
      'end;' + sLineBreak
  else if aShape = 'global' then
    Result := Result + cHeader + sLineBreak;
  Result := Result + 'implementation' + sLineBreak;
  if aShape = 'method' then
    Result := Result + 'procedure TWorker.Run(aValue: Integer);'
  else if aShape = 'private' then
    Result := Result + cHeader
  else
    Result := Result + 'procedure Run(aValue: Integer);';
  Result := Result + sLineBreak + 'begin end;' + sLineBreak + 'end.';
end;

procedure TUnitModelTests.ExtractsDefaultParameterReferences(
  const aShape: string; const aLean: Boolean);
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lText: string;
  lReference: TDelphiSemanticReference;
  lOffset: Integer;
  lCount: Integer;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\.dak\delphiSemanticsTests\refactoring-light-default-references\' + aShape + '.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lPath));
  lText := DefaultParameterSource(aShape);
  TFile.WriteAllText(lPath, lText, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lOptions.SkipBodyAnalysis := aLean;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lOffset := Pos('AlphaOnlyValue', lText);
  Assert.IsTrue(FindReferenceAtOffset(lModel, 'AlphaOnlyValue', lOffset, lReference),
    'The default expression reference must retain its original offset');
  Assert.AreEqual(ColumnOfSourceOffset(lText, lOffset), lReference.Column);
  Assert.AreEqual(lOffset + Length('AlphaOnlyValue'), lReference.EndOffset);
  Assert.AreEqual(LineContaining(lText, 'ProviderAlpha.AlphaOnlyValue'), lReference.Line);
  Assert.IsNotEmpty(lReference.RoutineScopeId);
  if aShape = 'private' then
    Assert.AreEqual('implementation', lReference.SectionKind)
  else
    Assert.AreEqual('interface', lReference.SectionKind);
  lCount := 0;
  for lReference in lModel.References do
    if lReference.Name = 'AlphaOnlyValue' then
      Inc(lCount);
  Assert.AreEqual(1, lCount, 'A default expression has one source occurrence');
end;

procedure TUnitModelTests.DefaultParameterStringsAndCommentsDoNotCreateReferences;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\.dak\delphiSemanticsTests\refactoring-light-default-references\literals.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lPath));
  TFile.WriteAllText(lPath, 'unit DefaultLiterals; interface' + sLineBreak +
    'procedure Run(aText: string = ''FakeValue'';' + sLineBreak +
    'aValue: Integer = 1 {CommentValue}; aPointer: Pointer = nil);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run(aText: string; aValue: Integer; aPointer: Pointer);' +
    sLineBreak + 'begin end; end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsFalse(HasReference(lModel, 'FakeValue'));
  Assert.IsFalse(HasReference(lModel, 'CommentValue'));
  Assert.IsFalse(HasReference(lModel, 'nil'));
end;

procedure TUnitModelTests.SkipsDefaultParameterReferencesWhenExtractionDisabled;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := TPath.Combine(ExtractFilePath(ParamStr(0)),
    '..\.dak\delphiSemanticsTests\refactoring-light-default-references\skipped.pas');
  TDirectory.CreateDirectory(TPath.GetDirectoryName(lPath));
  TFile.WriteAllText(lPath, DefaultParameterSource('global'), TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lOptions.SkipReferenceExtraction := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasRoutine(lModel, 'Run', 'interface'));
  Assert.AreEqual(0, Integer(Length(lModel.References)));
end;

procedure TUnitModelTests.SkipReferenceExtractionKeepsSymbolsAndOmitsReferences;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;
  lOptions.SkipReferenceExtraction := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'TSemanticRecord', 'type', 'interface'));
  Assert.IsTrue(HasMember(lModel, 'TSemanticRecord', 'Value', 'field', 'Integer'));
  Assert.IsTrue(HasRoutine(lModel, 'SemanticProcedure', 'interface'));
  Assert.IsTrue(HasLocal(lModel, 'SemanticProcedure', 'lRecord', 'TSemanticRecord'));
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.AreEqual(0, Integer(Length(lModel.References)));
  Assert.IsFalse(lModel.PhysicalReferenceOccurrencesAvailable,
    'Skipped extraction cannot prove there are no physical references');
end;

procedure TUnitModelTests.ExtractsUntypedRoutineParameters;
const
  cSections: array[0..1] of string = ('interface', 'implementation');
  cLines: array[0..1] of Integer = (12, 26);
var
  i: Integer;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoutine: TDelphiSemanticRoutine;
  lSymbol: TDelphiSemanticInventorySymbol;
  lSymbolFound: Boolean;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'UntypedParameterUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindRoutine(lModel, 'Run', 'implementation', lRoutine),
    'Expected implementation routine.');
  Assert.AreEqual('TUntypedParameterScope', lRoutine.OwnerName);
  Assert.AreEqual(2, Integer(Length(lRoutine.Parameters)));
  Assert.AreEqual('aValue', lRoutine.Parameters[0].Name);
  Assert.AreEqual('', lRoutine.Parameters[0].TypeName);
  Assert.AreEqual('const', lRoutine.Parameters[0].Modifier);
  Assert.AreEqual('aOther', lRoutine.Parameters[1].Name);
  Assert.AreEqual('', lRoutine.Parameters[1].TypeName);
  Assert.AreEqual('var', lRoutine.Parameters[1].Modifier);

  Assert.IsTrue(FindRoutine(lModel, 'RunMixed', 'implementation', lRoutine),
    'Expected mixed untyped-parameter routine.');
  Assert.AreEqual(3, Integer(Length(lRoutine.Parameters)));
  Assert.AreEqual('aFirst', lRoutine.Parameters[0].Name);
  Assert.AreEqual('Integer', lRoutine.Parameters[0].TypeName);
  Assert.AreEqual('aUntyped', lRoutine.Parameters[1].Name);
  Assert.AreEqual('', lRoutine.Parameters[1].TypeName);
  Assert.AreEqual('var', lRoutine.Parameters[1].Modifier);
  Assert.AreEqual('aLast', lRoutine.Parameters[2].Name);
  Assert.AreEqual('Integer', lRoutine.Parameters[2].TypeName);

  lSymbolFound := False;
  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  for lSymbol in lInventory.Symbols do
    if SameText(lSymbol.SymbolClass, 'parameter') and SameText(lSymbol.Name, 'aValue') then
    begin
      Assert.AreEqual('TUntypedParameterScope.Run', lSymbol.RoutineName);
      lSymbolFound := True;
    end;
  Assert.IsTrue(lSymbolFound, 'Expected inventory parameter symbol.');

  lSymbolFound := False;
  for lSymbol in lInventory.Symbols do
    if SameText(lSymbol.SymbolClass, 'parameter') and
      SameText(lSymbol.Name, 'aInventoryUntyped') then
    begin
      Assert.AreEqual('RunInventory', lSymbol.RoutineName);
      Assert.AreEqual('', lSymbol.TypeName);
      lSymbolFound := True;
    end;
  Assert.IsTrue(lSymbolFound, 'Expected multiline untyped inventory parameter symbol.');

  for i := Low(cSections) to High(cSections) do
  begin
    Assert.IsTrue(FindRoutine(lModel, 'RunInventory', cSections[i], lRoutine),
      'Expected multiline ' + cSections[i] + ' routine model.');
    Assert.AreEqual('', lRoutine.OwnerName);
    Assert.AreEqual('Integer', lRoutine.ReturnType);
    Assert.AreEqual(cLines[i], lRoutine.Line);
    Assert.AreEqual(10, lRoutine.Column);
    Assert.AreEqual('(aFirst: Integer;' + sLineBreak +
      '  var aInventoryUntyped; aLast: Integer)', lRoutine.Signature);
    Assert.AreEqual(3, Integer(Length(lRoutine.Parameters)));
    Assert.AreEqual('aFirst', lRoutine.Parameters[0].Name);
    Assert.AreEqual('Integer', lRoutine.Parameters[0].TypeName);
    Assert.AreEqual('', lRoutine.Parameters[0].Modifier);
    Assert.AreEqual(cLines[i], lRoutine.Parameters[0].Line);
    Assert.AreEqual(23, lRoutine.Parameters[0].Column);
    Assert.AreEqual('aInventoryUntyped', lRoutine.Parameters[1].Name);
    Assert.AreEqual('', lRoutine.Parameters[1].TypeName);
    Assert.AreEqual('var', lRoutine.Parameters[1].Modifier);
    Assert.AreEqual(cLines[i] + 1, lRoutine.Parameters[1].Line);
    Assert.AreEqual(7, lRoutine.Parameters[1].Column);
    Assert.AreEqual('aLast', lRoutine.Parameters[2].Name);
    Assert.AreEqual('Integer', lRoutine.Parameters[2].TypeName);
    Assert.AreEqual('', lRoutine.Parameters[2].Modifier);
    Assert.AreEqual(cLines[i] + 1, lRoutine.Parameters[2].Line);
    Assert.AreEqual(26, lRoutine.Parameters[2].Column);
  end;
end;

procedure TUnitModelTests.IncompleteRoutineHeaderPreservesFollowingDeclaration(
  const aCase: Integer);
const
  cBrokenHeaders: array[0..1] of string = ('function Broken: Integer', 'procedure Broken(');
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoutine: TDelphiSemanticRoutine;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('incomplete-header-' + IntToStr(aCase) + '.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, 'unit IncompleteHeader;' + sLineBreak +
    'interface' + sLineBreak + cBrokenHeaders[aCase] + sLineBreak +
    'procedure Following;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure Following;' + sLineBreak + 'begin' + sLineBreak + 'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(FindRoutine(lModel, 'Following', 'interface', lRoutine),
    'An incomplete header must not consume the following declaration.');
  Assert.AreEqual(4, lRoutine.Line);
  Assert.AreEqual(11, lRoutine.Column);
  Assert.AreEqual('', lRoutine.Signature);
  Assert.AreEqual('', lRoutine.ReturnType);
  Assert.IsTrue(HasRoutine(lModel, 'Following', 'implementation'));
  Assert.IsFalse(HasRoutine(lModel, 'Broken', 'interface'),
    'An incomplete header must not create a routine model.');
end;

procedure TUnitModelTests.RoutineHeaderExtentPreservesDelimitersAndCommentBoundaries;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoutine: TDelphiSemanticRoutine;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('RemoveWithMultilineHeaders', 'MultilineHeadersUnit.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindRoutine(lModel, 'HeaderExtent', 'interface', lRoutine));
  Assert.AreEqual('(aCount: Integer = (1 + (2));' + sLineBreak +
    '  aText: string = ''(x)''' + sLineBreak + '  {' + sLineBreak +
    'procedure Fake;' + sLineBreak + '  }' + sLineBreak + '  )', lRoutine.Signature);
  Assert.AreEqual('Integer', lRoutine.ReturnType);
  Assert.IsFalse(HasReference(lModel, 'x'), 'A string default is not a type reference.');
  Assert.IsFalse(HasReference(lModel, 'Fake'), 'A comment is not a type reference.');
  Assert.AreEqual(2, Integer(Length(lRoutine.Parameters)));
  Assert.AreEqual('aCount', lRoutine.Parameters[0].Name);
  Assert.AreEqual('Integer', lRoutine.Parameters[0].TypeName);
  Assert.AreEqual('aText', lRoutine.Parameters[1].Name);
  Assert.AreEqual('string', lRoutine.Parameters[1].TypeName);
  Assert.AreEqual(18, lRoutine.Parameters[0].Line);
  Assert.AreEqual(23, lRoutine.Parameters[0].Column);
  Assert.AreEqual(19, lRoutine.Parameters[1].Line);
  Assert.AreEqual(3, lRoutine.Parameters[1].Column);
  Assert.IsFalse(HasRoutine(lModel, 'Fake', 'interface'));
  Assert.IsTrue(HasRoutine(lModel, 'SingleLine', 'implementation'));
  Assert.IsTrue(HasRoutine(lModel, 'HeaderExtent', 'implementation'));
end;

procedure TUnitModelTests.ExtractsRoutineAfterSingleLineGuidInterface;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'GuidInterfaceRoutineUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(HasDeclaration(lModel, 'IGuidInline', 'type', 'interface'));
  Assert.IsTrue(HasRoutine(lModel, 'RoutineAfterGuidInterface', 'interface'));
end;

procedure TUnitModelTests.ExtractsAnonymousNestedRecordMembers;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'NestedAnonymousRecordUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindMember(lModel, 'DBF_File', 'Struktur', 'field', lMember));
  Assert.AreEqual('DBF_File.Struktur', lMember.TypeName);
  Assert.IsTrue(HasMember(lModel, 'DBF_File.Struktur', 'Version', 'field', 'Byte'));
  Assert.IsTrue(HasMember(lModel, 'DBF_File.Struktur', 'RecSize', 'field', 'Integer'));
end;

procedure TUnitModelTests.ExtractsUnprefixedConstVarAndTypedConstDeclarations;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'PlainSemanticConst', 'const', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'TypedSemanticConst', 'typed-const', 'interface'));
  Assert.IsFalse(HasDeclaration(lModel, 'PlainSemanticConst', 'type-alias', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'SemanticGlobal', 'var', 'interface'));
end;

procedure TUnitModelTests.PreservesUnitConstantsAcrossLineLayouts(const aCompact: Boolean);
var
  lPath, lSource: string;
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lCount: Integer;
begin
  lSource := 'unit CompactConstantFacts; interface const Alpha = 1; Beta = -2; ' +
    'implementation const Gamma = 3; end.';
  if not aCompact then
    lSource := lSource.Replace('; ', ';' + sLineBreak).Replace('interface const ',
      'interface' + sLineBreak + 'const' + sLineBreak).Replace('implementation const ',
      'implementation' + sLineBreak + 'const' + sLineBreak);
  lPath := UnitModelTempPath('compact-constant-facts-' + BoolToStr(aCompact, True) + '.pas');
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'Alpha', 'const', 'interface', lDeclaration), 'Alpha');
  Assert.IsTrue(FindDeclaration(lModel, 'Beta', 'const', 'interface', lDeclaration), 'Beta');
  Assert.IsTrue(FindDeclaration(lModel, 'Gamma', 'const', 'implementation', lDeclaration), 'Gamma');
  lCount := 0;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Kind, 'const') then
    begin
      Inc(lCount);
      Assert.AreEqual('unit', lDeclaration.ScopeKind);
      Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
      Assert.AreEqual(lDeclaration.Name, Copy(lSource, lDeclaration.Offset, Length(lDeclaration.Name)));
      Assert.AreEqual(lDeclaration.Offset + Length(lDeclaration.Name), lDeclaration.EndOffset);
      Assert.IsFalse(lDeclaration.Mutable);
    end;
  Assert.AreEqual(3, lCount, 'Each syntax-backed constant must occur once');
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsUnitNameAndUsesSections;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SymbolMapUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SymbolMapUnit', lModel.UnitName);
  Assert.AreEqual(lOptions.SourceFileName, lModel.FileName);
  Assert.AreEqual('utf-8', lModel.EncodingName);
  Assert.AreEqual(2, Integer(Length(lModel.InterfaceUses)));
  Assert.AreEqual('System.SysUtils', lModel.InterfaceUses[0]);
  Assert.AreEqual('Winapi.Windows', lModel.InterfaceUses[1]);
  Assert.AreEqual(2, Integer(Length(lModel.ImplementationUses)));
  Assert.AreEqual('System.Classes', lModel.ImplementationUses[0]);
  Assert.AreEqual('System.Generics.Collections', lModel.ImplementationUses[1]);
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsNamespacedUnitName;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('symbol-map-namespaced-unit.pas');
  TFile.WriteAllText(lPath, 'unit Foo.Bar;' + sLineBreak + 'interface' + sLineBreak +
    'uses System.SysUtils;' + sLineBreak + 'implementation' + sLineBreak + 'end.',
    TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('Foo.Bar', lModel.UnitName);
  Assert.AreEqual('System.SysUtils', lModel.InterfaceUses[0]);
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsTopLevelDeclarationsAndEnumValues;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoutine: TDelphiSemanticRoutine;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SymbolMapDeclarations.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SymbolMapDeclarations', lModel.UnitName);
  AssertTopLevelDeclarationKeysExactly(lModel, [
    'TDeclarationEnum:type:interface',
    'deOne:enum-value:interface',
    'deTwo:enum-value:interface',
    'TDeclarationAlias:type-alias:interface',
    'TDeclarationRecord:type:interface',
    'TDeclarationClass:type:interface',
    'cDeclarationConst:const:interface',
    'cDeclarationTyped:typed-const:interface',
    'GDeclarationGlobal:var:interface',
    'cImplementationConst:const:implementation',
    'GImplementationGlobal:var:implementation',
    'DeclarationProcedure:routine:interface',
    'DeclarationFunction:routine:interface',
    'DeclarationMultiParam:routine:interface',
    'DeclarationProcedure:routine:implementation',
    'DeclarationFunction:routine:implementation',
    'DeclarationMultiParam:routine:implementation',
    'ImplementationOnlyProcedure:routine:implementation']);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationEnum', 'type', 'interface', lDeclaration));
  Assert.AreEqual('enum', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'deOne', 'enum-value', 'interface', lDeclaration));
  Assert.AreEqual('TDeclarationEnum', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'deTwo', 'enum-value', 'interface', lDeclaration));
  Assert.AreEqual('TDeclarationEnum', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationAlias', 'type-alias', 'interface',
    lDeclaration));
  Assert.AreEqual('string', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationRecord', 'type', 'interface',
    lDeclaration));
  Assert.AreEqual('record', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'TDeclarationClass', 'type', 'interface',
    lDeclaration));
  Assert.AreEqual('class', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'cDeclarationConst', 'const', 'interface',
    lDeclaration));
  Assert.IsTrue(FindDeclaration(lModel, 'cDeclarationTyped', 'typed-const', 'interface',
    lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'GDeclarationGlobal', 'var', 'interface',
    lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'DeclarationProcedure', 'routine', 'interface',
    lDeclaration));
  Assert.IsTrue(FindRoutine(lModel, 'DeclarationProcedure', 'interface', lRoutine));
  Assert.IsTrue(Pos('const aName: string', lRoutine.Signature) > 0);
  Assert.IsTrue(FindDeclaration(lModel, 'DeclarationFunction', 'routine', 'interface',
    lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'DeclarationMultiParam', 'routine', 'interface',
    lDeclaration));
  Assert.AreEqual('Boolean', lDeclaration.TypeName);
  Assert.IsTrue(FindRoutine(lModel, 'DeclarationMultiParam', 'interface', lRoutine));
  Assert.IsTrue(Pos('const aName: string; const aValue: Integer', lRoutine.Signature) > 0);
  Assert.IsTrue(FindDeclaration(lModel, 'ImplementationOnlyProcedure', 'routine',
    'implementation', lDeclaration));
  Assert.IsTrue(FindRoutine(lModel, 'ImplementationOnlyProcedure', 'implementation',
    lRoutine));
  Assert.IsNotEmpty(lRoutine.ScopeId);
  Assert.IsTrue(FindDeclaration(lModel, 'cImplementationConst', 'const', 'implementation',
    lDeclaration));
  Assert.IsTrue(FindDeclaration(lModel, 'GImplementationGlobal', 'var', 'implementation',
    lDeclaration));
  Assert.IsFalse(HasDeclaration(lModel, 'cLocalConst', 'const', 'implementation'));
  Assert.IsTrue(FindDeclaration(lModel, 'TLocalType', 'type-alias', 'implementation',
    lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
  Assert.AreEqual('routine', lDeclaration.ScopeKind);
  Assert.AreEqual(lRoutine.ScopeId, lDeclaration.OwnerScopeId);
  Assert.IsFalse(HasDeclaration(lModel, 'lLocalValue', 'var', 'implementation'));
end;

procedure TUnitModelTests.MigratedSymbolMapExtractsMembersPropertiesAndMetadata;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SymbolMapMembers.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('SymbolMapMembers', lModel.UnitName);
  AssertUnitModelMemberKeysExactly(lModel, [
    'TMemberRecord.RecordField:field',
    'TMemberRecord.Reset:method',
    'TMemberRecord.DisplayName:property',
    'TMemberClass.FName:field',
    'TMemberClass.FItems:field',
    'TMemberClass.FEnabled:field',
    'TMemberClass.GetItem:method',
    'TMemberClass.GetNamedItem:method',
    'TMemberClass.ClassField:field',
    'TMemberClass.Run:method',
    'TMemberClass.Count:method',
    'TMemberClass.Name:property',
    'TMemberClass.Enabled:property',
    'TMemberClass.Items:property',
    'TMemberClass.MultiItems:property',
    'TDefaultVisibilityClass.DefaultField:field',
    'TDefaultVisibilityClass.DefaultProperty:property',
    'IMemberInterface.Touch:method',
    'IMemberInterface.GetCaption:method',
    'IMemberInterface.Caption:property',
    'TMemberRecordHelper.Normalize:method',
    'TMemberRecordHelper.HelperValue:property']);
  Assert.IsTrue(FindMember(lModel, 'TMemberRecord', 'RecordField', 'field', lMember));
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.AreEqual(7, lMember.Line);
  Assert.AreEqual(5, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberRecord', 'Reset', 'method', lMember));
  Assert.AreEqual(8, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberRecord', 'DisplayName', 'property', lMember));
  Assert.AreEqual(9, lMember.Line);
  Assert.AreEqual(14, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'FName', 'field', lMember));
  Assert.AreEqual('private', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'FItems', 'field', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'FEnabled', 'field', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'GetItem', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'GetNamedItem', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'ClassField', 'field', lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Run', 'method', lMember));
  Assert.IsTrue(Pos('const aName: string', lMember.Signature) > 0);
  Assert.AreEqual(21, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Count', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Name', 'property', lMember));
  Assert.AreEqual('string', lMember.TypeName);
  Assert.IsFalse(lMember.IsIndexed);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Enabled', 'property', lMember));
  Assert.IsFalse(lMember.IsDefault);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'Items', 'property', lMember));
  Assert.IsTrue(lMember.IsIndexed);
  Assert.IsTrue(lMember.IsDefault);
  Assert.IsTrue(FindMember(lModel, 'TMemberClass', 'MultiItems', 'property', lMember));
  Assert.AreEqual('string', lMember.TypeName);
  Assert.IsTrue(lMember.IsIndexed);
  Assert.IsFalse(lMember.IsDefault);
  Assert.IsTrue(FindMember(lModel, 'TDefaultVisibilityClass', 'DefaultField', 'field',
    lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TDefaultVisibilityClass', 'DefaultProperty', 'property',
    lMember));
  Assert.IsTrue(FindMember(lModel, 'IMemberInterface', 'Touch', 'method', lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.AreEqual(35, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'IMemberInterface', 'GetCaption', 'method', lMember));
  Assert.IsTrue(FindMember(lModel, 'IMemberInterface', 'Caption', 'property', lMember));
  Assert.IsTrue(FindMember(lModel, 'TMemberRecordHelper', 'Normalize', 'method', lMember));
  Assert.AreEqual(41, lMember.Line);
  Assert.AreEqual(15, lMember.Column);
  Assert.IsTrue(FindMember(lModel, 'TMemberRecordHelper', 'HelperValue', 'property',
    lMember));
  Assert.AreEqual(42, lMember.Line);
  Assert.AreEqual(14, lMember.Column);
end;

procedure TUnitModelTests.PreprocessingRemovesInactiveDeclarations;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE_MODEL'];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'TActiveModelType', 'type', 'interface'));
  Assert.IsFalse(HasDeclaration(lModel, 'TInactiveModelType', 'type', 'interface'));
end;

procedure TUnitModelTests.TypedConstantMutabilityUsesActivePreprocessedDirectives;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-active-j-directive.pas');
  TFile.WriteAllText(lPath,
    'unit ActiveJDirectiveUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$IFDEF INACTIVE_BRANCH}' + sLineBreak +
    '{$J+}' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    'const' + sLineBreak +
    '  GImmutableValue: Integer = 1;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(FindDeclaration(lModel, 'GImmutableValue', 'typed-const',
    'interface', lDeclaration));
  Assert.IsFalse(lDeclaration.Mutable,
    'Inactive conditional directives must not change typed-constant mutability.');
end;

procedure TUnitModelTests.TypedConstantMutabilityUsesIncludedDirectives(const aCase: Integer);
const
  cDirectives: array[0..2] of string = ('{$I Writable.inc}',
    '{$J-}{$I Writable.inc}', '{$I Writable.inc}{$J-}');
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-included-j-directive-' + IntToStr(aCase));
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Writable.inc'), '{$J+}',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedJDirectiveUnit.pas'),
    'unit IncludedJDirectiveUnit;' + sLineBreak +
    'interface' + sLineBreak +
    cDirectives[aCase] + sLineBreak +
    'const' + sLineBreak +
    '  GMutableValue: Integer = 1;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludedJDirectiveUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(FindDeclaration(lModel, 'GMutableValue', 'typed-const',
    'interface', lDeclaration));
  Assert.AreEqual(aCase <> 2, lDeclaration.Mutable,
    'Include-origin directives must retain their order relative to surrounding switches.');
end;

procedure TUnitModelTests.TypedConstantMutabilityIgnoresCommentedDirective(const aCase: Integer);
const
  cExamples: array[0..3] of string = ('// example {$J+}',
    '(* example' + sLineBreak + '{$J+}' + sLineBreak + '*)',
    '{ example' + sLineBreak + '(*$J+*)' + sLineBreak + '}',
    'const TextValue = ''It''''s {$J+} and (*$J+*)'';');
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-commented-j-directive-' + IntToStr(aCase) + '.pas');
  TFile.WriteAllText(lPath, 'unit CommentedJDirectiveUnit;' + sLineBreak +
    'interface' + sLineBreak + '{$J-}' + sLineBreak +
    cExamples[aCase] + sLineBreak + 'const' + sLineBreak +
    '  ReadOnlyValue: Integer = 1;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'ReadOnlyValue', 'typed-const',
    'interface', lDeclaration));
  Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
  Assert.IsFalse(lDeclaration.Mutable,
    'A commented directive must not change typed-constant mutability.');
end;

procedure TUnitModelTests.TypedConstantMutabilityRespectsInlineSwitchOrder;
const
  cNames: array[0..3] of string = ('BeforeSwitch', 'AfterSwitch', 'AfterPair', 'AfterParenPair');
  cColumns: array[0..3] of Integer = (7, 7, 18, 22);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  i: Integer;
begin
  lPath := UnitModelTempPath('unit-model-inline-j-directives.pas');
  TFile.WriteAllText(lPath, 'unit InlineJDirectiveUnit;' + sLineBreak +
    'interface' + sLineBreak + '{$J-}' + sLineBreak +
    'const BeforeSwitch: Integer = 1; {$J+}' + sLineBreak +
    'const AfterSwitch: Integer = 2;' + sLineBreak +
    '{$J+}{$J-} const AfterPair: Integer = 3;' + sLineBreak +
    '(*$J+*)(*$J-*) const AfterParenPair: Integer = 4;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  for i := Low(cNames) to High(cNames) do
  begin
    Assert.IsTrue(FindDeclaration(lModel, cNames[i], 'typed-const', 'interface', lDeclaration),
      cNames[i] + ' must remain a declaration.');
    Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
    Assert.AreEqual(i = 1, lDeclaration.Mutable,
      cNames[i] + ' must use the last preceding active switch.');
    Assert.AreEqual(4 + i, lDeclaration.Line, 'Original source line must be retained.');
    Assert.AreEqual(cColumns[i], lDeclaration.Column, 'Original source column must be retained.');
  end;
end;

procedure TUnitModelTests.TypedConstantMutabilityUsesLastStandaloneSwitch(const aCase: Integer);
const
  cSwitches: array[0..2] of string = ('(*$J+*)(*$J-*)', '{$J+}(*$J-*)', '(*$J+*){$J-}');
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-standalone-j-directives-' + IntToStr(aCase) + '.pas');
  TFile.WriteAllText(lPath, 'unit StandaloneJDirectiveUnit;' + sLineBreak +
    'interface' + sLineBreak + cSwitches[aCase] + sLineBreak +
    'const ReadOnlyValue: Integer = 1;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'ReadOnlyValue', 'typed-const', 'interface', lDeclaration));
  Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
  Assert.IsFalse(lDeclaration.Mutable, 'The final standalone switch must win.');
  Assert.AreEqual(4, lDeclaration.Line);
end;

procedure TUnitModelTests.RejectedDeclarationsHaveDeterministicMutability;
var
  i: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lFoundGlobal: Boolean;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRejected: Integer;
begin
  lPath := UnitModelTempPath('rejected-mutability.pas');
  TFile.WriteAllText(lPath,
    'unit RejectedMutability;' + sLineBreak +
    'interface' + sLineBreak +
    'var' + sLineBreak +
    '  GCounter: Integer;' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin Inc(GCounter); end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  for i := 1 to 2 do
  begin
    lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
    Assert.AreEqual('ast', lModel.ScopeModelStatus);
    lFoundGlobal := False;
    lRejected := 0;
    for lDeclaration in lModel.Declarations do
    begin
      if lDeclaration.DeclarationRole = 'invalid' then
      begin
        Inc(lRejected);
        Assert.IsFalse(lDeclaration.Mutable, Format('Rejected candidate must be nonmutable (extraction %d).', [i]));
      end else if lDeclaration.Name = 'GCounter' then
      begin
        lFoundGlobal := True;
        Assert.IsTrue(lDeclaration.Mutable, 'Valid variable must remain mutable.');
      end;
    end;
    Assert.IsTrue(lFoundGlobal, 'Expected the valid GCounter control.');
    Assert.IsTrue(lRejected > 0, 'Expected rejected routine candidates.');
  end;
end;

procedure TUnitModelTests.ScopeModelFailureRejectsUnverifiedGlobalCandidates;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-invalid-scope.pas');
  TFile.WriteAllText(lPath,
    'unit InvalidScopeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'var' + sLineBreak +
    '  GUnverified: Integer;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Broken;' + sLineBreak +
    'begin' + sLineBreak,
    TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits([lModel]);

  Assert.AreEqual('ast-failed', lModel.ScopeModelStatus);
  Assert.IsFalse(lModel.PhysicalReferenceOccurrencesAvailable,
    'A failed scope capture cannot prove the reference set complete');
  Assert.IsTrue(HasDiagnostic(lModel, 'SCOPE_MODEL_FAILED'));
  Assert.IsTrue(lModel.RejectedDeclarationCount > 0);
  for lDeclaration in lModel.Declarations do
    Assert.IsFalse(lDeclaration.Mutable, 'Rejected AST-failure candidate must be nonmutable.');
  Assert.AreEqual(0, Integer(Length(lAnalysis.Declarations)),
    'Unverified declaration candidates must fail closed.');
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentLineNumbers;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'Included.inc'), 'type TIncludedLineType = class end;',
    TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeLineUnit.pas'),
    'unit IncludeLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I Included.inc}' + sLineBreak +
    'type' + sLineBreak +
    '  TAfterIncludeType = class end;' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(5, LineOfDeclaration(lModel, 'TAfterIncludeType'));
end;

procedure TUnitModelTests.IncludeExpansionPreservesMultiLineIncludedDeclarations;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-multiline');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedRecord.inc'),
    'type' + sLineBreak +
    '  TIncludedRecord = record' + sLineBreak +
    '    IncludedValue: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeMultiLineUnit.pas'),
    'unit IncludeMultiLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedRecord.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'end.', TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeMultiLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'TIncludedRecord', 'type', 'interface'));
  Assert.IsTrue(HasMemberOfOwner(lModel, 'TIncludedRecord', 'IncludedValue'));
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentWithRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
  lSource: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-with-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedTypes.inc'),
    'type' + sLineBreak +
    '  TIncludedWithRecord = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  lSource :=
    'unit IncludeWithLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedTypes.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TIncludedWithRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '  begin' + sLineBreak +
    '    Value := 1;' + sLineBreak +
    '  end;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeWithLineUnit.pas'), lSource, TEncoding.UTF8);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeWithLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.AreEqual(9, lModel.WithStatements[0].Line);
  Assert.IsTrue(Pos('Value := 1', StatementText(lSource, lModel.WithStatements[0].Line,
    lModel.WithStatements[0].Column, lModel.WithStatements[0].EndLine,
    lModel.WithStatements[0].EndColumn)) > 0);
end;

// "file:line:column" of every fact named aName; the file is the include file that holds the
// text, or the unit itself. The source text at each position must spell the name.
function IncludeFactKeys(const aModel: TDelphiSemanticUnitModel; const aRoot, aName: string):
  string;
var
  lKeys: TStringList;

  procedure AddKey(const aFileName: string; const aLine, aColumn: Integer);
  var
    lFileName: string;
    lLines: TArray<string>;
  begin
    lFileName := aFileName;
    if lFileName = '' then
      lFileName := aModel.FileName;
    lKeys.Add(LowerCase(ExtractFileName(lFileName)) + ':' + aLine.ToString + ':' +
      aColumn.ToString);
    lLines := TFile.ReadAllLines(TPath.Combine(aRoot, ExtractFileName(lFileName)));
    Assert.IsTrue((aLine >= 1) and (aLine <= Length(lLines)), 'Line out of range: ' +
      lKeys[lKeys.Count - 1]);
    Assert.AreEqual(LowerCase(aName), LowerCase(Copy(lLines[aLine - 1], aColumn, Length(aName))),
      'The source text at ' + lKeys[lKeys.Count - 1] + ' must spell the name.');
  end;

var
  lDeclaration: TDelphiSemanticDeclaration;
  lLocal: TDelphiSemanticLocal;
  lReference: TDelphiSemanticReference;
  lRoutine: TDelphiSemanticRoutine;
begin
  lKeys := TStringList.Create;
  try
    lKeys.Sorted := True;
    lKeys.Duplicates := dupAccept;
    for lReference in aModel.References do
      if SameText(lReference.Name, aName) then
        AddKey(lReference.FileName, lReference.Line, lReference.Column);
    for lDeclaration in aModel.Declarations do
      if SameText(lDeclaration.Name, aName) then
        AddKey(lDeclaration.FileName, lDeclaration.Line, lDeclaration.Column);
    for lRoutine in aModel.Routines do
      if SameText(lRoutine.Name, aName) then
        AddKey(lRoutine.FileName, lRoutine.Line, lRoutine.Column);
    for lLocal in aModel.Locals do
      if SameText(lLocal.Name, aName) then
        AddKey(lLocal.FileName, lLocal.Line, lLocal.Column);
    lKeys.Delimiter := ' ';
    Result := lKeys.DelimitedText;
  finally
    lKeys.Free;
  end;
end;

procedure TUnitModelTests.IncludeInRoutineBodyAttributesReferencesToIncludeFiles;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-body');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'body.inc'),
    '  GA := GB + 1;'#13#10'{$I inner.inc}'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'inner.inc'), '  GA := GA + GB;'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncBody.pas'),
    'unit IncBody;'#13#10 + // 1
    'interface'#13#10 + // 2
    'var'#13#10 + // 3
    '  GA, GB: Integer;'#13#10 + // 4
    'procedure Foo;'#13#10 + // 5
    'procedure Bar;'#13#10 + // 6
    'implementation'#13#10 + // 7
    'procedure Foo;'#13#10 + // 8
    'begin'#13#10 + // 9
    '{$IFDEF NEVER_DEFINED}'#13#10 + // 10
    '  GA := 99;'#13#10 + // 11: inactive
    '{$ELSE}'#13#10 + // 12
    '{$I body.inc}'#13#10 + // 13
    '{$ENDIF}'#13#10 + // 14
    '  WriteLn(GA);'#13#10 + // 15
    'end;'#13#10 + // 16
    'procedure Bar;'#13#10 + // 17
    'begin'#13#10 + // 18
    '  GB := 5;'#13#10 + // 19
    'end;'#13#10 + // 20
    'end.'#13#10, TEncoding.ASCII);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncBody.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  // The inactive GA on line 11 is no fact; the include occurrences keep their own files,
  // including the nested include.
  Assert.AreEqual('body.inc:1:3 incbody.pas:15:11 incbody.pas:4:3 inner.inc:1:3 inner.inc:1:9',
    IncludeFactKeys(lModel, lRoot, 'GA'));
  Assert.AreEqual('body.inc:1:9 incbody.pas:19:3 incbody.pas:4:7 inner.inc:1:14',
    IncludeFactKeys(lModel, lRoot, 'GB'));
end;

procedure TUnitModelTests.MidLineIncludeFactsStayAtTheDirective;
var
  lKeys: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticReference;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-mid-line');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'midf.inc'), 'GF := GF + 1;'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncMid.pas'),
    'unit IncMid;'#13#10 + // 1
    'interface'#13#10 + // 2
    'var'#13#10 + // 3
    '  GF: Integer;'#13#10 + // 4
    'procedure Foo;'#13#10 + // 5
    'implementation'#13#10 + // 6
    'procedure Foo;'#13#10 + // 7
    'begin'#13#10 + // 8
    '  WriteLn(1); {$I midf.inc}'#13#10 + // 9: the directive starts at column 15
    '  GF := 3;'#13#10 + // 10
    'end;'#13#10 + // 11
    'end.'#13#10, TEncoding.ASCII);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncMid.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  lKeys := '';
  for lReference in lModel.References do
    if SameText(lReference.Name, 'GF') then
      lKeys := lKeys + LowerCase(ExtractFileName(lReference.FileName)) + ':' +
        lReference.Line.ToString + ':' + lReference.Column.ToString + ' ';
  // The unit's own GF on line 10 has no FileName; the included GF facts sit on the directive and
  // name the unit file, which marks them as not positioned in this unit's text.
  Assert.AreEqual('incmid.pas:9:15 :10:3 ', lKeys);
end;

procedure TUnitModelTests.MidLineIncludesKeepDistinctPhysicalReferenceOccurrences;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;

  procedure AssertOccurrences(const aJson: string);
  var
    i: Integer;
    lDocument: TJSONValue;
    lEntry: TJSONObject;
    lFacts: TJSONArray;
    lFileName: string;
    lFirstExpansion: string;
    lKeys: TStringList;
    lOffsets: TStringList;
    lSecondExpansion: string;
  begin
    lDocument := TJSONObject.ParseJSONValue(aJson);
    lKeys := TStringList.Create;
    lOffsets := TStringList.Create;
    try
      Assert.IsTrue(lDocument is TJSONObject);
      lFacts := (lDocument as TJSONObject).GetValue('PhysicalReferenceOccurrences') as TJSONArray;
      Assert.IsTrue(Assigned(lFacts), 'Missing physical occurrence sidecar');
      for i := 0 to Pred(lFacts.Count) do
      begin
        lEntry := lFacts.Items[i] as TJSONObject;
        if lEntry.GetValue('Name').Value <> 'GF' then
          Continue;
        lFileName := LowerCase(ExtractFileName(lEntry.GetValue('FileName').Value));
        if (lFileName <> 'first.inc') and (lFileName <> 'second.inc') then
          Continue;
        Assert.IsTrue(SameText(lEntry.GetValue('Verified').Value, 'true'));
        Assert.AreEqual('Foo', lEntry.GetValue('RoutineName').Value);
        Assert.AreNotEqual('', lEntry.GetValue('RoutineScopeId').Value);
        Assert.AreEqual('reference', lEntry.GetValue('Role').Value);
        Assert.AreEqual('1', lEntry.GetValue('Line').Value);
        Assert.AreEqual('1', lEntry.GetValue('EndLine').Value);
        Assert.AreEqual(IntToStr(StrToInt(lEntry.GetValue('Column').Value) + 1),
          lEntry.GetValue('EndColumn').Value,
          'Both GF tokens must retain their own physical span');
        lKeys.Add(lFileName + ':' + lEntry.GetValue('Column').Value);
        lOffsets.Add(lEntry.GetValue('OutputStartOffset').Value + ':' +
          lEntry.GetValue('OutputEndOffset').Value);
        if lFileName = 'first.inc' then
        begin
          if lFirstExpansion = '' then
            lFirstExpansion := lEntry.GetValue('ExpansionId').Value
          else
            Assert.AreEqual(lFirstExpansion, lEntry.GetValue('ExpansionId').Value);
        end else begin
          if lSecondExpansion = '' then
            lSecondExpansion := lEntry.GetValue('ExpansionId').Value
          else
            Assert.AreEqual(lSecondExpansion, lEntry.GetValue('ExpansionId').Value);
        end;
      end;
      Assert.AreEqual(4, lKeys.Count, 'Two includes must retain four GF tokens');
      Assert.IsTrue(lKeys.IndexOf('first.inc:1') >= 0);
      Assert.IsTrue(lKeys.IndexOf('first.inc:7') >= 0);
      Assert.IsTrue(lKeys.IndexOf('second.inc:1') >= 0);
      Assert.IsTrue(lKeys.IndexOf('second.inc:7') >= 0);
      Assert.AreNotEqual('', lFirstExpansion);
      Assert.AreNotEqual('', lSecondExpansion);
      Assert.AreNotEqual(lFirstExpansion, lSecondExpansion);
      for i := 0 to Pred(lOffsets.Count) do
        Assert.AreEqual(i, lOffsets.IndexOf(lOffsets[i]), 'Expanded token spans must be distinct');
    finally
      lOffsets.Free;
      lKeys.Free;
      lDocument.Free;
    end;
  end;

begin
  lRoot := UnitModelTempPath('unit-model-two-mid-line-includes');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'first.inc'), 'GF := GF + 1;'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'second.inc'), 'GF := GF + 1;'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncPhysical.pas'),
    'unit IncPhysical;'#13#10 +
    'interface'#13#10 +
    'var GF: Integer;'#13#10 +
    'procedure Foo;'#13#10 +
    'implementation'#13#10 +
    'procedure Foo;'#13#10 +
    'begin'#13#10 +
    '  WriteLn(1); {$I first.inc} {$I second.inc} GF := 3;'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncPhysical.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.PhysicalReferenceOccurrencesAvailable);
  AssertOccurrences(ModelToJson(lModel));
  AssertOccurrences(ModelToJson(JsonToModel(ModelToJson(lModel))));
end;

procedure TUnitModelTests.RepeatedNestedAndInactiveIncludesKeepPhysicalOccurrences;
var
  i: Integer;
  lDocument: TJSONValue;
  lEntry: TJSONObject;
  lFacts: TJSONArray;
  lFileName: string;
  lInnerCount: Integer;
  lInnerExpansions: TStringList;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOuterCount: Integer;
  lOuterExpansions: TStringList;
  lRoot: string;
  lRootCount: Integer;
begin
  lRoot := UnitModelTempPath('unit-model-nested-repeated-includes');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'inner.inc'), 'GF := GF + 1;'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'outer.inc'),
    '{$I inner.inc}'#13#10 + 'GF := GF + 1;'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'inactive.inc'), 'GF := GF + 1;'#13#10,
    TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncNested.pas'),
    'unit IncNested;'#13#10 +
    'interface'#13#10 +
    'var GF: Integer;'#13#10 +
    'procedure Foo;'#13#10 +
    'implementation'#13#10 +
    'procedure Foo;'#13#10 +
    'begin'#13#10 +
    '  {$I outer.inc}'#13#10 +
    '  {$I outer.inc} GF := GF + 1;'#13#10 +
    '  {$IFDEF NEVER}{$I inactive.inc}{$ENDIF}'#13#10 +
    'end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncNested.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.PhysicalReferenceOccurrencesAvailable);
  lDocument := TJSONObject.ParseJSONValue(ModelToJson(lModel));
  lInnerExpansions := TStringList.Create;
  lOuterExpansions := TStringList.Create;
  try
    Assert.IsTrue(lDocument is TJSONObject);
    lFacts := (lDocument as TJSONObject).GetValue('PhysicalReferenceOccurrences') as TJSONArray;
    Assert.IsTrue(Assigned(lFacts), 'Missing physical occurrence sidecar');
    lInnerCount := 0;
    lOuterCount := 0;
    lRootCount := 0;
    for i := 0 to Pred(lFacts.Count) do
    begin
      lEntry := lFacts.Items[i] as TJSONObject;
      if lEntry.GetValue('Name').Value <> 'GF' then
        Continue;
      lFileName := LowerCase(ExtractFileName(lEntry.GetValue('FileName').Value));
      if lFileName = 'inner.inc' then
      begin
        Inc(lInnerCount);
        Assert.AreEqual('1', lEntry.GetValue('Line').Value);
        if lInnerExpansions.IndexOf(lEntry.GetValue('ExpansionId').Value) < 0 then
          lInnerExpansions.Add(lEntry.GetValue('ExpansionId').Value);
      end else if lFileName = 'outer.inc' then
      begin
        Inc(lOuterCount);
        Assert.AreEqual('2', lEntry.GetValue('Line').Value);
        if lOuterExpansions.IndexOf(lEntry.GetValue('ExpansionId').Value) < 0 then
          lOuterExpansions.Add(lEntry.GetValue('ExpansionId').Value);
      end else if lFileName = 'incnested.pas' then
      begin
        Inc(lRootCount);
        Assert.AreEqual('9', lEntry.GetValue('Line').Value);
      end else
        Assert.AreNotEqual('inactive.inc', lFileName, 'Inactive text has no occurrence');
    end;
    Assert.AreEqual(4, lInnerCount);
    Assert.AreEqual(4, lOuterCount);
    Assert.AreEqual(2, lRootCount, 'The parent tail must keep its own source');
    Assert.AreEqual(2, lInnerExpansions.Count, 'Repeated nested includes need distinct identities');
    Assert.AreEqual(2, lOuterExpansions.Count, 'Repeated includes need distinct identities');
  finally
    lOuterExpansions.Free;
    lInnerExpansions.Free;
    lDocument.Free;
  end;
end;

procedure TUnitModelTests.IncludeBetweenDeclarationsAttributesFactsToIncludeFile;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-declarations');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'decl.inc'),
    'function Helper(aValue: Integer): Integer;'#13#10 + // 1
    'var'#13#10 + // 2
    '  lBase: Integer;'#13#10 + // 3
    'begin'#13#10 + // 4
    '  lBase := GB;'#13#10 + // 5
    '  Result := aValue + lBase;'#13#10 + // 6
    'end;'#13#10, TEncoding.ASCII);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncDecl.pas'),
    'unit IncDecl;'#13#10 + // 1
    'interface'#13#10 + // 2
    'var'#13#10 + // 3
    '  GA, GB: Integer;'#13#10 + // 4
    'function Twice: Integer;'#13#10 + // 5
    'implementation'#13#10 + // 6
    '{$I decl.inc}'#13#10 + // 7
    'function Twice: Integer;'#13#10 + // 8
    'var'#13#10 + // 9
    '  lBase: Integer;'#13#10 + // 10
    'begin'#13#10 + // 11
    '  lBase := GA;'#13#10 + // 12
    '  Result := Helper(lBase) * 2;'#13#10 + // 13
    'end;'#13#10 + // 14
    'end.'#13#10, TEncoding.ASCII);

  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncDecl.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  // Helper is both a routine declaration and a routine fact.
  Assert.AreEqual('decl.inc:1:10 decl.inc:1:10 incdecl.pas:13:13',
    IncludeFactKeys(lModel, lRoot, 'Helper'));
  Assert.AreEqual('decl.inc:3:3 decl.inc:5:3 decl.inc:6:22 incdecl.pas:10:3 incdecl.pas:12:3 ' +
    'incdecl.pas:13:20', IncludeFactKeys(lModel, lRoot, 'lBase'));
  Assert.AreEqual('decl.inc:5:12 incdecl.pas:4:7', IncludeFactKeys(lModel, lRoot, 'GB'));
  Assert.AreEqual('incdecl.pas:12:12 incdecl.pas:4:3', IncludeFactKeys(lModel, lRoot, 'GA'));
end;

procedure TUnitModelTests.ModelUsesSourceLoaderFallbackWhenExtractingAnsiSource;
var
  lBytes: TBytes;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-ansi-extract.pas');
  lBytes := [$75, $6E, $69, $74, $20, $41, $6E, $73, $69, $45, $78, $74, $72, $61, $63, $74,
    $55, $6E, $69, $74, $3B, $0D, $0A, $69, $6E, $74, $65, $72, $66, $61, $63, $65,
    $0D, $0A, $2F, $2F, $20, $E4, $0D, $0A, $69, $6D, $70, $6C, $65, $6D, $65, $6E,
    $74, $61, $74, $69, $6F, $6E, $0D, $0A, $65, $6E, $64, $2E];
  TFile.WriteAllBytes(lPath, lBytes);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('AnsiExtractUnit', lModel.UnitName);
  Assert.AreEqual('windows-1252', lModel.EncodingName);
end;

procedure TUnitModelTests.WithStatementsExposeSourceRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(lModel.WithStatements[0].EndLine > lModel.WithStatements[0].Line);
  Assert.IsTrue(lModel.WithStatements[0].EndColumn > 0);
  Assert.AreEqual('lRecord', lModel.WithStatements[0].SelectorText);
  Assert.IsTrue(Pos('Value := Length', lModel.WithStatements[0].Text) > 0);
  Assert.IsTrue(Pos('SemanticGlobal :=', lModel.WithStatements[0].Text) = 0);
end;

procedure TUnitModelTests.WithDiscoveryIgnoresStringsAndCommentsAndKeepsRepeatedRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := UnitModelTempPath('unit-model-with-scanner.pas');
  lSource :=
    'unit WithScannerUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  // with lRecord do' + sLineBreak +
    '  Text := ''with lRecord do'';' + sLineBreak +
    '  with lRecord do Value := 1;' + sLineBreak +
    '  with lRecord do Value := 2;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(2, Integer(Length(lModel.WithStatements)));
  Assert.AreEqual(10, lModel.WithStatements[0].Line);
  Assert.AreEqual(11, lModel.WithStatements[1].Line);
end;

procedure TUnitModelTests.ReferencesIgnoreStringsAndComments;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lPath := UnitModelTempPath('unit-model-reference-scanner.pas');
  TFile.WriteAllText(lPath,
    'unit ReferenceScannerUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  // PhantomReference' + sLineBreak +
    '  Text := ''StringReference'';' + sLineBreak +
    '  RealReference := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsFalse(HasReference(lModel, 'PhantomReference'));
  Assert.IsFalse(HasReference(lModel, 'StringReference'));
  Assert.IsTrue(HasReference(lModel, 'RealReference'));
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentReferences;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-reference-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedRefTypes.inc'),
    'type' + sLineBreak +
    '  TReferenceInclude = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludeReferenceLineUnit.pas'),
    'unit IncludeReferenceLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedRefTypes.inc}' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'begin' + sLineBreak +
    '  ParentReference := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludeReferenceLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasReferenceOnLine(lModel, 'ParentReference', 7));
end;

procedure TUnitModelTests.IncludeExpansionDoesNotShiftFollowingParentMembersRoutinesAndLocals;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot: string;
begin
  lRoot := UnitModelTempPath('unit-model-include-position-lines');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludedManyLines.inc'),
    'type' + sLineBreak +
    '  TIncludedPosition = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;', TEncoding.UTF8);
  TFile.WriteAllText(TPath.Combine(lRoot, 'IncludePositionLineUnit.pas'),
    'unit IncludePositionLineUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$I IncludedManyLines.inc}' + sLineBreak +
    'type' + sLineBreak +
    '  TParentRecord = record' + sLineBreak +
    '    ParentField: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure ParentRoutine;' + sLineBreak +
    'var' + sLineBreak +
    '  lParentLocal: TParentRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  lParentLocal.ParentField := 1;' + sLineBreak +
    'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'IncludePositionLineUnit.pas');
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasMemberOnLine(lModel, 'TParentRecord', 'ParentField', 6), 'member line');
  Assert.IsTrue(HasRoutineOnLine(lModel, 'ParentRoutine', 9), 'routine line');
  Assert.IsTrue(HasLocalOnLine(lModel, 'ParentRoutine', 'lParentLocal', 11), 'local line');
end;

procedure TUnitModelTests.WithStatementRangeCoversIfThenElseBodies;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := UnitModelTempPath('unit-model-with-if-else.pas');
  lSource :=
    'unit WithIfElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '    if Value > 0 then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Text := ''positive'';' + sLineBreak +
    '    end else begin' + sLineBreak +
    '      Text := ''zero'';' + sLineBreak +
    '    end;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Text := ''zero''', lModel.WithStatements[0].Text) > 0);
  Assert.IsTrue(Pos('AfterWith := True', lModel.WithStatements[0].Text) = 0);

  lPath := UnitModelTempPath('unit-model-with-if-end-else-begin.pas');
  lSource :=
    'unit WithIfEndElseBeginUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '    if Queue = nil then' + sLineBreak +
    '    begin' + sLineBreak +
    '      Next := lRecord;' + sLineBreak +
    '      Last := lRecord;' + sLineBreak +
    '    end' + sLineBreak +
    '    else begin' + sLineBreak +
    '      Next := Queue;' + sLineBreak +
    '      Last := Queue.Last;' + sLineBreak +
    '      Queue := lRecord;' + sLineBreak +
    '    end;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Last := Queue.Last', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterWith := True', lModel.WithStatements[0].Text) = 0);

  lPath := UnitModelTempPath('unit-model-with-structured-then-else.pas');
  lSource :=
    'unit WithStructuredThenElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    '  lOther: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '    if Queue = nil then' + sLineBreak +
    '      with lOther do' + sLineBreak +
    '      begin' + sLineBreak +
    '        Next := 1;' + sLineBreak +
    '      end' + sLineBreak +
    '    else begin' + sLineBreak +
    '      Last := Queue.Last;' + sLineBreak +
    '    end;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(2, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Last := Queue.Last', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterWith := True', lModel.WithStatements[0].Text) = 0);

  lPath := UnitModelTempPath('unit-model-with-inner-else-before-outer-else.pas');
  lSource :=
    'unit WithInnerElseBeforeOuterElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  if OuterFlag then' + sLineBreak +
    '    with lRecord do' + sLineBreak +
    '      if Queue = nil then' + sLineBreak +
    '      begin' + sLineBreak +
    '        Next := 1;' + sLineBreak +
    '      end' + sLineBreak +
    '      else begin' + sLineBreak +
    '        Last := Queue.Last;' + sLineBreak +
    '      end' + sLineBreak +
    '  else' + sLineBreak +
    '    AfterOuter := True;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Last := Queue.Last', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterOuter := True', lModel.WithStatements[0].Text) = 0,
    lModel.WithStatements[0].Text);

  lPath := UnitModelTempPath('unit-model-with-inner-single-else-before-outer-else.pas');
  lSource :=
    'unit WithInnerSingleElseBeforeOuterElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  if OuterFlag then' + sLineBreak +
    '    with lRecord do' + sLineBreak +
    '      if Queue = nil then' + sLineBreak +
    '      begin' + sLineBreak +
    '        Next := 1;' + sLineBreak +
    '      end' + sLineBreak +
    '      else' + sLineBreak +
    '        Last := Queue.Last' + sLineBreak +
    '  else' + sLineBreak +
    '    AfterOuter := True;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Last := Queue.Last', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterOuter := True', lModel.WithStatements[0].Text) = 0,
    lModel.WithStatements[0].Text);

  lPath := UnitModelTempPath('unit-model-with-nested-if-else-before-outer-else.pas');
  lSource :=
    'unit WithNestedIfElseBeforeOuterElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '    if First then' + sLineBreak +
    '      if Second then' + sLineBreak +
    '      begin' + sLineBreak +
    '        Next := 1;' + sLineBreak +
    '      end' + sLineBreak +
    '      else begin' + sLineBreak +
    '        Last := Queue.Last;' + sLineBreak +
    '      end' + sLineBreak +
    '    else begin' + sLineBreak +
    '      Queue := 3;' + sLineBreak +
    '    end;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Queue := 3', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterWith := True', lModel.WithStatements[0].Text) = 0,
    lModel.WithStatements[0].Text);

  lPath := UnitModelTempPath('unit-model-with-single-assignment-before-outer-else.pas');
  lSource :=
    'unit WithSingleAssignmentBeforeOuterElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  if OuterFlag then' + sLineBreak +
    '    with lRecord do' + sLineBreak +
    '      Text := ''left''' + sLineBreak +
    '  else' + sLineBreak +
    '    AfterOuter := True;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Text := ''left''', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.IsFalse(EndsText('end', Trim(lModel.WithStatements[0].Text)),
    lModel.WithStatements[0].Text);
  Assert.AreEqual(LineContaining(lSource, 'Text := ''left'''), lModel.WithStatements[0].EndLine,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterOuter := True', lModel.WithStatements[0].Text) = 0,
    lModel.WithStatements[0].Text);

  lPath := UnitModelTempPath('unit-model-with-begin-end-before-outer-else.pas');
  lSource :=
    'unit WithBeginEndBeforeOuterElseUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  if OuterFlag then' + sLineBreak +
    '  begin' + sLineBreak +
    '    with lRecord do' + sLineBreak +
    '      Text := ''left''' + sLineBreak +
    '  end else begin' + sLineBreak +
    '    AfterOuter := True;' + sLineBreak +
    '  end;' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('Text := ''left''', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.AreEqual(LineContaining(lSource, 'Text := ''left'''), lModel.WithStatements[0].EndLine,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterOuter := True', lModel.WithStatements[0].Text) = 0,
    lModel.WithStatements[0].Text);

  lPath := UnitModelTempPath('unit-model-with-comment-semicolon.pas');
  lSource :=
    'unit WithCommentSemicolonUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Run;' + sLineBreak +
    'var' + sLineBreak +
    '  lRecord: TSemanticRecord;' + sLineBreak +
    'begin' + sLineBreak +
    '  with lRecord do' + sLineBreak +
    '  begin' + sLineBreak +
    '    Text := ''done'';' + sLineBreak +
    '  end { comment; };' + sLineBreak +
    '  AfterWith := True;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  Assert.IsTrue(Pos('};', lModel.WithStatements[0].Text) > 0,
    lModel.WithStatements[0].Text);
  Assert.IsTrue(Pos('AfterWith := True', lModel.WithStatements[0].Text) = 0);
end;

procedure TUnitModelTests.ModelKeepsOriginalSourceLineNumbersAfterPreprocessing;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE_MODEL'];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(7, LineOfDeclaration(lModel, 'TActiveModelType'));
  Assert.AreEqual(LineContaining(TFile.ReadAllText(lOptions.SourceFileName, TEncoding.UTF8),
    'TDuplicateModelType = record'), LineOfDeclaration(lModel, 'TDuplicateModelType'));
end;

procedure TUnitModelTests.SourceSectionsExposeInitializationAndFinalizationBoundaries;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := UnitModelTempPath('unit-model-source-sections.pas');
  lSource :=
    'unit SourceSectionsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'implementation' + sLineBreak +
    'initialization' + sLineBreak +
    'finalization' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(Pos('interface', lSource), lModel.SourceSections.InterfaceOffset);
  Assert.AreEqual(Pos('implementation', lSource), lModel.SourceSections.ImplementationOffset);
  Assert.AreEqual(Pos('initialization', lSource), lModel.SourceSections.InitializationOffset);
  Assert.AreEqual(Pos('finalization', lSource), lModel.SourceSections.FinalizationOffset);
end;

procedure TUnitModelTests.SourceSectionsHandleUnitsWithoutImplementation;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := UnitModelTempPath('unit-model-no-implementation.pas');
  lSource :=
    'unit NoImplementationUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TNoImplementationType = Integer;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(Pos('interface', lSource), lModel.SourceSections.InterfaceOffset);
  Assert.AreEqual(0, lModel.SourceSections.ImplementationOffset);
  Assert.AreEqual(0, lModel.SourceSections.InitializationOffset);
  Assert.AreEqual(0, lModel.SourceSections.FinalizationOffset);
  Assert.IsTrue(FindDeclaration(lModel, 'TNoImplementationType', 'type-alias', 'interface',
    lDeclaration));
end;

procedure TUnitModelTests.SourceSectionsIgnoreCommentsAndStringsWhenFindingImplementation;
var
  lInterfaceDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSource: string;
begin
  lPath := UnitModelTempPath('unit-model-section-keywords.pas');
  lSource :=
    'unit SectionKeywordsUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '// implementation in a comment' + sLineBreak +
    'const cText = ''implementation in a string'';' + sLineBreak +
    'type' + sLineBreak +
    '  TBeforeImplementation = Integer;' + sLineBreak +
    'implementation' + sLineBreak +
    'type' + sLineBreak +
    '  TAfterImplementation = Integer;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(PosEx('implementation' + sLineBreak + 'type', lSource),
    lModel.SourceSections.ImplementationOffset);
  Assert.IsTrue(FindDeclaration(lModel, 'TBeforeImplementation', 'type-alias', 'interface',
    lInterfaceDeclaration));
  Assert.IsTrue(FindDeclaration(lModel, 'TAfterImplementation', 'type-alias', 'implementation',
    lInterfaceDeclaration));
end;

procedure TUnitModelTests.ModelCarriesOriginalSourceRangesForDeclarationsRoutinesMembersAndLocals;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lFirstSameNameOffset: Integer;
  lLocal: TDelphiSemanticLocal;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRoutine: TDelphiSemanticRoutine;
  lRoutineCount: Integer;
  lRoutineItem: TDelphiSemanticRoutine;
  lSecondSameNameOffset: Integer;
  lSource: string;
begin
  lPath := UnitModelTempPath('unit-model-original-ranges.pas');
  lSource :=
    'unit OriginalRangeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TRangeFirst = class' + sLineBreak +
    '  private' + sLineBreak +
    '    FValue: Integer;' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure SameName;' + sLineBreak +
    '    function Overloaded(const aValue: Integer): Integer; overload;' + sLineBreak +
    '    function Overloaded(const aText: string): string; overload;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TRangeSecond = class' + sLineBreak +
    '  public' + sLineBreak +
    '    procedure SameName;' + sLineBreak +
    '  end;' + sLineBreak +
    'procedure TopLevel(const aText: string);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure TRangeFirst.SameName;' + sLineBreak +
    'var' + sLineBreak +
    '  lFirstLocal: Integer;' + sLineBreak +
    '  procedure NestedWorker;' + sLineBreak +
    '  var' + sLineBreak +
    '    lNestedLocal: Integer;' + sLineBreak +
    '  begin' + sLineBreak +
    '    lNestedLocal := lFirstLocal;' + sLineBreak +
    '  end;' + sLineBreak +
    'begin' + sLineBreak +
    '  NestedWorker;' + sLineBreak +
    'end;' + sLineBreak +
    'function TRangeFirst.Overloaded(const aValue: Integer): Integer;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := aValue;' + sLineBreak +
    'end;' + sLineBreak +
    'function TRangeFirst.Overloaded(const aText: string): string;' + sLineBreak +
    'begin' + sLineBreak +
    '  Result := aText;' + sLineBreak +
    'end;' + sLineBreak +
    'procedure TRangeSecond.SameName;' + sLineBreak +
    'begin' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'TRangeFirst', 'type', 'interface', lDeclaration),
    'TRangeFirst declaration');
  Assert.AreEqual(Pos('TRangeFirst = class', lSource), lDeclaration.Offset);
  Assert.AreEqual(lDeclaration.Offset + Length(lDeclaration.Name), lDeclaration.EndOffset);
  Assert.AreEqual(lDeclaration.Name, Copy(lSource, lDeclaration.Offset,
    lDeclaration.EndOffset - lDeclaration.Offset));
  Assert.IsTrue(FindDeclaration(lModel, 'TopLevel', 'routine', 'interface', lDeclaration),
    'TopLevel declaration');
  Assert.AreEqual(Pos('TopLevel', lSource), lDeclaration.Offset);
  Assert.AreEqual(lDeclaration.Offset + Length(lDeclaration.Name), lDeclaration.EndOffset);
  Assert.AreEqual(lDeclaration.Name, Copy(lSource, lDeclaration.Offset,
    lDeclaration.EndOffset - lDeclaration.Offset));
  Assert.IsTrue(FindMember(lModel, 'TRangeFirst', 'FValue', 'field', lMember),
    'FValue member');
  Assert.AreEqual(Pos('FValue: Integer', lSource), lMember.Offset);
  Assert.AreEqual(lMember.Offset + Length(lMember.Name), lMember.EndOffset);
  Assert.AreEqual(lMember.Name, Copy(lSource, lMember.Offset,
    lMember.EndOffset - lMember.Offset));
  Assert.IsTrue(FindMember(lModel, 'TRangeFirst', 'SameName', 'method', lMember),
    'TRangeFirst.SameName member');
  Assert.AreEqual(Pos('SameName;', lSource), lMember.Offset);
  Assert.AreEqual(lMember.Offset + Length(lMember.Name), lMember.EndOffset);
  Assert.AreEqual(lMember.Name, Copy(lSource, lMember.Offset,
    lMember.EndOffset - lMember.Offset));
  Assert.IsTrue(FindRoutine(lModel, 'NestedWorker', 'implementation', lRoutine),
    'NestedWorker routine');
  Assert.AreEqual(Pos('NestedWorker;', lSource), lRoutine.Offset);
  Assert.AreEqual(lRoutine.Offset + Length(lRoutine.Name), lRoutine.EndOffset);
  Assert.AreEqual(lRoutine.Name, Copy(lSource, lRoutine.Offset,
    lRoutine.EndOffset - lRoutine.Offset));
  Assert.IsTrue(FindLocal(lModel, 'TRangeFirst.SameName', 'lFirstLocal', lLocal),
    'lFirstLocal local');
  Assert.AreEqual(Pos('lFirstLocal: Integer', lSource), lLocal.Offset);
  Assert.AreEqual(lLocal.Offset + Length(lLocal.Name), lLocal.EndOffset);
  Assert.AreEqual(lLocal.Name, Copy(lSource, lLocal.Offset,
    lLocal.EndOffset - lLocal.Offset));
  Assert.IsTrue(FindLocal(lModel, 'NestedWorker', 'lNestedLocal', lLocal), 'lNestedLocal local');
  Assert.AreEqual(Pos('lNestedLocal: Integer', lSource), lLocal.Offset);
  Assert.AreEqual(lLocal.Offset + Length(lLocal.Name), lLocal.EndOffset);
  Assert.AreEqual(lLocal.Name, Copy(lSource, lLocal.Offset,
    lLocal.EndOffset - lLocal.Offset));

  lRoutineCount := 0;
  lFirstSameNameOffset := Pos('procedure TRangeFirst.SameName;', lSource) +
    Length('procedure TRangeFirst.');
  lSecondSameNameOffset := Pos('procedure TRangeSecond.SameName;', lSource) +
    Length('procedure TRangeSecond.');
  for lRoutineItem in lModel.Routines do
    if SameText(lRoutineItem.Name, 'SameName') and SameText(lRoutineItem.SectionKind,
      'implementation') then
    begin
      Inc(lRoutineCount);
      if SameText(lRoutineItem.OwnerName, 'TRangeFirst') then
        Assert.AreEqual(lFirstSameNameOffset, lRoutineItem.Offset)
      else if SameText(lRoutineItem.OwnerName, 'TRangeSecond') then
        Assert.AreEqual(lSecondSameNameOffset, lRoutineItem.Offset)
      else
        Assert.Fail('Unexpected SameName owner: ' + lRoutineItem.OwnerName);
      Assert.AreEqual(lRoutineItem.Offset + Length(lRoutineItem.Name), lRoutineItem.EndOffset);
      Assert.AreEqual(lRoutineItem.Name, Copy(lSource, lRoutineItem.Offset,
        lRoutineItem.EndOffset - lRoutineItem.Offset));
    end;
  Assert.AreEqual(2, lRoutineCount);
  lRoutineCount := 0;
  for lRoutineItem in lModel.Routines do
    if SameText(lRoutineItem.Name, 'Overloaded') and SameText(lRoutineItem.OwnerName,
      'TRangeFirst') and SameText(lRoutineItem.SectionKind, 'implementation') then
    begin
      Inc(lRoutineCount);
      Assert.AreEqual(lRoutineItem.Offset + Length(lRoutineItem.Name), lRoutineItem.EndOffset);
      Assert.AreEqual(lRoutineItem.Name, Copy(lSource, lRoutineItem.Offset,
        lRoutineItem.EndOffset - lRoutineItem.Offset));
    end;
  Assert.AreEqual(2, lRoutineCount);
end;

procedure TUnitModelTests.CoordinateMappingPreservesRangesAcrossModelKinds;
const
  cSource = #$00FC + #13#10 + '  Token' + #10#10 + 'Token' + #13 + ' Z' + #10;
  cLines: array[0..7] of Integer = (2, 99, 1, 0, 99, 99, 4, 99);
  cColumns: array[0..7] of Integer = (3, 1, 6, 0, 1, 1, 1, 1);
  cOffsets: array[0..7] of Integer = (1, 1, 1, 0, 2, 3, 999, 4);
  cExpectedOffsets: array[0..7] of Integer = (6, 13, 6, 0, 2, 3, 13, 4);
  cExpectedLines: array[0..7] of Integer = (2, 4, 2, 0, 99, 99, 4, 99);
  cExpectedColumns: array[0..7] of Integer = (3, 1, 3, 0, 1, 1, 1, 1);
var
  g: TGarbos;
  i: Integer;
  lOffsetMap: TArray<Integer>;
  lDeclaration: TDelphiSemanticDeclaration;
  lDeclarations: TList<TDelphiSemanticDeclaration>;
  lMember: TDelphiSemanticMember;
  lMembers: TList<TDelphiSemanticMember>;
  lRoutine: TDelphiSemanticRoutine;
  lRoutines: TList<TDelphiSemanticRoutine>;
  lLocal: TDelphiSemanticLocal;
  lLocals: TList<TDelphiSemanticLocal>;
  lReference: TDelphiSemanticReference;
  lReferences: TList<TDelphiSemanticReference>;
begin
  GC(lDeclarations, TList<TDelphiSemanticDeclaration>.Create, g);
  GC(lMembers, TList<TDelphiSemanticMember>.Create, g);
  GC(lRoutines, TList<TDelphiSemanticRoutine>.Create, g);
  GC(lLocals, TList<TDelphiSemanticLocal>.Create, g);
  GC(lReferences, TList<TDelphiSemanticReference>.Create, g);
  SetLength(lOffsetMap, 5);
  lOffsetMap[1] := 13;
  lOffsetMap[2] := 0;
  lOffsetMap[3] := 1;
  lOffsetMap[4] := Length(cSource) + 1;
  for i := Low(cLines) to High(cLines) do
  begin
    lDeclaration := Default(TDelphiSemanticDeclaration);
    lDeclaration.Name := 'Token';
    lDeclaration.Line := cLines[i];
    lDeclaration.Column := cColumns[i];
    lDeclaration.Offset := cOffsets[i];
    lDeclarations.Add(lDeclaration);
    lMember := Default(TDelphiSemanticMember);
    lMember.Name := 'Token';
    lMember.Line := cLines[i];
    lMember.Column := cColumns[i];
    lMember.Offset := cOffsets[i];
    lMembers.Add(lMember);
    lRoutine := Default(TDelphiSemanticRoutine);
    lRoutine.Name := 'Token';
    lRoutine.Line := cLines[i];
    lRoutine.Column := cColumns[i];
    lRoutine.Offset := cOffsets[i];
    lRoutines.Add(lRoutine);
    lLocal := Default(TDelphiSemanticLocal);
    lLocal.Name := 'Token';
    lLocal.Line := cLines[i];
    lLocal.Column := cColumns[i];
    lLocal.Offset := cOffsets[i];
    lLocals.Add(lLocal);
    lReference := Default(TDelphiSemanticReference);
    lReference.Name := 'Token';
    lReference.Line := cLines[i];
    lReference.Column := cColumns[i];
    lReference.Offset := cOffsets[i];
    lReferences.Add(lReference);
  end;
  ApplyDeclarationSourceOffsetMap(cSource, lOffsetMap, lDeclarations);
  ApplyMemberSourceOffsetMap(cSource, lOffsetMap, lMembers);
  ApplyRoutineSourceOffsetMap(cSource, lOffsetMap, lRoutines);
  ApplyLocalSourceOffsetMap(cSource, lOffsetMap, lLocals);
  ApplyReferenceSourceOffsetMap(cSource, lOffsetMap, lReferences);
  for i := Low(cLines) to High(cLines) do
  begin
    Assert.AreEqual(cExpectedOffsets[i], lDeclarations[i].Offset, 'Declaration ' + i.ToString);
    Assert.AreEqual(cExpectedLines[i], lDeclarations[i].Line, 'Declaration ' + i.ToString);
    Assert.AreEqual(cExpectedColumns[i], lDeclarations[i].Column, 'Declaration ' + i.ToString);
    Assert.AreEqual(cExpectedOffsets[i], lMembers[i].Offset, 'Member ' + i.ToString);
    Assert.AreEqual(cExpectedLines[i], lMembers[i].Line, 'Member ' + i.ToString);
    Assert.AreEqual(cExpectedColumns[i], lMembers[i].Column, 'Member ' + i.ToString);
    Assert.AreEqual(cExpectedOffsets[i], lRoutines[i].Offset, 'Routine ' + i.ToString);
    Assert.AreEqual(cExpectedLines[i], lRoutines[i].Line, 'Routine ' + i.ToString);
    Assert.AreEqual(cExpectedColumns[i], lRoutines[i].Column, 'Routine ' + i.ToString);
    Assert.AreEqual(cExpectedOffsets[i], lLocals[i].Offset, 'Local ' + i.ToString);
    Assert.AreEqual(cExpectedLines[i], lLocals[i].Line, 'Local ' + i.ToString);
    Assert.AreEqual(cExpectedColumns[i], lLocals[i].Column, 'Local ' + i.ToString);
    Assert.AreEqual(cExpectedOffsets[i], lReferences[i].Offset, 'Reference ' + i.ToString);
    Assert.AreEqual(cExpectedLines[i], lReferences[i].Line, 'Reference ' + i.ToString);
    Assert.AreEqual(cExpectedColumns[i], lReferences[i].Column, 'Reference ' + i.ToString);
  end;
end;

procedure TUnitModelTests.ReferenceReconciliationPreservesMixedLineEndings;
const
  cSource = 'Token' + #13#10 + '  Token' + #10 + '{ Token' + #13#10 +
    ' Token }' + #10 + '    Token';
var
  lMetrics: TDelphiSemanticUnitModelMetrics;
  lReference: TDelphiSemanticReference;
  lReferences: TList<TDelphiSemanticReference>;
begin
  lReferences := TList<TDelphiSemanticReference>.Create;
  try
    lMetrics := Default(TDelphiSemanticUnitModelMetrics);
    ReconcileReferencesCoordinates('', lReferences, lMetrics);
    Assert.AreEqual(0, lMetrics.ReferenceOccurrenceTableBuildCount);
    lReference := Default(TDelphiSemanticReference);
    lReference.Name := 'Token';
    lReference.Line := 1;
    lReference.Column := 1;
    lReference.Offset := 1;
    lReferences.Add(lReference);
    lReference.Line := 2;
    lReference.Column := 3;
    lReference.Offset := 10;
    lReferences.Add(lReference);
    lReference.Line := 5;
    lReference.Column := 4;
    lReference.Offset := 0;
    lReferences.Add(lReference);
    ReconcileReferencesCoordinates(cSource, lReferences, lMetrics);
    Assert.AreEqual(1, lReferences[0].Line);
    Assert.AreEqual(1, lReferences[0].Column);
    Assert.AreEqual(2, lReferences[1].Line);
    Assert.AreEqual(3, lReferences[1].Column);
    Assert.AreEqual(5, lReferences[2].Line);
    Assert.AreEqual(5, lReferences[2].Column);
    Assert.AreEqual(Length(cSource) - 4, lReferences[2].Offset);
    Assert.AreEqual(Length(cSource) + 1, lReferences[2].EndOffset);
    Assert.AreEqual(5, lReferences[2].EndLine);
    Assert.AreEqual(9, lReferences[2].EndColumn);
    Assert.AreEqual(1, lMetrics.ReferenceReconciliationFallbackCount);
    Assert.AreEqual(1, lMetrics.ReferenceOccurrenceTableBuildCount);
  finally
    lReferences.Free;
  end;
end;

procedure TUnitModelTests.ReferencesCarryOriginalSourceRanges;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticReference;
  lReferenceOffset: Integer;
  lRoot: string;
  lSource: string;
begin
  lRoot := UnitModelTempPath('unit-model-reference-ranges');
  TDirectory.CreateDirectory(lRoot);
  TFile.WriteAllText(TPath.Combine(lRoot, 'ReferenceRanges.inc'),
    '// include before body references' + sLineBreak, TEncoding.ASCII);
  lPath := TPath.Combine(lRoot, 'ReferenceRangeUnit.pas');
  lSource :=
    'unit ReferenceRangeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    '{$DEFINE ACTIVE_RANGE}' + sLineBreak +
    'type' + sLineBreak +
    '  TTarget = record' + sLineBreak +
    '    Field: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TAlias = TTarget;' + sLineBreak +
    '  PTarget = ^TTarget;' + sLineBreak +
    '  TArray = array of TAlias;' + sLineBreak +
    '  TContainer = record' + sLineBreak +
    '    Item: TArray;' + sLineBreak +
    '  end;' + sLineBreak +
    '  TInline = {$IFDEF ACTIVE_RANGE}TAlias{$ENDIF};' + sLineBreak +
    '{$IFDEF ACTIVE_RANGE}' + sLineBreak +
    '  TConditional = TAlias;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    '{$IFNDEF ACTIVE_RANGE}' + sLineBreak +
    '  TInactive = TAlias;' + sLineBreak +
    '{$ENDIF}' + sLineBreak +
    'var' + sLineBreak +
    '  GTarget: TTarget;' + sLineBreak +
    'procedure UseRefs(const aParam: TAlias);' + sLineBreak +
    'implementation' + sLineBreak +
    '{$I ReferenceRanges.inc}' + sLineBreak +
    'procedure UseRefs(const aParam: TAlias);' + sLineBreak +
    'var' + sLineBreak +
    '  lLocal: TContainer;' + sLineBreak +
    'begin' + sLineBreak +
    '  GTarget.Field := lLocal.Item[0].Field;' + sLineBreak +
    '  aParam.Field := GTarget.Field;' + sLineBreak +
    '  // TAlias in a comment must not produce a range' + sLineBreak +
    '  Writeln(''TTarget in a string'');' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.SearchPaths := [lRoot];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  lReferenceOffset := Pos('TAlias = TTarget', lSource) + Length('TAlias = ');
  Assert.IsTrue(FindReferenceAtOffset(lModel, 'TTarget', lReferenceOffset, lReference),
    'alias type reference');
  Assert.AreEqual('TTarget', Copy(lSource, lReference.Offset, lReference.EndOffset -
    lReference.Offset));
  Assert.AreEqual(ColumnOfSourceOffset(lSource, lReferenceOffset), lReference.Column);
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TTarget', Pos('PTarget = ^TTarget', lSource) +
    Length('PTarget = ^')), 'pointer type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('TArray = array of TAlias',
    lSource) + Length('TArray = array of ')), 'array type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TArray', Pos('Item: TArray', lSource) +
    Length('Item: ')), 'record field type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('TInline = {$IFDEF ACTIVE_RANGE}TAlias',
    lSource) + Length('TInline = {$IFDEF ACTIVE_RANGE}')), 'inline directive type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('TConditional = TAlias',
    lSource) + Length('TConditional = ')), 'active conditional type reference');
  Assert.IsFalse(HasReferenceAtOffset(lModel, 'TAlias', Pos('TInactive = TAlias',
    lSource) + Length('TInactive = ')), 'inactive conditional type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TTarget', Pos('GTarget: TTarget', lSource) +
    Length('GTarget: ')), 'global type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TAlias', Pos('aParam: TAlias', lSource) +
    Length('aParam: ')), 'parameter type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TContainer', Pos('lLocal: TContainer', lSource) +
    Length('lLocal: ')), 'local type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'GTarget', Pos('GTarget.Field :=', lSource)),
    'global body reference after include');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'Field', Pos('Field :=', lSource)),
    'field body reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'lLocal', Pos('lLocal.Item', lSource)),
    'local body reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'aParam', Pos('aParam.Field', lSource)),
    'parameter body reference');
  Assert.IsFalse(HasReferenceAtOffset(lModel, 'TAlias', Pos('TAlias in a comment',
    lSource)), 'comment token');
  Assert.IsFalse(HasReferenceAtOffset(lModel, 'TTarget', Pos('TTarget in a string',
    lSource)), 'string token');
  Assert.IsTrue(lModel.Metrics.ReferenceReconciliationFallbackCount <= 17,
    'preprocessed source should keep reference reconciliation fallback within the documented ceiling');
end;

procedure TUnitModelTests.ReferencesCarryOriginalSourceRangesWithoutFallbackForPlainSource;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lRoot: string;
  lSource: string;
begin
  lRoot := UnitModelTempPath('unit-model-plain-reference-ranges');
  TDirectory.CreateDirectory(lRoot);
  lPath := TPath.Combine(lRoot, 'PlainReferenceRangeUnit.pas');
  lSource :=
    'unit PlainReferenceRangeUnit;' + sLineBreak +
    'interface' + sLineBreak +
    'type' + sLineBreak +
    '  TTarget = record' + sLineBreak +
    '    Value: Integer;' + sLineBreak +
    '  end;' + sLineBreak +
    'var' + sLineBreak +
    '  GTarget: TTarget;' + sLineBreak +
    'procedure UseRefs(const aParam: TTarget);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure UseRefs(const aParam: TTarget);' + sLineBreak +
    'begin' + sLineBreak +
    '  GTarget.Value := aParam.Value;' + sLineBreak +
    'end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'TTarget', Pos('GTarget: TTarget', lSource) +
    Length('GTarget: ')), 'global type reference');
  Assert.IsTrue(HasReferenceAtOffset(lModel, 'GTarget', Pos('GTarget.Value', lSource)),
    'body global reference');
  Assert.IsTrue(lModel.Metrics.ReferenceReconciliationFallbackCount <= 5,
    'plain source should keep reference reconciliation fallback within the documented ceiling');
end;

procedure TUnitModelTests.ModelPropagatesSourceAndPreprocessDiagnostics;
var
  lMissingModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPreprocessModel: TDelphiSemanticUnitModel;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'MissingUnit.pas');
  lOptions.ProjectContextApplied := True;

  lMissingModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsFalse(lMissingModel.Success);
  Assert.IsTrue(HasDiagnostic(lMissingModel, 'SOURCE_FILE_NOT_FOUND'));

  lOptions.SourceFileName := FixturePath('UnitModel', 'UnsupportedPreprocessUnit.pas');
  lPreprocessModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsFalse(lPreprocessModel.Success);
  Assert.IsTrue(HasDiagnostic(lPreprocessModel, 'UNSUPPORTED_PREPROCESS_DIRECTIVE'));
end;

procedure TUnitModelTests.StandaloneExtractionReportsDegradedMode;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDiagnostic(lModel, 'NO_PROJECT_CONTEXT'));
end;

procedure TUnitModelTests.UnitModelExtractionIsReentrantForParallelUnits;
  function UnitText(const aUnitName, aTypeName, aRoutineName, aReferenceName: string): string;
  begin
    Result := 'unit ' + aUnitName + ';' + sLineBreak +
      'interface' + sLineBreak +
      'type' + sLineBreak +
      '  ' + aTypeName + ' = record' + sLineBreak +
      '    Value: Integer;' + sLineBreak +
      '  end;' + sLineBreak +
      'procedure ' + aRoutineName + '(const aValue: ' + aTypeName + ');' + sLineBreak +
      'implementation' + sLineBreak +
      'procedure ' + aRoutineName + '(const aValue: ' + aTypeName + ');' + sLineBreak +
      'var' + sLineBreak +
      '  ' + aReferenceName + ': ' + aTypeName + ';' + sLineBreak +
      'begin' + sLineBreak +
      '  ' + aReferenceName + '.Value := aValue.Value;' + sLineBreak +
      'end;' + sLineBreak +
      'end.';
  end;

var
  lErrors: array[0..1] of string;
  lModelSource: string;
  lPathA: string;
  lPathB: string;
  lTempDir: string;
  lThreadA: TThread;
  lThreadB: TThread;
begin
  lModelSource := ReadRepoSource('src\DelphiSemantics.Model.pas');
  Assert.IsFalse(ContainsText(lModelSource, 'GLineCacheText'),
    'line coordinate cache must be scoped to an extraction, not process-global');
  Assert.IsFalse(ContainsText(lModelSource, 'GSectionCacheText'),
    'source section cache must be scoped to an extraction, not process-global');
  Assert.IsFalse(ContainsText(lModelSource, 'GTypeBlockRangesText'),
    'type-block range cache must be scoped to an extraction, not process-global');

  lTempDir := TPath.Combine(TPath.GetTempPath, 'DelphiSemanticsReentrantUnitModel_' +
    TGUID.NewGuid.ToString);
  TDirectory.CreateDirectory(lTempDir);
  try
    lPathA := TPath.Combine(lTempDir, 'ReentrantUnitA.pas');
    lPathB := TPath.Combine(lTempDir, 'ReentrantUnitB.pas');
    TFile.WriteAllText(lPathA, UnitText('ReentrantUnitA', 'TReentrantA', 'UseA',
      'lLocalA'), TEncoding.ASCII);
    TFile.WriteAllText(lPathB, UnitText('ReentrantUnitB', 'TReentrantB', 'UseB',
      'lLocalB'), TEncoding.ASCII);

    ExtractReentrantLoop(lPathA, 'ReentrantUnitA', 'TReentrantA', 'UseA', 'lLocalA',
      lErrors[0]);
    ExtractReentrantLoop(lPathB, 'ReentrantUnitB', 'TReentrantB', 'UseB', 'lLocalB',
      lErrors[1]);
    Assert.AreEqual('', lErrors[0]);
    Assert.AreEqual('', lErrors[1]);

    lThreadA := TThread.CreateAnonymousThread(
      procedure
      begin
        ExtractReentrantLoop(lPathA, 'ReentrantUnitA', 'TReentrantA', 'UseA', 'lLocalA',
          lErrors[0]);
      end);
    lThreadB := TThread.CreateAnonymousThread(
      procedure
      begin
        ExtractReentrantLoop(lPathB, 'ReentrantUnitB', 'TReentrantB', 'UseB', 'lLocalB',
          lErrors[1]);
      end);
    try
      lThreadA.FreeOnTerminate := False;
      lThreadB.FreeOnTerminate := False;
      lThreadA.Start;
      lThreadB.Start;
      WaitForTestThreads([lThreadA, lThreadB], 30000);
    finally
      lThreadB.Free;
      lThreadA.Free;
    end;

    Assert.AreEqual('', lErrors[0]);
    Assert.AreEqual('', lErrors[1]);
  finally
    TDirectory.Delete(lTempDir, True);
  end;
end;

procedure TUnitModelTests.TypeBlockAnalysisIsBuiltOncePerExtraction;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'SemanticUnit.pas');
  lOptions.ProjectContextApplied := True;

  TDelphiSemanticUnitModelExtractor.ResetTypeBlockAnalysisBuildCount;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, TDelphiSemanticUnitModelExtractor.TypeBlockAnalysisBuildCount,
    'type-block analysis should be built once per extracted unit');
end;

procedure TUnitModelTests.ReferenceReconciliationScansRepeatedNamesOnce;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE'];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.Metrics.ReferenceReconciliationFallbackCount > 0,
    'fixture should exercise reference reconciliation fallback');
  Assert.IsTrue(lModel.Metrics.ReferenceReconciliationNameScanCount <
    lModel.Metrics.ReferenceReconciliationFallbackCount,
    'repeated fallback names should share one source scan per name');
end;

procedure TUnitModelTests.ReferenceReconciliationBuildsOccurrenceTableOnce;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath('UnitModel', 'ConditionalModelUnit.pas');
  lOptions.Defines := ['ACTIVE'];
  lOptions.ProjectContextApplied := True;

  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);

  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.Metrics.ReferenceReconciliationFallbackCount > 0,
    'fixture should exercise reference reconciliation fallback');
  Assert.AreEqual(1, lModel.Metrics.ReferenceOccurrenceTableBuildCount,
    'fallback reconciliation should build one token occurrence table per unit');
  Assert.AreEqual(0, lModel.Metrics.ReferenceReconciliationNameScanCount,
    'fallback reconciliation should not regex-scan source once per name');
end;

procedure TUnitModelTests.RoutineReconciliationUsesOffsetMapBeforeFallback;
var
  lCoordinateSource: string;
  lExtractSource: string;
begin
  lExtractSource := ReadRepoSource('src\DelphiSemantics.Model.Extract.pas');
  lCoordinateSource := ReadRepoSource('src\DelphiSemantics.Model.Coordinates.pas');

  Assert.IsTrue(ContainsText(lExtractSource,
    'ApplyRoutineSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lRoutines);'),
    'routine reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lCoordinateSource, 'SourceRangeMatchesRoutine'),
    'routine reconciliation should skip fallback scans when the mapped source range is already exact');
  Assert.IsTrue(ContainsText(lExtractSource,
    'ApplyDeclarationSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lDeclarations);'),
    'declaration reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lExtractSource,
    'ApplyMemberSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lMembers);'),
    'member reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lExtractSource,
    'ApplyLocalSourceOffsetMap(lSourceResult.Source.Text, lOffsetMap, lLocals);'),
    'local reconciliation should first map preprocessed offsets back to source offsets');
  Assert.IsTrue(ContainsText(lCoordinateSource, 'if lCleanText = '''' then'),
    'fallback reconciliation should not sanitize whole source files when mapped ranges are already exact');
end;

procedure TUnitModelTests.PascalLexicalHelpersAreCentralized;
var
  lDeadCodeSource: string;
  lGlobalVarsSource: string;
  lQuerySource: string;
  lRefactorSource: string;
  lSourceContextSource: string;
  lTextSource: string;
begin
  lTextSource := ReadRepoSource('src\DelphiSemantics.Model.Text.pas');
  Assert.IsTrue(ContainsText(lTextSource, 'function IsIdentifierStart'),
    'Model text helpers should own Pascal identifier-start logic.');
  Assert.IsTrue(ContainsText(lTextSource, 'function IsWordAt'),
    'Model text helpers should own Pascal word-boundary logic.');
  Assert.IsTrue(ContainsText(lTextSource, 'function TextContainsIdentifier'),
    'Model text helpers should own repeated identifier containment scans.');

  lDeadCodeSource := ReadRepoSource('src\DelphiSemantics.DeadCode.pas');
  lGlobalVarsSource := ReadRepoSource('src\DelphiSemantics.GlobalVars.pas');
  lQuerySource := ReadRepoSource('src\DelphiSemantics.Query.pas');
  lRefactorSource := ReadRepoSource('src\DelphiSemantics.Refactor.pas');
  lSourceContextSource := ReadRepoSource('src\DelphiSemantics.SourceContext.Candidates.pas');

  Assert.IsFalse(ContainsText(lDeadCodeSource, 'function IsIdentifierChar('),
    'Dead-code scans should use the shared Pascal lexical helper.');
  Assert.IsFalse(ContainsText(lGlobalVarsSource, 'function IsIdentifierChar('),
    'Global-var scans should use the shared Pascal lexical helper.');
  Assert.IsFalse(ContainsText(lGlobalVarsSource, 'function IsWordAt('),
    'Global-var word scans should use the shared Pascal word-boundary helper.');
  Assert.IsFalse(ContainsText(lQuerySource, 'function IsIdentifierChar('),
    'Query token extraction should use the shared Pascal lexical helper.');
  Assert.IsFalse(ContainsText(lRefactorSource, 'function IsIdentifierChar('),
    'Refactor token extraction should use the shared Pascal lexical helper.');
  Assert.IsFalse(ContainsText(lSourceContextSource, 'function IsIdentifierChar('),
    'Source-context candidate extraction should use the shared Pascal lexical helper.');
end;

procedure TUnitModelTests.SameLineNestedRoutineEndRestoresOuterReferenceScope;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticReference;
  lSource: string;
begin
  lPath := UnitModelTempPath('same-line-nested-scope.pas');
  lSource := 'unit SameLineNestedScope;' + sLineBreak +
    'interface' + sLineBreak + 'procedure Outer;' + sLineBreak +
    'implementation' + sLineBreak + 'procedure Outer;' + sLineBreak +
    'var lValue: Integer;' + sLineBreak +
    '  procedure Inner;' + sLineBreak +
    '  begin lValue := 1; end; begin lValue := 2; Inner; end;' + sLineBreak +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindReferenceAtOffset(lModel, 'lValue',
    Pos('lValue := 1', lSource), lReference));
  Assert.AreEqual('Inner', lReference.RoutineName);
  Assert.AreEqual('samelinenestedscope|outer()/inner()', lReference.RoutineScopeId);
  Assert.IsTrue(FindReferenceAtOffset(lModel, 'lValue',
    Pos('lValue := 2', lSource), lReference));
  Assert.AreEqual('Outer', lReference.RoutineName);
  Assert.AreEqual('samelinenestedscope|outer()', lReference.RoutineScopeId);
end;

procedure TUnitModelTests.AdjacentRoutineHeadersKeepTheirOwnTypeReferenceScope;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lReference: TDelphiSemanticReference;
  lSource: string;
begin
  lPath := UnitModelTempPath('adjacent-routine-headers.pas');
  lSource := 'unit AdjacentRoutineHeaders;' + sLineBreak +
    'interface' + sLineBreak + 'type PAliasValue = ^Integer;' + sLineBreak +
    'procedure Previous(var aText: string);' + sLineBreak +
    'procedure Following(var aValue: PAliasValue);' + sLineBreak +
    'implementation' + sLineBreak +
    'procedure Previous(var aText: string);' + sLineBreak +
    'begin end;' + sLineBreak +
    'procedure Following(var aValue: PAliasValue);' + sLineBreak +
    'begin end;' + sLineBreak + 'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindReferenceAtOffset(lModel, 'PAliasValue',
    Pos('PAliasValue);', lSource), lReference));
  Assert.AreEqual('Following', lReference.RoutineName);
  Assert.AreEqual('adjacentroutineheaders|following(var:paliasvalue)',
    lReference.RoutineScopeId);
end;

procedure TUnitModelTests.PointerAliasRetainsUnitDeclarationScope(const aIndented,
  aLean: Boolean);
var
  lDeclaration: TDelphiSemanticDeclaration;
  lIndent: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
begin
  lIndent := '';
  if aIndented then
    lIndent := '  ';
  lPath := UnitModelTempPath('pointer-alias-scope.pas');
  TFile.WriteAllText(lPath, 'unit PointerAliasScope;' + sLineBreak +
    'interface' + sLineBreak + 'type' + sLineBreak +
    '  TAliasRecord = packed record' + sLineBreak +
    '    Value: Integer;' + sLineBreak + '  end;' + sLineBreak +
    lIndent + 'PAliasRecord = ^TAliasRecord;' + sLineBreak +
    'implementation' + sLineBreak + 'type' + sLineBreak +
    '  PPrivateAlias = ^TAliasRecord;' + sLineBreak + 'end.', TEncoding.UTF8);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lOptions.SkipBodyAnalysis := aLean;
  lOptions.SkipReferenceExtraction := aLean;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindDeclaration(lModel, 'PAliasRecord', 'type-alias',
    'interface', lDeclaration));
  Assert.AreEqual(7, lDeclaration.Line);
  Assert.AreEqual(Length(lIndent) + 1, lDeclaration.Column);
  Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
  Assert.AreEqual('unit', lDeclaration.ScopeKind);
  Assert.AreEqual('PointerAliasScope', lDeclaration.OwnerName);
  Assert.IsTrue(FindDeclaration(lModel, 'PPrivateAlias', 'type-alias',
    'implementation', lDeclaration));
  Assert.AreEqual('declaration', lDeclaration.DeclarationRole,
    'Skipping routine bodies must preserve implementation declaration facts');
  Assert.AreEqual('unit', lDeclaration.ScopeKind);
end;

procedure TUnitModelTests.ModelJsonPreservesDeclarationRolesAndLexicalOwnership;
var
  lJson: string;
  lModel: TDelphiSemanticUnitModel;
  lRestored: TDelphiSemanticUnitModel;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.ScopeModelStatus := 'ast';
  lModel.ScopeModelVersion := '1';
  lModel.RejectedDeclarationCount := 2;
  SetLength(lModel.Declarations, 1);
  lModel.Declarations[0].Name := 'GValue';
  lModel.Declarations[0].DeclarationRole := 'declaration';
  lModel.Declarations[0].ScopeKind := 'unit';
  lModel.Declarations[0].OwnerName := 'ScopeFixture';
  lModel.Declarations[0].OwnerScopeId := 'unit:scopefixture';
  lModel.Declarations[0].SymbolId := 'unit:scopefixture:gvalue';
  lModel.Declarations[0].Mutable := True;
  SetLength(lModel.Routines, 1);
  lModel.Routines[0].Name := 'Run';
  lModel.Routines[0].EndLine := 17;
  lModel.Routines[0].EndColumn := 4;
  lModel.Routines[0].ScopeId := 'routine:scopefixture.run';
  lModel.Routines[0].ParentScopeId := 'unit:scopefixture';
  SetLength(lModel.Locals, 1);
  lModel.Locals[0].Name := 'lValue';
  lModel.Locals[0].RoutineScopeId := lModel.Routines[0].ScopeId;
  SetLength(lModel.References, 1);
  lModel.References[0].Name := 'GValue';
  lModel.References[0].RoutineScopeId := lModel.Routines[0].ScopeId;

  lJson := ModelToJson(lModel);
  lRestored := JsonToModel(lJson);

  Assert.AreEqual('ast', lRestored.ScopeModelStatus);
  Assert.AreEqual('1', lRestored.ScopeModelVersion);
  Assert.AreEqual(2, lRestored.RejectedDeclarationCount);
  Assert.AreEqual('declaration', lRestored.Declarations[0].DeclarationRole);
  Assert.AreEqual('unit', lRestored.Declarations[0].ScopeKind);
  Assert.AreEqual('ScopeFixture', lRestored.Declarations[0].OwnerName);
  Assert.AreEqual('unit:scopefixture', lRestored.Declarations[0].OwnerScopeId);
  Assert.AreEqual('unit:scopefixture:gvalue', lRestored.Declarations[0].SymbolId);
  Assert.IsTrue(lRestored.Declarations[0].Mutable);
  Assert.AreEqual(17, lRestored.Routines[0].EndLine);
  Assert.AreEqual(4, lRestored.Routines[0].EndColumn);
  Assert.AreEqual('routine:scopefixture.run', lRestored.Routines[0].ScopeId);
  Assert.AreEqual('unit:scopefixture', lRestored.Routines[0].ParentScopeId);
  Assert.AreEqual('routine:scopefixture.run', lRestored.Locals[0].RoutineScopeId);
  Assert.AreEqual('routine:scopefixture.run', lRestored.References[0].RoutineScopeId);
end;

procedure TUnitModelTests.PhysicalOccurrencesJsonRoundTripRetainsStatusAndIndependentArray;
var
  lModel: TDelphiSemanticUnitModel;
  lRestored: TDelphiSemanticUnitModel;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.PhysicalReferenceOccurrencesAvailable := True;
  SetLength(lModel.PhysicalReferenceOccurrences, 1);
  lModel.PhysicalReferenceOccurrences[0].Name := 'GF';
  lModel.PhysicalReferenceOccurrences[0].Role := 'reference';
  lModel.PhysicalReferenceOccurrences[0].RoutineName := 'Foo';
  lModel.PhysicalReferenceOccurrences[0].RoutineScopeId := 'routine:foo';
  lModel.PhysicalReferenceOccurrences[0].OutputStartOffset := 17;
  lModel.PhysicalReferenceOccurrences[0].OutputEndOffset := 19;
  lModel.PhysicalReferenceOccurrences[0].FileName := 'first.inc';
  lModel.PhysicalReferenceOccurrences[0].Line := 1;
  lModel.PhysicalReferenceOccurrences[0].Column := 7;
  lModel.PhysicalReferenceOccurrences[0].EndLine := 1;
  lModel.PhysicalReferenceOccurrences[0].EndColumn := 8;
  lModel.PhysicalReferenceOccurrences[0].ExpansionId := '2';
  lModel.PhysicalReferenceOccurrences[0].Verified := True;

  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(lRestored.PhysicalReferenceOccurrencesAvailable);
  Assert.AreEqual(1, Integer(Length(lRestored.PhysicalReferenceOccurrences)));
  Assert.AreEqual('GF', lRestored.PhysicalReferenceOccurrences[0].Name);
  Assert.AreEqual('reference', lRestored.PhysicalReferenceOccurrences[0].Role);
  Assert.AreEqual('Foo', lRestored.PhysicalReferenceOccurrences[0].RoutineName);
  Assert.AreEqual('routine:foo', lRestored.PhysicalReferenceOccurrences[0].RoutineScopeId);
  Assert.AreEqual(17, lRestored.PhysicalReferenceOccurrences[0].OutputStartOffset);
  Assert.AreEqual(19, lRestored.PhysicalReferenceOccurrences[0].OutputEndOffset);
  Assert.AreEqual('first.inc', lRestored.PhysicalReferenceOccurrences[0].FileName);
  Assert.AreEqual(1, lRestored.PhysicalReferenceOccurrences[0].Line);
  Assert.AreEqual(7, lRestored.PhysicalReferenceOccurrences[0].Column);
  Assert.AreEqual(1, lRestored.PhysicalReferenceOccurrences[0].EndLine);
  Assert.AreEqual(8, lRestored.PhysicalReferenceOccurrences[0].EndColumn);
  Assert.AreEqual('2', lRestored.PhysicalReferenceOccurrences[0].ExpansionId);
  Assert.IsTrue(lRestored.PhysicalReferenceOccurrences[0].Verified);
  lRestored.PhysicalReferenceOccurrences[0].Name := 'Changed';
  Assert.AreEqual('GF', lModel.PhysicalReferenceOccurrences[0].Name);

  lModel.PhysicalReferenceOccurrences[0].Verified := False;
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsFalse(lRestored.PhysicalReferenceOccurrences[0].Verified,
    'JSON must not promote an unverified origin');
end;

procedure TUnitModelTests.PhysicalOccurrencesAvailabilityDistinguishesOldAndEmptyModels;
var
  lDocument: TJSONObject;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPair: TJSONPair;
  lRestored: TDelphiSemanticUnitModel;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('EmptyPhysicalUnit.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit EmptyPhysicalUnit;'#13#10 + 'interface'#13#10 +
    'implementation'#13#10 + 'end.'#13#10, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(lModel.PhysicalReferenceOccurrencesAvailable);
  Assert.AreEqual(0, Integer(Length(lModel.PhysicalReferenceOccurrences)));
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(lRestored.PhysicalReferenceOccurrencesAvailable);

  lDocument := TJSONObject.ParseJSONValue(ModelToJson(lModel)) as TJSONObject;
  try
    lPair := lDocument.RemovePair('PhysicalReferenceOccurrences');
    lPair.Free;
    lPair := lDocument.RemovePair('PhysicalReferenceOccurrencesAvailable');
    lPair.Free;
    lRestored := JsonToModel(lDocument.ToJSON);
    Assert.IsFalse(lRestored.PhysicalReferenceOccurrencesAvailable,
      'Legacy JSON with no sidecar cannot prove an empty reference set');
    Assert.AreEqual(0, Integer(Length(lRestored.PhysicalReferenceOccurrences)));
  finally
    lDocument.Free;
  end;

  lModel.PhysicalReferenceOccurrencesAvailable := True;
  SetLength(lModel.PhysicalReferenceOccurrences, 1);
  lModel.PhysicalReferenceOccurrences[0].Name := 'GF';
  lModel.PhysicalReferenceOccurrences[0].OutputStartOffset := 20;
  lModel.PhysicalReferenceOccurrences[0].OutputEndOffset := 19;
  lModel.PhysicalReferenceOccurrences[0].Verified := True;
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsFalse(lRestored.PhysicalReferenceOccurrencesAvailable);
  Assert.IsFalse(lRestored.PhysicalReferenceOccurrences[0].Verified);
  Assert.IsTrue(HasDiagnostic(lRestored, 'PHYSICAL_REFERENCE_JSON_UNVERIFIED'));

  lModel.PhysicalReferenceOccurrences[0].Role := 'reference';
  lModel.PhysicalReferenceOccurrences[0].OutputStartOffset := 17;
  lModel.PhysicalReferenceOccurrences[0].OutputEndOffset := 19;
  lModel.PhysicalReferenceOccurrences[0].FileName := 'first.inc';
  lModel.PhysicalReferenceOccurrences[0].Line := 1;
  lModel.PhysicalReferenceOccurrences[0].Column := 7;
  lModel.PhysicalReferenceOccurrences[0].EndLine := 1;
  lModel.PhysicalReferenceOccurrences[0].EndColumn := 8;
  lModel.PhysicalReferenceOccurrences[0].ExpansionId := '';
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(lRestored.PhysicalReferenceOccurrencesAvailable,
    'An unverified origin does not erase an enumerated token');
  Assert.IsFalse(lRestored.PhysicalReferenceOccurrences[0].Verified);

  lModel.PhysicalReferenceOccurrences[0].ExpansionId := '2';
  lModel.PhysicalReferenceOccurrences[0].EndColumn := 9;
  lRestored := JsonToModel(ModelToJson(lModel));
  Assert.IsFalse(lRestored.PhysicalReferenceOccurrences[0].Verified,
    'A physical span width mismatch cannot stay verified');
end;

procedure TUnitModelTests.UnitModelImplementationIsSplitIntoFocusedUnits;
var
  lCoordinateSource: string;
  lExtractPath: string;
  lExtractSource: string;
  lModelSource: string;
  lTextSource: string;
begin
  lModelSource := ReadRepoSource('src\DelphiSemantics.Model.pas');
  lExtractPath := TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)), '..', '..',
    'src', 'DelphiSemantics.Model.Extract.pas']));

  Assert.IsTrue(TFile.Exists(lExtractPath), 'Expected focused model extraction unit.');
  lExtractSource := TFile.ReadAllText(lExtractPath, TEncoding.UTF8);
  lTextSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
    '..', '..', 'src', 'DelphiSemantics.Model.Text.pas'])), TEncoding.UTF8);
  lCoordinateSource := TFile.ReadAllText(TPath.GetFullPath(CombinePath([ExtractFilePath(ParamStr(0)),
    '..', '..', 'src', 'DelphiSemantics.Model.Coordinates.pas'])), TEncoding.UTF8);

  Assert.IsFalse(ContainsText(lModelSource, 'System.RegularExpressions'),
    'Model DTO contract must not own regex extraction implementation.');
  Assert.IsFalse(ContainsText(lModelSource, 'SanitizeCodeText'),
    'Model DTO contract must not own source sanitizing.');
  Assert.IsFalse(ContainsText(lModelSource, 'ReconcileReferencesCoordinates'),
    'Model DTO contract must not own coordinate reconciliation.');
  Assert.IsTrue(ContainsText(lExtractSource, 'TDelphiSemanticUnitModelExtractorImpl'),
    'Extraction implementation should live in the focused extraction unit.');
  Assert.IsTrue(ContainsText(lTextSource, 'SanitizeCodeText'),
    'Source sanitizing should live in the focused text helper unit.');
  Assert.IsTrue(ContainsText(lCoordinateSource, 'ReconcileReferencesCoordinates'),
    'Coordinate reconciliation should live in the focused coordinate unit.');
end;

procedure TUnitModelTests.ExtractsInlineConstVarSections;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lExpectedOffset: Integer;
  lName: string;
  lOptions: TDelphiSemanticModelOptions;
  lSource: string;
begin
  lSource := 'unit InlineSections;' + sLineBreak + 'interface' + sLineBreak +
    'var ScopeTarget, v, a, ScopeOther: Integer;' + sLineBreak +
    '  NextGlobal: Integer;' + sLineBreak +
    'const c = 0;' + sLineBreak +
    'const InlineConstant = 1;' + sLineBreak +
    '  NextConstant = 2;' + sLineBreak +
    'const InlineTyped: Integer = 3;' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('inline-sections.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  for lName in ['ScopeTarget', 'v', 'a', 'ScopeOther', 'NextGlobal'] do
  begin
    Assert.IsTrue(FindDeclaration(lModel, lName, 'var', 'interface', lDeclaration), lName);
    if MatchText(lName, ['v', 'a']) then
      lExpectedOffset := Pos(', ' + lName + ',', lSource) + 2
    else
      lExpectedOffset := Pos(lName, lSource);
    Assert.AreEqual(lExpectedOffset, lDeclaration.Offset, lName);
    Assert.AreEqual('declaration', lDeclaration.DeclarationRole, lName);
    Assert.AreEqual('unit', lDeclaration.ScopeKind, lName);
  end;
  for lName in ['c', 'InlineConstant', 'NextConstant'] do
  begin
    Assert.IsTrue(FindDeclaration(lModel, lName, 'const', 'interface', lDeclaration), lName);
    Assert.AreEqual(Pos(lName + ' =', lSource), lDeclaration.Offset, lName);
  end;
  Assert.IsTrue(FindDeclaration(lModel, 'InlineTyped', 'typed-const', 'interface', lDeclaration));
  Assert.AreEqual(Pos('InlineTyped', lSource), lDeclaration.Offset);
end;

procedure TUnitModelTests.ProgramBodyReferencesUseActualSyntaxScope;
var
  lExpectedOffset: Integer;
  lMode: Integer;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticReference;
  lReferenceCount: Integer;
  lSource: string;
  lWithRoutine: Boolean;
begin
  for lWithRoutine := False to True do
  begin
    lSource := 'program ProgramBodyReferences;' + sLineBreak +
      'uses ChangedValues;' + sLineBreak + 'var' + sLineBreak +
      '  lValue: Integer;' + sLineBreak;
    if lWithRoutine then
      lSource := lSource + 'procedure Work;' + sLineBreak + 'begin' + sLineBreak +
        '  lValue := RoutineValue;' + sLineBreak + 'end;' + sLineBreak;
    lExpectedOffset := Length(lSource) + Length('begin' + sLineBreak + '  lValue := ') + 1;
    lSource := lSource + 'begin' + sLineBreak + '  lValue := ChangedValue;' +
      sLineBreak + '  { IgnoreCommentValue }' + sLineBreak +
      '  Writeln(''IgnoreStringValue'');' + sLineBreak + 'end.';
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := UnitModelTempPath('program-body-references.dpr');
    lOptions.ProjectContextApplied := True;
    TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
    for lMode := 0 to 2 do
    begin
      lOptions.SkipBodyAnalysis := lMode = 1;
      lOptions.SkipReferenceExtraction := lMode = 2;
      lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
      Assert.IsTrue(lModel.Success);
      lReferenceCount := 0;
      for lReference in lModel.References do
      begin
        Assert.IsFalse(MatchText(lReference.Name, ['IgnoreCommentValue',
          'IgnoreStringValue']), lReference.Name);
        if lWithRoutine and (lMode = 0) and
          SameText(lReference.Name, 'RoutineValue') then
        begin
          Assert.AreEqual('Work', lReference.RoutineName);
          Assert.AreNotEqual('', lReference.RoutineScopeId);
        end;
        if SameText(lReference.Name, 'ChangedValue') then
        begin
          Inc(lReferenceCount);
          Assert.AreEqual(lExpectedOffset, lReference.Offset);
          Assert.AreEqual(lExpectedOffset + Length('ChangedValue'), lReference.EndOffset);
          Assert.AreEqual(LineContaining(lSource, '  lValue := ChangedValue;'), lReference.Line);
          Assert.AreEqual(13, lReference.Column);
          Assert.AreEqual('reference', lReference.Role);
          Assert.AreEqual('', lReference.RoutineName);
          Assert.AreEqual('', lReference.RoutineScopeId);
        end;
      end;
      Assert.AreEqual(Integer(Ord(lMode = 0)), lReferenceCount);
      if not lWithRoutine and (lMode = 0) then
        Assert.AreEqual(0, lModel.Metrics.ReferenceReconciliationFallbackCount,
          'Main-body coordinates must be exact before reconciliation.');
      if lWithRoutine and (lMode = 0) then
        Assert.IsTrue(HasReferenceAtOffset(lModel, 'RoutineValue',
          Pos('RoutineValue', lSource)));
      if lMode = 2 then
        Assert.AreEqual(0, Integer(Length(lModel.References)));
    end;
  end;
end;

procedure TUnitModelTests.VariantLabelsKeepFollowingFields(const aSplit: Boolean);
var
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSeparator: string;
  lSource: string;
begin
  lSeparator := ' ';
  if aSplit then
    lSeparator := sLineBreak + '      ';
  lSource := 'unit VariantLabelFields;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TVariant = record' + sLineBreak +
    '    case Boolean of' + sLineBreak +
    '      True:' + lSeparator + '(Handle: Integer);' + sLineBreak +
    '      False:' + lSeparator + '(Other: Integer);' + sLineBreak +
    '  end;' + sLineBreak + 'procedure AssignFields(var aValue: TVariant);' + sLineBreak +
    'implementation' + sLineBreak + 'procedure AssignFields(var aValue: TVariant);' + sLineBreak +
    'begin' + sLineBreak + '  with aValue do' + sLineBreak + '  begin' + sLineBreak +
    '    Handle := 1;' + sLineBreak + '    Other := Handle + 1;' + sLineBreak +
    '  end;' + sLineBreak + 'end;' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('VariantLabelFields.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindMember(lModel, 'TVariant', 'Handle', 'field', lMember),
    'A variant label must not consume the following field.');
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.AreEqual(Pos('Handle:', lSource), lMember.Offset);
  Assert.IsTrue(FindMember(lModel, 'TVariant', 'Other', 'field', lMember));
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.AreEqual(Pos('Other:', lSource), lMember.Offset);
  Assert.AreEqual(2, Integer(Length(lModel.Members)));
  lFacts := TDelphiSemanticWithBinder.BindProject('variant-label-fields', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  Assert.AreEqual(3, Integer(Length(lFacts.Bindings[0].References)));
  for lReference in lFacts.Bindings[0].References do
  begin
    Assert.AreEqual('member', lReference.Classification);
    Assert.AreEqual('TVariant', lReference.ReceiverTypeName);
    Assert.AreEqual('Integer', lReference.TypeName);
    Assert.AreEqual('', lReference.ReasonCode);
  end;
end;

procedure TUnitModelTests.LiteralFieldTypesKeepOriginalText;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSource: string;
begin
  lSource := 'unit LiteralFieldTypes;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TLetters = record' + sLineBreak +
    '    Letter: ''a''..''z'';' + sLineBreak +
    '    Letters: array[''a''..''z''] of Integer;' + sLineBreak +
    '  end;' + sLineBreak + 'implementation' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('LiteralFieldTypes.pas');
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindMember(lModel, 'TLetters', 'Letter', 'field', lMember));
  Assert.AreEqual('''a''..''z''', lMember.TypeName);
  Assert.AreEqual(Pos('Letter:', lSource), lMember.Offset);
  Assert.IsTrue(FindMember(lModel, 'TLetters', 'Letters', 'field', lMember));
  Assert.AreEqual('array[''a''..''z''] of Integer', lMember.TypeName);
  Assert.AreEqual(Pos('Letters:', lSource), lMember.Offset);
end;

procedure TUnitModelTests.MultilineFieldsKeepSourceAndBindingIdentity(const aLineComment: Boolean);
const
  cNames: array[0..5] of string = ('r', 'v', 'w', 's', 'ValueLong', 'Value');
  cSpellings: array[0..5] of string = ('r,', 'v:', 'w,', 's:', 'ValueLong,', 'Value:');
  cTypes: array[0..5] of string = ('PAnsiChar', 'PAnsiChar', 'Int32', 'Int32', 'Integer', 'Integer');
var
  i: Integer;
  lCount: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSource := 'unit MultilineFieldNames;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TFields = record' + sLineBreak +
    '    r,' + sLineBreak + '      v: PAnsiChar;' + sLineBreak + '    w, ';
  if aLineComment then
    lSource := lSource + '// HiddenField: Boolean;' + sLineBreak
  else
    lSource := lSource + '{ HiddenField: Boolean; }' + sLineBreak +
      '      (* HiddenOther: Byte; *)' + sLineBreak;
  lSource := lSource + '      s: Int32;' + sLineBreak +
    '    ValueLong, Value: Integer;' + sLineBreak + '  end;' + sLineBreak +
    'procedure AssignFields(var aFields: TFields);' + sLineBreak + 'implementation' + sLineBreak +
    'procedure AssignFields(var aFields: TFields);' + sLineBreak + 'begin' + sLineBreak +
    '  with aFields do' + sLineBreak + '  begin' + sLineBreak +
    '    r := nil;' + sLineBreak + '    v := r;' + sLineBreak +
    '    w := 1;' + sLineBreak + '    s := w;' + sLineBreak +
    '    ValueLong := s;' + sLineBreak + '    Value := ValueLong;' + sLineBreak +
    '  end;' + sLineBreak + 'end;' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('MultilineFieldNames.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(6, Integer(Length(lModel.Members)),
    'Each real field appears once; commented names are not fields.');
  lFacts := TDelphiSemanticWithBinder.BindProject('multiline-field-identity', nil, [lModel]);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  for i := Low(cNames) to High(cNames) do
  begin
    Assert.IsTrue(FindMember(lModel, 'TFields', cNames[i], 'field', lMember), cNames[i]);
    Assert.AreEqual(cTypes[i], lMember.TypeName, cNames[i]);
    Assert.AreEqual(Pos(cSpellings[i], lSource), lMember.Offset, cNames[i]);
    Assert.AreEqual(lMember.Offset + Length(cNames[i]), lMember.EndOffset, cNames[i]);
    Assert.AreEqual(LineContaining(lSource, cSpellings[i]), lMember.Line, cNames[i]);
    Assert.AreEqual(ColumnOfSourceOffset(lSource, lMember.Offset), lMember.Column, cNames[i]);
    lCount := 0;
    for lSymbol in lFacts.Symbols do
      if (lSymbol.Name = cNames[i]) and (lSymbol.SymbolClass = 'member') then
      begin
        Inc(lCount);
        Assert.AreEqual('TFields', lSymbol.OwnerType);
        Assert.AreEqual('TFields', lSymbol.OwnerName);
        Assert.AreEqual('field', lSymbol.Kind);
        Assert.AreEqual(cTypes[i], lSymbol.TypeName);
        Assert.AreEqual(lMember.Line, lSymbol.Line);
        Assert.AreEqual(lMember.Column, lSymbol.Column);
        Assert.AreEqual(lMember.Line, lSymbol.EndLine);
        Assert.AreEqual(lMember.Column, lSymbol.EndColumn);
      end;
    Assert.AreEqual(1, lCount, cNames[i]);
    lCount := 0;
    for lReference in lFacts.Bindings[0].References do
      if lReference.Name = cNames[i] then
      begin
        Inc(lCount);
        Assert.AreEqual('member', lReference.Classification, cNames[i]);
        Assert.AreEqual('TFields', lReference.ReceiverTypeName, cNames[i]);
        Assert.AreEqual(cTypes[i], lReference.TypeName, cNames[i]);
        Assert.AreEqual('', lReference.ReasonCode, cNames[i]);
      end;
    Assert.IsTrue(lCount > 0, cNames[i]);
  end;
end;

procedure TUnitModelTests.PackedAndOrdinaryFieldsKeepModelAndBindingIdentity(const aPacked: Boolean);
var
  lBinding: TDelphiSemanticWithBinding;
  lCount: Integer;
  lFacts: TDelphiSemanticProjectWithBindingFacts;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticBoundReference;
  lSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSource := 'unit RecordFieldIdentity;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TContainer = ';
  if aPacked then
    lSource := lSource + 'packed ';
  lSource := lSource + 'record' + sLineBreak + '    Value: Integer;' + sLineBreak +
    '  end;' + sLineBreak + 'procedure Bump(var aContainer: TContainer);' + sLineBreak +
    'implementation' + sLineBreak + 'procedure Bump(var aContainer: TContainer);' + sLineBreak +
    'begin' + sLineBreak + '  with aContainer do' + sLineBreak +
    '    Value := Value + 1;' + sLineBreak + 'end;' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('RecordFieldIdentity.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindMember(lModel, 'TContainer', 'Value', 'field', lMember),
    'Packing changes storage layout, not whether the record declares its field.');
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.AreEqual(Pos('Value: Integer', lSource), lMember.Offset);
  Assert.AreEqual(lMember.Offset + Length('Value'), lMember.EndOffset);
  Assert.AreEqual(5, lMember.Line, 'Model line');
  Assert.AreEqual(5, lMember.Column, 'Model column');
  lFacts := TDelphiSemanticWithBinder.BindProject('record-field-identity', nil, [lModel]);
  lCount := 0;
  for lSymbol in lFacts.Symbols do
    if (lSymbol.SymbolClass = 'member') and (lSymbol.OwnerName = 'TContainer') and
      (lSymbol.Name = 'Value') then
    begin
      Inc(lCount);
      Assert.AreEqual('field', lSymbol.Kind);
      Assert.AreEqual('TContainer', lSymbol.OwnerType);
      Assert.AreEqual('Integer', lSymbol.TypeName);
      Assert.AreEqual(5, lSymbol.Line, 'Inventory line');
      Assert.AreEqual(5, lSymbol.Column, 'Inventory column');
      Assert.AreEqual(lSymbol.Line, lSymbol.EndLine);
      Assert.AreEqual(lSymbol.Column, lSymbol.EndColumn);
    end;
  Assert.AreEqual(1, lCount);
  Assert.AreEqual(1, Integer(Length(lFacts.Bindings)));
  lBinding := lFacts.Bindings[0];
  lCount := 0;
  for lReference in lBinding.References do
    if lReference.Name = 'Value' then
    begin
      Inc(lCount);
      Assert.AreEqual('member', lReference.Classification);
      Assert.AreEqual('TContainer', lReference.ReceiverTypeName);
      Assert.AreEqual('Integer', lReference.TypeName);
      Assert.AreEqual('', lReference.ReasonCode);
      Assert.AreEqual(12, lReference.Line);
      Assert.AreEqual(12, lReference.EndLine);
      Assert.AreEqual(Length('Value'), lReference.EndColumn - lReference.Column + 1, 'Inclusive reference name span');
    end;
  Assert.AreEqual(2, lCount, 'Both the read and write must bind to the declared field.');
end;

procedure TUnitModelTests.GlobalsAroundClassDeclarationsKeepTheirScope(const aGlobalsFirst: Boolean);
const
  cGlobals = 'var' + sLineBreak + '    ShadowContainer: Integer;' + sLineBreak;
  cClass = 'type' + sLineBreak + '  TReader = class' + sLineBreak +
    '    function ReadValue: Integer;' + sLineBreak + '  end;' + sLineBreak;
var
  i: Integer;
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lInventory: TDelphiSemanticRemoveWithInventory;
  lLocal: TDelphiSemanticLocal;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSource: string;
  lSymbol: TDelphiSemanticInventorySymbol;
begin
  lSource := 'unit GlobalAfterClass;' + sLineBreak + 'interface' + sLineBreak;
  if aGlobalsFirst then
    lSource := lSource + cGlobals + cClass
  else
    lSource := lSource + cClass + cGlobals;
  lSource := lSource + 'implementation' + sLineBreak +
    'function TReader.ReadValue: Integer;' + sLineBreak +
    'var' + sLineBreak + '    lValue: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  lValue := ShadowContainer;' + sLineBreak + '  Result := lValue;' + sLineBreak +
    'end;' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('GlobalAfterClass.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(FindDeclaration(lModel, 'ShadowContainer', 'var', 'interface', lDeclaration));
  Assert.AreEqual('Integer', lDeclaration.TypeName);
  Assert.AreEqual(Pos('ShadowContainer:', lSource), lDeclaration.Offset);
  Assert.AreEqual(LineContaining(lSource, 'ShadowContainer:'), lDeclaration.Line);
  Assert.AreEqual(5, lDeclaration.Column);
  for i := 0 to High(lModel.Locals) do
    Assert.IsFalse(SameText('ShadowContainer', lModel.Locals[i].Name),
      'A class method declaration cannot own a later unit variable.');
  Assert.IsTrue(FindLocal(lModel, 'TReader.ReadValue', 'lValue', lLocal));
  Assert.AreEqual('Integer', lLocal.TypeName);
  Assert.AreEqual(Pos('lValue: Integer', lSource), lLocal.Offset);
  Assert.AreEqual(LineContaining(lSource, 'lValue:'), lLocal.Line);
  Assert.AreEqual(5, lLocal.Column);
  lInventory := TDelphiSemanticWithBinder.BuildInventory(lModel);
  lCount := 0;
  for lSymbol in lInventory.Symbols do
    if SameText('ShadowContainer', lSymbol.Name) then
    begin
      Inc(lCount);
      Assert.IsTrue(MatchText(lSymbol.SymbolClass, ['declaration', 'unit-global']),
        'Only the model and source-backed global projections are valid.');
      if lSymbol.SymbolClass = 'declaration' then
        Assert.AreEqual('var', lSymbol.Kind)
      else
        Assert.AreEqual('unit-global', lSymbol.Kind);
      Assert.AreEqual('', lSymbol.RoutineName);
      Assert.AreEqual('Integer', lSymbol.TypeName);
      Assert.AreEqual('GlobalAfterClass', lSymbol.UnitName);
      if lSymbol.SymbolClass = 'declaration' then
        Assert.AreEqual('interface', lSymbol.SectionKind)
      else
        Assert.AreEqual('', lSymbol.SectionKind);
      Assert.AreEqual(lDeclaration.Line, lSymbol.Line);
      Assert.AreEqual(lDeclaration.Column, lSymbol.Column);
      Assert.AreEqual(lDeclaration.Line, lSymbol.EndLine);
      if lSymbol.SymbolClass = 'unit-global' then
        Assert.AreEqual(lDeclaration.Column + Length('ShadowContainer'), lSymbol.EndColumn)
      else
        Assert.AreEqual(lDeclaration.Column, lSymbol.EndColumn);
    end;
  Assert.AreEqual(2, lCount, 'Both projections must identify the same single global source declaration.');
end;


procedure TUnitModelTests.AssignmentsDoNotBecomeDeclarations;
var
  lCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lSource: string;
begin
  // The nested routine ends before the outer VAR section, as in LINKFILE.
  lSource := 'unit AssignmentDeclarations;' + sLineBreak + 'interface' + sLineBreak +
    'var RestFiles: Integer = 3;' + sLineBreak +
    'procedure CheckLinkFiles;' + sLineBreak + 'implementation' + sLineBreak +
    'procedure CheckLinkFiles;' + sLineBreak +
    '  procedure Touch;' + sLineBreak + '  begin' + sLineBreak + '  end;' + sLineBreak +
    'var' + sLineBreak + '  i: Integer;' + sLineBreak + 'begin' + sLineBreak +
    '  Touch;' + sLineBreak + '  i := 1;' + sLineBreak +
    '  RestFiles := i;' + sLineBreak + '  RestFiles := 0;' + sLineBreak +
    'end;' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('AssignmentDeclarations.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lCount := 0;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'RestFiles') then
    begin
      Inc(lCount);
      Assert.AreEqual(Pos('RestFiles: Integer', lSource), lDeclaration.Offset,
        'An assignment site must not create a competing declaration.');
      Assert.AreEqual('var', lDeclaration.Kind);
      Assert.AreEqual('Integer', lDeclaration.TypeName);
      Assert.AreEqual('interface', lDeclaration.SectionKind);
      Assert.AreEqual(LineContaining(lSource, 'var RestFiles:'), lDeclaration.Line);
      Assert.AreEqual(ColumnOfSourceOffset(lSource, lDeclaration.Offset), lDeclaration.Column);
      Assert.AreEqual(lDeclaration.Offset + Length('RestFiles'), lDeclaration.EndOffset);
    end;
  Assert.AreEqual(1, lCount, 'Only the initialized global declaration belongs in the model.');
end;


procedure TUnitModelTests.InitializedVariablesRetainOnlyDeclaredTypes;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lExpectedOffset: Integer;
  lModel: TDelphiSemanticUnitModel;
  lName: string;
  lOptions: TDelphiSemanticModelOptions;
  lReference: TDelphiSemanticReference;
  lSource: string;
begin
  lSource := 'unit InitializedVariables;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + '  TRelRec = record' + sLineBreak +
    '    aktiv: Boolean;' + sLineBreak + '  end;' + sLineBreak +
    'var' + sLineBreak + '  RelRec: TRelRec = (aktiv: False);' + sLineBreak +
    'var InlineRec: TRelRec = (aktiv: True);' + sLineBreak +
    '  TRelRecValue: TRelRec = (aktiv: False);' + sLineBreak +
    '  Uninitialized: TRelRec;' + sLineBreak +
    '  Symbols: array[''=''..''>''] of Char = (''a'', ''b'');' + sLineBreak +
    '  UninitializedSymbols: array[''=''..''>''] of Char;' + sLineBreak +
    '  BooleanSymbols: array[False..(1 = 1)] of Char = (''c'', ''d'');' + sLineBreak +
    'threadvar ThreadRec: TRelRec;' + sLineBreak +
    'implementation' + sLineBreak + 'end.';
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('initialized-variables.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  for lName in ['RelRec', 'InlineRec', 'TRelRecValue', 'Uninitialized'] do
  begin
    Assert.IsTrue(FindDeclaration(lModel, lName, 'var', 'interface', lDeclaration), lName);
    Assert.AreEqual('TRelRec', lDeclaration.TypeName, lName);
    Assert.AreEqual(Pos(lName + ': TRelRec', lSource), lDeclaration.Offset, lName);
    Assert.AreEqual(LineContaining(lSource, lName + ': TRelRec'), lDeclaration.Line, lName);
    Assert.AreEqual(ColumnOfSourceOffset(lSource, lDeclaration.Offset),
      lDeclaration.Column, lName);
    lExpectedOffset := Pos(lName + ': TRelRec', lSource) + Length(lName) + 2;
    Assert.IsTrue(FindReferenceAtOffset(lModel, 'TRelRec', lExpectedOffset,
      lReference), lName);
    Assert.AreEqual('type-reference', lReference.Role, lName);
    Assert.AreEqual(lExpectedOffset + Length('TRelRec'), lReference.EndOffset, lName);
    Assert.AreEqual(lDeclaration.Line, lReference.Line, lName);
    Assert.AreEqual(ColumnOfSourceOffset(lSource, lExpectedOffset), lReference.Column, lName);
  end;
  Assert.IsTrue(FindDeclaration(lModel, 'Symbols', 'var', 'interface', lDeclaration));
  Assert.AreEqual('array[''=''..''>''] of Char', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'UninitializedSymbols', 'var', 'interface',
    lDeclaration));
  Assert.AreEqual('array[''=''..''>''] of Char', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'BooleanSymbols', 'var', 'interface', lDeclaration));
  Assert.AreEqual('array[False..(1 = 1)] of Char', lDeclaration.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'ThreadRec', 'threadvar', 'interface', lDeclaration));
  Assert.AreEqual('TRelRec', lDeclaration.TypeName);
  for lReference in lModel.References do
    if lReference.Role = 'type-reference' then
    begin
      if lReference.Line = LineContaining(lSource, 'BooleanSymbols:') then
        Assert.IsTrue(lReference.Offset < Pos(' = (''c''', lSource),
          'Array initializer values must not become type references.')
      else
        Assert.IsFalse(MatchText(lReference.Name, ['aktiv', 'False', 'True', 'a', 'b']),
          'Initializer values and fields must not become type references.');
    end;
end;

procedure TUnitModelTests.InlineConstSectionEndsTypeDeclarations;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('inline-const-after-type.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit InlineAfterType;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + 'TNumber = Integer;' + sLineBreak +
    'const First = 1;' + sLineBreak + 'Second = 2;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'TNumber', 'type-alias', 'interface'));
  Assert.IsTrue(HasDeclaration(lModel, 'Second', 'const', 'interface'));
  Assert.IsFalse(HasDeclaration(lModel, 'Second', 'type-alias', 'interface'),
    'A const section must terminate type extraction even when its first declaration shares the line.');
end;

procedure TUnitModelTests.MultilineVarParametersAreNotUnitVariables;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('multiline-var-parameters.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit MultilineVarParameters;' + sLineBreak + 'interface' + sLineBreak +
    'type' + sLineBreak + 'TValue = record' + sLineBreak +
    '  Count: Integer;' + sLineBreak + 'end;' + sLineBreak +
    'TScope = class' + sLineBreak + 'public' + sLineBreak +
    '  class procedure Touch(var aOuter: TValue;' + sLineBreak +
    '    var aInner: TValue);' + sLineBreak + 'end;' + sLineBreak +
    'var ScopeTarget: Integer;' + sLineBreak +
    'implementation' + sLineBreak +
    'class procedure TScope.Touch(var aOuter: TValue;' + sLineBreak +
    '  var aInner: TValue);' + sLineBreak + 'begin' + sLineBreak +
    '  aInner.Count := aOuter.Count;' + sLineBreak + 'end;' + sLineBreak +
    'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'ScopeTarget', 'var', 'interface'));
  Assert.IsFalse(HasDeclaration(lModel, 'aInner', 'var', 'interface'),
    'A parameter continuation must not enter the unit variable inventory.');
  Assert.IsFalse(HasDeclaration(lModel, 'aInner', 'var', 'implementation'));
end;

procedure TUnitModelTests.CommentedRoutineHeaderDoesNotHideUnitVariables;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('commented-routine-header.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit CommentedRoutineHeader;' + sLineBreak + 'interface' + sLineBreak +
    '{' + sLineBreak + 'procedure Example' + sLineBreak + '}' + sLineBreak +
    'var' + sLineBreak + '  Value: Integer;' + sLineBreak +
    'implementation' + sLineBreak + 'end.', TEncoding.UTF8);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(HasDeclaration(lModel, 'Value', 'var', 'interface'),
    'Commented header text must not consume the next real declaration.');
end;

procedure TUnitModelTests.NestedRoutineDeclarationHasEnclosingScope;
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lOuter, lNested: TDelphiSemanticRoutine;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('nested-routine-declaration-scope.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit NestedRoutineDeclarationScope;'#13#10'interface'#13#10 +
    'type TSubject = class procedure Execute; end;'#13#10'implementation'#13#10 +
    'procedure TSubject.Execute;'#13#10'  procedure Nested;'#13#10 +
    '  begin end;'#13#10'begin Nested; end;'#13#10'end.', TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindRoutine(lModel, 'Execute', 'implementation', lOuter));
  Assert.IsTrue(FindRoutine(lModel, 'Nested', 'implementation', lNested));
  Assert.IsTrue(FindDeclaration(lModel, 'Nested', 'routine', 'implementation', lDeclaration));
  Assert.AreEqual('declaration', lDeclaration.DeclarationRole);
  Assert.AreEqual('routine', lDeclaration.ScopeKind);
  Assert.AreEqual(lOuter.ScopeId, lDeclaration.OwnerScopeId);
  Assert.AreEqual(lOuter.ScopeId, lNested.ParentScopeId);
  Assert.AreEqual(0, lModel.RejectedDeclarationCount);
  lModel := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(FindDeclaration(lModel, 'Nested', 'routine', 'implementation', lDeclaration));
  Assert.AreEqual(lOuter.ScopeId, lDeclaration.OwnerScopeId, 'JSON retains lexical owner');
end;

procedure TUnitModelTests.RoutineLocalTypesRetainTheirDeclaringScope;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lModel: TDelphiSemanticUnitModel;
  lNested, lRunLocal, lRunNested: TDelphiSemanticRoutine;
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := FixturePath(
    'RemoveWithLocalCaptureType\LocalConsumer.pas');
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindRoutine(lModel, 'RunLocal', 'implementation', lRunLocal));
  Assert.IsTrue(FindRoutine(lModel, 'RunNested', 'implementation', lRunNested));
  Assert.IsTrue(FindRoutine(lModel, 'IncrementItem', 'implementation', lNested));
  Assert.AreEqual(lRunNested.ScopeId, lNested.ParentScopeId);
  Assert.AreNotEqual(lRunLocal.ScopeId, lRunNested.ScopeId);
  Assert.IsTrue(FindDeclaration(lModel, 'TLocal', 'type', 'implementation',
    lDeclaration), 'The source-backed local record must be materialized.');
  Assert.AreEqual('routine', lDeclaration.ScopeKind);
  Assert.AreEqual(lRunLocal.ScopeId, lDeclaration.OwnerScopeId);
  Assert.IsNotEmpty(lDeclaration.SymbolId);
  Assert.AreEqual(12, lDeclaration.Line);
  Assert.IsTrue(FindDeclaration(lModel, 'TOuter', 'type', 'implementation',
    lDeclaration), 'The enclosing local record must be materialized.');
  Assert.AreEqual('routine', lDeclaration.ScopeKind);
  Assert.AreEqual(lRunNested.ScopeId, lDeclaration.OwnerScopeId);
  Assert.IsNotEmpty(lDeclaration.SymbolId);
  Assert.AreEqual(28, lDeclaration.Line);
  lModel := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(FindDeclaration(lModel, 'TOuter', 'type', 'implementation',
    lDeclaration));
  Assert.AreEqual(lRunNested.ScopeId, lDeclaration.OwnerScopeId,
    'JSON must retain the lexical declaration owner.');
end;

procedure TUnitModelTests.HomonymousAndDistinctRoutineLocalTypesKeepSourceIdentity;
var
  lDeclaration: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lFirst, lNested, lSecond: TDelphiSemanticRoutine;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lSeenAlias, lSeenFirst, lSeenNested, lSeenOther, lSeenPointer, lSeenSecond: Boolean;
  lSource: string;
  lFirstSymbol, lNestedSymbol, lOtherSymbol, lSecondSymbol: string;
begin
  lPath := UnitModelTempPath('routine-local-type-identity.pas');
  lSource := 'unit RoutineLocalTypeIdentity;'#13#10 +
    'interface'#13#10 +
    'procedure First;'#13#10 +
    'procedure Second;'#13#10 +
    'implementation'#13#10 +
    'procedure First;'#13#10 +
    'type TItem = record FirstValue: Integer; end;'#13#10 +
    '     TOther = record OtherValue: Integer; end;'#13#10 +
    '     TAlias = TItem;'#13#10 +
    '     PItem = ^TItem;'#13#10 +
    '  procedure Nested;'#13#10 +
    '  type TItem = record NestedValue: Integer; end;'#13#10 +
    '  begin end;'#13#10 +
    'begin Nested; end;'#13#10 +
    'procedure Second;'#13#10 +
    'type TItem = record SecondValue: Integer; end;'#13#10 +
    'begin end;'#13#10 +
    'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindRoutine(lModel, 'First', 'implementation', lFirst));
  Assert.IsTrue(FindRoutine(lModel, 'Nested', 'implementation', lNested));
  Assert.IsTrue(FindRoutine(lModel, 'Second', 'implementation', lSecond));
  Assert.AreEqual(lFirst.ScopeId, lNested.ParentScopeId);
  lSeenAlias := False;
  lSeenFirst := False;
  lSeenNested := False;
  lSeenSecond := False;
  lSeenOther := False;
  lSeenPointer := False;
  lFirstSymbol := '';
  lNestedSymbol := '';
  lSecondSymbol := '';
  lOtherSymbol := '';
  for lDeclaration in lModel.Declarations do
  begin
    if not SameText(lDeclaration.ScopeKind, 'routine') then
      Continue;
    if SameText(lDeclaration.Name, 'TItem') and SameText(lDeclaration.Kind, 'type') and
      (lDeclaration.OwnerScopeId = lFirst.ScopeId) then
    begin
      lSeenFirst := True;
      Assert.AreEqual(7, lDeclaration.Line);
      lFirstSymbol := lDeclaration.SymbolId;
    end else if SameText(lDeclaration.Name, 'TItem') and SameText(lDeclaration.Kind, 'type') and
      (lDeclaration.OwnerScopeId = lNested.ScopeId) then
    begin
      lSeenNested := True;
      Assert.AreEqual(12, lDeclaration.Line);
      lNestedSymbol := lDeclaration.SymbolId;
    end else if SameText(lDeclaration.Name, 'TItem') and
      SameText(lDeclaration.Kind, 'type') and
      (lDeclaration.OwnerScopeId = lSecond.ScopeId) then
    begin
      lSeenSecond := True;
      Assert.AreEqual(16, lDeclaration.Line);
      lSecondSymbol := lDeclaration.SymbolId;
    end else if SameText(lDeclaration.Name, 'TOther') and
      SameText(lDeclaration.Kind, 'type') and
      (lDeclaration.OwnerScopeId = lFirst.ScopeId) then
    begin
      lSeenOther := True;
      Assert.AreEqual(8, lDeclaration.Line);
      lOtherSymbol := lDeclaration.SymbolId;
    end else if SameText(lDeclaration.Name, 'TAlias') and
      SameText(lDeclaration.Kind, 'type-alias') and
      (lDeclaration.OwnerScopeId = lFirst.ScopeId) then
    begin
      lSeenAlias := True;
      Assert.AreEqual('TItem', lDeclaration.TypeName);
      Assert.AreEqual(9, lDeclaration.Line);
      Assert.IsNotEmpty(lDeclaration.SymbolId);
    end else if SameText(lDeclaration.Name, 'PItem') and
      SameText(lDeclaration.Kind, 'type-alias') and
      (lDeclaration.OwnerScopeId = lFirst.ScopeId) then
    begin
      lSeenPointer := True;
      Assert.AreEqual('^TItem', lDeclaration.TypeName);
      Assert.AreEqual(10, lDeclaration.Line);
      Assert.IsNotEmpty(lDeclaration.SymbolId);
    end;
  end;
  Assert.IsTrue(lSeenFirst, 'First.TItem must retain its source scope.');
  Assert.IsTrue(lSeenNested, 'Nested.TItem must shadow its enclosing type.');
  Assert.IsTrue(lSeenSecond, 'Second.TItem must retain its source scope.');
  Assert.IsTrue(lSeenOther, 'First.TOther must retain its source scope.');
  Assert.IsTrue(lSeenAlias, 'The alias must retain its declaration scope.');
  Assert.IsTrue(lSeenPointer, 'The pointer must retain its declaration scope.');
  Assert.IsNotEmpty(lFirstSymbol);
  Assert.IsNotEmpty(lNestedSymbol);
  Assert.IsNotEmpty(lSecondSymbol);
  Assert.IsNotEmpty(lOtherSymbol);
  Assert.AreNotEqual(lFirstSymbol, lSecondSymbol);
  Assert.AreNotEqual(lFirstSymbol, lNestedSymbol);
  Assert.AreNotEqual(lFirstSymbol, lOtherSymbol);
  lSeenFirst := False;
  lSeenSecond := False;
  for lMember in lModel.Members do
  begin
    if SameText(lMember.Name, 'FirstValue') then
    begin
      Assert.AreEqual(lFirst.ScopeId, lMember.OwnerScopeId);
      Assert.AreEqual(lFirstSymbol, lMember.OwnerSymbolId);
      lSeenFirst := True;
    end else if SameText(lMember.Name, 'SecondValue') then
    begin
      Assert.AreEqual(lSecond.ScopeId, lMember.OwnerScopeId);
      Assert.AreEqual(lSecondSymbol, lMember.OwnerSymbolId);
      lSeenSecond := True;
    end;
  end;
  Assert.IsTrue(lSeenFirst and lSeenSecond,
    'AST members must retain their exact local owning type.');
  lModel := JsonToModel(ModelToJson(lModel));
  lSeenFirst := False;
  for lMember in lModel.Members do
    if SameText(lMember.Name, 'FirstValue') then
    begin
      Assert.AreEqual(lFirst.ScopeId, lMember.OwnerScopeId);
      Assert.AreEqual(lFirstSymbol, lMember.OwnerSymbolId);
      lSeenFirst := True;
    end;
  Assert.IsTrue(lSeenFirst, 'Model JSON must retain local member ownership.');
end;

procedure TUnitModelTests.ExtractsFieldAfterVisibility(const aVisibility, aKind: string;
  const aInline: Boolean);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lMember: TDelphiSemanticMember;
  lSource, lField: string;
begin
  lField := 'fValue: Integer;';
  if aKind = 'class-var' then
    lField := 'class var ' + lField;
  if aInline then
    lField := aVisibility + ' ' + lField
  else
    lField := aVisibility + #13#10'  ' + lField;
  lSource := 'unit VisibilityFields;'#13#10'interface'#13#10 +
    'type'#13#10'  TSubject = class'#13#10'  ' + lField + #13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('visibility-fields.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual(0, lModel.RejectedDeclarationCount);
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'fValue', aKind, lMember));
  Assert.AreEqual(aVisibility, lMember.Visibility);
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.AreEqual(Pos('fValue', lSource), lMember.Offset);
  Assert.AreEqual(lMember.Offset + Length('fValue'), lMember.EndOffset);
  Assert.AreEqual(ColumnOfSourceOffset(lSource, lMember.Offset), lMember.Column);
  Assert.AreEqual('fValue', Copy(lSource, lMember.Offset, lMember.EndOffset - lMember.Offset));
  lModel := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'fValue', aKind, lMember));
  Assert.AreEqual(aVisibility, lMember.Visibility);
end;

procedure TUnitModelTests.ExtractsCompoundVisibilityFields(const aLayout: string);
var
  lOptions: TDelphiSemanticModelOptions;
  lModel: TDelphiSemanticUnitModel;
  lMember: TDelphiSemanticMember;
  lSource, lFields, lKind, lVisibility: string;
begin
  lFields := 'public fFirst: Integer; fSecond: Integer;';
  lKind := 'field';
  lVisibility := 'public';
  if aLayout = 'visibility' then
  begin
    lFields := 'public fFirst: Integer; private fSecond: Integer;';
    lVisibility := 'private';
  end else if aLayout = 'class-var' then
  begin
    lFields := 'public class var fFirst: Integer; fSecond: Integer;';
    lKind := 'class-var';
  end;
  lSource := 'unit CompoundVisibility;'#13#10'interface'#13#10 +
    'type'#13#10'  TSubject = class'#13#10'  ' + lFields + #13#10 +
    '  end;'#13#10'implementation'#13#10'end.'#13#10;
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath('compound-visibility.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName, lSource, TEncoding.ASCII);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'fFirst', lKind, lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'fSecond', lKind, lMember));
  Assert.AreEqual(lVisibility, lMember.Visibility);
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.AreEqual(Pos('fSecond', lSource), lMember.Offset);
  Assert.AreEqual(ColumnOfSourceOffset(lSource, lMember.Offset), lMember.Column);
  Assert.AreEqual('fSecond', Copy(lSource, lMember.Offset, lMember.EndOffset - lMember.Offset));
end;

function ExtractUnitSource(const aFileName, aSource: string;
  const aSkipBodyAnalysis: Boolean): TDelphiSemanticUnitModel;
var
  lOptions: TDelphiSemanticModelOptions;
begin
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := UnitModelTempPath(aFileName);
  lOptions.ProjectContextApplied := True;
  lOptions.SkipBodyAnalysis := aSkipBodyAnalysis;
  TFile.WriteAllText(lOptions.SourceFileName, aSource, TEncoding.ASCII);
  Result := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
end;

// Lists an owner's members in model order so tests assert the exact member set.
function OwnerMemberNames(const aModel: TDelphiSemanticUnitModel; const aOwnerName: string): string;
var
  lMember: TDelphiSemanticMember;
begin
  Result := '';
  for lMember in aModel.Members do
    if SameText(lMember.OwnerName, aOwnerName) then
      Result := Result + lMember.Name + ',';
end;

function DiagnosticCodes(const aModel: TDelphiSemanticUnitModel): string;
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  Result := '';
  for lDiagnostic in aModel.Diagnostics do
    Result := Result + lDiagnostic.Code + ',';
end;

function DiagnosticMessage(const aModel: TDelphiSemanticUnitModel; const aCode: string): string;
var
  lDiagnostic: TDelphiSemanticModelDiagnostic;
begin
  for lDiagnostic in aModel.Diagnostics do
    if SameText(lDiagnostic.Code, aCode) then
      Exit(lDiagnostic.Message);
  Result := '';
end;

procedure TUnitModelTests.ExtractsEveryMemberOnOnePhysicalLine(const aLayout: string);
var
  lExpectedNames: string;
  lLine: string;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lName: string;
  lNames: TArray<string>;
  lSource: string;
begin
  if aLayout = 'two-methods' then
  begin
    lLine := '  published procedure HandleOther(aValue: TValue); ' +
      'procedure HandleData(aValue: TValue);';
    lExpectedNames := 'HandleOther,HandleData,';
  end else
  begin
    // The next-line method must keep the visibility opened on the previous line.
    lLine := '  private FX: Integer; published procedure HandleOther(aValue: TValue);'#13#10 +
      '    procedure HandleData(aValue: TValue);';
    lExpectedNames := 'FX,HandleOther,HandleData,';
  end;
  lSource := 'unit SameLineMembers;'#13#10'interface'#13#10'type'#13#10 +
    '  TValue = class end;'#13#10'  TSubject = class'#13#10 + lLine + #13#10'  end;'#13#10 +
    'implementation'#13#10 +
    'procedure TSubject.HandleOther(aValue: TValue); begin end;'#13#10 +
    'procedure TSubject.HandleData(aValue: TValue); begin end;'#13#10'end.'#13#10;
  lModel := ExtractUnitSource('same-line-members.pas', lSource, False);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual('', DiagnosticCodes(lModel), 'Reconciled members must not be marked incomplete.');
  Assert.AreEqual(lExpectedNames, OwnerMemberNames(lModel, 'TSubject'));
  lNames := ['HandleOther', 'HandleData'];
  for lName in lNames do
  begin
    Assert.IsTrue(FindMember(lModel, 'TSubject', lName, 'method', lMember), lName);
    Assert.AreEqual('published', lMember.Visibility, lName);
    Assert.AreEqual(Pos(lName, lSource), lMember.Offset, lName);
    Assert.AreEqual(ColumnOfSourceOffset(lSource, lMember.Offset), lMember.Column, lName);
    Assert.IsTrue(lMember.ProcedureSignature.Known, lName);
    Assert.AreEqual(1, Integer(Length(lMember.ProcedureSignature.Parameters)), lName);
    Assert.AreEqual('TValue', lMember.ProcedureSignature.Parameters[0].TypeName, lName);
  end;
  if aLayout <> 'two-methods' then
  begin
    Assert.IsTrue(FindMember(lModel, 'TSubject', 'FX', 'field', lMember));
    Assert.AreEqual('private', lMember.Visibility);
    Assert.AreEqual('Integer', lMember.TypeName);
    Assert.AreEqual(Pos('FX', lSource), lMember.Offset);
  end;
end;

procedure TUnitModelTests.MethodContinuationParametersAreNotFields;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lSource: string;
begin
  lSource := 'unit ContinuationMembers;'#13#10'interface'#13#10'type'#13#10 +
    '  TSubject = class'#13#10'  public'#13#10 +
    '    procedure Run(aFirst: Integer;'#13#10'      aSecond: Integer);'#13#10 +
    '    property Count: Integer read GetCount;'#13#10 +
    '    function GetCount: Integer;'#13#10'  end;'#13#10 +
    'implementation'#13#10 +
    'procedure TSubject.Run(aFirst: Integer; aSecond: Integer); begin end;'#13#10 +
    'function TSubject.GetCount: Integer; begin Result := 0; end;'#13#10'end.'#13#10;
  lModel := ExtractUnitSource('continuation-members.pas', lSource, False);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual('', DiagnosticCodes(lModel));
  Assert.AreEqual('Run,Count,GetCount,', OwnerMemberNames(lModel, 'TSubject'),
    'A parameter on a continuation line is not a field.');
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'Run', 'method', lMember));
  Assert.AreEqual(2, Integer(Length(lMember.ProcedureSignature.Parameters)));
end;

procedure TUnitModelTests.EscapedIdentifierMembersAreKept;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lSource: string;
begin
  lSource := 'unit EscapedMembers;'#13#10'interface'#13#10'type'#13#10 +
    '  TSubject = class'#13#10'  public'#13#10'    &Type: Integer;'#13#10 +
    '    procedure &Label(aValue: Integer);'#13#10 +
    '    property &End: Integer read &Type;'#13#10'  end;'#13#10 +
    'implementation'#13#10'procedure TSubject.&Label(aValue: Integer); begin end;'#13#10 +
    'end.'#13#10;
  lModel := ExtractUnitSource('escaped-members.pas', lSource, False);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual('', DiagnosticCodes(lModel));
  Assert.AreEqual('Type,Label,End,', OwnerMemberNames(lModel, 'TSubject'));
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'Label', 'method', lMember));
  Assert.AreEqual(Pos('Label', lSource), lMember.Offset);
  Assert.IsTrue(lMember.ProcedureSignature.Known);
end;

procedure TUnitModelTests.NestedTypeMembersKeepQualifiedOwnerAndVisibility;
var
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lSource: string;
begin
  // The nested class ends in a private section; the outer method after it stays public.
  lSource := 'unit NestedMembers;'#13#10'interface'#13#10'type'#13#10 +
    '  TValue = class end;'#13#10 +
    '  TBindingForm = class'#13#10 +
    '  public'#13#10 +
    '    type'#13#10 +
    '      TInner = class'#13#10 +
    '      public'#13#10 +
    '        procedure HandleData(aValue: TValue);'#13#10 +
    '      private'#13#10 +
    '        FHidden: Integer;'#13#10 +
    '      end;'#13#10 +
    '    procedure OuterAfter;'#13#10 +
    '  published'#13#10 +
    '    procedure HandleOther(aValue: TValue);'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'procedure TBindingForm.TInner.HandleData(aValue: TValue); begin end;'#13#10 +
    'procedure TBindingForm.OuterAfter; begin end;'#13#10 +
    'procedure TBindingForm.HandleOther(aValue: TValue); begin end;'#13#10'end.'#13#10;
  lModel := ExtractUnitSource('nested-members.pas', lSource, False);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual('', DiagnosticCodes(lModel));
  Assert.AreEqual('OuterAfter,HandleOther,', OwnerMemberNames(lModel, 'TBindingForm'));
  Assert.AreEqual('HandleData,FHidden,', OwnerMemberNames(lModel, 'TBindingForm.TInner'));
  Assert.IsTrue(FindMember(lModel, 'TBindingForm.TInner', 'HandleData', 'method', lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.AreEqual(Pos('HandleData', lSource), lMember.Offset);
  Assert.IsTrue(lMember.ProcedureSignature.Known);
  Assert.IsTrue(FindMember(lModel, 'TBindingForm.TInner', 'FHidden', 'field', lMember));
  Assert.AreEqual('private', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TBindingForm', 'OuterAfter', 'method', lMember));
  Assert.AreEqual('public', lMember.Visibility, 'Nested visibility must not leak into the outer class.');
  Assert.IsTrue(FindMember(lModel, 'TBindingForm', 'HandleOther', 'method', lMember));
  Assert.AreEqual('published', lMember.Visibility);
end;

procedure TUnitModelTests.AstFailedUnitKeepsUnverifiedMembers;
var
  lAnalysis: TDelphiSemanticGlobalAnalysis;
  lDeclaration: TDelphiSemanticDeclaration;
  lMember: TDelphiSemanticMember;
  lModel: TDelphiSemanticUnitModel;
  lSource: string;
begin
  lSource := 'unit FailedMembers;'#13#10'interface'#13#10'type'#13#10 +
    '  TSubject = class'#13#10'  private'#13#10'    FValue: Integer;'#13#10 +
    '    class var FShared: Integer;'#13#10 +
    '  public'#13#10'    procedure Run(aFirst: Integer;'#13#10'      aSecond: Integer);'#13#10 +
    '    property Value: Integer read FValue;'#13#10'  end;'#13#10 +
    '  TOther = class end;'#13#10 +
    'implementation'#13#10'procedure TSubject.Run(aFirst: Integer; aSecond: Integer);'#13#10 +
    'begin'#13#10'  if ('#13#10'end;'#13#10'end.'#13#10;
  lModel := ExtractUnitSource('failed-members.pas', lSource, False);
  lAnalysis := TDelphiSemanticGlobalAnalyzer.AnalyzeUnits([lModel]);
  Assert.AreEqual('ast-failed', lModel.ScopeModelStatus);
  Assert.IsTrue(HasDiagnostic(lModel, 'SCOPE_MODEL_FAILED'));
  Assert.IsTrue(HasDiagnostic(lModel, 'MEMBERS_UNVERIFIED'),
    'Fallback members must be reported as unverified.');
  Assert.AreEqual(0, Integer(Length(lAnalysis.Declarations)),
    'Unverified class variables must not become global candidates.');
  Assert.AreEqual('', OwnerMemberNames(lModel, 'TOther'), 'A one-line class ends its own block.');
  Assert.AreEqual('FValue,Run,Value,', OwnerMemberNames(lModel, 'TSubject'));
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'FValue', 'field', lMember));
  Assert.AreEqual('private', lMember.Visibility);
  Assert.AreEqual(Pos('FValue', lSource), lMember.Offset);
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'Run', 'method', lMember));
  Assert.AreEqual('public', lMember.Visibility);
  Assert.IsTrue(FindMember(lModel, 'TSubject', 'Value', 'property', lMember));
  Assert.AreEqual('Integer', lMember.TypeName);
  Assert.IsTrue(FindDeclaration(lModel, 'TSubject', 'type', 'interface', lDeclaration));
  Assert.AreEqual('invalid', lDeclaration.DeclarationRole,
    'A fallback type must not claim a complete declaration.');
  lModel := JsonToModel(ModelToJson(lModel));
  Assert.IsTrue(HasDiagnostic(lModel, 'MEMBERS_UNVERIFIED'), 'JSON keeps the unverified marker.');
  Assert.AreEqual('FValue,Run,Value,', OwnerMemberNames(lModel, 'TSubject'));
end;

procedure TUnitModelTests.InterfaceOnlyRetryKeepsOriginalParserMessage;
var
  lExpected: string;
  lModel: TDelphiSemanticUnitModel;
  lSource: string;
begin
  lSource := 'unit RetryMembers;'#13#10'interface'#13#10'type'#13#10 +
    '  TSubject = class'#13#10'  public'#13#10'    procedure Run;'#13#10'  end;'#13#10 +
    'implementation'#13#10'procedure TSubject.Run;'#13#10'begin'#13#10'  if ('#13#10 +
    'end;'#13#10'end.'#13#10;
  lExpected := DiagnosticMessage(ExtractUnitSource('retry-members-full.pas', lSource, False),
    'SCOPE_MODEL_FAILED');
  Assert.AreNotEqual('', lExpected);
  lModel := ExtractUnitSource('retry-members.pas', lSource, True);
  Assert.AreEqual('ast-interface-only', lModel.ScopeModelStatus);
  Assert.AreEqual(lExpected, DiagnosticMessage(lModel, 'AST_BODY_PARSE_FAILED'),
    'The interface-only retry must keep the original parser message.');
  Assert.AreEqual('Run,', OwnerMemberNames(lModel, 'TSubject'));
end;

// Lists the locals and references named in aNames as sorted "L:Routine.Name@line" and
// "R:Name@line>Routine" keys, so a test asserts the exact owner of every fact.
function BodyFactsText(const aModel: TDelphiSemanticUnitModel;
  const aNames: array of string): string;
var
  lKeys: TStringList;
  lLocal: TDelphiSemanticLocal;
  lReference: TDelphiSemanticReference;
begin
  lKeys := TStringList.Create;
  try
    lKeys.Sorted := True;
    lKeys.Duplicates := dupAccept;
    for lLocal in aModel.Locals do
      if MatchText(lLocal.Name, aNames) then
        lKeys.Add(Format('L:%s.%s@%d', [lLocal.RoutineName, lLocal.Name, lLocal.Line]));
    for lReference in aModel.References do
      if MatchText(lReference.Name, aNames) then
        lKeys.Add(Format('R:%s@%d>%s', [lReference.Name, lReference.Line,
          lReference.RoutineName]));
    Result := string.Join(' ', lKeys.ToStringArray);
  finally
    lKeys.Free;
  end;
end;

function SortedFactKeys(const aKeys: array of string): string;
var
  lKeys: TStringList;
  lKey: string;
begin
  lKeys := TStringList.Create;
  try
    lKeys.Sorted := True;
    lKeys.Duplicates := dupAccept;
    for lKey in aKeys do
      lKeys.Add(lKey);
    Result := string.Join(' ', lKeys.ToStringArray);
  finally
    lKeys.Free;
  end;
end;

// DS-653: First's body ends at its own "end;" even when "begin" shares the line. The var section
// after it and the program main block belong to no routine; the global Shared is not First's local.
procedure TUnitModelTests.ProgramRoutineBodiesEndBeforeVarSectionsAndMainBlock;
var
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := ExtractUnitSource('body-bounds-program.dpr',
    'program BodyBounds;'#13#10 + // 1
    'var'#13#10 + // 2
    '  Shared: Integer;'#13#10 + // 3
    'procedure First;'#13#10 + // 4
    'var'#13#10 + // 5
    '  Shared: Integer;'#13#10 + // 6
    'begin Shared := 1; end;'#13#10 + // 7
    'var'#13#10 + // 8
    '  Between: Integer;'#13#10 + // 9
    'procedure Second;'#13#10 + // 10
    'begin'#13#10 + // 11
    '  Shared := 2;'#13#10 + // 12
    '  Between := 3;'#13#10 + // 13
    'end;'#13#10 + // 14
    'begin'#13#10 + // 15
    '  Shared := 4;'#13#10 + // 16
    '  Second;'#13#10 + // 17
    'end.'#13#10, False);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual(SortedFactKeys(['L:First.Shared@6', 'R:Shared@7>First', 'R:Shared@12>Second',
    'R:Between@13>Second', 'R:Shared@16>']), BodyFactsText(lModel, ['Shared', 'Between']));
end;

// DS-653: an interface header owns no body, so the implementation var section is no local of
// Work; initialization and finalization statements belong to no routine.
procedure TUnitModelTests.InterfaceHeadersAndInitializationGetNoRoutineBody;
var
  lModel: TDelphiSemanticUnitModel;
  lRoutine: TDelphiSemanticRoutine;
  lVerifiedWorkDeclarations: Integer;
begin
  lModel := ExtractUnitSource('body-bounds-unit.pas',
    'unit BodyBoundsUnit;'#13#10 + // 1
    'interface'#13#10 + // 2
    'procedure Work;'#13#10 + // 3
    'implementation'#13#10 + // 4
    'var'#13#10 + // 5
    '  Counter: Integer;'#13#10 + // 6
    'procedure Helper;'#13#10 + // 7
    'var'#13#10 + // 8
    '  Counter: Integer;'#13#10 + // 9
    'begin'#13#10 + // 10
    '  Counter := 5;'#13#10 + // 11
    'end;'#13#10 + // 12
    'procedure Work;'#13#10 + // 13
    'begin'#13#10 + // 14
    '  Counter := 1;'#13#10 + // 15
    'end;'#13#10 + // 16
    'initialization'#13#10 + // 17
    '  Counter := 2;'#13#10 + // 18
    'finalization'#13#10 + // 19
    '  Counter := 3;'#13#10 + // 20
    'end.'#13#10, False);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lVerifiedWorkDeclarations := 0;
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'Work') then
    begin
      Assert.AreEqual('()', lRoutine.AstSemanticSignature);
      Assert.AreEqual('', lRoutine.AstSourceSignature);
      Assert.IsTrue(lRoutine.AstSourceSignatureVerified);
      Inc(lVerifiedWorkDeclarations);
    end;
  Assert.AreEqual(2, lVerifiedWorkDeclarations,
    'An empty-arity interface header and body retain separate AST evidence.');
  Assert.AreEqual(SortedFactKeys(['L:Helper.Counter@9', 'R:Counter@11>Helper',
    'R:Counter@15>Work', 'R:Counter@18>', 'R:Counter@20>']),
    BodyFactsText(lModel, ['Counter']));
end;

// DS-653: nested routines, an anonymous method, a local record type and an asm body each end
// where the syntax tree ends them; declarations after them are neither locals nor references.
// Assembler operands are not classified, so aValue on line 35 yields no reference.
procedure TUnitModelTests.NestedAnonymousAsmAndLocalTypeBodiesAreBounded;
var
  lModel: TDelphiSemanticUnitModel;
begin
  lModel := ExtractUnitSource('body-bounds-nested.pas',
    'unit BodyBoundsNested;'#13#10 + // 1
    'interface'#13#10 + // 2
    'procedure Outer;'#13#10 + // 3
    'function Asmy(aValue: Integer): Integer;'#13#10 + // 4
    'implementation'#13#10 + // 5
    'uses System.SysUtils;'#13#10 + // 6
    'procedure Outer;'#13#10 + // 7
    'var'#13#10 + // 8
    '  lCount: Integer;'#13#10 + // 9
    'type'#13#10 + // 10
    '  TLocalRec = record'#13#10 + // 11
    '    Field: Integer;'#13#10 + // 12
    '  end;'#13#10 + // 13
    'var'#13#10 + // 14
    '  lRec: TLocalRec;'#13#10 + // 15
    '  procedure Inner;'#13#10 + // 16
    '  var'#13#10 + // 17
    '    lInner: Integer;'#13#10 + // 18
    '  begin'#13#10 + // 19
    '    lInner := lRec.Field + lCount;'#13#10 + // 20
    '  end;'#13#10 + // 21
    'var'#13#10 + // 22
    '  lProc: TProc;'#13#10 + // 23
    'begin'#13#10 + // 24
    '  lProc := procedure'#13#10 + // 25
    '    begin'#13#10 + // 26
    '      lRec.Field := lCount;'#13#10 + // 27
    '    end;'#13#10 + // 28
    '  Inner;'#13#10 + // 29
    'end;'#13#10 + // 30
    'var'#13#10 + // 31
    '  Tail: Integer;'#13#10 + // 32
    'function Asmy(aValue: Integer): Integer;'#13#10 + // 33
    'asm'#13#10 + // 34
    '  MOV EAX, aValue'#13#10 + // 35
    'end;'#13#10 + // 36
    'var'#13#10 + // 37
    '  AfterAsm: Integer;'#13#10 + // 38
    'initialization'#13#10 + // 39
    '  Tail := 1;'#13#10 + // 40
    '  AfterAsm := 2;'#13#10 + // 41
    'end.'#13#10, False);

  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  Assert.AreEqual(SortedFactKeys(['L:Outer.lCount@9', 'L:Outer.lRec@15', 'L:Inner.lInner@18',
    'L:Outer.lProc@23', 'R:lInner@20>Inner', 'R:lRec@20>Inner', 'R:Field@20>Inner',
    'R:lCount@20>Inner', 'R:lProc@25>Outer', 'R:lRec@27>Outer', 'R:Field@27>Outer',
    'R:lCount@27>Outer', 'R:Inner@29>Outer', 'R:Tail@40>',
    'R:AfterAsm@41>']), BodyFactsText(lModel, ['lCount', 'lRec', 'Field', 'lInner', 'lProc',
    'Inner', 'Tail', 'AfterAsm', 'aValue']));
end;

// DS-653/DS-657: names used by declarations are references wherever the declaration sits:
// absolute targets, address-of and constant initializers, array bounds, default values and
// the types of a class-method heading after an interface header. Declaring positions are not.
procedure TUnitModelTests.DeclarationExpressionsAreReferences;
var
  i: Integer;
  lFacts: string;
  lKey: string;
  lKeys: TStringList;
  lModel: TDelphiSemanticUnitModel;
  lReference: TDelphiSemanticReference;
begin
  lModel := ExtractUnitSource('declaration-references.pas',
    'unit DeclRefs;'#13#10 + // 1
    'interface'#13#10 + // 2
    'type'#13#10 + // 3
    '  TSizeKind = (skSmall, skLarge);'#13#10 + // 4
    '  TResultKind = Integer;'#13#10 + // 5
    'const'#13#10 + // 6
    '  MaxItems = 4;'#13#10 + // 7
    'procedure Api;'#13#10 + // 8
    'type'#13#10 + // 9
    '  TItem = class'#13#10 + // 10
    '    function Make(aSize: TSizeKind = skSmall): TResultKind;'#13#10 + // 11
    '  end;'#13#10 + // 12
    '  TItems = array[0..MaxItems] of TItem;'#13#10 + // 13
    'implementation'#13#10 + // 14
    'var'#13#10 + // 15
    '  GBase: Integer;'#13#10 + // 16
    '  GAlias: Integer absolute GBase;'#13#10 + // 17
    '  GPtr: PInteger = @GBase;'#13#10 + // 18
    'const'#13#10 + // 19
    '  CTwice = MaxItems * 2;'#13#10 + // 20
    'procedure Api;'#13#10 + // 21
    'begin'#13#10 + // 22
    'end;'#13#10 + // 23
    'function TItem.Make(aSize: TSizeKind): TResultKind;'#13#10 + // 24
    'begin'#13#10 + // 25
    '  Result := Ord(aSize) + CTwice;'#13#10 + // 26
    'end;'#13#10 + // 27
    'end.'#13#10, False);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);

  lKeys := TStringList.Create;
  try
    lKeys.Sorted := True;
    lKeys.Duplicates := dupAccept;
    for lReference in lModel.References do
      if MatchText(lReference.Name, ['GBase', 'MaxItems', 'TSizeKind', 'TResultKind', 'skSmall',
        'TItem']) then
        lKeys.Add(Format('%s@%d:%d', [lReference.Name, lReference.Line, lReference.Column]));
    lFacts := string.Join(' ', lKeys.ToStringArray);
    for lKey in ['GBase@17:28', 'GBase@18:21', 'MaxItems@13:21', 'MaxItems@20:12',
      'TSizeKind@11:26', 'skSmall@11:38', 'TResultKind@11:48', 'TItem@13:34'] do
      Assert.IsTrue(lKeys.IndexOf(lKey) >= 0, 'Missing ' + lKey + ' in ' + lFacts);
    // The enum type scan already records its values as type references (not this slice).
    for lKey in ['GBase@16:3', 'MaxItems@7:3', 'TItem@10:3'] do
      Assert.IsTrue(lKeys.IndexOf(lKey) < 0, 'A declaration is no reference: ' + lKey);
    for i := 1 to lKeys.Count - 1 do
      Assert.AreNotEqual(lKeys[i - 1], lKeys[i], 'Duplicate reference in ' + lFacts);
  finally
    lKeys.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TUnitModelTests);

end.
