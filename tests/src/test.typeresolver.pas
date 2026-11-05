unit Test.TypeResolver;

interface

uses
  DUnitX.TestFramework,
  DelphiSemantics.Model, DelphiSemantics.ProjectContext,
  DelphiSemantics.Resolve.TypeResolver, DelphiSemantics.SemanticGraph;

type
  [TestFixture]
  TTypeResolverTests = class
  private
    function Graph: TDelphiSemanticSemanticGraph;
    function ProjectInfo: TDelphiSemanticProjectInfo;
    function UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
  public
    [TestCase('own class', 'class-own')]
    [TestCase('ancestor class', 'class-ancestor')]
    [TestCase('earlier variable', 'declaration-order')]
    procedure DeclarationSitesKeepClassAndOrderIdentity(const aShape: string);
    [Category('Fast')]
    [Test]
    procedure ResolvesSimpleQualifiedAndVisibleTypeNames;
    [Category('Fast')]
    [Test]
    procedure PreservesDeclaredCanonicalAndUnderlyingAliasIdentities;
    [Category('Fast')]
    [Test]
    procedure ReportsAmbiguousSimpleNames;
    [Category('Fast')]
    [Test]
    procedure FindsAncestorTypeChain;
    [Category('Fast')]
    [Test]
    procedure ContextFreeLookupsExcludeRoutineLocalTypes;
    [Category('Fast')]
    [Test]
    procedure ScopedLookupSelectsNearestDeclarationAndRefusesBrokenChains;
    [Category('Fast')]
    [Test]
    procedure SourceBackedInterfaceBodyPairsPreserveScopedLocalIdentity;
    [Category('Fast')]
    [Test]
    procedure OpenArrayAndGenericHeadersKeepAstSignatureEvidence;
    [Category('Fast')]
    [Test]
    procedure HeaderBodyPairsIgnoreOnlyWhitespaceDifferences;
    [Category('Fast')]
    [TestCase('AThenB', 'TypeUnitA;TypeUnitB,TypeUnitB')]
    [TestCase('BThenA', 'TypeUnitB;TypeUnitA,TypeUnitA')]
    procedure OrderedVisibleNamesChooseLastUnit(const aImports, aExpectedUnit: string);
    [Category('Fast')]
    [Test]
    procedure UnknownLaterUnitMakesEarlierTypeUnproved;
    [Category('Fast')]
    [Test]
    procedure FailedIndexedLaterUnitMakesEarlierTypeUnproved;
    [Category('Fast')]
    [Test]
    procedure AncestorsStopAtUnindexedLaterImport;
    [Category('Fast')]
    [TestCase('AInterfaceBImplementation', '0')]
    [TestCase('BInterfaceAImplementation', '1')]
    procedure ImplementationImportsFollowInterfaceImports(const aReverse: Integer);
    [Category('Fast')]
    [Test]
    procedure UnknownActivityAppendsImportSentinel;
    [Category('Fast')]
    [TestCase('Body', 'body,True')]
    [TestCase('Declaration', 'declaration,True')]
    [TestCase('Clause', 'clause,False')]
    [TestCase('Section', 'section,False')]
    [TestCase('Include', 'include,False')]
    [TestCase('MissingImport', 'missing,False')]
    [TestCase('IncludedUses', 'included-uses,False')]
    [TestCase('IncludedLexicalUses', 'included-lexical,True')]
    [TestCase('RootLexicalUses', 'root-lexical,True')]
    [TestCase('UnresolvedClauseInclude', 'expanded-unresolved,False')]
    [TestCase('UnknownConditionalInclude', 'expanded-unknown,False')]
    [TestCase('ResolvedClauseInclude', 'expanded-known,True')]
    [TestCase('ResolvedNestedClauseInclude', 'expanded-nested,True')]
    [TestCase('ResolvedStandaloneUsesInclude', 'expanded-uses,True')]
    [TestCase('UsesIoSwitchBraces', 'switch-braces,True')]
    [TestCase('UsesIoSwitchParentheses', 'switch-parentheses,True')]
    procedure ImportActivityScope(const aShape: string; const aExpectedKnown: Boolean);
    [Category('Fast')]
    [Test]
    procedure ScopedImportSpellingCanonicalizes;
    [Category('Fast')]
    [Test]
    procedure AliasBeforeTargetUnitResolvesAfterRegistration;
    [Category('Fast')]
    [Test]
    procedure WitnessAbsenceAllowsEarlierCandidate;
    [Category('Fast')]
    [Test]
    procedure InactiveImportDoesNotShadow;
    [Category('Fast')]
    [Test]
    procedure LaterKnownAncestorWinsOverEarlierUnknownImport;
    [Category('Fast')]
    [Test]
    [TestCase('ImportedNoPosition', 'imported,resolved,,TypeUnitA')]
    [TestCase('OwnBefore', 'before,resolved,,SiteUnit')]
    [TestCase('OwnLater', 'later,resolved,,TypeUnitA')]
    [TestCase('OwnMissingPosition', 'position,unproved,position-unknown,')]
    [TestCase('OwnCrossFile', 'include,unproved,position-unknown,')]
    [TestCase('OwnTypeNamesUnknown', 'conditional,unproved,type-names-unknown,')]
    [TestCase('LaterUnknown', 'unknown,unproved,later-unknown-unit,')]
    [TestCase('UnknownWithoutCandidate', 'absent-unknown,unproved,witness-unknown,')]
    [TestCase('ImportsUnproved', 'imports,unproved,imports-unproved,')]
    [TestCase('ClosedAbsent', 'absent,unresolved,,')]
    [TestCase('P5OwnInterfaceWins', 'p5,resolved,,SiteUnit')]
    procedure SourceSiteTypeOutcomes(const aShape, aStatus, aCause, aUnit: string);
    [Category('Fast')]
    [Test]
    procedure NestedTypeOwnersHaveDistinctDeclaredIds;
    [Category('Fast')]
    [Test]
    [TestCase('OwnEarlier', 'own,resolved,,Values')]
    [TestCase('OwnLater', 'later,resolved,,Imported')]
    [TestCase('OwnPositionUnknown', 'position,unproved,position-unknown,')]
    [TestCase('OwnInclude', 'include,unproved,position-unknown,')]
    [TestCase('LaterUnknown', 'unknown,unproved,later-unknown-unit,')]
    [TestCase('EarlierUnknown', 'earlier-unknown,resolved,,Imported')]
    [TestCase('OwnUnknown', 'conditional,unproved,type-names-unknown,')]
    [TestCase('ClosedAbsent', 'absent,unresolved,,')]
    procedure ValueRootOutcomes(const aShape, aStatus, aCause, aUnit: string);

    [Category('Fast')]
    [Test]
    [TestCase('P1Ancestor', 'ancestor,resolved,,RuleUnit')]
    [TestCase('P1OpenRoot', 'open-root,unproved,class-root-open,')]
    [TestCase('NamedRootAbsence', 'root-provider,resolved,,Imported')]
    [TestCase('NamedRootWrongName', 'root-provider-miss,unproved,class-root-open,')]
    [TestCase('EnclosingNestedType', 'enclosing,resolved,,RuleUnit')]
    [TestCase('P1ImplicitRoot', 'implicit-root,resolved,,Imported')]
    [TestCase('P3SameSection', 'pointer-same,resolved,,RuleUnit')]
    [TestCase('P3NextSection', 'pointer-next,resolved,,Imported')]
    [TestCase('P3Directive', 'pointer-directive,unproved,position-unknown,')]
    [TestCase('P4EarlierParent', 'parent-before,resolved,,RuleUnit')]
    [TestCase('P4LaterParent', 'parent-later,resolved,,Imported')]
    [TestCase('TempBeforeLocalType', 'temp,resolved,,Imported')]
    [TestCase('BrokenCaller', 'broken,unproved,caller-scope-invalid,')]
    [TestCase('BrokenParentWithVisibleLocal', 'broken-parent,unproved,caller-scope-invalid,')]
    [TestCase('UnsupportedLocal', 'unsupported,unproved,unsupported-local,')]
    [TestCase('UnsupportedLaterParent', 'unsupported-later,resolved,,Imported')]
    [TestCase('QualifiedOwn', 'qualified-own,resolved,,RuleUnit')]
    [TestCase('QualifiedUsed', 'qualified-used,resolved,,Imported')]
    [TestCase('QualifiedDottedUnit', 'scoped-unit,resolved,,Scope.Imported')]
    [TestCase('QualifiedUnknown', 'qualified-unknown,unproved,external-unindexed,')]
    [TestCase('NestedQualified', 'nested,resolved,,RuleUnit')]
    [TestCase('SyntheticExcluded', 'synthetic,unresolved,,')]
    [TestCase('AmbiguousScope', 'ambiguous,ambiguous,,')]
    [TestCase('AliasConflict', 'alias-conflict,unproved,alias-conflict,')]
    procedure SourceScopeRules(const aShape, aStatus, aCause, aUnit: string);

    [Category('Fast')]
    [Test]
    [TestCase('BaseBeforeLaterHomonym', 'base')]
    [TestCase('AliasBeforeLaterHomonym', 'alias')]
    procedure InternalConsumersUseDeclaringSite(const aShape: string);
    [Category('Fast')]
    [Test]
    procedure RepeatedParameterHeadingHasOneValueIdentity;
    [Category('Fast')]
    [Test]
    procedure DifferentParameterTypesRemainAmbiguous;
    [Category('Fast')]
    [Test]
    procedure CompletedForwardPreservesEarlierVisibilityAndBodyEvidence;
    [Category('Fast')]
    [Test]
    [TestCase('AThenB', 'AB,resolved,HelperB')]
    [TestCase('BThenA', 'BA,resolved,HelperA')]
    [TestCase('LaterProjectUnknown', 'AU,unproved,')]
    [TestCase('EarlierProjectUnknown', 'UA,resolved,HelperA')]
    [TestCase('UnindexedOwnHelper', 'own-unindexed,unproved,')]
    [TestCase('UnindexedLaterOwnHelper', 'later-unindexed,resolved,HelperB')]
    [TestCase('MissingUnindexedFacts', 'missing-facts,unproved,')]
    procedure ActiveHelpersRespectImportOrder(const aOrder, aStatus, aUnit: string);

    [Category('Fast')]
    [Test]
    procedure DefaultResolutionFailsClosed;
    [Category('Fast')]
    [Test]
    [TestCase('Forward', 'False')]
    [TestCase('Reverse', 'True')]
    procedure HelperQueriesKeepExactFileImports(const aReverse: Boolean);
    [Category('Fast')]
    [TestCase('BodyOnly', 'body,True,False')]
    [TestCase('VariableOnly', 'variable,True,False')]
    // A-272: helper exports close independently; own conditional imports stay open.
    [TestCase('ConditionalUses', 'uses,True,True')]
    // A-273: an unrelated conditional alias does not export a helper.
    [TestCase('ConditionalType', 'type,True,False')]
    [TestCase('UnitScope', 'unit,False,True')]
    // A-274: helper-free source needs no body activity witness.
    [TestCase('MissingEvidence', 'missing,True,False')]
    procedure HelperScopeSeparatesBodyActivity(const aShape: string;
      const aHelperKnown, aOpen: Boolean);



    [Category('Fast')]
    [TestCase('WeakChain', 'weak,True')]
    [TestCase('StrongBoundary', 'strong,False')]
    procedure HelperMatchesWeakAliasTerminal(const aShape: string; const aMatches: Boolean);

    [Category('Fast')]
    [TestCase('ShortStringNotRecord', 'shortstring,absent')]
    [TestCase('RecordNotShortString', 'reverse,absent')]
    [TestCase('SameConstructedAlias', 'same,resolved')]
    [TestCase('DifferentConstructedAliases', 'different,unproved')]
    [TestCase('UnresolvedAlias', 'missing,unproved')]
    [TestCase('PointerHopHelper', 'pointer,resolved')]
    [TestCase('WeakPointerHopHelper', 'pointer-chain,resolved')]
    [TestCase('MissingPointee', 'pointer-missing,unproved')]
    [TestCase('PointerHelperTarget', 'pointer-target,unproved')]
    procedure HelperTargetKinds(const aShape, aExpected: string);

    [Category('Fast')]
    [TestCase('HelperFreeUnknownUses', 'uses,True')]
    [TestCase('InitOnlyConditional', 'init,True')]
    [TestCase('HelperInUnknownBranch', 'branch,False')]
    [TestCase('ConditionalInsideHelperBody', 'body,False')]
    [TestCase('UnresolvedInclude', 'missing-include,False')]
    [TestCase('IncludedHelper', 'included-helper,False')]
    [TestCase('ExternalDefineCaller', 'external,False')]
    [TestCase('CompleteConditionalHelper', 'complete,True')]
    [TestCase('PlainHelper', 'plain,True')]
    [TestCase('EscapedHelperPlain', 'escaped,True')]
    [TestCase('SameLineHelperPlain', 'same-line,True')]
    [TestCase('RawHelperIdentifier', 'identifier,False')]
    [TestCase('BranchHole', 'BranchHole,False')]
    [TestCase('Probe', 'Probe,False')]
    procedure HelperDeclarationEvidence(const aShape: string; const aKnown: Boolean);




    [Category('Fast')]
    [TestCase('Clean', 'clean,True')]
    [TestCase('Missing', 'missing,False')]
    [TestCase('TwoCandidates', 'two,False')]
    [TestCase('IncludePathOnly', 'include-path,True')]
    [TestCase('Helper', 'helper,False')]
    [TestCase('CommentHelper', 'comment,False')]
    [TestCase('StringHelper', 'string,False')]
    [TestCase('NestedClean', 'nested-clean,True')]
    [TestCase('NestedHelper', 'nested-helper,False')]
    [TestCase('NestedMissing', 'nested-missing,False')]
    [TestCase('Cycle', 'cycle,False')]
    [TestCase('Unreadable', 'unreadable,False')]
    procedure SkippedIncludeHelperEvidence(const aShape: string; const aKnown: Boolean);

    [Category('Fast')]
    [Test]
    procedure SkippedIncludeEditInvalidatesCache;

    [Category('Fast')]
    [TestCase('ImplicitClass', 'class,True,,System.TObject,False,1,-1')]
    [TestCase('ExplicitObject', 'object,True,,System.TObject,False,1,-1')]
    [TestCase('ImplicitInterface', 'interface,True,,System.IInterface,False,1,-1')]
    [TestCase('Record', 'record,True,,,False,1,-1')]
    [TestCase('IndexedRoot', 'indexed,True,,System.TObject,True,2,-1')]
    [TestCase('WeakChain', 'weak,True,,,False,3,-1')]
    [TestCase('StrongHop', 'strong,True,,,False,3,0')]
    [TestCase('UnresolvedBase', 'unresolved,False,unresolved-base,,False,1,-1')]
    [TestCase('UnprovedBase', 'unproved,False,unproved-base,,False,1,-1')]
    [TestCase('AliasUnresolved', 'alias,False,alias-unresolved,,False,1,-1')]
    [TestCase('Cycle', 'cycle,False,cycle,,False,2,-1')]
    procedure LineageKeepsCompletenessAndRoots(const aShape: string;
      const aComplete: Boolean; const aCause, aRoot: string; const aIndexed: Boolean;
      const aCount, aStrong: Integer);



  end;

implementation

uses
  System.Classes, System.IOUtils, System.StrUtils, System.SysUtils,
  AutoFree,
  DelphiSemantics.Cache, DelphiSemantics.Cache.Sqlite, DelphiSemantics.Model.Extract, DelphiSemantics.Model.Json,
  DelphiSemantics.Resolve.NameSites,
  DelphiSemantics.Resolve.UnitNameWitness, DelphiSemantics.RootMemberAbsence,
  DelphiSemantics.SourceConditionals,
  Test.Support;

type
  TExactNamedTypeAbsence = class(TInterfacedObject, IDelphiSemanticNamedRootMemberAbsence)
  public
    Name: string;
    function IsNamedRootMemberAbsent(const aRoot: TDelphiSemanticQualifiedRootType;
      const aSiteUnits: TArray<string>; const aName: string): Boolean;
  end;

function TExactNamedTypeAbsence.IsNamedRootMemberAbsent(const aRoot: TDelphiSemanticQualifiedRootType;
  const aSiteUnits: TArray<string>; const aName: string): Boolean;
begin
  Result := SameText(aRoot.Kind, 'class') and SameText(aRoot.TypeName, 'TExternal') and
    SameText(aName, Name) and (Length(aRoot.LookupUnits) = 1) and
    SameText(aRoot.LookupUnits[0], 'Imported') and (Length(aSiteUnits) = 1) and
    SameText(aSiteUnits[0], 'Imported');
end;

function TTypeResolverTests.Graph: TDelphiSemanticSemanticGraph;
begin
  Result := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [UnitModel('TypeUnitA'),
    UnitModel('TypeUnitB'), UnitModel('TypeUnitC')]);
end;

function TTypeResolverTests.ProjectInfo: TDelphiSemanticProjectInfo;
begin
  Result := Default(TDelphiSemanticProjectInfo);
  Result.ProjectName := 'TypeResolverProject';
  Result.ContextFingerprint := 'type-resolver-context';
end;

function TTypeResolverTests.UnitModel(const aUnitName: string): TDelphiSemanticUnitModel;
begin
  Result := Default(TDelphiSemanticUnitModel);
  Result.Success := True;
  Result.UnitName := aUnitName;
  Result.FileName := aUnitName + '.pas';
  // DS-719 2.7: hand-built AST fixtures must also prove import completeness.
  Result.ScopeModelStatus := 'ast';
  Result.DependencyFacts.Known := True;
  Result.SourceText := 'unit ' + aUnitName + '; interface implementation end.';
  if aUnitName = 'TypeUnitC' then
  begin
    Result.DependencyFacts.InterfaceImports := ['TypeUnitA'];
    Result.SourceText := 'unit TypeUnitC; interface uses TypeUnitA; implementation end.';
  end;


  if aUnitName = 'TypeUnitA' then
  begin
    SetLength(Result.Declarations, 5);
    Result.Declarations[0].Name := 'TBase';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'class';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
    Result.Declarations[1].Name := 'TChild';
    Result.Declarations[1].Kind := 'type';
    Result.Declarations[1].TypeName := 'class';
    Result.Declarations[1].BaseTypeName := 'TBase';
    Result.Declarations[1].SectionKind := 'interface';
    Result.Declarations[1].Line := 5;
    Result.Declarations[1].Column := 3;
    Result.Declarations[2].Name := 'TAlias';
    Result.Declarations[2].Kind := 'type-alias';
    Result.Declarations[2].TypeName := 'TChild';
    Result.Declarations[2].SectionKind := 'interface';
    Result.Declarations[2].Line := 6;
    Result.Declarations[2].Column := 3;
    Result.Declarations[3].Name := 'TShared';
    Result.Declarations[3].Kind := 'type';
    Result.Declarations[3].TypeName := 'record';
    Result.Declarations[3].SectionKind := 'interface';
    Result.Declarations[3].Line := 7;
    Result.Declarations[3].Column := 3;
    Result.Declarations[4].Name := 'TImplOnly';
    Result.Declarations[4].Kind := 'type';
    Result.Declarations[4].TypeName := 'record';
    Result.Declarations[4].SectionKind := 'implementation';
    Result.Declarations[4].Line := 20;
    Result.Declarations[4].Column := 3;
  end else if aUnitName = 'TypeUnitB' then
  begin
    SetLength(Result.Declarations, 1);
    Result.Declarations[0].Name := 'TShared';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'record';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
  end else
  begin
    SetLength(Result.Declarations, 2);
    Result.Declarations[0].Name := 'TExternalOnly';
    Result.Declarations[0].Kind := 'type';
    Result.Declarations[0].TypeName := 'record';
    Result.Declarations[0].SectionKind := 'interface';
    Result.Declarations[0].Line := 4;
    Result.Declarations[0].Column := 3;
    Result.Declarations[1].Name := 'TQualifiedAlias';
    Result.Declarations[1].Kind := 'type-alias';
    Result.Declarations[1].TypeName := 'TypeUnitA.TChild';
    Result.Declarations[1].SectionKind := 'interface';
    Result.Declarations[1].Line := 5;
    Result.Declarations[1].Column := 3;
  end;
end;

procedure TTypeResolverTests.FindsAncestorTypeChain;
var
  lAncestors: TArray<TDelphiSemanticTypeIdentity>;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TChild');
    Assert.IsTrue(lResult.Found, lResult.Reason);

    lAncestors := lIndex.FindAncestors(lResult.Identity);

    Assert.AreEqual(1, Integer(Length(lAncestors)));
    Assert.AreEqual('TBase', lAncestors[0].Name);

    lResult := lIndex.ResolveQualifiedName('TypeUnitC.TQualifiedAlias');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    lAncestors := lIndex.FindAncestors(lResult.Identity);

    Assert.AreEqual(2, Integer(Length(lAncestors)));
    Assert.AreEqual('TChild', lAncestors[0].Name);
    Assert.AreEqual('TBase', lAncestors[1].Name);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ContextFreeLookupsExcludeRoutineLocalTypes;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIdentity: TDelphiSemanticTypeIdentity;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticTypeLookupResult;
  lTypes: TArray<TDelphiSemanticGraphType>;
begin
  // This isolates legacy lookup behavior from the separate source extraction control.
  lModel := UnitModel('TypeUnitA');
  SetLength(lModel.Declarations, 6);
  lModel.Declarations[5].Name := 'TLocal';
  lModel.Declarations[5].Kind := 'type';
  lModel.Declarations[5].TypeName := 'record';
  lModel.Declarations[5].SectionKind := 'implementation';
  lModel.Declarations[5].ScopeKind := 'routine';
  lModel.Declarations[5].OwnerScopeId := 'typeunita|run()';
  lModel.Declarations[5].SymbolId := 'typeunita|run()|type|tlocal';
  lModel.Declarations[5].Line := 31;
  lModel.Declarations[5].Column := 3;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lTypes := lGraph.Types;
    Assert.AreEqual(6, Integer(Length(lTypes)));
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    Assert.IsTrue(lIndex.FindByDeclaredId(lTypes[5].DeclaredId, lIdentity),
      'An exact local ID stays addressable to contextual consumers.');
    Assert.AreEqual('TLocal', lIdentity.Name);
    lResult := lIndex.ResolveSimpleName('TLocal');
    Assert.IsFalse(lResult.Found, 'Unit-level simple lookup must exclude locals.');
    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TLocal');
    Assert.IsFalse(lResult.Found, 'Qualified unit lookup must exclude locals.');
    lResult := lIndex.ResolveVisibleName('TLocal', 'TypeUnitA', [], 'implementation');
    Assert.IsFalse(lResult.Found, 'Unit-visible lookup must exclude locals.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.SourceBackedInterfaceBodyPairsPreserveScopedLocalIdentity;
const
  cMalformedSignatures: array[0..2] of string = (
    '(aValue: string)',
    '(aValue: Integer; aOther: Integer)',
    '(var aValue: Integer)');
var
  lBodyCount: Integer;
  lDeclaration: TDelphiSemanticDeclaration;
  lGuid: TGUID;
  lGraph: TDelphiSemanticSemanticGraph;
  lGraphPairCount: Integer;
  lGraphRoutine: TDelphiSemanticGraphRoutine;
  lHeaderCount: Integer;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lInner: TDelphiSemanticRoutine;
  lInvalidGraph: TDelphiSemanticSemanticGraph;
  lInvalidIndex: TDelphiSemanticTypeIdentityIndex;
  lInvalidPairCount: Integer;
  lMalformedModel: TDelphiSemanticUnitModel;
  lMalformedSignature: string;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lOuterDeclaration: TDelphiSemanticDeclaration;
  lPath: string;
  lResult: TDelphiSemanticTypeLookupResult;
  lRoutine: TDelphiSemanticRoutine;
  lRunLocalBody, lRunLocalHeader: TDelphiSemanticRoutine;
  lRunNestedBody, lRunNestedHeader: TDelphiSemanticRoutine;
  lSource: string;
  lTypeCount: Integer;
begin
  CreateGUID(lGuid);
  lPath := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\type-resolver-scope-pair\' +
    GUIDToString(lGuid) + '\ScopedPairUnit.pas');
  TDirectory.CreateDirectory(ExtractFilePath(lPath));
  lSource := 'unit ScopedPairUnit;'#13#10 + // 1
    'interface'#13#10 + // 2
    'procedure RunLocal(aValue: Integer);'#13#10 + // 3
    'procedure RunNested(aValue: Integer);'#13#10 + // 4
    'implementation'#13#10 + // 5
    'procedure RunLocal(aValue: Integer);'#13#10 + // 6
    'type TLocal = record LocalOnly: Integer; end;'#13#10 + // 7
    'begin end;'#13#10 + // 8
    'procedure RunNested(aValue: Integer);'#13#10 + // 9
    'type TOuter = record OuterOnly: Integer; end;'#13#10 + // 10
    '  procedure Inner;'#13#10 + // 11
    '  begin end;'#13#10 + // 12
    'begin Inner; end;'#13#10 + // 13
    'end.'#13#10; // 14
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lModel := JsonToModel(ModelToJson(lModel));

  lBodyCount := 0;
  lHeaderCount := 0;
  lInner := Default(TDelphiSemanticRoutine);
  lRunLocalBody := Default(TDelphiSemanticRoutine);
  lRunLocalHeader := Default(TDelphiSemanticRoutine);
  lRunNestedBody := Default(TDelphiSemanticRoutine);
  lRunNestedHeader := Default(TDelphiSemanticRoutine);
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'RunLocal') or SameText(lRoutine.Name, 'RunNested') then
    begin
      Assert.IsNotEmpty(lRoutine.ScopeId, 'Both declarations need an AST scope.');
      if SameText(lRoutine.SectionKind, 'interface') then
      begin
        Inc(lHeaderCount);
        if SameText(lRoutine.Name, 'RunLocal') then
          lRunLocalHeader := lRoutine
        else
          lRunNestedHeader := lRoutine;
      end else if SameText(lRoutine.SectionKind, 'implementation') then
      begin
        Inc(lBodyCount);
        if SameText(lRoutine.Name, 'RunLocal') then
          lRunLocalBody := lRoutine
        else
          lRunNestedBody := lRoutine;
      end;
    end else if SameText(lRoutine.Name, 'Inner') then
      lInner := lRoutine;
  Assert.AreEqual(2, lHeaderCount);
  Assert.AreEqual(2, lBodyCount);
  Assert.AreEqual(3, lRunLocalHeader.Line);
  Assert.AreEqual(6, lRunLocalBody.Line);
  Assert.AreEqual(4, lRunNestedHeader.Line);
  Assert.AreEqual(9, lRunNestedBody.Line);
  Assert.AreEqual(lRunLocalHeader.Name, lRunLocalBody.Name);
  Assert.AreEqual(lRunNestedHeader.Name, lRunNestedBody.Name);
  Assert.AreEqual(lRunLocalHeader.Signature, lRunLocalBody.Signature);
  Assert.AreEqual(lRunNestedHeader.Signature, lRunNestedBody.Signature);
  Assert.IsNotEmpty(lRunNestedHeader.Signature);
  Assert.AreEqual(lRunLocalHeader.ScopeId, lRunLocalBody.ScopeId);
  Assert.AreEqual(lRunNestedHeader.ScopeId, lRunNestedBody.ScopeId);
  Assert.AreEqual(lRunLocalHeader.ParentScopeId, lRunLocalBody.ParentScopeId);
  Assert.AreEqual(lRunNestedHeader.ParentScopeId, lRunNestedBody.ParentScopeId);
  Assert.AreEqual('header', lRunLocalHeader.AstScopeKind);
  Assert.AreEqual('body', lRunLocalBody.AstScopeKind);
  Assert.AreEqual('header', lRunNestedHeader.AstScopeKind);
  Assert.AreEqual('body', lRunNestedBody.AstScopeKind);
  Assert.AreEqual('(integer)', lRunNestedHeader.AstSemanticSignature);
  Assert.AreEqual(lRunNestedHeader.AstSemanticSignature,
    lRunNestedBody.AstSemanticSignature);
  Assert.AreEqual(lRunNestedHeader.Signature,
    lRunNestedHeader.AstSourceSignature);
  Assert.AreEqual(lRunNestedBody.Signature,
    lRunNestedBody.AstSourceSignature);
  Assert.IsTrue(lRunNestedHeader.AstSourceSignatureVerified);
  Assert.IsTrue(lRunNestedBody.AstSourceSignatureVerified);
  Assert.AreNotEqual(lRunLocalBody.ScopeId, lRunNestedBody.ScopeId);
  Assert.AreEqual(11, lInner.Line);
  Assert.AreEqual(lRunNestedBody.ScopeId, lInner.ParentScopeId);

  lOuterDeclaration := Default(TDelphiSemanticDeclaration);
  lTypeCount := 0;
  for lDeclaration in lModel.Declarations do
    if SameText(lDeclaration.Name, 'TOuter') and SameText(lDeclaration.Kind, 'type') and
      SameText(lDeclaration.ScopeKind, 'routine') then
    begin
      Inc(lTypeCount);
      lOuterDeclaration := lDeclaration;
    end;
  Assert.AreEqual(1, lTypeCount, 'The source-backed local record must be present.');
  Assert.AreEqual(lRunNestedBody.ScopeId, lOuterDeclaration.OwnerScopeId);
  Assert.IsNotEmpty(lOuterDeclaration.SymbolId);
  Assert.AreEqual(10, lOuterDeclaration.Line);

  // A second implementation body is malformed even when its scope ID matches the real body.
  lMalformedModel := lModel;
  lMalformedModel.Routines := Copy(lModel.Routines);
  SetLength(lMalformedModel.Routines, Length(lMalformedModel.Routines) + 1);
  lMalformedModel.Routines[High(lMalformedModel.Routines)] := lRunNestedBody;
  lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
  try
    lInvalidPairCount := 0;
    for lGraphRoutine in lInvalidGraph.Routines do
      if SameText(lGraphRoutine.Name, 'RunNested') and
        SameText(lGraphRoutine.ScopeId, lRunNestedBody.ScopeId) then
        Inc(lInvalidPairCount);
    Assert.AreEqual(3, lInvalidPairCount, 'The malformed graph must retain both bodies.');
    lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
    lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsFalse(lResult.Found, 'A duplicate body cannot establish routine ownership.');
    Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
  finally
    lInvalidGraph.Free;
  end;

  // Old model JSON has no AST pair evidence. It must not make a body caller valid.
  lMalformedModel := lModel;
  lMalformedModel.Routines := Copy(lModel.Routines);
  for lBodyCount := 0 to High(lMalformedModel.Routines) do
    if SameText(lMalformedModel.Routines[lBodyCount].Name, 'RunNested') and
      SameText(lMalformedModel.Routines[lBodyCount].SectionKind, 'implementation') then
      lMalformedModel.Routines[lBodyCount].AstScopeKind := '';
  lMalformedModel := JsonToModel(ModelToJson(lMalformedModel));
  lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
  try
    lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
    lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsFalse(lResult.Found, 'Missing AST pair evidence cannot establish ownership.');
    Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
  finally
    lInvalidGraph.Free;
  end;

  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lGraphPairCount := 0;
    for lGraphRoutine in lGraph.Routines do
      if SameText(lGraphRoutine.Name, 'RunNested') and
        SameText(lGraphRoutine.ScopeId, lRunNestedBody.ScopeId) then
      begin
        Inc(lGraphPairCount);
        Assert.AreEqual(lPath, lGraphRoutine.SourceRange.FileName);
        Assert.IsTrue((lGraphRoutine.SourceRange.Line = 4) or
          (lGraphRoutine.SourceRange.Line = 9));
      end;
    Assert.AreEqual(2, lGraphPairCount, 'Graph lookup must retain the header and body.');
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual('routine', lResult.Identity.ScopeKind);
    Assert.AreEqual(lRunNestedBody.ScopeId, lResult.Identity.OwnerScopeId);
    Assert.AreEqual(lOuterDeclaration.SymbolId, lResult.Identity.SemanticSymbolId);
    Assert.AreEqual(lPath, lResult.Identity.SourceRange.FileName);
    lResult := lIndex.ResolveScopedName('TLocal', lModel.UnitName, lRunLocalBody.ScopeId,
      [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual(lRunLocalBody.ScopeId, lResult.Identity.OwnerScopeId);
  finally
    lGraph.Free;
  end;

  // A persisted lexical header cannot replace the AST parameter contract.
  for lMalformedSignature in cMalformedSignatures do
  begin
    lMalformedModel := lModel;
    lMalformedModel.Routines := Copy(lModel.Routines);
    for lBodyCount := 0 to High(lMalformedModel.Routines) do
      if SameText(lMalformedModel.Routines[lBodyCount].Name, 'RunNested') then
        lMalformedModel.Routines[lBodyCount].Signature := lMalformedSignature;
    lMalformedModel := JsonToModel(ModelToJson(lMalformedModel));
    lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
    try
      lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
      lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
        [], 'implementation');
      Assert.IsFalse(lResult.Found,
        'Conflicting lexical and AST signatures cannot establish routine ownership: ' +
        lMalformedSignature);
      Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
    finally
      lInvalidGraph.Free;
    end;
  end;

  // Missing or internally inconsistent AST evidence must also refuse old JSON rows.
  for lBodyCount := 0 to 2 do
  begin
    lMalformedModel := lModel;
    lMalformedModel.Routines := Copy(lModel.Routines);
    for lHeaderCount := 0 to High(lMalformedModel.Routines) do
      if SameText(lMalformedModel.Routines[lHeaderCount].Name, 'RunNested') then
        case lBodyCount of
          0: lMalformedModel.Routines[lHeaderCount].AstSemanticSignature := '';
          1: lMalformedModel.Routines[lHeaderCount].AstSourceSignatureVerified := False;
          2: lMalformedModel.Routines[lHeaderCount].AstSourceSignature :=
            '(aValue: string)';
        end;
    lMalformedModel := JsonToModel(ModelToJson(lMalformedModel));
    lInvalidGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lMalformedModel]);
    try
      lInvalidIndex := TDelphiSemanticTypeResolver.BuildIndex(lInvalidGraph);
      lResult := lInvalidIndex.ResolveScopedName('TOuter', lModel.UnitName,
        lInner.ScopeId, [], 'implementation');
      Assert.IsFalse(lResult.Found, 'Incomplete AST signature proof cannot establish ownership.');
      Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
    finally
      lInvalidGraph.Free;
    end;
  end;
end;

procedure TTypeResolverTests.HeaderBodyPairsIgnoreOnlyWhitespaceDifferences;
const
  // Each pair is (header, body) source text; only the first one differs by whitespace.
  cMismatches: array[0..3, 0..1] of string = (
    ('(aValue: Integer; aOther: Integer)', '(aValue: Integer; aOth er: Integer)'),
    ('(aValue: Integer; aOther: Integer)', '(aValue: Integer; aOther2: Integer)'),
    ('(aValue: Integer; aOther: Integer)', '(var aValue: Integer; aOther: Integer)'),
    ('(aValue: Integer; aOther: Integer)', '(aValue: Integer; aOther: Integer = 0)'));
var
  i: Integer;
  j: Integer;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lInner: TDelphiSemanticRoutine;
  lInvalidModel: TDelphiSemanticUnitModel;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lResult: TDelphiSemanticTypeLookupResult;
  lRoutine: TDelphiSemanticRoutine;
  lRunBody: TDelphiSemanticRoutine;
  lRunHeader: TDelphiSemanticRoutine;
  lSignature: string;
begin
  lPath := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\type-resolver-scope-pair\' +
    TPath.GetGUIDFileName + '\SpacedPairUnit.pas');
  TDirectory.CreateDirectory(ExtractFilePath(lPath));
  // Like maxTdb DBF2DAT and AppendLokalParameter: the body splits and spaces the
  // header's parameter list differently.
  TFile.WriteAllText(lPath,
    'unit SpacedPairUnit;'#13#10 +
    'interface'#13#10 +
    'function RunNested(aValue: Integer;aOther : Integer ):Integer;'#13#10 +
    'implementation'#13#10 +
    'function RunNested(aValue: Integer;'#13#10 +
    '  aOther: Integer): Integer;'#13#10 +
    'type TOuter = record OuterOnly: Integer; end;'#13#10 +
    '  procedure Inner;'#13#10 +
    '  begin end;'#13#10 +
    'begin Inner; Result := 0; end;'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lModel := JsonToModel(ModelToJson(lModel));
  lInner := Default(TDelphiSemanticRoutine);
  lRunBody := Default(TDelphiSemanticRoutine);
  lRunHeader := Default(TDelphiSemanticRoutine);
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'RunNested') and SameText(lRoutine.SectionKind, 'interface') then
      lRunHeader := lRoutine
    else if SameText(lRoutine.Name, 'RunNested') then
      lRunBody := lRoutine
    else if SameText(lRoutine.Name, 'Inner') then
      lInner := lRoutine;
  Assert.IsTrue(lRunHeader.AstSourceSignatureVerified and lRunBody.AstSourceSignatureVerified);
  Assert.AreNotEqual(lRunHeader.AstSourceSignature, lRunBody.AstSourceSignature,
    'The fixture must keep a whitespace-only difference.');
  Assert.AreEqual(lRunHeader.ScopeId, lRunBody.ScopeId);
  Assert.AreEqual(lRunBody.ScopeId, lInner.ParentScopeId);

  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
      [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual('routine', lResult.Identity.ScopeKind);
    Assert.AreEqual(lRunBody.ScopeId, lResult.Identity.OwnerScopeId);
  finally
    lGraph.Free;
  end;

  // A real difference in names, spelling, modifiers or defaults keeps the scope invalid.
  for i := Low(cMismatches) to High(cMismatches) do
  begin
    lInvalidModel := lModel;
    lInvalidModel.Routines := Copy(lModel.Routines);
    for j := 0 to High(lInvalidModel.Routines) do
      if SameText(lInvalidModel.Routines[j].Name, 'RunNested') then
      begin
        if SameText(lInvalidModel.Routines[j].SectionKind, 'interface') then
          lSignature := cMismatches[i, 0]
        else
          lSignature := cMismatches[i, 1];
        lInvalidModel.Routines[j].Signature := lSignature;
        lInvalidModel.Routines[j].AstSourceSignature := lSignature;
      end;
    lInvalidModel := JsonToModel(ModelToJson(lInvalidModel));
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lInvalidModel]);
    try
      lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
      lResult := lIndex.ResolveScopedName('TOuter', lModel.UnitName, lInner.ScopeId,
        [], 'implementation');
      Assert.IsFalse(lResult.Found, 'A real signature mismatch must stay invalid: ' +
        cMismatches[i, 1]);
      Assert.AreEqual('CALLER_SCOPE_INVALID', lResult.ReasonCode);
    finally
      lGraph.Free;
    end;
  end;
end;

procedure TTypeResolverTests.OpenArrayAndGenericHeadersKeepAstSignatureEvidence;
var
  lBody: TDelphiSemanticRoutine;
  lGenericBody: TDelphiSemanticRoutine;
  lGenericHeader: TDelphiSemanticRoutine;
  lGraph: TDelphiSemanticSemanticGraph;
  lGuid: TGUID;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lOpenBody: TDelphiSemanticRoutine;
  lOpenHeader: TDelphiSemanticRoutine;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lResult: TDelphiSemanticTypeLookupResult;
  lRoutine: TDelphiSemanticRoutine;
  lSource: string;
begin
  CreateGUID(lGuid);
  lPath := TPath.Combine(RepoRoot, 'tests\.dak\delphiSemanticsTests\type-resolver-scope-pair\' +
    GUIDToString(lGuid) + '\SignatureShapes.pas');
  TDirectory.CreateDirectory(ExtractFilePath(lPath));
  lSource := 'unit SignatureShapes;'#13#10 +
    'interface'#13#10 +
    'procedure OpenCase(aValues: array of Integer);'#13#10 +
    'procedure GenericCase(aValues: TArray<Integer>);'#13#10 +
    'implementation'#13#10 +
    'procedure OpenCase(aValues: array of Integer);'#13#10 +
    'type TOpenLocal = record Value: Integer; end;'#13#10 +
    'begin end;'#13#10 +
    'procedure GenericCase(aValues: TArray<Integer>);'#13#10 +
    'type TGenericLocal = record Value: Integer; end;'#13#10 +
    'begin end;'#13#10 +
    'end.'#13#10;
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := JsonToModel(ModelToJson(
    TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions)));
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lOpenHeader := Default(TDelphiSemanticRoutine);
  lOpenBody := Default(TDelphiSemanticRoutine);
  lGenericHeader := Default(TDelphiSemanticRoutine);
  lGenericBody := Default(TDelphiSemanticRoutine);
  for lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'OpenCase') then
    begin
      if SameText(lRoutine.SectionKind, 'interface') then
        lOpenHeader := lRoutine
      else if SameText(lRoutine.SectionKind, 'implementation') then
        lOpenBody := lRoutine;
    end else if SameText(lRoutine.Name, 'GenericCase') then
    begin
      if SameText(lRoutine.SectionKind, 'interface') then
        lGenericHeader := lRoutine
      else if SameText(lRoutine.SectionKind, 'implementation') then
        lGenericBody := lRoutine;
    end;
  Assert.IsTrue(TDelphiSemanticTypeResolver.VerifiedRoutineBody(lModel,
    lOpenHeader, lOpenBody, lBody), 'Open-array pair needs complete AST evidence.');
  Assert.AreEqual(lOpenBody.ScopeId, lBody.ScopeId);
  Assert.IsTrue(TDelphiSemanticTypeResolver.VerifiedRoutineBody(lModel,
    lGenericHeader, lGenericBody, lBody), 'Generic pair needs complete AST evidence.');
  Assert.AreEqual(lGenericBody.ScopeId, lBody.ScopeId);
  Assert.IsTrue(Pos('integer', lOpenBody.AstSemanticSignature) > 0);
  Assert.IsTrue(Pos('integer', lGenericBody.AstSemanticSignature) > 0);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveScopedName('TOpenLocal', lModel.UnitName,
      lOpenBody.ScopeId, [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual(lOpenBody.ScopeId, lResult.Identity.OwnerScopeId);
    lResult := lIndex.ResolveScopedName('TGenericLocal', lModel.UnitName,
      lGenericBody.ScopeId, [], 'implementation');
    Assert.IsTrue(lResult.Found, lResult.ReasonCode + ': ' + lResult.Reason);
    Assert.AreEqual(lGenericBody.ScopeId, lResult.Identity.OwnerScopeId);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ScopedLookupSelectsNearestDeclarationAndRefusesBrokenChains;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lOuter: TDelphiSemanticTypeLookupResult;
  lInner: TDelphiSemanticTypeLookupResult;
  lInnerPointer: TDelphiSemanticTypeLookupResult;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.Success := True;
  lModel.UnitName := 'ScopedUnit';
  lModel.FileName := 'ScopedUnit.pas';
  lModel.ScopeModelStatus := 'ast';
  SetLength(lModel.Routines, 4);
  lModel.Routines[0].Name := 'Outer';
  lModel.Routines[0].ScopeId := 'outer';
  lModel.Routines[0].Line := 10;
  lModel.Routines[0].EndLine := 28;
  lModel.Routines[0].Column := 1;
  lModel.Routines[1].Name := 'Inner';
  lModel.Routines[1].ScopeId := 'inner';
  lModel.Routines[1].ParentScopeId := 'outer';
  lModel.Routines[1].Line := 20;
  lModel.Routines[1].EndLine := 25;
  lModel.Routines[1].Column := 3;
  lModel.Routines[2].Name := 'Broken';
  lModel.Routines[2].ScopeId := 'broken';
  lModel.Routines[2].ParentScopeId := 'missing';
  lModel.Routines[2].Line := 30;
  lModel.Routines[2].EndLine := 33;
  lModel.Routines[2].Column := 1;
  lModel.Routines[3].Name := 'Cycle';
  lModel.Routines[3].ScopeId := 'cycle';
  lModel.Routines[3].ParentScopeId := 'cycle';
  lModel.Routines[3].Line := 35;
  lModel.Routines[3].EndLine := 39;
  lModel.Routines[3].Column := 1;
  SetLength(lModel.Declarations, 8);
  lModel.Declarations[0].Name := 'TItem';
  lModel.Declarations[0].Kind := 'type';
  lModel.Declarations[0].TypeName := 'record';
  lModel.Declarations[0].SectionKind := 'implementation';
  lModel.Declarations[0].ScopeKind := 'unit';
  lModel.Declarations[0].Line := 3;
  lModel.Declarations[0].Column := 3;
  lModel.Declarations[1] := lModel.Declarations[0];
  lModel.Declarations[1].ScopeKind := 'routine';
  lModel.Declarations[1].OwnerScopeId := 'outer';
  lModel.Declarations[1].SymbolId := 'outer|type|titem';
  lModel.Declarations[1].Line := 12;
  lModel.Declarations[2] := lModel.Declarations[1];
  lModel.Declarations[2].OwnerScopeId := 'inner';
  lModel.Declarations[2].SymbolId := 'inner|type|titem';
  lModel.Declarations[2].Line := 22;
  lModel.Declarations[3] := lModel.Declarations[1];
  lModel.Declarations[3].Name := 'TPtr';
  lModel.Declarations[3].Kind := 'type-alias';
  lModel.Declarations[3].TypeName := '^TItem';
  lModel.Declarations[3].SymbolId := 'outer|type-alias|tptr';
  lModel.Declarations[3].Line := 13;
  lModel.Declarations[4] := lModel.Declarations[3];
  lModel.Declarations[4].Name := 'TAlias';
  lModel.Declarations[4].TypeName := 'TItem';
  lModel.Declarations[4].SymbolId := 'outer|type-alias|talias';
  lModel.Declarations[4].Line := 14;
  lModel.Declarations[5] := lModel.Declarations[3];
  lModel.Declarations[5].OwnerScopeId := 'inner';
  lModel.Declarations[5].SymbolId := 'inner|type-alias|tptr';
  lModel.Declarations[5].Line := 23;
  lModel.Declarations[6] := lModel.Declarations[2];
  lModel.Declarations[6].Name := 'TUnsupported';
  lModel.Declarations[6].Kind := 'unsupported-local-type';
  lModel.Declarations[6].SymbolId := 'inner|unsupported|tunsupported';
  lModel.Declarations[6].Line := 24;
  lModel.Declarations[7] := lModel.Declarations[1];
  lModel.Declarations[7].OwnerScopeId := 'broken';
  lModel.Declarations[7].SymbolId := 'broken|type|titem';
  lModel.Declarations[7].Line := 32;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lInner := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsTrue(lInner.Found, lInner.Reason);
    Assert.AreEqual('inner', lInner.Identity.OwnerScopeId);
    lOuter := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'outer', [],
      'implementation');
    Assert.IsTrue(lOuter.Found, lOuter.Reason);
    Assert.AreEqual('outer', lOuter.Identity.OwnerScopeId);
    lResult := lIndex.ResolveScopedName('TAlias', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual(lOuter.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value,
      'An alias resolves its target at its declaration, not at the caller.');
    Assert.AreNotEqual(lInner.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value);
    lInnerPointer := lIndex.ResolveScopedName('TPtr', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsTrue(lInnerPointer.Found, lInnerPointer.Reason);
    Assert.AreEqual('inner', lInnerPointer.Identity.OwnerScopeId);
    lResult := lIndex.ResolveScopedName('TPtr', 'ScopedUnit', 'outer', [],
      'implementation');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreNotEqual(lInnerPointer.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value,
      'Pointer identity includes the declaration-scope pointee.');
    Assert.AreNotEqual(lInner.Identity.CanonicalId.Value,
      lResult.Identity.CanonicalId.Value);
    lResult := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'broken', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Incomplete parent chain cannot fall through to unit type.');
    lResult := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'unknown', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Unknown caller scope cannot see a unit homonym.');
    lResult := lIndex.ResolveScopedName('TItem', 'ScopedUnit', 'cycle', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Cyclic parent scope cannot fall back.');
    lResult := lIndex.ResolveScopedName('TUnsupported', 'ScopedUnit', 'inner', [],
      'implementation');
    Assert.IsFalse(lResult.Found, 'Unsupported nearest local type must stop lookup.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.PreservesDeclaredCanonicalAndUnderlyingAliasIdentities;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TAlias');

    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TAlias', lResult.Identity.Name);
    Assert.AreEqual('TChild', lResult.Identity.CanonicalName);
    Assert.AreEqual('class', lResult.Identity.UnderlyingName);
    Assert.AreEqual(lResult.Identity.UnderlyingName,
      lIndex.FindByUnderlyingId(lResult.Identity.UnderlyingId)[0].UnderlyingName);
    Assert.AreNotEqual(lResult.Identity.DeclaredId.Value,
      lResult.Identity.CanonicalId.Value);
    Assert.AreNotEqual(lResult.Identity.CanonicalId.Value,
      lResult.Identity.UnderlyingId.Value);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ReportsAmbiguousSimpleNames;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TShared');

    Assert.IsFalse(lResult.Found);
    Assert.IsTrue(lResult.Ambiguous);
    Assert.AreEqual('ambiguous', lResult.Status);
    Assert.AreEqual(2, Integer(Length(lResult.Candidates)));
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ResolvesSimpleQualifiedAndVisibleTypeNames;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);

    lResult := lIndex.ResolveSimpleName('TBase');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitA', lResult.Identity.UnitName);

    lResult := lIndex.ResolveQualifiedName('TypeUnitA.TChild');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TChild', lResult.Identity.Name);

    lResult := lIndex.ResolveVisibleName('TExternalOnly', 'TypeUnitA',
      ['TypeUnitA', 'TypeUnitC']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitC', lResult.Identity.UnitName);

    lResult := lIndex.ResolveVisibleName('TShared', 'TypeUnitA', ['TypeUnitA', 'TypeUnitB']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TypeUnitA', lResult.Identity.UnitName);

    lResult := lIndex.ResolveVisibleName('TImplOnly', 'TypeUnitA', [],
      'implementation');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('TImplOnly', lResult.Identity.Name);

    lResult := lIndex.ResolveVisibleName('TQualifiedAlias', 'TypeUnitA', ['TypeUnitC']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual('class', lResult.Identity.UnderlyingName);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.OrderedVisibleNamesChooseLastUnit(const aImports,
  aExpectedUnit: string);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveVisibleName('TShared', 'Consumer', aImports.Split([';']));
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual(aExpectedUnit, lResult.Identity.UnitName);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.UnknownLaterUnitMakesEarlierTypeUnproved;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lGraph := Graph;
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveVisibleName('TChild', 'Consumer', ['TypeUnitA', 'Unknown']);
    Assert.IsFalse(lResult.Found);
    Assert.IsFalse(lResult.Ambiguous);
    Assert.AreEqual('unproved', lResult.Status);
    Assert.AreEqual('TYPE_VISIBILITY_UNPROVED', lResult.ReasonCode);
    Assert.AreEqual(0, Integer(Length(lResult.Candidates)));
    lResult := lIndex.ResolveVisibleName('TChild', 'Consumer', ['Unknown', 'TypeUnitA']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
    lResult := lIndex.ResolveVisibleName('TChild', 'TypeUnitA', ['Unknown']);
    Assert.IsTrue(lResult.Found, lResult.Reason);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.FailedIndexedLaterUnitMakesEarlierTypeUnproved;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lModel := UnitModel('Broken');
  lModel.ScopeModelStatus := 'ast-failed';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [UnitModel('TypeUnitA'), lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveVisibleName('TChild', 'Consumer', ['TypeUnitA', 'Broken']);
    Assert.AreEqual('TYPE_VISIBILITY_UNPROVED', lResult.ReasonCode);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.AncestorsStopAtUnindexedLaterImport;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lModel := UnitModel('Consumer');
  lModel.ScopeModelStatus := 'ast';
  lModel.DependencyFacts.Known := True;
  lModel.DependencyFacts.InterfaceImports := ['TypeUnitA', 'Unknown'];
  lModel.Declarations := Copy(UnitModel('TypeUnitA').Declarations, 1, 1);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [UnitModel('TypeUnitA'), lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveQualifiedName('Consumer.TChild');
    Assert.IsTrue(lResult.Found, lResult.Reason);
    Assert.AreEqual(0, Integer(Length(lIndex.FindAncestors(lResult.Identity))),
      'An unproved base cannot borrow another unit''s TBase.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ImplementationImportsFollowInterfaceImports(const aReverse: Integer);
var
  g: TGarbos;
  lConsumer: TDelphiSemanticUnitModel;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lExpected, lFirst, lLast: string;
begin
  lFirst := 'TypeUnitA';
  lLast := 'TypeUnitB';
  if aReverse <> 0 then
  begin
    lFirst := 'TypeUnitB';
    lLast := 'TypeUnitA';
  end;
  lConsumer := UnitModel('Consumer');
  lConsumer.Declarations := nil;
  lConsumer.ScopeModelStatus := 'ast';
  lConsumer.DependencyFacts.Known := True;
  lConsumer.DependencyFacts.InterfaceImports := [lFirst];
  lConsumer.DependencyFacts.ImplementationImports := [lLast];
  lConsumer.SourceText := 'unit Consumer; interface uses ' + lFirst +
    '; implementation uses ' + lLast + '; end.';
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [UnitModel('TypeUnitA'), UnitModel('TypeUnitB'), lConsumer]), g);
  lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
  lExpected := lIndex.ResolveVisibleName('TShared', 'Consumer',
    lIndex.VisibleUnitNames('Consumer', 'interface'), 'interface').Identity.UnitName;
  Assert.AreEqual(lFirst, lExpected);
  lExpected := lIndex.ResolveVisibleName('TShared', 'Consumer',
    lIndex.VisibleUnitNames('Consumer', 'implementation'), 'implementation').Identity.UnitName;
  Assert.AreEqual(lLast, lExpected);
end;

procedure TTypeResolverTests.UnknownActivityAppendsImportSentinel;
var
  g: TGarbos;
  lConsumer: TDelphiSemanticUnitModel;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lImports: TArray<string>;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lConsumer := UnitModel('Consumer');
  lConsumer.Declarations := nil;
  lConsumer.ScopeModelStatus := 'ast';
  lConsumer.DependencyFacts.Known := True;
  lConsumer.DependencyFacts.InterfaceImports := ['TypeUnitA'];
  lConsumer.SourceText := 'x';
  lConsumer.VerifiedActiveSourceText := TDelphiSemanticSourceConditionals.UnavailableActivity + '?';
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [UnitModel('TypeUnitA'), lConsumer]), g);
  lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
  lImports := lIndex.VisibleUnitNames('Consumer', 'interface');
  Assert.AreEqual('<imports-unproved>', lImports[High(lImports)]);
  lResult := lIndex.ResolveVisibleName('TShared', 'Consumer', lImports, 'interface');
  Assert.AreEqual('TYPE_VISIBILITY_UNPROVED', lResult.ReasonCode);
end;

procedure TTypeResolverTests.ImportActivityScope(const aShape: string;
  const aExpectedKnown: Boolean);
var
  lConsumer: TDelphiSemanticUnitModel;
  lInterface, lImplementation: TArray<string>;
  lOffset: Integer;
  lRoot: string;
  lToken: string;
begin
  lConsumer := UnitModel('Consumer');
  lConsumer.ScopeModelStatus := 'ast';
  lConsumer.DependencyFacts.Known := True;
  lConsumer.DependencyFacts.InterfaceImports := ['TypeUnitA'];
  lConsumer.SourceText := 'unit Consumer; interface uses TypeUnitA; ' +
    'type TLocal = record Value: Integer; end; implementation begin end.';
  lToken := 'begin';
  if aShape = 'declaration' then
    lToken := 'TLocal'
  else if aShape = 'clause' then
    lToken := 'TypeUnitA'
  else if aShape = 'section' then
    lToken := 'interface'
  else if aShape = 'include' then
  begin
    lConsumer.SourceText := 'unit Consumer; interface uses {$I imports.inc} TypeUnitA; implementation end.';
    lToken := '{$I'
  end else if aShape = 'missing' then
    lConsumer.DependencyFacts.InterfaceImports := ['MissingUnit'];
  if aShape = 'switch-braces' then
    lConsumer.SourceText := 'unit Consumer; interface uses {$I-} TypeUnitA {$I+}; implementation end.'
  else if aShape = 'switch-parentheses' then
    lConsumer.SourceText := 'unit Consumer; interface uses (*$I-*) TypeUnitA (*$I+*); implementation end.';
  if StartsText('included-', aShape) then
  begin
    lRoot := CreateTestTempRoot('ds719-included-imports-temp');
    lConsumer.IncludeFileNames := [TPath.Combine(lRoot, 'imports.inc')];
    if aShape = 'included-uses' then
      TFile.WriteAllText(lConsumer.IncludeFileNames[0], 'uses OtherUnit;', TEncoding.ASCII)
    else
      TFile.WriteAllText(lConsumer.IncludeFileNames[0],
        '// uses OtherUnit;'#13#10'{uses CommentUnit;} (*uses MoreComments;*) ' +
        '''uses StringUnit;''', TEncoding.ASCII);
  end;
  if StartsText('expanded-', aShape) then
  begin
    lRoot := CreateTestTempRoot('ds719-expanded-imports-temp');
    lConsumer.SourceText := 'unit Consumer; interface uses TypeUnitA{$I imports.inc}; implementation end.';
    if aShape <> 'expanded-unresolved' then
    begin
      lConsumer.IncludeFileNames := [TPath.Combine(lRoot, 'imports.inc')];
      lConsumer.DependencyFacts.InterfaceImports := ['TypeUnitA', 'OtherUnit'];
      lToken := ', OtherUnit';
      if aShape = 'expanded-unknown' then
        lToken := '{$IFDEF UNICODE}, OtherUnit{$ENDIF}'
      else if aShape = 'expanded-nested' then
      begin
        lToken := '{$I nested.inc}';
        lConsumer.IncludeFileNames := lConsumer.IncludeFileNames + [TPath.Combine(lRoot, 'nested.inc')];
        TFile.WriteAllText(lConsumer.IncludeFileNames[1], ', OtherUnit', TEncoding.ASCII);
      end else if aShape = 'expanded-uses' then
      begin
        lConsumer.SourceText := 'unit Consumer; interface {$I imports.inc} implementation end.';
        lConsumer.DependencyFacts.InterfaceImports := ['OtherUnit'];
        lToken := 'uses OtherUnit;';
      end;
      TFile.WriteAllText(lConsumer.IncludeFileNames[0], lToken, TEncoding.ASCII);
    end;
  end;
  if aShape = 'root-lexical' then
    lConsumer.SourceText := lConsumer.SourceText +
      ' // uses CommentUnit;'#13#10'{uses MoreComments;} ''uses StringUnit;''';
  lConsumer.VerifiedActiveSourceText :=
    TDelphiSemanticSourceConditionals.UnavailableActivity +
    StringOfChar('A', Length(lConsumer.SourceText));
  if MatchText(aShape, ['body', 'declaration', 'clause', 'section', 'include']) then
  begin
    lOffset := Pos(lToken, lConsumer.SourceText);
    Assert.IsTrue(lOffset > 0);
    lConsumer.VerifiedActiveSourceText[
      Length(TDelphiSemanticSourceConditionals.UnavailableActivity) + lOffset] := '?';
  end;
  Assert.AreEqual(aExpectedKnown,
    TDelphiSemanticSemanticGraphBuilder.ProjectImports(ProjectInfo, lConsumer,
      [lConsumer], lInterface, lImplementation));
end;

procedure TTypeResolverTests.ScopedImportSpellingCanonicalizes;
var
  g: TGarbos;
  lConsumer, lScoped: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lImports: TArray<string>;
begin
  lProject := ProjectInfo;
  lProject.UnitScopeNames := ['Scope'];
  lScoped := UnitModel('TypeUnitB');
  lScoped.UnitName := 'Scope.Foo';
  lScoped.FileName := 'Scope.Foo.pas';
  lConsumer := UnitModel('Consumer');
  lConsumer.Declarations := nil;
  lConsumer.ScopeModelStatus := 'ast';
  lConsumer.DependencyFacts.Known := True;
  lConsumer.DependencyFacts.InterfaceImports := ['Foo'];
  lConsumer.SourceText := 'unit Consumer; interface uses Foo; implementation end.';
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lConsumer, lScoped]), g);
  lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
  lImports := lIndex.VisibleUnitNames('Consumer', 'interface');
  Assert.AreEqual('Scope.Foo', lImports[0]);
  Assert.AreEqual('Scope.Foo', lIndex.ResolveVisibleName('TShared', 'Consumer', lImports).Identity.UnitName);
end;

procedure TTypeResolverTests.AliasBeforeTargetUnitResolvesAfterRegistration;
var
  g: TGarbos;
  lAlias: TDelphiSemanticUnitModel;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
begin
  lAlias := UnitModel('TypeUnitA');
  lAlias.Declarations := Copy(lAlias.Declarations, 2, 1);
  lAlias.Declarations[0].TypeName := 'TShared';
  lAlias.ScopeModelStatus := 'ast';
  lAlias.DependencyFacts.Known := True;
  lAlias.DependencyFacts.InterfaceImports := ['TypeUnitB'];
  lAlias.SourceText := 'unit TypeUnitA; interface uses TypeUnitB; implementation end.';
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [lAlias, UnitModel('TypeUnitB')]), g);
  lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
  lResult := lIndex.ResolveQualifiedName('TypeUnitA.TAlias');
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('record', lResult.Identity.UnderlyingName);
end;

procedure TTypeResolverTests.WitnessAbsenceAllowsEarlierCandidate;
var
  g: TGarbos;
  lConsumer: TDelphiSemanticUnitModel;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
  lRoot: string;
begin
  // A4 permits absence only for a same-installation SDK pair.
  lRoot := TPath.Combine(CreateTestTempRoot('type-witness-temp'), 'sdk\source');
  TDirectory.CreateDirectory(lRoot);
  TDirectory.CreateDirectory(TPath.Combine(TPath.GetDirectoryName(lRoot), 'lib'));
  TFile.WriteAllText(TPath.Combine(TPath.GetDirectoryName(lRoot), 'lib\U.dcu'), 'SDK unit');
  TFile.WriteAllText(TPath.Combine(lRoot, 'U.pas'),
    'unit U; interface type TOther = Integer; implementation end.', TEncoding.ASCII);
  lProject := ProjectInfo;
  lProject.SearchPaths := [lRoot, TPath.Combine(TPath.GetDirectoryName(lRoot), 'lib')];
  lConsumer := UnitModel('Consumer');
  lConsumer.Declarations := nil;
  lConsumer.ScopeModelStatus := 'ast';
  lConsumer.DependencyFacts.Known := True;
  lConsumer.DependencyFacts.InterfaceImports := ['TypeUnitA', 'U'];
  lConsumer.SourceText := 'unit Consumer; interface uses TypeUnitA, U; implementation end.';
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(lProject,
    [UnitModel('TypeUnitA'), lConsumer]), g);
  lGraph.UnitNameWitness := TDelphiSemanticUnitNameWitnessBuilder.Build(lProject,
    [UnitModel('TypeUnitA'), lConsumer], lRoot);
  lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
  lResult := lIndex.ResolveVisibleName('TShared', 'Consumer',
    lIndex.VisibleUnitNames('Consumer', 'interface'));
  Assert.IsTrue(lResult.Found, lResult.Reason);
  Assert.AreEqual('TypeUnitA', lResult.Identity.UnitName);
end;

procedure TTypeResolverTests.InactiveImportDoesNotShadow;
var
  g: TGarbos;
  lOptions: TDelphiSemanticModelOptions;
  lConsumer: TDelphiSemanticUnitModel;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lRoot: string;
begin
  lRoot := CreateTestTempRoot('type-inactive-temp');
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'Consumer.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit Consumer; interface uses TypeUnitA {$IFDEF NEVER}, TypeUnitB {$ENDIF}; implementation end.',
    TEncoding.ASCII);
  lConsumer := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lConsumer.Success);
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [UnitModel('TypeUnitA'), UnitModel('TypeUnitB'), lConsumer]), g);
  lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
  Assert.AreEqual('TypeUnitA', lIndex.ResolveVisibleName('TShared', 'Consumer',
    lIndex.VisibleUnitNames('Consumer', 'interface')).Identity.UnitName);
end;

procedure TTypeResolverTests.LaterKnownAncestorWinsOverEarlierUnknownImport;
var
  g: TGarbos;
  lConsumer: TDelphiSemanticUnitModel;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeLookupResult;
  lAncestors: TArray<TDelphiSemanticTypeIdentity>;
begin
  lConsumer := UnitModel('Consumer');
  lConsumer.ScopeModelStatus := 'ast';
  lConsumer.DependencyFacts.Known := True;
  lConsumer.DependencyFacts.InterfaceImports := ['Unknown', 'TypeUnitA'];
  lConsumer.SourceText := 'unit Consumer; interface uses Unknown, TypeUnitA; implementation end.';
  lConsumer.Declarations := Copy(UnitModel('TypeUnitA').Declarations, 1, 1);
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [lConsumer, UnitModel('TypeUnitA')]), g);
  lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
  lResult := lIndex.ResolveQualifiedName('Consumer.TChild');
  lAncestors := lIndex.FindAncestors(lResult.Identity);
  Assert.AreEqual(1, Integer(Length(lAncestors)));
  Assert.AreEqual('TypeUnitA', lAncestors[0].UnitName);
end;

procedure TTypeResolverTests.SourceSiteTypeOutcomes(const aShape, aStatus, aCause,
  aUnit: string);
var
  lModel, lImported: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lWith: TDelphiSemanticWithStatement;
  lSite: TDelphiSemanticNameSite;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lGraph: TDelphiSemanticSemanticGraph;
  lResult: TDelphiSemanticTypeResolution;
begin
  lImported := UnitModel('TypeUnitA');
  lImported.ScopeModelStatus := 'ast';
  lImported.DependencyFacts.Known := True;
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.Success := True;
  lModel.ScopeModelStatus := 'ast';
  lModel.UnitName := 'SiteUnit';
  lModel.FileName := 'SiteUnit.pas';
  lModel.InterfaceUses := ['TypeUnitA'];
  lDeclaration := lImported.Declarations[0];
  lDeclaration.Name := 'TSite';
  lImported.Declarations := [lDeclaration];
  lDeclaration.ScopeKind := 'unit';
  lDeclaration.SectionKind := 'interface';
  lDeclaration.Line := 5;
  lDeclaration.Column := 3;
  if MatchText(aShape, ['before', 'later', 'position', 'include', 'p5']) then
    lModel.Declarations := [lDeclaration];
  lWith := Default(TDelphiSemanticWithStatement);
  lWith.Line := 10;
  lWith.Column := 3;
  if aShape = 'later' then
    lWith.Line := 4;
  if aShape = 'position' then
    lWith.Line := 0;
  if aShape = 'imported' then
    lWith.Line := 0; // No same-scope candidate: position is deliberately lazy.
  if aShape = 'include' then
    lModel.Declarations[0].FileName := 'other.inc';
  if aShape = 'conditional' then
  begin
    SetLength(lModel.Diagnostics, 1);
    lModel.Diagnostics[0].Code := 'UNVERIFIED_PREPROCESS_CONDITION';
  end;
  if aShape = 'unknown' then
    lModel.InterfaceUses := ['TypeUnitA', 'UnknownUnit'];
  if aShape = 'absent-unknown' then
    lModel.InterfaceUses := ['UnknownUnit'];
  if aShape = 'imports' then
    lModel.InterfaceUses := ['<imports-unproved>'];
  if aShape = 'absent' then
    lModel.InterfaceUses := [];
  if aShape = 'p5' then
    lModel.ImplementationUses := ['TypeUnitA'];
  lModel.SourceText := 'unit SiteUnit; interface uses ' +
    string.Join(', ', lModel.InterfaceUses) + '; implementation end.';
  if Length(lModel.InterfaceUses) = 0 then
    lModel.SourceText := 'unit SiteUnit; interface implementation end.';
  lModel.DependencyFacts.Known := True;
  lModel.DependencyFacts.InterfaceImports := Copy(lModel.InterfaceUses);
  lModel.DependencyFacts.ImplementationImports := Copy(lModel.ImplementationUses);
  lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lWith, '',
    Default(TDelphiSemanticGraphTypeId));
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lImported, lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveTypeAt(lSite, 'TSite');
    Assert.AreEqual(aStatus, lResult.AsLookupResult.Status, aShape + ': ' + lResult.Reason);
    Assert.AreEqual(aCause, lResult.Cause, aShape);
    Assert.AreEqual(aUnit, lResult.Identity.UnitName, aShape);
    if aStatus <> 'resolved' then
      Assert.IsEmpty(lResult.Identity.DeclaredId.Value, 'A refusal never carries an admitted identity.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.NestedTypeOwnersHaveDistinctDeclaredIds;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lGraph: TDelphiSemanticSemanticGraph;
  lFirst, lSecond: string;
  lPath: string;
  lCount: Integer;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-type-owners-temp'), 'OwnedTypes.pas');
  TFile.WriteAllText(lPath, 'unit OwnedTypes;'#13#10 +
    'interface'#13#10 +
    'type'#13#10 +
    '  TFirst = class'#13#10 +
    '  public'#13#10 +
    '    type TX = record FirstOnly: Integer; end;'#13#10 +
    '  end;'#13#10 +
    '  TSecond = class'#13#10 +
    '  public'#13#10 +
    '    type TX = record SecondOnly: Integer; end;'#13#10 +
    '  end;'#13#10 +
    'implementation'#13#10 +
    'end.'#13#10, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual('ast', lModel.ScopeModelStatus);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lCount := 0;
    for var lType in lGraph.Types do
      if SameText(lType.Name, 'TX') and SameText(lType.ScopeKind, 'type') then
      begin
        Inc(lCount);
        if lFirst = '' then
          lFirst := lType.DeclaredId.Value
        else
          lSecond := lType.DeclaredId.Value;
      end;
    Assert.AreEqual(2, lCount, 'Both independently owned nested declarations must reach the graph.');
    Assert.IsNotEmpty(lFirst);
    Assert.IsNotEmpty(lSecond);
    Assert.AreNotEqual(lFirst, lSecond, 'A nested type identity includes its declaring owner.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.SourceScopeRules(const aShape, aStatus, aCause, aUnit: string);
var
  lModel, lImported: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lProject: TDelphiSemanticProjectInfo;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticTypeResolution;
  lSite: TDelphiSemanticNameSite;
  lWith: TDelphiSemanticWithStatement;
  lSource, lSpelling, lRoutineId: string;
  lOwnerId: TDelphiSemanticGraphTypeId;
  lPath: string;
begin
  lSource := 'unit RuleUnit;'#13#10'interface'#13#10'uses Imported;'#13#10;
  if MatchText(aShape, ['ancestor', 'open-root', 'implicit-root', 'nested', 'root-provider', 'root-provider-miss', 'enclosing']) then
  begin
    if aShape = 'ancestor' then
      lSource := lSource + 'type TBase = class'#13#10'public'#13#10'  type TX = record Own: Integer; end;'#13#10'end;'#13#10 +
        'TChild = class(TBase) procedure Run; end;'#13#10
    else if MatchText(aShape, ['open-root', 'root-provider', 'root-provider-miss']) then
      lSource := lSource + 'type TChild = class(TExternal) procedure Run; end;'#13#10
    else if aShape = 'enclosing' then
      lSource := lSource + 'type TOuter = class'#13#10'public'#13#10 +
        '  type TX = record Own: Integer; end;'#13#10 +
        '  TChild = class procedure Run; end;'#13#10'end;'#13#10
    else if aShape = 'nested' then
      lSource := lSource + 'type TChild = class'#13#10'public'#13#10'  type TX = record Own: Integer; end;'#13#10'  procedure Run;'#13#10'end;'#13#10
    else
      lSource := lSource + 'type TChild = class procedure Run; end;'#13#10;
    lSource := lSource + 'implementation'#13#10'procedure TChild.Run;'#13#10'begin'#13#10'  with Value do Own := 1;'#13#10'end;'#13#10;
  end else if StartsText('pointer-', aShape) then
  begin
    lSource := lSource + 'type PTarget = ^TX;'#13#10;
    if aShape = 'pointer-next' then
      lSource := lSource + 'type'#13#10;
    if aShape = 'pointer-directive' then
      lSource := lSource + '{$IFDEF NEVER}'#13#10'{$ENDIF}'#13#10;
    lSource := lSource + 'TX = record Own: Integer; end;'#13#10'implementation'#13#10;
  end else if MatchText(aShape, ['parent-before', 'parent-later', 'temp', 'unsupported', 'unsupported-later', 'broken', 'broken-parent']) then
  begin
    lSource := lSource + 'implementation'#13#10'procedure Outer;'#13#10;
    if aShape = 'parent-before' then
      lSource := lSource + 'type TX = record Own: Integer; end;'#13#10;
    if aShape = 'unsupported' then
      lSource := lSource + 'type TX = array of Integer;'#13#10;
    lSource := lSource + '  procedure Inner;'#13#10;
    if aShape = 'broken-parent' then
      lSource := lSource + '  type TX = record Own: Integer; end;'#13#10;
    lSource := lSource + '  begin'#13#10'    with Value do Own := 1;'#13#10'  end;'#13#10;
    if aShape = 'unsupported-later' then
      lSource := lSource + 'type TX = array of Integer;'#13#10;
    if MatchText(aShape, ['parent-later', 'temp']) then
      lSource := lSource + 'type TX = record Own: Integer; end;'#13#10;
    lSource := lSource + 'begin Inner; end;'#13#10;
  end else
    lSource := lSource + 'type TX = record Own: Integer; end;'#13#10'implementation'#13#10;
  lSource := lSource + 'end.'#13#10;
  if aShape = 'scoped-unit' then
    lSource := lSource.Replace('uses Imported;', 'uses Scope.Imported;');
  if aShape = 'qualified-unknown' then
    lSource := lSource.Replace('uses Imported;', 'uses Missing;');
  if aShape = 'alias-conflict' then
    lSource := lSource.Replace('uses Imported;', 'uses Alias;');
  lPath := TPath.Combine(CreateTestTempRoot('ds719-rules-temp'), 'RuleUnit.pas');
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, aShape);
  Assert.AreEqual('ast', lModel.ScopeModelStatus, aShape);
  if MatchText(aShape, ['ancestor', 'nested']) then
  begin
    var lHasNested := False;
    for var lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.Name, 'TX') and SameText(lDeclaration.ScopeKind, 'type') then
        lHasNested := True;
    Assert.IsTrue(lHasNested, 'The class-scope probe must contain its nested TX fact.');
  end;
  if aShape = 'unsupported-later' then
  begin
    // The extractor omits declarations after a nested routine. Exercise the
    // index contract with the retained source token and explicit owning scope.
    var lUnsupported := Default(TDelphiSemanticDeclaration);
    lUnsupported.Name := 'TX';
    lUnsupported.Kind := 'unsupported-local-type';
    lUnsupported.TypeName := 'array of Integer';
    lUnsupported.ScopeKind := 'routine';
    lUnsupported.SectionKind := 'implementation';
    lUnsupported.FileName := lPath;
    var lLines := lSource.Split([#10]);
    for var i := 0 to High(lLines) do
      if StartsText('type TX = array', lLines[i]) then
        lUnsupported.Line := i + 1;
    Assert.IsTrue(lUnsupported.Line > 0);
    lUnsupported.Column := 6;
    for var lRoutine in lModel.Routines do
      if SameText(lRoutine.Name, 'Outer') then
        lUnsupported.OwnerScopeId := lRoutine.ScopeId;
    Assert.IsNotEmpty(lUnsupported.OwnerScopeId);
    lModel.Declarations := lModel.Declarations + [lUnsupported];
  end;
  if MatchText(aShape, ['unsupported', 'unsupported-later']) then
  begin
    var lHasUnsupported := False;
    for var lDeclaration in lModel.Declarations do
      if SameText(lDeclaration.Name, 'TX') and
        SameText(lDeclaration.Kind, 'unsupported-local-type') then
        lHasUnsupported := True;
    Assert.IsTrue(lHasUnsupported, 'The unsupported-local probe must contain its barrier fact.');
  end;
  lImported := UnitModel('TypeUnitA');
  lImported.UnitName := 'Imported';
  if aShape = 'scoped-unit' then
    lImported.UnitName := 'Scope.Imported';
  lImported.ScopeModelStatus := 'ast';
  lImported.DependencyFacts.Known := True;
  lImported.Declarations := Copy(lImported.Declarations, 0, 1);
  lImported.Declarations[0].Name := 'TX';
  lProject := ProjectInfo;
  if aShape = 'alias-conflict' then
  begin
    lProject.UnitAliases := ['Alias=Imported', 'Alias=Other'];
    lModel.Declarations := [];
    lModel.DependencyFacts.InterfaceImports := ['Alias'];
    lModel.InterfaceUses := ['Alias'];
  end;
  if aShape = 'qualified-unknown' then
  begin
    lModel.DependencyFacts.InterfaceImports := ['Missing'];
    lModel.InterfaceUses := ['Missing'];
  end;
  if aShape = 'synthetic' then
  begin
    lModel.Declarations[0].Name := 'TX.Sub';
    lModel.DependencyFacts.InterfaceImports := [];
    lModel.InterfaceUses := [];
  end;
  if aShape = 'ambiguous' then
  begin
    lModel.Declarations := lModel.Declarations + [lModel.Declarations[0]];
    lModel.Declarations[1].Line := lModel.Declarations[0].Line + 1;
    lModel.Declarations[1].SymbolId := 'independent-duplicate';
  end;
  if aShape = 'broken-parent' then
    for var i := 0 to High(lModel.Routines) do
      if SameText(lModel.Routines[i].Name, 'Inner') then
        lModel.Routines[i].ParentScopeId := 'missing-parent';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(lProject, [lModel, lImported]);
  try
    if MatchText(aShape, ['root-provider', 'root-provider-miss']) then
    begin
      var lProvider := TExactNamedTypeAbsence.Create;
      lProvider.Name := 'TX';
      if aShape = 'root-provider-miss' then
        lProvider.Name := 'DifferentName';
      lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph, lProvider);
    end else
      lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lOwnerId := Default(TDelphiSemanticGraphTypeId);
    for var lType in lGraph.Types do
      if SameText(lType.Name, 'TChild') then
        lOwnerId := lType.DeclaredId;
    lWith := Default(TDelphiSemanticWithStatement);
    lWith.Line := 100;
    lWith.Column := 1;
    if Length(lModel.WithStatements) > 0 then
      lWith := lModel.WithStatements[0];
    lRoutineId := '';
    for var lRoutine in lModel.Routines do
      if SameText(lRoutine.Name, 'Inner') then
        lRoutineId := lRoutine.ScopeId;
    lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lWith, lRoutineId, lOwnerId);
    lSpelling := 'TX';
    if StartsText('pointer-', aShape) then
    begin
      lSite := TDelphiSemanticNameSites.AtDeclaration(lModel, lModel.Declarations[0],
        Default(TDelphiSemanticGraphTypeId));
      lSite.ForwardPointerTarget := True;
    end;
    if aShape = 'broken' then
      lSite.RoutineScopeId := 'missing';
    if aShape = 'temp' then
      lSite.LocalCutoffLine := 5;
    if aShape = 'qualified-own' then
      lSpelling := 'RuleUnit.TX';
    if aShape = 'qualified-used' then
      lSpelling := 'Imported.TX';
    if aShape = 'scoped-unit' then
      lSpelling := 'Scope.Imported.TX';
    if aShape = 'qualified-unknown' then
      lSpelling := 'Missing.TX';
    if aShape = 'nested' then
    begin
      lSite.ClassScopeId := Default(TDelphiSemanticGraphTypeId);
      lSpelling := 'TChild.TX';
    end;
    if aShape = 'synthetic' then
    begin
      lSpelling := 'RuleUnit.TX.Sub';
      var lVerifiedSynthetic := False;
      for var lType in lGraph.Types do
        if SameText(lType.Name, 'TX.Sub') then
        begin
          var lIdentity: TDelphiSemanticTypeIdentity;
          Assert.IsTrue(lIndex.FindByDeclaredId(lType.DeclaredId, lIdentity));
          lVerifiedSynthetic := lIdentity.Synthetic;
        end;
      Assert.IsTrue(lVerifiedSynthetic, 'Synthetic identity remains reachable by its held declaration ID.');
    end;
    lResult := lIndex.ResolveTypeAt(lSite, lSpelling);
    Assert.AreEqual(aStatus, lResult.AsLookupResult.Status, aShape + ': ' + lResult.Reason);
    Assert.AreEqual(aCause, lResult.Cause, aShape);
    Assert.AreEqual(aUnit, lResult.Identity.UnitName, aShape);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ValueRootOutcomes(const aShape, aStatus, aCause, aUnit: string);
var
  lModel, lImported: TDelphiSemanticUnitModel;
  lDeclaration: TDelphiSemanticDeclaration;
  lSite: TDelphiSemanticNameSite;
  lWith: TDelphiSemanticWithStatement;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lResult: TDelphiSemanticValueResolution;
begin
  lModel := Default(TDelphiSemanticUnitModel);
  lModel.Success := True;
  lModel.ScopeModelStatus := 'ast';
  lModel.UnitName := 'Values';
  lModel.FileName := 'Values.pas';
  lModel.DependencyFacts.Known := True;
  lModel.DependencyFacts.InterfaceImports := ['Imported'];
  lDeclaration := Default(TDelphiSemanticDeclaration);
  lDeclaration.Name := 'Value';
  lDeclaration.Kind := 'var';
  lDeclaration.TypeName := 'TRecord';
  lDeclaration.SectionKind := 'interface';
  lDeclaration.ScopeKind := 'unit';
  lDeclaration.Line := 5;
  lDeclaration.Column := 5;
  lImported := lModel;
  lImported.UnitName := 'Imported';
  lImported.FileName := 'Imported.pas';
  lImported.DependencyFacts.InterfaceImports := [];
  lImported.SourceText := 'unit Imported; interface implementation end.';
  lImported.Declarations := [lDeclaration];
  if MatchText(aShape, ['own', 'later', 'position', 'include']) then
    lModel.Declarations := [lDeclaration];
  if aShape = 'later' then
    lModel.Declarations[0].Line := 15;
  if aShape = 'include' then
    lModel.Declarations[0].FileName := 'value.inc';
  if aShape = 'unknown' then
    lModel.DependencyFacts.InterfaceImports := ['Imported', 'UnknownUnit'];
  if aShape = 'earlier-unknown' then
    lModel.DependencyFacts.InterfaceImports := ['UnknownUnit', 'Imported'];
  if aShape = 'conditional' then
  begin
    SetLength(lModel.Diagnostics, 1);
    lModel.Diagnostics[0].Code := 'UNSUPPORTED_PREPROCESS_DIRECTIVE';
  end;
  if aShape = 'absent' then
    lModel.DependencyFacts.InterfaceImports := [];
  lModel.SourceText := 'unit Values; interface uses ' +
    string.Join(', ', lModel.DependencyFacts.InterfaceImports) + '; implementation end.';
  if aShape = 'absent' then
    lModel.SourceText := 'unit Values; interface implementation end.';
  lWith := Default(TDelphiSemanticWithStatement);
  lWith.Line := 10;
  lWith.Column := 1;
  if aShape = 'position' then
    lWith.Line := 0;
  lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lWith, '',
    Default(TDelphiSemanticGraphTypeId));
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel, lImported]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lResult := lIndex.ResolveValueRootAt(lSite, 'Value');
    var lStatus := '';
    case lResult.Outcome of
      noResolved: lStatus := 'resolved';
      noUnproved: lStatus := 'unproved';
      noAmbiguous: lStatus := 'ambiguous';
      noAbsent: lStatus := 'unresolved';
    end;
    Assert.AreEqual(aStatus, lStatus, lResult.Reason);
    Assert.AreEqual(aCause, lResult.Cause, aShape);
    Assert.AreEqual(aUnit, lResult.UnitName, aShape);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.InternalConsumersUseDeclaringSite(const aShape: string);
var
  lModel, lImported: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lIdentity: TDelphiSemanticTypeIdentity;
  lPath, lSource: string;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-internal-temp'), 'Internal.pas');
  lSource := 'unit Internal;'#13#10'interface'#13#10'uses Imported;'#13#10;
  if aShape = 'base' then
    lSource := lSource + 'type TChild = class(TX) end;'#13#10
  else
    lSource := lSource + 'type TChild = TX;'#13#10;
  lSource := lSource + 'type TX = class end;'#13#10'implementation'#13#10'end.'#13#10;
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lImported := UnitModel('TypeUnitA');
  lImported.UnitName := 'Imported';
  lImported.ScopeModelStatus := 'ast';
  lImported.DependencyFacts.Known := True;
  lImported.Declarations := Copy(lImported.Declarations, 0, 1);
  lImported.Declarations[0].Name := 'TX';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel, lImported]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    for var lType in lGraph.Types do
      if SameText(lType.Name, 'TChild') then
        Assert.IsTrue(lIndex.FindByDeclaredId(lType.DeclaredId, lIdentity));
    var lAncestors := lIndex.FindAncestors(lIdentity);
    Assert.AreEqual(1, Integer(Length(lAncestors)));
    Assert.AreEqual('Imported', lAncestors[0].UnitName,
      'The base/alias spelling precedes own-unit TX and must bind the imported declaration.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.ActiveHelpersRespectImportOrder(const aOrder, aStatus, aUnit: string);
begin
  var lTarget := UnitModel('TypeUnitA');
  lTarget.UnitName := 'Target';
  lTarget.ScopeModelStatus := 'ast';
  lTarget.DependencyFacts.Known := True;
  lTarget.Declarations := Copy(lTarget.Declarations, 0, 1);
  lTarget.Declarations[0].Name := 'TX';
  lTarget.Declarations[0].TypeName := 'record';
  var lHelperA := lTarget;
  lHelperA.Declarations := Copy(lTarget.Declarations);
  lHelperA.UnitName := 'HelperA';
  lHelperA.DependencyFacts.InterfaceImports := ['Target'];
  lHelperA.Declarations[0].Name := 'THelperA';
  lHelperA.Declarations[0].TypeName := 'record helper';
  lHelperA.Declarations[0].HelperTargetName := 'TX';
  var lHelperB := lHelperA;
  lHelperB.Declarations := Copy(lHelperA.Declarations);
  lHelperB.UnitName := 'HelperB';
  lHelperB.Declarations[0].Name := 'THelperB';
  var lConsumer := lTarget;
  lConsumer.UnitName := 'Consumer';
  lConsumer.Declarations := [];
  lConsumer.DependencyFacts.InterfaceImports := ['Target', 'HelperA', 'HelperB'];
  if aOrder = 'BA' then
    lConsumer.DependencyFacts.InterfaceImports := ['Target', 'HelperB', 'HelperA']
  else if aOrder = 'AU' then
    lConsumer.DependencyFacts.InterfaceImports := ['Target', 'HelperA', 'Unknown']
  else if aOrder = 'UA' then
    lConsumer.DependencyFacts.InterfaceImports := ['Target', 'Unknown', 'HelperA'];
  if MatchText(aOrder, ['own-unindexed', 'later-unindexed']) then
  begin
    var lHelper := Default(TDelphiSemanticUnindexedHelperFact);
    lHelper.Name := 'TUnsupportedHelper';
    lHelper.HelperKind := 'record';
    lHelper.TargetName := 'TX';
    lHelper.ScopeKind := 'unit';
    lHelper.SectionKind := 'implementation';
    lHelper.FileName := lConsumer.FileName;
    lHelper.Line := 10;
    lHelper.Column := 6;
    if aOrder = 'later-unindexed' then
      lHelper.Line := 200;
    lConsumer.UnindexedHelpers := [lHelper];
  end;
  if aOrder = 'missing-facts' then
  begin
    var lDiagnostic := Default(TDelphiSemanticModelDiagnostic);
    lDiagnostic.Code := 'AST_HELPER_DECLARATION_UNINDEXED';
    lConsumer.Diagnostics := [lDiagnostic];
  end;
  lTarget.SourceText := 'unit Target; interface implementation end.';
  lHelperA.SourceText := 'unit HelperA; interface uses Target; implementation end.';
  lHelperB.SourceText := 'unit HelperB; interface uses Target; implementation end.';
  lConsumer.SourceText := 'unit Consumer; interface uses ' +
    string.Join(', ', lConsumer.DependencyFacts.InterfaceImports) + '; implementation end.';
  var lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
    [lTarget, lHelperA, lHelperB, lConsumer]);
  try
    var lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    var lTargetId := Default(TDelphiSemanticGraphTypeId);
    for var lType in lGraph.Types do
      if SameText(lType.Name, 'TX') then
        lTargetId := lType.DeclaredId;
    Assert.IsNotEmpty(lTargetId.Value);
    var lWith := Default(TDelphiSemanticWithStatement);
    lWith.Line := 100;
    lWith.Column := 1;
    var lSite := TDelphiSemanticNameSites.AtWithStatement(lConsumer, lWith, '',
      Default(TDelphiSemanticGraphTypeId));
    var lResult := lIndex.ResolveActiveHelperAt(lTargetId, lSite);
    Assert.AreEqual(aStatus, lResult.AsLookupResult.Status, lResult.Reason);
    Assert.AreEqual(aUnit, lResult.Identity.UnitName);
    if aStatus = 'unproved' then
      Assert.AreEqual('helper-unknown', lResult.Cause);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.HelperScopeSeparatesBodyActivity(const aShape: string;
  const aHelperKnown, aOpen: Boolean);
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lSource: string;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lLineage: TDelphiSemanticLineage;
  lResult: TDelphiSemanticHelperResolution;
  lSite: TDelphiSemanticNameSite;
  lWith: TDelphiSemanticWithStatement;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-helper-activity-temp'), 'HelperActivity.pas');
  lSource := 'unit HelperActivity;'#13#10'interface'#13#10;
  if aShape = 'uses' then
    lSource := lSource + '{$IF UseFast} uses HelperProvider; {$IFEND}'#13#10;
  lSource := lSource + 'type TRec = record X: Integer; end;'#13#10;
  if aShape = 'variable' then
    lSource := lSource + '{$IF UseFast} var Count: Integer; {$IFEND}'#13#10;
  if aShape = 'type' then
    lSource := lSource + '{$IF UseFast} type TAlias = TRec; {$IFEND}'#13#10;
  if aShape = 'unit' then
    lSource := lSource + '{$IF UseFast}'#13#10 +
      'type THelp = record helper for TRec procedure M; end;'#13#10'{$IFEND}'#13#10;
  lSource := lSource + 'implementation'#13#10'procedure Run;'#13#10'begin'#13#10;
  if MatchText(aShape, ['body', 'missing']) then
    lSource := lSource + '{$IF UseFast} WriteLn(1); {$IFEND}'#13#10;
  lSource := lSource + 'end;'#13#10'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.IsTrue(Length(lModel.Diagnostics) > 0, 'The conditional must actually be unverified.');
  if aShape = 'missing' then
    lModel.VerifiedActiveSourceText := '';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    Assert.IsFalse(lGraph.Units[0].TypeNamesKnown,
      'Body uncertainty remains visible to existing type-name consumers.');
    Assert.AreEqual(aHelperKnown, lGraph.Units[0].HelperScopeKnown,
      'Helper exports are independent of unrelated conditional activity.');
    Assert.AreEqual(aShape <> 'uses', lGraph.Units[0].ImportsKnown,
      'Helper export proof must not clear conditional imports.');
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lLineage := lIndex.ResolveLineage(lIndex.ResolveQualifiedName('HelperActivity.TRec').Identity);
    Assert.IsTrue(lLineage.Complete);
    lWith := Default(TDelphiSemanticWithStatement);
    lWith.Line := 100;
    lWith.Column := 1;
    lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lWith, '',
      Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveHelpersAt(lLineage, lSite);
    Assert.AreEqual(aOpen, lResult.OpenFromLevel = 0,
      'Only variable/body uncertainty may leave helper levels closed.');
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.HelperQueriesKeepExactFileImports(const aReverse: Boolean);
var
  lTarget, lHelper, lFirst, lSecond: TDelphiSemanticUnitModel;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lLineage: TDelphiSemanticLineage;
  lSite: TDelphiSemanticNameSite;
  lWith: TDelphiSemanticWithStatement;
  lResult: TDelphiSemanticHelperResolution;
begin
  lTarget := UnitModel('TypeUnitA');
  lTarget.UnitName := 'Target';
  lTarget.FileName := 'Target.pas';
  lTarget.ScopeModelStatus := 'ast';
  lTarget.DependencyFacts.Known := True;
  lTarget.Declarations := Copy(lTarget.Declarations, 0, 1);
  lTarget.Declarations[0].Name := 'TX';
  lTarget.Declarations[0].TypeName := 'record';
  lTarget.SourceText := 'unit Target; interface implementation end.';
  lHelper := lTarget;
  lHelper.UnitName := 'HelperA';
  lHelper.FileName := 'HelperA.pas';
  lHelper.DependencyFacts.InterfaceImports := ['Target'];
  lHelper.Declarations := Copy(lTarget.Declarations);
  lHelper.Declarations[0].Name := 'THelper';
  lHelper.Declarations[0].TypeName := 'record helper';
  lHelper.Declarations[0].HelperTargetName := 'TX';
  lHelper.SourceText := 'unit HelperA; interface uses Target; implementation end.';
  lFirst := lTarget;
  lFirst.UnitName := 'Consumer';
  lFirst.FileName := 'FirstConsumer.pas';
  lFirst.Declarations := [];
  lFirst.DependencyFacts.InterfaceImports := ['Target', 'HelperA'];
  lFirst.SourceText := 'unit Consumer; interface uses Target, HelperA; implementation end.';
  lSecond := lFirst;
  lSecond.FileName := 'SecondConsumer.pas';
  lSecond.DependencyFacts.InterfaceImports := ['Target'];
  lSecond.SourceText := 'unit Consumer; interface uses Target; implementation end.';
  if aReverse then
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
      [lTarget, lHelper, lSecond, lFirst])
  else
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo,
      [lTarget, lHelper, lFirst, lSecond]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lLineage := lIndex.ResolveLineage(lIndex.ResolveQualifiedName('Target.TX').Identity);
    Assert.IsTrue(lLineage.Complete);
    lWith := Default(TDelphiSemanticWithStatement);
    lWith.Line := 100;
    lWith.Column := 1;
    lSite := TDelphiSemanticNameSites.AtWithStatement(lFirst, lWith, '',
      Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveHelpersAt(lLineage, lSite);
    Assert.AreEqual(1, Integer(Length(lResult.Levels)));
    Assert.IsTrue(lResult.Levels[0].Outcome = TDelphiSemanticNameOutcome.noResolved,
      'First file imports HelperA regardless of graph enumeration order.');
    Assert.AreEqual('HelperA', lResult.Levels[0].Chain[0].UnitName);
    Assert.AreEqual(MaxInt, lResult.OpenFromLevel);
    lSite := TDelphiSemanticNameSites.AtWithStatement(lSecond, lWith, '',
      Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveHelpersAt(lLineage, lSite);
    Assert.IsTrue(lResult.Levels[0].Outcome = TDelphiSemanticNameOutcome.noAbsent,
      'Second file does not import HelperA.');
    Assert.AreEqual(0, Integer(Length(lResult.Levels[0].Chain)));
    Assert.AreEqual(MaxInt, lResult.OpenFromLevel);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.RepeatedParameterHeadingHasOneValueIdentity;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lSite: TDelphiSemanticNameSite;
  lScopeId: string;
  lResult: TDelphiSemanticValueResolution;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-param-temp'), 'Params.pas');
  TFile.WriteAllText(lPath,
    'unit Params;'#13#10'interface'#13#10 +
    'type TRec = record X: Integer; end;'#13#10 +
    'procedure Run(Value: TRec);'#13#10'implementation'#13#10 +
    'procedure Run(Value: TRec);'#13#10'begin'#13#10 +
    '  with Value do X := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  lScopeId := '';
  for var lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'Run') and SameText(lRoutine.AstScopeKind, 'body') then
      lScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lScopeId);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    Assert.AreEqual(2, Integer(Length(lGraph.Parameters)), 'Both heading facts must reach the index.');
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lModel.WithStatements[0],
      lScopeId, Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveValueRootAt(lSite, 'Value');
    Assert.IsTrue(lResult.Outcome = noResolved,
      lResult.Reason + ' candidates=' + IntToStr(Length(lResult.Candidates)));
    Assert.AreEqual('parameter', lResult.Identity.Kind);
    Assert.AreEqual('TRec', lResult.Identity.TypeName);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.DifferentParameterTypesRemainAmbiguous;
var
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lSite: TDelphiSemanticNameSite;
  lScopeId: string;
  lResult: TDelphiSemanticValueResolution;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-param-conflict-temp'), 'Params.pas');
  TFile.WriteAllText(lPath,
    'unit Params;'#13#10'interface'#13#10 +
    'type TRec = record X: Integer; end;'#13#10 +
    'procedure Run(Value: TRec);'#13#10'implementation'#13#10 +
    'procedure Run(Value: TRec);'#13#10'begin'#13#10 +
    '  with Value do X := 1;'#13#10'end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  Assert.AreEqual(1, Integer(Length(lModel.WithStatements)));
  lScopeId := '';
  for var lRoutine in lModel.Routines do
    if SameText(lRoutine.Name, 'Run') and SameText(lRoutine.AstScopeKind, 'body') then
      lScopeId := lRoutine.ScopeId;
  Assert.IsNotEmpty(lScopeId);
  // Conflicting heading facts must survive deduplication as ambiguity.
  Assert.IsTrue(Length(lModel.Routines[0].Parameters) > 0);
  lModel.Routines[0].Parameters[0].TypeName := 'TOther';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    Assert.AreEqual(2, Integer(Length(lGraph.Parameters)), 'Both heading facts must reach the index.');
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lModel.WithStatements[0],
      lScopeId, Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveValueRootAt(lSite, 'Value');
    Assert.IsTrue(lResult.Outcome = noAmbiguous, lResult.Reason);
    Assert.AreEqual(2, Integer(Length(lResult.Candidates)));
    Assert.AreNotEqual(lResult.Candidates[0].TypeName, lResult.Candidates[1].TypeName);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.CompletedForwardPreservesEarlierVisibilityAndBodyEvidence;
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath: string;
  lResult: TDelphiSemanticTypeResolution;
  lSite: TDelphiSemanticNameSite;
  lWith: TDelphiSemanticWithStatement;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-completed-forward-temp'), 'ForwardUnit.pas');
  TFile.WriteAllText(lPath, 'unit ForwardUnit;'#13#10'interface'#13#10'type'#13#10 +
    '  TBase = class;'#13#10'  TBetween = class(TBase) end;'#13#10 +
    '  TBase = class'#13#10'    Value: Integer;'#13#10'  end;'#13#10 +
    'implementation'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lWith := Default(TDelphiSemanticWithStatement);
    lWith.Line := 5;
    lWith.Column := 25;
    lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lWith, '',
      Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveTypeAt(lSite, 'TBase');
    Assert.IsTrue(lResult.Outcome = noResolved,
      'A forward is visible between its heading and completed body: ' + lResult.Reason);
    var lDeclaredId := lResult.Identity.DeclaredId.Value;
    var lCount := 0;
    for var lType in lGraph.Types do
      if SameText(lType.Name, 'TBase') then
        Inc(lCount);
    Assert.AreEqual(1, lCount, 'Forward and body have one graph identity.');
    lSite.Line := 3;
    lSite.Column := 1;
    Assert.IsTrue(lIndex.ResolveTypeAt(lSite, 'TBase').Outcome = noAbsent,
      'The forward must not become visible before its heading.');
    lSite.Line := 9;
    lResult := lIndex.ResolveTypeAt(lSite, 'TBase');
    Assert.IsTrue(lResult.Outcome = noResolved);
    Assert.AreEqual(lDeclaredId, lResult.Identity.DeclaredId.Value);
    Assert.AreEqual(6, lResult.Identity.SourceRange.Line,
      'Member evidence must identify the completed body, independently of forward visibility.');
    Assert.AreEqual(3, lResult.Identity.SourceRange.Column);
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.DefaultResolutionFailsClosed;
var
  lType: TDelphiSemanticTypeResolution;
  lValue: TDelphiSemanticValueResolution;
begin
  lType := Default(TDelphiSemanticTypeResolution);
  lValue := Default(TDelphiSemanticValueResolution);
  Assert.IsTrue(lType.Outcome = TDelphiSemanticNameOutcome.noUnproved,
    'An unset type result cannot authorize binding.');
  Assert.IsTrue(lValue.Outcome = TDelphiSemanticNameOutcome.noUnproved,
    'An unset value result cannot authorize binding.');
end;

procedure TTypeResolverTests.HelperMatchesWeakAliasTerminal(const aShape: string;
  const aMatches: Boolean);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIdentity: TDelphiSemanticTypeIdentity;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lSource, lStrong: string;
  lResult: TDelphiSemanticTypeResolution;
  lSite: TDelphiSemanticNameSite;
  lWith: TDelphiSemanticWithStatement;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-weak-helper-temp'), 'WeakHelper.pas');
  lStrong := '';
  if aShape = 'strong' then
    lStrong := 'type ';
  lSource := 'unit WeakHelper;'#13#10'interface'#13#10 +
    'type'#13#10'  TRec = record X: Integer; end;'#13#10 +
    '  TS = ' + lStrong + 'TRec;'#13#10'  TS2 = TS;'#13#10 +
    '  THelp = record helper for TS2'#13#10'    function M: Integer;'#13#10'  end;'#13#10 +
    'implementation'#13#10'function THelp.M: Integer;'#13#10 +
    'begin'#13#10'  Result := 7;'#13#10'end;'#13#10'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    Assert.IsTrue(lIndex.ResolveQualifiedName('WeakHelper.TRec').Found);
    lIdentity := lIndex.ResolveQualifiedName('WeakHelper.TRec').Identity;
    lWith := Default(TDelphiSemanticWithStatement);
    lWith.Line := 100;
    lWith.Column := 1;
    lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lWith, '',
      Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveActiveHelperAt(lIdentity.DeclaredId, lSite);
    if aMatches then
    begin
      Assert.IsTrue(lResult.Outcome = TDelphiSemanticNameOutcome.noResolved,
        'A two-hop weak alias must identify the terminal helper target: ' + lResult.Reason);
      Assert.AreEqual('THelp', lResult.Identity.Name);
    end else begin
      Assert.IsFalse(lResult.Outcome = TDelphiSemanticNameOutcome.noResolved,
        'A strong alias boundary cannot match the underlying record.');
    end;
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.HelperTargetKinds(const aShape, aExpected: string);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lIdentity: TDelphiSemanticTypeIdentity;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lReceiver, lTarget: string;
  lResult: TDelphiSemanticTypeResolution;
  lHelpers: TDelphiSemanticHelperResolution;
  lSite: TDelphiSemanticNameSite;
  lWith: TDelphiSemanticWithStatement;
begin
  lReceiver := 'TRec';
  lTarget := 'TShort';
  if aShape = 'reverse' then
  begin
    lReceiver := 'TShort';
    lTarget := 'TRec';
  end else if aShape = 'same' then
  begin
    lReceiver := 'TShort';
    lTarget := 'TShort';
  end else if aShape = 'different' then
  begin
    lReceiver := 'TOtherShort';
  end else if aShape = 'missing' then
    lTarget := 'TMissingAlias'
  else if aShape = 'pointer-target' then
    lTarget := 'PRec'
  else if aShape = 'pointer-missing' then
  begin
    lReceiver := 'PMissing';
    lTarget := 'TRec';
  end else if aShape = 'pointer-chain' then
  begin
    lReceiver := 'PAlias';
    lTarget := 'TRec';
  end else if aShape = 'pointer' then
  begin
    lReceiver := 'PRec';
    lTarget := 'TRec';
  end;
  lPath := TPath.Combine(CreateTestTempRoot('ds719-helper-kind-temp'), 'HelperKinds.pas');
  TFile.WriteAllText(lPath, 'unit HelperKinds;'#13#10'interface'#13#10'type'#13#10 +
    '  TRec = record X: Integer; end;'#13#10 +
    '  TShort = string[255];'#13#10'  TOtherShort = string[255];'#13#10 +
    '  PRec = ^TRec;'#13#10'  PAlias = PRec;'#13#10 +
    '  PMissing = ^TNotDeclared;'#13#10'  TMissingAlias = TNotDeclared;'#13#10 +
    '  THelp = record helper for ' + lTarget + #13#10 +
    '    function Next: TRec;'#13#10'  end;'#13#10 +
    'implementation'#13#10'function THelp.Next: TRec;'#13#10 +
    'begin Result.X := 19; end;'#13#10'end.', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lIdentity := lIndex.ResolveQualifiedName('HelperKinds.' + lReceiver).Identity;
    Assert.IsTrue(lIdentity.DeclaredId.Value <> '');
    lWith := Default(TDelphiSemanticWithStatement);
    lWith.Line := 100;
    lWith.Column := 1;
    lSite := TDelphiSemanticNameSites.AtWithStatement(lModel, lWith, '',
      Default(TDelphiSemanticGraphTypeId));
    lResult := lIndex.ResolveActiveHelperAt(lIdentity.DeclaredId, lSite);
    if aExpected = 'resolved' then
      Assert.IsTrue(lResult.Outcome = noResolved, 'active helper: ' + lResult.Reason)
    else if aExpected = 'absent' then
      Assert.IsTrue(lResult.Outcome = noAbsent, 'active helper: ' + lResult.Reason)
    else
      Assert.IsTrue(lResult.Outcome = noUnproved, 'active helper: ' + lResult.Reason);
    lHelpers := lIndex.ResolveHelpersAt(lIndex.ResolveLineage(lIdentity), lSite);
    if aExpected = 'unproved' then
      Assert.IsTrue(lHelpers.OpenFromLevel = 0, 'Unproved applicability must stay open.')
    else begin
      Assert.AreEqual(1, Integer(Length(lHelpers.Levels)));
      Assert.AreEqual(MaxInt, lHelpers.OpenFromLevel);
      if aExpected = 'resolved' then
      begin
        Assert.IsTrue(lHelpers.Levels[0].Outcome = noResolved);
        Assert.AreEqual('THelp', lHelpers.Levels[0].Chain[0].Name);
        if StartsText('pointer', aShape) then
          Assert.AreEqual('TRec', lHelpers.Levels[0].Identity.Name,
            'Pointer applicability uses the declaration-site pointee.');
      end else
        Assert.IsTrue(lHelpers.Levels[0].Outcome = noAbsent);
    end;
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.LineageKeepsCompletenessAndRoots(const aShape: string;
  const aComplete: Boolean; const aCause, aRoot: string; const aIndexed: Boolean;
  const aCount, aStrong: Integer);
var
  lAncestor, lModel: TDelphiSemanticUnitModel;
  lGraph: TDelphiSemanticSemanticGraph;
  lIdentity: TDelphiSemanticTypeIdentity;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lLineage: TDelphiSemanticLineage;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lSource, lDeclarations, lImports: string;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-lineage-temp'), 'LineageUnit.pas');
  lImports := '';
  lDeclarations := '  TSubject = class end;';
  if aShape = 'object' then
    lDeclarations := '  TSubject = class(TObject) end;'
  else if aShape = 'interface' then
    lDeclarations := '  TSubject = interface end;'
  else if aShape = 'record' then
    lDeclarations := '  TSubject = record X: Integer; end;'
  else if aShape = 'weak' then
    lDeclarations := '  TRec = record X: Integer; end;'#13#10 +
      '  TS = TRec;'#13#10'  TSubject = TS;'
  else if aShape = 'strong' then
    lDeclarations := '  TRec = record X: Integer; end;'#13#10 +
      '  TS = TRec;'#13#10'  TSubject = type TS;'
  else if MatchText(aShape, ['unresolved', 'unproved']) then
    lDeclarations := '  TSubject = class(TMissing) end;'
  else if aShape = 'alias' then
    lDeclarations := '  TSubject = TMissing;'
  else if aShape = 'cycle' then
  begin
    lImports := 'uses OtherUnit;'#13#10;
    lDeclarations := '  TSubject = class(OtherUnit.TOther) end;';
  end;
  if aShape = 'unproved' then
    lImports := 'uses UnknownUnit;'#13#10;
  lSource := 'unit LineageUnit;'#13#10'interface'#13#10 + lImports +
    'type'#13#10 + lDeclarations + #13#10'implementation'#13#10'end.';
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success);
  lAncestor := UnitModel('TypeUnitA');
  lAncestor.Declarations := Copy(lAncestor.Declarations, 0, 1);
  if aShape = 'cycle' then
  begin
    lAncestor.UnitName := 'OtherUnit';
    lAncestor.DependencyFacts.InterfaceImports := ['LineageUnit'];
    lAncestor.SourceText := 'unit OtherUnit; interface uses LineageUnit; implementation end.';
    lAncestor.Declarations[0].Name := 'TOther';
    lAncestor.Declarations[0].BaseTypeName := 'LineageUnit.TSubject';
  end else if aShape = 'indexed' then
  begin
    lAncestor.UnitName := 'System';
    lAncestor.Declarations[0].Name := 'TObject';
  end else begin
    lAncestor.Declarations := [];
  end;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel, lAncestor]);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    Assert.IsTrue(lIndex.ResolveQualifiedName('LineageUnit.TSubject').Found);
    lIdentity := lIndex.ResolveQualifiedName('LineageUnit.TSubject').Identity;
    lLineage := lIndex.ResolveLineage(lIdentity);
    Assert.AreEqual(aComplete, lLineage.Complete, aShape + ': completeness');
    Assert.AreEqual(aCause, lLineage.Cause, aShape + ': stopping cause');
    Assert.AreEqual(aRoot, lLineage.ImplicitRoot, aShape + ': implicit root');
    Assert.AreEqual(aIndexed, lLineage.RootIndexed, aShape + ': indexed root');
    Assert.AreEqual(aCount, Integer(Length(lLineage.Items)), aShape + ': exact walk length');
    Assert.AreEqual(aStrong, lLineage.StrongAliasAt, aShape + ': first strong hop');
    Assert.AreEqual(lIdentity.DeclaredId.Value, lLineage.Items[0].DeclaredId.Value);
    Assert.AreEqual(aCount - 1, Integer(Length(lIndex.FindAncestors(lIdentity))),
      'The compatibility view is the same ordered walk without the receiver.');
    if aShape = 'weak' then
    begin
      Assert.AreEqual('TS', lLineage.Items[1].Name);
      Assert.AreEqual('TRec', lLineage.Items[2].Name);
    end;
  finally
    lGraph.Free;
  end;
end;

procedure TTypeResolverTests.HelperDeclarationEvidence(const aShape: string;
  const aKnown: Boolean);
var
  lGraph: TDelphiSemanticSemanticGraph;
  lModel, lReloaded: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lPath, lSource, lDeclaration: string;
begin
  lPath := TPath.Combine(CreateTestTempRoot('ds719-helper-evidence-temp'), 'Evidence.pas');
  lDeclaration := '';
  if MatchText(aShape, ['branch', 'external', 'complete', 'plain', 'body', 'escaped', 'same-line']) then
  begin
    lDeclaration := '  TH = record helper for TRec'#13#10 +
      '    function Count: Integer;'#13#10'  end;'#13#10;
    if MatchText(aShape, ['branch', 'external', 'complete']) then
      lDeclaration := '{$IFDEF REVIEW_FEATURE}'#13#10 + lDeclaration + '{$ENDIF}'#13#10
    else if aShape = 'body' then
      lDeclaration := '  TH = record helper for TRec'#13#10 +
        '{$IFDEF REVIEW_FEATURE}'#13#10'    function Count: Integer;'#13#10 +
        '{$ENDIF}'#13#10'  end;'#13#10;
    if aShape = 'escaped' then
      lDeclaration := StringReplace(lDeclaration, 'TH =', '&TH =', []);
    if aShape = 'same-line' then
      lDeclaration := '  TDummy = Integer; TH = record helper for TRec end;'#13#10;
  end else if aShape = 'identifier' then
    lDeclaration := 'var helper: Integer;'#13#10
  else if aShape = 'missing-include' then
    lDeclaration := '{$I Missing.inc}'#13#10
  else if aShape = 'included-helper' then
  begin
    TFile.WriteAllText(TPath.Combine(TPath.GetDirectoryName(lPath), 'Helper.inc'),
      'TH = record helper for TRec end;', TEncoding.ASCII);
    lDeclaration := '{$I Helper.inc}'#13#10;
  end;
  lSource := 'unit Evidence;'#13#10'interface'#13#10;
  if aShape = 'uses' then
    lSource := lSource + '{$IFDEF LINUX}'#13#10'uses Missing;'#13#10'{$ENDIF}'#13#10;
  lSource := lSource + 'type TRec = record X: Integer; end;'#13#10 +
    lDeclaration + 'implementation'#13#10;
  if aShape = 'init' then
    lSource := lSource + 'initialization'#13#10 +
      '{$IFDEF LINUX}'#13#10'Writeln(1);'#13#10'{$ENDIF}'#13#10;
  lSource := lSource + 'end.';
  if MatchText(aShape, ['BranchHole', 'Probe']) then
    lSource := TFile.ReadAllText(TPath.Combine(RepoRoot,
      'tests\fixtures\ds719-helper-evidence\' + aShape + '.dpr'));
  TFile.WriteAllText(lPath, lSource, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := lPath;
  lOptions.ProjectContextApplied := True;
  lOptions.DefineEvidenceComplete := aShape = 'complete';
  if MatchText(aShape, ['external', 'complete']) then
    lOptions.Defines := ['REVIEW_FEATURE'];
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  if aShape <> 'missing-include' then
    Assert.IsTrue(lModel.Success);
  if lModel.UnitName = '' then
    lModel.UnitName := 'Evidence';
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]);
  try
    if Length(lGraph.Units) = 0 then
    begin
      Assert.AreEqual('missing-include', aShape, 'Only the unresolved include may lack a unit.');
      Assert.IsFalse(lModel.Success,
        'An unresolved include cannot publish an indexed helper-scope proof.');
    end else
      Assert.AreEqual(aKnown, lGraph.Units[0].HelperScopeKnown, aShape);
    if aShape = 'uses' then
      Assert.IsFalse(lGraph.Units[0].ImportsKnown, 'Export proof must not clear imports.');
  finally
    lGraph.Free;
  end;
  Assert.AreEqual(lOptions.DefineEvidenceComplete, lModel.DefineEvidenceComplete);
  lReloaded := JsonToModel(ModelToJson(lModel));
  Assert.AreEqual(lModel.DefineEvidenceComplete, lReloaded.DefineEvidenceComplete,
    'Model cache reload must preserve define evidence.');
  if MatchText(aShape, ['escaped', 'same-line']) then
  begin
    Assert.AreEqual(1, Integer(Length(lReloaded.UnindexedHelpers)));
    Assert.IsTrue(lReloaded.UnindexedHelpers[0].TypeBodyEndLine > 0);
    Assert.IsTrue(lReloaded.UnindexedHelpers[0].TypeBodyEndColumn > 0);
    lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lReloaded]);
    try
      Assert.IsTrue(lGraph.Units[0].HelperScopeKnown, 'Reload retains helper endpoint proof');
    finally
      lGraph.Free;
    end;
  end;
end;

procedure TTypeResolverTests.SkippedIncludeHelperEvidence(const aShape: string;
  const aKnown: Boolean);
var
  g: TGarbos;
  lGraph: TDelphiSemanticSemanticGraph;
  lModel: TDelphiSemanticUnitModel;
  lOptions: TDelphiSemanticModelOptions;
  lRoot, lInclude, lText, lOther: string;
  lLock: TFileStream;
begin
  lRoot := CreateTestTempRoot('ds719-skipped-include-temp');
  lInclude := TPath.Combine(lRoot, 'Skipped.inc');
  lText := '// clean skipped file';
  if aShape = 'helper' then
    lText := 'TH = record helper for TRec end;'
  else if aShape = 'comment' then
    lText := '// helper'
  else if aShape = 'string' then
    lText := 'const s = ''helper'';'
  else if StartsText('nested-', aShape) then
  begin
    lText := '{$I Nested.inc}';
    if aShape = 'nested-clean' then
      TFile.WriteAllText(TPath.Combine(lRoot, 'Nested.inc'), '// clean', TEncoding.ASCII)
    else if aShape = 'nested-helper' then
      TFile.WriteAllText(TPath.Combine(lRoot, 'Nested.inc'), '// helper', TEncoding.ASCII);
  end else if aShape = 'cycle' then
    lText := '{$I Skipped.inc}';
  if aShape <> 'missing' then
    TFile.WriteAllText(lInclude, lText, TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'Evidence.pas');
  lOptions.ProjectContextApplied := True;
  // FPC is skipped by preprocessing, but incomplete evidence cannot prove inactivity.
  lOptions.Defines := ['MSWINDOWS'];
  if MatchText(aShape, ['two', 'include-path']) then
  begin
    lOther := TPath.Combine(lRoot, 'other');
    TDirectory.CreateDirectory(lOther);
    TFile.WriteAllText(TPath.Combine(lOther, 'Skipped.inc'), '// clean', TEncoding.ASCII);
    if aShape = 'two' then
      lOptions.SearchPaths := [lOther]
    else
    begin
      TFile.Delete(lInclude);
      lOptions.IncludePaths := [lOther];
    end;
  end;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit Evidence;'#13#10'interface'#13#10'{$IFDEF FPC}'#13#10 +
    '{$I Skipped.inc}'#13#10'{$ENDIF}'#13#10'implementation'#13#10'end.', TEncoding.ASCII);
  if aShape = 'unreadable' then
    GC(lLock, TFileStream.Create(lInclude, fmOpenReadWrite or fmShareExclusive), g);
  lModel := TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions);
  Assert.IsTrue(lModel.Success, aShape + ': skipped text must not affect the selected AST');
  Assert.AreEqual(0, Integer(Length(lModel.IncludeFileNames)), 'Skipped is not observed active source');
  Assert.IsFalse(lModel.DefineEvidenceComplete);
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lModel]), g);
  Assert.AreEqual(1, Integer(Length(lGraph.Units)));
  Assert.AreEqual(aKnown, lGraph.Units[0].HelperScopeKnown, aShape);
end;

procedure TTypeResolverTests.SkippedIncludeEditInvalidatesCache;
var
  g: TGarbos;
  lCache: TDelphiSemanticUnitCache;
  lCacheOptions: TDelphiSemanticCacheOptions;
  lOptions: TDelphiSemanticModelOptions;
  lAccess: TDelphiSemanticUnitCacheAccessResult;
  lGraph: TDelphiSemanticSemanticGraph;
  lRoot, lInclude: string;
begin
  lRoot := CreateTestTempRoot('ds719-skipped-cache-temp');
  lInclude := TPath.Combine(lRoot, 'Skipped.inc');
  TFile.WriteAllText(lInclude, '// clean', TEncoding.ASCII);
  lOptions := Default(TDelphiSemanticModelOptions);
  lOptions.SourceFileName := TPath.Combine(lRoot, 'Evidence.pas');
  lOptions.ProjectContextApplied := True;
  TFile.WriteAllText(lOptions.SourceFileName,
    'unit Evidence;'#13#10'interface'#13#10'{$IFDEF FPC}'#13#10 +
    '{$I Skipped.inc}'#13#10'{$ENDIF}'#13#10'implementation'#13#10'end.', TEncoding.ASCII);
  lCacheOptions := Default(TDelphiSemanticCacheOptions);
  lCacheOptions.SqliteCacheFileName := TPath.Combine(lRoot, 'cache.sqlite');
  GC(lCache, TDelphiSemanticSqliteUnitCache.Create(lCacheOptions), g);
  lAccess := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lAccess.Model]), g);
  Assert.IsTrue(lGraph.Units[0].HelperScopeKnown, 'Unique clean skipped include closes');
  g.Clear;
  // A new instance proves persistent reload, including role reconstruction.
  GC(lCache, TDelphiSemanticSqliteUnitCache.Create(lCacheOptions), g);
  lAccess := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  Assert.IsTrue(lAccess.CacheHit, 'Persistent skipped-file identity must hit');
  Assert.AreEqual(0, Integer(Length(lAccess.Model.IncludeFileNames)));
  Assert.AreEqual(1, Integer(Length(lAccess.Model.SkippedIncludeFileNames)));
  Assert.AreEqual(lInclude, lAccess.Model.SkippedIncludeFileNames[0]);
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lAccess.Model]), g);
  Assert.IsTrue(lGraph.Units[0].HelperScopeKnown, 'Reload keeps skipped proof separate');
  TFile.WriteAllText(lInclude, '// helper', TEncoding.ASCII);
  lAccess := lCache.GetOrExtractUnitModelWithStatus(lOptions);
  Assert.IsFalse(lAccess.CacheHit, 'Editing skipped source invalidates the model');
  GC(lGraph, TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, [lAccess.Model]), g);
  Assert.IsFalse(lGraph.Units[0].HelperScopeKnown, 'Edited skipped file cannot close scope');
end;

procedure TTypeResolverTests.DeclarationSitesKeepClassAndOrderIdentity(const aShape: string);
var
  lModels: TArray<TDelphiSemanticUnitModel>;
  lOptions: TDelphiSemanticModelOptions;
  lGraph: TDelphiSemanticSemanticGraph;
  lIndex: TDelphiSemanticTypeIdentityIndex;
  lOwner: TDelphiSemanticGraphTypeId;
  lSite: TDelphiSemanticNameSite;
  lResult: TDelphiSemanticTypeResolution;
  lSeen: Integer;
begin
  for var lFile in [FixturePath('BindingSafety', aShape + '\Unit1.pas'),
    FixturePath('BindingSafety', 'common\ClassBase.pas')] do
  begin
    lOptions := Default(TDelphiSemanticModelOptions);
    lOptions.SourceFileName := lFile;
    lOptions.ProjectContextApplied := True;
    lModels := lModels + [TDelphiSemanticUnitModelExtractor.ExtractFromFile(lOptions)];
    Assert.IsTrue(lModels[High(lModels)].Success);
  end;
  lGraph := TDelphiSemanticSemanticGraphBuilder.Build(ProjectInfo, lModels);
  try
    lIndex := TDelphiSemanticTypeResolver.BuildIndex(lGraph);
    lOwner := Default(TDelphiSemanticGraphTypeId);
    if aShape = 'class-own' then
      lOwner := lIndex.ResolveQualifiedName('Unit1.TOuter').Identity.DeclaredId
    else if aShape = 'class-ancestor' then
      lOwner := lIndex.ResolveQualifiedName('Unit1.TChild').Identity.DeclaredId;
    lSeen := 0;
    for var lLocal in lModels[0].Locals do
      if lLocal.Name = 'lRec' then
      begin
        Inc(lSeen);
        lSite := TDelphiSemanticNameSites.AtLocal(lModels[0], lLocal, lOwner);
        lResult := lIndex.ResolveTypeAt(lSite, lLocal.TypeName);
        Assert.AreEqual(noResolved, lResult.Outcome, lResult.Cause);
        if aShape = 'declaration-order' then
        begin
          Assert.AreNotEqual('routine', lResult.Identity.ScopeKind);
          Assert.AreEqual('TFoo', lResult.Identity.Name);
        end else begin
          Assert.AreEqual('type', lResult.Identity.ScopeKind);
          Assert.AreEqual('TInner', lResult.Identity.Name);
          if aShape = 'class-ancestor' then
            Assert.AreEqual('ClassBase', lResult.Identity.UnitName);
        end;
      end;
    Assert.AreEqual(1, lSeen);
  finally
    lGraph.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTypeResolverTests);

end.
